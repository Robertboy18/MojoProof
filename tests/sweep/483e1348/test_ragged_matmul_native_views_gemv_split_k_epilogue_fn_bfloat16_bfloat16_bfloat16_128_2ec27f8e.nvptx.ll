; ModuleID = 'test_ragged_matmul_native_views.mojo'
source_filename = "test_ragged_matmul_native_views.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
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
  %20 = alloca float, i64 1, align 4
  %21 = alloca [8 x bfloat], align 16
  %22 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %23 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %24 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %23, 0
  %25 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %22, 0
  %26 = sext i32 %5 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %30 = zext i32 %29 to i64
  %31 = trunc i64 %30 to i32
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %33 = mul i32 %32, 8
  %34 = sext i32 %33 to i64
  %35 = zext i32 %32 to i64
  call void @llvm.lifetime.start.p0(ptr %21)
  %36 = addrspacecast ptr %21 to ptr addrspace(5)
  call void @llvm.lifetime.start.p0(ptr %20)
  %37 = addrspacecast ptr %20 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %37, align 4
  %38 = mul i64 %35, 8
  %39 = icmp slt i64 %38, %26
  br i1 %39, label %40, label %58

40:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %30, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 0, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  %41 = insertvalue [2 x ptr] undef, ptr %19, 0
  %42 = insertvalue [2 x ptr] %41, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %17)
  store [2 x ptr] %42, ptr %17, align 8
  %43 = getelementptr inbounds [2 x ptr], ptr %17, i32 0, i32 0
  %44 = load ptr, ptr %43, align 8
  %45 = load i64, ptr %44, align 8
  %46 = trunc i64 %45 to i32
  %47 = getelementptr inbounds ptr, ptr %43, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = load i64, ptr %48, align 8
  %50 = trunc i64 %49 to i32
  %51 = mul i32 %46, 64
  %52 = mul i32 %50, 1024
  %53 = add i32 %51, %52
  %54 = sext i32 %53 to i64
  %55 = getelementptr inbounds bfloat, ptr %25, i64 %54
  %56 = getelementptr inbounds bfloat, ptr %55, i64 %34
  %57 = load <8 x bfloat>, ptr %56, align 16, !invariant.load !1
  store <8 x bfloat> %57, ptr addrspace(5) %36, align 16
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  br label %59

58:                                               ; preds = %7
  br label %59

59:                                               ; preds = %58, %40
  %60 = select i1 %39, i64 1, i64 0
  br i1 %39, label %61, label %112

61:                                               ; preds = %59
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 %28, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 0, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %62 = insertvalue [2 x ptr] undef, ptr %16, 0
  %63 = insertvalue [2 x ptr] %62, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %63, ptr %14, align 8
  %64 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %65 = load ptr, ptr %64, align 8
  %66 = load i64, ptr %65, align 8
  %67 = getelementptr inbounds ptr, ptr %64, i32 1
  %68 = load ptr, ptr %67, align 8
  %69 = load i64, ptr %68, align 8
  %70 = mul i64 %66, 64
  %71 = mul i64 %69, 1024
  %72 = add i64 %70, %71
  %73 = getelementptr inbounds bfloat, ptr %24, i64 %72
  %74 = getelementptr inbounds bfloat, ptr %73, i64 %34
  %75 = load <8 x bfloat>, ptr %74, align 16, !invariant.load !1
  %76 = load <8 x bfloat>, ptr addrspace(5) %36, align 16
  %77 = load float, ptr addrspace(5) %37, align 4
  %78 = fpext <8 x bfloat> %75 to <8 x float>
  %79 = fpext <8 x bfloat> %76 to <8 x float>
  %80 = extractelement <8 x float> %78, i64 0
  %81 = extractelement <8 x float> %79, i64 0
  %82 = fmul contract float %80, %81
  %83 = fadd contract float %77, %82
  %84 = extractelement <8 x float> %78, i64 1
  %85 = extractelement <8 x float> %79, i64 1
  %86 = fmul contract float %84, %85
  %87 = fadd contract float %83, %86
  %88 = extractelement <8 x float> %78, i64 2
  %89 = extractelement <8 x float> %79, i64 2
  %90 = fmul contract float %88, %89
  %91 = fadd contract float %87, %90
  %92 = extractelement <8 x float> %78, i64 3
  %93 = extractelement <8 x float> %79, i64 3
  %94 = fmul contract float %92, %93
  %95 = fadd contract float %91, %94
  %96 = extractelement <8 x float> %78, i64 4
  %97 = extractelement <8 x float> %79, i64 4
  %98 = fmul contract float %96, %97
  %99 = fadd contract float %95, %98
  %100 = extractelement <8 x float> %78, i64 5
  %101 = extractelement <8 x float> %79, i64 5
  %102 = fmul contract float %100, %101
  %103 = fadd contract float %99, %102
  %104 = extractelement <8 x float> %78, i64 6
  %105 = extractelement <8 x float> %79, i64 6
  %106 = fmul contract float %104, %105
  %107 = fadd contract float %103, %106
  %108 = extractelement <8 x float> %78, i64 7
  %109 = extractelement <8 x float> %79, i64 7
  %110 = fmul contract float %108, %109
  %111 = fadd contract float %107, %110
  store float %111, ptr addrspace(5) %37, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %113

