; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [32 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %21 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %22 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %21, i32 0, i32 5
  %23 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %21, i32 0, i32 4
  %24 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %21, i32 0, i32 3
  %25 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %21, i32 0, i32 2
  %26 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %21, i32 0, i32 1
  %27 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %21, i32 0, i32 0
  %28 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 2
  %29 = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> splat (i1 true))
  %30 = call <4 x i64> @llvm.stepvector.v4i64()
  %31 = mul <4 x i64> %30, splat (i64 4)
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %33 = sext i32 %32 to i64
  %34 = icmp slt i64 %33, 32
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %36 = zext i32 %35 to i64
  %37 = mul i64 %36, 4
  %38 = icmp eq i64 %33, 0
  %39 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %40 = load { i64, i64, i64, i64, i64 }, ptr %39, align 8
  %41 = extractvalue { i64, i64, i64, i64, i64 } %40, 0
  %42 = extractvalue { i64, i64, i64, i64, i64 } %40, 1
  %43 = mul i64 %41, %42
  %44 = extractvalue { i64, i64, i64, i64, i64 } %40, 2
  %45 = mul i64 %43, %44
  %46 = extractvalue { i64, i64, i64, i64, i64 } %40, 3
  %47 = mul i64 %45, %46
  %48 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %49 = zext i32 %48 to i64
  %50 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %51 = sext i32 %50 to i64
  %52 = icmp eq i64 %51, 0
  %53 = select i1 %52, i64 0, i64 %49
  %54 = select i1 %52, i64 0, i64 %47
  %55 = select i1 %52, i64 1, i64 %51
  %56 = icmp slt i64 %55, 0
  %57 = icmp sgt i64 %55, 0
  br label %58

58:                                               ; preds = %740, %1
  %59 = phi i64 [ %53, %1 ], [ %83, %740 ]
  %60 = phi i64 [ 0, %1 ], [ %84, %740 ]
  %61 = icmp sge i64 %54, %59
  %62 = icmp sge i64 %59, %54
  %63 = add i64 %59, %55
  %64 = icmp slt i64 %63, %59
  %65 = xor i1 %64, %56
  %66 = select i1 %65, i64 1, i64 0
  %67 = icmp eq i64 %60, 0
  %68 = xor i1 %67, true
  %69 = or i1 %68, %61
  %70 = or i1 %68, %62
  br label %71

71:                                               ; preds = %58
  br i1 %57, label %72, label %77

72:                                               ; preds = %71
  br i1 %70, label %73, label %74

73:                                               ; preds = %72
  br label %80

74:                                               ; preds = %72
  br label %75

75:                                               ; preds = %74
  br label %79

76:                                               ; preds = %77
  br label %79

77:                                               ; preds = %71
  br i1 %69, label %78, label %76

78:                                               ; preds = %77
  br label %80

79:                                               ; preds = %76, %75
  br label %80

80:                                               ; preds = %79, %78, %73
  %81 = phi i1 [ true, %73 ], [ true, %78 ], [ false, %79 ]
  %82 = phi i64 [ undef, %73 ], [ undef, %78 ], [ %59, %79 ]
  %83 = phi i64 [ %59, %73 ], [ %59, %78 ], [ %63, %79 ]
  %84 = phi i64 [ %60, %73 ], [ %60, %78 ], [ %66, %79 ]
  br i1 %81, label %85, label %86

85:                                               ; preds = %80
  br label %741

86:                                               ; preds = %80
  br label %87

