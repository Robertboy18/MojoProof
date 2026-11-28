# The elementwise kernels at every float format

Lean: MojoProof/Sym/Formats.lean (the retyping and `Map2.Step`), MojoProof/Kernels/Formats.lean
(`vadd.startsOf`, `vadd.sound_retype`, the tactic `mojo_map2_step`, the threads at the 16-bit
formats and the three family theorems), tests in MojoProofTest/Formats.lean.

**Scope.** `Ty.retype`, `Inst.retype`, `Func.retype`, `Program.retype` and the summary forms are
defined for every program, function, layout and float format. `vadd.startsOf` is for every program
and function with `vector_addition`'s layout, no globals, `vadd.fn_0`'s parameters and a first
block, whose check passes; `vadd.sound_retype` is for every such program and function retyped at
every format, every path list, launch and input. `vadd.family`, `vmul.family` and `vsub.family` are
each one kernel (`vector_addition`, `vector_multiply`, vector_subtraction) at every float format
(`.half`, `.bfloat`, `.float`, `.double`), every launch and every input that meet their premises.
The equations of MojoProofTest/Formats.lean are about the corpus files they name.

## Why a retyping

The Mojo sources of the three kernels are generic in their element type (`DType`); the compiler
emits one program per type. Measured with `Program.diff` (MojoProof/LLVM/Quote.lean) at the
corpus files: the program of `vector_addition` at `float16` (tests/corpus/vadd16/) and at
`bfloat16` (tests/corpus/vaddbf16/) differ from the `float32` one (tests/corpus/vadd/) in
`module`, `sha256` and `kernels`, not in `layout` or `intrinsics`. The functions differ in their
name and in block `%21` only: its two `getelementptr`s' element type, the two loads' and the
store's type and alignment (2 for `half` and `bfloat`, 4 for `float`) and the type of the
`fadd`. The `float64` compile (not in the corpus) differs in the same places, at `double` and
alignment 8.

`Program.retype t P` is that change, written once: `float` becomes `t` in the float binary
operations, the float loads and stores and the `getelementptr`s' element type, and an alignment
`a` of a float load or store becomes `a * size t / size float` under `P`'s layout. Everything
else is unchanged. A Lean function on the parsed program, not a clause of `mojo_family`
(MojoProof/LLVM/Family.lean), because `mojo_family`'s parameters are integer constants of
instructions, and here the change is in types and alignments. Float constants, casts,
comparisons, calls and the instructions on vectors are not retyped, so a kernel that has any of
them on floats is not covered by its retyping (none of the three has).

## Statement

`vadd.family` (MojoProof/Kernels/Formats.lean): for every format `t : FloatTy`, valid launch `L`
whose grid and block have side 1 in `y` and `z`, alignment `al` that `t`'s ABI alignment under
`vadd.prog.layout` divides, block numbers `a`, `b`, `out`, count `n`, tensors `x`, `y` of
`Model t.fmt` of length `N`, oracle `ω` and caller's memory `m` of `Map2.Pre` at `.fp t` and
`Val.ofFloat t` (docs/proofs/precond.md):

```
Kernel.Sound (vadd.prog.retype t) (vadd.fn_0.retype vadd.prog.layout t) L
  (vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
  (Elem.Out m out (fun i => vadd.prog.layout.size (.fp t) * i)
    (Elem.map2 vadd.prog.layout t Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y n)
    (volume L.grid * volume L.block))
```

The kernel has no undefined behaviour and no data race, terminates with one result whatever the
schedule, and leaves block `out` as the caller's with the bytes `Elem.map2` (MojoProof/Sym/
Kernel.lean: the encoding at `t` of `deliver (x_i + y_i)` at thread `i`'s oracle number, for
`i < n` and `i < N`; nothing otherwise) at cell `size t * i` for every thread `i`, every other
block unchanged. `vmul.family` and `vsub.family` are the same with `Model.mul` and `Model.sub`
at their own programs and functions.

## Proof

`vadd.sound_retype` is the general step, proved once. For every program `P` with
`vector_addition`'s layout and no globals, function `F` with `vadd.fn_0`'s parameters and a first
block, format `t` at which `F.retype P.layout t` passes the check, and paths `paths`, it is
`Kernel.sound_map2` at `P.retype t`, `F.retype P.layout t` and `Paths.retype t paths`. Its two
premises are what varies with the kernel and the format: the covers (`coversEntry`) at `t` and
`Map2.Step` at `t` (the premise `H` of `Kernel.sound_map2` as a proposition), for any bytes.
The rest of `Kernel.sound_map2`'s premises are discharged inside it at `vector_addition`'s
layout: the parameters, the argument types, the codec, the alignments, the attributes, the start
(by `vadd.startsOf`) and the cells' apartness.

