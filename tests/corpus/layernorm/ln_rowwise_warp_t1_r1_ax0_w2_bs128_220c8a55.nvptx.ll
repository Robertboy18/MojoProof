; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r1_ax0_w2_bs128_220c8a55(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
  %2 = alloca i64, i64 1, align 8
  %3 = alloca i64, i64 1, align 8
  %4 = alloca i64, i64 1, align 8
  %5 = alloca i64, i64 1, align 8
  %6 = alloca { float, float, float }, i64 1, align 4
  %7 = alloca { float, float, float }, i64 1, align 4
  %8 = alloca { float, float, float }, i64 1, align 4
  %9 = alloca { float, float, float }, i64 1, align 4
  %10 = alloca { float, float, float }, i64 1, align 4
  %11 = alloca { float, float, float }, i64 1, align 4
  %12 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %13 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %12, i32 0, i32 5
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %12, i32 0, i32 4
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %12, i32 0, i32 3
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %12, i32 0, i32 2
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %12, i32 0, i32 1
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %12, i32 0, i32 0
  %19 = call i1 @llvm.vector.reduce.and.v2i1(<2 x i1> splat (i1 true))
  %20 = call <2 x i64> @llvm.stepvector.v2i64()
  %21 = mul <2 x i64> %20, splat (i64 4)
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %23 = sext i32 %22 to i64
  %24 = mul i64 %23, 2
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %26 = zext i32 %25 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %28 = zext i32 %27 to i64
  %29 = mul i64 %28, 4
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %31 = sext i32 %30 to i64
  %32 = mul i64 %31, 4
  %33 = icmp eq i64 %32, 0
  %34 = select i1 %33, i64 0, i64 %29
  %35 = select i1 %33, i64 0, i64 1
  %36 = select i1 %33, i64 1, i64 %32
  %37 = icmp slt i64 %36, 0
  %38 = icmp sgt i64 %36, 0
  br label %39

39:                                               ; preds = %458, %1
  %40 = phi i64 [ %34, %1 ], [ %64, %458 ]
  %41 = phi i64 [ 0, %1 ], [ %65, %458 ]
  %42 = icmp sge i64 %35, %40
  %43 = icmp sge i64 %40, %35
  %44 = add i64 %40, %36
  %45 = icmp slt i64 %44, %40
  %46 = xor i1 %45, %37
  %47 = select i1 %46, i64 1, i64 0
  %48 = icmp eq i64 %41, 0
  %49 = xor i1 %48, true
  %50 = or i1 %49, %42
  %51 = or i1 %49, %43
  br label %52

52:                                               ; preds = %39
  br i1 %38, label %53, label %58

53:                                               ; preds = %52
  br i1 %51, label %54, label %55

54:                                               ; preds = %53
  br label %61

55:                                               ; preds = %53
  br label %56

56:                                               ; preds = %55
  br label %60

57:                                               ; preds = %58
  br label %60

58:                                               ; preds = %52
  br i1 %50, label %59, label %57

59:                                               ; preds = %58
  br label %61

60:                                               ; preds = %57, %56
  br label %61

61:                                               ; preds = %60, %59, %54
  %62 = phi i1 [ true, %54 ], [ true, %59 ], [ false, %60 ]
  %63 = phi i64 [ undef, %54 ], [ undef, %59 ], [ %40, %60 ]
  %64 = phi i64 [ %40, %54 ], [ %40, %59 ], [ %44, %60 ]
  %65 = phi i64 [ %41, %54 ], [ %41, %59 ], [ %47, %60 ]
  br i1 %62, label %66, label %67

66:                                               ; preds = %61
  br label %459

67:                                               ; preds = %61
  br label %68

68:                                               ; preds = %67
  %69 = udiv i64 %26, 32
  %70 = add i64 %63, %69
  %71 = icmp slt i64 %70, 1
  br i1 %71, label %72, label %457

72:                                               ; preds = %68
  %73 = load i64, ptr %18, align 8
  %74 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %75 = load { ptr, { { i64 }, { {} } } }, ptr %16, align 8
  %76 = load float, ptr %15, align 4
  %77 = load { ptr, { { i64 }, { {} } } }, ptr %14, align 8
  %78 = extractvalue { ptr, { { i64 }, { {} } } } %77, 0
  br label %79

79:                                               ; preds = %159, %72
  %80 = phi i64 [ 0, %72 ], [ %160, %159 ]
  %81 = phi i64 [ 0, %72 ], [ %95, %159 ]
  %82 = phi i64 [ 0, %72 ], [ %96, %159 ]
  %83 = phi <2 x float> [ zeroinitializer, %72 ], [ %161, %159 ]
  %84 = phi <2 x float> [ zeroinitializer, %72 ], [ %162, %159 ]
  %85 = phi <2 x float> [ zeroinitializer, %72 ], [ %163, %159 ]
  %86 = fadd contract <2 x float> %83, splat (float 1.000000e+00)
  %87 = extractelement <2 x float> %86, i64 0
  %88 = add i64 %81, 64
  %89 = icmp slt i64 %88, %81
  %90 = select i1 %89, i64 1, i64 0
  %91 = icmp sge i64 %81, %73
  %92 = icmp eq i64 %82, 0
  %93 = xor i1 %92, true
  %94 = or i1 %93, %91
  %95 = select i1 %94, i64 %81, i64 %88
  %96 = select i1 %94, i64 %82, i64 %90
  br i1 %94, label %97, label %98

97:                                               ; preds = %79
  br label %164

98:                                               ; preds = %79
  br label %99

99:                                               ; preds = %98
  %100 = add i64 %81, %24
  %101 = getelementptr inbounds float, ptr %78, i64 %100
  %102 = sub i64 %73, %100
  %103 = call i64 @llvm.smin.i64(i64 %102, i64 2)
  %104 = call i64 @llvm.smax.i64(i64 %103, i64 0)
  %105 = icmp eq i64 %103, 2
  %106 = icmp slt i64 %100, %73
  br i1 %106, label %107, label %158

107:                                              ; preds = %99
  br i1 %105, label %108, label %120

108:                                              ; preds = %107
  %109 = load <2 x float>, ptr %101, align 8
  %110 = fsub contract <2 x float> %109, %84
  %111 = fdiv float 1.000000e+00, %87
  %112 = insertelement <2 x float> undef, float %111, i32 0
  %113 = shufflevector <2 x float> %112, <2 x float> undef, <2 x i32> zeroinitializer
  %114 = fmul contract <2 x float> %110, %113
  %115 = fadd contract <2 x float> %84, %114
  %116 = fmul contract <2 x float> %110, %110
  %117 = fmul contract <2 x float> %116, %83
  %118 = fmul contract <2 x float> %117, %113
  %119 = fadd contract <2 x float> %85, %118
  br label %153

120:                                              ; preds = %107
  br label %121

121:                                              ; preds = %130, %120
  %122 = phi i64 [ 0, %120 ], [ %133, %130 ]
  %123 = phi i64 [ %80, %120 ], [ %134, %130 ]
  %124 = phi <2 x float> [ %83, %120 ], [ %138, %130 ]
  %125 = phi <2 x float> [ %84, %120 ], [ %143, %130 ]
  %126 = phi <2 x float> [ %85, %120 ], [ %147, %130 ]
  %127 = icmp slt i64 %122, %104
  br i1 %127, label %128, label %129

128:                                              ; preds = %121
  br label %130

129:                                              ; preds = %121
  br label %148

130:                                              ; preds = %128
  %131 = icmp eq i64 %122, %104
  %132 = add i64 %122, 1
  %133 = select i1 %131, i64 %122, i64 %132
  %134 = add i64 %100, %122
  %135 = getelementptr inbounds float, ptr %78, i64 %134
  %136 = load float, ptr %135, align 4
  %137 = insertelement <2 x float> zeroinitializer, float %136, i64 0
  %138 = fadd contract <2 x float> %124, <float 1.000000e+00, float 0.000000e+00>
  %139 = fsub contract <2 x float> %137, %125
  %140 = call <2 x float> @llvm.maxnum.v2f32(<2 x float> %138, <2 x float> splat (float 1.000000e+00))
  %141 = fdiv <2 x float> <float 1.000000e+00, float 0.000000e+00>, %140
  %142 = fmul contract <2 x float> %139, %141
  %143 = fadd contract <2 x float> %125, %142
  %144 = fmul contract <2 x float> %139, %139
  %145 = fmul contract <2 x float> %144, %124
  %146 = fmul contract <2 x float> %145, %141
  %147 = fadd contract <2 x float> %126, %146
  br label %121

148:                                              ; preds = %129
  %149 = phi i64 [ %123, %129 ]
  %150 = phi <2 x float> [ %124, %129 ]
  %151 = phi <2 x float> [ %125, %129 ]
  %152 = phi <2 x float> [ %126, %129 ]
  br label %153

153:                                              ; preds = %148, %108
  %154 = phi i64 [ %149, %148 ], [ %100, %108 ]
  %155 = phi <2 x float> [ %150, %148 ], [ %86, %108 ]
  %156 = phi <2 x float> [ %151, %148 ], [ %115, %108 ]
  %157 = phi <2 x float> [ %152, %148 ], [ %119, %108 ]
  br label %159

158:                                              ; preds = %99
  br label %159

159:                                              ; preds = %158, %153
  %160 = phi i64 [ %80, %158 ], [ %154, %153 ]
  %161 = phi <2 x float> [ %83, %158 ], [ %155, %153 ]
  %162 = phi <2 x float> [ %84, %158 ], [ %156, %153 ]
  %163 = phi <2 x float> [ %85, %158 ], [ %157, %153 ]
  br label %79

164:                                              ; preds = %97
  %165 = phi <2 x float> [ %83, %97 ]
  %166 = phi <2 x float> [ %84, %97 ]
  %167 = phi <2 x float> [ %85, %97 ]
  %168 = extractelement <2 x float> %165, i64 0
  %169 = extractelement <2 x float> %166, i64 0
  %170 = extractelement <2 x float> %167, i64 0
  %171 = extractelement <2 x float> %165, i64 1
  %172 = extractelement <2 x float> %166, i64 1
  %173 = extractelement <2 x float> %167, i64 1
  %174 = fadd contract float %168, %171
  %175 = call float @llvm.maxnum.f32(float %174, float 1.000000e+00)
  %176 = fsub contract float %172, %169
  %177 = fdiv float %171, %175
  %178 = fadd contract float %170, %173
  %179 = fmul contract float %176, %176
  %180 = fmul contract float %179, %168
  %181 = fmul contract float %180, %177
  %182 = fadd contract float %178, %181
  %183 = fmul contract float %176, %177
  %184 = fadd contract float %169, %183
  %185 = insertvalue { float, float, float } undef, float %174, 0
  %186 = insertvalue { float, float, float } %185, float %184, 1
  %187 = insertvalue { float, float, float } %186, float %182, 2
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } %187, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %188 = load i32, ptr %11, align 4
  %189 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %188, i32 16, i32 31)
  store i32 %189, ptr %10, align 4
  %190 = getelementptr inbounds i32, ptr %10, i32 1
  %191 = getelementptr inbounds i32, ptr %11, i32 1
  %192 = load i32, ptr %191, align 4
  %193 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %192, i32 16, i32 31)
  store i32 %193, ptr %190, align 4
  %194 = getelementptr inbounds i32, ptr %10, i32 2
  %195 = getelementptr inbounds i32, ptr %11, i32 2
  %196 = load i32, ptr %195, align 4
  %197 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %196, i32 16, i32 31)
  store i32 %197, ptr %194, align 4
  %198 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %199 = getelementptr { float, float, float }, ptr %11, i32 0, i32 0
  %200 = load float, ptr %199, align 4
  %201 = extractvalue { float, float, float } %198, 0
  %202 = fadd contract float %200, %201
  %203 = call float @llvm.maxnum.f32(float %202, float 1.000000e+00)
  %204 = extractvalue { float, float, float } %198, 1
  %205 = getelementptr { float, float, float }, ptr %11, i32 0, i32 1
  %206 = load float, ptr %205, align 4
  %207 = fsub contract float %204, %206
  %208 = fdiv float %201, %203
  %209 = getelementptr { float, float, float }, ptr %11, i32 0, i32 2
  %210 = extractvalue { float, float, float } %198, 2
  %211 = load float, ptr %209, align 4
  %212 = fadd contract float %211, %210
  %213 = fmul contract float %207, %207
  %214 = fmul contract float %213, %200
  %215 = fmul contract float %214, %208
  %216 = fadd contract float %212, %215
  store float %216, ptr %209, align 4
  %217 = fmul contract float %207, %208
  %218 = load float, ptr %205, align 4
  %219 = fadd contract float %218, %217
  store float %219, ptr %205, align 4
  store float %202, ptr %199, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %220 = load i32, ptr %11, align 4
  %221 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %220, i32 8, i32 31)
  store i32 %221, ptr %9, align 4
  %222 = getelementptr inbounds i32, ptr %9, i32 1
  %223 = load i32, ptr %191, align 4
  %224 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %223, i32 8, i32 31)
  store i32 %224, ptr %222, align 4
  %225 = getelementptr inbounds i32, ptr %9, i32 2
  %226 = load i32, ptr %195, align 4
  %227 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %226, i32 8, i32 31)
  store i32 %227, ptr %225, align 4
  %228 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %229 = load float, ptr %199, align 4
  %230 = extractvalue { float, float, float } %228, 0
  %231 = fadd contract float %229, %230
  %232 = call float @llvm.maxnum.f32(float %231, float 1.000000e+00)
  %233 = extractvalue { float, float, float } %228, 1
  %234 = load float, ptr %205, align 4
  %235 = fsub contract float %233, %234
  %236 = fdiv float %230, %232
  %237 = extractvalue { float, float, float } %228, 2
  %238 = load float, ptr %209, align 4
  %239 = fadd contract float %238, %237
  %240 = fmul contract float %235, %235
  %241 = fmul contract float %240, %229
  %242 = fmul contract float %241, %236
  %243 = fadd contract float %239, %242
  store float %243, ptr %209, align 4
  %244 = fmul contract float %235, %236
  %245 = load float, ptr %205, align 4
  %246 = fadd contract float %245, %244
  store float %246, ptr %205, align 4
  store float %231, ptr %199, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %247 = load i32, ptr %11, align 4
  %248 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %247, i32 4, i32 31)
  store i32 %248, ptr %8, align 4
  %249 = getelementptr inbounds i32, ptr %8, i32 1
  %250 = load i32, ptr %191, align 4
  %251 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %250, i32 4, i32 31)
  store i32 %251, ptr %249, align 4
  %252 = getelementptr inbounds i32, ptr %8, i32 2
  %253 = load i32, ptr %195, align 4
  %254 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %253, i32 4, i32 31)
  store i32 %254, ptr %252, align 4
  %255 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %256 = load float, ptr %199, align 4
  %257 = extractvalue { float, float, float } %255, 0
  %258 = fadd contract float %256, %257
  %259 = call float @llvm.maxnum.f32(float %258, float 1.000000e+00)
  %260 = extractvalue { float, float, float } %255, 1
  %261 = load float, ptr %205, align 4
  %262 = fsub contract float %260, %261
  %263 = fdiv float %257, %259
  %264 = extractvalue { float, float, float } %255, 2
  %265 = load float, ptr %209, align 4
  %266 = fadd contract float %265, %264
  %267 = fmul contract float %262, %262
  %268 = fmul contract float %267, %256
  %269 = fmul contract float %268, %263
  %270 = fadd contract float %266, %269
  store float %270, ptr %209, align 4
  %271 = fmul contract float %262, %263
  %272 = load float, ptr %205, align 4
  %273 = fadd contract float %272, %271
  store float %273, ptr %205, align 4
  store float %258, ptr %199, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %274 = load i32, ptr %11, align 4
  %275 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %274, i32 2, i32 31)
  store i32 %275, ptr %7, align 4
  %276 = getelementptr inbounds i32, ptr %7, i32 1
  %277 = load i32, ptr %191, align 4
  %278 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %277, i32 2, i32 31)
  store i32 %278, ptr %276, align 4
  %279 = getelementptr inbounds i32, ptr %7, i32 2
  %280 = load i32, ptr %195, align 4
  %281 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %280, i32 2, i32 31)
  store i32 %281, ptr %279, align 4
  %282 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %283 = load float, ptr %199, align 4
  %284 = extractvalue { float, float, float } %282, 0
  %285 = fadd contract float %283, %284
  %286 = call float @llvm.maxnum.f32(float %285, float 1.000000e+00)
  %287 = extractvalue { float, float, float } %282, 1
  %288 = load float, ptr %205, align 4
  %289 = fsub contract float %287, %288
  %290 = fdiv float %284, %286
  %291 = extractvalue { float, float, float } %282, 2
  %292 = load float, ptr %209, align 4
  %293 = fadd contract float %292, %291
  %294 = fmul contract float %289, %289
  %295 = fmul contract float %294, %283
  %296 = fmul contract float %295, %290
  %297 = fadd contract float %293, %296
  store float %297, ptr %209, align 4
  %298 = fmul contract float %289, %290
  %299 = load float, ptr %205, align 4
  %300 = fadd contract float %299, %298
  store float %300, ptr %205, align 4
  store float %285, ptr %199, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %301 = load i32, ptr %11, align 4
  %302 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %301, i32 1, i32 31)
  store i32 %302, ptr %6, align 4
  %303 = getelementptr inbounds i32, ptr %6, i32 1
  %304 = load i32, ptr %191, align 4
  %305 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %304, i32 1, i32 31)
  store i32 %305, ptr %303, align 4
  %306 = getelementptr inbounds i32, ptr %6, i32 2
  %307 = load i32, ptr %195, align 4
  %308 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %307, i32 1, i32 31)
  store i32 %308, ptr %306, align 4
  %309 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %310 = load float, ptr %199, align 4
  %311 = extractvalue { float, float, float } %309, 0
  %312 = fadd contract float %310, %311
  %313 = call float @llvm.maxnum.f32(float %312, float 1.000000e+00)
  %314 = extractvalue { float, float, float } %309, 1
  %315 = load float, ptr %205, align 4
  %316 = fsub contract float %314, %315
  %317 = fdiv float %311, %313
  %318 = extractvalue { float, float, float } %309, 2
  %319 = load float, ptr %209, align 4
  %320 = fadd contract float %319, %318
  %321 = fmul contract float %316, %316
  %322 = fmul contract float %321, %310
  %323 = fmul contract float %322, %317
  %324 = fadd contract float %320, %323
  store float %324, ptr %209, align 4
  %325 = fmul contract float %316, %317
  %326 = load float, ptr %205, align 4
  %327 = fadd contract float %326, %325
  store float %327, ptr %205, align 4
  store float %312, ptr %199, align 4
  %328 = load float, ptr %205, align 4
  store float %328, ptr %205, align 4
  %329 = load float, ptr %209, align 4
  store float %329, ptr %209, align 4
  %330 = load float, ptr %199, align 4
  store float %330, ptr %199, align 4
  %331 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %332 = extractvalue { float, float, float } %331, 0
  %333 = insertelement <2 x float> zeroinitializer, float %332, i64 0
  %334 = extractvalue { float, float, float } %331, 1
  %335 = insertelement <2 x float> zeroinitializer, float %334, i64 0
  %336 = extractvalue { float, float, float } %331, 2
  %337 = insertelement <2 x float> zeroinitializer, float %336, i64 0
  %338 = insertelement <2 x float> %333, float %332, i64 1
  %339 = insertelement <2 x float> %335, float %334, i64 1
  %340 = insertelement <2 x float> %337, float %336, i64 1
  %341 = fdiv <2 x float> %340, %338
  %342 = insertelement <2 x float> undef, float %76, i32 0
  %343 = shufflevector <2 x float> %342, <2 x float> undef, <2 x i32> zeroinitializer
  %344 = fadd contract <2 x float> %341, %343
  %345 = extractelement <2 x float> %344, i64 1
  %346 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %345)
  %347 = extractelement <2 x float> %344, i64 0
  %348 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %347)
  %349 = insertelement <2 x float> zeroinitializer, float %348, i64 0
  %350 = insertelement <2 x float> %349, float %346, i64 1
  %351 = load { ptr, { { i64 }, { {} } } }, ptr %13, align 8
  %352 = extractvalue { ptr, { { i64 }, { {} } } } %351, 0
  %353 = extractvalue { ptr, { { i64 }, { {} } } } %74, 0
  %354 = extractvalue { ptr, { { i64 }, { {} } } } %75, 0
  %355 = extractelement <2 x float> %339, i64 0
  %356 = call <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float> %339, i64 0)
  %357 = extractelement <2 x float> %350, i64 0
  %358 = call <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float> %350, i64 0)
  br label %359

