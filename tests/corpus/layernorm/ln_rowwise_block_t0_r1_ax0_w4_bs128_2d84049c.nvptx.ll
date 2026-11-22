; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r1_ax0_w4_bs128_2d84049c._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r1_ax0_w4_bs128_2d84049c(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
  %2 = alloca i64, i64 1, align 8
  %3 = alloca i64, i64 1, align 8
  %4 = alloca i64, i64 1, align 8
  %5 = alloca i64, i64 1, align 8
  %6 = alloca i64, i64 1, align 8
  %7 = alloca i64, i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca { float, float, float }, i64 1, align 4
  %11 = alloca { float, float, float }, i64 1, align 4
  %12 = alloca { float, float, float }, i64 1, align 4
  %13 = alloca { float, float, float }, i64 1, align 4
  %14 = alloca { float, float, float }, i64 1, align 4
  %15 = alloca { float, float, float }, i64 1, align 4
  %16 = alloca { float, float, float }, i64 1, align 4
  %17 = alloca { float, float, float }, i64 1, align 4
  %18 = alloca { float, float, float }, i64 1, align 4
  %19 = alloca { float, float, float }, i64 1, align 4
  %20 = alloca { float, float, float }, i64 1, align 4
  %21 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %22 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %21, i32 0, i32 5
  %23 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %21, i32 0, i32 4
  %24 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %21, i32 0, i32 3
  %25 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %21, i32 0, i32 2
  %26 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %21, i32 0, i32 1
  %27 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %21, i32 0, i32 0
  %28 = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> splat (i1 true))
  %29 = call <4 x i64> @llvm.stepvector.v4i64()
  %30 = mul <4 x i64> %29, splat (i64 4)
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %32 = sext i32 %31 to i64
  %33 = icmp slt i64 %32, 4
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %35 = zext i32 %34 to i64
  %36 = mul i64 %35, 4
  %37 = icmp eq i64 %32, 0
  %38 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %39 = zext i32 %38 to i64
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %41 = sext i32 %40 to i64
  %42 = icmp eq i64 %41, 0
  %43 = select i1 %42, i64 0, i64 %39
  %44 = select i1 %42, i64 0, i64 1
  %45 = select i1 %42, i64 1, i64 %41
  %46 = icmp slt i64 %45, 0
  %47 = icmp sgt i64 %45, 0
  br label %48

48:                                               ; preds = %629, %1
  %49 = phi i64 [ %43, %1 ], [ %72, %629 ]
  %50 = phi i64 [ 0, %1 ], [ %73, %629 ]
  %51 = icmp sge i64 %44, %49
  %52 = icmp sge i64 %49, %44
  %53 = add i64 %49, %45
  %54 = icmp slt i64 %53, %49
  %55 = xor i1 %54, %46
  %56 = select i1 %55, i64 1, i64 0
  %57 = icmp eq i64 %50, 0
  %58 = xor i1 %57, true
  %59 = or i1 %58, %51
  %60 = or i1 %58, %52
  br label %61

61:                                               ; preds = %48
  br i1 %47, label %62, label %67

62:                                               ; preds = %61
  br i1 %60, label %63, label %64

63:                                               ; preds = %62
  br label %70

64:                                               ; preds = %62
  br label %65

65:                                               ; preds = %64
  br label %69

66:                                               ; preds = %67
  br label %69

67:                                               ; preds = %61
  br i1 %59, label %68, label %66

68:                                               ; preds = %67
  br label %70

69:                                               ; preds = %66, %65
  br label %70

70:                                               ; preds = %69, %68, %63
  %71 = phi i1 [ true, %63 ], [ true, %68 ], [ false, %69 ]
  %72 = phi i64 [ %49, %63 ], [ %49, %68 ], [ %53, %69 ]
  %73 = phi i64 [ %50, %63 ], [ %50, %68 ], [ %56, %69 ]
  br i1 %71, label %74, label %75

74:                                               ; preds = %70
  br label %630

75:                                               ; preds = %70
  br label %76

76:                                               ; preds = %75
  %77 = load i64, ptr %27, align 8
  %78 = load { ptr, { { i64 }, { {} } } }, ptr %26, align 8
  %79 = load { ptr, { { i64 }, { {} } } }, ptr %25, align 8
  %80 = load float, ptr %24, align 4
  %81 = load { ptr, { { i64 }, { {} } } }, ptr %23, align 8
  %82 = extractvalue { ptr, { { i64 }, { {} } } } %81, 0
  br label %83

83:                                               ; preds = %163, %76
  %84 = phi i64 [ 0, %76 ], [ %164, %163 ]
  %85 = phi i64 [ 0, %76 ], [ %99, %163 ]
  %86 = phi i64 [ 0, %76 ], [ %100, %163 ]
  %87 = phi <4 x float> [ zeroinitializer, %76 ], [ %165, %163 ]
  %88 = phi <4 x float> [ zeroinitializer, %76 ], [ %166, %163 ]
  %89 = phi <4 x float> [ zeroinitializer, %76 ], [ %167, %163 ]
  %90 = fadd contract <4 x float> %87, splat (float 1.000000e+00)
  %91 = extractelement <4 x float> %90, i64 0
  %92 = add i64 %85, 512
  %93 = icmp slt i64 %92, %85
  %94 = select i1 %93, i64 1, i64 0
  %95 = icmp sge i64 %85, %77
  %96 = icmp eq i64 %86, 0
  %97 = xor i1 %96, true
  %98 = or i1 %97, %95
  %99 = select i1 %98, i64 %85, i64 %92
  %100 = select i1 %98, i64 %86, i64 %94
  br i1 %98, label %101, label %102

