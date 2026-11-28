; ModuleID = 'test_gemv_multirow.mojo'
source_filename = "test_gemv_multirow.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_compute_fn_bfloat16_bfloat16_bfloat16_True_8_ddbcea59(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i32, i64 1, align 4
  %15 = alloca i32, i64 1, align 4
  %16 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %17 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %18 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %19 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %18, 0
  %20 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %17, 0
  %21 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %16, 0
  %22 = sext i32 %5 to i64
  %23 = sext i32 %3 to i64
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %25 = zext i32 %24 to i64
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %27 = zext i32 %26 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %29 = sext i32 %28 to i64
  %30 = mul i64 %27, %29
  %31 = add i64 %30, %25
  %32 = udiv i64 %31, 32
  %33 = bitcast i64 %32 to <2 x i32>
  %34 = extractelement <2 x i32> %33, i64 0
  %35 = extractelement <2 x i32> %33, i64 1
  %36 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %34, i32 0, i32 31)
  %37 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %35, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i32 %36, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i32 %37, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %38 = insertvalue [2 x ptr] undef, ptr %15, 0
  %39 = insertvalue [2 x ptr] %38, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %39, ptr %13, align 8
  %40 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %41 = load ptr, ptr %40, align 8
  %42 = load i32, ptr %41, align 4
  %43 = insertelement <2 x i32> undef, i32 %42, i64 0
  %44 = getelementptr inbounds ptr, ptr %40, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = load i32, ptr %45, align 4
  %47 = insertelement <2 x i32> %43, i32 %46, i64 1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %48 = bitcast <2 x i32> %47 to i64
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %48, ptr %12, align 8
  %49 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %50 = sext i32 %49 to i64
  %51 = trunc i64 %50 to i32
  %52 = mul i32 %51, 8
  %53 = sext i32 %52 to i64
  %54 = icmp eq i64 %50, 0
  %55 = load i64, ptr %12, align 8
  %56 = icmp sge i64 %55, %23
  br i1 %56, label %57, label %58

57:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %151

58:                                               ; preds = %7
  %59 = udiv i64 %22, 256
  %60 = add i64 %59, 1
  %61 = sub i64 %60, 1
  %62 = call i64 @llvm.smax.i64(i64 %61, i64 0)
  br label %63

63:                                               ; preds = %100, %58
  %64 = phi <8 x float> [ zeroinitializer, %58 ], [ %138, %100 ]
  %65 = phi i64 [ 0, %58 ], [ %68, %100 ]
  call void @llvm.lifetime.end.p0(ptr %11)
  %66 = icmp eq i64 %65, %62
  %67 = add i64 %65, 1
  %68 = select i1 %66, i64 %65, i64 %67
  br i1 %66, label %69, label %100

69:                                               ; preds = %63
  %70 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %64, i64 0)
  %71 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %64, i64 4)
  %72 = fadd contract <4 x float> %70, %71
  %73 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %72, i64 0)
  %74 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %72, i64 2)
  %75 = fadd contract <2 x float> %73, %74
  %76 = extractelement <2 x float> %75, i64 0
  %77 = extractelement <2 x float> %75, i64 1
  %78 = fadd contract float %76, %77
  %79 = bitcast float %78 to i32
  %80 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %79, i32 16, i32 31)
  %81 = bitcast i32 %80 to float
  %82 = fadd contract float %78, %81
  %83 = bitcast float %82 to i32
  %84 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %83, i32 8, i32 31)
  %85 = bitcast i32 %84 to float
  %86 = fadd contract float %82, %85
  %87 = bitcast float %86 to i32
  %88 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %87, i32 4, i32 31)
  %89 = bitcast i32 %88 to float
  %90 = fadd contract float %86, %89
  %91 = bitcast float %90 to i32
  %92 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %91, i32 2, i32 31)
  %93 = bitcast i32 %92 to float
  %94 = fadd contract float %90, %93
  %95 = bitcast float %94 to i32
  %96 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %95, i32 1, i32 31)
  %97 = bitcast i32 %96 to float
  %98 = fadd contract float %94, %97
  %99 = fptrunc float %98 to bfloat
  br i1 %54, label %139, label %149

100:                                              ; preds = %63
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %65, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %101 = insertvalue [2 x ptr] undef, ptr %12, 0
  %102 = insertvalue [2 x ptr] %101, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %102, ptr %10, align 8
  %103 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %104 = load ptr, ptr %103, align 8
  %105 = load i64, ptr %104, align 8
  %106 = trunc i64 %105 to i32
  %107 = getelementptr inbounds ptr, ptr %103, i32 1
  %108 = load ptr, ptr %107, align 8
  %109 = load i64, ptr %108, align 8
  %110 = trunc i64 %109 to i32
  %111 = mul i32 %106, 256
  %112 = mul i32 %110, 256
  %113 = add i32 %111, %112
  %114 = sext i32 %113 to i64
  %115 = getelementptr inbounds bfloat, ptr %20, i64 %114
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 0, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %116 = insertvalue [2 x ptr] undef, ptr %9, 0
  %117 = insertvalue [2 x ptr] %116, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %117, ptr %8, align 8
  %118 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %119 = load ptr, ptr %118, align 8
  %120 = load i64, ptr %119, align 8
  %121 = trunc i64 %120 to i32
  %122 = getelementptr inbounds ptr, ptr %118, i32 1
  %123 = load ptr, ptr %122, align 8
  %124 = load i64, ptr %123, align 8
  %125 = trunc i64 %124 to i32
  %126 = mul i32 %121, 256
  %127 = mul i32 %125, 256
  %128 = add i32 %126, %127
  %129 = sext i32 %128 to i64
  %130 = getelementptr inbounds bfloat, ptr %21, i64 %129
  %131 = getelementptr inbounds bfloat, ptr %115, i64 %53
  %132 = load <8 x bfloat>, ptr %131, align 16, !invariant.load !1
  %133 = getelementptr inbounds bfloat, ptr %130, i64 %53
  %134 = load <8 x bfloat>, ptr %133, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %135 = fpext <8 x bfloat> %132 to <8 x float>
  %136 = fpext <8 x bfloat> %134 to <8 x float>
  %137 = fmul contract <8 x float> %135, %136
  %138 = fadd contract <8 x float> %64, %137
  br label %63

139:                                              ; preds = %69
  %140 = load i64, ptr %12, align 8
  %141 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %142 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %141, 0
  %143 = trunc i64 %140 to i32
  %144 = sext i32 %143 to i64
  %145 = getelementptr inbounds bfloat, ptr %142, i64 %144
  %146 = load bfloat, ptr %145, align 2, !invariant.load !1
  %147 = fadd contract bfloat %99, %146
  %148 = getelementptr inbounds bfloat, ptr %19, i64 %144
  store bfloat %147, ptr %148, align 2
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %150

149:                                              ; preds = %69
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %150

150:                                              ; preds = %149, %139
  br label %151

151:                                              ; preds = %150, %57
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
