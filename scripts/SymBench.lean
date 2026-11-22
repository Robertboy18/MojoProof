import MojoProof.Kernels
import MojoProof.Sym.Command
import MojoProof.LLVM.Quote

/-!
# Benchmark of the block checker (docs/automation.md, "Benchmark")

Run from the repository root, after `lake build MojoProof MojoProofKernels`, with
`lake env lean scripts/SymBench.lean` (peak RSS about 4.5 GB). The exit status is 0 when every
command succeeds, the expected failures below included. Not part of the build.

Each `#ktime n : p` adds theorem `n : p` with the proof `decide +kernel` builds
(`of_decide_eq_true (Eq.refl true)`) and prints the time of `addDecl` (the kernel's check:
elaboration of the instance is outside it) and the process's peak RSS (`VmHWM`) before and
after. Each `#etime c` runs command `c` (a theorem proved
by an elaborator tactic, then checked by the kernel) and prints its time and peak RSS.
`Elab.async` is off, so the kernel's check happens inside the timed call.

* `vadd`: `vector_addition`'s blocks `%21`, `%30`, `%31`.
* `wide n`: `n` statements `%(1000+n+i) = add i32 %(1000+i), 1`, each on an entry register:
  terms of size 3, `n` distinct obligations.
* `chain n`: `n` statements `%(1001+i) = add i32 %(1000+i), 1`: node `i` refers to node `i-1`;
  the table has `n` nodes of constant size.
* `twice n`: `n` statements `%(1001+i) = add i32 %(1000+i), %(1000+i)`, each using the value
  before twice: as a tree the `i`-th value has `2^(i+1) - 1` nodes; in the table it is one node
  that refers to node `i-1` twice. `et n`: the kernel evaluates the obligations of `twice n` on
  a valuation where `%1000` is the word 1 (`vals`: each node evaluated once).
* `sels n`: `n` statements `%(1001+i) = select i1 %0, i32 %(1000+i), i32 1`: a chain of
  `select` nodes, as `chain n`.
* `naive6`: the entry block `%6` of the naive matmul kernel
  (`tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll`),
  37 statements with an `llvm.smax` call and a `select`.
* `loads n`: `n` loads through entry register `%0` with `!invariant.load` (`checkMd` compares the
  key with strings) and the same without metadata.
* `extra k`: `wide 50` with `k` distinct conditions after the summary's own in `ds` (the check
  is by position: the summary's obligations come first).
* `mm67`: `tiled_matmul`'s largest block `%67` (208 statements), statements 1 to 191 (between its
  two barriers), with three changes that bring it into the fragment: a `getelementptr` on a global
  is on entry register `%0` instead, a float constant operand is entry register `%1`, and
  `fmul contract` is `fmul` without `contract`. 191 statements, 32 loads, 32 `getelementptr`s,
  16 `fmul`s and 16 `fadd contract`s. `km67real`: `summarize` on the block itself is `none` (it
  starts with a barrier call).
* `mm67c`: `mm67` with its 16 `fmul contract`s kept, checked by `coversC` (each `fadd contract`
  node then reads its product's operand terms, `SNode.fbinP`). `naive52`: the latch `%52` of the
  naive matmul kernel (14 statements, an `fmul contract` and the `fadd contract` that reads it),
  by `coversC`. Their summaries are definitions (`summarizeC`; `sym_summary` writes `summarize`'s
  only), which the kernel unfolds, so their times include computing the summary once more.
* the elaborator: `decide`, `rfl` and `simp` with `decide := true` on the same propositions.
  `rm67`: the elaborator's `rfl` fails on `mm67`, asserted by `fail_if_success` (the run fails
  if it succeeds), and the theorem is `km67`. `rw100`: `rfl` on `wide 100` reaches the maximum
  recursion depth, an error `fail_if_success` does not catch, so `#guard_msgs` asserts its
  message (the run fails on another outcome) and no theorem `rw100` is added.
