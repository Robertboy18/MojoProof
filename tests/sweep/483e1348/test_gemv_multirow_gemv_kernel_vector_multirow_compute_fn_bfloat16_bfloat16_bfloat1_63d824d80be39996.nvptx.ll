; ModuleID = 'test_gemv_multirow.mojo'
source_filename = "test_gemv_multirow.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_compute_fn_bfloat16_bfloat16_bfloat16_True_8_4_84ce1531(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca [2 x ptr], i64 1, align 8
  %13 = alloca i64, i64 1, align 8
  %14 = alloca [2 x ptr], i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca [2 x ptr], i64 1, align 8
  %17 = alloca i64, i64 1, align 8
  %18 = alloca i64, i64 1, align 8
  %19 = alloca [2 x ptr], i64 1, align 8
  %20 = alloca i32, i64 1, align 4
  %21 = alloca i32, i64 1, align 4
  %22 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %23 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %24 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %25 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %24, 0
  %26 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %23, 0
  %27 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %22, 0
  %28 = sext i32 %5 to i64
  %29 = sext i32 %3 to i64
  %30 = sub i64 %29, 1
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %34 = zext i32 %33 to i64
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %36 = sext i32 %35 to i64
  %37 = mul i64 %34, %36
  %38 = add i64 %37, %32
  %39 = udiv i64 %38, 32
  %40 = bitcast i64 %39 to <2 x i32>
  %41 = extractelement <2 x i32> %40, i64 0
  %42 = extractelement <2 x i32> %40, i64 1
  %43 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %41, i32 0, i32 31)
  %44 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %42, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i32 %43, ptr %21, align 4
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i32 %44, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  %45 = insertvalue [2 x ptr] undef, ptr %21, 0
  %46 = insertvalue [2 x ptr] %45, ptr %20, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %46, ptr %19, align 8
  %47 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %48 = load ptr, ptr %47, align 8
  %49 = load i32, ptr %48, align 4
  %50 = insertelement <2 x i32> undef, i32 %49, i64 0
  %51 = getelementptr inbounds ptr, ptr %47, i32 1
  %52 = load ptr, ptr %51, align 8
  %53 = load i32, ptr %52, align 4
  %54 = insertelement <2 x i32> %50, i32 %53, i64 1
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %55 = bitcast <2 x i32> %54 to i64
  %56 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %57 = sext i32 %56 to i64
  %58 = trunc i64 %57 to i32
  %59 = mul i32 %58, 8
  %60 = sext i32 %59 to i64
  %61 = icmp eq i64 %57, 0
  %62 = mul i64 %55, 4
  %63 = trunc i64 %62 to i32
  %64 = sext i32 %63 to i64
  %65 = getelementptr inbounds bfloat, ptr %25, i64 %64
  %66 = icmp slt i64 %62, %29
  %67 = select i1 %61, i1 %66, i1 false
  %68 = add i64 %62, 3
  %69 = trunc i64 %68 to i32
  %70 = sext i32 %69 to i64
  %71 = getelementptr inbounds bfloat, ptr %25, i64 %70
  %72 = icmp slt i64 %68, %29
  %73 = select i1 %61, i1 %72, i1 false
  %74 = call i64 @llvm.smin.i64(i64 %68, i64 %30)
  %75 = add i64 %62, 2
  %76 = trunc i64 %75 to i32
  %77 = sext i32 %76 to i64
  %78 = getelementptr inbounds bfloat, ptr %25, i64 %77
  %79 = icmp slt i64 %75, %29
  %80 = select i1 %61, i1 %79, i1 false
  %81 = call i64 @llvm.smin.i64(i64 %75, i64 %30)
  %82 = add i64 %62, 1
  %83 = trunc i64 %82 to i32
  %84 = sext i32 %83 to i64
  %85 = getelementptr inbounds bfloat, ptr %25, i64 %84
  %86 = icmp slt i64 %82, %29
  %87 = select i1 %61, i1 %86, i1 false
  %88 = call i64 @llvm.smin.i64(i64 %82, i64 %30)
  %89 = call i64 @llvm.smin.i64(i64 %62, i64 %30)
  %90 = icmp sge i64 %62, %29
  br i1 %90, label %91, label %92

91:                                               ; preds = %7
  br label %358

92:                                               ; preds = %7
  %93 = udiv i64 %28, 256
  %94 = add i64 %93, 1
  %95 = sub i64 %94, 1
  %96 = call i64 @llvm.smax.i64(i64 %95, i64 0)
  br label %97

