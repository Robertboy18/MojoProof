; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x float], align 4
  %14 = alloca [16 x bfloat], align 16
  %15 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %16 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %17 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %18 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %17, 0
  %19 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %17, 1, 1, 0
  %20 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %16, 0
  %21 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %16, 1, 1, 0
  %22 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %15, 0
  %23 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %15, 1, 1, 0
  %24 = sext i32 %4 to i64
  %25 = sext i32 %5 to i64
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %27 = zext i32 %26 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %29 = zext i32 %28 to i64
  %30 = mul i64 %29, 2
  %31 = add i64 %30, 1
  %32 = icmp slt i64 %31, %24
  %33 = icmp slt i64 %30, %24
  %34 = icmp sge i64 %31, %24
  %35 = icmp sge i64 %30, %24
  %36 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %37 = zext i32 %36 to i64
  %38 = mul i64 %37, 8
  %39 = add i64 %23, %38
  call void @llvm.lifetime.start.p0(ptr %14)
  %40 = addrspacecast ptr %14 to ptr addrspace(5)
  %41 = getelementptr inbounds bfloat, ptr addrspace(5) %40, i32 8
  call void @llvm.lifetime.start.p0(ptr %13)
  %42 = addrspacecast ptr %13 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %42, align 4
  %43 = getelementptr inbounds float, ptr addrspace(5) %42, i32 1
  store float 0.000000e+00, ptr addrspace(5) %43, align 4
  br label %44

44:                                               ; preds = %116, %6
  %45 = phi i64 [ %38, %6 ], [ %55, %116 ]
  %46 = phi i64 [ 0, %6 ], [ %56, %116 ]
  %47 = phi i64 [ 0, %6 ], [ %194, %116 ]
  %48 = add i64 %45, 1024
  %49 = icmp slt i64 %48, %45
  %50 = select i1 %49, i64 1, i64 0
  %51 = icmp sge i64 %45, %25
  %52 = icmp eq i64 %46, 0
  %53 = xor i1 %52, true
  %54 = or i1 %53, %51
  %55 = select i1 %54, i64 %45, i64 %48
  %56 = select i1 %54, i64 %46, i64 %50
  br i1 %54, label %57, label %93

57:                                               ; preds = %44
  %58 = udiv i64 %37, 32
  %59 = mul i64 %58, 2
  %60 = trunc i64 %59 to i32
  %61 = sext i32 %60 to i64
  %62 = add i64 %59, 1
  %63 = trunc i64 %62 to i32
  %64 = sext i32 %63 to i64
  %65 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %66 = sext i32 %65 to i64
  %67 = trunc i64 %64 to i32
  %68 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %67
  %69 = trunc i64 %61 to i32
  %70 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %69
  %71 = load float, ptr addrspace(5) %42, align 4
  %72 = bitcast float %71 to i32
  %73 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %72, i32 16, i32 31)
  %74 = bitcast i32 %73 to float
  %75 = fadd contract float %71, %74
  %76 = bitcast float %75 to i32
  %77 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %76, i32 8, i32 31)
  %78 = bitcast i32 %77 to float
  %79 = fadd contract float %75, %78
  %80 = bitcast float %79 to i32
  %81 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %80, i32 4, i32 31)
  %82 = bitcast i32 %81 to float
  %83 = fadd contract float %79, %82
  %84 = bitcast float %83 to i32
  %85 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %84, i32 2, i32 31)
  %86 = bitcast i32 %85 to float
  %87 = fadd contract float %83, %86
  %88 = bitcast float %87 to i32
  %89 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %88, i32 1, i32 31)
  %90 = bitcast i32 %89 to float
  %91 = fadd contract float %87, %90
  %92 = icmp eq i64 %66, 0
  br i1 %92, label %195, label %196

