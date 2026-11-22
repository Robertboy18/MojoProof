; ModuleID = 'tiled_matmul.mojo'
source_filename = "tiled_matmul.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [256 x float] undef, align 4
@tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem = internal addrspace(3) global [256 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2) #0 {
  %4 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %5 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %4, 0
  %6 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %7 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %6, 0
  %8 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %9 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %8, 0
  %10 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %11 = zext i32 %10 to i64
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %13 = zext i32 %12 to i64
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %15 = zext i32 %14 to i64
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %17 = zext i32 %16 to i64
  %18 = mul i64 %17, 16
  %19 = add i64 %18, %13
  %20 = mul i64 %15, 16
  %21 = add i64 %20, %11
  %22 = trunc i64 %13 to i32
  %23 = mul i32 %22, 64
  %24 = trunc i64 %19 to i32
  %25 = mul i32 %24, 64
  %26 = trunc i64 %11 to i32
  %27 = add i32 %25, %26
  %28 = sext i32 %27 to i64
  %29 = getelementptr inbounds float, ptr %9, i64 %28
  %30 = trunc i64 %21 to i32
  %31 = add i32 %23, %30
  %32 = sext i32 %31 to i64
  %33 = getelementptr inbounds float, ptr %7, i64 %32
  %34 = icmp slt i64 %19, 64
  %35 = icmp slt i64 %11, 64
  %36 = select i1 %34, i1 %35, i1 false
  %37 = icmp slt i64 %13, 64
  %38 = icmp slt i64 %21, 64
  %39 = select i1 %37, i1 %38, i1 false
  br i1 %36, label %40, label %47

40:                                               ; preds = %3
  %41 = load float, ptr %29, align 4, !invariant.load !1
  %42 = mul i32 %22, 16
  %43 = add i32 %42, %26
  %44 = sext i32 %43 to i64
  %45 = trunc i64 %44 to i32
  %46 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %45
  store float %41, ptr addrspace(3) %46, align 4
  br label %53

47:                                               ; preds = %3
  %48 = mul i32 %22, 16
  %49 = add i32 %48, %26
  %50 = sext i32 %49 to i64
  %51 = trunc i64 %50 to i32
  %52 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %51
  store float 0.000000e+00, ptr addrspace(3) %52, align 4
  br label %53

53:                                               ; preds = %47, %40
  br i1 %39, label %54, label %61

54:                                               ; preds = %53
  %55 = load float, ptr %33, align 4, !invariant.load !1
  %56 = mul i32 %22, 16
  %57 = add i32 %56, %26
  %58 = sext i32 %57 to i64
  %59 = trunc i64 %58 to i32
  %60 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %59
  store float %55, ptr addrspace(3) %60, align 4
  br label %67

61:                                               ; preds = %53
  %62 = mul i32 %22, 16
  %63 = add i32 %62, %26
  %64 = sext i32 %63 to i64
  %65 = trunc i64 %64 to i32
  %66 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %65
  store float 0.000000e+00, ptr addrspace(3) %66, align 4
  br label %67

