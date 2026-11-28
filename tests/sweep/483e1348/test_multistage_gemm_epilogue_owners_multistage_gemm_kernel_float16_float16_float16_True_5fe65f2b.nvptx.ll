; ModuleID = 'test_multistage_gemm_epilogue_owners.mojo'
source_filename = "test_multistage_gemm_epilogue_owners.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@extern_ptr_syml_4 = external dso_local addrspace(3) global [0 x half], align 16

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @multistage_gemm_kernel_float16_float16_float16_True_5fe65f2b(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = alloca { i64 }, i64 1, align 8
  %5 = alloca { i64 }, i64 1, align 8
  %6 = alloca [4 x ptr], i64 1, align 8
  %7 = alloca float, i64 1, align 4
  %8 = alloca float, i64 1, align 4
  %9 = alloca float, i64 1, align 4
  %10 = alloca float, i64 1, align 4
  %11 = alloca [4 x ptr], i64 1, align 8
  %12 = alloca float, i64 1, align 4
  %13 = alloca float, i64 1, align 4
  %14 = alloca float, i64 1, align 4
  %15 = alloca float, i64 1, align 4
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
  %31 = alloca [2 x ptr], i64 1, align 8
  %32 = alloca i64, i64 1, align 8
  %33 = alloca i64, i64 1, align 8
  %34 = alloca [2 x ptr], i64 1, align 8
  %35 = alloca [2 x ptr], i64 1, align 8
  %36 = alloca i64, i64 1, align 8
  %37 = alloca i64, i64 1, align 8
  %38 = alloca [4 x ptr], i64 1, align 8
  %39 = alloca float, i64 1, align 4
  %40 = alloca float, i64 1, align 4
  %41 = alloca float, i64 1, align 4
  %42 = alloca float, i64 1, align 4
  %43 = alloca [4 x ptr], i64 1, align 8
  %44 = alloca float, i64 1, align 4
  %45 = alloca float, i64 1, align 4
  %46 = alloca float, i64 1, align 4
  %47 = alloca float, i64 1, align 4
  %48 = alloca [2 x ptr], i64 1, align 8
  %49 = alloca i64, i64 1, align 8
  %50 = alloca i64, i64 1, align 8
  %51 = alloca [2 x ptr], i64 1, align 8
  %52 = alloca i64, i64 1, align 8
  %53 = alloca i64, i64 1, align 8
  %54 = alloca [2 x ptr], i64 1, align 8
  %55 = alloca i64, i64 1, align 8
  %56 = alloca i64, i64 1, align 8
  %57 = alloca [2 x ptr], i64 1, align 8
  %58 = alloca i64, i64 1, align 8
  %59 = alloca i64, i64 1, align 8
  %60 = alloca [2 x ptr], i64 1, align 8
  %61 = alloca i64, i64 1, align 8
  %62 = alloca i64, i64 1, align 8
  %63 = alloca [2 x ptr], i64 1, align 8
  %64 = alloca i64, i64 1, align 8
  %65 = alloca i64, i64 1, align 8
  %66 = alloca [2 x ptr], i64 1, align 8
  %67 = alloca [2 x ptr], i64 1, align 8
  %68 = alloca i64, i64 1, align 8
  %69 = alloca i64, i64 1, align 8
  %70 = alloca [2 x ptr], i64 1, align 8
  %71 = alloca i64, i64 1, align 8
  %72 = alloca i64, i64 1, align 8
  %73 = alloca [2 x ptr], i64 1, align 8
  %74 = alloca i64, i64 1, align 8
  %75 = alloca i64, i64 1, align 8
  %76 = alloca [2 x ptr], i64 1, align 8
  %77 = alloca i64, i64 1, align 8
  %78 = alloca i64, i64 1, align 8
  %79 = alloca [2 x ptr], i64 1, align 8
  %80 = alloca i64, i64 1, align 8
  %81 = alloca i64, i64 1, align 8
  %82 = alloca [2 x ptr], i64 1, align 8
  %83 = alloca i64, i64 1, align 8
  %84 = alloca i64, i64 1, align 8
  %85 = alloca [2 x ptr], i64 1, align 8
  %86 = alloca i64, i64 1, align 8
  %87 = alloca i64, i64 1, align 8
  %88 = alloca [16 x half], align 2
  %89 = alloca [16 x half], align 2
  %90 = alloca { i64 }, i64 1, align 8
  %91 = alloca [8 x float], align 4
  %92 = alloca [2 x ptr], i64 1, align 8
  %93 = alloca i32, i64 1, align 4
  %94 = alloca i32, i64 1, align 4
  %95 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %96 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %97 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %98 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %97, 0
  %99 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %96, 0
  %100 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %95, 0
  %101 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %102 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %103 = zext i32 %101 to i64
  %104 = urem i64 %103, 128
  %105 = udiv i64 %104, 32
  %106 = bitcast i64 %105 to <2 x i32>
  %107 = extractelement <2 x i32> %106, i64 0
  %108 = extractelement <2 x i32> %106, i64 1
  %109 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %107, i32 0, i32 31)
  %110 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %108, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %94)
  call void @llvm.lifetime.start.p0(ptr %94)
  store i32 %109, ptr %94, align 4
  call void @llvm.lifetime.end.p0(ptr %93)
  call void @llvm.lifetime.start.p0(ptr %93)
  store i32 %110, ptr %93, align 4
  call void @llvm.lifetime.end.p0(ptr %92)
  %111 = insertvalue [2 x ptr] undef, ptr %94, 0
  %112 = insertvalue [2 x ptr] %111, ptr %93, 1
  call void @llvm.lifetime.start.p0(ptr %92)
  store [2 x ptr] %112, ptr %92, align 8
  %113 = getelementptr inbounds [2 x ptr], ptr %92, i32 0, i32 0
  %114 = load ptr, ptr %113, align 8
  %115 = load i32, ptr %114, align 4
  %116 = insertelement <2 x i32> undef, i32 %115, i64 0
  %117 = getelementptr inbounds ptr, ptr %113, i32 1
  %118 = load ptr, ptr %117, align 8
  %119 = load i32, ptr %118, align 4
  %120 = insertelement <2 x i32> %116, i32 %119, i64 1
  call void @llvm.lifetime.end.p0(ptr %92)
  call void @llvm.lifetime.end.p0(ptr %93)
  call void @llvm.lifetime.end.p0(ptr %94)
  %121 = bitcast <2 x i32> %120 to i64
  %122 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %123 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %124 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %125 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.y()
  br label %126

126:                                              ; preds = %135, %3
  %127 = phi i64 [ 8, %3 ], [ %138, %135 ]
  %128 = phi i32 [ 3, %3 ], [ %136, %135 ]
  %129 = sub i64 %127, 1
  %130 = trunc i64 %129 to i32
  %131 = and i32 %124, %130
  %132 = icmp ne i32 %131, 0
  %133 = icmp ugt i32 %128, 0
  %134 = select i1 %132, i1 %133, i1 false
  br i1 %134, label %135, label %139

135:                                              ; preds = %126
  %136 = sub i32 %128, 1
  %137 = zext i32 %136 to i64
  %138 = shl i64 1, %137
  br label %126