93:                                               ; preds = %44
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %29, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %47, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %94 = insertvalue [2 x ptr] undef, ptr %12, 0
  %95 = insertvalue [2 x ptr] %94, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %95, ptr %10, align 8
  %96 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %97 = load ptr, ptr %96, align 8
  %98 = load i64, ptr %97, align 8
  %99 = getelementptr inbounds ptr, ptr %96, i32 1
  %100 = load ptr, ptr %99, align 8
  %101 = load i64, ptr %100, align 8
  %102 = mul i64 %98, 2
  %103 = mul i64 %102, %23
  %104 = mul i64 %101, 1024
  %105 = add i64 %103, %104
  %106 = getelementptr inbounds bfloat, ptr %22, i64 %105
  %107 = getelementptr inbounds bfloat, ptr %106, i64 %39
  %108 = getelementptr inbounds bfloat, ptr %106, i64 %38
  br i1 %35, label %109, label %110

109:                                              ; preds = %93
  br label %112

110:                                              ; preds = %93
  %111 = load <8 x bfloat>, ptr %108, align 16, !invariant.load !1
  store <8 x bfloat> %111, ptr addrspace(5) %40, align 16
  br label %112

112:                                              ; preds = %110, %109
  br i1 %34, label %113, label %114

113:                                              ; preds = %112
  br label %116

114:                                              ; preds = %112
  %115 = load <8 x bfloat>, ptr %107, align 16, !invariant.load !1
  store <8 x bfloat> %115, ptr addrspace(5) %41, align 16
  br label %116

116:                                              ; preds = %114, %113
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %27, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %47, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %117 = insertvalue [2 x ptr] undef, ptr %9, 0
  %118 = insertvalue [2 x ptr] %117, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %118, ptr %7, align 8
  %119 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %120 = load ptr, ptr %119, align 8
  %121 = load i64, ptr %120, align 8
  %122 = getelementptr inbounds ptr, ptr %119, i32 1
  %123 = load ptr, ptr %122, align 8
  %124 = load i64, ptr %123, align 8
  %125 = mul i64 %121, %21
  %126 = mul i64 %124, 1024
  %127 = add i64 %125, %126
  %128 = getelementptr inbounds bfloat, ptr %20, i64 %127
  %129 = getelementptr inbounds bfloat, ptr %128, i64 %38
  %130 = load <8 x bfloat>, ptr %129, align 16, !invariant.load !1
  %131 = load <8 x bfloat>, ptr addrspace(5) %40, align 16
  %132 = load float, ptr addrspace(5) %42, align 4
  %133 = fpext <8 x bfloat> %130 to <8 x float>
  %134 = fpext <8 x bfloat> %131 to <8 x float>
  %135 = extractelement <8 x float> %133, i64 0
  %136 = extractelement <8 x float> %134, i64 0
  %137 = fmul contract float %135, %136
  %138 = fadd contract float %132, %137
  %139 = extractelement <8 x float> %133, i64 1
  %140 = extractelement <8 x float> %134, i64 1
  %141 = fmul contract float %139, %140
  %142 = fadd contract float %138, %141
  %143 = extractelement <8 x float> %133, i64 2
  %144 = extractelement <8 x float> %134, i64 2
  %145 = fmul contract float %143, %144
  %146 = fadd contract float %142, %145
  %147 = extractelement <8 x float> %133, i64 3
  %148 = extractelement <8 x float> %134, i64 3
  %149 = fmul contract float %147, %148
  %150 = fadd contract float %146, %149
  %151 = extractelement <8 x float> %133, i64 4
  %152 = extractelement <8 x float> %134, i64 4
  %153 = fmul contract float %151, %152
  %154 = fadd contract float %150, %153
  %155 = extractelement <8 x float> %133, i64 5
  %156 = extractelement <8 x float> %134, i64 5
  %157 = fmul contract float %155, %156
  %158 = fadd contract float %154, %157
  %159 = extractelement <8 x float> %133, i64 6
  %160 = extractelement <8 x float> %134, i64 6
  %161 = fmul contract float %159, %160
  %162 = fadd contract float %158, %161
  %163 = extractelement <8 x float> %133, i64 7
  %164 = extractelement <8 x float> %134, i64 7
  %165 = fmul contract float %163, %164
  %166 = fadd contract float %162, %165
  store float %166, ptr addrspace(5) %42, align 4
  %167 = load <8 x bfloat>, ptr addrspace(5) %41, align 16
  %168 = load float, ptr addrspace(5) %43, align 4
  %169 = fpext <8 x bfloat> %167 to <8 x float>
  %170 = extractelement <8 x float> %169, i64 0
  %171 = fmul contract float %135, %170
  %172 = fadd contract float %168, %171
  %173 = extractelement <8 x float> %169, i64 1
  %174 = fmul contract float %139, %173
  %175 = fadd contract float %172, %174
  %176 = extractelement <8 x float> %169, i64 2
  %177 = fmul contract float %143, %176
  %178 = fadd contract float %175, %177
  %179 = extractelement <8 x float> %169, i64 3
  %180 = fmul contract float %147, %179
  %181 = fadd contract float %178, %180
  %182 = extractelement <8 x float> %169, i64 4
  %183 = fmul contract float %151, %182
  %184 = fadd contract float %181, %183
  %185 = extractelement <8 x float> %169, i64 5
  %186 = fmul contract float %155, %185
  %187 = fadd contract float %184, %186
  %188 = extractelement <8 x float> %169, i64 6
  %189 = fmul contract float %159, %188
  %190 = fadd contract float %187, %189
  %191 = extractelement <8 x float> %169, i64 7
  %192 = fmul contract float %163, %191
  %193 = fadd contract float %190, %192
  store float %193, ptr addrspace(5) %43, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %194 = add i64 %47, 1
  br label %44

