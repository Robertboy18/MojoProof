; ModuleID = 'test_multistage_gemm_kernel.mojo'
source_filename = "test_multistage_gemm_kernel.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float32_float32_float32_True_16_343aedc5(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %8 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %9 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %10 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %9, 0
  %11 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %8, 0
  %12 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %7, 0
  %13 = sext i32 %3 to i64
  %14 = sext i32 %4 to i64
  %15 = sext i32 %5 to i64
  %16 = call i64 @llvm.smax.i64(i64 %15, i64 0)
  %17 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %18 = zext i32 %17 to i64
  %19 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %20 = zext i32 %19 to i64
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %22 = sext i32 %21 to i64
  %23 = mul i64 %20, %22
  %24 = add i64 %23, %18
  %25 = trunc i64 %24 to i32
  %26 = mul i32 %25, 768
  %27 = mul i32 %25, 50257
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %29 = zext i32 %28 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %31 = zext i32 %30 to i64
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %33 = sext i32 %32 to i64
  %34 = mul i64 %31, %33
  %35 = add i64 %34, %29
  %36 = trunc i64 %35 to i32
  %37 = mul i32 %36, 768
  %38 = add i32 %27, %36
  %39 = sext i32 %38 to i64
  %40 = getelementptr inbounds float, ptr %10, i64 %39
  %41 = icmp sge i64 %24, %13
  %42 = icmp sge i64 %35, %14
  %43 = select i1 %41, i1 true, i1 %42
  br i1 %43, label %44, label %45

44:                                               ; preds = %6
  br label %66

45:                                               ; preds = %6
  br label %46

46:                                               ; preds = %50, %45
  %47 = phi i64 [ 0, %45 ], [ %53, %50 ]
  %48 = phi float [ 0.000000e+00, %45 ], [ %64, %50 ]
  %49 = icmp slt i64 %47, %16
  br i1 %49, label %50, label %65

50:                                               ; preds = %46
  %51 = icmp eq i64 %47, %16
  %52 = add i64 %47, 1
  %53 = select i1 %51, i64 %47, i64 %52
  %54 = trunc i64 %47 to i32
  %55 = add i32 %26, %54
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds float, ptr %11, i64 %56
  %58 = load float, ptr %57, align 4, !invariant.load !1
  %59 = add i32 %37, %54
  %60 = sext i32 %59 to i64
  %61 = getelementptr inbounds float, ptr %12, i64 %60
  %62 = load float, ptr %61, align 4, !invariant.load !1
  %63 = fmul float %58, %62
  %64 = fadd float %48, %63
  br label %46

65:                                               ; preds = %46
  store float %48, ptr %40, align 4
  br label %66

66:                                               ; preds = %65, %44
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

attributes #0 = { norecurse "target-cpu"="sm_90a" "target-features"="+ptx85,+sm_90a" "tune-cpu"="sm_90a" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
