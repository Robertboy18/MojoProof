; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x float] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %20 = alloca [8 x bfloat], align 16
  %21 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %22 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %23 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %24 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %23, 0
  %25 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %22, 0
  %26 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %21, 0
  %27 = sext i32 %5 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %29 = zext i32 %28 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %31 = zext i32 %30 to i64
  %32 = trunc i64 %31 to i32
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %34 = mul i32 %33, 8
  %35 = sext i32 %34 to i64
  %36 = zext i32 %33 to i64
  call void @llvm.lifetime.start.p0(ptr %20)
  %37 = addrspacecast ptr %20 to ptr addrspace(5)
  call void @llvm.lifetime.start.p0(ptr %19)
  %38 = addrspacecast ptr %19 to ptr addrspace(5)
  store float 0.000000e+00, ptr addrspace(5) %38, align 4
  %39 = mul i64 %36, 8
  %40 = icmp slt i64 %39, %27
  br i1 %40, label %41, label %58

41:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %31, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %42 = insertvalue [2 x ptr] undef, ptr %18, 0
  %43 = insertvalue [2 x ptr] %42, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %43, ptr %16, align 8
  %44 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %45 = load ptr, ptr %44, align 8
  %46 = load i64, ptr %45, align 8
  %47 = trunc i64 %46 to i32
  %48 = getelementptr inbounds ptr, ptr %44, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = load i64, ptr %49, align 8
  %51 = trunc i64 %50 to i32
  %52 = mul i32 %51, 1024
  %53 = add i32 %47, %52
  %54 = sext i32 %53 to i64
  %55 = getelementptr inbounds bfloat, ptr %26, i64 %54
  %56 = getelementptr inbounds bfloat, ptr %55, i64 %35
  %57 = load <8 x bfloat>, ptr %56, align 16, !invariant.load !1
  store <8 x bfloat> %57, ptr addrspace(5) %37, align 16
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %59

58:                                               ; preds = %6
  br label %59

59:                                               ; preds = %58, %41
  %60 = select i1 %40, i64 1, i64 0
  br i1 %40, label %61, label %115

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
  %67 = trunc i64 %66 to i32
  %68 = getelementptr inbounds ptr, ptr %64, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = load i64, ptr %69, align 8
  %71 = trunc i64 %70 to i32
  %72 = mul i32 %67, 1024
  %73 = mul i32 %71, 1024
  %74 = add i32 %72, %73
  %75 = sext i32 %74 to i64
  %76 = getelementptr inbounds bfloat, ptr %25, i64 %75
  %77 = getelementptr inbounds bfloat, ptr %76, i64 %35
  %78 = load <8 x bfloat>, ptr %77, align 16, !invariant.load !1
  %79 = load <8 x bfloat>, ptr addrspace(5) %37, align 16
  %80 = load float, ptr addrspace(5) %38, align 4
  %81 = fpext <8 x bfloat> %78 to <8 x float>
  %82 = fpext <8 x bfloat> %79 to <8 x float>
  %83 = extractelement <8 x float> %81, i64 0
  %84 = extractelement <8 x float> %82, i64 0
  %85 = fmul contract float %83, %84
  %86 = fadd contract float %80, %85
  %87 = extractelement <8 x float> %81, i64 1
  %88 = extractelement <8 x float> %82, i64 1
  %89 = fmul contract float %87, %88
  %90 = fadd contract float %86, %89
  %91 = extractelement <8 x float> %81, i64 2
  %92 = extractelement <8 x float> %82, i64 2
  %93 = fmul contract float %91, %92
  %94 = fadd contract float %90, %93
  %95 = extractelement <8 x float> %81, i64 3
  %96 = extractelement <8 x float> %82, i64 3
  %97 = fmul contract float %95, %96
  %98 = fadd contract float %94, %97
  %99 = extractelement <8 x float> %81, i64 4
  %100 = extractelement <8 x float> %82, i64 4
  %101 = fmul contract float %99, %100
  %102 = fadd contract float %98, %101
  %103 = extractelement <8 x float> %81, i64 5
  %104 = extractelement <8 x float> %82, i64 5
  %105 = fmul contract float %103, %104
  %106 = fadd contract float %102, %105
  %107 = extractelement <8 x float> %81, i64 6
  %108 = extractelement <8 x float> %82, i64 6
  %109 = fmul contract float %107, %108
  %110 = fadd contract float %106, %109
  %111 = extractelement <8 x float> %81, i64 7
  %112 = extractelement <8 x float> %82, i64 7
  %113 = fmul contract float %111, %112
  %114 = fadd contract float %110, %113
  store float %114, ptr addrspace(5) %38, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %116