139:                                              ; preds = %126
  %140 = lshr i32 %122, %128
  %141 = shl i32 %123, %128
  %142 = zext i32 %128 to i64
  %143 = shl i64 1, %142
  %144 = sub i64 %143, 1
  %145 = trunc i64 %144 to i32
  %146 = and i32 %122, %145
  %147 = add i32 %141, %146
  %148 = icmp eq i32 %125, 0
  %149 = select i1 %148, i32 1, i32 %125
  %150 = udiv i32 %147, %149
  %151 = select i1 %148, i32 0, i32 %150
  %152 = lshr i32 %124, %128
  %153 = mul i32 %151, %152
  %154 = add i32 %140, %153
  %155 = urem i32 %147, %149
  %156 = select i1 %148, i32 0, i32 %155
  %157 = zext i32 %156 to i64
  %158 = zext i32 %154 to i64
  %159 = udiv i64 %121, 2
  %160 = urem i64 %121, 2
  %161 = mul i64 %157, 32
  %162 = trunc i64 %157 to i32
  %163 = mul i32 %162, 32
  %164 = mul i32 %163, 512
  %165 = sext i32 %164 to i64
  %166 = getelementptr inbounds half, ptr %99, i64 %165
  %167 = mul i64 %158, 32
  %168 = trunc i64 %158 to i32
  %169 = mul i32 %168, 32
  %170 = mul i32 %169, 512
  %171 = sext i32 %170 to i64
  %172 = getelementptr inbounds half, ptr %100, i64 %171
  %173 = sub i64 32, %167
  call void @llvm.lifetime.start.p0(ptr %91)
  %174 = addrspacecast ptr %91 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %174, align 4
  %175 = getelementptr inbounds float, ptr addrspace(5) %174, i32 4
  store float 0.000000e+00, ptr addrspace(5) %175, align 4
  %176 = getelementptr inbounds float, ptr addrspace(5) %174, i32 1
  store float 0.000000e+00, ptr addrspace(5) %176, align 4
  %177 = getelementptr inbounds float, ptr addrspace(5) %174, i32 5
  store float 0.000000e+00, ptr addrspace(5) %177, align 4
  %178 = getelementptr inbounds float, ptr addrspace(5) %174, i32 2
  store float 0.000000e+00, ptr addrspace(5) %178, align 4
  %179 = getelementptr inbounds float, ptr addrspace(5) %174, i32 6
  store float 0.000000e+00, ptr addrspace(5) %179, align 4
  %180 = getelementptr inbounds float, ptr addrspace(5) %174, i32 3
  store float 0.000000e+00, ptr addrspace(5) %180, align 4
  %181 = getelementptr inbounds float, ptr addrspace(5) %174, i32 7
  store float 0.000000e+00, ptr addrspace(5) %181, align 4
  call void @llvm.lifetime.start.p0(ptr %90)
  %182 = getelementptr { { i64 } }, ptr %90, i32 0, i32 0
  %183 = getelementptr { i64 }, ptr %182, i32 0, i32 0
  store i64 %173, ptr %183, align 8
  %184 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %185 = zext i32 %184 to i64
  %186 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %187 = sext i32 %186 to i64
  %188 = mul i64 %185, %187
  %189 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %190 = sext i32 %189 to i64
  %191 = call i32 @llvm.nvvm.read.ptx.sreg.tid.z()
  %192 = zext i32 %191 to i64
  %193 = mul i64 %192, %190
  %194 = mul i64 %193, %187
  %195 = add i64 %194, %188
  %196 = add i64 %195, %103
  %197 = trunc i64 %104 to i32
  %198 = udiv i32 %197, 32
  %199 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %198, i32 0, i32 31)
  %200 = udiv i32 %199, 2
  %201 = urem i32 %199, 2
  %202 = sdiv i64 %196, 4
  %203 = mul i64 %202, 4
  %204 = icmp eq i64 %203, %196
  %205 = xor i64 %196, 4
  %206 = ashr i64 %205, 63
  %207 = select i1 %204, i64 0, i64 %206
  %208 = add i64 %202, %207
  %209 = sdiv i64 %208, 32
  %210 = mul i64 %209, 32
  %211 = sub i64 %208, %210
  %212 = icmp slt i64 %208, 0
  %213 = icmp ne i64 %211, 0
  %214 = and i1 %212, %213
  %215 = select i1 %214, i64 32, i64 0
  %216 = add i64 %211, %215
  %217 = trunc i64 %216 to i32
  %218 = mul i32 %217, 512
  %219 = sdiv i64 %196, 1
  %220 = mul i64 %219, 1
  %221 = icmp eq i64 %220, %196
  %222 = xor i64 %196, 1
  %223 = ashr i64 %222, 63
  %224 = select i1 %221, i64 0, i64 %223
  %225 = add i64 %219, %224
  %226 = sdiv i64 %225, 4
  %227 = mul i64 %226, 4
  %228 = sub i64 %225, %227
  %229 = icmp slt i64 %225, 0
  %230 = icmp ne i64 %228, 0
  %231 = and i1 %229, %230
  %232 = select i1 %231, i64 4, i64 0
  %233 = add i64 %228, %232
  %234 = trunc i64 %233 to i32
  %235 = mul i32 %234, 8
  %236 = add i32 %218, %235
  %237 = sext i32 %236 to i64
  %238 = getelementptr inbounds half, ptr %166, i64 %237
  %239 = mul i32 %217, 32
  %240 = add i32 %239, %235
  %241 = sext i32 %240 to i64
  %242 = trunc i64 %241 to i32
  %243 = getelementptr inbounds half, ptr addrspace(3) @extern_ptr_syml_4, i32 %242
  %244 = ptrtoint ptr addrspace(3) %243 to i64
  %245 = sub i64 %244, ptrtoint (ptr addrspace(3) @extern_ptr_syml_4 to i64)
  %246 = sdiv i64 %245, 2
  %247 = mul i64 %246, 2
  %248 = icmp eq i64 %247, %245
  %249 = xor i64 %245, 2
  %250 = ashr i64 %249, 63
  %251 = select i1 %248, i64 0, i64 %250
  %252 = add i64 %246, %251
  %253 = trunc i64 %252 to i32
  %254 = addrspacecast ptr %238 to ptr addrspace(1)
  %255 = and i32 %253, 192
  %256 = ashr i32 %255, 3
  %257 = xor i32 %253, %256
  %258 = sub i32 %257, %253
  %259 = sext i32 %258 to i64
  %260 = trunc i64 %259 to i32
  %261 = getelementptr inbounds half, ptr addrspace(3) %243, i32 %260
  %262 = ptrtoint ptr addrspace(3) %261 to i64
  %263 = trunc i64 %262 to i32
  call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %263, ptr addrspace(1) %254, i32 16)
  %264 = getelementptr inbounds half, ptr %172, i64 %237
  %265 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 6144), i32 %242
  %266 = ptrtoint ptr addrspace(3) %265 to i64
  %267 = sub i64 %266, ptrtoint (ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 6144) to i64)
  %268 = sdiv i64 %267, 2
  %269 = mul i64 %268, 2
  %270 = icmp eq i64 %269, %267
  %271 = xor i64 %267, 2
  %272 = ashr i64 %271, 63
  %273 = select i1 %270, i64 0, i64 %272
  %274 = add i64 %268, %273
  %275 = trunc i64 %274 to i32
  %276 = addrspacecast ptr %264 to ptr addrspace(1)
  %277 = and i32 %275, 192
  %278 = ashr i32 %277, 3
  %279 = xor i32 %275, %278
  %280 = sub i32 %279, %275
  %281 = sext i32 %280 to i64
  %282 = trunc i64 %281 to i32
  %283 = getelementptr inbounds half, ptr addrspace(3) %265, i32 %282
  %284 = ptrtoint ptr addrspace(3) %283 to i64
  %285 = trunc i64 %284 to i32
  call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %285, ptr addrspace(1) %276, i32 16)
  %286 = getelementptr inbounds half, ptr %172, i32 32
  %287 = getelementptr inbounds half, ptr %166, i32 32
  call void @llvm.nvvm.cp.async.commit.group()
  %288 = getelementptr inbounds half, ptr %287, i64 %237
  %289 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 2048), i32 %242
  %290 = ptrtoint ptr addrspace(3) %289 to i64
  %291 = sub i64 %290, ptrtoint (ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 2048) to i64)
  %292 = sdiv i64 %291, 2
  %293 = mul i64 %292, 2
  %294 = icmp eq i64 %293, %291
  %295 = xor i64 %291, 2
  %296 = ashr i64 %295, 63
  %297 = select i1 %294, i64 0, i64 %296
  %298 = add i64 %292, %297
  %299 = trunc i64 %298 to i32
  %300 = addrspacecast ptr %288 to ptr addrspace(1)
  %301 = and i32 %299, 192
  %302 = ashr i32 %301, 3
  %303 = xor i32 %299, %302
  %304 = sub i32 %303, %299
  %305 = sext i32 %304 to i64
  %306 = trunc i64 %305 to i32
  %307 = getelementptr inbounds half, ptr addrspace(3) %289, i32 %306
  %308 = ptrtoint ptr addrspace(3) %307 to i64
  %309 = trunc i64 %308 to i32
  call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %309, ptr addrspace(1) %300, i32 16)
  %310 = getelementptr inbounds half, ptr %286, i64 %237
  %311 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 8192), i32 %242
  %312 = ptrtoint ptr addrspace(3) %311 to i64
  %313 = sub i64 %312, ptrtoint (ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 8192) to i64)
  %314 = sdiv i64 %313, 2
  %315 = mul i64 %314, 2
  %316 = icmp eq i64 %315, %313
  %317 = xor i64 %313, 2
  %318 = ashr i64 %317, 63
  %319 = select i1 %316, i64 0, i64 %318
  %320 = add i64 %314, %319
  %321 = trunc i64 %320 to i32
  %322 = addrspacecast ptr %310 to ptr addrspace(1)
  %323 = and i32 %321, 192
  %324 = ashr i32 %323, 3
  %325 = xor i32 %321, %324
  %326 = sub i32 %325, %321
  %327 = sext i32 %326 to i64
  %328 = trunc i64 %327 to i32
  %329 = getelementptr inbounds half, ptr addrspace(3) %311, i32 %328
  %330 = ptrtoint ptr addrspace(3) %329 to i64
  %331 = trunc i64 %330 to i32
  call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %331, ptr addrspace(1) %322, i32 16)
  call void @llvm.nvvm.cp.async.commit.group()
  call void @llvm.nvvm.cp.async.wait.group(i32 1)
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  call void @llvm.lifetime.start.p0(ptr %89)
  call void @llvm.lifetime.start.p0(ptr %88)
  %332 = zext i32 %200 to i64
  call void @llvm.lifetime.end.p0(ptr %87)
  call void @llvm.lifetime.start.p0(ptr %87)
  store i64 %332, ptr %87, align 8
  call void @llvm.lifetime.end.p0(ptr %86)
  call void @llvm.lifetime.start.p0(ptr %86)
  store i64 0, ptr %86, align 8
  call void @llvm.lifetime.end.p0(ptr %85)
  %333 = insertvalue [2 x ptr] undef, ptr %87, 0
  %334 = insertvalue [2 x ptr] %333, ptr %86, 1
  call void @llvm.lifetime.start.p0(ptr %85)
  store [2 x ptr] %334, ptr %85, align 8
  %335 = getelementptr inbounds [2 x ptr], ptr %85, i32 0, i32 0
  %336 = load ptr, ptr %335, align 8
  %337 = load i64, ptr %336, align 8
  %338 = trunc i64 %337 to i32
  %339 = getelementptr inbounds ptr, ptr %335, i32 1
  %340 = load ptr, ptr %339, align 8
  %341 = load i64, ptr %340, align 8
  %342 = trunc i64 %341 to i32
  %343 = mul i32 %338, 16
  %344 = mul i32 %343, 32
  %345 = mul i32 %342, 32
  %346 = add i32 %344, %345
  %347 = sext i32 %346 to i64
  %348 = trunc i64 %347 to i32
  %349 = getelementptr inbounds half, ptr addrspace(3) @extern_ptr_syml_4, i32 %348
  call void @llvm.lifetime.end.p0(ptr %85)
  call void @llvm.lifetime.end.p0(ptr %86)
  call void @llvm.lifetime.end.p0(ptr %87)
  %350 = zext i32 %201 to i64
  call void @llvm.lifetime.end.p0(ptr %84)
  call void @llvm.lifetime.start.p0(ptr %84)
  store i64 %350, ptr %84, align 8
  call void @llvm.lifetime.end.p0(ptr %83)
  call void @llvm.lifetime.start.p0(ptr %83)
  store i64 0, ptr %83, align 8
  call void @llvm.lifetime.end.p0(ptr %82)
  %351 = insertvalue [2 x ptr] undef, ptr %84, 0
  %352 = insertvalue [2 x ptr] %351, ptr %83, 1
  call void @llvm.lifetime.start.p0(ptr %82)
  store [2 x ptr] %352, ptr %82, align 8
  %353 = getelementptr inbounds [2 x ptr], ptr %82, i32 0, i32 0
  %354 = load ptr, ptr %353, align 8
  %355 = load i64, ptr %354, align 8
  %356 = trunc i64 %355 to i32
  %357 = getelementptr inbounds ptr, ptr %353, i32 1
  %358 = load ptr, ptr %357, align 8
  %359 = load i64, ptr %358, align 8
  %360 = trunc i64 %359 to i32
  %361 = mul i32 %356, 16
  %362 = mul i32 %361, 32
  %363 = mul i32 %360, 32
  %364 = add i32 %362, %363
  %365 = sext i32 %364 to i64
  %366 = trunc i64 %365 to i32
  %367 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 6144), i32 %366
  call void @llvm.lifetime.end.p0(ptr %82)
  call void @llvm.lifetime.end.p0(ptr %81)
  call void @llvm.lifetime.start.p0(ptr %81)
  store i64 0, ptr %81, align 8
  call void @llvm.lifetime.end.p0(ptr %80)
  call void @llvm.lifetime.start.p0(ptr %80)
  store i64 0, ptr %80, align 8
  call void @llvm.lifetime.end.p0(ptr %79)
  %368 = insertvalue [2 x ptr] undef, ptr %81, 0
  %369 = insertvalue [2 x ptr] %368, ptr %80, 1
  call void @llvm.lifetime.start.p0(ptr %79)
  store [2 x ptr] %369, ptr %79, align 8
  %370 = getelementptr inbounds [2 x ptr], ptr %79, i32 0, i32 0
  %371 = load ptr, ptr %370, align 8
  %372 = load i64, ptr %371, align 8
  %373 = trunc i64 %372 to i32
  %374 = getelementptr inbounds ptr, ptr %370, i32 1
  %375 = load ptr, ptr %374, align 8
  %376 = load i64, ptr %375, align 8
  %377 = trunc i64 %376 to i32
  %378 = mul i32 %373, 8
  %379 = mul i32 %377, 8
  %380 = add i32 %378, %379
  %381 = addrspacecast ptr %89 to ptr addrspace(5)
  %382 = sext i32 %380 to i64
  %383 = trunc i64 %382 to i32
  %384 = getelementptr inbounds half, ptr addrspace(5) %381, i32 %383
  call void @llvm.lifetime.end.p0(ptr %79)
  call void @llvm.lifetime.end.p0(ptr %80)
  call void @llvm.lifetime.end.p0(ptr %81)
  call void @llvm.lifetime.end.p0(ptr %78)
  call void @llvm.lifetime.start.p0(ptr %78)
  store i64 0, ptr %78, align 8
  call void @llvm.lifetime.end.p0(ptr %77)
  call void @llvm.lifetime.start.p0(ptr %77)
  store i64 0, ptr %77, align 8
  call void @llvm.lifetime.end.p0(ptr %76)
  %385 = insertvalue [2 x ptr] undef, ptr %78, 0
  %386 = insertvalue [2 x ptr] %385, ptr %77, 1
  call void @llvm.lifetime.start.p0(ptr %76)
  store [2 x ptr] %386, ptr %76, align 8
  %387 = getelementptr inbounds [2 x ptr], ptr %76, i32 0, i32 0
  %388 = load ptr, ptr %387, align 8
  %389 = load i64, ptr %388, align 8
  %390 = trunc i64 %389 to i32
  %391 = getelementptr inbounds ptr, ptr %387, i32 1
  %392 = load ptr, ptr %391, align 8
  %393 = load i64, ptr %392, align 8
  %394 = trunc i64 %393 to i32
  %395 = mul i32 %390, 16
  %396 = mul i32 %395, 32
  %397 = mul i32 %394, 32
  %398 = add i32 %396, %397
  %399 = sext i32 %398 to i64
  %400 = trunc i64 %399 to i32
  %401 = getelementptr inbounds half, ptr addrspace(3) %349, i32 %400
  call void @llvm.lifetime.end.p0(ptr %76)
  call void @llvm.lifetime.end.p0(ptr %77)
  call void @llvm.lifetime.end.p0(ptr %78)
  %402 = sext i32 %102 to i64
  %403 = udiv i64 %402, 16
  %404 = urem i64 %402, 16
  %405 = mul i64 %404, 4
  %406 = urem i64 %403, 2
  %407 = add i64 %405, %406
  %408 = add i64 %407, 2
  %409 = and i64 %408, 24
  %410 = ashr i64 %409, 3
  %411 = xor i64 %408, %410
  %412 = mul i64 %411, 8
  %413 = and i64 %407, 24
  %414 = ashr i64 %413, 3
  %415 = xor i64 %407, %414
  %416 = mul i64 %415, 8
  %417 = trunc i64 %416 to i32
  %418 = getelementptr inbounds half, ptr addrspace(3) %401, i32 %417
  %419 = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) %418)
  %420 = extractvalue { i32, i32, i32, i32 } %419, 0
  %421 = bitcast i32 %420 to <2 x half>
  %422 = extractvalue { i32, i32, i32, i32 } %419, 1
  %423 = bitcast i32 %422 to <2 x half>
  %424 = extractvalue { i32, i32, i32, i32 } %419, 2
  %425 = bitcast i32 %424 to <2 x half>
  %426 = extractvalue { i32, i32, i32, i32 } %419, 3
  %427 = bitcast i32 %426 to <2 x half>
  %428 = shufflevector <2 x half> %421, <2 x half> %423, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %429 = shufflevector <2 x half> %425, <2 x half> %427, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %430 = shufflevector <4 x half> %428, <4 x half> %429, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  store <8 x half> %430, ptr addrspace(5) %384, align 2
  call void @llvm.lifetime.end.p0(ptr %75)
  call void @llvm.lifetime.start.p0(ptr %75)
  store i64 0, ptr %75, align 8
  call void @llvm.lifetime.end.p0(ptr %74)
  call void @llvm.lifetime.start.p0(ptr %74)
  store i64 0, ptr %74, align 8
  call void @llvm.lifetime.end.p0(ptr %73)
  %431 = insertvalue [2 x ptr] undef, ptr %75, 0
  %432 = insertvalue [2 x ptr] %431, ptr %74, 1
  call void @llvm.lifetime.start.p0(ptr %73)
  store [2 x ptr] %432, ptr %73, align 8
  %433 = getelementptr inbounds [2 x ptr], ptr %73, i32 0, i32 0
  %434 = load ptr, ptr %433, align 8
  %435 = load i64, ptr %434, align 8
  %436 = trunc i64 %435 to i32
  %437 = getelementptr inbounds ptr, ptr %433, i32 1
  %438 = load ptr, ptr %437, align 8
  %439 = load i64, ptr %438, align 8
  %440 = trunc i64 %439 to i32
  %441 = mul i32 %436, 2
  %442 = mul i32 %441, 4
  %443 = mul i32 %440, 4
  %444 = add i32 %442, %443
  %445 = addrspacecast ptr %88 to ptr addrspace(5)
  %446 = sext i32 %444 to i64
  %447 = trunc i64 %446 to i32
  %448 = getelementptr inbounds half, ptr addrspace(5) %445, i32 %447
  call void @llvm.lifetime.end.p0(ptr %73)
  call void @llvm.lifetime.end.p0(ptr %74)
  call void @llvm.lifetime.end.p0(ptr %75)
  call void @llvm.lifetime.end.p0(ptr %72)
  call void @llvm.lifetime.start.p0(ptr %72)
  store i64 0, ptr %72, align 8
  call void @llvm.lifetime.end.p0(ptr %71)
  call void @llvm.lifetime.start.p0(ptr %71)
  store i64 0, ptr %71, align 8
  call void @llvm.lifetime.end.p0(ptr %70)
  %449 = insertvalue [2 x ptr] undef, ptr %72, 0
  %450 = insertvalue [2 x ptr] %449, ptr %71, 1
  call void @llvm.lifetime.start.p0(ptr %70)
  store [2 x ptr] %450, ptr %70, align 8
  %451 = getelementptr inbounds [2 x ptr], ptr %70, i32 0, i32 0
  %452 = load ptr, ptr %451, align 8
  %453 = load i64, ptr %452, align 8
  %454 = trunc i64 %453 to i32
  %455 = getelementptr inbounds ptr, ptr %451, i32 1
  %456 = load ptr, ptr %455, align 8
  %457 = load i64, ptr %456, align 8
  %458 = trunc i64 %457 to i32
  %459 = mul i32 %454, 16
  %460 = mul i32 %459, 32
  %461 = mul i32 %458, 32
  %462 = add i32 %460, %461
  %463 = sext i32 %462 to i64
  %464 = trunc i64 %463 to i32
  %465 = getelementptr inbounds half, ptr addrspace(3) %367, i32 %464
  call void @llvm.lifetime.end.p0(ptr %70)
  call void @llvm.lifetime.end.p0(ptr %71)
  call void @llvm.lifetime.end.p0(ptr %72)
  %466 = udiv i64 %402, 8
  %467 = urem i64 %402, 8
  %468 = mul i64 %467, 4
  %469 = udiv i64 %466, 2
  %470 = urem i64 %466, 2
  %471 = add i64 %468, %470
  %472 = urem i64 %469, 2
  %473 = mul i64 %472, 32
  %474 = add i64 %471, %473
  %475 = add i64 %474, 2
  %476 = and i64 %475, 24
  %477 = ashr i64 %476, 3
  %478 = xor i64 %475, %477
  %479 = mul i64 %478, 8
  %480 = and i64 %474, 24
  %481 = ashr i64 %480, 3
  %482 = xor i64 %474, %481
  %483 = mul i64 %482, 8
  %484 = trunc i64 %483 to i32
  %485 = getelementptr inbounds half, ptr addrspace(3) %465, i32 %484
  %486 = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) %485)
  %487 = extractvalue { i32, i32, i32, i32 } %486, 0
  %488 = bitcast i32 %487 to <2 x half>
  %489 = extractvalue { i32, i32, i32, i32 } %486, 1
  %490 = bitcast i32 %489 to <2 x half>
  %491 = extractvalue { i32, i32, i32, i32 } %486, 2
  %492 = bitcast i32 %491 to <2 x half>
  %493 = extractvalue { i32, i32, i32, i32 } %486, 3
  %494 = bitcast i32 %493 to <2 x half>
  %495 = shufflevector <2 x half> %488, <2 x half> %490, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %496 = shufflevector <2 x half> %492, <2 x half> %494, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %497 = shufflevector <4 x half> %495, <4 x half> %496, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  %498 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %497, i64 0)
  %499 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %497, i64 4)
  store <4 x half> %498, ptr addrspace(5) %448, align 2
  %500 = getelementptr inbounds half, ptr addrspace(5) %448, i32 4
  store <4 x half> %499, ptr addrspace(5) %500, align 2
  br label %501

