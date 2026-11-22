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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w16_b256_gs_True_2e0d4661(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

29:                                               ; preds = %5733, %1
  %30 = phi i64 [ %24, %1 ], [ %54, %5733 ]
  %31 = phi i64 [ 0, %1 ], [ %55, %5733 ]
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
  %57 = trunc i64 %56 to i32
  br i1 %52, label %58, label %59

58:                                               ; preds = %51
  br label %5734

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59
  %61 = load i64, ptr %20, align 8
  %62 = icmp slt i64 %53, %61
  br i1 %62, label %63, label %1475

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
  %86 = add i64 %77, 16
  %87 = load i64, ptr %8, align 8
  %88 = icmp sgt i64 %86, %87
  br i1 %88, label %89, label %1356

89:                                               ; preds = %63
  %90 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %91 = load i64, ptr %4, align 8
  %92 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %93 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 0
  %94 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 1, 1, 0
  %95 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %90, 1, 1, 1
  %96 = mul i64 %80, %95
  %97 = add i64 %96, %77
  %98 = getelementptr inbounds i8, ptr %93, i64 %97
  br label %99

99:                                               ; preds = %105, %89
  %100 = phi i64 [ 0, %89 ], [ %108, %105 ]
  %101 = phi i8 [ 0, %89 ], [ %110, %105 ]
  %102 = icmp slt i64 %100, 1
  br i1 %102, label %103, label %104

103:                                              ; preds = %99
  br label %105

104:                                              ; preds = %99
  br label %111

105:                                              ; preds = %103
  %106 = icmp eq i64 %100, 1
  %107 = add i64 %100, 1
  %108 = select i1 %106, i64 %100, i64 %107
  %109 = getelementptr inbounds i8, ptr %98, i64 %100
  %110 = load i8, ptr %109, align 1, !invariant.load !1
  br label %99

111:                                              ; preds = %104
  %112 = phi i8 [ %101, %104 ]
  %113 = call i64 @llvm.smax.i64(i64 %91, i64 1)
  br label %114

114:                                              ; preds = %140, %111
  %115 = phi i64 [ 1, %111 ], [ %123, %140 ]
  %116 = phi i8 [ %112, %111 ], [ %153, %140 ]
  %117 = icmp slt i64 %115, %113
  br i1 %117, label %118, label %119

118:                                              ; preds = %114
  br label %120

119:                                              ; preds = %114
  br label %154

120:                                              ; preds = %118
  %121 = icmp eq i64 %115, %113
  %122 = add i64 %115, 1
  %123 = select i1 %121, i64 %115, i64 %122
  %124 = mul i64 %115, %94
  %125 = add i64 %124, %96
  %126 = add i64 %125, %77
  %127 = getelementptr inbounds i8, ptr %93, i64 %126
  br label %128

128:                                              ; preds = %134, %120
  %129 = phi i64 [ 0, %120 ], [ %137, %134 ]
  %130 = phi i8 [ 0, %120 ], [ %139, %134 ]
  %131 = icmp slt i64 %129, 1
  br i1 %131, label %132, label %133

132:                                              ; preds = %128
  br label %134

133:                                              ; preds = %128
  br label %140

134:                                              ; preds = %132
  %135 = icmp eq i64 %129, 1
  %136 = add i64 %129, 1
  %137 = select i1 %135, i64 %129, i64 %136
  %138 = getelementptr inbounds i8, ptr %127, i64 %129
  %139 = load i8, ptr %138, align 1, !invariant.load !1
  br label %128

140:                                              ; preds = %133
  %141 = phi i8 [ %130, %133 ]
  %142 = zext i8 %116 to i16
  %143 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %142)
  %144 = trunc i32 %143 to i16
  %145 = bitcast i16 %144 to half
  %146 = zext i8 %141 to i16
  %147 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %146)
  %148 = trunc i32 %147 to i16
  %149 = bitcast i16 %148 to half
  %150 = fadd contract half %145, %149
  %151 = fpext half %150 to float
  %152 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %151)
  %153 = trunc i16 %152 to i8
  br label %114

154:                                              ; preds = %119
  %155 = phi i8 [ %116, %119 ]
  %156 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %92, 0
  %157 = getelementptr inbounds i8, ptr %156, i64 %84
  store i8 %155, ptr %157, align 1
  %158 = load { i64, i64 }, ptr %6, align 8
  %159 = extractvalue { i64, i64 } %158, 1
  %160 = icmp sge i64 %79, %159
  %161 = select i1 %160, i64 0, i64 %79
  %162 = select i1 %160, i64 %85, i64 %80
  %163 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %164 = load i64, ptr %4, align 8
  %165 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %166 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %163, 0
  %167 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %163, 1, 1, 0
  %168 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %163, 1, 1, 1
  %169 = mul i64 %162, %168
  %170 = add i64 %169, %161
  %171 = getelementptr inbounds i8, ptr %166, i64 %170
  br label %172

172:                                              ; preds = %178, %154
  %173 = phi i64 [ 0, %154 ], [ %181, %178 ]
  %174 = phi i8 [ 0, %154 ], [ %183, %178 ]
  %175 = icmp slt i64 %173, 1
  br i1 %175, label %176, label %177

176:                                              ; preds = %172
  br label %178

177:                                              ; preds = %172
  br label %184

178:                                              ; preds = %176
  %179 = icmp eq i64 %173, 1
  %180 = add i64 %173, 1
  %181 = select i1 %179, i64 %173, i64 %180
  %182 = getelementptr inbounds i8, ptr %171, i64 %173
  %183 = load i8, ptr %182, align 1, !invariant.load !1
  br label %172

184:                                              ; preds = %177
  %185 = phi i8 [ %174, %177 ]
  %186 = call i64 @llvm.smax.i64(i64 %164, i64 1)
  br label %187

187:                                              ; preds = %213, %184
  %188 = phi i64 [ 1, %184 ], [ %196, %213 ]
  %189 = phi i8 [ %185, %184 ], [ %226, %213 ]
  %190 = icmp slt i64 %188, %186
  br i1 %190, label %191, label %192

191:                                              ; preds = %187
  br label %193

192:                                              ; preds = %187
  br label %227

193:                                              ; preds = %191
  %194 = icmp eq i64 %188, %186
  %195 = add i64 %188, 1
  %196 = select i1 %194, i64 %188, i64 %195
  %197 = mul i64 %188, %167
  %198 = add i64 %197, %169
  %199 = add i64 %198, %161
  %200 = getelementptr inbounds i8, ptr %166, i64 %199
  br label %201

201:                                              ; preds = %207, %193
  %202 = phi i64 [ 0, %193 ], [ %210, %207 ]
  %203 = phi i8 [ 0, %193 ], [ %212, %207 ]
  %204 = icmp slt i64 %202, 1
  br i1 %204, label %205, label %206

205:                                              ; preds = %201
  br label %207

206:                                              ; preds = %201
  br label %213

207:                                              ; preds = %205
  %208 = icmp eq i64 %202, 1
  %209 = add i64 %202, 1
  %210 = select i1 %208, i64 %202, i64 %209
  %211 = getelementptr inbounds i8, ptr %200, i64 %202
  %212 = load i8, ptr %211, align 1, !invariant.load !1
  br label %201

213:                                              ; preds = %206
  %214 = phi i8 [ %203, %206 ]
  %215 = zext i8 %189 to i16
  %216 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %215)
  %217 = trunc i32 %216 to i16
  %218 = bitcast i16 %217 to half
  %219 = zext i8 %214 to i16
  %220 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %219)
  %221 = trunc i32 %220 to i16
  %222 = bitcast i16 %221 to half
  %223 = fadd contract half %218, %222
  %224 = fpext half %223 to float
  %225 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %224)
  %226 = trunc i16 %225 to i8
  br label %187

227:                                              ; preds = %192
  %228 = phi i8 [ %189, %192 ]
  %229 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %165, 0
  %230 = trunc i64 %162 to i32
  %231 = mul i32 %230, 512
  %232 = trunc i64 %161 to i32
  %233 = add i32 %231, %232
  %234 = sext i32 %233 to i64
  %235 = getelementptr inbounds i8, ptr %229, i64 %234
  store i8 %228, ptr %235, align 1
  %236 = load { i64, i64 }, ptr %6, align 8
  %237 = add i64 %161, 1
  %238 = extractvalue { i64, i64 } %236, 1
  %239 = icmp sge i64 %237, %238
  %240 = select i1 %239, i64 0, i64 %237
  %241 = add i64 %162, 1
  %242 = select i1 %239, i64 %241, i64 %162
  %243 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %244 = load i64, ptr %4, align 8
  %245 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %246 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %243, 0
  %247 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %243, 1, 1, 0
  %248 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %243, 1, 1, 1
  %249 = mul i64 %242, %248
  %250 = add i64 %249, %240
  %251 = getelementptr inbounds i8, ptr %246, i64 %250
  br label %252

252:                                              ; preds = %258, %227
  %253 = phi i64 [ 0, %227 ], [ %261, %258 ]
  %254 = phi i8 [ 0, %227 ], [ %263, %258 ]
  %255 = icmp slt i64 %253, 1
  br i1 %255, label %256, label %257

256:                                              ; preds = %252
  br label %258

257:                                              ; preds = %252
  br label %264

258:                                              ; preds = %256
  %259 = icmp eq i64 %253, 1
  %260 = add i64 %253, 1
  %261 = select i1 %259, i64 %253, i64 %260
  %262 = getelementptr inbounds i8, ptr %251, i64 %253
  %263 = load i8, ptr %262, align 1, !invariant.load !1
  br label %252

264:                                              ; preds = %257
  %265 = phi i8 [ %254, %257 ]
  %266 = call i64 @llvm.smax.i64(i64 %244, i64 1)
  br label %267

267:                                              ; preds = %293, %264
  %268 = phi i64 [ 1, %264 ], [ %276, %293 ]
  %269 = phi i8 [ %265, %264 ], [ %306, %293 ]
  %270 = icmp slt i64 %268, %266
  br i1 %270, label %271, label %272

271:                                              ; preds = %267
  br label %273

272:                                              ; preds = %267
  br label %307

273:                                              ; preds = %271
  %274 = icmp eq i64 %268, %266
  %275 = add i64 %268, 1
  %276 = select i1 %274, i64 %268, i64 %275
  %277 = mul i64 %268, %247
  %278 = add i64 %277, %249
  %279 = add i64 %278, %240
  %280 = getelementptr inbounds i8, ptr %246, i64 %279
  br label %281

281:                                              ; preds = %287, %273
  %282 = phi i64 [ 0, %273 ], [ %290, %287 ]
  %283 = phi i8 [ 0, %273 ], [ %292, %287 ]
  %284 = icmp slt i64 %282, 1
  br i1 %284, label %285, label %286

285:                                              ; preds = %281
  br label %287

286:                                              ; preds = %281
  br label %293

287:                                              ; preds = %285
  %288 = icmp eq i64 %282, 1
  %289 = add i64 %282, 1
  %290 = select i1 %288, i64 %282, i64 %289
  %291 = getelementptr inbounds i8, ptr %280, i64 %282
  %292 = load i8, ptr %291, align 1, !invariant.load !1
  br label %281

293:                                              ; preds = %286
  %294 = phi i8 [ %283, %286 ]
  %295 = zext i8 %269 to i16
  %296 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %295)
  %297 = trunc i32 %296 to i16
  %298 = bitcast i16 %297 to half
  %299 = zext i8 %294 to i16
  %300 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %299)
  %301 = trunc i32 %300 to i16
  %302 = bitcast i16 %301 to half
  %303 = fadd contract half %298, %302
  %304 = fpext half %303 to float
  %305 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %304)
  %306 = trunc i16 %305 to i8
  br label %267

307:                                              ; preds = %272
  %308 = phi i8 [ %269, %272 ]
  %309 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %245, 0
  %310 = trunc i64 %242 to i32
  %311 = mul i32 %310, 512
  %312 = trunc i64 %240 to i32
  %313 = add i32 %311, %312
  %314 = sext i32 %313 to i64
  %315 = getelementptr inbounds i8, ptr %309, i64 %314
  store i8 %308, ptr %315, align 1
  %316 = load { i64, i64 }, ptr %6, align 8
  %317 = add i64 %240, 1
  %318 = extractvalue { i64, i64 } %316, 1
  %319 = icmp sge i64 %317, %318
  %320 = select i1 %319, i64 0, i64 %317
  %321 = add i64 %242, 1
  %322 = select i1 %319, i64 %321, i64 %242
  %323 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %324 = load i64, ptr %4, align 8
  %325 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %326 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %323, 0
  %327 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %323, 1, 1, 0
  %328 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %323, 1, 1, 1
  %329 = mul i64 %322, %328
  %330 = add i64 %329, %320
  %331 = getelementptr inbounds i8, ptr %326, i64 %330
  br label %332

332:                                              ; preds = %338, %307
  %333 = phi i64 [ 0, %307 ], [ %341, %338 ]
  %334 = phi i8 [ 0, %307 ], [ %343, %338 ]
  %335 = icmp slt i64 %333, 1
  br i1 %335, label %336, label %337

336:                                              ; preds = %332
  br label %338

337:                                              ; preds = %332
  br label %344

338:                                              ; preds = %336
  %339 = icmp eq i64 %333, 1
  %340 = add i64 %333, 1
  %341 = select i1 %339, i64 %333, i64 %340
  %342 = getelementptr inbounds i8, ptr %331, i64 %333
  %343 = load i8, ptr %342, align 1, !invariant.load !1
  br label %332

344:                                              ; preds = %337
  %345 = phi i8 [ %334, %337 ]
  %346 = call i64 @llvm.smax.i64(i64 %324, i64 1)
  br label %347

347:                                              ; preds = %373, %344
  %348 = phi i64 [ 1, %344 ], [ %356, %373 ]
  %349 = phi i8 [ %345, %344 ], [ %386, %373 ]
  %350 = icmp slt i64 %348, %346
  br i1 %350, label %351, label %352

351:                                              ; preds = %347
  br label %353

352:                                              ; preds = %347
  br label %387

353:                                              ; preds = %351
  %354 = icmp eq i64 %348, %346
  %355 = add i64 %348, 1
  %356 = select i1 %354, i64 %348, i64 %355
  %357 = mul i64 %348, %327
  %358 = add i64 %357, %329
  %359 = add i64 %358, %320
  %360 = getelementptr inbounds i8, ptr %326, i64 %359
  br label %361

361:                                              ; preds = %367, %353
  %362 = phi i64 [ 0, %353 ], [ %370, %367 ]
  %363 = phi i8 [ 0, %353 ], [ %372, %367 ]
  %364 = icmp slt i64 %362, 1
  br i1 %364, label %365, label %366

365:                                              ; preds = %361
  br label %367

366:                                              ; preds = %361
  br label %373

367:                                              ; preds = %365
  %368 = icmp eq i64 %362, 1
  %369 = add i64 %362, 1
  %370 = select i1 %368, i64 %362, i64 %369
  %371 = getelementptr inbounds i8, ptr %360, i64 %362
  %372 = load i8, ptr %371, align 1, !invariant.load !1
  br label %361

373:                                              ; preds = %366
  %374 = phi i8 [ %363, %366 ]
  %375 = zext i8 %349 to i16
  %376 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %375)
  %377 = trunc i32 %376 to i16
  %378 = bitcast i16 %377 to half
  %379 = zext i8 %374 to i16
  %380 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %379)
  %381 = trunc i32 %380 to i16
  %382 = bitcast i16 %381 to half
  %383 = fadd contract half %378, %382
  %384 = fpext half %383 to float
  %385 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %384)
  %386 = trunc i16 %385 to i8
  br label %347

387:                                              ; preds = %352
  %388 = phi i8 [ %349, %352 ]
  %389 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %325, 0
  %390 = trunc i64 %322 to i32
  %391 = mul i32 %390, 512
  %392 = trunc i64 %320 to i32
  %393 = add i32 %391, %392
  %394 = sext i32 %393 to i64
  %395 = getelementptr inbounds i8, ptr %389, i64 %394
  store i8 %388, ptr %395, align 1
  %396 = load { i64, i64 }, ptr %6, align 8
  %397 = add i64 %320, 1
  %398 = extractvalue { i64, i64 } %396, 1
  %399 = icmp sge i64 %397, %398
  %400 = select i1 %399, i64 0, i64 %397
  %401 = add i64 %322, 1
  %402 = select i1 %399, i64 %401, i64 %322
  %403 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %404 = load i64, ptr %4, align 8
  %405 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %406 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %403, 0
  %407 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %403, 1, 1, 0
  %408 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %403, 1, 1, 1
  %409 = mul i64 %402, %408
  %410 = add i64 %409, %400
  %411 = getelementptr inbounds i8, ptr %406, i64 %410
  br label %412

412:                                              ; preds = %418, %387
  %413 = phi i64 [ 0, %387 ], [ %421, %418 ]
  %414 = phi i8 [ 0, %387 ], [ %423, %418 ]
  %415 = icmp slt i64 %413, 1
  br i1 %415, label %416, label %417

416:                                              ; preds = %412
  br label %418

417:                                              ; preds = %412
  br label %424

418:                                              ; preds = %416
  %419 = icmp eq i64 %413, 1
  %420 = add i64 %413, 1
  %421 = select i1 %419, i64 %413, i64 %420
  %422 = getelementptr inbounds i8, ptr %411, i64 %413
  %423 = load i8, ptr %422, align 1, !invariant.load !1
  br label %412

424:                                              ; preds = %417
  %425 = phi i8 [ %414, %417 ]
  %426 = call i64 @llvm.smax.i64(i64 %404, i64 1)
  br label %427

427:                                              ; preds = %453, %424
  %428 = phi i64 [ 1, %424 ], [ %436, %453 ]
  %429 = phi i8 [ %425, %424 ], [ %466, %453 ]
  %430 = icmp slt i64 %428, %426
  br i1 %430, label %431, label %432

431:                                              ; preds = %427
  br label %433

432:                                              ; preds = %427
  br label %467

433:                                              ; preds = %431
  %434 = icmp eq i64 %428, %426
  %435 = add i64 %428, 1
  %436 = select i1 %434, i64 %428, i64 %435
  %437 = mul i64 %428, %407
  %438 = add i64 %437, %409
  %439 = add i64 %438, %400
  %440 = getelementptr inbounds i8, ptr %406, i64 %439
  br label %441

441:                                              ; preds = %447, %433
  %442 = phi i64 [ 0, %433 ], [ %450, %447 ]
  %443 = phi i8 [ 0, %433 ], [ %452, %447 ]
  %444 = icmp slt i64 %442, 1
  br i1 %444, label %445, label %446

445:                                              ; preds = %441
  br label %447

446:                                              ; preds = %441
  br label %453

447:                                              ; preds = %445
  %448 = icmp eq i64 %442, 1
  %449 = add i64 %442, 1
  %450 = select i1 %448, i64 %442, i64 %449
  %451 = getelementptr inbounds i8, ptr %440, i64 %442
  %452 = load i8, ptr %451, align 1, !invariant.load !1
  br label %441

453:                                              ; preds = %446
  %454 = phi i8 [ %443, %446 ]
  %455 = zext i8 %429 to i16
  %456 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %455)
  %457 = trunc i32 %456 to i16
  %458 = bitcast i16 %457 to half
  %459 = zext i8 %454 to i16
  %460 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %459)
  %461 = trunc i32 %460 to i16
  %462 = bitcast i16 %461 to half
  %463 = fadd contract half %458, %462
  %464 = fpext half %463 to float
  %465 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %464)
  %466 = trunc i16 %465 to i8
  br label %427

467:                                              ; preds = %432
  %468 = phi i8 [ %429, %432 ]
  %469 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %405, 0
  %470 = trunc i64 %402 to i32
  %471 = mul i32 %470, 512
  %472 = trunc i64 %400 to i32
  %473 = add i32 %471, %472
  %474 = sext i32 %473 to i64
  %475 = getelementptr inbounds i8, ptr %469, i64 %474
  store i8 %468, ptr %475, align 1
  %476 = load { i64, i64 }, ptr %6, align 8
  %477 = add i64 %400, 1
  %478 = extractvalue { i64, i64 } %476, 1
  %479 = icmp sge i64 %477, %478
  %480 = select i1 %479, i64 0, i64 %477
  %481 = add i64 %402, 1
  %482 = select i1 %479, i64 %481, i64 %402
  %483 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %484 = load i64, ptr %4, align 8
  %485 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %486 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %483, 0
  %487 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %483, 1, 1, 0
  %488 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %483, 1, 1, 1
  %489 = mul i64 %482, %488
  %490 = add i64 %489, %480
  %491 = getelementptr inbounds i8, ptr %486, i64 %490
  br label %492

492:                                              ; preds = %498, %467
  %493 = phi i64 [ 0, %467 ], [ %501, %498 ]
  %494 = phi i8 [ 0, %467 ], [ %503, %498 ]
  %495 = icmp slt i64 %493, 1
  br i1 %495, label %496, label %497

496:                                              ; preds = %492
  br label %498

497:                                              ; preds = %492
  br label %504

498:                                              ; preds = %496
  %499 = icmp eq i64 %493, 1
  %500 = add i64 %493, 1
  %501 = select i1 %499, i64 %493, i64 %500
  %502 = getelementptr inbounds i8, ptr %491, i64 %493
  %503 = load i8, ptr %502, align 1, !invariant.load !1
  br label %492

504:                                              ; preds = %497
  %505 = phi i8 [ %494, %497 ]
  %506 = call i64 @llvm.smax.i64(i64 %484, i64 1)
  br label %507

507:                                              ; preds = %533, %504
  %508 = phi i64 [ 1, %504 ], [ %516, %533 ]
  %509 = phi i8 [ %505, %504 ], [ %546, %533 ]
  %510 = icmp slt i64 %508, %506
  br i1 %510, label %511, label %512

511:                                              ; preds = %507
  br label %513

512:                                              ; preds = %507
  br label %547

513:                                              ; preds = %511
  %514 = icmp eq i64 %508, %506
  %515 = add i64 %508, 1
  %516 = select i1 %514, i64 %508, i64 %515
  %517 = mul i64 %508, %487
  %518 = add i64 %517, %489
  %519 = add i64 %518, %480
  %520 = getelementptr inbounds i8, ptr %486, i64 %519
  br label %521

521:                                              ; preds = %527, %513
  %522 = phi i64 [ 0, %513 ], [ %530, %527 ]
  %523 = phi i8 [ 0, %513 ], [ %532, %527 ]
  %524 = icmp slt i64 %522, 1
  br i1 %524, label %525, label %526

525:                                              ; preds = %521
  br label %527

526:                                              ; preds = %521
  br label %533

527:                                              ; preds = %525
  %528 = icmp eq i64 %522, 1
  %529 = add i64 %522, 1
  %530 = select i1 %528, i64 %522, i64 %529
  %531 = getelementptr inbounds i8, ptr %520, i64 %522
  %532 = load i8, ptr %531, align 1, !invariant.load !1
  br label %521

533:                                              ; preds = %526
  %534 = phi i8 [ %523, %526 ]
  %535 = zext i8 %509 to i16
  %536 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %535)
  %537 = trunc i32 %536 to i16
  %538 = bitcast i16 %537 to half
  %539 = zext i8 %534 to i16
  %540 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %539)
  %541 = trunc i32 %540 to i16
  %542 = bitcast i16 %541 to half
  %543 = fadd contract half %538, %542
  %544 = fpext half %543 to float
  %545 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %544)
  %546 = trunc i16 %545 to i8
  br label %507

547:                                              ; preds = %512
  %548 = phi i8 [ %509, %512 ]
  %549 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %485, 0
  %550 = trunc i64 %482 to i32
  %551 = mul i32 %550, 512
  %552 = trunc i64 %480 to i32
  %553 = add i32 %551, %552
  %554 = sext i32 %553 to i64
  %555 = getelementptr inbounds i8, ptr %549, i64 %554
  store i8 %548, ptr %555, align 1
  %556 = load { i64, i64 }, ptr %6, align 8
  %557 = add i64 %480, 1
  %558 = extractvalue { i64, i64 } %556, 1
  %559 = icmp sge i64 %557, %558
  %560 = select i1 %559, i64 0, i64 %557
  %561 = add i64 %482, 1
  %562 = select i1 %559, i64 %561, i64 %482
  %563 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %564 = load i64, ptr %4, align 8
  %565 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %566 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %563, 0
  %567 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %563, 1, 1, 0
  %568 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %563, 1, 1, 1
  %569 = mul i64 %562, %568
  %570 = add i64 %569, %560
  %571 = getelementptr inbounds i8, ptr %566, i64 %570
  br label %572

572:                                              ; preds = %578, %547
  %573 = phi i64 [ 0, %547 ], [ %581, %578 ]
  %574 = phi i8 [ 0, %547 ], [ %583, %578 ]
  %575 = icmp slt i64 %573, 1
  br i1 %575, label %576, label %577

576:                                              ; preds = %572
  br label %578

577:                                              ; preds = %572
  br label %584

578:                                              ; preds = %576
  %579 = icmp eq i64 %573, 1
  %580 = add i64 %573, 1
  %581 = select i1 %579, i64 %573, i64 %580
  %582 = getelementptr inbounds i8, ptr %571, i64 %573
  %583 = load i8, ptr %582, align 1, !invariant.load !1
  br label %572

584:                                              ; preds = %577
  %585 = phi i8 [ %574, %577 ]
  %586 = call i64 @llvm.smax.i64(i64 %564, i64 1)
  br label %587

587:                                              ; preds = %613, %584
  %588 = phi i64 [ 1, %584 ], [ %596, %613 ]
  %589 = phi i8 [ %585, %584 ], [ %626, %613 ]
  %590 = icmp slt i64 %588, %586
  br i1 %590, label %591, label %592

591:                                              ; preds = %587
  br label %593

592:                                              ; preds = %587
  br label %627

593:                                              ; preds = %591
  %594 = icmp eq i64 %588, %586
  %595 = add i64 %588, 1
  %596 = select i1 %594, i64 %588, i64 %595
  %597 = mul i64 %588, %567
  %598 = add i64 %597, %569
  %599 = add i64 %598, %560
  %600 = getelementptr inbounds i8, ptr %566, i64 %599
  br label %601

601:                                              ; preds = %607, %593
  %602 = phi i64 [ 0, %593 ], [ %610, %607 ]
  %603 = phi i8 [ 0, %593 ], [ %612, %607 ]
  %604 = icmp slt i64 %602, 1
  br i1 %604, label %605, label %606

605:                                              ; preds = %601
  br label %607

606:                                              ; preds = %601
  br label %613

607:                                              ; preds = %605
  %608 = icmp eq i64 %602, 1
  %609 = add i64 %602, 1
  %610 = select i1 %608, i64 %602, i64 %609
  %611 = getelementptr inbounds i8, ptr %600, i64 %602
  %612 = load i8, ptr %611, align 1, !invariant.load !1
  br label %601

613:                                              ; preds = %606
  %614 = phi i8 [ %603, %606 ]
  %615 = zext i8 %589 to i16
  %616 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %615)
  %617 = trunc i32 %616 to i16
  %618 = bitcast i16 %617 to half
  %619 = zext i8 %614 to i16
  %620 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %619)
  %621 = trunc i32 %620 to i16
  %622 = bitcast i16 %621 to half
  %623 = fadd contract half %618, %622
  %624 = fpext half %623 to float
  %625 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %624)
  %626 = trunc i16 %625 to i8
  br label %587

627:                                              ; preds = %592
  %628 = phi i8 [ %589, %592 ]
  %629 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %565, 0
  %630 = trunc i64 %562 to i32
  %631 = mul i32 %630, 512
  %632 = trunc i64 %560 to i32
  %633 = add i32 %631, %632
  %634 = sext i32 %633 to i64
  %635 = getelementptr inbounds i8, ptr %629, i64 %634
  store i8 %628, ptr %635, align 1
  %636 = load { i64, i64 }, ptr %6, align 8
  %637 = add i64 %560, 1
  %638 = extractvalue { i64, i64 } %636, 1
  %639 = icmp sge i64 %637, %638
  %640 = select i1 %639, i64 0, i64 %637
  %641 = add i64 %562, 1
  %642 = select i1 %639, i64 %641, i64 %562
  %643 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %644 = load i64, ptr %4, align 8
  %645 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %646 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %643, 0
  %647 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %643, 1, 1, 0
  %648 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %643, 1, 1, 1
  %649 = mul i64 %642, %648
  %650 = add i64 %649, %640
  %651 = getelementptr inbounds i8, ptr %646, i64 %650
  br label %652

652:                                              ; preds = %658, %627
  %653 = phi i64 [ 0, %627 ], [ %661, %658 ]
  %654 = phi i8 [ 0, %627 ], [ %663, %658 ]
  %655 = icmp slt i64 %653, 1
  br i1 %655, label %656, label %657

656:                                              ; preds = %652
  br label %658

657:                                              ; preds = %652
  br label %664

658:                                              ; preds = %656
  %659 = icmp eq i64 %653, 1
  %660 = add i64 %653, 1
  %661 = select i1 %659, i64 %653, i64 %660
  %662 = getelementptr inbounds i8, ptr %651, i64 %653
  %663 = load i8, ptr %662, align 1, !invariant.load !1
  br label %652

664:                                              ; preds = %657
  %665 = phi i8 [ %654, %657 ]
  %666 = call i64 @llvm.smax.i64(i64 %644, i64 1)
  br label %667

667:                                              ; preds = %693, %664
  %668 = phi i64 [ 1, %664 ], [ %676, %693 ]
  %669 = phi i8 [ %665, %664 ], [ %706, %693 ]
  %670 = icmp slt i64 %668, %666
  br i1 %670, label %671, label %672

671:                                              ; preds = %667
  br label %673

672:                                              ; preds = %667
  br label %707

673:                                              ; preds = %671
  %674 = icmp eq i64 %668, %666
  %675 = add i64 %668, 1
  %676 = select i1 %674, i64 %668, i64 %675
  %677 = mul i64 %668, %647
  %678 = add i64 %677, %649
  %679 = add i64 %678, %640
  %680 = getelementptr inbounds i8, ptr %646, i64 %679
  br label %681

681:                                              ; preds = %687, %673
  %682 = phi i64 [ 0, %673 ], [ %690, %687 ]
  %683 = phi i8 [ 0, %673 ], [ %692, %687 ]
  %684 = icmp slt i64 %682, 1
  br i1 %684, label %685, label %686

685:                                              ; preds = %681
  br label %687

686:                                              ; preds = %681
  br label %693

687:                                              ; preds = %685
  %688 = icmp eq i64 %682, 1
  %689 = add i64 %682, 1
  %690 = select i1 %688, i64 %682, i64 %689
  %691 = getelementptr inbounds i8, ptr %680, i64 %682
  %692 = load i8, ptr %691, align 1, !invariant.load !1
  br label %681

693:                                              ; preds = %686
  %694 = phi i8 [ %683, %686 ]
  %695 = zext i8 %669 to i16
  %696 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %695)
  %697 = trunc i32 %696 to i16
  %698 = bitcast i16 %697 to half
  %699 = zext i8 %694 to i16
  %700 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %699)
  %701 = trunc i32 %700 to i16
  %702 = bitcast i16 %701 to half
  %703 = fadd contract half %698, %702
  %704 = fpext half %703 to float
  %705 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %704)
  %706 = trunc i16 %705 to i8
  br label %667

707:                                              ; preds = %672
  %708 = phi i8 [ %669, %672 ]
  %709 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %645, 0
  %710 = trunc i64 %642 to i32
  %711 = mul i32 %710, 512
  %712 = trunc i64 %640 to i32
  %713 = add i32 %711, %712
  %714 = sext i32 %713 to i64
  %715 = getelementptr inbounds i8, ptr %709, i64 %714
  store i8 %708, ptr %715, align 1
  %716 = load { i64, i64 }, ptr %6, align 8
  %717 = add i64 %640, 1
  %718 = extractvalue { i64, i64 } %716, 1
  %719 = icmp sge i64 %717, %718
  %720 = select i1 %719, i64 0, i64 %717
  %721 = add i64 %642, 1
  %722 = select i1 %719, i64 %721, i64 %642
  %723 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %724 = load i64, ptr %4, align 8
  %725 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %726 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %723, 0
  %727 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %723, 1, 1, 0
  %728 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %723, 1, 1, 1
  %729 = mul i64 %722, %728
  %730 = add i64 %729, %720
  %731 = getelementptr inbounds i8, ptr %726, i64 %730
  br label %732

732:                                              ; preds = %738, %707
  %733 = phi i64 [ 0, %707 ], [ %741, %738 ]
  %734 = phi i8 [ 0, %707 ], [ %743, %738 ]
  %735 = icmp slt i64 %733, 1
  br i1 %735, label %736, label %737

736:                                              ; preds = %732
  br label %738

737:                                              ; preds = %732
  br label %744

738:                                              ; preds = %736
  %739 = icmp eq i64 %733, 1
  %740 = add i64 %733, 1
  %741 = select i1 %739, i64 %733, i64 %740
  %742 = getelementptr inbounds i8, ptr %731, i64 %733
  %743 = load i8, ptr %742, align 1, !invariant.load !1
  br label %732

744:                                              ; preds = %737
  %745 = phi i8 [ %734, %737 ]
  %746 = call i64 @llvm.smax.i64(i64 %724, i64 1)
  br label %747

747:                                              ; preds = %773, %744
  %748 = phi i64 [ 1, %744 ], [ %756, %773 ]
  %749 = phi i8 [ %745, %744 ], [ %786, %773 ]
  %750 = icmp slt i64 %748, %746
  br i1 %750, label %751, label %752

751:                                              ; preds = %747
  br label %753

752:                                              ; preds = %747
  br label %787

753:                                              ; preds = %751
  %754 = icmp eq i64 %748, %746
  %755 = add i64 %748, 1
  %756 = select i1 %754, i64 %748, i64 %755
  %757 = mul i64 %748, %727
  %758 = add i64 %757, %729
  %759 = add i64 %758, %720
  %760 = getelementptr inbounds i8, ptr %726, i64 %759
  br label %761

761:                                              ; preds = %767, %753
  %762 = phi i64 [ 0, %753 ], [ %770, %767 ]
  %763 = phi i8 [ 0, %753 ], [ %772, %767 ]
  %764 = icmp slt i64 %762, 1
  br i1 %764, label %765, label %766

765:                                              ; preds = %761
  br label %767

766:                                              ; preds = %761
  br label %773

767:                                              ; preds = %765
  %768 = icmp eq i64 %762, 1
  %769 = add i64 %762, 1
  %770 = select i1 %768, i64 %762, i64 %769
  %771 = getelementptr inbounds i8, ptr %760, i64 %762
  %772 = load i8, ptr %771, align 1, !invariant.load !1
  br label %761

773:                                              ; preds = %766
  %774 = phi i8 [ %763, %766 ]
  %775 = zext i8 %749 to i16
  %776 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %775)
  %777 = trunc i32 %776 to i16
  %778 = bitcast i16 %777 to half
  %779 = zext i8 %774 to i16
  %780 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %779)
  %781 = trunc i32 %780 to i16
  %782 = bitcast i16 %781 to half
  %783 = fadd contract half %778, %782
  %784 = fpext half %783 to float
  %785 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %784)
  %786 = trunc i16 %785 to i8
  br label %747

787:                                              ; preds = %752
  %788 = phi i8 [ %749, %752 ]
  %789 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %725, 0
  %790 = trunc i64 %722 to i32
  %791 = mul i32 %790, 512
  %792 = trunc i64 %720 to i32
  %793 = add i32 %791, %792
  %794 = sext i32 %793 to i64
  %795 = getelementptr inbounds i8, ptr %789, i64 %794
  store i8 %788, ptr %795, align 1
  %796 = load { i64, i64 }, ptr %6, align 8
  %797 = add i64 %720, 1
  %798 = extractvalue { i64, i64 } %796, 1
  %799 = icmp sge i64 %797, %798
  %800 = select i1 %799, i64 0, i64 %797
  %801 = add i64 %722, 1
  %802 = select i1 %799, i64 %801, i64 %722
  %803 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %804 = load i64, ptr %4, align 8
  %805 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %806 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %803, 0
  %807 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %803, 1, 1, 0
  %808 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %803, 1, 1, 1
  %809 = mul i64 %802, %808
  %810 = add i64 %809, %800
  %811 = getelementptr inbounds i8, ptr %806, i64 %810
  br label %812

812:                                              ; preds = %818, %787
  %813 = phi i64 [ 0, %787 ], [ %821, %818 ]
  %814 = phi i8 [ 0, %787 ], [ %823, %818 ]
  %815 = icmp slt i64 %813, 1
  br i1 %815, label %816, label %817

816:                                              ; preds = %812
  br label %818

817:                                              ; preds = %812
  br label %824

818:                                              ; preds = %816
  %819 = icmp eq i64 %813, 1
  %820 = add i64 %813, 1
  %821 = select i1 %819, i64 %813, i64 %820
  %822 = getelementptr inbounds i8, ptr %811, i64 %813
  %823 = load i8, ptr %822, align 1, !invariant.load !1
  br label %812

824:                                              ; preds = %817
  %825 = phi i8 [ %814, %817 ]
  %826 = call i64 @llvm.smax.i64(i64 %804, i64 1)
  br label %827

827:                                              ; preds = %853, %824
  %828 = phi i64 [ 1, %824 ], [ %836, %853 ]
  %829 = phi i8 [ %825, %824 ], [ %866, %853 ]
  %830 = icmp slt i64 %828, %826
  br i1 %830, label %831, label %832

831:                                              ; preds = %827
  br label %833

832:                                              ; preds = %827
  br label %867

833:                                              ; preds = %831
  %834 = icmp eq i64 %828, %826
  %835 = add i64 %828, 1
  %836 = select i1 %834, i64 %828, i64 %835
  %837 = mul i64 %828, %807
  %838 = add i64 %837, %809
  %839 = add i64 %838, %800
  %840 = getelementptr inbounds i8, ptr %806, i64 %839
  br label %841

841:                                              ; preds = %847, %833
  %842 = phi i64 [ 0, %833 ], [ %850, %847 ]
  %843 = phi i8 [ 0, %833 ], [ %852, %847 ]
  %844 = icmp slt i64 %842, 1
  br i1 %844, label %845, label %846

845:                                              ; preds = %841
  br label %847

846:                                              ; preds = %841
  br label %853

847:                                              ; preds = %845
  %848 = icmp eq i64 %842, 1
  %849 = add i64 %842, 1
  %850 = select i1 %848, i64 %842, i64 %849
  %851 = getelementptr inbounds i8, ptr %840, i64 %842
  %852 = load i8, ptr %851, align 1, !invariant.load !1
  br label %841

853:                                              ; preds = %846
  %854 = phi i8 [ %843, %846 ]
  %855 = zext i8 %829 to i16
  %856 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %855)
  %857 = trunc i32 %856 to i16
  %858 = bitcast i16 %857 to half
  %859 = zext i8 %854 to i16
  %860 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %859)
  %861 = trunc i32 %860 to i16
  %862 = bitcast i16 %861 to half
  %863 = fadd contract half %858, %862
  %864 = fpext half %863 to float
  %865 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %864)
  %866 = trunc i16 %865 to i8
  br label %827

