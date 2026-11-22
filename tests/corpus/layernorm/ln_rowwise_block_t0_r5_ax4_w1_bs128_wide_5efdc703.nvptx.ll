; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
  %2 = alloca { float, float, float }, i64 1, align 4
  %3 = alloca { float, float, float }, i64 1, align 4
  %4 = alloca { float, float, float }, i64 1, align 4
  %5 = alloca { float, float, float }, i64 1, align 4
  %6 = alloca { float, float, float }, i64 1, align 4
  %7 = alloca { float, float, float }, i64 1, align 4
  %8 = alloca { float, float, float }, i64 1, align 4
  %9 = alloca { float, float, float }, i64 1, align 4
  %10 = alloca { float, float, float }, i64 1, align 4
  %11 = alloca { float, float, float }, i64 1, align 4
  %12 = alloca { float, float, float }, i64 1, align 4
  %13 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 5
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 4
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 3
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 2
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 1
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 0
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %21 = sext i32 %20 to i64
  %22 = icmp slt i64 %21, 4
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %24 = zext i32 %23 to i64
  %25 = icmp eq i64 %21, 0
  %26 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %27 = load { i64, i64, i64, i64, i64 }, ptr %26, align 8
  %28 = extractvalue { i64, i64, i64, i64, i64 } %27, 0
  %29 = extractvalue { i64, i64, i64, i64, i64 } %27, 1
  %30 = mul i64 %28, %29
  %31 = extractvalue { i64, i64, i64, i64, i64 } %27, 2
  %32 = mul i64 %30, %31
  %33 = extractvalue { i64, i64, i64, i64, i64 } %27, 3
  %34 = mul i64 %32, %33
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %36 = zext i32 %35 to i64
  %37 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %38 = sext i32 %37 to i64
  %39 = icmp eq i64 %38, 0
  %40 = select i1 %39, i64 0, i64 %36
  %41 = select i1 %39, i64 0, i64 %34
  %42 = select i1 %39, i64 1, i64 %38
  %43 = icmp slt i64 %42, 0
  %44 = icmp sgt i64 %42, 0
  br label %45

45:                                               ; preds = %638, %1
  %46 = phi i64 [ %40, %1 ], [ %70, %638 ]
  %47 = phi i64 [ 0, %1 ], [ %71, %638 ]
  %48 = icmp sge i64 %41, %46
  %49 = icmp sge i64 %46, %41
  %50 = add i64 %46, %42
  %51 = icmp slt i64 %50, %46
  %52 = xor i1 %51, %43
  %53 = select i1 %52, i64 1, i64 0
  %54 = icmp eq i64 %47, 0
  %55 = xor i1 %54, true
  %56 = or i1 %55, %48
  %57 = or i1 %55, %49
  br label %58

58:                                               ; preds = %45
  br i1 %44, label %59, label %64

59:                                               ; preds = %58
  br i1 %57, label %60, label %61

60:                                               ; preds = %59
  br label %67

61:                                               ; preds = %59
  br label %62

62:                                               ; preds = %61
  br label %66

63:                                               ; preds = %64
  br label %66

64:                                               ; preds = %58
  br i1 %56, label %65, label %63

65:                                               ; preds = %64
  br label %67

66:                                               ; preds = %63, %62
  br label %67

67:                                               ; preds = %66, %65, %60
  %68 = phi i1 [ true, %60 ], [ true, %65 ], [ false, %66 ]
  %69 = phi i64 [ undef, %60 ], [ undef, %65 ], [ %46, %66 ]
  %70 = phi i64 [ %46, %60 ], [ %46, %65 ], [ %50, %66 ]
  %71 = phi i64 [ %47, %60 ], [ %47, %65 ], [ %53, %66 ]
  br i1 %68, label %72, label %73

72:                                               ; preds = %67
  br label %639

73:                                               ; preds = %67
  br label %74

