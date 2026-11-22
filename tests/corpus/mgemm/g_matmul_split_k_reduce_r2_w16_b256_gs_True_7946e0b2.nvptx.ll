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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w16_b256_gs_True_7946e0b2(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

29:                                               ; preds = %5741, %1
  %30 = phi i64 [ %24, %1 ], [ %54, %5741 ]
  %31 = phi i64 [ 0, %1 ], [ %55, %5741 ]
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
  %56 = mul i64 %53, 16
  %57 = icmp slt i64 %56, 0
  br i1 %52, label %58, label %59

58:                                               ; preds = %51
  br label %5742

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59
  %61 = load i64, ptr %20, align 8
  %62 = icmp slt i64 %53, %61
  br i1 %62, label %63, label %1477

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
  %88 = add i64 %83, 16
  %89 = load i64, ptr %8, align 8
  %90 = icmp sgt i64 %88, %89
  br i1 %90, label %91, label %1358

91:                                               ; preds = %63
  %92 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %93 = load i64, ptr %4, align 8
  %94 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %95 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 0
  %96 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 1, 1, 0
  %97 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %92, 1, 1, 1
  %98 = mul i64 %77, %97
  %99 = add i64 %98, %83
  %100 = getelementptr inbounds i8, ptr %95, i64 %99
  br label %101

101:                                              ; preds = %107, %91
  %102 = phi i64 [ 0, %91 ], [ %110, %107 ]
  %103 = phi i8 [ 0, %91 ], [ %112, %107 ]
  %104 = icmp slt i64 %102, 1
  br i1 %104, label %105, label %106

105:                                              ; preds = %101
  br label %107

106:                                              ; preds = %101
  br label %113

107:                                              ; preds = %105
  %108 = icmp eq i64 %102, 1
  %109 = add i64 %102, 1
  %110 = select i1 %108, i64 %102, i64 %109
  %111 = getelementptr inbounds i8, ptr %100, i64 %102
  %112 = load i8, ptr %111, align 1, !invariant.load !1
  br label %101

113:                                              ; preds = %106
  %114 = phi i8 [ %103, %106 ]
  %115 = call i64 @llvm.smax.i64(i64 %93, i64 1)
  br label %116

116:                                              ; preds = %142, %113
  %117 = phi i64 [ 1, %113 ], [ %125, %142 ]
  %118 = phi i8 [ %114, %113 ], [ %155, %142 ]
  %119 = icmp slt i64 %117, %115
  br i1 %119, label %120, label %121

120:                                              ; preds = %116
  br label %122

121:                                              ; preds = %116
  br label %156

122:                                              ; preds = %120
  %123 = icmp eq i64 %117, %115
  %124 = add i64 %117, 1
  %125 = select i1 %123, i64 %117, i64 %124
  %126 = mul i64 %117, %96
  %127 = add i64 %126, %98
  %128 = add i64 %127, %83
  %129 = getelementptr inbounds i8, ptr %95, i64 %128
  br label %130

130:                                              ; preds = %136, %122
  %131 = phi i64 [ 0, %122 ], [ %139, %136 ]
  %132 = phi i8 [ 0, %122 ], [ %141, %136 ]
  %133 = icmp slt i64 %131, 1
  br i1 %133, label %134, label %135

134:                                              ; preds = %130
  br label %136

135:                                              ; preds = %130
  br label %142

136:                                              ; preds = %134
  %137 = icmp eq i64 %131, 1
  %138 = add i64 %131, 1
  %139 = select i1 %137, i64 %131, i64 %138
  %140 = getelementptr inbounds i8, ptr %129, i64 %131
  %141 = load i8, ptr %140, align 1, !invariant.load !1
  br label %130

142:                                              ; preds = %135
  %143 = phi i8 [ %132, %135 ]
  %144 = zext i8 %118 to i16
  %145 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %144)
  %146 = trunc i32 %145 to i16
  %147 = bitcast i16 %146 to half
  %148 = zext i8 %143 to i16
  %149 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %148)
  %150 = trunc i32 %149 to i16
  %151 = bitcast i16 %150 to half
  %152 = fadd contract half %147, %151
  %153 = fpext half %152 to float
  %154 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %153)
  %155 = trunc i16 %154 to i8
  br label %116

156:                                              ; preds = %121
  %157 = phi i8 [ %118, %121 ]
  %158 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %94, 0
  %159 = getelementptr inbounds i8, ptr %158, i64 %86
  store i8 %157, ptr %159, align 1
  %160 = load { i64, i64 }, ptr %6, align 8
  %161 = extractvalue { i64, i64 } %160, 1
  %162 = icmp sge i64 %87, %161
  %163 = select i1 %162, i64 0, i64 %87
  %164 = select i1 %162, i64 %80, i64 %77
  %165 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %166 = load i64, ptr %4, align 8
  %167 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %168 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %165, 0
  %169 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %165, 1, 1, 0
  %170 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %165, 1, 1, 1
  %171 = mul i64 %164, %170
  %172 = add i64 %171, %163
  %173 = getelementptr inbounds i8, ptr %168, i64 %172
  br label %174

174:                                              ; preds = %180, %156
  %175 = phi i64 [ 0, %156 ], [ %183, %180 ]
  %176 = phi i8 [ 0, %156 ], [ %185, %180 ]
  %177 = icmp slt i64 %175, 1
  br i1 %177, label %178, label %179

178:                                              ; preds = %174
  br label %180

179:                                              ; preds = %174
  br label %186

180:                                              ; preds = %178
  %181 = icmp eq i64 %175, 1
  %182 = add i64 %175, 1
  %183 = select i1 %181, i64 %175, i64 %182
  %184 = getelementptr inbounds i8, ptr %173, i64 %175
  %185 = load i8, ptr %184, align 1, !invariant.load !1
  br label %174

186:                                              ; preds = %179
  %187 = phi i8 [ %176, %179 ]
  %188 = call i64 @llvm.smax.i64(i64 %166, i64 1)
  br label %189

189:                                              ; preds = %215, %186
  %190 = phi i64 [ 1, %186 ], [ %198, %215 ]
  %191 = phi i8 [ %187, %186 ], [ %228, %215 ]
  %192 = icmp slt i64 %190, %188
  br i1 %192, label %193, label %194

193:                                              ; preds = %189
  br label %195

194:                                              ; preds = %189
  br label %229

195:                                              ; preds = %193
  %196 = icmp eq i64 %190, %188
  %197 = add i64 %190, 1
  %198 = select i1 %196, i64 %190, i64 %197
  %199 = mul i64 %190, %169
  %200 = add i64 %199, %171
  %201 = add i64 %200, %163
  %202 = getelementptr inbounds i8, ptr %168, i64 %201
  br label %203

203:                                              ; preds = %209, %195
  %204 = phi i64 [ 0, %195 ], [ %212, %209 ]
  %205 = phi i8 [ 0, %195 ], [ %214, %209 ]
  %206 = icmp slt i64 %204, 1
  br i1 %206, label %207, label %208

207:                                              ; preds = %203
  br label %209

208:                                              ; preds = %203
  br label %215

209:                                              ; preds = %207
  %210 = icmp eq i64 %204, 1
  %211 = add i64 %204, 1
  %212 = select i1 %210, i64 %204, i64 %211
  %213 = getelementptr inbounds i8, ptr %202, i64 %204
  %214 = load i8, ptr %213, align 1, !invariant.load !1
  br label %203

215:                                              ; preds = %208
  %216 = phi i8 [ %205, %208 ]
  %217 = zext i8 %191 to i16
  %218 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %217)
  %219 = trunc i32 %218 to i16
  %220 = bitcast i16 %219 to half
  %221 = zext i8 %216 to i16
  %222 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %221)
  %223 = trunc i32 %222 to i16
  %224 = bitcast i16 %223 to half
  %225 = fadd contract half %220, %224
  %226 = fpext half %225 to float
  %227 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %226)
  %228 = trunc i16 %227 to i8
  br label %189

229:                                              ; preds = %194
  %230 = phi i8 [ %191, %194 ]
  %231 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %167, 0
  %232 = trunc i64 %164 to i32
  %233 = mul i32 %232, 512
  %234 = trunc i64 %163 to i32
  %235 = add i32 %233, %234
  %236 = sext i32 %235 to i64
  %237 = getelementptr inbounds i8, ptr %231, i64 %236
  store i8 %230, ptr %237, align 1
  %238 = load { i64, i64 }, ptr %6, align 8
  %239 = add i64 %163, 1
  %240 = extractvalue { i64, i64 } %238, 1
  %241 = icmp sge i64 %239, %240
  %242 = select i1 %241, i64 0, i64 %239
  %243 = add i64 %164, 1
  %244 = select i1 %241, i64 %243, i64 %164
  %245 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %246 = load i64, ptr %4, align 8
  %247 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %248 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %245, 0
  %249 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %245, 1, 1, 0
  %250 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %245, 1, 1, 1
  %251 = mul i64 %244, %250
  %252 = add i64 %251, %242
  %253 = getelementptr inbounds i8, ptr %248, i64 %252
  br label %254

254:                                              ; preds = %260, %229
  %255 = phi i64 [ 0, %229 ], [ %263, %260 ]
  %256 = phi i8 [ 0, %229 ], [ %265, %260 ]
  %257 = icmp slt i64 %255, 1
  br i1 %257, label %258, label %259

258:                                              ; preds = %254
  br label %260

259:                                              ; preds = %254
  br label %266

260:                                              ; preds = %258
  %261 = icmp eq i64 %255, 1
  %262 = add i64 %255, 1
  %263 = select i1 %261, i64 %255, i64 %262
  %264 = getelementptr inbounds i8, ptr %253, i64 %255
  %265 = load i8, ptr %264, align 1, !invariant.load !1
  br label %254

266:                                              ; preds = %259
  %267 = phi i8 [ %256, %259 ]
  %268 = call i64 @llvm.smax.i64(i64 %246, i64 1)
  br label %269

269:                                              ; preds = %295, %266
  %270 = phi i64 [ 1, %266 ], [ %278, %295 ]
  %271 = phi i8 [ %267, %266 ], [ %308, %295 ]
  %272 = icmp slt i64 %270, %268
  br i1 %272, label %273, label %274

273:                                              ; preds = %269
  br label %275

274:                                              ; preds = %269
  br label %309

275:                                              ; preds = %273
  %276 = icmp eq i64 %270, %268
  %277 = add i64 %270, 1
  %278 = select i1 %276, i64 %270, i64 %277
  %279 = mul i64 %270, %249
  %280 = add i64 %279, %251
  %281 = add i64 %280, %242
  %282 = getelementptr inbounds i8, ptr %248, i64 %281
  br label %283

283:                                              ; preds = %289, %275
  %284 = phi i64 [ 0, %275 ], [ %292, %289 ]
  %285 = phi i8 [ 0, %275 ], [ %294, %289 ]
  %286 = icmp slt i64 %284, 1
  br i1 %286, label %287, label %288

287:                                              ; preds = %283
  br label %289

288:                                              ; preds = %283
  br label %295

289:                                              ; preds = %287
  %290 = icmp eq i64 %284, 1
  %291 = add i64 %284, 1
  %292 = select i1 %290, i64 %284, i64 %291
  %293 = getelementptr inbounds i8, ptr %282, i64 %284
  %294 = load i8, ptr %293, align 1, !invariant.load !1
  br label %283

295:                                              ; preds = %288
  %296 = phi i8 [ %285, %288 ]
  %297 = zext i8 %271 to i16
  %298 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %297)
  %299 = trunc i32 %298 to i16
  %300 = bitcast i16 %299 to half
  %301 = zext i8 %296 to i16
  %302 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %301)
  %303 = trunc i32 %302 to i16
  %304 = bitcast i16 %303 to half
  %305 = fadd contract half %300, %304
  %306 = fpext half %305 to float
  %307 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %306)
  %308 = trunc i16 %307 to i8
  br label %269

309:                                              ; preds = %274
  %310 = phi i8 [ %271, %274 ]
  %311 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %247, 0
  %312 = trunc i64 %244 to i32
  %313 = mul i32 %312, 512
  %314 = trunc i64 %242 to i32
  %315 = add i32 %313, %314
  %316 = sext i32 %315 to i64
  %317 = getelementptr inbounds i8, ptr %311, i64 %316
  store i8 %310, ptr %317, align 1
  %318 = load { i64, i64 }, ptr %6, align 8
  %319 = add i64 %242, 1
  %320 = extractvalue { i64, i64 } %318, 1
  %321 = icmp sge i64 %319, %320
  %322 = select i1 %321, i64 0, i64 %319
  %323 = add i64 %244, 1
  %324 = select i1 %321, i64 %323, i64 %244
  %325 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %326 = load i64, ptr %4, align 8
  %327 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %328 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %325, 0
  %329 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %325, 1, 1, 0
  %330 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %325, 1, 1, 1
  %331 = mul i64 %324, %330
  %332 = add i64 %331, %322
  %333 = getelementptr inbounds i8, ptr %328, i64 %332
  br label %334

334:                                              ; preds = %340, %309
  %335 = phi i64 [ 0, %309 ], [ %343, %340 ]
  %336 = phi i8 [ 0, %309 ], [ %345, %340 ]
  %337 = icmp slt i64 %335, 1
  br i1 %337, label %338, label %339

338:                                              ; preds = %334
  br label %340

339:                                              ; preds = %334
  br label %346

340:                                              ; preds = %338
  %341 = icmp eq i64 %335, 1
  %342 = add i64 %335, 1
  %343 = select i1 %341, i64 %335, i64 %342
  %344 = getelementptr inbounds i8, ptr %333, i64 %335
  %345 = load i8, ptr %344, align 1, !invariant.load !1
  br label %334

346:                                              ; preds = %339
  %347 = phi i8 [ %336, %339 ]
  %348 = call i64 @llvm.smax.i64(i64 %326, i64 1)
  br label %349

349:                                              ; preds = %375, %346
  %350 = phi i64 [ 1, %346 ], [ %358, %375 ]
  %351 = phi i8 [ %347, %346 ], [ %388, %375 ]
  %352 = icmp slt i64 %350, %348
  br i1 %352, label %353, label %354

353:                                              ; preds = %349
  br label %355

354:                                              ; preds = %349
  br label %389

355:                                              ; preds = %353
  %356 = icmp eq i64 %350, %348
  %357 = add i64 %350, 1
  %358 = select i1 %356, i64 %350, i64 %357
  %359 = mul i64 %350, %329
  %360 = add i64 %359, %331
  %361 = add i64 %360, %322
  %362 = getelementptr inbounds i8, ptr %328, i64 %361
  br label %363

363:                                              ; preds = %369, %355
  %364 = phi i64 [ 0, %355 ], [ %372, %369 ]
  %365 = phi i8 [ 0, %355 ], [ %374, %369 ]
  %366 = icmp slt i64 %364, 1
  br i1 %366, label %367, label %368

367:                                              ; preds = %363
  br label %369

368:                                              ; preds = %363
  br label %375

369:                                              ; preds = %367
  %370 = icmp eq i64 %364, 1
  %371 = add i64 %364, 1
  %372 = select i1 %370, i64 %364, i64 %371
  %373 = getelementptr inbounds i8, ptr %362, i64 %364
  %374 = load i8, ptr %373, align 1, !invariant.load !1
  br label %363

375:                                              ; preds = %368
  %376 = phi i8 [ %365, %368 ]
  %377 = zext i8 %351 to i16
  %378 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %377)
  %379 = trunc i32 %378 to i16
  %380 = bitcast i16 %379 to half
  %381 = zext i8 %376 to i16
  %382 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %381)
  %383 = trunc i32 %382 to i16
  %384 = bitcast i16 %383 to half
  %385 = fadd contract half %380, %384
  %386 = fpext half %385 to float
  %387 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %386)
  %388 = trunc i16 %387 to i8
  br label %349

389:                                              ; preds = %354
  %390 = phi i8 [ %351, %354 ]
  %391 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %327, 0
  %392 = trunc i64 %324 to i32
  %393 = mul i32 %392, 512
  %394 = trunc i64 %322 to i32
  %395 = add i32 %393, %394
  %396 = sext i32 %395 to i64
  %397 = getelementptr inbounds i8, ptr %391, i64 %396
  store i8 %390, ptr %397, align 1
  %398 = load { i64, i64 }, ptr %6, align 8
  %399 = add i64 %322, 1
  %400 = extractvalue { i64, i64 } %398, 1
  %401 = icmp sge i64 %399, %400
  %402 = select i1 %401, i64 0, i64 %399
  %403 = add i64 %324, 1
  %404 = select i1 %401, i64 %403, i64 %324
  %405 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %406 = load i64, ptr %4, align 8
  %407 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %408 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %405, 0
  %409 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %405, 1, 1, 0
  %410 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %405, 1, 1, 1
  %411 = mul i64 %404, %410
  %412 = add i64 %411, %402
  %413 = getelementptr inbounds i8, ptr %408, i64 %412
  br label %414

414:                                              ; preds = %420, %389
  %415 = phi i64 [ 0, %389 ], [ %423, %420 ]
  %416 = phi i8 [ 0, %389 ], [ %425, %420 ]
  %417 = icmp slt i64 %415, 1
  br i1 %417, label %418, label %419

418:                                              ; preds = %414
  br label %420

419:                                              ; preds = %414
  br label %426

420:                                              ; preds = %418
  %421 = icmp eq i64 %415, 1
  %422 = add i64 %415, 1
  %423 = select i1 %421, i64 %415, i64 %422
  %424 = getelementptr inbounds i8, ptr %413, i64 %415
  %425 = load i8, ptr %424, align 1, !invariant.load !1
  br label %414

426:                                              ; preds = %419
  %427 = phi i8 [ %416, %419 ]
  %428 = call i64 @llvm.smax.i64(i64 %406, i64 1)
  br label %429

429:                                              ; preds = %455, %426
  %430 = phi i64 [ 1, %426 ], [ %438, %455 ]
  %431 = phi i8 [ %427, %426 ], [ %468, %455 ]
  %432 = icmp slt i64 %430, %428
  br i1 %432, label %433, label %434

433:                                              ; preds = %429
  br label %435

434:                                              ; preds = %429
  br label %469

435:                                              ; preds = %433
  %436 = icmp eq i64 %430, %428
  %437 = add i64 %430, 1
  %438 = select i1 %436, i64 %430, i64 %437
  %439 = mul i64 %430, %409
  %440 = add i64 %439, %411
  %441 = add i64 %440, %402
  %442 = getelementptr inbounds i8, ptr %408, i64 %441
  br label %443

443:                                              ; preds = %449, %435
  %444 = phi i64 [ 0, %435 ], [ %452, %449 ]
  %445 = phi i8 [ 0, %435 ], [ %454, %449 ]
  %446 = icmp slt i64 %444, 1
  br i1 %446, label %447, label %448

447:                                              ; preds = %443
  br label %449

448:                                              ; preds = %443
  br label %455

449:                                              ; preds = %447
  %450 = icmp eq i64 %444, 1
  %451 = add i64 %444, 1
  %452 = select i1 %450, i64 %444, i64 %451
  %453 = getelementptr inbounds i8, ptr %442, i64 %444
  %454 = load i8, ptr %453, align 1, !invariant.load !1
  br label %443

455:                                              ; preds = %448
  %456 = phi i8 [ %445, %448 ]
  %457 = zext i8 %431 to i16
  %458 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %457)
  %459 = trunc i32 %458 to i16
  %460 = bitcast i16 %459 to half
  %461 = zext i8 %456 to i16
  %462 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %461)
  %463 = trunc i32 %462 to i16
  %464 = bitcast i16 %463 to half
  %465 = fadd contract half %460, %464
  %466 = fpext half %465 to float
  %467 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %466)
  %468 = trunc i16 %467 to i8
  br label %429

469:                                              ; preds = %434
  %470 = phi i8 [ %431, %434 ]
  %471 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %407, 0
  %472 = trunc i64 %404 to i32
  %473 = mul i32 %472, 512
  %474 = trunc i64 %402 to i32
  %475 = add i32 %473, %474
  %476 = sext i32 %475 to i64
  %477 = getelementptr inbounds i8, ptr %471, i64 %476
  store i8 %470, ptr %477, align 1
  %478 = load { i64, i64 }, ptr %6, align 8
  %479 = add i64 %402, 1
  %480 = extractvalue { i64, i64 } %478, 1
  %481 = icmp sge i64 %479, %480
  %482 = select i1 %481, i64 0, i64 %479
  %483 = add i64 %404, 1
  %484 = select i1 %481, i64 %483, i64 %404
  %485 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %486 = load i64, ptr %4, align 8
  %487 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %488 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %485, 0
  %489 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %485, 1, 1, 0
  %490 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %485, 1, 1, 1
  %491 = mul i64 %484, %490
  %492 = add i64 %491, %482
  %493 = getelementptr inbounds i8, ptr %488, i64 %492
  br label %494

494:                                              ; preds = %500, %469
  %495 = phi i64 [ 0, %469 ], [ %503, %500 ]
  %496 = phi i8 [ 0, %469 ], [ %505, %500 ]
  %497 = icmp slt i64 %495, 1
  br i1 %497, label %498, label %499

498:                                              ; preds = %494
  br label %500

499:                                              ; preds = %494
  br label %506

500:                                              ; preds = %498
  %501 = icmp eq i64 %495, 1
  %502 = add i64 %495, 1
  %503 = select i1 %501, i64 %495, i64 %502
  %504 = getelementptr inbounds i8, ptr %493, i64 %495
  %505 = load i8, ptr %504, align 1, !invariant.load !1
  br label %494

506:                                              ; preds = %499
  %507 = phi i8 [ %496, %499 ]
  %508 = call i64 @llvm.smax.i64(i64 %486, i64 1)
  br label %509

509:                                              ; preds = %535, %506
  %510 = phi i64 [ 1, %506 ], [ %518, %535 ]
  %511 = phi i8 [ %507, %506 ], [ %548, %535 ]
  %512 = icmp slt i64 %510, %508
  br i1 %512, label %513, label %514

513:                                              ; preds = %509
  br label %515

514:                                              ; preds = %509
  br label %549

515:                                              ; preds = %513
  %516 = icmp eq i64 %510, %508
  %517 = add i64 %510, 1
  %518 = select i1 %516, i64 %510, i64 %517
  %519 = mul i64 %510, %489
  %520 = add i64 %519, %491
  %521 = add i64 %520, %482
  %522 = getelementptr inbounds i8, ptr %488, i64 %521
  br label %523

523:                                              ; preds = %529, %515
  %524 = phi i64 [ 0, %515 ], [ %532, %529 ]
  %525 = phi i8 [ 0, %515 ], [ %534, %529 ]
  %526 = icmp slt i64 %524, 1
  br i1 %526, label %527, label %528

527:                                              ; preds = %523
  br label %529

528:                                              ; preds = %523
  br label %535

529:                                              ; preds = %527
  %530 = icmp eq i64 %524, 1
  %531 = add i64 %524, 1
  %532 = select i1 %530, i64 %524, i64 %531
  %533 = getelementptr inbounds i8, ptr %522, i64 %524
  %534 = load i8, ptr %533, align 1, !invariant.load !1
  br label %523

535:                                              ; preds = %528
  %536 = phi i8 [ %525, %528 ]
  %537 = zext i8 %511 to i16
  %538 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %537)
  %539 = trunc i32 %538 to i16
  %540 = bitcast i16 %539 to half
  %541 = zext i8 %536 to i16
  %542 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %541)
  %543 = trunc i32 %542 to i16
  %544 = bitcast i16 %543 to half
  %545 = fadd contract half %540, %544
  %546 = fpext half %545 to float
  %547 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %546)
  %548 = trunc i16 %547 to i8
  br label %509

549:                                              ; preds = %514
  %550 = phi i8 [ %511, %514 ]
  %551 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %487, 0
  %552 = trunc i64 %484 to i32
  %553 = mul i32 %552, 512
  %554 = trunc i64 %482 to i32
  %555 = add i32 %553, %554
  %556 = sext i32 %555 to i64
  %557 = getelementptr inbounds i8, ptr %551, i64 %556
  store i8 %550, ptr %557, align 1
  %558 = load { i64, i64 }, ptr %6, align 8
  %559 = add i64 %482, 1
  %560 = extractvalue { i64, i64 } %558, 1
  %561 = icmp sge i64 %559, %560
  %562 = select i1 %561, i64 0, i64 %559
  %563 = add i64 %484, 1
  %564 = select i1 %561, i64 %563, i64 %484
  %565 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %566 = load i64, ptr %4, align 8
  %567 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %568 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %565, 0
  %569 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %565, 1, 1, 0
  %570 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %565, 1, 1, 1
  %571 = mul i64 %564, %570
  %572 = add i64 %571, %562
  %573 = getelementptr inbounds i8, ptr %568, i64 %572
  br label %574

574:                                              ; preds = %580, %549
  %575 = phi i64 [ 0, %549 ], [ %583, %580 ]
  %576 = phi i8 [ 0, %549 ], [ %585, %580 ]
  %577 = icmp slt i64 %575, 1
  br i1 %577, label %578, label %579

578:                                              ; preds = %574
  br label %580

579:                                              ; preds = %574
  br label %586

580:                                              ; preds = %578
  %581 = icmp eq i64 %575, 1
  %582 = add i64 %575, 1
  %583 = select i1 %581, i64 %575, i64 %582
  %584 = getelementptr inbounds i8, ptr %573, i64 %575
  %585 = load i8, ptr %584, align 1, !invariant.load !1
  br label %574

586:                                              ; preds = %579
  %587 = phi i8 [ %576, %579 ]
  %588 = call i64 @llvm.smax.i64(i64 %566, i64 1)
  br label %589

589:                                              ; preds = %615, %586
  %590 = phi i64 [ 1, %586 ], [ %598, %615 ]
  %591 = phi i8 [ %587, %586 ], [ %628, %615 ]
  %592 = icmp slt i64 %590, %588
  br i1 %592, label %593, label %594

593:                                              ; preds = %589
  br label %595

594:                                              ; preds = %589
  br label %629

595:                                              ; preds = %593
  %596 = icmp eq i64 %590, %588
  %597 = add i64 %590, 1
  %598 = select i1 %596, i64 %590, i64 %597
  %599 = mul i64 %590, %569
  %600 = add i64 %599, %571
  %601 = add i64 %600, %562
  %602 = getelementptr inbounds i8, ptr %568, i64 %601
  br label %603

603:                                              ; preds = %609, %595
  %604 = phi i64 [ 0, %595 ], [ %612, %609 ]
  %605 = phi i8 [ 0, %595 ], [ %614, %609 ]
  %606 = icmp slt i64 %604, 1
  br i1 %606, label %607, label %608

607:                                              ; preds = %603
  br label %609

608:                                              ; preds = %603
  br label %615

609:                                              ; preds = %607
  %610 = icmp eq i64 %604, 1
  %611 = add i64 %604, 1
  %612 = select i1 %610, i64 %604, i64 %611
  %613 = getelementptr inbounds i8, ptr %602, i64 %604
  %614 = load i8, ptr %613, align 1, !invariant.load !1
  br label %603

615:                                              ; preds = %608
  %616 = phi i8 [ %605, %608 ]
  %617 = zext i8 %591 to i16
  %618 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %617)
  %619 = trunc i32 %618 to i16
  %620 = bitcast i16 %619 to half
  %621 = zext i8 %616 to i16
  %622 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %621)
  %623 = trunc i32 %622 to i16
  %624 = bitcast i16 %623 to half
  %625 = fadd contract half %620, %624
  %626 = fpext half %625 to float
  %627 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %626)
  %628 = trunc i16 %627 to i8
  br label %589

629:                                              ; preds = %594
  %630 = phi i8 [ %591, %594 ]
  %631 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %567, 0
  %632 = trunc i64 %564 to i32
  %633 = mul i32 %632, 512
  %634 = trunc i64 %562 to i32
  %635 = add i32 %633, %634
  %636 = sext i32 %635 to i64
  %637 = getelementptr inbounds i8, ptr %631, i64 %636
  store i8 %630, ptr %637, align 1
  %638 = load { i64, i64 }, ptr %6, align 8
  %639 = add i64 %562, 1
  %640 = extractvalue { i64, i64 } %638, 1
  %641 = icmp sge i64 %639, %640
  %642 = select i1 %641, i64 0, i64 %639
  %643 = add i64 %564, 1
  %644 = select i1 %641, i64 %643, i64 %564
  %645 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %646 = load i64, ptr %4, align 8
  %647 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %648 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %645, 0
  %649 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %645, 1, 1, 0
  %650 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %645, 1, 1, 1
  %651 = mul i64 %644, %650
  %652 = add i64 %651, %642
  %653 = getelementptr inbounds i8, ptr %648, i64 %652
  br label %654

654:                                              ; preds = %660, %629
  %655 = phi i64 [ 0, %629 ], [ %663, %660 ]
  %656 = phi i8 [ 0, %629 ], [ %665, %660 ]
  %657 = icmp slt i64 %655, 1
  br i1 %657, label %658, label %659

658:                                              ; preds = %654
  br label %660

659:                                              ; preds = %654
  br label %666

660:                                              ; preds = %658
  %661 = icmp eq i64 %655, 1
  %662 = add i64 %655, 1
  %663 = select i1 %661, i64 %655, i64 %662
  %664 = getelementptr inbounds i8, ptr %653, i64 %655
  %665 = load i8, ptr %664, align 1, !invariant.load !1
  br label %654

666:                                              ; preds = %659
  %667 = phi i8 [ %656, %659 ]
  %668 = call i64 @llvm.smax.i64(i64 %646, i64 1)
  br label %669

669:                                              ; preds = %695, %666
  %670 = phi i64 [ 1, %666 ], [ %678, %695 ]
  %671 = phi i8 [ %667, %666 ], [ %708, %695 ]
  %672 = icmp slt i64 %670, %668
  br i1 %672, label %673, label %674

673:                                              ; preds = %669
  br label %675

674:                                              ; preds = %669
  br label %709

675:                                              ; preds = %673
  %676 = icmp eq i64 %670, %668
  %677 = add i64 %670, 1
  %678 = select i1 %676, i64 %670, i64 %677
  %679 = mul i64 %670, %649
  %680 = add i64 %679, %651
  %681 = add i64 %680, %642
  %682 = getelementptr inbounds i8, ptr %648, i64 %681
  br label %683

683:                                              ; preds = %689, %675
  %684 = phi i64 [ 0, %675 ], [ %692, %689 ]
  %685 = phi i8 [ 0, %675 ], [ %694, %689 ]
  %686 = icmp slt i64 %684, 1
  br i1 %686, label %687, label %688

687:                                              ; preds = %683
  br label %689

688:                                              ; preds = %683
  br label %695

689:                                              ; preds = %687
  %690 = icmp eq i64 %684, 1
  %691 = add i64 %684, 1
  %692 = select i1 %690, i64 %684, i64 %691
  %693 = getelementptr inbounds i8, ptr %682, i64 %684
  %694 = load i8, ptr %693, align 1, !invariant.load !1
  br label %683

695:                                              ; preds = %688
  %696 = phi i8 [ %685, %688 ]
  %697 = zext i8 %671 to i16
  %698 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %697)
  %699 = trunc i32 %698 to i16
  %700 = bitcast i16 %699 to half
  %701 = zext i8 %696 to i16
  %702 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %701)
  %703 = trunc i32 %702 to i16
  %704 = bitcast i16 %703 to half
  %705 = fadd contract half %700, %704
  %706 = fpext half %705 to float
  %707 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %706)
  %708 = trunc i16 %707 to i8
  br label %669

709:                                              ; preds = %674
  %710 = phi i8 [ %671, %674 ]
  %711 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %647, 0
  %712 = trunc i64 %644 to i32
  %713 = mul i32 %712, 512
  %714 = trunc i64 %642 to i32
  %715 = add i32 %713, %714
  %716 = sext i32 %715 to i64
  %717 = getelementptr inbounds i8, ptr %711, i64 %716
  store i8 %710, ptr %717, align 1
  %718 = load { i64, i64 }, ptr %6, align 8
  %719 = add i64 %642, 1
  %720 = extractvalue { i64, i64 } %718, 1
  %721 = icmp sge i64 %719, %720
  %722 = select i1 %721, i64 0, i64 %719
  %723 = add i64 %644, 1
  %724 = select i1 %721, i64 %723, i64 %644
  %725 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %726 = load i64, ptr %4, align 8
  %727 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %728 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %725, 0
  %729 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %725, 1, 1, 0
  %730 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %725, 1, 1, 1
  %731 = mul i64 %724, %730
  %732 = add i64 %731, %722
  %733 = getelementptr inbounds i8, ptr %728, i64 %732
  br label %734

734:                                              ; preds = %740, %709
  %735 = phi i64 [ 0, %709 ], [ %743, %740 ]
  %736 = phi i8 [ 0, %709 ], [ %745, %740 ]
  %737 = icmp slt i64 %735, 1
  br i1 %737, label %738, label %739

738:                                              ; preds = %734
  br label %740

739:                                              ; preds = %734
  br label %746

740:                                              ; preds = %738
  %741 = icmp eq i64 %735, 1
  %742 = add i64 %735, 1
  %743 = select i1 %741, i64 %735, i64 %742
  %744 = getelementptr inbounds i8, ptr %733, i64 %735
  %745 = load i8, ptr %744, align 1, !invariant.load !1
  br label %734

746:                                              ; preds = %739
  %747 = phi i8 [ %736, %739 ]
  %748 = call i64 @llvm.smax.i64(i64 %726, i64 1)
  br label %749

749:                                              ; preds = %775, %746
  %750 = phi i64 [ 1, %746 ], [ %758, %775 ]
  %751 = phi i8 [ %747, %746 ], [ %788, %775 ]
  %752 = icmp slt i64 %750, %748
  br i1 %752, label %753, label %754

753:                                              ; preds = %749
  br label %755

754:                                              ; preds = %749
  br label %789

755:                                              ; preds = %753
  %756 = icmp eq i64 %750, %748
  %757 = add i64 %750, 1
  %758 = select i1 %756, i64 %750, i64 %757
  %759 = mul i64 %750, %729
  %760 = add i64 %759, %731
  %761 = add i64 %760, %722
  %762 = getelementptr inbounds i8, ptr %728, i64 %761
  br label %763

763:                                              ; preds = %769, %755
  %764 = phi i64 [ 0, %755 ], [ %772, %769 ]
  %765 = phi i8 [ 0, %755 ], [ %774, %769 ]
  %766 = icmp slt i64 %764, 1
  br i1 %766, label %767, label %768

767:                                              ; preds = %763
  br label %769

768:                                              ; preds = %763
  br label %775

769:                                              ; preds = %767
  %770 = icmp eq i64 %764, 1
  %771 = add i64 %764, 1
  %772 = select i1 %770, i64 %764, i64 %771
  %773 = getelementptr inbounds i8, ptr %762, i64 %764
  %774 = load i8, ptr %773, align 1, !invariant.load !1
  br label %763

775:                                              ; preds = %768
  %776 = phi i8 [ %765, %768 ]
  %777 = zext i8 %751 to i16
  %778 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %777)
  %779 = trunc i32 %778 to i16
  %780 = bitcast i16 %779 to half
  %781 = zext i8 %776 to i16
  %782 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %781)
  %783 = trunc i32 %782 to i16
  %784 = bitcast i16 %783 to half
  %785 = fadd contract half %780, %784
  %786 = fpext half %785 to float
  %787 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %786)
  %788 = trunc i16 %787 to i8
  br label %749

789:                                              ; preds = %754
  %790 = phi i8 [ %751, %754 ]
  %791 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %727, 0
  %792 = trunc i64 %724 to i32
  %793 = mul i32 %792, 512
  %794 = trunc i64 %722 to i32
  %795 = add i32 %793, %794
  %796 = sext i32 %795 to i64
  %797 = getelementptr inbounds i8, ptr %791, i64 %796
  store i8 %790, ptr %797, align 1
  %798 = load { i64, i64 }, ptr %6, align 8
  %799 = add i64 %722, 1
  %800 = extractvalue { i64, i64 } %798, 1
  %801 = icmp sge i64 %799, %800
  %802 = select i1 %801, i64 0, i64 %799
  %803 = add i64 %724, 1
  %804 = select i1 %801, i64 %803, i64 %724
  %805 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %806 = load i64, ptr %4, align 8
  %807 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %808 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %805, 0
  %809 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %805, 1, 1, 0
  %810 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %805, 1, 1, 1
  %811 = mul i64 %804, %810
  %812 = add i64 %811, %802
  %813 = getelementptr inbounds i8, ptr %808, i64 %812
  br label %814

814:                                              ; preds = %820, %789
  %815 = phi i64 [ 0, %789 ], [ %823, %820 ]
  %816 = phi i8 [ 0, %789 ], [ %825, %820 ]
  %817 = icmp slt i64 %815, 1
  br i1 %817, label %818, label %819

818:                                              ; preds = %814
  br label %820

819:                                              ; preds = %814
  br label %826

820:                                              ; preds = %818
  %821 = icmp eq i64 %815, 1
  %822 = add i64 %815, 1
  %823 = select i1 %821, i64 %815, i64 %822
  %824 = getelementptr inbounds i8, ptr %813, i64 %815
  %825 = load i8, ptr %824, align 1, !invariant.load !1
  br label %814

826:                                              ; preds = %819
  %827 = phi i8 [ %816, %819 ]
  %828 = call i64 @llvm.smax.i64(i64 %806, i64 1)
  br label %829

829:                                              ; preds = %855, %826
  %830 = phi i64 [ 1, %826 ], [ %838, %855 ]
  %831 = phi i8 [ %827, %826 ], [ %868, %855 ]
  %832 = icmp slt i64 %830, %828
  br i1 %832, label %833, label %834

833:                                              ; preds = %829
  br label %835

834:                                              ; preds = %829
  br label %869

835:                                              ; preds = %833
  %836 = icmp eq i64 %830, %828
  %837 = add i64 %830, 1
  %838 = select i1 %836, i64 %830, i64 %837
  %839 = mul i64 %830, %809
  %840 = add i64 %839, %811
  %841 = add i64 %840, %802
  %842 = getelementptr inbounds i8, ptr %808, i64 %841
  br label %843

843:                                              ; preds = %849, %835
  %844 = phi i64 [ 0, %835 ], [ %852, %849 ]
  %845 = phi i8 [ 0, %835 ], [ %854, %849 ]
  %846 = icmp slt i64 %844, 1
  br i1 %846, label %847, label %848

847:                                              ; preds = %843
  br label %849

848:                                              ; preds = %843
  br label %855

849:                                              ; preds = %847
  %850 = icmp eq i64 %844, 1
  %851 = add i64 %844, 1
  %852 = select i1 %850, i64 %844, i64 %851
  %853 = getelementptr inbounds i8, ptr %842, i64 %844
  %854 = load i8, ptr %853, align 1, !invariant.load !1
  br label %843

855:                                              ; preds = %848
  %856 = phi i8 [ %845, %848 ]
  %857 = zext i8 %831 to i16
  %858 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %857)
  %859 = trunc i32 %858 to i16
  %860 = bitcast i16 %859 to half
  %861 = zext i8 %856 to i16
  %862 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %861)
  %863 = trunc i32 %862 to i16
  %864 = bitcast i16 %863 to half
  %865 = fadd contract half %860, %864
  %866 = fpext half %865 to float
  %867 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %866)
  %868 = trunc i16 %867 to i8
  br label %829

