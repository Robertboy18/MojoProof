; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r2_ax1_w4_bs64_6c9cce32._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [2 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r2_ax1_w4_bs64_6c9cce32(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %21 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %22 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %21, i32 0, i32 5
  %23 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %21, i32 0, i32 4
  %24 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %21, i32 0, i32 3
  %25 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %21, i32 0, i32 2
  %26 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %21, i32 0, i32 1
  %27 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %21, i32 0, i32 0
  %28 = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> splat (i1 true))
  %29 = call <4 x i64> @llvm.stepvector.v4i64()
  %30 = mul <4 x i64> %29, splat (i64 4)
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %32 = sext i32 %31 to i64
  %33 = icmp slt i64 %32, 2
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %35 = zext i32 %34 to i64
  %36 = mul i64 %35, 4
  %37 = icmp eq i64 %32, 0
  %38 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %39 = load { i64, i64 }, ptr %38, align 8
  %40 = extractvalue { i64, i64 } %39, 0
  %41 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %42 = zext i32 %41 to i64
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %44 = sext i32 %43 to i64
  %45 = icmp eq i64 %44, 0
  %46 = select i1 %45, i64 0, i64 %42
  %47 = select i1 %45, i64 0, i64 %40
  %48 = select i1 %45, i64 1, i64 %44
  %49 = icmp slt i64 %48, 0
  %50 = icmp sgt i64 %48, 0
  br label %51

51:                                               ; preds = %643, %1
  %52 = phi i64 [ %46, %1 ], [ %76, %643 ]
  %53 = phi i64 [ 0, %1 ], [ %77, %643 ]
  %54 = icmp sge i64 %47, %52
  %55 = icmp sge i64 %52, %47
  %56 = add i64 %52, %48
  %57 = icmp slt i64 %56, %52
  %58 = xor i1 %57, %49
  %59 = select i1 %58, i64 1, i64 0
  %60 = icmp eq i64 %53, 0
  %61 = xor i1 %60, true
  %62 = or i1 %61, %54
  %63 = or i1 %61, %55
  br label %64

64:                                               ; preds = %51
  br i1 %50, label %65, label %70

65:                                               ; preds = %64
  br i1 %63, label %66, label %67

66:                                               ; preds = %65
  br label %73

67:                                               ; preds = %65
  br label %68

68:                                               ; preds = %67
  br label %72

69:                                               ; preds = %70
  br label %72

70:                                               ; preds = %64
  br i1 %62, label %71, label %69

71:                                               ; preds = %70
  br label %73

72:                                               ; preds = %69, %68
  br label %73

73:                                               ; preds = %72, %71, %66
  %74 = phi i1 [ true, %66 ], [ true, %71 ], [ false, %72 ]
  %75 = phi i64 [ undef, %66 ], [ undef, %71 ], [ %52, %72 ]
  %76 = phi i64 [ %52, %66 ], [ %52, %71 ], [ %56, %72 ]
  %77 = phi i64 [ %53, %66 ], [ %53, %71 ], [ %59, %72 ]
  br i1 %74, label %78, label %79

78:                                               ; preds = %73
  br label %644

79:                                               ; preds = %73
  br label %80

80:                                               ; preds = %79
  %81 = load i64, ptr %27, align 8
  %82 = load { ptr, { { i64 }, { {} } } }, ptr %26, align 8
  %83 = load { ptr, { { i64 }, { {} } } }, ptr %25, align 8
  %84 = load float, ptr %24, align 4
  %85 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %23, align 8
  %86 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %85, 0
  %87 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %85, 1, 1, 0
  %88 = mul i64 %75, %87
  br label %89

89:                                               ; preds = %171, %80
  %90 = phi i64 [ 0, %80 ], [ %172, %171 ]
  %91 = phi i64 [ 0, %80 ], [ %105, %171 ]
  %92 = phi i64 [ 0, %80 ], [ %106, %171 ]
  %93 = phi <4 x float> [ zeroinitializer, %80 ], [ %173, %171 ]
  %94 = phi <4 x float> [ zeroinitializer, %80 ], [ %174, %171 ]
  %95 = phi <4 x float> [ zeroinitializer, %80 ], [ %175, %171 ]
  %96 = fadd contract <4 x float> %93, splat (float 1.000000e+00)
  %97 = extractelement <4 x float> %96, i64 0
  %98 = add i64 %91, 256
  %99 = icmp slt i64 %98, %91
  %100 = select i1 %99, i64 1, i64 0
  %101 = icmp sge i64 %91, %81
  %102 = icmp eq i64 %92, 0
  %103 = xor i1 %102, true
  %104 = or i1 %103, %101
  %105 = select i1 %104, i64 %91, i64 %98
  %106 = select i1 %104, i64 %92, i64 %100
  br i1 %104, label %107, label %108

107:                                              ; preds = %89
  br label %176

108:                                              ; preds = %89
  br label %109

109:                                              ; preds = %108
  %110 = add i64 %91, %36
  %111 = add i64 %88, %110
  %112 = getelementptr inbounds float, ptr %86, i64 %111
  %113 = sub i64 %81, %110
  %114 = call i64 @llvm.smin.i64(i64 %113, i64 4)
  %115 = call i64 @llvm.smax.i64(i64 %114, i64 0)
  %116 = icmp eq i64 %114, 4
  %117 = icmp slt i64 %110, %81
  br i1 %117, label %118, label %170

118:                                              ; preds = %109
  br i1 %116, label %119, label %131

119:                                              ; preds = %118
  %120 = load <4 x float>, ptr %112, align 16
  %121 = fsub contract <4 x float> %120, %94
  %122 = fdiv float 1.000000e+00, %97
  %123 = insertelement <4 x float> undef, float %122, i32 0
  %124 = shufflevector <4 x float> %123, <4 x float> undef, <4 x i32> zeroinitializer
  %125 = fmul contract <4 x float> %121, %124
  %126 = fadd contract <4 x float> %94, %125
  %127 = fmul contract <4 x float> %121, %121
  %128 = fmul contract <4 x float> %127, %93
  %129 = fmul contract <4 x float> %128, %124
  %130 = fadd contract <4 x float> %95, %129
  br label %165

131:                                              ; preds = %118
  br label %132

132:                                              ; preds = %141, %131
  %133 = phi i64 [ 0, %131 ], [ %144, %141 ]
  %134 = phi i64 [ %90, %131 ], [ %145, %141 ]
  %135 = phi <4 x float> [ %93, %131 ], [ %150, %141 ]
  %136 = phi <4 x float> [ %94, %131 ], [ %155, %141 ]
  %137 = phi <4 x float> [ %95, %131 ], [ %159, %141 ]
  %138 = icmp slt i64 %133, %115
  br i1 %138, label %139, label %140

139:                                              ; preds = %132
  br label %141

140:                                              ; preds = %132
  br label %160

141:                                              ; preds = %139
  %142 = icmp eq i64 %133, %115
  %143 = add i64 %133, 1
  %144 = select i1 %142, i64 %133, i64 %143
  %145 = add i64 %110, %133
  %146 = add i64 %88, %145
  %147 = getelementptr inbounds float, ptr %86, i64 %146
  %148 = load float, ptr %147, align 4
  %149 = insertelement <4 x float> zeroinitializer, float %148, i64 0
  %150 = fadd contract <4 x float> %135, <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>
  %151 = fsub contract <4 x float> %149, %136
  %152 = call <4 x float> @llvm.maxnum.v4f32(<4 x float> %150, <4 x float> splat (float 1.000000e+00))
  %153 = fdiv <4 x float> <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, %152
  %154 = fmul contract <4 x float> %151, %153
  %155 = fadd contract <4 x float> %136, %154
  %156 = fmul contract <4 x float> %151, %151
  %157 = fmul contract <4 x float> %156, %135
  %158 = fmul contract <4 x float> %157, %153
  %159 = fadd contract <4 x float> %137, %158
  br label %132

160:                                              ; preds = %140
  %161 = phi i64 [ %134, %140 ]
  %162 = phi <4 x float> [ %135, %140 ]
  %163 = phi <4 x float> [ %136, %140 ]
  %164 = phi <4 x float> [ %137, %140 ]
  br label %165

165:                                              ; preds = %160, %119
  %166 = phi i64 [ %161, %160 ], [ %110, %119 ]
  %167 = phi <4 x float> [ %162, %160 ], [ %96, %119 ]
  %168 = phi <4 x float> [ %163, %160 ], [ %126, %119 ]
  %169 = phi <4 x float> [ %164, %160 ], [ %130, %119 ]
  br label %171

170:                                              ; preds = %109
  br label %171

171:                                              ; preds = %170, %165
  %172 = phi i64 [ %90, %170 ], [ %166, %165 ]
  %173 = phi <4 x float> [ %93, %170 ], [ %167, %165 ]
  %174 = phi <4 x float> [ %94, %170 ], [ %168, %165 ]
  %175 = phi <4 x float> [ %95, %170 ], [ %169, %165 ]
  br label %89

176:                                              ; preds = %107
  %177 = phi <4 x float> [ %93, %107 ]
  %178 = phi <4 x float> [ %94, %107 ]
  %179 = phi <4 x float> [ %95, %107 ]
  %180 = insertvalue { <4 x float>, <4 x float>, <4 x float> } undef, <4 x float> %177, 0
  %181 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %180, <4 x float> %178, 1
  %182 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %181, <4 x float> %179, 2
  %183 = call { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } %182)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store { float, float, float } %183, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store { float, float, float } zeroinitializer, ptr %19, align 4
  %184 = load i32, ptr %20, align 4
  %185 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %184, i32 16, i32 31)
  store i32 %185, ptr %19, align 4
  %186 = getelementptr inbounds i32, ptr %19, i32 1
  %187 = getelementptr inbounds i32, ptr %20, i32 1
  %188 = load i32, ptr %187, align 4
  %189 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %188, i32 16, i32 31)
  store i32 %189, ptr %186, align 4
  %190 = getelementptr inbounds i32, ptr %19, i32 2
  %191 = getelementptr inbounds i32, ptr %20, i32 2
  %192 = load i32, ptr %191, align 4
  %193 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %192, i32 16, i32 31)
  store i32 %193, ptr %190, align 4
  %194 = load { float, float, float }, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  %195 = getelementptr { float, float, float }, ptr %20, i32 0, i32 0
  %196 = load float, ptr %195, align 4
  %197 = extractvalue { float, float, float } %194, 0
  %198 = fadd contract float %196, %197
  %199 = call float @llvm.maxnum.f32(float %198, float 1.000000e+00)
  %200 = extractvalue { float, float, float } %194, 1
  %201 = getelementptr { float, float, float }, ptr %20, i32 0, i32 1
  %202 = load float, ptr %201, align 4
  %203 = fsub contract float %200, %202
  %204 = fdiv float %197, %199
  %205 = getelementptr { float, float, float }, ptr %20, i32 0, i32 2
  %206 = extractvalue { float, float, float } %194, 2
  %207 = load float, ptr %205, align 4
  %208 = fadd contract float %207, %206
  %209 = fmul contract float %203, %203
  %210 = fmul contract float %209, %196
  %211 = fmul contract float %210, %204
  %212 = fadd contract float %208, %211
  store float %212, ptr %205, align 4
  %213 = fmul contract float %203, %204
  %214 = load float, ptr %201, align 4
  %215 = fadd contract float %214, %213
  store float %215, ptr %201, align 4
  store float %198, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store { float, float, float } zeroinitializer, ptr %18, align 4
  %216 = load i32, ptr %20, align 4
  %217 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %216, i32 8, i32 31)
  store i32 %217, ptr %18, align 4
  %218 = getelementptr inbounds i32, ptr %18, i32 1
  %219 = load i32, ptr %187, align 4
  %220 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %219, i32 8, i32 31)
  store i32 %220, ptr %218, align 4
  %221 = getelementptr inbounds i32, ptr %18, i32 2
  %222 = load i32, ptr %191, align 4
  %223 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %222, i32 8, i32 31)
  store i32 %223, ptr %221, align 4
  %224 = load { float, float, float }, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  %225 = load float, ptr %195, align 4
  %226 = extractvalue { float, float, float } %224, 0
  %227 = fadd contract float %225, %226
  %228 = call float @llvm.maxnum.f32(float %227, float 1.000000e+00)
  %229 = extractvalue { float, float, float } %224, 1
  %230 = load float, ptr %201, align 4
  %231 = fsub contract float %229, %230
  %232 = fdiv float %226, %228
  %233 = extractvalue { float, float, float } %224, 2
  %234 = load float, ptr %205, align 4
  %235 = fadd contract float %234, %233
  %236 = fmul contract float %231, %231
  %237 = fmul contract float %236, %225
  %238 = fmul contract float %237, %232
  %239 = fadd contract float %235, %238
  store float %239, ptr %205, align 4
  %240 = fmul contract float %231, %232
  %241 = load float, ptr %201, align 4
  %242 = fadd contract float %241, %240
  store float %242, ptr %201, align 4
  store float %227, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store { float, float, float } zeroinitializer, ptr %17, align 4
  %243 = load i32, ptr %20, align 4
  %244 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %243, i32 4, i32 31)
  store i32 %244, ptr %17, align 4
  %245 = getelementptr inbounds i32, ptr %17, i32 1
  %246 = load i32, ptr %187, align 4
  %247 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %246, i32 4, i32 31)
  store i32 %247, ptr %245, align 4
  %248 = getelementptr inbounds i32, ptr %17, i32 2
  %249 = load i32, ptr %191, align 4
  %250 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %249, i32 4, i32 31)
  store i32 %250, ptr %248, align 4
  %251 = load { float, float, float }, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  %252 = load float, ptr %195, align 4
  %253 = extractvalue { float, float, float } %251, 0
  %254 = fadd contract float %252, %253
  %255 = call float @llvm.maxnum.f32(float %254, float 1.000000e+00)
  %256 = extractvalue { float, float, float } %251, 1
  %257 = load float, ptr %201, align 4
  %258 = fsub contract float %256, %257
  %259 = fdiv float %253, %255
  %260 = extractvalue { float, float, float } %251, 2
  %261 = load float, ptr %205, align 4
  %262 = fadd contract float %261, %260
  %263 = fmul contract float %258, %258
  %264 = fmul contract float %263, %252
  %265 = fmul contract float %264, %259
  %266 = fadd contract float %262, %265
  store float %266, ptr %205, align 4
  %267 = fmul contract float %258, %259
  %268 = load float, ptr %201, align 4
  %269 = fadd contract float %268, %267
  store float %269, ptr %201, align 4
  store float %254, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store { float, float, float } zeroinitializer, ptr %16, align 4
  %270 = load i32, ptr %20, align 4
  %271 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %270, i32 2, i32 31)
  store i32 %271, ptr %16, align 4
  %272 = getelementptr inbounds i32, ptr %16, i32 1
  %273 = load i32, ptr %187, align 4
  %274 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %273, i32 2, i32 31)
  store i32 %274, ptr %272, align 4
  %275 = getelementptr inbounds i32, ptr %16, i32 2
  %276 = load i32, ptr %191, align 4
  %277 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %276, i32 2, i32 31)
  store i32 %277, ptr %275, align 4
  %278 = load { float, float, float }, ptr %16, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %279 = load float, ptr %195, align 4
  %280 = extractvalue { float, float, float } %278, 0
  %281 = fadd contract float %279, %280
  %282 = call float @llvm.maxnum.f32(float %281, float 1.000000e+00)
  %283 = extractvalue { float, float, float } %278, 1
  %284 = load float, ptr %201, align 4
  %285 = fsub contract float %283, %284
  %286 = fdiv float %280, %282
  %287 = extractvalue { float, float, float } %278, 2
  %288 = load float, ptr %205, align 4
  %289 = fadd contract float %288, %287
  %290 = fmul contract float %285, %285
  %291 = fmul contract float %290, %279
  %292 = fmul contract float %291, %286
  %293 = fadd contract float %289, %292
  store float %293, ptr %205, align 4
  %294 = fmul contract float %285, %286
  %295 = load float, ptr %201, align 4
  %296 = fadd contract float %295, %294
  store float %296, ptr %201, align 4
  store float %281, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store { float, float, float } zeroinitializer, ptr %15, align 4
  %297 = load i32, ptr %20, align 4
  %298 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %297, i32 1, i32 31)
  store i32 %298, ptr %15, align 4
  %299 = getelementptr inbounds i32, ptr %15, i32 1
  %300 = load i32, ptr %187, align 4
  %301 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %300, i32 1, i32 31)
  store i32 %301, ptr %299, align 4
  %302 = getelementptr inbounds i32, ptr %15, i32 2
  %303 = load i32, ptr %191, align 4
  %304 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %303, i32 1, i32 31)
  store i32 %304, ptr %302, align 4
  %305 = load { float, float, float }, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  %306 = load float, ptr %195, align 4
  %307 = extractvalue { float, float, float } %305, 0
  %308 = fadd contract float %306, %307
  %309 = call float @llvm.maxnum.f32(float %308, float 1.000000e+00)
  %310 = extractvalue { float, float, float } %305, 1
  %311 = load float, ptr %201, align 4
  %312 = fsub contract float %310, %311
  %313 = fdiv float %307, %309
  %314 = extractvalue { float, float, float } %305, 2
  %315 = load float, ptr %205, align 4
  %316 = fadd contract float %315, %314
  %317 = fmul contract float %312, %312
  %318 = fmul contract float %317, %306
  %319 = fmul contract float %318, %313
  %320 = fadd contract float %316, %319
  store float %320, ptr %205, align 4
  %321 = fmul contract float %312, %313
  %322 = load float, ptr %201, align 4
  %323 = fadd contract float %322, %321
  store float %323, ptr %201, align 4
  store float %308, ptr %195, align 4
  %324 = udiv i64 %35, 32
  %325 = trunc i64 %324 to i32
  %326 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w4_bs64_6c9cce32._global_alloc_0._gpu_shared_mem, i32 %325
  %327 = trunc i64 %32 to i32
  %328 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w4_bs64_6c9cce32._global_alloc_0._gpu_shared_mem, i32 %327
  br i1 %37, label %329, label %331

