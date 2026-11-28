; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, { i64, i64, i64, {} } noundef %6) #0 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca [2 x ptr], i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca i64, i64 1, align 8
  %14 = alloca [2 x float], align 4
  %15 = alloca [16 x bfloat], align 16
  %16 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %17 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %18 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %19 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %18, 0
  %20 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %18, 1, 1, 0
  %21 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %17, 0
  %22 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %17, 1, 1, 0
  %23 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %16, 0
  %24 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %16, 1, 1, 0
  %25 = sext i32 %4 to i64
  %26 = sext i32 %5 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = mul i64 %30, 2
  %32 = add i64 %31, 1
  %33 = icmp slt i64 %32, %25
  %34 = icmp slt i64 %31, %25
  %35 = icmp sge i64 %32, %25
  %36 = icmp sge i64 %31, %25
  %37 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %38 = zext i32 %37 to i64
  %39 = mul i64 %38, 8
  %40 = add i64 %24, %39
  call void @llvm.lifetime.start.p0(ptr %15)
  %41 = addrspacecast ptr %15 to ptr addrspace(5)
  %42 = getelementptr inbounds bfloat, ptr addrspace(5) %41, i32 8
  call void @llvm.lifetime.start.p0(ptr %14)
  %43 = addrspacecast ptr %14 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %43, align 4
  %44 = getelementptr inbounds float, ptr addrspace(5) %43, i32 1
  store float 0.000000e+00, ptr addrspace(5) %44, align 4
  br label %45

45:                                               ; preds = %117, %7
  %46 = phi i64 [ %39, %7 ], [ %56, %117 ]
  %47 = phi i64 [ 0, %7 ], [ %57, %117 ]
  %48 = phi i64 [ 0, %7 ], [ %195, %117 ]
  %49 = add i64 %46, 1024
  %50 = icmp slt i64 %49, %46
  %51 = select i1 %50, i64 1, i64 0
  %52 = icmp sge i64 %46, %26
  %53 = icmp eq i64 %47, 0
  %54 = xor i1 %53, true
  %55 = or i1 %54, %52
  %56 = select i1 %55, i64 %46, i64 %49
  %57 = select i1 %55, i64 %47, i64 %51
  br i1 %55, label %58, label %94

58:                                               ; preds = %45
  %59 = udiv i64 %38, 32
  %60 = mul i64 %59, 2
  %61 = trunc i64 %60 to i32
  %62 = sext i32 %61 to i64
  %63 = add i64 %60, 1
  %64 = trunc i64 %63 to i32
  %65 = sext i32 %64 to i64
  %66 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %67 = sext i32 %66 to i64
  %68 = trunc i64 %65 to i32
  %69 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %68
  %70 = trunc i64 %62 to i32
  %71 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %70
  %72 = load float, ptr addrspace(5) %43, align 4
  %73 = bitcast float %72 to i32
  %74 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %73, i32 16, i32 31)
  %75 = bitcast i32 %74 to float
  %76 = fadd contract float %72, %75
  %77 = bitcast float %76 to i32
  %78 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %77, i32 8, i32 31)
  %79 = bitcast i32 %78 to float
  %80 = fadd contract float %76, %79
  %81 = bitcast float %80 to i32
  %82 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %81, i32 4, i32 31)
  %83 = bitcast i32 %82 to float
  %84 = fadd contract float %80, %83
  %85 = bitcast float %84 to i32
  %86 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %85, i32 2, i32 31)
  %87 = bitcast i32 %86 to float
  %88 = fadd contract float %84, %87
  %89 = bitcast float %88 to i32
  %90 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %89, i32 1, i32 31)
  %91 = bitcast i32 %90 to float
  %92 = fadd contract float %88, %91
  %93 = icmp eq i64 %67, 0
  br i1 %93, label %196, label %197

