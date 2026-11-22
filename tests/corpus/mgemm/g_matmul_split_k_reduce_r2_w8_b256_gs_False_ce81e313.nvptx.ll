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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w8_b256_gs_False_ce81e313(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

28:                                               ; preds = %292, %1
  %29 = phi i64 [ %23, %1 ], [ %53, %292 ]
  %30 = phi i64 [ 0, %1 ], [ %54, %292 ]
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
  %56 = trunc i64 %55 to i32
  br i1 %51, label %57, label %58

57:                                               ; preds = %50
  br label %293

58:                                               ; preds = %50
  br label %59

59:                                               ; preds = %58
  %60 = load i64, ptr %19, align 8
  %61 = icmp slt i64 %52, %60
  br i1 %61, label %62, label %114

62:                                               ; preds = %59
  %63 = load { i64, i64 }, ptr %6, align 8
  %64 = extractvalue { i64, i64 } %63, 1
  %65 = trunc i64 %64 to i32
  %66 = icmp eq i32 %65, 0
  %67 = select i1 %66, i32 1, i32 %65
  %68 = icmp eq i32 %67, 0
  %69 = select i1 %68, i32 1, i32 %67
  %70 = udiv i32 %56, %69
  %71 = select i1 %68, i32 0, i32 %70
  %72 = urem i32 %56, %69
  %73 = select i1 %68, i32 0, i32 %72
  %74 = select i1 %66, i32 0, i32 %71
  %75 = select i1 %66, i32 0, i32 %73
  %76 = zext i32 %74 to i64
  %77 = zext i32 %75 to i64
  %78 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %79 = load i64, ptr %4, align 8
  %80 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %81 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %78, 0
  %82 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %78, 1, 1, 0
  %83 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %78, 1, 1, 1
  %84 = mul i64 %76, %83
  %85 = add i64 %84, %77
  %86 = getelementptr inbounds bfloat, ptr %81, i64 %85
  %87 = load <8 x bfloat>, ptr %86, align 16, !invariant.load !1
  %88 = call i64 @llvm.smax.i64(i64 %79, i64 1)
  br label %89

89:                                               ; preds = %95, %62
  %90 = phi i64 [ 1, %62 ], [ %98, %95 ]
  %91 = phi <8 x bfloat> [ %87, %62 ], [ %104, %95 ]
  %92 = icmp slt i64 %90, %88
  br i1 %92, label %93, label %94

93:                                               ; preds = %89
  br label %95

94:                                               ; preds = %89
  br label %105

95:                                               ; preds = %93
  %96 = icmp eq i64 %90, %88
  %97 = add i64 %90, 1
  %98 = select i1 %96, i64 %90, i64 %97
  %99 = mul i64 %90, %82
  %100 = add i64 %99, %84
  %101 = add i64 %100, %77
  %102 = getelementptr inbounds bfloat, ptr %81, i64 %101
  %103 = load <8 x bfloat>, ptr %102, align 16, !invariant.load !1
  %104 = fadd contract <8 x bfloat> %91, %103
  br label %89

105:                                              ; preds = %94
  %106 = phi <8 x bfloat> [ %91, %94 ]
  %107 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %80, 0
  %108 = trunc i64 %76 to i32
  %109 = mul i32 %108, 512
  %110 = trunc i64 %77 to i32
  %111 = add i32 %109, %110
  %112 = sext i32 %111 to i64
  %113 = getelementptr inbounds bfloat, ptr %107, i64 %112
  store <8 x bfloat> %106, ptr %113, align 16
  br label %115

114:                                              ; preds = %59
  br label %115

115:                                              ; preds = %114, %105
  %116 = add i64 %52, %16
  %117 = mul i64 %116, 8
  %118 = trunc i64 %117 to i32
  %119 = load i64, ptr %19, align 8
  %120 = icmp slt i64 %116, %119
  br i1 %120, label %121, label %173

121:                                              ; preds = %115
  %122 = load { i64, i64 }, ptr %6, align 8
  %123 = extractvalue { i64, i64 } %122, 1
  %124 = trunc i64 %123 to i32
  %125 = icmp eq i32 %124, 0
  %126 = select i1 %125, i32 1, i32 %124
  %127 = icmp eq i32 %126, 0
  %128 = select i1 %127, i32 1, i32 %126
  %129 = udiv i32 %118, %128
  %130 = select i1 %127, i32 0, i32 %129
  %131 = urem i32 %118, %128
  %132 = select i1 %127, i32 0, i32 %131
  %133 = select i1 %125, i32 0, i32 %130
  %134 = select i1 %125, i32 0, i32 %132
  %135 = zext i32 %133 to i64
  %136 = zext i32 %134 to i64
  %137 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %138 = load i64, ptr %4, align 8
  %139 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %140 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %137, 0
  %141 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %137, 1, 1, 0
  %142 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %137, 1, 1, 1
  %143 = mul i64 %135, %142
  %144 = add i64 %143, %136
  %145 = getelementptr inbounds bfloat, ptr %140, i64 %144
  %146 = load <8 x bfloat>, ptr %145, align 16, !invariant.load !1
  %147 = call i64 @llvm.smax.i64(i64 %138, i64 1)
  br label %148

148:                                              ; preds = %154, %121
  %149 = phi i64 [ 1, %121 ], [ %157, %154 ]
  %150 = phi <8 x bfloat> [ %146, %121 ], [ %163, %154 ]
  %151 = icmp slt i64 %149, %147
  br i1 %151, label %152, label %153

152:                                              ; preds = %148
  br label %154

153:                                              ; preds = %148
  br label %164

154:                                              ; preds = %152
  %155 = icmp eq i64 %149, %147
  %156 = add i64 %149, 1
  %157 = select i1 %155, i64 %149, i64 %156
  %158 = mul i64 %149, %141
  %159 = add i64 %158, %143
  %160 = add i64 %159, %136
  %161 = getelementptr inbounds bfloat, ptr %140, i64 %160
  %162 = load <8 x bfloat>, ptr %161, align 16, !invariant.load !1
  %163 = fadd contract <8 x bfloat> %150, %162
  br label %148

164:                                              ; preds = %153
  %165 = phi <8 x bfloat> [ %150, %153 ]
  %166 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %139, 0
  %167 = trunc i64 %135 to i32
  %168 = mul i32 %167, 512
  %169 = trunc i64 %136 to i32
  %170 = add i32 %168, %169
  %171 = sext i32 %170 to i64
  %172 = getelementptr inbounds bfloat, ptr %166, i64 %171
  store <8 x bfloat> %165, ptr %172, align 16
  br label %174

173:                                              ; preds = %115
  br label %174

174:                                              ; preds = %173, %164
  %175 = add i64 %52, %18
  %176 = mul i64 %175, 8
  %177 = trunc i64 %176 to i32
  %178 = load i64, ptr %19, align 8
  %179 = icmp slt i64 %175, %178
  br i1 %179, label %180, label %232

180:                                              ; preds = %174
  %181 = load { i64, i64 }, ptr %6, align 8
  %182 = extractvalue { i64, i64 } %181, 1
  %183 = trunc i64 %182 to i32
  %184 = icmp eq i32 %183, 0
  %185 = select i1 %184, i32 1, i32 %183
  %186 = icmp eq i32 %185, 0
  %187 = select i1 %186, i32 1, i32 %185
  %188 = udiv i32 %177, %187
  %189 = select i1 %186, i32 0, i32 %188
  %190 = urem i32 %177, %187
  %191 = select i1 %186, i32 0, i32 %190
  %192 = select i1 %184, i32 0, i32 %189
  %193 = select i1 %184, i32 0, i32 %191
  %194 = zext i32 %192 to i64
  %195 = zext i32 %193 to i64
  %196 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %197 = load i64, ptr %4, align 8
  %198 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %199 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %196, 0
  %200 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %196, 1, 1, 0
  %201 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %196, 1, 1, 1
  %202 = mul i64 %194, %201
  %203 = add i64 %202, %195
  %204 = getelementptr inbounds bfloat, ptr %199, i64 %203
  %205 = load <8 x bfloat>, ptr %204, align 16, !invariant.load !1
  %206 = call i64 @llvm.smax.i64(i64 %197, i64 1)
  br label %207

207:                                              ; preds = %213, %180
  %208 = phi i64 [ 1, %180 ], [ %216, %213 ]
  %209 = phi <8 x bfloat> [ %205, %180 ], [ %222, %213 ]
  %210 = icmp slt i64 %208, %206
  br i1 %210, label %211, label %212

211:                                              ; preds = %207
  br label %213

212:                                              ; preds = %207
  br label %223

213:                                              ; preds = %211
  %214 = icmp eq i64 %208, %206
  %215 = add i64 %208, 1
  %216 = select i1 %214, i64 %208, i64 %215
  %217 = mul i64 %208, %200
  %218 = add i64 %217, %202
  %219 = add i64 %218, %195
  %220 = getelementptr inbounds bfloat, ptr %199, i64 %219
  %221 = load <8 x bfloat>, ptr %220, align 16, !invariant.load !1
  %222 = fadd contract <8 x bfloat> %209, %221
  br label %207

223:                                              ; preds = %212
  %224 = phi <8 x bfloat> [ %209, %212 ]
  %225 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %198, 0
  %226 = trunc i64 %194 to i32
  %227 = mul i32 %226, 512
  %228 = trunc i64 %195 to i32
  %229 = add i32 %227, %228
  %230 = sext i32 %229 to i64
  %231 = getelementptr inbounds bfloat, ptr %225, i64 %230
  store <8 x bfloat> %224, ptr %231, align 16
  br label %233

232:                                              ; preds = %174
  br label %233

233:                                              ; preds = %232, %223
  %234 = add i64 %52, %17
  %235 = mul i64 %234, 8
  %236 = trunc i64 %235 to i32
  %237 = load i64, ptr %19, align 8
  %238 = icmp slt i64 %234, %237
  br i1 %238, label %239, label %291

239:                                              ; preds = %233
  %240 = load { i64, i64 }, ptr %6, align 8
  %241 = extractvalue { i64, i64 } %240, 1
  %242 = trunc i64 %241 to i32
  %243 = icmp eq i32 %242, 0
  %244 = select i1 %243, i32 1, i32 %242
  %245 = icmp eq i32 %244, 0
  %246 = select i1 %245, i32 1, i32 %244
  %247 = udiv i32 %236, %246
  %248 = select i1 %245, i32 0, i32 %247
  %249 = urem i32 %236, %246
  %250 = select i1 %245, i32 0, i32 %249
  %251 = select i1 %243, i32 0, i32 %248
  %252 = select i1 %243, i32 0, i32 %250
  %253 = zext i32 %251 to i64
  %254 = zext i32 %252 to i64
  %255 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %256 = load i64, ptr %4, align 8
  %257 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %258 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %255, 0
  %259 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %255, 1, 1, 0
  %260 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %255, 1, 1, 1
  %261 = mul i64 %253, %260
  %262 = add i64 %261, %254
  %263 = getelementptr inbounds bfloat, ptr %258, i64 %262
  %264 = load <8 x bfloat>, ptr %263, align 16, !invariant.load !1
  %265 = call i64 @llvm.smax.i64(i64 %256, i64 1)
  br label %266

266:                                              ; preds = %272, %239
  %267 = phi i64 [ 1, %239 ], [ %275, %272 ]
  %268 = phi <8 x bfloat> [ %264, %239 ], [ %281, %272 ]
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
  %278 = add i64 %277, %254
  %279 = getelementptr inbounds bfloat, ptr %258, i64 %278
  %280 = load <8 x bfloat>, ptr %279, align 16, !invariant.load !1
  %281 = fadd contract <8 x bfloat> %268, %280
  br label %266

282:                                              ; preds = %271
  %283 = phi <8 x bfloat> [ %268, %271 ]
  %284 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %257, 0
  %285 = trunc i64 %253 to i32
  %286 = mul i32 %285, 512
  %287 = trunc i64 %254 to i32
  %288 = add i32 %286, %287
  %289 = sext i32 %288 to i64
  %290 = getelementptr inbounds bfloat, ptr %284, i64 %289
  store <8 x bfloat> %283, ptr %290, align 16
  br label %292

291:                                              ; preds = %233
  br label %292

292:                                              ; preds = %291, %282
  br label %28

293:                                              ; preds = %57
  %294 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %295 = load i64, ptr %294, align 8
  %296 = icmp slt i64 %13, %295
  br i1 %296, label %297, label %352

297:                                              ; preds = %293
  %298 = load i64, ptr %7, align 8
  %299 = add i64 %298, %13
  %300 = load { i64, i64 }, ptr %6, align 8
  %301 = trunc i64 %299 to i32
  %302 = extractvalue { i64, i64 } %300, 1
  %303 = trunc i64 %302 to i32
  %304 = icmp eq i32 %303, 0
  %305 = select i1 %304, i32 1, i32 %303
  %306 = icmp eq i32 %305, 0
  %307 = select i1 %306, i32 1, i32 %305
  %308 = udiv i32 %301, %307
  %309 = select i1 %306, i32 0, i32 %308
  %310 = urem i32 %301, %307
  %311 = select i1 %306, i32 0, i32 %310
  %312 = select i1 %304, i32 0, i32 %309
  %313 = select i1 %304, i32 0, i32 %311
  %314 = zext i32 %312 to i64
  %315 = zext i32 %313 to i64
  %316 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %317 = load i64, ptr %4, align 8
  %318 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %319 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %316, 0
  %320 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %316, 1, 1, 0
  %321 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %316, 1, 1, 1
  %322 = mul i64 %314, %321
  %323 = add i64 %322, %315
  %324 = getelementptr inbounds bfloat, ptr %319, i64 %323
  %325 = load bfloat, ptr %324, align 2, !invariant.load !1
  %326 = call i64 @llvm.smax.i64(i64 %317, i64 1)
  br label %327

327:                                              ; preds = %333, %297
  %328 = phi i64 [ 1, %297 ], [ %336, %333 ]
  %329 = phi bfloat [ %325, %297 ], [ %342, %333 ]
  %330 = icmp slt i64 %328, %326
  br i1 %330, label %331, label %332

331:                                              ; preds = %327
  br label %333

332:                                              ; preds = %327
  br label %343

333:                                              ; preds = %331
  %334 = icmp eq i64 %328, %326
  %335 = add i64 %328, 1
  %336 = select i1 %334, i64 %328, i64 %335
  %337 = mul i64 %328, %320
  %338 = add i64 %337, %322
  %339 = add i64 %338, %315
  %340 = getelementptr inbounds bfloat, ptr %319, i64 %339
  %341 = load bfloat, ptr %340, align 2, !invariant.load !1
  %342 = fadd contract bfloat %329, %341
  br label %327

343:                                              ; preds = %332
  %344 = phi bfloat [ %329, %332 ]
  %345 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %318, 0
  %346 = trunc i64 %314 to i32
  %347 = mul i32 %346, 512
  %348 = trunc i64 %315 to i32
  %349 = add i32 %347, %348
  %350 = sext i32 %349 to i64
  %351 = getelementptr inbounds bfloat, ptr %345, i64 %350
  store bfloat %344, ptr %351, align 2
  br label %353

352:                                              ; preds = %293
  br label %353

353:                                              ; preds = %352, %343
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
