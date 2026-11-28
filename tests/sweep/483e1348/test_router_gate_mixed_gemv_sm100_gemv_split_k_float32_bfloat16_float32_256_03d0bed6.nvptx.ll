; ModuleID = 'test_router_gate_mixed_gemv_sm100.mojo'
source_filename = "test_router_gate_mixed_gemv_sm100.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [8 x float] undef, align 4

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_float32_bfloat16_float32_256_03d0bed6(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #1 {
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
  %19 = alloca float, i64 1, align 4
  %20 = alloca [4 x float], align 16
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
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %33 = mul i32 %32, 4
  %34 = sext i32 %33 to i64
  %35 = zext i32 %32 to i64
  call void @llvm.lifetime.start.p0(ptr %20)
  %36 = addrspacecast ptr %20 to ptr addrspace(5)
  call void @llvm.lifetime.start.p0(ptr %19)
  %37 = addrspacecast ptr %19 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %37, align 4
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  %38 = mul i64 %35, 4
  %39 = icmp slt i64 %38, %27
  br i1 %39, label %40, label %58

40:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %31, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %41 = insertvalue [2 x ptr] undef, ptr %18, 0
  %42 = insertvalue [2 x ptr] %41, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %42, ptr %16, align 8
  %43 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %44 = load ptr, ptr %43, align 8
  %45 = load i64, ptr %44, align 8
  %46 = trunc i64 %45 to i32
  %47 = getelementptr inbounds ptr, ptr %43, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = load i64, ptr %48, align 8
  %50 = trunc i64 %49 to i32
  %51 = mul i32 %46, 6144
  %52 = mul i32 %50, 1024
  %53 = add i32 %51, %52
  %54 = sext i32 %53 to i64
  %55 = getelementptr inbounds float, ptr %26, i64 %54
  %56 = getelementptr inbounds float, ptr %55, i64 %34
  %57 = load <4 x float>, ptr %56, align 16, !invariant.load !1
  store <4 x float> %57, ptr addrspace(5) %36, align 16
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %59

58:                                               ; preds = %6
  br label %59

59:                                               ; preds = %58, %40
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %60 = select i1 %39, i64 1, i64 0
  br i1 %39, label %61, label %95

61:                                               ; preds = %59
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %29, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 0, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %62 = insertvalue [2 x ptr] undef, ptr %15, 0
  %63 = insertvalue [2 x ptr] %62, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %63, ptr %13, align 8
  %64 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %65 = load ptr, ptr %64, align 8
  %66 = load i64, ptr %65, align 8
  %67 = getelementptr inbounds ptr, ptr %64, i32 1
  %68 = load ptr, ptr %67, align 8
  %69 = load i64, ptr %68, align 8
  %70 = mul i64 %66, 6144
  %71 = mul i64 %69, 1024
  %72 = add i64 %70, %71
  %73 = getelementptr inbounds bfloat, ptr %25, i64 %72
  %74 = getelementptr inbounds bfloat, ptr %73, i64 %34
  %75 = load <4 x bfloat>, ptr %74, align 8, !invariant.load !1
  %76 = load <4 x float>, ptr addrspace(5) %36, align 16
  %77 = load float, ptr addrspace(5) %37, align 4
  %78 = fpext <4 x bfloat> %75 to <4 x float>
  %79 = extractelement <4 x float> %78, i64 0
  %80 = extractelement <4 x float> %76, i64 0
  %81 = fmul contract float %79, %80
  %82 = fadd contract float %77, %81
  %83 = extractelement <4 x float> %78, i64 1
  %84 = extractelement <4 x float> %76, i64 1
  %85 = fmul contract float %83, %84
  %86 = fadd contract float %82, %85
  %87 = extractelement <4 x float> %78, i64 2
  %88 = extractelement <4 x float> %76, i64 2
  %89 = fmul contract float %87, %88
  %90 = fadd contract float %86, %89
  %91 = extractelement <4 x float> %78, i64 3
  %92 = extractelement <4 x float> %76, i64 3
  %93 = fmul contract float %91, %92
  %94 = fadd contract float %90, %93
  store float %94, ptr addrspace(5) %37, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %96

95:                                               ; preds = %59
  br label %96

96:                                               ; preds = %95, %61
  %97 = add i64 %38, 1024
  br label %98

98:                                               ; preds = %141, %96
  %99 = phi i64 [ %97, %96 ], [ %109, %141 ]
  %100 = phi i64 [ 0, %96 ], [ %110, %141 ]
  %101 = phi i64 [ %60, %96 ], [ %192, %141 ]
  %102 = add i64 %99, 1024
  %103 = icmp slt i64 %102, %99
  %104 = select i1 %103, i64 1, i64 0
  %105 = icmp sge i64 %99, %27
  %106 = icmp eq i64 %100, 0
  %107 = xor i1 %106, true
  %108 = or i1 %107, %105
  %109 = select i1 %108, i64 %99, i64 %102
  %110 = select i1 %108, i64 %100, i64 %104
  br i1 %108, label %111, label %141

111:                                              ; preds = %98
  %112 = udiv i64 %35, 32
  %113 = trunc i64 %112 to i32
  %114 = sext i32 %113 to i64
  %115 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %116 = sext i32 %115 to i64
  %117 = trunc i64 %114 to i32
  %118 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %117
  %119 = load float, ptr addrspace(5) %37, align 4
  %120 = bitcast float %119 to i32
  %121 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %120, i32 16, i32 31)
  %122 = bitcast i32 %121 to float
  %123 = fadd contract float %119, %122
  %124 = bitcast float %123 to i32
  %125 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %124, i32 8, i32 31)
  %126 = bitcast i32 %125 to float
  %127 = fadd contract float %123, %126
  %128 = bitcast float %127 to i32
  %129 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %128, i32 4, i32 31)
  %130 = bitcast i32 %129 to float
  %131 = fadd contract float %127, %130
  %132 = bitcast float %131 to i32
  %133 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %132, i32 2, i32 31)
  %134 = bitcast i32 %133 to float
  %135 = fadd contract float %131, %134
  %136 = bitcast float %135 to i32
  %137 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %136, i32 1, i32 31)
  %138 = bitcast i32 %137 to float
  %139 = fadd contract float %135, %138
  %140 = icmp eq i64 %116, 0
  br i1 %140, label %193, label %194

