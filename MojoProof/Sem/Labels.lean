import MojoProof.Sem.Skeleton

/-!
# The labellings a program admits (T3b's `Labels.Ok` and `Labels.MemOk`)

The checks of docs/proofs/payload.md section T3b on a labelling `lab` (`Labels`: the payload
registers of each function and the functions with a payload result). An operand of function `fn`
is skeleton when it mentions no payload register of `fn` (`Value.mentions (lab.reg fn.name)`);
a constant is skeleton.

`Labels.Ok prog lab` checks each function of `prog` (`Labels.funcOk`) and each of its statements
(`Labels.stmtOk`); it is a `Bool`, evaluated by the kernel:
- (O1) every operand that decides control or an address is skeleton: `condBr` and `switch`
  conditions, `select` conditions, the pointer operands of `load`, `store` and `atomicrmw`,
  `getelementptr` bases and indices, `alloca` counts, `extractelement` and `insertelement`
  indices, `shufflevector` masks, and the arguments of intrinsic calls, but a `shfl.sync`'s
  exchanged value (its second argument) and the operands of `maxnum`, `minnum` and
  `rsqrt.approx`;
- (O2) a statement with a skeleton result has skeleton operands and reads no payload choice
  (`Scope.ch`): it is not `fadd`, `fsub`, `fmul`, `fdiv`, `frem`, `fpext`, `fptrunc`, `maxnum`,
  `minnum` or `rsqrt.approx`, and a call to a defined function with a payload result
  (`lab.ret`) has a payload result register;
- (O3) a statement with a payload result is an operation of `Op.Total` on operands that are
  registers or skeleton (`TValue.payOk`; LLVM's constants hold no register), skeleton at the
  positions of (O1): integer operations with `BinOp.total` flags, the shift amount or divisor
  skeleton if `BinOp.skelB`; `fbin`, `fneg` and `fcmp` without `nnan` and `ninf`; every `icmp`,
  cast, `select`, `phi`, `extractvalue`, `insertvalue`, `extractelement`, `insertelement` and
  `shufflevector`; `maxnum`, `minnum` and `rsqrt.approx` without `nnan` and `ninf`; a
  `shfl.sync`; a call to a defined function; an intrinsic call on skeleton arguments, an `alloca`
  or `getelementptr`, whose results are equal in the two runs; and a `load` of a data type
  (`Ty.data`). The declaration of a `maxnum`, `minnum`, `rsqrt.approx` or `shfl.sync` with a
  payload result has no `range` attribute on its result or parameters (`withAttrs` in `exec` and
  `resumeAll` would read the value; a waiting shuffle's arguments are related only up to its
  exchanged value, `Status.Skel`). A stored value, a payload argument and a returned payload
  operand are registers or skeleton too;
- (O4) a payload argument of a defined function goes to a payload parameter (an argument past
  the parameters is skeleton), a payload parameter or result has no `range` attribute, and a
  `ret` of a payload operand is in a function with a payload result. The arguments of a call to
  a function the module does not have are registers or skeleton (`exec` evaluates them before it
  refuses the call); a call of inline assembly passes (`exec` refuses it before it evaluates
  anything). A call through a pointer has no form in the AST (`Callee`): the parser refuses it.

The kernel's parameters need no condition: the two runs take the same arguments. Payload enters
through memory.

`Labels.MemOk lab pay L c g₀` holds when every grid that launch `L` with contexts `c` reaches from
`g₀` meets `Labels.MemAt` at each running thread's next statement (`Labels.MemAll`, by
`Labels.MemNext` at each thread, as `step_skel` reads it): a `load` with a skeleton result
reads a block outside `pay`, and a `store` or an `atomicrmw` of a payload operand writes a block
in `pay`. An `alloca` needs nothing: `pay` names blocks to be made too, and a store of payload
into the new block must then be in `pay`. `Labels.MemOk.of_closed`: it holds when a set of grids
holds `g₀`, is closed under `Grid.Step` and meets `Labels.MemAll` at each of its grids.

Tests (MojoProofTest/Labels.lean):
- `vadd_ok`: `vector_addition` (corpus `vadd/`) passes `Labels.Ok` with its two loaded floats and
  their sum payload; `vadd_twin`: with the stored pointer payload too, it fails (O1), and with the
  sum not payload, it fails (O2);
