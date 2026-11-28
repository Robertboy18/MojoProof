; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_bfloat16_bfloat16_bfloat16_True_8_4_7f190612(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %21 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %22 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %23 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %24 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %23, 0
  %25 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %22, 0
  %26 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %21, 0
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
  %62 = getelementptr inbounds bfloat, ptr %24, i64 %61
  %63 = icmp slt i64 %61, %28
  %64 = select i1 %60, i1 %63, i1 false
  %65 = add i64 %61, 3
  %66 = getelementptr inbounds bfloat, ptr %24, i64 %65
  %67 = icmp slt i64 %65, %28
  %68 = select i1 %60, i1 %67, i1 false
  %69 = call i64 @llvm.smin.i64(i64 %65, i64 %29)
  %70 = add i64 %61, 2
  %71 = getelementptr inbounds bfloat, ptr %24, i64 %70
  %72 = icmp slt i64 %70, %28
  %73 = select i1 %60, i1 %72, i1 false
  %74 = call i64 @llvm.smin.i64(i64 %70, i64 %29)
  %75 = add i64 %61, 1
  %76 = getelementptr inbounds bfloat, ptr %24, i64 %75
  %77 = icmp slt i64 %75, %28
  %78 = select i1 %60, i1 %77, i1 false
  %79 = call i64 @llvm.smin.i64(i64 %75, i64 %29)
  %80 = call i64 @llvm.smin.i64(i64 %61, i64 %29)
  %81 = icmp sge i64 %61, %28
  br i1 %81, label %82, label %83

82:                                               ; preds = %6
  br label %326

83:                                               ; preds = %6
  %84 = udiv i64 %27, 256
  %85 = add i64 %84, 1
  %86 = sub i64 %85, 1
  %87 = call i64 @llvm.smax.i64(i64 %86, i64 0)
  br label %88

88:                                               ; preds = %128, %83
  %89 = phi i64 [ 0, %83 ], [ %96, %128 ]
  %90 = phi <8 x float> [ zeroinitializer, %83 ], [ %163, %128 ]
  %91 = phi <8 x float> [ zeroinitializer, %83 ], [ %183, %128 ]
  %92 = phi <8 x float> [ zeroinitializer, %83 ], [ %203, %128 ]
  %93 = phi <8 x float> [ zeroinitializer, %83 ], [ %223, %128 ]
  call void @llvm.lifetime.end.p0(ptr %17)
  %94 = icmp eq i64 %89, %87
  %95 = add i64 %89, 1
  %96 = select i1 %94, i64 %89, i64 %95
  br i1 %94, label %97, label %128

97:                                               ; preds = %88
  %98 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %90, i64 0)
  %99 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %90, i64 4)
  %100 = fadd contract <4 x float> %98, %99
  %101 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %100, i64 0)
  %102 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %100, i64 2)
  %103 = fadd contract <2 x float> %101, %102
  %104 = extractelement <2 x float> %103, i64 0
  %105 = extractelement <2 x float> %103, i64 1
  %106 = fadd contract float %104, %105
  %107 = bitcast float %106 to i32
  %108 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %107, i32 16, i32 31)
  %109 = bitcast i32 %108 to float
  %110 = fadd contract float %106, %109
  %111 = bitcast float %110 to i32
  %112 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %111, i32 8, i32 31)
  %113 = bitcast i32 %112 to float
  %114 = fadd contract float %110, %113
  %115 = bitcast float %114 to i32
  %116 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %115, i32 4, i32 31)
  %117 = bitcast i32 %116 to float
  %118 = fadd contract float %114, %117
  %119 = bitcast float %118 to i32
  %120 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %119, i32 2, i32 31)
  %121 = bitcast i32 %120 to float
  %122 = fadd contract float %118, %121
  %123 = bitcast float %122 to i32
  %124 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %123, i32 1, i32 31)
  %125 = bitcast i32 %124 to float
  %126 = fadd contract float %122, %125
  %127 = fptrunc float %126 to bfloat
  br i1 %64, label %224, label %225

