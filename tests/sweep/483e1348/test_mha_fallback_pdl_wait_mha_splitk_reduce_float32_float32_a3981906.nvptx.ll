; ModuleID = 'test_mha_fallback_pdl_wait.mojo'
source_filename = "test_mha_fallback_pdl_wait.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@mha_splitk_reduce_float32_float32_a3981906.exp_sums_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [32 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @mha_splitk_reduce_float32_float32_a3981906(ptr noundef %0, ptr noundef %1, ptr noundef %2, ptr noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = sext i32 %4 to i64
  %8 = sext i32 %5 to i64
  %9 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %10 = zext i32 %9 to i64
  %11 = mul i64 %10, 1024
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %13 = zext i32 %12 to i64
  %14 = mul i64 %13, 128
  %15 = add i64 %11, %14
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %17 = zext i32 %16 to i64
  %18 = trunc i64 %17 to i32
  %19 = sext i32 %18 to i64
  %20 = mul i64 %10, 8
  %21 = mul i64 %7, 8
  %22 = mul i64 %21, %17
  %23 = add i64 %20, %22
  %24 = add i64 %23, %13
  %25 = getelementptr inbounds float, ptr %2, i64 %24
  %26 = getelementptr inbounds float, ptr %3, i64 %24
  %27 = icmp slt i64 %17, %8
  br i1 %27, label %28, label %30

28:                                               ; preds = %6
  %29 = load float, ptr %26, align 4
  br label %31

30:                                               ; preds = %6
  br label %31

31:                                               ; preds = %30, %28
  %32 = phi float [ -inf, %30 ], [ %29, %28 ]
  %33 = bitcast float %32 to i32
  %34 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %33, i32 16, i32 31)
  %35 = bitcast i32 %34 to float
  %36 = call float @llvm.maxnum.f32(float %32, float %35)
  %37 = bitcast float %36 to i32
  %38 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %37, i32 8, i32 31)
  %39 = bitcast i32 %38 to float
  %40 = call float @llvm.maxnum.f32(float %36, float %39)
  %41 = bitcast float %40 to i32
  %42 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %41, i32 4, i32 31)
  %43 = bitcast i32 %42 to float
  %44 = call float @llvm.maxnum.f32(float %40, float %43)
  %45 = bitcast float %44 to i32
  %46 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %45, i32 2, i32 31)
  %47 = bitcast i32 %46 to float
  %48 = call float @llvm.maxnum.f32(float %44, float %47)
  %49 = bitcast float %48 to i32
  %50 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %49, i32 1, i32 31)
  %51 = bitcast i32 %50 to float
  %52 = call float @llvm.maxnum.f32(float %48, float %51)
  %53 = fsub contract float %32, %52
  %54 = fmul contract float %53, f0x3FB8AA3B
  %55 = trunc i64 %19 to i32
  %56 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_float32_float32_a3981906.exp_sums_storage_0._gpu_shared_mem, i32 %55
  %57 = mul i64 %7, 1024
  br i1 %27, label %58, label %62

58:                                               ; preds = %31
  %59 = call float asm "ex2.approx.ftz.f32 $0, $1;", "=f,f"(float %54)
  %60 = load float, ptr %25, align 4
  %61 = fmul contract float %60, %59
  store float %61, ptr addrspace(3) %56, align 4
  br label %63

62:                                               ; preds = %31
  br label %63

63:                                               ; preds = %62, %58
  %64 = phi float [ 0.000000e+00, %62 ], [ %61, %58 ]
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %65 = bitcast float %64 to i32
  %66 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %65, i32 16, i32 31)
  %67 = bitcast i32 %66 to float
  %68 = fadd contract float %64, %67
  %69 = bitcast float %68 to i32
  %70 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %69, i32 8, i32 31)
  %71 = bitcast i32 %70 to float
  %72 = fadd contract float %68, %71
  %73 = bitcast float %72 to i32
  %74 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %73, i32 4, i32 31)
  %75 = bitcast i32 %74 to float
  %76 = fadd contract float %72, %75
  %77 = bitcast float %76 to i32
  %78 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %77, i32 2, i32 31)
  %79 = bitcast i32 %78 to float
  %80 = fadd contract float %76, %79
  %81 = bitcast float %80 to i32
  %82 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %81, i32 1, i32 31)
  %83 = bitcast i32 %82 to float
  %84 = fadd contract float %80, %83
  %85 = fdiv float 1.000000e+00, %84
  %86 = insertelement <4 x float> undef, float %85, i32 0
  %87 = shufflevector <4 x float> %86, <4 x float> undef, <4 x i32> zeroinitializer
  %88 = mul i64 %17, 4
  %89 = add i64 %15, %88
  %90 = getelementptr inbounds float, ptr %1, i64 %89
  %91 = icmp slt i64 %88, 128
  br i1 %91, label %92, label %316