501:                                              ; preds = %1067, %139
  %502 = phi i64 [ 0, %139 ], [ %543, %1067 ]
  %503 = phi i32 [ 64, %139 ], [ %797, %1067 ]
  %504 = phi i32 [ 64, %139 ], [ %798, %1067 ]
  %505 = phi i32 [ 0, %139 ], [ %925, %1067 ]
  %506 = phi i32 [ 0, %139 ], [ %929, %1067 ]
  %507 = icmp slt i64 %502, 16
  br i1 %507, label %508, label %799

508:                                              ; preds = %501
  %509 = add i32 %506, 2048
  %510 = sub i32 %509, 3072
  %511 = icmp sge i32 %509, 3072
  %512 = select i1 %511, i32 %510, i32 %509
  %513 = sext i32 %512 to i64
  %514 = trunc i64 %513 to i32
  %515 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 6144), i32 %514
  %516 = ptrtoint ptr addrspace(3) %515 to i64
  %517 = getelementptr inbounds half, ptr addrspace(3) %515, i32 %242
  %518 = ptrtoint ptr addrspace(3) %517 to i64
  %519 = sub i64 %518, %516
  %520 = add i32 %504, 32
  %521 = sext i32 %504 to i64
  %522 = getelementptr inbounds half, ptr %172, i64 %521
  %523 = getelementptr inbounds half, ptr %522, i64 %237
  %524 = addrspacecast ptr %523 to ptr addrspace(1)
  %525 = add i32 %503, 32
  %526 = sext i32 %503 to i64
  %527 = getelementptr inbounds half, ptr %166, i64 %526
  %528 = getelementptr inbounds half, ptr %527, i64 %237
  %529 = addrspacecast ptr %528 to ptr addrspace(1)
  %530 = add i32 %505, 2048
  %531 = sub i32 %530, 3072
  %532 = icmp sge i32 %530, 3072
  %533 = select i1 %532, i32 %531, i32 %530
  %534 = sext i32 %533 to i64
  %535 = trunc i64 %534 to i32
  %536 = getelementptr inbounds half, ptr addrspace(3) @extern_ptr_syml_4, i32 %535
  %537 = getelementptr inbounds half, ptr addrspace(3) %536, i32 %242
  %538 = ptrtoint ptr addrspace(3) %537 to i64
  %539 = ptrtoint ptr addrspace(3) %536 to i64
  %540 = sub i64 %538, %539
  %541 = icmp eq i64 %502, 16
  %542 = add i64 %502, 1
  %543 = select i1 %541, i64 %502, i64 %542
  %544 = sext i32 %505 to i64
  %545 = trunc i64 %544 to i32
  %546 = getelementptr inbounds half, ptr addrspace(3) @extern_ptr_syml_4, i32 %545
  call void @llvm.lifetime.end.p0(ptr %69)
  call void @llvm.lifetime.start.p0(ptr %69)
  store i64 %332, ptr %69, align 8
  call void @llvm.lifetime.end.p0(ptr %68)
  call void @llvm.lifetime.start.p0(ptr %68)
  store i64 0, ptr %68, align 8
  call void @llvm.lifetime.end.p0(ptr %67)
  %547 = insertvalue [2 x ptr] undef, ptr %69, 0
  %548 = insertvalue [2 x ptr] %547, ptr %68, 1
  call void @llvm.lifetime.start.p0(ptr %67)
  store [2 x ptr] %548, ptr %67, align 8
  %549 = getelementptr inbounds [2 x ptr], ptr %67, i32 0, i32 0
  %550 = load ptr, ptr %549, align 8
  %551 = load i64, ptr %550, align 8
  %552 = trunc i64 %551 to i32
  %553 = getelementptr inbounds ptr, ptr %549, i32 1
  %554 = load ptr, ptr %553, align 8
  %555 = load i64, ptr %554, align 8
  %556 = trunc i64 %555 to i32
  %557 = mul i32 %552, 16
  %558 = mul i32 %557, 32
  %559 = mul i32 %556, 32
  %560 = add i32 %558, %559
  %561 = sext i32 %560 to i64
  %562 = trunc i64 %561 to i32
  %563 = getelementptr inbounds half, ptr addrspace(3) %546, i32 %562
  call void @llvm.lifetime.end.p0(ptr %67)
  call void @llvm.lifetime.end.p0(ptr %68)
  call void @llvm.lifetime.end.p0(ptr %69)
  %564 = sext i32 %506 to i64
  %565 = trunc i64 %564 to i32
  %566 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 6144), i32 %565
  call void @llvm.lifetime.end.p0(ptr %66)
  call void @llvm.lifetime.start.p0(ptr %66)
  store [2 x ptr] %352, ptr %66, align 8
  %567 = getelementptr inbounds [2 x ptr], ptr %66, i32 0, i32 0
  %568 = load ptr, ptr %567, align 8
  %569 = load i64, ptr %568, align 8
  %570 = trunc i64 %569 to i32
  %571 = getelementptr inbounds ptr, ptr %567, i32 1
  %572 = load ptr, ptr %571, align 8
  %573 = load i64, ptr %572, align 8
  %574 = trunc i64 %573 to i32
  %575 = mul i32 %570, 16
  %576 = mul i32 %575, 32
  %577 = mul i32 %574, 32
  %578 = add i32 %576, %577
  %579 = sext i32 %578 to i64
  %580 = trunc i64 %579 to i32
  %581 = getelementptr inbounds half, ptr addrspace(3) %566, i32 %580
  call void @llvm.lifetime.end.p0(ptr %66)
  call void @llvm.lifetime.end.p0(ptr %65)
  call void @llvm.lifetime.start.p0(ptr %65)
  store i64 1, ptr %65, align 8
  call void @llvm.lifetime.end.p0(ptr %64)
  call void @llvm.lifetime.start.p0(ptr %64)
  store i64 0, ptr %64, align 8
  call void @llvm.lifetime.end.p0(ptr %63)
  %582 = insertvalue [2 x ptr] undef, ptr %65, 0
  %583 = insertvalue [2 x ptr] %582, ptr %64, 1
  call void @llvm.lifetime.start.p0(ptr %63)
  store [2 x ptr] %583, ptr %63, align 8
  %584 = getelementptr inbounds [2 x ptr], ptr %63, i32 0, i32 0
  %585 = load ptr, ptr %584, align 8
  %586 = load i64, ptr %585, align 8
  %587 = trunc i64 %586 to i32
  %588 = getelementptr inbounds ptr, ptr %584, i32 1
  %589 = load ptr, ptr %588, align 8
  %590 = load i64, ptr %589, align 8
  %591 = trunc i64 %590 to i32
  %592 = mul i32 %587, 8
  %593 = mul i32 %591, 8
  %594 = add i32 %592, %593
  %595 = sext i32 %594 to i64
  %596 = trunc i64 %595 to i32
  %597 = getelementptr inbounds half, ptr addrspace(5) %381, i32 %596
  call void @llvm.lifetime.end.p0(ptr %63)
  call void @llvm.lifetime.end.p0(ptr %64)
  call void @llvm.lifetime.end.p0(ptr %65)
  call void @llvm.lifetime.end.p0(ptr %62)
  call void @llvm.lifetime.start.p0(ptr %62)
  store i64 0, ptr %62, align 8
  call void @llvm.lifetime.end.p0(ptr %61)
  call void @llvm.lifetime.start.p0(ptr %61)
  store i64 0, ptr %61, align 8
  call void @llvm.lifetime.end.p0(ptr %60)
  %598 = insertvalue [2 x ptr] undef, ptr %62, 0
  %599 = insertvalue [2 x ptr] %598, ptr %61, 1
  call void @llvm.lifetime.start.p0(ptr %60)
  store [2 x ptr] %599, ptr %60, align 8
  %600 = getelementptr inbounds [2 x ptr], ptr %60, i32 0, i32 0
  %601 = load ptr, ptr %600, align 8
  %602 = load i64, ptr %601, align 8
  %603 = trunc i64 %602 to i32
  %604 = getelementptr inbounds ptr, ptr %600, i32 1
  %605 = load ptr, ptr %604, align 8
  %606 = load i64, ptr %605, align 8
  %607 = trunc i64 %606 to i32
  %608 = mul i32 %603, 16
  %609 = mul i32 %608, 32
  %610 = mul i32 %607, 32
  %611 = add i32 %609, %610
  %612 = sext i32 %611 to i64
  %613 = trunc i64 %612 to i32
  %614 = getelementptr inbounds half, ptr addrspace(3) %563, i32 %613
  call void @llvm.lifetime.end.p0(ptr %60)
  call void @llvm.lifetime.end.p0(ptr %61)
  call void @llvm.lifetime.end.p0(ptr %62)
  %615 = trunc i64 %412 to i32
  %616 = getelementptr inbounds half, ptr addrspace(3) %614, i32 %615
  %617 = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) %616)
  %618 = extractvalue { i32, i32, i32, i32 } %617, 0
  %619 = bitcast i32 %618 to <2 x half>
  %620 = extractvalue { i32, i32, i32, i32 } %617, 1
  %621 = bitcast i32 %620 to <2 x half>
  %622 = extractvalue { i32, i32, i32, i32 } %617, 2
  %623 = bitcast i32 %622 to <2 x half>
  %624 = extractvalue { i32, i32, i32, i32 } %617, 3
  %625 = bitcast i32 %624 to <2 x half>
  %626 = shufflevector <2 x half> %619, <2 x half> %621, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %627 = shufflevector <2 x half> %623, <2 x half> %625, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %628 = shufflevector <4 x half> %626, <4 x half> %627, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  store <8 x half> %628, ptr addrspace(5) %597, align 2
  call void @llvm.lifetime.end.p0(ptr %59)
  call void @llvm.lifetime.start.p0(ptr %59)
  store i64 1, ptr %59, align 8
  call void @llvm.lifetime.end.p0(ptr %58)
  call void @llvm.lifetime.start.p0(ptr %58)
  store i64 0, ptr %58, align 8
  call void @llvm.lifetime.end.p0(ptr %57)
  %629 = insertvalue [2 x ptr] undef, ptr %59, 0
  %630 = insertvalue [2 x ptr] %629, ptr %58, 1
  call void @llvm.lifetime.start.p0(ptr %57)
  store [2 x ptr] %630, ptr %57, align 8
  %631 = getelementptr inbounds [2 x ptr], ptr %57, i32 0, i32 0
  %632 = load ptr, ptr %631, align 8
  %633 = load i64, ptr %632, align 8
  %634 = trunc i64 %633 to i32
  %635 = getelementptr inbounds ptr, ptr %631, i32 1
  %636 = load ptr, ptr %635, align 8
  %637 = load i64, ptr %636, align 8
  %638 = trunc i64 %637 to i32
  %639 = mul i32 %634, 2
  %640 = mul i32 %639, 4
  %641 = mul i32 %638, 4
  %642 = add i32 %640, %641
  %643 = sext i32 %642 to i64
  %644 = trunc i64 %643 to i32
  %645 = getelementptr inbounds half, ptr addrspace(5) %445, i32 %644
  call void @llvm.lifetime.end.p0(ptr %57)
  call void @llvm.lifetime.end.p0(ptr %58)
  call void @llvm.lifetime.end.p0(ptr %59)
  call void @llvm.lifetime.end.p0(ptr %56)
  call void @llvm.lifetime.start.p0(ptr %56)
  store i64 0, ptr %56, align 8
  call void @llvm.lifetime.end.p0(ptr %55)
  call void @llvm.lifetime.start.p0(ptr %55)
  store i64 0, ptr %55, align 8
  call void @llvm.lifetime.end.p0(ptr %54)
  %646 = insertvalue [2 x ptr] undef, ptr %56, 0
  %647 = insertvalue [2 x ptr] %646, ptr %55, 1
  call void @llvm.lifetime.start.p0(ptr %54)
  store [2 x ptr] %647, ptr %54, align 8
  %648 = getelementptr inbounds [2 x ptr], ptr %54, i32 0, i32 0
  %649 = load ptr, ptr %648, align 8
  %650 = load i64, ptr %649, align 8
  %651 = trunc i64 %650 to i32
  %652 = getelementptr inbounds ptr, ptr %648, i32 1
  %653 = load ptr, ptr %652, align 8
  %654 = load i64, ptr %653, align 8
  %655 = trunc i64 %654 to i32
  %656 = mul i32 %651, 16
  %657 = mul i32 %656, 32
  %658 = mul i32 %655, 32
  %659 = add i32 %657, %658
  %660 = sext i32 %659 to i64
  %661 = trunc i64 %660 to i32
  %662 = getelementptr inbounds half, ptr addrspace(3) %581, i32 %661
  call void @llvm.lifetime.end.p0(ptr %54)
  call void @llvm.lifetime.end.p0(ptr %55)
  call void @llvm.lifetime.end.p0(ptr %56)
  %663 = trunc i64 %479 to i32
  %664 = getelementptr inbounds half, ptr addrspace(3) %662, i32 %663
  %665 = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) %664)
  %666 = extractvalue { i32, i32, i32, i32 } %665, 0
  %667 = bitcast i32 %666 to <2 x half>
  %668 = extractvalue { i32, i32, i32, i32 } %665, 1
  %669 = bitcast i32 %668 to <2 x half>
  %670 = extractvalue { i32, i32, i32, i32 } %665, 2
  %671 = bitcast i32 %670 to <2 x half>
  %672 = extractvalue { i32, i32, i32, i32 } %665, 3
  %673 = bitcast i32 %672 to <2 x half>
  %674 = shufflevector <2 x half> %667, <2 x half> %669, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %675 = shufflevector <2 x half> %671, <2 x half> %673, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %676 = shufflevector <4 x half> %674, <4 x half> %675, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  %677 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %676, i64 0)
  %678 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %676, i64 4)
  store <4 x half> %677, ptr addrspace(5) %645, align 2
  %679 = getelementptr inbounds half, ptr addrspace(5) %645, i32 4
  store <4 x half> %678, ptr addrspace(5) %679, align 2
  call void @llvm.lifetime.end.p0(ptr %53)
  call void @llvm.lifetime.start.p0(ptr %53)
  store i64 0, ptr %53, align 8
  call void @llvm.lifetime.end.p0(ptr %52)
  call void @llvm.lifetime.start.p0(ptr %52)
  store i64 0, ptr %52, align 8
  call void @llvm.lifetime.end.p0(ptr %51)
  %680 = insertvalue [2 x ptr] undef, ptr %53, 0
  %681 = insertvalue [2 x ptr] %680, ptr %52, 1
  call void @llvm.lifetime.start.p0(ptr %51)
  store [2 x ptr] %681, ptr %51, align 8
  %682 = getelementptr inbounds [2 x ptr], ptr %51, i32 0, i32 0
  %683 = load ptr, ptr %682, align 8
  %684 = load i64, ptr %683, align 8
  %685 = trunc i64 %684 to i32
  %686 = getelementptr inbounds ptr, ptr %682, i32 1
  %687 = load ptr, ptr %686, align 8
  %688 = load i64, ptr %687, align 8
  %689 = trunc i64 %688 to i32
  %690 = mul i32 %685, 8
  %691 = mul i32 %689, 8
  %692 = add i32 %690, %691
  %693 = sext i32 %692 to i64
  %694 = trunc i64 %693 to i32
  %695 = getelementptr inbounds half, ptr addrspace(5) %381, i32 %694
  call void @llvm.lifetime.end.p0(ptr %51)
  call void @llvm.lifetime.end.p0(ptr %52)
  call void @llvm.lifetime.end.p0(ptr %53)
  call void @llvm.lifetime.end.p0(ptr %50)
  call void @llvm.lifetime.start.p0(ptr %50)
  store i64 0, ptr %50, align 8
  call void @llvm.lifetime.end.p0(ptr %49)
  call void @llvm.lifetime.start.p0(ptr %49)
  store i64 0, ptr %49, align 8
  call void @llvm.lifetime.end.p0(ptr %48)
  %696 = insertvalue [2 x ptr] undef, ptr %50, 0
  %697 = insertvalue [2 x ptr] %696, ptr %49, 1
  call void @llvm.lifetime.start.p0(ptr %48)
  store [2 x ptr] %697, ptr %48, align 8
  %698 = getelementptr inbounds [2 x ptr], ptr %48, i32 0, i32 0
  %699 = load ptr, ptr %698, align 8
  %700 = load i64, ptr %699, align 8
  %701 = trunc i64 %700 to i32
  %702 = getelementptr inbounds ptr, ptr %698, i32 1
  %703 = load ptr, ptr %702, align 8
  %704 = load i64, ptr %703, align 8
  %705 = trunc i64 %704 to i32
  %706 = mul i32 %701, 2
  %707 = mul i32 %706, 4
  %708 = mul i32 %705, 4
  %709 = add i32 %707, %708
  %710 = sext i32 %709 to i64
  %711 = trunc i64 %710 to i32
  %712 = getelementptr inbounds half, ptr addrspace(5) %445, i32 %711
  call void @llvm.lifetime.end.p0(ptr %48)
  call void @llvm.lifetime.end.p0(ptr %49)
  call void @llvm.lifetime.end.p0(ptr %50)
  %713 = load <4 x float>, ptr addrspace(5) %174, align 16
  %714 = load <8 x half>, ptr addrspace(5) %695, align 16
  %715 = load <4 x half>, ptr addrspace(5) %712, align 8
  %716 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %714, i64 0)
  %717 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %714, i64 4)
  %718 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %716, i64 0)
  %719 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %716, i64 2)
  %720 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %717, i64 0)
  %721 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %717, i64 2)
  %722 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %715, i64 0)
  %723 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %715, i64 2)
  %724 = extractelement <4 x float> %713, i64 0
  %725 = extractelement <4 x float> %713, i64 1
  %726 = extractelement <4 x float> %713, i64 2
  %727 = extractelement <4 x float> %713, i64 3
  %728 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(<2 x half> %718, <2 x half> %719, <2 x half> %720, <2 x half> %721, <2 x half> %722, <2 x half> %723, float %724, float %725, float %726, float %727)
  %729 = extractvalue { float, float, float, float } %728, 0
  %730 = extractvalue { float, float, float, float } %728, 1
  %731 = extractvalue { float, float, float, float } %728, 2
  %732 = extractvalue { float, float, float, float } %728, 3
  call void @llvm.lifetime.end.p0(ptr %47)
  call void @llvm.lifetime.start.p0(ptr %47)
  store float %729, ptr %47, align 4
  call void @llvm.lifetime.end.p0(ptr %46)
  call void @llvm.lifetime.start.p0(ptr %46)
  store float %730, ptr %46, align 4
  call void @llvm.lifetime.end.p0(ptr %45)
  call void @llvm.lifetime.start.p0(ptr %45)
  store float %731, ptr %45, align 4
  call void @llvm.lifetime.end.p0(ptr %44)
  call void @llvm.lifetime.start.p0(ptr %44)
  store float %732, ptr %44, align 4
  call void @llvm.lifetime.end.p0(ptr %43)
  %733 = insertvalue [4 x ptr] undef, ptr %47, 0
  %734 = insertvalue [4 x ptr] %733, ptr %46, 1
  %735 = insertvalue [4 x ptr] %734, ptr %45, 2
  %736 = insertvalue [4 x ptr] %735, ptr %44, 3
  call void @llvm.lifetime.start.p0(ptr %43)
  store [4 x ptr] %736, ptr %43, align 8
  %737 = getelementptr inbounds [4 x ptr], ptr %43, i32 0, i32 0
  %738 = load ptr, ptr %737, align 8
  %739 = load float, ptr %738, align 4
  %740 = insertelement <4 x float> undef, float %739, i64 0
  %741 = getelementptr inbounds ptr, ptr %737, i32 1
  %742 = load ptr, ptr %741, align 8
  %743 = load float, ptr %742, align 4
  %744 = insertelement <4 x float> %740, float %743, i64 1
  %745 = getelementptr inbounds ptr, ptr %737, i32 2
  %746 = load ptr, ptr %745, align 8
  %747 = load float, ptr %746, align 4
  %748 = insertelement <4 x float> %744, float %747, i64 2
  %749 = getelementptr inbounds ptr, ptr %737, i32 3
  %750 = load ptr, ptr %749, align 8
  %751 = load float, ptr %750, align 4
  %752 = insertelement <4 x float> %748, float %751, i64 3
  call void @llvm.lifetime.end.p0(ptr %43)
  call void @llvm.lifetime.end.p0(ptr %44)
  call void @llvm.lifetime.end.p0(ptr %45)
  call void @llvm.lifetime.end.p0(ptr %46)
  call void @llvm.lifetime.end.p0(ptr %47)
  store <4 x float> %752, ptr addrspace(5) %174, align 16
  %753 = load <4 x float>, ptr addrspace(5) %175, align 16
  %754 = load <8 x half>, ptr addrspace(5) %695, align 16
  %755 = getelementptr inbounds half, ptr addrspace(5) %712, i32 4
  %756 = load <4 x half>, ptr addrspace(5) %755, align 8
  %757 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %754, i64 0)
  %758 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %754, i64 4)
  %759 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %757, i64 0)
  %760 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %757, i64 2)
  %761 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %758, i64 0)
  %762 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %758, i64 2)
  %763 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %756, i64 0)
  %764 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %756, i64 2)
  %765 = extractelement <4 x float> %753, i64 0
  %766 = extractelement <4 x float> %753, i64 1
  %767 = extractelement <4 x float> %753, i64 2
  %768 = extractelement <4 x float> %753, i64 3
  %769 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(<2 x half> %759, <2 x half> %760, <2 x half> %761, <2 x half> %762, <2 x half> %763, <2 x half> %764, float %765, float %766, float %767, float %768)
  %770 = extractvalue { float, float, float, float } %769, 0
  %771 = extractvalue { float, float, float, float } %769, 1
  %772 = extractvalue { float, float, float, float } %769, 2
  %773 = extractvalue { float, float, float, float } %769, 3
  call void @llvm.lifetime.end.p0(ptr %42)
  call void @llvm.lifetime.start.p0(ptr %42)
  store float %770, ptr %42, align 4
  call void @llvm.lifetime.end.p0(ptr %41)
  call void @llvm.lifetime.start.p0(ptr %41)
  store float %771, ptr %41, align 4
  call void @llvm.lifetime.end.p0(ptr %40)
  call void @llvm.lifetime.start.p0(ptr %40)
  store float %772, ptr %40, align 4
  call void @llvm.lifetime.end.p0(ptr %39)
  call void @llvm.lifetime.start.p0(ptr %39)
  store float %773, ptr %39, align 4
  call void @llvm.lifetime.end.p0(ptr %38)
  %774 = insertvalue [4 x ptr] undef, ptr %42, 0
  %775 = insertvalue [4 x ptr] %774, ptr %41, 1
  %776 = insertvalue [4 x ptr] %775, ptr %40, 2
  %777 = insertvalue [4 x ptr] %776, ptr %39, 3
  call void @llvm.lifetime.start.p0(ptr %38)
  store [4 x ptr] %777, ptr %38, align 8
  %778 = getelementptr inbounds [4 x ptr], ptr %38, i32 0, i32 0
  %779 = load ptr, ptr %778, align 8
  %780 = load float, ptr %779, align 4
  %781 = insertelement <4 x float> undef, float %780, i64 0
  %782 = getelementptr inbounds ptr, ptr %778, i32 1
  %783 = load ptr, ptr %782, align 8
  %784 = load float, ptr %783, align 4
  %785 = insertelement <4 x float> %781, float %784, i64 1
  %786 = getelementptr inbounds ptr, ptr %778, i32 2
  %787 = load ptr, ptr %786, align 8
  %788 = load float, ptr %787, align 4
  %789 = insertelement <4 x float> %785, float %788, i64 2
  %790 = getelementptr inbounds ptr, ptr %778, i32 3
  %791 = load ptr, ptr %790, align 8
  %792 = load float, ptr %791, align 4
  %793 = insertelement <4 x float> %789, float %792, i64 3
  call void @llvm.lifetime.end.p0(ptr %38)
  call void @llvm.lifetime.end.p0(ptr %39)
  call void @llvm.lifetime.end.p0(ptr %40)
  call void @llvm.lifetime.end.p0(ptr %41)
  call void @llvm.lifetime.end.p0(ptr %42)
  store <4 x float> %793, ptr addrspace(5) %175, align 16
  %794 = add i64 %502, 3
  %795 = sub i64 %794, 1
  %796 = icmp slt i64 %795, 16
  %797 = select i1 %796, i32 %525, i32 %503
  %798 = select i1 %796, i32 %520, i32 %504
  br i1 %796, label %885, label %920