74:                                               ; preds = %73
  %75 = load { i64, i64, i64, i64, i64 }, ptr %26, align 8
  %76 = extractvalue { i64, i64, i64, i64, i64 } %75, 0
  %77 = extractvalue { i64, i64, i64, i64, i64 } %75, 1
  %78 = extractvalue { i64, i64, i64, i64, i64 } %75, 2
  %79 = extractvalue { i64, i64, i64, i64, i64 } %75, 3
  %80 = icmp slt i64 %76, 0
  %81 = icmp eq i64 %76, 0
  %82 = select i1 %81, i64 1, i64 %76
  %83 = icmp slt i64 %77, 0
  %84 = icmp eq i64 %77, 0
  %85 = select i1 %84, i64 1, i64 %77
  %86 = icmp slt i64 %78, 0
  %87 = icmp eq i64 %78, 0
  %88 = select i1 %87, i64 1, i64 %78
  %89 = icmp slt i64 %79, 0
  %90 = icmp eq i64 %79, 0
  %91 = select i1 %90, i64 1, i64 %79
  %92 = icmp slt i64 %69, 0
  %93 = xor i1 %89, %92
  %94 = sdiv i64 %69, %91
  %95 = mul i64 %94, %79
  %96 = sub i64 %69, %95
  %97 = icmp ne i64 %96, 0
  %98 = and i1 %93, %97
  %99 = select i1 %98, i64 1, i64 0
  %100 = sub i64 %94, %99
  %101 = select i1 %90, i64 0, i64 %100
  %102 = select i1 %98, i64 %79, i64 0
  %103 = add i64 %96, %102
  %104 = select i1 %90, i64 0, i64 %103
  %105 = icmp slt i64 %101, 0
  %106 = xor i1 %86, %105
  %107 = sdiv i64 %101, %88
  %108 = mul i64 %107, %78
  %109 = sub i64 %101, %108
  %110 = icmp ne i64 %109, 0
  %111 = and i1 %106, %110
  %112 = select i1 %111, i64 1, i64 0
  %113 = sub i64 %107, %112
  %114 = select i1 %87, i64 0, i64 %113
  %115 = select i1 %111, i64 %78, i64 0
  %116 = add i64 %109, %115
  %117 = select i1 %87, i64 0, i64 %116
  %118 = icmp slt i64 %114, 0
  %119 = xor i1 %83, %118
  %120 = sdiv i64 %114, %85
  %121 = mul i64 %120, %77
  %122 = sub i64 %114, %121
  %123 = icmp ne i64 %122, 0
  %124 = and i1 %119, %123
  %125 = select i1 %124, i64 1, i64 0
  %126 = sub i64 %120, %125
  %127 = select i1 %84, i64 0, i64 %126
  %128 = select i1 %124, i64 %77, i64 0
  %129 = add i64 %122, %128
  %130 = select i1 %84, i64 0, i64 %129
  %131 = icmp slt i64 %127, 0
  %132 = xor i1 %80, %131
  %133 = sdiv i64 %127, %82
  %134 = mul i64 %133, %76
  %135 = sub i64 %127, %134
  %136 = icmp ne i64 %135, 0
  %137 = and i1 %132, %136
  %138 = select i1 %137, i64 %76, i64 0
  %139 = add i64 %135, %138
  %140 = select i1 %81, i64 0, i64 %139
  %141 = load i64, ptr %19, align 8
  %142 = load { ptr, { { i64 }, { {} } } }, ptr %18, align 8
  %143 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %144 = load float, ptr %16, align 4
  %145 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %15, align 8
  %146 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %145, 0
  %147 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %145, 1, 1, 0
  %148 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %145, 1, 1, 1
  %149 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %145, 1, 1, 2
  %150 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %145, 1, 1, 3
  %151 = mul i64 %140, %147
  %152 = mul i64 %130, %148
  %153 = add i64 %151, %152
  %154 = mul i64 %117, %149
  %155 = add i64 %153, %154
  %156 = mul i64 %104, %150
  %157 = add i64 %155, %156
  br label %158

158:                                              ; preds = %235, %74
  %159 = phi i64 [ 0, %74 ], [ %236, %235 ]
  %160 = phi i64 [ 0, %74 ], [ %173, %235 ]
  %161 = phi i64 [ 0, %74 ], [ %174, %235 ]
  %162 = phi float [ 0.000000e+00, %74 ], [ %237, %235 ]
  %163 = phi float [ 0.000000e+00, %74 ], [ %238, %235 ]
  %164 = phi float [ 0.000000e+00, %74 ], [ %239, %235 ]
  %165 = fadd contract float %162, 1.000000e+00
  %166 = add i64 %160, 128
  %167 = icmp slt i64 %166, %160
  %168 = select i1 %167, i64 1, i64 0
  %169 = icmp sge i64 %160, %141
  %170 = icmp eq i64 %161, 0
  %171 = xor i1 %170, true
  %172 = or i1 %171, %169
  %173 = select i1 %172, i64 %160, i64 %166
  %174 = select i1 %172, i64 %161, i64 %168
  br i1 %172, label %175, label %176