97:                                               ; preds = %137, %92
  %98 = phi i64 [ 0, %92 ], [ %105, %137 ]
  %99 = phi <8 x float> [ zeroinitializer, %92 ], [ %175, %137 ]
  %100 = phi <8 x float> [ zeroinitializer, %92 ], [ %195, %137 ]
  %101 = phi <8 x float> [ zeroinitializer, %92 ], [ %215, %137 ]
  %102 = phi <8 x float> [ zeroinitializer, %92 ], [ %235, %137 ]
  call void @llvm.lifetime.end.p0(ptr %18)
  %103 = icmp eq i64 %98, %96
  %104 = add i64 %98, 1
  %105 = select i1 %103, i64 %98, i64 %104
  br i1 %103, label %106, label %137

106:                                              ; preds = %97
  %107 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %99, i64 0)
  %108 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %99, i64 4)
  %109 = fadd contract <4 x float> %107, %108
  %110 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %109, i64 0)
  %111 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %109, i64 2)
  %112 = fadd contract <2 x float> %110, %111
  %113 = extractelement <2 x float> %112, i64 0
  %114 = extractelement <2 x float> %112, i64 1
  %115 = fadd contract float %113, %114
  %116 = bitcast float %115 to i32
  %117 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %116, i32 16, i32 31)
  %118 = bitcast i32 %117 to float
  %119 = fadd contract float %115, %118
  %120 = bitcast float %119 to i32
  %121 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %120, i32 8, i32 31)
  %122 = bitcast i32 %121 to float
  %123 = fadd contract float %119, %122
  %124 = bitcast float %123 to i32
  %125 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %124, i32 4, i32 31)
  %126 = bitcast i32 %125 to float
  %127 = fadd contract float %123, %126
  %128 = bitcast float %127 to i32
  %129 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %128, i32 2, i32 31)
  %130 = bitcast i32 %129 to float
  %131 = fadd contract float %127, %130
  %132 = bitcast float %131 to i32
  %133 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %132, i32 1, i32 31)
  %134 = bitcast i32 %133 to float
  %135 = fadd contract float %131, %134
  %136 = fptrunc float %135 to bfloat
  br i1 %67, label %236, label %242