Each family theorem is `vadd.sound_retype` at its kernel's program, function and paths, with:
- the check and the covers by `cases t <;> rfl` and `cases t <;> decide +kernel` (the path
  checker at each format);
- `Map2.Step` by cases on `t`: `vadd.step_half` and `vadd.step_bfloat` (and their twins) at the
  16-bit formats, and the family theorem itself at `.float` and `.double`. Each of these is one
  call of the tactic `mojo_map2_step`: it takes the three facts of `Map2.Pre` (`ne`, `le`,
  `lt`), puts the alignment premise at the format's alignment, introduces the thread and the
  premises of `Map2.Step`, and runs mojo_ret.

The thread runs at `.half` and `.bfloat` are separate declarations because one declaration's
heartbeat budget (200000, no override) does not hold two runs of mojo_ret at 16-bit formats:
measured, one run at a 16-bit format fits in a declaration, two do not, and the runs at `.float`
and `.double` fit together. mojo_ret at a variable `t` fails: `omega` does not reduce
`l.size (.fp t) * k`, and the loads and the float operation stay open.

## Instances

- At `.float`: `vadd.prog.retype .float = vadd.prog`, the same for the function and the paths
  and for the other two kernels, and `vadd.bytes ω x y` is `Elem.map2 vadd.prog.layout .float
  Model.add (fun k => ω k (Nat.pair 23 0) / 3) x y`, all by `rfl`. `vadd.correct`,
  `vmul.correct` and `vsub.correct` (generated by `mojo_kernel`, unchanged) are derived from the
  family theorems at `.float` by one `exact` each, as `example`s.
- At `.half` and `.bfloat`: `vector_addition`'s function retyped is the function of
  tests/corpus/vadd16/ and tests/corpus/vaddbf16/ with `vadd.fn_0`'s name, and the layouts are
  equal, by `rfl`. The programs differ in the module (the kernel's name), the digest and the list
  of kernels, so the family theorem at `.half` is about the retyped program, not about the file's.
  The kernel theorems at the two files' own programs, `v16.correct` and `vb16.correct`, are
  generated by `mojo_kernel` on each file with `map2 (.fp .half) (Val.ofFloat .half)` (and at
  `.bfloat`) and the bytes `Elem.map2` of `Model.add` at the format: they are proved at those
  files, not derived from the family theorem.
- At `.double`: no corpus file. The Mojo compiler at `float64` was run once on a copy of the
  source; its function is `vector_addition`'s retyped at `.double` up to the kernel's name, and
  the layouts are equal (checked by `rfl` in a module outside the repository, since the file has
  no corpus row).
- `vector_multiply` and vector_subtraction have no compile at another format in the corpus.

## Plan: the family theorem at the files' programs

Not built. The family theorem at `.half` is about `vadd.prog.retype .half` and its kernel
`vadd.fn_0.retype vadd.prog.layout .half`; the f16 file's program `v16.prog` and kernel
`v16.fn_0` are another program and another function. Equality of the function bodies (the
`rfl` above) is not enough: `Grid.start` and `step` read the program (its layout, intrinsics,
globals, attribute groups and the functions it calls by name), and every frame holds its
function, so the two grids differ in each frame's function, whose name `Thread.at` reads (the
collective calls compare threads' positions, MojoProof/Sem/Grid.lean, `Grid.fire`).

**Statement.** In a new module of MojoProof/Sem, after the pattern of
MojoProof/Sem/ContractOff.lean (`CtxOff`, `Grid.lockstep_contractOff`, `Grid.start_ctxOff`,
`Kernel.Sound.contractOff`), with a map of frames in place of a map of statements:

```lean
/-- Frame `f` running `G`. -/
def Frame.toFn (G : Func) (f : Frame) : Frame := { f with fn := G }
/-- Thread `t` with every frame running `G`; `Status.toFn`, `Grid.toFn` map every thread. -/
def Thread.toFn (G : Func) (t : Thread) : Thread := { t with frames := t.frames.map (·.toFn G) }
/-- Every frame of every thread of `g` runs `F`. -/
def Grid.OnlyFn (F : Func) (g : Grid) : Prop := ...

/-- Programs `P`, `Q` with kernels `F`, `G` agree on what `F`'s steps read. -/
structure Program.Renamed (P Q : Program) (F G : Func) : Prop where
  fn : { F with name := G.name } = G
  layout : Q.layout = P.layout
  intrinsics : Q.intrinsics = P.intrinsics
  calls : ∀ g, Callee.fn g ∈ F.callees → ∃ d, d.blocks.isEmpty ∧
    P.module.funcs.find? (·.name == g) = some d ∧ Q.module.funcs.find? (·.name == g) = some d ∧
    d.attrs Q.module = d.attrs P.module ∧ ∀ i, d.check Q.module i = d.check P.module i

theorem Grid.lockstep_toFn (h : Program.Renamed P Q F G) (hc : ∀ n, (c n).prog = P)
    (hc' : ∀ n, c' n = { c n with prog := Q }) (L : Launch) :
    Grid.Lockstep L c c' fun g₁ g₂ => g₁.OnlyFn F ∧ g₂ = g₁.toFn G

theorem Kernel.Sound.toFn (h : Program.Renamed P Q F G)
    (hg : Q.module.globals = P.module.globals) (hk : G.check Q.module = F.check P.module)
    (ha : ∀ l m n args ch, launchArgs l m n G args ch = launchArgs l m n F args ch) :
    Kernel.Sound P F L args m adm obs R → Kernel.Sound Q G L args m adm obs R
```

**Premises, and why each.** `fn`: the blocks, parameters and attributes `step` and `enter` read
are `F`'s. `layout` and `intrinsics`: every access, `getelementptr`, `byval` copy and intrinsic
call reads them. `calls`: a call looks its callee up in the module by name, checks it
(`Func.check`) and reads its attributes (`Func.attrs`, the attribute groups); every callee of
`F` is a declaration (an intrinsic or a collective), so no frame of another function is ever
pushed and every frame of either grid runs `F` or `G` (`Grid.OnlyFn`). Then `Thread.at` of a
thread of `g.toFn G` is that of the thread of `g` with the name `G.name` for `F.name`, the same
change for every thread, so two threads' positions are equal in one grid exactly when they are
in the other. `hg`, `hk`, `ha`: the start's reads (the shared tiles of the globals, the kernel's
check, the arguments); `ha` and `hk` are premises, not unfoldings, so the transport does not
depend on `launchArgs`' and `Func.check`'s bodies, and at a concrete pair each is closed by
evaluation. `Thread.start G args` is `Thread.start F args` mapped by `Thread.toFn G`, from `fn`.

