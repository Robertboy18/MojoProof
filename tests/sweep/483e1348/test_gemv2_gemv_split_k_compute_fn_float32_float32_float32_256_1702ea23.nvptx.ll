; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %25 = alloca [2 x ptr], i64 1, align 8
  %26 = alloca i64, i64 1, align 8
  %27 = alloca i64, i64 1, align 8
  %28 = alloca [2 x ptr], i64 1, align 8
  %29 = alloca i64, i64 1, align 8
  %30 = alloca i64, i64 1, align 8
  %31 = alloca float, i64 1, align 4
  %32 = alloca [4 x float], align 16
  %33 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %34 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %35 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %36 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %35, 0
  %37 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %34, 0
  %38 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %33, 0
  %39 = sext i32 %5 to i64
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %41 = zext i32 %40 to i64
  %42 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %43 = zext i32 %42 to i64
  %44 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %45 = mul i32 %44, 4
  %46 = sext i32 %45 to i64
  %47 = zext i32 %44 to i64
  call void @llvm.lifetime.start.p0(ptr %32)
  %48 = addrspacecast ptr %32 to ptr addrspace(5)
  call void @llvm.lifetime.start.p0(ptr %31)
  %49 = addrspacecast ptr %31 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %49, align 4
  %50 = mul i64 %47, 4
  %51 = sub i64 %39, %50
  %52 = icmp slt i64 %50, %39
  br i1 %52, label %53, label %71

53:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.start.p0(ptr %30)
  store i64 %43, ptr %30, align 8
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.start.p0(ptr %29)
  store i64 0, ptr %29, align 8
  call void @llvm.lifetime.end.p0(ptr %28)
  %54 = insertvalue [2 x ptr] undef, ptr %30, 0
  %55 = insertvalue [2 x ptr] %54, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %28)
  store [2 x ptr] %55, ptr %28, align 8
  %56 = getelementptr inbounds [2 x ptr], ptr %28, i32 0, i32 0
  %57 = load ptr, ptr %56, align 8
  %58 = load i64, ptr %57, align 8
  %59 = trunc i64 %58 to i32
  %60 = getelementptr inbounds ptr, ptr %56, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = load i64, ptr %61, align 8
  %63 = trunc i64 %62 to i32
  %64 = mul i32 %59, 32
  %65 = mul i32 %63, 1024
  %66 = add i32 %64, %65
  %67 = sext i32 %66 to i64
  %68 = getelementptr inbounds float, ptr %38, i64 %67
  %69 = getelementptr inbounds float, ptr %68, i64 %46
  %70 = load <4 x float>, ptr %69, align 16, !invariant.load !1
  store <4 x float> %70, ptr addrspace(5) %48, align 16
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.end.p0(ptr %30)
  br label %72

71:                                               ; preds = %6
  br label %72

72:                                               ; preds = %71, %53
  %73 = select i1 %52, i64 1, i64 0
  br i1 %52, label %74, label %107

74:                                               ; preds = %72
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 %41, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.start.p0(ptr %26)
  store i64 0, ptr %26, align 8
  call void @llvm.lifetime.end.p0(ptr %25)
  %75 = insertvalue [2 x ptr] undef, ptr %27, 0
  %76 = insertvalue [2 x ptr] %75, ptr %26, 1
  call void @llvm.lifetime.start.p0(ptr %25)
  store [2 x ptr] %76, ptr %25, align 8
  %77 = getelementptr inbounds [2 x ptr], ptr %25, i32 0, i32 0
  %78 = load ptr, ptr %77, align 8
  %79 = load i64, ptr %78, align 8
  %80 = getelementptr inbounds ptr, ptr %77, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = load i64, ptr %81, align 8
  %83 = mul i64 %79, 32
  %84 = mul i64 %82, 1024
  %85 = add i64 %83, %84
  %86 = getelementptr inbounds float, ptr %37, i64 %85
  %87 = getelementptr inbounds float, ptr %86, i64 %46
  %88 = load <4 x float>, ptr %87, align 16, !invariant.load !1
  %89 = load <4 x float>, ptr addrspace(5) %48, align 16
  %90 = load float, ptr addrspace(5) %49, align 4
  %91 = extractelement <4 x float> %88, i64 0
  %92 = extractelement <4 x float> %89, i64 0
  %93 = fmul contract float %91, %92
  %94 = fadd contract float %90, %93
  %95 = extractelement <4 x float> %88, i64 1
  %96 = extractelement <4 x float> %89, i64 1
  %97 = fmul contract float %95, %96
  %98 = fadd contract float %94, %97
  %99 = extractelement <4 x float> %88, i64 2
  %100 = extractelement <4 x float> %89, i64 2
  %101 = fmul contract float %99, %100
  %102 = fadd contract float %98, %101
  %103 = extractelement <4 x float> %88, i64 3
  %104 = extractelement <4 x float> %89, i64 3
  %105 = fmul contract float %103, %104
  %106 = fadd contract float %102, %105
  store float %106, ptr addrspace(5) %49, align 4
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  br label %108

