; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %13 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 5
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 4
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 3
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 2
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 1
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, bfloat, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 0
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %21 = sext i32 %20 to i64
  %22 = icmp slt i64 %21, 4
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %24 = zext i32 %23 to i64
  %25 = icmp eq i64 %21, 0
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %27 = zext i32 %26 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %29 = sext i32 %28 to i64
  %30 = icmp eq i64 %29, 0
  %31 = select i1 %30, i64 0, i64 %27
  %32 = select i1 %30, i64 0, i64 1
  %33 = select i1 %30, i64 1, i64 %29
  %34 = icmp slt i64 %33, 0
  %35 = icmp sgt i64 %33, 0
  br label %36

36:                                               ; preds = %545, %1
  %37 = phi i64 [ %31, %1 ], [ %60, %545 ]
  %38 = phi i64 [ 0, %1 ], [ %61, %545 ]
  %39 = icmp sge i64 %32, %37
  %40 = icmp sge i64 %37, %32
  %41 = add i64 %37, %33
  %42 = icmp slt i64 %41, %37
  %43 = xor i1 %42, %34
  %44 = select i1 %43, i64 1, i64 0
  %45 = icmp eq i64 %38, 0
  %46 = xor i1 %45, true
  %47 = or i1 %46, %39
  %48 = or i1 %46, %40
  br label %49

49:                                               ; preds = %36
  br i1 %35, label %50, label %55

50:                                               ; preds = %49
  br i1 %48, label %51, label %52

51:                                               ; preds = %50
  br label %58

52:                                               ; preds = %50
  br label %53

53:                                               ; preds = %52
  br label %57

54:                                               ; preds = %55
  br label %57

55:                                               ; preds = %49
  br i1 %47, label %56, label %54

56:                                               ; preds = %55
  br label %58

57:                                               ; preds = %54, %53
  br label %58

58:                                               ; preds = %57, %56, %51
  %59 = phi i1 [ true, %51 ], [ true, %56 ], [ false, %57 ]
  %60 = phi i64 [ %37, %51 ], [ %37, %56 ], [ %41, %57 ]
  %61 = phi i64 [ %38, %51 ], [ %38, %56 ], [ %44, %57 ]
  br i1 %59, label %62, label %63

62:                                               ; preds = %58
  br label %546

63:                                               ; preds = %58
  br label %64

64:                                               ; preds = %63
  %65 = load i64, ptr %19, align 8
  %66 = load { ptr, { { i64 }, { {} } } }, ptr %18, align 8
  %67 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %68 = load bfloat, ptr %16, align 2
  %69 = load { ptr, { { i64 }, { {} } } }, ptr %15, align 8
  %70 = extractvalue { ptr, { { i64 }, { {} } } } %69, 0
  br label %71

71:                                               ; preds = %148, %64
  %72 = phi i64 [ 0, %64 ], [ %149, %148 ]
  %73 = phi i64 [ 0, %64 ], [ %86, %148 ]
  %74 = phi i64 [ 0, %64 ], [ %87, %148 ]
  %75 = phi float [ 0.000000e+00, %64 ], [ %150, %148 ]
  %76 = phi float [ 0.000000e+00, %64 ], [ %151, %148 ]
  %77 = phi float [ 0.000000e+00, %64 ], [ %152, %148 ]
  %78 = fadd contract float %75, 1.000000e+00
  %79 = add i64 %73, 128
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
  br label %153

89:                                               ; preds = %71
  br label %90

90:                                               ; preds = %89
  %91 = add i64 %73, %24
  %92 = getelementptr inbounds bfloat, ptr %70, i64 %91
  %93 = sub i64 %65, %91
  %94 = call i64 @llvm.smin.i64(i64 %93, i64 1)
  %95 = call i64 @llvm.smax.i64(i64 %94, i64 0)
  %96 = icmp eq i64 %94, 1
  %97 = icmp slt i64 %91, %65
  br i1 %97, label %98, label %147

98:                                               ; preds = %90
  br i1 %96, label %99, label %110

99:                                               ; preds = %98
  %100 = load bfloat, ptr %92, align 2
  %101 = fpext bfloat %100 to float
  %102 = fsub contract float %101, %76
  %103 = fdiv float 1.000000e+00, %78
  %104 = fmul contract float %102, %103
  %105 = fadd contract float %76, %104
  %106 = fmul contract float %102, %102
  %107 = fmul contract float %106, %75
  %108 = fmul contract float %107, %103
  %109 = fadd contract float %77, %108
  br label %142

