# LLVM IR constructs

Written by `scripts/roadmap_llvm.py` from the importer, the rule table, the corpus and its refusals. Do not edit; run `python3 scripts/roadmap_llvm.py` after changing one of them.

## Scope

The LLVM IR the 127 corpus files use: every opcode the importer reads that some corpus file uses, every intrinsic family some corpus file calls, every form of inline assembly the importer accepts, and every construct the importer refuses. The corpus IR declares no LLVM version (it has no `llvm.ident`); the cards cite the LangRef and PTX ISA versions the semantics was read from (LangRef 24.0.0git, PTX ISA 9.5, docs/TRUST.md T7). An opcode or family card is L1 when its `lean` names exist and the semantics runs the construct: the grid evaluator runs a kernel of it until every thread returns, the row `returns` of the table MojoProofTest/Modelled.lean pins (its build checks the table). A construct the importer reads and the semantics stops at (with `unsupported` or another fault) is L0, parsed but not modelled, and its card says so.

## Items

### Opcodes

- [inst-add](cards/inst-add.md): The `add` instruction (tested against the GPU, used by a proved kernel)
- [inst-addrspacecast](cards/inst-addrspacecast.md): The `addrspacecast` instruction
- [inst-alloca](cards/inst-alloca.md): The `alloca` instruction
- [inst-and](cards/inst-and.md): The `and` instruction
- [inst-ashr](cards/inst-ashr.md): The `ashr` instruction
- [inst-atomicrmw](cards/inst-atomicrmw.md): The `atomicrmw` instruction
- [inst-bitcast](cards/inst-bitcast.md): The `bitcast` instruction
- [term-br](cards/term-br.md): The `br` terminator (tested against the GPU, used by a proved kernel)
- [inst-call](cards/inst-call.md): The `call` instruction (tested against the GPU, used by a proved kernel)
- [inst-extractelement](cards/inst-extractelement.md): The `extractelement` instruction
- [inst-extractvalue](cards/inst-extractvalue.md): The `extractvalue` instruction (tested against the GPU, used by a proved kernel)
- [inst-fadd](cards/inst-fadd.md): The `fadd` instruction (tested against the GPU, used by a proved kernel)
- [inst-fdiv](cards/inst-fdiv.md): The `fdiv` instruction
- [inst-fmul](cards/inst-fmul.md): The `fmul` instruction (tested against the GPU, used by a proved kernel)
- [inst-fpext](cards/inst-fpext.md): The `fpext` instruction
- [inst-fptrunc](cards/inst-fptrunc.md): The `fptrunc` instruction
- [inst-fsub](cards/inst-fsub.md): The `fsub` instruction (tested against the GPU, used by a proved kernel)
- [inst-getelementptr](cards/inst-getelementptr.md): The `getelementptr` instruction (tested against the GPU, used by a proved kernel)
- [inst-icmp](cards/inst-icmp.md): The `icmp` instruction (tested against the GPU, used by a proved kernel)
- [inst-insertelement](cards/inst-insertelement.md): The `insertelement` instruction
- [inst-insertvalue](cards/inst-insertvalue.md): The `insertvalue` instruction
- [inst-load](cards/inst-load.md): The `load` instruction (tested against the GPU, used by a proved kernel)
- [inst-lshr](cards/inst-lshr.md): The `lshr` instruction
- [inst-mul](cards/inst-mul.md): The `mul` instruction (tested against the GPU, used by a proved kernel)
- [inst-or](cards/inst-or.md): The `or` instruction
- [inst-phi](cards/inst-phi.md): The `phi` instruction (tested against the GPU, used by a proved kernel)
- [inst-ptrtoint](cards/inst-ptrtoint.md): The `ptrtoint` instruction
- [term-ret](cards/term-ret.md): The `ret` terminator (tested against the GPU, used by a proved kernel)
- [inst-sdiv](cards/inst-sdiv.md): The `sdiv` instruction
- [inst-select](cards/inst-select.md): The `select` instruction (tested against the GPU, used by a proved kernel)
- [inst-sext](cards/inst-sext.md): The `sext` instruction (tested against the GPU, used by a proved kernel)
- [inst-shl](cards/inst-shl.md): The `shl` instruction
- [inst-shufflevector](cards/inst-shufflevector.md): The `shufflevector` instruction
- [inst-sitofp](cards/inst-sitofp.md): The `sitofp` instruction
- [inst-store](cards/inst-store.md): The `store` instruction (tested against the GPU, used by a proved kernel)
- [inst-sub](cards/inst-sub.md): The `sub` instruction
- [inst-trunc](cards/inst-trunc.md): The `trunc` instruction (tested against the GPU, used by a proved kernel)
- [inst-udiv](cards/inst-udiv.md): The `udiv` instruction
- [inst-urem](cards/inst-urem.md): The `urem` instruction
- [inst-xor](cards/inst-xor.md): The `xor` instruction
- [inst-zext](cards/inst-zext.md): The `zext` instruction (tested against the GPU, used by a proved kernel)

### Intrinsic families

