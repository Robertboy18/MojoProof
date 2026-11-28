; ModuleID = 'test_matmul_epilogue_fn_sm100_dispatch.mojo'
source_filename = "test_matmul_epilogue_fn_sm100_dispatch.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %6) #1 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca [2 x ptr], i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca i64, i64 1, align 8
  %14 = alloca [2 x ptr], i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca i64, i64 1, align 8
  %17 = alloca [2 x ptr], i64 1, align 8
  %18 = alloca i64, i64 1, align 8
  %19 = alloca i64, i64 1, align 8
  %20 = alloca [2 x float], align 4
  %21 = alloca [16 x bfloat], align 16
  %22 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %23 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %24 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %23, 0
  %25 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %22, 0
  %26 = sext i32 %5 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = mul i64 %30, 2
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %33 = mul i32 %32, 8
  %34 = add i32 %33, 7168
  %35 = sext i32 %34 to i64
  %36 = sext i32 %33 to i64
  %37 = zext i32 %32 to i64
  call void @llvm.lifetime.start.p0(ptr %21)
  %38 = addrspacecast ptr %21 to ptr addrspace(5)
  %39 = getelementptr inbounds bfloat, ptr addrspace(5) %38, i32 8
  call void @llvm.lifetime.start.p0(ptr %20)
  %40 = addrspacecast ptr %20 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %40, align 4
  %41 = getelementptr inbounds float, ptr addrspace(5) %40, i32 1
  store float 0.000000e+00, ptr addrspace(5) %41, align 4
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  %42 = mul i64 %37, 8
  %43 = icmp slt i64 %42, %26
  br i1 %43, label %44, label %65

44:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %30, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 0, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  %45 = insertvalue [2 x ptr] undef, ptr %19, 0
  %46 = insertvalue [2 x ptr] %45, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %17)
  store [2 x ptr] %46, ptr %17, align 8
  %47 = getelementptr inbounds [2 x ptr], ptr %17, i32 0, i32 0
  %48 = load ptr, ptr %47, align 8
  %49 = load i64, ptr %48, align 8
  %50 = trunc i64 %49 to i32
  %51 = getelementptr inbounds ptr, ptr %47, i32 1
  %52 = load ptr, ptr %51, align 8
  %53 = load i64, ptr %52, align 8
  %54 = trunc i64 %53 to i32
  %55 = mul i32 %50, 2
  %56 = mul i32 %55, 7168
  %57 = mul i32 %54, 1024
  %58 = add i32 %56, %57
  %59 = sext i32 %58 to i64
  %60 = getelementptr inbounds bfloat, ptr %25, i64 %59
  %61 = getelementptr inbounds bfloat, ptr %60, i64 %36
  %62 = load <8 x bfloat>, ptr %61, align 16, !invariant.load !1
  store <8 x bfloat> %62, ptr addrspace(5) %38, align 16
  %63 = getelementptr inbounds bfloat, ptr %60, i64 %35
  %64 = load <8 x bfloat>, ptr %63, align 16, !invariant.load !1
  store <8 x bfloat> %64, ptr addrspace(5) %39, align 16
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  br label %66

65:                                               ; preds = %7
  br label %66

66:                                               ; preds = %65, %44
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %67 = select i1 %43, i64 1, i64 0
  br i1 %43, label %68, label %146

