; ModuleID = 'test_ragged_matmul_native_views.mojo'
source_filename = "test_ragged_matmul_native_views.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_epilogue_fn_float32_float32_float32_True_2eb4c7c3(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
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
  %38 = trunc i64 %37 to i32
  %39 = sext i32 %38 to i64
  %40 = mul i64 %37, %12
  %41 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %42 = sext i32 %41 to i64
  %43 = icmp eq i64 %42, 0
  %44 = icmp sge i64 %37, %11
  br i1 %44, label %45, label %46

45:                                               ; preds = %7
  br label %105

46:                                               ; preds = %7
  %47 = sdiv i64 %12, -32
  %48 = mul i64 %47, -32
  %49 = icmp eq i64 %48, %12
  %50 = xor i64 %12, -32
  %51 = ashr i64 %50, 63
  %52 = select i1 %49, i64 0, i64 %51
  %53 = add i64 %47, %52
  %54 = sub i64 0, %53
  %55 = call i64 @llvm.smax.i64(i64 %54, i64 0)
  br label %56

56:                                               ; preds = %97, %46
  %57 = phi i64 [ 0, %46 ], [ %63, %97 ]
  %58 = phi float [ 0.000000e+00, %46 ], [ %98, %97 ]
  %59 = icmp slt i64 %57, %55
  br i1 %59, label %60, label %70

60:                                               ; preds = %56
  %61 = icmp eq i64 %57, %55
  %62 = add i64 %57, 1
  %63 = select i1 %61, i64 %57, i64 %62
  %64 = mul i64 %57, 32
  %65 = add i64 %64, %42
  %66 = getelementptr inbounds float, ptr %2, i64 %65
  %67 = add i64 %40, %65
  %68 = getelementptr inbounds float, ptr %1, i64 %67
  %69 = icmp slt i64 %65, %12
  br i1 %69, label %91, label %96

70:                                               ; preds = %56
  %71 = bitcast float %58 to i32
  %72 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %71, i32 16, i32 31)
  %73 = bitcast i32 %72 to float
  %74 = fadd contract float %58, %73
  %75 = bitcast float %74 to i32
  %76 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %75, i32 8, i32 31)
  %77 = bitcast i32 %76 to float
  %78 = fadd contract float %74, %77
  %79 = bitcast float %78 to i32
  %80 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %79, i32 4, i32 31)
  %81 = bitcast i32 %80 to float
  %82 = fadd contract float %78, %81
  %83 = bitcast float %82 to i32
  %84 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %83, i32 2, i32 31)
  %85 = bitcast i32 %84 to float
  %86 = fadd contract float %82, %85
  %87 = bitcast float %86 to i32
  %88 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %87, i32 1, i32 31)
  %89 = bitcast i32 %88 to float
  %90 = fadd contract float %86, %89
  br i1 %43, label %99, label %103

91:                                               ; preds = %60
  %92 = load float, ptr %68, align 4, !invariant.load !1
  %93 = load float, ptr %66, align 4, !invariant.load !1
  %94 = fmul contract float %92, %93
  %95 = fadd contract float %58, %94
  br label %97

96:                                               ; preds = %60
  br label %97

97:                                               ; preds = %96, %91
  %98 = phi float [ %58, %96 ], [ %95, %91 ]
  br label %56

99:                                               ; preds = %70
  %100 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %101 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %100, 0
  %102 = getelementptr inbounds float, ptr %101, i64 %39
  store float %90, ptr %102, align 4
  br label %104

103:                                              ; preds = %70
  br label %104

104:                                              ; preds = %103, %99
  br label %105

105:                                              ; preds = %104, %45
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.idx.i32(i32, i32, i32, i32) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #2

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
