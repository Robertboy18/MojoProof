; ModuleID = 'test_gemv_pdl_race.mojo'
source_filename = "test_gemv_pdl_race.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x float], align 4
  %14 = alloca [16 x bfloat], align 16
  %15 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %16 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %17 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %18 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %17, 0
  %19 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %16, 0
  %20 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %15, 0
  %21 = sext i32 %5 to i64
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %23 = zext i32 %22 to i64
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %25 = zext i32 %24 to i64
  %26 = mul i64 %25, 2
  %27 = add i64 %26, 1
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %29 = mul i32 %28, 8
  %30 = add i32 %29, 4096
  %31 = sext i32 %30 to i64
  %32 = sext i32 %29 to i64
  %33 = zext i32 %28 to i64
  call void @llvm.lifetime.start.p0(ptr %14)
  %34 = addrspacecast ptr %14 to ptr addrspace(5)
  %35 = getelementptr inbounds bfloat, ptr addrspace(5) %34, i32 8
  call void @llvm.lifetime.start.p0(ptr %13)
  %36 = addrspacecast ptr %13 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %36, align 4
  %37 = getelementptr inbounds float, ptr addrspace(5) %36, i32 1
  store float 0.000000e+00, ptr addrspace(5) %37, align 4
  %38 = mul i64 %33, 8
  br label %39

39:                                               ; preds = %88, %6
  %40 = phi i64 [ %38, %6 ], [ %50, %88 ]
  %41 = phi i64 [ 0, %6 ], [ %51, %88 ]
  %42 = phi i64 [ 0, %6 ], [ %186, %88 ]
  %43 = add i64 %40, 1024
  %44 = icmp slt i64 %43, %40
  %45 = select i1 %44, i64 1, i64 0
  %46 = icmp sge i64 %40, %21
  %47 = icmp eq i64 %41, 0
  %48 = xor i1 %47, true
  %49 = or i1 %48, %46
  %50 = select i1 %49, i64 %40, i64 %43
  %51 = select i1 %49, i64 %41, i64 %45
  br i1 %49, label %52, label %88

52:                                               ; preds = %39
  %53 = udiv i64 %33, 32
  %54 = mul i64 %53, 2
  %55 = trunc i64 %54 to i32
  %56 = sext i32 %55 to i64
  %57 = add i64 %54, 1
  %58 = trunc i64 %57 to i32
  %59 = sext i32 %58 to i64
  %60 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %61 = sext i32 %60 to i64
  %62 = trunc i64 %59 to i32
  %63 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %62
  %64 = trunc i64 %56 to i32
  %65 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %64
  %66 = load float, ptr addrspace(5) %36, align 4
  %67 = bitcast float %66 to i32
  %68 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %67, i32 16, i32 31)
  %69 = bitcast i32 %68 to float
  %70 = fadd contract float %66, %69
  %71 = bitcast float %70 to i32
  %72 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %71, i32 8, i32 31)
  %73 = bitcast i32 %72 to float
  %74 = fadd contract float %70, %73
  %75 = bitcast float %74 to i32
  %76 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %75, i32 4, i32 31)
  %77 = bitcast i32 %76 to float
  %78 = fadd contract float %74, %77
  %79 = bitcast float %78 to i32
  %80 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %79, i32 2, i32 31)
  %81 = bitcast i32 %80 to float
  %82 = fadd contract float %78, %81
  %83 = bitcast float %82 to i32
  %84 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %83, i32 1, i32 31)
  %85 = bitcast i32 %84 to float
  %86 = fadd contract float %82, %85
  %87 = icmp eq i64 %61, 0
  br i1 %87, label %187, label %188

