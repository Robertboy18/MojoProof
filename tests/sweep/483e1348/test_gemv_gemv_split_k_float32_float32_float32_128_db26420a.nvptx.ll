; ModuleID = 'test_gemv.mojo'
source_filename = "test_gemv.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_float32_float32_float32_128_db26420a(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, i64 } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %25 = alloca [2 x float], align 4
  %26 = alloca [8 x float], align 16
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
  %42 = mul i64 %41, 2
  %43 = add i64 %42, 1
  %44 = mul i64 %43, %32
  %45 = mul i64 %42, %32
  %46 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %47 = zext i32 %46 to i64
  %48 = mul i64 %47, 4
  %49 = add i64 %36, %48
  call void @llvm.lifetime.start.p0(ptr %26)
  %50 = addrspacecast ptr %26 to ptr addrspace(5)
  %51 = getelementptr inbounds float, ptr addrspace(5) %50, i32 4
  call void @llvm.lifetime.start.p0(ptr %25)
  %52 = addrspacecast ptr %25 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %52, align 4
  %53 = getelementptr inbounds float, ptr addrspace(5) %52, i32 1
  store float 0.000000e+00, ptr addrspace(5) %53, align 4
  %54 = sub i64 %37, %48
  %55 = icmp sgt i64 %37, %48
  br i1 %55, label %56, label %65

56:                                               ; preds = %6
  %57 = sdiv i64 %54, -512
  %58 = mul i64 %57, -512
  %59 = icmp eq i64 %58, %54
  %60 = xor i64 %54, -512
  %61 = ashr i64 %60, 63
  %62 = select i1 %59, i64 0, i64 %61
  %63 = add i64 %57, %62
  %64 = sub i64 0, %63
  br label %66

65:                                               ; preds = %6
  br label %66

66:                                               ; preds = %65, %56
  %67 = phi i64 [ 0, %65 ], [ %64, %56 ]
  %68 = sdiv i64 %67, 2
  %69 = mul i64 %68, 2
  %70 = icmp eq i64 %69, %67
  %71 = xor i64 %67, 2
  %72 = ashr i64 %71, 63
  %73 = select i1 %70, i64 0, i64 %72
  %74 = add i64 %68, %73
  %75 = mul i64 %74, 2
  br label %76

76:                                               ; preds = %91, %66
  %77 = phi i64 [ 0, %66 ], [ %87, %91 ]
  %78 = phi i64 [ 0, %66 ], [ %88, %91 ]
  %79 = phi i64 [ 0, %66 ], [ %219, %91 ]
  %80 = add i64 %77, 2
  %81 = icmp slt i64 %80, %77
  %82 = select i1 %81, i64 1, i64 0
  %83 = icmp sge i64 %77, %75
  %84 = icmp eq i64 %78, 0
  %85 = xor i1 %84, true
  %86 = or i1 %85, %83
  %87 = select i1 %86, i64 %77, i64 %80
  %88 = select i1 %86, i64 %78, i64 %82
  br i1 %86, label %89, label %91

89:                                               ; preds = %76
  %90 = call i64 @llvm.smax.i64(i64 %75, i64 %67)
  br label %220