67:                                               ; preds = %61, %54
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %68 = mul i32 %22, 16
  %69 = sext i32 %68 to i64
  %70 = trunc i64 %69 to i32
  %71 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %70
  %72 = load float, ptr addrspace(3) %71, align 4
  %73 = sext i32 %26 to i64
  %74 = trunc i64 %73 to i32
  %75 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %74
  %76 = load float, ptr addrspace(3) %75, align 4
  %77 = fmul contract float %72, %76
  %78 = fadd contract float %77, 0.000000e+00
  %79 = add i32 %68, 1
  %80 = sext i32 %79 to i64
  %81 = trunc i64 %80 to i32
  %82 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %81
  %83 = load float, ptr addrspace(3) %82, align 4
  %84 = add i32 %26, 16
  %85 = sext i32 %84 to i64
  %86 = trunc i64 %85 to i32
  %87 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %86
  %88 = load float, ptr addrspace(3) %87, align 4
  %89 = fmul contract float %83, %88
  %90 = fadd contract float %78, %89
  %91 = add i32 %68, 2
  %92 = sext i32 %91 to i64
  %93 = trunc i64 %92 to i32
  %94 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %93
  %95 = load float, ptr addrspace(3) %94, align 4
  %96 = add i32 %26, 32
  %97 = sext i32 %96 to i64
  %98 = trunc i64 %97 to i32
  %99 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %98
  %100 = load float, ptr addrspace(3) %99, align 4
  %101 = fmul contract float %95, %100
  %102 = fadd contract float %90, %101
  %103 = add i32 %68, 3
  %104 = sext i32 %103 to i64
  %105 = trunc i64 %104 to i32
  %106 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %105
  %107 = load float, ptr addrspace(3) %106, align 4
  %108 = add i32 %26, 48
  %109 = sext i32 %108 to i64
  %110 = trunc i64 %109 to i32
  %111 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %110
  %112 = load float, ptr addrspace(3) %111, align 4
  %113 = fmul contract float %107, %112
  %114 = fadd contract float %102, %113
  %115 = add i32 %68, 4
  %116 = sext i32 %115 to i64
  %117 = trunc i64 %116 to i32
  %118 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %117
  %119 = load float, ptr addrspace(3) %118, align 4
  %120 = add i32 %26, 64
  %121 = sext i32 %120 to i64
  %122 = trunc i64 %121 to i32
  %123 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %122
  %124 = load float, ptr addrspace(3) %123, align 4
  %125 = fmul contract float %119, %124
  %126 = fadd contract float %114, %125
  %127 = add i32 %68, 5
  %128 = sext i32 %127 to i64
  %129 = trunc i64 %128 to i32
  %130 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %129
  %131 = load float, ptr addrspace(3) %130, align 4
  %132 = add i32 %26, 80
  %133 = sext i32 %132 to i64
  %134 = trunc i64 %133 to i32
  %135 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %134
  %136 = load float, ptr addrspace(3) %135, align 4
  %137 = fmul contract float %131, %136
  %138 = fadd contract float %126, %137
  %139 = add i32 %68, 6
  %140 = sext i32 %139 to i64
  %141 = trunc i64 %140 to i32
  %142 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %141
  %143 = load float, ptr addrspace(3) %142, align 4
  %144 = add i32 %26, 96
  %145 = sext i32 %144 to i64
  %146 = trunc i64 %145 to i32
  %147 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %146
  %148 = load float, ptr addrspace(3) %147, align 4
  %149 = fmul contract float %143, %148
  %150 = fadd contract float %138, %149
  %151 = add i32 %68, 7
  %152 = sext i32 %151 to i64
  %153 = trunc i64 %152 to i32
  %154 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %153
  %155 = load float, ptr addrspace(3) %154, align 4
  %156 = add i32 %26, 112
  %157 = sext i32 %156 to i64
  %158 = trunc i64 %157 to i32
  %159 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %158
  %160 = load float, ptr addrspace(3) %159, align 4
  %161 = fmul contract float %155, %160
  %162 = fadd contract float %150, %161
  %163 = add i32 %68, 8
  %164 = sext i32 %163 to i64
  %165 = trunc i64 %164 to i32
  %166 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %165
  %167 = load float, ptr addrspace(3) %166, align 4
  %168 = add i32 %26, 128
  %169 = sext i32 %168 to i64
  %170 = trunc i64 %169 to i32
  %171 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %170
  %172 = load float, ptr addrspace(3) %171, align 4
  %173 = fmul contract float %167, %172
  %174 = fadd contract float %162, %173
  %175 = add i32 %68, 9
  %176 = sext i32 %175 to i64
  %177 = trunc i64 %176 to i32
  %178 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %177
  %179 = load float, ptr addrspace(3) %178, align 4
  %180 = add i32 %26, 144
  %181 = sext i32 %180 to i64
  %182 = trunc i64 %181 to i32
  %183 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %182
  %184 = load float, ptr addrspace(3) %183, align 4
  %185 = fmul contract float %179, %184
  %186 = fadd contract float %174, %185
  %187 = add i32 %68, 10
  %188 = sext i32 %187 to i64
  %189 = trunc i64 %188 to i32
  %190 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %189
  %191 = load float, ptr addrspace(3) %190, align 4
  %192 = add i32 %26, 160
  %193 = sext i32 %192 to i64
  %194 = trunc i64 %193 to i32
  %195 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %194
  %196 = load float, ptr addrspace(3) %195, align 4
  %197 = fmul contract float %191, %196
  %198 = fadd contract float %186, %197
  %199 = add i32 %68, 11
  %200 = sext i32 %199 to i64
  %201 = trunc i64 %200 to i32
  %202 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %201
  %203 = load float, ptr addrspace(3) %202, align 4
  %204 = add i32 %26, 176
  %205 = sext i32 %204 to i64
  %206 = trunc i64 %205 to i32
  %207 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %206
  %208 = load float, ptr addrspace(3) %207, align 4
  %209 = fmul contract float %203, %208
  %210 = fadd contract float %198, %209
  %211 = add i32 %68, 12
  %212 = sext i32 %211 to i64
  %213 = trunc i64 %212 to i32
  %214 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %213
  %215 = load float, ptr addrspace(3) %214, align 4
  %216 = add i32 %26, 192
  %217 = sext i32 %216 to i64
  %218 = trunc i64 %217 to i32
  %219 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %218
  %220 = load float, ptr addrspace(3) %219, align 4
  %221 = fmul contract float %215, %220
  %222 = fadd contract float %210, %221
  %223 = add i32 %68, 13
  %224 = sext i32 %223 to i64
  %225 = trunc i64 %224 to i32
  %226 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %225
  %227 = load float, ptr addrspace(3) %226, align 4
  %228 = add i32 %26, 208
  %229 = sext i32 %228 to i64
  %230 = trunc i64 %229 to i32
  %231 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %230
  %232 = load float, ptr addrspace(3) %231, align 4
  %233 = fmul contract float %227, %232
  %234 = fadd contract float %222, %233
  %235 = add i32 %68, 14
  %236 = sext i32 %235 to i64
  %237 = trunc i64 %236 to i32
  %238 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %237
  %239 = load float, ptr addrspace(3) %238, align 4
  %240 = add i32 %26, 224
  %241 = sext i32 %240 to i64
  %242 = trunc i64 %241 to i32
  %243 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %242
  %244 = load float, ptr addrspace(3) %243, align 4
  %245 = fmul contract float %239, %244
  %246 = fadd contract float %234, %245
  %247 = add i32 %68, 15
  %248 = sext i32 %247 to i64
  %249 = trunc i64 %248 to i32
  %250 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %249
  %251 = load float, ptr addrspace(3) %250, align 4
  %252 = add i32 %26, 240
  %253 = sext i32 %252 to i64
  %254 = trunc i64 %253 to i32
  %255 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %254
  %256 = load float, ptr addrspace(3) %255, align 4
  %257 = fmul contract float %251, %256
  %258 = fadd contract float %246, %257
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %259 = add i64 %11, 16
  %260 = trunc i64 %259 to i32
  %261 = add i32 %25, %260
  %262 = sext i32 %261 to i64
  %263 = getelementptr inbounds float, ptr %9, i64 %262
  %264 = add i64 %13, 16
  %265 = trunc i64 %264 to i32
  %266 = mul i32 %265, 64
  %267 = add i32 %266, %30
  %268 = sext i32 %267 to i64
  %269 = getelementptr inbounds float, ptr %7, i64 %268
  %270 = icmp slt i64 %259, 64
  %271 = select i1 %34, i1 %270, i1 false
  %272 = icmp slt i64 %264, 64
  %273 = select i1 %272, i1 %38, i1 false
  br i1 %271, label %274, label %280

