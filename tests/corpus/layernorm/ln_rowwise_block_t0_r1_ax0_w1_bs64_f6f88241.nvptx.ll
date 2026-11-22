; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r1_ax0_w1_bs64_f6f88241._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [2 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r1_ax0_w1_bs64_f6f88241(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %13 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, { i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 5
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 4
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 3
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 2
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 1
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } } }, ptr %13, i32 0, i32 0
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %21 = sext i32 %20 to i64
  %22 = icmp slt i64 %21, 2
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

36:                                               ; preds = %534, %1
  %37 = phi i64 [ %31, %1 ], [ %60, %534 ]
  %38 = phi i64 [ 0, %1 ], [ %61, %534 ]
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
  br label %535

63:                                               ; preds = %58
  br label %64

64:                                               ; preds = %63
  %65 = load i64, ptr %19, align 8
  %66 = load { ptr, { { i64 }, { {} } } }, ptr %18, align 8
  %67 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %68 = load float, ptr %16, align 4
  %69 = load { ptr, { { i64 }, { {} } } }, ptr %15, align 8
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
  %79 = add i64 %73, 64
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
  %91 = add i64 %73, %24
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
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } %157, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %158 = load i32, ptr %12, align 4
  %159 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %158, i32 16, i32 31)
  store i32 %159, ptr %11, align 4
  %160 = getelementptr inbounds i32, ptr %11, i32 1
  %161 = getelementptr inbounds i32, ptr %12, i32 1
  %162 = load i32, ptr %161, align 4
  %163 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %162, i32 16, i32 31)
  store i32 %163, ptr %160, align 4
  %164 = getelementptr inbounds i32, ptr %11, i32 2
  %165 = getelementptr inbounds i32, ptr %12, i32 2
  %166 = load i32, ptr %165, align 4
  %167 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %166, i32 16, i32 31)
  store i32 %167, ptr %164, align 4
  %168 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %169 = getelementptr { float, float, float }, ptr %12, i32 0, i32 0
  %170 = load float, ptr %169, align 4
  %171 = extractvalue { float, float, float } %168, 0
  %172 = fadd contract float %170, %171
  %173 = call float @llvm.maxnum.f32(float %172, float 1.000000e+00)
  %174 = extractvalue { float, float, float } %168, 1
  %175 = getelementptr { float, float, float }, ptr %12, i32 0, i32 1
  %176 = load float, ptr %175, align 4
  %177 = fsub contract float %174, %176
  %178 = fdiv float %171, %173
  %179 = getelementptr { float, float, float }, ptr %12, i32 0, i32 2
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
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %190 = load i32, ptr %12, align 4
  %191 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %190, i32 8, i32 31)
  store i32 %191, ptr %10, align 4
  %192 = getelementptr inbounds i32, ptr %10, i32 1
  %193 = load i32, ptr %161, align 4
  %194 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %193, i32 8, i32 31)
  store i32 %194, ptr %192, align 4
  %195 = getelementptr inbounds i32, ptr %10, i32 2
  %196 = load i32, ptr %165, align 4
  %197 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %196, i32 8, i32 31)
  store i32 %197, ptr %195, align 4
  %198 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
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
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %217 = load i32, ptr %12, align 4
  %218 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %217, i32 4, i32 31)
  store i32 %218, ptr %9, align 4
  %219 = getelementptr inbounds i32, ptr %9, i32 1
  %220 = load i32, ptr %161, align 4
  %221 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %220, i32 4, i32 31)
  store i32 %221, ptr %219, align 4
  %222 = getelementptr inbounds i32, ptr %9, i32 2
  %223 = load i32, ptr %165, align 4
  %224 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %223, i32 4, i32 31)
  store i32 %224, ptr %222, align 4
  %225 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
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
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %244 = load i32, ptr %12, align 4
  %245 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %244, i32 2, i32 31)
  store i32 %245, ptr %8, align 4
  %246 = getelementptr inbounds i32, ptr %8, i32 1
  %247 = load i32, ptr %161, align 4
  %248 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %247, i32 2, i32 31)
  store i32 %248, ptr %246, align 4
  %249 = getelementptr inbounds i32, ptr %8, i32 2
  %250 = load i32, ptr %165, align 4
  %251 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %250, i32 2, i32 31)
  store i32 %251, ptr %249, align 4
  %252 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
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
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %271 = load i32, ptr %12, align 4
  %272 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %271, i32 1, i32 31)
  store i32 %272, ptr %7, align 4
  %273 = getelementptr inbounds i32, ptr %7, i32 1
  %274 = load i32, ptr %161, align 4
  %275 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %274, i32 1, i32 31)
  store i32 %275, ptr %273, align 4
  %276 = getelementptr inbounds i32, ptr %7, i32 2
  %277 = load i32, ptr %165, align 4
  %278 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %277, i32 1, i32 31)
  store i32 %278, ptr %276, align 4
  %279 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
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
  %298 = udiv i64 %24, 32
  %299 = trunc i64 %298 to i32
  %300 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs64_f6f88241._global_alloc_0._gpu_shared_mem, i32 %299
  %301 = trunc i64 %21 to i32
  %302 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs64_f6f88241._global_alloc_0._gpu_shared_mem, i32 %301
  br i1 %25, label %303, label %305