799:                                              ; preds = %501
  call void @llvm.lifetime.end.p0(ptr %83)
  call void @llvm.lifetime.end.p0(ptr %84)
  %800 = mul i32 %163, 32
  %801 = add i32 %800, %169
  %802 = sext i32 %801 to i64
  %803 = getelementptr inbounds half, ptr %98, i64 %802
  %804 = trunc i64 %159 to i32
  %805 = mul i32 %804, 16
  %806 = mul i32 %805, 32
  %807 = trunc i64 %160 to i32
  %808 = mul i32 %807, 16
  %809 = add i32 %806, %808
  %810 = sext i32 %809 to i64
  %811 = getelementptr inbounds half, ptr %803, i64 %810
  %812 = ptrtoint ptr %811 to i64
  %813 = mul i64 %159, 16
  %814 = add i64 %161, %813
  %815 = sub i64 32, %814
  %816 = call i64 @llvm.smax.i64(i64 %815, i64 0)
  %817 = insertvalue { i64 } undef, i64 %816, 0
  %818 = insertvalue { { i64 } } undef, { i64 } %817, 0
  call void @llvm.lifetime.start.p0(ptr %5)
  store { { i64 } } %818, ptr %5, align 8
  %819 = load { i64 }, ptr %5, align 8
  %820 = mul i64 %160, 16
  %821 = add i64 %167, %820
  %822 = add i64 %821, 16
  %823 = icmp sle i64 %822, 32
  %824 = add i64 %814, 16
  %825 = icmp sle i64 %824, 32
  %826 = select i1 %825, i1 %823, i1 false
  %827 = mul i64 %121, 16
  %828 = mul i64 %827, 16
  %829 = trunc i64 %828 to i32
  %830 = getelementptr inbounds half, ptr addrspace(3) @extern_ptr_syml_4, i32 %829
  %831 = sdiv i64 %208, 8
  %832 = mul i64 %831, 8
  %833 = sub i64 %208, %832
  %834 = icmp ne i64 %833, 0
  %835 = and i1 %212, %834
  %836 = select i1 %835, i64 8, i64 0
  %837 = add i64 %833, %836
  %838 = trunc i64 %837 to i32
  %839 = mul i32 %838, 16
  %840 = mul i32 %234, 2
  %841 = add i32 %839, %840
  %842 = sext i32 %841 to i64
  %843 = trunc i64 %842 to i32
  %844 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %843
  %845 = ptrtoint ptr addrspace(3) %844 to i64
  %846 = ptrtoint ptr addrspace(3) %830 to i64
  %847 = sub i64 %845, %846
  %848 = sdiv i64 %847, 2
  %849 = mul i64 %848, 2
  %850 = icmp eq i64 %849, %847
  %851 = xor i64 %847, 2
  %852 = ashr i64 %851, 63
  %853 = select i1 %850, i64 0, i64 %852
  %854 = add i64 %848, %853
  %855 = trunc i64 %854 to i32
  %856 = and i32 %855, 112
  %857 = ashr i32 %856, 1
  %858 = xor i32 %855, %857
  %859 = load <2 x float>, ptr addrspace(5) %174, align 8
  %860 = fptrunc <2 x float> %859 to <2 x half>
  %861 = sext i32 %858 to i64
  %862 = trunc i64 %861 to i32
  %863 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %862
  store <2 x half> %860, ptr addrspace(3) %863, align 4
  %864 = add i32 %858, 128
  %865 = load <2 x float>, ptr addrspace(5) %178, align 8
  %866 = fptrunc <2 x float> %865 to <2 x half>
  %867 = sext i32 %864 to i64
  %868 = trunc i64 %867 to i32
  %869 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %868
  store <2 x half> %866, ptr addrspace(3) %869, align 4
  %870 = add i32 %855, 8
  %871 = and i32 %870, 112
  %872 = ashr i32 %871, 1
  %873 = xor i32 %870, %872
  %874 = load <2 x float>, ptr addrspace(5) %175, align 8
  %875 = fptrunc <2 x float> %874 to <2 x half>
  %876 = sext i32 %873 to i64
  %877 = trunc i64 %876 to i32
  %878 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %877
  store <2 x half> %875, ptr addrspace(3) %878, align 4
  %879 = add i32 %873, 128
  %880 = load <2 x float>, ptr addrspace(5) %179, align 8
  %881 = fptrunc <2 x float> %880 to <2 x half>
  %882 = sext i32 %879 to i64
  %883 = trunc i64 %882 to i32
  %884 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %883
  store <2 x half> %881, ptr addrspace(3) %884, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br i1 %826, label %1182, label %1234