87:                                               ; preds = %86
  %88 = load [3 x { i32, i32, i8, i8, i1, i8 }], ptr %28, align 4
  %89 = trunc i64 %82 to i32
  %90 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 2, 0
  %91 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 2, 1
  %92 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 2, 2
  %93 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 2, 3
  %94 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 2, 4
  %95 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 2, 5
  %96 = zext i8 %93 to i32
  %97 = zext i8 %92 to i32
  %98 = zext i32 %89 to i64
  %99 = zext i32 %91 to i64
  %100 = mul i64 %99, %98
  %101 = zext i8 %95 to i32
  %102 = lshr i32 %89, %101
  %103 = lshr i64 %100, 32
  %104 = trunc i64 %103 to i32
  %105 = sub i32 %89, %104
  %106 = lshr i32 %105, %97
  %107 = add i32 %104, %106
  %108 = lshr i32 %107, %96
  %109 = select i1 %94, i32 %102, i32 %108
  %110 = mul i32 %109, %90
  %111 = sub i32 %89, %110
  %112 = zext i32 %111 to i64
  %113 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 1, 0
  %114 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 1, 1
  %115 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 1, 2
  %116 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 1, 3
  %117 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 1, 4
  %118 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 1, 5
  %119 = zext i8 %116 to i32
  %120 = zext i8 %115 to i32
  %121 = zext i32 %109 to i64
  %122 = zext i32 %114 to i64
  %123 = mul i64 %122, %121
  %124 = zext i8 %118 to i32
  %125 = lshr i32 %109, %124
  %126 = lshr i64 %123, 32
  %127 = trunc i64 %126 to i32
  %128 = sub i32 %109, %127
  %129 = lshr i32 %128, %120
  %130 = add i32 %127, %129
  %131 = lshr i32 %130, %119
  %132 = select i1 %117, i32 %125, i32 %131
  %133 = mul i32 %132, %113
  %134 = sub i32 %109, %133
  %135 = zext i32 %134 to i64
  %136 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 0, 0
  %137 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 0, 1
  %138 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 0, 2
  %139 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 0, 3
  %140 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 0, 4
  %141 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %88, 0, 5
  %142 = zext i8 %139 to i32
  %143 = zext i8 %138 to i32
  %144 = zext i32 %132 to i64
  %145 = zext i32 %137 to i64
  %146 = mul i64 %145, %144
  %147 = zext i8 %141 to i32
  %148 = lshr i32 %132, %147
  %149 = lshr i64 %146, 32
  %150 = trunc i64 %149 to i32
  %151 = sub i32 %132, %150
  %152 = lshr i32 %151, %143
  %153 = add i32 %150, %152
  %154 = lshr i32 %153, %142
  %155 = select i1 %140, i32 %148, i32 %154
  %156 = mul i32 %155, %136
  %157 = sub i32 %132, %156
  %158 = zext i32 %157 to i64
  %159 = zext i32 %155 to i64
  %160 = load i64, ptr %27, align 8
  %161 = load { ptr, { { i64 }, { {} } } }, ptr %26, align 8
  %162 = load { ptr, { { i64 }, { {} } } }, ptr %25, align 8
  %163 = load float, ptr %24, align 4
  %164 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %23, align 8
  %165 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %164, 0
  %166 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %164, 1, 1, 0
  %167 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %164, 1, 1, 1
  %168 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %164, 1, 1, 2
  %169 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %164, 1, 1, 3
  %170 = mul i64 %159, %166
  %171 = mul i64 %158, %167
  %172 = add i64 %170, %171
  %173 = mul i64 %135, %168
  %174 = add i64 %172, %173
  %175 = mul i64 %112, %169
  %176 = add i64 %174, %175
  br label %177

177:                                              ; preds = %259, %87
  %178 = phi i64 [ 0, %87 ], [ %260, %259 ]
  %179 = phi i64 [ 0, %87 ], [ %193, %259 ]
  %180 = phi i64 [ 0, %87 ], [ %194, %259 ]
  %181 = phi <4 x float> [ zeroinitializer, %87 ], [ %261, %259 ]
  %182 = phi <4 x float> [ zeroinitializer, %87 ], [ %262, %259 ]
  %183 = phi <4 x float> [ zeroinitializer, %87 ], [ %263, %259 ]
  %184 = fadd contract <4 x float> %181, splat (float 1.000000e+00)
  %185 = extractelement <4 x float> %184, i64 0
  %186 = add i64 %179, 4096
  %187 = icmp slt i64 %186, %179
  %188 = select i1 %187, i64 1, i64 0
  %189 = icmp sge i64 %179, %160
  %190 = icmp eq i64 %180, 0
  %191 = xor i1 %190, true
  %192 = or i1 %191, %189
  %193 = select i1 %192, i64 %179, i64 %186
  %194 = select i1 %192, i64 %180, i64 %188
  br i1 %192, label %195, label %196

195:                                              ; preds = %177
  br label %264

196:                                              ; preds = %177
  br label %197

197:                                              ; preds = %196
  %198 = add i64 %179, %37
  %199 = add i64 %176, %198
  %200 = getelementptr inbounds float, ptr %165, i64 %199
  %201 = sub i64 %160, %198
  %202 = call i64 @llvm.smin.i64(i64 %201, i64 4)
  %203 = call i64 @llvm.smax.i64(i64 %202, i64 0)
  %204 = icmp eq i64 %202, 4
  %205 = icmp slt i64 %198, %160
  br i1 %205, label %206, label %258

206:                                              ; preds = %197
  br i1 %204, label %207, label %219

207:                                              ; preds = %206
  %208 = load <4 x float>, ptr %200, align 16
  %209 = fsub contract <4 x float> %208, %182
  %210 = fdiv float 1.000000e+00, %185
  %211 = insertelement <4 x float> undef, float %210, i32 0
  %212 = shufflevector <4 x float> %211, <4 x float> undef, <4 x i32> zeroinitializer
  %213 = fmul contract <4 x float> %209, %212
  %214 = fadd contract <4 x float> %182, %213
  %215 = fmul contract <4 x float> %209, %209
  %216 = fmul contract <4 x float> %215, %181
  %217 = fmul contract <4 x float> %216, %212
  %218 = fadd contract <4 x float> %183, %217
  br label %253

219:                                              ; preds = %206
  br label %220

220:                                              ; preds = %229, %219
  %221 = phi i64 [ 0, %219 ], [ %232, %229 ]
  %222 = phi i64 [ %178, %219 ], [ %233, %229 ]
  %223 = phi <4 x float> [ %181, %219 ], [ %238, %229 ]
  %224 = phi <4 x float> [ %182, %219 ], [ %243, %229 ]
  %225 = phi <4 x float> [ %183, %219 ], [ %247, %229 ]
  %226 = icmp slt i64 %221, %203
  br i1 %226, label %227, label %228

227:                                              ; preds = %220
  br label %229

228:                                              ; preds = %220
  br label %248