128:                                              ; preds = %88
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %89, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 0, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  %129 = insertvalue [2 x ptr] undef, ptr %16, 0
  %130 = insertvalue [2 x ptr] %129, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %15)
  store [2 x ptr] %130, ptr %15, align 8
  %131 = getelementptr inbounds [2 x ptr], ptr %15, i32 0, i32 0
  %132 = load ptr, ptr %131, align 8
  %133 = load i64, ptr %132, align 8
  %134 = getelementptr inbounds ptr, ptr %131, i32 1
  %135 = load ptr, ptr %134, align 8
  %136 = load i64, ptr %135, align 8
  %137 = mul i64 %133, 256
  %138 = mul i64 %136, 256
  %139 = add i64 %137, %138
  %140 = getelementptr inbounds bfloat, ptr %26, i64 %139
  %141 = getelementptr inbounds bfloat, ptr %140, i64 %59
  %142 = load <8 x bfloat>, ptr %141, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %80, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %143 = insertvalue [2 x ptr] undef, ptr %14, 0
  %144 = insertvalue [2 x ptr] %143, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %144, ptr %13, align 8
  %145 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %146 = load ptr, ptr %145, align 8
  %147 = load i64, ptr %146, align 8
  %148 = trunc i64 %147 to i32
  %149 = getelementptr inbounds ptr, ptr %145, i32 1
  %150 = load ptr, ptr %149, align 8
  %151 = load i64, ptr %150, align 8
  %152 = trunc i64 %151 to i32
  %153 = mul i32 %148, 256
  %154 = mul i32 %152, 256
  %155 = add i32 %153, %154
  %156 = sext i32 %155 to i64
  %157 = getelementptr inbounds bfloat, ptr %25, i64 %156
  %158 = getelementptr inbounds bfloat, ptr %157, i64 %59
  %159 = load <8 x bfloat>, ptr %158, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %160 = fpext <8 x bfloat> %159 to <8 x float>
  %161 = fpext <8 x bfloat> %142 to <8 x float>
  %162 = fmul contract <8 x float> %160, %161
  %163 = fadd contract <8 x float> %90, %162
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %79, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %164 = insertvalue [2 x ptr] undef, ptr %12, 0
  %165 = insertvalue [2 x ptr] %164, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %165, ptr %11, align 8
  %166 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %167 = load ptr, ptr %166, align 8
  %168 = load i64, ptr %167, align 8
  %169 = trunc i64 %168 to i32
  %170 = getelementptr inbounds ptr, ptr %166, i32 1
  %171 = load ptr, ptr %170, align 8
  %172 = load i64, ptr %171, align 8
  %173 = trunc i64 %172 to i32
  %174 = mul i32 %169, 256
  %175 = mul i32 %173, 256
  %176 = add i32 %174, %175
  %177 = sext i32 %176 to i64
  %178 = getelementptr inbounds bfloat, ptr %25, i64 %177
  %179 = getelementptr inbounds bfloat, ptr %178, i64 %59
  %180 = load <8 x bfloat>, ptr %179, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  %181 = fpext <8 x bfloat> %180 to <8 x float>
  %182 = fmul contract <8 x float> %181, %161
  %183 = fadd contract <8 x float> %91, %182
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %74, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %184 = insertvalue [2 x ptr] undef, ptr %10, 0
  %185 = insertvalue [2 x ptr] %184, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %185, ptr %9, align 8
  %186 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %187 = load ptr, ptr %186, align 8
  %188 = load i64, ptr %187, align 8
  %189 = trunc i64 %188 to i32
  %190 = getelementptr inbounds ptr, ptr %186, i32 1
  %191 = load ptr, ptr %190, align 8
  %192 = load i64, ptr %191, align 8
  %193 = trunc i64 %192 to i32
  %194 = mul i32 %189, 256
  %195 = mul i32 %193, 256
  %196 = add i32 %194, %195
  %197 = sext i32 %196 to i64
  %198 = getelementptr inbounds bfloat, ptr %25, i64 %197
  %199 = getelementptr inbounds bfloat, ptr %198, i64 %59
  %200 = load <8 x bfloat>, ptr %199, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %201 = fpext <8 x bfloat> %200 to <8 x float>
  %202 = fmul contract <8 x float> %201, %161
  %203 = fadd contract <8 x float> %92, %202
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %69, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %204 = insertvalue [2 x ptr] undef, ptr %8, 0
  %205 = insertvalue [2 x ptr] %204, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %205, ptr %7, align 8
  %206 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %207 = load ptr, ptr %206, align 8
  %208 = load i64, ptr %207, align 8
  %209 = trunc i64 %208 to i32
  %210 = getelementptr inbounds ptr, ptr %206, i32 1
  %211 = load ptr, ptr %210, align 8
  %212 = load i64, ptr %211, align 8
  %213 = trunc i64 %212 to i32
  %214 = mul i32 %209, 256
  %215 = mul i32 %213, 256
  %216 = add i32 %214, %215
  %217 = sext i32 %216 to i64
  %218 = getelementptr inbounds bfloat, ptr %25, i64 %217
  %219 = getelementptr inbounds bfloat, ptr %218, i64 %59
  %220 = load <8 x bfloat>, ptr %219, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %221 = fpext <8 x bfloat> %220 to <8 x float>
  %222 = fmul contract <8 x float> %221, %161
  %223 = fadd contract <8 x float> %93, %222
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %88

224:                                              ; preds = %97
  store bfloat %127, ptr %62, align 2
  br label %226

225:                                              ; preds = %97
  br label %226

