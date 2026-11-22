; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_mma_layout_tc_L6A6AcB_275004a9341a248d(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [4 x ptr], i64 1, align 8
  %5 = alloca float, i64 1, align 4
  %6 = alloca float, i64 1, align 4
  %7 = alloca float, i64 1, align 4
  %8 = alloca float, i64 1, align 4
  %9 = alloca [4 x float], align 4
  %10 = alloca float, i64 1, align 4
  %11 = alloca [2 x float], align 4
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
  %35 = mul i32 %34, 4
  %36 = trunc i64 %33 to i32
  %37 = add i32 %35, %36
  %38 = sext i32 %37 to i64
  %39 = getelementptr inbounds float, ptr %16, i64 %38
  %40 = load float, ptr %39, align 4
  store float %40, ptr addrspace(5) %18, align 4
  %41 = add i64 %27, 8
  %42 = trunc i64 %41 to i32
  %43 = mul i32 %42, 4
  %44 = add i32 %43, %36
  %45 = sext i32 %44 to i64
  %46 = getelementptr inbounds float, ptr %16, i64 %45
  %47 = load float, ptr %46, align 4
  %48 = getelementptr inbounds float, ptr addrspace(5) %18, i32 1
  store float %47, ptr addrspace(5) %48, align 4
  call void @llvm.lifetime.start.p0(ptr %10)
  %49 = mul i32 %36, 8
  %50 = add i32 %49, %34
  %51 = sext i32 %50 to i64
  %52 = getelementptr inbounds float, ptr %17, i64 %51
  %53 = load float, ptr %52, align 4
  %54 = addrspacecast ptr %10 to ptr addrspace(5)
  store float %53, ptr addrspace(5) %54, align 4
  call void @llvm.lifetime.start.p0(ptr %9)
  %55 = addrspacecast ptr %9 to ptr addrspace(5)
  %56 = mul i64 %33, 2
  %57 = mul i32 %34, 8
  %58 = trunc i64 %56 to i32
  %59 = add i32 %57, %58
  %60 = sext i32 %59 to i64
  %61 = getelementptr inbounds float, ptr %15, i64 %60
  %62 = load float, ptr %61, align 4
  store float %62, ptr addrspace(5) %55, align 4
  %63 = add i64 %56, 1
  %64 = trunc i64 %63 to i32
  %65 = add i32 %57, %64
  %66 = sext i32 %65 to i64
  %67 = getelementptr inbounds float, ptr %15, i64 %66
  %68 = load float, ptr %67, align 4
  %69 = getelementptr inbounds float, ptr addrspace(5) %55, i32 1
  store float %68, ptr addrspace(5) %69, align 4
  %70 = mul i32 %42, 8
  %71 = add i32 %70, %58
  %72 = sext i32 %71 to i64
  %73 = getelementptr inbounds float, ptr %15, i64 %72
  %74 = load float, ptr %73, align 4
  %75 = getelementptr inbounds float, ptr addrspace(5) %55, i32 2
  store float %74, ptr addrspace(5) %75, align 4
  %76 = add i32 %70, %64
  %77 = sext i32 %76 to i64
  %78 = getelementptr inbounds float, ptr %15, i64 %77
  %79 = load float, ptr %78, align 4
  %80 = getelementptr inbounds float, ptr addrspace(5) %55, i32 3
  store float %79, ptr addrspace(5) %80, align 4
  %81 = load <4 x float>, ptr addrspace(5) %55, align 4
  %82 = load <2 x float>, ptr addrspace(5) %18, align 4
  %83 = load float, ptr addrspace(5) %54, align 4
  %84 = bitcast <2 x float> %82 to <2 x i32>
  %85 = bitcast float %83 to i32
  %86 = extractelement <2 x i32> %84, i64 0
  %87 = extractelement <2 x i32> %84, i64 1
  %88 = extractelement <4 x float> %81, i64 0
  %89 = extractelement <4 x float> %81, i64 1
  %90 = extractelement <4 x float> %81, i64 2
  %91 = extractelement <4 x float> %81, i64 3
  %92 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k4.row.col.tf32(i32 %86, i32 %87, i32 %85, float %88, float %89, float %90, float %91)
  %93 = extractvalue { float, float, float, float } %92, 0
  %94 = extractvalue { float, float, float, float } %92, 1
  %95 = extractvalue { float, float, float, float } %92, 2
  %96 = extractvalue { float, float, float, float } %92, 3
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store float %93, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store float %94, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store float %95, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store float %96, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %97 = insertvalue [4 x ptr] undef, ptr %8, 0
  %98 = insertvalue [4 x ptr] %97, ptr %7, 1
  %99 = insertvalue [4 x ptr] %98, ptr %6, 2
  %100 = insertvalue [4 x ptr] %99, ptr %5, 3
  call void @llvm.lifetime.start.p0(ptr %4)
  store [4 x ptr] %100, ptr %4, align 8
  %101 = getelementptr inbounds [4 x ptr], ptr %4, i32 0, i32 0
  %102 = load ptr, ptr %101, align 8
  %103 = load float, ptr %102, align 4
  %104 = insertelement <4 x float> undef, float %103, i64 0
  %105 = getelementptr inbounds ptr, ptr %101, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = load float, ptr %106, align 4
  %108 = insertelement <4 x float> %104, float %107, i64 1
  %109 = getelementptr inbounds ptr, ptr %101, i32 2
  %110 = load ptr, ptr %109, align 8
  %111 = load float, ptr %110, align 4
  %112 = insertelement <4 x float> %108, float %111, i64 2
  %113 = getelementptr inbounds ptr, ptr %101, i32 3
  %114 = load ptr, ptr %113, align 8
  %115 = load float, ptr %114, align 4
  %116 = insertelement <4 x float> %112, float %115, i64 3
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %117 = extractelement <4 x float> %116, i64 0
  store float %117, ptr %61, align 4
  %118 = extractelement <4 x float> %116, i64 1
  store float %118, ptr %67, align 4
  %119 = extractelement <4 x float> %116, i64 2
  store float %119, ptr %73, align 4
  %120 = extractelement <4 x float> %116, i64 3
  store float %120, ptr %78, align 4
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
declare { float, float, float, float } @llvm.nvvm.mma.m16n8k4.row.col.tf32(i32, i32, i32, float, float, float, float) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nounwind memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