91:                                               ; preds = %76
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %41, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %79, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %92 = insertvalue [2 x ptr] undef, ptr %24, 0
  %93 = insertvalue [2 x ptr] %92, ptr %23, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %93, ptr %22, align 8
  %94 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %95 = load ptr, ptr %94, align 8
  %96 = load i64, ptr %95, align 8
  %97 = getelementptr inbounds ptr, ptr %94, i32 1
  %98 = load ptr, ptr %97, align 8
  %99 = load i64, ptr %98, align 8
  %100 = mul i64 %96, 2
  %101 = mul i64 %100, %36
  %102 = mul i64 %99, 512
  %103 = add i64 %101, %102
  %104 = getelementptr inbounds float, ptr %35, i64 %103
  %105 = getelementptr inbounds float, ptr %104, i64 %48
  %106 = load <4 x float>, ptr %105, align 16, !invariant.load !1
  store <4 x float> %106, ptr addrspace(5) %50, align 16
  %107 = getelementptr inbounds float, ptr %104, i64 %49
  %108 = load <4 x float>, ptr %107, align 16, !invariant.load !1
  store <4 x float> %108, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %39, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 %79, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %109 = insertvalue [2 x ptr] undef, ptr %21, 0
  %110 = insertvalue [2 x ptr] %109, ptr %20, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %110, ptr %19, align 8
  %111 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %112 = load ptr, ptr %111, align 8
  %113 = load i64, ptr %112, align 8
  %114 = getelementptr inbounds ptr, ptr %111, i32 1
  %115 = load ptr, ptr %114, align 8
  %116 = load i64, ptr %115, align 8
  %117 = mul i64 %113, %34
  %118 = mul i64 %116, 512
  %119 = add i64 %117, %118
  %120 = getelementptr inbounds float, ptr %33, i64 %119
  %121 = getelementptr inbounds float, ptr %120, i64 %48
  %122 = load <4 x float>, ptr %121, align 16, !invariant.load !1
  %123 = load <4 x float>, ptr addrspace(5) %50, align 16
  %124 = load float, ptr addrspace(5) %52, align 4
  %125 = extractelement <4 x float> %122, i64 0
  %126 = extractelement <4 x float> %123, i64 0
  %127 = fmul contract float %125, %126
  %128 = fadd contract float %124, %127
  %129 = extractelement <4 x float> %122, i64 1
  %130 = extractelement <4 x float> %123, i64 1
  %131 = fmul contract float %129, %130
  %132 = fadd contract float %128, %131
  %133 = extractelement <4 x float> %122, i64 2
  %134 = extractelement <4 x float> %123, i64 2
  %135 = fmul contract float %133, %134
  %136 = fadd contract float %132, %135
  %137 = extractelement <4 x float> %122, i64 3
  %138 = extractelement <4 x float> %123, i64 3
  %139 = fmul contract float %137, %138
  %140 = fadd contract float %136, %139
  store float %140, ptr addrspace(5) %52, align 4
  %141 = load <4 x float>, ptr addrspace(5) %51, align 16
  %142 = load float, ptr addrspace(5) %53, align 4
  %143 = extractelement <4 x float> %141, i64 0
  %144 = fmul contract float %125, %143
  %145 = fadd contract float %142, %144
  %146 = extractelement <4 x float> %141, i64 1
  %147 = fmul contract float %129, %146
  %148 = fadd contract float %145, %147
  %149 = extractelement <4 x float> %141, i64 2
  %150 = fmul contract float %133, %149
  %151 = fadd contract float %148, %150
  %152 = extractelement <4 x float> %141, i64 3
  %153 = fmul contract float %137, %152
  %154 = fadd contract float %151, %153
  store float %154, ptr addrspace(5) %53, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %155 = add i64 %79, 1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %41, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %155, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %156 = insertvalue [2 x ptr] undef, ptr %18, 0
  %157 = insertvalue [2 x ptr] %156, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %157, ptr %16, align 8
  %158 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %159 = load ptr, ptr %158, align 8
  %160 = load i64, ptr %159, align 8
  %161 = getelementptr inbounds ptr, ptr %158, i32 1
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = mul i64 %160, 2
  %165 = mul i64 %164, %36
  %166 = mul i64 %163, 512
  %167 = add i64 %165, %166
  %168 = getelementptr inbounds float, ptr %35, i64 %167
  %169 = getelementptr inbounds float, ptr %168, i64 %48
  %170 = load <4 x float>, ptr %169, align 16, !invariant.load !1
  store <4 x float> %170, ptr addrspace(5) %50, align 16
  %171 = getelementptr inbounds float, ptr %168, i64 %49
  %172 = load <4 x float>, ptr %171, align 16, !invariant.load !1
  store <4 x float> %172, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %39, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %155, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %173 = insertvalue [2 x ptr] undef, ptr %15, 0
  %174 = insertvalue [2 x ptr] %173, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %174, ptr %13, align 8
  %175 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %176 = load ptr, ptr %175, align 8
  %177 = load i64, ptr %176, align 8
  %178 = getelementptr inbounds ptr, ptr %175, i32 1
  %179 = load ptr, ptr %178, align 8
  %180 = load i64, ptr %179, align 8
  %181 = mul i64 %177, %34
  %182 = mul i64 %180, 512
  %183 = add i64 %181, %182
  %184 = getelementptr inbounds float, ptr %33, i64 %183
  %185 = getelementptr inbounds float, ptr %184, i64 %48
  %186 = load <4 x float>, ptr %185, align 16, !invariant.load !1
  %187 = load <4 x float>, ptr addrspace(5) %50, align 16
  %188 = load float, ptr addrspace(5) %52, align 4
  %189 = extractelement <4 x float> %186, i64 0
  %190 = extractelement <4 x float> %187, i64 0
  %191 = fmul contract float %189, %190
  %192 = fadd contract float %188, %191
  %193 = extractelement <4 x float> %186, i64 1
  %194 = extractelement <4 x float> %187, i64 1
  %195 = fmul contract float %193, %194
  %196 = fadd contract float %192, %195
  %197 = extractelement <4 x float> %186, i64 2
  %198 = extractelement <4 x float> %187, i64 2
  %199 = fmul contract float %197, %198
  %200 = fadd contract float %196, %199
  %201 = extractelement <4 x float> %186, i64 3
  %202 = extractelement <4 x float> %187, i64 3
  %203 = fmul contract float %201, %202
  %204 = fadd contract float %200, %203
  store float %204, ptr addrspace(5) %52, align 4
  %205 = load <4 x float>, ptr addrspace(5) %51, align 16
  %206 = load float, ptr addrspace(5) %53, align 4
  %207 = extractelement <4 x float> %205, i64 0
  %208 = fmul contract float %189, %207
  %209 = fadd contract float %206, %208
  %210 = extractelement <4 x float> %205, i64 1
  %211 = fmul contract float %193, %210
  %212 = fadd contract float %209, %211
  %213 = extractelement <4 x float> %205, i64 2
  %214 = fmul contract float %197, %213
  %215 = fadd contract float %212, %214
  %216 = extractelement <4 x float> %205, i64 3
  %217 = fmul contract float %201, %216
  %218 = fadd contract float %215, %217
  store float %218, ptr addrspace(5) %53, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %219 = add i64 %155, 1
  br label %76