137:                                              ; preds = %97
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %98, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %138 = insertvalue [2 x ptr] undef, ptr %17, 0
  %139 = insertvalue [2 x ptr] %138, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %139, ptr %16, align 8
  %140 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %141 = load ptr, ptr %140, align 8
  %142 = load i64, ptr %141, align 8
  %143 = trunc i64 %142 to i32
  %144 = getelementptr inbounds ptr, ptr %140, i32 1
  %145 = load ptr, ptr %144, align 8
  %146 = load i64, ptr %145, align 8
  %147 = trunc i64 %146 to i32
  %148 = mul i32 %143, 256
  %149 = mul i32 %147, 256
  %150 = add i32 %148, %149
  %151 = sext i32 %150 to i64
  %152 = getelementptr inbounds bfloat, ptr %27, i64 %151
  %153 = getelementptr inbounds bfloat, ptr %152, i64 %60
  %154 = load <8 x bfloat>, ptr %153, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %89, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %155 = insertvalue [2 x ptr] undef, ptr %15, 0
  %156 = insertvalue [2 x ptr] %155, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %156, ptr %14, align 8
  %157 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %158 = load ptr, ptr %157, align 8
  %159 = load i64, ptr %158, align 8
  %160 = trunc i64 %159 to i32
  %161 = getelementptr inbounds ptr, ptr %157, i32 1
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = trunc i64 %163 to i32
  %165 = mul i32 %160, 256
  %166 = mul i32 %164, 256
  %167 = add i32 %165, %166
  %168 = sext i32 %167 to i64
  %169 = getelementptr inbounds bfloat, ptr %26, i64 %168
  %170 = getelementptr inbounds bfloat, ptr %169, i64 %60
  %171 = load <8 x bfloat>, ptr %170, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %172 = fpext <8 x bfloat> %171 to <8 x float>
  %173 = fpext <8 x bfloat> %154 to <8 x float>
  %174 = fmul contract <8 x float> %172, %173
  %175 = fadd contract <8 x float> %99, %174
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %88, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %176 = insertvalue [2 x ptr] undef, ptr %13, 0
  %177 = insertvalue [2 x ptr] %176, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %177, ptr %12, align 8
  %178 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %179 = load ptr, ptr %178, align 8
  %180 = load i64, ptr %179, align 8
  %181 = trunc i64 %180 to i32
  %182 = getelementptr inbounds ptr, ptr %178, i32 1
  %183 = load ptr, ptr %182, align 8
  %184 = load i64, ptr %183, align 8
  %185 = trunc i64 %184 to i32
  %186 = mul i32 %181, 256
  %187 = mul i32 %185, 256
  %188 = add i32 %186, %187
  %189 = sext i32 %188 to i64
  %190 = getelementptr inbounds bfloat, ptr %26, i64 %189
  %191 = getelementptr inbounds bfloat, ptr %190, i64 %60
  %192 = load <8 x bfloat>, ptr %191, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  %193 = fpext <8 x bfloat> %192 to <8 x float>
  %194 = fmul contract <8 x float> %193, %173
  %195 = fadd contract <8 x float> %100, %194
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %81, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %196 = insertvalue [2 x ptr] undef, ptr %11, 0
  %197 = insertvalue [2 x ptr] %196, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %197, ptr %10, align 8
  %198 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %199 = load ptr, ptr %198, align 8
  %200 = load i64, ptr %199, align 8
  %201 = trunc i64 %200 to i32
  %202 = getelementptr inbounds ptr, ptr %198, i32 1
  %203 = load ptr, ptr %202, align 8
  %204 = load i64, ptr %203, align 8
  %205 = trunc i64 %204 to i32
  %206 = mul i32 %201, 256
  %207 = mul i32 %205, 256
  %208 = add i32 %206, %207
  %209 = sext i32 %208 to i64
  %210 = getelementptr inbounds bfloat, ptr %26, i64 %209
  %211 = getelementptr inbounds bfloat, ptr %210, i64 %60
  %212 = load <8 x bfloat>, ptr %211, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %213 = fpext <8 x bfloat> %212 to <8 x float>
  %214 = fmul contract <8 x float> %213, %173
  %215 = fadd contract <8 x float> %101, %214
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %74, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %216 = insertvalue [2 x ptr] undef, ptr %9, 0
  %217 = insertvalue [2 x ptr] %216, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %217, ptr %8, align 8
  %218 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %219 = load ptr, ptr %218, align 8
  %220 = load i64, ptr %219, align 8
  %221 = trunc i64 %220 to i32
  %222 = getelementptr inbounds ptr, ptr %218, i32 1
  %223 = load ptr, ptr %222, align 8
  %224 = load i64, ptr %223, align 8
  %225 = trunc i64 %224 to i32
  %226 = mul i32 %221, 256
  %227 = mul i32 %225, 256
  %228 = add i32 %226, %227
  %229 = sext i32 %228 to i64
  %230 = getelementptr inbounds bfloat, ptr %26, i64 %229
  %231 = getelementptr inbounds bfloat, ptr %230, i64 %60
  %232 = load <8 x bfloat>, ptr %231, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %233 = fpext <8 x bfloat> %232 to <8 x float>
  %234 = fmul contract <8 x float> %233, %173
  %235 = fadd contract <8 x float> %102, %234
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %97

236:                                              ; preds = %106
  %237 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %238 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %237, 0
  %239 = getelementptr inbounds bfloat, ptr %238, i64 %64
  %240 = load bfloat, ptr %239, align 2, !invariant.load !1
  %241 = fadd contract bfloat %136, %240
  store bfloat %241, ptr %65, align 2
  br label %243

242:                                              ; preds = %106
  br label %243

243:                                              ; preds = %242, %236
  %244 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %100, i64 0)
  %245 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %100, i64 4)
  %246 = fadd contract <4 x float> %244, %245
  %247 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %246, i64 0)
  %248 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %246, i64 2)
  %249 = fadd contract <2 x float> %247, %248
  %250 = extractelement <2 x float> %249, i64 0
  %251 = extractelement <2 x float> %249, i64 1
  %252 = fadd contract float %250, %251
  %253 = bitcast float %252 to i32
  %254 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %253, i32 16, i32 31)
  %255 = bitcast i32 %254 to float
  %256 = fadd contract float %252, %255
  %257 = bitcast float %256 to i32
  %258 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %257, i32 8, i32 31)
  %259 = bitcast i32 %258 to float
  %260 = fadd contract float %256, %259
  %261 = bitcast float %260 to i32
  %262 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %261, i32 4, i32 31)
  %263 = bitcast i32 %262 to float
  %264 = fadd contract float %260, %263
  %265 = bitcast float %264 to i32
  %266 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %265, i32 2, i32 31)
  %267 = bitcast i32 %266 to float
  %268 = fadd contract float %264, %267
  %269 = bitcast float %268 to i32
  %270 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %269, i32 1, i32 31)
  %271 = bitcast i32 %270 to float
  %272 = fadd contract float %268, %271
  %273 = fptrunc float %272 to bfloat
  br i1 %87, label %274, label %280