329:                                              ; preds = %176
  %330 = load { float, float, float }, ptr %20, align 4
  store { float, float, float } %330, ptr addrspace(3) %326, align 4
  br label %332

331:                                              ; preds = %176
  br label %332

332:                                              ; preds = %331, %329
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %333 = icmp eq i64 %324, 0
  br i1 %333, label %334, label %478

334:                                              ; preds = %332
  br i1 %33, label %335, label %337

335:                                              ; preds = %334
  %336 = load { float, float, float }, ptr addrspace(3) %328, align 4
  store { float, float, float } %336, ptr %20, align 4
  br label %338

337:                                              ; preds = %334
  store { float, float, float } zeroinitializer, ptr %20, align 4
  br label %338

338:                                              ; preds = %337, %335
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store { float, float, float } zeroinitializer, ptr %14, align 4
  %339 = load i32, ptr %20, align 4
  %340 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %339, i32 16, i32 31)
  store i32 %340, ptr %14, align 4
  %341 = getelementptr inbounds i32, ptr %14, i32 1
  %342 = load i32, ptr %187, align 4
  %343 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %342, i32 16, i32 31)
  store i32 %343, ptr %341, align 4
  %344 = getelementptr inbounds i32, ptr %14, i32 2
  %345 = load i32, ptr %191, align 4
  %346 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %345, i32 16, i32 31)
  store i32 %346, ptr %344, align 4
  %347 = load { float, float, float }, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  %348 = load float, ptr %195, align 4
  %349 = extractvalue { float, float, float } %347, 0
  %350 = fadd contract float %348, %349
  %351 = call float @llvm.maxnum.f32(float %350, float 1.000000e+00)
  %352 = extractvalue { float, float, float } %347, 1
  %353 = load float, ptr %201, align 4
  %354 = fsub contract float %352, %353
  %355 = fdiv float %349, %351
  %356 = extractvalue { float, float, float } %347, 2
  %357 = load float, ptr %205, align 4
  %358 = fadd contract float %357, %356
  %359 = fmul contract float %354, %354
  %360 = fmul contract float %359, %348
  %361 = fmul contract float %360, %355
  %362 = fadd contract float %358, %361
  store float %362, ptr %205, align 4
  %363 = fmul contract float %354, %355
  %364 = load float, ptr %201, align 4
  %365 = fadd contract float %364, %363
  store float %365, ptr %201, align 4
  store float %350, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store { float, float, float } zeroinitializer, ptr %13, align 4
  %366 = load i32, ptr %20, align 4
  %367 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %366, i32 8, i32 31)
  store i32 %367, ptr %13, align 4
  %368 = getelementptr inbounds i32, ptr %13, i32 1
  %369 = load i32, ptr %187, align 4
  %370 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %369, i32 8, i32 31)
  store i32 %370, ptr %368, align 4
  %371 = getelementptr inbounds i32, ptr %13, i32 2
  %372 = load i32, ptr %191, align 4
  %373 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %372, i32 8, i32 31)
  store i32 %373, ptr %371, align 4
  %374 = load { float, float, float }, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %375 = load float, ptr %195, align 4
  %376 = extractvalue { float, float, float } %374, 0
  %377 = fadd contract float %375, %376
  %378 = call float @llvm.maxnum.f32(float %377, float 1.000000e+00)
  %379 = extractvalue { float, float, float } %374, 1
  %380 = load float, ptr %201, align 4
  %381 = fsub contract float %379, %380
  %382 = fdiv float %376, %378
  %383 = extractvalue { float, float, float } %374, 2
  %384 = load float, ptr %205, align 4
  %385 = fadd contract float %384, %383
  %386 = fmul contract float %381, %381
  %387 = fmul contract float %386, %375
  %388 = fmul contract float %387, %382
  %389 = fadd contract float %385, %388
  store float %389, ptr %205, align 4
  %390 = fmul contract float %381, %382
  %391 = load float, ptr %201, align 4
  %392 = fadd contract float %391, %390
  store float %392, ptr %201, align 4
  store float %377, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } zeroinitializer, ptr %12, align 4
  %393 = load i32, ptr %20, align 4
  %394 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %393, i32 4, i32 31)
  store i32 %394, ptr %12, align 4
  %395 = getelementptr inbounds i32, ptr %12, i32 1
  %396 = load i32, ptr %187, align 4
  %397 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %396, i32 4, i32 31)
  store i32 %397, ptr %395, align 4
  %398 = getelementptr inbounds i32, ptr %12, i32 2
  %399 = load i32, ptr %191, align 4
  %400 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %399, i32 4, i32 31)
  store i32 %400, ptr %398, align 4
  %401 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %402 = load float, ptr %195, align 4
  %403 = extractvalue { float, float, float } %401, 0
  %404 = fadd contract float %402, %403
  %405 = call float @llvm.maxnum.f32(float %404, float 1.000000e+00)
  %406 = extractvalue { float, float, float } %401, 1
  %407 = load float, ptr %201, align 4
  %408 = fsub contract float %406, %407
  %409 = fdiv float %403, %405
  %410 = extractvalue { float, float, float } %401, 2
  %411 = load float, ptr %205, align 4
  %412 = fadd contract float %411, %410
  %413 = fmul contract float %408, %408
  %414 = fmul contract float %413, %402
  %415 = fmul contract float %414, %409
  %416 = fadd contract float %412, %415
  store float %416, ptr %205, align 4
  %417 = fmul contract float %408, %409
  %418 = load float, ptr %201, align 4
  %419 = fadd contract float %418, %417
  store float %419, ptr %201, align 4
  store float %404, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %420 = load i32, ptr %20, align 4
  %421 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %420, i32 2, i32 31)
  store i32 %421, ptr %11, align 4
  %422 = getelementptr inbounds i32, ptr %11, i32 1
  %423 = load i32, ptr %187, align 4
  %424 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %423, i32 2, i32 31)
  store i32 %424, ptr %422, align 4
  %425 = getelementptr inbounds i32, ptr %11, i32 2
  %426 = load i32, ptr %191, align 4
  %427 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %426, i32 2, i32 31)
  store i32 %427, ptr %425, align 4
  %428 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %429 = load float, ptr %195, align 4
  %430 = extractvalue { float, float, float } %428, 0
  %431 = fadd contract float %429, %430
  %432 = call float @llvm.maxnum.f32(float %431, float 1.000000e+00)
  %433 = extractvalue { float, float, float } %428, 1
  %434 = load float, ptr %201, align 4
  %435 = fsub contract float %433, %434
  %436 = fdiv float %430, %432
  %437 = extractvalue { float, float, float } %428, 2
  %438 = load float, ptr %205, align 4
  %439 = fadd contract float %438, %437
  %440 = fmul contract float %435, %435
  %441 = fmul contract float %440, %429
  %442 = fmul contract float %441, %436
  %443 = fadd contract float %439, %442
  store float %443, ptr %205, align 4
  %444 = fmul contract float %435, %436
  %445 = load float, ptr %201, align 4
  %446 = fadd contract float %445, %444
  store float %446, ptr %201, align 4
  store float %431, ptr %195, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %447 = load i32, ptr %20, align 4
  %448 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %447, i32 1, i32 31)
  store i32 %448, ptr %10, align 4
  %449 = getelementptr inbounds i32, ptr %10, i32 1
  %450 = load i32, ptr %187, align 4
  %451 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %450, i32 1, i32 31)
  store i32 %451, ptr %449, align 4
  %452 = getelementptr inbounds i32, ptr %10, i32 2
  %453 = load i32, ptr %191, align 4
  %454 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %453, i32 1, i32 31)
  store i32 %454, ptr %452, align 4
  %455 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %456 = load float, ptr %195, align 4
  %457 = extractvalue { float, float, float } %455, 0
  %458 = fadd contract float %456, %457
  %459 = call float @llvm.maxnum.f32(float %458, float 1.000000e+00)
  %460 = extractvalue { float, float, float } %455, 1
  %461 = load float, ptr %201, align 4
  %462 = fsub contract float %460, %461
  %463 = fdiv float %457, %459
  %464 = extractvalue { float, float, float } %455, 2
  %465 = load float, ptr %205, align 4
  %466 = fadd contract float %465, %464
  %467 = fmul contract float %462, %462
  %468 = fmul contract float %467, %456
  %469 = fmul contract float %468, %463
  %470 = fadd contract float %466, %469
  store float %470, ptr %205, align 4
  %471 = fmul contract float %462, %463
  %472 = load float, ptr %201, align 4
  %473 = fadd contract float %472, %471
  store float %473, ptr %201, align 4
  store float %458, ptr %195, align 4
  br i1 %37, label %474, label %476

