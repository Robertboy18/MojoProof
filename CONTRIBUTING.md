# Contributing

## Proving a new kernel

`docs/new-kernel.md` follows one kernel from its Mojo source to its kernel theorem: compiling it,
adding it to the corpus, importing it, writing its specification and running `mojo_kernel`.
`docs/kernel.md` and `docs/tactics.md` are the reference for the command and the tactics.
`AGENTS.md` has the same steps and the rules below as a checklist for automated agents.

## Building and checking

You need [elan](https://github.com/leanprover/elan) (it installs the toolchain that
`lean-toolchain` names, Lean 4 v4.36.0), git and python3. Mojo is needed only to add a kernel to
the corpus, and graphviz 2.44.0 (`dot`) only to regenerate or check the dependency documents:
`deps.py check` compares the rendered SVGs byte for byte, and they record that version.

```
lake exe cache get        # prebuilt Mathlib files
lake build                # the default targets: the library MojoProof and the kernels MojoProofKernels
lake build MojoProofTest  # every test module
lake test                 # the test runner mojoproof_test
lake env lean --run scripts/Audit.lean
python3 scripts/cited.py
python3 scripts/corpus.py check
```

What each one checks:

- `lake build MojoProofTest` elaborates every test module. A test theorem is checked by the kernel
  when its module builds; a refusal test in a test module is a `#guard_msgs` block.
- `lake test` runs `mojoproof_test`: the SHA-256 test vectors, the refusals of the inputs listed in
  `MojoProofTest/Main.lean`, and for every corpus file: its digest equals its
  `tests/corpus/MANIFEST.tsv` row, it parses, `parse (print m) = m`, and the importer accepts it or
  refuses it with exactly the reason `tests/corpus/REFUSALS.tsv` lists.
  It also runs the evaluator on `vector_addition` and `tiled_matmul` against FloatLib's arithmetic.
- `scripts/Audit.lean` imports every module of `MojoProof/` and `MojoProofTest/` and checks the
  environment. Every declaration (theorems and definitions, private ones included) must depend on no
  axiom beyond `propext`, `Classical.choice` and `Quot.sound`. A `sorry` shows as `sorryAx` and a
  `native_decide` as an auxiliary axiom. It also prints these counts:
  - `DUPDEF` and `DUPTHM`: definitions or theorems of the library that repeat an earlier one.
  - `DUPDEF_tests` and `DUPTHM_tests`: the same for test declarations.
  - `unused`: library declarations nothing mentions, except the targets in `scripts/targets.txt`.
  - `equivalences`: theorems `f as ↔ g bs` or `f as = g bs` whose two sides are headed by two
    different definitions of the library.

  With `--deps <file>` it also writes the facts that `scripts/deps.py` turns into
  `docs/DEPENDENCIES.md` and `docs/deps/`.
- `scripts/cited.py`: every name in backticks whose last component is snake_case (`addr_twin`,
  `Mem.load_skel`), in a module docstring of `MojoProof/` or `MojoProofTest/`, must be a declaration
  that resolves from the citing file. A library lemma of the same last name does not count, and
  neither does a field name standing in for a qualified name.
- `scripts/corpus.py check`: every corpus file matches its manifest row (sha256, line count, kernel
  name, arch, PTX version), and no `.ll` file under `tests/corpus/` is missing from the manifest.
- `python3 scripts/near_dups.py . --lib MojoProof --list 5`: the theorems of `MojoProof/` whose text
  is identical once widths and types are replaced (`width families`), and the clusters of theorems
  of 15 or more lines that share at least 70% of their 5-token shingles (`near-duplicate
  clusters`), with the five largest clusters listed.

The audit exits with an error only for an axiom. Compare the counts it prints with their limits in
`scripts/counts.tsv`, which are all 0; if a count drops below its limit, lower the limit.
`near_dups` and `width_families` in that file are the `near-duplicate clusters` and `width families`
counts that `scripts/near_dups.py` prints.

After a change that adds, deletes or moves declarations or imports, regenerate the dependency
documents and check them:

```
lake env lean --run scripts/Audit.lean --deps /tmp/facts.json
python3 scripts/deps.py write /tmp/facts.json
python3 scripts/deps.py check /tmp/facts.json
```

## Adding a kernel to the corpus

1. Compile the Mojo source to per-kernel LLVM IR. The corpus was compiled with the Mojo version
   that `scripts/corpus.py` records (`MOJO`, 1.3.0.dev2026111705); with another version, pass it to
   `add` with `--mojo` in step 2. In the source's directory:

   ```
   mojo build --emit llvm --target-accelerator sm_80 -o <name>.ll <name>.mojo
   ```

   This writes one `*.nvptx.ll` file per kernel specialization. Pass any other flags you need, for
   example `--fp-mode contract=off`, and record them in step 2.
2. Add the files and their manifest rows:

   ```
   python3 scripts/corpus.py add [--mojo "<version>"] <family> <src.mojo> <source-path> "<flags>" <file.nvptx.ll>...
   ```

   This copies each file to `tests/corpus/<family>/` and writes its `MANIFEST.tsv` row:

   - path, sha256 and line count;
   - the one `ptx_kernel` define;
   - the arch and PTX version, from the file's attributes;
   - the Mojo version (`--mojo`, else `MOJO`);
   - `<flags>`, which must be the exact flags passed to `mojo build` (for example
     `--emit llvm --target-accelerator sm_80`);
   - the source and the source's sha256.

   `<source-path>` is the source's path in the modular repository at the commit `corpus.py` records
   (`MODULAR`). For a source kept in this repository, write `repo:<path>` instead, with `<path>`
   relative to the repository root; `check` then also compares that source's sha256.

   Add the source to `tests/corpus/NOTICE`, with its commit and its license. Read the license in
   the source's header: the corpus takes only sources under the Apache License v2.0 with LLVM
   Exceptions, whose text is `tests/corpus/LICENSE-APACHE-LLVM`. A source kept in this repository
   that is a modified copy of a Modular file keeps that file's header and says what was changed.