869:                                              ; preds = %834
  %870 = phi i8 [ %831, %834 ]
  %871 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %807, 0
  %872 = trunc i64 %804 to i32
  %873 = mul i32 %872, 512
  %874 = trunc i64 %802 to i32
  %875 = add i32 %873, %874
  %876 = sext i32 %875 to i64
  %877 = getelementptr inbounds i8, ptr %871, i64 %876
  store i8 %870, ptr %877, align 1
  %878 = load { i64, i64 }, ptr %6, align 8
  %879 = add i64 %802, 1
  %880 = extractvalue { i64, i64 } %878, 1
  %881 = icmp sge i64 %879, %880
  %882 = select i1 %881, i64 0, i64 %879
  %883 = add i64 %804, 1
  %884 = select i1 %881, i64 %883, i64 %804
  %885 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %886 = load i64, ptr %4, align 8
  %887 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %888 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %885, 0
  %889 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %885, 1, 1, 0
  %890 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %885, 1, 1, 1
  %891 = mul i64 %884, %890
  %892 = add i64 %891, %882
  %893 = getelementptr inbounds i8, ptr %888, i64 %892
  br label %894

894:                                              ; preds = %900, %869
  %895 = phi i64 [ 0, %869 ], [ %903, %900 ]
  %896 = phi i8 [ 0, %869 ], [ %905, %900 ]
  %897 = icmp slt i64 %895, 1
  br i1 %897, label %898, label %899

898:                                              ; preds = %894
  br label %900

899:                                              ; preds = %894
  br label %906

900:                                              ; preds = %898
  %901 = icmp eq i64 %895, 1
  %902 = add i64 %895, 1
  %903 = select i1 %901, i64 %895, i64 %902
  %904 = getelementptr inbounds i8, ptr %893, i64 %895
  %905 = load i8, ptr %904, align 1, !invariant.load !1
  br label %894

906:                                              ; preds = %899
  %907 = phi i8 [ %896, %899 ]
  %908 = call i64 @llvm.smax.i64(i64 %886, i64 1)
  br label %909

909:                                              ; preds = %935, %906
  %910 = phi i64 [ 1, %906 ], [ %918, %935 ]
  %911 = phi i8 [ %907, %906 ], [ %948, %935 ]
  %912 = icmp slt i64 %910, %908
  br i1 %912, label %913, label %914

913:                                              ; preds = %909
  br label %915

914:                                              ; preds = %909
  br label %949

915:                                              ; preds = %913
  %916 = icmp eq i64 %910, %908
  %917 = add i64 %910, 1
  %918 = select i1 %916, i64 %910, i64 %917
  %919 = mul i64 %910, %889
  %920 = add i64 %919, %891
  %921 = add i64 %920, %882
  %922 = getelementptr inbounds i8, ptr %888, i64 %921
  br label %923

923:                                              ; preds = %929, %915
  %924 = phi i64 [ 0, %915 ], [ %932, %929 ]
  %925 = phi i8 [ 0, %915 ], [ %934, %929 ]
  %926 = icmp slt i64 %924, 1
  br i1 %926, label %927, label %928

927:                                              ; preds = %923
  br label %929

928:                                              ; preds = %923
  br label %935

929:                                              ; preds = %927
  %930 = icmp eq i64 %924, 1
  %931 = add i64 %924, 1
  %932 = select i1 %930, i64 %924, i64 %931
  %933 = getelementptr inbounds i8, ptr %922, i64 %924
  %934 = load i8, ptr %933, align 1, !invariant.load !1
  br label %923

935:                                              ; preds = %928
  %936 = phi i8 [ %925, %928 ]
  %937 = zext i8 %911 to i16
  %938 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %937)
  %939 = trunc i32 %938 to i16
  %940 = bitcast i16 %939 to half
  %941 = zext i8 %936 to i16
  %942 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %941)
  %943 = trunc i32 %942 to i16
  %944 = bitcast i16 %943 to half
  %945 = fadd contract half %940, %944
  %946 = fpext half %945 to float
  %947 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %946)
  %948 = trunc i16 %947 to i8
  br label %909

949:                                              ; preds = %914
  %950 = phi i8 [ %911, %914 ]
  %951 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %887, 0
  %952 = trunc i64 %884 to i32
  %953 = mul i32 %952, 512
  %954 = trunc i64 %882 to i32
  %955 = add i32 %953, %954
  %956 = sext i32 %955 to i64
  %957 = getelementptr inbounds i8, ptr %951, i64 %956
  store i8 %950, ptr %957, align 1
  %958 = load { i64, i64 }, ptr %6, align 8
  %959 = add i64 %882, 1
  %960 = extractvalue { i64, i64 } %958, 1
  %961 = icmp sge i64 %959, %960
  %962 = select i1 %961, i64 0, i64 %959
  %963 = add i64 %884, 1
  %964 = select i1 %961, i64 %963, i64 %884
  %965 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %966 = load i64, ptr %4, align 8
  %967 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %968 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %965, 0
  %969 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %965, 1, 1, 0
  %970 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %965, 1, 1, 1
  %971 = mul i64 %964, %970
  %972 = add i64 %971, %962
  %973 = getelementptr inbounds i8, ptr %968, i64 %972
  br label %974

974:                                              ; preds = %980, %949
  %975 = phi i64 [ 0, %949 ], [ %983, %980 ]
  %976 = phi i8 [ 0, %949 ], [ %985, %980 ]
  %977 = icmp slt i64 %975, 1
  br i1 %977, label %978, label %979

978:                                              ; preds = %974
  br label %980

979:                                              ; preds = %974
  br label %986

980:                                              ; preds = %978
  %981 = icmp eq i64 %975, 1
  %982 = add i64 %975, 1
  %983 = select i1 %981, i64 %975, i64 %982
  %984 = getelementptr inbounds i8, ptr %973, i64 %975
  %985 = load i8, ptr %984, align 1, !invariant.load !1
  br label %974

986:                                              ; preds = %979
  %987 = phi i8 [ %976, %979 ]
  %988 = call i64 @llvm.smax.i64(i64 %966, i64 1)
  br label %989

989:                                              ; preds = %1015, %986
  %990 = phi i64 [ 1, %986 ], [ %998, %1015 ]
  %991 = phi i8 [ %987, %986 ], [ %1028, %1015 ]
  %992 = icmp slt i64 %990, %988
  br i1 %992, label %993, label %994

993:                                              ; preds = %989
  br label %995

994:                                              ; preds = %989
  br label %1029

995:                                              ; preds = %993
  %996 = icmp eq i64 %990, %988
  %997 = add i64 %990, 1
  %998 = select i1 %996, i64 %990, i64 %997
  %999 = mul i64 %990, %969
  %1000 = add i64 %999, %971
  %1001 = add i64 %1000, %962
  %1002 = getelementptr inbounds i8, ptr %968, i64 %1001
  br label %1003

1003:                                             ; preds = %1009, %995
  %1004 = phi i64 [ 0, %995 ], [ %1012, %1009 ]
  %1005 = phi i8 [ 0, %995 ], [ %1014, %1009 ]
  %1006 = icmp slt i64 %1004, 1
  br i1 %1006, label %1007, label %1008

1007:                                             ; preds = %1003
  br label %1009

1008:                                             ; preds = %1003
  br label %1015

1009:                                             ; preds = %1007
  %1010 = icmp eq i64 %1004, 1
  %1011 = add i64 %1004, 1
  %1012 = select i1 %1010, i64 %1004, i64 %1011
  %1013 = getelementptr inbounds i8, ptr %1002, i64 %1004
  %1014 = load i8, ptr %1013, align 1, !invariant.load !1
  br label %1003

1015:                                             ; preds = %1008
  %1016 = phi i8 [ %1005, %1008 ]
  %1017 = zext i8 %991 to i16
  %1018 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1017)
  %1019 = trunc i32 %1018 to i16
  %1020 = bitcast i16 %1019 to half
  %1021 = zext i8 %1016 to i16
  %1022 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1021)
  %1023 = trunc i32 %1022 to i16
  %1024 = bitcast i16 %1023 to half
  %1025 = fadd contract half %1020, %1024
  %1026 = fpext half %1025 to float
  %1027 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1026)
  %1028 = trunc i16 %1027 to i8
  br label %989

1029:                                             ; preds = %994
  %1030 = phi i8 [ %991, %994 ]
  %1031 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %967, 0
  %1032 = trunc i64 %964 to i32
  %1033 = mul i32 %1032, 512
  %1034 = trunc i64 %962 to i32
  %1035 = add i32 %1033, %1034
  %1036 = sext i32 %1035 to i64
  %1037 = getelementptr inbounds i8, ptr %1031, i64 %1036
  store i8 %1030, ptr %1037, align 1
  %1038 = load { i64, i64 }, ptr %6, align 8
  %1039 = add i64 %962, 1
  %1040 = extractvalue { i64, i64 } %1038, 1
  %1041 = icmp sge i64 %1039, %1040
  %1042 = select i1 %1041, i64 0, i64 %1039
  %1043 = add i64 %964, 1
  %1044 = select i1 %1041, i64 %1043, i64 %964
  %1045 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1046 = load i64, ptr %4, align 8
  %1047 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1048 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1045, 0
  %1049 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1045, 1, 1, 0
  %1050 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1045, 1, 1, 1
  %1051 = mul i64 %1044, %1050
  %1052 = add i64 %1051, %1042
  %1053 = getelementptr inbounds i8, ptr %1048, i64 %1052
  br label %1054

1054:                                             ; preds = %1060, %1029
  %1055 = phi i64 [ 0, %1029 ], [ %1063, %1060 ]
  %1056 = phi i8 [ 0, %1029 ], [ %1065, %1060 ]
  %1057 = icmp slt i64 %1055, 1
  br i1 %1057, label %1058, label %1059

1058:                                             ; preds = %1054
  br label %1060

1059:                                             ; preds = %1054
  br label %1066

1060:                                             ; preds = %1058
  %1061 = icmp eq i64 %1055, 1
  %1062 = add i64 %1055, 1
  %1063 = select i1 %1061, i64 %1055, i64 %1062
  %1064 = getelementptr inbounds i8, ptr %1053, i64 %1055
  %1065 = load i8, ptr %1064, align 1, !invariant.load !1
  br label %1054

1066:                                             ; preds = %1059
  %1067 = phi i8 [ %1056, %1059 ]
  %1068 = call i64 @llvm.smax.i64(i64 %1046, i64 1)
  br label %1069

1069:                                             ; preds = %1095, %1066
  %1070 = phi i64 [ 1, %1066 ], [ %1078, %1095 ]
  %1071 = phi i8 [ %1067, %1066 ], [ %1108, %1095 ]
  %1072 = icmp slt i64 %1070, %1068
  br i1 %1072, label %1073, label %1074

1073:                                             ; preds = %1069
  br label %1075

1074:                                             ; preds = %1069
  br label %1109

1075:                                             ; preds = %1073
  %1076 = icmp eq i64 %1070, %1068
  %1077 = add i64 %1070, 1
  %1078 = select i1 %1076, i64 %1070, i64 %1077
  %1079 = mul i64 %1070, %1049
  %1080 = add i64 %1079, %1051
  %1081 = add i64 %1080, %1042
  %1082 = getelementptr inbounds i8, ptr %1048, i64 %1081
  br label %1083

1083:                                             ; preds = %1089, %1075
  %1084 = phi i64 [ 0, %1075 ], [ %1092, %1089 ]
  %1085 = phi i8 [ 0, %1075 ], [ %1094, %1089 ]
  %1086 = icmp slt i64 %1084, 1
  br i1 %1086, label %1087, label %1088

1087:                                             ; preds = %1083
  br label %1089

1088:                                             ; preds = %1083
  br label %1095

1089:                                             ; preds = %1087
  %1090 = icmp eq i64 %1084, 1
  %1091 = add i64 %1084, 1
  %1092 = select i1 %1090, i64 %1084, i64 %1091
  %1093 = getelementptr inbounds i8, ptr %1082, i64 %1084
  %1094 = load i8, ptr %1093, align 1, !invariant.load !1
  br label %1083

1095:                                             ; preds = %1088
  %1096 = phi i8 [ %1085, %1088 ]
  %1097 = zext i8 %1071 to i16
  %1098 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1097)
  %1099 = trunc i32 %1098 to i16
  %1100 = bitcast i16 %1099 to half
  %1101 = zext i8 %1096 to i16
  %1102 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1101)
  %1103 = trunc i32 %1102 to i16
  %1104 = bitcast i16 %1103 to half
  %1105 = fadd contract half %1100, %1104
  %1106 = fpext half %1105 to float
  %1107 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1106)
  %1108 = trunc i16 %1107 to i8
  br label %1069

1109:                                             ; preds = %1074
  %1110 = phi i8 [ %1071, %1074 ]
  %1111 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1047, 0
  %1112 = trunc i64 %1044 to i32
  %1113 = mul i32 %1112, 512
  %1114 = trunc i64 %1042 to i32
  %1115 = add i32 %1113, %1114
  %1116 = sext i32 %1115 to i64
  %1117 = getelementptr inbounds i8, ptr %1111, i64 %1116
  store i8 %1110, ptr %1117, align 1
  %1118 = load { i64, i64 }, ptr %6, align 8
  %1119 = add i64 %1042, 1
  %1120 = extractvalue { i64, i64 } %1118, 1
  %1121 = icmp sge i64 %1119, %1120
  %1122 = select i1 %1121, i64 0, i64 %1119
  %1123 = add i64 %1044, 1
  %1124 = select i1 %1121, i64 %1123, i64 %1044
  %1125 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1126 = load i64, ptr %4, align 8
  %1127 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1128 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1125, 0
  %1129 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1125, 1, 1, 0
  %1130 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1125, 1, 1, 1
  %1131 = mul i64 %1124, %1130
  %1132 = add i64 %1131, %1122
  %1133 = getelementptr inbounds i8, ptr %1128, i64 %1132
  br label %1134

1134:                                             ; preds = %1140, %1109
  %1135 = phi i64 [ 0, %1109 ], [ %1143, %1140 ]
  %1136 = phi i8 [ 0, %1109 ], [ %1145, %1140 ]
  %1137 = icmp slt i64 %1135, 1
  br i1 %1137, label %1138, label %1139

1138:                                             ; preds = %1134
  br label %1140

1139:                                             ; preds = %1134
  br label %1146

1140:                                             ; preds = %1138
  %1141 = icmp eq i64 %1135, 1
  %1142 = add i64 %1135, 1
  %1143 = select i1 %1141, i64 %1135, i64 %1142
  %1144 = getelementptr inbounds i8, ptr %1133, i64 %1135
  %1145 = load i8, ptr %1144, align 1, !invariant.load !1
  br label %1134

1146:                                             ; preds = %1139
  %1147 = phi i8 [ %1136, %1139 ]
  %1148 = call i64 @llvm.smax.i64(i64 %1126, i64 1)
  br label %1149

1149:                                             ; preds = %1175, %1146
  %1150 = phi i64 [ 1, %1146 ], [ %1158, %1175 ]
  %1151 = phi i8 [ %1147, %1146 ], [ %1188, %1175 ]
  %1152 = icmp slt i64 %1150, %1148
  br i1 %1152, label %1153, label %1154

1153:                                             ; preds = %1149
  br label %1155

1154:                                             ; preds = %1149
  br label %1189

1155:                                             ; preds = %1153
  %1156 = icmp eq i64 %1150, %1148
  %1157 = add i64 %1150, 1
  %1158 = select i1 %1156, i64 %1150, i64 %1157
  %1159 = mul i64 %1150, %1129
  %1160 = add i64 %1159, %1131
  %1161 = add i64 %1160, %1122
  %1162 = getelementptr inbounds i8, ptr %1128, i64 %1161
  br label %1163

1163:                                             ; preds = %1169, %1155
  %1164 = phi i64 [ 0, %1155 ], [ %1172, %1169 ]
  %1165 = phi i8 [ 0, %1155 ], [ %1174, %1169 ]
  %1166 = icmp slt i64 %1164, 1
  br i1 %1166, label %1167, label %1168

1167:                                             ; preds = %1163
  br label %1169

1168:                                             ; preds = %1163
  br label %1175

1169:                                             ; preds = %1167
  %1170 = icmp eq i64 %1164, 1
  %1171 = add i64 %1164, 1
  %1172 = select i1 %1170, i64 %1164, i64 %1171
  %1173 = getelementptr inbounds i8, ptr %1162, i64 %1164
  %1174 = load i8, ptr %1173, align 1, !invariant.load !1
  br label %1163

1175:                                             ; preds = %1168
  %1176 = phi i8 [ %1165, %1168 ]
  %1177 = zext i8 %1151 to i16
  %1178 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1177)
  %1179 = trunc i32 %1178 to i16
  %1180 = bitcast i16 %1179 to half
  %1181 = zext i8 %1176 to i16
  %1182 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1181)
  %1183 = trunc i32 %1182 to i16
  %1184 = bitcast i16 %1183 to half
  %1185 = fadd contract half %1180, %1184
  %1186 = fpext half %1185 to float
  %1187 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1186)
  %1188 = trunc i16 %1187 to i8
  br label %1149

1189:                                             ; preds = %1154
  %1190 = phi i8 [ %1151, %1154 ]
  %1191 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1127, 0
  %1192 = trunc i64 %1124 to i32
  %1193 = mul i32 %1192, 512
  %1194 = trunc i64 %1122 to i32
  %1195 = add i32 %1193, %1194
  %1196 = sext i32 %1195 to i64
  %1197 = getelementptr inbounds i8, ptr %1191, i64 %1196
  store i8 %1190, ptr %1197, align 1
  %1198 = load { i64, i64 }, ptr %6, align 8
  %1199 = add i64 %1122, 1
  %1200 = extractvalue { i64, i64 } %1198, 1
  %1201 = icmp sge i64 %1199, %1200
  %1202 = select i1 %1201, i64 0, i64 %1199
  %1203 = add i64 %1124, 1
  %1204 = select i1 %1201, i64 %1203, i64 %1124
  %1205 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1206 = load i64, ptr %4, align 8
  %1207 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1208 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1205, 0
  %1209 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1205, 1, 1, 0
  %1210 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1205, 1, 1, 1
  %1211 = mul i64 %1204, %1210
  %1212 = add i64 %1211, %1202
  %1213 = getelementptr inbounds i8, ptr %1208, i64 %1212
  br label %1214

1214:                                             ; preds = %1220, %1189
  %1215 = phi i64 [ 0, %1189 ], [ %1223, %1220 ]
  %1216 = phi i8 [ 0, %1189 ], [ %1225, %1220 ]
  %1217 = icmp slt i64 %1215, 1
  br i1 %1217, label %1218, label %1219

1218:                                             ; preds = %1214
  br label %1220

1219:                                             ; preds = %1214
  br label %1226

1220:                                             ; preds = %1218
  %1221 = icmp eq i64 %1215, 1
  %1222 = add i64 %1215, 1
  %1223 = select i1 %1221, i64 %1215, i64 %1222
  %1224 = getelementptr inbounds i8, ptr %1213, i64 %1215
  %1225 = load i8, ptr %1224, align 1, !invariant.load !1
  br label %1214

1226:                                             ; preds = %1219
  %1227 = phi i8 [ %1216, %1219 ]
  %1228 = call i64 @llvm.smax.i64(i64 %1206, i64 1)
  br label %1229

1229:                                             ; preds = %1255, %1226
  %1230 = phi i64 [ 1, %1226 ], [ %1238, %1255 ]
  %1231 = phi i8 [ %1227, %1226 ], [ %1268, %1255 ]
  %1232 = icmp slt i64 %1230, %1228
  br i1 %1232, label %1233, label %1234

1233:                                             ; preds = %1229
  br label %1235

1234:                                             ; preds = %1229
  br label %1269

1235:                                             ; preds = %1233
  %1236 = icmp eq i64 %1230, %1228
  %1237 = add i64 %1230, 1
  %1238 = select i1 %1236, i64 %1230, i64 %1237
  %1239 = mul i64 %1230, %1209
  %1240 = add i64 %1239, %1211
  %1241 = add i64 %1240, %1202
  %1242 = getelementptr inbounds i8, ptr %1208, i64 %1241
  br label %1243

1243:                                             ; preds = %1249, %1235
  %1244 = phi i64 [ 0, %1235 ], [ %1252, %1249 ]
  %1245 = phi i8 [ 0, %1235 ], [ %1254, %1249 ]
  %1246 = icmp slt i64 %1244, 1
  br i1 %1246, label %1247, label %1248

1247:                                             ; preds = %1243
  br label %1249

1248:                                             ; preds = %1243
  br label %1255

1249:                                             ; preds = %1247
  %1250 = icmp eq i64 %1244, 1
  %1251 = add i64 %1244, 1
  %1252 = select i1 %1250, i64 %1244, i64 %1251
  %1253 = getelementptr inbounds i8, ptr %1242, i64 %1244
  %1254 = load i8, ptr %1253, align 1, !invariant.load !1
  br label %1243

1255:                                             ; preds = %1248
  %1256 = phi i8 [ %1245, %1248 ]
  %1257 = zext i8 %1231 to i16
  %1258 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1257)
  %1259 = trunc i32 %1258 to i16
  %1260 = bitcast i16 %1259 to half
  %1261 = zext i8 %1256 to i16
  %1262 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1261)
  %1263 = trunc i32 %1262 to i16
  %1264 = bitcast i16 %1263 to half
  %1265 = fadd contract half %1260, %1264
  %1266 = fpext half %1265 to float
  %1267 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1266)
  %1268 = trunc i16 %1267 to i8
  br label %1229

1269:                                             ; preds = %1234
  %1270 = phi i8 [ %1231, %1234 ]
  %1271 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1207, 0
  %1272 = trunc i64 %1204 to i32
  %1273 = mul i32 %1272, 512
  %1274 = trunc i64 %1202 to i32
  %1275 = add i32 %1273, %1274
  %1276 = sext i32 %1275 to i64
  %1277 = getelementptr inbounds i8, ptr %1271, i64 %1276
  store i8 %1270, ptr %1277, align 1
  %1278 = load { i64, i64 }, ptr %6, align 8
  %1279 = add i64 %1202, 1
  %1280 = extractvalue { i64, i64 } %1278, 1
  %1281 = icmp sge i64 %1279, %1280
  %1282 = select i1 %1281, i64 0, i64 %1279
  %1283 = add i64 %1204, 1
  %1284 = select i1 %1281, i64 %1283, i64 %1204
  %1285 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1286 = load i64, ptr %4, align 8
  %1287 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1288 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1285, 0
  %1289 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1285, 1, 1, 0
  %1290 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1285, 1, 1, 1
  %1291 = mul i64 %1284, %1290
  %1292 = add i64 %1291, %1282
  %1293 = getelementptr inbounds i8, ptr %1288, i64 %1292
  br label %1294

1294:                                             ; preds = %1300, %1269
  %1295 = phi i64 [ 0, %1269 ], [ %1303, %1300 ]
  %1296 = phi i8 [ 0, %1269 ], [ %1305, %1300 ]
  %1297 = icmp slt i64 %1295, 1
  br i1 %1297, label %1298, label %1299

1298:                                             ; preds = %1294
  br label %1300

1299:                                             ; preds = %1294
  br label %1306

1300:                                             ; preds = %1298
  %1301 = icmp eq i64 %1295, 1
  %1302 = add i64 %1295, 1
  %1303 = select i1 %1301, i64 %1295, i64 %1302
  %1304 = getelementptr inbounds i8, ptr %1293, i64 %1295
  %1305 = load i8, ptr %1304, align 1, !invariant.load !1
  br label %1294

1306:                                             ; preds = %1299
  %1307 = phi i8 [ %1296, %1299 ]
  %1308 = call i64 @llvm.smax.i64(i64 %1286, i64 1)
  br label %1309

1309:                                             ; preds = %1335, %1306
  %1310 = phi i64 [ 1, %1306 ], [ %1318, %1335 ]
  %1311 = phi i8 [ %1307, %1306 ], [ %1348, %1335 ]
  %1312 = icmp slt i64 %1310, %1308
  br i1 %1312, label %1313, label %1314

1313:                                             ; preds = %1309
  br label %1315

1314:                                             ; preds = %1309
  br label %1349

1315:                                             ; preds = %1313
  %1316 = icmp eq i64 %1310, %1308
  %1317 = add i64 %1310, 1
  %1318 = select i1 %1316, i64 %1310, i64 %1317
  %1319 = mul i64 %1310, %1289
  %1320 = add i64 %1319, %1291
  %1321 = add i64 %1320, %1282
  %1322 = getelementptr inbounds i8, ptr %1288, i64 %1321
  br label %1323

1323:                                             ; preds = %1329, %1315
  %1324 = phi i64 [ 0, %1315 ], [ %1332, %1329 ]
  %1325 = phi i8 [ 0, %1315 ], [ %1334, %1329 ]
  %1326 = icmp slt i64 %1324, 1
  br i1 %1326, label %1327, label %1328

1327:                                             ; preds = %1323
  br label %1329

1328:                                             ; preds = %1323
  br label %1335

1329:                                             ; preds = %1327
  %1330 = icmp eq i64 %1324, 1
  %1331 = add i64 %1324, 1
  %1332 = select i1 %1330, i64 %1324, i64 %1331
  %1333 = getelementptr inbounds i8, ptr %1322, i64 %1324
  %1334 = load i8, ptr %1333, align 1, !invariant.load !1
  br label %1323

1335:                                             ; preds = %1328
  %1336 = phi i8 [ %1325, %1328 ]
  %1337 = zext i8 %1311 to i16
  %1338 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1337)
  %1339 = trunc i32 %1338 to i16
  %1340 = bitcast i16 %1339 to half
  %1341 = zext i8 %1336 to i16
  %1342 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1341)
  %1343 = trunc i32 %1342 to i16
  %1344 = bitcast i16 %1343 to half
  %1345 = fadd contract half %1340, %1344
  %1346 = fpext half %1345 to float
  %1347 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1346)
  %1348 = trunc i16 %1347 to i8
  br label %1309

1349:                                             ; preds = %1314
  %1350 = phi i8 [ %1311, %1314 ]
  %1351 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1287, 0
  %1352 = trunc i64 %1284 to i32
  %1353 = mul i32 %1352, 512
  %1354 = trunc i64 %1282 to i32
  %1355 = add i32 %1353, %1354
  %1356 = sext i32 %1355 to i64
  %1357 = getelementptr inbounds i8, ptr %1351, i64 %1356
  store i8 %1350, ptr %1357, align 1
  br label %1476

1358:                                             ; preds = %63
  %1359 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1360 = load i64, ptr %4, align 8
  %1361 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1362 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1359, 0
  %1363 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1359, 1, 1, 0
  %1364 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1359, 1, 1, 1
  %1365 = mul i64 %77, %1364
  %1366 = add i64 %1365, %83
  %1367 = getelementptr inbounds i8, ptr %1362, i64 %1366
  %1368 = load <16 x i8>, ptr %1367, align 16, !invariant.load !1
  %1369 = call i64 @llvm.smax.i64(i64 %1360, i64 1)
  br label %1370

1370:                                             ; preds = %1376, %1358
  %1371 = phi i64 [ 1, %1358 ], [ %1379, %1376 ]
  %1372 = phi <16 x i8> [ %1368, %1358 ], [ %1471, %1376 ]
  %1373 = icmp slt i64 %1371, %1369
  br i1 %1373, label %1374, label %1375

1374:                                             ; preds = %1370
  br label %1376

1375:                                             ; preds = %1370
  br label %1472

1376:                                             ; preds = %1374
  %1377 = icmp eq i64 %1371, %1369
  %1378 = add i64 %1371, 1
  %1379 = select i1 %1377, i64 %1371, i64 %1378
  %1380 = mul i64 %1371, %1363
  %1381 = add i64 %1380, %1365
  %1382 = add i64 %1381, %83
  %1383 = getelementptr inbounds i8, ptr %1362, i64 %1382
  %1384 = load <16 x i8>, ptr %1383, align 16, !invariant.load !1
  %1385 = bitcast <16 x i8> %1372 to <8 x i16>
  %1386 = extractelement <8 x i16> %1385, i32 0
  %1387 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1386)
  %1388 = insertelement <8 x i32> undef, i32 %1387, i32 0
  %1389 = extractelement <8 x i16> %1385, i32 1
  %1390 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1389)
  %1391 = insertelement <8 x i32> %1388, i32 %1390, i32 1
  %1392 = extractelement <8 x i16> %1385, i32 2
  %1393 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1392)
  %1394 = insertelement <8 x i32> %1391, i32 %1393, i32 2
  %1395 = extractelement <8 x i16> %1385, i32 3
  %1396 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1395)
  %1397 = insertelement <8 x i32> %1394, i32 %1396, i32 3
  %1398 = extractelement <8 x i16> %1385, i32 4
  %1399 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1398)
  %1400 = insertelement <8 x i32> %1397, i32 %1399, i32 4
  %1401 = extractelement <8 x i16> %1385, i32 5
  %1402 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1401)
  %1403 = insertelement <8 x i32> %1400, i32 %1402, i32 5
  %1404 = extractelement <8 x i16> %1385, i32 6
  %1405 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1404)
  %1406 = insertelement <8 x i32> %1403, i32 %1405, i32 6
  %1407 = extractelement <8 x i16> %1385, i32 7
  %1408 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1407)
  %1409 = insertelement <8 x i32> %1406, i32 %1408, i32 7
  %1410 = bitcast <8 x i32> %1409 to <16 x half>
  %1411 = bitcast <16 x i8> %1384 to <8 x i16>
  %1412 = extractelement <8 x i16> %1411, i32 0
  %1413 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1412)
  %1414 = insertelement <8 x i32> undef, i32 %1413, i32 0
  %1415 = extractelement <8 x i16> %1411, i32 1
  %1416 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1415)
  %1417 = insertelement <8 x i32> %1414, i32 %1416, i32 1
  %1418 = extractelement <8 x i16> %1411, i32 2
  %1419 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1418)
  %1420 = insertelement <8 x i32> %1417, i32 %1419, i32 2
  %1421 = extractelement <8 x i16> %1411, i32 3
  %1422 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1421)
  %1423 = insertelement <8 x i32> %1420, i32 %1422, i32 3
  %1424 = extractelement <8 x i16> %1411, i32 4
  %1425 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1424)
  %1426 = insertelement <8 x i32> %1423, i32 %1425, i32 4
  %1427 = extractelement <8 x i16> %1411, i32 5
  %1428 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1427)
  %1429 = insertelement <8 x i32> %1426, i32 %1428, i32 5
  %1430 = extractelement <8 x i16> %1411, i32 6
  %1431 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1430)
  %1432 = insertelement <8 x i32> %1429, i32 %1431, i32 6
  %1433 = extractelement <8 x i16> %1411, i32 7
  %1434 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1433)
  %1435 = insertelement <8 x i32> %1432, i32 %1434, i32 7
  %1436 = bitcast <8 x i32> %1435 to <16 x half>
  %1437 = fadd contract <16 x half> %1410, %1436
  %1438 = fpext <16 x half> %1437 to <16 x float>
  %1439 = extractelement <16 x float> %1438, i32 1
  %1440 = extractelement <16 x float> %1438, i32 0
  %1441 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1439, float %1440)
  %1442 = insertelement <8 x i16> undef, i16 %1441, i32 0
  %1443 = extractelement <16 x float> %1438, i32 3
  %1444 = extractelement <16 x float> %1438, i32 2
  %1445 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1443, float %1444)
  %1446 = insertelement <8 x i16> %1442, i16 %1445, i32 1
  %1447 = extractelement <16 x float> %1438, i32 5
  %1448 = extractelement <16 x float> %1438, i32 4
  %1449 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1447, float %1448)
  %1450 = insertelement <8 x i16> %1446, i16 %1449, i32 2
  %1451 = extractelement <16 x float> %1438, i32 7
  %1452 = extractelement <16 x float> %1438, i32 6
  %1453 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1451, float %1452)
  %1454 = insertelement <8 x i16> %1450, i16 %1453, i32 3
  %1455 = extractelement <16 x float> %1438, i32 9
  %1456 = extractelement <16 x float> %1438, i32 8
  %1457 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1455, float %1456)
  %1458 = insertelement <8 x i16> %1454, i16 %1457, i32 4
  %1459 = extractelement <16 x float> %1438, i32 11
  %1460 = extractelement <16 x float> %1438, i32 10
  %1461 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1459, float %1460)
  %1462 = insertelement <8 x i16> %1458, i16 %1461, i32 5
  %1463 = extractelement <16 x float> %1438, i32 13
  %1464 = extractelement <16 x float> %1438, i32 12
  %1465 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1463, float %1464)
  %1466 = insertelement <8 x i16> %1462, i16 %1465, i32 6
  %1467 = extractelement <16 x float> %1438, i32 15
  %1468 = extractelement <16 x float> %1438, i32 14
  %1469 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1467, float %1468)
  %1470 = insertelement <8 x i16> %1466, i16 %1469, i32 7
  %1471 = bitcast <8 x i16> %1470 to <16 x i8>
  br label %1370

1472:                                             ; preds = %1375
  %1473 = phi <16 x i8> [ %1372, %1375 ]
  %1474 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1361, 0
  %1475 = getelementptr inbounds i8, ptr %1474, i64 %86
  store <16 x i8> %1473, ptr %1475, align 16
  br label %1476

1476:                                             ; preds = %1472, %1349
  br label %1478

1477:                                             ; preds = %60
  br label %1478

1478:                                             ; preds = %1477, %1476
  %1479 = add i64 %53, %17
  %1480 = mul i64 %1479, 16
  %1481 = icmp slt i64 %1480, 0
  %1482 = load i64, ptr %20, align 8
  %1483 = icmp slt i64 %1479, %1482
  br i1 %1483, label %1484, label %2898

1484:                                             ; preds = %1478
  %1485 = load { i64, i64 }, ptr %6, align 8
  %1486 = extractvalue { i64, i64 } %1485, 1
  %1487 = icmp eq i64 %1486, 0
  %1488 = select i1 %1487, i64 1, i64 %1486
  %1489 = sdiv i64 %1480, %1488
  %1490 = mul i64 %1489, %1486
  %1491 = sub i64 %1480, %1490
  %1492 = icmp slt i64 %1486, 0
  %1493 = xor i1 %1492, %1481
  %1494 = icmp ne i64 %1491, 0
  %1495 = and i1 %1493, %1494
  %1496 = select i1 %1495, i64 1, i64 0
  %1497 = sub i64 %1489, %1496
  %1498 = select i1 %1487, i64 0, i64 %1497
  %1499 = trunc i64 %1498 to i32
  %1500 = mul i32 %1499, 512
  %1501 = add i64 %1498, 1
  %1502 = select i1 %1495, i64 %1486, i64 0
  %1503 = add i64 %1491, %1502
  %1504 = select i1 %1487, i64 0, i64 %1503
  %1505 = trunc i64 %1504 to i32
  %1506 = add i32 %1500, %1505
  %1507 = sext i32 %1506 to i64
  %1508 = add i64 %1504, 1
  %1509 = add i64 %1504, 16
  %1510 = load i64, ptr %8, align 8
  %1511 = icmp sgt i64 %1509, %1510
  br i1 %1511, label %1512, label %2779

1512:                                             ; preds = %1484
  %1513 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1514 = load i64, ptr %4, align 8
  %1515 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1516 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1513, 0
  %1517 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1513, 1, 1, 0
  %1518 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1513, 1, 1, 1
  %1519 = mul i64 %1498, %1518
  %1520 = add i64 %1519, %1504
  %1521 = getelementptr inbounds i8, ptr %1516, i64 %1520
  br label %1522

1522:                                             ; preds = %1528, %1512
  %1523 = phi i64 [ 0, %1512 ], [ %1531, %1528 ]
  %1524 = phi i8 [ 0, %1512 ], [ %1533, %1528 ]
  %1525 = icmp slt i64 %1523, 1
  br i1 %1525, label %1526, label %1527

1526:                                             ; preds = %1522
  br label %1528

1527:                                             ; preds = %1522
  br label %1534

1528:                                             ; preds = %1526
  %1529 = icmp eq i64 %1523, 1
  %1530 = add i64 %1523, 1
  %1531 = select i1 %1529, i64 %1523, i64 %1530
  %1532 = getelementptr inbounds i8, ptr %1521, i64 %1523
  %1533 = load i8, ptr %1532, align 1, !invariant.load !1
  br label %1522

1534:                                             ; preds = %1527
  %1535 = phi i8 [ %1524, %1527 ]
  %1536 = call i64 @llvm.smax.i64(i64 %1514, i64 1)
  br label %1537

1537:                                             ; preds = %1563, %1534
  %1538 = phi i64 [ 1, %1534 ], [ %1546, %1563 ]
  %1539 = phi i8 [ %1535, %1534 ], [ %1576, %1563 ]
  %1540 = icmp slt i64 %1538, %1536
  br i1 %1540, label %1541, label %1542

1541:                                             ; preds = %1537
  br label %1543

1542:                                             ; preds = %1537
  br label %1577

1543:                                             ; preds = %1541
  %1544 = icmp eq i64 %1538, %1536
  %1545 = add i64 %1538, 1
  %1546 = select i1 %1544, i64 %1538, i64 %1545
  %1547 = mul i64 %1538, %1517
  %1548 = add i64 %1547, %1519
  %1549 = add i64 %1548, %1504
  %1550 = getelementptr inbounds i8, ptr %1516, i64 %1549
  br label %1551

1551:                                             ; preds = %1557, %1543
  %1552 = phi i64 [ 0, %1543 ], [ %1560, %1557 ]
  %1553 = phi i8 [ 0, %1543 ], [ %1562, %1557 ]
  %1554 = icmp slt i64 %1552, 1
  br i1 %1554, label %1555, label %1556

1555:                                             ; preds = %1551
  br label %1557

1556:                                             ; preds = %1551
  br label %1563

1557:                                             ; preds = %1555
  %1558 = icmp eq i64 %1552, 1
  %1559 = add i64 %1552, 1
  %1560 = select i1 %1558, i64 %1552, i64 %1559
  %1561 = getelementptr inbounds i8, ptr %1550, i64 %1552
  %1562 = load i8, ptr %1561, align 1, !invariant.load !1
  br label %1551

1563:                                             ; preds = %1556
  %1564 = phi i8 [ %1553, %1556 ]
  %1565 = zext i8 %1539 to i16
  %1566 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1565)
  %1567 = trunc i32 %1566 to i16
  %1568 = bitcast i16 %1567 to half
  %1569 = zext i8 %1564 to i16
  %1570 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1569)
  %1571 = trunc i32 %1570 to i16
  %1572 = bitcast i16 %1571 to half
  %1573 = fadd contract half %1568, %1572
  %1574 = fpext half %1573 to float
  %1575 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1574)
  %1576 = trunc i16 %1575 to i8
  br label %1537

1577:                                             ; preds = %1542
  %1578 = phi i8 [ %1539, %1542 ]
  %1579 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1515, 0
  %1580 = getelementptr inbounds i8, ptr %1579, i64 %1507
  store i8 %1578, ptr %1580, align 1
  %1581 = load { i64, i64 }, ptr %6, align 8
  %1582 = extractvalue { i64, i64 } %1581, 1
  %1583 = icmp sge i64 %1508, %1582
  %1584 = select i1 %1583, i64 0, i64 %1508
  %1585 = select i1 %1583, i64 %1501, i64 %1498
  %1586 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1587 = load i64, ptr %4, align 8
  %1588 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1589 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1586, 0
  %1590 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1586, 1, 1, 0
  %1591 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1586, 1, 1, 1
  %1592 = mul i64 %1585, %1591
  %1593 = add i64 %1592, %1584
  %1594 = getelementptr inbounds i8, ptr %1589, i64 %1593
  br label %1595

1595:                                             ; preds = %1601, %1577
  %1596 = phi i64 [ 0, %1577 ], [ %1604, %1601 ]
  %1597 = phi i8 [ 0, %1577 ], [ %1606, %1601 ]
  %1598 = icmp slt i64 %1596, 1
  br i1 %1598, label %1599, label %1600