107:                                              ; preds = %72
  br label %108

108:                                              ; preds = %107, %74
  %109 = icmp sgt i64 %39, %50
  br i1 %109, label %110, label %119

110:                                              ; preds = %108
  %111 = sdiv i64 %51, -1024
  %112 = mul i64 %111, -1024
  %113 = icmp eq i64 %112, %51
  %114 = xor i64 %51, -1024
  %115 = ashr i64 %114, 63
  %116 = select i1 %113, i64 0, i64 %115
  %117 = add i64 %111, %116
  %118 = sub i64 0, %117
  br label %120

119:                                              ; preds = %108
  br label %120

120:                                              ; preds = %119, %110
  %121 = phi i64 [ 0, %119 ], [ %118, %110 ]
  %122 = sub i64 %121, 1
  %123 = call i64 @llvm.smax.i64(i64 %122, i64 0)
  %124 = sdiv i64 %123, 2
  %125 = mul i64 %124, 2
  %126 = icmp eq i64 %125, %123
  %127 = xor i64 %123, 2
  %128 = ashr i64 %127, 63
  %129 = select i1 %126, i64 0, i64 %128
  %130 = add i64 %124, %129
  %131 = mul i64 %130, 2
  br label %132

132:                                              ; preds = %147, %120
  %133 = phi i64 [ 0, %120 ], [ %143, %147 ]
  %134 = phi i64 [ 0, %120 ], [ %144, %147 ]
  %135 = phi i64 [ %73, %120 ], [ %247, %147 ]
  %136 = add i64 %133, 2
  %137 = icmp slt i64 %136, %133
  %138 = select i1 %137, i64 1, i64 0
  %139 = icmp sge i64 %133, %131
  %140 = icmp eq i64 %134, 0
  %141 = xor i1 %140, true
  %142 = or i1 %141, %139
  %143 = select i1 %142, i64 %133, i64 %136
  %144 = select i1 %142, i64 %134, i64 %138
  br i1 %142, label %145, label %147

145:                                              ; preds = %132
  %146 = call i64 @llvm.smax.i64(i64 %131, i64 %123)
  br label %248

