import MojoProof.Sem.TensorCoreWarp
import MojoProof.Sem.TensorCoreAcc

/-!
# The warp steps of `mma` and `ldmatrix` on run-time values, at two shapes each

Tests of MojoProof/Sem/TensorCoreWarp.lean.
* `bf16Warp`, `tf32Warp`: `mmaWarp_spec` at `m16n8k16 .bf16` and at `m16n8k8 .tf32`, both
  with an f32 accumulator, for every accumulation and all tiles; `ldm4Warp`, `ldm2Warp`:
  `ldmWarp_spec` at `ldmatrix.x4` and `.x2`, both flags.
* `#guard`s:
  - the register forms read a 32-bit pair and a `<2 x half>` vector element by element, and
    refuse another width, poison and a pointer;
  - on a warp's registers written by hand, every A and B element the bfloat16 one (`0x3f80`, two
    to an `i32`) and C zero, `mmaWarp` at `m16n8k16 .bf16` with the measured policy on bit
    patterns, `gridAcc.bits .bfloat16`, gives every lane four words of 16 (`0x41800000`), the
    words the GPU wrote in tests/gpu/mma/record.txt's kind-0 launches; a poison register or a
    missing one makes it `none`;
  - at `m16n8k8 .tf32`, on registers written by hand from the ISA's tables of section
    9.7.16.5.14 (`a0` to `a3` at `(g, t)`, `(g + 8, t)`, `(g, t + 4)`, `(g + 8, t + 4)`, `b0`
    and `b1` at `(t, g)` and `(t + 4, g)`, `c0` to `c3` at `(g, 2t)`, `(g, 2t + 1)`,
    `(g + 8, 2t)`, `(g + 8, 2t + 1)`, for `g = l / 4`, `t = l % 4`), with the exact
    accumulation on small integers, every lane's D register `r` is the sum at the cell of the
    table's C register `r`;
  - `ldmWarp` at `.x4` and `.x2`, both flags, on rows of a block at 16-byte strides, gives every
    lane's registers the elements `ldmatrix` gives.
-/

namespace MojoProofTest.TensorCoreWarp

open MojoProof.Sem MojoProof.LLVM FloatLib FloatLib.Floats.Formats
open FloatLib.Floats.Formats.BinaryInterchange

/-- `mma.m16n8k16` with bf16 inputs and an f32 accumulator, as the importer reads it. -/
def mmaBf16 : Mma := ⟨16, 8, 16, .bf16, .float⟩

/-- `mma.m16n8k8` with tf32 inputs and an f32 accumulator, as the importer reads it. -/
def mmaTf32 : Mma := ⟨16, 8, 8, .tf32, .float⟩

/-- **The warp's `mma` at `m16n8k16 .bf16`**, the instance of `mmaWarp_spec`: for every
accumulation `acc` on bit patterns and all tiles of 16-bit A and B elements and 32-bit C
elements, on the lanes' encoded registers (two bf16 to an `i32`, one f32 to a `float`) the step
succeeds and its D tile is `acc (TA i ·) (TB · j) (TC i j)` modulo `2 ^ 32` at every cell. -/
theorem bf16Warp (acc : (Fin 16 → Nat) → (Fin 16 → Nat) → Nat → Nat) (TA TB TC : Nat → Nat → Nat)
    (hTA : ∀ i j, TA i j < 2 ^ 16) (hTB : ∀ i j, TB i j < 2 ^ 16)
    (hTC : ∀ i j, TC i j < 2 ^ 32) :
    ∃ y, mmaWarp mmaBf16 acc (fun l => encode .pair (fragA 2 2 2) TA l ++
        encode .pair (fragB 2 2) TB l ++ encode (.word 32) (fragC 2 1) TC l) = some y ∧
      ∀ i < 16, ∀ j < 8, (fragC 2 1).gather (resElem (.word 32) y) i j =
        acc (fun k => TA i k) (fun k => TB k j) (TC i j) % 2 ^ 32 :=
  mmaWarp_spec (v := mmaBf16) (FA := fragA 2 2 2) (FB := fragB 2 2) (FC := fragC 2 1) rfl acc
    TA TB TC hTA hTB hTC

