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
define dso_local ptx_kernel void @rowwise_warp_t1_r2_ax1_w4_bs128_cf4b658a(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #1 {
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
  %16 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %16, i32 0, i32 5
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %16, i32 0, i32 4
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %16, i32 0, i32 3
  %20 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %16, i32 0, i32 2
  %21 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %16, i32 0, i32 1
  %22 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %16, i32 0, i32 0
  %23 = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> splat (i1 true))
  %24 = call <4 x i64> @llvm.stepvector.v4i64()
  %25 = mul <4 x i64> %24, splat (i64 4)
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %27 = sext i32 %26 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %29 = zext i32 %28 to i64
  %30 = mul i64 %27, 4
  %31 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %32 = load { i64, i64 }, ptr %31, align 8
  %33 = extractvalue { i64, i64 } %32, 0
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %35 = zext i32 %34 to i64
  %36 = mul i64 %35, 4
  %37 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %38 = sext i32 %37 to i64
  %39 = mul i64 %38, 4
  %40 = icmp eq i64 %39, 0
  %41 = select i1 %40, i64 0, i64 %36
  %42 = select i1 %40, i64 0, i64 %33
  %43 = select i1 %40, i64 1, i64 %39
  %44 = icmp slt i64 %43, 0
  %45 = icmp sgt i64 %43, 0
  br label %46

46:                                               ; preds = %487, %1
  %47 = phi i64 [ %41, %1 ], [ %71, %487 ]
  %48 = phi i64 [ 0, %1 ], [ %72, %487 ]
  %49 = icmp sge i64 %42, %47
  %50 = icmp sge i64 %47, %42
  %51 = add i64 %47, %43
  %52 = icmp slt i64 %51, %47
  %53 = xor i1 %52, %44
  %54 = select i1 %53, i64 1, i64 0
  %55 = icmp eq i64 %48, 0
  %56 = xor i1 %55, true
  %57 = or i1 %56, %49
  %58 = or i1 %56, %50
  br label %59

59:                                               ; preds = %46
  br i1 %45, label %60, label %65

60:                                               ; preds = %59
  br i1 %58, label %61, label %62

61:                                               ; preds = %60
  br label %68

62:                                               ; preds = %60
  br label %63

63:                                               ; preds = %62
  br label %67

64:                                               ; preds = %65
  br label %67

65:                                               ; preds = %59
  br i1 %57, label %66, label %64

66:                                               ; preds = %65
  br label %68

67:                                               ; preds = %64, %63
  br label %68

68:                                               ; preds = %67, %66, %61
  %69 = phi i1 [ true, %61 ], [ true, %66 ], [ false, %67 ]
  %70 = phi i64 [ undef, %61 ], [ undef, %66 ], [ %47, %67 ]
  %71 = phi i64 [ %47, %61 ], [ %47, %66 ], [ %51, %67 ]
  %72 = phi i64 [ %48, %61 ], [ %48, %66 ], [ %54, %67 ]
  br i1 %69, label %73, label %74

73:                                               ; preds = %68
  br label %488

74:                                               ; preds = %68
  br label %75

75:                                               ; preds = %74
  %76 = udiv i64 %29, 32
  %77 = add i64 %70, %76
  %78 = icmp slt i64 %77, %33
  br i1 %78, label %79, label %486

79:                                               ; preds = %75
  %80 = load i64, ptr %22, align 8
  %81 = load { ptr, { { i64 }, { {} } } }, ptr %21, align 8
  %82 = load { ptr, { { i64 }, { {} } } }, ptr %20, align 8
  %83 = load float, ptr %19, align 4
  %84 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %18, align 8
  %85 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %84, 0
  %86 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %84, 1, 1, 0
  %87 = mul i64 %77, %86
  br label %88

