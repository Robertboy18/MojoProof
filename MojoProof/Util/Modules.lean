import Lean

/-!
# The modules of a source directory

`modulesIn dir` lists the module names of the Lean files under `dir`, a directory relative to the
working directory, so that a script run from the repository's root can import every module of a
library. scripts/Audit.lean and scripts/L3Programs.lean use it (under `GPUProof/`, `MojoProof/`
and `MojoProofTest/`); it is listed in scripts/targets.txt, since no declaration uses it.

This module is executable code with no theorems.
-/

namespace MojoProof.Util

/-- Module names of the `.lean` files under `dir` (relative to the working directory): the file
`A/B/C.lean` is the module `A.B.C`. The entries of a directory come in the order
`System.FilePath.readDir` gives, a subdirectory's modules in its place. -/
partial def modulesIn (dir : System.FilePath) : IO (Array Lean.Name) := do
  let mut acc := #[]
  for e in ← dir.readDir do
    if ← e.path.isDir then acc := acc ++ (← modulesIn e.path)
    else if e.path.extension == some "lean" then
      let parts := (e.path.withExtension "").components
      acc := acc.push (parts.foldl (fun n s => if s == "." then n else .str n s) .anonymous)
  return acc

end MojoProof.Util