- [intrinsic-sreg](cards/intrinsic-sreg.md): The intrinsic family `Intrinsic.sreg` (tested against the GPU, used by a proved kernel)
- [intrinsic-laneid](cards/intrinsic-laneid.md): The intrinsic family `Intrinsic.laneid`
- [intrinsic-barrier](cards/intrinsic-barrier.md): The intrinsic family `Intrinsic.barrier`
- [intrinsic-shfl](cards/intrinsic-shfl.md): The intrinsic family `Intrinsic.shfl`
- [intrinsic-minmax](cards/intrinsic-minmax.md): The intrinsic family `Intrinsic.minmax` (tested against the GPU, used by a proved kernel)
- [intrinsic-fminmax](cards/intrinsic-fminmax.md): The intrinsic family `Intrinsic.fminmax`
- [intrinsic-rsqrtapprox](cards/intrinsic-rsqrtapprox.md): The intrinsic family `Intrinsic.rsqrtApprox`
- [intrinsic-lifetime](cards/intrinsic-lifetime.md): The intrinsic family `Intrinsic.lifetime`
- [intrinsic-reduceand](cards/intrinsic-reduceand.md): The intrinsic family `Intrinsic.reduceAnd`
- [intrinsic-extract](cards/intrinsic-extract.md): The intrinsic family `Intrinsic.extract`
- [intrinsic-stepvector](cards/intrinsic-stepvector.md): The intrinsic family `Intrinsic.stepvector`
- [intrinsic-griddepwait](cards/intrinsic-griddepwait.md): The intrinsic family `Intrinsic.griddepWait`
- [intrinsic-griddeplaunch](cards/intrinsic-griddeplaunch.md): The intrinsic family `Intrinsic.griddepLaunch`
- [intrinsic-cpasynccommit](cards/intrinsic-cpasynccommit.md): The intrinsic family `Intrinsic.cpAsyncCommit`
- [intrinsic-cpasyncwait](cards/intrinsic-cpasyncwait.md): The intrinsic family `Intrinsic.cpAsyncWait`
- [intrinsic-ldmatrix](cards/intrinsic-ldmatrix.md): The intrinsic family `Intrinsic.ldmatrix` (parsed, not modelled)
- [intrinsic-mma](cards/intrinsic-mma.md): The intrinsic family `Intrinsic.mma` (parsed, not modelled)

### Accepted inline assembly

- [asm-cp-async-cg-shared-global-3](cards/asm-cp-async-cg-shared-global-3.md): Inline asm `cp.async.cg.shared.global` with 3 operands (parsed, not modelled)
- [asm-cp-async-cg-shared-global-4](cards/asm-cp-async-cg-shared-global-4.md): Inline asm `cp.async.cg.shared.global` with 4 operands (parsed, not modelled)

### Refused constructs

- [refused-asm-cvt-rn-f16x2-e4m3x2-2](cards/refused-asm-cvt-rn-f16x2-e4m3x2-2.md): Refused: inline asm `cvt.rn.f16x2.e4m3x2` with 2 operands
- [refused-asm-cvt-rn-satfinite-e4m3x2-f32-3](cards/refused-asm-cvt-rn-satfinite-e4m3x2-f32-3.md): Refused: inline asm `cvt.rn.satfinite.e4m3x2.f32` with 3 operands
- [refused-load-atomic](cards/refused-load-atomic.md): Refused: `load atomic`
- [refused-store-atomic](cards/refused-store-atomic.md): Refused: `store atomic`

## Out of scope

Opcodes the importer reads (51 keywords) that no corpus file uses, and intrinsic families no corpus file calls: the cards follow the corpus. Calls of functions defined in the module are calls, not intrinsics, and have no card of their own.

## Depends on

The corpus (tests/corpus/MANIFEST.tsv) and the importer's tables; the reading of LangRef and PTX ISA (docs/TRUST.md T7, T9, T10).

## Coverage in MojoProof

56 of the 58 opcode and family cards are L1: the importer reads the construct, `MojoProof.Sem.exec`, `MojoProof.Sem.step` or `MojoProof.Sem.intrinsic` gives it a meaning, and the grid evaluator runs a kernel of it to the end (MojoProofTest/Modelled.lean); the card repeats the block checker's rules and refusals for its constructors. The `intrinsic-ldmatrix` and `intrinsic-mma` cards are L0, parsed but not modelled: the semantics stops a run at the construct. The accepted inline asm cards `asm-cp-async-cg-shared-global-3` and `asm-cp-async-cg-shared-global-4` are L0: the importer accepts the call, and `MojoProof.Sem.exec` stops a run at it. The refused constructs are L0. 20 of the L1 cards are L2: a record of a GPU run that agrees with the evaluator ran a corpus kernel whose IR uses the construct (tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt; a conformance test, not a proof). 20 of the L2 cards are L3: a kernel card with L2 evidence, a proved kernel, has a `Kernel.Sound` theorem about a program whose IR uses the construct. The proved kernels, their L2 theorems and the corpus files of the programs those are about (the program of the elaborated conclusion and the corpus file of the imported program it unfolds to, programs.tsv, which scripts/L3Programs.lean writes; the other files a kernel card cites do not count): naive-matmul: `MojoProofTest.NaiveKernel.correct` (tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll), `MojoProofTest.NaiveOff.correct` (tests/corpus/mgemm_nocontract/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll); vadd: `MojoProof.Kernels.vadd.correct` (tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll); vmul: `MojoProof.Kernels.vmul.correct` (tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll); vsub: `MojoProof.Kernels.vsub.correct` (tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll). L3 here means used by a proved kernel, not that the construct has a theorem of its own: a kernel's theorem covers the forms of the construct in the IR of its program, at the launches and on the memories its premises admit, and no other form.

## Next steps

- A recorded GPU run of a kernel that uses the construct, for L2 of the L1 cards that are not L2.
- A semantics of the constructs parsed but not modelled (`intrinsic-ldmatrix`, `intrinsic-mma`), for L1.
- A model of the refused inline asm (`cvt` to and from e4m3), so the refused files import, and a semantics of the accepted `cp.async.cg` copies, for L1 of their cards.
- The block checker's refusals listed in each card, which bound what a proved kernel can use today.