88:                                               ; preds = %170, %79
  %89 = phi i64 [ 0, %79 ], [ %171, %170 ]
  %90 = phi i64 [ 0, %79 ], [ %104, %170 ]
  %91 = phi i64 [ 0, %79 ], [ %105, %170 ]
  %92 = phi <4 x float> [ zeroinitializer, %79 ], [ %172, %170 ]
  %93 = phi <4 x float> [ zeroinitializer, %79 ], [ %173, %170 ]
  %94 = phi <4 x float> [ zeroinitializer, %79 ], [ %174, %170 ]
  %95 = fadd contract <4 x float> %92, splat (float 1.000000e+00)
  %96 = extractelement <4 x float> %95, i64 0
  %97 = add i64 %90, 128
  %98 = icmp slt i64 %97, %90
  %99 = select i1 %98, i64 1, i64 0
  %100 = icmp sge i64 %90, %80
  %101 = icmp eq i64 %91, 0
  %102 = xor i1 %101, true
  %103 = or i1 %102, %100
  %104 = select i1 %103, i64 %90, i64 %97
  %105 = select i1 %103, i64 %91, i64 %99
  br i1 %103, label %106, label %107

106:                                              ; preds = %88
  br label %175

107:                                              ; preds = %88
  br label %108

108:                                              ; preds = %107
  %109 = add i64 %90, %30
  %110 = add i64 %87, %109
  %111 = getelementptr inbounds float, ptr %85, i64 %110
  %112 = sub i64 %80, %109
  %113 = call i64 @llvm.smin.i64(i64 %112, i64 4)
  %114 = call i64 @llvm.smax.i64(i64 %113, i64 0)
  %115 = icmp eq i64 %113, 4
  %116 = icmp slt i64 %109, %80
  br i1 %116, label %117, label %169

117:                                              ; preds = %108
  br i1 %115, label %118, label %130

118:                                              ; preds = %117
  %119 = load <4 x float>, ptr %111, align 16
  %120 = fsub contract <4 x float> %119, %93
  %121 = fdiv float 1.000000e+00, %96
  %122 = insertelement <4 x float> undef, float %121, i32 0
  %123 = shufflevector <4 x float> %122, <4 x float> undef, <4 x i32> zeroinitializer
  %124 = fmul contract <4 x float> %120, %123
  %125 = fadd contract <4 x float> %93, %124
  %126 = fmul contract <4 x float> %120, %120
  %127 = fmul contract <4 x float> %126, %92
  %128 = fmul contract <4 x float> %127, %123
  %129 = fadd contract <4 x float> %94, %128
  br label %164

130:                                              ; preds = %117
  br label %131

131:                                              ; preds = %140, %130
  %132 = phi i64 [ 0, %130 ], [ %143, %140 ]
  %133 = phi i64 [ %89, %130 ], [ %144, %140 ]
  %134 = phi <4 x float> [ %92, %130 ], [ %149, %140 ]
  %135 = phi <4 x float> [ %93, %130 ], [ %154, %140 ]
  %136 = phi <4 x float> [ %94, %130 ], [ %158, %140 ]
  %137 = icmp slt i64 %132, %114
  br i1 %137, label %138, label %139

138:                                              ; preds = %131
  br label %140

139:                                              ; preds = %131
  br label %159

140:                                              ; preds = %138
  %141 = icmp eq i64 %132, %114
  %142 = add i64 %132, 1
  %143 = select i1 %141, i64 %132, i64 %142
  %144 = add i64 %109, %132
  %145 = add i64 %87, %144
  %146 = getelementptr inbounds float, ptr %85, i64 %145
  %147 = load float, ptr %146, align 4
  %148 = insertelement <4 x float> zeroinitializer, float %147, i64 0
  %149 = fadd contract <4 x float> %134, <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>
  %150 = fsub contract <4 x float> %148, %135
  %151 = call <4 x float> @llvm.maxnum.v4f32(<4 x float> %149, <4 x float> splat (float 1.000000e+00))
  %152 = fdiv <4 x float> <float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, %151
  %153 = fmul contract <4 x float> %150, %152
  %154 = fadd contract <4 x float> %135, %153
  %155 = fmul contract <4 x float> %150, %150
  %156 = fmul contract <4 x float> %155, %134
  %157 = fmul contract <4 x float> %156, %152
  %158 = fadd contract <4 x float> %136, %157
  br label %131

159:                                              ; preds = %139
  %160 = phi i64 [ %133, %139 ]
  %161 = phi <4 x float> [ %134, %139 ]
  %162 = phi <4 x float> [ %135, %139 ]
  %163 = phi <4 x float> [ %136, %139 ]
  br label %164