220:                                              ; preds = %224, %89
  %221 = phi i64 [ %75, %89 ], [ %227, %224 ]
  %222 = phi i64 [ %79, %89 ], [ %291, %224 ]
  %223 = icmp slt i64 %221, %90
  br i1 %223, label %224, label %292

224:                                              ; preds = %220
  %225 = icmp eq i64 %221, %90
  %226 = add i64 %221, 1
  %227 = select i1 %225, i64 %221, i64 %226
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %41, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %222, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %228 = insertvalue [2 x ptr] undef, ptr %12, 0
  %229 = insertvalue [2 x ptr] %228, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %229, ptr %10, align 8
  %230 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %231 = load ptr, ptr %230, align 8
  %232 = load i64, ptr %231, align 8
  %233 = getelementptr inbounds ptr, ptr %230, i32 1
  %234 = load ptr, ptr %233, align 8
  %235 = load i64, ptr %234, align 8
  %236 = mul i64 %232, 2
  %237 = mul i64 %236, %36
  %238 = mul i64 %235, 512
  %239 = add i64 %237, %238
  %240 = getelementptr inbounds float, ptr %35, i64 %239
  %241 = getelementptr inbounds float, ptr %240, i64 %48
  %242 = load <4 x float>, ptr %241, align 16, !invariant.load !1
  store <4 x float> %242, ptr addrspace(5) %50, align 16
  %243 = getelementptr inbounds float, ptr %240, i64 %49
  %244 = load <4 x float>, ptr %243, align 16, !invariant.load !1
  store <4 x float> %244, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %39, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %222, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %245 = insertvalue [2 x ptr] undef, ptr %9, 0
  %246 = insertvalue [2 x ptr] %245, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %246, ptr %7, align 8
  %247 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %248 = load ptr, ptr %247, align 8
  %249 = load i64, ptr %248, align 8
  %250 = getelementptr inbounds ptr, ptr %247, i32 1
  %251 = load ptr, ptr %250, align 8
  %252 = load i64, ptr %251, align 8
  %253 = mul i64 %249, %34
  %254 = mul i64 %252, 512
  %255 = add i64 %253, %254
  %256 = getelementptr inbounds float, ptr %33, i64 %255
  %257 = getelementptr inbounds float, ptr %256, i64 %48
  %258 = load <4 x float>, ptr %257, align 16, !invariant.load !1
  %259 = load <4 x float>, ptr addrspace(5) %50, align 16
  %260 = load float, ptr addrspace(5) %52, align 4
  %261 = extractelement <4 x float> %258, i64 0
  %262 = extractelement <4 x float> %259, i64 0
  %263 = fmul contract float %261, %262
  %264 = fadd contract float %260, %263
  %265 = extractelement <4 x float> %258, i64 1
  %266 = extractelement <4 x float> %259, i64 1
  %267 = fmul contract float %265, %266
  %268 = fadd contract float %264, %267
  %269 = extractelement <4 x float> %258, i64 2
  %270 = extractelement <4 x float> %259, i64 2
  %271 = fmul contract float %269, %270
  %272 = fadd contract float %268, %271
  %273 = extractelement <4 x float> %258, i64 3
  %274 = extractelement <4 x float> %259, i64 3
  %275 = fmul contract float %273, %274
  %276 = fadd contract float %272, %275
  store float %276, ptr addrspace(5) %52, align 4
  %277 = load <4 x float>, ptr addrspace(5) %51, align 16
  %278 = load float, ptr addrspace(5) %53, align 4
  %279 = extractelement <4 x float> %277, i64 0
  %280 = fmul contract float %261, %279
  %281 = fadd contract float %278, %280
  %282 = extractelement <4 x float> %277, i64 1
  %283 = fmul contract float %265, %282
  %284 = fadd contract float %281, %283
  %285 = extractelement <4 x float> %277, i64 2
  %286 = fmul contract float %269, %285
  %287 = fadd contract float %284, %286
  %288 = extractelement <4 x float> %277, i64 3
  %289 = fmul contract float %273, %288
  %290 = fadd contract float %287, %289
  store float %290, ptr addrspace(5) %53, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %291 = add i64 %222, 1
  br label %220