474:                                              ; preds = %338
  %475 = load { float, float, float }, ptr %20, align 4
  store { float, float, float } %475, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w4_bs64_6c9cce32._global_alloc_0._gpu_shared_mem, align 4
  br label %477

476:                                              ; preds = %338
  br label %477

477:                                              ; preds = %476, %474
  br label %479

478:                                              ; preds = %332
  br label %479

479:                                              ; preds = %478, %477
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %480 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w4_bs64_6c9cce32._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %480, ptr %20, align 4
  %481 = load float, ptr %201, align 4
  store float %481, ptr %201, align 4
  %482 = load float, ptr %205, align 4
  store float %482, ptr %205, align 4
  %483 = load float, ptr %195, align 4
  store float %483, ptr %195, align 4
  %484 = load { float, float, float }, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %20)
  %485 = extractvalue { float, float, float } %484, 0
  %486 = insertelement <4 x float> zeroinitializer, float %485, i64 0
  %487 = extractvalue { float, float, float } %484, 1
  %488 = insertelement <4 x float> zeroinitializer, float %487, i64 0
  %489 = extractvalue { float, float, float } %484, 2
  %490 = insertelement <4 x float> zeroinitializer, float %489, i64 0
  %491 = insertelement <4 x float> %486, float %485, i64 1
  %492 = insertelement <4 x float> %488, float %487, i64 1
  %493 = insertelement <4 x float> %490, float %489, i64 1
  %494 = insertelement <4 x float> %491, float %485, i64 2
  %495 = insertelement <4 x float> %492, float %487, i64 2
  %496 = insertelement <4 x float> %493, float %489, i64 2
  %497 = insertelement <4 x float> %494, float %485, i64 3
  %498 = insertelement <4 x float> %495, float %487, i64 3
  %499 = insertelement <4 x float> %496, float %489, i64 3
  %500 = fdiv <4 x float> %499, %497
  %501 = insertelement <4 x float> undef, float %84, i32 0
  %502 = shufflevector <4 x float> %501, <4 x float> undef, <4 x i32> zeroinitializer
  %503 = fadd contract <4 x float> %500, %502
  %504 = extractelement <4 x float> %503, i64 3
  %505 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %504)
  %506 = extractelement <4 x float> %503, i64 2
  %507 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %506)
  %508 = extractelement <4 x float> %503, i64 1
  %509 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %508)
  %510 = extractelement <4 x float> %503, i64 0
  %511 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %510)
  %512 = insertelement <4 x float> zeroinitializer, float %511, i64 0
  %513 = insertelement <4 x float> %512, float %509, i64 1
  %514 = insertelement <4 x float> %513, float %507, i64 2
  %515 = insertelement <4 x float> %514, float %505, i64 3
  %516 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %22, align 8
  %517 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %516, 0
  %518 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %516, 1, 1, 0
  %519 = extractvalue { ptr, { { i64 }, { {} } } } %82, 0
  %520 = extractvalue { ptr, { { i64 }, { {} } } } %83, 0
  %521 = extractelement <4 x float> %498, i64 0
  %522 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %498, i64 0)
  %523 = extractelement <4 x float> %515, i64 0
  %524 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %515, i64 0)
  %525 = mul i64 %75, %518
  br label %526