867:                                              ; preds = %832
  %868 = phi i8 [ %829, %832 ]
  %869 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %805, 0
  %870 = trunc i64 %802 to i32
  %871 = mul i32 %870, 512
  %872 = trunc i64 %800 to i32
  %873 = add i32 %871, %872
  %874 = sext i32 %873 to i64
  %875 = getelementptr inbounds i8, ptr %869, i64 %874
  store i8 %868, ptr %875, align 1
  %876 = load { i64, i64 }, ptr %6, align 8
  %877 = add i64 %800, 1
  %878 = extractvalue { i64, i64 } %876, 1
  %879 = icmp sge i64 %877, %878
  %880 = select i1 %879, i64 0, i64 %877
  %881 = add i64 %802, 1
  %882 = select i1 %879, i64 %881, i64 %802
  %883 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %884 = load i64, ptr %4, align 8
  %885 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %886 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %883, 0
  %887 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %883, 1, 1, 0
  %888 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %883, 1, 1, 1
  %889 = mul i64 %882, %888
  %890 = add i64 %889, %880
  %891 = getelementptr inbounds i8, ptr %886, i64 %890
  br label %892

892:                                              ; preds = %898, %867
  %893 = phi i64 [ 0, %867 ], [ %901, %898 ]
  %894 = phi i8 [ 0, %867 ], [ %903, %898 ]
  %895 = icmp slt i64 %893, 1
  br i1 %895, label %896, label %897

896:                                              ; preds = %892
  br label %898

897:                                              ; preds = %892
  br label %904

898:                                              ; preds = %896
  %899 = icmp eq i64 %893, 1
  %900 = add i64 %893, 1
  %901 = select i1 %899, i64 %893, i64 %900
  %902 = getelementptr inbounds i8, ptr %891, i64 %893
  %903 = load i8, ptr %902, align 1, !invariant.load !1
  br label %892

904:                                              ; preds = %897
  %905 = phi i8 [ %894, %897 ]
  %906 = call i64 @llvm.smax.i64(i64 %884, i64 1)
  br label %907

907:                                              ; preds = %933, %904
  %908 = phi i64 [ 1, %904 ], [ %916, %933 ]
  %909 = phi i8 [ %905, %904 ], [ %946, %933 ]
  %910 = icmp slt i64 %908, %906
  br i1 %910, label %911, label %912

911:                                              ; preds = %907
  br label %913

912:                                              ; preds = %907
  br label %947

913:                                              ; preds = %911
  %914 = icmp eq i64 %908, %906
  %915 = add i64 %908, 1
  %916 = select i1 %914, i64 %908, i64 %915
  %917 = mul i64 %908, %887
  %918 = add i64 %917, %889
  %919 = add i64 %918, %880
  %920 = getelementptr inbounds i8, ptr %886, i64 %919
  br label %921

921:                                              ; preds = %927, %913
  %922 = phi i64 [ 0, %913 ], [ %930, %927 ]
  %923 = phi i8 [ 0, %913 ], [ %932, %927 ]
  %924 = icmp slt i64 %922, 1
  br i1 %924, label %925, label %926

925:                                              ; preds = %921
  br label %927

926:                                              ; preds = %921
  br label %933

927:                                              ; preds = %925
  %928 = icmp eq i64 %922, 1
  %929 = add i64 %922, 1
  %930 = select i1 %928, i64 %922, i64 %929
  %931 = getelementptr inbounds i8, ptr %920, i64 %922
  %932 = load i8, ptr %931, align 1, !invariant.load !1
  br label %921

933:                                              ; preds = %926
  %934 = phi i8 [ %923, %926 ]
  %935 = zext i8 %909 to i16
  %936 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %935)
  %937 = trunc i32 %936 to i16
  %938 = bitcast i16 %937 to half
  %939 = zext i8 %934 to i16
  %940 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %939)
  %941 = trunc i32 %940 to i16
  %942 = bitcast i16 %941 to half
  %943 = fadd contract half %938, %942
  %944 = fpext half %943 to float
  %945 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %944)
  %946 = trunc i16 %945 to i8
  br label %907

947:                                              ; preds = %912
  %948 = phi i8 [ %909, %912 ]
  %949 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %885, 0
  %950 = trunc i64 %882 to i32
  %951 = mul i32 %950, 512
  %952 = trunc i64 %880 to i32
  %953 = add i32 %951, %952
  %954 = sext i32 %953 to i64
  %955 = getelementptr inbounds i8, ptr %949, i64 %954
  store i8 %948, ptr %955, align 1
  %956 = load { i64, i64 }, ptr %6, align 8
  %957 = add i64 %880, 1
  %958 = extractvalue { i64, i64 } %956, 1
  %959 = icmp sge i64 %957, %958
  %960 = select i1 %959, i64 0, i64 %957
  %961 = add i64 %882, 1
  %962 = select i1 %959, i64 %961, i64 %882
  %963 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %964 = load i64, ptr %4, align 8
  %965 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %966 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %963, 0
  %967 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %963, 1, 1, 0
  %968 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %963, 1, 1, 1
  %969 = mul i64 %962, %968
  %970 = add i64 %969, %960
  %971 = getelementptr inbounds i8, ptr %966, i64 %970
  br label %972

972:                                              ; preds = %978, %947
  %973 = phi i64 [ 0, %947 ], [ %981, %978 ]
  %974 = phi i8 [ 0, %947 ], [ %983, %978 ]
  %975 = icmp slt i64 %973, 1
  br i1 %975, label %976, label %977

976:                                              ; preds = %972
  br label %978

977:                                              ; preds = %972
  br label %984

978:                                              ; preds = %976
  %979 = icmp eq i64 %973, 1
  %980 = add i64 %973, 1
  %981 = select i1 %979, i64 %973, i64 %980
  %982 = getelementptr inbounds i8, ptr %971, i64 %973
  %983 = load i8, ptr %982, align 1, !invariant.load !1
  br label %972

984:                                              ; preds = %977
  %985 = phi i8 [ %974, %977 ]
  %986 = call i64 @llvm.smax.i64(i64 %964, i64 1)
  br label %987

987:                                              ; preds = %1013, %984
  %988 = phi i64 [ 1, %984 ], [ %996, %1013 ]
  %989 = phi i8 [ %985, %984 ], [ %1026, %1013 ]
  %990 = icmp slt i64 %988, %986
  br i1 %990, label %991, label %992

991:                                              ; preds = %987
  br label %993

992:                                              ; preds = %987
  br label %1027

993:                                              ; preds = %991
  %994 = icmp eq i64 %988, %986
  %995 = add i64 %988, 1
  %996 = select i1 %994, i64 %988, i64 %995
  %997 = mul i64 %988, %967
  %998 = add i64 %997, %969
  %999 = add i64 %998, %960
  %1000 = getelementptr inbounds i8, ptr %966, i64 %999
  br label %1001

1001:                                             ; preds = %1007, %993
  %1002 = phi i64 [ 0, %993 ], [ %1010, %1007 ]
  %1003 = phi i8 [ 0, %993 ], [ %1012, %1007 ]
  %1004 = icmp slt i64 %1002, 1
  br i1 %1004, label %1005, label %1006

1005:                                             ; preds = %1001
  br label %1007

1006:                                             ; preds = %1001
  br label %1013

1007:                                             ; preds = %1005
  %1008 = icmp eq i64 %1002, 1
  %1009 = add i64 %1002, 1
  %1010 = select i1 %1008, i64 %1002, i64 %1009
  %1011 = getelementptr inbounds i8, ptr %1000, i64 %1002
  %1012 = load i8, ptr %1011, align 1, !invariant.load !1
  br label %1001

1013:                                             ; preds = %1006
  %1014 = phi i8 [ %1003, %1006 ]
  %1015 = zext i8 %989 to i16
  %1016 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1015)
  %1017 = trunc i32 %1016 to i16
  %1018 = bitcast i16 %1017 to half
  %1019 = zext i8 %1014 to i16
  %1020 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1019)
  %1021 = trunc i32 %1020 to i16
  %1022 = bitcast i16 %1021 to half
  %1023 = fadd contract half %1018, %1022
  %1024 = fpext half %1023 to float
  %1025 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1024)
  %1026 = trunc i16 %1025 to i8
  br label %987

1027:                                             ; preds = %992
  %1028 = phi i8 [ %989, %992 ]
  %1029 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %965, 0
  %1030 = trunc i64 %962 to i32
  %1031 = mul i32 %1030, 512
  %1032 = trunc i64 %960 to i32
  %1033 = add i32 %1031, %1032
  %1034 = sext i32 %1033 to i64
  %1035 = getelementptr inbounds i8, ptr %1029, i64 %1034
  store i8 %1028, ptr %1035, align 1
  %1036 = load { i64, i64 }, ptr %6, align 8
  %1037 = add i64 %960, 1
  %1038 = extractvalue { i64, i64 } %1036, 1
  %1039 = icmp sge i64 %1037, %1038
  %1040 = select i1 %1039, i64 0, i64 %1037
  %1041 = add i64 %962, 1
  %1042 = select i1 %1039, i64 %1041, i64 %962
  %1043 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1044 = load i64, ptr %4, align 8
  %1045 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1046 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1043, 0
  %1047 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1043, 1, 1, 0
  %1048 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1043, 1, 1, 1
  %1049 = mul i64 %1042, %1048
  %1050 = add i64 %1049, %1040
  %1051 = getelementptr inbounds i8, ptr %1046, i64 %1050
  br label %1052

1052:                                             ; preds = %1058, %1027
  %1053 = phi i64 [ 0, %1027 ], [ %1061, %1058 ]
  %1054 = phi i8 [ 0, %1027 ], [ %1063, %1058 ]
  %1055 = icmp slt i64 %1053, 1
  br i1 %1055, label %1056, label %1057

1056:                                             ; preds = %1052
  br label %1058

1057:                                             ; preds = %1052
  br label %1064

1058:                                             ; preds = %1056
  %1059 = icmp eq i64 %1053, 1
  %1060 = add i64 %1053, 1
  %1061 = select i1 %1059, i64 %1053, i64 %1060
  %1062 = getelementptr inbounds i8, ptr %1051, i64 %1053
  %1063 = load i8, ptr %1062, align 1, !invariant.load !1
  br label %1052

1064:                                             ; preds = %1057
  %1065 = phi i8 [ %1054, %1057 ]
  %1066 = call i64 @llvm.smax.i64(i64 %1044, i64 1)
  br label %1067

1067:                                             ; preds = %1093, %1064
  %1068 = phi i64 [ 1, %1064 ], [ %1076, %1093 ]
  %1069 = phi i8 [ %1065, %1064 ], [ %1106, %1093 ]
  %1070 = icmp slt i64 %1068, %1066
  br i1 %1070, label %1071, label %1072

1071:                                             ; preds = %1067
  br label %1073

1072:                                             ; preds = %1067
  br label %1107

1073:                                             ; preds = %1071
  %1074 = icmp eq i64 %1068, %1066
  %1075 = add i64 %1068, 1
  %1076 = select i1 %1074, i64 %1068, i64 %1075
  %1077 = mul i64 %1068, %1047
  %1078 = add i64 %1077, %1049
  %1079 = add i64 %1078, %1040
  %1080 = getelementptr inbounds i8, ptr %1046, i64 %1079
  br label %1081

1081:                                             ; preds = %1087, %1073
  %1082 = phi i64 [ 0, %1073 ], [ %1090, %1087 ]
  %1083 = phi i8 [ 0, %1073 ], [ %1092, %1087 ]
  %1084 = icmp slt i64 %1082, 1
  br i1 %1084, label %1085, label %1086

1085:                                             ; preds = %1081
  br label %1087

1086:                                             ; preds = %1081
  br label %1093

1087:                                             ; preds = %1085
  %1088 = icmp eq i64 %1082, 1
  %1089 = add i64 %1082, 1
  %1090 = select i1 %1088, i64 %1082, i64 %1089
  %1091 = getelementptr inbounds i8, ptr %1080, i64 %1082
  %1092 = load i8, ptr %1091, align 1, !invariant.load !1
  br label %1081

1093:                                             ; preds = %1086
  %1094 = phi i8 [ %1083, %1086 ]
  %1095 = zext i8 %1069 to i16
  %1096 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1095)
  %1097 = trunc i32 %1096 to i16
  %1098 = bitcast i16 %1097 to half
  %1099 = zext i8 %1094 to i16
  %1100 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1099)
  %1101 = trunc i32 %1100 to i16
  %1102 = bitcast i16 %1101 to half
  %1103 = fadd contract half %1098, %1102
  %1104 = fpext half %1103 to float
  %1105 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1104)
  %1106 = trunc i16 %1105 to i8
  br label %1067

1107:                                             ; preds = %1072
  %1108 = phi i8 [ %1069, %1072 ]
  %1109 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1045, 0
  %1110 = trunc i64 %1042 to i32
  %1111 = mul i32 %1110, 512
  %1112 = trunc i64 %1040 to i32
  %1113 = add i32 %1111, %1112
  %1114 = sext i32 %1113 to i64
  %1115 = getelementptr inbounds i8, ptr %1109, i64 %1114
  store i8 %1108, ptr %1115, align 1
  %1116 = load { i64, i64 }, ptr %6, align 8
  %1117 = add i64 %1040, 1
  %1118 = extractvalue { i64, i64 } %1116, 1
  %1119 = icmp sge i64 %1117, %1118
  %1120 = select i1 %1119, i64 0, i64 %1117
  %1121 = add i64 %1042, 1
  %1122 = select i1 %1119, i64 %1121, i64 %1042
  %1123 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1124 = load i64, ptr %4, align 8
  %1125 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1126 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1123, 0
  %1127 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1123, 1, 1, 0
  %1128 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1123, 1, 1, 1
  %1129 = mul i64 %1122, %1128
  %1130 = add i64 %1129, %1120
  %1131 = getelementptr inbounds i8, ptr %1126, i64 %1130
  br label %1132

1132:                                             ; preds = %1138, %1107
  %1133 = phi i64 [ 0, %1107 ], [ %1141, %1138 ]
  %1134 = phi i8 [ 0, %1107 ], [ %1143, %1138 ]
  %1135 = icmp slt i64 %1133, 1
  br i1 %1135, label %1136, label %1137

1136:                                             ; preds = %1132
  br label %1138

1137:                                             ; preds = %1132
  br label %1144

1138:                                             ; preds = %1136
  %1139 = icmp eq i64 %1133, 1
  %1140 = add i64 %1133, 1
  %1141 = select i1 %1139, i64 %1133, i64 %1140
  %1142 = getelementptr inbounds i8, ptr %1131, i64 %1133
  %1143 = load i8, ptr %1142, align 1, !invariant.load !1
  br label %1132

1144:                                             ; preds = %1137
  %1145 = phi i8 [ %1134, %1137 ]
  %1146 = call i64 @llvm.smax.i64(i64 %1124, i64 1)
  br label %1147

1147:                                             ; preds = %1173, %1144
  %1148 = phi i64 [ 1, %1144 ], [ %1156, %1173 ]
  %1149 = phi i8 [ %1145, %1144 ], [ %1186, %1173 ]
  %1150 = icmp slt i64 %1148, %1146
  br i1 %1150, label %1151, label %1152

1151:                                             ; preds = %1147
  br label %1153

1152:                                             ; preds = %1147
  br label %1187

1153:                                             ; preds = %1151
  %1154 = icmp eq i64 %1148, %1146
  %1155 = add i64 %1148, 1
  %1156 = select i1 %1154, i64 %1148, i64 %1155
  %1157 = mul i64 %1148, %1127
  %1158 = add i64 %1157, %1129
  %1159 = add i64 %1158, %1120
  %1160 = getelementptr inbounds i8, ptr %1126, i64 %1159
  br label %1161

1161:                                             ; preds = %1167, %1153
  %1162 = phi i64 [ 0, %1153 ], [ %1170, %1167 ]
  %1163 = phi i8 [ 0, %1153 ], [ %1172, %1167 ]
  %1164 = icmp slt i64 %1162, 1
  br i1 %1164, label %1165, label %1166

1165:                                             ; preds = %1161
  br label %1167

1166:                                             ; preds = %1161
  br label %1173

1167:                                             ; preds = %1165
  %1168 = icmp eq i64 %1162, 1
  %1169 = add i64 %1162, 1
  %1170 = select i1 %1168, i64 %1162, i64 %1169
  %1171 = getelementptr inbounds i8, ptr %1160, i64 %1162
  %1172 = load i8, ptr %1171, align 1, !invariant.load !1
  br label %1161

1173:                                             ; preds = %1166
  %1174 = phi i8 [ %1163, %1166 ]
  %1175 = zext i8 %1149 to i16
  %1176 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1175)
  %1177 = trunc i32 %1176 to i16
  %1178 = bitcast i16 %1177 to half
  %1179 = zext i8 %1174 to i16
  %1180 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1179)
  %1181 = trunc i32 %1180 to i16
  %1182 = bitcast i16 %1181 to half
  %1183 = fadd contract half %1178, %1182
  %1184 = fpext half %1183 to float
  %1185 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1184)
  %1186 = trunc i16 %1185 to i8
  br label %1147

1187:                                             ; preds = %1152
  %1188 = phi i8 [ %1149, %1152 ]
  %1189 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1125, 0
  %1190 = trunc i64 %1122 to i32
  %1191 = mul i32 %1190, 512
  %1192 = trunc i64 %1120 to i32
  %1193 = add i32 %1191, %1192
  %1194 = sext i32 %1193 to i64
  %1195 = getelementptr inbounds i8, ptr %1189, i64 %1194
  store i8 %1188, ptr %1195, align 1
  %1196 = load { i64, i64 }, ptr %6, align 8
  %1197 = add i64 %1120, 1
  %1198 = extractvalue { i64, i64 } %1196, 1
  %1199 = icmp sge i64 %1197, %1198
  %1200 = select i1 %1199, i64 0, i64 %1197
  %1201 = add i64 %1122, 1
  %1202 = select i1 %1199, i64 %1201, i64 %1122
  %1203 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1204 = load i64, ptr %4, align 8
  %1205 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1206 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1203, 0
  %1207 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1203, 1, 1, 0
  %1208 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1203, 1, 1, 1
  %1209 = mul i64 %1202, %1208
  %1210 = add i64 %1209, %1200
  %1211 = getelementptr inbounds i8, ptr %1206, i64 %1210
  br label %1212

1212:                                             ; preds = %1218, %1187
  %1213 = phi i64 [ 0, %1187 ], [ %1221, %1218 ]
  %1214 = phi i8 [ 0, %1187 ], [ %1223, %1218 ]
  %1215 = icmp slt i64 %1213, 1
  br i1 %1215, label %1216, label %1217

1216:                                             ; preds = %1212
  br label %1218

1217:                                             ; preds = %1212
  br label %1224

1218:                                             ; preds = %1216
  %1219 = icmp eq i64 %1213, 1
  %1220 = add i64 %1213, 1
  %1221 = select i1 %1219, i64 %1213, i64 %1220
  %1222 = getelementptr inbounds i8, ptr %1211, i64 %1213
  %1223 = load i8, ptr %1222, align 1, !invariant.load !1
  br label %1212

1224:                                             ; preds = %1217
  %1225 = phi i8 [ %1214, %1217 ]
  %1226 = call i64 @llvm.smax.i64(i64 %1204, i64 1)
  br label %1227

1227:                                             ; preds = %1253, %1224
  %1228 = phi i64 [ 1, %1224 ], [ %1236, %1253 ]
  %1229 = phi i8 [ %1225, %1224 ], [ %1266, %1253 ]
  %1230 = icmp slt i64 %1228, %1226
  br i1 %1230, label %1231, label %1232

1231:                                             ; preds = %1227
  br label %1233

1232:                                             ; preds = %1227
  br label %1267

1233:                                             ; preds = %1231
  %1234 = icmp eq i64 %1228, %1226
  %1235 = add i64 %1228, 1
  %1236 = select i1 %1234, i64 %1228, i64 %1235
  %1237 = mul i64 %1228, %1207
  %1238 = add i64 %1237, %1209
  %1239 = add i64 %1238, %1200
  %1240 = getelementptr inbounds i8, ptr %1206, i64 %1239
  br label %1241

1241:                                             ; preds = %1247, %1233
  %1242 = phi i64 [ 0, %1233 ], [ %1250, %1247 ]
  %1243 = phi i8 [ 0, %1233 ], [ %1252, %1247 ]
  %1244 = icmp slt i64 %1242, 1
  br i1 %1244, label %1245, label %1246

1245:                                             ; preds = %1241
  br label %1247

1246:                                             ; preds = %1241
  br label %1253

1247:                                             ; preds = %1245
  %1248 = icmp eq i64 %1242, 1
  %1249 = add i64 %1242, 1
  %1250 = select i1 %1248, i64 %1242, i64 %1249
  %1251 = getelementptr inbounds i8, ptr %1240, i64 %1242
  %1252 = load i8, ptr %1251, align 1, !invariant.load !1
  br label %1241

1253:                                             ; preds = %1246
  %1254 = phi i8 [ %1243, %1246 ]
  %1255 = zext i8 %1229 to i16
  %1256 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1255)
  %1257 = trunc i32 %1256 to i16
  %1258 = bitcast i16 %1257 to half
  %1259 = zext i8 %1254 to i16
  %1260 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1259)
  %1261 = trunc i32 %1260 to i16
  %1262 = bitcast i16 %1261 to half
  %1263 = fadd contract half %1258, %1262
  %1264 = fpext half %1263 to float
  %1265 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1264)
  %1266 = trunc i16 %1265 to i8
  br label %1227

1267:                                             ; preds = %1232
  %1268 = phi i8 [ %1229, %1232 ]
  %1269 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1205, 0
  %1270 = trunc i64 %1202 to i32
  %1271 = mul i32 %1270, 512
  %1272 = trunc i64 %1200 to i32
  %1273 = add i32 %1271, %1272
  %1274 = sext i32 %1273 to i64
  %1275 = getelementptr inbounds i8, ptr %1269, i64 %1274
  store i8 %1268, ptr %1275, align 1
  %1276 = load { i64, i64 }, ptr %6, align 8
  %1277 = add i64 %1200, 1
  %1278 = extractvalue { i64, i64 } %1276, 1
  %1279 = icmp sge i64 %1277, %1278
  %1280 = select i1 %1279, i64 0, i64 %1277
  %1281 = add i64 %1202, 1
  %1282 = select i1 %1279, i64 %1281, i64 %1202
  %1283 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1284 = load i64, ptr %4, align 8
  %1285 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1286 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1283, 0
  %1287 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1283, 1, 1, 0
  %1288 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1283, 1, 1, 1
  %1289 = mul i64 %1282, %1288
  %1290 = add i64 %1289, %1280
  %1291 = getelementptr inbounds i8, ptr %1286, i64 %1290
  br label %1292

1292:                                             ; preds = %1298, %1267
  %1293 = phi i64 [ 0, %1267 ], [ %1301, %1298 ]
  %1294 = phi i8 [ 0, %1267 ], [ %1303, %1298 ]
  %1295 = icmp slt i64 %1293, 1
  br i1 %1295, label %1296, label %1297

1296:                                             ; preds = %1292
  br label %1298

1297:                                             ; preds = %1292
  br label %1304

1298:                                             ; preds = %1296
  %1299 = icmp eq i64 %1293, 1
  %1300 = add i64 %1293, 1
  %1301 = select i1 %1299, i64 %1293, i64 %1300
  %1302 = getelementptr inbounds i8, ptr %1291, i64 %1293
  %1303 = load i8, ptr %1302, align 1, !invariant.load !1
  br label %1292

1304:                                             ; preds = %1297
  %1305 = phi i8 [ %1294, %1297 ]
  %1306 = call i64 @llvm.smax.i64(i64 %1284, i64 1)
  br label %1307

1307:                                             ; preds = %1333, %1304
  %1308 = phi i64 [ 1, %1304 ], [ %1316, %1333 ]
  %1309 = phi i8 [ %1305, %1304 ], [ %1346, %1333 ]
  %1310 = icmp slt i64 %1308, %1306
  br i1 %1310, label %1311, label %1312

1311:                                             ; preds = %1307
  br label %1313

1312:                                             ; preds = %1307
  br label %1347

1313:                                             ; preds = %1311
  %1314 = icmp eq i64 %1308, %1306
  %1315 = add i64 %1308, 1
  %1316 = select i1 %1314, i64 %1308, i64 %1315
  %1317 = mul i64 %1308, %1287
  %1318 = add i64 %1317, %1289
  %1319 = add i64 %1318, %1280
  %1320 = getelementptr inbounds i8, ptr %1286, i64 %1319
  br label %1321

1321:                                             ; preds = %1327, %1313
  %1322 = phi i64 [ 0, %1313 ], [ %1330, %1327 ]
  %1323 = phi i8 [ 0, %1313 ], [ %1332, %1327 ]
  %1324 = icmp slt i64 %1322, 1
  br i1 %1324, label %1325, label %1326

1325:                                             ; preds = %1321
  br label %1327

1326:                                             ; preds = %1321
  br label %1333

1327:                                             ; preds = %1325
  %1328 = icmp eq i64 %1322, 1
  %1329 = add i64 %1322, 1
  %1330 = select i1 %1328, i64 %1322, i64 %1329
  %1331 = getelementptr inbounds i8, ptr %1320, i64 %1322
  %1332 = load i8, ptr %1331, align 1, !invariant.load !1
  br label %1321

1333:                                             ; preds = %1326
  %1334 = phi i8 [ %1323, %1326 ]
  %1335 = zext i8 %1309 to i16
  %1336 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1335)
  %1337 = trunc i32 %1336 to i16
  %1338 = bitcast i16 %1337 to half
  %1339 = zext i8 %1334 to i16
  %1340 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1339)
  %1341 = trunc i32 %1340 to i16
  %1342 = bitcast i16 %1341 to half
  %1343 = fadd contract half %1338, %1342
  %1344 = fpext half %1343 to float
  %1345 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1344)
  %1346 = trunc i16 %1345 to i8
  br label %1307

1347:                                             ; preds = %1312
  %1348 = phi i8 [ %1309, %1312 ]
  %1349 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1285, 0
  %1350 = trunc i64 %1282 to i32
  %1351 = mul i32 %1350, 512
  %1352 = trunc i64 %1280 to i32
  %1353 = add i32 %1351, %1352
  %1354 = sext i32 %1353 to i64
  %1355 = getelementptr inbounds i8, ptr %1349, i64 %1354
  store i8 %1348, ptr %1355, align 1
  br label %1474

1356:                                             ; preds = %63
  %1357 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1358 = load i64, ptr %4, align 8
  %1359 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1360 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1357, 0
  %1361 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1357, 1, 1, 0
  %1362 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1357, 1, 1, 1
  %1363 = mul i64 %80, %1362
  %1364 = add i64 %1363, %77
  %1365 = getelementptr inbounds i8, ptr %1360, i64 %1364
  %1366 = load <16 x i8>, ptr %1365, align 16, !invariant.load !1
  %1367 = call i64 @llvm.smax.i64(i64 %1358, i64 1)
  br label %1368

1368:                                             ; preds = %1374, %1356
  %1369 = phi i64 [ 1, %1356 ], [ %1377, %1374 ]
  %1370 = phi <16 x i8> [ %1366, %1356 ], [ %1469, %1374 ]
  %1371 = icmp slt i64 %1369, %1367
  br i1 %1371, label %1372, label %1373

1372:                                             ; preds = %1368
  br label %1374

1373:                                             ; preds = %1368
  br label %1470

1374:                                             ; preds = %1372
  %1375 = icmp eq i64 %1369, %1367
  %1376 = add i64 %1369, 1
  %1377 = select i1 %1375, i64 %1369, i64 %1376
  %1378 = mul i64 %1369, %1361
  %1379 = add i64 %1378, %1363
  %1380 = add i64 %1379, %77
  %1381 = getelementptr inbounds i8, ptr %1360, i64 %1380
  %1382 = load <16 x i8>, ptr %1381, align 16, !invariant.load !1
  %1383 = bitcast <16 x i8> %1370 to <8 x i16>
  %1384 = extractelement <8 x i16> %1383, i32 0
  %1385 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1384)
  %1386 = insertelement <8 x i32> undef, i32 %1385, i32 0
  %1387 = extractelement <8 x i16> %1383, i32 1
  %1388 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1387)
  %1389 = insertelement <8 x i32> %1386, i32 %1388, i32 1
  %1390 = extractelement <8 x i16> %1383, i32 2
  %1391 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1390)
  %1392 = insertelement <8 x i32> %1389, i32 %1391, i32 2
  %1393 = extractelement <8 x i16> %1383, i32 3
  %1394 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1393)
  %1395 = insertelement <8 x i32> %1392, i32 %1394, i32 3
  %1396 = extractelement <8 x i16> %1383, i32 4
  %1397 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1396)
  %1398 = insertelement <8 x i32> %1395, i32 %1397, i32 4
  %1399 = extractelement <8 x i16> %1383, i32 5
  %1400 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1399)
  %1401 = insertelement <8 x i32> %1398, i32 %1400, i32 5
  %1402 = extractelement <8 x i16> %1383, i32 6
  %1403 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1402)
  %1404 = insertelement <8 x i32> %1401, i32 %1403, i32 6
  %1405 = extractelement <8 x i16> %1383, i32 7
  %1406 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1405)
  %1407 = insertelement <8 x i32> %1404, i32 %1406, i32 7
  %1408 = bitcast <8 x i32> %1407 to <16 x half>
  %1409 = bitcast <16 x i8> %1382 to <8 x i16>
  %1410 = extractelement <8 x i16> %1409, i32 0
  %1411 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1410)
  %1412 = insertelement <8 x i32> undef, i32 %1411, i32 0
  %1413 = extractelement <8 x i16> %1409, i32 1
  %1414 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1413)
  %1415 = insertelement <8 x i32> %1412, i32 %1414, i32 1
  %1416 = extractelement <8 x i16> %1409, i32 2
  %1417 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1416)
  %1418 = insertelement <8 x i32> %1415, i32 %1417, i32 2
  %1419 = extractelement <8 x i16> %1409, i32 3
  %1420 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1419)
  %1421 = insertelement <8 x i32> %1418, i32 %1420, i32 3
  %1422 = extractelement <8 x i16> %1409, i32 4
  %1423 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1422)
  %1424 = insertelement <8 x i32> %1421, i32 %1423, i32 4
  %1425 = extractelement <8 x i16> %1409, i32 5
  %1426 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1425)
  %1427 = insertelement <8 x i32> %1424, i32 %1426, i32 5
  %1428 = extractelement <8 x i16> %1409, i32 6
  %1429 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1428)
  %1430 = insertelement <8 x i32> %1427, i32 %1429, i32 6
  %1431 = extractelement <8 x i16> %1409, i32 7
  %1432 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1431)
  %1433 = insertelement <8 x i32> %1430, i32 %1432, i32 7
  %1434 = bitcast <8 x i32> %1433 to <16 x half>
  %1435 = fadd contract <16 x half> %1408, %1434
  %1436 = fpext <16 x half> %1435 to <16 x float>
  %1437 = extractelement <16 x float> %1436, i32 1
  %1438 = extractelement <16 x float> %1436, i32 0
  %1439 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1437, float %1438)
  %1440 = insertelement <8 x i16> undef, i16 %1439, i32 0
  %1441 = extractelement <16 x float> %1436, i32 3
  %1442 = extractelement <16 x float> %1436, i32 2
  %1443 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1441, float %1442)
  %1444 = insertelement <8 x i16> %1440, i16 %1443, i32 1
  %1445 = extractelement <16 x float> %1436, i32 5
  %1446 = extractelement <16 x float> %1436, i32 4
  %1447 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1445, float %1446)
  %1448 = insertelement <8 x i16> %1444, i16 %1447, i32 2
  %1449 = extractelement <16 x float> %1436, i32 7
  %1450 = extractelement <16 x float> %1436, i32 6
  %1451 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1449, float %1450)
  %1452 = insertelement <8 x i16> %1448, i16 %1451, i32 3
  %1453 = extractelement <16 x float> %1436, i32 9
  %1454 = extractelement <16 x float> %1436, i32 8
  %1455 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1453, float %1454)
  %1456 = insertelement <8 x i16> %1452, i16 %1455, i32 4
  %1457 = extractelement <16 x float> %1436, i32 11
  %1458 = extractelement <16 x float> %1436, i32 10
  %1459 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1457, float %1458)
  %1460 = insertelement <8 x i16> %1456, i16 %1459, i32 5
  %1461 = extractelement <16 x float> %1436, i32 13
  %1462 = extractelement <16 x float> %1436, i32 12
  %1463 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1461, float %1462)
  %1464 = insertelement <8 x i16> %1460, i16 %1463, i32 6
  %1465 = extractelement <16 x float> %1436, i32 15
  %1466 = extractelement <16 x float> %1436, i32 14
  %1467 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %1465, float %1466)
  %1468 = insertelement <8 x i16> %1464, i16 %1467, i32 7
  %1469 = bitcast <8 x i16> %1468 to <16 x i8>
  br label %1368

1470:                                             ; preds = %1373
  %1471 = phi <16 x i8> [ %1370, %1373 ]
  %1472 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1359, 0
  %1473 = getelementptr inbounds i8, ptr %1472, i64 %84
  store <16 x i8> %1471, ptr %1473, align 16
  br label %1474

1474:                                             ; preds = %1470, %1347
  br label %1476

1475:                                             ; preds = %60
  br label %1476

1476:                                             ; preds = %1475, %1474
  %1477 = add i64 %53, %17
  %1478 = mul i64 %1477, 16
  %1479 = trunc i64 %1478 to i32
  %1480 = load i64, ptr %20, align 8
  %1481 = icmp slt i64 %1477, %1480
  br i1 %1481, label %1482, label %2894

1482:                                             ; preds = %1476
  %1483 = load { i64, i64 }, ptr %6, align 8
  %1484 = extractvalue { i64, i64 } %1483, 1
  %1485 = trunc i64 %1484 to i32
  %1486 = icmp eq i32 %1485, 0
  %1487 = select i1 %1486, i32 1, i32 %1485
  %1488 = icmp eq i32 %1487, 0
  %1489 = select i1 %1488, i32 1, i32 %1487
  %1490 = udiv i32 %1479, %1489
  %1491 = select i1 %1488, i32 0, i32 %1490
  %1492 = urem i32 %1479, %1489
  %1493 = select i1 %1488, i32 0, i32 %1492
  %1494 = select i1 %1486, i32 0, i32 %1491
  %1495 = select i1 %1486, i32 0, i32 %1493
  %1496 = zext i32 %1495 to i64
  %1497 = trunc i64 %1496 to i32
  %1498 = add i64 %1496, 1
  %1499 = zext i32 %1494 to i64
  %1500 = trunc i64 %1499 to i32
  %1501 = mul i32 %1500, 512
  %1502 = add i32 %1501, %1497
  %1503 = sext i32 %1502 to i64
  %1504 = add i64 %1499, 1
  %1505 = add i64 %1496, 16
  %1506 = load i64, ptr %8, align 8
  %1507 = icmp sgt i64 %1505, %1506
  br i1 %1507, label %1508, label %2775

1508:                                             ; preds = %1482
  %1509 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1510 = load i64, ptr %4, align 8
  %1511 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1512 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1509, 0
  %1513 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1509, 1, 1, 0
  %1514 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1509, 1, 1, 1
  %1515 = mul i64 %1499, %1514
  %1516 = add i64 %1515, %1496
  %1517 = getelementptr inbounds i8, ptr %1512, i64 %1516
  br label %1518

1518:                                             ; preds = %1524, %1508
  %1519 = phi i64 [ 0, %1508 ], [ %1527, %1524 ]
  %1520 = phi i8 [ 0, %1508 ], [ %1529, %1524 ]
  %1521 = icmp slt i64 %1519, 1
  br i1 %1521, label %1522, label %1523

1522:                                             ; preds = %1518
  br label %1524

1523:                                             ; preds = %1518
  br label %1530

1524:                                             ; preds = %1522
  %1525 = icmp eq i64 %1519, 1
  %1526 = add i64 %1519, 1
  %1527 = select i1 %1525, i64 %1519, i64 %1526
  %1528 = getelementptr inbounds i8, ptr %1517, i64 %1519
  %1529 = load i8, ptr %1528, align 1, !invariant.load !1
  br label %1518

1530:                                             ; preds = %1523
  %1531 = phi i8 [ %1520, %1523 ]
  %1532 = call i64 @llvm.smax.i64(i64 %1510, i64 1)
  br label %1533

1533:                                             ; preds = %1559, %1530
  %1534 = phi i64 [ 1, %1530 ], [ %1542, %1559 ]
  %1535 = phi i8 [ %1531, %1530 ], [ %1572, %1559 ]
  %1536 = icmp slt i64 %1534, %1532
  br i1 %1536, label %1537, label %1538

1537:                                             ; preds = %1533
  br label %1539

1538:                                             ; preds = %1533
  br label %1573

1539:                                             ; preds = %1537
  %1540 = icmp eq i64 %1534, %1532
  %1541 = add i64 %1534, 1
  %1542 = select i1 %1540, i64 %1534, i64 %1541
  %1543 = mul i64 %1534, %1513
  %1544 = add i64 %1543, %1515
  %1545 = add i64 %1544, %1496
  %1546 = getelementptr inbounds i8, ptr %1512, i64 %1545
  br label %1547

1547:                                             ; preds = %1553, %1539
  %1548 = phi i64 [ 0, %1539 ], [ %1556, %1553 ]
  %1549 = phi i8 [ 0, %1539 ], [ %1558, %1553 ]
  %1550 = icmp slt i64 %1548, 1
  br i1 %1550, label %1551, label %1552

1551:                                             ; preds = %1547
  br label %1553

1552:                                             ; preds = %1547
  br label %1559

1553:                                             ; preds = %1551
  %1554 = icmp eq i64 %1548, 1
  %1555 = add i64 %1548, 1
  %1556 = select i1 %1554, i64 %1548, i64 %1555
  %1557 = getelementptr inbounds i8, ptr %1546, i64 %1548
  %1558 = load i8, ptr %1557, align 1, !invariant.load !1
  br label %1547

1559:                                             ; preds = %1552
  %1560 = phi i8 [ %1549, %1552 ]
  %1561 = zext i8 %1535 to i16
  %1562 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1561)
  %1563 = trunc i32 %1562 to i16
  %1564 = bitcast i16 %1563 to half
  %1565 = zext i8 %1560 to i16
  %1566 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1565)
  %1567 = trunc i32 %1566 to i16
  %1568 = bitcast i16 %1567 to half
  %1569 = fadd contract half %1564, %1568
  %1570 = fpext half %1569 to float
  %1571 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1570)
  %1572 = trunc i16 %1571 to i8
  br label %1533

1573:                                             ; preds = %1538
  %1574 = phi i8 [ %1535, %1538 ]
  %1575 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1511, 0
  %1576 = getelementptr inbounds i8, ptr %1575, i64 %1503
  store i8 %1574, ptr %1576, align 1
  %1577 = load { i64, i64 }, ptr %6, align 8
  %1578 = extractvalue { i64, i64 } %1577, 1
  %1579 = icmp sge i64 %1498, %1578
  %1580 = select i1 %1579, i64 0, i64 %1498
  %1581 = select i1 %1579, i64 %1504, i64 %1499
  %1582 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1583 = load i64, ptr %4, align 8
  %1584 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1585 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1582, 0
  %1586 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1582, 1, 1, 0
  %1587 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1582, 1, 1, 1
  %1588 = mul i64 %1581, %1587
  %1589 = add i64 %1588, %1580
  %1590 = getelementptr inbounds i8, ptr %1585, i64 %1589
  br label %1591

1591:                                             ; preds = %1597, %1573
  %1592 = phi i64 [ 0, %1573 ], [ %1600, %1597 ]
  %1593 = phi i8 [ 0, %1573 ], [ %1602, %1597 ]
  %1594 = icmp slt i64 %1592, 1
  br i1 %1594, label %1595, label %1596

