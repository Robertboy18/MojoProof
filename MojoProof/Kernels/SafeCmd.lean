import MojoProof.Kernels.Safe
import MojoProof.Sym.KernelCmd

/-!
# The spec-free mode: `mojo_safe`

`Kernel.Safe` of a kernel from the function alone, with no specification and no hand-written
proof line (docs/proofs/safe.md, "The spec-free mode").

* `MojoProof.Sem.Kernel.admits` and `Kernel.Admits`: the admission, a closed form decided by
  evaluation. The start succeeds; each thread in turn, from the memory the threads before it
  left, has a path of `paths` that `MojoProof.Sym.Ret.check` accepts
  (`MojoProof.Sym.Kernel.check`: the obligations of every block of the path, the exits between
  them, `ret`, and the last block's effects); and the trace of the memory the threads leave in
  turn has no data race (the core's `GPUProof.racy` at `MojoProof.Sem.sig`) and keeps the promise
  of `!invariant.load` (`GPUProof.kept`). The first part is the conjunction of the block
  summaries' obligations over the threads; race freedom adds the condition on pairs of threads.
* `Kernel.safe_of_admits`: for every program, kernel and list of paths that `coversEntry`
  accepts, and every launch, arguments and memory whose pointer bytes are known, the kernel is
  safe (`Kernel.Safe`) at that admission for the observation of the blocks.
* `Kernel.Safe.narrow`: safety at an admission gives it at every smaller admission.
* `MojoProof.Sym.Kernel.firstFail`: the first obligation of the admission that does not hold, as
  text.
* `mojo_safe n := P fn`: derives `fn`'s parameter clauses (`clausesFor`), runs `mojo_kernel` with
  them (the summaries, the paths, `n.covers`), unless an earlier `covers` theorem of the same
  program and kernel exists, which it then uses; and adds `n.safe`, `Kernel.safe_of_admits` at
  that theorem (or uses an earlier theorem of that statement). `mojo_safe n := P fn at L args m
  ch ω hm` also adds `n.safe_at`, the kernel safe at the one choice `ch` and oracle `ω` at that
  launch, arguments and memory (`hm` its `Mem.BytesIn`), the admission decided by
  `decide +kernel`, and the witness `n.obs` (`L.Valid ∧ ∃ y, Kernel.Obs … ∧ True`, for a launch
  `launch2 …`). When the admission is false the command fails with `Kernel.firstFail`'s text,
  the first obligation left, and adds nothing after `mojo_kernel`'s declarations.

The theorems are for every program, kernel, launch, arguments and memory; the command's are
about the one kernel it is given. Nothing here is trusted: `n.covers` and the admission are
decided by the kernel.
-/

namespace MojoProof.Sem

open MojoProof.LLVM

/-- The admission of the spec-free mode, as a test: `Grid.start` at choice `ch` and oracle `ω`
succeeds with grid `g` and contexts `c`, every thread has a path of `paths` that `Ret.check`
accepts from the memory the threads before it left (`MojoProof.Sym.Kernel.check`), and the
memory the threads leave in turn (`MojoProof.Sym.Kernel.mems`) has a trace with no data race
(`GPUProof.racy` at `MojoProof.Sem.sig` is false) that keeps the promise of `!invariant.load`
(`GPUProof.kept`); false when the start faults. -/
def Kernel.admits (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (paths : List (List (Nat × List MojoProof.Sym.Cond × MojoProof.Sym.Summary)))
    (ch : Nat → Nat) (ω : Nat → Nat → Nat) : Bool :=
  match Grid.start prog fn L args m ch ω with
  | .ok (g, c) => MojoProof.Sym.Kernel.check g c paths &&
      !GPUProof.racy sig ((MojoProof.Sym.Kernel.mems g c paths g.threads.size).trace.map
        (Event.toCore L)).reverse &&
      GPUProof.kept sig ((MojoProof.Sym.Kernel.mems g c paths g.threads.size).trace.map
        (Event.toCore L)).reverse
  | .error _ => false

/-- **The admission of the spec-free mode**: the address choices `ch` and oracles `ω` at which
`Kernel.admits` holds, for every program, kernel, launch, arguments, memory and list of paths.
A closed form: on a concrete launch, arguments, memory, choice and oracle the kernel decides it
(`decide +kernel`). -/
abbrev Kernel.Admits (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (paths : List (List (Nat × List MojoProof.Sym.Cond × MojoProof.Sym.Summary)))
    (ch : Nat → Nat) (ω : Nat → Nat → Nat) : Prop :=
  Kernel.admits prog fn L args m paths ch ω = true

/-- **The spec-free theorem from the paths.** For every program `prog`, kernel `fn` and list of
paths `paths` that start at `fn`'s first block and are accepted from position 0 (`coversEntry`),
and every launch `L`, arguments `args` and memory `m` whose pointer bytes are known
(`Mem.BytesIn`), the kernel is safe (`Kernel.Safe`) at the admission `Kernel.Admits` for the
observation of the blocks: at every choice and oracle it admits, the launch starts, no reachable
grid faults or races, every execution ends, and every schedule ends with the same blocks
(`MojoProof.Sym.Kernel.sound_eval` at each admitted choice and oracle). -/
theorem Kernel.safe_of_admits {prog : Program} {fn : Func}
    {paths : List (List (Nat × List MojoProof.Sym.Cond × MojoProof.Sym.Summary))}
    (hc : MojoProof.Sym.coversEntry prog fn paths = true)
    (L : Launch) (args : List Val) (m : Mem) (hm : m.BytesIn m.Known) :
    Kernel.Safe prog fn L args m (Kernel.Admits prog fn L args m paths)
      (fun m => some m.blocks) := by
  intro ch ω ha
  unfold Kernel.Admits Kernel.admits at ha
  split at ha
  · rename_i g c hs
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at ha
    exact MojoProof.Sym.Kernel.sound_eval hc hm hs (fun _ _ h => congrArg some h) ha.1.1
      ⟨ha.1.2, ha.2⟩ ⟨_, rfl, trivial⟩ ch ω ⟨rfl, rfl⟩
  · cases ha

/-- **Safety at a smaller admission**: for every program, kernel, launch, arguments, memory,
observation and admissions `adm`, `adm'` with every choice and oracle of `adm'` one of `adm`,
`Kernel.Safe` at `adm` gives it at `adm'`. -/
theorem Kernel.Safe.narrow {β : Type} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {adm adm' : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    {obs : Mem → Option β} (h : Kernel.Safe prog fn L args m adm obs)
    (hA : ∀ ch ω, adm' ch ω → adm ch ω) : Kernel.Safe prog fn L args m adm' obs :=
  fun ch ω ha => h ch ω (hA ch ω ha)

end MojoProof.Sem

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- What obligation `d` of a block summary says holds, as text. -/
def Cond.text : Cond → String
  | .ok _ => "a value evaluates without a fault"
  | .bool _ => "a branch condition evaluates to a word"
  | .mem _ => "the block's memory effects run without a fault"

/-- A fault as text. -/
def faultText : Fault → String
  | .ub e => s!"undefined behavior: {e}"
  | .unsupported e => s!"unsupported: {e}"

/-- Why the path `ps` of kernel `fn` is or is not a `Ret` from valuation `V` (`Ret.check`):
`.ok true` when it is; `.ok false` when the thread leaves the path (an exit to another block, or
a last block that does not return); `.error` with the block (named by `fn`'s local names) and the
first of its obligations that does not hold, or the fault of the last block's effects. -/
def Ret.why (fn : Func) (V : Valuation) : List (Nat × List Cond × Summary) → Except String Bool
  | [] => .ok false
  | (l, ds, S) :: ps =>
    let vs := vals V S.nodes
    let name := s!"%{fn.names.getD l s!"{l}"}"
    match ds.zipIdx.find? (fun (d, _) => !decide (d.Holds V vs)) with
    | some (d, i) =>
      let f := match d with
        | .ok x => match x.eval V vs with
          | .error e => s!": {faultText e}"
          | .ok _ => ""
        | .bool x => match x.eval V vs with
          | .error e => s!": {faultText e}"
          | .ok _ => ": the value is not a word"
        | .mem es => match SEff.run V vs es with
          | .error e => s!": {faultText e}"
          | .ok _ => ""
      .error s!"block {name}: obligation {i} of {ds.length} ({d.text}) does not hold{f}"
    | none => match ps with
      | [] =>
        if S.exit != .ret then .ok false else
        match SEff.run V vs S.effs with
        | .ok _ => .ok true
        | .error e => .error s!"block {name}: its effects fault: {faultText e}"
      | (l', _, _) :: _ =>
        if S.exit.dest V vs != some l' then .ok false else Ret.why fn (V.intoWith false l S) ps

/-- The first obligation of `MojoProof.Sem.Kernel.admits` that does not hold, as text, or `none`
when it holds: the start's fault; else the first thread with one frame none of whose paths of
`paths` is a `Ret` from its entry valuation on the memory the threads before it left
(`Ret.check`), with the block and obligation that `Ret.why` names on the first path that names
one; else the data race of the trace, or its broken `!invariant.load` promise. -/
def Kernel.firstFail (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (paths : List (List (Nat × List Cond × Summary))) (ch : Nat → Nat) (ω : Nat → Nat → Nat) :
    Option String :=
  match Grid.start prog fn L args m ch ω with
  | .error e => some s!"the start faults: {faultText e}"
  | .ok (g, c) =>
    let bad := (List.range g.threads.size).findSome? fun k =>
      match (Grid.thread g k).frames with
      | [f] =>
        let V := Valuation.entry (c k) 0 (Kernel.mems g c paths k) f
        if paths.any (Ret.check V) then none else
        some <| s!"thread {k}: " ++
          match (paths.map (Ret.why fn V)).findSome? (fun | .error e => some e | _ => none) with
          | some e => e
          | none => "none of the kernel's paths is the one the thread follows"
      | _ => none
    match bad with
    | some e => some e
    | none =>
      let tr := ((Kernel.mems g c paths g.threads.size).trace.map (Event.toCore L)).reverse
      if GPUProof.racy sig tr then
        some "race freedom: the trace of the threads, run in turn, has a data race \
          (GPUProof.racy)"
      else if !GPUProof.kept sig tr then
        some "the trace of the threads, run in turn, breaks the promise of an !invariant.load \
          (GPUProof.kept)"
      else none

open Lean Elab Command Meta

/-- The parameter clauses of a function with parameters `ps`, as `mojo_kernel`'s clause text:
`reads` for each `byval` buffer struct (`Param.buffer`; outside `map2` and `mat`, `mojo_kernel`
treats `reads` and `writes` alike), `scalars` for each integer that is not `byval`
(`Param.scalar`), `pointers` for each plain pointer (`Param.pointer`), parameter `i` named `p<i>`
in each; an error naming the first parameter that is none of them. -/
def clausesFor (ps : List Param) : Except String String := do
  let mut rd := #[]
  let mut sc := #[]
  let mut pt := #[]
  for (p, i) in ps.zipIdx do
    let c := s!"p{i} := a{i}"
    if p.buffer then rd := rd.push c
    else if p.scalar then sc := sc.push c
    else if p.pointer then pt := pt.push c
    else throw s!"parameter a{i} is not a byval buffer struct, an integer or a pointer"
  let grp (k : String) (cs : Array String) : String :=
    if cs.isEmpty then "" else s!" {k} " ++ ", ".intercalate cs.toList
  return grp "reads" rd ++ grp "scalars" sc ++ grp "pointers" pt

/-- Syntax `stx` with every position replaced by the synthetic position of `ref`. -/
partial def synthAt (ref : Syntax) : Syntax → Syntax
  | .node _ k xs => .node .none k (xs.map (synthAt ref))
  | .atom _ v => .atom (SourceInfo.fromRef ref) v
  | .ident _ r v p => .ident (SourceInfo.fromRef ref) r v p
  | .missing => .missing

/-- `mojo_safe n := P fn`, and `mojo_safe n := P fn at L args m ch ω hm`: the spec-free mode
(the module docstring). -/
syntax (name := mojoSafe) "mojo_safe " ident " := " term:max term:max
  (&" at " term:max term:max term:max term:max term:max term:max)? : command

/-- Elaborates `mojo_safe`; `unsafe` because it evaluates the function and the admission's
first failure. -/
@[command_elab mojoSafe] unsafe def elabMojoSafe : CommandElab := fun stx => do
  let n := stx[1].getId
  let base := (← getCurrNamespace) ++ n
  let Pstx : Lean.Term := ⟨stx[3]⟩
  let fnstx : Lean.Term := ⟨stx[4]⟩
  let fnText := toString fnstx.raw.prettyPrint
  let (fn, Pe, fne) ← liftTermElabM do
    let Pe ← Term.elabTermEnsuringType Pstx (mkConst ``Program)
    let fne ← Term.elabTermEnsuringType fnstx (mkConst ``Func)
    Term.synthesizeSyntheticMVarsNoPostponing
    let Pe ← instantiateMVars Pe
    let fne ← instantiateMVars fne
    pure (← evalExpr Func (mkConst ``Func) fne, Pe, fne)
  -- 1. the parameter clauses, from the function
  let cls ← match clausesFor fn.params with
    | .ok c => pure c
    | .error e => throwError "mojo_safe: {e} ({fnText})"
  -- 2. an earlier `covers` of the same program and kernel, or `mojo_kernel` with the clauses
  let isCovers (t : Expr) : Bool := match t.eq? with
    | some (_, lhs, rhs) => rhs.isConstOf ``Bool.true && lhs.isAppOfArity ``coversEntry 3 &&
        lhs.appFn!.appFn!.appArg! == Pe && lhs.appFn!.appArg! == fne
    | none => false
  let earlier := (← getEnv).constants.fold (init := none) fun acc c ci =>
    if acc.isSome then acc else match c, ci with
      | .str _ "covers", .thmInfo t => if isCovers t.type then some c else none
      | _, _ => none
  let coversN ← match earlier with
    | some c => pure c
    | none => do
      let text := s!"mojo_kernel {n} := {Pstx.raw.prettyPrint} {fnstx.raw.prettyPrint}{cls}"
      let kstx ← match Parser.runParserCategory (← getEnv) `command text with
        | .ok s => pure (synthAt stx s)
        | .error e => throwError "mojo_safe: the clauses do not parse: {e} ({text})"
      let msgs0 := (← get).messages
      -- synchronously, so that an error of a theorem's proof is among the messages here
      withScope (fun sc => { sc with opts := Elab.async.set sc.opts false }) (elabCommand kstx)
      let errs := ((← get).messages.toList.drop msgs0.toList.length).filter
        (·.severity == .error)
      if let some e := errs.head? then
        modify fun s => { s with messages := msgs0 }
        throwError "mojo_safe: mojo_kernel{cls}: {← e.data.toString} ({fnText})"
      pure (base ++ `covers)
  -- 3. with `at`: the admission's first failure at the launch, evaluated (a refused launch adds
  -- nothing more)
  let a := stx[5]
  let (L, args, m) : Lean.Term × Lean.Term × Lean.Term := (⟨a[1]⟩, ⟨a[2]⟩, ⟨a[3]⟩)
  let (ch, ω, hm) : Lean.Term × Lean.Term × Lean.Term := (⟨a[4]⟩, ⟨a[5]⟩, ⟨a[6]⟩)
  let Ltext := toString L.raw.prettyPrint
  let fail ← if a.isNone then pure none else liftTermElabM do
    let t ← inferType (mkConst coversN)
    let some (_, lhs, _) := t.eq? | throwError "mojo_safe: {coversN} is not an equation"
    let paths ← Term.exprToSyntax lhs.appArg!
    let e ← Term.elabTermEnsuringType
      (← `($(mkCIdent ``Kernel.firstFail) $Pstx $fnstx $L $args $m $paths $ch $ω))
      (mkApp (mkConst ``Option [0]) (mkConst ``String))
    Term.synthesizeSyntheticMVarsNoPostponing
    evalExpr (Option String) (mkApp (mkConst ``Option [0]) (mkConst ``String))
      (← instantiateMVars e)
  if let some why := fail then
    throwError "mojo_safe: the admission does not hold at {Ltext}: {why} ({fnText})"
  -- 4. `n.safe`: an earlier theorem of the same statement, or one added
  let (safeE, safeT) ← liftTermElabM do
    let e ← Term.elabTerm (← `($(mkCIdent ``Kernel.safe_of_admits) $(mkCIdent coversN))) none
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars e
    pure (e, ← inferType e)
  let safeN := (← getEnv).constants.fold (init := none) fun acc c ci =>
    if acc.isSome then acc else match c, ci with
      | .str _ "safe", .thmInfo t => if t.type == safeT then some c else none
      | _, _ => none
  let safeN ← match safeN with
    | some c => pure c
    | none => do
      let name := base ++ `safe
      liftCoreM <| addDecl (.thmDecl { name, levelParams := [], type := safeT, value := safeE })
      addDocStringCore (base ++ `safe) s!"**`{fnText}` is safe** (`Kernel.Safe`) for every \
        launch, arguments and memory whose pointer bytes are known, at the admission \
        `Kernel.Admits` of its paths, for the observation of the blocks: \
        `Kernel.safe_of_admits` at `{coversN}`, with the parameters' clauses{cls} derived from \
        the function (`mojo_safe {n}`). It covers this one kernel."
      pure (base ++ `safe)
  -- 5. with `at`: the kernel safe at the launch, and the witness
  if a.isNone then return
  let sealed := (← getReducibilityStatus ``Array.anyM.loop) matches .irreducible
  let unsealIn (c : TSyntax `command) : CommandElabM (TSyntax `command) :=
    if sealed then `(command| unseal Array.anyM.loop in $c:command) else pure c
  let atId := mkIdent (n ++ `safe_at)
  elabCommand (← unsealIn (← `(command|
    theorem $atId : $(mkCIdent ``Kernel.Safe) $Pstx $fnstx $L $args $m
        (fun ch' ω' => ch' = $ch ∧ ω' = $ω) (fun m => some m.blocks) :=
      $(mkCIdent ``Kernel.Safe.narrow) ($(mkCIdent safeN) $L $args $m $hm)
        (fun _ _ ⟨h1, h2⟩ => by subst h1 h2; decide +kernel))))
  addDocStringCore (base ++ `safe_at) s!"**`{fnText}` is safe at one launch**: `{safeN}` at \
    the launch `{Ltext}`, the arguments `{args.raw.prettyPrint}` and the memory \
    `{m.raw.prettyPrint}`, at the one address choice `{ch.raw.prettyPrint}` and oracle \
    `{ω.raw.prettyPrint}`, whose admission the kernel decides (`decide +kernel`). A test of one \
    launch."
  let obsId := mkIdent (n ++ `obs)
  elabCommand (← `(command|
    theorem $obsId : Launch.Valid $L ∧ ∃ y, $(mkCIdent ``Kernel.Obs) $Pstx $fnstx $L $args $m
        (fun m => some m.blocks) $ch $ω y ∧ True :=
      ⟨$(mkCIdent ``launch2_valid) (by decide),
        $(mkCIdent ``Kernel.Sound.exists_obs) $(mkCIdent (base ++ `safe_at)) ⟨rfl, rfl⟩⟩))
  addDocStringCore (base ++ `obs) s!"**The witness of `{n}.safe_at`**: the launch `{Ltext}` is \
    valid, and some complete run of `{fnText}` on it at that choice and oracle is observed \
    (`Kernel.Sound.exists_obs` at `{n}.safe_at`). A test of one launch."

end MojoProof.Sym
