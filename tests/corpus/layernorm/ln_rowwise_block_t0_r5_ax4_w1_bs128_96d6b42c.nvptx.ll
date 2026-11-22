; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %13 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 5
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 4
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 3
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 2
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 1
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, ptr %13, i32 0, i32 0
  %20 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 2
  %21 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %22 = sext i32 %21 to i64
  %23 = icmp slt i64 %22, 4
  %24 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %25 = zext i32 %24 to i64
  %26 = icmp eq i64 %22, 0
  %27 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } }, { i64, i64, i64, i64, i64 }, [3 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %28 = load { i64, i64, i64, i64, i64 }, ptr %27, align 8
  %29 = extractvalue { i64, i64, i64, i64, i64 } %28, 0
  %30 = extractvalue { i64, i64, i64, i64, i64 } %28, 1
  %31 = mul i64 %29, %30
  %32 = extractvalue { i64, i64, i64, i64, i64 } %28, 2
  %33 = mul i64 %31, %32
  %34 = extractvalue { i64, i64, i64, i64, i64 } %28, 3
  %35 = mul i64 %33, %34
  %36 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %37 = zext i32 %36 to i64
  %38 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %39 = sext i32 %38 to i64
  %40 = icmp eq i64 %39, 0
  %41 = select i1 %40, i64 0, i64 %37
  %42 = select i1 %40, i64 0, i64 %35
  %43 = select i1 %40, i64 1, i64 %39
  %44 = icmp slt i64 %43, 0
  %45 = icmp sgt i64 %43, 0
  br label %46

46:                                               ; preds = %645, %1
  %47 = phi i64 [ %41, %1 ], [ %71, %645 ]
  %48 = phi i64 [ 0, %1 ], [ %72, %645 ]
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
  br label %646

74:                                               ; preds = %68
  br label %75

75:                                               ; preds = %74
  %76 = load [3 x { i32, i32, i8, i8, i1, i8 }], ptr %20, align 4
  %77 = trunc i64 %70 to i32
  %78 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 2, 0
  %79 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 2, 1
  %80 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 2, 2
  %81 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 2, 3
  %82 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 2, 4
  %83 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 2, 5
  %84 = zext i8 %81 to i32
  %85 = zext i8 %80 to i32
  %86 = zext i32 %77 to i64
  %87 = zext i32 %79 to i64
  %88 = mul i64 %87, %86
  %89 = zext i8 %83 to i32
  %90 = lshr i32 %77, %89
  %91 = lshr i64 %88, 32
  %92 = trunc i64 %91 to i32
  %93 = sub i32 %77, %92
  %94 = lshr i32 %93, %85
  %95 = add i32 %92, %94
  %96 = lshr i32 %95, %84
  %97 = select i1 %82, i32 %90, i32 %96
  %98 = mul i32 %97, %78
  %99 = sub i32 %77, %98
  %100 = zext i32 %99 to i64
  %101 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 1, 0
  %102 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 1, 1
  %103 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 1, 2
  %104 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 1, 3
  %105 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 1, 4
  %106 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 1, 5
  %107 = zext i8 %104 to i32
  %108 = zext i8 %103 to i32
  %109 = zext i32 %97 to i64
  %110 = zext i32 %102 to i64
  %111 = mul i64 %110, %109
  %112 = zext i8 %106 to i32
  %113 = lshr i32 %97, %112
  %114 = lshr i64 %111, 32
  %115 = trunc i64 %114 to i32
  %116 = sub i32 %97, %115
  %117 = lshr i32 %116, %108
  %118 = add i32 %115, %117
  %119 = lshr i32 %118, %107
  %120 = select i1 %105, i32 %113, i32 %119
  %121 = mul i32 %120, %101
  %122 = sub i32 %97, %121
  %123 = zext i32 %122 to i64
  %124 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 0, 0
  %125 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 0, 1
  %126 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 0, 2
  %127 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 0, 3
  %128 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 0, 4
  %129 = extractvalue [3 x { i32, i32, i8, i8, i1, i8 }] %76, 0, 5
  %130 = zext i8 %127 to i32
  %131 = zext i8 %126 to i32
  %132 = zext i32 %120 to i64
  %133 = zext i32 %125 to i64
  %134 = mul i64 %133, %132
  %135 = zext i8 %129 to i32
  %136 = lshr i32 %120, %135
  %137 = lshr i64 %134, 32
  %138 = trunc i64 %137 to i32
  %139 = sub i32 %120, %138
  %140 = lshr i32 %139, %131
  %141 = add i32 %138, %140
  %142 = lshr i32 %141, %130
  %143 = select i1 %128, i32 %136, i32 %142
  %144 = mul i32 %143, %124
  %145 = sub i32 %120, %144
  %146 = zext i32 %145 to i64
  %147 = zext i32 %143 to i64
  %148 = load i64, ptr %19, align 8
  %149 = load { ptr, { { i64 }, { {} } } }, ptr %18, align 8
  %150 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %151 = load float, ptr %16, align 4
  %152 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %15, align 8
  %153 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %152, 0
  %154 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %152, 1, 1, 0
  %155 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %152, 1, 1, 1
  %156 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %152, 1, 1, 2
  %157 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %152, 1, 1, 3
  %158 = mul i64 %147, %154
  %159 = mul i64 %146, %155
  %160 = add i64 %158, %159
  %161 = mul i64 %123, %156
  %162 = add i64 %160, %161
  %163 = mul i64 %100, %157
  %164 = add i64 %162, %163
  br label %165

165:                                              ; preds = %242, %75
  %166 = phi i64 [ 0, %75 ], [ %243, %242 ]
  %167 = phi i64 [ 0, %75 ], [ %180, %242 ]
  %168 = phi i64 [ 0, %75 ], [ %181, %242 ]
  %169 = phi float [ 0.000000e+00, %75 ], [ %244, %242 ]
  %170 = phi float [ 0.000000e+00, %75 ], [ %245, %242 ]
  %171 = phi float [ 0.000000e+00, %75 ], [ %246, %242 ]
  %172 = fadd contract float %169, 1.000000e+00
  %173 = add i64 %167, 128
  %174 = icmp slt i64 %173, %167
  %175 = select i1 %174, i64 1, i64 0
  %176 = icmp sge i64 %167, %148
  %177 = icmp eq i64 %168, 0
  %178 = xor i1 %177, true
  %179 = or i1 %178, %176
  %180 = select i1 %179, i64 %167, i64 %173
  %181 = select i1 %179, i64 %168, i64 %175
  br i1 %179, label %182, label %183

182:                                              ; preds = %165
  br label %247

183:                                              ; preds = %165
  br label %184

184:                                              ; preds = %183
  %185 = add i64 %167, %25
  %186 = add i64 %164, %185
  %187 = getelementptr inbounds float, ptr %153, i64 %186
  %188 = sub i64 %148, %185
  %189 = call i64 @llvm.smin.i64(i64 %188, i64 1)
  %190 = call i64 @llvm.smax.i64(i64 %189, i64 0)
  %191 = icmp eq i64 %189, 1
  %192 = icmp slt i64 %185, %148
  br i1 %192, label %193, label %241

193:                                              ; preds = %184
  br i1 %191, label %194, label %204

194:                                              ; preds = %193
  %195 = load float, ptr %187, align 4
  %196 = fsub contract float %195, %170
  %197 = fdiv float 1.000000e+00, %172
  %198 = fmul contract float %196, %197
  %199 = fadd contract float %170, %198
  %200 = fmul contract float %196, %196
  %201 = fmul contract float %200, %169
  %202 = fmul contract float %201, %197
  %203 = fadd contract float %171, %202
  br label %236

204:                                              ; preds = %193
  br label %205

205:                                              ; preds = %214, %204
  %206 = phi i64 [ 0, %204 ], [ %217, %214 ]
  %207 = phi i64 [ %166, %204 ], [ %218, %214 ]
  %208 = phi float [ %169, %204 ], [ %222, %214 ]
  %209 = phi float [ %170, %204 ], [ %226, %214 ]
  %210 = phi float [ %171, %204 ], [ %230, %214 ]
  %211 = icmp slt i64 %206, %190
  br i1 %211, label %212, label %213

212:                                              ; preds = %205
  br label %214

213:                                              ; preds = %205
  br label %231

214:                                              ; preds = %212
  %215 = icmp eq i64 %206, %190
  %216 = add i64 %206, 1
  %217 = select i1 %215, i64 %206, i64 %216
  %218 = add i64 %185, %206
  %219 = add i64 %164, %218
  %220 = getelementptr inbounds float, ptr %153, i64 %219
  %221 = load float, ptr %220, align 4
  %222 = fadd contract float %208, 1.000000e+00
  %223 = fsub contract float %221, %209
  %224 = fdiv float 1.000000e+00, %222
  %225 = fmul contract float %223, %224
  %226 = fadd contract float %209, %225
  %227 = fmul contract float %223, %223
  %228 = fmul contract float %227, %208
  %229 = fmul contract float %228, %224
  %230 = fadd contract float %210, %229
  br label %205

231:                                              ; preds = %213
  %232 = phi i64 [ %207, %213 ]
  %233 = phi float [ %208, %213 ]
  %234 = phi float [ %209, %213 ]
  %235 = phi float [ %210, %213 ]
  br label %236

236:                                              ; preds = %231, %194
  %237 = phi i64 [ %232, %231 ], [ %185, %194 ]
  %238 = phi float [ %233, %231 ], [ %172, %194 ]
  %239 = phi float [ %234, %231 ], [ %199, %194 ]
  %240 = phi float [ %235, %231 ], [ %203, %194 ]
  br label %242

241:                                              ; preds = %184
  br label %242

242:                                              ; preds = %241, %236
  %243 = phi i64 [ %166, %241 ], [ %237, %236 ]
  %244 = phi float [ %169, %241 ], [ %238, %236 ]
  %245 = phi float [ %170, %241 ], [ %239, %236 ]
  %246 = phi float [ %171, %241 ], [ %240, %236 ]
  br label %165

247:                                              ; preds = %182
  %248 = phi float [ %169, %182 ]
  %249 = phi float [ %170, %182 ]
  %250 = phi float [ %171, %182 ]
  %251 = insertvalue { float, float, float } undef, float %248, 0
  %252 = insertvalue { float, float, float } %251, float %249, 1
  %253 = insertvalue { float, float, float } %252, float %250, 2
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } %253, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %254 = load i32, ptr %12, align 4
  %255 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %254, i32 16, i32 31)
  store i32 %255, ptr %11, align 4
  %256 = getelementptr inbounds i32, ptr %11, i32 1
  %257 = getelementptr inbounds i32, ptr %12, i32 1
  %258 = load i32, ptr %257, align 4
  %259 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %258, i32 16, i32 31)
  store i32 %259, ptr %256, align 4
  %260 = getelementptr inbounds i32, ptr %11, i32 2
  %261 = getelementptr inbounds i32, ptr %12, i32 2
  %262 = load i32, ptr %261, align 4
  %263 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %262, i32 16, i32 31)
  store i32 %263, ptr %260, align 4
  %264 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %265 = getelementptr { float, float, float }, ptr %12, i32 0, i32 0
  %266 = load float, ptr %265, align 4
  %267 = extractvalue { float, float, float } %264, 0
  %268 = fadd contract float %266, %267
  %269 = call float @llvm.maxnum.f32(float %268, float 1.000000e+00)
  %270 = extractvalue { float, float, float } %264, 1
  %271 = getelementptr { float, float, float }, ptr %12, i32 0, i32 1
  %272 = load float, ptr %271, align 4
  %273 = fsub contract float %270, %272
  %274 = fdiv float %267, %269
  %275 = getelementptr { float, float, float }, ptr %12, i32 0, i32 2
  %276 = extractvalue { float, float, float } %264, 2
  %277 = load float, ptr %275, align 4
  %278 = fadd contract float %277, %276
  %279 = fmul contract float %273, %273
  %280 = fmul contract float %279, %266
  %281 = fmul contract float %280, %274
  %282 = fadd contract float %278, %281
  store float %282, ptr %275, align 4
  %283 = fmul contract float %273, %274
  %284 = load float, ptr %271, align 4
  %285 = fadd contract float %284, %283
  store float %285, ptr %271, align 4
  store float %268, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %286 = load i32, ptr %12, align 4
  %287 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %286, i32 8, i32 31)
  store i32 %287, ptr %10, align 4
  %288 = getelementptr inbounds i32, ptr %10, i32 1
  %289 = load i32, ptr %257, align 4
  %290 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %289, i32 8, i32 31)
  store i32 %290, ptr %288, align 4
  %291 = getelementptr inbounds i32, ptr %10, i32 2
  %292 = load i32, ptr %261, align 4
  %293 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %292, i32 8, i32 31)
  store i32 %293, ptr %291, align 4
  %294 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %295 = load float, ptr %265, align 4
  %296 = extractvalue { float, float, float } %294, 0
  %297 = fadd contract float %295, %296
  %298 = call float @llvm.maxnum.f32(float %297, float 1.000000e+00)
  %299 = extractvalue { float, float, float } %294, 1
  %300 = load float, ptr %271, align 4
  %301 = fsub contract float %299, %300
  %302 = fdiv float %296, %298
  %303 = extractvalue { float, float, float } %294, 2
  %304 = load float, ptr %275, align 4
  %305 = fadd contract float %304, %303
  %306 = fmul contract float %301, %301
  %307 = fmul contract float %306, %295
  %308 = fmul contract float %307, %302
  %309 = fadd contract float %305, %308
  store float %309, ptr %275, align 4
  %310 = fmul contract float %301, %302
  %311 = load float, ptr %271, align 4
  %312 = fadd contract float %311, %310
  store float %312, ptr %271, align 4
  store float %297, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %313 = load i32, ptr %12, align 4
  %314 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %313, i32 4, i32 31)
  store i32 %314, ptr %9, align 4
  %315 = getelementptr inbounds i32, ptr %9, i32 1
  %316 = load i32, ptr %257, align 4
  %317 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %316, i32 4, i32 31)
  store i32 %317, ptr %315, align 4
  %318 = getelementptr inbounds i32, ptr %9, i32 2
  %319 = load i32, ptr %261, align 4
  %320 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %319, i32 4, i32 31)
  store i32 %320, ptr %318, align 4
  %321 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %322 = load float, ptr %265, align 4
  %323 = extractvalue { float, float, float } %321, 0
  %324 = fadd contract float %322, %323
  %325 = call float @llvm.maxnum.f32(float %324, float 1.000000e+00)
  %326 = extractvalue { float, float, float } %321, 1
  %327 = load float, ptr %271, align 4
  %328 = fsub contract float %326, %327
  %329 = fdiv float %323, %325
  %330 = extractvalue { float, float, float } %321, 2
  %331 = load float, ptr %275, align 4
  %332 = fadd contract float %331, %330
  %333 = fmul contract float %328, %328
  %334 = fmul contract float %333, %322
  %335 = fmul contract float %334, %329
  %336 = fadd contract float %332, %335
  store float %336, ptr %275, align 4
  %337 = fmul contract float %328, %329
  %338 = load float, ptr %271, align 4
  %339 = fadd contract float %338, %337
  store float %339, ptr %271, align 4
  store float %324, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %340 = load i32, ptr %12, align 4
  %341 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %340, i32 2, i32 31)
  store i32 %341, ptr %8, align 4
  %342 = getelementptr inbounds i32, ptr %8, i32 1
  %343 = load i32, ptr %257, align 4
  %344 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %343, i32 2, i32 31)
  store i32 %344, ptr %342, align 4
  %345 = getelementptr inbounds i32, ptr %8, i32 2
  %346 = load i32, ptr %261, align 4
  %347 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %346, i32 2, i32 31)
  store i32 %347, ptr %345, align 4
  %348 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %349 = load float, ptr %265, align 4
  %350 = extractvalue { float, float, float } %348, 0
  %351 = fadd contract float %349, %350
  %352 = call float @llvm.maxnum.f32(float %351, float 1.000000e+00)
  %353 = extractvalue { float, float, float } %348, 1
  %354 = load float, ptr %271, align 4
  %355 = fsub contract float %353, %354
  %356 = fdiv float %350, %352
  %357 = extractvalue { float, float, float } %348, 2
  %358 = load float, ptr %275, align 4
  %359 = fadd contract float %358, %357
  %360 = fmul contract float %355, %355
  %361 = fmul contract float %360, %349
  %362 = fmul contract float %361, %356
  %363 = fadd contract float %359, %362
  store float %363, ptr %275, align 4
  %364 = fmul contract float %355, %356
  %365 = load float, ptr %271, align 4
  %366 = fadd contract float %365, %364
  store float %366, ptr %271, align 4
  store float %351, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %367 = load i32, ptr %12, align 4
  %368 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %367, i32 1, i32 31)
  store i32 %368, ptr %7, align 4
  %369 = getelementptr inbounds i32, ptr %7, i32 1
  %370 = load i32, ptr %257, align 4
  %371 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %370, i32 1, i32 31)
  store i32 %371, ptr %369, align 4
  %372 = getelementptr inbounds i32, ptr %7, i32 2
  %373 = load i32, ptr %261, align 4
  %374 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %373, i32 1, i32 31)
  store i32 %374, ptr %372, align 4
  %375 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %376 = load float, ptr %265, align 4
  %377 = extractvalue { float, float, float } %375, 0
  %378 = fadd contract float %376, %377
  %379 = call float @llvm.maxnum.f32(float %378, float 1.000000e+00)
  %380 = extractvalue { float, float, float } %375, 1
  %381 = load float, ptr %271, align 4
  %382 = fsub contract float %380, %381
  %383 = fdiv float %377, %379
  %384 = extractvalue { float, float, float } %375, 2
  %385 = load float, ptr %275, align 4
  %386 = fadd contract float %385, %384
  %387 = fmul contract float %382, %382
  %388 = fmul contract float %387, %376
  %389 = fmul contract float %388, %383
  %390 = fadd contract float %386, %389
  store float %390, ptr %275, align 4
  %391 = fmul contract float %382, %383
  %392 = load float, ptr %271, align 4
  %393 = fadd contract float %392, %391
  store float %393, ptr %271, align 4
  store float %378, ptr %265, align 4
  %394 = udiv i64 %25, 32
  %395 = trunc i64 %394 to i32
  %396 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c._global_alloc_0._gpu_shared_mem, i32 %395
  %397 = trunc i64 %22 to i32
  %398 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c._global_alloc_0._gpu_shared_mem, i32 %397
  br i1 %26, label %399, label %401

