; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_compute_fn_float32_float32_float32_False_4_2547971f(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca [2 x ptr], i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i64, i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca [2 x ptr], i64 1, align 8
  %17 = alloca i32, i64 1, align 4
  %18 = alloca i32, i64 1, align 4
  %19 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %20 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %21 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %22 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %21, 0
  %23 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %21, 1, 1, 0
  %24 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %20, 0
  %25 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %20, 1, 1, 0
  %26 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %19, 0
  %27 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %19, 1, 1, 0
  %28 = sext i32 %3 to i64
  %29 = sext i32 %5 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %31 = zext i32 %30 to i64
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %33 = zext i32 %32 to i64
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %35 = sext i32 %34 to i64
  %36 = mul i64 %33, %35
  %37 = add i64 %36, %31
  %38 = udiv i64 %37, 32
  %39 = bitcast i64 %38 to <2 x i32>
  %40 = extractelement <2 x i32> %39, i64 0
  %41 = extractelement <2 x i32> %39, i64 1
  %42 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %40, i32 0, i32 31)
  %43 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %41, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %42, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i32 %43, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %44 = insertvalue [2 x ptr] undef, ptr %18, 0
  %45 = insertvalue [2 x ptr] %44, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %45, ptr %16, align 8
  %46 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %47 = load ptr, ptr %46, align 8
  %48 = load i32, ptr %47, align 4
  %49 = insertelement <2 x i32> undef, i32 %48, i64 0
  %50 = getelementptr inbounds ptr, ptr %46, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = load i32, ptr %51, align 4
  %53 = insertelement <2 x i32> %49, i32 %52, i64 1
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  %54 = bitcast <2 x i32> %53 to i64
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %54, ptr %15, align 8
  %55 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %56 = sext i32 %55 to i64
  %57 = mul i64 %56, 4
  %58 = icmp eq i64 %56, 0
  %59 = load i64, ptr %15, align 8
  %60 = icmp sge i64 %59, %28
  br i1 %60, label %61, label %62

61:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %195

62:                                               ; preds = %6
  %63 = sdiv i64 %29, 4
  %64 = mul i64 %63, 4
  %65 = icmp eq i64 %64, %29
  %66 = xor i64 %29, 4
  %67 = ashr i64 %66, 63
  %68 = select i1 %65, i64 0, i64 %67
  %69 = add i64 %63, %68
  %70 = sdiv i64 %69, -32
  %71 = mul i64 %70, -32
  %72 = icmp eq i64 %71, %69
  %73 = xor i64 %69, -32
  %74 = ashr i64 %73, 63
  %75 = select i1 %72, i64 0, i64 %74
  %76 = add i64 %70, %75
  %77 = sub i64 0, %76
  %78 = sub i64 %77, 1
  %79 = call i64 @llvm.smax.i64(i64 %78, i64 0)
  br label %80

80:                                               ; preds = %88, %62
  %81 = phi <4 x float> [ zeroinitializer, %62 ], [ %118, %88 ]
  %82 = phi i64 [ 0, %62 ], [ %85, %88 ]
  call void @llvm.lifetime.end.p0(ptr %14)
  %83 = icmp eq i64 %82, %79
  %84 = add i64 %82, 1
  %85 = select i1 %83, i64 %82, i64 %84
  br i1 %83, label %86, label %88

86:                                               ; preds = %80
  %87 = icmp sgt i64 %77, 0
  br i1 %87, label %119, label %159

88:                                               ; preds = %80
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %82, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %89 = insertvalue [2 x ptr] undef, ptr %15, 0
  %90 = insertvalue [2 x ptr] %89, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %90, ptr %13, align 8
  %91 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %92 = load ptr, ptr %91, align 8
  %93 = load i64, ptr %92, align 8
  %94 = getelementptr inbounds ptr, ptr %91, i32 1
  %95 = load ptr, ptr %94, align 8
  %96 = load i64, ptr %95, align 8
  %97 = mul i64 %93, %25
  %98 = mul i64 %96, 128
  %99 = add i64 %97, %98
  %100 = getelementptr inbounds float, ptr %24, i64 %99
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 0, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %101 = insertvalue [2 x ptr] undef, ptr %12, 0
  %102 = insertvalue [2 x ptr] %101, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %102, ptr %11, align 8
  %103 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %104 = load ptr, ptr %103, align 8
  %105 = load i64, ptr %104, align 8
  %106 = getelementptr inbounds ptr, ptr %103, i32 1
  %107 = load ptr, ptr %106, align 8
  %108 = load i64, ptr %107, align 8
  %109 = mul i64 %105, %27
  %110 = mul i64 %108, 128
  %111 = add i64 %109, %110
  %112 = getelementptr inbounds float, ptr %26, i64 %111
  %113 = getelementptr inbounds float, ptr %100, i64 %57
  %114 = load <4 x float>, ptr %113, align 16, !invariant.load !1
  %115 = getelementptr inbounds float, ptr %112, i64 %57
  %116 = load <4 x float>, ptr %115, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %117 = fmul contract <4 x float> %114, %116
  %118 = fadd contract <4 x float> %81, %117
  br label %80

