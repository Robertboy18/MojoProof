import MojoProof.LLVM.Syntax
import MojoProof.Sem.Value

/-!
# Tile programs and their interpreter

A tile program is a finite tree of events over cells of numbered buffers, with float choices at
semantic sites. This module defines:

* `Sig`, `Prog`: the programs over a signature of events (`Prog.ret`, `Prog.vis`), a monad by
  `Prog.bind`; every program is a finite tree, so every run ends;
* `Site`: a float site, a thread, a cell, a float operation and the term of a reduction it is
  for (never a compiled position);
* `TileI`, `TileE`: the tile events (`load`, `store`, `choose`, `barrier`, `ub`) and their
  answers over cell values `V`;
* `Access`, `St`: an access of the log and the interpreter's state (cells, access log, phase);
* `run1`, `runAll`: the interpreter of one thread and of threads `0` to `T - 1` in turn, at a
  tile oracle `q : Site → Nat` (the number of the float choice at each site); a load of a cell
  that was never set and `ub` stop the run with `Sem.Fault.ub`.

Nothing here is in the trusted base: these are definitions that theorems relate to the LLVM
semantics (MojoProof/Tile/Map2.lean).
-/

namespace MojoProof.Tile

/-- A signature of events: the type `I` of events and, for each event, the type `O e` of its
answer. -/
structure Sig where
  /-- The signature from its events and their answer types. -/
  mk ::
  /-- The events. -/
  I : Type
  /-- The type of the answer to each event. -/
  O : I → Type

/-- A program over the events of `E` that ends with a value of `α`: a finite tree whose leaves
are results and whose nodes are events, with one branch per answer. -/
inductive Prog (E : Sig) (α : Type) where
  /-- The program that ends with `a`. -/
  | ret (a : α)
  /-- The program that performs `e` and continues with `k` applied to the answer. -/
  | vis (e : E.I) (k : E.O e → Prog E α)

/-- Sequencing: `p.bind f` runs `p` and continues with `f` applied to its result. -/
def Prog.bind {E : Sig} {α β : Type} : Prog E α → (α → Prog E β) → Prog E β
  | .ret a, f => f a
  | .vis e k, f => .vis e fun o => (k o).bind f

/-- `Prog E` is a monad: `pure` is `Prog.ret` and `bind` is `Prog.bind`. -/
instance {E : Sig} : Monad (Prog E) where
  pure := .ret
  bind := Prog.bind

/-- A float site: the float operation `op` that thread `thread` performs for cell `cell`, for
term `idx` of a reduction (0 for an element-wise operation). It names no compiled position;
MojoProof/Tile/Map2.lean computes the kernel's step of a site from its paths. -/
structure Site where
  /-- The site from its thread, cell, operation and term. -/
  mk ::
  /-- The thread. -/
  thread : Nat
  /-- The cell the operation's result is for. -/
  cell : Nat
  /-- The float operation. -/
  op : LLVM.FBinOp
  /-- The term of a reduction the operation is for; 0 for an element-wise operation. -/
  idx : Nat
  deriving DecidableEq, Repr

/-- The tile events over cell values `V`. -/
inductive TileI (V : Type) where
  /-- Read cell `cell` of buffer `buf`. -/
  | load (buf cell : Nat)
  /-- Write `v` to cell `cell` of buffer `buf`. -/
  | store (buf cell : Nat) (v : V)
  /-- Ask for the number of the float choice at site `s`. -/
  | choose (s : Site)
  /-- End the current phase. -/
  | barrier
  /-- Stop with undefined behavior, with a message saying which. -/
  | ub (msg : String)

/-- The tile signature over cell values `V`: a `load` answers the cell's value, a `choose` a
number, `store` and `barrier` nothing, and `ub` has no answer (`Empty`), so a program stops
there. -/
abbrev TileE (V : Type) : Sig where
  I := TileI V
  O := fun
    | .load .. => V
    | .store .. => Unit
    | .choose _ => Nat
    | .barrier => Unit
    | .ub _ => Empty

/-- An access of the log: the thread, the buffer, the cell, whether it writes, and the phase it
happens in. -/
structure Access where
  /-- The access from its thread, buffer, cell, kind and phase. -/
  mk ::
  /-- The thread that accesses. -/
  thread : Nat
  /-- The buffer. -/
  buf : Nat
  /-- The cell. -/
  cell : Nat
  /-- `true` for a store, `false` for a load. -/
  write : Bool
  /-- The phase number at the access. -/
  phase : Nat
  deriving DecidableEq, Repr

/-- The interpreter's state over cell values `V`. -/
structure St (V : Type) where
  /-- The state from its cells, log and phase. -/
  mk ::
  /-- The value of cell `c` of buffer `b`, `none` if it was never set. -/
  cells : Nat → Nat → Option V
  /-- The accesses so far, latest first. -/
  log : List Access
  /-- The number of `barrier`s so far. -/
  phase : Nat

/-- **The run of thread `t`'s program** at tile oracle `q` from state `s`: the program's result
and the final state, handling each event: `load` answers the cell's value (a fault if it was
never set) and logs a read, `store` sets the cell and logs a write, `choose st` answers `q st`,
`barrier` advances the phase, and `ub` is a fault. -/
def run1 {V α : Type} (q : Site → Nat) (t : Nat) :
    Prog (TileE V) α → St V → Except Sem.Fault (α × St V)
  | .ret a, s => .ok (a, s)
  | .vis (.load b c) k, s =>
    match s.cells b c with
    | some v => run1 q t (k v) { s with log := ⟨t, b, c, false, s.phase⟩ :: s.log }
    | none => .error (.ub "load of a cell never set")
  | .vis (.store b c v) k, s =>
    run1 q t (k ()) { s with
      cells := fun b' c' => if b' = b ∧ c' = c then some v else s.cells b' c'
      log := ⟨t, b, c, true, s.phase⟩ :: s.log }
  | .vis (.choose st) k, s => run1 q t (k (q st)) s
  | .vis .barrier k, s => run1 q t (k ()) { s with phase := s.phase + 1 }
  | .vis (.ub msg) _, _ => .error (.ub msg)

/-- **The run of threads `0` to `T - 1`**, each to its end in turn, of the programs `p t` at
tile oracle `q` from state `s`: the final state, or the first fault. -/
def runAll {V : Type} (q : Site → Nat) (p : Nat → Prog (TileE V) Unit) :
    Nat → St V → Except Sem.Fault (St V)
  | 0, s => .ok s
  | T + 1, s =>
    match runAll q p T s with
    | .ok s => (run1 q T (p T) s).map Prod.snd
    | .error e => .error e

end MojoProof.Tile