147:                                              ; preds = %132
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %43, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %135, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %148 = insertvalue [2 x ptr] undef, ptr %24, 0
  %149 = insertvalue [2 x ptr] %148, ptr %23, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %149, ptr %22, align 8
  %150 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %151 = load ptr, ptr %150, align 8
  %152 = load i64, ptr %151, align 8
  %153 = trunc i64 %152 to i32
  %154 = getelementptr inbounds ptr, ptr %150, i32 1
  %155 = load ptr, ptr %154, align 8
  %156 = load i64, ptr %155, align 8
  %157 = trunc i64 %156 to i32
  %158 = mul i32 %153, 32
  %159 = mul i32 %157, 1024
  %160 = add i32 %158, %159
  %161 = sext i32 %160 to i64
  %162 = getelementptr inbounds float, ptr %38, i64 %161
  %163 = getelementptr inbounds float, ptr %162, i64 %46
  %164 = load <4 x float>, ptr %163, align 16, !invariant.load !1
  store <4 x float> %164, ptr addrspace(5) %48, align 16
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %41, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 %135, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %165 = insertvalue [2 x ptr] undef, ptr %21, 0
  %166 = insertvalue [2 x ptr] %165, ptr %20, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %166, ptr %19, align 8
  %167 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %168 = load ptr, ptr %167, align 8
  %169 = load i64, ptr %168, align 8
  %170 = getelementptr inbounds ptr, ptr %167, i32 1
  %171 = load ptr, ptr %170, align 8
  %172 = load i64, ptr %171, align 8
  %173 = mul i64 %169, 32
  %174 = mul i64 %172, 1024
  %175 = add i64 %173, %174
  %176 = getelementptr inbounds float, ptr %37, i64 %175
  %177 = getelementptr inbounds float, ptr %176, i64 %46
  %178 = load <4 x float>, ptr %177, align 16, !invariant.load !1
  %179 = load <4 x float>, ptr addrspace(5) %48, align 16
  %180 = load float, ptr addrspace(5) %49, align 4
  %181 = extractelement <4 x float> %178, i64 0
  %182 = extractelement <4 x float> %179, i64 0
  %183 = fmul contract float %181, %182
  %184 = fadd contract float %180, %183
  %185 = extractelement <4 x float> %178, i64 1
  %186 = extractelement <4 x float> %179, i64 1
  %187 = fmul contract float %185, %186
  %188 = fadd contract float %184, %187
  %189 = extractelement <4 x float> %178, i64 2
  %190 = extractelement <4 x float> %179, i64 2
  %191 = fmul contract float %189, %190
  %192 = fadd contract float %188, %191
  %193 = extractelement <4 x float> %178, i64 3
  %194 = extractelement <4 x float> %179, i64 3
  %195 = fmul contract float %193, %194
  %196 = fadd contract float %192, %195
  store float %196, ptr addrspace(5) %49, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %197 = add i64 %135, 1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %43, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %197, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %198 = insertvalue [2 x ptr] undef, ptr %18, 0
  %199 = insertvalue [2 x ptr] %198, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %199, ptr %16, align 8
  %200 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %201 = load ptr, ptr %200, align 8
  %202 = load i64, ptr %201, align 8
  %203 = trunc i64 %202 to i32
  %204 = getelementptr inbounds ptr, ptr %200, i32 1
  %205 = load ptr, ptr %204, align 8
  %206 = load i64, ptr %205, align 8
  %207 = trunc i64 %206 to i32
  %208 = mul i32 %203, 32
  %209 = mul i32 %207, 1024
  %210 = add i32 %208, %209
  %211 = sext i32 %210 to i64
  %212 = getelementptr inbounds float, ptr %38, i64 %211
  %213 = getelementptr inbounds float, ptr %212, i64 %46
  %214 = load <4 x float>, ptr %213, align 16, !invariant.load !1
  store <4 x float> %214, ptr addrspace(5) %48, align 16
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %41, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %197, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %215 = insertvalue [2 x ptr] undef, ptr %15, 0
  %216 = insertvalue [2 x ptr] %215, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %216, ptr %13, align 8
  %217 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %218 = load ptr, ptr %217, align 8
  %219 = load i64, ptr %218, align 8
  %220 = getelementptr inbounds ptr, ptr %217, i32 1
  %221 = load ptr, ptr %220, align 8
  %222 = load i64, ptr %221, align 8
  %223 = mul i64 %219, 32
  %224 = mul i64 %222, 1024
  %225 = add i64 %223, %224
  %226 = getelementptr inbounds float, ptr %37, i64 %225
  %227 = getelementptr inbounds float, ptr %226, i64 %46
  %228 = load <4 x float>, ptr %227, align 16, !invariant.load !1
  %229 = load <4 x float>, ptr addrspace(5) %48, align 16
  %230 = load float, ptr addrspace(5) %49, align 4
  %231 = extractelement <4 x float> %228, i64 0
  %232 = extractelement <4 x float> %229, i64 0
  %233 = fmul contract float %231, %232
  %234 = fadd contract float %230, %233
  %235 = extractelement <4 x float> %228, i64 1
  %236 = extractelement <4 x float> %229, i64 1
  %237 = fmul contract float %235, %236
  %238 = fadd contract float %234, %237
  %239 = extractelement <4 x float> %228, i64 2
  %240 = extractelement <4 x float> %229, i64 2
  %241 = fmul contract float %239, %240
  %242 = fadd contract float %238, %241
  %243 = extractelement <4 x float> %228, i64 3
  %244 = extractelement <4 x float> %229, i64 3
  %245 = fmul contract float %243, %244
  %246 = fadd contract float %242, %245
  store float %246, ptr addrspace(5) %49, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %247 = add i64 %197, 1
  br label %132

