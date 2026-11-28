; ModuleID = 'test_matmul_epilogue_fn_sm100_dispatch.mojo'
source_filename = "test_matmul_epilogue_fn_sm100_dispatch.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #1 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i64, i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca [2 x ptr], i64 1, align 8
  %17 = alloca i64, i64 1, align 8
  %18 = alloca i64, i64 1, align 8
  %19 = alloca [2 x float], align 4
  %20 = alloca [16 x bfloat], align 16
  %21 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %22 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %23 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %24 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %23, 0
  %25 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %22, 0
  %26 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %21, 0
  %27 = sext i32 %5 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %29 = zext i32 %28 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %31 = zext i32 %30 to i64
  %32 = mul i64 %31, 2
  %33 = add i64 %32, 1
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %35 = mul i32 %34, 8
  %36 = add i32 %35, 4096
  %37 = sext i32 %36 to i64
  %38 = sext i32 %35 to i64
  %39 = zext i32 %34 to i64
  call void @llvm.lifetime.start.p0(ptr %20)
  %40 = addrspacecast ptr %20 to ptr addrspace(5)
  %41 = getelementptr inbounds bfloat, ptr addrspace(5) %40, i32 8
  call void @llvm.lifetime.start.p0(ptr %19)
  %42 = addrspacecast ptr %19 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %42, align 4
  %43 = getelementptr inbounds float, ptr addrspace(5) %42, i32 1
  store float 0.000000e+00, ptr addrspace(5) %43, align 4
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  %44 = mul i64 %39, 8
  %45 = icmp slt i64 %44, %27
  br i1 %45, label %46, label %67

46:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %31, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %47 = insertvalue [2 x ptr] undef, ptr %18, 0
  %48 = insertvalue [2 x ptr] %47, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %48, ptr %16, align 8
  %49 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %50 = load ptr, ptr %49, align 8
  %51 = load i64, ptr %50, align 8
  %52 = trunc i64 %51 to i32
  %53 = getelementptr inbounds ptr, ptr %49, i32 1
  %54 = load ptr, ptr %53, align 8
  %55 = load i64, ptr %54, align 8
  %56 = trunc i64 %55 to i32
  %57 = mul i32 %52, 2
  %58 = mul i32 %57, 4096
  %59 = mul i32 %56, 1024
  %60 = add i32 %58, %59
  %61 = sext i32 %60 to i64
  %62 = getelementptr inbounds bfloat, ptr %26, i64 %61
  %63 = getelementptr inbounds bfloat, ptr %62, i64 %38
  %64 = load <8 x bfloat>, ptr %63, align 16, !invariant.load !1
  store <8 x bfloat> %64, ptr addrspace(5) %40, align 16
  %65 = getelementptr inbounds bfloat, ptr %62, i64 %37
  %66 = load <8 x bfloat>, ptr %65, align 16, !invariant.load !1
  store <8 x bfloat> %66, ptr addrspace(5) %41, align 16
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %68

67:                                               ; preds = %6
  br label %68

68:                                               ; preds = %67, %46
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %69 = select i1 %45, i64 1, i64 0
  br i1 %45, label %70, label %148

