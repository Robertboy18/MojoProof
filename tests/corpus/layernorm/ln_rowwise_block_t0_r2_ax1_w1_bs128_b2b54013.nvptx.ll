; ModuleID = 'test_layer_norm.mojo'
source_filename = "test_layer_norm.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@rowwise_block_t0_r2_ax1_w1_bs128_b2b54013._global_alloc_0._gpu_shared_mem = internal addrspace(3) global [4 x { float, float, float }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @rowwise_block_t0_r2_ax1_w1_bs128_b2b54013(ptr noundef nonnull readonly byval({ { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }) %0) #0 {
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
  %13 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 0
  %14 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %13, i32 0, i32 5
  %15 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %13, i32 0, i32 4
  %16 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %13, i32 0, i32 3
  %17 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %13, i32 0, i32 2
  %18 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %13, i32 0, i32 1
  %19 = getelementptr { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, ptr %13, i32 0, i32 0
  %20 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %21 = sext i32 %20 to i64
  %22 = icmp slt i64 %21, 4
  %23 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %24 = zext i32 %23 to i64
  %25 = icmp eq i64 %21, 0
  %26 = getelementptr { { i64, { ptr, { { i64 }, { {} } } }, { ptr, { { i64 }, { {} } } }, float, { ptr, { { i64, i64 }, { i64, {} } } }, { ptr, { { i64, i64 }, { i64, {} } } } }, { i64, i64 }, [0 x { i32, i32, i8, i8, i1, i8 }] }, ptr %0, i32 0, i32 1
  %27 = load { i64, i64 }, ptr %26, align 8
  %28 = extractvalue { i64, i64 } %27, 0
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %32 = sext i32 %31 to i64
  %33 = icmp eq i64 %32, 0
  %34 = select i1 %33, i64 0, i64 %30
  %35 = select i1 %33, i64 0, i64 %28
  %36 = select i1 %33, i64 1, i64 %32
  %37 = icmp slt i64 %36, 0
  %38 = icmp sgt i64 %36, 0
  br label %39

39:                                               ; preds = %548, %1
  %40 = phi i64 [ %34, %1 ], [ %64, %548 ]
  %41 = phi i64 [ 0, %1 ], [ %65, %548 ]
  %42 = icmp sge i64 %35, %40
  %43 = icmp sge i64 %40, %35
  %44 = add i64 %40, %36
  %45 = icmp slt i64 %44, %40
  %46 = xor i1 %45, %37
  %47 = select i1 %46, i64 1, i64 0
  %48 = icmp eq i64 %41, 0
  %49 = xor i1 %48, true
  %50 = or i1 %49, %42
  %51 = or i1 %49, %43
  br label %52

52:                                               ; preds = %39
  br i1 %38, label %53, label %58

53:                                               ; preds = %52
  br i1 %51, label %54, label %55

54:                                               ; preds = %53
  br label %61

55:                                               ; preds = %53
  br label %56

56:                                               ; preds = %55
  br label %60

57:                                               ; preds = %58
  br label %60

58:                                               ; preds = %52
  br i1 %50, label %59, label %57

59:                                               ; preds = %58
  br label %61

60:                                               ; preds = %57, %56
  br label %61

61:                                               ; preds = %60, %59, %54
  %62 = phi i1 [ true, %54 ], [ true, %59 ], [ false, %60 ]
  %63 = phi i64 [ undef, %54 ], [ undef, %59 ], [ %40, %60 ]
  %64 = phi i64 [ %40, %54 ], [ %40, %59 ], [ %44, %60 ]
  %65 = phi i64 [ %41, %54 ], [ %41, %59 ], [ %47, %60 ]
  br i1 %62, label %66, label %67

66:                                               ; preds = %61
  br label %549

67:                                               ; preds = %61
  br label %68

68:                                               ; preds = %67
  %69 = load i64, ptr %19, align 8
  %70 = load { ptr, { { i64 }, { {} } } }, ptr %18, align 8
  %71 = load { ptr, { { i64 }, { {} } } }, ptr %17, align 8
  %72 = load float, ptr %16, align 4
  %73 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %15, align 8
  %74 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %73, 0
  %75 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %73, 1, 1, 0
  %76 = mul i64 %63, %75
  br label %77

77:                                               ; preds = %154, %68
  %78 = phi i64 [ 0, %68 ], [ %155, %154 ]
  %79 = phi i64 [ 0, %68 ], [ %92, %154 ]
  %80 = phi i64 [ 0, %68 ], [ %93, %154 ]
  %81 = phi float [ 0.000000e+00, %68 ], [ %156, %154 ]
  %82 = phi float [ 0.000000e+00, %68 ], [ %157, %154 ]
  %83 = phi float [ 0.000000e+00, %68 ], [ %158, %154 ]
  %84 = fadd contract float %81, 1.000000e+00
  %85 = add i64 %79, 128
  %86 = icmp slt i64 %85, %79
  %87 = select i1 %86, i64 1, i64 0
  %88 = icmp sge i64 %79, %69
  %89 = icmp eq i64 %80, 0
  %90 = xor i1 %89, true
  %91 = or i1 %90, %88
  %92 = select i1 %91, i64 %79, i64 %85
  %93 = select i1 %91, i64 %80, i64 %87
  br i1 %91, label %94, label %95

94:                                               ; preds = %77
  br label %159

95:                                               ; preds = %77
  br label %96

96:                                               ; preds = %95
  %97 = add i64 %79, %24
  %98 = add i64 %76, %97
  %99 = getelementptr inbounds float, ptr %74, i64 %98
  %100 = sub i64 %69, %97
  %101 = call i64 @llvm.smin.i64(i64 %100, i64 1)
  %102 = call i64 @llvm.smax.i64(i64 %101, i64 0)
  %103 = icmp eq i64 %101, 1
  %104 = icmp slt i64 %97, %69
  br i1 %104, label %105, label %153

105:                                              ; preds = %96
  br i1 %103, label %106, label %116

106:                                              ; preds = %105
  %107 = load float, ptr %99, align 4
  %108 = fsub contract float %107, %82
  %109 = fdiv float 1.000000e+00, %84
  %110 = fmul contract float %108, %109
  %111 = fadd contract float %82, %110
  %112 = fmul contract float %108, %108
  %113 = fmul contract float %112, %81
  %114 = fmul contract float %113, %109
  %115 = fadd contract float %83, %114
  br label %148

116:                                              ; preds = %105
  br label %117

117:                                              ; preds = %126, %116
  %118 = phi i64 [ 0, %116 ], [ %129, %126 ]
  %119 = phi i64 [ %78, %116 ], [ %130, %126 ]
  %120 = phi float [ %81, %116 ], [ %134, %126 ]
  %121 = phi float [ %82, %116 ], [ %138, %126 ]
  %122 = phi float [ %83, %116 ], [ %142, %126 ]
  %123 = icmp slt i64 %118, %102
  br i1 %123, label %124, label %125

124:                                              ; preds = %117
  br label %126

125:                                              ; preds = %117
  br label %143

126:                                              ; preds = %124
  %127 = icmp eq i64 %118, %102
  %128 = add i64 %118, 1
  %129 = select i1 %127, i64 %118, i64 %128
  %130 = add i64 %97, %118
  %131 = add i64 %76, %130
  %132 = getelementptr inbounds float, ptr %74, i64 %131
  %133 = load float, ptr %132, align 4
  %134 = fadd contract float %120, 1.000000e+00
  %135 = fsub contract float %133, %121
  %136 = fdiv float 1.000000e+00, %134
  %137 = fmul contract float %135, %136
  %138 = fadd contract float %121, %137
  %139 = fmul contract float %135, %135
  %140 = fmul contract float %139, %120
  %141 = fmul contract float %140, %136
  %142 = fadd contract float %122, %141
  br label %117

143:                                              ; preds = %125
  %144 = phi i64 [ %119, %125 ]
  %145 = phi float [ %120, %125 ]
  %146 = phi float [ %121, %125 ]
  %147 = phi float [ %122, %125 ]
  br label %148

148:                                              ; preds = %143, %106
  %149 = phi i64 [ %144, %143 ], [ %97, %106 ]
  %150 = phi float [ %145, %143 ], [ %84, %106 ]
  %151 = phi float [ %146, %143 ], [ %111, %106 ]
  %152 = phi float [ %147, %143 ], [ %115, %106 ]
  br label %154

153:                                              ; preds = %96
  br label %154

154:                                              ; preds = %153, %148
  %155 = phi i64 [ %78, %153 ], [ %149, %148 ]
  %156 = phi float [ %81, %153 ], [ %150, %148 ]
  %157 = phi float [ %82, %153 ], [ %151, %148 ]
  %158 = phi float [ %83, %153 ], [ %152, %148 ]
  br label %77

159:                                              ; preds = %94
  %160 = phi float [ %81, %94 ]
  %161 = phi float [ %82, %94 ]
  %162 = phi float [ %83, %94 ]
  %163 = insertvalue { float, float, float } undef, float %160, 0
  %164 = insertvalue { float, float, float } %163, float %161, 1
  %165 = insertvalue { float, float, float } %164, float %162, 2
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store { float, float, float } %165, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store { float, float, float } zeroinitializer, ptr %11, align 4
  %166 = load i32, ptr %12, align 4
  %167 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %166, i32 16, i32 31)
  store i32 %167, ptr %11, align 4
  %168 = getelementptr inbounds i32, ptr %11, i32 1
  %169 = getelementptr inbounds i32, ptr %12, i32 1
  %170 = load i32, ptr %169, align 4
  %171 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %170, i32 16, i32 31)
  store i32 %171, ptr %168, align 4
  %172 = getelementptr inbounds i32, ptr %11, i32 2
  %173 = getelementptr inbounds i32, ptr %12, i32 2
  %174 = load i32, ptr %173, align 4
  %175 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %174, i32 16, i32 31)
  store i32 %175, ptr %172, align 4
  %176 = load { float, float, float }, ptr %11, align 4
  call void @llvm.lifetime.end.p0(ptr %11)
  %177 = getelementptr { float, float, float }, ptr %12, i32 0, i32 0
  %178 = load float, ptr %177, align 4
  %179 = extractvalue { float, float, float } %176, 0
  %180 = fadd contract float %178, %179
  %181 = call float @llvm.maxnum.f32(float %180, float 1.000000e+00)
  %182 = extractvalue { float, float, float } %176, 1
  %183 = getelementptr { float, float, float }, ptr %12, i32 0, i32 1
  %184 = load float, ptr %183, align 4
  %185 = fsub contract float %182, %184
  %186 = fdiv float %179, %181
  %187 = getelementptr { float, float, float }, ptr %12, i32 0, i32 2
  %188 = extractvalue { float, float, float } %176, 2
  %189 = load float, ptr %187, align 4
  %190 = fadd contract float %189, %188
  %191 = fmul contract float %185, %185
  %192 = fmul contract float %191, %178
  %193 = fmul contract float %192, %186
  %194 = fadd contract float %190, %193
  store float %194, ptr %187, align 4
  %195 = fmul contract float %185, %186
  %196 = load float, ptr %183, align 4
  %197 = fadd contract float %196, %195
  store float %197, ptr %183, align 4
  store float %180, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store { float, float, float } zeroinitializer, ptr %10, align 4
  %198 = load i32, ptr %12, align 4
  %199 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %198, i32 8, i32 31)
  store i32 %199, ptr %10, align 4
  %200 = getelementptr inbounds i32, ptr %10, i32 1
  %201 = load i32, ptr %169, align 4
  %202 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %201, i32 8, i32 31)
  store i32 %202, ptr %200, align 4
  %203 = getelementptr inbounds i32, ptr %10, i32 2
  %204 = load i32, ptr %173, align 4
  %205 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %204, i32 8, i32 31)
  store i32 %205, ptr %203, align 4
  %206 = load { float, float, float }, ptr %10, align 4
  call void @llvm.lifetime.end.p0(ptr %10)
  %207 = load float, ptr %177, align 4
  %208 = extractvalue { float, float, float } %206, 0
  %209 = fadd contract float %207, %208
  %210 = call float @llvm.maxnum.f32(float %209, float 1.000000e+00)
  %211 = extractvalue { float, float, float } %206, 1
  %212 = load float, ptr %183, align 4
  %213 = fsub contract float %211, %212
  %214 = fdiv float %208, %210
  %215 = extractvalue { float, float, float } %206, 2
  %216 = load float, ptr %187, align 4
  %217 = fadd contract float %216, %215
  %218 = fmul contract float %213, %213
  %219 = fmul contract float %218, %207
  %220 = fmul contract float %219, %214
  %221 = fadd contract float %217, %220
  store float %221, ptr %187, align 4
  %222 = fmul contract float %213, %214
  %223 = load float, ptr %183, align 4
  %224 = fadd contract float %223, %222
  store float %224, ptr %183, align 4
  store float %209, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store { float, float, float } zeroinitializer, ptr %9, align 4
  %225 = load i32, ptr %12, align 4
  %226 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %225, i32 4, i32 31)
  store i32 %226, ptr %9, align 4
  %227 = getelementptr inbounds i32, ptr %9, i32 1
  %228 = load i32, ptr %169, align 4
  %229 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %228, i32 4, i32 31)
  store i32 %229, ptr %227, align 4
  %230 = getelementptr inbounds i32, ptr %9, i32 2
  %231 = load i32, ptr %173, align 4
  %232 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %231, i32 4, i32 31)
  store i32 %232, ptr %230, align 4
  %233 = load { float, float, float }, ptr %9, align 4
  call void @llvm.lifetime.end.p0(ptr %9)
  %234 = load float, ptr %177, align 4
  %235 = extractvalue { float, float, float } %233, 0
  %236 = fadd contract float %234, %235
  %237 = call float @llvm.maxnum.f32(float %236, float 1.000000e+00)
  %238 = extractvalue { float, float, float } %233, 1
  %239 = load float, ptr %183, align 4
  %240 = fsub contract float %238, %239
  %241 = fdiv float %235, %237
  %242 = extractvalue { float, float, float } %233, 2
  %243 = load float, ptr %187, align 4
  %244 = fadd contract float %243, %242
  %245 = fmul contract float %240, %240
  %246 = fmul contract float %245, %234
  %247 = fmul contract float %246, %241
  %248 = fadd contract float %244, %247
  store float %248, ptr %187, align 4
  %249 = fmul contract float %240, %241
  %250 = load float, ptr %183, align 4
  %251 = fadd contract float %250, %249
  store float %251, ptr %183, align 4
  store float %236, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store { float, float, float } zeroinitializer, ptr %8, align 4
  %252 = load i32, ptr %12, align 4
  %253 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %252, i32 2, i32 31)
  store i32 %253, ptr %8, align 4
  %254 = getelementptr inbounds i32, ptr %8, i32 1
  %255 = load i32, ptr %169, align 4
  %256 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %255, i32 2, i32 31)
  store i32 %256, ptr %254, align 4
  %257 = getelementptr inbounds i32, ptr %8, i32 2
  %258 = load i32, ptr %173, align 4
  %259 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %258, i32 2, i32 31)
  store i32 %259, ptr %257, align 4
  %260 = load { float, float, float }, ptr %8, align 4
  call void @llvm.lifetime.end.p0(ptr %8)
  %261 = load float, ptr %177, align 4
  %262 = extractvalue { float, float, float } %260, 0
  %263 = fadd contract float %261, %262
  %264 = call float @llvm.maxnum.f32(float %263, float 1.000000e+00)
  %265 = extractvalue { float, float, float } %260, 1
  %266 = load float, ptr %183, align 4
  %267 = fsub contract float %265, %266
  %268 = fdiv float %262, %264
  %269 = extractvalue { float, float, float } %260, 2
  %270 = load float, ptr %187, align 4
  %271 = fadd contract float %270, %269
  %272 = fmul contract float %267, %267
  %273 = fmul contract float %272, %261
  %274 = fmul contract float %273, %268
  %275 = fadd contract float %271, %274
  store float %275, ptr %187, align 4
  %276 = fmul contract float %267, %268
  %277 = load float, ptr %183, align 4
  %278 = fadd contract float %277, %276
  store float %278, ptr %183, align 4
  store float %263, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.start.p0(ptr %7)
  store { float, float, float } zeroinitializer, ptr %7, align 4
  %279 = load i32, ptr %12, align 4
  %280 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %279, i32 1, i32 31)
  store i32 %280, ptr %7, align 4
  %281 = getelementptr inbounds i32, ptr %7, i32 1
  %282 = load i32, ptr %169, align 4
  %283 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %282, i32 1, i32 31)
  store i32 %283, ptr %281, align 4
  %284 = getelementptr inbounds i32, ptr %7, i32 2
  %285 = load i32, ptr %173, align 4
  %286 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %285, i32 1, i32 31)
  store i32 %286, ptr %284, align 4
  %287 = load { float, float, float }, ptr %7, align 4
  call void @llvm.lifetime.end.p0(ptr %7)
  %288 = load float, ptr %177, align 4
  %289 = extractvalue { float, float, float } %287, 0
  %290 = fadd contract float %288, %289
  %291 = call float @llvm.maxnum.f32(float %290, float 1.000000e+00)
  %292 = extractvalue { float, float, float } %287, 1
  %293 = load float, ptr %183, align 4
  %294 = fsub contract float %292, %293
  %295 = fdiv float %289, %291
  %296 = extractvalue { float, float, float } %287, 2
  %297 = load float, ptr %187, align 4
  %298 = fadd contract float %297, %296
  %299 = fmul contract float %294, %294
  %300 = fmul contract float %299, %288
  %301 = fmul contract float %300, %295
  %302 = fadd contract float %298, %301
  store float %302, ptr %187, align 4
  %303 = fmul contract float %294, %295
  %304 = load float, ptr %183, align 4
  %305 = fadd contract float %304, %303
  store float %305, ptr %183, align 4
  store float %290, ptr %177, align 4
  %306 = udiv i64 %24, 32
  %307 = trunc i64 %306 to i32
  %308 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w1_bs128_b2b54013._global_alloc_0._gpu_shared_mem, i32 %307
  %309 = trunc i64 %21 to i32
  %310 = getelementptr inbounds { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w1_bs128_b2b54013._global_alloc_0._gpu_shared_mem, i32 %309
  br i1 %25, label %311, label %313

311:                                              ; preds = %159
  %312 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %312, ptr addrspace(3) %308, align 4
  br label %314

313:                                              ; preds = %159
  br label %314

314:                                              ; preds = %313, %311
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %315 = icmp eq i64 %306, 0
  br i1 %315, label %316, label %460

316:                                              ; preds = %314
  br i1 %22, label %317, label %319

317:                                              ; preds = %316
  %318 = load { float, float, float }, ptr addrspace(3) %310, align 4
  store { float, float, float } %318, ptr %12, align 4
  br label %320

319:                                              ; preds = %316
  store { float, float, float } zeroinitializer, ptr %12, align 4
  br label %320

320:                                              ; preds = %319, %317
  call void @llvm.lifetime.end.p0(ptr %6)
  call void @llvm.lifetime.start.p0(ptr %6)
  store { float, float, float } zeroinitializer, ptr %6, align 4
  %321 = load i32, ptr %12, align 4
  %322 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %321, i32 16, i32 31)
  store i32 %322, ptr %6, align 4
  %323 = getelementptr inbounds i32, ptr %6, i32 1
  %324 = load i32, ptr %169, align 4
  %325 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %324, i32 16, i32 31)
  store i32 %325, ptr %323, align 4
  %326 = getelementptr inbounds i32, ptr %6, i32 2
  %327 = load i32, ptr %173, align 4
  %328 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %327, i32 16, i32 31)
  store i32 %328, ptr %326, align 4
  %329 = load { float, float, float }, ptr %6, align 4
  call void @llvm.lifetime.end.p0(ptr %6)
  %330 = load float, ptr %177, align 4
  %331 = extractvalue { float, float, float } %329, 0
  %332 = fadd contract float %330, %331
  %333 = call float @llvm.maxnum.f32(float %332, float 1.000000e+00)
  %334 = extractvalue { float, float, float } %329, 1
  %335 = load float, ptr %183, align 4
  %336 = fsub contract float %334, %335
  %337 = fdiv float %331, %333
  %338 = extractvalue { float, float, float } %329, 2
  %339 = load float, ptr %187, align 4
  %340 = fadd contract float %339, %338
  %341 = fmul contract float %336, %336
  %342 = fmul contract float %341, %330
  %343 = fmul contract float %342, %337
  %344 = fadd contract float %340, %343
  store float %344, ptr %187, align 4
  %345 = fmul contract float %336, %337
  %346 = load float, ptr %183, align 4
  %347 = fadd contract float %346, %345
  store float %347, ptr %183, align 4
  store float %332, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  call void @llvm.lifetime.start.p0(ptr %5)
  store { float, float, float } zeroinitializer, ptr %5, align 4
  %348 = load i32, ptr %12, align 4
  %349 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %348, i32 8, i32 31)
  store i32 %349, ptr %5, align 4
  %350 = getelementptr inbounds i32, ptr %5, i32 1
  %351 = load i32, ptr %169, align 4
  %352 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %351, i32 8, i32 31)
  store i32 %352, ptr %350, align 4
  %353 = getelementptr inbounds i32, ptr %5, i32 2
  %354 = load i32, ptr %173, align 4
  %355 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %354, i32 8, i32 31)
  store i32 %355, ptr %353, align 4
  %356 = load { float, float, float }, ptr %5, align 4
  call void @llvm.lifetime.end.p0(ptr %5)
  %357 = load float, ptr %177, align 4
  %358 = extractvalue { float, float, float } %356, 0
  %359 = fadd contract float %357, %358
  %360 = call float @llvm.maxnum.f32(float %359, float 1.000000e+00)
  %361 = extractvalue { float, float, float } %356, 1
  %362 = load float, ptr %183, align 4
  %363 = fsub contract float %361, %362
  %364 = fdiv float %358, %360
  %365 = extractvalue { float, float, float } %356, 2
  %366 = load float, ptr %187, align 4
  %367 = fadd contract float %366, %365
  %368 = fmul contract float %363, %363
  %369 = fmul contract float %368, %357
  %370 = fmul contract float %369, %364
  %371 = fadd contract float %367, %370
  store float %371, ptr %187, align 4
  %372 = fmul contract float %363, %364
  %373 = load float, ptr %183, align 4
  %374 = fadd contract float %373, %372
  store float %374, ptr %183, align 4
  store float %359, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  call void @llvm.lifetime.start.p0(ptr %4)
  store { float, float, float } zeroinitializer, ptr %4, align 4
  %375 = load i32, ptr %12, align 4
  %376 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %375, i32 4, i32 31)
  store i32 %376, ptr %4, align 4
  %377 = getelementptr inbounds i32, ptr %4, i32 1
  %378 = load i32, ptr %169, align 4
  %379 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %378, i32 4, i32 31)
  store i32 %379, ptr %377, align 4
  %380 = getelementptr inbounds i32, ptr %4, i32 2
  %381 = load i32, ptr %173, align 4
  %382 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %381, i32 4, i32 31)
  store i32 %382, ptr %380, align 4
  %383 = load { float, float, float }, ptr %4, align 4
  call void @llvm.lifetime.end.p0(ptr %4)
  %384 = load float, ptr %177, align 4
  %385 = extractvalue { float, float, float } %383, 0
  %386 = fadd contract float %384, %385
  %387 = call float @llvm.maxnum.f32(float %386, float 1.000000e+00)
  %388 = extractvalue { float, float, float } %383, 1
  %389 = load float, ptr %183, align 4
  %390 = fsub contract float %388, %389
  %391 = fdiv float %385, %387
  %392 = extractvalue { float, float, float } %383, 2
  %393 = load float, ptr %187, align 4
  %394 = fadd contract float %393, %392
  %395 = fmul contract float %390, %390
  %396 = fmul contract float %395, %384
  %397 = fmul contract float %396, %391
  %398 = fadd contract float %394, %397
  store float %398, ptr %187, align 4
  %399 = fmul contract float %390, %391
  %400 = load float, ptr %183, align 4
  %401 = fadd contract float %400, %399
  store float %401, ptr %183, align 4
  store float %386, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  call void @llvm.lifetime.start.p0(ptr %3)
  store { float, float, float } zeroinitializer, ptr %3, align 4
  %402 = load i32, ptr %12, align 4
  %403 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %402, i32 2, i32 31)
  store i32 %403, ptr %3, align 4
  %404 = getelementptr inbounds i32, ptr %3, i32 1
  %405 = load i32, ptr %169, align 4
  %406 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %405, i32 2, i32 31)
  store i32 %406, ptr %404, align 4
  %407 = getelementptr inbounds i32, ptr %3, i32 2
  %408 = load i32, ptr %173, align 4
  %409 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %408, i32 2, i32 31)
  store i32 %409, ptr %407, align 4
  %410 = load { float, float, float }, ptr %3, align 4
  call void @llvm.lifetime.end.p0(ptr %3)
  %411 = load float, ptr %177, align 4
  %412 = extractvalue { float, float, float } %410, 0
  %413 = fadd contract float %411, %412
  %414 = call float @llvm.maxnum.f32(float %413, float 1.000000e+00)
  %415 = extractvalue { float, float, float } %410, 1
  %416 = load float, ptr %183, align 4
  %417 = fsub contract float %415, %416
  %418 = fdiv float %412, %414
  %419 = extractvalue { float, float, float } %410, 2
  %420 = load float, ptr %187, align 4
  %421 = fadd contract float %420, %419
  %422 = fmul contract float %417, %417
  %423 = fmul contract float %422, %411
  %424 = fmul contract float %423, %418
  %425 = fadd contract float %421, %424
  store float %425, ptr %187, align 4
  %426 = fmul contract float %417, %418
  %427 = load float, ptr %183, align 4
  %428 = fadd contract float %427, %426
  store float %428, ptr %183, align 4
  store float %413, ptr %177, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  call void @llvm.lifetime.start.p0(ptr %2)
  store { float, float, float } zeroinitializer, ptr %2, align 4
  %429 = load i32, ptr %12, align 4
  %430 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %429, i32 1, i32 31)
  store i32 %430, ptr %2, align 4
  %431 = getelementptr inbounds i32, ptr %2, i32 1
  %432 = load i32, ptr %169, align 4
  %433 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %432, i32 1, i32 31)
  store i32 %433, ptr %431, align 4
  %434 = getelementptr inbounds i32, ptr %2, i32 2
  %435 = load i32, ptr %173, align 4
  %436 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %435, i32 1, i32 31)
  store i32 %436, ptr %434, align 4
  %437 = load { float, float, float }, ptr %2, align 4
  call void @llvm.lifetime.end.p0(ptr %2)
  %438 = load float, ptr %177, align 4
  %439 = extractvalue { float, float, float } %437, 0
  %440 = fadd contract float %438, %439
  %441 = call float @llvm.maxnum.f32(float %440, float 1.000000e+00)
  %442 = extractvalue { float, float, float } %437, 1
  %443 = load float, ptr %183, align 4
  %444 = fsub contract float %442, %443
  %445 = fdiv float %439, %441
  %446 = extractvalue { float, float, float } %437, 2
  %447 = load float, ptr %187, align 4
  %448 = fadd contract float %447, %446
  %449 = fmul contract float %444, %444
  %450 = fmul contract float %449, %438
  %451 = fmul contract float %450, %445
  %452 = fadd contract float %448, %451
  store float %452, ptr %187, align 4
  %453 = fmul contract float %444, %445
  %454 = load float, ptr %183, align 4
  %455 = fadd contract float %454, %453
  store float %455, ptr %183, align 4
  store float %440, ptr %177, align 4
  br i1 %25, label %456, label %458

