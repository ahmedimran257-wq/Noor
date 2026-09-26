// Allocation-free preflight, not a JPEG decoder. Walk segment lengths and scan
// escapes so metadata, a second frame or deferred height cannot hide geometry.
// The existing decoder still validates pixels and the decoded dimensions.
export function hasSafeJpegDimensions(bytes: Uint8Array): boolean {
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8) return false;
  let offset = 2;
  let hasFrame = false;
  let hasScan = false;
  let inScan = false;
  while (offset < bytes.length) {
    if (inScan) {
      while (offset < bytes.length && bytes[offset] !== 0xff) offset++;
    }
    if (bytes[offset++] !== 0xff) return false;
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0x00 || (marker >= 0xd0 && marker <= 0xd7)) {
      if (!inScan) return false;
      continue;
    }
    if (marker === 0x01) continue; // Standalone TEM marker.
    if (marker === 0xd9) {
      return hasFrame && hasScan && offset === bytes.length;
    }
    if (marker === 0xd8 || marker === 0xdc) return false; // SOI / deferred height.
    inScan = false;
    if (offset + 2 > bytes.length) return false;
    const length = bytes[offset] * 256 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return false;
    const isFrame = marker >= 0xc0 && marker <= 0xcf &&
      marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
    if (isFrame) {
      if (hasFrame || length < 11) return false;
      const height = bytes[offset + 3] * 256 + bytes[offset + 4];
      const width = bytes[offset + 5] * 256 + bytes[offset + 6];
      const components = bytes[offset + 7];
      if (
        components < 1 || length !== 8 + 3 * components ||
        width < 320 || height < 320 || width > 8000 || height > 8000 ||
        width * height > 32_000_000
      ) return false;
      hasFrame = true;
    }
    if (marker === 0xda) {
      if (!hasFrame) return false;
      hasScan = inScan = true;
    }
    offset += length;
  }
  return false;
}