* names: `k` comparisons of an intrinsic's name as `String` and as `Nat`, and `k` times the two
  lookups by name `exec` makes for a call (`Program.module.funcs.find?` and
  `Program.intrinsics.lookup`) against `k` lookups by index.
-/

open Lean Elab Command Meta
open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

set_option Elab.async false

/-- The process's peak resident set size so far, in kB (`VmHWM` of `/proc/self/status`). -/
def hwm : IO Nat := do
  let s ← IO.FS.readFile "/proc/self/status"
  for l in s.splitOn "\n" do
    if l.startsWith "VmHWM:" then
      return (String.ofList (l.toList.filter Char.isDigit)).toNat!
  return 0

/-- `#ktime n : p`: theorem `n : p` by the kernel's evaluation of `decide p`, timed. -/
elab "#ktime " n:ident " : " t:term : command => do
  let (ty, pf) ← liftTermElabM do
    let ty ← Term.elabTerm t (some (mkSort .zero))
    Term.synthesizeSyntheticMVarsNoPostponing
    let ty ← instantiateMVars ty
    return (ty, ← instantiateMVars (← mkDecideProof ty))
  let h0 ← hwm
  let t0 ← IO.monoNanosNow
  liftCoreM <| addDecl (.thmDecl { name := n.getId, levelParams := [], type := ty, value := pf })
  let t1 ← IO.monoNanosNow
  let h1 ← hwm
  logInfo m!"{n.getId}: kernel {(t1 - t0) / 1000000} ms, VmHWM {h0} -> {h1} kB"

/-- `#etime c`: command `c`, timed. -/
elab "#etime " c:command : command => do
  let h0 ← hwm
  let t0 ← IO.monoNanosNow
  elabCommand c
  let t1 ← IO.monoNanosNow
  let h1 ← hwm
  logInfo m!"elaboration and kernel {(t1 - t0) / 1000000} ms, VmHWM {h0} -> {h1} kB"