274:                                              ; preds = %67
  %275 = load float, ptr %263, align 4, !invariant.load !1
  %276 = add i32 %68, %26
  %277 = sext i32 %276 to i64
  %278 = trunc i64 %277 to i32
  %279 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %278
  store float %275, ptr addrspace(3) %279, align 4
  br label %285

280:                                              ; preds = %67
  %281 = add i32 %68, %26
  %282 = sext i32 %281 to i64
  %283 = trunc i64 %282 to i32
  %284 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %283
  store float 0.000000e+00, ptr addrspace(3) %284, align 4
  br label %285

285:                                              ; preds = %280, %274
  br i1 %273, label %286, label %292

286:                                              ; preds = %285
  %287 = load float, ptr %269, align 4, !invariant.load !1
  %288 = add i32 %68, %26
  %289 = sext i32 %288 to i64
  %290 = trunc i64 %289 to i32
  %291 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %290
  store float %287, ptr addrspace(3) %291, align 4
  br label %297

292:                                              ; preds = %285
  %293 = add i32 %68, %26
  %294 = sext i32 %293 to i64
  %295 = trunc i64 %294 to i32
  %296 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %295
  store float 0.000000e+00, ptr addrspace(3) %296, align 4
  br label %297

297:                                              ; preds = %292, %286
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %298 = load float, ptr addrspace(3) %71, align 4
  %299 = load float, ptr addrspace(3) %75, align 4
  %300 = fmul contract float %298, %299
  %301 = fadd contract float %258, %300
  %302 = load float, ptr addrspace(3) %82, align 4
  %303 = load float, ptr addrspace(3) %87, align 4
  %304 = fmul contract float %302, %303
  %305 = fadd contract float %301, %304
  %306 = load float, ptr addrspace(3) %94, align 4
  %307 = load float, ptr addrspace(3) %99, align 4
  %308 = fmul contract float %306, %307
  %309 = fadd contract float %305, %308
  %310 = load float, ptr addrspace(3) %106, align 4
  %311 = load float, ptr addrspace(3) %111, align 4
  %312 = fmul contract float %310, %311
  %313 = fadd contract float %309, %312
  %314 = load float, ptr addrspace(3) %118, align 4
  %315 = load float, ptr addrspace(3) %123, align 4
  %316 = fmul contract float %314, %315
  %317 = fadd contract float %313, %316
  %318 = load float, ptr addrspace(3) %130, align 4
  %319 = load float, ptr addrspace(3) %135, align 4
  %320 = fmul contract float %318, %319
  %321 = fadd contract float %317, %320
  %322 = load float, ptr addrspace(3) %142, align 4
  %323 = load float, ptr addrspace(3) %147, align 4
  %324 = fmul contract float %322, %323
  %325 = fadd contract float %321, %324
  %326 = load float, ptr addrspace(3) %154, align 4
  %327 = load float, ptr addrspace(3) %159, align 4
  %328 = fmul contract float %326, %327
  %329 = fadd contract float %325, %328
  %330 = load float, ptr addrspace(3) %166, align 4
  %331 = load float, ptr addrspace(3) %171, align 4
  %332 = fmul contract float %330, %331
  %333 = fadd contract float %329, %332
  %334 = load float, ptr addrspace(3) %178, align 4
  %335 = load float, ptr addrspace(3) %183, align 4
  %336 = fmul contract float %334, %335
  %337 = fadd contract float %333, %336
  %338 = load float, ptr addrspace(3) %190, align 4
  %339 = load float, ptr addrspace(3) %195, align 4
  %340 = fmul contract float %338, %339
  %341 = fadd contract float %337, %340
  %342 = load float, ptr addrspace(3) %202, align 4
  %343 = load float, ptr addrspace(3) %207, align 4
  %344 = fmul contract float %342, %343
  %345 = fadd contract float %341, %344
  %346 = load float, ptr addrspace(3) %214, align 4
  %347 = load float, ptr addrspace(3) %219, align 4
  %348 = fmul contract float %346, %347
  %349 = fadd contract float %345, %348
  %350 = load float, ptr addrspace(3) %226, align 4
  %351 = load float, ptr addrspace(3) %231, align 4
  %352 = fmul contract float %350, %351
  %353 = fadd contract float %349, %352
  %354 = load float, ptr addrspace(3) %238, align 4
  %355 = load float, ptr addrspace(3) %243, align 4
  %356 = fmul contract float %354, %355
  %357 = fadd contract float %353, %356
  %358 = load float, ptr addrspace(3) %250, align 4
  %359 = load float, ptr addrspace(3) %255, align 4
  %360 = fmul contract float %358, %359
  %361 = fadd contract float %357, %360
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %362 = add i64 %11, 32
  %363 = trunc i64 %362 to i32
  %364 = add i32 %25, %363
  %365 = sext i32 %364 to i64
  %366 = getelementptr inbounds float, ptr %9, i64 %365
  %367 = add i64 %13, 32
  %368 = trunc i64 %367 to i32
  %369 = mul i32 %368, 64
  %370 = add i32 %369, %30
  %371 = sext i32 %370 to i64
  %372 = getelementptr inbounds float, ptr %7, i64 %371
  %373 = icmp slt i64 %362, 64
  %374 = select i1 %34, i1 %373, i1 false
  %375 = icmp slt i64 %367, 64
  %376 = select i1 %375, i1 %38, i1 false
  br i1 %374, label %377, label %383

