; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r2_ax1_w2_bs128_72863918(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %12 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %13 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %12, i32 0, i32 5
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %12, i32 0, i32 4
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %12, i32 0, i32 3
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %12, i32 0, i32 2
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %12, i32 0, i32 1
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %12, i32 0, i32 0
  %19 = call i1 @llvm.vector.reduce.and.v2i1(<2 x i1> splat (i1 true))
  %20 = call <2 x i64> @llvm.stepvector.v2i64()
  %21 = mul <2 x i64> %20, splat (i64 4)
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %23 = sext i32 %22 to i64
  %24 = mul i64 %23, 2
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %26 = zext i32 %25 to i64
  %27 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %28 = load { i64, i64 }, ptr %27, align 8
  %29 = extractvalue { i64, i64 } %28, 0
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %31 = zext i32 %30 to i64
  %32 = mul i64 %31, 4
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %34 = sext i32 %33 to i64
  %35 = mul i64 %34, 4
  %36 = icmp eq i64 %35, 0
  %37 = select i1 %36, i64 0, i64 %32
  %38 = select i1 %36, i64 0, i64 %29
  %39 = select i1 %36, i64 1, i64 %35
  %40 = icmp slt i64 %39, 0
  %41 = icmp sgt i64 %39, 0
  br label %42

42:                                               ; preds = %471, %1
  %43 = phi i64 [ %37, %1 ], [ %67, %471 ]
  %44 = phi i64 [ 0, %1 ], [ %68, %471 ]
  %45 = icmp sge i64 %38, %43
  %46 = icmp sge i64 %43, %38
  %47 = add i64 %43, %39
  %48 = icmp slt i64 %47, %43
  %49 = xor i1 %48, %40
  %50 = select i1 %49, i64 1, i64 0
  %51 = icmp eq i64 %44, 0
  %52 = xor i1 %51, true
  %53 = or i1 %52, %45
  %54 = or i1 %52, %46
  br label %55

55:                                               ; preds = %42
  br i1 %41, label %56, label %61

56:                                               ; preds = %55
  br i1 %54, label %57, label %58

57:                                               ; preds = %56
  br label %64

58:                                               ; preds = %56
  br label %59

59:                                               ; preds = %58
  br label %63

60:                                               ; preds = %61
  br label %63

61:                                               ; preds = %55
  br i1 %53, label %62, label %60

62:                                               ; preds = %61
  br label %64

63:                                               ; preds = %60, %59
  br label %64

64:                                               ; preds = %63, %62, %57
  %65 = phi i1 [ true, %57 ], [ true, %62 ], [ false, %63 ]
  %66 = phi i64 [ undef, %57 ], [ undef, %62 ], [ %43, %63 ]
  %67 = phi i64 [ %43, %57 ], [ %43, %62 ], [ %47, %63 ]
  %68 = phi i64 [ %44, %57 ], [ %44, %62 ], [ %50, %63 ]
  br i1 %65, label %69, label %70

69:                                               ; preds = %64
  br label %472

70:                                               ; preds = %64
  br label %71

71:                                               ; preds = %70
  %72 = udiv i64 %26, 32
  %73 = add i64 %66, %72
  %74 = icmp slt i64 %73, %29
  br i1 %74, label %75, label %470

75:                                               ; preds = %71
  %76 = load i64, ptr %18, align 8
  %77 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %78 = load { ptr, { { i64 }, { {} } } }, ptr %16, align 8
  %79 = load float, ptr %15, align 4
  %80 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %14, align 8
  %81 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %80, 0
  %82 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %80, 1, 1, 0
  %83 = mul i64 %73, %82
  br label %84

84:                                               ; preds = %166, %75
  %85 = phi i64 [ 0, %75 ], [ %167, %166 ]
  %86 = phi i64 [ 0, %75 ], [ %100, %166 ]
  %87 = phi i64 [ 0, %75 ], [ %101, %166 ]
  %88 = phi <2 x float> [ zeroinitializer, %75 ], [ %168, %166 ]
  %89 = phi <2 x float> [ zeroinitializer, %75 ], [ %169, %166 ]
  %90 = phi <2 x float> [ zeroinitializer, %75 ], [ %170, %166 ]
  %91 = fadd contract <2 x float> %88, splat (float 1.000000e+00)
  %92 = extractelement <2 x float> %91, i64 0
  %93 = add i64 %86, 64
  %94 = icmp slt i64 %93, %86
  %95 = select i1 %94, i64 1, i64 0
  %96 = icmp sge i64 %86, %76
  %97 = icmp eq i64 %87, 0
  %98 = xor i1 %97, true
  %99 = or i1 %98, %96
  %100 = select i1 %99, i64 %86, i64 %93
  %101 = select i1 %99, i64 %87, i64 %95
  br i1 %99, label %102, label %103

102:                                              ; preds = %84
  br label %171

103:                                              ; preds = %84
  br label %104

104:                                              ; preds = %103
  %105 = add i64 %86, %24
  %106 = add i64 %83, %105
  %107 = getelementptr inbounds float, ptr %81, i64 %106
  %108 = sub i64 %76, %105
  %109 = call i64 @llvm.smin.i64(i64 %108, i64 2)
  %110 = call i64 @llvm.smax.i64(i64 %109, i64 0)
  %111 = icmp eq i64 %109, 2
  %112 = icmp slt i64 %105, %76
  br i1 %112, label %113, label %165

113:                                              ; preds = %104
  br i1 %111, label %114, label %126

114:                                              ; preds = %113
  %115 = load <2 x float>, ptr %107, align 8
  %116 = fsub contract <2 x float> %115, %89
  %117 = fdiv float 1.000000e+00, %92
  %118 = insertelement <2 x float> undef, float %117, i32 0
  %119 = shufflevector <2 x float> %118, <2 x float> undef, <2 x i32> zeroinitializer
  %120 = fmul contract <2 x float> %116, %119
  %121 = fadd contract <2 x float> %89, %120
  %122 = fmul contract <2 x float> %116, %116
  %123 = fmul contract <2 x float> %122, %88
  %124 = fmul contract <2 x float> %123, %119
  %125 = fadd contract <2 x float> %90, %124
  br label %160

126:                                              ; preds = %113
  br label %127

127:                                              ; preds = %136, %126
  %128 = phi i64 [ 0, %126 ], [ %139, %136 ]
  %129 = phi i64 [ %85, %126 ], [ %140, %136 ]
  %130 = phi <2 x float> [ %88, %126 ], [ %145, %136 ]
  %131 = phi <2 x float> [ %89, %126 ], [ %150, %136 ]
  %132 = phi <2 x float> [ %90, %126 ], [ %154, %136 ]
  %133 = icmp slt i64 %128, %110
  br i1 %133, label %134, label %135

134:                                              ; preds = %127
  br label %136

135:                                              ; preds = %127
  br label %155

136:                                              ; preds = %134
  %137 = icmp eq i64 %128, %110
  %138 = add i64 %128, 1
  %139 = select i1 %137, i64 %128, i64 %138
  %140 = add i64 %105, %128
  %141 = add i64 %83, %140
  %142 = getelementptr inbounds float, ptr %81, i64 %141
  %143 = load float, ptr %142, align 4
  %144 = insertelement <2 x float> zeroinitializer, float %143, i64 0
  %145 = fadd contract <2 x float> %130, <float 1.000000e+00, float 0.000000e+00>
  %146 = fsub contract <2 x float> %144, %131
  %147 = call <2 x float> @llvm.maxnum.v2f32(<2 x float> %145, <2 x float> splat (float 1.000000e+00))
  %148 = fdiv <2 x float> <float 1.000000e+00, float 0.000000e+00>, %147
  %149 = fmul contract <2 x float> %146, %148
  %150 = fadd contract <2 x float> %131, %149
  %151 = fmul contract <2 x float> %146, %146
  %152 = fmul contract <2 x float> %151, %130
  %153 = fmul contract <2 x float> %152, %148
  %154 = fadd contract <2 x float> %132, %153
  br label %127

155:                                              ; preds = %135
  %156 = phi i64 [ %129, %135 ]
  %157 = phi <2 x float> [ %130, %135 ]
  %158 = phi <2 x float> [ %131, %135 ]
  %159 = phi <2 x float> [ %132, %135 ]
  br label %160

160:                                              ; preds = %155, %114
  %161 = phi i64 [ %156, %155 ], [ %105, %114 ]
  %162 = phi <2 x float> [ %157, %155 ], [ %91, %114 ]
  %163 = phi <2 x float> [ %158, %155 ], [ %121, %114 ]
  %164 = phi <2 x float> [ %159, %155 ], [ %125, %114 ]
  br label %166

165:                                              ; preds = %104
  br label %166

166:                                              ; preds = %165, %160
  %167 = phi i64 [ %85, %165 ], [ %161, %160 ]
  %168 = phi <2 x float> [ %88, %165 ], [ %162, %160 ]
  %169 = phi <2 x float> [ %89, %165 ], [ %163, %160 ]
  %170 = phi <2 x float> [ %90, %165 ], [ %164, %160 ]
  br label %84

171:                                              ; preds = %102
  %172 = phi <2 x float> [ %88, %102 ]
  %173 = phi <2 x float> [ %89, %102 ]
  %174 = phi <2 x float> [ %90, %102 ]
  %175 = extractelement <2 x float> %172, i64 0
  %176 = extractelement <2 x float> %173, i64 0
  %177 = extractelement <2 x float> %174, i64 0
  %178 = extractelement <2 x float> %172, i64 1
  %179 = extractelement <2 x float> %173, i64 1
  %180 = extractelement <2 x float> %174, i64 1
  %181 = fadd contract float %175, %178
  %182 = call float @llvm.maxnum.f32(float %181, float 1.000000e+00)
  %183 = fsub contract float %179, %176
  %184 = fdiv float %178, %182
  %185 = fadd contract float %177, %180
  %186 = fmul contract float %183, %183
  %187 = fmul contract float %186, %175
  %188 = fmul contract float %187, %184
  %189 = fadd contract float %185, %188
  %190 = fmul contract float %183, %184
  %191 = fadd contract float %176, %190
  %192 = insertvalue { float, float, float } undef, float %181, 0
  %193 = insertvalue { float, float, float } %192, float %191, 1
  %194 = insertvalue { float, float, float } %193, float %189, 2
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } %194, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %195 = load i32, ptr %11, align 4
  %196 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %195, i32 16, i32 31)
  store i32 %196, ptr %10, align 4
  %197 = getelementptr inbounds i32, ptr %10, i32 1
  %198 = getelementptr inbounds i32, ptr %11, i32 1
  %199 = load i32, ptr %198, align 4
  %200 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %199, i32 16, i32 31)
  store i32 %200, ptr %197, align 4
  %201 = getelementptr inbounds i32, ptr %10, i32 2
  %202 = getelementptr inbounds i32, ptr %11, i32 2
  %203 = load i32, ptr %202, align 4
  %204 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %203, i32 16, i32 31)
  store i32 %204, ptr %201, align 4
  %205 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %206 = getelementptr { float, float, float }, ptr %11, i32 0, i32 0
  %207 = load float, ptr %206, align 4
  %208 = extractvalue { float, float, float } %205, 0
  %209 = fadd contract float %207, %208
  %210 = call float @llvm.maxnum.f32(float %209, float 1.000000e+00)
  %211 = extractvalue { float, float, float } %205, 1
  %212 = getelementptr { float, float, float }, ptr %11, i32 0, i32 1
  %213 = load float, ptr %212, align 4
  %214 = fsub contract float %211, %213
  %215 = fdiv float %208, %210
  %216 = getelementptr { float, float, float }, ptr %11, i32 0, i32 2
  %217 = extractvalue { float, float, float } %205, 2
  %218 = load float, ptr %216, align 4
  %219 = fadd contract float %218, %217
  %220 = fmul contract float %214, %214
  %221 = fmul contract float %220, %207
  %222 = fmul contract float %221, %215
  %223 = fadd contract float %219, %222
  store float %223, ptr %216, align 4
  %224 = fmul contract float %214, %215
  %225 = load float, ptr %212, align 4
  %226 = fadd contract float %225, %224
  store float %226, ptr %212, align 4
  store float %209, ptr %206, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %227 = load i32, ptr %11, align 4
  %228 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %227, i32 8, i32 31)
  store i32 %228, ptr %9, align 4
  %229 = getelementptr inbounds i32, ptr %9, i32 1
  %230 = load i32, ptr %198, align 4
  %231 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %230, i32 8, i32 31)
  store i32 %231, ptr %229, align 4
  %232 = getelementptr inbounds i32, ptr %9, i32 2
  %233 = load i32, ptr %202, align 4
  %234 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %233, i32 8, i32 31)
  store i32 %234, ptr %232, align 4
  %235 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %236 = load float, ptr %206, align 4
  %237 = extractvalue { float, float, float } %235, 0
  %238 = fadd contract float %236, %237
  %239 = call float @llvm.maxnum.f32(float %238, float 1.000000e+00)
  %240 = extractvalue { float, float, float } %235, 1
  %241 = load float, ptr %212, align 4
  %242 = fsub contract float %240, %241
  %243 = fdiv float %237, %239
  %244 = extractvalue { float, float, float } %235, 2
  %245 = load float, ptr %216, align 4
  %246 = fadd contract float %245, %244
  %247 = fmul contract float %242, %242
  %248 = fmul contract float %247, %236
  %249 = fmul contract float %248, %243
  %250 = fadd contract float %246, %249
  store float %250, ptr %216, align 4
  %251 = fmul contract float %242, %243
  %252 = load float, ptr %212, align 4
  %253 = fadd contract float %252, %251
  store float %253, ptr %212, align 4
  store float %238, ptr %206, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %254 = load i32, ptr %11, align 4
  %255 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %254, i32 4, i32 31)
  store i32 %255, ptr %8, align 4
  %256 = getelementptr inbounds i32, ptr %8, i32 1
  %257 = load i32, ptr %198, align 4
  %258 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %257, i32 4, i32 31)
  store i32 %258, ptr %256, align 4
  %259 = getelementptr inbounds i32, ptr %8, i32 2
  %260 = load i32, ptr %202, align 4
  %261 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %260, i32 4, i32 31)
  store i32 %261, ptr %259, align 4
  %262 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %263 = load float, ptr %206, align 4
  %264 = extractvalue { float, float, float } %262, 0
  %265 = fadd contract float %263, %264
  %266 = call float @llvm.maxnum.f32(float %265, float 1.000000e+00)
  %267 = extractvalue { float, float, float } %262, 1
  %268 = load float, ptr %212, align 4
  %269 = fsub contract float %267, %268
  %270 = fdiv float %264, %266
  %271 = extractvalue { float, float, float } %262, 2
  %272 = load float, ptr %216, align 4
  %273 = fadd contract float %272, %271
  %274 = fmul contract float %269, %269
  %275 = fmul contract float %274, %263
  %276 = fmul contract float %275, %270
  %277 = fadd contract float %273, %276
  store float %277, ptr %216, align 4
  %278 = fmul contract float %269, %270
  %279 = load float, ptr %212, align 4
  %280 = fadd contract float %279, %278
  store float %280, ptr %212, align 4
  store float %265, ptr %206, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %281 = load i32, ptr %11, align 4
  %282 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %281, i32 2, i32 31)
  store i32 %282, ptr %7, align 4
  %283 = getelementptr inbounds i32, ptr %7, i32 1
  %284 = load i32, ptr %198, align 4
  %285 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %284, i32 2, i32 31)
  store i32 %285, ptr %283, align 4
  %286 = getelementptr inbounds i32, ptr %7, i32 2
  %287 = load i32, ptr %202, align 4
  %288 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %287, i32 2, i32 31)
  store i32 %288, ptr %286, align 4
  %289 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %290 = load float, ptr %206, align 4
  %291 = extractvalue { float, float, float } %289, 0
  %292 = fadd contract float %290, %291
  %293 = call float @llvm.maxnum.f32(float %292, float 1.000000e+00)
  %294 = extractvalue { float, float, float } %289, 1
  %295 = load float, ptr %212, align 4
  %296 = fsub contract float %294, %295
  %297 = fdiv float %291, %293
  %298 = extractvalue { float, float, float } %289, 2
  %299 = load float, ptr %216, align 4
  %300 = fadd contract float %299, %298
  %301 = fmul contract float %296, %296
  %302 = fmul contract float %301, %290
  %303 = fmul contract float %302, %297
  %304 = fadd contract float %300, %303
  store float %304, ptr %216, align 4
  %305 = fmul contract float %296, %297
  %306 = load float, ptr %212, align 4
  %307 = fadd contract float %306, %305
  store float %307, ptr %212, align 4
  store float %292, ptr %206, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %308 = load i32, ptr %11, align 4
  %309 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %308, i32 1, i32 31)
  store i32 %309, ptr %6, align 4
  %310 = getelementptr inbounds i32, ptr %6, i32 1
  %311 = load i32, ptr %198, align 4
  %312 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %311, i32 1, i32 31)
  store i32 %312, ptr %310, align 4
  %313 = getelementptr inbounds i32, ptr %6, i32 2
  %314 = load i32, ptr %202, align 4
  %315 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %314, i32 1, i32 31)
  store i32 %315, ptr %313, align 4
  %316 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %317 = load float, ptr %206, align 4
  %318 = extractvalue { float, float, float } %316, 0
  %319 = fadd contract float %317, %318
  %320 = call float @llvm.maxnum.f32(float %319, float 1.000000e+00)
  %321 = extractvalue { float, float, float } %316, 1
  %322 = load float, ptr %212, align 4
  %323 = fsub contract float %321, %322
  %324 = fdiv float %318, %320
  %325 = extractvalue { float, float, float } %316, 2
  %326 = load float, ptr %216, align 4
  %327 = fadd contract float %326, %325
  %328 = fmul contract float %323, %323
  %329 = fmul contract float %328, %317
  %330 = fmul contract float %329, %324
  %331 = fadd contract float %327, %330
  store float %331, ptr %216, align 4
  %332 = fmul contract float %323, %324
  %333 = load float, ptr %212, align 4
  %334 = fadd contract float %333, %332
  store float %334, ptr %212, align 4
  store float %319, ptr %206, align 4
  %335 = load float, ptr %212, align 4
  store float %335, ptr %212, align 4
  %336 = load float, ptr %216, align 4
  store float %336, ptr %216, align 4
  %337 = load float, ptr %206, align 4
  store float %337, ptr %206, align 4
  %338 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %339 = extractvalue { float, float, float } %338, 0
  %340 = insertelement <2 x float> zeroinitializer, float %339, i64 0
  %341 = extractvalue { float, float, float } %338, 1
  %342 = insertelement <2 x float> zeroinitializer, float %341, i64 0
  %343 = extractvalue { float, float, float } %338, 2
  %344 = insertelement <2 x float> zeroinitializer, float %343, i64 0
  %345 = insertelement <2 x float> %340, float %339, i64 1
  %346 = insertelement <2 x float> %342, float %341, i64 1
  %347 = insertelement <2 x float> %344, float %343, i64 1
  %348 = fdiv <2 x float> %347, %345
  %349 = insertelement <2 x float> undef, float %79, i32 0
  %350 = shufflevector <2 x float> %349, <2 x float> undef, <2 x i32> zeroinitializer
  %351 = fadd contract <2 x float> %348, %350
  %352 = extractelement <2 x float> %351, i64 1
  %353 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %352)
  %354 = extractelement <2 x float> %351, i64 0
  %355 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %354)
  %356 = insertelement <2 x float> zeroinitializer, float %355, i64 0
  %357 = insertelement <2 x float> %356, float %353, i64 1
  %358 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %13, align 8
  %359 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %358, 0
  %360 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %358, 1, 1, 0
  %361 = extractvalue { ptr, { { i64 }, { {} } } } %77, 0
  %362 = extractvalue { ptr, { { i64 }, { {} } } } %78, 0
  %363 = extractelement <2 x float> %346, i64 0
  %364 = call <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float> %346, i64 0)
  %365 = extractelement <2 x float> %357, i64 0
  %366 = call <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float> %357, i64 0)
  %367 = mul i64 %73, %360
  br label %368

