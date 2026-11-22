; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_warp_t1_r5_ax4_w1_bs128_f54b0d3e(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
  %2 = alloca { float, float, float }, i64 1, align 4
  %3 = alloca { float, float, float }, i64 1, align 4
  %4 = alloca { float, float, float }, i64 1, align 4
  %5 = alloca { float, float, float }, i64 1, align 4
  %6 = alloca { float, float, float }, i64 1, align 4
  %7 = alloca { float, float, float }, i64 1, align 4
  %8 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %9 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %8, i32 0, i32 5
  %10 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %8, i32 0, i32 4
  %11 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %8, i32 0, i32 3
  %12 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %8, i32 0, i32 2
  %13 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %8, i32 0, i32 1
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %8, i32 0, i32 0
  %15 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 2
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %17 = sext i32 %16 to i64
  %18 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %19 = zext i32 %18 to i64
  %20 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %21 = load { i64, i64, i64, i64, i64 }, ptr %20, align 8
  %22 = extractvalue { i64, i64, i64, i64, i64 } %21, 0
  %23 = extractvalue { i64, i64, i64, i64, i64 } %21, 1
  %24 = mul i64 %22, %23
  %25 = extractvalue { i64, i64, i64, i64, i64 } %21, 2
  %26 = mul i64 %24, %25
  %27 = extractvalue { i64, i64, i64, i64, i64 } %21, 3
  %28 = mul i64 %26, %27
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %30 = zext i32 %29 to i64
  %31 = mul i64 %30, 4
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %33 = sext i32 %32 to i64
  %34 = mul i64 %33, 4
  %35 = icmp eq i64 %34, 0
  %36 = select i1 %35, i64 0, i64 %31
  %37 = select i1 %35, i64 0, i64 %28
  %38 = select i1 %35, i64 1, i64 %34
  %39 = icmp slt i64 %38, 0
  %40 = icmp sgt i64 %38, 0
  br label %41

41:                                               ; preds = %489, %1
  %42 = phi i64 [ %36, %1 ], [ %66, %489 ]
  %43 = phi i64 [ 0, %1 ], [ %67, %489 ]
  %44 = icmp sge i64 %37, %42
  %45 = icmp sge i64 %42, %37
  %46 = add i64 %42, %38
  %47 = icmp slt i64 %46, %42
  %48 = xor i1 %47, %39
  %49 = select i1 %48, i64 1, i64 0
  %50 = icmp eq i64 %43, 0
  %51 = xor i1 %50, true
  %52 = or i1 %51, %44
  %53 = or i1 %51, %45
  br label %54

54:                                               ; preds = %41
  br i1 %40, label %55, label %60

55:                                               ; preds = %54
  br i1 %53, label %56, label %57

56:                                               ; preds = %55
  br label %63

57:                                               ; preds = %55
  br label %58

58:                                               ; preds = %57
  br label %62

59:                                               ; preds = %60
  br label %62

60:                                               ; preds = %54
  br i1 %52, label %61, label %59

61:                                               ; preds = %60
  br label %63

62:                                               ; preds = %59, %58
  br label %63

63:                                               ; preds = %62, %61, %56
  %64 = phi i1 [ true, %56 ], [ true, %61 ], [ false, %62 ]
  %65 = phi i64 [ undef, %56 ], [ undef, %61 ], [ %42, %62 ]
  %66 = phi i64 [ %42, %56 ], [ %42, %61 ], [ %46, %62 ]
  %67 = phi i64 [ %43, %56 ], [ %43, %61 ], [ %49, %62 ]
  br i1 %64, label %68, label %69

68:                                               ; preds = %63
  br label %490

69:                                               ; preds = %63
  br label %70

70:                                               ; preds = %69
  %71 = udiv i64 %19, 32
  %72 = add i64 %65, %71
  %73 = trunc i64 %72 to i32
  %74 = zext i32 %73 to i64
  %75 = icmp slt i64 %72, %28
  br i1 %75, label %76, label %488

76:                                               ; preds = %70
  %77 = load [3 x { i32, i32, i8, i8, i1, i8 }], ptr %15, align 4
  %78 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 2, 0
  %79 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 2, 1
  %80 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 2, 2
  %81 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 2, 3
  %82 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 2, 4
  %83 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 2, 5
  %84 = zext i8 %81 to i32
  %85 = zext i8 %80 to i32
  %86 = zext i32 %79 to i64
  %87 = mul i64 %86, %74
  %88 = zext i8 %83 to i32
  %89 = lshr i32 %73, %88
  %90 = lshr i64 %87, 32
  %91 = trunc i64 %90 to i32
  %92 = sub i32 %73, %91
  %93 = lshr i32 %92, %85
  %94 = add i32 %91, %93
  %95 = lshr i32 %94, %84
  %96 = select i1 %82, i32 %89, i32 %95
  %97 = mul i32 %96, %78
  %98 = sub i32 %73, %97
  %99 = zext i32 %98 to i64
  %100 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 1, 0
  %101 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 1, 1
  %102 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 1, 2
  %103 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 1, 3
  %104 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 1, 4
  %105 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 1, 5
  %106 = zext i8 %103 to i32
  %107 = zext i8 %102 to i32
  %108 = zext i32 %96 to i64
  %109 = zext i32 %101 to i64
  %110 = mul i64 %109, %108
  %111 = zext i8 %105 to i32
  %112 = lshr i32 %96, %111
  %113 = lshr i64 %110, 32
  %114 = trunc i64 %113 to i32
  %115 = sub i32 %96, %114
  %116 = lshr i32 %115, %107
  %117 = add i32 %114, %116
  %118 = lshr i32 %117, %106
  %119 = select i1 %104, i32 %112, i32 %118
  %120 = mul i32 %119, %100
  %121 = sub i32 %96, %120
  %122 = zext i32 %121 to i64
  %123 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 0, 0
  %124 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 0, 1
  %125 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 0, 2
  %126 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 0, 3
  %127 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 0, 4
  %128 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %77, 0, 5
  %129 = zext i8 %126 to i32
  %130 = zext i8 %125 to i32
  %131 = zext i32 %119 to i64
  %132 = zext i32 %124 to i64
  %133 = mul i64 %132, %131
  %134 = zext i8 %128 to i32
  %135 = lshr i32 %119, %134
  %136 = lshr i64 %133, 32
  %137 = trunc i64 %136 to i32
  %138 = sub i32 %119, %137
  %139 = lshr i32 %138, %130
  %140 = add i32 %137, %139
  %141 = lshr i32 %140, %129
  %142 = select i1 %127, i32 %135, i32 %141
  %143 = mul i32 %142, %123
  %144 = sub i32 %119, %143
  %145 = zext i32 %144 to i64
  %146 = zext i32 %142 to i64
  %147 = load i64, ptr %14, align 8
  %148 = load { ptr, { { i64 }, { {} } } }, ptr %13, align 8
  %149 = load { ptr, { { i64 }, { {} } } }, ptr %12, align 8
  %150 = load float, ptr %11, align 4
  %151 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %10, align 8
  %152 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %151, 0
  %153 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %151, 1, 1, 0
  %154 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %151, 1, 1, 1
  %155 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %151, 1, 1, 2
  %156 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %151, 1, 1, 3
  %157 = mul i64 %146, %153
  %158 = mul i64 %145, %154
  %159 = add i64 %157, %158
  %160 = mul i64 %122, %155
  %161 = add i64 %159, %160
  %162 = mul i64 %99, %156
  %163 = add i64 %161, %162
  br label %164

164:                                              ; preds = %241, %76
  %165 = phi i64 [ 0, %76 ], [ %242, %241 ]
  %166 = phi i64 [ 0, %76 ], [ %179, %241 ]
  %167 = phi i64 [ 0, %76 ], [ %180, %241 ]
  %168 = phi float [ 0.000000e+00, %76 ], [ %243, %241 ]
  %169 = phi float [ 0.000000e+00, %76 ], [ %244, %241 ]
  %170 = phi float [ 0.000000e+00, %76 ], [ %245, %241 ]
  %171 = fadd contract float %168, 1.000000e+00
  %172 = add i64 %166, 32
  %173 = icmp slt i64 %172, %166
  %174 = select i1 %173, i64 1, i64 0
  %175 = icmp sge i64 %166, %147
  %176 = icmp eq i64 %167, 0
  %177 = xor i1 %176, true
  %178 = or i1 %177, %175
  %179 = select i1 %178, i64 %166, i64 %172
  %180 = select i1 %178, i64 %167, i64 %174
  br i1 %178, label %181, label %182

181:                                              ; preds = %164
  br label %246

182:                                              ; preds = %164
  br label %183

183:                                              ; preds = %182
  %184 = add i64 %166, %17
  %185 = add i64 %163, %184
  %186 = getelementptr inbounds float, ptr %152, i64 %185
  %187 = sub i64 %147, %184
  %188 = call i64 @llvm.smin.i64(i64 %187, i64 1)
  %189 = call i64 @llvm.smax.i64(i64 %188, i64 0)
  %190 = icmp eq i64 %188, 1
  %191 = icmp slt i64 %184, %147
  br i1 %191, label %192, label %240

192:                                              ; preds = %183
  br i1 %190, label %193, label %203

193:                                              ; preds = %192
  %194 = load float, ptr %186, align 4
  %195 = fsub contract float %194, %169
  %196 = fdiv float 1.000000e+00, %171
  %197 = fmul contract float %195, %196
  %198 = fadd contract float %169, %197
  %199 = fmul contract float %195, %195
  %200 = fmul contract float %199, %168
  %201 = fmul contract float %200, %196
  %202 = fadd contract float %170, %201
  br label %235

203:                                              ; preds = %192
  br label %204

204:                                              ; preds = %213, %203
  %205 = phi i64 [ 0, %203 ], [ %216, %213 ]
  %206 = phi i64 [ %165, %203 ], [ %217, %213 ]
  %207 = phi float [ %168, %203 ], [ %221, %213 ]
  %208 = phi float [ %169, %203 ], [ %225, %213 ]
  %209 = phi float [ %170, %203 ], [ %229, %213 ]
  %210 = icmp slt i64 %205, %189
  br i1 %210, label %211, label %212

211:                                              ; preds = %204
  br label %213

212:                                              ; preds = %204
  br label %230

213:                                              ; preds = %211
  %214 = icmp eq i64 %205, %189
  %215 = add i64 %205, 1
  %216 = select i1 %214, i64 %205, i64 %215
  %217 = add i64 %184, %205
  %218 = add i64 %163, %217
  %219 = getelementptr inbounds float, ptr %152, i64 %218
  %220 = load float, ptr %219, align 4
  %221 = fadd contract float %207, 1.000000e+00
  %222 = fsub contract float %220, %208
  %223 = fdiv float 1.000000e+00, %221
  %224 = fmul contract float %222, %223
  %225 = fadd contract float %208, %224
  %226 = fmul contract float %222, %222
  %227 = fmul contract float %226, %207
  %228 = fmul contract float %227, %223
  %229 = fadd contract float %209, %228
  br label %204

230:                                              ; preds = %212
  %231 = phi i64 [ %206, %212 ]
  %232 = phi float [ %207, %212 ]
  %233 = phi float [ %208, %212 ]
  %234 = phi float [ %209, %212 ]
  br label %235

235:                                              ; preds = %230, %193
  %236 = phi i64 [ %231, %230 ], [ %184, %193 ]
  %237 = phi float [ %232, %230 ], [ %171, %193 ]
  %238 = phi float [ %233, %230 ], [ %198, %193 ]
  %239 = phi float [ %234, %230 ], [ %202, %193 ]
  br label %241

240:                                              ; preds = %183
  br label %241

241:                                              ; preds = %240, %235
  %242 = phi i64 [ %165, %240 ], [ %236, %235 ]
  %243 = phi float [ %168, %240 ], [ %237, %235 ]
  %244 = phi float [ %169, %240 ], [ %238, %235 ]
  %245 = phi float [ %170, %240 ], [ %239, %235 ]
  br label %164

246:                                              ; preds = %181
  %247 = phi float [ %168, %181 ]
  %248 = phi float [ %169, %181 ]
  %249 = phi float [ %170, %181 ]
  %250 = insertvalue { float, float, float } undef, float %247, 0
  %251 = insertvalue { float, float, float } %250, float %248, 1
  %252 = insertvalue { float, float, float } %251, float %249, 2
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } %252, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %253 = load i32, ptr %7, align 4
  %254 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %253, i32 16, i32 31)
  store i32 %254, ptr %6, align 4
  %255 = getelementptr inbounds i32, ptr %6, i32 1
  %256 = getelementptr inbounds i32, ptr %7, i32 1
  %257 = load i32, ptr %256, align 4
  %258 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %257, i32 16, i32 31)
  store i32 %258, ptr %255, align 4
  %259 = getelementptr inbounds i32, ptr %6, i32 2
  %260 = getelementptr inbounds i32, ptr %7, i32 2
  %261 = load i32, ptr %260, align 4
  %262 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %261, i32 16, i32 31)
  store i32 %262, ptr %259, align 4
  %263 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %264 = getelementptr { float, float, float }, ptr %7, i32 0, i32 0
  %265 = load float, ptr %264, align 4
  %266 = extractvalue { float, float, float } %263, 0
  %267 = fadd contract float %265, %266
  %268 = call float @llvm.maxnum.f32(float %267, float 1.000000e+00)
  %269 = extractvalue { float, float, float } %263, 1
  %270 = getelementptr { float, float, float }, ptr %7, i32 0, i32 1
  %271 = load float, ptr %270, align 4
  %272 = fsub contract float %269, %271
  %273 = fdiv float %266, %268
  %274 = getelementptr { float, float, float }, ptr %7, i32 0, i32 2
  %275 = extractvalue { float, float, float } %263, 2
  %276 = load float, ptr %274, align 4
  %277 = fadd contract float %276, %275
  %278 = fmul contract float %272, %272
  %279 = fmul contract float %278, %265
  %280 = fmul contract float %279, %273
  %281 = fadd contract float %277, %280
  store float %281, ptr %274, align 4
  %282 = fmul contract float %272, %273
  %283 = load float, ptr %270, align 4
  %284 = fadd contract float %283, %282
  store float %284, ptr %270, align 4
  store float %267, ptr %264, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %285 = load i32, ptr %7, align 4
  %286 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %285, i32 8, i32 31)
  store i32 %286, ptr %5, align 4
  %287 = getelementptr inbounds i32, ptr %5, i32 1
  %288 = load i32, ptr %256, align 4
  %289 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %288, i32 8, i32 31)
  store i32 %289, ptr %287, align 4
  %290 = getelementptr inbounds i32, ptr %5, i32 2
  %291 = load i32, ptr %260, align 4
  %292 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %291, i32 8, i32 31)
  store i32 %292, ptr %290, align 4
  %293 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %294 = load float, ptr %264, align 4
  %295 = extractvalue { float, float, float } %293, 0
  %296 = fadd contract float %294, %295
  %297 = call float @llvm.maxnum.f32(float %296, float 1.000000e+00)
  %298 = extractvalue { float, float, float } %293, 1
  %299 = load float, ptr %270, align 4
  %300 = fsub contract float %298, %299
  %301 = fdiv float %295, %297
  %302 = extractvalue { float, float, float } %293, 2
  %303 = load float, ptr %274, align 4
  %304 = fadd contract float %303, %302
  %305 = fmul contract float %300, %300
  %306 = fmul contract float %305, %294
  %307 = fmul contract float %306, %301
  %308 = fadd contract float %304, %307
  store float %308, ptr %274, align 4
  %309 = fmul contract float %300, %301
  %310 = load float, ptr %270, align 4
  %311 = fadd contract float %310, %309
  store float %311, ptr %270, align 4
  store float %296, ptr %264, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %312 = load i32, ptr %7, align 4
  %313 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %312, i32 4, i32 31)
  store i32 %313, ptr %4, align 4
  %314 = getelementptr inbounds i32, ptr %4, i32 1
  %315 = load i32, ptr %256, align 4
  %316 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %315, i32 4, i32 31)
  store i32 %316, ptr %314, align 4
  %317 = getelementptr inbounds i32, ptr %4, i32 2
  %318 = load i32, ptr %260, align 4
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 4, i32 31)
  store i32 %319, ptr %317, align 4
  %320 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %321 = load float, ptr %264, align 4
  %322 = extractvalue { float, float, float } %320, 0
  %323 = fadd contract float %321, %322
  %324 = call float @llvm.maxnum.f32(float %323, float 1.000000e+00)
  %325 = extractvalue { float, float, float } %320, 1
  %326 = load float, ptr %270, align 4
  %327 = fsub contract float %325, %326
  %328 = fdiv float %322, %324
  %329 = extractvalue { float, float, float } %320, 2
  %330 = load float, ptr %274, align 4
  %331 = fadd contract float %330, %329
  %332 = fmul contract float %327, %327
  %333 = fmul contract float %332, %321
  %334 = fmul contract float %333, %328
  %335 = fadd contract float %331, %334
  store float %335, ptr %274, align 4
  %336 = fmul contract float %327, %328
  %337 = load float, ptr %270, align 4
  %338 = fadd contract float %337, %336
  store float %338, ptr %270, align 4
  store float %323, ptr %264, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %339 = load i32, ptr %7, align 4
  %340 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %339, i32 2, i32 31)
  store i32 %340, ptr %3, align 4
  %341 = getelementptr inbounds i32, ptr %3, i32 1
  %342 = load i32, ptr %256, align 4
  %343 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %342, i32 2, i32 31)
  store i32 %343, ptr %341, align 4
  %344 = getelementptr inbounds i32, ptr %3, i32 2
  %345 = load i32, ptr %260, align 4
  %346 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %345, i32 2, i32 31)
  store i32 %346, ptr %344, align 4
  %347 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %348 = load float, ptr %264, align 4
  %349 = extractvalue { float, float, float } %347, 0
  %350 = fadd contract float %348, %349
  %351 = call float @llvm.maxnum.f32(float %350, float 1.000000e+00)
  %352 = extractvalue { float, float, float } %347, 1
  %353 = load float, ptr %270, align 4
  %354 = fsub contract float %352, %353
  %355 = fdiv float %349, %351
  %356 = extractvalue { float, float, float } %347, 2
  %357 = load float, ptr %274, align 4
  %358 = fadd contract float %357, %356
  %359 = fmul contract float %354, %354
  %360 = fmul contract float %359, %348
  %361 = fmul contract float %360, %355
  %362 = fadd contract float %358, %361
  store float %362, ptr %274, align 4
  %363 = fmul contract float %354, %355
  %364 = load float, ptr %270, align 4
  %365 = fadd contract float %364, %363
  store float %365, ptr %270, align 4
  store float %350, ptr %264, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %366 = load i32, ptr %7, align 4
  %367 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %366, i32 1, i32 31)
  store i32 %367, ptr %2, align 4
  %368 = getelementptr inbounds i32, ptr %2, i32 1
  %369 = load i32, ptr %256, align 4
  %370 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %369, i32 1, i32 31)
  store i32 %370, ptr %368, align 4
  %371 = getelementptr inbounds i32, ptr %2, i32 2
  %372 = load i32, ptr %260, align 4
  %373 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %372, i32 1, i32 31)
  store i32 %373, ptr %371, align 4
  %374 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %375 = load float, ptr %264, align 4
  %376 = extractvalue { float, float, float } %374, 0
  %377 = fadd contract float %375, %376
  %378 = call float @llvm.maxnum.f32(float %377, float 1.000000e+00)
  %379 = extractvalue { float, float, float } %374, 1
  %380 = load float, ptr %270, align 4
  %381 = fsub contract float %379, %380
  %382 = fdiv float %376, %378
  %383 = extractvalue { float, float, float } %374, 2
  %384 = load float, ptr %274, align 4
  %385 = fadd contract float %384, %383
  %386 = fmul contract float %381, %381
  %387 = fmul contract float %386, %375
  %388 = fmul contract float %387, %382
  %389 = fadd contract float %385, %388
  store float %389, ptr %274, align 4
  %390 = fmul contract float %381, %382
  %391 = load float, ptr %270, align 4
  %392 = fadd contract float %391, %390
  store float %392, ptr %270, align 4
  store float %377, ptr %264, align 4
  %393 = load float, ptr %270, align 4
  store float %393, ptr %270, align 4
  %394 = load float, ptr %274, align 4
  store float %394, ptr %274, align 4
  %395 = load float, ptr %264, align 4
  store float %395, ptr %264, align 4
  %396 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %397 = extractvalue { float, float, float } %396, 0
  %398 = extractvalue { float, float, float } %396, 1
  %399 = extractvalue { float, float, float } %396, 2
  %400 = fdiv float %399, %397
  %401 = fadd contract float %400, %150
  %402 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %401)
  %403 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %9, align 8
  %404 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %403, 0
  %405 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %403, 1, 1, 0
  %406 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %403, 1, 1, 1
  %407 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %403, 1, 1, 2
  %408 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %403, 1, 1, 3
  %409 = extractvalue { ptr, { { i64 }, { {} } } } %148, 0
  %410 = extractvalue { ptr, { { i64 }, { {} } } } %149, 0
  %411 = mul i64 %146, %405
  %412 = mul i64 %145, %406
  %413 = add i64 %411, %412
  %414 = mul i64 %122, %407
  %415 = add i64 %413, %414
  %416 = mul i64 %99, %408
  %417 = add i64 %415, %416
  br label %418

