; ModuleID = 'test_gemv_multirow.mojo'
source_filename = "test_gemv_multirow.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_float32_bfloat16_bfloat16_True_8_4_73f4570f(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca [2 x ptr], i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i64, i64 1, align 8
  %15 = alloca [2 x ptr], i64 1, align 8
  %16 = alloca i64, i64 1, align 8
  %17 = alloca i64, i64 1, align 8
  %18 = alloca [2 x ptr], i64 1, align 8
  %19 = alloca i32, i64 1, align 4
  %20 = alloca i32, i64 1, align 4
  %21 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %22 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %23 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %24 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %23, 0
  %25 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %22, 0
  %26 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %21, 0
  %27 = sext i32 %5 to i64
  %28 = sext i32 %3 to i64
  %29 = sub i64 %28, 1
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
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i32 %42, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i32 %43, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  %44 = insertvalue [2 x ptr] undef, ptr %20, 0
  %45 = insertvalue [2 x ptr] %44, ptr %19, 1
  call void @llvm.lifetime.start.p0(ptr %18)
  store [2 x ptr] %45, ptr %18, align 8
  %46 = getelementptr inbounds [2 x ptr], ptr %18, i32 0, i32 0
  %47 = load ptr, ptr %46, align 8
  %48 = load i32, ptr %47, align 4
  %49 = insertelement <2 x i32> undef, i32 %48, i64 0
  %50 = getelementptr inbounds ptr, ptr %46, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = load i32, ptr %51, align 4
  %53 = insertelement <2 x i32> %49, i32 %52, i64 1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  %54 = bitcast <2 x i32> %53 to i64
  %55 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %56 = sext i32 %55 to i64
  %57 = trunc i64 %56 to i32
  %58 = mul i32 %57, 8
  %59 = sext i32 %58 to i64
  %60 = icmp eq i64 %56, 0
  %61 = mul i64 %54, 4
  %62 = trunc i64 %61 to i32
  %63 = sext i32 %62 to i64
  %64 = getelementptr inbounds float, ptr %24, i64 %63
  %65 = icmp slt i64 %61, %28
  %66 = select i1 %60, i1 %65, i1 false
  %67 = add i64 %61, 3
  %68 = trunc i64 %67 to i32
  %69 = sext i32 %68 to i64
  %70 = getelementptr inbounds float, ptr %24, i64 %69
  %71 = icmp slt i64 %67, %28
  %72 = select i1 %60, i1 %71, i1 false
  %73 = call i64 @llvm.smin.i64(i64 %67, i64 %29)
  %74 = add i64 %61, 2
  %75 = trunc i64 %74 to i32
  %76 = sext i32 %75 to i64
  %77 = getelementptr inbounds float, ptr %24, i64 %76
  %78 = icmp slt i64 %74, %28
  %79 = select i1 %60, i1 %78, i1 false
  %80 = call i64 @llvm.smin.i64(i64 %74, i64 %29)
  %81 = add i64 %61, 1
  %82 = trunc i64 %81 to i32
  %83 = sext i32 %82 to i64
  %84 = getelementptr inbounds float, ptr %24, i64 %83
  %85 = icmp slt i64 %81, %28
  %86 = select i1 %60, i1 %85, i1 false
  %87 = call i64 @llvm.smin.i64(i64 %81, i64 %29)
  %88 = call i64 @llvm.smin.i64(i64 %61, i64 %29)
  %89 = icmp sge i64 %61, %28
  br i1 %89, label %90, label %91

90:                                               ; preds = %6
  br label %333

91:                                               ; preds = %6
  %92 = udiv i64 %27, 256
  %93 = add i64 %92, 1
  %94 = sub i64 %93, 1
  %95 = call i64 @llvm.smax.i64(i64 %94, i64 0)
  br label %96