115:                                              ; preds = %59
  br label %116

116:                                              ; preds = %115, %61
  %117 = add i64 %39, 1024
  br label %118

118:                                              ; preds = %161, %116
  %119 = phi i64 [ %117, %116 ], [ %129, %161 ]
  %120 = phi i64 [ 0, %116 ], [ %130, %161 ]
  %121 = phi i64 [ %60, %116 ], [ %231, %161 ]
  %122 = add i64 %119, 1024
  %123 = icmp slt i64 %122, %119
  %124 = select i1 %123, i64 1, i64 0
  %125 = icmp sge i64 %119, %27
  %126 = icmp eq i64 %120, 0
  %127 = xor i1 %126, true
  %128 = or i1 %127, %125
  %129 = select i1 %128, i64 %119, i64 %122
  %130 = select i1 %128, i64 %120, i64 %124
  br i1 %128, label %131, label %161

131:                                              ; preds = %118
  %132 = udiv i64 %36, 32
  %133 = trunc i64 %132 to i32
  %134 = sext i32 %133 to i64
  %135 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %136 = sext i32 %135 to i64
  %137 = trunc i64 %134 to i32
  %138 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a._global_alloc_0._gpu_shared_mem, i32 %137
  %139 = load float, ptr addrspace(5) %38, align 4
  %140 = bitcast float %139 to i32
  %141 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %140, i32 16, i32 31)
  %142 = bitcast i32 %141 to float
  %143 = fadd contract float %139, %142
  %144 = bitcast float %143 to i32
  %145 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %144, i32 8, i32 31)
  %146 = bitcast i32 %145 to float
  %147 = fadd contract float %143, %146
  %148 = bitcast float %147 to i32
  %149 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %148, i32 4, i32 31)
  %150 = bitcast i32 %149 to float
  %151 = fadd contract float %147, %150
  %152 = bitcast float %151 to i32
  %153 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %152, i32 2, i32 31)
  %154 = bitcast i32 %153 to float
  %155 = fadd contract float %151, %154
  %156 = bitcast float %155 to i32
  %157 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %156, i32 1, i32 31)
  %158 = bitcast i32 %157 to float
  %159 = fadd contract float %155, %158
  %160 = icmp eq i64 %136, 0
  br i1 %160, label %232, label %233

161:                                              ; preds = %118
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %31, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %121, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %162 = insertvalue [2 x ptr] undef, ptr %12, 0
  %163 = insertvalue [2 x ptr] %162, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %163, ptr %10, align 8
  %164 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %165 = load ptr, ptr %164, align 8
  %166 = load i64, ptr %165, align 8
  %167 = trunc i64 %166 to i32
  %168 = getelementptr inbounds ptr, ptr %164, i32 1
  %169 = load ptr, ptr %168, align 8
  %170 = load i64, ptr %169, align 8
  %171 = trunc i64 %170 to i32
  %172 = mul i32 %171, 1024
  %173 = add i32 %167, %172
  %174 = sext i32 %173 to i64
  %175 = getelementptr inbounds bfloat, ptr %26, i64 %174
  %176 = getelementptr inbounds bfloat, ptr %175, i64 %35
  %177 = load <8 x bfloat>, ptr %176, align 16, !invariant.load !1
  store <8 x bfloat> %177, ptr addrspace(5) %37, align 16
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %29, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %121, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %178 = insertvalue [2 x ptr] undef, ptr %9, 0
  %179 = insertvalue [2 x ptr] %178, ptr %8, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %179, ptr %7, align 8
  %180 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %181 = load ptr, ptr %180, align 8
  %182 = load i64, ptr %181, align 8
  %183 = trunc i64 %182 to i32
  %184 = getelementptr inbounds ptr, ptr %180, i32 1
  %185 = load ptr, ptr %184, align 8
  %186 = load i64, ptr %185, align 8
  %187 = trunc i64 %186 to i32
  %188 = mul i32 %183, 1024
  %189 = mul i32 %187, 1024
  %190 = add i32 %188, %189
  %191 = sext i32 %190 to i64
  %192 = getelementptr inbounds bfloat, ptr %25, i64 %191
  %193 = getelementptr inbounds bfloat, ptr %192, i64 %35
  %194 = load <8 x bfloat>, ptr %193, align 16, !invariant.load !1
  %195 = load <8 x bfloat>, ptr addrspace(5) %37, align 16
  %196 = load float, ptr addrspace(5) %38, align 4
  %197 = fpext <8 x bfloat> %194 to <8 x float>
  %198 = fpext <8 x bfloat> %195 to <8 x float>
  %199 = extractelement <8 x float> %197, i64 0
  %200 = extractelement <8 x float> %198, i64 0
  %201 = fmul contract float %199, %200
  %202 = fadd contract float %196, %201
  %203 = extractelement <8 x float> %197, i64 1
  %204 = extractelement <8 x float> %198, i64 1
  %205 = fmul contract float %203, %204
  %206 = fadd contract float %202, %205
  %207 = extractelement <8 x float> %197, i64 2
  %208 = extractelement <8 x float> %198, i64 2
  %209 = fmul contract float %207, %208
  %210 = fadd contract float %206, %209
  %211 = extractelement <8 x float> %197, i64 3
  %212 = extractelement <8 x float> %198, i64 3
  %213 = fmul contract float %211, %212
  %214 = fadd contract float %210, %213
  %215 = extractelement <8 x float> %197, i64 4
  %216 = extractelement <8 x float> %198, i64 4
  %217 = fmul contract float %215, %216
  %218 = fadd contract float %214, %217
  %219 = extractelement <8 x float> %197, i64 5
  %220 = extractelement <8 x float> %198, i64 5
  %221 = fmul contract float %219, %220
  %222 = fadd contract float %218, %221
  %223 = extractelement <8 x float> %197, i64 6
  %224 = extractelement <8 x float> %198, i64 6
  %225 = fmul contract float %223, %224
  %226 = fadd contract float %222, %225
  %227 = extractelement <8 x float> %197, i64 7
  %228 = extractelement <8 x float> %198, i64 7
  %229 = fmul contract float %227, %228
  %230 = fadd contract float %226, %229
  store float %230, ptr addrspace(5) %38, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %231 = add i64 %121, 1
  br label %118

