; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_compute_fn_bfloat16_bfloat16_bfloat16_1024_10cd3542.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_compute_fn_bfloat16_bfloat16_bfloat16_1024_10cd3542(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, { i64, i64, i64, {} } noundef %6) #0 {
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
  %30 = getelementptr inbounds bfloat, ptr %0, i64 %29
  %31 = sdiv i64 %8, -32
  %32 = mul i64 %31, -32
  %33 = icmp eq i64 %32, %8
  %34 = xor i64 %8, -32
  %35 = ashr i64 %34, 63
  %36 = select i1 %33, i64 0, i64 %35
  %37 = add i64 %31, %36
  %38 = sub i64 0, %37
  %39 = call i64 @llvm.smax.i64(i64 %38, i64 0)
  br label %40

40:                                               ; preds = %44, %7
  %41 = phi i64 [ 0, %7 ], [ %47, %44 ]
  %42 = phi float [ 0.000000e+00, %7 ], [ %59, %44 ]
  %43 = icmp slt i64 %41, %39
  br i1 %43, label %44, label %60

44:                                               ; preds = %40
  %45 = icmp eq i64 %41, %39
  %46 = add i64 %41, 1
  %47 = select i1 %45, i64 %41, i64 %46
  %48 = mul i64 %41, 32
  %49 = add i64 %48, %12
  %50 = getelementptr inbounds bfloat, ptr %1, i64 %49
  %51 = load bfloat, ptr %50, align 2
  %52 = mul i64 %49, %9
  %53 = add i64 %52, %18
  %54 = getelementptr inbounds bfloat, ptr %2, i64 %53
  %55 = load bfloat, ptr %54, align 2
  %56 = fpext bfloat %51 to float
  %57 = fpext bfloat %55 to float
  %58 = fmul contract float %56, %57
  %59 = fadd contract float %42, %58
  br label %40

60:                                               ; preds = %40
  %61 = mul i64 %14, 32
  %62 = add i64 %61, %12
  %63 = trunc i64 %62 to i32
  %64 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_compute_fn_bfloat16_bfloat16_bfloat16_1024_10cd3542.x_shared_storage_0._gpu_shared_mem, i32 %63
  store float %42, ptr addrspace(3) %64, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %65 = trunc i64 %11 to i32
  %66 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_compute_fn_bfloat16_bfloat16_bfloat16_1024_10cd3542.x_shared_storage_0._gpu_shared_mem, i32 %65
  %67 = load float, ptr addrspace(3) %66, align 4
  %68 = bitcast float %67 to i32
  %69 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %68, i32 16, i32 31)
  %70 = bitcast i32 %69 to float
  %71 = fadd contract float %67, %70
  %72 = bitcast float %71 to i32
  %73 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %72, i32 8, i32 31)
  %74 = bitcast i32 %73 to float
  %75 = fadd contract float %71, %74
  %76 = bitcast float %75 to i32
  %77 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %76, i32 4, i32 31)
  %78 = bitcast i32 %77 to float
  %79 = fadd contract float %75, %78
  %80 = bitcast float %79 to i32
  %81 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %80, i32 2, i32 31)
  %82 = bitcast i32 %81 to float
  %83 = fadd contract float %79, %82
  %84 = bitcast float %83 to i32
  %85 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %84, i32 1, i32 31)
  %86 = bitcast i32 %85 to float
  %87 = fadd contract float %83, %86
  %88 = fptrunc float %87 to bfloat
  %89 = fpext bfloat %88 to float
  %90 = fmul contract float %89, 2.000000e+00
  %91 = fptrunc float %90 to bfloat
  %92 = sdiv i64 %14, 32
  %93 = mul i64 %92, 32
  %94 = sub i64 %14, %93
  %95 = icmp slt i64 %14, 0
  %96 = icmp ne i64 %94, 0
  %97 = and i1 %95, %96
  %98 = select i1 %97, i64 32, i64 0
  %99 = add i64 %94, %98
  %100 = icmp eq i64 %99, 0
  br i1 %100, label %101, label %102

101:                                              ; preds = %60
  store bfloat %91, ptr %30, align 2
  br label %103

102:                                              ; preds = %60
  br label %103

103:                                              ; preds = %102, %101
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