303:                                              ; preds = %151
  %304 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %304, ptr addrspace(3) %300, align 4
  br label %306

305:                                              ; preds = %151
  br label %306

306:                                              ; preds = %305, %303
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %307 = icmp eq i64 %298, 0
  br i1 %307, label %308, label %452

308:                                              ; preds = %306
  br i1 %22, label %309, label %311

309:                                              ; preds = %308
  %310 = load { float, float, float }, ptr addrspace(3) %302, align 4
  store { float, float, float } %310, ptr %12, align 4
  br label %312

311:                                              ; preds = %308
  store { float, float, float } zeroinitializer, ptr %12, align 4
  br label %312

312:                                              ; preds = %311, %309
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %313 = load i32, ptr %12, align 4
  %314 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %313, i32 16, i32 31)
  store i32 %314, ptr %6, align 4
  %315 = getelementptr inbounds i32, ptr %6, i32 1
  %316 = load i32, ptr %161, align 4
  %317 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %316, i32 16, i32 31)
  store i32 %317, ptr %315, align 4
  %318 = getelementptr inbounds i32, ptr %6, i32 2
  %319 = load i32, ptr %165, align 4
  %320 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %319, i32 16, i32 31)
  store i32 %320, ptr %318, align 4
  %321 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %322 = load float, ptr %169, align 4
  %323 = extractvalue { float, float, float } %321, 0
  %324 = fadd contract float %322, %323
  %325 = call float @llvm.maxnum.f32(float %324, float 1.000000e+00)
  %326 = extractvalue { float, float, float } %321, 1
  %327 = load float, ptr %175, align 4
  %328 = fsub contract float %326, %327
  %329 = fdiv float %323, %325
  %330 = extractvalue { float, float, float } %321, 2
  %331 = load float, ptr %179, align 4
  %332 = fadd contract float %331, %330
  %333 = fmul contract float %328, %328
  %334 = fmul contract float %333, %322
  %335 = fmul contract float %334, %329
  %336 = fadd contract float %332, %335
  store float %336, ptr %179, align 4
  %337 = fmul contract float %328, %329
  %338 = load float, ptr %175, align 4
  %339 = fadd contract float %338, %337
  store float %339, ptr %175, align 4
  store float %324, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %340 = load i32, ptr %12, align 4
  %341 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %340, i32 8, i32 31)
  store i32 %341, ptr %5, align 4
  %342 = getelementptr inbounds i32, ptr %5, i32 1
  %343 = load i32, ptr %161, align 4
  %344 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %343, i32 8, i32 31)
  store i32 %344, ptr %342, align 4
  %345 = getelementptr inbounds i32, ptr %5, i32 2
  %346 = load i32, ptr %165, align 4
  %347 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %346, i32 8, i32 31)
  store i32 %347, ptr %345, align 4
  %348 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %349 = load float, ptr %169, align 4
  %350 = extractvalue { float, float, float } %348, 0
  %351 = fadd contract float %349, %350
  %352 = call float @llvm.maxnum.f32(float %351, float 1.000000e+00)
  %353 = extractvalue { float, float, float } %348, 1
  %354 = load float, ptr %175, align 4
  %355 = fsub contract float %353, %354
  %356 = fdiv float %350, %352
  %357 = extractvalue { float, float, float } %348, 2
  %358 = load float, ptr %179, align 4
  %359 = fadd contract float %358, %357
  %360 = fmul contract float %355, %355
  %361 = fmul contract float %360, %349
  %362 = fmul contract float %361, %356
  %363 = fadd contract float %359, %362
  store float %363, ptr %179, align 4
  %364 = fmul contract float %355, %356
  %365 = load float, ptr %175, align 4
  %366 = fadd contract float %365, %364
  store float %366, ptr %175, align 4
  store float %351, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %367 = load i32, ptr %12, align 4
  %368 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %367, i32 4, i32 31)
  store i32 %368, ptr %4, align 4
  %369 = getelementptr inbounds i32, ptr %4, i32 1
  %370 = load i32, ptr %161, align 4
  %371 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %370, i32 4, i32 31)
  store i32 %371, ptr %369, align 4
  %372 = getelementptr inbounds i32, ptr %4, i32 2
  %373 = load i32, ptr %165, align 4
  %374 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %373, i32 4, i32 31)
  store i32 %374, ptr %372, align 4
  %375 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %376 = load float, ptr %169, align 4
  %377 = extractvalue { float, float, float } %375, 0
  %378 = fadd contract float %376, %377
  %379 = call float @llvm.maxnum.f32(float %378, float 1.000000e+00)
  %380 = extractvalue { float, float, float } %375, 1
  %381 = load float, ptr %175, align 4
  %382 = fsub contract float %380, %381
  %383 = fdiv float %377, %379
  %384 = extractvalue { float, float, float } %375, 2
  %385 = load float, ptr %179, align 4
  %386 = fadd contract float %385, %384
  %387 = fmul contract float %382, %382
  %388 = fmul contract float %387, %376
  %389 = fmul contract float %388, %383
  %390 = fadd contract float %386, %389
  store float %390, ptr %179, align 4
  %391 = fmul contract float %382, %383
  %392 = load float, ptr %175, align 4
  %393 = fadd contract float %392, %391
  store float %393, ptr %175, align 4
  store float %378, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %394 = load i32, ptr %12, align 4
  %395 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %394, i32 2, i32 31)
  store i32 %395, ptr %3, align 4
  %396 = getelementptr inbounds i32, ptr %3, i32 1
  %397 = load i32, ptr %161, align 4
  %398 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %397, i32 2, i32 31)
  store i32 %398, ptr %396, align 4
  %399 = getelementptr inbounds i32, ptr %3, i32 2
  %400 = load i32, ptr %165, align 4
  %401 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %400, i32 2, i32 31)
  store i32 %401, ptr %399, align 4
  %402 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %403 = load float, ptr %169, align 4
  %404 = extractvalue { float, float, float } %402, 0
  %405 = fadd contract float %403, %404
  %406 = call float @llvm.maxnum.f32(float %405, float 1.000000e+00)
  %407 = extractvalue { float, float, float } %402, 1
  %408 = load float, ptr %175, align 4
  %409 = fsub contract float %407, %408
  %410 = fdiv float %404, %406
  %411 = extractvalue { float, float, float } %402, 2
  %412 = load float, ptr %179, align 4
  %413 = fadd contract float %412, %411
  %414 = fmul contract float %409, %409
  %415 = fmul contract float %414, %403
  %416 = fmul contract float %415, %410
  %417 = fadd contract float %413, %416
  store float %417, ptr %179, align 4
  %418 = fmul contract float %409, %410
  %419 = load float, ptr %175, align 4
  %420 = fadd contract float %419, %418
  store float %420, ptr %175, align 4
  store float %405, ptr %169, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %421 = load i32, ptr %12, align 4
  %422 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %421, i32 1, i32 31)
  store i32 %422, ptr %2, align 4
  %423 = getelementptr inbounds i32, ptr %2, i32 1
  %424 = load i32, ptr %161, align 4
  %425 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %424, i32 1, i32 31)
  store i32 %425, ptr %423, align 4
  %426 = getelementptr inbounds i32, ptr %2, i32 2
  %427 = load i32, ptr %165, align 4
  %428 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %427, i32 1, i32 31)
  store i32 %428, ptr %426, align 4
  %429 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %430 = load float, ptr %169, align 4
  %431 = extractvalue { float, float, float } %429, 0
  %432 = fadd contract float %430, %431
  %433 = call float @llvm.maxnum.f32(float %432, float 1.000000e+00)
  %434 = extractvalue { float, float, float } %429, 1
  %435 = load float, ptr %175, align 4
  %436 = fsub contract float %434, %435
  %437 = fdiv float %431, %433
  %438 = extractvalue { float, float, float } %429, 2
  %439 = load float, ptr %179, align 4
  %440 = fadd contract float %439, %438
  %441 = fmul contract float %436, %436
  %442 = fmul contract float %441, %430
  %443 = fmul contract float %442, %437
  %444 = fadd contract float %440, %443
  store float %444, ptr %179, align 4
  %445 = fmul contract float %436, %437
  %446 = load float, ptr %175, align 4
  %447 = fadd contract float %446, %445
  store float %447, ptr %175, align 4
  store float %432, ptr %169, align 4
  br i1 %25, label %448, label %450

