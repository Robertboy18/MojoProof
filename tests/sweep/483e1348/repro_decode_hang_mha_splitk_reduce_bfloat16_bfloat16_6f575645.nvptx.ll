; ModuleID = 'repro_decode_hang.mojo'
source_filename = "repro_decode_hang.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@mha_splitk_reduce_bfloat16_bfloat16_6f575645.exp_sums_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [32 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @mha_splitk_reduce_bfloat16_bfloat16_6f575645(ptr noundef %0, ptr noundef %1, ptr noundef %2, ptr noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = sext i32 %4 to i64
  %8 = sext i32 %5 to i64
  %9 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %10 = zext i32 %9 to i64
  %11 = mul i64 %10, 4096
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %13 = zext i32 %12 to i64
  %14 = mul i64 %13, 128
  %15 = add i64 %11, %14
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %17 = zext i32 %16 to i64
  %18 = trunc i64 %17 to i32
  %19 = sext i32 %18 to i64
  %20 = mul i64 %10, 32
  %21 = mul i64 %7, 32
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
  %56 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_bfloat16_bfloat16_6f575645.exp_sums_storage_0._gpu_shared_mem, i32 %55
  %57 = mul i64 %7, 4096
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
  %90 = getelementptr inbounds bfloat, ptr %1, i64 %89
  %91 = icmp slt i64 %88, 128
  br i1 %91, label %92, label %326

92:                                               ; preds = %63
  %93 = udiv i64 %8, 8
  %94 = mul i64 %93, 8
  br label %95

