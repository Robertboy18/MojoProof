; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }) %6) #0 {
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
  %20 = alloca [2 x ptr], i64 1, align 8
  %21 = alloca i64, i64 1, align 8
  %22 = alloca i64, i64 1, align 8
  %23 = alloca [2 x ptr], i64 1, align 8
  %24 = alloca i64, i64 1, align 8
  %25 = alloca i64, i64 1, align 8
  %26 = alloca [2 x ptr], i64 1, align 8
  %27 = alloca i64, i64 1, align 8
  %28 = alloca i64, i64 1, align 8
  %29 = alloca [2 x ptr], i64 1, align 8
  %30 = alloca i64, i64 1, align 8
  %31 = alloca i64, i64 1, align 8
  %32 = alloca float, i64 1, align 4
  %33 = alloca [4 x float], align 16
  %34 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %35 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %36 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %35, 0
  %37 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %34, 0
  %38 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 2
  %39 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 1
  %40 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 0
  %41 = sext i32 %5 to i64
  %42 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %43 = zext i32 %42 to i64
  %44 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %45 = zext i32 %44 to i64
  %46 = trunc i64 %45 to i32
  %47 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %48 = mul i32 %47, 4
  %49 = sext i32 %48 to i64
  %50 = zext i32 %47 to i64
  call void @llvm.lifetime.start.p0(ptr %33)
  %51 = addrspacecast ptr %33 to ptr addrspace(5)
  call void @llvm.lifetime.start.p0(ptr %32)
  %52 = addrspacecast ptr %32 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %52, align 4
  %53 = mul i64 %50, 4
  %54 = sub i64 %41, %53
  %55 = icmp slt i64 %53, %41
  br i1 %55, label %56, label %74

56:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i64 %45, ptr %31, align 8
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.start.p0(ptr %30)
  store i64 0, ptr %30, align 8
  call void @llvm.lifetime.end.p0(ptr %29)
  %57 = insertvalue [2 x ptr] undef, ptr %31, 0
  %58 = insertvalue [2 x ptr] %57, ptr %30, 1
  call void @llvm.lifetime.start.p0(ptr %29)
  store [2 x ptr] %58, ptr %29, align 8
  %59 = getelementptr inbounds [2 x ptr], ptr %29, i32 0, i32 0
  %60 = load ptr, ptr %59, align 8
  %61 = load i64, ptr %60, align 8
  %62 = trunc i64 %61 to i32
  %63 = getelementptr inbounds ptr, ptr %59, i32 1
  %64 = load ptr, ptr %63, align 8
  %65 = load i64, ptr %64, align 8
  %66 = trunc i64 %65 to i32
  %67 = mul i32 %62, 32
  %68 = mul i32 %66, 1024
  %69 = add i32 %67, %68
  %70 = sext i32 %69 to i64
  %71 = getelementptr inbounds float, ptr %37, i64 %70
  %72 = getelementptr inbounds float, ptr %71, i64 %49
  %73 = load <4 x float>, ptr %72, align 16, !invariant.load !1
  store <4 x float> %73, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  br label %75

74:                                               ; preds = %7
  br label %75

75:                                               ; preds = %74, %56
  %76 = select i1 %55, i64 1, i64 0
  br i1 %55, label %77, label %110

77:                                               ; preds = %75
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 %43, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 0, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  %78 = insertvalue [2 x ptr] undef, ptr %28, 0
  %79 = insertvalue [2 x ptr] %78, ptr %27, 1
  call void @llvm.lifetime.start.p0(ptr %26)
  store [2 x ptr] %79, ptr %26, align 8
  %80 = getelementptr inbounds [2 x ptr], ptr %26, i32 0, i32 0
  %81 = load ptr, ptr %80, align 8
  %82 = load i64, ptr %81, align 8
  %83 = getelementptr inbounds ptr, ptr %80, i32 1
  %84 = load ptr, ptr %83, align 8
  %85 = load i64, ptr %84, align 8
  %86 = mul i64 %82, 32
  %87 = mul i64 %85, 1024
  %88 = add i64 %86, %87
  %89 = getelementptr inbounds float, ptr %36, i64 %88
  %90 = getelementptr inbounds float, ptr %89, i64 %49
  %91 = load <4 x float>, ptr %90, align 16, !invariant.load !1
  %92 = load <4 x float>, ptr addrspace(5) %51, align 16
  %93 = load float, ptr addrspace(5) %52, align 4
  %94 = extractelement <4 x float> %91, i64 0
  %95 = extractelement <4 x float> %92, i64 0
  %96 = fmul contract float %94, %95
  %97 = fadd contract float %93, %96
  %98 = extractelement <4 x float> %91, i64 1
  %99 = extractelement <4 x float> %92, i64 1
  %100 = fmul contract float %98, %99
  %101 = fadd contract float %97, %100
  %102 = extractelement <4 x float> %91, i64 2
  %103 = extractelement <4 x float> %92, i64 2
  %104 = fmul contract float %102, %103
  %105 = fadd contract float %101, %104
  %106 = extractelement <4 x float> %91, i64 3
  %107 = extractelement <4 x float> %92, i64 3
  %108 = fmul contract float %106, %107
  %109 = fadd contract float %105, %108
  store float %109, ptr addrspace(5) %52, align 4
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  br label %111