377:                                              ; preds = %297
  %378 = load float, ptr %366, align 4, !invariant.load !1
  %379 = add i32 %68, %26
  %380 = sext i32 %379 to i64
  %381 = trunc i64 %380 to i32
  %382 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %381
  store float %378, ptr addrspace(3) %382, align 4
  br label %388

383:                                              ; preds = %297
  %384 = add i32 %68, %26
  %385 = sext i32 %384 to i64
  %386 = trunc i64 %385 to i32
  %387 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %386
  store float 0.000000e+00, ptr addrspace(3) %387, align 4
  br label %388

388:                                              ; preds = %383, %377
  br i1 %376, label %389, label %395

389:                                              ; preds = %388
  %390 = load float, ptr %372, align 4, !invariant.load !1
  %391 = add i32 %68, %26
  %392 = sext i32 %391 to i64
  %393 = trunc i64 %392 to i32
  %394 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %393
  store float %390, ptr addrspace(3) %394, align 4
  br label %400

395:                                              ; preds = %388
  %396 = add i32 %68, %26
  %397 = sext i32 %396 to i64
  %398 = trunc i64 %397 to i32
  %399 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %398
  store float 0.000000e+00, ptr addrspace(3) %399, align 4
  br label %400

400:                                              ; preds = %395, %389
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %401 = load float, ptr addrspace(3) %71, align 4
  %402 = load float, ptr addrspace(3) %75, align 4
  %403 = fmul contract float %401, %402
  %404 = fadd contract float %361, %403
  %405 = load float, ptr addrspace(3) %82, align 4
  %406 = load float, ptr addrspace(3) %87, align 4
  %407 = fmul contract float %405, %406
  %408 = fadd contract float %404, %407
  %409 = load float, ptr addrspace(3) %94, align 4
  %410 = load float, ptr addrspace(3) %99, align 4
  %411 = fmul contract float %409, %410
  %412 = fadd contract float %408, %411
  %413 = load float, ptr addrspace(3) %106, align 4
  %414 = load float, ptr addrspace(3) %111, align 4
  %415 = fmul contract float %413, %414
  %416 = fadd contract float %412, %415
  %417 = load float, ptr addrspace(3) %118, align 4
  %418 = load float, ptr addrspace(3) %123, align 4
  %419 = fmul contract float %417, %418
  %420 = fadd contract float %416, %419
  %421 = load float, ptr addrspace(3) %130, align 4
  %422 = load float, ptr addrspace(3) %135, align 4
  %423 = fmul contract float %421, %422
  %424 = fadd contract float %420, %423
  %425 = load float, ptr addrspace(3) %142, align 4
  %426 = load float, ptr addrspace(3) %147, align 4
  %427 = fmul contract float %425, %426
  %428 = fadd contract float %424, %427
  %429 = load float, ptr addrspace(3) %154, align 4
  %430 = load float, ptr addrspace(3) %159, align 4
  %431 = fmul contract float %429, %430
  %432 = fadd contract float %428, %431
  %433 = load float, ptr addrspace(3) %166, align 4
  %434 = load float, ptr addrspace(3) %171, align 4
  %435 = fmul contract float %433, %434
  %436 = fadd contract float %432, %435
  %437 = load float, ptr addrspace(3) %178, align 4
  %438 = load float, ptr addrspace(3) %183, align 4
  %439 = fmul contract float %437, %438
  %440 = fadd contract float %436, %439
  %441 = load float, ptr addrspace(3) %190, align 4
  %442 = load float, ptr addrspace(3) %195, align 4
  %443 = fmul contract float %441, %442
  %444 = fadd contract float %440, %443
  %445 = load float, ptr addrspace(3) %202, align 4
  %446 = load float, ptr addrspace(3) %207, align 4
  %447 = fmul contract float %445, %446
  %448 = fadd contract float %444, %447
  %449 = load float, ptr addrspace(3) %214, align 4
  %450 = load float, ptr addrspace(3) %219, align 4
  %451 = fmul contract float %449, %450
  %452 = fadd contract float %448, %451
  %453 = load float, ptr addrspace(3) %226, align 4
  %454 = load float, ptr addrspace(3) %231, align 4
  %455 = fmul contract float %453, %454
  %456 = fadd contract float %452, %455
  %457 = load float, ptr addrspace(3) %238, align 4
  %458 = load float, ptr addrspace(3) %243, align 4
  %459 = fmul contract float %457, %458
  %460 = fadd contract float %456, %459
  %461 = load float, ptr addrspace(3) %250, align 4
  %462 = load float, ptr addrspace(3) %255, align 4
  %463 = fmul contract float %461, %462
  %464 = fadd contract float %460, %463
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %465 = add i64 %11, 48
  %466 = trunc i64 %465 to i32
  %467 = add i32 %25, %466
  %468 = sext i32 %467 to i64
  %469 = getelementptr inbounds float, ptr %9, i64 %468
  %470 = add i64 %13, 48
  %471 = trunc i64 %470 to i32
  %472 = mul i32 %471, 64
  %473 = add i32 %472, %30
  %474 = sext i32 %473 to i64
  %475 = getelementptr inbounds float, ptr %7, i64 %474
  %476 = icmp slt i64 %465, 64
  %477 = select i1 %34, i1 %476, i1 false
  %478 = icmp slt i64 %470, 64
  %479 = select i1 %478, i1 %38, i1 false
  br i1 %477, label %480, label %486