70:                                               ; preds = %68
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %29, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 0, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %71 = insertvalue [2 x ptr] undef, ptr %15, 0
  %72 = insertvalue [2 x ptr] %71, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %72, ptr %13, align 8
  %73 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %74 = load ptr, ptr %73, align 8
  %75 = load i64, ptr %74, align 8
  %76 = getelementptr inbounds ptr, ptr %73, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = load i64, ptr %77, align 8
  %79 = mul i64 %75, 4096
  %80 = mul i64 %78, 1024
  %81 = add i64 %79, %80
  %82 = getelementptr inbounds bfloat, ptr %25, i64 %81
  %83 = getelementptr inbounds bfloat, ptr %82, i64 %38
  %84 = load <8 x bfloat>, ptr %83, align 16, !invariant.load !1
  %85 = load <8 x bfloat>, ptr addrspace(5) %40, align 16
  %86 = load float, ptr addrspace(5) %42, align 4
  %87 = fpext <8 x bfloat> %84 to <8 x float>
  %88 = fpext <8 x bfloat> %85 to <8 x float>
  %89 = extractelement <8 x float> %87, i64 0
  %90 = extractelement <8 x float> %88, i64 0
  %91 = fmul contract float %89, %90
  %92 = fadd contract float %86, %91
  %93 = extractelement <8 x float> %87, i64 1
  %94 = extractelement <8 x float> %88, i64 1
  %95 = fmul contract float %93, %94
  %96 = fadd contract float %92, %95
  %97 = extractelement <8 x float> %87, i64 2
  %98 = extractelement <8 x float> %88, i64 2
  %99 = fmul contract float %97, %98
  %100 = fadd contract float %96, %99
  %101 = extractelement <8 x float> %87, i64 3
  %102 = extractelement <8 x float> %88, i64 3
  %103 = fmul contract float %101, %102
  %104 = fadd contract float %100, %103
  %105 = extractelement <8 x float> %87, i64 4
  %106 = extractelement <8 x float> %88, i64 4
  %107 = fmul contract float %105, %106
  %108 = fadd contract float %104, %107
  %109 = extractelement <8 x float> %87, i64 5
  %110 = extractelement <8 x float> %88, i64 5
  %111 = fmul contract float %109, %110
  %112 = fadd contract float %108, %111
  %113 = extractelement <8 x float> %87, i64 6
  %114 = extractelement <8 x float> %88, i64 6
  %115 = fmul contract float %113, %114
  %116 = fadd contract float %112, %115
  %117 = extractelement <8 x float> %87, i64 7
  %118 = extractelement <8 x float> %88, i64 7
  %119 = fmul contract float %117, %118
  %120 = fadd contract float %116, %119
  store float %120, ptr addrspace(5) %42, align 4
  %121 = load <8 x bfloat>, ptr addrspace(5) %41, align 16
  %122 = load float, ptr addrspace(5) %43, align 4
  %123 = fpext <8 x bfloat> %121 to <8 x float>
  %124 = extractelement <8 x float> %123, i64 0
  %125 = fmul contract float %89, %124
  %126 = fadd contract float %122, %125
  %127 = extractelement <8 x float> %123, i64 1
  %128 = fmul contract float %93, %127
  %129 = fadd contract float %126, %128
  %130 = extractelement <8 x float> %123, i64 2
  %131 = fmul contract float %97, %130
  %132 = fadd contract float %129, %131
  %133 = extractelement <8 x float> %123, i64 3
  %134 = fmul contract float %101, %133
  %135 = fadd contract float %132, %134
  %136 = extractelement <8 x float> %123, i64 4
  %137 = fmul contract float %105, %136
  %138 = fadd contract float %135, %137
  %139 = extractelement <8 x float> %123, i64 5
  %140 = fmul contract float %109, %139
  %141 = fadd contract float %138, %140
  %142 = extractelement <8 x float> %123, i64 6
  %143 = fmul contract float %113, %142
  %144 = fadd contract float %141, %143
  %145 = extractelement <8 x float> %123, i64 7
  %146 = fmul contract float %117, %145
  %147 = fadd contract float %144, %146
  store float %147, ptr addrspace(5) %43, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %149

148:                                              ; preds = %68
  br label %149

149:                                              ; preds = %148, %70
  %150 = add i64 %44, 1024
  br label %151

151:                                              ; preds = %200, %149
  %152 = phi i64 [ %150, %149 ], [ %162, %200 ]
  %153 = phi i64 [ 0, %149 ], [ %163, %200 ]
  %154 = phi i64 [ %69, %149 ], [ %298, %200 ]
  %155 = add i64 %152, 1024
  %156 = icmp slt i64 %155, %152
  %157 = select i1 %156, i64 1, i64 0
  %158 = icmp sge i64 %152, %27
  %159 = icmp eq i64 %153, 0
  %160 = xor i1 %159, true
  %161 = or i1 %160, %158
  %162 = select i1 %161, i64 %152, i64 %155
  %163 = select i1 %161, i64 %153, i64 %157
  br i1 %161, label %164, label %200