248:                                              ; preds = %252, %145
  %249 = phi i64 [ %131, %145 ], [ %255, %252 ]
  %250 = phi i64 [ %135, %145 ], [ %305, %252 ]
  %251 = icmp slt i64 %249, %146
  br i1 %251, label %252, label %306

252:                                              ; preds = %248
  %253 = icmp eq i64 %249, %146
  %254 = add i64 %249, 1
  %255 = select i1 %253, i64 %249, i64 %254
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %43, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %250, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %256 = insertvalue [2 x ptr] undef, ptr %12, 0
  %257 = insertvalue [2 x ptr] %256, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %257, ptr %10, align 8
  %258 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %259 = load ptr, ptr %258, align 8
  %260 = load i64, ptr %259, align 8
  %261 = trunc i64 %260 to i32
  %262 = getelementptr inbounds ptr, ptr %258, i32 1
  %263 = load ptr, ptr %262, align 8
  %264 = load i64, ptr %263, align 8
  %265 = trunc i64 %264 to i32
  %266 = mul i32 %261, 32
  %267 = mul i32 %265, 1024
  %268 = add i32 %266, %267
  %269 = sext i32 %268 to i64
  %270 = getelementptr inbounds float, ptr %38, i64 %269
  %271 = getelementptr inbounds float, ptr %270, i64 %46
  %272 = load <4 x float>, ptr %271, align 16, !invariant.load !1
  store <4 x float> %272, ptr addrspace(5) %48, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %41, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %250, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %273 = insertvalue [2 x ptr] undef, ptr %9, 0
  %274 = insertvalue [2 x ptr] %273, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %274, ptr %7, align 8
  %275 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %276 = load ptr, ptr %275, align 8
  %277 = load i64, ptr %276, align 8
  %278 = getelementptr inbounds ptr, ptr %275, i32 1
  %279 = load ptr, ptr %278, align 8
  %280 = load i64, ptr %279, align 8
  %281 = mul i64 %277, 32
  %282 = mul i64 %280, 1024
  %283 = add i64 %281, %282
  %284 = getelementptr inbounds float, ptr %37, i64 %283
  %285 = getelementptr inbounds float, ptr %284, i64 %46
  %286 = load <4 x float>, ptr %285, align 16, !invariant.load !1
  %287 = load <4 x float>, ptr addrspace(5) %48, align 16
  %288 = load float, ptr addrspace(5) %49, align 4
  %289 = extractelement <4 x float> %286, i64 0
  %290 = extractelement <4 x float> %287, i64 0
  %291 = fmul contract float %289, %290
  %292 = fadd contract float %288, %291
  %293 = extractelement <4 x float> %286, i64 1
  %294 = extractelement <4 x float> %287, i64 1
  %295 = fmul contract float %293, %294
  %296 = fadd contract float %292, %295
  %297 = extractelement <4 x float> %286, i64 2
  %298 = extractelement <4 x float> %287, i64 2
  %299 = fmul contract float %297, %298
  %300 = fadd contract float %296, %299
  %301 = extractelement <4 x float> %286, i64 3
  %302 = extractelement <4 x float> %287, i64 3
  %303 = fmul contract float %301, %302
  %304 = fadd contract float %300, %303
  store float %304, ptr addrspace(5) %49, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %305 = add i64 %250, 1
  br label %248

306:                                              ; preds = %248
  %307 = udiv i64 %47, 32
  %308 = trunc i64 %307 to i32
  %309 = sext i32 %308 to i64
  %310 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %311 = sext i32 %310 to i64
  %312 = trunc i64 %309 to i32
  %313 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %312
  %314 = load float, ptr addrspace(5) %49, align 4
  %315 = bitcast float %314 to i32
  %316 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %315, i32 16, i32 31)
  %317 = bitcast i32 %316 to float
  %318 = fadd contract float %314, %317
  %319 = bitcast float %318 to i32
  %320 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %319, i32 8, i32 31)
  %321 = bitcast i32 %320 to float
  %322 = fadd contract float %318, %321
  %323 = bitcast float %322 to i32
  %324 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %323, i32 4, i32 31)
  %325 = bitcast i32 %324 to float
  %326 = fadd contract float %322, %325
  %327 = bitcast float %326 to i32
  %328 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %327, i32 2, i32 31)
  %329 = bitcast i32 %328 to float
  %330 = fadd contract float %326, %329
  %331 = bitcast float %330 to i32
  %332 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %331, i32 1, i32 31)
  %333 = bitcast i32 %332 to float
  %334 = fadd contract float %330, %333
  %335 = icmp eq i64 %311, 0
  br i1 %335, label %336, label %337

