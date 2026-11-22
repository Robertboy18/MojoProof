; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

define internal { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } noundef %0) #0 {
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

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r5_ax4_w4_bs128_2a51f5f4(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }) %0) #1 {
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
  %16 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %16, i32 0, i32 5
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %16, i32 0, i32 4
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %16, i32 0, i32 3
  %20 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %16, i32 0, i32 2
  %21 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %16, i32 0, i32 1
  %22 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %16, i32 0, i32 0
  %23 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 2
  %24 = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> splat (i1 true))
  %25 = call <4 x i64> @llvm.stepvector.v4i64()
  %26 = mul <4 x i64> %25, splat (i64 4)
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %28 = sext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %30 = zext i32 %29 to i64
  %31 = mul i64 %28, 4
  %32 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %33 = load { i64, i64, i64, i64, i64 }, ptr %32, align 8
  %34 = extractvalue { i64, i64, i64, i64, i64 } %33, 0
  %35 = extractvalue { i64, i64, i64, i64, i64 } %33, 1
  %36 = mul i64 %34, %35
  %37 = extractvalue { i64, i64, i64, i64, i64 } %33, 2
  %38 = mul i64 %36, %37
  %39 = extractvalue { i64, i64, i64, i64, i64 } %33, 3
  %40 = mul i64 %38, %39
  %41 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %42 = zext i32 %41 to i64
  %43 = mul i64 %42, 4
  %44 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %45 = sext i32 %44 to i64
  %46 = mul i64 %45, 4
  %47 = icmp eq i64 %46, 0
  %48 = select i1 %47, i64 0, i64 %43
  %49 = select i1 %47, i64 0, i64 %40
  %50 = select i1 %47, i64 1, i64 %46
  %51 = icmp slt i64 %50, 0
  %52 = icmp sgt i64 %50, 0
  br label %53

53:                                               ; preds = %584, %1
  %54 = phi i64 [ %48, %1 ], [ %78, %584 ]
  %55 = phi i64 [ 0, %1 ], [ %79, %584 ]
  %56 = icmp sge i64 %49, %54
  %57 = icmp sge i64 %54, %49
  %58 = add i64 %54, %50
  %59 = icmp slt i64 %58, %54
  %60 = xor i1 %59, %51
  %61 = select i1 %60, i64 1, i64 0
  %62 = icmp eq i64 %55, 0
  %63 = xor i1 %62, true
  %64 = or i1 %63, %56
  %65 = or i1 %63, %57
  br label %66

66:                                               ; preds = %53
  br i1 %52, label %67, label %72

67:                                               ; preds = %66
  br i1 %65, label %68, label %69

68:                                               ; preds = %67
  br label %75

69:                                               ; preds = %67
  br label %70

70:                                               ; preds = %69
  br label %74

71:                                               ; preds = %72
  br label %74

72:                                               ; preds = %66
  br i1 %64, label %73, label %71

73:                                               ; preds = %72
  br label %75

74:                                               ; preds = %71, %70
  br label %75

75:                                               ; preds = %74, %73, %68
  %76 = phi i1 [ true, %68 ], [ true, %73 ], [ false, %74 ]
  %77 = phi i64 [ undef, %68 ], [ undef, %73 ], [ %54, %74 ]
  %78 = phi i64 [ %54, %68 ], [ %54, %73 ], [ %58, %74 ]
  %79 = phi i64 [ %55, %68 ], [ %55, %73 ], [ %61, %74 ]
  br i1 %76, label %80, label %81

80:                                               ; preds = %75
  br label %585

81:                                               ; preds = %75
  br label %82

82:                                               ; preds = %81
  %83 = udiv i64 %30, 32
  %84 = add i64 %77, %83
  %85 = trunc i64 %84 to i32
  %86 = zext i32 %85 to i64
  %87 = icmp slt i64 %84, %40
  br i1 %87, label %88, label %583

