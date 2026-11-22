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
define dso_local ptx_kernel void @rowwise_warp_t1_r1_ax0_w4_bs128_a3ff2222(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #1 {
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
  %16 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %16, i32 0, i32 5
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %16, i32 0, i32 4
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %16, i32 0, i32 3
  %20 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %16, i32 0, i32 2
  %21 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %16, i32 0, i32 1
  %22 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %16, i32 0, i32 0
  %23 = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> splat (i1 true))
  %24 = call <4 x i64> @llvm.stepvector.v4i64()
  %25 = mul <4 x i64> %24, splat (i64 4)
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %27 = sext i32 %26 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %29 = zext i32 %28 to i64
  %30 = mul i64 %27, 4
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %32 = zext i32 %31 to i64
  %33 = mul i64 %32, 4
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %35 = sext i32 %34 to i64
  %36 = mul i64 %35, 4
  %37 = icmp eq i64 %36, 0
  %38 = select i1 %37, i64 0, i64 %33
  %39 = select i1 %37, i64 0, i64 1
  %40 = select i1 %37, i64 1, i64 %36
  %41 = icmp slt i64 %40, 0
  %42 = icmp sgt i64 %40, 0
  br label %43

43:                                               ; preds = %474, %1
  %44 = phi i64 [ %38, %1 ], [ %68, %474 ]
  %45 = phi i64 [ 0, %1 ], [ %69, %474 ]
  %46 = icmp sge i64 %39, %44
  %47 = icmp sge i64 %44, %39
  %48 = add i64 %44, %40
  %49 = icmp slt i64 %48, %44
  %50 = xor i1 %49, %41
  %51 = select i1 %50, i64 1, i64 0
  %52 = icmp eq i64 %45, 0
  %53 = xor i1 %52, true
  %54 = or i1 %53, %46
  %55 = or i1 %53, %47
  br label %56

56:                                               ; preds = %43
  br i1 %42, label %57, label %62

57:                                               ; preds = %56
  br i1 %55, label %58, label %59

58:                                               ; preds = %57
  br label %65

59:                                               ; preds = %57
  br label %60

60:                                               ; preds = %59
  br label %64

61:                                               ; preds = %62
  br label %64

62:                                               ; preds = %56
  br i1 %54, label %63, label %61

63:                                               ; preds = %62
  br label %65

64:                                               ; preds = %61, %60
  br label %65

65:                                               ; preds = %64, %63, %58
  %66 = phi i1 [ true, %58 ], [ true, %63 ], [ false, %64 ]
  %67 = phi i64 [ undef, %58 ], [ undef, %63 ], [ %44, %64 ]
  %68 = phi i64 [ %44, %58 ], [ %44, %63 ], [ %48, %64 ]
  %69 = phi i64 [ %45, %58 ], [ %45, %63 ], [ %51, %64 ]
  br i1 %66, label %70, label %71

70:                                               ; preds = %65
  br label %475

71:                                               ; preds = %65
  br label %72

72:                                               ; preds = %71
  %73 = udiv i64 %29, 32
  %74 = add i64 %67, %73
  %75 = icmp slt i64 %74, 1
  br i1 %75, label %76, label %473

