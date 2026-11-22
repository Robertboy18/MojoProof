; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r2_ax1_w1_bs128_48df3ecd(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
  %2 = alloca { float, float, float }, i64 1, align 4
  %3 = alloca { float, float, float }, i64 1, align 4
  %4 = alloca { float, float, float }, i64 1, align 4
  %5 = alloca { float, float, float }, i64 1, align 4
  %6 = alloca { float, float, float }, i64 1, align 4
  %7 = alloca { float, float, float }, i64 1, align 4
  %8 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %9 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %8, i32 0, i32 5
  %10 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %8, i32 0, i32 4
  %11 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %8, i32 0, i32 3
  %12 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %8, i32 0, i32 2
  %13 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %8, i32 0, i32 1
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %8, i32 0, i32 0
  %15 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %16 = sext i32 %15 to i64
  %17 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %18 = zext i32 %17 to i64
  %19 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %20 = load { i64, i64 }, ptr %19, align 8
  %21 = extractvalue { i64, i64 } %20, 0
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %23 = zext i32 %22 to i64
  %24 = mul i64 %23, 4
  %25 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %26 = sext i32 %25 to i64
  %27 = mul i64 %26, 4
  %28 = icmp eq i64 %27, 0
  %29 = select i1 %28, i64 0, i64 %24
  %30 = select i1 %28, i64 0, i64 %21
  %31 = select i1 %28, i64 1, i64 %27
  %32 = icmp slt i64 %31, 0
  %33 = icmp sgt i64 %31, 0
  br label %34

34:                                               ; preds = %392, %1
  %35 = phi i64 [ %29, %1 ], [ %59, %392 ]
  %36 = phi i64 [ 0, %1 ], [ %60, %392 ]
  %37 = icmp sge i64 %30, %35
  %38 = icmp sge i64 %35, %30
  %39 = add i64 %35, %31
  %40 = icmp slt i64 %39, %35
  %41 = xor i1 %40, %32
  %42 = select i1 %41, i64 1, i64 0
  %43 = icmp eq i64 %36, 0
  %44 = xor i1 %43, true
  %45 = or i1 %44, %37
  %46 = or i1 %44, %38
  br label %47

47:                                               ; preds = %34
  br i1 %33, label %48, label %53

48:                                               ; preds = %47
  br i1 %46, label %49, label %50

49:                                               ; preds = %48
  br label %56

50:                                               ; preds = %48
  br label %51

51:                                               ; preds = %50
  br label %55

52:                                               ; preds = %53
  br label %55

53:                                               ; preds = %47
  br i1 %45, label %54, label %52

54:                                               ; preds = %53
  br label %56

55:                                               ; preds = %52, %51
  br label %56

56:                                               ; preds = %55, %54, %49
  %57 = phi i1 [ true, %49 ], [ true, %54 ], [ false, %55 ]
  %58 = phi i64 [ undef, %49 ], [ undef, %54 ], [ %35, %55 ]
  %59 = phi i64 [ %35, %49 ], [ %35, %54 ], [ %39, %55 ]
  %60 = phi i64 [ %36, %49 ], [ %36, %54 ], [ %42, %55 ]
  br i1 %57, label %61, label %62

61:                                               ; preds = %56
  br label %393

62:                                               ; preds = %56
  br label %63

63:                                               ; preds = %62
  %64 = udiv i64 %18, 32
  %65 = add i64 %58, %64
  %66 = icmp slt i64 %65, %21
  br i1 %66, label %67, label %391

67:                                               ; preds = %63
  %68 = load i64, ptr %14, align 8
  %69 = load { ptr, { { i64 }, { {} } } }, ptr %13, align 8
  %70 = load { ptr, { { i64 }, { {} } } }, ptr %12, align 8
  %71 = load float, ptr %11, align 4
  %72 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %10, align 8
  %73 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %72, 0
  %74 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %72, 1, 1, 0
  %75 = mul i64 %65, %74
  br label %76

76:                                               ; preds = %153, %67
  %77 = phi i64 [ 0, %67 ], [ %154, %153 ]
  %78 = phi i64 [ 0, %67 ], [ %91, %153 ]
  %79 = phi i64 [ 0, %67 ], [ %92, %153 ]
  %80 = phi float [ 0.000000e+00, %67 ], [ %155, %153 ]
  %81 = phi float [ 0.000000e+00, %67 ], [ %156, %153 ]
  %82 = phi float [ 0.000000e+00, %67 ], [ %157, %153 ]
  %83 = fadd contract float %80, 1.000000e+00
  %84 = add i64 %78, 32
  %85 = icmp slt i64 %84, %78
  %86 = select i1 %85, i64 1, i64 0
  %87 = icmp sge i64 %78, %68
  %88 = icmp eq i64 %79, 0
  %89 = xor i1 %88, true
  %90 = or i1 %89, %87
  %91 = select i1 %90, i64 %78, i64 %84
  %92 = select i1 %90, i64 %79, i64 %86
  br i1 %90, label %93, label %94

93:                                               ; preds = %76
  br label %158

94:                                               ; preds = %76
  br label %95

95:                                               ; preds = %94
  %96 = add i64 %78, %16
  %97 = add i64 %75, %96
  %98 = getelementptr inbounds float, ptr %73, i64 %97
  %99 = sub i64 %68, %96
  %100 = call i64 @llvm.smin.i64(i64 %99, i64 1)
  %101 = call i64 @llvm.smax.i64(i64 %100, i64 0)
  %102 = icmp eq i64 %100, 1
  %103 = icmp slt i64 %96, %68
  br i1 %103, label %104, label %152

104:                                              ; preds = %95
  br i1 %102, label %105, label %115

105:                                              ; preds = %104
  %106 = load float, ptr %98, align 4
  %107 = fsub contract float %106, %81
  %108 = fdiv float 1.000000e+00, %83
  %109 = fmul contract float %107, %108
  %110 = fadd contract float %81, %109
  %111 = fmul contract float %107, %107
  %112 = fmul contract float %111, %80
  %113 = fmul contract float %112, %108
  %114 = fadd contract float %82, %113
  br label %147

115:                                              ; preds = %104
  br label %116

116:                                              ; preds = %125, %115
  %117 = phi i64 [ 0, %115 ], [ %128, %125 ]
  %118 = phi i64 [ %77, %115 ], [ %129, %125 ]
  %119 = phi float [ %80, %115 ], [ %133, %125 ]
  %120 = phi float [ %81, %115 ], [ %137, %125 ]
  %121 = phi float [ %82, %115 ], [ %141, %125 ]
  %122 = icmp slt i64 %117, %101
  br i1 %122, label %123, label %124

123:                                              ; preds = %116
  br label %125

124:                                              ; preds = %116
  br label %142

125:                                              ; preds = %123
  %126 = icmp eq i64 %117, %101
  %127 = add i64 %117, 1
  %128 = select i1 %126, i64 %117, i64 %127
  %129 = add i64 %96, %117
  %130 = add i64 %75, %129
  %131 = getelementptr inbounds float, ptr %73, i64 %130
  %132 = load float, ptr %131, align 4
  %133 = fadd contract float %119, 1.000000e+00
  %134 = fsub contract float %132, %120
  %135 = fdiv float 1.000000e+00, %133
  %136 = fmul contract float %134, %135
  %137 = fadd contract float %120, %136
  %138 = fmul contract float %134, %134
  %139 = fmul contract float %138, %119
  %140 = fmul contract float %139, %135
  %141 = fadd contract float %121, %140
  br label %116

142:                                              ; preds = %124
  %143 = phi i64 [ %118, %124 ]
  %144 = phi float [ %119, %124 ]
  %145 = phi float [ %120, %124 ]
  %146 = phi float [ %121, %124 ]
  br label %147

147:                                              ; preds = %142, %105
  %148 = phi i64 [ %143, %142 ], [ %96, %105 ]
  %149 = phi float [ %144, %142 ], [ %83, %105 ]
  %150 = phi float [ %145, %142 ], [ %110, %105 ]
  %151 = phi float [ %146, %142 ], [ %114, %105 ]
  br label %153

152:                                              ; preds = %95
  br label %153

153:                                              ; preds = %152, %147
  %154 = phi i64 [ %77, %152 ], [ %148, %147 ]
  %155 = phi float [ %80, %152 ], [ %149, %147 ]
  %156 = phi float [ %81, %152 ], [ %150, %147 ]
  %157 = phi float [ %82, %152 ], [ %151, %147 ]
  br label %76

158:                                              ; preds = %93
  %159 = phi float [ %80, %93 ]
  %160 = phi float [ %81, %93 ]
  %161 = phi float [ %82, %93 ]
  %162 = insertvalue { float, float, float } undef, float %159, 0
  %163 = insertvalue { float, float, float } %162, float %160, 1
  %164 = insertvalue { float, float, float } %163, float %161, 2
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } %164, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %165 = load i32, ptr %7, align 4
  %166 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %165, i32 16, i32 31)
  store i32 %166, ptr %6, align 4
  %167 = getelementptr inbounds i32, ptr %6, i32 1
  %168 = getelementptr inbounds i32, ptr %7, i32 1
  %169 = load i32, ptr %168, align 4
  %170 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %169, i32 16, i32 31)
  store i32 %170, ptr %167, align 4
  %171 = getelementptr inbounds i32, ptr %6, i32 2
  %172 = getelementptr inbounds i32, ptr %7, i32 2
  %173 = load i32, ptr %172, align 4
  %174 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %173, i32 16, i32 31)
  store i32 %174, ptr %171, align 4
  %175 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %176 = getelementptr { float, float, float }, ptr %7, i32 0, i32 0
  %177 = load float, ptr %176, align 4
  %178 = extractvalue { float, float, float } %175, 0
  %179 = fadd contract float %177, %178
  %180 = call float @llvm.maxnum.f32(float %179, float 1.000000e+00)
  %181 = extractvalue { float, float, float } %175, 1
  %182 = getelementptr { float, float, float }, ptr %7, i32 0, i32 1
  %183 = load float, ptr %182, align 4
  %184 = fsub contract float %181, %183
  %185 = fdiv float %178, %180
  %186 = getelementptr { float, float, float }, ptr %7, i32 0, i32 2
  %187 = extractvalue { float, float, float } %175, 2
  %188 = load float, ptr %186, align 4
  %189 = fadd contract float %188, %187
  %190 = fmul contract float %184, %184
  %191 = fmul contract float %190, %177
  %192 = fmul contract float %191, %185
  %193 = fadd contract float %189, %192
  store float %193, ptr %186, align 4
  %194 = fmul contract float %184, %185
  %195 = load float, ptr %182, align 4
  %196 = fadd contract float %195, %194
  store float %196, ptr %182, align 4
  store float %179, ptr %176, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %197 = load i32, ptr %7, align 4
  %198 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %197, i32 8, i32 31)
  store i32 %198, ptr %5, align 4
  %199 = getelementptr inbounds i32, ptr %5, i32 1
  %200 = load i32, ptr %168, align 4
  %201 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %200, i32 8, i32 31)
  store i32 %201, ptr %199, align 4
  %202 = getelementptr inbounds i32, ptr %5, i32 2
  %203 = load i32, ptr %172, align 4
  %204 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %203, i32 8, i32 31)
  store i32 %204, ptr %202, align 4
  %205 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %206 = load float, ptr %176, align 4
  %207 = extractvalue { float, float, float } %205, 0
  %208 = fadd contract float %206, %207
  %209 = call float @llvm.maxnum.f32(float %208, float 1.000000e+00)
  %210 = extractvalue { float, float, float } %205, 1
  %211 = load float, ptr %182, align 4
  %212 = fsub contract float %210, %211
  %213 = fdiv float %207, %209
  %214 = extractvalue { float, float, float } %205, 2
  %215 = load float, ptr %186, align 4
  %216 = fadd contract float %215, %214
  %217 = fmul contract float %212, %212
  %218 = fmul contract float %217, %206
  %219 = fmul contract float %218, %213
  %220 = fadd contract float %216, %219
  store float %220, ptr %186, align 4
  %221 = fmul contract float %212, %213
  %222 = load float, ptr %182, align 4
  %223 = fadd contract float %222, %221
  store float %223, ptr %182, align 4
  store float %208, ptr %176, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %224 = load i32, ptr %7, align 4
  %225 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %224, i32 4, i32 31)
  store i32 %225, ptr %4, align 4
  %226 = getelementptr inbounds i32, ptr %4, i32 1
  %227 = load i32, ptr %168, align 4
  %228 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %227, i32 4, i32 31)
  store i32 %228, ptr %226, align 4
  %229 = getelementptr inbounds i32, ptr %4, i32 2
  %230 = load i32, ptr %172, align 4
  %231 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %230, i32 4, i32 31)
  store i32 %231, ptr %229, align 4
  %232 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %233 = load float, ptr %176, align 4
  %234 = extractvalue { float, float, float } %232, 0
  %235 = fadd contract float %233, %234
  %236 = call float @llvm.maxnum.f32(float %235, float 1.000000e+00)
  %237 = extractvalue { float, float, float } %232, 1
  %238 = load float, ptr %182, align 4
  %239 = fsub contract float %237, %238
  %240 = fdiv float %234, %236
  %241 = extractvalue { float, float, float } %232, 2
  %242 = load float, ptr %186, align 4
  %243 = fadd contract float %242, %241
  %244 = fmul contract float %239, %239
  %245 = fmul contract float %244, %233
  %246 = fmul contract float %245, %240
  %247 = fadd contract float %243, %246
  store float %247, ptr %186, align 4
  %248 = fmul contract float %239, %240
  %249 = load float, ptr %182, align 4
  %250 = fadd contract float %249, %248
  store float %250, ptr %182, align 4
  store float %235, ptr %176, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %251 = load i32, ptr %7, align 4
  %252 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %251, i32 2, i32 31)
  store i32 %252, ptr %3, align 4
  %253 = getelementptr inbounds i32, ptr %3, i32 1
  %254 = load i32, ptr %168, align 4
  %255 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %254, i32 2, i32 31)
  store i32 %255, ptr %253, align 4
  %256 = getelementptr inbounds i32, ptr %3, i32 2
  %257 = load i32, ptr %172, align 4
  %258 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %257, i32 2, i32 31)
  store i32 %258, ptr %256, align 4
  %259 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %260 = load float, ptr %176, align 4
  %261 = extractvalue { float, float, float } %259, 0
  %262 = fadd contract float %260, %261
  %263 = call float @llvm.maxnum.f32(float %262, float 1.000000e+00)
  %264 = extractvalue { float, float, float } %259, 1
  %265 = load float, ptr %182, align 4
  %266 = fsub contract float %264, %265
  %267 = fdiv float %261, %263
  %268 = extractvalue { float, float, float } %259, 2
  %269 = load float, ptr %186, align 4
  %270 = fadd contract float %269, %268
  %271 = fmul contract float %266, %266
  %272 = fmul contract float %271, %260
  %273 = fmul contract float %272, %267
  %274 = fadd contract float %270, %273
  store float %274, ptr %186, align 4
  %275 = fmul contract float %266, %267
  %276 = load float, ptr %182, align 4
  %277 = fadd contract float %276, %275
  store float %277, ptr %182, align 4
  store float %262, ptr %176, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %278 = load i32, ptr %7, align 4
  %279 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %278, i32 1, i32 31)
  store i32 %279, ptr %2, align 4
  %280 = getelementptr inbounds i32, ptr %2, i32 1
  %281 = load i32, ptr %168, align 4
  %282 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %281, i32 1, i32 31)
  store i32 %282, ptr %280, align 4
  %283 = getelementptr inbounds i32, ptr %2, i32 2
  %284 = load i32, ptr %172, align 4
  %285 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %284, i32 1, i32 31)
  store i32 %285, ptr %283, align 4
  %286 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %287 = load float, ptr %176, align 4
  %288 = extractvalue { float, float, float } %286, 0
  %289 = fadd contract float %287, %288
  %290 = call float @llvm.maxnum.f32(float %289, float 1.000000e+00)
  %291 = extractvalue { float, float, float } %286, 1
  %292 = load float, ptr %182, align 4
  %293 = fsub contract float %291, %292
  %294 = fdiv float %288, %290
  %295 = extractvalue { float, float, float } %286, 2
  %296 = load float, ptr %186, align 4
  %297 = fadd contract float %296, %295
  %298 = fmul contract float %293, %293
  %299 = fmul contract float %298, %287
  %300 = fmul contract float %299, %294
  %301 = fadd contract float %297, %300
  store float %301, ptr %186, align 4
  %302 = fmul contract float %293, %294
  %303 = load float, ptr %182, align 4
  %304 = fadd contract float %303, %302
  store float %304, ptr %182, align 4
  store float %289, ptr %176, align 4
  %305 = load float, ptr %182, align 4
  store float %305, ptr %182, align 4
  %306 = load float, ptr %186, align 4
  store float %306, ptr %186, align 4
  %307 = load float, ptr %176, align 4
  store float %307, ptr %176, align 4
  %308 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %309 = extractvalue { float, float, float } %308, 0
  %310 = extractvalue { float, float, float } %308, 1
  %311 = extractvalue { float, float, float } %308, 2
  %312 = fdiv float %311, %309
  %313 = fadd contract float %312, %71
  %314 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %313)
  %315 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %9, align 8
  %316 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %315, 0
  %317 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %315, 1, 1, 0
  %318 = extractvalue { ptr, { { i64 }, { {} } } } %69, 0
  %319 = extractvalue { ptr, { { i64 }, { {} } } } %70, 0
  %320 = mul i64 %65, %317
  br label %321