88:                                               ; preds = %82
  %89 = load [3 x { i32, i32, i8, i8, i1, i8 }], ptr %23, align 4
  %90 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 2, 0
  %91 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 2, 1
  %92 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 2, 2
  %93 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 2, 3
  %94 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 2, 4
  %95 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 2, 5
  %96 = zext i8 %93 to i32
  %97 = zext i8 %92 to i32
  %98 = zext i32 %91 to i64
  %99 = mul i64 %98, %86
  %100 = zext i8 %95 to i32
  %101 = lshr i32 %85, %100
  %102 = lshr i64 %99, 32
  %103 = trunc i64 %102 to i32
  %104 = sub i32 %85, %103
  %105 = lshr i32 %104, %97
  %106 = add i32 %103, %105
  %107 = lshr i32 %106, %96
  %108 = select i1 %94, i32 %101, i32 %107
  %109 = mul i32 %108, %90
  %110 = sub i32 %85, %109
  %111 = zext i32 %110 to i64
  %112 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 1, 0
  %113 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 1, 1
  %114 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 1, 2
  %115 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 1, 3
  %116 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 1, 4
  %117 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 1, 5
  %118 = zext i8 %115 to i32
  %119 = zext i8 %114 to i32
  %120 = zext i32 %108 to i64
  %121 = zext i32 %113 to i64
  %122 = mul i64 %121, %120
  %123 = zext i8 %117 to i32
  %124 = lshr i32 %108, %123
  %125 = lshr i64 %122, 32
  %126 = trunc i64 %125 to i32
  %127 = sub i32 %108, %126
  %128 = lshr i32 %127, %119
  %129 = add i32 %126, %128
  %130 = lshr i32 %129, %118
  %131 = select i1 %116, i32 %124, i32 %130
  %132 = mul i32 %131, %112
  %133 = sub i32 %108, %132
  %134 = zext i32 %133 to i64
  %135 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 0, 0
  %136 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 0, 1
  %137 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 0, 2
  %138 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 0, 3
  %139 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 0, 4
  %140 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %89, 0, 5
  %141 = zext i8 %138 to i32
  %142 = zext i8 %137 to i32
  %143 = zext i32 %131 to i64
  %144 = zext i32 %136 to i64
  %145 = mul i64 %144, %143
  %146 = zext i8 %140 to i32
  %147 = lshr i32 %131, %146
  %148 = lshr i64 %145, 32
  %149 = trunc i64 %148 to i32
  %150 = sub i32 %131, %149
  %151 = lshr i32 %150, %142
  %152 = add i32 %149, %151
  %153 = lshr i32 %152, %141
  %154 = select i1 %139, i32 %147, i32 %153
  %155 = mul i32 %154, %135
  %156 = sub i32 %131, %155
  %157 = zext i32 %156 to i64
  %158 = zext i32 %154 to i64
  %159 = load i64, ptr %22, align 8
  %160 = load { ptr, { { i64 }, { {} } } }, ptr %21, align 8
  %161 = load { ptr, { { i64 }, { {} } } }, ptr %20, align 8
  %162 = load float, ptr %19, align 4
  %163 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %18, align 8
  %164 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %163, 0
  %165 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %163, 1, 1, 0
  %166 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %163, 1, 1, 1
  %167 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %163, 1, 1, 2
  %168 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %163, 1, 1, 3
  %169 = mul i64 %158, %165
  %170 = mul i64 %157, %166
  %171 = add i64 %169, %170
  %172 = mul i64 %134, %167
  %173 = add i64 %171, %172
  %174 = mul i64 %111, %168
  %175 = add i64 %173, %174
  br label %176

176:                                              ; preds = %258, %88
  %177 = phi i64 [ 0, %88 ], [ %259, %258 ]
  %178 = phi i64 [ 0, %88 ], [ %192, %258 ]
  %179 = phi i64 [ 0, %88 ], [ %193, %258 ]
  %180 = phi <4 x float> [ zeroinitializer, %88 ], [ %260, %258 ]
  %181 = phi <4 x float> [ zeroinitializer, %88 ], [ %261, %258 ]
  %182 = phi <4 x float> [ zeroinitializer, %88 ], [ %262, %258 ]
  %183 = fadd contract <4 x float> %180, splat (float 1.000000e+00)
  %184 = extractelement <4 x float> %183, i64 0
  %185 = add i64 %178, 128
  %186 = icmp slt i64 %185, %178
  %187 = select i1 %186, i64 1, i64 0
  %188 = icmp sge i64 %178, %159
  %189 = icmp eq i64 %179, 0
  %190 = xor i1 %189, true
  %191 = or i1 %190, %188
  %192 = select i1 %191, i64 %178, i64 %185
  %193 = select i1 %191, i64 %179, i64 %187
  br i1 %191, label %194, label %195

