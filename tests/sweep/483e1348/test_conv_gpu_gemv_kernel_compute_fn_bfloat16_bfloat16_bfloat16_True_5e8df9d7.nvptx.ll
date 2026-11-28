; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_compute_fn_bfloat16_bfloat16_bfloat16_True_5e8df9d7(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, { i64, i64, i64, {} } noundef %6) #0 {
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
  %38 = getelementptr inbounds bfloat, ptr %0, i64 %37
  %39 = mul i64 %37, %12
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %41 = sext i32 %40 to i64
  %42 = icmp eq i64 %41, 0
  %43 = icmp sge i64 %37, %11
  br i1 %43, label %44, label %45

44:                                               ; preds = %7
  br label %107

45:                                               ; preds = %7
  %46 = sdiv i64 %12, -32
  %47 = mul i64 %46, -32
  %48 = icmp eq i64 %47, %12
  %49 = xor i64 %12, -32
  %50 = ashr i64 %49, 63
  %51 = select i1 %48, i64 0, i64 %50
  %52 = add i64 %46, %51
  %53 = sub i64 0, %52
  %54 = call i64 @llvm.smax.i64(i64 %53, i64 0)
  br label %55

55:                                               ; preds = %102, %45
  %56 = phi i64 [ 0, %45 ], [ %62, %102 ]
  %57 = phi float [ 0.000000e+00, %45 ], [ %103, %102 ]
  %58 = icmp slt i64 %56, %54
  br i1 %58, label %59, label %69

59:                                               ; preds = %55
  %60 = icmp eq i64 %56, %54
  %61 = add i64 %56, 1
  %62 = select i1 %60, i64 %56, i64 %61
  %63 = mul i64 %56, 32
  %64 = add i64 %63, %41
  %65 = getelementptr inbounds bfloat, ptr %2, i64 %64
  %66 = add i64 %39, %64
  %67 = getelementptr inbounds bfloat, ptr %1, i64 %66
  %68 = icmp slt i64 %64, %12
  br i1 %68, label %94, label %101

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
  %90 = fptrunc float %89 to bfloat
  %91 = fpext bfloat %90 to float
  %92 = fmul contract float %91, 2.000000e+00
  %93 = fptrunc float %92 to bfloat
  br i1 %42, label %104, label %105

94:                                               ; preds = %59
  %95 = load bfloat, ptr %67, align 2, !invariant.load !1
  %96 = fpext bfloat %95 to float
  %97 = load bfloat, ptr %65, align 2, !invariant.load !1
  %98 = fpext bfloat %97 to float
  %99 = fmul contract float %96, %98
  %100 = fadd contract float %57, %99
  br label %102

101:                                              ; preds = %59
  br label %102

102:                                              ; preds = %101, %94
  %103 = phi float [ %57, %101 ], [ %100, %94 ]
  br label %55

104:                                              ; preds = %69
  store bfloat %93, ptr %38, align 2
  br label %106

105:                                              ; preds = %69
  br label %106

106:                                              ; preds = %105, %104
  br label %107

107:                                              ; preds = %106, %44
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