96:                                               ; preds = %135, %91
  %97 = phi i64 [ 0, %91 ], [ %104, %135 ]
  %98 = phi <8 x float> [ zeroinitializer, %91 ], [ %173, %135 ]
  %99 = phi <8 x float> [ zeroinitializer, %91 ], [ %193, %135 ]
  %100 = phi <8 x float> [ zeroinitializer, %91 ], [ %213, %135 ]
  %101 = phi <8 x float> [ zeroinitializer, %91 ], [ %233, %135 ]
  call void @llvm.lifetime.end.p0(ptr %17)
  %102 = icmp eq i64 %97, %95
  %103 = add i64 %97, 1
  %104 = select i1 %102, i64 %97, i64 %103
  br i1 %102, label %105, label %135

105:                                              ; preds = %96
  %106 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %98, i64 0)
  %107 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %98, i64 4)
  %108 = fadd contract <4 x float> %106, %107
  %109 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %108, i64 0)
  %110 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %108, i64 2)
  %111 = fadd contract <2 x float> %109, %110
  %112 = extractelement <2 x float> %111, i64 0
  %113 = extractelement <2 x float> %111, i64 1
  %114 = fadd contract float %112, %113
  %115 = bitcast float %114 to i32
  %116 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %115, i32 16, i32 31)
  %117 = bitcast i32 %116 to float
  %118 = fadd contract float %114, %117
  %119 = bitcast float %118 to i32
  %120 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %119, i32 8, i32 31)
  %121 = bitcast i32 %120 to float
  %122 = fadd contract float %118, %121
  %123 = bitcast float %122 to i32
  %124 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %123, i32 4, i32 31)
  %125 = bitcast i32 %124 to float
  %126 = fadd contract float %122, %125
  %127 = bitcast float %126 to i32
  %128 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %127, i32 2, i32 31)
  %129 = bitcast i32 %128 to float
  %130 = fadd contract float %126, %129
  %131 = bitcast float %130 to i32
  %132 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %131, i32 1, i32 31)
  %133 = bitcast i32 %132 to float
  %134 = fadd contract float %130, %133
  br i1 %66, label %234, label %235