526:                                              ; preds = %641, %479
  %527 = phi i64 [ 0, %479 ], [ %642, %641 ]
  %528 = phi i64 [ 0, %479 ], [ %537, %641 ]
  %529 = phi i64 [ 0, %479 ], [ %538, %641 ]
  %530 = add i64 %528, 256
  %531 = icmp slt i64 %530, %528
  %532 = select i1 %531, i64 1, i64 0
  %533 = icmp sge i64 %528, %81
  %534 = icmp eq i64 %529, 0
  %535 = xor i1 %534, true
  %536 = or i1 %535, %533
  %537 = select i1 %536, i64 %528, i64 %530
  %538 = select i1 %536, i64 %529, i64 %532
  br i1 %536, label %539, label %540

539:                                              ; preds = %526
  br label %643

540:                                              ; preds = %526
  br label %541

541:                                              ; preds = %540
  %542 = add i64 %528, %36
  %543 = getelementptr inbounds float, ptr %520, i64 %542
  %544 = ptrtoint ptr %543 to i64
  %545 = insertelement <4 x i64> undef, i64 %544, i32 0
  %546 = shufflevector <4 x i64> %545, <4 x i64> undef, <4 x i32> zeroinitializer
  %547 = add <4 x i64> %546, %30
  %548 = extractelement <4 x i64> %547, i64 1
  %549 = extractelement <4 x i64> %547, i64 3
  %550 = extractelement <4 x i64> %547, i64 2
  %551 = extractelement <4 x i64> %547, i64 0
  %552 = getelementptr inbounds float, ptr %519, i64 %542
  %553 = ptrtoint ptr %552 to i64
  %554 = insertelement <4 x i64> undef, i64 %553, i32 0
  %555 = shufflevector <4 x i64> %554, <4 x i64> undef, <4 x i32> zeroinitializer
  %556 = add <4 x i64> %555, %30
  %557 = extractelement <4 x i64> %556, i64 1
  %558 = extractelement <4 x i64> %556, i64 3
  %559 = extractelement <4 x i64> %556, i64 2
  %560 = extractelement <4 x i64> %556, i64 0
  %561 = add i64 %525, %542
  %562 = getelementptr inbounds float, ptr %517, i64 %561
  %563 = add i64 %88, %542
  %564 = getelementptr inbounds float, ptr %86, i64 %563
  %565 = sub i64 %81, %542
  %566 = call i64 @llvm.smin.i64(i64 %565, i64 4)
  %567 = call i64 @llvm.smax.i64(i64 %566, i64 0)
  %568 = icmp eq i64 %566, 4
  %569 = icmp slt i64 %542, %81
  br i1 %569, label %570, label %640

