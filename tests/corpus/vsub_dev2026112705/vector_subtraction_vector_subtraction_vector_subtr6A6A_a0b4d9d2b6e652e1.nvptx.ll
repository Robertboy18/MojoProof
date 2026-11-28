; ModuleID = 'vector_subtraction.mojo'
source_filename = "vector_subtraction.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1(ptr noundef nonnull readonly byval({ ptr, { { {} }, { {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {} }, { {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {} }, { {} } } }) %2, i32 noundef %3) #0 {
  %5 = load { ptr, { { {} }, { {} } } }, ptr %2, align 8
  %6 = extractvalue { ptr, { { {} }, { {} } } } %5, 0
  %7 = load { ptr, { { {} }, { {} } } }, ptr %1, align 8
  %8 = extractvalue { ptr, { { {} }, { {} } } } %7, 0
  %9 = load { ptr, { { {} }, { {} } } }, ptr %0, align 8
  %10 = extractvalue { ptr, { { {} }, { {} } } } %9, 0
  %11 = sext i32 %3 to i64
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %13 = zext i32 %12 to i64
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %15 = zext i32 %14 to i64
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %17 = sext i32 %16 to i64
  %18 = mul i64 %15, %17
  %19 = add i64 %18, %13
  %20 = icmp slt i64 %19, %11
  br i1 %20, label %21, label %30

21:                                               ; preds = %4
  %22 = trunc i64 %19 to i32
  %23 = sext i32 %22 to i64
  %24 = getelementptr inbounds float, ptr %10, i64 %23
  %25 = load float, ptr %24, align 4, !invariant.load !1
  %26 = getelementptr inbounds float, ptr %8, i64 %23
  %27 = load float, ptr %26, align 4, !invariant.load !1
  %28 = fsub contract float %25, %27
  %29 = getelementptr inbounds float, ptr %6, i64 %23
  store float %28, ptr %29, align 4
  br label %31

30:                                               ; preds = %4
  br label %31

31:                                               ; preds = %30, %21
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