1595:                                             ; preds = %1591
  br label %1597

1596:                                             ; preds = %1591
  br label %1603

1597:                                             ; preds = %1595
  %1598 = icmp eq i64 %1592, 1
  %1599 = add i64 %1592, 1
  %1600 = select i1 %1598, i64 %1592, i64 %1599
  %1601 = getelementptr inbounds i8, ptr %1590, i64 %1592
  %1602 = load i8, ptr %1601, align 1, !invariant.load !1
  br label %1591

1603:                                             ; preds = %1596
  %1604 = phi i8 [ %1593, %1596 ]
  %1605 = call i64 @llvm.smax.i64(i64 %1583, i64 1)
  br label %1606

1606:                                             ; preds = %1632, %1603
  %1607 = phi i64 [ 1, %1603 ], [ %1615, %1632 ]
  %1608 = phi i8 [ %1604, %1603 ], [ %1645, %1632 ]
  %1609 = icmp slt i64 %1607, %1605
  br i1 %1609, label %1610, label %1611

1610:                                             ; preds = %1606
  br label %1612

1611:                                             ; preds = %1606
  br label %1646

1612:                                             ; preds = %1610
  %1613 = icmp eq i64 %1607, %1605
  %1614 = add i64 %1607, 1
  %1615 = select i1 %1613, i64 %1607, i64 %1614
  %1616 = mul i64 %1607, %1586
  %1617 = add i64 %1616, %1588
  %1618 = add i64 %1617, %1580
  %1619 = getelementptr inbounds i8, ptr %1585, i64 %1618
  br label %1620

1620:                                             ; preds = %1626, %1612
  %1621 = phi i64 [ 0, %1612 ], [ %1629, %1626 ]
  %1622 = phi i8 [ 0, %1612 ], [ %1631, %1626 ]
  %1623 = icmp slt i64 %1621, 1
  br i1 %1623, label %1624, label %1625

1624:                                             ; preds = %1620
  br label %1626

1625:                                             ; preds = %1620
  br label %1632

1626:                                             ; preds = %1624
  %1627 = icmp eq i64 %1621, 1
  %1628 = add i64 %1621, 1
  %1629 = select i1 %1627, i64 %1621, i64 %1628
  %1630 = getelementptr inbounds i8, ptr %1619, i64 %1621
  %1631 = load i8, ptr %1630, align 1, !invariant.load !1
  br label %1620

1632:                                             ; preds = %1625
  %1633 = phi i8 [ %1622, %1625 ]
  %1634 = zext i8 %1608 to i16
  %1635 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1634)
  %1636 = trunc i32 %1635 to i16
  %1637 = bitcast i16 %1636 to half
  %1638 = zext i8 %1633 to i16
  %1639 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1638)
  %1640 = trunc i32 %1639 to i16
  %1641 = bitcast i16 %1640 to half
  %1642 = fadd contract half %1637, %1641
  %1643 = fpext half %1642 to float
  %1644 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1643)
  %1645 = trunc i16 %1644 to i8
  br label %1606

1646:                                             ; preds = %1611
  %1647 = phi i8 [ %1608, %1611 ]
  %1648 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1584, 0
  %1649 = trunc i64 %1581 to i32
  %1650 = mul i32 %1649, 512
  %1651 = trunc i64 %1580 to i32
  %1652 = add i32 %1650, %1651
  %1653 = sext i32 %1652 to i64
  %1654 = getelementptr inbounds i8, ptr %1648, i64 %1653
  store i8 %1647, ptr %1654, align 1
  %1655 = load { i64, i64 }, ptr %6, align 8
  %1656 = add i64 %1580, 1
  %1657 = extractvalue { i64, i64 } %1655, 1
  %1658 = icmp sge i64 %1656, %1657
  %1659 = select i1 %1658, i64 0, i64 %1656
  %1660 = add i64 %1581, 1
  %1661 = select i1 %1658, i64 %1660, i64 %1581
  %1662 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1663 = load i64, ptr %4, align 8
  %1664 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1665 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1662, 0
  %1666 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1662, 1, 1, 0
  %1667 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1662, 1, 1, 1
  %1668 = mul i64 %1661, %1667
  %1669 = add i64 %1668, %1659
  %1670 = getelementptr inbounds i8, ptr %1665, i64 %1669
  br label %1671

1671:                                             ; preds = %1677, %1646
  %1672 = phi i64 [ 0, %1646 ], [ %1680, %1677 ]
  %1673 = phi i8 [ 0, %1646 ], [ %1682, %1677 ]
  %1674 = icmp slt i64 %1672, 1
  br i1 %1674, label %1675, label %1676

1675:                                             ; preds = %1671
  br label %1677

1676:                                             ; preds = %1671
  br label %1683

1677:                                             ; preds = %1675
  %1678 = icmp eq i64 %1672, 1
  %1679 = add i64 %1672, 1
  %1680 = select i1 %1678, i64 %1672, i64 %1679
  %1681 = getelementptr inbounds i8, ptr %1670, i64 %1672
  %1682 = load i8, ptr %1681, align 1, !invariant.load !1
  br label %1671

1683:                                             ; preds = %1676
  %1684 = phi i8 [ %1673, %1676 ]
  %1685 = call i64 @llvm.smax.i64(i64 %1663, i64 1)
  br label %1686

1686:                                             ; preds = %1712, %1683
  %1687 = phi i64 [ 1, %1683 ], [ %1695, %1712 ]
  %1688 = phi i8 [ %1684, %1683 ], [ %1725, %1712 ]
  %1689 = icmp slt i64 %1687, %1685
  br i1 %1689, label %1690, label %1691

1690:                                             ; preds = %1686
  br label %1692

1691:                                             ; preds = %1686
  br label %1726

1692:                                             ; preds = %1690
  %1693 = icmp eq i64 %1687, %1685
  %1694 = add i64 %1687, 1
  %1695 = select i1 %1693, i64 %1687, i64 %1694
  %1696 = mul i64 %1687, %1666
  %1697 = add i64 %1696, %1668
  %1698 = add i64 %1697, %1659
  %1699 = getelementptr inbounds i8, ptr %1665, i64 %1698
  br label %1700

1700:                                             ; preds = %1706, %1692
  %1701 = phi i64 [ 0, %1692 ], [ %1709, %1706 ]
  %1702 = phi i8 [ 0, %1692 ], [ %1711, %1706 ]
  %1703 = icmp slt i64 %1701, 1
  br i1 %1703, label %1704, label %1705

1704:                                             ; preds = %1700
  br label %1706

1705:                                             ; preds = %1700
  br label %1712

1706:                                             ; preds = %1704
  %1707 = icmp eq i64 %1701, 1
  %1708 = add i64 %1701, 1
  %1709 = select i1 %1707, i64 %1701, i64 %1708
  %1710 = getelementptr inbounds i8, ptr %1699, i64 %1701
  %1711 = load i8, ptr %1710, align 1, !invariant.load !1
  br label %1700

1712:                                             ; preds = %1705
  %1713 = phi i8 [ %1702, %1705 ]
  %1714 = zext i8 %1688 to i16
  %1715 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1714)
  %1716 = trunc i32 %1715 to i16
  %1717 = bitcast i16 %1716 to half
  %1718 = zext i8 %1713 to i16
  %1719 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1718)
  %1720 = trunc i32 %1719 to i16
  %1721 = bitcast i16 %1720 to half
  %1722 = fadd contract half %1717, %1721
  %1723 = fpext half %1722 to float
  %1724 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1723)
  %1725 = trunc i16 %1724 to i8
  br label %1686

1726:                                             ; preds = %1691
  %1727 = phi i8 [ %1688, %1691 ]
  %1728 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1664, 0
  %1729 = trunc i64 %1661 to i32
  %1730 = mul i32 %1729, 512
  %1731 = trunc i64 %1659 to i32
  %1732 = add i32 %1730, %1731
  %1733 = sext i32 %1732 to i64
  %1734 = getelementptr inbounds i8, ptr %1728, i64 %1733
  store i8 %1727, ptr %1734, align 1
  %1735 = load { i64, i64 }, ptr %6, align 8
  %1736 = add i64 %1659, 1
  %1737 = extractvalue { i64, i64 } %1735, 1
  %1738 = icmp sge i64 %1736, %1737
  %1739 = select i1 %1738, i64 0, i64 %1736
  %1740 = add i64 %1661, 1
  %1741 = select i1 %1738, i64 %1740, i64 %1661
  %1742 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1743 = load i64, ptr %4, align 8
  %1744 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1745 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1742, 0
  %1746 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1742, 1, 1, 0
  %1747 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1742, 1, 1, 1
  %1748 = mul i64 %1741, %1747
  %1749 = add i64 %1748, %1739
  %1750 = getelementptr inbounds i8, ptr %1745, i64 %1749
  br label %1751

1751:                                             ; preds = %1757, %1726
  %1752 = phi i64 [ 0, %1726 ], [ %1760, %1757 ]
  %1753 = phi i8 [ 0, %1726 ], [ %1762, %1757 ]
  %1754 = icmp slt i64 %1752, 1
  br i1 %1754, label %1755, label %1756

1755:                                             ; preds = %1751
  br label %1757

1756:                                             ; preds = %1751
  br label %1763

1757:                                             ; preds = %1755
  %1758 = icmp eq i64 %1752, 1
  %1759 = add i64 %1752, 1
  %1760 = select i1 %1758, i64 %1752, i64 %1759
  %1761 = getelementptr inbounds i8, ptr %1750, i64 %1752
  %1762 = load i8, ptr %1761, align 1, !invariant.load !1
  br label %1751

1763:                                             ; preds = %1756
  %1764 = phi i8 [ %1753, %1756 ]
  %1765 = call i64 @llvm.smax.i64(i64 %1743, i64 1)
  br label %1766

1766:                                             ; preds = %1792, %1763
  %1767 = phi i64 [ 1, %1763 ], [ %1775, %1792 ]
  %1768 = phi i8 [ %1764, %1763 ], [ %1805, %1792 ]
  %1769 = icmp slt i64 %1767, %1765
  br i1 %1769, label %1770, label %1771

1770:                                             ; preds = %1766
  br label %1772

1771:                                             ; preds = %1766
  br label %1806

1772:                                             ; preds = %1770
  %1773 = icmp eq i64 %1767, %1765
  %1774 = add i64 %1767, 1
  %1775 = select i1 %1773, i64 %1767, i64 %1774
  %1776 = mul i64 %1767, %1746
  %1777 = add i64 %1776, %1748
  %1778 = add i64 %1777, %1739
  %1779 = getelementptr inbounds i8, ptr %1745, i64 %1778
  br label %1780

1780:                                             ; preds = %1786, %1772
  %1781 = phi i64 [ 0, %1772 ], [ %1789, %1786 ]
  %1782 = phi i8 [ 0, %1772 ], [ %1791, %1786 ]
  %1783 = icmp slt i64 %1781, 1
  br i1 %1783, label %1784, label %1785

1784:                                             ; preds = %1780
  br label %1786

1785:                                             ; preds = %1780
  br label %1792

1786:                                             ; preds = %1784
  %1787 = icmp eq i64 %1781, 1
  %1788 = add i64 %1781, 1
  %1789 = select i1 %1787, i64 %1781, i64 %1788
  %1790 = getelementptr inbounds i8, ptr %1779, i64 %1781
  %1791 = load i8, ptr %1790, align 1, !invariant.load !1
  br label %1780

1792:                                             ; preds = %1785
  %1793 = phi i8 [ %1782, %1785 ]
  %1794 = zext i8 %1768 to i16
  %1795 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1794)
  %1796 = trunc i32 %1795 to i16
  %1797 = bitcast i16 %1796 to half
  %1798 = zext i8 %1793 to i16
  %1799 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1798)
  %1800 = trunc i32 %1799 to i16
  %1801 = bitcast i16 %1800 to half
  %1802 = fadd contract half %1797, %1801
  %1803 = fpext half %1802 to float
  %1804 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1803)
  %1805 = trunc i16 %1804 to i8
  br label %1766

1806:                                             ; preds = %1771
  %1807 = phi i8 [ %1768, %1771 ]
  %1808 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1744, 0
  %1809 = trunc i64 %1741 to i32
  %1810 = mul i32 %1809, 512
  %1811 = trunc i64 %1739 to i32
  %1812 = add i32 %1810, %1811
  %1813 = sext i32 %1812 to i64
  %1814 = getelementptr inbounds i8, ptr %1808, i64 %1813
  store i8 %1807, ptr %1814, align 1
  %1815 = load { i64, i64 }, ptr %6, align 8
  %1816 = add i64 %1739, 1
  %1817 = extractvalue { i64, i64 } %1815, 1
  %1818 = icmp sge i64 %1816, %1817
  %1819 = select i1 %1818, i64 0, i64 %1816
  %1820 = add i64 %1741, 1
  %1821 = select i1 %1818, i64 %1820, i64 %1741
  %1822 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1823 = load i64, ptr %4, align 8
  %1824 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1825 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1822, 0
  %1826 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1822, 1, 1, 0
  %1827 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1822, 1, 1, 1
  %1828 = mul i64 %1821, %1827
  %1829 = add i64 %1828, %1819
  %1830 = getelementptr inbounds i8, ptr %1825, i64 %1829
  br label %1831

1831:                                             ; preds = %1837, %1806
  %1832 = phi i64 [ 0, %1806 ], [ %1840, %1837 ]
  %1833 = phi i8 [ 0, %1806 ], [ %1842, %1837 ]
  %1834 = icmp slt i64 %1832, 1
  br i1 %1834, label %1835, label %1836

1835:                                             ; preds = %1831
  br label %1837

1836:                                             ; preds = %1831
  br label %1843

1837:                                             ; preds = %1835
  %1838 = icmp eq i64 %1832, 1
  %1839 = add i64 %1832, 1
  %1840 = select i1 %1838, i64 %1832, i64 %1839
  %1841 = getelementptr inbounds i8, ptr %1830, i64 %1832
  %1842 = load i8, ptr %1841, align 1, !invariant.load !1
  br label %1831

1843:                                             ; preds = %1836
  %1844 = phi i8 [ %1833, %1836 ]
  %1845 = call i64 @llvm.smax.i64(i64 %1823, i64 1)
  br label %1846

1846:                                             ; preds = %1872, %1843
  %1847 = phi i64 [ 1, %1843 ], [ %1855, %1872 ]
  %1848 = phi i8 [ %1844, %1843 ], [ %1885, %1872 ]
  %1849 = icmp slt i64 %1847, %1845
  br i1 %1849, label %1850, label %1851

1850:                                             ; preds = %1846
  br label %1852

1851:                                             ; preds = %1846
  br label %1886

1852:                                             ; preds = %1850
  %1853 = icmp eq i64 %1847, %1845
  %1854 = add i64 %1847, 1
  %1855 = select i1 %1853, i64 %1847, i64 %1854
  %1856 = mul i64 %1847, %1826
  %1857 = add i64 %1856, %1828
  %1858 = add i64 %1857, %1819
  %1859 = getelementptr inbounds i8, ptr %1825, i64 %1858
  br label %1860

1860:                                             ; preds = %1866, %1852
  %1861 = phi i64 [ 0, %1852 ], [ %1869, %1866 ]
  %1862 = phi i8 [ 0, %1852 ], [ %1871, %1866 ]
  %1863 = icmp slt i64 %1861, 1
  br i1 %1863, label %1864, label %1865

1864:                                             ; preds = %1860
  br label %1866

1865:                                             ; preds = %1860
  br label %1872

1866:                                             ; preds = %1864
  %1867 = icmp eq i64 %1861, 1
  %1868 = add i64 %1861, 1
  %1869 = select i1 %1867, i64 %1861, i64 %1868
  %1870 = getelementptr inbounds i8, ptr %1859, i64 %1861
  %1871 = load i8, ptr %1870, align 1, !invariant.load !1
  br label %1860

1872:                                             ; preds = %1865
  %1873 = phi i8 [ %1862, %1865 ]
  %1874 = zext i8 %1848 to i16
  %1875 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1874)
  %1876 = trunc i32 %1875 to i16
  %1877 = bitcast i16 %1876 to half
  %1878 = zext i8 %1873 to i16
  %1879 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1878)
  %1880 = trunc i32 %1879 to i16
  %1881 = bitcast i16 %1880 to half
  %1882 = fadd contract half %1877, %1881
  %1883 = fpext half %1882 to float
  %1884 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1883)
  %1885 = trunc i16 %1884 to i8
  br label %1846

1886:                                             ; preds = %1851
  %1887 = phi i8 [ %1848, %1851 ]
  %1888 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1824, 0
  %1889 = trunc i64 %1821 to i32
  %1890 = mul i32 %1889, 512
  %1891 = trunc i64 %1819 to i32
  %1892 = add i32 %1890, %1891
  %1893 = sext i32 %1892 to i64
  %1894 = getelementptr inbounds i8, ptr %1888, i64 %1893
  store i8 %1887, ptr %1894, align 1
  %1895 = load { i64, i64 }, ptr %6, align 8
  %1896 = add i64 %1819, 1
  %1897 = extractvalue { i64, i64 } %1895, 1
  %1898 = icmp sge i64 %1896, %1897
  %1899 = select i1 %1898, i64 0, i64 %1896
  %1900 = add i64 %1821, 1
  %1901 = select i1 %1898, i64 %1900, i64 %1821
  %1902 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1903 = load i64, ptr %4, align 8
  %1904 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1905 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1902, 0
  %1906 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1902, 1, 1, 0
  %1907 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1902, 1, 1, 1
  %1908 = mul i64 %1901, %1907
  %1909 = add i64 %1908, %1899
  %1910 = getelementptr inbounds i8, ptr %1905, i64 %1909
  br label %1911

1911:                                             ; preds = %1917, %1886
  %1912 = phi i64 [ 0, %1886 ], [ %1920, %1917 ]
  %1913 = phi i8 [ 0, %1886 ], [ %1922, %1917 ]
  %1914 = icmp slt i64 %1912, 1
  br i1 %1914, label %1915, label %1916

1915:                                             ; preds = %1911
  br label %1917

1916:                                             ; preds = %1911
  br label %1923

1917:                                             ; preds = %1915
  %1918 = icmp eq i64 %1912, 1
  %1919 = add i64 %1912, 1
  %1920 = select i1 %1918, i64 %1912, i64 %1919
  %1921 = getelementptr inbounds i8, ptr %1910, i64 %1912
  %1922 = load i8, ptr %1921, align 1, !invariant.load !1
  br label %1911

1923:                                             ; preds = %1916
  %1924 = phi i8 [ %1913, %1916 ]
  %1925 = call i64 @llvm.smax.i64(i64 %1903, i64 1)
  br label %1926

1926:                                             ; preds = %1952, %1923
  %1927 = phi i64 [ 1, %1923 ], [ %1935, %1952 ]
  %1928 = phi i8 [ %1924, %1923 ], [ %1965, %1952 ]
  %1929 = icmp slt i64 %1927, %1925
  br i1 %1929, label %1930, label %1931

1930:                                             ; preds = %1926
  br label %1932

1931:                                             ; preds = %1926
  br label %1966

1932:                                             ; preds = %1930
  %1933 = icmp eq i64 %1927, %1925
  %1934 = add i64 %1927, 1
  %1935 = select i1 %1933, i64 %1927, i64 %1934
  %1936 = mul i64 %1927, %1906
  %1937 = add i64 %1936, %1908
  %1938 = add i64 %1937, %1899
  %1939 = getelementptr inbounds i8, ptr %1905, i64 %1938
  br label %1940

1940:                                             ; preds = %1946, %1932
  %1941 = phi i64 [ 0, %1932 ], [ %1949, %1946 ]
  %1942 = phi i8 [ 0, %1932 ], [ %1951, %1946 ]
  %1943 = icmp slt i64 %1941, 1
  br i1 %1943, label %1944, label %1945

1944:                                             ; preds = %1940
  br label %1946

1945:                                             ; preds = %1940
  br label %1952

1946:                                             ; preds = %1944
  %1947 = icmp eq i64 %1941, 1
  %1948 = add i64 %1941, 1
  %1949 = select i1 %1947, i64 %1941, i64 %1948
  %1950 = getelementptr inbounds i8, ptr %1939, i64 %1941
  %1951 = load i8, ptr %1950, align 1, !invariant.load !1
  br label %1940

1952:                                             ; preds = %1945
  %1953 = phi i8 [ %1942, %1945 ]
  %1954 = zext i8 %1928 to i16
  %1955 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1954)
  %1956 = trunc i32 %1955 to i16
  %1957 = bitcast i16 %1956 to half
  %1958 = zext i8 %1953 to i16
  %1959 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %1958)
  %1960 = trunc i32 %1959 to i16
  %1961 = bitcast i16 %1960 to half
  %1962 = fadd contract half %1957, %1961
  %1963 = fpext half %1962 to float
  %1964 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %1963)
  %1965 = trunc i16 %1964 to i8
  br label %1926

1966:                                             ; preds = %1931
  %1967 = phi i8 [ %1928, %1931 ]
  %1968 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1904, 0
  %1969 = trunc i64 %1901 to i32
  %1970 = mul i32 %1969, 512
  %1971 = trunc i64 %1899 to i32
  %1972 = add i32 %1970, %1971
  %1973 = sext i32 %1972 to i64
  %1974 = getelementptr inbounds i8, ptr %1968, i64 %1973
  store i8 %1967, ptr %1974, align 1
  %1975 = load { i64, i64 }, ptr %6, align 8
  %1976 = add i64 %1899, 1
  %1977 = extractvalue { i64, i64 } %1975, 1
  %1978 = icmp sge i64 %1976, %1977
  %1979 = select i1 %1978, i64 0, i64 %1976
  %1980 = add i64 %1901, 1
  %1981 = select i1 %1978, i64 %1980, i64 %1901
  %1982 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %1983 = load i64, ptr %4, align 8
  %1984 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %1985 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1982, 0
  %1986 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1982, 1, 1, 0
  %1987 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %1982, 1, 1, 1
  %1988 = mul i64 %1981, %1987
  %1989 = add i64 %1988, %1979
  %1990 = getelementptr inbounds i8, ptr %1985, i64 %1989
  br label %1991

1991:                                             ; preds = %1997, %1966
  %1992 = phi i64 [ 0, %1966 ], [ %2000, %1997 ]
  %1993 = phi i8 [ 0, %1966 ], [ %2002, %1997 ]
  %1994 = icmp slt i64 %1992, 1
  br i1 %1994, label %1995, label %1996

1995:                                             ; preds = %1991
  br label %1997

1996:                                             ; preds = %1991
  br label %2003

1997:                                             ; preds = %1995
  %1998 = icmp eq i64 %1992, 1
  %1999 = add i64 %1992, 1
  %2000 = select i1 %1998, i64 %1992, i64 %1999
  %2001 = getelementptr inbounds i8, ptr %1990, i64 %1992
  %2002 = load i8, ptr %2001, align 1, !invariant.load !1
  br label %1991

2003:                                             ; preds = %1996
  %2004 = phi i8 [ %1993, %1996 ]
  %2005 = call i64 @llvm.smax.i64(i64 %1983, i64 1)
  br label %2006

2006:                                             ; preds = %2032, %2003
  %2007 = phi i64 [ 1, %2003 ], [ %2015, %2032 ]
  %2008 = phi i8 [ %2004, %2003 ], [ %2045, %2032 ]
  %2009 = icmp slt i64 %2007, %2005
  br i1 %2009, label %2010, label %2011

2010:                                             ; preds = %2006
  br label %2012

2011:                                             ; preds = %2006
  br label %2046

2012:                                             ; preds = %2010
  %2013 = icmp eq i64 %2007, %2005
  %2014 = add i64 %2007, 1
  %2015 = select i1 %2013, i64 %2007, i64 %2014
  %2016 = mul i64 %2007, %1986
  %2017 = add i64 %2016, %1988
  %2018 = add i64 %2017, %1979
  %2019 = getelementptr inbounds i8, ptr %1985, i64 %2018
  br label %2020

2020:                                             ; preds = %2026, %2012
  %2021 = phi i64 [ 0, %2012 ], [ %2029, %2026 ]
  %2022 = phi i8 [ 0, %2012 ], [ %2031, %2026 ]
  %2023 = icmp slt i64 %2021, 1
  br i1 %2023, label %2024, label %2025

2024:                                             ; preds = %2020
  br label %2026

2025:                                             ; preds = %2020
  br label %2032

2026:                                             ; preds = %2024
  %2027 = icmp eq i64 %2021, 1
  %2028 = add i64 %2021, 1
  %2029 = select i1 %2027, i64 %2021, i64 %2028
  %2030 = getelementptr inbounds i8, ptr %2019, i64 %2021
  %2031 = load i8, ptr %2030, align 1, !invariant.load !1
  br label %2020

2032:                                             ; preds = %2025
  %2033 = phi i8 [ %2022, %2025 ]
  %2034 = zext i8 %2008 to i16
  %2035 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2034)
  %2036 = trunc i32 %2035 to i16
  %2037 = bitcast i16 %2036 to half
  %2038 = zext i8 %2033 to i16
  %2039 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2038)
  %2040 = trunc i32 %2039 to i16
  %2041 = bitcast i16 %2040 to half
  %2042 = fadd contract half %2037, %2041
  %2043 = fpext half %2042 to float
  %2044 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2043)
  %2045 = trunc i16 %2044 to i8
  br label %2006

2046:                                             ; preds = %2011
  %2047 = phi i8 [ %2008, %2011 ]
  %2048 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %1984, 0
  %2049 = trunc i64 %1981 to i32
  %2050 = mul i32 %2049, 512
  %2051 = trunc i64 %1979 to i32
  %2052 = add i32 %2050, %2051
  %2053 = sext i32 %2052 to i64
  %2054 = getelementptr inbounds i8, ptr %2048, i64 %2053
  store i8 %2047, ptr %2054, align 1
  %2055 = load { i64, i64 }, ptr %6, align 8
  %2056 = add i64 %1979, 1
  %2057 = extractvalue { i64, i64 } %2055, 1
  %2058 = icmp sge i64 %2056, %2057
  %2059 = select i1 %2058, i64 0, i64 %2056
  %2060 = add i64 %1981, 1
  %2061 = select i1 %2058, i64 %2060, i64 %1981
  %2062 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2063 = load i64, ptr %4, align 8
  %2064 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2065 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2062, 0
  %2066 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2062, 1, 1, 0
  %2067 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2062, 1, 1, 1
  %2068 = mul i64 %2061, %2067
  %2069 = add i64 %2068, %2059
  %2070 = getelementptr inbounds i8, ptr %2065, i64 %2069
  br label %2071

2071:                                             ; preds = %2077, %2046
  %2072 = phi i64 [ 0, %2046 ], [ %2080, %2077 ]
  %2073 = phi i8 [ 0, %2046 ], [ %2082, %2077 ]
  %2074 = icmp slt i64 %2072, 1
  br i1 %2074, label %2075, label %2076

2075:                                             ; preds = %2071
  br label %2077

2076:                                             ; preds = %2071
  br label %2083

2077:                                             ; preds = %2075
  %2078 = icmp eq i64 %2072, 1
  %2079 = add i64 %2072, 1
  %2080 = select i1 %2078, i64 %2072, i64 %2079
  %2081 = getelementptr inbounds i8, ptr %2070, i64 %2072
  %2082 = load i8, ptr %2081, align 1, !invariant.load !1
  br label %2071

2083:                                             ; preds = %2076
  %2084 = phi i8 [ %2073, %2076 ]
  %2085 = call i64 @llvm.smax.i64(i64 %2063, i64 1)
  br label %2086

2086:                                             ; preds = %2112, %2083
  %2087 = phi i64 [ 1, %2083 ], [ %2095, %2112 ]
  %2088 = phi i8 [ %2084, %2083 ], [ %2125, %2112 ]
  %2089 = icmp slt i64 %2087, %2085
  br i1 %2089, label %2090, label %2091

2090:                                             ; preds = %2086
  br label %2092

2091:                                             ; preds = %2086
  br label %2126

2092:                                             ; preds = %2090
  %2093 = icmp eq i64 %2087, %2085
  %2094 = add i64 %2087, 1
  %2095 = select i1 %2093, i64 %2087, i64 %2094
  %2096 = mul i64 %2087, %2066
  %2097 = add i64 %2096, %2068
  %2098 = add i64 %2097, %2059
  %2099 = getelementptr inbounds i8, ptr %2065, i64 %2098
  br label %2100

2100:                                             ; preds = %2106, %2092
  %2101 = phi i64 [ 0, %2092 ], [ %2109, %2106 ]
  %2102 = phi i8 [ 0, %2092 ], [ %2111, %2106 ]
  %2103 = icmp slt i64 %2101, 1
  br i1 %2103, label %2104, label %2105

2104:                                             ; preds = %2100
  br label %2106

2105:                                             ; preds = %2100
  br label %2112

2106:                                             ; preds = %2104
  %2107 = icmp eq i64 %2101, 1
  %2108 = add i64 %2101, 1
  %2109 = select i1 %2107, i64 %2101, i64 %2108
  %2110 = getelementptr inbounds i8, ptr %2099, i64 %2101
  %2111 = load i8, ptr %2110, align 1, !invariant.load !1
  br label %2100

2112:                                             ; preds = %2105
  %2113 = phi i8 [ %2102, %2105 ]
  %2114 = zext i8 %2088 to i16
  %2115 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2114)
  %2116 = trunc i32 %2115 to i16
  %2117 = bitcast i16 %2116 to half
  %2118 = zext i8 %2113 to i16
  %2119 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2118)
  %2120 = trunc i32 %2119 to i16
  %2121 = bitcast i16 %2120 to half
  %2122 = fadd contract half %2117, %2121
  %2123 = fpext half %2122 to float
  %2124 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2123)
  %2125 = trunc i16 %2124 to i8
  br label %2086

2126:                                             ; preds = %2091
  %2127 = phi i8 [ %2088, %2091 ]
  %2128 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2064, 0
  %2129 = trunc i64 %2061 to i32
  %2130 = mul i32 %2129, 512
  %2131 = trunc i64 %2059 to i32
  %2132 = add i32 %2130, %2131
  %2133 = sext i32 %2132 to i64
  %2134 = getelementptr inbounds i8, ptr %2128, i64 %2133
  store i8 %2127, ptr %2134, align 1
  %2135 = load { i64, i64 }, ptr %6, align 8
  %2136 = add i64 %2059, 1
  %2137 = extractvalue { i64, i64 } %2135, 1
  %2138 = icmp sge i64 %2136, %2137
  %2139 = select i1 %2138, i64 0, i64 %2136
  %2140 = add i64 %2061, 1
  %2141 = select i1 %2138, i64 %2140, i64 %2061
  %2142 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2143 = load i64, ptr %4, align 8
  %2144 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2145 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2142, 0
  %2146 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2142, 1, 1, 0
  %2147 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2142, 1, 1, 1
  %2148 = mul i64 %2141, %2147
  %2149 = add i64 %2148, %2139
  %2150 = getelementptr inbounds i8, ptr %2145, i64 %2149
  br label %2151

2151:                                             ; preds = %2157, %2126
  %2152 = phi i64 [ 0, %2126 ], [ %2160, %2157 ]
  %2153 = phi i8 [ 0, %2126 ], [ %2162, %2157 ]
  %2154 = icmp slt i64 %2152, 1
  br i1 %2154, label %2155, label %2156

2155:                                             ; preds = %2151
  br label %2157

2156:                                             ; preds = %2151
  br label %2163

2157:                                             ; preds = %2155
  %2158 = icmp eq i64 %2152, 1
  %2159 = add i64 %2152, 1
  %2160 = select i1 %2158, i64 %2152, i64 %2159
  %2161 = getelementptr inbounds i8, ptr %2150, i64 %2152
  %2162 = load i8, ptr %2161, align 1, !invariant.load !1
  br label %2151

2163:                                             ; preds = %2156
  %2164 = phi i8 [ %2153, %2156 ]
  %2165 = call i64 @llvm.smax.i64(i64 %2143, i64 1)
  br label %2166

2166:                                             ; preds = %2192, %2163
  %2167 = phi i64 [ 1, %2163 ], [ %2175, %2192 ]
  %2168 = phi i8 [ %2164, %2163 ], [ %2205, %2192 ]
  %2169 = icmp slt i64 %2167, %2165
  br i1 %2169, label %2170, label %2171

2170:                                             ; preds = %2166
  br label %2172

2171:                                             ; preds = %2166
  br label %2206

2172:                                             ; preds = %2170
  %2173 = icmp eq i64 %2167, %2165
  %2174 = add i64 %2167, 1
  %2175 = select i1 %2173, i64 %2167, i64 %2174
  %2176 = mul i64 %2167, %2146
  %2177 = add i64 %2176, %2148
  %2178 = add i64 %2177, %2139
  %2179 = getelementptr inbounds i8, ptr %2145, i64 %2178
  br label %2180

2180:                                             ; preds = %2186, %2172
  %2181 = phi i64 [ 0, %2172 ], [ %2189, %2186 ]
  %2182 = phi i8 [ 0, %2172 ], [ %2191, %2186 ]
  %2183 = icmp slt i64 %2181, 1
  br i1 %2183, label %2184, label %2185

2184:                                             ; preds = %2180
  br label %2186

2185:                                             ; preds = %2180
  br label %2192

2186:                                             ; preds = %2184
  %2187 = icmp eq i64 %2181, 1
  %2188 = add i64 %2181, 1
  %2189 = select i1 %2187, i64 %2181, i64 %2188
  %2190 = getelementptr inbounds i8, ptr %2179, i64 %2181
  %2191 = load i8, ptr %2190, align 1, !invariant.load !1
  br label %2180

2192:                                             ; preds = %2185
  %2193 = phi i8 [ %2182, %2185 ]
  %2194 = zext i8 %2168 to i16
  %2195 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2194)
  %2196 = trunc i32 %2195 to i16
  %2197 = bitcast i16 %2196 to half
  %2198 = zext i8 %2193 to i16
  %2199 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2198)
  %2200 = trunc i32 %2199 to i16
  %2201 = bitcast i16 %2200 to half
  %2202 = fadd contract half %2197, %2201
  %2203 = fpext half %2202 to float
  %2204 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2203)
  %2205 = trunc i16 %2204 to i8
  br label %2166

2206:                                             ; preds = %2171
  %2207 = phi i8 [ %2168, %2171 ]
  %2208 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2144, 0
  %2209 = trunc i64 %2141 to i32
  %2210 = mul i32 %2209, 512
  %2211 = trunc i64 %2139 to i32
  %2212 = add i32 %2210, %2211
  %2213 = sext i32 %2212 to i64
  %2214 = getelementptr inbounds i8, ptr %2208, i64 %2213
  store i8 %2207, ptr %2214, align 1
  %2215 = load { i64, i64 }, ptr %6, align 8
  %2216 = add i64 %2139, 1
  %2217 = extractvalue { i64, i64 } %2215, 1
  %2218 = icmp sge i64 %2216, %2217
  %2219 = select i1 %2218, i64 0, i64 %2216
  %2220 = add i64 %2141, 1
  %2221 = select i1 %2218, i64 %2220, i64 %2141
  %2222 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2223 = load i64, ptr %4, align 8
  %2224 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2225 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2222, 0
  %2226 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2222, 1, 1, 0
  %2227 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2222, 1, 1, 1
  %2228 = mul i64 %2221, %2227
  %2229 = add i64 %2228, %2219
  %2230 = getelementptr inbounds i8, ptr %2225, i64 %2229
  br label %2231

2231:                                             ; preds = %2237, %2206
  %2232 = phi i64 [ 0, %2206 ], [ %2240, %2237 ]
  %2233 = phi i8 [ 0, %2206 ], [ %2242, %2237 ]
  %2234 = icmp slt i64 %2232, 1
  br i1 %2234, label %2235, label %2236

2235:                                             ; preds = %2231
  br label %2237

2236:                                             ; preds = %2231
  br label %2243

2237:                                             ; preds = %2235
  %2238 = icmp eq i64 %2232, 1
  %2239 = add i64 %2232, 1
  %2240 = select i1 %2238, i64 %2232, i64 %2239
  %2241 = getelementptr inbounds i8, ptr %2230, i64 %2232
  %2242 = load i8, ptr %2241, align 1, !invariant.load !1
  br label %2231

2243:                                             ; preds = %2236
  %2244 = phi i8 [ %2233, %2236 ]
  %2245 = call i64 @llvm.smax.i64(i64 %2223, i64 1)
  br label %2246

2246:                                             ; preds = %2272, %2243
  %2247 = phi i64 [ 1, %2243 ], [ %2255, %2272 ]
  %2248 = phi i8 [ %2244, %2243 ], [ %2285, %2272 ]
  %2249 = icmp slt i64 %2247, %2245
  br i1 %2249, label %2250, label %2251

2250:                                             ; preds = %2246
  br label %2252

2251:                                             ; preds = %2246
  br label %2286

2252:                                             ; preds = %2250
  %2253 = icmp eq i64 %2247, %2245
  %2254 = add i64 %2247, 1
  %2255 = select i1 %2253, i64 %2247, i64 %2254
  %2256 = mul i64 %2247, %2226
  %2257 = add i64 %2256, %2228
  %2258 = add i64 %2257, %2219
  %2259 = getelementptr inbounds i8, ptr %2225, i64 %2258
  br label %2260

2260:                                             ; preds = %2266, %2252
  %2261 = phi i64 [ 0, %2252 ], [ %2269, %2266 ]
  %2262 = phi i8 [ 0, %2252 ], [ %2271, %2266 ]
  %2263 = icmp slt i64 %2261, 1
  br i1 %2263, label %2264, label %2265

2264:                                             ; preds = %2260
  br label %2266

2265:                                             ; preds = %2260
  br label %2272

2266:                                             ; preds = %2264
  %2267 = icmp eq i64 %2261, 1
  %2268 = add i64 %2261, 1
  %2269 = select i1 %2267, i64 %2261, i64 %2268
  %2270 = getelementptr inbounds i8, ptr %2259, i64 %2261
  %2271 = load i8, ptr %2270, align 1, !invariant.load !1
  br label %2260

2272:                                             ; preds = %2265
  %2273 = phi i8 [ %2262, %2265 ]
  %2274 = zext i8 %2248 to i16
  %2275 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2274)
  %2276 = trunc i32 %2275 to i16
  %2277 = bitcast i16 %2276 to half
  %2278 = zext i8 %2273 to i16
  %2279 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2278)
  %2280 = trunc i32 %2279 to i16
  %2281 = bitcast i16 %2280 to half
  %2282 = fadd contract half %2277, %2281
  %2283 = fpext half %2282 to float
  %2284 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2283)
  %2285 = trunc i16 %2284 to i8
  br label %2246

2286:                                             ; preds = %2251
  %2287 = phi i8 [ %2248, %2251 ]
  %2288 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2224, 0
  %2289 = trunc i64 %2221 to i32
  %2290 = mul i32 %2289, 512
  %2291 = trunc i64 %2219 to i32
  %2292 = add i32 %2290, %2291
  %2293 = sext i32 %2292 to i64
  %2294 = getelementptr inbounds i8, ptr %2288, i64 %2293
  store i8 %2287, ptr %2294, align 1
  %2295 = load { i64, i64 }, ptr %6, align 8
  %2296 = add i64 %2219, 1
  %2297 = extractvalue { i64, i64 } %2295, 1
  %2298 = icmp sge i64 %2296, %2297
  %2299 = select i1 %2298, i64 0, i64 %2296
  %2300 = add i64 %2221, 1
  %2301 = select i1 %2298, i64 %2300, i64 %2221
  %2302 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2303 = load i64, ptr %4, align 8
  %2304 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2305 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2302, 0
  %2306 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2302, 1, 1, 0
  %2307 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2302, 1, 1, 1
  %2308 = mul i64 %2301, %2307
  %2309 = add i64 %2308, %2299
  %2310 = getelementptr inbounds i8, ptr %2305, i64 %2309
  br label %2311

