; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r5_ax4_w2_bs128_79d88993(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %12 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %13 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %12, i32 0, i32 5
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %12, i32 0, i32 4
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %12, i32 0, i32 3
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %12, i32 0, i32 2
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %12, i32 0, i32 1
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %12, i32 0, i32 0
  %19 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 2
  %20 = call i1 @llvm.vector.reduce.and.v2i1(<2 x i1> splat (i1 true))
  %21 = call <2 x i64> @llvm.stepvector.v2i64()
  %22 = mul <2 x i64> %21, splat (i64 4)
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %24 = sext i32 %23 to i64
  %25 = mul i64 %24, 2
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %27 = zext i32 %26 to i64
  %28 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %29 = load { i64, i64, i64, i64, i64 }, ptr %28, align 8
  %30 = extractvalue { i64, i64, i64, i64, i64 } %29, 0
  %31 = extractvalue { i64, i64, i64, i64, i64 } %29, 1
  %32 = mul i64 %30, %31
  %33 = extractvalue { i64, i64, i64, i64, i64 } %29, 2
  %34 = mul i64 %32, %33
  %35 = extractvalue { i64, i64, i64, i64, i64 } %29, 3
  %36 = mul i64 %34, %35
  %37 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %38 = zext i32 %37 to i64
  %39 = mul i64 %38, 4
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %41 = sext i32 %40 to i64
  %42 = mul i64 %41, 4
  %43 = icmp eq i64 %42, 0
  %44 = select i1 %43, i64 0, i64 %39
  %45 = select i1 %43, i64 0, i64 %36
  %46 = select i1 %43, i64 1, i64 %42
  %47 = icmp slt i64 %46, 0
  %48 = icmp sgt i64 %46, 0
  br label %49

49:                                               ; preds = %568, %1
  %50 = phi i64 [ %44, %1 ], [ %74, %568 ]
  %51 = phi i64 [ 0, %1 ], [ %75, %568 ]
  %52 = icmp sge i64 %45, %50
  %53 = icmp sge i64 %50, %45
  %54 = add i64 %50, %46
  %55 = icmp slt i64 %54, %50
  %56 = xor i1 %55, %47
  %57 = select i1 %56, i64 1, i64 0
  %58 = icmp eq i64 %51, 0
  %59 = xor i1 %58, true
  %60 = or i1 %59, %52
  %61 = or i1 %59, %53
  br label %62

62:                                               ; preds = %49
  br i1 %48, label %63, label %68

63:                                               ; preds = %62
  br i1 %61, label %64, label %65

64:                                               ; preds = %63
  br label %71

65:                                               ; preds = %63
  br label %66

66:                                               ; preds = %65
  br label %70

67:                                               ; preds = %68
  br label %70

68:                                               ; preds = %62
  br i1 %60, label %69, label %67

69:                                               ; preds = %68
  br label %71

70:                                               ; preds = %67, %66
  br label %71

71:                                               ; preds = %70, %69, %64
  %72 = phi i1 [ true, %64 ], [ true, %69 ], [ false, %70 ]
  %73 = phi i64 [ undef, %64 ], [ undef, %69 ], [ %50, %70 ]
  %74 = phi i64 [ %50, %64 ], [ %50, %69 ], [ %54, %70 ]
  %75 = phi i64 [ %51, %64 ], [ %51, %69 ], [ %57, %70 ]
  br i1 %72, label %76, label %77

76:                                               ; preds = %71
  br label %569

77:                                               ; preds = %71
  br label %78

78:                                               ; preds = %77
  %79 = udiv i64 %27, 32
  %80 = add i64 %73, %79
  %81 = trunc i64 %80 to i32
  %82 = zext i32 %81 to i64
  %83 = icmp slt i64 %80, %36
  br i1 %83, label %84, label %567

84:                                               ; preds = %78
  %85 = load [3 x { i32, i32, i8, i8, i1, i8 }], ptr %19, align 4
  %86 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 2, 0
  %87 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 2, 1
  %88 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 2, 2
  %89 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 2, 3
  %90 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 2, 4
  %91 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 2, 5
  %92 = zext i8 %89 to i32
  %93 = zext i8 %88 to i32
  %94 = zext i32 %87 to i64
  %95 = mul i64 %94, %82
  %96 = zext i8 %91 to i32
  %97 = lshr i32 %81, %96
  %98 = lshr i64 %95, 32
  %99 = trunc i64 %98 to i32
  %100 = sub i32 %81, %99
  %101 = lshr i32 %100, %93
  %102 = add i32 %99, %101
  %103 = lshr i32 %102, %92
  %104 = select i1 %90, i32 %97, i32 %103
  %105 = mul i32 %104, %86
  %106 = sub i32 %81, %105
  %107 = zext i32 %106 to i64
  %108 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 1, 0
  %109 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 1, 1
  %110 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 1, 2
  %111 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 1, 3
  %112 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 1, 4
  %113 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 1, 5
  %114 = zext i8 %111 to i32
  %115 = zext i8 %110 to i32
  %116 = zext i32 %104 to i64
  %117 = zext i32 %109 to i64
  %118 = mul i64 %117, %116
  %119 = zext i8 %113 to i32
  %120 = lshr i32 %104, %119
  %121 = lshr i64 %118, 32
  %122 = trunc i64 %121 to i32
  %123 = sub i32 %104, %122
  %124 = lshr i32 %123, %115
  %125 = add i32 %122, %124
  %126 = lshr i32 %125, %114
  %127 = select i1 %112, i32 %120, i32 %126
  %128 = mul i32 %127, %108
  %129 = sub i32 %104, %128
  %130 = zext i32 %129 to i64
  %131 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 0, 0
  %132 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 0, 1
  %133 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 0, 2
  %134 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 0, 3
  %135 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 0, 4
  %136 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %85, 0, 5
  %137 = zext i8 %134 to i32
  %138 = zext i8 %133 to i32
  %139 = zext i32 %127 to i64
  %140 = zext i32 %132 to i64
  %141 = mul i64 %140, %139
  %142 = zext i8 %136 to i32
  %143 = lshr i32 %127, %142
  %144 = lshr i64 %141, 32
  %145 = trunc i64 %144 to i32
  %146 = sub i32 %127, %145
  %147 = lshr i32 %146, %138
  %148 = add i32 %145, %147
  %149 = lshr i32 %148, %137
  %150 = select i1 %135, i32 %143, i32 %149
  %151 = mul i32 %150, %131
  %152 = sub i32 %127, %151
  %153 = zext i32 %152 to i64
  %154 = zext i32 %150 to i64
  %155 = load i64, ptr %18, align 8
  %156 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %157 = load { ptr, { { i64 }, { {} } } }, ptr %16, align 8
  %158 = load float, ptr %15, align 4
  %159 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %14, align 8
  %160 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %159, 0
  %161 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %159, 1, 1, 0
  %162 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %159, 1, 1, 1
  %163 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %159, 1, 1, 2
  %164 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %159, 1, 1, 3
  %165 = mul i64 %154, %161
  %166 = mul i64 %153, %162
  %167 = add i64 %165, %166
  %168 = mul i64 %130, %163
  %169 = add i64 %167, %168
  %170 = mul i64 %107, %164
  %171 = add i64 %169, %170
  br label %172

172:                                              ; preds = %254, %84
  %173 = phi i64 [ 0, %84 ], [ %255, %254 ]
  %174 = phi i64 [ 0, %84 ], [ %188, %254 ]
  %175 = phi i64 [ 0, %84 ], [ %189, %254 ]
  %176 = phi <2 x float> [ zeroinitializer, %84 ], [ %256, %254 ]
  %177 = phi <2 x float> [ zeroinitializer, %84 ], [ %257, %254 ]
  %178 = phi <2 x float> [ zeroinitializer, %84 ], [ %258, %254 ]
  %179 = fadd contract <2 x float> %176, splat (float 1.000000e+00)
  %180 = extractelement <2 x float> %179, i64 0
  %181 = add i64 %174, 64
  %182 = icmp slt i64 %181, %174
  %183 = select i1 %182, i64 1, i64 0
  %184 = icmp sge i64 %174, %155
  %185 = icmp eq i64 %175, 0
  %186 = xor i1 %185, true
  %187 = or i1 %186, %184
  %188 = select i1 %187, i64 %174, i64 %181
  %189 = select i1 %187, i64 %175, i64 %183
  br i1 %187, label %190, label %191

190:                                              ; preds = %172
  br label %259

191:                                              ; preds = %172
  br label %192

192:                                              ; preds = %191
  %193 = add i64 %174, %25
  %194 = add i64 %171, %193
  %195 = getelementptr inbounds float, ptr %160, i64 %194
  %196 = sub i64 %155, %193
  %197 = call i64 @llvm.smin.i64(i64 %196, i64 2)
  %198 = call i64 @llvm.smax.i64(i64 %197, i64 0)
  %199 = icmp eq i64 %197, 2
  %200 = icmp slt i64 %193, %155
  br i1 %200, label %201, label %253

201:                                              ; preds = %192
  br i1 %199, label %202, label %214

202:                                              ; preds = %201
  %203 = load <2 x float>, ptr %195, align 8
  %204 = fsub contract <2 x float> %203, %177
  %205 = fdiv float 1.000000e+00, %180
  %206 = insertelement <2 x float> undef, float %205, i32 0
  %207 = shufflevector <2 x float> %206, <2 x float> undef, <2 x i32> zeroinitializer
  %208 = fmul contract <2 x float> %204, %207
  %209 = fadd contract <2 x float> %177, %208
  %210 = fmul contract <2 x float> %204, %204
  %211 = fmul contract <2 x float> %210, %176
  %212 = fmul contract <2 x float> %211, %207
  %213 = fadd contract <2 x float> %178, %212
  br label %248

214:                                              ; preds = %201
  br label %215

215:                                              ; preds = %224, %214
  %216 = phi i64 [ 0, %214 ], [ %227, %224 ]
  %217 = phi i64 [ %173, %214 ], [ %228, %224 ]
  %218 = phi <2 x float> [ %176, %214 ], [ %233, %224 ]
  %219 = phi <2 x float> [ %177, %214 ], [ %238, %224 ]
  %220 = phi <2 x float> [ %178, %214 ], [ %242, %224 ]
  %221 = icmp slt i64 %216, %198
  br i1 %221, label %222, label %223

222:                                              ; preds = %215
  br label %224

223:                                              ; preds = %215
  br label %243

224:                                              ; preds = %222
  %225 = icmp eq i64 %216, %198
  %226 = add i64 %216, 1
  %227 = select i1 %225, i64 %216, i64 %226
  %228 = add i64 %193, %216
  %229 = add i64 %171, %228
  %230 = getelementptr inbounds float, ptr %160, i64 %229
  %231 = load float, ptr %230, align 4
  %232 = insertelement <2 x float> zeroinitializer, float %231, i64 0
  %233 = fadd contract <2 x float> %218, <float 1.000000e+00, float 0.000000e+00>
  %234 = fsub contract <2 x float> %232, %219
  %235 = call <2 x float> @llvm.maxnum.v2f32(<2 x float> %233, <2 x float> splat (float 1.000000e+00))
  %236 = fdiv <2 x float> <float 1.000000e+00, float 0.000000e+00>, %235
  %237 = fmul contract <2 x float> %234, %236
  %238 = fadd contract <2 x float> %219, %237
  %239 = fmul contract <2 x float> %234, %234
  %240 = fmul contract <2 x float> %239, %218
  %241 = fmul contract <2 x float> %240, %236
  %242 = fadd contract <2 x float> %220, %241
  br label %215

243:                                              ; preds = %223
  %244 = phi i64 [ %217, %223 ]
  %245 = phi <2 x float> [ %218, %223 ]
  %246 = phi <2 x float> [ %219, %223 ]
  %247 = phi <2 x float> [ %220, %223 ]
  br label %248

248:                                              ; preds = %243, %202
  %249 = phi i64 [ %244, %243 ], [ %193, %202 ]
  %250 = phi <2 x float> [ %245, %243 ], [ %179, %202 ]
  %251 = phi <2 x float> [ %246, %243 ], [ %209, %202 ]
  %252 = phi <2 x float> [ %247, %243 ], [ %213, %202 ]
  br label %254

253:                                              ; preds = %192
  br label %254

254:                                              ; preds = %253, %248
  %255 = phi i64 [ %173, %253 ], [ %249, %248 ]
  %256 = phi <2 x float> [ %176, %253 ], [ %250, %248 ]
  %257 = phi <2 x float> [ %177, %253 ], [ %251, %248 ]
  %258 = phi <2 x float> [ %178, %253 ], [ %252, %248 ]
  br label %172

259:                                              ; preds = %190
  %260 = phi <2 x float> [ %176, %190 ]
  %261 = phi <2 x float> [ %177, %190 ]
  %262 = phi <2 x float> [ %178, %190 ]
  %263 = extractelement <2 x float> %260, i64 0
  %264 = extractelement <2 x float> %261, i64 0
  %265 = extractelement <2 x float> %262, i64 0
  %266 = extractelement <2 x float> %260, i64 1
  %267 = extractelement <2 x float> %261, i64 1
  %268 = extractelement <2 x float> %262, i64 1
  %269 = fadd contract float %263, %266
  %270 = call float @llvm.maxnum.f32(float %269, float 1.000000e+00)
  %271 = fsub contract float %267, %264
  %272 = fdiv float %266, %270
  %273 = fadd contract float %265, %268
  %274 = fmul contract float %271, %271
  %275 = fmul contract float %274, %263
  %276 = fmul contract float %275, %272
  %277 = fadd contract float %273, %276
  %278 = fmul contract float %271, %272
  %279 = fadd contract float %264, %278
  %280 = insertvalue { float, float, float } undef, float %269, 0
  %281 = insertvalue { float, float, float } %280, float %279, 1
  %282 = insertvalue { float, float, float } %281, float %277, 2
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } %282, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %283 = load i32, ptr %11, align 4
  %284 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %283, i32 16, i32 31)
  store i32 %284, ptr %10, align 4
  %285 = getelementptr inbounds i32, ptr %10, i32 1
  %286 = getelementptr inbounds i32, ptr %11, i32 1
  %287 = load i32, ptr %286, align 4
  %288 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %287, i32 16, i32 31)
  store i32 %288, ptr %285, align 4
  %289 = getelementptr inbounds i32, ptr %10, i32 2
  %290 = getelementptr inbounds i32, ptr %11, i32 2
  %291 = load i32, ptr %290, align 4
  %292 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %291, i32 16, i32 31)
  store i32 %292, ptr %289, align 4
  %293 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %294 = getelementptr { float, float, float }, ptr %11, i32 0, i32 0
  %295 = load float, ptr %294, align 4
  %296 = extractvalue { float, float, float } %293, 0
  %297 = fadd contract float %295, %296
  %298 = call float @llvm.maxnum.f32(float %297, float 1.000000e+00)
  %299 = extractvalue { float, float, float } %293, 1
  %300 = getelementptr { float, float, float }, ptr %11, i32 0, i32 1
  %301 = load float, ptr %300, align 4
  %302 = fsub contract float %299, %301
  %303 = fdiv float %296, %298
  %304 = getelementptr { float, float, float }, ptr %11, i32 0, i32 2
  %305 = extractvalue { float, float, float } %293, 2
  %306 = load float, ptr %304, align 4
  %307 = fadd contract float %306, %305
  %308 = fmul contract float %302, %302
  %309 = fmul contract float %308, %295
  %310 = fmul contract float %309, %303
  %311 = fadd contract float %307, %310
  store float %311, ptr %304, align 4
  %312 = fmul contract float %302, %303
  %313 = load float, ptr %300, align 4
  %314 = fadd contract float %313, %312
  store float %314, ptr %300, align 4
  store float %297, ptr %294, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %315 = load i32, ptr %11, align 4
  %316 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %315, i32 8, i32 31)
  store i32 %316, ptr %9, align 4
  %317 = getelementptr inbounds i32, ptr %9, i32 1
  %318 = load i32, ptr %286, align 4
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 8, i32 31)
  store i32 %319, ptr %317, align 4
  %320 = getelementptr inbounds i32, ptr %9, i32 2
  %321 = load i32, ptr %290, align 4
  %322 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %321, i32 8, i32 31)
  store i32 %322, ptr %320, align 4
  %323 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %324 = load float, ptr %294, align 4
  %325 = extractvalue { float, float, float } %323, 0
  %326 = fadd contract float %324, %325
  %327 = call float @llvm.maxnum.f32(float %326, float 1.000000e+00)
  %328 = extractvalue { float, float, float } %323, 1
  %329 = load float, ptr %300, align 4
  %330 = fsub contract float %328, %329
  %331 = fdiv float %325, %327
  %332 = extractvalue { float, float, float } %323, 2
  %333 = load float, ptr %304, align 4
  %334 = fadd contract float %333, %332
  %335 = fmul contract float %330, %330
  %336 = fmul contract float %335, %324
  %337 = fmul contract float %336, %331
  %338 = fadd contract float %334, %337
  store float %338, ptr %304, align 4
  %339 = fmul contract float %330, %331
  %340 = load float, ptr %300, align 4
  %341 = fadd contract float %340, %339
  store float %341, ptr %300, align 4
  store float %326, ptr %294, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %342 = load i32, ptr %11, align 4
  %343 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %342, i32 4, i32 31)
  store i32 %343, ptr %8, align 4
  %344 = getelementptr inbounds i32, ptr %8, i32 1
  %345 = load i32, ptr %286, align 4
  %346 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %345, i32 4, i32 31)
  store i32 %346, ptr %344, align 4
  %347 = getelementptr inbounds i32, ptr %8, i32 2
  %348 = load i32, ptr %290, align 4
  %349 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %348, i32 4, i32 31)
  store i32 %349, ptr %347, align 4
  %350 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %351 = load float, ptr %294, align 4
  %352 = extractvalue { float, float, float } %350, 0
  %353 = fadd contract float %351, %352
  %354 = call float @llvm.maxnum.f32(float %353, float 1.000000e+00)
  %355 = extractvalue { float, float, float } %350, 1
  %356 = load float, ptr %300, align 4
  %357 = fsub contract float %355, %356
  %358 = fdiv float %352, %354
  %359 = extractvalue { float, float, float } %350, 2
  %360 = load float, ptr %304, align 4
  %361 = fadd contract float %360, %359
  %362 = fmul contract float %357, %357
  %363 = fmul contract float %362, %351
  %364 = fmul contract float %363, %358
  %365 = fadd contract float %361, %364
  store float %365, ptr %304, align 4
  %366 = fmul contract float %357, %358
  %367 = load float, ptr %300, align 4
  %368 = fadd contract float %367, %366
  store float %368, ptr %300, align 4
  store float %353, ptr %294, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %369 = load i32, ptr %11, align 4
  %370 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %369, i32 2, i32 31)
  store i32 %370, ptr %7, align 4
  %371 = getelementptr inbounds i32, ptr %7, i32 1
  %372 = load i32, ptr %286, align 4
  %373 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %372, i32 2, i32 31)
  store i32 %373, ptr %371, align 4
  %374 = getelementptr inbounds i32, ptr %7, i32 2
  %375 = load i32, ptr %290, align 4
  %376 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %375, i32 2, i32 31)
  store i32 %376, ptr %374, align 4
  %377 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %378 = load float, ptr %294, align 4
  %379 = extractvalue { float, float, float } %377, 0
  %380 = fadd contract float %378, %379
  %381 = call float @llvm.maxnum.f32(float %380, float 1.000000e+00)
  %382 = extractvalue { float, float, float } %377, 1
  %383 = load float, ptr %300, align 4
  %384 = fsub contract float %382, %383
  %385 = fdiv float %379, %381
  %386 = extractvalue { float, float, float } %377, 2
  %387 = load float, ptr %304, align 4
  %388 = fadd contract float %387, %386
  %389 = fmul contract float %384, %384
  %390 = fmul contract float %389, %378
  %391 = fmul contract float %390, %385
  %392 = fadd contract float %388, %391
  store float %392, ptr %304, align 4
  %393 = fmul contract float %384, %385
  %394 = load float, ptr %300, align 4
  %395 = fadd contract float %394, %393
  store float %395, ptr %300, align 4
  store float %380, ptr %294, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %396 = load i32, ptr %11, align 4
  %397 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %396, i32 1, i32 31)
  store i32 %397, ptr %6, align 4
  %398 = getelementptr inbounds i32, ptr %6, i32 1
  %399 = load i32, ptr %286, align 4
  %400 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %399, i32 1, i32 31)
  store i32 %400, ptr %398, align 4
  %401 = getelementptr inbounds i32, ptr %6, i32 2
  %402 = load i32, ptr %290, align 4
  %403 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %402, i32 1, i32 31)
  store i32 %403, ptr %401, align 4
  %404 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %405 = load float, ptr %294, align 4
  %406 = extractvalue { float, float, float } %404, 0
  %407 = fadd contract float %405, %406
  %408 = call float @llvm.maxnum.f32(float %407, float 1.000000e+00)
  %409 = extractvalue { float, float, float } %404, 1
  %410 = load float, ptr %300, align 4
  %411 = fsub contract float %409, %410
  %412 = fdiv float %406, %408
  %413 = extractvalue { float, float, float } %404, 2
  %414 = load float, ptr %304, align 4
  %415 = fadd contract float %414, %413
  %416 = fmul contract float %411, %411
  %417 = fmul contract float %416, %405
  %418 = fmul contract float %417, %412
  %419 = fadd contract float %415, %418
  store float %419, ptr %304, align 4
  %420 = fmul contract float %411, %412
  %421 = load float, ptr %300, align 4
  %422 = fadd contract float %421, %420
  store float %422, ptr %300, align 4
  store float %407, ptr %294, align 4
  %423 = load float, ptr %300, align 4
  store float %423, ptr %300, align 4
  %424 = load float, ptr %304, align 4
  store float %424, ptr %304, align 4
  %425 = load float, ptr %294, align 4
  store float %425, ptr %294, align 4
  %426 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %427 = extractvalue { float, float, float } %426, 0
  %428 = insertelement <2 x float> zeroinitializer, float %427, i64 0
  %429 = extractvalue { float, float, float } %426, 1
  %430 = insertelement <2 x float> zeroinitializer, float %429, i64 0
  %431 = extractvalue { float, float, float } %426, 2
  %432 = insertelement <2 x float> zeroinitializer, float %431, i64 0
  %433 = insertelement <2 x float> %428, float %427, i64 1
  %434 = insertelement <2 x float> %430, float %429, i64 1
  %435 = insertelement <2 x float> %432, float %431, i64 1
  %436 = fdiv <2 x float> %435, %433
  %437 = insertelement <2 x float> undef, float %158, i32 0
  %438 = shufflevector <2 x float> %437, <2 x float> undef, <2 x i32> zeroinitializer
  %439 = fadd contract <2 x float> %436, %438
  %440 = extractelement <2 x float> %439, i64 1
  %441 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %440)
  %442 = extractelement <2 x float> %439, i64 0
  %443 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %442)
  %444 = insertelement <2 x float> zeroinitializer, float %443, i64 0
  %445 = insertelement <2 x float> %444, float %441, i64 1
  %446 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %13, align 8
  %447 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 0
  %448 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 0
  %449 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 1
  %450 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 2
  %451 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 3
  %452 = extractvalue { ptr, { { i64 }, { {} } } } %156, 0
  %453 = extractvalue { ptr, { { i64 }, { {} } } } %157, 0
  %454 = extractelement <2 x float> %434, i64 0
  %455 = call <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float> %434, i64 0)
  %456 = extractelement <2 x float> %445, i64 0
  %457 = call <2 x float> @llvm.vector.extract.v2f32.v2f32(<2 x float> %445, i64 0)
  %458 = mul i64 %154, %448
  %459 = mul i64 %153, %449
  %460 = add i64 %458, %459
  %461 = mul i64 %130, %450
  %462 = add i64 %460, %461
  %463 = mul i64 %107, %451
  %464 = add i64 %462, %463
  br label %465

