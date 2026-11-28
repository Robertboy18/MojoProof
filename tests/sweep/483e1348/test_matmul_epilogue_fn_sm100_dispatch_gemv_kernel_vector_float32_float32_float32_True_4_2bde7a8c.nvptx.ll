; ModuleID = 'test_matmul_epilogue_fn_sm100_dispatch.mojo'
source_filename = "test_matmul_epilogue_fn_sm100_dispatch.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_float32_float32_float32_True_4_2bde7a8c(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #1 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca [2 x ptr], i64 1, align 8
  %13 = alloca i32, i64 1, align 4
  %14 = alloca i32, i64 1, align 4
  %15 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %16 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %17 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %18 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %17, 0
  %19 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %16, 0
  %20 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %15, 0
  %21 = sext i32 %5 to i64
  %22 = sext i32 %3 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %24 = zext i32 %23 to i64
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %26 = zext i32 %25 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %28 = sext i32 %27 to i64
  %29 = mul i64 %26, %28
  %30 = add i64 %29, %24
  %31 = udiv i64 %30, 32
  %32 = bitcast i64 %31 to <2 x i32>
  %33 = extractelement <2 x i32> %32, i64 0
  %34 = extractelement <2 x i32> %32, i64 1
  %35 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %33, i32 0, i32 31)
  %36 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %34, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i32 %35, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i32 %36, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %37 = insertvalue [2 x ptr] undef, ptr %14, 0
  %38 = insertvalue [2 x ptr] %37, ptr %13, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %38, ptr %12, align 8
  %39 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %40 = load ptr, ptr %39, align 8
  %41 = load i32, ptr %40, align 4
  %42 = insertelement <2 x i32> undef, i32 %41, i64 0
  %43 = getelementptr inbounds ptr, ptr %39, i32 1
  %44 = load ptr, ptr %43, align 8
  %45 = load i32, ptr %44, align 4
  %46 = insertelement <2 x i32> %42, i32 %45, i64 1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %47 = bitcast <2 x i32> %46 to i64
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %47, ptr %11, align 8
  %48 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %49 = sext i32 %48 to i64
  %50 = trunc i64 %49 to i32
  %51 = mul i32 %50, 4
  %52 = sext i32 %51 to i64
  %53 = icmp eq i64 %49, 0
  %54 = load i64, ptr %11, align 8
  %55 = icmp sge i64 %54, %22
  br i1 %55, label %56, label %57

56:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %134

57:                                               ; preds = %6
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %58 = udiv i64 %21, 128
  %59 = add i64 %58, 1
  %60 = sub i64 %59, 1
  %61 = call i64 @llvm.smax.i64(i64 %60, i64 0)
  br label %62

62:                                               ; preds = %95, %57
  %63 = phi <4 x float> [ zeroinitializer, %57 ], [ %128, %95 ]
  %64 = phi i64 [ 0, %57 ], [ %67, %95 ]
  call void @llvm.lifetime.end.p0(ptr %10)
  %65 = icmp eq i64 %64, %61
  %66 = add i64 %64, 1
  %67 = select i1 %65, i64 %64, i64 %66
  br i1 %65, label %68, label %95

68:                                               ; preds = %62
  %69 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %63, i64 0)
  %70 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %63, i64 2)
  %71 = fadd contract <2 x float> %69, %70
  %72 = extractelement <2 x float> %71, i64 0
  %73 = extractelement <2 x float> %71, i64 1
  %74 = fadd contract float %72, %73
  %75 = bitcast float %74 to i32
  %76 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %75, i32 16, i32 31)
  %77 = bitcast i32 %76 to float
  %78 = fadd contract float %74, %77
  %79 = bitcast float %78 to i32
  %80 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %79, i32 8, i32 31)
  %81 = bitcast i32 %80 to float
  %82 = fadd contract float %78, %81
  %83 = bitcast float %82 to i32
  %84 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %83, i32 4, i32 31)
  %85 = bitcast i32 %84 to float
  %86 = fadd contract float %82, %85
  %87 = bitcast float %86 to i32
  %88 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %87, i32 2, i32 31)
  %89 = bitcast i32 %88 to float
  %90 = fadd contract float %86, %89
  %91 = bitcast float %90 to i32
  %92 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %91, i32 1, i32 31)
  %93 = bitcast i32 %92 to float
  %94 = fadd contract float %90, %93
  br i1 %53, label %129, label %132

95:                                               ; preds = %62
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %64, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %96 = insertvalue [2 x ptr] undef, ptr %11, 0
  %97 = insertvalue [2 x ptr] %96, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %97, ptr %9, align 8
  %98 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %99 = load ptr, ptr %98, align 8
  %100 = load i64, ptr %99, align 8
  %101 = trunc i64 %100 to i32
  %102 = getelementptr inbounds ptr, ptr %98, i32 1
  %103 = load ptr, ptr %102, align 8
  %104 = load i64, ptr %103, align 8
  %105 = trunc i64 %104 to i32
  %106 = mul i32 %101, 6144
  %107 = mul i32 %105, 128
  %108 = add i32 %106, %107
  %109 = sext i32 %108 to i64
  %110 = getelementptr inbounds float, ptr %19, i64 %109
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 0, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %111 = insertvalue [2 x ptr] undef, ptr %8, 0
  %112 = insertvalue [2 x ptr] %111, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %112, ptr %7, align 8
  %113 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %114 = load ptr, ptr %113, align 8
  %115 = load i64, ptr %114, align 8
  %116 = getelementptr inbounds ptr, ptr %113, i32 1
  %117 = load ptr, ptr %116, align 8
  %118 = load i64, ptr %117, align 8
  %119 = mul i64 %115, 6144
  %120 = mul i64 %118, 128
  %121 = add i64 %119, %120
  %122 = getelementptr inbounds float, ptr %20, i64 %121
  %123 = getelementptr inbounds float, ptr %110, i64 %52
  %124 = load <4 x float>, ptr %123, align 16, !invariant.load !1
  %125 = getelementptr inbounds float, ptr %122, i64 %52
  %126 = load <4 x float>, ptr %125, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %127 = fmul contract <4 x float> %124, %126
  %128 = fadd contract <4 x float> %63, %127
  br label %62

129:                                              ; preds = %68
  %130 = load i64, ptr %11, align 8
  %131 = getelementptr inbounds float, ptr %18, i64 %130
  store float %94, ptr %131, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %133

132:                                              ; preds = %68
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %133

133:                                              ; preds = %132, %129
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  br label %134

134:                                              ; preds = %133, %56
  ret void
}

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.wait() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #3

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.idx.i32(i32, i32, i32, i32) #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #5

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #5

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #6

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float>, i64 immarg) #3

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #4

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.launch.dependents() #2

attributes #0 = { noinline "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #1 = { convergent norecurse "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #2 = { nounwind }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #6 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
