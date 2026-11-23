# The roadmap

The roadmap lists what the project means to prove, one card per item, and shows how far each
item has come. The levels are not written by hand: `scripts/roadmap_status.py` computes each
card's level from the declarations, corpus files and records the card names, checks that the
card states that level, and writes the status pages. A card that names a declaration the code
does not have fails the check.

The status: [STATUS.md](STATUS.md) (and [status.yaml](status.yaml), the same as data). The
cards and their dependencies: [graph.svg](graph.svg), drawn from [graph.dot](graph.dot).
docs/deps/ is a different graph, of the Lean modules.

## Areas

An area is a directory `roadmap/<area>/` with a `README.md` and the cards in `cards/`. The
script reads every directory under roadmap/, so a new area needs no change to it.

| Area | Cards about |
|---|---|
| [kernels](kernels/README.md) | the corpus's kernels and the ones to add, each with its TorchLean operation |
| [gpu-model](gpu-model/README.md) | the launch, address spaces, shared memory, barriers, shuffles, atomics, tensor cores |
| [floats](floats/README.md) | rounding, NaNs, `contract`, `maxnum` and `minnum`, `rsqrt.approx` |
| [llvm-ir](llvm-ir/README.md) | the LLVM IR instructions and their rules |
| [layout](layout/README.md) | the layout laws |
| [std-math](std-math/README.md) | the standard library's math functions |

An area's README starts with a `# ` heading, the area's title (the status pages use it), and
has at least three sections: **Scope** (what the area covers and its reference documents, with
their versions), **Cards** or **Items** (a link to each card with one line about it) and
**Open** or **Next steps** (what the area needs next).

## A card

A card is `roadmap/<area>/cards/<id>.md`. It starts with front matter, one `key: value` per
line between two `---` lines (a `#` after a space starts a comment, except inside the quote):

```
---
id: <slug>                       # the file name without .md
title: <the item in one line>
kind: kernel | construct
ref: <source>@<version or commit>:<path>[:<line>|#<section>]
quote: "<a short exact quote of that source>"
lean: <comma-separated full declaration names> | not stated yet
corpus: <comma-separated paths or globs under tests/corpus> | none
tests: <comma-separated full test declaration names or MojoProofTest modules> | none
upstream:                        # an issue number if one is filed; otherwise empty
depends: <comma-separated card ids, optional>
level: <the level the script computes>
evidence: <optional: L<k>: item, item; L<m>: item>
---
```

| Key | Meaning | Checked by the script |
|---|---|---|
| id | the card's slug | equals the file name |
| title | the item, in one line; a kernel card names its TorchLean operation | not empty |
| kind | `kernel` (a GPU kernel family) or `construct` (a rule or an operation of the model) | one of the two |
| ref | where the rule or the kernel is written: a repository at a commit and a path and line (`modular/modular@bbc13a71:max/examples/gpu-functions/vector_addition.mojo:76`), a document at a version and a section (`PTX ISA 9.5 #9.7.15.1`, `LLVM LangRef 24.0.0git #fadd-instruction`), or a file of this repository, `repo:<path>:<line>` | not empty; for `repo:`, the file exists and the quote is on that line |
| quote | a short exact quote of the ref, in double quotes; `""` when no copy of the source is at hand, and the body then says "quote to be added" | a double-quoted string |
| lean | the Lean declarations of the item, full names; for a kernel, the TorchLean operation and the kernel's terms and theorems | each is a declaration |
| corpus | the corpus files of the item | each matches a file under tests/corpus |
| tests | the tests of the item, declarations or whole MojoProofTest modules | each is a declaration or a module file |
| upstream | an issue filed upstream (`#123` or its URL); never bug text | empty or an issue number |
| depends | the cards this one needs, by id (`<area>/<id>` if the id is in more than one area) | each is a card |
| level | the level | equals the computed level |
| evidence | the declarations, records or cards that show each level above L0 | see the ladders |

Declarations are looked up in the index of scripts/cited.py (MojoProof/ and MojoProofTest/),
plus the names the `mojo_kernel` command adds (`MojoProof.Kernels.vadd.correct`,
`.covers`, `.sound_of` and the others; with `mat`, `.sound_mat` and the others,
MojoProof/Sym/KernelCmd.lean), plus FloatLib's and
TorchLean's sources under .lake/packages for names starting with `FloatLib.` or `TorchLean.`.
No Lean runs, so the script checks that a name exists, not what it states: that the theorem
cited at a level states what the level means is for the card's reviewer.

The body says, in plain words, the rule (or what the kernel computes), what is proved and for
what (for a kernel: one kernel, some specializations, or the family), what is in and out of
scope, and what is still open.

