; ModuleID = 'test_layout_mma.mojo'
source_filename = "test_layout_mma.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @test_layout_mma_c_fragment_kern6A6A_957f36c79da62114(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { i64, i64 } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { i64, i64 } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca [4 x double], align 8
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
  %43 = add i64 %24, 8
  %44 = mul i64 %43, %9
  %45 = add i64 %44, %33
  %46 = getelementptr inbounds double, ptr %8, i64 %45
  %47 = load double, ptr %46, align 8, !invariant.load !1
  %48 = getelementptr inbounds double, ptr addrspace(5) %15, i32 2
  store double %47, ptr addrspace(5) %48, align 8
  %49 = add i64 %44, %38
  %50 = getelementptr inbounds double, ptr %8, i64 %49
  %51 = load double, ptr %50, align 8, !invariant.load !1
  %52 = getelementptr inbounds double, ptr addrspace(5) %15, i32 3
  store double %51, ptr addrspace(5) %52, align 8
  %53 = load double, ptr addrspace(5) %15, align 8
  %54 = trunc i64 %17 to i32
  %55 = mul i32 %54, 4
  %56 = sext i32 %55 to i64
  %57 = getelementptr inbounds double, ptr %14, i64 %56
  store double %53, ptr %57, align 8
  %58 = mul i64 %17, 4
  %59 = sitofp i64 %58 to double
  store double %59, ptr addrspace(5) %15, align 8
  %60 = load double, ptr addrspace(5) %42, align 8
  %61 = add i32 %55, 1
  %62 = sext i32 %61 to i64
  %63 = getelementptr inbounds double, ptr %14, i64 %62
  store double %60, ptr %63, align 8
  %64 = add i64 %58, 1
  %65 = sitofp i64 %64 to double
  store double %65, ptr addrspace(5) %42, align 8
  %66 = load double, ptr addrspace(5) %48, align 8
  %67 = add i32 %55, 2
  %68 = sext i32 %67 to i64
  %69 = getelementptr inbounds double, ptr %14, i64 %68
  store double %66, ptr %69, align 8
  %70 = add i64 %58, 2
  %71 = sitofp i64 %70 to double
  store double %71, ptr addrspace(5) %48, align 8
  %72 = load double, ptr addrspace(5) %52, align 8
  %73 = add i32 %55, 3
  %74 = sext i32 %73 to i64
  %75 = getelementptr inbounds double, ptr %14, i64 %74
  store double %72, ptr %75, align 8
  %76 = add i64 %58, 3
  %77 = sitofp i64 %76 to double
  store double %77, ptr addrspace(5) %52, align 8
  %78 = load <4 x double>, ptr addrspace(5) %15, align 8
  %79 = extractelement <4 x double> %78, i64 0
  %80 = mul i64 %24, %12
  %81 = mul i64 %31, %13
  %82 = add i64 %80, %81
  %83 = getelementptr inbounds double, ptr %11, i64 %82
  store double %79, ptr %83, align 8
  %84 = extractelement <4 x double> %78, i64 1
  %85 = mul i64 %37, %13
  %86 = add i64 %80, %85
  %87 = getelementptr inbounds double, ptr %11, i64 %86
  store double %84, ptr %87, align 8
  %88 = extractelement <4 x double> %78, i64 2
  %89 = mul i64 %43, %12
  %90 = add i64 %89, %81
  %91 = getelementptr inbounds double, ptr %11, i64 %90
  store double %88, ptr %91, align 8
  %92 = extractelement <4 x double> %78, i64 3
  %93 = add i64 %89, %85
  %94 = getelementptr inbounds double, ptr %11, i64 %93
  store double %92, ptr %94, align 8
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