110:                                              ; preds = %75
  br label %111

111:                                              ; preds = %110, %77
  %112 = icmp sgt i64 %41, %53
  br i1 %112, label %113, label %122

113:                                              ; preds = %111
  %114 = sdiv i64 %54, -1024
  %115 = mul i64 %114, -1024
  %116 = icmp eq i64 %115, %54
  %117 = xor i64 %54, -1024
  %118 = ashr i64 %117, 63
  %119 = select i1 %116, i64 0, i64 %118
  %120 = add i64 %114, %119
  %121 = sub i64 0, %120
  br label %123

122:                                              ; preds = %111
  br label %123

123:                                              ; preds = %122, %113
  %124 = phi i64 [ 0, %122 ], [ %121, %113 ]
  %125 = sub i64 %124, 1
  %126 = call i64 @llvm.smax.i64(i64 %125, i64 0)
  %127 = sdiv i64 %126, 2
  %128 = mul i64 %127, 2
  %129 = icmp eq i64 %128, %126
  %130 = xor i64 %126, 2
  %131 = ashr i64 %130, 63
  %132 = select i1 %129, i64 0, i64 %131
  %133 = add i64 %127, %132
  %134 = mul i64 %133, 2
  br label %135

135:                                              ; preds = %150, %123
  %136 = phi i64 [ 0, %123 ], [ %146, %150 ]
  %137 = phi i64 [ 0, %123 ], [ %147, %150 ]
  %138 = phi i64 [ %76, %123 ], [ %250, %150 ]
  %139 = add i64 %136, 2
  %140 = icmp slt i64 %139, %136
  %141 = select i1 %140, i64 1, i64 0
  %142 = icmp sge i64 %136, %134
  %143 = icmp eq i64 %137, 0
  %144 = xor i1 %143, true
  %145 = or i1 %144, %142
  %146 = select i1 %145, i64 %136, i64 %139
  %147 = select i1 %145, i64 %137, i64 %141
  br i1 %145, label %148, label %150

148:                                              ; preds = %135
  %149 = call i64 @llvm.smax.i64(i64 %134, i64 %126)
  br label %251

