; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r1_ax0_w1_bs128_1a9a768a(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
  %2 = alloca { float, float, float }, i64 1, align 4
  %3 = alloca { float, float, float }, i64 1, align 4
  %4 = alloca { float, float, float }, i64 1, align 4
  %5 = alloca { float, float, float }, i64 1, align 4
  %6 = alloca { float, float, float }, i64 1, align 4
  %7 = alloca { float, float, float }, i64 1, align 4
  %8 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %9 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %8, i32 0, i32 5
  %10 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %8, i32 0, i32 4
  %11 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %8, i32 0, i32 3
  %12 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %8, i32 0, i32 2
  %13 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %8, i32 0, i32 1
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %8, i32 0, i32 0
  %15 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %16 = sext i32 %15 to i64
  %17 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %18 = zext i32 %17 to i64
  %19 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %20 = zext i32 %19 to i64
  %21 = mul i64 %20, 4
  %22 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %23 = sext i32 %22 to i64
  %24 = mul i64 %23, 4
  %25 = icmp eq i64 %24, 0
  %26 = select i1 %25, i64 0, i64 %21
  %27 = select i1 %25, i64 0, i64 1
  %28 = select i1 %25, i64 1, i64 %24
  %29 = icmp slt i64 %28, 0
  %30 = icmp sgt i64 %28, 0
  br label %31

31:                                               ; preds = %379, %1
  %32 = phi i64 [ %26, %1 ], [ %56, %379 ]
  %33 = phi i64 [ 0, %1 ], [ %57, %379 ]
  %34 = icmp sge i64 %27, %32
  %35 = icmp sge i64 %32, %27
  %36 = add i64 %32, %28
  %37 = icmp slt i64 %36, %32
  %38 = xor i1 %37, %29
  %39 = select i1 %38, i64 1, i64 0
  %40 = icmp eq i64 %33, 0
  %41 = xor i1 %40, true
  %42 = or i1 %41, %34
  %43 = or i1 %41, %35
  br label %44

44:                                               ; preds = %31
  br i1 %30, label %45, label %50

45:                                               ; preds = %44
  br i1 %43, label %46, label %47

46:                                               ; preds = %45
  br label %53

47:                                               ; preds = %45
  br label %48

48:                                               ; preds = %47
  br label %52

49:                                               ; preds = %50
  br label %52

50:                                               ; preds = %44
  br i1 %42, label %51, label %49

51:                                               ; preds = %50
  br label %53

52:                                               ; preds = %49, %48
  br label %53

53:                                               ; preds = %52, %51, %46
  %54 = phi i1 [ true, %46 ], [ true, %51 ], [ false, %52 ]
  %55 = phi i64 [ undef, %46 ], [ undef, %51 ], [ %32, %52 ]
  %56 = phi i64 [ %32, %46 ], [ %32, %51 ], [ %36, %52 ]
  %57 = phi i64 [ %33, %46 ], [ %33, %51 ], [ %39, %52 ]
  br i1 %54, label %58, label %59

58:                                               ; preds = %53
  br label %380

59:                                               ; preds = %53
  br label %60

60:                                               ; preds = %59
  %61 = udiv i64 %18, 32
  %62 = add i64 %55, %61
  %63 = icmp slt i64 %62, 1
  br i1 %63, label %64, label %378

64:                                               ; preds = %60
  %65 = load i64, ptr %14, align 8
  %66 = load { ptr, { { i64 }, { {} } } }, ptr %13, align 8
  %67 = load { ptr, { { i64 }, { {} } } }, ptr %12, align 8
  %68 = load float, ptr %11, align 4
  %69 = load { ptr, { { i64 }, { {} } } }, ptr %10, align 8
  %70 = extractvalue { ptr, { { i64 }, { {} } } } %69, 0
  br label %71

71:                                               ; preds = %146, %64
  %72 = phi i64 [ 0, %64 ], [ %147, %146 ]
  %73 = phi i64 [ 0, %64 ], [ %86, %146 ]
  %74 = phi i64 [ 0, %64 ], [ %87, %146 ]
  %75 = phi float [ 0.000000e+00, %64 ], [ %148, %146 ]
  %76 = phi float [ 0.000000e+00, %64 ], [ %149, %146 ]
  %77 = phi float [ 0.000000e+00, %64 ], [ %150, %146 ]
  %78 = fadd contract float %75, 1.000000e+00
  %79 = add i64 %73, 32
  %80 = icmp slt i64 %79, %73
  %81 = select i1 %80, i64 1, i64 0
  %82 = icmp sge i64 %73, %65
  %83 = icmp eq i64 %74, 0
  %84 = xor i1 %83, true
  %85 = or i1 %84, %82
  %86 = select i1 %85, i64 %73, i64 %79
  %87 = select i1 %85, i64 %74, i64 %81
  br i1 %85, label %88, label %89

88:                                               ; preds = %71
  br label %151

89:                                               ; preds = %71
  br label %90

90:                                               ; preds = %89
  %91 = add i64 %73, %16
  %92 = getelementptr inbounds float, ptr %70, i64 %91
  %93 = sub i64 %65, %91
  %94 = call i64 @llvm.smin.i64(i64 %93, i64 1)
  %95 = call i64 @llvm.smax.i64(i64 %94, i64 0)
  %96 = icmp eq i64 %94, 1
  %97 = icmp slt i64 %91, %65
  br i1 %97, label %98, label %145

98:                                               ; preds = %90
  br i1 %96, label %99, label %109

99:                                               ; preds = %98
  %100 = load float, ptr %92, align 4
  %101 = fsub contract float %100, %76
  %102 = fdiv float 1.000000e+00, %78
  %103 = fmul contract float %101, %102
  %104 = fadd contract float %76, %103
  %105 = fmul contract float %101, %101
  %106 = fmul contract float %105, %75
  %107 = fmul contract float %106, %102
  %108 = fadd contract float %77, %107
  br label %140

109:                                              ; preds = %98
  br label %110

110:                                              ; preds = %119, %109
  %111 = phi i64 [ 0, %109 ], [ %122, %119 ]
  %112 = phi i64 [ %72, %109 ], [ %123, %119 ]
  %113 = phi float [ %75, %109 ], [ %126, %119 ]
  %114 = phi float [ %76, %109 ], [ %130, %119 ]
  %115 = phi float [ %77, %109 ], [ %134, %119 ]
  %116 = icmp slt i64 %111, %95
  br i1 %116, label %117, label %118

117:                                              ; preds = %110
  br label %119

118:                                              ; preds = %110
  br label %135

119:                                              ; preds = %117
  %120 = icmp eq i64 %111, %95
  %121 = add i64 %111, 1
  %122 = select i1 %120, i64 %111, i64 %121
  %123 = add i64 %91, %111
  %124 = getelementptr inbounds float, ptr %70, i64 %123
  %125 = load float, ptr %124, align 4
  %126 = fadd contract float %113, 1.000000e+00
  %127 = fsub contract float %125, %114
  %128 = fdiv float 1.000000e+00, %126
  %129 = fmul contract float %127, %128
  %130 = fadd contract float %114, %129
  %131 = fmul contract float %127, %127
  %132 = fmul contract float %131, %113
  %133 = fmul contract float %132, %128
  %134 = fadd contract float %115, %133
  br label %110

135:                                              ; preds = %118
  %136 = phi i64 [ %112, %118 ]
  %137 = phi float [ %113, %118 ]
  %138 = phi float [ %114, %118 ]
  %139 = phi float [ %115, %118 ]
  br label %140

140:                                              ; preds = %135, %99
  %141 = phi i64 [ %136, %135 ], [ %91, %99 ]
  %142 = phi float [ %137, %135 ], [ %78, %99 ]
  %143 = phi float [ %138, %135 ], [ %104, %99 ]
  %144 = phi float [ %139, %135 ], [ %108, %99 ]
  br label %146

145:                                              ; preds = %90
  br label %146

146:                                              ; preds = %145, %140
  %147 = phi i64 [ %72, %145 ], [ %141, %140 ]
  %148 = phi float [ %75, %145 ], [ %142, %140 ]
  %149 = phi float [ %76, %145 ], [ %143, %140 ]
  %150 = phi float [ %77, %145 ], [ %144, %140 ]
  br label %71

151:                                              ; preds = %88
  %152 = phi float [ %75, %88 ]
  %153 = phi float [ %76, %88 ]
  %154 = phi float [ %77, %88 ]
  %155 = insertvalue { float, float, float } undef, float %152, 0
  %156 = insertvalue { float, float, float } %155, float %153, 1
  %157 = insertvalue { float, float, float } %156, float %154, 2
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } %157, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %158 = load i32, ptr %7, align 4
  %159 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %158, i32 16, i32 31)
  store i32 %159, ptr %6, align 4
  %160 = getelementptr inbounds i32, ptr %6, i32 1
  %161 = getelementptr inbounds i32, ptr %7, i32 1
  %162 = load i32, ptr %161, align 4
  %163 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %162, i32 16, i32 31)
  store i32 %163, ptr %160, align 4
  %164 = getelementptr inbounds i32, ptr %6, i32 2
  %165 = getelementptr inbounds i32, ptr %7, i32 2
  %166 = load i32, ptr %165, align 4
  %167 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %166, i32 16, i32 31)
  store i32 %167, ptr %164, align 4
  %168 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %169 = getelementptr { float, float, float }, ptr %7, i32 0, i32 0
  %170 = load float, ptr %169, align 4
  %171 = extractvalue { float, float, float } %168, 0
  %172 = fadd contract float %170, %171
  %173 = call float @llvm.maxnum.f32(float %172, float 1.000000e+00)
  %174 = extractvalue { float, float, float } %168, 1
  %175 = getelementptr { float, float, float }, ptr %7, i32 0, i32 1
  %176 = load float, ptr %175, align 4
  %177 = fsub contract float %174, %176
  %178 = fdiv float %171, %173
  %179 = getelementptr { float, float, float }, ptr %7, i32 0, i32 2
  %180 = extractvalue { float, float, float } %168, 2
  %181 = load float, ptr %179, align 4
  %182 = fadd contract float %181, %180
  %183 = fmul contract float %177, %177
  %184 = fmul contract float %183, %170
  %185 = fmul contract float %184, %178
  %186 = fadd contract float %182, %185
  store float %186, ptr %179, align 4
  %187 = fmul contract float %177, %178
  %188 = load float, ptr %175, align 4
  %189 = fadd contract float %188, %187
  store float %189, ptr %175, align 4
  store float %172, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %190 = load i32, ptr %7, align 4
  %191 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %190, i32 8, i32 31)
  store i32 %191, ptr %5, align 4
  %192 = getelementptr inbounds i32, ptr %5, i32 1
  %193 = load i32, ptr %161, align 4
  %194 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %193, i32 8, i32 31)
  store i32 %194, ptr %192, align 4
  %195 = getelementptr inbounds i32, ptr %5, i32 2
  %196 = load i32, ptr %165, align 4
  %197 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %196, i32 8, i32 31)
  store i32 %197, ptr %195, align 4
  %198 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %199 = load float, ptr %169, align 4
  %200 = extractvalue { float, float, float } %198, 0
  %201 = fadd contract float %199, %200
  %202 = call float @llvm.maxnum.f32(float %201, float 1.000000e+00)
  %203 = extractvalue { float, float, float } %198, 1
  %204 = load float, ptr %175, align 4
  %205 = fsub contract float %203, %204
  %206 = fdiv float %200, %202
  %207 = extractvalue { float, float, float } %198, 2
  %208 = load float, ptr %179, align 4
  %209 = fadd contract float %208, %207
  %210 = fmul contract float %205, %205
  %211 = fmul contract float %210, %199
  %212 = fmul contract float %211, %206
  %213 = fadd contract float %209, %212
  store float %213, ptr %179, align 4
  %214 = fmul contract float %205, %206
  %215 = load float, ptr %175, align 4
  %216 = fadd contract float %215, %214
  store float %216, ptr %175, align 4
  store float %201, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %217 = load i32, ptr %7, align 4
  %218 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %217, i32 4, i32 31)
  store i32 %218, ptr %4, align 4
  %219 = getelementptr inbounds i32, ptr %4, i32 1
  %220 = load i32, ptr %161, align 4
  %221 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %220, i32 4, i32 31)
  store i32 %221, ptr %219, align 4
  %222 = getelementptr inbounds i32, ptr %4, i32 2
  %223 = load i32, ptr %165, align 4
  %224 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %223, i32 4, i32 31)
  store i32 %224, ptr %222, align 4
  %225 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %226 = load float, ptr %169, align 4
  %227 = extractvalue { float, float, float } %225, 0
  %228 = fadd contract float %226, %227
  %229 = call float @llvm.maxnum.f32(float %228, float 1.000000e+00)
  %230 = extractvalue { float, float, float } %225, 1
  %231 = load float, ptr %175, align 4
  %232 = fsub contract float %230, %231
  %233 = fdiv float %227, %229
  %234 = extractvalue { float, float, float } %225, 2
  %235 = load float, ptr %179, align 4
  %236 = fadd contract float %235, %234
  %237 = fmul contract float %232, %232
  %238 = fmul contract float %237, %226
  %239 = fmul contract float %238, %233
  %240 = fadd contract float %236, %239
  store float %240, ptr %179, align 4
  %241 = fmul contract float %232, %233
  %242 = load float, ptr %175, align 4
  %243 = fadd contract float %242, %241
  store float %243, ptr %175, align 4
  store float %228, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %244 = load i32, ptr %7, align 4
  %245 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %244, i32 2, i32 31)
  store i32 %245, ptr %3, align 4
  %246 = getelementptr inbounds i32, ptr %3, i32 1
  %247 = load i32, ptr %161, align 4
  %248 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %247, i32 2, i32 31)
  store i32 %248, ptr %246, align 4
  %249 = getelementptr inbounds i32, ptr %3, i32 2
  %250 = load i32, ptr %165, align 4
  %251 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %250, i32 2, i32 31)
  store i32 %251, ptr %249, align 4
  %252 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %253 = load float, ptr %169, align 4
  %254 = extractvalue { float, float, float } %252, 0
  %255 = fadd contract float %253, %254
  %256 = call float @llvm.maxnum.f32(float %255, float 1.000000e+00)
  %257 = extractvalue { float, float, float } %252, 1
  %258 = load float, ptr %175, align 4
  %259 = fsub contract float %257, %258
  %260 = fdiv float %254, %256
  %261 = extractvalue { float, float, float } %252, 2
  %262 = load float, ptr %179, align 4
  %263 = fadd contract float %262, %261
  %264 = fmul contract float %259, %259
  %265 = fmul contract float %264, %253
  %266 = fmul contract float %265, %260
  %267 = fadd contract float %263, %266
  store float %267, ptr %179, align 4
  %268 = fmul contract float %259, %260
  %269 = load float, ptr %175, align 4
  %270 = fadd contract float %269, %268
  store float %270, ptr %175, align 4
  store float %255, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %271 = load i32, ptr %7, align 4
  %272 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %271, i32 1, i32 31)
  store i32 %272, ptr %2, align 4
  %273 = getelementptr inbounds i32, ptr %2, i32 1
  %274 = load i32, ptr %161, align 4
  %275 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %274, i32 1, i32 31)
  store i32 %275, ptr %273, align 4
  %276 = getelementptr inbounds i32, ptr %2, i32 2
  %277 = load i32, ptr %165, align 4
  %278 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %277, i32 1, i32 31)
  store i32 %278, ptr %276, align 4
  %279 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %280 = load float, ptr %169, align 4
  %281 = extractvalue { float, float, float } %279, 0
  %282 = fadd contract float %280, %281
  %283 = call float @llvm.maxnum.f32(float %282, float 1.000000e+00)
  %284 = extractvalue { float, float, float } %279, 1
  %285 = load float, ptr %175, align 4
  %286 = fsub contract float %284, %285
  %287 = fdiv float %281, %283
  %288 = extractvalue { float, float, float } %279, 2
  %289 = load float, ptr %179, align 4
  %290 = fadd contract float %289, %288
  %291 = fmul contract float %286, %286
  %292 = fmul contract float %291, %280
  %293 = fmul contract float %292, %287
  %294 = fadd contract float %290, %293
  store float %294, ptr %179, align 4
  %295 = fmul contract float %286, %287
  %296 = load float, ptr %175, align 4
  %297 = fadd contract float %296, %295
  store float %297, ptr %175, align 4
  store float %282, ptr %169, align 4
  %298 = load float, ptr %175, align 4
  store float %298, ptr %175, align 4
  %299 = load float, ptr %179, align 4
  store float %299, ptr %179, align 4
  %300 = load float, ptr %169, align 4
  store float %300, ptr %169, align 4
  %301 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %302 = extractvalue { float, float, float } %301, 0
  %303 = extractvalue { float, float, float } %301, 1
  %304 = extractvalue { float, float, float } %301, 2
  %305 = fdiv float %304, %302
  %306 = fadd contract float %305, %68
  %307 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %306)
  %308 = load { ptr, { { i64 }, { {} } } }, ptr %9, align 8
  %309 = extractvalue { ptr, { { i64 }, { {} } } } %308, 0
  %310 = extractvalue { ptr, { { i64 }, { {} } } } %66, 0
  %311 = extractvalue { ptr, { { i64 }, { {} } } } %67, 0
  br label %312

