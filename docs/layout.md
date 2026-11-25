# The repository

- `GPUProof/`: the core, definitions for every machine with no front end, importing only Mathlib
  and FloatLib: the one-run theorem (`OneRun.lean`), the signature (`Sig.lean`), races and
  happens-before (`Race.lean`), runs and `Clean` (`Run.lean`), and confluence along a surjection
  (`Transfer.lean`).
- `MojoProof/LLVM/`: the LLVM IR syntax, lexer, parser and printer, the intrinsic table, the
  `mojo_import` and `mojo_corpus` commands, and a mutation harness.
- `MojoProof/Sem/`: the semantics (values, memory, floats, threads, launches) and what a kernel
  theorem states, with schedule independence and the trace-replay checker.
- `MojoProof/Sym/`: the symbolic block checker and its soundness, loops, the kernel theorems,
  `mojo_kernel` and the tactics.
- `MojoProof/Cert/`, `MojoProof/Util/`: the RUP certificate checker and SHA-256.
- `MojoProof/Kernels.lean`, `MojoProof/Kernels/`: three corpus kernels imported as Lean terms
  (`vector_addition`, the vector multiply and `tiled_matmul`), the theorems of the first two, and
  the tutorial's `vector_subtraction` with its theorem (`MojoProof/Kernels/Vsub.lean`).
- `MojoProofTest/`: the tests. Most are checked when `lake build MojoProofTest` compiles them;
  `lake test` runs the rest: SHA-256 vectors, the importer's refusals, each corpus file's digest and
  print-parse round trip, and the evaluator on `vector_addition`, `tiled_matmul` and small test
  kernels.
- `tests/corpus/`: the compiled kernels, with `MANIFEST.tsv` (digests and provenance) and the
  files the importer refuses, with their reasons (`REFUSALS.tsv`).
- `tests/gpu/`: records of GPU runs of `vector_addition`, the vector multiply and
  `vector_subtraction` (the driver, the dump of inputs and outputs, and `record.txt`), and
  `Compare.lean`, which runs the grid evaluator on a dump's inputs and compares its output buffer
  with the GPU's. They are conformance tests of those launches and inputs, not proofs.
- `docs/`: the trusted base, guides to the commands and tactics, and informal proofs.
- `roadmap/`: one card per kernel, GPU-model construct, float operation, LLVM construct, layout law
  and `std.math` function, each with its source line, its Lean names and its level;
  `roadmap/STATUS.md` is the table of all cards, written by `scripts/roadmap_status.py`.
- `scripts/`: the corpus manifest tool, the declaration audit, the documentation checks and the
  roadmap scripts.