164:                                              ; preds = %159, %118
  %165 = phi i64 [ %160, %159 ], [ %109, %118 ]
  %166 = phi <4 x float> [ %161, %159 ], [ %95, %118 ]
  %167 = phi <4 x float> [ %162, %159 ], [ %125, %118 ]
  %168 = phi <4 x float> [ %163, %159 ], [ %129, %118 ]
  br label %170

169:                                              ; preds = %108
  br label %170

170:                                              ; preds = %169, %164
  %171 = phi i64 [ %89, %169 ], [ %165, %164 ]
  %172 = phi <4 x float> [ %92, %169 ], [ %166, %164 ]
  %173 = phi <4 x float> [ %93, %169 ], [ %167, %164 ]
  %174 = phi <4 x float> [ %94, %169 ], [ %168, %164 ]
  br label %88

175:                                              ; preds = %106
  %176 = phi <4 x float> [ %92, %106 ]
  %177 = phi <4 x float> [ %93, %106 ]
  %178 = phi <4 x float> [ %94, %106 ]
  %179 = insertvalue { <4 x float>, <4 x float>, <4 x float> } undef, <4 x float> %176, 0
  %180 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %179, <4 x float> %177, 1
  %181 = insertvalue { <4 x float>, <4 x float>, <4 x float> } %180, <4 x float> %178, 2
  %182 = call { float, float, float } @algorithm_reduce_op_ReduceOp6A6A6A6A6A6A_d898dd27f3614903({ <4 x float>, <4 x float>, <4 x float> } %181)
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store { float, float, float } %182, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store { float, float, float } zeroinitializer, ptr %14, align 4
  %183 = load i32, ptr %15, align 4
  %184 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %183, i32 16, i32 31)
  store i32 %184, ptr %14, align 4
  %185 = getelementptr inbounds i32, ptr %14, i32 1
  %186 = getelementptr inbounds i32, ptr %15, i32 1
  %187 = load i32, ptr %186, align 4
  %188 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %187, i32 16, i32 31)
  store i32 %188, ptr %185, align 4
  %189 = getelementptr inbounds i32, ptr %14, i32 2
  %190 = getelementptr inbounds i32, ptr %15, i32 2
  %191 = load i32, ptr %190, align 4
  %192 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %191, i32 16, i32 31)
  store i32 %192, ptr %189, align 4
  %193 = load { float, float, float }, ptr %14, align 4
  call void @llvm.lifetime.end.p0(ptr %14)
  %194 = getelementptr { float, float, float }, ptr %15, i32 0, i32 0
  %195 = load float, ptr %194, align 4
  %196 = extractvalue { float, float, float } %193, 0
  %197 = fadd contract float %195, %196
  %198 = call float @llvm.maxnum.f32(float %197, float 1.000000e+00)
  %199 = extractvalue { float, float, float } %193, 1
  %200 = getelementptr { float, float, float }, ptr %15, i32 0, i32 1
  %201 = load float, ptr %200, align 4
  %202 = fsub contract float %199, %201
  %203 = fdiv float %196, %198
  %204 = getelementptr { float, float, float }, ptr %15, i32 0, i32 2
  %205 = extractvalue { float, float, float } %193, 2
  %206 = load float, ptr %204, align 4
  %207 = fadd contract float %206, %205
  %208 = fmul contract float %202, %202
  %209 = fmul contract float %208, %195
  %210 = fmul contract float %209, %203
  %211 = fadd contract float %207, %210
  store float %211, ptr %204, align 4
  %212 = fmul contract float %202, %203
  %213 = load float, ptr %200, align 4
  %214 = fadd contract float %213, %212
  store float %214, ptr %200, align 4
  store float %197, ptr %194, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store { float, float, float } zeroinitializer, ptr %13, align 4
  %215 = load i32, ptr %15, align 4
  %216 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %215, i32 8, i32 31)
  store i32 %216, ptr %13, align 4
  %217 = getelementptr inbounds i32, ptr %13, i32 1
  %218 = load i32, ptr %186, align 4
  %219 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %218, i32 8, i32 31)
  store i32 %219, ptr %217, align 4
  %220 = getelementptr inbounds i32, ptr %13, i32 2
  %221 = load i32, ptr %190, align 4
  %222 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %221, i32 8, i32 31)
  store i32 %222, ptr %220, align 4
  %223 = load { float, float, float }, ptr %13, align 4
  call void @llvm.lifetime.end.p0(ptr %13)
  %224 = load float, ptr %194, align 4
  %225 = extractvalue { float, float, float } %223, 0
  %226 = fadd contract float %224, %225
  %227 = call float @llvm.maxnum.f32(float %226, float 1.000000e+00)
  %228 = extractvalue { float, float, float } %223, 1
  %229 = load float, ptr %200, align 4
  %230 = fsub contract float %228, %229
  %231 = fdiv float %225, %227
  %232 = extractvalue { float, float, float } %223, 2
  %233 = load float, ptr %204, align 4
  %234 = fadd contract float %233, %232
  %235 = fmul contract float %230, %230
  %236 = fmul contract float %235, %224
  %237 = fmul contract float %236, %231
  %238 = fadd contract float %234, %237
  store float %238, ptr %204, align 4
  %239 = fmul contract float %230, %231
  %240 = load float, ptr %200, align 4
  %241 = fadd contract float %240, %239
  store float %241, ptr %200, align 4
  store float %226, ptr %194, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } zeroinitializer, ptr %12, align 4
  %242 = load i32, ptr %15, align 4
  %243 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %242, i32 4, i32 31)
  store i32 %243, ptr %12, align 4
  %244 = getelementptr inbounds i32, ptr %12, i32 1
  %245 = load i32, ptr %186, align 4
  %246 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %245, i32 4, i32 31)
  store i32 %246, ptr %244, align 4
  %247 = getelementptr inbounds i32, ptr %12, i32 2
  %248 = load i32, ptr %190, align 4
  %249 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %248, i32 4, i32 31)
  store i32 %249, ptr %247, align 4
  %250 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %251 = load float, ptr %194, align 4
  %252 = extractvalue { float, float, float } %250, 0
  %253 = fadd contract float %251, %252
  %254 = call float @llvm.maxnum.f32(float %253, float 1.000000e+00)
  %255 = extractvalue { float, float, float } %250, 1
  %256 = load float, ptr %200, align 4
  %257 = fsub contract float %255, %256
  %258 = fdiv float %252, %254
  %259 = extractvalue { float, float, float } %250, 2
  %260 = load float, ptr %204, align 4
  %261 = fadd contract float %260, %259
  %262 = fmul contract float %257, %257
  %263 = fmul contract float %262, %251
  %264 = fmul contract float %263, %258
  %265 = fadd contract float %261, %264
  store float %265, ptr %204, align 4
  %266 = fmul contract float %257, %258
  %267 = load float, ptr %200, align 4
  %268 = fadd contract float %267, %266
  store float %268, ptr %200, align 4
  store float %253, ptr %194, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %269 = load i32, ptr %15, align 4
  %270 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %269, i32 2, i32 31)
  store i32 %270, ptr %11, align 4
  %271 = getelementptr inbounds i32, ptr %11, i32 1
  %272 = load i32, ptr %186, align 4
  %273 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %272, i32 2, i32 31)
  store i32 %273, ptr %271, align 4
  %274 = getelementptr inbounds i32, ptr %11, i32 2
  %275 = load i32, ptr %190, align 4
  %276 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %275, i32 2, i32 31)
  store i32 %276, ptr %274, align 4
  %277 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %278 = load float, ptr %194, align 4
  %279 = extractvalue { float, float, float } %277, 0
  %280 = fadd contract float %278, %279
  %281 = call float @llvm.maxnum.f32(float %280, float 1.000000e+00)
  %282 = extractvalue { float, float, float } %277, 1
  %283 = load float, ptr %200, align 4
  %284 = fsub contract float %282, %283
  %285 = fdiv float %279, %281
  %286 = extractvalue { float, float, float } %277, 2
  %287 = load float, ptr %204, align 4
  %288 = fadd contract float %287, %286
  %289 = fmul contract float %284, %284
  %290 = fmul contract float %289, %278
  %291 = fmul contract float %290, %285
  %292 = fadd contract float %288, %291
  store float %292, ptr %204, align 4
  %293 = fmul contract float %284, %285
  %294 = load float, ptr %200, align 4
  %295 = fadd contract float %294, %293
  store float %295, ptr %200, align 4
  store float %280, ptr %194, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %296 = load i32, ptr %15, align 4
  %297 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %296, i32 1, i32 31)
  store i32 %297, ptr %10, align 4
  %298 = getelementptr inbounds i32, ptr %10, i32 1
  %299 = load i32, ptr %186, align 4
  %300 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %299, i32 1, i32 31)
  store i32 %300, ptr %298, align 4
  %301 = getelementptr inbounds i32, ptr %10, i32 2
  %302 = load i32, ptr %190, align 4
  %303 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %302, i32 1, i32 31)
  store i32 %303, ptr %301, align 4
  %304 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %305 = load float, ptr %194, align 4
  %306 = extractvalue { float, float, float } %304, 0
  %307 = fadd contract float %305, %306
  %308 = call float @llvm.maxnum.f32(float %307, float 1.000000e+00)
  %309 = extractvalue { float, float, float } %304, 1
  %310 = load float, ptr %200, align 4
  %311 = fsub contract float %309, %310
  %312 = fdiv float %306, %308
  %313 = extractvalue { float, float, float } %304, 2
  %314 = load float, ptr %204, align 4
  %315 = fadd contract float %314, %313
  %316 = fmul contract float %311, %311
  %317 = fmul contract float %316, %305
  %318 = fmul contract float %317, %312
  %319 = fadd contract float %315, %318
  store float %319, ptr %204, align 4
  %320 = fmul contract float %311, %312
  %321 = load float, ptr %200, align 4
  %322 = fadd contract float %321, %320
  store float %322, ptr %200, align 4
  store float %307, ptr %194, align 4
  %323 = load float, ptr %200, align 4
  store float %323, ptr %200, align 4
  %324 = load float, ptr %204, align 4
  store float %324, ptr %204, align 4
  %325 = load float, ptr %194, align 4
  store float %325, ptr %194, align 4
  %326 = load { float, float, float }, ptr %15, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  %327 = extractvalue { float, float, float } %326, 0
  %328 = insertelement <4 x float> zeroinitializer, float %327, i64 0
  %329 = extractvalue { float, float, float } %326, 1
  %330 = insertelement <4 x float> zeroinitializer, float %329, i64 0
  %331 = extractvalue { float, float, float } %326, 2
  %332 = insertelement <4 x float> zeroinitializer, float %331, i64 0
  %333 = insertelement <4 x float> %328, float %327, i64 1
  %334 = insertelement <4 x float> %330, float %329, i64 1
  %335 = insertelement <4 x float> %332, float %331, i64 1
  %336 = insertelement <4 x float> %333, float %327, i64 2
  %337 = insertelement <4 x float> %334, float %329, i64 2
  %338 = insertelement <4 x float> %335, float %331, i64 2
  %339 = insertelement <4 x float> %336, float %327, i64 3
  %340 = insertelement <4 x float> %337, float %329, i64 3
  %341 = insertelement <4 x float> %338, float %331, i64 3
  %342 = fdiv <4 x float> %341, %339
  %343 = insertelement <4 x float> undef, float %83, i32 0
  %344 = shufflevector <4 x float> %343, <4 x float> undef, <4 x i32> zeroinitializer
  %345 = fadd contract <4 x float> %342, %344
  %346 = extractelement <4 x float> %345, i64 3
  %347 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %346)
  %348 = extractelement <4 x float> %345, i64 2
  %349 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %348)
  %350 = extractelement <4 x float> %345, i64 1
  %351 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %350)
  %352 = extractelement <4 x float> %345, i64 0
  %353 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %352)
  %354 = insertelement <4 x float> zeroinitializer, float %353, i64 0
  %355 = insertelement <4 x float> %354, float %351, i64 1
  %356 = insertelement <4 x float> %355, float %349, i64 2
  %357 = insertelement <4 x float> %356, float %347, i64 3
  %358 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %17, align 8
  %359 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %358, 0
  %360 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %358, 1, 1, 0
  %361 = extractvalue { ptr, { { i64 }, { {} } } } %81, 0
  %362 = extractvalue { ptr, { { i64 }, { {} } } } %82, 0
  %363 = extractelement <4 x float> %340, i64 0
  %364 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %340, i64 0)
  %365 = extractelement <4 x float> %357, i64 0
  %366 = call <4 x float> @llvm.vector.extract.v4f32.v4f32(<4 x float> %357, i64 0)
  %367 = mul i64 %77, %360
  br label %368

