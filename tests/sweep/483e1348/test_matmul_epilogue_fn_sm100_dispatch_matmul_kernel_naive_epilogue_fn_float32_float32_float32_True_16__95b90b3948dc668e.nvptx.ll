; ModuleID = 'test_matmul_epilogue_fn_sm100_dispatch.mojo'
source_filename = "test_matmul_epilogue_fn_sm100_dispatch.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_epilogue_fn_float32_float32_float32_True_16_30dd0544(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %6) #0 {
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
  %24 = mul i64 %23, 6144
  %25 = mul i64 %23, 128
  %26 = icmp slt i64 %23, 0
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %32 = sext i32 %31 to i64
  %33 = mul i64 %30, %32
  %34 = add i64 %33, %28
  %35 = trunc i64 %34 to i32
  %36 = mul i32 %35, 6144
  %37 = add i64 %25, %34
  %38 = icmp sge i64 %23, %12
  %39 = icmp sge i64 %34, %13
  %40 = select i1 %38, i1 true, i1 %39
  br i1 %40, label %41, label %42

41:                                               ; preds = %7
  br label %76

42:                                               ; preds = %7
  br label %43

43:                                               ; preds = %47, %42
  %44 = phi i64 [ 0, %42 ], [ %50, %47 ]
  %45 = phi float [ 0.000000e+00, %42 ], [ %60, %47 ]
  %46 = icmp slt i64 %44, %15
  br i1 %46, label %47, label %61

47:                                               ; preds = %43
  %48 = icmp eq i64 %44, %15
  %49 = add i64 %44, 1
  %50 = select i1 %48, i64 %44, i64 %49
  %51 = add i64 %24, %44
  %52 = getelementptr inbounds float, ptr %10, i64 %51
  %53 = load float, ptr %52, align 4, !invariant.load !1
  %54 = trunc i64 %44 to i32
  %55 = add i32 %36, %54
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds float, ptr %11, i64 %56
  %58 = load float, ptr %57, align 4, !invariant.load !1
  %59 = fmul contract float %53, %58
  %60 = fadd contract float %45, %59
  br label %43

61:                                               ; preds = %43
  %62 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %6, align 8
  %63 = sdiv i64 %23, 2
  %64 = mul i64 %63, 2
  %65 = sub i64 %23, %64
  %66 = icmp ne i64 %65, 0
  %67 = and i1 %26, %66
  %68 = select i1 %67, i64 2, i64 0
  %69 = add i64 %65, %68
  %70 = icmp eq i64 %69, 1
  %71 = select i1 %70, i64 -2, i64 2
  %72 = sitofp i64 %71 to float
  %73 = fmul contract float %45, %72
  %74 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %62, 0
  %75 = getelementptr inbounds float, ptr %74, i64 %37
  store float %73, ptr %75, align 4
  br label %76

76:                                               ; preds = %61, %41
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
