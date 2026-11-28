; ModuleID = 'test_repack_q4_0.mojo'
source_filename = "test_repack_q4_0.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@extern_ptr_syml = external dso_local addrspace(3) global [0 x i8], align 1

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @repack_Q4_0_for_sm8x_bfloat16_cdec3ed7(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1) #0 {
  %3 = alloca [2 x ptr], i64 1, align 8
  %4 = alloca i64, i64 1, align 8
  %5 = alloca i64, i64 1, align 8
  %6 = alloca [2 x ptr], i64 1, align 8
  %7 = alloca i64, i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca i64, i64 1, align 8
  %14 = alloca i64, i64 1, align 8
  %15 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %16 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %17 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %16, 0
  %18 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %15, 0
  %19 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %20 = zext i32 %19 to i64
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %22 = sext i32 %21 to i64
  %23 = mul i64 %20, %22
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %25 = sext i32 %24 to i64
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.tid.z()
  %27 = zext i32 %26 to i64
  %28 = mul i64 %27, %25
  %29 = mul i64 %28, %22
  %30 = add i64 %29, %23
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %32 = zext i32 %31 to i64
  %33 = add i64 %30, %32
  %34 = udiv i64 %32, 32
  %35 = urem i64 %34, 2
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %35, ptr %14, align 8
  %36 = udiv i64 %34, 2
  call void @llvm.lifetime.end.p0(ptr %13)
  %37 = insertvalue [2 x ptr] undef, ptr %14, 0
  %38 = insertvalue [2 x ptr] %37, ptr %13, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %36, ptr %13, align 8
  %39 = urem i64 %32, 32
  %40 = mul i64 %39, 2
  %41 = trunc i64 %40 to i32
  %42 = sext i32 %41 to i64
  %43 = add i64 %40, 1
  %44 = trunc i64 %43 to i32
  %45 = sext i32 %44 to i64
  %46 = icmp slt i64 %39, 0
  %47 = mul i64 %39, 4
  %48 = trunc i64 %47 to i32
  %49 = sext i32 %48 to i64
  %50 = add i64 %47, 128
  %51 = trunc i64 %50 to i32
  %52 = sext i32 %51 to i64
  %53 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %54 = zext i32 %53 to i64
  %55 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %56 = zext i32 %55 to i64
  %57 = mul i64 %54, 2
  %58 = mul i64 %56, 32
  %59 = mul i64 %56, 16
  %60 = getelementptr inbounds i8, ptr %18, i32 65536
  br label %61

61:                                               ; preds = %874, %2
  %62 = phi i64 [ 0, %2 ], [ %67, %874 ]
  %63 = icmp slt i64 %62, 16
  br i1 %63, label %64, label %164