194:                                              ; preds = %176
  br label %263

195:                                              ; preds = %176
  br label %196

196:                                              ; preds = %195
  %197 = add i64 %178, %31
  %198 = add i64 %175, %197
  %199 = getelementptr inbounds float, ptr %164, i64 %198
  %200 = sub i64 %159, %197
  %201 = call i64 @llvm.smin.i64(i64 %200, i64 4)
  %202 = call i64 @llvm.smax.i64(i64 %201, i64 0)
  %203 = icmp eq i64 %201, 4
  %204 = icmp slt i64 %197, %159
  br i1 %204, label %205, label %257

205:                                              ; preds = %196
  br i1 %203, label %206, label %218

206:                                              ; preds = %205
  %207 = load <4 x float>, ptr %199, align 16
  %208 = fsub contract <4 x float> %207, %181
  %209 = fdiv float 1.000000e+00, %184
  %210 = insertelement <4 x float> undef, float %209, i32 0
  %211 = shufflevector <4 x float> %210, <4 x float> undef, <4 x i32> zeroinitializer
  %212 = fmul contract <4 x float> %208, %211
  %213 = fadd contract <4 x float> %181, %212
  %214 = fmul contract <4 x float> %208, %208
  %215 = fmul contract <4 x float> %214, %180
  %216 = fmul contract <4 x float> %215, %211
  %217 = fadd contract <4 x float> %182, %216
  br label %252

218:                                              ; preds = %205
  br label %219

219:                                              ; preds = %228, %218
  %220 = phi i64 [ 0, %218 ], [ %231, %228 ]
  %221 = phi i64 [ %177, %218 ], [ %232, %228 ]
  %222 = phi <4 x float> [ %180, %218 ], [ %237, %228 ]
  %223 = phi <4 x float> [ %181, %218 ], [ %242, %228 ]
  %224 = phi <4 x float> [ %182, %218 ], [ %246, %228 ]
  %225 = icmp slt i64 %220, %202
  br i1 %225, label %226, label %227

226:                                              ; preds = %219
  br label %228

227:                                              ; preds = %219
  br label %247

228:                                              ; preds = %226
  %229 = icmp eq i64 %220, %202
  %230 = add i64 %220, 1
  %231 = select i1 %229, i64 %220, i64 %230
  %232 = add i64 %197, %220
  %233 = add i64 %175, %232
  %234 = getelementptr inbounds float, ptr %164, i64 %233
  %235 = load float, ptr %234, align 4
  %236 = insertelement <4 x float> zeroinitializer, float %235, i64 0
  %237 = fadd contract <4 x float> %222, <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>
  %238 = fsub contract <4 x float> %236, %223
  %239 = call <4 x float> @llvm.maxnum.v4f32(<4 x float> %237, <4 x float> splat (float 1.000000e+00))
  %240 = fdiv <4 x float> <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, %239
  %241 = fmul contract <4 x float> %238, %240
  %242 = fadd contract <4 x float> %223, %241
  %243 = fmul contract <4 x float> %238, %238
  %244 = fmul contract <4 x float> %243, %222
  %245 = fmul contract <4 x float> %244, %240
  %246 = fadd contract <4 x float> %224, %245
  br label %219

247:                                              ; preds = %227
  %248 = phi i64 [ %221, %227 ]
  %249 = phi <4 x float> [ %222, %227 ]
  %250 = phi <4 x float> [ %223, %227 ]
  %251 = phi <4 x float> [ %224, %227 ]
  br label %252