195:                                              ; preds = %57
  store float %91, ptr addrspace(3) %70, align 4
  br label %197

196:                                              ; preds = %57
  br label %197

197:                                              ; preds = %196, %195
  %198 = load float, ptr addrspace(5) %43, align 4
  %199 = bitcast float %198 to i32
  %200 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %199, i32 16, i32 31)
  %201 = bitcast i32 %200 to float
  %202 = fadd contract float %198, %201
  %203 = bitcast float %202 to i32
  %204 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %203, i32 8, i32 31)
  %205 = bitcast i32 %204 to float
  %206 = fadd contract float %202, %205
  %207 = bitcast float %206 to i32
  %208 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %207, i32 4, i32 31)
  %209 = bitcast i32 %208 to float
  %210 = fadd contract float %206, %209
  %211 = bitcast float %210 to i32
  %212 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %211, i32 2, i32 31)
  %213 = bitcast i32 %212 to float
  %214 = fadd contract float %210, %213
  %215 = bitcast float %214 to i32
  %216 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %215, i32 1, i32 31)
  %217 = bitcast i32 %216 to float
  %218 = fadd contract float %214, %217
  br i1 %92, label %219, label %220

219:                                              ; preds = %197
  store float %218, ptr addrspace(3) %68, align 4
  br label %221

220:                                              ; preds = %197
  br label %221

221:                                              ; preds = %220, %219
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %222

222:                                              ; preds = %322, %221
  %223 = phi i64 [ %37, %221 ], [ %232, %322 ]
  %224 = phi i64 [ 0, %221 ], [ %233, %322 ]
  %225 = add i64 %223, 128
  %226 = icmp slt i64 %225, %223
  %227 = select i1 %226, i64 1, i64 0
  %228 = icmp sge i64 %223, 1
  %229 = icmp eq i64 %224, 0
  %230 = xor i1 %229, true
  %231 = or i1 %230, %228
  %232 = select i1 %231, i64 %223, i64 %225
  %233 = select i1 %231, i64 %224, i64 %227
  br i1 %231, label %234, label %235

234:                                              ; preds = %222
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %13)
  ret void