399:                                              ; preds = %247
  %400 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %400, ptr addrspace(3) %396, align 4
  br label %402

401:                                              ; preds = %247
  br label %402

402:                                              ; preds = %401, %399
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %403 = icmp eq i64 %394, 0
  br i1 %403, label %404, label %548

404:                                              ; preds = %402
  br i1 %23, label %405, label %407

405:                                              ; preds = %404
  %406 = load { float, float, float }, ptr addrspace(3) %398, align 4
  store { float, float, float } %406, ptr %12, align 4
  br label %408

407:                                              ; preds = %404
  store { float, float, float } zeroinitializer, ptr %12, align 4
  br label %408

408:                                              ; preds = %407, %405
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %409 = load i32, ptr %12, align 4
  %410 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %409, i32 16, i32 31)
  store i32 %410, ptr %6, align 4
  %411 = getelementptr inbounds i32, ptr %6, i32 1
  %412 = load i32, ptr %257, align 4
  %413 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %412, i32 16, i32 31)
  store i32 %413, ptr %411, align 4
  %414 = getelementptr inbounds i32, ptr %6, i32 2
  %415 = load i32, ptr %261, align 4
  %416 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %415, i32 16, i32 31)
  store i32 %416, ptr %414, align 4
  %417 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %418 = load float, ptr %265, align 4
  %419 = extractvalue { float, float, float } %417, 0
  %420 = fadd contract float %418, %419
  %421 = call float @llvm.maxnum.f32(float %420, float 1.000000e+00)
  %422 = extractvalue { float, float, float } %417, 1
  %423 = load float, ptr %271, align 4
  %424 = fsub contract float %422, %423
  %425 = fdiv float %419, %421
  %426 = extractvalue { float, float, float } %417, 2
  %427 = load float, ptr %275, align 4
  %428 = fadd contract float %427, %426
  %429 = fmul contract float %424, %424
  %430 = fmul contract float %429, %418
  %431 = fmul contract float %430, %425
  %432 = fadd contract float %428, %431
  store float %432, ptr %275, align 4
  %433 = fmul contract float %424, %425
  %434 = load float, ptr %271, align 4
  %435 = fadd contract float %434, %433
  store float %435, ptr %271, align 4
  store float %420, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %436 = load i32, ptr %12, align 4
  %437 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %436, i32 8, i32 31)
  store i32 %437, ptr %5, align 4
  %438 = getelementptr inbounds i32, ptr %5, i32 1
  %439 = load i32, ptr %257, align 4
  %440 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %439, i32 8, i32 31)
  store i32 %440, ptr %438, align 4
  %441 = getelementptr inbounds i32, ptr %5, i32 2
  %442 = load i32, ptr %261, align 4
  %443 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %442, i32 8, i32 31)
  store i32 %443, ptr %441, align 4
  %444 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %445 = load float, ptr %265, align 4
  %446 = extractvalue { float, float, float } %444, 0
  %447 = fadd contract float %445, %446
  %448 = call float @llvm.maxnum.f32(float %447, float 1.000000e+00)
  %449 = extractvalue { float, float, float } %444, 1
  %450 = load float, ptr %271, align 4
  %451 = fsub contract float %449, %450
  %452 = fdiv float %446, %448
  %453 = extractvalue { float, float, float } %444, 2
  %454 = load float, ptr %275, align 4
  %455 = fadd contract float %454, %453
  %456 = fmul contract float %451, %451
  %457 = fmul contract float %456, %445
  %458 = fmul contract float %457, %452
  %459 = fadd contract float %455, %458
  store float %459, ptr %275, align 4
  %460 = fmul contract float %451, %452
  %461 = load float, ptr %271, align 4
  %462 = fadd contract float %461, %460
  store float %462, ptr %271, align 4
  store float %447, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %463 = load i32, ptr %12, align 4
  %464 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %463, i32 4, i32 31)
  store i32 %464, ptr %4, align 4
  %465 = getelementptr inbounds i32, ptr %4, i32 1
  %466 = load i32, ptr %257, align 4
  %467 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %466, i32 4, i32 31)
  store i32 %467, ptr %465, align 4
  %468 = getelementptr inbounds i32, ptr %4, i32 2
  %469 = load i32, ptr %261, align 4
  %470 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %469, i32 4, i32 31)
  store i32 %470, ptr %468, align 4
  %471 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %472 = load float, ptr %265, align 4
  %473 = extractvalue { float, float, float } %471, 0
  %474 = fadd contract float %472, %473
  %475 = call float @llvm.maxnum.f32(float %474, float 1.000000e+00)
  %476 = extractvalue { float, float, float } %471, 1
  %477 = load float, ptr %271, align 4
  %478 = fsub contract float %476, %477
  %479 = fdiv float %473, %475
  %480 = extractvalue { float, float, float } %471, 2
  %481 = load float, ptr %275, align 4
  %482 = fadd contract float %481, %480
  %483 = fmul contract float %478, %478
  %484 = fmul contract float %483, %472
  %485 = fmul contract float %484, %479
  %486 = fadd contract float %482, %485
  store float %486, ptr %275, align 4
  %487 = fmul contract float %478, %479
  %488 = load float, ptr %271, align 4
  %489 = fadd contract float %488, %487
  store float %489, ptr %271, align 4
  store float %474, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %490 = load i32, ptr %12, align 4
  %491 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %490, i32 2, i32 31)
  store i32 %491, ptr %3, align 4
  %492 = getelementptr inbounds i32, ptr %3, i32 1
  %493 = load i32, ptr %257, align 4
  %494 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %493, i32 2, i32 31)
  store i32 %494, ptr %492, align 4
  %495 = getelementptr inbounds i32, ptr %3, i32 2
  %496 = load i32, ptr %261, align 4
  %497 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %496, i32 2, i32 31)
  store i32 %497, ptr %495, align 4
  %498 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %499 = load float, ptr %265, align 4
  %500 = extractvalue { float, float, float } %498, 0
  %501 = fadd contract float %499, %500
  %502 = call float @llvm.maxnum.f32(float %501, float 1.000000e+00)
  %503 = extractvalue { float, float, float } %498, 1
  %504 = load float, ptr %271, align 4
  %505 = fsub contract float %503, %504
  %506 = fdiv float %500, %502
  %507 = extractvalue { float, float, float } %498, 2
  %508 = load float, ptr %275, align 4
  %509 = fadd contract float %508, %507
  %510 = fmul contract float %505, %505
  %511 = fmul contract float %510, %499
  %512 = fmul contract float %511, %506
  %513 = fadd contract float %509, %512
  store float %513, ptr %275, align 4
  %514 = fmul contract float %505, %506
  %515 = load float, ptr %271, align 4
  %516 = fadd contract float %515, %514
  store float %516, ptr %271, align 4
  store float %501, ptr %265, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %517 = load i32, ptr %12, align 4
  %518 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %517, i32 1, i32 31)
  store i32 %518, ptr %2, align 4
  %519 = getelementptr inbounds i32, ptr %2, i32 1
  %520 = load i32, ptr %257, align 4
  %521 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %520, i32 1, i32 31)
  store i32 %521, ptr %519, align 4
  %522 = getelementptr inbounds i32, ptr %2, i32 2
  %523 = load i32, ptr %261, align 4
  %524 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %523, i32 1, i32 31)
  store i32 %524, ptr %522, align 4
  %525 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %526 = load float, ptr %265, align 4
  %527 = extractvalue { float, float, float } %525, 0
  %528 = fadd contract float %526, %527
  %529 = call float @llvm.maxnum.f32(float %528, float 1.000000e+00)
  %530 = extractvalue { float, float, float } %525, 1
  %531 = load float, ptr %271, align 4
  %532 = fsub contract float %530, %531
  %533 = fdiv float %527, %529
  %534 = extractvalue { float, float, float } %525, 2
  %535 = load float, ptr %275, align 4
  %536 = fadd contract float %535, %534
  %537 = fmul contract float %532, %532
  %538 = fmul contract float %537, %526
  %539 = fmul contract float %538, %533
  %540 = fadd contract float %536, %539
  store float %540, ptr %275, align 4
  %541 = fmul contract float %532, %533
  %542 = load float, ptr %271, align 4
  %543 = fadd contract float %542, %541
  store float %543, ptr %271, align 4
  store float %528, ptr %265, align 4
  br i1 %26, label %544, label %546

