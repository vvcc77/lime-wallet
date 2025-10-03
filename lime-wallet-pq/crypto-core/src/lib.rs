use wasm_bindgen::prelude::*;
use rand::rngs::OsRng;

#[wasm_bindgen]
pub fn falcon_sign(message: &[u8]) -> Vec<u8> {
    // Placeholder – integrate FROST partial sign here
    let mut sig = message.to_vec();
    sig.push(0x00); // fake byte
    sig
}