101:                                              ; preds = %83
  br label %168

102:                                              ; preds = %83
  br label %103

103:                                              ; preds = %102
  %104 = add i64 %85, %36
  %105 = getelementptr inbounds float, ptr %82, i64 %104
  %106 = sub i64 %77, %104
  %107 = call i64 @llvm.smin.i64(i64 %106, i64 4)
  %108 = call i64 @llvm.smax.i64(i64 %107, i64 0)
  %109 = icmp eq i64 %107, 4
  %110 = icmp slt i64 %104, %77
  br i1 %110, label %111, label %162

111:                                              ; preds = %103
  br i1 %109, label %112, label %124

112:                                              ; preds = %111
  %113 = load <4 x float>, ptr %105, align 16
  %114 = fsub contract <4 x float> %113, %88
  %115 = fdiv float 1.000000e+00, %91
  %116 = insertelement <4 x float> undef, float %115, i32 0
  %117 = shufflevector <4 x float> %116, <4 x float> undef, <4 x i32> zeroinitializer
  %118 = fmul contract <4 x float> %114, %117
  %119 = fadd contract <4 x float> %88, %118
  %120 = fmul contract <4 x float> %114, %114
  %121 = fmul contract <4 x float> %120, %87
  %122 = fmul contract <4 x float> %121, %117
  %123 = fadd contract <4 x float> %89, %122
  br label %157

124:                                              ; preds = %111
  br label %125

125:                                              ; preds = %134, %124
  %126 = phi i64 [ 0, %124 ], [ %137, %134 ]
  %127 = phi i64 [ %84, %124 ], [ %138, %134 ]
  %128 = phi <4 x float> [ %87, %124 ], [ %142, %134 ]
  %129 = phi <4 x float> [ %88, %124 ], [ %147, %134 ]
  %130 = phi <4 x float> [ %89, %124 ], [ %151, %134 ]
  %131 = icmp slt i64 %126, %108
  br i1 %131, label %132, label %133

132:                                              ; preds = %125
  br label %134

133:                                              ; preds = %125
  br label %152

134:                                              ; preds = %132
  %135 = icmp eq i64 %126, %108
  %136 = add i64 %126, 1
  %137 = select i1 %135, i64 %126, i64 %136
  %138 = add i64 %104, %126
  %139 = getelementptr inbounds float, ptr %82, i64 %138
  %140 = load float, ptr %139, align 4
  %141 = insertelement <4 x float> zeroinitializer, float %140, i64 0
  %142 = fadd contract <4 x float> %128, <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>
  %143 = fsub contract <4 x float> %141, %129
  %144 = call <4 x float> @llvm.maxnum.v4f32(<4 x float> %142, <4 x float> splat (float 1.000000e+00))
  %145 = fdiv <4 x float> <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, %144
  %146 = fmul contract <4 x float> %143, %145
  %147 = fadd contract <4 x float> %129, %146
  %148 = fmul contract <4 x float> %143, %143
  %149 = fmul contract <4 x float> %148, %128
  %150 = fmul contract <4 x float> %149, %145
  %151 = fadd contract <4 x float> %130, %150
  br label %125

152:                                              ; preds = %133
  %153 = phi i64 [ %127, %133 ]
  %154 = phi <4 x float> [ %128, %133 ]
  %155 = phi <4 x float> [ %129, %133 ]
  %156 = phi <4 x float> [ %130, %133 ]
  br label %157

157:                                              ; preds = %152, %112
  %158 = phi i64 [ %153, %152 ], [ %104, %112 ]
  %159 = phi <4 x float> [ %154, %152 ], [ %90, %112 ]
  %160 = phi <4 x float> [ %155, %152 ], [ %119, %112 ]
  %161 = phi <4 x float> [ %156, %152 ], [ %123, %112 ]
  br label %163

162:                                              ; preds = %103
  br label %163

163:                                              ; preds = %162, %157
  %164 = phi i64 [ %84, %162 ], [ %158, %157 ]
  %165 = phi <4 x float> [ %87, %162 ], [ %159, %157 ]
  %166 = phi <4 x float> [ %88, %162 ], [ %160, %157 ]
  %167 = phi <4 x float> [ %89, %162 ], [ %161, %157 ]
  br label %83

