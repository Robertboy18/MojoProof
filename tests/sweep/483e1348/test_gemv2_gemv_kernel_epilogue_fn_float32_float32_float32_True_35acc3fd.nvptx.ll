; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_epilogue_fn_float32_float32_float32_True_35acc3fd(ptr noundef %0, ptr noundef %1, ptr noundef %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }) %6) #0 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i32, i64 1, align 4
  %10 = alloca i32, i64 1, align 4
  %11 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 2
  %12 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 1
  %13 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 0
  %14 = sext i32 %3 to i64
  %15 = sext i32 %5 to i64
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %17 = zext i32 %16 to i64
  %18 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %19 = zext i32 %18 to i64
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %21 = sext i32 %20 to i64
  %22 = mul i64 %19, %21
  %23 = add i64 %22, %17
  %24 = udiv i64 %23, 32
  %25 = bitcast i64 %24 to <2 x i32>
  %26 = extractelement <2 x i32> %25, i64 0
  %27 = extractelement <2 x i32> %25, i64 1
  %28 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %26, i32 0, i32 31)
  %29 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %27, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i32 %28, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i32 %29, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %30 = insertvalue [2 x ptr] undef, ptr %10, 0
  %31 = insertvalue [2 x ptr] %30, ptr %9, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %31, ptr %8, align 8
  %32 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %33 = load ptr, ptr %32, align 8
  %34 = load i32, ptr %33, align 4
  %35 = insertelement <2 x i32> undef, i32 %34, i64 0
  %36 = getelementptr inbounds ptr, ptr %32, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = load i32, ptr %37, align 4
  %39 = insertelement <2 x i32> %35, i32 %38, i64 1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %40 = bitcast <2 x i32> %39 to i64
  %41 = trunc i64 %40 to i32
  %42 = mul i64 %40, %15
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %44 = sext i32 %43 to i64
  %45 = icmp eq i64 %44, 0
  %46 = icmp sge i64 %40, %14
  br i1 %46, label %47, label %48

47:                                               ; preds = %7
  br label %113

48:                                               ; preds = %7
  %49 = sdiv i64 %15, -32
  %50 = mul i64 %49, -32
  %51 = icmp eq i64 %50, %15
  %52 = xor i64 %15, -32
  %53 = ashr i64 %52, 63
  %54 = select i1 %51, i64 0, i64 %53
  %55 = add i64 %49, %54
  %56 = sub i64 0, %55
  %57 = call i64 @llvm.smax.i64(i64 %56, i64 0)
  br label %58

58:                                               ; preds = %99, %48
  %59 = phi i64 [ 0, %48 ], [ %65, %99 ]
  %60 = phi float [ 0.000000e+00, %48 ], [ %100, %99 ]
  %61 = icmp slt i64 %59, %57
  br i1 %61, label %62, label %72

62:                                               ; preds = %58
  %63 = icmp eq i64 %59, %57
  %64 = add i64 %59, 1
  %65 = select i1 %63, i64 %59, i64 %64
  %66 = mul i64 %59, 32
  %67 = add i64 %66, %44
  %68 = getelementptr inbounds float, ptr %2, i64 %67
  %69 = add i64 %42, %67
  %70 = getelementptr inbounds float, ptr %1, i64 %69
  %71 = icmp slt i64 %67, %15
  br i1 %71, label %93, label %98

72:                                               ; preds = %58
  %73 = bitcast float %60 to i32
  %74 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %73, i32 16, i32 31)
  %75 = bitcast i32 %74 to float
  %76 = fadd contract float %60, %75
  %77 = bitcast float %76 to i32
  %78 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %77, i32 8, i32 31)
  %79 = bitcast i32 %78 to float
  %80 = fadd contract float %76, %79
  %81 = bitcast float %80 to i32
  %82 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %81, i32 4, i32 31)
  %83 = bitcast i32 %82 to float
  %84 = fadd contract float %80, %83
  %85 = bitcast float %84 to i32
  %86 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %85, i32 2, i32 31)
  %87 = bitcast i32 %86 to float
  %88 = fadd contract float %84, %87
  %89 = bitcast float %88 to i32
  %90 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %89, i32 1, i32 31)
  %91 = bitcast i32 %90 to float
  %92 = fadd contract float %88, %91
  br i1 %45, label %101, label %111

93:                                               ; preds = %62
  %94 = load float, ptr %70, align 4, !invariant.load !1
  %95 = load float, ptr %68, align 4, !invariant.load !1
  %96 = fmul contract float %94, %95
  %97 = fadd contract float %60, %96
  br label %99

98:                                               ; preds = %62
  br label %99

99:                                               ; preds = %98, %93
  %100 = phi float [ %60, %98 ], [ %97, %93 ]
  br label %58

101:                                              ; preds = %72
  %102 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %13, align 8
  %103 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %12, align 8
  %104 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %11, align 8
  %105 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %102, 0
  %106 = getelementptr inbounds float, ptr %105, i64 %40
  store float %92, ptr %106, align 4
  %107 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %103, 0
  %108 = getelementptr inbounds i32, ptr %107, i64 %40
  store i32 0, ptr %108, align 4
  %109 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %104, 0
  %110 = getelementptr inbounds i32, ptr %109, i64 %40
  store i32 %41, ptr %110, align 4
  br label %112

111:                                              ; preds = %72
  br label %112

112:                                              ; preds = %111, %101
  br label %113

113:                                              ; preds = %112, %47
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.idx.i32(i32, i32, i32, i32) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #2

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