1599:                                             ; preds = %1595
  br label %1601

1600:                                             ; preds = %1595
  br label %1607

1601:                                             ; preds = %1599
  %1602 = icmp eq i64 %1596, 1
  %1603 = add i64 %1596, 1
  %1604 = select i1 %1602, i64 %1596, i64 %1603
  %1605 = getelementptr inbounds i8, ptr %1594, i64 %1596
  %1606 = load i8, ptr %1605, align 1, !invariant.load !1
  br label %1595

1607:                                             ; preds = %1600
  %1608 = phi i8 [ %1597, %1600 ]
  %1609 = call i64 @llvm.smax.i64(i64 %1587, i64 1)
  br label %1610

1610:                                             ; preds = %1636, %1607
  %1611 = phi i64 [ 1, %1607 ], [ %1619, %1636 ]
  %1612 = phi i8 [ %1608, %1607 ], [ %1649, %1636 ]
  %1613 = icmp slt i64 %1611, %1609
  br i1 %1613, label %1614, label %1615

1614:                                             ; preds = %1610
  br label %1616

1615:                                             ; preds = %1610
  br label %1650

1616:                                             ; preds = %1614
  %1617 = icmp eq i64 %1611, %1609
  %1618 = add i64 %1611, 1
  %1619 = select i1 %1617, i64 %1611, i64 %1618
  %1620 = mul i64 %1611, %1590
  %1621 = add i64 %1620, %1592
  %1622 = add i64 %1621, %1584
  %1623 = getelementptr inbounds i8, ptr %1589, i64 %1622
  br label %1624

1624:                                             ; preds = %1630, %1616
  %1625 = phi i64 [ 0, %1616 ], [ %1633, %1630 ]
  %1626 = phi i8 [ 0, %1616 ], [ %1635, %1630 ]
  %1627 = icmp slt i64 %1625, 1
  br i1 %1627, label %1628, label %1629

1628:                                             ; preds = %1624
  br label %1630

1629:                                             ; preds = %1624
  br label %1636

1630:                                             ; preds = %1628
  %1631 = icmp eq i64 %1625, 1
  %1632 = add i64 %1625, 1
  %1633 = select i1 %1631, i64 %1625, i64 %1632
  %1634 = getelementptr inbounds i8, ptr %1623, i64 %1625
  %1635 = load i8, ptr %1634, align 1, !invariant.load !1
  br label %1624

1636:                                             ; preds = %1629
  %1637 = phi i8 [ %1626, %1629 ]
  %1638 = zext i8 %1612 to i16
  %1639 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1638)
  %1640 = trunc i32 %1639 to i16
  %1641 = bitcast i16 %1640 to half
  %1642 = zext i8 %1637 to i16
  %1643 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1642)
  %1644 = trunc i32 %1643 to i16
  %1645 = bitcast i16 %1644 to half
  %1646 = fadd contract half %1641, %1645
  %1647 = fpext half %1646 to float
  %1648 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1647)
  %1649 = trunc i16 %1648 to i8
  br label %1610

1650:                                             ; preds = %1615
  %1651 = phi i8 [ %1612, %1615 ]
  %1652 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1588, 0
  %1653 = trunc i64 %1585 to i32
  %1654 = mul i32 %1653, 512
  %1655 = trunc i64 %1584 to i32
  %1656 = add i32 %1654, %1655
  %1657 = sext i32 %1656 to i64
  %1658 = getelementptr inbounds i8, ptr %1652, i64 %1657
  store i8 %1651, ptr %1658, align 1
  %1659 = load { i64, i64 }, ptr %6, align 8
  %1660 = add i64 %1584, 1
  %1661 = extractvalue { i64, i64 } %1659, 1
  %1662 = icmp sge i64 %1660, %1661
  %1663 = select i1 %1662, i64 0, i64 %1660
  %1664 = add i64 %1585, 1
  %1665 = select i1 %1662, i64 %1664, i64 %1585
  %1666 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1667 = load i64, ptr %4, align 8
  %1668 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1669 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1666, 0
  %1670 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1666, 1, 1, 0
  %1671 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1666, 1, 1, 1
  %1672 = mul i64 %1665, %1671
  %1673 = add i64 %1672, %1663
  %1674 = getelementptr inbounds i8, ptr %1669, i64 %1673
  br label %1675

1675:                                             ; preds = %1681, %1650
  %1676 = phi i64 [ 0, %1650 ], [ %1684, %1681 ]
  %1677 = phi i8 [ 0, %1650 ], [ %1686, %1681 ]
  %1678 = icmp slt i64 %1676, 1
  br i1 %1678, label %1679, label %1680

1679:                                             ; preds = %1675
  br label %1681

1680:                                             ; preds = %1675
  br label %1687

1681:                                             ; preds = %1679
  %1682 = icmp eq i64 %1676, 1
  %1683 = add i64 %1676, 1
  %1684 = select i1 %1682, i64 %1676, i64 %1683
  %1685 = getelementptr inbounds i8, ptr %1674, i64 %1676
  %1686 = load i8, ptr %1685, align 1, !invariant.load !1
  br label %1675

1687:                                             ; preds = %1680
  %1688 = phi i8 [ %1677, %1680 ]
  %1689 = call i64 @llvm.smax.i64(i64 %1667, i64 1)
  br label %1690

1690:                                             ; preds = %1716, %1687
  %1691 = phi i64 [ 1, %1687 ], [ %1699, %1716 ]
  %1692 = phi i8 [ %1688, %1687 ], [ %1729, %1716 ]
  %1693 = icmp slt i64 %1691, %1689
  br i1 %1693, label %1694, label %1695

1694:                                             ; preds = %1690
  br label %1696

1695:                                             ; preds = %1690
  br label %1730

1696:                                             ; preds = %1694
  %1697 = icmp eq i64 %1691, %1689
  %1698 = add i64 %1691, 1
  %1699 = select i1 %1697, i64 %1691, i64 %1698
  %1700 = mul i64 %1691, %1670
  %1701 = add i64 %1700, %1672
  %1702 = add i64 %1701, %1663
  %1703 = getelementptr inbounds i8, ptr %1669, i64 %1702
  br label %1704

1704:                                             ; preds = %1710, %1696
  %1705 = phi i64 [ 0, %1696 ], [ %1713, %1710 ]
  %1706 = phi i8 [ 0, %1696 ], [ %1715, %1710 ]
  %1707 = icmp slt i64 %1705, 1
  br i1 %1707, label %1708, label %1709

1708:                                             ; preds = %1704
  br label %1710

1709:                                             ; preds = %1704
  br label %1716

1710:                                             ; preds = %1708
  %1711 = icmp eq i64 %1705, 1
  %1712 = add i64 %1705, 1
  %1713 = select i1 %1711, i64 %1705, i64 %1712
  %1714 = getelementptr inbounds i8, ptr %1703, i64 %1705
  %1715 = load i8, ptr %1714, align 1, !invariant.load !1
  br label %1704

1716:                                             ; preds = %1709
  %1717 = phi i8 [ %1706, %1709 ]
  %1718 = zext i8 %1692 to i16
  %1719 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1718)
  %1720 = trunc i32 %1719 to i16
  %1721 = bitcast i16 %1720 to half
  %1722 = zext i8 %1717 to i16
  %1723 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1722)
  %1724 = trunc i32 %1723 to i16
  %1725 = bitcast i16 %1724 to half
  %1726 = fadd contract half %1721, %1725
  %1727 = fpext half %1726 to float
  %1728 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1727)
  %1729 = trunc i16 %1728 to i8
  br label %1690

1730:                                             ; preds = %1695
  %1731 = phi i8 [ %1692, %1695 ]
  %1732 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1668, 0
  %1733 = trunc i64 %1665 to i32
  %1734 = mul i32 %1733, 512
  %1735 = trunc i64 %1663 to i32
  %1736 = add i32 %1734, %1735
  %1737 = sext i32 %1736 to i64
  %1738 = getelementptr inbounds i8, ptr %1732, i64 %1737
  store i8 %1731, ptr %1738, align 1
  %1739 = load { i64, i64 }, ptr %6, align 8
  %1740 = add i64 %1663, 1
  %1741 = extractvalue { i64, i64 } %1739, 1
  %1742 = icmp sge i64 %1740, %1741
  %1743 = select i1 %1742, i64 0, i64 %1740
  %1744 = add i64 %1665, 1
  %1745 = select i1 %1742, i64 %1744, i64 %1665
  %1746 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1747 = load i64, ptr %4, align 8
  %1748 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1749 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1746, 0
  %1750 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1746, 1, 1, 0
  %1751 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1746, 1, 1, 1
  %1752 = mul i64 %1745, %1751
  %1753 = add i64 %1752, %1743
  %1754 = getelementptr inbounds i8, ptr %1749, i64 %1753
  br label %1755

1755:                                             ; preds = %1761, %1730
  %1756 = phi i64 [ 0, %1730 ], [ %1764, %1761 ]
  %1757 = phi i8 [ 0, %1730 ], [ %1766, %1761 ]
  %1758 = icmp slt i64 %1756, 1
  br i1 %1758, label %1759, label %1760

1759:                                             ; preds = %1755
  br label %1761

1760:                                             ; preds = %1755
  br label %1767

1761:                                             ; preds = %1759
  %1762 = icmp eq i64 %1756, 1
  %1763 = add i64 %1756, 1
  %1764 = select i1 %1762, i64 %1756, i64 %1763
  %1765 = getelementptr inbounds i8, ptr %1754, i64 %1756
  %1766 = load i8, ptr %1765, align 1, !invariant.load !1
  br label %1755

1767:                                             ; preds = %1760
  %1768 = phi i8 [ %1757, %1760 ]
  %1769 = call i64 @llvm.smax.i64(i64 %1747, i64 1)
  br label %1770

1770:                                             ; preds = %1796, %1767
  %1771 = phi i64 [ 1, %1767 ], [ %1779, %1796 ]
  %1772 = phi i8 [ %1768, %1767 ], [ %1809, %1796 ]
  %1773 = icmp slt i64 %1771, %1769
  br i1 %1773, label %1774, label %1775

1774:                                             ; preds = %1770
  br label %1776

1775:                                             ; preds = %1770
  br label %1810

1776:                                             ; preds = %1774
  %1777 = icmp eq i64 %1771, %1769
  %1778 = add i64 %1771, 1
  %1779 = select i1 %1777, i64 %1771, i64 %1778
  %1780 = mul i64 %1771, %1750
  %1781 = add i64 %1780, %1752
  %1782 = add i64 %1781, %1743
  %1783 = getelementptr inbounds i8, ptr %1749, i64 %1782
  br label %1784

1784:                                             ; preds = %1790, %1776
  %1785 = phi i64 [ 0, %1776 ], [ %1793, %1790 ]
  %1786 = phi i8 [ 0, %1776 ], [ %1795, %1790 ]
  %1787 = icmp slt i64 %1785, 1
  br i1 %1787, label %1788, label %1789

1788:                                             ; preds = %1784
  br label %1790

1789:                                             ; preds = %1784
  br label %1796

1790:                                             ; preds = %1788
  %1791 = icmp eq i64 %1785, 1
  %1792 = add i64 %1785, 1
  %1793 = select i1 %1791, i64 %1785, i64 %1792
  %1794 = getelementptr inbounds i8, ptr %1783, i64 %1785
  %1795 = load i8, ptr %1794, align 1, !invariant.load !1
  br label %1784

1796:                                             ; preds = %1789
  %1797 = phi i8 [ %1786, %1789 ]
  %1798 = zext i8 %1772 to i16
  %1799 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1798)
  %1800 = trunc i32 %1799 to i16
  %1801 = bitcast i16 %1800 to half
  %1802 = zext i8 %1797 to i16
  %1803 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1802)
  %1804 = trunc i32 %1803 to i16
  %1805 = bitcast i16 %1804 to half
  %1806 = fadd contract half %1801, %1805
  %1807 = fpext half %1806 to float
  %1808 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1807)
  %1809 = trunc i16 %1808 to i8
  br label %1770

1810:                                             ; preds = %1775
  %1811 = phi i8 [ %1772, %1775 ]
  %1812 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1748, 0
  %1813 = trunc i64 %1745 to i32
  %1814 = mul i32 %1813, 512
  %1815 = trunc i64 %1743 to i32
  %1816 = add i32 %1814, %1815
  %1817 = sext i32 %1816 to i64
  %1818 = getelementptr inbounds i8, ptr %1812, i64 %1817
  store i8 %1811, ptr %1818, align 1
  %1819 = load { i64, i64 }, ptr %6, align 8
  %1820 = add i64 %1743, 1
  %1821 = extractvalue { i64, i64 } %1819, 1
  %1822 = icmp sge i64 %1820, %1821
  %1823 = select i1 %1822, i64 0, i64 %1820
  %1824 = add i64 %1745, 1
  %1825 = select i1 %1822, i64 %1824, i64 %1745
  %1826 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1827 = load i64, ptr %4, align 8
  %1828 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1829 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1826, 0
  %1830 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1826, 1, 1, 0
  %1831 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1826, 1, 1, 1
  %1832 = mul i64 %1825, %1831
  %1833 = add i64 %1832, %1823
  %1834 = getelementptr inbounds i8, ptr %1829, i64 %1833
  br label %1835

1835:                                             ; preds = %1841, %1810
  %1836 = phi i64 [ 0, %1810 ], [ %1844, %1841 ]
  %1837 = phi i8 [ 0, %1810 ], [ %1846, %1841 ]
  %1838 = icmp slt i64 %1836, 1
  br i1 %1838, label %1839, label %1840

1839:                                             ; preds = %1835
  br label %1841

1840:                                             ; preds = %1835
  br label %1847

1841:                                             ; preds = %1839
  %1842 = icmp eq i64 %1836, 1
  %1843 = add i64 %1836, 1
  %1844 = select i1 %1842, i64 %1836, i64 %1843
  %1845 = getelementptr inbounds i8, ptr %1834, i64 %1836
  %1846 = load i8, ptr %1845, align 1, !invariant.load !1
  br label %1835

1847:                                             ; preds = %1840
  %1848 = phi i8 [ %1837, %1840 ]
  %1849 = call i64 @llvm.smax.i64(i64 %1827, i64 1)
  br label %1850

1850:                                             ; preds = %1876, %1847
  %1851 = phi i64 [ 1, %1847 ], [ %1859, %1876 ]
  %1852 = phi i8 [ %1848, %1847 ], [ %1889, %1876 ]
  %1853 = icmp slt i64 %1851, %1849
  br i1 %1853, label %1854, label %1855

1854:                                             ; preds = %1850
  br label %1856

1855:                                             ; preds = %1850
  br label %1890

1856:                                             ; preds = %1854
  %1857 = icmp eq i64 %1851, %1849
  %1858 = add i64 %1851, 1
  %1859 = select i1 %1857, i64 %1851, i64 %1858
  %1860 = mul i64 %1851, %1830
  %1861 = add i64 %1860, %1832
  %1862 = add i64 %1861, %1823
  %1863 = getelementptr inbounds i8, ptr %1829, i64 %1862
  br label %1864

1864:                                             ; preds = %1870, %1856
  %1865 = phi i64 [ 0, %1856 ], [ %1873, %1870 ]
  %1866 = phi i8 [ 0, %1856 ], [ %1875, %1870 ]
  %1867 = icmp slt i64 %1865, 1
  br i1 %1867, label %1868, label %1869

1868:                                             ; preds = %1864
  br label %1870

1869:                                             ; preds = %1864
  br label %1876

1870:                                             ; preds = %1868
  %1871 = icmp eq i64 %1865, 1
  %1872 = add i64 %1865, 1
  %1873 = select i1 %1871, i64 %1865, i64 %1872
  %1874 = getelementptr inbounds i8, ptr %1863, i64 %1865
  %1875 = load i8, ptr %1874, align 1, !invariant.load !1
  br label %1864

1876:                                             ; preds = %1869
  %1877 = phi i8 [ %1866, %1869 ]
  %1878 = zext i8 %1852 to i16
  %1879 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1878)
  %1880 = trunc i32 %1879 to i16
  %1881 = bitcast i16 %1880 to half
  %1882 = zext i8 %1877 to i16
  %1883 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1882)
  %1884 = trunc i32 %1883 to i16
  %1885 = bitcast i16 %1884 to half
  %1886 = fadd contract half %1881, %1885
  %1887 = fpext half %1886 to float
  %1888 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1887)
  %1889 = trunc i16 %1888 to i8
  br label %1850

1890:                                             ; preds = %1855
  %1891 = phi i8 [ %1852, %1855 ]
  %1892 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1828, 0
  %1893 = trunc i64 %1825 to i32
  %1894 = mul i32 %1893, 512
  %1895 = trunc i64 %1823 to i32
  %1896 = add i32 %1894, %1895
  %1897 = sext i32 %1896 to i64
  %1898 = getelementptr inbounds i8, ptr %1892, i64 %1897
  store i8 %1891, ptr %1898, align 1
  %1899 = load { i64, i64 }, ptr %6, align 8
  %1900 = add i64 %1823, 1
  %1901 = extractvalue { i64, i64 } %1899, 1
  %1902 = icmp sge i64 %1900, %1901
  %1903 = select i1 %1902, i64 0, i64 %1900
  %1904 = add i64 %1825, 1
  %1905 = select i1 %1902, i64 %1904, i64 %1825
  %1906 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1907 = load i64, ptr %4, align 8
  %1908 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1909 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1906, 0
  %1910 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1906, 1, 1, 0
  %1911 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1906, 1, 1, 1
  %1912 = mul i64 %1905, %1911
  %1913 = add i64 %1912, %1903
  %1914 = getelementptr inbounds i8, ptr %1909, i64 %1913
  br label %1915

1915:                                             ; preds = %1921, %1890
  %1916 = phi i64 [ 0, %1890 ], [ %1924, %1921 ]
  %1917 = phi i8 [ 0, %1890 ], [ %1926, %1921 ]
  %1918 = icmp slt i64 %1916, 1
  br i1 %1918, label %1919, label %1920

1919:                                             ; preds = %1915
  br label %1921

1920:                                             ; preds = %1915
  br label %1927

1921:                                             ; preds = %1919
  %1922 = icmp eq i64 %1916, 1
  %1923 = add i64 %1916, 1
  %1924 = select i1 %1922, i64 %1916, i64 %1923
  %1925 = getelementptr inbounds i8, ptr %1914, i64 %1916
  %1926 = load i8, ptr %1925, align 1, !invariant.load !1
  br label %1915

1927:                                             ; preds = %1920
  %1928 = phi i8 [ %1917, %1920 ]
  %1929 = call i64 @llvm.smax.i64(i64 %1907, i64 1)
  br label %1930

1930:                                             ; preds = %1956, %1927
  %1931 = phi i64 [ 1, %1927 ], [ %1939, %1956 ]
  %1932 = phi i8 [ %1928, %1927 ], [ %1969, %1956 ]
  %1933 = icmp slt i64 %1931, %1929
  br i1 %1933, label %1934, label %1935

1934:                                             ; preds = %1930
  br label %1936

1935:                                             ; preds = %1930
  br label %1970

1936:                                             ; preds = %1934
  %1937 = icmp eq i64 %1931, %1929
  %1938 = add i64 %1931, 1
  %1939 = select i1 %1937, i64 %1931, i64 %1938
  %1940 = mul i64 %1931, %1910
  %1941 = add i64 %1940, %1912
  %1942 = add i64 %1941, %1903
  %1943 = getelementptr inbounds i8, ptr %1909, i64 %1942
  br label %1944

1944:                                             ; preds = %1950, %1936
  %1945 = phi i64 [ 0, %1936 ], [ %1953, %1950 ]
  %1946 = phi i8 [ 0, %1936 ], [ %1955, %1950 ]
  %1947 = icmp slt i64 %1945, 1
  br i1 %1947, label %1948, label %1949

1948:                                             ; preds = %1944
  br label %1950

1949:                                             ; preds = %1944
  br label %1956

1950:                                             ; preds = %1948
  %1951 = icmp eq i64 %1945, 1
  %1952 = add i64 %1945, 1
  %1953 = select i1 %1951, i64 %1945, i64 %1952
  %1954 = getelementptr inbounds i8, ptr %1943, i64 %1945
  %1955 = load i8, ptr %1954, align 1, !invariant.load !1
  br label %1944

1956:                                             ; preds = %1949
  %1957 = phi i8 [ %1946, %1949 ]
  %1958 = zext i8 %1932 to i16
  %1959 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1958)
  %1960 = trunc i32 %1959 to i16
  %1961 = bitcast i16 %1960 to half
  %1962 = zext i8 %1957 to i16
  %1963 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1962)
  %1964 = trunc i32 %1963 to i16
  %1965 = bitcast i16 %1964 to half
  %1966 = fadd contract half %1961, %1965
  %1967 = fpext half %1966 to float
  %1968 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1967)
  %1969 = trunc i16 %1968 to i8
  br label %1930

1970:                                             ; preds = %1935
  %1971 = phi i8 [ %1932, %1935 ]
  %1972 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1908, 0
  %1973 = trunc i64 %1905 to i32
  %1974 = mul i32 %1973, 512
  %1975 = trunc i64 %1903 to i32
  %1976 = add i32 %1974, %1975
  %1977 = sext i32 %1976 to i64
  %1978 = getelementptr inbounds i8, ptr %1972, i64 %1977
  store i8 %1971, ptr %1978, align 1
  %1979 = load { i64, i64 }, ptr %6, align 8
  %1980 = add i64 %1903, 1
  %1981 = extractvalue { i64, i64 } %1979, 1
  %1982 = icmp sge i64 %1980, %1981
  %1983 = select i1 %1982, i64 0, i64 %1980
  %1984 = add i64 %1905, 1
  %1985 = select i1 %1982, i64 %1984, i64 %1905
  %1986 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1987 = load i64, ptr %4, align 8
  %1988 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1989 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1986, 0
  %1990 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1986, 1, 1, 0
  %1991 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1986, 1, 1, 1
  %1992 = mul i64 %1985, %1991
  %1993 = add i64 %1992, %1983
  %1994 = getelementptr inbounds i8, ptr %1989, i64 %1993
  br label %1995

1995:                                             ; preds = %2001, %1970
  %1996 = phi i64 [ 0, %1970 ], [ %2004, %2001 ]
  %1997 = phi i8 [ 0, %1970 ], [ %2006, %2001 ]
  %1998 = icmp slt i64 %1996, 1
  br i1 %1998, label %1999, label %2000

1999:                                             ; preds = %1995
  br label %2001

2000:                                             ; preds = %1995
  br label %2007

2001:                                             ; preds = %1999
  %2002 = icmp eq i64 %1996, 1
  %2003 = add i64 %1996, 1
  %2004 = select i1 %2002, i64 %1996, i64 %2003
  %2005 = getelementptr inbounds i8, ptr %1994, i64 %1996
  %2006 = load i8, ptr %2005, align 1, !invariant.load !1
  br label %1995

2007:                                             ; preds = %2000
  %2008 = phi i8 [ %1997, %2000 ]
  %2009 = call i64 @llvm.smax.i64(i64 %1987, i64 1)
  br label %2010

2010:                                             ; preds = %2036, %2007
  %2011 = phi i64 [ 1, %2007 ], [ %2019, %2036 ]
  %2012 = phi i8 [ %2008, %2007 ], [ %2049, %2036 ]
  %2013 = icmp slt i64 %2011, %2009
  br i1 %2013, label %2014, label %2015

2014:                                             ; preds = %2010
  br label %2016

2015:                                             ; preds = %2010
  br label %2050

2016:                                             ; preds = %2014
  %2017 = icmp eq i64 %2011, %2009
  %2018 = add i64 %2011, 1
  %2019 = select i1 %2017, i64 %2011, i64 %2018
  %2020 = mul i64 %2011, %1990
  %2021 = add i64 %2020, %1992
  %2022 = add i64 %2021, %1983
  %2023 = getelementptr inbounds i8, ptr %1989, i64 %2022
  br label %2024

2024:                                             ; preds = %2030, %2016
  %2025 = phi i64 [ 0, %2016 ], [ %2033, %2030 ]
  %2026 = phi i8 [ 0, %2016 ], [ %2035, %2030 ]
  %2027 = icmp slt i64 %2025, 1
  br i1 %2027, label %2028, label %2029

2028:                                             ; preds = %2024
  br label %2030

2029:                                             ; preds = %2024
  br label %2036

2030:                                             ; preds = %2028
  %2031 = icmp eq i64 %2025, 1
  %2032 = add i64 %2025, 1
  %2033 = select i1 %2031, i64 %2025, i64 %2032
  %2034 = getelementptr inbounds i8, ptr %2023, i64 %2025
  %2035 = load i8, ptr %2034, align 1, !invariant.load !1
  br label %2024

2036:                                             ; preds = %2029
  %2037 = phi i8 [ %2026, %2029 ]
  %2038 = zext i8 %2012 to i16
  %2039 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2038)
  %2040 = trunc i32 %2039 to i16
  %2041 = bitcast i16 %2040 to half
  %2042 = zext i8 %2037 to i16
  %2043 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2042)
  %2044 = trunc i32 %2043 to i16
  %2045 = bitcast i16 %2044 to half
  %2046 = fadd contract half %2041, %2045
  %2047 = fpext half %2046 to float
  %2048 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2047)
  %2049 = trunc i16 %2048 to i8
  br label %2010

2050:                                             ; preds = %2015
  %2051 = phi i8 [ %2012, %2015 ]
  %2052 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1988, 0
  %2053 = trunc i64 %1985 to i32
  %2054 = mul i32 %2053, 512
  %2055 = trunc i64 %1983 to i32
  %2056 = add i32 %2054, %2055
  %2057 = sext i32 %2056 to i64
  %2058 = getelementptr inbounds i8, ptr %2052, i64 %2057
  store i8 %2051, ptr %2058, align 1
  %2059 = load { i64, i64 }, ptr %6, align 8
  %2060 = add i64 %1983, 1
  %2061 = extractvalue { i64, i64 } %2059, 1
  %2062 = icmp sge i64 %2060, %2061
  %2063 = select i1 %2062, i64 0, i64 %2060
  %2064 = add i64 %1985, 1
  %2065 = select i1 %2062, i64 %2064, i64 %1985
  %2066 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2067 = load i64, ptr %4, align 8
  %2068 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2069 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2066, 0
  %2070 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2066, 1, 1, 0
  %2071 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2066, 1, 1, 1
  %2072 = mul i64 %2065, %2071
  %2073 = add i64 %2072, %2063
  %2074 = getelementptr inbounds i8, ptr %2069, i64 %2073
  br label %2075

2075:                                             ; preds = %2081, %2050
  %2076 = phi i64 [ 0, %2050 ], [ %2084, %2081 ]
  %2077 = phi i8 [ 0, %2050 ], [ %2086, %2081 ]
  %2078 = icmp slt i64 %2076, 1
  br i1 %2078, label %2079, label %2080

2079:                                             ; preds = %2075
  br label %2081

2080:                                             ; preds = %2075
  br label %2087

2081:                                             ; preds = %2079
  %2082 = icmp eq i64 %2076, 1
  %2083 = add i64 %2076, 1
  %2084 = select i1 %2082, i64 %2076, i64 %2083
  %2085 = getelementptr inbounds i8, ptr %2074, i64 %2076
  %2086 = load i8, ptr %2085, align 1, !invariant.load !1
  br label %2075

2087:                                             ; preds = %2080
  %2088 = phi i8 [ %2077, %2080 ]
  %2089 = call i64 @llvm.smax.i64(i64 %2067, i64 1)
  br label %2090

2090:                                             ; preds = %2116, %2087
  %2091 = phi i64 [ 1, %2087 ], [ %2099, %2116 ]
  %2092 = phi i8 [ %2088, %2087 ], [ %2129, %2116 ]
  %2093 = icmp slt i64 %2091, %2089
  br i1 %2093, label %2094, label %2095

2094:                                             ; preds = %2090
  br label %2096

2095:                                             ; preds = %2090
  br label %2130

2096:                                             ; preds = %2094
  %2097 = icmp eq i64 %2091, %2089
  %2098 = add i64 %2091, 1
  %2099 = select i1 %2097, i64 %2091, i64 %2098
  %2100 = mul i64 %2091, %2070
  %2101 = add i64 %2100, %2072
  %2102 = add i64 %2101, %2063
  %2103 = getelementptr inbounds i8, ptr %2069, i64 %2102
  br label %2104

2104:                                             ; preds = %2110, %2096
  %2105 = phi i64 [ 0, %2096 ], [ %2113, %2110 ]
  %2106 = phi i8 [ 0, %2096 ], [ %2115, %2110 ]
  %2107 = icmp slt i64 %2105, 1
  br i1 %2107, label %2108, label %2109

2108:                                             ; preds = %2104
  br label %2110

2109:                                             ; preds = %2104
  br label %2116

2110:                                             ; preds = %2108
  %2111 = icmp eq i64 %2105, 1
  %2112 = add i64 %2105, 1
  %2113 = select i1 %2111, i64 %2105, i64 %2112
  %2114 = getelementptr inbounds i8, ptr %2103, i64 %2105
  %2115 = load i8, ptr %2114, align 1, !invariant.load !1
  br label %2104

2116:                                             ; preds = %2109
  %2117 = phi i8 [ %2106, %2109 ]
  %2118 = zext i8 %2092 to i16
  %2119 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2118)
  %2120 = trunc i32 %2119 to i16
  %2121 = bitcast i16 %2120 to half
  %2122 = zext i8 %2117 to i16
  %2123 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2122)
  %2124 = trunc i32 %2123 to i16
  %2125 = bitcast i16 %2124 to half
  %2126 = fadd contract half %2121, %2125
  %2127 = fpext half %2126 to float
  %2128 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2127)
  %2129 = trunc i16 %2128 to i8
  br label %2090

2130:                                             ; preds = %2095
  %2131 = phi i8 [ %2092, %2095 ]
  %2132 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2068, 0
  %2133 = trunc i64 %2065 to i32
  %2134 = mul i32 %2133, 512
  %2135 = trunc i64 %2063 to i32
  %2136 = add i32 %2134, %2135
  %2137 = sext i32 %2136 to i64
  %2138 = getelementptr inbounds i8, ptr %2132, i64 %2137
  store i8 %2131, ptr %2138, align 1
  %2139 = load { i64, i64 }, ptr %6, align 8
  %2140 = add i64 %2063, 1
  %2141 = extractvalue { i64, i64 } %2139, 1
  %2142 = icmp sge i64 %2140, %2141
  %2143 = select i1 %2142, i64 0, i64 %2140
  %2144 = add i64 %2065, 1
  %2145 = select i1 %2142, i64 %2144, i64 %2065
  %2146 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2147 = load i64, ptr %4, align 8
  %2148 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2149 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2146, 0
  %2150 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2146, 1, 1, 0
  %2151 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2146, 1, 1, 1
  %2152 = mul i64 %2145, %2151
  %2153 = add i64 %2152, %2143
  %2154 = getelementptr inbounds i8, ptr %2149, i64 %2153
  br label %2155

2155:                                             ; preds = %2161, %2130
  %2156 = phi i64 [ 0, %2130 ], [ %2164, %2161 ]
  %2157 = phi i8 [ 0, %2130 ], [ %2166, %2161 ]
  %2158 = icmp slt i64 %2156, 1
  br i1 %2158, label %2159, label %2160

2159:                                             ; preds = %2155
  br label %2161

2160:                                             ; preds = %2155
  br label %2167

2161:                                             ; preds = %2159
  %2162 = icmp eq i64 %2156, 1
  %2163 = add i64 %2156, 1
  %2164 = select i1 %2162, i64 %2156, i64 %2163
  %2165 = getelementptr inbounds i8, ptr %2154, i64 %2156
  %2166 = load i8, ptr %2165, align 1, !invariant.load !1
  br label %2155

2167:                                             ; preds = %2160
  %2168 = phi i8 [ %2157, %2160 ]
  %2169 = call i64 @llvm.smax.i64(i64 %2147, i64 1)
  br label %2170

2170:                                             ; preds = %2196, %2167
  %2171 = phi i64 [ 1, %2167 ], [ %2179, %2196 ]
  %2172 = phi i8 [ %2168, %2167 ], [ %2209, %2196 ]
  %2173 = icmp slt i64 %2171, %2169
  br i1 %2173, label %2174, label %2175

2174:                                             ; preds = %2170
  br label %2176

2175:                                             ; preds = %2170
  br label %2210

2176:                                             ; preds = %2174
  %2177 = icmp eq i64 %2171, %2169
  %2178 = add i64 %2171, 1
  %2179 = select i1 %2177, i64 %2171, i64 %2178
  %2180 = mul i64 %2171, %2150
  %2181 = add i64 %2180, %2152
  %2182 = add i64 %2181, %2143
  %2183 = getelementptr inbounds i8, ptr %2149, i64 %2182
  br label %2184

2184:                                             ; preds = %2190, %2176
  %2185 = phi i64 [ 0, %2176 ], [ %2193, %2190 ]
  %2186 = phi i8 [ 0, %2176 ], [ %2195, %2190 ]
  %2187 = icmp slt i64 %2185, 1
  br i1 %2187, label %2188, label %2189

2188:                                             ; preds = %2184
  br label %2190

2189:                                             ; preds = %2184
  br label %2196

2190:                                             ; preds = %2188
  %2191 = icmp eq i64 %2185, 1
  %2192 = add i64 %2185, 1
  %2193 = select i1 %2191, i64 %2185, i64 %2192
  %2194 = getelementptr inbounds i8, ptr %2183, i64 %2185
  %2195 = load i8, ptr %2194, align 1, !invariant.load !1
  br label %2184

2196:                                             ; preds = %2189
  %2197 = phi i8 [ %2186, %2189 ]
  %2198 = zext i8 %2172 to i16
  %2199 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2198)
  %2200 = trunc i32 %2199 to i16
  %2201 = bitcast i16 %2200 to half
  %2202 = zext i8 %2197 to i16
  %2203 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2202)
  %2204 = trunc i32 %2203 to i16
  %2205 = bitcast i16 %2204 to half
  %2206 = fadd contract half %2201, %2205
  %2207 = fpext half %2206 to float
  %2208 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2207)
  %2209 = trunc i16 %2208 to i8
  br label %2170

2210:                                             ; preds = %2175
  %2211 = phi i8 [ %2172, %2175 ]
  %2212 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2148, 0
  %2213 = trunc i64 %2145 to i32
  %2214 = mul i32 %2213, 512
  %2215 = trunc i64 %2143 to i32
  %2216 = add i32 %2214, %2215
  %2217 = sext i32 %2216 to i64
  %2218 = getelementptr inbounds i8, ptr %2212, i64 %2217
  store i8 %2211, ptr %2218, align 1
  %2219 = load { i64, i64 }, ptr %6, align 8
  %2220 = add i64 %2143, 1
  %2221 = extractvalue { i64, i64 } %2219, 1
  %2222 = icmp sge i64 %2220, %2221
  %2223 = select i1 %2222, i64 0, i64 %2220
  %2224 = add i64 %2145, 1
  %2225 = select i1 %2222, i64 %2224, i64 %2145
  %2226 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2227 = load i64, ptr %4, align 8
  %2228 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2229 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2226, 0
  %2230 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2226, 1, 1, 0
  %2231 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2226, 1, 1, 1
  %2232 = mul i64 %2225, %2231
  %2233 = add i64 %2232, %2223
  %2234 = getelementptr inbounds i8, ptr %2229, i64 %2233
  br label %2235

2235:                                             ; preds = %2241, %2210
  %2236 = phi i64 [ 0, %2210 ], [ %2244, %2241 ]
  %2237 = phi i8 [ 0, %2210 ], [ %2246, %2241 ]
  %2238 = icmp slt i64 %2236, 1
  br i1 %2238, label %2239, label %2240

2239:                                             ; preds = %2235
  br label %2241

2240:                                             ; preds = %2235
  br label %2247

2241:                                             ; preds = %2239
  %2242 = icmp eq i64 %2236, 1
  %2243 = add i64 %2236, 1
  %2244 = select i1 %2242, i64 %2236, i64 %2243
  %2245 = getelementptr inbounds i8, ptr %2234, i64 %2236
  %2246 = load i8, ptr %2245, align 1, !invariant.load !1
  br label %2235

2247:                                             ; preds = %2240
  %2248 = phi i8 [ %2237, %2240 ]
  %2249 = call i64 @llvm.smax.i64(i64 %2227, i64 1)
  br label %2250

2250:                                             ; preds = %2276, %2247
  %2251 = phi i64 [ 1, %2247 ], [ %2259, %2276 ]
  %2252 = phi i8 [ %2248, %2247 ], [ %2289, %2276 ]
  %2253 = icmp slt i64 %2251, %2249
  br i1 %2253, label %2254, label %2255

2254:                                             ; preds = %2250
  br label %2256

2255:                                             ; preds = %2250
  br label %2290

2256:                                             ; preds = %2254
  %2257 = icmp eq i64 %2251, %2249
  %2258 = add i64 %2251, 1
  %2259 = select i1 %2257, i64 %2251, i64 %2258
  %2260 = mul i64 %2251, %2230
  %2261 = add i64 %2260, %2232
  %2262 = add i64 %2261, %2223
  %2263 = getelementptr inbounds i8, ptr %2229, i64 %2262
  br label %2264

2264:                                             ; preds = %2270, %2256
  %2265 = phi i64 [ 0, %2256 ], [ %2273, %2270 ]
  %2266 = phi i8 [ 0, %2256 ], [ %2275, %2270 ]
  %2267 = icmp slt i64 %2265, 1
  br i1 %2267, label %2268, label %2269

2268:                                             ; preds = %2264
  br label %2270

2269:                                             ; preds = %2264
  br label %2276

2270:                                             ; preds = %2268
  %2271 = icmp eq i64 %2265, 1
  %2272 = add i64 %2265, 1
  %2273 = select i1 %2271, i64 %2265, i64 %2272
  %2274 = getelementptr inbounds i8, ptr %2263, i64 %2265
  %2275 = load i8, ptr %2274, align 1, !invariant.load !1
  br label %2264

2276:                                             ; preds = %2269
  %2277 = phi i8 [ %2266, %2269 ]
  %2278 = zext i8 %2252 to i16
  %2279 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2278)
  %2280 = trunc i32 %2279 to i16
  %2281 = bitcast i16 %2280 to half
  %2282 = zext i8 %2277 to i16
  %2283 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2282)
  %2284 = trunc i32 %2283 to i16
  %2285 = bitcast i16 %2284 to half
  %2286 = fadd contract half %2281, %2285
  %2287 = fpext half %2286 to float
  %2288 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2287)
  %2289 = trunc i16 %2288 to i8
  br label %2250

2290:                                             ; preds = %2255
  %2291 = phi i8 [ %2252, %2255 ]
  %2292 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2228, 0
  %2293 = trunc i64 %2225 to i32
  %2294 = mul i32 %2293, 512
  %2295 = trunc i64 %2223 to i32
  %2296 = add i32 %2294, %2295
  %2297 = sext i32 %2296 to i64
  %2298 = getelementptr inbounds i8, ptr %2292, i64 %2297
  store i8 %2291, ptr %2298, align 1
  %2299 = load { i64, i64 }, ptr %6, align 8
  %2300 = add i64 %2223, 1
  %2301 = extractvalue { i64, i64 } %2299, 1
  %2302 = icmp sge i64 %2300, %2301
  %2303 = select i1 %2302, i64 0, i64 %2300
  %2304 = add i64 %2225, 1
  %2305 = select i1 %2302, i64 %2304, i64 %2225
  %2306 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2307 = load i64, ptr %4, align 8
  %2308 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2309 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2306, 0
  %2310 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2306, 1, 1, 0
  %2311 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2306, 1, 1, 1
  %2312 = mul i64 %2305, %2311
  %2313 = add i64 %2312, %2303
  %2314 = getelementptr inbounds i8, ptr %2309, i64 %2313
  br label %2315