368:                                              ; preds = %467, %171
  %369 = phi i64 [ 0, %171 ], [ %468, %467 ]
  %370 = phi i64 [ 0, %171 ], [ %379, %467 ]
  %371 = phi i64 [ 0, %171 ], [ %380, %467 ]
  %372 = add i64 %370, 64
  %373 = icmp slt i64 %372, %370
  %374 = select i1 %373, i64 1, i64 0
  %375 = icmp sge i64 %370, %76
  %376 = icmp eq i64 %371, 0
  %377 = xor i1 %376, true
  %378 = or i1 %377, %375
  %379 = select i1 %378, i64 %370, i64 %372
  %380 = select i1 %378, i64 %371, i64 %374
  br i1 %378, label %381, label %382

381:                                              ; preds = %368
  br label %469

382:                                              ; preds = %368
  br label %383

383:                                              ; preds = %382
  %384 = add i64 %370, %24
  %385 = getelementptr inbounds float, ptr %362, i64 %384
  %386 = ptrtoint ptr %385 to i64
  %387 = insertelement <2 x i64> undef, i64 %386, i32 0
  %388 = shufflevector <2 x i64> %387, <2 x i64> undef, <2 x i32> zeroinitializer
  %389 = add <2 x i64> %388, %21
  %390 = extractelement <2 x i64> %389, i64 1
  %391 = extractelement <2 x i64> %389, i64 0
  %392 = getelementptr inbounds float, ptr %361, i64 %384
  %393 = ptrtoint ptr %392 to i64
  %394 = insertelement <2 x i64> undef, i64 %393, i32 0
  %395 = shufflevector <2 x i64> %394, <2 x i64> undef, <2 x i32> zeroinitializer
  %396 = add <2 x i64> %395, %21
  %397 = extractelement <2 x i64> %396, i64 1
  %398 = extractelement <2 x i64> %396, i64 0
  %399 = add i64 %367, %384
  %400 = getelementptr inbounds float, ptr %359, i64 %399
  %401 = add i64 %83, %384
  %402 = getelementptr inbounds float, ptr %81, i64 %401
  %403 = sub i64 %76, %384
  %404 = call i64 @llvm.smin.i64(i64 %403, i64 2)
  %405 = call i64 @llvm.smax.i64(i64 %404, i64 0)
  %406 = icmp eq i64 %404, 2
  %407 = icmp slt i64 %384, %76
  br i1 %407, label %408, label %466