480:                                              ; preds = %400
  %481 = load float, ptr %469, align 4, !invariant.load !1
  %482 = add i32 %68, %26
  %483 = sext i32 %482 to i64
  %484 = trunc i64 %483 to i32
  %485 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %484
  store float %481, ptr addrspace(3) %485, align 4
  br label %491

486:                                              ; preds = %400
  %487 = add i32 %68, %26
  %488 = sext i32 %487 to i64
  %489 = trunc i64 %488 to i32
  %490 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_0._gpu_shared_mem, i32 %489
  store float 0.000000e+00, ptr addrspace(3) %490, align 4
  br label %491

491:                                              ; preds = %486, %480
  br i1 %479, label %492, label %498

492:                                              ; preds = %491
  %493 = load float, ptr %475, align 4, !invariant.load !1
  %494 = add i32 %68, %26
  %495 = sext i32 %494 to i64
  %496 = trunc i64 %495 to i32
  %497 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %496
  store float %493, ptr addrspace(3) %497, align 4
  br label %503

498:                                              ; preds = %491
  %499 = add i32 %68, %26
  %500 = sext i32 %499 to i64
  %501 = trunc i64 %500 to i32
  %502 = getelementptr inbounds float, ptr addrspace(3) @tiled_matmul_tiled_matmul_kerne6A6A_2b5f0ce79ef83e63._global_alloc_1._gpu_shared_mem, i32 %501
  store float 0.000000e+00, ptr addrspace(3) %502, align 4
  br label %503