94:                                               ; preds = %45
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %30, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %48, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %95 = insertvalue [2 x ptr] undef, ptr %13, 0
  %96 = insertvalue [2 x ptr] %95, ptr %12, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %96, ptr %11, align 8
  %97 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %98 = load ptr, ptr %97, align 8
  %99 = load i64, ptr %98, align 8
  %100 = getelementptr inbounds ptr, ptr %97, i32 1
  %101 = load ptr, ptr %100, align 8
  %102 = load i64, ptr %101, align 8
  %103 = mul i64 %99, 2
  %104 = mul i64 %103, %24
  %105 = mul i64 %102, 1024
  %106 = add i64 %104, %105
  %107 = getelementptr inbounds bfloat, ptr %23, i64 %106
  %108 = getelementptr inbounds bfloat, ptr %107, i64 %40
  %109 = getelementptr inbounds bfloat, ptr %107, i64 %39
  br i1 %36, label %110, label %111

110:                                              ; preds = %94
  br label %113

111:                                              ; preds = %94
  %112 = load <8 x bfloat>, ptr %109, align 16, !invariant.load !1
  store <8 x bfloat> %112, ptr addrspace(5) %41, align 16
  br label %113

113:                                              ; preds = %111, %110
  br i1 %35, label %114, label %115

114:                                              ; preds = %113
  br label %117

115:                                              ; preds = %113
  %116 = load <8 x bfloat>, ptr %108, align 16, !invariant.load !1
  store <8 x bfloat> %116, ptr addrspace(5) %42, align 16
  br label %117

117:                                              ; preds = %115, %114
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %28, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %48, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %118 = insertvalue [2 x ptr] undef, ptr %10, 0
  %119 = insertvalue [2 x ptr] %118, ptr %9, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %119, ptr %8, align 8
  %120 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %121 = load ptr, ptr %120, align 8
  %122 = load i64, ptr %121, align 8
  %123 = getelementptr inbounds ptr, ptr %120, i32 1
  %124 = load ptr, ptr %123, align 8
  %125 = load i64, ptr %124, align 8
  %126 = mul i64 %122, %22
  %127 = mul i64 %125, 1024
  %128 = add i64 %126, %127
  %129 = getelementptr inbounds bfloat, ptr %21, i64 %128
  %130 = getelementptr inbounds bfloat, ptr %129, i64 %39
  %131 = load <8 x bfloat>, ptr %130, align 16, !invariant.load !1
  %132 = load <8 x bfloat>, ptr addrspace(5) %41, align 16
  %133 = load float, ptr addrspace(5) %43, align 4
  %134 = fpext <8 x bfloat> %131 to <8 x float>
  %135 = fpext <8 x bfloat> %132 to <8 x float>
  %136 = extractelement <8 x float> %134, i64 0
  %137 = extractelement <8 x float> %135, i64 0
  %138 = fmul contract float %136, %137
  %139 = fadd contract float %133, %138
  %140 = extractelement <8 x float> %134, i64 1
  %141 = extractelement <8 x float> %135, i64 1
  %142 = fmul contract float %140, %141
  %143 = fadd contract float %139, %142
  %144 = extractelement <8 x float> %134, i64 2
  %145 = extractelement <8 x float> %135, i64 2
  %146 = fmul contract float %144, %145
  %147 = fadd contract float %143, %146
  %148 = extractelement <8 x float> %134, i64 3
  %149 = extractelement <8 x float> %135, i64 3
  %150 = fmul contract float %148, %149
  %151 = fadd contract float %147, %150
  %152 = extractelement <8 x float> %134, i64 4
  %153 = extractelement <8 x float> %135, i64 4
  %154 = fmul contract float %152, %153
  %155 = fadd contract float %151, %154
  %156 = extractelement <8 x float> %134, i64 5
  %157 = extractelement <8 x float> %135, i64 5
  %158 = fmul contract float %156, %157
  %159 = fadd contract float %155, %158
  %160 = extractelement <8 x float> %134, i64 6
  %161 = extractelement <8 x float> %135, i64 6
  %162 = fmul contract float %160, %161
  %163 = fadd contract float %159, %162
  %164 = extractelement <8 x float> %134, i64 7
  %165 = extractelement <8 x float> %135, i64 7
  %166 = fmul contract float %164, %165
  %167 = fadd contract float %163, %166
  store float %167, ptr addrspace(5) %43, align 4
  %168 = load <8 x bfloat>, ptr addrspace(5) %42, align 16
  %169 = load float, ptr addrspace(5) %44, align 4
  %170 = fpext <8 x bfloat> %168 to <8 x float>
  %171 = extractelement <8 x float> %170, i64 0
  %172 = fmul contract float %136, %171
  %173 = fadd contract float %169, %172
  %174 = extractelement <8 x float> %170, i64 1
  %175 = fmul contract float %140, %174
  %176 = fadd contract float %173, %175
  %177 = extractelement <8 x float> %170, i64 2
  %178 = fmul contract float %144, %177
  %179 = fadd contract float %176, %178
  %180 = extractelement <8 x float> %170, i64 3
  %181 = fmul contract float %148, %180
  %182 = fadd contract float %179, %181
  %183 = extractelement <8 x float> %170, i64 4
  %184 = fmul contract float %152, %183
  %185 = fadd contract float %182, %184
  %186 = extractelement <8 x float> %170, i64 5
  %187 = fmul contract float %156, %186
  %188 = fadd contract float %185, %187
  %189 = extractelement <8 x float> %170, i64 6
  %190 = fmul contract float %160, %189
  %191 = fadd contract float %188, %190
  %192 = extractelement <8 x float> %170, i64 7
  %193 = fmul contract float %164, %192
  %194 = fadd contract float %191, %193
  store float %194, ptr addrspace(5) %44, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %195 = add i64 %48, 1
  br label %45