408:                                              ; preds = %383
  br i1 %406, label %409, label %437

409:                                              ; preds = %408
  %410 = load <2 x float>, ptr %402, align 8
  br i1 %19, label %411, label %413

411:                                              ; preds = %409
  %412 = load <2 x float>, ptr %392, align 2, !invariant.load !1
  br label %420

413:                                              ; preds = %409
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %398, ptr %5, align 8
  %414 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %415 = load float, ptr %414, align 4, !invariant.load !1
  %416 = insertelement <2 x float> zeroinitializer, float %415, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %397, ptr %4, align 8
  %417 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %418 = load float, ptr %417, align 4, !invariant.load !1
  %419 = insertelement <2 x float> %416, float %418, i64 1
  br label %420

420:                                              ; preds = %413, %411
  %421 = phi <2 x float> [ %419, %413 ], [ %412, %411 ]
  br i1 %19, label %422, label %424

422:                                              ; preds = %420
  %423 = load <2 x float>, ptr %385, align 2, !invariant.load !1
  br label %431

424:                                              ; preds = %420
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %391, ptr %3, align 8
  %425 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %426 = load float, ptr %425, align 4, !invariant.load !1
  %427 = insertelement <2 x float> zeroinitializer, float %426, i64 0
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %390, ptr %2, align 8
  %428 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %429 = load float, ptr %428, align 4, !invariant.load !1
  %430 = insertelement <2 x float> %427, float %429, i64 1
  br label %431

