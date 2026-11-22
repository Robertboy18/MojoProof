import MojoProof.LLVM.Mutate
import MojoProof.Kernels
import MojoProof.Kernels.Vmul
import MojoProofTest.Kernel

/-!
# Tests of the mutation harness (MojoProof/LLVM/Mutate.lean)

`table` is a test table: the Mojo LLVM operators that apply to vector_addition and
vector_multiply (icmp predicate swaps, constant-true conditional branch, getelementptr index plus
or minus one, store deletion, store redirection to a compatible pointer, byte-width changes of a
getelementptr's element, and the `noundef`, `range` and `inbounds` promises), with the identity
control. `vaddReport` and `vmulReport` run the harness on the two kernels with a budget of 32,
replayed on one launch and memory (`vaddAt`, `vmulAt`: `MojoProofTest/Kernel.lean`'s `L23`,
`mem5`, `ch₀`, `ω₀`); their reports are pinned below, every mutant with its outcome. The kills
with a theorem by `decide +kernel` (`vadd_m0` to `vadd_m7`, `vmul_m4`) are certified, and a test
checks that every index the reports list as certified has its theorem; the other refuted mutants
and those that pass are unknown. The certified kills are `Kills` values from `mojo_kills`; tests
check that `mojo_kills` refuses a wrong row (another mutant's theorem, another instance, another
kernel's mutant, another statement, a definition, the right program with another function, an
index beyond the selection, a mutant term of another shape), that its axioms check reports an
axiom left out of the allowed list, and that kills written by hand (the anonymous constructor, a
structure instance, the constructor's name, a list) are refused. Controls: the identity edit is
admitted and is the original; the smaller table `fourOps` of four operators (icmp swaps,
constant-true branch, index plus or minus one, store deletion) gives 9 candidates on vector
addition. A malformed edit (a branch to a local that is no block, or that the name table lacks,
or a getelementptr whose indices do not index its type) is classified malformed, and on
tiled_matmul, whose barrier calls the block checker refuses, an admitted mutant is unsupported.
-/

namespace MojoProofTest.Mutate

open MojoProof MojoProof.LLVM MojoProof.LLVM.Mutate
open MojoProofTest.Kernel (L23 mem5 ch₀ ω₀ x5 y5)

/-- The boundary swaps of the `icmp` predicates, both ways. -/
def swaps : List Op :=
  [.icmp .slt .sle, .icmp .sle .slt, .icmp .sgt .sge, .icmp .sge .sgt, .icmp .ult .ule,
    .icmp .ule .ult, .icmp .ugt .uge, .icmp .uge .ugt, .icmp .eq .ne, .icmp .ne .eq]

/-- The test table: the Mojo LLVM operators that apply to vector_addition and vector_multiply,
and the identity. -/
def table : List Op :=
  swaps ++ [.brTrue, .gepIdx 1, .gepIdx (-1), .storeDel, .storeTo, .gepTy (.fp .float) (.fp .half),
    .gepTy (.fp .float) (.fp .double), .inbounds, .dropAttr "noundef", .range (-1), .id]

/-- A smaller table of four operators: icmp swaps, constant-true branch, index plus or minus one,
store deletion. -/
def fourOps : List Op := swaps ++ [.brTrue, .gepIdx 1, .gepIdx (-1), .storeDel]

/-- The instance of `MojoProofTest.Kernel.correct23` for kernel function 0 (`fn`): 2 blocks of 3
threads (`L23`) with count 5 on `mem5` (inputs `x5`, `y5` at blocks 1 and 2, the output at block
3), address choice `ch₀`, oracle `ω₀`, 100 steps per thread and phase and 3 phases; block 3 ends
with the bytes `bs` at cell `4 i` of each of the 6 threads (`Sym.Elem.put`). -/
def at23 (fn : Func) (bs : Nat → Option (List Sem.MemByte)) : Instance :=
  ⟨0, fn, L23, Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5), mem5, ch₀, ω₀, 100, 3, 3,
    Sym.Elem.put (fun i => 4 * i) bs 6⟩

/-- vector_addition's instance: `at23` with the bytes of `Kernels.vadd.bytes ω₀ x5 y5 5`. -/
def vaddAt : Instance := at23 Kernels.vadd.fn_0 (Kernels.vadd.bytes ω₀ x5 y5 5)

/-- vector_multiply's instance: `at23` with the bytes of `Kernels.vmul.bytes ω₀ x5 y5 5`. -/
def vmulAt : Instance := at23 Kernels.vmul.fn_0 (Kernels.vmul.bytes ω₀ x5 y5 5)

/-- vector_addition's contract on `vaddAt`: `correct23`'s relation, `Sym.Elem.Out` on `mem5`
with the bytes `Kernels.vadd.bytes ω₀ x5 y5 5`. -/
abbrev vaddOut := Sym.Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 6

/-- vector_multiply's contract on `vmulAt`: `Sym.Elem.Out` on `mem5` with the bytes
`Kernels.vmul.bytes ω₀ x5 y5 5`. -/
abbrev vmulOut := Sym.Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vmul.bytes ω₀ x5 y5 5) 6