2311:                                             ; preds = %2317, %2286
  %2312 = phi i64 [ 0, %2286 ], [ %2320, %2317 ]
  %2313 = phi i8 [ 0, %2286 ], [ %2322, %2317 ]
  %2314 = icmp slt i64 %2312, 1
  br i1 %2314, label %2315, label %2316

2315:                                             ; preds = %2311
  br label %2317

2316:                                             ; preds = %2311
  br label %2323

2317:                                             ; preds = %2315
  %2318 = icmp eq i64 %2312, 1
  %2319 = add i64 %2312, 1
  %2320 = select i1 %2318, i64 %2312, i64 %2319
  %2321 = getelementptr inbounds i8, ptr %2310, i64 %2312
  %2322 = load i8, ptr %2321, align 1, !invariant.load !1
  br label %2311

2323:                                             ; preds = %2316
  %2324 = phi i8 [ %2313, %2316 ]
  %2325 = call i64 @llvm.smax.i64(i64 %2303, i64 1)
  br label %2326

2326:                                             ; preds = %2352, %2323
  %2327 = phi i64 [ 1, %2323 ], [ %2335, %2352 ]
  %2328 = phi i8 [ %2324, %2323 ], [ %2365, %2352 ]
  %2329 = icmp slt i64 %2327, %2325
  br i1 %2329, label %2330, label %2331

2330:                                             ; preds = %2326
  br label %2332

2331:                                             ; preds = %2326
  br label %2366

2332:                                             ; preds = %2330
  %2333 = icmp eq i64 %2327, %2325
  %2334 = add i64 %2327, 1
  %2335 = select i1 %2333, i64 %2327, i64 %2334
  %2336 = mul i64 %2327, %2306
  %2337 = add i64 %2336, %2308
  %2338 = add i64 %2337, %2299
  %2339 = getelementptr inbounds i8, ptr %2305, i64 %2338
  br label %2340

2340:                                             ; preds = %2346, %2332
  %2341 = phi i64 [ 0, %2332 ], [ %2349, %2346 ]
  %2342 = phi i8 [ 0, %2332 ], [ %2351, %2346 ]
  %2343 = icmp slt i64 %2341, 1
  br i1 %2343, label %2344, label %2345

2344:                                             ; preds = %2340
  br label %2346

2345:                                             ; preds = %2340
  br label %2352

2346:                                             ; preds = %2344
  %2347 = icmp eq i64 %2341, 1
  %2348 = add i64 %2341, 1
  %2349 = select i1 %2347, i64 %2341, i64 %2348
  %2350 = getelementptr inbounds i8, ptr %2339, i64 %2341
  %2351 = load i8, ptr %2350, align 1, !invariant.load !1
  br label %2340

2352:                                             ; preds = %2345
  %2353 = phi i8 [ %2342, %2345 ]
  %2354 = zext i8 %2328 to i16
  %2355 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2354)
  %2356 = trunc i32 %2355 to i16
  %2357 = bitcast i16 %2356 to half
  %2358 = zext i8 %2353 to i16
  %2359 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2358)
  %2360 = trunc i32 %2359 to i16
  %2361 = bitcast i16 %2360 to half
  %2362 = fadd contract half %2357, %2361
  %2363 = fpext half %2362 to float
  %2364 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2363)
  %2365 = trunc i16 %2364 to i8
  br label %2326

2366:                                             ; preds = %2331
  %2367 = phi i8 [ %2328, %2331 ]
  %2368 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2304, 0
  %2369 = trunc i64 %2301 to i32
  %2370 = mul i32 %2369, 512
  %2371 = trunc i64 %2299 to i32
  %2372 = add i32 %2370, %2371
  %2373 = sext i32 %2372 to i64
  %2374 = getelementptr inbounds i8, ptr %2368, i64 %2373
  store i8 %2367, ptr %2374, align 1
  %2375 = load { i64, i64 }, ptr %6, align 8
  %2376 = add i64 %2299, 1
  %2377 = extractvalue { i64, i64 } %2375, 1
  %2378 = icmp sge i64 %2376, %2377
  %2379 = select i1 %2378, i64 0, i64 %2376
  %2380 = add i64 %2301, 1
  %2381 = select i1 %2378, i64 %2380, i64 %2301
  %2382 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2383 = load i64, ptr %4, align 8
  %2384 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2385 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2382, 0
  %2386 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2382, 1, 1, 0
  %2387 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2382, 1, 1, 1
  %2388 = mul i64 %2381, %2387
  %2389 = add i64 %2388, %2379
  %2390 = getelementptr inbounds i8, ptr %2385, i64 %2389
  br label %2391

2391:                                             ; preds = %2397, %2366
  %2392 = phi i64 [ 0, %2366 ], [ %2400, %2397 ]
  %2393 = phi i8 [ 0, %2366 ], [ %2402, %2397 ]
  %2394 = icmp slt i64 %2392, 1
  br i1 %2394, label %2395, label %2396

2395:                                             ; preds = %2391
  br label %2397

2396:                                             ; preds = %2391
  br label %2403

2397:                                             ; preds = %2395
  %2398 = icmp eq i64 %2392, 1
  %2399 = add i64 %2392, 1
  %2400 = select i1 %2398, i64 %2392, i64 %2399
  %2401 = getelementptr inbounds i8, ptr %2390, i64 %2392
  %2402 = load i8, ptr %2401, align 1, !invariant.load !1
  br label %2391

2403:                                             ; preds = %2396
  %2404 = phi i8 [ %2393, %2396 ]
  %2405 = call i64 @llvm.smax.i64(i64 %2383, i64 1)
  br label %2406

2406:                                             ; preds = %2432, %2403
  %2407 = phi i64 [ 1, %2403 ], [ %2415, %2432 ]
  %2408 = phi i8 [ %2404, %2403 ], [ %2445, %2432 ]
  %2409 = icmp slt i64 %2407, %2405
  br i1 %2409, label %2410, label %2411

2410:                                             ; preds = %2406
  br label %2412

2411:                                             ; preds = %2406
  br label %2446

2412:                                             ; preds = %2410
  %2413 = icmp eq i64 %2407, %2405
  %2414 = add i64 %2407, 1
  %2415 = select i1 %2413, i64 %2407, i64 %2414
  %2416 = mul i64 %2407, %2386
  %2417 = add i64 %2416, %2388
  %2418 = add i64 %2417, %2379
  %2419 = getelementptr inbounds i8, ptr %2385, i64 %2418
  br label %2420

2420:                                             ; preds = %2426, %2412
  %2421 = phi i64 [ 0, %2412 ], [ %2429, %2426 ]
  %2422 = phi i8 [ 0, %2412 ], [ %2431, %2426 ]
  %2423 = icmp slt i64 %2421, 1
  br i1 %2423, label %2424, label %2425

2424:                                             ; preds = %2420
  br label %2426

2425:                                             ; preds = %2420
  br label %2432

2426:                                             ; preds = %2424
  %2427 = icmp eq i64 %2421, 1
  %2428 = add i64 %2421, 1
  %2429 = select i1 %2427, i64 %2421, i64 %2428
  %2430 = getelementptr inbounds i8, ptr %2419, i64 %2421
  %2431 = load i8, ptr %2430, align 1, !invariant.load !1
  br label %2420

2432:                                             ; preds = %2425
  %2433 = phi i8 [ %2422, %2425 ]
  %2434 = zext i8 %2408 to i16
  %2435 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2434)
  %2436 = trunc i32 %2435 to i16
  %2437 = bitcast i16 %2436 to half
  %2438 = zext i8 %2433 to i16
  %2439 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2438)
  %2440 = trunc i32 %2439 to i16
  %2441 = bitcast i16 %2440 to half
  %2442 = fadd contract half %2437, %2441
  %2443 = fpext half %2442 to float
  %2444 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2443)
  %2445 = trunc i16 %2444 to i8
  br label %2406

2446:                                             ; preds = %2411
  %2447 = phi i8 [ %2408, %2411 ]
  %2448 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2384, 0
  %2449 = trunc i64 %2381 to i32
  %2450 = mul i32 %2449, 512
  %2451 = trunc i64 %2379 to i32
  %2452 = add i32 %2450, %2451
  %2453 = sext i32 %2452 to i64
  %2454 = getelementptr inbounds i8, ptr %2448, i64 %2453
  store i8 %2447, ptr %2454, align 1
  %2455 = load { i64, i64 }, ptr %6, align 8
  %2456 = add i64 %2379, 1
  %2457 = extractvalue { i64, i64 } %2455, 1
  %2458 = icmp sge i64 %2456, %2457
  %2459 = select i1 %2458, i64 0, i64 %2456
  %2460 = add i64 %2381, 1
  %2461 = select i1 %2458, i64 %2460, i64 %2381
  %2462 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2463 = load i64, ptr %4, align 8
  %2464 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2465 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2462, 0
  %2466 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2462, 1, 1, 0
  %2467 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2462, 1, 1, 1
  %2468 = mul i64 %2461, %2467
  %2469 = add i64 %2468, %2459
  %2470 = getelementptr inbounds i8, ptr %2465, i64 %2469
  br label %2471

2471:                                             ; preds = %2477, %2446
  %2472 = phi i64 [ 0, %2446 ], [ %2480, %2477 ]
  %2473 = phi i8 [ 0, %2446 ], [ %2482, %2477 ]
  %2474 = icmp slt i64 %2472, 1
  br i1 %2474, label %2475, label %2476

2475:                                             ; preds = %2471
  br label %2477

2476:                                             ; preds = %2471
  br label %2483

2477:                                             ; preds = %2475
  %2478 = icmp eq i64 %2472, 1
  %2479 = add i64 %2472, 1
  %2480 = select i1 %2478, i64 %2472, i64 %2479
  %2481 = getelementptr inbounds i8, ptr %2470, i64 %2472
  %2482 = load i8, ptr %2481, align 1, !invariant.load !1
  br label %2471

2483:                                             ; preds = %2476
  %2484 = phi i8 [ %2473, %2476 ]
  %2485 = call i64 @llvm.smax.i64(i64 %2463, i64 1)
  br label %2486

2486:                                             ; preds = %2512, %2483
  %2487 = phi i64 [ 1, %2483 ], [ %2495, %2512 ]
  %2488 = phi i8 [ %2484, %2483 ], [ %2525, %2512 ]
  %2489 = icmp slt i64 %2487, %2485
  br i1 %2489, label %2490, label %2491

2490:                                             ; preds = %2486
  br label %2492

2491:                                             ; preds = %2486
  br label %2526

2492:                                             ; preds = %2490
  %2493 = icmp eq i64 %2487, %2485
  %2494 = add i64 %2487, 1
  %2495 = select i1 %2493, i64 %2487, i64 %2494
  %2496 = mul i64 %2487, %2466
  %2497 = add i64 %2496, %2468
  %2498 = add i64 %2497, %2459
  %2499 = getelementptr inbounds i8, ptr %2465, i64 %2498
  br label %2500

2500:                                             ; preds = %2506, %2492
  %2501 = phi i64 [ 0, %2492 ], [ %2509, %2506 ]
  %2502 = phi i8 [ 0, %2492 ], [ %2511, %2506 ]
  %2503 = icmp slt i64 %2501, 1
  br i1 %2503, label %2504, label %2505

2504:                                             ; preds = %2500
  br label %2506

2505:                                             ; preds = %2500
  br label %2512

2506:                                             ; preds = %2504
  %2507 = icmp eq i64 %2501, 1
  %2508 = add i64 %2501, 1
  %2509 = select i1 %2507, i64 %2501, i64 %2508
  %2510 = getelementptr inbounds i8, ptr %2499, i64 %2501
  %2511 = load i8, ptr %2510, align 1, !invariant.load !1
  br label %2500

2512:                                             ; preds = %2505
  %2513 = phi i8 [ %2502, %2505 ]
  %2514 = zext i8 %2488 to i16
  %2515 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2514)
  %2516 = trunc i32 %2515 to i16
  %2517 = bitcast i16 %2516 to half
  %2518 = zext i8 %2513 to i16
  %2519 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2518)
  %2520 = trunc i32 %2519 to i16
  %2521 = bitcast i16 %2520 to half
  %2522 = fadd contract half %2517, %2521
  %2523 = fpext half %2522 to float
  %2524 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2523)
  %2525 = trunc i16 %2524 to i8
  br label %2486

2526:                                             ; preds = %2491
  %2527 = phi i8 [ %2488, %2491 ]
  %2528 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2464, 0
  %2529 = trunc i64 %2461 to i32
  %2530 = mul i32 %2529, 512
  %2531 = trunc i64 %2459 to i32
  %2532 = add i32 %2530, %2531
  %2533 = sext i32 %2532 to i64
  %2534 = getelementptr inbounds i8, ptr %2528, i64 %2533
  store i8 %2527, ptr %2534, align 1
  %2535 = load { i64, i64 }, ptr %6, align 8
  %2536 = add i64 %2459, 1
  %2537 = extractvalue { i64, i64 } %2535, 1
  %2538 = icmp sge i64 %2536, %2537
  %2539 = select i1 %2538, i64 0, i64 %2536
  %2540 = add i64 %2461, 1
  %2541 = select i1 %2538, i64 %2540, i64 %2461
  %2542 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2543 = load i64, ptr %4, align 8
  %2544 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2545 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2542, 0
  %2546 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2542, 1, 1, 0
  %2547 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2542, 1, 1, 1
  %2548 = mul i64 %2541, %2547
  %2549 = add i64 %2548, %2539
  %2550 = getelementptr inbounds i8, ptr %2545, i64 %2549
  br label %2551

2551:                                             ; preds = %2557, %2526
  %2552 = phi i64 [ 0, %2526 ], [ %2560, %2557 ]
  %2553 = phi i8 [ 0, %2526 ], [ %2562, %2557 ]
  %2554 = icmp slt i64 %2552, 1
  br i1 %2554, label %2555, label %2556

2555:                                             ; preds = %2551
  br label %2557

2556:                                             ; preds = %2551
  br label %2563

2557:                                             ; preds = %2555
  %2558 = icmp eq i64 %2552, 1
  %2559 = add i64 %2552, 1
  %2560 = select i1 %2558, i64 %2552, i64 %2559
  %2561 = getelementptr inbounds i8, ptr %2550, i64 %2552
  %2562 = load i8, ptr %2561, align 1, !invariant.load !1
  br label %2551

2563:                                             ; preds = %2556
  %2564 = phi i8 [ %2553, %2556 ]
  %2565 = call i64 @llvm.smax.i64(i64 %2543, i64 1)
  br label %2566

2566:                                             ; preds = %2592, %2563
  %2567 = phi i64 [ 1, %2563 ], [ %2575, %2592 ]
  %2568 = phi i8 [ %2564, %2563 ], [ %2605, %2592 ]
  %2569 = icmp slt i64 %2567, %2565
  br i1 %2569, label %2570, label %2571

2570:                                             ; preds = %2566
  br label %2572

2571:                                             ; preds = %2566
  br label %2606

2572:                                             ; preds = %2570
  %2573 = icmp eq i64 %2567, %2565
  %2574 = add i64 %2567, 1
  %2575 = select i1 %2573, i64 %2567, i64 %2574
  %2576 = mul i64 %2567, %2546
  %2577 = add i64 %2576, %2548
  %2578 = add i64 %2577, %2539
  %2579 = getelementptr inbounds i8, ptr %2545, i64 %2578
  br label %2580

2580:                                             ; preds = %2586, %2572
  %2581 = phi i64 [ 0, %2572 ], [ %2589, %2586 ]
  %2582 = phi i8 [ 0, %2572 ], [ %2591, %2586 ]
  %2583 = icmp slt i64 %2581, 1
  br i1 %2583, label %2584, label %2585

2584:                                             ; preds = %2580
  br label %2586

2585:                                             ; preds = %2580
  br label %2592

2586:                                             ; preds = %2584
  %2587 = icmp eq i64 %2581, 1
  %2588 = add i64 %2581, 1
  %2589 = select i1 %2587, i64 %2581, i64 %2588
  %2590 = getelementptr inbounds i8, ptr %2579, i64 %2581
  %2591 = load i8, ptr %2590, align 1, !invariant.load !1
  br label %2580

2592:                                             ; preds = %2585
  %2593 = phi i8 [ %2582, %2585 ]
  %2594 = zext i8 %2568 to i16
  %2595 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2594)
  %2596 = trunc i32 %2595 to i16
  %2597 = bitcast i16 %2596 to half
  %2598 = zext i8 %2593 to i16
  %2599 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2598)
  %2600 = trunc i32 %2599 to i16
  %2601 = bitcast i16 %2600 to half
  %2602 = fadd contract half %2597, %2601
  %2603 = fpext half %2602 to float
  %2604 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2603)
  %2605 = trunc i16 %2604 to i8
  br label %2566

2606:                                             ; preds = %2571
  %2607 = phi i8 [ %2568, %2571 ]
  %2608 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2544, 0
  %2609 = trunc i64 %2541 to i32
  %2610 = mul i32 %2609, 512
  %2611 = trunc i64 %2539 to i32
  %2612 = add i32 %2610, %2611
  %2613 = sext i32 %2612 to i64
  %2614 = getelementptr inbounds i8, ptr %2608, i64 %2613
  store i8 %2607, ptr %2614, align 1
  %2615 = load { i64, i64 }, ptr %6, align 8
  %2616 = add i64 %2539, 1
  %2617 = extractvalue { i64, i64 } %2615, 1
  %2618 = icmp sge i64 %2616, %2617
  %2619 = select i1 %2618, i64 0, i64 %2616
  %2620 = add i64 %2541, 1
  %2621 = select i1 %2618, i64 %2620, i64 %2541
  %2622 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2623 = load i64, ptr %4, align 8
  %2624 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2625 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2622, 0
  %2626 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2622, 1, 1, 0
  %2627 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2622, 1, 1, 1
  %2628 = mul i64 %2621, %2627
  %2629 = add i64 %2628, %2619
  %2630 = getelementptr inbounds i8, ptr %2625, i64 %2629
  br label %2631

2631:                                             ; preds = %2637, %2606
  %2632 = phi i64 [ 0, %2606 ], [ %2640, %2637 ]
  %2633 = phi i8 [ 0, %2606 ], [ %2642, %2637 ]
  %2634 = icmp slt i64 %2632, 1
  br i1 %2634, label %2635, label %2636

2635:                                             ; preds = %2631
  br label %2637

2636:                                             ; preds = %2631
  br label %2643

2637:                                             ; preds = %2635
  %2638 = icmp eq i64 %2632, 1
  %2639 = add i64 %2632, 1
  %2640 = select i1 %2638, i64 %2632, i64 %2639
  %2641 = getelementptr inbounds i8, ptr %2630, i64 %2632
  %2642 = load i8, ptr %2641, align 1, !invariant.load !1
  br label %2631

2643:                                             ; preds = %2636
  %2644 = phi i8 [ %2633, %2636 ]
  %2645 = call i64 @llvm.smax.i64(i64 %2623, i64 1)
  br label %2646

2646:                                             ; preds = %2672, %2643
  %2647 = phi i64 [ 1, %2643 ], [ %2655, %2672 ]
  %2648 = phi i8 [ %2644, %2643 ], [ %2685, %2672 ]
  %2649 = icmp slt i64 %2647, %2645
  br i1 %2649, label %2650, label %2651

2650:                                             ; preds = %2646
  br label %2652

2651:                                             ; preds = %2646
  br label %2686

2652:                                             ; preds = %2650
  %2653 = icmp eq i64 %2647, %2645
  %2654 = add i64 %2647, 1
  %2655 = select i1 %2653, i64 %2647, i64 %2654
  %2656 = mul i64 %2647, %2626
  %2657 = add i64 %2656, %2628
  %2658 = add i64 %2657, %2619
  %2659 = getelementptr inbounds i8, ptr %2625, i64 %2658
  br label %2660

2660:                                             ; preds = %2666, %2652
  %2661 = phi i64 [ 0, %2652 ], [ %2669, %2666 ]
  %2662 = phi i8 [ 0, %2652 ], [ %2671, %2666 ]
  %2663 = icmp slt i64 %2661, 1
  br i1 %2663, label %2664, label %2665

2664:                                             ; preds = %2660
  br label %2666

2665:                                             ; preds = %2660
  br label %2672

2666:                                             ; preds = %2664
  %2667 = icmp eq i64 %2661, 1
  %2668 = add i64 %2661, 1
  %2669 = select i1 %2667, i64 %2661, i64 %2668
  %2670 = getelementptr inbounds i8, ptr %2659, i64 %2661
  %2671 = load i8, ptr %2670, align 1, !invariant.load !1
  br label %2660

2672:                                             ; preds = %2665
  %2673 = phi i8 [ %2662, %2665 ]
  %2674 = zext i8 %2648 to i16
  %2675 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2674)
  %2676 = trunc i32 %2675 to i16
  %2677 = bitcast i16 %2676 to half
  %2678 = zext i8 %2673 to i16
  %2679 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2678)
  %2680 = trunc i32 %2679 to i16
  %2681 = bitcast i16 %2680 to half
  %2682 = fadd contract half %2677, %2681
  %2683 = fpext half %2682 to float
  %2684 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2683)
  %2685 = trunc i16 %2684 to i8
  br label %2646

2686:                                             ; preds = %2651
  %2687 = phi i8 [ %2648, %2651 ]
  %2688 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2624, 0
  %2689 = trunc i64 %2621 to i32
  %2690 = mul i32 %2689, 512
  %2691 = trunc i64 %2619 to i32
  %2692 = add i32 %2690, %2691
  %2693 = sext i32 %2692 to i64
  %2694 = getelementptr inbounds i8, ptr %2688, i64 %2693
  store i8 %2687, ptr %2694, align 1
  %2695 = load { i64, i64 }, ptr %6, align 8
  %2696 = add i64 %2619, 1
  %2697 = extractvalue { i64, i64 } %2695, 1
  %2698 = icmp sge i64 %2696, %2697
  %2699 = select i1 %2698, i64 0, i64 %2696
  %2700 = add i64 %2621, 1
  %2701 = select i1 %2698, i64 %2700, i64 %2621
  %2702 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2703 = load i64, ptr %4, align 8
  %2704 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2705 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2702, 0
  %2706 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2702, 1, 1, 0
  %2707 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2702, 1, 1, 1
  %2708 = mul i64 %2701, %2707
  %2709 = add i64 %2708, %2699
  %2710 = getelementptr inbounds i8, ptr %2705, i64 %2709
  br label %2711

2711:                                             ; preds = %2717, %2686
  %2712 = phi i64 [ 0, %2686 ], [ %2720, %2717 ]
  %2713 = phi i8 [ 0, %2686 ], [ %2722, %2717 ]
  %2714 = icmp slt i64 %2712, 1
  br i1 %2714, label %2715, label %2716

2715:                                             ; preds = %2711
  br label %2717

2716:                                             ; preds = %2711
  br label %2723

2717:                                             ; preds = %2715
  %2718 = icmp eq i64 %2712, 1
  %2719 = add i64 %2712, 1
  %2720 = select i1 %2718, i64 %2712, i64 %2719
  %2721 = getelementptr inbounds i8, ptr %2710, i64 %2712
  %2722 = load i8, ptr %2721, align 1, !invariant.load !1
  br label %2711

2723:                                             ; preds = %2716
  %2724 = phi i8 [ %2713, %2716 ]
  %2725 = call i64 @llvm.smax.i64(i64 %2703, i64 1)
  br label %2726

2726:                                             ; preds = %2752, %2723
  %2727 = phi i64 [ 1, %2723 ], [ %2735, %2752 ]
  %2728 = phi i8 [ %2724, %2723 ], [ %2765, %2752 ]
  %2729 = icmp slt i64 %2727, %2725
  br i1 %2729, label %2730, label %2731

2730:                                             ; preds = %2726
  br label %2732

2731:                                             ; preds = %2726
  br label %2766

2732:                                             ; preds = %2730
  %2733 = icmp eq i64 %2727, %2725
  %2734 = add i64 %2727, 1
  %2735 = select i1 %2733, i64 %2727, i64 %2734
  %2736 = mul i64 %2727, %2706
  %2737 = add i64 %2736, %2708
  %2738 = add i64 %2737, %2699
  %2739 = getelementptr inbounds i8, ptr %2705, i64 %2738
  br label %2740

2740:                                             ; preds = %2746, %2732
  %2741 = phi i64 [ 0, %2732 ], [ %2749, %2746 ]
  %2742 = phi i8 [ 0, %2732 ], [ %2751, %2746 ]
  %2743 = icmp slt i64 %2741, 1
  br i1 %2743, label %2744, label %2745

2744:                                             ; preds = %2740
  br label %2746

2745:                                             ; preds = %2740
  br label %2752

2746:                                             ; preds = %2744
  %2747 = icmp eq i64 %2741, 1
  %2748 = add i64 %2741, 1
  %2749 = select i1 %2747, i64 %2741, i64 %2748
  %2750 = getelementptr inbounds i8, ptr %2739, i64 %2741
  %2751 = load i8, ptr %2750, align 1, !invariant.load !1
  br label %2740

2752:                                             ; preds = %2745
  %2753 = phi i8 [ %2742, %2745 ]
  %2754 = zext i8 %2728 to i16
  %2755 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2754)
  %2756 = trunc i32 %2755 to i16
  %2757 = bitcast i16 %2756 to half
  %2758 = zext i8 %2753 to i16
  %2759 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2758)
  %2760 = trunc i32 %2759 to i16
  %2761 = bitcast i16 %2760 to half
  %2762 = fadd contract half %2757, %2761
  %2763 = fpext half %2762 to float
  %2764 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2763)
  %2765 = trunc i16 %2764 to i8
  br label %2726

2766:                                             ; preds = %2731
  %2767 = phi i8 [ %2728, %2731 ]
  %2768 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2704, 0
  %2769 = trunc i64 %2701 to i32
  %2770 = mul i32 %2769, 512
  %2771 = trunc i64 %2699 to i32
  %2772 = add i32 %2770, %2771
  %2773 = sext i32 %2772 to i64
  %2774 = getelementptr inbounds i8, ptr %2768, i64 %2773
  store i8 %2767, ptr %2774, align 1
  br label %2893

2775:                                             ; preds = %1482
  %2776 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2777 = load i64, ptr %4, align 8
  %2778 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2779 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2776, 0
  %2780 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2776, 1, 1, 0
  %2781 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2776, 1, 1, 1
  %2782 = mul i64 %1499, %2781
  %2783 = add i64 %2782, %1496
  %2784 = getelementptr inbounds i8, ptr %2779, i64 %2783
  %2785 = load <16 x i8>, ptr %2784, align 16, !invariant.load !1
  %2786 = call i64 @llvm.smax.i64(i64 %2777, i64 1)
  br label %2787

2787:                                             ; preds = %2793, %2775
  %2788 = phi i64 [ 1, %2775 ], [ %2796, %2793 ]
  %2789 = phi <16 x i8> [ %2785, %2775 ], [ %2888, %2793 ]
  %2790 = icmp slt i64 %2788, %2786
  br i1 %2790, label %2791, label %2792

2791:                                             ; preds = %2787
  br label %2793

2792:                                             ; preds = %2787
  br label %2889

2793:                                             ; preds = %2791
  %2794 = icmp eq i64 %2788, %2786
  %2795 = add i64 %2788, 1
  %2796 = select i1 %2794, i64 %2788, i64 %2795
  %2797 = mul i64 %2788, %2780
  %2798 = add i64 %2797, %2782
  %2799 = add i64 %2798, %1496
  %2800 = getelementptr inbounds i8, ptr %2779, i64 %2799
  %2801 = load <16 x i8>, ptr %2800, align 16, !invariant.load !1
  %2802 = bitcast <16 x i8> %2789 to <8 x i16>
  %2803 = extractelement <8 x i16> %2802, i32 0
  %2804 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2803)
  %2805 = insertelement <8 x i32> undef, i32 %2804, i32 0
  %2806 = extractelement <8 x i16> %2802, i32 1
  %2807 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2806)
  %2808 = insertelement <8 x i32> %2805, i32 %2807, i32 1
  %2809 = extractelement <8 x i16> %2802, i32 2
  %2810 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2809)
  %2811 = insertelement <8 x i32> %2808, i32 %2810, i32 2
  %2812 = extractelement <8 x i16> %2802, i32 3
  %2813 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2812)
  %2814 = insertelement <8 x i32> %2811, i32 %2813, i32 3
  %2815 = extractelement <8 x i16> %2802, i32 4
  %2816 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2815)
  %2817 = insertelement <8 x i32> %2814, i32 %2816, i32 4
  %2818 = extractelement <8 x i16> %2802, i32 5
  %2819 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2818)
  %2820 = insertelement <8 x i32> %2817, i32 %2819, i32 5
  %2821 = extractelement <8 x i16> %2802, i32 6
  %2822 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2821)
  %2823 = insertelement <8 x i32> %2820, i32 %2822, i32 6
  %2824 = extractelement <8 x i16> %2802, i32 7
  %2825 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2824)
  %2826 = insertelement <8 x i32> %2823, i32 %2825, i32 7
  %2827 = bitcast <8 x i32> %2826 to <16 x half>
  %2828 = bitcast <16 x i8> %2801 to <8 x i16>
  %2829 = extractelement <8 x i16> %2828, i32 0
  %2830 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2829)
  %2831 = insertelement <8 x i32> undef, i32 %2830, i32 0
  %2832 = extractelement <8 x i16> %2828, i32 1
  %2833 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2832)
  %2834 = insertelement <8 x i32> %2831, i32 %2833, i32 1
  %2835 = extractelement <8 x i16> %2828, i32 2
  %2836 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2835)
  %2837 = insertelement <8 x i32> %2834, i32 %2836, i32 2
  %2838 = extractelement <8 x i16> %2828, i32 3
  %2839 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2838)
  %2840 = insertelement <8 x i32> %2837, i32 %2839, i32 3
  %2841 = extractelement <8 x i16> %2828, i32 4
  %2842 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2841)
  %2843 = insertelement <8 x i32> %2840, i32 %2842, i32 4
  %2844 = extractelement <8 x i16> %2828, i32 5
  %2845 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2844)
  %2846 = insertelement <8 x i32> %2843, i32 %2845, i32 5
  %2847 = extractelement <8 x i16> %2828, i32 6
  %2848 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2847)
  %2849 = insertelement <8 x i32> %2846, i32 %2848, i32 6
  %2850 = extractelement <8 x i16> %2828, i32 7
  %2851 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2850)
  %2852 = insertelement <8 x i32> %2849, i32 %2851, i32 7
  %2853 = bitcast <8 x i32> %2852 to <16 x half>
  %2854 = fadd contract <16 x half> %2827, %2853
  %2855 = fpext <16 x half> %2854 to <16 x float>
  %2856 = extractelement <16 x float> %2855, i32 1
  %2857 = extractelement <16 x float> %2855, i32 0
  %2858 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2856, float %2857)
  %2859 = insertelement <8 x i16> undef, i16 %2858, i32 0
  %2860 = extractelement <16 x float> %2855, i32 3
  %2861 = extractelement <16 x float> %2855, i32 2
  %2862 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2860, float %2861)
  %2863 = insertelement <8 x i16> %2859, i16 %2862, i32 1
  %2864 = extractelement <16 x float> %2855, i32 5
  %2865 = extractelement <16 x float> %2855, i32 4
  %2866 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2864, float %2865)
  %2867 = insertelement <8 x i16> %2863, i16 %2866, i32 2
  %2868 = extractelement <16 x float> %2855, i32 7
  %2869 = extractelement <16 x float> %2855, i32 6
  %2870 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2868, float %2869)
  %2871 = insertelement <8 x i16> %2867, i16 %2870, i32 3
  %2872 = extractelement <16 x float> %2855, i32 9
  %2873 = extractelement <16 x float> %2855, i32 8
  %2874 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2872, float %2873)
  %2875 = insertelement <8 x i16> %2871, i16 %2874, i32 4
  %2876 = extractelement <16 x float> %2855, i32 11
  %2877 = extractelement <16 x float> %2855, i32 10
  %2878 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2876, float %2877)
  %2879 = insertelement <8 x i16> %2875, i16 %2878, i32 5
  %2880 = extractelement <16 x float> %2855, i32 13
  %2881 = extractelement <16 x float> %2855, i32 12
  %2882 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2880, float %2881)
  %2883 = insertelement <8 x i16> %2879, i16 %2882, i32 6
  %2884 = extractelement <16 x float> %2855, i32 15
  %2885 = extractelement <16 x float> %2855, i32 14
  %2886 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %2884, float %2885)
  %2887 = insertelement <8 x i16> %2883, i16 %2886, i32 7
  %2888 = bitcast <8 x i16> %2887 to <16 x i8>
  br label %2787

2889:                                             ; preds = %2792
  %2890 = phi <16 x i8> [ %2789, %2792 ]
  %2891 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2778, 0
  %2892 = getelementptr inbounds i8, ptr %2891, i64 %1503
  store <16 x i8> %2890, ptr %2892, align 16
  br label %2893

2893:                                             ; preds = %2889, %2766
  br label %2895

2894:                                             ; preds = %1476
  br label %2895

2895:                                             ; preds = %2894, %2893
  %2896 = add i64 %53, %19
  %2897 = mul i64 %2896, 16
  %2898 = trunc i64 %2897 to i32
  %2899 = load i64, ptr %20, align 8
  %2900 = icmp slt i64 %2896, %2899
  br i1 %2900, label %2901, label %4313

2901:                                             ; preds = %2895
  %2902 = load { i64, i64 }, ptr %6, align 8
  %2903 = extractvalue { i64, i64 } %2902, 1
  %2904 = trunc i64 %2903 to i32
  %2905 = icmp eq i32 %2904, 0
  %2906 = select i1 %2905, i32 1, i32 %2904
  %2907 = icmp eq i32 %2906, 0
  %2908 = select i1 %2907, i32 1, i32 %2906
  %2909 = udiv i32 %2898, %2908
  %2910 = select i1 %2907, i32 0, i32 %2909
  %2911 = urem i32 %2898, %2908
  %2912 = select i1 %2907, i32 0, i32 %2911
  %2913 = select i1 %2905, i32 0, i32 %2910
  %2914 = select i1 %2905, i32 0, i32 %2912
  %2915 = zext i32 %2914 to i64
  %2916 = trunc i64 %2915 to i32
  %2917 = add i64 %2915, 1
  %2918 = zext i32 %2913 to i64
  %2919 = trunc i64 %2918 to i32
  %2920 = mul i32 %2919, 512
  %2921 = add i32 %2920, %2916
  %2922 = sext i32 %2921 to i64
  %2923 = add i64 %2918, 1
  %2924 = add i64 %2915, 16
  %2925 = load i64, ptr %8, align 8
  %2926 = icmp sgt i64 %2924, %2925
  br i1 %2926, label %2927, label %4194

2927:                                             ; preds = %2901
  %2928 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %2929 = load i64, ptr %4, align 8
  %2930 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %2931 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2928, 0
  %2932 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2928, 1, 1, 0
  %2933 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %2928, 1, 1, 1
  %2934 = mul i64 %2918, %2933
  %2935 = add i64 %2934, %2915
  %2936 = getelementptr inbounds i8, ptr %2931, i64 %2935
  br label %2937

2937:                                             ; preds = %2943, %2927
  %2938 = phi i64 [ 0, %2927 ], [ %2946, %2943 ]
  %2939 = phi i8 [ 0, %2927 ], [ %2948, %2943 ]
  %2940 = icmp slt i64 %2938, 1
  br i1 %2940, label %2941, label %2942

2941:                                             ; preds = %2937
  br label %2943

2942:                                             ; preds = %2937
  br label %2949

2943:                                             ; preds = %2941
  %2944 = icmp eq i64 %2938, 1
  %2945 = add i64 %2938, 1
  %2946 = select i1 %2944, i64 %2938, i64 %2945
  %2947 = getelementptr inbounds i8, ptr %2936, i64 %2938
  %2948 = load i8, ptr %2947, align 1, !invariant.load !1
  br label %2937

2949:                                             ; preds = %2942
  %2950 = phi i8 [ %2939, %2942 ]
  %2951 = call i64 @llvm.smax.i64(i64 %2929, i64 1)
  br label %2952

2952:                                             ; preds = %2978, %2949
  %2953 = phi i64 [ 1, %2949 ], [ %2961, %2978 ]
  %2954 = phi i8 [ %2950, %2949 ], [ %2991, %2978 ]
  %2955 = icmp slt i64 %2953, %2951
  br i1 %2955, label %2956, label %2957

2956:                                             ; preds = %2952
  br label %2958

2957:                                             ; preds = %2952
  br label %2992

2958:                                             ; preds = %2956
  %2959 = icmp eq i64 %2953, %2951
  %2960 = add i64 %2953, 1
  %2961 = select i1 %2959, i64 %2953, i64 %2960
  %2962 = mul i64 %2953, %2932
  %2963 = add i64 %2962, %2934
  %2964 = add i64 %2963, %2915
  %2965 = getelementptr inbounds i8, ptr %2931, i64 %2964
  br label %2966

2966:                                             ; preds = %2972, %2958
  %2967 = phi i64 [ 0, %2958 ], [ %2975, %2972 ]
  %2968 = phi i8 [ 0, %2958 ], [ %2977, %2972 ]
  %2969 = icmp slt i64 %2967, 1
  br i1 %2969, label %2970, label %2971

2970:                                             ; preds = %2966
  br label %2972

2971:                                             ; preds = %2966
  br label %2978

2972:                                             ; preds = %2970
  %2973 = icmp eq i64 %2967, 1
  %2974 = add i64 %2967, 1
  %2975 = select i1 %2973, i64 %2967, i64 %2974
  %2976 = getelementptr inbounds i8, ptr %2965, i64 %2967
  %2977 = load i8, ptr %2976, align 1, !invariant.load !1
  br label %2966

2978:                                             ; preds = %2971
  %2979 = phi i8 [ %2968, %2971 ]
  %2980 = zext i8 %2954 to i16
  %2981 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2980)
  %2982 = trunc i32 %2981 to i16
  %2983 = bitcast i16 %2982 to half
  %2984 = zext i8 %2979 to i16
  %2985 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %2984)
  %2986 = trunc i32 %2985 to i16
  %2987 = bitcast i16 %2986 to half
  %2988 = fadd contract half %2983, %2987
  %2989 = fpext half %2988 to float
  %2990 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %2989)
  %2991 = trunc i16 %2990 to i8
  br label %2952

2992:                                             ; preds = %2957
  %2993 = phi i8 [ %2954, %2957 ]
  %2994 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %2930, 0
  %2995 = getelementptr inbounds i8, ptr %2994, i64 %2922
  store i8 %2993, ptr %2995, align 1
  %2996 = load { i64, i64 }, ptr %6, align 8
  %2997 = extractvalue { i64, i64 } %2996, 1
  %2998 = icmp sge i64 %2917, %2997
  %2999 = select i1 %2998, i64 0, i64 %2917
  %3000 = select i1 %2998, i64 %2923, i64 %2918
  %3001 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3002 = load i64, ptr %4, align 8
  %3003 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3004 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3001, 0
  %3005 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3001, 1, 1, 0
  %3006 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3001, 1, 1, 1
  %3007 = mul i64 %3000, %3006
  %3008 = add i64 %3007, %2999
  %3009 = getelementptr inbounds i8, ptr %3004, i64 %3008
  br label %3010