292:                                              ; preds = %220
  %293 = udiv i64 %47, 32
  %294 = mul i64 %293, 2
  %295 = trunc i64 %294 to i32
  %296 = sext i32 %295 to i64
  %297 = add i64 %294, 1
  %298 = trunc i64 %297 to i32
  %299 = sext i32 %298 to i64
  %300 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %301 = sext i32 %300 to i64
  %302 = trunc i64 %299 to i32
  %303 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %302
  %304 = trunc i64 %296 to i32
  %305 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %304
  %306 = load float, ptr addrspace(5) %52, align 4
  %307 = bitcast float %306 to i32
  %308 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %307, i32 16, i32 31)
  %309 = bitcast i32 %308 to float
  %310 = fadd contract float %306, %309
  %311 = bitcast float %310 to i32
  %312 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %311, i32 8, i32 31)
  %313 = bitcast i32 %312 to float
  %314 = fadd contract float %310, %313
  %315 = bitcast float %314 to i32
  %316 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %315, i32 4, i32 31)
  %317 = bitcast i32 %316 to float
  %318 = fadd contract float %314, %317
  %319 = bitcast float %318 to i32
  %320 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %319, i32 2, i32 31)
  %321 = bitcast i32 %320 to float
  %322 = fadd contract float %318, %321
  %323 = bitcast float %322 to i32
  %324 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %323, i32 1, i32 31)
  %325 = bitcast i32 %324 to float
  %326 = fadd contract float %322, %325
  %327 = icmp eq i64 %301, 0
  br i1 %327, label %328, label %329

328:                                              ; preds = %292
  store float %326, ptr addrspace(3) %305, align 4
  br label %330

329:                                              ; preds = %292
  br label %330

330:                                              ; preds = %329, %328
  %331 = load float, ptr addrspace(5) %53, align 4
  %332 = bitcast float %331 to i32
  %333 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %332, i32 16, i32 31)
  %334 = bitcast i32 %333 to float
  %335 = fadd contract float %331, %334
  %336 = bitcast float %335 to i32
  %337 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %336, i32 8, i32 31)
  %338 = bitcast i32 %337 to float
  %339 = fadd contract float %335, %338
  %340 = bitcast float %339 to i32
  %341 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %340, i32 4, i32 31)
  %342 = bitcast i32 %341 to float
  %343 = fadd contract float %339, %342
  %344 = bitcast float %343 to i32
  %345 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %344, i32 2, i32 31)
  %346 = bitcast i32 %345 to float
  %347 = fadd contract float %343, %346
  %348 = bitcast float %347 to i32
  %349 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %348, i32 1, i32 31)
  %350 = bitcast i32 %349 to float
  %351 = fadd contract float %347, %350
  br i1 %327, label %352, label %353

352:                                              ; preds = %330
  store float %351, ptr addrspace(3) %303, align 4
  br label %354

353:                                              ; preds = %330
  br label %354

354:                                              ; preds = %353, %352
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %355