150:                                              ; preds = %135
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.start.p0(ptr %25)
  store i64 %45, ptr %25, align 8
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %138, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  %151 = insertvalue [2 x ptr] undef, ptr %25, 0
  %152 = insertvalue [2 x ptr] %151, ptr %24, 1
  call void @llvm.lifetime.start.p0(ptr %23)
  store [2 x ptr] %152, ptr %23, align 8
  %153 = getelementptr inbounds [2 x ptr], ptr %23, i32 0, i32 0
  %154 = load ptr, ptr %153, align 8
  %155 = load i64, ptr %154, align 8
  %156 = trunc i64 %155 to i32
  %157 = getelementptr inbounds ptr, ptr %153, i32 1
  %158 = load ptr, ptr %157, align 8
  %159 = load i64, ptr %158, align 8
  %160 = trunc i64 %159 to i32
  %161 = mul i32 %156, 32
  %162 = mul i32 %160, 1024
  %163 = add i32 %161, %162
  %164 = sext i32 %163 to i64
  %165 = getelementptr inbounds float, ptr %37, i64 %164
  %166 = getelementptr inbounds float, ptr %165, i64 %49
  %167 = load <4 x float>, ptr %166, align 16, !invariant.load !1
  store <4 x float> %167, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.start.p0(ptr %22)
  store i64 %43, ptr %22, align 8
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %138, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  %168 = insertvalue [2 x ptr] undef, ptr %22, 0
  %169 = insertvalue [2 x ptr] %168, ptr %21, 1
  call void @llvm.lifetime.start.p0(ptr %20)
  store [2 x ptr] %169, ptr %20, align 8
  %170 = getelementptr inbounds [2 x ptr], ptr %20, i32 0, i32 0
  %171 = load ptr, ptr %170, align 8
  %172 = load i64, ptr %171, align 8
  %173 = getelementptr inbounds ptr, ptr %170, i32 1
  %174 = load ptr, ptr %173, align 8
  %175 = load i64, ptr %174, align 8
  %176 = mul i64 %172, 32
  %177 = mul i64 %175, 1024
  %178 = add i64 %176, %177
  %179 = getelementptr inbounds float, ptr %36, i64 %178
  %180 = getelementptr inbounds float, ptr %179, i64 %49
  %181 = load <4 x float>, ptr %180, align 16, !invariant.load !1
  %182 = load <4 x float>, ptr addrspace(5) %51, align 16
  %183 = load float, ptr addrspace(5) %52, align 4
  %184 = extractelement <4 x float> %181, i64 0
  %185 = extractelement <4 x float> %182, i64 0
  %186 = fmul contract float %184, %185
  %187 = fadd contract float %183, %186
  %188 = extractelement <4 x float> %181, i64 1
  %189 = extractelement <4 x float> %182, i64 1
  %190 = fmul contract float %188, %189
  %191 = fadd contract float %187, %190
  %192 = extractelement <4 x float> %181, i64 2
  %193 = extractelement <4 x float> %182, i64 2
  %194 = fmul contract float %192, %193
  %195 = fadd contract float %191, %194
  %196 = extractelement <4 x float> %181, i64 3
  %197 = extractelement <4 x float> %182, i64 3
  %198 = fmul contract float %196, %197
  %199 = fadd contract float %195, %198
  store float %199, ptr addrspace(5) %52, align 4
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %22)
  %200 = add i64 %138, 1
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %45, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %200, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  %201 = insertvalue [2 x ptr] undef, ptr %19, 0
  %202 = insertvalue [2 x ptr] %201, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %17)
  store [2 x ptr] %202, ptr %17, align 8
  %203 = getelementptr inbounds [2 x ptr], ptr %17, i32 0, i32 0
  %204 = load ptr, ptr %203, align 8
  %205 = load i64, ptr %204, align 8
  %206 = trunc i64 %205 to i32
  %207 = getelementptr inbounds ptr, ptr %203, i32 1
  %208 = load ptr, ptr %207, align 8
  %209 = load i64, ptr %208, align 8
  %210 = trunc i64 %209 to i32
  %211 = mul i32 %206, 32
  %212 = mul i32 %210, 1024
  %213 = add i32 %211, %212
  %214 = sext i32 %213 to i64
  %215 = getelementptr inbounds float, ptr %37, i64 %214
  %216 = getelementptr inbounds float, ptr %215, i64 %49
  %217 = load <4 x float>, ptr %216, align 16, !invariant.load !1
  store <4 x float> %217, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 %43, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %200, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %218 = insertvalue [2 x ptr] undef, ptr %16, 0
  %219 = insertvalue [2 x ptr] %218, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %219, ptr %14, align 8
  %220 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %221 = load ptr, ptr %220, align 8
  %222 = load i64, ptr %221, align 8
  %223 = getelementptr inbounds ptr, ptr %220, i32 1
  %224 = load ptr, ptr %223, align 8
  %225 = load i64, ptr %224, align 8
  %226 = mul i64 %222, 32
  %227 = mul i64 %225, 1024
  %228 = add i64 %226, %227
  %229 = getelementptr inbounds float, ptr %36, i64 %228
  %230 = getelementptr inbounds float, ptr %229, i64 %49
  %231 = load <4 x float>, ptr %230, align 16, !invariant.load !1
  %232 = load <4 x float>, ptr addrspace(5) %51, align 16
  %233 = load float, ptr addrspace(5) %52, align 4
  %234 = extractelement <4 x float> %231, i64 0
  %235 = extractelement <4 x float> %232, i64 0
  %236 = fmul contract float %234, %235
  %237 = fadd contract float %233, %236
  %238 = extractelement <4 x float> %231, i64 1
  %239 = extractelement <4 x float> %232, i64 1
  %240 = fmul contract float %238, %239
  %241 = fadd contract float %237, %240
  %242 = extractelement <4 x float> %231, i64 2
  %243 = extractelement <4 x float> %232, i64 2
  %244 = fmul contract float %242, %243
  %245 = fadd contract float %241, %244
  %246 = extractelement <4 x float> %231, i64 3
  %247 = extractelement <4 x float> %232, i64 3
  %248 = fmul contract float %246, %247
  %249 = fadd contract float %245, %248
  store float %249, ptr addrspace(5) %52, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  %250 = add i64 %200, 1
  br label %135

