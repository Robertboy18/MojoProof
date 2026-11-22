; ModuleID = 'test_multistage_gemm_kernel.mojo'
source_filename = "test_multistage_gemm_kernel.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float8_e4m3fn_bfloat16_bfloat16_True_16_c1599541(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %26 = mul i32 %25, 512
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %32 = sext i32 %31 to i64
  %33 = mul i64 %30, %32
  %34 = add i64 %33, %28
  %35 = trunc i64 %34 to i32
  %36 = mul i32 %35, 512
  %37 = add i32 %26, %35
  %38 = sext i32 %37 to i64
  %39 = getelementptr inbounds i8, ptr %10, i64 %38
  %40 = icmp sge i64 %24, %13
  %41 = icmp sge i64 %34, %14
  %42 = select i1 %40, i1 true, i1 %41
  br i1 %42, label %43, label %44

43:                                               ; preds = %6
  br label %72

44:                                               ; preds = %6
  br label %45

45:                                               ; preds = %51, %44
  %46 = phi i64 [ 0, %44 ], [ %54, %51 ]
  %47 = phi float [ 0.000000e+00, %44 ], [ %67, %51 ]
  %48 = icmp slt i64 %46, %16
  br i1 %48, label %49, label %50

49:                                               ; preds = %45
  br label %51

50:                                               ; preds = %45
  br label %68

51:                                               ; preds = %49
  %52 = icmp eq i64 %46, %16
  %53 = add i64 %46, 1
  %54 = select i1 %52, i64 %46, i64 %53
  %55 = trunc i64 %46 to i32
  %56 = add i32 %26, %55
  %57 = sext i32 %56 to i64
  %58 = getelementptr inbounds bfloat, ptr %11, i64 %57
  %59 = load bfloat, ptr %58, align 2, !invariant.load !1
  %60 = fpext bfloat %59 to float
  %61 = add i32 %36, %55
  %62 = sext i32 %61 to i64
  %63 = getelementptr inbounds bfloat, ptr %12, i64 %62
  %64 = load bfloat, ptr %63, align 2, !invariant.load !1
  %65 = fpext bfloat %64 to float
  %66 = fmul contract float %60, %65
  %67 = fadd contract float %47, %66
  br label %45

68:                                               ; preds = %50
  %69 = phi float [ %47, %50 ]
  %70 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %69)
  %71 = trunc i16 %70 to i8
  store i8 %71, ptr %39, align 1
  br label %72

72:                                               ; preds = %68, %43
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
