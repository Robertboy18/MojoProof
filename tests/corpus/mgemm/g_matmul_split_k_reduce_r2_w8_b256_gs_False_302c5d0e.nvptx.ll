; ModuleID = 'test_multistage_gemm_kernel.mojo'
source_filename = "test_multistage_gemm_kernel.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w8_b256_gs_False_302c5d0e(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
  %2 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 0
  %3 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 4
  %4 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 1
  %5 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 0
  %6 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 1
  %7 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 4
  %8 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %9 = zext i32 %8 to i64
  %10 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %11 = zext i32 %10 to i64
  %12 = mul i64 %11, 256
  %13 = add i64 %9, %12
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %15 = sext i32 %14 to i64
  %16 = mul i64 %15, 256
  %17 = mul i64 %16, 3
  %18 = mul i64 %16, 2
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %19 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 2
  %20 = mul i64 %16, 4
  %21 = load i64, ptr %19, align 8
  %22 = icmp eq i64 %20, 0
  %23 = select i1 %22, i64 0, i64 %13
  %24 = select i1 %22, i64 0, i64 %21
  %25 = select i1 %22, i64 1, i64 %20
  %26 = icmp slt i64 %25, 0
  %27 = icmp sgt i64 %25, 0
  br label %28

28:                                               ; preds = %300, %1
  %29 = phi i64 [ %23, %1 ], [ %53, %300 ]
  %30 = phi i64 [ 0, %1 ], [ %54, %300 ]
  %31 = icmp sge i64 %24, %29
  %32 = icmp sge i64 %29, %24
  %33 = add i64 %29, %25
  %34 = icmp slt i64 %33, %29
  %35 = xor i1 %34, %26
  %36 = select i1 %35, i64 1, i64 0
  %37 = icmp eq i64 %30, 0
  %38 = xor i1 %37, true
  %39 = or i1 %38, %31
  %40 = or i1 %38, %32
  br label %41

41:                                               ; preds = %28
  br i1 %27, label %42, label %47

42:                                               ; preds = %41
  br i1 %40, label %43, label %44

43:                                               ; preds = %42
  br label %50

44:                                               ; preds = %42
  br label %45

45:                                               ; preds = %44
  br label %49

46:                                               ; preds = %47
  br label %49

47:                                               ; preds = %41
  br i1 %39, label %48, label %46

48:                                               ; preds = %47
  br label %50

49:                                               ; preds = %46, %45
  br label %50

50:                                               ; preds = %49, %48, %43
  %51 = phi i1 [ true, %43 ], [ true, %48 ], [ false, %49 ]
  %52 = phi i64 [ undef, %43 ], [ undef, %48 ], [ %29, %49 ]
  %53 = phi i64 [ %29, %43 ], [ %29, %48 ], [ %33, %49 ]
  %54 = phi i64 [ %30, %43 ], [ %30, %48 ], [ %36, %49 ]
  %55 = mul i64 %52, 8
  %56 = icmp slt i64 %55, 0
  br i1 %51, label %57, label %58

57:                                               ; preds = %50
  br label %301

58:                                               ; preds = %50
  br label %59

59:                                               ; preds = %58
  %60 = load i64, ptr %19, align 8
  %61 = icmp slt i64 %52, %60
  br i1 %61, label %62, label %116

62:                                               ; preds = %59
  %63 = load { i64, i64 }, ptr %6, align 8
  %64 = extractvalue { i64, i64 } %63, 1
  %65 = icmp eq i64 %64, 0
  %66 = select i1 %65, i64 1, i64 %64
  %67 = sdiv i64 %55, %66
  %68 = mul i64 %67, %64
  %69 = sub i64 %55, %68
  %70 = icmp slt i64 %64, 0
  %71 = xor i1 %70, %56
  %72 = icmp ne i64 %69, 0
  %73 = and i1 %71, %72
  %74 = select i1 %73, i64 1, i64 0
  %75 = sub i64 %67, %74
  %76 = select i1 %65, i64 0, i64 %75
  %77 = select i1 %73, i64 %64, i64 0
  %78 = add i64 %69, %77
  %79 = select i1 %65, i64 0, i64 %78
  %80 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %81 = load i64, ptr %4, align 8
  %82 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %83 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %80, 0
  %84 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %80, 1, 1, 0
  %85 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %80, 1, 1, 1
  %86 = mul i64 %76, %85
  %87 = add i64 %86, %79
  %88 = getelementptr inbounds bfloat, ptr %83, i64 %87
  %89 = load <8 x bfloat>, ptr %88, align 16, !invariant.load !1
  %90 = call i64 @llvm.smax.i64(i64 %81, i64 1)
  br label %91

91:                                               ; preds = %97, %62
  %92 = phi i64 [ 1, %62 ], [ %100, %97 ]
  %93 = phi <8 x bfloat> [ %89, %62 ], [ %106, %97 ]
  %94 = icmp slt i64 %92, %90
  br i1 %94, label %95, label %96

