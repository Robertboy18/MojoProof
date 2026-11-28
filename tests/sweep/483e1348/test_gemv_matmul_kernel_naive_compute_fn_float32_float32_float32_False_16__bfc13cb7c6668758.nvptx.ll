; ModuleID = 'test_gemv.mojo'
source_filename = "test_gemv.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_compute_fn_float32_float32_float32_False_16_1e8c5738(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, float noundef %6) #0 {
  %8 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %9 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %10 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %11 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %10, 0
  %12 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %10, 1, 1, 0
  %13 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 0
  %14 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 1, 1, 0
  %15 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %8, 0
  %16 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %8, 1, 1, 0
  %17 = sext i32 %3 to i64
  %18 = sext i32 %4 to i64
  %19 = sext i32 %5 to i64
  %20 = call i64 @llvm.smax.i64(i64 %19, i64 0)
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %22 = zext i32 %21 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %24 = zext i32 %23 to i64
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %26 = sext i32 %25 to i64
  %27 = mul i64 %24, %26
  %28 = add i64 %27, %22
  %29 = mul i64 %28, %14
  %30 = mul i64 %28, %12
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %34 = zext i32 %33 to i64
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %36 = sext i32 %35 to i64
  %37 = mul i64 %34, %36
  %38 = add i64 %37, %32
  %39 = add i64 %30, %38
  %40 = getelementptr inbounds float, ptr %11, i64 %39
  %41 = icmp sge i64 %28, %17
  %42 = icmp sge i64 %38, %18
  %43 = select i1 %41, i1 true, i1 %42
  br i1 %43, label %44, label %45

44:                                               ; preds = %7
  br label %65

45:                                               ; preds = %7
  br label %46

46:                                               ; preds = %50, %45
  %47 = phi i64 [ 0, %45 ], [ %53, %50 ]
  %48 = phi float [ 0.000000e+00, %45 ], [ %62, %50 ]
  %49 = icmp slt i64 %47, %20
  br i1 %49, label %50, label %63

50:                                               ; preds = %46
  %51 = icmp eq i64 %47, %20
  %52 = add i64 %47, 1
  %53 = select i1 %51, i64 %47, i64 %52
  %54 = add i64 %29, %47
  %55 = getelementptr inbounds float, ptr %13, i64 %54
  %56 = load float, ptr %55, align 4, !invariant.load !1
  %57 = mul i64 %47, %16
  %58 = add i64 %57, %38
  %59 = getelementptr inbounds float, ptr %15, i64 %58
  %60 = load float, ptr %59, align 4, !invariant.load !1
  %61 = fmul contract float %56, %60
  %62 = fadd contract float %48, %61
  br label %46

63:                                               ; preds = %46
  %64 = fadd contract float %48, %6
  store float %64, ptr %40, align 4
  br label %65

65:                                               ; preds = %63, %44
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