/-- The selected mutant `k` of vector_addition, as a program. -/
def vaddMutant (k : Nat) : Program :=
  ((selected table Kernels.vadd.prog 32)[k]!).program Kernels.vadd.prog

/-- The selected mutant `k` of vector_multiply, as a program. -/
def vmulMutant (k : Nat) : Program :=
  ((selected table Kernels.vmul.prog 32)[k]!).program Kernels.vmul.prog

mojo_mutant vadd.m0 := vaddMutant 0
mojo_mutant vadd.m1 := vaddMutant 1
mojo_mutant vadd.m2 := vaddMutant 2
mojo_mutant vadd.m3 := vaddMutant 3
mojo_mutant vadd.m4 := vaddMutant 4
mojo_mutant vadd.m5 := vaddMutant 5
mojo_mutant vadd.m6 := vaddMutant 6
mojo_mutant vadd.m7 := vaddMutant 7
mojo_mutant vmul.m4 := vmulMutant 4

-- The docstrings: a corpus program's cites its file and manifest digest; a mutant's cites the
-- mutant (its term, operator, site, index and the program it mutates) and the SHA-256 of its
-- printed module, which the test recomputes, and neither a corpus file nor the manifest.
open Lean in
/--
info: The program of the corpus file
`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`: its module,
its SHA-256 `8e4779ad54f40f0a4a38467397efdf29deaa0a4c39c35825e5c4eeb13b458b0c` (the file's
`MANIFEST.tsv` digest), its data layout, intrinsic declarations and kernel names. `mojo_import`'s
core checks, when it adds this term, that it evaluates to the importer's result and that its module
prints back to the file's tokens.
The program of the mutant `MojoProofTest.Mutate.vadd.m0` (the term `vaddMutant 0`: operator `icmp
slt->sle` at fn 0 %4 stmt 15, index 0 of `selected table Kernels.vadd.prog 32`, of the program
`Kernels.vadd.prog`), whose printed module has SHA-256
`22bc7d3a05d2249774d6f67468f4548c47114e3bb5ac141a9ec0d77db13c3d71` (added by `mojo_mutant`; no
corpus file or manifest row holds it): its module, and the data layout, intrinsic declarations,
kernel names and `sha256` field `8e4779ad54f40f0a4a38467397efdf29deaa0a4c39c35825e5c4eeb13b458b0c`
of the program it mutates (`Mutant.program` keeps them, so the field is that program's digest, not
the mutant's). `mojo_mutant` checks, when it adds this term, that it evaluates to the term's value
and that its module prints back to the printed module's tokens.
Block 0 (`%4`) of function 0 (`@vector_addition_vector_addition6A6A_793e5fe36a195e73`) of the mutant
`MojoProofTest.Mutate.vadd.m0` (the term `vaddMutant 0`: operator `icmp slt->sle` at fn 0 %4 stmt
15, index 0 of `selected table Kernels.vadd.prog 32`, of the program `Kernels.vadd.prog`), whose
printed module has SHA-256 `22bc7d3a05d2249774d6f67468f4548c47114e3bb5ac141a9ec0d77db13c3d71` (added
by `mojo_mutant`; no corpus file or manifest row holds it).
-/
#guard_msgs (whitespace := lax) in
run_meta do
  let doc (c : Name) : MetaM String := do
    let some d ← findDocString? (← getEnv) c | throwError "{c} has no docstring"
    return d
  let corpus ← doc ``Kernels.vadd.prog
  let mutant ← doc ``vadd.m0.prog
  let block ← doc ``vadd.m0.fn_0.b_0
  let digest := SHA256.hex (LLVM.print vadd.m0.module).toUTF8
  for d in [mutant, block] do
    unless (d.splitOn digest).length == 2 do throwError "no digest {digest} in: {d}"
    for w in ["corpus file `", "MANIFEST.tsv` digest", "tests/corpus"] do
      unless (d.splitOn w).length == 1 do throwError "'{w}' in: {d}"
  logInfo m!"{corpus}\n{mutant}\n{block}"

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 0 (`icmp slt` to `sle` in the bound check) is
refuted on `vaddAt` (thread 5 reads out of bounds). -/
theorem vadd_m0 : vaddAt.Refuted vadd.m0.prog vadd.m0.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 1 (the bound check's branch always taken). -/
theorem vadd_m1 : vaddAt.Refuted vadd.m1.prog vadd.m1.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 2 (the first load's index plus one). -/
theorem vadd_m2 : vaddAt.Refuted vadd.m2.prog vadd.m2.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 3 (the first load's index minus one). -/
theorem vadd_m3 : vaddAt.Refuted vadd.m3.prog vadd.m3.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 4 (the store deleted: the output stays stale). -/
theorem vadd_m4 : vaddAt.Refuted vadd.m4.prog vadd.m4.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 5 (the store redirected to an input). -/
theorem vadd_m5 : vaddAt.Refuted vadd.m5.prog vadd.m5.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 6 (the first load's element width halved). -/
theorem vadd_m6 : vaddAt.Refuted vadd.m6.prog vadd.m6.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_addition's mutant 7 (the first load's element width doubled). -/
theorem vadd_m7 : vaddAt.Refuted vadd.m7.prog vadd.m7.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

set_option profiler true in
/-- **Certified kill**: vector_multiply's mutant 4 (the store deleted). -/
theorem vmul_m4 : vmulAt.Refuted vmul.m4.prog vmul.m4.fn_0 vmulOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

-- The certified kills, each index with its theorem, which `mojo_kills` checks to be the
-- refutation of that index's mutant on the instance for the contract.
mojo_kills vaddKills : vaddMutant on vaddAt vaddOut :=
  [0 => vadd_m0, 1 => vadd_m1, 2 => vadd_m2, 3 => vadd_m3, 4 => vadd_m4, 5 => vadd_m5,
    6 => vadd_m6, 7 => vadd_m7]
mojo_kills vmulKills : vmulMutant on vmulAt vmulOut := [4 => vmul_m4]
#guard vaddKills.ks == [0, 1, 2, 3, 4, 5, 6, 7] && vmulKills.ks == [4]

-- Each certified mutant's term is the harness's selected mutant.
#guard [vadd.m0.prog, vadd.m1.prog, vadd.m2.prog, vadd.m3.prog, vadd.m4.prog, vadd.m5.prog,
    vadd.m6.prog, vadd.m7.prog].map (·.module) == vaddKills.ks.map (vaddMutant · |>.module)
#guard vmul.m4.prog.module == (vmulMutant 4).module

-- A wrong theorem fails the build: another mutant's (index 1 with `vadd_m0`), another instance
-- (`vmul_m4` on `vaddAt`), another kernel's mutant with the right instance (`vmul_m4` as
-- vector_addition's mutant 4), a theorem of another statement (`Nat.le_refl`) and a definition.
/--
error: mojo_kills: vadd_m0 does not refute mutant 1: its program vadd.m0.prog is not mutant 1's:
they differ in [module]
-/
#guard_msgs (whitespace := lax) in
mojo_kills bad1 : vaddMutant on vaddAt vaddOut := [1 => vadd_m0]
/-- error: mojo_kills: vmul_m4 does not refute mutant 4: its instance is vmulAt, not vaddAt -/
#guard_msgs (whitespace := lax) in
mojo_kills bad2 : vmulMutant on vaddAt vaddOut := [4 => vmul_m4]
/--
error: mojo_kills: vmul_m4 does not refute mutant 4: its program vmul.m4.prog is not mutant 4's:
they differ in [module, sha256, kernels]
-/
#guard_msgs (whitespace := lax) in
mojo_kills bad3 : vaddMutant on vmulAt vmulOut := [4 => vmul_m4]
/--
error: mojo_kills: Nat.le_refl does not refute mutant 2: its type
  ∀ (n : ℕ), n ≤ n
is not an `Instance.Refuted`
-/
#guard_msgs (whitespace := lax) in
mojo_kills bad4 : vaddMutant on vaddAt vaddOut := [0 => vadd_m0, 2 => Nat.le_refl]
/-- error: mojo_kills: vaddAt does not refute mutant 0: it is not a theorem -/
#guard_msgs (whitespace := lax) in
mojo_kills bad5 : vaddMutant on vaddAt vaddOut := [0 => vaddAt]

set_option profiler true in
/-- Mutant 0's program with mutant 4's kernel function (the store deleted) is refuted on
`vaddAt`: the right program for index 0 but another function, which `mojo_kills` refuses. -/
theorem vadd_m0_m4 : vaddAt.Refuted vadd.m0.prog vadd.m4.fn_0 vaddOut :=
  Instance.refutes (fun _ hB => hB.1) (by decide +kernel) (by decide +kernel)

-- More wrong rows: the right program with another function, an index beyond the selection, and a
-- mutant term that is not the selected mutants' programs.
/--
error: mojo_kills: vadd_m0_m4 does not refute mutant 0: its function vadd.m4.fn_0 is not function 0
of mutant 0
-/
#guard_msgs (whitespace := lax) in
mojo_kills bad6 : vaddMutant on vaddAt vaddOut := [0 => vadd_m0_m4]
/--
error: mojo_kills: vadd_m0 does not refute mutant 31: there are 31 mutants in
selected table Kernels.vadd.prog 32
-/
#guard_msgs (whitespace := lax) in
mojo_kills bad7 : vaddMutant on vaddAt vaddOut := [31 => vadd_m0]
/--
error: mojo_kills: fun x => vadd.m0.prog does not unfold to `Mutant.program P ms[k]!` with `P` and
`ms : List Mutant` free of `k`
-/
#guard_msgs (whitespace := lax) in
mojo_kills bad8 : (fun _ => vadd.m0.prog) on vaddAt vaddOut := [0 => vadd_m0]

-- The axioms check: `vadd_m0` depends on axioms of `killAxioms` only, and with any one of them
-- left out of the allowed list, `foreignAxiom` (mojo_kills' check) reports that one. No test
-- theorem depends on an axiom outside `killAxioms` (none is declared), so mojo_kills' refusal of
-- one is checked through `foreignAxiom` only.
run_meta do
  let axs ← Lean.collectAxioms ``vadd_m0
  if axs.isEmpty then Lean.throwError "vadd_m0 depends on no axioms"
  match ← foreignAxiom killAxioms ``vadd_m0 with
  | some b => Lean.throwError m!"vadd_m0 uses {b}"
  | none => pure ()
  for a in axs do
    unless (← foreignAxiom (killAxioms.erase a) ``vadd_m0) == some a do
      Lean.throwError "foreignAxiom does not report {a}"

/-- The type of vector_addition's kills on `vaddAt`, as `run` takes them. -/
abbrev VaddKills : Type :=
  Kills Kernels.vadd.prog (selected table Kernels.vadd.prog 32) (some vaddAt)

-- Kills cannot be written by hand: the constructor is private, so the anonymous constructor, a
-- structure instance (with or without `with`) and the constructor's name are refused, and a list
-- is not kills.
/--
error: Invalid `⟨...⟩` notation: Constructor for `MojoProof.LLVM.Mutate.Kills` is marked as private
-/
#guard_msgs (whitespace := lax) in
example : VaddKills := ⟨vaddOut, [0, 12]⟩
/--
error: invalid {...} notation, constructor for `Kills` is marked as private
-/
#guard_msgs (whitespace := lax) in
example : VaddKills := { rel := vaddOut, ks := [0, 12] }
/--
error: invalid {...} notation, constructor for `Kills` is marked as private
-/
#guard_msgs (whitespace := lax) in
example : VaddKills := { vaddKills with ks := [0, 12] }
/-- error: Unknown constant `MojoProof.LLVM.Mutate.Kills.mk` -/
#guard_msgs (whitespace := lax) in
example : VaddKills := Kills.mk vaddOut [0, 12]
/--
error: Application type mismatch: The argument
  [0, 12]
has type
  List ℕ
but is expected to have type
  optParam (Kills Kernels.vadd.prog (selected table Kernels.vadd.prog 32) (some vaddAt)) Kills.empty
in the application
  run table Kernels.vadd.prog 32 (some vaddAt) [0, 12]
-/
#guard_msgs (whitespace := lax) in
example : Report := run table Kernels.vadd.prog 32 (some vaddAt) ([0, 12] : List Nat)

-- The control: the identity mutant (11) replays with no violation.
#guard (vaddAt.replay (vaddMutant 11) Kernels.vadd.fn_0).passed

/-- The harness on vector_addition with the test table and a budget of 32, replayed on `vaddAt`
with the certified kills `vaddKills`. -/
def vaddReport : Report := run table Kernels.vadd.prog 32 (some vaddAt) vaddKills

/-- The harness on vector_multiply with the test table and a budget of 32, replayed on
`vmulAt`. -/
def vmulReport : Report := run table Kernels.vmul.prog 32 (some vmulAt) vmulKills

/-- `vaddReport` as text. -/
def vaddText : String := vaddReport.text

-- vector_addition replayed on `vaddAt`: the identity is equivalent; the replay refutes 17, of
-- which the 8 with a theorem (`vadd_m0` to `vadd_m7`) are certified kills and 9 are refuted by
-- evaluation only; 13 pass. Refuted and passing mutants are unknown.
/--
info: mutants: generated 31, selected 31, admitted 31, equivalent 1, conforming 0, killed 8, unknown 22
not admitted: malformed 0
admitted: duplicate 0, unsupported 0, infrastructure failure 0, timeout 0, open proof 0
admitted: killed 8, equivalent 1, conforming 0, survived 0
admitted, counted as unknown: refuted by evaluation (uncertified) 9, passes 13, unclassified 0
0: icmp slt->sle at fn 0 %4 stmt 15: killed, certified (undefined behavior at thread 5: access out of bounds)
1: br true at fn 0 %4 term: killed, certified (undefined behavior at thread 5: access out of bounds)
2: gep index +1 at fn 0 %21 stmt 2: killed, certified (undefined behavior at thread 4: access out of bounds)
3: gep index -1 at fn 0 %21 stmt 2: killed, certified (undefined behavior at thread 0: memory access through poison)
4: store delete at fn 0 %21 stmt 8: killed, certified (the output block differs from the contract's)
5: store redirect at fn 0 %21 stmt 8: killed, certified (undefined behavior at thread 0: store to read-only memory)
6: gep float->half at fn 0 %21 stmt 2: killed, certified (undefined behavior at thread 1: misaligned access)
7: gep float->double at fn 0 %21 stmt 2: killed, certified (undefined behavior at thread 3: memory access through poison)
8: inbounds toggle at fn 0 %21 stmt 2: passes (no violation)
9: drop noundef at fn 0 param 0: passes (no violation)
10: range upper -1 at fn 1 ret: passes (no violation)
11: identity at module: equivalent
12: gep index +1 at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 4: access out of bounds)
13: gep index -1 at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 0: memory access through poison)
14: store redirect at fn 0 %21 stmt 8: refuted by evaluation, uncertified (undefined behavior at thread 0: store to read-only memory)
15: gep float->half at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 1: misaligned access)
16: gep float->double at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 3: memory access through poison)
17: inbounds toggle at fn 0 %21 stmt 4: passes (no violation)
18: drop noundef at fn 0 param 1: passes (no violation)
19: range upper -1 at fn 2 ret: passes (no violation)
20: gep index +1 at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 4: access out of bounds)
21: gep index -1 at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 0: memory access through poison)
22: gep float->half at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 1: misaligned access)
23: gep float->double at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 3: memory access through poison)
24: inbounds toggle at fn 0 %21 stmt 7: passes (no violation)
25: drop noundef at fn 0 param 2: passes (no violation)
26: range upper -1 at fn 3 ret: passes (no violation)
27: drop noundef at fn 0 param 3: passes (no violation)
28: drop noundef at fn 1 ret: passes (no violation)
29: drop noundef at fn 2 ret: passes (no violation)
30: drop noundef at fn 3 ret: passes (no violation)
-/
#guard_msgs in
#eval IO.println vaddText