141:                                              ; preds = %98
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %31, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %101, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %142 = insertvalue [2 x ptr] undef, ptr %12, 0
  %143 = insertvalue [2 x ptr] %142, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %143, ptr %10, align 8
  %144 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %145 = load ptr, ptr %144, align 8
  %146 = load i64, ptr %145, align 8
  %147 = trunc i64 %146 to i32
  %148 = getelementptr inbounds ptr, ptr %144, i32 1
  %149 = load ptr, ptr %148, align 8
  %150 = load i64, ptr %149, align 8
  %151 = trunc i64 %150 to i32
  %152 = mul i32 %147, 6144
  %153 = mul i32 %151, 1024
  %154 = add i32 %152, %153
  %155 = sext i32 %154 to i64
  %156 = getelementptr inbounds float, ptr %26, i64 %155
  %157 = getelementptr inbounds float, ptr %156, i64 %34
  %158 = load <4 x float>, ptr %157, align 16, !invariant.load !1
  store <4 x float> %158, ptr addrspace(5) %36, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %29, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %101, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %159 = insertvalue [2 x ptr] undef, ptr %9, 0
  %160 = insertvalue [2 x ptr] %159, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %160, ptr %7, align 8
  %161 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = getelementptr inbounds ptr, ptr %161, i32 1
  %165 = load ptr, ptr %164, align 8
  %166 = load i64, ptr %165, align 8
  %167 = mul i64 %163, 6144
  %168 = mul i64 %166, 1024
  %169 = add i64 %167, %168
  %170 = getelementptr inbounds bfloat, ptr %25, i64 %169
  %171 = getelementptr inbounds bfloat, ptr %170, i64 %34
  %172 = load <4 x bfloat>, ptr %171, align 8, !invariant.load !1
  %173 = load <4 x float>, ptr addrspace(5) %36, align 16
  %174 = load float, ptr addrspace(5) %37, align 4
  %175 = fpext <4 x bfloat> %172 to <4 x float>
  %176 = extractelement <4 x float> %175, i64 0
  %177 = extractelement <4 x float> %173, i64 0
  %178 = fmul contract float %176, %177
  %179 = fadd contract float %174, %178
  %180 = extractelement <4 x float> %175, i64 1
  %181 = extractelement <4 x float> %173, i64 1
  %182 = fmul contract float %180, %181
  %183 = fadd contract float %179, %182
  %184 = extractelement <4 x float> %175, i64 2
  %185 = extractelement <4 x float> %173, i64 2
  %186 = fmul contract float %184, %185
  %187 = fadd contract float %183, %186
  %188 = extractelement <4 x float> %175, i64 3
  %189 = extractelement <4 x float> %173, i64 3
  %190 = fmul contract float %188, %189
  %191 = fadd contract float %187, %190
  store float %191, ptr addrspace(5) %37, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %192 = add i64 %101, 1
  br label %98

