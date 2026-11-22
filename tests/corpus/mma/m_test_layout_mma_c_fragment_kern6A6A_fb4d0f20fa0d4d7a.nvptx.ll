; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_c_fragment_kern6A6A_fb4d0f20fa0d4d7a(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { i64, i64 } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { i64, i64 } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [2 x double], align 8
  %5 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %6 = load { ptr, { { {}, {} }, { i64, i64 } } }, ptr %1, align 8
  %7 = load { ptr, { { {}, {} }, { i64, i64 } } }, ptr %0, align 8
  %8 = extractvalue { ptr, { { {}, {} }, { i64, i64 } } } %7, 0
  %9 = extractvalue { ptr, { { {}, {} }, { i64, i64 } } } %7, 1, 1, 0
  %10 = extractvalue { ptr, { { {}, {} }, { i64, i64 } } } %7, 1, 1, 1
  %11 = extractvalue { ptr, { { {}, {} }, { i64, i64 } } } %6, 0
  %12 = extractvalue { ptr, { { {}, {} }, { i64, i64 } } } %6, 1, 1, 0
  %13 = extractvalue { ptr, { { {}, {} }, { i64, i64 } } } %6, 1, 1, 1
  %14 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5, 0
  call void @llvm.lifetime.start.p0(ptr %4)
  %15 = addrspacecast ptr %4 to ptr addrspace(5)
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
  %31 = mul i64 %30, 2
  %32 = mul i64 %24, %9
  %33 = mul i64 %31, %10
  %34 = add i64 %32, %33
  %35 = getelementptr inbounds double, ptr %8, i64 %34
  %36 = load double, ptr %35, align 8, !invariant.load !1
  store double %36, ptr addrspace(5) %15, align 8
  %37 = add i64 %31, 1
  %38 = mul i64 %37, %10
  %39 = add i64 %32, %38
  %40 = getelementptr inbounds double, ptr %8, i64 %39
  %41 = load double, ptr %40, align 8, !invariant.load !1
  %42 = getelementptr inbounds double, ptr addrspace(5) %15, i32 1
  store double %41, ptr addrspace(5) %42, align 8
  %43 = load double, ptr addrspace(5) %15, align 8
  %44 = trunc i64 %17 to i32
  %45 = mul i32 %44, 2
  %46 = sext i32 %45 to i64
  %47 = getelementptr inbounds double, ptr %14, i64 %46
  store double %43, ptr %47, align 8
  %48 = mul i64 %17, 2
  %49 = sitofp i64 %48 to double
  store double %49, ptr addrspace(5) %15, align 8
  %50 = load double, ptr addrspace(5) %42, align 8
  %51 = add i32 %45, 1
  %52 = sext i32 %51 to i64
  %53 = getelementptr inbounds double, ptr %14, i64 %52
  store double %50, ptr %53, align 8
  %54 = add i64 %48, 1
  %55 = sitofp i64 %54 to double
  store double %55, ptr addrspace(5) %42, align 8
  %56 = load <2 x double>, ptr addrspace(5) %15, align 8
  %57 = extractelement <2 x double> %56, i64 0
  %58 = mul i64 %24, %12
  %59 = mul i64 %31, %13
  %60 = add i64 %58, %59
  %61 = getelementptr inbounds double, ptr %11, i64 %60
  store double %57, ptr %61, align 8
  %62 = extractelement <2 x double> %56, i64 1
  %63 = mul i64 %37, %13
  %64 = add i64 %58, %63
  %65 = getelementptr inbounds double, ptr %11, i64 %64
  store double %62, ptr %65, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