544:                                              ; preds = %408
  %545 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %545, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c._global_alloc_0._gpu_shared_mem, align 4
  br label %547

546:                                              ; preds = %408
  br label %547

547:                                              ; preds = %546, %544
  br label %549

548:                                              ; preds = %402
  br label %549

549:                                              ; preds = %548, %547
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %550 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %550, ptr %12, align 4
  %551 = load float, ptr %271, align 4
  store float %551, ptr %271, align 4
  %552 = load float, ptr %275, align 4
  store float %552, ptr %275, align 4
  %553 = load float, ptr %265, align 4
  store float %553, ptr %265, align 4
  %554 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %555 = extractvalue { float, float, float } %554, 0
  %556 = extractvalue { float, float, float } %554, 1
  %557 = extractvalue { float, float, float } %554, 2
  %558 = fdiv float %557, %555
  %559 = fadd contract float %558, %151
  %560 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %559)
  %561 = load { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } }, ptr %14, align 8
  %562 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %561, 0
  %563 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %561, 1, 1, 0
  %564 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %561, 1, 1, 1
  %565 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %561, 1, 1, 2
  %566 = extractvalue { ptr, { { i64, i64, i64, i64, i64 }, { i64, i64, i64, i64, {} } } } %561, 1, 1, 3
  %567 = extractvalue { ptr, { { i64 }, { {} } } } %149, 0
  %568 = extractvalue { ptr, { { i64 }, { {} } } } %150, 0
  %569 = mul i64 %147, %563
  %570 = mul i64 %146, %564
  %571 = add i64 %569, %570
  %572 = mul i64 %123, %565
  %573 = add i64 %571, %572
  %574 = mul i64 %100, %566
  %575 = add i64 %573, %574
  br label %576