251:                                              ; preds = %255, %148
  %252 = phi i64 [ %134, %148 ], [ %258, %255 ]
  %253 = phi i64 [ %138, %148 ], [ %308, %255 ]
  %254 = icmp slt i64 %252, %149
  br i1 %254, label %255, label %309

255:                                              ; preds = %251
  %256 = icmp eq i64 %252, %149
  %257 = add i64 %252, 1
  %258 = select i1 %256, i64 %252, i64 %257
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %45, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %253, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %259 = insertvalue [2 x ptr] undef, ptr %13, 0
  %260 = insertvalue [2 x ptr] %259, ptr %12, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %260, ptr %11, align 8
  %261 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %262 = load ptr, ptr %261, align 8
  %263 = load i64, ptr %262, align 8
  %264 = trunc i64 %263 to i32
  %265 = getelementptr inbounds ptr, ptr %261, i32 1
  %266 = load ptr, ptr %265, align 8
  %267 = load i64, ptr %266, align 8
  %268 = trunc i64 %267 to i32
  %269 = mul i32 %264, 32
  %270 = mul i32 %268, 1024
  %271 = add i32 %269, %270
  %272 = sext i32 %271 to i64
  %273 = getelementptr inbounds float, ptr %37, i64 %272
  %274 = getelementptr inbounds float, ptr %273, i64 %49
  %275 = load <4 x float>, ptr %274, align 16, !invariant.load !1
  store <4 x float> %275, ptr addrspace(5) %51, align 16
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %43, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %253, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %276 = insertvalue [2 x ptr] undef, ptr %10, 0
  %277 = insertvalue [2 x ptr] %276, ptr %9, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %277, ptr %8, align 8
  %278 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %279 = load ptr, ptr %278, align 8
  %280 = load i64, ptr %279, align 8
  %281 = getelementptr inbounds ptr, ptr %278, i32 1
  %282 = load ptr, ptr %281, align 8
  %283 = load i64, ptr %282, align 8
  %284 = mul i64 %280, 32
  %285 = mul i64 %283, 1024
  %286 = add i64 %284, %285
  %287 = getelementptr inbounds float, ptr %36, i64 %286
  %288 = getelementptr inbounds float, ptr %287, i64 %49
  %289 = load <4 x float>, ptr %288, align 16, !invariant.load !1
  %290 = load <4 x float>, ptr addrspace(5) %51, align 16
  %291 = load float, ptr addrspace(5) %52, align 4
  %292 = extractelement <4 x float> %289, i64 0
  %293 = extractelement <4 x float> %290, i64 0
  %294 = fmul contract float %292, %293
  %295 = fadd contract float %291, %294
  %296 = extractelement <4 x float> %289, i64 1
  %297 = extractelement <4 x float> %290, i64 1
  %298 = fmul contract float %296, %297
  %299 = fadd contract float %295, %298
  %300 = extractelement <4 x float> %289, i64 2
  %301 = extractelement <4 x float> %290, i64 2
  %302 = fmul contract float %300, %301
  %303 = fadd contract float %299, %302
  %304 = extractelement <4 x float> %289, i64 3
  %305 = extractelement <4 x float> %290, i64 3
  %306 = fmul contract float %304, %305
  %307 = fadd contract float %303, %306
  store float %307, ptr addrspace(5) %52, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %308 = add i64 %253, 1
  br label %251

309:                                              ; preds = %251
  %310 = udiv i64 %50, 32
  %311 = trunc i64 %310 to i32
  %312 = sext i32 %311 to i64
  %313 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %314 = sext i32 %313 to i64
  %315 = trunc i64 %312 to i32
  %316 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %315
  %317 = load float, ptr addrspace(5) %52, align 4
  %318 = bitcast float %317 to i32
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 16, i32 31)
  %320 = bitcast i32 %319 to float
  %321 = fadd contract float %317, %320
  %322 = bitcast float %321 to i32
  %323 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %322, i32 8, i32 31)
  %324 = bitcast i32 %323 to float
  %325 = fadd contract float %321, %324
  %326 = bitcast float %325 to i32
  %327 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %326, i32 4, i32 31)
  %328 = bitcast i32 %327 to float
  %329 = fadd contract float %325, %328
  %330 = bitcast float %329 to i32
  %331 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %330, i32 2, i32 31)
  %332 = bitcast i32 %331 to float
  %333 = fadd contract float %329, %332
  %334 = bitcast float %333 to i32
  %335 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %334, i32 1, i32 31)
  %336 = bitcast i32 %335 to float
  %337 = fadd contract float %333, %336
  %338 = icmp eq i64 %314, 0
  br i1 %338, label %339, label %340