-- vector_multiply replayed on `vmulAt`: the same operators, sites and replay results; the one
-- certified kill is `vmul_m4`.
/--
info: mutants: generated 31, selected 31, admitted 31, equivalent 1, conforming 0, killed 1, unknown 29
not admitted: malformed 0
admitted: duplicate 0, unsupported 0, infrastructure failure 0, timeout 0, open proof 0
admitted: killed 1, equivalent 1, conforming 0, survived 0
admitted, counted as unknown: refuted by evaluation (uncertified) 16, passes 13, unclassified 0
0: icmp slt->sle at fn 0 %4 stmt 15: refuted by evaluation, uncertified (undefined behavior at thread 5: access out of bounds)
1: br true at fn 0 %4 term: refuted by evaluation, uncertified (undefined behavior at thread 5: access out of bounds)
2: gep index +1 at fn 0 %21 stmt 2: refuted by evaluation, uncertified (undefined behavior at thread 4: access out of bounds)
3: gep index -1 at fn 0 %21 stmt 2: refuted by evaluation, uncertified (undefined behavior at thread 0: memory access through poison)
4: store delete at fn 0 %21 stmt 8: killed, certified (the output block differs from the contract's)
5: store redirect at fn 0 %21 stmt 8: refuted by evaluation, uncertified (undefined behavior at thread 0: store to read-only memory)
6: gep float->half at fn 0 %21 stmt 2: refuted by evaluation, uncertified (undefined behavior at thread 1: misaligned access)
7: gep float->double at fn 0 %21 stmt 2: refuted by evaluation, uncertified (undefined behavior at thread 3: memory access through poison)
8: inbounds toggle at fn 0 %21 stmt 2: passes (no violation)
9: drop noundef at fn 0 param 0: passes (no violation)
10: range upper -1 at fn 1 ret: passes (no violation)
11: identity at module: equivalent
12: gep index +1 at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 4: access out of bounds)
13: gep index -1 at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 0: memory access through poison)
14: store redirect at fn 0 %21 stmt 8: refuted by evaluation, uncertified (undefined behavior at thread 0: store to read-only memory)
15: gep float->half at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 1: misaligned access)
16: gep float->double at fn 0 %21 stmt 4: refuted by evaluation, uncertified (undefined behavior at thread 3: memory access through poison)
17: inbounds toggle at fn 0 %21 stmt 4: passes (no violation)
18: drop noundef at fn 0 param 1: passes (no violation)
19: range upper -1 at fn 2 ret: passes (no violation)
20: gep index +1 at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 4: access out of bounds)
21: gep index -1 at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 0: memory access through poison)
22: gep float->half at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 1: misaligned access)
23: gep float->double at fn 0 %21 stmt 7: refuted by evaluation, uncertified (undefined behavior at thread 3: memory access through poison)
24: inbounds toggle at fn 0 %21 stmt 7: passes (no violation)
25: drop noundef at fn 0 param 2: passes (no violation)
26: range upper -1 at fn 3 ret: passes (no violation)
27: drop noundef at fn 0 param 3: passes (no violation)
28: drop noundef at fn 1 ret: passes (no violation)
29: drop noundef at fn 2 ret: passes (no violation)
30: drop noundef at fn 3 ret: passes (no violation)
-/
#guard_msgs in
#eval IO.println vmulReport.text