3. Run `python3 scripts/corpus.py check` and `lake test`. A file the importer refuses must be listed
   in `tests/corpus/REFUSALS.tsv` with the exact reason the test prints. A refusal that is not listed,
   or a listed one that does not occur, fails the test. A new row also changes the counts that
   `MojoProofTest/Corpus.lean`'s `#mojo_corpus` test expects (rows, imported, refused): update its
   `/-- info: ... -/` line, or `lake build MojoProofTest` fails there.
4. To state theorems about the kernel, import it as a Lean term with `mojo_corpus` in
   `MojoProof/Kernels.lean` (the order of the arguments fixes which import names a shared function).
   Or use `mojo_import "<family>/<file>" as <name>`. Both check the digest against the manifest at
   every build.

## Rules a change must meet

- The build, the tests, the audit (with every count within its limit), `cited.py` and
  `corpus.py check` pass. There is no `sorry`, `admit`, `native_decide`, `axiom`,
  `implemented_by` or `extern` in `MojoProof/`.
- Prove each family of statements once. A variant is a one-line corollary or is not added. Generate
  instances with commands or tactics instead of copying proofs.
- Every abstraction and every premise of a headline theorem has a concrete instance, and a premise
  the proof needs has a twin: a test showing the conclusion fails without it.
- No duplicates. When a statement becomes a corollary of a stronger one, delete the weaker code.
- Keep modules under about 2,500 lines. Each module starts with a docstring that says exactly what is
  proved, with premises, and whether it covers one kernel, a family of programs, or every program.
- Every public declaration, constructor and structure field has a docstring that says what it is or
  proves, with its premises and scope. Do not write "complete", "full", "general" or "all" for
  something partial.
- Floats go only through FloatLib, never a local IEEE model. Specifications come from TorchLean; if
  TorchLean lacks one, record the gap instead of defining a second copy.
- A new trusted item goes in `docs/TRUST.md` with its reason, and needs an anchor line in
  `scripts/trust.tsv` (`all`, `module`, `modules` or `const`). A new issue goes in `docs/BUGS.md`.
- A headline theorem nothing else uses goes in `scripts/targets.txt`, in the section for its module.
- Findings about Mojo or other upstream projects go in `docs/BUGS.md`, marked upstream, with a
  reproducer under `tests/upstream/`.
- Commit messages describe the change in plain words.

## The website

The website, <https://robertboy18.github.io/MojoProof/>, is built from the repository's own files
by `scripts/site.py`: the README, the roadmap with every card, this guide and every document of
`docs/`. To build it and check it locally:

```
pip install -r scripts/site-requirements.txt   # markdown and pygments
python3 scripts/roadmap_status.py              # if a card or a declaration it names changed
python3 scripts/site.py --out _site
python3 scripts/site.py --check _site          # every link, anchor and image resolves
```

Then open `_site/index.html` in a browser, as a file. CI builds and checks the site on every pull
request, and rebuilds and publishes it from main when the pull request is merged.

## Where things live

- `MojoProof/LLVM/`: the LLVM IR AST, lexer, parser, printer, intrinsic table, the importer's checks,
  and the `mojo_import` and `mojo_corpus` commands.
- `MojoProof/Sem/`: the semantics (values, memory, one thread, the grid of threads), what a kernel
  theorem states (`Spec.lean`), and theorems stated for every program under their premises:
  schedule independence, race freedom, the skeleton relation, the float relations.
- `MojoProof/Sym/`: the symbolic block checker and the `mojo_kernel` command.
- `MojoProof/Cert/`: the RUP certificate checker. `MojoProof/Util/`: SHA-256.
- `MojoProof/Kernels.lean` and `MojoProof/Kernels/`: the imported corpus kernels and their theorems.
- `MojoProofTest/`: instances, twins and evaluator tests. `MojoProofTest/Main.lean` is the test
  runner.
- `LICENSE`: the Apache License 2.0, for everything outside `tests/corpus/`'s kernel files and
  their Modular sources. `AGENTS.md`: the instructions for automated agents.
- `tests/corpus/`: the kernel files, `MANIFEST.tsv` and `REFUSALS.tsv`; `NOTICE`, the sources the
  kernel files are compiled from, with their commit and license, and `LICENSE-APACHE-LLVM`, the
  license of those sources. `tests/stale/`: a changed file that the digest check must refuse.
  `tests/upstream/`: Mojo reproducers for the upstream rows of `docs/BUGS.md`.
- `scripts/`: `Audit.lean`, `cited.py`, `corpus.py`, `deps.py`, `counts.tsv`, `targets.txt`,
  `trust.tsv`, and `SymBench.lean` (the block checker's benchmark).
- `docs/`: `TRUST.md` (the trusted base), `BUGS.md` (issues), `new-kernel.md`, `kernel.md`,
  `automation.md` and `tactics.md` (how to prove a kernel), `proofs/` (the proofs written out),
  `DEPENDENCIES.md` and `deps/` (generated).