359:                                              ; preds = %454, %164
  %360 = phi i64 [ 0, %164 ], [ %455, %454 ]
  %361 = phi i64 [ 0, %164 ], [ %370, %454 ]
  %362 = phi i64 [ 0, %164 ], [ %371, %454 ]
  %363 = add i64 %361, 64
  %364 = icmp slt i64 %363, %361
  %365 = select i1 %364, i64 1, i64 0
  %366 = icmp sge i64 %361, %73
  %367 = icmp eq i64 %362, 0
  %368 = xor i1 %367, true
  %369 = or i1 %368, %366
  %370 = select i1 %369, i64 %361, i64 %363
  %371 = select i1 %369, i64 %362, i64 %365
  br i1 %369, label %372, label %373

372:                                              ; preds = %359
  br label %456

373:                                              ; preds = %359
  br label %374

374:                                              ; preds = %373
  %375 = add i64 %361, %24
  %376 = getelementptr inbounds float, ptr %352, i64 %375
  %377 = getelementptr inbounds float, ptr %354, i64 %375
  %378 = ptrtoint ptr %377 to i64
  %379 = insertelement <2 x i64> undef, i64 %378, i32 0
  %380 = shufflevector <2 x i64> %379, <2 x i64> undef, <2 x i32> zeroinitializer
  %381 = add <2 x i64> %380, %21
  %382 = extractelement <2 x i64> %381, i64 1
  %383 = extractelement <2 x i64> %381, i64 0
  %384 = getelementptr inbounds float, ptr %353, i64 %375
  %385 = ptrtoint ptr %384 to i64
  %386 = insertelement <2 x i64> undef, i64 %385, i32 0
  %387 = shufflevector <2 x i64> %386, <2 x i64> undef, <2 x i32> zeroinitializer
  %388 = add <2 x i64> %387, %21
  %389 = extractelement <2 x i64> %388, i64 1
  %390 = extractelement <2 x i64> %388, i64 0
  %391 = getelementptr inbounds float, ptr %78, i64 %375
  %392 = sub i64 %73, %375
  %393 = call i64 @llvm.smin.i64(i64 %392, i64 2)
  %394 = call i64 @llvm.smax.i64(i64 %393, i64 0)
  %395 = icmp eq i64 %393, 2
  %396 = icmp slt i64 %375, %73
  br i1 %396, label %397, label %453

