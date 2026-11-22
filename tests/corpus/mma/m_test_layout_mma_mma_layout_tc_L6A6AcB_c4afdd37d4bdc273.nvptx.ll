; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_mma_layout_tc_L6A6AcB_c4afdd37d4bdc273(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [4 x ptr], i64 1, align 8
  %5 = alloca float, i64 1, align 4
  %6 = alloca float, i64 1, align 4
  %7 = alloca float, i64 1, align 4
  %8 = alloca float, i64 1, align 4
  %9 = alloca [4 x float], align 4
  %10 = alloca [2 x bfloat], align 2
  %11 = alloca [4 x bfloat], align 2
  %12 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %13 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %14 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %15 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %14, 0
  %16 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %13, 0
  %17 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %12, 0
  call void @llvm.lifetime.start.p0(ptr %11)
  %18 = addrspacecast ptr %11 to ptr addrspace(5)
  %19 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %20 = sext i32 %19 to i64
  %21 = sdiv i64 %20, 4
  %22 = mul i64 %21, 4
  %23 = icmp eq i64 %22, %20
  %24 = xor i64 %20, 4
  %25 = ashr i64 %24, 63
  %26 = select i1 %23, i64 0, i64 %25
  %27 = add i64 %21, %26
  %28 = sub i64 %20, %22
  %29 = icmp slt i64 %20, 0
  %30 = icmp ne i64 %28, 0
  %31 = and i1 %29, %30
  %32 = select i1 %31, i64 4, i64 0
  %33 = add i64 %28, %32
  %34 = mul i64 %33, 2
  %35 = trunc i64 %27 to i32
  %36 = mul i32 %35, 8
  %37 = trunc i64 %34 to i32
  %38 = add i32 %36, %37
  %39 = sext i32 %38 to i64
  %40 = getelementptr inbounds bfloat, ptr %16, i64 %39
  %41 = load bfloat, ptr %40, align 2
  store bfloat %41, ptr addrspace(5) %18, align 2
  %42 = add i64 %34, 1
  %43 = trunc i64 %42 to i32
  %44 = add i32 %36, %43
  %45 = sext i32 %44 to i64
  %46 = getelementptr inbounds bfloat, ptr %16, i64 %45
  %47 = load bfloat, ptr %46, align 2
  %48 = getelementptr inbounds bfloat, ptr addrspace(5) %18, i32 1
  store bfloat %47, ptr addrspace(5) %48, align 2
  %49 = add i64 %27, 8
  %50 = trunc i64 %49 to i32
  %51 = mul i32 %50, 8
  %52 = add i32 %51, %37
  %53 = sext i32 %52 to i64
  %54 = getelementptr inbounds bfloat, ptr %16, i64 %53
  %55 = load bfloat, ptr %54, align 2
  %56 = getelementptr inbounds bfloat, ptr addrspace(5) %18, i32 2
  store bfloat %55, ptr addrspace(5) %56, align 2
  %57 = add i32 %51, %43
  %58 = sext i32 %57 to i64
  %59 = getelementptr inbounds bfloat, ptr %16, i64 %58
  %60 = load bfloat, ptr %59, align 2
  %61 = getelementptr inbounds bfloat, ptr addrspace(5) %18, i32 3
  store bfloat %60, ptr addrspace(5) %61, align 2
  call void @llvm.lifetime.start.p0(ptr %10)
  %62 = addrspacecast ptr %10 to ptr addrspace(5)
  %63 = mul i32 %37, 8
  %64 = add i32 %63, %35
  %65 = sext i32 %64 to i64
  %66 = getelementptr inbounds bfloat, ptr %17, i64 %65
  %67 = load bfloat, ptr %66, align 2
  store bfloat %67, ptr addrspace(5) %62, align 2
  %68 = mul i32 %43, 8
  %69 = add i32 %68, %35
  %70 = sext i32 %69 to i64
  %71 = getelementptr inbounds bfloat, ptr %17, i64 %70
  %72 = load bfloat, ptr %71, align 2
  %73 = getelementptr inbounds bfloat, ptr addrspace(5) %62, i32 1
  store bfloat %72, ptr addrspace(5) %73, align 2
  call void @llvm.lifetime.start.p0(ptr %9)
  %74 = addrspacecast ptr %9 to ptr addrspace(5)
  %75 = getelementptr inbounds float, ptr %15, i64 %39
  %76 = load float, ptr %75, align 4
  store float %76, ptr addrspace(5) %74, align 4
  %77 = getelementptr inbounds float, ptr %15, i64 %45
  %78 = load float, ptr %77, align 4
  %79 = getelementptr inbounds float, ptr addrspace(5) %74, i32 1
  store float %78, ptr addrspace(5) %79, align 4
  %80 = getelementptr inbounds float, ptr %15, i64 %53
  %81 = load float, ptr %80, align 4
  %82 = getelementptr inbounds float, ptr addrspace(5) %74, i32 2
  store float %81, ptr addrspace(5) %82, align 4
  %83 = getelementptr inbounds float, ptr %15, i64 %58
  %84 = load float, ptr %83, align 4
  %85 = getelementptr inbounds float, ptr addrspace(5) %74, i32 3
  store float %84, ptr addrspace(5) %85, align 4
  %86 = load <4 x float>, ptr addrspace(5) %74, align 4
  %87 = load <4 x bfloat>, ptr addrspace(5) %18, align 2
  %88 = load <2 x bfloat>, ptr addrspace(5) %62, align 2
  %89 = call <2 x bfloat> @llvm.vector.extract.v2bf16.v4bf16(<4 x bfloat> %87, i64 0)
  %90 = call <2 x bfloat> @llvm.vector.extract.v2bf16.v4bf16(<4 x bfloat> %87, i64 2)
  %91 = bitcast <2 x bfloat> %89 to i32
  %92 = bitcast <2 x bfloat> %90 to i32
  %93 = bitcast <2 x bfloat> %88 to i32
  %94 = extractelement <4 x float> %86, i64 0
  %95 = extractelement <4 x float> %86, i64 1
  %96 = extractelement <4 x float> %86, i64 2
  %97 = extractelement <4 x float> %86, i64 3
  %98 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k8.row.col.bf16(i32 %91, i32 %92, i32 %93, float %94, float %95, float %96, float %97)
  %99 = extractvalue { float, float, float, float } %98, 0
  %100 = extractvalue { float, float, float, float } %98, 1
  %101 = extractvalue { float, float, float, float } %98, 2
  %102 = extractvalue { float, float, float, float } %98, 3
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store float %99, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store float %100, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store float %101, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store float %102, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %103 = insertvalue [4 x ptr] undef, ptr %8, 0
  %104 = insertvalue [4 x ptr] %103, ptr %7, 1
  %105 = insertvalue [4 x ptr] %104, ptr %6, 2
  %106 = insertvalue [4 x ptr] %105, ptr %5, 3
  call void @llvm.lifetime.start.p0(ptr %4)
  store [4 x ptr] %106, ptr %4, align 8
  %107 = getelementptr inbounds [4 x ptr], ptr %4, i32 0, i32 0
  %108 = load ptr, ptr %107, align 8
  %109 = load float, ptr %108, align 4
  %110 = insertelement <4 x float> undef, float %109, i64 0
  %111 = getelementptr inbounds ptr, ptr %107, i32 1
  %112 = load ptr, ptr %111, align 8
  %113 = load float, ptr %112, align 4
  %114 = insertelement <4 x float> %110, float %113, i64 1
  %115 = getelementptr inbounds ptr, ptr %107, i32 2
  %116 = load ptr, ptr %115, align 8
  %117 = load float, ptr %116, align 4
  %118 = insertelement <4 x float> %114, float %117, i64 2
  %119 = getelementptr inbounds ptr, ptr %107, i32 3
  %120 = load ptr, ptr %119, align 8
  %121 = load float, ptr %120, align 4
  %122 = insertelement <4 x float> %118, float %121, i64 3
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %123 = extractelement <4 x float> %122, i64 0
  store float %123, ptr %75, align 4
  %124 = extractelement <4 x float> %122, i64 1
  store float %124, ptr %77, align 4
  %125 = extractelement <4 x float> %122, i64 2
  store float %125, ptr %80, align 4
  %126 = extractelement <4 x float> %122, i64 3
  store float %126, ptr %83, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %9)
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x bfloat> @llvm.vector.extract.v2bf16.v4bf16(<4 x bfloat>, i64 immarg) #2

; Function Attrs: nocallback nounwind memory(none)
declare { float, float, float, float } @llvm.nvvm.mma.m16n8k8.row.col.bf16(i32, i32, i32, float, float, float, float) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nounwind memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
