# LLVM IR constructs

Written by `scripts/roadmap_llvm.py` from the importer, the rule table, the corpus and its refusals. Do not edit; run `python3 scripts/roadmap_llvm.py` after changing one of them.

## Scope

The LLVM IR the 111 corpus files use: every opcode the importer reads that some corpus file uses, every intrinsic family some corpus file calls, and every construct the importer refuses. The corpus IR declares no LLVM version (it has no `llvm.ident`); the cards cite the LangRef and PTX ISA versions the semantics was read from (LangRef 24.0.0git, PTX ISA 9.5, docs/TRUST.md T7). A card is L1 when its `lean` names exist.

## Items

### Opcodes

- [inst-add](cards/inst-add.md): The `add` instruction
- [inst-addrspacecast](cards/inst-addrspacecast.md): The `addrspacecast` instruction
- [inst-alloca](cards/inst-alloca.md): The `alloca` instruction
- [inst-and](cards/inst-and.md): The `and` instruction
- [inst-ashr](cards/inst-ashr.md): The `ashr` instruction
- [inst-atomicrmw](cards/inst-atomicrmw.md): The `atomicrmw` instruction
- [inst-bitcast](cards/inst-bitcast.md): The `bitcast` instruction
- [term-br](cards/term-br.md): The `br` terminator
- [inst-call](cards/inst-call.md): The `call` instruction
- [inst-extractelement](cards/inst-extractelement.md): The `extractelement` instruction
- [inst-extractvalue](cards/inst-extractvalue.md): The `extractvalue` instruction
- [inst-fadd](cards/inst-fadd.md): The `fadd` instruction
- [inst-fdiv](cards/inst-fdiv.md): The `fdiv` instruction
- [inst-fmul](cards/inst-fmul.md): The `fmul` instruction
- [inst-fpext](cards/inst-fpext.md): The `fpext` instruction
- [inst-fptrunc](cards/inst-fptrunc.md): The `fptrunc` instruction
- [inst-fsub](cards/inst-fsub.md): The `fsub` instruction
- [inst-getelementptr](cards/inst-getelementptr.md): The `getelementptr` instruction
- [inst-icmp](cards/inst-icmp.md): The `icmp` instruction
- [inst-insertelement](cards/inst-insertelement.md): The `insertelement` instruction
- [inst-insertvalue](cards/inst-insertvalue.md): The `insertvalue` instruction
- [inst-load](cards/inst-load.md): The `load` instruction
- [inst-lshr](cards/inst-lshr.md): The `lshr` instruction
- [inst-mul](cards/inst-mul.md): The `mul` instruction
- [inst-or](cards/inst-or.md): The `or` instruction
- [inst-phi](cards/inst-phi.md): The `phi` instruction
- [inst-ptrtoint](cards/inst-ptrtoint.md): The `ptrtoint` instruction
- [term-ret](cards/term-ret.md): The `ret` terminator
- [inst-sdiv](cards/inst-sdiv.md): The `sdiv` instruction
- [inst-select](cards/inst-select.md): The `select` instruction
- [inst-sext](cards/inst-sext.md): The `sext` instruction
- [inst-shl](cards/inst-shl.md): The `shl` instruction
- [inst-shufflevector](cards/inst-shufflevector.md): The `shufflevector` instruction
- [inst-sitofp](cards/inst-sitofp.md): The `sitofp` instruction
- [inst-store](cards/inst-store.md): The `store` instruction
- [inst-sub](cards/inst-sub.md): The `sub` instruction
- [inst-trunc](cards/inst-trunc.md): The `trunc` instruction
- [inst-udiv](cards/inst-udiv.md): The `udiv` instruction
- [inst-urem](cards/inst-urem.md): The `urem` instruction
- [inst-xor](cards/inst-xor.md): The `xor` instruction
- [inst-zext](cards/inst-zext.md): The `zext` instruction

### Intrinsic families

- [intrinsic-sreg](cards/intrinsic-sreg.md): The intrinsic family `Intrinsic.sreg`
- [intrinsic-laneid](cards/intrinsic-laneid.md): The intrinsic family `Intrinsic.laneid`
- [intrinsic-barrier](cards/intrinsic-barrier.md): The intrinsic family `Intrinsic.barrier`
- [intrinsic-shfl](cards/intrinsic-shfl.md): The intrinsic family `Intrinsic.shfl`
- [intrinsic-minmax](cards/intrinsic-minmax.md): The intrinsic family `Intrinsic.minmax`
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
- [intrinsic-ldmatrix](cards/intrinsic-ldmatrix.md): The intrinsic family `Intrinsic.ldmatrix`
- [intrinsic-mma](cards/intrinsic-mma.md): The intrinsic family `Intrinsic.mma`

### Refused constructs

- [refused-asm-cp-async-cg-shared-global-4](cards/refused-asm-cp-async-cg-shared-global-4.md): Refused: inline asm `cp.async.cg.shared.global` with 4 operands
- [refused-asm-cp-async-cg-shared-global-3](cards/refused-asm-cp-async-cg-shared-global-3.md): Refused: inline asm `cp.async.cg.shared.global` with 3 operands
- [refused-asm-cvt-rn-f16x2-e4m3x2-2](cards/refused-asm-cvt-rn-f16x2-e4m3x2-2.md): Refused: inline asm `cvt.rn.f16x2.e4m3x2` with 2 operands
- [refused-asm-cvt-rn-satfinite-e4m3x2-f32-3](cards/refused-asm-cvt-rn-satfinite-e4m3x2-f32-3.md): Refused: inline asm `cvt.rn.satfinite.e4m3x2.f32` with 3 operands
- [refused-load-atomic](cards/refused-load-atomic.md): Refused: `load atomic`
- [refused-store-atomic](cards/refused-store-atomic.md): Refused: `store atomic`

## Out of scope

Opcodes the importer reads (51 keywords) that no corpus file uses, and intrinsic families no corpus file calls: the cards follow the corpus. Calls of functions defined in the module are calls, not intrinsics, and have no card of their own.

## Depends on

The corpus (tests/corpus/MANIFEST.tsv) and the importer's tables; the reading of LangRef and PTX ISA (docs/TRUST.md T7, T9, T10).

## Coverage in MojoProof

Every opcode and family card is L1: the importer reads it, `MojoProof.Sem.exec`, `MojoProof.Sem.step` or `MojoProof.Sem.intrinsic` gives it a meaning, and the card repeats the block checker's rules and refusals for its constructors. The refused constructs are L0. No card is L2, since no GPU run is recorded, and so none is L3.

## Next steps

- A recorded GPU run per construct, for L2.
- A model of the refused inline asm (`cvt` to e4m3 and `cp.async.cg`), so the refused files import.
- The block checker's refusals listed in each card, which bound what a proved kernel can use today.
