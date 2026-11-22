# Skeleton transfer, the output term and payload relations (T3, T4, T5)

Status. T3a is proved as stated below, for every launch, contexts and relation
(MojoProof/Sem/Lockstep.lean; instance and twin in MojoProofTest/Lockstep.lean). T3b's relations on
values, memory, threads and grids (`Val.erase`, `Val.Skel`, `MemByte.erase`, `MemByte.Skel`,
`Block.SkelEq`, `Mem.SkelEq`, `Labels`, `Labels.Rel`, `Frame.Skel`, `Thread.Skel`, `Thread.payRes`,
`Intrinsic.eraseArgs`, `Status.Skel`, `Grid.SkelRel`; `Val.Skel`, `Mem.SkelEq`, `Thread.Skel`,
`Status.Skel` and `Grid.SkelRel` reflexive and symmetric) are stated in MojoProof/Sem/Skeleton.lean,
with the instances `skel_vals`, `skel_pay`, `skel_thread` and `skel_grid` and counterexample (iii)
`addr_twin` (two address choices give memories that are not related) in MojoProofTest/Skeleton.lean.
So are its memory lemmas, proved for every layout, type and set of payload blocks:
`Layout.encode_erase`, `Layout.decode_erase` (for data types, `Ty.data`, and at most the stored
size), `Mem.check_skel`, `Mem.load_skel`, `Mem.store_skel`, `Mem.set_skel`, `Mem.log_skel`,
`Mem.alloc_skel` and `Mem.setLive_skel` (instances and twins `decode_twins`, `load_skel`,
`store_skel`, `alloc_skel`); `evalV_skel`, for every scope, type, operand and two oracles
(`castV_ch`; `eval_skel`, `fpext_twin`); and `lanes_skel`, `lanes2_skel`, `intCast_skel`,
`intBin_skel`, `icmpV_skel`, `floatBin_skel`, `fcmpV_skel`, `fnegV_skel`, `selectV_skel`,
`extractE_skel`, `insertE_skel`, `shuffleV_skel`, `extractV_skel`, `insertV_skel`, `castV_skel`,
`fminmax_skel` and `rsqrt_skel` (`trunc_skel`, `pair_skel`, `bin_skel`, `icmp_skel`, `float_skel`,
`select_skel`, `elem_skel`, `shuffle_skel`, `value_skel`, `cast_skel`, `maxnum_skel`,
`approx_skel`); and `withAttrs_skel` (`attrs_skel`). The labelling checks `Labels.Ok` and
`Labels.MemOk` (with `Labels.MemOk.of_closed`) are stated in MojoProof/Sem/Labels.lean (instances
and twins `vadd_ok`, `vadd_twin`, `branch_twin` and `store_ok` in MojoProofTest/Labels.lean).
`exec_skel`, for every statement, is proved in MojoProof/Sem/SkelExec.lean (with `exec_call_skel`
for calls; instance `exec_inst`, twins `exec_twin` of `Labels.stmtOk`, `exec_mem_twin` of
`Labels.MemAt` and `exec_call_twin` of `Labels.Ok` in MojoProofTest/SkelExec.lean). So is
`enter_skel`, for every block entry of a function that passes `Labels.funcOk` (instance
`enter_inst`, twin `enter_twin` of `Labels.funcOk`). `step_skel`, for every step of related threads
whose first's frames meet `Labels.FramesOk` (kept by `step_framesOk`), and `Grid.advance_skel`, for
every thread of related grids, are proved in MojoProof/Sem/SkelStep.lean, and so is
`Grid.FramesOk` at every grid reachable from a start whose kernel is the module's function of its
name (`Grid.start_reach_framesOk`) (instances `step_inst`, `call_framesOk`, `advance_inst` and
`start_framesOk`, twins `ret_twin` and `fn_twin` of `Labels.FramesOk`, `call_framesOk_twin` of
`Labels.Ok` and `start_framesOk_twin` of the premise on the kernel in
MojoProofTest/SkelStep.lean), and so is `Thread.pending_skel`, for every pair of related threads
(instance `pending_inst`, twin `pending_twin` of `Labels.Ok`), and so is `Grid.fire_skel`, for
every collective call of related grids whose first meets `Grid.FramesOk` under the one program of
all contexts and `Grid.AtCalls` (instance `fire_inst`, twins `fire_atCalls_twin`,
`fire_prog_twin`, `fire_ok_twin` and `fire_framesOk_twin`). So are `Grid.start_skel`, for every two
starts on related memories (instance `start_inst`, twin `start_twin` of `Mem.SkelEq`), and T3b
itself, `Grid.skel_lockstep`, for every start whose program passes `Labels.Ok`, whose kernel is the
module's function of its name and that meets `Labels.MemOk` (instance `lockstep_inst`), and T3 on
T3b's relation, `Grid.skel_run`, for every such start on the first of two related caller memories
and every run from it to a done grid that is not bad (instance `run_inst`, one kernel that returns
at once on memories that differ in one data byte; twin `run_twin` of `Mem.SkelEq`; and
`PayloadRun.run_inst`, one kernel that loads a float from the payload block, adds it to itself and
stores the sum, twin `PayloadRun.run_twin`). T3c on terms is proved to the end of a returning path
(sections "To the next block's entry" and "Along a path"); T4 has no Lean beyond one summary's
check (section "The term block `%21` of `vector_addition` stores"); of T5, the rows one operation
at a time are proved (section "T5's rows"), the term statement `SVal.eval_respects` is not.

The proof relies on these properties of the semantics (MojoProof/Sem):

- An `alloca`'s addresses come from `Ctx.addr` (skeleton choices), and `Ctx.oracle` holds the
  float freedoms only (MojoProof/Sem/Thread.lean). So no oracle position is a skeleton choice.
- An `alloca`'s block is `Mem.fresh m n k = m.next + Nat.pair n k`. Two runs in lockstep make the
  same block numbers, so no renaming is needed.
- An admitted `atomicrmw` leaves its result register unset (its old value depends on the order of
  the atomics on one location).
- The threads of a collective call are matched on their position, not on a position and a count
  of completed calls. A different matching would change the proof of `Grid.fire_skel` below but
  not its statement: two runs in lockstep have the same positions and step counts, so one
  matching applies to both sides.

**Scope.**
- T3a: every launch, two context families and every relation.
- T3b: every program, kernel, launch, arguments and address choice, with two caller memories that
  agree off a set of payload blocks and two payload oracles, for a program whose registers carry a
  labelling that passes `Labels.Ok`. The memory hypothesis `Labels.MemOk` is on the first run only.
- T4: every program with a block summary of the symbolic checker (MojoProof/Sym).
- T5: every relation and every term.

Which corpus kernels pass `Labels.Ok` is not claimed here, except `vector_addition` (`vadd_ok`,
MojoProofTest/Labels.lean). Expected, and not checked:
- `tiled_matmul` passes. Its payload operations are `fadd`, `fmul` and `fadd contract`, and its
  guards and addresses come from special registers and the size argument.
- `ln64` keeps payload in `{ float, float, float }` aggregates, which T3b admits, and calls
  `rsqrt.approx` (82 calls in the corpus, none with fast-math flags). `Op.Total` lists
  `rsqrt.approx` without `nnan` and `ninf` (`rsqrt_skel`).

A kernel that branches on payload, or computes an address from it, is outside T3. It is verified
per payload and oracle by the block simulation alone; T1, T2 and T2′ still apply to it.

**How the proof is organized.**
1. T3 is split in two:
   - T3a: a lockstep bisimulation between the grids of two context families carries runs, `Done`
     and `Bad`, and `Grid.Sound` for observations it preserves, for every relation.
   - T3b: the skeleton relation `Grid.SkelRel` is such a bisimulation for a labelled program.
2. Obliviousness is a labelling of the SSA registers of each function, payload or skeleton,
   checked on the program text (`Labels.Ok`, decidable and evaluated by the kernel).
   - An SSA register has one definition, so a label per register is exact. `Labels.Ok` checks
     that guards, accesses and collective calls do not depend on payload, on registers instead of
     on terms.
   - The memory part, which payload block each access may touch, is the hypothesis
     `Labels.MemOk` on one run. Deriving it from the block checker's access terms is not
     proved.
   - So T3b does not depend on the symbolic block checker. T3c and T4 do.
3. Payload-dependent faults: T3b admits only payload operations that are total on data words. T3c
   adds the partial ones (division by payload, integer and fast-math flags on payload,
   float-to-integer casts, `range` on payload). Their domain conditions become hypotheses on both
   runs, stated on T4's terms.
4. T3 ends with what the composition uses: a run on one payload to a grid that is done and not bad
   gives one on the other, so `Grid.start_sound` applies to the other (`Grid.payload_run`).

## T3a: lockstep transfer, for every relation

### Definitions