368:                                              ; preds = %483, %175
  %369 = phi i64 [ 0, %175 ], [ %484, %483 ]
  %370 = phi i64 [ 0, %175 ], [ %379, %483 ]
  %371 = phi i64 [ 0, %175 ], [ %380, %483 ]
  %372 = add i64 %370, 128
  %373 = icmp slt i64 %372, %370
  %374 = select i1 %373, i64 1, i64 0
  %375 = icmp sge i64 %370, %80
  %376 = icmp eq i64 %371, 0
  %377 = xor i1 %376, true
  %378 = or i1 %377, %375
  %379 = select i1 %378, i64 %370, i64 %372
  %380 = select i1 %378, i64 %371, i64 %374
  br i1 %378, label %381, label %382

381:                                              ; preds = %368
  br label %485

382:                                              ; preds = %368
  br label %383

383:                                              ; preds = %382
  %384 = add i64 %370, %30
  %385 = getelementptr inbounds float, ptr %362, i64 %384
  %386 = ptrtoint ptr %385 to i64
  %387 = insertelement <4 x i64> undef, i64 %386, i32 0
  %388 = shufflevector <4 x i64> %387, <4 x i64> undef, <4 x i32> zeroinitializer
  %389 = add <4 x i64> %388, %25
  %390 = extractelement <4 x i64> %389, i64 1
  %391 = extractelement <4 x i64> %389, i64 3
  %392 = extractelement <4 x i64> %389, i64 2
  %393 = extractelement <4 x i64> %389, i64 0
  %394 = getelementptr inbounds float, ptr %361, i64 %384
  %395 = ptrtoint ptr %394 to i64
  %396 = insertelement <4 x i64> undef, i64 %395, i32 0
  %397 = shufflevector <4 x i64> %396, <4 x i64> undef, <4 x i32> zeroinitializer
  %398 = add <4 x i64> %397, %25
  %399 = extractelement <4 x i64> %398, i64 1
  %400 = extractelement <4 x i64> %398, i64 3
  %401 = extractelement <4 x i64> %398, i64 2
  %402 = extractelement <4 x i64> %398, i64 0
  %403 = add i64 %367, %384
  %404 = getelementptr inbounds float, ptr %359, i64 %403
  %405 = add i64 %87, %384
  %406 = getelementptr inbounds float, ptr %85, i64 %405
  %407 = sub i64 %80, %384
  %408 = call i64 @llvm.smin.i64(i64 %407, i64 4)
  %409 = call i64 @llvm.smax.i64(i64 %408, i64 0)
  %410 = icmp eq i64 %408, 4
  %411 = icmp slt i64 %384, %80
  br i1 %411, label %412, label %482

