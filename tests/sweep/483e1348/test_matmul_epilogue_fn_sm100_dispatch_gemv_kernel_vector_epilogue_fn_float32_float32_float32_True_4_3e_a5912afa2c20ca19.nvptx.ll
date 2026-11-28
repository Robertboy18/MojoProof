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
define dso_local ptx_kernel void @gemv_kernel_vector_epilogue_fn_float32_float32_float32_True_4_3e5cfaaa(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %6) #1 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i32, i64 1, align 4
  %15 = alloca i32, i64 1, align 4
  %16 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %17 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %18 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %17, 0
  %19 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %16, 0
  %20 = sext i32 %5 to i64
  %21 = sext i32 %3 to i64
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %23 = zext i32 %22 to i64
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %25 = zext i32 %24 to i64
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %27 = sext i32 %26 to i64
  %28 = mul i64 %25, %27
  %29 = add i64 %28, %23
  %30 = udiv i64 %29, 32
  %31 = bitcast i64 %30 to <2 x i32>
  %32 = extractelement <2 x i32> %31, i64 0
  %33 = extractelement <2 x i32> %31, i64 1
  %34 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %32, i32 0, i32 31)
  %35 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %33, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i32 %34, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i32 %35, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %36 = insertvalue [2 x ptr] undef, ptr %15, 0
  %37 = insertvalue [2 x ptr] %36, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %37, ptr %13, align 8
  %38 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %39 = load ptr, ptr %38, align 8
  %40 = load i32, ptr %39, align 4
  %41 = insertelement <2 x i32> undef, i32 %40, i64 0
  %42 = getelementptr inbounds ptr, ptr %38, i32 1
  %43 = load ptr, ptr %42, align 8
  %44 = load i32, ptr %43, align 4
  %45 = insertelement <2 x i32> %41, i32 %44, i64 1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %46 = bitcast <2 x i32> %45 to i64
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %46, ptr %12, align 8
  %47 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %48 = sext i32 %47 to i64
  %49 = trunc i64 %48 to i32
  %50 = mul i32 %49, 4
  %51 = sext i32 %50 to i64
  %52 = icmp eq i64 %48, 0
  %53 = load i64, ptr %12, align 8
  %54 = icmp sge i64 %53, %21
  br i1 %54, label %55, label %56

55:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %136

56:                                               ; preds = %7
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %57 = udiv i64 %20, 128
  %58 = add i64 %57, 1
  %59 = sub i64 %58, 1
  %60 = call i64 @llvm.smax.i64(i64 %59, i64 0)
  br label %61

61:                                               ; preds = %95, %56
  %62 = phi <4 x float> [ zeroinitializer, %56 ], [ %128, %95 ]
  %63 = phi i64 [ 0, %56 ], [ %66, %95 ]
  call void @llvm.lifetime.end.p0(ptr %11)
  %64 = icmp eq i64 %63, %60
  %65 = add i64 %63, 1
  %66 = select i1 %64, i64 %63, i64 %65
  br i1 %64, label %67, label %95

67:                                               ; preds = %61
  %68 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %62, i64 0)
  %69 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %62, i64 2)
  %70 = fadd contract <2 x float> %68, %69
  %71 = extractelement <2 x float> %70, i64 0
  %72 = extractelement <2 x float> %70, i64 1
  %73 = fadd contract float %71, %72
  %74 = bitcast float %73 to i32
  %75 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %74, i32 16, i32 31)
  %76 = bitcast i32 %75 to float
  %77 = fadd contract float %73, %76
  %78 = bitcast float %77 to i32
  %79 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %78, i32 8, i32 31)
  %80 = bitcast i32 %79 to float
  %81 = fadd contract float %77, %80
  %82 = bitcast float %81 to i32
  %83 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %82, i32 4, i32 31)
  %84 = bitcast i32 %83 to float
  %85 = fadd contract float %81, %84
  %86 = bitcast float %85 to i32
  %87 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %86, i32 2, i32 31)
  %88 = bitcast i32 %87 to float
  %89 = fadd contract float %85, %88
  %90 = bitcast float %89 to i32
  %91 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %90, i32 1, i32 31)
  %92 = bitcast i32 %91 to float
  %93 = fadd contract float %89, %92
  %94 = fmul contract float %93, 2.000000e+00
  br i1 %52, label %129, label %134

95:                                               ; preds = %61
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %63, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %96 = insertvalue [2 x ptr] undef, ptr %12, 0
  %97 = insertvalue [2 x ptr] %96, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %97, ptr %10, align 8
  %98 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
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
  %110 = getelementptr inbounds float, ptr %18, i64 %109
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 0, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %111 = insertvalue [2 x ptr] undef, ptr %9, 0
  %112 = insertvalue [2 x ptr] %111, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %112, ptr %8, align 8
  %113 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %114 = load ptr, ptr %113, align 8
  %115 = load i64, ptr %114, align 8
  %116 = getelementptr inbounds ptr, ptr %113, i32 1
  %117 = load ptr, ptr %116, align 8
  %118 = load i64, ptr %117, align 8
  %119 = mul i64 %115, 6144
  %120 = mul i64 %118, 128
  %121 = add i64 %119, %120
  %122 = getelementptr inbounds float, ptr %19, i64 %121
  %123 = getelementptr inbounds float, ptr %110, i64 %51
  %124 = load <4 x float>, ptr %123, align 16, !invariant.load !1
  %125 = getelementptr inbounds float, ptr %122, i64 %51
  %126 = load <4 x float>, ptr %125, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %127 = fmul contract <4 x float> %124, %126
  %128 = fadd contract <4 x float> %62, %127
  br label %61

129:                                              ; preds = %67
  %130 = load i64, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %131 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %6, align 8
  %132 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %131, 0
  %133 = getelementptr inbounds float, ptr %132, i64 %130
  store float %94, ptr %133, align 4
  br label %135

134:                                              ; preds = %67
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %135

135:                                              ; preds = %134, %129
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  br label %136

136:                                              ; preds = %135, %55
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