229:                                              ; preds = %227
  %230 = icmp eq i64 %221, %203
  %231 = add i64 %221, 1
  %232 = select i1 %230, i64 %221, i64 %231
  %233 = add i64 %198, %221
  %234 = add i64 %176, %233
  %235 = getelementptr inbounds float, ptr %165, i64 %234
  %236 = load float, ptr %235, align 4
  %237 = insertelement <4 x float> zeroinitializer, float %236, i64 0
  %238 = fadd contract <4 x float> %223, <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>
  %239 = fsub contract <4 x float> %237, %224
  %240 = call <4 x float> @llvm.maxnum.v4f32(<4 x float> %238, <4 x float> splat (float 1.000000e+00))
  %241 = fdiv <4 x float> <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, %240
  %242 = fmul contract <4 x float> %239, %241
  %243 = fadd contract <4 x float> %224, %242
  %244 = fmul contract <4 x float> %239, %239
  %245 = fmul contract <4 x float> %244, %223
  %246 = fmul contract <4 x float> %245, %241
  %247 = fadd contract <4 x float> %225, %246
  br label %220

248:                                              ; preds = %228
  %249 = phi i64 [ %222, %228 ]
  %250 = phi <4 x float> [ %223, %228 ]
  %251 = phi <4 x float> [ %224, %228 ]
  %252 = phi <4 x float> [ %225, %228 ]
  br label %253

253:                                              ; preds = %248, %207
  %254 = phi i64 [ %249, %248 ], [ %198, %207 ]
  %255 = phi <4 x float> [ %250, %248 ], [ %184, %207 ]
  %256 = phi <4 x float> [ %251, %248 ], [ %214, %207 ]
  %257 = phi <4 x float> [ %252, %248 ], [ %218, %207 ]
  br label %259

258:                                              ; preds = %197
  br label %259

259:                                              ; preds = %258, %253
  %260 = phi i64 [ %178, %258 ], [ %254, %253 ]
  %261 = phi <4 x float> [ %181, %258 ], [ %255, %253 ]
  %262 = phi <4 x float> [ %182, %258 ], [ %256, %253 ]
  %263 = phi <4 x float> [ %183, %258 ], [ %257, %253 ]
  br label %177

