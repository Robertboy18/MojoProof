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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w8_b256_gs_True_c79178f5(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

29:                                               ; preds = %1653, %1
  %30 = phi i64 [ %24, %1 ], [ %54, %1653 ]
  %31 = phi i64 [ 0, %1 ], [ %55, %1653 ]
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
  %57 = icmp slt i64 %56, 0
  br i1 %52, label %58, label %59

58:                                               ; preds = %51
  br label %1654

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59
  %61 = load i64, ptr %20, align 8
  %62 = icmp slt i64 %53, %61
  br i1 %62, label %63, label %455

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
  %88 = add i64 %83, 8
  %89 = load i64, ptr %8, align 8
  %90 = icmp sgt i64 %88, %89
  br i1 %90, label %91, label %422

91:                                               ; preds = %63
  %92 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %93 = load i64, ptr %4, align 8
  %94 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %95 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 0
  %96 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 1, 1, 0
  %97 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 1, 1, 1
  %98 = mul i64 %77, %97
  %99 = add i64 %98, %83
  %100 = getelementptr inbounds bfloat, ptr %95, i64 %99
  %101 = load bfloat, ptr %100, align 2, !invariant.load !1
  %102 = call i64 @llvm.smax.i64(i64 %93, i64 1)
  br label %103

103:                                              ; preds = %109, %91
  %104 = phi i64 [ 1, %91 ], [ %112, %109 ]
  %105 = phi bfloat [ %101, %91 ], [ %118, %109 ]
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
  %116 = getelementptr inbounds bfloat, ptr %95, i64 %115
  %117 = load bfloat, ptr %116, align 2, !invariant.load !1
  %118 = fadd contract bfloat %105, %117
  br label %103

119:                                              ; preds = %108
  %120 = phi bfloat [ %105, %108 ]
  %121 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %94, 0
  %122 = getelementptr inbounds bfloat, ptr %121, i64 %86
  store bfloat %120, ptr %122, align 2
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
  %136 = getelementptr inbounds bfloat, ptr %131, i64 %135
  %137 = load bfloat, ptr %136, align 2, !invariant.load !1
  %138 = call i64 @llvm.smax.i64(i64 %129, i64 1)
  br label %139

139:                                              ; preds = %145, %119
  %140 = phi i64 [ 1, %119 ], [ %148, %145 ]
  %141 = phi bfloat [ %137, %119 ], [ %154, %145 ]
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
  %152 = getelementptr inbounds bfloat, ptr %131, i64 %151
  %153 = load bfloat, ptr %152, align 2, !invariant.load !1
  %154 = fadd contract bfloat %141, %153
  br label %139

155:                                              ; preds = %144
  %156 = phi bfloat [ %141, %144 ]
  %157 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %130, 0
  %158 = trunc i64 %127 to i32
  %159 = mul i32 %158, 512
  %160 = trunc i64 %126 to i32
  %161 = add i32 %159, %160
  %162 = sext i32 %161 to i64
  %163 = getelementptr inbounds bfloat, ptr %157, i64 %162
  store bfloat %156, ptr %163, align 2
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
  %179 = getelementptr inbounds bfloat, ptr %174, i64 %178
  %180 = load bfloat, ptr %179, align 2, !invariant.load !1
  %181 = call i64 @llvm.smax.i64(i64 %172, i64 1)
  br label %182

182:                                              ; preds = %188, %155
  %183 = phi i64 [ 1, %155 ], [ %191, %188 ]
  %184 = phi bfloat [ %180, %155 ], [ %197, %188 ]
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
  %195 = getelementptr inbounds bfloat, ptr %174, i64 %194
  %196 = load bfloat, ptr %195, align 2, !invariant.load !1
  %197 = fadd contract bfloat %184, %196
  br label %182

198:                                              ; preds = %187
  %199 = phi bfloat [ %184, %187 ]
  %200 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %173, 0
  %201 = trunc i64 %170 to i32
  %202 = mul i32 %201, 512
  %203 = trunc i64 %168 to i32
  %204 = add i32 %202, %203
  %205 = sext i32 %204 to i64
  %206 = getelementptr inbounds bfloat, ptr %200, i64 %205
  store bfloat %199, ptr %206, align 2
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
  %222 = getelementptr inbounds bfloat, ptr %217, i64 %221
  %223 = load bfloat, ptr %222, align 2, !invariant.load !1
  %224 = call i64 @llvm.smax.i64(i64 %215, i64 1)
  br label %225

225:                                              ; preds = %231, %198
  %226 = phi i64 [ 1, %198 ], [ %234, %231 ]
  %227 = phi bfloat [ %223, %198 ], [ %240, %231 ]
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
  %238 = getelementptr inbounds bfloat, ptr %217, i64 %237
  %239 = load bfloat, ptr %238, align 2, !invariant.load !1
  %240 = fadd contract bfloat %227, %239
  br label %225

241:                                              ; preds = %230
  %242 = phi bfloat [ %227, %230 ]
  %243 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %216, 0
  %244 = trunc i64 %213 to i32
  %245 = mul i32 %244, 512
  %246 = trunc i64 %211 to i32
  %247 = add i32 %245, %246
  %248 = sext i32 %247 to i64
  %249 = getelementptr inbounds bfloat, ptr %243, i64 %248
  store bfloat %242, ptr %249, align 2
  %250 = load { i64, i64 }, ptr %6, align 8
  %251 = add i64 %211, 1
  %252 = extractvalue { i64, i64 } %250, 1
  %253 = icmp sge i64 %251, %252
  %254 = select i1 %253, i64 0, i64 %251
  %255 = add i64 %213, 1
  %256 = select i1 %253, i64 %255, i64 %213
  %257 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %258 = load i64, ptr %4, align 8
  %259 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %260 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %257, 0
  %261 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %257, 1, 1, 0
  %262 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %257, 1, 1, 1
  %263 = mul i64 %256, %262
  %264 = add i64 %263, %254
  %265 = getelementptr inbounds bfloat, ptr %260, i64 %264
  %266 = load bfloat, ptr %265, align 2, !invariant.load !1
  %267 = call i64 @llvm.smax.i64(i64 %258, i64 1)
  br label %268

268:                                              ; preds = %274, %241
  %269 = phi i64 [ 1, %241 ], [ %277, %274 ]
  %270 = phi bfloat [ %266, %241 ], [ %283, %274 ]
  %271 = icmp slt i64 %269, %267
  br i1 %271, label %272, label %273

272:                                              ; preds = %268
  br label %274

273:                                              ; preds = %268
  br label %284

274:                                              ; preds = %272
  %275 = icmp eq i64 %269, %267
  %276 = add i64 %269, 1
  %277 = select i1 %275, i64 %269, i64 %276
  %278 = mul i64 %269, %261
  %279 = add i64 %278, %263
  %280 = add i64 %279, %254
  %281 = getelementptr inbounds bfloat, ptr %260, i64 %280
  %282 = load bfloat, ptr %281, align 2, !invariant.load !1
  %283 = fadd contract bfloat %270, %282
  br label %268

284:                                              ; preds = %273
  %285 = phi bfloat [ %270, %273 ]
  %286 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %259, 0
  %287 = trunc i64 %256 to i32
  %288 = mul i32 %287, 512
  %289 = trunc i64 %254 to i32
  %290 = add i32 %288, %289
  %291 = sext i32 %290 to i64
  %292 = getelementptr inbounds bfloat, ptr %286, i64 %291
  store bfloat %285, ptr %292, align 2
  %293 = load { i64, i64 }, ptr %6, align 8
  %294 = add i64 %254, 1
  %295 = extractvalue { i64, i64 } %293, 1
  %296 = icmp sge i64 %294, %295
  %297 = select i1 %296, i64 0, i64 %294
  %298 = add i64 %256, 1
  %299 = select i1 %296, i64 %298, i64 %256
  %300 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %301 = load i64, ptr %4, align 8
  %302 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %303 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %300, 0
  %304 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %300, 1, 1, 0
  %305 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %300, 1, 1, 1
  %306 = mul i64 %299, %305
  %307 = add i64 %306, %297
  %308 = getelementptr inbounds bfloat, ptr %303, i64 %307
  %309 = load bfloat, ptr %308, align 2, !invariant.load !1
  %310 = call i64 @llvm.smax.i64(i64 %301, i64 1)
  br label %311

311:                                              ; preds = %317, %284
  %312 = phi i64 [ 1, %284 ], [ %320, %317 ]
  %313 = phi bfloat [ %309, %284 ], [ %326, %317 ]
  %314 = icmp slt i64 %312, %310
  br i1 %314, label %315, label %316

315:                                              ; preds = %311
  br label %317

316:                                              ; preds = %311
  br label %327

317:                                              ; preds = %315
  %318 = icmp eq i64 %312, %310
  %319 = add i64 %312, 1
  %320 = select i1 %318, i64 %312, i64 %319
  %321 = mul i64 %312, %304
  %322 = add i64 %321, %306
  %323 = add i64 %322, %297
  %324 = getelementptr inbounds bfloat, ptr %303, i64 %323
  %325 = load bfloat, ptr %324, align 2, !invariant.load !1
  %326 = fadd contract bfloat %313, %325
  br label %311

327:                                              ; preds = %316
  %328 = phi bfloat [ %313, %316 ]
  %329 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %302, 0
  %330 = trunc i64 %299 to i32
  %331 = mul i32 %330, 512
  %332 = trunc i64 %297 to i32
  %333 = add i32 %331, %332
  %334 = sext i32 %333 to i64
  %335 = getelementptr inbounds bfloat, ptr %329, i64 %334
  store bfloat %328, ptr %335, align 2
  %336 = load { i64, i64 }, ptr %6, align 8
  %337 = add i64 %297, 1
  %338 = extractvalue { i64, i64 } %336, 1
  %339 = icmp sge i64 %337, %338
  %340 = select i1 %339, i64 0, i64 %337
  %341 = add i64 %299, 1
  %342 = select i1 %339, i64 %341, i64 %299
  %343 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %344 = load i64, ptr %4, align 8
  %345 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %346 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %343, 0
  %347 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %343, 1, 1, 0
  %348 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %343, 1, 1, 1
  %349 = mul i64 %342, %348
  %350 = add i64 %349, %340
  %351 = getelementptr inbounds bfloat, ptr %346, i64 %350
  %352 = load bfloat, ptr %351, align 2, !invariant.load !1
  %353 = call i64 @llvm.smax.i64(i64 %344, i64 1)
  br label %354

354:                                              ; preds = %360, %327
  %355 = phi i64 [ 1, %327 ], [ %363, %360 ]
  %356 = phi bfloat [ %352, %327 ], [ %369, %360 ]
  %357 = icmp slt i64 %355, %353
  br i1 %357, label %358, label %359

358:                                              ; preds = %354
  br label %360

359:                                              ; preds = %354
  br label %370

360:                                              ; preds = %358
  %361 = icmp eq i64 %355, %353
  %362 = add i64 %355, 1
  %363 = select i1 %361, i64 %355, i64 %362
  %364 = mul i64 %355, %347
  %365 = add i64 %364, %349
  %366 = add i64 %365, %340
  %367 = getelementptr inbounds bfloat, ptr %346, i64 %366
  %368 = load bfloat, ptr %367, align 2, !invariant.load !1
  %369 = fadd contract bfloat %356, %368
  br label %354

370:                                              ; preds = %359
  %371 = phi bfloat [ %356, %359 ]
  %372 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %345, 0
  %373 = trunc i64 %342 to i32
  %374 = mul i32 %373, 512
  %375 = trunc i64 %340 to i32
  %376 = add i32 %374, %375
  %377 = sext i32 %376 to i64
  %378 = getelementptr inbounds bfloat, ptr %372, i64 %377
  store bfloat %371, ptr %378, align 2
  %379 = load { i64, i64 }, ptr %6, align 8
  %380 = add i64 %340, 1
  %381 = extractvalue { i64, i64 } %379, 1
  %382 = icmp sge i64 %380, %381
  %383 = select i1 %382, i64 0, i64 %380
  %384 = add i64 %342, 1
  %385 = select i1 %382, i64 %384, i64 %342
  %386 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %387 = load i64, ptr %4, align 8
  %388 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %389 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %386, 0
  %390 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %386, 1, 1, 0
  %391 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %386, 1, 1, 1
  %392 = mul i64 %385, %391
  %393 = add i64 %392, %383
  %394 = getelementptr inbounds bfloat, ptr %389, i64 %393
  %395 = load bfloat, ptr %394, align 2, !invariant.load !1
  %396 = call i64 @llvm.smax.i64(i64 %387, i64 1)
  br label %397

397:                                              ; preds = %403, %370
  %398 = phi i64 [ 1, %370 ], [ %406, %403 ]
  %399 = phi bfloat [ %395, %370 ], [ %412, %403 ]
  %400 = icmp slt i64 %398, %396
  br i1 %400, label %401, label %402

401:                                              ; preds = %397
  br label %403

402:                                              ; preds = %397
  br label %413

403:                                              ; preds = %401
  %404 = icmp eq i64 %398, %396
  %405 = add i64 %398, 1
  %406 = select i1 %404, i64 %398, i64 %405
  %407 = mul i64 %398, %390
  %408 = add i64 %407, %392
  %409 = add i64 %408, %383
  %410 = getelementptr inbounds bfloat, ptr %389, i64 %409
  %411 = load bfloat, ptr %410, align 2, !invariant.load !1
  %412 = fadd contract bfloat %399, %411
  br label %397

413:                                              ; preds = %402
  %414 = phi bfloat [ %399, %402 ]
  %415 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %388, 0
  %416 = trunc i64 %385 to i32
  %417 = mul i32 %416, 512
  %418 = trunc i64 %383 to i32
  %419 = add i32 %417, %418
  %420 = sext i32 %419 to i64
  %421 = getelementptr inbounds bfloat, ptr %415, i64 %420
  store bfloat %414, ptr %421, align 2
  br label %454

422:                                              ; preds = %63
  %423 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %424 = load i64, ptr %4, align 8
  %425 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %426 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %423, 0
  %427 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %423, 1, 1, 0
  %428 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %423, 1, 1, 1
  %429 = mul i64 %77, %428
  %430 = add i64 %429, %83
  %431 = getelementptr inbounds bfloat, ptr %426, i64 %430
  %432 = load <8 x bfloat>, ptr %431, align 16, !invariant.load !1
  %433 = call i64 @llvm.smax.i64(i64 %424, i64 1)
  br label %434

434:                                              ; preds = %440, %422
  %435 = phi i64 [ 1, %422 ], [ %443, %440 ]
  %436 = phi <8 x bfloat> [ %432, %422 ], [ %449, %440 ]
  %437 = icmp slt i64 %435, %433
  br i1 %437, label %438, label %439

438:                                              ; preds = %434
  br label %440

439:                                              ; preds = %434
  br label %450

440:                                              ; preds = %438
  %441 = icmp eq i64 %435, %433
  %442 = add i64 %435, 1
  %443 = select i1 %441, i64 %435, i64 %442
  %444 = mul i64 %435, %427
  %445 = add i64 %444, %429
  %446 = add i64 %445, %83
  %447 = getelementptr inbounds bfloat, ptr %426, i64 %446
  %448 = load <8 x bfloat>, ptr %447, align 16, !invariant.load !1
  %449 = fadd contract <8 x bfloat> %436, %448
  br label %434

450:                                              ; preds = %439
  %451 = phi <8 x bfloat> [ %436, %439 ]
  %452 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %425, 0
  %453 = getelementptr inbounds bfloat, ptr %452, i64 %86
  store <8 x bfloat> %451, ptr %453, align 16
  br label %454

454:                                              ; preds = %450, %413
  br label %456

455:                                              ; preds = %60
  br label %456

456:                                              ; preds = %455, %454
  %457 = add i64 %53, %17
  %458 = mul i64 %457, 8
  %459 = icmp slt i64 %458, 0
  %460 = load i64, ptr %20, align 8
  %461 = icmp slt i64 %457, %460
  br i1 %461, label %462, label %854

462:                                              ; preds = %456
  %463 = load { i64, i64 }, ptr %6, align 8
  %464 = extractvalue { i64, i64 } %463, 1
  %465 = icmp eq i64 %464, 0
  %466 = select i1 %465, i64 1, i64 %464
  %467 = sdiv i64 %458, %466
  %468 = mul i64 %467, %464
  %469 = sub i64 %458, %468
  %470 = icmp slt i64 %464, 0
  %471 = xor i1 %470, %459
  %472 = icmp ne i64 %469, 0
  %473 = and i1 %471, %472
  %474 = select i1 %473, i64 1, i64 0
  %475 = sub i64 %467, %474
  %476 = select i1 %465, i64 0, i64 %475
  %477 = trunc i64 %476 to i32
  %478 = mul i32 %477, 512
  %479 = add i64 %476, 1
  %480 = select i1 %473, i64 %464, i64 0
  %481 = add i64 %469, %480
  %482 = select i1 %465, i64 0, i64 %481
  %483 = trunc i64 %482 to i32
  %484 = add i32 %478, %483
  %485 = sext i32 %484 to i64
  %486 = add i64 %482, 1
  %487 = add i64 %482, 8
  %488 = load i64, ptr %8, align 8
  %489 = icmp sgt i64 %487, %488
  br i1 %489, label %490, label %821

490:                                              ; preds = %462
  %491 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %492 = load i64, ptr %4, align 8
  %493 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %494 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %491, 0
  %495 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %491, 1, 1, 0
  %496 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %491, 1, 1, 1
  %497 = mul i64 %476, %496
  %498 = add i64 %497, %482
  %499 = getelementptr inbounds bfloat, ptr %494, i64 %498
  %500 = load bfloat, ptr %499, align 2, !invariant.load !1
  %501 = call i64 @llvm.smax.i64(i64 %492, i64 1)
  br label %502

502:                                              ; preds = %508, %490
  %503 = phi i64 [ 1, %490 ], [ %511, %508 ]
  %504 = phi bfloat [ %500, %490 ], [ %517, %508 ]
  %505 = icmp slt i64 %503, %501
  br i1 %505, label %506, label %507

506:                                              ; preds = %502
  br label %508

507:                                              ; preds = %502
  br label %518

508:                                              ; preds = %506
  %509 = icmp eq i64 %503, %501
  %510 = add i64 %503, 1
  %511 = select i1 %509, i64 %503, i64 %510
  %512 = mul i64 %503, %495
  %513 = add i64 %512, %497
  %514 = add i64 %513, %482
  %515 = getelementptr inbounds bfloat, ptr %494, i64 %514
  %516 = load bfloat, ptr %515, align 2, !invariant.load !1
  %517 = fadd contract bfloat %504, %516
  br label %502

518:                                              ; preds = %507
  %519 = phi bfloat [ %504, %507 ]
  %520 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %493, 0
  %521 = getelementptr inbounds bfloat, ptr %520, i64 %485
  store bfloat %519, ptr %521, align 2
  %522 = load { i64, i64 }, ptr %6, align 8
  %523 = extractvalue { i64, i64 } %522, 1
  %524 = icmp sge i64 %486, %523
  %525 = select i1 %524, i64 0, i64 %486
  %526 = select i1 %524, i64 %479, i64 %476
  %527 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %528 = load i64, ptr %4, align 8
  %529 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %530 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %527, 0
  %531 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %527, 1, 1, 0
  %532 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %527, 1, 1, 1
  %533 = mul i64 %526, %532
  %534 = add i64 %533, %525
  %535 = getelementptr inbounds bfloat, ptr %530, i64 %534
  %536 = load bfloat, ptr %535, align 2, !invariant.load !1
  %537 = call i64 @llvm.smax.i64(i64 %528, i64 1)
  br label %538

538:                                              ; preds = %544, %518
  %539 = phi i64 [ 1, %518 ], [ %547, %544 ]
  %540 = phi bfloat [ %536, %518 ], [ %553, %544 ]
  %541 = icmp slt i64 %539, %537
  br i1 %541, label %542, label %543

542:                                              ; preds = %538
  br label %544

543:                                              ; preds = %538
  br label %554

544:                                              ; preds = %542
  %545 = icmp eq i64 %539, %537
  %546 = add i64 %539, 1
  %547 = select i1 %545, i64 %539, i64 %546
  %548 = mul i64 %539, %531
  %549 = add i64 %548, %533
  %550 = add i64 %549, %525
  %551 = getelementptr inbounds bfloat, ptr %530, i64 %550
  %552 = load bfloat, ptr %551, align 2, !invariant.load !1
  %553 = fadd contract bfloat %540, %552
  br label %538

554:                                              ; preds = %543
  %555 = phi bfloat [ %540, %543 ]
  %556 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %529, 0
  %557 = trunc i64 %526 to i32
  %558 = mul i32 %557, 512
  %559 = trunc i64 %525 to i32
  %560 = add i32 %558, %559
  %561 = sext i32 %560 to i64
  %562 = getelementptr inbounds bfloat, ptr %556, i64 %561
  store bfloat %555, ptr %562, align 2
  %563 = load { i64, i64 }, ptr %6, align 8
  %564 = add i64 %525, 1
  %565 = extractvalue { i64, i64 } %563, 1
  %566 = icmp sge i64 %564, %565
  %567 = select i1 %566, i64 0, i64 %564
  %568 = add i64 %526, 1
  %569 = select i1 %566, i64 %568, i64 %526
  %570 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %571 = load i64, ptr %4, align 8
  %572 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %573 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %570, 0
  %574 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %570, 1, 1, 0
  %575 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %570, 1, 1, 1
  %576 = mul i64 %569, %575
  %577 = add i64 %576, %567
  %578 = getelementptr inbounds bfloat, ptr %573, i64 %577
  %579 = load bfloat, ptr %578, align 2, !invariant.load !1
  %580 = call i64 @llvm.smax.i64(i64 %571, i64 1)
  br label %581

581:                                              ; preds = %587, %554
  %582 = phi i64 [ 1, %554 ], [ %590, %587 ]
  %583 = phi bfloat [ %579, %554 ], [ %596, %587 ]
  %584 = icmp slt i64 %582, %580
  br i1 %584, label %585, label %586

585:                                              ; preds = %581
  br label %587

586:                                              ; preds = %581
  br label %597

587:                                              ; preds = %585
  %588 = icmp eq i64 %582, %580
  %589 = add i64 %582, 1
  %590 = select i1 %588, i64 %582, i64 %589
  %591 = mul i64 %582, %574
  %592 = add i64 %591, %576
  %593 = add i64 %592, %567
  %594 = getelementptr inbounds bfloat, ptr %573, i64 %593
  %595 = load bfloat, ptr %594, align 2, !invariant.load !1
  %596 = fadd contract bfloat %583, %595
  br label %581

597:                                              ; preds = %586
  %598 = phi bfloat [ %583, %586 ]
  %599 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %572, 0
  %600 = trunc i64 %569 to i32
  %601 = mul i32 %600, 512
  %602 = trunc i64 %567 to i32
  %603 = add i32 %601, %602
  %604 = sext i32 %603 to i64
  %605 = getelementptr inbounds bfloat, ptr %599, i64 %604
  store bfloat %598, ptr %605, align 2
  %606 = load { i64, i64 }, ptr %6, align 8
  %607 = add i64 %567, 1
  %608 = extractvalue { i64, i64 } %606, 1
  %609 = icmp sge i64 %607, %608
  %610 = select i1 %609, i64 0, i64 %607
  %611 = add i64 %569, 1
  %612 = select i1 %609, i64 %611, i64 %569
  %613 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %614 = load i64, ptr %4, align 8
  %615 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %616 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %613, 0
  %617 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %613, 1, 1, 0
  %618 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %613, 1, 1, 1
  %619 = mul i64 %612, %618
  %620 = add i64 %619, %610
  %621 = getelementptr inbounds bfloat, ptr %616, i64 %620
  %622 = load bfloat, ptr %621, align 2, !invariant.load !1
  %623 = call i64 @llvm.smax.i64(i64 %614, i64 1)
  br label %624

624:                                              ; preds = %630, %597
  %625 = phi i64 [ 1, %597 ], [ %633, %630 ]
  %626 = phi bfloat [ %622, %597 ], [ %639, %630 ]
  %627 = icmp slt i64 %625, %623
  br i1 %627, label %628, label %629

628:                                              ; preds = %624
  br label %630

629:                                              ; preds = %624
  br label %640

630:                                              ; preds = %628
  %631 = icmp eq i64 %625, %623
  %632 = add i64 %625, 1
  %633 = select i1 %631, i64 %625, i64 %632
  %634 = mul i64 %625, %617
  %635 = add i64 %634, %619
  %636 = add i64 %635, %610
  %637 = getelementptr inbounds bfloat, ptr %616, i64 %636
  %638 = load bfloat, ptr %637, align 2, !invariant.load !1
  %639 = fadd contract bfloat %626, %638
  br label %624

640:                                              ; preds = %629
  %641 = phi bfloat [ %626, %629 ]
  %642 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %615, 0
  %643 = trunc i64 %612 to i32
  %644 = mul i32 %643, 512
  %645 = trunc i64 %610 to i32
  %646 = add i32 %644, %645
  %647 = sext i32 %646 to i64
  %648 = getelementptr inbounds bfloat, ptr %642, i64 %647
  store bfloat %641, ptr %648, align 2
  %649 = load { i64, i64 }, ptr %6, align 8
  %650 = add i64 %610, 1
  %651 = extractvalue { i64, i64 } %649, 1
  %652 = icmp sge i64 %650, %651
  %653 = select i1 %652, i64 0, i64 %650
  %654 = add i64 %612, 1
  %655 = select i1 %652, i64 %654, i64 %612
  %656 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %657 = load i64, ptr %4, align 8
  %658 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %659 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %656, 0
  %660 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %656, 1, 1, 0
  %661 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %656, 1, 1, 1
  %662 = mul i64 %655, %661
  %663 = add i64 %662, %653
  %664 = getelementptr inbounds bfloat, ptr %659, i64 %663
  %665 = load bfloat, ptr %664, align 2, !invariant.load !1
  %666 = call i64 @llvm.smax.i64(i64 %657, i64 1)
  br label %667

667:                                              ; preds = %673, %640
  %668 = phi i64 [ 1, %640 ], [ %676, %673 ]
  %669 = phi bfloat [ %665, %640 ], [ %682, %673 ]
  %670 = icmp slt i64 %668, %666
  br i1 %670, label %671, label %672

671:                                              ; preds = %667
  br label %673

672:                                              ; preds = %667
  br label %683

673:                                              ; preds = %671
  %674 = icmp eq i64 %668, %666
  %675 = add i64 %668, 1
  %676 = select i1 %674, i64 %668, i64 %675
  %677 = mul i64 %668, %660
  %678 = add i64 %677, %662
  %679 = add i64 %678, %653
  %680 = getelementptr inbounds bfloat, ptr %659, i64 %679
  %681 = load bfloat, ptr %680, align 2, !invariant.load !1
  %682 = fadd contract bfloat %669, %681
  br label %667

683:                                              ; preds = %672
  %684 = phi bfloat [ %669, %672 ]
  %685 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %658, 0
  %686 = trunc i64 %655 to i32
  %687 = mul i32 %686, 512
  %688 = trunc i64 %653 to i32
  %689 = add i32 %687, %688
  %690 = sext i32 %689 to i64
  %691 = getelementptr inbounds bfloat, ptr %685, i64 %690
  store bfloat %684, ptr %691, align 2
  %692 = load { i64, i64 }, ptr %6, align 8
  %693 = add i64 %653, 1
  %694 = extractvalue { i64, i64 } %692, 1
  %695 = icmp sge i64 %693, %694
  %696 = select i1 %695, i64 0, i64 %693
  %697 = add i64 %655, 1
  %698 = select i1 %695, i64 %697, i64 %655
  %699 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %700 = load i64, ptr %4, align 8
  %701 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %702 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %699, 0
  %703 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %699, 1, 1, 0
  %704 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %699, 1, 1, 1
  %705 = mul i64 %698, %704
  %706 = add i64 %705, %696
  %707 = getelementptr inbounds bfloat, ptr %702, i64 %706
  %708 = load bfloat, ptr %707, align 2, !invariant.load !1
  %709 = call i64 @llvm.smax.i64(i64 %700, i64 1)
  br label %710

710:                                              ; preds = %716, %683
  %711 = phi i64 [ 1, %683 ], [ %719, %716 ]
  %712 = phi bfloat [ %708, %683 ], [ %725, %716 ]
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
  %722 = add i64 %721, %696
  %723 = getelementptr inbounds bfloat, ptr %702, i64 %722
  %724 = load bfloat, ptr %723, align 2, !invariant.load !1
  %725 = fadd contract bfloat %712, %724
  br label %710

726:                                              ; preds = %715
  %727 = phi bfloat [ %712, %715 ]
  %728 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %701, 0
  %729 = trunc i64 %698 to i32
  %730 = mul i32 %729, 512
  %731 = trunc i64 %696 to i32
  %732 = add i32 %730, %731
  %733 = sext i32 %732 to i64
  %734 = getelementptr inbounds bfloat, ptr %728, i64 %733
  store bfloat %727, ptr %734, align 2
  %735 = load { i64, i64 }, ptr %6, align 8
  %736 = add i64 %696, 1
  %737 = extractvalue { i64, i64 } %735, 1
  %738 = icmp sge i64 %736, %737
  %739 = select i1 %738, i64 0, i64 %736
  %740 = add i64 %698, 1
  %741 = select i1 %738, i64 %740, i64 %698
  %742 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %743 = load i64, ptr %4, align 8
  %744 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %745 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %742, 0
  %746 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %742, 1, 1, 0
  %747 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %742, 1, 1, 1
  %748 = mul i64 %741, %747
  %749 = add i64 %748, %739
  %750 = getelementptr inbounds bfloat, ptr %745, i64 %749
  %751 = load bfloat, ptr %750, align 2, !invariant.load !1
  %752 = call i64 @llvm.smax.i64(i64 %743, i64 1)
  br label %753

753:                                              ; preds = %759, %726
  %754 = phi i64 [ 1, %726 ], [ %762, %759 ]
  %755 = phi bfloat [ %751, %726 ], [ %768, %759 ]
  %756 = icmp slt i64 %754, %752
  br i1 %756, label %757, label %758

757:                                              ; preds = %753
  br label %759

758:                                              ; preds = %753
  br label %769

759:                                              ; preds = %757
  %760 = icmp eq i64 %754, %752
  %761 = add i64 %754, 1
  %762 = select i1 %760, i64 %754, i64 %761
  %763 = mul i64 %754, %746
  %764 = add i64 %763, %748
  %765 = add i64 %764, %739
  %766 = getelementptr inbounds bfloat, ptr %745, i64 %765
  %767 = load bfloat, ptr %766, align 2, !invariant.load !1
  %768 = fadd contract bfloat %755, %767
  br label %753

769:                                              ; preds = %758
  %770 = phi bfloat [ %755, %758 ]
  %771 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %744, 0
  %772 = trunc i64 %741 to i32
  %773 = mul i32 %772, 512
  %774 = trunc i64 %739 to i32
  %775 = add i32 %773, %774
  %776 = sext i32 %775 to i64
  %777 = getelementptr inbounds bfloat, ptr %771, i64 %776
  store bfloat %770, ptr %777, align 2
  %778 = load { i64, i64 }, ptr %6, align 8
  %779 = add i64 %739, 1
  %780 = extractvalue { i64, i64 } %778, 1
  %781 = icmp sge i64 %779, %780
  %782 = select i1 %781, i64 0, i64 %779
  %783 = add i64 %741, 1
  %784 = select i1 %781, i64 %783, i64 %741
  %785 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %786 = load i64, ptr %4, align 8
  %787 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %788 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %785, 0
  %789 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %785, 1, 1, 0
  %790 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %785, 1, 1, 1
  %791 = mul i64 %784, %790
  %792 = add i64 %791, %782
  %793 = getelementptr inbounds bfloat, ptr %788, i64 %792
  %794 = load bfloat, ptr %793, align 2, !invariant.load !1
  %795 = call i64 @llvm.smax.i64(i64 %786, i64 1)
  br label %796

796:                                              ; preds = %802, %769
  %797 = phi i64 [ 1, %769 ], [ %805, %802 ]
  %798 = phi bfloat [ %794, %769 ], [ %811, %802 ]
  %799 = icmp slt i64 %797, %795
  br i1 %799, label %800, label %801

800:                                              ; preds = %796
  br label %802

801:                                              ; preds = %796
  br label %812

802:                                              ; preds = %800
  %803 = icmp eq i64 %797, %795
  %804 = add i64 %797, 1
  %805 = select i1 %803, i64 %797, i64 %804
  %806 = mul i64 %797, %789
  %807 = add i64 %806, %791
  %808 = add i64 %807, %782
  %809 = getelementptr inbounds bfloat, ptr %788, i64 %808
  %810 = load bfloat, ptr %809, align 2, !invariant.load !1
  %811 = fadd contract bfloat %798, %810
  br label %796

812:                                              ; preds = %801
  %813 = phi bfloat [ %798, %801 ]
  %814 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %787, 0
  %815 = trunc i64 %784 to i32
  %816 = mul i32 %815, 512
  %817 = trunc i64 %782 to i32
  %818 = add i32 %816, %817
  %819 = sext i32 %818 to i64
  %820 = getelementptr inbounds bfloat, ptr %814, i64 %819
  store bfloat %813, ptr %820, align 2
  br label %853

821:                                              ; preds = %462
  %822 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %823 = load i64, ptr %4, align 8
  %824 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %825 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %822, 0
  %826 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %822, 1, 1, 0
  %827 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %822, 1, 1, 1
  %828 = mul i64 %476, %827
  %829 = add i64 %828, %482
  %830 = getelementptr inbounds bfloat, ptr %825, i64 %829
  %831 = load <8 x bfloat>, ptr %830, align 16, !invariant.load !1
  %832 = call i64 @llvm.smax.i64(i64 %823, i64 1)
  br label %833

833:                                              ; preds = %839, %821
  %834 = phi i64 [ 1, %821 ], [ %842, %839 ]
  %835 = phi <8 x bfloat> [ %831, %821 ], [ %848, %839 ]
  %836 = icmp slt i64 %834, %832
  br i1 %836, label %837, label %838

837:                                              ; preds = %833
  br label %839

838:                                              ; preds = %833
  br label %849

839:                                              ; preds = %837
  %840 = icmp eq i64 %834, %832
  %841 = add i64 %834, 1
  %842 = select i1 %840, i64 %834, i64 %841
  %843 = mul i64 %834, %826
  %844 = add i64 %843, %828
  %845 = add i64 %844, %482
  %846 = getelementptr inbounds bfloat, ptr %825, i64 %845
  %847 = load <8 x bfloat>, ptr %846, align 16, !invariant.load !1
  %848 = fadd contract <8 x bfloat> %835, %847
  br label %833

849:                                              ; preds = %838
  %850 = phi <8 x bfloat> [ %835, %838 ]
  %851 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %824, 0
  %852 = getelementptr inbounds bfloat, ptr %851, i64 %485
  store <8 x bfloat> %850, ptr %852, align 16
  br label %853

853:                                              ; preds = %849, %812
  br label %855

854:                                              ; preds = %456
  br label %855

855:                                              ; preds = %854, %853
  %856 = add i64 %53, %19
  %857 = mul i64 %856, 8
  %858 = icmp slt i64 %857, 0
  %859 = load i64, ptr %20, align 8
  %860 = icmp slt i64 %856, %859
  br i1 %860, label %861, label %1253

861:                                              ; preds = %855
  %862 = load { i64, i64 }, ptr %6, align 8
  %863 = extractvalue { i64, i64 } %862, 1
  %864 = icmp eq i64 %863, 0
  %865 = select i1 %864, i64 1, i64 %863
  %866 = sdiv i64 %857, %865
  %867 = mul i64 %866, %863
  %868 = sub i64 %857, %867
  %869 = icmp slt i64 %863, 0
  %870 = xor i1 %869, %858
  %871 = icmp ne i64 %868, 0
  %872 = and i1 %870, %871
  %873 = select i1 %872, i64 1, i64 0
  %874 = sub i64 %866, %873
  %875 = select i1 %864, i64 0, i64 %874
  %876 = trunc i64 %875 to i32
  %877 = mul i32 %876, 512
  %878 = add i64 %875, 1
  %879 = select i1 %872, i64 %863, i64 0
  %880 = add i64 %868, %879
  %881 = select i1 %864, i64 0, i64 %880
  %882 = trunc i64 %881 to i32
  %883 = add i32 %877, %882
  %884 = sext i32 %883 to i64
  %885 = add i64 %881, 1
  %886 = add i64 %881, 8
  %887 = load i64, ptr %8, align 8
  %888 = icmp sgt i64 %886, %887
  br i1 %888, label %889, label %1220

889:                                              ; preds = %861
  %890 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %891 = load i64, ptr %4, align 8
  %892 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %893 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %890, 0
  %894 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %890, 1, 1, 0
  %895 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %890, 1, 1, 1
  %896 = mul i64 %875, %895
  %897 = add i64 %896, %881
  %898 = getelementptr inbounds bfloat, ptr %893, i64 %897
  %899 = load bfloat, ptr %898, align 2, !invariant.load !1
  %900 = call i64 @llvm.smax.i64(i64 %891, i64 1)
  br label %901

901:                                              ; preds = %907, %889
  %902 = phi i64 [ 1, %889 ], [ %910, %907 ]
  %903 = phi bfloat [ %899, %889 ], [ %916, %907 ]
  %904 = icmp slt i64 %902, %900
  br i1 %904, label %905, label %906

905:                                              ; preds = %901
  br label %907

906:                                              ; preds = %901
  br label %917

907:                                              ; preds = %905
  %908 = icmp eq i64 %902, %900
  %909 = add i64 %902, 1
  %910 = select i1 %908, i64 %902, i64 %909
  %911 = mul i64 %902, %894
  %912 = add i64 %911, %896
  %913 = add i64 %912, %881
  %914 = getelementptr inbounds bfloat, ptr %893, i64 %913
  %915 = load bfloat, ptr %914, align 2, !invariant.load !1
  %916 = fadd contract bfloat %903, %915
  br label %901

917:                                              ; preds = %906
  %918 = phi bfloat [ %903, %906 ]
  %919 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %892, 0
  %920 = getelementptr inbounds bfloat, ptr %919, i64 %884
  store bfloat %918, ptr %920, align 2
  %921 = load { i64, i64 }, ptr %6, align 8
  %922 = extractvalue { i64, i64 } %921, 1
  %923 = icmp sge i64 %885, %922
  %924 = select i1 %923, i64 0, i64 %885
  %925 = select i1 %923, i64 %878, i64 %875
  %926 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %927 = load i64, ptr %4, align 8
  %928 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %929 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %926, 0
  %930 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %926, 1, 1, 0
  %931 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %926, 1, 1, 1
  %932 = mul i64 %925, %931
  %933 = add i64 %932, %924
  %934 = getelementptr inbounds bfloat, ptr %929, i64 %933
  %935 = load bfloat, ptr %934, align 2, !invariant.load !1
  %936 = call i64 @llvm.smax.i64(i64 %927, i64 1)
  br label %937

937:                                              ; preds = %943, %917
  %938 = phi i64 [ 1, %917 ], [ %946, %943 ]
  %939 = phi bfloat [ %935, %917 ], [ %952, %943 ]
  %940 = icmp slt i64 %938, %936
  br i1 %940, label %941, label %942

941:                                              ; preds = %937
  br label %943

942:                                              ; preds = %937
  br label %953

943:                                              ; preds = %941
  %944 = icmp eq i64 %938, %936
  %945 = add i64 %938, 1
  %946 = select i1 %944, i64 %938, i64 %945
  %947 = mul i64 %938, %930
  %948 = add i64 %947, %932
  %949 = add i64 %948, %924
  %950 = getelementptr inbounds bfloat, ptr %929, i64 %949
  %951 = load bfloat, ptr %950, align 2, !invariant.load !1
  %952 = fadd contract bfloat %939, %951
  br label %937

953:                                              ; preds = %942
  %954 = phi bfloat [ %939, %942 ]
  %955 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %928, 0
  %956 = trunc i64 %925 to i32
  %957 = mul i32 %956, 512
  %958 = trunc i64 %924 to i32
  %959 = add i32 %957, %958
  %960 = sext i32 %959 to i64
  %961 = getelementptr inbounds bfloat, ptr %955, i64 %960
  store bfloat %954, ptr %961, align 2
  %962 = load { i64, i64 }, ptr %6, align 8
  %963 = add i64 %924, 1
  %964 = extractvalue { i64, i64 } %962, 1
  %965 = icmp sge i64 %963, %964
  %966 = select i1 %965, i64 0, i64 %963
  %967 = add i64 %925, 1
  %968 = select i1 %965, i64 %967, i64 %925
  %969 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %970 = load i64, ptr %4, align 8
  %971 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %972 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %969, 0
  %973 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %969, 1, 1, 0
  %974 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %969, 1, 1, 1
  %975 = mul i64 %968, %974
  %976 = add i64 %975, %966
  %977 = getelementptr inbounds bfloat, ptr %972, i64 %976
  %978 = load bfloat, ptr %977, align 2, !invariant.load !1
  %979 = call i64 @llvm.smax.i64(i64 %970, i64 1)
  br label %980

980:                                              ; preds = %986, %953
  %981 = phi i64 [ 1, %953 ], [ %989, %986 ]
  %982 = phi bfloat [ %978, %953 ], [ %995, %986 ]
  %983 = icmp slt i64 %981, %979
  br i1 %983, label %984, label %985

984:                                              ; preds = %980
  br label %986

985:                                              ; preds = %980
  br label %996

986:                                              ; preds = %984
  %987 = icmp eq i64 %981, %979
  %988 = add i64 %981, 1
  %989 = select i1 %987, i64 %981, i64 %988
  %990 = mul i64 %981, %973
  %991 = add i64 %990, %975
  %992 = add i64 %991, %966
  %993 = getelementptr inbounds bfloat, ptr %972, i64 %992
  %994 = load bfloat, ptr %993, align 2, !invariant.load !1
  %995 = fadd contract bfloat %982, %994
  br label %980

996:                                              ; preds = %985
  %997 = phi bfloat [ %982, %985 ]
  %998 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %971, 0
  %999 = trunc i64 %968 to i32
  %1000 = mul i32 %999, 512
  %1001 = trunc i64 %966 to i32
  %1002 = add i32 %1000, %1001
  %1003 = sext i32 %1002 to i64
  %1004 = getelementptr inbounds bfloat, ptr %998, i64 %1003
  store bfloat %997, ptr %1004, align 2
  %1005 = load { i64, i64 }, ptr %6, align 8
  %1006 = add i64 %966, 1
  %1007 = extractvalue { i64, i64 } %1005, 1
  %1008 = icmp sge i64 %1006, %1007
  %1009 = select i1 %1008, i64 0, i64 %1006
  %1010 = add i64 %968, 1
  %1011 = select i1 %1008, i64 %1010, i64 %968
  %1012 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1013 = load i64, ptr %4, align 8
  %1014 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1015 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1012, 0
  %1016 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1012, 1, 1, 0
  %1017 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1012, 1, 1, 1
  %1018 = mul i64 %1011, %1017
  %1019 = add i64 %1018, %1009
  %1020 = getelementptr inbounds bfloat, ptr %1015, i64 %1019
  %1021 = load bfloat, ptr %1020, align 2, !invariant.load !1
  %1022 = call i64 @llvm.smax.i64(i64 %1013, i64 1)
  br label %1023

1023:                                             ; preds = %1029, %996
  %1024 = phi i64 [ 1, %996 ], [ %1032, %1029 ]
  %1025 = phi bfloat [ %1021, %996 ], [ %1038, %1029 ]
  %1026 = icmp slt i64 %1024, %1022
  br i1 %1026, label %1027, label %1028

1027:                                             ; preds = %1023
  br label %1029

1028:                                             ; preds = %1023
  br label %1039

1029:                                             ; preds = %1027
  %1030 = icmp eq i64 %1024, %1022
  %1031 = add i64 %1024, 1
  %1032 = select i1 %1030, i64 %1024, i64 %1031
  %1033 = mul i64 %1024, %1016
  %1034 = add i64 %1033, %1018
  %1035 = add i64 %1034, %1009
  %1036 = getelementptr inbounds bfloat, ptr %1015, i64 %1035
  %1037 = load bfloat, ptr %1036, align 2, !invariant.load !1
  %1038 = fadd contract bfloat %1025, %1037
  br label %1023

1039:                                             ; preds = %1028
  %1040 = phi bfloat [ %1025, %1028 ]
  %1041 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1014, 0
  %1042 = trunc i64 %1011 to i32
  %1043 = mul i32 %1042, 512
  %1044 = trunc i64 %1009 to i32
  %1045 = add i32 %1043, %1044
  %1046 = sext i32 %1045 to i64
  %1047 = getelementptr inbounds bfloat, ptr %1041, i64 %1046
  store bfloat %1040, ptr %1047, align 2
  %1048 = load { i64, i64 }, ptr %6, align 8
  %1049 = add i64 %1009, 1
  %1050 = extractvalue { i64, i64 } %1048, 1
  %1051 = icmp sge i64 %1049, %1050
  %1052 = select i1 %1051, i64 0, i64 %1049
  %1053 = add i64 %1011, 1
  %1054 = select i1 %1051, i64 %1053, i64 %1011
  %1055 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1056 = load i64, ptr %4, align 8
  %1057 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1058 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1055, 0
  %1059 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1055, 1, 1, 0
  %1060 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1055, 1, 1, 1
  %1061 = mul i64 %1054, %1060
  %1062 = add i64 %1061, %1052
  %1063 = getelementptr inbounds bfloat, ptr %1058, i64 %1062
  %1064 = load bfloat, ptr %1063, align 2, !invariant.load !1
  %1065 = call i64 @llvm.smax.i64(i64 %1056, i64 1)
  br label %1066

1066:                                             ; preds = %1072, %1039
  %1067 = phi i64 [ 1, %1039 ], [ %1075, %1072 ]
  %1068 = phi bfloat [ %1064, %1039 ], [ %1081, %1072 ]
  %1069 = icmp slt i64 %1067, %1065
  br i1 %1069, label %1070, label %1071

1070:                                             ; preds = %1066
  br label %1072

1071:                                             ; preds = %1066
  br label %1082

1072:                                             ; preds = %1070
  %1073 = icmp eq i64 %1067, %1065
  %1074 = add i64 %1067, 1
  %1075 = select i1 %1073, i64 %1067, i64 %1074
  %1076 = mul i64 %1067, %1059
  %1077 = add i64 %1076, %1061
  %1078 = add i64 %1077, %1052
  %1079 = getelementptr inbounds bfloat, ptr %1058, i64 %1078
  %1080 = load bfloat, ptr %1079, align 2, !invariant.load !1
  %1081 = fadd contract bfloat %1068, %1080
  br label %1066

1082:                                             ; preds = %1071
  %1083 = phi bfloat [ %1068, %1071 ]
  %1084 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1057, 0
  %1085 = trunc i64 %1054 to i32
  %1086 = mul i32 %1085, 512
  %1087 = trunc i64 %1052 to i32
  %1088 = add i32 %1086, %1087
  %1089 = sext i32 %1088 to i64
  %1090 = getelementptr inbounds bfloat, ptr %1084, i64 %1089
  store bfloat %1083, ptr %1090, align 2
  %1091 = load { i64, i64 }, ptr %6, align 8
  %1092 = add i64 %1052, 1
  %1093 = extractvalue { i64, i64 } %1091, 1
  %1094 = icmp sge i64 %1092, %1093
  %1095 = select i1 %1094, i64 0, i64 %1092
  %1096 = add i64 %1054, 1
  %1097 = select i1 %1094, i64 %1096, i64 %1054
  %1098 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1099 = load i64, ptr %4, align 8
  %1100 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1101 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1098, 0
  %1102 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1098, 1, 1, 0
  %1103 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1098, 1, 1, 1
  %1104 = mul i64 %1097, %1103
  %1105 = add i64 %1104, %1095
  %1106 = getelementptr inbounds bfloat, ptr %1101, i64 %1105
  %1107 = load bfloat, ptr %1106, align 2, !invariant.load !1
  %1108 = call i64 @llvm.smax.i64(i64 %1099, i64 1)
  br label %1109

1109:                                             ; preds = %1115, %1082
  %1110 = phi i64 [ 1, %1082 ], [ %1118, %1115 ]
  %1111 = phi bfloat [ %1107, %1082 ], [ %1124, %1115 ]
  %1112 = icmp slt i64 %1110, %1108
  br i1 %1112, label %1113, label %1114

1113:                                             ; preds = %1109
  br label %1115

1114:                                             ; preds = %1109
  br label %1125

1115:                                             ; preds = %1113
  %1116 = icmp eq i64 %1110, %1108
  %1117 = add i64 %1110, 1
  %1118 = select i1 %1116, i64 %1110, i64 %1117
  %1119 = mul i64 %1110, %1102
  %1120 = add i64 %1119, %1104
  %1121 = add i64 %1120, %1095
  %1122 = getelementptr inbounds bfloat, ptr %1101, i64 %1121
  %1123 = load bfloat, ptr %1122, align 2, !invariant.load !1
  %1124 = fadd contract bfloat %1111, %1123
  br label %1109

1125:                                             ; preds = %1114
  %1126 = phi bfloat [ %1111, %1114 ]
  %1127 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1100, 0
  %1128 = trunc i64 %1097 to i32
  %1129 = mul i32 %1128, 512
  %1130 = trunc i64 %1095 to i32
  %1131 = add i32 %1129, %1130
  %1132 = sext i32 %1131 to i64
  %1133 = getelementptr inbounds bfloat, ptr %1127, i64 %1132
  store bfloat %1126, ptr %1133, align 2
  %1134 = load { i64, i64 }, ptr %6, align 8
  %1135 = add i64 %1095, 1
  %1136 = extractvalue { i64, i64 } %1134, 1
  %1137 = icmp sge i64 %1135, %1136
  %1138 = select i1 %1137, i64 0, i64 %1135
  %1139 = add i64 %1097, 1
  %1140 = select i1 %1137, i64 %1139, i64 %1097
  %1141 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1142 = load i64, ptr %4, align 8
  %1143 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1144 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1141, 0
  %1145 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1141, 1, 1, 0
  %1146 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1141, 1, 1, 1
  %1147 = mul i64 %1140, %1146
  %1148 = add i64 %1147, %1138
  %1149 = getelementptr inbounds bfloat, ptr %1144, i64 %1148
  %1150 = load bfloat, ptr %1149, align 2, !invariant.load !1
  %1151 = call i64 @llvm.smax.i64(i64 %1142, i64 1)
  br label %1152

1152:                                             ; preds = %1158, %1125
  %1153 = phi i64 [ 1, %1125 ], [ %1161, %1158 ]
  %1154 = phi bfloat [ %1150, %1125 ], [ %1167, %1158 ]
  %1155 = icmp slt i64 %1153, %1151
  br i1 %1155, label %1156, label %1157

1156:                                             ; preds = %1152
  br label %1158

1157:                                             ; preds = %1152
  br label %1168

1158:                                             ; preds = %1156
  %1159 = icmp eq i64 %1153, %1151
  %1160 = add i64 %1153, 1
  %1161 = select i1 %1159, i64 %1153, i64 %1160
  %1162 = mul i64 %1153, %1145
  %1163 = add i64 %1162, %1147
  %1164 = add i64 %1163, %1138
  %1165 = getelementptr inbounds bfloat, ptr %1144, i64 %1164
  %1166 = load bfloat, ptr %1165, align 2, !invariant.load !1
  %1167 = fadd contract bfloat %1154, %1166
  br label %1152

1168:                                             ; preds = %1157
  %1169 = phi bfloat [ %1154, %1157 ]
  %1170 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1143, 0
  %1171 = trunc i64 %1140 to i32
  %1172 = mul i32 %1171, 512
  %1173 = trunc i64 %1138 to i32
  %1174 = add i32 %1172, %1173
  %1175 = sext i32 %1174 to i64
  %1176 = getelementptr inbounds bfloat, ptr %1170, i64 %1175
  store bfloat %1169, ptr %1176, align 2
  %1177 = load { i64, i64 }, ptr %6, align 8
  %1178 = add i64 %1138, 1
  %1179 = extractvalue { i64, i64 } %1177, 1
  %1180 = icmp sge i64 %1178, %1179
  %1181 = select i1 %1180, i64 0, i64 %1178
  %1182 = add i64 %1140, 1
  %1183 = select i1 %1180, i64 %1182, i64 %1140
  %1184 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1185 = load i64, ptr %4, align 8
  %1186 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1187 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1184, 0
  %1188 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1184, 1, 1, 0
  %1189 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1184, 1, 1, 1
  %1190 = mul i64 %1183, %1189
  %1191 = add i64 %1190, %1181
  %1192 = getelementptr inbounds bfloat, ptr %1187, i64 %1191
  %1193 = load bfloat, ptr %1192, align 2, !invariant.load !1
  %1194 = call i64 @llvm.smax.i64(i64 %1185, i64 1)
  br label %1195

1195:                                             ; preds = %1201, %1168
  %1196 = phi i64 [ 1, %1168 ], [ %1204, %1201 ]
  %1197 = phi bfloat [ %1193, %1168 ], [ %1210, %1201 ]
  %1198 = icmp slt i64 %1196, %1194
  br i1 %1198, label %1199, label %1200

1199:                                             ; preds = %1195
  br label %1201

1200:                                             ; preds = %1195
  br label %1211

1201:                                             ; preds = %1199
  %1202 = icmp eq i64 %1196, %1194
  %1203 = add i64 %1196, 1
  %1204 = select i1 %1202, i64 %1196, i64 %1203
  %1205 = mul i64 %1196, %1188
  %1206 = add i64 %1205, %1190
  %1207 = add i64 %1206, %1181
  %1208 = getelementptr inbounds bfloat, ptr %1187, i64 %1207
  %1209 = load bfloat, ptr %1208, align 2, !invariant.load !1
  %1210 = fadd contract bfloat %1197, %1209
  br label %1195

1211:                                             ; preds = %1200
  %1212 = phi bfloat [ %1197, %1200 ]
  %1213 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1186, 0
  %1214 = trunc i64 %1183 to i32
  %1215 = mul i32 %1214, 512
  %1216 = trunc i64 %1181 to i32
  %1217 = add i32 %1215, %1216
  %1218 = sext i32 %1217 to i64
  %1219 = getelementptr inbounds bfloat, ptr %1213, i64 %1218
  store bfloat %1212, ptr %1219, align 2
  br label %1252

1220:                                             ; preds = %861
  %1221 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1222 = load i64, ptr %4, align 8
  %1223 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1224 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1221, 0
  %1225 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1221, 1, 1, 0
  %1226 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1221, 1, 1, 1
  %1227 = mul i64 %875, %1226
  %1228 = add i64 %1227, %881
  %1229 = getelementptr inbounds bfloat, ptr %1224, i64 %1228
  %1230 = load <8 x bfloat>, ptr %1229, align 16, !invariant.load !1
  %1231 = call i64 @llvm.smax.i64(i64 %1222, i64 1)
  br label %1232

1232:                                             ; preds = %1238, %1220
  %1233 = phi i64 [ 1, %1220 ], [ %1241, %1238 ]
  %1234 = phi <8 x bfloat> [ %1230, %1220 ], [ %1247, %1238 ]
  %1235 = icmp slt i64 %1233, %1231
  br i1 %1235, label %1236, label %1237

1236:                                             ; preds = %1232
  br label %1238

1237:                                             ; preds = %1232
  br label %1248

1238:                                             ; preds = %1236
  %1239 = icmp eq i64 %1233, %1231
  %1240 = add i64 %1233, 1
  %1241 = select i1 %1239, i64 %1233, i64 %1240
  %1242 = mul i64 %1233, %1225
  %1243 = add i64 %1242, %1227
  %1244 = add i64 %1243, %881
  %1245 = getelementptr inbounds bfloat, ptr %1224, i64 %1244
  %1246 = load <8 x bfloat>, ptr %1245, align 16, !invariant.load !1
  %1247 = fadd contract <8 x bfloat> %1234, %1246
  br label %1232

1248:                                             ; preds = %1237
  %1249 = phi <8 x bfloat> [ %1234, %1237 ]
  %1250 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1223, 0
  %1251 = getelementptr inbounds bfloat, ptr %1250, i64 %884
  store <8 x bfloat> %1249, ptr %1251, align 16
  br label %1252

1252:                                             ; preds = %1248, %1211
  br label %1254

1253:                                             ; preds = %855
  br label %1254

1254:                                             ; preds = %1253, %1252
  %1255 = add i64 %53, %18
  %1256 = mul i64 %1255, 8
  %1257 = icmp slt i64 %1256, 0
  %1258 = load i64, ptr %20, align 8
  %1259 = icmp slt i64 %1255, %1258
  br i1 %1259, label %1260, label %1652

1260:                                             ; preds = %1254
  %1261 = load { i64, i64 }, ptr %6, align 8
  %1262 = extractvalue { i64, i64 } %1261, 1
  %1263 = icmp eq i64 %1262, 0
  %1264 = select i1 %1263, i64 1, i64 %1262
  %1265 = sdiv i64 %1256, %1264
  %1266 = mul i64 %1265, %1262
  %1267 = sub i64 %1256, %1266
  %1268 = icmp slt i64 %1262, 0
  %1269 = xor i1 %1268, %1257
  %1270 = icmp ne i64 %1267, 0
  %1271 = and i1 %1269, %1270
  %1272 = select i1 %1271, i64 1, i64 0
  %1273 = sub i64 %1265, %1272
  %1274 = select i1 %1263, i64 0, i64 %1273
  %1275 = trunc i64 %1274 to i32
  %1276 = mul i32 %1275, 512
  %1277 = add i64 %1274, 1
  %1278 = select i1 %1271, i64 %1262, i64 0
  %1279 = add i64 %1267, %1278
  %1280 = select i1 %1263, i64 0, i64 %1279
  %1281 = trunc i64 %1280 to i32
  %1282 = add i32 %1276, %1281
  %1283 = sext i32 %1282 to i64
  %1284 = add i64 %1280, 1
  %1285 = add i64 %1280, 8
  %1286 = load i64, ptr %8, align 8
  %1287 = icmp sgt i64 %1285, %1286
  br i1 %1287, label %1288, label %1619

1288:                                             ; preds = %1260
  %1289 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1290 = load i64, ptr %4, align 8
  %1291 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1292 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1289, 0
  %1293 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1289, 1, 1, 0
  %1294 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1289, 1, 1, 1
  %1295 = mul i64 %1274, %1294
  %1296 = add i64 %1295, %1280
  %1297 = getelementptr inbounds bfloat, ptr %1292, i64 %1296
  %1298 = load bfloat, ptr %1297, align 2, !invariant.load !1
  %1299 = call i64 @llvm.smax.i64(i64 %1290, i64 1)
  br label %1300

1300:                                             ; preds = %1306, %1288
  %1301 = phi i64 [ 1, %1288 ], [ %1309, %1306 ]
  %1302 = phi bfloat [ %1298, %1288 ], [ %1315, %1306 ]
  %1303 = icmp slt i64 %1301, %1299
  br i1 %1303, label %1304, label %1305

1304:                                             ; preds = %1300
  br label %1306

1305:                                             ; preds = %1300
  br label %1316

1306:                                             ; preds = %1304
  %1307 = icmp eq i64 %1301, %1299
  %1308 = add i64 %1301, 1
  %1309 = select i1 %1307, i64 %1301, i64 %1308
  %1310 = mul i64 %1301, %1293
  %1311 = add i64 %1310, %1295
  %1312 = add i64 %1311, %1280
  %1313 = getelementptr inbounds bfloat, ptr %1292, i64 %1312
  %1314 = load bfloat, ptr %1313, align 2, !invariant.load !1
  %1315 = fadd contract bfloat %1302, %1314
  br label %1300

1316:                                             ; preds = %1305
  %1317 = phi bfloat [ %1302, %1305 ]
  %1318 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1291, 0
  %1319 = getelementptr inbounds bfloat, ptr %1318, i64 %1283
  store bfloat %1317, ptr %1319, align 2
  %1320 = load { i64, i64 }, ptr %6, align 8
  %1321 = extractvalue { i64, i64 } %1320, 1
  %1322 = icmp sge i64 %1284, %1321
  %1323 = select i1 %1322, i64 0, i64 %1284
  %1324 = select i1 %1322, i64 %1277, i64 %1274
  %1325 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1326 = load i64, ptr %4, align 8
  %1327 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1328 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1325, 0
  %1329 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1325, 1, 1, 0
  %1330 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1325, 1, 1, 1
  %1331 = mul i64 %1324, %1330
  %1332 = add i64 %1331, %1323
  %1333 = getelementptr inbounds bfloat, ptr %1328, i64 %1332
  %1334 = load bfloat, ptr %1333, align 2, !invariant.load !1
  %1335 = call i64 @llvm.smax.i64(i64 %1326, i64 1)
  br label %1336

1336:                                             ; preds = %1342, %1316
  %1337 = phi i64 [ 1, %1316 ], [ %1345, %1342 ]
  %1338 = phi bfloat [ %1334, %1316 ], [ %1351, %1342 ]
  %1339 = icmp slt i64 %1337, %1335
  br i1 %1339, label %1340, label %1341

1340:                                             ; preds = %1336
  br label %1342

1341:                                             ; preds = %1336
  br label %1352

1342:                                             ; preds = %1340
  %1343 = icmp eq i64 %1337, %1335
  %1344 = add i64 %1337, 1
  %1345 = select i1 %1343, i64 %1337, i64 %1344
  %1346 = mul i64 %1337, %1329
  %1347 = add i64 %1346, %1331
  %1348 = add i64 %1347, %1323
  %1349 = getelementptr inbounds bfloat, ptr %1328, i64 %1348
  %1350 = load bfloat, ptr %1349, align 2, !invariant.load !1
  %1351 = fadd contract bfloat %1338, %1350
  br label %1336

1352:                                             ; preds = %1341
  %1353 = phi bfloat [ %1338, %1341 ]
  %1354 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1327, 0
  %1355 = trunc i64 %1324 to i32
  %1356 = mul i32 %1355, 512
  %1357 = trunc i64 %1323 to i32
  %1358 = add i32 %1356, %1357
  %1359 = sext i32 %1358 to i64
  %1360 = getelementptr inbounds bfloat, ptr %1354, i64 %1359
  store bfloat %1353, ptr %1360, align 2
  %1361 = load { i64, i64 }, ptr %6, align 8
  %1362 = add i64 %1323, 1
  %1363 = extractvalue { i64, i64 } %1361, 1
  %1364 = icmp sge i64 %1362, %1363
  %1365 = select i1 %1364, i64 0, i64 %1362
  %1366 = add i64 %1324, 1
  %1367 = select i1 %1364, i64 %1366, i64 %1324
  %1368 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1369 = load i64, ptr %4, align 8
  %1370 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1371 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1368, 0
  %1372 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1368, 1, 1, 0
  %1373 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1368, 1, 1, 1
  %1374 = mul i64 %1367, %1373
  %1375 = add i64 %1374, %1365
  %1376 = getelementptr inbounds bfloat, ptr %1371, i64 %1375
  %1377 = load bfloat, ptr %1376, align 2, !invariant.load !1
  %1378 = call i64 @llvm.smax.i64(i64 %1369, i64 1)
  br label %1379

1379:                                             ; preds = %1385, %1352
  %1380 = phi i64 [ 1, %1352 ], [ %1388, %1385 ]
  %1381 = phi bfloat [ %1377, %1352 ], [ %1394, %1385 ]
  %1382 = icmp slt i64 %1380, %1378
  br i1 %1382, label %1383, label %1384

1383:                                             ; preds = %1379
  br label %1385

1384:                                             ; preds = %1379
  br label %1395

1385:                                             ; preds = %1383
  %1386 = icmp eq i64 %1380, %1378
  %1387 = add i64 %1380, 1
  %1388 = select i1 %1386, i64 %1380, i64 %1387
  %1389 = mul i64 %1380, %1372
  %1390 = add i64 %1389, %1374
  %1391 = add i64 %1390, %1365
  %1392 = getelementptr inbounds bfloat, ptr %1371, i64 %1391
  %1393 = load bfloat, ptr %1392, align 2, !invariant.load !1
  %1394 = fadd contract bfloat %1381, %1393
  br label %1379

1395:                                             ; preds = %1384
  %1396 = phi bfloat [ %1381, %1384 ]
  %1397 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1370, 0
  %1398 = trunc i64 %1367 to i32
  %1399 = mul i32 %1398, 512
  %1400 = trunc i64 %1365 to i32
  %1401 = add i32 %1399, %1400
  %1402 = sext i32 %1401 to i64
  %1403 = getelementptr inbounds bfloat, ptr %1397, i64 %1402
  store bfloat %1396, ptr %1403, align 2
  %1404 = load { i64, i64 }, ptr %6, align 8
  %1405 = add i64 %1365, 1
  %1406 = extractvalue { i64, i64 } %1404, 1
  %1407 = icmp sge i64 %1405, %1406
  %1408 = select i1 %1407, i64 0, i64 %1405
  %1409 = add i64 %1367, 1
  %1410 = select i1 %1407, i64 %1409, i64 %1367
  %1411 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1412 = load i64, ptr %4, align 8
  %1413 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1414 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1411, 0
  %1415 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1411, 1, 1, 0
  %1416 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1411, 1, 1, 1
  %1417 = mul i64 %1410, %1416
  %1418 = add i64 %1417, %1408
  %1419 = getelementptr inbounds bfloat, ptr %1414, i64 %1418
  %1420 = load bfloat, ptr %1419, align 2, !invariant.load !1
  %1421 = call i64 @llvm.smax.i64(i64 %1412, i64 1)
  br label %1422

1422:                                             ; preds = %1428, %1395
  %1423 = phi i64 [ 1, %1395 ], [ %1431, %1428 ]
  %1424 = phi bfloat [ %1420, %1395 ], [ %1437, %1428 ]
  %1425 = icmp slt i64 %1423, %1421
  br i1 %1425, label %1426, label %1427

1426:                                             ; preds = %1422
  br label %1428

1427:                                             ; preds = %1422
  br label %1438

1428:                                             ; preds = %1426
  %1429 = icmp eq i64 %1423, %1421
  %1430 = add i64 %1423, 1
  %1431 = select i1 %1429, i64 %1423, i64 %1430
  %1432 = mul i64 %1423, %1415
  %1433 = add i64 %1432, %1417
  %1434 = add i64 %1433, %1408
  %1435 = getelementptr inbounds bfloat, ptr %1414, i64 %1434
  %1436 = load bfloat, ptr %1435, align 2, !invariant.load !1
  %1437 = fadd contract bfloat %1424, %1436
  br label %1422

1438:                                             ; preds = %1427
  %1439 = phi bfloat [ %1424, %1427 ]
  %1440 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1413, 0
  %1441 = trunc i64 %1410 to i32
  %1442 = mul i32 %1441, 512
  %1443 = trunc i64 %1408 to i32
  %1444 = add i32 %1442, %1443
  %1445 = sext i32 %1444 to i64
  %1446 = getelementptr inbounds bfloat, ptr %1440, i64 %1445
  store bfloat %1439, ptr %1446, align 2
  %1447 = load { i64, i64 }, ptr %6, align 8
  %1448 = add i64 %1408, 1
  %1449 = extractvalue { i64, i64 } %1447, 1
  %1450 = icmp sge i64 %1448, %1449
  %1451 = select i1 %1450, i64 0, i64 %1448
  %1452 = add i64 %1410, 1
  %1453 = select i1 %1450, i64 %1452, i64 %1410
  %1454 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1455 = load i64, ptr %4, align 8
  %1456 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1457 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1454, 0
  %1458 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1454, 1, 1, 0
  %1459 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1454, 1, 1, 1
  %1460 = mul i64 %1453, %1459
  %1461 = add i64 %1460, %1451
  %1462 = getelementptr inbounds bfloat, ptr %1457, i64 %1461
  %1463 = load bfloat, ptr %1462, align 2, !invariant.load !1
  %1464 = call i64 @llvm.smax.i64(i64 %1455, i64 1)
  br label %1465

1465:                                             ; preds = %1471, %1438
  %1466 = phi i64 [ 1, %1438 ], [ %1474, %1471 ]
  %1467 = phi bfloat [ %1463, %1438 ], [ %1480, %1471 ]
  %1468 = icmp slt i64 %1466, %1464
  br i1 %1468, label %1469, label %1470

1469:                                             ; preds = %1465
  br label %1471

1470:                                             ; preds = %1465
  br label %1481

1471:                                             ; preds = %1469
  %1472 = icmp eq i64 %1466, %1464
  %1473 = add i64 %1466, 1
  %1474 = select i1 %1472, i64 %1466, i64 %1473
  %1475 = mul i64 %1466, %1458
  %1476 = add i64 %1475, %1460
  %1477 = add i64 %1476, %1451
  %1478 = getelementptr inbounds bfloat, ptr %1457, i64 %1477
  %1479 = load bfloat, ptr %1478, align 2, !invariant.load !1
  %1480 = fadd contract bfloat %1467, %1479
  br label %1465

1481:                                             ; preds = %1470
  %1482 = phi bfloat [ %1467, %1470 ]
  %1483 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1456, 0
  %1484 = trunc i64 %1453 to i32
  %1485 = mul i32 %1484, 512
  %1486 = trunc i64 %1451 to i32
  %1487 = add i32 %1485, %1486
  %1488 = sext i32 %1487 to i64
  %1489 = getelementptr inbounds bfloat, ptr %1483, i64 %1488
  store bfloat %1482, ptr %1489, align 2
  %1490 = load { i64, i64 }, ptr %6, align 8
  %1491 = add i64 %1451, 1
  %1492 = extractvalue { i64, i64 } %1490, 1
  %1493 = icmp sge i64 %1491, %1492
  %1494 = select i1 %1493, i64 0, i64 %1491
  %1495 = add i64 %1453, 1
  %1496 = select i1 %1493, i64 %1495, i64 %1453
  %1497 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1498 = load i64, ptr %4, align 8
  %1499 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1500 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1497, 0
  %1501 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1497, 1, 1, 0
  %1502 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1497, 1, 1, 1
  %1503 = mul i64 %1496, %1502
  %1504 = add i64 %1503, %1494
  %1505 = getelementptr inbounds bfloat, ptr %1500, i64 %1504
  %1506 = load bfloat, ptr %1505, align 2, !invariant.load !1
  %1507 = call i64 @llvm.smax.i64(i64 %1498, i64 1)
  br label %1508

1508:                                             ; preds = %1514, %1481
  %1509 = phi i64 [ 1, %1481 ], [ %1517, %1514 ]
  %1510 = phi bfloat [ %1506, %1481 ], [ %1523, %1514 ]
  %1511 = icmp slt i64 %1509, %1507
  br i1 %1511, label %1512, label %1513

1512:                                             ; preds = %1508
  br label %1514

1513:                                             ; preds = %1508
  br label %1524

1514:                                             ; preds = %1512
  %1515 = icmp eq i64 %1509, %1507
  %1516 = add i64 %1509, 1
  %1517 = select i1 %1515, i64 %1509, i64 %1516
  %1518 = mul i64 %1509, %1501
  %1519 = add i64 %1518, %1503
  %1520 = add i64 %1519, %1494
  %1521 = getelementptr inbounds bfloat, ptr %1500, i64 %1520
  %1522 = load bfloat, ptr %1521, align 2, !invariant.load !1
  %1523 = fadd contract bfloat %1510, %1522
  br label %1508

1524:                                             ; preds = %1513
  %1525 = phi bfloat [ %1510, %1513 ]
  %1526 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1499, 0
  %1527 = trunc i64 %1496 to i32
  %1528 = mul i32 %1527, 512
  %1529 = trunc i64 %1494 to i32
  %1530 = add i32 %1528, %1529
  %1531 = sext i32 %1530 to i64
  %1532 = getelementptr inbounds bfloat, ptr %1526, i64 %1531
  store bfloat %1525, ptr %1532, align 2
  %1533 = load { i64, i64 }, ptr %6, align 8
  %1534 = add i64 %1494, 1
  %1535 = extractvalue { i64, i64 } %1533, 1
  %1536 = icmp sge i64 %1534, %1535
  %1537 = select i1 %1536, i64 0, i64 %1534
  %1538 = add i64 %1496, 1
  %1539 = select i1 %1536, i64 %1538, i64 %1496
  %1540 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1541 = load i64, ptr %4, align 8
  %1542 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1543 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1540, 0
  %1544 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1540, 1, 1, 0
  %1545 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1540, 1, 1, 1
  %1546 = mul i64 %1539, %1545
  %1547 = add i64 %1546, %1537
  %1548 = getelementptr inbounds bfloat, ptr %1543, i64 %1547
  %1549 = load bfloat, ptr %1548, align 2, !invariant.load !1
  %1550 = call i64 @llvm.smax.i64(i64 %1541, i64 1)
  br label %1551

1551:                                             ; preds = %1557, %1524
  %1552 = phi i64 [ 1, %1524 ], [ %1560, %1557 ]
  %1553 = phi bfloat [ %1549, %1524 ], [ %1566, %1557 ]
  %1554 = icmp slt i64 %1552, %1550
  br i1 %1554, label %1555, label %1556

1555:                                             ; preds = %1551
  br label %1557

1556:                                             ; preds = %1551
  br label %1567

1557:                                             ; preds = %1555
  %1558 = icmp eq i64 %1552, %1550
  %1559 = add i64 %1552, 1
  %1560 = select i1 %1558, i64 %1552, i64 %1559
  %1561 = mul i64 %1552, %1544
  %1562 = add i64 %1561, %1546
  %1563 = add i64 %1562, %1537
  %1564 = getelementptr inbounds bfloat, ptr %1543, i64 %1563
  %1565 = load bfloat, ptr %1564, align 2, !invariant.load !1
  %1566 = fadd contract bfloat %1553, %1565
  br label %1551

1567:                                             ; preds = %1556
  %1568 = phi bfloat [ %1553, %1556 ]
  %1569 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1542, 0
  %1570 = trunc i64 %1539 to i32
  %1571 = mul i32 %1570, 512
  %1572 = trunc i64 %1537 to i32
  %1573 = add i32 %1571, %1572
  %1574 = sext i32 %1573 to i64
  %1575 = getelementptr inbounds bfloat, ptr %1569, i64 %1574
  store bfloat %1568, ptr %1575, align 2
  %1576 = load { i64, i64 }, ptr %6, align 8
  %1577 = add i64 %1537, 1
  %1578 = extractvalue { i64, i64 } %1576, 1
  %1579 = icmp sge i64 %1577, %1578
  %1580 = select i1 %1579, i64 0, i64 %1577
  %1581 = add i64 %1539, 1
  %1582 = select i1 %1579, i64 %1581, i64 %1539
  %1583 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1584 = load i64, ptr %4, align 8
  %1585 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1586 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1583, 0
  %1587 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1583, 1, 1, 0
  %1588 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1583, 1, 1, 1
  %1589 = mul i64 %1582, %1588
  %1590 = add i64 %1589, %1580
  %1591 = getelementptr inbounds bfloat, ptr %1586, i64 %1590
  %1592 = load bfloat, ptr %1591, align 2, !invariant.load !1
  %1593 = call i64 @llvm.smax.i64(i64 %1584, i64 1)
  br label %1594

1594:                                             ; preds = %1600, %1567
  %1595 = phi i64 [ 1, %1567 ], [ %1603, %1600 ]
  %1596 = phi bfloat [ %1592, %1567 ], [ %1609, %1600 ]
  %1597 = icmp slt i64 %1595, %1593
  br i1 %1597, label %1598, label %1599

1598:                                             ; preds = %1594
  br label %1600

1599:                                             ; preds = %1594
  br label %1610

1600:                                             ; preds = %1598
  %1601 = icmp eq i64 %1595, %1593
  %1602 = add i64 %1595, 1
  %1603 = select i1 %1601, i64 %1595, i64 %1602
  %1604 = mul i64 %1595, %1587
  %1605 = add i64 %1604, %1589
  %1606 = add i64 %1605, %1580
  %1607 = getelementptr inbounds bfloat, ptr %1586, i64 %1606
  %1608 = load bfloat, ptr %1607, align 2, !invariant.load !1
  %1609 = fadd contract bfloat %1596, %1608
  br label %1594

1610:                                             ; preds = %1599
  %1611 = phi bfloat [ %1596, %1599 ]
  %1612 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1585, 0
  %1613 = trunc i64 %1582 to i32
  %1614 = mul i32 %1613, 512
  %1615 = trunc i64 %1580 to i32
  %1616 = add i32 %1614, %1615
  %1617 = sext i32 %1616 to i64
  %1618 = getelementptr inbounds bfloat, ptr %1612, i64 %1617
  store bfloat %1611, ptr %1618, align 2
  br label %1651

1619:                                             ; preds = %1260
  %1620 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1621 = load i64, ptr %4, align 8
  %1622 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1623 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1620, 0
  %1624 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1620, 1, 1, 0
  %1625 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1620, 1, 1, 1
  %1626 = mul i64 %1274, %1625
  %1627 = add i64 %1626, %1280
  %1628 = getelementptr inbounds bfloat, ptr %1623, i64 %1627
  %1629 = load <8 x bfloat>, ptr %1628, align 16, !invariant.load !1
  %1630 = call i64 @llvm.smax.i64(i64 %1621, i64 1)
  br label %1631

1631:                                             ; preds = %1637, %1619
  %1632 = phi i64 [ 1, %1619 ], [ %1640, %1637 ]
  %1633 = phi <8 x bfloat> [ %1629, %1619 ], [ %1646, %1637 ]
  %1634 = icmp slt i64 %1632, %1630
  br i1 %1634, label %1635, label %1636

1635:                                             ; preds = %1631
  br label %1637

1636:                                             ; preds = %1631
  br label %1647

1637:                                             ; preds = %1635
  %1638 = icmp eq i64 %1632, %1630
  %1639 = add i64 %1632, 1
  %1640 = select i1 %1638, i64 %1632, i64 %1639
  %1641 = mul i64 %1632, %1624
  %1642 = add i64 %1641, %1626
  %1643 = add i64 %1642, %1280
  %1644 = getelementptr inbounds bfloat, ptr %1623, i64 %1643
  %1645 = load <8 x bfloat>, ptr %1644, align 16, !invariant.load !1
  %1646 = fadd contract <8 x bfloat> %1633, %1645
  br label %1631

1647:                                             ; preds = %1636
  %1648 = phi <8 x bfloat> [ %1633, %1636 ]
  %1649 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1622, 0
  %1650 = getelementptr inbounds bfloat, ptr %1649, i64 %1283
  store <8 x bfloat> %1648, ptr %1650, align 16
  br label %1651

1651:                                             ; preds = %1647, %1610
  br label %1653

1652:                                             ; preds = %1254
  br label %1653

1653:                                             ; preds = %1652, %1651
  br label %29

1654:                                             ; preds = %58
  %1655 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %1656 = load i64, ptr %1655, align 8
  %1657 = icmp slt i64 %14, %1656
  br i1 %1657, label %1658, label %1715

1658:                                             ; preds = %1654
  %1659 = load i64, ptr %7, align 8
  %1660 = add i64 %1659, %14
  %1661 = load { i64, i64 }, ptr %6, align 8
  %1662 = extractvalue { i64, i64 } %1661, 1
  %1663 = icmp eq i64 %1662, 0
  %1664 = select i1 %1663, i64 1, i64 %1662
  %1665 = sdiv i64 %1660, %1664
  %1666 = mul i64 %1665, %1662
  %1667 = sub i64 %1660, %1666
  %1668 = icmp slt i64 %1662, 0
  %1669 = icmp slt i64 %1660, 0
  %1670 = xor i1 %1668, %1669
  %1671 = icmp ne i64 %1667, 0
  %1672 = and i1 %1670, %1671
  %1673 = select i1 %1672, i64 1, i64 0
  %1674 = sub i64 %1665, %1673
  %1675 = select i1 %1663, i64 0, i64 %1674
  %1676 = select i1 %1672, i64 %1662, i64 0
  %1677 = add i64 %1667, %1676
  %1678 = select i1 %1663, i64 0, i64 %1677
  %1679 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1680 = load i64, ptr %4, align 8
  %1681 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1682 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1679, 0
  %1683 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1679, 1, 1, 0
  %1684 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1679, 1, 1, 1
  %1685 = mul i64 %1675, %1684
  %1686 = add i64 %1685, %1678
  %1687 = getelementptr inbounds bfloat, ptr %1682, i64 %1686
  %1688 = load bfloat, ptr %1687, align 2, !invariant.load !1
  %1689 = call i64 @llvm.smax.i64(i64 %1680, i64 1)
  br label %1690

1690:                                             ; preds = %1696, %1658
  %1691 = phi i64 [ 1, %1658 ], [ %1699, %1696 ]
  %1692 = phi bfloat [ %1688, %1658 ], [ %1705, %1696 ]
  %1693 = icmp slt i64 %1691, %1689
  br i1 %1693, label %1694, label %1695

1694:                                             ; preds = %1690
  br label %1696

1695:                                             ; preds = %1690
  br label %1706

1696:                                             ; preds = %1694
  %1697 = icmp eq i64 %1691, %1689
  %1698 = add i64 %1691, 1
  %1699 = select i1 %1697, i64 %1691, i64 %1698
  %1700 = mul i64 %1691, %1683
  %1701 = add i64 %1700, %1685
  %1702 = add i64 %1701, %1678
  %1703 = getelementptr inbounds bfloat, ptr %1682, i64 %1702
  %1704 = load bfloat, ptr %1703, align 2, !invariant.load !1
  %1705 = fadd contract bfloat %1692, %1704
  br label %1690

1706:                                             ; preds = %1695
  %1707 = phi bfloat [ %1692, %1695 ]
  %1708 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1681, 0
  %1709 = trunc i64 %1675 to i32
  %1710 = mul i32 %1709, 512
  %1711 = trunc i64 %1678 to i32
  %1712 = add i32 %1710, %1711
  %1713 = sext i32 %1712 to i64
  %1714 = getelementptr inbounds bfloat, ptr %1708, i64 %1713
  store bfloat %1707, ptr %1714, align 2
  br label %1716

1715:                                             ; preds = %1654
  br label %1716

1716:                                             ; preds = %1715, %1706
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
