import MojoProofTest.Gpu

/-!
# A GPU run against the evaluator

`lake env lean --run tests/gpu/Compare.lean <kernel> <dump> <launches>`, for `<kernel>` one of
`vadd`, `vmul`, `vsub` (1-D launches) and `naive` (the naive matmul kernel, 2-D launches with
sizes `m`, `n`, `K`): runs `MojoProofTest.Gpu.main`, which refuses a dump with no launch or with
a number of launches other than `<launches>` (exit code 1), runs the grid evaluator on the inputs
of each launch of the dump and compares its output buffer with the GPU's word for word (exit code
0 when every launch agrees, 1 otherwise). The code is in `MojoProofTest/Gpu.lean`, a module of
the test library, so `lake build MojoProofTest` compiles it; the test executable runs the same
code compiled, `mojoproof_test gpu <kernel> <dump> <launches>`.

A conformance test of one compiled kernel on these inputs, not a proof.
-/

/-- The entry point of `lean --run`: `MojoProofTest.Gpu.main` on the arguments. -/
def main (args : List String) : IO UInt32 := MojoProofTest.Gpu.main args
