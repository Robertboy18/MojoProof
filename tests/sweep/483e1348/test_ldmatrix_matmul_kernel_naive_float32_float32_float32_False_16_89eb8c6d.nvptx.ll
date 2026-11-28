; ModuleID = 'test_ldmatrix.mojo'
source_filename = "test_ldmatrix.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float32_float32_float32_False_16_89eb8c6d(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %38 = add i64 %29, %37
  %39 = getelementptr inbounds float, ptr %10, i64 %38
  %40 = icmp sge i64 %27, %16
  %41 = icmp sge i64 %37, %17
  %42 = select i1 %40, i1 true, i1 %41
  br i1 %42, label %43, label %44

43:                                               ; preds = %6
  br label %63

44:                                               ; preds = %6
  br label %45

45:                                               ; preds = %49, %44
  %46 = phi i64 [ 0, %44 ], [ %52, %49 ]
  %47 = phi float [ 0.000000e+00, %44 ], [ %61, %49 ]
  %48 = icmp slt i64 %46, %19
  br i1 %48, label %49, label %62

49:                                               ; preds = %45
  %50 = icmp eq i64 %46, %19
  %51 = add i64 %46, 1
  %52 = select i1 %50, i64 %46, i64 %51
  %53 = add i64 %28, %46
  %54 = getelementptr inbounds float, ptr %12, i64 %53
  %55 = load float, ptr %54, align 4, !invariant.load !1
  %56 = mul i64 %46, %15
  %57 = add i64 %56, %37
  %58 = getelementptr inbounds float, ptr %14, i64 %57
  %59 = load float, ptr %58, align 4, !invariant.load !1
  %60 = fmul contract float %55, %59
  %61 = fadd contract float %47, %60
  br label %45

62:                                               ; preds = %45
  store float %47, ptr %39, align 4
  br label %63

63:                                               ; preds = %62, %43
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