2315:                                             ; preds = %2321, %2290
  %2316 = phi i64 [ 0, %2290 ], [ %2324, %2321 ]
  %2317 = phi i8 [ 0, %2290 ], [ %2326, %2321 ]
  %2318 = icmp slt i64 %2316, 1
  br i1 %2318, label %2319, label %2320

2319:                                             ; preds = %2315
  br label %2321

2320:                                             ; preds = %2315
  br label %2327

2321:                                             ; preds = %2319
  %2322 = icmp eq i64 %2316, 1
  %2323 = add i64 %2316, 1
  %2324 = select i1 %2322, i64 %2316, i64 %2323
  %2325 = getelementptr inbounds i8, ptr %2314, i64 %2316
  %2326 = load i8, ptr %2325, align 1, !invariant.load !1
  br label %2315

2327:                                             ; preds = %2320
  %2328 = phi i8 [ %2317, %2320 ]
  %2329 = call i64 @llvm.smax.i64(i64 %2307, i64 1)
  br label %2330

2330:                                             ; preds = %2356, %2327
  %2331 = phi i64 [ 1, %2327 ], [ %2339, %2356 ]
  %2332 = phi i8 [ %2328, %2327 ], [ %2369, %2356 ]
  %2333 = icmp slt i64 %2331, %2329
  br i1 %2333, label %2334, label %2335

2334:                                             ; preds = %2330
  br label %2336

2335:                                             ; preds = %2330
  br label %2370

2336:                                             ; preds = %2334
  %2337 = icmp eq i64 %2331, %2329
  %2338 = add i64 %2331, 1
  %2339 = select i1 %2337, i64 %2331, i64 %2338
  %2340 = mul i64 %2331, %2310
  %2341 = add i64 %2340, %2312
  %2342 = add i64 %2341, %2303
  %2343 = getelementptr inbounds i8, ptr %2309, i64 %2342
  br label %2344

2344:                                             ; preds = %2350, %2336
  %2345 = phi i64 [ 0, %2336 ], [ %2353, %2350 ]
  %2346 = phi i8 [ 0, %2336 ], [ %2355, %2350 ]
  %2347 = icmp slt i64 %2345, 1
  br i1 %2347, label %2348, label %2349

2348:                                             ; preds = %2344
  br label %2350

2349:                                             ; preds = %2344
  br label %2356

2350:                                             ; preds = %2348
  %2351 = icmp eq i64 %2345, 1
  %2352 = add i64 %2345, 1
  %2353 = select i1 %2351, i64 %2345, i64 %2352
  %2354 = getelementptr inbounds i8, ptr %2343, i64 %2345
  %2355 = load i8, ptr %2354, align 1, !invariant.load !1
  br label %2344

2356:                                             ; preds = %2349
  %2357 = phi i8 [ %2346, %2349 ]
  %2358 = zext i8 %2332 to i16
  %2359 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2358)
  %2360 = trunc i32 %2359 to i16
  %2361 = bitcast i16 %2360 to half
  %2362 = zext i8 %2357 to i16
  %2363 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2362)
  %2364 = trunc i32 %2363 to i16
  %2365 = bitcast i16 %2364 to half
  %2366 = fadd contract half %2361, %2365
  %2367 = fpext half %2366 to float
  %2368 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2367)
  %2369 = trunc i16 %2368 to i8
  br label %2330

2370:                                             ; preds = %2335
  %2371 = phi i8 [ %2332, %2335 ]
  %2372 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2308, 0
  %2373 = trunc i64 %2305 to i32
  %2374 = mul i32 %2373, 512
  %2375 = trunc i64 %2303 to i32
  %2376 = add i32 %2374, %2375
  %2377 = sext i32 %2376 to i64
  %2378 = getelementptr inbounds i8, ptr %2372, i64 %2377
  store i8 %2371, ptr %2378, align 1
  %2379 = load { i64, i64 }, ptr %6, align 8
  %2380 = add i64 %2303, 1
  %2381 = extractvalue { i64, i64 } %2379, 1
  %2382 = icmp sge i64 %2380, %2381
  %2383 = select i1 %2382, i64 0, i64 %2380
  %2384 = add i64 %2305, 1
  %2385 = select i1 %2382, i64 %2384, i64 %2305
  %2386 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2387 = load i64, ptr %4, align 8
  %2388 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2389 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2386, 0
  %2390 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2386, 1, 1, 0
  %2391 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2386, 1, 1, 1
  %2392 = mul i64 %2385, %2391
  %2393 = add i64 %2392, %2383
  %2394 = getelementptr inbounds i8, ptr %2389, i64 %2393
  br label %2395

2395:                                             ; preds = %2401, %2370
  %2396 = phi i64 [ 0, %2370 ], [ %2404, %2401 ]
  %2397 = phi i8 [ 0, %2370 ], [ %2406, %2401 ]
  %2398 = icmp slt i64 %2396, 1
  br i1 %2398, label %2399, label %2400

2399:                                             ; preds = %2395
  br label %2401

2400:                                             ; preds = %2395
  br label %2407

2401:                                             ; preds = %2399
  %2402 = icmp eq i64 %2396, 1
  %2403 = add i64 %2396, 1
  %2404 = select i1 %2402, i64 %2396, i64 %2403
  %2405 = getelementptr inbounds i8, ptr %2394, i64 %2396
  %2406 = load i8, ptr %2405, align 1, !invariant.load !1
  br label %2395

2407:                                             ; preds = %2400
  %2408 = phi i8 [ %2397, %2400 ]
  %2409 = call i64 @llvm.smax.i64(i64 %2387, i64 1)
  br label %2410

2410:                                             ; preds = %2436, %2407
  %2411 = phi i64 [ 1, %2407 ], [ %2419, %2436 ]
  %2412 = phi i8 [ %2408, %2407 ], [ %2449, %2436 ]
  %2413 = icmp slt i64 %2411, %2409
  br i1 %2413, label %2414, label %2415

2414:                                             ; preds = %2410
  br label %2416

2415:                                             ; preds = %2410
  br label %2450

2416:                                             ; preds = %2414
  %2417 = icmp eq i64 %2411, %2409
  %2418 = add i64 %2411, 1
  %2419 = select i1 %2417, i64 %2411, i64 %2418
  %2420 = mul i64 %2411, %2390
  %2421 = add i64 %2420, %2392
  %2422 = add i64 %2421, %2383
  %2423 = getelementptr inbounds i8, ptr %2389, i64 %2422
  br label %2424

2424:                                             ; preds = %2430, %2416
  %2425 = phi i64 [ 0, %2416 ], [ %2433, %2430 ]
  %2426 = phi i8 [ 0, %2416 ], [ %2435, %2430 ]
  %2427 = icmp slt i64 %2425, 1
  br i1 %2427, label %2428, label %2429

2428:                                             ; preds = %2424
  br label %2430

2429:                                             ; preds = %2424
  br label %2436

2430:                                             ; preds = %2428
  %2431 = icmp eq i64 %2425, 1
  %2432 = add i64 %2425, 1
  %2433 = select i1 %2431, i64 %2425, i64 %2432
  %2434 = getelementptr inbounds i8, ptr %2423, i64 %2425
  %2435 = load i8, ptr %2434, align 1, !invariant.load !1
  br label %2424

2436:                                             ; preds = %2429
  %2437 = phi i8 [ %2426, %2429 ]
  %2438 = zext i8 %2412 to i16
  %2439 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2438)
  %2440 = trunc i32 %2439 to i16
  %2441 = bitcast i16 %2440 to half
  %2442 = zext i8 %2437 to i16
  %2443 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2442)
  %2444 = trunc i32 %2443 to i16
  %2445 = bitcast i16 %2444 to half
  %2446 = fadd contract half %2441, %2445
  %2447 = fpext half %2446 to float
  %2448 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2447)
  %2449 = trunc i16 %2448 to i8
  br label %2410

2450:                                             ; preds = %2415
  %2451 = phi i8 [ %2412, %2415 ]
  %2452 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2388, 0
  %2453 = trunc i64 %2385 to i32
  %2454 = mul i32 %2453, 512
  %2455 = trunc i64 %2383 to i32
  %2456 = add i32 %2454, %2455
  %2457 = sext i32 %2456 to i64
  %2458 = getelementptr inbounds i8, ptr %2452, i64 %2457
  store i8 %2451, ptr %2458, align 1
  %2459 = load { i64, i64 }, ptr %6, align 8
  %2460 = add i64 %2383, 1
  %2461 = extractvalue { i64, i64 } %2459, 1
  %2462 = icmp sge i64 %2460, %2461
  %2463 = select i1 %2462, i64 0, i64 %2460
  %2464 = add i64 %2385, 1
  %2465 = select i1 %2462, i64 %2464, i64 %2385
  %2466 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2467 = load i64, ptr %4, align 8
  %2468 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2469 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2466, 0
  %2470 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2466, 1, 1, 0
  %2471 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2466, 1, 1, 1
  %2472 = mul i64 %2465, %2471
  %2473 = add i64 %2472, %2463
  %2474 = getelementptr inbounds i8, ptr %2469, i64 %2473
  br label %2475

2475:                                             ; preds = %2481, %2450
  %2476 = phi i64 [ 0, %2450 ], [ %2484, %2481 ]
  %2477 = phi i8 [ 0, %2450 ], [ %2486, %2481 ]
  %2478 = icmp slt i64 %2476, 1
  br i1 %2478, label %2479, label %2480

2479:                                             ; preds = %2475
  br label %2481

2480:                                             ; preds = %2475
  br label %2487

2481:                                             ; preds = %2479
  %2482 = icmp eq i64 %2476, 1
  %2483 = add i64 %2476, 1
  %2484 = select i1 %2482, i64 %2476, i64 %2483
  %2485 = getelementptr inbounds i8, ptr %2474, i64 %2476
  %2486 = load i8, ptr %2485, align 1, !invariant.load !1
  br label %2475

2487:                                             ; preds = %2480
  %2488 = phi i8 [ %2477, %2480 ]
  %2489 = call i64 @llvm.smax.i64(i64 %2467, i64 1)
  br label %2490

2490:                                             ; preds = %2516, %2487
  %2491 = phi i64 [ 1, %2487 ], [ %2499, %2516 ]
  %2492 = phi i8 [ %2488, %2487 ], [ %2529, %2516 ]
  %2493 = icmp slt i64 %2491, %2489
  br i1 %2493, label %2494, label %2495

2494:                                             ; preds = %2490
  br label %2496

2495:                                             ; preds = %2490
  br label %2530

2496:                                             ; preds = %2494
  %2497 = icmp eq i64 %2491, %2489
  %2498 = add i64 %2491, 1
  %2499 = select i1 %2497, i64 %2491, i64 %2498
  %2500 = mul i64 %2491, %2470
  %2501 = add i64 %2500, %2472
  %2502 = add i64 %2501, %2463
  %2503 = getelementptr inbounds i8, ptr %2469, i64 %2502
  br label %2504

2504:                                             ; preds = %2510, %2496
  %2505 = phi i64 [ 0, %2496 ], [ %2513, %2510 ]
  %2506 = phi i8 [ 0, %2496 ], [ %2515, %2510 ]
  %2507 = icmp slt i64 %2505, 1
  br i1 %2507, label %2508, label %2509

2508:                                             ; preds = %2504
  br label %2510

2509:                                             ; preds = %2504
  br label %2516

2510:                                             ; preds = %2508
  %2511 = icmp eq i64 %2505, 1
  %2512 = add i64 %2505, 1
  %2513 = select i1 %2511, i64 %2505, i64 %2512
  %2514 = getelementptr inbounds i8, ptr %2503, i64 %2505
  %2515 = load i8, ptr %2514, align 1, !invariant.load !1
  br label %2504

2516:                                             ; preds = %2509
  %2517 = phi i8 [ %2506, %2509 ]
  %2518 = zext i8 %2492 to i16
  %2519 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2518)
  %2520 = trunc i32 %2519 to i16
  %2521 = bitcast i16 %2520 to half
  %2522 = zext i8 %2517 to i16
  %2523 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2522)
  %2524 = trunc i32 %2523 to i16
  %2525 = bitcast i16 %2524 to half
  %2526 = fadd contract half %2521, %2525
  %2527 = fpext half %2526 to float
  %2528 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2527)
  %2529 = trunc i16 %2528 to i8
  br label %2490

2530:                                             ; preds = %2495
  %2531 = phi i8 [ %2492, %2495 ]
  %2532 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2468, 0
  %2533 = trunc i64 %2465 to i32
  %2534 = mul i32 %2533, 512
  %2535 = trunc i64 %2463 to i32
  %2536 = add i32 %2534, %2535
  %2537 = sext i32 %2536 to i64
  %2538 = getelementptr inbounds i8, ptr %2532, i64 %2537
  store i8 %2531, ptr %2538, align 1
  %2539 = load { i64, i64 }, ptr %6, align 8
  %2540 = add i64 %2463, 1
  %2541 = extractvalue { i64, i64 } %2539, 1
  %2542 = icmp sge i64 %2540, %2541
  %2543 = select i1 %2542, i64 0, i64 %2540
  %2544 = add i64 %2465, 1
  %2545 = select i1 %2542, i64 %2544, i64 %2465
  %2546 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2547 = load i64, ptr %4, align 8
  %2548 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2549 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2546, 0
  %2550 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2546, 1, 1, 0
  %2551 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2546, 1, 1, 1
  %2552 = mul i64 %2545, %2551
  %2553 = add i64 %2552, %2543
  %2554 = getelementptr inbounds i8, ptr %2549, i64 %2553
  br label %2555

2555:                                             ; preds = %2561, %2530
  %2556 = phi i64 [ 0, %2530 ], [ %2564, %2561 ]
  %2557 = phi i8 [ 0, %2530 ], [ %2566, %2561 ]
  %2558 = icmp slt i64 %2556, 1
  br i1 %2558, label %2559, label %2560

2559:                                             ; preds = %2555
  br label %2561

2560:                                             ; preds = %2555
  br label %2567

2561:                                             ; preds = %2559
  %2562 = icmp eq i64 %2556, 1
  %2563 = add i64 %2556, 1
  %2564 = select i1 %2562, i64 %2556, i64 %2563
  %2565 = getelementptr inbounds i8, ptr %2554, i64 %2556
  %2566 = load i8, ptr %2565, align 1, !invariant.load !1
  br label %2555

2567:                                             ; preds = %2560
  %2568 = phi i8 [ %2557, %2560 ]
  %2569 = call i64 @llvm.smax.i64(i64 %2547, i64 1)
  br label %2570

2570:                                             ; preds = %2596, %2567
  %2571 = phi i64 [ 1, %2567 ], [ %2579, %2596 ]
  %2572 = phi i8 [ %2568, %2567 ], [ %2609, %2596 ]
  %2573 = icmp slt i64 %2571, %2569
  br i1 %2573, label %2574, label %2575

2574:                                             ; preds = %2570
  br label %2576

2575:                                             ; preds = %2570
  br label %2610

2576:                                             ; preds = %2574
  %2577 = icmp eq i64 %2571, %2569
  %2578 = add i64 %2571, 1
  %2579 = select i1 %2577, i64 %2571, i64 %2578
  %2580 = mul i64 %2571, %2550
  %2581 = add i64 %2580, %2552
  %2582 = add i64 %2581, %2543
  %2583 = getelementptr inbounds i8, ptr %2549, i64 %2582
  br label %2584

2584:                                             ; preds = %2590, %2576
  %2585 = phi i64 [ 0, %2576 ], [ %2593, %2590 ]
  %2586 = phi i8 [ 0, %2576 ], [ %2595, %2590 ]
  %2587 = icmp slt i64 %2585, 1
  br i1 %2587, label %2588, label %2589

2588:                                             ; preds = %2584
  br label %2590

2589:                                             ; preds = %2584
  br label %2596

2590:                                             ; preds = %2588
  %2591 = icmp eq i64 %2585, 1
  %2592 = add i64 %2585, 1
  %2593 = select i1 %2591, i64 %2585, i64 %2592
  %2594 = getelementptr inbounds i8, ptr %2583, i64 %2585
  %2595 = load i8, ptr %2594, align 1, !invariant.load !1
  br label %2584

2596:                                             ; preds = %2589
  %2597 = phi i8 [ %2586, %2589 ]
  %2598 = zext i8 %2572 to i16
  %2599 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2598)
  %2600 = trunc i32 %2599 to i16
  %2601 = bitcast i16 %2600 to half
  %2602 = zext i8 %2597 to i16
  %2603 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2602)
  %2604 = trunc i32 %2603 to i16
  %2605 = bitcast i16 %2604 to half
  %2606 = fadd contract half %2601, %2605
  %2607 = fpext half %2606 to float
  %2608 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2607)
  %2609 = trunc i16 %2608 to i8
  br label %2570

2610:                                             ; preds = %2575
  %2611 = phi i8 [ %2572, %2575 ]
  %2612 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2548, 0
  %2613 = trunc i64 %2545 to i32
  %2614 = mul i32 %2613, 512
  %2615 = trunc i64 %2543 to i32
  %2616 = add i32 %2614, %2615
  %2617 = sext i32 %2616 to i64
  %2618 = getelementptr inbounds i8, ptr %2612, i64 %2617
  store i8 %2611, ptr %2618, align 1
  %2619 = load { i64, i64 }, ptr %6, align 8
  %2620 = add i64 %2543, 1
  %2621 = extractvalue { i64, i64 } %2619, 1
  %2622 = icmp sge i64 %2620, %2621
  %2623 = select i1 %2622, i64 0, i64 %2620
  %2624 = add i64 %2545, 1
  %2625 = select i1 %2622, i64 %2624, i64 %2545
  %2626 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2627 = load i64, ptr %4, align 8
  %2628 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2629 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2626, 0
  %2630 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2626, 1, 1, 0
  %2631 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2626, 1, 1, 1
  %2632 = mul i64 %2625, %2631
  %2633 = add i64 %2632, %2623
  %2634 = getelementptr inbounds i8, ptr %2629, i64 %2633
  br label %2635

2635:                                             ; preds = %2641, %2610
  %2636 = phi i64 [ 0, %2610 ], [ %2644, %2641 ]
  %2637 = phi i8 [ 0, %2610 ], [ %2646, %2641 ]
  %2638 = icmp slt i64 %2636, 1
  br i1 %2638, label %2639, label %2640

2639:                                             ; preds = %2635
  br label %2641

2640:                                             ; preds = %2635
  br label %2647

2641:                                             ; preds = %2639
  %2642 = icmp eq i64 %2636, 1
  %2643 = add i64 %2636, 1
  %2644 = select i1 %2642, i64 %2636, i64 %2643
  %2645 = getelementptr inbounds i8, ptr %2634, i64 %2636
  %2646 = load i8, ptr %2645, align 1, !invariant.load !1
  br label %2635

2647:                                             ; preds = %2640
  %2648 = phi i8 [ %2637, %2640 ]
  %2649 = call i64 @llvm.smax.i64(i64 %2627, i64 1)
  br label %2650

2650:                                             ; preds = %2676, %2647
  %2651 = phi i64 [ 1, %2647 ], [ %2659, %2676 ]
  %2652 = phi i8 [ %2648, %2647 ], [ %2689, %2676 ]
  %2653 = icmp slt i64 %2651, %2649
  br i1 %2653, label %2654, label %2655

2654:                                             ; preds = %2650
  br label %2656

2655:                                             ; preds = %2650
  br label %2690

2656:                                             ; preds = %2654
  %2657 = icmp eq i64 %2651, %2649
  %2658 = add i64 %2651, 1
  %2659 = select i1 %2657, i64 %2651, i64 %2658
  %2660 = mul i64 %2651, %2630
  %2661 = add i64 %2660, %2632
  %2662 = add i64 %2661, %2623
  %2663 = getelementptr inbounds i8, ptr %2629, i64 %2662
  br label %2664

2664:                                             ; preds = %2670, %2656
  %2665 = phi i64 [ 0, %2656 ], [ %2673, %2670 ]
  %2666 = phi i8 [ 0, %2656 ], [ %2675, %2670 ]
  %2667 = icmp slt i64 %2665, 1
  br i1 %2667, label %2668, label %2669

2668:                                             ; preds = %2664
  br label %2670

2669:                                             ; preds = %2664
  br label %2676

2670:                                             ; preds = %2668
  %2671 = icmp eq i64 %2665, 1
  %2672 = add i64 %2665, 1
  %2673 = select i1 %2671, i64 %2665, i64 %2672
  %2674 = getelementptr inbounds i8, ptr %2663, i64 %2665
  %2675 = load i8, ptr %2674, align 1, !invariant.load !1
  br label %2664

2676:                                             ; preds = %2669
  %2677 = phi i8 [ %2666, %2669 ]
  %2678 = zext i8 %2652 to i16
  %2679 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2678)
  %2680 = trunc i32 %2679 to i16
  %2681 = bitcast i16 %2680 to half
  %2682 = zext i8 %2677 to i16
  %2683 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2682)
  %2684 = trunc i32 %2683 to i16
  %2685 = bitcast i16 %2684 to half
  %2686 = fadd contract half %2681, %2685
  %2687 = fpext half %2686 to float
  %2688 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2687)
  %2689 = trunc i16 %2688 to i8
  br label %2650

2690:                                             ; preds = %2655
  %2691 = phi i8 [ %2652, %2655 ]
  %2692 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2628, 0
  %2693 = trunc i64 %2625 to i32
  %2694 = mul i32 %2693, 512
  %2695 = trunc i64 %2623 to i32
  %2696 = add i32 %2694, %2695
  %2697 = sext i32 %2696 to i64
  %2698 = getelementptr inbounds i8, ptr %2692, i64 %2697
  store i8 %2691, ptr %2698, align 1
  %2699 = load { i64, i64 }, ptr %6, align 8
  %2700 = add i64 %2623, 1
  %2701 = extractvalue { i64, i64 } %2699, 1
  %2702 = icmp sge i64 %2700, %2701
  %2703 = select i1 %2702, i64 0, i64 %2700
  %2704 = add i64 %2625, 1
  %2705 = select i1 %2702, i64 %2704, i64 %2625
  %2706 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2707 = load i64, ptr %4, align 8
  %2708 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2709 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2706, 0
  %2710 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2706, 1, 1, 0
  %2711 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2706, 1, 1, 1
  %2712 = mul i64 %2705, %2711
  %2713 = add i64 %2712, %2703
  %2714 = getelementptr inbounds i8, ptr %2709, i64 %2713
  br label %2715

2715:                                             ; preds = %2721, %2690
  %2716 = phi i64 [ 0, %2690 ], [ %2724, %2721 ]
  %2717 = phi i8 [ 0, %2690 ], [ %2726, %2721 ]
  %2718 = icmp slt i64 %2716, 1
  br i1 %2718, label %2719, label %2720

2719:                                             ; preds = %2715
  br label %2721

2720:                                             ; preds = %2715
  br label %2727

2721:                                             ; preds = %2719
  %2722 = icmp eq i64 %2716, 1
  %2723 = add i64 %2716, 1
  %2724 = select i1 %2722, i64 %2716, i64 %2723
  %2725 = getelementptr inbounds i8, ptr %2714, i64 %2716
  %2726 = load i8, ptr %2725, align 1, !invariant.load !1
  br label %2715

2727:                                             ; preds = %2720
  %2728 = phi i8 [ %2717, %2720 ]
  %2729 = call i64 @llvm.smax.i64(i64 %2707, i64 1)
  br label %2730

2730:                                             ; preds = %2756, %2727
  %2731 = phi i64 [ 1, %2727 ], [ %2739, %2756 ]
  %2732 = phi i8 [ %2728, %2727 ], [ %2769, %2756 ]
  %2733 = icmp slt i64 %2731, %2729
  br i1 %2733, label %2734, label %2735

2734:                                             ; preds = %2730
  br label %2736

2735:                                             ; preds = %2730
  br label %2770

2736:                                             ; preds = %2734
  %2737 = icmp eq i64 %2731, %2729
  %2738 = add i64 %2731, 1
  %2739 = select i1 %2737, i64 %2731, i64 %2738
  %2740 = mul i64 %2731, %2710
  %2741 = add i64 %2740, %2712
  %2742 = add i64 %2741, %2703
  %2743 = getelementptr inbounds i8, ptr %2709, i64 %2742
  br label %2744

2744:                                             ; preds = %2750, %2736
  %2745 = phi i64 [ 0, %2736 ], [ %2753, %2750 ]
  %2746 = phi i8 [ 0, %2736 ], [ %2755, %2750 ]
  %2747 = icmp slt i64 %2745, 1
  br i1 %2747, label %2748, label %2749

2748:                                             ; preds = %2744
  br label %2750

2749:                                             ; preds = %2744
  br label %2756

2750:                                             ; preds = %2748
  %2751 = icmp eq i64 %2745, 1
  %2752 = add i64 %2745, 1
  %2753 = select i1 %2751, i64 %2745, i64 %2752
  %2754 = getelementptr inbounds i8, ptr %2743, i64 %2745
  %2755 = load i8, ptr %2754, align 1, !invariant.load !1
  br label %2744

2756:                                             ; preds = %2749
  %2757 = phi i8 [ %2746, %2749 ]
  %2758 = zext i8 %2732 to i16
  %2759 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2758)
  %2760 = trunc i32 %2759 to i16
  %2761 = bitcast i16 %2760 to half
  %2762 = zext i8 %2757 to i16
  %2763 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2762)
  %2764 = trunc i32 %2763 to i16
  %2765 = bitcast i16 %2764 to half
  %2766 = fadd contract half %2761, %2765
  %2767 = fpext half %2766 to float
  %2768 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2767)
  %2769 = trunc i16 %2768 to i8
  br label %2730

2770:                                             ; preds = %2735
  %2771 = phi i8 [ %2732, %2735 ]
  %2772 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2708, 0
  %2773 = trunc i64 %2705 to i32
  %2774 = mul i32 %2773, 512
  %2775 = trunc i64 %2703 to i32
  %2776 = add i32 %2774, %2775
  %2777 = sext i32 %2776 to i64
  %2778 = getelementptr inbounds i8, ptr %2772, i64 %2777
  store i8 %2771, ptr %2778, align 1
  br label %2897

2779:                                             ; preds = %1484
  %2780 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2781 = load i64, ptr %4, align 8
  %2782 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2783 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2780, 0
  %2784 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2780, 1, 1, 0
  %2785 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2780, 1, 1, 1
  %2786 = mul i64 %1498, %2785
  %2787 = add i64 %2786, %1504
  %2788 = getelementptr inbounds i8, ptr %2783, i64 %2787
  %2789 = load <16 x i8>, ptr %2788, align 16, !invariant.load !1
  %2790 = call i64 @llvm.smax.i64(i64 %2781, i64 1)
  br label %2791

2791:                                             ; preds = %2797, %2779
  %2792 = phi i64 [ 1, %2779 ], [ %2800, %2797 ]
  %2793 = phi <16 x i8> [ %2789, %2779 ], [ %2892, %2797 ]
  %2794 = icmp slt i64 %2792, %2790
  br i1 %2794, label %2795, label %2796

2795:                                             ; preds = %2791
  br label %2797

2796:                                             ; preds = %2791
  br label %2893

2797:                                             ; preds = %2795
  %2798 = icmp eq i64 %2792, %2790
  %2799 = add i64 %2792, 1
  %2800 = select i1 %2798, i64 %2792, i64 %2799
  %2801 = mul i64 %2792, %2784
  %2802 = add i64 %2801, %2786
  %2803 = add i64 %2802, %1504
  %2804 = getelementptr inbounds i8, ptr %2783, i64 %2803
  %2805 = load <16 x i8>, ptr %2804, align 16, !invariant.load !1
  %2806 = bitcast <16 x i8> %2793 to <8 x i16>
  %2807 = extractelement <8 x i16> %2806, i32 0
  %2808 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2807)
  %2809 = insertelement <8 x i32> undef, i32 %2808, i32 0
  %2810 = extractelement <8 x i16> %2806, i32 1
  %2811 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2810)
  %2812 = insertelement <8 x i32> %2809, i32 %2811, i32 1
  %2813 = extractelement <8 x i16> %2806, i32 2
  %2814 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2813)
  %2815 = insertelement <8 x i32> %2812, i32 %2814, i32 2
  %2816 = extractelement <8 x i16> %2806, i32 3
  %2817 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2816)
  %2818 = insertelement <8 x i32> %2815, i32 %2817, i32 3
  %2819 = extractelement <8 x i16> %2806, i32 4
  %2820 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2819)
  %2821 = insertelement <8 x i32> %2818, i32 %2820, i32 4
  %2822 = extractelement <8 x i16> %2806, i32 5
  %2823 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2822)
  %2824 = insertelement <8 x i32> %2821, i32 %2823, i32 5
  %2825 = extractelement <8 x i16> %2806, i32 6
  %2826 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2825)
  %2827 = insertelement <8 x i32> %2824, i32 %2826, i32 6
  %2828 = extractelement <8 x i16> %2806, i32 7
  %2829 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2828)
  %2830 = insertelement <8 x i32> %2827, i32 %2829, i32 7
  %2831 = bitcast <8 x i32> %2830 to <16 x half>
  %2832 = bitcast <16 x i8> %2805 to <8 x i16>
  %2833 = extractelement <8 x i16> %2832, i32 0
  %2834 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2833)
  %2835 = insertelement <8 x i32> undef, i32 %2834, i32 0
  %2836 = extractelement <8 x i16> %2832, i32 1
  %2837 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2836)
  %2838 = insertelement <8 x i32> %2835, i32 %2837, i32 1
  %2839 = extractelement <8 x i16> %2832, i32 2
  %2840 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2839)
  %2841 = insertelement <8 x i32> %2838, i32 %2840, i32 2
  %2842 = extractelement <8 x i16> %2832, i32 3
  %2843 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2842)
  %2844 = insertelement <8 x i32> %2841, i32 %2843, i32 3
  %2845 = extractelement <8 x i16> %2832, i32 4
  %2846 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2845)
  %2847 = insertelement <8 x i32> %2844, i32 %2846, i32 4
  %2848 = extractelement <8 x i16> %2832, i32 5
  %2849 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2848)
  %2850 = insertelement <8 x i32> %2847, i32 %2849, i32 5
  %2851 = extractelement <8 x i16> %2832, i32 6
  %2852 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2851)
  %2853 = insertelement <8 x i32> %2850, i32 %2852, i32 6
  %2854 = extractelement <8 x i16> %2832, i32 7
  %2855 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2854)
  %2856 = insertelement <8 x i32> %2853, i32 %2855, i32 7
  %2857 = bitcast <8 x i32> %2856 to <16 x half>
  %2858 = fadd contract <16 x half> %2831, %2857
  %2859 = fpext <16 x half> %2858 to <16 x float>
  %2860 = extractelement <16 x float> %2859, i32 1
  %2861 = extractelement <16 x float> %2859, i32 0
  %2862 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2860, float %2861)
  %2863 = insertelement <8 x i16> undef, i16 %2862, i32 0
  %2864 = extractelement <16 x float> %2859, i32 3
  %2865 = extractelement <16 x float> %2859, i32 2
  %2866 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2864, float %2865)
  %2867 = insertelement <8 x i16> %2863, i16 %2866, i32 1
  %2868 = extractelement <16 x float> %2859, i32 5
  %2869 = extractelement <16 x float> %2859, i32 4
  %2870 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2868, float %2869)
  %2871 = insertelement <8 x i16> %2867, i16 %2870, i32 2
  %2872 = extractelement <16 x float> %2859, i32 7
  %2873 = extractelement <16 x float> %2859, i32 6
  %2874 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2872, float %2873)
  %2875 = insertelement <8 x i16> %2871, i16 %2874, i32 3
  %2876 = extractelement <16 x float> %2859, i32 9
  %2877 = extractelement <16 x float> %2859, i32 8
  %2878 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2876, float %2877)
  %2879 = insertelement <8 x i16> %2875, i16 %2878, i32 4
  %2880 = extractelement <16 x float> %2859, i32 11
  %2881 = extractelement <16 x float> %2859, i32 10
  %2882 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2880, float %2881)
  %2883 = insertelement <8 x i16> %2879, i16 %2882, i32 5
  %2884 = extractelement <16 x float> %2859, i32 13
  %2885 = extractelement <16 x float> %2859, i32 12
  %2886 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2884, float %2885)
  %2887 = insertelement <8 x i16> %2883, i16 %2886, i32 6
  %2888 = extractelement <16 x float> %2859, i32 15
  %2889 = extractelement <16 x float> %2859, i32 14
  %2890 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2888, float %2889)
  %2891 = insertelement <8 x i16> %2887, i16 %2890, i32 7
  %2892 = bitcast <8 x i16> %2891 to <16 x i8>
  br label %2791

2893:                                             ; preds = %2796
  %2894 = phi <16 x i8> [ %2793, %2796 ]
  %2895 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2782, 0
  %2896 = getelementptr inbounds i8, ptr %2895, i64 %1507
  store <16 x i8> %2894, ptr %2896, align 16
  br label %2897

2897:                                             ; preds = %2893, %2770
  br label %2899

2898:                                             ; preds = %1478
  br label %2899

2899:                                             ; preds = %2898, %2897
  %2900 = add i64 %53, %19
  %2901 = mul i64 %2900, 16
  %2902 = icmp slt i64 %2901, 0
  %2903 = load i64, ptr %20, align 8
  %2904 = icmp slt i64 %2900, %2903
  br i1 %2904, label %2905, label %4319

2905:                                             ; preds = %2899
  %2906 = load { i64, i64 }, ptr %6, align 8
  %2907 = extractvalue { i64, i64 } %2906, 1
  %2908 = icmp eq i64 %2907, 0
  %2909 = select i1 %2908, i64 1, i64 %2907
  %2910 = sdiv i64 %2901, %2909
  %2911 = mul i64 %2910, %2907
  %2912 = sub i64 %2901, %2911
  %2913 = icmp slt i64 %2907, 0
  %2914 = xor i1 %2913, %2902
  %2915 = icmp ne i64 %2912, 0
  %2916 = and i1 %2914, %2915
  %2917 = select i1 %2916, i64 1, i64 0
  %2918 = sub i64 %2910, %2917
  %2919 = select i1 %2908, i64 0, i64 %2918
  %2920 = trunc i64 %2919 to i32
  %2921 = mul i32 %2920, 512
  %2922 = add i64 %2919, 1
  %2923 = select i1 %2916, i64 %2907, i64 0
  %2924 = add i64 %2912, %2923
  %2925 = select i1 %2908, i64 0, i64 %2924
  %2926 = trunc i64 %2925 to i32
  %2927 = add i32 %2921, %2926
  %2928 = sext i32 %2927 to i64
  %2929 = add i64 %2925, 1
  %2930 = add i64 %2925, 16
  %2931 = load i64, ptr %8, align 8
  %2932 = icmp sgt i64 %2930, %2931
  br i1 %2932, label %2933, label %4200

2933:                                             ; preds = %2905
  %2934 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2935 = load i64, ptr %4, align 8
  %2936 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2937 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2934, 0
  %2938 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2934, 1, 1, 0
  %2939 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2934, 1, 1, 1
  %2940 = mul i64 %2919, %2939
  %2941 = add i64 %2940, %2925
  %2942 = getelementptr inbounds i8, ptr %2937, i64 %2941
  br label %2943

2943:                                             ; preds = %2949, %2933
  %2944 = phi i64 [ 0, %2933 ], [ %2952, %2949 ]
  %2945 = phi i8 [ 0, %2933 ], [ %2954, %2949 ]
  %2946 = icmp slt i64 %2944, 1
  br i1 %2946, label %2947, label %2948

2947:                                             ; preds = %2943
  br label %2949

2948:                                             ; preds = %2943
  br label %2955

2949:                                             ; preds = %2947
  %2950 = icmp eq i64 %2944, 1
  %2951 = add i64 %2944, 1
  %2952 = select i1 %2950, i64 %2944, i64 %2951
  %2953 = getelementptr inbounds i8, ptr %2942, i64 %2944
  %2954 = load i8, ptr %2953, align 1, !invariant.load !1
  br label %2943

2955:                                             ; preds = %2948
  %2956 = phi i8 [ %2945, %2948 ]
  %2957 = call i64 @llvm.smax.i64(i64 %2935, i64 1)
  br label %2958

2958:                                             ; preds = %2984, %2955
  %2959 = phi i64 [ 1, %2955 ], [ %2967, %2984 ]
  %2960 = phi i8 [ %2956, %2955 ], [ %2997, %2984 ]
  %2961 = icmp slt i64 %2959, %2957
  br i1 %2961, label %2962, label %2963

2962:                                             ; preds = %2958
  br label %2964

2963:                                             ; preds = %2958
  br label %2998

2964:                                             ; preds = %2962
  %2965 = icmp eq i64 %2959, %2957
  %2966 = add i64 %2959, 1
  %2967 = select i1 %2965, i64 %2959, i64 %2966
  %2968 = mul i64 %2959, %2938
  %2969 = add i64 %2968, %2940
  %2970 = add i64 %2969, %2925
  %2971 = getelementptr inbounds i8, ptr %2937, i64 %2970
  br label %2972

2972:                                             ; preds = %2978, %2964
  %2973 = phi i64 [ 0, %2964 ], [ %2981, %2978 ]
  %2974 = phi i8 [ 0, %2964 ], [ %2983, %2978 ]
  %2975 = icmp slt i64 %2973, 1
  br i1 %2975, label %2976, label %2977

2976:                                             ; preds = %2972
  br label %2978

2977:                                             ; preds = %2972
  br label %2984

2978:                                             ; preds = %2976
  %2979 = icmp eq i64 %2973, 1
  %2980 = add i64 %2973, 1
  %2981 = select i1 %2979, i64 %2973, i64 %2980
  %2982 = getelementptr inbounds i8, ptr %2971, i64 %2973
  %2983 = load i8, ptr %2982, align 1, !invariant.load !1
  br label %2972

2984:                                             ; preds = %2977
  %2985 = phi i8 [ %2974, %2977 ]
  %2986 = zext i8 %2960 to i16
  %2987 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2986)
  %2988 = trunc i32 %2987 to i16
  %2989 = bitcast i16 %2988 to half
  %2990 = zext i8 %2985 to i16
  %2991 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2990)
  %2992 = trunc i32 %2991 to i16
  %2993 = bitcast i16 %2992 to half
  %2994 = fadd contract half %2989, %2993
  %2995 = fpext half %2994 to float
  %2996 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2995)
  %2997 = trunc i16 %2996 to i8
  br label %2958

2998:                                             ; preds = %2963
  %2999 = phi i8 [ %2960, %2963 ]
  %3000 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2936, 0
  %3001 = getelementptr inbounds i8, ptr %3000, i64 %2928
  store i8 %2999, ptr %3001, align 1
  %3002 = load { i64, i64 }, ptr %6, align 8
  %3003 = extractvalue { i64, i64 } %3002, 1
  %3004 = icmp sge i64 %2929, %3003
  %3005 = select i1 %3004, i64 0, i64 %2929
  %3006 = select i1 %3004, i64 %2922, i64 %2919
  %3007 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3008 = load i64, ptr %4, align 8
  %3009 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3010 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3007, 0
  %3011 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3007, 1, 1, 0
  %3012 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3007, 1, 1, 1
  %3013 = mul i64 %3006, %3012
  %3014 = add i64 %3013, %3005
  %3015 = getelementptr inbounds i8, ptr %3010, i64 %3014
  br label %3016

