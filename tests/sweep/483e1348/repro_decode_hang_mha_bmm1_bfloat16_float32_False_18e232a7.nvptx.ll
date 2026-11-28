; ModuleID = 'repro_decode_hang.mojo'
source_filename = "repro_decode_hang.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @mha_bmm1_bfloat16_float32_False_18e232a7(ptr noundef %0, ptr noundef %1, ptr noundef nonnull readonly byval({ { ptr, { { i64, i64, {}, {} }, { i64, {}, {}, {} } } }, { ptr, { {}, {} } } }) %2, { { i64, [1 x i64] }, i8 } noundef %3, i32 noundef %4, i32 noundef %5, i32 noundef %6, i32 noundef %7, i32 noundef %8) #0 {
  %10 = load { { ptr, { { i64, i64, {}, {} }, { i64, {}, {}, {} } } }, { ptr, { {}, {} } } }, ptr %2, align 8
  %11 = extractvalue { { ptr, { { i64, i64, {}, {} }, { i64, {}, {}, {} } } }, { ptr, { {}, {} } } } %10, 0, 0
  %12 = extractvalue { { ptr, { { i64, i64, {}, {} }, { i64, {}, {}, {} } } }, { ptr, { {}, {} } } } %10, 0, 1, 1, 0
  %13 = sext i32 %8 to i64
  %14 = icmp eq i64 %13, 0
  %15 = select i1 %14, i64 1, i64 %13
  %16 = sext i32 %4 to i64
  %17 = sext i32 %5 to i64
  %18 = call i64 @llvm.smax.i64(i64 %17, i64 0)
  %19 = sext i32 %6 to i64
  %20 = sext i32 %7 to i64
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %22 = zext i32 %21 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %24 = zext i32 %23 to i64
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %26 = sext i32 %25 to i64
  %27 = mul i64 %24, %26
  %28 = add i64 %27, %22
  %29 = trunc i64 %28 to i32
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %34 = zext i32 %33 to i64
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %36 = sext i32 %35 to i64
  %37 = mul i64 %34, %36
  %38 = add i64 %37, %32
  %39 = mul i64 %38, %17
  %40 = mul i64 %38, %19
  %41 = mul i64 %40, %20
  %42 = add i64 %41, %28
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %44 = zext i32 %43 to i64
  %45 = icmp eq i64 %19, 0
  %46 = select i1 %45, i64 1, i64 %19
  %47 = icmp eq i64 %46, 0
  %48 = select i1 %47, i64 1, i64 %46
  %49 = udiv i64 %44, %48
  %50 = select i1 %47, i64 0, i64 %49
  %51 = urem i64 %44, %48
  %52 = select i1 %47, i64 0, i64 %51
  %53 = select i1 %45, i64 0, i64 %50
  %54 = select i1 %45, i64 0, i64 %52
  %55 = trunc i64 %53 to i32
  %56 = zext i32 %55 to i64
  %57 = mul i64 %56, %12
  %58 = mul i64 %44, %16
  %59 = mul i64 %58, %17
  %60 = getelementptr inbounds float, ptr %1, i64 %59
  %61 = mul i64 %19, %16
  %62 = mul i64 %61, %53
  %63 = add i64 %54, %62
  %64 = mul i64 %20, %63
  %65 = getelementptr inbounds bfloat, ptr %0, i64 %64
  %66 = getelementptr inbounds bfloat, ptr %65, i64 %42
  %67 = icmp sge i64 %28, %20
  %68 = icmp sge i64 %38, %16
  %69 = select i1 %67, i1 true, i1 %68
  br i1 %69, label %70, label %71

70:                                               ; preds = %9
  br label %101

71:                                               ; preds = %9
  %72 = udiv i64 %54, %15
  %73 = select i1 %14, i64 0, i64 %72
  %74 = trunc i64 %73 to i32
  %75 = zext i32 %74 to i64
  %76 = mul i64 %75, 128
  br label %77

77:                                               ; preds = %81, %71
  %78 = phi i64 [ 0, %71 ], [ %84, %81 ]
  %79 = phi float [ 0.000000e+00, %71 ], [ %98, %81 ]
  %80 = icmp slt i64 %78, %18
  br i1 %80, label %81, label %99

81:                                               ; preds = %77
  %82 = icmp eq i64 %78, %18
  %83 = add i64 %78, 1
  %84 = select i1 %82, i64 %78, i64 %83
  %85 = trunc i64 %78 to i32
  %86 = zext i32 %85 to i64
  %87 = mul i64 %86, 4096
  %88 = add i64 %57, %87
  %89 = add i64 %88, %76
  %90 = add i64 %89, %30
  %91 = getelementptr inbounds bfloat, ptr %11, i64 %90
  %92 = add i64 %39, %78
  %93 = getelementptr inbounds float, ptr %60, i64 %92
  %94 = load float, ptr %93, align 4
  %95 = load bfloat, ptr %91, align 2
  %96 = fpext bfloat %95 to float
  %97 = fmul contract float %94, %96
  %98 = fadd contract float %79, %97
  br label %77

99:                                               ; preds = %77
  %100 = fptrunc float %79 to bfloat
  store bfloat %100, ptr %66, align 2
  br label %101

101:                                              ; preds = %99, %70
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.z() #2

attributes #0 = { norecurse "nvvm.maxntid"="512" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