110:                                              ; preds = %98
  br label %111

111:                                              ; preds = %120, %110
  %112 = phi i64 [ 0, %110 ], [ %123, %120 ]
  %113 = phi i64 [ %72, %110 ], [ %124, %120 ]
  %114 = phi float [ %75, %110 ], [ %128, %120 ]
  %115 = phi float [ %76, %110 ], [ %132, %120 ]
  %116 = phi float [ %77, %110 ], [ %136, %120 ]
  %117 = icmp slt i64 %112, %95
  br i1 %117, label %118, label %119

118:                                              ; preds = %111
  br label %120

119:                                              ; preds = %111
  br label %137

120:                                              ; preds = %118
  %121 = icmp eq i64 %112, %95
  %122 = add i64 %112, 1
  %123 = select i1 %121, i64 %112, i64 %122
  %124 = add i64 %91, %112
  %125 = getelementptr inbounds bfloat, ptr %70, i64 %124
  %126 = load bfloat, ptr %125, align 2
  %127 = fpext bfloat %126 to float
  %128 = fadd contract float %114, 1.000000e+00
  %129 = fsub contract float %127, %115
  %130 = fdiv float 1.000000e+00, %128
  %131 = fmul contract float %129, %130
  %132 = fadd contract float %115, %131
  %133 = fmul contract float %129, %129
  %134 = fmul contract float %133, %114
  %135 = fmul contract float %134, %130
  %136 = fadd contract float %116, %135
  br label %111

137:                                              ; preds = %119
  %138 = phi i64 [ %113, %119 ]
  %139 = phi float [ %114, %119 ]
  %140 = phi float [ %115, %119 ]
  %141 = phi float [ %116, %119 ]
  br label %142

142:                                              ; preds = %137, %99
  %143 = phi i64 [ %138, %137 ], [ %91, %99 ]
  %144 = phi float [ %139, %137 ], [ %78, %99 ]
  %145 = phi float [ %140, %137 ], [ %105, %99 ]
  %146 = phi float [ %141, %137 ], [ %109, %99 ]
  br label %148

147:                                              ; preds = %90
  br label %148

148:                                              ; preds = %147, %142
  %149 = phi i64 [ %72, %147 ], [ %143, %142 ]
  %150 = phi float [ %75, %147 ], [ %144, %142 ]
  %151 = phi float [ %76, %147 ], [ %145, %142 ]
  %152 = phi float [ %77, %147 ], [ %146, %142 ]
  br label %71

