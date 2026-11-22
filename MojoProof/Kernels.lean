import MojoProof.LLVM.Corpus

/-!
# Imported corpus kernels

The programs of corpus kernels as Lean terms, imported by mojo_corpus (MojoProof/LLVM/Corpus.lean:
each term checked against the importer when this module is built, the digest the manifest's), in
this order, which fixes the names of the functions they share:

* `vadd.prog`: `vector_addition` (`tests/corpus/vadd/`);
* `vmul.prog`: vector_multiply (`tests/corpus/vmul/`), written for this library, not taken from
  upstream: `vector_addition` with `*` for `+`, compiled with contraction off;
* `matmul.prog`: `tiled_matmul` (`tests/corpus/tiled_matmul/`).
-/

namespace MojoProof.Kernels

mojo_corpus "vadd" as vadd "vmul" as vmul "tiled_matmul" as matmul

end MojoProof.Kernels
