; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @naive_batched_matmul_kernel_float32_float32_float32_False_compute_fn_b210ecc9(ptr noundef nonnull readonly byval({ ptr, { { i64, i64, i64 }, { i64, i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64, i64 }, { i64, i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64, i64 }, { i64, i64, {} } } }) %2, { i64, i64, i64 } noundef %3) #0 {
  %5 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %2, align 8
  %6 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %1, align 8
  %7 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %0, align 8
  %8 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %7, 0
  %9 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %7, 1, 0, 0
  %10 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %7, 1, 0, 1
  %11 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %7, 1, 0, 2
  %12 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %7, 1, 1, 0
  %13 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %7, 1, 1, 1
  %14 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %6, 0
  %15 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %6, 1, 0, 2
  %16 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %6, 1, 1, 0
  %17 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %6, 1, 1, 1
  %18 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5, 0
  %19 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5, 1, 1, 0
  %20 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5, 1, 1, 1
  %21 = call i64 @llvm.smax.i64(i64 %15, i64 0)
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %23 = zext i32 %22 to i64
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %25 = zext i32 %24 to i64
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %27 = sext i32 %26 to i64
  %28 = mul i64 %25, %27
  %29 = add i64 %28, %23
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %31 = zext i32 %30 to i64
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %33 = zext i32 %32 to i64
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %35 = sext i32 %34 to i64
  %36 = mul i64 %33, %35
  %37 = add i64 %36, %31
  %38 = mul i64 %37, %17
  %39 = mul i64 %37, %13
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %41 = zext i32 %40 to i64
  %42 = mul i64 %41, %16
  %43 = add i64 %42, %38
  %44 = mul i64 %41, %19
  %45 = mul i64 %41, %12
  %46 = add i64 %45, %39
  %47 = add i64 %46, %29
  %48 = getelementptr inbounds float, ptr %8, i64 %47
  %49 = icmp sge i64 %41, %9
  %50 = icmp sge i64 %29, %11
  %51 = select i1 %49, i1 true, i1 %50
  %52 = icmp sge i64 %37, %10
  %53 = select i1 %51, i1 true, i1 %52
  br i1 %53, label %54, label %55

54:                                               ; preds = %4
  br label %76

55:                                               ; preds = %4
  br label %56

56:                                               ; preds = %60, %55
  %57 = phi i64 [ 0, %55 ], [ %63, %60 ]
  %58 = phi float [ 0.000000e+00, %55 ], [ %73, %60 ]
  %59 = icmp slt i64 %57, %21
  br i1 %59, label %60, label %74

60:                                               ; preds = %56
  %61 = icmp eq i64 %57, %21
  %62 = add i64 %57, 1
  %63 = select i1 %61, i64 %57, i64 %62
  %64 = mul i64 %57, %20
  %65 = add i64 %44, %64
  %66 = add i64 %65, %29
  %67 = getelementptr inbounds float, ptr %18, i64 %66
  %68 = load float, ptr %67, align 4, !invariant.load !1
  %69 = add i64 %43, %57
  %70 = getelementptr inbounds float, ptr %14, i64 %69
  %71 = load float, ptr %70, align 4, !invariant.load !1
  %72 = fmul contract float %71, %68
  %73 = fadd contract float %58, %72
  br label %56

74:                                               ; preds = %56
  %75 = fadd contract float %58, 2.000000e+00
  store float %75, ptr %48, align 4
  br label %76

76:                                               ; preds = %74, %54
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

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