153:                                              ; preds = %88
  %154 = phi float [ %75, %88 ]
  %155 = phi float [ %76, %88 ]
  %156 = phi float [ %77, %88 ]
  %157 = insertvalue { float, float, float } undef, float %154, 0
  %158 = insertvalue { float, float, float } %157, float %155, 1
  %159 = insertvalue { float, float, float } %158, float %156, 2
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } %159, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %160 = load i32, ptr %12, align 4
  %161 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %160, i32 16, i32 31)
  store i32 %161, ptr %11, align 4
  %162 = getelementptr inbounds i32, ptr %11, i32 1
  %163 = getelementptr inbounds i32, ptr %12, i32 1
  %164 = load i32, ptr %163, align 4
  %165 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %164, i32 16, i32 31)
  store i32 %165, ptr %162, align 4
  %166 = getelementptr inbounds i32, ptr %11, i32 2
  %167 = getelementptr inbounds i32, ptr %12, i32 2
  %168 = load i32, ptr %167, align 4
  %169 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %168, i32 16, i32 31)
  store i32 %169, ptr %166, align 4
  %170 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %171 = getelementptr { float, float, float }, ptr %12, i32 0, i32 0
  %172 = load float, ptr %171, align 4
  %173 = extractvalue { float, float, float } %170, 0
  %174 = fadd contract float %172, %173
  %175 = call float @llvm.maxnum.f32(float %174, float 1.000000e+00)
  %176 = extractvalue { float, float, float } %170, 1
  %177 = getelementptr { float, float, float }, ptr %12, i32 0, i32 1
  %178 = load float, ptr %177, align 4
  %179 = fsub contract float %176, %178
  %180 = fdiv float %173, %175
  %181 = getelementptr { float, float, float }, ptr %12, i32 0, i32 2
  %182 = extractvalue { float, float, float } %170, 2
  %183 = load float, ptr %181, align 4
  %184 = fadd contract float %183, %182
  %185 = fmul contract float %179, %179
  %186 = fmul contract float %185, %172
  %187 = fmul contract float %186, %180
  %188 = fadd contract float %184, %187
  store float %188, ptr %181, align 4
  %189 = fmul contract float %179, %180
  %190 = load float, ptr %177, align 4
  %191 = fadd contract float %190, %189
  store float %191, ptr %177, align 4
  store float %174, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %192 = load i32, ptr %12, align 4
  %193 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %192, i32 8, i32 31)
  store i32 %193, ptr %10, align 4
  %194 = getelementptr inbounds i32, ptr %10, i32 1
  %195 = load i32, ptr %163, align 4
  %196 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %195, i32 8, i32 31)
  store i32 %196, ptr %194, align 4
  %197 = getelementptr inbounds i32, ptr %10, i32 2
  %198 = load i32, ptr %167, align 4
  %199 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %198, i32 8, i32 31)
  store i32 %199, ptr %197, align 4
  %200 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %201 = load float, ptr %171, align 4
  %202 = extractvalue { float, float, float } %200, 0
  %203 = fadd contract float %201, %202
  %204 = call float @llvm.maxnum.f32(float %203, float 1.000000e+00)
  %205 = extractvalue { float, float, float } %200, 1
  %206 = load float, ptr %177, align 4
  %207 = fsub contract float %205, %206
  %208 = fdiv float %202, %204
  %209 = extractvalue { float, float, float } %200, 2
  %210 = load float, ptr %181, align 4
  %211 = fadd contract float %210, %209
  %212 = fmul contract float %207, %207
  %213 = fmul contract float %212, %201
  %214 = fmul contract float %213, %208
  %215 = fadd contract float %211, %214
  store float %215, ptr %181, align 4
  %216 = fmul contract float %207, %208
  %217 = load float, ptr %177, align 4
  %218 = fadd contract float %217, %216
  store float %218, ptr %177, align 4
  store float %203, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %219 = load i32, ptr %12, align 4
  %220 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %219, i32 4, i32 31)
  store i32 %220, ptr %9, align 4
  %221 = getelementptr inbounds i32, ptr %9, i32 1
  %222 = load i32, ptr %163, align 4
  %223 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %222, i32 4, i32 31)
  store i32 %223, ptr %221, align 4
  %224 = getelementptr inbounds i32, ptr %9, i32 2
  %225 = load i32, ptr %167, align 4
  %226 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %225, i32 4, i32 31)
  store i32 %226, ptr %224, align 4
  %227 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %228 = load float, ptr %171, align 4
  %229 = extractvalue { float, float, float } %227, 0
  %230 = fadd contract float %228, %229
  %231 = call float @llvm.maxnum.f32(float %230, float 1.000000e+00)
  %232 = extractvalue { float, float, float } %227, 1
  %233 = load float, ptr %177, align 4
  %234 = fsub contract float %232, %233
  %235 = fdiv float %229, %231
  %236 = extractvalue { float, float, float } %227, 2
  %237 = load float, ptr %181, align 4
  %238 = fadd contract float %237, %236
  %239 = fmul contract float %234, %234
  %240 = fmul contract float %239, %228
  %241 = fmul contract float %240, %235
  %242 = fadd contract float %238, %241
  store float %242, ptr %181, align 4
  %243 = fmul contract float %234, %235
  %244 = load float, ptr %177, align 4
  %245 = fadd contract float %244, %243
  store float %245, ptr %177, align 4
  store float %230, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %246 = load i32, ptr %12, align 4
  %247 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %246, i32 2, i32 31)
  store i32 %247, ptr %8, align 4
  %248 = getelementptr inbounds i32, ptr %8, i32 1
  %249 = load i32, ptr %163, align 4
  %250 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %249, i32 2, i32 31)
  store i32 %250, ptr %248, align 4
  %251 = getelementptr inbounds i32, ptr %8, i32 2
  %252 = load i32, ptr %167, align 4
  %253 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %252, i32 2, i32 31)
  store i32 %253, ptr %251, align 4
  %254 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %255 = load float, ptr %171, align 4
  %256 = extractvalue { float, float, float } %254, 0
  %257 = fadd contract float %255, %256
  %258 = call float @llvm.maxnum.f32(float %257, float 1.000000e+00)
  %259 = extractvalue { float, float, float } %254, 1
  %260 = load float, ptr %177, align 4
  %261 = fsub contract float %259, %260
  %262 = fdiv float %256, %258
  %263 = extractvalue { float, float, float } %254, 2
  %264 = load float, ptr %181, align 4
  %265 = fadd contract float %264, %263
  %266 = fmul contract float %261, %261
  %267 = fmul contract float %266, %255
  %268 = fmul contract float %267, %262
  %269 = fadd contract float %265, %268
  store float %269, ptr %181, align 4
  %270 = fmul contract float %261, %262
  %271 = load float, ptr %177, align 4
  %272 = fadd contract float %271, %270
  store float %272, ptr %177, align 4
  store float %257, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %273 = load i32, ptr %12, align 4
  %274 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %273, i32 1, i32 31)
  store i32 %274, ptr %7, align 4
  %275 = getelementptr inbounds i32, ptr %7, i32 1
  %276 = load i32, ptr %163, align 4
  %277 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %276, i32 1, i32 31)
  store i32 %277, ptr %275, align 4
  %278 = getelementptr inbounds i32, ptr %7, i32 2
  %279 = load i32, ptr %167, align 4
  %280 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %279, i32 1, i32 31)
  store i32 %280, ptr %278, align 4
  %281 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %282 = load float, ptr %171, align 4
  %283 = extractvalue { float, float, float } %281, 0
  %284 = fadd contract float %282, %283
  %285 = call float @llvm.maxnum.f32(float %284, float 1.000000e+00)
  %286 = extractvalue { float, float, float } %281, 1
  %287 = load float, ptr %177, align 4
  %288 = fsub contract float %286, %287
  %289 = fdiv float %283, %285
  %290 = extractvalue { float, float, float } %281, 2
  %291 = load float, ptr %181, align 4
  %292 = fadd contract float %291, %290
  %293 = fmul contract float %288, %288
  %294 = fmul contract float %293, %282
  %295 = fmul contract float %294, %289
  %296 = fadd contract float %292, %295
  store float %296, ptr %181, align 4
  %297 = fmul contract float %288, %289
  %298 = load float, ptr %177, align 4
  %299 = fadd contract float %298, %297
  store float %299, ptr %177, align 4
  store float %284, ptr %171, align 4
  %300 = udiv i64 %24, 32
  %301 = trunc i64 %300 to i32
  %302 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70._global_alloc_0._gpu_shared_mem, i32 %301
  %303 = trunc i64 %21 to i32
  %304 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70._global_alloc_0._gpu_shared_mem, i32 %303
  br i1 %25, label %305, label %307