95:                                               ; preds = %111, %92
  %96 = phi i64 [ 0, %92 ], [ %107, %111 ]
  %97 = phi i64 [ 0, %92 ], [ %108, %111 ]
  %98 = phi <4 x float> [ zeroinitializer, %92 ], [ %281, %111 ]
  %99 = phi <4 x float> [ zeroinitializer, %92 ], [ %283, %111 ]
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
  br label %284

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
  %123 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_bfloat16_bfloat16_6f575645.exp_sums_storage_0._gpu_shared_mem, i32 %122
  %124 = load <8 x float>, ptr addrspace(3) %123, align 32
  %125 = mul i64 %96, %57
  %126 = add i64 %125, %11
  %127 = add i64 %126, %14
  %128 = add i64 %127, %88
  %129 = getelementptr inbounds bfloat, ptr %0, i64 %128
  %130 = load <4 x bfloat>, ptr %129, align 8, !invariant.load !1
  %131 = fpext <4 x bfloat> %130 to <4 x float>
  %132 = extractelement <8 x float> %124, i64 0
  %133 = fcmp ogt float %132, 0.000000e+00
  %134 = insertelement <4 x i1> undef, i1 %133, i32 0
  %135 = shufflevector <4 x i1> %134, <4 x i1> undef, <4 x i32> zeroinitializer
  %136 = select <4 x i1> %135, <4 x float> %131, <4 x float> zeroinitializer
  %137 = insertelement <4 x float> undef, float %132, i32 0
  %138 = shufflevector <4 x float> %137, <4 x float> undef, <4 x i32> zeroinitializer
  %139 = fmul contract <4 x float> %136, %138
  %140 = fsub contract <4 x float> %139, %99
  %141 = fadd contract <4 x float> %98, %140
  %142 = fsub contract <4 x float> %141, %98
  %143 = fsub contract <4 x float> %142, %140
  %144 = add i64 %96, 1
  %145 = mul i64 %144, %57
  %146 = add i64 %145, %11
  %147 = add i64 %146, %14
  %148 = add i64 %147, %88
  %149 = getelementptr inbounds bfloat, ptr %0, i64 %148
  %150 = load <4 x bfloat>, ptr %149, align 8, !invariant.load !1
  %151 = fpext <4 x bfloat> %150 to <4 x float>
  %152 = extractelement <8 x float> %124, i64 1
  %153 = fcmp ogt float %152, 0.000000e+00
  %154 = insertelement <4 x i1> undef, i1 %153, i32 0
  %155 = shufflevector <4 x i1> %154, <4 x i1> undef, <4 x i32> zeroinitializer
  %156 = select <4 x i1> %155, <4 x float> %151, <4 x float> zeroinitializer
  %157 = insertelement <4 x float> undef, float %152, i32 0
  %158 = shufflevector <4 x float> %157, <4 x float> undef, <4 x i32> zeroinitializer
  %159 = fmul contract <4 x float> %156, %158
  %160 = fsub contract <4 x float> %159, %143
  %161 = fadd contract <4 x float> %141, %160
  %162 = fsub contract <4 x float> %161, %141
  %163 = fsub contract <4 x float> %162, %160
  %164 = add i64 %96, 2
  %165 = mul i64 %164, %57
  %166 = add i64 %165, %11
  %167 = add i64 %166, %14
  %168 = add i64 %167, %88
  %169 = getelementptr inbounds bfloat, ptr %0, i64 %168
  %170 = load <4 x bfloat>, ptr %169, align 8, !invariant.load !1
  %171 = fpext <4 x bfloat> %170 to <4 x float>
  %172 = extractelement <8 x float> %124, i64 2
  %173 = fcmp ogt float %172, 0.000000e+00
  %174 = insertelement <4 x i1> undef, i1 %173, i32 0
  %175 = shufflevector <4 x i1> %174, <4 x i1> undef, <4 x i32> zeroinitializer
  %176 = select <4 x i1> %175, <4 x float> %171, <4 x float> zeroinitializer
  %177 = insertelement <4 x float> undef, float %172, i32 0
  %178 = shufflevector <4 x float> %177, <4 x float> undef, <4 x i32> zeroinitializer
  %179 = fmul contract <4 x float> %176, %178
  %180 = fsub contract <4 x float> %179, %163
  %181 = fadd contract <4 x float> %161, %180
  %182 = fsub contract <4 x float> %181, %161
  %183 = fsub contract <4 x float> %182, %180
  %184 = add i64 %96, 3
  %185 = mul i64 %184, %57
  %186 = add i64 %185, %11
  %187 = add i64 %186, %14
  %188 = add i64 %187, %88
  %189 = getelementptr inbounds bfloat, ptr %0, i64 %188
  %190 = load <4 x bfloat>, ptr %189, align 8, !invariant.load !1
  %191 = fpext <4 x bfloat> %190 to <4 x float>
  %192 = extractelement <8 x float> %124, i64 3
  %193 = fcmp ogt float %192, 0.000000e+00
  %194 = insertelement <4 x i1> undef, i1 %193, i32 0
  %195 = shufflevector <4 x i1> %194, <4 x i1> undef, <4 x i32> zeroinitializer
  %196 = select <4 x i1> %195, <4 x float> %191, <4 x float> zeroinitializer
  %197 = insertelement <4 x float> undef, float %192, i32 0
  %198 = shufflevector <4 x float> %197, <4 x float> undef, <4 x i32> zeroinitializer
  %199 = fmul contract <4 x float> %196, %198
  %200 = fsub contract <4 x float> %199, %183
  %201 = fadd contract <4 x float> %181, %200
  %202 = fsub contract <4 x float> %201, %181
  %203 = fsub contract <4 x float> %202, %200
  %204 = add i64 %96, 4
  %205 = mul i64 %204, %57
  %206 = add i64 %205, %11
  %207 = add i64 %206, %14
  %208 = add i64 %207, %88
  %209 = getelementptr inbounds bfloat, ptr %0, i64 %208
  %210 = load <4 x bfloat>, ptr %209, align 8, !invariant.load !1
  %211 = fpext <4 x bfloat> %210 to <4 x float>
  %212 = extractelement <8 x float> %124, i64 4
  %213 = fcmp ogt float %212, 0.000000e+00
  %214 = insertelement <4 x i1> undef, i1 %213, i32 0
  %215 = shufflevector <4 x i1> %214, <4 x i1> undef, <4 x i32> zeroinitializer
  %216 = select <4 x i1> %215, <4 x float> %211, <4 x float> zeroinitializer
  %217 = insertelement <4 x float> undef, float %212, i32 0
  %218 = shufflevector <4 x float> %217, <4 x float> undef, <4 x i32> zeroinitializer
  %219 = fmul contract <4 x float> %216, %218
  %220 = fsub contract <4 x float> %219, %203
  %221 = fadd contract <4 x float> %201, %220
  %222 = fsub contract <4 x float> %221, %201
  %223 = fsub contract <4 x float> %222, %220
  %224 = add i64 %96, 5
  %225 = mul i64 %224, %57
  %226 = add i64 %225, %11
  %227 = add i64 %226, %14
  %228 = add i64 %227, %88
  %229 = getelementptr inbounds bfloat, ptr %0, i64 %228
  %230 = load <4 x bfloat>, ptr %229, align 8, !invariant.load !1
  %231 = fpext <4 x bfloat> %230 to <4 x float>
  %232 = extractelement <8 x float> %124, i64 5
  %233 = fcmp ogt float %232, 0.000000e+00
  %234 = insertelement <4 x i1> undef, i1 %233, i32 0
  %235 = shufflevector <4 x i1> %234, <4 x i1> undef, <4 x i32> zeroinitializer
  %236 = select <4 x i1> %235, <4 x float> %231, <4 x float> zeroinitializer
  %237 = insertelement <4 x float> undef, float %232, i32 0
  %238 = shufflevector <4 x float> %237, <4 x float> undef, <4 x i32> zeroinitializer
  %239 = fmul contract <4 x float> %236, %238
  %240 = fsub contract <4 x float> %239, %223
  %241 = fadd contract <4 x float> %221, %240
  %242 = fsub contract <4 x float> %241, %221
  %243 = fsub contract <4 x float> %242, %240
  %244 = add i64 %96, 6
  %245 = mul i64 %244, %57
  %246 = add i64 %245, %11
  %247 = add i64 %246, %14
  %248 = add i64 %247, %88
  %249 = getelementptr inbounds bfloat, ptr %0, i64 %248
  %250 = load <4 x bfloat>, ptr %249, align 8, !invariant.load !1
  %251 = fpext <4 x bfloat> %250 to <4 x float>
  %252 = extractelement <8 x float> %124, i64 6
  %253 = fcmp ogt float %252, 0.000000e+00
  %254 = insertelement <4 x i1> undef, i1 %253, i32 0
  %255 = shufflevector <4 x i1> %254, <4 x i1> undef, <4 x i32> zeroinitializer
  %256 = select <4 x i1> %255, <4 x float> %251, <4 x float> zeroinitializer
  %257 = insertelement <4 x float> undef, float %252, i32 0
  %258 = shufflevector <4 x float> %257, <4 x float> undef, <4 x i32> zeroinitializer
  %259 = fmul contract <4 x float> %256, %258
  %260 = fsub contract <4 x float> %259, %243
  %261 = fadd contract <4 x float> %241, %260
  %262 = fsub contract <4 x float> %261, %241
  %263 = fsub contract <4 x float> %262, %260
  %264 = add i64 %96, 7
  %265 = mul i64 %264, %57
  %266 = add i64 %265, %11
  %267 = add i64 %266, %14
  %268 = add i64 %267, %88
  %269 = getelementptr inbounds bfloat, ptr %0, i64 %268
  %270 = load <4 x bfloat>, ptr %269, align 8, !invariant.load !1
  %271 = fpext <4 x bfloat> %270 to <4 x float>
  %272 = extractelement <8 x float> %124, i64 7
  %273 = fcmp ogt float %272, 0.000000e+00
  %274 = insertelement <4 x i1> undef, i1 %273, i32 0
  %275 = shufflevector <4 x i1> %274, <4 x i1> undef, <4 x i32> zeroinitializer
  %276 = select <4 x i1> %275, <4 x float> %271, <4 x float> zeroinitializer
  %277 = insertelement <4 x float> undef, float %272, i32 0
  %278 = shufflevector <4 x float> %277, <4 x float> undef, <4 x i32> zeroinitializer
  %279 = fmul contract <4 x float> %276, %278
  %280 = fsub contract <4 x float> %279, %263
  %281 = fadd contract <4 x float> %261, %280
  %282 = fsub contract <4 x float> %281, %261
  %283 = fsub contract <4 x float> %282, %280
  br label %95

