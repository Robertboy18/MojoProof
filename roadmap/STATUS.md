# Roadmap status

Written by `scripts/roadmap_status.py` from the cards and the code. Do not edit; run
`python3 scripts/roadmap_status.py` after changing a card or a declaration it names.
roadmap/README.md describes the cards and the levels.

## The construct ladder

| Level | Meaning | Evidence |
|---|---|---|
| L0 | card written | the card, with every check passing |
| L1 | modelled in Lean | the card's lean names |
| L2 | tested against the GPU: a conformance test of the model against the GPU on the recorded inputs, not a proof | a tracked record of a GPU run of a test of the construct that agrees (a file of this repository) |
| L3 | used by a proved kernel | a kernel card id whose card has L2 evidence |

## The kernel ladder

| Level | Meaning | Evidence |
|---|---|---|
| L0 | card written | the card, with every check passing |
| L1 | imported, and the evaluator agrees with a GPU run: a conformance test of the evaluator against the GPU on the recorded inputs, not a proof | a tracked record of a GPU run of the corpus kernel that agrees (a file of this repository) |
| L2 | memory safety and race freedom for every valid launch of the shape the theorem states | a Kernel.Sound theorem (declaration name); the launches its premises admit are listed per card |
| L3 | the outputs are the TorchLean operation's, under the theorem's premises | a theorem equating the output with the TorchLean operation (declaration name); its launch shape, and whether it needs a finite output and gives the real value rounded, are listed per card |
| L4 | an IEEE bound, or bit-exact | a theorem bounding the error, or giving the exact bits (declaration name); its premises are listed per card as for L3 |

## Summary

| Area | Cards | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|---|
| [Floats](floats/README.md) | 6 | 0 | 3 | 0 | 3 | 0 |
| [The GPU model](gpu-model/README.md) | 9 | 0 | 8 | 0 | 1 | 0 |
| [Kernels](kernels/README.md) | 13 | 9 | 0 | 0 | 0 | 4 |
| [Layout laws](layout/README.md) | 15 | 1 | 14 | 0 | 0 | 0 |
| [LLVM IR constructs](llvm-ir/README.md) | 64 | 8 | 36 | 0 | 20 | 0 |
| [std.math functions the corpus kernels call](std-math/README.md) | 3 | 0 | 3 | 0 | 0 | 0 |

Records of GPU runs the cards cite: 4.

## Floats

[floats/README.md](floats/README.md)

| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | Next | Corpus kernels |
|---|---|---|---|---|---|---|
| [binary-op-rounding](floats/cards/binary-op-rounding.md): the rounding of fadd, fsub, fmul and fdiv, to nearest even in the operation's format | construct | L3 | - | - | top level | 13 |
| [contract](floats/cards/contract.md): contract, the fast-math flag that lets fmul and fadd fuse into one rounding | construct | L3 | - | - | top level | 14 |
| [deliver](floats/cards/deliver.md): deliver, the result of a floating-point operation as a word, NaNs from the oracle | construct | L3 | - | - | top level | 0 |
| [maxnum-minnum](floats/cards/maxnum-minnum.md): llvm.maxnum and llvm.minnum, the floating-point maximum and minimum | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [nan-payloads](floats/cards/nan-payloads.md): NaN payloads, which NaN a floating-point operation may return | construct | L1 | L3 evidence present | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [rsqrt-approx](floats/cards/rsqrt-approx.md): rsqrt.approx.ftz.f32, the approximate reciprocal square root | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 34 |

## The GPU model

[gpu-model/README.md](gpu-model/README.md)

| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | Next | Corpus kernels |
|---|---|---|---|---|---|---|
| [address-spaces](gpu-model/cards/address-spaces.md): address spaces, the generic, global, shared and local spaces of a pointer | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [atomics](gpu-model/cards/atomics.md): atomics, atomicrmw with a commutative operation and an unused result | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [barriers](gpu-model/cards/barriers.md): the block barrier, bar.sync over the threads of a block | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [cp-async](gpu-model/cards/cp-async.md): cp.async, asynchronous copies from global to shared memory and their groups | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [launch](gpu-model/cards/launch.md): threads and the launch, the grid and blocks of threads and their special registers | construct | L3 | - | - | top level | 0 |
| [ldmatrix](gpu-model/cards/ldmatrix.md): ldmatrix, a warp's load of 8x8 matrices from shared memory | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [mma](gpu-model/cards/mma.md): mma, a warp's tensor-core multiply-accumulate | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [shared-memory](gpu-model/cards/shared-memory.md): shared memory, the static and dynamic shared blocks of a block of threads | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [warp-shuffles](gpu-model/cards/warp-shuffles.md): warp shuffles, shfl.sync of an i32 across the lanes of a warp | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |

## Kernels

[kernels/README.md](kernels/README.md)

| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | Next | Corpus kernels |
|---|---|---|---|---|---|---|
| [gemv](kernels/cards/gemv.md): gemv_kernel, a matrix-vector product (TorchLean.Tensor.matVecLoop) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 2 |
| [layernorm](kernels/cards/layernorm.md): layer_norm_gpu, the 34 row-wise layer norm specializations (TorchLean.Tensor.layerNorm) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 34 |
| [layout-mma](kernels/cards/layout-mma.md): the layout tensor-core tests, mma_layout_tc, matmul_naive and c_fragment_kernel (TorchLean.Tensor.matmul) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 13 |
| [multistage-gemm](kernels/cards/multistage-gemm.md): multistage_gemm, the tiled tensor-core GEMM with asynchronous copies (TorchLean.Tensor.matmul) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 24 |
| [naive-matmul](kernels/cards/naive-matmul.md): matmul_kernel_naive, one thread per output cell of C = A B (TorchLean.Tensor.matmul) | kernel | L4 | - | L2: valid launches with block and grid of side 1 in z; L3: valid launches with block and grid of side 1 in z, NaiveKernel.matmul_nanEq only for a thread whose oracle fuses no round (no oracle number 2 modulo 3); L4: valid launches with block and grid of side 1 in z, where the output is finite | top level | 24 |
| [reduction](kernels/cards/reduction.md): sum_kernel, a block sum in shared memory with one atomic add per block (TorchLean.Tensor.sum) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 1 |
| [rms-norm](kernels/cards/rms-norm.md): rms_norm_gpu, root mean square normalization (TorchLean.Tensor.rmsNorm) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [softmax](kernels/cards/softmax.md): softmax_kernel, the row-wise softmax (TorchLean.Tensor.softmax) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [split-k-reduce](kernels/cards/split-k-reduce.md): matmul split-k reduce, the sum of the partial products of a split GEMM (TorchLean.Tensor.sum) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 12 |
| [tiled-matmul](kernels/cards/tiled-matmul.md): tiled_matmul_kernel, a matmul by shared-memory tiles (TorchLean.Tensor.matmul) | kernel | L0 | - | - | L1 needs a recorded GPU run (a conformance test, not a proof) | 1 |
| [vadd](kernels/cards/vadd.md): vector_addition, the elementwise sum of two float32 vectors (TorchLean.Tensor.add) | kernel | L4 | - | L2: valid one-dimensional launches (block and grid of side 1 in y and z); L3, L4: valid one-dimensional launches (block and grid of side 1 in y and z), where the output is finite and is the exact real result rounded to the format | top level | 1 |
| [vmul](kernels/cards/vmul.md): vector_multiply, the elementwise product of two float32 vectors (TorchLean.Tensor.mul) | kernel | L4 | - | L2: valid one-dimensional launches (block and grid of side 1 in y and z); L3, L4: valid one-dimensional launches (block and grid of side 1 in y and z), where the output is finite and is the exact real result rounded to the format | top level | 1 |
| [vsub](kernels/cards/vsub.md): vector_subtraction, the tutorial's elementwise difference of two float32 vectors (TorchLean.Tensor.sub) | kernel | L4 | - | L2: valid one-dimensional launches (block and grid of side 1 in y and z); L3, L4: valid one-dimensional launches (block and grid of side 1 in y and z), where the output is finite and is the exact real result rounded to the format | top level | 1 |

