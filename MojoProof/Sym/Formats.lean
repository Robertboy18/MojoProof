import MojoProof.Sym.Kernel

/-!
# A program at another float format, and the per-thread premise of a binary elementwise kernel

The Mojo sources of the elementwise kernels are generic in their element type (`DType`); the
compiler emits one program per type. For `vector_addition` at `float16` and `bfloat16`
(tests/corpus/vadd16/, tests/corpus/vaddbf16/), the program differs from the `float32` one
(tests/corpus/vadd/) only in the kernel's name and in the four instructions on elements: the
`getelementptr`s' element type, the loads' and the store's type and alignment, and the type of
the `fadd`. `Program.retype t P` is that change, defined once for every program and format, so
that one theorem per kernel covers every format (`Kernels.vadd.family` and its twins at
`vector_multiply` and vector_subtraction).

Defined here:

- `Ty.retype t`: `float` becomes `t`; every other type is unchanged (vectors of floats, arrays
  and structs included).
- `Inst.retype l t`: the float binary operations, the float loads and stores and the
  `getelementptr`s have `float` replaced by `t`; an alignment `a` of a float load or store becomes
  `a * l.size (.fp t) / l.size (.fp .float)` (the alignment a scalar access of `t` has when the
  `float` one has its ABI alignment, and `a` itself at `.float`); every other instruction is
  unchanged. Float constants, casts, comparisons, calls and the instructions on vectors are not
  changed, so a kernel that has any of them on floats is not covered by its retyping.
- `Func.retype`, `Program.retype`: every instruction of every block and function, under the
  program's layout; names, parameters, attributes and the rest are unchanged.
- `SNode.retype`, `Summary.retype`, `Paths.retype`: the same on the block checker's summaries
  (only `fbin` and `fbinP` nodes carry a format; loads, stores and addresses carry none).
- `Map2.Step`: the per-thread premise `H` of `Kernel.sound_map2`, as a proposition, so that the
  thread runs of a kernel at several formats can be proved in a declaration apart from the kernel
  theorem's.

The equations at the corpus files are checked by the kernel in MojoProofTest/Formats.lean: at
`.float`, the retyping is the identity on the program, function and paths of each of the three
elementwise kernels (`vadd.prog.retype .float` is `vadd.prog`, and the same for `vmul` and
`vsub`); at `.half` and `.bfloat`, for `vector_addition` only, its function retyped is the f16
and bf16 files' function up to its name, and the layouts are equal. The corpus has no f16 or
bf16 file of `vector_multiply` or vector_subtraction, so no such equation is checked for them.
-/

namespace MojoProof.LLVM

/-- `ty` at float format `t`: `float` becomes `t`; every other type is unchanged. -/
def Ty.retype (t : FloatTy) : Ty → Ty
  | .fp .float => .fp t
  | ty => ty

/-- Instruction `i` at float format `t` under layout `l`: the type of a float binary operation,
of a float load or store and the element type of a `getelementptr` become `Ty.retype t` of
theirs, and an alignment `a` of a float load or store becomes `a * l.size (.fp t) /
l.size (.fp .float)`; every other instruction is unchanged. -/
def Inst.retype (l : Sem.Layout) (t : FloatTy) : Inst → Inst
  | .fbin op fm ty a b => .fbin op fm (ty.retype t) a b
  | .load v (.fp .float) p al =>
    .load v (.fp t) p (al.map fun a => a * l.size (.fp t) / l.size (.fp .float))
  | .store v (.mk (.fp .float) x) p al =>
    .store v (.mk (.fp t) x) p (al.map fun a => a * l.size (.fp t) / l.size (.fp .float))
  | .gep fl src b idx => .gep fl (src.retype t) b idx
  | i => i

/-- Function `f` at float format `t` under layout `l`: `Inst.retype l t` on every instruction of
every block; everything else is `f`'s. -/
def Func.retype (l : Sem.Layout) (t : FloatTy) (f : Func) : Func :=
  { f with blocks := ⟨f.blocks.toList.map fun b =>
      { b with stmts := ⟨b.stmts.toList.map fun s => { s with inst := s.inst.retype l t }⟩ }⟩ }