305:                                              ; preds = %153
  %306 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %306, ptr addrspace(3) %302, align 4
  br label %308

307:                                              ; preds = %153
  br label %308

308:                                              ; preds = %307, %305
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %309 = icmp eq i64 %300, 0
  br i1 %309, label %310, label %454

310:                                              ; preds = %308
  br i1 %22, label %311, label %313

311:                                              ; preds = %310
  %312 = load { float, float, float }, ptr addrspace(3) %304, align 4
  store { float, float, float } %312, ptr %12, align 4
  br label %314

313:                                              ; preds = %310
  store { float, float, float } zeroinitializer, ptr %12, align 4
  br label %314

314:                                              ; preds = %313, %311
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %315 = load i32, ptr %12, align 4
  %316 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %315, i32 16, i32 31)
  store i32 %316, ptr %6, align 4
  %317 = getelementptr inbounds i32, ptr %6, i32 1
  %318 = load i32, ptr %163, align 4
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 16, i32 31)
  store i32 %319, ptr %317, align 4
  %320 = getelementptr inbounds i32, ptr %6, i32 2
  %321 = load i32, ptr %167, align 4
  %322 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %321, i32 16, i32 31)
  store i32 %322, ptr %320, align 4
  %323 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %324 = load float, ptr %171, align 4
  %325 = extractvalue { float, float, float } %323, 0
  %326 = fadd contract float %324, %325
  %327 = call float @llvm.maxnum.f32(float %326, float 1.000000e+00)
  %328 = extractvalue { float, float, float } %323, 1
  %329 = load float, ptr %177, align 4
  %330 = fsub contract float %328, %329
  %331 = fdiv float %325, %327
  %332 = extractvalue { float, float, float } %323, 2
  %333 = load float, ptr %181, align 4
  %334 = fadd contract float %333, %332
  %335 = fmul contract float %330, %330
  %336 = fmul contract float %335, %324
  %337 = fmul contract float %336, %331
  %338 = fadd contract float %334, %337
  store float %338, ptr %181, align 4
  %339 = fmul contract float %330, %331
  %340 = load float, ptr %177, align 4
  %341 = fadd contract float %340, %339
  store float %341, ptr %177, align 4
  store float %326, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %342 = load i32, ptr %12, align 4
  %343 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %342, i32 8, i32 31)
  store i32 %343, ptr %5, align 4
  %344 = getelementptr inbounds i32, ptr %5, i32 1
  %345 = load i32, ptr %163, align 4
  %346 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %345, i32 8, i32 31)
  store i32 %346, ptr %344, align 4
  %347 = getelementptr inbounds i32, ptr %5, i32 2
  %348 = load i32, ptr %167, align 4
  %349 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %348, i32 8, i32 31)
  store i32 %349, ptr %347, align 4
  %350 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %351 = load float, ptr %171, align 4
  %352 = extractvalue { float, float, float } %350, 0
  %353 = fadd contract float %351, %352
  %354 = call float @llvm.maxnum.f32(float %353, float 1.000000e+00)
  %355 = extractvalue { float, float, float } %350, 1
  %356 = load float, ptr %177, align 4
  %357 = fsub contract float %355, %356
  %358 = fdiv float %352, %354
  %359 = extractvalue { float, float, float } %350, 2
  %360 = load float, ptr %181, align 4
  %361 = fadd contract float %360, %359
  %362 = fmul contract float %357, %357
  %363 = fmul contract float %362, %351
  %364 = fmul contract float %363, %358
  %365 = fadd contract float %361, %364
  store float %365, ptr %181, align 4
  %366 = fmul contract float %357, %358
  %367 = load float, ptr %177, align 4
  %368 = fadd contract float %367, %366
  store float %368, ptr %177, align 4
  store float %353, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %369 = load i32, ptr %12, align 4
  %370 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %369, i32 4, i32 31)
  store i32 %370, ptr %4, align 4
  %371 = getelementptr inbounds i32, ptr %4, i32 1
  %372 = load i32, ptr %163, align 4
  %373 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %372, i32 4, i32 31)
  store i32 %373, ptr %371, align 4
  %374 = getelementptr inbounds i32, ptr %4, i32 2
  %375 = load i32, ptr %167, align 4
  %376 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %375, i32 4, i32 31)
  store i32 %376, ptr %374, align 4
  %377 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %378 = load float, ptr %171, align 4
  %379 = extractvalue { float, float, float } %377, 0
  %380 = fadd contract float %378, %379
  %381 = call float @llvm.maxnum.f32(float %380, float 1.000000e+00)
  %382 = extractvalue { float, float, float } %377, 1
  %383 = load float, ptr %177, align 4
  %384 = fsub contract float %382, %383
  %385 = fdiv float %379, %381
  %386 = extractvalue { float, float, float } %377, 2
  %387 = load float, ptr %181, align 4
  %388 = fadd contract float %387, %386
  %389 = fmul contract float %384, %384
  %390 = fmul contract float %389, %378
  %391 = fmul contract float %390, %385
  %392 = fadd contract float %388, %391
  store float %392, ptr %181, align 4
  %393 = fmul contract float %384, %385
  %394 = load float, ptr %177, align 4
  %395 = fadd contract float %394, %393
  store float %395, ptr %177, align 4
  store float %380, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %396 = load i32, ptr %12, align 4
  %397 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %396, i32 2, i32 31)
  store i32 %397, ptr %3, align 4
  %398 = getelementptr inbounds i32, ptr %3, i32 1
  %399 = load i32, ptr %163, align 4
  %400 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %399, i32 2, i32 31)
  store i32 %400, ptr %398, align 4
  %401 = getelementptr inbounds i32, ptr %3, i32 2
  %402 = load i32, ptr %167, align 4
  %403 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %402, i32 2, i32 31)
  store i32 %403, ptr %401, align 4
  %404 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %405 = load float, ptr %171, align 4
  %406 = extractvalue { float, float, float } %404, 0
  %407 = fadd contract float %405, %406
  %408 = call float @llvm.maxnum.f32(float %407, float 1.000000e+00)
  %409 = extractvalue { float, float, float } %404, 1
  %410 = load float, ptr %177, align 4
  %411 = fsub contract float %409, %410
  %412 = fdiv float %406, %408
  %413 = extractvalue { float, float, float } %404, 2
  %414 = load float, ptr %181, align 4
  %415 = fadd contract float %414, %413
  %416 = fmul contract float %411, %411
  %417 = fmul contract float %416, %405
  %418 = fmul contract float %417, %412
  %419 = fadd contract float %415, %418
  store float %419, ptr %181, align 4
  %420 = fmul contract float %411, %412
  %421 = load float, ptr %177, align 4
  %422 = fadd contract float %421, %420
  store float %422, ptr %177, align 4
  store float %407, ptr %171, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %423 = load i32, ptr %12, align 4
  %424 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %423, i32 1, i32 31)
  store i32 %424, ptr %2, align 4
  %425 = getelementptr inbounds i32, ptr %2, i32 1
  %426 = load i32, ptr %163, align 4
  %427 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %426, i32 1, i32 31)
  store i32 %427, ptr %425, align 4
  %428 = getelementptr inbounds i32, ptr %2, i32 2
  %429 = load i32, ptr %167, align 4
  %430 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %429, i32 1, i32 31)
  store i32 %430, ptr %428, align 4
  %431 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %432 = load float, ptr %171, align 4
  %433 = extractvalue { float, float, float } %431, 0
  %434 = fadd contract float %432, %433
  %435 = call float @llvm.maxnum.f32(float %434, float 1.000000e+00)
  %436 = extractvalue { float, float, float } %431, 1
  %437 = load float, ptr %177, align 4
  %438 = fsub contract float %436, %437
  %439 = fdiv float %433, %435
  %440 = extractvalue { float, float, float } %431, 2
  %441 = load float, ptr %181, align 4
  %442 = fadd contract float %441, %440
  %443 = fmul contract float %438, %438
  %444 = fmul contract float %443, %432
  %445 = fmul contract float %444, %439
  %446 = fadd contract float %442, %445
  store float %446, ptr %181, align 4
  %447 = fmul contract float %438, %439
  %448 = load float, ptr %177, align 4
  %449 = fadd contract float %448, %447
  store float %449, ptr %177, align 4
  store float %434, ptr %171, align 4
  br i1 %25, label %450, label %452

