import MojoProofTest.TensorCore
import MojoProof.Sem.TensorCoreAcc

/-!
# GPU runs of `mma.m16n8k16` with bfloat16 inputs and of `ldmatrix.x4` against the models

`lake env lean --run tests/gpu/mma/Compare.lean <dump> <launches>` runs `main` on the dump of
tests/gpu/mma/test_wmma.mojo: for each launch, the 32 lanes' A registers (4 words of two bfloat16
each), B registers (2 words) and C registers (4 binary32 words) the GPU was given, and the D
registers it wrote. For each lane `l` and D register `r` it evaluates
`mmaStep (fragA 2 2 2) (fragB 2 2) (fragC 2 1)` on the lanes' A, B and C registers three times:
with the measured policy `gridAcc .bfloat16 .binary32`, which is `fuseAcc .bfloat16 .binary32 8 24`
(`fuseAcc` in the output; `MojoProof.Sem.TensorCoreAcc`: blocks of 8 products,
each addend truncated to 24 bits below the largest one's leading power, the sum truncated toward
zero), a word; with the sequential policy `seqAcc .bfloat16 .binary32` (`bfAcc` in the output;
FloatLib's binary32 arithmetic, C then the products
`k = 0, …, 15` added in order), a word; and with `ratAcc`, the exact rational sum
`Σ_k a_k b_k + c` and the absolute sum `T`. It counts the D words equal to `fuseAcc`'s, bit for
bit, which must be all of them; those equal to `bfAcc`'s, which must be all of them in the
launches of kind 0 (small integers: every partial sum is exact, so every order of the additions
gives the same word); and the finite D words within `dotBound .binary32 16 T` of the exact sum
(`dotBoundQ`, equal to it by `dotBoundQ_eq`), the bound `bf16_ok` proves of `bfAcc`, which the
GPU does not meet. The layouts are the library's: if they placed an element where the hardware
does not, the kind-0 words would differ. For the launch of kind 5, the alignment probe, it
prints `D - 1` and the exact sum less 1 in units of `2^-23` at each distance of the probe's
small products.

It refuses a dump with a malformed case or a number of launches other than `<launches>`
(exit code 2). Exit code 0 when every D word is `fuseAcc`'s, every kind-0 word is `bfAcc`'s
and the GPU wrote every D word (none is the initial word); 1 otherwise.

`lake env lean --run tests/gpu/ldmatrix/Compare.lean <dump> <launches>` runs `ldmMain` on the
dump of tests/gpu/ldmatrix/test_ldmatrix.mojo: for each launch, the 512 16-bit words of shared
memory, the row addresses the 32 lanes gave, and the registers of `ldmatrix.x4` and of
`ldmatrix.x4.trans` from those addresses. It compares each 16-bit element with `ldmatrix 4`,
exit code 0 when all agree and the GPU wrote every register.

Conformance tests of one instruction each on these inputs and one GPU, not proofs.
-/

namespace MojoProofTest.TensorCoreGpu

open MojoProof.Sem MojoProofTest.TensorCore
open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange

/-- `dotBound .binary32 K T` over the rationals: `((1 + u) ^ (K + 1) - 1) T + (2 + u) η
((1 + u) ^ K - 1) / u` with binary32's `u = 2^-24` and `η = 2^-150`. -/
def dotBoundQ (K : Nat) (T : ℚ) : ℚ :=
  ((1 + 1 / 2 ^ 24) ^ (K + 1) - 1) * T +
    (2 + 1 / 2 ^ 24) * (1 / 2 ^ 150) * ((1 + 1 / 2 ^ 24) ^ K - 1) / (1 / 2 ^ 24)

/-- `dotBoundQ` is the contract's bound: for every `K` and rational `T`, its cast to the reals
is `dotBound .binary32 K T`. -/
theorem dotBoundQ_eq (K : Nat) (T : ℚ) : (dotBoundQ K T : ℝ) = dotBound .binary32 K T := by
  simp only [dotBoundQ, dotBound]
  push_cast
  norm_num [Model.unitRoundoffAt_eq, Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
    FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
    show FloatFormat.binary32.fracWidth = 23 by decide,
    show FloatFormat.binary32.exponentBias = 127 by decide]

