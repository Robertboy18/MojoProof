import MojoProof.Sym.Kernel
import MojoProof.Sym.Command
import MojoProof.Sym.Start
import MojoProof.Sym.Ops
import MojoProof.Sym.KernelMat

/-!
# A kernel's paths as Lean terms: `mojo_kernel`

`mojo_kernel n := P fn reads x := a0, … writes y := a2, … scalars z := a3, … pointers q := a4, …
map2 t e bytes contract loop h := …` names the parameters of kernel `fn` of program `P` (`a<i>` is
parameter `i`; each clause group is optional; `fn` is a term, elaborated, and steps 5 and 6 use
the constant it denotes), and, when the command is elaborated:

1. checks the clauses against `fn.params` (`clauseError`): every parameter is named by exactly
   one clause, a `reads` or `writes` parameter is `byval` of a buffer struct (a struct whose first
   field is a pointer), a `scalars` parameter is an integer that is not `byval`, and a `pointers`
   parameter is a pointer that is not `byval` (such as `ptr addrspace(1) %p`). A clause list
   that names fewer parameters than `fn` has is refused, so a launch built from the clauses passes
   one value per parameter. The flag `contract` (before the loop clauses, if any; not with `map2`,
   whose theorem has no variant with the flag) puts
   `fmul contract` in the checker's fragment: steps 2 to 5 then use the variants with the flag
   (`summarizeC`, `coversEntryWith true`, `coversChainsWith true`, `EdgeWith true`,
   `Valuation.roundWith true`, `RoundWith true`, `RetWith true`, `RetLsWith true` by
   `ChainWith.loop`, `Kernel.sound_of_chainsWith` and `Kernel.sound_entryWith` at
   `contract := true`), and without it a block with `fmul contract` is outside the fragment;
2. evaluates `summarize P fn l (phiCount fn l)` for every block `l` of `fn` (as `sym_summary`: from
   after the block's `phi`s, the position an edge enters it at, `Exit.pc`; 0 for a block without
   `phi`s) and adds `n.b<i> : Summary`, the summary of block `i`, after the checks of steps 3 and 6
   (so a refused command adds nothing); a block outside the checker's fragment is an error naming
   it. `n.b<i>` and `n.paths` are registered for equation lemmas
   (`enableRealizationsForConst`), so `simp only [n.b<i>]` unfolds them in the module that runs the
   command too;
