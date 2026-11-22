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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w4_b256_gs_True_02035925(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

29:                                               ; preds = %957, %1
  %30 = phi i64 [ %24, %1 ], [ %54, %957 ]
  %31 = phi i64 [ 0, %1 ], [ %55, %957 ]
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
  %57 = trunc i64 %56 to i32
  br i1 %52, label %58, label %59

58:                                               ; preds = %51
  br label %958

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59
  %61 = load i64, ptr %20, align 8
  %62 = icmp slt i64 %53, %61
  br i1 %62, label %63, label %281

63:                                               ; preds = %60
  %64 = load { i64, i64 }, ptr %6, align 8
  %65 = extractvalue { i64, i64 } %64, 1
  %66 = trunc i64 %65 to i32
  %67 = icmp eq i32 %66, 0
  %68 = select i1 %67, i32 1, i32 %66
  %69 = icmp eq i32 %68, 0
  %70 = select i1 %69, i32 1, i32 %68
  %71 = udiv i32 %57, %70
  %72 = select i1 %69, i32 0, i32 %71
  %73 = urem i32 %57, %70
  %74 = select i1 %69, i32 0, i32 %73
  %75 = select i1 %67, i32 0, i32 %72
  %76 = select i1 %67, i32 0, i32 %74
  %77 = zext i32 %76 to i64
  %78 = trunc i64 %77 to i32
  %79 = add i64 %77, 1
  %80 = zext i32 %75 to i64
  %81 = trunc i64 %80 to i32
  %82 = mul i32 %81, 512
  %83 = add i32 %82, %78
  %84 = sext i32 %83 to i64
  %85 = add i64 %80, 1
  %86 = add i64 %77, 4
  %87 = load i64, ptr %8, align 8
  %88 = icmp sgt i64 %86, %87
  br i1 %88, label %89, label %248

89:                                               ; preds = %63
  %90 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %91 = load i64, ptr %4, align 8
  %92 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %93 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 0
  %94 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 1, 1, 0
  %95 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 1, 1, 1
  %96 = mul i64 %80, %95
  %97 = add i64 %96, %77
  %98 = getelementptr inbounds float, ptr %93, i64 %97
  %99 = load float, ptr %98, align 4, !invariant.load !1
  %100 = call i64 @llvm.smax.i64(i64 %91, i64 1)
  br label %101

101:                                              ; preds = %107, %89
  %102 = phi i64 [ 1, %89 ], [ %110, %107 ]
  %103 = phi float [ %99, %89 ], [ %116, %107 ]
  %104 = icmp slt i64 %102, %100
  br i1 %104, label %105, label %106

105:                                              ; preds = %101
  br label %107

106:                                              ; preds = %101
  br label %117

107:                                              ; preds = %105
  %108 = icmp eq i64 %102, %100
  %109 = add i64 %102, 1
  %110 = select i1 %108, i64 %102, i64 %109
  %111 = mul i64 %102, %94
  %112 = add i64 %111, %96
  %113 = add i64 %112, %77
  %114 = getelementptr inbounds float, ptr %93, i64 %113
  %115 = load float, ptr %114, align 4, !invariant.load !1
  %116 = fadd contract float %103, %115
  br label %101

117:                                              ; preds = %106
  %118 = phi float [ %103, %106 ]
  %119 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %92, 0
  %120 = getelementptr inbounds float, ptr %119, i64 %84
  store float %118, ptr %120, align 4
  %121 = load { i64, i64 }, ptr %6, align 8
  %122 = extractvalue { i64, i64 } %121, 1
  %123 = icmp sge i64 %79, %122
  %124 = select i1 %123, i64 0, i64 %79
  %125 = select i1 %123, i64 %85, i64 %80
  %126 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %127 = load i64, ptr %4, align 8
  %128 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %129 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %126, 0
  %130 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %126, 1, 1, 0
  %131 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %126, 1, 1, 1
  %132 = mul i64 %125, %131
  %133 = add i64 %132, %124
  %134 = getelementptr inbounds float, ptr %129, i64 %133
  %135 = load float, ptr %134, align 4, !invariant.load !1
  %136 = call i64 @llvm.smax.i64(i64 %127, i64 1)
  br label %137

137:                                              ; preds = %143, %117
  %138 = phi i64 [ 1, %117 ], [ %146, %143 ]
  %139 = phi float [ %135, %117 ], [ %152, %143 ]
  %140 = icmp slt i64 %138, %136
  br i1 %140, label %141, label %142

141:                                              ; preds = %137
  br label %143

142:                                              ; preds = %137
  br label %153

143:                                              ; preds = %141
  %144 = icmp eq i64 %138, %136
  %145 = add i64 %138, 1
  %146 = select i1 %144, i64 %138, i64 %145
  %147 = mul i64 %138, %130
  %148 = add i64 %147, %132
  %149 = add i64 %148, %124
  %150 = getelementptr inbounds float, ptr %129, i64 %149
  %151 = load float, ptr %150, align 4, !invariant.load !1
  %152 = fadd contract float %139, %151
  br label %137

153:                                              ; preds = %142
  %154 = phi float [ %139, %142 ]
  %155 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %128, 0
  %156 = trunc i64 %125 to i32
  %157 = mul i32 %156, 512
  %158 = trunc i64 %124 to i32
  %159 = add i32 %157, %158
  %160 = sext i32 %159 to i64
  %161 = getelementptr inbounds float, ptr %155, i64 %160
  store float %154, ptr %161, align 4
  %162 = load { i64, i64 }, ptr %6, align 8
  %163 = add i64 %124, 1
  %164 = extractvalue { i64, i64 } %162, 1
  %165 = icmp sge i64 %163, %164
  %166 = select i1 %165, i64 0, i64 %163
  %167 = add i64 %125, 1
  %168 = select i1 %165, i64 %167, i64 %125
  %169 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %170 = load i64, ptr %4, align 8
  %171 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %172 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %169, 0
  %173 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %169, 1, 1, 0
  %174 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %169, 1, 1, 1
  %175 = mul i64 %168, %174
  %176 = add i64 %175, %166
  %177 = getelementptr inbounds float, ptr %172, i64 %176
  %178 = load float, ptr %177, align 4, !invariant.load !1
  %179 = call i64 @llvm.smax.i64(i64 %170, i64 1)
  br label %180

180:                                              ; preds = %186, %153
  %181 = phi i64 [ 1, %153 ], [ %189, %186 ]
  %182 = phi float [ %178, %153 ], [ %195, %186 ]
  %183 = icmp slt i64 %181, %179
  br i1 %183, label %184, label %185

184:                                              ; preds = %180
  br label %186

185:                                              ; preds = %180
  br label %196

186:                                              ; preds = %184
  %187 = icmp eq i64 %181, %179
  %188 = add i64 %181, 1
  %189 = select i1 %187, i64 %181, i64 %188
  %190 = mul i64 %181, %173
  %191 = add i64 %190, %175
  %192 = add i64 %191, %166
  %193 = getelementptr inbounds float, ptr %172, i64 %192
  %194 = load float, ptr %193, align 4, !invariant.load !1
  %195 = fadd contract float %182, %194
  br label %180

196:                                              ; preds = %185
  %197 = phi float [ %182, %185 ]
  %198 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %171, 0
  %199 = trunc i64 %168 to i32
  %200 = mul i32 %199, 512
  %201 = trunc i64 %166 to i32
  %202 = add i32 %200, %201
  %203 = sext i32 %202 to i64
  %204 = getelementptr inbounds float, ptr %198, i64 %203
  store float %197, ptr %204, align 4
  %205 = load { i64, i64 }, ptr %6, align 8
  %206 = add i64 %166, 1
  %207 = extractvalue { i64, i64 } %205, 1
  %208 = icmp sge i64 %206, %207
  %209 = select i1 %208, i64 0, i64 %206
  %210 = add i64 %168, 1
  %211 = select i1 %208, i64 %210, i64 %168
  %212 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %213 = load i64, ptr %4, align 8
  %214 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %215 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %212, 0
  %216 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %212, 1, 1, 0
  %217 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %212, 1, 1, 1
  %218 = mul i64 %211, %217
  %219 = add i64 %218, %209
  %220 = getelementptr inbounds float, ptr %215, i64 %219
  %221 = load float, ptr %220, align 4, !invariant.load !1
  %222 = call i64 @llvm.smax.i64(i64 %213, i64 1)
  br label %223

223:                                              ; preds = %229, %196
  %224 = phi i64 [ 1, %196 ], [ %232, %229 ]
  %225 = phi float [ %221, %196 ], [ %238, %229 ]
  %226 = icmp slt i64 %224, %222
  br i1 %226, label %227, label %228

227:                                              ; preds = %223
  br label %229

228:                                              ; preds = %223
  br label %239

229:                                              ; preds = %227
  %230 = icmp eq i64 %224, %222
  %231 = add i64 %224, 1
  %232 = select i1 %230, i64 %224, i64 %231
  %233 = mul i64 %224, %216
  %234 = add i64 %233, %218
  %235 = add i64 %234, %209
  %236 = getelementptr inbounds float, ptr %215, i64 %235
  %237 = load float, ptr %236, align 4, !invariant.load !1
  %238 = fadd contract float %225, %237
  br label %223

239:                                              ; preds = %228
  %240 = phi float [ %225, %228 ]
  %241 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %214, 0
  %242 = trunc i64 %211 to i32
  %243 = mul i32 %242, 512
  %244 = trunc i64 %209 to i32
  %245 = add i32 %243, %244
  %246 = sext i32 %245 to i64
  %247 = getelementptr inbounds float, ptr %241, i64 %246
  store float %240, ptr %247, align 4
  br label %280

248:                                              ; preds = %63
  %249 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %250 = load i64, ptr %4, align 8
  %251 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %252 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %249, 0
  %253 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %249, 1, 1, 0
  %254 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %249, 1, 1, 1
  %255 = mul i64 %80, %254
  %256 = add i64 %255, %77
  %257 = getelementptr inbounds float, ptr %252, i64 %256
  %258 = load <4 x float>, ptr %257, align 16, !invariant.load !1
  %259 = call i64 @llvm.smax.i64(i64 %250, i64 1)
  br label %260

260:                                              ; preds = %266, %248
  %261 = phi i64 [ 1, %248 ], [ %269, %266 ]
  %262 = phi <4 x float> [ %258, %248 ], [ %275, %266 ]
  %263 = icmp slt i64 %261, %259
  br i1 %263, label %264, label %265

264:                                              ; preds = %260
  br label %266

265:                                              ; preds = %260
  br label %276

266:                                              ; preds = %264
  %267 = icmp eq i64 %261, %259
  %268 = add i64 %261, 1
  %269 = select i1 %267, i64 %261, i64 %268
  %270 = mul i64 %261, %253
  %271 = add i64 %270, %255
  %272 = add i64 %271, %77
  %273 = getelementptr inbounds float, ptr %252, i64 %272
  %274 = load <4 x float>, ptr %273, align 16, !invariant.load !1
  %275 = fadd contract <4 x float> %262, %274
  br label %260

276:                                              ; preds = %265
  %277 = phi <4 x float> [ %262, %265 ]
  %278 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %251, 0
  %279 = getelementptr inbounds float, ptr %278, i64 %84
  store <4 x float> %277, ptr %279, align 16
  br label %280

280:                                              ; preds = %276, %239
  br label %282

281:                                              ; preds = %60
  br label %282

282:                                              ; preds = %281, %280
  %283 = add i64 %53, %17
  %284 = mul i64 %283, 4
  %285 = trunc i64 %284 to i32
  %286 = load i64, ptr %20, align 8
  %287 = icmp slt i64 %283, %286
  br i1 %287, label %288, label %506

288:                                              ; preds = %282
  %289 = load { i64, i64 }, ptr %6, align 8
  %290 = extractvalue { i64, i64 } %289, 1
  %291 = trunc i64 %290 to i32
  %292 = icmp eq i32 %291, 0
  %293 = select i1 %292, i32 1, i32 %291
  %294 = icmp eq i32 %293, 0
  %295 = select i1 %294, i32 1, i32 %293
  %296 = udiv i32 %285, %295
  %297 = select i1 %294, i32 0, i32 %296
  %298 = urem i32 %285, %295
  %299 = select i1 %294, i32 0, i32 %298
  %300 = select i1 %292, i32 0, i32 %297
  %301 = select i1 %292, i32 0, i32 %299
  %302 = zext i32 %301 to i64
  %303 = trunc i64 %302 to i32
  %304 = add i64 %302, 1
  %305 = zext i32 %300 to i64
  %306 = trunc i64 %305 to i32
  %307 = mul i32 %306, 512
  %308 = add i32 %307, %303
  %309 = sext i32 %308 to i64
  %310 = add i64 %305, 1
  %311 = add i64 %302, 4
  %312 = load i64, ptr %8, align 8
  %313 = icmp sgt i64 %311, %312
  br i1 %313, label %314, label %473

314:                                              ; preds = %288
  %315 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %316 = load i64, ptr %4, align 8
  %317 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %318 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %315, 0
  %319 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %315, 1, 1, 0
  %320 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %315, 1, 1, 1
  %321 = mul i64 %305, %320
  %322 = add i64 %321, %302
  %323 = getelementptr inbounds float, ptr %318, i64 %322
  %324 = load float, ptr %323, align 4, !invariant.load !1
  %325 = call i64 @llvm.smax.i64(i64 %316, i64 1)
  br label %326

326:                                              ; preds = %332, %314
  %327 = phi i64 [ 1, %314 ], [ %335, %332 ]
  %328 = phi float [ %324, %314 ], [ %341, %332 ]
  %329 = icmp slt i64 %327, %325
  br i1 %329, label %330, label %331

330:                                              ; preds = %326
  br label %332

331:                                              ; preds = %326
  br label %342

332:                                              ; preds = %330
  %333 = icmp eq i64 %327, %325
  %334 = add i64 %327, 1
  %335 = select i1 %333, i64 %327, i64 %334
  %336 = mul i64 %327, %319
  %337 = add i64 %336, %321
  %338 = add i64 %337, %302
  %339 = getelementptr inbounds float, ptr %318, i64 %338
  %340 = load float, ptr %339, align 4, !invariant.load !1
  %341 = fadd contract float %328, %340
  br label %326

342:                                              ; preds = %331
  %343 = phi float [ %328, %331 ]
  %344 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %317, 0
  %345 = getelementptr inbounds float, ptr %344, i64 %309
  store float %343, ptr %345, align 4
  %346 = load { i64, i64 }, ptr %6, align 8
  %347 = extractvalue { i64, i64 } %346, 1
  %348 = icmp sge i64 %304, %347
  %349 = select i1 %348, i64 0, i64 %304
  %350 = select i1 %348, i64 %310, i64 %305
  %351 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %352 = load i64, ptr %4, align 8
  %353 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %354 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %351, 0
  %355 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %351, 1, 1, 0
  %356 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %351, 1, 1, 1
  %357 = mul i64 %350, %356
  %358 = add i64 %357, %349
  %359 = getelementptr inbounds float, ptr %354, i64 %358
  %360 = load float, ptr %359, align 4, !invariant.load !1
  %361 = call i64 @llvm.smax.i64(i64 %352, i64 1)
  br label %362

362:                                              ; preds = %368, %342
  %363 = phi i64 [ 1, %342 ], [ %371, %368 ]
  %364 = phi float [ %360, %342 ], [ %377, %368 ]
  %365 = icmp slt i64 %363, %361
  br i1 %365, label %366, label %367

366:                                              ; preds = %362
  br label %368

367:                                              ; preds = %362
  br label %378

368:                                              ; preds = %366
  %369 = icmp eq i64 %363, %361
  %370 = add i64 %363, 1
  %371 = select i1 %369, i64 %363, i64 %370
  %372 = mul i64 %363, %355
  %373 = add i64 %372, %357
  %374 = add i64 %373, %349
  %375 = getelementptr inbounds float, ptr %354, i64 %374
  %376 = load float, ptr %375, align 4, !invariant.load !1
  %377 = fadd contract float %364, %376
  br label %362

378:                                              ; preds = %367
  %379 = phi float [ %364, %367 ]
  %380 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %353, 0
  %381 = trunc i64 %350 to i32
  %382 = mul i32 %381, 512
  %383 = trunc i64 %349 to i32
  %384 = add i32 %382, %383
  %385 = sext i32 %384 to i64
  %386 = getelementptr inbounds float, ptr %380, i64 %385
  store float %379, ptr %386, align 4
  %387 = load { i64, i64 }, ptr %6, align 8
  %388 = add i64 %349, 1
  %389 = extractvalue { i64, i64 } %387, 1
  %390 = icmp sge i64 %388, %389
  %391 = select i1 %390, i64 0, i64 %388
  %392 = add i64 %350, 1
  %393 = select i1 %390, i64 %392, i64 %350
  %394 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %395 = load i64, ptr %4, align 8
  %396 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %397 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %394, 0
  %398 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %394, 1, 1, 0
  %399 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %394, 1, 1, 1
  %400 = mul i64 %393, %399
  %401 = add i64 %400, %391
  %402 = getelementptr inbounds float, ptr %397, i64 %401
  %403 = load float, ptr %402, align 4, !invariant.load !1
  %404 = call i64 @llvm.smax.i64(i64 %395, i64 1)
  br label %405

405:                                              ; preds = %411, %378
  %406 = phi i64 [ 1, %378 ], [ %414, %411 ]
  %407 = phi float [ %403, %378 ], [ %420, %411 ]
  %408 = icmp slt i64 %406, %404
  br i1 %408, label %409, label %410

409:                                              ; preds = %405
  br label %411

410:                                              ; preds = %405
  br label %421

411:                                              ; preds = %409
  %412 = icmp eq i64 %406, %404
  %413 = add i64 %406, 1
  %414 = select i1 %412, i64 %406, i64 %413
  %415 = mul i64 %406, %398
  %416 = add i64 %415, %400
  %417 = add i64 %416, %391
  %418 = getelementptr inbounds float, ptr %397, i64 %417
  %419 = load float, ptr %418, align 4, !invariant.load !1
  %420 = fadd contract float %407, %419
  br label %405

421:                                              ; preds = %410
  %422 = phi float [ %407, %410 ]
  %423 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %396, 0
  %424 = trunc i64 %393 to i32
  %425 = mul i32 %424, 512
  %426 = trunc i64 %391 to i32
  %427 = add i32 %425, %426
  %428 = sext i32 %427 to i64
  %429 = getelementptr inbounds float, ptr %423, i64 %428
  store float %422, ptr %429, align 4
  %430 = load { i64, i64 }, ptr %6, align 8
  %431 = add i64 %391, 1
  %432 = extractvalue { i64, i64 } %430, 1
  %433 = icmp sge i64 %431, %432
  %434 = select i1 %433, i64 0, i64 %431
  %435 = add i64 %393, 1
  %436 = select i1 %433, i64 %435, i64 %393
  %437 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %438 = load i64, ptr %4, align 8
  %439 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %440 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %437, 0
  %441 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %437, 1, 1, 0
  %442 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %437, 1, 1, 1
  %443 = mul i64 %436, %442
  %444 = add i64 %443, %434
  %445 = getelementptr inbounds float, ptr %440, i64 %444
  %446 = load float, ptr %445, align 4, !invariant.load !1
  %447 = call i64 @llvm.smax.i64(i64 %438, i64 1)
  br label %448

448:                                              ; preds = %454, %421
  %449 = phi i64 [ 1, %421 ], [ %457, %454 ]
  %450 = phi float [ %446, %421 ], [ %463, %454 ]
  %451 = icmp slt i64 %449, %447
  br i1 %451, label %452, label %453

452:                                              ; preds = %448
  br label %454

453:                                              ; preds = %448
  br label %464

454:                                              ; preds = %452
  %455 = icmp eq i64 %449, %447
  %456 = add i64 %449, 1
  %457 = select i1 %455, i64 %449, i64 %456
  %458 = mul i64 %449, %441
  %459 = add i64 %458, %443
  %460 = add i64 %459, %434
  %461 = getelementptr inbounds float, ptr %440, i64 %460
  %462 = load float, ptr %461, align 4, !invariant.load !1
  %463 = fadd contract float %450, %462
  br label %448

464:                                              ; preds = %453
  %465 = phi float [ %450, %453 ]
  %466 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %439, 0
  %467 = trunc i64 %436 to i32
  %468 = mul i32 %467, 512
  %469 = trunc i64 %434 to i32
  %470 = add i32 %468, %469
  %471 = sext i32 %470 to i64
  %472 = getelementptr inbounds float, ptr %466, i64 %471
  store float %465, ptr %472, align 4
  br label %505

473:                                              ; preds = %288
  %474 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %475 = load i64, ptr %4, align 8
  %476 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %477 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %474, 0
  %478 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %474, 1, 1, 0
  %479 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %474, 1, 1, 1
  %480 = mul i64 %305, %479
  %481 = add i64 %480, %302
  %482 = getelementptr inbounds float, ptr %477, i64 %481
  %483 = load <4 x float>, ptr %482, align 16, !invariant.load !1
  %484 = call i64 @llvm.smax.i64(i64 %475, i64 1)
  br label %485

485:                                              ; preds = %491, %473
  %486 = phi i64 [ 1, %473 ], [ %494, %491 ]
  %487 = phi <4 x float> [ %483, %473 ], [ %500, %491 ]
  %488 = icmp slt i64 %486, %484
  br i1 %488, label %489, label %490

489:                                              ; preds = %485
  br label %491

490:                                              ; preds = %485
  br label %501

491:                                              ; preds = %489
  %492 = icmp eq i64 %486, %484
  %493 = add i64 %486, 1
  %494 = select i1 %492, i64 %486, i64 %493
  %495 = mul i64 %486, %478
  %496 = add i64 %495, %480
  %497 = add i64 %496, %302
  %498 = getelementptr inbounds float, ptr %477, i64 %497
  %499 = load <4 x float>, ptr %498, align 16, !invariant.load !1
  %500 = fadd contract <4 x float> %487, %499
  br label %485

501:                                              ; preds = %490
  %502 = phi <4 x float> [ %487, %490 ]
  %503 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %476, 0
  %504 = getelementptr inbounds float, ptr %503, i64 %309
  store <4 x float> %502, ptr %504, align 16
  br label %505

505:                                              ; preds = %501, %464
  br label %507

506:                                              ; preds = %282
  br label %507

507:                                              ; preds = %506, %505
  %508 = add i64 %53, %19
  %509 = mul i64 %508, 4
  %510 = trunc i64 %509 to i32
  %511 = load i64, ptr %20, align 8
  %512 = icmp slt i64 %508, %511
  br i1 %512, label %513, label %731

513:                                              ; preds = %507
  %514 = load { i64, i64 }, ptr %6, align 8
  %515 = extractvalue { i64, i64 } %514, 1
  %516 = trunc i64 %515 to i32
  %517 = icmp eq i32 %516, 0
  %518 = select i1 %517, i32 1, i32 %516
  %519 = icmp eq i32 %518, 0
  %520 = select i1 %519, i32 1, i32 %518
  %521 = udiv i32 %510, %520
  %522 = select i1 %519, i32 0, i32 %521
  %523 = urem i32 %510, %520
  %524 = select i1 %519, i32 0, i32 %523
  %525 = select i1 %517, i32 0, i32 %522
  %526 = select i1 %517, i32 0, i32 %524
  %527 = zext i32 %526 to i64
  %528 = trunc i64 %527 to i32
  %529 = add i64 %527, 1
  %530 = zext i32 %525 to i64
  %531 = trunc i64 %530 to i32
  %532 = mul i32 %531, 512
  %533 = add i32 %532, %528
  %534 = sext i32 %533 to i64
  %535 = add i64 %530, 1
  %536 = add i64 %527, 4
  %537 = load i64, ptr %8, align 8
  %538 = icmp sgt i64 %536, %537
  br i1 %538, label %539, label %698

539:                                              ; preds = %513
  %540 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %541 = load i64, ptr %4, align 8
  %542 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %543 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %540, 0
  %544 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %540, 1, 1, 0
  %545 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %540, 1, 1, 1
  %546 = mul i64 %530, %545
  %547 = add i64 %546, %527
  %548 = getelementptr inbounds float, ptr %543, i64 %547
  %549 = load float, ptr %548, align 4, !invariant.load !1
  %550 = call i64 @llvm.smax.i64(i64 %541, i64 1)
  br label %551

551:                                              ; preds = %557, %539
  %552 = phi i64 [ 1, %539 ], [ %560, %557 ]
  %553 = phi float [ %549, %539 ], [ %566, %557 ]
  %554 = icmp slt i64 %552, %550
  br i1 %554, label %555, label %556

555:                                              ; preds = %551
  br label %557

556:                                              ; preds = %551
  br label %567

557:                                              ; preds = %555
  %558 = icmp eq i64 %552, %550
  %559 = add i64 %552, 1
  %560 = select i1 %558, i64 %552, i64 %559
  %561 = mul i64 %552, %544
  %562 = add i64 %561, %546
  %563 = add i64 %562, %527
  %564 = getelementptr inbounds float, ptr %543, i64 %563
  %565 = load float, ptr %564, align 4, !invariant.load !1
  %566 = fadd contract float %553, %565
  br label %551

567:                                              ; preds = %556
  %568 = phi float [ %553, %556 ]
  %569 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %542, 0
  %570 = getelementptr inbounds float, ptr %569, i64 %534
  store float %568, ptr %570, align 4
  %571 = load { i64, i64 }, ptr %6, align 8
  %572 = extractvalue { i64, i64 } %571, 1
  %573 = icmp sge i64 %529, %572
  %574 = select i1 %573, i64 0, i64 %529
  %575 = select i1 %573, i64 %535, i64 %530
  %576 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %577 = load i64, ptr %4, align 8
  %578 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %579 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %576, 0
  %580 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %576, 1, 1, 0
  %581 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %576, 1, 1, 1
  %582 = mul i64 %575, %581
  %583 = add i64 %582, %574
  %584 = getelementptr inbounds float, ptr %579, i64 %583
  %585 = load float, ptr %584, align 4, !invariant.load !1
  %586 = call i64 @llvm.smax.i64(i64 %577, i64 1)
  br label %587

587:                                              ; preds = %593, %567
  %588 = phi i64 [ 1, %567 ], [ %596, %593 ]
  %589 = phi float [ %585, %567 ], [ %602, %593 ]
  %590 = icmp slt i64 %588, %586
  br i1 %590, label %591, label %592

591:                                              ; preds = %587
  br label %593

592:                                              ; preds = %587
  br label %603

593:                                              ; preds = %591
  %594 = icmp eq i64 %588, %586
  %595 = add i64 %588, 1
  %596 = select i1 %594, i64 %588, i64 %595
  %597 = mul i64 %588, %580
  %598 = add i64 %597, %582
  %599 = add i64 %598, %574
  %600 = getelementptr inbounds float, ptr %579, i64 %599
  %601 = load float, ptr %600, align 4, !invariant.load !1
  %602 = fadd contract float %589, %601
  br label %587

603:                                              ; preds = %592
  %604 = phi float [ %589, %592 ]
  %605 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %578, 0
  %606 = trunc i64 %575 to i32
  %607 = mul i32 %606, 512
  %608 = trunc i64 %574 to i32
  %609 = add i32 %607, %608
  %610 = sext i32 %609 to i64
  %611 = getelementptr inbounds float, ptr %605, i64 %610
  store float %604, ptr %611, align 4
  %612 = load { i64, i64 }, ptr %6, align 8
  %613 = add i64 %574, 1
  %614 = extractvalue { i64, i64 } %612, 1
  %615 = icmp sge i64 %613, %614
  %616 = select i1 %615, i64 0, i64 %613
  %617 = add i64 %575, 1
  %618 = select i1 %615, i64 %617, i64 %575
  %619 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %620 = load i64, ptr %4, align 8
  %621 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %622 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %619, 0
  %623 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %619, 1, 1, 0
  %624 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %619, 1, 1, 1
  %625 = mul i64 %618, %624
  %626 = add i64 %625, %616
  %627 = getelementptr inbounds float, ptr %622, i64 %626
  %628 = load float, ptr %627, align 4, !invariant.load !1
  %629 = call i64 @llvm.smax.i64(i64 %620, i64 1)
  br label %630

630:                                              ; preds = %636, %603
  %631 = phi i64 [ 1, %603 ], [ %639, %636 ]
  %632 = phi float [ %628, %603 ], [ %645, %636 ]
  %633 = icmp slt i64 %631, %629
  br i1 %633, label %634, label %635

634:                                              ; preds = %630
  br label %636

635:                                              ; preds = %630
  br label %646

636:                                              ; preds = %634
  %637 = icmp eq i64 %631, %629
  %638 = add i64 %631, 1
  %639 = select i1 %637, i64 %631, i64 %638
  %640 = mul i64 %631, %623
  %641 = add i64 %640, %625
  %642 = add i64 %641, %616
  %643 = getelementptr inbounds float, ptr %622, i64 %642
  %644 = load float, ptr %643, align 4, !invariant.load !1
  %645 = fadd contract float %632, %644
  br label %630

646:                                              ; preds = %635
  %647 = phi float [ %632, %635 ]
  %648 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %621, 0
  %649 = trunc i64 %618 to i32
  %650 = mul i32 %649, 512
  %651 = trunc i64 %616 to i32
  %652 = add i32 %650, %651
  %653 = sext i32 %652 to i64
  %654 = getelementptr inbounds float, ptr %648, i64 %653
  store float %647, ptr %654, align 4
  %655 = load { i64, i64 }, ptr %6, align 8
  %656 = add i64 %616, 1
  %657 = extractvalue { i64, i64 } %655, 1
  %658 = icmp sge i64 %656, %657
  %659 = select i1 %658, i64 0, i64 %656
  %660 = add i64 %618, 1
  %661 = select i1 %658, i64 %660, i64 %618
  %662 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %663 = load i64, ptr %4, align 8
  %664 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %665 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %662, 0
  %666 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %662, 1, 1, 0
  %667 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %662, 1, 1, 1
  %668 = mul i64 %661, %667
  %669 = add i64 %668, %659
  %670 = getelementptr inbounds float, ptr %665, i64 %669
  %671 = load float, ptr %670, align 4, !invariant.load !1
  %672 = call i64 @llvm.smax.i64(i64 %663, i64 1)
  br label %673

673:                                              ; preds = %679, %646
  %674 = phi i64 [ 1, %646 ], [ %682, %679 ]
  %675 = phi float [ %671, %646 ], [ %688, %679 ]
  %676 = icmp slt i64 %674, %672
  br i1 %676, label %677, label %678

677:                                              ; preds = %673
  br label %679

678:                                              ; preds = %673
  br label %689

679:                                              ; preds = %677
  %680 = icmp eq i64 %674, %672
  %681 = add i64 %674, 1
  %682 = select i1 %680, i64 %674, i64 %681
  %683 = mul i64 %674, %666
  %684 = add i64 %683, %668
  %685 = add i64 %684, %659
  %686 = getelementptr inbounds float, ptr %665, i64 %685
  %687 = load float, ptr %686, align 4, !invariant.load !1
  %688 = fadd contract float %675, %687
  br label %673

689:                                              ; preds = %678
  %690 = phi float [ %675, %678 ]
  %691 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %664, 0
  %692 = trunc i64 %661 to i32
  %693 = mul i32 %692, 512
  %694 = trunc i64 %659 to i32
  %695 = add i32 %693, %694
  %696 = sext i32 %695 to i64
  %697 = getelementptr inbounds float, ptr %691, i64 %696
  store float %690, ptr %697, align 4
  br label %730

698:                                              ; preds = %513
  %699 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %700 = load i64, ptr %4, align 8
  %701 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %702 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %699, 0
  %703 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %699, 1, 1, 0
  %704 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %699, 1, 1, 1
  %705 = mul i64 %530, %704
  %706 = add i64 %705, %527
  %707 = getelementptr inbounds float, ptr %702, i64 %706
  %708 = load <4 x float>, ptr %707, align 16, !invariant.load !1
  %709 = call i64 @llvm.smax.i64(i64 %700, i64 1)
  br label %710

710:                                              ; preds = %716, %698
  %711 = phi i64 [ 1, %698 ], [ %719, %716 ]
  %712 = phi <4 x float> [ %708, %698 ], [ %725, %716 ]
  %713 = icmp slt i64 %711, %709
  br i1 %713, label %714, label %715

714:                                              ; preds = %710
  br label %716

715:                                              ; preds = %710
  br label %726

716:                                              ; preds = %714
  %717 = icmp eq i64 %711, %709
  %718 = add i64 %711, 1
  %719 = select i1 %717, i64 %711, i64 %718
  %720 = mul i64 %711, %703
  %721 = add i64 %720, %705
  %722 = add i64 %721, %527
  %723 = getelementptr inbounds float, ptr %702, i64 %722
  %724 = load <4 x float>, ptr %723, align 16, !invariant.load !1
  %725 = fadd contract <4 x float> %712, %724
  br label %710

726:                                              ; preds = %715
  %727 = phi <4 x float> [ %712, %715 ]
  %728 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %701, 0
  %729 = getelementptr inbounds float, ptr %728, i64 %534
  store <4 x float> %727, ptr %729, align 16
  br label %730

730:                                              ; preds = %726, %689
  br label %732

731:                                              ; preds = %507
  br label %732

732:                                              ; preds = %731, %730
  %733 = add i64 %53, %18
  %734 = mul i64 %733, 4
  %735 = trunc i64 %734 to i32
  %736 = load i64, ptr %20, align 8
  %737 = icmp slt i64 %733, %736
  br i1 %737, label %738, label %956

738:                                              ; preds = %732
  %739 = load { i64, i64 }, ptr %6, align 8
  %740 = extractvalue { i64, i64 } %739, 1
  %741 = trunc i64 %740 to i32
  %742 = icmp eq i32 %741, 0
  %743 = select i1 %742, i32 1, i32 %741
  %744 = icmp eq i32 %743, 0
  %745 = select i1 %744, i32 1, i32 %743
  %746 = udiv i32 %735, %745
  %747 = select i1 %744, i32 0, i32 %746
  %748 = urem i32 %735, %745
  %749 = select i1 %744, i32 0, i32 %748
  %750 = select i1 %742, i32 0, i32 %747
  %751 = select i1 %742, i32 0, i32 %749
  %752 = zext i32 %751 to i64
  %753 = trunc i64 %752 to i32
  %754 = add i64 %752, 1
  %755 = zext i32 %750 to i64
  %756 = trunc i64 %755 to i32
  %757 = mul i32 %756, 512
  %758 = add i32 %757, %753
  %759 = sext i32 %758 to i64
  %760 = add i64 %755, 1
  %761 = add i64 %752, 4
  %762 = load i64, ptr %8, align 8
  %763 = icmp sgt i64 %761, %762
  br i1 %763, label %764, label %923

764:                                              ; preds = %738
  %765 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %766 = load i64, ptr %4, align 8
  %767 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %768 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %765, 0
  %769 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %765, 1, 1, 0
  %770 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %765, 1, 1, 1
  %771 = mul i64 %755, %770
  %772 = add i64 %771, %752
  %773 = getelementptr inbounds float, ptr %768, i64 %772
  %774 = load float, ptr %773, align 4, !invariant.load !1
  %775 = call i64 @llvm.smax.i64(i64 %766, i64 1)
  br label %776

776:                                              ; preds = %782, %764
  %777 = phi i64 [ 1, %764 ], [ %785, %782 ]
  %778 = phi float [ %774, %764 ], [ %791, %782 ]
  %779 = icmp slt i64 %777, %775
  br i1 %779, label %780, label %781

780:                                              ; preds = %776
  br label %782

781:                                              ; preds = %776
  br label %792

782:                                              ; preds = %780
  %783 = icmp eq i64 %777, %775
  %784 = add i64 %777, 1
  %785 = select i1 %783, i64 %777, i64 %784
  %786 = mul i64 %777, %769
  %787 = add i64 %786, %771
  %788 = add i64 %787, %752
  %789 = getelementptr inbounds float, ptr %768, i64 %788
  %790 = load float, ptr %789, align 4, !invariant.load !1
  %791 = fadd contract float %778, %790
  br label %776

792:                                              ; preds = %781
  %793 = phi float [ %778, %781 ]
  %794 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %767, 0
  %795 = getelementptr inbounds float, ptr %794, i64 %759
  store float %793, ptr %795, align 4
  %796 = load { i64, i64 }, ptr %6, align 8
  %797 = extractvalue { i64, i64 } %796, 1
  %798 = icmp sge i64 %754, %797
  %799 = select i1 %798, i64 0, i64 %754
  %800 = select i1 %798, i64 %760, i64 %755
  %801 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %802 = load i64, ptr %4, align 8
  %803 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %804 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %801, 0
  %805 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %801, 1, 1, 0
  %806 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %801, 1, 1, 1
  %807 = mul i64 %800, %806
  %808 = add i64 %807, %799
  %809 = getelementptr inbounds float, ptr %804, i64 %808
  %810 = load float, ptr %809, align 4, !invariant.load !1
  %811 = call i64 @llvm.smax.i64(i64 %802, i64 1)
  br label %812

812:                                              ; preds = %818, %792
  %813 = phi i64 [ 1, %792 ], [ %821, %818 ]
  %814 = phi float [ %810, %792 ], [ %827, %818 ]
  %815 = icmp slt i64 %813, %811
  br i1 %815, label %816, label %817

816:                                              ; preds = %812
  br label %818

817:                                              ; preds = %812
  br label %828

818:                                              ; preds = %816
  %819 = icmp eq i64 %813, %811
  %820 = add i64 %813, 1
  %821 = select i1 %819, i64 %813, i64 %820
  %822 = mul i64 %813, %805
  %823 = add i64 %822, %807
  %824 = add i64 %823, %799
  %825 = getelementptr inbounds float, ptr %804, i64 %824
  %826 = load float, ptr %825, align 4, !invariant.load !1
  %827 = fadd contract float %814, %826
  br label %812

828:                                              ; preds = %817
  %829 = phi float [ %814, %817 ]
  %830 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %803, 0
  %831 = trunc i64 %800 to i32
  %832 = mul i32 %831, 512
  %833 = trunc i64 %799 to i32
  %834 = add i32 %832, %833
  %835 = sext i32 %834 to i64
  %836 = getelementptr inbounds float, ptr %830, i64 %835
  store float %829, ptr %836, align 4
  %837 = load { i64, i64 }, ptr %6, align 8
  %838 = add i64 %799, 1
  %839 = extractvalue { i64, i64 } %837, 1
  %840 = icmp sge i64 %838, %839
  %841 = select i1 %840, i64 0, i64 %838
  %842 = add i64 %800, 1
  %843 = select i1 %840, i64 %842, i64 %800
  %844 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %845 = load i64, ptr %4, align 8
  %846 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %847 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %844, 0
  %848 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %844, 1, 1, 0
  %849 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %844, 1, 1, 1
  %850 = mul i64 %843, %849
  %851 = add i64 %850, %841
  %852 = getelementptr inbounds float, ptr %847, i64 %851
  %853 = load float, ptr %852, align 4, !invariant.load !1
  %854 = call i64 @llvm.smax.i64(i64 %845, i64 1)
  br label %855

855:                                              ; preds = %861, %828
  %856 = phi i64 [ 1, %828 ], [ %864, %861 ]
  %857 = phi float [ %853, %828 ], [ %870, %861 ]
  %858 = icmp slt i64 %856, %854
  br i1 %858, label %859, label %860

859:                                              ; preds = %855
  br label %861

860:                                              ; preds = %855
  br label %871

861:                                              ; preds = %859
  %862 = icmp eq i64 %856, %854
  %863 = add i64 %856, 1
  %864 = select i1 %862, i64 %856, i64 %863
  %865 = mul i64 %856, %848
  %866 = add i64 %865, %850
  %867 = add i64 %866, %841
  %868 = getelementptr inbounds float, ptr %847, i64 %867
  %869 = load float, ptr %868, align 4, !invariant.load !1
  %870 = fadd contract float %857, %869
  br label %855

871:                                              ; preds = %860
  %872 = phi float [ %857, %860 ]
  %873 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %846, 0
  %874 = trunc i64 %843 to i32
  %875 = mul i32 %874, 512
  %876 = trunc i64 %841 to i32
  %877 = add i32 %875, %876
  %878 = sext i32 %877 to i64
  %879 = getelementptr inbounds float, ptr %873, i64 %878
  store float %872, ptr %879, align 4
  %880 = load { i64, i64 }, ptr %6, align 8
  %881 = add i64 %841, 1
  %882 = extractvalue { i64, i64 } %880, 1
  %883 = icmp sge i64 %881, %882
  %884 = select i1 %883, i64 0, i64 %881
  %885 = add i64 %843, 1
  %886 = select i1 %883, i64 %885, i64 %843
  %887 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %888 = load i64, ptr %4, align 8
  %889 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %890 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %887, 0
  %891 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %887, 1, 1, 0
  %892 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %887, 1, 1, 1
  %893 = mul i64 %886, %892
  %894 = add i64 %893, %884
  %895 = getelementptr inbounds float, ptr %890, i64 %894
  %896 = load float, ptr %895, align 4, !invariant.load !1
  %897 = call i64 @llvm.smax.i64(i64 %888, i64 1)
  br label %898

898:                                              ; preds = %904, %871
  %899 = phi i64 [ 1, %871 ], [ %907, %904 ]
  %900 = phi float [ %896, %871 ], [ %913, %904 ]
  %901 = icmp slt i64 %899, %897
  br i1 %901, label %902, label %903

902:                                              ; preds = %898
  br label %904

903:                                              ; preds = %898
  br label %914

904:                                              ; preds = %902
  %905 = icmp eq i64 %899, %897
  %906 = add i64 %899, 1
  %907 = select i1 %905, i64 %899, i64 %906
  %908 = mul i64 %899, %891
  %909 = add i64 %908, %893
  %910 = add i64 %909, %884
  %911 = getelementptr inbounds float, ptr %890, i64 %910
  %912 = load float, ptr %911, align 4, !invariant.load !1
  %913 = fadd contract float %900, %912
  br label %898

914:                                              ; preds = %903
  %915 = phi float [ %900, %903 ]
  %916 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %889, 0
  %917 = trunc i64 %886 to i32
  %918 = mul i32 %917, 512
  %919 = trunc i64 %884 to i32
  %920 = add i32 %918, %919
  %921 = sext i32 %920 to i64
  %922 = getelementptr inbounds float, ptr %916, i64 %921
  store float %915, ptr %922, align 4
  br label %955

923:                                              ; preds = %738
  %924 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %925 = load i64, ptr %4, align 8
  %926 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %927 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %924, 0
  %928 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %924, 1, 1, 0
  %929 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %924, 1, 1, 1
  %930 = mul i64 %755, %929
  %931 = add i64 %930, %752
  %932 = getelementptr inbounds float, ptr %927, i64 %931
  %933 = load <4 x float>, ptr %932, align 16, !invariant.load !1
  %934 = call i64 @llvm.smax.i64(i64 %925, i64 1)
  br label %935

935:                                              ; preds = %941, %923
  %936 = phi i64 [ 1, %923 ], [ %944, %941 ]
  %937 = phi <4 x float> [ %933, %923 ], [ %950, %941 ]
  %938 = icmp slt i64 %936, %934
  br i1 %938, label %939, label %940

939:                                              ; preds = %935
  br label %941

940:                                              ; preds = %935
  br label %951

941:                                              ; preds = %939
  %942 = icmp eq i64 %936, %934
  %943 = add i64 %936, 1
  %944 = select i1 %942, i64 %936, i64 %943
  %945 = mul i64 %936, %928
  %946 = add i64 %945, %930
  %947 = add i64 %946, %752
  %948 = getelementptr inbounds float, ptr %927, i64 %947
  %949 = load <4 x float>, ptr %948, align 16, !invariant.load !1
  %950 = fadd contract <4 x float> %937, %949
  br label %935

951:                                              ; preds = %940
  %952 = phi <4 x float> [ %937, %940 ]
  %953 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %926, 0
  %954 = getelementptr inbounds float, ptr %953, i64 %759
  store <4 x float> %952, ptr %954, align 16
  br label %955

955:                                              ; preds = %951, %914
  br label %957

956:                                              ; preds = %732
  br label %957

957:                                              ; preds = %956, %955
  br label %29

958:                                              ; preds = %58
  %959 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %960 = load i64, ptr %959, align 8
  %961 = icmp slt i64 %14, %960
  br i1 %961, label %962, label %1017

962:                                              ; preds = %958
  %963 = load i64, ptr %7, align 8
  %964 = add i64 %963, %14
  %965 = load { i64, i64 }, ptr %6, align 8
  %966 = trunc i64 %964 to i32
  %967 = extractvalue { i64, i64 } %965, 1
  %968 = trunc i64 %967 to i32
  %969 = icmp eq i32 %968, 0
  %970 = select i1 %969, i32 1, i32 %968
  %971 = icmp eq i32 %970, 0
  %972 = select i1 %971, i32 1, i32 %970
  %973 = udiv i32 %966, %972
  %974 = select i1 %971, i32 0, i32 %973
  %975 = urem i32 %966, %972
  %976 = select i1 %971, i32 0, i32 %975
  %977 = select i1 %969, i32 0, i32 %974
  %978 = select i1 %969, i32 0, i32 %976
  %979 = zext i32 %977 to i64
  %980 = zext i32 %978 to i64
  %981 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %982 = load i64, ptr %4, align 8
  %983 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %984 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %981, 0
  %985 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %981, 1, 1, 0
  %986 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %981, 1, 1, 1
  %987 = mul i64 %979, %986
  %988 = add i64 %987, %980
  %989 = getelementptr inbounds float, ptr %984, i64 %988
  %990 = load float, ptr %989, align 4, !invariant.load !1
  %991 = call i64 @llvm.smax.i64(i64 %982, i64 1)
  br label %992

992:                                              ; preds = %998, %962
  %993 = phi i64 [ 1, %962 ], [ %1001, %998 ]
  %994 = phi float [ %990, %962 ], [ %1007, %998 ]
  %995 = icmp slt i64 %993, %991
  br i1 %995, label %996, label %997

996:                                              ; preds = %992
  br label %998

997:                                              ; preds = %992
  br label %1008

998:                                              ; preds = %996
  %999 = icmp eq i64 %993, %991
  %1000 = add i64 %993, 1
  %1001 = select i1 %999, i64 %993, i64 %1000
  %1002 = mul i64 %993, %985
  %1003 = add i64 %1002, %987
  %1004 = add i64 %1003, %980
  %1005 = getelementptr inbounds float, ptr %984, i64 %1004
  %1006 = load float, ptr %1005, align 4, !invariant.load !1
  %1007 = fadd contract float %994, %1006
  br label %992

1008:                                             ; preds = %997
  %1009 = phi float [ %994, %997 ]
  %1010 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %983, 0
  %1011 = trunc i64 %979 to i32
  %1012 = mul i32 %1011, 512
  %1013 = trunc i64 %980 to i32
  %1014 = add i32 %1012, %1013
  %1015 = sext i32 %1014 to i64
  %1016 = getelementptr inbounds float, ptr %1010, i64 %1015
  store float %1009, ptr %1016, align 4
  br label %1018

1017:                                             ; preds = %958
  br label %1018

1018:                                             ; preds = %1017, %1008
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
