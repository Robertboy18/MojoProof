; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_kernel_naive_bfloat16_bfloat16_bfloat16_False_16_cd8e8294(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %26 = mul i32 %25, 1024
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %32 = sext i32 %31 to i64
  %33 = mul i64 %30, %32
  %34 = add i64 %33, %28
  %35 = trunc i64 %34 to i32
  %36 = add i32 %25, %35
  %37 = sext i32 %36 to i64
  %38 = getelementptr inbounds bfloat, ptr %10, i64 %37
  %39 = icmp sge i64 %24, %13
  %40 = icmp sge i64 %34, %14
  %41 = select i1 %39, i1 true, i1 %40
  br i1 %41, label %42, label %43

42:                                               ; preds = %6
  br label %67

43:                                               ; preds = %6
  br label %44

44:                                               ; preds = %48, %43
  %45 = phi i64 [ 0, %43 ], [ %51, %48 ]
  %46 = phi float [ 0.000000e+00, %43 ], [ %64, %48 ]
  %47 = icmp slt i64 %45, %16
  br i1 %47, label %48, label %65

48:                                               ; preds = %44
  %49 = icmp eq i64 %45, %16
  %50 = add i64 %45, 1
  %51 = select i1 %49, i64 %45, i64 %50
  %52 = trunc i64 %45 to i32
  %53 = add i32 %26, %52
  %54 = sext i32 %53 to i64
  %55 = getelementptr inbounds bfloat, ptr %11, i64 %54
  %56 = load bfloat, ptr %55, align 2, !invariant.load !1
  %57 = fpext bfloat %56 to float
  %58 = add i32 %52, %35
  %59 = sext i32 %58 to i64
  %60 = getelementptr inbounds bfloat, ptr %12, i64 %59
  %61 = load bfloat, ptr %60, align 2, !invariant.load !1
  %62 = fpext bfloat %61 to float
  %63 = fmul contract float %57, %62
  %64 = fadd contract float %46, %63
  br label %44

65:                                               ; preds = %44
  %66 = fptrunc float %46 to bfloat
  store bfloat %66, ptr %38, align 2
  br label %67

67:                                               ; preds = %65, %42
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