3010:                                             ; preds = %3016, %2992
  %3011 = phi i64 [ 0, %2992 ], [ %3019, %3016 ]
  %3012 = phi i8 [ 0, %2992 ], [ %3021, %3016 ]
  %3013 = icmp slt i64 %3011, 1
  br i1 %3013, label %3014, label %3015

3014:                                             ; preds = %3010
  br label %3016

3015:                                             ; preds = %3010
  br label %3022

3016:                                             ; preds = %3014
  %3017 = icmp eq i64 %3011, 1
  %3018 = add i64 %3011, 1
  %3019 = select i1 %3017, i64 %3011, i64 %3018
  %3020 = getelementptr inbounds i8, ptr %3009, i64 %3011
  %3021 = load i8, ptr %3020, align 1, !invariant.load !1
  br label %3010

3022:                                             ; preds = %3015
  %3023 = phi i8 [ %3012, %3015 ]
  %3024 = call i64 @llvm.smax.i64(i64 %3002, i64 1)
  br label %3025

3025:                                             ; preds = %3051, %3022
  %3026 = phi i64 [ 1, %3022 ], [ %3034, %3051 ]
  %3027 = phi i8 [ %3023, %3022 ], [ %3064, %3051 ]
  %3028 = icmp slt i64 %3026, %3024
  br i1 %3028, label %3029, label %3030

3029:                                             ; preds = %3025
  br label %3031

3030:                                             ; preds = %3025
  br label %3065

3031:                                             ; preds = %3029
  %3032 = icmp eq i64 %3026, %3024
  %3033 = add i64 %3026, 1
  %3034 = select i1 %3032, i64 %3026, i64 %3033
  %3035 = mul i64 %3026, %3005
  %3036 = add i64 %3035, %3007
  %3037 = add i64 %3036, %2999
  %3038 = getelementptr inbounds i8, ptr %3004, i64 %3037
  br label %3039

3039:                                             ; preds = %3045, %3031
  %3040 = phi i64 [ 0, %3031 ], [ %3048, %3045 ]
  %3041 = phi i8 [ 0, %3031 ], [ %3050, %3045 ]
  %3042 = icmp slt i64 %3040, 1
  br i1 %3042, label %3043, label %3044

3043:                                             ; preds = %3039
  br label %3045

3044:                                             ; preds = %3039
  br label %3051

3045:                                             ; preds = %3043
  %3046 = icmp eq i64 %3040, 1
  %3047 = add i64 %3040, 1
  %3048 = select i1 %3046, i64 %3040, i64 %3047
  %3049 = getelementptr inbounds i8, ptr %3038, i64 %3040
  %3050 = load i8, ptr %3049, align 1, !invariant.load !1
  br label %3039

3051:                                             ; preds = %3044
  %3052 = phi i8 [ %3041, %3044 ]
  %3053 = zext i8 %3027 to i16
  %3054 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3053)
  %3055 = trunc i32 %3054 to i16
  %3056 = bitcast i16 %3055 to half
  %3057 = zext i8 %3052 to i16
  %3058 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3057)
  %3059 = trunc i32 %3058 to i16
  %3060 = bitcast i16 %3059 to half
  %3061 = fadd contract half %3056, %3060
  %3062 = fpext half %3061 to float
  %3063 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3062)
  %3064 = trunc i16 %3063 to i8
  br label %3025

3065:                                             ; preds = %3030
  %3066 = phi i8 [ %3027, %3030 ]
  %3067 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3003, 0
  %3068 = trunc i64 %3000 to i32
  %3069 = mul i32 %3068, 512
  %3070 = trunc i64 %2999 to i32
  %3071 = add i32 %3069, %3070
  %3072 = sext i32 %3071 to i64
  %3073 = getelementptr inbounds i8, ptr %3067, i64 %3072
  store i8 %3066, ptr %3073, align 1
  %3074 = load { i64, i64 }, ptr %6, align 8
  %3075 = add i64 %2999, 1
  %3076 = extractvalue { i64, i64 } %3074, 1
  %3077 = icmp sge i64 %3075, %3076
  %3078 = select i1 %3077, i64 0, i64 %3075
  %3079 = add i64 %3000, 1
  %3080 = select i1 %3077, i64 %3079, i64 %3000
  %3081 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3082 = load i64, ptr %4, align 8
  %3083 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3084 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3081, 0
  %3085 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3081, 1, 1, 0
  %3086 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3081, 1, 1, 1
  %3087 = mul i64 %3080, %3086
  %3088 = add i64 %3087, %3078
  %3089 = getelementptr inbounds i8, ptr %3084, i64 %3088
  br label %3090

3090:                                             ; preds = %3096, %3065
  %3091 = phi i64 [ 0, %3065 ], [ %3099, %3096 ]
  %3092 = phi i8 [ 0, %3065 ], [ %3101, %3096 ]
  %3093 = icmp slt i64 %3091, 1
  br i1 %3093, label %3094, label %3095

3094:                                             ; preds = %3090
  br label %3096

3095:                                             ; preds = %3090
  br label %3102

3096:                                             ; preds = %3094
  %3097 = icmp eq i64 %3091, 1
  %3098 = add i64 %3091, 1
  %3099 = select i1 %3097, i64 %3091, i64 %3098
  %3100 = getelementptr inbounds i8, ptr %3089, i64 %3091
  %3101 = load i8, ptr %3100, align 1, !invariant.load !1
  br label %3090

3102:                                             ; preds = %3095
  %3103 = phi i8 [ %3092, %3095 ]
  %3104 = call i64 @llvm.smax.i64(i64 %3082, i64 1)
  br label %3105

3105:                                             ; preds = %3131, %3102
  %3106 = phi i64 [ 1, %3102 ], [ %3114, %3131 ]
  %3107 = phi i8 [ %3103, %3102 ], [ %3144, %3131 ]
  %3108 = icmp slt i64 %3106, %3104
  br i1 %3108, label %3109, label %3110

3109:                                             ; preds = %3105
  br label %3111

3110:                                             ; preds = %3105
  br label %3145

3111:                                             ; preds = %3109
  %3112 = icmp eq i64 %3106, %3104
  %3113 = add i64 %3106, 1
  %3114 = select i1 %3112, i64 %3106, i64 %3113
  %3115 = mul i64 %3106, %3085
  %3116 = add i64 %3115, %3087
  %3117 = add i64 %3116, %3078
  %3118 = getelementptr inbounds i8, ptr %3084, i64 %3117
  br label %3119

3119:                                             ; preds = %3125, %3111
  %3120 = phi i64 [ 0, %3111 ], [ %3128, %3125 ]
  %3121 = phi i8 [ 0, %3111 ], [ %3130, %3125 ]
  %3122 = icmp slt i64 %3120, 1
  br i1 %3122, label %3123, label %3124

3123:                                             ; preds = %3119
  br label %3125

3124:                                             ; preds = %3119
  br label %3131

3125:                                             ; preds = %3123
  %3126 = icmp eq i64 %3120, 1
  %3127 = add i64 %3120, 1
  %3128 = select i1 %3126, i64 %3120, i64 %3127
  %3129 = getelementptr inbounds i8, ptr %3118, i64 %3120
  %3130 = load i8, ptr %3129, align 1, !invariant.load !1
  br label %3119

3131:                                             ; preds = %3124
  %3132 = phi i8 [ %3121, %3124 ]
  %3133 = zext i8 %3107 to i16
  %3134 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3133)
  %3135 = trunc i32 %3134 to i16
  %3136 = bitcast i16 %3135 to half
  %3137 = zext i8 %3132 to i16
  %3138 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3137)
  %3139 = trunc i32 %3138 to i16
  %3140 = bitcast i16 %3139 to half
  %3141 = fadd contract half %3136, %3140
  %3142 = fpext half %3141 to float
  %3143 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3142)
  %3144 = trunc i16 %3143 to i8
  br label %3105

3145:                                             ; preds = %3110
  %3146 = phi i8 [ %3107, %3110 ]
  %3147 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3083, 0
  %3148 = trunc i64 %3080 to i32
  %3149 = mul i32 %3148, 512
  %3150 = trunc i64 %3078 to i32
  %3151 = add i32 %3149, %3150
  %3152 = sext i32 %3151 to i64
  %3153 = getelementptr inbounds i8, ptr %3147, i64 %3152
  store i8 %3146, ptr %3153, align 1
  %3154 = load { i64, i64 }, ptr %6, align 8
  %3155 = add i64 %3078, 1
  %3156 = extractvalue { i64, i64 } %3154, 1
  %3157 = icmp sge i64 %3155, %3156
  %3158 = select i1 %3157, i64 0, i64 %3155
  %3159 = add i64 %3080, 1
  %3160 = select i1 %3157, i64 %3159, i64 %3080
  %3161 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3162 = load i64, ptr %4, align 8
  %3163 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3164 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3161, 0
  %3165 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3161, 1, 1, 0
  %3166 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3161, 1, 1, 1
  %3167 = mul i64 %3160, %3166
  %3168 = add i64 %3167, %3158
  %3169 = getelementptr inbounds i8, ptr %3164, i64 %3168
  br label %3170

3170:                                             ; preds = %3176, %3145
  %3171 = phi i64 [ 0, %3145 ], [ %3179, %3176 ]
  %3172 = phi i8 [ 0, %3145 ], [ %3181, %3176 ]
  %3173 = icmp slt i64 %3171, 1
  br i1 %3173, label %3174, label %3175

3174:                                             ; preds = %3170
  br label %3176

3175:                                             ; preds = %3170
  br label %3182

3176:                                             ; preds = %3174
  %3177 = icmp eq i64 %3171, 1
  %3178 = add i64 %3171, 1
  %3179 = select i1 %3177, i64 %3171, i64 %3178
  %3180 = getelementptr inbounds i8, ptr %3169, i64 %3171
  %3181 = load i8, ptr %3180, align 1, !invariant.load !1
  br label %3170

3182:                                             ; preds = %3175
  %3183 = phi i8 [ %3172, %3175 ]
  %3184 = call i64 @llvm.smax.i64(i64 %3162, i64 1)
  br label %3185

3185:                                             ; preds = %3211, %3182
  %3186 = phi i64 [ 1, %3182 ], [ %3194, %3211 ]
  %3187 = phi i8 [ %3183, %3182 ], [ %3224, %3211 ]
  %3188 = icmp slt i64 %3186, %3184
  br i1 %3188, label %3189, label %3190

3189:                                             ; preds = %3185
  br label %3191

3190:                                             ; preds = %3185
  br label %3225

3191:                                             ; preds = %3189
  %3192 = icmp eq i64 %3186, %3184
  %3193 = add i64 %3186, 1
  %3194 = select i1 %3192, i64 %3186, i64 %3193
  %3195 = mul i64 %3186, %3165
  %3196 = add i64 %3195, %3167
  %3197 = add i64 %3196, %3158
  %3198 = getelementptr inbounds i8, ptr %3164, i64 %3197
  br label %3199

3199:                                             ; preds = %3205, %3191
  %3200 = phi i64 [ 0, %3191 ], [ %3208, %3205 ]
  %3201 = phi i8 [ 0, %3191 ], [ %3210, %3205 ]
  %3202 = icmp slt i64 %3200, 1
  br i1 %3202, label %3203, label %3204

3203:                                             ; preds = %3199
  br label %3205

3204:                                             ; preds = %3199
  br label %3211

3205:                                             ; preds = %3203
  %3206 = icmp eq i64 %3200, 1
  %3207 = add i64 %3200, 1
  %3208 = select i1 %3206, i64 %3200, i64 %3207
  %3209 = getelementptr inbounds i8, ptr %3198, i64 %3200
  %3210 = load i8, ptr %3209, align 1, !invariant.load !1
  br label %3199

3211:                                             ; preds = %3204
  %3212 = phi i8 [ %3201, %3204 ]
  %3213 = zext i8 %3187 to i16
  %3214 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3213)
  %3215 = trunc i32 %3214 to i16
  %3216 = bitcast i16 %3215 to half
  %3217 = zext i8 %3212 to i16
  %3218 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3217)
  %3219 = trunc i32 %3218 to i16
  %3220 = bitcast i16 %3219 to half
  %3221 = fadd contract half %3216, %3220
  %3222 = fpext half %3221 to float
  %3223 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3222)
  %3224 = trunc i16 %3223 to i8
  br label %3185

3225:                                             ; preds = %3190
  %3226 = phi i8 [ %3187, %3190 ]
  %3227 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3163, 0
  %3228 = trunc i64 %3160 to i32
  %3229 = mul i32 %3228, 512
  %3230 = trunc i64 %3158 to i32
  %3231 = add i32 %3229, %3230
  %3232 = sext i32 %3231 to i64
  %3233 = getelementptr inbounds i8, ptr %3227, i64 %3232
  store i8 %3226, ptr %3233, align 1
  %3234 = load { i64, i64 }, ptr %6, align 8
  %3235 = add i64 %3158, 1
  %3236 = extractvalue { i64, i64 } %3234, 1
  %3237 = icmp sge i64 %3235, %3236
  %3238 = select i1 %3237, i64 0, i64 %3235
  %3239 = add i64 %3160, 1
  %3240 = select i1 %3237, i64 %3239, i64 %3160
  %3241 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3242 = load i64, ptr %4, align 8
  %3243 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3244 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3241, 0
  %3245 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3241, 1, 1, 0
  %3246 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3241, 1, 1, 1
  %3247 = mul i64 %3240, %3246
  %3248 = add i64 %3247, %3238
  %3249 = getelementptr inbounds i8, ptr %3244, i64 %3248
  br label %3250

3250:                                             ; preds = %3256, %3225
  %3251 = phi i64 [ 0, %3225 ], [ %3259, %3256 ]
  %3252 = phi i8 [ 0, %3225 ], [ %3261, %3256 ]
  %3253 = icmp slt i64 %3251, 1
  br i1 %3253, label %3254, label %3255

3254:                                             ; preds = %3250
  br label %3256

3255:                                             ; preds = %3250
  br label %3262

3256:                                             ; preds = %3254
  %3257 = icmp eq i64 %3251, 1
  %3258 = add i64 %3251, 1
  %3259 = select i1 %3257, i64 %3251, i64 %3258
  %3260 = getelementptr inbounds i8, ptr %3249, i64 %3251
  %3261 = load i8, ptr %3260, align 1, !invariant.load !1
  br label %3250

3262:                                             ; preds = %3255
  %3263 = phi i8 [ %3252, %3255 ]
  %3264 = call i64 @llvm.smax.i64(i64 %3242, i64 1)
  br label %3265

3265:                                             ; preds = %3291, %3262
  %3266 = phi i64 [ 1, %3262 ], [ %3274, %3291 ]
  %3267 = phi i8 [ %3263, %3262 ], [ %3304, %3291 ]
  %3268 = icmp slt i64 %3266, %3264
  br i1 %3268, label %3269, label %3270

3269:                                             ; preds = %3265
  br label %3271

3270:                                             ; preds = %3265
  br label %3305

3271:                                             ; preds = %3269
  %3272 = icmp eq i64 %3266, %3264
  %3273 = add i64 %3266, 1
  %3274 = select i1 %3272, i64 %3266, i64 %3273
  %3275 = mul i64 %3266, %3245
  %3276 = add i64 %3275, %3247
  %3277 = add i64 %3276, %3238
  %3278 = getelementptr inbounds i8, ptr %3244, i64 %3277
  br label %3279

3279:                                             ; preds = %3285, %3271
  %3280 = phi i64 [ 0, %3271 ], [ %3288, %3285 ]
  %3281 = phi i8 [ 0, %3271 ], [ %3290, %3285 ]
  %3282 = icmp slt i64 %3280, 1
  br i1 %3282, label %3283, label %3284

3283:                                             ; preds = %3279
  br label %3285

3284:                                             ; preds = %3279
  br label %3291

3285:                                             ; preds = %3283
  %3286 = icmp eq i64 %3280, 1
  %3287 = add i64 %3280, 1
  %3288 = select i1 %3286, i64 %3280, i64 %3287
  %3289 = getelementptr inbounds i8, ptr %3278, i64 %3280
  %3290 = load i8, ptr %3289, align 1, !invariant.load !1
  br label %3279

3291:                                             ; preds = %3284
  %3292 = phi i8 [ %3281, %3284 ]
  %3293 = zext i8 %3267 to i16
  %3294 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3293)
  %3295 = trunc i32 %3294 to i16
  %3296 = bitcast i16 %3295 to half
  %3297 = zext i8 %3292 to i16
  %3298 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3297)
  %3299 = trunc i32 %3298 to i16
  %3300 = bitcast i16 %3299 to half
  %3301 = fadd contract half %3296, %3300
  %3302 = fpext half %3301 to float
  %3303 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3302)
  %3304 = trunc i16 %3303 to i8
  br label %3265

3305:                                             ; preds = %3270
  %3306 = phi i8 [ %3267, %3270 ]
  %3307 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3243, 0
  %3308 = trunc i64 %3240 to i32
  %3309 = mul i32 %3308, 512
  %3310 = trunc i64 %3238 to i32
  %3311 = add i32 %3309, %3310
  %3312 = sext i32 %3311 to i64
  %3313 = getelementptr inbounds i8, ptr %3307, i64 %3312
  store i8 %3306, ptr %3313, align 1
  %3314 = load { i64, i64 }, ptr %6, align 8
  %3315 = add i64 %3238, 1
  %3316 = extractvalue { i64, i64 } %3314, 1
  %3317 = icmp sge i64 %3315, %3316
  %3318 = select i1 %3317, i64 0, i64 %3315
  %3319 = add i64 %3240, 1
  %3320 = select i1 %3317, i64 %3319, i64 %3240
  %3321 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3322 = load i64, ptr %4, align 8
  %3323 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3324 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3321, 0
  %3325 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3321, 1, 1, 0
  %3326 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3321, 1, 1, 1
  %3327 = mul i64 %3320, %3326
  %3328 = add i64 %3327, %3318
  %3329 = getelementptr inbounds i8, ptr %3324, i64 %3328
  br label %3330

3330:                                             ; preds = %3336, %3305
  %3331 = phi i64 [ 0, %3305 ], [ %3339, %3336 ]
  %3332 = phi i8 [ 0, %3305 ], [ %3341, %3336 ]
  %3333 = icmp slt i64 %3331, 1
  br i1 %3333, label %3334, label %3335

3334:                                             ; preds = %3330
  br label %3336

3335:                                             ; preds = %3330
  br label %3342

3336:                                             ; preds = %3334
  %3337 = icmp eq i64 %3331, 1
  %3338 = add i64 %3331, 1
  %3339 = select i1 %3337, i64 %3331, i64 %3338
  %3340 = getelementptr inbounds i8, ptr %3329, i64 %3331
  %3341 = load i8, ptr %3340, align 1, !invariant.load !1
  br label %3330

3342:                                             ; preds = %3335
  %3343 = phi i8 [ %3332, %3335 ]
  %3344 = call i64 @llvm.smax.i64(i64 %3322, i64 1)
  br label %3345

3345:                                             ; preds = %3371, %3342
  %3346 = phi i64 [ 1, %3342 ], [ %3354, %3371 ]
  %3347 = phi i8 [ %3343, %3342 ], [ %3384, %3371 ]
  %3348 = icmp slt i64 %3346, %3344
  br i1 %3348, label %3349, label %3350

3349:                                             ; preds = %3345
  br label %3351

3350:                                             ; preds = %3345
  br label %3385

3351:                                             ; preds = %3349
  %3352 = icmp eq i64 %3346, %3344
  %3353 = add i64 %3346, 1
  %3354 = select i1 %3352, i64 %3346, i64 %3353
  %3355 = mul i64 %3346, %3325
  %3356 = add i64 %3355, %3327
  %3357 = add i64 %3356, %3318
  %3358 = getelementptr inbounds i8, ptr %3324, i64 %3357
  br label %3359

3359:                                             ; preds = %3365, %3351
  %3360 = phi i64 [ 0, %3351 ], [ %3368, %3365 ]
  %3361 = phi i8 [ 0, %3351 ], [ %3370, %3365 ]
  %3362 = icmp slt i64 %3360, 1
  br i1 %3362, label %3363, label %3364

3363:                                             ; preds = %3359
  br label %3365

3364:                                             ; preds = %3359
  br label %3371

3365:                                             ; preds = %3363
  %3366 = icmp eq i64 %3360, 1
  %3367 = add i64 %3360, 1
  %3368 = select i1 %3366, i64 %3360, i64 %3367
  %3369 = getelementptr inbounds i8, ptr %3358, i64 %3360
  %3370 = load i8, ptr %3369, align 1, !invariant.load !1
  br label %3359

3371:                                             ; preds = %3364
  %3372 = phi i8 [ %3361, %3364 ]
  %3373 = zext i8 %3347 to i16
  %3374 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3373)
  %3375 = trunc i32 %3374 to i16
  %3376 = bitcast i16 %3375 to half
  %3377 = zext i8 %3372 to i16
  %3378 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3377)
  %3379 = trunc i32 %3378 to i16
  %3380 = bitcast i16 %3379 to half
  %3381 = fadd contract half %3376, %3380
  %3382 = fpext half %3381 to float
  %3383 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3382)
  %3384 = trunc i16 %3383 to i8
  br label %3345

3385:                                             ; preds = %3350
  %3386 = phi i8 [ %3347, %3350 ]
  %3387 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3323, 0
  %3388 = trunc i64 %3320 to i32
  %3389 = mul i32 %3388, 512
  %3390 = trunc i64 %3318 to i32
  %3391 = add i32 %3389, %3390
  %3392 = sext i32 %3391 to i64
  %3393 = getelementptr inbounds i8, ptr %3387, i64 %3392
  store i8 %3386, ptr %3393, align 1
  %3394 = load { i64, i64 }, ptr %6, align 8
  %3395 = add i64 %3318, 1
  %3396 = extractvalue { i64, i64 } %3394, 1
  %3397 = icmp sge i64 %3395, %3396
  %3398 = select i1 %3397, i64 0, i64 %3395
  %3399 = add i64 %3320, 1
  %3400 = select i1 %3397, i64 %3399, i64 %3320
  %3401 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3402 = load i64, ptr %4, align 8
  %3403 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3404 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3401, 0
  %3405 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3401, 1, 1, 0
  %3406 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3401, 1, 1, 1
  %3407 = mul i64 %3400, %3406
  %3408 = add i64 %3407, %3398
  %3409 = getelementptr inbounds i8, ptr %3404, i64 %3408
  br label %3410

3410:                                             ; preds = %3416, %3385
  %3411 = phi i64 [ 0, %3385 ], [ %3419, %3416 ]
  %3412 = phi i8 [ 0, %3385 ], [ %3421, %3416 ]
  %3413 = icmp slt i64 %3411, 1
  br i1 %3413, label %3414, label %3415

3414:                                             ; preds = %3410
  br label %3416

3415:                                             ; preds = %3410
  br label %3422

3416:                                             ; preds = %3414
  %3417 = icmp eq i64 %3411, 1
  %3418 = add i64 %3411, 1
  %3419 = select i1 %3417, i64 %3411, i64 %3418
  %3420 = getelementptr inbounds i8, ptr %3409, i64 %3411
  %3421 = load i8, ptr %3420, align 1, !invariant.load !1
  br label %3410

3422:                                             ; preds = %3415
  %3423 = phi i8 [ %3412, %3415 ]
  %3424 = call i64 @llvm.smax.i64(i64 %3402, i64 1)
  br label %3425

3425:                                             ; preds = %3451, %3422
  %3426 = phi i64 [ 1, %3422 ], [ %3434, %3451 ]
  %3427 = phi i8 [ %3423, %3422 ], [ %3464, %3451 ]
  %3428 = icmp slt i64 %3426, %3424
  br i1 %3428, label %3429, label %3430

3429:                                             ; preds = %3425
  br label %3431

3430:                                             ; preds = %3425
  br label %3465

3431:                                             ; preds = %3429
  %3432 = icmp eq i64 %3426, %3424
  %3433 = add i64 %3426, 1
  %3434 = select i1 %3432, i64 %3426, i64 %3433
  %3435 = mul i64 %3426, %3405
  %3436 = add i64 %3435, %3407
  %3437 = add i64 %3436, %3398
  %3438 = getelementptr inbounds i8, ptr %3404, i64 %3437
  br label %3439

3439:                                             ; preds = %3445, %3431
  %3440 = phi i64 [ 0, %3431 ], [ %3448, %3445 ]
  %3441 = phi i8 [ 0, %3431 ], [ %3450, %3445 ]
  %3442 = icmp slt i64 %3440, 1
  br i1 %3442, label %3443, label %3444

3443:                                             ; preds = %3439
  br label %3445

3444:                                             ; preds = %3439
  br label %3451

3445:                                             ; preds = %3443
  %3446 = icmp eq i64 %3440, 1
  %3447 = add i64 %3440, 1
  %3448 = select i1 %3446, i64 %3440, i64 %3447
  %3449 = getelementptr inbounds i8, ptr %3438, i64 %3440
  %3450 = load i8, ptr %3449, align 1, !invariant.load !1
  br label %3439

3451:                                             ; preds = %3444
  %3452 = phi i8 [ %3441, %3444 ]
  %3453 = zext i8 %3427 to i16
  %3454 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3453)
  %3455 = trunc i32 %3454 to i16
  %3456 = bitcast i16 %3455 to half
  %3457 = zext i8 %3452 to i16
  %3458 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3457)
  %3459 = trunc i32 %3458 to i16
  %3460 = bitcast i16 %3459 to half
  %3461 = fadd contract half %3456, %3460
  %3462 = fpext half %3461 to float
  %3463 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3462)
  %3464 = trunc i16 %3463 to i8
  br label %3425

3465:                                             ; preds = %3430
  %3466 = phi i8 [ %3427, %3430 ]
  %3467 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3403, 0
  %3468 = trunc i64 %3400 to i32
  %3469 = mul i32 %3468, 512
  %3470 = trunc i64 %3398 to i32
  %3471 = add i32 %3469, %3470
  %3472 = sext i32 %3471 to i64
  %3473 = getelementptr inbounds i8, ptr %3467, i64 %3472
  store i8 %3466, ptr %3473, align 1
  %3474 = load { i64, i64 }, ptr %6, align 8
  %3475 = add i64 %3398, 1
  %3476 = extractvalue { i64, i64 } %3474, 1
  %3477 = icmp sge i64 %3475, %3476
  %3478 = select i1 %3477, i64 0, i64 %3475
  %3479 = add i64 %3400, 1
  %3480 = select i1 %3477, i64 %3479, i64 %3400
  %3481 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3482 = load i64, ptr %4, align 8
  %3483 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3484 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3481, 0
  %3485 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3481, 1, 1, 0
  %3486 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3481, 1, 1, 1
  %3487 = mul i64 %3480, %3486
  %3488 = add i64 %3487, %3478
  %3489 = getelementptr inbounds i8, ptr %3484, i64 %3488
  br label %3490

3490:                                             ; preds = %3496, %3465
  %3491 = phi i64 [ 0, %3465 ], [ %3499, %3496 ]
  %3492 = phi i8 [ 0, %3465 ], [ %3501, %3496 ]
  %3493 = icmp slt i64 %3491, 1
  br i1 %3493, label %3494, label %3495

3494:                                             ; preds = %3490
  br label %3496

3495:                                             ; preds = %3490
  br label %3502

3496:                                             ; preds = %3494
  %3497 = icmp eq i64 %3491, 1
  %3498 = add i64 %3491, 1
  %3499 = select i1 %3497, i64 %3491, i64 %3498
  %3500 = getelementptr inbounds i8, ptr %3489, i64 %3491
  %3501 = load i8, ptr %3500, align 1, !invariant.load !1
  br label %3490

3502:                                             ; preds = %3495
  %3503 = phi i8 [ %3492, %3495 ]
  %3504 = call i64 @llvm.smax.i64(i64 %3482, i64 1)
  br label %3505

3505:                                             ; preds = %3531, %3502
  %3506 = phi i64 [ 1, %3502 ], [ %3514, %3531 ]
  %3507 = phi i8 [ %3503, %3502 ], [ %3544, %3531 ]
  %3508 = icmp slt i64 %3506, %3504
  br i1 %3508, label %3509, label %3510

3509:                                             ; preds = %3505
  br label %3511

3510:                                             ; preds = %3505
  br label %3545

3511:                                             ; preds = %3509
  %3512 = icmp eq i64 %3506, %3504
  %3513 = add i64 %3506, 1
  %3514 = select i1 %3512, i64 %3506, i64 %3513
  %3515 = mul i64 %3506, %3485
  %3516 = add i64 %3515, %3487
  %3517 = add i64 %3516, %3478
  %3518 = getelementptr inbounds i8, ptr %3484, i64 %3517
  br label %3519

3519:                                             ; preds = %3525, %3511
  %3520 = phi i64 [ 0, %3511 ], [ %3528, %3525 ]
  %3521 = phi i8 [ 0, %3511 ], [ %3530, %3525 ]
  %3522 = icmp slt i64 %3520, 1
  br i1 %3522, label %3523, label %3524

3523:                                             ; preds = %3519
  br label %3525

3524:                                             ; preds = %3519
  br label %3531

3525:                                             ; preds = %3523
  %3526 = icmp eq i64 %3520, 1
  %3527 = add i64 %3520, 1
  %3528 = select i1 %3526, i64 %3520, i64 %3527
  %3529 = getelementptr inbounds i8, ptr %3518, i64 %3520
  %3530 = load i8, ptr %3529, align 1, !invariant.load !1
  br label %3519

3531:                                             ; preds = %3524
  %3532 = phi i8 [ %3521, %3524 ]
  %3533 = zext i8 %3507 to i16
  %3534 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3533)
  %3535 = trunc i32 %3534 to i16
  %3536 = bitcast i16 %3535 to half
  %3537 = zext i8 %3532 to i16
  %3538 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3537)
  %3539 = trunc i32 %3538 to i16
  %3540 = bitcast i16 %3539 to half
  %3541 = fadd contract half %3536, %3540
  %3542 = fpext half %3541 to float
  %3543 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3542)
  %3544 = trunc i16 %3543 to i8
  br label %3505

3545:                                             ; preds = %3510
  %3546 = phi i8 [ %3507, %3510 ]
  %3547 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3483, 0
  %3548 = trunc i64 %3480 to i32
  %3549 = mul i32 %3548, 512
  %3550 = trunc i64 %3478 to i32
  %3551 = add i32 %3549, %3550
  %3552 = sext i32 %3551 to i64
  %3553 = getelementptr inbounds i8, ptr %3547, i64 %3552
  store i8 %3546, ptr %3553, align 1
  %3554 = load { i64, i64 }, ptr %6, align 8
  %3555 = add i64 %3478, 1
  %3556 = extractvalue { i64, i64 } %3554, 1
  %3557 = icmp sge i64 %3555, %3556
  %3558 = select i1 %3557, i64 0, i64 %3555
  %3559 = add i64 %3480, 1
  %3560 = select i1 %3557, i64 %3559, i64 %3480
  %3561 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3562 = load i64, ptr %4, align 8
  %3563 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3564 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3561, 0
  %3565 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3561, 1, 1, 0
  %3566 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3561, 1, 1, 1
  %3567 = mul i64 %3560, %3566
  %3568 = add i64 %3567, %3558
  %3569 = getelementptr inbounds i8, ptr %3564, i64 %3568
  br label %3570

3570:                                             ; preds = %3576, %3545
  %3571 = phi i64 [ 0, %3545 ], [ %3579, %3576 ]
  %3572 = phi i8 [ 0, %3545 ], [ %3581, %3576 ]
  %3573 = icmp slt i64 %3571, 1
  br i1 %3573, label %3574, label %3575

3574:                                             ; preds = %3570
  br label %3576

3575:                                             ; preds = %3570
  br label %3582

3576:                                             ; preds = %3574
  %3577 = icmp eq i64 %3571, 1
  %3578 = add i64 %3571, 1
  %3579 = select i1 %3577, i64 %3571, i64 %3578
  %3580 = getelementptr inbounds i8, ptr %3569, i64 %3571
  %3581 = load i8, ptr %3580, align 1, !invariant.load !1
  br label %3570

3582:                                             ; preds = %3575
  %3583 = phi i8 [ %3572, %3575 ]
  %3584 = call i64 @llvm.smax.i64(i64 %3562, i64 1)
  br label %3585

3585:                                             ; preds = %3611, %3582
  %3586 = phi i64 [ 1, %3582 ], [ %3594, %3611 ]
  %3587 = phi i8 [ %3583, %3582 ], [ %3624, %3611 ]
  %3588 = icmp slt i64 %3586, %3584
  br i1 %3588, label %3589, label %3590

3589:                                             ; preds = %3585
  br label %3591

3590:                                             ; preds = %3585
  br label %3625

3591:                                             ; preds = %3589
  %3592 = icmp eq i64 %3586, %3584
  %3593 = add i64 %3586, 1
  %3594 = select i1 %3592, i64 %3586, i64 %3593
  %3595 = mul i64 %3586, %3565
  %3596 = add i64 %3595, %3567
  %3597 = add i64 %3596, %3558
  %3598 = getelementptr inbounds i8, ptr %3564, i64 %3597
  br label %3599

3599:                                             ; preds = %3605, %3591
  %3600 = phi i64 [ 0, %3591 ], [ %3608, %3605 ]
  %3601 = phi i8 [ 0, %3591 ], [ %3610, %3605 ]
  %3602 = icmp slt i64 %3600, 1
  br i1 %3602, label %3603, label %3604

3603:                                             ; preds = %3599
  br label %3605

3604:                                             ; preds = %3599
  br label %3611

3605:                                             ; preds = %3603
  %3606 = icmp eq i64 %3600, 1
  %3607 = add i64 %3600, 1
  %3608 = select i1 %3606, i64 %3600, i64 %3607
  %3609 = getelementptr inbounds i8, ptr %3598, i64 %3600
  %3610 = load i8, ptr %3609, align 1, !invariant.load !1
  br label %3599

3611:                                             ; preds = %3604
  %3612 = phi i8 [ %3601, %3604 ]
  %3613 = zext i8 %3587 to i16
  %3614 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3613)
  %3615 = trunc i32 %3614 to i16
  %3616 = bitcast i16 %3615 to half
  %3617 = zext i8 %3612 to i16
  %3618 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3617)
  %3619 = trunc i32 %3618 to i16
  %3620 = bitcast i16 %3619 to half
  %3621 = fadd contract half %3616, %3620
  %3622 = fpext half %3621 to float
  %3623 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3622)
  %3624 = trunc i16 %3623 to i8
  br label %3585

3625:                                             ; preds = %3590
  %3626 = phi i8 [ %3587, %3590 ]
  %3627 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3563, 0
  %3628 = trunc i64 %3560 to i32
  %3629 = mul i32 %3628, 512
  %3630 = trunc i64 %3558 to i32
  %3631 = add i32 %3629, %3630
  %3632 = sext i32 %3631 to i64
  %3633 = getelementptr inbounds i8, ptr %3627, i64 %3632
  store i8 %3626, ptr %3633, align 1
  %3634 = load { i64, i64 }, ptr %6, align 8
  %3635 = add i64 %3558, 1
  %3636 = extractvalue { i64, i64 } %3634, 1
  %3637 = icmp sge i64 %3635, %3636
  %3638 = select i1 %3637, i64 0, i64 %3635
  %3639 = add i64 %3560, 1
  %3640 = select i1 %3637, i64 %3639, i64 %3560
  %3641 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3642 = load i64, ptr %4, align 8
  %3643 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3644 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3641, 0
  %3645 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3641, 1, 1, 0
  %3646 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3641, 1, 1, 1
  %3647 = mul i64 %3640, %3646
  %3648 = add i64 %3647, %3638
  %3649 = getelementptr inbounds i8, ptr %3644, i64 %3648
  br label %3650

3650:                                             ; preds = %3656, %3625
  %3651 = phi i64 [ 0, %3625 ], [ %3659, %3656 ]
  %3652 = phi i8 [ 0, %3625 ], [ %3661, %3656 ]
  %3653 = icmp slt i64 %3651, 1
  br i1 %3653, label %3654, label %3655

3654:                                             ; preds = %3650
  br label %3656

3655:                                             ; preds = %3650
  br label %3662

3656:                                             ; preds = %3654
  %3657 = icmp eq i64 %3651, 1
  %3658 = add i64 %3651, 1
  %3659 = select i1 %3657, i64 %3651, i64 %3658
  %3660 = getelementptr inbounds i8, ptr %3649, i64 %3651
  %3661 = load i8, ptr %3660, align 1, !invariant.load !1
  br label %3650

3662:                                             ; preds = %3655
  %3663 = phi i8 [ %3652, %3655 ]
  %3664 = call i64 @llvm.smax.i64(i64 %3642, i64 1)
  br label %3665

3665:                                             ; preds = %3691, %3662
  %3666 = phi i64 [ 1, %3662 ], [ %3674, %3691 ]
  %3667 = phi i8 [ %3663, %3662 ], [ %3704, %3691 ]
  %3668 = icmp slt i64 %3666, %3664
  br i1 %3668, label %3669, label %3670

3669:                                             ; preds = %3665
  br label %3671

3670:                                             ; preds = %3665
  br label %3705

3671:                                             ; preds = %3669
  %3672 = icmp eq i64 %3666, %3664
  %3673 = add i64 %3666, 1
  %3674 = select i1 %3672, i64 %3666, i64 %3673
  %3675 = mul i64 %3666, %3645
  %3676 = add i64 %3675, %3647
  %3677 = add i64 %3676, %3638
  %3678 = getelementptr inbounds i8, ptr %3644, i64 %3677
  br label %3679

3679:                                             ; preds = %3685, %3671
  %3680 = phi i64 [ 0, %3671 ], [ %3688, %3685 ]
  %3681 = phi i8 [ 0, %3671 ], [ %3690, %3685 ]
  %3682 = icmp slt i64 %3680, 1
  br i1 %3682, label %3683, label %3684

3683:                                             ; preds = %3679
  br label %3685

3684:                                             ; preds = %3679
  br label %3691

3685:                                             ; preds = %3683
  %3686 = icmp eq i64 %3680, 1
  %3687 = add i64 %3680, 1
  %3688 = select i1 %3686, i64 %3680, i64 %3687
  %3689 = getelementptr inbounds i8, ptr %3678, i64 %3680
  %3690 = load i8, ptr %3689, align 1, !invariant.load !1
  br label %3679

3691:                                             ; preds = %3684
  %3692 = phi i8 [ %3681, %3684 ]
  %3693 = zext i8 %3667 to i16
  %3694 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3693)
  %3695 = trunc i32 %3694 to i16
  %3696 = bitcast i16 %3695 to half
  %3697 = zext i8 %3692 to i16
  %3698 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3697)
  %3699 = trunc i32 %3698 to i16
  %3700 = bitcast i16 %3699 to half
  %3701 = fadd contract half %3696, %3700
  %3702 = fpext half %3701 to float
  %3703 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3702)
  %3704 = trunc i16 %3703 to i8
  br label %3665

