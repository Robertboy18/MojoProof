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
define dso_local ptx_kernel void @gemv_kernel_epilogue_fn_float32_float32_float32_True_a18324a4(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %6) #1 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i32, i64 1, align 4
  %10 = alloca i32, i64 1, align 4
  %11 = sext i32 %3 to i64
  %12 = sext i32 %5 to i64
  %13 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %14 = zext i32 %13 to i64
  %15 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %16 = zext i32 %15 to i64
  %17 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %18 = sext i32 %17 to i64
  %19 = mul i64 %16, %18
  %20 = add i64 %19, %14
  %21 = udiv i64 %20, 32
  %22 = bitcast i64 %21 to <2 x i32>
  %23 = extractelement <2 x i32> %22, i64 0
  %24 = extractelement <2 x i32> %22, i64 1
  %25 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %23, i32 0, i32 31)
  %26 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %24, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i32 %25, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i32 %26, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %27 = insertvalue [2 x ptr] undef, ptr %10, 0
  %28 = insertvalue [2 x ptr] %27, ptr %9, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %28, ptr %8, align 8
  %29 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %30 = load ptr, ptr %29, align 8
  %31 = load i32, ptr %30, align 4
  %32 = insertelement <2 x i32> undef, i32 %31, i64 0
  %33 = getelementptr inbounds ptr, ptr %29, i32 1
  %34 = load ptr, ptr %33, align 8
  %35 = load i32, ptr %34, align 4
  %36 = insertelement <2 x i32> %32, i32 %35, i64 1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %37 = bitcast <2 x i32> %36 to i64
  %38 = mul i64 %37, %12
  %39 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %40 = sext i32 %39 to i64
  %41 = icmp eq i64 %40, 0
  %42 = icmp sge i64 %37, %11
  br i1 %42, label %43, label %44

43:                                               ; preds = %7
  br label %104

44:                                               ; preds = %7
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %45 = sdiv i64 %12, -32
  %46 = mul i64 %45, -32
  %47 = icmp eq i64 %46, %12
  %48 = xor i64 %12, -32
  %49 = ashr i64 %48, 63
  %50 = select i1 %47, i64 0, i64 %49
  %51 = add i64 %45, %50
  %52 = sub i64 0, %51
  %53 = call i64 @llvm.smax.i64(i64 %52, i64 0)
  br label %54

54:                                               ; preds = %96, %44
  %55 = phi i64 [ 0, %44 ], [ %61, %96 ]
  %56 = phi float [ 0.000000e+00, %44 ], [ %97, %96 ]
  %57 = icmp slt i64 %55, %53
  br i1 %57, label %58, label %68

58:                                               ; preds = %54
  %59 = icmp eq i64 %55, %53
  %60 = add i64 %55, 1
  %61 = select i1 %59, i64 %55, i64 %60
  %62 = mul i64 %55, 32
  %63 = add i64 %62, %40
  %64 = getelementptr inbounds float, ptr %2, i64 %63
  %65 = add i64 %38, %63
  %66 = getelementptr inbounds float, ptr %1, i64 %65
  %67 = icmp slt i64 %63, %12
  br i1 %67, label %90, label %95

68:                                               ; preds = %54
  %69 = bitcast float %56 to i32
  %70 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %69, i32 16, i32 31)
  %71 = bitcast i32 %70 to float
  %72 = fadd contract float %56, %71
  %73 = bitcast float %72 to i32
  %74 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %73, i32 8, i32 31)
  %75 = bitcast i32 %74 to float
  %76 = fadd contract float %72, %75
  %77 = bitcast float %76 to i32
  %78 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %77, i32 4, i32 31)
  %79 = bitcast i32 %78 to float
  %80 = fadd contract float %76, %79
  %81 = bitcast float %80 to i32
  %82 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %81, i32 2, i32 31)
  %83 = bitcast i32 %82 to float
  %84 = fadd contract float %80, %83
  %85 = bitcast float %84 to i32
  %86 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %85, i32 1, i32 31)
  %87 = bitcast i32 %86 to float
  %88 = fadd contract float %84, %87
  %89 = fmul contract float %88, 2.000000e+00
  br i1 %41, label %98, label %102

90:                                               ; preds = %58
  %91 = load float, ptr %66, align 4, !invariant.load !1
  %92 = load float, ptr %64, align 4, !invariant.load !1
  %93 = fmul contract float %91, %92
  %94 = fadd contract float %56, %93
  br label %96

95:                                               ; preds = %58
  br label %96

96:                                               ; preds = %95, %90
  %97 = phi float [ %56, %95 ], [ %94, %90 ]
  br label %54

98:                                               ; preds = %68
  %99 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %6, align 8
  %100 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %99, 0
  %101 = getelementptr inbounds float, ptr %100, i64 %37
  store float %89, ptr %101, align 4
  br label %103

102:                                              ; preds = %68
  br label %103

103:                                              ; preds = %102, %98
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  br label %104

104:                                              ; preds = %103, %43
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