456:                                              ; preds = %320
  %457 = load { float, float, float }, ptr %12, align 4
  store { float, float, float } %457, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w1_bs128_b2b54013._global_alloc_0._gpu_shared_mem, align 4
  br label %459

458:                                              ; preds = %320
  br label %459

459:                                              ; preds = %458, %456
  br label %461

460:                                              ; preds = %314
  br label %461

461:                                              ; preds = %460, %459
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %462 = load { float, float, float }, ptr addrspace(3) @rowwise_block_t0_r2_ax1_w1_bs128_b2b54013._global_alloc_0._gpu_shared_mem, align 4
  store { float, float, float } %462, ptr %12, align 4
  %463 = load float, ptr %183, align 4
  store float %463, ptr %183, align 4
  %464 = load float, ptr %187, align 4
  store float %464, ptr %187, align 4
  %465 = load float, ptr %177, align 4
  store float %465, ptr %177, align 4
  %466 = load { float, float, float }, ptr %12, align 4
  call void @llvm.lifetime.end.p0(ptr %12)
  %467 = extractvalue { float, float, float } %466, 0
  %468 = extractvalue { float, float, float } %466, 1
  %469 = extractvalue { float, float, float } %466, 2
  %470 = fdiv float %469, %467
  %471 = fadd contract float %470, %72
  %472 = call float @llvm.nvvm.rsqrt.approx.ftz.f(float %471)
  %473 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %14, align 8
  %474 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %473, 0
  %475 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %473, 1, 1, 0
  %476 = extractvalue { ptr, { { i64 }, { {} } } } %70, 0
  %477 = extractvalue { ptr, { { i64 }, { {} } } } %71, 0
  %478 = mul i64 %63, %475
  br label %479