570:                                              ; preds = %541
  br i1 %568, label %571, label %611

571:                                              ; preds = %570
  %572 = load <4 x float>, ptr %564, align 16
  br i1 %28, label %573, label %575

573:                                              ; preds = %571
  %574 = load <4 x float>, ptr %552, align 4, !invariant.load !1
  br label %588

575:                                              ; preds = %571
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %560, ptr %9, align 8
  %576 = load ptr, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %577 = load float, ptr %576, align 4, !invariant.load !1
  %578 = insertelement <4 x float> zeroinitializer, float %577, i64 0
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %557, ptr %8, align 8
  %579 = load ptr, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %580 = load float, ptr %579, align 4, !invariant.load !1
  %581 = insertelement <4 x float> %578, float %580, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %559, ptr %7, align 8
  %582 = load ptr, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %583 = load float, ptr %582, align 4, !invariant.load !1
  %584 = insertelement <4 x float> %581, float %583, i64 2
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store i64 %558, ptr %6, align 8
  %585 = load ptr, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %586 = load float, ptr %585, align 4, !invariant.load !1
  %587 = insertelement <4 x float> %584, float %586, i64 3
  br label %588

588:                                              ; preds = %575, %573
  %589 = phi <4 x float> [ %587, %575 ], [ %574, %573 ]
  br i1 %28, label %590, label %592

