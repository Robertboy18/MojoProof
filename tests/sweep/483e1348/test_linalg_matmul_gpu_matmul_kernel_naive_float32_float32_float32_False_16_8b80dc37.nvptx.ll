; ModuleID = 'test_linalg_matmul_gpu.mojo'
source_filename = "test_linalg_matmul_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float32_float32_float32_False_16_8b80dc37(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %8 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %9 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %10 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %9, 0
  %11 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %8, 0
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
  %25 = mul i64 %24, 4
  %26 = mul i64 %24, 8
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %32 = sext i32 %31 to i64
  %33 = mul i64 %30, %32
  %34 = add i64 %33, %28
  %35 = trunc i64 %34 to i32
  %36 = add i64 %26, %34
  %37 = getelementptr inbounds float, ptr %10, i64 %36
  %38 = icmp sge i64 %24, %13
  %39 = icmp sge i64 %34, %14
  %40 = select i1 %38, i1 true, i1 %39
  br i1 %40, label %41, label %42

41:                                               ; preds = %6
  br label %63

42:                                               ; preds = %6
  br label %43

43:                                               ; preds = %47, %42
  %44 = phi i64 [ 0, %42 ], [ %50, %47 ]
  %45 = phi float [ 0.000000e+00, %42 ], [ %61, %47 ]
  %46 = icmp slt i64 %44, %16
  br i1 %46, label %47, label %62

47:                                               ; preds = %43
  %48 = icmp eq i64 %44, %16
  %49 = add i64 %44, 1
  %50 = select i1 %48, i64 %44, i64 %49
  %51 = add i64 %25, %44
  %52 = getelementptr inbounds float, ptr %11, i64 %51
  %53 = load float, ptr %52, align 4, !invariant.load !1
  %54 = trunc i64 %44 to i32
  %55 = mul i32 %54, 8
  %56 = add i32 %55, %35
  %57 = sext i32 %56 to i64
  %58 = getelementptr inbounds float, ptr %12, i64 %57
  %59 = load float, ptr %58, align 4, !invariant.load !1
  %60 = fmul contract float %53, %59
  %61 = fadd contract float %45, %60
  br label %43

62:                                               ; preds = %43
  store float %45, ptr %37, align 4
  br label %63

63:                                               ; preds = %62, %41
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