#guard vmulReport.results.map (fun (mu, _) => (mu.op, mu.site)) ==
  vaddReport.results.map (fun (mu, _) => (mu.op, mu.site))

/-! Controls. -/

-- The identity edit gives one mutant, admitted, whose AST is the original's.
#guard (Op.id.mutants Kernels.vadd.module).map
    (fun mu => (admission mu.module).toOption.map (·.module == Kernels.vadd.module)) == [some true]

-- The four operators of `fourOps` give 9 candidates on vector addition.
#guard (mutants fourOps Kernels.vadd.module).length == 9

-- With a budget of 4, the selection takes the first mutant of each of the first four operators
-- that apply.
#guard ((select (mutants fourOps Kernels.vadd.module) 4).map (·.op.label)) ==
  ["icmp slt->sle", "br true", "gep index +1", "gep index -1"]

/-- An edit of vector_addition: block `%21`'s terminator becomes `br` to local `l`. -/
def badBr (l : Nat) : Mutant :=
  ⟨.id, .term 0 1,
    { Kernels.vadd.module with funcs := Kernels.vadd.module.funcs.modify 0 (·.setTerm 1 (.br l)) }⟩

-- A branch to local `%0` (a parameter, no block) and to local 99 (the name table lacks it): both
-- are malformed.
/--
info: malformed (the terminator in block %21 of @vector_addition_vector_addition6A6A_793e5fe36a195e73 names no block)
malformed (the printed mutant does not import: line 34: empty name or NUL in a name)
-/
#guard_msgs in
#eval IO.println ("\n".intercalate ((classify Kernels.vadd.prog [badBr 0, badBr 99]).toList.map
  (·.2.label)))