3016:                                             ; preds = %3022, %2998
  %3017 = phi i64 [ 0, %2998 ], [ %3025, %3022 ]
  %3018 = phi i8 [ 0, %2998 ], [ %3027, %3022 ]
  %3019 = icmp slt i64 %3017, 1
  br i1 %3019, label %3020, label %3021

3020:                                             ; preds = %3016
  br label %3022

3021:                                             ; preds = %3016
  br label %3028

3022:                                             ; preds = %3020
  %3023 = icmp eq i64 %3017, 1
  %3024 = add i64 %3017, 1
  %3025 = select i1 %3023, i64 %3017, i64 %3024
  %3026 = getelementptr inbounds i8, ptr %3015, i64 %3017
  %3027 = load i8, ptr %3026, align 1, !invariant.load !1
  br label %3016

3028:                                             ; preds = %3021
  %3029 = phi i8 [ %3018, %3021 ]
  %3030 = call i64 @llvm.smax.i64(i64 %3008, i64 1)
  br label %3031

3031:                                             ; preds = %3057, %3028
  %3032 = phi i64 [ 1, %3028 ], [ %3040, %3057 ]
  %3033 = phi i8 [ %3029, %3028 ], [ %3070, %3057 ]
  %3034 = icmp slt i64 %3032, %3030
  br i1 %3034, label %3035, label %3036

3035:                                             ; preds = %3031
  br label %3037

3036:                                             ; preds = %3031
  br label %3071

3037:                                             ; preds = %3035
  %3038 = icmp eq i64 %3032, %3030
  %3039 = add i64 %3032, 1
  %3040 = select i1 %3038, i64 %3032, i64 %3039
  %3041 = mul i64 %3032, %3011
  %3042 = add i64 %3041, %3013
  %3043 = add i64 %3042, %3005
  %3044 = getelementptr inbounds i8, ptr %3010, i64 %3043
  br label %3045

3045:                                             ; preds = %3051, %3037
  %3046 = phi i64 [ 0, %3037 ], [ %3054, %3051 ]
  %3047 = phi i8 [ 0, %3037 ], [ %3056, %3051 ]
  %3048 = icmp slt i64 %3046, 1
  br i1 %3048, label %3049, label %3050

3049:                                             ; preds = %3045
  br label %3051

3050:                                             ; preds = %3045
  br label %3057

3051:                                             ; preds = %3049
  %3052 = icmp eq i64 %3046, 1
  %3053 = add i64 %3046, 1
  %3054 = select i1 %3052, i64 %3046, i64 %3053
  %3055 = getelementptr inbounds i8, ptr %3044, i64 %3046
  %3056 = load i8, ptr %3055, align 1, !invariant.load !1
  br label %3045

3057:                                             ; preds = %3050
  %3058 = phi i8 [ %3047, %3050 ]
  %3059 = zext i8 %3033 to i16
  %3060 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3059)
  %3061 = trunc i32 %3060 to i16
  %3062 = bitcast i16 %3061 to half
  %3063 = zext i8 %3058 to i16
  %3064 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3063)
  %3065 = trunc i32 %3064 to i16
  %3066 = bitcast i16 %3065 to half
  %3067 = fadd contract half %3062, %3066
  %3068 = fpext half %3067 to float
  %3069 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3068)
  %3070 = trunc i16 %3069 to i8
  br label %3031

3071:                                             ; preds = %3036
  %3072 = phi i8 [ %3033, %3036 ]
  %3073 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3009, 0
  %3074 = trunc i64 %3006 to i32
  %3075 = mul i32 %3074, 512
  %3076 = trunc i64 %3005 to i32
  %3077 = add i32 %3075, %3076
  %3078 = sext i32 %3077 to i64
  %3079 = getelementptr inbounds i8, ptr %3073, i64 %3078
  store i8 %3072, ptr %3079, align 1
  %3080 = load { i64, i64 }, ptr %6, align 8
  %3081 = add i64 %3005, 1
  %3082 = extractvalue { i64, i64 } %3080, 1
  %3083 = icmp sge i64 %3081, %3082
  %3084 = select i1 %3083, i64 0, i64 %3081
  %3085 = add i64 %3006, 1
  %3086 = select i1 %3083, i64 %3085, i64 %3006
  %3087 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3088 = load i64, ptr %4, align 8
  %3089 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3090 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3087, 0
  %3091 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3087, 1, 1, 0
  %3092 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3087, 1, 1, 1
  %3093 = mul i64 %3086, %3092
  %3094 = add i64 %3093, %3084
  %3095 = getelementptr inbounds i8, ptr %3090, i64 %3094
  br label %3096

3096:                                             ; preds = %3102, %3071
  %3097 = phi i64 [ 0, %3071 ], [ %3105, %3102 ]
  %3098 = phi i8 [ 0, %3071 ], [ %3107, %3102 ]
  %3099 = icmp slt i64 %3097, 1
  br i1 %3099, label %3100, label %3101

3100:                                             ; preds = %3096
  br label %3102

3101:                                             ; preds = %3096
  br label %3108

3102:                                             ; preds = %3100
  %3103 = icmp eq i64 %3097, 1
  %3104 = add i64 %3097, 1
  %3105 = select i1 %3103, i64 %3097, i64 %3104
  %3106 = getelementptr inbounds i8, ptr %3095, i64 %3097
  %3107 = load i8, ptr %3106, align 1, !invariant.load !1
  br label %3096

3108:                                             ; preds = %3101
  %3109 = phi i8 [ %3098, %3101 ]
  %3110 = call i64 @llvm.smax.i64(i64 %3088, i64 1)
  br label %3111

3111:                                             ; preds = %3137, %3108
  %3112 = phi i64 [ 1, %3108 ], [ %3120, %3137 ]
  %3113 = phi i8 [ %3109, %3108 ], [ %3150, %3137 ]
  %3114 = icmp slt i64 %3112, %3110
  br i1 %3114, label %3115, label %3116

3115:                                             ; preds = %3111
  br label %3117

3116:                                             ; preds = %3111
  br label %3151

3117:                                             ; preds = %3115
  %3118 = icmp eq i64 %3112, %3110
  %3119 = add i64 %3112, 1
  %3120 = select i1 %3118, i64 %3112, i64 %3119
  %3121 = mul i64 %3112, %3091
  %3122 = add i64 %3121, %3093
  %3123 = add i64 %3122, %3084
  %3124 = getelementptr inbounds i8, ptr %3090, i64 %3123
  br label %3125

3125:                                             ; preds = %3131, %3117
  %3126 = phi i64 [ 0, %3117 ], [ %3134, %3131 ]
  %3127 = phi i8 [ 0, %3117 ], [ %3136, %3131 ]
  %3128 = icmp slt i64 %3126, 1
  br i1 %3128, label %3129, label %3130

3129:                                             ; preds = %3125
  br label %3131

3130:                                             ; preds = %3125
  br label %3137

3131:                                             ; preds = %3129
  %3132 = icmp eq i64 %3126, 1
  %3133 = add i64 %3126, 1
  %3134 = select i1 %3132, i64 %3126, i64 %3133
  %3135 = getelementptr inbounds i8, ptr %3124, i64 %3126
  %3136 = load i8, ptr %3135, align 1, !invariant.load !1
  br label %3125

3137:                                             ; preds = %3130
  %3138 = phi i8 [ %3127, %3130 ]
  %3139 = zext i8 %3113 to i16
  %3140 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3139)
  %3141 = trunc i32 %3140 to i16
  %3142 = bitcast i16 %3141 to half
  %3143 = zext i8 %3138 to i16
  %3144 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3143)
  %3145 = trunc i32 %3144 to i16
  %3146 = bitcast i16 %3145 to half
  %3147 = fadd contract half %3142, %3146
  %3148 = fpext half %3147 to float
  %3149 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3148)
  %3150 = trunc i16 %3149 to i8
  br label %3111

3151:                                             ; preds = %3116
  %3152 = phi i8 [ %3113, %3116 ]
  %3153 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3089, 0
  %3154 = trunc i64 %3086 to i32
  %3155 = mul i32 %3154, 512
  %3156 = trunc i64 %3084 to i32
  %3157 = add i32 %3155, %3156
  %3158 = sext i32 %3157 to i64
  %3159 = getelementptr inbounds i8, ptr %3153, i64 %3158
  store i8 %3152, ptr %3159, align 1
  %3160 = load { i64, i64 }, ptr %6, align 8
  %3161 = add i64 %3084, 1
  %3162 = extractvalue { i64, i64 } %3160, 1
  %3163 = icmp sge i64 %3161, %3162
  %3164 = select i1 %3163, i64 0, i64 %3161
  %3165 = add i64 %3086, 1
  %3166 = select i1 %3163, i64 %3165, i64 %3086
  %3167 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3168 = load i64, ptr %4, align 8
  %3169 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3170 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3167, 0
  %3171 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3167, 1, 1, 0
  %3172 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3167, 1, 1, 1
  %3173 = mul i64 %3166, %3172
  %3174 = add i64 %3173, %3164
  %3175 = getelementptr inbounds i8, ptr %3170, i64 %3174
  br label %3176

3176:                                             ; preds = %3182, %3151
  %3177 = phi i64 [ 0, %3151 ], [ %3185, %3182 ]
  %3178 = phi i8 [ 0, %3151 ], [ %3187, %3182 ]
  %3179 = icmp slt i64 %3177, 1
  br i1 %3179, label %3180, label %3181

3180:                                             ; preds = %3176
  br label %3182

3181:                                             ; preds = %3176
  br label %3188

3182:                                             ; preds = %3180
  %3183 = icmp eq i64 %3177, 1
  %3184 = add i64 %3177, 1
  %3185 = select i1 %3183, i64 %3177, i64 %3184
  %3186 = getelementptr inbounds i8, ptr %3175, i64 %3177
  %3187 = load i8, ptr %3186, align 1, !invariant.load !1
  br label %3176

3188:                                             ; preds = %3181
  %3189 = phi i8 [ %3178, %3181 ]
  %3190 = call i64 @llvm.smax.i64(i64 %3168, i64 1)
  br label %3191

3191:                                             ; preds = %3217, %3188
  %3192 = phi i64 [ 1, %3188 ], [ %3200, %3217 ]
  %3193 = phi i8 [ %3189, %3188 ], [ %3230, %3217 ]
  %3194 = icmp slt i64 %3192, %3190
  br i1 %3194, label %3195, label %3196

3195:                                             ; preds = %3191
  br label %3197

3196:                                             ; preds = %3191
  br label %3231

3197:                                             ; preds = %3195
  %3198 = icmp eq i64 %3192, %3190
  %3199 = add i64 %3192, 1
  %3200 = select i1 %3198, i64 %3192, i64 %3199
  %3201 = mul i64 %3192, %3171
  %3202 = add i64 %3201, %3173
  %3203 = add i64 %3202, %3164
  %3204 = getelementptr inbounds i8, ptr %3170, i64 %3203
  br label %3205

3205:                                             ; preds = %3211, %3197
  %3206 = phi i64 [ 0, %3197 ], [ %3214, %3211 ]
  %3207 = phi i8 [ 0, %3197 ], [ %3216, %3211 ]
  %3208 = icmp slt i64 %3206, 1
  br i1 %3208, label %3209, label %3210

3209:                                             ; preds = %3205
  br label %3211

3210:                                             ; preds = %3205
  br label %3217

3211:                                             ; preds = %3209
  %3212 = icmp eq i64 %3206, 1
  %3213 = add i64 %3206, 1
  %3214 = select i1 %3212, i64 %3206, i64 %3213
  %3215 = getelementptr inbounds i8, ptr %3204, i64 %3206
  %3216 = load i8, ptr %3215, align 1, !invariant.load !1
  br label %3205

3217:                                             ; preds = %3210
  %3218 = phi i8 [ %3207, %3210 ]
  %3219 = zext i8 %3193 to i16
  %3220 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3219)
  %3221 = trunc i32 %3220 to i16
  %3222 = bitcast i16 %3221 to half
  %3223 = zext i8 %3218 to i16
  %3224 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3223)
  %3225 = trunc i32 %3224 to i16
  %3226 = bitcast i16 %3225 to half
  %3227 = fadd contract half %3222, %3226
  %3228 = fpext half %3227 to float
  %3229 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3228)
  %3230 = trunc i16 %3229 to i8
  br label %3191

3231:                                             ; preds = %3196
  %3232 = phi i8 [ %3193, %3196 ]
  %3233 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3169, 0
  %3234 = trunc i64 %3166 to i32
  %3235 = mul i32 %3234, 512
  %3236 = trunc i64 %3164 to i32
  %3237 = add i32 %3235, %3236
  %3238 = sext i32 %3237 to i64
  %3239 = getelementptr inbounds i8, ptr %3233, i64 %3238
  store i8 %3232, ptr %3239, align 1
  %3240 = load { i64, i64 }, ptr %6, align 8
  %3241 = add i64 %3164, 1
  %3242 = extractvalue { i64, i64 } %3240, 1
  %3243 = icmp sge i64 %3241, %3242
  %3244 = select i1 %3243, i64 0, i64 %3241
  %3245 = add i64 %3166, 1
  %3246 = select i1 %3243, i64 %3245, i64 %3166
  %3247 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3248 = load i64, ptr %4, align 8
  %3249 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3250 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3247, 0
  %3251 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3247, 1, 1, 0
  %3252 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3247, 1, 1, 1
  %3253 = mul i64 %3246, %3252
  %3254 = add i64 %3253, %3244
  %3255 = getelementptr inbounds i8, ptr %3250, i64 %3254
  br label %3256

3256:                                             ; preds = %3262, %3231
  %3257 = phi i64 [ 0, %3231 ], [ %3265, %3262 ]
  %3258 = phi i8 [ 0, %3231 ], [ %3267, %3262 ]
  %3259 = icmp slt i64 %3257, 1
  br i1 %3259, label %3260, label %3261

3260:                                             ; preds = %3256
  br label %3262

3261:                                             ; preds = %3256
  br label %3268

3262:                                             ; preds = %3260
  %3263 = icmp eq i64 %3257, 1
  %3264 = add i64 %3257, 1
  %3265 = select i1 %3263, i64 %3257, i64 %3264
  %3266 = getelementptr inbounds i8, ptr %3255, i64 %3257
  %3267 = load i8, ptr %3266, align 1, !invariant.load !1
  br label %3256

3268:                                             ; preds = %3261
  %3269 = phi i8 [ %3258, %3261 ]
  %3270 = call i64 @llvm.smax.i64(i64 %3248, i64 1)
  br label %3271

3271:                                             ; preds = %3297, %3268
  %3272 = phi i64 [ 1, %3268 ], [ %3280, %3297 ]
  %3273 = phi i8 [ %3269, %3268 ], [ %3310, %3297 ]
  %3274 = icmp slt i64 %3272, %3270
  br i1 %3274, label %3275, label %3276

3275:                                             ; preds = %3271
  br label %3277

3276:                                             ; preds = %3271
  br label %3311

3277:                                             ; preds = %3275
  %3278 = icmp eq i64 %3272, %3270
  %3279 = add i64 %3272, 1
  %3280 = select i1 %3278, i64 %3272, i64 %3279
  %3281 = mul i64 %3272, %3251
  %3282 = add i64 %3281, %3253
  %3283 = add i64 %3282, %3244
  %3284 = getelementptr inbounds i8, ptr %3250, i64 %3283
  br label %3285

3285:                                             ; preds = %3291, %3277
  %3286 = phi i64 [ 0, %3277 ], [ %3294, %3291 ]
  %3287 = phi i8 [ 0, %3277 ], [ %3296, %3291 ]
  %3288 = icmp slt i64 %3286, 1
  br i1 %3288, label %3289, label %3290

3289:                                             ; preds = %3285
  br label %3291

3290:                                             ; preds = %3285
  br label %3297

3291:                                             ; preds = %3289
  %3292 = icmp eq i64 %3286, 1
  %3293 = add i64 %3286, 1
  %3294 = select i1 %3292, i64 %3286, i64 %3293
  %3295 = getelementptr inbounds i8, ptr %3284, i64 %3286
  %3296 = load i8, ptr %3295, align 1, !invariant.load !1
  br label %3285

3297:                                             ; preds = %3290
  %3298 = phi i8 [ %3287, %3290 ]
  %3299 = zext i8 %3273 to i16
  %3300 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3299)
  %3301 = trunc i32 %3300 to i16
  %3302 = bitcast i16 %3301 to half
  %3303 = zext i8 %3298 to i16
  %3304 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3303)
  %3305 = trunc i32 %3304 to i16
  %3306 = bitcast i16 %3305 to half
  %3307 = fadd contract half %3302, %3306
  %3308 = fpext half %3307 to float
  %3309 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3308)
  %3310 = trunc i16 %3309 to i8
  br label %3271

3311:                                             ; preds = %3276
  %3312 = phi i8 [ %3273, %3276 ]
  %3313 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3249, 0
  %3314 = trunc i64 %3246 to i32
  %3315 = mul i32 %3314, 512
  %3316 = trunc i64 %3244 to i32
  %3317 = add i32 %3315, %3316
  %3318 = sext i32 %3317 to i64
  %3319 = getelementptr inbounds i8, ptr %3313, i64 %3318
  store i8 %3312, ptr %3319, align 1
  %3320 = load { i64, i64 }, ptr %6, align 8
  %3321 = add i64 %3244, 1
  %3322 = extractvalue { i64, i64 } %3320, 1
  %3323 = icmp sge i64 %3321, %3322
  %3324 = select i1 %3323, i64 0, i64 %3321
  %3325 = add i64 %3246, 1
  %3326 = select i1 %3323, i64 %3325, i64 %3246
  %3327 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3328 = load i64, ptr %4, align 8
  %3329 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3330 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3327, 0
  %3331 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3327, 1, 1, 0
  %3332 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3327, 1, 1, 1
  %3333 = mul i64 %3326, %3332
  %3334 = add i64 %3333, %3324
  %3335 = getelementptr inbounds i8, ptr %3330, i64 %3334
  br label %3336

3336:                                             ; preds = %3342, %3311
  %3337 = phi i64 [ 0, %3311 ], [ %3345, %3342 ]
  %3338 = phi i8 [ 0, %3311 ], [ %3347, %3342 ]
  %3339 = icmp slt i64 %3337, 1
  br i1 %3339, label %3340, label %3341

3340:                                             ; preds = %3336
  br label %3342

3341:                                             ; preds = %3336
  br label %3348

3342:                                             ; preds = %3340
  %3343 = icmp eq i64 %3337, 1
  %3344 = add i64 %3337, 1
  %3345 = select i1 %3343, i64 %3337, i64 %3344
  %3346 = getelementptr inbounds i8, ptr %3335, i64 %3337
  %3347 = load i8, ptr %3346, align 1, !invariant.load !1
  br label %3336

3348:                                             ; preds = %3341
  %3349 = phi i8 [ %3338, %3341 ]
  %3350 = call i64 @llvm.smax.i64(i64 %3328, i64 1)
  br label %3351

3351:                                             ; preds = %3377, %3348
  %3352 = phi i64 [ 1, %3348 ], [ %3360, %3377 ]
  %3353 = phi i8 [ %3349, %3348 ], [ %3390, %3377 ]
  %3354 = icmp slt i64 %3352, %3350
  br i1 %3354, label %3355, label %3356

3355:                                             ; preds = %3351
  br label %3357

3356:                                             ; preds = %3351
  br label %3391

3357:                                             ; preds = %3355
  %3358 = icmp eq i64 %3352, %3350
  %3359 = add i64 %3352, 1
  %3360 = select i1 %3358, i64 %3352, i64 %3359
  %3361 = mul i64 %3352, %3331
  %3362 = add i64 %3361, %3333
  %3363 = add i64 %3362, %3324
  %3364 = getelementptr inbounds i8, ptr %3330, i64 %3363
  br label %3365

3365:                                             ; preds = %3371, %3357
  %3366 = phi i64 [ 0, %3357 ], [ %3374, %3371 ]
  %3367 = phi i8 [ 0, %3357 ], [ %3376, %3371 ]
  %3368 = icmp slt i64 %3366, 1
  br i1 %3368, label %3369, label %3370

3369:                                             ; preds = %3365
  br label %3371

3370:                                             ; preds = %3365
  br label %3377

3371:                                             ; preds = %3369
  %3372 = icmp eq i64 %3366, 1
  %3373 = add i64 %3366, 1
  %3374 = select i1 %3372, i64 %3366, i64 %3373
  %3375 = getelementptr inbounds i8, ptr %3364, i64 %3366
  %3376 = load i8, ptr %3375, align 1, !invariant.load !1
  br label %3365

3377:                                             ; preds = %3370
  %3378 = phi i8 [ %3367, %3370 ]
  %3379 = zext i8 %3353 to i16
  %3380 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3379)
  %3381 = trunc i32 %3380 to i16
  %3382 = bitcast i16 %3381 to half
  %3383 = zext i8 %3378 to i16
  %3384 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3383)
  %3385 = trunc i32 %3384 to i16
  %3386 = bitcast i16 %3385 to half
  %3387 = fadd contract half %3382, %3386
  %3388 = fpext half %3387 to float
  %3389 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3388)
  %3390 = trunc i16 %3389 to i8
  br label %3351

3391:                                             ; preds = %3356
  %3392 = phi i8 [ %3353, %3356 ]
  %3393 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3329, 0
  %3394 = trunc i64 %3326 to i32
  %3395 = mul i32 %3394, 512
  %3396 = trunc i64 %3324 to i32
  %3397 = add i32 %3395, %3396
  %3398 = sext i32 %3397 to i64
  %3399 = getelementptr inbounds i8, ptr %3393, i64 %3398
  store i8 %3392, ptr %3399, align 1
  %3400 = load { i64, i64 }, ptr %6, align 8
  %3401 = add i64 %3324, 1
  %3402 = extractvalue { i64, i64 } %3400, 1
  %3403 = icmp sge i64 %3401, %3402
  %3404 = select i1 %3403, i64 0, i64 %3401
  %3405 = add i64 %3326, 1
  %3406 = select i1 %3403, i64 %3405, i64 %3326
  %3407 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3408 = load i64, ptr %4, align 8
  %3409 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3410 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3407, 0
  %3411 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3407, 1, 1, 0
  %3412 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3407, 1, 1, 1
  %3413 = mul i64 %3406, %3412
  %3414 = add i64 %3413, %3404
  %3415 = getelementptr inbounds i8, ptr %3410, i64 %3414
  br label %3416

3416:                                             ; preds = %3422, %3391
  %3417 = phi i64 [ 0, %3391 ], [ %3425, %3422 ]
  %3418 = phi i8 [ 0, %3391 ], [ %3427, %3422 ]
  %3419 = icmp slt i64 %3417, 1
  br i1 %3419, label %3420, label %3421

3420:                                             ; preds = %3416
  br label %3422

3421:                                             ; preds = %3416
  br label %3428

3422:                                             ; preds = %3420
  %3423 = icmp eq i64 %3417, 1
  %3424 = add i64 %3417, 1
  %3425 = select i1 %3423, i64 %3417, i64 %3424
  %3426 = getelementptr inbounds i8, ptr %3415, i64 %3417
  %3427 = load i8, ptr %3426, align 1, !invariant.load !1
  br label %3416

3428:                                             ; preds = %3421
  %3429 = phi i8 [ %3418, %3421 ]
  %3430 = call i64 @llvm.smax.i64(i64 %3408, i64 1)
  br label %3431

3431:                                             ; preds = %3457, %3428
  %3432 = phi i64 [ 1, %3428 ], [ %3440, %3457 ]
  %3433 = phi i8 [ %3429, %3428 ], [ %3470, %3457 ]
  %3434 = icmp slt i64 %3432, %3430
  br i1 %3434, label %3435, label %3436

3435:                                             ; preds = %3431
  br label %3437

3436:                                             ; preds = %3431
  br label %3471

3437:                                             ; preds = %3435
  %3438 = icmp eq i64 %3432, %3430
  %3439 = add i64 %3432, 1
  %3440 = select i1 %3438, i64 %3432, i64 %3439
  %3441 = mul i64 %3432, %3411
  %3442 = add i64 %3441, %3413
  %3443 = add i64 %3442, %3404
  %3444 = getelementptr inbounds i8, ptr %3410, i64 %3443
  br label %3445

3445:                                             ; preds = %3451, %3437
  %3446 = phi i64 [ 0, %3437 ], [ %3454, %3451 ]
  %3447 = phi i8 [ 0, %3437 ], [ %3456, %3451 ]
  %3448 = icmp slt i64 %3446, 1
  br i1 %3448, label %3449, label %3450

3449:                                             ; preds = %3445
  br label %3451

3450:                                             ; preds = %3445
  br label %3457

3451:                                             ; preds = %3449
  %3452 = icmp eq i64 %3446, 1
  %3453 = add i64 %3446, 1
  %3454 = select i1 %3452, i64 %3446, i64 %3453
  %3455 = getelementptr inbounds i8, ptr %3444, i64 %3446
  %3456 = load i8, ptr %3455, align 1, !invariant.load !1
  br label %3445

3457:                                             ; preds = %3450
  %3458 = phi i8 [ %3447, %3450 ]
  %3459 = zext i8 %3433 to i16
  %3460 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3459)
  %3461 = trunc i32 %3460 to i16
  %3462 = bitcast i16 %3461 to half
  %3463 = zext i8 %3458 to i16
  %3464 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3463)
  %3465 = trunc i32 %3464 to i16
  %3466 = bitcast i16 %3465 to half
  %3467 = fadd contract half %3462, %3466
  %3468 = fpext half %3467 to float
  %3469 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3468)
  %3470 = trunc i16 %3469 to i8
  br label %3431

3471:                                             ; preds = %3436
  %3472 = phi i8 [ %3433, %3436 ]
  %3473 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3409, 0
  %3474 = trunc i64 %3406 to i32
  %3475 = mul i32 %3474, 512
  %3476 = trunc i64 %3404 to i32
  %3477 = add i32 %3475, %3476
  %3478 = sext i32 %3477 to i64
  %3479 = getelementptr inbounds i8, ptr %3473, i64 %3478
  store i8 %3472, ptr %3479, align 1
  %3480 = load { i64, i64 }, ptr %6, align 8
  %3481 = add i64 %3404, 1
  %3482 = extractvalue { i64, i64 } %3480, 1
  %3483 = icmp sge i64 %3481, %3482
  %3484 = select i1 %3483, i64 0, i64 %3481
  %3485 = add i64 %3406, 1
  %3486 = select i1 %3483, i64 %3485, i64 %3406
  %3487 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3488 = load i64, ptr %4, align 8
  %3489 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3490 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3487, 0
  %3491 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3487, 1, 1, 0
  %3492 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3487, 1, 1, 1
  %3493 = mul i64 %3486, %3492
  %3494 = add i64 %3493, %3484
  %3495 = getelementptr inbounds i8, ptr %3490, i64 %3494
  br label %3496

3496:                                             ; preds = %3502, %3471
  %3497 = phi i64 [ 0, %3471 ], [ %3505, %3502 ]
  %3498 = phi i8 [ 0, %3471 ], [ %3507, %3502 ]
  %3499 = icmp slt i64 %3497, 1
  br i1 %3499, label %3500, label %3501

3500:                                             ; preds = %3496
  br label %3502

3501:                                             ; preds = %3496
  br label %3508

3502:                                             ; preds = %3500
  %3503 = icmp eq i64 %3497, 1
  %3504 = add i64 %3497, 1
  %3505 = select i1 %3503, i64 %3497, i64 %3504
  %3506 = getelementptr inbounds i8, ptr %3495, i64 %3497
  %3507 = load i8, ptr %3506, align 1, !invariant.load !1
  br label %3496

3508:                                             ; preds = %3501
  %3509 = phi i8 [ %3498, %3501 ]
  %3510 = call i64 @llvm.smax.i64(i64 %3488, i64 1)
  br label %3511

3511:                                             ; preds = %3537, %3508
  %3512 = phi i64 [ 1, %3508 ], [ %3520, %3537 ]
  %3513 = phi i8 [ %3509, %3508 ], [ %3550, %3537 ]
  %3514 = icmp slt i64 %3512, %3510
  br i1 %3514, label %3515, label %3516

3515:                                             ; preds = %3511
  br label %3517

3516:                                             ; preds = %3511
  br label %3551

3517:                                             ; preds = %3515
  %3518 = icmp eq i64 %3512, %3510
  %3519 = add i64 %3512, 1
  %3520 = select i1 %3518, i64 %3512, i64 %3519
  %3521 = mul i64 %3512, %3491
  %3522 = add i64 %3521, %3493
  %3523 = add i64 %3522, %3484
  %3524 = getelementptr inbounds i8, ptr %3490, i64 %3523
  br label %3525

3525:                                             ; preds = %3531, %3517
  %3526 = phi i64 [ 0, %3517 ], [ %3534, %3531 ]
  %3527 = phi i8 [ 0, %3517 ], [ %3536, %3531 ]
  %3528 = icmp slt i64 %3526, 1
  br i1 %3528, label %3529, label %3530

3529:                                             ; preds = %3525
  br label %3531

3530:                                             ; preds = %3525
  br label %3537

3531:                                             ; preds = %3529
  %3532 = icmp eq i64 %3526, 1
  %3533 = add i64 %3526, 1
  %3534 = select i1 %3532, i64 %3526, i64 %3533
  %3535 = getelementptr inbounds i8, ptr %3524, i64 %3526
  %3536 = load i8, ptr %3535, align 1, !invariant.load !1
  br label %3525

3537:                                             ; preds = %3530
  %3538 = phi i8 [ %3527, %3530 ]
  %3539 = zext i8 %3513 to i16
  %3540 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3539)
  %3541 = trunc i32 %3540 to i16
  %3542 = bitcast i16 %3541 to half
  %3543 = zext i8 %3538 to i16
  %3544 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3543)
  %3545 = trunc i32 %3544 to i16
  %3546 = bitcast i16 %3545 to half
  %3547 = fadd contract half %3542, %3546
  %3548 = fpext half %3547 to float
  %3549 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3548)
  %3550 = trunc i16 %3549 to i8
  br label %3511

3551:                                             ; preds = %3516
  %3552 = phi i8 [ %3513, %3516 ]
  %3553 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3489, 0
  %3554 = trunc i64 %3486 to i32
  %3555 = mul i32 %3554, 512
  %3556 = trunc i64 %3484 to i32
  %3557 = add i32 %3555, %3556
  %3558 = sext i32 %3557 to i64
  %3559 = getelementptr inbounds i8, ptr %3553, i64 %3558
  store i8 %3552, ptr %3559, align 1
  %3560 = load { i64, i64 }, ptr %6, align 8
  %3561 = add i64 %3484, 1
  %3562 = extractvalue { i64, i64 } %3560, 1
  %3563 = icmp sge i64 %3561, %3562
  %3564 = select i1 %3563, i64 0, i64 %3561
  %3565 = add i64 %3486, 1
  %3566 = select i1 %3563, i64 %3565, i64 %3486
  %3567 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3568 = load i64, ptr %4, align 8
  %3569 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3570 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3567, 0
  %3571 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3567, 1, 1, 0
  %3572 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3567, 1, 1, 1
  %3573 = mul i64 %3566, %3572
  %3574 = add i64 %3573, %3564
  %3575 = getelementptr inbounds i8, ptr %3570, i64 %3574
  br label %3576

3576:                                             ; preds = %3582, %3551
  %3577 = phi i64 [ 0, %3551 ], [ %3585, %3582 ]
  %3578 = phi i8 [ 0, %3551 ], [ %3587, %3582 ]
  %3579 = icmp slt i64 %3577, 1
  br i1 %3579, label %3580, label %3581

3580:                                             ; preds = %3576
  br label %3582

3581:                                             ; preds = %3576
  br label %3588

3582:                                             ; preds = %3580
  %3583 = icmp eq i64 %3577, 1
  %3584 = add i64 %3577, 1
  %3585 = select i1 %3583, i64 %3577, i64 %3584
  %3586 = getelementptr inbounds i8, ptr %3575, i64 %3577
  %3587 = load i8, ptr %3586, align 1, !invariant.load !1
  br label %3576

3588:                                             ; preds = %3581
  %3589 = phi i8 [ %3578, %3581 ]
  %3590 = call i64 @llvm.smax.i64(i64 %3568, i64 1)
  br label %3591

3591:                                             ; preds = %3617, %3588
  %3592 = phi i64 [ 1, %3588 ], [ %3600, %3617 ]
  %3593 = phi i8 [ %3589, %3588 ], [ %3630, %3617 ]
  %3594 = icmp slt i64 %3592, %3590
  br i1 %3594, label %3595, label %3596

3595:                                             ; preds = %3591
  br label %3597

3596:                                             ; preds = %3591
  br label %3631

3597:                                             ; preds = %3595
  %3598 = icmp eq i64 %3592, %3590
  %3599 = add i64 %3592, 1
  %3600 = select i1 %3598, i64 %3592, i64 %3599
  %3601 = mul i64 %3592, %3571
  %3602 = add i64 %3601, %3573
  %3603 = add i64 %3602, %3564
  %3604 = getelementptr inbounds i8, ptr %3570, i64 %3603
  br label %3605

3605:                                             ; preds = %3611, %3597
  %3606 = phi i64 [ 0, %3597 ], [ %3614, %3611 ]
  %3607 = phi i8 [ 0, %3597 ], [ %3616, %3611 ]
  %3608 = icmp slt i64 %3606, 1
  br i1 %3608, label %3609, label %3610

3609:                                             ; preds = %3605
  br label %3611

3610:                                             ; preds = %3605
  br label %3617

3611:                                             ; preds = %3609
  %3612 = icmp eq i64 %3606, 1
  %3613 = add i64 %3606, 1
  %3614 = select i1 %3612, i64 %3606, i64 %3613
  %3615 = getelementptr inbounds i8, ptr %3604, i64 %3606
  %3616 = load i8, ptr %3615, align 1, !invariant.load !1
  br label %3605

3617:                                             ; preds = %3610
  %3618 = phi i8 [ %3607, %3610 ]
  %3619 = zext i8 %3593 to i16
  %3620 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3619)
  %3621 = trunc i32 %3620 to i16
  %3622 = bitcast i16 %3621 to half
  %3623 = zext i8 %3618 to i16
  %3624 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3623)
  %3625 = trunc i32 %3624 to i16
  %3626 = bitcast i16 %3625 to half
  %3627 = fadd contract half %3622, %3626
  %3628 = fpext half %3627 to float
  %3629 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3628)
  %3630 = trunc i16 %3629 to i8
  br label %3591

3631:                                             ; preds = %3596
  %3632 = phi i8 [ %3593, %3596 ]
  %3633 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3569, 0
  %3634 = trunc i64 %3566 to i32
  %3635 = mul i32 %3634, 512
  %3636 = trunc i64 %3564 to i32
  %3637 = add i32 %3635, %3636
  %3638 = sext i32 %3637 to i64
  %3639 = getelementptr inbounds i8, ptr %3633, i64 %3638
  store i8 %3632, ptr %3639, align 1
  %3640 = load { i64, i64 }, ptr %6, align 8
  %3641 = add i64 %3564, 1
  %3642 = extractvalue { i64, i64 } %3640, 1
  %3643 = icmp sge i64 %3641, %3642
  %3644 = select i1 %3643, i64 0, i64 %3641
  %3645 = add i64 %3566, 1
  %3646 = select i1 %3643, i64 %3645, i64 %3566
  %3647 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3648 = load i64, ptr %4, align 8
  %3649 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3650 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3647, 0
  %3651 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3647, 1, 1, 0
  %3652 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3647, 1, 1, 1
  %3653 = mul i64 %3646, %3652
  %3654 = add i64 %3653, %3644
  %3655 = getelementptr inbounds i8, ptr %3650, i64 %3654
  br label %3656

3656:                                             ; preds = %3662, %3631
  %3657 = phi i64 [ 0, %3631 ], [ %3665, %3662 ]
  %3658 = phi i8 [ 0, %3631 ], [ %3667, %3662 ]
  %3659 = icmp slt i64 %3657, 1
  br i1 %3659, label %3660, label %3661

3660:                                             ; preds = %3656
  br label %3662

3661:                                             ; preds = %3656
  br label %3668

3662:                                             ; preds = %3660
  %3663 = icmp eq i64 %3657, 1
  %3664 = add i64 %3657, 1
  %3665 = select i1 %3663, i64 %3657, i64 %3664
  %3666 = getelementptr inbounds i8, ptr %3655, i64 %3657
  %3667 = load i8, ptr %3666, align 1, !invariant.load !1
  br label %3656

3668:                                             ; preds = %3661
  %3669 = phi i8 [ %3658, %3661 ]
  %3670 = call i64 @llvm.smax.i64(i64 %3648, i64 1)
  br label %3671

3671:                                             ; preds = %3697, %3668
  %3672 = phi i64 [ 1, %3668 ], [ %3680, %3697 ]
  %3673 = phi i8 [ %3669, %3668 ], [ %3710, %3697 ]
  %3674 = icmp slt i64 %3672, %3670
  br i1 %3674, label %3675, label %3676

3675:                                             ; preds = %3671
  br label %3677

3676:                                             ; preds = %3671
  br label %3711

3677:                                             ; preds = %3675
  %3678 = icmp eq i64 %3672, %3670
  %3679 = add i64 %3672, 1
  %3680 = select i1 %3678, i64 %3672, i64 %3679
  %3681 = mul i64 %3672, %3651
  %3682 = add i64 %3681, %3653
  %3683 = add i64 %3682, %3644
  %3684 = getelementptr inbounds i8, ptr %3650, i64 %3683
  br label %3685

3685:                                             ; preds = %3691, %3677
  %3686 = phi i64 [ 0, %3677 ], [ %3694, %3691 ]
  %3687 = phi i8 [ 0, %3677 ], [ %3696, %3691 ]
  %3688 = icmp slt i64 %3686, 1
  br i1 %3688, label %3689, label %3690

3689:                                             ; preds = %3685
  br label %3691

3690:                                             ; preds = %3685
  br label %3697

3691:                                             ; preds = %3689
  %3692 = icmp eq i64 %3686, 1
  %3693 = add i64 %3686, 1
  %3694 = select i1 %3692, i64 %3686, i64 %3693
  %3695 = getelementptr inbounds i8, ptr %3684, i64 %3686
  %3696 = load i8, ptr %3695, align 1, !invariant.load !1
  br label %3685

3697:                                             ; preds = %3690
  %3698 = phi i8 [ %3687, %3690 ]
  %3699 = zext i8 %3673 to i16
  %3700 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3699)
  %3701 = trunc i32 %3700 to i16
  %3702 = bitcast i16 %3701 to half
  %3703 = zext i8 %3698 to i16
  %3704 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3703)
  %3705 = trunc i32 %3704 to i16
  %3706 = bitcast i16 %3705 to half
  %3707 = fadd contract half %3702, %3706
  %3708 = fpext half %3707 to float
  %3709 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3708)
  %3710 = trunc i16 %3709 to i8
  br label %3671

