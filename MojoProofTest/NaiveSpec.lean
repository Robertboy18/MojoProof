import MojoProofTest.NaiveThread
import MojoProof.Sym.Kernel
import MojoProof.Sem.Matmul

/-!
# The naive matmul kernel's theorem, split at the thread: the statements

The kernel theorem of the naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean) with
`fmul contract` is `Kernel.sound_mapNWith` (MojoProof/Sym/Kernel.lean) at the blocks
`[bC, bA, bB]` of its three `byval` buffer structs, its three `i32` scalars `m`, `n`, `K`, the
output block `bC`, cells 4 bytes wide and the threads in bounds. This module states, as
definitions, what that theorem's per-thread premise asks of one thread, so that the thread's run
and the composition can be proved apart:

* `T`, `z`: the type of the buffer structs and the value of their tail.
* `S`, `cell`: thread `k` of launch `L` is in bounds (a thread of `L` whose row `L.index k .x`
  is below `m` and whose column `L.index k .y` is below `n`), and the byte offset of its cell of
  `C`, `(row * 50257 + column) * 4`.
* `o`, `pairs`, `bytes`: the oracle numbers of round `j` of a thread whose oracle is `w` (`w` at
  steps `54 + 18 j` and `55 + 18 j`, those of `NaiveThread.oN` at step count 0); the factor pairs
  of cell `(r, c)`, the first `K` elements of row `r` of `A` and of row `c` of `B`; and the bytes
  thread `k` puts, `dotLoop` with `fmul contract` from `+0` over its pairs, encoded as a binary32
  word, if it is in bounds, else none.
* `At`: the facts at the entry of thread `k`: those `Kernel.sound_mapNWith`'s per-thread premise
  gives (the context, the frame's function, its struct pointers and their loads, its scalar
  registers) and the precondition's buffer facts, on the thread's memory.
* `RunIn`, `RunOut`: a thread in bounds runs `NaiveThread.chainN` to `ret` (`RetLsWith true`)
  and a thread of the launch out of bounds runs `NaiveThread.skipN` to `ret` (`RetWith true`),
  from `At` and a memory of `Elem` after `k` threads whose accesses to `bC` are by threads in
  bounds (`Elem.Only`), to a memory of `Elem` after `k + 1` threads with the same property.

Nothing is proved here: these definitions are the interface between the thread's runs (`RunIn`
and `RunOut` for every launch, thread and memory) and the composition through
`Kernel.sound_mapNWith`.
-/

namespace MojoProofTest.NaiveSpec

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveThread
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- The type of the naive kernel's three `byval` buffer structs: a pointer and an empty
layout. -/
abbrev T : Ty :=
  .struct [.ptr 0, .struct [.struct [.struct [], .struct []], .struct [.struct [], .struct []]]]

/-- The value of the buffer structs' tail, the empty layout. -/
abbrev z : Val := .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]

/-- Thread `k` of launch `L` is in bounds for `m` rows and `n` columns: it is a thread of `L`,
its row `L.index k .x` is below `m` and its column `L.index k .y` is below `n`. -/
abbrev S (L : Launch) (m n k : Nat) : Prop :=
  k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n

/-- The byte offset of thread `k`'s cell of `C` in launch `L`: `(row * 50257 + column) * 4`. -/
abbrev cell (L : Launch) (k : Nat) : Nat :=
  (L.index k .x * 50257 + L.index k .y) * 4

/-- The oracle numbers of round `j`'s `fmul` and `fadd` for a thread with oracle `w` whose entry
valuation has step count 0: `w` at steps `54 + 18 j` and `55 + 18 j`, lane 0 (`NaiveThread.oN`
at step count 0). -/
def o (w : Nat → Nat) (j : Nat) : Nat × Nat :=
  (w (Nat.pair (54 + 18 * j) 0), w (Nat.pair (55 + 18 * j) 0))

/-- The factor pairs of cell `(r, c)`: for `j < min K 768`, element `j` of row `r` of `A` and
element `j` of row `c` of `B`, in that order. -/
def pairs {m n : Nat} (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) (r : Fin m) (c : Fin n) (K : Nat) :
    List (Model FloatTy.float.fmt × Model FloatTy.float.fmt) :=
  (List.ofFn fun j : Fin 768 => (Tensor.get2 A r j, Tensor.get2 B c j)).take K