465:                                              ; preds = %564, %259
  %466 = phi i64 [ 0, %259 ], [ %565, %564 ]
  %467 = phi i64 [ 0, %259 ], [ %476, %564 ]
  %468 = phi i64 [ 0, %259 ], [ %477, %564 ]
  %469 = add i64 %467, 64
  %470 = icmp slt i64 %469, %467
  %471 = select i1 %470, i64 1, i64 0
  %472 = icmp sge i64 %467, %155
  %473 = icmp eq i64 %468, 0
  %474 = xor i1 %473, true
  %475 = or i1 %474, %472
  %476 = select i1 %475, i64 %467, i64 %469
  %477 = select i1 %475, i64 %468, i64 %471
  br i1 %475, label %478, label %479

478:                                              ; preds = %465
  br label %566

479:                                              ; preds = %465
  br label %480

480:                                              ; preds = %479
  %481 = add i64 %467, %25
  %482 = getelementptr inbounds float, ptr %453, i64 %481
  %483 = ptrtoint ptr %482 to i64
  %484 = insertelement <2 x i64> undef, i64 %483, i32 0
  %485 = shufflevector <2 x i64> %484, <2 x i64> undef, <2 x i32> zeroinitializer
  %486 = add <2 x i64> %485, %22
  %487 = extractelement <2 x i64> %486, i64 1
  %488 = extractelement <2 x i64> %486, i64 0
  %489 = getelementptr inbounds float, ptr %452, i64 %481
  %490 = ptrtoint ptr %489 to i64
  %491 = insertelement <2 x i64> undef, i64 %490, i32 0
  %492 = shufflevector <2 x i64> %491, <2 x i64> undef, <2 x i32> zeroinitializer
  %493 = add <2 x i64> %492, %22
  %494 = extractelement <2 x i64> %493, i64 1
  %495 = extractelement <2 x i64> %493, i64 0
  %496 = add i64 %464, %481
  %497 = getelementptr inbounds float, ptr %447, i64 %496
  %498 = add i64 %171, %481
  %499 = getelementptr inbounds float, ptr %160, i64 %498
  %500 = sub i64 %155, %481
  %501 = call i64 @llvm.smin.i64(i64 %500, i64 2)
  %502 = call i64 @llvm.smax.i64(i64 %501, i64 0)
  %503 = icmp eq i64 %501, 2
  %504 = icmp slt i64 %481, %155
  br i1 %504, label %505, label %563

