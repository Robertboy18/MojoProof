; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_epilogue_fn_float32_float32_float32_1024_113cff41.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_epilogue_fn_float32_float32_float32_1024_113cff41(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }) %6) #0 {
  %8 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 2
  %9 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 1
  %10 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 0
  %11 = sext i32 %5 to i64
  %12 = sext i32 %4 to i64
  %13 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %14 = zext i32 %13 to i64
  %15 = udiv i64 %14, 32
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %17 = sext i32 %16 to i64
  %18 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %19 = zext i32 %18 to i64
  %20 = mul i64 %19, 32
  %21 = add i64 %20, %17
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %23 = sext i32 %22 to i64
  %24 = mul i64 %19, %23
  %25 = add i64 %24, %14
  %26 = sdiv i64 %25, 32
  %27 = mul i64 %26, 32
  %28 = icmp eq i64 %27, %25
  %29 = xor i64 %25, 32
  %30 = ashr i64 %29, 63
  %31 = select i1 %28, i64 0, i64 %30
  %32 = add i64 %26, %31
  %33 = trunc i64 %32 to i32
  %34 = sdiv i64 %11, -32
  %35 = mul i64 %34, -32
  %36 = icmp eq i64 %35, %11
  %37 = xor i64 %11, -32
  %38 = ashr i64 %37, 63
  %39 = select i1 %36, i64 0, i64 %38
  %40 = add i64 %34, %39
  %41 = sub i64 0, %40
  %42 = call i64 @llvm.smax.i64(i64 %41, i64 0)
  br label %43

43:                                               ; preds = %47, %7
  %44 = phi i64 [ 0, %7 ], [ %50, %47 ]
  %45 = phi float [ 0.000000e+00, %7 ], [ %60, %47 ]
  %46 = icmp slt i64 %44, %42
  br i1 %46, label %47, label %61

47:                                               ; preds = %43
  %48 = icmp eq i64 %44, %42
  %49 = add i64 %44, 1
  %50 = select i1 %48, i64 %44, i64 %49
  %51 = mul i64 %44, 32
  %52 = add i64 %51, %15
  %53 = getelementptr inbounds float, ptr %1, i64 %52
  %54 = load float, ptr %53, align 4
  %55 = mul i64 %52, %12
  %56 = add i64 %55, %21
  %57 = getelementptr inbounds float, ptr %2, i64 %56
  %58 = load float, ptr %57, align 4
  %59 = fmul contract float %54, %58
  %60 = fadd contract float %45, %59
  br label %43

61:                                               ; preds = %43
  %62 = mul i64 %17, 32
  %63 = add i64 %62, %15
  %64 = trunc i64 %63 to i32
  %65 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_epilogue_fn_float32_float32_float32_1024_113cff41.x_shared_storage_0._gpu_shared_mem, i32 %64
  store float %45, ptr addrspace(3) %65, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %66 = trunc i64 %14 to i32
  %67 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_epilogue_fn_float32_float32_float32_1024_113cff41.x_shared_storage_0._gpu_shared_mem, i32 %66
  %68 = load float, ptr addrspace(3) %67, align 4
  %69 = bitcast float %68 to i32
  %70 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %69, i32 16, i32 31)
  %71 = bitcast i32 %70 to float
  %72 = fadd contract float %68, %71
  %73 = bitcast float %72 to i32
  %74 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %73, i32 8, i32 31)
  %75 = bitcast i32 %74 to float
  %76 = fadd contract float %72, %75
  %77 = bitcast float %76 to i32
  %78 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %77, i32 4, i32 31)
  %79 = bitcast i32 %78 to float
  %80 = fadd contract float %76, %79
  %81 = bitcast float %80 to i32
  %82 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %81, i32 2, i32 31)
  %83 = bitcast i32 %82 to float
  %84 = fadd contract float %80, %83
  %85 = bitcast float %84 to i32
  %86 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %85, i32 1, i32 31)
  %87 = bitcast i32 %86 to float
  %88 = fadd contract float %84, %87
  %89 = sdiv i64 %17, 32
  %90 = mul i64 %89, 32
  %91 = sub i64 %17, %90
  %92 = icmp slt i64 %17, 0
  %93 = icmp ne i64 %91, 0
  %94 = and i1 %92, %93
  %95 = select i1 %94, i64 32, i64 0
  %96 = add i64 %91, %95
  %97 = icmp eq i64 %96, 0
  br i1 %97, label %98, label %108

98:                                               ; preds = %61
  %99 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %10, align 8
  %100 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %9, align 8
  %101 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %8, align 8
  %102 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %99, 0
  %103 = getelementptr inbounds float, ptr %102, i64 %32
  store float %88, ptr %103, align 4
  %104 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %100, 0
  %105 = getelementptr inbounds i32, ptr %104, i64 %32
  store i32 0, ptr %105, align 4
  %106 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %101, 0
  %107 = getelementptr inbounds i32, ptr %106, i64 %32
  store i32 %33, ptr %107, align 4
  br label %109

108:                                              ; preds = %61
  br label %109

109:                                              ; preds = %108, %98
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