76:                                               ; preds = %72
  %77 = load i64, ptr %22, align 8
  %78 = load { ptr, { { i64 }, { {} } } }, ptr %21, align 8
  %79 = load { ptr, { { i64 }, { {} } } }, ptr %20, align 8
  %80 = load float, ptr %19, align 4
  %81 = load { ptr, { { i64 }, { {} } } }, ptr %18, align 8
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
  %92 = add i64 %85, 128
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
  %104 = add i64 %85, %30
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
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store { float, float, float } %175, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store { float, float, float } zeroinitializer, ptr %14, align 4
  %176 = load i32, ptr %15, align 4
  %177 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %176, i32 16, i32 31)
  store i32 %177, ptr %14, align 4
  %178 = getelementptr inbounds i32, ptr %14, i32 1
  %179 = getelementptr inbounds i32, ptr %15, i32 1
  %180 = load i32, ptr %179, align 4
  %181 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %180, i32 16, i32 31)
  store i32 %181, ptr %178, align 4
  %182 = getelementptr inbounds i32, ptr %14, i32 2
  %183 = getelementptr inbounds i32, ptr %15, i32 2
  %184 = load i32, ptr %183, align 4
  %185 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %184, i32 16, i32 31)
  store i32 %185, ptr %182, align 4
  %186 = load { float, float, float }, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  %187 = getelementptr { float, float, float }, ptr %15, i32 0, i32 0
  %188 = load float, ptr %187, align 4
  %189 = extractvalue { float, float, float } %186, 0
  %190 = fadd contract float %188, %189
  %191 = call float @llvm.maxnum.f32(float %190, float 1.000000e+00)
  %192 = extractvalue { float, float, float } %186, 1
  %193 = getelementptr { float, float, float }, ptr %15, i32 0, i32 1
  %194 = load float, ptr %193, align 4
  %195 = fsub contract float %192, %194
  %196 = fdiv float %189, %191
  %197 = getelementptr { float, float, float }, ptr %15, i32 0, i32 2
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
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store { float, float, float } zeroinitializer, ptr %13, align 4
  %208 = load i32, ptr %15, align 4
  %209 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %208, i32 8, i32 31)
  store i32 %209, ptr %13, align 4
  %210 = getelementptr inbounds i32, ptr %13, i32 1
  %211 = load i32, ptr %179, align 4
  %212 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %211, i32 8, i32 31)
  store i32 %212, ptr %210, align 4
  %213 = getelementptr inbounds i32, ptr %13, i32 2
  %214 = load i32, ptr %183, align 4
  %215 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %214, i32 8, i32 31)
  store i32 %215, ptr %213, align 4
  %216 = load { float, float, float }, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
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
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } zeroinitializer, ptr %12, align 4
  %235 = load i32, ptr %15, align 4
  %236 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %235, i32 4, i32 31)
  store i32 %236, ptr %12, align 4
  %237 = getelementptr inbounds i32, ptr %12, i32 1
  %238 = load i32, ptr %179, align 4
  %239 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %238, i32 4, i32 31)
  store i32 %239, ptr %237, align 4
  %240 = getelementptr inbounds i32, ptr %12, i32 2
  %241 = load i32, ptr %183, align 4
  %242 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %241, i32 4, i32 31)
  store i32 %242, ptr %240, align 4
  %243 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
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
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %262 = load i32, ptr %15, align 4
  %263 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %262, i32 2, i32 31)
  store i32 %263, ptr %11, align 4
  %264 = getelementptr inbounds i32, ptr %11, i32 1
  %265 = load i32, ptr %179, align 4
  %266 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %265, i32 2, i32 31)
  store i32 %266, ptr %264, align 4
  %267 = getelementptr inbounds i32, ptr %11, i32 2
  %268 = load i32, ptr %183, align 4
  %269 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %268, i32 2, i32 31)
  store i32 %269, ptr %267, align 4
  %270 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
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
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %289 = load i32, ptr %15, align 4
  %290 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %289, i32 1, i32 31)
  store i32 %290, ptr %10, align 4
  %291 = getelementptr inbounds i32, ptr %10, i32 1
  %292 = load i32, ptr %179, align 4
  %293 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %292, i32 1, i32 31)
  store i32 %293, ptr %291, align 4
  %294 = getelementptr inbounds i32, ptr %10, i32 2
  %295 = load i32, ptr %183, align 4
  %296 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %295, i32 1, i32 31)
  store i32 %296, ptr %294, align 4
  %297 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
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
  %316 = load float, ptr %193, align 4
  store float %316, ptr %193, align 4
  %317 = load float, ptr %197, align 4
  store float %317, ptr %197, align 4
  %318 = load float, ptr %187, align 4
  store float %318, ptr %187, align 4
  %319 = load { float, float, float }, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  %320 = extractvalue { float, float, float } %319, 0
  %321 = insertelement <4 x float> zeroinitializer, float %320, i64 0
  %322 = extractvalue { float, float, float } %319, 1
  %323 = insertelement <4 x float> zeroinitializer, float %322, i64 0
  %324 = extractvalue { float, float, float } %319, 2
  %325 = insertelement <4 x float> zeroinitializer, float %324, i64 0
  %326 = insertelement <4 x float> %321, float %320, i64 1
  %327 = insertelement <4 x float> %323, float %322, i64 1
  %328 = insertelement <4 x float> %325, float %324, i64 1
  %329 = insertelement <4 x float> %326, float %320, i64 2
  %330 = insertelement <4 x float> %327, float %322, i64 2
  %331 = insertelement <4 x float> %328, float %324, i64 2
  %332 = insertelement <4 x float> %329, float %320, i64 3
  %333 = insertelement <4 x float> %330, float %322, i64 3
  %334 = insertelement <4 x float> %331, float %324, i64 3
  %335 = fdiv <4 x float> %334, %332
  %336 = insertelement <4 x float> undef, float %80, i32 0
  %337 = shufflevector <4 x float> %336, <4 x float> undef, <4 x i32> zeroinitializer
  %338 = fadd contract <4 x float> %335, %337
  %339 = extractelement <4 x float> %338, i64 3
  %340 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %339)
  %341 = extractelement <4 x float> %338, i64 2
  %342 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %341)
  %343 = extractelement <4 x float> %338, i64 1
  %344 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %343)
  %345 = extractelement <4 x float> %338, i64 0
  %346 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %345)
  %347 = insertelement <4 x float> zeroinitializer, float %346, i64 0
  %348 = insertelement <4 x float> %347, float %344, i64 1
  %349 = insertelement <4 x float> %348, float %342, i64 2
  %350 = insertelement <4 x float> %349, float %340, i64 3
  %351 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %352 = extractvalue { ptr, { { i64 }, { {} } } } %351, 0
  %353 = extractvalue { ptr, { { i64 }, { {} } } } %78, 0
  %354 = extractvalue { ptr, { { i64 }, { {} } } } %79, 0
  %355 = extractelement <4 x float> %333, i64 0
  %356 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %333, i64 0)
  %357 = extractelement <4 x float> %350, i64 0
  %358 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %350, i64 0)
  br label %359