175:                                              ; preds = %158
  br label %240

176:                                              ; preds = %158
  br label %177

177:                                              ; preds = %176
  %178 = add i64 %160, %24
  %179 = add i64 %157, %178
  %180 = getelementptr inbounds float, ptr %146, i64 %179
  %181 = sub i64 %141, %178
  %182 = call i64 @llvm.smin.i64(i64 %181, i64 1)
  %183 = call i64 @llvm.smax.i64(i64 %182, i64 0)
  %184 = icmp eq i64 %182, 1
  %185 = icmp slt i64 %178, %141
  br i1 %185, label %186, label %234

186:                                              ; preds = %177
  br i1 %184, label %187, label %197

187:                                              ; preds = %186
  %188 = load float, ptr %180, align 4
  %189 = fsub contract float %188, %163
  %190 = fdiv float 1.000000e+00, %165
  %191 = fmul contract float %189, %190
  %192 = fadd contract float %163, %191
  %193 = fmul contract float %189, %189
  %194 = fmul contract float %193, %162
  %195 = fmul contract float %194, %190
  %196 = fadd contract float %164, %195
  br label %229

197:                                              ; preds = %186
  br label %198

198:                                              ; preds = %207, %197
  %199 = phi i64 [ 0, %197 ], [ %210, %207 ]
  %200 = phi i64 [ %159, %197 ], [ %211, %207 ]
  %201 = phi float [ %162, %197 ], [ %215, %207 ]
  %202 = phi float [ %163, %197 ], [ %219, %207 ]
  %203 = phi float [ %164, %197 ], [ %223, %207 ]
  %204 = icmp slt i64 %199, %183
  br i1 %204, label %205, label %206

205:                                              ; preds = %198
  br label %207

206:                                              ; preds = %198
  br label %224

207:                                              ; preds = %205
  %208 = icmp eq i64 %199, %183
  %209 = add i64 %199, 1
  %210 = select i1 %208, i64 %199, i64 %209
  %211 = add i64 %178, %199
  %212 = add i64 %157, %211
  %213 = getelementptr inbounds float, ptr %146, i64 %212
  %214 = load float, ptr %213, align 4
  %215 = fadd contract float %201, 1.000000e+00
  %216 = fsub contract float %214, %202
  %217 = fdiv float 1.000000e+00, %215
  %218 = fmul contract float %216, %217
  %219 = fadd contract float %202, %218
  %220 = fmul contract float %216, %216
  %221 = fmul contract float %220, %201
  %222 = fmul contract float %221, %217
  %223 = fadd contract float %203, %222
  br label %198

224:                                              ; preds = %206
  %225 = phi i64 [ %200, %206 ]
  %226 = phi float [ %201, %206 ]
  %227 = phi float [ %202, %206 ]
  %228 = phi float [ %203, %206 ]
  br label %229

229:                                              ; preds = %224, %187
  %230 = phi i64 [ %225, %224 ], [ %178, %187 ]
  %231 = phi float [ %226, %224 ], [ %165, %187 ]
  %232 = phi float [ %227, %224 ], [ %192, %187 ]
  %233 = phi float [ %228, %224 ], [ %196, %187 ]
  br label %235

234:                                              ; preds = %177
  br label %235

235:                                              ; preds = %234, %229
  %236 = phi i64 [ %159, %234 ], [ %230, %229 ]
  %237 = phi float [ %162, %234 ], [ %231, %229 ]
  %238 = phi float [ %163, %234 ], [ %232, %229 ]
  %239 = phi float [ %164, %234 ], [ %233, %229 ]
  br label %158