168:                                              ; preds = %101
  %169 = phi <4 x float> [ %87, %101 ]
  %170 = phi <4 x float> [ %88, %101 ]
  %171 = phi <4 x float> [ %89, %101 ]
  %172 = insertvalue { <4 x float>, <4 x float>, <4 x float> } undef, <4 x float> %169, 0
  %173 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %172, <4 x float> %170, 1
  %174 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %173, <4 x float> %171, 2
  %175 = call { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } %174)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store { float, float, float } %175, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store { float, float, float } zeroinitializer, ptr %19, align 4
  %176 = load i32, ptr %20, align 4
  %177 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %176, i32 16, i32 31)
  store i32 %177, ptr %19, align 4
  %178 = getelementptr inbounds i32, ptr %19, i32 1
  %179 = getelementptr inbounds i32, ptr %20, i32 1
  %180 = load i32, ptr %179, align 4
  %181 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %180, i32 16, i32 31)
  store i32 %181, ptr %178, align 4
  %182 = getelementptr inbounds i32, ptr %19, i32 2
  %183 = getelementptr inbounds i32, ptr %20, i32 2
  %184 = load i32, ptr %183, align 4
  %185 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %184, i32 16, i32 31)
  store i32 %185, ptr %182, align 4
  %186 = load { float, float, float }, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  %187 = getelementptr { float, float, float }, ptr %20, i32 0, i32 0
  %188 = load float, ptr %187, align 4
  %189 = extractvalue { float, float, float } %186, 0
  %190 = fadd contract float %188, %189
  %191 = call float @llvm.maxnum.f32(float %190, float 1.000000e+00)
  %192 = extractvalue { float, float, float } %186, 1
  %193 = getelementptr { float, float, float }, ptr %20, i32 0, i32 1
  %194 = load float, ptr %193, align 4
  %195 = fsub contract float %192, %194
  %196 = fdiv float %189, %191
  %197 = getelementptr { float, float, float }, ptr %20, i32 0, i32 2
  %198 = extractvalue { float, float, float } %186, 2
  %199 = load float, ptr %197, align 4
  %200 = fadd contract float %199, %198
  %201 = fmul contract float %195, %195
  %202 = fmul contract float %201, %188
  %203 = fmul contract float %202, %196
  %204 = fadd contract float %200, %203
  store float %204, ptr %197, align 4
  %205 = fmul contract float %195, %196
  %206 = load float, ptr %193, align 4
  %207 = fadd contract float %206, %205
  store float %207, ptr %193, align 4
  store float %190, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store { float, float, float } zeroinitializer, ptr %18, align 4
  %208 = load i32, ptr %20, align 4
  %209 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %208, i32 8, i32 31)
  store i32 %209, ptr %18, align 4
  %210 = getelementptr inbounds i32, ptr %18, i32 1
  %211 = load i32, ptr %179, align 4
  %212 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %211, i32 8, i32 31)
  store i32 %212, ptr %210, align 4
  %213 = getelementptr inbounds i32, ptr %18, i32 2
  %214 = load i32, ptr %183, align 4
  %215 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %214, i32 8, i32 31)
  store i32 %215, ptr %213, align 4
  %216 = load { float, float, float }, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  %217 = load float, ptr %187, align 4
  %218 = extractvalue { float, float, float } %216, 0
  %219 = fadd contract float %217, %218
  %220 = call float @llvm.maxnum.f32(float %219, float 1.000000e+00)
  %221 = extractvalue { float, float, float } %216, 1
  %222 = load float, ptr %193, align 4
  %223 = fsub contract float %221, %222
  %224 = fdiv float %218, %220
  %225 = extractvalue { float, float, float } %216, 2
  %226 = load float, ptr %197, align 4
  %227 = fadd contract float %226, %225
  %228 = fmul contract float %223, %223
  %229 = fmul contract float %228, %217
  %230 = fmul contract float %229, %224
  %231 = fadd contract float %227, %230
  store float %231, ptr %197, align 4
  %232 = fmul contract float %223, %224
  %233 = load float, ptr %193, align 4
  %234 = fadd contract float %233, %232
  store float %234, ptr %193, align 4
  store float %219, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store { float, float, float } zeroinitializer, ptr %17, align 4
  %235 = load i32, ptr %20, align 4
  %236 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %235, i32 4, i32 31)
  store i32 %236, ptr %17, align 4
  %237 = getelementptr inbounds i32, ptr %17, i32 1
  %238 = load i32, ptr %179, align 4
  %239 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %238, i32 4, i32 31)
  store i32 %239, ptr %237, align 4
  %240 = getelementptr inbounds i32, ptr %17, i32 2
  %241 = load i32, ptr %183, align 4
  %242 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %241, i32 4, i32 31)
  store i32 %242, ptr %240, align 4
  %243 = load { float, float, float }, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  %244 = load float, ptr %187, align 4
  %245 = extractvalue { float, float, float } %243, 0
  %246 = fadd contract float %244, %245
  %247 = call float @llvm.maxnum.f32(float %246, float 1.000000e+00)
  %248 = extractvalue { float, float, float } %243, 1
  %249 = load float, ptr %193, align 4
  %250 = fsub contract float %248, %249
  %251 = fdiv float %245, %247
  %252 = extractvalue { float, float, float } %243, 2
  %253 = load float, ptr %197, align 4
  %254 = fadd contract float %253, %252
  %255 = fmul contract float %250, %250
  %256 = fmul contract float %255, %244
  %257 = fmul contract float %256, %251
  %258 = fadd contract float %254, %257
  store float %258, ptr %197, align 4
  %259 = fmul contract float %250, %251
  %260 = load float, ptr %193, align 4
  %261 = fadd contract float %260, %259
  store float %261, ptr %193, align 4
  store float %246, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store { float, float, float } zeroinitializer, ptr %16, align 4
  %262 = load i32, ptr %20, align 4
  %263 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %262, i32 2, i32 31)
  store i32 %263, ptr %16, align 4
  %264 = getelementptr inbounds i32, ptr %16, i32 1
  %265 = load i32, ptr %179, align 4
  %266 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %265, i32 2, i32 31)
  store i32 %266, ptr %264, align 4
  %267 = getelementptr inbounds i32, ptr %16, i32 2
  %268 = load i32, ptr %183, align 4
  %269 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %268, i32 2, i32 31)
  store i32 %269, ptr %267, align 4
  %270 = load { float, float, float }, ptr %16, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %271 = load float, ptr %187, align 4
  %272 = extractvalue { float, float, float } %270, 0
  %273 = fadd contract float %271, %272
  %274 = call float @llvm.maxnum.f32(float %273, float 1.000000e+00)
  %275 = extractvalue { float, float, float } %270, 1
  %276 = load float, ptr %193, align 4
  %277 = fsub contract float %275, %276
  %278 = fdiv float %272, %274
  %279 = extractvalue { float, float, float } %270, 2
  %280 = load float, ptr %197, align 4
  %281 = fadd contract float %280, %279
  %282 = fmul contract float %277, %277
  %283 = fmul contract float %282, %271
  %284 = fmul contract float %283, %278
  %285 = fadd contract float %281, %284
  store float %285, ptr %197, align 4
  %286 = fmul contract float %277, %278
  %287 = load float, ptr %193, align 4
  %288 = fadd contract float %287, %286
  store float %288, ptr %193, align 4
  store float %273, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store { float, float, float } zeroinitializer, ptr %15, align 4
  %289 = load i32, ptr %20, align 4
  %290 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %289, i32 1, i32 31)
  store i32 %290, ptr %15, align 4
  %291 = getelementptr inbounds i32, ptr %15, i32 1
  %292 = load i32, ptr %179, align 4
  %293 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %292, i32 1, i32 31)
  store i32 %293, ptr %291, align 4
  %294 = getelementptr inbounds i32, ptr %15, i32 2
  %295 = load i32, ptr %183, align 4
  %296 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %295, i32 1, i32 31)
  store i32 %296, ptr %294, align 4
  %297 = load { float, float, float }, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  %298 = load float, ptr %187, align 4
  %299 = extractvalue { float, float, float } %297, 0
  %300 = fadd contract float %298, %299
  %301 = call float @llvm.maxnum.f32(float %300, float 1.000000e+00)
  %302 = extractvalue { float, float, float } %297, 1
  %303 = load float, ptr %193, align 4
  %304 = fsub contract float %302, %303
  %305 = fdiv float %299, %301
  %306 = extractvalue { float, float, float } %297, 2
  %307 = load float, ptr %197, align 4
  %308 = fadd contract float %307, %306
  %309 = fmul contract float %304, %304
  %310 = fmul contract float %309, %298
  %311 = fmul contract float %310, %305
  %312 = fadd contract float %308, %311
  store float %312, ptr %197, align 4
  %313 = fmul contract float %304, %305
  %314 = load float, ptr %193, align 4
  %315 = fadd contract float %314, %313
  store float %315, ptr %193, align 4
  store float %300, ptr %187, align 4
  %316 = udiv i64 %35, 32
  %317 = trunc i64 %316 to i32
  %318 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w4_bs128_2d84049c._global_alloc_0._gpu_shared_mem, i32 %317
  %319 = trunc i64 %32 to i32
  %320 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w4_bs128_2d84049c._global_alloc_0._gpu_shared_mem, i32 %319
  br i1 %37, label %321, label %323