359:                                              ; preds = %470, %168
  %360 = phi i64 [ 0, %168 ], [ %471, %470 ]
  %361 = phi i64 [ 0, %168 ], [ %370, %470 ]
  %362 = phi i64 [ 0, %168 ], [ %371, %470 ]
  %363 = add i64 %361, 128
  %364 = icmp slt i64 %363, %361
  %365 = select i1 %364, i64 1, i64 0
  %366 = icmp sge i64 %361, %77
  %367 = icmp eq i64 %362, 0
  %368 = xor i1 %367, true
  %369 = or i1 %368, %366
  %370 = select i1 %369, i64 %361, i64 %363
  %371 = select i1 %369, i64 %362, i64 %365
  br i1 %369, label %372, label %373

372:                                              ; preds = %359
  br label %472

373:                                              ; preds = %359
  br label %374

374:                                              ; preds = %373
  %375 = add i64 %361, %30
  %376 = getelementptr inbounds float, ptr %352, i64 %375
  %377 = getelementptr inbounds float, ptr %354, i64 %375
  %378 = ptrtoint ptr %377 to i64
  %379 = insertelement <4 x i64> undef, i64 %378, i32 0
  %380 = shufflevector <4 x i64> %379, <4 x i64> undef, <4 x i32> zeroinitializer
  %381 = add <4 x i64> %380, %25
  %382 = extractelement <4 x i64> %381, i64 1
  %383 = extractelement <4 x i64> %381, i64 3
  %384 = extractelement <4 x i64> %381, i64 2
  %385 = extractelement <4 x i64> %381, i64 0
  %386 = getelementptr inbounds float, ptr %353, i64 %375
  %387 = ptrtoint ptr %386 to i64
  %388 = insertelement <4 x i64> undef, i64 %387, i32 0
  %389 = shufflevector <4 x i64> %388, <4 x i64> undef, <4 x i32> zeroinitializer
  %390 = add <4 x i64> %389, %25
  %391 = extractelement <4 x i64> %390, i64 1
  %392 = extractelement <4 x i64> %390, i64 3
  %393 = extractelement <4 x i64> %390, i64 2
  %394 = extractelement <4 x i64> %390, i64 0
  %395 = getelementptr inbounds float, ptr %82, i64 %375
  %396 = sub i64 %77, %375
  %397 = call i64 @llvm.smin.i64(i64 %396, i64 4)
  %398 = call i64 @llvm.smax.i64(i64 %397, i64 0)
  %399 = icmp eq i64 %397, 4
  %400 = icmp slt i64 %375, %77
  br i1 %400, label %401, label %469

401:                                              ; preds = %374
  br i1 %399, label %402, label %442

402:                                              ; preds = %401
  %403 = load <4 x float>, ptr %395, align 16
  br i1 %23, label %404, label %406

