import MojoProof.Kernels.Formats

/-!
# Tests of the tactic mojo_map2_step: its facts found by type

`mojo_map2_step` (MojoProof/Kernels/Formats.lean) proves a goal `Map2.Step`
(MojoProof/Sym/Formats.lean) by mojo_ret, from a hypothesis `Map2.Pre …` and one `d ∣ e`, which it
finds by their types. Checked here:

* the first `example`: `vector_addition`'s threads at `.float`, the goal `vadd.family` hands it
  at that format, with the precondition and the alignment under other names than in
  MojoProof/Kernels/Formats.lean (`pre`, `four`) and the alignment `4 ∣ al` stated as
  `vadd.prog.layout.align (.fp .float) ∣ al`, which is `4 ∣ al` by definition;
* its open-goal twin: with the alignment behind an irreducible definition (`Div4`), the tactic
  finds no `d ∣ e`; mojo_ret logs as open (`mojo_ret: open goal`) the premises of the first path
  that need it, then fails on that path's store;
* the last `example`: with no hypothesis `Map2.Pre …` the tactic fails.
-/

namespace MojoProofTest.Map2Step

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProof.Kernels TorchLean
open FloatLib.Floats.Formats.BinaryInterchange

/-- **`vector_addition`'s threads at `.float` by mojo_map2_step**, its facts under other names:
for every launch whose grid and block have side 1 in `y` and `z`, alignment that the format's
divides, caller's memory of `Map2.Pre` at `.float` and oracle `ω`, each thread takes one of
`Paths.retype .float vadd.paths` to `ret` with `Elem` for the bytes `Elem.map2` of `Model.add`
at cells `4 i`. -/
example {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat}
    (four : vadd.prog.layout.align (.fp .float) ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.float.fmt) [N]} {m : Mem}
    (pre : Map2.Pre vadd.prog.layout (.fp .float) (Val.ofFloat .float) al vadd.argTail m a b out n
      x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vadd.prog.retype .float) (vadd.fn_0.retype vadd.prog.layout .float) L
      (Paths.retype .float vadd.paths) vadd.argTy 8 vadd.argTail (.fp .float)
      (Val.ofFloat .float) al a b out n x y ω 4 (fun i => 4 * i)
      (Elem.map2 vadd.prog.layout .float Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- `4 ∣ al`, behind an irreducible definition. -/
@[irreducible] def Div4 (al : Nat) : Prop := 4 ∣ al

/--
info: mojo_ret: open goal
  Cond.Holds ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
    (vals ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
      (Summary.retype FloatTy.float vadd.b1).nodes)
    (Cond.mem [SEff.load 21 3 (SVal.node 2), SEff.load 21 5 (SVal.node 4),
      SEff.store 21 8 (SVal.node 6) (SVal.node 7)])
---
info: mojo_ret: open goal
  Cond.Holds ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
    (vals ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
      (Summary.retype FloatTy.float vadd.b1).nodes)
    (Cond.ok (SVal.node 6))
---
info: mojo_ret: open goal
  Cond.Holds ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
    (vals ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
      (Summary.retype FloatTy.float vadd.b1).nodes)
    (Cond.ok (SVal.node 5))
---
info: mojo_ret: open goal
  Cond.Holds ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
    (vals ((Valuation.entry c✝ 0 m'✝ f✝).into 4 (Summary.retype FloatTy.float vadd.b0))
      (Summary.retype FloatTy.float vadd.b1).nodes)
    (Cond.ok (SVal.node 3))
---
error: mojo_obl: node 6 has no value
-/
#guard_msgs (whitespace := lax) in
/-- **The open-goal twin of the first `example`**: with the alignment stated as `Div4 al`,
behind an irreducible definition, and every thread below the count (`hn`), mojo_map2_step finds
no `d ∣ e`. No path is a `Ret` without the alignment, so mojo_ret takes the first path (block
`%4`, then `%21`) and logs as open the premises it needs: the alignment of `%21`'s two loads and
its store (`Cond.mem`) and the values of the loads and of the sum (`Cond.ok`); it then fails on
the store, whose value (node 6) it has not got. -/
example {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (four : Div4 al) {a b out n N : Nat}
    (hn : volume L.grid * volume L.block ≤ n) {x y : Tensor (Model LLVM.FloatTy.float.fmt) [N]}
    {m : Mem}
    (pre : Map2.Pre vadd.prog.layout (.fp .float) (Val.ofFloat .float) al vadd.argTail m a b out n
      x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vadd.prog.retype .float) (vadd.fn_0.retype vadd.prog.layout .float) L
      (Paths.retype .float vadd.paths) vadd.argTy 8 vadd.argTail (.fp .float)
      (Val.ofFloat .float) al a b out n x y ω 4 (fun i => 4 * i)
      (Elem.map2 vadd.prog.layout .float Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- **No precondition, no step**: without a hypothesis `Map2.Pre …`, mojo_map2_step fails. -/
example : True := by
  fail_if_success mojo_map2_step
  trivial

end MojoProofTest.Map2Step
