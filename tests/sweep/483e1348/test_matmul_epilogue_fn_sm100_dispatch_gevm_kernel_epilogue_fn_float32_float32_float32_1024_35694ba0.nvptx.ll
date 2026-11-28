; ModuleID = 'test_matmul_epilogue_fn_sm100_dispatch.mojo'
source_filename = "test_matmul_epilogue_fn_sm100_dispatch.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_epilogue_fn_float32_float32_float32_1024_35694ba0.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_epilogue_fn_float32_float32_float32_1024_35694ba0(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %6) #1 {
  %8 = sext i32 %5 to i64
  %9 = sext i32 %4 to i64
  %10 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %11 = zext i32 %10 to i64
  %12 = udiv i64 %11, 32
  %13 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %14 = sext i32 %13 to i64
  %15 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %16 = zext i32 %15 to i64
  %17 = mul i64 %16, 32
  %18 = add i64 %17, %14
  %19 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %20 = sext i32 %19 to i64
  %21 = mul i64 %16, %20
  %22 = add i64 %21, %11
  %23 = sdiv i64 %22, 32
  %24 = mul i64 %23, 32
  %25 = icmp eq i64 %24, %22
  %26 = xor i64 %22, 32
  %27 = ashr i64 %26, 63
  %28 = select i1 %25, i64 0, i64 %27
  %29 = add i64 %23, %28
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %30 = sdiv i64 %8, -32
  %31 = mul i64 %30, -32
  %32 = icmp eq i64 %31, %8
  %33 = xor i64 %8, -32
  %34 = ashr i64 %33, 63
  %35 = select i1 %32, i64 0, i64 %34
  %36 = add i64 %30, %35
  %37 = sub i64 0, %36
  %38 = call i64 @llvm.smax.i64(i64 %37, i64 0)
  br label %39

39:                                               ; preds = %43, %7
  %40 = phi i64 [ 0, %7 ], [ %46, %43 ]
  %41 = phi float [ 0.000000e+00, %7 ], [ %56, %43 ]
  %42 = icmp slt i64 %40, %38
  br i1 %42, label %43, label %57

43:                                               ; preds = %39
  %44 = icmp eq i64 %40, %38
  %45 = add i64 %40, 1
  %46 = select i1 %44, i64 %40, i64 %45
  %47 = mul i64 %40, 32
  %48 = add i64 %47, %12
  %49 = getelementptr inbounds float, ptr %1, i64 %48
  %50 = load float, ptr %49, align 4
  %51 = mul i64 %48, %9
  %52 = add i64 %51, %18
  %53 = getelementptr inbounds float, ptr %2, i64 %52
  %54 = load float, ptr %53, align 4
  %55 = fmul contract float %50, %54
  %56 = fadd contract float %41, %55
  br label %39

57:                                               ; preds = %39
  %58 = mul i64 %14, 32
  %59 = add i64 %58, %12
  %60 = trunc i64 %59 to i32
  %61 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_epilogue_fn_float32_float32_float32_1024_35694ba0.x_shared_storage_0._gpu_shared_mem, i32 %60
  store float %41, ptr addrspace(3) %61, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %62 = trunc i64 %11 to i32
  %63 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_epilogue_fn_float32_float32_float32_1024_35694ba0.x_shared_storage_0._gpu_shared_mem, i32 %62
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
  %85 = fmul contract float %84, 2.000000e+00
  %86 = sdiv i64 %14, 32
  %87 = mul i64 %86, 32
  %88 = sub i64 %14, %87
  %89 = icmp slt i64 %14, 0
  %90 = icmp ne i64 %88, 0
  %91 = and i1 %89, %90
  %92 = select i1 %91, i64 32, i64 0
  %93 = add i64 %88, %92
  %94 = icmp eq i64 %93, 0
  br i1 %94, label %95, label %99

95:                                               ; preds = %57
  %96 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %6, align 8
  %97 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %96, 0
  %98 = getelementptr inbounds float, ptr %97, i64 %29
  store float %85, ptr %98, align 4
  br label %100

99:                                               ; preds = %57
  br label %100

100:                                              ; preds = %99, %95
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