92:                                               ; preds = %63
  %93 = udiv i64 %8, 8
  %94 = mul i64 %93, 8
  br label %95

95:                                               ; preds = %111, %92
  %96 = phi i64 [ 0, %92 ], [ %107, %111 ]
  %97 = phi i64 [ 0, %92 ], [ %108, %111 ]
  %98 = phi <4 x float> [ zeroinitializer, %92 ], [ %273, %111 ]
  %99 = phi <4 x float> [ zeroinitializer, %92 ], [ %275, %111 ]
  %100 = add i64 %96, 8
  %101 = icmp slt i64 %100, %96
  %102 = select i1 %101, i64 1, i64 0
  %103 = icmp sge i64 %96, %94
  %104 = icmp eq i64 %97, 0
  %105 = xor i1 %104, true
  %106 = or i1 %105, %103
  %107 = select i1 %106, i64 %96, i64 %100
  %108 = select i1 %106, i64 %97, i64 %102
  br i1 %106, label %109, label %111

109:                                              ; preds = %95
  %110 = call i64 @llvm.smax.i64(i64 %94, i64 %8)
  br label %276

111:                                              ; preds = %95
  %112 = sdiv i64 %96, 8
  %113 = mul i64 %112, 8
  %114 = icmp eq i64 %113, %96
  %115 = xor i64 %96, 8
  %116 = ashr i64 %115, 63
  %117 = select i1 %114, i64 0, i64 %116
  %118 = add i64 %112, %117
  %119 = trunc i64 %118 to i32
  %120 = mul i32 %119, 8
  %121 = sext i32 %120 to i64
  %122 = trunc i64 %121 to i32
  %123 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_float32_float32_a3981906.exp_sums_storage_0._gpu_shared_mem, i32 %122
  %124 = load <8 x float>, ptr addrspace(3) %123, align 32
  %125 = mul i64 %96, %57
  %126 = add i64 %125, %11
  %127 = add i64 %126, %14
  %128 = add i64 %127, %88
  %129 = getelementptr inbounds float, ptr %0, i64 %128
  %130 = load <4 x float>, ptr %129, align 16, !invariant.load !1
  %131 = extractelement <8 x float> %124, i64 0
  %132 = fcmp ogt float %131, 0.000000e+00
  %133 = insertelement <4 x i1> undef, i1 %132, i32 0
  %134 = shufflevector <4 x i1> %133, <4 x i1> undef, <4 x i32> zeroinitializer
  %135 = select <4 x i1> %134, <4 x float> %130, <4 x float> zeroinitializer
  %136 = insertelement <4 x float> undef, float %131, i32 0
  %137 = shufflevector <4 x float> %136, <4 x float> undef, <4 x i32> zeroinitializer
  %138 = fmul contract <4 x float> %135, %137
  %139 = fsub contract <4 x float> %138, %99
  %140 = fadd contract <4 x float> %98, %139
  %141 = fsub contract <4 x float> %140, %98
  %142 = fsub contract <4 x float> %141, %139
  %143 = add i64 %96, 1
  %144 = mul i64 %143, %57
  %145 = add i64 %144, %11
  %146 = add i64 %145, %14
  %147 = add i64 %146, %88
  %148 = getelementptr inbounds float, ptr %0, i64 %147
  %149 = load <4 x float>, ptr %148, align 16, !invariant.load !1
  %150 = extractelement <8 x float> %124, i64 1
  %151 = fcmp ogt float %150, 0.000000e+00
  %152 = insertelement <4 x i1> undef, i1 %151, i32 0
  %153 = shufflevector <4 x i1> %152, <4 x i1> undef, <4 x i32> zeroinitializer
  %154 = select <4 x i1> %153, <4 x float> %149, <4 x float> zeroinitializer
  %155 = insertelement <4 x float> undef, float %150, i32 0
  %156 = shufflevector <4 x float> %155, <4 x float> undef, <4 x i32> zeroinitializer
  %157 = fmul contract <4 x float> %154, %156
  %158 = fsub contract <4 x float> %157, %142
  %159 = fadd contract <4 x float> %140, %158
  %160 = fsub contract <4 x float> %159, %140
  %161 = fsub contract <4 x float> %160, %158
  %162 = add i64 %96, 2
  %163 = mul i64 %162, %57
  %164 = add i64 %163, %11
  %165 = add i64 %164, %14
  %166 = add i64 %165, %88
  %167 = getelementptr inbounds float, ptr %0, i64 %166
  %168 = load <4 x float>, ptr %167, align 16, !invariant.load !1
  %169 = extractelement <8 x float> %124, i64 2
  %170 = fcmp ogt float %169, 0.000000e+00
  %171 = insertelement <4 x i1> undef, i1 %170, i32 0
  %172 = shufflevector <4 x i1> %171, <4 x i1> undef, <4 x i32> zeroinitializer
  %173 = select <4 x i1> %172, <4 x float> %168, <4 x float> zeroinitializer
  %174 = insertelement <4 x float> undef, float %169, i32 0
  %175 = shufflevector <4 x float> %174, <4 x float> undef, <4 x i32> zeroinitializer
  %176 = fmul contract <4 x float> %173, %175
  %177 = fsub contract <4 x float> %176, %161
  %178 = fadd contract <4 x float> %159, %177
  %179 = fsub contract <4 x float> %178, %159
  %180 = fsub contract <4 x float> %179, %177
  %181 = add i64 %96, 3
  %182 = mul i64 %181, %57
  %183 = add i64 %182, %11
  %184 = add i64 %183, %14
  %185 = add i64 %184, %88
  %186 = getelementptr inbounds float, ptr %0, i64 %185
  %187 = load <4 x float>, ptr %186, align 16, !invariant.load !1
  %188 = extractelement <8 x float> %124, i64 3
  %189 = fcmp ogt float %188, 0.000000e+00
  %190 = insertelement <4 x i1> undef, i1 %189, i32 0
  %191 = shufflevector <4 x i1> %190, <4 x i1> undef, <4 x i32> zeroinitializer
  %192 = select <4 x i1> %191, <4 x float> %187, <4 x float> zeroinitializer
  %193 = insertelement <4 x float> undef, float %188, i32 0
  %194 = shufflevector <4 x float> %193, <4 x float> undef, <4 x i32> zeroinitializer
  %195 = fmul contract <4 x float> %192, %194
  %196 = fsub contract <4 x float> %195, %180
  %197 = fadd contract <4 x float> %178, %196
  %198 = fsub contract <4 x float> %197, %178
  %199 = fsub contract <4 x float> %198, %196
  %200 = add i64 %96, 4
  %201 = mul i64 %200, %57
  %202 = add i64 %201, %11
  %203 = add i64 %202, %14
  %204 = add i64 %203, %88
  %205 = getelementptr inbounds float, ptr %0, i64 %204
  %206 = load <4 x float>, ptr %205, align 16, !invariant.load !1
  %207 = extractelement <8 x float> %124, i64 4
  %208 = fcmp ogt float %207, 0.000000e+00
  %209 = insertelement <4 x i1> undef, i1 %208, i32 0
  %210 = shufflevector <4 x i1> %209, <4 x i1> undef, <4 x i32> zeroinitializer
  %211 = select <4 x i1> %210, <4 x float> %206, <4 x float> zeroinitializer
  %212 = insertelement <4 x float> undef, float %207, i32 0
  %213 = shufflevector <4 x float> %212, <4 x float> undef, <4 x i32> zeroinitializer
  %214 = fmul contract <4 x float> %211, %213
  %215 = fsub contract <4 x float> %214, %199
  %216 = fadd contract <4 x float> %197, %215
  %217 = fsub contract <4 x float> %216, %197
  %218 = fsub contract <4 x float> %217, %215
  %219 = add i64 %96, 5
  %220 = mul i64 %219, %57
  %221 = add i64 %220, %11
  %222 = add i64 %221, %14
  %223 = add i64 %222, %88
  %224 = getelementptr inbounds float, ptr %0, i64 %223
  %225 = load <4 x float>, ptr %224, align 16, !invariant.load !1
  %226 = extractelement <8 x float> %124, i64 5
  %227 = fcmp ogt float %226, 0.000000e+00
  %228 = insertelement <4 x i1> undef, i1 %227, i32 0
  %229 = shufflevector <4 x i1> %228, <4 x i1> undef, <4 x i32> zeroinitializer
  %230 = select <4 x i1> %229, <4 x float> %225, <4 x float> zeroinitializer
  %231 = insertelement <4 x float> undef, float %226, i32 0
  %232 = shufflevector <4 x float> %231, <4 x float> undef, <4 x i32> zeroinitializer
  %233 = fmul contract <4 x float> %230, %232
  %234 = fsub contract <4 x float> %233, %218
  %235 = fadd contract <4 x float> %216, %234
  %236 = fsub contract <4 x float> %235, %216
  %237 = fsub contract <4 x float> %236, %234
  %238 = add i64 %96, 6
  %239 = mul i64 %238, %57
  %240 = add i64 %239, %11
  %241 = add i64 %240, %14
  %242 = add i64 %241, %88
  %243 = getelementptr inbounds float, ptr %0, i64 %242
  %244 = load <4 x float>, ptr %243, align 16, !invariant.load !1
  %245 = extractelement <8 x float> %124, i64 6
  %246 = fcmp ogt float %245, 0.000000e+00
  %247 = insertelement <4 x i1> undef, i1 %246, i32 0
  %248 = shufflevector <4 x i1> %247, <4 x i1> undef, <4 x i32> zeroinitializer
  %249 = select <4 x i1> %248, <4 x float> %244, <4 x float> zeroinitializer
  %250 = insertelement <4 x float> undef, float %245, i32 0
  %251 = shufflevector <4 x float> %250, <4 x float> undef, <4 x i32> zeroinitializer
  %252 = fmul contract <4 x float> %249, %251
  %253 = fsub contract <4 x float> %252, %237
  %254 = fadd contract <4 x float> %235, %253
  %255 = fsub contract <4 x float> %254, %235
  %256 = fsub contract <4 x float> %255, %253
  %257 = add i64 %96, 7
  %258 = mul i64 %257, %57
  %259 = add i64 %258, %11
  %260 = add i64 %259, %14
  %261 = add i64 %260, %88
  %262 = getelementptr inbounds float, ptr %0, i64 %261
  %263 = load <4 x float>, ptr %262, align 16, !invariant.load !1
  %264 = extractelement <8 x float> %124, i64 7
  %265 = fcmp ogt float %264, 0.000000e+00
  %266 = insertelement <4 x i1> undef, i1 %265, i32 0
  %267 = shufflevector <4 x i1> %266, <4 x i1> undef, <4 x i32> zeroinitializer
  %268 = select <4 x i1> %267, <4 x float> %263, <4 x float> zeroinitializer
  %269 = insertelement <4 x float> undef, float %264, i32 0
  %270 = shufflevector <4 x float> %269, <4 x float> undef, <4 x i32> zeroinitializer
  %271 = fmul contract <4 x float> %268, %270
  %272 = fsub contract <4 x float> %271, %256
  %273 = fadd contract <4 x float> %254, %272
  %274 = fsub contract <4 x float> %273, %254
  %275 = fsub contract <4 x float> %274, %272
  br label %95