196:                                              ; preds = %58
  store float %92, ptr addrspace(3) %71, align 4
  br label %198

197:                                              ; preds = %58
  br label %198

198:                                              ; preds = %197, %196
  %199 = load float, ptr addrspace(5) %44, align 4
  %200 = bitcast float %199 to i32
  %201 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %200, i32 16, i32 31)
  %202 = bitcast i32 %201 to float
  %203 = fadd contract float %199, %202
  %204 = bitcast float %203 to i32
  %205 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %204, i32 8, i32 31)
  %206 = bitcast i32 %205 to float
  %207 = fadd contract float %203, %206
  %208 = bitcast float %207 to i32
  %209 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %208, i32 4, i32 31)
  %210 = bitcast i32 %209 to float
  %211 = fadd contract float %207, %210
  %212 = bitcast float %211 to i32
  %213 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %212, i32 2, i32 31)
  %214 = bitcast i32 %213 to float
  %215 = fadd contract float %211, %214
  %216 = bitcast float %215 to i32
  %217 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %216, i32 1, i32 31)
  %218 = bitcast i32 %217 to float
  %219 = fadd contract float %215, %218
  br i1 %93, label %220, label %221

220:                                              ; preds = %198
  store float %219, ptr addrspace(3) %69, align 4
  br label %222

221:                                              ; preds = %198
  br label %222

222:                                              ; preds = %221, %220
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %223

223:                                              ; preds = %329, %222
  %224 = phi i64 [ %38, %222 ], [ %233, %329 ]
  %225 = phi i64 [ 0, %222 ], [ %234, %329 ]
  %226 = add i64 %224, 128
  %227 = icmp slt i64 %226, %224
  %228 = select i1 %227, i64 1, i64 0
  %229 = icmp sge i64 %224, 1
  %230 = icmp eq i64 %225, 0
  %231 = xor i1 %230, true
  %232 = or i1 %231, %229
  %233 = select i1 %232, i64 %224, i64 %226
  %234 = select i1 %232, i64 %225, i64 %228
  br i1 %232, label %235, label %236

235:                                              ; preds = %223
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %14)
  ret void