/-- The bytes thread `k` of launch `L` puts at its cell, under the oracles `ω`: if it is in
bounds (`S`), the binary32 encoding in `naive`'s layout of `dotLoop` with `fmul contract` from
`+0` over the factor pairs of its cell (`pairs`) under its oracle numbers (`o (ω k)`); else
none. -/
def bytes (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) (k : Nat) : Option (List MemByte) :=
  if h : S L m n k then
    naive.prog.layout.encode (.fp .float) (.ofFloat .float
      (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨_, h.2.1⟩ ⟨_, h.2.2⟩ K)))
  else none

/-- **The facts at the entry of thread `k`** of launch `L` of the naive kernel on the buffers
`bC`, `bA`, `bB` (whose structs' copies are at blocks `p0`, `p1`, `p2`), `m` rows, `n` columns
and inner dimension `K`, with context `c`, memory `m'` and frame `f`: the launch and the
dimensions are in the kernel theorem's range, `c` is thread `k`'s context of `naive`'s program,
`f` is a frame of its function whose registers hold the struct pointers and the scalars, the
structs load from `m'` as those of `bC`, `bA`, `bB`, and on `m'` `bA` and `bB` are read-only
buffers holding `A` and `B` row-major and `bC` is a writable buffer of `m * 50257` cells. -/
structure At (L : Launch) {m n : Nat} (K bC bA bB p0 p1 p2 : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) (k : Nat) (c : Ctx) (m' : Mem)
    (f : Frame) : Prop where
  /-- Builds `At` from its fields. -/
  mk ::
  /-- The launch is valid. -/
  valid : L.Valid
  /-- The launch has side 1 in `z`, in its grid and its blocks. -/
  flat : L.grid .z = 1 ∧ L.block .z = 1
  /-- `n ≤ 50257`, `K ≤ 768`, and the `i32` products of the address arithmetic are in range. -/
  dims : n ≤ 50257 ∧ K ≤ 768 ∧ m * 50257 < 2 ^ 31 ∧ m * 768 < 2 ^ 31 ∧ n * 768 < 2 ^ 31
  /-- `k` is a thread of the launch. -/
  thread : k < volume L.grid * volume L.block
  /-- `c` is thread `k`'s context of `naive`'s program: its program, registers and identity. -/
  ctx : c.prog = naive.prog ∧ c.env = L.env k ∧ c.who = ⟨k, k / volume L.block⟩
  /-- `f` is a frame of `naive`'s function. -/
  fn : f.fn = naive.fn_0
  /-- `%0`, `%1`, `%2` point at offset 0 of the blocks `p0`, `p1`, `p2`, none of them `bC`. -/
  ptrs : f.regs (idx "0") = some (.ptr ⟨p0, 0⟩) ∧ f.regs (idx "1") = some (.ptr ⟨p1, 0⟩) ∧
    f.regs (idx "2") = some (.ptr ⟨p2, 0⟩) ∧ p0 ≠ bC ∧ p1 ≠ bC ∧ p2 ≠ bC
  /-- The structs at `p0`, `p1`, `p2` load from `m'` as the structs of `bC`, `bA`, `bB`. -/
  loads : m'.load naive.prog.layout c.who 0 T ⟨p0, 0⟩ (some 8) = .ok (.agg [.ptr ⟨bC, 0⟩, z]) ∧
    m'.load naive.prog.layout c.who 0 T ⟨p1, 0⟩ (some 8) = .ok (.agg [.ptr ⟨bA, 0⟩, z]) ∧
    m'.load naive.prog.layout c.who 0 T ⟨p2, 0⟩ (some 8) = .ok (.agg [.ptr ⟨bB, 0⟩, z])
  /-- `%3`, `%4`, `%5` are the 32-bit words of `m`, `n` and `K`. -/
  scalars : f.regs (idx "3") = some (.bits 32 (BitVec.ofNat 32 m)) ∧
    f.regs (idx "4") = some (.bits 32 (BitVec.ofNat 32 n)) ∧
    f.regs (idx "5") = some (.bits 32 (BitVec.ofNat 32 K))
  /-- `bA` and `bB` are not `bC`. -/
  ne : bA ≠ bC ∧ bB ≠ bC
  /-- On `m'`, `bA` is a read-only buffer of `m * 768` binary32 aligned to 4 whose generic
  addresses do not wrap and that holds `A` row-major from offset 0. -/
  bufA : m'.Buffer bA (m * 768 * 4) 4 false ∧ m'.Fits naive.prog.layout bA (m * 768 * 4) ∧
    m'.Holds naive.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) A
  /-- On `m'`, `bB` is a read-only buffer of `n * 768` binary32 aligned to 4 whose generic
  addresses do not wrap and that holds `B` row-major from offset 0. -/
  bufB : m'.Buffer bB (n * 768 * 4) 4 false ∧ m'.Fits naive.prog.layout bB (n * 768 * 4) ∧
    m'.Holds naive.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) B
  /-- On `m'`, `bC` is a writable buffer of `m * 50257` binary32 aligned to 4 whose generic
  addresses do not wrap. -/
  bufC : m'.Buffer bC (m * 50257 * 4) 4 true ∧ m'.Fits naive.prog.layout bC (m * 50257 * 4)

/-- **The per-thread premise for the threads in bounds**, under the oracles `ω`, of launch `L`
of the naive kernel on the buffers `bC`, `bA`, `bB` holding `A` and `B`, `m` rows, `n` columns
and inner dimension `K`: for every thread `k` in bounds (`S`), copies `p0`, `p1`, `p2` of the
structs, context `c` with oracle `ω k`, memories `m₀` and `m'` and frame `f` at which `At`
holds, if `m'` meets `Elem` after `k` threads (from `m₀`, block `bC`, cells `cell L` 4 bytes
wide, bytes `bytes ω L K A B`) and its accesses to `bC` are by threads in bounds
(`Elem.Only`), then the thread runs `chainN` from `f`'s entry valuation to `ret`
(`RetLsWith true`) with a memory that meets `Elem` after `k + 1` threads and whose accesses to
`bC` are by threads in bounds. -/
def RunIn (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) : Prop :=
  ∀ k p0 p1 p2 (c : Ctx) (m₀ m' : Mem) (f : Frame), S L m n k → c.oracle = ω k →
    At L K bC bA bB p0 p1 p2 A B k c m' f →
    Elem m₀ bC 4 (cell L) (bytes ω L K A B) k m' → Elem.Only bC (S L m n) m' →
    ∃ C ∈ [chainN], RetLsWith true
      (fun me => Elem m₀ bC 4 (cell L) (bytes ω L K A B) (k + 1) me ∧ Elem.Only bC (S L m n) me)
      C.loops (Valuation.entry c 0 m' f) C.l C.ds C.S C.E

/-- **The per-thread premise for the threads out of bounds**, under the oracles `ω`, of launch
`L` of the naive kernel on the buffers `bC`, `bA`, `bB` holding `A` and `B`, `m` rows, `n`
columns and inner dimension `K`: for every thread `k` out of bounds (not `S`; `At` makes it a
thread of the launch), copies `p0`, `p1`, `p2` of the structs, context `c`, memories `m₀` and
`m'` and frame `f` at which `At` holds, if `m'` meets `Elem` after `k` threads (as in `RunIn`)
and its accesses to `bC` are by threads in bounds (`Elem.Only`), then the thread runs `skipN`
from `f`'s entry valuation to `ret` (`RetWith true`) with a memory that meets `Elem` after
`k + 1` threads and whose accesses to `bC` are by threads in bounds. -/
def RunOut (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) : Prop :=
  ∀ k p0 p1 p2 (c : Ctx) (m₀ m' : Mem) (f : Frame), ¬ S L m n k →
    At L K bC bA bB p0 p1 p2 A B k c m' f →
    Elem m₀ bC 4 (cell L) (bytes ω L K A B) k m' → Elem.Only bC (S L m n) m' →
    ∃ ps ∈ [skipN], RetWith true (Valuation.entry c 0 m' f)
      (fun me => Elem m₀ bC 4 (cell L) (bytes ω L K A B) (k + 1) me ∧ Elem.Only bC (S L m n) me)
      ps

end MojoProofTest.NaiveSpec