68:                                               ; preds = %66
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 %28, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 0, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %69 = insertvalue [2 x ptr] undef, ptr %16, 0
  %70 = insertvalue [2 x ptr] %69, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %70, ptr %14, align 8
  %71 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %72 = load ptr, ptr %71, align 8
  %73 = load i64, ptr %72, align 8
  %74 = getelementptr inbounds ptr, ptr %71, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = load i64, ptr %75, align 8
  %77 = mul i64 %73, 7168
  %78 = mul i64 %76, 1024
  %79 = add i64 %77, %78
  %80 = getelementptr inbounds bfloat, ptr %24, i64 %79
  %81 = getelementptr inbounds bfloat, ptr %80, i64 %36
  %82 = load <8 x bfloat>, ptr %81, align 16, !invariant.load !1
  %83 = load <8 x bfloat>, ptr addrspace(5) %38, align 16
  %84 = load float, ptr addrspace(5) %40, align 4
  %85 = fpext <8 x bfloat> %82 to <8 x float>
  %86 = fpext <8 x bfloat> %83 to <8 x float>
  %87 = extractelement <8 x float> %85, i64 0
  %88 = extractelement <8 x float> %86, i64 0
  %89 = fmul contract float %87, %88
  %90 = fadd contract float %84, %89
  %91 = extractelement <8 x float> %85, i64 1
  %92 = extractelement <8 x float> %86, i64 1
  %93 = fmul contract float %91, %92
  %94 = fadd contract float %90, %93
  %95 = extractelement <8 x float> %85, i64 2
  %96 = extractelement <8 x float> %86, i64 2
  %97 = fmul contract float %95, %96
  %98 = fadd contract float %94, %97
  %99 = extractelement <8 x float> %85, i64 3
  %100 = extractelement <8 x float> %86, i64 3
  %101 = fmul contract float %99, %100
  %102 = fadd contract float %98, %101
  %103 = extractelement <8 x float> %85, i64 4
  %104 = extractelement <8 x float> %86, i64 4
  %105 = fmul contract float %103, %104
  %106 = fadd contract float %102, %105
  %107 = extractelement <8 x float> %85, i64 5
  %108 = extractelement <8 x float> %86, i64 5
  %109 = fmul contract float %107, %108
  %110 = fadd contract float %106, %109
  %111 = extractelement <8 x float> %85, i64 6
  %112 = extractelement <8 x float> %86, i64 6
  %113 = fmul contract float %111, %112
  %114 = fadd contract float %110, %113
  %115 = extractelement <8 x float> %85, i64 7
  %116 = extractelement <8 x float> %86, i64 7
  %117 = fmul contract float %115, %116
  %118 = fadd contract float %114, %117
  store float %118, ptr addrspace(5) %40, align 4
  %119 = load <8 x bfloat>, ptr addrspace(5) %39, align 16
  %120 = load float, ptr addrspace(5) %41, align 4
  %121 = fpext <8 x bfloat> %119 to <8 x float>
  %122 = extractelement <8 x float> %121, i64 0
  %123 = fmul contract float %87, %122
  %124 = fadd contract float %120, %123
  %125 = extractelement <8 x float> %121, i64 1
  %126 = fmul contract float %91, %125
  %127 = fadd contract float %124, %126
  %128 = extractelement <8 x float> %121, i64 2
  %129 = fmul contract float %95, %128
  %130 = fadd contract float %127, %129
  %131 = extractelement <8 x float> %121, i64 3
  %132 = fmul contract float %99, %131
  %133 = fadd contract float %130, %132
  %134 = extractelement <8 x float> %121, i64 4
  %135 = fmul contract float %103, %134
  %136 = fadd contract float %133, %135
  %137 = extractelement <8 x float> %121, i64 5
  %138 = fmul contract float %107, %137
  %139 = fadd contract float %136, %138
  %140 = extractelement <8 x float> %121, i64 6
  %141 = fmul contract float %111, %140
  %142 = fadd contract float %139, %141
  %143 = extractelement <8 x float> %121, i64 7
  %144 = fmul contract float %115, %143
  %145 = fadd contract float %142, %144
  store float %145, ptr addrspace(5) %41, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %147

146:                                              ; preds = %66
  br label %147

147:                                              ; preds = %146, %68
  %148 = add i64 %42, 1024
  br label %149

149:                                              ; preds = %198, %147
  %150 = phi i64 [ %148, %147 ], [ %160, %198 ]
  %151 = phi i64 [ 0, %147 ], [ %161, %198 ]
  %152 = phi i64 [ %67, %147 ], [ %296, %198 ]
  %153 = add i64 %150, 1024
  %154 = icmp slt i64 %153, %150
  %155 = select i1 %154, i64 1, i64 0
  %156 = icmp sge i64 %150, %26
  %157 = icmp eq i64 %151, 0
  %158 = xor i1 %157, true
  %159 = or i1 %158, %156
  %160 = select i1 %159, i64 %150, i64 %153
  %161 = select i1 %159, i64 %151, i64 %155
  br i1 %159, label %162, label %198