240:                                              ; preds = %175
  %241 = phi float [ %162, %175 ]
  %242 = phi float [ %163, %175 ]
  %243 = phi float [ %164, %175 ]
  %244 = insertvalue { float, float, float } undef, float %241, 0
  %245 = insertvalue { float, float, float } %244, float %242, 1
  %246 = insertvalue { float, float, float } %245, float %243, 2
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } %246, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %247 = load i32, ptr %12, align 4
  %248 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %247, i32 16, i32 31)
  store i32 %248, ptr %11, align 4
  %249 = getelementptr inbounds i32, ptr %11, i32 1
  %250 = getelementptr inbounds i32, ptr %12, i32 1
  %251 = load i32, ptr %250, align 4
  %252 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %251, i32 16, i32 31)
  store i32 %252, ptr %249, align 4
  %253 = getelementptr inbounds i32, ptr %11, i32 2
  %254 = getelementptr inbounds i32, ptr %12, i32 2
  %255 = load i32, ptr %254, align 4
  %256 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %255, i32 16, i32 31)
  store i32 %256, ptr %253, align 4
  %257 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %258 = getelementptr { float, float, float }, ptr %12, i32 0, i32 0
  %259 = load float, ptr %258, align 4
  %260 = extractvalue { float, float, float } %257, 0
  %261 = fadd contract float %259, %260
  %262 = call float @llvm.maxnum.f32(float %261, float 1.000000e+00)
  %263 = extractvalue { float, float, float } %257, 1
  %264 = getelementptr { float, float, float }, ptr %12, i32 0, i32 1
  %265 = load float, ptr %264, align 4
  %266 = fsub contract float %263, %265
  %267 = fdiv float %260, %262
  %268 = getelementptr { float, float, float }, ptr %12, i32 0, i32 2
  %269 = extractvalue { float, float, float } %257, 2
  %270 = load float, ptr %268, align 4
  %271 = fadd contract float %270, %269
  %272 = fmul contract float %266, %266
  %273 = fmul contract float %272, %259
  %274 = fmul contract float %273, %267
  %275 = fadd contract float %271, %274
  store float %275, ptr %268, align 4
  %276 = fmul contract float %266, %267
  %277 = load float, ptr %264, align 4
  %278 = fadd contract float %277, %276
  store float %278, ptr %264, align 4
  store float %261, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %279 = load i32, ptr %12, align 4
  %280 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %279, i32 8, i32 31)
  store i32 %280, ptr %10, align 4
  %281 = getelementptr inbounds i32, ptr %10, i32 1
  %282 = load i32, ptr %250, align 4
  %283 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %282, i32 8, i32 31)
  store i32 %283, ptr %281, align 4
  %284 = getelementptr inbounds i32, ptr %10, i32 2
  %285 = load i32, ptr %254, align 4
  %286 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %285, i32 8, i32 31)
  store i32 %286, ptr %284, align 4
  %287 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %288 = load float, ptr %258, align 4
  %289 = extractvalue { float, float, float } %287, 0
  %290 = fadd contract float %288, %289
  %291 = call float @llvm.maxnum.f32(float %290, float 1.000000e+00)
  %292 = extractvalue { float, float, float } %287, 1
  %293 = load float, ptr %264, align 4
  %294 = fsub contract float %292, %293
  %295 = fdiv float %289, %291
  %296 = extractvalue { float, float, float } %287, 2
  %297 = load float, ptr %268, align 4
  %298 = fadd contract float %297, %296
  %299 = fmul contract float %294, %294
  %300 = fmul contract float %299, %288
  %301 = fmul contract float %300, %295
  %302 = fadd contract float %298, %301
  store float %302, ptr %268, align 4
  %303 = fmul contract float %294, %295
  %304 = load float, ptr %264, align 4
  %305 = fadd contract float %304, %303
  store float %305, ptr %264, align 4
  store float %290, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %306 = load i32, ptr %12, align 4
  %307 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %306, i32 4, i32 31)
  store i32 %307, ptr %9, align 4
  %308 = getelementptr inbounds i32, ptr %9, i32 1
  %309 = load i32, ptr %250, align 4
  %310 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %309, i32 4, i32 31)
  store i32 %310, ptr %308, align 4
  %311 = getelementptr inbounds i32, ptr %9, i32 2
  %312 = load i32, ptr %254, align 4
  %313 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %312, i32 4, i32 31)
  store i32 %313, ptr %311, align 4
  %314 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %315 = load float, ptr %258, align 4
  %316 = extractvalue { float, float, float } %314, 0
  %317 = fadd contract float %315, %316
  %318 = call float @llvm.maxnum.f32(float %317, float 1.000000e+00)
  %319 = extractvalue { float, float, float } %314, 1
  %320 = load float, ptr %264, align 4
  %321 = fsub contract float %319, %320
  %322 = fdiv float %316, %318
  %323 = extractvalue { float, float, float } %314, 2
  %324 = load float, ptr %268, align 4
  %325 = fadd contract float %324, %323
  %326 = fmul contract float %321, %321
  %327 = fmul contract float %326, %315
  %328 = fmul contract float %327, %322
  %329 = fadd contract float %325, %328
  store float %329, ptr %268, align 4
  %330 = fmul contract float %321, %322
  %331 = load float, ptr %264, align 4
  %332 = fadd contract float %331, %330
  store float %332, ptr %264, align 4
  store float %317, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %333 = load i32, ptr %12, align 4
  %334 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %333, i32 2, i32 31)
  store i32 %334, ptr %8, align 4
  %335 = getelementptr inbounds i32, ptr %8, i32 1
  %336 = load i32, ptr %250, align 4
  %337 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %336, i32 2, i32 31)
  store i32 %337, ptr %335, align 4
  %338 = getelementptr inbounds i32, ptr %8, i32 2
  %339 = load i32, ptr %254, align 4
  %340 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %339, i32 2, i32 31)
  store i32 %340, ptr %338, align 4
  %341 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %342 = load float, ptr %258, align 4
  %343 = extractvalue { float, float, float } %341, 0
  %344 = fadd contract float %342, %343
  %345 = call float @llvm.maxnum.f32(float %344, float 1.000000e+00)
  %346 = extractvalue { float, float, float } %341, 1
  %347 = load float, ptr %264, align 4
  %348 = fsub contract float %346, %347
  %349 = fdiv float %343, %345
  %350 = extractvalue { float, float, float } %341, 2
  %351 = load float, ptr %268, align 4
  %352 = fadd contract float %351, %350
  %353 = fmul contract float %348, %348
  %354 = fmul contract float %353, %342
  %355 = fmul contract float %354, %349
  %356 = fadd contract float %352, %355
  store float %356, ptr %268, align 4
  %357 = fmul contract float %348, %349
  %358 = load float, ptr %264, align 4
  %359 = fadd contract float %358, %357
  store float %359, ptr %264, align 4
  store float %344, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %360 = load i32, ptr %12, align 4
  %361 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %360, i32 1, i32 31)
  store i32 %361, ptr %7, align 4
  %362 = getelementptr inbounds i32, ptr %7, i32 1
  %363 = load i32, ptr %250, align 4
  %364 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %363, i32 1, i32 31)
  store i32 %364, ptr %362, align 4
  %365 = getelementptr inbounds i32, ptr %7, i32 2
  %366 = load i32, ptr %254, align 4
  %367 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %366, i32 1, i32 31)
  store i32 %367, ptr %365, align 4
  %368 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %369 = load float, ptr %258, align 4
  %370 = extractvalue { float, float, float } %368, 0
  %371 = fadd contract float %369, %370
  %372 = call float @llvm.maxnum.f32(float %371, float 1.000000e+00)
  %373 = extractvalue { float, float, float } %368, 1
  %374 = load float, ptr %264, align 4
  %375 = fsub contract float %373, %374
  %376 = fdiv float %370, %372
  %377 = extractvalue { float, float, float } %368, 2
  %378 = load float, ptr %268, align 4
  %379 = fadd contract float %378, %377
  %380 = fmul contract float %375, %375
  %381 = fmul contract float %380, %369
  %382 = fmul contract float %381, %376
  %383 = fadd contract float %379, %382
  store float %383, ptr %268, align 4
  %384 = fmul contract float %375, %376
  %385 = load float, ptr %264, align 4
  %386 = fadd contract float %385, %384
  store float %386, ptr %264, align 4
  store float %371, ptr %258, align 4
  %387 = udiv i64 %24, 32
  %388 = trunc i64 %387 to i32
  %389 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703._global_alloc_0._gpu_shared_mem, i32 %388
  %390 = trunc i64 %21 to i32
  %391 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703._global_alloc_0._gpu_shared_mem, i32 %390
  br i1 %25, label %392, label %394