## The ladders

A card's level is the highest level whose evidence is present together with that of every
level below it. Evidence for a higher level with a lower one missing is shown, not counted:
STATUS.md then says, for example, "L0; L2, L3 and L4 evidence present; L1 needs a recorded GPU
run".

Kernel cards:

| Level | Meaning | Evidence (the `evidence` entry) |
|---|---|---|
| L0 | card written | the card, with every check passing |
| L1 | imported, and the evaluator agrees with a GPU run: a conformance test of the evaluator against the GPU on the recorded inputs, not a proof | `L1:` a file of this repository recording a run on a GPU of a corpus file of the card: the GPU and its driver, the file and its digest, the launch and inputs, and the outputs of the GPU and of the evaluator, equal |
| L2 | memory safety and race freedom for every valid launch of the shape the theorem states | `L2:` a theorem `Kernel.Sound` (`MojoProof.Kernels.vadd.correct`, for one-dimensional launches, the shape `vector_addition` indexes: its index reads `tid.x` and not `tid.y`, so the theorem's premises exclude a two-dimensional block, `MojoProofTest.Kernel.twin_2d`) |
| L3 | the outputs are the TorchLean operation's, under the theorem's premises | `L3:` a theorem that the outputs are the TorchLean operation's (`MojoProofTest.Kernel.vadd_real`: where an output is finite it is TorchLean's `x + y`, and its real value is the real sum rounded to binary32) |
| L4 | an IEEE bound, or bit-exact | `L4:` a theorem bounding the outputs' error against the real result, or giving their exact bits |

So L3 is not equality over the reals: a binary32 sum is rounded (`1 + 2⁻²⁴` is `1`), and the
theorem may assume a finite output. STATUS.md's column "Scope of the cited theorems" says, for
each kernel card, what the premises of the theorems it cites restrict: the launches they admit
(one-dimensional: grid and block of side 1 in `y` and `z`), and for L3 and L4 whether an output
is assumed finite, whether its real value is the exact one rounded, and whether the thread's
oracle is assumed to fuse no round (no oracle number 2 modulo 3); a premise only some of a
level's theorems have follows their names. The script reads these from the theorems'
statements in their source (for a name `mojo_kernel` adds, from its statement template), not
from the card.

Construct cards:

| Level | Meaning | Evidence |
|---|---|---|
| L0 | card written | the card, with every check passing |
| L1 | modelled in Lean | the card's `lean` names (not `not stated yet`); no `evidence` entry |
| L2 | tested against the GPU: a conformance test of the model against the GPU on the recorded inputs, not a proof | `L2:` a file of this repository recording a run on a GPU of a test of the construct, as for kernel L1 |
| L3 | used by a proved kernel: a `Kernel.Sound` theorem of a kernel card with L2 evidence is about a program whose IR uses the construct | `L3:` kernel card ids, each with L2 evidence and a theorem about a program (the program of its elaborated statement and the corpus file whose manifest sha256 that program records: roadmap/llvm-ir/programs.tsv, which scripts/L3Programs.lean writes) whose IR uses the construct; the other corpus files a kernel card cites do not count (scripts/roadmap_llvm.py) |

Kernel L1 and construct L2 are the only levels a theorem does not give: they compare the model
with a GPU on the inputs a record lists, which tests the model on those inputs and proves
nothing about the others. A kernel card with no record of a GPU run stays at L0, and a
construct card with none at L1, whatever their higher evidence. Of each file cited at these two
levels the script checks that it is the record of a run that agrees: its first line starts
with `GPU run record:`, its `kernel:` line names a file under tests/corpus/ (for a kernel card,
one of the card's corpus files), and its `result:` line starts with `agree`. That the run's
kernel uses a construct and that the record compares it is for the card's reviewer.

## The script

```
python3 scripts/roadmap_status.py           # check the cards, write STATUS.md, status.yaml, graph.dot, graph.svg
python3 scripts/roadmap_status.py --check   # check the cards and that the three files are current; write nothing
```

Run the first after changing a card, adding one, or renaming a declaration a card names, and
commit the four files with the change. The second is what the gate runs: it exits 1 if a check
fails or if STATUS.md, status.yaml or graph.dot is not what the first would write (graph.svg,
drawn by `/usr/bin/dot`, is not compared). The output is sorted and has no timestamps. The
script needs Python 3 and its standard library only, and reads .lake/packages for FloatLib and
TorchLean names, so the dependencies must be fetched first.

## Adding a card

Copy a card of the same kind, set `id` to the new file name, fill in the keys, set `level:
L0`, and run the script: it says the level it computes, which the card must then state.
