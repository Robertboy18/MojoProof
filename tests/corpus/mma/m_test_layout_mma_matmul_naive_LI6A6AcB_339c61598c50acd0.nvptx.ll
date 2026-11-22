; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_matmul_naive_LI6A6AcB_339c61598c50acd0(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %5 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %6 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %7 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %6, 0
  %8 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5, 0
  %9 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4, 0
  %10 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %11 = zext i32 %10 to i64
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %13 = zext i32 %12 to i64
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %15 = sext i32 %14 to i64
  %16 = mul i64 %13, %15
  %17 = add i64 %16, %11
  %18 = trunc i64 %17 to i32
  %19 = mul i32 %18, 8
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %21 = zext i32 %20 to i64
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %23 = zext i32 %22 to i64
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %25 = sext i32 %24 to i64
  %26 = mul i64 %23, %25
  %27 = add i64 %26, %21
  %28 = trunc i64 %27 to i32
  %29 = add i32 %19, %28
  %30 = sext i32 %29 to i64
  %31 = getelementptr inbounds float, ptr %7, i64 %30
  %32 = icmp sge i64 %17, 16
  %33 = icmp sge i64 %27, 8
  %34 = select i1 %32, i1 true, i1 %33
  br i1 %34, label %35, label %36

35:                                               ; preds = %3
  br label %64

36:                                               ; preds = %3
  %37 = load float, ptr %31, align 4
  br label %38

38:                                               ; preds = %44, %36
  %39 = phi i64 [ 0, %36 ], [ %47, %44 ]
  %40 = phi float [ %37, %36 ], [ %61, %44 ]
  %41 = icmp slt i64 %39, 8
  br i1 %41, label %42, label %43

42:                                               ; preds = %38
  br label %44

43:                                               ; preds = %38
  br label %62

44:                                               ; preds = %42
  %45 = icmp eq i64 %39, 8
  %46 = add i64 %39, 1
  %47 = select i1 %45, i64 %39, i64 %46
  %48 = trunc i64 %39 to i32
  %49 = add i32 %19, %48
  %50 = sext i32 %49 to i64
  %51 = getelementptr inbounds bfloat, ptr %8, i64 %50
  %52 = load bfloat, ptr %51, align 2
  %53 = fpext bfloat %52 to float
  %54 = mul i32 %48, 8
  %55 = add i32 %54, %28
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds bfloat, ptr %9, i64 %56
  %58 = load bfloat, ptr %57, align 2
  %59 = fpext bfloat %58 to float
  %60 = fmul contract float %53, %59
  %61 = fadd contract float %40, %60
  br label %38

62:                                               ; preds = %43
  %63 = phi float [ %40, %43 ]
  store float %63, ptr %31, align 4
  br label %64

64:                                               ; preds = %62, %35
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