/-- A function of `vector_addition` with one block, label 0, of statements `sts`, `ret void`. -/
def bfn (sts : List Stmt) : Func :=
  { Kernels.vadd.fn_0 with blocks := #[⟨0, sts.toArray, .ret none⟩] }

/-- `n` independent `add`s. -/
def wide (n : Nat) : Func := bfn <| (List.range n).map fun i =>
  ⟨some (1000 + n + i), .bin .add {} (.int 32) (.loc (1000 + i)) (.int 1), []⟩

/-- `n` chained `add`s. -/
def chain (n : Nat) : Func := bfn <| (List.range n).map fun i =>
  ⟨some (1001 + i), .bin .add {} (.int 32) (.loc (1000 + i)) (.int 1), []⟩

/-- `n` chained integer `select`s on the entry register `%0`. -/
def sels (n : Nat) : Func := bfn <| (List.range n).map fun i =>
  ⟨some (1001 + i), .select (.mk (.int 1) (.loc 0)) (.mk (.int 32) (.loc (1000 + i)))
    (.mk (.int 32) (.int 1)), []⟩

/-- `n` loads through `%0`, with metadata `md`. -/
def loads (n : Nat) (md : List (String × Nat)) : Func := bfn <| (List.range n).map fun i =>
  ⟨some (2000 + i), .load false (.fp .float) (.mk (.ptr 1) (.loc 0)) (some 4), md⟩

/-- `n` chained `add`s, each of the value before with itself. -/
def twice (n : Nat) : Func := bfn <| (List.range n).map fun i =>
  ⟨some (1001 + i), .bin .add {} (.int 32) (.loc (1000 + i)) (.loc (1000 + i)), []⟩

/-- A valuation on `vector_addition`'s program and function `fn` where `%1000` is the word 1. -/
def V1 (fn : Func) : Valuation :=
  ⟨⟨Kernels.vadd.prog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0, fun _ => 0⟩, fn, 0,
    {}, fun r => if r = 1000 then some (.bits 32 1) else none, fun _ => none⟩

/-- `k` distinct conditions. -/
def extra (k : Nat) : List Cond := (List.range k).map fun i => .ok (.int 32 i)

/-- `tiled_matmul`'s kernel function. -/
def mmFn : Func := (Kernels.matmul.prog.module.funcs.toList.find? (!·.blocks.isEmpty)).getD
  Kernels.vadd.fn_0

/-- An operand in the fragment: a global is `%0`, a float constant `%1`. -/
def tweakV : Value → Value
  | .glob _ => .loc 0
  | .float _ => .loc 1
  | v => v

/-- Flags `fm` of float operator `op`, without `contract` on `fmul`. -/
def dropContract (op : FBinOp) (fm : FastMath) : FastMath :=
  if op == .fmul then { fm with contract := false } else fm

/-- A statement of `%67` brought into the fragment. -/
def tweak (st : Stmt) : Stmt := match st.inst with
  | .gep fl src (.mk t b) idx => { st with inst := .gep fl src (.mk t (tweakV b)) idx }
  | .fbin op fm t a b => { st with inst := .fbin op (dropContract op fm) t (tweakV a) (tweakV b) }
  | _ => st

/-- A statement of `%67` brought into the fragment of `coversC`: `tweak` with the flags of
`fmul contract` kept. -/
def tweakC (st : Stmt) : Stmt := match st.inst with
  | .fbin op fm t a b => { st with inst := .fbin op fm t (tweakV a) (tweakV b) }
  | _ => tweak st

/-- The label of `tiled_matmul`'s block `%67`. -/
def l67 : Nat := ((mmFn.blocks.find? (mmFn.names[·.label]? == some "67")).map (·.label)).getD 0

/-- Block `%67`'s statements 1 to 191, brought into the fragment, as one block. -/
def mm67 : Func :=
  let b := (mmFn.blocks.find? (mmFn.names[·.label]? == some "67")).getD ⟨0, #[], .ret none⟩
  { mmFn with blocks := #[⟨0, (b.stmts.extract 1 192).map tweak, .ret none⟩] }

/-- `mm67` with its `fmul contract`s kept (`tweakC`), in the fragment of `coversC`. -/
def mm67c : Func :=
  let b := (mmFn.blocks.find? (mmFn.names[·.label]? == some "67")).getD ⟨0, #[], .ret none⟩
  { mmFn with blocks := #[⟨0, (b.stmts.extract 1 192).map tweakC, .ret none⟩] }

-- matmul: its blocks (name, size, position after the phis, in the fragment from there)
#eval mmFn.blocks.toList.map fun b =>
  let p0 := (b.stmts.toList.takeWhile (·.inst matches .phi _ _)).length
  (mmFn.names[b.label]?, b.stmts.size, p0, (summarize Kernels.matmul.prog mmFn b.label p0).isSome)
#eval (mm67.blocks[0]!.stmts.size, (summarize Kernels.matmul.prog mm67 0 0).isSome)

#etime sym_summary s21 := Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
sym_summary s30 := Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_2.label 0
sym_summary s31 := Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_3.label 0
sym_summary w10 := Kernels.vadd.prog (wide 10) 0 0
sym_summary w25 := Kernels.vadd.prog (wide 25) 0 0
sym_summary w50 := Kernels.vadd.prog (wide 50) 0 0
sym_summary w100 := Kernels.vadd.prog (wide 100) 0 0
sym_summary w200 := Kernels.vadd.prog (wide 200) 0 0
sym_summary c25 := Kernels.vadd.prog (chain 25) 0 0
sym_summary c50 := Kernels.vadd.prog (chain 50) 0 0
sym_summary c100 := Kernels.vadd.prog (chain 100) 0 0
sym_summary t25 := Kernels.vadd.prog (twice 25) 0 0
sym_summary t50 := Kernels.vadd.prog (twice 50) 0 0
sym_summary t100 := Kernels.vadd.prog (twice 100) 0 0
sym_summary t200 := Kernels.vadd.prog (twice 200) 0 0
sym_summary l50md := Kernels.vadd.prog (loads 50 [("invariant.load", 1)]) 0 0
sym_summary l50 := Kernels.vadd.prog (loads 50 []) 0 0
#etime sym_summary sm67 := Kernels.matmul.prog mm67 0 0
sym_summary sl50 := Kernels.vadd.prog (sels 50) 0 0
mojo_import "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll"
  as naive
sym_summary sn6 := naive.prog naive.fn_0 naive.fn_0.b_0.label 0
/-- `mm67c`'s summary with `fmul contract` in the fragment (`summarizeC`). -/
def sm67c : Summary := (summarizeC Kernels.matmul.prog mm67c 0 0).getD default
/-- The naive kernel's latch `%52`'s summary with `fmul contract` in the fragment
(`summarizeC`). -/
def sn52 : Summary := (summarizeC naive.prog naive.fn_0 naive.fn_0.b_6.label 0).getD default
#eval ((summarize Kernels.matmul.prog mm67c 0 0).isSome, sm67c.nodes.length, sn52.nodes.length)

-- the kernel
#ktime k21 : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
  s21.obls s21 = true
#ktime k30 : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_2.label 0
  s30.obls s30 = true
#ktime k31 : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_3.label 0
  s31.obls s31 = true
#ktime km67 : covers Kernels.matmul.prog mm67 0 0 sm67.obls sm67 = true
#ktime km67real : summarize Kernels.matmul.prog mmFn l67 0 = none
#ktime kw10 : covers Kernels.vadd.prog (wide 10) 0 0 w10.obls w10 = true
#ktime kw25 : covers Kernels.vadd.prog (wide 25) 0 0 w25.obls w25 = true
#ktime kw50 : covers Kernels.vadd.prog (wide 50) 0 0 w50.obls w50 = true
#ktime kw100 : covers Kernels.vadd.prog (wide 100) 0 0 w100.obls w100 = true
#ktime kw200 : covers Kernels.vadd.prog (wide 200) 0 0 w200.obls w200 = true
#ktime kc25 : covers Kernels.vadd.prog (chain 25) 0 0 c25.obls c25 = true
#ktime kc50 : covers Kernels.vadd.prog (chain 50) 0 0 c50.obls c50 = true
#ktime kc100 : covers Kernels.vadd.prog (chain 100) 0 0 c100.obls c100 = true
#ktime kt25 : covers Kernels.vadd.prog (twice 25) 0 0 t25.obls t25 = true
#ktime kt50 : covers Kernels.vadd.prog (twice 50) 0 0 t50.obls t50 = true
#ktime kt100 : covers Kernels.vadd.prog (twice 100) 0 0 t100.obls t100 = true
#ktime kt200 : covers Kernels.vadd.prog (twice 200) 0 0 t200.obls t200 = true
#ktime et25 : ∀ d ∈ t25.obls, d.Holds (V1 (twice 25)) (vals (V1 (twice 25)) t25.nodes)
#ktime et50 : ∀ d ∈ t50.obls, d.Holds (V1 (twice 50)) (vals (V1 (twice 50)) t50.nodes)
#ktime et100 : ∀ d ∈ t100.obls, d.Holds (V1 (twice 100)) (vals (V1 (twice 100)) t100.nodes)
#ktime et200 : ∀ d ∈ t200.obls, d.Holds (V1 (twice 200)) (vals (V1 (twice 200)) t200.nodes)
#ktime ks50 : covers Kernels.vadd.prog (sels 50) 0 0 sl50.obls sl50 = true
#ktime kn6 : covers naive.prog naive.fn_0 naive.fn_0.b_0.label 0 sn6.obls sn6 = true
#ktime km67c : coversC Kernels.matmul.prog mm67c 0 0 sm67c.obls sm67c = true
#ktime kn52 : coversC naive.prog naive.fn_0 naive.fn_0.b_6.label 0 sn52.obls sn52 = true
#ktime kl50md : covers Kernels.vadd.prog (loads 50 [("invariant.load", 1)]) 0 0
  l50md.obls l50md = true
#ktime kl50 : covers Kernels.vadd.prog (loads 50 []) 0 0 l50.obls l50 = true
#ktime kd100 : covers Kernels.vadd.prog (wide 50) 0 0 (w50.obls ++ extra 100) w50 = true
#ktime kd1000 : covers Kernels.vadd.prog (wide 50) 0 0 (w50.obls ++ extra 1000) w50 = true
#ktime kfalse21 : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
  s21.obls.tail s21 = false

-- the elaborator
#etime theorem d21 : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
    s21.obls s21 = true := by decide
#etime theorem r21 : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
    s21.obls s21 = true := by rfl
#etime theorem s21' : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
    s21.obls s21 = true := by
  simp (config := { decide := true }) [covers, coversWith, summarize, summarizeWith, SState.run,
    SState.stmt, SState.exit, SState.exitAt, entersAt]
#etime theorem dw10 : covers Kernels.vadd.prog (wide 10) 0 0 w10.obls w10 = true := by decide
#etime theorem dw25 : covers Kernels.vadd.prog (wide 25) 0 0 w25.obls w25 = true := by decide
#etime theorem dw50 : covers Kernels.vadd.prog (wide 50) 0 0 w50.obls w50 = true := by decide
#etime theorem rw10 : covers Kernels.vadd.prog (wide 10) 0 0 w10.obls w10 = true := by rfl
#etime theorem rw25 : covers Kernels.vadd.prog (wide 25) 0 0 w25.obls w25 = true := by rfl
#etime theorem rw50 : covers Kernels.vadd.prog (wide 50) 0 0 w50.obls w50 = true := by rfl
#etime /--
error: maximum recursion depth has been reached
use `set_option maxRecDepth <num>` to increase limit
use `set_option diagnostics true` to get diagnostic information
-/
#guard_msgs in
theorem rw100 : covers Kernels.vadd.prog (wide 100) 0 0 w100.obls w100 = true := by rfl
#etime theorem sw10 : covers Kernels.vadd.prog (wide 10) 0 0 w10.obls w10 = true := by
  simp (config := { decide := true }) [covers, coversWith, summarize, summarizeWith, SState.run,
    SState.stmt, SState.exit, SState.exitAt, entersAt]
#etime theorem sw25 : covers Kernels.vadd.prog (wide 25) 0 0 w25.obls w25 = true := by
  simp (config := { decide := true }) [covers, coversWith, summarize, summarizeWith, SState.run,
    SState.stmt, SState.exit, SState.exitAt, entersAt]
#etime theorem rm67 : covers Kernels.matmul.prog mm67 0 0 sm67.obls sm67 = true := by
  fail_if_success rfl
  exact km67

-- names
#ktime str100 : (List.replicate 100 "llvm.nvvm.read.ptx.sreg.tid.x").all
  (· == "llvm.nvvm.read.ptx.sreg.tid.x") = true
#ktime str1000 : (List.replicate 1000 "llvm.nvvm.read.ptx.sreg.tid.x").all
  (· == "llvm.nvvm.read.ptx.sreg.tid.x") = true
#ktime strne1000 : (List.replicate 1000 "llvm.nvvm.read.ptx.sreg.tid.x").all
  (· != "llvm.nvvm.read.ptx.sreg.tid.y") = true
#ktime nat1000 : (List.replicate 1000 4711).all (· == 4711) = true
#ktime call100 : (List.replicate 100 "llvm.nvvm.read.ptx.sreg.tid.x").all (fun g =>
  (Kernels.vadd.prog.module.funcs.find? (·.name == g)).isSome &&
    (Kernels.vadd.prog.intrinsics.lookup g).isSome) = true
#ktime idx100 : (List.replicate 100 0).all
  (fun j => (Kernels.vadd.prog.module.funcs[j]?).isSome) = true
#eval (Kernels.vadd.prog.module.funcs.map (·.name), Kernels.matmul.prog.module.funcs.size)
