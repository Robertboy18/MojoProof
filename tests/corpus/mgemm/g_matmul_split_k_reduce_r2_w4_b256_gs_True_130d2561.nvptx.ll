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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w4_b256_gs_True_130d2561(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
  %2 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 0
  %3 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 4
  %4 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 1
  %5 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 0
  %6 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 1
  %7 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 4
  %8 = getelementptr { i64, i64 }, ptr %6, i32 0, i32 1
  %9 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %10 = zext i32 %9 to i64
  %11 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %12 = zext i32 %11 to i64
  %13 = mul i64 %12, 256
  %14 = add i64 %10, %13
  %15 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %16 = sext i32 %15 to i64
  %17 = mul i64 %16, 256
  %18 = mul i64 %17, 3
  %19 = mul i64 %17, 2
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %20 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 2
  %21 = mul i64 %17, 4
  %22 = load i64, ptr %20, align 8
  %23 = icmp eq i64 %21, 0
  %24 = select i1 %23, i64 0, i64 %14
  %25 = select i1 %23, i64 0, i64 %22
  %26 = select i1 %23, i64 1, i64 %21
  %27 = icmp slt i64 %26, 0
  %28 = icmp sgt i64 %26, 0
  br label %29

29:                                               ; preds = %965, %1
  %30 = phi i64 [ %24, %1 ], [ %54, %965 ]
  %31 = phi i64 [ 0, %1 ], [ %55, %965 ]
  %32 = icmp sge i64 %25, %30
  %33 = icmp sge i64 %30, %25
  %34 = add i64 %30, %26
  %35 = icmp slt i64 %34, %30
  %36 = xor i1 %35, %27
  %37 = select i1 %36, i64 1, i64 0
  %38 = icmp eq i64 %31, 0
  %39 = xor i1 %38, true
  %40 = or i1 %39, %32
  %41 = or i1 %39, %33
  br label %42

42:                                               ; preds = %29
  br i1 %28, label %43, label %48

43:                                               ; preds = %42
  br i1 %41, label %44, label %45

44:                                               ; preds = %43
  br label %51

45:                                               ; preds = %43
  br label %46

46:                                               ; preds = %45
  br label %50

47:                                               ; preds = %48
  br label %50

48:                                               ; preds = %42
  br i1 %40, label %49, label %47

49:                                               ; preds = %48
  br label %51

50:                                               ; preds = %47, %46
  br label %51

51:                                               ; preds = %50, %49, %44
  %52 = phi i1 [ true, %44 ], [ true, %49 ], [ false, %50 ]
  %53 = phi i64 [ undef, %44 ], [ undef, %49 ], [ %30, %50 ]
  %54 = phi i64 [ %30, %44 ], [ %30, %49 ], [ %34, %50 ]
  %55 = phi i64 [ %31, %44 ], [ %31, %49 ], [ %37, %50 ]
  %56 = mul i64 %53, 4
  %57 = icmp slt i64 %56, 0
  br i1 %52, label %58, label %59

58:                                               ; preds = %51
  br label %966

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59
  %61 = load i64, ptr %20, align 8
  %62 = icmp slt i64 %53, %61
  br i1 %62, label %63, label %283

63:                                               ; preds = %60
  %64 = load { i64, i64 }, ptr %6, align 8
  %65 = extractvalue { i64, i64 } %64, 1
  %66 = icmp eq i64 %65, 0
  %67 = select i1 %66, i64 1, i64 %65
  %68 = sdiv i64 %56, %67
  %69 = mul i64 %68, %65
  %70 = sub i64 %56, %69
  %71 = icmp slt i64 %65, 0
  %72 = xor i1 %71, %57
  %73 = icmp ne i64 %70, 0
  %74 = and i1 %72, %73
  %75 = select i1 %74, i64 1, i64 0
  %76 = sub i64 %68, %75
  %77 = select i1 %66, i64 0, i64 %76
  %78 = trunc i64 %77 to i32
  %79 = mul i32 %78, 512
  %80 = add i64 %77, 1
  %81 = select i1 %74, i64 %65, i64 0
  %82 = add i64 %70, %81
  %83 = select i1 %66, i64 0, i64 %82
  %84 = trunc i64 %83 to i32
  %85 = add i32 %79, %84
  %86 = sext i32 %85 to i64
  %87 = add i64 %83, 1
  %88 = add i64 %83, 4
  %89 = load i64, ptr %8, align 8
  %90 = icmp sgt i64 %88, %89
  br i1 %90, label %91, label %250

91:                                               ; preds = %63
  %92 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %93 = load i64, ptr %4, align 8
  %94 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %95 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 0
  %96 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 1, 1, 0
  %97 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 1, 1, 1
  %98 = mul i64 %77, %97
  %99 = add i64 %98, %83
  %100 = getelementptr inbounds float, ptr %95, i64 %99
  %101 = load float, ptr %100, align 4, !invariant.load !1
  %102 = call i64 @llvm.smax.i64(i64 %93, i64 1)
  br label %103

103:                                              ; preds = %109, %91
  %104 = phi i64 [ 1, %91 ], [ %112, %109 ]
  %105 = phi float [ %101, %91 ], [ %118, %109 ]
  %106 = icmp slt i64 %104, %102
  br i1 %106, label %107, label %108

107:                                              ; preds = %103
  br label %109

108:                                              ; preds = %103
  br label %119

109:                                              ; preds = %107
  %110 = icmp eq i64 %104, %102
  %111 = add i64 %104, 1
  %112 = select i1 %110, i64 %104, i64 %111
  %113 = mul i64 %104, %96
  %114 = add i64 %113, %98
  %115 = add i64 %114, %83
  %116 = getelementptr inbounds float, ptr %95, i64 %115
  %117 = load float, ptr %116, align 4, !invariant.load !1
  %118 = fadd contract float %105, %117
  br label %103

119:                                              ; preds = %108
  %120 = phi float [ %105, %108 ]
  %121 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %94, 0
  %122 = getelementptr inbounds float, ptr %121, i64 %86
  store float %120, ptr %122, align 4
  %123 = load { i64, i64 }, ptr %6, align 8
  %124 = extractvalue { i64, i64 } %123, 1
  %125 = icmp sge i64 %87, %124
  %126 = select i1 %125, i64 0, i64 %87
  %127 = select i1 %125, i64 %80, i64 %77
  %128 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %129 = load i64, ptr %4, align 8
  %130 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %131 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %128, 0
  %132 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %128, 1, 1, 0
  %133 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %128, 1, 1, 1
  %134 = mul i64 %127, %133
  %135 = add i64 %134, %126
  %136 = getelementptr inbounds float, ptr %131, i64 %135
  %137 = load float, ptr %136, align 4, !invariant.load !1
  %138 = call i64 @llvm.smax.i64(i64 %129, i64 1)
  br label %139

139:                                              ; preds = %145, %119
  %140 = phi i64 [ 1, %119 ], [ %148, %145 ]
  %141 = phi float [ %137, %119 ], [ %154, %145 ]
  %142 = icmp slt i64 %140, %138
  br i1 %142, label %143, label %144

143:                                              ; preds = %139
  br label %145

144:                                              ; preds = %139
  br label %155

145:                                              ; preds = %143
  %146 = icmp eq i64 %140, %138
  %147 = add i64 %140, 1
  %148 = select i1 %146, i64 %140, i64 %147
  %149 = mul i64 %140, %132
  %150 = add i64 %149, %134
  %151 = add i64 %150, %126
  %152 = getelementptr inbounds float, ptr %131, i64 %151
  %153 = load float, ptr %152, align 4, !invariant.load !1
  %154 = fadd contract float %141, %153
  br label %139

155:                                              ; preds = %144
  %156 = phi float [ %141, %144 ]
  %157 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %130, 0
  %158 = trunc i64 %127 to i32
  %159 = mul i32 %158, 512
  %160 = trunc i64 %126 to i32
  %161 = add i32 %159, %160
  %162 = sext i32 %161 to i64
  %163 = getelementptr inbounds float, ptr %157, i64 %162
  store float %156, ptr %163, align 4
  %164 = load { i64, i64 }, ptr %6, align 8
  %165 = add i64 %126, 1
  %166 = extractvalue { i64, i64 } %164, 1
  %167 = icmp sge i64 %165, %166
  %168 = select i1 %167, i64 0, i64 %165
  %169 = add i64 %127, 1
  %170 = select i1 %167, i64 %169, i64 %127
  %171 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %172 = load i64, ptr %4, align 8
  %173 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %174 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %171, 0
  %175 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %171, 1, 1, 0
  %176 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %171, 1, 1, 1
  %177 = mul i64 %170, %176
  %178 = add i64 %177, %168
  %179 = getelementptr inbounds float, ptr %174, i64 %178
  %180 = load float, ptr %179, align 4, !invariant.load !1
  %181 = call i64 @llvm.smax.i64(i64 %172, i64 1)
  br label %182

182:                                              ; preds = %188, %155
  %183 = phi i64 [ 1, %155 ], [ %191, %188 ]
  %184 = phi float [ %180, %155 ], [ %197, %188 ]
  %185 = icmp slt i64 %183, %181
  br i1 %185, label %186, label %187

186:                                              ; preds = %182
  br label %188

187:                                              ; preds = %182
  br label %198

188:                                              ; preds = %186
  %189 = icmp eq i64 %183, %181
  %190 = add i64 %183, 1
  %191 = select i1 %189, i64 %183, i64 %190
  %192 = mul i64 %183, %175
  %193 = add i64 %192, %177
  %194 = add i64 %193, %168
  %195 = getelementptr inbounds float, ptr %174, i64 %194
  %196 = load float, ptr %195, align 4, !invariant.load !1
  %197 = fadd contract float %184, %196
  br label %182

198:                                              ; preds = %187
  %199 = phi float [ %184, %187 ]
  %200 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %173, 0
  %201 = trunc i64 %170 to i32
  %202 = mul i32 %201, 512
  %203 = trunc i64 %168 to i32
  %204 = add i32 %202, %203
  %205 = sext i32 %204 to i64
  %206 = getelementptr inbounds float, ptr %200, i64 %205
  store float %199, ptr %206, align 4
  %207 = load { i64, i64 }, ptr %6, align 8
  %208 = add i64 %168, 1
  %209 = extractvalue { i64, i64 } %207, 1
  %210 = icmp sge i64 %208, %209
  %211 = select i1 %210, i64 0, i64 %208
  %212 = add i64 %170, 1
  %213 = select i1 %210, i64 %212, i64 %170
  %214 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %215 = load i64, ptr %4, align 8
  %216 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %217 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %214, 0
  %218 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %214, 1, 1, 0
  %219 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %214, 1, 1, 1
  %220 = mul i64 %213, %219
  %221 = add i64 %220, %211
  %222 = getelementptr inbounds float, ptr %217, i64 %221
  %223 = load float, ptr %222, align 4, !invariant.load !1
  %224 = call i64 @llvm.smax.i64(i64 %215, i64 1)
  br label %225

225:                                              ; preds = %231, %198
  %226 = phi i64 [ 1, %198 ], [ %234, %231 ]
  %227 = phi float [ %223, %198 ], [ %240, %231 ]
  %228 = icmp slt i64 %226, %224
  br i1 %228, label %229, label %230

229:                                              ; preds = %225
  br label %231

230:                                              ; preds = %225
  br label %241

231:                                              ; preds = %229
  %232 = icmp eq i64 %226, %224
  %233 = add i64 %226, 1
  %234 = select i1 %232, i64 %226, i64 %233
  %235 = mul i64 %226, %218
  %236 = add i64 %235, %220
  %237 = add i64 %236, %211
  %238 = getelementptr inbounds float, ptr %217, i64 %237
  %239 = load float, ptr %238, align 4, !invariant.load !1
  %240 = fadd contract float %227, %239
  br label %225

241:                                              ; preds = %230
  %242 = phi float [ %227, %230 ]
  %243 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %216, 0
  %244 = trunc i64 %213 to i32
  %245 = mul i32 %244, 512
  %246 = trunc i64 %211 to i32
  %247 = add i32 %245, %246
  %248 = sext i32 %247 to i64
  %249 = getelementptr inbounds float, ptr %243, i64 %248
  store float %242, ptr %249, align 4
  br label %282

250:                                              ; preds = %63
  %251 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %252 = load i64, ptr %4, align 8
  %253 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %254 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %251, 0
  %255 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %251, 1, 1, 0
  %256 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %251, 1, 1, 1
  %257 = mul i64 %77, %256
  %258 = add i64 %257, %83
  %259 = getelementptr inbounds float, ptr %254, i64 %258
  %260 = load <4 x float>, ptr %259, align 16, !invariant.load !1
  %261 = call i64 @llvm.smax.i64(i64 %252, i64 1)
  br label %262

262:                                              ; preds = %268, %250
  %263 = phi i64 [ 1, %250 ], [ %271, %268 ]
  %264 = phi <4 x float> [ %260, %250 ], [ %277, %268 ]
  %265 = icmp slt i64 %263, %261
  br i1 %265, label %266, label %267

266:                                              ; preds = %262
  br label %268

267:                                              ; preds = %262
  br label %278

268:                                              ; preds = %266
  %269 = icmp eq i64 %263, %261
  %270 = add i64 %263, 1
  %271 = select i1 %269, i64 %263, i64 %270
  %272 = mul i64 %263, %255
  %273 = add i64 %272, %257
  %274 = add i64 %273, %83
  %275 = getelementptr inbounds float, ptr %254, i64 %274
  %276 = load <4 x float>, ptr %275, align 16, !invariant.load !1
  %277 = fadd contract <4 x float> %264, %276
  br label %262

278:                                              ; preds = %267
  %279 = phi <4 x float> [ %264, %267 ]
  %280 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %253, 0
  %281 = getelementptr inbounds float, ptr %280, i64 %86
  store <4 x float> %279, ptr %281, align 16
  br label %282

282:                                              ; preds = %278, %241
  br label %284

283:                                              ; preds = %60
  br label %284

284:                                              ; preds = %283, %282
  %285 = add i64 %53, %17
  %286 = mul i64 %285, 4
  %287 = icmp slt i64 %286, 0
  %288 = load i64, ptr %20, align 8
  %289 = icmp slt i64 %285, %288
  br i1 %289, label %290, label %510

290:                                              ; preds = %284
  %291 = load { i64, i64 }, ptr %6, align 8
  %292 = extractvalue { i64, i64 } %291, 1
  %293 = icmp eq i64 %292, 0
  %294 = select i1 %293, i64 1, i64 %292
  %295 = sdiv i64 %286, %294
  %296 = mul i64 %295, %292
  %297 = sub i64 %286, %296
  %298 = icmp slt i64 %292, 0
  %299 = xor i1 %298, %287
  %300 = icmp ne i64 %297, 0
  %301 = and i1 %299, %300
  %302 = select i1 %301, i64 1, i64 0
  %303 = sub i64 %295, %302
  %304 = select i1 %293, i64 0, i64 %303
  %305 = trunc i64 %304 to i32
  %306 = mul i32 %305, 512
  %307 = add i64 %304, 1
  %308 = select i1 %301, i64 %292, i64 0
  %309 = add i64 %297, %308
  %310 = select i1 %293, i64 0, i64 %309
  %311 = trunc i64 %310 to i32
  %312 = add i32 %306, %311
  %313 = sext i32 %312 to i64
  %314 = add i64 %310, 1
  %315 = add i64 %310, 4
  %316 = load i64, ptr %8, align 8
  %317 = icmp sgt i64 %315, %316
  br i1 %317, label %318, label %477

318:                                              ; preds = %290
  %319 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %320 = load i64, ptr %4, align 8
  %321 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %322 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %319, 0
  %323 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %319, 1, 1, 0
  %324 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %319, 1, 1, 1
  %325 = mul i64 %304, %324
  %326 = add i64 %325, %310
  %327 = getelementptr inbounds float, ptr %322, i64 %326
  %328 = load float, ptr %327, align 4, !invariant.load !1
  %329 = call i64 @llvm.smax.i64(i64 %320, i64 1)
  br label %330

330:                                              ; preds = %336, %318
  %331 = phi i64 [ 1, %318 ], [ %339, %336 ]
  %332 = phi float [ %328, %318 ], [ %345, %336 ]
  %333 = icmp slt i64 %331, %329
  br i1 %333, label %334, label %335

334:                                              ; preds = %330
  br label %336

335:                                              ; preds = %330
  br label %346

336:                                              ; preds = %334
  %337 = icmp eq i64 %331, %329
  %338 = add i64 %331, 1
  %339 = select i1 %337, i64 %331, i64 %338
  %340 = mul i64 %331, %323
  %341 = add i64 %340, %325
  %342 = add i64 %341, %310
  %343 = getelementptr inbounds float, ptr %322, i64 %342
  %344 = load float, ptr %343, align 4, !invariant.load !1
  %345 = fadd contract float %332, %344
  br label %330

346:                                              ; preds = %335
  %347 = phi float [ %332, %335 ]
  %348 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %321, 0
  %349 = getelementptr inbounds float, ptr %348, i64 %313
  store float %347, ptr %349, align 4
  %350 = load { i64, i64 }, ptr %6, align 8
  %351 = extractvalue { i64, i64 } %350, 1
  %352 = icmp sge i64 %314, %351
  %353 = select i1 %352, i64 0, i64 %314
  %354 = select i1 %352, i64 %307, i64 %304
  %355 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %356 = load i64, ptr %4, align 8
  %357 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %358 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %355, 0
  %359 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %355, 1, 1, 0
  %360 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %355, 1, 1, 1
  %361 = mul i64 %354, %360
  %362 = add i64 %361, %353
  %363 = getelementptr inbounds float, ptr %358, i64 %362
  %364 = load float, ptr %363, align 4, !invariant.load !1
  %365 = call i64 @llvm.smax.i64(i64 %356, i64 1)
  br label %366

366:                                              ; preds = %372, %346
  %367 = phi i64 [ 1, %346 ], [ %375, %372 ]
  %368 = phi float [ %364, %346 ], [ %381, %372 ]
  %369 = icmp slt i64 %367, %365
  br i1 %369, label %370, label %371

370:                                              ; preds = %366
  br label %372

371:                                              ; preds = %366
  br label %382

372:                                              ; preds = %370
  %373 = icmp eq i64 %367, %365
  %374 = add i64 %367, 1
  %375 = select i1 %373, i64 %367, i64 %374
  %376 = mul i64 %367, %359
  %377 = add i64 %376, %361
  %378 = add i64 %377, %353
  %379 = getelementptr inbounds float, ptr %358, i64 %378
  %380 = load float, ptr %379, align 4, !invariant.load !1
  %381 = fadd contract float %368, %380
  br label %366

382:                                              ; preds = %371
  %383 = phi float [ %368, %371 ]
  %384 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %357, 0
  %385 = trunc i64 %354 to i32
  %386 = mul i32 %385, 512
  %387 = trunc i64 %353 to i32
  %388 = add i32 %386, %387
  %389 = sext i32 %388 to i64
  %390 = getelementptr inbounds float, ptr %384, i64 %389
  store float %383, ptr %390, align 4
  %391 = load { i64, i64 }, ptr %6, align 8
  %392 = add i64 %353, 1
  %393 = extractvalue { i64, i64 } %391, 1
  %394 = icmp sge i64 %392, %393
  %395 = select i1 %394, i64 0, i64 %392
  %396 = add i64 %354, 1
  %397 = select i1 %394, i64 %396, i64 %354
  %398 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %399 = load i64, ptr %4, align 8
  %400 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %401 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %398, 0
  %402 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %398, 1, 1, 0
  %403 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %398, 1, 1, 1
  %404 = mul i64 %397, %403
  %405 = add i64 %404, %395
  %406 = getelementptr inbounds float, ptr %401, i64 %405
  %407 = load float, ptr %406, align 4, !invariant.load !1
  %408 = call i64 @llvm.smax.i64(i64 %399, i64 1)
  br label %409

409:                                              ; preds = %415, %382
  %410 = phi i64 [ 1, %382 ], [ %418, %415 ]
  %411 = phi float [ %407, %382 ], [ %424, %415 ]
  %412 = icmp slt i64 %410, %408
  br i1 %412, label %413, label %414

413:                                              ; preds = %409
  br label %415

414:                                              ; preds = %409
  br label %425

415:                                              ; preds = %413
  %416 = icmp eq i64 %410, %408
  %417 = add i64 %410, 1
  %418 = select i1 %416, i64 %410, i64 %417
  %419 = mul i64 %410, %402
  %420 = add i64 %419, %404
  %421 = add i64 %420, %395
  %422 = getelementptr inbounds float, ptr %401, i64 %421
  %423 = load float, ptr %422, align 4, !invariant.load !1
  %424 = fadd contract float %411, %423
  br label %409

425:                                              ; preds = %414
  %426 = phi float [ %411, %414 ]
  %427 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %400, 0
  %428 = trunc i64 %397 to i32
  %429 = mul i32 %428, 512
  %430 = trunc i64 %395 to i32
  %431 = add i32 %429, %430
  %432 = sext i32 %431 to i64
  %433 = getelementptr inbounds float, ptr %427, i64 %432
  store float %426, ptr %433, align 4
  %434 = load { i64, i64 }, ptr %6, align 8
  %435 = add i64 %395, 1
  %436 = extractvalue { i64, i64 } %434, 1
  %437 = icmp sge i64 %435, %436
  %438 = select i1 %437, i64 0, i64 %435
  %439 = add i64 %397, 1
  %440 = select i1 %437, i64 %439, i64 %397
  %441 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %442 = load i64, ptr %4, align 8
  %443 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %444 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %441, 0
  %445 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %441, 1, 1, 0
  %446 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %441, 1, 1, 1
  %447 = mul i64 %440, %446
  %448 = add i64 %447, %438
  %449 = getelementptr inbounds float, ptr %444, i64 %448
  %450 = load float, ptr %449, align 4, !invariant.load !1
  %451 = call i64 @llvm.smax.i64(i64 %442, i64 1)
  br label %452

452:                                              ; preds = %458, %425
  %453 = phi i64 [ 1, %425 ], [ %461, %458 ]
  %454 = phi float [ %450, %425 ], [ %467, %458 ]
  %455 = icmp slt i64 %453, %451
  br i1 %455, label %456, label %457

456:                                              ; preds = %452
  br label %458

457:                                              ; preds = %452
  br label %468

458:                                              ; preds = %456
  %459 = icmp eq i64 %453, %451
  %460 = add i64 %453, 1
  %461 = select i1 %459, i64 %453, i64 %460
  %462 = mul i64 %453, %445
  %463 = add i64 %462, %447
  %464 = add i64 %463, %438
  %465 = getelementptr inbounds float, ptr %444, i64 %464
  %466 = load float, ptr %465, align 4, !invariant.load !1
  %467 = fadd contract float %454, %466
  br label %452

468:                                              ; preds = %457
  %469 = phi float [ %454, %457 ]
  %470 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %443, 0
  %471 = trunc i64 %440 to i32
  %472 = mul i32 %471, 512
  %473 = trunc i64 %438 to i32
  %474 = add i32 %472, %473
  %475 = sext i32 %474 to i64
  %476 = getelementptr inbounds float, ptr %470, i64 %475
  store float %469, ptr %476, align 4
  br label %509

477:                                              ; preds = %290
  %478 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %479 = load i64, ptr %4, align 8
  %480 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %481 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %478, 0
  %482 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %478, 1, 1, 0
  %483 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %478, 1, 1, 1
  %484 = mul i64 %304, %483
  %485 = add i64 %484, %310
  %486 = getelementptr inbounds float, ptr %481, i64 %485
  %487 = load <4 x float>, ptr %486, align 16, !invariant.load !1
  %488 = call i64 @llvm.smax.i64(i64 %479, i64 1)
  br label %489

489:                                              ; preds = %495, %477
  %490 = phi i64 [ 1, %477 ], [ %498, %495 ]
  %491 = phi <4 x float> [ %487, %477 ], [ %504, %495 ]
  %492 = icmp slt i64 %490, %488
  br i1 %492, label %493, label %494

493:                                              ; preds = %489
  br label %495

494:                                              ; preds = %489
  br label %505

495:                                              ; preds = %493
  %496 = icmp eq i64 %490, %488
  %497 = add i64 %490, 1
  %498 = select i1 %496, i64 %490, i64 %497
  %499 = mul i64 %490, %482
  %500 = add i64 %499, %484
  %501 = add i64 %500, %310
  %502 = getelementptr inbounds float, ptr %481, i64 %501
  %503 = load <4 x float>, ptr %502, align 16, !invariant.load !1
  %504 = fadd contract <4 x float> %491, %503
  br label %489

505:                                              ; preds = %494
  %506 = phi <4 x float> [ %491, %494 ]
  %507 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %480, 0
  %508 = getelementptr inbounds float, ptr %507, i64 %313
  store <4 x float> %506, ptr %508, align 16
  br label %509

509:                                              ; preds = %505, %468
  br label %511

510:                                              ; preds = %284
  br label %511

511:                                              ; preds = %510, %509
  %512 = add i64 %53, %19
  %513 = mul i64 %512, 4
  %514 = icmp slt i64 %513, 0
  %515 = load i64, ptr %20, align 8
  %516 = icmp slt i64 %512, %515
  br i1 %516, label %517, label %737

517:                                              ; preds = %511
  %518 = load { i64, i64 }, ptr %6, align 8
  %519 = extractvalue { i64, i64 } %518, 1
  %520 = icmp eq i64 %519, 0
  %521 = select i1 %520, i64 1, i64 %519
  %522 = sdiv i64 %513, %521
  %523 = mul i64 %522, %519
  %524 = sub i64 %513, %523
  %525 = icmp slt i64 %519, 0
  %526 = xor i1 %525, %514
  %527 = icmp ne i64 %524, 0
  %528 = and i1 %526, %527
  %529 = select i1 %528, i64 1, i64 0
  %530 = sub i64 %522, %529
  %531 = select i1 %520, i64 0, i64 %530
  %532 = trunc i64 %531 to i32
  %533 = mul i32 %532, 512
  %534 = add i64 %531, 1
  %535 = select i1 %528, i64 %519, i64 0
  %536 = add i64 %524, %535
  %537 = select i1 %520, i64 0, i64 %536
  %538 = trunc i64 %537 to i32
  %539 = add i32 %533, %538
  %540 = sext i32 %539 to i64
  %541 = add i64 %537, 1
  %542 = add i64 %537, 4
  %543 = load i64, ptr %8, align 8
  %544 = icmp sgt i64 %542, %543
  br i1 %544, label %545, label %704

545:                                              ; preds = %517
  %546 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %547 = load i64, ptr %4, align 8
  %548 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %549 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %546, 0
  %550 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %546, 1, 1, 0
  %551 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %546, 1, 1, 1
  %552 = mul i64 %531, %551
  %553 = add i64 %552, %537
  %554 = getelementptr inbounds float, ptr %549, i64 %553
  %555 = load float, ptr %554, align 4, !invariant.load !1
  %556 = call i64 @llvm.smax.i64(i64 %547, i64 1)
  br label %557

557:                                              ; preds = %563, %545
  %558 = phi i64 [ 1, %545 ], [ %566, %563 ]
  %559 = phi float [ %555, %545 ], [ %572, %563 ]
  %560 = icmp slt i64 %558, %556
  br i1 %560, label %561, label %562

561:                                              ; preds = %557
  br label %563

562:                                              ; preds = %557
  br label %573

563:                                              ; preds = %561
  %564 = icmp eq i64 %558, %556
  %565 = add i64 %558, 1
  %566 = select i1 %564, i64 %558, i64 %565
  %567 = mul i64 %558, %550
  %568 = add i64 %567, %552
  %569 = add i64 %568, %537
  %570 = getelementptr inbounds float, ptr %549, i64 %569
  %571 = load float, ptr %570, align 4, !invariant.load !1
  %572 = fadd contract float %559, %571
  br label %557

573:                                              ; preds = %562
  %574 = phi float [ %559, %562 ]
  %575 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %548, 0
  %576 = getelementptr inbounds float, ptr %575, i64 %540
  store float %574, ptr %576, align 4
  %577 = load { i64, i64 }, ptr %6, align 8
  %578 = extractvalue { i64, i64 } %577, 1
  %579 = icmp sge i64 %541, %578
  %580 = select i1 %579, i64 0, i64 %541
  %581 = select i1 %579, i64 %534, i64 %531
  %582 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %583 = load i64, ptr %4, align 8
  %584 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %585 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %582, 0
  %586 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %582, 1, 1, 0
  %587 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %582, 1, 1, 1
  %588 = mul i64 %581, %587
  %589 = add i64 %588, %580
  %590 = getelementptr inbounds float, ptr %585, i64 %589
  %591 = load float, ptr %590, align 4, !invariant.load !1
  %592 = call i64 @llvm.smax.i64(i64 %583, i64 1)
  br label %593

593:                                              ; preds = %599, %573
  %594 = phi i64 [ 1, %573 ], [ %602, %599 ]
  %595 = phi float [ %591, %573 ], [ %608, %599 ]
  %596 = icmp slt i64 %594, %592
  br i1 %596, label %597, label %598

597:                                              ; preds = %593
  br label %599

598:                                              ; preds = %593
  br label %609

599:                                              ; preds = %597
  %600 = icmp eq i64 %594, %592
  %601 = add i64 %594, 1
  %602 = select i1 %600, i64 %594, i64 %601
  %603 = mul i64 %594, %586
  %604 = add i64 %603, %588
  %605 = add i64 %604, %580
  %606 = getelementptr inbounds float, ptr %585, i64 %605
  %607 = load float, ptr %606, align 4, !invariant.load !1
  %608 = fadd contract float %595, %607
  br label %593

609:                                              ; preds = %598
  %610 = phi float [ %595, %598 ]
  %611 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %584, 0
  %612 = trunc i64 %581 to i32
  %613 = mul i32 %612, 512
  %614 = trunc i64 %580 to i32
  %615 = add i32 %613, %614
  %616 = sext i32 %615 to i64
  %617 = getelementptr inbounds float, ptr %611, i64 %616
  store float %610, ptr %617, align 4
  %618 = load { i64, i64 }, ptr %6, align 8
  %619 = add i64 %580, 1
  %620 = extractvalue { i64, i64 } %618, 1
  %621 = icmp sge i64 %619, %620
  %622 = select i1 %621, i64 0, i64 %619
  %623 = add i64 %581, 1
  %624 = select i1 %621, i64 %623, i64 %581
  %625 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %626 = load i64, ptr %4, align 8
  %627 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %628 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %625, 0
  %629 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %625, 1, 1, 0
  %630 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %625, 1, 1, 1
  %631 = mul i64 %624, %630
  %632 = add i64 %631, %622
  %633 = getelementptr inbounds float, ptr %628, i64 %632
  %634 = load float, ptr %633, align 4, !invariant.load !1
  %635 = call i64 @llvm.smax.i64(i64 %626, i64 1)
  br label %636

636:                                              ; preds = %642, %609
  %637 = phi i64 [ 1, %609 ], [ %645, %642 ]
  %638 = phi float [ %634, %609 ], [ %651, %642 ]
  %639 = icmp slt i64 %637, %635
  br i1 %639, label %640, label %641

640:                                              ; preds = %636
  br label %642

641:                                              ; preds = %636
  br label %652

642:                                              ; preds = %640
  %643 = icmp eq i64 %637, %635
  %644 = add i64 %637, 1
  %645 = select i1 %643, i64 %637, i64 %644
  %646 = mul i64 %637, %629
  %647 = add i64 %646, %631
  %648 = add i64 %647, %622
  %649 = getelementptr inbounds float, ptr %628, i64 %648
  %650 = load float, ptr %649, align 4, !invariant.load !1
  %651 = fadd contract float %638, %650
  br label %636

652:                                              ; preds = %641
  %653 = phi float [ %638, %641 ]
  %654 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %627, 0
  %655 = trunc i64 %624 to i32
  %656 = mul i32 %655, 512
  %657 = trunc i64 %622 to i32
  %658 = add i32 %656, %657
  %659 = sext i32 %658 to i64
  %660 = getelementptr inbounds float, ptr %654, i64 %659
  store float %653, ptr %660, align 4
  %661 = load { i64, i64 }, ptr %6, align 8
  %662 = add i64 %622, 1
  %663 = extractvalue { i64, i64 } %661, 1
  %664 = icmp sge i64 %662, %663
  %665 = select i1 %664, i64 0, i64 %662
  %666 = add i64 %624, 1
  %667 = select i1 %664, i64 %666, i64 %624
  %668 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %669 = load i64, ptr %4, align 8
  %670 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %671 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %668, 0
  %672 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %668, 1, 1, 0
  %673 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %668, 1, 1, 1
  %674 = mul i64 %667, %673
  %675 = add i64 %674, %665
  %676 = getelementptr inbounds float, ptr %671, i64 %675
  %677 = load float, ptr %676, align 4, !invariant.load !1
  %678 = call i64 @llvm.smax.i64(i64 %669, i64 1)
  br label %679

679:                                              ; preds = %685, %652
  %680 = phi i64 [ 1, %652 ], [ %688, %685 ]
  %681 = phi float [ %677, %652 ], [ %694, %685 ]
  %682 = icmp slt i64 %680, %678
  br i1 %682, label %683, label %684

683:                                              ; preds = %679
  br label %685

684:                                              ; preds = %679
  br label %695

685:                                              ; preds = %683
  %686 = icmp eq i64 %680, %678
  %687 = add i64 %680, 1
  %688 = select i1 %686, i64 %680, i64 %687
  %689 = mul i64 %680, %672
  %690 = add i64 %689, %674
  %691 = add i64 %690, %665
  %692 = getelementptr inbounds float, ptr %671, i64 %691
  %693 = load float, ptr %692, align 4, !invariant.load !1
  %694 = fadd contract float %681, %693
  br label %679

695:                                              ; preds = %684
  %696 = phi float [ %681, %684 ]
  %697 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %670, 0
  %698 = trunc i64 %667 to i32
  %699 = mul i32 %698, 512
  %700 = trunc i64 %665 to i32
  %701 = add i32 %699, %700
  %702 = sext i32 %701 to i64
  %703 = getelementptr inbounds float, ptr %697, i64 %702
  store float %696, ptr %703, align 4
  br label %736

704:                                              ; preds = %517
  %705 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %706 = load i64, ptr %4, align 8
  %707 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %708 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %705, 0
  %709 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %705, 1, 1, 0
  %710 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %705, 1, 1, 1
  %711 = mul i64 %531, %710
  %712 = add i64 %711, %537
  %713 = getelementptr inbounds float, ptr %708, i64 %712
  %714 = load <4 x float>, ptr %713, align 16, !invariant.load !1
  %715 = call i64 @llvm.smax.i64(i64 %706, i64 1)
  br label %716

716:                                              ; preds = %722, %704
  %717 = phi i64 [ 1, %704 ], [ %725, %722 ]
  %718 = phi <4 x float> [ %714, %704 ], [ %731, %722 ]
  %719 = icmp slt i64 %717, %715
  br i1 %719, label %720, label %721

720:                                              ; preds = %716
  br label %722

721:                                              ; preds = %716
  br label %732

722:                                              ; preds = %720
  %723 = icmp eq i64 %717, %715
  %724 = add i64 %717, 1
  %725 = select i1 %723, i64 %717, i64 %724
  %726 = mul i64 %717, %709
  %727 = add i64 %726, %711
  %728 = add i64 %727, %537
  %729 = getelementptr inbounds float, ptr %708, i64 %728
  %730 = load <4 x float>, ptr %729, align 16, !invariant.load !1
  %731 = fadd contract <4 x float> %718, %730
  br label %716

732:                                              ; preds = %721
  %733 = phi <4 x float> [ %718, %721 ]
  %734 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %707, 0
  %735 = getelementptr inbounds float, ptr %734, i64 %540
  store <4 x float> %733, ptr %735, align 16
  br label %736

736:                                              ; preds = %732, %695
  br label %738

737:                                              ; preds = %511
  br label %738

738:                                              ; preds = %737, %736
  %739 = add i64 %53, %18
  %740 = mul i64 %739, 4
  %741 = icmp slt i64 %740, 0
  %742 = load i64, ptr %20, align 8
  %743 = icmp slt i64 %739, %742
  br i1 %743, label %744, label %964

744:                                              ; preds = %738
  %745 = load { i64, i64 }, ptr %6, align 8
  %746 = extractvalue { i64, i64 } %745, 1
  %747 = icmp eq i64 %746, 0
  %748 = select i1 %747, i64 1, i64 %746
  %749 = sdiv i64 %740, %748
  %750 = mul i64 %749, %746
  %751 = sub i64 %740, %750
  %752 = icmp slt i64 %746, 0
  %753 = xor i1 %752, %741
  %754 = icmp ne i64 %751, 0
  %755 = and i1 %753, %754
  %756 = select i1 %755, i64 1, i64 0
  %757 = sub i64 %749, %756
  %758 = select i1 %747, i64 0, i64 %757
  %759 = trunc i64 %758 to i32
  %760 = mul i32 %759, 512
  %761 = add i64 %758, 1
  %762 = select i1 %755, i64 %746, i64 0
  %763 = add i64 %751, %762
  %764 = select i1 %747, i64 0, i64 %763
  %765 = trunc i64 %764 to i32
  %766 = add i32 %760, %765
  %767 = sext i32 %766 to i64
  %768 = add i64 %764, 1
  %769 = add i64 %764, 4
  %770 = load i64, ptr %8, align 8
  %771 = icmp sgt i64 %769, %770
  br i1 %771, label %772, label %931

772:                                              ; preds = %744
  %773 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %774 = load i64, ptr %4, align 8
  %775 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %776 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %773, 0
  %777 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %773, 1, 1, 0
  %778 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %773, 1, 1, 1
  %779 = mul i64 %758, %778
  %780 = add i64 %779, %764
  %781 = getelementptr inbounds float, ptr %776, i64 %780
  %782 = load float, ptr %781, align 4, !invariant.load !1
  %783 = call i64 @llvm.smax.i64(i64 %774, i64 1)
  br label %784

784:                                              ; preds = %790, %772
  %785 = phi i64 [ 1, %772 ], [ %793, %790 ]
  %786 = phi float [ %782, %772 ], [ %799, %790 ]
  %787 = icmp slt i64 %785, %783
  br i1 %787, label %788, label %789

788:                                              ; preds = %784
  br label %790

789:                                              ; preds = %784
  br label %800

790:                                              ; preds = %788
  %791 = icmp eq i64 %785, %783
  %792 = add i64 %785, 1
  %793 = select i1 %791, i64 %785, i64 %792
  %794 = mul i64 %785, %777
  %795 = add i64 %794, %779
  %796 = add i64 %795, %764
  %797 = getelementptr inbounds float, ptr %776, i64 %796
  %798 = load float, ptr %797, align 4, !invariant.load !1
  %799 = fadd contract float %786, %798
  br label %784

800:                                              ; preds = %789
  %801 = phi float [ %786, %789 ]
  %802 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %775, 0
  %803 = getelementptr inbounds float, ptr %802, i64 %767
  store float %801, ptr %803, align 4
  %804 = load { i64, i64 }, ptr %6, align 8
  %805 = extractvalue { i64, i64 } %804, 1
  %806 = icmp sge i64 %768, %805
  %807 = select i1 %806, i64 0, i64 %768
  %808 = select i1 %806, i64 %761, i64 %758
  %809 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %810 = load i64, ptr %4, align 8
  %811 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %812 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %809, 0
  %813 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %809, 1, 1, 0
  %814 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %809, 1, 1, 1
  %815 = mul i64 %808, %814
  %816 = add i64 %815, %807
  %817 = getelementptr inbounds float, ptr %812, i64 %816
  %818 = load float, ptr %817, align 4, !invariant.load !1
  %819 = call i64 @llvm.smax.i64(i64 %810, i64 1)
  br label %820

820:                                              ; preds = %826, %800
  %821 = phi i64 [ 1, %800 ], [ %829, %826 ]
  %822 = phi float [ %818, %800 ], [ %835, %826 ]
  %823 = icmp slt i64 %821, %819
  br i1 %823, label %824, label %825

824:                                              ; preds = %820
  br label %826

825:                                              ; preds = %820
  br label %836

826:                                              ; preds = %824
  %827 = icmp eq i64 %821, %819
  %828 = add i64 %821, 1
  %829 = select i1 %827, i64 %821, i64 %828
  %830 = mul i64 %821, %813
  %831 = add i64 %830, %815
  %832 = add i64 %831, %807
  %833 = getelementptr inbounds float, ptr %812, i64 %832
  %834 = load float, ptr %833, align 4, !invariant.load !1
  %835 = fadd contract float %822, %834
  br label %820

836:                                              ; preds = %825
  %837 = phi float [ %822, %825 ]
  %838 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %811, 0
  %839 = trunc i64 %808 to i32
  %840 = mul i32 %839, 512
  %841 = trunc i64 %807 to i32
  %842 = add i32 %840, %841
  %843 = sext i32 %842 to i64
  %844 = getelementptr inbounds float, ptr %838, i64 %843
  store float %837, ptr %844, align 4
  %845 = load { i64, i64 }, ptr %6, align 8
  %846 = add i64 %807, 1
  %847 = extractvalue { i64, i64 } %845, 1
  %848 = icmp sge i64 %846, %847
  %849 = select i1 %848, i64 0, i64 %846
  %850 = add i64 %808, 1
  %851 = select i1 %848, i64 %850, i64 %808
  %852 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %853 = load i64, ptr %4, align 8
  %854 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %855 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %852, 0
  %856 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %852, 1, 1, 0
  %857 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %852, 1, 1, 1
  %858 = mul i64 %851, %857
  %859 = add i64 %858, %849
  %860 = getelementptr inbounds float, ptr %855, i64 %859
  %861 = load float, ptr %860, align 4, !invariant.load !1
  %862 = call i64 @llvm.smax.i64(i64 %853, i64 1)
  br label %863

863:                                              ; preds = %869, %836
  %864 = phi i64 [ 1, %836 ], [ %872, %869 ]
  %865 = phi float [ %861, %836 ], [ %878, %869 ]
  %866 = icmp slt i64 %864, %862
  br i1 %866, label %867, label %868

867:                                              ; preds = %863
  br label %869

868:                                              ; preds = %863
  br label %879

869:                                              ; preds = %867
  %870 = icmp eq i64 %864, %862
  %871 = add i64 %864, 1
  %872 = select i1 %870, i64 %864, i64 %871
  %873 = mul i64 %864, %856
  %874 = add i64 %873, %858
  %875 = add i64 %874, %849
  %876 = getelementptr inbounds float, ptr %855, i64 %875
  %877 = load float, ptr %876, align 4, !invariant.load !1
  %878 = fadd contract float %865, %877
  br label %863

879:                                              ; preds = %868
  %880 = phi float [ %865, %868 ]
  %881 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %854, 0
  %882 = trunc i64 %851 to i32
  %883 = mul i32 %882, 512
  %884 = trunc i64 %849 to i32
  %885 = add i32 %883, %884
  %886 = sext i32 %885 to i64
  %887 = getelementptr inbounds float, ptr %881, i64 %886
  store float %880, ptr %887, align 4
  %888 = load { i64, i64 }, ptr %6, align 8
  %889 = add i64 %849, 1
  %890 = extractvalue { i64, i64 } %888, 1
  %891 = icmp sge i64 %889, %890
  %892 = select i1 %891, i64 0, i64 %889
  %893 = add i64 %851, 1
  %894 = select i1 %891, i64 %893, i64 %851
  %895 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %896 = load i64, ptr %4, align 8
  %897 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %898 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %895, 0
  %899 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %895, 1, 1, 0
  %900 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %895, 1, 1, 1
  %901 = mul i64 %894, %900
  %902 = add i64 %901, %892
  %903 = getelementptr inbounds float, ptr %898, i64 %902
  %904 = load float, ptr %903, align 4, !invariant.load !1
  %905 = call i64 @llvm.smax.i64(i64 %896, i64 1)
  br label %906

906:                                              ; preds = %912, %879
  %907 = phi i64 [ 1, %879 ], [ %915, %912 ]
  %908 = phi float [ %904, %879 ], [ %921, %912 ]
  %909 = icmp slt i64 %907, %905
  br i1 %909, label %910, label %911

910:                                              ; preds = %906
  br label %912

911:                                              ; preds = %906
  br label %922

912:                                              ; preds = %910
  %913 = icmp eq i64 %907, %905
  %914 = add i64 %907, 1
  %915 = select i1 %913, i64 %907, i64 %914
  %916 = mul i64 %907, %899
  %917 = add i64 %916, %901
  %918 = add i64 %917, %892
  %919 = getelementptr inbounds float, ptr %898, i64 %918
  %920 = load float, ptr %919, align 4, !invariant.load !1
  %921 = fadd contract float %908, %920
  br label %906

922:                                              ; preds = %911
  %923 = phi float [ %908, %911 ]
  %924 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %897, 0
  %925 = trunc i64 %894 to i32
  %926 = mul i32 %925, 512
  %927 = trunc i64 %892 to i32
  %928 = add i32 %926, %927
  %929 = sext i32 %928 to i64
  %930 = getelementptr inbounds float, ptr %924, i64 %929
  store float %923, ptr %930, align 4
  br label %963

931:                                              ; preds = %744
  %932 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %933 = load i64, ptr %4, align 8
  %934 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %935 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %932, 0
  %936 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %932, 1, 1, 0
  %937 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %932, 1, 1, 1
  %938 = mul i64 %758, %937
  %939 = add i64 %938, %764
  %940 = getelementptr inbounds float, ptr %935, i64 %939
  %941 = load <4 x float>, ptr %940, align 16, !invariant.load !1
  %942 = call i64 @llvm.smax.i64(i64 %933, i64 1)
  br label %943

943:                                              ; preds = %949, %931
  %944 = phi i64 [ 1, %931 ], [ %952, %949 ]
  %945 = phi <4 x float> [ %941, %931 ], [ %958, %949 ]
  %946 = icmp slt i64 %944, %942
  br i1 %946, label %947, label %948

947:                                              ; preds = %943
  br label %949

948:                                              ; preds = %943
  br label %959

949:                                              ; preds = %947
  %950 = icmp eq i64 %944, %942
  %951 = add i64 %944, 1
  %952 = select i1 %950, i64 %944, i64 %951
  %953 = mul i64 %944, %936
  %954 = add i64 %953, %938
  %955 = add i64 %954, %764
  %956 = getelementptr inbounds float, ptr %935, i64 %955
  %957 = load <4 x float>, ptr %956, align 16, !invariant.load !1
  %958 = fadd contract <4 x float> %945, %957
  br label %943

959:                                              ; preds = %948
  %960 = phi <4 x float> [ %945, %948 ]
  %961 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %934, 0
  %962 = getelementptr inbounds float, ptr %961, i64 %767
  store <4 x float> %960, ptr %962, align 16
  br label %963

963:                                              ; preds = %959, %922
  br label %965

964:                                              ; preds = %738
  br label %965

965:                                              ; preds = %964, %963
  br label %29

966:                                              ; preds = %58
  %967 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %968 = load i64, ptr %967, align 8
  %969 = icmp slt i64 %14, %968
  br i1 %969, label %970, label %1027

970:                                              ; preds = %966
  %971 = load i64, ptr %7, align 8
  %972 = add i64 %971, %14
  %973 = load { i64, i64 }, ptr %6, align 8
  %974 = extractvalue { i64, i64 } %973, 1
  %975 = icmp eq i64 %974, 0
  %976 = select i1 %975, i64 1, i64 %974
  %977 = sdiv i64 %972, %976
  %978 = mul i64 %977, %974
  %979 = sub i64 %972, %978
  %980 = icmp slt i64 %974, 0
  %981 = icmp slt i64 %972, 0
  %982 = xor i1 %980, %981
  %983 = icmp ne i64 %979, 0
  %984 = and i1 %982, %983
  %985 = select i1 %984, i64 1, i64 0
  %986 = sub i64 %977, %985
  %987 = select i1 %975, i64 0, i64 %986
  %988 = select i1 %984, i64 %974, i64 0
  %989 = add i64 %979, %988
  %990 = select i1 %975, i64 0, i64 %989
  %991 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %992 = load i64, ptr %4, align 8
  %993 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %994 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %991, 0
  %995 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %991, 1, 1, 0
  %996 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %991, 1, 1, 1
  %997 = mul i64 %987, %996
  %998 = add i64 %997, %990
  %999 = getelementptr inbounds float, ptr %994, i64 %998
  %1000 = load float, ptr %999, align 4, !invariant.load !1
  %1001 = call i64 @llvm.smax.i64(i64 %992, i64 1)
  br label %1002

1002:                                             ; preds = %1008, %970
  %1003 = phi i64 [ 1, %970 ], [ %1011, %1008 ]
  %1004 = phi float [ %1000, %970 ], [ %1017, %1008 ]
  %1005 = icmp slt i64 %1003, %1001
  br i1 %1005, label %1006, label %1007

1006:                                             ; preds = %1002
  br label %1008

1007:                                             ; preds = %1002
  br label %1018

1008:                                             ; preds = %1006
  %1009 = icmp eq i64 %1003, %1001
  %1010 = add i64 %1003, 1
  %1011 = select i1 %1009, i64 %1003, i64 %1010
  %1012 = mul i64 %1003, %995
  %1013 = add i64 %1012, %997
  %1014 = add i64 %1013, %990
  %1015 = getelementptr inbounds float, ptr %994, i64 %1014
  %1016 = load float, ptr %1015, align 4, !invariant.load !1
  %1017 = fadd contract float %1004, %1016
  br label %1002

1018:                                             ; preds = %1007
  %1019 = phi float [ %1004, %1007 ]
  %1020 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %993, 0
  %1021 = trunc i64 %987 to i32
  %1022 = mul i32 %1021, 512
  %1023 = trunc i64 %990 to i32
  %1024 = add i32 %1022, %1023
  %1025 = sext i32 %1024 to i64
  %1026 = getelementptr inbounds float, ptr %1020, i64 %1025
  store float %1019, ptr %1026, align 4
  br label %1028

1027:                                             ; preds = %966
  br label %1028

1028:                                             ; preds = %1027, %1018
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