3711:                                             ; preds = %3676
  %3712 = phi i8 [ %3673, %3676 ]
  %3713 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3649, 0
  %3714 = trunc i64 %3646 to i32
  %3715 = mul i32 %3714, 512
  %3716 = trunc i64 %3644 to i32
  %3717 = add i32 %3715, %3716
  %3718 = sext i32 %3717 to i64
  %3719 = getelementptr inbounds i8, ptr %3713, i64 %3718
  store i8 %3712, ptr %3719, align 1
  %3720 = load { i64, i64 }, ptr %6, align 8
  %3721 = add i64 %3644, 1
  %3722 = extractvalue { i64, i64 } %3720, 1
  %3723 = icmp sge i64 %3721, %3722
  %3724 = select i1 %3723, i64 0, i64 %3721
  %3725 = add i64 %3646, 1
  %3726 = select i1 %3723, i64 %3725, i64 %3646
  %3727 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3728 = load i64, ptr %4, align 8
  %3729 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3730 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3727, 0
  %3731 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3727, 1, 1, 0
  %3732 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3727, 1, 1, 1
  %3733 = mul i64 %3726, %3732
  %3734 = add i64 %3733, %3724
  %3735 = getelementptr inbounds i8, ptr %3730, i64 %3734
  br label %3736

3736:                                             ; preds = %3742, %3711
  %3737 = phi i64 [ 0, %3711 ], [ %3745, %3742 ]
  %3738 = phi i8 [ 0, %3711 ], [ %3747, %3742 ]
  %3739 = icmp slt i64 %3737, 1
  br i1 %3739, label %3740, label %3741

3740:                                             ; preds = %3736
  br label %3742

3741:                                             ; preds = %3736
  br label %3748

3742:                                             ; preds = %3740
  %3743 = icmp eq i64 %3737, 1
  %3744 = add i64 %3737, 1
  %3745 = select i1 %3743, i64 %3737, i64 %3744
  %3746 = getelementptr inbounds i8, ptr %3735, i64 %3737
  %3747 = load i8, ptr %3746, align 1, !invariant.load !1
  br label %3736

3748:                                             ; preds = %3741
  %3749 = phi i8 [ %3738, %3741 ]
  %3750 = call i64 @llvm.smax.i64(i64 %3728, i64 1)
  br label %3751

3751:                                             ; preds = %3777, %3748
  %3752 = phi i64 [ 1, %3748 ], [ %3760, %3777 ]
  %3753 = phi i8 [ %3749, %3748 ], [ %3790, %3777 ]
  %3754 = icmp slt i64 %3752, %3750
  br i1 %3754, label %3755, label %3756

3755:                                             ; preds = %3751
  br label %3757

3756:                                             ; preds = %3751
  br label %3791

3757:                                             ; preds = %3755
  %3758 = icmp eq i64 %3752, %3750
  %3759 = add i64 %3752, 1
  %3760 = select i1 %3758, i64 %3752, i64 %3759
  %3761 = mul i64 %3752, %3731
  %3762 = add i64 %3761, %3733
  %3763 = add i64 %3762, %3724
  %3764 = getelementptr inbounds i8, ptr %3730, i64 %3763
  br label %3765

3765:                                             ; preds = %3771, %3757
  %3766 = phi i64 [ 0, %3757 ], [ %3774, %3771 ]
  %3767 = phi i8 [ 0, %3757 ], [ %3776, %3771 ]
  %3768 = icmp slt i64 %3766, 1
  br i1 %3768, label %3769, label %3770

3769:                                             ; preds = %3765
  br label %3771

3770:                                             ; preds = %3765
  br label %3777

3771:                                             ; preds = %3769
  %3772 = icmp eq i64 %3766, 1
  %3773 = add i64 %3766, 1
  %3774 = select i1 %3772, i64 %3766, i64 %3773
  %3775 = getelementptr inbounds i8, ptr %3764, i64 %3766
  %3776 = load i8, ptr %3775, align 1, !invariant.load !1
  br label %3765

3777:                                             ; preds = %3770
  %3778 = phi i8 [ %3767, %3770 ]
  %3779 = zext i8 %3753 to i16
  %3780 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3779)
  %3781 = trunc i32 %3780 to i16
  %3782 = bitcast i16 %3781 to half
  %3783 = zext i8 %3778 to i16
  %3784 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3783)
  %3785 = trunc i32 %3784 to i16
  %3786 = bitcast i16 %3785 to half
  %3787 = fadd contract half %3782, %3786
  %3788 = fpext half %3787 to float
  %3789 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3788)
  %3790 = trunc i16 %3789 to i8
  br label %3751

3791:                                             ; preds = %3756
  %3792 = phi i8 [ %3753, %3756 ]
  %3793 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3729, 0
  %3794 = trunc i64 %3726 to i32
  %3795 = mul i32 %3794, 512
  %3796 = trunc i64 %3724 to i32
  %3797 = add i32 %3795, %3796
  %3798 = sext i32 %3797 to i64
  %3799 = getelementptr inbounds i8, ptr %3793, i64 %3798
  store i8 %3792, ptr %3799, align 1
  %3800 = load { i64, i64 }, ptr %6, align 8
  %3801 = add i64 %3724, 1
  %3802 = extractvalue { i64, i64 } %3800, 1
  %3803 = icmp sge i64 %3801, %3802
  %3804 = select i1 %3803, i64 0, i64 %3801
  %3805 = add i64 %3726, 1
  %3806 = select i1 %3803, i64 %3805, i64 %3726
  %3807 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3808 = load i64, ptr %4, align 8
  %3809 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3810 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3807, 0
  %3811 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3807, 1, 1, 0
  %3812 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3807, 1, 1, 1
  %3813 = mul i64 %3806, %3812
  %3814 = add i64 %3813, %3804
  %3815 = getelementptr inbounds i8, ptr %3810, i64 %3814
  br label %3816

3816:                                             ; preds = %3822, %3791
  %3817 = phi i64 [ 0, %3791 ], [ %3825, %3822 ]
  %3818 = phi i8 [ 0, %3791 ], [ %3827, %3822 ]
  %3819 = icmp slt i64 %3817, 1
  br i1 %3819, label %3820, label %3821

3820:                                             ; preds = %3816
  br label %3822

3821:                                             ; preds = %3816
  br label %3828

3822:                                             ; preds = %3820
  %3823 = icmp eq i64 %3817, 1
  %3824 = add i64 %3817, 1
  %3825 = select i1 %3823, i64 %3817, i64 %3824
  %3826 = getelementptr inbounds i8, ptr %3815, i64 %3817
  %3827 = load i8, ptr %3826, align 1, !invariant.load !1
  br label %3816

3828:                                             ; preds = %3821
  %3829 = phi i8 [ %3818, %3821 ]
  %3830 = call i64 @llvm.smax.i64(i64 %3808, i64 1)
  br label %3831

3831:                                             ; preds = %3857, %3828
  %3832 = phi i64 [ 1, %3828 ], [ %3840, %3857 ]
  %3833 = phi i8 [ %3829, %3828 ], [ %3870, %3857 ]
  %3834 = icmp slt i64 %3832, %3830
  br i1 %3834, label %3835, label %3836

3835:                                             ; preds = %3831
  br label %3837

3836:                                             ; preds = %3831
  br label %3871

3837:                                             ; preds = %3835
  %3838 = icmp eq i64 %3832, %3830
  %3839 = add i64 %3832, 1
  %3840 = select i1 %3838, i64 %3832, i64 %3839
  %3841 = mul i64 %3832, %3811
  %3842 = add i64 %3841, %3813
  %3843 = add i64 %3842, %3804
  %3844 = getelementptr inbounds i8, ptr %3810, i64 %3843
  br label %3845

3845:                                             ; preds = %3851, %3837
  %3846 = phi i64 [ 0, %3837 ], [ %3854, %3851 ]
  %3847 = phi i8 [ 0, %3837 ], [ %3856, %3851 ]
  %3848 = icmp slt i64 %3846, 1
  br i1 %3848, label %3849, label %3850

3849:                                             ; preds = %3845
  br label %3851

3850:                                             ; preds = %3845
  br label %3857

3851:                                             ; preds = %3849
  %3852 = icmp eq i64 %3846, 1
  %3853 = add i64 %3846, 1
  %3854 = select i1 %3852, i64 %3846, i64 %3853
  %3855 = getelementptr inbounds i8, ptr %3844, i64 %3846
  %3856 = load i8, ptr %3855, align 1, !invariant.load !1
  br label %3845

3857:                                             ; preds = %3850
  %3858 = phi i8 [ %3847, %3850 ]
  %3859 = zext i8 %3833 to i16
  %3860 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3859)
  %3861 = trunc i32 %3860 to i16
  %3862 = bitcast i16 %3861 to half
  %3863 = zext i8 %3858 to i16
  %3864 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3863)
  %3865 = trunc i32 %3864 to i16
  %3866 = bitcast i16 %3865 to half
  %3867 = fadd contract half %3862, %3866
  %3868 = fpext half %3867 to float
  %3869 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3868)
  %3870 = trunc i16 %3869 to i8
  br label %3831

3871:                                             ; preds = %3836
  %3872 = phi i8 [ %3833, %3836 ]
  %3873 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3809, 0
  %3874 = trunc i64 %3806 to i32
  %3875 = mul i32 %3874, 512
  %3876 = trunc i64 %3804 to i32
  %3877 = add i32 %3875, %3876
  %3878 = sext i32 %3877 to i64
  %3879 = getelementptr inbounds i8, ptr %3873, i64 %3878
  store i8 %3872, ptr %3879, align 1
  %3880 = load { i64, i64 }, ptr %6, align 8
  %3881 = add i64 %3804, 1
  %3882 = extractvalue { i64, i64 } %3880, 1
  %3883 = icmp sge i64 %3881, %3882
  %3884 = select i1 %3883, i64 0, i64 %3881
  %3885 = add i64 %3806, 1
  %3886 = select i1 %3883, i64 %3885, i64 %3806
  %3887 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3888 = load i64, ptr %4, align 8
  %3889 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3890 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3887, 0
  %3891 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3887, 1, 1, 0
  %3892 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3887, 1, 1, 1
  %3893 = mul i64 %3886, %3892
  %3894 = add i64 %3893, %3884
  %3895 = getelementptr inbounds i8, ptr %3890, i64 %3894
  br label %3896

3896:                                             ; preds = %3902, %3871
  %3897 = phi i64 [ 0, %3871 ], [ %3905, %3902 ]
  %3898 = phi i8 [ 0, %3871 ], [ %3907, %3902 ]
  %3899 = icmp slt i64 %3897, 1
  br i1 %3899, label %3900, label %3901

3900:                                             ; preds = %3896
  br label %3902

3901:                                             ; preds = %3896
  br label %3908

3902:                                             ; preds = %3900
  %3903 = icmp eq i64 %3897, 1
  %3904 = add i64 %3897, 1
  %3905 = select i1 %3903, i64 %3897, i64 %3904
  %3906 = getelementptr inbounds i8, ptr %3895, i64 %3897
  %3907 = load i8, ptr %3906, align 1, !invariant.load !1
  br label %3896

3908:                                             ; preds = %3901
  %3909 = phi i8 [ %3898, %3901 ]
  %3910 = call i64 @llvm.smax.i64(i64 %3888, i64 1)
  br label %3911

3911:                                             ; preds = %3937, %3908
  %3912 = phi i64 [ 1, %3908 ], [ %3920, %3937 ]
  %3913 = phi i8 [ %3909, %3908 ], [ %3950, %3937 ]
  %3914 = icmp slt i64 %3912, %3910
  br i1 %3914, label %3915, label %3916

3915:                                             ; preds = %3911
  br label %3917

3916:                                             ; preds = %3911
  br label %3951

3917:                                             ; preds = %3915
  %3918 = icmp eq i64 %3912, %3910
  %3919 = add i64 %3912, 1
  %3920 = select i1 %3918, i64 %3912, i64 %3919
  %3921 = mul i64 %3912, %3891
  %3922 = add i64 %3921, %3893
  %3923 = add i64 %3922, %3884
  %3924 = getelementptr inbounds i8, ptr %3890, i64 %3923
  br label %3925

3925:                                             ; preds = %3931, %3917
  %3926 = phi i64 [ 0, %3917 ], [ %3934, %3931 ]
  %3927 = phi i8 [ 0, %3917 ], [ %3936, %3931 ]
  %3928 = icmp slt i64 %3926, 1
  br i1 %3928, label %3929, label %3930

3929:                                             ; preds = %3925
  br label %3931

3930:                                             ; preds = %3925
  br label %3937

3931:                                             ; preds = %3929
  %3932 = icmp eq i64 %3926, 1
  %3933 = add i64 %3926, 1
  %3934 = select i1 %3932, i64 %3926, i64 %3933
  %3935 = getelementptr inbounds i8, ptr %3924, i64 %3926
  %3936 = load i8, ptr %3935, align 1, !invariant.load !1
  br label %3925

3937:                                             ; preds = %3930
  %3938 = phi i8 [ %3927, %3930 ]
  %3939 = zext i8 %3913 to i16
  %3940 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3939)
  %3941 = trunc i32 %3940 to i16
  %3942 = bitcast i16 %3941 to half
  %3943 = zext i8 %3938 to i16
  %3944 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3943)
  %3945 = trunc i32 %3944 to i16
  %3946 = bitcast i16 %3945 to half
  %3947 = fadd contract half %3942, %3946
  %3948 = fpext half %3947 to float
  %3949 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3948)
  %3950 = trunc i16 %3949 to i8
  br label %3911

3951:                                             ; preds = %3916
  %3952 = phi i8 [ %3913, %3916 ]
  %3953 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3889, 0
  %3954 = trunc i64 %3886 to i32
  %3955 = mul i32 %3954, 512
  %3956 = trunc i64 %3884 to i32
  %3957 = add i32 %3955, %3956
  %3958 = sext i32 %3957 to i64
  %3959 = getelementptr inbounds i8, ptr %3953, i64 %3958
  store i8 %3952, ptr %3959, align 1
  %3960 = load { i64, i64 }, ptr %6, align 8
  %3961 = add i64 %3884, 1
  %3962 = extractvalue { i64, i64 } %3960, 1
  %3963 = icmp sge i64 %3961, %3962
  %3964 = select i1 %3963, i64 0, i64 %3961
  %3965 = add i64 %3886, 1
  %3966 = select i1 %3963, i64 %3965, i64 %3886
  %3967 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3968 = load i64, ptr %4, align 8
  %3969 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3970 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3967, 0
  %3971 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3967, 1, 1, 0
  %3972 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3967, 1, 1, 1
  %3973 = mul i64 %3966, %3972
  %3974 = add i64 %3973, %3964
  %3975 = getelementptr inbounds i8, ptr %3970, i64 %3974
  br label %3976

3976:                                             ; preds = %3982, %3951
  %3977 = phi i64 [ 0, %3951 ], [ %3985, %3982 ]
  %3978 = phi i8 [ 0, %3951 ], [ %3987, %3982 ]
  %3979 = icmp slt i64 %3977, 1
  br i1 %3979, label %3980, label %3981

3980:                                             ; preds = %3976
  br label %3982

3981:                                             ; preds = %3976
  br label %3988

3982:                                             ; preds = %3980
  %3983 = icmp eq i64 %3977, 1
  %3984 = add i64 %3977, 1
  %3985 = select i1 %3983, i64 %3977, i64 %3984
  %3986 = getelementptr inbounds i8, ptr %3975, i64 %3977
  %3987 = load i8, ptr %3986, align 1, !invariant.load !1
  br label %3976

3988:                                             ; preds = %3981
  %3989 = phi i8 [ %3978, %3981 ]
  %3990 = call i64 @llvm.smax.i64(i64 %3968, i64 1)
  br label %3991

3991:                                             ; preds = %4017, %3988
  %3992 = phi i64 [ 1, %3988 ], [ %4000, %4017 ]
  %3993 = phi i8 [ %3989, %3988 ], [ %4030, %4017 ]
  %3994 = icmp slt i64 %3992, %3990
  br i1 %3994, label %3995, label %3996

3995:                                             ; preds = %3991
  br label %3997

3996:                                             ; preds = %3991
  br label %4031

3997:                                             ; preds = %3995
  %3998 = icmp eq i64 %3992, %3990
  %3999 = add i64 %3992, 1
  %4000 = select i1 %3998, i64 %3992, i64 %3999
  %4001 = mul i64 %3992, %3971
  %4002 = add i64 %4001, %3973
  %4003 = add i64 %4002, %3964
  %4004 = getelementptr inbounds i8, ptr %3970, i64 %4003
  br label %4005

4005:                                             ; preds = %4011, %3997
  %4006 = phi i64 [ 0, %3997 ], [ %4014, %4011 ]
  %4007 = phi i8 [ 0, %3997 ], [ %4016, %4011 ]
  %4008 = icmp slt i64 %4006, 1
  br i1 %4008, label %4009, label %4010

4009:                                             ; preds = %4005
  br label %4011

4010:                                             ; preds = %4005
  br label %4017

4011:                                             ; preds = %4009
  %4012 = icmp eq i64 %4006, 1
  %4013 = add i64 %4006, 1
  %4014 = select i1 %4012, i64 %4006, i64 %4013
  %4015 = getelementptr inbounds i8, ptr %4004, i64 %4006
  %4016 = load i8, ptr %4015, align 1, !invariant.load !1
  br label %4005

4017:                                             ; preds = %4010
  %4018 = phi i8 [ %4007, %4010 ]
  %4019 = zext i8 %3993 to i16
  %4020 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4019)
  %4021 = trunc i32 %4020 to i16
  %4022 = bitcast i16 %4021 to half
  %4023 = zext i8 %4018 to i16
  %4024 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4023)
  %4025 = trunc i32 %4024 to i16
  %4026 = bitcast i16 %4025 to half
  %4027 = fadd contract half %4022, %4026
  %4028 = fpext half %4027 to float
  %4029 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4028)
  %4030 = trunc i16 %4029 to i8
  br label %3991

4031:                                             ; preds = %3996
  %4032 = phi i8 [ %3993, %3996 ]
  %4033 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3969, 0
  %4034 = trunc i64 %3966 to i32
  %4035 = mul i32 %4034, 512
  %4036 = trunc i64 %3964 to i32
  %4037 = add i32 %4035, %4036
  %4038 = sext i32 %4037 to i64
  %4039 = getelementptr inbounds i8, ptr %4033, i64 %4038
  store i8 %4032, ptr %4039, align 1
  %4040 = load { i64, i64 }, ptr %6, align 8
  %4041 = add i64 %3964, 1
  %4042 = extractvalue { i64, i64 } %4040, 1
  %4043 = icmp sge i64 %4041, %4042
  %4044 = select i1 %4043, i64 0, i64 %4041
  %4045 = add i64 %3966, 1
  %4046 = select i1 %4043, i64 %4045, i64 %3966
  %4047 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4048 = load i64, ptr %4, align 8
  %4049 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4050 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4047, 0
  %4051 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4047, 1, 1, 0
  %4052 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4047, 1, 1, 1
  %4053 = mul i64 %4046, %4052
  %4054 = add i64 %4053, %4044
  %4055 = getelementptr inbounds i8, ptr %4050, i64 %4054
  br label %4056

4056:                                             ; preds = %4062, %4031
  %4057 = phi i64 [ 0, %4031 ], [ %4065, %4062 ]
  %4058 = phi i8 [ 0, %4031 ], [ %4067, %4062 ]
  %4059 = icmp slt i64 %4057, 1
  br i1 %4059, label %4060, label %4061

4060:                                             ; preds = %4056
  br label %4062

4061:                                             ; preds = %4056
  br label %4068

4062:                                             ; preds = %4060
  %4063 = icmp eq i64 %4057, 1
  %4064 = add i64 %4057, 1
  %4065 = select i1 %4063, i64 %4057, i64 %4064
  %4066 = getelementptr inbounds i8, ptr %4055, i64 %4057
  %4067 = load i8, ptr %4066, align 1, !invariant.load !1
  br label %4056

4068:                                             ; preds = %4061
  %4069 = phi i8 [ %4058, %4061 ]
  %4070 = call i64 @llvm.smax.i64(i64 %4048, i64 1)
  br label %4071

4071:                                             ; preds = %4097, %4068
  %4072 = phi i64 [ 1, %4068 ], [ %4080, %4097 ]
  %4073 = phi i8 [ %4069, %4068 ], [ %4110, %4097 ]
  %4074 = icmp slt i64 %4072, %4070
  br i1 %4074, label %4075, label %4076

4075:                                             ; preds = %4071
  br label %4077

4076:                                             ; preds = %4071
  br label %4111

4077:                                             ; preds = %4075
  %4078 = icmp eq i64 %4072, %4070
  %4079 = add i64 %4072, 1
  %4080 = select i1 %4078, i64 %4072, i64 %4079
  %4081 = mul i64 %4072, %4051
  %4082 = add i64 %4081, %4053
  %4083 = add i64 %4082, %4044
  %4084 = getelementptr inbounds i8, ptr %4050, i64 %4083
  br label %4085

4085:                                             ; preds = %4091, %4077
  %4086 = phi i64 [ 0, %4077 ], [ %4094, %4091 ]
  %4087 = phi i8 [ 0, %4077 ], [ %4096, %4091 ]
  %4088 = icmp slt i64 %4086, 1
  br i1 %4088, label %4089, label %4090

4089:                                             ; preds = %4085
  br label %4091

4090:                                             ; preds = %4085
  br label %4097

4091:                                             ; preds = %4089
  %4092 = icmp eq i64 %4086, 1
  %4093 = add i64 %4086, 1
  %4094 = select i1 %4092, i64 %4086, i64 %4093
  %4095 = getelementptr inbounds i8, ptr %4084, i64 %4086
  %4096 = load i8, ptr %4095, align 1, !invariant.load !1
  br label %4085

4097:                                             ; preds = %4090
  %4098 = phi i8 [ %4087, %4090 ]
  %4099 = zext i8 %4073 to i16
  %4100 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4099)
  %4101 = trunc i32 %4100 to i16
  %4102 = bitcast i16 %4101 to half
  %4103 = zext i8 %4098 to i16
  %4104 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4103)
  %4105 = trunc i32 %4104 to i16
  %4106 = bitcast i16 %4105 to half
  %4107 = fadd contract half %4102, %4106
  %4108 = fpext half %4107 to float
  %4109 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4108)
  %4110 = trunc i16 %4109 to i8
  br label %4071

4111:                                             ; preds = %4076
  %4112 = phi i8 [ %4073, %4076 ]
  %4113 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4049, 0
  %4114 = trunc i64 %4046 to i32
  %4115 = mul i32 %4114, 512
  %4116 = trunc i64 %4044 to i32
  %4117 = add i32 %4115, %4116
  %4118 = sext i32 %4117 to i64
  %4119 = getelementptr inbounds i8, ptr %4113, i64 %4118
  store i8 %4112, ptr %4119, align 1
  %4120 = load { i64, i64 }, ptr %6, align 8
  %4121 = add i64 %4044, 1
  %4122 = extractvalue { i64, i64 } %4120, 1
  %4123 = icmp sge i64 %4121, %4122
  %4124 = select i1 %4123, i64 0, i64 %4121
  %4125 = add i64 %4046, 1
  %4126 = select i1 %4123, i64 %4125, i64 %4046
  %4127 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4128 = load i64, ptr %4, align 8
  %4129 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4130 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4127, 0
  %4131 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4127, 1, 1, 0
  %4132 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4127, 1, 1, 1
  %4133 = mul i64 %4126, %4132
  %4134 = add i64 %4133, %4124
  %4135 = getelementptr inbounds i8, ptr %4130, i64 %4134
  br label %4136

4136:                                             ; preds = %4142, %4111
  %4137 = phi i64 [ 0, %4111 ], [ %4145, %4142 ]
  %4138 = phi i8 [ 0, %4111 ], [ %4147, %4142 ]
  %4139 = icmp slt i64 %4137, 1
  br i1 %4139, label %4140, label %4141

4140:                                             ; preds = %4136
  br label %4142

4141:                                             ; preds = %4136
  br label %4148

4142:                                             ; preds = %4140
  %4143 = icmp eq i64 %4137, 1
  %4144 = add i64 %4137, 1
  %4145 = select i1 %4143, i64 %4137, i64 %4144
  %4146 = getelementptr inbounds i8, ptr %4135, i64 %4137
  %4147 = load i8, ptr %4146, align 1, !invariant.load !1
  br label %4136

4148:                                             ; preds = %4141
  %4149 = phi i8 [ %4138, %4141 ]
  %4150 = call i64 @llvm.smax.i64(i64 %4128, i64 1)
  br label %4151

4151:                                             ; preds = %4177, %4148
  %4152 = phi i64 [ 1, %4148 ], [ %4160, %4177 ]
  %4153 = phi i8 [ %4149, %4148 ], [ %4190, %4177 ]
  %4154 = icmp slt i64 %4152, %4150
  br i1 %4154, label %4155, label %4156

4155:                                             ; preds = %4151
  br label %4157

4156:                                             ; preds = %4151
  br label %4191

4157:                                             ; preds = %4155
  %4158 = icmp eq i64 %4152, %4150
  %4159 = add i64 %4152, 1
  %4160 = select i1 %4158, i64 %4152, i64 %4159
  %4161 = mul i64 %4152, %4131
  %4162 = add i64 %4161, %4133
  %4163 = add i64 %4162, %4124
  %4164 = getelementptr inbounds i8, ptr %4130, i64 %4163
  br label %4165

4165:                                             ; preds = %4171, %4157
  %4166 = phi i64 [ 0, %4157 ], [ %4174, %4171 ]
  %4167 = phi i8 [ 0, %4157 ], [ %4176, %4171 ]
  %4168 = icmp slt i64 %4166, 1
  br i1 %4168, label %4169, label %4170

4169:                                             ; preds = %4165
  br label %4171

4170:                                             ; preds = %4165
  br label %4177

4171:                                             ; preds = %4169
  %4172 = icmp eq i64 %4166, 1
  %4173 = add i64 %4166, 1
  %4174 = select i1 %4172, i64 %4166, i64 %4173
  %4175 = getelementptr inbounds i8, ptr %4164, i64 %4166
  %4176 = load i8, ptr %4175, align 1, !invariant.load !1
  br label %4165

4177:                                             ; preds = %4170
  %4178 = phi i8 [ %4167, %4170 ]
  %4179 = zext i8 %4153 to i16
  %4180 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4179)
  %4181 = trunc i32 %4180 to i16
  %4182 = bitcast i16 %4181 to half
  %4183 = zext i8 %4178 to i16
  %4184 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4183)
  %4185 = trunc i32 %4184 to i16
  %4186 = bitcast i16 %4185 to half
  %4187 = fadd contract half %4182, %4186
  %4188 = fpext half %4187 to float
  %4189 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4188)
  %4190 = trunc i16 %4189 to i8
  br label %4151

4191:                                             ; preds = %4156
  %4192 = phi i8 [ %4153, %4156 ]
  %4193 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4129, 0
  %4194 = trunc i64 %4126 to i32
  %4195 = mul i32 %4194, 512
  %4196 = trunc i64 %4124 to i32
  %4197 = add i32 %4195, %4196
  %4198 = sext i32 %4197 to i64
  %4199 = getelementptr inbounds i8, ptr %4193, i64 %4198
  store i8 %4192, ptr %4199, align 1
  br label %4318

4200:                                             ; preds = %2905
  %4201 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4202 = load i64, ptr %4, align 8
  %4203 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4204 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4201, 0
  %4205 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4201, 1, 1, 0
  %4206 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4201, 1, 1, 1
  %4207 = mul i64 %2919, %4206
  %4208 = add i64 %4207, %2925
  %4209 = getelementptr inbounds i8, ptr %4204, i64 %4208
  %4210 = load <16 x i8>, ptr %4209, align 16, !invariant.load !1
  %4211 = call i64 @llvm.smax.i64(i64 %4202, i64 1)
  br label %4212

4212:                                             ; preds = %4218, %4200
  %4213 = phi i64 [ 1, %4200 ], [ %4221, %4218 ]
  %4214 = phi <16 x i8> [ %4210, %4200 ], [ %4313, %4218 ]
  %4215 = icmp slt i64 %4213, %4211
  br i1 %4215, label %4216, label %4217

4216:                                             ; preds = %4212
  br label %4218

4217:                                             ; preds = %4212
  br label %4314

4218:                                             ; preds = %4216
  %4219 = icmp eq i64 %4213, %4211
  %4220 = add i64 %4213, 1
  %4221 = select i1 %4219, i64 %4213, i64 %4220
  %4222 = mul i64 %4213, %4205
  %4223 = add i64 %4222, %4207
  %4224 = add i64 %4223, %2925
  %4225 = getelementptr inbounds i8, ptr %4204, i64 %4224
  %4226 = load <16 x i8>, ptr %4225, align 16, !invariant.load !1
  %4227 = bitcast <16 x i8> %4214 to <8 x i16>
  %4228 = extractelement <8 x i16> %4227, i32 0
  %4229 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4228)
  %4230 = insertelement <8 x i32> undef, i32 %4229, i32 0
  %4231 = extractelement <8 x i16> %4227, i32 1
  %4232 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4231)
  %4233 = insertelement <8 x i32> %4230, i32 %4232, i32 1
  %4234 = extractelement <8 x i16> %4227, i32 2
  %4235 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4234)
  %4236 = insertelement <8 x i32> %4233, i32 %4235, i32 2
  %4237 = extractelement <8 x i16> %4227, i32 3
  %4238 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4237)
  %4239 = insertelement <8 x i32> %4236, i32 %4238, i32 3
  %4240 = extractelement <8 x i16> %4227, i32 4
  %4241 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4240)
  %4242 = insertelement <8 x i32> %4239, i32 %4241, i32 4
  %4243 = extractelement <8 x i16> %4227, i32 5
  %4244 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4243)
  %4245 = insertelement <8 x i32> %4242, i32 %4244, i32 5
  %4246 = extractelement <8 x i16> %4227, i32 6
  %4247 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4246)
  %4248 = insertelement <8 x i32> %4245, i32 %4247, i32 6
  %4249 = extractelement <8 x i16> %4227, i32 7
  %4250 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4249)
  %4251 = insertelement <8 x i32> %4248, i32 %4250, i32 7
  %4252 = bitcast <8 x i32> %4251 to <16 x half>
  %4253 = bitcast <16 x i8> %4226 to <8 x i16>
  %4254 = extractelement <8 x i16> %4253, i32 0
  %4255 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4254)
  %4256 = insertelement <8 x i32> undef, i32 %4255, i32 0
  %4257 = extractelement <8 x i16> %4253, i32 1
  %4258 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4257)
  %4259 = insertelement <8 x i32> %4256, i32 %4258, i32 1
  %4260 = extractelement <8 x i16> %4253, i32 2
  %4261 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4260)
  %4262 = insertelement <8 x i32> %4259, i32 %4261, i32 2
  %4263 = extractelement <8 x i16> %4253, i32 3
  %4264 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4263)
  %4265 = insertelement <8 x i32> %4262, i32 %4264, i32 3
  %4266 = extractelement <8 x i16> %4253, i32 4
  %4267 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4266)
  %4268 = insertelement <8 x i32> %4265, i32 %4267, i32 4
  %4269 = extractelement <8 x i16> %4253, i32 5
  %4270 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4269)
  %4271 = insertelement <8 x i32> %4268, i32 %4270, i32 5
  %4272 = extractelement <8 x i16> %4253, i32 6
  %4273 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4272)
  %4274 = insertelement <8 x i32> %4271, i32 %4273, i32 6
  %4275 = extractelement <8 x i16> %4253, i32 7
  %4276 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4275)
  %4277 = insertelement <8 x i32> %4274, i32 %4276, i32 7
  %4278 = bitcast <8 x i32> %4277 to <16 x half>
  %4279 = fadd contract <16 x half> %4252, %4278
  %4280 = fpext <16 x half> %4279 to <16 x float>
  %4281 = extractelement <16 x float> %4280, i32 1
  %4282 = extractelement <16 x float> %4280, i32 0
  %4283 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4281, float %4282)
  %4284 = insertelement <8 x i16> undef, i16 %4283, i32 0
  %4285 = extractelement <16 x float> %4280, i32 3
  %4286 = extractelement <16 x float> %4280, i32 2
  %4287 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4285, float %4286)
  %4288 = insertelement <8 x i16> %4284, i16 %4287, i32 1
  %4289 = extractelement <16 x float> %4280, i32 5
  %4290 = extractelement <16 x float> %4280, i32 4
  %4291 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4289, float %4290)
  %4292 = insertelement <8 x i16> %4288, i16 %4291, i32 2
  %4293 = extractelement <16 x float> %4280, i32 7
  %4294 = extractelement <16 x float> %4280, i32 6
  %4295 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4293, float %4294)
  %4296 = insertelement <8 x i16> %4292, i16 %4295, i32 3
  %4297 = extractelement <16 x float> %4280, i32 9
  %4298 = extractelement <16 x float> %4280, i32 8
  %4299 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4297, float %4298)
  %4300 = insertelement <8 x i16> %4296, i16 %4299, i32 4
  %4301 = extractelement <16 x float> %4280, i32 11
  %4302 = extractelement <16 x float> %4280, i32 10
  %4303 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4301, float %4302)
  %4304 = insertelement <8 x i16> %4300, i16 %4303, i32 5
  %4305 = extractelement <16 x float> %4280, i32 13
  %4306 = extractelement <16 x float> %4280, i32 12
  %4307 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4305, float %4306)
  %4308 = insertelement <8 x i16> %4304, i16 %4307, i32 6
  %4309 = extractelement <16 x float> %4280, i32 15
  %4310 = extractelement <16 x float> %4280, i32 14
  %4311 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4309, float %4310)
  %4312 = insertelement <8 x i16> %4308, i16 %4311, i32 7
  %4313 = bitcast <8 x i16> %4312 to <16 x i8>
  br label %4212

4314:                                             ; preds = %4217
  %4315 = phi <16 x i8> [ %4214, %4217 ]
  %4316 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4203, 0
  %4317 = getelementptr inbounds i8, ptr %4316, i64 %2928
  store <16 x i8> %4315, ptr %4317, align 16
  br label %4318

4318:                                             ; preds = %4314, %4191
  br label %4320

4319:                                             ; preds = %2899
  br label %4320

4320:                                             ; preds = %4319, %4318
  %4321 = add i64 %53, %18
  %4322 = mul i64 %4321, 16
  %4323 = icmp slt i64 %4322, 0
  %4324 = load i64, ptr %20, align 8
  %4325 = icmp slt i64 %4321, %4324
  br i1 %4325, label %4326, label %5740

4326:                                             ; preds = %4320
  %4327 = load { i64, i64 }, ptr %6, align 8
  %4328 = extractvalue { i64, i64 } %4327, 1
  %4329 = icmp eq i64 %4328, 0
  %4330 = select i1 %4329, i64 1, i64 %4328
  %4331 = sdiv i64 %4322, %4330
  %4332 = mul i64 %4331, %4328
  %4333 = sub i64 %4322, %4332
  %4334 = icmp slt i64 %4328, 0
  %4335 = xor i1 %4334, %4323
  %4336 = icmp ne i64 %4333, 0
  %4337 = and i1 %4335, %4336
  %4338 = select i1 %4337, i64 1, i64 0
  %4339 = sub i64 %4331, %4338
  %4340 = select i1 %4329, i64 0, i64 %4339
  %4341 = trunc i64 %4340 to i32
  %4342 = mul i32 %4341, 512
  %4343 = add i64 %4340, 1
  %4344 = select i1 %4337, i64 %4328, i64 0
  %4345 = add i64 %4333, %4344
  %4346 = select i1 %4329, i64 0, i64 %4345
  %4347 = trunc i64 %4346 to i32
  %4348 = add i32 %4342, %4347
  %4349 = sext i32 %4348 to i64
  %4350 = add i64 %4346, 1
  %4351 = add i64 %4346, 16
  %4352 = load i64, ptr %8, align 8
  %4353 = icmp sgt i64 %4351, %4352
  br i1 %4353, label %4354, label %5621

4354:                                             ; preds = %4326
  %4355 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4356 = load i64, ptr %4, align 8
  %4357 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4358 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4355, 0
  %4359 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4355, 1, 1, 0
  %4360 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4355, 1, 1, 1
  %4361 = mul i64 %4340, %4360
  %4362 = add i64 %4361, %4346
  %4363 = getelementptr inbounds i8, ptr %4358, i64 %4362
  br label %4364

4364:                                             ; preds = %4370, %4354
  %4365 = phi i64 [ 0, %4354 ], [ %4373, %4370 ]
  %4366 = phi i8 [ 0, %4354 ], [ %4375, %4370 ]
  %4367 = icmp slt i64 %4365, 1
  br i1 %4367, label %4368, label %4369

4368:                                             ; preds = %4364
  br label %4370

4369:                                             ; preds = %4364
  br label %4376

4370:                                             ; preds = %4368
  %4371 = icmp eq i64 %4365, 1
  %4372 = add i64 %4365, 1
  %4373 = select i1 %4371, i64 %4365, i64 %4372
  %4374 = getelementptr inbounds i8, ptr %4363, i64 %4365
  %4375 = load i8, ptr %4374, align 1, !invariant.load !1
  br label %4364

4376:                                             ; preds = %4369
  %4377 = phi i8 [ %4366, %4369 ]
  %4378 = call i64 @llvm.smax.i64(i64 %4356, i64 1)
  br label %4379

4379:                                             ; preds = %4405, %4376
  %4380 = phi i64 [ 1, %4376 ], [ %4388, %4405 ]
  %4381 = phi i8 [ %4377, %4376 ], [ %4418, %4405 ]
  %4382 = icmp slt i64 %4380, %4378
  br i1 %4382, label %4383, label %4384

4383:                                             ; preds = %4379
  br label %4385

4384:                                             ; preds = %4379
  br label %4419

4385:                                             ; preds = %4383
  %4386 = icmp eq i64 %4380, %4378
  %4387 = add i64 %4380, 1
  %4388 = select i1 %4386, i64 %4380, i64 %4387
  %4389 = mul i64 %4380, %4359
  %4390 = add i64 %4389, %4361
  %4391 = add i64 %4390, %4346
  %4392 = getelementptr inbounds i8, ptr %4358, i64 %4391
  br label %4393

4393:                                             ; preds = %4399, %4385
  %4394 = phi i64 [ 0, %4385 ], [ %4402, %4399 ]
  %4395 = phi i8 [ 0, %4385 ], [ %4404, %4399 ]
  %4396 = icmp slt i64 %4394, 1
  br i1 %4396, label %4397, label %4398

4397:                                             ; preds = %4393
  br label %4399

4398:                                             ; preds = %4393
  br label %4405

4399:                                             ; preds = %4397
  %4400 = icmp eq i64 %4394, 1
  %4401 = add i64 %4394, 1
  %4402 = select i1 %4400, i64 %4394, i64 %4401
  %4403 = getelementptr inbounds i8, ptr %4392, i64 %4394
  %4404 = load i8, ptr %4403, align 1, !invariant.load !1
  br label %4393

4405:                                             ; preds = %4398
  %4406 = phi i8 [ %4395, %4398 ]
  %4407 = zext i8 %4381 to i16
  %4408 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4407)
  %4409 = trunc i32 %4408 to i16
  %4410 = bitcast i16 %4409 to half
  %4411 = zext i8 %4406 to i16
  %4412 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4411)
  %4413 = trunc i32 %4412 to i16
  %4414 = bitcast i16 %4413 to half
  %4415 = fadd contract half %4410, %4414
  %4416 = fpext half %4415 to float
  %4417 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4416)
  %4418 = trunc i16 %4417 to i8
  br label %4379