88:                                               ; preds = %39
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %25, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %42, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %89 = insertvalue [2 x ptr] undef, ptr %12, 0
  %90 = insertvalue [2 x ptr] %89, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %90, ptr %10, align 8
  %91 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %92 = load ptr, ptr %91, align 8
  %93 = load i64, ptr %92, align 8
  %94 = trunc i64 %93 to i32
  %95 = getelementptr inbounds ptr, ptr %91, i32 1
  %96 = load ptr, ptr %95, align 8
  %97 = load i64, ptr %96, align 8
  %98 = trunc i64 %97 to i32
  %99 = mul i32 %94, 2
  %100 = mul i32 %99, 4096
  %101 = mul i32 %98, 1024
  %102 = add i32 %100, %101
  %103 = sext i32 %102 to i64
  %104 = getelementptr inbounds bfloat, ptr %20, i64 %103
  %105 = getelementptr inbounds bfloat, ptr %104, i64 %32
  %106 = load <8 x bfloat>, ptr %105, align 16, !invariant.load !1
  store <8 x bfloat> %106, ptr addrspace(5) %34, align 16
  %107 = getelementptr inbounds bfloat, ptr %104, i64 %31
  %108 = load <8 x bfloat>, ptr %107, align 16, !invariant.load !1
  store <8 x bfloat> %108, ptr addrspace(5) %35, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %23, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %42, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %109 = insertvalue [2 x ptr] undef, ptr %9, 0
  %110 = insertvalue [2 x ptr] %109, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %110, ptr %7, align 8
  %111 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %112 = load ptr, ptr %111, align 8
  %113 = load i64, ptr %112, align 8
  %114 = getelementptr inbounds ptr, ptr %111, i32 1
  %115 = load ptr, ptr %114, align 8
  %116 = load i64, ptr %115, align 8
  %117 = mul i64 %113, 4096
  %118 = mul i64 %116, 1024
  %119 = add i64 %117, %118
  %120 = getelementptr inbounds bfloat, ptr %19, i64 %119
  %121 = getelementptr inbounds bfloat, ptr %120, i64 %32
  %122 = load <8 x bfloat>, ptr %121, align 16, !invariant.load !1
  %123 = load <8 x bfloat>, ptr addrspace(5) %34, align 16
  %124 = load float, ptr addrspace(5) %36, align 4
  %125 = fpext <8 x bfloat> %122 to <8 x float>
  %126 = fpext <8 x bfloat> %123 to <8 x float>
  %127 = extractelement <8 x float> %125, i64 0
  %128 = extractelement <8 x float> %126, i64 0
  %129 = fmul contract float %127, %128
  %130 = fadd contract float %124, %129
  %131 = extractelement <8 x float> %125, i64 1
  %132 = extractelement <8 x float> %126, i64 1
  %133 = fmul contract float %131, %132
  %134 = fadd contract float %130, %133
  %135 = extractelement <8 x float> %125, i64 2
  %136 = extractelement <8 x float> %126, i64 2
  %137 = fmul contract float %135, %136
  %138 = fadd contract float %134, %137
  %139 = extractelement <8 x float> %125, i64 3
  %140 = extractelement <8 x float> %126, i64 3
  %141 = fmul contract float %139, %140
  %142 = fadd contract float %138, %141
  %143 = extractelement <8 x float> %125, i64 4
  %144 = extractelement <8 x float> %126, i64 4
  %145 = fmul contract float %143, %144
  %146 = fadd contract float %142, %145
  %147 = extractelement <8 x float> %125, i64 5
  %148 = extractelement <8 x float> %126, i64 5
  %149 = fmul contract float %147, %148
  %150 = fadd contract float %146, %149
  %151 = extractelement <8 x float> %125, i64 6
  %152 = extractelement <8 x float> %126, i64 6
  %153 = fmul contract float %151, %152
  %154 = fadd contract float %150, %153
  %155 = extractelement <8 x float> %125, i64 7
  %156 = extractelement <8 x float> %126, i64 7
  %157 = fmul contract float %155, %156
  %158 = fadd contract float %154, %157
  store float %158, ptr addrspace(5) %36, align 4
  %159 = load <8 x bfloat>, ptr addrspace(5) %35, align 16
  %160 = load float, ptr addrspace(5) %37, align 4
  %161 = fpext <8 x bfloat> %159 to <8 x float>
  %162 = extractelement <8 x float> %161, i64 0
  %163 = fmul contract float %127, %162
  %164 = fadd contract float %160, %163
  %165 = extractelement <8 x float> %161, i64 1
  %166 = fmul contract float %131, %165
  %167 = fadd contract float %164, %166
  %168 = extractelement <8 x float> %161, i64 2
  %169 = fmul contract float %135, %168
  %170 = fadd contract float %167, %169
  %171 = extractelement <8 x float> %161, i64 3
  %172 = fmul contract float %139, %171
  %173 = fadd contract float %170, %172
  %174 = extractelement <8 x float> %161, i64 4
  %175 = fmul contract float %143, %174
  %176 = fadd contract float %173, %175
  %177 = extractelement <8 x float> %161, i64 5
  %178 = fmul contract float %147, %177
  %179 = fadd contract float %176, %178
  %180 = extractelement <8 x float> %161, i64 6
  %181 = fmul contract float %151, %180
  %182 = fadd contract float %179, %181
  %183 = extractelement <8 x float> %161, i64 7
  %184 = fmul contract float %155, %183
  %185 = fadd contract float %182, %184
  store float %185, ptr addrspace(5) %37, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %186 = add i64 %42, 1
  br label %39

187:                                              ; preds = %52
  store float %86, ptr addrspace(3) %65, align 4
  br label %189

188:                                              ; preds = %52
  br label %189

189:                                              ; preds = %188, %187
  %190 = load float, ptr addrspace(5) %37, align 4
  %191 = bitcast float %190 to i32
  %192 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %191, i32 16, i32 31)
  %193 = bitcast i32 %192 to float
  %194 = fadd contract float %190, %193
  %195 = bitcast float %194 to i32
  %196 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %195, i32 8, i32 31)
  %197 = bitcast i32 %196 to float
  %198 = fadd contract float %194, %197
  %199 = bitcast float %198 to i32
  %200 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %199, i32 4, i32 31)
  %201 = bitcast i32 %200 to float
  %202 = fadd contract float %198, %201
  %203 = bitcast float %202 to i32
  %204 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %203, i32 2, i32 31)
  %205 = bitcast i32 %204 to float
  %206 = fadd contract float %202, %205
  %207 = bitcast float %206 to i32
  %208 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %207, i32 1, i32 31)
  %209 = bitcast i32 %208 to float
  %210 = fadd contract float %206, %209
  br i1 %87, label %211, label %212