392:                                              ; preds = %240
  %393 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %393, ptr addrspace(3) %389, align 4
  br label %395

394:                                              ; preds = %240
  br label %395

395:                                              ; preds = %394, %392
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %396 = icmp eq i64 %387, 0
  br i1 %396, label %397, label %541

397:                                              ; preds = %395
  br i1 %22, label %398, label %400

398:                                              ; preds = %397
  %399 = load { float, float, float }, ptr addrspace(3) %391, align 4
  store { float, float, float } %399, ptr %12, align 4
  br label %401

400:                                              ; preds = %397
  store { float, float, float } zeroinitializer, ptr %12, align 4
  br label %401

401:                                              ; preds = %400, %398
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %402 = load i32, ptr %12, align 4
  %403 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %402, i32 16, i32 31)
  store i32 %403, ptr %6, align 4
  %404 = getelementptr inbounds i32, ptr %6, i32 1
  %405 = load i32, ptr %250, align 4
  %406 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %405, i32 16, i32 31)
  store i32 %406, ptr %404, align 4
  %407 = getelementptr inbounds i32, ptr %6, i32 2
  %408 = load i32, ptr %254, align 4
  %409 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %408, i32 16, i32 31)
  store i32 %409, ptr %407, align 4
  %410 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %411 = load float, ptr %258, align 4
  %412 = extractvalue { float, float, float } %410, 0
  %413 = fadd contract float %411, %412
  %414 = call float @llvm.maxnum.f32(float %413, float 1.000000e+00)
  %415 = extractvalue { float, float, float } %410, 1
  %416 = load float, ptr %264, align 4
  %417 = fsub contract float %415, %416
  %418 = fdiv float %412, %414
  %419 = extractvalue { float, float, float } %410, 2
  %420 = load float, ptr %268, align 4
  %421 = fadd contract float %420, %419
  %422 = fmul contract float %417, %417
  %423 = fmul contract float %422, %411
  %424 = fmul contract float %423, %418
  %425 = fadd contract float %421, %424
  store float %425, ptr %268, align 4
  %426 = fmul contract float %417, %418
  %427 = load float, ptr %264, align 4
  %428 = fadd contract float %427, %426
  store float %428, ptr %264, align 4
  store float %413, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %429 = load i32, ptr %12, align 4
  %430 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %429, i32 8, i32 31)
  store i32 %430, ptr %5, align 4
  %431 = getelementptr inbounds i32, ptr %5, i32 1
  %432 = load i32, ptr %250, align 4
  %433 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %432, i32 8, i32 31)
  store i32 %433, ptr %431, align 4
  %434 = getelementptr inbounds i32, ptr %5, i32 2
  %435 = load i32, ptr %254, align 4
  %436 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %435, i32 8, i32 31)
  store i32 %436, ptr %434, align 4
  %437 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %438 = load float, ptr %258, align 4
  %439 = extractvalue { float, float, float } %437, 0
  %440 = fadd contract float %438, %439
  %441 = call float @llvm.maxnum.f32(float %440, float 1.000000e+00)
  %442 = extractvalue { float, float, float } %437, 1
  %443 = load float, ptr %264, align 4
  %444 = fsub contract float %442, %443
  %445 = fdiv float %439, %441
  %446 = extractvalue { float, float, float } %437, 2
  %447 = load float, ptr %268, align 4
  %448 = fadd contract float %447, %446
  %449 = fmul contract float %444, %444
  %450 = fmul contract float %449, %438
  %451 = fmul contract float %450, %445
  %452 = fadd contract float %448, %451
  store float %452, ptr %268, align 4
  %453 = fmul contract float %444, %445
  %454 = load float, ptr %264, align 4
  %455 = fadd contract float %454, %453
  store float %455, ptr %264, align 4
  store float %440, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %456 = load i32, ptr %12, align 4
  %457 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %456, i32 4, i32 31)
  store i32 %457, ptr %4, align 4
  %458 = getelementptr inbounds i32, ptr %4, i32 1
  %459 = load i32, ptr %250, align 4
  %460 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %459, i32 4, i32 31)
  store i32 %460, ptr %458, align 4
  %461 = getelementptr inbounds i32, ptr %4, i32 2
  %462 = load i32, ptr %254, align 4
  %463 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %462, i32 4, i32 31)
  store i32 %463, ptr %461, align 4
  %464 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %465 = load float, ptr %258, align 4
  %466 = extractvalue { float, float, float } %464, 0
  %467 = fadd contract float %465, %466
  %468 = call float @llvm.maxnum.f32(float %467, float 1.000000e+00)
  %469 = extractvalue { float, float, float } %464, 1
  %470 = load float, ptr %264, align 4
  %471 = fsub contract float %469, %470
  %472 = fdiv float %466, %468
  %473 = extractvalue { float, float, float } %464, 2
  %474 = load float, ptr %268, align 4
  %475 = fadd contract float %474, %473
  %476 = fmul contract float %471, %471
  %477 = fmul contract float %476, %465
  %478 = fmul contract float %477, %472
  %479 = fadd contract float %475, %478
  store float %479, ptr %268, align 4
  %480 = fmul contract float %471, %472
  %481 = load float, ptr %264, align 4
  %482 = fadd contract float %481, %480
  store float %482, ptr %264, align 4
  store float %467, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %483 = load i32, ptr %12, align 4
  %484 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %483, i32 2, i32 31)
  store i32 %484, ptr %3, align 4
  %485 = getelementptr inbounds i32, ptr %3, i32 1
  %486 = load i32, ptr %250, align 4
  %487 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %486, i32 2, i32 31)
  store i32 %487, ptr %485, align 4
  %488 = getelementptr inbounds i32, ptr %3, i32 2
  %489 = load i32, ptr %254, align 4
  %490 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %489, i32 2, i32 31)
  store i32 %490, ptr %488, align 4
  %491 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %492 = load float, ptr %258, align 4
  %493 = extractvalue { float, float, float } %491, 0
  %494 = fadd contract float %492, %493
  %495 = call float @llvm.maxnum.f32(float %494, float 1.000000e+00)
  %496 = extractvalue { float, float, float } %491, 1
  %497 = load float, ptr %264, align 4
  %498 = fsub contract float %496, %497
  %499 = fdiv float %493, %495
  %500 = extractvalue { float, float, float } %491, 2
  %501 = load float, ptr %268, align 4
  %502 = fadd contract float %501, %500
  %503 = fmul contract float %498, %498
  %504 = fmul contract float %503, %492
  %505 = fmul contract float %504, %499
  %506 = fadd contract float %502, %505
  store float %506, ptr %268, align 4
  %507 = fmul contract float %498, %499
  %508 = load float, ptr %264, align 4
  %509 = fadd contract float %508, %507
  store float %509, ptr %264, align 4
  store float %494, ptr %258, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %510 = load i32, ptr %12, align 4
  %511 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %510, i32 1, i32 31)
  store i32 %511, ptr %2, align 4
  %512 = getelementptr inbounds i32, ptr %2, i32 1
  %513 = load i32, ptr %250, align 4
  %514 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %513, i32 1, i32 31)
  store i32 %514, ptr %512, align 4
  %515 = getelementptr inbounds i32, ptr %2, i32 2
  %516 = load i32, ptr %254, align 4
  %517 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %516, i32 1, i32 31)
  store i32 %517, ptr %515, align 4
  %518 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %519 = load float, ptr %258, align 4
  %520 = extractvalue { float, float, float } %518, 0
  %521 = fadd contract float %519, %520
  %522 = call float @llvm.maxnum.f32(float %521, float 1.000000e+00)
  %523 = extractvalue { float, float, float } %518, 1
  %524 = load float, ptr %264, align 4
  %525 = fsub contract float %523, %524
  %526 = fdiv float %520, %522
  %527 = extractvalue { float, float, float } %518, 2
  %528 = load float, ptr %268, align 4
  %529 = fadd contract float %528, %527
  %530 = fmul contract float %525, %525
  %531 = fmul contract float %530, %519
  %532 = fmul contract float %531, %526
  %533 = fadd contract float %529, %532
  store float %533, ptr %268, align 4
  %534 = fmul contract float %525, %526
  %535 = load float, ptr %264, align 4
  %536 = fadd contract float %535, %534
  store float %536, ptr %264, align 4
  store float %521, ptr %258, align 4
  br i1 %25, label %537, label %539

