; ModuleID = 'test_ragged_matmul_native_views.mojo'
source_filename = "test_ragged_matmul_native_views.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_epilogue_fn_float32_float32_float32_True_16_c44e2616(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
  %8 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %9 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %10 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %9, 0
  %11 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %8, 0
  %12 = sext i32 %3 to i64
  %13 = sext i32 %4 to i64
  %14 = sext i32 %5 to i64
  %15 = call i64 @llvm.smax.i64(i64 %14, i64 0)
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %17 = zext i32 %16 to i64
  %18 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %19 = zext i32 %18 to i64
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %21 = sext i32 %20 to i64
  %22 = mul i64 %19, %21
  %23 = add i64 %22, %17
  %24 = mul i64 %23, 64
  %25 = trunc i64 %23 to i32
  %26 = mul i32 %25, 80
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %32 = sext i32 %31 to i64
  %33 = mul i64 %30, %32
  %34 = add i64 %33, %28
  %35 = trunc i64 %34 to i32
  %36 = mul i32 %35, 64
  %37 = add i32 %26, %35
  %38 = sext i32 %37 to i64
  %39 = icmp sge i64 %23, %12
  %40 = icmp sge i64 %34, %13
  %41 = select i1 %39, i1 true, i1 %40
  br i1 %41, label %42, label %43

42:                                               ; preds = %7
  br label %66

43:                                               ; preds = %7
  br label %44

44:                                               ; preds = %48, %43
  %45 = phi i64 [ 0, %43 ], [ %51, %48 ]
  %46 = phi float [ 0.000000e+00, %43 ], [ %61, %48 ]
  %47 = icmp slt i64 %45, %15
  br i1 %47, label %48, label %62

48:                                               ; preds = %44
  %49 = icmp eq i64 %45, %15
  %50 = add i64 %45, 1
  %51 = select i1 %49, i64 %45, i64 %50
  %52 = add i64 %24, %45
  %53 = getelementptr inbounds float, ptr %10, i64 %52
  %54 = load float, ptr %53, align 4, !invariant.load !1
  %55 = trunc i64 %45 to i32
  %56 = add i32 %36, %55
  %57 = sext i32 %56 to i64
  %58 = getelementptr inbounds float, ptr %11, i64 %57
  %59 = load float, ptr %58, align 4, !invariant.load !1
  %60 = fmul contract float %54, %59
  %61 = fadd contract float %46, %60
  br label %44

62:                                               ; preds = %44
  %63 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %64 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %63, 0
  %65 = getelementptr inbounds float, ptr %64, i64 %38
  store float %46, ptr %65, align 4
  br label %66

66:                                               ; preds = %62, %42
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