885:                                              ; preds = %508
  %886 = sdiv i64 %540, 2
  %887 = mul i64 %886, 2
  %888 = icmp eq i64 %887, %540
  %889 = xor i64 %540, 2
  %890 = ashr i64 %889, 63
  %891 = select i1 %888, i64 0, i64 %890
  %892 = add i64 %886, %891
  %893 = trunc i64 %892 to i32
  %894 = and i32 %893, 192
  %895 = ashr i32 %894, 3
  %896 = xor i32 %893, %895
  %897 = sub i32 %896, %893
  %898 = sext i32 %897 to i64
  %899 = trunc i64 %898 to i32
  %900 = getelementptr inbounds half, ptr addrspace(3) %537, i32 %899
  %901 = ptrtoint ptr addrspace(3) %900 to i64
  %902 = trunc i64 %901 to i32
  call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %902, ptr addrspace(1) %529, i32 16)
  %903 = sdiv i64 %519, 2
  %904 = mul i64 %903, 2
  %905 = icmp eq i64 %904, %519
  %906 = xor i64 %519, 2
  %907 = ashr i64 %906, 63
  %908 = select i1 %905, i64 0, i64 %907
  %909 = add i64 %903, %908
  %910 = trunc i64 %909 to i32
  %911 = and i32 %910, 192
  %912 = ashr i32 %911, 3
  %913 = xor i32 %910, %912
  %914 = sub i32 %913, %910
  %915 = sext i32 %914 to i64
  %916 = trunc i64 %915 to i32
  %917 = getelementptr inbounds half, ptr addrspace(3) %517, i32 %916
  %918 = ptrtoint ptr addrspace(3) %917 to i64
  %919 = trunc i64 %918 to i32
  call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %919, ptr addrspace(1) %524, i32 16)
  br label %921