274:                                              ; preds = %243
  %275 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %276 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %275, 0
  %277 = getelementptr inbounds bfloat, ptr %276, i64 %84
  %278 = load bfloat, ptr %277, align 2, !invariant.load !1
  %279 = fadd contract bfloat %273, %278
  store bfloat %279, ptr %85, align 2
  br label %281

280:                                              ; preds = %243
  br label %281

281:                                              ; preds = %280, %274
  %282 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %101, i64 0)
  %283 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %101, i64 4)
  %284 = fadd contract <4 x float> %282, %283
  %285 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %284, i64 0)
  %286 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %284, i64 2)
  %287 = fadd contract <2 x float> %285, %286
  %288 = extractelement <2 x float> %287, i64 0
  %289 = extractelement <2 x float> %287, i64 1
  %290 = fadd contract float %288, %289
  %291 = bitcast float %290 to i32
  %292 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %291, i32 16, i32 31)
  %293 = bitcast i32 %292 to float
  %294 = fadd contract float %290, %293
  %295 = bitcast float %294 to i32
  %296 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %295, i32 8, i32 31)
  %297 = bitcast i32 %296 to float
  %298 = fadd contract float %294, %297
  %299 = bitcast float %298 to i32
  %300 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %299, i32 4, i32 31)
  %301 = bitcast i32 %300 to float
  %302 = fadd contract float %298, %301
  %303 = bitcast float %302 to i32
  %304 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %303, i32 2, i32 31)
  %305 = bitcast i32 %304 to float
  %306 = fadd contract float %302, %305
  %307 = bitcast float %306 to i32
  %308 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %307, i32 1, i32 31)
  %309 = bitcast i32 %308 to float
  %310 = fadd contract float %306, %309
  %311 = fptrunc float %310 to bfloat
  br i1 %80, label %312, label %318

312:                                              ; preds = %281
  %313 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %314 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %313, 0
  %315 = getelementptr inbounds bfloat, ptr %314, i64 %77
  %316 = load bfloat, ptr %315, align 2, !invariant.load !1
  %317 = fadd contract bfloat %311, %316
  store bfloat %317, ptr %78, align 2
  br label %319

318:                                              ; preds = %281
  br label %319

319:                                              ; preds = %318, %312
  %320 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %102, i64 0)
  %321 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %102, i64 4)
  %322 = fadd contract <4 x float> %320, %321
  %323 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %322, i64 0)
  %324 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %322, i64 2)
  %325 = fadd contract <2 x float> %323, %324
  %326 = extractelement <2 x float> %325, i64 0
  %327 = extractelement <2 x float> %325, i64 1
  %328 = fadd contract float %326, %327
  %329 = bitcast float %328 to i32
  %330 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %329, i32 16, i32 31)
  %331 = bitcast i32 %330 to float
  %332 = fadd contract float %328, %331
  %333 = bitcast float %332 to i32
  %334 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %333, i32 8, i32 31)
  %335 = bitcast i32 %334 to float
  %336 = fadd contract float %332, %335
  %337 = bitcast float %336 to i32
  %338 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %337, i32 4, i32 31)
  %339 = bitcast i32 %338 to float
  %340 = fadd contract float %336, %339
  %341 = bitcast float %340 to i32
  %342 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %341, i32 2, i32 31)
  %343 = bitcast i32 %342 to float
  %344 = fadd contract float %340, %343
  %345 = bitcast float %344 to i32
  %346 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %345, i32 1, i32 31)
  %347 = bitcast i32 %346 to float
  %348 = fadd contract float %344, %347
  %349 = fptrunc float %348 to bfloat
  br i1 %73, label %350, label %356

350:                                              ; preds = %319
  %351 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %352 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %351, 0
  %353 = getelementptr inbounds bfloat, ptr %352, i64 %70
  %354 = load bfloat, ptr %353, align 2, !invariant.load !1
  %355 = fadd contract bfloat %349, %354
  store bfloat %355, ptr %71, align 2
  br label %357

356:                                              ; preds = %319
  br label %357

357:                                              ; preds = %356, %350
  br label %358

358:                                              ; preds = %357, %91
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