/-- The exact accumulation on rationals, for every format and `K`: from `c`, C's value and its
absolute value, it adds each product `a_k b_k` of the `K` input pairs to the sum and `|a_k b_k|`
to the absolute sum, giving `(Σ_k a_k b_k + c, Σ_k |a_k b_k| + |c|)`; `none` when a word is not
finite (`toRat?`) or `c` is `none`. -/
def ratAcc {fi : FloatFormat} {K : Nat} (a b : Fin K → Model fi) (c : Option (ℚ × ℚ)) :
    Option (ℚ × ℚ) :=
  (List.finRange K).foldl (fun acc k => do
    let (s, t) ← acc
    let x ← (a k).toRat?
    let y ← (b k).toRat?
    pure (s + x * y, t + |x * y|)) c

/-- Element `s` (the 16 bits from bit `16 s`) of register `r` of lane `l` of a bfloat16 operand
with `n` registers to a lane, from the lanes' words `w` in order (`0` past the end). -/
def half (w : Array Nat) (n l r s : Nat) : Model .bfloat16 :=
  Model.ofNatBits (w.getD (n * l + r) 0 / 2 ^ (16 * s) % 2 ^ 16)

/-- Register `r` of lane `l` of the binary32 accumulator, four to a lane, from the lanes' words
`w` in order (`0` past the end). -/
def word (w : Array Nat) (l r : Nat) : Model .binary32 :=
  Model.ofNatBits (w.getD (4 * l + r) 0)