920:                                              ; preds = %508
  br label %921

921:                                              ; preds = %920, %885
  call void @llvm.nvvm.cp.async.commit.group()
  call void @llvm.nvvm.cp.async.wait.group(i32 1)
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %922 = add i32 %505, 1024
  %923 = icmp sge i32 %922, 3072
  %924 = sub i32 %922, 3072
  %925 = select i1 %923, i32 %924, i32 %922
  %926 = add i32 %506, 1024
  %927 = icmp sge i32 %926, 3072
  %928 = sub i32 %926, 3072
  %929 = select i1 %927, i32 %928, i32 %926
  %930 = sext i32 %925 to i64
  %931 = trunc i64 %930 to i32
  %932 = getelementptr inbounds half, ptr addrspace(3) @extern_ptr_syml_4, i32 %931
  call void @llvm.lifetime.end.p0(ptr %37)
  call void @llvm.lifetime.start.p0(ptr %37)
  store i64 %332, ptr %37, align 8
  call void @llvm.lifetime.end.p0(ptr %36)
  call void @llvm.lifetime.start.p0(ptr %36)
  store i64 0, ptr %36, align 8
  call void @llvm.lifetime.end.p0(ptr %35)
  %933 = insertvalue [2 x ptr] undef, ptr %37, 0
  %934 = insertvalue [2 x ptr] %933, ptr %36, 1
  call void @llvm.lifetime.start.p0(ptr %35)
  store [2 x ptr] %934, ptr %35, align 8
  %935 = getelementptr inbounds [2 x ptr], ptr %35, i32 0, i32 0
  %936 = load ptr, ptr %935, align 8
  %937 = load i64, ptr %936, align 8
  %938 = trunc i64 %937 to i32
  %939 = getelementptr inbounds ptr, ptr %935, i32 1
  %940 = load ptr, ptr %939, align 8
  %941 = load i64, ptr %940, align 8
  %942 = trunc i64 %941 to i32
  %943 = mul i32 %938, 16
  %944 = mul i32 %943, 32
  %945 = mul i32 %942, 32
  %946 = add i32 %944, %945
  %947 = sext i32 %946 to i64
  %948 = trunc i64 %947 to i32
  %949 = getelementptr inbounds half, ptr addrspace(3) %932, i32 %948
  call void @llvm.lifetime.end.p0(ptr %35)
  call void @llvm.lifetime.end.p0(ptr %36)
  call void @llvm.lifetime.end.p0(ptr %37)
  %950 = sext i32 %929 to i64
  %951 = trunc i64 %950 to i32
  %952 = getelementptr inbounds half, ptr addrspace(3) getelementptr inbounds nuw (i8, ptr addrspace(3) @extern_ptr_syml_4, i32 6144), i32 %951
  call void @llvm.lifetime.end.p0(ptr %34)
  call void @llvm.lifetime.start.p0(ptr %34)
  store [2 x ptr] %352, ptr %34, align 8
  %953 = getelementptr inbounds [2 x ptr], ptr %34, i32 0, i32 0
  %954 = load ptr, ptr %953, align 8
  %955 = load i64, ptr %954, align 8
  %956 = trunc i64 %955 to i32
  %957 = getelementptr inbounds ptr, ptr %953, i32 1
  %958 = load ptr, ptr %957, align 8
  %959 = load i64, ptr %958, align 8
  %960 = trunc i64 %959 to i32
  %961 = mul i32 %956, 16
  %962 = mul i32 %961, 32
  %963 = mul i32 %960, 32
  %964 = add i32 %962, %963
  %965 = sext i32 %964 to i64
  %966 = trunc i64 %965 to i32
  %967 = getelementptr inbounds half, ptr addrspace(3) %952, i32 %966
  call void @llvm.lifetime.end.p0(ptr %34)
  %968 = icmp slt i64 %542, 16
  br i1 %968, label %969, label %1066

