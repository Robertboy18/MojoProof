; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_mma_layout_tc_L6A6AcB_eb86e9289bcca915(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [2 x ptr], i64 1, align 8
  %5 = alloca double, i64 1, align 8
  %6 = alloca double, i64 1, align 8
  %7 = alloca [2 x double], align 8
  %8 = alloca double, i64 1, align 8
  %9 = alloca double, i64 1, align 8
  %10 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %11 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %12 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %13 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %12, 0
  %14 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %11, 0
  %15 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %10, 0
  call void @llvm.lifetime.start.p0(ptr %9)
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %17 = sext i32 %16 to i64
  %18 = sdiv i64 %17, 4
  %19 = mul i64 %18, 4
  %20 = icmp eq i64 %19, %17
  %21 = xor i64 %17, 4
  %22 = ashr i64 %21, 63
  %23 = select i1 %20, i64 0, i64 %22
  %24 = add i64 %18, %23
  %25 = sub i64 %17, %19
  %26 = icmp slt i64 %17, 0
  %27 = icmp ne i64 %25, 0
  %28 = and i1 %26, %27
  %29 = select i1 %28, i64 4, i64 0
  %30 = add i64 %25, %29
  %31 = trunc i64 %24 to i32
  %32 = mul i32 %31, 4
  %33 = trunc i64 %30 to i32
  %34 = add i32 %32, %33
  %35 = sext i32 %34 to i64
  %36 = getelementptr inbounds double, ptr %14, i64 %35
  %37 = load double, ptr %36, align 8
  %38 = addrspacecast ptr %9 to ptr addrspace(5)
  store double %37, ptr addrspace(5) %38, align 8
  call void @llvm.lifetime.start.p0(ptr %8)
  %39 = mul i32 %33, 8
  %40 = add i32 %39, %31
  %41 = sext i32 %40 to i64
  %42 = getelementptr inbounds double, ptr %15, i64 %41
  %43 = load double, ptr %42, align 8
  %44 = addrspacecast ptr %8 to ptr addrspace(5)
  store double %43, ptr addrspace(5) %44, align 8
  call void @llvm.lifetime.start.p0(ptr %7)
  %45 = addrspacecast ptr %7 to ptr addrspace(5)
  %46 = mul i64 %30, 2
  %47 = mul i32 %31, 8
  %48 = trunc i64 %46 to i32
  %49 = add i32 %47, %48
  %50 = sext i32 %49 to i64
  %51 = getelementptr inbounds double, ptr %13, i64 %50
  %52 = load double, ptr %51, align 8
  store double %52, ptr addrspace(5) %45, align 8
  %53 = add i64 %46, 1
  %54 = trunc i64 %53 to i32
  %55 = add i32 %47, %54
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds double, ptr %13, i64 %56
  %58 = load double, ptr %57, align 8
  %59 = getelementptr inbounds double, ptr addrspace(5) %45, i32 1
  store double %58, ptr addrspace(5) %59, align 8
  %60 = load <2 x double>, ptr addrspace(5) %45, align 8
  %61 = load double, ptr addrspace(5) %38, align 8
  %62 = load double, ptr addrspace(5) %44, align 8
  %63 = extractelement <2 x double> %60, i64 0
  %64 = extractelement <2 x double> %60, i64 1
  %65 = call { double, double } @llvm.nvvm.mma.m8n8k4.row.col.f64(double %61, double %62, double %63, double %64)
  %66 = extractvalue { double, double } %65, 0
  %67 = extractvalue { double, double } %65, 1
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store double %66, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store double %67, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %68 = insertvalue [2 x ptr] undef, ptr %6, 0
  %69 = insertvalue [2 x ptr] %68, ptr %5, 1
  call void @llvm.lifetime.start.p0(ptr %4)
  store [2 x ptr] %69, ptr %4, align 8
  %70 = getelementptr inbounds [2 x ptr], ptr %4, i32 0, i32 0
  %71 = load ptr, ptr %70, align 8
  %72 = load double, ptr %71, align 8
  %73 = insertelement <2 x double> undef, double %72, i64 0
  %74 = getelementptr inbounds ptr, ptr %70, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = load double, ptr %75, align 8
  %77 = insertelement <2 x double> %73, double %76, i64 1
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.end.p0(ptr %6)
  %78 = extractelement <2 x double> %77, i64 0
  store double %78, ptr %51, align 8
  %79 = extractelement <2 x double> %77, i64 1
  store double %79, ptr %57, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %7)
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #2

; Function Attrs: nocallback nounwind memory(none)
declare { double, double } @llvm.nvvm.mma.m8n8k4.row.col.f64(double, double, double, double) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nounwind memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