448:                                              ; preds = %312
  %449 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %449, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs64_f6f88241._global_alloc_0._gpu_shared_mem, align 4
  br label %451

450:                                              ; preds = %312
  br label %451

451:                                              ; preds = %450, %448
  br label %453

452:                                              ; preds = %306
  br label %453

453:                                              ; preds = %452, %451
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %454 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r1_ax0_w1_bs64_f6f88241._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %454, ptr %12, align 4
  %455 = load float, ptr %175, align 4
  store float %455, ptr %175, align 4
  %456 = load float, ptr %179, align 4
  store float %456, ptr %179, align 4
  %457 = load float, ptr %169, align 4
  store float %457, ptr %169, align 4
  %458 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %459 = extractvalue { float, float, float } %458, 0
  %460 = extractvalue { float, float, float } %458, 1
  %461 = extractvalue { float, float, float } %458, 2
  %462 = fdiv float %461, %459
  %463 = fadd contract float %462, %68
  %464 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %463)
  %465 = load { ptr, { { i64 }, { {} } } }, ptr %14, align 8
  %466 = extractvalue { ptr, { { i64 }, { {} } } } %465, 0
  %467 = extractvalue { ptr, { { i64 }, { {} } } } %66, 0
  %468 = extractvalue { ptr, { { i64 }, { {} } } } %67, 0
  br label %469