252:                                              ; preds = %247, %206
  %253 = phi i64 [ %248, %247 ], [ %197, %206 ]
  %254 = phi <4 x float> [ %249, %247 ], [ %183, %206 ]
  %255 = phi <4 x float> [ %250, %247 ], [ %213, %206 ]
  %256 = phi <4 x float> [ %251, %247 ], [ %217, %206 ]
  br label %258

257:                                              ; preds = %196
  br label %258

258:                                              ; preds = %257, %252
  %259 = phi i64 [ %177, %257 ], [ %253, %252 ]
  %260 = phi <4 x float> [ %180, %257 ], [ %254, %252 ]
  %261 = phi <4 x float> [ %181, %257 ], [ %255, %252 ]
  %262 = phi <4 x float> [ %182, %257 ], [ %256, %252 ]
  br label %176

263:                                              ; preds = %194
  %264 = phi <4 x float> [ %180, %194 ]
  %265 = phi <4 x float> [ %181, %194 ]
  %266 = phi <4 x float> [ %182, %194 ]
  %267 = insertvalue { <4 x float>, <4 x float>, <4 x float> } undef, <4 x float> %264, 0
  %268 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %267, <4 x float> %265, 1
  %269 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %268, <4 x float> %266, 2
  %270 = call { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } %269)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store { float, float, float } %270, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store { float, float, float } zeroinitializer, ptr %14, align 4
  %271 = load i32, ptr %15, align 4
  %272 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %271, i32 16, i32 31)
  store i32 %272, ptr %14, align 4
  %273 = getelementptr inbounds i32, ptr %14, i32 1
  %274 = getelementptr inbounds i32, ptr %15, i32 1
  %275 = load i32, ptr %274, align 4
  %276 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %275, i32 16, i32 31)
  store i32 %276, ptr %273, align 4
  %277 = getelementptr inbounds i32, ptr %14, i32 2
  %278 = getelementptr inbounds i32, ptr %15, i32 2
  %279 = load i32, ptr %278, align 4
  %280 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %279, i32 16, i32 31)
  store i32 %280, ptr %277, align 4
  %281 = load { float, float, float }, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  %282 = getelementptr { float, float, float }, ptr %15, i32 0, i32 0
  %283 = load float, ptr %282, align 4
  %284 = extractvalue { float, float, float } %281, 0
  %285 = fadd contract float %283, %284
  %286 = call float @llvm.maxnum.f32(float %285, float 1.000000e+00)
  %287 = extractvalue { float, float, float } %281, 1
  %288 = getelementptr { float, float, float }, ptr %15, i32 0, i32 1
  %289 = load float, ptr %288, align 4
  %290 = fsub contract float %287, %289
  %291 = fdiv float %284, %286
  %292 = getelementptr { float, float, float }, ptr %15, i32 0, i32 2
  %293 = extractvalue { float, float, float } %281, 2
  %294 = load float, ptr %292, align 4
  %295 = fadd contract float %294, %293
  %296 = fmul contract float %290, %290
  %297 = fmul contract float %296, %283
  %298 = fmul contract float %297, %291
  %299 = fadd contract float %295, %298
  store float %299, ptr %292, align 4
  %300 = fmul contract float %290, %291
  %301 = load float, ptr %288, align 4
  %302 = fadd contract float %301, %300
  store float %302, ptr %288, align 4
  store float %285, ptr %282, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store { float, float, float } zeroinitializer, ptr %13, align 4
  %303 = load i32, ptr %15, align 4
  %304 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %303, i32 8, i32 31)
  store i32 %304, ptr %13, align 4
  %305 = getelementptr inbounds i32, ptr %13, i32 1
  %306 = load i32, ptr %274, align 4
  %307 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %306, i32 8, i32 31)
  store i32 %307, ptr %305, align 4
  %308 = getelementptr inbounds i32, ptr %13, i32 2
  %309 = load i32, ptr %278, align 4
  %310 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %309, i32 8, i32 31)
  store i32 %310, ptr %308, align 4
  %311 = load { float, float, float }, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %312 = load float, ptr %282, align 4
  %313 = extractvalue { float, float, float } %311, 0
  %314 = fadd contract float %312, %313
  %315 = call float @llvm.maxnum.f32(float %314, float 1.000000e+00)
  %316 = extractvalue { float, float, float } %311, 1
  %317 = load float, ptr %288, align 4
  %318 = fsub contract float %316, %317
  %319 = fdiv float %313, %315
  %320 = extractvalue { float, float, float } %311, 2
  %321 = load float, ptr %292, align 4
  %322 = fadd contract float %321, %320
  %323 = fmul contract float %318, %318
  %324 = fmul contract float %323, %312
  %325 = fmul contract float %324, %319
  %326 = fadd contract float %322, %325
  store float %326, ptr %292, align 4
  %327 = fmul contract float %318, %319
  %328 = load float, ptr %288, align 4
  %329 = fadd contract float %328, %327
  store float %329, ptr %288, align 4
  store float %314, ptr %282, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } zeroinitializer, ptr %12, align 4
  %330 = load i32, ptr %15, align 4
  %331 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %330, i32 4, i32 31)
  store i32 %331, ptr %12, align 4
  %332 = getelementptr inbounds i32, ptr %12, i32 1
  %333 = load i32, ptr %274, align 4
  %334 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %333, i32 4, i32 31)
  store i32 %334, ptr %332, align 4
  %335 = getelementptr inbounds i32, ptr %12, i32 2
  %336 = load i32, ptr %278, align 4
  %337 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %336, i32 4, i32 31)
  store i32 %337, ptr %335, align 4
  %338 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %339 = load float, ptr %282, align 4
  %340 = extractvalue { float, float, float } %338, 0
  %341 = fadd contract float %339, %340
  %342 = call float @llvm.maxnum.f32(float %341, float 1.000000e+00)
  %343 = extractvalue { float, float, float } %338, 1
  %344 = load float, ptr %288, align 4
  %345 = fsub contract float %343, %344
  %346 = fdiv float %340, %342
  %347 = extractvalue { float, float, float } %338, 2
  %348 = load float, ptr %292, align 4
  %349 = fadd contract float %348, %347
  %350 = fmul contract float %345, %345
  %351 = fmul contract float %350, %339
  %352 = fmul contract float %351, %346
  %353 = fadd contract float %349, %352
  store float %353, ptr %292, align 4
  %354 = fmul contract float %345, %346
  %355 = load float, ptr %288, align 4
  %356 = fadd contract float %355, %354
  store float %356, ptr %288, align 4
  store float %341, ptr %282, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %357 = load i32, ptr %15, align 4
  %358 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %357, i32 2, i32 31)
  store i32 %358, ptr %11, align 4
  %359 = getelementptr inbounds i32, ptr %11, i32 1
  %360 = load i32, ptr %274, align 4
  %361 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %360, i32 2, i32 31)
  store i32 %361, ptr %359, align 4
  %362 = getelementptr inbounds i32, ptr %11, i32 2
  %363 = load i32, ptr %278, align 4
  %364 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %363, i32 2, i32 31)
  store i32 %364, ptr %362, align 4
  %365 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %366 = load float, ptr %282, align 4
  %367 = extractvalue { float, float, float } %365, 0
  %368 = fadd contract float %366, %367
  %369 = call float @llvm.maxnum.f32(float %368, float 1.000000e+00)
  %370 = extractvalue { float, float, float } %365, 1
  %371 = load float, ptr %288, align 4
  %372 = fsub contract float %370, %371
  %373 = fdiv float %367, %369
  %374 = extractvalue { float, float, float } %365, 2
  %375 = load float, ptr %292, align 4
  %376 = fadd contract float %375, %374
  %377 = fmul contract float %372, %372
  %378 = fmul contract float %377, %366
  %379 = fmul contract float %378, %373
  %380 = fadd contract float %376, %379
  store float %380, ptr %292, align 4
  %381 = fmul contract float %372, %373
  %382 = load float, ptr %288, align 4
  %383 = fadd contract float %382, %381
  store float %383, ptr %288, align 4
  store float %368, ptr %282, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %384 = load i32, ptr %15, align 4
  %385 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %384, i32 1, i32 31)
  store i32 %385, ptr %10, align 4
  %386 = getelementptr inbounds i32, ptr %10, i32 1
  %387 = load i32, ptr %274, align 4
  %388 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %387, i32 1, i32 31)
  store i32 %388, ptr %386, align 4
  %389 = getelementptr inbounds i32, ptr %10, i32 2
  %390 = load i32, ptr %278, align 4
  %391 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %390, i32 1, i32 31)
  store i32 %391, ptr %389, align 4
  %392 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %393 = load float, ptr %282, align 4
  %394 = extractvalue { float, float, float } %392, 0
  %395 = fadd contract float %393, %394
  %396 = call float @llvm.maxnum.f32(float %395, float 1.000000e+00)
  %397 = extractvalue { float, float, float } %392, 1
  %398 = load float, ptr %288, align 4
  %399 = fsub contract float %397, %398
  %400 = fdiv float %394, %396
  %401 = extractvalue { float, float, float } %392, 2
  %402 = load float, ptr %292, align 4
  %403 = fadd contract float %402, %401
  %404 = fmul contract float %399, %399
  %405 = fmul contract float %404, %393
  %406 = fmul contract float %405, %400
  %407 = fadd contract float %403, %406
  store float %407, ptr %292, align 4
  %408 = fmul contract float %399, %400
  %409 = load float, ptr %288, align 4
  %410 = fadd contract float %409, %408
  store float %410, ptr %288, align 4
  store float %395, ptr %282, align 4
  %411 = load float, ptr %288, align 4
  store float %411, ptr %288, align 4
  %412 = load float, ptr %292, align 4
  store float %412, ptr %292, align 4
  %413 = load float, ptr %282, align 4
  store float %413, ptr %282, align 4
  %414 = load { float, float, float }, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  %415 = extractvalue { float, float, float } %414, 0
  %416 = insertelement <4 x float> zeroinitializer, float %415, i64 0
  %417 = extractvalue { float, float, float } %414, 1
  %418 = insertelement <4 x float> zeroinitializer, float %417, i64 0
  %419 = extractvalue { float, float, float } %414, 2
  %420 = insertelement <4 x float> zeroinitializer, float %419, i64 0
  %421 = insertelement <4 x float> %416, float %415, i64 1
  %422 = insertelement <4 x float> %418, float %417, i64 1
  %423 = insertelement <4 x float> %420, float %419, i64 1
  %424 = insertelement <4 x float> %421, float %415, i64 2
  %425 = insertelement <4 x float> %422, float %417, i64 2
  %426 = insertelement <4 x float> %423, float %419, i64 2
  %427 = insertelement <4 x float> %424, float %415, i64 3
  %428 = insertelement <4 x float> %425, float %417, i64 3
  %429 = insertelement <4 x float> %426, float %419, i64 3
  %430 = fdiv <4 x float> %429, %427
  %431 = insertelement <4 x float> undef, float %162, i32 0
  %432 = shufflevector <4 x float> %431, <4 x float> undef, <4 x i32> zeroinitializer
  %433 = fadd contract <4 x float> %430, %432
  %434 = extractelement <4 x float> %433, i64 3
  %435 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %434)
  %436 = extractelement <4 x float> %433, i64 2
  %437 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %436)
  %438 = extractelement <4 x float> %433, i64 1
  %439 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %438)
  %440 = extractelement <4 x float> %433, i64 0
  %441 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %440)
  %442 = insertelement <4 x float> zeroinitializer, float %441, i64 0
  %443 = insertelement <4 x float> %442, float %439, i64 1
  %444 = insertelement <4 x float> %443, float %437, i64 2
  %445 = insertelement <4 x float> %444, float %435, i64 3
  %446 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %17, align 8
  %447 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 0
  %448 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 0
  %449 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 1
  %450 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 2
  %451 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %446, 1, 1, 3
  %452 = extractvalue { ptr, { { i64 }, { {} } } } %160, 0
  %453 = extractvalue { ptr, { { i64 }, { {} } } } %161, 0
  %454 = extractelement <4 x float> %428, i64 0
  %455 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %428, i64 0)
  %456 = extractelement <4 x float> %445, i64 0
  %457 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %445, i64 0)
  %458 = mul i64 %158, %448
  %459 = mul i64 %157, %449
  %460 = add i64 %458, %459
  %461 = mul i64 %134, %450
  %462 = add i64 %460, %461
  %463 = mul i64 %111, %451
  %464 = add i64 %462, %463
  br label %465