/-- Program `P` at float format `t`: `Func.retype` under `P`'s layout on every function of its
module; everything else is `P`'s. -/
def Program.retype (t : FloatTy) (P : Program) : Program :=
  { P with module := { P.module with funcs := ⟨P.module.funcs.toList.map (·.retype P.layout t)⟩ } }

end MojoProof.LLVM

namespace MojoProof.Sym

open LLVM Sem

/-- A summary node at float format `t`: a float binary operation at `float` is at `t`; every
other node is unchanged. -/
def SNode.retype (t : FloatTy) : SNode → SNode
  | .fbin op fm .float n a b => .fbin op fm t n a b
  | .fbinP op fm .float n a b pa pb => .fbinP op fm t n a b pa pb
  | s => s

/-- Summary `S` at float format `t`: `SNode.retype t` on every node. -/
def Summary.retype (t : FloatTy) (S : Summary) : Summary :=
  { S with nodes := S.nodes.map (·.retype t) }

/-- Paths at float format `t`: `Summary.retype t` on every summary of every path. -/
def Paths.retype (t : FloatTy) (ps : List (List (Nat × List Cond × Summary))) :
    List (List (Nat × List Cond × Summary)) :=
  ps.map (List.map fun (l, ds, S) => (l, ds, S.retype t))

/-- **The per-thread premise of `Kernel.sound_map2`**, for program `prog`, kernel `fn`, launch
`L`, paths `paths`, struct type `T` of alignment `al'` with tail `z`, element type `t` with
encoder `enc`, alignment `al`, block numbers `a`, `b`, `o`, count `n`, tensors `x`, `y`, oracle
`ω`, cells `cell` of `w` bytes and bytes `bs`: every thread `k` of the launch, at every context,
memories and frame whose registers hold the three structs' addresses and the count, whose
structs hold the buffers' pointers, whose buffers are live, hold `x` and `y` and do not wrap, and
after `k` threads of the elementwise invariant `Elem`, takes one of `paths` to `ret` (`Ret`) with
`Elem` after `k + 1` threads. It is `H` of `Kernel.sound_map2`, word for word. -/
def Map2.Step (prog : Program) (fn : Func) (L : Launch)
    (paths : List (List (Nat × List Cond × Summary))) (T : Ty) (al' : Nat) (z : Val) {α : Type}
    [TorchLean.Storage α] (t : Ty) (enc : α → Val) (al a b o n : Nat) {N : Nat}
    (x y : TorchLean.Tensor α [N]) (ω : Nat → Nat → Nat) (w : Nat) (cell : Nat → Nat)
    (bs : Nat → Option (List MemByte)) : Prop :=
  ∀ k, k < volume L.grid * volume L.block → ∀ c : Ctx, c.prog = prog →
    c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ → c.oracle = ω k →
    ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn → ∀ q0 q1 q2 : Nat,
    f.regs 0 = some (.ptr ⟨q0, 0⟩) → f.regs 1 = some (.ptr ⟨q1, 0⟩) →
    f.regs 2 = some (.ptr ⟨q2, 0⟩) → f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)) →
    m'.load prog.layout c.who 0 T ⟨q0, 0⟩ (some al') = .ok (.agg [.ptr ⟨a, 0⟩, z]) →
    m'.load prog.layout c.who 0 T ⟨q1, 0⟩ (some al') = .ok (.agg [.ptr ⟨b, 0⟩, z]) →
    m'.load prog.layout c.who 0 T ⟨q2, 0⟩ (some al') = .ok (.agg [.ptr ⟨o, 0⟩, z]) →
    m'.Buffer a (n * prog.layout.size t) al false →
    m'.Buffer b (n * prog.layout.size t) al false →
    m'.Buffer o (n * prog.layout.size t) al true →
    m'.Holds prog.layout a t enc (rowMajor prog.layout t 0) x →
    m'.Holds prog.layout b t enc (rowMajor prog.layout t 0) y →
    m'.Fits prog.layout a (n * prog.layout.size t) →
    m'.Fits prog.layout b (n * prog.layout.size t) →
    m'.Fits prog.layout o (n * prog.layout.size t) → q0 ≠ o ∧ q1 ≠ o ∧ q2 ≠ o →
    Elem m₀ o w cell bs k m' →
    ∃ ps ∈ paths, Ret (Valuation.entry c 0 m' f) (Elem m₀ o w cell bs (k + 1)) ps

end MojoProof.Sym