64:                                               ; preds = %61
  %65 = icmp eq i64 %62, 16
  %66 = add i64 %62, 1
  %67 = select i1 %65, i64 %62, i64 %66
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %68 = add i64 %59, %62
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %54, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %68, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %69 = insertvalue [2 x ptr] undef, ptr %12, 0
  %70 = insertvalue [2 x ptr] %69, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %70, ptr %10, align 8
  %71 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %72 = load ptr, ptr %71, align 8
  %73 = load i64, ptr %72, align 8
  %74 = trunc i64 %73 to i32
  %75 = getelementptr inbounds ptr, ptr %71, i32 1
  %76 = load ptr, ptr %75, align 8
  %77 = load i64, ptr %76, align 8
  %78 = trunc i64 %77 to i32
  %79 = mul i32 %74, 128
  %80 = mul i32 %79, 576
  %81 = mul i32 %78, 36
  %82 = add i32 %80, %81
  %83 = sext i32 %82 to i64
  %84 = getelementptr inbounds i8, ptr %17, i64 %83
  %85 = sdiv i64 %33, 1
  %86 = mul i64 %85, 1
  %87 = icmp eq i64 %86, %33
  %88 = xor i64 %33, 1
  %89 = ashr i64 %88, 63
  %90 = select i1 %87, i64 0, i64 %89
  %91 = add i64 %85, %90
  %92 = sdiv i64 %91, 128
  %93 = mul i64 %92, 128
  %94 = sub i64 %91, %93
  %95 = icmp slt i64 %91, 0
  %96 = icmp ne i64 %94, 0
  %97 = and i1 %95, %96
  %98 = select i1 %97, i64 128, i64 0
  %99 = add i64 %94, %98
  %100 = trunc i64 %99 to i32
  %101 = mul i32 %100, 576
  %102 = sdiv i64 %91, 1
  %103 = sub i64 %91, %102
  %104 = icmp ne i64 %103, 0
  %105 = and i1 %95, %104
  %106 = select i1 %105, i64 1, i64 0
  %107 = add i64 %103, %106
  %108 = trunc i64 %107 to i32
  %109 = mul i32 %108, 4
  %110 = add i32 %101, %109
  %111 = sext i32 %110 to i64
  %112 = getelementptr inbounds i8, ptr %84, i64 %111
  %113 = mul i32 %100, 36
  %114 = add i32 %113, %109
  %115 = sext i32 %114 to i64
  %116 = trunc i64 %115 to i32
  %117 = getelementptr inbounds i8, ptr addrspace(3) @extern_ptr_syml, i32 %116
  %118 = load <4 x i8>, ptr %112, align 4, !invariant.load !1
  store <4 x i8> %118, ptr addrspace(3) %117, align 4
  %119 = getelementptr inbounds i8, ptr %112, i32 4
  %120 = load <4 x i8>, ptr %119, align 4, !invariant.load !1
  %121 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 4
  store <4 x i8> %120, ptr addrspace(3) %121, align 4
  %122 = getelementptr inbounds i8, ptr %112, i32 8
  %123 = load <4 x i8>, ptr %122, align 4, !invariant.load !1
  %124 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 8
  store <4 x i8> %123, ptr addrspace(3) %124, align 4
  %125 = getelementptr inbounds i8, ptr %112, i32 12
  %126 = load <4 x i8>, ptr %125, align 4, !invariant.load !1
  %127 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 12
  store <4 x i8> %126, ptr addrspace(3) %127, align 4
  %128 = getelementptr inbounds i8, ptr %112, i32 16
  %129 = load <4 x i8>, ptr %128, align 4, !invariant.load !1
  %130 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 16
  store <4 x i8> %129, ptr addrspace(3) %130, align 4
  %131 = getelementptr inbounds i8, ptr %112, i32 20
  %132 = load <4 x i8>, ptr %131, align 4, !invariant.load !1
  %133 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 20
  store <4 x i8> %132, ptr addrspace(3) %133, align 4
  %134 = getelementptr inbounds i8, ptr %112, i32 24
  %135 = load <4 x i8>, ptr %134, align 4, !invariant.load !1
  %136 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 24
  store <4 x i8> %135, ptr addrspace(3) %136, align 4
  %137 = getelementptr inbounds i8, ptr %112, i32 28
  %138 = load <4 x i8>, ptr %137, align 4, !invariant.load !1
  %139 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 28
  store <4 x i8> %138, ptr addrspace(3) %139, align 4
  %140 = getelementptr inbounds i8, ptr %112, i32 32
  %141 = load <4 x i8>, ptr %140, align 4, !invariant.load !1
  %142 = getelementptr inbounds i8, ptr addrspace(3) %117, i32 32
  store <4 x i8> %141, ptr addrspace(3) %142, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %38, ptr %9, align 8
  %143 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %144 = load ptr, ptr %143, align 8
  %145 = load i64, ptr %144, align 8
  %146 = trunc i64 %145 to i32
  %147 = getelementptr inbounds ptr, ptr %143, i32 1
  %148 = load ptr, ptr %147, align 8
  %149 = load i64, ptr %148, align 8
  %150 = trunc i64 %149 to i32
  %151 = mul i32 %146, 64
  %152 = mul i32 %151, 36
  %153 = mul i32 %150, 18
  %154 = add i32 %152, %153
  %155 = sext i32 %154 to i64
  %156 = trunc i64 %155 to i32
  %157 = getelementptr inbounds i8, ptr addrspace(3) @extern_ptr_syml, i32 %156
  %158 = getelementptr inbounds i8, ptr addrspace(3) %157, i32 2
  %159 = mul i64 %62, 2
  %160 = add i64 %58, %159
  %161 = load i64, ptr %13, align 8
  %162 = add i64 %160, %161
  %163 = icmp slt i64 %162, 32
  br i1 %163, label %165, label %873

164:                                              ; preds = %61
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  ret void