162:                                              ; preds = %149
  %163 = udiv i64 %37, 32
  %164 = mul i64 %163, 2
  %165 = trunc i64 %164 to i32
  %166 = sext i32 %165 to i64
  %167 = add i64 %164, 1
  %168 = trunc i64 %167 to i32
  %169 = sext i32 %168 to i64
  %170 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %171 = sext i32 %170 to i64
  %172 = trunc i64 %169 to i32
  %173 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %172
  %174 = trunc i64 %166 to i32
  %175 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %174
  %176 = load float, ptr addrspace(5) %40, align 4
  %177 = bitcast float %176 to i32
  %178 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %177, i32 16, i32 31)
  %179 = bitcast i32 %178 to float
  %180 = fadd contract float %176, %179
  %181 = bitcast float %180 to i32
  %182 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %181, i32 8, i32 31)
  %183 = bitcast i32 %182 to float
  %184 = fadd contract float %180, %183
  %185 = bitcast float %184 to i32
  %186 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %185, i32 4, i32 31)
  %187 = bitcast i32 %186 to float
  %188 = fadd contract float %184, %187
  %189 = bitcast float %188 to i32
  %190 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %189, i32 2, i32 31)
  %191 = bitcast i32 %190 to float
  %192 = fadd contract float %188, %191
  %193 = bitcast float %192 to i32
  %194 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %193, i32 1, i32 31)
  %195 = bitcast i32 %194 to float
  %196 = fadd contract float %192, %195
  %197 = icmp eq i64 %171, 0
  br i1 %197, label %297, label %298

198:                                              ; preds = %149
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %30, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %152, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %199 = insertvalue [2 x ptr] undef, ptr %13, 0
  %200 = insertvalue [2 x ptr] %199, ptr %12, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %200, ptr %11, align 8
  %201 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %202 = load ptr, ptr %201, align 8
  %203 = load i64, ptr %202, align 8
  %204 = trunc i64 %203 to i32
  %205 = getelementptr inbounds ptr, ptr %201, i32 1
  %206 = load ptr, ptr %205, align 8
  %207 = load i64, ptr %206, align 8
  %208 = trunc i64 %207 to i32
  %209 = mul i32 %204, 2
  %210 = mul i32 %209, 7168
  %211 = mul i32 %208, 1024
  %212 = add i32 %210, %211
  %213 = sext i32 %212 to i64
  %214 = getelementptr inbounds bfloat, ptr %25, i64 %213
  %215 = getelementptr inbounds bfloat, ptr %214, i64 %36
  %216 = load <8 x bfloat>, ptr %215, align 16, !invariant.load !1
  store <8 x bfloat> %216, ptr addrspace(5) %38, align 16
  %217 = getelementptr inbounds bfloat, ptr %214, i64 %35
  %218 = load <8 x bfloat>, ptr %217, align 16, !invariant.load !1
  store <8 x bfloat> %218, ptr addrspace(5) %39, align 16
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %28, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %152, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %219 = insertvalue [2 x ptr] undef, ptr %10, 0
  %220 = insertvalue [2 x ptr] %219, ptr %9, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %220, ptr %8, align 8
  %221 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %222 = load ptr, ptr %221, align 8
  %223 = load i64, ptr %222, align 8
  %224 = getelementptr inbounds ptr, ptr %221, i32 1
  %225 = load ptr, ptr %224, align 8
  %226 = load i64, ptr %225, align 8
  %227 = mul i64 %223, 7168
  %228 = mul i64 %226, 1024
  %229 = add i64 %227, %228
  %230 = getelementptr inbounds bfloat, ptr %24, i64 %229
  %231 = getelementptr inbounds bfloat, ptr %230, i64 %36
  %232 = load <8 x bfloat>, ptr %231, align 16, !invariant.load !1
  %233 = load <8 x bfloat>, ptr addrspace(5) %38, align 16
  %234 = load float, ptr addrspace(5) %40, align 4
  %235 = fpext <8 x bfloat> %232 to <8 x float>
  %236 = fpext <8 x bfloat> %233 to <8 x float>
  %237 = extractelement <8 x float> %235, i64 0
  %238 = extractelement <8 x float> %236, i64 0
  %239 = fmul contract float %237, %238
  %240 = fadd contract float %234, %239
  %241 = extractelement <8 x float> %235, i64 1
  %242 = extractelement <8 x float> %236, i64 1
  %243 = fmul contract float %241, %242
  %244 = fadd contract float %240, %243
  %245 = extractelement <8 x float> %235, i64 2
  %246 = extractelement <8 x float> %236, i64 2
  %247 = fmul contract float %245, %246
  %248 = fadd contract float %244, %247
  %249 = extractelement <8 x float> %235, i64 3
  %250 = extractelement <8 x float> %236, i64 3
  %251 = fmul contract float %249, %250
  %252 = fadd contract float %248, %251
  %253 = extractelement <8 x float> %235, i64 4
  %254 = extractelement <8 x float> %236, i64 4
  %255 = fmul contract float %253, %254
  %256 = fadd contract float %252, %255
  %257 = extractelement <8 x float> %235, i64 5
  %258 = extractelement <8 x float> %236, i64 5
  %259 = fmul contract float %257, %258
  %260 = fadd contract float %256, %259
  %261 = extractelement <8 x float> %235, i64 6
  %262 = extractelement <8 x float> %236, i64 6
  %263 = fmul contract float %261, %262
  %264 = fadd contract float %260, %263
  %265 = extractelement <8 x float> %235, i64 7
  %266 = extractelement <8 x float> %236, i64 7
  %267 = fmul contract float %265, %266
  %268 = fadd contract float %264, %267
  store float %268, ptr addrspace(5) %40, align 4
  %269 = load <8 x bfloat>, ptr addrspace(5) %39, align 16
  %270 = load float, ptr addrspace(5) %41, align 4
  %271 = fpext <8 x bfloat> %269 to <8 x float>
  %272 = extractelement <8 x float> %271, i64 0
  %273 = fmul contract float %237, %272
  %274 = fadd contract float %270, %273
  %275 = extractelement <8 x float> %271, i64 1
  %276 = fmul contract float %241, %275
  %277 = fadd contract float %274, %276
  %278 = extractelement <8 x float> %271, i64 2
  %279 = fmul contract float %245, %278
  %280 = fadd contract float %277, %279
  %281 = extractelement <8 x float> %271, i64 3
  %282 = fmul contract float %249, %281
  %283 = fadd contract float %280, %282
  %284 = extractelement <8 x float> %271, i64 4
  %285 = fmul contract float %253, %284
  %286 = fadd contract float %283, %285
  %287 = extractelement <8 x float> %271, i64 5
  %288 = fmul contract float %257, %287
  %289 = fadd contract float %286, %288
  %290 = extractelement <8 x float> %271, i64 6
  %291 = fmul contract float %261, %290
  %292 = fadd contract float %289, %291
  %293 = extractelement <8 x float> %271, i64 7
  %294 = fmul contract float %265, %293
  %295 = fadd contract float %292, %294
  store float %295, ptr addrspace(5) %41, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %296 = add i64 %152, 1
  br label %149