465:                                              ; preds = %580, %263
  %466 = phi i64 [ 0, %263 ], [ %581, %580 ]
  %467 = phi i64 [ 0, %263 ], [ %476, %580 ]
  %468 = phi i64 [ 0, %263 ], [ %477, %580 ]
  %469 = add i64 %467, 128
  %470 = icmp slt i64 %469, %467
  %471 = select i1 %470, i64 1, i64 0
  %472 = icmp sge i64 %467, %159
  %473 = icmp eq i64 %468, 0
  %474 = xor i1 %473, true
  %475 = or i1 %474, %472
  %476 = select i1 %475, i64 %467, i64 %469
  %477 = select i1 %475, i64 %468, i64 %471
  br i1 %475, label %478, label %479

478:                                              ; preds = %465
  br label %582

479:                                              ; preds = %465
  br label %480

480:                                              ; preds = %479
  %481 = add i64 %467, %31
  %482 = getelementptr inbounds float, ptr %453, i64 %481
  %483 = ptrtoint ptr %482 to i64
  %484 = insertelement <4 x i64> undef, i64 %483, i32 0
  %485 = shufflevector <4 x i64> %484, <4 x i64> undef, <4 x i32> zeroinitializer
  %486 = add <4 x i64> %485, %26
  %487 = extractelement <4 x i64> %486, i64 1
  %488 = extractelement <4 x i64> %486, i64 3
  %489 = extractelement <4 x i64> %486, i64 2
  %490 = extractelement <4 x i64> %486, i64 0
  %491 = getelementptr inbounds float, ptr %452, i64 %481
  %492 = ptrtoint ptr %491 to i64
  %493 = insertelement <4 x i64> undef, i64 %492, i32 0
  %494 = shufflevector <4 x i64> %493, <4 x i64> undef, <4 x i32> zeroinitializer
  %495 = add <4 x i64> %494, %26
  %496 = extractelement <4 x i64> %495, i64 1
  %497 = extractelement <4 x i64> %495, i64 3
  %498 = extractelement <4 x i64> %495, i64 2
  %499 = extractelement <4 x i64> %495, i64 0
  %500 = add i64 %464, %481
  %501 = getelementptr inbounds float, ptr %447, i64 %500
  %502 = add i64 %175, %481
  %503 = getelementptr inbounds float, ptr %164, i64 %502
  %504 = sub i64 %159, %481
  %505 = call i64 @llvm.smin.i64(i64 %504, i64 4)
  %506 = call i64 @llvm.smax.i64(i64 %505, i64 0)
  %507 = icmp eq i64 %505, 4
  %508 = icmp slt i64 %481, %159
  br i1 %508, label %509, label %579

