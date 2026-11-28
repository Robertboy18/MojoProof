; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_compute_fn_float32_float32_float32_1024_083454df.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_compute_fn_float32_float32_float32_1024_083454df(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = sext i32 %5 to i64
  %8 = sext i32 %4 to i64
  %9 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %10 = zext i32 %9 to i64
  %11 = udiv i64 %10, 32
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %13 = sext i32 %12 to i64
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %15 = zext i32 %14 to i64
  %16 = mul i64 %15, 32
  %17 = add i64 %16, %13
  %18 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %19 = sext i32 %18 to i64
  %20 = mul i64 %15, %19
  %21 = add i64 %20, %10
  %22 = sdiv i64 %21, 32
  %23 = mul i64 %22, 32
  %24 = icmp eq i64 %23, %21
  %25 = xor i64 %21, 32
  %26 = ashr i64 %25, 63
  %27 = select i1 %24, i64 0, i64 %26
  %28 = add i64 %22, %27
  %29 = sitofp i64 %28 to float
  %30 = getelementptr inbounds float, ptr %0, i64 %28
  %31 = sdiv i64 %7, -32
  %32 = mul i64 %31, -32
  %33 = icmp eq i64 %32, %7
  %34 = xor i64 %7, -32
  %35 = ashr i64 %34, 63
  %36 = select i1 %33, i64 0, i64 %35
  %37 = add i64 %31, %36
  %38 = sub i64 0, %37
  %39 = call i64 @llvm.smax.i64(i64 %38, i64 0)
  br label %40

40:                                               ; preds = %44, %6
  %41 = phi i64 [ 0, %6 ], [ %47, %44 ]
  %42 = phi float [ 0.000000e+00, %6 ], [ %57, %44 ]
  %43 = icmp slt i64 %41, %39
  br i1 %43, label %44, label %58

44:                                               ; preds = %40
  %45 = icmp eq i64 %41, %39
  %46 = add i64 %41, 1
  %47 = select i1 %45, i64 %41, i64 %46
  %48 = mul i64 %41, 32
  %49 = add i64 %48, %11
  %50 = getelementptr inbounds float, ptr %1, i64 %49
  %51 = load float, ptr %50, align 4
  %52 = mul i64 %49, %8
  %53 = add i64 %52, %17
  %54 = getelementptr inbounds float, ptr %2, i64 %53
  %55 = load float, ptr %54, align 4
  %56 = fmul contract float %51, %55
  %57 = fadd contract float %42, %56
  br label %40

58:                                               ; preds = %40
  %59 = mul i64 %13, 32
  %60 = add i64 %59, %11
  %61 = trunc i64 %60 to i32
  %62 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_compute_fn_float32_float32_float32_1024_083454df.x_shared_storage_0._gpu_shared_mem, i32 %61
  store float %42, ptr addrspace(3) %62, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %63 = trunc i64 %10 to i32
  %64 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_compute_fn_float32_float32_float32_1024_083454df.x_shared_storage_0._gpu_shared_mem, i32 %63
  %65 = load float, ptr addrspace(3) %64, align 4
  %66 = bitcast float %65 to i32
  %67 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %66, i32 16, i32 31)
  %68 = bitcast i32 %67 to float
  %69 = fadd contract float %65, %68
  %70 = bitcast float %69 to i32
  %71 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %70, i32 8, i32 31)
  %72 = bitcast i32 %71 to float
  %73 = fadd contract float %69, %72
  %74 = bitcast float %73 to i32
  %75 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %74, i32 4, i32 31)
  %76 = bitcast i32 %75 to float
  %77 = fadd contract float %73, %76
  %78 = bitcast float %77 to i32
  %79 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %78, i32 2, i32 31)
  %80 = bitcast i32 %79 to float
  %81 = fadd contract float %77, %80
  %82 = bitcast float %81 to i32
  %83 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %82, i32 1, i32 31)
  %84 = bitcast i32 %83 to float
  %85 = fadd contract float %81, %84
  %86 = fadd contract float %85, %29
  %87 = sdiv i64 %13, 32
  %88 = mul i64 %87, 32
  %89 = sub i64 %13, %88
  %90 = icmp slt i64 %13, 0
  %91 = icmp ne i64 %89, 0
  %92 = and i1 %90, %91
  %93 = select i1 %92, i64 32, i64 0
  %94 = add i64 %89, %93
  %95 = icmp eq i64 %94, 0
  br i1 %95, label %96, label %97

96:                                               ; preds = %58
  store float %86, ptr %30, align 4
  br label %98

97:                                               ; preds = %58
  br label %98

98:                                               ; preds = %97, %96
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #2

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #3

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #4

attributes #0 = { convergent norecurse "nvvm.maxntid"="1024" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { convergent nocallback nounwind }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
