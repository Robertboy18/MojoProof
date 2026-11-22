/-!
# SHA-256

SHA-256 (FIPS 180-4) of a byte array, as a lowercase hexadecimal string. The importer records the
digest of every kernel file it reads, so a theorem about an imported program names the exact bytes
it is about. Tested by the test driver (MojoProofTest/Main.lean) against three known digests (the
empty message, `abc` and the 56-byte message of the FIPS 180-4 examples) and against the digest
of every corpus file in tests/corpus/MANIFEST.tsv, which scripts/corpus.py computes with
Python's hashlib.

This module is executable code with no theorems.
-/

namespace MojoProof.SHA256

/-- The round constants. -/
def k : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

/-- The initial hash value. -/
def h0 : Array UInt32 :=
  #[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

private def rotr (x n : UInt32) : UInt32 := (x >>> n) ||| (x <<< (32 - n))

/-- The message padded to a multiple of 64 bytes: `0x80`, zeros, the bit length as 64 bits. -/
def pad (msg : ByteArray) : ByteArray := Id.run do
  let mut m := msg.push 0x80
  while m.size % 64 != 56 do
    m := m.push 0
  let bits := msg.size * 8
  for i in [0:8] do
    m := m.push (bits >>> (8 * (7 - i))).toUInt8
  return m

/-- One compression of the 64-byte block at offset `off`. -/
def compress (h : Array UInt32) (m : ByteArray) (off : Nat) : Array UInt32 := Id.run do
  let mut w : Array UInt32 := Array.mkEmpty 64
  for i in [0:16] do
    let b (j : Nat) : UInt32 := m[off + 4 * i + j]!.toUInt32
    w := w.push ((b 0 <<< 24) ||| (b 1 <<< 16) ||| (b 2 <<< 8) ||| b 3)
  for i in [16:64] do
    let x := w[i - 15]!
    let y := w[i - 2]!
    let s0 := rotr x 7 ^^^ rotr x 18 ^^^ (x >>> 3)
    let s1 := rotr y 17 ^^^ rotr y 19 ^^^ (y >>> 10)
    w := w.push (w[i - 16]! + s0 + w[i - 7]! + s1)
  let mut (a, b, c, d, e, f, g, hh) := (h[0]!, h[1]!, h[2]!, h[3]!, h[4]!, h[5]!, h[6]!, h[7]!)
  for i in [0:64] do
    let t1 := hh + (rotr e 6 ^^^ rotr e 11 ^^^ rotr e 25) + ((e &&& f) ^^^ (~~~e &&& g)) +
      k[i]! + w[i]!
    let t2 := (rotr a 2 ^^^ rotr a 13 ^^^ rotr a 22) + ((a &&& b) ^^^ (a &&& c) ^^^ (b &&& c))
    (a, b, c, d, e, f, g, hh) := (t1 + t2, a, b, c, d + t1, e, f, g)
  return #[h[0]! + a, h[1]! + b, h[2]! + c, h[3]! + d, h[4]! + e, h[5]! + f, h[6]! + g, h[7]! + hh]

private def hexByte (b : UInt8) : String :=
  let d (n : UInt8) : Char :=
    if n < 10 then Char.ofNat (48 + n.toNat) else Char.ofNat (87 + n.toNat)
  String.ofList [d (b >>> 4), d (b &&& 15)]

/-- The SHA-256 digest of `msg` as 64 lowercase hexadecimal digits. -/
def hex (msg : ByteArray) : String := Id.run do
  let m := pad msg
  let mut h := h0
  for i in [0:m.size / 64] do
    h := compress h m (64 * i)
  return String.join <| h.toList.flatMap fun x =>
    [24, 16, 8, 0].map fun s => hexByte (x >>> s).toUInt8

end MojoProof.SHA256