590:                                              ; preds = %588
  %591 = load <4 x float>, ptr %543, align 4, !invariant.load !1
  br label %605

592:                                              ; preds = %588
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %551, ptr %5, align 8
  %593 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %594 = load float, ptr %593, align 4, !invariant.load !1
  %595 = insertelement <4 x float> zeroinitializer, float %594, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %548, ptr %4, align 8
  %596 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %597 = load float, ptr %596, align 4, !invariant.load !1
  %598 = insertelement <4 x float> %595, float %597, i64 1
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %550, ptr %3, align 8
  %599 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %600 = load float, ptr %599, align 4, !invariant.load !1
  %601 = insertelement <4 x float> %598, float %600, i64 2
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %549, ptr %2, align 8
  %602 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %603 = load float, ptr %602, align 4, !invariant.load !1
  %604 = insertelement <4 x float> %601, float %603, i64 3
  br label %605

605:                                              ; preds = %592, %590
  %606 = phi <4 x float> [ %604, %592 ], [ %591, %590 ]
  %607 = fsub contract <4 x float> %572, %522
  %608 = fmul contract <4 x float> %607, %524
  %609 = fmul contract <4 x float> %608, %589
  %610 = fadd contract <4 x float> %609, %606
  store <4 x float> %610, ptr %562, align 16
  br label %638