431:                                              ; preds = %424, %422
  %432 = phi <2 x float> [ %430, %424 ], [ %423, %422 ]
  %433 = fsub contract <2 x float> %410, %364
  %434 = fmul contract <2 x float> %433, %366
  %435 = fmul contract <2 x float> %434, %421
  %436 = fadd contract <2 x float> %435, %432
  store <2 x float> %436, ptr %400, align 8
  br label %464

437:                                              ; preds = %408
  br label %438

438:                                              ; preds = %444, %437
  %439 = phi i64 [ 0, %437 ], [ %447, %444 ]
  %440 = phi i64 [ %369, %437 ], [ %448, %444 ]
  %441 = icmp slt i64 %439, %405
  br i1 %441, label %442, label %443

442:                                              ; preds = %438
  br label %444

443:                                              ; preds = %438
  br label %462

444:                                              ; preds = %442
  %445 = icmp eq i64 %439, %405
  %446 = add i64 %439, 1
  %447 = select i1 %445, i64 %439, i64 %446
  %448 = add i64 %384, %439
  %449 = add i64 %83, %448
  %450 = getelementptr inbounds float, ptr %81, i64 %449
  %451 = load float, ptr %450, align 4
  %452 = getelementptr inbounds float, ptr %361, i64 %448
  %453 = load float, ptr %452, align 4, !invariant.load !1
  %454 = getelementptr inbounds float, ptr %362, i64 %448
  %455 = load float, ptr %454, align 4, !invariant.load !1
  %456 = fsub contract float %451, %363
  %457 = fmul contract float %456, %365
  %458 = fmul contract float %457, %453
  %459 = fadd contract float %458, %455
  %460 = add i64 %367, %448
  %461 = getelementptr inbounds float, ptr %359, i64 %460
  store float %459, ptr %461, align 4
  br label %438

462:                                              ; preds = %443
  %463 = phi i64 [ %440, %443 ]
  br label %464

464:                                              ; preds = %462, %431
  %465 = phi i64 [ %463, %462 ], [ %384, %431 ]
  br label %467

466:                                              ; preds = %383
  br label %467

467:                                              ; preds = %466, %464
  %468 = phi i64 [ %369, %466 ], [ %465, %464 ]
  br label %368

469:                                              ; preds = %381
  br label %471

470:                                              ; preds = %71
  br label %471

471:                                              ; preds = %470, %469
  br label %42

472:                                              ; preds = %69
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
