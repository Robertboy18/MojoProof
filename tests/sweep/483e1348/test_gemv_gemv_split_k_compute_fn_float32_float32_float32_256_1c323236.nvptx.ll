; ModuleID = 'test_gemv.mojo'
source_filename = "test_gemv.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, i64 } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %19 = alloca [2 x ptr], i64 1, align 8
  %20 = alloca i64, i64 1, align 8
  %21 = alloca i64, i64 1, align 8
  %22 = alloca [2 x ptr], i64 1, align 8
  %23 = alloca i64, i64 1, align 8
  %24 = alloca i64, i64 1, align 8
  %25 = alloca float, i64 1, align 4
  %26 = alloca [4 x float], align 16
  %27 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %28 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %29 = load { ptr, { { i64, i64 }, { i64, i64 } } }, ptr %0, align 8
  %30 = extractvalue { ptr, { { i64, i64 }, { i64, i64 } } } %29, 0
  %31 = extractvalue { ptr, { { i64, i64 }, { i64, i64 } } } %29, 1, 1, 0
  %32 = extractvalue { ptr, { { i64, i64 }, { i64, i64 } } } %29, 1, 1, 1
  %33 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %28, 0
  %34 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %28, 1, 1, 0
  %35 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %27, 0
  %36 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %27, 1, 1, 0
  %37 = sext i32 %5 to i64
  %38 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %39 = zext i32 %38 to i64
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %41 = zext i32 %40 to i64
  %42 = mul i64 %41, %32
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %44 = zext i32 %43 to i64
  %45 = mul i64 %44, 4
  call void @llvm.lifetime.start.p0(ptr %26)
  %46 = addrspacecast ptr %26 to ptr addrspace(5)
  call void @llvm.lifetime.start.p0(ptr %25)
  %47 = addrspacecast ptr %25 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %47, align 4
  %48 = sub i64 %37, %45
  %49 = icmp sgt i64 %37, %45
  br i1 %49, label %50, label %59

50:                                               ; preds = %6
  %51 = sdiv i64 %48, -1024
  %52 = mul i64 %51, -1024
  %53 = icmp eq i64 %52, %48
  %54 = xor i64 %48, -1024
  %55 = ashr i64 %54, 63
  %56 = select i1 %53, i64 0, i64 %55
  %57 = add i64 %51, %56
  %58 = sub i64 0, %57
  br label %60

59:                                               ; preds = %6
  br label %60

60:                                               ; preds = %59, %50
  %61 = phi i64 [ 0, %59 ], [ %58, %50 ]
  %62 = sdiv i64 %61, 2
  %63 = mul i64 %62, 2
  %64 = icmp eq i64 %63, %61
  %65 = xor i64 %61, 2
  %66 = ashr i64 %65, 63
  %67 = select i1 %64, i64 0, i64 %66
  %68 = add i64 %62, %67
  %69 = mul i64 %68, 2
  br label %70

70:                                               ; preds = %85, %60
  %71 = phi i64 [ 0, %60 ], [ %81, %85 ]
  %72 = phi i64 [ 0, %60 ], [ %82, %85 ]
  %73 = phi i64 [ 0, %60 ], [ %179, %85 ]
  %74 = add i64 %71, 2
  %75 = icmp slt i64 %74, %71
  %76 = select i1 %75, i64 1, i64 0
  %77 = icmp sge i64 %71, %69
  %78 = icmp eq i64 %72, 0
  %79 = xor i1 %78, true
  %80 = or i1 %79, %77
  %81 = select i1 %80, i64 %71, i64 %74
  %82 = select i1 %80, i64 %72, i64 %76
  br i1 %80, label %83, label %85

83:                                               ; preds = %70
  %84 = call i64 @llvm.smax.i64(i64 %69, i64 %61)
  br label %180

