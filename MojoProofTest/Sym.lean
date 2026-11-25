import MojoProof.Kernels.Vadd
import MojoProof.Sym.Command

/-!
# Tests of the block checker

On `vector_addition` (corpus `vadd/`), `mojo_kernel` (MojoProof/Kernels/Vadd.lean) computes the
summaries `Kernels.vadd.b0` to `Kernels.vadd.b3` of blocks `%4`, `%21`, `%30` and `%31` from their
entries (nobody writes them), and the kernel checks `covers … = true` for `%21`, `%30` and `%31`,
with the summary's own obligations as the conditions (`vadd21_covers`, `vadd30_covers`,
`vadd31_covers`, by `decide +kernel`). Block `%21`'s summary has two loads, then a store of
node `j`, which is the `fadd` of two nodes that are loads, and the exit to `%31`
(`vadd21_shape`). `Block.sound` on it: from a thread
at block `%21`'s entry whose obligations hold on the values of the summary's table, the steps
reach the block's end, with the memory the summary's effects make (`vadd21_sound`).

The twins, each evaluated by the kernel to `false`: the summary with a wrong entry (the latest
register's entry replaced by a constant), with an obligation dropped from the conditions, with
the conditions reversed (the check is by position), with an atom relabelled in the table
(register `%10`, the first input buffer, read as `%8`, the second), with the effects reordered,
and with another exit (`vadd21_twins`). The entry block `%4`, which calls the special registers
`tid.x`, `ctaid.x` and `ntid.x`, is in the fragment (`vadd4_covers`); its twins: the summary with
a call node moved to another call, and the block with the fast-math flag `nnan` on its first
call, which `summarize` and `sym_summary` refuse (`vadd4_twins`).

`Block.sound` gives the step count at the block's end, `t.k + Kernels.vadd.b1.len` (`vadd21_sound`).
The path checker (`coversPathWith false`) accepts the kernel's two paths from its entry,
`%4 → %21 → %31` (`%4` then `vaddIn`) and `%4 → %30 → %31` (`%4` then `vaddOut`), by
`decide +kernel` (`vadd_paths`), and refuses a path with a summary at the wrong block and one
entered at the wrong position (`vadd_paths_twins`). `Block.sound_retWith` on them: from a thread
with one frame at `%4`'s entry whose path premises hold (`WalkWith false`), the steps run the path
to `%31`'s `ret`, and the next step returns (`vadd_ret`; its premises on a concrete run are in
MojoProofTest/SymRun.lean). Each result is about the one kernel, for every context and thread of it.
-/

namespace MojoProofTest.Sym

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

/-- The checker accepts block `%21` with its summary and the summary's obligations. -/
theorem vadd21_covers : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
    Kernels.vadd.b1.obls Kernels.vadd.b1 = true := by decide +kernel

/-- The checker accepts block `%30`. -/
theorem vadd30_covers : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_2.label 0
    Kernels.vadd.b2.obls Kernels.vadd.b2 = true := by decide +kernel

/-- The checker accepts block `%31`. -/
theorem vadd31_covers : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_3.label 0
    Kernels.vadd.b3.obls Kernels.vadd.b3 = true := by decide +kernel

/-- Block `%21`'s summary: three accesses (two loads, then a store of node `j`, which is the `fadd`
of nodes `a` and `b`, both loads), and the exit to `%31`. -/
theorem vadd21_shape : (match Kernels.vadd.b1.effs, Kernels.vadd.b1.exit with
    | [.load _ _ _, .load _ _ _, .store _ _ (.node j) _], .br d =>
      (match Kernels.vadd.b1.nodes[j]? with
        | some (.fbin .fadd _ .float _ (.node a) (.node b)) =>
          (Kernels.vadd.b1.nodes[a]? matches some (.load _ _ _)) &&
            (Kernels.vadd.b1.nodes[b]? matches some (.load _ _ _))
        | _ => false) && d == Kernels.vadd.fn_0.b_3.label
    | _, _ => false) = true := by decide +kernel

/-- **`Block.sound` on block `%21`**: for every context of `vector_addition` and thread whose
innermost frame is at block `%21`'s entry, with every obligation of the summary holding on the
values of its table, the thread's steps reach the block's end, `Kernels.vadd.b1.len` steps later,
with the memory the summary's effects make. -/
theorem vadd21_sound {c : Ctx} (hP : c.prog = Kernels.vadd.prog) {t : Thread} {m : Mem}
    {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = Kernels.vadd.fn_0)
    (hl : f.label = Kernels.vadd.fn_0.b_1.label) (hp : f.pc = 0)
    (hds : ∀ d ∈ Kernels.vadd.b1.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) Kernels.vadd.b1.nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + Kernels.vadd.b1.len⟩ me ∧
      SEff.run (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) Kernels.vadd.b1.nodes) Kernels.vadd.b1.effs = .ok me := by
  obtain ⟨fe, me, hS, -, -, -, -, -, -, hm, -⟩ := Block.sound vadd21_covers hP ht hfn hl hp hds
  exact ⟨fe, me, hS, hm⟩