4419:                                             ; preds = %4384
  %4420 = phi i8 [ %4381, %4384 ]
  %4421 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4357, 0
  %4422 = getelementptr inbounds i8, ptr %4421, i64 %4349
  store i8 %4420, ptr %4422, align 1
  %4423 = load { i64, i64 }, ptr %6, align 8
  %4424 = extractvalue { i64, i64 } %4423, 1
  %4425 = icmp sge i64 %4350, %4424
  %4426 = select i1 %4425, i64 0, i64 %4350
  %4427 = select i1 %4425, i64 %4343, i64 %4340
  %4428 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4429 = load i64, ptr %4, align 8
  %4430 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4431 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4428, 0
  %4432 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4428, 1, 1, 0
  %4433 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4428, 1, 1, 1
  %4434 = mul i64 %4427, %4433
  %4435 = add i64 %4434, %4426
  %4436 = getelementptr inbounds i8, ptr %4431, i64 %4435
  br label %4437

4437:                                             ; preds = %4443, %4419
  %4438 = phi i64 [ 0, %4419 ], [ %4446, %4443 ]
  %4439 = phi i8 [ 0, %4419 ], [ %4448, %4443 ]
  %4440 = icmp slt i64 %4438, 1
  br i1 %4440, label %4441, label %4442

4441:                                             ; preds = %4437
  br label %4443

4442:                                             ; preds = %4437
  br label %4449

4443:                                             ; preds = %4441
  %4444 = icmp eq i64 %4438, 1
  %4445 = add i64 %4438, 1
  %4446 = select i1 %4444, i64 %4438, i64 %4445
  %4447 = getelementptr inbounds i8, ptr %4436, i64 %4438
  %4448 = load i8, ptr %4447, align 1, !invariant.load !1
  br label %4437

4449:                                             ; preds = %4442
  %4450 = phi i8 [ %4439, %4442 ]
  %4451 = call i64 @llvm.smax.i64(i64 %4429, i64 1)
  br label %4452

4452:                                             ; preds = %4478, %4449
  %4453 = phi i64 [ 1, %4449 ], [ %4461, %4478 ]
  %4454 = phi i8 [ %4450, %4449 ], [ %4491, %4478 ]
  %4455 = icmp slt i64 %4453, %4451
  br i1 %4455, label %4456, label %4457

4456:                                             ; preds = %4452
  br label %4458

4457:                                             ; preds = %4452
  br label %4492

4458:                                             ; preds = %4456
  %4459 = icmp eq i64 %4453, %4451
  %4460 = add i64 %4453, 1
  %4461 = select i1 %4459, i64 %4453, i64 %4460
  %4462 = mul i64 %4453, %4432
  %4463 = add i64 %4462, %4434
  %4464 = add i64 %4463, %4426
  %4465 = getelementptr inbounds i8, ptr %4431, i64 %4464
  br label %4466

4466:                                             ; preds = %4472, %4458
  %4467 = phi i64 [ 0, %4458 ], [ %4475, %4472 ]
  %4468 = phi i8 [ 0, %4458 ], [ %4477, %4472 ]
  %4469 = icmp slt i64 %4467, 1
  br i1 %4469, label %4470, label %4471

4470:                                             ; preds = %4466
  br label %4472

4471:                                             ; preds = %4466
  br label %4478

4472:                                             ; preds = %4470
  %4473 = icmp eq i64 %4467, 1
  %4474 = add i64 %4467, 1
  %4475 = select i1 %4473, i64 %4467, i64 %4474
  %4476 = getelementptr inbounds i8, ptr %4465, i64 %4467
  %4477 = load i8, ptr %4476, align 1, !invariant.load !1
  br label %4466

4478:                                             ; preds = %4471
  %4479 = phi i8 [ %4468, %4471 ]
  %4480 = zext i8 %4454 to i16
  %4481 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4480)
  %4482 = trunc i32 %4481 to i16
  %4483 = bitcast i16 %4482 to half
  %4484 = zext i8 %4479 to i16
  %4485 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4484)
  %4486 = trunc i32 %4485 to i16
  %4487 = bitcast i16 %4486 to half
  %4488 = fadd contract half %4483, %4487
  %4489 = fpext half %4488 to float
  %4490 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4489)
  %4491 = trunc i16 %4490 to i8
  br label %4452

4492:                                             ; preds = %4457
  %4493 = phi i8 [ %4454, %4457 ]
  %4494 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4430, 0
  %4495 = trunc i64 %4427 to i32
  %4496 = mul i32 %4495, 512
  %4497 = trunc i64 %4426 to i32
  %4498 = add i32 %4496, %4497
  %4499 = sext i32 %4498 to i64
  %4500 = getelementptr inbounds i8, ptr %4494, i64 %4499
  store i8 %4493, ptr %4500, align 1
  %4501 = load { i64, i64 }, ptr %6, align 8
  %4502 = add i64 %4426, 1
  %4503 = extractvalue { i64, i64 } %4501, 1
  %4504 = icmp sge i64 %4502, %4503
  %4505 = select i1 %4504, i64 0, i64 %4502
  %4506 = add i64 %4427, 1
  %4507 = select i1 %4504, i64 %4506, i64 %4427
  %4508 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4509 = load i64, ptr %4, align 8
  %4510 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4511 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4508, 0
  %4512 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4508, 1, 1, 0
  %4513 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4508, 1, 1, 1
  %4514 = mul i64 %4507, %4513
  %4515 = add i64 %4514, %4505
  %4516 = getelementptr inbounds i8, ptr %4511, i64 %4515
  br label %4517

4517:                                             ; preds = %4523, %4492
  %4518 = phi i64 [ 0, %4492 ], [ %4526, %4523 ]
  %4519 = phi i8 [ 0, %4492 ], [ %4528, %4523 ]
  %4520 = icmp slt i64 %4518, 1
  br i1 %4520, label %4521, label %4522

4521:                                             ; preds = %4517
  br label %4523

4522:                                             ; preds = %4517
  br label %4529

4523:                                             ; preds = %4521
  %4524 = icmp eq i64 %4518, 1
  %4525 = add i64 %4518, 1
  %4526 = select i1 %4524, i64 %4518, i64 %4525
  %4527 = getelementptr inbounds i8, ptr %4516, i64 %4518
  %4528 = load i8, ptr %4527, align 1, !invariant.load !1
  br label %4517

4529:                                             ; preds = %4522
  %4530 = phi i8 [ %4519, %4522 ]
  %4531 = call i64 @llvm.smax.i64(i64 %4509, i64 1)
  br label %4532

4532:                                             ; preds = %4558, %4529
  %4533 = phi i64 [ 1, %4529 ], [ %4541, %4558 ]
  %4534 = phi i8 [ %4530, %4529 ], [ %4571, %4558 ]
  %4535 = icmp slt i64 %4533, %4531
  br i1 %4535, label %4536, label %4537

4536:                                             ; preds = %4532
  br label %4538

4537:                                             ; preds = %4532
  br label %4572

4538:                                             ; preds = %4536
  %4539 = icmp eq i64 %4533, %4531
  %4540 = add i64 %4533, 1
  %4541 = select i1 %4539, i64 %4533, i64 %4540
  %4542 = mul i64 %4533, %4512
  %4543 = add i64 %4542, %4514
  %4544 = add i64 %4543, %4505
  %4545 = getelementptr inbounds i8, ptr %4511, i64 %4544
  br label %4546

4546:                                             ; preds = %4552, %4538
  %4547 = phi i64 [ 0, %4538 ], [ %4555, %4552 ]
  %4548 = phi i8 [ 0, %4538 ], [ %4557, %4552 ]
  %4549 = icmp slt i64 %4547, 1
  br i1 %4549, label %4550, label %4551

4550:                                             ; preds = %4546
  br label %4552

4551:                                             ; preds = %4546
  br label %4558

4552:                                             ; preds = %4550
  %4553 = icmp eq i64 %4547, 1
  %4554 = add i64 %4547, 1
  %4555 = select i1 %4553, i64 %4547, i64 %4554
  %4556 = getelementptr inbounds i8, ptr %4545, i64 %4547
  %4557 = load i8, ptr %4556, align 1, !invariant.load !1
  br label %4546

4558:                                             ; preds = %4551
  %4559 = phi i8 [ %4548, %4551 ]
  %4560 = zext i8 %4534 to i16
  %4561 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4560)
  %4562 = trunc i32 %4561 to i16
  %4563 = bitcast i16 %4562 to half
  %4564 = zext i8 %4559 to i16
  %4565 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4564)
  %4566 = trunc i32 %4565 to i16
  %4567 = bitcast i16 %4566 to half
  %4568 = fadd contract half %4563, %4567
  %4569 = fpext half %4568 to float
  %4570 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4569)
  %4571 = trunc i16 %4570 to i8
  br label %4532

4572:                                             ; preds = %4537
  %4573 = phi i8 [ %4534, %4537 ]
  %4574 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4510, 0
  %4575 = trunc i64 %4507 to i32
  %4576 = mul i32 %4575, 512
  %4577 = trunc i64 %4505 to i32
  %4578 = add i32 %4576, %4577
  %4579 = sext i32 %4578 to i64
  %4580 = getelementptr inbounds i8, ptr %4574, i64 %4579
  store i8 %4573, ptr %4580, align 1
  %4581 = load { i64, i64 }, ptr %6, align 8
  %4582 = add i64 %4505, 1
  %4583 = extractvalue { i64, i64 } %4581, 1
  %4584 = icmp sge i64 %4582, %4583
  %4585 = select i1 %4584, i64 0, i64 %4582
  %4586 = add i64 %4507, 1
  %4587 = select i1 %4584, i64 %4586, i64 %4507
  %4588 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4589 = load i64, ptr %4, align 8
  %4590 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4591 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4588, 0
  %4592 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4588, 1, 1, 0
  %4593 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4588, 1, 1, 1
  %4594 = mul i64 %4587, %4593
  %4595 = add i64 %4594, %4585
  %4596 = getelementptr inbounds i8, ptr %4591, i64 %4595
  br label %4597

4597:                                             ; preds = %4603, %4572
  %4598 = phi i64 [ 0, %4572 ], [ %4606, %4603 ]
  %4599 = phi i8 [ 0, %4572 ], [ %4608, %4603 ]
  %4600 = icmp slt i64 %4598, 1
  br i1 %4600, label %4601, label %4602

4601:                                             ; preds = %4597
  br label %4603

4602:                                             ; preds = %4597
  br label %4609

4603:                                             ; preds = %4601
  %4604 = icmp eq i64 %4598, 1
  %4605 = add i64 %4598, 1
  %4606 = select i1 %4604, i64 %4598, i64 %4605
  %4607 = getelementptr inbounds i8, ptr %4596, i64 %4598
  %4608 = load i8, ptr %4607, align 1, !invariant.load !1
  br label %4597

4609:                                             ; preds = %4602
  %4610 = phi i8 [ %4599, %4602 ]
  %4611 = call i64 @llvm.smax.i64(i64 %4589, i64 1)
  br label %4612

4612:                                             ; preds = %4638, %4609
  %4613 = phi i64 [ 1, %4609 ], [ %4621, %4638 ]
  %4614 = phi i8 [ %4610, %4609 ], [ %4651, %4638 ]
  %4615 = icmp slt i64 %4613, %4611
  br i1 %4615, label %4616, label %4617

4616:                                             ; preds = %4612
  br label %4618

4617:                                             ; preds = %4612
  br label %4652

4618:                                             ; preds = %4616
  %4619 = icmp eq i64 %4613, %4611
  %4620 = add i64 %4613, 1
  %4621 = select i1 %4619, i64 %4613, i64 %4620
  %4622 = mul i64 %4613, %4592
  %4623 = add i64 %4622, %4594
  %4624 = add i64 %4623, %4585
  %4625 = getelementptr inbounds i8, ptr %4591, i64 %4624
  br label %4626

4626:                                             ; preds = %4632, %4618
  %4627 = phi i64 [ 0, %4618 ], [ %4635, %4632 ]
  %4628 = phi i8 [ 0, %4618 ], [ %4637, %4632 ]
  %4629 = icmp slt i64 %4627, 1
  br i1 %4629, label %4630, label %4631

4630:                                             ; preds = %4626
  br label %4632

4631:                                             ; preds = %4626
  br label %4638

4632:                                             ; preds = %4630
  %4633 = icmp eq i64 %4627, 1
  %4634 = add i64 %4627, 1
  %4635 = select i1 %4633, i64 %4627, i64 %4634
  %4636 = getelementptr inbounds i8, ptr %4625, i64 %4627
  %4637 = load i8, ptr %4636, align 1, !invariant.load !1
  br label %4626

4638:                                             ; preds = %4631
  %4639 = phi i8 [ %4628, %4631 ]
  %4640 = zext i8 %4614 to i16
  %4641 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4640)
  %4642 = trunc i32 %4641 to i16
  %4643 = bitcast i16 %4642 to half
  %4644 = zext i8 %4639 to i16
  %4645 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4644)
  %4646 = trunc i32 %4645 to i16
  %4647 = bitcast i16 %4646 to half
  %4648 = fadd contract half %4643, %4647
  %4649 = fpext half %4648 to float
  %4650 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4649)
  %4651 = trunc i16 %4650 to i8
  br label %4612

4652:                                             ; preds = %4617
  %4653 = phi i8 [ %4614, %4617 ]
  %4654 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4590, 0
  %4655 = trunc i64 %4587 to i32
  %4656 = mul i32 %4655, 512
  %4657 = trunc i64 %4585 to i32
  %4658 = add i32 %4656, %4657
  %4659 = sext i32 %4658 to i64
  %4660 = getelementptr inbounds i8, ptr %4654, i64 %4659
  store i8 %4653, ptr %4660, align 1
  %4661 = load { i64, i64 }, ptr %6, align 8
  %4662 = add i64 %4585, 1
  %4663 = extractvalue { i64, i64 } %4661, 1
  %4664 = icmp sge i64 %4662, %4663
  %4665 = select i1 %4664, i64 0, i64 %4662
  %4666 = add i64 %4587, 1
  %4667 = select i1 %4664, i64 %4666, i64 %4587
  %4668 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4669 = load i64, ptr %4, align 8
  %4670 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4671 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4668, 0
  %4672 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4668, 1, 1, 0
  %4673 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4668, 1, 1, 1
  %4674 = mul i64 %4667, %4673
  %4675 = add i64 %4674, %4665
  %4676 = getelementptr inbounds i8, ptr %4671, i64 %4675
  br label %4677

4677:                                             ; preds = %4683, %4652
  %4678 = phi i64 [ 0, %4652 ], [ %4686, %4683 ]
  %4679 = phi i8 [ 0, %4652 ], [ %4688, %4683 ]
  %4680 = icmp slt i64 %4678, 1
  br i1 %4680, label %4681, label %4682

4681:                                             ; preds = %4677
  br label %4683

4682:                                             ; preds = %4677
  br label %4689

4683:                                             ; preds = %4681
  %4684 = icmp eq i64 %4678, 1
  %4685 = add i64 %4678, 1
  %4686 = select i1 %4684, i64 %4678, i64 %4685
  %4687 = getelementptr inbounds i8, ptr %4676, i64 %4678
  %4688 = load i8, ptr %4687, align 1, !invariant.load !1
  br label %4677

4689:                                             ; preds = %4682
  %4690 = phi i8 [ %4679, %4682 ]
  %4691 = call i64 @llvm.smax.i64(i64 %4669, i64 1)
  br label %4692

4692:                                             ; preds = %4718, %4689
  %4693 = phi i64 [ 1, %4689 ], [ %4701, %4718 ]
  %4694 = phi i8 [ %4690, %4689 ], [ %4731, %4718 ]
  %4695 = icmp slt i64 %4693, %4691
  br i1 %4695, label %4696, label %4697

4696:                                             ; preds = %4692
  br label %4698

4697:                                             ; preds = %4692
  br label %4732

4698:                                             ; preds = %4696
  %4699 = icmp eq i64 %4693, %4691
  %4700 = add i64 %4693, 1
  %4701 = select i1 %4699, i64 %4693, i64 %4700
  %4702 = mul i64 %4693, %4672
  %4703 = add i64 %4702, %4674
  %4704 = add i64 %4703, %4665
  %4705 = getelementptr inbounds i8, ptr %4671, i64 %4704
  br label %4706

4706:                                             ; preds = %4712, %4698
  %4707 = phi i64 [ 0, %4698 ], [ %4715, %4712 ]
  %4708 = phi i8 [ 0, %4698 ], [ %4717, %4712 ]
  %4709 = icmp slt i64 %4707, 1
  br i1 %4709, label %4710, label %4711

4710:                                             ; preds = %4706
  br label %4712

4711:                                             ; preds = %4706
  br label %4718

4712:                                             ; preds = %4710
  %4713 = icmp eq i64 %4707, 1
  %4714 = add i64 %4707, 1
  %4715 = select i1 %4713, i64 %4707, i64 %4714
  %4716 = getelementptr inbounds i8, ptr %4705, i64 %4707
  %4717 = load i8, ptr %4716, align 1, !invariant.load !1
  br label %4706

4718:                                             ; preds = %4711
  %4719 = phi i8 [ %4708, %4711 ]
  %4720 = zext i8 %4694 to i16
  %4721 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4720)
  %4722 = trunc i32 %4721 to i16
  %4723 = bitcast i16 %4722 to half
  %4724 = zext i8 %4719 to i16
  %4725 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4724)
  %4726 = trunc i32 %4725 to i16
  %4727 = bitcast i16 %4726 to half
  %4728 = fadd contract half %4723, %4727
  %4729 = fpext half %4728 to float
  %4730 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4729)
  %4731 = trunc i16 %4730 to i8
  br label %4692

4732:                                             ; preds = %4697
  %4733 = phi i8 [ %4694, %4697 ]
  %4734 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4670, 0
  %4735 = trunc i64 %4667 to i32
  %4736 = mul i32 %4735, 512
  %4737 = trunc i64 %4665 to i32
  %4738 = add i32 %4736, %4737
  %4739 = sext i32 %4738 to i64
  %4740 = getelementptr inbounds i8, ptr %4734, i64 %4739
  store i8 %4733, ptr %4740, align 1
  %4741 = load { i64, i64 }, ptr %6, align 8
  %4742 = add i64 %4665, 1
  %4743 = extractvalue { i64, i64 } %4741, 1
  %4744 = icmp sge i64 %4742, %4743
  %4745 = select i1 %4744, i64 0, i64 %4742
  %4746 = add i64 %4667, 1
  %4747 = select i1 %4744, i64 %4746, i64 %4667
  %4748 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4749 = load i64, ptr %4, align 8
  %4750 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4751 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4748, 0
  %4752 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4748, 1, 1, 0
  %4753 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4748, 1, 1, 1
  %4754 = mul i64 %4747, %4753
  %4755 = add i64 %4754, %4745
  %4756 = getelementptr inbounds i8, ptr %4751, i64 %4755
  br label %4757

4757:                                             ; preds = %4763, %4732
  %4758 = phi i64 [ 0, %4732 ], [ %4766, %4763 ]
  %4759 = phi i8 [ 0, %4732 ], [ %4768, %4763 ]
  %4760 = icmp slt i64 %4758, 1
  br i1 %4760, label %4761, label %4762

4761:                                             ; preds = %4757
  br label %4763

4762:                                             ; preds = %4757
  br label %4769

4763:                                             ; preds = %4761
  %4764 = icmp eq i64 %4758, 1
  %4765 = add i64 %4758, 1
  %4766 = select i1 %4764, i64 %4758, i64 %4765
  %4767 = getelementptr inbounds i8, ptr %4756, i64 %4758
  %4768 = load i8, ptr %4767, align 1, !invariant.load !1
  br label %4757

4769:                                             ; preds = %4762
  %4770 = phi i8 [ %4759, %4762 ]
  %4771 = call i64 @llvm.smax.i64(i64 %4749, i64 1)
  br label %4772

4772:                                             ; preds = %4798, %4769
  %4773 = phi i64 [ 1, %4769 ], [ %4781, %4798 ]
  %4774 = phi i8 [ %4770, %4769 ], [ %4811, %4798 ]
  %4775 = icmp slt i64 %4773, %4771
  br i1 %4775, label %4776, label %4777

4776:                                             ; preds = %4772
  br label %4778

4777:                                             ; preds = %4772
  br label %4812

4778:                                             ; preds = %4776
  %4779 = icmp eq i64 %4773, %4771
  %4780 = add i64 %4773, 1
  %4781 = select i1 %4779, i64 %4773, i64 %4780
  %4782 = mul i64 %4773, %4752
  %4783 = add i64 %4782, %4754
  %4784 = add i64 %4783, %4745
  %4785 = getelementptr inbounds i8, ptr %4751, i64 %4784
  br label %4786

4786:                                             ; preds = %4792, %4778
  %4787 = phi i64 [ 0, %4778 ], [ %4795, %4792 ]
  %4788 = phi i8 [ 0, %4778 ], [ %4797, %4792 ]
  %4789 = icmp slt i64 %4787, 1
  br i1 %4789, label %4790, label %4791

4790:                                             ; preds = %4786
  br label %4792

4791:                                             ; preds = %4786
  br label %4798

4792:                                             ; preds = %4790
  %4793 = icmp eq i64 %4787, 1
  %4794 = add i64 %4787, 1
  %4795 = select i1 %4793, i64 %4787, i64 %4794
  %4796 = getelementptr inbounds i8, ptr %4785, i64 %4787
  %4797 = load i8, ptr %4796, align 1, !invariant.load !1
  br label %4786

4798:                                             ; preds = %4791
  %4799 = phi i8 [ %4788, %4791 ]
  %4800 = zext i8 %4774 to i16
  %4801 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4800)
  %4802 = trunc i32 %4801 to i16
  %4803 = bitcast i16 %4802 to half
  %4804 = zext i8 %4799 to i16
  %4805 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4804)
  %4806 = trunc i32 %4805 to i16
  %4807 = bitcast i16 %4806 to half
  %4808 = fadd contract half %4803, %4807
  %4809 = fpext half %4808 to float
  %4810 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4809)
  %4811 = trunc i16 %4810 to i8
  br label %4772

4812:                                             ; preds = %4777
  %4813 = phi i8 [ %4774, %4777 ]
  %4814 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4750, 0
  %4815 = trunc i64 %4747 to i32
  %4816 = mul i32 %4815, 512
  %4817 = trunc i64 %4745 to i32
  %4818 = add i32 %4816, %4817
  %4819 = sext i32 %4818 to i64
  %4820 = getelementptr inbounds i8, ptr %4814, i64 %4819
  store i8 %4813, ptr %4820, align 1
  %4821 = load { i64, i64 }, ptr %6, align 8
  %4822 = add i64 %4745, 1
  %4823 = extractvalue { i64, i64 } %4821, 1
  %4824 = icmp sge i64 %4822, %4823
  %4825 = select i1 %4824, i64 0, i64 %4822
  %4826 = add i64 %4747, 1
  %4827 = select i1 %4824, i64 %4826, i64 %4747
  %4828 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4829 = load i64, ptr %4, align 8
  %4830 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4831 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4828, 0
  %4832 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4828, 1, 1, 0
  %4833 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4828, 1, 1, 1
  %4834 = mul i64 %4827, %4833
  %4835 = add i64 %4834, %4825
  %4836 = getelementptr inbounds i8, ptr %4831, i64 %4835
  br label %4837

4837:                                             ; preds = %4843, %4812
  %4838 = phi i64 [ 0, %4812 ], [ %4846, %4843 ]
  %4839 = phi i8 [ 0, %4812 ], [ %4848, %4843 ]
  %4840 = icmp slt i64 %4838, 1
  br i1 %4840, label %4841, label %4842

4841:                                             ; preds = %4837
  br label %4843

4842:                                             ; preds = %4837
  br label %4849

4843:                                             ; preds = %4841
  %4844 = icmp eq i64 %4838, 1
  %4845 = add i64 %4838, 1
  %4846 = select i1 %4844, i64 %4838, i64 %4845
  %4847 = getelementptr inbounds i8, ptr %4836, i64 %4838
  %4848 = load i8, ptr %4847, align 1, !invariant.load !1
  br label %4837

4849:                                             ; preds = %4842
  %4850 = phi i8 [ %4839, %4842 ]
  %4851 = call i64 @llvm.smax.i64(i64 %4829, i64 1)
  br label %4852

4852:                                             ; preds = %4878, %4849
  %4853 = phi i64 [ 1, %4849 ], [ %4861, %4878 ]
  %4854 = phi i8 [ %4850, %4849 ], [ %4891, %4878 ]
  %4855 = icmp slt i64 %4853, %4851
  br i1 %4855, label %4856, label %4857

4856:                                             ; preds = %4852
  br label %4858

4857:                                             ; preds = %4852
  br label %4892

4858:                                             ; preds = %4856
  %4859 = icmp eq i64 %4853, %4851
  %4860 = add i64 %4853, 1
  %4861 = select i1 %4859, i64 %4853, i64 %4860
  %4862 = mul i64 %4853, %4832
  %4863 = add i64 %4862, %4834
  %4864 = add i64 %4863, %4825
  %4865 = getelementptr inbounds i8, ptr %4831, i64 %4864
  br label %4866

4866:                                             ; preds = %4872, %4858
  %4867 = phi i64 [ 0, %4858 ], [ %4875, %4872 ]
  %4868 = phi i8 [ 0, %4858 ], [ %4877, %4872 ]
  %4869 = icmp slt i64 %4867, 1
  br i1 %4869, label %4870, label %4871

4870:                                             ; preds = %4866
  br label %4872

4871:                                             ; preds = %4866
  br label %4878

4872:                                             ; preds = %4870
  %4873 = icmp eq i64 %4867, 1
  %4874 = add i64 %4867, 1
  %4875 = select i1 %4873, i64 %4867, i64 %4874
  %4876 = getelementptr inbounds i8, ptr %4865, i64 %4867
  %4877 = load i8, ptr %4876, align 1, !invariant.load !1
  br label %4866

4878:                                             ; preds = %4871
  %4879 = phi i8 [ %4868, %4871 ]
  %4880 = zext i8 %4854 to i16
  %4881 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4880)
  %4882 = trunc i32 %4881 to i16
  %4883 = bitcast i16 %4882 to half
  %4884 = zext i8 %4879 to i16
  %4885 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4884)
  %4886 = trunc i32 %4885 to i16
  %4887 = bitcast i16 %4886 to half
  %4888 = fadd contract half %4883, %4887
  %4889 = fpext half %4888 to float
  %4890 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4889)
  %4891 = trunc i16 %4890 to i8
  br label %4852

4892:                                             ; preds = %4857
  %4893 = phi i8 [ %4854, %4857 ]
  %4894 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4830, 0
  %4895 = trunc i64 %4827 to i32
  %4896 = mul i32 %4895, 512
  %4897 = trunc i64 %4825 to i32
  %4898 = add i32 %4896, %4897
  %4899 = sext i32 %4898 to i64
  %4900 = getelementptr inbounds i8, ptr %4894, i64 %4899
  store i8 %4893, ptr %4900, align 1
  %4901 = load { i64, i64 }, ptr %6, align 8
  %4902 = add i64 %4825, 1
  %4903 = extractvalue { i64, i64 } %4901, 1
  %4904 = icmp sge i64 %4902, %4903
  %4905 = select i1 %4904, i64 0, i64 %4902
  %4906 = add i64 %4827, 1
  %4907 = select i1 %4904, i64 %4906, i64 %4827
  %4908 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4909 = load i64, ptr %4, align 8
  %4910 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4911 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4908, 0
  %4912 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4908, 1, 1, 0
  %4913 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4908, 1, 1, 1
  %4914 = mul i64 %4907, %4913
  %4915 = add i64 %4914, %4905
  %4916 = getelementptr inbounds i8, ptr %4911, i64 %4915
  br label %4917

4917:                                             ; preds = %4923, %4892
  %4918 = phi i64 [ 0, %4892 ], [ %4926, %4923 ]
  %4919 = phi i8 [ 0, %4892 ], [ %4928, %4923 ]
  %4920 = icmp slt i64 %4918, 1
  br i1 %4920, label %4921, label %4922

4921:                                             ; preds = %4917
  br label %4923

4922:                                             ; preds = %4917
  br label %4929

4923:                                             ; preds = %4921
  %4924 = icmp eq i64 %4918, 1
  %4925 = add i64 %4918, 1
  %4926 = select i1 %4924, i64 %4918, i64 %4925
  %4927 = getelementptr inbounds i8, ptr %4916, i64 %4918
  %4928 = load i8, ptr %4927, align 1, !invariant.load !1
  br label %4917

4929:                                             ; preds = %4922
  %4930 = phi i8 [ %4919, %4922 ]
  %4931 = call i64 @llvm.smax.i64(i64 %4909, i64 1)
  br label %4932

4932:                                             ; preds = %4958, %4929
  %4933 = phi i64 [ 1, %4929 ], [ %4941, %4958 ]
  %4934 = phi i8 [ %4930, %4929 ], [ %4971, %4958 ]
  %4935 = icmp slt i64 %4933, %4931
  br i1 %4935, label %4936, label %4937

4936:                                             ; preds = %4932
  br label %4938

4937:                                             ; preds = %4932
  br label %4972

4938:                                             ; preds = %4936
  %4939 = icmp eq i64 %4933, %4931
  %4940 = add i64 %4933, 1
  %4941 = select i1 %4939, i64 %4933, i64 %4940
  %4942 = mul i64 %4933, %4912
  %4943 = add i64 %4942, %4914
  %4944 = add i64 %4943, %4905
  %4945 = getelementptr inbounds i8, ptr %4911, i64 %4944
  br label %4946

4946:                                             ; preds = %4952, %4938
  %4947 = phi i64 [ 0, %4938 ], [ %4955, %4952 ]
  %4948 = phi i8 [ 0, %4938 ], [ %4957, %4952 ]
  %4949 = icmp slt i64 %4947, 1
  br i1 %4949, label %4950, label %4951

4950:                                             ; preds = %4946
  br label %4952

4951:                                             ; preds = %4946
  br label %4958

4952:                                             ; preds = %4950
  %4953 = icmp eq i64 %4947, 1
  %4954 = add i64 %4947, 1
  %4955 = select i1 %4953, i64 %4947, i64 %4954
  %4956 = getelementptr inbounds i8, ptr %4945, i64 %4947
  %4957 = load i8, ptr %4956, align 1, !invariant.load !1
  br label %4946

4958:                                             ; preds = %4951
  %4959 = phi i8 [ %4948, %4951 ]
  %4960 = zext i8 %4934 to i16
  %4961 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4960)
  %4962 = trunc i32 %4961 to i16
  %4963 = bitcast i16 %4962 to half
  %4964 = zext i8 %4959 to i16
  %4965 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4964)
  %4966 = trunc i32 %4965 to i16
  %4967 = bitcast i16 %4966 to half
  %4968 = fadd contract half %4963, %4967
  %4969 = fpext half %4968 to float
  %4970 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4969)
  %4971 = trunc i16 %4970 to i8
  br label %4932

4972:                                             ; preds = %4937
  %4973 = phi i8 [ %4934, %4937 ]
  %4974 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4910, 0
  %4975 = trunc i64 %4907 to i32
  %4976 = mul i32 %4975, 512
  %4977 = trunc i64 %4905 to i32
  %4978 = add i32 %4976, %4977
  %4979 = sext i32 %4978 to i64
  %4980 = getelementptr inbounds i8, ptr %4974, i64 %4979
  store i8 %4973, ptr %4980, align 1
  %4981 = load { i64, i64 }, ptr %6, align 8
  %4982 = add i64 %4905, 1
  %4983 = extractvalue { i64, i64 } %4981, 1
  %4984 = icmp sge i64 %4982, %4983
  %4985 = select i1 %4984, i64 0, i64 %4982
  %4986 = add i64 %4907, 1
  %4987 = select i1 %4984, i64 %4986, i64 %4907
  %4988 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4989 = load i64, ptr %4, align 8
  %4990 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4991 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4988, 0
  %4992 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4988, 1, 1, 0
  %4993 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4988, 1, 1, 1
  %4994 = mul i64 %4987, %4993
  %4995 = add i64 %4994, %4985
  %4996 = getelementptr inbounds i8, ptr %4991, i64 %4995
  br label %4997

4997:                                             ; preds = %5003, %4972
  %4998 = phi i64 [ 0, %4972 ], [ %5006, %5003 ]
  %4999 = phi i8 [ 0, %4972 ], [ %5008, %5003 ]
  %5000 = icmp slt i64 %4998, 1
  br i1 %5000, label %5001, label %5002

5001:                                             ; preds = %4997
  br label %5003

5002:                                             ; preds = %4997
  br label %5009

5003:                                             ; preds = %5001
  %5004 = icmp eq i64 %4998, 1
  %5005 = add i64 %4998, 1
  %5006 = select i1 %5004, i64 %4998, i64 %5005
  %5007 = getelementptr inbounds i8, ptr %4996, i64 %4998
  %5008 = load i8, ptr %5007, align 1, !invariant.load !1
  br label %4997

5009:                                             ; preds = %5002
  %5010 = phi i8 [ %4999, %5002 ]
  %5011 = call i64 @llvm.smax.i64(i64 %4989, i64 1)
  br label %5012

5012:                                             ; preds = %5038, %5009
  %5013 = phi i64 [ 1, %5009 ], [ %5021, %5038 ]
  %5014 = phi i8 [ %5010, %5009 ], [ %5051, %5038 ]
  %5015 = icmp slt i64 %5013, %5011
  br i1 %5015, label %5016, label %5017

5016:                                             ; preds = %5012
  br label %5018

5017:                                             ; preds = %5012
  br label %5052

5018:                                             ; preds = %5016
  %5019 = icmp eq i64 %5013, %5011
  %5020 = add i64 %5013, 1
  %5021 = select i1 %5019, i64 %5013, i64 %5020
  %5022 = mul i64 %5013, %4992
  %5023 = add i64 %5022, %4994
  %5024 = add i64 %5023, %4985
  %5025 = getelementptr inbounds i8, ptr %4991, i64 %5024
  br label %5026

5026:                                             ; preds = %5032, %5018
  %5027 = phi i64 [ 0, %5018 ], [ %5035, %5032 ]
  %5028 = phi i8 [ 0, %5018 ], [ %5037, %5032 ]
  %5029 = icmp slt i64 %5027, 1
  br i1 %5029, label %5030, label %5031

5030:                                             ; preds = %5026
  br label %5032

5031:                                             ; preds = %5026
  br label %5038

5032:                                             ; preds = %5030
  %5033 = icmp eq i64 %5027, 1
  %5034 = add i64 %5027, 1
  %5035 = select i1 %5033, i64 %5027, i64 %5034
  %5036 = getelementptr inbounds i8, ptr %5025, i64 %5027
  %5037 = load i8, ptr %5036, align 1, !invariant.load !1
  br label %5026

5038:                                             ; preds = %5031
  %5039 = phi i8 [ %5028, %5031 ]
  %5040 = zext i8 %5014 to i16
  %5041 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5040)
  %5042 = trunc i32 %5041 to i16
  %5043 = bitcast i16 %5042 to half
  %5044 = zext i8 %5039 to i16
  %5045 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5044)
  %5046 = trunc i32 %5045 to i16
  %5047 = bitcast i16 %5046 to half
  %5048 = fadd contract half %5043, %5047
  %5049 = fpext half %5048 to float
  %5050 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5049)
  %5051 = trunc i16 %5050 to i8
  br label %5012

5052:                                             ; preds = %5017
  %5053 = phi i8 [ %5014, %5017 ]
  %5054 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4990, 0
  %5055 = trunc i64 %4987 to i32
  %5056 = mul i32 %5055, 512
  %5057 = trunc i64 %4985 to i32
  %5058 = add i32 %5056, %5057
  %5059 = sext i32 %5058 to i64
  %5060 = getelementptr inbounds i8, ptr %5054, i64 %5059
  store i8 %5053, ptr %5060, align 1
  %5061 = load { i64, i64 }, ptr %6, align 8
  %5062 = add i64 %4985, 1
  %5063 = extractvalue { i64, i64 } %5061, 1
  %5064 = icmp sge i64 %5062, %5063
  %5065 = select i1 %5064, i64 0, i64 %5062
  %5066 = add i64 %4987, 1
  %5067 = select i1 %5064, i64 %5066, i64 %4987
  %5068 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5069 = load i64, ptr %4, align 8
  %5070 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5071 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5068, 0
  %5072 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5068, 1, 1, 0
  %5073 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5068, 1, 1, 1
  %5074 = mul i64 %5067, %5073
  %5075 = add i64 %5074, %5065
  %5076 = getelementptr inbounds i8, ptr %5071, i64 %5075
  br label %5077

5077:                                             ; preds = %5083, %5052
  %5078 = phi i64 [ 0, %5052 ], [ %5086, %5083 ]
  %5079 = phi i8 [ 0, %5052 ], [ %5088, %5083 ]
  %5080 = icmp slt i64 %5078, 1
  br i1 %5080, label %5081, label %5082

5081:                                             ; preds = %5077
  br label %5083

5082:                                             ; preds = %5077
  br label %5089

5083:                                             ; preds = %5081
  %5084 = icmp eq i64 %5078, 1
  %5085 = add i64 %5078, 1
  %5086 = select i1 %5084, i64 %5078, i64 %5085
  %5087 = getelementptr inbounds i8, ptr %5076, i64 %5078
  %5088 = load i8, ptr %5087, align 1, !invariant.load !1
  br label %5077

5089:                                             ; preds = %5082
  %5090 = phi i8 [ %5079, %5082 ]
  %5091 = call i64 @llvm.smax.i64(i64 %5069, i64 1)
  br label %5092

5092:                                             ; preds = %5118, %5089
  %5093 = phi i64 [ 1, %5089 ], [ %5101, %5118 ]
  %5094 = phi i8 [ %5090, %5089 ], [ %5131, %5118 ]
  %5095 = icmp slt i64 %5093, %5091
  br i1 %5095, label %5096, label %5097

5096:                                             ; preds = %5092
  br label %5098

5097:                                             ; preds = %5092
  br label %5132

5098:                                             ; preds = %5096
  %5099 = icmp eq i64 %5093, %5091
  %5100 = add i64 %5093, 1
  %5101 = select i1 %5099, i64 %5093, i64 %5100
  %5102 = mul i64 %5093, %5072
  %5103 = add i64 %5102, %5074
  %5104 = add i64 %5103, %5065
  %5105 = getelementptr inbounds i8, ptr %5071, i64 %5104
  br label %5106

5106:                                             ; preds = %5112, %5098
  %5107 = phi i64 [ 0, %5098 ], [ %5115, %5112 ]
  %5108 = phi i8 [ 0, %5098 ], [ %5117, %5112 ]
  %5109 = icmp slt i64 %5107, 1
  br i1 %5109, label %5110, label %5111

5110:                                             ; preds = %5106
  br label %5112

5111:                                             ; preds = %5106
  br label %5118

5112:                                             ; preds = %5110
  %5113 = icmp eq i64 %5107, 1
  %5114 = add i64 %5107, 1
  %5115 = select i1 %5113, i64 %5107, i64 %5114
  %5116 = getelementptr inbounds i8, ptr %5105, i64 %5107
  %5117 = load i8, ptr %5116, align 1, !invariant.load !1
  br label %5106

5118:                                             ; preds = %5111
  %5119 = phi i8 [ %5108, %5111 ]
  %5120 = zext i8 %5094 to i16
  %5121 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5120)
  %5122 = trunc i32 %5121 to i16
  %5123 = bitcast i16 %5122 to half
  %5124 = zext i8 %5119 to i16
  %5125 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5124)
  %5126 = trunc i32 %5125 to i16
  %5127 = bitcast i16 %5126 to half
  %5128 = fadd contract half %5123, %5127
  %5129 = fpext half %5128 to float
  %5130 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5129)
  %5131 = trunc i16 %5130 to i8
  br label %5092