321:                                              ; preds = %388, %158
  %322 = phi i64 [ 0, %158 ], [ %389, %388 ]
  %323 = phi i64 [ 0, %158 ], [ %332, %388 ]
  %324 = phi i64 [ 0, %158 ], [ %333, %388 ]
  %325 = add i64 %323, 32
  %326 = icmp slt i64 %325, %323
  %327 = select i1 %326, i64 1, i64 0
  %328 = icmp sge i64 %323, %68
  %329 = icmp eq i64 %324, 0
  %330 = xor i1 %329, true
  %331 = or i1 %330, %328
  %332 = select i1 %331, i64 %323, i64 %325
  %333 = select i1 %331, i64 %324, i64 %327
  br i1 %331, label %334, label %335

334:                                              ; preds = %321
  br label %390

335:                                              ; preds = %321
  br label %336

336:                                              ; preds = %335
  %337 = add i64 %323, %16
  %338 = getelementptr inbounds float, ptr %319, i64 %337
  %339 = getelementptr inbounds float, ptr %318, i64 %337
  %340 = add i64 %320, %337
  %341 = getelementptr inbounds float, ptr %316, i64 %340
  %342 = add i64 %75, %337
  %343 = getelementptr inbounds float, ptr %73, i64 %342
  %344 = sub i64 %68, %337
  %345 = call i64 @llvm.smin.i64(i64 %344, i64 1)
  %346 = call i64 @llvm.smax.i64(i64 %345, i64 0)
  %347 = icmp eq i64 %345, 1
  %348 = icmp slt i64 %337, %68
  br i1 %348, label %349, label %387

