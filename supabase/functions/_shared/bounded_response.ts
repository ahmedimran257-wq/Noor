export async function readResponseBytes(
  response: Response,
  maxBytes: number,
): Promise<Uint8Array> {
  const declaredLength = Number(response.headers.get("content-length") ?? 0);
  if (declaredLength > maxBytes) {
    throw new Error("provider_response_too_large");
  }

  const reader = response.body?.getReader();
  if (!reader) return new Uint8Array();

  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel("provider_response_too_large");
        throw new Error("provider_response_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

export async function readResponseText(
  response: Response,
  maxBytes: number,
): Promise<string> {
  return new TextDecoder().decode(
    await readResponseBytes(response, maxBytes),
  );
}

export async function readResponseJson(
  response: Response,
  maxBytes: number,
): Promise<unknown> {
  return JSON.parse(await readResponseText(response, maxBytes));
}
