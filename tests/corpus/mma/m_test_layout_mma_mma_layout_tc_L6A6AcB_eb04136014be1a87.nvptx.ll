; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_mma_layout_tc_L6A6AcB_eb04136014be1a87(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [4 x ptr], i64 1, align 8
  %5 = alloca float, i64 1, align 4
  %6 = alloca float, i64 1, align 4
  %7 = alloca float, i64 1, align 4
  %8 = alloca float, i64 1, align 4
  %9 = alloca [4 x float], align 4
  %10 = alloca [2 x float], align 4
  %11 = alloca [4 x float], align 4
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
  %34 = trunc i64 %27 to i32
  %35 = mul i32 %34, 8
  %36 = trunc i64 %33 to i32
  %37 = add i32 %35, %36
  %38 = sext i32 %37 to i64
  %39 = getelementptr inbounds float, ptr %16, i64 %38
  %40 = load float, ptr %39, align 4
  store float %40, ptr addrspace(5) %18, align 4
  %41 = add i64 %27, 8
  %42 = trunc i64 %41 to i32
  %43 = mul i32 %42, 8
  %44 = add i32 %43, %36
  %45 = sext i32 %44 to i64
  %46 = getelementptr inbounds float, ptr %16, i64 %45
  %47 = load float, ptr %46, align 4
  %48 = getelementptr inbounds float, ptr addrspace(5) %18, i32 1
  store float %47, ptr addrspace(5) %48, align 4
  %49 = add i64 %33, 4
  %50 = trunc i64 %49 to i32
  %51 = add i32 %35, %50
  %52 = sext i32 %51 to i64
  %53 = getelementptr inbounds float, ptr %16, i64 %52
  %54 = load float, ptr %53, align 4
  %55 = getelementptr inbounds float, ptr addrspace(5) %18, i32 2
  store float %54, ptr addrspace(5) %55, align 4
  %56 = add i32 %43, %50
  %57 = sext i32 %56 to i64
  %58 = getelementptr inbounds float, ptr %16, i64 %57
  %59 = load float, ptr %58, align 4
  %60 = getelementptr inbounds float, ptr addrspace(5) %18, i32 3
  store float %59, ptr addrspace(5) %60, align 4
  call void @llvm.lifetime.start.p0(ptr %10)
  %61 = addrspacecast ptr %10 to ptr addrspace(5)
  %62 = mul i32 %36, 8
  %63 = add i32 %62, %34
  %64 = sext i32 %63 to i64
  %65 = getelementptr inbounds float, ptr %17, i64 %64
  %66 = load float, ptr %65, align 4
  store float %66, ptr addrspace(5) %61, align 4
  %67 = mul i32 %50, 8
  %68 = add i32 %67, %34
  %69 = sext i32 %68 to i64
  %70 = getelementptr inbounds float, ptr %17, i64 %69
  %71 = load float, ptr %70, align 4
  %72 = getelementptr inbounds float, ptr addrspace(5) %61, i32 1
  store float %71, ptr addrspace(5) %72, align 4
  call void @llvm.lifetime.start.p0(ptr %9)
  %73 = addrspacecast ptr %9 to ptr addrspace(5)
  %74 = mul i64 %33, 2
  %75 = trunc i64 %74 to i32
  %76 = add i32 %35, %75
  %77 = sext i32 %76 to i64
  %78 = getelementptr inbounds float, ptr %15, i64 %77
  %79 = load float, ptr %78, align 4
  store float %79, ptr addrspace(5) %73, align 4
  %80 = add i64 %74, 1
  %81 = trunc i64 %80 to i32
  %82 = add i32 %35, %81
  %83 = sext i32 %82 to i64
  %84 = getelementptr inbounds float, ptr %15, i64 %83
  %85 = load float, ptr %84, align 4
  %86 = getelementptr inbounds float, ptr addrspace(5) %73, i32 1
  store float %85, ptr addrspace(5) %86, align 4
  %87 = add i32 %43, %75
  %88 = sext i32 %87 to i64
  %89 = getelementptr inbounds float, ptr %15, i64 %88
  %90 = load float, ptr %89, align 4
  %91 = getelementptr inbounds float, ptr addrspace(5) %73, i32 2
  store float %90, ptr addrspace(5) %91, align 4
  %92 = add i32 %43, %81
  %93 = sext i32 %92 to i64
  %94 = getelementptr inbounds float, ptr %15, i64 %93
  %95 = load float, ptr %94, align 4
  %96 = getelementptr inbounds float, ptr addrspace(5) %73, i32 3
  store float %95, ptr addrspace(5) %96, align 4
  %97 = load <4 x float>, ptr addrspace(5) %73, align 4
  %98 = load <4 x float>, ptr addrspace(5) %18, align 4
  %99 = load <2 x float>, ptr addrspace(5) %61, align 4
  %100 = bitcast <4 x float> %98 to <4 x i32>
  %101 = bitcast <2 x float> %99 to <2 x i32>
  %102 = extractelement <4 x i32> %100, i64 0
  %103 = extractelement <4 x i32> %100, i64 1
  %104 = extractelement <4 x i32> %100, i64 2
  %105 = extractelement <4 x i32> %100, i64 3
  %106 = extractelement <2 x i32> %101, i64 0
  %107 = extractelement <2 x i32> %101, i64 1
  %108 = extractelement <4 x float> %97, i64 0
  %109 = extractelement <4 x float> %97, i64 1
  %110 = extractelement <4 x float> %97, i64 2
  %111 = extractelement <4 x float> %97, i64 3
  %112 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k8.row.col.tf32(i32 %102, i32 %103, i32 %104, i32 %105, i32 %106, i32 %107, float %108, float %109, float %110, float %111)
  %113 = extractvalue { float, float, float, float } %112, 0
  %114 = extractvalue { float, float, float, float } %112, 1
  %115 = extractvalue { float, float, float, float } %112, 2
  %116 = extractvalue { float, float, float, float } %112, 3
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store float %113, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store float %114, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store float %115, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store float %116, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %117 = insertvalue [4 x ptr] undef, ptr %8, 0
  %118 = insertvalue [4 x ptr] %117, ptr %7, 1
  %119 = insertvalue [4 x ptr] %118, ptr %6, 2
  %120 = insertvalue [4 x ptr] %119, ptr %5, 3
  call void @llvm.lifetime.start.p0(ptr %4)
  store [4 x ptr] %120, ptr %4, align 8
  %121 = getelementptr inbounds [4 x ptr], ptr %4, i32 0, i32 0
  %122 = load ptr, ptr %121, align 8
  %123 = load float, ptr %122, align 4
  %124 = insertelement <4 x float> undef, float %123, i64 0
  %125 = getelementptr inbounds ptr, ptr %121, i32 1
  %126 = load ptr, ptr %125, align 8
  %127 = load float, ptr %126, align 4
  %128 = insertelement <4 x float> %124, float %127, i64 1
  %129 = getelementptr inbounds ptr, ptr %121, i32 2
  %130 = load ptr, ptr %129, align 8
  %131 = load float, ptr %130, align 4
  %132 = insertelement <4 x float> %128, float %131, i64 2
  %133 = getelementptr inbounds ptr, ptr %121, i32 3
  %134 = load ptr, ptr %133, align 8
  %135 = load float, ptr %134, align 4
  %136 = insertelement <4 x float> %132, float %135, i64 3
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %137 = extractelement <4 x float> %136, i64 0
  store float %137, ptr %78, align 4
  %138 = extractelement <4 x float> %136, i64 1
  store float %138, ptr %84, align 4
  %139 = extractelement <4 x float> %136, i64 2
  store float %139, ptr %89, align 4
  %140 = extractelement <4 x float> %136, i64 3
  store float %140, ptr %94, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %9)
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #2

; Function Attrs: nocallback nounwind memory(none)
declare { float, float, float, float } @llvm.nvvm.mma.m16n8k8.row.col.tf32(i32, i32, i32, i32, i32, i32, float, float, float, float) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nounwind memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