3. enumerates the paths from the entry block over the summaries' exits (`kernelSegs`, depth
   first; `br d` to `d`, `cond c d e` and `phi c d e` to `d` then `e`, `ret` ends a path); a
   branch into a block with `phi`s is followed, and the path checker with `phi`s (`coversPathI`,
   in `coversEntry`) covers its target from after them. It adds `n.paths`, each path a list of
   `(label, n.b<i>.obls, n.b<i>)`, and the theorem `n.covers : coversEntry P fn n.paths = true`,
   proved by `decide +kernel`. A branch to a block on the current path is a loop: without the
   clause `loop h := pre inv trips post by tac` it is an error naming the block. With it, block
   `h` (a block number, not the entry block) is the header of the kernel's one loop: the paths
   end at a branch into `h`, and the command needs one path from the entry block into `h`, one
   round from `h` back to it and one path from `h` to a `ret`, with no other loop (an error
   otherwise), and checks that the path checker accepts them (`coversChains`) and that `pre`,
   `inv`, `trips`, `post` have the types `Valuation → Prop` (on the thread's entry valuation),
   `Valuation → Nat → Valuation → Prop` (the invariant by round at that valuation),
   `Valuation → Nat` (the trip count) and `Valuation → Mem → Prop` (on the memory the thread
   leaves), before it adds anything. It adds the sequence of loops `n.chains` (`LoopChain`, the
   loop entered at the header's position `Exit.pc`), the theorem
   `n.coversChains : coversChains P fn n.chains = true` by `decide +kernel`, the obligations of
   `Chain.loop` at every valuation `V` of `pre` (`n.entry`, the path into the loop is an
   `Edge`; `n.init`, `inv V 0` after it; `n.step`, each round `i < trips V` from `inv V i` is a
   `Round` to `inv V (i + 1)`; `n.exit`, the path out from `inv V (trips V)` is a `Ret` to
   `post V`), each proved by `tac` (`decide +kernel` if the clause has no `by`; `proveBy`, with
   no error recovery), and the thread's run `n.loop` (`RetLs` by `Chain.loop`). If `tac` leaves
   some obligations, the error names each of them and the command restores the environment, so
   it adds nothing. With a clause for each of several loops in sequence, in the order a thread
   runs them, the paths end at a branch into any of their headers; the command needs one path
   from the entry block into the first loop, and for each loop one round and one path out, into
   the next clause's loop or, after the last, to a `ret`. `n.chains` has a `LoopSeg` for each
   loop; each loop's obligations end with its header (`n.entry<h>`), its path in is the previous
   loop's path out, and the exit of each loop but the last is that the invariant at its trip
   count gives the next clause's precondition, whose postcondition implies this clause's;
   `n.loop` is `Chain.loop` for each loop in turn, from the first clause's precondition;
4. adds `n.sound_of`, `Kernel.sound_of_paths` at `n.covers` (with the loop clause
   `Kernel.sound_of_chains` at `n.covers` and `n.coversChains`; with the flag and no loop clause
   `Kernel.sound_of_chainsWith` at `n.covers` and no sequence of loops, whose cover is `rfl`): the
   kernel theorem for `fn`, for
   every launch, arguments, memory, admission, observation and predicate, from the premises that
   remain (the caller's pointer bytes, the start, the observation and the per-thread invariant);
5. when `fn` elaborates to a constant (a name, or a term such as `(f)` that denotes one) and `P`
   has no globals: adds `n.args`, the arguments from the clauses in
   parameter order (a buffer's is its `byval` struct with a pointer to offset 0 of a block number
   and the zero value of every other field, `Layout.zero` evaluated by the command and written as
   a term by `valTerm`; a pointer's is the pointer `.ptr ⟨b, 0⟩` to offset 0 of a block number
   `b`; a scalar's is a bit vector), the theorem `n.starts`, that the start on
   `n.args` succeeds for every launch, block numbers, scalars, memory closed for the arguments
   (`Mem.Closed`), address choice and oracle (`Sym.Grid.start_ok`, each premise by `rfl`,
   `decide +kernel` or `simp` on `fn`'s parameters), and `n.sound`, `n.sound_of` on `n.args` with
   the start's premise replaced by `Mem.Closed`. A scalar or pointer whose attributes `withAttrs`
   does not accept by evaluation on every memory (a pointer's `nonnull` or `align`, which depend
   on its address) is an error at `n.starts`. With the loop clause it also adds
   `n.sound_loop`, `Kernel.sound_entry` at `n.covers` and `n.coversChains` on `n.args`, with the
   start by `n.starts` and each thread by `n.loop`: its premises are `Mem.Closed`, the pointer
   bytes, the observation reading only blocks, an invariant `I` by the number of threads done
   that holds of every memory with the caller's blocks and an empty trace, the per-thread premise
   that every valuation with the start's facts (the program, the thread's identity and special
   registers, the kernel, and each scalar's and pointer's register holding its argument) and a
   memory of `I k` meets the first clause's `pre`, with `post` there implying `I (k + 1)`, and
   the end check on `I` after all threads; with `contract` the per-thread premise also has an
   admitted address choice and oracle `oracle` and the thread's oracle `oracle k`, on which a
   fused operation's rounding depends. Another `fn` or a program with globals skips this step and
   the next;
6. with the clause `map2 t e bytes` (a binary elementwise kernel: element type `t`, encoder `e`,
   and `bytes ω x y n k`, the bytes thread `k` stores at oracle `ω` for tensors `x`, `y` and count
   `n`), when `fn` elaborates to a constant, `P` has no globals, the clauses are `reads` of `a0`,
   `a1`, `writes` of `a2` and `scalars` of an `i32` `a3` and `a0` to `a2` are `byval` of one struct
   of a pointer and a tail with a zero value (otherwise an error naming the reason and `fn`,
   checked before step 2 adds anything): adds `n.argTy`, that struct type, and
   `n.argTail`, the zero tail; the theorem `n.ret`, each thread's path is a `Ret` to the
   elementwise invariant `Elem` after one more thread with `bytes` at cells `size t * i` (for
   every valid launch whose grid and block have side 1 in `y` and `z`, alignment, blocks, count
   below `2 ^ 31`, tensors, thread, context, oracle and frame and memory with the start's facts),
   proved by the tactic mojo_ret (MojoProof/Sym/Ops.lean), an error at `n.ret` if it does
   not prove it; and the kernel theorem `n.correct`, `Kernel.sound_map2` at `n.covers`,
   `n.starts` and `n.ret`, for every such launch and every caller's memory of `Map2.Pre` at `t`,
   `e` and `n.argTail`, every address choice and oracle. Both are about the one kernel `fn`.
   The clause names are the binder names of the blocks and the count in both;
7. with the clause `mat paths chains` (a matmul kernel: the output and two inputs `byval` of one
   struct, then the `i32` sizes `m`, `n`, `K`; `elabMat`), in place of steps 2 to 6: when `fn`
   elaborates to a constant, `P` has no globals, the clauses are `reads` of `a1`, `a2`, `writes`
   of `a0` and `scalars` of `a3`, `a4`, `a5`, the three structs are of a pointer and a tail with a
   zero value `z`, parameter `j` is named `%j`, no clause name is a binder name of the kernel
   theorem, there is no `map2` or `loop` clause, `paths` and `chains` are not empty (evaluated;
   the checker's cover of an empty list is vacuous, and the theorem would then cover only
   launches with no thread out of, or in, bounds), and the path checker accepts `paths` and
   `chains` (`coversEntryWith contract`, `coversChainsWith contract`, evaluated; otherwise an
   error naming the reason and `fn`, before anything is added): adds `n.names`, parameter `j` of
   `fn` has register name `j` (by `decide +kernel`), `n.starts`, the start on
   `Mat.args z o a b m n K` (Sem/Precond.lean) succeeds (`Sym.Grid.start_ok`, as in step 5), and
   `n.sound_mat`, the kernel theorem of `fn` from its threads' runs, `Kernel.sound_mat` at
   `fn`, `paths`, `chains`, the struct type and `z`, with every premise that depends only on the
   program discharged (the paths and the chains by `decide +kernel`, the parameters by `rfl`, the
   names by `n.names`, the codec by `Layout.Codec.ptrArg`, the alignment by `decide`, `withAttrs`
   by `rfl`, the start by `n.starts`). The launch's and the memory's premises and the threads'
   runs `Hin` and `Hout` remain, named so that a caller passes them by name. Its instance is the
   naive matmul kernel (MojoProofTest/NaiveSound.lean).

In a library module (`MojoProof.*`), or in any module with the option `mojo_kernel.share` true,
a definition `n.b<i>`, `n.paths`, `n.chains`, `n.args`, `n.argTy` or `n.argTail` whose value
an earlier definition of `mojo_import` or `mojo_kernel` has, in the imports or the module, is not
added again: the command uses that constant (`kernelDef`, by `share` of
MojoProof/LLVM/Quote.lean), so the library has no two definitions of one value, nor does a test
module that sets the option.
vector_multiply's blocks `%4`, `%30` and `%31`, arguments, struct type and tail are `vadd.b0`,
`vadd.b2`, `vadd.b3`, `vadd.args`, `vadd.argTy` and `vadd.argTail` (MojoProof/Kernels/Vmul.lean).
In a test module without the option each is added under its own name.

Nothing here is trusted: the theorems are checked by the kernel, so a wrong summary, path or
quotation makes `n.covers` or `n.coversChains` fail, not hold. This module is executable code
with no theorems.
-/

open Lean Elab Command Meta

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The parameter number `i` of a clause's right side `a<i>`, if it has that form. -/
def paramIndex? (s : String) : Option Nat :=
  match s.toList with
  | 'a' :: d :: ds =>
    if (d :: ds).all Char.isDigit then
      some ((d :: ds).foldl (fun n c => 10 * n + (c.toNat - '0'.toNat)) 0)
    else none
  | _ => none

/-- Whether parameter `p` is `byval` of a buffer struct (a struct whose first field is a
pointer). -/
def _root_.MojoProof.LLVM.Param.buffer (p : Param) : Bool :=
  p.attrs.any fun | .ty "byval" (.struct (.ptr _ :: _)) => true | _ => false

/-- Whether parameter `p` is an integer that is not `byval`. -/
def _root_.MojoProof.LLVM.Param.scalar (p : Param) : Bool :=
  (p.ty matches .int _) && !p.attrs.any fun | .ty "byval" _ => true | _ => false

/-- Whether parameter `p` is a pointer that is not `byval` (a plain pointer such as
`ptr addrspace(1) %p`, whose argument is the pointer itself). -/
def _root_.MojoProof.LLVM.Param.pointer (p : Param) : Bool :=
  (p.ty matches .ptr _) && !p.attrs.any fun | .ty "byval" _ => true | _ => false

/-- The first error of the clauses `bufs` (`reads` and `writes`), `scalars` and `ptrs`
(`pointers`), each a clause's name and parameter number, against the parameters `ps`; `none` if
every parameter is named by exactly one clause, of the right kind (`Param.buffer`,
`Param.scalar`, `Param.pointer`). -/
def clauseError (ps : List Param) (bufs scalars ptrs : List (String × Nat)) : Option String :=
  let all := bufs ++ scalars ++ ptrs
  match all.find? (·.2 ≥ ps.length) with
  | some (x, i) => some s!"clause {x} := a{i}: the kernel has {ps.length} parameters"
  | none =>
    match (List.range ps.length).find? fun i => (all.filter (·.2 == i)).length != 1 with
    | some i => some s!"parameter a{i} is named by {(all.filter (·.2 == i)).length} clauses, \
        not 1"
    | none =>
      match bufs.find? fun (_, i) => !(ps.getD i default).buffer with
      | some (x, i) => some s!"clause {x} := a{i}: a{i} is not byval of a buffer struct"
      | none =>
        match scalars.find? fun (_, i) => !(ps.getD i default).scalar with
        | some (x, i) => some s!"clause {x} := a{i}: a{i} is not an integer passed by value"
        | none =>
          match ptrs.find? fun (_, i) => !(ps.getD i default).pointer with
          | some (x, i) => some s!"clause {x} := a{i}: a{i} is not a pointer without byval"
          | none => none

/-- The successors of an exit, as labels: `br d` has `d`, `cond c d e` and `phi c d e` have `d`
then `e` (once if they are equal), `ret` none. -/
def Exit.succs : Exit → List Nat
  | .br d => [d]
  | .cond _ d e | .phi _ d e => if d = e then [d] else [d, e]
  | .ret => []

/-- The paths from block `i`, as lists of block numbers with their ends, depth first, given each
block's successors `succ` (block numbers), the blocks `stop` at which a path ends and the blocks
`stack` of the path so far: a path ends at a block without successors (`none`, a `ret`) or with
a branch into a block `j` of `stop` (`some j`). `.error j` if a branch goes to a block `j` on
the path that is not in `stop` (a loop). `fuel` bounds the depth; it is the number of blocks plus
one, since a path without a loop visits each block at most once. -/
def kernelSegs (succ : Nat → List Nat) (stop : Nat → Bool) :
    Nat → List Nat → Nat → Except Nat (List (List Nat × Option Nat))
  | 0, _, i => .error i
  | fuel + 1, stack, i =>
    if i ∈ stack then .error i
    else match succ i with
      | [] => .ok [([i], none)]
      | ss => do
        let pss ← ss.mapM fun j =>
          if stop j then pure [([], some j)] else kernelSegs succ stop fuel (i :: stack) j
        pure (pss.flatten.map fun (p, e) => (i :: p, e))

/-- The identifiers of `stx`, in order. -/
partial def identsOf (stx : Syntax) : Array Syntax :=
  if stx.isIdent then #[stx] else stx.getArgs.foldl (fun a s => a ++ identsOf s) #[]

/-- A term that elaborates to value `v` (`Val.ptr` with its block and offset, `Val.bits` from the
number of its bits). -/
partial def valTerm : Val → CommandElabM Lean.Term
  | .bits w b => `(Val.bits $(quote w) (BitVec.ofNat $(quote w) $(quote b.toNat)))
  | .ptr ⟨b, .ofNat o⟩ => `(Val.ptr ⟨$(quote b), Int.ofNat $(quote o)⟩)
  | .ptr ⟨b, .negSucc o⟩ => `(Val.ptr ⟨$(quote b), Int.negSucc $(quote o)⟩)
  | .poison => `(Val.poison)
  | .undef => `(Val.undef)
  | .vec xs => do `(Val.vec [$(← xs.toArray.mapM valTerm),*])
  | .agg xs => do `(Val.agg [$(← xs.toArray.mapM valTerm),*])

/-- The clauses of an optional clause group: each name with its parameter number. -/
def clausesOf (stx : Syntax) : CommandElabM (List (String × Nat)) := do
  let ids := identsOf stx
  (List.range (ids.size / 2)).mapM fun j => do
    let x := ids[2 * j]!.getId.toString
    let a := ids[2 * j + 1]!
    match paramIndex? a.getId.toString with
    | some i => pure (x, i)
    | none => throwErrorAt a "mojo_kernel: {a} is not a parameter a<i>"

/-- Whether `mojo_kernel` shares definitions outside the library (default `false`): when `true`,
a definition `n.b<i>`, `n.paths`, `n.chains`, `n.args`, `n.argTy` or `n.argTail` whose value an
earlier definition of `mojo_import` or `mojo_kernel` has, in the imports or the module, is not
added again and the command uses that constant (`kernelDef`). In a library module
(`MojoProof.*`) the command shares definitions whatever the option's value. -/
register_option mojo_kernel.share : Bool := {
  defValue := false
  descr := "whether mojo_kernel uses an earlier definition of a value in a module outside \
    MojoProof.* too (it always does in a library module)" }

/-- The constant of a definition `name : type := value` of `mojo_kernel`, with docstring `doc` and
its equation lemmas enabled (`enableRealizationsForConst`): in a library module (`MojoProof.*`), or
in any module when the option `mojo_kernel.share` is true, an earlier definition of `mojo_import`
or `mojo_kernel` of the same value, in the imports or the module, if there is one (`share`; no two
definitions of one value); otherwise `name`, added. -/
def kernelDef (name : Name) (type value : Expr) (doc : String) : CoreM Name := do
  let c ← if (← getEnv).mainModule.getRoot == `MojoProof || mojo_kernel.share.get (← getOptions)
    then pure (← share name type value).constName!
    else do addDef name type value; pure name
  if c == name then
    enableRealizationsForConst name
    addDocStringCore name doc
  return c

/-- `kernelDef` at the elaborated term `stx` and its type. -/
def kernelDefOf (name : Name) (stx : Lean.Term) (doc : String) : CommandElabM Name :=
  liftTermElabM do
    let e ← Term.elabTerm stx none
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars e
    kernelDef name (← instantiateMVars (← inferType e)) e doc

/-- `mojo_kernel n := P fn reads … writes … scalars … pointers …` adds the summaries `n.b<i>`, the
paths `n.paths`, the theorem `n.covers : coversEntry P fn n.paths = true` and the kernel theorem
`n.sound_of` (`Kernel.sound_of_paths` at `n.covers`) of kernel `fn` of program `P`, and, when
`fn` elaborates to a constant and `P` has no globals, the arguments `n.args` (a `reads` or
`writes` parameter's `byval` struct, a `pointers` parameter's pointer, each at offset 0 of a block
number, and a `scalars` parameter's bit vector), the start `n.starts` and the kernel theorem
`n.sound` on them; with `map2 t e bytes`, also `n.argTy`, `n.argTail`, each thread's `Ret`
`n.ret` (by `mojo_ret`) and the kernel theorem `n.correct` (`Kernel.sound_map2`). With
`loop i := pre inv trips post by tac` (block `i` the header of the kernel's one loop,
`pre : Valuation → Prop` on the thread's entry valuation, `inv : Valuation → Nat → Valuation →
Prop` the invariant by round at that valuation, `trips : Valuation → Nat` the trip count,
`post : Valuation → Mem → Prop` on the memory the thread leaves, `by tac` optional, default
`decide +kernel`), also the sequence of loops `n.chains`, its theorem `n.coversChains`, the
obligations `n.entry`, `n.init`, `n.step`, `n.exit` (each proved by `tac`), the thread's run
`n.loop`, `n.sound_of` is `Kernel.sound_of_chains`, and with `n.args` also the kernel theorem
`n.sound_loop` on them (`Kernel.sound_entry`).
With a `loop` clause for each of several loops in sequence, in the order a thread runs them, the
obligations end with the header (`n.entry<i>`), a loop's path in is the previous loop's path out,
and the exit of each loop but the last is the next clause's precondition at the invariant at the
trip count, with its postcondition implying this clause's; `n.loop` and `n.sound_loop` take the
first clause's precondition and postcondition. With `contract` (before the loop clauses, if any),
`fmul contract` is in the checker's fragment and every one of these is over the variant with the
flag (`summarizeC`, `coversEntryWith true`, `coversChainsWith true`, `EdgeWith true`,
`Valuation.roundWith true`, `RoundWith true`, `RetWith true`, `RetLsWith true`,
`Kernel.sound_of_chainsWith` and `Kernel.sound_entryWith`), and `n.sound_loop`'s per-thread
premise also has an admitted address choice and oracle and the thread's oracle. Errors on
clauses that do not name each parameter once with its kind, on `contract` with `map2`,
on a block outside the checker's fragment, on a loop without a `loop` clause
(naming its header), on loop clauses without one path into the first loop and, for each loop, one
round and one path out into the next loop or, after the last, to a `ret`, or whose obligations
`tac` does not all close (naming each one it leaves), and with `map2` on an `fn` that is not a
constant, a program with globals, a kernel of another shape or a loop; a refused command adds
nothing. In a library module or with `mojo_kernel.share`, a summary, the paths, the chains, the
arguments, the struct type or tail of an earlier definition's value are that definition
(`kernelDef`). With `mat paths chains` (after the other clauses; `contract` optional), for a
kernel of the parameters `byval` output, two `byval` inputs and `i32` sizes `m`, `n`, `K`, the
command adds only `n.names`, `n.starts` (on `Mat.args`) and `n.sound_mat`, `Kernel.sound_mat`
at `paths` and `chains` with every premise of the program discharged, whose premises are the
memory premises and the threads' runs `Hin` and `Hout` (`elabMat`). -/
syntax (name := mojoKernel) "mojo_kernel " ident " := " term:max term:max
  (&" reads " sepBy1(ident " := " ident, ", "))? (&" writes " sepBy1(ident " := " ident, ", "))?
  (&" scalars " sepBy1(ident " := " ident, ", "))? (&" pointers " sepBy1(ident " := " ident, ", "))?
  (&" map2 " term:max term:max term:max)? (&" contract")?
  (&" loop " num " := " term:max term:max term:max term:max (" by " Lean.Parser.Tactic.tacticSeq)?)*
  (&" mat " term:max term:max)? : command

/-- Proves the theorem `name : type` by the tactic `tac` without error recovery, and adds it:
`true` if `tac` closes the goal and its proof has no placeholder (`Expr.hasSorry`) and no
metavariable; otherwise `false`, with the state, the environment and the messages as before (the
tactic's errors are discarded). -/
def proveBy (name : Name) (type : Expr) (tac : Syntax) : TermElabM Bool := do
  let s ← Term.saveState
  try
    let mv ← mkFreshExprSyntheticOpaqueMVar type
    let gs ← Term.withoutErrToSorry <|
      Tactic.run mv.mvarId! (Tactic.withoutRecover (Tactic.evalTactic tac))
    Term.synthesizeSyntheticMVarsNoPostponing
    let v ← instantiateMVars mv
    unless gs.isEmpty && !v.hasSorry && !v.hasExprMVar do
      s.restore
      return false
    addDecl <| .thmDecl { name, levelParams := [], type, value := v }
    return true
  catch _ =>
    s.restore
    return false

/-- One `loop` clause of `mojo_kernel`, as `elabLoopClause` takes it: the header (a block number),
the position its rounds start at, its round and its path out as block numbers, the clause's
precondition, invariant, trip count and postcondition, its tactic (`none` without `by`), and the
texts of the header, the round and the path out. -/
abbrev LoopClause : Type :=
  Nat × Nat × List Nat × List Nat × (Lean.Term × Lean.Term × Lean.Term × Lean.Term) ×
    Option Syntax × String × String × String

/-- The proof term of a thread's run through the loops `ks` in order (each given by its clause's
invariant and trip count and the constants of its obligations `entry`, `init`, `step` and `exit`)
from valuation `V` with the first one's precondition `hV`, to `ret` with a memory of the predicate
of `hQ` (a proof that the first one's postcondition at `V` implies it): `Chain.loop` for each
loop, the next loop's from every valuation of the invariant at the trip count, by that loop's
`exit` (the next precondition, and the next postcondition implies this one's), and `Chain.last`
with `Ret.mono` for the last loop's path out; with `contract`, `ChainWith.loop`,
`ChainWith.last` and `RetWith.mono`. Each level's binders have their own macro scope. -/
def loopRun (contract : Bool) : List (Lean.Term × Lean.Term × Ident × Ident × Ident × Ident) →
    Lean.Term → Lean.Term → Lean.Term → CommandElabM Lean.Term
  | [], _, _, _ => throwError "mojo_kernel: no loop clause"
  | (invS, tripsS, entryI, initI, stepI, exitI) :: ks, V, hV, hQ => withFreshMacroScope do
    let W := mkIdent (← MonadQuotation.addMacroScope `W)
    let hW := mkIdent (← MonadQuotation.addMacroScope `hW)
    let (loopC, lastC, monoC) := if contract then
        (mkCIdent ``ChainWith.loop, mkCIdent ``ChainWith.last, mkCIdent ``RetWith.mono)
      else (mkCIdent ``Chain.loop, mkCIdent ``Chain.last, mkCIdent ``Ret.mono)
    let next ← match ks with
      | [] => `($lastC ($monoC $hQ ($exitI $V $hV $W $hW)))
      | _ => do
        let hV' ← `(($exitI $V $hV $W $hW).1)
        let hQ' ← `(fun me h => $hQ me (($exitI $V $hV $W $hW).2 me h))
        loopRun contract ks W hV' hQ'
    `($loopC ($invS $V) ($tripsS $V) ($entryI $V $hV) ($initI $V $hV)
        (fun i hi W hW => $lastC ($stepI $V $hV i hi W hW)) fun $W:ident $hW:ident => $next)

/-- The declarations of the `loop` clauses of `mojo_kernel n`, in namespace `ns`, for kernel
`fnstx` (named `fnText`) of program `Pstx`: given the constants `bns` of the blocks' summaries,
the blocks' labels `lbl`, the path entries `tupleE` (of type `tupleTy`), the path `en` from the
entry block into the first loop's header (block numbers, named `enText`) and the clauses `cls`
in the order a thread runs their loops (`LoopClause`: each loop's round goes from its header back
to it, and its path out to the next loop's header, the last one's to a `ret`), adds the sequence
of loops `n.chains`, the theorem `n.coversChains`, each loop's obligations, each proved by its
clause's tactic (`proveBy`; `decide +kernel` without `by`), and the thread's run `n.loop`, and
returns the constant of the chains. With one clause the obligations are `n.entry`, `n.init`,
`n.step` and `n.exit`; with more, each name ends with its loop's header (`n.entry1`), a loop's
path in is the previous loop's path out, and the exit of a loop before the last is that the
invariant at its trip count gives the next clause's precondition, whose postcondition implies
this one's. If a tactic leaves some obligations, an error names each of them, and the caller
restores the environment. With `contract` (`fmul contract` in the fragment), the theorem and the
obligations are over `coversChainsWith true`, `EdgeWith true`, `Valuation.roundWith true`,
`RoundWith true` and `RetWith true`, and `n.loop` is `RetLsWith true`. -/
def elabLoopClause (n ns : Name) (Pstx fnstx : Lean.Term) (fnText enText : String)
    (bns : Array Name) (lbl : Nat → Nat) (tupleE : Nat → TermElabM Expr) (tupleTy : Expr)
    (en : List Nat) (cls : List LoopClause) (contract : Bool) : CommandElabM Name := do
  let base := ns ++ n
  -- the forms of the obligations, over the variants with `fmul contract` under the flag
  let (edgeF, rvF, roundF, retF, retLsF, ccF) ← if contract then
      pure (← `(EdgeWith true), ← `(Valuation.roundWith true), ← `(RoundWith true),
        ← `(RetWith true), ← `(RetLsWith true), ← `(coversChainsWith true))
    else pure (← `(Edge), ← `(Valuation.round), ← `(Round), ← `(Ret), ← `(RetLs), ← `(coversChains))
  let withText := if contract then " with `fmul contract`" else ""
  let w (s : String) : String := if contract then s!"{s}With true" else s
  let one := cls.length == 1
  let b (i : Nat) : Expr := mkConst (bns.getD i .anonymous)
  let obls (i : Nat) : Expr := mkApp (mkConst ``Summary.obls) (b i)
  let loopText : String := ", then ".intercalate <| cls.map fun (_, p, _, _, _, _, hT, bT, oT) =>
    s!"the loop at {hT}, entered at position {p}, with the round `{bT}` and the path out `{oT}`"
  let chainsN ← liftTermElabM do
    let tl (q : List Nat) : TermElabM Expr := do mkListLit tupleTy (← q.tail.mapM tupleE)
    let segs ← cls.mapM fun (h, p, bk, ou, _) => do
      pure <| mkAppN (mkConst ``LoopSeg.mk) #[toExpr (lbl h), toExpr p, obls h, b h, ← tl bk,
        ← tl ou, ← mkListLit (mkConst ``LoopSeg) []]
    let ch := mkAppN (mkConst ``LoopChain.mk) #[toExpr (lbl 0), obls 0, b 0, ← tl en,
      ← mkListLit (mkConst ``LoopSeg) segs]
    kernelDef (base ++ `chains) (mkApp (mkConst ``List [Level.zero]) (mkConst ``LoopChain))
      (← mkListLit (mkConst ``LoopChain) [ch]) <| match cls with
      | [(_, p, _, _, _, _, hT, bT, oT)] => s!"The sequence of loops of `{fnText}` for the \
        loop clause of `mojo_kernel {n}` (`LoopChain`, computed by the command): the path \
        `{enText}` into the loop at {hT}, entered at position {p}, the round `{bT}` and \
        the path out `{oT}`, with the summaries `{n}.b<i>`; no loop is nested in it."
      | _ => s!"The sequence of loops of `{fnText}` for the loop clauses of `mojo_kernel {n}` \
        (`LoopChain`, computed by the command): the path `{enText}` into the first loop, then \
        {loopText}, with the summaries `{n}.b<i>`; no loop is nested in one."
  let chainsS := chainsN.replacePrefix ns .anonymous
  let ccId := mkIdent (n ++ `coversChains)
  elabCommand (← `(command|
    theorem $ccId : $ccF $Pstx $fnstx $(mkCIdent chainsN) = true := by decide +kernel))
  addDocStringCore (base ++ `coversChains) <| match cls with
    | [(_, p, _, _, _, _, _, bT, oT)] => s!"`{w "coversChains"}` accepts `{chainsS}` for \
      `{fnText}` (evaluated by the kernel): it starts at the entry block, and the path checker \
      with `phi`s{withText} accepts the path `{enText}` from position 0, and the round `{bT}` \
      and the path out `{oT}` from the header's position {p}."
    | _ => s!"`{w "coversChains"}` accepts `{chainsS}` for `{fnText}` (evaluated by the kernel): \
      it starts at the entry block, and the path checker with `phi`s{withText} accepts the path \
      `{enText}` from position 0, and each loop's round and path out from its header's \
      position."
  -- the obligations of each loop, each by its clause's tactic
  let tupS (i : Nat) : CommandElabM Lean.Term := do
    let bi := mkCIdent (bns.getD i .anonymous)
    `((($(quote (lbl i)) : Nat), Summary.obls $bi, $bi))
  let tlS (q : List Nat) : CommandElabM Lean.Term := do
    `(([$(← q.tail.toArray.mapM tupS),*] : List (Nat × List Cond × Summary)))
  let by_ := s!"by the loop clause's tactic, generated by `mojo_kernel {n}`"
  let arr := cls.toArray
  let mut left : Array String := #[]
  let mut ks : Array (Lean.Term × Lean.Term × Ident × Ident × Ident × Ident) := #[]
  -- the path into the current loop: its first block, its blocks and its text
  let mut into : Nat × List Nat × String := (0, en, enText)
  for k in [0:arr.size] do
    let (h, p, bk, ou, (preS, invS, tripsS, postS), tac?, hT, bkText, ouText) := arr[k]!
    let tac ← match tac? with
      | some t => pure t
      | none => pure (← `(tactic| decide +kernel)).raw
    let (l0i, inPath, inText) := into
    let nm (o : String) : Name := .mkSimple (if one then o else s!"{o}{h}")
    let (hq, pq, l0) := (quote (lbl h), quote p, quote (lbl l0i))
    let (b0, bh) := (mkCIdent (bns.getD l0i .anonymous), mkCIdent (bns.getD h .anonymous))
    let (E, B, X) := (← tlS inPath, ← tlS bk, ← tlS ou)
    let at_ := if one then "" else s!" at {hT}"
    let exitOb : String × String × Lean.Term ← match arr[k + 1]? with
      | none => do pure ("the path out", s!"**The path out of the loop**{at_} of `{fnText}` \
          ({by_}): from every valuation `V` of the loop clause's precondition and every \
          valuation `W` of the invariant at the trip count at `V`, the path `{ouText}` from `W` \
          runs to `ret` with a memory of the postcondition at `V` (`{w "Ret"}`).",
          ← `(∀ V : Valuation, $preS V → ∀ W : Valuation, $invS V ($tripsS V) W →
            $retF W ($postS V) (($hq, Summary.obls $bh, $bh) :: $X)))
      | some (_, _, _, _, (pre', _, _, post'), _, hT', _, _) => do pure ("the next loop's \
          precondition", s!"**From the loop{at_} to the next** of `{fnText}` ({by_}): from \
          every valuation `V` of the loop clause's precondition and every valuation `W` of the \
          invariant at the trip count at `V`, the precondition of the clause of the loop at \
          {hT'} holds at `W`, and its postcondition at `W` implies this clause's at `V`.",
          ← `(∀ V : Valuation, $preS V → ∀ W : Valuation, $invS V ($tripsS V) W →
            $pre' W ∧ ∀ me, $post' W me → $postS V me))
    let obligations : List (Name × String × String × Lean.Term) := [
      (nm "entry", "the path into the loop", s!"**The path into the loop**{at_} of `{fnText}` \
        ({by_}): from every valuation of the loop clause's precondition, the path `{inText}` has \
        its premises and its last edge enters the header at position {p} (`{w "Edge"}`).",
        ← `(∀ V : Valuation, $preS V → $edgeF $hq $pq V $l0 (Summary.obls $b0) $b0 $E)),
      (nm "init", "the invariant at round 0", s!"**The invariant at round 0** of the loop{at_} \
        of `{fnText}` ({by_}): from every valuation `V` of the loop clause's precondition, the \
        invariant at `V` holds at round 0 of the header's entry valuation after the path \
        `{inText}` (`{w "Valuation.round"}`).",
        ← `(∀ V : Valuation, $preS V → $invS V 0 ($rvF $l0 $b0 $E V))),
      (nm "step", "a round", s!"**A round** of the loop{at_} of `{fnText}` ({by_}): from every \
        valuation `V` of the loop clause's precondition, for every round `i` below the trip \
        count at `V` and every valuation `W` of the invariant at round `i`, the round \
        `{bkText}` from `W` has its premises and goes back to the header at position {p} \
        (`{w "Round"}`), and the invariant holds at round `i + 1` after it \
        (`{w "Valuation.round"}`).",
        ← `(∀ V : Valuation, $preS V → ∀ i < $tripsS V, ∀ W : Valuation, $invS V i W →
            $roundF $hq $pq (Summary.obls $bh) $bh $B W ∧
              $invS V (i + 1) ($rvF $hq $bh $B W))),
      (nm "exit", exitOb.1, exitOb.2.1, exitOb.2.2)]
    for (o, what, doc, t) in obligations do
      let closed ← liftTermElabM do
        let ty ← Term.withoutErrToSorry do
          let e ← Term.elabType t
          Term.synthesizeSyntheticMVarsNoPostponing
          instantiateMVars e
        proveBy (base ++ o) (← Core.betaReduce ty) tac
      if closed then addDocStringCore (base ++ o) doc
      else left := left.push s!"{n ++ o} ({what})"
    ks := ks.push (invS, tripsS, mkCIdent (base ++ nm "entry"), mkCIdent (base ++ nm "init"),
      mkCIdent (base ++ nm "step"), mkCIdent (base ++ nm "exit"))
    into := (h, ou, ouText)
  unless left.isEmpty do
    match cls with
    | [(_, _, _, _, _, _, hT, _, _)] => throwError "mojo_kernel: the loop clause's tactic does \
        not close {", ".intercalate left.toList} for the loop at {hT}; the command adds nothing"
    | _ => throwError "mojo_kernel: the loop clauses' tactics do not close \
        {", ".intercalate left.toList}; the command adds nothing"
  -- the thread's run through the loops
  let some (_, _, _, _, (pre1, _, _, post1), _) := cls.head? | throwError "mojo_kernel: no loop"
  let loopId := mkIdent (n ++ `loop)
  let run ← loopRun contract ks.toList (← `(V)) (← `(hV)) (← `(hQ))
  elabCommand (← `(command|
    theorem $loopId {Q : Mem → Prop} (V : Valuation) (hV : $pre1 V)
        (hQ : ∀ me, $post1 V me → Q me) :
        ∃ C ∈ $(mkCIdent chainsN), $retLsF Q C.loops V C.l C.ds C.S C.E := by
      refine ⟨_, List.mem_singleton.2 rfl, ?_⟩
      exact $run))
  let obText := if one then s!"`{n}.entry`, `{n}.init`, `{n}.step` and `{n}.exit`"
    else s!"each loop's `{n}.entry<h>`, `{n}.init<h>`, `{n}.step<h>` and `{n}.exit<h>`"
  addDocStringCore (base ++ `loop) s!"**A thread of `{fnText}` through its \
    loop{if one then "" else "s"}** (generated by `mojo_kernel {n}`): from every valuation `V` \
    of the {if one then "" else "first "}loop clause's precondition, for every predicate `Q` \
    that holds of every memory of the postcondition at `V`, the sequence of loops of \
    `{chainsS}` runs from `V` to `ret` with a memory of `Q`{withText} (`{w "RetLs"}`: \
    `{if contract then "ChainWith" else "Chain"}.loop` with the invariant and the trip count at \
    `V`, by {obText}). It covers this one kernel, at every valuation of the precondition."
  return chainsN

/-- The step of `mojo_kernel` that, with the `loop` clauses, adds the kernel theorem `n.sound_loop`
on the arguments `n.args` (constant `argsN`, the binders `binders` and their identifiers `xs`, the
arguments in parameter order `elems` with their clause, position and kind `byIdx`) and its
docstring: `Kernel.sound_entry` at `n.covers` and `n.coversChains` with the paths `pathsN` and the
chains `chainsN`, the start by `n.starts`, and each thread by `n.loop` from the first loop clause's
precondition `preS` and postcondition `postS`. Every parameter of `fn` without `byval` whose name
is a register no earlier parameter names gets a register premise in the per-thread hypothesis, and
its proof is the start's (`Grid.start_scalar` through `Kernel.sound_entry`). `one` says whether
there is one loop clause. With `contract` (`fmul contract` in the fragment) the theorem is
`Kernel.sound_entryWith (contract := true)`, with `I` not depending on the start's memory, and
the per-thread hypothesis also takes an admitted address choice and oracle and the thread's
oracle `V.ctx.oracle = oracle k`, on which a fused operation's rounding depends. -/
def elabSoundLoop (n ns : Name) (Pstx fnstx : Lean.Term) (fnText : String) (fn : Func)
    (byIdx : Array (String × Nat × Bool)) (elems : Array Lean.Term)
    (binders : Array (TSyntax ``Lean.Parser.Term.bracketedBinder)) (xs : Array Ident)
    (argsN pathsN chainsN : Name) (preS postS : Lean.Term) (one contract : Bool) :
    CommandElabM Unit := do
  let base := ns ++ n
  let short (c : Name) : Name := c.replacePrefix ns .anonymous
  let name (l : Nat) : String := s!"%{fn.names.getD l s!"{l}"}"
  let argsId := mkCIdent argsN
  let startsId := mkIdent (n ++ `starts)
  -- the parameters without `byval` that name a register no earlier parameter names: position,
  -- register and argument
  let regs : Array (Nat × Nat × Lean.Term) := (byIdx.zip elems).filterMap fun ((_, i, _), e) =>
    let p := fn.params.getD i default
    match p.byval?, p.name with
    | none, some r => if (fn.params.take i).all (·.name != some r) then some (i, r, e) else none
    | _, _ => none
  let hH ← regs.foldrM (fun (_, r, e) t => `(V.regs $(quote r) = some $e → $t))
    (← `(I k V.mem → $preS V ∧ ∀ me, $postS V me → I (k + 1) me))
  let regArgs ← regs.mapM fun (i, r, e) =>
    `((hr $(quote i) _ _ $e $(quote r) rfl rfl rfl rfl rfl fun _ => rfl))
  let loopC := mkCIdent (base ++ `loop)
  let soundLoopId := mkIdent (n ++ `sound_loop)
  let sig ← `(Kernel.Sound $Pstx $fnstx L ($argsId $xs*) m adm obs R)
  let hendT ← `(∀ m', I (volume L.grid * volume L.block) m' → racy m'.trace = false ∧
    kept m'.trace = true ∧ ∃ y, obs m' = some y ∧ R y)
  if contract then
    let run ← `((H ch oracle ha k hk V hp hw he ho hf $regArgs* hI).elim fun h1 h2 =>
      Or.inr ($loopC V h1 h2))
    let perThread ← if regs.isEmpty then `(fun ch oracle ha _ _ k hk V hp hw he ho hf _ _ hI => $run)
      else `(fun ch oracle ha _ _ k hk V hp hw he ho hf hr _ hI => $run)
    elabCommand (← `(command|
      theorem $soundLoopId {L : Launch} $binders* {m : Mem}
          {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
          {R : β → Prop} (hC : m.Closed ($argsId $xs*)) (hm : m.BytesIn m.Known)
          (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (I : Nat → Mem → Prop)
          (h0 : ∀ m₀ : Mem, (∀ b x, m.blocks b = some x → m₀.blocks b = some x) →
            m₀.trace = [] → I 0 m₀)
          (H : ∀ (ch : Nat → Nat) (oracle : Nat → Nat → Nat), adm ch oracle →
            ∀ k < volume L.grid * volume L.block, ∀ V : Valuation, V.ctx.prog = $Pstx →
            V.ctx.who = ⟨k, k / volume L.block⟩ → V.ctx.env = L.env k →
            V.ctx.oracle = oracle k → V.fn = $fnstx → $hH)
          (hend : $hendT) : $sig :=
        Kernel.sound_entryWith (contract := true) (paths := $(mkCIdent pathsN))
          (chains := $(mkCIdent chainsN)) $(mkCIdent (base ++ `covers))
          $(mkCIdent (base ++ `coversChains)) hm (fun ch oracle _ => $startsId L $xs* hC ch oracle)
          hO (fun _ => I) h0 $perThread fun _ => hend))
  else
    let run ← `((H k hk V hp hw he hf $regArgs* hI).elim fun h1 h2 => Or.inr ($loopC V h1 h2))
    let perThread ← if regs.isEmpty then `(fun k hk V hp hw he hf _ hI => $run)
      else `(fun k hk V hp hw he hf hr hI => $run)
    elabCommand (← `(command|
      theorem $soundLoopId {L : Launch} $binders* {m : Mem}
          {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
          {R : β → Prop} (hC : m.Closed ($argsId $xs*)) (hm : m.BytesIn m.Known)
          (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (I : Nat → Mem → Prop)
          (h0 : ∀ m₀ : Mem, (∀ b x, m.blocks b = some x → m₀.blocks b = some x) →
            m₀.trace = [] → I 0 m₀)
          (H : ∀ k < volume L.grid * volume L.block, ∀ V : Valuation, V.ctx.prog = $Pstx →
            V.ctx.who = ⟨k, k / volume L.block⟩ → V.ctx.env = L.env k → V.fn = $fnstx → $hH)
          (hend : $hendT) : $sig :=
        Kernel.sound_entry (paths := $(mkCIdent pathsN)) (chains := $(mkCIdent chainsN))
          $(mkCIdent (base ++ `covers)) $(mkCIdent (base ++ `coversChains)) hm
          (fun ch oracle _ => $startsId L $xs* hC ch oracle) hO I h0 $perThread hend))
  let regText := if regs.isEmpty then "" else s!", and the register of each scalar and \
    pointer parameter holding its argument ({", ".intercalate (regs.toList.map fun (i, r, _) =>
      s!"`{name r}` of parameter {i}")})"
  let entryText := if contract then s!"`Kernel.sound_entryWith (contract := true)` at \
    `{n}.covers` and `{n}.coversChains`, with `fmul contract`," else s!"`Kernel.sound_entry` at \
    `{n}.covers` and `{n}.coversChains`,"
  let oracleText := if contract then ", for every admitted address choice and oracle `oracle`, \
    with the thread's oracle `oracle k`" else ""
  addDocStringCore (base ++ `sound_loop) s!"**The kernel theorem for `{fnText}` on \
    `{short argsN}` through its loop{if one then "" else "s"}** (`Kernel.Sound`, generated by \
    `mojo_kernel {n}`): {entryText} with the \
    start by `{n}.starts` and each thread by `{n}.loop`. For every launch, block numbers, \
    scalars, memory closed for the arguments (`Mem.Closed`), admission, observation and \
    predicate, `{fnText}` is sound if the caller's pointer bytes are known (`Mem.BytesIn`), \
    the observation reads only blocks, and some invariant `I` indexed by the number of threads \
    done holds of every memory with the caller's blocks and an empty trace, each thread `k` of \
    the launch{oracleText}, from every valuation `V` with the start's facts (the program, the \
    identity `⟨k, k / volume L.block⟩`, the special registers `L.env k`{if contract then ", the \
    oracle `oracle k`" else ""} and the kernel{regText}) and \
    memory of `I k`, meets the {if one then "" else "first "}loop clause's precondition, with \
    every memory of its postcondition at `V` one of `I (k + 1)`, and `I` after all threads \
    holds only of memories whose trace has no data race, keeps the promise of \
    `!invariant.load` and has an observation meeting the predicate. It covers this one \
    kernel."

/-- The binder names of `n.sound_mat` other than the six clause names: no clause of `mat` may
have one of them as its name. -/
def matBinders : List Name :=
  [`L, `hL, `hz, `α, `t, `enc, `al, `sA, `sB, `sC, `x, `y, `mem, `hC, `hne, `hbuf, `hx, `hy,
    `hsC, `hfit, `adm, `w, `bs, `Hin, `Hout]

/-- `mojo_kernel n := P fn … mat paths chains`, the `mat` clause (a matmul kernel: three `byval`
structs, the output then the two inputs, then the `i32` sizes `m`, `n`, `K`), with paths `paths`
and sequences of loops `chains` from the clause. After the checks (the clauses as in step 1,
`clauseError`; the kernel a constant of a program without globals; six parameters, `a0`, `a1`,
`a2` `byval` of one struct of a pointer of address space `sp` and a tail with a zero value `z`,
`a3`, `a4`, `a5` of type `i32`; the clauses `reads a1, a2`, `writes a0`, `scalars a3, a4, a5`
with names other than `matBinders` and each other's; parameter `j` named `%j`; `paths` and
`chains` not empty, evaluated, since the checker's cover of an empty list is vacuous; the path
checker accepting them at the flag `contract`, evaluated; no `map2` or `loop` clause; an
error naming the reason and `fn` otherwise, before anything is added), it adds the theorems
`n.names` (parameter `j` has register name `j`, by `decide +kernel`), `n.starts` (the start on
`Mat.args z o a b m n K` succeeds, `Sym.Grid.start_ok`, proved as step 5's) and `n.sound_mat`,
`Kernel.sound_mat` at `fn` with every premise that depends only on the program discharged; the
threads' runs `Hin` and `Hout` stay its premises. If one of the three does not elaborate, the
command restores the environment, so it adds nothing. -/
unsafe def elabMat (stx : Syntax) : CommandElabM Unit := do
  let n := stx[1].getId
  let base := (← getCurrNamespace) ++ n
  let Pstx : Lean.Term := ⟨stx[3]⟩
  let fnstx : Lean.Term := ⟨stx[4]⟩
  let fnText := toString fnstx.raw.prettyPrint
  let rd ← clausesOf stx[5]
  let wr ← clausesOf stx[6]
  let scalars ← clausesOf stx[7]
  let ptrs ← clausesOf stx[8]
  let (P, fn, fnC?) ← liftTermElabM do
    let Pe ← Term.elabTermEnsuringType Pstx (mkConst ``Program)
    let fne ← Term.elabTermEnsuringType fnstx (mkConst ``Func)
    Term.synthesizeSyntheticMVarsNoPostponing
    let Pe ← instantiateMVars Pe
    let fne ← instantiateMVars fne
    pure (← evalExpr Program (mkConst ``Program) Pe, ← evalExpr Func (mkConst ``Func) fne,
      fne.consumeMData.constName?)
  if let some e := clauseError fn.params (rd ++ wr) scalars ptrs then
    throwError "mojo_kernel: {e} ({fnText})"
  let contract := !stx[10].isNone
  unless stx[9].isNone && stx[11].getArgs.isEmpty do
    throwError "mojo_kernel: mat is not combined with map2 or loop ({fnText})"
  let some fnC := fnC? | throwError "mojo_kernel: mat needs the kernel as a constant; {fnText} \
    does not elaborate to one"
  unless P.module.globals.isEmpty do
    throwError "mojo_kernel: mat needs a program without globals; \
      {toString Pstx.raw.prettyPrint} has {P.module.globals.toList.map (s!"@{·.name}")} \
      ({fnText})"
  unless fn.params.length == 6 do
    throwError "mojo_kernel: mat needs a kernel of six parameters, three byval structs then \
      three i32s; {fnText} has {fn.params.length}"
  unless wr.map (·.2) == [0] && rd.map (·.2) == [1, 2] && scalars.map (·.2) == [3, 4, 5] &&
      ptrs.isEmpty do
    throwError "mojo_kernel: mat needs reads a1, a2, writes a0 and scalars a3, a4, a5 \
      ({fnText})"
  unless (fn.params.drop 3).all (·.ty == .int 32) do
    throwError "mojo_kernel: mat needs a3, a4 and a5 of type i32 ({fnText})"
  let T ← match (fn.params.take 3).map (·.byval?) with
    | [some T, some T', some T''] =>
      if T == T' && T == T'' then pure T
      else throwError "mojo_kernel: mat needs a0, a1 and a2 byval of one type ({fnText})"
    | _ => throwError "mojo_kernel: mat needs a0, a1 and a2 byval ({fnText})"
  let (sp, z) ← match T with
    | .struct [.ptr sp, u] => match P.layout.zero u with
      | some z => pure (sp, z)
      | none => throwError "mojo_kernel: mat: the struct's tail has no zero value ({fnText})"
    | _ => throwError "mojo_kernel: mat needs a struct of a pointer and a tail ({fnText})"
  unless (List.range 6).all fun j => (fn.params[j]?.bind Param.name) == some j do
    throwError "mojo_kernel: mat needs parameter j named %j, for each j ({fnText})"
  let xsN := (wr ++ rd ++ scalars).map (·.1)
  if let some x := xsN.find? fun x => matBinders.contains (.mkSimple x) then
    throwError "mojo_kernel: mat: the clause name {x} is a binder name of {n}.sound_mat \
      ({fnText})"
  unless xsN.eraseDups.length == xsN.length do
    throwError "mojo_kernel: mat: two clauses have one name ({fnText})"
  let pathsStx : Lean.Term := ⟨stx[12][1]⟩
  let chainsStx : Lean.Term := ⟨stx[12][2]⟩
  -- no empty list, evaluated before the path checker: the checker's cover of no path is vacuous,
  -- and the theorem would then cover only launches with no thread on that side
  let scope0 := (← get).nextMacroScope
  let (noP, noC) ← liftTermElabM <| Term.withoutErrToSorry do
    let e ← Term.elabTermEnsuringType (← `(List.isEmpty
      ($pathsStx : List (List (Nat × List MojoProof.Sym.Cond × MojoProof.Sym.Summary)))))
      (mkConst ``Bool)
    let c ← Term.elabTermEnsuringType
      (← `(List.isEmpty ($chainsStx : List MojoProof.Sym.LoopChain))) (mkConst ``Bool)
    Term.synthesizeSyntheticMVarsNoPostponing
    pure (← evalExpr Bool (mkConst ``Bool) (← instantiateMVars e),
      ← evalExpr Bool (mkConst ``Bool) (← instantiateMVars c))
  -- the check keeps none of its names (two Booleans), so its macro scopes are reused: the
  -- theorem's hygienic binder names are those it has without the check
  modify fun s => { s with nextMacroScope := scope0 }
  if noP then
    throwError "mojo_kernel: mat needs a path; with no paths the theorem covers only launches \
      with no thread out of bounds ({fnText})"
  if noC then
    throwError "mojo_kernel: mat needs a chain; with no chains the theorem covers only launches \
      with no thread in bounds ({fnText})"
  -- the paths and the chains, by the path checker, evaluated
  let cq : Lean.Term := quote contract
  let (okE, okC) ← liftTermElabM <| Term.withoutErrToSorry do
    let e ← Term.elabTermEnsuringType (← `(coversEntryWith $cq $Pstx $fnstx $pathsStx))
      (mkConst ``Bool)
    let c ← Term.elabTermEnsuringType (← `(coversChainsWith $cq $Pstx $fnstx $chainsStx))
      (mkConst ``Bool)
    Term.synthesizeSyntheticMVarsNoPostponing
    pure (← evalExpr Bool (mkConst ``Bool) (← instantiateMVars e),
      ← evalExpr Bool (mkConst ``Bool) (← instantiateMVars c))
  unless okE do
    throwError "mojo_kernel: mat: the path checker does not accept the paths \
      (coversEntryWith {contract}, {fnText})"
  unless okC do
    throwError "mojo_kernel: mat: the path checker does not accept the chains \
      (coversChainsWith {contract}, {fnText})"
  -- everything below is added after the checks; if `n.sound_mat` does not elaborate, the
  -- environment is restored
  let env0 ← getEnv
  try
    let fnId : Ident := mkCIdent fnC
    let namesId := mkIdent (n ++ `names)
    elabCommand (← `(command|
      theorem $namesId : ∀ j (p : Param), ($fnstx).params[j]? = some p → p.name = some j := by
        intro j p h
        have hall : (List.range ($fnstx).params.length).all
            (fun j => (($fnstx).params[j]?.bind Param.name) == some j) = true := by
          decide +kernel
        have := List.all_eq_true.1 hall j (List.mem_range.2 (List.getElem?_eq_some_iff.1 h).1)
        rw [h] at this
        simpa using this))
    addDocStringCore (base ++ `names) s!"Parameter `j` of `{fnText}`, for each of its six \
      parameters, has the register name `j` (by `decide +kernel`, generated by \
      `mojo_kernel {n}`)."
    let xs : Array Ident := (xsN.map fun x => mkIdent (.mkSimple x)).toArray
    let binders ← xs.mapM fun x => `(bracketedBinder| ($x : Nat))
    let zt ← valTerm z
    let startsId := mkIdent (n ++ `starts)
    let sealed := (← getReducibilityStatus ``Array.anyM.loop) matches .irreducible
    let unsealIn (c : TSyntax `command) : CommandElabM (TSyntax `command) :=
      if sealed then `(command| unseal Array.anyM.loop in $c:command) else pure c
    elabCommand (← unsealIn (← `(command|
      theorem $startsId (L : Launch) $binders* {mem : Mem} (hC : mem.Closed (Mat.args $zt $xs*))
          (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
          ∃ g c, Sem.Grid.start $Pstx $fnstx L (Mat.args $zt $xs*) mem ch oracle = .ok (g, c) := by
        refine Sym.Grid.start_ok ch oracle rfl hC
          (fun g hg => by rw [show ($Pstx).module.globals.toList = [] from rfl] at hg; cases hg)
          (fun p v hpv t ht => ?_) (fun p v hpv hnb m' => ?_) (by decide +kernel)
        all_goals
          simp only [Mat.args, $fnId:ident, List.zip_cons_cons, List.zip_nil_left,
            List.mem_cons, Prod.mk.injEq, List.not_mem_nil] at hpv
          repeat' rcases hpv with ⟨hp, hv⟩ | hpv
        all_goals subst_vars
        all_goals first
          | exact ⟨_, rfl⟩
          | simp at hnb
          | (simp at ht; subst ht; rfl)
          | simp at ht)))
    addDocStringCore (base ++ `starts) s!"`{fnText}` starts on `Mat.args` (Sem/Precond.lean) at \
      the zero tail of its structs, for every launch, block numbers `{xsN[0]!}`, `{xsN[1]!}`, \
      `{xsN[2]!}`, sizes `{xsN[3]!}`, `{xsN[4]!}`, `{xsN[5]!}`, memory closed for the arguments \
      (`Mem.Closed`, the one premise), address choice and oracle (`Sym.Grid.start_ok`, generated \
      by `mojo_kernel {n}`). It covers this one kernel."
    let some [L, hL, hz, α, t, enc, al, sA, sB, sC, x, y, mem, hC, hne, hbuf, hx, hy, hsC, hfit,
        adm, w, bs, Hin, Hout] := some (matBinders.map mkIdent) | throwError "unreachable"
    let some [xo, xa, xb, xm, xn, xK] := some xs.toList | throwError "unreachable"
    let alq := quote (P.layout.align T)
    let spq := quote sp
    let startsC := mkCIdent (base ++ `starts)
    let namesC := mkCIdent (base ++ `names)
    liftTermElabM <| Term.withoutErrToSorry do
      let Tt ← Term.exprToSyntax (toExpr T)
      let body ← `(fun {$L : Launch} ($hL : Launch.Valid $L)
          ($hz : Launch.grid $L .z = 1 ∧ Launch.block $L .z = 1) {$xo $xa $xb $xm $xn $xK : Nat}
          {$α : Type} [TorchLean.Storage $α] {$t : Ty} {$enc : $α → Val} {$al $sA $sB $sC : Nat}
          {$x : TorchLean.Tensor $α [$xm, $sA]} {$y : TorchLean.Tensor $α [$xn, $sB]} {$mem : Mem}
          $hC:ident $hne:ident $hbuf:ident $hx:ident $hy:ident $hsC:ident $hfit:ident
          {$adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {$w : Nat}
          {$bs : Nat → Option (List MemByte)} $Hin:ident $Hout:ident =>
        Kernel.sound_mat (contract := $cq) (prog := $Pstx) (fn := $fnstx) (paths := $pathsStx)
          (chains := $chainsStx) (T := $Tt) (z := $zt) (al' := $alq) (m := $xm) (n := $xn)
          (K := $xK) (t := $t) (enc := $enc) (al := $al) (o := $xo) (a := $xa) (b := $xb)
          (sA := $sA) (sB := $sB) (sC := $sC) (x := $x) (y := $y) (mem := $mem) (adm := $adm)
          (w := $w) (bs := $bs) $hL $hz (by decide +kernel) (by decide +kernel) rfl $namesC
          ⟨rfl, rfl, rfl⟩ ⟨rfl, rfl, rfl⟩
          (Layout.Codec.ptrArg _ $spq (by decide +kernel) (by decide +kernel) rfl rfl rfl)
          ⟨by decide, by decide⟩ (fun _ => ⟨rfl, rfl, rfl⟩) $hC $hne $hbuf $hx $hy $hsC $hfit
          (fun ch oracle _ => $startsC $L $xo $xa $xb $xm $xn $xK $hC ch oracle) $Hin $Hout)
      let e ← Term.elabTerm body none
      Term.synthesizeSyntheticMVarsNoPostponing
      let e ← instantiateMVars e
      let ty ← instantiateMVars (← inferType e)
      if e.hasSorry || e.hasExprMVar || ty.hasExprMVar then
        throwError "mojo_kernel: mat: {n}.sound_mat does not elaborate ({fnText})"
      addDecl <| .thmDecl { name := base ++ `sound_mat, levelParams := [], type := ty, value := e }
    addDocStringCore (base ++ `sound_mat) s!"**The kernel theorem of `{fnText}` from its \
      threads' runs** (generated by `mojo_kernel {n}`): `Kernel.sound_mat` \
      {if contract then "(contract := true) " else ""}at `{fnText}` with every premise that \
      depends only on the program discharged (the paths and the chains of the `mat` clause by \
      `decide +kernel`, the parameters and their `byval` types by `rfl`, the names by \
      `{n}.names`, the codec of the struct by `Layout.Codec.ptrArg`, the `withAttrs` of the \
      sizes by `rfl`, the start by `{n}.starts`). For every launch valid with `z` sides 1, block \
      numbers `{xsN[0]!}` (output), `{xsN[1]!}`, `{xsN[2]!}` (inputs), sizes `{xsN[3]!}`, \
      `{xsN[4]!}`, `{xsN[5]!}`, element type, encoder, alignment, row strides, tensors and \
      caller's memory with the memory premises of `Kernel.sound_mat`, admission, cell width and \
      bytes: if `Hin` (a thread in bounds runs some sequence of loops of the clause to `ret`) \
      and `Hout` (a thread out of bounds takes some path of the clause to `ret`) hold, \
      `{fnText}` is sound on `Mat.args` (`Kernel.Sound`) for the observation of the blocks and \
      `Elem.Out` at the 2-D cells. It covers this one kernel; `Hin` and `Hout` are the user's."
  catch e =>
    setEnv env0
    throw e

/-- Elaborates `mojo_kernel` without the `mat` clause; `unsafe` because it evaluates the program
and the summaries. -/
unsafe def elabMojoKernel : CommandElab := fun stx => do
  let n := stx[1].getId
  let ns ← getCurrNamespace
  let base := ns ++ n
  let short (c : Name) : Name := c.replacePrefix ns .anonymous
  let Pstx : Lean.Term := ⟨stx[3]⟩
  let fnstx : Lean.Term := ⟨stx[4]⟩
  let fnText := toString fnstx.raw.prettyPrint
  let bufs := (← clausesOf stx[5]) ++ (← clausesOf stx[6])
  let scalars ← clausesOf stx[7]
  let ptrs ← clausesOf stx[8]
  let (P, fn, fnC?) ← liftTermElabM do
    let Pe ← Term.elabTermEnsuringType Pstx (mkConst ``Program)
    let fne ← Term.elabTermEnsuringType fnstx (mkConst ``Func)
    Term.synthesizeSyntheticMVarsNoPostponing
    let Pe ← instantiateMVars Pe
    let fne ← instantiateMVars fne
    pure (← evalExpr Program (mkConst ``Program) Pe, ← evalExpr Func (mkConst ``Func) fne,
      fne.consumeMData.constName?)
  -- 1. the clauses, and the flag `contract` not with `map2` (`Kernel.sound_map2` has no variant
  -- with the flag)
  if let some e := clauseError fn.params bufs scalars ptrs then
    throwError "mojo_kernel: {e} ({fnText})"
  let contract := !stx[10].isNone
  let loopStxs := stx[11].getArgs.toList
  if contract && !stx[9].isNone then
    throwError "mojo_kernel: contract is not combined with map2 ({fnText})"
  -- 2. the summaries (added after every check, so that a refused command adds nothing), with
  -- `fmul contract` in the fragment under the flag
  let name (l : Nat) : String := s!"%{fn.names.getD l s!"{l}"}"
  let mut sums : Array Summary := #[]
  for b in fn.blocks do
    let l := b.label
    match if contract then summarizeC P fn l (phiCount fn l) else summarize P fn l (phiCount fn l)
      with
    | none => throwError "mojo_kernel: block {name l} (block {sums.size} of {fnText}) is \
        outside the checker's fragment{if contract then " with fmul contract" else ""}"
    | some S => sums := sums.push S
  -- 3. the paths, and with the `loop` clause the loop's paths
  let idx (l : Nat) : Nat := (fn.blocks.findIdx? (·.label == l)).getD fn.blocks.size
  let exits : Array Exit := sums.map Summary.exit
  let succ (i : Nat) : List Nat := (exits.getD i .ret).succs.map idx
  let lbl (i : Nat) : Nat := (fn.blocks.getD i default).label
  let blk (i : Nat) : String := s!"block {name (lbl i)} (block {i} of {fnText})"
  let hdrs ← loopStxs.mapM fun g => match g[1].isNatLit? with
    | some h =>
      if 0 < h && h < fn.blocks.size then pure h
      else throwErrorAt g[1] "mojo_kernel: the loop clause's header {h} is not a block of \
        {fnText} other than its entry block 0 (it has {fn.blocks.size} blocks)"
    | none => throwErrorAt g[1] "mojo_kernel: the loop clause's header is not a number"
  let hdrsText := ", ".intercalate (hdrs.map blk)
  let segs (i : Nat) : CommandElabM (List (List Nat × Option Nat)) :=
    match kernelSegs succ (hdrs.contains ·) (fn.blocks.size + 1) [] i, hdrs with
    | .ok ss, _ => pure ss
    | .error j, [] => throwError "mojo_kernel: loop at {blk j} with no loop clause; give its \
        precondition, invariant, trip count and postcondition by loop {j} := pre inv trips post"
    | .error j, [h] => throwError "mojo_kernel: loop at {blk j}, not at the loop clause's \
        header {blk h}; the clause covers one loop, with no loop in it or after it"
    | .error j, _ => throwError "mojo_kernel: loop at {blk j}, not at a loop clause's header \
        ({hdrsText}); the clauses cover loops in sequence, with no loop in one"
  let es ← segs 0
  let ps := es.filterMap fun (p, e) => if e.isNone then some p else none
  -- with loop clauses: the path into the first loop, and each loop's round and path out
  let ins := es.filterMap fun (p, e) => if e.isSome then some (p, e) else none
  let need := "mojo_kernel: the loop clauses need one path from the entry block to a loop, into \
    the first clause's loop, and for each loop one round and one path out, into the next \
    clause's loop or, after the last, to a ret;"
  let en? ← match hdrs, ins with
    | [], _ => pure none
    | [_], [(en, _)] => pure (some en)
    | [_], _ => pure none
    | h :: _, [(en, e)] => if e == some h then pure (some en) else throwError "{need} the entry \
        block's path to a loop is not into the loop at {blk h}"
    | _ :: _, _ => throwError "{need} the entry block has {ins.length} paths to a loop"
  let mut loops : Array (Nat × List Nat × List Nat) := #[]
  for (h, k) in hdrs.zipIdx do
    let hs ← segs h
    let next := hdrs[k + 1]?
    let rounds := hs.filterMap fun (p, e) => if e == some h then some p else none
    let outs := hs.filterMap fun (p, e) => if e != some h then some (p, e) else none
    match hdrs, en?, rounds, outs with
    | [_], some _, [bk], [(ou, _)] => loops := loops.push (h, bk, ou)
    | [_], _, _, _ => throwError "mojo_kernel: the loop clause needs one path into the loop at \
        {blk h}, one round and one path out; it has {ins.length} paths into it, \
        {rounds.length} rounds and {outs.length} paths out"
    | _, _, [bk], [(ou, e)] =>
      if e == next then loops := loops.push (h, bk, ou)
      else throwError "{need} the loop at {blk h}'s path out is not \
        {match next with | some h' => s!"into the loop at {blk h'}" | none => "to a ret"}"
    | _, _, _, _ => throwError "{need} the loop at {blk h} has {rounds.length} rounds and \
        {outs.length} paths out"
  -- the prerequisites of the `loop` clauses, checked before anything is added: the path checker
  -- accepts the loops' paths, and their terms have their types
  let tup (i : Nat) : Nat × List Cond × Summary :=
    (lbl i, (sums.getD i default).obls, sums.getD i default)
  let terms (g : Syntax) : Lean.Term × Lean.Term × Lean.Term × Lean.Term :=
    (⟨g[3]⟩, ⟨g[4]⟩, ⟨g[5]⟩, ⟨g[6]⟩)
  if let some en := en? then
    let C : LoopChain := ⟨lbl 0, (tup 0).2.1, (tup 0).2.2, en.tail.map tup,
      loops.toList.map fun (h, bk, ou) => ⟨lbl h, phiCount fn (lbl h), (tup h).2.1, (tup h).2.2,
        bk.tail.map tup, ou.tail.map tup, []⟩⟩
    unless coversChainsWith contract P fn [C] do
      throwError "mojo_kernel: the path checker does not accept the paths of the loop\
        {if hdrs.length == 1 then "" else "s"} at {hdrsText} \
        ({if contract then "coversChainsWith true" else "coversChains"})"
    for g in loopStxs do
      let (preS, invS, tripsS, postS) := terms g
      liftTermElabM <| Term.withoutErrToSorry do
        let _ ← Term.elabTerm (← `((($preS : Valuation → Prop),
          ($invS : Valuation → Nat → Valuation → Prop), ($tripsS : Valuation → Nat),
          ($postS : Valuation → Mem → Prop)))) none
        Term.synthesizeSyntheticMVarsNoPostponing
  -- the prerequisites of the `map2` clause, checked before anything is added, so that a refused
  -- command declares nothing
  let map2? ← if stx[9].isNone then pure none else do
    let some _ := fnC? | throwError "mojo_kernel: map2 needs the kernel as a constant; {fnText} \
      does not elaborate to one"
    unless hdrs.isEmpty do throwError "mojo_kernel: map2 needs a kernel without a loop ({fnText})"
    unless P.module.globals.isEmpty do
      throwError "mojo_kernel: map2 needs a program without globals; \
        {toString Pstx.raw.prettyPrint} has {P.module.globals.toList.map (s!"@{·.name}")} \
        ({fnText})"
    let rd ← clausesOf stx[5]
    let wr ← clausesOf stx[6]
    unless rd.map (·.2) == [0, 1] && wr.map (·.2) == [2] && scalars.map (·.2) == [3] &&
        fn.params.length == 4 && (fn.params.getD 3 default).ty == .int 32 do
      throwError "mojo_kernel: map2 needs reads a0, a1, writes a2, scalars a3, an i32 ({fnText})"
    let T ← match (fn.params.take 3).map (·.byval?) with
      | [some T, some T', some T''] =>
        if T == T' && T == T'' then pure T
        else throwError "mojo_kernel: map2 needs a0, a1 and a2 byval of one type ({fnText})"
      | _ => throwError "mojo_kernel: map2 needs a0, a1 and a2 byval ({fnText})"
    let (sp, z) ← match T with
      | .struct [.ptr sp, u] => match P.layout.zero u with
        | some z => pure (sp, z)
        | none => throwError "mojo_kernel: map2: the struct's tail has no zero value ({fnText})"
      | _ => throwError "mojo_kernel: map2 needs a struct of a pointer and a tail ({fnText})"
    let tstx : Lean.Term := ⟨stx[9][1]⟩
    let t ← liftTermElabM do
      let e ← Term.elabTermEnsuringType tstx (mkConst ``Ty)
      Term.synthesizeSyntheticMVarsNoPostponing
      evalExpr Ty (mkConst ``Ty) (← instantiateMVars e)
    pure (some (rd, wr, T, sp, z, t))
  -- everything below is added after the checks; a loop clause whose discharger leaves an
  -- obligation restores this environment, so that a refused command adds nothing
  let env0 ← getEnv
  let mut bns : Array Name := #[]
  for i in [0:sums.size] do
    let l := (fn.blocks.getD i default).label
    bns := bns.push (← liftCoreM <| kernelDef (base ++ .mkSimple s!"b{i}")
      (mkConst ``Summary) (toExpr sums[i]!) s!"The summary of block `{name l}` (block {i}) of \
        `{fnText}`, from after its `phi`s ({if contract then "`summarizeC`, with `fmul contract` \
        in the fragment," else "`summarize`"} at `phiCount`, computed by `mojo_kernel`).")
  let pathText (p : List Nat) : String := " → ".intercalate (p.map fun i => name (lbl i))
  let pathsText (ps : List (List Nat)) : String :=
    if ps.isEmpty then "none" else ", ".intercalate (ps.map (s!"`{pathText ·}`"))
  let tupleE (i : Nat) : TermElabM Expr := do
    let b := mkConst (bns.getD i .anonymous)
    mkAppM ``Prod.mk #[toExpr (lbl i), ← mkAppM ``Prod.mk #[mkApp (mkConst ``Summary.obls) b, b]]
  let tupleTy := mkApp2 (mkConst ``Prod [Level.zero, Level.zero]) (mkConst ``Nat)
    (mkApp2 (mkConst ``Prod [Level.zero, Level.zero]) (mkApp (mkConst ``List [Level.zero])
      (mkConst ``Cond)) (mkConst ``Summary))
  let notIn := match hdrs with
    | [] => "" | [_] => " that do not enter its loop" | _ => " that do not enter its loops"
  let pathsN ← liftTermElabM do
    let pathTy := mkApp (mkConst ``List [Level.zero]) tupleTy
    let pes ← ps.mapM fun p => do mkListLit tupleTy (← p.mapM tupleE)
    kernelDef (base ++ `paths) (mkApp (mkConst ``List [Level.zero]) pathTy)
      (← mkListLit pathTy pes) s!"The paths of `{fnText}` from its entry block to `ret`\
        {notIn}, computed by \
        `mojo_kernel`: {pathsText ps}."
  let coversId := mkIdent (n ++ `covers)
  let coversT ← if contract then `(coversEntryWith true $Pstx $fnstx $(mkCIdent pathsN))
    else `(coversEntry $Pstx $fnstx $(mkCIdent pathsN))
  elabCommand (← `(command| theorem $coversId : $coversT = true := by decide +kernel))
  addDocStringCore (base ++ `covers) s!"The paths `{short pathsN}` start at the entry block of \
    `{fnText}` and are accepted by the path checker with `phi`s from position 0 \
    ({if contract then "`coversEntryWith true`, with `fmul contract`" else "`coversEntry`"}, \
    evaluated by the kernel)."
  -- 3'. the loop: its chain, the obligations by the discharger, the thread's run through it
  let chainsN? ← match en? with
    | none => pure none
    | some en => do
      let pt (q : List Nat) : String := pathText q
      let cls : List LoopClause := (loopStxs.zip loops.toList).map fun (g, h, bk, ou) =>
        (h, phiCount fn (lbl h), bk, ou, terms g, if g[7].isNone then none else some g[7][1],
          blk h, pt bk, pt ou)
      try
        some <$> elabLoopClause n ns Pstx fnstx fnText (pathText en) bns lbl tupleE tupleTy en cls
          contract
      catch e =>
        setEnv env0
        throw e
  -- 4. the kernel theorem from the remaining premises
  let soundN := base ++ `sound_of
  liftTermElabM do
    let thm ← match chainsN? with
      | none =>
        if contract then `(@Kernel.sound_of_chainsWith true $Pstx $fnstx L args m adm β obs R
          $(mkCIdent pathsN) [] $(mkCIdent (base ++ `covers)) rfl)
        else `(@Kernel.sound_of_paths $Pstx $fnstx L args m adm β obs R $(mkCIdent pathsN)
          $(mkCIdent (base ++ `covers)))
      | some chainsN =>
        if contract then `(@Kernel.sound_of_chainsWith true $Pstx $fnstx L args m adm β obs R
          $(mkCIdent pathsN) $(mkCIdent chainsN) $(mkCIdent (base ++ `covers))
          $(mkCIdent (base ++ `coversChains)))
        else `(@Kernel.sound_of_chains $Pstx $fnstx L args m adm β obs R
          $(mkCIdent pathsN) $(mkCIdent chainsN) $(mkCIdent (base ++ `covers))
          $(mkCIdent (base ++ `coversChains)))
    let e ← Term.elabTerm (← `(fun {L : Launch} {args : List Val} {m : Mem}
        {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
        {R : β → Prop} => $thm)) none
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars e
    addDecl <| .thmDecl { name := soundN, levelParams := [], type := ← inferType e, value := e }
  let alongText := match chainsN? with
    | none => if contract then s!"along some path of `{short pathsN}` that is a `RetWith true`, \
        with `fmul contract`" else s!"along some path of `{short pathsN}` that is a `Ret`"
    | some chainsN =>
      if contract then s!"along some path of `{short pathsN}` that is a `RetWith true` or \
        through some sequence of loops of `{short chainsN}` to `ret` (`RetLsWith true`), with \
        `fmul contract`"
      else s!"along some path of `{short pathsN}` that is a `Ret` or through some \
        sequence of loops of `{short chainsN}` to `ret` (`RetLs`)"
  addDocStringCore soundN s!"The kernel theorem for `{fnText}` (`Kernel.Sound`) from its paths, \
    generated by `mojo_kernel {n}`: \
    {if chainsN?.isSome then s!"`Kernel.sound_of_chains{if contract then "With" else ""}` \
      {if contract then "(contract := true) " else ""}at `{n}.covers` and \
      `{n}.coversChains`" else if contract then s!"`Kernel.sound_of_chainsWith \
      (contract := true)` at `{n}.covers` and no sequence of loops" else
      s!"`Kernel.sound_of_paths` at `{n}.covers`"}. For every launch, \
    arguments, memory, admission, observation and predicate, `{fnText}` is sound if the caller's \
    pointer bytes are known (`Mem.BytesIn`), the start succeeds on every admitted address choice \
    and oracle, the observation reads only blocks, and on each start some invariant indexed by \
    the number of threads done holds of the start's memory, is kept by each thread \
    {alongText}, and holds at the end only of memories whose trace has no data race, keeps the \
    promise of `!invariant.load` and has an observation meeting the predicate. It covers this \
    one kernel; every premise is the caller's."
  -- 5. the arguments from the clauses, the start on them, and the kernel theorem from `Mem.Closed`
  let some fnC := fnC? | return
  unless P.module.globals.isEmpty do return
  let fnId : Ident := mkCIdent fnC
  -- a buffer's and a pointer's binder is a block number, a scalar's a bit vector
  let cls := (bufs ++ ptrs).map (fun (x, i) => (x, i, true)) ++
    scalars.map fun (x, i) => (x, i, false)
  let byIdx := ((List.range fn.params.length).filterMap fun i => cls.find? (·.2.1 == i)).toArray
  let xs : Array Ident := byIdx.map fun (x, _, _) => mkIdent (.mkSimple x)
  let mut binders : Array (TSyntax ``Lean.Parser.Term.bracketedBinder) := #[]
  let mut elems : Array Lean.Term := #[]
  for (x, i, isBuf) in byIdx do
    let xi := mkIdent (.mkSimple x)
    if isBuf then
      binders := binders.push (← `(bracketedBinder| ($xi : Nat)))
      match (fn.params.getD i default).attrs.findSome? (fun a : Attr => match a with
          | .ty "byval" t => some t | _ => none) with
      | some (.struct (_ :: ts)) =>
        let es := #[← `(Val.ptr ⟨$xi, 0⟩)] ++
          (← ts.toArray.mapM fun t => valTerm ((P.layout.zero t).getD .undef))
        elems := elems.push (← `(Val.agg [$es,*]))
      -- a `pointers` parameter, with no `byval`: its argument is the pointer itself
      | _ => elems := elems.push (← `(Val.ptr ⟨$xi, 0⟩))
    else
      let w := match (fn.params.getD i default).ty with | .int w => w | _ => 0
      binders := binders.push (← `(bracketedBinder| ($xi : BitVec $(quote w))))
      elems := elems.push (← `(Val.bits $(quote w) $xi))
  let lams (t : Lean.Term) : CommandElabM Lean.Term :=
    byIdx.foldrM (init := t) fun (x, i, isBuf) t => do
      let xi := mkIdent (.mkSimple x)
      let w := match (fn.params.getD i default).ty with | .int w => w | _ => 0
      if isBuf then `(fun ($xi : Nat) => $t) else `(fun ($xi : BitVec $(quote w)) => $t)
  let ptrText := if ptrs.isEmpty then "" else "a pointer parameter's pointer to offset 0 of a \
    block number, "
  let argsN ← kernelDefOf (base ++ `args) (← lams (← `(([$elems,*] : List Val))))
    s!"The arguments of `{fnText}` from the clauses of `mojo_kernel {n}`, in parameter order: a \
      buffer's `byval` struct with a pointer to offset 0 of a block number and the zero value of \
      every other field, {ptrText}a scalar as a bit vector."
  let argsId := mkCIdent argsN
  let startsId := mkIdent (n ++ `starts)
  -- the proof needs `Array.anyM.loop` (a well-founded recursion) unsealed; `unseal` fails on a
  -- constant the module has already unsealed, so it is added only when the constant is sealed
  let sealed := (← getReducibilityStatus ``Array.anyM.loop) matches .irreducible
  let unsealIn (c : TSyntax `command) : CommandElabM (TSyntax `command) :=
    if sealed then `(command| unseal Array.anyM.loop in $c:command) else pure c
  elabCommand (← unsealIn (← `(command|
    theorem $startsId (L : Launch) $binders* {m : Mem} (hC : m.Closed ($argsId $xs*))
        (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
        ∃ g c, Sem.Grid.start $Pstx $fnstx L ($argsId $xs*) m ch oracle = .ok (g, c) := by
      refine Sym.Grid.start_ok ch oracle rfl hC
        (fun g hg => by rw [show ($Pstx).module.globals.toList = [] from rfl] at hg; cases hg)
        (fun p v hpv t ht => ?_) (fun p v hpv hnb m' => ?_) (by decide +kernel)
      all_goals
        simp only [$argsId:ident, $fnId:ident, List.zip_cons_cons, List.zip_nil_left,
          List.mem_cons, Prod.mk.injEq, List.not_mem_nil] at hpv
        repeat' rcases hpv with ⟨hp, hv⟩ | hpv
      all_goals try subst_vars
      all_goals first
        | exact ⟨_, rfl⟩
        | (simp at hnb; done)
        | (simp at ht; done)
        | (simp at ht; subst ht; rfl))))
  addDocStringCore (base ++ `starts) s!"`{fnText}` starts on `{short argsN}` for every launch, \
    block numbers, scalars, memory closed for the arguments (`Mem.Closed`, the one premise), \
    address choice and oracle (`Sym.Grid.start_ok`, generated by `mojo_kernel {n}`). It covers \
    this one kernel."
  let body ← lams (← `(fun {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
      {β : Type} {obs : Mem → Option β} {R : β → Prop} (hC : Mem.Closed m ($argsId $xs*))
      (hm : Mem.BytesIn (Mem.Known m) m) => @$(mkCIdent soundN) L ($argsId $xs*) m adm β obs R hm
        fun ch oracle _ => $startsId L $xs* hC ch oracle))
  let body ← `(fun {L : Launch} => $body)
  liftTermElabM do
    let e ← Term.elabTerm body none
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars e
    addDecl <| .thmDecl
      { name := base ++ `sound, levelParams := [], type := ← inferType e, value := e }
  addDocStringCore (base ++ `sound) s!"The kernel theorem for `{fnText}` on `{short argsN}` \
    (`Kernel.Sound`), generated by `mojo_kernel {n}`, for every launch, block numbers, scalars, \
    memory closed for the arguments (`Mem.Closed`), admission, observation and predicate: \
    `{n}.sound_of` with the start by `{n}.starts`. Its premises are `Mem.Closed`, the pointer \
    bytes (`Mem.BytesIn`), the observation reading only blocks, and the invariant \
    {if chainsN?.isSome then "of each thread" else s!"along `{short pathsN}`"} as in \
    `{n}.sound_of`. It covers this one kernel."
  -- 5'. with the loop clauses: the kernel theorem on `n.args` from `Mem.Closed`, each thread by
  -- `n.loop` from the start's facts, among them the registers of the scalars and pointers
  if let (some chainsN, g :: _) := (chainsN?, loopStxs) then
    let (preS, _, _, postS) := terms g
    elabSoundLoop n ns Pstx fnstx fnText fn byIdx elems binders xs argsN pathsN chainsN preS postS
      (hdrs.length == 1) contract
  -- 6. a binary elementwise kernel: the struct type and tail, each thread's `Ret`, the theorem
  let some (rd, wr, T, sp, z, t) := map2? | return
  let tstx : Lean.Term := ⟨stx[9][1]⟩
  let encstx : Lean.Term := ⟨stx[9][2]⟩
  let bytesstx : Lean.Term := ⟨stx[9][3]⟩
  let argTyN ← liftCoreM <| kernelDef (base ++ `argTy) (mkConst ``Ty) (toExpr T)
    s!"The type of the `byval` parameters `a0` to `a2` of `{fnText}`: a struct of a pointer and a \
      tail (generated by `mojo_kernel {n}`)."
  let argTailN ← kernelDefOf (base ++ `argTail) (← `(($(← valTerm z) : Val)))
    s!"The zero tail of a struct of type `{short argTyN}`, as in `{short argsN}` (generated by \
      `mojo_kernel {n}`)."
  let argTyId := mkCIdent argTyN
  let argTailId := mkCIdent argTailN
  let (xa, xb, xo, xn) := (mkIdent (.mkSimple rd[0]!.1), mkIdent (.mkSimple rd[1]!.1),
    mkIdent (.mkSimple wr[0]!.1), mkIdent (.mkSimple scalars[0]!.1))
  let wq := quote (P.layout.size t)
  let alq := quote (P.layout.align t)
  let alq' := quote (P.layout.align T)
  let retId := mkIdent (n ++ `ret)
  let pathsId := mkCIdent pathsN
  elabCommand (← `(command|
    theorem $retId {L : Launch} (hL : L.Valid)
        (hg : L.grid .y = 1 ∧ L.grid .z = 1) (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat}
        (hal : $alq ∣ al) {$xa $xb $xo $xn N : Nat} {x y : TorchLean.Tensor _ [N]}
        (hne : $xa ≠ $xb ∧ $xa ≠ $xo ∧ $xb ≠ $xo) (hnN : $xn ≤ N) (h31 : $xn < 2 ^ 31) {k : Nat}
        (hk : k < volume L.grid * volume L.block) {c : Ctx} (hcp : c.prog = $Pstx)
        (hce : c.env = L.env k) (hcw : c.who = ⟨k, k / volume L.block⟩) {ω : Nat → Nat → Nat}
        (hco : c.oracle = ω k) {m₀ m : Mem} {f : Frame} (hf : f.fn = $fnstx) {p0 p1 p2 : Nat}
        (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
        (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩))
        (hr3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 $xn)))
        (hv0 : m.load ($Pstx).layout c.who 0 $argTyId ⟨p0, 0⟩ (some $alq') =
          .ok (.agg [.ptr ⟨$xa, 0⟩, $argTailId]))
        (hv1 : m.load ($Pstx).layout c.who 0 $argTyId ⟨p1, 0⟩ (some $alq') =
          .ok (.agg [.ptr ⟨$xb, 0⟩, $argTailId]))
        (hv2 : m.load ($Pstx).layout c.who 0 $argTyId ⟨p2, 0⟩ (some $alq') =
          .ok (.agg [.ptr ⟨$xo, 0⟩, $argTailId]))
        (hA : m.Buffer $xa ($xn * ($Pstx).layout.size $tstx) al false)
        (hB : m.Buffer $xb ($xn * ($Pstx).layout.size $tstx) al false)
        (hO : m.Buffer $xo ($xn * ($Pstx).layout.size $tstx) al true)
        (hx : m.Holds ($Pstx).layout $xa $tstx $encstx (rowMajor ($Pstx).layout $tstx 0) x)
        (hy : m.Holds ($Pstx).layout $xb $tstx $encstx (rowMajor ($Pstx).layout $tstx 0) y)
        (hFa : m.Fits ($Pstx).layout $xa ($xn * ($Pstx).layout.size $tstx))
        (hFb : m.Fits ($Pstx).layout $xb ($xn * ($Pstx).layout.size $tstx))
        (hFo : m.Fits ($Pstx).layout $xo ($xn * ($Pstx).layout.size $tstx))
        (hp : p0 ≠ $xo ∧ p1 ≠ $xo ∧ p2 ≠ $xo)
        (hE : Elem m₀ $xo $wq (fun i => $wq * i) ($bytesstx ω x y $xn) k m) :
        ∃ ps ∈ $pathsId, Ret (Valuation.entry c 0 m f)
          (Elem m₀ $xo $wq (fun i => $wq * i) ($bytesstx ω x y $xn) (k + 1)) ps := by
      mojo_ret))
  addDocStringCore (base ++ `ret) s!"**Each thread's path of `{fnText}` is a `Ret`** (by \
    `mojo_ret`, generated by `mojo_kernel {n}`). For every valid launch whose grid and block \
    have side 1 in `y` and `z`, alignment `al` that `{P.layout.align t}` divides, distinct blocks \
    `{rd[0]!.1}`, `{rd[1]!.1}`, `{wr[0]!.1}`, count `{scalars[0]!.1} ≤ N` below `2 ^ 31`, tensors \
    `x`, `y`, thread `k` of the launch, context of the program with thread `k`'s registers, \
    identity and oracle `ω k`, caller's memory `m₀`, memory `m` of `Elem` after `k` threads \
    with the bytes of the `map2` clause at cells `{P.layout.size t} i`, and frame of the kernel \
    whose registers `%0` to `%2` point to blocks other than `{wr[0]!.1}` from which \
    `{short argTyN}` loads as the structs of the three buffers and whose `%3` is the count, on \
    which the three are buffers of the count's elements that fit and the inputs hold `x`, `y` \
    row-major from 0: some path of `{short pathsN}` from the frame's entry is a `Ret` to `Elem` \
    after `k + 1` threads. It covers this one kernel, at every launch, thread, frame and memory \
    that meet these premises."
  let correctId := mkIdent (n ++ `correct)
  let coversId' := mkCIdent (base ++ `covers)
  let startsId' := mkCIdent (base ++ `starts)
  let retId' := mkCIdent (base ++ `ret)
  elabCommand (← `(command|
    theorem $correctId {L : Launch} (hL : L.Valid)
        (hg : L.grid .y = 1 ∧ L.grid .z = 1) (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat}
        (hal : $alq ∣ al) {$xa $xb $xo $xn N : Nat} {x y : TorchLean.Tensor _ [N]} {m : Mem}
        (hP : Map2.Pre ($Pstx).layout $tstx $encstx al $argTailId m $xa $xb $xo $xn x y)
        {ω : Nat → Nat → Nat} :
        Kernel.Sound $Pstx $fnstx L ($argsId $xa $xb $xo (BitVec.ofNat 32 $xn)) m
          (fun _ ω' => ω' = ω) (fun m => some m.blocks)
          (Elem.Out m $xo (fun i => $wq * i) ($bytesstx ω x y $xn)
            (volume L.grid * volume L.block)) :=
      Kernel.sound_map2 $coversId' rfl ⟨rfl, rfl, rfl, rfl⟩ (T := $argTyId) ⟨rfl, rfl, rfl, rfl⟩
        (Layout.Codec.ptrArg _ $(quote sp) (by decide +kernel) (by decide +kernel) rfl rfl rfl)
        (al' := $alq') ⟨by decide, by decide⟩ hP (fun _ => rfl)
        (fun ch => $startsId' L $xa $xb $xo _ hP.closed ch ω) (apart_mul $wq)
        fun _ hk _ hcp hce hcw hco _ _ _ hf _ _ _ hr0 hr1 hr2 hr3 hv0 hv1 hv2 hA hB hO hx hy hFa
          hFb hFo hp hE => $retId' hL hg hb hal hP.ne hP.le hP.lt hk hcp hce hcw hco hf hr0 hr1
            hr2 hr3 hv0 hv1 hv2 hA hB hO hx hy hFa hFb hFo hp hE))
  addDocStringCore (base ++ `correct) s!"**The kernel theorem of `{fnText}`** (generated by \
    `mojo_kernel {n}`). For every valid launch `L` whose grid and block have side 1 in `y` and \
    `z`, alignment `al` that `{P.layout.align t}` divides, block numbers `{rd[0]!.1}`, \
    `{rd[1]!.1}`, `{wr[0]!.1}`, count `{scalars[0]!.1}`, tensors `x`, `y` of length `N`, oracle \
    `ω` and caller's memory `m` of `Map2.Pre` at the element type and encoder of the `map2` \
    clause and tail `{short argTailN}` (`m` closed for the arguments; distinct buffers \
    `{rd[0]!.1}`, `{rd[1]!.1}` read-only and `{wr[0]!.1}` writable, each of at least \
    `{scalars[0]!.1}` elements whose generic addresses do not wrap; the inputs holding \
    `x`, `y`; `{scalars[0]!.1} ≤ N` and `{scalars[0]!.1} < 2 ^ 31`): `{fnText}` is sound on \
    `{short argsN}` at every address choice and `ω` (`Kernel.Sound`) for the observation of the \
    blocks and `Elem.Out`: block `{wr[0]!.1}` is `m`'s with, at cell `{P.layout.size t} i`, the \
    bytes the `map2` clause gives each thread `i` of the launch put in turn (`Elem.put`; nothing \
    where it gives `none`), and every other block of `m` is unchanged. It covers this one \
    kernel, at every launch and input that meet these premises \
    (`Kernel.sound_map2` at `{n}.covers`, `{n}.starts` and `{n}.ret`)."


/-- Elaborates `mojo_kernel`: with the `mat` clause by `elabMat`, otherwise by `elabMojoKernel`;
`unsafe` because both evaluate the program. -/
@[command_elab mojoKernel] unsafe def elabMojoKernelCmd : CommandElab := fun stx =>
  if stx[12].isNone then elabMojoKernel stx else elabMat stx

end MojoProof.Sym
