; ModuleID = 'gemv_f32.mojo'
source_filename = "gemv_f32.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_float32_float32_float32_False_b79a852b(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  br label %103

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

54:                                               ; preds = %76, %44
  %55 = phi i64 [ 0, %44 ], [ %63, %76 ]
  %56 = phi float [ 0.000000e+00, %44 ], [ %77, %76 ]
  %57 = icmp slt i64 %55, %53
  br i1 %57, label %58, label %59

58:                                               ; preds = %54
  br label %60

59:                                               ; preds = %54
  br label %78

60:                                               ; preds = %58
  %61 = icmp eq i64 %55, %53
  %62 = add i64 %55, 1
  %63 = select i1 %61, i64 %55, i64 %62
  %64 = mul i64 %55, 32
  %65 = add i64 %64, %40
  %66 = getelementptr inbounds float, ptr %2, i64 %65
  %67 = add i64 %38, %65
  %68 = getelementptr inbounds float, ptr %1, i64 %67
  %69 = icmp slt i64 %65, %11
  br i1 %69, label %70, label %75

70:                                               ; preds = %60
  %71 = load float, ptr %68, align 4, !invariant.load !1
  %72 = load float, ptr %66, align 4, !invariant.load !1
  %73 = fmul contract float %71, %72
  %74 = fadd contract float %56, %73
  br label %76

75:                                               ; preds = %60
  br label %76

76:                                               ; preds = %75, %70
  %77 = phi float [ %56, %75 ], [ %74, %70 ]
  br label %54

78:                                               ; preds = %59
  %79 = phi float [ %56, %59 ]
  %80 = bitcast float %79 to i32
  %81 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %80, i32 16, i32 31)
  %82 = bitcast i32 %81 to float
  %83 = fadd contract float %79, %82
  %84 = bitcast float %83 to i32
  %85 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %84, i32 8, i32 31)
  %86 = bitcast i32 %85 to float
  %87 = fadd contract float %83, %86
  %88 = bitcast float %87 to i32
  %89 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %88, i32 4, i32 31)
  %90 = bitcast i32 %89 to float
  %91 = fadd contract float %87, %90
  %92 = bitcast float %91 to i32
  %93 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %92, i32 2, i32 31)
  %94 = bitcast i32 %93 to float
  %95 = fadd contract float %91, %94
  %96 = bitcast float %95 to i32
  %97 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %96, i32 1, i32 31)
  %98 = bitcast i32 %97 to float
  %99 = fadd contract float %95, %98
  br i1 %41, label %100, label %101

100:                                              ; preds = %78
  store float %99, ptr %37, align 4
  br label %102

101:                                              ; preds = %78
  br label %102

102:                                              ; preds = %101, %100
  br label %103

103:                                              ; preds = %102, %43
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