5132:                                             ; preds = %5097
  %5133 = phi i8 [ %5094, %5097 ]
  %5134 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5070, 0
  %5135 = trunc i64 %5067 to i32
  %5136 = mul i32 %5135, 512
  %5137 = trunc i64 %5065 to i32
  %5138 = add i32 %5136, %5137
  %5139 = sext i32 %5138 to i64
  %5140 = getelementptr inbounds i8, ptr %5134, i64 %5139
  store i8 %5133, ptr %5140, align 1
  %5141 = load { i64, i64 }, ptr %6, align 8
  %5142 = add i64 %5065, 1
  %5143 = extractvalue { i64, i64 } %5141, 1
  %5144 = icmp sge i64 %5142, %5143
  %5145 = select i1 %5144, i64 0, i64 %5142
  %5146 = add i64 %5067, 1
  %5147 = select i1 %5144, i64 %5146, i64 %5067
  %5148 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5149 = load i64, ptr %4, align 8
  %5150 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5151 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5148, 0
  %5152 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5148, 1, 1, 0
  %5153 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5148, 1, 1, 1
  %5154 = mul i64 %5147, %5153
  %5155 = add i64 %5154, %5145
  %5156 = getelementptr inbounds i8, ptr %5151, i64 %5155
  br label %5157

5157:                                             ; preds = %5163, %5132
  %5158 = phi i64 [ 0, %5132 ], [ %5166, %5163 ]
  %5159 = phi i8 [ 0, %5132 ], [ %5168, %5163 ]
  %5160 = icmp slt i64 %5158, 1
  br i1 %5160, label %5161, label %5162

5161:                                             ; preds = %5157
  br label %5163

5162:                                             ; preds = %5157
  br label %5169

5163:                                             ; preds = %5161
  %5164 = icmp eq i64 %5158, 1
  %5165 = add i64 %5158, 1
  %5166 = select i1 %5164, i64 %5158, i64 %5165
  %5167 = getelementptr inbounds i8, ptr %5156, i64 %5158
  %5168 = load i8, ptr %5167, align 1, !invariant.load !1
  br label %5157

5169:                                             ; preds = %5162
  %5170 = phi i8 [ %5159, %5162 ]
  %5171 = call i64 @llvm.smax.i64(i64 %5149, i64 1)
  br label %5172

5172:                                             ; preds = %5198, %5169
  %5173 = phi i64 [ 1, %5169 ], [ %5181, %5198 ]
  %5174 = phi i8 [ %5170, %5169 ], [ %5211, %5198 ]
  %5175 = icmp slt i64 %5173, %5171
  br i1 %5175, label %5176, label %5177

5176:                                             ; preds = %5172
  br label %5178

5177:                                             ; preds = %5172
  br label %5212

5178:                                             ; preds = %5176
  %5179 = icmp eq i64 %5173, %5171
  %5180 = add i64 %5173, 1
  %5181 = select i1 %5179, i64 %5173, i64 %5180
  %5182 = mul i64 %5173, %5152
  %5183 = add i64 %5182, %5154
  %5184 = add i64 %5183, %5145
  %5185 = getelementptr inbounds i8, ptr %5151, i64 %5184
  br label %5186

5186:                                             ; preds = %5192, %5178
  %5187 = phi i64 [ 0, %5178 ], [ %5195, %5192 ]
  %5188 = phi i8 [ 0, %5178 ], [ %5197, %5192 ]
  %5189 = icmp slt i64 %5187, 1
  br i1 %5189, label %5190, label %5191

5190:                                             ; preds = %5186
  br label %5192

5191:                                             ; preds = %5186
  br label %5198

5192:                                             ; preds = %5190
  %5193 = icmp eq i64 %5187, 1
  %5194 = add i64 %5187, 1
  %5195 = select i1 %5193, i64 %5187, i64 %5194
  %5196 = getelementptr inbounds i8, ptr %5185, i64 %5187
  %5197 = load i8, ptr %5196, align 1, !invariant.load !1
  br label %5186

5198:                                             ; preds = %5191
  %5199 = phi i8 [ %5188, %5191 ]
  %5200 = zext i8 %5174 to i16
  %5201 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5200)
  %5202 = trunc i32 %5201 to i16
  %5203 = bitcast i16 %5202 to half
  %5204 = zext i8 %5199 to i16
  %5205 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5204)
  %5206 = trunc i32 %5205 to i16
  %5207 = bitcast i16 %5206 to half
  %5208 = fadd contract half %5203, %5207
  %5209 = fpext half %5208 to float
  %5210 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5209)
  %5211 = trunc i16 %5210 to i8
  br label %5172

5212:                                             ; preds = %5177
  %5213 = phi i8 [ %5174, %5177 ]
  %5214 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5150, 0
  %5215 = trunc i64 %5147 to i32
  %5216 = mul i32 %5215, 512
  %5217 = trunc i64 %5145 to i32
  %5218 = add i32 %5216, %5217
  %5219 = sext i32 %5218 to i64
  %5220 = getelementptr inbounds i8, ptr %5214, i64 %5219
  store i8 %5213, ptr %5220, align 1
  %5221 = load { i64, i64 }, ptr %6, align 8
  %5222 = add i64 %5145, 1
  %5223 = extractvalue { i64, i64 } %5221, 1
  %5224 = icmp sge i64 %5222, %5223
  %5225 = select i1 %5224, i64 0, i64 %5222
  %5226 = add i64 %5147, 1
  %5227 = select i1 %5224, i64 %5226, i64 %5147
  %5228 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5229 = load i64, ptr %4, align 8
  %5230 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5231 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5228, 0
  %5232 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5228, 1, 1, 0
  %5233 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5228, 1, 1, 1
  %5234 = mul i64 %5227, %5233
  %5235 = add i64 %5234, %5225
  %5236 = getelementptr inbounds i8, ptr %5231, i64 %5235
  br label %5237

5237:                                             ; preds = %5243, %5212
  %5238 = phi i64 [ 0, %5212 ], [ %5246, %5243 ]
  %5239 = phi i8 [ 0, %5212 ], [ %5248, %5243 ]
  %5240 = icmp slt i64 %5238, 1
  br i1 %5240, label %5241, label %5242

5241:                                             ; preds = %5237
  br label %5243

5242:                                             ; preds = %5237
  br label %5249

5243:                                             ; preds = %5241
  %5244 = icmp eq i64 %5238, 1
  %5245 = add i64 %5238, 1
  %5246 = select i1 %5244, i64 %5238, i64 %5245
  %5247 = getelementptr inbounds i8, ptr %5236, i64 %5238
  %5248 = load i8, ptr %5247, align 1, !invariant.load !1
  br label %5237

5249:                                             ; preds = %5242
  %5250 = phi i8 [ %5239, %5242 ]
  %5251 = call i64 @llvm.smax.i64(i64 %5229, i64 1)
  br label %5252

5252:                                             ; preds = %5278, %5249
  %5253 = phi i64 [ 1, %5249 ], [ %5261, %5278 ]
  %5254 = phi i8 [ %5250, %5249 ], [ %5291, %5278 ]
  %5255 = icmp slt i64 %5253, %5251
  br i1 %5255, label %5256, label %5257

5256:                                             ; preds = %5252
  br label %5258

5257:                                             ; preds = %5252
  br label %5292

5258:                                             ; preds = %5256
  %5259 = icmp eq i64 %5253, %5251
  %5260 = add i64 %5253, 1
  %5261 = select i1 %5259, i64 %5253, i64 %5260
  %5262 = mul i64 %5253, %5232
  %5263 = add i64 %5262, %5234
  %5264 = add i64 %5263, %5225
  %5265 = getelementptr inbounds i8, ptr %5231, i64 %5264
  br label %5266

5266:                                             ; preds = %5272, %5258
  %5267 = phi i64 [ 0, %5258 ], [ %5275, %5272 ]
  %5268 = phi i8 [ 0, %5258 ], [ %5277, %5272 ]
  %5269 = icmp slt i64 %5267, 1
  br i1 %5269, label %5270, label %5271

5270:                                             ; preds = %5266
  br label %5272

5271:                                             ; preds = %5266
  br label %5278

5272:                                             ; preds = %5270
  %5273 = icmp eq i64 %5267, 1
  %5274 = add i64 %5267, 1
  %5275 = select i1 %5273, i64 %5267, i64 %5274
  %5276 = getelementptr inbounds i8, ptr %5265, i64 %5267
  %5277 = load i8, ptr %5276, align 1, !invariant.load !1
  br label %5266

5278:                                             ; preds = %5271
  %5279 = phi i8 [ %5268, %5271 ]
  %5280 = zext i8 %5254 to i16
  %5281 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5280)
  %5282 = trunc i32 %5281 to i16
  %5283 = bitcast i16 %5282 to half
  %5284 = zext i8 %5279 to i16
  %5285 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5284)
  %5286 = trunc i32 %5285 to i16
  %5287 = bitcast i16 %5286 to half
  %5288 = fadd contract half %5283, %5287
  %5289 = fpext half %5288 to float
  %5290 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5289)
  %5291 = trunc i16 %5290 to i8
  br label %5252

5292:                                             ; preds = %5257
  %5293 = phi i8 [ %5254, %5257 ]
  %5294 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5230, 0
  %5295 = trunc i64 %5227 to i32
  %5296 = mul i32 %5295, 512
  %5297 = trunc i64 %5225 to i32
  %5298 = add i32 %5296, %5297
  %5299 = sext i32 %5298 to i64
  %5300 = getelementptr inbounds i8, ptr %5294, i64 %5299
  store i8 %5293, ptr %5300, align 1
  %5301 = load { i64, i64 }, ptr %6, align 8
  %5302 = add i64 %5225, 1
  %5303 = extractvalue { i64, i64 } %5301, 1
  %5304 = icmp sge i64 %5302, %5303
  %5305 = select i1 %5304, i64 0, i64 %5302
  %5306 = add i64 %5227, 1
  %5307 = select i1 %5304, i64 %5306, i64 %5227
  %5308 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5309 = load i64, ptr %4, align 8
  %5310 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5311 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5308, 0
  %5312 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5308, 1, 1, 0
  %5313 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5308, 1, 1, 1
  %5314 = mul i64 %5307, %5313
  %5315 = add i64 %5314, %5305
  %5316 = getelementptr inbounds i8, ptr %5311, i64 %5315
  br label %5317

5317:                                             ; preds = %5323, %5292
  %5318 = phi i64 [ 0, %5292 ], [ %5326, %5323 ]
  %5319 = phi i8 [ 0, %5292 ], [ %5328, %5323 ]
  %5320 = icmp slt i64 %5318, 1
  br i1 %5320, label %5321, label %5322

5321:                                             ; preds = %5317
  br label %5323

5322:                                             ; preds = %5317
  br label %5329

5323:                                             ; preds = %5321
  %5324 = icmp eq i64 %5318, 1
  %5325 = add i64 %5318, 1
  %5326 = select i1 %5324, i64 %5318, i64 %5325
  %5327 = getelementptr inbounds i8, ptr %5316, i64 %5318
  %5328 = load i8, ptr %5327, align 1, !invariant.load !1
  br label %5317

5329:                                             ; preds = %5322
  %5330 = phi i8 [ %5319, %5322 ]
  %5331 = call i64 @llvm.smax.i64(i64 %5309, i64 1)
  br label %5332

5332:                                             ; preds = %5358, %5329
  %5333 = phi i64 [ 1, %5329 ], [ %5341, %5358 ]
  %5334 = phi i8 [ %5330, %5329 ], [ %5371, %5358 ]
  %5335 = icmp slt i64 %5333, %5331
  br i1 %5335, label %5336, label %5337

5336:                                             ; preds = %5332
  br label %5338

5337:                                             ; preds = %5332
  br label %5372

5338:                                             ; preds = %5336
  %5339 = icmp eq i64 %5333, %5331
  %5340 = add i64 %5333, 1
  %5341 = select i1 %5339, i64 %5333, i64 %5340
  %5342 = mul i64 %5333, %5312
  %5343 = add i64 %5342, %5314
  %5344 = add i64 %5343, %5305
  %5345 = getelementptr inbounds i8, ptr %5311, i64 %5344
  br label %5346

5346:                                             ; preds = %5352, %5338
  %5347 = phi i64 [ 0, %5338 ], [ %5355, %5352 ]
  %5348 = phi i8 [ 0, %5338 ], [ %5357, %5352 ]
  %5349 = icmp slt i64 %5347, 1
  br i1 %5349, label %5350, label %5351

5350:                                             ; preds = %5346
  br label %5352

5351:                                             ; preds = %5346
  br label %5358

5352:                                             ; preds = %5350
  %5353 = icmp eq i64 %5347, 1
  %5354 = add i64 %5347, 1
  %5355 = select i1 %5353, i64 %5347, i64 %5354
  %5356 = getelementptr inbounds i8, ptr %5345, i64 %5347
  %5357 = load i8, ptr %5356, align 1, !invariant.load !1
  br label %5346

5358:                                             ; preds = %5351
  %5359 = phi i8 [ %5348, %5351 ]
  %5360 = zext i8 %5334 to i16
  %5361 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5360)
  %5362 = trunc i32 %5361 to i16
  %5363 = bitcast i16 %5362 to half
  %5364 = zext i8 %5359 to i16
  %5365 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5364)
  %5366 = trunc i32 %5365 to i16
  %5367 = bitcast i16 %5366 to half
  %5368 = fadd contract half %5363, %5367
  %5369 = fpext half %5368 to float
  %5370 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5369)
  %5371 = trunc i16 %5370 to i8
  br label %5332

5372:                                             ; preds = %5337
  %5373 = phi i8 [ %5334, %5337 ]
  %5374 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5310, 0
  %5375 = trunc i64 %5307 to i32
  %5376 = mul i32 %5375, 512
  %5377 = trunc i64 %5305 to i32
  %5378 = add i32 %5376, %5377
  %5379 = sext i32 %5378 to i64
  %5380 = getelementptr inbounds i8, ptr %5374, i64 %5379
  store i8 %5373, ptr %5380, align 1
  %5381 = load { i64, i64 }, ptr %6, align 8
  %5382 = add i64 %5305, 1
  %5383 = extractvalue { i64, i64 } %5381, 1
  %5384 = icmp sge i64 %5382, %5383
  %5385 = select i1 %5384, i64 0, i64 %5382
  %5386 = add i64 %5307, 1
  %5387 = select i1 %5384, i64 %5386, i64 %5307
  %5388 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5389 = load i64, ptr %4, align 8
  %5390 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5391 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5388, 0
  %5392 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5388, 1, 1, 0
  %5393 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5388, 1, 1, 1
  %5394 = mul i64 %5387, %5393
  %5395 = add i64 %5394, %5385
  %5396 = getelementptr inbounds i8, ptr %5391, i64 %5395
  br label %5397

5397:                                             ; preds = %5403, %5372
  %5398 = phi i64 [ 0, %5372 ], [ %5406, %5403 ]
  %5399 = phi i8 [ 0, %5372 ], [ %5408, %5403 ]
  %5400 = icmp slt i64 %5398, 1
  br i1 %5400, label %5401, label %5402

5401:                                             ; preds = %5397
  br label %5403

5402:                                             ; preds = %5397
  br label %5409

5403:                                             ; preds = %5401
  %5404 = icmp eq i64 %5398, 1
  %5405 = add i64 %5398, 1
  %5406 = select i1 %5404, i64 %5398, i64 %5405
  %5407 = getelementptr inbounds i8, ptr %5396, i64 %5398
  %5408 = load i8, ptr %5407, align 1, !invariant.load !1
  br label %5397

5409:                                             ; preds = %5402
  %5410 = phi i8 [ %5399, %5402 ]
  %5411 = call i64 @llvm.smax.i64(i64 %5389, i64 1)
  br label %5412

5412:                                             ; preds = %5438, %5409
  %5413 = phi i64 [ 1, %5409 ], [ %5421, %5438 ]
  %5414 = phi i8 [ %5410, %5409 ], [ %5451, %5438 ]
  %5415 = icmp slt i64 %5413, %5411
  br i1 %5415, label %5416, label %5417

5416:                                             ; preds = %5412
  br label %5418

5417:                                             ; preds = %5412
  br label %5452

5418:                                             ; preds = %5416
  %5419 = icmp eq i64 %5413, %5411
  %5420 = add i64 %5413, 1
  %5421 = select i1 %5419, i64 %5413, i64 %5420
  %5422 = mul i64 %5413, %5392
  %5423 = add i64 %5422, %5394
  %5424 = add i64 %5423, %5385
  %5425 = getelementptr inbounds i8, ptr %5391, i64 %5424
  br label %5426

5426:                                             ; preds = %5432, %5418
  %5427 = phi i64 [ 0, %5418 ], [ %5435, %5432 ]
  %5428 = phi i8 [ 0, %5418 ], [ %5437, %5432 ]
  %5429 = icmp slt i64 %5427, 1
  br i1 %5429, label %5430, label %5431

5430:                                             ; preds = %5426
  br label %5432

5431:                                             ; preds = %5426
  br label %5438

5432:                                             ; preds = %5430
  %5433 = icmp eq i64 %5427, 1
  %5434 = add i64 %5427, 1
  %5435 = select i1 %5433, i64 %5427, i64 %5434
  %5436 = getelementptr inbounds i8, ptr %5425, i64 %5427
  %5437 = load i8, ptr %5436, align 1, !invariant.load !1
  br label %5426

5438:                                             ; preds = %5431
  %5439 = phi i8 [ %5428, %5431 ]
  %5440 = zext i8 %5414 to i16
  %5441 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5440)
  %5442 = trunc i32 %5441 to i16
  %5443 = bitcast i16 %5442 to half
  %5444 = zext i8 %5439 to i16
  %5445 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5444)
  %5446 = trunc i32 %5445 to i16
  %5447 = bitcast i16 %5446 to half
  %5448 = fadd contract half %5443, %5447
  %5449 = fpext half %5448 to float
  %5450 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5449)
  %5451 = trunc i16 %5450 to i8
  br label %5412

5452:                                             ; preds = %5417
  %5453 = phi i8 [ %5414, %5417 ]
  %5454 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5390, 0
  %5455 = trunc i64 %5387 to i32
  %5456 = mul i32 %5455, 512
  %5457 = trunc i64 %5385 to i32
  %5458 = add i32 %5456, %5457
  %5459 = sext i32 %5458 to i64
  %5460 = getelementptr inbounds i8, ptr %5454, i64 %5459
  store i8 %5453, ptr %5460, align 1
  %5461 = load { i64, i64 }, ptr %6, align 8
  %5462 = add i64 %5385, 1
  %5463 = extractvalue { i64, i64 } %5461, 1
  %5464 = icmp sge i64 %5462, %5463
  %5465 = select i1 %5464, i64 0, i64 %5462
  %5466 = add i64 %5387, 1
  %5467 = select i1 %5464, i64 %5466, i64 %5387
  %5468 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5469 = load i64, ptr %4, align 8
  %5470 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5471 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5468, 0
  %5472 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5468, 1, 1, 0
  %5473 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5468, 1, 1, 1
  %5474 = mul i64 %5467, %5473
  %5475 = add i64 %5474, %5465
  %5476 = getelementptr inbounds i8, ptr %5471, i64 %5475
  br label %5477

5477:                                             ; preds = %5483, %5452
  %5478 = phi i64 [ 0, %5452 ], [ %5486, %5483 ]
  %5479 = phi i8 [ 0, %5452 ], [ %5488, %5483 ]
  %5480 = icmp slt i64 %5478, 1
  br i1 %5480, label %5481, label %5482

5481:                                             ; preds = %5477
  br label %5483

5482:                                             ; preds = %5477
  br label %5489

5483:                                             ; preds = %5481
  %5484 = icmp eq i64 %5478, 1
  %5485 = add i64 %5478, 1
  %5486 = select i1 %5484, i64 %5478, i64 %5485
  %5487 = getelementptr inbounds i8, ptr %5476, i64 %5478
  %5488 = load i8, ptr %5487, align 1, !invariant.load !1
  br label %5477

5489:                                             ; preds = %5482
  %5490 = phi i8 [ %5479, %5482 ]
  %5491 = call i64 @llvm.smax.i64(i64 %5469, i64 1)
  br label %5492

5492:                                             ; preds = %5518, %5489
  %5493 = phi i64 [ 1, %5489 ], [ %5501, %5518 ]
  %5494 = phi i8 [ %5490, %5489 ], [ %5531, %5518 ]
  %5495 = icmp slt i64 %5493, %5491
  br i1 %5495, label %5496, label %5497

5496:                                             ; preds = %5492
  br label %5498

5497:                                             ; preds = %5492
  br label %5532

5498:                                             ; preds = %5496
  %5499 = icmp eq i64 %5493, %5491
  %5500 = add i64 %5493, 1
  %5501 = select i1 %5499, i64 %5493, i64 %5500
  %5502 = mul i64 %5493, %5472
  %5503 = add i64 %5502, %5474
  %5504 = add i64 %5503, %5465
  %5505 = getelementptr inbounds i8, ptr %5471, i64 %5504
  br label %5506

5506:                                             ; preds = %5512, %5498
  %5507 = phi i64 [ 0, %5498 ], [ %5515, %5512 ]
  %5508 = phi i8 [ 0, %5498 ], [ %5517, %5512 ]
  %5509 = icmp slt i64 %5507, 1
  br i1 %5509, label %5510, label %5511

5510:                                             ; preds = %5506
  br label %5512

5511:                                             ; preds = %5506
  br label %5518

5512:                                             ; preds = %5510
  %5513 = icmp eq i64 %5507, 1
  %5514 = add i64 %5507, 1
  %5515 = select i1 %5513, i64 %5507, i64 %5514
  %5516 = getelementptr inbounds i8, ptr %5505, i64 %5507
  %5517 = load i8, ptr %5516, align 1, !invariant.load !1
  br label %5506

5518:                                             ; preds = %5511
  %5519 = phi i8 [ %5508, %5511 ]
  %5520 = zext i8 %5494 to i16
  %5521 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5520)
  %5522 = trunc i32 %5521 to i16
  %5523 = bitcast i16 %5522 to half
  %5524 = zext i8 %5519 to i16
  %5525 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5524)
  %5526 = trunc i32 %5525 to i16
  %5527 = bitcast i16 %5526 to half
  %5528 = fadd contract half %5523, %5527
  %5529 = fpext half %5528 to float
  %5530 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5529)
  %5531 = trunc i16 %5530 to i8
  br label %5492

5532:                                             ; preds = %5497
  %5533 = phi i8 [ %5494, %5497 ]
  %5534 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5470, 0
  %5535 = trunc i64 %5467 to i32
  %5536 = mul i32 %5535, 512
  %5537 = trunc i64 %5465 to i32
  %5538 = add i32 %5536, %5537
  %5539 = sext i32 %5538 to i64
  %5540 = getelementptr inbounds i8, ptr %5534, i64 %5539
  store i8 %5533, ptr %5540, align 1
  %5541 = load { i64, i64 }, ptr %6, align 8
  %5542 = add i64 %5465, 1
  %5543 = extractvalue { i64, i64 } %5541, 1
  %5544 = icmp sge i64 %5542, %5543
  %5545 = select i1 %5544, i64 0, i64 %5542
  %5546 = add i64 %5467, 1
  %5547 = select i1 %5544, i64 %5546, i64 %5467
  %5548 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5549 = load i64, ptr %4, align 8
  %5550 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5551 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5548, 0
  %5552 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5548, 1, 1, 0
  %5553 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5548, 1, 1, 1
  %5554 = mul i64 %5547, %5553
  %5555 = add i64 %5554, %5545
  %5556 = getelementptr inbounds i8, ptr %5551, i64 %5555
  br label %5557

5557:                                             ; preds = %5563, %5532
  %5558 = phi i64 [ 0, %5532 ], [ %5566, %5563 ]
  %5559 = phi i8 [ 0, %5532 ], [ %5568, %5563 ]
  %5560 = icmp slt i64 %5558, 1
  br i1 %5560, label %5561, label %5562

5561:                                             ; preds = %5557
  br label %5563

5562:                                             ; preds = %5557
  br label %5569

5563:                                             ; preds = %5561
  %5564 = icmp eq i64 %5558, 1
  %5565 = add i64 %5558, 1
  %5566 = select i1 %5564, i64 %5558, i64 %5565
  %5567 = getelementptr inbounds i8, ptr %5556, i64 %5558
  %5568 = load i8, ptr %5567, align 1, !invariant.load !1
  br label %5557

5569:                                             ; preds = %5562
  %5570 = phi i8 [ %5559, %5562 ]
  %5571 = call i64 @llvm.smax.i64(i64 %5549, i64 1)
  br label %5572

5572:                                             ; preds = %5598, %5569
  %5573 = phi i64 [ 1, %5569 ], [ %5581, %5598 ]
  %5574 = phi i8 [ %5570, %5569 ], [ %5611, %5598 ]
  %5575 = icmp slt i64 %5573, %5571
  br i1 %5575, label %5576, label %5577

5576:                                             ; preds = %5572
  br label %5578

5577:                                             ; preds = %5572
  br label %5612

5578:                                             ; preds = %5576
  %5579 = icmp eq i64 %5573, %5571
  %5580 = add i64 %5573, 1
  %5581 = select i1 %5579, i64 %5573, i64 %5580
  %5582 = mul i64 %5573, %5552
  %5583 = add i64 %5582, %5554
  %5584 = add i64 %5583, %5545
  %5585 = getelementptr inbounds i8, ptr %5551, i64 %5584
  br label %5586

5586:                                             ; preds = %5592, %5578
  %5587 = phi i64 [ 0, %5578 ], [ %5595, %5592 ]
  %5588 = phi i8 [ 0, %5578 ], [ %5597, %5592 ]
  %5589 = icmp slt i64 %5587, 1
  br i1 %5589, label %5590, label %5591

5590:                                             ; preds = %5586
  br label %5592

5591:                                             ; preds = %5586
  br label %5598

5592:                                             ; preds = %5590
  %5593 = icmp eq i64 %5587, 1
  %5594 = add i64 %5587, 1
  %5595 = select i1 %5593, i64 %5587, i64 %5594
  %5596 = getelementptr inbounds i8, ptr %5585, i64 %5587
  %5597 = load i8, ptr %5596, align 1, !invariant.load !1
  br label %5586

5598:                                             ; preds = %5591
  %5599 = phi i8 [ %5588, %5591 ]
  %5600 = zext i8 %5574 to i16
  %5601 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5600)
  %5602 = trunc i32 %5601 to i16
  %5603 = bitcast i16 %5602 to half
  %5604 = zext i8 %5599 to i16
  %5605 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5604)
  %5606 = trunc i32 %5605 to i16
  %5607 = bitcast i16 %5606 to half
  %5608 = fadd contract half %5603, %5607
  %5609 = fpext half %5608 to float
  %5610 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5609)
  %5611 = trunc i16 %5610 to i8
  br label %5572

5612:                                             ; preds = %5577
  %5613 = phi i8 [ %5574, %5577 ]
  %5614 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5550, 0
  %5615 = trunc i64 %5547 to i32
  %5616 = mul i32 %5615, 512
  %5617 = trunc i64 %5545 to i32
  %5618 = add i32 %5616, %5617
  %5619 = sext i32 %5618 to i64
  %5620 = getelementptr inbounds i8, ptr %5614, i64 %5619
  store i8 %5613, ptr %5620, align 1
  br label %5739

5621:                                             ; preds = %4326
  %5622 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5623 = load i64, ptr %4, align 8
  %5624 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5625 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5622, 0
  %5626 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5622, 1, 1, 0
  %5627 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5622, 1, 1, 1
  %5628 = mul i64 %4340, %5627
  %5629 = add i64 %5628, %4346
  %5630 = getelementptr inbounds i8, ptr %5625, i64 %5629
  %5631 = load <16 x i8>, ptr %5630, align 16, !invariant.load !1
  %5632 = call i64 @llvm.smax.i64(i64 %5623, i64 1)
  br label %5633

5633:                                             ; preds = %5639, %5621
  %5634 = phi i64 [ 1, %5621 ], [ %5642, %5639 ]
  %5635 = phi <16 x i8> [ %5631, %5621 ], [ %5734, %5639 ]
  %5636 = icmp slt i64 %5634, %5632
  br i1 %5636, label %5637, label %5638

5637:                                             ; preds = %5633
  br label %5639

5638:                                             ; preds = %5633
  br label %5735

5639:                                             ; preds = %5637
  %5640 = icmp eq i64 %5634, %5632
  %5641 = add i64 %5634, 1
  %5642 = select i1 %5640, i64 %5634, i64 %5641
  %5643 = mul i64 %5634, %5626
  %5644 = add i64 %5643, %5628
  %5645 = add i64 %5644, %4346
  %5646 = getelementptr inbounds i8, ptr %5625, i64 %5645
  %5647 = load <16 x i8>, ptr %5646, align 16, !invariant.load !1
  %5648 = bitcast <16 x i8> %5635 to <8 x i16>
  %5649 = extractelement <8 x i16> %5648, i32 0
  %5650 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5649)
  %5651 = insertelement <8 x i32> undef, i32 %5650, i32 0
  %5652 = extractelement <8 x i16> %5648, i32 1
  %5653 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5652)
  %5654 = insertelement <8 x i32> %5651, i32 %5653, i32 1
  %5655 = extractelement <8 x i16> %5648, i32 2
  %5656 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5655)
  %5657 = insertelement <8 x i32> %5654, i32 %5656, i32 2
  %5658 = extractelement <8 x i16> %5648, i32 3
  %5659 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5658)
  %5660 = insertelement <8 x i32> %5657, i32 %5659, i32 3
  %5661 = extractelement <8 x i16> %5648, i32 4
  %5662 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5661)
  %5663 = insertelement <8 x i32> %5660, i32 %5662, i32 4
  %5664 = extractelement <8 x i16> %5648, i32 5
  %5665 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5664)
  %5666 = insertelement <8 x i32> %5663, i32 %5665, i32 5
  %5667 = extractelement <8 x i16> %5648, i32 6
  %5668 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5667)
  %5669 = insertelement <8 x i32> %5666, i32 %5668, i32 6
  %5670 = extractelement <8 x i16> %5648, i32 7
  %5671 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5670)
  %5672 = insertelement <8 x i32> %5669, i32 %5671, i32 7
  %5673 = bitcast <8 x i32> %5672 to <16 x half>
  %5674 = bitcast <16 x i8> %5647 to <8 x i16>
  %5675 = extractelement <8 x i16> %5674, i32 0
  %5676 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5675)
  %5677 = insertelement <8 x i32> undef, i32 %5676, i32 0
  %5678 = extractelement <8 x i16> %5674, i32 1
  %5679 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5678)
  %5680 = insertelement <8 x i32> %5677, i32 %5679, i32 1
  %5681 = extractelement <8 x i16> %5674, i32 2
  %5682 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5681)
  %5683 = insertelement <8 x i32> %5680, i32 %5682, i32 2
  %5684 = extractelement <8 x i16> %5674, i32 3
  %5685 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5684)
  %5686 = insertelement <8 x i32> %5683, i32 %5685, i32 3
  %5687 = extractelement <8 x i16> %5674, i32 4
  %5688 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5687)
  %5689 = insertelement <8 x i32> %5686, i32 %5688, i32 4
  %5690 = extractelement <8 x i16> %5674, i32 5
  %5691 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5690)
  %5692 = insertelement <8 x i32> %5689, i32 %5691, i32 5
  %5693 = extractelement <8 x i16> %5674, i32 6
  %5694 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5693)
  %5695 = insertelement <8 x i32> %5692, i32 %5694, i32 6
  %5696 = extractelement <8 x i16> %5674, i32 7
  %5697 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5696)
  %5698 = insertelement <8 x i32> %5695, i32 %5697, i32 7
  %5699 = bitcast <8 x i32> %5698 to <16 x half>
  %5700 = fadd contract <16 x half> %5673, %5699
  %5701 = fpext <16 x half> %5700 to <16 x float>
  %5702 = extractelement <16 x float> %5701, i32 1
  %5703 = extractelement <16 x float> %5701, i32 0
  %5704 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5702, float %5703)
  %5705 = insertelement <8 x i16> undef, i16 %5704, i32 0
  %5706 = extractelement <16 x float> %5701, i32 3
  %5707 = extractelement <16 x float> %5701, i32 2
  %5708 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5706, float %5707)
  %5709 = insertelement <8 x i16> %5705, i16 %5708, i32 1
  %5710 = extractelement <16 x float> %5701, i32 5
  %5711 = extractelement <16 x float> %5701, i32 4
  %5712 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5710, float %5711)
  %5713 = insertelement <8 x i16> %5709, i16 %5712, i32 2
  %5714 = extractelement <16 x float> %5701, i32 7
  %5715 = extractelement <16 x float> %5701, i32 6
  %5716 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5714, float %5715)
  %5717 = insertelement <8 x i16> %5713, i16 %5716, i32 3
  %5718 = extractelement <16 x float> %5701, i32 9
  %5719 = extractelement <16 x float> %5701, i32 8
  %5720 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5718, float %5719)
  %5721 = insertelement <8 x i16> %5717, i16 %5720, i32 4
  %5722 = extractelement <16 x float> %5701, i32 11
  %5723 = extractelement <16 x float> %5701, i32 10
  %5724 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5722, float %5723)
  %5725 = insertelement <8 x i16> %5721, i16 %5724, i32 5
  %5726 = extractelement <16 x float> %5701, i32 13
  %5727 = extractelement <16 x float> %5701, i32 12
  %5728 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5726, float %5727)
  %5729 = insertelement <8 x i16> %5725, i16 %5728, i32 6
  %5730 = extractelement <16 x float> %5701, i32 15
  %5731 = extractelement <16 x float> %5701, i32 14
  %5732 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5730, float %5731)
  %5733 = insertelement <8 x i16> %5729, i16 %5732, i32 7
  %5734 = bitcast <8 x i16> %5733 to <16 x i8>
  br label %5633

5735:                                             ; preds = %5638
  %5736 = phi <16 x i8> [ %5635, %5638 ]
  %5737 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5624, 0
  %5738 = getelementptr inbounds i8, ptr %5737, i64 %4349
  store <16 x i8> %5736, ptr %5738, align 16
  br label %5739

5739:                                             ; preds = %5735, %5612
  br label %5741

5740:                                             ; preds = %4320
  br label %5741

5741:                                             ; preds = %5740, %5739
  br label %29

5742:                                             ; preds = %58
  %5743 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %5744 = load i64, ptr %5743, align 8
  %5745 = icmp slt i64 %14, %5744
  br i1 %5745, label %5746, label %5840

5746:                                             ; preds = %5742
  %5747 = load i64, ptr %7, align 8
  %5748 = add i64 %5747, %14
  %5749 = load { i64, i64 }, ptr %6, align 8
  %5750 = extractvalue { i64, i64 } %5749, 1
  %5751 = icmp eq i64 %5750, 0
  %5752 = select i1 %5751, i64 1, i64 %5750
  %5753 = sdiv i64 %5748, %5752
  %5754 = mul i64 %5753, %5750
  %5755 = sub i64 %5748, %5754
  %5756 = icmp slt i64 %5750, 0
  %5757 = icmp slt i64 %5748, 0
  %5758 = xor i1 %5756, %5757
  %5759 = icmp ne i64 %5755, 0
  %5760 = and i1 %5758, %5759
  %5761 = select i1 %5760, i64 1, i64 0
  %5762 = sub i64 %5753, %5761
  %5763 = select i1 %5751, i64 0, i64 %5762
  %5764 = select i1 %5760, i64 %5750, i64 0
  %5765 = add i64 %5755, %5764
  %5766 = select i1 %5751, i64 0, i64 %5765
  %5767 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5768 = load i64, ptr %4, align 8
  %5769 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5770 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5767, 0
  %5771 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5767, 1, 1, 0
  %5772 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5767, 1, 1, 1
  %5773 = mul i64 %5763, %5772
  %5774 = add i64 %5773, %5766
  %5775 = getelementptr inbounds i8, ptr %5770, i64 %5774
  br label %5776

5776:                                             ; preds = %5782, %5746
  %5777 = phi i64 [ 0, %5746 ], [ %5785, %5782 ]
  %5778 = phi i8 [ 0, %5746 ], [ %5787, %5782 ]
  %5779 = icmp slt i64 %5777, 1
  br i1 %5779, label %5780, label %5781

5780:                                             ; preds = %5776
  br label %5782

5781:                                             ; preds = %5776
  br label %5788

5782:                                             ; preds = %5780
  %5783 = icmp eq i64 %5777, 1
  %5784 = add i64 %5777, 1
  %5785 = select i1 %5783, i64 %5777, i64 %5784
  %5786 = getelementptr inbounds i8, ptr %5775, i64 %5777
  %5787 = load i8, ptr %5786, align 1, !invariant.load !1
  br label %5776

5788:                                             ; preds = %5781
  %5789 = phi i8 [ %5778, %5781 ]
  %5790 = call i64 @llvm.smax.i64(i64 %5768, i64 1)
  br label %5791

5791:                                             ; preds = %5817, %5788
  %5792 = phi i64 [ 1, %5788 ], [ %5800, %5817 ]
  %5793 = phi i8 [ %5789, %5788 ], [ %5830, %5817 ]
  %5794 = icmp slt i64 %5792, %5790
  br i1 %5794, label %5795, label %5796

5795:                                             ; preds = %5791
  br label %5797

5796:                                             ; preds = %5791
  br label %5831

5797:                                             ; preds = %5795
  %5798 = icmp eq i64 %5792, %5790
  %5799 = add i64 %5792, 1
  %5800 = select i1 %5798, i64 %5792, i64 %5799
  %5801 = mul i64 %5792, %5771
  %5802 = add i64 %5801, %5773
  %5803 = add i64 %5802, %5766
  %5804 = getelementptr inbounds i8, ptr %5770, i64 %5803
  br label %5805

5805:                                             ; preds = %5811, %5797
  %5806 = phi i64 [ 0, %5797 ], [ %5814, %5811 ]
  %5807 = phi i8 [ 0, %5797 ], [ %5816, %5811 ]
  %5808 = icmp slt i64 %5806, 1
  br i1 %5808, label %5809, label %5810

5809:                                             ; preds = %5805
  br label %5811

5810:                                             ; preds = %5805
  br label %5817

5811:                                             ; preds = %5809
  %5812 = icmp eq i64 %5806, 1
  %5813 = add i64 %5806, 1
  %5814 = select i1 %5812, i64 %5806, i64 %5813
  %5815 = getelementptr inbounds i8, ptr %5804, i64 %5806
  %5816 = load i8, ptr %5815, align 1, !invariant.load !1
  br label %5805

5817:                                             ; preds = %5810
  %5818 = phi i8 [ %5807, %5810 ]
  %5819 = zext i8 %5793 to i16
  %5820 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5819)
  %5821 = trunc i32 %5820 to i16
  %5822 = bitcast i16 %5821 to half
  %5823 = zext i8 %5818 to i16
  %5824 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5823)
  %5825 = trunc i32 %5824 to i16
  %5826 = bitcast i16 %5825 to half
  %5827 = fadd contract half %5822, %5826
  %5828 = fpext half %5827 to float
  %5829 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5828)
  %5830 = trunc i16 %5829 to i8
  br label %5791

5831:                                             ; preds = %5796
  %5832 = phi i8 [ %5793, %5796 ]
  %5833 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5769, 0
  %5834 = trunc i64 %5763 to i32
  %5835 = mul i32 %5834, 512
  %5836 = trunc i64 %5766 to i32
  %5837 = add i32 %5835, %5836
  %5838 = sext i32 %5837 to i64
  %5839 = getelementptr inbounds i8, ptr %5833, i64 %5838
  store i8 %5832, ptr %5839, align 1
  br label %5841

5840:                                             ; preds = %5742
  br label %5841

5841:                                             ; preds = %5840, %5831
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