/-- **The warp's `mma` at `m16n8k8 .tf32`**, the instance of `mmaWarp_spec` at a second shape
and input format: for every accumulation and all tiles of 32-bit elements, on the lanes' encoded
registers (one tf32 to an `i32`, one f32 to a `float`) the step succeeds and its D tile is
`acc (TA i ·) (TB · j) (TC i j)` modulo `2 ^ 32` at every cell. -/
theorem tf32Warp (acc : (Fin 8 → Nat) → (Fin 8 → Nat) → Nat → Nat) (TA TB TC : Nat → Nat → Nat)
    (hTA : ∀ i j, TA i j < 2 ^ 32) (hTB : ∀ i j, TB i j < 2 ^ 32)
    (hTC : ∀ i j, TC i j < 2 ^ 32) :
    ∃ y, mmaWarp mmaTf32 acc (fun l => encode (.word 32) (fragA 2 1 2) TA l ++
        encode (.word 32) (fragB 1 2) TB l ++ encode (.word 32) (fragC 2 1) TC l) = some y ∧
      ∀ i < 16, ∀ j < 8, (fragC 2 1).gather (resElem (.word 32) y) i j =
        acc (fun k => TA i k) (fun k => TB k j) (TC i j) % 2 ^ 32 :=
  mmaWarp_spec (v := mmaTf32) (FA := fragA 2 1 2) (FB := fragB 1 2) (FC := fragC 2 1) rfl acc
    TA TB TC hTA hTB hTC

/-- **The warp's `ldmatrix.x4`**, the instance of `ldmWarp_spec` at the importer's count, both
flags: when lane `R < 32` passes the pointer `P R` and its row's elements read as `T R C`, the
step succeeds and its registers, read in `ldm 4 t`, are `T`. -/
theorem ldm4Warp (t : Bool) {rd : Ptr → Option Nat} {x : Nat → List Val} {P : Nat → Ptr}
    {T : Nat → Nat → Nat} (hx : ∀ R < 32, x R = [.ptr (P R)])
    (hrd : ∀ R < 32, ∀ C : Nat, C < 8 → rd ⟨(P R).block, (P R).off + 2 * C⟩ = some (T R C))
    (hT : ∀ R C, T R C < 2 ^ 16) :
    ∃ y, ldmWarp 4 t rd x = some y ∧
      ∀ R < 32, ∀ C < 8, (ldm 4 t).gather (resElem .pair y) R C = T R C :=
  ldmWarp_spec (q := 4) hx hrd hT

/-- **The warp's `ldmatrix.x2`**, the instance of `ldmWarp_spec` at a second count, both flags:
when lane `R < 16` passes the pointer `P R` and its row's elements read as `T R C`, the step
succeeds and its registers, read in `ldm 2 t`, are `T`. -/
theorem ldm2Warp (t : Bool) {rd : Ptr → Option Nat} {x : Nat → List Val} {P : Nat → Ptr}
    {T : Nat → Nat → Nat} (hx : ∀ R < 16, x R = [.ptr (P R)])
    (hrd : ∀ R < 16, ∀ C : Nat, C < 8 → rd ⟨(P R).block, (P R).off + 2 * C⟩ = some (T R C))
    (hT : ∀ R C, T R C < 2 ^ 16) :
    ∃ y, ldmWarp 2 t rd x = some y ∧
      ∀ R < 16, ∀ C < 8, (ldm 2 t).gather (resElem .pair y) R C = T R C :=
  ldmWarp_spec (q := 2) hx hrd hT

-- The forms read a 32-bit pair and a `<2 x half>` vector, and refuse another width, poison and
-- a pointer.
#guard RegForm.pair.get (.bits 32 0x40003f80) 0 == some 0x3f80 &&
  RegForm.pair.get (.bits 32 0x40003f80) 1 == some 0x4000 &&
  RegForm.pair.get (.bits 32 0x40003f80) 2 == none
#guard RegForm.vec2.get (.vec [.bits 16 0x3c00, .bits 16 0xc000]) 0 == some 0x3c00 &&
  RegForm.vec2.get (.vec [.bits 16 0x3c00, .bits 16 0xc000]) 1 == some 0xc000
#guard (RegForm.word 32).get (.bits 64 0) 0 == none && RegForm.vec2.get .poison 0 == none &&
  RegForm.pair.get (.ptr ⟨1, 0⟩) 0 == none && RegForm.vec2.get (.vec [.bits 16 0]) 0 == none

/-- Every lane's arguments at `m16n8k16 .bf16`, written by hand: four A and two B registers
of two bfloat16 ones (`0x3f803f80`), then four C registers of binary32 zero. -/
def onesArgs : Nat → List Val :=
  fun _ => List.replicate 6 (Val.bits 32 0x3f803f80) ++ List.replicate 4 (Val.bits 32 0)