576:                                              ; preds = %643, %549
  %577 = phi i64 [ 0, %549 ], [ %644, %643 ]
  %578 = phi i64 [ 0, %549 ], [ %587, %643 ]
  %579 = phi i64 [ 0, %549 ], [ %588, %643 ]
  %580 = add i64 %578, 128
  %581 = icmp slt i64 %580, %578
  %582 = select i1 %581, i64 1, i64 0
  %583 = icmp sge i64 %578, %148
  %584 = icmp eq i64 %579, 0
  %585 = xor i1 %584, true
  %586 = or i1 %585, %583
  %587 = select i1 %586, i64 %578, i64 %580
  %588 = select i1 %586, i64 %579, i64 %582
  br i1 %586, label %589, label %590

589:                                              ; preds = %576
  br label %645

590:                                              ; preds = %576
  br label %591

591:                                              ; preds = %590
  %592 = add i64 %578, %25
  %593 = getelementptr inbounds float, ptr %568, i64 %592
  %594 = getelementptr inbounds float, ptr %567, i64 %592
  %595 = add i64 %575, %592
  %596 = getelementptr inbounds float, ptr %562, i64 %595
  %597 = add i64 %164, %592
  %598 = getelementptr inbounds float, ptr %153, i64 %597
  %599 = sub i64 %148, %592
  %600 = call i64 @llvm.smin.i64(i64 %599, i64 1)
  %601 = call i64 @llvm.smax.i64(i64 %600, i64 0)
  %602 = icmp eq i64 %600, 1
  %603 = icmp slt i64 %592, %148
  br i1 %603, label %604, label %642

