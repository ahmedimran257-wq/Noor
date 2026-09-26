import { assertEquals } from "@std/assert";
import { Image } from "imagescript";

Deno.test("photo validation bounds JPEG dimensions before decoding", async (t) => {
  const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
  const originalFetch = globalThis.fetch;
  const originalDecode = Image.decode;
  const envNames = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"];
  const savedEnv = envNames.map((name) => Deno.env.get(name));
  let handler!: (request: Request) => Promise<Response>;
  const userId = "11111111-1111-4111-8111-111111111111";
  const path = `${userId}/22222222-2222-4222-8222-222222222222.jpg`;
  const validJpeg = await new Image(320, 320).encodeJPEG();
  let upload = validJpeg;
  let decodeCalls = 0;
  let removed = 0;
  let finalized = 0;
  let blockDecode = false;
  try {
    Deno.env.set(envNames[0], "https://example.supabase.co");
    Deno.env.set(envNames[1], "test-only-service-key");
    Object.defineProperty(Deno, "serve", {
      configurable: true,
      value: (callback: typeof handler) => {
        handler = callback;
        return {};
      },
    });
    await import("./index.ts");
    Object.defineProperty(Deno, "serve", originalServe);
    Image.decode = async (bytes: Uint8Array) => {
      decodeCalls++;
      // Never allocate a forged image, even when proving the old guard fails.
      if (blockDecode) throw new Error("unsafe_decoder_call");
      return await originalDecode(bytes);
    };
    globalThis.fetch = (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);
      if (url.hostname !== "example.supabase.co") {
        throw new Error("unexpected_test_network_request");
      }
      const json = (value: unknown) => Promise.resolve(Response.json(value));
      if (url.pathname === "/auth/v1/user") return json({ id: userId });
      if (url.pathname.endsWith("/rpc/consume_edge_rate_limit")) {
        return json([{
          allowed: true,
          remaining: 19,
          reset_at: new Date(Date.now() + 60_000).toISOString(),
        }]);
      }
      if (url.pathname === "/rest/v1/photos") return json(null);
      if (url.pathname.endsWith("/rpc/finalize_profile_photo_upload")) {
        finalized++;
        return json([{ photo_id: "test-photo", action: "active" }]);
      }
      if (url.pathname.startsWith("/storage/v1/object/")) {
        if (request.method === "DELETE") {
          removed++;
          return json([]);
        }
        return Promise.resolve(
          new Response(Uint8Array.from(upload), {
            headers: { "Content-Type": "image/jpeg" },
          }),
        );
      }
      throw new Error(`unexpected_test_path:${url.pathname}`);
    };
    const invoke = () =>
      handler(
        new Request("https://example.test", {
          method: "POST",
          headers: { Authorization: "Bearer test-only" },
          body: JSON.stringify({ storage_path: path }),
        }),
      );

    await t.step(
      "oversized headers never reach the allocating decoder",
      async () => {
        blockDecode = true;
        for (
          const [width, height] of [[8001, 320], [320, 8001], [6000, 6000]]
        ) {
          upload = jpegFrame(width, height);
          decodeCalls = removed = finalized = 0;
          const response = await invoke();
          assertEquals(response.status, 422);
          assertEquals(decodeCalls, 0);
          assertEquals(removed, 1);
          assertEquals(finalized, 0);
        }
      },
    );
    for (
      const [name, bytes] of [
        ["baseline", validJpeg],
        [
          "progressive",
          progressiveJpeg,
        ],
        ["grayscale", grayscaleJpeg],
        ["CMYK", cmykJpeg],
      ] as const
    ) {
      await t.step(`${name} JPEG still decodes and publishes`, async () => {
        blockDecode = false;
        upload = bytes;
        decodeCalls = removed = finalized = 0;
        const response = await invoke();
        assertEquals(response.status, 202);
        assertEquals((await response.json()).action, "active");
        assertEquals(decodeCalls, 1);
        assertEquals(removed, 0);
        assertEquals(finalized, 1);
      });
    }
  } finally {
    Object.defineProperty(Deno, "serve", originalServe);
    globalThis.fetch = originalFetch;
    Image.decode = originalDecode;
    envNames.forEach((name, i) => {
      if (savedEnv[i] === undefined) Deno.env.delete(name);
      else Deno.env.set(name, savedEnv[i]!);
    });
  }
});

// Generated once with Pillow: RGB 320x320, fill (80,120,160), progressive JPEG.
// Embedded so CI needs no image-generation dependency or fixture download.
const progressiveJpeg = Uint8Array.from(
  atob(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCAFAAUADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAT/xAAVAQEBAAAAAAAAAAAAAAAAAAAABP/aAAwDAQACEAMQAAABnFkoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAH/xAAUEAEAAAAAAAAAAAAAAAAAAACg/9oACAEBAAEFAkgf/8QAFBEBAAAAAAAAAAAAAAAAAAAAgP/aAAgBAwEBPwFIf//EABQRAQAAAAAAAAAAAAAAAAAAAID/2gAIAQIBAT8BSH//xAAUEAEAAAAAAAAAAAAAAAAAAACg/9oACAEBAAY/Akgf/8QAFBABAAAAAAAAAAAAAAAAAAAAoP/aAAgBAQABPyFIH//aAAwDAQACAAMAAAAQ8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888/8QAFBEBAAAAAAAAAAAAAAAAAAAAgP/aAAgBAwEBPxBIf//EABQRAQAAAAAAAAAAAAAAAAAAAID/2gAIAQIBAT8QSH//xAAUEAEAAAAAAAAAAAAAAAAAAACg/9oACAEBAAE/EEgf/9k=",
  ),
  (character) => character.charCodeAt(0),
);

// Pillow-generated 320x320 solid grayscale and CMYK JPEG compatibility fixtures.
const grayscaleJpeg = Uint8Array.from(
  atob(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAFAAUABAREA/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AJ/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAf//Z",
  ),
  (c) => c.charCodeAt(0),
);
const cmykJpeg = Uint8Array.from(
  atob(
    "/9j/7gAOQWRvYmUAZAAAAAAA/9sAQwAIBgYHBgUIBwcHCQkICgwUDQwLCwwZEhMPFB0aHx4dGhwcICQuJyAiLCMcHCg3KSwwMTQ0NB8nOT04MjwuMzQy/8AAFAgBQAFABEMRAE0RAFkRAEsRAP/EABUAAQEAAAAAAAAAAAAAAAAAAAAH/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAA4EQwBNAFkASwAAPwC/r+v6/gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/Z",
  ),
  (c) => c.charCodeAt(0),
);

// A header-only adversarial fixture, never passed to the real decoder.
function jpegFrame(width: number, height: number): Uint8Array {
  return new Uint8Array([
    0xff,
    0xd8,
    0xff,
    0xc0,
    0,
    17,
    8,
    height >> 8,
    height & 255,
    width >> 8,
    width & 255,
    3,
    1,
    0x11,
    0,
    2,
    0x11,
    0,
    3,
    0x11,
    0,
    0xff,
    0xda,
    0,
    12,
    3,
    1,
    0,
    2,
    0,
    3,
    0,
    0,
    63,
    0,
    1,
    0xff,
    0xd9,
  ]);
}