412:                                              ; preds = %383
  br i1 %410, label %413, label %453

413:                                              ; preds = %412
  %414 = load <4 x float>, ptr %406, align 16
  br i1 %23, label %415, label %417

415:                                              ; preds = %413
  %416 = load <4 x float>, ptr %394, align 4, !invariant.load !1
  br label %430

417:                                              ; preds = %413
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %402, ptr %9, align 8
  %418 = load ptr, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %419 = load float, ptr %418, align 4, !invariant.load !1
  %420 = insertelement <4 x float> zeroinitializer, float %419, i64 0
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %399, ptr %8, align 8
  %421 = load ptr, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %422 = load float, ptr %421, align 4, !invariant.load !1
  %423 = insertelement <4 x float> %420, float %422, i64 1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store i64 %401, ptr %7, align 8
  %424 = load ptr, ptr %7, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %425 = load float, ptr %424, align 4, !invariant.load !1
  %426 = insertelement <4 x float> %423, float %425, i64 2
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store i64 %400, ptr %6, align 8
  %427 = load ptr, ptr %6, align 8
  call void @llvm.lifetime.end.p0(ptr %6)
  %428 = load float, ptr %427, align 4, !invariant.load !1
  %429 = insertelement <4 x float> %426, float %428, i64 3
  br label %430