/-- Register `a` read as register `b` in an operand. -/
def relabel (a b : Nat) : SVal → SVal
  | .reg r => .reg (if r = a then b else r)
  | x => x

/-- Register `a` read as register `b` in an effect's operands. -/
def relabelEff (a b : Nat) : SEff → SEff
  | .load l pc y => .load l pc (relabel a b y)
  | .store l pc v y => .store l pc (relabel a b v) (relabel a b y)
  | .alloca l pc n c => .alloca l pc n (c.map (relabel a b))

/-- Register `a` read as register `b` in a node's operands. -/
def relabelNode (a b : Nat) : SNode → SNode
  | .bin op fl w x y => .bin op fl w (relabel a b x) (relabel a b y)
  | .icmp p w x y => .icmp p w (relabel a b x) (relabel a b y)
  | .cast op w x => .cast op w (relabel a b x)
  | .extract is x => .extract is (relabel a b x)
  | .call l pc => .call l pc
  | .gep l pc x y => .gep l pc (relabel a b x) (relabel a b y)
  | .load l pc x => .load l pc (relabel a b x)
  | .fbin op fm ft n x y => .fbin op fm ft n (relabel a b x) (relabel a b y)
  | .select w c x y => .select w (relabel a b c) (relabel a b x) (relabel a b y)
  | .minmax s m x y => .minmax s m (relabel a b x) (relabel a b y)
  | .fbinP op fm ft n x y px py =>
    .fbinP op fm ft n (relabel a b x) (relabel a b y)
      (px.map fun (u, v) => (relabel a b u, relabel a b v))
      (py.map fun (u, v) => (relabel a b u, relabel a b v))
  | .flit ft lit => .flit ft lit
  | .castAt l pc n x => .castAt l pc n (relabel a b x)
  | .globalAt l pc i => .globalAt l pc i
  | .constAt l pc i => .constAt l pc i
  | .insert is x y => .insert is (relabel a b x) (relabel a b y)
  | .eltAt l pc x y => .eltAt l pc (relabel a b x) (relabel a b y)
  | .insEltAt l pc x y z => .insEltAt l pc (relabel a b x) (relabel a b y) (relabel a b z)
  | .gepN l pc x ys => .gepN l pc (relabel a b x) (ys.map (relabel a b))
  | .loadAfter l pc x es => .loadAfter l pc (relabel a b x) (es.map (relabelEff a b))
  | .fresh n => .fresh n
  | .icmpAfter p w x y es =>
    .icmpAfter p w (relabel a b x) (relabel a b y) (es.map (relabelEff a b))
  | .castAfter l pc n x es => .castAfter l pc n (relabel a b x) (es.map (relabelEff a b))
  | .gepAfter l pc x y es =>
    .gepAfter l pc (relabel a b x) (relabel a b y) (es.map (relabelEff a b))
  | .gepNAfter l pc x ys es =>
    .gepNAfter l pc (relabel a b x) (ys.map (relabel a b)) (es.map (relabelEff a b))

/-- The number of local `%n` of `vector_addition`. -/
def local? (n : String) : Nat :=
  ((List.range Kernels.vadd.fn_0.names.size).find? (Kernels.vadd.fn_0.names[·]? == some n)).getD 0

/-- The twins: the checker refuses block `%21`'s summary with the latest register's entry
replaced by a constant, its conditions without their first obligation, its conditions reversed,
the summary with `%10` read as `%8` in its table, its effects reversed, and its exit to
`%30`. -/
theorem vadd21_twins :
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0 Kernels.vadd.b1.obls
      { Kernels.vadd.b1 with regs := match Kernels.vadd.b1.regs with
        | (r, _) :: rs => (r, .int 64 0) :: rs
        | [] => [] } = false ∧
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
      Kernels.vadd.b1.obls.tail Kernels.vadd.b1 = false ∧
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0
      Kernels.vadd.b1.obls.reverse Kernels.vadd.b1 = false ∧
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0 Kernels.vadd.b1.obls
      { Kernels.vadd.b1 with
        nodes := Kernels.vadd.b1.nodes.map (relabelNode (local? "10") (local? "8")) } = false ∧
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0 Kernels.vadd.b1.obls
      { Kernels.vadd.b1 with effs := Kernels.vadd.b1.effs.reverse } = false ∧
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 0 Kernels.vadd.b1.obls
      { Kernels.vadd.b1 with exit := .br Kernels.vadd.fn_0.b_2.label } = false := by
  decide +kernel

/-- The checker accepts the entry block `%4`, whose statements 7, 9 and 11 call the special
registers `tid.x`, `ctaid.x` and `ntid.x`. -/
theorem vadd4_covers : covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_0.label 0
    Kernels.vadd.b0.obls Kernels.vadd.b0 = true := by decide +kernel

/-- `vector_addition`'s function with the fast-math flag `nnan` on the call at statement 7 of
block `%4`. -/
def fn4nnan : Func := { Kernels.vadd.fn_0 with blocks := Kernels.vadd.fn_0.blocks.map fun b =>
  if b.label == Kernels.vadd.fn_0.b_0.label then
    { b with stmts := b.stmts.modify 7 fun st => match st.inst with
      | .call _ ty cal args => { st with inst := .call { nnan := true } ty cal args }
      | _ => st }
  else b }