537:                                              ; preds = %401
  %538 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %538, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703._global_alloc_0._gpu_shared_mem, align 4
  br label %540

539:                                              ; preds = %401
  br label %540

540:                                              ; preds = %539, %537
  br label %542

541:                                              ; preds = %395
  br label %542

542:                                              ; preds = %541, %540
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %543 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %543, ptr %12, align 4
  %544 = load float, ptr %264, align 4
  store float %544, ptr %264, align 4
  %545 = load float, ptr %268, align 4
  store float %545, ptr %268, align 4
  %546 = load float, ptr %258, align 4
  store float %546, ptr %258, align 4
  %547 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %548 = extractvalue { float, float, float } %547, 0
  %549 = extractvalue { float, float, float } %547, 1
  %550 = extractvalue { float, float, float } %547, 2
  %551 = fdiv float %550, %548
  %552 = fadd contract float %551, %144
  %553 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %552)
  %554 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %14, align 8
  %555 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %554, 0
  %556 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %554, 1, 1, 0
  %557 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %554, 1, 1, 1
  %558 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %554, 1, 1, 2
  %559 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %554, 1, 1, 3
  %560 = extractvalue { ptr, { { i64 }, { {} } } } %142, 0
  %561 = extractvalue { ptr, { { i64 }, { {} } } } %143, 0
  %562 = mul i64 %140, %556
  %563 = mul i64 %130, %557
  %564 = add i64 %562, %563
  %565 = mul i64 %117, %558
  %566 = add i64 %564, %565
  %567 = mul i64 %104, %559
  %568 = add i64 %566, %567
  br label %569

