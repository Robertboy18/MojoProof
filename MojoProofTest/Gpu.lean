import MojoProofTest.Eval
import MojoProofTest.SymPhi
import MojoProof.Kernels.Vsub

/-!
# A GPU run against the evaluator

The code of `lake env lean --run tests/gpu/Compare.lean <kernel> <dump> <launches>`, for
`<kernel>` one of `vadd`, `vmul`, `vsub` and `naive` (`tests/gpu/Compare.lean` calls `main` here;
this module is in the test library, so `lake build MojoProofTest` compiles it). It reads the file
`<dump>` that the driver `tests/gpu/<kernel>/*.mojo` wrote on a GPU and refuses it, with exit
code 1 and a message, when it holds no launch or a number of launches other than `<launches>`
(the number of `launch:` lines of the run's record). For each launch in it, it runs the grid
evaluator (`MojoProof.Sem.Grid.run`) on the kernel's corpus program with the same launch, the same
input words, the same initial output buffer and the same scalar arguments, all buffers in address
space 1, and compares the evaluator's final output buffer with the GPU's word for word over the
whole buffer, the words the kernel writes and those it must not write.

* `vadd`, `vmul`, `vsub`: the programs `Kernels.<kernel>.prog` (the library's imports of the
  corpus files), 1-D launches on the buffers `lhs`, `rhs` and the output and the size `n`. Every
  thread gets the oracle that is always 0; the kernels' only float operation is one
  `fadd contract`, `fmul` or `fsub contract` whose operands carry no `fmul contract` product, on
  finite inputs, so no oracle choice reaches the output.
* `naive`: the program `naiveSm80.prog`, the import of the naive matmul kernel's IR for sm_80
  (tests/corpus/mgemm_sm80/), whose function is that of `naive` (MojoProofTest/SymPhi.lean, the
  kernel of the proofs) but for its name (`naiveSm80_fn`). 2-D launches on the buffers `C` (the
  output), `A` and `B` and the sizes `m`, `n`, `K`. Every thread gets the oracle that is always 2:
  each `fadd contract` of the loop fuses the `fmul contract` product into the sum
  (`Sem.contract`), and the number 2 encodes no `NaN`, so `Sem.deliver` changes no result.

A conformance test of compiled kernels on these inputs, not a proof.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProofTest

namespace MojoProofTest.Gpu

mojo_import "mgemm_sm80/test_multistage_gemm_kernel_\
  matmul_kernel_naive_float32_float32_float32_True_16_343aedc5.nvptx.ll" as naiveSm80

/-- The name of the naive matmul kernel in its `sm_80` file (tests/corpus/mgemm_sm80/). -/
def sm80Name : String := "matmul_kernel_naive_float32_float32_float32_True_16_343aedc5"

/-- **The `sm_80` kernel's function is `naive`'s but for its name**: the same linkage, calling
convention, parameters, attribute group, register names and blocks (the import names `naive`'s
blocks). For these two imports only. -/
theorem naiveSm80_fn : naiveSm80.fn_0 = { SymPhi.naive.fn_0 with name := sm80Name } := rfl

/-- **The `sm_80` program is `naive`'s but for the kernel's name, its file's digest and the target
attributes of group 0** (`sm_80` and `+ptx81` for `sm_90a` and `+ptx85`): the same source file
name, data layout, triple, declarations, other attribute groups, metadata, layout and
intrinsics. For these two imports only. -/
theorem naiveSm80_prog : naiveSm80.prog = { SymPhi.naive.prog with
    module := { SymPhi.naive.module with
      funcs := SymPhi.naive.module.funcs.modify 0 fun f => { f with name := sm80Name }
      attrGroups := SymPhi.naive.module.attrGroups.modify 0 fun _ => (0, [.flag "norecurse",
        .str "target-cpu" "sm_80", .str "target-features" "+ptx81,+sm_80",
        .str "tune-cpu" "sm_80"]) }
    sha256 := "03f8d1b362e7612b7a2ae6dd359d640e16afa58b508b21a1ac11d17c1e4c6274"
    kernels := [sm80Name] } := rfl

/-- The 4 bytes of word `w`, little-endian. -/
def wordBytes (w : Nat) : List MemByte :=
  (List.range 4).map fun k => .byte (BitVec.ofNat 8 (w >>> (8 * k)))

/-- Word `i` of block `blk` (bytes `4 i` to `4 i + 3`, little-endian), if all four are data. -/
def wordAt (blk : Sem.Block) (i : Nat) : Option Nat :=
  (List.range 4).foldr (init := some 0) fun k acc => do
    let .byte b := blk.bytes (4 * i + k) | none
    return ((← acc) <<< 8) ||| b.toNat

/-- `m` with a new block of the words `ws` (4 bytes each, little-endian) in address space 1,
writable, live and admitting every thread, at address `0x1000000 * (j + 1) * 16`: the block of
`Mem.alloc` with these bytes as its `init`, its bytes read from an array (the same bytes). Returns
the memory and the block number. -/
def allocWords (l : Sem.Layout) (m : Mem) (ws : List Nat) (j : Nat) : Mem × Nat :=
  let (m, b) := m.alloc l 1 (4 * ws.length) 16 true false .all (0x1000000 * (j + 1))
    (0x1000000 * (j + 1))
  let bs := (ws.flatMap wordBytes).toArray
  match m.blocks b with
  | some blk => (m.set b { blk with bytes := fun i => bs.getD i .undef }, b)
  | none => (m, b)

/-- One launch `L` of the kernel of `prog` on buffers of the words `bufs` (in the order of the
kernel's buffer parameters, blocks `allocWords` makes) and the `i32` scalars `scalars`, every
thread with the oracle that is always `o`: the words of buffer `out` after the run. -/
def runCase (prog : Program) (L : Launch) (bufs : List (List Nat)) (scalars : List Nat)
    (out o : Nat) : Except String (List (Option Nat)) := do
  let l := prog.layout
  let some fn := prog.module.funcs.find? (some ·.name == prog.kernels.head?)
    | throw "no kernel"
  let (m, bs) := bufs.zipIdx.foldl (init := (({} : Mem), ([] : List Nat)))
    fun (m, acc) (ws, j) => let (m, b) := allocWords l m ws j; (m, acc ++ [b])
  let args := kernelArgs fn bs (scalars.map fun s => .bits 32 (BitVec.ofNat 32 s))
  let (g, ctx) ← (Grid.start prog fn L args m (fun _ => 0) fun _ _ => o).mapError err
  let g ← (g.run L ctx 100000 100).mapError err
  let some blk := g.mem.blocks (bs.getD out 0) | throw "no output block"
  return (List.range (bufs.getD out []).length).map (wordAt blk)

/-- One launch of the dump: the kernel's scalar arguments, the grid's and the block's sides in
`x` and `y`, the buffers' words before the launch, which buffer is the output, and the output
buffer's words after the launch, on the GPU. -/
structure Case where
  /-- The launch from its scalars, sides, buffers and output. -/
  mk ::
  /-- The `i32` scalar arguments: `n` for a 1-D launch, `m`, `n`, `K` for a 2-D one. -/
  scalars : List Nat
  /-- The grid's sides in `x` and `y`. -/
  grid : Nat × Nat
  /-- The block's sides in `x` and `y`. -/
  block : Nat × Nat
  /-- The buffers before the launch, in the order of the kernel's buffer parameters. -/
  bufs : List (List Nat)
  /-- The index of the output buffer in `bufs`. -/
  out : Nat
  /-- The output buffer after the launch, on the GPU. -/
  gpu : List Nat

/-- The words of the token `w`: `[v]` for a number `v`, `k` copies of `v` for `v*k`. -/
def token (w : String) : Except String (List Nat) :=
  match w.splitOn "*" with
  | [v] => match v.toNat? with
    | some v => pure [v]
    | none => throw s!"not a number: {w}"
  | [v, k] => match v.toNat?, k.toNat? with
    | some v, some k => pure (List.replicate k v)
    | _, _ => throw s!"not a number: {w}"
  | _ => throw s!"not a number: {w}"

/-- The numbers of line `line` after its first field, which must be `tag`; a field `v*k` stands
for `k` copies of `v`. -/
def nums (tag line : String) : Except String (List Nat) :=
  match (line.splitOn " ").filter (· ≠ "") with
  | t :: ws =>
    if t = tag then return (← ws.mapM token).flatten
    else throw s!"expected {tag}, found {t}"
  | [] => throw s!"expected {tag}, found an empty line"

/-- The launches of the dump's lines (the `seed` and `gpu` lines removed), five lines each. A
1-D launch (of `vadd`, `vmul`, `vsub`): `case n grid block total`, then `lhs`, `rhs` (`total`
words each), `init` (one word) and `out` (`total` words); its buffers are `lhs`, `rhs` and the
output, `total` words of `init`. A 2-D launch (of the naive matmul): `case m n K gx gy bx by c a
b`, then `a` (`a` words), `b` (`b` words), `init` (one word) and `c` (`c` words); its buffers are
the output, `c` words of `init`, then `a` and `b`. No line gives no launch; `dumpCases` refuses
that. -/
def parseCases : List String → Except String (List Case)
  | [] => pure []
  | c :: l :: r :: i :: o :: rest => do
    let [init] ← nums "init" i | throw s!"bad init line: {i}"
    let cs ← match ← nums "case" c with
      | [n, grid, block, total] => do
        let lhs ← nums "lhs" l
        let rhs ← nums "rhs" r
        let out ← nums "out" o
        unless lhs.length = total ∧ rhs.length = total ∧ out.length = total do
          throw s!"case {n}: a buffer of the wrong length"
        pure ⟨[n], (grid, 1), (block, 1), [lhs, rhs, List.replicate total init], 2, out⟩
      | [m, n, k, gx, gy, bx, by', cw, aw, bw] => do
        let a ← nums "a" l
        let b ← nums "b" r
        let out ← nums "c" o
        unless a.length = aw ∧ b.length = bw ∧ out.length = cw do
          throw s!"case {m} {n} {k}: a buffer of the wrong length"
        pure ⟨[m, n, k], (gx, gy), (bx, by'), [List.replicate cw init, a, b], 0, out⟩
      | _ => throw s!"bad case line: {c}"
    return cs :: (← parseCases rest)
  | _ => throw "truncated dump"

/-- The launches of the dump whose lines are `ls`: the `seed` and `gpu` lines and the empty ones
removed, the rest parsed by `parseCases`. An error when the dump holds no launch (an empty dump,
or one of `seed` and `gpu` lines only), and when it holds a number of launches other than
`expected` (the number of `launch:` lines of the run's record). -/
def dumpCases (ls : List String) (expected : Nat) : Except String (List Case) := do
  let cs ← parseCases (ls.filter fun l =>
    !(l.startsWith "seed " || l.startsWith "gpu " || l.isEmpty))
  if cs.isEmpty then throw "no launch in the dump"
  unless cs.length = expected do
    throw s!"{cs.length} launches in the dump, {expected} expected"
  return cs

/-- The head of launch `c`'s line: `n N grid G block B` for a 1-D launch, `m M n N k K grid GX
GY block BX BY` for a 2-D one. -/
def Case.head (c : Case) : String :=
  match c.scalars with
  | [n] => s!"n {n} grid {c.grid.1} block {c.block.1}"
  | [m, n, k] => s!"m {m} n {n} k {k} grid {c.grid.1} {c.grid.2} block {c.block.1} {c.block.2}"
  | _ => s!"scalars {c.scalars}"

/-- Run the launches `cs` of program `prog` (kernel `k`) in the evaluator, every thread with the
oracle that is always `o`, and compare their output buffers with the GPU's: one line per launch
and a summary; 0 when every launch agrees, 1 otherwise. -/
def compare (k : String) (prog : Program) (o : Nat) (cs : List Case) : IO UInt32 := do
  IO.println s!"program {k}: corpus file sha256 {prog.sha256}"
  let mut bad := 0
  for c in cs do
    let L := launch2 c.grid.1 c.grid.2 c.block.1 c.block.2
    match runCase prog L c.bufs c.scalars c.out o with
    | .error e => IO.println s!"{c.head}: evaluator fault {e}"; bad := bad + 1
    | .ok ws =>
      let diff := (ws.zip c.gpu).zipIdx.filter fun ((a, b), _) => a != some b
      if diff.isEmpty && ws.length == c.gpu.length then
        IO.println s!"{c.head}: {ws.length} words agree"
      else
        bad := bad + 1
        let shown := (diff.take 5).map fun ((a, b), j) => s!"word {j}: evaluator {a}, GPU {b}"
        IO.println s!"{c.head}: {diff.length} words differ; {shown}"
  IO.println s!"{cs.length} launches, {bad} differ"
  return if bad = 0 then 0 else 1

/-- Run every launch of the dump the arguments name and compare (see the module docstring):
exit code 2 on a usage error, 1 when the dump is refused by `dumpCases` or a launch differs, 0
when the dump holds the expected number of launches and every one agrees. -/
def main (args : List String) : IO UInt32 := do
  let [k, path, count] := args
    | IO.eprintln
        "usage: lean --run tests/gpu/Compare.lean <vadd|vmul|vsub|naive> <dump> <launches>"
      return 2
  let some expected := count.toNat?
    | IO.eprintln s!"not a number of launches: {count}"; return 2
  let (prog, o) ← match k with
    | "vadd" => pure (Kernels.vadd.prog, 0)
    | "vmul" => pure (Kernels.vmul.prog, 0)
    | "vsub" => pure (Kernels.vsub.prog, 0)
    | "naive" => pure (naiveSm80.prog, 2)
    | _ => throw (IO.userError s!"unknown kernel {k}")
  match dumpCases (← IO.FS.lines path).toList expected with
  | .error e => IO.eprintln s!"{path}: {e}"; return 1
  | .ok cs => compare k prog o cs

/-- The dump lines of a 2-D launch of one block of 2 x 1 threads, `m = 1`, `n = 1`, `K = 2`: `C`
3 words long, every word 7 before the launch; `A` and `B` the binary32 words of 1.0 and 2.0; on
the GPU, `C`'s first word the binary32 word of 5.0 after the launch (a made-up dump). -/
private def twoCase : List String :=
  ["case 1 1 2 1 1 2 1 3 2 2", "a 1065353216 1073741824", "b 1065353216 1073741824",
    "init 7*1", "c 1084227584 7*2"]

-- A 2-D launch: its scalars, sides and buffers, the output first and `init` repeated.
#guard (dumpCases twoCase 1).toOption.map (List.map fun c => (c.scalars, c.grid, c.block,
  c.bufs, c.out, c.gpu)) == some [([1, 1, 2], (1, 1), (2, 1),
    [[7, 7, 7], [1065353216, 1073741824], [1065353216, 1073741824]], 0, [1084227584, 7, 7])]
-- A token `v*k` is `k` copies of `v`; `*` alone is refused.
#guard nums "a" "a 3*2 4" == .ok [3, 3, 4] && (nums "a" "a 3*").toOption.isNone
-- The evaluator on `twoCase`: thread 0 computes `1 * 1 + 2 * 2 = 5` into `C`'s word 0, thread 1
-- (row 1, out of bounds since `m = 1`) writes nothing, and words 1 and 2 keep `init`.
#guard (dumpCases twoCase 1).toOption.bind (fun cs => cs.head?.bind fun c =>
  (runCase naiveSm80.prog (launch2 1 1 2 1) c.bufs c.scalars c.out 2).toOption) ==
  some [some 1084227584, some 7, some 7]

/-- The dump lines of one launch of 1 element, its buffers 2 words long. -/
private def oneCase : List String :=
  ["case 1 1 1 2", "lhs 1 2", "rhs 3 4", "init 0", "out 4 0"]

-- `dumpCases` refuses an empty dump.
#guard dumpCases [] 6 matches .error "no launch in the dump"
-- `dumpCases` refuses a dump of `seed` and `gpu` lines only, even when no launch is expected.
#guard dumpCases ["seed 1", "gpu G", ""] 0 matches .error "no launch in the dump"
-- `dumpCases` refuses a dump of five launches when six are expected.
#guard dumpCases ("seed 1" :: "gpu G" :: (List.replicate 5 oneCase).flatten) 6 matches
  .error "5 launches in the dump, 6 expected"
-- `dumpCases` reads six launches when six are expected.
#guard (dumpCases ("seed 1" :: "gpu G" :: (List.replicate 6 oneCase).flatten) 6).toOption.map
  List.length == some 6

end MojoProofTest.Gpu
