import Lake
open Lake DSL

/-!
# MojoProof

Machine-checked guarantees for compiled Mojo GPU kernels: the per-kernel LLVM IR that
`mojo build --emit llvm --target-accelerator <arch>` writes, imported into Lean and given a
semantics with floating point through FloatLib.
-/

package MojoProof where
  version := v!"0.1.0"
  description := "Proofs about compiled Mojo GPU kernels (LLVM IR), floats through FloatLib."
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`relaxedAutoImplicit, false⟩]
  testDriver := "mojoproof_test"

require floatlib from git
  "https://github.com/lean-dojo/FloatLib" @ "v4.1.0"

require TorchLean from git
  "https://github.com/lean-dojo/TorchLean" @ "v1.5"

-- Keep `mathlib` last so Mathlib's dependency versions win (required by `lake exe cache get`).
require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "v4.36.0"

/-- The corpus: an input of the modules that import from it, which a changed file rebuilds. -/
input_dir corpus where
  path := "tests/corpus"

/-- The core: definitions and theorems for every machine, with no front end. Its modules import
only `GPUProof.*`, `Mathlib.*` and `FloatLib.*` (checked by MojoProofTest/GPUProof/Imports.lean).
-/
@[default_target]
lean_lib GPUProof where
  globs := #[.submodules `GPUProof]

/-- The library: the LLVM AST, parser, printer and quotation, the semantics, the certificate
checkers and the block checker. -/
@[default_target]
lean_lib MojoProof where
  globs := #[
    .submodules `MojoProof.LLVM,
    .submodules `MojoProof.Layout,
    .submodules `MojoProof.Sem,
    .submodules `MojoProof.Util,
    .submodules `MojoProof.Cert,
    .submodules `MojoProof.Float,
    .submodules `MojoProof.Sym,
    .submodules `MojoProof.Tile]

/-- The imported kernels (`mojo_import`) and their theorems. -/
@[default_target]
lean_lib MojoProofKernels where
  globs := #[.andSubmodules `MojoProof.Kernels]
  needs := #[corpus]

/-- A changed file and the manifest row of the file before the change: the digest refusal's
test input. -/
input_dir stale where
  path := "tests/stale"

/-- The test runner and the tests it runs. -/
lean_lib MojoProofTest where
  globs := #[.submodules `MojoProofTest]
  needs := #[corpus, stale]

/-- The test runner (`lake test`): SHA-256 vectors, refusals, and the corpus round trip. -/
lean_exe mojoproof_test where
  root := `MojoProofTest.Main