569:                                              ; preds = %636, %542
  %570 = phi i64 [ 0, %542 ], [ %637, %636 ]
  %571 = phi i64 [ 0, %542 ], [ %580, %636 ]
  %572 = phi i64 [ 0, %542 ], [ %581, %636 ]
  %573 = add i64 %571, 128
  %574 = icmp slt i64 %573, %571
  %575 = select i1 %574, i64 1, i64 0
  %576 = icmp sge i64 %571, %141
  %577 = icmp eq i64 %572, 0
  %578 = xor i1 %577, true
  %579 = or i1 %578, %576
  %580 = select i1 %579, i64 %571, i64 %573
  %581 = select i1 %579, i64 %572, i64 %575
  br i1 %579, label %582, label %583

582:                                              ; preds = %569
  br label %638

583:                                              ; preds = %569
  br label %584

584:                                              ; preds = %583
  %585 = add i64 %571, %24
  %586 = getelementptr inbounds float, ptr %561, i64 %585
  %587 = getelementptr inbounds float, ptr %560, i64 %585
  %588 = add i64 %568, %585
  %589 = getelementptr inbounds float, ptr %555, i64 %588
  %590 = add i64 %157, %585
  %591 = getelementptr inbounds float, ptr %146, i64 %590
  %592 = sub i64 %141, %585
  %593 = call i64 @llvm.smin.i64(i64 %592, i64 1)
  %594 = call i64 @llvm.smax.i64(i64 %593, i64 0)
  %595 = icmp eq i64 %593, 1
  %596 = icmp slt i64 %585, %141
  br i1 %596, label %597, label %635

