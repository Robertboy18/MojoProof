; ModuleID = 'reduction.mojo'
source_filename = "reduction.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [512 x i32] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d(ptr noundef %0, ptr noundef %1) #0 {
  %3 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %4 = zext i32 %3 to i64
  %5 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %6 = sext i32 %5 to i64
  %7 = mul i64 %4, %6
  %8 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %9 = zext i32 %8 to i64
  %10 = icmp eq i64 %9, 0
  %11 = add i64 %9, 32
  %12 = trunc i64 %11 to i32
  %13 = getelementptr inbounds i32, ptr addrspace(3) @reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d._global_alloc_0._gpu_shared_mem, i32 %12
  %14 = add i64 %9, 64
  %15 = trunc i64 %14 to i32
  %16 = getelementptr inbounds i32, ptr addrspace(3) @reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d._global_alloc_0._gpu_shared_mem, i32 %15
  %17 = add i64 %9, 128
  %18 = trunc i64 %17 to i32
  %19 = getelementptr inbounds i32, ptr addrspace(3) @reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d._global_alloc_0._gpu_shared_mem, i32 %18
  %20 = add i64 %9, 256
  %21 = trunc i64 %20 to i32
  %22 = getelementptr inbounds i32, ptr addrspace(3) @reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d._global_alloc_0._gpu_shared_mem, i32 %21
  %23 = add i64 %7, %9
  br label %24

24:                                               ; preds = %56, %2
  %25 = phi i32 [ 0, %2 ], [ %57, %56 ]
  %26 = phi i64 [ %23, %2 ], [ %35, %56 ]
  %27 = phi i64 [ 0, %2 ], [ %36, %56 ]
  %28 = add i64 %26, 512
  %29 = icmp slt i64 %28, %26
  %30 = select i1 %29, i64 1, i64 0
  %31 = icmp sge i64 %26, 4096
  %32 = icmp eq i64 %27, 0
  %33 = xor i1 %32, true
  %34 = or i1 %33, %31
  %35 = select i1 %34, i64 %26, i64 %28
  %36 = select i1 %34, i64 %27, i64 %30
  br i1 %34, label %37, label %38

37:                                               ; preds = %24
  br label %58

38:                                               ; preds = %24
  br label %39

39:                                               ; preds = %38
  %40 = mul i64 %26, 8
  %41 = getelementptr inbounds i32, ptr %1, i64 %40
  %42 = icmp slt i64 %40, 4096
  br i1 %42, label %43, label %55

43:                                               ; preds = %39
  %44 = load <8 x i32>, ptr %41, align 4, !invariant.load !1
  %45 = call <4 x i32> @llvm.vector.extract.v4i32.v8i32(<8 x i32> %44, i64 0)
  %46 = call <4 x i32> @llvm.vector.extract.v4i32.v8i32(<8 x i32> %44, i64 4)
  %47 = add <4 x i32> %45, %46
  %48 = call <2 x i32> @llvm.vector.extract.v2i32.v4i32(<4 x i32> %47, i64 0)
  %49 = call <2 x i32> @llvm.vector.extract.v2i32.v4i32(<4 x i32> %47, i64 2)
  %50 = add <2 x i32> %48, %49
  %51 = extractelement <2 x i32> %50, i64 0
  %52 = extractelement <2 x i32> %50, i64 1
  %53 = add i32 %51, %52
  %54 = add i32 %25, %53
  br label %56

55:                                               ; preds = %39
  br label %56

56:                                               ; preds = %55, %43
  %57 = phi i32 [ %25, %55 ], [ %54, %43 ]
  br label %24

58:                                               ; preds = %37
  %59 = phi i32 [ %25, %37 ]
  %60 = trunc i64 %9 to i32
  %61 = getelementptr inbounds i32, ptr addrspace(3) @reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d._global_alloc_0._gpu_shared_mem, i32 %60
  store i32 %59, ptr addrspace(3) %61, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %62 = icmp slt i64 %9, 256
  br i1 %62, label %63, label %67

63:                                               ; preds = %58
  %64 = load i32, ptr addrspace(3) %61, align 4
  %65 = load i32, ptr addrspace(3) %22, align 4
  %66 = add i32 %64, %65
  store i32 %66, ptr addrspace(3) %61, align 4
  br label %68

67:                                               ; preds = %58
  br label %68

68:                                               ; preds = %67, %63
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %69 = icmp slt i64 %9, 128
  br i1 %69, label %70, label %74

70:                                               ; preds = %68
  %71 = load i32, ptr addrspace(3) %61, align 4
  %72 = load i32, ptr addrspace(3) %19, align 4
  %73 = add i32 %71, %72
  store i32 %73, ptr addrspace(3) %61, align 4
  br label %75

74:                                               ; preds = %68
  br label %75

75:                                               ; preds = %74, %70
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %76 = icmp slt i64 %9, 64
  br i1 %76, label %77, label %81

77:                                               ; preds = %75
  %78 = load i32, ptr addrspace(3) %61, align 4
  %79 = load i32, ptr addrspace(3) %16, align 4
  %80 = add i32 %78, %79
  store i32 %80, ptr addrspace(3) %61, align 4
  br label %82

81:                                               ; preds = %75
  br label %82

82:                                               ; preds = %81, %77
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %83 = icmp slt i64 %9, 32
  br i1 %83, label %84, label %88

84:                                               ; preds = %82
  %85 = load i32, ptr addrspace(3) %61, align 4
  %86 = load i32, ptr addrspace(3) %13, align 4
  %87 = add i32 %85, %86
  store i32 %87, ptr addrspace(3) %61, align 4
  br label %89

88:                                               ; preds = %82
  br label %89

89:                                               ; preds = %88, %84
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br i1 %83, label %90, label %106

90:                                               ; preds = %89
  %91 = load i32, ptr addrspace(3) %61, align 4
  %92 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %91, i32 16, i32 31)
  %93 = add i32 %91, %92
  %94 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %93, i32 8, i32 31)
  %95 = add i32 %93, %94
  %96 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %95, i32 4, i32 31)
  %97 = add i32 %95, %96
  %98 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %97, i32 2, i32 31)
  %99 = add i32 %97, %98
  %100 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %99, i32 1, i32 31)
  %101 = add i32 %99, %100
  br i1 %10, label %102, label %104

102:                                              ; preds = %90
  %103 = atomicrmw add ptr %0, i32 %101 seq_cst, align 4
  br label %105

104:                                              ; preds = %90
  br label %105

105:                                              ; preds = %104, %102
  br label %107

106:                                              ; preds = %89
  br label %107

107:                                              ; preds = %106, %105
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x i32> @llvm.vector.extract.v4i32.v8i32(<8 x i32>, i64 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x i32> @llvm.vector.extract.v2i32.v4i32(<4 x i32>, i64 immarg) #1

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #2

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #3

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind }
attributes #3 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
