; ModuleID = 'test_ldmatrix_fp8.mojo'
source_filename = "test_ldmatrix_fp8.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_float32_float8_e4m3fn_float8_e4m3fn_True_16_1c75fa41(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %38 = mul i64 %37, %15
  %39 = add i64 %29, %37
  %40 = getelementptr inbounds float, ptr %10, i64 %39
  %41 = icmp sge i64 %27, %16
  %42 = icmp sge i64 %37, %17
  %43 = select i1 %41, i1 true, i1 %42
  br i1 %43, label %44, label %45

44:                                               ; preds = %6
  br label %85

45:                                               ; preds = %6
  br label %46

46:                                               ; preds = %81, %45
  %47 = phi i64 [ 0, %45 ], [ %53, %81 ]
  %48 = phi float [ 0.000000e+00, %45 ], [ %84, %81 ]
  %49 = icmp slt i64 %47, %19
  br i1 %49, label %50, label %56

50:                                               ; preds = %46
  %51 = icmp eq i64 %47, %19
  %52 = add i64 %47, 1
  %53 = select i1 %51, i64 %47, i64 %52
  %54 = add i64 %28, %47
  %55 = getelementptr inbounds i8, ptr %12, i64 %54
  br label %57

56:                                               ; preds = %46
  store float %48, ptr %40, align 4
  br label %85

57:                                               ; preds = %61, %50
  %58 = phi i64 [ 0, %50 ], [ %64, %61 ]
  %59 = phi i8 [ 0, %50 ], [ %66, %61 ]
  %60 = icmp slt i64 %58, 1
  br i1 %60, label %61, label %67

61:                                               ; preds = %57
  %62 = icmp eq i64 %58, 1
  %63 = add i64 %58, 1
  %64 = select i1 %62, i64 %58, i64 %63
  %65 = getelementptr inbounds i8, ptr %55, i64 %58
  %66 = load i8, ptr %65, align 1, !invariant.load !1
  br label %57

67:                                               ; preds = %57
  %68 = call float @__kgen_pop_cast_f8e4m3fn_to_f32_branching(i8 %59)
  %69 = add i64 %38, %47
  %70 = getelementptr inbounds i8, ptr %14, i64 %69
  br label %71

71:                                               ; preds = %75, %67
  %72 = phi i64 [ 0, %67 ], [ %78, %75 ]
  %73 = phi i8 [ 0, %67 ], [ %80, %75 ]
  %74 = icmp slt i64 %72, 1
  br i1 %74, label %75, label %81

75:                                               ; preds = %71
  %76 = icmp eq i64 %72, 1
  %77 = add i64 %72, 1
  %78 = select i1 %76, i64 %72, i64 %77
  %79 = getelementptr inbounds i8, ptr %70, i64 %72
  %80 = load i8, ptr %79, align 1, !invariant.load !1
  br label %71

81:                                               ; preds = %71
  %82 = call float @__kgen_pop_cast_f8e4m3fn_to_f32_branching(i8 %73)
  %83 = fmul contract float %68, %82
  %84 = fadd contract float %48, %83
  br label %46

85:                                               ; preds = %56, %44
  ret void
}

; Function Attrs: alwaysinline
define internal float @__kgen_pop_cast_f8e4m3fn_to_f32_branching(i8 %0) #1 {
  %2 = lshr i8 %0, 3
  %3 = and i8 %2, 15
  %4 = zext i8 %3 to i64
  %5 = sext i8 %0 to i64
  %6 = and i64 %5, 7
  %7 = xor i64 %6, -1
  %8 = icmp slt i64 %6, 0
  %9 = select i1 %8, i64 %7, i64 %6
  %10 = icmp eq i64 %6, 0
  %11 = xor i1 %10, true
  %12 = icmp eq i64 %4, 0
  %13 = select i1 %12, i1 %11, i1 false
  br i1 %13, label %14, label %22

14:                                               ; preds = %1
  %15 = call i64 @llvm.ctlz.i64(i64 %9, i1 false)
  %16 = sub i64 64, %15
  %17 = sub i64 3, %16
  %18 = sub i64 %4, %17
  %19 = add i64 %17, 1
  %20 = shl i64 %6, %19
  %21 = and i64 %20, 7
  br label %23

22:                                               ; preds = %1
  br label %23

23:                                               ; preds = %22, %14
  %24 = phi i64 [ %4, %22 ], [ %18, %14 ]
  %25 = phi i64 [ %6, %22 ], [ %21, %14 ]
  %26 = add i64 %24, 120
  %27 = shl i64 %25, 20
  %28 = shl i64 %26, 23
  %29 = and i64 %28, -2155872256
  %30 = or i64 %29, 0
  %31 = trunc i64 %30 to i32
  %32 = sext i32 %31 to i64
  %33 = and i64 %32, -8388608
  %34 = and i64 %27, 8388607
  %35 = or i64 %33, %34
  %36 = trunc i64 %35 to i32
  %37 = bitcast i32 %36 to float
  %38 = and i8 %0, 127
  %39 = icmp eq i8 %38, 0
  %40 = select i1 %39, float 0.000000e+00, float %37
  %41 = icmp eq i8 %38, 127
  %42 = select i1 %41, float +qnan, float %40
  %43 = and i64 %5, 128
  %44 = icmp eq i64 %43, 0
  %45 = xor i1 %44, true
  %46 = bitcast float %42 to i32
  %47 = sext i32 %46 to i64
  %48 = and i64 %47, -2147483649
  %49 = or i64 %48, 2147483648
  %50 = select i1 %45, i64 %49, i64 %48
  %51 = trunc i64 %50 to i32
  %52 = bitcast i32 %51 to float
  ret float %52
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctlz.i64(i64, i1 immarg) #3

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { alwaysinline }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