- `branch_twin`, the twin of (O1) for control: a `condBr` on a payload register fails
  `Labels.Ok`, and `step` on two frames related by `Frame.Skel` takes different edges, so the
  threads after are not related;
- `store_ok`: for every launch, on a one-thread grid that stores a payload register to block 1
  and returns, whose kernel passes `Labels.Ok`, `Labels.MemOk` holds with block 1 payload
  (`Labels.MemOk.of_closed`), and fails with no block payload;
- `payOk_twin`: a store of a vector that holds the payload register fails `Labels.Ok`;
- `shfl_range_twin`: a shuffle of a constant into a payload register passes `Labels.Ok`, and fails
  it when the declaration's result has a `range` attribute;
- `rsqrt_ok`: `rsqrt.approx` of a register into a payload register passes `Labels.Ok`, and fails
  it with `nnan`, with `ninf`, with a `range` result attribute, or into a skeleton register.
-/

namespace MojoProof.Sem

open LLVM

/-- Operand `v` of a function whose payload registers are `P` may be payload where (O3) allows
it: it is a register or skeleton. -/
def _root_.MojoProof.LLVM.TValue.payOk (P : Nat → Bool) : TValue → Bool
  | ⟨_, .loc _⟩ => true
  | v => !v.mentions P

/-- Whether statement `st` of function `fn` of program `prog` passes (O1), (O2) and (O3), and the
call part of (O4), under `lab` (the module docstring): `ops vs` holds when the operands `vs` are
skeleton, or, with a payload result, `TValue.payOk`. -/
def Labels.stmtOk (lab : Labels) (prog : Program) (fn : Func) (st : Stmt) : Bool :=
  let P := lab.reg fn.name
  let pr := st.res.any P
  let sk (v : TValue) : Bool := !v.mentions P
  let ops (vs : List TValue) : Bool := if pr then vs.all (·.payOk P) else vs.all sk
  let flags (fm : FastMath) : Bool := !pr || !fm.nnan && !fm.ninf
  match st.inst with
  | .bin op fl t a b => (!pr || op.total fl) && (!op.skelB || sk ⟨t, b⟩) && ops [⟨t, a⟩, ⟨t, b⟩]
  | .fbin _ fm t a b => pr && flags fm && ops [⟨t, a⟩, ⟨t, b⟩]
  | .fneg fm a => flags fm && ops [a]
  | .icmp _ t a b => ops [⟨t, a⟩, ⟨t, b⟩]
  | .fcmp fm _ t a b => flags fm && ops [⟨t, a⟩, ⟨t, b⟩]
  | .cast op a _ => (pr || !(op matches .fpext | .fptrunc)) && ops [a]
  | .select c a b => sk c && ops [a, b]
  | .phi t inc => ops (inc.map (⟨t, ·.1⟩))
  | .alloca _ cnt _ => cnt.all sk
  | .load _ t p _ => sk p && (!pr || t.data)
  | .store _ v p _ | .atomicrmw _ _ p v _ _ _ => sk p && v.payOk P
  | .gep _ _ b idx => sk b && idx.all sk
  | .extractvalue a _ => ops [a]
  | .insertvalue a e _ => ops [a, e]
  | .extractelement v i => sk i && ops [v]
  | .insertelement v e i => sk i && ops [v, e]
  | .shufflevector a b m => sk m && ops [a, b]
  | .call fm _ (.fn g) args => match prog.module.funcs.find? (·.name == g) with
    | none => args.all (·.1.payOk P)
    | some h =>
      if h.blocks.isEmpty then
        let noRange := (h.retAttrs ++ h.params.flatMap (·.attrs)).all (·.name != "range")
        match prog.intrinsics.lookup g with
        | some (.fminmax ..) => pr && flags fm && noRange && ops (args.map (·.1))
        | some (.shfl _) => (!pr || noRange) && args.zipIdx.all fun ((a, _), j) =>
          sk a || j == 1 && pr && a.payOk P
        | some .rsqrtApprox => pr && flags fm && noRange && ops (args.map (·.1))
        | _ => args.all (sk ·.1)
      else (!lab.ret g || pr) && args.zipIdx.all fun ((a, _), j) =>
        sk a || (h.params[j]?.any fun q => q.name.any (lab.reg g)) && a.payOk P
  | .call .. => true