164:                                              ; preds = %151
  %165 = udiv i64 %39, 32
  %166 = mul i64 %165, 2
  %167 = trunc i64 %166 to i32
  %168 = sext i32 %167 to i64
  %169 = add i64 %166, 1
  %170 = trunc i64 %169 to i32
  %171 = sext i32 %170 to i64
  %172 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %173 = sext i32 %172 to i64
  %174 = trunc i64 %171 to i32
  %175 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %174
  %176 = trunc i64 %168 to i32
  %177 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %176
  %178 = load float, ptr addrspace(5) %42, align 4
  %179 = bitcast float %178 to i32
  %180 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %179, i32 16, i32 31)
  %181 = bitcast i32 %180 to float
  %182 = fadd contract float %178, %181
  %183 = bitcast float %182 to i32
  %184 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %183, i32 8, i32 31)
  %185 = bitcast i32 %184 to float
  %186 = fadd contract float %182, %185
  %187 = bitcast float %186 to i32
  %188 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %187, i32 4, i32 31)
  %189 = bitcast i32 %188 to float
  %190 = fadd contract float %186, %189
  %191 = bitcast float %190 to i32
  %192 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %191, i32 2, i32 31)
  %193 = bitcast i32 %192 to float
  %194 = fadd contract float %190, %193
  %195 = bitcast float %194 to i32
  %196 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %195, i32 1, i32 31)
  %197 = bitcast i32 %196 to float
  %198 = fadd contract float %194, %197
  %199 = icmp eq i64 %173, 0
  br i1 %199, label %299, label %300

200:                                              ; preds = %151
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %31, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %154, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %201 = insertvalue [2 x ptr] undef, ptr %12, 0
  %202 = insertvalue [2 x ptr] %201, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %202, ptr %10, align 8
  %203 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %204 = load ptr, ptr %203, align 8
  %205 = load i64, ptr %204, align 8
  %206 = trunc i64 %205 to i32
  %207 = getelementptr inbounds ptr, ptr %203, i32 1
  %208 = load ptr, ptr %207, align 8
  %209 = load i64, ptr %208, align 8
  %210 = trunc i64 %209 to i32
  %211 = mul i32 %206, 2
  %212 = mul i32 %211, 4096
  %213 = mul i32 %210, 1024
  %214 = add i32 %212, %213
  %215 = sext i32 %214 to i64
  %216 = getelementptr inbounds bfloat, ptr %26, i64 %215
  %217 = getelementptr inbounds bfloat, ptr %216, i64 %38
  %218 = load <8 x bfloat>, ptr %217, align 16, !invariant.load !1
  store <8 x bfloat> %218, ptr addrspace(5) %40, align 16
  %219 = getelementptr inbounds bfloat, ptr %216, i64 %37
  %220 = load <8 x bfloat>, ptr %219, align 16, !invariant.load !1
  store <8 x bfloat> %220, ptr addrspace(5) %41, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %29, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %154, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %221 = insertvalue [2 x ptr] undef, ptr %9, 0
  %222 = insertvalue [2 x ptr] %221, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %222, ptr %7, align 8
  %223 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %224 = load ptr, ptr %223, align 8
  %225 = load i64, ptr %224, align 8
  %226 = getelementptr inbounds ptr, ptr %223, i32 1
  %227 = load ptr, ptr %226, align 8
  %228 = load i64, ptr %227, align 8
  %229 = mul i64 %225, 4096
  %230 = mul i64 %228, 1024
  %231 = add i64 %229, %230
  %232 = getelementptr inbounds bfloat, ptr %25, i64 %231
  %233 = getelementptr inbounds bfloat, ptr %232, i64 %38
  %234 = load <8 x bfloat>, ptr %233, align 16, !invariant.load !1
  %235 = load <8 x bfloat>, ptr addrspace(5) %40, align 16
  %236 = load float, ptr addrspace(5) %42, align 4
  %237 = fpext <8 x bfloat> %234 to <8 x float>
  %238 = fpext <8 x bfloat> %235 to <8 x float>
  %239 = extractelement <8 x float> %237, i64 0
  %240 = extractelement <8 x float> %238, i64 0
  %241 = fmul contract float %239, %240
  %242 = fadd contract float %236, %241
  %243 = extractelement <8 x float> %237, i64 1
  %244 = extractelement <8 x float> %238, i64 1
  %245 = fmul contract float %243, %244
  %246 = fadd contract float %242, %245
  %247 = extractelement <8 x float> %237, i64 2
  %248 = extractelement <8 x float> %238, i64 2
  %249 = fmul contract float %247, %248
  %250 = fadd contract float %246, %249
  %251 = extractelement <8 x float> %237, i64 3
  %252 = extractelement <8 x float> %238, i64 3
  %253 = fmul contract float %251, %252
  %254 = fadd contract float %250, %253
  %255 = extractelement <8 x float> %237, i64 4
  %256 = extractelement <8 x float> %238, i64 4
  %257 = fmul contract float %255, %256
  %258 = fadd contract float %254, %257
  %259 = extractelement <8 x float> %237, i64 5
  %260 = extractelement <8 x float> %238, i64 5
  %261 = fmul contract float %259, %260
  %262 = fadd contract float %258, %261
  %263 = extractelement <8 x float> %237, i64 6
  %264 = extractelement <8 x float> %238, i64 6
  %265 = fmul contract float %263, %264
  %266 = fadd contract float %262, %265
  %267 = extractelement <8 x float> %237, i64 7
  %268 = extractelement <8 x float> %238, i64 7
  %269 = fmul contract float %267, %268
  %270 = fadd contract float %266, %269
  store float %270, ptr addrspace(5) %42, align 4
  %271 = load <8 x bfloat>, ptr addrspace(5) %41, align 16
  %272 = load float, ptr addrspace(5) %43, align 4
  %273 = fpext <8 x bfloat> %271 to <8 x float>
  %274 = extractelement <8 x float> %273, i64 0
  %275 = fmul contract float %239, %274
  %276 = fadd contract float %272, %275
  %277 = extractelement <8 x float> %273, i64 1
  %278 = fmul contract float %243, %277
  %279 = fadd contract float %276, %278
  %280 = extractelement <8 x float> %273, i64 2
  %281 = fmul contract float %247, %280
  %282 = fadd contract float %279, %281
  %283 = extractelement <8 x float> %273, i64 3
  %284 = fmul contract float %251, %283
  %285 = fadd contract float %282, %284
  %286 = extractelement <8 x float> %273, i64 4
  %287 = fmul contract float %255, %286
  %288 = fadd contract float %285, %287
  %289 = extractelement <8 x float> %273, i64 5
  %290 = fmul contract float %259, %289
  %291 = fadd contract float %288, %290
  %292 = extractelement <8 x float> %273, i64 6
  %293 = fmul contract float %263, %292
  %294 = fadd contract float %291, %293
  %295 = extractelement <8 x float> %273, i64 7
  %296 = fmul contract float %267, %295
  %297 = fadd contract float %294, %296
  store float %297, ptr addrspace(5) %43, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %298 = add i64 %154, 1
  br label %151

