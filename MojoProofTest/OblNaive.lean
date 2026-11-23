import MojoProofTest.SymPhi
import MojoProof.Sym.Vals
import MojoProof.Sym.OblHave

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
* `dotS`, `dotS_vals`: a hand-written summary of a `fmul contract` of registers 1 and 2 and the
  `fadd contract` of register 0 and that product (the latch's two nodes on registers);
  `obl_have` gives its nodes' values on symbolic floats, `deliver` of the product and `deliver`
  of `contract` with its factors.
* `dotS_open`: the same summary on operands that are any values; mojo_obl leaves the obligation
  open, as logged, and proves it once register 0 is a float.
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

/-- A block of two nodes on registers, for every valuation: node 0 is `fmul contract` of registers 1
and 2 at type `float`, node 1 is `fadd contract` of register 0 and node 0, whose `fmul contract`
operands are registers 1 and 2 (as `%66` of the naive matrix product's latch on `%48` and the
loads). Its obligation is that node 1 evaluates; no register, no effect, a `ret` exit. -/
def dotS : Summary :=
  { nodes := [.fbinP .fmul { contract := true } .float 0 (.reg 1) (.reg 2) none none,
      .fbinP .fadd { contract := true } .float 1 (.reg 0) (.node 0) none (some (.reg 1, .reg 2))],
    regs := [], effs := [], obls := [.ok (.node 1)], exit := .ret, len := 2 }

/-- **The nodes of `dotS` on symbolic floats by `obl_have`**: for every valuation `V` and floats
`x`, `a`, `b` of type `float` in registers 0, 1 and 2, none of which has `fmul contract` operands,
node 1 is `deliver` of `contract` of `x`, the product node 0 (`deliver` of `a.mul b` under the
oracle number of statement 0) and its factors `(a, b)`, under the oracle number of statement 1
(`SNode.eval_fbinP_ofFloat`, `floatBin_contract_ofFloat`, `floatBin_ofFloat_factors`). -/
theorem dotS_vals (V : Valuation) (x a b : Model FloatTy.float.fmt)
    (h0 : V.regs 0 = some (.ofFloat .float x)) (h1 : V.regs 1 = some (.ofFloat .float a))
    (h2 : V.regs 2 = some (.ofFloat .float b)) (hp : V.prods 0 = none)
    (hp1 : V.prods 1 = none) (hp2 : V.prods 2 = none) :
    (vals V dotS.nodes)[1]? = some (.ok (.ofFloat .float (deliver (contract false x
      (deliver (a.mul b) (V.ctx.oracle (Nat.pair V.k 0) / 3)) none (some (a, b))
      (V.ctx.oracle (Nat.pair (V.k + 1) 0))) (V.ctx.oracle (Nat.pair (V.k + 1) 0) / 3)))) := by
  obl_have e : (vals V dotS.nodes)[1]?
  exact e

/--
info: mojo_obl: open goal
  Cond.Holds V (vals V dotS.nodes) (Cond.ok (SVal.node 1))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `dotS_vals`**: for every valuation `V` and values `v`, `a`, `b` in registers 0,
1 and 2 (`a` and `b` floats), the obligation of `dotS` holds when `v` is a float. The evaluator
gives a float operator on an operand that is no float `.ofFloat t u` no value, so mojo_obl leaves
the obligation that node 1 evaluates open, as logged; after `subst` it proves it. -/
theorem dotS_open (V : Valuation) (v : Val) (x a b : Model FloatTy.float.fmt)
    (h0 : V.regs 0 = some v) (h1 : V.regs 1 = some (.ofFloat .float a))
    (h2 : V.regs 2 = some (.ofFloat .float b)) (hp : V.prods 0 = none)
    (hp1 : V.prods 1 = none) (hp2 : V.prods 2 = none) (hv : v = .ofFloat .float x) :
    ∀ d ∈ dotS.obls, d.Holds V (vals V dotS.nodes) := by
  mojo_obl
  subst hv
  mojo_obl

end MojoProofTest.OblNaive