165:                                              ; preds = %64
  %166 = sdiv i64 %39, 4
  %167 = mul i64 %166, 4
  %168 = icmp eq i64 %167, %39
  %169 = xor i64 %39, 4
  %170 = ashr i64 %169, 63
  %171 = select i1 %168, i64 0, i64 %170
  %172 = add i64 %166, %171
  %173 = sdiv i64 %172, 8
  %174 = mul i64 %173, 8
  %175 = sub i64 %172, %174
  %176 = icmp slt i64 %172, 0
  %177 = icmp ne i64 %175, 0
  %178 = and i1 %176, %177
  %179 = select i1 %178, i64 8, i64 0
  %180 = add i64 %175, %179
  %181 = trunc i64 %180 to i32
  %182 = mul i32 %181, 36
  %183 = sdiv i64 %39, 1
  %184 = mul i64 %183, 1
  %185 = icmp eq i64 %184, %39
  %186 = xor i64 %39, 1
  %187 = ashr i64 %186, 63
  %188 = select i1 %185, i64 0, i64 %187
  %189 = add i64 %183, %188
  %190 = sdiv i64 %189, 4
  %191 = mul i64 %190, 4
  %192 = sub i64 %189, %191
  %193 = icmp slt i64 %189, 0
  %194 = icmp ne i64 %192, 0
  %195 = and i1 %193, %194
  %196 = select i1 %195, i64 4, i64 0
  %197 = add i64 %192, %196
  %198 = trunc i64 %197 to i32
  %199 = mul i32 %198, 2
  %200 = add i32 %182, %199
  %201 = sext i32 %200 to i64
  %202 = trunc i64 %201 to i32
  %203 = getelementptr inbounds i8, ptr addrspace(3) %158, i32 %202
  %204 = load <2 x i8>, ptr addrspace(3) %203, align 2
  %205 = extractelement <2 x i8> %204, i64 0
  %206 = and i8 %205, 15
  %207 = extractelement <2 x i8> %204, i64 1
  %208 = and i8 %207, 15
  %209 = shl i8 %208, 4
  %210 = or i8 %206, %209
  %211 = insertelement <16 x i8> zeroinitializer, i8 %210, i64 0
  %212 = and i8 %205, -16
  %213 = lshr i8 %212, 4
  %214 = and i8 %207, -16
  %215 = or i8 %213, %214
  %216 = insertelement <16 x i8> zeroinitializer, i8 %215, i64 0
  %217 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 8
  %218 = load <2 x i8>, ptr addrspace(3) %217, align 2
  %219 = extractelement <2 x i8> %218, i64 0
  %220 = and i8 %219, 15
  %221 = extractelement <2 x i8> %218, i64 1
  %222 = and i8 %221, 15
  %223 = shl i8 %222, 4
  %224 = or i8 %220, %223
  %225 = insertelement <16 x i8> %211, i8 %224, i64 1
  %226 = and i8 %219, -16
  %227 = lshr i8 %226, 4
  %228 = and i8 %221, -16
  %229 = or i8 %227, %228
  %230 = insertelement <16 x i8> %216, i8 %229, i64 1
  %231 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 288
  %232 = load <2 x i8>, ptr addrspace(3) %231, align 2
  %233 = extractelement <2 x i8> %232, i64 0
  %234 = and i8 %233, 15
  %235 = extractelement <2 x i8> %232, i64 1
  %236 = and i8 %235, 15
  %237 = shl i8 %236, 4
  %238 = or i8 %234, %237
  %239 = insertelement <16 x i8> %225, i8 %238, i64 2
  %240 = and i8 %233, -16
  %241 = lshr i8 %240, 4
  %242 = and i8 %235, -16
  %243 = or i8 %241, %242
  %244 = insertelement <16 x i8> %230, i8 %243, i64 2
  %245 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 296
  %246 = load <2 x i8>, ptr addrspace(3) %245, align 2
  %247 = extractelement <2 x i8> %246, i64 0
  %248 = and i8 %247, 15
  %249 = extractelement <2 x i8> %246, i64 1
  %250 = and i8 %249, 15
  %251 = shl i8 %250, 4
  %252 = or i8 %248, %251
  %253 = insertelement <16 x i8> %239, i8 %252, i64 3
  %254 = and i8 %247, -16
  %255 = lshr i8 %254, 4
  %256 = and i8 %249, -16
  %257 = or i8 %255, %256
  %258 = insertelement <16 x i8> %244, i8 %257, i64 3
  %259 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 576
  %260 = load <2 x i8>, ptr addrspace(3) %259, align 2
  %261 = extractelement <2 x i8> %260, i64 0
  %262 = and i8 %261, 15
  %263 = extractelement <2 x i8> %260, i64 1
  %264 = and i8 %263, 15
  %265 = shl i8 %264, 4
  %266 = or i8 %262, %265
  %267 = insertelement <16 x i8> %253, i8 %266, i64 4
  %268 = and i8 %261, -16
  %269 = lshr i8 %268, 4
  %270 = and i8 %263, -16
  %271 = or i8 %269, %270
  %272 = insertelement <16 x i8> %258, i8 %271, i64 4
  %273 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 584
  %274 = load <2 x i8>, ptr addrspace(3) %273, align 2
  %275 = extractelement <2 x i8> %274, i64 0
  %276 = and i8 %275, 15
  %277 = extractelement <2 x i8> %274, i64 1
  %278 = and i8 %277, 15
  %279 = shl i8 %278, 4
  %280 = or i8 %276, %279
  %281 = insertelement <16 x i8> %267, i8 %280, i64 5
  %282 = and i8 %275, -16
  %283 = lshr i8 %282, 4
  %284 = and i8 %277, -16
  %285 = or i8 %283, %284
  %286 = insertelement <16 x i8> %272, i8 %285, i64 5
  %287 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 864
  %288 = load <2 x i8>, ptr addrspace(3) %287, align 2
  %289 = extractelement <2 x i8> %288, i64 0
  %290 = and i8 %289, 15
  %291 = extractelement <2 x i8> %288, i64 1
  %292 = and i8 %291, 15
  %293 = shl i8 %292, 4
  %294 = or i8 %290, %293
  %295 = insertelement <16 x i8> %281, i8 %294, i64 6
  %296 = and i8 %289, -16
  %297 = lshr i8 %296, 4
  %298 = and i8 %291, -16
  %299 = or i8 %297, %298
  %300 = insertelement <16 x i8> %286, i8 %299, i64 6
  %301 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 872
  %302 = load <2 x i8>, ptr addrspace(3) %301, align 2
  %303 = extractelement <2 x i8> %302, i64 0
  %304 = and i8 %303, 15
  %305 = extractelement <2 x i8> %302, i64 1
  %306 = and i8 %305, 15
  %307 = shl i8 %306, 4
  %308 = or i8 %304, %307
  %309 = insertelement <16 x i8> %295, i8 %308, i64 7
  %310 = and i8 %303, -16
  %311 = lshr i8 %310, 4
  %312 = and i8 %305, -16
  %313 = or i8 %311, %312
  %314 = insertelement <16 x i8> %300, i8 %313, i64 7
  %315 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 1152
  %316 = load <2 x i8>, ptr addrspace(3) %315, align 2
  %317 = extractelement <2 x i8> %316, i64 0
  %318 = and i8 %317, 15
  %319 = extractelement <2 x i8> %316, i64 1
  %320 = and i8 %319, 15
  %321 = shl i8 %320, 4
  %322 = or i8 %318, %321
  %323 = insertelement <16 x i8> %309, i8 %322, i64 8
  %324 = and i8 %317, -16
  %325 = lshr i8 %324, 4
  %326 = and i8 %319, -16
  %327 = or i8 %325, %326
  %328 = insertelement <16 x i8> %314, i8 %327, i64 8
  %329 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 1160
  %330 = load <2 x i8>, ptr addrspace(3) %329, align 2
  %331 = extractelement <2 x i8> %330, i64 0
  %332 = and i8 %331, 15
  %333 = extractelement <2 x i8> %330, i64 1
  %334 = and i8 %333, 15
  %335 = shl i8 %334, 4
  %336 = or i8 %332, %335
  %337 = insertelement <16 x i8> %323, i8 %336, i64 9
  %338 = and i8 %331, -16
  %339 = lshr i8 %338, 4
  %340 = and i8 %333, -16
  %341 = or i8 %339, %340
  %342 = insertelement <16 x i8> %328, i8 %341, i64 9
  %343 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 1440
  %344 = load <2 x i8>, ptr addrspace(3) %343, align 2
  %345 = extractelement <2 x i8> %344, i64 0
  %346 = and i8 %345, 15
  %347 = extractelement <2 x i8> %344, i64 1
  %348 = and i8 %347, 15
  %349 = shl i8 %348, 4
  %350 = or i8 %346, %349
  %351 = insertelement <16 x i8> %337, i8 %350, i64 10
  %352 = and i8 %345, -16
  %353 = lshr i8 %352, 4
  %354 = and i8 %347, -16
  %355 = or i8 %353, %354
  %356 = insertelement <16 x i8> %342, i8 %355, i64 10
  %357 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 1448
  %358 = load <2 x i8>, ptr addrspace(3) %357, align 2
  %359 = extractelement <2 x i8> %358, i64 0
  %360 = and i8 %359, 15
  %361 = extractelement <2 x i8> %358, i64 1
  %362 = and i8 %361, 15
  %363 = shl i8 %362, 4
  %364 = or i8 %360, %363
  %365 = insertelement <16 x i8> %351, i8 %364, i64 11
  %366 = and i8 %359, -16
  %367 = lshr i8 %366, 4
  %368 = and i8 %361, -16
  %369 = or i8 %367, %368
  %370 = insertelement <16 x i8> %356, i8 %369, i64 11
  %371 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 1728
  %372 = load <2 x i8>, ptr addrspace(3) %371, align 2
  %373 = extractelement <2 x i8> %372, i64 0
  %374 = and i8 %373, 15
  %375 = extractelement <2 x i8> %372, i64 1
  %376 = and i8 %375, 15
  %377 = shl i8 %376, 4
  %378 = or i8 %374, %377
  %379 = insertelement <16 x i8> %365, i8 %378, i64 12
  %380 = and i8 %373, -16
  %381 = lshr i8 %380, 4
  %382 = and i8 %375, -16
  %383 = or i8 %381, %382
  %384 = insertelement <16 x i8> %370, i8 %383, i64 12
  %385 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 1736
  %386 = load <2 x i8>, ptr addrspace(3) %385, align 2
  %387 = extractelement <2 x i8> %386, i64 0
  %388 = and i8 %387, 15
  %389 = extractelement <2 x i8> %386, i64 1
  %390 = and i8 %389, 15
  %391 = shl i8 %390, 4
  %392 = or i8 %388, %391
  %393 = insertelement <16 x i8> %379, i8 %392, i64 13
  %394 = and i8 %387, -16
  %395 = lshr i8 %394, 4
  %396 = and i8 %389, -16
  %397 = or i8 %395, %396
  %398 = insertelement <16 x i8> %384, i8 %397, i64 13
  %399 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 2016
  %400 = load <2 x i8>, ptr addrspace(3) %399, align 2
  %401 = extractelement <2 x i8> %400, i64 0
  %402 = and i8 %401, 15
  %403 = extractelement <2 x i8> %400, i64 1
  %404 = and i8 %403, 15
  %405 = shl i8 %404, 4
  %406 = or i8 %402, %405
  %407 = insertelement <16 x i8> %393, i8 %406, i64 14
  %408 = and i8 %401, -16
  %409 = lshr i8 %408, 4
  %410 = and i8 %403, -16
  %411 = or i8 %409, %410
  %412 = insertelement <16 x i8> %398, i8 %411, i64 14
  %413 = getelementptr inbounds i8, ptr addrspace(3) %203, i32 2024
  %414 = load <2 x i8>, ptr addrspace(3) %413, align 2
  %415 = extractelement <2 x i8> %414, i64 0
  %416 = and i8 %415, 15
  %417 = extractelement <2 x i8> %414, i64 1
  %418 = and i8 %417, 15
  %419 = shl i8 %418, 4
  %420 = or i8 %416, %419
  %421 = insertelement <16 x i8> %407, i8 %420, i64 15
  %422 = and i8 %415, -16
  %423 = lshr i8 %422, 4
  %424 = and i8 %417, -16
  %425 = or i8 %423, %424
  %426 = insertelement <16 x i8> %412, i8 %425, i64 15
  %427 = load i64, ptr %14, align 8
  %428 = add i64 %57, %427
  %429 = load i64, ptr %13, align 8
  %430 = add i64 %160, %429
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %428, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %430, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %431 = insertvalue [2 x ptr] undef, ptr %8, 0
  %432 = insertvalue [2 x ptr] %431, ptr %7, 1
  call void @llvm.lifetime.start.p0(ptr %6)
  store [2 x ptr] %432, ptr %6, align 8
  %433 = getelementptr inbounds [2 x ptr], ptr %6, i32 0, i32 0
  %434 = load ptr, ptr %433, align 8
  %435 = load i64, ptr %434, align 8
  %436 = trunc i64 %435 to i32
  %437 = getelementptr inbounds ptr, ptr %433, i32 1
  %438 = load ptr, ptr %437, align 8
  %439 = load i64, ptr %438, align 8
  %440 = trunc i64 %439 to i32
  %441 = mul i32 %436, 8192
  %442 = mul i32 %440, 256
  %443 = add i32 %441, %442
  %444 = sext i32 %443 to i64
  %445 = getelementptr inbounds i32, ptr %18, i64 %444
  %446 = extractelement <16 x i8> %421, i64 0
  %447 = zext i8 %446 to i32
  %448 = and i32 %447, 15
  %449 = or i32 %448, 0
  %450 = insertelement <4 x i32> zeroinitializer, i32 %449, i64 0
  %451 = and i32 %447, 240
  %452 = shl i32 %451, 12
  %453 = extractelement <4 x i32> %450, i64 0
  %454 = or i32 %453, %452
  %455 = insertelement <4 x i32> %450, i32 %454, i64 0
  %456 = extractelement <16 x i8> %421, i64 1
  %457 = zext i8 %456 to i32
  %458 = and i32 %457, 15
  %459 = shl i32 %458, 4
  %460 = extractelement <4 x i32> %455, i64 0
  %461 = or i32 %460, %459
  %462 = insertelement <4 x i32> %455, i32 %461, i64 0
  %463 = and i32 %457, 240
  %464 = shl i32 %463, 16
  %465 = extractelement <4 x i32> %462, i64 0
  %466 = or i32 %465, %464
  %467 = insertelement <4 x i32> %462, i32 %466, i64 0
  %468 = extractelement <16 x i8> %421, i64 2
  %469 = zext i8 %468 to i32
  %470 = and i32 %469, 15
  %471 = shl i32 %470, 8
  %472 = extractelement <4 x i32> %467, i64 0
  %473 = or i32 %472, %471
  %474 = insertelement <4 x i32> %467, i32 %473, i64 0
  %475 = and i32 %469, 240
  %476 = shl i32 %475, 20
  %477 = extractelement <4 x i32> %474, i64 0
  %478 = or i32 %477, %476
  %479 = insertelement <4 x i32> %474, i32 %478, i64 0
  %480 = extractelement <16 x i8> %421, i64 3
  %481 = zext i8 %480 to i32
  %482 = and i32 %481, 15
  %483 = shl i32 %482, 12
  %484 = extractelement <4 x i32> %479, i64 0
  %485 = or i32 %484, %483
  %486 = insertelement <4 x i32> %479, i32 %485, i64 0
  %487 = and i32 %481, 240
  %488 = shl i32 %487, 24
  %489 = extractelement <4 x i32> %486, i64 0
  %490 = or i32 %489, %488
  %491 = insertelement <4 x i32> %486, i32 %490, i64 0
  %492 = extractelement <16 x i8> %421, i64 4
  %493 = zext i8 %492 to i32
  %494 = and i32 %493, 15
  %495 = extractelement <4 x i32> %491, i64 1
  %496 = or i32 %495, %494
  %497 = insertelement <4 x i32> %491, i32 %496, i64 1
  %498 = and i32 %493, 240
  %499 = shl i32 %498, 12
  %500 = extractelement <4 x i32> %497, i64 1
  %501 = or i32 %500, %499
  %502 = insertelement <4 x i32> %497, i32 %501, i64 1
  %503 = extractelement <16 x i8> %421, i64 5
  %504 = zext i8 %503 to i32
  %505 = and i32 %504, 15
  %506 = shl i32 %505, 4
  %507 = extractelement <4 x i32> %502, i64 1
  %508 = or i32 %507, %506
  %509 = insertelement <4 x i32> %502, i32 %508, i64 1
  %510 = and i32 %504, 240
  %511 = shl i32 %510, 16
  %512 = extractelement <4 x i32> %509, i64 1
  %513 = or i32 %512, %511
  %514 = insertelement <4 x i32> %509, i32 %513, i64 1
  %515 = extractelement <16 x i8> %421, i64 6
  %516 = zext i8 %515 to i32
  %517 = and i32 %516, 15
  %518 = shl i32 %517, 8
  %519 = extractelement <4 x i32> %514, i64 1
  %520 = or i32 %519, %518
  %521 = insertelement <4 x i32> %514, i32 %520, i64 1
  %522 = and i32 %516, 240
  %523 = shl i32 %522, 20
  %524 = extractelement <4 x i32> %521, i64 1
  %525 = or i32 %524, %523
  %526 = insertelement <4 x i32> %521, i32 %525, i64 1
  %527 = extractelement <16 x i8> %421, i64 7
  %528 = zext i8 %527 to i32
  %529 = and i32 %528, 15
  %530 = shl i32 %529, 12
  %531 = extractelement <4 x i32> %526, i64 1
  %532 = or i32 %531, %530
  %533 = insertelement <4 x i32> %526, i32 %532, i64 1
  %534 = and i32 %528, 240
  %535 = shl i32 %534, 24
  %536 = extractelement <4 x i32> %533, i64 1
  %537 = or i32 %536, %535
  %538 = insertelement <4 x i32> %533, i32 %537, i64 1
  %539 = extractelement <16 x i8> %421, i64 8
  %540 = zext i8 %539 to i32
  %541 = and i32 %540, 15
  %542 = extractelement <4 x i32> %538, i64 2
  %543 = or i32 %542, %541
  %544 = insertelement <4 x i32> %538, i32 %543, i64 2
  %545 = and i32 %540, 240
  %546 = shl i32 %545, 12
  %547 = extractelement <4 x i32> %544, i64 2
  %548 = or i32 %547, %546
  %549 = insertelement <4 x i32> %544, i32 %548, i64 2
  %550 = extractelement <16 x i8> %421, i64 9
  %551 = zext i8 %550 to i32
  %552 = and i32 %551, 15
  %553 = shl i32 %552, 4
  %554 = extractelement <4 x i32> %549, i64 2
  %555 = or i32 %554, %553
  %556 = insertelement <4 x i32> %549, i32 %555, i64 2
  %557 = and i32 %551, 240
  %558 = shl i32 %557, 16
  %559 = extractelement <4 x i32> %556, i64 2
  %560 = or i32 %559, %558
  %561 = insertelement <4 x i32> %556, i32 %560, i64 2
  %562 = extractelement <16 x i8> %421, i64 10
  %563 = zext i8 %562 to i32
  %564 = and i32 %563, 15
  %565 = shl i32 %564, 8
  %566 = extractelement <4 x i32> %561, i64 2
  %567 = or i32 %566, %565
  %568 = insertelement <4 x i32> %561, i32 %567, i64 2
  %569 = and i32 %563, 240
  %570 = shl i32 %569, 20
  %571 = extractelement <4 x i32> %568, i64 2
  %572 = or i32 %571, %570
  %573 = insertelement <4 x i32> %568, i32 %572, i64 2
  %574 = extractelement <16 x i8> %421, i64 11
  %575 = zext i8 %574 to i32
  %576 = and i32 %575, 15
  %577 = shl i32 %576, 12
  %578 = extractelement <4 x i32> %573, i64 2
  %579 = or i32 %578, %577
  %580 = insertelement <4 x i32> %573, i32 %579, i64 2
  %581 = and i32 %575, 240
  %582 = shl i32 %581, 24
  %583 = extractelement <4 x i32> %580, i64 2
  %584 = or i32 %583, %582
  %585 = insertelement <4 x i32> %580, i32 %584, i64 2
  %586 = extractelement <16 x i8> %421, i64 12
  %587 = zext i8 %586 to i32
  %588 = and i32 %587, 15
  %589 = extractelement <4 x i32> %585, i64 3
  %590 = or i32 %589, %588
  %591 = insertelement <4 x i32> %585, i32 %590, i64 3
  %592 = and i32 %587, 240
  %593 = shl i32 %592, 12
  %594 = extractelement <4 x i32> %591, i64 3
  %595 = or i32 %594, %593
  %596 = insertelement <4 x i32> %591, i32 %595, i64 3
  %597 = extractelement <16 x i8> %421, i64 13
  %598 = zext i8 %597 to i32
  %599 = and i32 %598, 15
  %600 = shl i32 %599, 4
  %601 = extractelement <4 x i32> %596, i64 3
  %602 = or i32 %601, %600
  %603 = insertelement <4 x i32> %596, i32 %602, i64 3
  %604 = and i32 %598, 240
  %605 = shl i32 %604, 16
  %606 = extractelement <4 x i32> %603, i64 3
  %607 = or i32 %606, %605
  %608 = insertelement <4 x i32> %603, i32 %607, i64 3
  %609 = extractelement <16 x i8> %421, i64 14
  %610 = zext i8 %609 to i32
  %611 = and i32 %610, 15
  %612 = shl i32 %611, 8
  %613 = extractelement <4 x i32> %608, i64 3
  %614 = or i32 %613, %612
  %615 = insertelement <4 x i32> %608, i32 %614, i64 3
  %616 = and i32 %610, 240
  %617 = shl i32 %616, 20
  %618 = extractelement <4 x i32> %615, i64 3
  %619 = or i32 %618, %617
  %620 = insertelement <4 x i32> %615, i32 %619, i64 3
  %621 = extractelement <16 x i8> %421, i64 15
  %622 = zext i8 %621 to i32
  %623 = and i32 %622, 15
  %624 = shl i32 %623, 12
  %625 = extractelement <4 x i32> %620, i64 3
  %626 = or i32 %625, %624
  %627 = insertelement <4 x i32> %620, i32 %626, i64 3
  %628 = and i32 %622, 240
  %629 = shl i32 %628, 24
  %630 = extractelement <4 x i32> %627, i64 3
  %631 = or i32 %630, %629
  %632 = insertelement <4 x i32> %627, i32 %631, i64 3
  %633 = getelementptr inbounds i32, ptr %445, i64 %49
  store <4 x i32> %632, ptr %633, align 16
  %634 = extractelement <16 x i8> %426, i64 0
  %635 = zext i8 %634 to i32
  %636 = and i32 %635, 15
  %637 = or i32 %636, 0
  %638 = insertelement <4 x i32> zeroinitializer, i32 %637, i64 0
  %639 = and i32 %635, 240
  %640 = shl i32 %639, 12
  %641 = extractelement <4 x i32> %638, i64 0
  %642 = or i32 %641, %640
  %643 = insertelement <4 x i32> %638, i32 %642, i64 0
  %644 = extractelement <16 x i8> %426, i64 1
  %645 = zext i8 %644 to i32
  %646 = and i32 %645, 15
  %647 = shl i32 %646, 4
  %648 = extractelement <4 x i32> %643, i64 0
  %649 = or i32 %648, %647
  %650 = insertelement <4 x i32> %643, i32 %649, i64 0
  %651 = and i32 %645, 240
  %652 = shl i32 %651, 16
  %653 = extractelement <4 x i32> %650, i64 0
  %654 = or i32 %653, %652
  %655 = insertelement <4 x i32> %650, i32 %654, i64 0
  %656 = extractelement <16 x i8> %426, i64 2
  %657 = zext i8 %656 to i32
  %658 = and i32 %657, 15
  %659 = shl i32 %658, 8
  %660 = extractelement <4 x i32> %655, i64 0
  %661 = or i32 %660, %659
  %662 = insertelement <4 x i32> %655, i32 %661, i64 0
  %663 = and i32 %657, 240
  %664 = shl i32 %663, 20
  %665 = extractelement <4 x i32> %662, i64 0
  %666 = or i32 %665, %664
  %667 = insertelement <4 x i32> %662, i32 %666, i64 0
  %668 = extractelement <16 x i8> %426, i64 3
  %669 = zext i8 %668 to i32
  %670 = and i32 %669, 15
  %671 = shl i32 %670, 12
  %672 = extractelement <4 x i32> %667, i64 0
  %673 = or i32 %672, %671
  %674 = insertelement <4 x i32> %667, i32 %673, i64 0
  %675 = and i32 %669, 240
  %676 = shl i32 %675, 24
  %677 = extractelement <4 x i32> %674, i64 0
  %678 = or i32 %677, %676
  %679 = insertelement <4 x i32> %674, i32 %678, i64 0
  %680 = extractelement <16 x i8> %426, i64 4
  %681 = zext i8 %680 to i32
  %682 = and i32 %681, 15
  %683 = extractelement <4 x i32> %679, i64 1
  %684 = or i32 %683, %682
  %685 = insertelement <4 x i32> %679, i32 %684, i64 1
  %686 = and i32 %681, 240
  %687 = shl i32 %686, 12
  %688 = extractelement <4 x i32> %685, i64 1
  %689 = or i32 %688, %687
  %690 = insertelement <4 x i32> %685, i32 %689, i64 1
  %691 = extractelement <16 x i8> %426, i64 5
  %692 = zext i8 %691 to i32
  %693 = and i32 %692, 15
  %694 = shl i32 %693, 4
  %695 = extractelement <4 x i32> %690, i64 1
  %696 = or i32 %695, %694
  %697 = insertelement <4 x i32> %690, i32 %696, i64 1
  %698 = and i32 %692, 240
  %699 = shl i32 %698, 16
  %700 = extractelement <4 x i32> %697, i64 1
  %701 = or i32 %700, %699
  %702 = insertelement <4 x i32> %697, i32 %701, i64 1
  %703 = extractelement <16 x i8> %426, i64 6
  %704 = zext i8 %703 to i32
  %705 = and i32 %704, 15
  %706 = shl i32 %705, 8
  %707 = extractelement <4 x i32> %702, i64 1
  %708 = or i32 %707, %706
  %709 = insertelement <4 x i32> %702, i32 %708, i64 1
  %710 = and i32 %704, 240
  %711 = shl i32 %710, 20
  %712 = extractelement <4 x i32> %709, i64 1
  %713 = or i32 %712, %711
  %714 = insertelement <4 x i32> %709, i32 %713, i64 1
  %715 = extractelement <16 x i8> %426, i64 7
  %716 = zext i8 %715 to i32
  %717 = and i32 %716, 15
  %718 = shl i32 %717, 12
  %719 = extractelement <4 x i32> %714, i64 1
  %720 = or i32 %719, %718
  %721 = insertelement <4 x i32> %714, i32 %720, i64 1
  %722 = and i32 %716, 240
  %723 = shl i32 %722, 24
  %724 = extractelement <4 x i32> %721, i64 1
  %725 = or i32 %724, %723
  %726 = insertelement <4 x i32> %721, i32 %725, i64 1
  %727 = extractelement <16 x i8> %426, i64 8
  %728 = zext i8 %727 to i32
  %729 = and i32 %728, 15
  %730 = extractelement <4 x i32> %726, i64 2
  %731 = or i32 %730, %729
  %732 = insertelement <4 x i32> %726, i32 %731, i64 2
  %733 = and i32 %728, 240
  %734 = shl i32 %733, 12
  %735 = extractelement <4 x i32> %732, i64 2
  %736 = or i32 %735, %734
  %737 = insertelement <4 x i32> %732, i32 %736, i64 2
  %738 = extractelement <16 x i8> %426, i64 9
  %739 = zext i8 %738 to i32
  %740 = and i32 %739, 15
  %741 = shl i32 %740, 4
  %742 = extractelement <4 x i32> %737, i64 2
  %743 = or i32 %742, %741
  %744 = insertelement <4 x i32> %737, i32 %743, i64 2
  %745 = and i32 %739, 240
  %746 = shl i32 %745, 16
  %747 = extractelement <4 x i32> %744, i64 2
  %748 = or i32 %747, %746
  %749 = insertelement <4 x i32> %744, i32 %748, i64 2
  %750 = extractelement <16 x i8> %426, i64 10
  %751 = zext i8 %750 to i32
  %752 = and i32 %751, 15
  %753 = shl i32 %752, 8
  %754 = extractelement <4 x i32> %749, i64 2
  %755 = or i32 %754, %753
  %756 = insertelement <4 x i32> %749, i32 %755, i64 2
  %757 = and i32 %751, 240
  %758 = shl i32 %757, 20
  %759 = extractelement <4 x i32> %756, i64 2
  %760 = or i32 %759, %758
  %761 = insertelement <4 x i32> %756, i32 %760, i64 2
  %762 = extractelement <16 x i8> %426, i64 11
  %763 = zext i8 %762 to i32
  %764 = and i32 %763, 15
  %765 = shl i32 %764, 12
  %766 = extractelement <4 x i32> %761, i64 2
  %767 = or i32 %766, %765
  %768 = insertelement <4 x i32> %761, i32 %767, i64 2
  %769 = and i32 %763, 240
  %770 = shl i32 %769, 24
  %771 = extractelement <4 x i32> %768, i64 2
  %772 = or i32 %771, %770
  %773 = insertelement <4 x i32> %768, i32 %772, i64 2
  %774 = extractelement <16 x i8> %426, i64 12
  %775 = zext i8 %774 to i32
  %776 = and i32 %775, 15
  %777 = extractelement <4 x i32> %773, i64 3
  %778 = or i32 %777, %776
  %779 = insertelement <4 x i32> %773, i32 %778, i64 3
  %780 = and i32 %775, 240
  %781 = shl i32 %780, 12
  %782 = extractelement <4 x i32> %779, i64 3
  %783 = or i32 %782, %781
  %784 = insertelement <4 x i32> %779, i32 %783, i64 3
  %785 = extractelement <16 x i8> %426, i64 13
  %786 = zext i8 %785 to i32
  %787 = and i32 %786, 15
  %788 = shl i32 %787, 4
  %789 = extractelement <4 x i32> %784, i64 3
  %790 = or i32 %789, %788
  %791 = insertelement <4 x i32> %784, i32 %790, i64 3
  %792 = and i32 %786, 240
  %793 = shl i32 %792, 16
  %794 = extractelement <4 x i32> %791, i64 3
  %795 = or i32 %794, %793
  %796 = insertelement <4 x i32> %791, i32 %795, i64 3
  %797 = extractelement <16 x i8> %426, i64 14
  %798 = zext i8 %797 to i32
  %799 = and i32 %798, 15
  %800 = shl i32 %799, 8
  %801 = extractelement <4 x i32> %796, i64 3
  %802 = or i32 %801, %800
  %803 = insertelement <4 x i32> %796, i32 %802, i64 3
  %804 = and i32 %798, 240
  %805 = shl i32 %804, 20
  %806 = extractelement <4 x i32> %803, i64 3
  %807 = or i32 %806, %805
  %808 = insertelement <4 x i32> %803, i32 %807, i64 3
  %809 = extractelement <16 x i8> %426, i64 15
  %810 = zext i8 %809 to i32
  %811 = and i32 %810, 15
  %812 = shl i32 %811, 12
  %813 = extractelement <4 x i32> %808, i64 3
  %814 = or i32 %813, %812
  %815 = insertelement <4 x i32> %808, i32 %814, i64 3
  %816 = and i32 %810, 240
  %817 = shl i32 %816, 24
  %818 = extractelement <4 x i32> %815, i64 3
  %819 = or i32 %818, %817
  %820 = insertelement <4 x i32> %815, i32 %819, i64 3
  %821 = getelementptr inbounds i32, ptr %445, i64 %52
  store <4 x i32> %820, ptr %821, align 16
  %822 = sub i64 %39, %167
  %823 = icmp ne i64 %822, 0
  %824 = and i1 %46, %823
  %825 = select i1 %824, i64 1, i64 0
  %826 = sub i64 %166, %825
  %827 = select i1 %824, i64 4, i64 0
  %828 = add i64 %822, %827
  %829 = mul i64 %828, 16
  %830 = add i64 %829, %826
  %831 = load i64, ptr %13, align 8
  %832 = add i64 %160, %831
  %833 = load i64, ptr %14, align 8
  %834 = add i64 %57, %833
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %832, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %834, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %835 = insertvalue [2 x ptr] undef, ptr %5, 0
  %836 = insertvalue [2 x ptr] %835, ptr %4, 1
  call void @llvm.lifetime.start.p0(ptr %3)
  store [2 x ptr] %836, ptr %3, align 8
  %837 = getelementptr inbounds [2 x ptr], ptr %3, i32 0, i32 0
  %838 = load ptr, ptr %837, align 8
  %839 = load i64, ptr %838, align 8
  %840 = trunc i64 %839 to i32
  %841 = getelementptr inbounds ptr, ptr %837, i32 1
  %842 = load ptr, ptr %841, align 8
  %843 = load i64, ptr %842, align 8
  %844 = trunc i64 %843 to i32
  %845 = mul i32 %840, 128
  %846 = mul i32 %844, 64
  %847 = add i32 %845, %846
  %848 = sext i32 %847 to i64
  %849 = getelementptr inbounds bfloat, ptr %60, i64 %848
  %850 = trunc i64 %830 to i32
  %851 = mul i32 %850, 36
  %852 = sext i32 %851 to i64
  %853 = trunc i64 %852 to i32
  %854 = getelementptr inbounds i8, ptr addrspace(3) %157, i32 %853
  %855 = load <2 x i8>, ptr addrspace(3) %854, align 2
  %856 = bitcast <2 x i8> %855 to half
  %857 = fpext half %856 to float
  %858 = bitcast float %857 to <2 x bfloat>
  %859 = extractelement <2 x bfloat> %858, i64 1
  %860 = getelementptr inbounds bfloat, ptr %849, i64 %42
  store bfloat %859, ptr %860, align 2
  %861 = add i64 %830, 8
  %862 = trunc i64 %861 to i32
  %863 = mul i32 %862, 36
  %864 = sext i32 %863 to i64
  %865 = trunc i64 %864 to i32
  %866 = getelementptr inbounds i8, ptr addrspace(3) %157, i32 %865
  %867 = load <2 x i8>, ptr addrspace(3) %866, align 2
  %868 = bitcast <2 x i8> %867 to half
  %869 = fpext half %868 to float
  %870 = bitcast float %869 to <2 x bfloat>
  %871 = extractelement <2 x bfloat> %870, i64 1
  %872 = getelementptr inbounds bfloat, ptr %849, i64 %45
  store bfloat %871, ptr %872, align 2
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %874

873:                                              ; preds = %64
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  br label %874

874:                                              ; preds = %873, %165
  br label %61
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 64) i32 @llvm.nvvm.read.ptx.sreg.tid.z() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #3

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