297:                                              ; preds = %162
  store float %196, ptr addrspace(3) %175, align 4
  br label %299

298:                                              ; preds = %162
  br label %299

299:                                              ; preds = %298, %297
  %300 = load float, ptr addrspace(5) %41, align 4
  %301 = bitcast float %300 to i32
  %302 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %301, i32 16, i32 31)
  %303 = bitcast i32 %302 to float
  %304 = fadd contract float %300, %303
  %305 = bitcast float %304 to i32
  %306 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %305, i32 8, i32 31)
  %307 = bitcast i32 %306 to float
  %308 = fadd contract float %304, %307
  %309 = bitcast float %308 to i32
  %310 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %309, i32 4, i32 31)
  %311 = bitcast i32 %310 to float
  %312 = fadd contract float %308, %311
  %313 = bitcast float %312 to i32
  %314 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %313, i32 2, i32 31)
  %315 = bitcast i32 %314 to float
  %316 = fadd contract float %312, %315
  %317 = bitcast float %316 to i32
  %318 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %317, i32 1, i32 31)
  %319 = bitcast i32 %318 to float
  %320 = fadd contract float %316, %319
  br i1 %197, label %321, label %322

321:                                              ; preds = %299
  store float %320, ptr addrspace(3) %173, align 4
  br label %323

322:                                              ; preds = %299
  br label %323

323:                                              ; preds = %322, %321
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %324

324:                                              ; preds = %337, %323
  %325 = phi i64 [ %37, %323 ], [ %334, %337 ]
  %326 = phi i64 [ 0, %323 ], [ %335, %337 ]
  %327 = add i64 %325, 128
  %328 = icmp slt i64 %327, %325
  %329 = select i1 %328, i64 1, i64 0
  %330 = icmp sge i64 %325, 1
  %331 = icmp eq i64 %326, 0
  %332 = xor i1 %331, true
  %333 = or i1 %332, %330
  %334 = select i1 %333, i64 %325, i64 %327
  %335 = select i1 %333, i64 %326, i64 %329
  br i1 %333, label %336, label %337

336:                                              ; preds = %324
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %20)
  ret void