/-- Whether function `fn` of program `prog` passes `Labels.Ok` under `lab`: each statement passes
`Labels.stmtOk`, each `condBr` and `switch` condition is skeleton (O1), each `ret` of a payload
operand, a register (`TValue.payOk`), is in a function with a payload result, and payload
parameters and results have no `range` attribute (O4). -/
def Labels.funcOk (lab : Labels) (prog : Program) (fn : Func) : Bool :=
  let P := lab.reg fn.name
  let sk (v : TValue) : Bool := !v.mentions P
  (!lab.ret fn.name || fn.retAttrs.all (·.name != "range")) &&
  fn.params.all (fun q => !q.name.any P || q.attrs.all (·.name != "range")) &&
  fn.blocks.all fun b => b.stmts.all (lab.stmtOk prog fn) && match b.term with
    | .ret v => v.all fun v => sk v || lab.ret fn.name && v.payOk P
    | .condBr c _ _ => sk ⟨.int 1, c⟩
    | .switch t v _ _ => sk ⟨t, v⟩
    | .br _ | .unreachable => true

/-- Labelling `lab` passes (O1) to (O4) on every function of `prog` (the module docstring). -/
def Labels.Ok (prog : Program) (lab : Labels) : Bool := prog.module.funcs.all (lab.funcOk prog)

/-- What statement `st` of function `fn` with scope `s` requires of the block its pointer operand
points to, for payload blocks `pay`: outside `pay` for a `load` with a skeleton result, inside for
a `store` or an `atomicrmw` of a payload operand. -/
def Labels.MemAt (lab : Labels) (pay : Nat → Prop) (s : Scope) (fn : Func) (st : Stmt) : Prop :=
  match st.inst with
  | .load _ _ (.mk (.ptr a) p) _ => st.res.any (lab.reg fn.name) = false →
    ∀ q, evalV s (.ptr a) p = .ok (.ptr q) → ¬ pay q.block
  | .store _ v (.mk (.ptr a) p) _ | .atomicrmw _ _ (.mk (.ptr a) p) v _ _ _ =>
    v.mentions (lab.reg fn.name) = true → ∀ q, evalV s (.ptr a) p = .ok (.ptr q) → pay q.block
  | _ => True

/-- Thread `t` meets `Labels.MemAt` at its next statement, with the scope of its first frame on
memory `m` under context `c` (as `step` evaluates it). -/
def Labels.MemNext (lab : Labels) (pay : Nat → Prop) (c : Ctx) (m : Mem) (t : Thread) : Prop :=
  ∀ f rest b st, t.frames = f :: rest → f.fn.blocks.find? (·.label == f.label) = some b →
    b.stmts[f.pc]? = some st → lab.MemAt pay (c.scope m f t.k) f.fn st

/-- Grid `g` meets `Labels.MemNext` at each running thread, thread `n` under context `c n`. -/
def Labels.MemAll (lab : Labels) (pay : Nat → Prop) (c : Nat → Ctx) (g : Grid) : Prop :=
  ∀ n t, g.threads[n]? = some (.run t) → lab.MemNext pay (c n) g.mem t

/-- The memory conditions of T3b (the module docstring): every grid that launch `L` with contexts
`c` reaches from `g₀` meets `Labels.MemAll`. -/
def Labels.MemOk (lab : Labels) (pay : Nat → Prop) (L : Launch) (c : Nat → Ctx) (g₀ : Grid) :
    Prop :=
  ∀ g, Relation.ReflTransGen (Grid.Step L c) g₀ g → lab.MemAll pay c g

/-- For every labelling, payload blocks, launch, contexts and set of grids that holds `g₀`, is
closed under `Grid.Step` and meets `Labels.MemAll` at each of its grids, `Labels.MemOk` holds
from `g₀`. -/
theorem Labels.MemOk.of_closed {lab : Labels} {pay : Nat → Prop} {L : Launch} {c : Nat → Ctx}
    {g₀ : Grid} (S : Grid → Prop) (h₀ : S g₀) (hS : ∀ g g', S g → Grid.Step L c g g' → S g')
    (hM : ∀ g, S g → lab.MemAll pay c g) : lab.MemOk pay L c g₀ := by
  intro g h
  refine hM g ?_
  induction h with
  | refl => exact h₀
  | tail _ hs ih => exact hS _ _ ih hs

end MojoProof.Sem