284:                                              ; preds = %289, %109
  %285 = phi i64 [ %94, %109 ], [ %292, %289 ]
  %286 = phi <4 x float> [ %98, %109 ], [ %320, %289 ]
  %287 = phi <4 x float> [ %99, %109 ], [ %322, %289 ]
  %288 = icmp slt i64 %285, %110
  br i1 %288, label %289, label %323

289:                                              ; preds = %284
  %290 = icmp eq i64 %285, %110
  %291 = add i64 %285, 1
  %292 = select i1 %290, i64 %285, i64 %291
  %293 = sdiv i64 %285, 1
  %294 = mul i64 %293, 1
  %295 = icmp eq i64 %294, %285
  %296 = xor i64 %285, 1
  %297 = ashr i64 %296, 63
  %298 = select i1 %295, i64 0, i64 %297
  %299 = add i64 %293, %298
  %300 = trunc i64 %299 to i32
  %301 = sext i32 %300 to i64
  %302 = trunc i64 %301 to i32
  %303 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_bfloat16_bfloat16_6f575645.exp_sums_storage_0._gpu_shared_mem, i32 %302
  %304 = load float, ptr addrspace(3) %303, align 4
  %305 = mul i64 %285, %57
  %306 = add i64 %305, %11
  %307 = add i64 %306, %14
  %308 = add i64 %307, %88
  %309 = getelementptr inbounds bfloat, ptr %0, i64 %308
  %310 = load <4 x bfloat>, ptr %309, align 8, !invariant.load !1
  %311 = fpext <4 x bfloat> %310 to <4 x float>
  %312 = fcmp ogt float %304, 0.000000e+00
  %313 = insertelement <4 x i1> undef, i1 %312, i32 0
  %314 = shufflevector <4 x i1> %313, <4 x i1> undef, <4 x i32> zeroinitializer
  %315 = select <4 x i1> %314, <4 x float> %311, <4 x float> zeroinitializer
  %316 = insertelement <4 x float> undef, float %304, i32 0
  %317 = shufflevector <4 x float> %316, <4 x float> undef, <4 x i32> zeroinitializer
  %318 = fmul contract <4 x float> %315, %317
  %319 = fsub contract <4 x float> %318, %287
  %320 = fadd contract <4 x float> %286, %319
  %321 = fsub contract <4 x float> %320, %286
  %322 = fsub contract <4 x float> %321, %319
  br label %284

323:                                              ; preds = %284
  %324 = fmul contract <4 x float> %286, %87
  %325 = fptrunc <4 x float> %324 to <4 x bfloat>
  store <4 x bfloat> %325, ptr %90, align 8
  br label %327

326:                                              ; preds = %63
  br label %327

327:                                              ; preds = %326, %323
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