**Proof.** As MojoProof/Sem/ContractOff.lean: one step of a thread of `F` under `c n` and its
image under `c' n` give results related by the map (`exec` reads the context's program only at
the reads above; `enter` and the return read the frame's blocks, which `fn` makes equal), then
`Grid.advance`, `Grid.fire` (`Thread.at` as above; `Thread.resume` reads the frame's blocks),
the done and race conditions (the pending accesses read the frames' statements and registers,
which the map keeps) and the trace (the map keeps memory). `Grid.Lockstep.sound` moves
`Grid.Sound`, and the start relation gives `Kernel.Sound.toFn`. The step lemma unfolds `step`'s
and `exec`'s equations, which the semantics' changes to their bodies can break.

**The instance at the two corpus files.** `P := vadd.prog.retype .half`,
`F := vadd.fn_0.retype vadd.prog.layout .half`, `Q := v16.prog`, `G := v16.fn_0`, and the same at
`.bfloat` with `vb16`. `fn` and `layout` are the `rfl`s of MojoProofTest/Formats.lean, and so
are `intrinsics`, `hg`, `hk` (both checks are `.ok ()`), and the callees' lookups and attributes
(the callees are the module's declarations after the kernel, equal in the two modules, and the
attribute groups are equal); the callees' checks at every instruction and `ha` (by `rfl` while
`launchArgs` reads only the parameters) are not checked yet. Then `Kernel.Sound.toFn` applied to
`vadd.family .half` is `v16.correct`'s statement (its bytes are at `v16.prog.layout`, which is
`(vadd.prog.retype .half).layout` by `rfl`), and `v16.correct`, `vb16.correct` become derived
from the family theorem instead of generated at the files.

**The alternative.** A family generic in the function's name (the retyped kernel at every name
`s`) needs no lockstep relation, but it reruns the symbolic proofs with the name abstract, and the
start and the program still differ beyond the name (the module's function list, its kernels), so
the `calls` and start premises above come back.

## Not covered

- The theorem that moves the family theorem at `.half` to the f16 file's program: planned above,
  not built.
- Kernels whose source is generic in the type of more than the elements, and formats other than
  the four `FloatTy`s.
