; ModuleID = 'test_vendor_blas_matmul.mojo'
source_filename = "test_vendor_blas_matmul.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float32_bfloat16_bfloat16_True_16_e58bb4a5(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %8 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %9 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %10 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 0
  %11 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 1, 1, 0
  %12 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %8, 0
  %13 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %8, 1, 1, 0
  %14 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %7, 0
  %15 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %7, 1, 1, 0
  %16 = sext i32 %3 to i64
  %17 = sext i32 %4 to i64
  %18 = sext i32 %5 to i64
  %19 = call i64 @llvm.smax.i64(i64 %18, i64 0)
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %21 = zext i32 %20 to i64
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %23 = zext i32 %22 to i64
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %25 = sext i32 %24 to i64
  %26 = mul i64 %23, %25
  %27 = add i64 %26, %21
  %28 = mul i64 %27, %13
  %29 = mul i64 %27, %11
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %31 = zext i32 %30 to i64
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %33 = zext i32 %32 to i64
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %35 = sext i32 %34 to i64
  %36 = mul i64 %33, %35
  %37 = add i64 %36, %31
  %38 = mul i64 %37, %15
  %39 = add i64 %29, %37
  %40 = getelementptr inbounds float, ptr %10, i64 %39
  %41 = icmp sge i64 %27, %16
  %42 = icmp sge i64 %37, %17
  %43 = select i1 %41, i1 true, i1 %42
  br i1 %43, label %44, label %45

44:                                               ; preds = %6
  br label %65

45:                                               ; preds = %6
  br label %46

46:                                               ; preds = %50, %45
  %47 = phi i64 [ 0, %45 ], [ %53, %50 ]
  %48 = phi float [ 0.000000e+00, %45 ], [ %63, %50 ]
  %49 = icmp slt i64 %47, %19
  br i1 %49, label %50, label %64

50:                                               ; preds = %46
  %51 = icmp eq i64 %47, %19
  %52 = add i64 %47, 1
  %53 = select i1 %51, i64 %47, i64 %52
  %54 = add i64 %28, %47
  %55 = getelementptr inbounds bfloat, ptr %12, i64 %54
  %56 = load bfloat, ptr %55, align 2, !invariant.load !1
  %57 = fpext bfloat %56 to float
  %58 = add i64 %38, %47
  %59 = getelementptr inbounds bfloat, ptr %14, i64 %58
  %60 = load bfloat, ptr %59, align 2, !invariant.load !1
  %61 = fpext bfloat %60 to float
  %62 = fmul contract float %57, %61
  %63 = fadd contract float %48, %62
  br label %46

64:                                               ; preds = %46
  store float %48, ptr %40, align 4
  br label %65

65:                                               ; preds = %64, %44
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

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