604:                                              ; preds = %591
  br i1 %602, label %605, label %613

605:                                              ; preds = %604
  %606 = load float, ptr %598, align 4
  %607 = load float, ptr %594, align 4, !invariant.load !1
  %608 = load float, ptr %593, align 4, !invariant.load !1
  %609 = fsub contract float %606, %556
  %610 = fmul contract float %609, %560
  %611 = fmul contract float %610, %607
  %612 = fadd contract float %611, %608
  store float %612, ptr %596, align 4
  br label %640

613:                                              ; preds = %604
  br label %614

614:                                              ; preds = %620, %613
  %615 = phi i64 [ 0, %613 ], [ %623, %620 ]
  %616 = phi i64 [ %577, %613 ], [ %624, %620 ]
  %617 = icmp slt i64 %615, %601
  br i1 %617, label %618, label %619

618:                                              ; preds = %614
  br label %620

619:                                              ; preds = %614
  br label %638

620:                                              ; preds = %618
  %621 = icmp eq i64 %615, %601
  %622 = add i64 %615, 1
  %623 = select i1 %621, i64 %615, i64 %622
  %624 = add i64 %592, %615
  %625 = add i64 %164, %624
  %626 = getelementptr inbounds float, ptr %153, i64 %625
  %627 = load float, ptr %626, align 4
  %628 = getelementptr inbounds float, ptr %567, i64 %624
  %629 = load float, ptr %628, align 4, !invariant.load !1
  %630 = getelementptr inbounds float, ptr %568, i64 %624
  %631 = load float, ptr %630, align 4, !invariant.load !1
  %632 = fsub contract float %627, %556
  %633 = fmul contract float %632, %560
  %634 = fmul contract float %633, %629
  %635 = fadd contract float %634, %631
  %636 = add i64 %575, %624
  %637 = getelementptr inbounds float, ptr %562, i64 %636
  store float %635, ptr %637, align 4
  br label %614

638:                                              ; preds = %619
  %639 = phi i64 [ %616, %619 ]
  br label %640

640:                                              ; preds = %638, %605
  %641 = phi i64 [ %639, %638 ], [ %592, %605 ]
  br label %643

642:                                              ; preds = %591
  br label %643

643:                                              ; preds = %642, %640
  %644 = phi i64 [ %577, %642 ], [ %641, %640 ]
  br label %576

645:                                              ; preds = %589
  br label %46

646:                                              ; preds = %73
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