337:                                              ; preds = %324
  %338 = mul i64 %325, 2
  %339 = trunc i64 %338 to i32
  %340 = sext i32 %339 to i64
  %341 = trunc i64 %340 to i32
  %342 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %341
  %343 = load float, ptr addrspace(3) %342, align 4
  %344 = fadd contract float %343, 0.000000e+00
  %345 = insertelement <2 x float> zeroinitializer, float %344, i64 0
  %346 = add i64 %338, 1
  %347 = trunc i64 %346 to i32
  %348 = sext i32 %347 to i64
  %349 = trunc i64 %348 to i32
  %350 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %349
  %351 = load float, ptr addrspace(3) %350, align 4
  %352 = extractelement <2 x float> %345, i64 1
  %353 = fadd contract float %352, %351
  %354 = insertelement <2 x float> %345, float %353, i64 1
  %355 = add i64 %338, 2
  %356 = trunc i64 %355 to i32
  %357 = sext i32 %356 to i64
  %358 = trunc i64 %357 to i32
  %359 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %358
  %360 = load float, ptr addrspace(3) %359, align 4
  %361 = extractelement <2 x float> %354, i64 0
  %362 = fadd contract float %361, %360
  %363 = insertelement <2 x float> %354, float %362, i64 0
  %364 = add i64 %355, 1
  %365 = trunc i64 %364 to i32
  %366 = sext i32 %365 to i64
  %367 = trunc i64 %366 to i32
  %368 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %367
  %369 = load float, ptr addrspace(3) %368, align 4
  %370 = extractelement <2 x float> %363, i64 1
  %371 = fadd contract float %370, %369
  %372 = insertelement <2 x float> %363, float %371, i64 1
  %373 = add i64 %338, 4
  %374 = trunc i64 %373 to i32
  %375 = sext i32 %374 to i64
  %376 = trunc i64 %375 to i32
  %377 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %376
  %378 = load float, ptr addrspace(3) %377, align 4
  %379 = extractelement <2 x float> %372, i64 0
  %380 = fadd contract float %379, %378
  %381 = insertelement <2 x float> %372, float %380, i64 0
  %382 = add i64 %373, 1
  %383 = trunc i64 %382 to i32
  %384 = sext i32 %383 to i64
  %385 = trunc i64 %384 to i32
  %386 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %385
  %387 = load float, ptr addrspace(3) %386, align 4
  %388 = extractelement <2 x float> %381, i64 1
  %389 = fadd contract float %388, %387
  %390 = insertelement <2 x float> %381, float %389, i64 1
  %391 = add i64 %338, 6
  %392 = trunc i64 %391 to i32
  %393 = sext i32 %392 to i64
  %394 = trunc i64 %393 to i32
  %395 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %394
  %396 = load float, ptr addrspace(3) %395, align 4
  %397 = extractelement <2 x float> %390, i64 0
  %398 = fadd contract float %397, %396
  %399 = insertelement <2 x float> %390, float %398, i64 0
  %400 = add i64 %391, 1
  %401 = trunc i64 %400 to i32
  %402 = sext i32 %401 to i64
  %403 = trunc i64 %402 to i32
  %404 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_5727e24f._global_alloc_0._gpu_shared_mem, i32 %403
  %405 = load float, ptr addrspace(3) %404, align 4
  %406 = extractelement <2 x float> %399, i64 1
  %407 = fadd contract float %406, %405
  %408 = insertelement <2 x float> %399, float %407, i64 1
  %409 = add i64 %28, %325
  %410 = fptrunc <2 x float> %408 to <2 x bfloat>
  %411 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %6, align 8
  %412 = sdiv i64 %409, 2
  %413 = mul i64 %412, 2
  %414 = sub i64 %409, %413
  %415 = icmp slt i64 %409, 0
  %416 = icmp ne i64 %414, 0
  %417 = and i1 %415, %416
  %418 = select i1 %417, i64 2, i64 0
  %419 = add i64 %414, %418
  %420 = icmp eq i64 %419, 1
  %421 = select i1 %420, i64 -2, i64 2
  %422 = sitofp i64 %421 to bfloat
  %423 = insertelement <2 x bfloat> undef, bfloat %422, i32 0
  %424 = shufflevector <2 x bfloat> %423, <2 x bfloat> undef, <2 x i32> zeroinitializer
  %425 = fmul contract <2 x bfloat> %410, %424
  %426 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %411, 0
  %427 = mul i64 %409, 384
  %428 = add i64 %427, %31
  %429 = getelementptr inbounds bfloat, ptr %426, i64 %428
  store <2 x bfloat> %425, ptr %429, align 4
  br label %324
}

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.wait() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #4

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.launch.dependents() #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #3

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #5

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #6

attributes #0 = { noinline "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #1 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #2 = { nounwind }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #6 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