3705:                                             ; preds = %3670
  %3706 = phi i8 [ %3667, %3670 ]
  %3707 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3643, 0
  %3708 = trunc i64 %3640 to i32
  %3709 = mul i32 %3708, 512
  %3710 = trunc i64 %3638 to i32
  %3711 = add i32 %3709, %3710
  %3712 = sext i32 %3711 to i64
  %3713 = getelementptr inbounds i8, ptr %3707, i64 %3712
  store i8 %3706, ptr %3713, align 1
  %3714 = load { i64, i64 }, ptr %6, align 8
  %3715 = add i64 %3638, 1
  %3716 = extractvalue { i64, i64 } %3714, 1
  %3717 = icmp sge i64 %3715, %3716
  %3718 = select i1 %3717, i64 0, i64 %3715
  %3719 = add i64 %3640, 1
  %3720 = select i1 %3717, i64 %3719, i64 %3640
  %3721 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3722 = load i64, ptr %4, align 8
  %3723 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3724 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3721, 0
  %3725 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3721, 1, 1, 0
  %3726 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3721, 1, 1, 1
  %3727 = mul i64 %3720, %3726
  %3728 = add i64 %3727, %3718
  %3729 = getelementptr inbounds i8, ptr %3724, i64 %3728
  br label %3730

3730:                                             ; preds = %3736, %3705
  %3731 = phi i64 [ 0, %3705 ], [ %3739, %3736 ]
  %3732 = phi i8 [ 0, %3705 ], [ %3741, %3736 ]
  %3733 = icmp slt i64 %3731, 1
  br i1 %3733, label %3734, label %3735

3734:                                             ; preds = %3730
  br label %3736

3735:                                             ; preds = %3730
  br label %3742

3736:                                             ; preds = %3734
  %3737 = icmp eq i64 %3731, 1
  %3738 = add i64 %3731, 1
  %3739 = select i1 %3737, i64 %3731, i64 %3738
  %3740 = getelementptr inbounds i8, ptr %3729, i64 %3731
  %3741 = load i8, ptr %3740, align 1, !invariant.load !1
  br label %3730

3742:                                             ; preds = %3735
  %3743 = phi i8 [ %3732, %3735 ]
  %3744 = call i64 @llvm.smax.i64(i64 %3722, i64 1)
  br label %3745

3745:                                             ; preds = %3771, %3742
  %3746 = phi i64 [ 1, %3742 ], [ %3754, %3771 ]
  %3747 = phi i8 [ %3743, %3742 ], [ %3784, %3771 ]
  %3748 = icmp slt i64 %3746, %3744
  br i1 %3748, label %3749, label %3750

3749:                                             ; preds = %3745
  br label %3751

3750:                                             ; preds = %3745
  br label %3785

3751:                                             ; preds = %3749
  %3752 = icmp eq i64 %3746, %3744
  %3753 = add i64 %3746, 1
  %3754 = select i1 %3752, i64 %3746, i64 %3753
  %3755 = mul i64 %3746, %3725
  %3756 = add i64 %3755, %3727
  %3757 = add i64 %3756, %3718
  %3758 = getelementptr inbounds i8, ptr %3724, i64 %3757
  br label %3759

3759:                                             ; preds = %3765, %3751
  %3760 = phi i64 [ 0, %3751 ], [ %3768, %3765 ]
  %3761 = phi i8 [ 0, %3751 ], [ %3770, %3765 ]
  %3762 = icmp slt i64 %3760, 1
  br i1 %3762, label %3763, label %3764

3763:                                             ; preds = %3759
  br label %3765

3764:                                             ; preds = %3759
  br label %3771

3765:                                             ; preds = %3763
  %3766 = icmp eq i64 %3760, 1
  %3767 = add i64 %3760, 1
  %3768 = select i1 %3766, i64 %3760, i64 %3767
  %3769 = getelementptr inbounds i8, ptr %3758, i64 %3760
  %3770 = load i8, ptr %3769, align 1, !invariant.load !1
  br label %3759

3771:                                             ; preds = %3764
  %3772 = phi i8 [ %3761, %3764 ]
  %3773 = zext i8 %3747 to i16
  %3774 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3773)
  %3775 = trunc i32 %3774 to i16
  %3776 = bitcast i16 %3775 to half
  %3777 = zext i8 %3772 to i16
  %3778 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3777)
  %3779 = trunc i32 %3778 to i16
  %3780 = bitcast i16 %3779 to half
  %3781 = fadd contract half %3776, %3780
  %3782 = fpext half %3781 to float
  %3783 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3782)
  %3784 = trunc i16 %3783 to i8
  br label %3745

3785:                                             ; preds = %3750
  %3786 = phi i8 [ %3747, %3750 ]
  %3787 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3723, 0
  %3788 = trunc i64 %3720 to i32
  %3789 = mul i32 %3788, 512
  %3790 = trunc i64 %3718 to i32
  %3791 = add i32 %3789, %3790
  %3792 = sext i32 %3791 to i64
  %3793 = getelementptr inbounds i8, ptr %3787, i64 %3792
  store i8 %3786, ptr %3793, align 1
  %3794 = load { i64, i64 }, ptr %6, align 8
  %3795 = add i64 %3718, 1
  %3796 = extractvalue { i64, i64 } %3794, 1
  %3797 = icmp sge i64 %3795, %3796
  %3798 = select i1 %3797, i64 0, i64 %3795
  %3799 = add i64 %3720, 1
  %3800 = select i1 %3797, i64 %3799, i64 %3720
  %3801 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3802 = load i64, ptr %4, align 8
  %3803 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3804 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3801, 0
  %3805 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3801, 1, 1, 0
  %3806 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3801, 1, 1, 1
  %3807 = mul i64 %3800, %3806
  %3808 = add i64 %3807, %3798
  %3809 = getelementptr inbounds i8, ptr %3804, i64 %3808
  br label %3810

3810:                                             ; preds = %3816, %3785
  %3811 = phi i64 [ 0, %3785 ], [ %3819, %3816 ]
  %3812 = phi i8 [ 0, %3785 ], [ %3821, %3816 ]
  %3813 = icmp slt i64 %3811, 1
  br i1 %3813, label %3814, label %3815

3814:                                             ; preds = %3810
  br label %3816

3815:                                             ; preds = %3810
  br label %3822

3816:                                             ; preds = %3814
  %3817 = icmp eq i64 %3811, 1
  %3818 = add i64 %3811, 1
  %3819 = select i1 %3817, i64 %3811, i64 %3818
  %3820 = getelementptr inbounds i8, ptr %3809, i64 %3811
  %3821 = load i8, ptr %3820, align 1, !invariant.load !1
  br label %3810

3822:                                             ; preds = %3815
  %3823 = phi i8 [ %3812, %3815 ]
  %3824 = call i64 @llvm.smax.i64(i64 %3802, i64 1)
  br label %3825

3825:                                             ; preds = %3851, %3822
  %3826 = phi i64 [ 1, %3822 ], [ %3834, %3851 ]
  %3827 = phi i8 [ %3823, %3822 ], [ %3864, %3851 ]
  %3828 = icmp slt i64 %3826, %3824
  br i1 %3828, label %3829, label %3830

3829:                                             ; preds = %3825
  br label %3831

3830:                                             ; preds = %3825
  br label %3865

3831:                                             ; preds = %3829
  %3832 = icmp eq i64 %3826, %3824
  %3833 = add i64 %3826, 1
  %3834 = select i1 %3832, i64 %3826, i64 %3833
  %3835 = mul i64 %3826, %3805
  %3836 = add i64 %3835, %3807
  %3837 = add i64 %3836, %3798
  %3838 = getelementptr inbounds i8, ptr %3804, i64 %3837
  br label %3839

3839:                                             ; preds = %3845, %3831
  %3840 = phi i64 [ 0, %3831 ], [ %3848, %3845 ]
  %3841 = phi i8 [ 0, %3831 ], [ %3850, %3845 ]
  %3842 = icmp slt i64 %3840, 1
  br i1 %3842, label %3843, label %3844

3843:                                             ; preds = %3839
  br label %3845

3844:                                             ; preds = %3839
  br label %3851

3845:                                             ; preds = %3843
  %3846 = icmp eq i64 %3840, 1
  %3847 = add i64 %3840, 1
  %3848 = select i1 %3846, i64 %3840, i64 %3847
  %3849 = getelementptr inbounds i8, ptr %3838, i64 %3840
  %3850 = load i8, ptr %3849, align 1, !invariant.load !1
  br label %3839

3851:                                             ; preds = %3844
  %3852 = phi i8 [ %3841, %3844 ]
  %3853 = zext i8 %3827 to i16
  %3854 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3853)
  %3855 = trunc i32 %3854 to i16
  %3856 = bitcast i16 %3855 to half
  %3857 = zext i8 %3852 to i16
  %3858 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3857)
  %3859 = trunc i32 %3858 to i16
  %3860 = bitcast i16 %3859 to half
  %3861 = fadd contract half %3856, %3860
  %3862 = fpext half %3861 to float
  %3863 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3862)
  %3864 = trunc i16 %3863 to i8
  br label %3825

3865:                                             ; preds = %3830
  %3866 = phi i8 [ %3827, %3830 ]
  %3867 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3803, 0
  %3868 = trunc i64 %3800 to i32
  %3869 = mul i32 %3868, 512
  %3870 = trunc i64 %3798 to i32
  %3871 = add i32 %3869, %3870
  %3872 = sext i32 %3871 to i64
  %3873 = getelementptr inbounds i8, ptr %3867, i64 %3872
  store i8 %3866, ptr %3873, align 1
  %3874 = load { i64, i64 }, ptr %6, align 8
  %3875 = add i64 %3798, 1
  %3876 = extractvalue { i64, i64 } %3874, 1
  %3877 = icmp sge i64 %3875, %3876
  %3878 = select i1 %3877, i64 0, i64 %3875
  %3879 = add i64 %3800, 1
  %3880 = select i1 %3877, i64 %3879, i64 %3800
  %3881 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3882 = load i64, ptr %4, align 8
  %3883 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3884 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3881, 0
  %3885 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3881, 1, 1, 0
  %3886 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3881, 1, 1, 1
  %3887 = mul i64 %3880, %3886
  %3888 = add i64 %3887, %3878
  %3889 = getelementptr inbounds i8, ptr %3884, i64 %3888
  br label %3890

3890:                                             ; preds = %3896, %3865
  %3891 = phi i64 [ 0, %3865 ], [ %3899, %3896 ]
  %3892 = phi i8 [ 0, %3865 ], [ %3901, %3896 ]
  %3893 = icmp slt i64 %3891, 1
  br i1 %3893, label %3894, label %3895

3894:                                             ; preds = %3890
  br label %3896

3895:                                             ; preds = %3890
  br label %3902

3896:                                             ; preds = %3894
  %3897 = icmp eq i64 %3891, 1
  %3898 = add i64 %3891, 1
  %3899 = select i1 %3897, i64 %3891, i64 %3898
  %3900 = getelementptr inbounds i8, ptr %3889, i64 %3891
  %3901 = load i8, ptr %3900, align 1, !invariant.load !1
  br label %3890

3902:                                             ; preds = %3895
  %3903 = phi i8 [ %3892, %3895 ]
  %3904 = call i64 @llvm.smax.i64(i64 %3882, i64 1)
  br label %3905

3905:                                             ; preds = %3931, %3902
  %3906 = phi i64 [ 1, %3902 ], [ %3914, %3931 ]
  %3907 = phi i8 [ %3903, %3902 ], [ %3944, %3931 ]
  %3908 = icmp slt i64 %3906, %3904
  br i1 %3908, label %3909, label %3910

3909:                                             ; preds = %3905
  br label %3911

3910:                                             ; preds = %3905
  br label %3945

3911:                                             ; preds = %3909
  %3912 = icmp eq i64 %3906, %3904
  %3913 = add i64 %3906, 1
  %3914 = select i1 %3912, i64 %3906, i64 %3913
  %3915 = mul i64 %3906, %3885
  %3916 = add i64 %3915, %3887
  %3917 = add i64 %3916, %3878
  %3918 = getelementptr inbounds i8, ptr %3884, i64 %3917
  br label %3919

3919:                                             ; preds = %3925, %3911
  %3920 = phi i64 [ 0, %3911 ], [ %3928, %3925 ]
  %3921 = phi i8 [ 0, %3911 ], [ %3930, %3925 ]
  %3922 = icmp slt i64 %3920, 1
  br i1 %3922, label %3923, label %3924

3923:                                             ; preds = %3919
  br label %3925

3924:                                             ; preds = %3919
  br label %3931

3925:                                             ; preds = %3923
  %3926 = icmp eq i64 %3920, 1
  %3927 = add i64 %3920, 1
  %3928 = select i1 %3926, i64 %3920, i64 %3927
  %3929 = getelementptr inbounds i8, ptr %3918, i64 %3920
  %3930 = load i8, ptr %3929, align 1, !invariant.load !1
  br label %3919

3931:                                             ; preds = %3924
  %3932 = phi i8 [ %3921, %3924 ]
  %3933 = zext i8 %3907 to i16
  %3934 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3933)
  %3935 = trunc i32 %3934 to i16
  %3936 = bitcast i16 %3935 to half
  %3937 = zext i8 %3932 to i16
  %3938 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %3937)
  %3939 = trunc i32 %3938 to i16
  %3940 = bitcast i16 %3939 to half
  %3941 = fadd contract half %3936, %3940
  %3942 = fpext half %3941 to float
  %3943 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %3942)
  %3944 = trunc i16 %3943 to i8
  br label %3905

3945:                                             ; preds = %3910
  %3946 = phi i8 [ %3907, %3910 ]
  %3947 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3883, 0
  %3948 = trunc i64 %3880 to i32
  %3949 = mul i32 %3948, 512
  %3950 = trunc i64 %3878 to i32
  %3951 = add i32 %3949, %3950
  %3952 = sext i32 %3951 to i64
  %3953 = getelementptr inbounds i8, ptr %3947, i64 %3952
  store i8 %3946, ptr %3953, align 1
  %3954 = load { i64, i64 }, ptr %6, align 8
  %3955 = add i64 %3878, 1
  %3956 = extractvalue { i64, i64 } %3954, 1
  %3957 = icmp sge i64 %3955, %3956
  %3958 = select i1 %3957, i64 0, i64 %3955
  %3959 = add i64 %3880, 1
  %3960 = select i1 %3957, i64 %3959, i64 %3880
  %3961 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %3962 = load i64, ptr %4, align 8
  %3963 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %3964 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3961, 0
  %3965 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3961, 1, 1, 0
  %3966 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %3961, 1, 1, 1
  %3967 = mul i64 %3960, %3966
  %3968 = add i64 %3967, %3958
  %3969 = getelementptr inbounds i8, ptr %3964, i64 %3968
  br label %3970

3970:                                             ; preds = %3976, %3945
  %3971 = phi i64 [ 0, %3945 ], [ %3979, %3976 ]
  %3972 = phi i8 [ 0, %3945 ], [ %3981, %3976 ]
  %3973 = icmp slt i64 %3971, 1
  br i1 %3973, label %3974, label %3975

3974:                                             ; preds = %3970
  br label %3976

3975:                                             ; preds = %3970
  br label %3982

3976:                                             ; preds = %3974
  %3977 = icmp eq i64 %3971, 1
  %3978 = add i64 %3971, 1
  %3979 = select i1 %3977, i64 %3971, i64 %3978
  %3980 = getelementptr inbounds i8, ptr %3969, i64 %3971
  %3981 = load i8, ptr %3980, align 1, !invariant.load !1
  br label %3970

3982:                                             ; preds = %3975
  %3983 = phi i8 [ %3972, %3975 ]
  %3984 = call i64 @llvm.smax.i64(i64 %3962, i64 1)
  br label %3985

3985:                                             ; preds = %4011, %3982
  %3986 = phi i64 [ 1, %3982 ], [ %3994, %4011 ]
  %3987 = phi i8 [ %3983, %3982 ], [ %4024, %4011 ]
  %3988 = icmp slt i64 %3986, %3984
  br i1 %3988, label %3989, label %3990

3989:                                             ; preds = %3985
  br label %3991

3990:                                             ; preds = %3985
  br label %4025

3991:                                             ; preds = %3989
  %3992 = icmp eq i64 %3986, %3984
  %3993 = add i64 %3986, 1
  %3994 = select i1 %3992, i64 %3986, i64 %3993
  %3995 = mul i64 %3986, %3965
  %3996 = add i64 %3995, %3967
  %3997 = add i64 %3996, %3958
  %3998 = getelementptr inbounds i8, ptr %3964, i64 %3997
  br label %3999

3999:                                             ; preds = %4005, %3991
  %4000 = phi i64 [ 0, %3991 ], [ %4008, %4005 ]
  %4001 = phi i8 [ 0, %3991 ], [ %4010, %4005 ]
  %4002 = icmp slt i64 %4000, 1
  br i1 %4002, label %4003, label %4004

4003:                                             ; preds = %3999
  br label %4005

4004:                                             ; preds = %3999
  br label %4011

4005:                                             ; preds = %4003
  %4006 = icmp eq i64 %4000, 1
  %4007 = add i64 %4000, 1
  %4008 = select i1 %4006, i64 %4000, i64 %4007
  %4009 = getelementptr inbounds i8, ptr %3998, i64 %4000
  %4010 = load i8, ptr %4009, align 1, !invariant.load !1
  br label %3999

4011:                                             ; preds = %4004
  %4012 = phi i8 [ %4001, %4004 ]
  %4013 = zext i8 %3987 to i16
  %4014 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4013)
  %4015 = trunc i32 %4014 to i16
  %4016 = bitcast i16 %4015 to half
  %4017 = zext i8 %4012 to i16
  %4018 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4017)
  %4019 = trunc i32 %4018 to i16
  %4020 = bitcast i16 %4019 to half
  %4021 = fadd contract half %4016, %4020
  %4022 = fpext half %4021 to float
  %4023 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4022)
  %4024 = trunc i16 %4023 to i8
  br label %3985

4025:                                             ; preds = %3990
  %4026 = phi i8 [ %3987, %3990 ]
  %4027 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %3963, 0
  %4028 = trunc i64 %3960 to i32
  %4029 = mul i32 %4028, 512
  %4030 = trunc i64 %3958 to i32
  %4031 = add i32 %4029, %4030
  %4032 = sext i32 %4031 to i64
  %4033 = getelementptr inbounds i8, ptr %4027, i64 %4032
  store i8 %4026, ptr %4033, align 1
  %4034 = load { i64, i64 }, ptr %6, align 8
  %4035 = add i64 %3958, 1
  %4036 = extractvalue { i64, i64 } %4034, 1
  %4037 = icmp sge i64 %4035, %4036
  %4038 = select i1 %4037, i64 0, i64 %4035
  %4039 = add i64 %3960, 1
  %4040 = select i1 %4037, i64 %4039, i64 %3960
  %4041 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4042 = load i64, ptr %4, align 8
  %4043 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4044 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4041, 0
  %4045 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4041, 1, 1, 0
  %4046 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4041, 1, 1, 1
  %4047 = mul i64 %4040, %4046
  %4048 = add i64 %4047, %4038
  %4049 = getelementptr inbounds i8, ptr %4044, i64 %4048
  br label %4050

4050:                                             ; preds = %4056, %4025
  %4051 = phi i64 [ 0, %4025 ], [ %4059, %4056 ]
  %4052 = phi i8 [ 0, %4025 ], [ %4061, %4056 ]
  %4053 = icmp slt i64 %4051, 1
  br i1 %4053, label %4054, label %4055

4054:                                             ; preds = %4050
  br label %4056

4055:                                             ; preds = %4050
  br label %4062

4056:                                             ; preds = %4054
  %4057 = icmp eq i64 %4051, 1
  %4058 = add i64 %4051, 1
  %4059 = select i1 %4057, i64 %4051, i64 %4058
  %4060 = getelementptr inbounds i8, ptr %4049, i64 %4051
  %4061 = load i8, ptr %4060, align 1, !invariant.load !1
  br label %4050

4062:                                             ; preds = %4055
  %4063 = phi i8 [ %4052, %4055 ]
  %4064 = call i64 @llvm.smax.i64(i64 %4042, i64 1)
  br label %4065

4065:                                             ; preds = %4091, %4062
  %4066 = phi i64 [ 1, %4062 ], [ %4074, %4091 ]
  %4067 = phi i8 [ %4063, %4062 ], [ %4104, %4091 ]
  %4068 = icmp slt i64 %4066, %4064
  br i1 %4068, label %4069, label %4070

4069:                                             ; preds = %4065
  br label %4071

4070:                                             ; preds = %4065
  br label %4105

4071:                                             ; preds = %4069
  %4072 = icmp eq i64 %4066, %4064
  %4073 = add i64 %4066, 1
  %4074 = select i1 %4072, i64 %4066, i64 %4073
  %4075 = mul i64 %4066, %4045
  %4076 = add i64 %4075, %4047
  %4077 = add i64 %4076, %4038
  %4078 = getelementptr inbounds i8, ptr %4044, i64 %4077
  br label %4079

4079:                                             ; preds = %4085, %4071
  %4080 = phi i64 [ 0, %4071 ], [ %4088, %4085 ]
  %4081 = phi i8 [ 0, %4071 ], [ %4090, %4085 ]
  %4082 = icmp slt i64 %4080, 1
  br i1 %4082, label %4083, label %4084

4083:                                             ; preds = %4079
  br label %4085

4084:                                             ; preds = %4079
  br label %4091

4085:                                             ; preds = %4083
  %4086 = icmp eq i64 %4080, 1
  %4087 = add i64 %4080, 1
  %4088 = select i1 %4086, i64 %4080, i64 %4087
  %4089 = getelementptr inbounds i8, ptr %4078, i64 %4080
  %4090 = load i8, ptr %4089, align 1, !invariant.load !1
  br label %4079

4091:                                             ; preds = %4084
  %4092 = phi i8 [ %4081, %4084 ]
  %4093 = zext i8 %4067 to i16
  %4094 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4093)
  %4095 = trunc i32 %4094 to i16
  %4096 = bitcast i16 %4095 to half
  %4097 = zext i8 %4092 to i16
  %4098 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4097)
  %4099 = trunc i32 %4098 to i16
  %4100 = bitcast i16 %4099 to half
  %4101 = fadd contract half %4096, %4100
  %4102 = fpext half %4101 to float
  %4103 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4102)
  %4104 = trunc i16 %4103 to i8
  br label %4065

4105:                                             ; preds = %4070
  %4106 = phi i8 [ %4067, %4070 ]
  %4107 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4043, 0
  %4108 = trunc i64 %4040 to i32
  %4109 = mul i32 %4108, 512
  %4110 = trunc i64 %4038 to i32
  %4111 = add i32 %4109, %4110
  %4112 = sext i32 %4111 to i64
  %4113 = getelementptr inbounds i8, ptr %4107, i64 %4112
  store i8 %4106, ptr %4113, align 1
  %4114 = load { i64, i64 }, ptr %6, align 8
  %4115 = add i64 %4038, 1
  %4116 = extractvalue { i64, i64 } %4114, 1
  %4117 = icmp sge i64 %4115, %4116
  %4118 = select i1 %4117, i64 0, i64 %4115
  %4119 = add i64 %4040, 1
  %4120 = select i1 %4117, i64 %4119, i64 %4040
  %4121 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4122 = load i64, ptr %4, align 8
  %4123 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4124 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4121, 0
  %4125 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4121, 1, 1, 0
  %4126 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4121, 1, 1, 1
  %4127 = mul i64 %4120, %4126
  %4128 = add i64 %4127, %4118
  %4129 = getelementptr inbounds i8, ptr %4124, i64 %4128
  br label %4130

4130:                                             ; preds = %4136, %4105
  %4131 = phi i64 [ 0, %4105 ], [ %4139, %4136 ]
  %4132 = phi i8 [ 0, %4105 ], [ %4141, %4136 ]
  %4133 = icmp slt i64 %4131, 1
  br i1 %4133, label %4134, label %4135

4134:                                             ; preds = %4130
  br label %4136

4135:                                             ; preds = %4130
  br label %4142

4136:                                             ; preds = %4134
  %4137 = icmp eq i64 %4131, 1
  %4138 = add i64 %4131, 1
  %4139 = select i1 %4137, i64 %4131, i64 %4138
  %4140 = getelementptr inbounds i8, ptr %4129, i64 %4131
  %4141 = load i8, ptr %4140, align 1, !invariant.load !1
  br label %4130

4142:                                             ; preds = %4135
  %4143 = phi i8 [ %4132, %4135 ]
  %4144 = call i64 @llvm.smax.i64(i64 %4122, i64 1)
  br label %4145

4145:                                             ; preds = %4171, %4142
  %4146 = phi i64 [ 1, %4142 ], [ %4154, %4171 ]
  %4147 = phi i8 [ %4143, %4142 ], [ %4184, %4171 ]
  %4148 = icmp slt i64 %4146, %4144
  br i1 %4148, label %4149, label %4150

4149:                                             ; preds = %4145
  br label %4151

4150:                                             ; preds = %4145
  br label %4185

4151:                                             ; preds = %4149
  %4152 = icmp eq i64 %4146, %4144
  %4153 = add i64 %4146, 1
  %4154 = select i1 %4152, i64 %4146, i64 %4153
  %4155 = mul i64 %4146, %4125
  %4156 = add i64 %4155, %4127
  %4157 = add i64 %4156, %4118
  %4158 = getelementptr inbounds i8, ptr %4124, i64 %4157
  br label %4159

4159:                                             ; preds = %4165, %4151
  %4160 = phi i64 [ 0, %4151 ], [ %4168, %4165 ]
  %4161 = phi i8 [ 0, %4151 ], [ %4170, %4165 ]
  %4162 = icmp slt i64 %4160, 1
  br i1 %4162, label %4163, label %4164

4163:                                             ; preds = %4159
  br label %4165

4164:                                             ; preds = %4159
  br label %4171

4165:                                             ; preds = %4163
  %4166 = icmp eq i64 %4160, 1
  %4167 = add i64 %4160, 1
  %4168 = select i1 %4166, i64 %4160, i64 %4167
  %4169 = getelementptr inbounds i8, ptr %4158, i64 %4160
  %4170 = load i8, ptr %4169, align 1, !invariant.load !1
  br label %4159

4171:                                             ; preds = %4164
  %4172 = phi i8 [ %4161, %4164 ]
  %4173 = zext i8 %4147 to i16
  %4174 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4173)
  %4175 = trunc i32 %4174 to i16
  %4176 = bitcast i16 %4175 to half
  %4177 = zext i8 %4172 to i16
  %4178 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4177)
  %4179 = trunc i32 %4178 to i16
  %4180 = bitcast i16 %4179 to half
  %4181 = fadd contract half %4176, %4180
  %4182 = fpext half %4181 to float
  %4183 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4182)
  %4184 = trunc i16 %4183 to i8
  br label %4145

4185:                                             ; preds = %4150
  %4186 = phi i8 [ %4147, %4150 ]
  %4187 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4123, 0
  %4188 = trunc i64 %4120 to i32
  %4189 = mul i32 %4188, 512
  %4190 = trunc i64 %4118 to i32
  %4191 = add i32 %4189, %4190
  %4192 = sext i32 %4191 to i64
  %4193 = getelementptr inbounds i8, ptr %4187, i64 %4192
  store i8 %4186, ptr %4193, align 1
  br label %4312

4194:                                             ; preds = %2901
  %4195 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4196 = load i64, ptr %4, align 8
  %4197 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4198 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4195, 0
  %4199 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4195, 1, 1, 0
  %4200 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4195, 1, 1, 1
  %4201 = mul i64 %2918, %4200
  %4202 = add i64 %4201, %2915
  %4203 = getelementptr inbounds i8, ptr %4198, i64 %4202
  %4204 = load <16 x i8>, ptr %4203, align 16, !invariant.load !1
  %4205 = call i64 @llvm.smax.i64(i64 %4196, i64 1)
  br label %4206

4206:                                             ; preds = %4212, %4194
  %4207 = phi i64 [ 1, %4194 ], [ %4215, %4212 ]
  %4208 = phi <16 x i8> [ %4204, %4194 ], [ %4307, %4212 ]
  %4209 = icmp slt i64 %4207, %4205
  br i1 %4209, label %4210, label %4211

4210:                                             ; preds = %4206
  br label %4212

4211:                                             ; preds = %4206
  br label %4308

4212:                                             ; preds = %4210
  %4213 = icmp eq i64 %4207, %4205
  %4214 = add i64 %4207, 1
  %4215 = select i1 %4213, i64 %4207, i64 %4214
  %4216 = mul i64 %4207, %4199
  %4217 = add i64 %4216, %4201
  %4218 = add i64 %4217, %2915
  %4219 = getelementptr inbounds i8, ptr %4198, i64 %4218
  %4220 = load <16 x i8>, ptr %4219, align 16, !invariant.load !1
  %4221 = bitcast <16 x i8> %4208 to <8 x i16>
  %4222 = extractelement <8 x i16> %4221, i32 0
  %4223 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4222)
  %4224 = insertelement <8 x i32> undef, i32 %4223, i32 0
  %4225 = extractelement <8 x i16> %4221, i32 1
  %4226 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4225)
  %4227 = insertelement <8 x i32> %4224, i32 %4226, i32 1
  %4228 = extractelement <8 x i16> %4221, i32 2
  %4229 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4228)
  %4230 = insertelement <8 x i32> %4227, i32 %4229, i32 2
  %4231 = extractelement <8 x i16> %4221, i32 3
  %4232 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4231)
  %4233 = insertelement <8 x i32> %4230, i32 %4232, i32 3
  %4234 = extractelement <8 x i16> %4221, i32 4
  %4235 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4234)
  %4236 = insertelement <8 x i32> %4233, i32 %4235, i32 4
  %4237 = extractelement <8 x i16> %4221, i32 5
  %4238 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4237)
  %4239 = insertelement <8 x i32> %4236, i32 %4238, i32 5
  %4240 = extractelement <8 x i16> %4221, i32 6
  %4241 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4240)
  %4242 = insertelement <8 x i32> %4239, i32 %4241, i32 6
  %4243 = extractelement <8 x i16> %4221, i32 7
  %4244 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4243)
  %4245 = insertelement <8 x i32> %4242, i32 %4244, i32 7
  %4246 = bitcast <8 x i32> %4245 to <16 x half>
  %4247 = bitcast <16 x i8> %4220 to <8 x i16>
  %4248 = extractelement <8 x i16> %4247, i32 0
  %4249 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4248)
  %4250 = insertelement <8 x i32> undef, i32 %4249, i32 0
  %4251 = extractelement <8 x i16> %4247, i32 1
  %4252 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4251)
  %4253 = insertelement <8 x i32> %4250, i32 %4252, i32 1
  %4254 = extractelement <8 x i16> %4247, i32 2
  %4255 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4254)
  %4256 = insertelement <8 x i32> %4253, i32 %4255, i32 2
  %4257 = extractelement <8 x i16> %4247, i32 3
  %4258 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4257)
  %4259 = insertelement <8 x i32> %4256, i32 %4258, i32 3
  %4260 = extractelement <8 x i16> %4247, i32 4
  %4261 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4260)
  %4262 = insertelement <8 x i32> %4259, i32 %4261, i32 4
  %4263 = extractelement <8 x i16> %4247, i32 5
  %4264 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4263)
  %4265 = insertelement <8 x i32> %4262, i32 %4264, i32 5
  %4266 = extractelement <8 x i16> %4247, i32 6
  %4267 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4266)
  %4268 = insertelement <8 x i32> %4265, i32 %4267, i32 6
  %4269 = extractelement <8 x i16> %4247, i32 7
  %4270 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4269)
  %4271 = insertelement <8 x i32> %4268, i32 %4270, i32 7
  %4272 = bitcast <8 x i32> %4271 to <16 x half>
  %4273 = fadd contract <16 x half> %4246, %4272
  %4274 = fpext <16 x half> %4273 to <16 x float>
  %4275 = extractelement <16 x float> %4274, i32 1
  %4276 = extractelement <16 x float> %4274, i32 0
  %4277 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4275, float %4276)
  %4278 = insertelement <8 x i16> undef, i16 %4277, i32 0
  %4279 = extractelement <16 x float> %4274, i32 3
  %4280 = extractelement <16 x float> %4274, i32 2
  %4281 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4279, float %4280)
  %4282 = insertelement <8 x i16> %4278, i16 %4281, i32 1
  %4283 = extractelement <16 x float> %4274, i32 5
  %4284 = extractelement <16 x float> %4274, i32 4
  %4285 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4283, float %4284)
  %4286 = insertelement <8 x i16> %4282, i16 %4285, i32 2
  %4287 = extractelement <16 x float> %4274, i32 7
  %4288 = extractelement <16 x float> %4274, i32 6
  %4289 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4287, float %4288)
  %4290 = insertelement <8 x i16> %4286, i16 %4289, i32 3
  %4291 = extractelement <16 x float> %4274, i32 9
  %4292 = extractelement <16 x float> %4274, i32 8
  %4293 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4291, float %4292)
  %4294 = insertelement <8 x i16> %4290, i16 %4293, i32 4
  %4295 = extractelement <16 x float> %4274, i32 11
  %4296 = extractelement <16 x float> %4274, i32 10
  %4297 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4295, float %4296)
  %4298 = insertelement <8 x i16> %4294, i16 %4297, i32 5
  %4299 = extractelement <16 x float> %4274, i32 13
  %4300 = extractelement <16 x float> %4274, i32 12
  %4301 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4299, float %4300)
  %4302 = insertelement <8 x i16> %4298, i16 %4301, i32 6
  %4303 = extractelement <16 x float> %4274, i32 15
  %4304 = extractelement <16 x float> %4274, i32 14
  %4305 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %4303, float %4304)
  %4306 = insertelement <8 x i16> %4302, i16 %4305, i32 7
  %4307 = bitcast <8 x i16> %4306 to <16 x i8>
  br label %4206

4308:                                             ; preds = %4211
  %4309 = phi <16 x i8> [ %4208, %4211 ]
  %4310 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4197, 0
  %4311 = getelementptr inbounds i8, ptr %4310, i64 %2922
  store <16 x i8> %4309, ptr %4311, align 16
  br label %4312

4312:                                             ; preds = %4308, %4185
  br label %4314

4313:                                             ; preds = %2895
  br label %4314

4314:                                             ; preds = %4313, %4312
  %4315 = add i64 %53, %18
  %4316 = mul i64 %4315, 16
  %4317 = trunc i64 %4316 to i32
  %4318 = load i64, ptr %20, align 8
  %4319 = icmp slt i64 %4315, %4318
  br i1 %4319, label %4320, label %5732

4320:                                             ; preds = %4314
  %4321 = load { i64, i64 }, ptr %6, align 8
  %4322 = extractvalue { i64, i64 } %4321, 1
  %4323 = trunc i64 %4322 to i32
  %4324 = icmp eq i32 %4323, 0
  %4325 = select i1 %4324, i32 1, i32 %4323
  %4326 = icmp eq i32 %4325, 0
  %4327 = select i1 %4326, i32 1, i32 %4325
  %4328 = udiv i32 %4317, %4327
  %4329 = select i1 %4326, i32 0, i32 %4328
  %4330 = urem i32 %4317, %4327
  %4331 = select i1 %4326, i32 0, i32 %4330
  %4332 = select i1 %4324, i32 0, i32 %4329
  %4333 = select i1 %4324, i32 0, i32 %4331
  %4334 = zext i32 %4333 to i64
  %4335 = trunc i64 %4334 to i32
  %4336 = add i64 %4334, 1
  %4337 = zext i32 %4332 to i64
  %4338 = trunc i64 %4337 to i32
  %4339 = mul i32 %4338, 512
  %4340 = add i32 %4339, %4335
  %4341 = sext i32 %4340 to i64
  %4342 = add i64 %4337, 1
  %4343 = add i64 %4334, 16
  %4344 = load i64, ptr %8, align 8
  %4345 = icmp sgt i64 %4343, %4344
  br i1 %4345, label %4346, label %5613

4346:                                             ; preds = %4320
  %4347 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4348 = load i64, ptr %4, align 8
  %4349 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4350 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4347, 0
  %4351 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4347, 1, 1, 0
  %4352 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4347, 1, 1, 1
  %4353 = mul i64 %4337, %4352
  %4354 = add i64 %4353, %4334
  %4355 = getelementptr inbounds i8, ptr %4350, i64 %4354
  br label %4356

4356:                                             ; preds = %4362, %4346
  %4357 = phi i64 [ 0, %4346 ], [ %4365, %4362 ]
  %4358 = phi i8 [ 0, %4346 ], [ %4367, %4362 ]
  %4359 = icmp slt i64 %4357, 1
  br i1 %4359, label %4360, label %4361

4360:                                             ; preds = %4356
  br label %4362

4361:                                             ; preds = %4356
  br label %4368

4362:                                             ; preds = %4360
  %4363 = icmp eq i64 %4357, 1
  %4364 = add i64 %4357, 1
  %4365 = select i1 %4363, i64 %4357, i64 %4364
  %4366 = getelementptr inbounds i8, ptr %4355, i64 %4357
  %4367 = load i8, ptr %4366, align 1, !invariant.load !1
  br label %4356

4368:                                             ; preds = %4361
  %4369 = phi i8 [ %4358, %4361 ]
  %4370 = call i64 @llvm.smax.i64(i64 %4348, i64 1)
  br label %4371

4371:                                             ; preds = %4397, %4368
  %4372 = phi i64 [ 1, %4368 ], [ %4380, %4397 ]
  %4373 = phi i8 [ %4369, %4368 ], [ %4410, %4397 ]
  %4374 = icmp slt i64 %4372, %4370
  br i1 %4374, label %4375, label %4376

4375:                                             ; preds = %4371
  br label %4377

4376:                                             ; preds = %4371
  br label %4411

4377:                                             ; preds = %4375
  %4378 = icmp eq i64 %4372, %4370
  %4379 = add i64 %4372, 1
  %4380 = select i1 %4378, i64 %4372, i64 %4379
  %4381 = mul i64 %4372, %4351
  %4382 = add i64 %4381, %4353
  %4383 = add i64 %4382, %4334
  %4384 = getelementptr inbounds i8, ptr %4350, i64 %4383
  br label %4385

4385:                                             ; preds = %4391, %4377
  %4386 = phi i64 [ 0, %4377 ], [ %4394, %4391 ]
  %4387 = phi i8 [ 0, %4377 ], [ %4396, %4391 ]
  %4388 = icmp slt i64 %4386, 1
  br i1 %4388, label %4389, label %4390

4389:                                             ; preds = %4385
  br label %4391

4390:                                             ; preds = %4385
  br label %4397

4391:                                             ; preds = %4389
  %4392 = icmp eq i64 %4386, 1
  %4393 = add i64 %4386, 1
  %4394 = select i1 %4392, i64 %4386, i64 %4393
  %4395 = getelementptr inbounds i8, ptr %4384, i64 %4386
  %4396 = load i8, ptr %4395, align 1, !invariant.load !1
  br label %4385

4397:                                             ; preds = %4390
  %4398 = phi i8 [ %4387, %4390 ]
  %4399 = zext i8 %4373 to i16
  %4400 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4399)
  %4401 = trunc i32 %4400 to i16
  %4402 = bitcast i16 %4401 to half
  %4403 = zext i8 %4398 to i16
  %4404 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4403)
  %4405 = trunc i32 %4404 to i16
  %4406 = bitcast i16 %4405 to half
  %4407 = fadd contract half %4402, %4406
  %4408 = fpext half %4407 to float
  %4409 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4408)
  %4410 = trunc i16 %4409 to i8
  br label %4371

4411:                                             ; preds = %4376
  %4412 = phi i8 [ %4373, %4376 ]
  %4413 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4349, 0
  %4414 = getelementptr inbounds i8, ptr %4413, i64 %4341
  store i8 %4412, ptr %4414, align 1
  %4415 = load { i64, i64 }, ptr %6, align 8
  %4416 = extractvalue { i64, i64 } %4415, 1
  %4417 = icmp sge i64 %4336, %4416
  %4418 = select i1 %4417, i64 0, i64 %4336
  %4419 = select i1 %4417, i64 %4342, i64 %4337
  %4420 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4421 = load i64, ptr %4, align 8
  %4422 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4423 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4420, 0
  %4424 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4420, 1, 1, 0
  %4425 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4420, 1, 1, 1
  %4426 = mul i64 %4419, %4425
  %4427 = add i64 %4426, %4418
  %4428 = getelementptr inbounds i8, ptr %4423, i64 %4427
  br label %4429