299:                                              ; preds = %164
  store float %198, ptr addrspace(3) %177, align 4
  br label %301

300:                                              ; preds = %164
  br label %301

301:                                              ; preds = %300, %299
  %302 = load float, ptr addrspace(5) %43, align 4
  %303 = bitcast float %302 to i32
  %304 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %303, i32 16, i32 31)
  %305 = bitcast i32 %304 to float
  %306 = fadd contract float %302, %305
  %307 = bitcast float %306 to i32
  %308 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %307, i32 8, i32 31)
  %309 = bitcast i32 %308 to float
  %310 = fadd contract float %306, %309
  %311 = bitcast float %310 to i32
  %312 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %311, i32 4, i32 31)
  %313 = bitcast i32 %312 to float
  %314 = fadd contract float %310, %313
  %315 = bitcast float %314 to i32
  %316 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %315, i32 2, i32 31)
  %317 = bitcast i32 %316 to float
  %318 = fadd contract float %314, %317
  %319 = bitcast float %318 to i32
  %320 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %319, i32 1, i32 31)
  %321 = bitcast i32 %320 to float
  %322 = fadd contract float %318, %321
  br i1 %199, label %323, label %324

323:                                              ; preds = %301
  store float %322, ptr addrspace(3) %175, align 4
  br label %325

324:                                              ; preds = %301
  br label %325

325:                                              ; preds = %324, %323
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %326

326:                                              ; preds = %339, %325
  %327 = phi i64 [ %39, %325 ], [ %336, %339 ]
  %328 = phi i64 [ 0, %325 ], [ %337, %339 ]
  %329 = add i64 %327, 128
  %330 = icmp slt i64 %329, %327
  %331 = select i1 %330, i64 1, i64 0
  %332 = icmp sge i64 %327, 1
  %333 = icmp eq i64 %328, 0
  %334 = xor i1 %333, true
  %335 = or i1 %334, %332
  %336 = select i1 %335, i64 %327, i64 %329
  %337 = select i1 %335, i64 %328, i64 %331
  br i1 %335, label %338, label %339

