; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_mma_layout_tc_L6A6AcB_c8da7db1dcabbc98(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [4 x ptr], i64 1, align 8
  %5 = alloca float, i64 1, align 4
  %6 = alloca float, i64 1, align 4
  %7 = alloca float, i64 1, align 4
  %8 = alloca float, i64 1, align 4
  %9 = alloca [4 x float], align 4
  %10 = alloca [2 x half], align 2
  %11 = alloca [4 x half], align 2
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
  %40 = getelementptr inbounds half, ptr %16, i64 %39
  %41 = load half, ptr %40, align 2
  store half %41, ptr addrspace(5) %18, align 2
  %42 = add i64 %34, 1
  %43 = trunc i64 %42 to i32
  %44 = add i32 %36, %43
  %45 = sext i32 %44 to i64
  %46 = getelementptr inbounds half, ptr %16, i64 %45
  %47 = load half, ptr %46, align 2
  %48 = getelementptr inbounds half, ptr addrspace(5) %18, i32 1
  store half %47, ptr addrspace(5) %48, align 2
  %49 = add i64 %27, 8
  %50 = trunc i64 %49 to i32
  %51 = mul i32 %50, 8
  %52 = add i32 %51, %37
  %53 = sext i32 %52 to i64
  %54 = getelementptr inbounds half, ptr %16, i64 %53
  %55 = load half, ptr %54, align 2
  %56 = getelementptr inbounds half, ptr addrspace(5) %18, i32 2
  store half %55, ptr addrspace(5) %56, align 2
  %57 = add i32 %51, %43
  %58 = sext i32 %57 to i64
  %59 = getelementptr inbounds half, ptr %16, i64 %58
  %60 = load half, ptr %59, align 2
  %61 = getelementptr inbounds half, ptr addrspace(5) %18, i32 3
  store half %60, ptr addrspace(5) %61, align 2
  call void @llvm.lifetime.start.p0(ptr %10)
  %62 = addrspacecast ptr %10 to ptr addrspace(5)
  %63 = mul i32 %37, 8
  %64 = add i32 %63, %35
  %65 = sext i32 %64 to i64
  %66 = getelementptr inbounds half, ptr %17, i64 %65
  %67 = load half, ptr %66, align 2
  store half %67, ptr addrspace(5) %62, align 2
  %68 = mul i32 %43, 8
  %69 = add i32 %68, %35
  %70 = sext i32 %69 to i64
  %71 = getelementptr inbounds half, ptr %17, i64 %70
  %72 = load half, ptr %71, align 2
  %73 = getelementptr inbounds half, ptr addrspace(5) %62, i32 1
  store half %72, ptr addrspace(5) %73, align 2
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
  %87 = load <4 x half>, ptr addrspace(5) %18, align 2
  %88 = load <2 x half>, ptr addrspace(5) %62, align 2
  %89 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %87, i64 0)
  %90 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %87, i64 2)
  %91 = extractelement <4 x float> %86, i64 0
  %92 = extractelement <4 x float> %86, i64 1
  %93 = extractelement <4 x float> %86, i64 2
  %94 = extractelement <4 x float> %86, i64 3
  %95 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k8.row.col.f32.f32(<2 x half> %89, <2 x half> %90, <2 x half> %88, float %91, float %92, float %93, float %94)
  %96 = extractvalue { float, float, float, float } %95, 0
  %97 = extractvalue { float, float, float, float } %95, 1
  %98 = extractvalue { float, float, float, float } %95, 2
  %99 = extractvalue { float, float, float, float } %95, 3
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store float %96, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store float %97, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store float %98, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store float %99, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %100 = insertvalue [4 x ptr] undef, ptr %8, 0
  %101 = insertvalue [4 x ptr] %100, ptr %7, 1
  %102 = insertvalue [4 x ptr] %101, ptr %6, 2
  %103 = insertvalue [4 x ptr] %102, ptr %5, 3
  call void @llvm.lifetime.start.p0(ptr %4)
  store [4 x ptr] %103, ptr %4, align 8
  %104 = getelementptr inbounds [4 x ptr], ptr %4, i32 0, i32 0
  %105 = load ptr, ptr %104, align 8
  %106 = load float, ptr %105, align 4
  %107 = insertelement <4 x float> undef, float %106, i64 0
  %108 = getelementptr inbounds ptr, ptr %104, i32 1
  %109 = load ptr, ptr %108, align 8
  %110 = load float, ptr %109, align 4
  %111 = insertelement <4 x float> %107, float %110, i64 1
  %112 = getelementptr inbounds ptr, ptr %104, i32 2
  %113 = load ptr, ptr %112, align 8
  %114 = load float, ptr %113, align 4
  %115 = insertelement <4 x float> %111, float %114, i64 2
  %116 = getelementptr inbounds ptr, ptr %104, i32 3
  %117 = load ptr, ptr %116, align 8
  %118 = load float, ptr %117, align 4
  %119 = insertelement <4 x float> %115, float %118, i64 3
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %120 = extractelement <4 x float> %119, i64 0
  store float %120, ptr %75, align 4
  %121 = extractelement <4 x float> %119, i64 1
  store float %121, ptr %77, align 4
  %122 = extractelement <4 x float> %119, i64 2
  store float %122, ptr %80, align 4
  %123 = extractelement <4 x float> %119, i64 3
  store float %123, ptr %83, align 4
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
declare <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half>, i64 immarg) #2

; Function Attrs: nocallback nounwind memory(none)
declare { float, float, float, float } @llvm.nvvm.mma.m16n8k8.row.col.f32.f32(<2 x half>, <2 x half>, <2 x half>, float, float, float, float) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nounwind memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
