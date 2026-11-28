; ModuleID = 'test_matmul_epilogue_fn_sm100_dispatch.mojo'
source_filename = "test_matmul_epilogue_fn_sm100_dispatch.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_float32_float32_float32_1024_1308aaae.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_float32_float32_float32_1024_1308aaae(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #1 {
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
  %29 = getelementptr inbounds float, ptr %0, i64 %28
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %30 = sdiv i64 %7, -32
  %31 = mul i64 %30, -32
  %32 = icmp eq i64 %31, %7
  %33 = xor i64 %7, -32
  %34 = ashr i64 %33, 63
  %35 = select i1 %32, i64 0, i64 %34
  %36 = add i64 %30, %35
  %37 = sub i64 0, %36
  %38 = call i64 @llvm.smax.i64(i64 %37, i64 0)
  br label %39

39:                                               ; preds = %43, %6
  %40 = phi i64 [ 0, %6 ], [ %46, %43 ]
  %41 = phi float [ 0.000000e+00, %6 ], [ %56, %43 ]
  %42 = icmp slt i64 %40, %38
  br i1 %42, label %43, label %57

43:                                               ; preds = %39
  %44 = icmp eq i64 %40, %38
  %45 = add i64 %40, 1
  %46 = select i1 %44, i64 %40, i64 %45
  %47 = mul i64 %40, 32
  %48 = add i64 %47, %11
  %49 = getelementptr inbounds float, ptr %1, i64 %48
  %50 = load float, ptr %49, align 4
  %51 = mul i64 %48, %8
  %52 = add i64 %51, %17
  %53 = getelementptr inbounds float, ptr %2, i64 %52
  %54 = load float, ptr %53, align 4
  %55 = fmul contract float %50, %54
  %56 = fadd contract float %41, %55
  br label %39

57:                                               ; preds = %39
  %58 = mul i64 %13, 32
  %59 = add i64 %58, %11
  %60 = trunc i64 %59 to i32
  %61 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_float32_float32_float32_1024_1308aaae.x_shared_storage_0._gpu_shared_mem, i32 %60
  store float %41, ptr addrspace(3) %61, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %62 = trunc i64 %10 to i32
  %63 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_float32_float32_float32_1024_1308aaae.x_shared_storage_0._gpu_shared_mem, i32 %62
  %64 = load float, ptr addrspace(3) %63, align 4
  %65 = bitcast float %64 to i32
  %66 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %65, i32 16, i32 31)
  %67 = bitcast i32 %66 to float
  %68 = fadd contract float %64, %67
  %69 = bitcast float %68 to i32
  %70 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %69, i32 8, i32 31)
  %71 = bitcast i32 %70 to float
  %72 = fadd contract float %68, %71
  %73 = bitcast float %72 to i32
  %74 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %73, i32 4, i32 31)
  %75 = bitcast i32 %74 to float
  %76 = fadd contract float %72, %75
  %77 = bitcast float %76 to i32
  %78 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %77, i32 2, i32 31)
  %79 = bitcast i32 %78 to float
  %80 = fadd contract float %76, %79
  %81 = bitcast float %80 to i32
  %82 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %81, i32 1, i32 31)
  %83 = bitcast i32 %82 to float
  %84 = fadd contract float %80, %83
  %85 = sdiv i64 %13, 32
  %86 = mul i64 %85, 32
  %87 = sub i64 %13, %86
  %88 = icmp slt i64 %13, 0
  %89 = icmp ne i64 %87, 0
  %90 = and i1 %88, %89
  %91 = select i1 %90, i64 32, i64 0
  %92 = add i64 %87, %91
  %93 = icmp eq i64 %92, 0
  br i1 %93, label %94, label %95

94:                                               ; preds = %57
  store float %84, ptr %29, align 4
  br label %96

95:                                               ; preds = %57
  br label %96

96:                                               ; preds = %95, %94
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  ret void
}

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.wait() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #5

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #6

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.launch.dependents() #2

attributes #0 = { noinline "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #1 = { convergent norecurse "nvvm.maxntid"="1024" "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #2 = { nounwind }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { convergent nocallback nounwind }
attributes #6 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
