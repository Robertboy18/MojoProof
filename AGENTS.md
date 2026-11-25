# Instructions for coding agents

This file is for automated agents that work in this repository. CONTRIBUTING.md has the same rules
for people, in more detail.

## What this repository is

MojoProof is a Lean 4 library of machine-checked proofs about GPU kernels written in Mojo. A kernel
is compiled to LLVM IR and kept in `tests/corpus/`. `mojo_import` reads it into Lean, checking its
digest. `MojoProof/Sem/` gives the IR a semantics. The block checker and the `mojo_kernel` command
(`MojoProof/Sym/`) turn the kernel's blocks and paths into theorems that Lean's kernel checks.
Floats go through FloatLib, and specifications come from TorchLean.

## Commands

These are the commands of CONTRIBUTING.md's "Building and checking". Run them from the repository
root; run `lake exe cache get` once first, for the prebuilt Mathlib files.

```
lake build                               # the core GPUProof, MojoProof and MojoProofKernels
lake build MojoProofTest                 # every test module
lake test                                # the test runner mojoproof_test
python3 scripts/corpus.py check          # each corpus file against tests/corpus/MANIFEST.tsv
python3 scripts/cited.py                 # the names cited in module docstrings and card bodies resolve
lake env lean --run scripts/Audit.lean   # the axioms of every declaration, and the counts
```

Compare the counts the audit prints with their limits in `scripts/counts.tsv`.

## Rules

- No `sorry`, `admit`, `native_decide` or new `axiom`. Every declaration may depend only on
  `propext`, `Classical.choice` and `Quot.sound`.
- Never change, weaken or delete an existing theorem statement. If one looks wrong, say so in your
  report and leave it as it is.
- Never weaken a specification to make a proof go through.
- A human reviews every specification. One you write is a proposal until then: say which
  definitions are specifications when you hand over the work.
- If a proof does not go through, leave the open goal or a clear failure. Never write a proof that
  only looks finished, such as a premise that assumes the conclusion or a weaker statement under
  the claim's name.
- Keep docstrings. Every new public declaration gets one that says what it proves, with its
  premises and its scope.
- Run the audit before you hand over the work.

## Proving a kernel

`docs/new-kernel.md` follows one kernel from its source to its theorem. The steps, in order:

1. Choose a kernel: a Mojo source, the kernel in it, and what to prove about it.
2. Compile it with the Mojo version that `scripts/corpus.py` records:
   `mojo build --emit llvm --target-accelerator sm_80 -o <name>.ll <name>.mojo`. Add
   `--fp-mode contract=off` when products must be exact, so that no multiply and add are fused.
3. Add it to the corpus:
   `python3 scripts/corpus.py add <family> <src.mojo> <source-path> "<flags>" <file.nvptx.ll>...`,
   then `python3 scripts/corpus.py check`. Add the source to `tests/corpus/NOTICE`.
4. Import it: `mojo_import "<family>/<file>.nvptx.ll" as k`, or add it to the `mojo_corpus` line
   of `MojoProof/Kernels.lean`.
5. Write the specification before the proof, in FloatLib and TorchLean terms, as `vadd.bytes` is
   written in `MojoProof/Kernels/Vadd.lean`.
6. Run `mojo_kernel` with one clause per parameter (`docs/kernel.md`).
7. Where it refuses or stops, `#mojo_info k.prog` prints each block's verdict, and the tactics
   `mojo_obl`, `mojo_vals`, `mojo_ret`, `mojo_race` and `mojo_bounds` (`docs/tactics.md`) prove the
   obligations that remain.
8. `#print axioms` on each new theorem.
9. `lake build`, `lake build MojoProofTest`, `lake test`, `python3 scripts/corpus.py check`,
   `python3 scripts/cited.py` and the audit.

## What is automatic today

- With the `map2` clause, `mojo_kernel` proves what a binary elementwise kernel without a loop
  computes, at every valid one-dimensional launch and every input of its precondition
  (`Kernels.vadd.correct`, `Kernels.vmul.correct`).
- Loops are not automatic. With a `loop` clause per loop the command checks the loops' paths,
  states each loop's obligations and gives the kernel theorem through the loops, but you write the
  precondition, the invariant, the trip count and the tactic that proves the obligations
  (`MojoProofTest/KernelLoop.lean`). No corpus kernel with a loop has a kernel theorem yet.
- Shared memory and barriers are not automatic: the block checker refuses barriers, and no kernel
  theorem covers a kernel that uses shared memory.

## If you are stuck

Stop and report:

- the goal, as Lean prints it;
- what you tried, and how each attempt failed;
- the smallest failing piece (one block, one path, one obligation or one lemma), with the command
  that reproduces it.

## Pick a card whose level can be raised

1. Open `roadmap/STATUS.md`.
2. Choose a card whose level can be raised.
3. Read its `ref`, `lean`, `corpus` and `tests` fields.
4. Do the work, under the rules above.
5. Rerun `python3 scripts/roadmap_status.py`, which writes `roadmap/STATUS.md`.
   `python3 scripts/roadmap_status.py --check` checks that the file is current.

## Starting an agent

A prompt that starts the work:

> Prove kernel X against spec Y in this repository, following AGENTS.md.