235:                                              ; preds = %222
  %236 = mul i64 %223, 2
  %237 = trunc i64 %236 to i32
  %238 = sext i32 %237 to i64
  %239 = trunc i64 %238 to i32
  %240 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %239
  %241 = load float, ptr addrspace(3) %240, align 4
  %242 = fadd contract float %241, 0.000000e+00
  %243 = insertelement <2 x float> zeroinitializer, float %242, i64 0
  %244 = add i64 %236, 1
  %245 = trunc i64 %244 to i32
  %246 = sext i32 %245 to i64
  %247 = trunc i64 %246 to i32
  %248 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %247
  %249 = load float, ptr addrspace(3) %248, align 4
  %250 = extractelement <2 x float> %243, i64 1
  %251 = fadd contract float %250, %249
  %252 = insertelement <2 x float> %243, float %251, i64 1
  %253 = add i64 %236, 2
  %254 = trunc i64 %253 to i32
  %255 = sext i32 %254 to i64
  %256 = trunc i64 %255 to i32
  %257 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %256
  %258 = load float, ptr addrspace(3) %257, align 4
  %259 = extractelement <2 x float> %252, i64 0
  %260 = fadd contract float %259, %258
  %261 = insertelement <2 x float> %252, float %260, i64 0
  %262 = add i64 %253, 1
  %263 = trunc i64 %262 to i32
  %264 = sext i32 %263 to i64
  %265 = trunc i64 %264 to i32
  %266 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %265
  %267 = load float, ptr addrspace(3) %266, align 4
  %268 = extractelement <2 x float> %261, i64 1
  %269 = fadd contract float %268, %267
  %270 = insertelement <2 x float> %261, float %269, i64 1
  %271 = add i64 %236, 4
  %272 = trunc i64 %271 to i32
  %273 = sext i32 %272 to i64
  %274 = trunc i64 %273 to i32
  %275 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %274
  %276 = load float, ptr addrspace(3) %275, align 4
  %277 = extractelement <2 x float> %270, i64 0
  %278 = fadd contract float %277, %276
  %279 = insertelement <2 x float> %270, float %278, i64 0
  %280 = add i64 %271, 1
  %281 = trunc i64 %280 to i32
  %282 = sext i32 %281 to i64
  %283 = trunc i64 %282 to i32
  %284 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %283
  %285 = load float, ptr addrspace(3) %284, align 4
  %286 = extractelement <2 x float> %279, i64 1
  %287 = fadd contract float %286, %285
  %288 = insertelement <2 x float> %279, float %287, i64 1
  %289 = add i64 %236, 6
  %290 = trunc i64 %289 to i32
  %291 = sext i32 %290 to i64
  %292 = trunc i64 %291 to i32
  %293 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %292
  %294 = load float, ptr addrspace(3) %293, align 4
  %295 = extractelement <2 x float> %288, i64 0
  %296 = fadd contract float %295, %294
  %297 = insertelement <2 x float> %288, float %296, i64 0
  %298 = add i64 %289, 1
  %299 = trunc i64 %298 to i32
  %300 = sext i32 %299 to i64
  %301 = trunc i64 %300 to i32
  %302 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f316f926._global_alloc_0._gpu_shared_mem, i32 %301
  %303 = load float, ptr addrspace(3) %302, align 4
  %304 = extractelement <2 x float> %297, i64 1
  %305 = fadd contract float %304, %303
  %306 = insertelement <2 x float> %297, float %305, i64 1
  %307 = extractelement <2 x float> %306, i64 1
  %308 = fptrunc float %307 to bfloat
  %309 = extractelement <2 x float> %306, i64 0
  %310 = fptrunc float %309 to bfloat
  %311 = add i64 %27, %223
  %312 = mul i64 %311, %19
  %313 = add i64 %312, %31
  %314 = getelementptr inbounds bfloat, ptr %18, i64 %313
  %315 = add i64 %312, %30
  %316 = getelementptr inbounds bfloat, ptr %18, i64 %315
  br i1 %33, label %317, label %318

317:                                              ; preds = %235
  store bfloat %310, ptr %316, align 2
  br label %319

318:                                              ; preds = %235
  br label %319

319:                                              ; preds = %318, %317
  br i1 %32, label %320, label %321

320:                                              ; preds = %319
  store bfloat %308, ptr %314, align 2
  br label %322

321:                                              ; preds = %319
  br label %322

322:                                              ; preds = %321, %320
  br label %222
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