264:                                              ; preds = %195
  %265 = phi <4 x float> [ %181, %195 ]
  %266 = phi <4 x float> [ %182, %195 ]
  %267 = phi <4 x float> [ %183, %195 ]
  %268 = insertvalue { <4 x float>, <4 x float>, <4 x float> } undef, <4 x float> %265, 0
  %269 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %268, <4 x float> %266, 1
  %270 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %269, <4 x float> %267, 2
  %271 = call { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } %270)
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store { float, float, float } %271, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store { float, float, float } zeroinitializer, ptr %19, align 4
  %272 = load i32, ptr %20, align 4
  %273 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %272, i32 16, i32 31)
  store i32 %273, ptr %19, align 4
  %274 = getelementptr inbounds i32, ptr %19, i32 1
  %275 = getelementptr inbounds i32, ptr %20, i32 1
  %276 = load i32, ptr %275, align 4
  %277 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %276, i32 16, i32 31)
  store i32 %277, ptr %274, align 4
  %278 = getelementptr inbounds i32, ptr %19, i32 2
  %279 = getelementptr inbounds i32, ptr %20, i32 2
  %280 = load i32, ptr %279, align 4
  %281 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %280, i32 16, i32 31)
  store i32 %281, ptr %278, align 4
  %282 = load { float, float, float }, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %19)
  %283 = getelementptr { float, float, float }, ptr %20, i32 0, i32 0
  %284 = load float, ptr %283, align 4
  %285 = extractvalue { float, float, float } %282, 0
  %286 = fadd contract float %284, %285
  %287 = call float @llvm.maxnum.f32(float %286, float 1.000000e+00)
  %288 = extractvalue { float, float, float } %282, 1
  %289 = getelementptr { float, float, float }, ptr %20, i32 0, i32 1
  %290 = load float, ptr %289, align 4
  %291 = fsub contract float %288, %290
  %292 = fdiv float %285, %287
  %293 = getelementptr { float, float, float }, ptr %20, i32 0, i32 2
  %294 = extractvalue { float, float, float } %282, 2
  %295 = load float, ptr %293, align 4
  %296 = fadd contract float %295, %294
  %297 = fmul contract float %291, %291
  %298 = fmul contract float %297, %284
  %299 = fmul contract float %298, %292
  %300 = fadd contract float %296, %299
  store float %300, ptr %293, align 4
  %301 = fmul contract float %291, %292
  %302 = load float, ptr %289, align 4
  %303 = fadd contract float %302, %301
  store float %303, ptr %289, align 4
  store float %286, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store { float, float, float } zeroinitializer, ptr %18, align 4
  %304 = load i32, ptr %20, align 4
  %305 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %304, i32 8, i32 31)
  store i32 %305, ptr %18, align 4
  %306 = getelementptr inbounds i32, ptr %18, i32 1
  %307 = load i32, ptr %275, align 4
  %308 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %307, i32 8, i32 31)
  store i32 %308, ptr %306, align 4
  %309 = getelementptr inbounds i32, ptr %18, i32 2
  %310 = load i32, ptr %279, align 4
  %311 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %310, i32 8, i32 31)
  store i32 %311, ptr %309, align 4
  %312 = load { float, float, float }, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  %313 = load float, ptr %283, align 4
  %314 = extractvalue { float, float, float } %312, 0
  %315 = fadd contract float %313, %314
  %316 = call float @llvm.maxnum.f32(float %315, float 1.000000e+00)
  %317 = extractvalue { float, float, float } %312, 1
  %318 = load float, ptr %289, align 4
  %319 = fsub contract float %317, %318
  %320 = fdiv float %314, %316
  %321 = extractvalue { float, float, float } %312, 2
  %322 = load float, ptr %293, align 4
  %323 = fadd contract float %322, %321
  %324 = fmul contract float %319, %319
  %325 = fmul contract float %324, %313
  %326 = fmul contract float %325, %320
  %327 = fadd contract float %323, %326
  store float %327, ptr %293, align 4
  %328 = fmul contract float %319, %320
  %329 = load float, ptr %289, align 4
  %330 = fadd contract float %329, %328
  store float %330, ptr %289, align 4
  store float %315, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store { float, float, float } zeroinitializer, ptr %17, align 4
  %331 = load i32, ptr %20, align 4
  %332 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %331, i32 4, i32 31)
  store i32 %332, ptr %17, align 4
  %333 = getelementptr inbounds i32, ptr %17, i32 1
  %334 = load i32, ptr %275, align 4
  %335 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %334, i32 4, i32 31)
  store i32 %335, ptr %333, align 4
  %336 = getelementptr inbounds i32, ptr %17, i32 2
  %337 = load i32, ptr %279, align 4
  %338 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %337, i32 4, i32 31)
  store i32 %338, ptr %336, align 4
  %339 = load { float, float, float }, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  %340 = load float, ptr %283, align 4
  %341 = extractvalue { float, float, float } %339, 0
  %342 = fadd contract float %340, %341
  %343 = call float @llvm.maxnum.f32(float %342, float 1.000000e+00)
  %344 = extractvalue { float, float, float } %339, 1
  %345 = load float, ptr %289, align 4
  %346 = fsub contract float %344, %345
  %347 = fdiv float %341, %343
  %348 = extractvalue { float, float, float } %339, 2
  %349 = load float, ptr %293, align 4
  %350 = fadd contract float %349, %348
  %351 = fmul contract float %346, %346
  %352 = fmul contract float %351, %340
  %353 = fmul contract float %352, %347
  %354 = fadd contract float %350, %353
  store float %354, ptr %293, align 4
  %355 = fmul contract float %346, %347
  %356 = load float, ptr %289, align 4
  %357 = fadd contract float %356, %355
  store float %357, ptr %289, align 4
  store float %342, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store { float, float, float } zeroinitializer, ptr %16, align 4
  %358 = load i32, ptr %20, align 4
  %359 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %358, i32 2, i32 31)
  store i32 %359, ptr %16, align 4
  %360 = getelementptr inbounds i32, ptr %16, i32 1
  %361 = load i32, ptr %275, align 4
  %362 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %361, i32 2, i32 31)
  store i32 %362, ptr %360, align 4
  %363 = getelementptr inbounds i32, ptr %16, i32 2
  %364 = load i32, ptr %279, align 4
  %365 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %364, i32 2, i32 31)
  store i32 %365, ptr %363, align 4
  %366 = load { float, float, float }, ptr %16, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %367 = load float, ptr %283, align 4
  %368 = extractvalue { float, float, float } %366, 0
  %369 = fadd contract float %367, %368
  %370 = call float @llvm.maxnum.f32(float %369, float 1.000000e+00)
  %371 = extractvalue { float, float, float } %366, 1
  %372 = load float, ptr %289, align 4
  %373 = fsub contract float %371, %372
  %374 = fdiv float %368, %370
  %375 = extractvalue { float, float, float } %366, 2
  %376 = load float, ptr %293, align 4
  %377 = fadd contract float %376, %375
  %378 = fmul contract float %373, %373
  %379 = fmul contract float %378, %367
  %380 = fmul contract float %379, %374
  %381 = fadd contract float %377, %380
  store float %381, ptr %293, align 4
  %382 = fmul contract float %373, %374
  %383 = load float, ptr %289, align 4
  %384 = fadd contract float %383, %382
  store float %384, ptr %289, align 4
  store float %369, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store { float, float, float } zeroinitializer, ptr %15, align 4
  %385 = load i32, ptr %20, align 4
  %386 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %385, i32 1, i32 31)
  store i32 %386, ptr %15, align 4
  %387 = getelementptr inbounds i32, ptr %15, i32 1
  %388 = load i32, ptr %275, align 4
  %389 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %388, i32 1, i32 31)
  store i32 %389, ptr %387, align 4
  %390 = getelementptr inbounds i32, ptr %15, i32 2
  %391 = load i32, ptr %279, align 4
  %392 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %391, i32 1, i32 31)
  store i32 %392, ptr %390, align 4
  %393 = load { float, float, float }, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  %394 = load float, ptr %283, align 4
  %395 = extractvalue { float, float, float } %393, 0
  %396 = fadd contract float %394, %395
  %397 = call float @llvm.maxnum.f32(float %396, float 1.000000e+00)
  %398 = extractvalue { float, float, float } %393, 1
  %399 = load float, ptr %289, align 4
  %400 = fsub contract float %398, %399
  %401 = fdiv float %395, %397
  %402 = extractvalue { float, float, float } %393, 2
  %403 = load float, ptr %293, align 4
  %404 = fadd contract float %403, %402
  %405 = fmul contract float %400, %400
  %406 = fmul contract float %405, %394
  %407 = fmul contract float %406, %401
  %408 = fadd contract float %404, %407
  store float %408, ptr %293, align 4
  %409 = fmul contract float %400, %401
  %410 = load float, ptr %289, align 4
  %411 = fadd contract float %410, %409
  store float %411, ptr %289, align 4
  store float %396, ptr %283, align 4
  %412 = udiv i64 %36, 32
  %413 = trunc i64 %412 to i32
  %414 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0._global_alloc_0._gpu_shared_mem, i32 %413
  %415 = trunc i64 %33 to i32
  %416 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0._global_alloc_0._gpu_shared_mem, i32 %415
  br i1 %38, label %417, label %419