135:                                              ; preds = %96
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %97, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 0, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  %136 = insertvalue [2 x ptr] undef, ptr %16, 0
  %137 = insertvalue [2 x ptr] %136, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %15)
  store [2 x ptr] %137, ptr %15, align 8
  %138 = getelementptr inbounds [2 x ptr], ptr %15, i32 0, i32 0
  %139 = load ptr, ptr %138, align 8
  %140 = load i64, ptr %139, align 8
  %141 = trunc i64 %140 to i32
  %142 = getelementptr inbounds ptr, ptr %138, i32 1
  %143 = load ptr, ptr %142, align 8
  %144 = load i64, ptr %143, align 8
  %145 = trunc i64 %144 to i32
  %146 = mul i32 %141, 512
  %147 = mul i32 %145, 256
  %148 = add i32 %146, %147
  %149 = sext i32 %148 to i64
  %150 = getelementptr inbounds bfloat, ptr %26, i64 %149
  %151 = getelementptr inbounds bfloat, ptr %150, i64 %59
  %152 = load <8 x bfloat>, ptr %151, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %88, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %153 = insertvalue [2 x ptr] undef, ptr %14, 0
  %154 = insertvalue [2 x ptr] %153, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %154, ptr %13, align 8
  %155 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %156 = load ptr, ptr %155, align 8
  %157 = load i64, ptr %156, align 8
  %158 = trunc i64 %157 to i32
  %159 = getelementptr inbounds ptr, ptr %155, i32 1
  %160 = load ptr, ptr %159, align 8
  %161 = load i64, ptr %160, align 8
  %162 = trunc i64 %161 to i32
  %163 = mul i32 %158, 512
  %164 = mul i32 %162, 256
  %165 = add i32 %163, %164
  %166 = sext i32 %165 to i64
  %167 = getelementptr inbounds bfloat, ptr %25, i64 %166
  %168 = getelementptr inbounds bfloat, ptr %167, i64 %59
  %169 = load <8 x bfloat>, ptr %168, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %170 = fpext <8 x bfloat> %169 to <8 x float>
  %171 = fpext <8 x bfloat> %152 to <8 x float>
  %172 = fmul contract <8 x float> %170, %171
  %173 = fadd contract <8 x float> %98, %172
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %87, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %174 = insertvalue [2 x ptr] undef, ptr %12, 0
  %175 = insertvalue [2 x ptr] %174, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %175, ptr %11, align 8
  %176 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %177 = load ptr, ptr %176, align 8
  %178 = load i64, ptr %177, align 8
  %179 = trunc i64 %178 to i32
  %180 = getelementptr inbounds ptr, ptr %176, i32 1
  %181 = load ptr, ptr %180, align 8
  %182 = load i64, ptr %181, align 8
  %183 = trunc i64 %182 to i32
  %184 = mul i32 %179, 512
  %185 = mul i32 %183, 256
  %186 = add i32 %184, %185
  %187 = sext i32 %186 to i64
  %188 = getelementptr inbounds bfloat, ptr %25, i64 %187
  %189 = getelementptr inbounds bfloat, ptr %188, i64 %59
  %190 = load <8 x bfloat>, ptr %189, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  %191 = fpext <8 x bfloat> %190 to <8 x float>
  %192 = fmul contract <8 x float> %191, %171
  %193 = fadd contract <8 x float> %99, %192
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %80, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %194 = insertvalue [2 x ptr] undef, ptr %10, 0
  %195 = insertvalue [2 x ptr] %194, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %195, ptr %9, align 8
  %196 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %197 = load ptr, ptr %196, align 8
  %198 = load i64, ptr %197, align 8
  %199 = trunc i64 %198 to i32
  %200 = getelementptr inbounds ptr, ptr %196, i32 1
  %201 = load ptr, ptr %200, align 8
  %202 = load i64, ptr %201, align 8
  %203 = trunc i64 %202 to i32
  %204 = mul i32 %199, 512
  %205 = mul i32 %203, 256
  %206 = add i32 %204, %205
  %207 = sext i32 %206 to i64
  %208 = getelementptr inbounds bfloat, ptr %25, i64 %207
  %209 = getelementptr inbounds bfloat, ptr %208, i64 %59
  %210 = load <8 x bfloat>, ptr %209, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %211 = fpext <8 x bfloat> %210 to <8 x float>
  %212 = fmul contract <8 x float> %211, %171
  %213 = fadd contract <8 x float> %100, %212
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %73, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %214 = insertvalue [2 x ptr] undef, ptr %8, 0
  %215 = insertvalue [2 x ptr] %214, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %215, ptr %7, align 8
  %216 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %217 = load ptr, ptr %216, align 8
  %218 = load i64, ptr %217, align 8
  %219 = trunc i64 %218 to i32
  %220 = getelementptr inbounds ptr, ptr %216, i32 1
  %221 = load ptr, ptr %220, align 8
  %222 = load i64, ptr %221, align 8
  %223 = trunc i64 %222 to i32
  %224 = mul i32 %219, 512
  %225 = mul i32 %223, 256
  %226 = add i32 %224, %225
  %227 = sext i32 %226 to i64
  %228 = getelementptr inbounds bfloat, ptr %25, i64 %227
  %229 = getelementptr inbounds bfloat, ptr %228, i64 %59
  %230 = load <8 x bfloat>, ptr %229, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %231 = fpext <8 x bfloat> %230 to <8 x float>
  %232 = fmul contract <8 x float> %231, %171
  %233 = fadd contract <8 x float> %101, %232
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %96

234:                                              ; preds = %105
  store float %134, ptr %64, align 4
  br label %236

235:                                              ; preds = %105
  br label %236