236:                                              ; preds = %223
  %237 = mul i64 %224, 2
  %238 = trunc i64 %237 to i32
  %239 = sext i32 %238 to i64
  %240 = trunc i64 %239 to i32
  %241 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %240
  %242 = load float, ptr addrspace(3) %241, align 4
  %243 = fadd contract float %242, 0.000000e+00
  %244 = insertelement <2 x float> zeroinitializer, float %243, i64 0
  %245 = add i64 %237, 1
  %246 = trunc i64 %245 to i32
  %247 = sext i32 %246 to i64
  %248 = trunc i64 %247 to i32
  %249 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %248
  %250 = load float, ptr addrspace(3) %249, align 4
  %251 = extractelement <2 x float> %244, i64 1
  %252 = fadd contract float %251, %250
  %253 = insertelement <2 x float> %244, float %252, i64 1
  %254 = add i64 %237, 2
  %255 = trunc i64 %254 to i32
  %256 = sext i32 %255 to i64
  %257 = trunc i64 %256 to i32
  %258 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %257
  %259 = load float, ptr addrspace(3) %258, align 4
  %260 = extractelement <2 x float> %253, i64 0
  %261 = fadd contract float %260, %259
  %262 = insertelement <2 x float> %253, float %261, i64 0
  %263 = add i64 %254, 1
  %264 = trunc i64 %263 to i32
  %265 = sext i32 %264 to i64
  %266 = trunc i64 %265 to i32
  %267 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %266
  %268 = load float, ptr addrspace(3) %267, align 4
  %269 = extractelement <2 x float> %262, i64 1
  %270 = fadd contract float %269, %268
  %271 = insertelement <2 x float> %262, float %270, i64 1
  %272 = add i64 %237, 4
  %273 = trunc i64 %272 to i32
  %274 = sext i32 %273 to i64
  %275 = trunc i64 %274 to i32
  %276 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %275
  %277 = load float, ptr addrspace(3) %276, align 4
  %278 = extractelement <2 x float> %271, i64 0
  %279 = fadd contract float %278, %277
  %280 = insertelement <2 x float> %271, float %279, i64 0
  %281 = add i64 %272, 1
  %282 = trunc i64 %281 to i32
  %283 = sext i32 %282 to i64
  %284 = trunc i64 %283 to i32
  %285 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %284
  %286 = load float, ptr addrspace(3) %285, align 4
  %287 = extractelement <2 x float> %280, i64 1
  %288 = fadd contract float %287, %286
  %289 = insertelement <2 x float> %280, float %288, i64 1
  %290 = add i64 %237, 6
  %291 = trunc i64 %290 to i32
  %292 = sext i32 %291 to i64
  %293 = trunc i64 %292 to i32
  %294 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %293
  %295 = load float, ptr addrspace(3) %294, align 4
  %296 = extractelement <2 x float> %289, i64 0
  %297 = fadd contract float %296, %295
  %298 = insertelement <2 x float> %289, float %297, i64 0
  %299 = add i64 %290, 1
  %300 = trunc i64 %299 to i32
  %301 = sext i32 %300 to i64
  %302 = trunc i64 %301 to i32
  %303 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_bfloat16_bfloat16_bfloat16_128_12802c3e._global_alloc_0._gpu_shared_mem, i32 %302
  %304 = load float, ptr addrspace(3) %303, align 4
  %305 = extractelement <2 x float> %298, i64 1
  %306 = fadd contract float %305, %304
  %307 = insertelement <2 x float> %298, float %306, i64 1
  %308 = extractelement <2 x float> %307, i64 1
  %309 = fptrunc float %308 to bfloat
  %310 = fpext bfloat %309 to float
  %311 = fmul contract float %310, 2.000000e+00
  %312 = fptrunc float %311 to bfloat
  %313 = extractelement <2 x float> %307, i64 0
  %314 = fptrunc float %313 to bfloat
  %315 = fpext bfloat %314 to float
  %316 = fmul contract float %315, 2.000000e+00
  %317 = fptrunc float %316 to bfloat
  %318 = add i64 %28, %224
  %319 = mul i64 %318, %20
  %320 = add i64 %319, %32
  %321 = getelementptr inbounds bfloat, ptr %19, i64 %320
  %322 = add i64 %319, %31
  %323 = getelementptr inbounds bfloat, ptr %19, i64 %322
  br i1 %34, label %324, label %325

324:                                              ; preds = %236
  store bfloat %317, ptr %323, align 2
  br label %326

325:                                              ; preds = %236
  br label %326

326:                                              ; preds = %325, %324
  br i1 %33, label %327, label %328

327:                                              ; preds = %326
  store bfloat %312, ptr %321, align 2
  br label %329

328:                                              ; preds = %326
  br label %329

329:                                              ; preds = %328, %327
  br label %223
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #3

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #4

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #4 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