417:                                              ; preds = %264
  %418 = load { float, float, float }, ptr %20, align 4
  store { float, float, float } %418, ptr addrspace(3) %414, align 4
  br label %420

419:                                              ; preds = %264
  br label %420

420:                                              ; preds = %419, %417
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %421 = icmp eq i64 %412, 0
  br i1 %421, label %422, label %566

422:                                              ; preds = %420
  br i1 %34, label %423, label %425

423:                                              ; preds = %422
  %424 = load { float, float, float }, ptr addrspace(3) %416, align 4
  store { float, float, float } %424, ptr %20, align 4
  br label %426

425:                                              ; preds = %422
  store { float, float, float } zeroinitializer, ptr %20, align 4
  br label %426

426:                                              ; preds = %425, %423
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store { float, float, float } zeroinitializer, ptr %14, align 4
  %427 = load i32, ptr %20, align 4
  %428 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %427, i32 16, i32 31)
  store i32 %428, ptr %14, align 4
  %429 = getelementptr inbounds i32, ptr %14, i32 1
  %430 = load i32, ptr %275, align 4
  %431 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %430, i32 16, i32 31)
  store i32 %431, ptr %429, align 4
  %432 = getelementptr inbounds i32, ptr %14, i32 2
  %433 = load i32, ptr %279, align 4
  %434 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %433, i32 16, i32 31)
  store i32 %434, ptr %432, align 4
  %435 = load { float, float, float }, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  %436 = load float, ptr %283, align 4
  %437 = extractvalue { float, float, float } %435, 0
  %438 = fadd contract float %436, %437
  %439 = call float @llvm.maxnum.f32(float %438, float 1.000000e+00)
  %440 = extractvalue { float, float, float } %435, 1
  %441 = load float, ptr %289, align 4
  %442 = fsub contract float %440, %441
  %443 = fdiv float %437, %439
  %444 = extractvalue { float, float, float } %435, 2
  %445 = load float, ptr %293, align 4
  %446 = fadd contract float %445, %444
  %447 = fmul contract float %442, %442
  %448 = fmul contract float %447, %436
  %449 = fmul contract float %448, %443
  %450 = fadd contract float %446, %449
  store float %450, ptr %293, align 4
  %451 = fmul contract float %442, %443
  %452 = load float, ptr %289, align 4
  %453 = fadd contract float %452, %451
  store float %453, ptr %289, align 4
  store float %438, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store { float, float, float } zeroinitializer, ptr %13, align 4
  %454 = load i32, ptr %20, align 4
  %455 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %454, i32 8, i32 31)
  store i32 %455, ptr %13, align 4
  %456 = getelementptr inbounds i32, ptr %13, i32 1
  %457 = load i32, ptr %275, align 4
  %458 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %457, i32 8, i32 31)
  store i32 %458, ptr %456, align 4
  %459 = getelementptr inbounds i32, ptr %13, i32 2
  %460 = load i32, ptr %279, align 4
  %461 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %460, i32 8, i32 31)
  store i32 %461, ptr %459, align 4
  %462 = load { float, float, float }, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %463 = load float, ptr %283, align 4
  %464 = extractvalue { float, float, float } %462, 0
  %465 = fadd contract float %463, %464
  %466 = call float @llvm.maxnum.f32(float %465, float 1.000000e+00)
  %467 = extractvalue { float, float, float } %462, 1
  %468 = load float, ptr %289, align 4
  %469 = fsub contract float %467, %468
  %470 = fdiv float %464, %466
  %471 = extractvalue { float, float, float } %462, 2
  %472 = load float, ptr %293, align 4
  %473 = fadd contract float %472, %471
  %474 = fmul contract float %469, %469
  %475 = fmul contract float %474, %463
  %476 = fmul contract float %475, %470
  %477 = fadd contract float %473, %476
  store float %477, ptr %293, align 4
  %478 = fmul contract float %469, %470
  %479 = load float, ptr %289, align 4
  %480 = fadd contract float %479, %478
  store float %480, ptr %289, align 4
  store float %465, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } zeroinitializer, ptr %12, align 4
  %481 = load i32, ptr %20, align 4
  %482 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %481, i32 4, i32 31)
  store i32 %482, ptr %12, align 4
  %483 = getelementptr inbounds i32, ptr %12, i32 1
  %484 = load i32, ptr %275, align 4
  %485 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %484, i32 4, i32 31)
  store i32 %485, ptr %483, align 4
  %486 = getelementptr inbounds i32, ptr %12, i32 2
  %487 = load i32, ptr %279, align 4
  %488 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %487, i32 4, i32 31)
  store i32 %488, ptr %486, align 4
  %489 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %490 = load float, ptr %283, align 4
  %491 = extractvalue { float, float, float } %489, 0
  %492 = fadd contract float %490, %491
  %493 = call float @llvm.maxnum.f32(float %492, float 1.000000e+00)
  %494 = extractvalue { float, float, float } %489, 1
  %495 = load float, ptr %289, align 4
  %496 = fsub contract float %494, %495
  %497 = fdiv float %491, %493
  %498 = extractvalue { float, float, float } %489, 2
  %499 = load float, ptr %293, align 4
  %500 = fadd contract float %499, %498
  %501 = fmul contract float %496, %496
  %502 = fmul contract float %501, %490
  %503 = fmul contract float %502, %497
  %504 = fadd contract float %500, %503
  store float %504, ptr %293, align 4
  %505 = fmul contract float %496, %497
  %506 = load float, ptr %289, align 4
  %507 = fadd contract float %506, %505
  store float %507, ptr %289, align 4
  store float %492, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %508 = load i32, ptr %20, align 4
  %509 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %508, i32 2, i32 31)
  store i32 %509, ptr %11, align 4
  %510 = getelementptr inbounds i32, ptr %11, i32 1
  %511 = load i32, ptr %275, align 4
  %512 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %511, i32 2, i32 31)
  store i32 %512, ptr %510, align 4
  %513 = getelementptr inbounds i32, ptr %11, i32 2
  %514 = load i32, ptr %279, align 4
  %515 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %514, i32 2, i32 31)
  store i32 %515, ptr %513, align 4
  %516 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %517 = load float, ptr %283, align 4
  %518 = extractvalue { float, float, float } %516, 0
  %519 = fadd contract float %517, %518
  %520 = call float @llvm.maxnum.f32(float %519, float 1.000000e+00)
  %521 = extractvalue { float, float, float } %516, 1
  %522 = load float, ptr %289, align 4
  %523 = fsub contract float %521, %522
  %524 = fdiv float %518, %520
  %525 = extractvalue { float, float, float } %516, 2
  %526 = load float, ptr %293, align 4
  %527 = fadd contract float %526, %525
  %528 = fmul contract float %523, %523
  %529 = fmul contract float %528, %517
  %530 = fmul contract float %529, %524
  %531 = fadd contract float %527, %530
  store float %531, ptr %293, align 4
  %532 = fmul contract float %523, %524
  %533 = load float, ptr %289, align 4
  %534 = fadd contract float %533, %532
  store float %534, ptr %289, align 4
  store float %519, ptr %283, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %535 = load i32, ptr %20, align 4
  %536 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %535, i32 1, i32 31)
  store i32 %536, ptr %10, align 4
  %537 = getelementptr inbounds i32, ptr %10, i32 1
  %538 = load i32, ptr %275, align 4
  %539 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %538, i32 1, i32 31)
  store i32 %539, ptr %537, align 4
  %540 = getelementptr inbounds i32, ptr %10, i32 2
  %541 = load i32, ptr %279, align 4
  %542 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %541, i32 1, i32 31)
  store i32 %542, ptr %540, align 4
  %543 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %544 = load float, ptr %283, align 4
  %545 = extractvalue { float, float, float } %543, 0
  %546 = fadd contract float %544, %545
  %547 = call float @llvm.maxnum.f32(float %546, float 1.000000e+00)
  %548 = extractvalue { float, float, float } %543, 1
  %549 = load float, ptr %289, align 4
  %550 = fsub contract float %548, %549
  %551 = fdiv float %545, %547
  %552 = extractvalue { float, float, float } %543, 2
  %553 = load float, ptr %293, align 4
  %554 = fadd contract float %553, %552
  %555 = fmul contract float %550, %550
  %556 = fmul contract float %555, %544
  %557 = fmul contract float %556, %551
  %558 = fadd contract float %554, %557
  store float %558, ptr %293, align 4
  %559 = fmul contract float %550, %551
  %560 = load float, ptr %289, align 4
  %561 = fadd contract float %560, %559
  store float %561, ptr %289, align 4
  store float %546, ptr %283, align 4
  br i1 %38, label %562, label %564

