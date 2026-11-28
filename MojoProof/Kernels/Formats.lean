import MojoProof.Kernels.Vadd
import MojoProof.Kernels.Vmul
import MojoProof.Kernels.Vsub
import MojoProof.Sym.Formats

/-!
# The elementwise kernels at every float format

`vector_addition`, vector_multiply and vector_subtraction (MojoProof/Kernels/Vadd.lean,
MojoProof/Kernels/Vmul.lean, MojoProof/Kernels/Vsub.lean) at every float format `t`: each
kernel's Float32 program retyped at `t` (`Program.retype t`, MojoProof/Sym/Formats.lean). This
module has:

* `vadd.startsOf`: every kernel with `vector_addition`'s layout and parameters, no globals and a
  first block, whose check passes, starts on `vadd.args` at every launch that passes its launch
  check (`Func.checkLaunch`);
* `vadd.sound_retype`: the kernel theorem at `t` of every such kernel retyped at `t`, from the
  path checker at `t` and each thread's `Ret` at `t` (`Map2.Step`). It is `Kernel.sound_map2`
  (MojoProof/Sym/Kernel.lean) at `vadd.startsOf`;
* the tactic `mojo_map2_step`, which proves a `Map2.Step` goal for one kernel at one format by
  mojo_ret (MojoProof/Sym/Ops.lean);
* `vadd.step_half` and `vadd.step_bfloat`, `vector_addition`'s threads at the two 16-bit
  formats, and `vadd.family`, its kernel theorem at every `t`: `vadd.sound_retype` with the
  threads by these two steps and by `mojo_map2_step` at `.float` and `.double`; the same under
  `vmul` and `vsub`. The 16-bit runs are separate
  declarations because one declaration's heartbeat budget does not hold two runs of mojo_ret at
  a 16-bit format.

The command `mojo_kernel` has no clause for the format, so these are written here. At `.float`
the family theorems' statements are `vadd.correct`'s, `vmul.correct`'s and `vsub.correct`'s up
to unfolding definitions (MojoProofTest/Formats.lean).
-/

namespace MojoProof.Kernels

open MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean FloatLib.Floats.Formats.BinaryInterchange

