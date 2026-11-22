import MojoProofTest.SymPhi
import MojoProof.Sym.Vals

/-!
# mojo_obl and mojo_vals on the naive matrix product's blocks

The naive matrix product (`naive` of MojoProofTest/SymPhi.lean, the corpus's naive matrix
product of binary32) starts its loop from the preheader `%45` (`pre` of the same file), whose
summary has one node, the float constant `0.000000e+00` at type `float` that the header's `phi`
`%48` takes.

* `pre_obls`: mojo_obl proves `%45`'s obligations at every valuation: the word 0, node 0 (the
  float constant, by `SNode.eval_flit` and the kernel's evaluation of `floatLit`) and its effects
  (none).
* `pre_vals`, `pre_vals_lit`: mojo_vals proves `%45`'s node values at every valuation, as the
  float `0` and as the literal's value `floatLit`.
* `flitS`, `flit_open`: a summary whose float constant is an unknown literal; mojo_obl leaves its
  obligation open, as logged.
-/

namespace MojoProofTest.OblNaive

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymRun
open MojoProofTest.SymPhi FloatLib.Floats.Formats.BinaryInterchange

/-- **The preheader's obligations by mojo_obl**: for every valuation `V`, each obligation of
`%45`'s summary `pre` holds at `V` on its node values: the word 0 for `%47` evaluates, node 0
(the float constant `0.0` at type `float`) evaluates, and the block's effects (none) run. No
premise: the node reads no register and no memory. -/
theorem pre_obls (V : Valuation) : ∀ d ∈ pre.obls, d.Holds V (vals V pre.nodes) := by
  mojo_obl

/-- **The preheader's node values by mojo_vals**: for every valuation `V`, the one node of `%45`
(the float constant `0.000000e+00` at type `float`) has the value the float `+0` of type `float`
(`Model.ofNatBits 0`). -/
theorem pre_vals (V : Valuation) :
    vals V pre.nodes = [.ok (.ofFloat .float (Model.ofNatBits 0))] := by
  mojo_vals

/-- **The preheader's node values as the literal's**: for every valuation `V`, the one node of
`%45` has the value `floatLit` gives its literal at type `float`. -/
theorem pre_vals_lit (V : Valuation) :
    vals V pre.nodes = [floatLit .float (.dec false "0" "000000" 0)] := by
  mojo_vals

/-- A block with one node, the float constant `lit` at type `float`, the obligation that it
evaluates, no register, no effect, and a `ret` exit, for every literal `lit`. -/
def flitS (lit : FloatLit) : Summary :=
  { nodes := [.flit .float lit], regs := [], effs := [], obls := [.ok (.node 0)], exit := .ret,
    len := 1 }

/--
info: mojo_obl: open goal
  Cond.Holds V (vals V (flitS lit).nodes) (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `pre_obls`**: for every valuation `V`, literal `lit` and value `v` with
`floatLit .float lit = .ok v`, the obligation of `flitS lit` holds. The kernel does not evaluate
`floatLit` of an unknown literal, so mojo_obl leaves the obligation that node 0 evaluates open,
as logged; `SNode.eval_flit` closes it from `hl`. -/
theorem flit_open (V : Valuation) (lit : FloatLit) (v : Val)
    (hl : floatLit .float lit = .ok v) :
    ∀ d ∈ (flitS lit).obls, d.Holds V (vals V (flitS lit).nodes) := by
  mojo_obl
  exact Cond.holds_ok (SVal.eval_node (vals_getElem?_eval rfl (SNode.eval_flit hl)))

end MojoProofTest.OblNaive