339:                                              ; preds = %309
  store float %337, ptr addrspace(3) %316, align 4
  br label %341

340:                                              ; preds = %309
  br label %341

341:                                              ; preds = %340, %339
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %342

342:                                              ; preds = %355, %341
  %343 = phi i64 [ %50, %341 ], [ %352, %355 ]
  %344 = phi i64 [ 0, %341 ], [ %353, %355 ]
  %345 = add i64 %343, 256
  %346 = icmp slt i64 %345, %343
  %347 = select i1 %346, i64 1, i64 0
  %348 = icmp sge i64 %343, 1
  %349 = icmp eq i64 %344, 0
  %350 = xor i1 %349, true
  %351 = or i1 %350, %348
  %352 = select i1 %351, i64 %343, i64 %345
  %353 = select i1 %351, i64 %344, i64 %347
  br i1 %351, label %354, label %355

354:                                              ; preds = %342
  call void @llvm.lifetime.end.p0(ptr %33)
  call void @llvm.lifetime.end.p0(ptr %32)
  ret void

355:                                              ; preds = %342
  %356 = trunc i64 %343 to i32
  %357 = sext i32 %356 to i64
  %358 = trunc i64 %357 to i32
  %359 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %358
  %360 = load float, ptr addrspace(3) %359, align 4
  %361 = fadd contract float %360, 0.000000e+00
  %362 = add i64 %343, 1
  %363 = trunc i64 %362 to i32
  %364 = sext i32 %363 to i64
  %365 = trunc i64 %364 to i32
  %366 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %365
  %367 = load float, ptr addrspace(3) %366, align 4
  %368 = fadd contract float %361, %367
  %369 = add i64 %343, 2
  %370 = trunc i64 %369 to i32
  %371 = sext i32 %370 to i64
  %372 = trunc i64 %371 to i32
  %373 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %372
  %374 = load float, ptr addrspace(3) %373, align 4
  %375 = fadd contract float %368, %374
  %376 = add i64 %343, 3
  %377 = trunc i64 %376 to i32
  %378 = sext i32 %377 to i64
  %379 = trunc i64 %378 to i32
  %380 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %379
  %381 = load float, ptr addrspace(3) %380, align 4
  %382 = fadd contract float %375, %381
  %383 = add i64 %343, 4
  %384 = trunc i64 %383 to i32
  %385 = sext i32 %384 to i64
  %386 = trunc i64 %385 to i32
  %387 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %386
  %388 = load float, ptr addrspace(3) %387, align 4
  %389 = fadd contract float %382, %388
  %390 = add i64 %343, 5
  %391 = trunc i64 %390 to i32
  %392 = sext i32 %391 to i64
  %393 = trunc i64 %392 to i32
  %394 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %393
  %395 = load float, ptr addrspace(3) %394, align 4
  %396 = fadd contract float %389, %395
  %397 = add i64 %343, 6
  %398 = trunc i64 %397 to i32
  %399 = sext i32 %398 to i64
  %400 = trunc i64 %399 to i32
  %401 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %400
  %402 = load float, ptr addrspace(3) %401, align 4
  %403 = fadd contract float %396, %402
  %404 = add i64 %343, 7
  %405 = trunc i64 %404 to i32
  %406 = sext i32 %405 to i64
  %407 = trunc i64 %406 to i32
  %408 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_float32_float32_float32_256_77bd7ea1._global_alloc_0._gpu_shared_mem, i32 %407
  %409 = load float, ptr addrspace(3) %408, align 4
  %410 = fadd contract float %403, %409
  %411 = add i64 %43, %343
  %412 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %40, align 8
  %413 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %39, align 8
  %414 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %38, align 8
  %415 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %412, 0
  %416 = add i64 %411, %45
  %417 = getelementptr inbounds float, ptr %415, i64 %416
  store float %410, ptr %417, align 4
  %418 = trunc i64 %411 to i32
  %419 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %413, 0
  %420 = getelementptr inbounds i32, ptr %419, i64 %416
  store i32 %418, ptr %420, align 4
  %421 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %414, 0
  %422 = getelementptr inbounds i32, ptr %421, i64 %416
  store i32 %46, ptr %422, align 4
  br label %342
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