85:                                               ; preds = %70
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %41, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %73, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %86 = insertvalue [2 x ptr] undef, ptr %24, 0
  %87 = insertvalue [2 x ptr] %86, ptr %23, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %87, ptr %22, align 8
  %88 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %89 = load ptr, ptr %88, align 8
  %90 = load i64, ptr %89, align 8
  %91 = getelementptr inbounds ptr, ptr %88, i32 1
  %92 = load ptr, ptr %91, align 8
  %93 = load i64, ptr %92, align 8
  %94 = mul i64 %90, %36
  %95 = mul i64 %93, 1024
  %96 = add i64 %94, %95
  %97 = getelementptr inbounds float, ptr %35, i64 %96
  %98 = getelementptr inbounds float, ptr %97, i64 %45
  %99 = load <4 x float>, ptr %98, align 16, !invariant.load !1
  store <4 x float> %99, ptr addrspace(5) %46, align 16
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %39, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 %73, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %100 = insertvalue [2 x ptr] undef, ptr %21, 0
  %101 = insertvalue [2 x ptr] %100, ptr %20, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %101, ptr %19, align 8
  %102 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %103 = load ptr, ptr %102, align 8
  %104 = load i64, ptr %103, align 8
  %105 = getelementptr inbounds ptr, ptr %102, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = load i64, ptr %106, align 8
  %108 = mul i64 %104, %34
  %109 = mul i64 %107, 1024
  %110 = add i64 %108, %109
  %111 = getelementptr inbounds float, ptr %33, i64 %110
  %112 = getelementptr inbounds float, ptr %111, i64 %45
  %113 = load <4 x float>, ptr %112, align 16, !invariant.load !1
  %114 = load <4 x float>, ptr addrspace(5) %46, align 16
  %115 = load float, ptr addrspace(5) %47, align 4
  %116 = extractelement <4 x float> %113, i64 0
  %117 = extractelement <4 x float> %114, i64 0
  %118 = fmul contract float %116, %117
  %119 = fadd contract float %115, %118
  %120 = extractelement <4 x float> %113, i64 1
  %121 = extractelement <4 x float> %114, i64 1
  %122 = fmul contract float %120, %121
  %123 = fadd contract float %119, %122
  %124 = extractelement <4 x float> %113, i64 2
  %125 = extractelement <4 x float> %114, i64 2
  %126 = fmul contract float %124, %125
  %127 = fadd contract float %123, %126
  %128 = extractelement <4 x float> %113, i64 3
  %129 = extractelement <4 x float> %114, i64 3
  %130 = fmul contract float %128, %129
  %131 = fadd contract float %127, %130
  store float %131, ptr addrspace(5) %47, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %132 = add i64 %73, 1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %41, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %132, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %133 = insertvalue [2 x ptr] undef, ptr %18, 0
  %134 = insertvalue [2 x ptr] %133, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %134, ptr %16, align 8
  %135 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %136 = load ptr, ptr %135, align 8
  %137 = load i64, ptr %136, align 8
  %138 = getelementptr inbounds ptr, ptr %135, i32 1
  %139 = load ptr, ptr %138, align 8
  %140 = load i64, ptr %139, align 8
  %141 = mul i64 %137, %36
  %142 = mul i64 %140, 1024
  %143 = add i64 %141, %142
  %144 = getelementptr inbounds float, ptr %35, i64 %143
  %145 = getelementptr inbounds float, ptr %144, i64 %45
  %146 = load <4 x float>, ptr %145, align 16, !invariant.load !1
  store <4 x float> %146, ptr addrspace(5) %46, align 16
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %39, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %132, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %147 = insertvalue [2 x ptr] undef, ptr %15, 0
  %148 = insertvalue [2 x ptr] %147, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %148, ptr %13, align 8
  %149 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %150 = load ptr, ptr %149, align 8
  %151 = load i64, ptr %150, align 8
  %152 = getelementptr inbounds ptr, ptr %149, i32 1
  %153 = load ptr, ptr %152, align 8
  %154 = load i64, ptr %153, align 8
  %155 = mul i64 %151, %34
  %156 = mul i64 %154, 1024
  %157 = add i64 %155, %156
  %158 = getelementptr inbounds float, ptr %33, i64 %157
  %159 = getelementptr inbounds float, ptr %158, i64 %45
  %160 = load <4 x float>, ptr %159, align 16, !invariant.load !1
  %161 = load <4 x float>, ptr addrspace(5) %46, align 16
  %162 = load float, ptr addrspace(5) %47, align 4
  %163 = extractelement <4 x float> %160, i64 0
  %164 = extractelement <4 x float> %161, i64 0
  %165 = fmul contract float %163, %164
  %166 = fadd contract float %162, %165
  %167 = extractelement <4 x float> %160, i64 1
  %168 = extractelement <4 x float> %161, i64 1
  %169 = fmul contract float %167, %168
  %170 = fadd contract float %166, %169
  %171 = extractelement <4 x float> %160, i64 2
  %172 = extractelement <4 x float> %161, i64 2
  %173 = fmul contract float %171, %172
  %174 = fadd contract float %170, %173
  %175 = extractelement <4 x float> %160, i64 3
  %176 = extractelement <4 x float> %161, i64 3
  %177 = fmul contract float %175, %176
  %178 = fadd contract float %174, %177
  store float %178, ptr addrspace(5) %47, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %179 = add i64 %132, 1
  br label %70