95:                                               ; preds = %91
  br label %97

96:                                               ; preds = %91
  br label %107

97:                                               ; preds = %95
  %98 = icmp eq i64 %92, %90
  %99 = add i64 %92, 1
  %100 = select i1 %98, i64 %92, i64 %99
  %101 = mul i64 %92, %84
  %102 = add i64 %101, %86
  %103 = add i64 %102, %79
  %104 = getelementptr inbounds bfloat, ptr %83, i64 %103
  %105 = load <8 x bfloat>, ptr %104, align 16, !invariant.load !1
  %106 = fadd contract <8 x bfloat> %93, %105
  br label %91

107:                                              ; preds = %96
  %108 = phi <8 x bfloat> [ %93, %96 ]
  %109 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %82, 0
  %110 = trunc i64 %76 to i32
  %111 = mul i32 %110, 512
  %112 = trunc i64 %79 to i32
  %113 = add i32 %111, %112
  %114 = sext i32 %113 to i64
  %115 = getelementptr inbounds bfloat, ptr %109, i64 %114
  store <8 x bfloat> %108, ptr %115, align 16
  br label %117

116:                                              ; preds = %59
  br label %117

117:                                              ; preds = %116, %107
  %118 = add i64 %52, %16
  %119 = mul i64 %118, 8
  %120 = icmp slt i64 %119, 0
  %121 = load i64, ptr %19, align 8
  %122 = icmp slt i64 %118, %121
  br i1 %122, label %123, label %177

123:                                              ; preds = %117
  %124 = load { i64, i64 }, ptr %6, align 8
  %125 = extractvalue { i64, i64 } %124, 1
  %126 = icmp eq i64 %125, 0
  %127 = select i1 %126, i64 1, i64 %125
  %128 = sdiv i64 %119, %127
  %129 = mul i64 %128, %125
  %130 = sub i64 %119, %129
  %131 = icmp slt i64 %125, 0
  %132 = xor i1 %131, %120
  %133 = icmp ne i64 %130, 0
  %134 = and i1 %132, %133
  %135 = select i1 %134, i64 1, i64 0
  %136 = sub i64 %128, %135
  %137 = select i1 %126, i64 0, i64 %136
  %138 = select i1 %134, i64 %125, i64 0
  %139 = add i64 %130, %138
  %140 = select i1 %126, i64 0, i64 %139
  %141 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %142 = load i64, ptr %4, align 8
  %143 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %144 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %141, 0
  %145 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %141, 1, 1, 0
  %146 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %141, 1, 1, 1
  %147 = mul i64 %137, %146
  %148 = add i64 %147, %140
  %149 = getelementptr inbounds bfloat, ptr %144, i64 %148
  %150 = load <8 x bfloat>, ptr %149, align 16, !invariant.load !1
  %151 = call i64 @llvm.smax.i64(i64 %142, i64 1)
  br label %152

152:                                              ; preds = %158, %123
  %153 = phi i64 [ 1, %123 ], [ %161, %158 ]
  %154 = phi <8 x bfloat> [ %150, %123 ], [ %167, %158 ]
  %155 = icmp slt i64 %153, %151
  br i1 %155, label %156, label %157

156:                                              ; preds = %152
  br label %158

157:                                              ; preds = %152
  br label %168

158:                                              ; preds = %156
  %159 = icmp eq i64 %153, %151
  %160 = add i64 %153, 1
  %161 = select i1 %159, i64 %153, i64 %160
  %162 = mul i64 %153, %145
  %163 = add i64 %162, %147
  %164 = add i64 %163, %140
  %165 = getelementptr inbounds bfloat, ptr %144, i64 %164
  %166 = load <8 x bfloat>, ptr %165, align 16, !invariant.load !1
  %167 = fadd contract <8 x bfloat> %154, %166
  br label %152

168:                                              ; preds = %157
  %169 = phi <8 x bfloat> [ %154, %157 ]
  %170 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %143, 0
  %171 = trunc i64 %137 to i32
  %172 = mul i32 %171, 512
  %173 = trunc i64 %140 to i32
  %174 = add i32 %172, %173
  %175 = sext i32 %174 to i64
  %176 = getelementptr inbounds bfloat, ptr %170, i64 %175
  store <8 x bfloat> %169, ptr %176, align 16
  br label %178

177:                                              ; preds = %117
  br label %178

178:                                              ; preds = %177, %168
  %179 = add i64 %52, %18
  %180 = mul i64 %179, 8
  %181 = icmp slt i64 %180, 0
  %182 = load i64, ptr %19, align 8
  %183 = icmp slt i64 %179, %182
  br i1 %183, label %184, label %238