469:                                              ; preds = %532, %453
  %470 = phi i64 [ 0, %453 ], [ %533, %532 ]
  %471 = phi i64 [ 0, %453 ], [ %480, %532 ]
  %472 = phi i64 [ 0, %453 ], [ %481, %532 ]
  %473 = add i64 %471, 64
  %474 = icmp slt i64 %473, %471
  %475 = select i1 %474, i64 1, i64 0
  %476 = icmp sge i64 %471, %65
  %477 = icmp eq i64 %472, 0
  %478 = xor i1 %477, true
  %479 = or i1 %478, %476
  %480 = select i1 %479, i64 %471, i64 %473
  %481 = select i1 %479, i64 %472, i64 %475
  br i1 %479, label %482, label %483

482:                                              ; preds = %469
  br label %534

483:                                              ; preds = %469
  br label %484

484:                                              ; preds = %483
  %485 = add i64 %471, %24
  %486 = getelementptr inbounds float, ptr %466, i64 %485
  %487 = getelementptr inbounds float, ptr %468, i64 %485
  %488 = getelementptr inbounds float, ptr %467, i64 %485
  %489 = getelementptr inbounds float, ptr %70, i64 %485
  %490 = sub i64 %65, %485
  %491 = call i64 @llvm.smin.i64(i64 %490, i64 1)
  %492 = call i64 @llvm.smax.i64(i64 %491, i64 0)
  %493 = icmp eq i64 %491, 1
  %494 = icmp slt i64 %485, %65
  br i1 %494, label %495, label %531

495:                                              ; preds = %484
  br i1 %493, label %496, label %504

496:                                              ; preds = %495
  %497 = load float, ptr %489, align 4
  %498 = load float, ptr %488, align 4, !invariant.load !1
  %499 = load float, ptr %487, align 4, !invariant.load !1
  %500 = fsub contract float %497, %460
  %501 = fmul contract float %500, %464
  %502 = fmul contract float %501, %498
  %503 = fadd contract float %502, %499
  store float %503, ptr %486, align 4
  br label %529

504:                                              ; preds = %495
  br label %505

505:                                              ; preds = %511, %504
  %506 = phi i64 [ 0, %504 ], [ %514, %511 ]
  %507 = phi i64 [ %470, %504 ], [ %515, %511 ]
  %508 = icmp slt i64 %506, %492
  br i1 %508, label %509, label %510

509:                                              ; preds = %505
  br label %511

510:                                              ; preds = %505
  br label %527

511:                                              ; preds = %509
  %512 = icmp eq i64 %506, %492
  %513 = add i64 %506, 1
  %514 = select i1 %512, i64 %506, i64 %513
  %515 = add i64 %485, %506
  %516 = getelementptr inbounds float, ptr %70, i64 %515
  %517 = load float, ptr %516, align 4
  %518 = getelementptr inbounds float, ptr %467, i64 %515
  %519 = load float, ptr %518, align 4, !invariant.load !1
  %520 = getelementptr inbounds float, ptr %468, i64 %515
  %521 = load float, ptr %520, align 4, !invariant.load !1
  %522 = fsub contract float %517, %460
  %523 = fmul contract float %522, %464
  %524 = fmul contract float %523, %519
  %525 = fadd contract float %524, %521
  %526 = getelementptr inbounds float, ptr %466, i64 %515
  store float %525, ptr %526, align 4
  br label %505

527:                                              ; preds = %510
  %528 = phi i64 [ %507, %510 ]
  br label %529

529:                                              ; preds = %527, %496
  %530 = phi i64 [ %528, %527 ], [ %485, %496 ]
  br label %532

531:                                              ; preds = %484
  br label %532

532:                                              ; preds = %531, %529
  %533 = phi i64 [ %470, %531 ], [ %530, %529 ]
  br label %469

534:                                              ; preds = %482
  br label %36

535:                                              ; preds = %62
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

attributes #0 = { convergent norecurse "nvvm.maxntid"="64" "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #5 = { convergent nocallback nounwind }
attributes #6 = { nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