349:                                              ; preds = %336
  br i1 %347, label %350, label %358

350:                                              ; preds = %349
  %351 = load float, ptr %343, align 4
  %352 = load float, ptr %339, align 4, !invariant.load !1
  %353 = load float, ptr %338, align 4, !invariant.load !1
  %354 = fsub contract float %351, %310
  %355 = fmul contract float %354, %314
  %356 = fmul contract float %355, %352
  %357 = fadd contract float %356, %353
  store float %357, ptr %341, align 4
  br label %385

358:                                              ; preds = %349
  br label %359

359:                                              ; preds = %365, %358
  %360 = phi i64 [ 0, %358 ], [ %368, %365 ]
  %361 = phi i64 [ %322, %358 ], [ %369, %365 ]
  %362 = icmp slt i64 %360, %346
  br i1 %362, label %363, label %364

363:                                              ; preds = %359
  br label %365

364:                                              ; preds = %359
  br label %383

365:                                              ; preds = %363
  %366 = icmp eq i64 %360, %346
  %367 = add i64 %360, 1
  %368 = select i1 %366, i64 %360, i64 %367
  %369 = add i64 %337, %360
  %370 = add i64 %75, %369
  %371 = getelementptr inbounds float, ptr %73, i64 %370
  %372 = load float, ptr %371, align 4
  %373 = getelementptr inbounds float, ptr %318, i64 %369
  %374 = load float, ptr %373, align 4, !invariant.load !1
  %375 = getelementptr inbounds float, ptr %319, i64 %369
  %376 = load float, ptr %375, align 4, !invariant.load !1
  %377 = fsub contract float %372, %310
  %378 = fmul contract float %377, %314
  %379 = fmul contract float %378, %374
  %380 = fadd contract float %379, %376
  %381 = add i64 %320, %369
  %382 = getelementptr inbounds float, ptr %316, i64 %381
  store float %380, ptr %382, align 4
  br label %359

383:                                              ; preds = %364
  %384 = phi i64 [ %361, %364 ]
  br label %385

385:                                              ; preds = %383, %350
  %386 = phi i64 [ %384, %383 ], [ %337, %350 ]
  br label %388

387:                                              ; preds = %336
  br label %388

388:                                              ; preds = %387, %385
  %389 = phi i64 [ %322, %387 ], [ %386, %385 ]
  br label %321

390:                                              ; preds = %334
  br label %392

391:                                              ; preds = %63
  br label %392

392:                                              ; preds = %391, %390
  br label %34

393:                                              ; preds = %61
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, -2147483648) i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #3

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #4

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none)
declare float @llvm.nvvm.rsqrt.approx.ftz.f(float) #5

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #5 = { nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