180:                                              ; preds = %184, %83
  %181 = phi i64 [ %69, %83 ], [ %187, %184 ]
  %182 = phi i64 [ %73, %83 ], [ %234, %184 ]
  %183 = icmp slt i64 %181, %84
  br i1 %183, label %184, label %235

184:                                              ; preds = %180
  %185 = icmp eq i64 %181, %84
  %186 = add i64 %181, 1
  %187 = select i1 %185, i64 %181, i64 %186
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %41, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %182, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %188 = insertvalue [2 x ptr] undef, ptr %12, 0
  %189 = insertvalue [2 x ptr] %188, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %189, ptr %10, align 8
  %190 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %191 = load ptr, ptr %190, align 8
  %192 = load i64, ptr %191, align 8
  %193 = getelementptr inbounds ptr, ptr %190, i32 1
  %194 = load ptr, ptr %193, align 8
  %195 = load i64, ptr %194, align 8
  %196 = mul i64 %192, %36
  %197 = mul i64 %195, 1024
  %198 = add i64 %196, %197
  %199 = getelementptr inbounds float, ptr %35, i64 %198
  %200 = getelementptr inbounds float, ptr %199, i64 %45
  %201 = load <4 x float>, ptr %200, align 16, !invariant.load !1
  store <4 x float> %201, ptr addrspace(5) %46, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %39, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %182, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %202 = insertvalue [2 x ptr] undef, ptr %9, 0
  %203 = insertvalue [2 x ptr] %202, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %203, ptr %7, align 8
  %204 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %205 = load ptr, ptr %204, align 8
  %206 = load i64, ptr %205, align 8
  %207 = getelementptr inbounds ptr, ptr %204, i32 1
  %208 = load ptr, ptr %207, align 8
  %209 = load i64, ptr %208, align 8
  %210 = mul i64 %206, %34
  %211 = mul i64 %209, 1024
  %212 = add i64 %210, %211
  %213 = getelementptr inbounds float, ptr %33, i64 %212
  %214 = getelementptr inbounds float, ptr %213, i64 %45
  %215 = load <4 x float>, ptr %214, align 16, !invariant.load !1
  %216 = load <4 x float>, ptr addrspace(5) %46, align 16
  %217 = load float, ptr addrspace(5) %47, align 4
  %218 = extractelement <4 x float> %215, i64 0
  %219 = extractelement <4 x float> %216, i64 0
  %220 = fmul contract float %218, %219
  %221 = fadd contract float %217, %220
  %222 = extractelement <4 x float> %215, i64 1
  %223 = extractelement <4 x float> %216, i64 1
  %224 = fmul contract float %222, %223
  %225 = fadd contract float %221, %224
  %226 = extractelement <4 x float> %215, i64 2
  %227 = extractelement <4 x float> %216, i64 2
  %228 = fmul contract float %226, %227
  %229 = fadd contract float %225, %228
  %230 = extractelement <4 x float> %215, i64 3
  %231 = extractelement <4 x float> %216, i64 3
  %232 = fmul contract float %230, %231
  %233 = fadd contract float %229, %232
  store float %233, ptr addrspace(5) %47, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %234 = add i64 %182, 1
  br label %180

235:                                              ; preds = %180
  %236 = udiv i64 %44, 32
  %237 = trunc i64 %236 to i32
  %238 = sext i32 %237 to i64
  %239 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %240 = sext i32 %239 to i64
  %241 = trunc i64 %238 to i32
  %242 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %241
  %243 = load float, ptr addrspace(5) %47, align 4
  %244 = bitcast float %243 to i32
  %245 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %244, i32 16, i32 31)
  %246 = bitcast i32 %245 to float
  %247 = fadd contract float %243, %246
  %248 = bitcast float %247 to i32
  %249 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %248, i32 8, i32 31)
  %250 = bitcast i32 %249 to float
  %251 = fadd contract float %247, %250
  %252 = bitcast float %251 to i32
  %253 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %252, i32 4, i32 31)
  %254 = bitcast i32 %253 to float
  %255 = fadd contract float %251, %254
  %256 = bitcast float %255 to i32
  %257 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %256, i32 2, i32 31)
  %258 = bitcast i32 %257 to float
  %259 = fadd contract float %255, %258
  %260 = bitcast float %259 to i32
  %261 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %260, i32 1, i32 31)
  %262 = bitcast i32 %261 to float
  %263 = fadd contract float %259, %262
  %264 = icmp eq i64 %240, 0
  br i1 %264, label %265, label %266