/-- The twins of block `%4`: the checker refuses its summary with the call node of statement 7
(`tid.x`) moved to statement 9 (`ctaid.x`), and refuses the block with the fast-math flag `nnan`
on that call (`summarize` gives `none`). -/
theorem vadd4_twins :
    covers Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_0.label 0 Kernels.vadd.b0.obls
      { Kernels.vadd.b0 with nodes := Kernels.vadd.b0.nodes.map fun (nd : SNode) => match nd with
        | .call l 7 => .call l 9
        | nd => nd } = false ∧
    summarize Kernels.vadd.prog fn4nnan Kernels.vadd.fn_0.b_0.label 0 = none := by
  decide +kernel

/--
error: sym_summary: block Kernels.vadd.fn_0.b_0.label of fn4nnan from position 0 is outside the
checker's fragment
-/
#guard_msgs (whitespace := lax) in
sym_summary vadd4nnan := Kernels.vadd.prog fn4nnan Kernels.vadd.fn_0.b_0.label 0

/-- The rest of `vector_addition`'s path through `%21` (a thread whose index is below the count):
`%21`, then `%31`, each with its summary and the summary's obligations. -/
def vaddIn : List (Nat × List Cond × Summary) :=
  [(Kernels.vadd.fn_0.b_1.label, Kernels.vadd.b1.obls, Kernels.vadd.b1),
    (Kernels.vadd.fn_0.b_3.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)]

/-- The rest of `vector_addition`'s path through `%30` (a thread whose index is not below the
count): `%30`, then `%31`. -/
def vaddOut : List (Nat × List Cond × Summary) :=
  [(Kernels.vadd.fn_0.b_2.label, Kernels.vadd.b2.obls, Kernels.vadd.b2),
    (Kernels.vadd.fn_0.b_3.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)]

/-- The path checker accepts `vector_addition`'s two paths from the entry block `%4`:
`%4 → %21 → %31` and `%4 → %30 → %31`. -/
theorem vadd_paths :
    coversPathWith false Kernels.vadd.prog Kernels.vadd.fn_0 0
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn) = true ∧
    coversPathWith false Kernels.vadd.prog Kernels.vadd.fn_0 0
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddOut) = true := by
  decide +kernel

/-- The twins: the path checker refuses the path with `%21`'s summary at `%30`, and the path
whose first block is entered at position 1 (its summary is from position 0). -/
theorem vadd_paths_twins :
    coversPathWith false Kernels.vadd.prog Kernels.vadd.fn_0 0
      [(Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0),
        (Kernels.vadd.fn_0.b_2.label, Kernels.vadd.b1.obls, Kernels.vadd.b1),
        (Kernels.vadd.fn_0.b_3.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)] = false ∧
    coversPathWith false Kernels.vadd.prog Kernels.vadd.fn_0 1
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn) = false := by
  decide +kernel

/-- **`Block.sound_retWith` on `vector_addition`'s two paths**: for every context of the kernel
and thread with one frame, at the entry block `%4`, and either path (`ps` is `vaddIn` or
`vaddOut`) whose premises hold (`WalkWith false`), the thread's steps reach `%31`'s end,
`pathLen Kernels.vadd.b0 ps` steps later, on the memory the path's last block's effects make, and
its next step returns. -/
theorem vadd_ret {c : Ctx} (hP : c.prog = Kernels.vadd.prog)
    {ps : List (Nat × List Cond × Summary)} (hps : ps = vaddIn ∨ ps = vaddOut) {t : Thread}
    {m : Mem} {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = Kernels.vadd.fn_0)
    (hl : f.label = Kernels.vadd.fn_0.b_0.label) (hp : f.pc = 0)
    (hW : WalkWith false (Valuation.entry c t.k m f)
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: ps)) :
    ∃ fe me, Steps c t m ⟨[fe], t.k + pathLen Kernels.vadd.b0 ps⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).lastWith false Kernels.vadd.fn_0.b_0.label
          Kernels.vadd.b0 ps).1
        (vals ((Valuation.entry c t.k m f).lastWith false Kernels.vadd.fn_0.b_0.label
            Kernels.vadd.b0 ps).1
          ((Valuation.entry c t.k m f).lastWith false Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0
            ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastWith false Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0
          ps).2.2.effs = .ok me ∧
      step c ⟨[fe], t.k + pathLen Kernels.vadd.b0 ps⟩ me =
        .ok (.done (f.allocas.foldl (fun m b => m.setLive b false) me)) := by
  rcases hps with rfl | rfl
  · have h := Block.sound_retWith hP vadd_paths.1 ht hfn hl hp hW rfl rfl
    rw [Valuation.allocsWith_nil _ vadd_paths.1, List.nil_append] at h
    exact h
  · have h := Block.sound_retWith hP vadd_paths.2 ht hfn hl hp hW rfl rfl
    rw [Valuation.allocsWith_nil _ vadd_paths.2, List.nil_append] at h
    exact h

end MojoProofTest.Sym