-- `gepIdx 1` on field 0 of `{ i32 }` names field 1, which the struct lacks, and `gepTy` from
-- `{ i32 }` to `float` leaves an index into a float: admission admits the original and refuses
-- both mutants.
/--
info: admitted
a getelementptr in block %entry of @f does not index its type: field 1 of a 1-field struct
a getelementptr in block %entry of @f does not index its type: an index into float
-/
#guard_msgs in
#eval IO.println <|
  match parse ("define void @f(ptr %p) {\nentry:\n  %q = getelementptr { i32 }, ptr %p, i64 0, " ++
      "i32 0\n  ret void\n}\n").toUTF8 with
  | .error e => e
  | .ok m => "\n".intercalate <| (m :: (mutants [.gepIdx 1, .gepTy (.struct [.int 32]) (.fp .float)]
      m).map Mutant.module).map fun m' => match admission m' with
      | .ok _ => "admitted"
      | .error e => e

-- On tiled_matmul the block checker refuses a block (%40, at its getelementptr on the
-- shared-memory global), so a mutant is unsupported.
/--
info: mutants: generated 57, selected 1, admitted 1, equivalent 0, conforming 0, killed 0, unknown 1
not admitted: malformed 0
admitted: duplicate 0, unsupported 1, infrastructure failure 0, timeout 0, open proof 0
admitted: killed 0, equivalent 0, conforming 0, survived 0
admitted, counted as unknown: refuted by evaluation (uncertified) 0, passes 0, unclassified 0
0: inbounds toggle at fn 0 %3 stmt 25: unsupported (the block checker refuses block %40 of @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63)
-/
#guard_msgs in
#eval IO.println (run [.inbounds] Kernels.matmul.prog 1).text

end MojoProofTest.Mutate