unseal Array.anyM.loop in
/-- Every kernel `F` of a program `P` with `vector_addition`'s layout, no globals, `vadd.fn_0`'s
parameters and a first block, whose check passes (`Func.check`), starts on `vadd.args` for every
launch that passes its launch check (`Func.checkLaunch`: within `F`'s launch limits, if it has
any), block numbers, count, memory closed for them (`Mem.Closed`), address choice and oracle
(`Sym.Grid.start_ok`). The three elementwise kernels at every float format (`Program.retype`,
MojoProof/Sym/Formats.lean) are such kernels, with no launch limit. -/
theorem vadd.startsOf {P : Program} {F : Func} (hf : F.check P.module = .ok ())
    (hl : P.layout = vadd.prog.layout) (hg : P.module.globals.toList = [])
    (hp : F.params = vadd.fn_0.params) (hb : 0 < F.blocks.size) (L : Launch) (a b out : Nat)
    (n : BitVec 32) (hk : F.checkLaunch P.module L.block (vadd.args a b out n).length = .ok ())
    {m : Mem} (hC : m.Closed (vadd.args a b out n)) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g c, Sem.Grid.start P F L (vadd.args a b out n) m ch oracle = .ok (g, c) := by
  refine Sym.Grid.start_ok ch oracle hf hk hC (fun g hg' => by rw [hg] at hg'; cases hg')
    (fun p v hpv t ht => ?_) (fun p v hpv hnb m' => ?_) hb
    (by unfold Func.byvalPlaced; rw [hp, hl]; rfl)
  all_goals
    rw [hl]
    rw [hp] at hpv
    simp only [vadd.args, vadd.fn_0, List.zip_cons_cons, List.zip_nil_left, List.mem_cons,
      Prod.mk.injEq, List.not_mem_nil] at hpv
    repeat' rcases hpv with ⟨hp, hv⟩ | hpv
  all_goals subst_vars
  all_goals first
    | exact ⟨_, rfl⟩
    | simp at hnb
    | (simp at ht; done)
    | (simp at ht; subst ht; rfl)

/-- **The kernel theorem at float format `t` of every kernel with `vector_addition`'s layout and
parameters.** For every program `P` with `vector_addition`'s layout and no globals, kernel `F`
with `vadd.fn_0`'s parameters and a first block whose check at `t` passes, paths `paths` that the
path checker at `t` accepts from the entry (`coversEntry`), launch `L` that passes the retyped
kernel's launch check (`Func.checkLaunch`), caller's memory of
`Map2.Pre` at `t`, oracle `ω` and bytes `bs`: if every thread takes one of the paths at `t` to
`ret` with the elementwise invariant `Elem` for `bs` at cells `l.size (.fp t) * i`
(`Map2.Step`), then `F` retyped at `t` is sound at every address choice and `ω`: block `out` is
the caller's with the bytes `bs i` put at cell `l.size (.fp t) * i` for every thread `i`, and
every other block is unchanged. It is `Kernel.sound_map2` at `vadd.startsOf`. -/
theorem vadd.sound_retype {P : Program} {F : Func}
    {paths : List (List (Nat × List Cond × Summary))} (t : LLVM.FloatTy)
    (hl : P.layout = vadd.prog.layout)
    (hf : (F.retype P.layout t).check (P.retype t).module = .ok ())
    (hg : P.module.globals.toList = []) (hp : F.params = vadd.fn_0.params)
    (hb : 0 < F.blocks.size)
    (hc : coversEntry (P.retype t) (F.retype P.layout t) (Paths.retype t paths) = true)
    {L : Launch} {al a b out n N : Nat} {x y : Tensor (Model t.fmt) [N]} {m : Mem}
    (hk : (F.retype P.layout t).checkLaunch (P.retype t).module L.block
      (vadd.args a b out (BitVec.ofNat 32 n)).length = .ok ())
    (hP : Map2.Pre P.layout (.fp t) (Val.ofFloat t) al vadd.argTail m a b out n x y)
    {ω : Nat → Nat → Nat} {bs : Nat → Option (List MemByte)}
    (H : Map2.Step (P.retype t) (F.retype P.layout t) L (Paths.retype t paths) vadd.argTy 8
      vadd.argTail (.fp t) (Val.ofFloat t) al a b out n x y ω (P.layout.size (.fp t))
      (fun i => P.layout.size (.fp t) * i) bs) :
    Kernel.Sound (P.retype t) (F.retype P.layout t) L
      (vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out (fun i => P.layout.size (.fp t) * i) bs
        (volume L.grid * volume L.block)) := by
  have hl' : (P.retype t).layout = vadd.prog.layout := hl
  have hb' : 0 < (F.retype P.layout t).blocks.size := by simpa [Func.retype] using hb
  exact Kernel.sound_map2 (prog := P.retype t) (fn := F.retype P.layout t)
    (paths := Paths.retype t paths) hc hp ⟨rfl, rfl, rfl, rfl⟩ (T := vadd.argTy)
    ⟨rfl, rfl, rfl, rfl⟩
    (by
      rw [hl']
      exact Layout.Codec.ptrArg vadd.prog.layout 0 (by decide +kernel) (by decide +kernel) rfl rfl
        rfl)
    (al' := 8) ⟨by rw [hl']; decide, by rw [hl']; decide⟩ hP (fun _ => rfl)
    (fun ch => vadd.startsOf (P := P.retype t) (F := F.retype P.layout t) hf hl' hg hp hb' L a b
      out _ hk hP.closed ch ω) (apart_mul _) H

/-- `mojo_map2_step`: closes a goal `Map2.Step` (MojoProof/Sym/Formats.lean) for one kernel at
one format by mojo_ret. It finds its facts by type, whatever their names: a hypothesis
`Map2.Pre …`, whose three facts `ne`, `le` and `lt` it adds, and a hypothesis `d ∣ e` of natural
numbers, which it adds as `2 ∣ e`, `4 ∣ e` or `8 ∣ e`, the first of the three that `d` is by
definition (none when `d` is none of them, or when there is no such hypothesis). It introduces
the thread, its context, memories, frame and the premises of `Map2.Step` under names of its own,
and runs mojo_ret on the goal `∃ ps ∈ paths, Ret …`. When mojo_ret proves no path, it logs as
open (`mojo_ret: open goal`) the premises of the first path that it does not prove, and it may then
fail on that path (it does when the alignment is not found). It fails when there is no hypothesis
`Map2.Pre …`. Tests: MojoProofTest/Map2Step.lean. -/
macro "mojo_map2_step" : tactic => `(tactic| (
  have hne := Map2.Pre.ne ‹_›
  have hnN := Map2.Pre.le ‹_›
  have h31 := Map2.Pre.lt ‹_›
  try first
    | have hal : (2 : Nat) ∣ _ := ‹(_ : Nat) ∣ _›
    | have hal : (4 : Nat) ∣ _ := ‹(_ : Nat) ∣ _›
    | have hal : (8 : Nat) ∣ _ := ‹(_ : Nat) ∣ _›
  intro k hk c hcp hce hcw hco m₀ m' f hf _ _ _ hr0 hr1 hr2 hr3 hv0 hv1 hv2 hA hB hO hx hy hFa hFb
    hFo hp hE
  mojo_ret))

/-- The threads of `vector_addition` at `.half` (`Map2.Step`, MojoProof/Sym/Formats.lean): for
every launch whose grid and block have side 1 in `y` and `z`, alignment that 2 divides, caller's
memory of `Map2.Pre` at `.half` and oracle `ω`, each thread takes one of
`Paths.retype .half vadd.paths` to `ret` with the elementwise invariant `Elem` for the bytes
`Elem.map2` of `Model.add` at cells `2 i` (mojo_ret). A step of `vadd.family`, apart from it
because one declaration's heartbeat budget does not hold two runs of mojo_ret at a 16-bit
format. -/
theorem vadd.step_half {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 2 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.half.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vadd.prog.layout (.fp .half) (Val.ofFloat .half) al vadd.argTail m a b out n x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vadd.prog.retype .half) (vadd.fn_0.retype vadd.prog.layout .half) L
      (Paths.retype .half vadd.paths) vadd.argTy 8 vadd.argTail (.fp .half)
      (Val.ofFloat .half) al a b out n x y ω 2 (fun i => 2 * i)
      (Elem.map2 vadd.prog.layout .half Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- The threads of `vector_addition` at `.bfloat`: `vadd.step_half` at `.bfloat` (mojo_ret). -/
theorem vadd.step_bfloat {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 2 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.bfloat.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vadd.prog.layout (.fp .bfloat) (Val.ofFloat .bfloat) al vadd.argTail m a b out n
      x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vadd.prog.retype .bfloat) (vadd.fn_0.retype vadd.prog.layout .bfloat) L
      (Paths.retype .bfloat vadd.paths) vadd.argTy 8 vadd.argTail (.fp .bfloat)
      (Val.ofFloat .bfloat) al a b out n x y ω 2 (fun i => 2 * i)
      (Elem.map2 vadd.prog.layout .bfloat Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- **`vector_addition` at every float format.** For every format `t` (`.half`, `.bfloat`,
`.float`, `.double`), valid launch whose grid and block have side 1 in `y` and `z`, alignment
that the format's divides, and caller's memory of the precondition `Map2.Pre` at `t`
(MojoProof/Sem/Precond.lean), `vector_addition` retyped at `t` (`Program.retype`,
MojoProof/Sym/Formats.lean) is sound at every address choice and oracle `ω`: block `out` is the
caller's with the bytes `Elem.map2` of `Model.add` (`deliver (x_i + y_i)` at thread `i`'s `fadd`
oracle number, for `i < n`; nothing for the others) put at cell `l.size (.fp t) * i` for every
thread `i`, and every other block of the caller's memory is unchanged. It is `vadd.sound_retype`
at the kernel, with the threads by `mojo_map2_step` at `.float` and `.double` and by
`vadd.step_half` and `vadd.step_bfloat` at the 16-bit formats. At `.float` the retyping is
`vadd.prog` itself and the statement is `vadd.correct`'s up to unfolding definitions (derived in
MojoProofTest/Formats.lean); at `.half` and `.bfloat` the function is the one of
tests/corpus/vadd16/ and tests/corpus/vaddbf16/ up to the kernel's name. It covers this one
kernel at every format, launch and input that meet these premises. -/
theorem vadd.family (t : LLVM.FloatTy) {L : Launch} (hL : L.Valid)
    (hg : L.grid .y = 1 ∧ L.grid .z = 1) (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat}
    (hal : vadd.prog.layout.align (.fp t) ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model t.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vadd.prog.layout (.fp t) (Val.ofFloat t) al vadd.argTail m a b out n x y)
    {ω : Nat → Nat → Nat} :
    Kernel.Sound (vadd.prog.retype t) (vadd.fn_0.retype vadd.prog.layout t) L
      (vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out (fun i => vadd.prog.layout.size (.fp t) * i)
        (Elem.map2 vadd.prog.layout t Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y n)
        (volume L.grid * volume L.block)) := by
  refine vadd.sound_retype (P := vadd.prog) (F := vadd.fn_0) (paths := vadd.paths) t rfl
    (by cases t <;> rfl) rfl rfl (Nat.succ_pos _) (by cases t <;> decide +kernel)
    (by cases t <;> rfl) hP ?_
  cases t
  · exact vadd.step_half hL hg hb hal hP ω
  · exact vadd.step_bfloat hL hg hb hal hP ω
  all_goals mojo_map2_step

/-- The threads of `vector_multiply` at `.half` (`Map2.Step`, MojoProof/Sym/Formats.lean): for
every launch whose grid and block have side 1 in `y` and `z`, alignment that 2 divides, caller's
memory of `Map2.Pre` at `.half` and oracle `ω`, each thread takes one of
`Paths.retype .half vmul.paths` to `ret` with the elementwise invariant `Elem` for the bytes
`Elem.map2` of `Model.mul` at cells `2 i` (mojo_ret). A step of `vmul.family`, apart from it
because one declaration's heartbeat budget does not hold two runs of mojo_ret at a 16-bit
format. -/
theorem vmul.step_half {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 2 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.half.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vmul.prog.layout (.fp .half) (Val.ofFloat .half) al vadd.argTail m a b out n x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vmul.prog.retype .half) (vmul.fn_0.retype vmul.prog.layout .half) L
      (Paths.retype .half vmul.paths) vadd.argTy 8 vadd.argTail (.fp .half)
      (Val.ofFloat .half) al a b out n x y ω 2 (fun i => 2 * i)
      (Elem.map2 vmul.prog.layout .half Model.mul (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- The threads of `vector_multiply` at `.bfloat`: `vmul.step_half` at `.bfloat` (mojo_ret). -/
theorem vmul.step_bfloat {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 2 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.bfloat.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vmul.prog.layout (.fp .bfloat) (Val.ofFloat .bfloat) al vadd.argTail m a b out n
      x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vmul.prog.retype .bfloat) (vmul.fn_0.retype vmul.prog.layout .bfloat) L
      (Paths.retype .bfloat vmul.paths) vadd.argTy 8 vadd.argTail (.fp .bfloat)
      (Val.ofFloat .bfloat) al a b out n x y ω 2 (fun i => 2 * i)
      (Elem.map2 vmul.prog.layout .bfloat Model.mul (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- **`vector_multiply` at every float format.** For every format `t` (`.half`, `.bfloat`,
`.float`, `.double`), valid launch whose grid and block have side 1 in `y` and `z`, alignment
that the format's divides, and caller's memory of the precondition `Map2.Pre` at `t`
(MojoProof/Sem/Precond.lean), `vector_multiply` retyped at `t` (`Program.retype`,
MojoProof/Sym/Formats.lean) is sound at every address choice and oracle `ω`: block `out` is the
caller's with the bytes `Elem.map2` of `Model.mul` (`deliver (x_i * y_i)` at thread `i`'s `fmul`
oracle number, for `i < n`; nothing for the others) put at cell `l.size (.fp t) * i` for every
thread `i`, and every other block of the caller's memory is unchanged. It is `vadd.sound_retype`
at the kernel, with the threads by `mojo_map2_step` at `.float` and `.double` and by
`vmul.step_half` and `vmul.step_bfloat` at the 16-bit formats. At `.float` the retyping is
`vmul.prog` itself and the statement is `vmul.correct`'s up to unfolding definitions (derived in
MojoProofTest/Formats.lean); no Mojo compile of the kernel at `.half`, `.bfloat` or `.double`
is in the corpus. It covers this one kernel at every format, launch and input that meet these
premises. -/
theorem vmul.family (t : LLVM.FloatTy) {L : Launch} (hL : L.Valid)
    (hg : L.grid .y = 1 ∧ L.grid .z = 1) (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat}
    (hal : vmul.prog.layout.align (.fp t) ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model t.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vmul.prog.layout (.fp t) (Val.ofFloat t) al vadd.argTail m a b out n x y)
    {ω : Nat → Nat → Nat} :
    Kernel.Sound (vmul.prog.retype t) (vmul.fn_0.retype vmul.prog.layout t) L
      (vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out (fun i => vmul.prog.layout.size (.fp t) * i)
        (Elem.map2 vmul.prog.layout t Model.mul (fun k => ω k (Nat.pair 23 0) / 3) x y n)
        (volume L.grid * volume L.block)) := by
  refine vadd.sound_retype (P := vmul.prog) (F := vmul.fn_0) (paths := vmul.paths) t rfl
    (by cases t <;> rfl) rfl rfl (Nat.succ_pos _) (by cases t <;> decide +kernel)
    (by cases t <;> rfl) hP ?_
  cases t
  · exact vmul.step_half hL hg hb hal hP ω
  · exact vmul.step_bfloat hL hg hb hal hP ω
  all_goals mojo_map2_step

/-- The threads of vector_subtraction at `.half` (`Map2.Step`, MojoProof/Sym/Formats.lean): for
every launch whose grid and block have side 1 in `y` and `z`, alignment that 2 divides, caller's
memory of `Map2.Pre` at `.half` and oracle `ω`, each thread takes one of
`Paths.retype .half vsub.paths` to `ret` with the elementwise invariant `Elem` for the bytes
`Elem.map2` of `Model.sub` at cells `2 i` (mojo_ret). A step of `vsub.family`, apart from it
because one declaration's heartbeat budget does not hold two runs of mojo_ret at a 16-bit
format. -/
theorem vsub.step_half {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 2 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.half.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vsub.prog.layout (.fp .half) (Val.ofFloat .half) al vadd.argTail m a b out n x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vsub.prog.retype .half) (vsub.fn_0.retype vsub.prog.layout .half) L
      (Paths.retype .half vsub.paths) vadd.argTy 8 vadd.argTail (.fp .half)
      (Val.ofFloat .half) al a b out n x y ω 2 (fun i => 2 * i)
      (Elem.map2 vsub.prog.layout .half Model.sub (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- The threads of vector_subtraction at `.bfloat`: `vsub.step_half` at `.bfloat` (mojo_ret). -/
theorem vsub.step_bfloat {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 2 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model LLVM.FloatTy.bfloat.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vsub.prog.layout (.fp .bfloat) (Val.ofFloat .bfloat) al vadd.argTail m a b out n
      x y)
    (ω : Nat → Nat → Nat) :
    Map2.Step (vsub.prog.retype .bfloat) (vsub.fn_0.retype vsub.prog.layout .bfloat) L
      (Paths.retype .bfloat vsub.paths) vadd.argTy 8 vadd.argTail (.fp .bfloat)
      (Val.ofFloat .bfloat) al a b out n x y ω 2 (fun i => 2 * i)
      (Elem.map2 vsub.prog.layout .bfloat Model.sub (fun k => ω k (Nat.pair 23 0) / 3) x y n) := by
  mojo_map2_step

/-- **vector_subtraction at every float format.** For every format `t` (`.half`, `.bfloat`,
`.float`, `.double`), valid launch whose grid and block have side 1 in `y` and `z`, alignment
that the format's divides, and caller's memory of the precondition `Map2.Pre` at `t`
(MojoProof/Sem/Precond.lean), vector_subtraction retyped at `t` (`Program.retype`,
MojoProof/Sym/Formats.lean) is sound at every address choice and oracle `ω`: block `out` is the
caller's with the bytes `Elem.map2` of `Model.sub` (`deliver (x_i - y_i)` at thread `i`'s `fsub`
oracle number, for `i < n`; nothing for the others) put at cell `l.size (.fp t) * i` for every
thread `i`, and every other block of the caller's memory is unchanged. It is `vadd.sound_retype`
at the kernel, with the threads by `mojo_map2_step` at `.float` and `.double` and by
`vsub.step_half` and `vsub.step_bfloat` at the 16-bit formats. At `.float` the retyping is
`vsub.prog` itself and the statement is `vsub.correct`'s up to unfolding definitions (derived in
MojoProofTest/Formats.lean); no Mojo compile of the kernel at `.half`, `.bfloat` or `.double`
is in the corpus. It covers this one kernel at every format, launch and input that meet these
premises. -/
theorem vsub.family (t : LLVM.FloatTy) {L : Launch} (hL : L.Valid)
    (hg : L.grid .y = 1 ∧ L.grid .z = 1) (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat}
    (hal : vsub.prog.layout.align (.fp t) ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model t.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vsub.prog.layout (.fp t) (Val.ofFloat t) al vadd.argTail m a b out n x y)
    {ω : Nat → Nat → Nat} :
    Kernel.Sound (vsub.prog.retype t) (vsub.fn_0.retype vsub.prog.layout t) L
      (vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out (fun i => vsub.prog.layout.size (.fp t) * i)
        (Elem.map2 vsub.prog.layout t Model.sub (fun k => ω k (Nat.pair 23 0) / 3) x y n)
        (volume L.grid * volume L.block)) := by
  refine vadd.sound_retype (P := vsub.prog) (F := vsub.fn_0) (paths := vsub.paths) t rfl
    (by cases t <;> rfl) rfl rfl (Nat.succ_pos _) (by cases t <;> decide +kernel)
    (by cases t <;> rfl) hP ?_
  cases t
  · exact vsub.step_half hL hg hb hal hP ω
  · exact vsub.step_bfloat hL hg hb hal hP ω
  all_goals mojo_map2_step

end MojoProof.Kernels