503:                                              ; preds = %498, %492
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %504 = load float, ptr addrspace(3) %71, align 4
  %505 = load float, ptr addrspace(3) %75, align 4
  %506 = fmul contract float %504, %505
  %507 = fadd contract float %464, %506
  %508 = load float, ptr addrspace(3) %82, align 4
  %509 = load float, ptr addrspace(3) %87, align 4
  %510 = fmul contract float %508, %509
  %511 = fadd contract float %507, %510
  %512 = load float, ptr addrspace(3) %94, align 4
  %513 = load float, ptr addrspace(3) %99, align 4
  %514 = fmul contract float %512, %513
  %515 = fadd contract float %511, %514
  %516 = load float, ptr addrspace(3) %106, align 4
  %517 = load float, ptr addrspace(3) %111, align 4
  %518 = fmul contract float %516, %517
  %519 = fadd contract float %515, %518
  %520 = load float, ptr addrspace(3) %118, align 4
  %521 = load float, ptr addrspace(3) %123, align 4
  %522 = fmul contract float %520, %521
  %523 = fadd contract float %519, %522
  %524 = load float, ptr addrspace(3) %130, align 4
  %525 = load float, ptr addrspace(3) %135, align 4
  %526 = fmul contract float %524, %525
  %527 = fadd contract float %523, %526
  %528 = load float, ptr addrspace(3) %142, align 4
  %529 = load float, ptr addrspace(3) %147, align 4
  %530 = fmul contract float %528, %529
  %531 = fadd contract float %527, %530
  %532 = load float, ptr addrspace(3) %154, align 4
  %533 = load float, ptr addrspace(3) %159, align 4
  %534 = fmul contract float %532, %533
  %535 = fadd contract float %531, %534
  %536 = load float, ptr addrspace(3) %166, align 4
  %537 = load float, ptr addrspace(3) %171, align 4
  %538 = fmul contract float %536, %537
  %539 = fadd contract float %535, %538
  %540 = load float, ptr addrspace(3) %178, align 4
  %541 = load float, ptr addrspace(3) %183, align 4
  %542 = fmul contract float %540, %541
  %543 = fadd contract float %539, %542
  %544 = load float, ptr addrspace(3) %190, align 4
  %545 = load float, ptr addrspace(3) %195, align 4
  %546 = fmul contract float %544, %545
  %547 = fadd contract float %543, %546
  %548 = load float, ptr addrspace(3) %202, align 4
  %549 = load float, ptr addrspace(3) %207, align 4
  %550 = fmul contract float %548, %549
  %551 = fadd contract float %547, %550
  %552 = load float, ptr addrspace(3) %214, align 4
  %553 = load float, ptr addrspace(3) %219, align 4
  %554 = fmul contract float %552, %553
  %555 = fadd contract float %551, %554
  %556 = load float, ptr addrspace(3) %226, align 4
  %557 = load float, ptr addrspace(3) %231, align 4
  %558 = fmul contract float %556, %557
  %559 = fadd contract float %555, %558
  %560 = load float, ptr addrspace(3) %238, align 4
  %561 = load float, ptr addrspace(3) %243, align 4
  %562 = fmul contract float %560, %561
  %563 = fadd contract float %559, %562
  %564 = load float, ptr addrspace(3) %250, align 4
  %565 = load float, ptr addrspace(3) %255, align 4
  %566 = fmul contract float %564, %565
  %567 = fadd contract float %563, %566
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %568 = select i1 %34, i1 %38, i1 false
  br i1 %568, label %569, label %573

569:                                              ; preds = %503
  %570 = add i32 %25, %30
  %571 = sext i32 %570 to i64
  %572 = getelementptr inbounds float, ptr %5, i64 %571
  store float %567, ptr %572, align 4
  br label %574

573:                                              ; preds = %503
  br label %574

574:                                              ; preds = %573, %569
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #2

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