184:                                              ; preds = %178
  %185 = load { i64, i64 }, ptr %6, align 8
  %186 = extractvalue { i64, i64 } %185, 1
  %187 = icmp eq i64 %186, 0
  %188 = select i1 %187, i64 1, i64 %186
  %189 = sdiv i64 %180, %188
  %190 = mul i64 %189, %186
  %191 = sub i64 %180, %190
  %192 = icmp slt i64 %186, 0
  %193 = xor i1 %192, %181
  %194 = icmp ne i64 %191, 0
  %195 = and i1 %193, %194
  %196 = select i1 %195, i64 1, i64 0
  %197 = sub i64 %189, %196
  %198 = select i1 %187, i64 0, i64 %197
  %199 = select i1 %195, i64 %186, i64 0
  %200 = add i64 %191, %199
  %201 = select i1 %187, i64 0, i64 %200
  %202 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %203 = load i64, ptr %4, align 8
  %204 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %205 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %202, 0
  %206 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %202, 1, 1, 0
  %207 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %202, 1, 1, 1
  %208 = mul i64 %198, %207
  %209 = add i64 %208, %201
  %210 = getelementptr inbounds bfloat, ptr %205, i64 %209
  %211 = load <8 x bfloat>, ptr %210, align 16, !invariant.load !1
  %212 = call i64 @llvm.smax.i64(i64 %203, i64 1)
  br label %213

213:                                              ; preds = %219, %184
  %214 = phi i64 [ 1, %184 ], [ %222, %219 ]
  %215 = phi <8 x bfloat> [ %211, %184 ], [ %228, %219 ]
  %216 = icmp slt i64 %214, %212
  br i1 %216, label %217, label %218

217:                                              ; preds = %213
  br label %219

218:                                              ; preds = %213
  br label %229

219:                                              ; preds = %217
  %220 = icmp eq i64 %214, %212
  %221 = add i64 %214, 1
  %222 = select i1 %220, i64 %214, i64 %221
  %223 = mul i64 %214, %206
  %224 = add i64 %223, %208
  %225 = add i64 %224, %201
  %226 = getelementptr inbounds bfloat, ptr %205, i64 %225
  %227 = load <8 x bfloat>, ptr %226, align 16, !invariant.load !1
  %228 = fadd contract <8 x bfloat> %215, %227
  br label %213

229:                                              ; preds = %218
  %230 = phi <8 x bfloat> [ %215, %218 ]
  %231 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %204, 0
  %232 = trunc i64 %198 to i32
  %233 = mul i32 %232, 512
  %234 = trunc i64 %201 to i32
  %235 = add i32 %233, %234
  %236 = sext i32 %235 to i64
  %237 = getelementptr inbounds bfloat, ptr %231, i64 %236
  store <8 x bfloat> %230, ptr %237, align 16
  br label %239

238:                                              ; preds = %178
  br label %239

239:                                              ; preds = %238, %229
  %240 = add i64 %52, %17
  %241 = mul i64 %240, 8
  %242 = icmp slt i64 %241, 0
  %243 = load i64, ptr %19, align 8
  %244 = icmp slt i64 %240, %243
  br i1 %244, label %245, label %299

245:                                              ; preds = %239
  %246 = load { i64, i64 }, ptr %6, align 8
  %247 = extractvalue { i64, i64 } %246, 1
  %248 = icmp eq i64 %247, 0
  %249 = select i1 %248, i64 1, i64 %247
  %250 = sdiv i64 %241, %249
  %251 = mul i64 %250, %247
  %252 = sub i64 %241, %251
  %253 = icmp slt i64 %247, 0
  %254 = xor i1 %253, %242
  %255 = icmp ne i64 %252, 0
  %256 = and i1 %254, %255
  %257 = select i1 %256, i64 1, i64 0
  %258 = sub i64 %250, %257
  %259 = select i1 %248, i64 0, i64 %258
  %260 = select i1 %256, i64 %247, i64 0
  %261 = add i64 %252, %260
  %262 = select i1 %248, i64 0, i64 %261
  %263 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %264 = load i64, ptr %4, align 8
  %265 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %266 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %263, 0
  %267 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %263, 1, 1, 0
  %268 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %263, 1, 1, 1
  %269 = mul i64 %259, %268
  %270 = add i64 %269, %262
  %271 = getelementptr inbounds bfloat, ptr %266, i64 %270
  %272 = load <8 x bfloat>, ptr %271, align 16, !invariant.load !1
  %273 = call i64 @llvm.smax.i64(i64 %264, i64 1)
  br label %274

274:                                              ; preds = %280, %245
  %275 = phi i64 [ 1, %245 ], [ %283, %280 ]
  %276 = phi <8 x bfloat> [ %272, %245 ], [ %289, %280 ]
  %277 = icmp slt i64 %275, %273
  br i1 %277, label %278, label %279