112:                                              ; preds = %59
  br label %113

113:                                              ; preds = %112, %61
  %114 = add i64 %38, 1024
  br label %115

115:                                              ; preds = %158, %113
  %116 = phi i64 [ %114, %113 ], [ %126, %158 ]
  %117 = phi i64 [ 0, %113 ], [ %127, %158 ]
  %118 = phi i64 [ %60, %113 ], [ %226, %158 ]
  %119 = add i64 %116, 1024
  %120 = icmp slt i64 %119, %116
  %121 = select i1 %120, i64 1, i64 0
  %122 = icmp sge i64 %116, %26
  %123 = icmp eq i64 %117, 0
  %124 = xor i1 %123, true
  %125 = or i1 %124, %122
  %126 = select i1 %125, i64 %116, i64 %119
  %127 = select i1 %125, i64 %117, i64 %121
  br i1 %125, label %128, label %158

128:                                              ; preds = %115
  %129 = udiv i64 %35, 32
  %130 = trunc i64 %129 to i32
  %131 = sext i32 %130 to i64
  %132 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %133 = sext i32 %132 to i64
  %134 = trunc i64 %131 to i32
  %135 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e._global_alloc_0._gpu_shared_mem, i32 %134
  %136 = load float, ptr addrspace(5) %37, align 4
  %137 = bitcast float %136 to i32
  %138 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %137, i32 16, i32 31)
  %139 = bitcast i32 %138 to float
  %140 = fadd contract float %136, %139
  %141 = bitcast float %140 to i32
  %142 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %141, i32 8, i32 31)
  %143 = bitcast i32 %142 to float
  %144 = fadd contract float %140, %143
  %145 = bitcast float %144 to i32
  %146 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %145, i32 4, i32 31)
  %147 = bitcast i32 %146 to float
  %148 = fadd contract float %144, %147
  %149 = bitcast float %148 to i32
  %150 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %149, i32 2, i32 31)
  %151 = bitcast i32 %150 to float
  %152 = fadd contract float %148, %151
  %153 = bitcast float %152 to i32
  %154 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %153, i32 1, i32 31)
  %155 = bitcast i32 %154 to float
  %156 = fadd contract float %152, %155
  %157 = icmp eq i64 %133, 0
  br i1 %157, label %227, label %228

158:                                              ; preds = %115
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %30, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %118, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %159 = insertvalue [2 x ptr] undef, ptr %13, 0
  %160 = insertvalue [2 x ptr] %159, ptr %12, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %160, ptr %11, align 8
  %161 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = trunc i64 %163 to i32
  %165 = getelementptr inbounds ptr, ptr %161, i32 1
  %166 = load ptr, ptr %165, align 8
  %167 = load i64, ptr %166, align 8
  %168 = trunc i64 %167 to i32
  %169 = mul i32 %164, 64
  %170 = mul i32 %168, 1024
  %171 = add i32 %169, %170
  %172 = sext i32 %171 to i64
  %173 = getelementptr inbounds bfloat, ptr %25, i64 %172
  %174 = getelementptr inbounds bfloat, ptr %173, i64 %34
  %175 = load <8 x bfloat>, ptr %174, align 16, !invariant.load !1
  store <8 x bfloat> %175, ptr addrspace(5) %36, align 16
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %28, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %118, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %176 = insertvalue [2 x ptr] undef, ptr %10, 0
  %177 = insertvalue [2 x ptr] %176, ptr %9, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %177, ptr %8, align 8
  %178 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %179 = load ptr, ptr %178, align 8
  %180 = load i64, ptr %179, align 8
  %181 = getelementptr inbounds ptr, ptr %178, i32 1
  %182 = load ptr, ptr %181, align 8
  %183 = load i64, ptr %182, align 8
  %184 = mul i64 %180, 64
  %185 = mul i64 %183, 1024
  %186 = add i64 %184, %185
  %187 = getelementptr inbounds bfloat, ptr %24, i64 %186
  %188 = getelementptr inbounds bfloat, ptr %187, i64 %34
  %189 = load <8 x bfloat>, ptr %188, align 16, !invariant.load !1
  %190 = load <8 x bfloat>, ptr addrspace(5) %36, align 16
  %191 = load float, ptr addrspace(5) %37, align 4
  %192 = fpext <8 x bfloat> %189 to <8 x float>
  %193 = fpext <8 x bfloat> %190 to <8 x float>
  %194 = extractelement <8 x float> %192, i64 0
  %195 = extractelement <8 x float> %193, i64 0
  %196 = fmul contract float %194, %195
  %197 = fadd contract float %191, %196
  %198 = extractelement <8 x float> %192, i64 1
  %199 = extractelement <8 x float> %193, i64 1
  %200 = fmul contract float %198, %199
  %201 = fadd contract float %197, %200
  %202 = extractelement <8 x float> %192, i64 2
  %203 = extractelement <8 x float> %193, i64 2
  %204 = fmul contract float %202, %203
  %205 = fadd contract float %201, %204
  %206 = extractelement <8 x float> %192, i64 3
  %207 = extractelement <8 x float> %193, i64 3
  %208 = fmul contract float %206, %207
  %209 = fadd contract float %205, %208
  %210 = extractelement <8 x float> %192, i64 4
  %211 = extractelement <8 x float> %193, i64 4
  %212 = fmul contract float %210, %211
  %213 = fadd contract float %209, %212
  %214 = extractelement <8 x float> %192, i64 5
  %215 = extractelement <8 x float> %193, i64 5
  %216 = fmul contract float %214, %215
  %217 = fadd contract float %213, %216
  %218 = extractelement <8 x float> %192, i64 6
  %219 = extractelement <8 x float> %193, i64 6
  %220 = fmul contract float %218, %219
  %221 = fadd contract float %217, %220
  %222 = extractelement <8 x float> %192, i64 7
  %223 = extractelement <8 x float> %193, i64 7
  %224 = fmul contract float %222, %223
  %225 = fadd contract float %221, %224
  store float %225, ptr addrspace(5) %37, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %226 = add i64 %118, 1
  br label %115