321:                                              ; preds = %168
  %322 = load { float, float, float }, ptr %20, align 4
  store { float, float, float } %322, ptr addrspace(3) %318, align 4
  br label %324

323:                                              ; preds = %168
  br label %324

324:                                              ; preds = %323, %321
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %325 = icmp eq i64 %316, 0
  br i1 %325, label %326, label %470

326:                                              ; preds = %324
  br i1 %33, label %327, label %329

327:                                              ; preds = %326
  %328 = load { float, float, float }, ptr addrspace(3) %320, align 4
  store { float, float, float } %328, ptr %20, align 4
  br label %330

329:                                              ; preds = %326
  store { float, float, float } zeroinitializer, ptr %20, align 4
  br label %330

330:                                              ; preds = %329, %327
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store { float, float, float } zeroinitializer, ptr %14, align 4
  %331 = load i32, ptr %20, align 4
  %332 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %331, i32 16, i32 31)
  store i32 %332, ptr %14, align 4
  %333 = getelementptr inbounds i32, ptr %14, i32 1
  %334 = load i32, ptr %179, align 4
  %335 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %334, i32 16, i32 31)
  store i32 %335, ptr %333, align 4
  %336 = getelementptr inbounds i32, ptr %14, i32 2
  %337 = load i32, ptr %183, align 4
  %338 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %337, i32 16, i32 31)
  store i32 %338, ptr %336, align 4
  %339 = load { float, float, float }, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  %340 = load float, ptr %187, align 4
  %341 = extractvalue { float, float, float } %339, 0
  %342 = fadd contract float %340, %341
  %343 = call float @llvm.maxnum.f32(float %342, float 1.000000e+00)
  %344 = extractvalue { float, float, float } %339, 1
  %345 = load float, ptr %193, align 4
  %346 = fsub contract float %344, %345
  %347 = fdiv float %341, %343
  %348 = extractvalue { float, float, float } %339, 2
  %349 = load float, ptr %197, align 4
  %350 = fadd contract float %349, %348
  %351 = fmul contract float %346, %346
  %352 = fmul contract float %351, %340
  %353 = fmul contract float %352, %347
  %354 = fadd contract float %350, %353
  store float %354, ptr %197, align 4
  %355 = fmul contract float %346, %347
  %356 = load float, ptr %193, align 4
  %357 = fadd contract float %356, %355
  store float %357, ptr %193, align 4
  store float %342, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store { float, float, float } zeroinitializer, ptr %13, align 4
  %358 = load i32, ptr %20, align 4
  %359 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %358, i32 8, i32 31)
  store i32 %359, ptr %13, align 4
  %360 = getelementptr inbounds i32, ptr %13, i32 1
  %361 = load i32, ptr %179, align 4
  %362 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %361, i32 8, i32 31)
  store i32 %362, ptr %360, align 4
  %363 = getelementptr inbounds i32, ptr %13, i32 2
  %364 = load i32, ptr %183, align 4
  %365 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %364, i32 8, i32 31)
  store i32 %365, ptr %363, align 4
  %366 = load { float, float, float }, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %367 = load float, ptr %187, align 4
  %368 = extractvalue { float, float, float } %366, 0
  %369 = fadd contract float %367, %368
  %370 = call float @llvm.maxnum.f32(float %369, float 1.000000e+00)
  %371 = extractvalue { float, float, float } %366, 1
  %372 = load float, ptr %193, align 4
  %373 = fsub contract float %371, %372
  %374 = fdiv float %368, %370
  %375 = extractvalue { float, float, float } %366, 2
  %376 = load float, ptr %197, align 4
  %377 = fadd contract float %376, %375
  %378 = fmul contract float %373, %373
  %379 = fmul contract float %378, %367
  %380 = fmul contract float %379, %374
  %381 = fadd contract float %377, %380
  store float %381, ptr %197, align 4
  %382 = fmul contract float %373, %374
  %383 = load float, ptr %193, align 4
  %384 = fadd contract float %383, %382
  store float %384, ptr %193, align 4
  store float %369, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } zeroinitializer, ptr %12, align 4
  %385 = load i32, ptr %20, align 4
  %386 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %385, i32 4, i32 31)
  store i32 %386, ptr %12, align 4
  %387 = getelementptr inbounds i32, ptr %12, i32 1
  %388 = load i32, ptr %179, align 4
  %389 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %388, i32 4, i32 31)
  store i32 %389, ptr %387, align 4
  %390 = getelementptr inbounds i32, ptr %12, i32 2
  %391 = load i32, ptr %183, align 4
  %392 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %391, i32 4, i32 31)
  store i32 %392, ptr %390, align 4
  %393 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %394 = load float, ptr %187, align 4
  %395 = extractvalue { float, float, float } %393, 0
  %396 = fadd contract float %394, %395
  %397 = call float @llvm.maxnum.f32(float %396, float 1.000000e+00)
  %398 = extractvalue { float, float, float } %393, 1
  %399 = load float, ptr %193, align 4
  %400 = fsub contract float %398, %399
  %401 = fdiv float %395, %397
  %402 = extractvalue { float, float, float } %393, 2
  %403 = load float, ptr %197, align 4
  %404 = fadd contract float %403, %402
  %405 = fmul contract float %400, %400
  %406 = fmul contract float %405, %394
  %407 = fmul contract float %406, %401
  %408 = fadd contract float %404, %407
  store float %408, ptr %197, align 4
  %409 = fmul contract float %400, %401
  %410 = load float, ptr %193, align 4
  %411 = fadd contract float %410, %409
  store float %411, ptr %193, align 4
  store float %396, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %412 = load i32, ptr %20, align 4
  %413 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %412, i32 2, i32 31)
  store i32 %413, ptr %11, align 4
  %414 = getelementptr inbounds i32, ptr %11, i32 1
  %415 = load i32, ptr %179, align 4
  %416 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %415, i32 2, i32 31)
  store i32 %416, ptr %414, align 4
  %417 = getelementptr inbounds i32, ptr %11, i32 2
  %418 = load i32, ptr %183, align 4
  %419 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %418, i32 2, i32 31)
  store i32 %419, ptr %417, align 4
  %420 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %421 = load float, ptr %187, align 4
  %422 = extractvalue { float, float, float } %420, 0
  %423 = fadd contract float %421, %422
  %424 = call float @llvm.maxnum.f32(float %423, float 1.000000e+00)
  %425 = extractvalue { float, float, float } %420, 1
  %426 = load float, ptr %193, align 4
  %427 = fsub contract float %425, %426
  %428 = fdiv float %422, %424
  %429 = extractvalue { float, float, float } %420, 2
  %430 = load float, ptr %197, align 4
  %431 = fadd contract float %430, %429
  %432 = fmul contract float %427, %427
  %433 = fmul contract float %432, %421
  %434 = fmul contract float %433, %428
  %435 = fadd contract float %431, %434
  store float %435, ptr %197, align 4
  %436 = fmul contract float %427, %428
  %437 = load float, ptr %193, align 4
  %438 = fadd contract float %437, %436
  store float %438, ptr %193, align 4
  store float %423, ptr %187, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %439 = load i32, ptr %20, align 4
  %440 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %439, i32 1, i32 31)
  store i32 %440, ptr %10, align 4
  %441 = getelementptr inbounds i32, ptr %10, i32 1
  %442 = load i32, ptr %179, align 4
  %443 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %442, i32 1, i32 31)
  store i32 %443, ptr %441, align 4
  %444 = getelementptr inbounds i32, ptr %10, i32 2
  %445 = load i32, ptr %183, align 4
  %446 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %445, i32 1, i32 31)
  store i32 %446, ptr %444, align 4
  %447 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %448 = load float, ptr %187, align 4
  %449 = extractvalue { float, float, float } %447, 0
  %450 = fadd contract float %448, %449
  %451 = call float @llvm.maxnum.f32(float %450, float 1.000000e+00)
  %452 = extractvalue { float, float, float } %447, 1
  %453 = load float, ptr %193, align 4
  %454 = fsub contract float %452, %453
  %455 = fdiv float %449, %451
  %456 = extractvalue { float, float, float } %447, 2
  %457 = load float, ptr %197, align 4
  %458 = fadd contract float %457, %456
  %459 = fmul contract float %454, %454
  %460 = fmul contract float %459, %448
  %461 = fmul contract float %460, %455
  %462 = fadd contract float %458, %461
  store float %462, ptr %197, align 4
  %463 = fmul contract float %454, %455
  %464 = load float, ptr %193, align 4
  %465 = fadd contract float %464, %463
  store float %465, ptr %193, align 4
  store float %450, ptr %187, align 4
  br i1 %37, label %466, label %468