193:                                              ; preds = %111
  store float %139, ptr addrspace(3) %118, align 4
  br label %195

194:                                              ; preds = %111
  br label %195

195:                                              ; preds = %194, %193
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %196

196:                                              ; preds = %209, %195
  %197 = phi i64 [ %35, %195 ], [ %206, %209 ]
  %198 = phi i64 [ 0, %195 ], [ %207, %209 ]
  %199 = add i64 %197, 256
  %200 = icmp slt i64 %199, %197
  %201 = select i1 %200, i64 1, i64 0
  %202 = icmp sge i64 %197, 1
  %203 = icmp eq i64 %198, 0
  %204 = xor i1 %203, true
  %205 = or i1 %204, %202
  %206 = select i1 %205, i64 %197, i64 %199
  %207 = select i1 %205, i64 %198, i64 %201
  br i1 %205, label %208, label %209

208:                                              ; preds = %196
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %19)
  ret void

209:                                              ; preds = %196
  %210 = trunc i64 %197 to i32
  %211 = sext i32 %210 to i64
  %212 = trunc i64 %211 to i32
  %213 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %212
  %214 = load float, ptr addrspace(3) %213, align 4
  %215 = fadd contract float %214, 0.000000e+00
  %216 = add i64 %197, 1
  %217 = trunc i64 %216 to i32
  %218 = sext i32 %217 to i64
  %219 = trunc i64 %218 to i32
  %220 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %219
  %221 = load float, ptr addrspace(3) %220, align 4
  %222 = fadd contract float %215, %221
  %223 = add i64 %197, 2
  %224 = trunc i64 %223 to i32
  %225 = sext i32 %224 to i64
  %226 = trunc i64 %225 to i32
  %227 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %226
  %228 = load float, ptr addrspace(3) %227, align 4
  %229 = fadd contract float %222, %228
  %230 = add i64 %197, 3
  %231 = trunc i64 %230 to i32
  %232 = sext i32 %231 to i64
  %233 = trunc i64 %232 to i32
  %234 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %233
  %235 = load float, ptr addrspace(3) %234, align 4
  %236 = fadd contract float %229, %235
  %237 = add i64 %197, 4
  %238 = trunc i64 %237 to i32
  %239 = sext i32 %238 to i64
  %240 = trunc i64 %239 to i32
  %241 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %240
  %242 = load float, ptr addrspace(3) %241, align 4
  %243 = fadd contract float %236, %242
  %244 = add i64 %197, 5
  %245 = trunc i64 %244 to i32
  %246 = sext i32 %245 to i64
  %247 = trunc i64 %246 to i32
  %248 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %247
  %249 = load float, ptr addrspace(3) %248, align 4
  %250 = fadd contract float %243, %249
  %251 = add i64 %197, 6
  %252 = trunc i64 %251 to i32
  %253 = sext i32 %252 to i64
  %254 = trunc i64 %253 to i32
  %255 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %254
  %256 = load float, ptr addrspace(3) %255, align 4
  %257 = fadd contract float %250, %256
  %258 = add i64 %197, 7
  %259 = trunc i64 %258 to i32
  %260 = sext i32 %259 to i64
  %261 = trunc i64 %260 to i32
  %262 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_float32_bfloat16_float32_256_03d0bed6._global_alloc_0._gpu_shared_mem, i32 %261
  %263 = load float, ptr addrspace(3) %262, align 4
  %264 = fadd contract float %257, %263
  %265 = add i64 %29, %197
  %266 = mul i64 %265, 128
  %267 = add i64 %266, %31
  %268 = getelementptr inbounds float, ptr %24, i64 %267
  store float %264, ptr %268, align 4
  br label %196
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
attributes #1 = { convergent norecurse "nvvm.maxntid"="256" "target-cpu"="sm_100a" "target-features"="+ptx88,+sm_100a" "tune-cpu"="sm_100a" }
attributes #2 = { nounwind }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #6 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