562:                                              ; preds = %426
  %563 = load { float, float, float }, ptr %20, align 4
  store { float, float, float } %563, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0._global_alloc_0._gpu_shared_mem, align 4
  br label %565

564:                                              ; preds = %426
  br label %565

565:                                              ; preds = %564, %562
  br label %567

566:                                              ; preds = %420
  br label %567

567:                                              ; preds = %566, %565
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %568 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %568, ptr %20, align 4
  %569 = load float, ptr %289, align 4
  store float %569, ptr %289, align 4
  %570 = load float, ptr %293, align 4
  store float %570, ptr %293, align 4
  %571 = load float, ptr %283, align 4
  store float %571, ptr %283, align 4
  %572 = load { float, float, float }, ptr %20, align 4
  call void @llvm.lifetime.end.p0(ptr %20)
  %573 = extractvalue { float, float, float } %572, 0
  %574 = insertelement <4 x float> zeroinitializer, float %573, i64 0
  %575 = extractvalue { float, float, float } %572, 1
  %576 = insertelement <4 x float> zeroinitializer, float %575, i64 0
  %577 = extractvalue { float, float, float } %572, 2
  %578 = insertelement <4 x float> zeroinitializer, float %577, i64 0
  %579 = insertelement <4 x float> %574, float %573, i64 1
  %580 = insertelement <4 x float> %576, float %575, i64 1
  %581 = insertelement <4 x float> %578, float %577, i64 1
  %582 = insertelement <4 x float> %579, float %573, i64 2
  %583 = insertelement <4 x float> %580, float %575, i64 2
  %584 = insertelement <4 x float> %581, float %577, i64 2
  %585 = insertelement <4 x float> %582, float %573, i64 3
  %586 = insertelement <4 x float> %583, float %575, i64 3
  %587 = insertelement <4 x float> %584, float %577, i64 3
  %588 = fdiv <4 x float> %587, %585
  %589 = insertelement <4 x float> undef, float %163, i32 0
  %590 = shufflevector <4 x float> %589, <4 x float> undef, <4 x i32> zeroinitializer
  %591 = fadd contract <4 x float> %588, %590
  %592 = extractelement <4 x float> %591, i64 3
  %593 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %592)
  %594 = extractelement <4 x float> %591, i64 2
  %595 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %594)
  %596 = extractelement <4 x float> %591, i64 1
  %597 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %596)
  %598 = extractelement <4 x float> %591, i64 0
  %599 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %598)
  %600 = insertelement <4 x float> zeroinitializer, float %599, i64 0
  %601 = insertelement <4 x float> %600, float %597, i64 1
  %602 = insertelement <4 x float> %601, float %595, i64 2
  %603 = insertelement <4 x float> %602, float %593, i64 3
  %604 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %22, align 8
  %605 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %604, 0
  %606 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %604, 1, 1, 0
  %607 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %604, 1, 1, 1
  %608 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %604, 1, 1, 2
  %609 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %604, 1, 1, 3
  %610 = extractvalue { ptr, { { i64 }, { {} } } } %161, 0
  %611 = extractvalue { ptr, { { i64 }, { {} } } } %162, 0
  %612 = extractelement <4 x float> %586, i64 0
  %613 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %586, i64 0)
  %614 = extractelement <4 x float> %603, i64 0
  %615 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %603, i64 0)
  %616 = mul i64 %159, %606
  %617 = mul i64 %158, %607
  %618 = add i64 %616, %617
  %619 = mul i64 %135, %608
  %620 = add i64 %618, %619
  %621 = mul i64 %112, %609
  %622 = add i64 %620, %621
  br label %623