```lean
/-- Two results of a step (an `advance` or a `fire`) agree under `S`: both fault, both take no
step, or both give grids related by `S`. -/
def Grid.Agree (S : Grid → Grid → Prop) : Except Fault (Option Grid) → Except Fault (Option Grid) → Prop
  | .error _, .error _ => True
  | .ok none, .ok none => True
  | .ok (some g₁), .ok (some g₂) => S g₁ g₂
  | _, _ => False

/-- `S` is a lockstep bisimulation between the grids of launch `L` under contexts `c` and `c'`:
related grids agree on every thread's step and every collective call, are done together, have
one trace, and have a race enabled together. -/
structure Grid.Lockstep (L : Launch) (c c' : Nat → Ctx) (S : Grid → Grid → Prop) : Prop where
  advance : ∀ {g₁ g₂}, S g₁ g₂ → ∀ n, Grid.Agree S (g₁.advance c n) (g₂.advance c' n)
  fire : ∀ {g₁ g₂}, S g₁ g₂ → ∀ n, Grid.Agree S (g₁.fire L c n) (g₂.fire L c' n)
  done : ∀ {g₁ g₂}, S g₁ g₂ → (g₁.Done ↔ g₂.Done)
  trace : ∀ {g₁ g₂}, S g₁ g₂ → g₁.mem.trace = g₂.mem.trace
  race : ∀ {g₁ g₂}, S g₁ g₂ → (g₁.RaceEnabled c ↔ g₂.RaceEnabled c')
```

`S` is any relation. To use invariants (W1 to W5, `Labels.MemOk`), put them into `S`, for
example `S x y := ReflTransGen (Grid.Step L c) g₀ x ∧ R x y`. A step keeps such an `S` because
the step's target is reachable.

### Statement

For every launch `L`, contexts `c`, `c'`, relation `S` with `hS : Grid.Lockstep L c c' S`, and
grids with `S g₁ g₂`:

- `Grid.Lockstep.symm`: `Grid.Lockstep L c' c (flip S)`.
- `Grid.Lockstep.step`: `Grid.Step L c g₁ h₁ → ∃ h₂, Grid.Step L c' g₂ h₂ ∧ S h₁ h₂`, by the
  same thread number and the same kind of step.
- `Grid.Lockstep.path`: `Path (Grid.Step L c) k g₁ z₁ → ∃ z₂, Path (Grid.Step L c') k g₂ z₂ ∧
  S z₁ z₂`. The converse comes from `symm`.
- `Grid.Lockstep.bad`: `g₁.Bad L c ↔ g₂.Bad L c'`.
- `Grid.Lockstep.sound`: for every observation `obs` with `hO : ∀ x y, S x y → x.Done →
  obs x.mem = obs y.mem` and every `R`: `Grid.Sound L c g₁ obs R → Grid.Sound L c' g₂ obs R`.
- `Grid.payload_run` (the corollary T3 is used through): suppose `Grid.start prog fn L args m'
  ch ω' = .ok (g₂, c')` with `m'.BytesIn m'.Known`, and suppose `Path (Grid.Step L c) k g₁ z₁`
  with `z₁.Done` and `¬ z₁.Bad L c`. Then there is a `z₂` with `Path (Grid.Step L c') k g₂ z₂`,
  `z₂.Done`, `¬ z₂.Bad L c'` and `S z₁ z₂`. And for every `obs` that reads only the blocks, every
  `R` and `y`, if `obs z₂.mem = some y` and `R y`, then `Grid.Sound L c' g₂ obs R` (by
  `Grid.start_sound`).

### Proof

- `Grid.Agree` flips: `Grid.Agree S a b → Grid.Agree (flip S) b a`, by cases on `a` and `b`. Each
  field of `symm` is the flip of the field, or `Iff.symm`, or `Eq.symm`.
- `step`: `Grid.Step L c g₁ h₁` is `∃ n, g₁.advance c n = .ok (some h₁) ∨ g₁.fire L c n = .ok
  (some h₁)`. In the first case, rewrite `hS.advance hs n` with it. Cases on `g₂.advance c' n`
  leave only `.ok (some h₂)` with `S h₁ h₂`, the others being `False`. The fire case is the same.
- `path`: induction on the path, by `step`.
- `bad`, the four disjuncts of `Grid.Bad` in turn:
  - `Faults`: `g₁.advance c n = .error e` makes `Grid.Agree S (.error e) (g₂.advance c' n)`, which
    forces `.error _`. The same holds for `fire`, and the other direction is by `symm`.
  - `racy` and `kept`: rewrite by `trace`.
  - `RaceEnabled`: this is `race`.
- `sound`, field by field. For `h₂` reachable from `g₂`, `symm.path` (through `Path.exists_iff`)
  gives an `h₁` reachable from `g₁` with `S h₁ h₂`.
  - `safe`: a fault of `h₂` is a fault of `h₁` (`bad`'s first case).
  - `raceFree` and `kept`: by `trace`.
  - `progress`: if `h₂` is not done, `h₁` is not done (`done`). Then `h₁` has a step, and `step`
    gives `h₂` one.
  - `terminates`: by induction on `Acc`, `∀ h₁, Acc (flip (Grid.Step L c)) h₁ → ∀ h₂, S h₁ h₂ →
    Acc (flip (Grid.Step L c')) h₂`. A step of `h₂` is matched by one of `h₁` (`symm.step`), and
    the induction hypothesis applies to its target.
  - `determinate`: if `h₂` and `h₂'` are done, then `h₁` and `h₁'` are done, and `obs h₂.mem =
    obs h₁.mem = obs h₁'.mem = obs h₂'.mem` (`hO` twice, and `g₁`'s `determinate`).
  - `post`: `obs h₂.mem = obs h₁.mem = some y` with `R y`.
- `payload_run`: `path` gives `z₂`. `done` and `bad` move `z₁.Done` and `¬ z₁.Bad`. The last part
  is `Grid.start_sound` on `g₂`'s start with the run to `z₂`.

The proof uses no property of the semantics beyond the definitions of `Grid.Step`, `Grid.Bad` and
`Grid.Sound`. It is the real-grid form of the miniature's `CRel.step`, `CRel.path`, `CRel.flip`
and `payload_transfer`.

## T3b: the skeleton relation

### Definitions

```lean
/-- `v` with every data word replaced by the zero word of its width, through vectors and
aggregates: what the skeleton sees of a value. -/
def Val.erase : Val → Val   -- with `Val.eraseAll` on lists (structural, mutual)
  | .bits w _ => .bits w 0
  | .vec xs => .vec (Val.eraseAll xs)
  | .agg xs => .agg (Val.eraseAll xs)
  | v => v

/-- Payload-related values: equal but for their data words, which have one width. Pointers,
`poison` and `undef` are equal; vectors and aggregates are related element by element, at any
depth (`ln64` keeps payload in a `{ float, float, float }`). -/
def Val.Skel (x y : Val) : Prop := x.erase = y.erase

/-- A data byte becomes the zero byte; other bytes stay. -/
def MemByte.erase : MemByte → MemByte
  | .byte _ => .byte 0
  | b => b

/-- Payload-related bytes: equal, or both data bytes. -/
def MemByte.Skel (b₁ b₂ : MemByte) : Prop := b₁.erase = b₂.erase

/-- Blocks equal in every field but `bytes`, whose bytes are payload-related, and equal unless
`p` (the block is payload). -/
structure Block.SkelEq (p : Prop) (B₁ B₂ : Block) : Prop where
  shape : { B₁ with bytes := fun _ => .undef } = { B₂ with bytes := fun _ => .undef }
  bytes : ∀ i, (B₁.bytes i).Skel (B₂.bytes i)
  same : ¬ p → ∀ i, B₁.bytes i = B₂.bytes i

/-- Memories equal but for the data bytes of the blocks `pay`: one `next`, one trace, and at every
number both no block or blocks related by `Block.SkelEq`. -/
structure Mem.SkelEq (pay : Nat → Prop) (m₁ m₂ : Mem) : Prop where
  next : m₁.next = m₂.next
  trace : m₁.trace = m₂.trace
  blocks : ∀ b, Option.Rel (Block.SkelEq (pay b)) (m₁.blocks b) (m₂.blocks b)

/-- A labelling: the payload registers of each function (by name), and whether its result is
payload. -/
structure Labels where
  reg : String → Nat → Bool
  ret : String → Bool
```

`Thread.Skel lab t₁ t₂` relates two threads:
- equal `k`;
- frames pairwise by `Frame.Skel lab`: equal but for `regs` and `prods` (as `Block.SkelEq.shape`,
  the frames with both fields cleared are equal, so `fn`, `label`, `pc`, `allocas` and `dest` are);
- registers equal where `lab.reg fn.name r = false` and `Option.Rel Val.Skel` where it is true
  (`Labels.Rel`);
- `prods` payload-related the same way, both operands by `Val.Skel`.

`Status.Skel` relates statuses with one constructor:
- `run` with `Thread.Skel`;
- `wait` with `Thread.Skel`, one intrinsic and declaration, and arguments related by the label of
  the call's result register (`Thread.payRes`, the register `Thread.resume` sets): when it is
  payload, the arguments are equal after `Intrinsic.eraseArgs`, which erases the exchanged value
  of a shuffle and nothing else (the mask, lane operand and width decide which lane a value comes
  from, so they are skeleton); when it is skeleton, the arguments are equal. The exchanged value
  is copied to some lane's result register, so a payload value may only be exchanged into a
  payload register.
- `done` with `done`.

`Grid.SkelRel lab pay g₁ g₂` holds when the grids have the same number of threads, their statuses
are related at every number, and `Mem.SkelEq pay g₁.mem g₂.mem` holds.

`Labels.Ok prog lab` (MojoProof/Sem/Labels.lean) checks each function of `prog`
(`Labels.funcOk`) and each of its statements (`Labels.stmtOk`); it is a `Bool`, evaluated by the
kernel. An operand of function `fn` is skeleton when it mentions no payload register of `fn`
(`Value.mentions (lab.reg fn.name)`); a constant is skeleton.
- (O1) Every operand that decides control or an address is skeleton:
  - `condBr` and `switch` conditions, and `select` conditions;
  - the pointer operands of `load`, `store` and `atomicrmw`, `getelementptr` bases and indices;
  - `alloca` counts, `extractelement` and `insertelement` indices, `shufflevector` masks;
  - the arguments of intrinsic calls (`lifetime.*`, collectives, special registers), but a
    `shfl.sync`'s exchanged value (its second argument) and the operands of `maxnum`, `minnum`
    and `rsqrt.approx`;
  - arguments for skeleton parameters of defined functions ((O4)).
- (O2) A statement with a skeleton result has skeleton operands and reads no payload choice
  (`Scope.ch`): it is not `fadd`, `fsub`, `fmul`, `fdiv`, `frem`, `fpext`, `fptrunc`, `maxnum`,
  `minnum` or `rsqrt.approx`. `fneg`, `fcmp` and the other casts read no oracle number (Thread.lean,
  Eval.lean), so they may have skeleton results on skeleton operands.
- (O3) A statement with a payload result has operands that are registers or skeleton
  (`TValue.payOk`; LLVM's constants hold no register, so a vector or constant expression with a
  payload register is not LLVM), and is one of:
  - `add`, `sub`, `mul`, `and`, `or`, `xor`, `shl`, `lshr`, `ashr`, `udiv` and `urem` with flags
    of `BinOp.total` (no `nsw`, `nuw`, `exact` or `disjoint`), the shift amount or divisor
    skeleton (`BinOp.skelB`);
  - `fadd`, `fsub`, `fmul`, `fdiv`, `fneg` and `fcmp` without `nnan` and `ninf` (`nsz`, `arcp`,
    `afn` and `reassoc` fault on both sides, `FastMath.check`; `frem` faults on both, Op.lean);
  - every `icmp`, cast, `select` (on a skeleton condition), `phi`, `extractvalue`, `insertvalue`,
    `extractelement`, `insertelement` and `shufflevector`, with skeleton operands where (O1)
    asks;
  - `maxnum`, `minnum` and `rsqrt.approx` without `nnan` and `ninf`;
  - a `shfl.sync`, a call to a defined function, an intrinsic call on skeleton arguments, an
    `alloca` or a `getelementptr`, whose results are related as their operands are skeleton;
  - a `load` of a data type (`Ty.data`: integers of whole bytes and floats, through vectors,
    arrays and structs). `Layout.decode` reads an `i1` from one byte and gives `poison` for a
    number of 2 or more, so for an `i1` whether the result is `poison` would depend on the
    payload. This is the only place a data type is required: `Mem.load_skel`'s premise. Payload
    `icmp` and `fcmp` results are `i1` words, related by `Val.Skel` (`icmpV_skel`, `fcmpV_skel`).

  `rsqrt.approx` is in the list because `rsqrt` is total: it returns a word on every operand and
  oracle number, the oracle's if it meets the contract, else the fallback. So on two 32-bit words
  it gives two floats (`rsqrt_skel`). Under `nnan` or `ninf` whether it gives `poison` depends on
  its operand, so those flags fail (T3c). Aggregates are admitted because `ln64` keeps payload in
  a `{ float, float, float }`.

  The property that defines the list: on operands related by `Val.Skel`, for every two oracle
  numbers, the operation faults on both sides or on neither, and its results are related by
  `Val.Skel`. `Val.Skel` operands have their `poison` and `undef` lanes at the same places, so
  `poison` comes out at the same places too; a data word gives a data word for every oracle number
  (`floatBin` by `exists_deliver`, Float.lean). An operation for which this fails is not in the
  list. These flags break it: `or disjoint` on `i8` gives 3 on (1, 2)
  and `poison` on (1, 1); `fadd nnan` gives a word on (0, 0) and `poison` on (NaN, 0). A shift
  amount of at least the width gives `poison`, and a divisor of 0 faults, so those operands must
  be skeleton. `sdiv` and `srem` fault on the minimum divided by -1, which reads both operands,
  so they go to T3c.

  A `select` on a payload condition (`fcmp` then `select`, as in a NaN-aware maximum) is
  excluded by (O1): if the condition differed, the two runs would pick different operands, and
  one of them might be `poison`. Admitting it, with a flag for payload registers that are never
  `poison`, is left to T3c.
- (O4) Labels agree across calls and returns:
  - a payload argument of a defined function goes to a payload parameter (an argument past the
    parameters is skeleton), and a call to a function with a payload result (`lab.ret`) has a
    payload result register;
  - the arguments of a call to a function the module does not have are registers or skeleton
    (`exec` evaluates them before it refuses the call); a call of inline assembly passes
    (`exec` refuses it before it evaluates anything), and a call through a pointer has no form
    in the AST (`Callee`), as the parser refuses it;
  - a `ret` of a payload operand is in a function with a payload result;
  - a stored value, a payload argument and a returned payload operand are registers or skeleton
    (`TValue.payOk`, as in (O3));
  - payload parameters and results have no `range` attribute (whose test reads the value), and
    neither has the declaration of a `maxnum`, `minnum` or `shfl.sync` with a payload result
    (`withAttrs` in `exec` and `resumeAll`; a waiting shuffle's arguments are related only up to
    its exchanged value, so its result is checked whenever it is payload).

  The kernel's parameters need no condition: the two runs take the same arguments, so payload
  enters through memory.

Instances and twins (MojoProofTest/Labels.lean): `vector_addition` passes `Labels.Ok` with `%25`,
`%27` and `%28` payload (`vadd_ok`); with the stored pointer `%29` payload too it fails (O1), and
with `%28` not payload it fails (O2) (`vadd_twin`). A `condBr` on a payload register fails
`Labels.Ok`, and two frames related by `Frame.Skel` whose condition holds 1 and 0 step to
different blocks, so the threads after are not related (`branch_twin`). A store of a vector that
holds a payload register fails `Labels.Ok` (`payOk_twin`; the AST of `<i8 %0>`, which is not LLVM
IR and which the parser refuses).

`Labels.MemOk lab pay L c g₀` holds when every grid that launch `L` with contexts `c` reaches from
`g₀` meets `Labels.MemAt` at each running thread's next statement (`Labels.MemAll`):
- a `load` with a skeleton result reads a block outside `pay`;
- a `store` of a payload operand writes a block in `pay`;
- an `atomicrmw` with a payload operand updates a block in `pay`.

An `alloca` needs nothing: `pay` names blocks to be made too, and a store of payload into the new
block must then be in `pay`. `Labels.MemOk.of_closed` gives it from a set of grids that holds
`g₀`, is closed under `Grid.Step` and meets `Labels.MemAll` at each grid. Instance and twin
`store_ok`: a grid of one thread that stores the payload register 0 to block 1 meets it with block
1 payload, for every launch, and not with no block payload.

`pay` is fixed for the run and names blocks to be made too: `Mem.fresh` numbers them, and those
numbers are the same in both runs. The blocks of a buffer the caller gives hold payload if `pay`
says so; `byval` copies hold pointers and sizes, so they are skeleton.

### Statement

For every program, kernel, launch, arguments, address choice `ch`, labelling `lab` with
`Labels.Ok prog lab`, payload blocks `pay`, caller memories with `Mem.SkelEq pay m₁ m₂`, and
oracles `ω₁`, `ω₂`:

- `Grid.start_skel` (proved): `Except.Rel (fun r₁ r₂ => Grid.SkelRel lab pay r₁.1 r₂.1 ∧ ∀ n,
  r₂.2 n = { r₁.2 n with oracle := (r₂.2 n).oracle }) (Grid.start prog fn L args m₁ ch ω₁)
  (Grid.start prog fn L args m₂ ch ω₂)`: both starts fault, or both give related grids and
  contexts that differ only in their oracles.
- `Grid.skel_lockstep` (T3b, proved): if `Grid.start prog fn L args m₁ ch ω₁ = .ok (g₁, c₁)`, with
  `Labels.MemOk lab pay L c₁ g₁` and `prog.module.funcs.find? (·.name == fn.name) = some fn` (the
  kernel is the module's function of its name; `Grid.start` takes any function; see
  `Grid.FramesOk` below), then for all contexts `c₂` with `c₂ n = { c₁ n with oracle :=
  (c₂ n).oracle }`, `Grid.Lockstep L c₁ c₂ (fun x y => ReflTransGen (Grid.Step L c₁) g₁ x ∧
  Grid.SkelRel lab pay x y)`.
- T3 is `Grid.payload_run` on T3b's relation (proved: `Grid.skel_run`). One run on `(m₁, ω₁)` to
  a grid that is done and not bad gives such a run on `(m₂, ω₂)`, of as many steps and with an end
  related to the first's by `Grid.SkelRel`, and soundness there for every observation of the
  blocks whose value at its end satisfies `R`. That value is T4's term. `Grid.payload_run` asks
  `Mem.BytesIn m₂.Known` of the second memory; it follows from the first's (`Mem.SkelEq.bytesIn`:
  related memories have one `next`, blocks at the same numbers and the same pointer bytes).

### Lemmas used (to prove unless marked proved)

- `Val.Skel` and `MemByte.Skel` are reflexive and symmetric (equalities after erasure); so are
  `Mem.SkelEq` and `Grid.SkelRel` (proved: `Val.Skel.refl`, `Val.Skel.symm`, `Mem.SkelEq.refl`,
  `Mem.SkelEq.symm`, `Grid.SkelRel.refl`, `Grid.SkelRel.symm`).
- `Val.erase` keeps the constructor and the width of a word, and the length of a vector or
  aggregate. So `Val.Skel` values have the same shape: a word and a word of one width, the same
  pointer, both `poison`, both `undef`, or two vectors (two aggregates) of one length related
  element by element.
- `Layout.decode_erase` (proved): for every layout, data type
  `t` (`Ty.data`: integer widths are multiples of 8, no pointers, at any depth) and list `bs` of
  at most `l.stored t` bytes, `(l.decode t bs).map Val.erase = (l.decode t (bs.map
  MemByte.erase)).map Val.erase`. So byte lists related pointwise by `MemByte.Skel` decode to
  `Val.Skel` values, or both to `none`. Both premises are needed (`decode_twins`):
  - an `i1` reads one byte, and `[byte 2]` gives `poison` where its erasure `[byte 0]` gives a
    word;
  - an `i8` read from two bytes gives `poison` from `[byte 1, byte 1]` and a word from
    `[byte 0, byte 0]`.

  A `load` reads exactly `l.stored t` bytes, and `decode` passes each element and field a slice
  of at most its stored size, so the premises hold all the way down (`Layout.decodeAll_erase`,
  `Layout.decodeFields_erase`). For `scalarOf` (`Layout.scalarOf_erase`): erasure keeps the bytes
  that are not data, so the list has a `poison` (an `undef`) byte exactly when its erasure has
  one, and otherwise both are all data. Then the number is below `2 ^ (8 * length)`, which is at
  most `2 ^ w`, so both give a word. `ptrOf` reads its data bytes (all zero gives null), so a
  pointer load must be skeleton and outside `pay`, which is (O3) and `MemOk`.
- `Layout.encode_erase` (proved): for every layout, type and value, `(l.encode t v).map (·.map
  MemByte.erase) = (l.encode t v.erase).map (·.map MemByte.erase)`. So `Val.Skel` values encode to
  pointwise `MemByte.Skel` bytes, or both to `none`. `encode` writes a word as data bytes, a
  pointer, `poison` and `undef` as bytes that do not depend on any word, and pads with `undef`;
  the lengths depend only on the type and the shape (`Layout.encodeAll_erase`,
  `Layout.encodeFields_erase`).
- `Mem.check_skel` (proved): the checks of an access (`Mem.check`) read only the block's fields
  but `bytes`, so on `Mem.SkelEq` memories they give one fault, or related blocks at one offset
  (`Except.Rel`: one fault, or related results). `ptrtoint` reads the block's `addr` and
  `gaddr`, which agree too, so a cast of equal operands gives one result (in `evalV_skel`, by
  `evalV_shape`).
- `Mem.load_skel` (proved): one fault, or values that are `Val.Skel`, and equal outside `pay`; a
  load from a block in `pay` is at a data type. Instance and twin `load_skel` (an `i1` load from
  a payload block gives a word in one run and `poison` in the other).
- `Mem.store_skel` (proved): a store of `Val.Skel` values, equal outside `pay`, gives one fault or
  `Mem.SkelEq` memories. Instance and twin `store_skel` (different words stored to a block
  outside `pay` give memories that are not related).
- `Mem.set_skel`, `Mem.log_skel`, `Mem.alloc_skel` (one block number too) and `Mem.setLive_skel`
  (proved; instance `alloc_skel`): setting related blocks at one number, recording one event, an
  allocation of one block and setting a block live or dead keep `Mem.SkelEq`. `Mem.fresh` is equal
  on equal `next` by definition.
- `evalV_skel` (proved, for every scope, type, operand and two oracles; instance and twin
  `eval_skel`): with `Mem.SkelEq` memories, and registers equal outside a set `p`, an operand
  that mentions no register of `p` (`Value.mentions p`; `evalV_regs`) has one value, whatever the
  oracle numbers of the two scopes. An operand reads no oracle number: a cast in a constant
  expression is one LangRef admits there (`CastOp.const`: `trunc`, `ptrtoint`, `inttoptr`,
  `bitcast`, `addrspacecast`), none of which reads one (`castV_ch`: no cast but `fpext` and
  `fptrunc` does), and the parser and `evalV` refuse the others (twin
  `fpext_twin`: the `fpext` instruction of a `half` NaN gives two words under two oracle
  numbers). So a skeleton operand has equal values. A constant expression reads only block fields
  but `bytes` (`ptrtoint` of a global reads its address). A payload operand that is a register
  has `Val.Skel` values by `Labels.Rel`; one that mentions no register has one value by
  `evalV_skel`. (O3) admits no other payload operand (`TValue.payOk`).
- `Op.total_skel`, one lemma per row of `Op.Total`: `Val.Skel` operands of a data type give
  `Val.Skel` results, or both fault, for every two oracle numbers. This is where the oracle may
  differ. Proved so far: `lanes_skel` (for all lane functions that give related results on
  related lanes, two oracle numbers allowed, `lanes` gives related results; by `Except.Rel.mapM`)
  and the row of `trunc`, `zext` and `sext` on scalars, `intCast_skel` (instance and twin
  `trunc_skel`: a lane function that makes `poison` of the word 1 gives results that are not
  related), `lanes2_skel` (the same for `lanes2` and two-operand lane functions, also with
  second operands equal when a proposition `P` holds; instance and twin `pair_skel`), and the row
  of the integer binary operators on scalars, `intBin_skel`: for every width, and every operator
  and flags of `Op.Total` (`BinOp.total`: no flag, not `sdiv` or `srem`), related scalars whose
  second ones are equal if the operator reads its value (`BinOp.skelB`: the shifts, `udiv` and
  `urem`) give related results (instance and twins `bin_skel`: `or disjoint` of 1 and 2 gives 3
  and of 1 and 1 `poison`; `sdiv` of -128 and of 0 by -1 faults and gives 0; `shl` of 1 by 1 and
  by 9 in `i8` gives 2 and `poison`). In `exec`, the `bin` row is `lanes2_skel` with
  `P := op.skelB = true` and `intBin_skel`. The `icmp` row, `icmpV_skel`, holds for every
  layout, predicate and type, pointers included, on memories related for some set of payload
  blocks (related pointers are equal and have one address, `Mem.addr_shape`; instance and twins
  `icmp_skel`: a pointer comparison faults on a memory with no block 1 and not on `memX 1`;
  `icmp eq` of an `i8` with an `i16` faults). The rows of `fadd`, `fsub`, `fmul` and `fdiv`
  (`floatBin_skel`, on scalars; `frem` faults on both sides), `fcmp` (`fcmpV_skel`) and `fneg`
  (`fnegV_skel`) hold for every float type, operator or predicate, factors and two oracle
  numbers, with flags without `nnan` and `ninf`, as (O3) requires (`FastMath.check` refuses
  `nsz`, `arcp`, `afn` and `reassoc` on both sides; instance and twins `float_skel`: `fadd`
  of a NaN under two oracle numbers gives two NaN words; with `nnan` a NaN operand, and with
  `ninf` an infinite one, gives `poison` and 0 a word). In `exec`, the `fbin` row is
  `lanes2_skel` with `P := False` and `floatBin_skel`. `floatBin` delivers a word of the format
  for every oracle number (`exists_deliver`, Float.lean). The `select` row, `selectV_skel`,
  holds for every type and condition (the condition is skeleton by (O1); twin `select_skel`:
  `true` and `false` select a pointer to block 1 and one to block 2); the `extractelement`,
  `insertelement` and `shufflevector` rows (`extractE_skel`, `insertE_skel`, `shuffleV_skel`)
  for every type and index or mask, and the `extractvalue` and `insertvalue` rows
  (`extractV_skel`, `insertV_skel`) for every list of indices: related vectors and aggregates
  have one shape, so the operations take one path and fault together (twins `elem_skel`,
  `shuffle_skel`, `value_skel`: two indices, masks or index lists give results that are not
  related). The cast rows, `castV_skel`, hold for every layout, cast, two types, any oracle
  numbers and memories related for some set of payload blocks, so `trunc`, `zext`, `sext`,
  `fpext`, `fptrunc` (`floatCast_skel`), `sitofp`, `uitofp` (`intToFloat_skel`) and `bitcast`
  between all types (`bitcast_skel`: related values have their poison bits at the same places,
  `toBitList_skel`, `ofBitList_skel`), and also `ptrtoint` and `addrspacecast` (twin `cast_skel`:
  `ptrtoint` faults on a memory with no block 1 and not on `memX 1`). The `maxnum` and `minnum`
  row, `fminmax_skel`, holds for every type, two contexts and two scopes, with flags without
  `nnan` and `ninf`, as (O3) requires: the intrinsic call (Thread.lean) gives one
  fault, or two results with related values that leave the scopes' memories unchanged. It is
  `lanes2_skel` with `P := False` and `floats2_skel` (also the core of `fcmpV_skel`), since
  `withFlags` then gives the IEEE 754 result (`withFlags_some`) and two floats of one type give
  related words (`Val.ofFloat_skel`); twins `maxnum_skel`: with `nnan` a NaN operand, and with
  `ninf` an infinite one, gives `poison` and 0 a word. The `rsqrt.approx` row, `rsqrt_skel`,
  holds for every two contexts, two scopes and related operands, with flags without
  `nnan` and `ninf`: two 32-bit words give two floats, whatever the words and the two oracle
  numbers (by the definitions of `withFlags` and `FastMath.poisons`), `poison` gives `poison`,
  and every other operand faults on both sides. Its proof is by cases on the two operands and the
  definition of `intrinsic`, and needs no theorem about `rsqrt`, since `rsqrt` returns a word on
  every operand by definition; so `Grid.skel_six`'s proof closure still has no theorem of
  FloatLib, Sem/Float or Sem/FloatRel. In `exec_call_skel` its case is the `maxnum` case with one
  argument (`intrinsic_rsqrt`: it never returns `none`). Instance and twins `approx_skel`: 1
  under the oracle number 0 (its word `+0` misses the contract, so the fallback 1) and 4 under
  the word of 0.5 give the related words of 1 and 0.5; with `nnan`, -1 gives `poison` and 1 a
  word; with `ninf`, likewise `+0`. `Labels.Ok`'s row and its twins: `rsqrt_ok`
  (MojoProofTest/Labels.lean).
- `withAttrs_skel`, proved for every layout, type, list of attributes and memories related for
  some set of payload blocks: on related values with no `range` attribute, or on equal values,
  `withAttrs` gives one fault or related values. `noundef` needs no premise: related values are
  both defined or both not (`Val.Skel.defined`, by `Val.defined_erase`), so it faults on both
  sides or neither; `nonnull` and `align` read the address of one pointer (`Mem.addr_shape`); the
  attributes act in turn (`Except.Rel.foldlM`). Twin `attrs_skel`: `range i8 0, 2` gives a word
  on the word 1 and `poison` on the word 2. In `enter` and `exec` the premise comes from (O4) at
  payload parameters and results (no `range` there) and from equal skeleton values elsewhere.
- `enter_skel` (`phi`s by `evalV_skel` and `evalV_pay`), `exec_skel` and `step_skel`. Each is
  `Except`-agreement: both fault, or both succeed with related results and `Mem.SkelEq` memories.
  The cases follow `exec` and `step`:
  - skeleton statements: the operands are equal, so the results are equal (O2);
  - payload statements: (O3) with `Op.total_skel`;
  - `load` and `store`: (O1) makes the pointer equal, and `MemOk` with `Mem.load_skel` and
    `Mem.store_skel` gives the values;
  - `alloca`: the count is equal (O1), the number is `Mem.fresh` on equal `next`, and the
    addresses are `c.addr` on equal `ch`, so the new block is the same block of undefined bytes;
  - `atomicrmw`: `rmw` on data words gives a data word, and the result is unset (S2);
  - calls: (O4);
  - terminators: the condition is equal (O1), so the edge is the same.
- `step_skel` (proved), as stated: for every labelling `lab`, payload blocks `pay`, context `c` whose
  program passes `Labels.Ok`, oracle `o`, threads related by `Thread.Skel` whose first has frames
  that meet `Labels.FramesOk lab c.prog`, memories related by `Mem.SkelEq`, with `Labels.MemAt` at
  the first thread's next statement (in its scope, `Labels.MemNext`), `step` under `c` and under
  `{ c with oracle := o }` gives
  one fault or results related by `Step.Skel lab pay (t₁.payRes lab)`: `next` with threads related
  by `Thread.Skel` and memories by `Mem.SkelEq`; `wait` at one intrinsic declared by one function,
  with arguments equal after `Intrinsic.eraseArgs` when the call's result is payload and equal when
  not (as `Status.Skel` needs); `done` with memories related. `Labels.FramesOk lab prog fs` is the
  invariant this needs on the thread's frames: every frame's function is the module's function of
  its name (`Array.find?`), so it passes `Labels.funcOk` by `Labels.Ok` (`Labels.FramesOk.funcOk`),
  and each two adjacent frames `f` (the callee) and `g` (its caller) meet `lab.ret f.fn.name →
  f.dest.any (lab.reg g.fn.name)` (`List.IsChain`): a function with a payload result returns into a
  payload register. `Labels.Ok` alone does not give it: the kernel of `Grid.start` is any function
  and `f.dest` is the caller's register. Asking for the module's function, not only one
  that passes `Labels.funcOk`, is what `Grid.fire_skel` needs too: two threads at one `Thread.at`
  (which compares names) then run one function. The proof
  follows `step`:
  - no frame, or no current block: frames related by `Frame.Skel` have one function, label and
    statement index, so both runs fault the same way;
  - a statement `st`: `exec_skel`, with `Labels.stmtOk` from the frame function's
    `Labels.funcOk`. Its label `st.res.any (lab.reg f.fn.name)` is `t₁.payRes lab`. A `next`
    replaces the first frame and keeps the others; a `wait` is related as `Eff.Skel` relates it; a
    call of `g` with arguments related at its payload parameters reads `g.blocks[0]?`, `g.check`
    and the functions of the frames (the `norecurse` check), all equal, and gives callee frames
    whose register `r` is the argument at the first parameter named `r`, payload exactly when `r`
    is a payload register of `g`, so they are related (`List.find?` on `g.params.zip args`);
  - `br`, `condBr`, `switch`: the condition is skeleton (`Labels.funcOk`), so it has one value
    (`evalV_skel`), one edge or one fault, and `enter_skel`; `unreachable` faults in both;
  - `ret`: a skeleton operand has one value (`evalV_skel`) and `withAttrs` on one value and
    memories of one shape gives one result (`withAttrs_shape`); a payload operand is in a function
    with a payload result and is a register (`Labels.funcOk`), so its values are related
    (`evalV_pay`), and the result has no `range` attribute, so `withAttrs_skel` keeps them related.
    The frames have one list of `alloca`s, set dead in turn (`Mem.setLive_skel`). With no caller
    both are `done`. Otherwise the caller's register `f.dest` is set to values related by
    `Labels.Rel (lab.ret f.fn.name)`, and by `Labels.FramesOk` it is a payload register when that
    label is true (`Labels.Rel.mono`, `Frame.Skel.next`).
- `step_framesOk` (proved): `Labels.FramesOk` holds after a step to `next` of a context whose program
  passes `Labels.Ok`. `exec` and `enter` keep a frame's function and `dest` (`exec_fn`,
  `enter_fn`); a call's function is the module's `find?` of the callee's name (`exec_call`), and
  the callee's `dest` is the call's result register, which (O2) makes payload when the callee's
  result is (`Labels.stmtOk`); a `ret` drops the first frame, and setting the caller's register
  keeps its function and `dest`.
- `Grid.advance_skel` (proved), as stated: for every labelling, payload blocks, contexts `c₁` and `c₂`
  with `c₂ n = { c₁ n with oracle := (c₂ n).oracle }`, grids related by `Grid.SkelRel` and thread
  number `n`, if `c₁ n`'s program passes `Labels.Ok`, thread `n` of `g₁`, if it runs, has frames
  that meet `Labels.FramesOk`, and `g₁` meets `Labels.MemAll`, then `g₁.advance c₁ n` and
  `g₂.advance c₂ n` agree (`Grid.Agree`). Related statuses have one constructor, so both threads
  run or neither does; if both run, `step_skel`, and each result sets status `n` of related arrays
  to related statuses (`Option.Rel.set!`): `next` to running threads related by `Thread.Skel` with
  the memories after; `wait` to the threads before the step (related) at one intrinsic and
  declaration with the arguments as `Step.Skel` relates them, which is `Status.Skel`'s wait case,
  with the memories before; `done` to two returned threads with the memories after.
- `Grid.FramesOk lab prog g` (proved), the invariant `Grid.advance_skel` and `Grid.fire_skel` need
  of the first grid: every running and waiting thread has frames that meet `Labels.FramesOk` under
  `prog` (`Status.FramesOk`), the program of every context (`hp : ∀ n, (c n).prog = prog`, which
  `Grid.start` gives, `Grid.start_ctx`), so every frame's function is the module's `find?` of its
  name. For every labelling and contexts whose programs are `prog` and pass `Labels.Ok`, a
  grid step keeps it (`Grid.advance_framesOk`: `step_framesOk` for `next`, a wait keeps the thread,
  and `done` has no frames), and so does a fire (`Grid.fire_framesOk`: a resume replaces the first
  frame by one of the same function and `dest`, `Thread.resume_framesOk` by `Labels.FramesOk.head`),
  so every grid reachable from one that meets it does (`Grid.reach_framesOk`, by `Grid.reach_inv`).
  It holds at the start if the kernel is the module's `find?` of its name, as every thread has one
  frame of the kernel (`Grid.start_framesOk`, by `Grid.start_run`), and so at every grid reachable
  from the start if the program passes `Labels.Ok` (`Grid.start_reach_framesOk`; instance
  `start_framesOk`, twin `start_framesOk_twin`: a kernel with the name of the module's kernel and
  other statements). So two threads at one `Thread.at` (which compares function names) are at one
  statement of one function, and their next results are both payload or both not. Without the
  start's condition this fails: `step` refuses a call to a function already on the stack only if it
  is `norecurse`, so a kernel outside the module can call a module function with its name.
- `Grid.fire_skel` (proved, MojoProof/Sem/SkelStep.lean; instance `fire_inst`, on the launches of
  one kernel for every address choice and every two oracles, twins `fire_atCalls_twin`,
  `fire_prog_twin`, `fire_ok_twin` and `fire_framesOk_twin` in MojoProofTest/SkelStep.lean),
  for every labelling, payload blocks, launch, program `prog` that
  passes `Labels.Ok`, contexts as in `Grid.advance_skel` whose programs are all `prog`, grids
  related by `Grid.SkelRel` whose first meets `Grid.FramesOk lab prog` and `Grid.AtCalls c₁`, and
  thread number `n`: `g₁.fire L c₁ n` and `g₂.fire L c₂ n` agree. `Grid.AtCalls` (W5, kept by
  every step, fire and path and given by `Grid.start`) says each waiting thread is at a call of the
  saved declaration, the module's bodiless function of the callee's name, whose intrinsic is the
  saved one (`Thread.AtCall`); without it a waiting status could hold any declaration, and
  `resumeAll` applies its attributes. The one program makes the lanes' frames meet
  `Labels.FramesOk` under one module. Statuses have
  one constructor, so thread `n` waits in both or in neither; if it waits, the intrinsic and
  declaration are one, and the arguments are equal or (payload result) equal after
  `Intrinsic.eraseArgs`, which changes only a shuffle's exchanged value (`Intrinsic.barrier_args`,
  `Intrinsic.shfl_args`). The layout is one (`c₂` differs in the oracle only).
  - barrier `[x]`: `eraseArgs` is the identity, so `x` is one, and so are the checks on it. The
    group depends on `n` and `L` only. At each member, related statuses have one constructor, and
    related waiting threads have one intrinsic, one argument list (a barrier) and one `Thread.at`
    (`Frame.Skel` keeps function, label and index), so `states` is one list or both fault.
    `resumeAll` with no results resumes related threads to related threads (`Thread.resume` with
    `none` sets no register), and `Mem.log_skel` relates the memories.
  - shuffle `[msk, a, b, c]`: `msk`, `b` and `c` are one at each lane, so the checks, `lanes`, and
    the `parts` but their exchanged values are one, and `parts.mapM id` is `none` on both sides or
    on neither (`List.Forall₂.mapM_id`). Every lane is at thread `n`'s `Thread.at`
    (`Thread.Skel.at`), so by `Grid.FramesOk` under one program all run one function at one
    statement and have one `Thread.payRes`, thread `n`'s (`Thread.payRes_at`). If it is false the
    exchanged values are equal, so each `res k` is one value; if true they are related by
    `Val.Skel`, `src` keeps that (`List.find?` on one index list, the default `poison` on both
    sides), and so does `res k`. `resumeAll` then sets each lane's result register to `withAttrs` of
    related values: equal values give one result (`withAttrs_shape`), and related values with no
    `range` attribute related results (`withAttrs_skel`; both in `withAttrs_rel`). With a payload
    result the saved declaration has no `range` attribute: by `Grid.AtCalls` it is the module's
    declaration of the lane's current call, which passes (O3) as a statement of a function of the
    module (`Thread.AtCall.noRange`; twins `shfl_range_twin`, `fire_atCalls_twin`,
    `fire_ok_twin`). The resumed threads are related (`Frame.Skel.next` at the call's result
    register, payload exactly when `Thread.payRes` is true), and the memory is unchanged.
  - `ldmatrix`, `mma` and ill-typed arguments: both fault.
  `resumeAll` is a `List.foldlM` over one list of thread numbers, so `Except.Rel.foldlM` with
  `Option.Rel.set!` at each step gives related arrays (`resumeAll_skel`, `Thread.Skel.resume`).
  Another matching of the threads of a collective call would change the matching but not the
  argument: it reads positions, step counts and `Thread.at`, all equal in related grids.
- `Thread.pending_skel` (proved, MojoProof/Sem/SkelStep.lean; instance `pending_inst`, twin
  `pending_twin` in MojoProofTest/SkelStep.lean), for every labelling, payload blocks, context whose
  program passes `Labels.Ok`, oracle, threads related by `Thread.Skel` whose first's frames meet
  `Labels.FramesOk`, and memories related by `Mem.SkelEq`: the pending accesses (`Thread.pending`)
  under the context and under it with the oracle are equal. Related frames have one function, label
  and statement index, so both threads are at one statement or neither. Its function passes
  `Labels.funcOk` (`Labels.FramesOk.funcOk`), so the statement passes `Labels.stmtOk`, whose (O1)
  makes the pointer operand of a `load`, `store` or `atomicrmw` skeleton; it evaluates to one value
  (`evalV_skel`). The access's thread, length and flags read only the context's `who` and layout,
  which the oracle does not change, and the statement. With `Mem.SkelEq.trace` this gives `race`.
  Its twin is a store through a constant `getelementptr` whose index is a payload register, which
  fails (O1): the two threads' accesses are at different offsets. The twin is an AST form only, not
  LLVM IR: a constant holds no register, and the parser refuses its text.

### Proof

`Grid.start_skel` (proved): the start's steps read the caller's memory in two places.
`Mem.checkClosed` reads `next`, which blocks exist, their sizes and pointer bytes, and those are
equal by `Mem.SkelEq` (`Mem.checkClosed_skel`). `launchArgs` checks each pointer argument's
`nonnull` and `align` attributes with `withAttrs`, which reads only the memory's shape (which
blocks exist, their spaces, sizes and addresses); `Mem.SkelEq` keeps the shape
(`Mem.SkelEq.sameShape`), so `withAttrs` gives one result on both memories (`withAttrs_shape`).
The other steps are `shared` and `launchArgs`' allocations, which allocate from `ch`, encode the
arguments and number blocks from `next`; those are equal on both sides (`Mem.allocNext_skel`,
`shared_skel`, `launchArgs_skel`). Its contexts differ only in `oracle`.

`Grid.skel_lockstep` (proved), by fields (with `Grid.FramesOk` at every reachable grid of the
first run, from the start's, by the premise on the kernel, and `Grid.AtCalls` there, by
`Grid.start_reach_atCalls`; every context's program is `prog`, `Grid.start_ctx`):
- `advance`: `Grid.advance_skel`, with `MemOk` at the first grid, which is reachable, and
  `Grid.FramesOk` there. A step's target is reachable, so `S` is kept (`Grid.Agree.imp`).
- `fire`: `Grid.fire_skel`.
- `done`: statuses have one constructor (`Grid.SkelRel.done`).
- `trace`: by `Mem.SkelEq.trace`.
- `race`: by `Thread.pending_skel` and `trace`.

`MemOk` is needed on the first run only. The addresses it speaks of are skeleton values, equal in
both runs, so the conditions hold at the second grid of each related pair.

### Obliviousness on terms (MojoProof/Sym/Payload.lean)

The checks above on a block summary's node table
(`Summary`, MojoProof/Sym/Checker.lean), for every labelling, function and summary; they are
`Bool`s the kernel evaluates.

- Roles (`roles lab fn ns`): node `j`'s role is `SNode.pay` on the roles of nodes `0..j-1`
  (`roles_getElem?`). An entry register is payload by its label, a constant never, a node by its
  role (`SVal.pay`). A node is payload if an operand is (a `select`'s condition among them); a
  `call`, `getelementptr` or `load` also if its statement's result register (`resReg`) is
  labelled payload (payload enters through loads); a float operation always ((O2): its NaN
  results read the oracle). Nodes of the other
  kinds carry no statement position, so their labels are not read: their roles come from their
  operands.
- `Summary.oblivious` is (O1) on terms: the exit condition, each effect's pointer, the
  operands of each `getelementptr` and `load` node, and the condition of each `select` node are
  payload-free.
- `Summary.agrees`: every register the summary sets whose entry is payload is labelled payload.
  It is an implication and not an equality: a register labelled payload may hold a skeleton
  value, as `Labels.Ok` allows. What T3c needs at the next block's entry is that a skeleton label
  means a skeleton value.
- `Summary.phiAgrees` and `Summary.agreesI`. An edge into a block
  with `phi`s also sets the target's `phi` results (`enter`, `Valuation.into`). These are in no
  summary's `regs`: the target's summary starts after them, and reads a `phi` result as an entry
  register, by its label. So `agrees` alone does not give the property at the next block's entry:
  a payload value can flow through a `phi` into a register labelled skeleton, and from there into a
  branch, with both blocks' checks passing (`phiFn`, `phi_payload_branch`).
  `phiAgrees lab fn lbl S d` checks each `phi` at the head of block `d` (`phisAt`, the list
  `enter` reads). If its operand for `lbl` mentions a register whose entry at the block's end is
  payload (`Summary.endPay`), the operand must be a register and its result register must be
  labelled payload (stated below).
  `agreesI lab fn lbl S` is `agrees` together with `phiAgrees` at each target of `S`'s exit.
  The property at the next block's entry rests on `agreesI`, by cases on a register `r`:
  - `r` is set by a `phi` of the edge: `phiAgrees` covers it, and `enter` sets it last;
  - otherwise, `r` is set by the block: `agrees` covers it;
  - otherwise, `r` keeps its value from the block's entry, whose label is the same register's
    label, so the property comes from the block before, by induction along the path.
  `Labels.Ok` refuses `phiFn` as well: the `phi` has a skeleton result and a payload
  operand, (O2) (`phi_payload_labels`). `agreesI` is the check on the summaries, which `Labels.Ok`
  does not read.
- `roles` is the fold `scanSnoc` at `SNode.pay`, and its lemmas are `scanSnoc`'s
  (`scanSnoc_length`, `scanSnoc_snoc`, `scanSnoc_getElem?`, for every function and list).
  `vals` (MojoProof/Sym/Term.lean) is the same fold at `SNode.eval`, unfolded, so
  `vals_length`, `vals_snoc` and `vals_getElem?` could become corollaries of these.

Instances (MojoProofTest/Payload.lean, one program): under `vaddLab ["25", "27", "28"]`, the roles
of `vector_addition`'s block `%21` are its two loads and the `fadd` (`vadd21_roles`), and the
summaries of its four blocks are oblivious and agree (`vadd_oblivious`). Twins (`vadd_twins`):
with the gep `%24` payload, `%21` agrees but is not oblivious (a load through a payload pointer);
with `%28` skeleton, or nothing payload, it does not agree.

The `phi` edges. The first is the naive matmul kernel's edge `%51 → %67`
(MojoProofTest/SymPhi.lean), into `%68 = phi float [%48, %51]`:
- with `%48` and `%68` payload, `agreesI` accepts it (`phi_agrees`);
- with `%68` skeleton, `agrees` and `oblivious` pass on both blocks and `agreesI` refuses the
  edge (`phi_twin`).

The second is a load fed to a `phi` whose result decides a branch, written as an AST (`phiFn`):
- with `%p` payload, `agreesI` refuses the edge and `Labels.Ok` refuses the program;
- with `%q` payload too, the edge agrees, and the branch block is not oblivious
  (`phi_payload_branch`).


**Two runs** (for every labelling `lab`, payload blocks
`pay`, table and pair of valuations).
- `Valuation.Skel lab pay V₁ V₂`: one program, environment, thread and function, memories related
  by `Mem.SkelEq pay`, and equal registers where `lab` labels skeleton. The step counts, the
  `fmul contract` operands, the globals, the address choices and the oracles are free: no
  skeleton node reads them (a float operation is payload, and `getelementptr` and `call` read
  only the program, the environment and the memory's shape).
- `Valuation.LoadsOk lab pay V ns`: under `V`, the pointer of each `load` node whose statement's
  result register is skeleton points outside `pay`, `Labels.MemAt` at a `load` on terms. When
  every `load` node has a payload result register it holds for every `pay`
  (`Valuation.loadsOk_of_pay`; `vector_addition`'s case).
- `vals_skel`: under valuations related by `Valuation.Skel` meeting `LoadsOk` under the first,
  every node whose role is skeleton has one value under both: the same fault or the same value.
  Proof: induction on the table by `vals_snoc` and `roles_snoc`. A skeleton node's operands are
  skeleton (`SNode.pay`), so they have one value (`SVal.eval_skel`: a skeleton register by
  `Valuation.Skel.regs`, a node by induction). `bin`, `cast` and `extract` are functions of
  their operands. `icmp`, `getelementptr` and `call` read the memory only through its shape
  (`icmpV_shape`, `gep_shape`, `withAttrs_shape`, with `Mem.SkelEq.sameShape` and
  `Val.namesIn_top`). A `load` reads one pointer, outside `pay` by `LoadsOk`, so `Mem.load_skel`
  gives one value. A float operation is never skeleton.
- `Summary.oblivious_skel`: an oblivious summary, under such valuations, exits to one block (or
  to none) under both, and each effect's pointer (`SEff.ptr`) has one value under both: its exit
  condition and pointers are payload-free, so `vals_skel` applies. The exit is `Exit.dest`, so
  this covers a branch into blocks with `phi`s (`Exit.phi`, whose condition `oblivious` reads),
  and not only `Exit.target`'s branches. Which `phi` assignments the edge makes,
  and whether they are skeleton where the labels say so, is the next block's entry relation
  (`agreesI`), below.

Instances (one program each, every pair of related valuations of its function and every `pay`):
nodes 0, 1, 2, 4 and 7 of `vector_addition`'s `%21` (the truncation, extension and three geps)
have one value (`vadd21_skel`), and, when the entry block's three loads of the byval arguments
read outside `pay` (a premise), each of the four blocks exits to one block and accesses one
address per effect (`vadd_skel`); the naive matmul kernel's `%51`, a `phi` exit into `%67`, and
`%67`'s store, under `phi_agrees`'s labelling (`naive_skel`).

### To the next block's entry (T3c on terms, MojoProof/Sym/Payload.lean)

For every labelling `lab`, payload blocks `pay`, summary `S` of
block `l` of a function, and pair of valuations.

**Definitions.**
- `Valuation.Rel lab pay V₁ V₂`: `Frame.Skel` and `Mem.SkelEq` on valuations. One program,
  environment, thread, globals and function; memories related by `Mem.SkelEq pay`; at every
  register, no value in both or values related by `Labels.Rel` at its label (equal where
  skeleton, `Val.Skel` where payload), and the same for the `fmul contract` operands. The step
  counts, the address choices and the oracles are free. It gives `Valuation.Skel`
  (`Valuation.Rel.skel`).
- (O3) on terms, `SNode.payOk lab fn ps nd`: a payload node's operation gives related results
  on related operands, as `Op.Total` above requires:
  - an integer `bin` has no flag and is not `sdiv` or `srem` (`BinOp.total`), and its second
    operand is skeleton when it is a shift amount or a divisor (`BinOp.skelB`);
  - a float operation has neither `nnan` nor `ninf`;
  - a `getelementptr` has skeleton operands (only its result label is payload);
  - a `load` has a skeleton pointer and loads a data type (`Ty.data`, read by `loadData` at the
    statement), so the bytes of a payload block decode to related values (`Mem.load_skel`);
  - a `select` has a skeleton condition (`selectV_skel` relates the results of one condition;
    `oblivious` requires it too);
  - `icmp`, the integer casts, `extractvalue`, `call` and the integer maxima and minima
    (`intMinMax_skel`) always.
  `Summary.payOk lab fn S`: every node of `S` whose role is payload passes, on the roles of the
  nodes before it (a skeleton node is not checked: `SNode.eval_skel` covers it).
- `Valuation.StoresOk lab pay V S`: under `V`, each `store` effect of `S` whose value operand is
  payload stores through a pointer into a block of `pay` (`Labels.MemAt` at a `store`, on terms).
- `Summary.endPay lab fn S r`: register `r`'s entry at the block's end (`SState.get`: its node, or
  the entry register `r`) is payload.
- `Summary.phiAgrees`: on the edge from `l` into `d`, each `phi` at the
  head of `d` whose operand `v` for `l` mentions a register with a payload entry at the block's
  end (`endPay`, itself or inside a constant expression) is a register `%r`, and its result is
  labelled payload. An operand that mentions none (a constant, a global, a register with a
  skeleton entry) passes whatever the result's label: it has one value in both runs. Counting
  every operand that is not a register or an integer as payload instead would refuse a float
  constant into a skeleton result and accept a constant expression on a payload register into a
  payload result, whose values in two runs need not be related (a `getelementptr` on a payload
  index gives two pointers).

**Statements.**
1. `vals_rel`: under valuations related by `Valuation.Rel`, meeting `LoadsOk` under the first,
   on a table whose nodes pass `payOk`, every node's value is related at its role: one fault, or
   equal values where the role is skeleton and values related by `Val.Skel` where it is payload.
2. `SEff.run_rel`: with values related as in (1), each effect's pointer with one value under both
   (`Summary.oblivious_skel`) and `StoresOk`, the effects give one fault or memories related by
   `Mem.SkelEq pay`.
3. `Valuation.after_rel`: from `oblivious`, `agrees`, `LoadsOk`, `payOk` and `StoresOk`,
   `(V₁.after S).Rel lab pay (V₂.after S)`.
4. `Valuation.into_rel`: with `agreesI lab V₁.fn l S` in place of `agrees`,
   `(V₁.into l S).Rel lab pay (V₂.into l S)`.

**Proof.**
1. Induction on the table (`vals_snoc`, `roles_snoc`), as `vals_skel`. A skeleton node:
   `SNode.eval_skel` (its operands are skeleton, so equal). A payload node: its operands are
   related at their roles (`SVal.eval_rel`: a register by `Valuation.Rel.regs`, a node by
   induction, a constant equal), so by `Val.Skel` (`Labels.Rel.to`), and by `payOk`:
   - `bin`: `lanes2_skel` with `intBin_skel` (the second operand is equal when `skelB`);
   - `icmp`: `icmpV_skel`; integer casts: `lanes_skel` with `intCast_skel`; `extractvalue`:
     `extractV_skel`;
   - float operations: `lanes2_skel` with `floatBin_skel` (any oracle numbers and `fmul contract`
     operands);
   - `call`, `getelementptr`: one value, as in `SNode.eval_skel`;
   - `load`: one pointer `q`; `Mem.load_skel` (with `Ty.data`) gives related values, so
     `Val.Skel.defined` gives one `noundef` check.
   A fault is the same fault on both sides: `Except.Rel` relates `.error e` only to `.error e`.
2. `Except.Rel.foldlM` from `Valuation.Rel.mem`. Each effect's pointer has one value, so one
   address `q`. A `load` effect records one event (`Mem.log_skel`). A `store` writes values
   related at the value operand's role: equal if skeleton; if payload, related by `Val.Skel`,
   and `StoresOk` puts `q` in `pay`; so `Mem.store_skel` applies.
3. Field by field. Context and function: `after` keeps `V`'s. Memory: (2), or `V`'s memories when
   the effects fault in both. Register `r` (`regVal`): if the block sets it, its entry `x` has
   values related at `x`'s role (1), and `agrees` gives a payload label when that role is payload
   (`Labels.Rel.mono`); if not, `V`'s registers. `fmul contract` operands (`regProd`): none for a
   register the block sets, `V`'s otherwise.
4. `into` is `after` except for an exit into blocks with `phi`s (`Exit.phi`) whose condition
   selects a target `d`, and `oblivious_skel` gives one `d` under both. There `enter` runs from
   the frames `Valuation.frameAt`, related by `Frame.Skel` by (3), and evaluates each `phi`'s
   operand for `l` in each run's scope (one layout and globals by `Valuation.Rel`). An operand
   that mentions no `endPay` register has one value (`evalV_skel`): a register with a skeleton
   entry at the block's end has one value there, by (1) if the block sets it and by
   `Valuation.Rel.regs` if not. Otherwise `phiAgrees` gives a register with a payload result, and
   its values are related by `Val.Skel` (`evalV_pay`). `Frame.Skel.setAll` and
   `Frame.Skel.goto` give related frames (`enter_rel`), so related registers and operands
   (`enter_fields`: the function is kept). A fault of `enter` is one fault in both runs, and
   `into` is then `after`.

Lean (MojoProof/Sym/Payload.lean, for every labelling, payload blocks, summary and pair of
valuations): `SVal.eval_rel`, `SNode.eval_rel`, `vals_rel`, `SEff.run_rel`,
`Valuation.after_regs`, `Valuation.after_rel`, `enter_rel` and `Valuation.into_rel`, as above.
`LoadsOk` and `StoresOk` are premises: they are `Labels.MemAt` on terms, and discharging them from
`Labels.Ok` and the run's memory invariant is the composition's work.

Instances (MojoProofTest/Payload.lean, one program each, every pair of valuations related by
`Valuation.Rel` and every `pay`):
- `vadd21_into`: `vector_addition`'s block `%21` under `vaddLab ["25", "27", "28"]`, given
  `StoresOk` (its store of the sum `%28` writes to `pay`), relates the valuations at the next
  block's entry;
- `naive_into`: the naive matmul kernel's `%51` under `labIn SymPhi.naive.fn_0 ["48", "68"]`
  relates the valuations at `%67`'s entry, after the `phi` `%68` (no store, so `StoresOk` holds).

Twins: `vadd21_payOk` (block `%21` passes `payOk`; with its `fadd` marked `nnan` it does not) and
`phi_operand_twin` (`phiFn` with `%p` and `%q` payload agrees on its edge; with
the `phi` operand `splat (i32 %p)`, a constant expression on a payload register, it does not).

### Along a path, and two runs of a returning path (MojoProof/Sym/Payload.lean)

For every labelling `lab`, payload blocks `pay`, function `fn` and path `(l, ds, S) :: ps` (the
block checker's `coversPathI` and `WalkI`, whose blocks after the first are entered through
`Valuation.into`).

**Definitions.**
- `pathOk lab fn l S ps`: every summary of the path is oblivious, agrees with `lab` on its exit's
  edges (`agreesI` at its own label) and passes `payOk`. A `Bool` on summaries only.
- `Valuation.PathMem lab pay V l S ps`: `LoadsOk` and `StoresOk` of each block at its entry
  valuation in the run from `V` (`Valuation.into` of the block before).
- `Cond.effsIn S d`: obligation `d` runs only effects of summary `S` (a `Cond.mem es` each of
  whose effects is one of `S.effs`; `true` for `Cond.ok` and `Cond.bool`). A `Bool`. The
  obligations `summarize` makes pass it (their one `Cond.mem` runs `S.effs`); `covers` lets a
  path's lists hold more conditions than `S.obls`, so it is checked, by the kernel, per path.

**Statements.**
1. `Valuation.lastI_rel`: if `V₁.Rel lab pay V₂`, `V₁.fn = fn`, `pathOk` and `V₁.PathMem` hold,
   then the entry valuations of the last block (`Valuation.lastI`) are related, the last block's
   label and summary are one under both, and the valuations after the last block
   (`Valuation.after`) are related.
2. `Block.sound_retI_rel`: for two contexts of one program and two threads of one frame each at
   block `l`'s position `p0`, whose frames have one list of `allocas` (premise `ha`), if
   `coversPathI` accepts the path, `pathOk` holds, each obligation of the path passes
   `Cond.effsIn` at its block's summary (premise `hd`), the first entry valuation meets `WalkI`,
   the last block returns, the entry valuations are related and the first meets `PathMem`, then both
   threads run the path and their next steps return (`.done`), and the two returned memories
   (the memories at the last block's end with each frame's `allocas` made dead) are related by
   `Mem.SkelEq pay`.
3. `Cond.holds_rel`: for valuations related by `Valuation.Rel` and a summary `S` that is
   oblivious, passes `payOk` and meets `LoadsOk` and `StoresOk` under the first, every obligation
   `d` with `Cond.effsIn S d` that holds under the first on `S`'s node values holds under the
   second.
4. `WalkI.rel`: if `V₁.Rel lab pay V₂`, `V₁.fn = fn`, `pathOk` holds, every obligation of the
   path passes `Cond.effsIn` at its block's summary, and `V₁.PathMem` holds, then `WalkI` from
   `V₁` gives `WalkI` from `V₂`.

**Proof.**
1. Induction on `ps`. A one-block path: `pathOk` gives `oblivious`, `agreesI` (so `agrees`, its
   first conjunct) and `payOk` at `fn = V₁.fn`, and `PathMem` gives `LoadsOk` and `StoresOk`, so
   `Valuation.after_rel`. A longer path: `Valuation.into_rel` relates the next block's entry
   valuations, which keep the function (`Valuation.into_k`), and the induction hypothesis applies
   to the rest. `lastI`'s label and summary are the path's last, so they do not depend on the
   valuation.
2. `Block.sound_retR` for each thread (the second's program and function are the first's by
   `Valuation.Rel`, and its last block is the first's by (1)): each run's steps reach the last
   block's end on the memory `me` that its effects make from its entry valuation (`SEff.run`),
   and the next step returns. That memory is `Valuation.after`'s, so (1) relates the two. The
   return sets each block of the frame's `allocas` dead in turn (`List.foldl` of
   `Mem.setLive b false`); with one list in both frames (`ha`), `Mem.foldl_setLive_skel`
   (MojoProof/Sem/Skeleton.lean; induction on the list, `Mem.setLive_skel` at each block)
   relates the returned memories. The second run's `WalkI` is (4)'s.
3. `vals_rel` relates the node values. `Cond.ok x`: `SVal.eval_rel` relates `x`'s results
   (`Except.Rel`: one fault or two values), so an `ok` under the first is an `ok` under the
   second. `Cond.bool x`: the two values are related by `Val.Skel` at least (`Labels.Rel.to`),
   which keeps a scalar's width (`Val.Skel.scalar`); a word under the first is a word under the
   second, as `poison` and `undef` are not defined (`Val.Skel.defined`). `Cond.mem es`: each
   effect is one of `S.effs` (`Cond.effsIn`), whose pointers are one under both
   (`Summary.oblivious_skel`) and whose payload stores write to `pay` (`StoresOk`), so
   `SEff.run_rel` gives one fault or related memories.
4. Induction on the path. Each block's obligations by (3) at its entry valuations; each exit's
   destination is one under both (`Summary.oblivious_skel`'s first conjunct); the next block's
   entry valuations are related by `Valuation.into_rel` and keep the function
   (`Valuation.into_k`).

Why `hd`: `covers` asks only that `S.obls` be a prefix of the block's list, so a path may carry
a `Cond.mem` of effects that are not the block's, whose pointers `oblivious` does not check.

Why `ha`: `Valuation.entry` does not read a frame's `allocas`, so `Valuation.Rel`, `WalkI` and
`PathMem` say nothing about them, and frames that differ only in `allocas` return different
memories. Twin (MojoProofTest/Payload.lean's `allocas_twin`, for every context, step count,
frame, labelling and `pay`): the frames with `allocas` `[]` and `[1]` have related entry
valuations on a memory whose block 1 is live, and the returned memories are not related (block 1
is live in one and dead in the other).

`Valuation.storesOk_of_skel`: when no `store` effect has a payload value operand, `StoresOk`
holds under every valuation (as `Valuation.loadsOk_of_pay` for `LoadsOk`).

Loads and stores through registers (for every labelling, `pay`, valuation, table or summary and
list of registers `rs`):
- `SVal.baseIn ns rs p` (a `Bool`): `p` is a register of `rs` or a node of `ns` that is a
  `getelementptr` on one.
- `SVal.eval_baseIn`: if the values of `rs` under `V` name only blocks of a set `B`
  (`Val.NamesIn`) and `SVal.baseIn ns rs p`, a pointer value of `p` on `ns`'s node values points
  to a block of `B`. Proof: a register's value is its own; a `getelementptr` keeps its base's
  block (`gep_namesIn`, MojoProof/Sem/Schedule.lean).
- `Valuation.loadsOk_of_regs`: if the values of `rs` name no block of `pay` and each `load`
  node with a skeleton result has its pointer's base in `rs` (on the nodes before it),
  `LoadsOk` holds.
- `Valuation.storesOk_of_regs`: if the values of `rs` name only blocks of `pay` and each `store`
  effect of a payload value has its pointer's base in `rs`, `StoresOk` holds.
These discharge `LoadsOk` and `StoresOk` from facts about the entry registers, which a caller
gets from the launch's start facts; the `Bool`s are decided by the kernel.

Instance (MojoProofTest/Payload.lean, one program, every two contexts, threads and memories, and
every `pay`): `vadd_runs`, `vector_addition`'s path `%4 → %21 → %31` under
`vaddLab ["25", "27", "28"]`, for frames with one list of `allocas`, the first thread's `WalkI`
and every `p0`, `p1`, `p2`, `out` and struct tail `tl`. Its premises are start facts of the first
run: the first frame's registers `%0` to `%2` point to offset 0 of `p0` to `p2`, outside `pay`,
and the struct load `%5` through `%2` reads a struct whose first field points to offset 0 of
`out`, in `pay` (the start facts of `Kernel.sound_map2`, MojoProof/Sym/Kernel.lean, give these with
`pay` the one block `out`). From them, `Valuation.loadsOk_of_regs` (registers `%0` to `%2`) gives `%4`'s `LoadsOk`
and `Valuation.storesOk_of_regs` (register `%6`, which is `out`'s pointer at `%21`'s entry by
`vadd4_reg6`) gives `%21`'s `StoresOk`; the second thread's `WalkI` is `WalkI.rel`'s. The kernel
decides the rest (`coversPathI`, `pathOk`, `Cond.effsIn`, the pointer bases, `loadsOk_of_pay`
for `%21` and `%31`, `storesOk_of_skel` for `%4` and `%31`). Twin: `vadd_pathOk`, where
`pathOk` passes under that labelling and fails with `%28` skeleton.

Not proved:
- the discharge of `LoadsOk` and `StoresOk` from `Labels.MemOk` (the grid-level memory
  conditions on statements): it needs, at each `load` and `store` that `Block.sound` runs, the
  statement's pointer to be the term's, which `SState.run_sound` (MojoProof/Sym/Block.lean)
  proves but does not state;
- two runs of a grid (every thread and its interleaving, `Grid.SkelRel`).

## T3c: partial payload operations (after T4)

The partial operations are:
- `rsqrt.approx` under `nnan` or `ninf` (without them it is in `Op.Total`, `rsqrt_skel`).
  Its contract `rsqrtOk` (Float.lean) admits PTX's results
  for the special inputs: a NaN or negative operand gives a NaN, a zero or subnormal one gives an
  infinity of its sign, `+∞` gives `+0`. `rsqrt` returns the oracle's word if it meets the
  contract and else its fallback, FloatLib's `Model.rSqrt` of the operand with subnormals
  flushed, which meets `rsqrtOk` on every binary32 operand (`rsqrtOk_rSqrt`), so every value
  meets it (`rsqrtOk_of_rsqrt`). Under `nnan` or `ninf` whether it gives `poison` depends on the
  operand, and T3c takes the domain hypothesis;
- `udiv` and `urem` by a payload divisor, and `sdiv` and `srem` with a payload operand;
- `nsw`, `nuw`, `exact` and `disjoint` on payload, and shifts by a payload amount;
- `nnan` and `ninf` on payload float operations and calls;
- `fptosi` and `fptoui` on payload;
- `range` on a payload parameter or result.

Each is to be admitted in (O3) if the block summary gives its operand terms, and if the hypothesis
`Φ₁ ∧ Φ₂` says that the terms, evaluated on each run's payload and oracle, lie in the operation's
domain. `Op.total_skel` for such an operation then holds on the operands that occur. Φ is
proved once for every payload from bounds on the term (for example, that a payload divisor is
nonzero, or FloatLib's bounds on a float term). Not started: it needs T4's terms.

## T4: the output term (with the block summaries)

T4 has no Lean statement. This section fixes its definitions, its statement and a proof route.

Definitions (an `alloca`'s address is a skeleton choice, `Ctx.addr`; the oracle holds only float
freedoms):
- `Atom`: `arg i`, `sreg r d`, `laneid` and `addr` (skeleton); `cell b i` (the byte `i` of payload
  block `b` at the start, or the word at offset `i`: which of the two is not fixed); `orc n k i`
  (thread `n`'s payload choice at step `k`, index `i`).
- `SVal`: an atom, a constant `Val`, or an operation of `Op.Total` (the partial ones are left out)
  applied to `SVal`s at an oracle position.
- `SVal.eval (env : Atom → Val) : SVal → Except Fault Val` applies the semantics' own operation
  functions (`floatBin`, `lanes2`, `castV`, ...), so the term is computed by the semantics and is
  not a model of it.
- `Summary.out : Launch → List Val → Nat → Nat → SVal` gives the term of each output word.

**Statement.** Let `Σ` be a block summary (MojoProof/Sym) of `prog`'s kernel `fn`, sound for `L`, `args` and `ch`.
For every caller memory `m` with `Mem.SkelEq pay m₀ m` and every oracle `ω`, every grid reachable
from the start on `(m, ω)` in which every thread has returned holds, at each output word, the
bytes of `(Σ.out L args b i).eval (env m ω)`. Here `env m ω` reads `cell` atoms from `m`, `orc`
atoms from `ω`, and skeleton atoms from the launch.

**Proof route.** The invariant along a run is `TermRel`:
- every payload register equals the evaluation of its term in the block checker's symbolic state
  at the same instruction;
- every byte of a `pay` block equals the byte of its term's evaluation.

The step: each step keeps `TermRel` with the symbolic step. It is not proved; it would extend
`Block.sound` (MojoProof/Sym/Block.lean). With it, the done grid of one run holds `out`'s
evaluation, and schedule independence (`Grid.start_sound`, docs/proofs/schedule.md) gives every
done grid.

### The term block `%21` of `vector_addition` stores (3c; one program, MojoProofTest/Payload.lean)

This fixes, on the summary `Kernels.vadd.b1` that `mojo_kernel` generates
(MojoProof/Kernels/Vadd.lean), the term of the value the block stores, and the step whose oracle
numbers its `fadd` reads. It is a check on one summary, not T4.

**Definition.** `cellOk ra rb ro s S` (a Bool function in the test) holds when:
- `S`'s effects are `[load _ _ (node pa), load _ _ (node pb), store _ _ (node j) (node po)]`;
- node `j` is `fbin fadd fm float s (node a) (node b)` for some flags `fm`;
- nodes `a` and `b` are loads through `node pa` and `node pb`;
- nodes `pa`, `pb` and `po` are `gep`s on the entry registers `ra`, `rb` and `ro` at one index `i`
  (the second operand of the store's `gep`).

**Statement.** `cellOk (local? "10") (local? "8") (local? "6") 6 Kernels.vadd.b1 = true`. The block stores,
through the `gep` of the output `%6` at an index `i`, the `fadd` at step 6 after the block entry of
the loads through the `gep`s of the inputs `%10` (`a`) and `%8` (`b`) at the same `i`. So, by
`SNode.eval`, under every valuation `V` the stored value is `lanes2` of `floatBin float fadd fm` on
the two loaded values, with oracle number `Nat.pair (V.k + 6) 0` for its one lane.

**Proof.** `decide +kernel` on the summary.

**Twins.** The check fails:
- with the inputs swapped (`%8` read first);
- with the output register replaced by `%10`;
- at step 5;
- on the entry block's summary `Kernels.vadd.b0`, which has no store.

**The value statement** (`vadd21_store`, `vadd21_store_sound`). `SumStored V me` (a `Prop` in
the test) says, for a valuation `V` and a memory `me`, that:
- register `%19` holds `r`, and the `sext` to 64 bits of the `trunc` to 32 of `r` is `i` (`%23`);
- `%10`, `%8` and `%6` hold `pa`, `pb` and `po`, and the `getelementptr inbounds float` of each at
  index `i` is a pointer: `qa`, `qb` and `qo`;
- the float loads (address space 0, alignment 4) from `V`'s memory at `qa` and `qb` give `xa` and
  `xb`, cells `i` of the inputs;
- `lanes2` of `floatBin float fadd {contract}` with oracle number `Nat.pair (V.k + 6) j` for lane
  `j` gives `x` on `xa` and `xb`;
- `me` is the store of `x` at `qo` on `V`'s memory with the two loads' trace entries (so `qo`
  holds the bytes of `x`), and when `x` is a float, the float load at `qo` from `me` gives `x`.

For every valuation of `vector_addition`'s function in a context of its program, every memory
that `Kernels.vadd.b1`'s effects make from it satisfies `SumStored` (`vadd21_store`). With `vadd21_sound`
(`Block.sound`): for every context of the program and thread whose innermost frame is at `%21`'s
entry and whose obligations hold, the steps reach the block's end with such a memory, at the
entry valuation (`vadd21_store_sound`).

**Proof.** The summary's table and effects, and the six statements they name, are the program's
by `rfl`; `SEff.run`, `vals` and `SNode.eval` unfold, and each bind that succeeds gives a value
(`Except.bind_eq_ok`). The load back is `Mem.load_store_codec` with `Layout.Codec.float`.

**Instance and twin** (`vadd21_store_twin`). The premises hold on MojoProofTest/SymRun.lean's run
at index 2 (`vadd21_hds`). For every valuation `V`, `SumStored V V.mem` fails: the memory the
block makes has three more trace entries.

**Not proved.**
- Whether `x` is a float: it is unless an input cell is poison (an undefined cell faults).
- T4 for every program.

## T5: relations on payload, for every relation

Let `R : Val → Val → Prop`, and let `C` couple two oracles: for example, equal choices, or any
choices for an operation whose result `R` relates for every choice. Let `o.Respects R C` say:
`R`-related argument lists give `R`-related results, or both fault, under `C`-coupled oracle
numbers.

**Statement** (`SVal.eval_respects`, not stated in Lean; `SVal.eval_rel` is T3c's Lean theorem on
the skeleton relation, another statement). For every term `t` whose operations all
respect `R` under `C`, every two environments with `R (env₁ a) (env₂ a)` for every atom `a` of
`t`, every two oracles coupled by `C`, and `R v v` for every constant `v` of `t`: `t.eval env₁`
and `t.eval env₂` both fault or give `R`-related values.

The premises are on the atoms and constants of `t`, not on reflexivity of `R`, because `R` is
arbitrary: for `R x y := x ≠ y` and a constant term, the two evaluations
are one value, which `R` does not relate. A skeleton atom has one value in both runs, so its
premise is `R v v` at that value; for the relations of the rows below this holds on defined
values.

**Proof.** Induction on `t`:
- an atom or a constant: by the premise;
- an operation: the induction hypothesis on the arguments gives `List.Forall₂ R`, and `Respects`
  finishes. Faults propagate on both sides.

The instances are one lemma per row, one relation each: `FinEq`, NaN equivalence, the error
relation with its validity flag, and the `rsqrt` relation. These are float results about the
semantics' operations; results about floats alone belong in FloatLib. Not every row is a `Respects` lemma on its
relation: the coupled `maxnum` / `minnum` row (`maxnum_nanEq`, `fminmax_nanEq`,
`fminmax_vec_nanEq`) relates **identical operands** under two oracle numbers of one parity, so its
input relation is equality, and it does not compose with `NaNEq` on the operands. No parity
coupling can make it: with
`q = 0x7fc00000` (a quiet NaN), `s = 0x7fa00000` (a signaling NaN), `NaNEq q s`, second operand
`1` and `n = n' = 1`, `maxnum true q 1 1 = 1` and `maxnum true s 1 1` is a NaN, which are not
`NaNEq` (`mx 1` and `maxnum_inst` in MojoProofTest/FloatRel.lean; LangRef's quiet and signaling
NaN rules for `llvm.maxnum`). A term with a `maxnum` node that a NaN can reach therefore gets
`NaNEq` at that node only when its operands are equal words in both runs, which `SVal.eval_respects`
must take as the node's premise.

### T5's rows, one operation at a time (MojoProof/Sem/FloatRel.lean)

These are the rows that are proved, for one operation each (on scalars or on words), not for
terms: `SVal.eval_respects` is not stated here.

**Definitions.**
- `FinEq x y` on `Model fmt`: `x = y`, or neither is finite.
- `NaNEq x y`: `x = y`, or both are NaNs.
- `Est` with fields `value : ℝ`, `bound : ℝ`, `valid : Bool`, and `e.Holds w`:
  `e.valid = true → w.isFinite = true ∧ |w.toReal - e.value| ≤ e.bound` (the flag carries the
  range hypothesis).
- `Est.contract sub a b pa pb`, the estimate of a contracted `fadd` (`fsub` if `sub`) of `a` and `b`
  with factors `pa`, `pb`. With `s = ±1` and `M` the largest finite value
  (`(posMaxFinite fmt).toReal`): value `exact a pa + s · exact b pb`; bound `contract_error`'s,
  the maximum over the three choices (unfused, fused with `a`'s factors, fused with `b`'s) of their
  factors' rounding errors plus half an ULP at the choice's exact result; valid iff `a` and `b`
  are finite and each choice's exact result, `a + s·b`, `exact a pa + s·b` and `a + s·exact b pb`,
  has magnitude at most `M`.
- `RsqrtClose a w` on binary32: `w` is finite and `|w.toReal - 1 / √a| ≤ rsqrtErr / √a`. Two runs'
  results of `rsqrt` are related when both are `RsqrtClose` at the operand's value.
- `Val.Lift t R v v'`: `v = v'`, or `v = .ofFloat t a`, `v' = .ofFloat t a'` and `R a a'`.
- `Respects R S C o` for `o : List Val → Nat → Except Fault Val`: for every operand lists related
  elementwise by `R` (`List.Forall₂`) and oracle numbers `n`, `n'` with `C n n'`, `o xs n` and
  `o ys n'` are related by `Except.Rel S` (the same fault, or values related by `S`).
- `floatOp t op fm`: `floatBin t op fm x y none none n` on `[x, y]`, a fault on other lists: the
  operation with no recorded factor.

**Row 1** (`floatOp_finEq`). For every float type `t`, `op ∈ {fadd, fsub, fmul}` and flags `fm`
with `nnan = false` and `ninf = false`:
`Respects (Val.Lift t FinEq) (Val.Lift t FinEq) (fun _ _ => True) (floatOp t op fm)`.

Proof.
1. `FinEq.deliver`: if `FinEq r r'` then `FinEq (deliver r n) (deliver r' n')` for every `n`, `n'`.
   If `r = r'` is a NaN, both deliveries are NaNs (`isNaN_deliver`), so neither is finite
   (`Model.isFinite_eq_false_of_isNaN`); if it is not a NaN, both are `r`
   (`deliver_of_isNaN_eq_false`). If neither is finite, a delivery is a NaN or `r` itself, so it
   is not finite.
2. `FinEq.op`: for `f` whose finite results have finite operands, `FinEq x x'` and `FinEq y y'` give
   `FinEq (f x y) (f x' y')`. If both pairs are equal, the results are. Otherwise one of `x, x'`
   (say) is not finite on both sides, so neither result is finite. FloatLib gives the premise for
   `add`, `sub` and `mul` on IEEE formats (`Model.isFinite_of_isFinite_add`, `_sub`, `_mul`), and every
   `FloatTy.fmt` is IEEE (`isIEEE_fmt`, by cases).
3. `floatBin_ofFloat`: on two float scalars of type `t`, with flags that pass `FastMath.check` and
   have no `nnan` or `ninf`, and no factors, `floatBin` is `.ok (.ofFloat t (deliver (f a b) (n / 3)))`
   with `fbin op = some f`, for `fadd`, `fsub`, `fmul` and `fdiv`: `contract sub a b none none n` is
   the unfused operation for every `n` (no arm of its match fires without a factor), and
   `withFlags` returns its argument when no flag poisons.
4. The row. If `fm` fails `FastMath.check`, both sides are that fault. Otherwise take the operand
   lists: of length other than 2 on both sides, both are the same fault. For `[x, y]` and
   `[x', y']`: write each pair as equal scalars that are not floats of type `t`, or as floats
   (an equal pair that is a float of type `t` is a float pair with `FinEq a a`). If either pair is
   not floats of type `t`, its scalar is the same on both sides, and `floatBin`'s result does not
   depend on the other operand's float or on the oracle number (`floatBin_left`,
   `floatBin_right`): undef faults, poison gives poison, and any other scalar faults as the wrong
   type. If both are floats, step 3 and steps 1-2 give `Val.Lift t FinEq`.

**Row `rsqrt.approx`** (`rsqrt_close`). For every positive binary32 `x` that is finite, not zero
and not subnormal, and every `n`: `RsqrtClose x.toReal (rsqrt x n)`.

Proof. Let `w := rsqrt x n`; `rsqrtOk x w` (`rsqrtOk_of_rsqrt`). Its arms for a NaN, a zero or
subnormal, a negative and an infinite `x` do not fire, so `x.toRat? = some a` and
`w.toRat? = some b` with `rsqrtNear a b`. Then
`w` is finite (`Model.Algebraic.toRat?_isSome_eq_isFinite`), `a = x.toReal` and `b = w.toReal`
(`Model.Algebraic.toReal_of_toRat?_eq_some`), `0 < a` since `x` is not negative and not zero
(`Model.toReal_nonneg_of_signBit_eq_false`, `Model.isZero_eq_true_iff_toReal_eq_zero`), and
`rsqrtNear_iff` gives the bound. So for every two oracle numbers the two results are both
`RsqrtClose` at `x.toReal`: a free coupling. They need not be equal: `rsqrt 1` is the word of 1 or
of `1 + 2 ^ -23`.

**Row `maxnum` / `minnum`, free** (`maxnum_of_not_nan`). For every format, `max` flag, words `x`,
`y` with no signaling NaN (`(x.isSignaling || y.isSignaling) = false`) and not both NaNs, and every `n`:
`maxnum max x y n = if max then maximumNumber x y else minimumNumber x y`. So two runs give equal
words under any two oracle numbers; the condition "neither operand is a NaN" is a special case.

Proof. The first arm of `maxnum` needs a signaling NaN operand, so `maxnum max x y n` is
`deliver r (n / 2)` with `r` FloatLib's `maximumNumber x y` or `minimumNumber x y`. `r` is not a NaN
when not both operands are (`Model.isNaN_maximumNumber_eq_false_of_not_both`, `_minimumNumber_`),
so `deliver` returns it (`deliver_of_isNaN_eq_false`).

**Row `maxnum` / `minnum`, coupled** (`maxnum_nanEq`). For every format, `max`, `x`, `y` and oracle
numbers `n`, `n'` with `n % 2 = n' % 2`: `NaNEq (maxnum max x y n) (maxnum max x y n')`. The two
runs have the same operands `x`, `y`: the input relation is equality, not `NaNEq` (see the
counterexample after T5's statement).

Proof. `NaNEq.deliver`: `NaNEq r r'` gives `NaNEq (deliver r n) (deliver r' n')` for every `n`, `n'`
(as in `FinEq.deliver`: a NaN is delivered as a NaN, `isNaN_deliver`, and a word that is not a NaN
as itself). With `n % 2 = n' % 2` both sides take the same arm of `maxnum`: `deliver` of the
canonical NaN, or `deliver` of one word `r`, at `n / 2` and `n' / 2`; `NaNEq.deliver` with `r = r`
closes both. The results need not be equal: `deliver` picks the NaN by `n / 2`.

**Rows `maxnum` / `minnum` at the intrinsic, on scalars** (`intrinsic_fminmax_ofFloat`,
`fminmax_of_not_nan`, `fminmax_nanEq`). For every `max`, type `t` whose element type is the float
type `ft`, words `a`, `b` of `ft`, context `c`, scope `s` and flags `fm`, the call of `llvm.maxnum`
(`max`) or `llvm.minnum` on the scalars `.ofFloat ft a` and `.ofFloat ft b`, as `intrinsic`
evaluates it, returns the scalar of `maxnum max a b (s.ch 0)`, or `poison` if `withFlags fm` makes
it poison, and leaves `s.mem` (`intrinsic_fminmax_ofFloat`). So, free (`fminmax_of_not_nan`): with
no signaling NaN operand and not both NaNs the result is that of `maximumNumber a b` or
`minimumNumber a b`, with no oracle number; and coupled (`fminmax_nanEq`): with flags without
`nnan` and `ninf`, two scopes whose oracle numbers 0 have one parity give results related by
`Val.Lift ft NaNEq`, each leaving its scope's memory.

Proof. `lanes2` on two scalars applies its function at lane 0, and `floats2` reads `a` and `b`
back (`Val.float?_ofFloat`), so the call returns `withFlags fm [a, b] (maxnum max a b (s.ch 0))`
as a scalar, or poison. The free row rewrites `maxnum` by `maxnum_of_not_nan`; the coupled row
removes the flags by `withFlags_some` and relates the words by `maxnum_nanEq`. Instances and twins:
`fminmax_inst` and `fminmax_twin` in MojoProofTest/FloatRel.lean; the twins of the flag premises
are `maxnum_skel`'s.

**Rows `maxnum` / `minnum` at the intrinsic, on vectors** (`intrinsic_fminmax_vec`,
`fminmax_vec_of_not_nan`, `fminmax_vec_nanEq`). For every `max`, type `t` whose element type is the
float type `ft`, lists of words `as`, `bs` of `ft` of one length, context `c`, scope `s` and flags
`fm`, the call on the vectors `.vec (as.map (.ofFloat ft))` and `.vec (bs.map (.ofFloat ft))`
returns the vector whose lane `j`, of the words `a`, `b`, is the scalar of
`maxnum max a b (s.ch j)`, or `poison` if `withFlags fm` makes it poison, and leaves `s.mem`
(`intrinsic_fminmax_vec`). So, free (`fminmax_vec_of_not_nan`): if no lane has a signaling NaN
operand or two NaN operands, lane `j` is the scalar of `maximumNumber a b` or `minimumNumber a b`
(or poison), with no oracle number; and coupled lane by lane (`fminmax_vec_nanEq`): with flags
without `nnan` and `ninf`, two scopes `s`, `s'` with `s.ch j % 2 = s'.ch j % 2` for every lane
`j < as.length` give vectors `xs`, `ys` with `List.Forall₂ (Val.Lift ft NaNEq) xs ys`, each
leaving its scope's memory. The parity of oracle number 0 alone (the scalar row's premise) does
not suffice: lane 1 reads `s.ch 1`.

Proof. `lanes2` on two vectors of one length maps its function over the zipped lanes with their
indices (`List.zipIdx`), in `Except`; the lists of scalars are maps of the word lists, so the
zip of the maps is the map of the zip (`List.zip_map`, `List.zipIdx_map`, `List.mapM_map`), and
`floats2` reads each lane's words back (`Val.float?_ofFloat`), so each lane's function returns
`pure` of its scalar (`mapM_congr`), and `List.mapM_pure` gives the vector. The free row rewrites
`maxnum` lane by lane by `maxnum_of_not_nan` (a lane `((a, b), j)` of the indexed zip has
`(a, b)` in the zip, `List.fst_mem_of_mem_zipIdx`; the indices dropped, `List.zipIdx_map_fst`).
The coupled row writes both vectors as maps of one indexed list (`List.forall₂_map_left_iff`,
`List.forall₂_map_right_iff`, `List.forall₂_same`); a lane `((a, b), j)` has `j < as.length`
(`List.mem_zipIdx`), so its oracle numbers have one parity, and `withFlags_some` and
`maxnum_nanEq` relate the lane's scalars. Instances and twins: `fminmax_vec_inst`,
`fminmax_vec_coupled` and `fminmax_vec_twin` in MojoProofTest/FloatRel.lean.

**Row: the error relation, one operation** (`contract_est`, `floatBin_contract_est`). For every
IEEE format, `sub`, words `a`, `b` with `IsProd a pa` and `IsProd b pb`
(each operand is a rounded product of its factors, if it has them) and every oracle number `n`:
`(Est.contract sub a b pa pb).Holds (contract sub a b pa pb n)` (`contract_est`). For every float
type `t`, `op ∈ {fadd, fsub}`, flags with `contract` and every `n`, if `floatBin t op fm` on the
scalars of `a` and `b`, with the scalars of the factors, gives the scalar of `r`, then
`(Est.contract (op == fsub) a b pa pb).Holds r` (`floatBin_contract_est`). Free: no condition on the
oracle numbers, so two runs' results are both within the bound of the same value.

Proof.
1. Finiteness. Assume the estimate is valid. `contract_cases` gives three cases. Unfused: `add a b`
   or `sub a b` of finite operands whose exact result has magnitude at most `M` is finite
   (FloatLib's `Model.isFinite_add_of_abs_toReal_add_le_posMaxFinite`, `_sub_`). Fused with `a`'s
   factors `(u, v)`: `a` is finite, so `mul u v` is (`IsProd`), so `u` and `v` are
   (`Model.isFinite_of_isFinite_mul`; `IsProd.factors_finite`); `±b` is finite, and
   `|u v ± b| = |exact a pa + s·b| ≤ M` (with `toReal (neg b) = -toReal b` for finite `b`), so
   `fma u v (±b)` is finite (`Model.isFinite_fma_of_abs_toReal_fma_le_posMaxFinite`). Fused with
   `b`'s factors `(c, d)`: the same, `fma (±c) d a` with `|±c d + a| = |a + s·exact b pb| ≤ M`.
2. The bound: `contract_error`, whose premise is the finiteness of 1.
3. At `floatBin` (`holds_withFlags`). A valid estimate that holds of the IEEE result `c` makes `c`
   finite, so not a NaN, so `deliver c k = c`; `withFlags` returns its argument or nothing, so a
   value `r` it returns is `c`. `floatBin` with `contract` (flags without `nsz`, `reassoc`, `arcp`,
   `afn`; with them it faults) on the scalars of `a`, `b` and their factors computes
   `withFlags fm [a, b] (deliver (contract (op == fsub) a b pa pb n) (n / 3))`, and reads `r` back
   from its scalar (`Model.ofBits_toBits`), as in `floatBin_contract`; 1-2 and this step close it.

The validity flag is a condition on the operands' values, not on the result word; it is decidable
on rationals but `Est.contract` takes it on reals (`decide` on `ℝ`, so noncomputable), since the
operands' estimates along a term are real intervals.

**Row: NaN** (`fbin_isNaN`, `floatOp_isNaN`). For every IEEE format,
operator `op` with an IEEE 754 operation (`fadd`, `fsub`, `fmul`, `fdiv`; `fbin op = some f`) and
words `x`, `y` one of which is a NaN, `f x y` is a NaN (`fbin_isNaN`). For every float type `t`,
operator other than `frem`, flags without `nsz`, `reassoc`, `arcp`, `afn` (with them `floatBin`
faults), `nnan` and `ninf` (`contract` is allowed), words `a`, `b` one of which is a NaN and every
oracle number `k`, `floatOp t op fm` on their scalars gives the scalar of a NaN
(`floatOp_isNaN`).

Proof. FloatLib's `Proof.add_eq_spec` (and `sub_`, `mul_`, `div_`) rewrites each operation to its
specification. `Spec.add x y` matches on `toDyadic? x, toDyadic? y`; a NaN has no dyadic value
(`toDyadic?_eq_none_of_isNaN`), so the first arm is impossible and the result is `chooseNaN2 x y`'s
NaN: `chooseNaN2` is `none` only if neither operand is a NaN (`chooseNaN2_eq_none_iff`), and what it
returns is a NaN (`isNaN_of_chooseNaN2_eq_some`). `Spec.sub x y` is `Spec.add x (neg y)`, and `neg`
keeps a NaN a NaN (`isNaN_neg`). `Spec.mul` has `add`'s shape; `Spec.div` falls through to
`divSpecial`, which matches on `chooseNaN2` first. At `floatBin` (`floatBin_ofFloat`): the result
is `deliver (f a b) (k / 3)`, which `withFlags` returns unchanged when neither `nnan` nor `ninf` is
set, and `deliver` keeps a NaN a NaN (`isNaN_deliver`). FloatLib v4.1.0 has no such lemma; these
lines answer FloatLib request 1 (NaN propagation) on our side. Instances and twins: `nan_row_inst`,
`nan_row_twin` in MojoProofTest/FloatRel.lean.

**Row: NaN equivalence under free oracles** (`floatOp_nanEq`). For every float type `t`, operator
`op` other than `frem` (`fadd`, `fsub`, `fmul`, `fdiv`) and flags `fm` with `nnan = false` and
`ninf = false`:
`Respects (Val.Lift t NaNEq) (Val.Lift t NaNEq) (fun _ _ => True) (floatOp t op fm)`.

Proof. Row 1's steps 3 and 4 do not use `FinEq`, so they are proved once, for every relation `R`
on the floats of `t` that relates each float to itself (`floatOp_lift`): if `fbin op = some f` and
`R x x'`, `R y y'` give `R (deliver (f x y) n) (deliver (f x' y') n')` for every `n`, `n'`, then
`floatOp t op fm` respects `Val.Lift t R` under any two oracle numbers. Row 1 is `floatOp_lift` with
`FinEq.op` and `FinEq.deliver`. For this row:
1. `fbin_some`: every operator but `frem` has an IEEE operation `f` (by cases).
2. `NaNEq.op`: `NaNEq x x'` and `NaNEq y y'` give `NaNEq (f x y) (f x' y')`. If both pairs are
   equal, the results are. Otherwise one pair (say `x, x'`) are both NaNs, and the NaN row
   (`fbin_isNaN`) makes both results NaNs.
3. `NaNEq.deliver` (proved above) for every two oracle numbers, then `floatOp_lift`.

Instance and twin (`nanEq_row_inst`, MojoProofTest/FloatRel.lean): `fadd` of the two quiet NaNs
`0x7fc00000` and `0x7fc00001` with 1, under the oracle numbers 0 and 5, gives related results;
the operand relation cannot be `FinEq`: `fadd` of `+∞` and 1 and of a quiet NaN and 1 (operands
related by `FinEq`) gives `+∞` and a NaN, which `NaNEq` does not relate.

**Rows left, and why.**
- The error relation is proved for one operation on words with known values (above); along a term,
  as a `Respects` statement, the operands are themselves estimated results, and `Est` must be
  computed from their estimates (the value, the bound and the validity flag propagated, with the
  operands' errors added to the bound), which is not proved.

**Instances and twins** (MojoProofTest/FloatRel.lean, binary32, by evaluation; three of them are
counterexamples):
- `FinEq`: `+∞` and a NaN are `FinEq`; the contracted results `+0` and `-2 ^ -46` of
  `contract false (mul a b) (-1) (some (a, b)) none n` for `n = 0, 1` (`a = 1 + 2 ^ -23`,
  `b = 1 - 2 ^ -23`) are not, so row 1 fails for a recorded factor under free oracles.
- `NaNEq`: two NaNs are; `maxnum true sNaN 1 n` for `n = 1, 0`, a NaN and 1, are not, so `maxnum`
  with a NaN operand does not respect `NaNEq` under free oracles.
- `maxnum`, free row: `maxnum true 1 2 n` is 2 and `maxnum true qNaN 1 n` is 1 for every `n`; the
  twin of the premise on signaling NaNs is `nanEq_inst`'s pair (`sNaN` and 1 under 1 and 0 give a NaN
  and 1); the twin of the premise "not both NaNs": `maxnum true qNaN qNaN' n` under `n = 2 · 0x7fc00000`
  and `n = 2 · 0x7fc00001` gives the two different NaNs `0x7fc00000` and `0x7fc00001`.
- `maxnum`, coupled row: `maxnum true sNaN 1 n` under `n = 1` and `n = 2 · 0x7fc00001 + 1`, of one
  parity, gives two different NaNs, which are `NaNEq`; the twin of the coupling is `nanEq_inst`'s pair
  (`n = 1` and `n = 0`).
- `maxnum` at the intrinsic, on `<2 x float>` vectors with no flags: `<1, qNaN>` and `<2, 1>` give
  `<2, 1>` under every scope (`fminmax_vec_inst`); `<sNaN, 1>` and `<1, 2>` under two scopes whose
  oracle numbers 0 and 1 have one parity each give lanes related by `Val.Lift NaNEq`
  (`fminmax_vec_coupled`). Twins (`fminmax_vec_twin`): of the coupling lane by lane, `<1, sNaN>`
  and `<2, 1>` under two scopes whose oracle numbers 0 are both 0 and whose oracle numbers 1 are
  1 and 0 give lanes 1 that are a NaN and 1, not related; of the premise "no lane has two NaN
  operands", `<qNaN, 1>` and `<qNaN', 2>` under oracle numbers 0 `2 · 0x7fc00000` and
  `2 · 0x7fc00001` give two different NaNs at lane 0.
- `Est`: `⟨-2 ^ -46, 2 ^ -46, true⟩` holds of both contracted results; with bound 0 it holds of
  the fused one and not the unfused one; with `valid = false` it holds of a NaN.
- The error relation's row: `fadd contract` of `mul a b` (with its factors `a = 1 + 2 ^ -23`,
  `b = 1 - 2 ^ -23`) and `-1`, as `floatBin` evaluates it, gives `ct n` for `n = 0, 1, 2`; its
  `Est.contract` is valid with value `a b - 1 = -2 ^ -46`, so each `ct n` is finite and within the
  bound of `-2 ^ -46` (`contract_est_inst`). The twin of the validity flag: `fadd contract` of the
  largest finite binary32 number with itself gives `+∞`; its estimate is not valid
  (`|2M| > M`), and with the flag set the estimate would not hold of `+∞`, which is not finite
  (`contract_est_twin`). The premises `IsProd` have no twin here.
- `RsqrtClose`: both values of `rsqrt 1` (the words of 1 and of `1 + 2 ^ -23`) are close at 1 by
  `rsqrt_close`, and they differ, so `rsqrt` does not respect equality under free oracles; the word
  of `1 + 2 ^ -22` is not close at 1.
- Row 1 on scalars: `floatOp float fadd {}` on `[+∞, 1]` and `[NaN, 1]` gives two results that are
  `Val.Lift FinEq`; its twin with `nnan`: on the same operands one result is poison and the other a
  float, which `Val.Lift FinEq` does not relate; its twin on the operator: `fdiv` of 1 by `+∞` and
  by a NaN gives `+0` and a NaN, which `Val.Lift FinEq` does not relate, so `fdiv` is not in row 1
  (`div` has finite results with an operand that is not finite).

## Composition

Fix a launch, arguments and address choice `ch`. Run once on a reference payload `(m₁, ω₁)` to a
grid that is done and not bad (`Grid.run`, certified by evaluation). Then for every `m₂` with
`Mem.SkelEq pay m₁ m₂` and every `ω₂`:
- T3 (`Grid.payload_run` with T3b) gives a run on `(m₂, ω₂)` to a grid `z₂` that is done and not
  bad, and `Grid.start_sound` gives the six fields of `Grid.Sound` that do not mention `R`;
- T4 gives `obs z₂.mem` as the output terms evaluated on `(m₂, ω₂)`;
- T5 with FloatLib gives `R` of it, which is the seventh field.

This is `Kernel.Sound` for every payload in the class and every admitted oracle, at `ch`. The
quantifier over `ch` stays. It is discharged by the block checker on a run that is
symbolic in the address atoms; that is out of scope here.

### The six-field lemma (MojoProof/Sem/SkelStep.lean, proved)

`Grid.skel_six` is the first two steps for the unit payload, for every program, kernel, launch,
arguments, labelling, payload blocks, address choice and pair of memories and oracles that meet
its premises. From one start `Grid.start prog fn L args m₁ ch o₁ = .ok (g₁, c₁)` with
`m₁.BytesIn m₁.Known`, `Labels.Ok prog lab = true`, `fn` found in `prog`, `lab.MemOk pay L c₁ g₁`
and one run `ReflTransGen (Grid.Step L c₁) g₁ z₁` to a grid `z₁` that is done and not bad: for
every `m₂` with `m₁.SkelEq pay m₂` and every `o₂`, the launch on `(m₂, o₂)` starts at some
`(g₂, c₂)` with `Grid.Sound L c₂ g₂ (fun m => some m.blocks) (fun _ => True)`.

- With the trivial relation the field `post` holds whenever `determinate` does, so the content is
  the first six fields. The observation is the blocks, the strongest one: with the unit
  observation `determinate` would say nothing.
- Proof: `Grid.skel_run` (one use of `Grid.sound_of_one_run`, through `Grid.payload_run` and
  `Grid.start_sound`) at the observation `fun m => some m.blocks`.
- `Grid.Sound.of_blocks` gives the seventh field for any observation `obs` that reads only the
  blocks and any `R`: from soundness for the blocks and one final grid `z` reachable from `g` with
  `obs z.mem = some y` and `R y`, `Grid.Sound L c g obs R`.
- No case split on a float value or the oracle. The proof closure of `Grid.skel_six` (theorem
  values, matchers and auxiliary definitions; 8,203 constants, 4,375 theorems) has no theorem of
  FloatLib, Sem/Float.lean or Sem/FloatRel.lean. The only float-typed matchers in it are 8 splits
  on `Option (Model _)`, whether a decode or a lookup of an operation succeeded
  (`floatBin.match_8`, `_10`, `_13`, `floats2.match_1`, `fnegV.match_1`, `intrinsic.match_1`,
  `_6`, `_8`), and it has no recursor of a FloatLib type. The control `rsqrtOk_rSqrt` has 746
  FloatLib theorems in its closure.
- Instances (MojoProofTest/PayloadRun.lean): `six_inst` on `kF` (load float, `fadd`, store) for
  every word in block 1 and every oracle, from the one run on 1.0 with oracle 0; `sum_inst`, the
  seventh field for bytes 0 to 3 of block 1 and 2.0 at 1.0 and oracle 0.

What a kernel's proof must give for the premises: `Labels.Ok` and the lookup by evaluation; the
first memory's `BytesIn` (its pointer bytes point into its blocks); `Labels.MemOk`, that the
pointer of every payload load and store points into a block of `pay` at every grid reachable from
the start (the hard premise; for `kF` it is checked by `ScheduleOwned.every`, which does not scale
to `vector_addition` on `L23`); and the reference run, done and not bad.

## Dependencies

- In the tree:
  - `Grid.Step`, `Grid.Bad`, `Grid.Sound`, `Path`, `Path.exists_iff`;
  - `Grid.start_sound` (T2's conclusion 2);
  - `exec`, `step`, `enter`, `Grid.advance`, `Grid.fire`;
  - `Mem.load`, `Mem.store`, `Mem.check`, `Mem.fresh`, `castV`, `Layout.decode`,
    `Layout.encode`, `Thread.pending`, `exists_deliver`.
- Defined for T3a: `Grid.Agree`, `Grid.Lockstep` and the five statements above (no semantics).
- Defined for T3b: `Val.erase`, `Val.Skel`, `MemByte.erase`, `MemByte.Skel`, `Block.SkelEq`, `Mem.SkelEq`, `Labels`,
  `Labels.Rel`, `Labels.Ok`, `Labels.MemOk`, `Frame.Skel`, `Thread.Skel`, `Status.Skel`,
  `Grid.SkelRel` and the lemmas listed.
- T3c and T4: the block summaries and `Block.sound`. T5: `SVal`, `SVal.eval`.

## Instances and twins

- T3a, for every launch, contexts and grid: `Grid.Lockstep L c c Eq`. This instance is a theorem
  over all grids. The twin of the field `trace`: a relation that agrees on every step and on
  `Done` but relates two grids with different traces does not preserve `Bad`. Example: `doneP`,
  with a racy trace, and `done2`.
- T3b's run, given: `run_inst` (MojoProofTest/SkelStep.lean), `Grid.skel_run` on the one-step
  runs of `kernel #[]` (`ret void`) on `memX 1` and `memX 2`, which differ in the data byte 0 of
  block 1, the payload block; the ends are related and the second start is sound for that byte.
  Twin `run_twin`: with no payload block, no one-step run on `memX 2` ends at a grid related to
  the first's end. That instance has no payload operation; the next one has.
- T3b's run on a kernel that reads and writes the payload, given: `run_inst`
  (MojoProofTest/PayloadRun.lean), `Grid.skel_run` on `kF`, `%1 = load float, ptr %0`,
  `%2 = fadd float %1, %1`, `store float %2, ptr %0`, launched on one thread on `memF w1`, block
  1 holding 1.0, the payload block, with address choice and oracle 0. The run of four steps ends
  with 2.0 in block 1; for every memory related to `memF w1` and every second oracle, the second
  run of four steps ends at a related done grid that is not bad, and the second start is sound
  for the size of block 1. The load is evaluated after unfolding `Layout.decode` once;
  `Labels.MemOk` needs register 0 to point into block 1 at every reachable grid, which
  `ScheduleOwned.every` checks from the grid after the load. One example: one kernel, one first
  memory, address choice 0 and first oracle 0. Twin `run_twin`: the read-only `memF w1 true` is
  not related to `memF w1`, and no run of four steps on it ends at a done grid, as its store
  faults.
- The twins of T3b's premises:
  - (O1): a branch on `fcmp` of an oracle-chosen word stores in one run and not in the other, so
    the traces differ.
  - `MemOk`: a payload store into a block outside `pay` breaks `Mem.SkelEq`.
  - Same `ch`, counterexample (iii), given as `addr_twin`
    (MojoProofTest/Skeleton.lean): from `start2`'s grid, thread 0's `alloca i32` under `c2` and
    under `c2'` (address choice 1 everywhere) makes block 2 at address 0 and at address 4, so the
    memories are not `Mem.SkelEq` for any `pay`. A `ptrtoint` of the `alloca` and a branch on it
    would then take different edges in the two runs.
