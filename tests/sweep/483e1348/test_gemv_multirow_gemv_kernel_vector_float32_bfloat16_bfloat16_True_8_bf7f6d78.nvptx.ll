; ModuleID = 'test_gemv_multirow.mojo'
source_filename = "test_gemv_multirow.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_float32_bfloat16_bfloat16_True_8_bf7f6d78(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca [2 x ptr], i64 1, align 8
  %13 = alloca i32, i64 1, align 4
  %14 = alloca i32, i64 1, align 4
  %15 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %16 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %17 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %18 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %17, 0
  %19 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %16, 0
  %20 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %15, 0
  %21 = sext i32 %5 to i64
  %22 = sext i32 %3 to i64
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %24 = zext i32 %23 to i64
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %26 = zext i32 %25 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %28 = sext i32 %27 to i64
  %29 = mul i64 %26, %28
  %30 = add i64 %29, %24
  %31 = udiv i64 %30, 32
  %32 = bitcast i64 %31 to <2 x i32>
  %33 = extractelement <2 x i32> %32, i64 0
  %34 = extractelement <2 x i32> %32, i64 1
  %35 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %33, i32 0, i32 31)
  %36 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %34, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i32 %35, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i32 %36, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %37 = insertvalue [2 x ptr] undef, ptr %14, 0
  %38 = insertvalue [2 x ptr] %37, ptr %13, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %38, ptr %12, align 8
  %39 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %40 = load ptr, ptr %39, align 8
  %41 = load i32, ptr %40, align 4
  %42 = insertelement <2 x i32> undef, i32 %41, i64 0
  %43 = getelementptr inbounds ptr, ptr %39, i32 1
  %44 = load ptr, ptr %43, align 8
  %45 = load i32, ptr %44, align 4
  %46 = insertelement <2 x i32> %42, i32 %45, i64 1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %47 = bitcast <2 x i32> %46 to i64
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %47, ptr %11, align 8
  %48 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %49 = sext i32 %48 to i64
  %50 = trunc i64 %49 to i32
  %51 = mul i32 %50, 8
  %52 = sext i32 %51 to i64
  %53 = icmp eq i64 %49, 0
  %54 = load i64, ptr %11, align 8
  %55 = icmp sge i64 %54, %22
  br i1 %55, label %56, label %57

56:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %144

57:                                               ; preds = %6
  %58 = udiv i64 %21, 256
  %59 = add i64 %58, 1
  %60 = sub i64 %59, 1
  %61 = call i64 @llvm.smax.i64(i64 %60, i64 0)
  br label %62

62:                                               ; preds = %98, %57
  %63 = phi <8 x float> [ zeroinitializer, %57 ], [ %136, %98 ]
  %64 = phi i64 [ 0, %57 ], [ %67, %98 ]
  call void @llvm.lifetime.end.p0(ptr %10)
  %65 = icmp eq i64 %64, %61
  %66 = add i64 %64, 1
  %67 = select i1 %65, i64 %64, i64 %66
  br i1 %65, label %68, label %98

68:                                               ; preds = %62
  %69 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %63, i64 0)
  %70 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %63, i64 4)
  %71 = fadd contract <4 x float> %69, %70
  %72 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %71, i64 0)
  %73 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %71, i64 2)
  %74 = fadd contract <2 x float> %72, %73
  %75 = extractelement <2 x float> %74, i64 0
  %76 = extractelement <2 x float> %74, i64 1
  %77 = fadd contract float %75, %76
  %78 = bitcast float %77 to i32
  %79 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %78, i32 16, i32 31)
  %80 = bitcast i32 %79 to float
  %81 = fadd contract float %77, %80
  %82 = bitcast float %81 to i32
  %83 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %82, i32 8, i32 31)
  %84 = bitcast i32 %83 to float
  %85 = fadd contract float %81, %84
  %86 = bitcast float %85 to i32
  %87 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %86, i32 4, i32 31)
  %88 = bitcast i32 %87 to float
  %89 = fadd contract float %85, %88
  %90 = bitcast float %89 to i32
  %91 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %90, i32 2, i32 31)
  %92 = bitcast i32 %91 to float
  %93 = fadd contract float %89, %92
  %94 = bitcast float %93 to i32
  %95 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %94, i32 1, i32 31)
  %96 = bitcast i32 %95 to float
  %97 = fadd contract float %93, %96
  br i1 %53, label %137, label %142

98:                                               ; preds = %62
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %64, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %99 = insertvalue [2 x ptr] undef, ptr %11, 0
  %100 = insertvalue [2 x ptr] %99, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %100, ptr %9, align 8
  %101 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %102 = load ptr, ptr %101, align 8
  %103 = load i64, ptr %102, align 8
  %104 = trunc i64 %103 to i32
  %105 = getelementptr inbounds ptr, ptr %101, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = load i64, ptr %106, align 8
  %108 = trunc i64 %107 to i32
  %109 = mul i32 %104, 512
  %110 = mul i32 %108, 256
  %111 = add i32 %109, %110
  %112 = sext i32 %111 to i64
  %113 = getelementptr inbounds bfloat, ptr %19, i64 %112
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 0, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %114 = insertvalue [2 x ptr] undef, ptr %8, 0
  %115 = insertvalue [2 x ptr] %114, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %115, ptr %7, align 8
  %116 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %117 = load ptr, ptr %116, align 8
  %118 = load i64, ptr %117, align 8
  %119 = trunc i64 %118 to i32
  %120 = getelementptr inbounds ptr, ptr %116, i32 1
  %121 = load ptr, ptr %120, align 8
  %122 = load i64, ptr %121, align 8
  %123 = trunc i64 %122 to i32
  %124 = mul i32 %119, 512
  %125 = mul i32 %123, 256
  %126 = add i32 %124, %125
  %127 = sext i32 %126 to i64
  %128 = getelementptr inbounds bfloat, ptr %20, i64 %127
  %129 = getelementptr inbounds bfloat, ptr %113, i64 %52
  %130 = load <8 x bfloat>, ptr %129, align 16, !invariant.load !1
  %131 = getelementptr inbounds bfloat, ptr %128, i64 %52
  %132 = load <8 x bfloat>, ptr %131, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %133 = fpext <8 x bfloat> %130 to <8 x float>
  %134 = fpext <8 x bfloat> %132 to <8 x float>
  %135 = fmul contract <8 x float> %133, %134
  %136 = fadd contract <8 x float> %63, %135
  br label %62

137:                                              ; preds = %68
  %138 = load i64, ptr %11, align 8
  %139 = trunc i64 %138 to i32
  %140 = sext i32 %139 to i64
  %141 = getelementptr inbounds float, ptr %18, i64 %140
  store float %97, ptr %141, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %143

142:                                              ; preds = %68
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %143

143:                                              ; preds = %142, %137
  br label %144

144:                                              ; preds = %143, %56
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

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float>, i64 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float>, i64 immarg) #1

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
