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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w8_b256_gs_True_6942d4bb(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

29:                                               ; preds = %1645, %1
  %30 = phi i64 [ %24, %1 ], [ %54, %1645 ]
  %31 = phi i64 [ 0, %1 ], [ %55, %1645 ]
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
  %56 = mul i64 %53, 8
  %57 = trunc i64 %56 to i32
  br i1 %52, label %58, label %59

58:                                               ; preds = %51
  br label %1646

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59
  %61 = load i64, ptr %20, align 8
  %62 = icmp slt i64 %53, %61
  br i1 %62, label %63, label %453

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
  %86 = add i64 %77, 8
  %87 = load i64, ptr %8, align 8
  %88 = icmp sgt i64 %86, %87
  br i1 %88, label %89, label %420

89:                                               ; preds = %63
  %90 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %91 = load i64, ptr %4, align 8
  %92 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %93 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 0
  %94 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 1, 1, 0
  %95 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 1, 1, 1
  %96 = mul i64 %80, %95
  %97 = add i64 %96, %77
  %98 = getelementptr inbounds bfloat, ptr %93, i64 %97
  %99 = load bfloat, ptr %98, align 2, !invariant.load !1
  %100 = call i64 @llvm.smax.i64(i64 %91, i64 1)
  br label %101

101:                                              ; preds = %107, %89
  %102 = phi i64 [ 1, %89 ], [ %110, %107 ]
  %103 = phi bfloat [ %99, %89 ], [ %116, %107 ]
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
  %114 = getelementptr inbounds bfloat, ptr %93, i64 %113
  %115 = load bfloat, ptr %114, align 2, !invariant.load !1
  %116 = fadd contract bfloat %103, %115
  br label %101

117:                                              ; preds = %106
  %118 = phi bfloat [ %103, %106 ]
  %119 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %92, 0
  %120 = getelementptr inbounds bfloat, ptr %119, i64 %84
  store bfloat %118, ptr %120, align 2
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
  %134 = getelementptr inbounds bfloat, ptr %129, i64 %133
  %135 = load bfloat, ptr %134, align 2, !invariant.load !1
  %136 = call i64 @llvm.smax.i64(i64 %127, i64 1)
  br label %137

137:                                              ; preds = %143, %117
  %138 = phi i64 [ 1, %117 ], [ %146, %143 ]
  %139 = phi bfloat [ %135, %117 ], [ %152, %143 ]
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
  %150 = getelementptr inbounds bfloat, ptr %129, i64 %149
  %151 = load bfloat, ptr %150, align 2, !invariant.load !1
  %152 = fadd contract bfloat %139, %151
  br label %137

153:                                              ; preds = %142
  %154 = phi bfloat [ %139, %142 ]
  %155 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %128, 0
  %156 = trunc i64 %125 to i32
  %157 = mul i32 %156, 512
  %158 = trunc i64 %124 to i32
  %159 = add i32 %157, %158
  %160 = sext i32 %159 to i64
  %161 = getelementptr inbounds bfloat, ptr %155, i64 %160
  store bfloat %154, ptr %161, align 2
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
  %177 = getelementptr inbounds bfloat, ptr %172, i64 %176
  %178 = load bfloat, ptr %177, align 2, !invariant.load !1
  %179 = call i64 @llvm.smax.i64(i64 %170, i64 1)
  br label %180

180:                                              ; preds = %186, %153
  %181 = phi i64 [ 1, %153 ], [ %189, %186 ]
  %182 = phi bfloat [ %178, %153 ], [ %195, %186 ]
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
  %193 = getelementptr inbounds bfloat, ptr %172, i64 %192
  %194 = load bfloat, ptr %193, align 2, !invariant.load !1
  %195 = fadd contract bfloat %182, %194
  br label %180

196:                                              ; preds = %185
  %197 = phi bfloat [ %182, %185 ]
  %198 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %171, 0
  %199 = trunc i64 %168 to i32
  %200 = mul i32 %199, 512
  %201 = trunc i64 %166 to i32
  %202 = add i32 %200, %201
  %203 = sext i32 %202 to i64
  %204 = getelementptr inbounds bfloat, ptr %198, i64 %203
  store bfloat %197, ptr %204, align 2
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
  %220 = getelementptr inbounds bfloat, ptr %215, i64 %219
  %221 = load bfloat, ptr %220, align 2, !invariant.load !1
  %222 = call i64 @llvm.smax.i64(i64 %213, i64 1)
  br label %223

223:                                              ; preds = %229, %196
  %224 = phi i64 [ 1, %196 ], [ %232, %229 ]
  %225 = phi bfloat [ %221, %196 ], [ %238, %229 ]
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
  %236 = getelementptr inbounds bfloat, ptr %215, i64 %235
  %237 = load bfloat, ptr %236, align 2, !invariant.load !1
  %238 = fadd contract bfloat %225, %237
  br label %223

239:                                              ; preds = %228
  %240 = phi bfloat [ %225, %228 ]
  %241 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %214, 0
  %242 = trunc i64 %211 to i32
  %243 = mul i32 %242, 512
  %244 = trunc i64 %209 to i32
  %245 = add i32 %243, %244
  %246 = sext i32 %245 to i64
  %247 = getelementptr inbounds bfloat, ptr %241, i64 %246
  store bfloat %240, ptr %247, align 2
  %248 = load { i64, i64 }, ptr %6, align 8
  %249 = add i64 %209, 1
  %250 = extractvalue { i64, i64 } %248, 1
  %251 = icmp sge i64 %249, %250
  %252 = select i1 %251, i64 0, i64 %249
  %253 = add i64 %211, 1
  %254 = select i1 %251, i64 %253, i64 %211
  %255 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %256 = load i64, ptr %4, align 8
  %257 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %258 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %255, 0
  %259 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %255, 1, 1, 0
  %260 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %255, 1, 1, 1
  %261 = mul i64 %254, %260
  %262 = add i64 %261, %252
  %263 = getelementptr inbounds bfloat, ptr %258, i64 %262
  %264 = load bfloat, ptr %263, align 2, !invariant.load !1
  %265 = call i64 @llvm.smax.i64(i64 %256, i64 1)
  br label %266

266:                                              ; preds = %272, %239
  %267 = phi i64 [ 1, %239 ], [ %275, %272 ]
  %268 = phi bfloat [ %264, %239 ], [ %281, %272 ]
  %269 = icmp slt i64 %267, %265
  br i1 %269, label %270, label %271

270:                                              ; preds = %266
  br label %272

271:                                              ; preds = %266
  br label %282

272:                                              ; preds = %270
  %273 = icmp eq i64 %267, %265
  %274 = add i64 %267, 1
  %275 = select i1 %273, i64 %267, i64 %274
  %276 = mul i64 %267, %259
  %277 = add i64 %276, %261
  %278 = add i64 %277, %252
  %279 = getelementptr inbounds bfloat, ptr %258, i64 %278
  %280 = load bfloat, ptr %279, align 2, !invariant.load !1
  %281 = fadd contract bfloat %268, %280
  br label %266

282:                                              ; preds = %271
  %283 = phi bfloat [ %268, %271 ]
  %284 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %257, 0
  %285 = trunc i64 %254 to i32
  %286 = mul i32 %285, 512
  %287 = trunc i64 %252 to i32
  %288 = add i32 %286, %287
  %289 = sext i32 %288 to i64
  %290 = getelementptr inbounds bfloat, ptr %284, i64 %289
  store bfloat %283, ptr %290, align 2
  %291 = load { i64, i64 }, ptr %6, align 8
  %292 = add i64 %252, 1
  %293 = extractvalue { i64, i64 } %291, 1
  %294 = icmp sge i64 %292, %293
  %295 = select i1 %294, i64 0, i64 %292
  %296 = add i64 %254, 1
  %297 = select i1 %294, i64 %296, i64 %254
  %298 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %299 = load i64, ptr %4, align 8
  %300 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %301 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %298, 0
  %302 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %298, 1, 1, 0
  %303 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %298, 1, 1, 1
  %304 = mul i64 %297, %303
  %305 = add i64 %304, %295
  %306 = getelementptr inbounds bfloat, ptr %301, i64 %305
  %307 = load bfloat, ptr %306, align 2, !invariant.load !1
  %308 = call i64 @llvm.smax.i64(i64 %299, i64 1)
  br label %309

309:                                              ; preds = %315, %282
  %310 = phi i64 [ 1, %282 ], [ %318, %315 ]
  %311 = phi bfloat [ %307, %282 ], [ %324, %315 ]
  %312 = icmp slt i64 %310, %308
  br i1 %312, label %313, label %314

313:                                              ; preds = %309
  br label %315

314:                                              ; preds = %309
  br label %325

315:                                              ; preds = %313
  %316 = icmp eq i64 %310, %308
  %317 = add i64 %310, 1
  %318 = select i1 %316, i64 %310, i64 %317
  %319 = mul i64 %310, %302
  %320 = add i64 %319, %304
  %321 = add i64 %320, %295
  %322 = getelementptr inbounds bfloat, ptr %301, i64 %321
  %323 = load bfloat, ptr %322, align 2, !invariant.load !1
  %324 = fadd contract bfloat %311, %323
  br label %309

325:                                              ; preds = %314
  %326 = phi bfloat [ %311, %314 ]
  %327 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %300, 0
  %328 = trunc i64 %297 to i32
  %329 = mul i32 %328, 512
  %330 = trunc i64 %295 to i32
  %331 = add i32 %329, %330
  %332 = sext i32 %331 to i64
  %333 = getelementptr inbounds bfloat, ptr %327, i64 %332
  store bfloat %326, ptr %333, align 2
  %334 = load { i64, i64 }, ptr %6, align 8
  %335 = add i64 %295, 1
  %336 = extractvalue { i64, i64 } %334, 1
  %337 = icmp sge i64 %335, %336
  %338 = select i1 %337, i64 0, i64 %335
  %339 = add i64 %297, 1
  %340 = select i1 %337, i64 %339, i64 %297
  %341 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %342 = load i64, ptr %4, align 8
  %343 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %344 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %341, 0
  %345 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %341, 1, 1, 0
  %346 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %341, 1, 1, 1
  %347 = mul i64 %340, %346
  %348 = add i64 %347, %338
  %349 = getelementptr inbounds bfloat, ptr %344, i64 %348
  %350 = load bfloat, ptr %349, align 2, !invariant.load !1
  %351 = call i64 @llvm.smax.i64(i64 %342, i64 1)
  br label %352

352:                                              ; preds = %358, %325
  %353 = phi i64 [ 1, %325 ], [ %361, %358 ]
  %354 = phi bfloat [ %350, %325 ], [ %367, %358 ]
  %355 = icmp slt i64 %353, %351
  br i1 %355, label %356, label %357

356:                                              ; preds = %352
  br label %358

357:                                              ; preds = %352
  br label %368

358:                                              ; preds = %356
  %359 = icmp eq i64 %353, %351
  %360 = add i64 %353, 1
  %361 = select i1 %359, i64 %353, i64 %360
  %362 = mul i64 %353, %345
  %363 = add i64 %362, %347
  %364 = add i64 %363, %338
  %365 = getelementptr inbounds bfloat, ptr %344, i64 %364
  %366 = load bfloat, ptr %365, align 2, !invariant.load !1
  %367 = fadd contract bfloat %354, %366
  br label %352

368:                                              ; preds = %357
  %369 = phi bfloat [ %354, %357 ]
  %370 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %343, 0
  %371 = trunc i64 %340 to i32
  %372 = mul i32 %371, 512
  %373 = trunc i64 %338 to i32
  %374 = add i32 %372, %373
  %375 = sext i32 %374 to i64
  %376 = getelementptr inbounds bfloat, ptr %370, i64 %375
  store bfloat %369, ptr %376, align 2
  %377 = load { i64, i64 }, ptr %6, align 8
  %378 = add i64 %338, 1
  %379 = extractvalue { i64, i64 } %377, 1
  %380 = icmp sge i64 %378, %379
  %381 = select i1 %380, i64 0, i64 %378
  %382 = add i64 %340, 1
  %383 = select i1 %380, i64 %382, i64 %340
  %384 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %385 = load i64, ptr %4, align 8
  %386 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %387 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %384, 0
  %388 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %384, 1, 1, 0
  %389 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %384, 1, 1, 1
  %390 = mul i64 %383, %389
  %391 = add i64 %390, %381
  %392 = getelementptr inbounds bfloat, ptr %387, i64 %391
  %393 = load bfloat, ptr %392, align 2, !invariant.load !1
  %394 = call i64 @llvm.smax.i64(i64 %385, i64 1)
  br label %395

395:                                              ; preds = %401, %368
  %396 = phi i64 [ 1, %368 ], [ %404, %401 ]
  %397 = phi bfloat [ %393, %368 ], [ %410, %401 ]
  %398 = icmp slt i64 %396, %394
  br i1 %398, label %399, label %400

399:                                              ; preds = %395
  br label %401

400:                                              ; preds = %395
  br label %411

401:                                              ; preds = %399
  %402 = icmp eq i64 %396, %394
  %403 = add i64 %396, 1
  %404 = select i1 %402, i64 %396, i64 %403
  %405 = mul i64 %396, %388
  %406 = add i64 %405, %390
  %407 = add i64 %406, %381
  %408 = getelementptr inbounds bfloat, ptr %387, i64 %407
  %409 = load bfloat, ptr %408, align 2, !invariant.load !1
  %410 = fadd contract bfloat %397, %409
  br label %395

411:                                              ; preds = %400
  %412 = phi bfloat [ %397, %400 ]
  %413 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %386, 0
  %414 = trunc i64 %383 to i32
  %415 = mul i32 %414, 512
  %416 = trunc i64 %381 to i32
  %417 = add i32 %415, %416
  %418 = sext i32 %417 to i64
  %419 = getelementptr inbounds bfloat, ptr %413, i64 %418
  store bfloat %412, ptr %419, align 2
  br label %452

420:                                              ; preds = %63
  %421 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %422 = load i64, ptr %4, align 8
  %423 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %424 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %421, 0
  %425 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %421, 1, 1, 0
  %426 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %421, 1, 1, 1
  %427 = mul i64 %80, %426
  %428 = add i64 %427, %77
  %429 = getelementptr inbounds bfloat, ptr %424, i64 %428
  %430 = load <8 x bfloat>, ptr %429, align 16, !invariant.load !1
  %431 = call i64 @llvm.smax.i64(i64 %422, i64 1)
  br label %432

432:                                              ; preds = %438, %420
  %433 = phi i64 [ 1, %420 ], [ %441, %438 ]
  %434 = phi <8 x bfloat> [ %430, %420 ], [ %447, %438 ]
  %435 = icmp slt i64 %433, %431
  br i1 %435, label %436, label %437

436:                                              ; preds = %432
  br label %438

437:                                              ; preds = %432
  br label %448

438:                                              ; preds = %436
  %439 = icmp eq i64 %433, %431
  %440 = add i64 %433, 1
  %441 = select i1 %439, i64 %433, i64 %440
  %442 = mul i64 %433, %425
  %443 = add i64 %442, %427
  %444 = add i64 %443, %77
  %445 = getelementptr inbounds bfloat, ptr %424, i64 %444
  %446 = load <8 x bfloat>, ptr %445, align 16, !invariant.load !1
  %447 = fadd contract <8 x bfloat> %434, %446
  br label %432

448:                                              ; preds = %437
  %449 = phi <8 x bfloat> [ %434, %437 ]
  %450 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %423, 0
  %451 = getelementptr inbounds bfloat, ptr %450, i64 %84
  store <8 x bfloat> %449, ptr %451, align 16
  br label %452

452:                                              ; preds = %448, %411
  br label %454

453:                                              ; preds = %60
  br label %454

454:                                              ; preds = %453, %452
  %455 = add i64 %53, %17
  %456 = mul i64 %455, 8
  %457 = trunc i64 %456 to i32
  %458 = load i64, ptr %20, align 8
  %459 = icmp slt i64 %455, %458
  br i1 %459, label %460, label %850

460:                                              ; preds = %454
  %461 = load { i64, i64 }, ptr %6, align 8
  %462 = extractvalue { i64, i64 } %461, 1
  %463 = trunc i64 %462 to i32
  %464 = icmp eq i32 %463, 0
  %465 = select i1 %464, i32 1, i32 %463
  %466 = icmp eq i32 %465, 0
  %467 = select i1 %466, i32 1, i32 %465
  %468 = udiv i32 %457, %467
  %469 = select i1 %466, i32 0, i32 %468
  %470 = urem i32 %457, %467
  %471 = select i1 %466, i32 0, i32 %470
  %472 = select i1 %464, i32 0, i32 %469
  %473 = select i1 %464, i32 0, i32 %471
  %474 = zext i32 %473 to i64
  %475 = trunc i64 %474 to i32
  %476 = add i64 %474, 1
  %477 = zext i32 %472 to i64
  %478 = trunc i64 %477 to i32
  %479 = mul i32 %478, 512
  %480 = add i32 %479, %475
  %481 = sext i32 %480 to i64
  %482 = add i64 %477, 1
  %483 = add i64 %474, 8
  %484 = load i64, ptr %8, align 8
  %485 = icmp sgt i64 %483, %484
  br i1 %485, label %486, label %817

486:                                              ; preds = %460
  %487 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %488 = load i64, ptr %4, align 8
  %489 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %490 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %487, 0
  %491 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %487, 1, 1, 0
  %492 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %487, 1, 1, 1
  %493 = mul i64 %477, %492
  %494 = add i64 %493, %474
  %495 = getelementptr inbounds bfloat, ptr %490, i64 %494
  %496 = load bfloat, ptr %495, align 2, !invariant.load !1
  %497 = call i64 @llvm.smax.i64(i64 %488, i64 1)
  br label %498

498:                                              ; preds = %504, %486
  %499 = phi i64 [ 1, %486 ], [ %507, %504 ]
  %500 = phi bfloat [ %496, %486 ], [ %513, %504 ]
  %501 = icmp slt i64 %499, %497
  br i1 %501, label %502, label %503

502:                                              ; preds = %498
  br label %504

503:                                              ; preds = %498
  br label %514

504:                                              ; preds = %502
  %505 = icmp eq i64 %499, %497
  %506 = add i64 %499, 1
  %507 = select i1 %505, i64 %499, i64 %506
  %508 = mul i64 %499, %491
  %509 = add i64 %508, %493
  %510 = add i64 %509, %474
  %511 = getelementptr inbounds bfloat, ptr %490, i64 %510
  %512 = load bfloat, ptr %511, align 2, !invariant.load !1
  %513 = fadd contract bfloat %500, %512
  br label %498

514:                                              ; preds = %503
  %515 = phi bfloat [ %500, %503 ]
  %516 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %489, 0
  %517 = getelementptr inbounds bfloat, ptr %516, i64 %481
  store bfloat %515, ptr %517, align 2
  %518 = load { i64, i64 }, ptr %6, align 8
  %519 = extractvalue { i64, i64 } %518, 1
  %520 = icmp sge i64 %476, %519
  %521 = select i1 %520, i64 0, i64 %476
  %522 = select i1 %520, i64 %482, i64 %477
  %523 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %524 = load i64, ptr %4, align 8
  %525 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %526 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %523, 0
  %527 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %523, 1, 1, 0
  %528 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %523, 1, 1, 1
  %529 = mul i64 %522, %528
  %530 = add i64 %529, %521
  %531 = getelementptr inbounds bfloat, ptr %526, i64 %530
  %532 = load bfloat, ptr %531, align 2, !invariant.load !1
  %533 = call i64 @llvm.smax.i64(i64 %524, i64 1)
  br label %534

534:                                              ; preds = %540, %514
  %535 = phi i64 [ 1, %514 ], [ %543, %540 ]
  %536 = phi bfloat [ %532, %514 ], [ %549, %540 ]
  %537 = icmp slt i64 %535, %533
  br i1 %537, label %538, label %539

538:                                              ; preds = %534
  br label %540

539:                                              ; preds = %534
  br label %550

540:                                              ; preds = %538
  %541 = icmp eq i64 %535, %533
  %542 = add i64 %535, 1
  %543 = select i1 %541, i64 %535, i64 %542
  %544 = mul i64 %535, %527
  %545 = add i64 %544, %529
  %546 = add i64 %545, %521
  %547 = getelementptr inbounds bfloat, ptr %526, i64 %546
  %548 = load bfloat, ptr %547, align 2, !invariant.load !1
  %549 = fadd contract bfloat %536, %548
  br label %534

550:                                              ; preds = %539
  %551 = phi bfloat [ %536, %539 ]
  %552 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %525, 0
  %553 = trunc i64 %522 to i32
  %554 = mul i32 %553, 512
  %555 = trunc i64 %521 to i32
  %556 = add i32 %554, %555
  %557 = sext i32 %556 to i64
  %558 = getelementptr inbounds bfloat, ptr %552, i64 %557
  store bfloat %551, ptr %558, align 2
  %559 = load { i64, i64 }, ptr %6, align 8
  %560 = add i64 %521, 1
  %561 = extractvalue { i64, i64 } %559, 1
  %562 = icmp sge i64 %560, %561
  %563 = select i1 %562, i64 0, i64 %560
  %564 = add i64 %522, 1
  %565 = select i1 %562, i64 %564, i64 %522
  %566 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %567 = load i64, ptr %4, align 8
  %568 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %569 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %566, 0
  %570 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %566, 1, 1, 0
  %571 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %566, 1, 1, 1
  %572 = mul i64 %565, %571
  %573 = add i64 %572, %563
  %574 = getelementptr inbounds bfloat, ptr %569, i64 %573
  %575 = load bfloat, ptr %574, align 2, !invariant.load !1
  %576 = call i64 @llvm.smax.i64(i64 %567, i64 1)
  br label %577

577:                                              ; preds = %583, %550
  %578 = phi i64 [ 1, %550 ], [ %586, %583 ]
  %579 = phi bfloat [ %575, %550 ], [ %592, %583 ]
  %580 = icmp slt i64 %578, %576
  br i1 %580, label %581, label %582

581:                                              ; preds = %577
  br label %583

582:                                              ; preds = %577
  br label %593

583:                                              ; preds = %581
  %584 = icmp eq i64 %578, %576
  %585 = add i64 %578, 1
  %586 = select i1 %584, i64 %578, i64 %585
  %587 = mul i64 %578, %570
  %588 = add i64 %587, %572
  %589 = add i64 %588, %563
  %590 = getelementptr inbounds bfloat, ptr %569, i64 %589
  %591 = load bfloat, ptr %590, align 2, !invariant.load !1
  %592 = fadd contract bfloat %579, %591
  br label %577

593:                                              ; preds = %582
  %594 = phi bfloat [ %579, %582 ]
  %595 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %568, 0
  %596 = trunc i64 %565 to i32
  %597 = mul i32 %596, 512
  %598 = trunc i64 %563 to i32
  %599 = add i32 %597, %598
  %600 = sext i32 %599 to i64
  %601 = getelementptr inbounds bfloat, ptr %595, i64 %600
  store bfloat %594, ptr %601, align 2
  %602 = load { i64, i64 }, ptr %6, align 8
  %603 = add i64 %563, 1
  %604 = extractvalue { i64, i64 } %602, 1
  %605 = icmp sge i64 %603, %604
  %606 = select i1 %605, i64 0, i64 %603
  %607 = add i64 %565, 1
  %608 = select i1 %605, i64 %607, i64 %565
  %609 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %610 = load i64, ptr %4, align 8
  %611 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %612 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %609, 0
  %613 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %609, 1, 1, 0
  %614 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %609, 1, 1, 1
  %615 = mul i64 %608, %614
  %616 = add i64 %615, %606
  %617 = getelementptr inbounds bfloat, ptr %612, i64 %616
  %618 = load bfloat, ptr %617, align 2, !invariant.load !1
  %619 = call i64 @llvm.smax.i64(i64 %610, i64 1)
  br label %620

620:                                              ; preds = %626, %593
  %621 = phi i64 [ 1, %593 ], [ %629, %626 ]
  %622 = phi bfloat [ %618, %593 ], [ %635, %626 ]
  %623 = icmp slt i64 %621, %619
  br i1 %623, label %624, label %625

624:                                              ; preds = %620
  br label %626

625:                                              ; preds = %620
  br label %636

626:                                              ; preds = %624
  %627 = icmp eq i64 %621, %619
  %628 = add i64 %621, 1
  %629 = select i1 %627, i64 %621, i64 %628
  %630 = mul i64 %621, %613
  %631 = add i64 %630, %615
  %632 = add i64 %631, %606
  %633 = getelementptr inbounds bfloat, ptr %612, i64 %632
  %634 = load bfloat, ptr %633, align 2, !invariant.load !1
  %635 = fadd contract bfloat %622, %634
  br label %620

636:                                              ; preds = %625
  %637 = phi bfloat [ %622, %625 ]
  %638 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %611, 0
  %639 = trunc i64 %608 to i32
  %640 = mul i32 %639, 512
  %641 = trunc i64 %606 to i32
  %642 = add i32 %640, %641
  %643 = sext i32 %642 to i64
  %644 = getelementptr inbounds bfloat, ptr %638, i64 %643
  store bfloat %637, ptr %644, align 2
  %645 = load { i64, i64 }, ptr %6, align 8
  %646 = add i64 %606, 1
  %647 = extractvalue { i64, i64 } %645, 1
  %648 = icmp sge i64 %646, %647
  %649 = select i1 %648, i64 0, i64 %646
  %650 = add i64 %608, 1
  %651 = select i1 %648, i64 %650, i64 %608
  %652 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %653 = load i64, ptr %4, align 8
  %654 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %655 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %652, 0
  %656 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %652, 1, 1, 0
  %657 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %652, 1, 1, 1
  %658 = mul i64 %651, %657
  %659 = add i64 %658, %649
  %660 = getelementptr inbounds bfloat, ptr %655, i64 %659
  %661 = load bfloat, ptr %660, align 2, !invariant.load !1
  %662 = call i64 @llvm.smax.i64(i64 %653, i64 1)
  br label %663

663:                                              ; preds = %669, %636
  %664 = phi i64 [ 1, %636 ], [ %672, %669 ]
  %665 = phi bfloat [ %661, %636 ], [ %678, %669 ]
  %666 = icmp slt i64 %664, %662
  br i1 %666, label %667, label %668

667:                                              ; preds = %663
  br label %669

668:                                              ; preds = %663
  br label %679

669:                                              ; preds = %667
  %670 = icmp eq i64 %664, %662
  %671 = add i64 %664, 1
  %672 = select i1 %670, i64 %664, i64 %671
  %673 = mul i64 %664, %656
  %674 = add i64 %673, %658
  %675 = add i64 %674, %649
  %676 = getelementptr inbounds bfloat, ptr %655, i64 %675
  %677 = load bfloat, ptr %676, align 2, !invariant.load !1
  %678 = fadd contract bfloat %665, %677
  br label %663

679:                                              ; preds = %668
  %680 = phi bfloat [ %665, %668 ]
  %681 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %654, 0
  %682 = trunc i64 %651 to i32
  %683 = mul i32 %682, 512
  %684 = trunc i64 %649 to i32
  %685 = add i32 %683, %684
  %686 = sext i32 %685 to i64
  %687 = getelementptr inbounds bfloat, ptr %681, i64 %686
  store bfloat %680, ptr %687, align 2
  %688 = load { i64, i64 }, ptr %6, align 8
  %689 = add i64 %649, 1
  %690 = extractvalue { i64, i64 } %688, 1
  %691 = icmp sge i64 %689, %690
  %692 = select i1 %691, i64 0, i64 %689
  %693 = add i64 %651, 1
  %694 = select i1 %691, i64 %693, i64 %651
  %695 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %696 = load i64, ptr %4, align 8
  %697 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %698 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %695, 0
  %699 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %695, 1, 1, 0
  %700 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %695, 1, 1, 1
  %701 = mul i64 %694, %700
  %702 = add i64 %701, %692
  %703 = getelementptr inbounds bfloat, ptr %698, i64 %702
  %704 = load bfloat, ptr %703, align 2, !invariant.load !1
  %705 = call i64 @llvm.smax.i64(i64 %696, i64 1)
  br label %706

706:                                              ; preds = %712, %679
  %707 = phi i64 [ 1, %679 ], [ %715, %712 ]
  %708 = phi bfloat [ %704, %679 ], [ %721, %712 ]
  %709 = icmp slt i64 %707, %705
  br i1 %709, label %710, label %711

710:                                              ; preds = %706
  br label %712

711:                                              ; preds = %706
  br label %722

712:                                              ; preds = %710
  %713 = icmp eq i64 %707, %705
  %714 = add i64 %707, 1
  %715 = select i1 %713, i64 %707, i64 %714
  %716 = mul i64 %707, %699
  %717 = add i64 %716, %701
  %718 = add i64 %717, %692
  %719 = getelementptr inbounds bfloat, ptr %698, i64 %718
  %720 = load bfloat, ptr %719, align 2, !invariant.load !1
  %721 = fadd contract bfloat %708, %720
  br label %706

722:                                              ; preds = %711
  %723 = phi bfloat [ %708, %711 ]
  %724 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %697, 0
  %725 = trunc i64 %694 to i32
  %726 = mul i32 %725, 512
  %727 = trunc i64 %692 to i32
  %728 = add i32 %726, %727
  %729 = sext i32 %728 to i64
  %730 = getelementptr inbounds bfloat, ptr %724, i64 %729
  store bfloat %723, ptr %730, align 2
  %731 = load { i64, i64 }, ptr %6, align 8
  %732 = add i64 %692, 1
  %733 = extractvalue { i64, i64 } %731, 1
  %734 = icmp sge i64 %732, %733
  %735 = select i1 %734, i64 0, i64 %732
  %736 = add i64 %694, 1
  %737 = select i1 %734, i64 %736, i64 %694
  %738 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %739 = load i64, ptr %4, align 8
  %740 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %741 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %738, 0
  %742 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %738, 1, 1, 0
  %743 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %738, 1, 1, 1
  %744 = mul i64 %737, %743
  %745 = add i64 %744, %735
  %746 = getelementptr inbounds bfloat, ptr %741, i64 %745
  %747 = load bfloat, ptr %746, align 2, !invariant.load !1
  %748 = call i64 @llvm.smax.i64(i64 %739, i64 1)
  br label %749

749:                                              ; preds = %755, %722
  %750 = phi i64 [ 1, %722 ], [ %758, %755 ]
  %751 = phi bfloat [ %747, %722 ], [ %764, %755 ]
  %752 = icmp slt i64 %750, %748
  br i1 %752, label %753, label %754

753:                                              ; preds = %749
  br label %755

754:                                              ; preds = %749
  br label %765

755:                                              ; preds = %753
  %756 = icmp eq i64 %750, %748
  %757 = add i64 %750, 1
  %758 = select i1 %756, i64 %750, i64 %757
  %759 = mul i64 %750, %742
  %760 = add i64 %759, %744
  %761 = add i64 %760, %735
  %762 = getelementptr inbounds bfloat, ptr %741, i64 %761
  %763 = load bfloat, ptr %762, align 2, !invariant.load !1
  %764 = fadd contract bfloat %751, %763
  br label %749

765:                                              ; preds = %754
  %766 = phi bfloat [ %751, %754 ]
  %767 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %740, 0
  %768 = trunc i64 %737 to i32
  %769 = mul i32 %768, 512
  %770 = trunc i64 %735 to i32
  %771 = add i32 %769, %770
  %772 = sext i32 %771 to i64
  %773 = getelementptr inbounds bfloat, ptr %767, i64 %772
  store bfloat %766, ptr %773, align 2
  %774 = load { i64, i64 }, ptr %6, align 8
  %775 = add i64 %735, 1
  %776 = extractvalue { i64, i64 } %774, 1
  %777 = icmp sge i64 %775, %776
  %778 = select i1 %777, i64 0, i64 %775
  %779 = add i64 %737, 1
  %780 = select i1 %777, i64 %779, i64 %737
  %781 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %782 = load i64, ptr %4, align 8
  %783 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %784 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %781, 0
  %785 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %781, 1, 1, 0
  %786 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %781, 1, 1, 1
  %787 = mul i64 %780, %786
  %788 = add i64 %787, %778
  %789 = getelementptr inbounds bfloat, ptr %784, i64 %788
  %790 = load bfloat, ptr %789, align 2, !invariant.load !1
  %791 = call i64 @llvm.smax.i64(i64 %782, i64 1)
  br label %792

792:                                              ; preds = %798, %765
  %793 = phi i64 [ 1, %765 ], [ %801, %798 ]
  %794 = phi bfloat [ %790, %765 ], [ %807, %798 ]
  %795 = icmp slt i64 %793, %791
  br i1 %795, label %796, label %797

796:                                              ; preds = %792
  br label %798

797:                                              ; preds = %792
  br label %808

798:                                              ; preds = %796
  %799 = icmp eq i64 %793, %791
  %800 = add i64 %793, 1
  %801 = select i1 %799, i64 %793, i64 %800
  %802 = mul i64 %793, %785
  %803 = add i64 %802, %787
  %804 = add i64 %803, %778
  %805 = getelementptr inbounds bfloat, ptr %784, i64 %804
  %806 = load bfloat, ptr %805, align 2, !invariant.load !1
  %807 = fadd contract bfloat %794, %806
  br label %792

808:                                              ; preds = %797
  %809 = phi bfloat [ %794, %797 ]
  %810 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %783, 0
  %811 = trunc i64 %780 to i32
  %812 = mul i32 %811, 512
  %813 = trunc i64 %778 to i32
  %814 = add i32 %812, %813
  %815 = sext i32 %814 to i64
  %816 = getelementptr inbounds bfloat, ptr %810, i64 %815
  store bfloat %809, ptr %816, align 2
  br label %849

817:                                              ; preds = %460
  %818 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %819 = load i64, ptr %4, align 8
  %820 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %821 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %818, 0
  %822 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %818, 1, 1, 0
  %823 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %818, 1, 1, 1
  %824 = mul i64 %477, %823
  %825 = add i64 %824, %474
  %826 = getelementptr inbounds bfloat, ptr %821, i64 %825
  %827 = load <8 x bfloat>, ptr %826, align 16, !invariant.load !1
  %828 = call i64 @llvm.smax.i64(i64 %819, i64 1)
  br label %829

829:                                              ; preds = %835, %817
  %830 = phi i64 [ 1, %817 ], [ %838, %835 ]
  %831 = phi <8 x bfloat> [ %827, %817 ], [ %844, %835 ]
  %832 = icmp slt i64 %830, %828
  br i1 %832, label %833, label %834

833:                                              ; preds = %829
  br label %835

834:                                              ; preds = %829
  br label %845

835:                                              ; preds = %833
  %836 = icmp eq i64 %830, %828
  %837 = add i64 %830, 1
  %838 = select i1 %836, i64 %830, i64 %837
  %839 = mul i64 %830, %822
  %840 = add i64 %839, %824
  %841 = add i64 %840, %474
  %842 = getelementptr inbounds bfloat, ptr %821, i64 %841
  %843 = load <8 x bfloat>, ptr %842, align 16, !invariant.load !1
  %844 = fadd contract <8 x bfloat> %831, %843
  br label %829

845:                                              ; preds = %834
  %846 = phi <8 x bfloat> [ %831, %834 ]
  %847 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %820, 0
  %848 = getelementptr inbounds bfloat, ptr %847, i64 %481
  store <8 x bfloat> %846, ptr %848, align 16
  br label %849

849:                                              ; preds = %845, %808
  br label %851

850:                                              ; preds = %454
  br label %851

851:                                              ; preds = %850, %849
  %852 = add i64 %53, %19
  %853 = mul i64 %852, 8
  %854 = trunc i64 %853 to i32
  %855 = load i64, ptr %20, align 8
  %856 = icmp slt i64 %852, %855
  br i1 %856, label %857, label %1247

857:                                              ; preds = %851
  %858 = load { i64, i64 }, ptr %6, align 8
  %859 = extractvalue { i64, i64 } %858, 1
  %860 = trunc i64 %859 to i32
  %861 = icmp eq i32 %860, 0
  %862 = select i1 %861, i32 1, i32 %860
  %863 = icmp eq i32 %862, 0
  %864 = select i1 %863, i32 1, i32 %862
  %865 = udiv i32 %854, %864
  %866 = select i1 %863, i32 0, i32 %865
  %867 = urem i32 %854, %864
  %868 = select i1 %863, i32 0, i32 %867
  %869 = select i1 %861, i32 0, i32 %866
  %870 = select i1 %861, i32 0, i32 %868
  %871 = zext i32 %870 to i64
  %872 = trunc i64 %871 to i32
  %873 = add i64 %871, 1
  %874 = zext i32 %869 to i64
  %875 = trunc i64 %874 to i32
  %876 = mul i32 %875, 512
  %877 = add i32 %876, %872
  %878 = sext i32 %877 to i64
  %879 = add i64 %874, 1
  %880 = add i64 %871, 8
  %881 = load i64, ptr %8, align 8
  %882 = icmp sgt i64 %880, %881
  br i1 %882, label %883, label %1214

883:                                              ; preds = %857
  %884 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %885 = load i64, ptr %4, align 8
  %886 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %887 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %884, 0
  %888 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %884, 1, 1, 0
  %889 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %884, 1, 1, 1
  %890 = mul i64 %874, %889
  %891 = add i64 %890, %871
  %892 = getelementptr inbounds bfloat, ptr %887, i64 %891
  %893 = load bfloat, ptr %892, align 2, !invariant.load !1
  %894 = call i64 @llvm.smax.i64(i64 %885, i64 1)
  br label %895

895:                                              ; preds = %901, %883
  %896 = phi i64 [ 1, %883 ], [ %904, %901 ]
  %897 = phi bfloat [ %893, %883 ], [ %910, %901 ]
  %898 = icmp slt i64 %896, %894
  br i1 %898, label %899, label %900

899:                                              ; preds = %895
  br label %901

900:                                              ; preds = %895
  br label %911

901:                                              ; preds = %899
  %902 = icmp eq i64 %896, %894
  %903 = add i64 %896, 1
  %904 = select i1 %902, i64 %896, i64 %903
  %905 = mul i64 %896, %888
  %906 = add i64 %905, %890
  %907 = add i64 %906, %871
  %908 = getelementptr inbounds bfloat, ptr %887, i64 %907
  %909 = load bfloat, ptr %908, align 2, !invariant.load !1
  %910 = fadd contract bfloat %897, %909
  br label %895

911:                                              ; preds = %900
  %912 = phi bfloat [ %897, %900 ]
  %913 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %886, 0
  %914 = getelementptr inbounds bfloat, ptr %913, i64 %878
  store bfloat %912, ptr %914, align 2
  %915 = load { i64, i64 }, ptr %6, align 8
  %916 = extractvalue { i64, i64 } %915, 1
  %917 = icmp sge i64 %873, %916
  %918 = select i1 %917, i64 0, i64 %873
  %919 = select i1 %917, i64 %879, i64 %874
  %920 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %921 = load i64, ptr %4, align 8
  %922 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %923 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %920, 0
  %924 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %920, 1, 1, 0
  %925 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %920, 1, 1, 1
  %926 = mul i64 %919, %925
  %927 = add i64 %926, %918
  %928 = getelementptr inbounds bfloat, ptr %923, i64 %927
  %929 = load bfloat, ptr %928, align 2, !invariant.load !1
  %930 = call i64 @llvm.smax.i64(i64 %921, i64 1)
  br label %931

931:                                              ; preds = %937, %911
  %932 = phi i64 [ 1, %911 ], [ %940, %937 ]
  %933 = phi bfloat [ %929, %911 ], [ %946, %937 ]
  %934 = icmp slt i64 %932, %930
  br i1 %934, label %935, label %936

935:                                              ; preds = %931
  br label %937

936:                                              ; preds = %931
  br label %947

937:                                              ; preds = %935
  %938 = icmp eq i64 %932, %930
  %939 = add i64 %932, 1
  %940 = select i1 %938, i64 %932, i64 %939
  %941 = mul i64 %932, %924
  %942 = add i64 %941, %926
  %943 = add i64 %942, %918
  %944 = getelementptr inbounds bfloat, ptr %923, i64 %943
  %945 = load bfloat, ptr %944, align 2, !invariant.load !1
  %946 = fadd contract bfloat %933, %945
  br label %931

947:                                              ; preds = %936
  %948 = phi bfloat [ %933, %936 ]
  %949 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %922, 0
  %950 = trunc i64 %919 to i32
  %951 = mul i32 %950, 512
  %952 = trunc i64 %918 to i32
  %953 = add i32 %951, %952
  %954 = sext i32 %953 to i64
  %955 = getelementptr inbounds bfloat, ptr %949, i64 %954
  store bfloat %948, ptr %955, align 2
  %956 = load { i64, i64 }, ptr %6, align 8
  %957 = add i64 %918, 1
  %958 = extractvalue { i64, i64 } %956, 1
  %959 = icmp sge i64 %957, %958
  %960 = select i1 %959, i64 0, i64 %957
  %961 = add i64 %919, 1
  %962 = select i1 %959, i64 %961, i64 %919
  %963 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %964 = load i64, ptr %4, align 8
  %965 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %966 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %963, 0
  %967 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %963, 1, 1, 0
  %968 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %963, 1, 1, 1
  %969 = mul i64 %962, %968
  %970 = add i64 %969, %960
  %971 = getelementptr inbounds bfloat, ptr %966, i64 %970
  %972 = load bfloat, ptr %971, align 2, !invariant.load !1
  %973 = call i64 @llvm.smax.i64(i64 %964, i64 1)
  br label %974

974:                                              ; preds = %980, %947
  %975 = phi i64 [ 1, %947 ], [ %983, %980 ]
  %976 = phi bfloat [ %972, %947 ], [ %989, %980 ]
  %977 = icmp slt i64 %975, %973
  br i1 %977, label %978, label %979

978:                                              ; preds = %974
  br label %980

979:                                              ; preds = %974
  br label %990

980:                                              ; preds = %978
  %981 = icmp eq i64 %975, %973
  %982 = add i64 %975, 1
  %983 = select i1 %981, i64 %975, i64 %982
  %984 = mul i64 %975, %967
  %985 = add i64 %984, %969
  %986 = add i64 %985, %960
  %987 = getelementptr inbounds bfloat, ptr %966, i64 %986
  %988 = load bfloat, ptr %987, align 2, !invariant.load !1
  %989 = fadd contract bfloat %976, %988
  br label %974

990:                                              ; preds = %979
  %991 = phi bfloat [ %976, %979 ]
  %992 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %965, 0
  %993 = trunc i64 %962 to i32
  %994 = mul i32 %993, 512
  %995 = trunc i64 %960 to i32
  %996 = add i32 %994, %995
  %997 = sext i32 %996 to i64
  %998 = getelementptr inbounds bfloat, ptr %992, i64 %997
  store bfloat %991, ptr %998, align 2
  %999 = load { i64, i64 }, ptr %6, align 8
  %1000 = add i64 %960, 1
  %1001 = extractvalue { i64, i64 } %999, 1
  %1002 = icmp sge i64 %1000, %1001
  %1003 = select i1 %1002, i64 0, i64 %1000
  %1004 = add i64 %962, 1
  %1005 = select i1 %1002, i64 %1004, i64 %962
  %1006 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1007 = load i64, ptr %4, align 8
  %1008 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1009 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1006, 0
  %1010 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1006, 1, 1, 0
  %1011 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1006, 1, 1, 1
  %1012 = mul i64 %1005, %1011
  %1013 = add i64 %1012, %1003
  %1014 = getelementptr inbounds bfloat, ptr %1009, i64 %1013
  %1015 = load bfloat, ptr %1014, align 2, !invariant.load !1
  %1016 = call i64 @llvm.smax.i64(i64 %1007, i64 1)
  br label %1017

1017:                                             ; preds = %1023, %990
  %1018 = phi i64 [ 1, %990 ], [ %1026, %1023 ]
  %1019 = phi bfloat [ %1015, %990 ], [ %1032, %1023 ]
  %1020 = icmp slt i64 %1018, %1016
  br i1 %1020, label %1021, label %1022

1021:                                             ; preds = %1017
  br label %1023

1022:                                             ; preds = %1017
  br label %1033

1023:                                             ; preds = %1021
  %1024 = icmp eq i64 %1018, %1016
  %1025 = add i64 %1018, 1
  %1026 = select i1 %1024, i64 %1018, i64 %1025
  %1027 = mul i64 %1018, %1010
  %1028 = add i64 %1027, %1012
  %1029 = add i64 %1028, %1003
  %1030 = getelementptr inbounds bfloat, ptr %1009, i64 %1029
  %1031 = load bfloat, ptr %1030, align 2, !invariant.load !1
  %1032 = fadd contract bfloat %1019, %1031
  br label %1017

1033:                                             ; preds = %1022
  %1034 = phi bfloat [ %1019, %1022 ]
  %1035 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1008, 0
  %1036 = trunc i64 %1005 to i32
  %1037 = mul i32 %1036, 512
  %1038 = trunc i64 %1003 to i32
  %1039 = add i32 %1037, %1038
  %1040 = sext i32 %1039 to i64
  %1041 = getelementptr inbounds bfloat, ptr %1035, i64 %1040
  store bfloat %1034, ptr %1041, align 2
  %1042 = load { i64, i64 }, ptr %6, align 8
  %1043 = add i64 %1003, 1
  %1044 = extractvalue { i64, i64 } %1042, 1
  %1045 = icmp sge i64 %1043, %1044
  %1046 = select i1 %1045, i64 0, i64 %1043
  %1047 = add i64 %1005, 1
  %1048 = select i1 %1045, i64 %1047, i64 %1005
  %1049 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1050 = load i64, ptr %4, align 8
  %1051 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1052 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1049, 0
  %1053 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1049, 1, 1, 0
  %1054 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1049, 1, 1, 1
  %1055 = mul i64 %1048, %1054
  %1056 = add i64 %1055, %1046
  %1057 = getelementptr inbounds bfloat, ptr %1052, i64 %1056
  %1058 = load bfloat, ptr %1057, align 2, !invariant.load !1
  %1059 = call i64 @llvm.smax.i64(i64 %1050, i64 1)
  br label %1060

1060:                                             ; preds = %1066, %1033
  %1061 = phi i64 [ 1, %1033 ], [ %1069, %1066 ]
  %1062 = phi bfloat [ %1058, %1033 ], [ %1075, %1066 ]
  %1063 = icmp slt i64 %1061, %1059
  br i1 %1063, label %1064, label %1065

1064:                                             ; preds = %1060
  br label %1066

1065:                                             ; preds = %1060
  br label %1076

1066:                                             ; preds = %1064
  %1067 = icmp eq i64 %1061, %1059
  %1068 = add i64 %1061, 1
  %1069 = select i1 %1067, i64 %1061, i64 %1068
  %1070 = mul i64 %1061, %1053
  %1071 = add i64 %1070, %1055
  %1072 = add i64 %1071, %1046
  %1073 = getelementptr inbounds bfloat, ptr %1052, i64 %1072
  %1074 = load bfloat, ptr %1073, align 2, !invariant.load !1
  %1075 = fadd contract bfloat %1062, %1074
  br label %1060

1076:                                             ; preds = %1065
  %1077 = phi bfloat [ %1062, %1065 ]
  %1078 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1051, 0
  %1079 = trunc i64 %1048 to i32
  %1080 = mul i32 %1079, 512
  %1081 = trunc i64 %1046 to i32
  %1082 = add i32 %1080, %1081
  %1083 = sext i32 %1082 to i64
  %1084 = getelementptr inbounds bfloat, ptr %1078, i64 %1083
  store bfloat %1077, ptr %1084, align 2
  %1085 = load { i64, i64 }, ptr %6, align 8
  %1086 = add i64 %1046, 1
  %1087 = extractvalue { i64, i64 } %1085, 1
  %1088 = icmp sge i64 %1086, %1087
  %1089 = select i1 %1088, i64 0, i64 %1086
  %1090 = add i64 %1048, 1
  %1091 = select i1 %1088, i64 %1090, i64 %1048
  %1092 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1093 = load i64, ptr %4, align 8
  %1094 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1095 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1092, 0
  %1096 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1092, 1, 1, 0
  %1097 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1092, 1, 1, 1
  %1098 = mul i64 %1091, %1097
  %1099 = add i64 %1098, %1089
  %1100 = getelementptr inbounds bfloat, ptr %1095, i64 %1099
  %1101 = load bfloat, ptr %1100, align 2, !invariant.load !1
  %1102 = call i64 @llvm.smax.i64(i64 %1093, i64 1)
  br label %1103

1103:                                             ; preds = %1109, %1076
  %1104 = phi i64 [ 1, %1076 ], [ %1112, %1109 ]
  %1105 = phi bfloat [ %1101, %1076 ], [ %1118, %1109 ]
  %1106 = icmp slt i64 %1104, %1102
  br i1 %1106, label %1107, label %1108

1107:                                             ; preds = %1103
  br label %1109

1108:                                             ; preds = %1103
  br label %1119

1109:                                             ; preds = %1107
  %1110 = icmp eq i64 %1104, %1102
  %1111 = add i64 %1104, 1
  %1112 = select i1 %1110, i64 %1104, i64 %1111
  %1113 = mul i64 %1104, %1096
  %1114 = add i64 %1113, %1098
  %1115 = add i64 %1114, %1089
  %1116 = getelementptr inbounds bfloat, ptr %1095, i64 %1115
  %1117 = load bfloat, ptr %1116, align 2, !invariant.load !1
  %1118 = fadd contract bfloat %1105, %1117
  br label %1103

1119:                                             ; preds = %1108
  %1120 = phi bfloat [ %1105, %1108 ]
  %1121 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1094, 0
  %1122 = trunc i64 %1091 to i32
  %1123 = mul i32 %1122, 512
  %1124 = trunc i64 %1089 to i32
  %1125 = add i32 %1123, %1124
  %1126 = sext i32 %1125 to i64
  %1127 = getelementptr inbounds bfloat, ptr %1121, i64 %1126
  store bfloat %1120, ptr %1127, align 2
  %1128 = load { i64, i64 }, ptr %6, align 8
  %1129 = add i64 %1089, 1
  %1130 = extractvalue { i64, i64 } %1128, 1
  %1131 = icmp sge i64 %1129, %1130
  %1132 = select i1 %1131, i64 0, i64 %1129
  %1133 = add i64 %1091, 1
  %1134 = select i1 %1131, i64 %1133, i64 %1091
  %1135 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1136 = load i64, ptr %4, align 8
  %1137 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1138 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1135, 0
  %1139 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1135, 1, 1, 0
  %1140 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1135, 1, 1, 1
  %1141 = mul i64 %1134, %1140
  %1142 = add i64 %1141, %1132
  %1143 = getelementptr inbounds bfloat, ptr %1138, i64 %1142
  %1144 = load bfloat, ptr %1143, align 2, !invariant.load !1
  %1145 = call i64 @llvm.smax.i64(i64 %1136, i64 1)
  br label %1146

1146:                                             ; preds = %1152, %1119
  %1147 = phi i64 [ 1, %1119 ], [ %1155, %1152 ]
  %1148 = phi bfloat [ %1144, %1119 ], [ %1161, %1152 ]
  %1149 = icmp slt i64 %1147, %1145
  br i1 %1149, label %1150, label %1151

1150:                                             ; preds = %1146
  br label %1152

1151:                                             ; preds = %1146
  br label %1162

1152:                                             ; preds = %1150
  %1153 = icmp eq i64 %1147, %1145
  %1154 = add i64 %1147, 1
  %1155 = select i1 %1153, i64 %1147, i64 %1154
  %1156 = mul i64 %1147, %1139
  %1157 = add i64 %1156, %1141
  %1158 = add i64 %1157, %1132
  %1159 = getelementptr inbounds bfloat, ptr %1138, i64 %1158
  %1160 = load bfloat, ptr %1159, align 2, !invariant.load !1
  %1161 = fadd contract bfloat %1148, %1160
  br label %1146

1162:                                             ; preds = %1151
  %1163 = phi bfloat [ %1148, %1151 ]
  %1164 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1137, 0
  %1165 = trunc i64 %1134 to i32
  %1166 = mul i32 %1165, 512
  %1167 = trunc i64 %1132 to i32
  %1168 = add i32 %1166, %1167
  %1169 = sext i32 %1168 to i64
  %1170 = getelementptr inbounds bfloat, ptr %1164, i64 %1169
  store bfloat %1163, ptr %1170, align 2
  %1171 = load { i64, i64 }, ptr %6, align 8
  %1172 = add i64 %1132, 1
  %1173 = extractvalue { i64, i64 } %1171, 1
  %1174 = icmp sge i64 %1172, %1173
  %1175 = select i1 %1174, i64 0, i64 %1172
  %1176 = add i64 %1134, 1
  %1177 = select i1 %1174, i64 %1176, i64 %1134
  %1178 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1179 = load i64, ptr %4, align 8
  %1180 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1181 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1178, 0
  %1182 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1178, 1, 1, 0
  %1183 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1178, 1, 1, 1
  %1184 = mul i64 %1177, %1183
  %1185 = add i64 %1184, %1175
  %1186 = getelementptr inbounds bfloat, ptr %1181, i64 %1185
  %1187 = load bfloat, ptr %1186, align 2, !invariant.load !1
  %1188 = call i64 @llvm.smax.i64(i64 %1179, i64 1)
  br label %1189

1189:                                             ; preds = %1195, %1162
  %1190 = phi i64 [ 1, %1162 ], [ %1198, %1195 ]
  %1191 = phi bfloat [ %1187, %1162 ], [ %1204, %1195 ]
  %1192 = icmp slt i64 %1190, %1188
  br i1 %1192, label %1193, label %1194

1193:                                             ; preds = %1189
  br label %1195

1194:                                             ; preds = %1189
  br label %1205

1195:                                             ; preds = %1193
  %1196 = icmp eq i64 %1190, %1188
  %1197 = add i64 %1190, 1
  %1198 = select i1 %1196, i64 %1190, i64 %1197
  %1199 = mul i64 %1190, %1182
  %1200 = add i64 %1199, %1184
  %1201 = add i64 %1200, %1175
  %1202 = getelementptr inbounds bfloat, ptr %1181, i64 %1201
  %1203 = load bfloat, ptr %1202, align 2, !invariant.load !1
  %1204 = fadd contract bfloat %1191, %1203
  br label %1189

1205:                                             ; preds = %1194
  %1206 = phi bfloat [ %1191, %1194 ]
  %1207 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1180, 0
  %1208 = trunc i64 %1177 to i32
  %1209 = mul i32 %1208, 512
  %1210 = trunc i64 %1175 to i32
  %1211 = add i32 %1209, %1210
  %1212 = sext i32 %1211 to i64
  %1213 = getelementptr inbounds bfloat, ptr %1207, i64 %1212
  store bfloat %1206, ptr %1213, align 2
  br label %1246

1214:                                             ; preds = %857
  %1215 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1216 = load i64, ptr %4, align 8
  %1217 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1218 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1215, 0
  %1219 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1215, 1, 1, 0
  %1220 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1215, 1, 1, 1
  %1221 = mul i64 %874, %1220
  %1222 = add i64 %1221, %871
  %1223 = getelementptr inbounds bfloat, ptr %1218, i64 %1222
  %1224 = load <8 x bfloat>, ptr %1223, align 16, !invariant.load !1
  %1225 = call i64 @llvm.smax.i64(i64 %1216, i64 1)
  br label %1226

1226:                                             ; preds = %1232, %1214
  %1227 = phi i64 [ 1, %1214 ], [ %1235, %1232 ]
  %1228 = phi <8 x bfloat> [ %1224, %1214 ], [ %1241, %1232 ]
  %1229 = icmp slt i64 %1227, %1225
  br i1 %1229, label %1230, label %1231

1230:                                             ; preds = %1226
  br label %1232

1231:                                             ; preds = %1226
  br label %1242

1232:                                             ; preds = %1230
  %1233 = icmp eq i64 %1227, %1225
  %1234 = add i64 %1227, 1
  %1235 = select i1 %1233, i64 %1227, i64 %1234
  %1236 = mul i64 %1227, %1219
  %1237 = add i64 %1236, %1221
  %1238 = add i64 %1237, %871
  %1239 = getelementptr inbounds bfloat, ptr %1218, i64 %1238
  %1240 = load <8 x bfloat>, ptr %1239, align 16, !invariant.load !1
  %1241 = fadd contract <8 x bfloat> %1228, %1240
  br label %1226

1242:                                             ; preds = %1231
  %1243 = phi <8 x bfloat> [ %1228, %1231 ]
  %1244 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1217, 0
  %1245 = getelementptr inbounds bfloat, ptr %1244, i64 %878
  store <8 x bfloat> %1243, ptr %1245, align 16
  br label %1246

1246:                                             ; preds = %1242, %1205
  br label %1248

1247:                                             ; preds = %851
  br label %1248

1248:                                             ; preds = %1247, %1246
  %1249 = add i64 %53, %18
  %1250 = mul i64 %1249, 8
  %1251 = trunc i64 %1250 to i32
  %1252 = load i64, ptr %20, align 8
  %1253 = icmp slt i64 %1249, %1252
  br i1 %1253, label %1254, label %1644

1254:                                             ; preds = %1248
  %1255 = load { i64, i64 }, ptr %6, align 8
  %1256 = extractvalue { i64, i64 } %1255, 1
  %1257 = trunc i64 %1256 to i32
  %1258 = icmp eq i32 %1257, 0
  %1259 = select i1 %1258, i32 1, i32 %1257
  %1260 = icmp eq i32 %1259, 0
  %1261 = select i1 %1260, i32 1, i32 %1259
  %1262 = udiv i32 %1251, %1261
  %1263 = select i1 %1260, i32 0, i32 %1262
  %1264 = urem i32 %1251, %1261
  %1265 = select i1 %1260, i32 0, i32 %1264
  %1266 = select i1 %1258, i32 0, i32 %1263
  %1267 = select i1 %1258, i32 0, i32 %1265
  %1268 = zext i32 %1267 to i64
  %1269 = trunc i64 %1268 to i32
  %1270 = add i64 %1268, 1
  %1271 = zext i32 %1266 to i64
  %1272 = trunc i64 %1271 to i32
  %1273 = mul i32 %1272, 512
  %1274 = add i32 %1273, %1269
  %1275 = sext i32 %1274 to i64
  %1276 = add i64 %1271, 1
  %1277 = add i64 %1268, 8
  %1278 = load i64, ptr %8, align 8
  %1279 = icmp sgt i64 %1277, %1278
  br i1 %1279, label %1280, label %1611

1280:                                             ; preds = %1254
  %1281 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1282 = load i64, ptr %4, align 8
  %1283 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1284 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1281, 0
  %1285 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1281, 1, 1, 0
  %1286 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1281, 1, 1, 1
  %1287 = mul i64 %1271, %1286
  %1288 = add i64 %1287, %1268
  %1289 = getelementptr inbounds bfloat, ptr %1284, i64 %1288
  %1290 = load bfloat, ptr %1289, align 2, !invariant.load !1
  %1291 = call i64 @llvm.smax.i64(i64 %1282, i64 1)
  br label %1292

1292:                                             ; preds = %1298, %1280
  %1293 = phi i64 [ 1, %1280 ], [ %1301, %1298 ]
  %1294 = phi bfloat [ %1290, %1280 ], [ %1307, %1298 ]
  %1295 = icmp slt i64 %1293, %1291
  br i1 %1295, label %1296, label %1297

1296:                                             ; preds = %1292
  br label %1298

1297:                                             ; preds = %1292
  br label %1308

1298:                                             ; preds = %1296
  %1299 = icmp eq i64 %1293, %1291
  %1300 = add i64 %1293, 1
  %1301 = select i1 %1299, i64 %1293, i64 %1300
  %1302 = mul i64 %1293, %1285
  %1303 = add i64 %1302, %1287
  %1304 = add i64 %1303, %1268
  %1305 = getelementptr inbounds bfloat, ptr %1284, i64 %1304
  %1306 = load bfloat, ptr %1305, align 2, !invariant.load !1
  %1307 = fadd contract bfloat %1294, %1306
  br label %1292

1308:                                             ; preds = %1297
  %1309 = phi bfloat [ %1294, %1297 ]
  %1310 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1283, 0
  %1311 = getelementptr inbounds bfloat, ptr %1310, i64 %1275
  store bfloat %1309, ptr %1311, align 2
  %1312 = load { i64, i64 }, ptr %6, align 8
  %1313 = extractvalue { i64, i64 } %1312, 1
  %1314 = icmp sge i64 %1270, %1313
  %1315 = select i1 %1314, i64 0, i64 %1270
  %1316 = select i1 %1314, i64 %1276, i64 %1271
  %1317 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1318 = load i64, ptr %4, align 8
  %1319 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1320 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1317, 0
  %1321 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1317, 1, 1, 0
  %1322 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1317, 1, 1, 1
  %1323 = mul i64 %1316, %1322
  %1324 = add i64 %1323, %1315
  %1325 = getelementptr inbounds bfloat, ptr %1320, i64 %1324
  %1326 = load bfloat, ptr %1325, align 2, !invariant.load !1
  %1327 = call i64 @llvm.smax.i64(i64 %1318, i64 1)
  br label %1328

1328:                                             ; preds = %1334, %1308
  %1329 = phi i64 [ 1, %1308 ], [ %1337, %1334 ]
  %1330 = phi bfloat [ %1326, %1308 ], [ %1343, %1334 ]
  %1331 = icmp slt i64 %1329, %1327
  br i1 %1331, label %1332, label %1333

1332:                                             ; preds = %1328
  br label %1334

1333:                                             ; preds = %1328
  br label %1344

1334:                                             ; preds = %1332
  %1335 = icmp eq i64 %1329, %1327
  %1336 = add i64 %1329, 1
  %1337 = select i1 %1335, i64 %1329, i64 %1336
  %1338 = mul i64 %1329, %1321
  %1339 = add i64 %1338, %1323
  %1340 = add i64 %1339, %1315
  %1341 = getelementptr inbounds bfloat, ptr %1320, i64 %1340
  %1342 = load bfloat, ptr %1341, align 2, !invariant.load !1
  %1343 = fadd contract bfloat %1330, %1342
  br label %1328

1344:                                             ; preds = %1333
  %1345 = phi bfloat [ %1330, %1333 ]
  %1346 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1319, 0
  %1347 = trunc i64 %1316 to i32
  %1348 = mul i32 %1347, 512
  %1349 = trunc i64 %1315 to i32
  %1350 = add i32 %1348, %1349
  %1351 = sext i32 %1350 to i64
  %1352 = getelementptr inbounds bfloat, ptr %1346, i64 %1351
  store bfloat %1345, ptr %1352, align 2
  %1353 = load { i64, i64 }, ptr %6, align 8
  %1354 = add i64 %1315, 1
  %1355 = extractvalue { i64, i64 } %1353, 1
  %1356 = icmp sge i64 %1354, %1355
  %1357 = select i1 %1356, i64 0, i64 %1354
  %1358 = add i64 %1316, 1
  %1359 = select i1 %1356, i64 %1358, i64 %1316
  %1360 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1361 = load i64, ptr %4, align 8
  %1362 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1363 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1360, 0
  %1364 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1360, 1, 1, 0
  %1365 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1360, 1, 1, 1
  %1366 = mul i64 %1359, %1365
  %1367 = add i64 %1366, %1357
  %1368 = getelementptr inbounds bfloat, ptr %1363, i64 %1367
  %1369 = load bfloat, ptr %1368, align 2, !invariant.load !1
  %1370 = call i64 @llvm.smax.i64(i64 %1361, i64 1)
  br label %1371

1371:                                             ; preds = %1377, %1344
  %1372 = phi i64 [ 1, %1344 ], [ %1380, %1377 ]
  %1373 = phi bfloat [ %1369, %1344 ], [ %1386, %1377 ]
  %1374 = icmp slt i64 %1372, %1370
  br i1 %1374, label %1375, label %1376

1375:                                             ; preds = %1371
  br label %1377

1376:                                             ; preds = %1371
  br label %1387

1377:                                             ; preds = %1375
  %1378 = icmp eq i64 %1372, %1370
  %1379 = add i64 %1372, 1
  %1380 = select i1 %1378, i64 %1372, i64 %1379
  %1381 = mul i64 %1372, %1364
  %1382 = add i64 %1381, %1366
  %1383 = add i64 %1382, %1357
  %1384 = getelementptr inbounds bfloat, ptr %1363, i64 %1383
  %1385 = load bfloat, ptr %1384, align 2, !invariant.load !1
  %1386 = fadd contract bfloat %1373, %1385
  br label %1371

1387:                                             ; preds = %1376
  %1388 = phi bfloat [ %1373, %1376 ]
  %1389 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1362, 0
  %1390 = trunc i64 %1359 to i32
  %1391 = mul i32 %1390, 512
  %1392 = trunc i64 %1357 to i32
  %1393 = add i32 %1391, %1392
  %1394 = sext i32 %1393 to i64
  %1395 = getelementptr inbounds bfloat, ptr %1389, i64 %1394
  store bfloat %1388, ptr %1395, align 2
  %1396 = load { i64, i64 }, ptr %6, align 8
  %1397 = add i64 %1357, 1
  %1398 = extractvalue { i64, i64 } %1396, 1
  %1399 = icmp sge i64 %1397, %1398
  %1400 = select i1 %1399, i64 0, i64 %1397
  %1401 = add i64 %1359, 1
  %1402 = select i1 %1399, i64 %1401, i64 %1359
  %1403 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1404 = load i64, ptr %4, align 8
  %1405 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1406 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1403, 0
  %1407 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1403, 1, 1, 0
  %1408 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1403, 1, 1, 1
  %1409 = mul i64 %1402, %1408
  %1410 = add i64 %1409, %1400
  %1411 = getelementptr inbounds bfloat, ptr %1406, i64 %1410
  %1412 = load bfloat, ptr %1411, align 2, !invariant.load !1
  %1413 = call i64 @llvm.smax.i64(i64 %1404, i64 1)
  br label %1414

1414:                                             ; preds = %1420, %1387
  %1415 = phi i64 [ 1, %1387 ], [ %1423, %1420 ]
  %1416 = phi bfloat [ %1412, %1387 ], [ %1429, %1420 ]
  %1417 = icmp slt i64 %1415, %1413
  br i1 %1417, label %1418, label %1419

1418:                                             ; preds = %1414
  br label %1420

1419:                                             ; preds = %1414
  br label %1430

1420:                                             ; preds = %1418
  %1421 = icmp eq i64 %1415, %1413
  %1422 = add i64 %1415, 1
  %1423 = select i1 %1421, i64 %1415, i64 %1422
  %1424 = mul i64 %1415, %1407
  %1425 = add i64 %1424, %1409
  %1426 = add i64 %1425, %1400
  %1427 = getelementptr inbounds bfloat, ptr %1406, i64 %1426
  %1428 = load bfloat, ptr %1427, align 2, !invariant.load !1
  %1429 = fadd contract bfloat %1416, %1428
  br label %1414

1430:                                             ; preds = %1419
  %1431 = phi bfloat [ %1416, %1419 ]
  %1432 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1405, 0
  %1433 = trunc i64 %1402 to i32
  %1434 = mul i32 %1433, 512
  %1435 = trunc i64 %1400 to i32
  %1436 = add i32 %1434, %1435
  %1437 = sext i32 %1436 to i64
  %1438 = getelementptr inbounds bfloat, ptr %1432, i64 %1437
  store bfloat %1431, ptr %1438, align 2
  %1439 = load { i64, i64 }, ptr %6, align 8
  %1440 = add i64 %1400, 1
  %1441 = extractvalue { i64, i64 } %1439, 1
  %1442 = icmp sge i64 %1440, %1441
  %1443 = select i1 %1442, i64 0, i64 %1440
  %1444 = add i64 %1402, 1
  %1445 = select i1 %1442, i64 %1444, i64 %1402
  %1446 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1447 = load i64, ptr %4, align 8
  %1448 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1449 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1446, 0
  %1450 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1446, 1, 1, 0
  %1451 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1446, 1, 1, 1
  %1452 = mul i64 %1445, %1451
  %1453 = add i64 %1452, %1443
  %1454 = getelementptr inbounds bfloat, ptr %1449, i64 %1453
  %1455 = load bfloat, ptr %1454, align 2, !invariant.load !1
  %1456 = call i64 @llvm.smax.i64(i64 %1447, i64 1)
  br label %1457

1457:                                             ; preds = %1463, %1430
  %1458 = phi i64 [ 1, %1430 ], [ %1466, %1463 ]
  %1459 = phi bfloat [ %1455, %1430 ], [ %1472, %1463 ]
  %1460 = icmp slt i64 %1458, %1456
  br i1 %1460, label %1461, label %1462

1461:                                             ; preds = %1457
  br label %1463

1462:                                             ; preds = %1457
  br label %1473

1463:                                             ; preds = %1461
  %1464 = icmp eq i64 %1458, %1456
  %1465 = add i64 %1458, 1
  %1466 = select i1 %1464, i64 %1458, i64 %1465
  %1467 = mul i64 %1458, %1450
  %1468 = add i64 %1467, %1452
  %1469 = add i64 %1468, %1443
  %1470 = getelementptr inbounds bfloat, ptr %1449, i64 %1469
  %1471 = load bfloat, ptr %1470, align 2, !invariant.load !1
  %1472 = fadd contract bfloat %1459, %1471
  br label %1457

1473:                                             ; preds = %1462
  %1474 = phi bfloat [ %1459, %1462 ]
  %1475 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1448, 0
  %1476 = trunc i64 %1445 to i32
  %1477 = mul i32 %1476, 512
  %1478 = trunc i64 %1443 to i32
  %1479 = add i32 %1477, %1478
  %1480 = sext i32 %1479 to i64
  %1481 = getelementptr inbounds bfloat, ptr %1475, i64 %1480
  store bfloat %1474, ptr %1481, align 2
  %1482 = load { i64, i64 }, ptr %6, align 8
  %1483 = add i64 %1443, 1
  %1484 = extractvalue { i64, i64 } %1482, 1
  %1485 = icmp sge i64 %1483, %1484
  %1486 = select i1 %1485, i64 0, i64 %1483
  %1487 = add i64 %1445, 1
  %1488 = select i1 %1485, i64 %1487, i64 %1445
  %1489 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1490 = load i64, ptr %4, align 8
  %1491 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1492 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1489, 0
  %1493 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1489, 1, 1, 0
  %1494 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1489, 1, 1, 1
  %1495 = mul i64 %1488, %1494
  %1496 = add i64 %1495, %1486
  %1497 = getelementptr inbounds bfloat, ptr %1492, i64 %1496
  %1498 = load bfloat, ptr %1497, align 2, !invariant.load !1
  %1499 = call i64 @llvm.smax.i64(i64 %1490, i64 1)
  br label %1500

1500:                                             ; preds = %1506, %1473
  %1501 = phi i64 [ 1, %1473 ], [ %1509, %1506 ]
  %1502 = phi bfloat [ %1498, %1473 ], [ %1515, %1506 ]
  %1503 = icmp slt i64 %1501, %1499
  br i1 %1503, label %1504, label %1505

1504:                                             ; preds = %1500
  br label %1506

1505:                                             ; preds = %1500
  br label %1516

1506:                                             ; preds = %1504
  %1507 = icmp eq i64 %1501, %1499
  %1508 = add i64 %1501, 1
  %1509 = select i1 %1507, i64 %1501, i64 %1508
  %1510 = mul i64 %1501, %1493
  %1511 = add i64 %1510, %1495
  %1512 = add i64 %1511, %1486
  %1513 = getelementptr inbounds bfloat, ptr %1492, i64 %1512
  %1514 = load bfloat, ptr %1513, align 2, !invariant.load !1
  %1515 = fadd contract bfloat %1502, %1514
  br label %1500

1516:                                             ; preds = %1505
  %1517 = phi bfloat [ %1502, %1505 ]
  %1518 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1491, 0
  %1519 = trunc i64 %1488 to i32
  %1520 = mul i32 %1519, 512
  %1521 = trunc i64 %1486 to i32
  %1522 = add i32 %1520, %1521
  %1523 = sext i32 %1522 to i64
  %1524 = getelementptr inbounds bfloat, ptr %1518, i64 %1523
  store bfloat %1517, ptr %1524, align 2
  %1525 = load { i64, i64 }, ptr %6, align 8
  %1526 = add i64 %1486, 1
  %1527 = extractvalue { i64, i64 } %1525, 1
  %1528 = icmp sge i64 %1526, %1527
  %1529 = select i1 %1528, i64 0, i64 %1526
  %1530 = add i64 %1488, 1
  %1531 = select i1 %1528, i64 %1530, i64 %1488
  %1532 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1533 = load i64, ptr %4, align 8
  %1534 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1535 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1532, 0
  %1536 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1532, 1, 1, 0
  %1537 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1532, 1, 1, 1
  %1538 = mul i64 %1531, %1537
  %1539 = add i64 %1538, %1529
  %1540 = getelementptr inbounds bfloat, ptr %1535, i64 %1539
  %1541 = load bfloat, ptr %1540, align 2, !invariant.load !1
  %1542 = call i64 @llvm.smax.i64(i64 %1533, i64 1)
  br label %1543

1543:                                             ; preds = %1549, %1516
  %1544 = phi i64 [ 1, %1516 ], [ %1552, %1549 ]
  %1545 = phi bfloat [ %1541, %1516 ], [ %1558, %1549 ]
  %1546 = icmp slt i64 %1544, %1542
  br i1 %1546, label %1547, label %1548

1547:                                             ; preds = %1543
  br label %1549

1548:                                             ; preds = %1543
  br label %1559

1549:                                             ; preds = %1547
  %1550 = icmp eq i64 %1544, %1542
  %1551 = add i64 %1544, 1
  %1552 = select i1 %1550, i64 %1544, i64 %1551
  %1553 = mul i64 %1544, %1536
  %1554 = add i64 %1553, %1538
  %1555 = add i64 %1554, %1529
  %1556 = getelementptr inbounds bfloat, ptr %1535, i64 %1555
  %1557 = load bfloat, ptr %1556, align 2, !invariant.load !1
  %1558 = fadd contract bfloat %1545, %1557
  br label %1543

1559:                                             ; preds = %1548
  %1560 = phi bfloat [ %1545, %1548 ]
  %1561 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1534, 0
  %1562 = trunc i64 %1531 to i32
  %1563 = mul i32 %1562, 512
  %1564 = trunc i64 %1529 to i32
  %1565 = add i32 %1563, %1564
  %1566 = sext i32 %1565 to i64
  %1567 = getelementptr inbounds bfloat, ptr %1561, i64 %1566
  store bfloat %1560, ptr %1567, align 2
  %1568 = load { i64, i64 }, ptr %6, align 8
  %1569 = add i64 %1529, 1
  %1570 = extractvalue { i64, i64 } %1568, 1
  %1571 = icmp sge i64 %1569, %1570
  %1572 = select i1 %1571, i64 0, i64 %1569
  %1573 = add i64 %1531, 1
  %1574 = select i1 %1571, i64 %1573, i64 %1531
  %1575 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1576 = load i64, ptr %4, align 8
  %1577 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1578 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1575, 0
  %1579 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1575, 1, 1, 0
  %1580 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1575, 1, 1, 1
  %1581 = mul i64 %1574, %1580
  %1582 = add i64 %1581, %1572
  %1583 = getelementptr inbounds bfloat, ptr %1578, i64 %1582
  %1584 = load bfloat, ptr %1583, align 2, !invariant.load !1
  %1585 = call i64 @llvm.smax.i64(i64 %1576, i64 1)
  br label %1586

1586:                                             ; preds = %1592, %1559
  %1587 = phi i64 [ 1, %1559 ], [ %1595, %1592 ]
  %1588 = phi bfloat [ %1584, %1559 ], [ %1601, %1592 ]
  %1589 = icmp slt i64 %1587, %1585
  br i1 %1589, label %1590, label %1591

1590:                                             ; preds = %1586
  br label %1592

1591:                                             ; preds = %1586
  br label %1602

1592:                                             ; preds = %1590
  %1593 = icmp eq i64 %1587, %1585
  %1594 = add i64 %1587, 1
  %1595 = select i1 %1593, i64 %1587, i64 %1594
  %1596 = mul i64 %1587, %1579
  %1597 = add i64 %1596, %1581
  %1598 = add i64 %1597, %1572
  %1599 = getelementptr inbounds bfloat, ptr %1578, i64 %1598
  %1600 = load bfloat, ptr %1599, align 2, !invariant.load !1
  %1601 = fadd contract bfloat %1588, %1600
  br label %1586

1602:                                             ; preds = %1591
  %1603 = phi bfloat [ %1588, %1591 ]
  %1604 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1577, 0
  %1605 = trunc i64 %1574 to i32
  %1606 = mul i32 %1605, 512
  %1607 = trunc i64 %1572 to i32
  %1608 = add i32 %1606, %1607
  %1609 = sext i32 %1608 to i64
  %1610 = getelementptr inbounds bfloat, ptr %1604, i64 %1609
  store bfloat %1603, ptr %1610, align 2
  br label %1643

1611:                                             ; preds = %1254
  %1612 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1613 = load i64, ptr %4, align 8
  %1614 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1615 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1612, 0
  %1616 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1612, 1, 1, 0
  %1617 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1612, 1, 1, 1
  %1618 = mul i64 %1271, %1617
  %1619 = add i64 %1618, %1268
  %1620 = getelementptr inbounds bfloat, ptr %1615, i64 %1619
  %1621 = load <8 x bfloat>, ptr %1620, align 16, !invariant.load !1
  %1622 = call i64 @llvm.smax.i64(i64 %1613, i64 1)
  br label %1623

1623:                                             ; preds = %1629, %1611
  %1624 = phi i64 [ 1, %1611 ], [ %1632, %1629 ]
  %1625 = phi <8 x bfloat> [ %1621, %1611 ], [ %1638, %1629 ]
  %1626 = icmp slt i64 %1624, %1622
  br i1 %1626, label %1627, label %1628

1627:                                             ; preds = %1623
  br label %1629

1628:                                             ; preds = %1623
  br label %1639

1629:                                             ; preds = %1627
  %1630 = icmp eq i64 %1624, %1622
  %1631 = add i64 %1624, 1
  %1632 = select i1 %1630, i64 %1624, i64 %1631
  %1633 = mul i64 %1624, %1616
  %1634 = add i64 %1633, %1618
  %1635 = add i64 %1634, %1268
  %1636 = getelementptr inbounds bfloat, ptr %1615, i64 %1635
  %1637 = load <8 x bfloat>, ptr %1636, align 16, !invariant.load !1
  %1638 = fadd contract <8 x bfloat> %1625, %1637
  br label %1623

1639:                                             ; preds = %1628
  %1640 = phi <8 x bfloat> [ %1625, %1628 ]
  %1641 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1614, 0
  %1642 = getelementptr inbounds bfloat, ptr %1641, i64 %1275
  store <8 x bfloat> %1640, ptr %1642, align 16
  br label %1643

1643:                                             ; preds = %1639, %1602
  br label %1645

1644:                                             ; preds = %1248
  br label %1645

1645:                                             ; preds = %1644, %1643
  br label %29

1646:                                             ; preds = %58
  %1647 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %1648 = load i64, ptr %1647, align 8
  %1649 = icmp slt i64 %14, %1648
  br i1 %1649, label %1650, label %1705

1650:                                             ; preds = %1646
  %1651 = load i64, ptr %7, align 8
  %1652 = add i64 %1651, %14
  %1653 = load { i64, i64 }, ptr %6, align 8
  %1654 = trunc i64 %1652 to i32
  %1655 = extractvalue { i64, i64 } %1653, 1
  %1656 = trunc i64 %1655 to i32
  %1657 = icmp eq i32 %1656, 0
  %1658 = select i1 %1657, i32 1, i32 %1656
  %1659 = icmp eq i32 %1658, 0
  %1660 = select i1 %1659, i32 1, i32 %1658
  %1661 = udiv i32 %1654, %1660
  %1662 = select i1 %1659, i32 0, i32 %1661
  %1663 = urem i32 %1654, %1660
  %1664 = select i1 %1659, i32 0, i32 %1663
  %1665 = select i1 %1657, i32 0, i32 %1662
  %1666 = select i1 %1657, i32 0, i32 %1664
  %1667 = zext i32 %1665 to i64
  %1668 = zext i32 %1666 to i64
  %1669 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1670 = load i64, ptr %4, align 8
  %1671 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1672 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1669, 0
  %1673 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1669, 1, 1, 0
  %1674 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1669, 1, 1, 1
  %1675 = mul i64 %1667, %1674
  %1676 = add i64 %1675, %1668
  %1677 = getelementptr inbounds bfloat, ptr %1672, i64 %1676
  %1678 = load bfloat, ptr %1677, align 2, !invariant.load !1
  %1679 = call i64 @llvm.smax.i64(i64 %1670, i64 1)
  br label %1680

1680:                                             ; preds = %1686, %1650
  %1681 = phi i64 [ 1, %1650 ], [ %1689, %1686 ]
  %1682 = phi bfloat [ %1678, %1650 ], [ %1695, %1686 ]
  %1683 = icmp slt i64 %1681, %1679
  br i1 %1683, label %1684, label %1685

1684:                                             ; preds = %1680
  br label %1686

1685:                                             ; preds = %1680
  br label %1696

1686:                                             ; preds = %1684
  %1687 = icmp eq i64 %1681, %1679
  %1688 = add i64 %1681, 1
  %1689 = select i1 %1687, i64 %1681, i64 %1688
  %1690 = mul i64 %1681, %1673
  %1691 = add i64 %1690, %1675
  %1692 = add i64 %1691, %1668
  %1693 = getelementptr inbounds bfloat, ptr %1672, i64 %1692
  %1694 = load bfloat, ptr %1693, align 2, !invariant.load !1
  %1695 = fadd contract bfloat %1682, %1694
  br label %1680

1696:                                             ; preds = %1685
  %1697 = phi bfloat [ %1682, %1685 ]
  %1698 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1671, 0
  %1699 = trunc i64 %1667 to i32
  %1700 = mul i32 %1699, 512
  %1701 = trunc i64 %1668 to i32
  %1702 = add i32 %1700, %1701
  %1703 = sext i32 %1702 to i64
  %1704 = getelementptr inbounds bfloat, ptr %1698, i64 %1703
  store bfloat %1697, ptr %1704, align 2
  br label %1706

1705:                                             ; preds = %1646
  br label %1706

1706:                                             ; preds = %1705, %1696
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
