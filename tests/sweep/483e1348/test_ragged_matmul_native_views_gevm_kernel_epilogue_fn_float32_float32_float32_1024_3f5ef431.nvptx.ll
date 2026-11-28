; ModuleID = 'test_ragged_matmul_native_views.mojo'
source_filename = "test_ragged_matmul_native_views.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_epilogue_fn_float32_float32_float32_1024_3f5ef431.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_epilogue_fn_float32_float32_float32_1024_3f5ef431(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
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
  %30 = trunc i64 %29 to i32
  %31 = sext i32 %30 to i64
  %32 = sdiv i64 %8, -32
  %33 = mul i64 %32, -32
  %34 = icmp eq i64 %33, %8
  %35 = xor i64 %8, -32
  %36 = ashr i64 %35, 63
  %37 = select i1 %34, i64 0, i64 %36
  %38 = add i64 %32, %37
  %39 = sub i64 0, %38
  %40 = call i64 @llvm.smax.i64(i64 %39, i64 0)
  br label %41

41:                                               ; preds = %45, %7
  %42 = phi i64 [ 0, %7 ], [ %48, %45 ]
  %43 = phi float [ 0.000000e+00, %7 ], [ %58, %45 ]
  %44 = icmp slt i64 %42, %40
  br i1 %44, label %45, label %59

45:                                               ; preds = %41
  %46 = icmp eq i64 %42, %40
  %47 = add i64 %42, 1
  %48 = select i1 %46, i64 %42, i64 %47
  %49 = mul i64 %42, 32
  %50 = add i64 %49, %12
  %51 = getelementptr inbounds float, ptr %1, i64 %50
  %52 = load float, ptr %51, align 4
  %53 = mul i64 %50, %9
  %54 = add i64 %53, %18
  %55 = getelementptr inbounds float, ptr %2, i64 %54
  %56 = load float, ptr %55, align 4
  %57 = fmul contract float %52, %56
  %58 = fadd contract float %43, %57
  br label %41

59:                                               ; preds = %41
  %60 = mul i64 %14, 32
  %61 = add i64 %60, %12
  %62 = trunc i64 %61 to i32
  %63 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_epilogue_fn_float32_float32_float32_1024_3f5ef431.x_shared_storage_0._gpu_shared_mem, i32 %62
  store float %43, ptr addrspace(3) %63, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %64 = trunc i64 %11 to i32
  %65 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_epilogue_fn_float32_float32_float32_1024_3f5ef431.x_shared_storage_0._gpu_shared_mem, i32 %64
  %66 = load float, ptr addrspace(3) %65, align 4
  %67 = bitcast float %66 to i32
  %68 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %67, i32 16, i32 31)
  %69 = bitcast i32 %68 to float
  %70 = fadd contract float %66, %69
  %71 = bitcast float %70 to i32
  %72 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %71, i32 8, i32 31)
  %73 = bitcast i32 %72 to float
  %74 = fadd contract float %70, %73
  %75 = bitcast float %74 to i32
  %76 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %75, i32 4, i32 31)
  %77 = bitcast i32 %76 to float
  %78 = fadd contract float %74, %77
  %79 = bitcast float %78 to i32
  %80 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %79, i32 2, i32 31)
  %81 = bitcast i32 %80 to float
  %82 = fadd contract float %78, %81
  %83 = bitcast float %82 to i32
  %84 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %83, i32 1, i32 31)
  %85 = bitcast i32 %84 to float
  %86 = fadd contract float %82, %85
  %87 = sdiv i64 %14, 32
  %88 = mul i64 %87, 32
  %89 = sub i64 %14, %88
  %90 = icmp slt i64 %14, 0
  %91 = icmp ne i64 %89, 0
  %92 = and i1 %90, %91
  %93 = select i1 %92, i64 32, i64 0
  %94 = add i64 %89, %93
  %95 = icmp eq i64 %94, 0
  br i1 %95, label %96, label %100

96:                                               ; preds = %59
  %97 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %98 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %97, 0
  %99 = getelementptr inbounds float, ptr %98, i64 %31
  store float %86, ptr %99, align 4
  br label %101

100:                                              ; preds = %59
  br label %101

101:                                              ; preds = %100, %96
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