## Layout laws

[layout/README.md](layout/README.md)

| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | Next | Corpus kernels |
|---|---|---|---|---|---|---|
| [bit-layout](layout/cards/bit-layout.md): A layout whose extents are powers of two is linear over F2 | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [blocked-product](layout/cards/blocked-product.md): `blocked_product`'s outer stride is documented as the block's cosize times the tiler's stride | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [coalesce](layout/cards/coalesce.md): `coalesce` keeps the offsets and merges contiguous modes | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [composition](layout/cards/composition.md): `composition(a, b)` maps a coordinate through `b`, then `a` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [cosize](layout/cards/cosize.md): `cosize` is the offset of the last coordinate plus one | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [crd2idx](layout/cards/crd2idx.md): `crd2idx` is the dot product of a coordinate with the strides | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [idx2crd](layout/cards/idx2crd.md): `idx2crd` maps an offset back to a coordinate, documented as the inverse of `crd2idx` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [index-width](layout/cards/index-width.md): With a narrow index type the caller must ensure products and sums fit | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [is-affine](layout/cards/is-affine.md): Stepping by a stride is exact only for an affine layout | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [reverse-transpose](layout/cards/reverse-transpose.md): `reverse` and `transpose` reverse the shape and the stride | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [row-major-views](layout/cards/row-major-views.md): `TileTensor.as_span`, `reshape` and `coalesce` need row-major contiguous strides | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [swizzle](layout/cards/swizzle.md): `Swizzle` is `x ^ ((x & mask) >> shift)` and needs `abs(shift) >= bits` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [two-level-swizzle](layout/cards/two-level-swizzle.md): `two_level_layout_from_swizzle` evaluates to `Swizzle(L(x))` | construct | L0 | - | - | L1 needs a Lean model | 0 |
| [upcast](layout/cards/upcast.md): `upcast` divides strides and shapes by the factor with `shape_div` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |
| [zipped-divide](layout/cards/zipped-divide.md): `zipped_divide` splits a layout into tile and number-of-tiles modes | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 0 |

## LLVM IR constructs

[llvm-ir/README.md](llvm-ir/README.md)

| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | Next | Corpus kernels |
|---|---|---|---|---|---|---|
| [asm-cp-async-cg-shared-global-3](llvm-ir/cards/asm-cp-async-cg-shared-global-3.md): Inline asm `cp.async.cg.shared.global` with 3 operands | construct | L0 | - | - | L1 needs a Lean model | 5 |
| [asm-cp-async-cg-shared-global-4](llvm-ir/cards/asm-cp-async-cg-shared-global-4.md): Inline asm `cp.async.cg.shared.global` with 4 operands | construct | L0 | - | - | L1 needs a Lean model | 5 |
| [inst-add](llvm-ir/cards/inst-add.md): The `add` instruction | construct | L3 | - | - | top level | 5 |
| [inst-addrspacecast](llvm-ir/cards/inst-addrspacecast.md): The `addrspacecast` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-alloca](llvm-ir/cards/inst-alloca.md): The `alloca` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-and](llvm-ir/cards/inst-and.md): The `and` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-ashr](llvm-ir/cards/inst-ashr.md): The `ashr` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-atomicrmw](llvm-ir/cards/inst-atomicrmw.md): The `atomicrmw` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 1 |
| [inst-bitcast](llvm-ir/cards/inst-bitcast.md): The `bitcast` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-call](llvm-ir/cards/inst-call.md): The `call` instruction | construct | L3 | - | - | top level | 5 |
| [inst-extractelement](llvm-ir/cards/inst-extractelement.md): The `extractelement` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-extractvalue](llvm-ir/cards/inst-extractvalue.md): The `extractvalue` instruction | construct | L3 | - | - | top level | 5 |
| [inst-fadd](llvm-ir/cards/inst-fadd.md): The `fadd` instruction | construct | L3 | - | - | top level | 5 |
| [inst-fdiv](llvm-ir/cards/inst-fdiv.md): The `fdiv` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-fmul](llvm-ir/cards/inst-fmul.md): The `fmul` instruction | construct | L3 | - | - | top level | 5 |
| [inst-fpext](llvm-ir/cards/inst-fpext.md): The `fpext` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-fptrunc](llvm-ir/cards/inst-fptrunc.md): The `fptrunc` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-fsub](llvm-ir/cards/inst-fsub.md): The `fsub` instruction | construct | L3 | - | - | top level | 5 |
| [inst-getelementptr](llvm-ir/cards/inst-getelementptr.md): The `getelementptr` instruction | construct | L3 | - | - | top level | 5 |
| [inst-icmp](llvm-ir/cards/inst-icmp.md): The `icmp` instruction | construct | L3 | - | - | top level | 5 |
| [inst-insertelement](llvm-ir/cards/inst-insertelement.md): The `insertelement` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-insertvalue](llvm-ir/cards/inst-insertvalue.md): The `insertvalue` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-load](llvm-ir/cards/inst-load.md): The `load` instruction | construct | L3 | - | - | top level | 5 |
| [inst-lshr](llvm-ir/cards/inst-lshr.md): The `lshr` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-mul](llvm-ir/cards/inst-mul.md): The `mul` instruction | construct | L3 | - | - | top level | 5 |
| [inst-or](llvm-ir/cards/inst-or.md): The `or` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-phi](llvm-ir/cards/inst-phi.md): The `phi` instruction | construct | L3 | - | - | top level | 5 |
| [inst-ptrtoint](llvm-ir/cards/inst-ptrtoint.md): The `ptrtoint` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-sdiv](llvm-ir/cards/inst-sdiv.md): The `sdiv` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-select](llvm-ir/cards/inst-select.md): The `select` instruction | construct | L3 | - | - | top level | 5 |
| [inst-sext](llvm-ir/cards/inst-sext.md): The `sext` instruction | construct | L3 | - | - | top level | 5 |
| [inst-shl](llvm-ir/cards/inst-shl.md): The `shl` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-shufflevector](llvm-ir/cards/inst-shufflevector.md): The `shufflevector` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-sitofp](llvm-ir/cards/inst-sitofp.md): The `sitofp` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 3 |
| [inst-store](llvm-ir/cards/inst-store.md): The `store` instruction | construct | L3 | - | - | top level | 5 |
| [inst-sub](llvm-ir/cards/inst-sub.md): The `sub` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-trunc](llvm-ir/cards/inst-trunc.md): The `trunc` instruction | construct | L3 | - | - | top level | 5 |
| [inst-udiv](llvm-ir/cards/inst-udiv.md): The `udiv` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-urem](llvm-ir/cards/inst-urem.md): The `urem` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-xor](llvm-ir/cards/inst-xor.md): The `xor` instruction | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [inst-zext](llvm-ir/cards/inst-zext.md): The `zext` instruction | construct | L3 | - | - | top level | 5 |
| [intrinsic-barrier](llvm-ir/cards/intrinsic-barrier.md): The intrinsic family `Intrinsic.barrier` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-cpasynccommit](llvm-ir/cards/intrinsic-cpasynccommit.md): The intrinsic family `Intrinsic.cpAsyncCommit` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-cpasyncwait](llvm-ir/cards/intrinsic-cpasyncwait.md): The intrinsic family `Intrinsic.cpAsyncWait` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-extract](llvm-ir/cards/intrinsic-extract.md): The intrinsic family `Intrinsic.extract` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-fminmax](llvm-ir/cards/intrinsic-fminmax.md): The intrinsic family `Intrinsic.fminmax` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-griddeplaunch](llvm-ir/cards/intrinsic-griddeplaunch.md): The intrinsic family `Intrinsic.griddepLaunch` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-griddepwait](llvm-ir/cards/intrinsic-griddepwait.md): The intrinsic family `Intrinsic.griddepWait` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-laneid](llvm-ir/cards/intrinsic-laneid.md): The intrinsic family `Intrinsic.laneid` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-ldmatrix](llvm-ir/cards/intrinsic-ldmatrix.md): The intrinsic family `Intrinsic.ldmatrix` | construct | L0 | - | - | L1 needs a Lean model | 5 |
| [intrinsic-lifetime](llvm-ir/cards/intrinsic-lifetime.md): The intrinsic family `Intrinsic.lifetime` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-minmax](llvm-ir/cards/intrinsic-minmax.md): The intrinsic family `Intrinsic.minmax` | construct | L3 | - | - | top level | 5 |
| [intrinsic-mma](llvm-ir/cards/intrinsic-mma.md): The intrinsic family `Intrinsic.mma` | construct | L0 | - | - | L1 needs a Lean model | 5 |
| [intrinsic-reduceand](llvm-ir/cards/intrinsic-reduceand.md): The intrinsic family `Intrinsic.reduceAnd` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-rsqrtapprox](llvm-ir/cards/intrinsic-rsqrtapprox.md): The intrinsic family `Intrinsic.rsqrtApprox` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-shfl](llvm-ir/cards/intrinsic-shfl.md): The intrinsic family `Intrinsic.shfl` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [intrinsic-sreg](llvm-ir/cards/intrinsic-sreg.md): The intrinsic family `Intrinsic.sreg` | construct | L3 | - | - | top level | 5 |
| [intrinsic-stepvector](llvm-ir/cards/intrinsic-stepvector.md): The intrinsic family `Intrinsic.stepvector` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 5 |
| [refused-asm-cvt-rn-f16x2-e4m3x2-2](llvm-ir/cards/refused-asm-cvt-rn-f16x2-e4m3x2-2.md): Refused: inline asm `cvt.rn.f16x2.e4m3x2` with 2 operands | construct | L0 | - | - | L1 needs a Lean model | 4 |
| [refused-asm-cvt-rn-satfinite-e4m3x2-f32-3](llvm-ir/cards/refused-asm-cvt-rn-satfinite-e4m3x2-f32-3.md): Refused: inline asm `cvt.rn.satfinite.e4m3x2.f32` with 3 operands | construct | L0 | - | - | L1 needs a Lean model | 3 |
| [refused-load-atomic](llvm-ir/cards/refused-load-atomic.md): Refused: `load atomic` | construct | L0 | - | - | L1 needs a Lean model | 0 |
| [refused-store-atomic](llvm-ir/cards/refused-store-atomic.md): Refused: `store atomic` | construct | L0 | - | - | L1 needs a Lean model | 0 |
| [term-br](llvm-ir/cards/term-br.md): The `br` terminator | construct | L3 | - | - | top level | 5 |
| [term-ret](llvm-ir/cards/term-ret.md): The `ret` terminator | construct | L3 | - | - | top level | 5 |

## std.math functions the corpus kernels call

[std-math/README.md](std-math/README.md)

| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | Next | Corpus kernels |
|---|---|---|---|---|---|---|
| [max](std-math/cards/max.md): `std.math.max` on SIMD values: `llvm.maxnum` on floats, `llvm.smax` on signed integers | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 44 |
| [min](std-math/cards/min.md): `std.math.min` on SIMD values: `llvm.smin` on signed integers | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 37 |
| [rsqrt](std-math/cards/rsqrt.md): `std.math.rsqrt` on float32 on the GPU is `llvm.nvvm.rsqrt.approx.ftz.f` | construct | L1 | - | - | L2 needs a recorded GPU run (a conformance test, not a proof) | 34 |