479:                                              ; preds = %546, %461
  %480 = phi i64 [ 0, %461 ], [ %547, %546 ]
  %481 = phi i64 [ 0, %461 ], [ %490, %546 ]
  %482 = phi i64 [ 0, %461 ], [ %491, %546 ]
  %483 = add i64 %481, 128
  %484 = icmp slt i64 %483, %481
  %485 = select i1 %484, i64 1, i64 0
  %486 = icmp sge i64 %481, %69
  %487 = icmp eq i64 %482, 0
  %488 = xor i1 %487, true
  %489 = or i1 %488, %486
  %490 = select i1 %489, i64 %481, i64 %483
  %491 = select i1 %489, i64 %482, i64 %485
  br i1 %489, label %492, label %493

492:                                              ; preds = %479
  br label %548

493:                                              ; preds = %479
  br label %494

494:                                              ; preds = %493
  %495 = add i64 %481, %24
  %496 = getelementptr inbounds float, ptr %477, i64 %495
  %497 = getelementptr inbounds float, ptr %476, i64 %495
  %498 = add i64 %478, %495
  %499 = getelementptr inbounds float, ptr %474, i64 %498
  %500 = add i64 %76, %495
  %501 = getelementptr inbounds float, ptr %74, i64 %500
  %502 = sub i64 %69, %495
  %503 = call i64 @llvm.smin.i64(i64 %502, i64 1)
  %504 = call i64 @llvm.smax.i64(i64 %503, i64 0)
  %505 = icmp eq i64 %503, 1
  %506 = icmp slt i64 %495, %69
  br i1 %506, label %507, label %545

