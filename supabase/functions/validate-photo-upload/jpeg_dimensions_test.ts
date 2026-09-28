import { assertEquals } from "@std/assert";
import { hasSafeJpegDimensions } from "./jpeg_dimensions.ts";

function frame(width = 320, height = 320, marker = 0xc0, components = 3) {
  const body = [
    8,
    height >> 8,
    height & 255,
    width >> 8,
    width & 255,
    components,
  ];
  for (let i = 0; i < components; i++) body.push(i + 1, 0x11, 0);
  return segment(marker, body);
}

function segment(marker: number, body: number[]) {
  const length = body.length + 2;
  return [0xff, marker, length >> 8, length & 255, ...body];
}

const scan = segment(0xda, [1, 1, 0, 0, 63, 0]);
const jpeg = (...parts: number[][]) =>
  new Uint8Array([0xff, 0xd8, ...parts.flat(), 0xff, 0xd9]);

Deno.test("JPEG preflight preserves geometry limits and common frame forms", () => {
  for (const marker of [0xc0, 0xc1, 0xc2]) {
    for (const components of [1, 3, 4]) {
      assertEquals(
        hasSafeJpegDimensions(jpeg(frame(320, 320, marker, components), scan)),
        true,
      );
    }
  }
  assertEquals(hasSafeJpegDimensions(jpeg(frame(8000, 4000), scan)), true);
  for (
    const [width, height] of [
      [0, 320],
      [319, 320],
      [320, 319],
      [8001, 320],
      [320, 8001],
      [6000, 6000],
      [65535, 65535],
    ]
  ) {
    assertEquals(
      hasSafeJpegDimensions(jpeg(frame(width, height), scan)),
      false,
    );
  }
});

Deno.test("JPEG preflight skips metadata and supports scan escapes and progressive scans", () => {
  const metadata = segment(0xe1, frame(65535, 65535));
  const encoded = jpeg(
    metadata,
    frame(640, 480, 0xc2),
    scan,
    [42, 0xff, 0x00, 43, 0xff, 0xd0, 44],
    segment(0xc4, [0]),
    scan,
    [7],
  );
  assertEquals(hasSafeJpegDimensions(encoded), true);
  const padded = jpeg([0xff], frame(), scan);
  assertEquals(hasSafeJpegDimensions(padded), true);
});

Deno.test("JPEG preflight rejects truncation, ambiguous frames and deferred dimensions", () => {
  const valid = jpeg(frame(), scan, [1]);
  for (let length = 0; length < valid.length; length++) {
    assertEquals(hasSafeJpegDimensions(valid.subarray(0, length)), false);
  }
  for (
    const bytes of [
      jpeg(scan),
      jpeg(frame()),
      jpeg(frame(), frame(8000, 8000), scan),
      jpeg(frame(), scan, [1], frame(8000, 8000), scan),
      jpeg(frame(), scan, segment(0xdc, [1, 64])),
      jpeg([0xff, 0xe1, 0, 1], frame(), scan),
      jpeg([0xff, 0xe1, 0xff, 0xff], frame(), scan),
      jpeg([0xff, 0x00], frame(), scan),
      jpeg([0xff, 0xd0], frame(), scan),
      jpeg(frame(), scan, [0xff, 0xd8]),
      new Uint8Array([...valid, ...valid]),
    ]
  ) assertEquals(hasSafeJpegDimensions(bytes), false);
});