597:                                              ; preds = %584
  br i1 %595, label %598, label %606

598:                                              ; preds = %597
  %599 = load float, ptr %591, align 4
  %600 = load float, ptr %587, align 4, !invariant.load !1
  %601 = load float, ptr %586, align 4, !invariant.load !1
  %602 = fsub contract float %599, %549
  %603 = fmul contract float %602, %553
  %604 = fmul contract float %603, %600
  %605 = fadd contract float %604, %601
  store float %605, ptr %589, align 4
  br label %633

606:                                              ; preds = %597
  br label %607

607:                                              ; preds = %613, %606
  %608 = phi i64 [ 0, %606 ], [ %616, %613 ]
  %609 = phi i64 [ %570, %606 ], [ %617, %613 ]
  %610 = icmp slt i64 %608, %594
  br i1 %610, label %611, label %612

611:                                              ; preds = %607
  br label %613

612:                                              ; preds = %607
  br label %631

613:                                              ; preds = %611
  %614 = icmp eq i64 %608, %594
  %615 = add i64 %608, 1
  %616 = select i1 %614, i64 %608, i64 %615
  %617 = add i64 %585, %608
  %618 = add i64 %157, %617
  %619 = getelementptr inbounds float, ptr %146, i64 %618
  %620 = load float, ptr %619, align 4
  %621 = getelementptr inbounds float, ptr %560, i64 %617
  %622 = load float, ptr %621, align 4, !invariant.load !1
  %623 = getelementptr inbounds float, ptr %561, i64 %617
  %624 = load float, ptr %623, align 4, !invariant.load !1
  %625 = fsub contract float %620, %549
  %626 = fmul contract float %625, %553
  %627 = fmul contract float %626, %622
  %628 = fadd contract float %627, %624
  %629 = add i64 %568, %617
  %630 = getelementptr inbounds float, ptr %555, i64 %629
  store float %628, ptr %630, align 4
  br label %607

631:                                              ; preds = %612
  %632 = phi i64 [ %609, %612 ]
  br label %633

633:                                              ; preds = %631, %598
  %634 = phi i64 [ %632, %631 ], [ %585, %598 ]
  br label %636

635:                                              ; preds = %584
  br label %636

636:                                              ; preds = %635, %633
  %637 = phi i64 [ %570, %635 ], [ %634, %633 ]
  br label %569

638:                                              ; preds = %582
  br label %45

639:                                              ; preds = %72
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

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #5

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none)
declare float @llvm.nvvm.rsqrt.approx.ftz.f(float) #6

attributes #0 = { convergent norecurse "nvvm.maxntid"="128" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #5 = { convergent nocallback nounwind }
attributes #6 = { nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
