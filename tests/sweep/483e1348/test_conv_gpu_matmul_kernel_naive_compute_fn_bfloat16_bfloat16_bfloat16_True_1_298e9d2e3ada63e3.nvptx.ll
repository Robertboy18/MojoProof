; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_compute_fn_bfloat16_bfloat16_bfloat16_True_16_4e19f700(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, { i64, i64, i64, {} } noundef %6) #0 {
  %8 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %9 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %10 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %11 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %10, 0
  %12 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %10, 1, 1, 0
  %13 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 0
  %14 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %9, 1, 1, 0
  %15 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %8, 0
  %16 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %8, 1, 1, 0
  %17 = sext i32 %3 to i64
  %18 = sext i32 %4 to i64
  %19 = sext i32 %5 to i64
  %20 = call i64 @llvm.smax.i64(i64 %19, i64 0)
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %22 = zext i32 %21 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %24 = zext i32 %23 to i64
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %26 = sext i32 %25 to i64
  %27 = mul i64 %24, %26
  %28 = add i64 %27, %22
  %29 = mul i64 %28, %14
  %30 = mul i64 %28, %12
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %34 = zext i32 %33 to i64
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %36 = sext i32 %35 to i64
  %37 = mul i64 %34, %36
  %38 = add i64 %37, %32
  %39 = mul i64 %38, %16
  %40 = add i64 %30, %38
  %41 = getelementptr inbounds bfloat, ptr %11, i64 %40
  %42 = icmp sge i64 %28, %17
  %43 = icmp sge i64 %38, %18
  %44 = select i1 %42, i1 true, i1 %43
  br i1 %44, label %45, label %46

45:                                               ; preds = %7
  br label %70

46:                                               ; preds = %7
  br label %47

47:                                               ; preds = %51, %46
  %48 = phi i64 [ 0, %46 ], [ %54, %51 ]
  %49 = phi float [ 0.000000e+00, %46 ], [ %64, %51 ]
  %50 = icmp slt i64 %48, %20
  br i1 %50, label %51, label %65

51:                                               ; preds = %47
  %52 = icmp eq i64 %48, %20
  %53 = add i64 %48, 1
  %54 = select i1 %52, i64 %48, i64 %53
  %55 = add i64 %29, %48
  %56 = getelementptr inbounds bfloat, ptr %13, i64 %55
  %57 = load bfloat, ptr %56, align 2, !invariant.load !1
  %58 = fpext bfloat %57 to float
  %59 = add i64 %39, %48
  %60 = getelementptr inbounds bfloat, ptr %15, i64 %59
  %61 = load bfloat, ptr %60, align 2, !invariant.load !1
  %62 = fpext bfloat %61 to float
  %63 = fmul contract float %58, %62
  %64 = fadd contract float %49, %63
  br label %47

65:                                               ; preds = %47
  %66 = fptrunc float %49 to bfloat
  %67 = fpext bfloat %66 to float
  %68 = fmul contract float %67, 2.000000e+00
  %69 = fptrunc float %68 to bfloat
  store bfloat %69, ptr %41, align 2
  br label %70

70:                                               ; preds = %65, %45
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