466:                                              ; preds = %330
  %467 = load { float, float, float }, ptr %20, align 4
  store { float, float, float } %467, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w4_bs128_2d84049c._global_alloc_0._gpu_shared_mem, align 4
  br label %469

468:                                              ; preds = %330
  br label %469

469:                                              ; preds = %468, %466
  br label %471

470:                                              ; preds = %324
  br label %471

471:                                              ; preds = %470, %469
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %472 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w4_bs128_2d84049c._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %472, ptr %20, align 4
  %473 = load float, ptr %193, align 4
  store float %473, ptr %193, align 4
  %474 = load float, ptr %197, align 4
  store float %474, ptr %197, align 4
  %475 = load float, ptr %187, align 4
  store float %475, ptr %187, align 4
  %476 = load { float, float, float }, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %20)
  %477 = extractvalue { float, float, float } %476, 0
  %478 = insertelement <4 x float> zeroinitializer, float %477, i64 0
  %479 = extractvalue { float, float, float } %476, 1
  %480 = insertelement <4 x float> zeroinitializer, float %479, i64 0
  %481 = extractvalue { float, float, float } %476, 2
  %482 = insertelement <4 x float> zeroinitializer, float %481, i64 0
  %483 = insertelement <4 x float> %478, float %477, i64 1
  %484 = insertelement <4 x float> %480, float %479, i64 1
  %485 = insertelement <4 x float> %482, float %481, i64 1
  %486 = insertelement <4 x float> %483, float %477, i64 2
  %487 = insertelement <4 x float> %484, float %479, i64 2
  %488 = insertelement <4 x float> %485, float %481, i64 2
  %489 = insertelement <4 x float> %486, float %477, i64 3
  %490 = insertelement <4 x float> %487, float %479, i64 3
  %491 = insertelement <4 x float> %488, float %481, i64 3
  %492 = fdiv <4 x float> %491, %489
  %493 = insertelement <4 x float> undef, float %80, i32 0
  %494 = shufflevector <4 x float> %493, <4 x float> undef, <4 x i32> zeroinitializer
  %495 = fadd contract <4 x float> %492, %494
  %496 = extractelement <4 x float> %495, i64 3
  %497 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %496)
  %498 = extractelement <4 x float> %495, i64 2
  %499 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %498)
  %500 = extractelement <4 x float> %495, i64 1
  %501 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %500)
  %502 = extractelement <4 x float> %495, i64 0
  %503 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %502)
  %504 = insertelement <4 x float> zeroinitializer, float %503, i64 0
  %505 = insertelement <4 x float> %504, float %501, i64 1
  %506 = insertelement <4 x float> %505, float %499, i64 2
  %507 = insertelement <4 x float> %506, float %497, i64 3
  %508 = load { ptr, { { i64 }, { {} } } }, ptr %22, align 8
  %509 = extractvalue { ptr, { { i64 }, { {} } } } %508, 0
  %510 = extractvalue { ptr, { { i64 }, { {} } } } %78, 0
  %511 = extractvalue { ptr, { { i64 }, { {} } } } %79, 0
  %512 = extractelement <4 x float> %490, i64 0
  %513 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %490, i64 0)
  %514 = extractelement <4 x float> %507, i64 0
  %515 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %507, i64 0)
  br label %516