211:                                              ; preds = %189
  store float %210, ptr addrspace(3) %63, align 4
  br label %213

212:                                              ; preds = %189
  br label %213

213:                                              ; preds = %212, %211
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %214

214:                                              ; preds = %227, %213
  %215 = phi i64 [ %33, %213 ], [ %224, %227 ]
  %216 = phi i64 [ 0, %213 ], [ %225, %227 ]
  %217 = add i64 %215, 128
  %218 = icmp slt i64 %217, %215
  %219 = select i1 %218, i64 1, i64 0
  %220 = icmp sge i64 %215, 1
  %221 = icmp eq i64 %216, 0
  %222 = xor i1 %221, true
  %223 = or i1 %222, %220
  %224 = select i1 %223, i64 %215, i64 %217
  %225 = select i1 %223, i64 %216, i64 %219
  br i1 %223, label %226, label %227

226:                                              ; preds = %214
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %13)
  ret void

227:                                              ; preds = %214
  %228 = mul i64 %215, 2
  %229 = trunc i64 %228 to i32
  %230 = sext i32 %229 to i64
  %231 = trunc i64 %230 to i32
  %232 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %231
  %233 = load float, ptr addrspace(3) %232, align 4
  %234 = fadd contract float %233, 0.000000e+00
  %235 = insertelement <2 x float> zeroinitializer, float %234, i64 0
  %236 = add i64 %228, 1
  %237 = trunc i64 %236 to i32
  %238 = sext i32 %237 to i64
  %239 = trunc i64 %238 to i32
  %240 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %239
  %241 = load float, ptr addrspace(3) %240, align 4
  %242 = extractelement <2 x float> %235, i64 1
  %243 = fadd contract float %242, %241
  %244 = insertelement <2 x float> %235, float %243, i64 1
  %245 = add i64 %228, 2
  %246 = trunc i64 %245 to i32
  %247 = sext i32 %246 to i64
  %248 = trunc i64 %247 to i32
  %249 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %248
  %250 = load float, ptr addrspace(3) %249, align 4
  %251 = extractelement <2 x float> %244, i64 0
  %252 = fadd contract float %251, %250
  %253 = insertelement <2 x float> %244, float %252, i64 0
  %254 = add i64 %245, 1
  %255 = trunc i64 %254 to i32
  %256 = sext i32 %255 to i64
  %257 = trunc i64 %256 to i32
  %258 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %257
  %259 = load float, ptr addrspace(3) %258, align 4
  %260 = extractelement <2 x float> %253, i64 1
  %261 = fadd contract float %260, %259
  %262 = insertelement <2 x float> %253, float %261, i64 1
  %263 = add i64 %228, 4
  %264 = trunc i64 %263 to i32
  %265 = sext i32 %264 to i64
  %266 = trunc i64 %265 to i32
  %267 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %266
  %268 = load float, ptr addrspace(3) %267, align 4
  %269 = extractelement <2 x float> %262, i64 0
  %270 = fadd contract float %269, %268
  %271 = insertelement <2 x float> %262, float %270, i64 0
  %272 = add i64 %263, 1
  %273 = trunc i64 %272 to i32
  %274 = sext i32 %273 to i64
  %275 = trunc i64 %274 to i32
  %276 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %275
  %277 = load float, ptr addrspace(3) %276, align 4
  %278 = extractelement <2 x float> %271, i64 1
  %279 = fadd contract float %278, %277
  %280 = insertelement <2 x float> %271, float %279, i64 1
  %281 = add i64 %228, 6
  %282 = trunc i64 %281 to i32
  %283 = sext i32 %282 to i64
  %284 = trunc i64 %283 to i32
  %285 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %284
  %286 = load float, ptr addrspace(3) %285, align 4
  %287 = extractelement <2 x float> %280, i64 0
  %288 = fadd contract float %287, %286
  %289 = insertelement <2 x float> %280, float %288, i64 0
  %290 = add i64 %281, 1
  %291 = trunc i64 %290 to i32
  %292 = sext i32 %291 to i64
  %293 = trunc i64 %292 to i32
  %294 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_f4b4bc44._global_alloc_0._gpu_shared_mem, i32 %293
  %295 = load float, ptr addrspace(3) %294, align 4
  %296 = extractelement <2 x float> %289, i64 1
  %297 = fadd contract float %296, %295
  %298 = insertelement <2 x float> %289, float %297, i64 1
  %299 = add i64 %23, %215
  %300 = fptrunc <2 x float> %298 to <2 x bfloat>
  %301 = extractelement <2 x bfloat> %300, i64 0
  %302 = mul i64 %299, 8192
  %303 = add i64 %302, %26
  %304 = getelementptr inbounds bfloat, ptr %18, i64 %303
  store bfloat %301, ptr %304, align 2
  %305 = extractelement <2 x bfloat> %300, i64 1
  %306 = add i64 %302, %27
  %307 = getelementptr inbounds bfloat, ptr %18, i64 %306
  store bfloat %305, ptr %307, align 2
  br label %214
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