404:                                              ; preds = %402
  %405 = load <4 x float>, ptr %386, align 4, !invariant.load !1
  br label %419

406:                                              ; preds = %402
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %394, ptr %9, align 8
  %407 = load ptr, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %408 = load float, ptr %407, align 4, !invariant.load !1
  %409 = insertelement <4 x float> zeroinitializer, float %408, i64 0
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %391, ptr %8, align 8
  %410 = load ptr, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %411 = load float, ptr %410, align 4, !invariant.load !1
  %412 = insertelement <4 x float> %409, float %411, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %393, ptr %7, align 8
  %413 = load ptr, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %414 = load float, ptr %413, align 4, !invariant.load !1
  %415 = insertelement <4 x float> %412, float %414, i64 2
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store i64 %392, ptr %6, align 8
  %416 = load ptr, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %417 = load float, ptr %416, align 4, !invariant.load !1
  %418 = insertelement <4 x float> %415, float %417, i64 3
  br label %419

419:                                              ; preds = %406, %404
  %420 = phi <4 x float> [ %418, %406 ], [ %405, %404 ]
  br i1 %23, label %421, label %423

421:                                              ; preds = %419
  %422 = load <4 x float>, ptr %377, align 4, !invariant.load !1
  br label %436

423:                                              ; preds = %419
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %385, ptr %5, align 8
  %424 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %425 = load float, ptr %424, align 4, !invariant.load !1
  %426 = insertelement <4 x float> zeroinitializer, float %425, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %382, ptr %4, align 8
  %427 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %428 = load float, ptr %427, align 4, !invariant.load !1
  %429 = insertelement <4 x float> %426, float %428, i64 1
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %384, ptr %3, align 8
  %430 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %431 = load float, ptr %430, align 4, !invariant.load !1
  %432 = insertelement <4 x float> %429, float %431, i64 2
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %383, ptr %2, align 8
  %433 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %434 = load float, ptr %433, align 4, !invariant.load !1
  %435 = insertelement <4 x float> %432, float %434, i64 3
  br label %436

436:                                              ; preds = %423, %421
  %437 = phi <4 x float> [ %435, %423 ], [ %422, %421 ]
  %438 = fsub contract <4 x float> %403, %356
  %439 = fmul contract <4 x float> %438, %358
  %440 = fmul contract <4 x float> %439, %420
  %441 = fadd contract <4 x float> %440, %437
  store <4 x float> %441, ptr %376, align 16
  br label %467

442:                                              ; preds = %401
  br label %443

443:                                              ; preds = %449, %442
  %444 = phi i64 [ 0, %442 ], [ %452, %449 ]
  %445 = phi i64 [ %360, %442 ], [ %453, %449 ]
  %446 = icmp slt i64 %444, %398
  br i1 %446, label %447, label %448

447:                                              ; preds = %443
  br label %449

448:                                              ; preds = %443
  br label %465

449:                                              ; preds = %447
  %450 = icmp eq i64 %444, %398
  %451 = add i64 %444, 1
  %452 = select i1 %450, i64 %444, i64 %451
  %453 = add i64 %375, %444
  %454 = getelementptr inbounds float, ptr %82, i64 %453
  %455 = load float, ptr %454, align 4
  %456 = getelementptr inbounds float, ptr %353, i64 %453
  %457 = load float, ptr %456, align 4, !invariant.load !1
  %458 = getelementptr inbounds float, ptr %354, i64 %453
  %459 = load float, ptr %458, align 4, !invariant.load !1
  %460 = fsub contract float %455, %355
  %461 = fmul contract float %460, %357
  %462 = fmul contract float %461, %457
  %463 = fadd contract float %462, %459
  %464 = getelementptr inbounds float, ptr %352, i64 %453
  store float %463, ptr %464, align 4
  br label %443

465:                                              ; preds = %448
  %466 = phi i64 [ %445, %448 ]
  br label %467

467:                                              ; preds = %465, %436
  %468 = phi i64 [ %466, %465 ], [ %375, %436 ]
  br label %470

469:                                              ; preds = %374
  br label %470

470:                                              ; preds = %469, %467
  %471 = phi i64 [ %360, %469 ], [ %468, %467 ]
  br label %359

472:                                              ; preds = %372
  br label %474

473:                                              ; preds = %72
  br label %474

474:                                              ; preds = %473, %472
  br label %43

475:                                              ; preds = %70
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