338:                                              ; preds = %326
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %19)
  ret void

339:                                              ; preds = %326
  %340 = mul i64 %327, 2
  %341 = trunc i64 %340 to i32
  %342 = sext i32 %341 to i64
  %343 = trunc i64 %342 to i32
  %344 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %343
  %345 = load float, ptr addrspace(3) %344, align 4
  %346 = fadd contract float %345, 0.000000e+00
  %347 = insertelement <2 x float> zeroinitializer, float %346, i64 0
  %348 = add i64 %340, 1
  %349 = trunc i64 %348 to i32
  %350 = sext i32 %349 to i64
  %351 = trunc i64 %350 to i32
  %352 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %351
  %353 = load float, ptr addrspace(3) %352, align 4
  %354 = extractelement <2 x float> %347, i64 1
  %355 = fadd contract float %354, %353
  %356 = insertelement <2 x float> %347, float %355, i64 1
  %357 = add i64 %340, 2
  %358 = trunc i64 %357 to i32
  %359 = sext i32 %358 to i64
  %360 = trunc i64 %359 to i32
  %361 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %360
  %362 = load float, ptr addrspace(3) %361, align 4
  %363 = extractelement <2 x float> %356, i64 0
  %364 = fadd contract float %363, %362
  %365 = insertelement <2 x float> %356, float %364, i64 0
  %366 = add i64 %357, 1
  %367 = trunc i64 %366 to i32
  %368 = sext i32 %367 to i64
  %369 = trunc i64 %368 to i32
  %370 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %369
  %371 = load float, ptr addrspace(3) %370, align 4
  %372 = extractelement <2 x float> %365, i64 1
  %373 = fadd contract float %372, %371
  %374 = insertelement <2 x float> %365, float %373, i64 1
  %375 = add i64 %340, 4
  %376 = trunc i64 %375 to i32
  %377 = sext i32 %376 to i64
  %378 = trunc i64 %377 to i32
  %379 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %378
  %380 = load float, ptr addrspace(3) %379, align 4
  %381 = extractelement <2 x float> %374, i64 0
  %382 = fadd contract float %381, %380
  %383 = insertelement <2 x float> %374, float %382, i64 0
  %384 = add i64 %375, 1
  %385 = trunc i64 %384 to i32
  %386 = sext i32 %385 to i64
  %387 = trunc i64 %386 to i32
  %388 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %387
  %389 = load float, ptr addrspace(3) %388, align 4
  %390 = extractelement <2 x float> %383, i64 1
  %391 = fadd contract float %390, %389
  %392 = insertelement <2 x float> %383, float %391, i64 1
  %393 = add i64 %340, 6
  %394 = trunc i64 %393 to i32
  %395 = sext i32 %394 to i64
  %396 = trunc i64 %395 to i32
  %397 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %396
  %398 = load float, ptr addrspace(3) %397, align 4
  %399 = extractelement <2 x float> %392, i64 0
  %400 = fadd contract float %399, %398
  %401 = insertelement <2 x float> %392, float %400, i64 0
  %402 = add i64 %393, 1
  %403 = trunc i64 %402 to i32
  %404 = sext i32 %403 to i64
  %405 = trunc i64 %404 to i32
  %406 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_5648a11a._global_alloc_0._gpu_shared_mem, i32 %405
  %407 = load float, ptr addrspace(3) %406, align 4
  %408 = extractelement <2 x float> %401, i64 1
  %409 = fadd contract float %408, %407
  %410 = insertelement <2 x float> %401, float %409, i64 1
  %411 = add i64 %29, %327
  %412 = fptrunc <2 x float> %410 to <2 x bfloat>
  %413 = extractelement <2 x bfloat> %412, i64 0
  %414 = mul i64 %411, 264
  %415 = add i64 %414, %32
  %416 = getelementptr inbounds bfloat, ptr %24, i64 %415
  store bfloat %413, ptr %416, align 2
  %417 = extractelement <2 x bfloat> %412, i64 1
  %418 = add i64 %414, %33
  %419 = getelementptr inbounds bfloat, ptr %24, i64 %418
  store bfloat %417, ptr %419, align 2
  br label %326
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