418:                                              ; preds = %485, %246
  %419 = phi i64 [ 0, %246 ], [ %486, %485 ]
  %420 = phi i64 [ 0, %246 ], [ %429, %485 ]
  %421 = phi i64 [ 0, %246 ], [ %430, %485 ]
  %422 = add i64 %420, 32
  %423 = icmp slt i64 %422, %420
  %424 = select i1 %423, i64 1, i64 0
  %425 = icmp sge i64 %420, %147
  %426 = icmp eq i64 %421, 0
  %427 = xor i1 %426, true
  %428 = or i1 %427, %425
  %429 = select i1 %428, i64 %420, i64 %422
  %430 = select i1 %428, i64 %421, i64 %424
  br i1 %428, label %431, label %432

431:                                              ; preds = %418
  br label %487

432:                                              ; preds = %418
  br label %433

433:                                              ; preds = %432
  %434 = add i64 %420, %17
  %435 = getelementptr inbounds float, ptr %410, i64 %434
  %436 = getelementptr inbounds float, ptr %409, i64 %434
  %437 = add i64 %417, %434
  %438 = getelementptr inbounds float, ptr %404, i64 %437
  %439 = add i64 %163, %434
  %440 = getelementptr inbounds float, ptr %152, i64 %439
  %441 = sub i64 %147, %434
  %442 = call i64 @llvm.smin.i64(i64 %441, i64 1)
  %443 = call i64 @llvm.smax.i64(i64 %442, i64 0)
  %444 = icmp eq i64 %442, 1
  %445 = icmp slt i64 %434, %147
  br i1 %445, label %446, label %484

