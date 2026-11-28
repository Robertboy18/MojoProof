; ModuleID = 'test_argsort.mojo'
source_filename = "test_argsort.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @bitonic_global_step_True_06300ccc(ptr noundef nonnull readonly byval({ ptr, { { i64 }, { {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64 }, { {} } } }) %1, i32 noundef %2, i32 noundef %3, i32 noundef %4) #0 {
  %6 = load { ptr, { { i64 }, { {} } } }, ptr %1, align 8
  %7 = load { ptr, { { i64 }, { {} } } }, ptr %0, align 8
  %8 = extractvalue { ptr, { { i64 }, { {} } } } %7, 0
  %9 = extractvalue { ptr, { { i64 }, { {} } } } %6, 0
  %10 = sext i32 %2 to i64
  %11 = sext i32 %3 to i64
  %12 = sext i32 %4 to i64
  %13 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %14 = zext i32 %13 to i64
  %15 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %16 = zext i32 %15 to i64
  %17 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %18 = sext i32 %17 to i64
  %19 = mul i64 %16, %18
  %20 = add i64 %19, %14
  %21 = getelementptr inbounds i64, ptr %8, i64 %20
  %22 = and i64 %20, %12
  %23 = icmp eq i64 %22, 0
  %24 = getelementptr inbounds i64, ptr %9, i64 %20
  %25 = xor i64 %20, %11
  %26 = getelementptr inbounds i64, ptr %8, i64 %25
  %27 = getelementptr inbounds i64, ptr %9, i64 %25
  %28 = icmp slt i64 %25, %10
  %29 = icmp sgt i64 %25, %20
  %30 = select i1 %29, i1 %28, i1 false
  %31 = icmp sge i64 %20, %10
  br i1 %31, label %32, label %33

32:                                               ; preds = %5
  br label %49

33:                                               ; preds = %5
  br i1 %30, label %34, label %47

34:                                               ; preds = %33
  %35 = load i64, ptr %24, align 8
  %36 = load i64, ptr %27, align 8
  %37 = icmp sgt i64 %35, %36
  %38 = xor i1 %37, %23
  %39 = xor i1 %38, true
  br i1 %39, label %40, label %45

40:                                               ; preds = %34
  %41 = load i64, ptr %24, align 8
  %42 = load i64, ptr %27, align 8
  store i64 %41, ptr %27, align 8
  store i64 %42, ptr %24, align 8
  %43 = load i64, ptr %21, align 8
  %44 = load i64, ptr %26, align 8
  store i64 %43, ptr %26, align 8
  store i64 %44, ptr %21, align 8
  br label %46

45:                                               ; preds = %34
  br label %46

46:                                               ; preds = %45, %40
  br label %48

47:                                               ; preds = %33
  br label %48

48:                                               ; preds = %47, %46
  br label %49

49:                                               ; preds = %48, %32
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

attributes #0 = { norecurse "nvvm.maxntid"="256" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