509:                                              ; preds = %480
  br i1 %507, label %510, label %550

510:                                              ; preds = %509
  %511 = load <4 x float>, ptr %503, align 16
  br i1 %24, label %512, label %514

512:                                              ; preds = %510
  %513 = load <4 x float>, ptr %491, align 4, !invariant.load !1
  br label %527

514:                                              ; preds = %510
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %499, ptr %9, align 8
  %515 = load ptr, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %516 = load float, ptr %515, align 4, !invariant.load !1
  %517 = insertelement <4 x float> zeroinitializer, float %516, i64 0
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %496, ptr %8, align 8
  %518 = load ptr, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %519 = load float, ptr %518, align 4, !invariant.load !1
  %520 = insertelement <4 x float> %517, float %519, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %498, ptr %7, align 8
  %521 = load ptr, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %522 = load float, ptr %521, align 4, !invariant.load !1
  %523 = insertelement <4 x float> %520, float %522, i64 2
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store i64 %497, ptr %6, align 8
  %524 = load ptr, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %525 = load float, ptr %524, align 4, !invariant.load !1
  %526 = insertelement <4 x float> %523, float %525, i64 3
  br label %527

527:                                              ; preds = %514, %512
  %528 = phi <4 x float> [ %526, %514 ], [ %513, %512 ]
  br i1 %24, label %529, label %531

