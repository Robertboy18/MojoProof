; ModuleID = 'gevm_f32_t512.mojo'
source_filename = "gevm_f32_t512.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gevm_kernel_float32_float32_float32_512_7a789db0._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [512 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gevm_kernel_float32_float32_float32_512_7a789db0(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %22 = sdiv i64 %21, 16
  %23 = mul i64 %22, 16
  %24 = icmp eq i64 %23, %21
  %25 = xor i64 %21, 16
  %26 = ashr i64 %25, 63
  %27 = select i1 %24, i64 0, i64 %26
  %28 = add i64 %22, %27
  %29 = getelementptr inbounds float, ptr %0, i64 %28
  %30 = sdiv i64 %7, -16
  %31 = mul i64 %30, -16
  %32 = icmp eq i64 %31, %7
  %33 = xor i64 %7, -16
  %34 = ashr i64 %33, 63
  %35 = select i1 %32, i64 0, i64 %34
  %36 = add i64 %30, %35
  %37 = sub i64 0, %36
  %38 = call i64 @llvm.smax.i64(i64 %37, i64 0)
  br label %39

39:                                               ; preds = %45, %6
  %40 = phi i64 [ 0, %6 ], [ %48, %45 ]
  %41 = phi float [ 0.000000e+00, %6 ], [ %58, %45 ]
  %42 = icmp slt i64 %40, %38
  br i1 %42, label %43, label %44

43:                                               ; preds = %39
  br label %45

44:                                               ; preds = %39
  br label %59

45:                                               ; preds = %43
  %46 = icmp eq i64 %40, %38
  %47 = add i64 %40, 1
  %48 = select i1 %46, i64 %40, i64 %47
  %49 = mul i64 %40, 16
  %50 = add i64 %49, %11
  %51 = getelementptr inbounds float, ptr %1, i64 %50
  %52 = load float, ptr %51, align 4
  %53 = mul i64 %50, %8
  %54 = add i64 %53, %17
  %55 = getelementptr inbounds float, ptr %2, i64 %54
  %56 = load float, ptr %55, align 4
  %57 = fmul contract float %52, %56
  %58 = fadd contract float %41, %57
  br label %39

59:                                               ; preds = %44
  %60 = phi float [ %41, %44 ]
  %61 = mul i64 %13, 16
  %62 = add i64 %61, %11
  %63 = trunc i64 %62 to i32
  %64 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_float32_float32_float32_512_7a789db0._global_alloc_0._gpu_shared_mem, i32 %63
  store float %60, ptr addrspace(3) %64, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %65 = trunc i64 %10 to i32
  %66 = getelementptr inbounds float, ptr addrspace(3) @gevm_kernel_float32_float32_float32_512_7a789db0._global_alloc_0._gpu_shared_mem, i32 %65
  %67 = load float, ptr addrspace(3) %66, align 4
  %68 = bitcast float %67 to i32
  %69 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %68, i32 8, i32 31)
  %70 = bitcast i32 %69 to float
  %71 = fadd contract float %67, %70
  %72 = bitcast float %71 to i32
  %73 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %72, i32 4, i32 31)
  %74 = bitcast i32 %73 to float
  %75 = fadd contract float %71, %74
  %76 = bitcast float %75 to i32
  %77 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %76, i32 2, i32 31)
  %78 = bitcast i32 %77 to float
  %79 = fadd contract float %75, %78
  %80 = bitcast float %79 to i32
  %81 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %80, i32 1, i32 31)
  %82 = bitcast i32 %81 to float
  %83 = fadd contract float %79, %82
  %84 = sdiv i64 %13, 16
  %85 = mul i64 %84, 16
  %86 = sub i64 %13, %85
  %87 = icmp slt i64 %13, 0
  %88 = icmp ne i64 %86, 0
  %89 = and i1 %87, %88
  %90 = select i1 %89, i64 16, i64 0
  %91 = add i64 %86, %90
  %92 = icmp eq i64 %91, 0
  br i1 %92, label %93, label %94

93:                                               ; preds = %59
  store float %83, ptr %29, align 4
  br label %95

94:                                               ; preds = %59
  br label %95

95:                                               ; preds = %94, %93
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

attributes #0 = { convergent norecurse "nvvm.maxntid"="512" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { convergent nocallback nounwind }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