4429:                                             ; preds = %4435, %4411
  %4430 = phi i64 [ 0, %4411 ], [ %4438, %4435 ]
  %4431 = phi i8 [ 0, %4411 ], [ %4440, %4435 ]
  %4432 = icmp slt i64 %4430, 1
  br i1 %4432, label %4433, label %4434

4433:                                             ; preds = %4429
  br label %4435

4434:                                             ; preds = %4429
  br label %4441

4435:                                             ; preds = %4433
  %4436 = icmp eq i64 %4430, 1
  %4437 = add i64 %4430, 1
  %4438 = select i1 %4436, i64 %4430, i64 %4437
  %4439 = getelementptr inbounds i8, ptr %4428, i64 %4430
  %4440 = load i8, ptr %4439, align 1, !invariant.load !1
  br label %4429

4441:                                             ; preds = %4434
  %4442 = phi i8 [ %4431, %4434 ]
  %4443 = call i64 @llvm.smax.i64(i64 %4421, i64 1)
  br label %4444

4444:                                             ; preds = %4470, %4441
  %4445 = phi i64 [ 1, %4441 ], [ %4453, %4470 ]
  %4446 = phi i8 [ %4442, %4441 ], [ %4483, %4470 ]
  %4447 = icmp slt i64 %4445, %4443
  br i1 %4447, label %4448, label %4449

4448:                                             ; preds = %4444
  br label %4450

4449:                                             ; preds = %4444
  br label %4484

4450:                                             ; preds = %4448
  %4451 = icmp eq i64 %4445, %4443
  %4452 = add i64 %4445, 1
  %4453 = select i1 %4451, i64 %4445, i64 %4452
  %4454 = mul i64 %4445, %4424
  %4455 = add i64 %4454, %4426
  %4456 = add i64 %4455, %4418
  %4457 = getelementptr inbounds i8, ptr %4423, i64 %4456
  br label %4458

4458:                                             ; preds = %4464, %4450
  %4459 = phi i64 [ 0, %4450 ], [ %4467, %4464 ]
  %4460 = phi i8 [ 0, %4450 ], [ %4469, %4464 ]
  %4461 = icmp slt i64 %4459, 1
  br i1 %4461, label %4462, label %4463

4462:                                             ; preds = %4458
  br label %4464

4463:                                             ; preds = %4458
  br label %4470

4464:                                             ; preds = %4462
  %4465 = icmp eq i64 %4459, 1
  %4466 = add i64 %4459, 1
  %4467 = select i1 %4465, i64 %4459, i64 %4466
  %4468 = getelementptr inbounds i8, ptr %4457, i64 %4459
  %4469 = load i8, ptr %4468, align 1, !invariant.load !1
  br label %4458

4470:                                             ; preds = %4463
  %4471 = phi i8 [ %4460, %4463 ]
  %4472 = zext i8 %4446 to i16
  %4473 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4472)
  %4474 = trunc i32 %4473 to i16
  %4475 = bitcast i16 %4474 to half
  %4476 = zext i8 %4471 to i16
  %4477 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4476)
  %4478 = trunc i32 %4477 to i16
  %4479 = bitcast i16 %4478 to half
  %4480 = fadd contract half %4475, %4479
  %4481 = fpext half %4480 to float
  %4482 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4481)
  %4483 = trunc i16 %4482 to i8
  br label %4444

4484:                                             ; preds = %4449
  %4485 = phi i8 [ %4446, %4449 ]
  %4486 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4422, 0
  %4487 = trunc i64 %4419 to i32
  %4488 = mul i32 %4487, 512
  %4489 = trunc i64 %4418 to i32
  %4490 = add i32 %4488, %4489
  %4491 = sext i32 %4490 to i64
  %4492 = getelementptr inbounds i8, ptr %4486, i64 %4491
  store i8 %4485, ptr %4492, align 1
  %4493 = load { i64, i64 }, ptr %6, align 8
  %4494 = add i64 %4418, 1
  %4495 = extractvalue { i64, i64 } %4493, 1
  %4496 = icmp sge i64 %4494, %4495
  %4497 = select i1 %4496, i64 0, i64 %4494
  %4498 = add i64 %4419, 1
  %4499 = select i1 %4496, i64 %4498, i64 %4419
  %4500 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4501 = load i64, ptr %4, align 8
  %4502 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4503 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4500, 0
  %4504 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4500, 1, 1, 0
  %4505 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4500, 1, 1, 1
  %4506 = mul i64 %4499, %4505
  %4507 = add i64 %4506, %4497
  %4508 = getelementptr inbounds i8, ptr %4503, i64 %4507
  br label %4509

4509:                                             ; preds = %4515, %4484
  %4510 = phi i64 [ 0, %4484 ], [ %4518, %4515 ]
  %4511 = phi i8 [ 0, %4484 ], [ %4520, %4515 ]
  %4512 = icmp slt i64 %4510, 1
  br i1 %4512, label %4513, label %4514

4513:                                             ; preds = %4509
  br label %4515

4514:                                             ; preds = %4509
  br label %4521

4515:                                             ; preds = %4513
  %4516 = icmp eq i64 %4510, 1
  %4517 = add i64 %4510, 1
  %4518 = select i1 %4516, i64 %4510, i64 %4517
  %4519 = getelementptr inbounds i8, ptr %4508, i64 %4510
  %4520 = load i8, ptr %4519, align 1, !invariant.load !1
  br label %4509

4521:                                             ; preds = %4514
  %4522 = phi i8 [ %4511, %4514 ]
  %4523 = call i64 @llvm.smax.i64(i64 %4501, i64 1)
  br label %4524

4524:                                             ; preds = %4550, %4521
  %4525 = phi i64 [ 1, %4521 ], [ %4533, %4550 ]
  %4526 = phi i8 [ %4522, %4521 ], [ %4563, %4550 ]
  %4527 = icmp slt i64 %4525, %4523
  br i1 %4527, label %4528, label %4529

4528:                                             ; preds = %4524
  br label %4530

4529:                                             ; preds = %4524
  br label %4564

4530:                                             ; preds = %4528
  %4531 = icmp eq i64 %4525, %4523
  %4532 = add i64 %4525, 1
  %4533 = select i1 %4531, i64 %4525, i64 %4532
  %4534 = mul i64 %4525, %4504
  %4535 = add i64 %4534, %4506
  %4536 = add i64 %4535, %4497
  %4537 = getelementptr inbounds i8, ptr %4503, i64 %4536
  br label %4538

4538:                                             ; preds = %4544, %4530
  %4539 = phi i64 [ 0, %4530 ], [ %4547, %4544 ]
  %4540 = phi i8 [ 0, %4530 ], [ %4549, %4544 ]
  %4541 = icmp slt i64 %4539, 1
  br i1 %4541, label %4542, label %4543

4542:                                             ; preds = %4538
  br label %4544

4543:                                             ; preds = %4538
  br label %4550

4544:                                             ; preds = %4542
  %4545 = icmp eq i64 %4539, 1
  %4546 = add i64 %4539, 1
  %4547 = select i1 %4545, i64 %4539, i64 %4546
  %4548 = getelementptr inbounds i8, ptr %4537, i64 %4539
  %4549 = load i8, ptr %4548, align 1, !invariant.load !1
  br label %4538

4550:                                             ; preds = %4543
  %4551 = phi i8 [ %4540, %4543 ]
  %4552 = zext i8 %4526 to i16
  %4553 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4552)
  %4554 = trunc i32 %4553 to i16
  %4555 = bitcast i16 %4554 to half
  %4556 = zext i8 %4551 to i16
  %4557 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4556)
  %4558 = trunc i32 %4557 to i16
  %4559 = bitcast i16 %4558 to half
  %4560 = fadd contract half %4555, %4559
  %4561 = fpext half %4560 to float
  %4562 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4561)
  %4563 = trunc i16 %4562 to i8
  br label %4524

4564:                                             ; preds = %4529
  %4565 = phi i8 [ %4526, %4529 ]
  %4566 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4502, 0
  %4567 = trunc i64 %4499 to i32
  %4568 = mul i32 %4567, 512
  %4569 = trunc i64 %4497 to i32
  %4570 = add i32 %4568, %4569
  %4571 = sext i32 %4570 to i64
  %4572 = getelementptr inbounds i8, ptr %4566, i64 %4571
  store i8 %4565, ptr %4572, align 1
  %4573 = load { i64, i64 }, ptr %6, align 8
  %4574 = add i64 %4497, 1
  %4575 = extractvalue { i64, i64 } %4573, 1
  %4576 = icmp sge i64 %4574, %4575
  %4577 = select i1 %4576, i64 0, i64 %4574
  %4578 = add i64 %4499, 1
  %4579 = select i1 %4576, i64 %4578, i64 %4499
  %4580 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4581 = load i64, ptr %4, align 8
  %4582 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4583 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4580, 0
  %4584 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4580, 1, 1, 0
  %4585 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4580, 1, 1, 1
  %4586 = mul i64 %4579, %4585
  %4587 = add i64 %4586, %4577
  %4588 = getelementptr inbounds i8, ptr %4583, i64 %4587
  br label %4589

4589:                                             ; preds = %4595, %4564
  %4590 = phi i64 [ 0, %4564 ], [ %4598, %4595 ]
  %4591 = phi i8 [ 0, %4564 ], [ %4600, %4595 ]
  %4592 = icmp slt i64 %4590, 1
  br i1 %4592, label %4593, label %4594

4593:                                             ; preds = %4589
  br label %4595

4594:                                             ; preds = %4589
  br label %4601

4595:                                             ; preds = %4593
  %4596 = icmp eq i64 %4590, 1
  %4597 = add i64 %4590, 1
  %4598 = select i1 %4596, i64 %4590, i64 %4597
  %4599 = getelementptr inbounds i8, ptr %4588, i64 %4590
  %4600 = load i8, ptr %4599, align 1, !invariant.load !1
  br label %4589

4601:                                             ; preds = %4594
  %4602 = phi i8 [ %4591, %4594 ]
  %4603 = call i64 @llvm.smax.i64(i64 %4581, i64 1)
  br label %4604

4604:                                             ; preds = %4630, %4601
  %4605 = phi i64 [ 1, %4601 ], [ %4613, %4630 ]
  %4606 = phi i8 [ %4602, %4601 ], [ %4643, %4630 ]
  %4607 = icmp slt i64 %4605, %4603
  br i1 %4607, label %4608, label %4609

4608:                                             ; preds = %4604
  br label %4610

4609:                                             ; preds = %4604
  br label %4644

4610:                                             ; preds = %4608
  %4611 = icmp eq i64 %4605, %4603
  %4612 = add i64 %4605, 1
  %4613 = select i1 %4611, i64 %4605, i64 %4612
  %4614 = mul i64 %4605, %4584
  %4615 = add i64 %4614, %4586
  %4616 = add i64 %4615, %4577
  %4617 = getelementptr inbounds i8, ptr %4583, i64 %4616
  br label %4618

4618:                                             ; preds = %4624, %4610
  %4619 = phi i64 [ 0, %4610 ], [ %4627, %4624 ]
  %4620 = phi i8 [ 0, %4610 ], [ %4629, %4624 ]
  %4621 = icmp slt i64 %4619, 1
  br i1 %4621, label %4622, label %4623

4622:                                             ; preds = %4618
  br label %4624

4623:                                             ; preds = %4618
  br label %4630

4624:                                             ; preds = %4622
  %4625 = icmp eq i64 %4619, 1
  %4626 = add i64 %4619, 1
  %4627 = select i1 %4625, i64 %4619, i64 %4626
  %4628 = getelementptr inbounds i8, ptr %4617, i64 %4619
  %4629 = load i8, ptr %4628, align 1, !invariant.load !1
  br label %4618

4630:                                             ; preds = %4623
  %4631 = phi i8 [ %4620, %4623 ]
  %4632 = zext i8 %4606 to i16
  %4633 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4632)
  %4634 = trunc i32 %4633 to i16
  %4635 = bitcast i16 %4634 to half
  %4636 = zext i8 %4631 to i16
  %4637 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4636)
  %4638 = trunc i32 %4637 to i16
  %4639 = bitcast i16 %4638 to half
  %4640 = fadd contract half %4635, %4639
  %4641 = fpext half %4640 to float
  %4642 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4641)
  %4643 = trunc i16 %4642 to i8
  br label %4604

4644:                                             ; preds = %4609
  %4645 = phi i8 [ %4606, %4609 ]
  %4646 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4582, 0
  %4647 = trunc i64 %4579 to i32
  %4648 = mul i32 %4647, 512
  %4649 = trunc i64 %4577 to i32
  %4650 = add i32 %4648, %4649
  %4651 = sext i32 %4650 to i64
  %4652 = getelementptr inbounds i8, ptr %4646, i64 %4651
  store i8 %4645, ptr %4652, align 1
  %4653 = load { i64, i64 }, ptr %6, align 8
  %4654 = add i64 %4577, 1
  %4655 = extractvalue { i64, i64 } %4653, 1
  %4656 = icmp sge i64 %4654, %4655
  %4657 = select i1 %4656, i64 0, i64 %4654
  %4658 = add i64 %4579, 1
  %4659 = select i1 %4656, i64 %4658, i64 %4579
  %4660 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4661 = load i64, ptr %4, align 8
  %4662 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4663 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4660, 0
  %4664 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4660, 1, 1, 0
  %4665 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4660, 1, 1, 1
  %4666 = mul i64 %4659, %4665
  %4667 = add i64 %4666, %4657
  %4668 = getelementptr inbounds i8, ptr %4663, i64 %4667
  br label %4669

4669:                                             ; preds = %4675, %4644
  %4670 = phi i64 [ 0, %4644 ], [ %4678, %4675 ]
  %4671 = phi i8 [ 0, %4644 ], [ %4680, %4675 ]
  %4672 = icmp slt i64 %4670, 1
  br i1 %4672, label %4673, label %4674

4673:                                             ; preds = %4669
  br label %4675

4674:                                             ; preds = %4669
  br label %4681

4675:                                             ; preds = %4673
  %4676 = icmp eq i64 %4670, 1
  %4677 = add i64 %4670, 1
  %4678 = select i1 %4676, i64 %4670, i64 %4677
  %4679 = getelementptr inbounds i8, ptr %4668, i64 %4670
  %4680 = load i8, ptr %4679, align 1, !invariant.load !1
  br label %4669

4681:                                             ; preds = %4674
  %4682 = phi i8 [ %4671, %4674 ]
  %4683 = call i64 @llvm.smax.i64(i64 %4661, i64 1)
  br label %4684

4684:                                             ; preds = %4710, %4681
  %4685 = phi i64 [ 1, %4681 ], [ %4693, %4710 ]
  %4686 = phi i8 [ %4682, %4681 ], [ %4723, %4710 ]
  %4687 = icmp slt i64 %4685, %4683
  br i1 %4687, label %4688, label %4689

4688:                                             ; preds = %4684
  br label %4690

4689:                                             ; preds = %4684
  br label %4724

4690:                                             ; preds = %4688
  %4691 = icmp eq i64 %4685, %4683
  %4692 = add i64 %4685, 1
  %4693 = select i1 %4691, i64 %4685, i64 %4692
  %4694 = mul i64 %4685, %4664
  %4695 = add i64 %4694, %4666
  %4696 = add i64 %4695, %4657
  %4697 = getelementptr inbounds i8, ptr %4663, i64 %4696
  br label %4698

4698:                                             ; preds = %4704, %4690
  %4699 = phi i64 [ 0, %4690 ], [ %4707, %4704 ]
  %4700 = phi i8 [ 0, %4690 ], [ %4709, %4704 ]
  %4701 = icmp slt i64 %4699, 1
  br i1 %4701, label %4702, label %4703

4702:                                             ; preds = %4698
  br label %4704

4703:                                             ; preds = %4698
  br label %4710

4704:                                             ; preds = %4702
  %4705 = icmp eq i64 %4699, 1
  %4706 = add i64 %4699, 1
  %4707 = select i1 %4705, i64 %4699, i64 %4706
  %4708 = getelementptr inbounds i8, ptr %4697, i64 %4699
  %4709 = load i8, ptr %4708, align 1, !invariant.load !1
  br label %4698

4710:                                             ; preds = %4703
  %4711 = phi i8 [ %4700, %4703 ]
  %4712 = zext i8 %4686 to i16
  %4713 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4712)
  %4714 = trunc i32 %4713 to i16
  %4715 = bitcast i16 %4714 to half
  %4716 = zext i8 %4711 to i16
  %4717 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4716)
  %4718 = trunc i32 %4717 to i16
  %4719 = bitcast i16 %4718 to half
  %4720 = fadd contract half %4715, %4719
  %4721 = fpext half %4720 to float
  %4722 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4721)
  %4723 = trunc i16 %4722 to i8
  br label %4684

4724:                                             ; preds = %4689
  %4725 = phi i8 [ %4686, %4689 ]
  %4726 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4662, 0
  %4727 = trunc i64 %4659 to i32
  %4728 = mul i32 %4727, 512
  %4729 = trunc i64 %4657 to i32
  %4730 = add i32 %4728, %4729
  %4731 = sext i32 %4730 to i64
  %4732 = getelementptr inbounds i8, ptr %4726, i64 %4731
  store i8 %4725, ptr %4732, align 1
  %4733 = load { i64, i64 }, ptr %6, align 8
  %4734 = add i64 %4657, 1
  %4735 = extractvalue { i64, i64 } %4733, 1
  %4736 = icmp sge i64 %4734, %4735
  %4737 = select i1 %4736, i64 0, i64 %4734
  %4738 = add i64 %4659, 1
  %4739 = select i1 %4736, i64 %4738, i64 %4659
  %4740 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4741 = load i64, ptr %4, align 8
  %4742 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4743 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4740, 0
  %4744 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4740, 1, 1, 0
  %4745 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4740, 1, 1, 1
  %4746 = mul i64 %4739, %4745
  %4747 = add i64 %4746, %4737
  %4748 = getelementptr inbounds i8, ptr %4743, i64 %4747
  br label %4749

4749:                                             ; preds = %4755, %4724
  %4750 = phi i64 [ 0, %4724 ], [ %4758, %4755 ]
  %4751 = phi i8 [ 0, %4724 ], [ %4760, %4755 ]
  %4752 = icmp slt i64 %4750, 1
  br i1 %4752, label %4753, label %4754

4753:                                             ; preds = %4749
  br label %4755

4754:                                             ; preds = %4749
  br label %4761

4755:                                             ; preds = %4753
  %4756 = icmp eq i64 %4750, 1
  %4757 = add i64 %4750, 1
  %4758 = select i1 %4756, i64 %4750, i64 %4757
  %4759 = getelementptr inbounds i8, ptr %4748, i64 %4750
  %4760 = load i8, ptr %4759, align 1, !invariant.load !1
  br label %4749

4761:                                             ; preds = %4754
  %4762 = phi i8 [ %4751, %4754 ]
  %4763 = call i64 @llvm.smax.i64(i64 %4741, i64 1)
  br label %4764

4764:                                             ; preds = %4790, %4761
  %4765 = phi i64 [ 1, %4761 ], [ %4773, %4790 ]
  %4766 = phi i8 [ %4762, %4761 ], [ %4803, %4790 ]
  %4767 = icmp slt i64 %4765, %4763
  br i1 %4767, label %4768, label %4769

4768:                                             ; preds = %4764
  br label %4770

4769:                                             ; preds = %4764
  br label %4804

4770:                                             ; preds = %4768
  %4771 = icmp eq i64 %4765, %4763
  %4772 = add i64 %4765, 1
  %4773 = select i1 %4771, i64 %4765, i64 %4772
  %4774 = mul i64 %4765, %4744
  %4775 = add i64 %4774, %4746
  %4776 = add i64 %4775, %4737
  %4777 = getelementptr inbounds i8, ptr %4743, i64 %4776
  br label %4778

4778:                                             ; preds = %4784, %4770
  %4779 = phi i64 [ 0, %4770 ], [ %4787, %4784 ]
  %4780 = phi i8 [ 0, %4770 ], [ %4789, %4784 ]
  %4781 = icmp slt i64 %4779, 1
  br i1 %4781, label %4782, label %4783

4782:                                             ; preds = %4778
  br label %4784

4783:                                             ; preds = %4778
  br label %4790

4784:                                             ; preds = %4782
  %4785 = icmp eq i64 %4779, 1
  %4786 = add i64 %4779, 1
  %4787 = select i1 %4785, i64 %4779, i64 %4786
  %4788 = getelementptr inbounds i8, ptr %4777, i64 %4779
  %4789 = load i8, ptr %4788, align 1, !invariant.load !1
  br label %4778

4790:                                             ; preds = %4783
  %4791 = phi i8 [ %4780, %4783 ]
  %4792 = zext i8 %4766 to i16
  %4793 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4792)
  %4794 = trunc i32 %4793 to i16
  %4795 = bitcast i16 %4794 to half
  %4796 = zext i8 %4791 to i16
  %4797 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4796)
  %4798 = trunc i32 %4797 to i16
  %4799 = bitcast i16 %4798 to half
  %4800 = fadd contract half %4795, %4799
  %4801 = fpext half %4800 to float
  %4802 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4801)
  %4803 = trunc i16 %4802 to i8
  br label %4764

4804:                                             ; preds = %4769
  %4805 = phi i8 [ %4766, %4769 ]
  %4806 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4742, 0
  %4807 = trunc i64 %4739 to i32
  %4808 = mul i32 %4807, 512
  %4809 = trunc i64 %4737 to i32
  %4810 = add i32 %4808, %4809
  %4811 = sext i32 %4810 to i64
  %4812 = getelementptr inbounds i8, ptr %4806, i64 %4811
  store i8 %4805, ptr %4812, align 1
  %4813 = load { i64, i64 }, ptr %6, align 8
  %4814 = add i64 %4737, 1
  %4815 = extractvalue { i64, i64 } %4813, 1
  %4816 = icmp sge i64 %4814, %4815
  %4817 = select i1 %4816, i64 0, i64 %4814
  %4818 = add i64 %4739, 1
  %4819 = select i1 %4816, i64 %4818, i64 %4739
  %4820 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4821 = load i64, ptr %4, align 8
  %4822 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4823 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4820, 0
  %4824 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4820, 1, 1, 0
  %4825 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4820, 1, 1, 1
  %4826 = mul i64 %4819, %4825
  %4827 = add i64 %4826, %4817
  %4828 = getelementptr inbounds i8, ptr %4823, i64 %4827
  br label %4829

4829:                                             ; preds = %4835, %4804
  %4830 = phi i64 [ 0, %4804 ], [ %4838, %4835 ]
  %4831 = phi i8 [ 0, %4804 ], [ %4840, %4835 ]
  %4832 = icmp slt i64 %4830, 1
  br i1 %4832, label %4833, label %4834

4833:                                             ; preds = %4829
  br label %4835

4834:                                             ; preds = %4829
  br label %4841

4835:                                             ; preds = %4833
  %4836 = icmp eq i64 %4830, 1
  %4837 = add i64 %4830, 1
  %4838 = select i1 %4836, i64 %4830, i64 %4837
  %4839 = getelementptr inbounds i8, ptr %4828, i64 %4830
  %4840 = load i8, ptr %4839, align 1, !invariant.load !1
  br label %4829

4841:                                             ; preds = %4834
  %4842 = phi i8 [ %4831, %4834 ]
  %4843 = call i64 @llvm.smax.i64(i64 %4821, i64 1)
  br label %4844

4844:                                             ; preds = %4870, %4841
  %4845 = phi i64 [ 1, %4841 ], [ %4853, %4870 ]
  %4846 = phi i8 [ %4842, %4841 ], [ %4883, %4870 ]
  %4847 = icmp slt i64 %4845, %4843
  br i1 %4847, label %4848, label %4849

4848:                                             ; preds = %4844
  br label %4850

4849:                                             ; preds = %4844
  br label %4884

4850:                                             ; preds = %4848
  %4851 = icmp eq i64 %4845, %4843
  %4852 = add i64 %4845, 1
  %4853 = select i1 %4851, i64 %4845, i64 %4852
  %4854 = mul i64 %4845, %4824
  %4855 = add i64 %4854, %4826
  %4856 = add i64 %4855, %4817
  %4857 = getelementptr inbounds i8, ptr %4823, i64 %4856
  br label %4858

4858:                                             ; preds = %4864, %4850
  %4859 = phi i64 [ 0, %4850 ], [ %4867, %4864 ]
  %4860 = phi i8 [ 0, %4850 ], [ %4869, %4864 ]
  %4861 = icmp slt i64 %4859, 1
  br i1 %4861, label %4862, label %4863

4862:                                             ; preds = %4858
  br label %4864

4863:                                             ; preds = %4858
  br label %4870

4864:                                             ; preds = %4862
  %4865 = icmp eq i64 %4859, 1
  %4866 = add i64 %4859, 1
  %4867 = select i1 %4865, i64 %4859, i64 %4866
  %4868 = getelementptr inbounds i8, ptr %4857, i64 %4859
  %4869 = load i8, ptr %4868, align 1, !invariant.load !1
  br label %4858

4870:                                             ; preds = %4863
  %4871 = phi i8 [ %4860, %4863 ]
  %4872 = zext i8 %4846 to i16
  %4873 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4872)
  %4874 = trunc i32 %4873 to i16
  %4875 = bitcast i16 %4874 to half
  %4876 = zext i8 %4871 to i16
  %4877 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4876)
  %4878 = trunc i32 %4877 to i16
  %4879 = bitcast i16 %4878 to half
  %4880 = fadd contract half %4875, %4879
  %4881 = fpext half %4880 to float
  %4882 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4881)
  %4883 = trunc i16 %4882 to i8
  br label %4844

4884:                                             ; preds = %4849
  %4885 = phi i8 [ %4846, %4849 ]
  %4886 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4822, 0
  %4887 = trunc i64 %4819 to i32
  %4888 = mul i32 %4887, 512
  %4889 = trunc i64 %4817 to i32
  %4890 = add i32 %4888, %4889
  %4891 = sext i32 %4890 to i64
  %4892 = getelementptr inbounds i8, ptr %4886, i64 %4891
  store i8 %4885, ptr %4892, align 1
  %4893 = load { i64, i64 }, ptr %6, align 8
  %4894 = add i64 %4817, 1
  %4895 = extractvalue { i64, i64 } %4893, 1
  %4896 = icmp sge i64 %4894, %4895
  %4897 = select i1 %4896, i64 0, i64 %4894
  %4898 = add i64 %4819, 1
  %4899 = select i1 %4896, i64 %4898, i64 %4819
  %4900 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4901 = load i64, ptr %4, align 8
  %4902 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4903 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4900, 0
  %4904 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4900, 1, 1, 0
  %4905 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4900, 1, 1, 1
  %4906 = mul i64 %4899, %4905
  %4907 = add i64 %4906, %4897
  %4908 = getelementptr inbounds i8, ptr %4903, i64 %4907
  br label %4909

4909:                                             ; preds = %4915, %4884
  %4910 = phi i64 [ 0, %4884 ], [ %4918, %4915 ]
  %4911 = phi i8 [ 0, %4884 ], [ %4920, %4915 ]
  %4912 = icmp slt i64 %4910, 1
  br i1 %4912, label %4913, label %4914

4913:                                             ; preds = %4909
  br label %4915

4914:                                             ; preds = %4909
  br label %4921

4915:                                             ; preds = %4913
  %4916 = icmp eq i64 %4910, 1
  %4917 = add i64 %4910, 1
  %4918 = select i1 %4916, i64 %4910, i64 %4917
  %4919 = getelementptr inbounds i8, ptr %4908, i64 %4910
  %4920 = load i8, ptr %4919, align 1, !invariant.load !1
  br label %4909

4921:                                             ; preds = %4914
  %4922 = phi i8 [ %4911, %4914 ]
  %4923 = call i64 @llvm.smax.i64(i64 %4901, i64 1)
  br label %4924

4924:                                             ; preds = %4950, %4921
  %4925 = phi i64 [ 1, %4921 ], [ %4933, %4950 ]
  %4926 = phi i8 [ %4922, %4921 ], [ %4963, %4950 ]
  %4927 = icmp slt i64 %4925, %4923
  br i1 %4927, label %4928, label %4929

4928:                                             ; preds = %4924
  br label %4930

4929:                                             ; preds = %4924
  br label %4964

4930:                                             ; preds = %4928
  %4931 = icmp eq i64 %4925, %4923
  %4932 = add i64 %4925, 1
  %4933 = select i1 %4931, i64 %4925, i64 %4932
  %4934 = mul i64 %4925, %4904
  %4935 = add i64 %4934, %4906
  %4936 = add i64 %4935, %4897
  %4937 = getelementptr inbounds i8, ptr %4903, i64 %4936
  br label %4938

4938:                                             ; preds = %4944, %4930
  %4939 = phi i64 [ 0, %4930 ], [ %4947, %4944 ]
  %4940 = phi i8 [ 0, %4930 ], [ %4949, %4944 ]
  %4941 = icmp slt i64 %4939, 1
  br i1 %4941, label %4942, label %4943

4942:                                             ; preds = %4938
  br label %4944

4943:                                             ; preds = %4938
  br label %4950

4944:                                             ; preds = %4942
  %4945 = icmp eq i64 %4939, 1
  %4946 = add i64 %4939, 1
  %4947 = select i1 %4945, i64 %4939, i64 %4946
  %4948 = getelementptr inbounds i8, ptr %4937, i64 %4939
  %4949 = load i8, ptr %4948, align 1, !invariant.load !1
  br label %4938

4950:                                             ; preds = %4943
  %4951 = phi i8 [ %4940, %4943 ]
  %4952 = zext i8 %4926 to i16
  %4953 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4952)
  %4954 = trunc i32 %4953 to i16
  %4955 = bitcast i16 %4954 to half
  %4956 = zext i8 %4951 to i16
  %4957 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %4956)
  %4958 = trunc i32 %4957 to i16
  %4959 = bitcast i16 %4958 to half
  %4960 = fadd contract half %4955, %4959
  %4961 = fpext half %4960 to float
  %4962 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %4961)
  %4963 = trunc i16 %4962 to i8
  br label %4924

4964:                                             ; preds = %4929
  %4965 = phi i8 [ %4926, %4929 ]
  %4966 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4902, 0
  %4967 = trunc i64 %4899 to i32
  %4968 = mul i32 %4967, 512
  %4969 = trunc i64 %4897 to i32
  %4970 = add i32 %4968, %4969
  %4971 = sext i32 %4970 to i64
  %4972 = getelementptr inbounds i8, ptr %4966, i64 %4971
  store i8 %4965, ptr %4972, align 1
  %4973 = load { i64, i64 }, ptr %6, align 8
  %4974 = add i64 %4897, 1
  %4975 = extractvalue { i64, i64 } %4973, 1
  %4976 = icmp sge i64 %4974, %4975
  %4977 = select i1 %4976, i64 0, i64 %4974
  %4978 = add i64 %4899, 1
  %4979 = select i1 %4976, i64 %4978, i64 %4899
  %4980 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %4981 = load i64, ptr %4, align 8
  %4982 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %4983 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4980, 0
  %4984 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4980, 1, 1, 0
  %4985 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %4980, 1, 1, 1
  %4986 = mul i64 %4979, %4985
  %4987 = add i64 %4986, %4977
  %4988 = getelementptr inbounds i8, ptr %4983, i64 %4987
  br label %4989

4989:                                             ; preds = %4995, %4964
  %4990 = phi i64 [ 0, %4964 ], [ %4998, %4995 ]
  %4991 = phi i8 [ 0, %4964 ], [ %5000, %4995 ]
  %4992 = icmp slt i64 %4990, 1
  br i1 %4992, label %4993, label %4994

4993:                                             ; preds = %4989
  br label %4995

4994:                                             ; preds = %4989
  br label %5001

4995:                                             ; preds = %4993
  %4996 = icmp eq i64 %4990, 1
  %4997 = add i64 %4990, 1
  %4998 = select i1 %4996, i64 %4990, i64 %4997
  %4999 = getelementptr inbounds i8, ptr %4988, i64 %4990
  %5000 = load i8, ptr %4999, align 1, !invariant.load !1
  br label %4989

5001:                                             ; preds = %4994
  %5002 = phi i8 [ %4991, %4994 ]
  %5003 = call i64 @llvm.smax.i64(i64 %4981, i64 1)
  br label %5004

5004:                                             ; preds = %5030, %5001
  %5005 = phi i64 [ 1, %5001 ], [ %5013, %5030 ]
  %5006 = phi i8 [ %5002, %5001 ], [ %5043, %5030 ]
  %5007 = icmp slt i64 %5005, %5003
  br i1 %5007, label %5008, label %5009

5008:                                             ; preds = %5004
  br label %5010

5009:                                             ; preds = %5004
  br label %5044

5010:                                             ; preds = %5008
  %5011 = icmp eq i64 %5005, %5003
  %5012 = add i64 %5005, 1
  %5013 = select i1 %5011, i64 %5005, i64 %5012
  %5014 = mul i64 %5005, %4984
  %5015 = add i64 %5014, %4986
  %5016 = add i64 %5015, %4977
  %5017 = getelementptr inbounds i8, ptr %4983, i64 %5016
  br label %5018

5018:                                             ; preds = %5024, %5010
  %5019 = phi i64 [ 0, %5010 ], [ %5027, %5024 ]
  %5020 = phi i8 [ 0, %5010 ], [ %5029, %5024 ]
  %5021 = icmp slt i64 %5019, 1
  br i1 %5021, label %5022, label %5023

5022:                                             ; preds = %5018
  br label %5024

5023:                                             ; preds = %5018
  br label %5030

5024:                                             ; preds = %5022
  %5025 = icmp eq i64 %5019, 1
  %5026 = add i64 %5019, 1
  %5027 = select i1 %5025, i64 %5019, i64 %5026
  %5028 = getelementptr inbounds i8, ptr %5017, i64 %5019
  %5029 = load i8, ptr %5028, align 1, !invariant.load !1
  br label %5018

5030:                                             ; preds = %5023
  %5031 = phi i8 [ %5020, %5023 ]
  %5032 = zext i8 %5006 to i16
  %5033 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5032)
  %5034 = trunc i32 %5033 to i16
  %5035 = bitcast i16 %5034 to half
  %5036 = zext i8 %5031 to i16
  %5037 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5036)
  %5038 = trunc i32 %5037 to i16
  %5039 = bitcast i16 %5038 to half
  %5040 = fadd contract half %5035, %5039
  %5041 = fpext half %5040 to float
  %5042 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5041)
  %5043 = trunc i16 %5042 to i8
  br label %5004

5044:                                             ; preds = %5009
  %5045 = phi i8 [ %5006, %5009 ]
  %5046 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4982, 0
  %5047 = trunc i64 %4979 to i32
  %5048 = mul i32 %5047, 512
  %5049 = trunc i64 %4977 to i32
  %5050 = add i32 %5048, %5049
  %5051 = sext i32 %5050 to i64
  %5052 = getelementptr inbounds i8, ptr %5046, i64 %5051
  store i8 %5045, ptr %5052, align 1
  %5053 = load { i64, i64 }, ptr %6, align 8
  %5054 = add i64 %4977, 1
  %5055 = extractvalue { i64, i64 } %5053, 1
  %5056 = icmp sge i64 %5054, %5055
  %5057 = select i1 %5056, i64 0, i64 %5054
  %5058 = add i64 %4979, 1
  %5059 = select i1 %5056, i64 %5058, i64 %4979
  %5060 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5061 = load i64, ptr %4, align 8
  %5062 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5063 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5060, 0
  %5064 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5060, 1, 1, 0
  %5065 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5060, 1, 1, 1
  %5066 = mul i64 %5059, %5065
  %5067 = add i64 %5066, %5057
  %5068 = getelementptr inbounds i8, ptr %5063, i64 %5067
  br label %5069

5069:                                             ; preds = %5075, %5044
  %5070 = phi i64 [ 0, %5044 ], [ %5078, %5075 ]
  %5071 = phi i8 [ 0, %5044 ], [ %5080, %5075 ]
  %5072 = icmp slt i64 %5070, 1
  br i1 %5072, label %5073, label %5074

5073:                                             ; preds = %5069
  br label %5075

5074:                                             ; preds = %5069
  br label %5081

5075:                                             ; preds = %5073
  %5076 = icmp eq i64 %5070, 1
  %5077 = add i64 %5070, 1
  %5078 = select i1 %5076, i64 %5070, i64 %5077
  %5079 = getelementptr inbounds i8, ptr %5068, i64 %5070
  %5080 = load i8, ptr %5079, align 1, !invariant.load !1
  br label %5069

5081:                                             ; preds = %5074
  %5082 = phi i8 [ %5071, %5074 ]
  %5083 = call i64 @llvm.smax.i64(i64 %5061, i64 1)
  br label %5084

5084:                                             ; preds = %5110, %5081
  %5085 = phi i64 [ 1, %5081 ], [ %5093, %5110 ]
  %5086 = phi i8 [ %5082, %5081 ], [ %5123, %5110 ]
  %5087 = icmp slt i64 %5085, %5083
  br i1 %5087, label %5088, label %5089

5088:                                             ; preds = %5084
  br label %5090

5089:                                             ; preds = %5084
  br label %5124

5090:                                             ; preds = %5088
  %5091 = icmp eq i64 %5085, %5083
  %5092 = add i64 %5085, 1
  %5093 = select i1 %5091, i64 %5085, i64 %5092
  %5094 = mul i64 %5085, %5064
  %5095 = add i64 %5094, %5066
  %5096 = add i64 %5095, %5057
  %5097 = getelementptr inbounds i8, ptr %5063, i64 %5096
  br label %5098

5098:                                             ; preds = %5104, %5090
  %5099 = phi i64 [ 0, %5090 ], [ %5107, %5104 ]
  %5100 = phi i8 [ 0, %5090 ], [ %5109, %5104 ]
  %5101 = icmp slt i64 %5099, 1
  br i1 %5101, label %5102, label %5103

5102:                                             ; preds = %5098
  br label %5104

5103:                                             ; preds = %5098
  br label %5110

5104:                                             ; preds = %5102
  %5105 = icmp eq i64 %5099, 1
  %5106 = add i64 %5099, 1
  %5107 = select i1 %5105, i64 %5099, i64 %5106
  %5108 = getelementptr inbounds i8, ptr %5097, i64 %5099
  %5109 = load i8, ptr %5108, align 1, !invariant.load !1
  br label %5098

5110:                                             ; preds = %5103
  %5111 = phi i8 [ %5100, %5103 ]
  %5112 = zext i8 %5086 to i16
  %5113 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5112)
  %5114 = trunc i32 %5113 to i16
  %5115 = bitcast i16 %5114 to half
  %5116 = zext i8 %5111 to i16
  %5117 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5116)
  %5118 = trunc i32 %5117 to i16
  %5119 = bitcast i16 %5118 to half
  %5120 = fadd contract half %5115, %5119
  %5121 = fpext half %5120 to float
  %5122 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5121)
  %5123 = trunc i16 %5122 to i8
  br label %5084