278:                                              ; preds = %274
  br label %280

279:                                              ; preds = %274
  br label %290

280:                                              ; preds = %278
  %281 = icmp eq i64 %275, %273
  %282 = add i64 %275, 1
  %283 = select i1 %281, i64 %275, i64 %282
  %284 = mul i64 %275, %267
  %285 = add i64 %284, %269
  %286 = add i64 %285, %262
  %287 = getelementptr inbounds bfloat, ptr %266, i64 %286
  %288 = load <8 x bfloat>, ptr %287, align 16, !invariant.load !1
  %289 = fadd contract <8 x bfloat> %276, %288
  br label %274

290:                                              ; preds = %279
  %291 = phi <8 x bfloat> [ %276, %279 ]
  %292 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %265, 0
  %293 = trunc i64 %259 to i32
  %294 = mul i32 %293, 512
  %295 = trunc i64 %262 to i32
  %296 = add i32 %294, %295
  %297 = sext i32 %296 to i64
  %298 = getelementptr inbounds bfloat, ptr %292, i64 %297
  store <8 x bfloat> %291, ptr %298, align 16
  br label %300

299:                                              ; preds = %239
  br label %300

300:                                              ; preds = %299, %290
  br label %28

301:                                              ; preds = %57
  %302 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %303 = load i64, ptr %302, align 8
  %304 = icmp slt i64 %13, %303
  br i1 %304, label %305, label %362

305:                                              ; preds = %301
  %306 = load i64, ptr %7, align 8
  %307 = add i64 %306, %13
  %308 = load { i64, i64 }, ptr %6, align 8
  %309 = extractvalue { i64, i64 } %308, 1
  %310 = icmp eq i64 %309, 0
  %311 = select i1 %310, i64 1, i64 %309
  %312 = sdiv i64 %307, %311
  %313 = mul i64 %312, %309
  %314 = sub i64 %307, %313
  %315 = icmp slt i64 %309, 0
  %316 = icmp slt i64 %307, 0
  %317 = xor i1 %315, %316
  %318 = icmp ne i64 %314, 0
  %319 = and i1 %317, %318
  %320 = select i1 %319, i64 1, i64 0
  %321 = sub i64 %312, %320
  %322 = select i1 %310, i64 0, i64 %321
  %323 = select i1 %319, i64 %309, i64 0
  %324 = add i64 %314, %323
  %325 = select i1 %310, i64 0, i64 %324
  %326 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %327 = load i64, ptr %4, align 8
  %328 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %329 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %326, 0
  %330 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %326, 1, 1, 0
  %331 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %326, 1, 1, 1
  %332 = mul i64 %322, %331
  %333 = add i64 %332, %325
  %334 = getelementptr inbounds bfloat, ptr %329, i64 %333
  %335 = load bfloat, ptr %334, align 2, !invariant.load !1
  %336 = call i64 @llvm.smax.i64(i64 %327, i64 1)
  br label %337

337:                                              ; preds = %343, %305
  %338 = phi i64 [ 1, %305 ], [ %346, %343 ]
  %339 = phi bfloat [ %335, %305 ], [ %352, %343 ]
  %340 = icmp slt i64 %338, %336
  br i1 %340, label %341, label %342

341:                                              ; preds = %337
  br label %343

342:                                              ; preds = %337
  br label %353

343:                                              ; preds = %341
  %344 = icmp eq i64 %338, %336
  %345 = add i64 %338, 1
  %346 = select i1 %344, i64 %338, i64 %345
  %347 = mul i64 %338, %330
  %348 = add i64 %347, %332
  %349 = add i64 %348, %325
  %350 = getelementptr inbounds bfloat, ptr %329, i64 %349
  %351 = load bfloat, ptr %350, align 2, !invariant.load !1
  %352 = fadd contract bfloat %339, %351
  br label %337

353:                                              ; preds = %342
  %354 = phi bfloat [ %339, %342 ]
  %355 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %328, 0
  %356 = trunc i64 %322 to i32
  %357 = mul i32 %356, 512
  %358 = trunc i64 %325 to i32
  %359 = add i32 %357, %358
  %360 = sext i32 %359 to i64
  %361 = getelementptr inbounds bfloat, ptr %355, i64 %360
  store bfloat %354, ptr %361, align 2
  br label %363

362:                                              ; preds = %301
  br label %363

363:                                              ; preds = %362, %353
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  ret void
}

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.wait() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, -2147483648) i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.launch.dependents() #2

attributes #0 = { noinline "target-cpu"="sm_90a" "target-features"="+ptx85,+sm_90a" "tune-cpu"="sm_90a" }
attributes #1 = { norecurse "nvvm.maxntid"="256" "target-cpu"="sm_90a" "target-features"="+ptx85,+sm_90a" "tune-cpu"="sm_90a" }
attributes #2 = { nounwind }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