969:                                              ; preds = %921
  call void @llvm.lifetime.end.p0(ptr %33)
  call void @llvm.lifetime.start.p0(ptr %33)
  store i64 0, ptr %33, align 8
  call void @llvm.lifetime.end.p0(ptr %32)
  call void @llvm.lifetime.start.p0(ptr %32)
  store i64 0, ptr %32, align 8
  call void @llvm.lifetime.end.p0(ptr %31)
  %970 = insertvalue [2 x ptr] undef, ptr %33, 0
  %971 = insertvalue [2 x ptr] %970, ptr %32, 1
  call void @llvm.lifetime.start.p0(ptr %31)
  store [2 x ptr] %971, ptr %31, align 8
  %972 = getelementptr inbounds [2 x ptr], ptr %31, i32 0, i32 0
  %973 = load ptr, ptr %972, align 8
  %974 = load i64, ptr %973, align 8
  %975 = trunc i64 %974 to i32
  %976 = getelementptr inbounds ptr, ptr %972, i32 1
  %977 = load ptr, ptr %976, align 8
  %978 = load i64, ptr %977, align 8
  %979 = trunc i64 %978 to i32
  %980 = mul i32 %975, 8
  %981 = mul i32 %979, 8
  %982 = add i32 %980, %981
  %983 = sext i32 %982 to i64
  %984 = trunc i64 %983 to i32
  %985 = getelementptr inbounds half, ptr addrspace(5) %381, i32 %984
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.end.p0(ptr %32)
  call void @llvm.lifetime.end.p0(ptr %33)
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.start.p0(ptr %30)
  store i64 0, ptr %30, align 8
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.start.p0(ptr %29)
  store i64 0, ptr %29, align 8
  call void @llvm.lifetime.end.p0(ptr %28)
  %986 = insertvalue [2 x ptr] undef, ptr %30, 0
  %987 = insertvalue [2 x ptr] %986, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %28)
  store [2 x ptr] %987, ptr %28, align 8
  %988 = getelementptr inbounds [2 x ptr], ptr %28, i32 0, i32 0
  %989 = load ptr, ptr %988, align 8
  %990 = load i64, ptr %989, align 8
  %991 = trunc i64 %990 to i32
  %992 = getelementptr inbounds ptr, ptr %988, i32 1
  %993 = load ptr, ptr %992, align 8
  %994 = load i64, ptr %993, align 8
  %995 = trunc i64 %994 to i32
  %996 = mul i32 %991, 16
  %997 = mul i32 %996, 32
  %998 = mul i32 %995, 32
  %999 = add i32 %997, %998
  %1000 = sext i32 %999 to i64
  %1001 = trunc i64 %1000 to i32
  %1002 = getelementptr inbounds half, ptr addrspace(3) %949, i32 %1001
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.end.p0(ptr %30)
  %1003 = getelementptr inbounds half, ptr addrspace(3) %1002, i32 %417
  %1004 = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) %1003)
  %1005 = extractvalue { i32, i32, i32, i32 } %1004, 0
  %1006 = bitcast i32 %1005 to <2 x half>
  %1007 = extractvalue { i32, i32, i32, i32 } %1004, 1
  %1008 = bitcast i32 %1007 to <2 x half>
  %1009 = extractvalue { i32, i32, i32, i32 } %1004, 2
  %1010 = bitcast i32 %1009 to <2 x half>
  %1011 = extractvalue { i32, i32, i32, i32 } %1004, 3
  %1012 = bitcast i32 %1011 to <2 x half>
  %1013 = shufflevector <2 x half> %1006, <2 x half> %1008, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %1014 = shufflevector <2 x half> %1010, <2 x half> %1012, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %1015 = shufflevector <4 x half> %1013, <4 x half> %1014, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  store <8 x half> %1015, ptr addrspace(5) %985, align 2
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 0, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.start.p0(ptr %26)
  store i64 0, ptr %26, align 8
  call void @llvm.lifetime.end.p0(ptr %25)
  %1016 = insertvalue [2 x ptr] undef, ptr %27, 0
  %1017 = insertvalue [2 x ptr] %1016, ptr %26, 1
  call void @llvm.lifetime.start.p0(ptr %25)
  store [2 x ptr] %1017, ptr %25, align 8
  %1018 = getelementptr inbounds [2 x ptr], ptr %25, i32 0, i32 0
  %1019 = load ptr, ptr %1018, align 8
  %1020 = load i64, ptr %1019, align 8
  %1021 = trunc i64 %1020 to i32
  %1022 = getelementptr inbounds ptr, ptr %1018, i32 1
  %1023 = load ptr, ptr %1022, align 8
  %1024 = load i64, ptr %1023, align 8
  %1025 = trunc i64 %1024 to i32
  %1026 = mul i32 %1021, 2
  %1027 = mul i32 %1026, 4
  %1028 = mul i32 %1025, 4
  %1029 = add i32 %1027, %1028
  %1030 = sext i32 %1029 to i64
  %1031 = trunc i64 %1030 to i32
  %1032 = getelementptr inbounds half, ptr addrspace(5) %445, i32 %1031
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 0, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 0, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %1033 = insertvalue [2 x ptr] undef, ptr %24, 0
  %1034 = insertvalue [2 x ptr] %1033, ptr %23, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %1034, ptr %22, align 8
  %1035 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %1036 = load ptr, ptr %1035, align 8
  %1037 = load i64, ptr %1036, align 8
  %1038 = trunc i64 %1037 to i32
  %1039 = getelementptr inbounds ptr, ptr %1035, i32 1
  %1040 = load ptr, ptr %1039, align 8
  %1041 = load i64, ptr %1040, align 8
  %1042 = trunc i64 %1041 to i32
  %1043 = mul i32 %1038, 16
  %1044 = mul i32 %1043, 32
  %1045 = mul i32 %1042, 32
  %1046 = add i32 %1044, %1045
  %1047 = sext i32 %1046 to i64
  %1048 = trunc i64 %1047 to i32
  %1049 = getelementptr inbounds half, ptr addrspace(3) %967, i32 %1048
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  %1050 = getelementptr inbounds half, ptr addrspace(3) %1049, i32 %484
  %1051 = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) %1050)
  %1052 = extractvalue { i32, i32, i32, i32 } %1051, 0
  %1053 = bitcast i32 %1052 to <2 x half>
  %1054 = extractvalue { i32, i32, i32, i32 } %1051, 1
  %1055 = bitcast i32 %1054 to <2 x half>
  %1056 = extractvalue { i32, i32, i32, i32 } %1051, 2
  %1057 = bitcast i32 %1056 to <2 x half>
  %1058 = extractvalue { i32, i32, i32, i32 } %1051, 3
  %1059 = bitcast i32 %1058 to <2 x half>
  %1060 = shufflevector <2 x half> %1053, <2 x half> %1055, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %1061 = shufflevector <2 x half> %1057, <2 x half> %1059, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %1062 = shufflevector <4 x half> %1060, <4 x half> %1061, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  %1063 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %1062, i64 0)
  %1064 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %1062, i64 4)
  store <4 x half> %1063, ptr addrspace(5) %1032, align 2
  %1065 = getelementptr inbounds half, ptr addrspace(5) %1032, i32 4
  store <4 x half> %1064, ptr addrspace(5) %1065, align 2
  br label %1067

1066:                                             ; preds = %921
  br label %1067