446:                                              ; preds = %433
  br i1 %444, label %447, label %455

447:                                              ; preds = %446
  %448 = load float, ptr %440, align 4
  %449 = load float, ptr %436, align 4, !invariant.load !1
  %450 = load float, ptr %435, align 4, !invariant.load !1
  %451 = fsub contract float %448, %398
  %452 = fmul contract float %451, %402
  %453 = fmul contract float %452, %449
  %454 = fadd contract float %453, %450
  store float %454, ptr %438, align 4
  br label %482

455:                                              ; preds = %446
  br label %456

456:                                              ; preds = %462, %455
  %457 = phi i64 [ 0, %455 ], [ %465, %462 ]
  %458 = phi i64 [ %419, %455 ], [ %466, %462 ]
  %459 = icmp slt i64 %457, %443
  br i1 %459, label %460, label %461

460:                                              ; preds = %456
  br label %462

461:                                              ; preds = %456
  br label %480

462:                                              ; preds = %460
  %463 = icmp eq i64 %457, %443
  %464 = add i64 %457, 1
  %465 = select i1 %463, i64 %457, i64 %464
  %466 = add i64 %434, %457
  %467 = add i64 %163, %466
  %468 = getelementptr inbounds float, ptr %152, i64 %467
  %469 = load float, ptr %468, align 4
  %470 = getelementptr inbounds float, ptr %409, i64 %466
  %471 = load float, ptr %470, align 4, !invariant.load !1
  %472 = getelementptr inbounds float, ptr %410, i64 %466
  %473 = load float, ptr %472, align 4, !invariant.load !1
  %474 = fsub contract float %469, %398
  %475 = fmul contract float %474, %402
  %476 = fmul contract float %475, %471
  %477 = fadd contract float %476, %473
  %478 = add i64 %417, %466
  %479 = getelementptr inbounds float, ptr %404, i64 %478
  store float %477, ptr %479, align 4
  br label %456

480:                                              ; preds = %461
  %481 = phi i64 [ %458, %461 ]
  br label %482

482:                                              ; preds = %480, %447
  %483 = phi i64 [ %481, %480 ], [ %434, %447 ]
  br label %485

484:                                              ; preds = %433
  br label %485

485:                                              ; preds = %484, %482
  %486 = phi i64 [ %419, %484 ], [ %483, %482 ]
  br label %418

487:                                              ; preds = %431
  br label %489

488:                                              ; preds = %70
  br label %489

489:                                              ; preds = %488, %487
  br label %41

490:                                              ; preds = %68
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