397:                                              ; preds = %374
  br i1 %395, label %398, label %426

398:                                              ; preds = %397
  %399 = load <2 x float>, ptr %391, align 8
  br i1 %19, label %400, label %402

400:                                              ; preds = %398
  %401 = load <2 x float>, ptr %384, align 2, !invariant.load !1
  br label %409

402:                                              ; preds = %398
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %390, ptr %5, align 8
  %403 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %404 = load float, ptr %403, align 4, !invariant.load !1
  %405 = insertelement <2 x float> zeroinitializer, float %404, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %389, ptr %4, align 8
  %406 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %407 = load float, ptr %406, align 4, !invariant.load !1
  %408 = insertelement <2 x float> %405, float %407, i64 1
  br label %409

409:                                              ; preds = %402, %400
  %410 = phi <2 x float> [ %408, %402 ], [ %401, %400 ]
  br i1 %19, label %411, label %413

411:                                              ; preds = %409
  %412 = load <2 x float>, ptr %377, align 2, !invariant.load !1
  br label %420

413:                                              ; preds = %409
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %383, ptr %3, align 8
  %414 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %415 = load float, ptr %414, align 4, !invariant.load !1
  %416 = insertelement <2 x float> zeroinitializer, float %415, i64 0
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %382, ptr %2, align 8
  %417 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %418 = load float, ptr %417, align 4, !invariant.load !1
  %419 = insertelement <2 x float> %416, float %418, i64 1
  br label %420