450:                                              ; preds = %314
  %451 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %451, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70._global_alloc_0._gpu_shared_mem, align 4
  br label %453

452:                                              ; preds = %314
  br label %453

453:                                              ; preds = %452, %450
  br label %455

454:                                              ; preds = %308
  br label %455

455:                                              ; preds = %454, %453
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %456 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %456, ptr %12, align 4
  %457 = load float, ptr %177, align 4
  store float %457, ptr %177, align 4
  %458 = load float, ptr %181, align 4
  store float %458, ptr %181, align 4
  %459 = load float, ptr %171, align 4
  store float %459, ptr %171, align 4
  %460 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %461 = extractvalue { float, float, float } %460, 0
  %462 = extractvalue { float, float, float } %460, 1
  %463 = extractvalue { float, float, float } %460, 2
  %464 = fdiv float %463, %461
  %465 = fpext bfloat %68 to float
  %466 = fadd contract float %464, %465
  %467 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %466)
  %468 = load { ptr, { { i64 }, { {} } } }, ptr %14, align 8
  %469 = extractvalue { ptr, { { i64 }, { {} } } } %468, 0
  %470 = extractvalue { ptr, { { i64 }, { {} } } } %66, 0
  %471 = extractvalue { ptr, { { i64 }, { {} } } } %67, 0
  br label %472

