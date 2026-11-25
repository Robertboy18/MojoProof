import MojoProofTest.TensorCoreGpu

/-!
# A GPU run of `ldmatrix.x4` and `ldmatrix.x4.trans` against `ldmatrix`

`lake env lean --run tests/gpu/ldmatrix/Compare.lean <dump> <launches>`: runs
`MojoProofTest.TensorCoreGpu.ldmMain`, which refuses a malformed dump or one with a number of
launches other than `<launches>` (exit code 2), evaluates `ldmatrix 4` on the shared memory and
row addresses of each launch, plain and transposed, and compares every 16-bit element of the
GPU's registers with it (exit code 0 when all agree and the GPU wrote every register, 1
otherwise). The code is in `MojoProofTest/TensorCoreGpu.lean`, a module of the test library.

A conformance test of one instruction on these inputs, not a proof.
-/

/-- The entry point of `lean --run`: `MojoProofTest.TensorCoreGpu.ldmMain` on the arguments. -/
def main (args : List String) : IO UInt32 := MojoProofTest.TensorCoreGpu.ldmMain args
