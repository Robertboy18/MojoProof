import MojoProof.Sem.Sig
import MojoProofTest.Embed

/-!
# `sig` on `vadd` at two launches

One program (vadd, `Kernels.vadd.prog`) at two launches, 2 blocks of 2 threads (`launch2 2 1 2 1`)
and 1 block of 4 threads (`launch2 1 1 4 1`), with the buffers of `memV`
(`MojoProofTest/Start.lean`) filled with zero bytes (`memZ`; `memV`'s bytes are undefined, and
adding them faults), zero address choices and the zero oracle, by evaluation (`check`):

* `sig`'s own steps (`run`: each thread steps until it waits or returns, then the calls complete)
  from `sig.start` end with every thread returned, and their trace is the reversed trace of the
  grid's evaluator (`Grid.run`) on the same start, as core events, with 6 accesses per thread
  (three reads of its `byval` copies, the two frozen loads, the store);
* the core's `racy` at `sig` (`GPUProof.racy sig`) agrees with MojoProof's race check by phases
  (`fast`, MojoProof/Sem/Race.lean) on the final trace (no race), and the core's `kept` at `sig`
  (`GPUProof.kept sig`) keeps every frozen read of it;
* a mutant of the final trace, with a write by thread 3 to the bytes of thread 0's store in front,
  races for `fast`, and the core's `racy` at `sig` refuses it too.

Two `atomicrmw`s of one operation on the same bytes by two threads, with no barrier between them,
as MojoProof logs them (`rmwPair`: each a read, then its write), by evaluation (`rmwRacy`): with
`xchg` (which does not commute) they race for `fast` and for the core's `racy` at `sig` on the
core events; with `add` (which commutes) they race for neither. At 4 bytes at offset 0 by
threads 0 and 1 (one block of threads), and at 2 bytes at offset 6 by threads 1 and 2 (two blocks
of threads), of `launch2 2 1 2 1`.

Statements about this program, these launches and this memory.
-/

namespace MojoProofTest.Sig

open MojoProof.Sem MojoProof.LLVM MojoProof MojoProofTest.Start

/-- `memV` with zero bytes: blocks 1 to 3, each `Close.blk` with 16 bytes `0`, and `next = 4`. -/
def memZ : Mem :=
  { blocks := fun c =>
      if 1 ≤ c ∧ c ≤ 3 then some { Close.blk with size := 16, bytes := fun _ => .byte 0 } else none,
    next := 4 }

/-- Thread `n` takes `sig`'s steps until it waits or returns, for at most `fuel` steps. -/
def runThread (n : Nat) : Nat → sig.State → Except Fault sig.State
  | 0, s => pure s
  | fuel + 1, s => do
    match ← sig.advance s (.thread n) with
    | some s' => runThread n fuel s'
    | none => pure s

/-- `sig`'s run from `s`, for at most `phases` phases: each thread of the launch in turn steps
(`runThread`), then each thread's call completes where it can (`sig.fire`); the run stops after a
phase in which no call completes. -/
def run (fuel : Nat) : Nat → sig.State → Except Fault sig.State
  | 0, s => pure s
  | phases + 1, s => do
    let ns := sig.threads (sig.launchOf s)
    let s ← ns.foldlM (fun s n => runThread n fuel s) s
    let (s, fired) ← ns.foldlM (init := (s, false)) fun (s, b) n => do
      match ← sig.fire s n with
      | some s' => pure (s', true)
      | none => pure (s, b)
    if fired then run fuel phases s else pure s

/-- `vadd` started by `sig.start` on launch `L` and `memZ`, with zero address choices and the zero
oracle, and run by `sig`'s steps (`run`) and by the grid's evaluator (`Grid.run`): every thread
of `sig`'s run returns; its trace is the evaluator's, oldest first, as core events
(`Event.toCore`), with 6 accesses per thread; the core's `racy` at `sig` agrees with `fast` on
it (no race) and the core's `kept` at `sig` keeps it; and the trace with a write by thread 3 to
the bytes of thread 0's store in front races for both. -/
def check (L : Launch) : Except Fault Bool := do
  let s₀ ← sig.start (Kernels.vadd.prog, Kernels.vadd.fn_0) L argsV memZ (fun _ => 0, fun _ _ => 0)
  let s ← run 1000 10 s₀
  let g ← Grid.run L s₀.2.2 1000 10 s₀.1
  let tr := sig.trace s
  let store := g.mem.trace.findSome? fun
    | .access a => if a.write && a.who.thread == 0 then some a else none
    | .barrier _ => none
  let mutant := match store with
    | some a => .access { a with who := ⟨3, 3 / volume L.block⟩ } :: g.mem.trace
    | none => g.mem.trace
  return s.1.threads.size == 4 && s.1.threads.all (· matches .done) &&
    tr == (g.mem.trace.map (Event.toCore L)).reverse && tr.length == 24 &&
    GPUProof.racy sig tr == fast s.1.mem.trace && !fast s.1.mem.trace &&
    GPUProof.kept sig tr &&
    store.isSome && fast mutant && GPUProof.racy sig (mutant.map (Event.toCore L)).reverse

#guard (check (launch2 2 1 2 1)).toOption == some true
#guard (check (launch2 1 1 4 1)).toOption == some true

/-- An `atomicrmw` of operation `op` by thread `n` of launch `L` on the `len` bytes at offset `off`
of block 1, as MojoProof logs it, newest first: its write in front of its read. -/
def rmwPair (L : Launch) (n : Nat) (op : RmwOp) (off : Int) (len : Nat) : List Event :=
  let a : Access := ⟨⟨n, n / volume L.block⟩, ⟨1, off⟩, len, false, some op, false⟩
  [.access { a with write := true }, .access a]

/-- `fast` and the core's `racy` at `sig` (on the core events, oldest first) of the
trace in which thread `j` of launch `L` updates the `len` bytes at offset `off` of block 1 by
operation `op` after thread `i` does, with no barrier between them. -/
def rmwRacy (L : Launch) (i j : Nat) (op : RmwOp) (off : Int) (len : Nat) : Bool × Bool :=
  let tr := rmwPair L j op off len ++ rmwPair L i op off len
  (fast tr, GPUProof.racy sig (tr.map (Event.toCore L)).reverse)

#guard rmwRacy (launch2 2 1 2 1) 0 1 .xchg 0 4 == (true, true)
#guard rmwRacy (launch2 2 1 2 1) 0 1 .add 0 4 == (false, false)
#guard rmwRacy (launch2 2 1 2 1) 1 2 .xchg 6 2 == (true, true)
#guard rmwRacy (launch2 2 1 2 1) 1 2 .add 6 2 == (false, false)

end MojoProofTest.Sig
