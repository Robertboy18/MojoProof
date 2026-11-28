; ModuleID = 'test_mma_ws_partial_sm100.mojo'
source_filename = "test_mma_ws_partial_sm100.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float32_bfloat16_bfloat16_True_16_2c65e51f(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %8 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %9 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %10 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 0
  %11 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 1, 1, 0
  %12 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %8, 0
  %13 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %7, 0
  %14 = sext i32 %3 to i64
  %15 = sext i32 %4 to i64
  %16 = sext i32 %5 to i64
  %17 = call i64 @llvm.smax.i64(i64 %16, i64 0)
  %18 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %19 = zext i32 %18 to i64
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %21 = zext i32 %20 to i64
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %23 = sext i32 %22 to i64
  %24 = mul i64 %21, %23
  %25 = add i64 %24, %19
  %26 = trunc i64 %25 to i32
  %27 = mul i32 %26, 512
  %28 = mul i64 %25, %11
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %34 = sext i32 %33 to i64
  %35 = mul i64 %32, %34
  %36 = add i64 %35, %30
  %37 = trunc i64 %36 to i32
  %38 = mul i32 %37, 512
  %39 = add i64 %28, %36
  %40 = getelementptr inbounds float, ptr %10, i64 %39
  %41 = icmp sge i64 %25, %14
  %42 = icmp sge i64 %36, %15
  %43 = select i1 %41, i1 true, i1 %42
  br i1 %43, label %44, label %45

44:                                               ; preds = %6
  br label %68

45:                                               ; preds = %6
  br label %46

46:                                               ; preds = %50, %45
  %47 = phi i64 [ 0, %45 ], [ %53, %50 ]
  %48 = phi float [ 0.000000e+00, %45 ], [ %66, %50 ]
  %49 = icmp slt i64 %47, %17
  br i1 %49, label %50, label %67

50:                                               ; preds = %46
  %51 = icmp eq i64 %47, %17
  %52 = add i64 %47, 1
  %53 = select i1 %51, i64 %47, i64 %52
  %54 = trunc i64 %47 to i32
  %55 = add i32 %27, %54
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds bfloat, ptr %12, i64 %56
  %58 = load bfloat, ptr %57, align 2, !invariant.load !1
  %59 = fpext bfloat %58 to float
  %60 = add i32 %38, %54
  %61 = sext i32 %60 to i64
  %62 = getelementptr inbounds bfloat, ptr %13, i64 %61
  %63 = load bfloat, ptr %62, align 2, !invariant.load !1
  %64 = fpext bfloat %63 to float
  %65 = fmul contract float %59, %64
  %66 = fadd contract float %48, %65
  br label %46

67:                                               ; preds = %46
  store float %48, ptr %40, align 4
  br label %68

68:                                               ; preds = %67, %44
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

attributes #0 = { norecurse "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
