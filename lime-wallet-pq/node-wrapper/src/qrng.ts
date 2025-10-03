export async function getQrngBytes(len: number): Promise<Uint8Array> {
  // Stub: fetch from local QRNG USB or fall back to window.crypto
  const buf = new Uint8Array(len);
  crypto.getRandomValues(buf);
  return buf;
}

