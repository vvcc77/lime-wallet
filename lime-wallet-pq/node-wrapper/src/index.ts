import init, { falcon_sign } from '../../crypto-core/pkg/crypto_core.js';
import { getQrngBytes } from './qrng.js';

export async function partialSign(message: Uint8Array) {
  await init();
  const seed = await getQrngBytes(48);
  // TODO: mix seed into FROST nonce
  return falcon_sign(message);
}