507:                                              ; preds = %494
  br i1 %505, label %508, label %516

508:                                              ; preds = %507
  %509 = load float, ptr %501, align 4
  %510 = load float, ptr %497, align 4, !invariant.load !1
  %511 = load float, ptr %496, align 4, !invariant.load !1
  %512 = fsub contract float %509, %468
  %513 = fmul contract float %512, %472
  %514 = fmul contract float %513, %510
  %515 = fadd contract float %514, %511
  store float %515, ptr %499, align 4
  br label %543

516:                                              ; preds = %507
  br label %517

517:                                              ; preds = %523, %516
  %518 = phi i64 [ 0, %516 ], [ %526, %523 ]
  %519 = phi i64 [ %480, %516 ], [ %527, %523 ]
  %520 = icmp slt i64 %518, %504
  br i1 %520, label %521, label %522

521:                                              ; preds = %517
  br label %523

522:                                              ; preds = %517
  br label %541

523:                                              ; preds = %521
  %524 = icmp eq i64 %518, %504
  %525 = add i64 %518, 1
  %526 = select i1 %524, i64 %518, i64 %525
  %527 = add i64 %495, %518
  %528 = add i64 %76, %527
  %529 = getelementptr inbounds float, ptr %74, i64 %528
  %530 = load float, ptr %529, align 4
  %531 = getelementptr inbounds float, ptr %476, i64 %527
  %532 = load float, ptr %531, align 4, !invariant.load !1
  %533 = getelementptr inbounds float, ptr %477, i64 %527
  %534 = load float, ptr %533, align 4, !invariant.load !1
  %535 = fsub contract float %530, %468
  %536 = fmul contract float %535, %472
  %537 = fmul contract float %536, %532
  %538 = fadd contract float %537, %534
  %539 = add i64 %478, %527
  %540 = getelementptr inbounds float, ptr %474, i64 %539
  store float %538, ptr %540, align 4
  br label %517

541:                                              ; preds = %522
  %542 = phi i64 [ %519, %522 ]
  br label %543

543:                                              ; preds = %541, %508
  %544 = phi i64 [ %542, %541 ], [ %495, %508 ]
  br label %546

545:                                              ; preds = %494
  br label %546

546:                                              ; preds = %545, %543
  %547 = phi i64 [ %480, %545 ], [ %544, %543 ]
  br label %479

548:                                              ; preds = %492
  br label %39

549:                                              ; preds = %66
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
