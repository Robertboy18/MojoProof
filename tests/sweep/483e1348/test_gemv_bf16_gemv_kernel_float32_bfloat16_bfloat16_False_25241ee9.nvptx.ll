; ModuleID = 'test_gemv_bf16.mojo'
source_filename = "test_gemv_bf16.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_float32_bfloat16_bfloat16_False_25241ee9(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %38 = mul i64 %36, %11
  %39 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %40 = sext i32 %39 to i64
  %41 = icmp eq i64 %40, 0
  %42 = icmp sge i64 %36, %10
  br i1 %42, label %43, label %44

43:                                               ; preds = %6
  br label %102

44:                                               ; preds = %6
  %45 = sdiv i64 %11, -32
  %46 = mul i64 %45, -32
  %47 = icmp eq i64 %46, %11
  %48 = xor i64 %11, -32
  %49 = ashr i64 %48, 63
  %50 = select i1 %47, i64 0, i64 %49
  %51 = add i64 %45, %50
  %52 = sub i64 0, %51
  %53 = call i64 @llvm.smax.i64(i64 %52, i64 0)
  br label %54

54:                                               ; preds = %97, %44
  %55 = phi i64 [ 0, %44 ], [ %61, %97 ]
  %56 = phi float [ 0.000000e+00, %44 ], [ %98, %97 ]
  %57 = icmp slt i64 %55, %53
  br i1 %57, label %58, label %68

58:                                               ; preds = %54
  %59 = icmp eq i64 %55, %53
  %60 = add i64 %55, 1
  %61 = select i1 %59, i64 %55, i64 %60
  %62 = mul i64 %55, 32
  %63 = add i64 %62, %40
  %64 = getelementptr inbounds bfloat, ptr %2, i64 %63
  %65 = add i64 %38, %63
  %66 = getelementptr inbounds bfloat, ptr %1, i64 %65
  %67 = icmp slt i64 %63, %11
  br i1 %67, label %89, label %96

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
  br i1 %41, label %99, label %100

89:                                               ; preds = %58
  %90 = load bfloat, ptr %66, align 2, !invariant.load !1
  %91 = fpext bfloat %90 to float
  %92 = load bfloat, ptr %64, align 2, !invariant.load !1
  %93 = fpext bfloat %92 to float
  %94 = fmul contract float %91, %93
  %95 = fadd contract float %56, %94
  br label %97

96:                                               ; preds = %58
  br label %97

97:                                               ; preds = %96, %89
  %98 = phi float [ %56, %96 ], [ %95, %89 ]
  br label %54

99:                                               ; preds = %68
  store float %88, ptr %37, align 4
  br label %101

100:                                              ; preds = %68
  br label %101

101:                                              ; preds = %100, %99
  br label %102

102:                                              ; preds = %101, %43
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