1067:                                             ; preds = %1066, %969
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 1, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 0, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %1068 = insertvalue [2 x ptr] undef, ptr %21, 0
  %1069 = insertvalue [2 x ptr] %1068, ptr %20, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %1069, ptr %19, align 8
  %1070 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %1071 = load ptr, ptr %1070, align 8
  %1072 = load i64, ptr %1071, align 8
  %1073 = trunc i64 %1072 to i32
  %1074 = getelementptr inbounds ptr, ptr %1070, i32 1
  %1075 = load ptr, ptr %1074, align 8
  %1076 = load i64, ptr %1075, align 8
  %1077 = trunc i64 %1076 to i32
  %1078 = mul i32 %1073, 8
  %1079 = mul i32 %1077, 8
  %1080 = add i32 %1078, %1079
  %1081 = sext i32 %1080 to i64
  %1082 = trunc i64 %1081 to i32
  %1083 = getelementptr inbounds half, ptr addrspace(5) %381, i32 %1082
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 1, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %1084 = insertvalue [2 x ptr] undef, ptr %18, 0
  %1085 = insertvalue [2 x ptr] %1084, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %1085, ptr %16, align 8
  %1086 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %1087 = load ptr, ptr %1086, align 8
  %1088 = load i64, ptr %1087, align 8
  %1089 = trunc i64 %1088 to i32
  %1090 = getelementptr inbounds ptr, ptr %1086, i32 1
  %1091 = load ptr, ptr %1090, align 8
  %1092 = load i64, ptr %1091, align 8
  %1093 = trunc i64 %1092 to i32
  %1094 = mul i32 %1089, 2
  %1095 = mul i32 %1094, 4
  %1096 = mul i32 %1093, 4
  %1097 = add i32 %1095, %1096
  %1098 = sext i32 %1097 to i64
  %1099 = trunc i64 %1098 to i32
  %1100 = getelementptr inbounds half, ptr addrspace(5) %445, i32 %1099
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  %1101 = load <4 x float>, ptr addrspace(5) %174, align 16
  %1102 = load <8 x half>, ptr addrspace(5) %1083, align 16
  %1103 = load <4 x half>, ptr addrspace(5) %1100, align 8
  %1104 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %1102, i64 0)
  %1105 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %1102, i64 4)
  %1106 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1104, i64 0)
  %1107 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1104, i64 2)
  %1108 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1105, i64 0)
  %1109 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1105, i64 2)
  %1110 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1103, i64 0)
  %1111 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1103, i64 2)
  %1112 = extractelement <4 x float> %1101, i64 0
  %1113 = extractelement <4 x float> %1101, i64 1
  %1114 = extractelement <4 x float> %1101, i64 2
  %1115 = extractelement <4 x float> %1101, i64 3
  %1116 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(<2 x half> %1106, <2 x half> %1107, <2 x half> %1108, <2 x half> %1109, <2 x half> %1110, <2 x half> %1111, float %1112, float %1113, float %1114, float %1115)
  %1117 = extractvalue { float, float, float, float } %1116, 0
  %1118 = extractvalue { float, float, float, float } %1116, 1
  %1119 = extractvalue { float, float, float, float } %1116, 2
  %1120 = extractvalue { float, float, float, float } %1116, 3
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store float %1117, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store float %1118, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store float %1119, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store float %1120, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %1121 = insertvalue [4 x ptr] undef, ptr %15, 0
  %1122 = insertvalue [4 x ptr] %1121, ptr %14, 1
  %1123 = insertvalue [4 x ptr] %1122, ptr %13, 2
  %1124 = insertvalue [4 x ptr] %1123, ptr %12, 3
  call void @llvm.lifetime.start.p0(ptr %11)
  store [4 x ptr] %1124, ptr %11, align 8
  %1125 = getelementptr inbounds [4 x ptr], ptr %11, i32 0, i32 0
  %1126 = load ptr, ptr %1125, align 8
  %1127 = load float, ptr %1126, align 4
  %1128 = insertelement <4 x float> undef, float %1127, i64 0
  %1129 = getelementptr inbounds ptr, ptr %1125, i32 1
  %1130 = load ptr, ptr %1129, align 8
  %1131 = load float, ptr %1130, align 4
  %1132 = insertelement <4 x float> %1128, float %1131, i64 1
  %1133 = getelementptr inbounds ptr, ptr %1125, i32 2
  %1134 = load ptr, ptr %1133, align 8
  %1135 = load float, ptr %1134, align 4
  %1136 = insertelement <4 x float> %1132, float %1135, i64 2
  %1137 = getelementptr inbounds ptr, ptr %1125, i32 3
  %1138 = load ptr, ptr %1137, align 8
  %1139 = load float, ptr %1138, align 4
  %1140 = insertelement <4 x float> %1136, float %1139, i64 3
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  store <4 x float> %1140, ptr addrspace(5) %174, align 16
  %1141 = load <4 x float>, ptr addrspace(5) %175, align 16
  %1142 = load <8 x half>, ptr addrspace(5) %1083, align 16
  %1143 = getelementptr inbounds half, ptr addrspace(5) %1100, i32 4
  %1144 = load <4 x half>, ptr addrspace(5) %1143, align 8
  %1145 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %1142, i64 0)
  %1146 = call <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half> %1142, i64 4)
  %1147 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1145, i64 0)
  %1148 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1145, i64 2)
  %1149 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1146, i64 0)
  %1150 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1146, i64 2)
  %1151 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1144, i64 0)
  %1152 = call <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half> %1144, i64 2)
  %1153 = extractelement <4 x float> %1141, i64 0
  %1154 = extractelement <4 x float> %1141, i64 1
  %1155 = extractelement <4 x float> %1141, i64 2
  %1156 = extractelement <4 x float> %1141, i64 3
  %1157 = call { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(<2 x half> %1147, <2 x half> %1148, <2 x half> %1149, <2 x half> %1150, <2 x half> %1151, <2 x half> %1152, float %1153, float %1154, float %1155, float %1156)
  %1158 = extractvalue { float, float, float, float } %1157, 0
  %1159 = extractvalue { float, float, float, float } %1157, 1
  %1160 = extractvalue { float, float, float, float } %1157, 2
  %1161 = extractvalue { float, float, float, float } %1157, 3
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store float %1158, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store float %1159, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store float %1160, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store float %1161, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %1162 = insertvalue [4 x ptr] undef, ptr %10, 0
  %1163 = insertvalue [4 x ptr] %1162, ptr %9, 1
  %1164 = insertvalue [4 x ptr] %1163, ptr %8, 2
  %1165 = insertvalue [4 x ptr] %1164, ptr %7, 3
  call void @llvm.lifetime.start.p0(ptr %6)
  store [4 x ptr] %1165, ptr %6, align 8
  %1166 = getelementptr inbounds [4 x ptr], ptr %6, i32 0, i32 0
  %1167 = load ptr, ptr %1166, align 8
  %1168 = load float, ptr %1167, align 4
  %1169 = insertelement <4 x float> undef, float %1168, i64 0
  %1170 = getelementptr inbounds ptr, ptr %1166, i32 1
  %1171 = load ptr, ptr %1170, align 8
  %1172 = load float, ptr %1171, align 4
  %1173 = insertelement <4 x float> %1169, float %1172, i64 1
  %1174 = getelementptr inbounds ptr, ptr %1166, i32 2
  %1175 = load ptr, ptr %1174, align 8
  %1176 = load float, ptr %1175, align 4
  %1177 = insertelement <4 x float> %1173, float %1176, i64 2
  %1178 = getelementptr inbounds ptr, ptr %1166, i32 3
  %1179 = load ptr, ptr %1178, align 8
  %1180 = load float, ptr %1179, align 4
  %1181 = insertelement <4 x float> %1177, float %1180, i64 3
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  store <4 x float> %1181, ptr addrspace(5) %175, align 16
  br label %501

1182:                                             ; preds = %799
  %1183 = sdiv i64 %196, 2
  %1184 = mul i64 %1183, 2
  %1185 = icmp eq i64 %1184, %196
  %1186 = xor i64 %196, 2
  %1187 = ashr i64 %1186, 63
  %1188 = select i1 %1185, i64 0, i64 %1187
  %1189 = add i64 %1183, %1188
  %1190 = sdiv i64 %1189, 16
  %1191 = mul i64 %1190, 16
  %1192 = sub i64 %1189, %1191
  %1193 = icmp slt i64 %1189, 0
  %1194 = icmp ne i64 %1192, 0
  %1195 = and i1 %1193, %1194
  %1196 = select i1 %1195, i64 16, i64 0
  %1197 = add i64 %1192, %1196
  %1198 = trunc i64 %1197 to i32
  %1199 = mul i32 %1198, 16
  %1200 = sdiv i64 %225, 2
  %1201 = mul i64 %1200, 2
  %1202 = sub i64 %225, %1201
  %1203 = icmp ne i64 %1202, 0
  %1204 = and i1 %229, %1203
  %1205 = select i1 %1204, i64 2, i64 0
  %1206 = add i64 %1202, %1205
  %1207 = trunc i64 %1206 to i32
  %1208 = mul i32 %1207, 8
  %1209 = add i32 %1199, %1208
  %1210 = sext i32 %1209 to i64
  %1211 = trunc i64 %1210 to i32
  %1212 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %1211
  %1213 = mul i32 %1198, 32
  %1214 = add i32 %1213, %1208
  %1215 = sext i32 %1214 to i64
  %1216 = getelementptr inbounds half, ptr %811, i64 %1215
  %1217 = ptrtoint ptr addrspace(3) %1212 to i64
  %1218 = sub i64 %1217, %846
  %1219 = sdiv i64 %1218, 2
  %1220 = mul i64 %1219, 2
  %1221 = icmp eq i64 %1220, %1218
  %1222 = xor i64 %1218, 2
  %1223 = ashr i64 %1222, 63
  %1224 = select i1 %1221, i64 0, i64 %1223
  %1225 = add i64 %1219, %1224
  %1226 = trunc i64 %1225 to i32
  %1227 = and i32 %1226, 112
  %1228 = ashr i32 %1227, 1
  %1229 = xor i32 %1226, %1228
  %1230 = sext i32 %1229 to i64
  %1231 = trunc i64 %1230 to i32
  %1232 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %1231
  %1233 = load <8 x half>, ptr addrspace(3) %1232, align 16
  store <8 x half> %1233, ptr %1216, align 16
  br label %1306

1234:                                             ; preds = %799
  %1235 = sdiv i64 %196, 2
  %1236 = mul i64 %1235, 2
  %1237 = icmp eq i64 %1236, %196
  %1238 = xor i64 %196, 2
  %1239 = ashr i64 %1238, 63
  %1240 = select i1 %1237, i64 0, i64 %1239
  %1241 = add i64 %1235, %1240
  %1242 = sdiv i64 %1241, 16
  %1243 = mul i64 %1242, 16
  %1244 = sub i64 %1241, %1243
  %1245 = icmp slt i64 %1241, 0
  %1246 = icmp ne i64 %1244, 0
  %1247 = and i1 %1245, %1246
  %1248 = select i1 %1247, i64 16, i64 0
  %1249 = add i64 %1244, %1248
  %1250 = trunc i64 %1249 to i32
  %1251 = mul i32 %1250, 16
  %1252 = sdiv i64 %225, 2
  %1253 = mul i64 %1252, 2
  %1254 = sub i64 %225, %1253
  %1255 = icmp ne i64 %1254, 0
  %1256 = and i1 %229, %1255
  %1257 = select i1 %1256, i64 2, i64 0
  %1258 = add i64 %1254, %1257
  %1259 = trunc i64 %1258 to i32
  %1260 = mul i32 %1259, 8
  %1261 = add i32 %1251, %1260
  %1262 = sext i32 %1261 to i64
  %1263 = trunc i64 %1262 to i32
  %1264 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %1263
  %1265 = mul i32 %1250, 32
  %1266 = add i32 %1265, %1260
  %1267 = sext i32 %1266 to i64
  %1268 = getelementptr inbounds half, ptr %811, i64 %1267
  %1269 = ptrtoint ptr addrspace(3) %1264 to i64
  %1270 = sub i64 %1269, %846
  %1271 = sdiv i64 %1270, 2
  %1272 = mul i64 %1271, 2
  %1273 = icmp eq i64 %1272, %1270
  %1274 = xor i64 %1270, 2
  %1275 = ashr i64 %1274, 63
  %1276 = select i1 %1273, i64 0, i64 %1275
  %1277 = add i64 %1271, %1276
  %1278 = trunc i64 %1277 to i32
  call void @llvm.lifetime.start.p0(ptr %4)
  store { i64 } %819, ptr %4, align 8
  %1279 = getelementptr { { i64 } }, ptr %4, i32 0, i32 0
  %1280 = getelementptr { i64 }, ptr %1279, i32 0, i32 0
  %1281 = load i64, ptr %1280, align 8
  %1282 = mul i64 %1281, 32
  %1283 = trunc i64 %1282 to i32
  %1284 = ptrtoint ptr %1268 to i64
  %1285 = sub i64 %1284, %812
  %1286 = sdiv i64 %1285, 2
  %1287 = mul i64 %1286, 2
  %1288 = icmp eq i64 %1287, %1285
  %1289 = xor i64 %1285, 2
  %1290 = ashr i64 %1289, 63
  %1291 = select i1 %1288, i64 0, i64 %1290
  %1292 = add i64 %1286, %1291
  %1293 = trunc i64 %1292 to i32
  %1294 = sub i32 %1283, %1293
  %1295 = and i32 %1278, 112
  %1296 = ashr i32 %1295, 1
  %1297 = xor i32 %1278, %1296
  %1298 = sext i32 %1297 to i64
  %1299 = trunc i64 %1298 to i32
  %1300 = getelementptr inbounds half, ptr addrspace(3) %830, i32 %1299
  %1301 = icmp slt i32 0, %1294
  br i1 %1301, label %1302, label %1304

1302:                                             ; preds = %1234
  %1303 = load <8 x half>, ptr addrspace(3) %1300, align 16
  store <8 x half> %1303, ptr %1268, align 16
  br label %1305

1304:                                             ; preds = %1234
  br label %1305

1305:                                             ; preds = %1304, %1302
  br label %1306

1306:                                             ; preds = %1305, %1182
  call void @llvm.lifetime.end.p0(ptr %91)
  call void @llvm.lifetime.end.p0(ptr %90)
  call void @llvm.lifetime.end.p0(ptr %89)
  call void @llvm.lifetime.end.p0(ptr %88)
  call void @llvm.lifetime.end.p0(ptr %5)
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.idx.i32(i32, i32, i32, i32) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, -2147483648) i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 65536) i32 @llvm.nvvm.read.ptx.sreg.nctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 64) i32 @llvm.nvvm.read.ptx.sreg.tid.z() #1

; Function Attrs: nounwind
declare void @llvm.nvvm.cp.async.commit.group() #4

; Function Attrs: nounwind
declare void @llvm.nvvm.cp.async.wait.group(i32 immarg) #4

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #5

; Function Attrs: convergent nocallback nounwind memory(argmem: read)
declare { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(ptr addrspace(3) readonly captures(none)) #6

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x half> @llvm.vector.extract.v4f16.v8f16(<8 x half>, i64 immarg) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #7

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x half> @llvm.vector.extract.v2f16.v4f16(<4 x half>, i64 immarg) #1

; Function Attrs: nocallback nounwind memory(none)
declare { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(<2 x half>, <2 x half>, <2 x half>, <2 x half>, <2 x half>, <2 x half>, float, float, float, float) #8

attributes #0 = { convergent norecurse "target-cpu"="sm_90a" "target-features"="+ptx85,+sm_90a" "tune-cpu"="sm_90a" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { nounwind }
attributes #5 = { convergent nocallback nounwind }
attributes #6 = { convergent nocallback nounwind memory(argmem: read) }
attributes #7 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #8 = { nocallback nounwind memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
