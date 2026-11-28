; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_compute_fn_float32_float32_float32_True_e831020f(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i32, i64 1, align 4
  %9 = alloca i32, i64 1, align 4
  %10 = sext i32 %3 to i64
  %11 = sext i32 %5 to i64
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %13 = zext i32 %12 to i64
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %15 = zext i32 %14 to i64
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %17 = sext i32 %16 to i64
  %18 = mul i64 %15, %17
  %19 = add i64 %18, %13
  %20 = udiv i64 %19, 32
  %21 = bitcast i64 %20 to <2 x i32>
  %22 = extractelement <2 x i32> %21, i64 0
  %23 = extractelement <2 x i32> %21, i64 1
  %24 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %22, i32 0, i32 31)
  %25 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %23, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i32 %24, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i32 %25, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %26 = insertvalue [2 x ptr] undef, ptr %9, 0
  %27 = insertvalue [2 x ptr] %26, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %27, ptr %7, align 8
  %28 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %29 = load ptr, ptr %28, align 8
  %30 = load i32, ptr %29, align 4
  %31 = insertelement <2 x i32> undef, i32 %30, i64 0
  %32 = getelementptr inbounds ptr, ptr %28, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = load i32, ptr %33, align 4
  %35 = insertelement <2 x i32> %31, i32 %34, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %36 = bitcast <2 x i32> %35 to i64
  %37 = getelementptr inbounds float, ptr %0, i64 %36
  %38 = sitofp i64 %36 to float
  %39 = mul i64 %36, %11
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %41 = sext i32 %40 to i64
  %42 = icmp eq i64 %41, 0
  %43 = icmp sge i64 %36, %10
  br i1 %43, label %44, label %45

44:                                               ; preds = %6
  br label %102

45:                                               ; preds = %6
  %46 = sdiv i64 %11, -32
  %47 = mul i64 %46, -32
  %48 = icmp eq i64 %47, %11
  %49 = xor i64 %11, -32
  %50 = ashr i64 %49, 63
  %51 = select i1 %48, i64 0, i64 %50
  %52 = add i64 %46, %51
  %53 = sub i64 0, %52
  %54 = call i64 @llvm.smax.i64(i64 %53, i64 0)
  br label %55

55:                                               ; preds = %97, %45
  %56 = phi i64 [ 0, %45 ], [ %62, %97 ]
  %57 = phi float [ 0.000000e+00, %45 ], [ %98, %97 ]
  %58 = icmp slt i64 %56, %54
  br i1 %58, label %59, label %69

59:                                               ; preds = %55
  %60 = icmp eq i64 %56, %54
  %61 = add i64 %56, 1
  %62 = select i1 %60, i64 %56, i64 %61
  %63 = mul i64 %56, 32
  %64 = add i64 %63, %41
  %65 = getelementptr inbounds float, ptr %2, i64 %64
  %66 = add i64 %39, %64
  %67 = getelementptr inbounds float, ptr %1, i64 %66
  %68 = icmp slt i64 %64, %11
  br i1 %68, label %91, label %96

69:                                               ; preds = %55
  %70 = bitcast float %57 to i32
  %71 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %70, i32 16, i32 31)
  %72 = bitcast i32 %71 to float
  %73 = fadd contract float %57, %72
  %74 = bitcast float %73 to i32
  %75 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %74, i32 8, i32 31)
  %76 = bitcast i32 %75 to float
  %77 = fadd contract float %73, %76
  %78 = bitcast float %77 to i32
  %79 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %78, i32 4, i32 31)
  %80 = bitcast i32 %79 to float
  %81 = fadd contract float %77, %80
  %82 = bitcast float %81 to i32
  %83 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %82, i32 2, i32 31)
  %84 = bitcast i32 %83 to float
  %85 = fadd contract float %81, %84
  %86 = bitcast float %85 to i32
  %87 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %86, i32 1, i32 31)
  %88 = bitcast i32 %87 to float
  %89 = fadd contract float %85, %88
  %90 = fadd contract float %89, %38
  br i1 %42, label %99, label %100

91:                                               ; preds = %59
  %92 = load float, ptr %67, align 4, !invariant.load !1
  %93 = load float, ptr %65, align 4, !invariant.load !1
  %94 = fmul contract float %92, %93
  %95 = fadd contract float %57, %94
  br label %97

96:                                               ; preds = %59
  br label %97

97:                                               ; preds = %96, %91
  %98 = phi float [ %57, %96 ], [ %95, %91 ]
  br label %55

99:                                               ; preds = %69
  store float %90, ptr %37, align 4
  br label %101

100:                                              ; preds = %69
  br label %101

101:                                              ; preds = %100, %99
  br label %102

102:                                              ; preds = %101, %44
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