529:                                              ; preds = %527
  %530 = load <4 x float>, ptr %482, align 4, !invariant.load !1
  br label %544

531:                                              ; preds = %527
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %490, ptr %5, align 8
  %532 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %533 = load float, ptr %532, align 4, !invariant.load !1
  %534 = insertelement <4 x float> zeroinitializer, float %533, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %487, ptr %4, align 8
  %535 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %536 = load float, ptr %535, align 4, !invariant.load !1
  %537 = insertelement <4 x float> %534, float %536, i64 1
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %489, ptr %3, align 8
  %538 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %539 = load float, ptr %538, align 4, !invariant.load !1
  %540 = insertelement <4 x float> %537, float %539, i64 2
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %488, ptr %2, align 8
  %541 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %542 = load float, ptr %541, align 4, !invariant.load !1
  %543 = insertelement <4 x float> %540, float %542, i64 3
  br label %544

544:                                              ; preds = %531, %529
  %545 = phi <4 x float> [ %543, %531 ], [ %530, %529 ]
  %546 = fsub contract <4 x float> %511, %455
  %547 = fmul contract <4 x float> %546, %457
  %548 = fmul contract <4 x float> %547, %528
  %549 = fadd contract <4 x float> %548, %545
  store <4 x float> %549, ptr %501, align 16
  br label %577