336:                                              ; preds = %306
  store float %334, ptr addrspace(3) %313, align 4
  br label %338

337:                                              ; preds = %306
  br label %338

338:                                              ; preds = %337, %336
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %339

339:                                              ; preds = %352, %338
  %340 = phi i64 [ %47, %338 ], [ %349, %352 ]
  %341 = phi i64 [ 0, %338 ], [ %350, %352 ]
  %342 = add i64 %340, 256
  %343 = icmp slt i64 %342, %340
  %344 = select i1 %343, i64 1, i64 0
  %345 = icmp sge i64 %340, 1
  %346 = icmp eq i64 %341, 0
  %347 = xor i1 %346, true
  %348 = or i1 %347, %345
  %349 = select i1 %348, i64 %340, i64 %342
  %350 = select i1 %348, i64 %341, i64 %344
  br i1 %348, label %351, label %352

351:                                              ; preds = %339
  call void @llvm.lifetime.end.p0(ptr %32)
  call void @llvm.lifetime.end.p0(ptr %31)
  ret void

352:                                              ; preds = %339
  %353 = trunc i64 %340 to i32
  %354 = sext i32 %353 to i64
  %355 = trunc i64 %354 to i32
  %356 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %355
  %357 = load float, ptr addrspace(3) %356, align 4
  %358 = fadd contract float %357, 0.000000e+00
  %359 = add i64 %340, 1
  %360 = trunc i64 %359 to i32
  %361 = sext i32 %360 to i64
  %362 = trunc i64 %361 to i32
  %363 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %362
  %364 = load float, ptr addrspace(3) %363, align 4
  %365 = fadd contract float %358, %364
  %366 = add i64 %340, 2
  %367 = trunc i64 %366 to i32
  %368 = sext i32 %367 to i64
  %369 = trunc i64 %368 to i32
  %370 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %369
  %371 = load float, ptr addrspace(3) %370, align 4
  %372 = fadd contract float %365, %371
  %373 = add i64 %340, 3
  %374 = trunc i64 %373 to i32
  %375 = sext i32 %374 to i64
  %376 = trunc i64 %375 to i32
  %377 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %376
  %378 = load float, ptr addrspace(3) %377, align 4
  %379 = fadd contract float %372, %378
  %380 = add i64 %340, 4
  %381 = trunc i64 %380 to i32
  %382 = sext i32 %381 to i64
  %383 = trunc i64 %382 to i32
  %384 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %383
  %385 = load float, ptr addrspace(3) %384, align 4
  %386 = fadd contract float %379, %385
  %387 = add i64 %340, 5
  %388 = trunc i64 %387 to i32
  %389 = sext i32 %388 to i64
  %390 = trunc i64 %389 to i32
  %391 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %390
  %392 = load float, ptr addrspace(3) %391, align 4
  %393 = fadd contract float %386, %392
  %394 = add i64 %340, 6
  %395 = trunc i64 %394 to i32
  %396 = sext i32 %395 to i64
  %397 = trunc i64 %396 to i32
  %398 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %397
  %399 = load float, ptr addrspace(3) %398, align 4
  %400 = fadd contract float %393, %399
  %401 = add i64 %340, 7
  %402 = trunc i64 %401 to i32
  %403 = sext i32 %402 to i64
  %404 = trunc i64 %403 to i32
  %405 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_compute_fn_float32_float32_float32_256_1702ea23._global_alloc_0._gpu_shared_mem, i32 %404
  %406 = load float, ptr addrspace(3) %405, align 4
  %407 = fadd contract float %400, %406
  %408 = add i64 %41, %340
  %409 = mul i64 %408, 1000
  %410 = add i64 %409, %43
  %411 = sitofp i64 %410 to float
  %412 = fadd contract float %407, %411
  %413 = add i64 %408, %43
  %414 = getelementptr inbounds float, ptr %36, i64 %413
  store float %412, ptr %414, align 4
  br label %339
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
