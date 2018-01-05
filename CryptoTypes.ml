type aead_cipher =
  | AES_128_GCM
  | AES_256_GCM
  | CHACHA20_POLY1305
  | AES_128_CCM   (* "Counter with CBC-Message Authentication Code" *)
  | AES_256_CCM
  | AES_128_CCM_8 (* variant with truncated 8-byte tags *)
  | AES_256_CCM_8

(* the key materials consist of an encryption key, a static IV, and an authentication key. *)

let aeadKeySize = function
  | AES_128_CCM       -> Z.of_int 16
  | AES_128_CCM_8     -> Z.of_int 16
  | AES_128_GCM       -> Z.of_int 16
  | AES_256_CCM       -> Z.of_int 32
  | AES_256_CCM_8     -> Z.of_int 32
  | AES_256_GCM       -> Z.of_int 32
  | CHACHA20_POLY1305 -> Z.of_int 32

let aeadRealIVSize (a:aead_cipher) = Z.of_int 12

(* the ciphertext ends with an authentication tag *)
let aeadTagSize = function
  | AES_128_CCM_8     -> Z.of_int 8
  | AES_256_CCM_8     -> Z.of_int 8
  | AES_128_CCM       -> Z.of_int 16
  | AES_256_CCM       -> Z.of_int 16
  | AES_128_GCM       -> Z.of_int 16
  | AES_256_GCM       -> Z.of_int 16
  | CHACHA20_POLY1305 -> Z.of_int 16
