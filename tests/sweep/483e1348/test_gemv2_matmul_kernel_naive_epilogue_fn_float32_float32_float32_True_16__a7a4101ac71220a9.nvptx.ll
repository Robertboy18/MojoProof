; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_epilogue_fn_float32_float32_float32_True_16_0560c3ff(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }) %6) #0 {
  %8 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %9 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %10 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %9, 0
  %11 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %8, 0
  %12 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 2
  %13 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 1
  %14 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 0
  %15 = sext i32 %3 to i64
  %16 = sext i32 %4 to i64
  %17 = sext i32 %5 to i64
  %18 = call i64 @llvm.smax.i64(i64 %17, i64 0)
  %19 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %20 = zext i32 %19 to i64
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %22 = zext i32 %21 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %24 = sext i32 %23 to i64
  %25 = mul i64 %22, %24
  %26 = add i64 %25, %20
  %27 = mul i64 %26, 32
  %28 = trunc i64 %26 to i32
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %34 = sext i32 %33 to i64
  %35 = mul i64 %32, %34
  %36 = add i64 %35, %30
  %37 = trunc i64 %36 to i32
  %38 = mul i32 %37, 32
  %39 = add i64 %26, %36
  %40 = icmp sge i64 %26, %15
  %41 = icmp sge i64 %36, %16
  %42 = select i1 %40, i1 true, i1 %41
  br i1 %42, label %43, label %44

43:                                               ; preds = %7
  br label %73

44:                                               ; preds = %7
  br label %45

45:                                               ; preds = %49, %44
  %46 = phi i64 [ 0, %44 ], [ %52, %49 ]
  %47 = phi float [ 0.000000e+00, %44 ], [ %62, %49 ]
  %48 = icmp slt i64 %46, %18
  br i1 %48, label %49, label %63

49:                                               ; preds = %45
  %50 = icmp eq i64 %46, %18
  %51 = add i64 %46, 1
  %52 = select i1 %50, i64 %46, i64 %51
  %53 = add i64 %27, %46
  %54 = getelementptr inbounds float, ptr %10, i64 %53
  %55 = load float, ptr %54, align 4, !invariant.load !1
  %56 = trunc i64 %46 to i32
  %57 = add i32 %38, %56
  %58 = sext i32 %57 to i64
  %59 = getelementptr inbounds float, ptr %11, i64 %58
  %60 = load float, ptr %59, align 4, !invariant.load !1
  %61 = fmul contract float %55, %60
  %62 = fadd contract float %47, %61
  br label %45

63:                                               ; preds = %45
  %64 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %14, align 8
  %65 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %13, align 8
  %66 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %12, align 8
  %67 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %64, 0
  %68 = getelementptr inbounds float, ptr %67, i64 %39
  store float %47, ptr %68, align 4
  %69 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %65, 0
  %70 = getelementptr inbounds i32, ptr %69, i64 %39
  store i32 %28, ptr %70, align 4
  %71 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %66, 0
  %72 = getelementptr inbounds i32, ptr %71, i64 %39
  store i32 %37, ptr %72, align 4
  br label %73

73:                                               ; preds = %63, %43
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
