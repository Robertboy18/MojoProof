# std.math functions the corpus kernels call

## Scope

The functions of Mojo's `std.math` whose lowering appears in the corpus IR, with each function's contract as the Modular source at bbc13a71 states it and the Lean declaration of that contract. A function is in scope if the corpus IR has the intrinsic it lowers to: `rsqrt` (`llvm.nvvm.rsqrt.approx.ftz.f`), `max` (`llvm.maxnum`, `llvm.smax`) and `min` (`llvm.smin`).

## Items

- [rsqrt](cards/rsqrt.md): `std.math.rsqrt` on float32 on the GPU is `llvm.nvvm.rsqrt.approx.ftz.f`
- [max](cards/max.md): `std.math.max` on SIMD values: `llvm.maxnum` on floats, `llvm.smax` on signed integers
- [min](cards/min.md): `std.math.min` on SIMD values: `llvm.smin` on signed integers

## Out of scope

- The functions whose lowering no corpus file has (for example `exp`, `sqrt` and `log`).
- The CPU lowering of every function.
- Which source call produced a given intrinsic call: the compiler lowers `pop.max` and `pop.min`, and we cannot see that step. The IR also does not name the source function, so the corpus counts are counts of intrinsic calls.

## Depends on

The llvm-ir cards for the intrinsics (`intrinsic-rsqrtapprox`, `intrinsic-fminmax`, `intrinsic-minmax`) and the reading of LangRef and PTX ISA (docs/TRUST.md T7, T10).

## Coverage in MojoProof

Every card is L1: its contract is stated in Lean (`MojoProof.Sem.rsqrtOk`, `MojoProof.Sem.maxnum`, `MojoProof.Sem.intMinMax`). No card is L2, since no GPU run is recorded, and so none is L3.

## Next steps

- A recorded GPU run of each contract, for L2: the 2^-22.9 bound of `rsqrt` and the NaN cases of `maxnum`.
- A card per function as more corpus kernels call `std.math`.
