import MojoProof.Sym.Block
import MojoProof.LLVM.Printer

/-!
# `#mojo_info`: what the automation sees in a program

`#mojo_info P` prints, for every function of program `P` with blocks: the intrinsics it calls (the
direct callees that `P.intrinsics` names, each with its number of calls), the other functions it
calls (direct callees that are not intrinsics, each with its number of calls), its phases (the
number of `barrier` calls plus one), its back edges (a branch to a block at or before the
branching one, in the function's order: the loops), the float operators with their fast-math
flags, its fusable pairs (`fusable`: an `fadd` or `fsub` operand that an `fmul` computes, both with
the `contract` flag, so the compiler may fuse them into a multiply-add), and one line per block:
its name, its number of statements and of `phi`s, its successors, and the block checker's
verdict from after its `phi`s (`summarize`, MojoProof/Sym/Checker.lean): in the fragment, or the
first statement (or the terminator) outside it, printed as LLVM text.

Nothing here is trusted or proved: the command evaluates `info` with the compiler and prints it.
This module is executable code with no theorems.
-/

open Lean Elab Command Meta

namespace MojoProof.Sym

open MojoProof.LLVM

/-- The blocks a terminator may branch to. -/
def succs : LLVM.Term → List Nat
  | .br d => [d]
  | .condBr _ d e => [d, e]
  | .switch _ _ d cs => d :: cs.map (·.2)
  | _ => []

/-- The position of the first statement of block `b` of `fn` from position `p0` that the checker
refuses, the number of statements when the terminator is refused, `none` when the block is in
the fragment. It runs from the checker's start state (`SState.start`, the block's float
constants as nodes), as `summarizeWith` does. -/
def refusal (P : Program) (fn : Func) (b : LLVM.Block) (p0 : Nat) : Option Nat :=
  go (b.stmts.toList.drop p0) 0 (SState.start fn b.label p0 b)
where
  /-- From statements `sts`, `n` after `p0`, in state `σ`. -/
  go : List Stmt → Nat → SState → Option Nat
    | [], n, σ => if (σ.exitAt fn b.label b.term).isSome then none else some (p0 + n)
    | st :: sts, n, σ => match σ.stmt P b.label (p0 + n) n st with
      | some σ' => go sts (n + 1) σ'
      | none => some (p0 + n)

/-- A local's name as LLVM prints it. -/
def lname (fn : Func) (l : Nat) : String := "%" ++ Printer.name (fn.names.getD l "")

/-- The line of block `b` of `fn`. -/
def blockLine (P : Program) (fn : Func) (b : LLVM.Block) : String :=
  let p0 := (b.stmts.toList.takeWhile (·.inst matches .phi _ _)).length
  let verdict := match refusal P fn b p0 with
    | none => "in the fragment"
    | some i => match b.stmts[i]? with
      | some st => s!"outside the fragment at statement {i}: {Printer.stmt fn.names st}"
      | none => s!"outside the fragment at the terminator: {Printer.term fn.names b.term}"
  s!"  {lname fn b.label}: {b.stmts.size} statements, {p0} phis, to " ++
    s!"[{", ".intercalate ((succs b.term).map (lname fn))}]; {verdict}"

/-- The fast-math flag words of LLVM. -/
def flagWords : List String := ["nnan", "ninf", "nsz", "arcp", "contract", "afn", "reassoc", "fast"]

/-- The fusable pairs of `fn`: the operands of an `fadd` or `fsub` with the `contract` flag that
are the result of an `fmul` of `fn` with the `contract` flag (LangRef, "Fast-Math Flags":
`contract` on both allows the two to be fused into a multiply-add), counted once per operand. An
operand that is not such an `fmul`'s result (a constant, an argument, a `phi`, a cast of a
product) is not counted. -/
def fusable (fn : Func) : Nat :=
  let sts := fn.blocks.toList.flatMap (·.stmts.toList)
  let muls := sts.filterMap fun st => match st.res, st.inst with
    | some r, .fbin .fmul f _ _ _ => if f.contract then some r else none
    | _, _ => none
  let fused : Value → Bool
    | .loc r => muls.contains r
    | _ => false
  sts.foldl (fun n st => match st.inst with
    | .fbin .fadd f _ a b | .fbin .fsub f _ a b =>
      if f.contract then n + [a, b].countP fused else n
    | _ => n) 0

/-- The report of function `fn` of `P`. -/
def funcInfo (P : Program) (fn : Func) : List String :=
  let sts := fn.blocks.toList.flatMap (·.stmts.toList)
  let callees := sts.filterMap fun st => match st.inst with
    | .call _ _ (.fn g) _ => some g
    | _ => none
  let names := callees.eraseDups
  let intrinsic (g : String) : Bool := (P.intrinsics.lookup g).isSome
  let counted (gs : List String) : String :=
    ", ".intercalate (gs.map fun g => s!"@{g} ×{callees.count g}")
  let barriers := callees.countP fun g => P.intrinsics.lookup g matches some .barrier
  let pos (l : Nat) : Nat := (fn.blocks.toList.findIdx? (·.label == l)).getD 0
  let back := fn.blocks.toList.zipIdx.flatMap fun (b, i) =>
    (succs b.term).filter (pos · ≤ i) |>.map fun d => s!"{lname fn b.label} -> {lname fn d}"
  let floats := (sts.filterMap fun st => match st.inst with
    | .fbin .. => some <| match (Printer.inst fn.names st.inst).splitOn " " with
      | op :: rest => " ".intercalate (op :: rest.takeWhile (· ∈ flagWords))
      | [] => ""
    | _ => none).eraseDups
  [s!"@{fn.name}:",
   s!"  intrinsics: [{counted (names.filter intrinsic)}]",
   s!"  calls: [{counted (names.filter (!intrinsic ·))}]",
   s!"  phases: {barriers + 1}",
   s!"  back edges: [{", ".intercalate back}]",
   s!"  float operators: [{", ".intercalate floats}]",
   s!"  fusable pairs: {fusable fn}"] ++
    fn.blocks.toList.map (blockLine P fn)

/-- The report of `#mojo_info` on program `P`. -/
def info (P : Program) : String :=
  "\n".intercalate <| (P.module.funcs.toList.filter (!·.blocks.isEmpty)).flatMap (funcInfo P)

/-- `#mojo_info P` prints what the automation sees in program `P` (see the module docstring):
per function its intrinsics, other callees, phases, back edges, float operators and fusable pairs,
and per block the block checker's verdict. -/
syntax (name := mojoInfo) "#mojo_info " term : command

/-- Elaborates `#mojo_info`; `unsafe` because it evaluates the report. -/
@[command_elab mojoInfo] unsafe def elabMojoInfo : CommandElab := fun stx => liftTermElabM do
  let P ← Lean.Elab.Term.elabTermEnsuringType stx[1] (mkConst ``MojoProof.LLVM.Program)
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let P ← instantiateMVars P
  let s := info (← evalExpr Program (mkConst ``MojoProof.LLVM.Program) P)
  if s.isEmpty then throwError "#mojo_info: the program has no function with blocks"
  logInfo s

end MojoProof.Sym