265:                                              ; preds = %235
  store float %263, ptr addrspace(3) %242, align 4
  br label %267

266:                                              ; preds = %235
  br label %267

267:                                              ; preds = %266, %265
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %268

268:                                              ; preds = %281, %267
  %269 = phi i64 [ %44, %267 ], [ %278, %281 ]
  %270 = phi i64 [ 0, %267 ], [ %279, %281 ]
  %271 = add i64 %269, 256
  %272 = icmp slt i64 %271, %269
  %273 = select i1 %272, i64 1, i64 0
  %274 = icmp sge i64 %269, 1
  %275 = icmp eq i64 %270, 0
  %276 = xor i1 %275, true
  %277 = or i1 %276, %274
  %278 = select i1 %277, i64 %269, i64 %271
  %279 = select i1 %277, i64 %270, i64 %273
  br i1 %277, label %280, label %281

280:                                              ; preds = %268
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %25)
  ret void

281:                                              ; preds = %268
  %282 = trunc i64 %269 to i32
  %283 = sext i32 %282 to i64
  %284 = trunc i64 %283 to i32
  %285 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %284
  %286 = load float, ptr addrspace(3) %285, align 4
  %287 = fadd contract float %286, 0.000000e+00
  %288 = add i64 %269, 1
  %289 = trunc i64 %288 to i32
  %290 = sext i32 %289 to i64
  %291 = trunc i64 %290 to i32
  %292 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %291
  %293 = load float, ptr addrspace(3) %292, align 4
  %294 = fadd contract float %287, %293
  %295 = add i64 %269, 2
  %296 = trunc i64 %295 to i32
  %297 = sext i32 %296 to i64
  %298 = trunc i64 %297 to i32
  %299 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %298
  %300 = load float, ptr addrspace(3) %299, align 4
  %301 = fadd contract float %294, %300
  %302 = add i64 %269, 3
  %303 = trunc i64 %302 to i32
  %304 = sext i32 %303 to i64
  %305 = trunc i64 %304 to i32
  %306 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %305
  %307 = load float, ptr addrspace(3) %306, align 4
  %308 = fadd contract float %301, %307
  %309 = add i64 %269, 4
  %310 = trunc i64 %309 to i32
  %311 = sext i32 %310 to i64
  %312 = trunc i64 %311 to i32
  %313 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %312
  %314 = load float, ptr addrspace(3) %313, align 4
  %315 = fadd contract float %308, %314
  %316 = add i64 %269, 5
  %317 = trunc i64 %316 to i32
  %318 = sext i32 %317 to i64
  %319 = trunc i64 %318 to i32
  %320 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %319
  %321 = load float, ptr addrspace(3) %320, align 4
  %322 = fadd contract float %315, %321
  %323 = add i64 %269, 6
  %324 = trunc i64 %323 to i32
  %325 = sext i32 %324 to i64
  %326 = trunc i64 %325 to i32
  %327 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %326
  %328 = load float, ptr addrspace(3) %327, align 4
  %329 = fadd contract float %322, %328
  %330 = add i64 %269, 7
  %331 = trunc i64 %330 to i32
  %332 = sext i32 %331 to i64
  %333 = trunc i64 %332 to i32
  %334 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1c323236._global_alloc_0._gpu_shared_mem, i32 %333
  %335 = load float, ptr addrspace(3) %334, align 4
  %336 = fadd contract float %329, %335
  %337 = add i64 %39, %269
  %338 = fadd contract float %336, 4.000000e+00
  %339 = mul i64 %337, %31
  %340 = add i64 %339, %42
  %341 = getelementptr inbounds float, ptr %30, i64 %340
  store float %338, ptr %341, align 4
  br label %268
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

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #4

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #5

attributes #0 = { convergent norecurse "nvvm.maxntid"="256" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #5 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
