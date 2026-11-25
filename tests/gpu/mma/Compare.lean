import MojoProofTest.TensorCoreGpu

/-!
# A GPU run of `mma.m16n8k16` with bfloat16 inputs against `mmaStep`

`lake env lean --run tests/gpu/mma/Compare.lean <dump> <launches>`: runs
`MojoProofTest.TensorCoreGpu.main`, which refuses a malformed dump or one with a number of
launches other than `<launches>` (exit code 2), evaluates `mmaStep` at `m16n8k16` on the
registers of each launch with `fuseAcc .bfloat16 .binary32 8 24` (`gridAcc`), with the sequential
policy `seqAcc .bfloat16 .binary32` (`bfAcc` in the output) and with the exact rational sum,
and compares the GPU's D registers with them: word for word with `fuseAcc`'s everywhere, word
for word with `bfAcc`'s where the order of the additions does not matter (kind 0), and it
counts the finite words within `dotBound .binary32 16` of the exact sum (exit code 0 when every
word is `fuseAcc`'s, every kind-0 word is `bfAcc`'s and the GPU wrote every word, 1
otherwise). The code is in `MojoProofTest/TensorCoreGpu.lean`, a module of the test
library.

A conformance test of one instruction on these inputs, not a proof.
-/

/-- The entry point of `lean --run`: `MojoProofTest.TensorCoreGpu.main` on the arguments. -/
def main (args : List String) : IO UInt32 := MojoProofTest.TensorCoreGpu.main args