516:                                              ; preds = %627, %471
  %517 = phi i64 [ 0, %471 ], [ %628, %627 ]
  %518 = phi i64 [ 0, %471 ], [ %527, %627 ]
  %519 = phi i64 [ 0, %471 ], [ %528, %627 ]
  %520 = add i64 %518, 512
  %521 = icmp slt i64 %520, %518
  %522 = select i1 %521, i64 1, i64 0
  %523 = icmp sge i64 %518, %77
  %524 = icmp eq i64 %519, 0
  %525 = xor i1 %524, true
  %526 = or i1 %525, %523
  %527 = select i1 %526, i64 %518, i64 %520
  %528 = select i1 %526, i64 %519, i64 %522
  br i1 %526, label %529, label %530

529:                                              ; preds = %516
  br label %629

530:                                              ; preds = %516
  br label %531

531:                                              ; preds = %530
  %532 = add i64 %518, %36
  %533 = getelementptr inbounds float, ptr %509, i64 %532
  %534 = getelementptr inbounds float, ptr %511, i64 %532
  %535 = ptrtoint ptr %534 to i64
  %536 = insertelement <4 x i64> undef, i64 %535, i32 0
  %537 = shufflevector <4 x i64> %536, <4 x i64> undef, <4 x i32> zeroinitializer
  %538 = add <4 x i64> %537, %30
  %539 = extractelement <4 x i64> %538, i64 1
  %540 = extractelement <4 x i64> %538, i64 3
  %541 = extractelement <4 x i64> %538, i64 2
  %542 = extractelement <4 x i64> %538, i64 0
  %543 = getelementptr inbounds float, ptr %510, i64 %532
  %544 = ptrtoint ptr %543 to i64
  %545 = insertelement <4 x i64> undef, i64 %544, i32 0
  %546 = shufflevector <4 x i64> %545, <4 x i64> undef, <4 x i32> zeroinitializer
  %547 = add <4 x i64> %546, %30
  %548 = extractelement <4 x i64> %547, i64 1
  %549 = extractelement <4 x i64> %547, i64 3
  %550 = extractelement <4 x i64> %547, i64 2
  %551 = extractelement <4 x i64> %547, i64 0
  %552 = getelementptr inbounds float, ptr %82, i64 %532
  %553 = sub i64 %77, %532
  %554 = call i64 @llvm.smin.i64(i64 %553, i64 4)
  %555 = call i64 @llvm.smax.i64(i64 %554, i64 0)
  %556 = icmp eq i64 %554, 4
  %557 = icmp slt i64 %532, %77
  br i1 %557, label %558, label %626