119:                                              ; preds = %86
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %78, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %120 = insertvalue [2 x ptr] undef, ptr %15, 0
  %121 = insertvalue [2 x ptr] %120, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %121, ptr %9, align 8
  %122 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %123 = load ptr, ptr %122, align 8
  %124 = load i64, ptr %123, align 8
  %125 = getelementptr inbounds ptr, ptr %122, i32 1
  %126 = load ptr, ptr %125, align 8
  %127 = load i64, ptr %126, align 8
  %128 = mul i64 %124, %25
  %129 = mul i64 %127, 128
  %130 = add i64 %128, %129
  %131 = getelementptr inbounds float, ptr %24, i64 %130
  %132 = getelementptr inbounds float, ptr %131, i64 %57
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 0, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %133 = insertvalue [2 x ptr] undef, ptr %8, 0
  %134 = insertvalue [2 x ptr] %133, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %134, ptr %7, align 8
  %135 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %136 = load ptr, ptr %135, align 8
  %137 = load i64, ptr %136, align 8
  %138 = getelementptr inbounds ptr, ptr %135, i32 1
  %139 = load ptr, ptr %138, align 8
  %140 = load i64, ptr %139, align 8
  %141 = mul i64 %137, %27
  %142 = mul i64 %140, 128
  %143 = add i64 %141, %142
  %144 = getelementptr inbounds float, ptr %26, i64 %143
  %145 = getelementptr inbounds float, ptr %144, i64 %57
  %146 = load i64, ptr %10, align 8
  %147 = mul i64 %146, 32
  %148 = add i64 %56, %147
  %149 = mul i64 %148, 4
  %150 = icmp slt i64 %149, %29
  br i1 %150, label %151, label %156

151:                                              ; preds = %119
  %152 = load <4 x float>, ptr %132, align 16, !invariant.load !1
  %153 = load <4 x float>, ptr %145, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %154 = fmul contract <4 x float> %152, %153
  %155 = fadd contract <4 x float> %81, %154
  br label %157

156:                                              ; preds = %119
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  br label %157

157:                                              ; preds = %156, %151
  %158 = phi <4 x float> [ %81, %156 ], [ %155, %151 ]
  br label %160

159:                                              ; preds = %86
  br label %160

160:                                              ; preds = %159, %157
  %161 = phi <4 x float> [ %81, %159 ], [ %158, %157 ]
  %162 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %161, i64 0)
  %163 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %161, i64 2)
  %164 = fadd contract <2 x float> %162, %163
  %165 = extractelement <2 x float> %164, i64 0
  %166 = extractelement <2 x float> %164, i64 1
  %167 = fadd contract float %165, %166
  %168 = bitcast float %167 to i32
  %169 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %168, i32 16, i32 31)
  %170 = bitcast i32 %169 to float
  %171 = fadd contract float %167, %170
  %172 = bitcast float %171 to i32
  %173 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %172, i32 8, i32 31)
  %174 = bitcast i32 %173 to float
  %175 = fadd contract float %171, %174
  %176 = bitcast float %175 to i32
  %177 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %176, i32 4, i32 31)
  %178 = bitcast i32 %177 to float
  %179 = fadd contract float %175, %178
  %180 = bitcast float %179 to i32
  %181 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %180, i32 2, i32 31)
  %182 = bitcast i32 %181 to float
  %183 = fadd contract float %179, %182
  %184 = bitcast float %183 to i32
  %185 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %184, i32 1, i32 31)
  %186 = bitcast i32 %185 to float
  %187 = fadd contract float %183, %186
  %188 = fadd contract float %187, 2.000000e+00
  br i1 %58, label %189, label %193

189:                                              ; preds = %160
  %190 = load i64, ptr %15, align 8
  %191 = mul i64 %190, %23
  %192 = getelementptr inbounds float, ptr %22, i64 %191
  store float %188, ptr %192, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %194

193:                                              ; preds = %160
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %194

194:                                              ; preds = %193, %189
  br label %195

195:                                              ; preds = %194, %61
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