312:                                              ; preds = %375, %151
  %313 = phi i64 [ 0, %151 ], [ %376, %375 ]
  %314 = phi i64 [ 0, %151 ], [ %323, %375 ]
  %315 = phi i64 [ 0, %151 ], [ %324, %375 ]
  %316 = add i64 %314, 32
  %317 = icmp slt i64 %316, %314
  %318 = select i1 %317, i64 1, i64 0
  %319 = icmp sge i64 %314, %65
  %320 = icmp eq i64 %315, 0
  %321 = xor i1 %320, true
  %322 = or i1 %321, %319
  %323 = select i1 %322, i64 %314, i64 %316
  %324 = select i1 %322, i64 %315, i64 %318
  br i1 %322, label %325, label %326

325:                                              ; preds = %312
  br label %377

326:                                              ; preds = %312
  br label %327

327:                                              ; preds = %326
  %328 = add i64 %314, %16
  %329 = getelementptr inbounds float, ptr %309, i64 %328
  %330 = getelementptr inbounds float, ptr %311, i64 %328
  %331 = getelementptr inbounds float, ptr %310, i64 %328
  %332 = getelementptr inbounds float, ptr %70, i64 %328
  %333 = sub i64 %65, %328
  %334 = call i64 @llvm.smin.i64(i64 %333, i64 1)
  %335 = call i64 @llvm.smax.i64(i64 %334, i64 0)
  %336 = icmp eq i64 %334, 1
  %337 = icmp slt i64 %328, %65
  br i1 %337, label %338, label %374

