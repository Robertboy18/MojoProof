import MojoProofTest.AsyncGpu

/-!
# A GPU run of `cp.async` and its groups against `Async.lazyRun` and `Async.smem`

`lake env lean --run tests/gpu/cp-async/Compare.lean <dump> <launches>`: runs
`MojoProofTest.AsyncGpu.main`, which refuses a malformed dump or one with a number of launches
other than `<launches>` (exit code 2), evaluates `Async.smem` after `Async.lazyRun` of each
lane's copies, commits and waits on the global and initial shared words of each launch, and
compares the shared words the GPU read back after `wait_group 1` and after `wait_group 0` with
it (exit code 0 when all agree and the GPU wrote every word, 1 otherwise). The code is in
`MojoProofTest/AsyncGpu.lean`, a module of the test library.

A conformance test of one instruction and its groups on these inputs, not a proof.
-/

/-- The entry point of `lean --run`: `MojoProofTest.AsyncGpu.main` on the arguments. -/
def main (args : List String) : IO UInt32 := MojoProofTest.AsyncGpu.main args
