import MojoProofTest.GPUProof.Race

/-!
# Laminar traces of the toy machine

The toy machine (MojoProofTest/GPUProof/Toy.lean) with one level between the thread and the
launch, the warp of `w` consecutive lanes (level widths `[w]`). The hand-over (`handover`) passes
byte `0` of buffer `0` from lane to lane of warp `0` at the warp's barrier, and then to lane `0`
of warp `1` at the launch's barrier.

* Every run of the toy machine is laminar for its launch (`run_laminar`, from
  `MojoProofTest.GPUProof.Toy.reach_laminar`), so `GPUProof.HB.laminar_iff` applies to it.
* At two sizes, two warps of 2 lanes and three warps of 5, the run ends with every thread
  returned, the last lane's value in the byte and a trace that `racy` passes; `hb` agrees with
  the right side of `GPUProof.HB.laminar_iff` (`viaSync`) at every pair of positions, and orders
  the first write before the read through the launch's rendezvous alone. The mutant without the
  warp's barriers, and the one without the launch's barrier, race.
* The mutant for the other side: a hand-over through a release and an acquire is not laminar
  (`relAcq_not_laminar`), and on it `hb` orders a write before a read that no rendezvous lies
  between (`viaSync` refuses the pair).
-/

open GPUProof MojoProofTest.GPUProof.Toy MojoProofTest.GPUProof.Race

namespace MojoProofTest.GPUProof.Laminar

/-- The hand-over at `w` lanes per warp, for thread `t`: a lane `t < w` of warp `0` waits at `t`
warp barriers when `warp`, writes `t` to byte `0` of buffer `0`, and waits at the other `w - 1 - t`
warp barriers when `warp`, so lane `t + 1` writes after lane `t`; then every thread waits at the
launch's barrier when `top`, and thread `w` (lane `0` of warp `1`) reads byte `0`. -/
def handover (warp top : Bool) (w t : Nat) : List Ins :=
  let bars (k : Nat) : List Ins := if warp then List.replicate k (.bar (1 : Nat)) else []
  (if t < w then bars t ++ [.write 0 0 1 (UInt8.ofNat t) false] ++ bars (w - 1 - t) else []) ++
    (if top then [.bar ⊤] else []) ++ (if t = w then [.read 0 0 1 false] else [])

/-- The toy schedule's run of `handover warp top w` on `nw` warps of `w` lanes (level widths
`[w]`) over `w * nw` zero bytes, for at most `10 * (w * nw) + 10` steps. -/
def run (warp top : Bool) (w nw : Nat) : St :=
  runFor (10 * (w * nw) + 10) (launch (handover warp top w) (w * nw) (zeros (w * nw)) [w])

/-- One test machine (`toy`): the trace of every hand-over run is laminar for its launch, at every
number of lanes and warps, with and without the barriers. -/
theorem run_laminar (warp top : Bool) (w nw : Nat) :
    Laminar toy (w * nw, [w]) (run warp top w nw).trace :=
  (reach_laminar (runFor_reach _ _)).2.2

/-- The right side of `GPUProof.HB.laminar_iff` at positions `i` and `j` of trace `tr`, as a
check: `i < j`, both are positions, and the events there share an agent, or a rendezvous at a
position strictly between them has an agent of each among its agents. -/
def viaSync (tr : List Ev) (i j : Nat) : Bool :=
  decide (i < j) && tr[i]?.any fun e => tr[j]?.any fun e' =>
    e.agents.any (fun a => decide (a ∈ e'.agents)) ||
      (List.range tr.length).any fun k => decide (i < k) && decide (k < j) &&
        match tr[k]? with
        | some (.sync _ ms) =>
          e.agents.any (fun a => decide (a ∈ ms)) && e'.agents.any fun b => decide (b ∈ ms)
        | _ => false

/-- `hb` and `viaSync` agree at every pair of positions of trace `tr`. -/
def agrees (tr : List Ev) : Bool :=
  (List.range tr.length).all fun i => (List.range tr.length).all fun j =>
    hb toy tr i j == viaSync tr i j

-- the hand-over at two warps of 2 lanes and three warps of 5: the run ends race free with the
-- last lane's value in the byte; `hb` agrees with `viaSync` at every pair, and orders the first
-- write before the read, which share no agent
#guard [(2, 2), (5, 3)].all fun (w, nw) =>
  let z := run true true w nw
  allDone z && stopped z && !racy toy z.trace && kept toy z.trace &&
    byte z.mem (0, 0) == some (UInt8.ofNat (w - 1)) && z.trace.length == 2 * w + 1 &&
    agrees z.trace && hb toy z.trace 0 (2 * w) &&
    z.trace[0]?.map Event.agents == some [.thread 0] &&
    z.trace[2 * w]?.map Event.agents == some [.thread w]
-- the mutants: without the warp's barriers the lanes' writes race, and without the launch's
-- barrier the read races with the writes
#guard [(2, 2), (5, 3)].all fun (w, nw) =>
  racy toy (run false true w nw).trace && racy toy (run true false w nw).trace &&
    agrees (run false true w nw).trace && agrees (run true false w nw).trace

/-- Thread `0` writes `n` bytes of buffer `0` and releases phase `0` of object `1`; thread `1`
acquires it and reads the bytes. -/
def relAcqTrace (n : Nat) : List Ev := [w 0 0 n, rel 0 1 0, acq 1 1 0, r 1 0 n]

/-- One test machine (`toy`): the hand-over through a release and an acquire is not laminar for
any launch, at every size: its release is not an access, a fence or a rendezvous. -/
theorem relAcq_not_laminar (L : toy.Launch) (n : Nat) : ¬ Laminar toy L (relAcqTrace n) := by
  intro h
  have hm : rel 0 1 0 ∈ relAcqTrace n := by simp [relAcqTrace]
  rcases h _ hm with ⟨a, ha⟩ | ⟨_, _, _, ha⟩ | ⟨_, _, _, ha, -⟩ <;> cases ha

-- on it `hb` orders the write before the read, which share no agent and have no rendezvous
-- between them
#guard [3, 7].all fun n =>
  hb toy (relAcqTrace n) 0 3 && !viaSync (relAcqTrace n) 0 3 && !racy toy (relAcqTrace n)

end MojoProofTest.GPUProof.Laminar