623:                                              ; preds = %738, %567
  %624 = phi i64 [ 0, %567 ], [ %739, %738 ]
  %625 = phi i64 [ 0, %567 ], [ %634, %738 ]
  %626 = phi i64 [ 0, %567 ], [ %635, %738 ]
  %627 = add i64 %625, 4096
  %628 = icmp slt i64 %627, %625
  %629 = select i1 %628, i64 1, i64 0
  %630 = icmp sge i64 %625, %160
  %631 = icmp eq i64 %626, 0
  %632 = xor i1 %631, true
  %633 = or i1 %632, %630
  %634 = select i1 %633, i64 %625, i64 %627
  %635 = select i1 %633, i64 %626, i64 %629
  br i1 %633, label %636, label %637

636:                                              ; preds = %623
  br label %740

637:                                              ; preds = %623
  br label %638

638:                                              ; preds = %637
  %639 = add i64 %625, %37
  %640 = getelementptr inbounds float, ptr %611, i64 %639
  %641 = ptrtoint ptr %640 to i64
  %642 = insertelement <4 x i64> undef, i64 %641, i32 0
  %643 = shufflevector <4 x i64> %642, <4 x i64> undef, <4 x i32> zeroinitializer
  %644 = add <4 x i64> %643, %31
  %645 = extractelement <4 x i64> %644, i64 1
  %646 = extractelement <4 x i64> %644, i64 3
  %647 = extractelement <4 x i64> %644, i64 2
  %648 = extractelement <4 x i64> %644, i64 0
  %649 = getelementptr inbounds float, ptr %610, i64 %639
  %650 = ptrtoint ptr %649 to i64
  %651 = insertelement <4 x i64> undef, i64 %650, i32 0
  %652 = shufflevector <4 x i64> %651, <4 x i64> undef, <4 x i32> zeroinitializer
  %653 = add <4 x i64> %652, %31
  %654 = extractelement <4 x i64> %653, i64 1
  %655 = extractelement <4 x i64> %653, i64 3
  %656 = extractelement <4 x i64> %653, i64 2
  %657 = extractelement <4 x i64> %653, i64 0
  %658 = add i64 %622, %639
  %659 = getelementptr inbounds float, ptr %605, i64 %658
  %660 = add i64 %176, %639
  %661 = getelementptr inbounds float, ptr %165, i64 %660
  %662 = sub i64 %160, %639
  %663 = call i64 @llvm.smin.i64(i64 %662, i64 4)
  %664 = call i64 @llvm.smax.i64(i64 %663, i64 0)
  %665 = icmp eq i64 %663, 4
  %666 = icmp slt i64 %639, %160
  br i1 %666, label %667, label %737

