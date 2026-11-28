; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_bfloat16_bfloat16_bfloat16_1024_8b7e318a.x_shared_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [1024 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_bfloat16_bfloat16_bfloat16_1024_8b7e318a(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %29 = getelementptr inbounds bfloat, ptr %0, i64 %28
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
  %41 = phi float [ 0.000000e+00, %6 ], [ %58, %43 ]
  %42 = icmp slt i64 %40, %38
  br i1 %42, label %43, label %59

43:                                               ; preds = %39
  %44 = icmp eq i64 %40, %38
  %45 = add i64 %40, 1
  %46 = select i1 %44, i64 %40, i64 %45
  %47 = mul i64 %40, 32
  %48 = add i64 %47, %11
  %49 = getelementptr inbounds bfloat, ptr %1, i64 %48
  %50 = load bfloat, ptr %49, align 2
  %51 = mul i64 %48, %8
  %52 = add i64 %51, %17
  %53 = getelementptr inbounds bfloat, ptr %2, i64 %52
  %54 = load bfloat, ptr %53, align 2
  %55 = fpext bfloat %50 to float
  %56 = fpext bfloat %54 to float
  %57 = fmul contract float %55, %56
  %58 = fadd contract float %41, %57
  br label %39

59:                                               ; preds = %39
  %60 = mul i64 %13, 32
  %61 = add i64 %60, %11
  %62 = trunc i64 %61 to i32
  %63 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_bfloat16_bfloat16_bfloat16_1024_8b7e318a.x_shared_storage_0._gpu_shared_mem, i32 %62
  store float %41, ptr addrspace(3) %63, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %64 = trunc i64 %10 to i32
  %65 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_bfloat16_bfloat16_bfloat16_1024_8b7e318a.x_shared_storage_0._gpu_shared_mem, i32 %64
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
  %87 = fptrunc float %86 to bfloat
  %88 = sdiv i64 %13, 32
  %89 = mul i64 %88, 32
  %90 = sub i64 %13, %89
  %91 = icmp slt i64 %13, 0
  %92 = icmp ne i64 %90, 0
  %93 = and i1 %91, %92
  %94 = select i1 %93, i64 32, i64 0
  %95 = add i64 %90, %94
  %96 = icmp eq i64 %95, 0
  br i1 %96, label %97, label %98

97:                                               ; preds = %59
  store bfloat %87, ptr %29, align 2
  br label %99

98:                                               ; preds = %59
  br label %99

99:                                               ; preds = %98, %97
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