472:                                              ; preds = %543, %455
  %473 = phi i64 [ 0, %455 ], [ %544, %543 ]
  %474 = phi i64 [ 0, %455 ], [ %483, %543 ]
  %475 = phi i64 [ 0, %455 ], [ %484, %543 ]
  %476 = add i64 %474, 128
  %477 = icmp slt i64 %476, %474
  %478 = select i1 %477, i64 1, i64 0
  %479 = icmp sge i64 %474, %65
  %480 = icmp eq i64 %475, 0
  %481 = xor i1 %480, true
  %482 = or i1 %481, %479
  %483 = select i1 %482, i64 %474, i64 %476
  %484 = select i1 %482, i64 %475, i64 %478
  br i1 %482, label %485, label %486

485:                                              ; preds = %472
  br label %545

486:                                              ; preds = %472
  br label %487

487:                                              ; preds = %486
  %488 = add i64 %474, %24
  %489 = getelementptr inbounds bfloat, ptr %469, i64 %488
  %490 = getelementptr inbounds bfloat, ptr %471, i64 %488
  %491 = getelementptr inbounds bfloat, ptr %470, i64 %488
  %492 = getelementptr inbounds bfloat, ptr %70, i64 %488
  %493 = sub i64 %65, %488
  %494 = call i64 @llvm.smin.i64(i64 %493, i64 1)
  %495 = call i64 @llvm.smax.i64(i64 %494, i64 0)
  %496 = icmp eq i64 %494, 1
  %497 = icmp slt i64 %488, %65
  br i1 %497, label %498, label %542