-- Every lane's four D registers are 16 (`0x41800000`).
#guard match mmaWarp mmaBf16 (gridAcc.bits .bfloat16) onesArgs with
  | some y => (List.range 32).all fun l => (List.range 4).all fun r =>
      resElem (.word 32) y l r 0 == 0x41800000
  | none => false
-- A poison register in lane 5, or a lane with nine registers, makes the step `none`.
#guard (mmaWarp mmaBf16 (gridAcc.bits .bfloat16) fun l =>
  if l = 5 then (onesArgs l).set 3 .poison else onesArgs l).isNone
#guard (mmaWarp mmaBf16 (gridAcc.bits .bfloat16) fun l => (onesArgs l).take 9).isNone

/-- The exact accumulation on natural numbers, `c + Σ_k a_k b_k`, for a layout test. -/
def sumAcc {K : Nat} (a b : Fin K → Nat) (c : Nat) : Nat :=
  (List.finRange K).foldl (fun s k => s + a k * b k) c

/-- An A tile of small integers: cell `(i, k)` is `100 i + k + 1`. -/
def smallA (i k : Nat) : Nat := 100 * i + k + 1

/-- A B tile of small integers: cell `(k, j)` is `10 k + j + 2`. -/
def smallB (k j : Nat) : Nat := 10 * k + j + 2

/-- A C tile of small integers: cell `(i, j)` is `i j + 3`. -/
def smallC (i j : Nat) : Nat := i * j + 3

/-- Lane `l`'s arguments at `m16n8k8 .tf32`, written from the ISA's tables (section
9.7.16.5.14) with `g = l / 4`, `t = l % 4`: A registers at `(g, t)`, `(g + 8, t)`, `(g, t + 4)`,
`(g + 8, t + 4)`; B registers at `(t, g)`, `(t + 4, g)`; C registers at `(g, 2t)`,
`(g, 2t + 1)`, `(g + 8, 2t)`, `(g + 8, 2t + 1)`; each a 32-bit word. -/
def tfHand (l : Nat) : List Val :=
  let g := l / 4
  let t := l % 4
  let w (n : Nat) : Val := .bits 32 (BitVec.ofNat 32 n)
  [w (smallA g t), w (smallA (g + 8) t), w (smallA g (t + 4)), w (smallA (g + 8) (t + 4)),
    w (smallB t g), w (smallB (t + 4) g),
    w (smallC g (2 * t)), w (smallC g (2 * t + 1)), w (smallC (g + 8) (2 * t)),
    w (smallC (g + 8) (2 * t + 1))]

-- Every lane's D register `r` is the exact sum at the cell of C register `r` in the ISA's table.
#guard match mmaWarp mmaTf32 sumAcc tfHand with
  | some y => (List.range 32).all fun l =>
      let g := l / 4
      let t := l % 4
      [(g, 2 * t), (g, 2 * t + 1), (g + 8, 2 * t), (g + 8, 2 * t + 1)].zipIdx.all
        fun ((i, j), r) => resElem (.word 32) y l r 0 ==
          sumAcc (K := 8) (fun k => smallA i k.val) (fun k => smallB k.val j) (smallC i j)
  | none => false

/-- Lane `R`'s argument to `ldmatrix`: the pointer to byte `16 R` of block 1. -/
def rowArgs (R : Nat) : List Val := [.ptr ⟨1, 16 * R⟩]

/-- A reader of block 1 whose 16-bit element at byte `x` is `x / 2` (modulo `2 ^ 16`); other
blocks do not read. -/
def rdHalf (p : Ptr) : Option Nat :=
  if p.block = 1 then some (p.off.toNat / 2 % 2 ^ 16) else none

-- At `.x4` and `.x2`, both flags, every lane's registers are the elements `ldmatrix` gives.
#guard [(4, false), (4, true), (2, false), (2, true)].all fun (q, t) =>
  match ldmWarp q t rdHalf rowArgs with
  | some y => (List.range 32).all fun l => (List.range q).all fun r => (List.range 2).all
      fun s => resElem .pair y l r s ==
        ldmatrix q t (fun R => 16 * R) (fun x => x / 2 % 2 ^ 16) l r s
  | none => false
-- A row in block 2, which does not read, makes the step `none`.
#guard (ldmWarp 4 false rdHalf fun R => if R = 7 then [.ptr ⟨2, 0⟩] else rowArgs R).isNone

end MojoProofTest.TensorCoreWarp