420:                                              ; preds = %413, %411
  %421 = phi <2 x float> [ %419, %413 ], [ %412, %411 ]
  %422 = fsub contract <2 x float> %399, %356
  %423 = fmul contract <2 x float> %422, %358
  %424 = fmul contract <2 x float> %423, %410
  %425 = fadd contract <2 x float> %424, %421
  store <2 x float> %425, ptr %376, align 8
  br label %451

426:                                              ; preds = %397
  br label %427

427:                                              ; preds = %433, %426
  %428 = phi i64 [ 0, %426 ], [ %436, %433 ]
  %429 = phi i64 [ %360, %426 ], [ %437, %433 ]
  %430 = icmp slt i64 %428, %394
  br i1 %430, label %431, label %432

431:                                              ; preds = %427
  br label %433

432:                                              ; preds = %427
  br label %449

433:                                              ; preds = %431
  %434 = icmp eq i64 %428, %394
  %435 = add i64 %428, 1
  %436 = select i1 %434, i64 %428, i64 %435
  %437 = add i64 %375, %428
  %438 = getelementptr inbounds float, ptr %78, i64 %437
  %439 = load float, ptr %438, align 4
  %440 = getelementptr inbounds float, ptr %353, i64 %437
  %441 = load float, ptr %440, align 4, !invariant.load !1
  %442 = getelementptr inbounds float, ptr %354, i64 %437
  %443 = load float, ptr %442, align 4, !invariant.load !1
  %444 = fsub contract float %439, %355
  %445 = fmul contract float %444, %357
  %446 = fmul contract float %445, %441
  %447 = fadd contract float %446, %443
  %448 = getelementptr inbounds float, ptr %352, i64 %437
  store float %447, ptr %448, align 4
  br label %427

449:                                              ; preds = %432
  %450 = phi i64 [ %429, %432 ]
  br label %451

451:                                              ; preds = %449, %420
  %452 = phi i64 [ %450, %449 ], [ %375, %420 ]
  br label %454

453:                                              ; preds = %374
  br label %454

454:                                              ; preds = %453, %451
  %455 = phi i64 [ %360, %453 ], [ %452, %451 ]
  br label %359

456:                                              ; preds = %372
  br label %458

457:                                              ; preds = %68
  br label %458

458:                                              ; preds = %457, %456
  br label %39

459:                                              ; preds = %66
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i1 @llvm.vector.reduce.and.v2i1(<2 x i1>) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <2 x i64> @llvm.stepvector.v2i64() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, -2147483648) i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x float> @llvm.maxnum.v2f32(<2 x float>, <2 x float>) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #4

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #5

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none)
declare float @llvm.nvvm.rsqrt.approx.ftz.f(float) #6

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float>, i64 immarg) #3

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #6 = { nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