227:                                              ; preds = %128
  store float %156, ptr addrspace(3) %135, align 4
  br label %229

228:                                              ; preds = %128
  br label %229

229:                                              ; preds = %228, %227
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %230

230:                                              ; preds = %243, %229
  %231 = phi i64 [ %35, %229 ], [ %240, %243 ]
  %232 = phi i64 [ 0, %229 ], [ %241, %243 ]
  %233 = add i64 %231, 128
  %234 = icmp slt i64 %233, %231
  %235 = select i1 %234, i64 1, i64 0
  %236 = icmp sge i64 %231, 1
  %237 = icmp eq i64 %232, 0
  %238 = xor i1 %237, true
  %239 = or i1 %238, %236
  %240 = select i1 %239, i64 %231, i64 %233
  %241 = select i1 %239, i64 %232, i64 %235
  br i1 %239, label %242, label %243

242:                                              ; preds = %230
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %20)
  ret void

243:                                              ; preds = %230
  %244 = trunc i64 %231 to i32
  %245 = sext i32 %244 to i64
  %246 = trunc i64 %245 to i32
  %247 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e._global_alloc_0._gpu_shared_mem, i32 %246
  %248 = load float, ptr addrspace(3) %247, align 4
  %249 = fadd contract float %248, 0.000000e+00
  %250 = add i64 %231, 1
  %251 = trunc i64 %250 to i32
  %252 = sext i32 %251 to i64
  %253 = trunc i64 %252 to i32
  %254 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e._global_alloc_0._gpu_shared_mem, i32 %253
  %255 = load float, ptr addrspace(3) %254, align 4
  %256 = fadd contract float %249, %255
  %257 = add i64 %231, 2
  %258 = trunc i64 %257 to i32
  %259 = sext i32 %258 to i64
  %260 = trunc i64 %259 to i32
  %261 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e._global_alloc_0._gpu_shared_mem, i32 %260
  %262 = load float, ptr addrspace(3) %261, align 4
  %263 = fadd contract float %256, %262
  %264 = add i64 %231, 3
  %265 = trunc i64 %264 to i32
  %266 = sext i32 %265 to i64
  %267 = trunc i64 %266 to i32
  %268 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_epilogue_fn_bfloat16_bfloat16_bfloat16_128_2ec27f8e._global_alloc_0._gpu_shared_mem, i32 %267
  %269 = load float, ptr addrspace(3) %268, align 4
  %270 = fadd contract float %263, %269
  %271 = add i64 %28, %231
  %272 = fptrunc float %270 to bfloat
  %273 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %274 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %273, 0
  %275 = trunc i64 %271 to i32
  %276 = mul i32 %275, 80
  %277 = add i32 %276, %31
  %278 = sext i32 %277 to i64
  %279 = getelementptr inbounds bfloat, ptr %274, i64 %278
  store bfloat %272, ptr %279, align 2
  br label %230
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