338:                                              ; preds = %327
  br i1 %336, label %339, label %347

339:                                              ; preds = %338
  %340 = load float, ptr %332, align 4
  %341 = load float, ptr %331, align 4, !invariant.load !1
  %342 = load float, ptr %330, align 4, !invariant.load !1
  %343 = fsub contract float %340, %303
  %344 = fmul contract float %343, %307
  %345 = fmul contract float %344, %341
  %346 = fadd contract float %345, %342
  store float %346, ptr %329, align 4
  br label %372

347:                                              ; preds = %338
  br label %348

348:                                              ; preds = %354, %347
  %349 = phi i64 [ 0, %347 ], [ %357, %354 ]
  %350 = phi i64 [ %313, %347 ], [ %358, %354 ]
  %351 = icmp slt i64 %349, %335
  br i1 %351, label %352, label %353

352:                                              ; preds = %348
  br label %354

353:                                              ; preds = %348
  br label %370

354:                                              ; preds = %352
  %355 = icmp eq i64 %349, %335
  %356 = add i64 %349, 1
  %357 = select i1 %355, i64 %349, i64 %356
  %358 = add i64 %328, %349
  %359 = getelementptr inbounds float, ptr %70, i64 %358
  %360 = load float, ptr %359, align 4
  %361 = getelementptr inbounds float, ptr %310, i64 %358
  %362 = load float, ptr %361, align 4, !invariant.load !1
  %363 = getelementptr inbounds float, ptr %311, i64 %358
  %364 = load float, ptr %363, align 4, !invariant.load !1
  %365 = fsub contract float %360, %303
  %366 = fmul contract float %365, %307
  %367 = fmul contract float %366, %362
  %368 = fadd contract float %367, %364
  %369 = getelementptr inbounds float, ptr %309, i64 %358
  store float %368, ptr %369, align 4
  br label %348

370:                                              ; preds = %353
  %371 = phi i64 [ %350, %353 ]
  br label %372

372:                                              ; preds = %370, %339
  %373 = phi i64 [ %371, %370 ], [ %328, %339 ]
  br label %375

374:                                              ; preds = %327
  br label %375

375:                                              ; preds = %374, %372
  %376 = phi i64 [ %313, %374 ], [ %373, %372 ]
  br label %312

377:                                              ; preds = %325
  br label %379

378:                                              ; preds = %60
  br label %379

379:                                              ; preds = %378, %377
  br label %31

380:                                              ; preds = %58
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