667:                                              ; preds = %638
  br i1 %665, label %668, label %708

668:                                              ; preds = %667
  %669 = load <4 x float>, ptr %661, align 16
  br i1 %29, label %670, label %672

670:                                              ; preds = %668
  %671 = load <4 x float>, ptr %649, align 4, !invariant.load !1
  br label %685

672:                                              ; preds = %668
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %657, ptr %9, align 8
  %673 = load ptr, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %674 = load float, ptr %673, align 4, !invariant.load !1
  %675 = insertelement <4 x float> zeroinitializer, float %674, i64 0
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %654, ptr %8, align 8
  %676 = load ptr, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %677 = load float, ptr %676, align 4, !invariant.load !1
  %678 = insertelement <4 x float> %675, float %677, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %656, ptr %7, align 8
  %679 = load ptr, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %680 = load float, ptr %679, align 4, !invariant.load !1
  %681 = insertelement <4 x float> %678, float %680, i64 2
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store i64 %655, ptr %6, align 8
  %682 = load ptr, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %683 = load float, ptr %682, align 4, !invariant.load !1
  %684 = insertelement <4 x float> %681, float %683, i64 3
  br label %685

685:                                              ; preds = %672, %670
  %686 = phi <4 x float> [ %684, %672 ], [ %671, %670 ]
  br i1 %29, label %687, label %689

687:                                              ; preds = %685
  %688 = load <4 x float>, ptr %640, align 4, !invariant.load !1
  br label %702

689:                                              ; preds = %685
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %648, ptr %5, align 8
  %690 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %691 = load float, ptr %690, align 4, !invariant.load !1
  %692 = insertelement <4 x float> zeroinitializer, float %691, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %645, ptr %4, align 8
  %693 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %694 = load float, ptr %693, align 4, !invariant.load !1
  %695 = insertelement <4 x float> %692, float %694, i64 1
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %647, ptr %3, align 8
  %696 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %697 = load float, ptr %696, align 4, !invariant.load !1
  %698 = insertelement <4 x float> %695, float %697, i64 2
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %646, ptr %2, align 8
  %699 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %700 = load float, ptr %699, align 4, !invariant.load !1
  %701 = insertelement <4 x float> %698, float %700, i64 3
  br label %702

702:                                              ; preds = %689, %687
  %703 = phi <4 x float> [ %701, %689 ], [ %688, %687 ]
  %704 = fsub contract <4 x float> %669, %613
  %705 = fmul contract <4 x float> %704, %615
  %706 = fmul contract <4 x float> %705, %686
  %707 = fadd contract <4 x float> %706, %703
  store <4 x float> %707, ptr %659, align 16
  br label %735

708:                                              ; preds = %667
  br label %709

709:                                              ; preds = %715, %708
  %710 = phi i64 [ 0, %708 ], [ %718, %715 ]
  %711 = phi i64 [ %624, %708 ], [ %719, %715 ]
  %712 = icmp slt i64 %710, %664
  br i1 %712, label %713, label %714

713:                                              ; preds = %709
  br label %715

714:                                              ; preds = %709
  br label %733

715:                                              ; preds = %713
  %716 = icmp eq i64 %710, %664
  %717 = add i64 %710, 1
  %718 = select i1 %716, i64 %710, i64 %717
  %719 = add i64 %639, %710
  %720 = add i64 %176, %719
  %721 = getelementptr inbounds float, ptr %165, i64 %720
  %722 = load float, ptr %721, align 4
  %723 = getelementptr inbounds float, ptr %610, i64 %719
  %724 = load float, ptr %723, align 4, !invariant.load !1
  %725 = getelementptr inbounds float, ptr %611, i64 %719
  %726 = load float, ptr %725, align 4, !invariant.load !1
  %727 = fsub contract float %722, %612
  %728 = fmul contract float %727, %614
  %729 = fmul contract float %728, %724
  %730 = fadd contract float %729, %726
  %731 = add i64 %622, %719
  %732 = getelementptr inbounds float, ptr %605, i64 %731
  store float %730, ptr %732, align 4
  br label %709

733:                                              ; preds = %714
  %734 = phi i64 [ %711, %714 ]
  br label %735

735:                                              ; preds = %733, %702
  %736 = phi i64 [ %734, %733 ], [ %639, %702 ]
  br label %738

737:                                              ; preds = %638
  br label %738

738:                                              ; preds = %737, %735
  %739 = phi i64 [ %624, %737 ], [ %736, %735 ]
  br label %623

740:                                              ; preds = %636
  br label %58

741:                                              ; preds = %85
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

attributes #0 = { convergent norecurse "nvvm.maxntid"="1024" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
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