232:                                              ; preds = %131
  store float %159, ptr addrspace(3) %138, align 4
  br label %234

233:                                              ; preds = %131
  br label %234

234:                                              ; preds = %233, %232
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  br label %235

235:                                              ; preds = %248, %234
  %236 = phi i64 [ %36, %234 ], [ %245, %248 ]
  %237 = phi i64 [ 0, %234 ], [ %246, %248 ]
  %238 = add i64 %236, 128
  %239 = icmp slt i64 %238, %236
  %240 = select i1 %239, i64 1, i64 0
  %241 = icmp sge i64 %236, 1
  %242 = icmp eq i64 %237, 0
  %243 = xor i1 %242, true
  %244 = or i1 %243, %241
  %245 = select i1 %244, i64 %236, i64 %238
  %246 = select i1 %244, i64 %237, i64 %240
  br i1 %244, label %247, label %248

247:                                              ; preds = %235
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %19)
  ret void

248:                                              ; preds = %235
  %249 = trunc i64 %236 to i32
  %250 = sext i32 %249 to i64
  %251 = trunc i64 %250 to i32
  %252 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a._global_alloc_0._gpu_shared_mem, i32 %251
  %253 = load float, ptr addrspace(3) %252, align 4
  %254 = fadd contract float %253, 0.000000e+00
  %255 = add i64 %236, 1
  %256 = trunc i64 %255 to i32
  %257 = sext i32 %256 to i64
  %258 = trunc i64 %257 to i32
  %259 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a._global_alloc_0._gpu_shared_mem, i32 %258
  %260 = load float, ptr addrspace(3) %259, align 4
  %261 = fadd contract float %254, %260
  %262 = add i64 %236, 2
  %263 = trunc i64 %262 to i32
  %264 = sext i32 %263 to i64
  %265 = trunc i64 %264 to i32
  %266 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a._global_alloc_0._gpu_shared_mem, i32 %265
  %267 = load float, ptr addrspace(3) %266, align 4
  %268 = fadd contract float %261, %267
  %269 = add i64 %236, 3
  %270 = trunc i64 %269 to i32
  %271 = sext i32 %270 to i64
  %272 = trunc i64 %271 to i32
  %273 = getelementptr inbounds float, ptr addrspace(3) @gemv_split_k_bfloat16_bfloat16_bfloat16_128_383ebf6a._global_alloc_0._gpu_shared_mem, i32 %272
  %274 = load float, ptr addrspace(3) %273, align 4
  %275 = fadd contract float %268, %274
  %276 = add i64 %29, %236
  %277 = fptrunc float %275 to bfloat
  %278 = trunc i64 %276 to i32
  %279 = add i32 %278, %32
  %280 = sext i32 %279 to i64
  %281 = getelementptr inbounds bfloat, ptr %24, i64 %280
  store bfloat %277, ptr %281, align 2
  br label %235
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