/-- One launch of the dump: its kind, the lanes' A, B and C words, the word D's buffer held
before the launch and the D words after it. -/
structure Case where
  /-- The launch from its kind, A, B and C words, initial word and D words. -/
  mk ::
  /-- The kind of the inputs (the driver's `bf16_half`, `f32_word` and `probe_half`). -/
  kind : Nat
  /-- The A words, 4 to a lane. -/
  a : Array Nat
  /-- The B words, 2 to a lane. -/
  b : Array Nat
  /-- The C words, 4 to a lane. -/
  c : Array Nat
  /-- Every word of D's buffer before the launch. -/
  init : Nat
  /-- The D words after the launch, 4 to a lane. -/
  d : Array Nat

/-- The numbers of the line `line` after its first token, which must be `tag`. -/
def nums (tag line : String) : Except String (List Nat) :=
  match (line.splitOn " ").filter (· ≠ "") with
  | t :: ws =>
    if t = tag then
      ws.mapM fun w => match w.toNat? with
        | some n => pure n
        | none => throw s!"not a number: {w}"
    else throw s!"expected {tag}: {line}"
  | [] => throw s!"expected {tag}: an empty line"

/-- The numbers of the line `line` after the tag `tag`, which must be `n` of them. -/
def numsOf (tag : String) (n : Nat) (line : String) : Except String (Array Nat) := do
  let ws ← nums tag line
  if ws.length = n then pure ws.toArray
  else throw s!"{tag}: {ws.length} numbers, expected {n}"

/-- The cases of the dump's lines: each line `case k` starts one, followed by its lines `a`
(128 words), `b` (64), `c` (128), `init` (one word) and `d` (128); other lines are skipped. -/
def parse : List String → Except String (List Case)
  | [] => pure []
  | l :: ls =>
    if l.startsWith "case" then
      match ls with
      | la :: lb :: lc :: li :: ld :: rest => do
        let [k] ← nums "case" l | throw s!"case: {l}"
        let [i] ← nums "init" li | throw s!"init: {li}"
        let c : Case := ⟨k, ← numsOf "a" 128 la, ← numsOf "b" 64 lb, ← numsOf "c" 128 lc, i,
          ← numsOf "d" 128 ld⟩
        return c :: (← parse rest)
      | _ => throw s!"a truncated case: {l}"
    else parse ls

/-- `seqAcc .bfloat16 .binary32`'s word (`bfAcc` in the output) for D register `r` of lane `l` of
the case `c`: `mmaStep` at `m16n8k16` on the lanes' registers. -/
def model (c : Case) (l r : Nat) : Nat :=
  (mmaStep (fragA 2 2 2) (fragB 2 2) (fragC 2 1) (seqAcc .bfloat16 .binary32 (K := 16))
    (half c.a 4) (half c.b 2) (fun l r _ => word c.c l r) l r 0).toNatBits

/-- `gridAcc .bfloat16 .binary32`'s word (`fuseAcc` in the output) for D register `r` of lane `l`
of the case `c`: `mmaStep` at `m16n8k16` on the lanes' registers. -/
def fused (c : Case) (l r : Nat) : Nat :=
  (mmaStep (K := 16) (fragA 2 2 2) (fragB 2 2) (fragC 2 1) (gridAcc .bfloat16 .binary32)
    (half c.a 4) (half c.b 2) (fun l r _ => word c.c l r) l r 0).toNatBits

/-- The exact sum and absolute sum `T` for D register `r` of lane `l` of the case `c`: `mmaStep`
at `m16n8k16` with `ratAcc` on the lanes' registers. -/
def exact (c : Case) (l r : Nat) : Option (ℚ × ℚ) :=
  mmaStep (K := 16) (fragA 2 2 2) (fragB 2 2) (fragC 2 1) ratAcc (half c.a 4) (half c.b 2)
    (fun l r _ => (word c.c l r).toRat?.map fun q => (q, |q|)) l r 0

/-- A nonnegative rational to three decimals, rounded down. -/
def dec (q : ℚ) : String :=
  let n := (q * 1000).floor.toNat
  let f := toString (n % 1000)
  s!"{n / 1000}.{"".pushn '0' (3 - f.length)}{f}"

/-- The 128 pairs `(lane, register)` of the D registers. -/
def regs : List (Nat × Nat) :=
  (List.range 32).flatMap fun l => (List.range 4).map fun r => (l, r)

/-- The counts of one case: D words equal to `fuseAcc`'s and to `bfAcc`'s; finite D words; those
within `dotBoundQ 16 T` of the exact sum; D words left at the initial word; the largest
`|D - exact| / (u T)` with `u = 2^-24`; a line for each word other than `fuseAcc`'s and one for
each finite word outside the bound. -/
structure Tally where
  /-- The counts from their values. -/
  mk ::
  /-- The D words equal to `fuseAcc`'s. -/
  fuse : Nat := 0
  /-- The D words equal to `bfAcc`'s. -/
  same : Nat := 0
  /-- The finite D words. -/
  finite : Nat := 0
  /-- The finite D words within the bound. -/
  within : Nat := 0
  /-- The D words equal to the initial word. -/
  unwritten : Nat := 0
  /-- The largest `|D - exact| / (u T)`, over the finite D words with `T > 0`. -/
  worst : ℚ := 0
  /-- A line for each finite D word outside the bound. -/
  outside : List String := []
  /-- A line for each D word other than `fuseAcc`'s. -/
  differ : List String := []

/-- The tally of the case `c`, numbered `n` in the dump. -/
def tally (n : Nat) (c : Case) : Tally :=
  regs.foldl (fun t (l, r) =>
    let g := c.d.getD (4 * l + r) 0
    let f := fused c l r
    let t := { t with same := t.same + (if g = model c l r then 1 else 0),
                      fuse := t.fuse + (if g = f then 1 else 0),
                      unwritten := t.unwritten + (if g = c.init then 1 else 0),
                      differ := if g = f then t.differ else t.differ ++
                        [s!"case {n} kind {c.kind} lane {l} register {r} cell \
                          {(fragC 2 1).pos l r 0}: D word {g}, fuseAcc word {f}"] }
    match (Model.ofNatBits g : Model .binary32).toRat?, exact c l r with
    | some v, some (s, a) =>
      let e := |v - s|
      let b := dotBoundQ 16 a
      let i := (fragC 2 1).pos l r 0
      { t with
        finite := t.finite + 1
        within := t.within + (if e ≤ b then 1 else 0)
        worst := if 0 < a then max t.worst (e * 2 ^ 24 / a) else t.worst
        outside := if e ≤ b then t.outside else t.outside ++
          [s!"case {n} kind {c.kind} lane {l} register {r} cell {i}: D word {g}, " ++
            s!"model word {model c l r}, |D - exact| / dotBound {dec (e / b)}, " ++
            s!"|D - exact| / (u T) {dec (e * 2 ^ 24 / a)}"] }
    | _, _ => t) {}

/-- The probe lines of the case `c`: for each distance `d` from 0 to 22, at the first cell
`(i, j)` with `i + j = d`, `D - 1` and the exact sum less 1 in units of `2^-23`; the probe's
small products are `(2 - 2^-7) 2^-(21 + d)`. -/
def probe (c : Case) : List String :=
  (List.range 23).filterMap fun d =>
    (regs.find? fun (l, r) => let i := (fragC 2 1).pos l r 0; i.1 + i.2 = d).bind
      fun (l, r) => do
        let v ← (Model.ofNatBits (c.d.getD (4 * l + r) 0) : Model .binary32).toRat?
        let (s, _) ← exact c l r
        let sgn (q : ℚ) := if q < 0 then "-" else ""
        pure s!"probe distance {21 + d}: D - 1 = {sgn (v - 1)}{dec (|v - 1| * 2 ^ 23)}, \
          exact - 1 = {sgn (s - 1)}{dec (|s - 1| * 2 ^ 23)} (units of 2^-23)"

/-- Compares every case of `cs` and prints a line for each, the lines of the words other than
`fuseAcc`'s (8 at most a case), of the words outside `dotBound` and of the probe, and a summary;
exit code 0 when every D word is `fuseAcc`'s, every kind-0 word is `bfAcc`'s and none is left at
the initial word, 1 otherwise. -/
def compare (cs : List Case) : IO UInt32 := do
  let mut off := 0
  let mut bad := 0
  let mut far := 0
  let mut left := 0
  for (c, n) in cs.zipIdx do
    let t := tally n c
    IO.println s!"case {n} kind {c.kind}: 128 words, {t.fuse} equal to fuseAcc's, {t.same} equal \
      to bfAcc's, {t.finite} finite, {t.within} within dotBound, worst |D - exact| / (u T) \
      {dec t.worst}"
    for s in t.differ.take 8 do IO.println s
    for s in t.outside do IO.println s
    if c.kind = 5 then
      for s in probe c do IO.println s
    off := off + (128 - t.fuse)
    if c.kind = 0 then bad := bad + (128 - t.same)
    far := far + (t.finite - t.within)
    left := left + t.unwritten
  IO.println s!"{cs.length} launches: {off} words differ from fuseAcc's, {bad} kind-0 words \
    differ from bfAcc's, {far} finite words outside dotBound, {left} words unwritten"
  return if off = 0 ∧ bad = 0 ∧ left = 0 then 0 else 1

/-- The entry point: `<dump> <launches>`; refuses a malformed dump or another number of
launches (exit code 2), else `compare`. -/
def main (args : List String) : IO UInt32 := do
  let [path, count] := args
    | IO.eprintln "usage: lean --run tests/gpu/mma/Compare.lean <dump> <launches>"; return 2
  let some expected := count.toNat?
    | IO.eprintln s!"not a number of launches: {count}"; return 2
  match parse (← IO.FS.lines path).toList with
  | .error e => IO.eprintln s!"{path}: {e}"; return 2
  | .ok cs =>
    if cs.length ≠ expected then
      IO.eprintln s!"{path}: {cs.length} launches, expected {expected}"; return 2
    compare cs

/-- A made-up case of kind 0: every A and B element 1 (`0x3f80`) and C 0, so each D word is 16
(`0x41800000`) on the GPU; and the same with D word 0 of lane 0 changed to 15. -/
private def ones (d0 : Nat) : Case :=
  ⟨0, .replicate 128 0x3f803f80, .replicate 64 0x3f803f80, .replicate 128 0, 0x7fbadbad,
    (Array.replicate 128 0x41800000).set! 0 d0⟩

-- Every D word of the made-up case is `fuseAcc`'s and `bfAcc`'s, finite and within the bound,
-- with error 0.
#guard let t := tally 0 (ones 0x41800000)
  t.fuse == 128 && t.same == 128 && t.finite == 128 && t.within == 128 && t.worst == 0 &&
    t.unwritten == 0
-- With D word 0 changed to 15, it differs from both models' words and is outside the bound, at
-- cell (0, 0).
#guard let t := tally 0 (ones 0x41700000)
  t.fuse == 127 && t.same == 127 && t.within == 127 && t.outside.length == 1 &&
    t.differ.length == 1
-- The parser reads a case and refuses a short `a` line.
#guard let z (n : Nat) := String.join (List.replicate n " 0")
  (parse ["seed 1", "case 0", "a" ++ z 128, "b" ++ z 64, "c" ++ z 128, "init 7",
    "d" ++ z 128]).toOption.map List.length == some 1
#guard (parse ["case 0", "a 0", "b", "c", "init 7", "d"]).toOption.isNone

/-! ## `ldmatrix.x4` -/

/-- One launch of the `ldmatrix` dump: the 512 16-bit words of shared memory, the 32 row
offsets in bytes (lane `R` gives row `R`), the word D's buffer held before the launch, and the
lanes' registers after it, 8 to a lane: the 4 of `ldmatrix.x4`, then the 4 of `.trans`. -/
structure LdmCase where
  /-- The launch from its shared words, row offsets, initial word and registers. -/
  mk ::
  /-- The 16-bit words of shared memory, the word at byte `x` numbered `x / 2`. -/
  mem : Array Nat
  /-- The byte offset of row `R`, given by lane `R`. -/
  rows : Array Nat
  /-- Every word of D's buffer before the launch. -/
  init : Nat
  /-- The registers after the launch, 8 to a lane. -/
  d : Array Nat

/-- The cases of the `ldmatrix` dump's lines: each line `case n` starts one, followed by its
lines `mem` (512 words), `rows` (32), `init` (one word) and `d` (256); other lines are
skipped. -/
def parseLdm : List String → Except String (List LdmCase)
  | [] => pure []
  | l :: ls =>
    if l.startsWith "case" then
      match ls with
      | lm :: la :: li :: ld :: rest => do
        let [i] ← nums "init" li | throw s!"init: {li}"
        let c : LdmCase := ⟨← numsOf "mem" 512 lm, ← numsOf "rows" 32 la, i, ← numsOf "d" 256 ld⟩
        return c :: (← parseLdm rest)
      | _ => throw s!"a truncated case: {l}"
    else parseLdm ls

/-- The model's element `s` of register `r` of lane `l` of the case `c`, with `.trans` when `t`:
`ldmatrix 4 t` with lane `R`'s row address `rows R` and the 16-bit word at byte `x` the word
`x / 2` of `mem`. -/
def ldmModel (c : LdmCase) (t : Bool) (l r s : Nat) : Nat :=
  ldmatrix 4 t (fun R => c.rows.getD R 0) (fun x => c.mem.getD (x / 2) 0) l r s

/-- The GPU's element `s` of register `r` of lane `l` of the case `c`, with `.trans` when `t`:
bits `16 s` to `16 s + 15` of the register's word. -/
def ldmGpu (c : LdmCase) (t : Bool) (l r s : Nat) : Nat :=
  c.d.getD (8 * l + (if t then 4 else 0) + r) 0 / 2 ^ (16 * s) % 2 ^ 16

/-- The 256 triples `(lane, register, element)` of an `ldmatrix.x4`. -/
def ldmElems : List (Nat × Nat × Nat) :=
  regs.flatMap fun (l, r) => [(l, r, 0), (l, r, 1)]

/-- The elements of the case `c`, with `.trans` when `t`, where the GPU and the model differ. -/
def ldmDiff (c : LdmCase) (t : Bool) : List (Nat × Nat × Nat) :=
  ldmElems.filter fun (l, r, s) => ldmGpu c t l r s ≠ ldmModel c t l r s

/-- Compares every case of `cs`, both loads, and prints a line for each and a summary; exit code
0 when every element agrees and no register word is left at the initial word, 1 otherwise. -/
def ldmCompare (cs : List LdmCase) : IO UInt32 := do
  let mut bad := 0
  let mut left := 0
  for (c, n) in cs.zipIdx do
    let p := (ldmDiff c false).length
    let q := (ldmDiff c true).length
    let u := (c.d.toList.filter (· = c.init)).length
    IO.println s!"case {n}: ldmatrix.x4 {256 - p} of 256 elements agree, ldmatrix.x4.trans \
      {256 - q} of 256 agree, {u} words unwritten"
    for (l, r, s) in (ldmDiff c false).take 4 do
      IO.println s!"case {n} x4 lane {l} register {r} element {s}: GPU {ldmGpu c false l r s}, \
        model {ldmModel c false l r s}"
    for (l, r, s) in (ldmDiff c true).take 4 do
      IO.println s!"case {n} x4.trans lane {l} register {r} element {s}: GPU \
        {ldmGpu c true l r s}, model {ldmModel c true l r s}"
    bad := bad + p + q
    left := left + u
  IO.println s!"{cs.length} launches: {bad} elements differ, {left} words unwritten"
  return if bad = 0 ∧ left = 0 then 0 else 1

/-- The entry point of the `ldmatrix` comparison: `<dump> <launches>`; refuses a malformed dump
or another number of launches (exit code 2), else `ldmCompare`. -/
def ldmMain (args : List String) : IO UInt32 := do
  let [path, count] := args
    | IO.eprintln "usage: lean --run tests/gpu/ldmatrix/Compare.lean <dump> <launches>"; return 2
  let some expected := count.toNat?
    | IO.eprintln s!"not a number of launches: {count}"; return 2
  match parseLdm (← IO.FS.lines path).toList with
  | .error e => IO.eprintln s!"{path}: {e}"; return 2
  | .ok cs =>
    if cs.length ≠ expected then
      IO.eprintln s!"{path}: {cs.length} launches, expected {expected}"; return 2
    ldmCompare cs

/-- A made-up case: shared word `i` is `i`, row `R` at byte `16 R` (the rows in order), and the
registers the ISA's layout gives: lane `l`'s register `r` holds elements `2 (l % 4)` and
`2 (l % 4) + 1` of row `8 r + l / 4`, and with `.trans` element `l / 4` of rows
`8 r + 2 (l % 4)` and `8 r + 2 (l % 4) + 1`. -/
private def inOrder : LdmCase :=
  ⟨.ofFn (n := 512) (·.val), .ofFn (n := 32) (16 * ·.val), 0x7fbadbad,
    .ofFn (n := 256) fun i =>
      let l := i.val / 8
      let r := i.val % 8 % 4
      let e (R C : Nat) := 8 * R + C
      if i.val % 8 < 4 then
        e (8 * r + l / 4) (2 * (l % 4)) + 2 ^ 16 * e (8 * r + l / 4) (2 * (l % 4) + 1)
      else e (8 * r + 2 * (l % 4)) (l / 4) + 2 ^ 16 * e (8 * r + 2 * (l % 4) + 1) (l / 4)⟩

-- The model agrees with the ISA's layout, written in its own form, on the made-up case.
#guard (ldmDiff inOrder false).isEmpty && (ldmDiff inOrder true).isEmpty
-- With lane 0's first register word set to 0, its element 1 (word 1 of row 0) differs.
#guard (ldmDiff { inOrder with d := inOrder.d.set! 0 0 } false).length == 1

end MojoProofTest.TensorCoreGpu