558:                                              ; preds = %531
  br i1 %556, label %559, label %599

559:                                              ; preds = %558
  %560 = load <4 x float>, ptr %552, align 16
  br i1 %28, label %561, label %563

561:                                              ; preds = %559
  %562 = load <4 x float>, ptr %543, align 4, !invariant.load !1
  br label %576

563:                                              ; preds = %559
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %551, ptr %9, align 8
  %564 = load ptr, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %565 = load float, ptr %564, align 4, !invariant.load !1
  %566 = insertelement <4 x float> zeroinitializer, float %565, i64 0
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %548, ptr %8, align 8
  %567 = load ptr, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %568 = load float, ptr %567, align 4, !invariant.load !1
  %569 = insertelement <4 x float> %566, float %568, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %550, ptr %7, align 8
  %570 = load ptr, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %571 = load float, ptr %570, align 4, !invariant.load !1
  %572 = insertelement <4 x float> %569, float %571, i64 2
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store i64 %549, ptr %6, align 8
  %573 = load ptr, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %574 = load float, ptr %573, align 4, !invariant.load !1
  %575 = insertelement <4 x float> %572, float %574, i64 3
  br label %576

576:                                              ; preds = %563, %561
  %577 = phi <4 x float> [ %575, %563 ], [ %562, %561 ]
  br i1 %28, label %578, label %580

578:                                              ; preds = %576
  %579 = load <4 x float>, ptr %534, align 4, !invariant.load !1
  br label %593

580:                                              ; preds = %576
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %542, ptr %5, align 8
  %581 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %582 = load float, ptr %581, align 4, !invariant.load !1
  %583 = insertelement <4 x float> zeroinitializer, float %582, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %539, ptr %4, align 8
  %584 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %585 = load float, ptr %584, align 4, !invariant.load !1
  %586 = insertelement <4 x float> %583, float %585, i64 1
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %541, ptr %3, align 8
  %587 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %588 = load float, ptr %587, align 4, !invariant.load !1
  %589 = insertelement <4 x float> %586, float %588, i64 2
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %540, ptr %2, align 8
  %590 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %591 = load float, ptr %590, align 4, !invariant.load !1
  %592 = insertelement <4 x float> %589, float %591, i64 3
  br label %593

593:                                              ; preds = %580, %578
  %594 = phi <4 x float> [ %592, %580 ], [ %579, %578 ]
  %595 = fsub contract <4 x float> %560, %513
  %596 = fmul contract <4 x float> %595, %515
  %597 = fmul contract <4 x float> %596, %577
  %598 = fadd contract <4 x float> %597, %594
  store <4 x float> %598, ptr %533, align 16
  br label %624