505:                                              ; preds = %480
  br i1 %503, label %506, label %534

506:                                              ; preds = %505
  %507 = load <2 x float>, ptr %499, align 8
  br i1 %20, label %508, label %510

508:                                              ; preds = %506
  %509 = load <2 x float>, ptr %489, align 2, !invariant.load !1
  br label %517

510:                                              ; preds = %506
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %495, ptr %5, align 8
  %511 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %512 = load float, ptr %511, align 4, !invariant.load !1
  %513 = insertelement <2 x float> zeroinitializer, float %512, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %494, ptr %4, align 8
  %514 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %515 = load float, ptr %514, align 4, !invariant.load !1
  %516 = insertelement <2 x float> %513, float %515, i64 1
  br label %517

517:                                              ; preds = %510, %508
  %518 = phi <2 x float> [ %516, %510 ], [ %509, %508 ]
  br i1 %20, label %519, label %521

519:                                              ; preds = %517
  %520 = load <2 x float>, ptr %482, align 2, !invariant.load !1
  br label %528

521:                                              ; preds = %517
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %488, ptr %3, align 8
  %522 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %523 = load float, ptr %522, align 4, !invariant.load !1
  %524 = insertelement <2 x float> zeroinitializer, float %523, i64 0
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %487, ptr %2, align 8
  %525 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %526 = load float, ptr %525, align 4, !invariant.load !1
  %527 = insertelement <2 x float> %524, float %526, i64 1
  br label %528