430:                                              ; preds = %417, %415
  %431 = phi <4 x float> [ %429, %417 ], [ %416, %415 ]
  br i1 %23, label %432, label %434

432:                                              ; preds = %430
  %433 = load <4 x float>, ptr %385, align 4, !invariant.load !1
  br label %447

434:                                              ; preds = %430
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store i64 %393, ptr %5, align 8
  %435 = load ptr, ptr %5, align 8
  call void @llvm.lifetime.end.p0(ptr %5)
  %436 = load float, ptr %435, align 4, !invariant.load !1
  %437 = insertelement <4 x float> zeroinitializer, float %436, i64 0
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store i64 %390, ptr %4, align 8
  %438 = load ptr, ptr %4, align 8
  call void @llvm.lifetime.end.p0(ptr %4)
  %439 = load float, ptr %438, align 4, !invariant.load !1
  %440 = insertelement <4 x float> %437, float %439, i64 1
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store i64 %392, ptr %3, align 8
  %441 = load ptr, ptr %3, align 8
  call void @llvm.lifetime.end.p0(ptr %3)
  %442 = load float, ptr %441, align 4, !invariant.load !1
  %443 = insertelement <4 x float> %440, float %442, i64 2
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store i64 %391, ptr %2, align 8
  %444 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(ptr %2)
  %445 = load float, ptr %444, align 4, !invariant.load !1
  %446 = insertelement <4 x float> %443, float %445, i64 3
  br label %447