276:                                              ; preds = %281, %109
  %277 = phi i64 [ %94, %109 ], [ %284, %281 ]
  %278 = phi <4 x float> [ %98, %109 ], [ %311, %281 ]
  %279 = phi <4 x float> [ %99, %109 ], [ %313, %281 ]
  %280 = icmp slt i64 %277, %110
  br i1 %280, label %281, label %314

281:                                              ; preds = %276
  %282 = icmp eq i64 %277, %110
  %283 = add i64 %277, 1
  %284 = select i1 %282, i64 %277, i64 %283
  %285 = sdiv i64 %277, 1
  %286 = mul i64 %285, 1
  %287 = icmp eq i64 %286, %277
  %288 = xor i64 %277, 1
  %289 = ashr i64 %288, 63
  %290 = select i1 %287, i64 0, i64 %289
  %291 = add i64 %285, %290
  %292 = trunc i64 %291 to i32
  %293 = sext i32 %292 to i64
  %294 = trunc i64 %293 to i32
  %295 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_float32_float32_a3981906.exp_sums_storage_0._gpu_shared_mem, i32 %294
  %296 = load float, ptr addrspace(3) %295, align 4
  %297 = mul i64 %277, %57
  %298 = add i64 %297, %11
  %299 = add i64 %298, %14
  %300 = add i64 %299, %88
  %301 = getelementptr inbounds float, ptr %0, i64 %300
  %302 = load <4 x float>, ptr %301, align 16, !invariant.load !1
  %303 = fcmp ogt float %296, 0.000000e+00
  %304 = insertelement <4 x i1> undef, i1 %303, i32 0
  %305 = shufflevector <4 x i1> %304, <4 x i1> undef, <4 x i32> zeroinitializer
  %306 = select <4 x i1> %305, <4 x float> %302, <4 x float> zeroinitializer
  %307 = insertelement <4 x float> undef, float %296, i32 0
  %308 = shufflevector <4 x float> %307, <4 x float> undef, <4 x i32> zeroinitializer
  %309 = fmul contract <4 x float> %306, %308
  %310 = fsub contract <4 x float> %309, %279
  %311 = fadd contract <4 x float> %278, %310
  %312 = fsub contract <4 x float> %311, %278
  %313 = fsub contract <4 x float> %312, %310
  br label %276

314:                                              ; preds = %276
  %315 = fmul contract <4 x float> %278, %87
  store <4 x float> %315, ptr %90, align 16
  br label %317

316:                                              ; preds = %63
  br label %317

317:                                              ; preds = %316, %314
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.z() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #3

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #4

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #3

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