528:                                              ; preds = %521, %519
  %529 = phi <2 x float> [ %527, %521 ], [ %520, %519 ]
  %530 = fsub contract <2 x float> %507, %455
  %531 = fmul contract <2 x float> %530, %457
  %532 = fmul contract <2 x float> %531, %518
  %533 = fadd contract <2 x float> %532, %529
  store <2 x float> %533, ptr %497, align 8
  br label %561

534:                                              ; preds = %505
  br label %535

535:                                              ; preds = %541, %534
  %536 = phi i64 [ 0, %534 ], [ %544, %541 ]
  %537 = phi i64 [ %466, %534 ], [ %545, %541 ]
  %538 = icmp slt i64 %536, %502
  br i1 %538, label %539, label %540

539:                                              ; preds = %535
  br label %541

540:                                              ; preds = %535
  br label %559

541:                                              ; preds = %539
  %542 = icmp eq i64 %536, %502
  %543 = add i64 %536, 1
  %544 = select i1 %542, i64 %536, i64 %543
  %545 = add i64 %481, %536
  %546 = add i64 %171, %545
  %547 = getelementptr inbounds float, ptr %160, i64 %546
  %548 = load float, ptr %547, align 4
  %549 = getelementptr inbounds float, ptr %452, i64 %545
  %550 = load float, ptr %549, align 4, !invariant.load !1
  %551 = getelementptr inbounds float, ptr %453, i64 %545
  %552 = load float, ptr %551, align 4, !invariant.load !1
  %553 = fsub contract float %548, %454
  %554 = fmul contract float %553, %456
  %555 = fmul contract float %554, %550
  %556 = fadd contract float %555, %552
  %557 = add i64 %464, %545
  %558 = getelementptr inbounds float, ptr %447, i64 %557
  store float %556, ptr %558, align 4
  br label %535

559:                                              ; preds = %540
  %560 = phi i64 [ %537, %540 ]
  br label %561

561:                                              ; preds = %559, %528
  %562 = phi i64 [ %560, %559 ], [ %481, %528 ]
  br label %564

563:                                              ; preds = %480
  br label %564

564:                                              ; preds = %563, %561
  %565 = phi i64 [ %466, %563 ], [ %562, %561 ]
  br label %465

566:                                              ; preds = %478
  br label %568

567:                                              ; preds = %78
  br label %568

568:                                              ; preds = %567, %566
  br label %49

569:                                              ; preds = %76
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