498:                                              ; preds = %487
  br i1 %496, label %499, label %511

499:                                              ; preds = %498
  %500 = load bfloat, ptr %492, align 2
  %501 = load bfloat, ptr %491, align 2, !invariant.load !1
  %502 = fpext bfloat %501 to float
  %503 = load bfloat, ptr %490, align 2, !invariant.load !1
  %504 = fpext bfloat %503 to float
  %505 = fpext bfloat %500 to float
  %506 = fsub contract float %505, %462
  %507 = fmul contract float %506, %467
  %508 = fmul contract float %507, %502
  %509 = fadd contract float %508, %504
  %510 = fptrunc float %509 to bfloat
  store bfloat %510, ptr %489, align 2
  br label %540

511:                                              ; preds = %498
  br label %512

512:                                              ; preds = %518, %511
  %513 = phi i64 [ 0, %511 ], [ %521, %518 ]
  %514 = phi i64 [ %473, %511 ], [ %522, %518 ]
  %515 = icmp slt i64 %513, %495
  br i1 %515, label %516, label %517

516:                                              ; preds = %512
  br label %518

517:                                              ; preds = %512
  br label %538

518:                                              ; preds = %516
  %519 = icmp eq i64 %513, %495
  %520 = add i64 %513, 1
  %521 = select i1 %519, i64 %513, i64 %520
  %522 = add i64 %488, %513
  %523 = getelementptr inbounds bfloat, ptr %70, i64 %522
  %524 = load bfloat, ptr %523, align 2
  %525 = getelementptr inbounds bfloat, ptr %470, i64 %522
  %526 = load bfloat, ptr %525, align 2, !invariant.load !1
  %527 = fpext bfloat %526 to float
  %528 = getelementptr inbounds bfloat, ptr %471, i64 %522
  %529 = load bfloat, ptr %528, align 2, !invariant.load !1
  %530 = fpext bfloat %529 to float
  %531 = fpext bfloat %524 to float
  %532 = fsub contract float %531, %462
  %533 = fmul contract float %532, %467
  %534 = fmul contract float %533, %527
  %535 = fadd contract float %534, %530
  %536 = fptrunc float %535 to bfloat
  %537 = getelementptr inbounds bfloat, ptr %469, i64 %522
  store bfloat %536, ptr %537, align 2
  br label %512

538:                                              ; preds = %517
  %539 = phi i64 [ %514, %517 ]
  br label %540

540:                                              ; preds = %538, %499
  %541 = phi i64 [ %539, %538 ], [ %488, %499 ]
  br label %543

542:                                              ; preds = %487
  br label %543

543:                                              ; preds = %542, %540
  %544 = phi i64 [ %473, %542 ], [ %541, %540 ]
  br label %472

545:                                              ; preds = %485
  br label %36

546:                                              ; preds = %62
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