611:                                              ; preds = %570
  br label %612

612:                                              ; preds = %618, %611
  %613 = phi i64 [ 0, %611 ], [ %621, %618 ]
  %614 = phi i64 [ %527, %611 ], [ %622, %618 ]
  %615 = icmp slt i64 %613, %567
  br i1 %615, label %616, label %617

616:                                              ; preds = %612
  br label %618

617:                                              ; preds = %612
  br label %636

618:                                              ; preds = %616
  %619 = icmp eq i64 %613, %567
  %620 = add i64 %613, 1
  %621 = select i1 %619, i64 %613, i64 %620
  %622 = add i64 %542, %613
  %623 = add i64 %88, %622
  %624 = getelementptr inbounds float, ptr %86, i64 %623
  %625 = load float, ptr %624, align 4
  %626 = getelementptr inbounds float, ptr %519, i64 %622
  %627 = load float, ptr %626, align 4, !invariant.load !1
  %628 = getelementptr inbounds float, ptr %520, i64 %622
  %629 = load float, ptr %628, align 4, !invariant.load !1
  %630 = fsub contract float %625, %521
  %631 = fmul contract float %630, %523
  %632 = fmul contract float %631, %627
  %633 = fadd contract float %632, %629
  %634 = add i64 %525, %622
  %635 = getelementptr inbounds float, ptr %517, i64 %634
  store float %633, ptr %635, align 4
  br label %612

636:                                              ; preds = %617
  %637 = phi i64 [ %614, %617 ]
  br label %638

638:                                              ; preds = %636, %605
  %639 = phi i64 [ %637, %636 ], [ %542, %605 ]
  br label %641

640:                                              ; preds = %541
  br label %641

641:                                              ; preds = %640, %638
  %642 = phi i64 [ %527, %640 ], [ %639, %638 ]
  br label %526

643:                                              ; preds = %539
  br label %51

644:                                              ; preds = %78
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

attributes #0 = { convergent norecurse "nvvm.maxntid"="64" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
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
