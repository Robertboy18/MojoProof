; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_matmul_naive_LI6A6AcB_35c5d079f21063a3(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
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
  %19 = mul i32 %18, 4
  %20 = mul i32 %18, 8
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %22 = zext i32 %21 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %24 = zext i32 %23 to i64
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %26 = sext i32 %25 to i64
  %27 = mul i64 %24, %26
  %28 = add i64 %27, %22
  %29 = trunc i64 %28 to i32
  %30 = add i32 %20, %29
  %31 = sext i32 %30 to i64
  %32 = getelementptr inbounds double, ptr %7, i64 %31
  %33 = icmp sge i64 %17, 8
  %34 = icmp sge i64 %28, 8
  %35 = select i1 %33, i1 true, i1 %34
  br i1 %35, label %36, label %37

36:                                               ; preds = %3
  br label %63

37:                                               ; preds = %3
  %38 = load double, ptr %32, align 8
  br label %39

39:                                               ; preds = %45, %37
  %40 = phi i64 [ 0, %37 ], [ %48, %45 ]
  %41 = phi double [ %38, %37 ], [ %60, %45 ]
  %42 = icmp slt i64 %40, 4
  br i1 %42, label %43, label %44

43:                                               ; preds = %39
  br label %45

44:                                               ; preds = %39
  br label %61

45:                                               ; preds = %43
  %46 = icmp eq i64 %40, 4
  %47 = add i64 %40, 1
  %48 = select i1 %46, i64 %40, i64 %47
  %49 = trunc i64 %40 to i32
  %50 = add i32 %19, %49
  %51 = sext i32 %50 to i64
  %52 = getelementptr inbounds double, ptr %8, i64 %51
  %53 = load double, ptr %52, align 8
  %54 = mul i32 %49, 8
  %55 = add i32 %54, %29
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds double, ptr %9, i64 %56
  %58 = load double, ptr %57, align 8
  %59 = fmul contract double %53, %58
  %60 = fadd contract double %41, %59
  br label %39

61:                                               ; preds = %44
  %62 = phi double [ %41, %44 ]
  store double %62, ptr %32, align 8
  br label %63

63:                                               ; preds = %61, %36
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