226:                                              ; preds = %225, %224
  %227 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %91, i64 0)
  %228 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %91, i64 4)
  %229 = fadd contract <4 x float> %227, %228
  %230 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %229, i64 0)
  %231 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %229, i64 2)
  %232 = fadd contract <2 x float> %230, %231
  %233 = extractelement <2 x float> %232, i64 0
  %234 = extractelement <2 x float> %232, i64 1
  %235 = fadd contract float %233, %234
  %236 = bitcast float %235 to i32
  %237 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %236, i32 16, i32 31)
  %238 = bitcast i32 %237 to float
  %239 = fadd contract float %235, %238
  %240 = bitcast float %239 to i32
  %241 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %240, i32 8, i32 31)
  %242 = bitcast i32 %241 to float
  %243 = fadd contract float %239, %242
  %244 = bitcast float %243 to i32
  %245 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %244, i32 4, i32 31)
  %246 = bitcast i32 %245 to float
  %247 = fadd contract float %243, %246
  %248 = bitcast float %247 to i32
  %249 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %248, i32 2, i32 31)
  %250 = bitcast i32 %249 to float
  %251 = fadd contract float %247, %250
  %252 = bitcast float %251 to i32
  %253 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %252, i32 1, i32 31)
  %254 = bitcast i32 %253 to float
  %255 = fadd contract float %251, %254
  %256 = fptrunc float %255 to bfloat
  br i1 %78, label %257, label %258

257:                                              ; preds = %226
  store bfloat %256, ptr %76, align 2
  br label %259

258:                                              ; preds = %226
  br label %259

259:                                              ; preds = %258, %257
  %260 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %92, i64 0)
  %261 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %92, i64 4)
  %262 = fadd contract <4 x float> %260, %261
  %263 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %262, i64 0)
  %264 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %262, i64 2)
  %265 = fadd contract <2 x float> %263, %264
  %266 = extractelement <2 x float> %265, i64 0
  %267 = extractelement <2 x float> %265, i64 1
  %268 = fadd contract float %266, %267
  %269 = bitcast float %268 to i32
  %270 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %269, i32 16, i32 31)
  %271 = bitcast i32 %270 to float
  %272 = fadd contract float %268, %271
  %273 = bitcast float %272 to i32
  %274 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %273, i32 8, i32 31)
  %275 = bitcast i32 %274 to float
  %276 = fadd contract float %272, %275
  %277 = bitcast float %276 to i32
  %278 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %277, i32 4, i32 31)
  %279 = bitcast i32 %278 to float
  %280 = fadd contract float %276, %279
  %281 = bitcast float %280 to i32
  %282 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %281, i32 2, i32 31)
  %283 = bitcast i32 %282 to float
  %284 = fadd contract float %280, %283
  %285 = bitcast float %284 to i32
  %286 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %285, i32 1, i32 31)
  %287 = bitcast i32 %286 to float
  %288 = fadd contract float %284, %287
  %289 = fptrunc float %288 to bfloat
  br i1 %73, label %290, label %291

290:                                              ; preds = %259
  store bfloat %289, ptr %71, align 2
  br label %292

291:                                              ; preds = %259
  br label %292

292:                                              ; preds = %291, %290
  %293 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %93, i64 0)
  %294 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %93, i64 4)
  %295 = fadd contract <4 x float> %293, %294
  %296 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %295, i64 0)
  %297 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %295, i64 2)
  %298 = fadd contract <2 x float> %296, %297
  %299 = extractelement <2 x float> %298, i64 0
  %300 = extractelement <2 x float> %298, i64 1
  %301 = fadd contract float %299, %300
  %302 = bitcast float %301 to i32
  %303 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %302, i32 16, i32 31)
  %304 = bitcast i32 %303 to float
  %305 = fadd contract float %301, %304
  %306 = bitcast float %305 to i32
  %307 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %306, i32 8, i32 31)
  %308 = bitcast i32 %307 to float
  %309 = fadd contract float %305, %308
  %310 = bitcast float %309 to i32
  %311 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %310, i32 4, i32 31)
  %312 = bitcast i32 %311 to float
  %313 = fadd contract float %309, %312
  %314 = bitcast float %313 to i32
  %315 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %314, i32 2, i32 31)
  %316 = bitcast i32 %315 to float
  %317 = fadd contract float %313, %316
  %318 = bitcast float %317 to i32
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 1, i32 31)
  %320 = bitcast i32 %319 to float
  %321 = fadd contract float %317, %320
  %322 = fptrunc float %321 to bfloat
  br i1 %68, label %323, label %324

323:                                              ; preds = %292
  store bfloat %322, ptr %66, align 2
  br label %325

324:                                              ; preds = %292
  br label %325

325:                                              ; preds = %324, %323
  br label %326

326:                                              ; preds = %325, %82
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