355:                                              ; preds = %368, %354
  %356 = phi i64 [ %47, %354 ], [ %365, %368 ]
  %357 = phi i64 [ 0, %354 ], [ %366, %368 ]
  %358 = add i64 %356, 128
  %359 = icmp slt i64 %358, %356
  %360 = select i1 %359, i64 1, i64 0
  %361 = icmp sge i64 %356, 1
  %362 = icmp eq i64 %357, 0
  %363 = xor i1 %362, true
  %364 = or i1 %363, %361
  %365 = select i1 %364, i64 %356, i64 %358
  %366 = select i1 %364, i64 %357, i64 %360
  br i1 %364, label %367, label %368

367:                                              ; preds = %355
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %25)
  ret void

368:                                              ; preds = %355
  %369 = mul i64 %356, 2
  %370 = trunc i64 %369 to i32
  %371 = sext i32 %370 to i64
  %372 = trunc i64 %371 to i32
  %373 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %372
  %374 = load float, ptr addrspace(3) %373, align 4
  %375 = fadd contract float %374, 0.000000e+00
  %376 = insertelement <2 x float> zeroinitializer, float %375, i64 0
  %377 = add i64 %369, 1
  %378 = trunc i64 %377 to i32
  %379 = sext i32 %378 to i64
  %380 = trunc i64 %379 to i32
  %381 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %380
  %382 = load float, ptr addrspace(3) %381, align 4
  %383 = extractelement <2 x float> %376, i64 1
  %384 = fadd contract float %383, %382
  %385 = insertelement <2 x float> %376, float %384, i64 1
  %386 = add i64 %369, 2
  %387 = trunc i64 %386 to i32
  %388 = sext i32 %387 to i64
  %389 = trunc i64 %388 to i32
  %390 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %389
  %391 = load float, ptr addrspace(3) %390, align 4
  %392 = extractelement <2 x float> %385, i64 0
  %393 = fadd contract float %392, %391
  %394 = insertelement <2 x float> %385, float %393, i64 0
  %395 = add i64 %386, 1
  %396 = trunc i64 %395 to i32
  %397 = sext i32 %396 to i64
  %398 = trunc i64 %397 to i32
  %399 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %398
  %400 = load float, ptr addrspace(3) %399, align 4
  %401 = extractelement <2 x float> %394, i64 1
  %402 = fadd contract float %401, %400
  %403 = insertelement <2 x float> %394, float %402, i64 1
  %404 = add i64 %369, 4
  %405 = trunc i64 %404 to i32
  %406 = sext i32 %405 to i64
  %407 = trunc i64 %406 to i32
  %408 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %407
  %409 = load float, ptr addrspace(3) %408, align 4
  %410 = extractelement <2 x float> %403, i64 0
  %411 = fadd contract float %410, %409
  %412 = insertelement <2 x float> %403, float %411, i64 0
  %413 = add i64 %404, 1
  %414 = trunc i64 %413 to i32
  %415 = sext i32 %414 to i64
  %416 = trunc i64 %415 to i32
  %417 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %416
  %418 = load float, ptr addrspace(3) %417, align 4
  %419 = extractelement <2 x float> %412, i64 1
  %420 = fadd contract float %419, %418
  %421 = insertelement <2 x float> %412, float %420, i64 1
  %422 = add i64 %369, 6
  %423 = trunc i64 %422 to i32
  %424 = sext i32 %423 to i64
  %425 = trunc i64 %424 to i32
  %426 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %425
  %427 = load float, ptr addrspace(3) %426, align 4
  %428 = extractelement <2 x float> %421, i64 0
  %429 = fadd contract float %428, %427
  %430 = insertelement <2 x float> %421, float %429, i64 0
  %431 = add i64 %422, 1
  %432 = trunc i64 %431 to i32
  %433 = sext i32 %432 to i64
  %434 = trunc i64 %433 to i32
  %435 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_float32_float32_128_db26420a._global_alloc_0._gpu_shared_mem, i32 %434
  %436 = load float, ptr addrspace(3) %435, align 4
  %437 = extractelement <2 x float> %430, i64 1
  %438 = fadd contract float %437, %436
  %439 = insertelement <2 x float> %430, float %438, i64 1
  %440 = add i64 %39, %356
  %441 = extractelement <2 x float> %439, i64 0
  %442 = mul i64 %440, %31
  %443 = add i64 %442, %45
  %444 = getelementptr inbounds float, ptr %30, i64 %443
  store float %441, ptr %444, align 4
  %445 = extractelement <2 x float> %439, i64 1
  %446 = add i64 %442, %44
  %447 = getelementptr inbounds float, ptr %30, i64 %446
  store float %445, ptr %447, align 4
  br label %355
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

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #5 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