550:                                              ; preds = %509
  br label %551

551:                                              ; preds = %557, %550
  %552 = phi i64 [ 0, %550 ], [ %560, %557 ]
  %553 = phi i64 [ %466, %550 ], [ %561, %557 ]
  %554 = icmp slt i64 %552, %506
  br i1 %554, label %555, label %556

555:                                              ; preds = %551
  br label %557

556:                                              ; preds = %551
  br label %575

557:                                              ; preds = %555
  %558 = icmp eq i64 %552, %506
  %559 = add i64 %552, 1
  %560 = select i1 %558, i64 %552, i64 %559
  %561 = add i64 %481, %552
  %562 = add i64 %175, %561
  %563 = getelementptr inbounds float, ptr %164, i64 %562
  %564 = load float, ptr %563, align 4
  %565 = getelementptr inbounds float, ptr %452, i64 %561
  %566 = load float, ptr %565, align 4, !invariant.load !1
  %567 = getelementptr inbounds float, ptr %453, i64 %561
  %568 = load float, ptr %567, align 4, !invariant.load !1
  %569 = fsub contract float %564, %454
  %570 = fmul contract float %569, %456
  %571 = fmul contract float %570, %566
  %572 = fadd contract float %571, %568
  %573 = add i64 %464, %561
  %574 = getelementptr inbounds float, ptr %447, i64 %573
  store float %572, ptr %574, align 4
  br label %551

575:                                              ; preds = %556
  %576 = phi i64 [ %553, %556 ]
  br label %577

577:                                              ; preds = %575, %544
  %578 = phi i64 [ %576, %575 ], [ %481, %544 ]
  br label %580

579:                                              ; preds = %480
  br label %580

580:                                              ; preds = %579, %577
  %581 = phi i64 [ %466, %579 ], [ %578, %577 ]
  br label %465

582:                                              ; preds = %478
  br label %584

583:                                              ; preds = %82
  br label %584

584:                                              ; preds = %583, %582
  br label %53

585:                                              ; preds = %80
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #2

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

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none)
declare float @llvm.nvvm.rsqrt.approx.ftz.f(float) #7

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float>, i64 immarg) #4

attributes #0 = { "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #6 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #7 = { nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