236:                                              ; preds = %235, %234
  %237 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %99, i64 0)
  %238 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %99, i64 4)
  %239 = fadd contract <4 x float> %237, %238
  %240 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %239, i64 0)
  %241 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %239, i64 2)
  %242 = fadd contract <2 x float> %240, %241
  %243 = extractelement <2 x float> %242, i64 0
  %244 = extractelement <2 x float> %242, i64 1
  %245 = fadd contract float %243, %244
  %246 = bitcast float %245 to i32
  %247 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %246, i32 16, i32 31)
  %248 = bitcast i32 %247 to float
  %249 = fadd contract float %245, %248
  %250 = bitcast float %249 to i32
  %251 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %250, i32 8, i32 31)
  %252 = bitcast i32 %251 to float
  %253 = fadd contract float %249, %252
  %254 = bitcast float %253 to i32
  %255 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %254, i32 4, i32 31)
  %256 = bitcast i32 %255 to float
  %257 = fadd contract float %253, %256
  %258 = bitcast float %257 to i32
  %259 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %258, i32 2, i32 31)
  %260 = bitcast i32 %259 to float
  %261 = fadd contract float %257, %260
  %262 = bitcast float %261 to i32
  %263 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %262, i32 1, i32 31)
  %264 = bitcast i32 %263 to float
  %265 = fadd contract float %261, %264
  br i1 %86, label %266, label %267

266:                                              ; preds = %236
  store float %265, ptr %84, align 4
  br label %268

267:                                              ; preds = %236
  br label %268

268:                                              ; preds = %267, %266
  %269 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %100, i64 0)
  %270 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %100, i64 4)
  %271 = fadd contract <4 x float> %269, %270
  %272 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %271, i64 0)
  %273 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %271, i64 2)
  %274 = fadd contract <2 x float> %272, %273
  %275 = extractelement <2 x float> %274, i64 0
  %276 = extractelement <2 x float> %274, i64 1
  %277 = fadd contract float %275, %276
  %278 = bitcast float %277 to i32
  %279 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %278, i32 16, i32 31)
  %280 = bitcast i32 %279 to float
  %281 = fadd contract float %277, %280
  %282 = bitcast float %281 to i32
  %283 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %282, i32 8, i32 31)
  %284 = bitcast i32 %283 to float
  %285 = fadd contract float %281, %284
  %286 = bitcast float %285 to i32
  %287 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %286, i32 4, i32 31)
  %288 = bitcast i32 %287 to float
  %289 = fadd contract float %285, %288
  %290 = bitcast float %289 to i32
  %291 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %290, i32 2, i32 31)
  %292 = bitcast i32 %291 to float
  %293 = fadd contract float %289, %292
  %294 = bitcast float %293 to i32
  %295 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %294, i32 1, i32 31)
  %296 = bitcast i32 %295 to float
  %297 = fadd contract float %293, %296
  br i1 %79, label %298, label %299

298:                                              ; preds = %268
  store float %297, ptr %77, align 4
  br label %300

299:                                              ; preds = %268
  br label %300

300:                                              ; preds = %299, %298
  %301 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %101, i64 0)
  %302 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %101, i64 4)
  %303 = fadd contract <4 x float> %301, %302
  %304 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %303, i64 0)
  %305 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %303, i64 2)
  %306 = fadd contract <2 x float> %304, %305
  %307 = extractelement <2 x float> %306, i64 0
  %308 = extractelement <2 x float> %306, i64 1
  %309 = fadd contract float %307, %308
  %310 = bitcast float %309 to i32
  %311 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %310, i32 16, i32 31)
  %312 = bitcast i32 %311 to float
  %313 = fadd contract float %309, %312
  %314 = bitcast float %313 to i32
  %315 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %314, i32 8, i32 31)
  %316 = bitcast i32 %315 to float
  %317 = fadd contract float %313, %316
  %318 = bitcast float %317 to i32
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 4, i32 31)
  %320 = bitcast i32 %319 to float
  %321 = fadd contract float %317, %320
  %322 = bitcast float %321 to i32
  %323 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %322, i32 2, i32 31)
  %324 = bitcast i32 %323 to float
  %325 = fadd contract float %321, %324
  %326 = bitcast float %325 to i32
  %327 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %326, i32 1, i32 31)
  %328 = bitcast i32 %327 to float
  %329 = fadd contract float %325, %328
  br i1 %72, label %330, label %331

330:                                              ; preds = %300
  store float %329, ptr %70, align 4
  br label %332

331:                                              ; preds = %300
  br label %332

332:                                              ; preds = %331, %330
  br label %333

333:                                              ; preds = %332, %90
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
declare i64 @llvm.smin.i64(i64, i64) #4

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