599:                                              ; preds = %558
  br label %600

600:                                              ; preds = %606, %599
  %601 = phi i64 [ 0, %599 ], [ %609, %606 ]
  %602 = phi i64 [ %517, %599 ], [ %610, %606 ]
  %603 = icmp slt i64 %601, %555
  br i1 %603, label %604, label %605

604:                                              ; preds = %600
  br label %606

605:                                              ; preds = %600
  br label %622

606:                                              ; preds = %604
  %607 = icmp eq i64 %601, %555
  %608 = add i64 %601, 1
  %609 = select i1 %607, i64 %601, i64 %608
  %610 = add i64 %532, %601
  %611 = getelementptr inbounds float, ptr %82, i64 %610
  %612 = load float, ptr %611, align 4
  %613 = getelementptr inbounds float, ptr %510, i64 %610
  %614 = load float, ptr %613, align 4, !invariant.load !1
  %615 = getelementptr inbounds float, ptr %511, i64 %610
  %616 = load float, ptr %615, align 4, !invariant.load !1
  %617 = fsub contract float %612, %512
  %618 = fmul contract float %617, %514
  %619 = fmul contract float %618, %614
  %620 = fadd contract float %619, %616
  %621 = getelementptr inbounds float, ptr %509, i64 %610
  store float %620, ptr %621, align 4
  br label %600

622:                                              ; preds = %605
  %623 = phi i64 [ %602, %605 ]
  br label %624

624:                                              ; preds = %622, %593
  %625 = phi i64 [ %623, %622 ], [ %532, %593 ]
  br label %627

626:                                              ; preds = %531
  br label %627

627:                                              ; preds = %626, %624
  %628 = phi i64 [ %517, %626 ], [ %625, %624 ]
  br label %516

629:                                              ; preds = %529
  br label %48

630:                                              ; preds = %74
  ret void
}

define internal { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } noundef %0) #1 {
  %2 = extractvalue { <4 x float>, <4 x float>, <4 x float> } %0, 0
  %3 = extractelement <4 x float> %2, i64 0
  %4 = extractvalue { <4 x float>, <4 x float>, <4 x float> } %0, 1
  %5 = extractelement <4 x float> %4, i64 0
  %6 = extractvalue { <4 x float>, <4 x float>, <4 x float> } %0, 2
  %7 = extractelement <4 x float> %6, i64 0
  %8 = extractelement <4 x float> %2, i64 1
  %9 = extractelement <4 x float> %4, i64 1
  %10 = extractelement <4 x float> %6, i64 1
  %11 = fadd contract float %3, %8
  %12 = call float @llvm.maxnum.f32(float %11, float 1.000000e+00)
  %13 = fsub contract float %9, %5
  %14 = fdiv float %8, %12
  %15 = fadd contract float %7, %10
  %16 = fmul contract float %13, %13
  %17 = fmul contract float %16, %3
  %18 = fmul contract float %17, %14
  %19 = fadd contract float %15, %18
  %20 = fmul contract float %13, %14
  %21 = fadd contract float %5, %20
  %22 = extractelement <4 x float> %2, i64 2
  %23 = extractelement <4 x float> %4, i64 2
  %24 = extractelement <4 x float> %6, i64 2
  %25 = fadd contract float %11, %22
  %26 = call float @llvm.maxnum.f32(float %25, float 1.000000e+00)
  %27 = fsub contract float %23, %21
  %28 = fdiv float %22, %26
  %29 = fadd contract float %19, %24
  %30 = fmul contract float %27, %27
  %31 = fmul contract float %30, %11
  %32 = fmul contract float %31, %28
  %33 = fadd contract float %29, %32
  %34 = fmul contract float %27, %28
  %35 = fadd contract float %21, %34
  %36 = extractelement <4 x float> %2, i64 3
  %37 = extractelement <4 x float> %4, i64 3
  %38 = extractelement <4 x float> %6, i64 3
  %39 = fadd contract float %25, %36
  %40 = call float @llvm.maxnum.f32(float %39, float 1.000000e+00)
  %41 = fsub contract float %37, %35
  %42 = fdiv float %36, %40
  %43 = fadd contract float %33, %38
  %44 = fmul contract float %41, %41
  %45 = fmul contract float %44, %25
  %46 = fmul contract float %45, %42
  %47 = fadd contract float %43, %46
  %48 = fmul contract float %41, %42
  %49 = fadd contract float %35, %48
  %50 = insertvalue { float, float, float } undef, float %39, 0
  %51 = insertvalue { float, float, float } %50, float %49, 1
  %52 = insertvalue { float, float, float } %51, float %47, 2
  ret { float, float, float } %52
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i1 @llvm.vector.reduce.and.v4i1(<4 x i1>) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <4 x i64> @llvm.stepvector.v4i64() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, -2147483648) i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #4

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x float> @llvm.maxnum.v4f32(<4 x float>, <4 x float>) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #5

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #5

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #6

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #2

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #7

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none)
declare float @llvm.nvvm.rsqrt.approx.ftz.f(float) #8

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float>, i64 immarg) #4

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #6 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #7 = { convergent nocallback nounwind }
attributes #8 = { nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