5124:                                             ; preds = %5089
  %5125 = phi i8 [ %5086, %5089 ]
  %5126 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5062, 0
  %5127 = trunc i64 %5059 to i32
  %5128 = mul i32 %5127, 512
  %5129 = trunc i64 %5057 to i32
  %5130 = add i32 %5128, %5129
  %5131 = sext i32 %5130 to i64
  %5132 = getelementptr inbounds i8, ptr %5126, i64 %5131
  store i8 %5125, ptr %5132, align 1
  %5133 = load { i64, i64 }, ptr %6, align 8
  %5134 = add i64 %5057, 1
  %5135 = extractvalue { i64, i64 } %5133, 1
  %5136 = icmp sge i64 %5134, %5135
  %5137 = select i1 %5136, i64 0, i64 %5134
  %5138 = add i64 %5059, 1
  %5139 = select i1 %5136, i64 %5138, i64 %5059
  %5140 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5141 = load i64, ptr %4, align 8
  %5142 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5143 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5140, 0
  %5144 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5140, 1, 1, 0
  %5145 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5140, 1, 1, 1
  %5146 = mul i64 %5139, %5145
  %5147 = add i64 %5146, %5137
  %5148 = getelementptr inbounds i8, ptr %5143, i64 %5147
  br label %5149

5149:                                             ; preds = %5155, %5124
  %5150 = phi i64 [ 0, %5124 ], [ %5158, %5155 ]
  %5151 = phi i8 [ 0, %5124 ], [ %5160, %5155 ]
  %5152 = icmp slt i64 %5150, 1
  br i1 %5152, label %5153, label %5154

5153:                                             ; preds = %5149
  br label %5155

5154:                                             ; preds = %5149
  br label %5161

5155:                                             ; preds = %5153
  %5156 = icmp eq i64 %5150, 1
  %5157 = add i64 %5150, 1
  %5158 = select i1 %5156, i64 %5150, i64 %5157
  %5159 = getelementptr inbounds i8, ptr %5148, i64 %5150
  %5160 = load i8, ptr %5159, align 1, !invariant.load !1
  br label %5149

5161:                                             ; preds = %5154
  %5162 = phi i8 [ %5151, %5154 ]
  %5163 = call i64 @llvm.smax.i64(i64 %5141, i64 1)
  br label %5164

5164:                                             ; preds = %5190, %5161
  %5165 = phi i64 [ 1, %5161 ], [ %5173, %5190 ]
  %5166 = phi i8 [ %5162, %5161 ], [ %5203, %5190 ]
  %5167 = icmp slt i64 %5165, %5163
  br i1 %5167, label %5168, label %5169

5168:                                             ; preds = %5164
  br label %5170

5169:                                             ; preds = %5164
  br label %5204

5170:                                             ; preds = %5168
  %5171 = icmp eq i64 %5165, %5163
  %5172 = add i64 %5165, 1
  %5173 = select i1 %5171, i64 %5165, i64 %5172
  %5174 = mul i64 %5165, %5144
  %5175 = add i64 %5174, %5146
  %5176 = add i64 %5175, %5137
  %5177 = getelementptr inbounds i8, ptr %5143, i64 %5176
  br label %5178

5178:                                             ; preds = %5184, %5170
  %5179 = phi i64 [ 0, %5170 ], [ %5187, %5184 ]
  %5180 = phi i8 [ 0, %5170 ], [ %5189, %5184 ]
  %5181 = icmp slt i64 %5179, 1
  br i1 %5181, label %5182, label %5183

5182:                                             ; preds = %5178
  br label %5184

5183:                                             ; preds = %5178
  br label %5190

5184:                                             ; preds = %5182
  %5185 = icmp eq i64 %5179, 1
  %5186 = add i64 %5179, 1
  %5187 = select i1 %5185, i64 %5179, i64 %5186
  %5188 = getelementptr inbounds i8, ptr %5177, i64 %5179
  %5189 = load i8, ptr %5188, align 1, !invariant.load !1
  br label %5178

5190:                                             ; preds = %5183
  %5191 = phi i8 [ %5180, %5183 ]
  %5192 = zext i8 %5166 to i16
  %5193 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5192)
  %5194 = trunc i32 %5193 to i16
  %5195 = bitcast i16 %5194 to half
  %5196 = zext i8 %5191 to i16
  %5197 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5196)
  %5198 = trunc i32 %5197 to i16
  %5199 = bitcast i16 %5198 to half
  %5200 = fadd contract half %5195, %5199
  %5201 = fpext half %5200 to float
  %5202 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5201)
  %5203 = trunc i16 %5202 to i8
  br label %5164

5204:                                             ; preds = %5169
  %5205 = phi i8 [ %5166, %5169 ]
  %5206 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5142, 0
  %5207 = trunc i64 %5139 to i32
  %5208 = mul i32 %5207, 512
  %5209 = trunc i64 %5137 to i32
  %5210 = add i32 %5208, %5209
  %5211 = sext i32 %5210 to i64
  %5212 = getelementptr inbounds i8, ptr %5206, i64 %5211
  store i8 %5205, ptr %5212, align 1
  %5213 = load { i64, i64 }, ptr %6, align 8
  %5214 = add i64 %5137, 1
  %5215 = extractvalue { i64, i64 } %5213, 1
  %5216 = icmp sge i64 %5214, %5215
  %5217 = select i1 %5216, i64 0, i64 %5214
  %5218 = add i64 %5139, 1
  %5219 = select i1 %5216, i64 %5218, i64 %5139
  %5220 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5221 = load i64, ptr %4, align 8
  %5222 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5223 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5220, 0
  %5224 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5220, 1, 1, 0
  %5225 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5220, 1, 1, 1
  %5226 = mul i64 %5219, %5225
  %5227 = add i64 %5226, %5217
  %5228 = getelementptr inbounds i8, ptr %5223, i64 %5227
  br label %5229

5229:                                             ; preds = %5235, %5204
  %5230 = phi i64 [ 0, %5204 ], [ %5238, %5235 ]
  %5231 = phi i8 [ 0, %5204 ], [ %5240, %5235 ]
  %5232 = icmp slt i64 %5230, 1
  br i1 %5232, label %5233, label %5234

5233:                                             ; preds = %5229
  br label %5235

5234:                                             ; preds = %5229
  br label %5241

5235:                                             ; preds = %5233
  %5236 = icmp eq i64 %5230, 1
  %5237 = add i64 %5230, 1
  %5238 = select i1 %5236, i64 %5230, i64 %5237
  %5239 = getelementptr inbounds i8, ptr %5228, i64 %5230
  %5240 = load i8, ptr %5239, align 1, !invariant.load !1
  br label %5229

5241:                                             ; preds = %5234
  %5242 = phi i8 [ %5231, %5234 ]
  %5243 = call i64 @llvm.smax.i64(i64 %5221, i64 1)
  br label %5244

5244:                                             ; preds = %5270, %5241
  %5245 = phi i64 [ 1, %5241 ], [ %5253, %5270 ]
  %5246 = phi i8 [ %5242, %5241 ], [ %5283, %5270 ]
  %5247 = icmp slt i64 %5245, %5243
  br i1 %5247, label %5248, label %5249

5248:                                             ; preds = %5244
  br label %5250

5249:                                             ; preds = %5244
  br label %5284

5250:                                             ; preds = %5248
  %5251 = icmp eq i64 %5245, %5243
  %5252 = add i64 %5245, 1
  %5253 = select i1 %5251, i64 %5245, i64 %5252
  %5254 = mul i64 %5245, %5224
  %5255 = add i64 %5254, %5226
  %5256 = add i64 %5255, %5217
  %5257 = getelementptr inbounds i8, ptr %5223, i64 %5256
  br label %5258

5258:                                             ; preds = %5264, %5250
  %5259 = phi i64 [ 0, %5250 ], [ %5267, %5264 ]
  %5260 = phi i8 [ 0, %5250 ], [ %5269, %5264 ]
  %5261 = icmp slt i64 %5259, 1
  br i1 %5261, label %5262, label %5263

5262:                                             ; preds = %5258
  br label %5264

5263:                                             ; preds = %5258
  br label %5270

5264:                                             ; preds = %5262
  %5265 = icmp eq i64 %5259, 1
  %5266 = add i64 %5259, 1
  %5267 = select i1 %5265, i64 %5259, i64 %5266
  %5268 = getelementptr inbounds i8, ptr %5257, i64 %5259
  %5269 = load i8, ptr %5268, align 1, !invariant.load !1
  br label %5258

5270:                                             ; preds = %5263
  %5271 = phi i8 [ %5260, %5263 ]
  %5272 = zext i8 %5246 to i16
  %5273 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5272)
  %5274 = trunc i32 %5273 to i16
  %5275 = bitcast i16 %5274 to half
  %5276 = zext i8 %5271 to i16
  %5277 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5276)
  %5278 = trunc i32 %5277 to i16
  %5279 = bitcast i16 %5278 to half
  %5280 = fadd contract half %5275, %5279
  %5281 = fpext half %5280 to float
  %5282 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5281)
  %5283 = trunc i16 %5282 to i8
  br label %5244

5284:                                             ; preds = %5249
  %5285 = phi i8 [ %5246, %5249 ]
  %5286 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5222, 0
  %5287 = trunc i64 %5219 to i32
  %5288 = mul i32 %5287, 512
  %5289 = trunc i64 %5217 to i32
  %5290 = add i32 %5288, %5289
  %5291 = sext i32 %5290 to i64
  %5292 = getelementptr inbounds i8, ptr %5286, i64 %5291
  store i8 %5285, ptr %5292, align 1
  %5293 = load { i64, i64 }, ptr %6, align 8
  %5294 = add i64 %5217, 1
  %5295 = extractvalue { i64, i64 } %5293, 1
  %5296 = icmp sge i64 %5294, %5295
  %5297 = select i1 %5296, i64 0, i64 %5294
  %5298 = add i64 %5219, 1
  %5299 = select i1 %5296, i64 %5298, i64 %5219
  %5300 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5301 = load i64, ptr %4, align 8
  %5302 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5303 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5300, 0
  %5304 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5300, 1, 1, 0
  %5305 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5300, 1, 1, 1
  %5306 = mul i64 %5299, %5305
  %5307 = add i64 %5306, %5297
  %5308 = getelementptr inbounds i8, ptr %5303, i64 %5307
  br label %5309

5309:                                             ; preds = %5315, %5284
  %5310 = phi i64 [ 0, %5284 ], [ %5318, %5315 ]
  %5311 = phi i8 [ 0, %5284 ], [ %5320, %5315 ]
  %5312 = icmp slt i64 %5310, 1
  br i1 %5312, label %5313, label %5314

5313:                                             ; preds = %5309
  br label %5315

5314:                                             ; preds = %5309
  br label %5321

5315:                                             ; preds = %5313
  %5316 = icmp eq i64 %5310, 1
  %5317 = add i64 %5310, 1
  %5318 = select i1 %5316, i64 %5310, i64 %5317
  %5319 = getelementptr inbounds i8, ptr %5308, i64 %5310
  %5320 = load i8, ptr %5319, align 1, !invariant.load !1
  br label %5309

5321:                                             ; preds = %5314
  %5322 = phi i8 [ %5311, %5314 ]
  %5323 = call i64 @llvm.smax.i64(i64 %5301, i64 1)
  br label %5324

5324:                                             ; preds = %5350, %5321
  %5325 = phi i64 [ 1, %5321 ], [ %5333, %5350 ]
  %5326 = phi i8 [ %5322, %5321 ], [ %5363, %5350 ]
  %5327 = icmp slt i64 %5325, %5323
  br i1 %5327, label %5328, label %5329

5328:                                             ; preds = %5324
  br label %5330

5329:                                             ; preds = %5324
  br label %5364

5330:                                             ; preds = %5328
  %5331 = icmp eq i64 %5325, %5323
  %5332 = add i64 %5325, 1
  %5333 = select i1 %5331, i64 %5325, i64 %5332
  %5334 = mul i64 %5325, %5304
  %5335 = add i64 %5334, %5306
  %5336 = add i64 %5335, %5297
  %5337 = getelementptr inbounds i8, ptr %5303, i64 %5336
  br label %5338

5338:                                             ; preds = %5344, %5330
  %5339 = phi i64 [ 0, %5330 ], [ %5347, %5344 ]
  %5340 = phi i8 [ 0, %5330 ], [ %5349, %5344 ]
  %5341 = icmp slt i64 %5339, 1
  br i1 %5341, label %5342, label %5343

5342:                                             ; preds = %5338
  br label %5344

5343:                                             ; preds = %5338
  br label %5350

5344:                                             ; preds = %5342
  %5345 = icmp eq i64 %5339, 1
  %5346 = add i64 %5339, 1
  %5347 = select i1 %5345, i64 %5339, i64 %5346
  %5348 = getelementptr inbounds i8, ptr %5337, i64 %5339
  %5349 = load i8, ptr %5348, align 1, !invariant.load !1
  br label %5338

5350:                                             ; preds = %5343
  %5351 = phi i8 [ %5340, %5343 ]
  %5352 = zext i8 %5326 to i16
  %5353 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5352)
  %5354 = trunc i32 %5353 to i16
  %5355 = bitcast i16 %5354 to half
  %5356 = zext i8 %5351 to i16
  %5357 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5356)
  %5358 = trunc i32 %5357 to i16
  %5359 = bitcast i16 %5358 to half
  %5360 = fadd contract half %5355, %5359
  %5361 = fpext half %5360 to float
  %5362 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5361)
  %5363 = trunc i16 %5362 to i8
  br label %5324

5364:                                             ; preds = %5329
  %5365 = phi i8 [ %5326, %5329 ]
  %5366 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5302, 0
  %5367 = trunc i64 %5299 to i32
  %5368 = mul i32 %5367, 512
  %5369 = trunc i64 %5297 to i32
  %5370 = add i32 %5368, %5369
  %5371 = sext i32 %5370 to i64
  %5372 = getelementptr inbounds i8, ptr %5366, i64 %5371
  store i8 %5365, ptr %5372, align 1
  %5373 = load { i64, i64 }, ptr %6, align 8
  %5374 = add i64 %5297, 1
  %5375 = extractvalue { i64, i64 } %5373, 1
  %5376 = icmp sge i64 %5374, %5375
  %5377 = select i1 %5376, i64 0, i64 %5374
  %5378 = add i64 %5299, 1
  %5379 = select i1 %5376, i64 %5378, i64 %5299
  %5380 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5381 = load i64, ptr %4, align 8
  %5382 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5383 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5380, 0
  %5384 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5380, 1, 1, 0
  %5385 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5380, 1, 1, 1
  %5386 = mul i64 %5379, %5385
  %5387 = add i64 %5386, %5377
  %5388 = getelementptr inbounds i8, ptr %5383, i64 %5387
  br label %5389

5389:                                             ; preds = %5395, %5364
  %5390 = phi i64 [ 0, %5364 ], [ %5398, %5395 ]
  %5391 = phi i8 [ 0, %5364 ], [ %5400, %5395 ]
  %5392 = icmp slt i64 %5390, 1
  br i1 %5392, label %5393, label %5394

5393:                                             ; preds = %5389
  br label %5395

5394:                                             ; preds = %5389
  br label %5401

5395:                                             ; preds = %5393
  %5396 = icmp eq i64 %5390, 1
  %5397 = add i64 %5390, 1
  %5398 = select i1 %5396, i64 %5390, i64 %5397
  %5399 = getelementptr inbounds i8, ptr %5388, i64 %5390
  %5400 = load i8, ptr %5399, align 1, !invariant.load !1
  br label %5389

5401:                                             ; preds = %5394
  %5402 = phi i8 [ %5391, %5394 ]
  %5403 = call i64 @llvm.smax.i64(i64 %5381, i64 1)
  br label %5404

5404:                                             ; preds = %5430, %5401
  %5405 = phi i64 [ 1, %5401 ], [ %5413, %5430 ]
  %5406 = phi i8 [ %5402, %5401 ], [ %5443, %5430 ]
  %5407 = icmp slt i64 %5405, %5403
  br i1 %5407, label %5408, label %5409

5408:                                             ; preds = %5404
  br label %5410

5409:                                             ; preds = %5404
  br label %5444

5410:                                             ; preds = %5408
  %5411 = icmp eq i64 %5405, %5403
  %5412 = add i64 %5405, 1
  %5413 = select i1 %5411, i64 %5405, i64 %5412
  %5414 = mul i64 %5405, %5384
  %5415 = add i64 %5414, %5386
  %5416 = add i64 %5415, %5377
  %5417 = getelementptr inbounds i8, ptr %5383, i64 %5416
  br label %5418

5418:                                             ; preds = %5424, %5410
  %5419 = phi i64 [ 0, %5410 ], [ %5427, %5424 ]
  %5420 = phi i8 [ 0, %5410 ], [ %5429, %5424 ]
  %5421 = icmp slt i64 %5419, 1
  br i1 %5421, label %5422, label %5423

5422:                                             ; preds = %5418
  br label %5424

5423:                                             ; preds = %5418
  br label %5430

5424:                                             ; preds = %5422
  %5425 = icmp eq i64 %5419, 1
  %5426 = add i64 %5419, 1
  %5427 = select i1 %5425, i64 %5419, i64 %5426
  %5428 = getelementptr inbounds i8, ptr %5417, i64 %5419
  %5429 = load i8, ptr %5428, align 1, !invariant.load !1
  br label %5418

5430:                                             ; preds = %5423
  %5431 = phi i8 [ %5420, %5423 ]
  %5432 = zext i8 %5406 to i16
  %5433 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5432)
  %5434 = trunc i32 %5433 to i16
  %5435 = bitcast i16 %5434 to half
  %5436 = zext i8 %5431 to i16
  %5437 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5436)
  %5438 = trunc i32 %5437 to i16
  %5439 = bitcast i16 %5438 to half
  %5440 = fadd contract half %5435, %5439
  %5441 = fpext half %5440 to float
  %5442 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5441)
  %5443 = trunc i16 %5442 to i8
  br label %5404

5444:                                             ; preds = %5409
  %5445 = phi i8 [ %5406, %5409 ]
  %5446 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5382, 0
  %5447 = trunc i64 %5379 to i32
  %5448 = mul i32 %5447, 512
  %5449 = trunc i64 %5377 to i32
  %5450 = add i32 %5448, %5449
  %5451 = sext i32 %5450 to i64
  %5452 = getelementptr inbounds i8, ptr %5446, i64 %5451
  store i8 %5445, ptr %5452, align 1
  %5453 = load { i64, i64 }, ptr %6, align 8
  %5454 = add i64 %5377, 1
  %5455 = extractvalue { i64, i64 } %5453, 1
  %5456 = icmp sge i64 %5454, %5455
  %5457 = select i1 %5456, i64 0, i64 %5454
  %5458 = add i64 %5379, 1
  %5459 = select i1 %5456, i64 %5458, i64 %5379
  %5460 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5461 = load i64, ptr %4, align 8
  %5462 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5463 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5460, 0
  %5464 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5460, 1, 1, 0
  %5465 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5460, 1, 1, 1
  %5466 = mul i64 %5459, %5465
  %5467 = add i64 %5466, %5457
  %5468 = getelementptr inbounds i8, ptr %5463, i64 %5467
  br label %5469

5469:                                             ; preds = %5475, %5444
  %5470 = phi i64 [ 0, %5444 ], [ %5478, %5475 ]
  %5471 = phi i8 [ 0, %5444 ], [ %5480, %5475 ]
  %5472 = icmp slt i64 %5470, 1
  br i1 %5472, label %5473, label %5474

5473:                                             ; preds = %5469
  br label %5475

5474:                                             ; preds = %5469
  br label %5481

5475:                                             ; preds = %5473
  %5476 = icmp eq i64 %5470, 1
  %5477 = add i64 %5470, 1
  %5478 = select i1 %5476, i64 %5470, i64 %5477
  %5479 = getelementptr inbounds i8, ptr %5468, i64 %5470
  %5480 = load i8, ptr %5479, align 1, !invariant.load !1
  br label %5469

5481:                                             ; preds = %5474
  %5482 = phi i8 [ %5471, %5474 ]
  %5483 = call i64 @llvm.smax.i64(i64 %5461, i64 1)
  br label %5484

5484:                                             ; preds = %5510, %5481
  %5485 = phi i64 [ 1, %5481 ], [ %5493, %5510 ]
  %5486 = phi i8 [ %5482, %5481 ], [ %5523, %5510 ]
  %5487 = icmp slt i64 %5485, %5483
  br i1 %5487, label %5488, label %5489

5488:                                             ; preds = %5484
  br label %5490

5489:                                             ; preds = %5484
  br label %5524

5490:                                             ; preds = %5488
  %5491 = icmp eq i64 %5485, %5483
  %5492 = add i64 %5485, 1
  %5493 = select i1 %5491, i64 %5485, i64 %5492
  %5494 = mul i64 %5485, %5464
  %5495 = add i64 %5494, %5466
  %5496 = add i64 %5495, %5457
  %5497 = getelementptr inbounds i8, ptr %5463, i64 %5496
  br label %5498

5498:                                             ; preds = %5504, %5490
  %5499 = phi i64 [ 0, %5490 ], [ %5507, %5504 ]
  %5500 = phi i8 [ 0, %5490 ], [ %5509, %5504 ]
  %5501 = icmp slt i64 %5499, 1
  br i1 %5501, label %5502, label %5503

5502:                                             ; preds = %5498
  br label %5504

5503:                                             ; preds = %5498
  br label %5510

5504:                                             ; preds = %5502
  %5505 = icmp eq i64 %5499, 1
  %5506 = add i64 %5499, 1
  %5507 = select i1 %5505, i64 %5499, i64 %5506
  %5508 = getelementptr inbounds i8, ptr %5497, i64 %5499
  %5509 = load i8, ptr %5508, align 1, !invariant.load !1
  br label %5498

5510:                                             ; preds = %5503
  %5511 = phi i8 [ %5500, %5503 ]
  %5512 = zext i8 %5486 to i16
  %5513 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5512)
  %5514 = trunc i32 %5513 to i16
  %5515 = bitcast i16 %5514 to half
  %5516 = zext i8 %5511 to i16
  %5517 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5516)
  %5518 = trunc i32 %5517 to i16
  %5519 = bitcast i16 %5518 to half
  %5520 = fadd contract half %5515, %5519
  %5521 = fpext half %5520 to float
  %5522 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5521)
  %5523 = trunc i16 %5522 to i8
  br label %5484

5524:                                             ; preds = %5489
  %5525 = phi i8 [ %5486, %5489 ]
  %5526 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5462, 0
  %5527 = trunc i64 %5459 to i32
  %5528 = mul i32 %5527, 512
  %5529 = trunc i64 %5457 to i32
  %5530 = add i32 %5528, %5529
  %5531 = sext i32 %5530 to i64
  %5532 = getelementptr inbounds i8, ptr %5526, i64 %5531
  store i8 %5525, ptr %5532, align 1
  %5533 = load { i64, i64 }, ptr %6, align 8
  %5534 = add i64 %5457, 1
  %5535 = extractvalue { i64, i64 } %5533, 1
  %5536 = icmp sge i64 %5534, %5535
  %5537 = select i1 %5536, i64 0, i64 %5534
  %5538 = add i64 %5459, 1
  %5539 = select i1 %5536, i64 %5538, i64 %5459
  %5540 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5541 = load i64, ptr %4, align 8
  %5542 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5543 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5540, 0
  %5544 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5540, 1, 1, 0
  %5545 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5540, 1, 1, 1
  %5546 = mul i64 %5539, %5545
  %5547 = add i64 %5546, %5537
  %5548 = getelementptr inbounds i8, ptr %5543, i64 %5547
  br label %5549

5549:                                             ; preds = %5555, %5524
  %5550 = phi i64 [ 0, %5524 ], [ %5558, %5555 ]
  %5551 = phi i8 [ 0, %5524 ], [ %5560, %5555 ]
  %5552 = icmp slt i64 %5550, 1
  br i1 %5552, label %5553, label %5554

5553:                                             ; preds = %5549
  br label %5555

5554:                                             ; preds = %5549
  br label %5561

5555:                                             ; preds = %5553
  %5556 = icmp eq i64 %5550, 1
  %5557 = add i64 %5550, 1
  %5558 = select i1 %5556, i64 %5550, i64 %5557
  %5559 = getelementptr inbounds i8, ptr %5548, i64 %5550
  %5560 = load i8, ptr %5559, align 1, !invariant.load !1
  br label %5549

5561:                                             ; preds = %5554
  %5562 = phi i8 [ %5551, %5554 ]
  %5563 = call i64 @llvm.smax.i64(i64 %5541, i64 1)
  br label %5564

5564:                                             ; preds = %5590, %5561
  %5565 = phi i64 [ 1, %5561 ], [ %5573, %5590 ]
  %5566 = phi i8 [ %5562, %5561 ], [ %5603, %5590 ]
  %5567 = icmp slt i64 %5565, %5563
  br i1 %5567, label %5568, label %5569

5568:                                             ; preds = %5564
  br label %5570

5569:                                             ; preds = %5564
  br label %5604

5570:                                             ; preds = %5568
  %5571 = icmp eq i64 %5565, %5563
  %5572 = add i64 %5565, 1
  %5573 = select i1 %5571, i64 %5565, i64 %5572
  %5574 = mul i64 %5565, %5544
  %5575 = add i64 %5574, %5546
  %5576 = add i64 %5575, %5537
  %5577 = getelementptr inbounds i8, ptr %5543, i64 %5576
  br label %5578

5578:                                             ; preds = %5584, %5570
  %5579 = phi i64 [ 0, %5570 ], [ %5587, %5584 ]
  %5580 = phi i8 [ 0, %5570 ], [ %5589, %5584 ]
  %5581 = icmp slt i64 %5579, 1
  br i1 %5581, label %5582, label %5583

5582:                                             ; preds = %5578
  br label %5584

5583:                                             ; preds = %5578
  br label %5590

5584:                                             ; preds = %5582
  %5585 = icmp eq i64 %5579, 1
  %5586 = add i64 %5579, 1
  %5587 = select i1 %5585, i64 %5579, i64 %5586
  %5588 = getelementptr inbounds i8, ptr %5577, i64 %5579
  %5589 = load i8, ptr %5588, align 1, !invariant.load !1
  br label %5578

5590:                                             ; preds = %5583
  %5591 = phi i8 [ %5580, %5583 ]
  %5592 = zext i8 %5566 to i16
  %5593 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5592)
  %5594 = trunc i32 %5593 to i16
  %5595 = bitcast i16 %5594 to half
  %5596 = zext i8 %5591 to i16
  %5597 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5596)
  %5598 = trunc i32 %5597 to i16
  %5599 = bitcast i16 %5598 to half
  %5600 = fadd contract half %5595, %5599
  %5601 = fpext half %5600 to float
  %5602 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5601)
  %5603 = trunc i16 %5602 to i8
  br label %5564

5604:                                             ; preds = %5569
  %5605 = phi i8 [ %5566, %5569 ]
  %5606 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5542, 0
  %5607 = trunc i64 %5539 to i32
  %5608 = mul i32 %5607, 512
  %5609 = trunc i64 %5537 to i32
  %5610 = add i32 %5608, %5609
  %5611 = sext i32 %5610 to i64
  %5612 = getelementptr inbounds i8, ptr %5606, i64 %5611
  store i8 %5605, ptr %5612, align 1
  br label %5731

5613:                                             ; preds = %4320
  %5614 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5615 = load i64, ptr %4, align 8
  %5616 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5617 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5614, 0
  %5618 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5614, 1, 1, 0
  %5619 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5614, 1, 1, 1
  %5620 = mul i64 %4337, %5619
  %5621 = add i64 %5620, %4334
  %5622 = getelementptr inbounds i8, ptr %5617, i64 %5621
  %5623 = load <16 x i8>, ptr %5622, align 16, !invariant.load !1
  %5624 = call i64 @llvm.smax.i64(i64 %5615, i64 1)
  br label %5625

5625:                                             ; preds = %5631, %5613
  %5626 = phi i64 [ 1, %5613 ], [ %5634, %5631 ]
  %5627 = phi <16 x i8> [ %5623, %5613 ], [ %5726, %5631 ]
  %5628 = icmp slt i64 %5626, %5624
  br i1 %5628, label %5629, label %5630

5629:                                             ; preds = %5625
  br label %5631

5630:                                             ; preds = %5625
  br label %5727

5631:                                             ; preds = %5629
  %5632 = icmp eq i64 %5626, %5624
  %5633 = add i64 %5626, 1
  %5634 = select i1 %5632, i64 %5626, i64 %5633
  %5635 = mul i64 %5626, %5618
  %5636 = add i64 %5635, %5620
  %5637 = add i64 %5636, %4334
  %5638 = getelementptr inbounds i8, ptr %5617, i64 %5637
  %5639 = load <16 x i8>, ptr %5638, align 16, !invariant.load !1
  %5640 = bitcast <16 x i8> %5627 to <8 x i16>
  %5641 = extractelement <8 x i16> %5640, i32 0
  %5642 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5641)
  %5643 = insertelement <8 x i32> undef, i32 %5642, i32 0
  %5644 = extractelement <8 x i16> %5640, i32 1
  %5645 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5644)
  %5646 = insertelement <8 x i32> %5643, i32 %5645, i32 1
  %5647 = extractelement <8 x i16> %5640, i32 2
  %5648 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5647)
  %5649 = insertelement <8 x i32> %5646, i32 %5648, i32 2
  %5650 = extractelement <8 x i16> %5640, i32 3
  %5651 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5650)
  %5652 = insertelement <8 x i32> %5649, i32 %5651, i32 3
  %5653 = extractelement <8 x i16> %5640, i32 4
  %5654 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5653)
  %5655 = insertelement <8 x i32> %5652, i32 %5654, i32 4
  %5656 = extractelement <8 x i16> %5640, i32 5
  %5657 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5656)
  %5658 = insertelement <8 x i32> %5655, i32 %5657, i32 5
  %5659 = extractelement <8 x i16> %5640, i32 6
  %5660 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5659)
  %5661 = insertelement <8 x i32> %5658, i32 %5660, i32 6
  %5662 = extractelement <8 x i16> %5640, i32 7
  %5663 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5662)
  %5664 = insertelement <8 x i32> %5661, i32 %5663, i32 7
  %5665 = bitcast <8 x i32> %5664 to <16 x half>
  %5666 = bitcast <16 x i8> %5639 to <8 x i16>
  %5667 = extractelement <8 x i16> %5666, i32 0
  %5668 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5667)
  %5669 = insertelement <8 x i32> undef, i32 %5668, i32 0
  %5670 = extractelement <8 x i16> %5666, i32 1
  %5671 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5670)
  %5672 = insertelement <8 x i32> %5669, i32 %5671, i32 1
  %5673 = extractelement <8 x i16> %5666, i32 2
  %5674 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5673)
  %5675 = insertelement <8 x i32> %5672, i32 %5674, i32 2
  %5676 = extractelement <8 x i16> %5666, i32 3
  %5677 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5676)
  %5678 = insertelement <8 x i32> %5675, i32 %5677, i32 3
  %5679 = extractelement <8 x i16> %5666, i32 4
  %5680 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5679)
  %5681 = insertelement <8 x i32> %5678, i32 %5680, i32 4
  %5682 = extractelement <8 x i16> %5666, i32 5
  %5683 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5682)
  %5684 = insertelement <8 x i32> %5681, i32 %5683, i32 5
  %5685 = extractelement <8 x i16> %5666, i32 6
  %5686 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5685)
  %5687 = insertelement <8 x i32> %5684, i32 %5686, i32 6
  %5688 = extractelement <8 x i16> %5666, i32 7
  %5689 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5688)
  %5690 = insertelement <8 x i32> %5687, i32 %5689, i32 7
  %5691 = bitcast <8 x i32> %5690 to <16 x half>
  %5692 = fadd contract <16 x half> %5665, %5691
  %5693 = fpext <16 x half> %5692 to <16 x float>
  %5694 = extractelement <16 x float> %5693, i32 1
  %5695 = extractelement <16 x float> %5693, i32 0
  %5696 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5694, float %5695)
  %5697 = insertelement <8 x i16> undef, i16 %5696, i32 0
  %5698 = extractelement <16 x float> %5693, i32 3
  %5699 = extractelement <16 x float> %5693, i32 2
  %5700 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5698, float %5699)
  %5701 = insertelement <8 x i16> %5697, i16 %5700, i32 1
  %5702 = extractelement <16 x float> %5693, i32 5
  %5703 = extractelement <16 x float> %5693, i32 4
  %5704 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5702, float %5703)
  %5705 = insertelement <8 x i16> %5701, i16 %5704, i32 2
  %5706 = extractelement <16 x float> %5693, i32 7
  %5707 = extractelement <16 x float> %5693, i32 6
  %5708 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5706, float %5707)
  %5709 = insertelement <8 x i16> %5705, i16 %5708, i32 3
  %5710 = extractelement <16 x float> %5693, i32 9
  %5711 = extractelement <16 x float> %5693, i32 8
  %5712 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5710, float %5711)
  %5713 = insertelement <8 x i16> %5709, i16 %5712, i32 4
  %5714 = extractelement <16 x float> %5693, i32 11
  %5715 = extractelement <16 x float> %5693, i32 10
  %5716 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5714, float %5715)
  %5717 = insertelement <8 x i16> %5713, i16 %5716, i32 5
  %5718 = extractelement <16 x float> %5693, i32 13
  %5719 = extractelement <16 x float> %5693, i32 12
  %5720 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5718, float %5719)
  %5721 = insertelement <8 x i16> %5717, i16 %5720, i32 6
  %5722 = extractelement <16 x float> %5693, i32 15
  %5723 = extractelement <16 x float> %5693, i32 14
  %5724 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %5722, float %5723)
  %5725 = insertelement <8 x i16> %5721, i16 %5724, i32 7
  %5726 = bitcast <8 x i16> %5725 to <16 x i8>
  br label %5625

5727:                                             ; preds = %5630
  %5728 = phi <16 x i8> [ %5627, %5630 ]
  %5729 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5616, 0
  %5730 = getelementptr inbounds i8, ptr %5729, i64 %4341
  store <16 x i8> %5728, ptr %5730, align 16
  br label %5731

5731:                                             ; preds = %5727, %5604
  br label %5733

5732:                                             ; preds = %4314
  br label %5733

5733:                                             ; preds = %5732, %5731
  br label %29

5734:                                             ; preds = %58
  %5735 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %5736 = load i64, ptr %5735, align 8
  %5737 = icmp slt i64 %14, %5736
  br i1 %5737, label %5738, label %5830

5738:                                             ; preds = %5734
  %5739 = load i64, ptr %7, align 8
  %5740 = add i64 %5739, %14
  %5741 = load { i64, i64 }, ptr %6, align 8
  %5742 = trunc i64 %5740 to i32
  %5743 = extractvalue { i64, i64 } %5741, 1
  %5744 = trunc i64 %5743 to i32
  %5745 = icmp eq i32 %5744, 0
  %5746 = select i1 %5745, i32 1, i32 %5744
  %5747 = icmp eq i32 %5746, 0
  %5748 = select i1 %5747, i32 1, i32 %5746
  %5749 = udiv i32 %5742, %5748
  %5750 = select i1 %5747, i32 0, i32 %5749
  %5751 = urem i32 %5742, %5748
  %5752 = select i1 %5747, i32 0, i32 %5751
  %5753 = select i1 %5745, i32 0, i32 %5750
  %5754 = select i1 %5745, i32 0, i32 %5752
  %5755 = zext i32 %5753 to i64
  %5756 = zext i32 %5754 to i64
  %5757 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %5758 = load i64, ptr %4, align 8
  %5759 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %5760 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5757, 0
  %5761 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5757, 1, 1, 0
  %5762 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %5757, 1, 1, 1
  %5763 = mul i64 %5755, %5762
  %5764 = add i64 %5763, %5756
  %5765 = getelementptr inbounds i8, ptr %5760, i64 %5764
  br label %5766

5766:                                             ; preds = %5772, %5738
  %5767 = phi i64 [ 0, %5738 ], [ %5775, %5772 ]
  %5768 = phi i8 [ 0, %5738 ], [ %5777, %5772 ]
  %5769 = icmp slt i64 %5767, 1
  br i1 %5769, label %5770, label %5771

5770:                                             ; preds = %5766
  br label %5772

5771:                                             ; preds = %5766
  br label %5778

5772:                                             ; preds = %5770
  %5773 = icmp eq i64 %5767, 1
  %5774 = add i64 %5767, 1
  %5775 = select i1 %5773, i64 %5767, i64 %5774
  %5776 = getelementptr inbounds i8, ptr %5765, i64 %5767
  %5777 = load i8, ptr %5776, align 1, !invariant.load !1
  br label %5766

5778:                                             ; preds = %5771
  %5779 = phi i8 [ %5768, %5771 ]
  %5780 = call i64 @llvm.smax.i64(i64 %5758, i64 1)
  br label %5781

5781:                                             ; preds = %5807, %5778
  %5782 = phi i64 [ 1, %5778 ], [ %5790, %5807 ]
  %5783 = phi i8 [ %5779, %5778 ], [ %5820, %5807 ]
  %5784 = icmp slt i64 %5782, %5780
  br i1 %5784, label %5785, label %5786

5785:                                             ; preds = %5781
  br label %5787

5786:                                             ; preds = %5781
  br label %5821

5787:                                             ; preds = %5785
  %5788 = icmp eq i64 %5782, %5780
  %5789 = add i64 %5782, 1
  %5790 = select i1 %5788, i64 %5782, i64 %5789
  %5791 = mul i64 %5782, %5761
  %5792 = add i64 %5791, %5763
  %5793 = add i64 %5792, %5756
  %5794 = getelementptr inbounds i8, ptr %5760, i64 %5793
  br label %5795

5795:                                             ; preds = %5801, %5787
  %5796 = phi i64 [ 0, %5787 ], [ %5804, %5801 ]
  %5797 = phi i8 [ 0, %5787 ], [ %5806, %5801 ]
  %5798 = icmp slt i64 %5796, 1
  br i1 %5798, label %5799, label %5800

5799:                                             ; preds = %5795
  br label %5801

5800:                                             ; preds = %5795
  br label %5807

5801:                                             ; preds = %5799
  %5802 = icmp eq i64 %5796, 1
  %5803 = add i64 %5796, 1
  %5804 = select i1 %5802, i64 %5796, i64 %5803
  %5805 = getelementptr inbounds i8, ptr %5794, i64 %5796
  %5806 = load i8, ptr %5805, align 1, !invariant.load !1
  br label %5795

5807:                                             ; preds = %5800
  %5808 = phi i8 [ %5797, %5800 ]
  %5809 = zext i8 %5783 to i16
  %5810 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5809)
  %5811 = trunc i32 %5810 to i16
  %5812 = bitcast i16 %5811 to half
  %5813 = zext i8 %5808 to i16
  %5814 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %5813)
  %5815 = trunc i32 %5814 to i16
  %5816 = bitcast i16 %5815 to half
  %5817 = fadd contract half %5812, %5816
  %5818 = fpext half %5817 to float
  %5819 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %5818)
  %5820 = trunc i16 %5819 to i8
  br label %5781

5821:                                             ; preds = %5786
  %5822 = phi i8 [ %5783, %5786 ]
  %5823 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %5759, 0
  %5824 = trunc i64 %5755 to i32
  %5825 = mul i32 %5824, 512
  %5826 = trunc i64 %5756 to i32
  %5827 = add i32 %5825, %5826
  %5828 = sext i32 %5827 to i64
  %5829 = getelementptr inbounds i8, ptr %5823, i64 %5828
  store i8 %5822, ptr %5829, align 1
  br label %5831

5830:                                             ; preds = %5734
  br label %5831

5831:                                             ; preds = %5830, %5821
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