447:                                              ; preds = %434, %432
  %448 = phi <4 x float> [ %446, %434 ], [ %433, %432 ]
  %449 = fsub contract <4 x float> %414, %364
  %450 = fmul contract <4 x float> %449, %366
  %451 = fmul contract <4 x float> %450, %431
  %452 = fadd contract <4 x float> %451, %448
  store <4 x float> %452, ptr %404, align 16
  br label %480

453:                                              ; preds = %412
  br label %454

454:                                              ; preds = %460, %453
  %455 = phi i64 [ 0, %453 ], [ %463, %460 ]
  %456 = phi i64 [ %369, %453 ], [ %464, %460 ]
  %457 = icmp slt i64 %455, %409
  br i1 %457, label %458, label %459

458:                                              ; preds = %454
  br label %460

459:                                              ; preds = %454
  br label %478

460:                                              ; preds = %458
  %461 = icmp eq i64 %455, %409
  %462 = add i64 %455, 1
  %463 = select i1 %461, i64 %455, i64 %462
  %464 = add i64 %384, %455
  %465 = add i64 %87, %464
  %466 = getelementptr inbounds float, ptr %85, i64 %465
  %467 = load float, ptr %466, align 4
  %468 = getelementptr inbounds float, ptr %361, i64 %464
  %469 = load float, ptr %468, align 4, !invariant.load !1
  %470 = getelementptr inbounds float, ptr %362, i64 %464
  %471 = load float, ptr %470, align 4, !invariant.load !1
  %472 = fsub contract float %467, %363
  %473 = fmul contract float %472, %365
  %474 = fmul contract float %473, %469
  %475 = fadd contract float %474, %471
  %476 = add i64 %367, %464
  %477 = getelementptr inbounds float, ptr %359, i64 %476
  store float %475, ptr %477, align 4
  br label %454

478:                                              ; preds = %459
  %479 = phi i64 [ %456, %459 ]
  br label %480

480:                                              ; preds = %478, %447
  %481 = phi i64 [ %479, %478 ], [ %384, %447 ]
  br label %483

482:                                              ; preds = %383
  br label %483

483:                                              ; preds = %482, %480
  %484 = phi i64 [ %369, %482 ], [ %481, %480 ]
  br label %368

485:                                              ; preds = %381
  br label %487

486:                                              ; preds = %75
  br label %487

487:                                              ; preds = %486, %485
  br label %46

488:                                              ; preds = %73
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
