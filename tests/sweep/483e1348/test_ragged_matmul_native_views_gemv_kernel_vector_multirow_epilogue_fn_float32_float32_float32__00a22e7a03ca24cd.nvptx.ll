; ModuleID = 'test_ragged_matmul_native_views.mojo'
source_filename = "test_ragged_matmul_native_views.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_epilogue_fn_float32_float32_float32_True_4_4_d97f03db(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca [2 x ptr], i64 1, align 8
  %13 = alloca i64, i64 1, align 8
  %14 = alloca [2 x ptr], i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca [2 x ptr], i64 1, align 8
  %17 = alloca i64, i64 1, align 8
  %18 = alloca i64, i64 1, align 8
  %19 = alloca [2 x ptr], i64 1, align 8
  %20 = alloca i64, i64 1, align 8
  %21 = alloca [2 x ptr], i64 1, align 8
  %22 = alloca i64, i64 1, align 8
  %23 = alloca [2 x ptr], i64 1, align 8
  %24 = alloca i64, i64 1, align 8
  %25 = alloca [2 x ptr], i64 1, align 8
  %26 = alloca i64, i64 1, align 8
  %27 = alloca [2 x ptr], i64 1, align 8
  %28 = alloca i64, i64 1, align 8
  %29 = alloca i64, i64 1, align 8
  %30 = alloca [2 x ptr], i64 1, align 8
  %31 = alloca i32, i64 1, align 4
  %32 = alloca i32, i64 1, align 4
  %33 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %34 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %35 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %34, 0
  %36 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %33, 0
  %37 = sext i32 %3 to i64
  %38 = sub i64 %37, 1
  %39 = sext i32 %5 to i64
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %41 = zext i32 %40 to i64
  %42 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %43 = zext i32 %42 to i64
  %44 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %45 = sext i32 %44 to i64
  %46 = mul i64 %43, %45
  %47 = add i64 %46, %41
  %48 = udiv i64 %47, 32
  %49 = bitcast i64 %48 to <2 x i32>
  %50 = extractelement <2 x i32> %49, i64 0
  %51 = extractelement <2 x i32> %49, i64 1
  %52 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %50, i32 0, i32 31)
  %53 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %51, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %32)
  call void @llvm.lifetime.start.p0(ptr %32)
  store i32 %52, ptr %32, align 4
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i32 %53, ptr %31, align 4
  call void @llvm.lifetime.end.p0(ptr %30)
  %54 = insertvalue [2 x ptr] undef, ptr %32, 0
  %55 = insertvalue [2 x ptr] %54, ptr %31, 1
  call void @llvm.lifetime.start.p0(ptr %30)
  store [2 x ptr] %55, ptr %30, align 8
  %56 = getelementptr inbounds [2 x ptr], ptr %30, i32 0, i32 0
  %57 = load ptr, ptr %56, align 8
  %58 = load i32, ptr %57, align 4
  %59 = insertelement <2 x i32> undef, i32 %58, i64 0
  %60 = getelementptr inbounds ptr, ptr %56, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = load i32, ptr %61, align 4
  %63 = insertelement <2 x i32> %59, i32 %62, i64 1
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.end.p0(ptr %32)
  %64 = bitcast <2 x i32> %63 to i64
  %65 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %66 = sext i32 %65 to i64
  %67 = trunc i64 %66 to i32
  %68 = mul i32 %67, 4
  %69 = sext i32 %68 to i64
  %70 = icmp eq i64 %66, 0
  %71 = mul i64 %64, 4
  %72 = trunc i64 %71 to i32
  %73 = sext i32 %72 to i64
  %74 = add i64 %71, 3
  %75 = call i64 @llvm.smin.i64(i64 %74, i64 %38)
  %76 = add i64 %71, 2
  %77 = call i64 @llvm.smin.i64(i64 %76, i64 %38)
  %78 = add i64 %71, 1
  %79 = call i64 @llvm.smin.i64(i64 %78, i64 %38)
  %80 = call i64 @llvm.smin.i64(i64 %71, i64 %38)
  %81 = trunc i64 %74 to i32
  %82 = sext i32 %81 to i64
  %83 = icmp slt i64 %74, %37
  %84 = select i1 %70, i1 %83, i1 false
  %85 = trunc i64 %76 to i32
  %86 = sext i32 %85 to i64
  %87 = icmp slt i64 %76, %37
  %88 = select i1 %70, i1 %87, i1 false
  %89 = trunc i64 %78 to i32
  %90 = sext i32 %89 to i64
  %91 = icmp slt i64 %78, %37
  %92 = select i1 %70, i1 %91, i1 false
  %93 = icmp slt i64 %71, %37
  %94 = select i1 %70, i1 %93, i1 false
  %95 = icmp sge i64 %71, %37
  br i1 %95, label %96, label %97

96:                                               ; preds = %7
  br label %454

97:                                               ; preds = %7
  %98 = sdiv i64 %39, 4
  %99 = mul i64 %98, 4
  %100 = icmp eq i64 %99, %39
  %101 = xor i64 %39, 4
  %102 = ashr i64 %101, 63
  %103 = select i1 %100, i64 0, i64 %102
  %104 = add i64 %98, %103
  %105 = sdiv i64 %104, -32
  %106 = mul i64 %105, -32
  %107 = icmp eq i64 %106, %104
  %108 = xor i64 %104, -32
  %109 = ashr i64 %108, 63
  %110 = select i1 %107, i64 0, i64 %109
  %111 = add i64 %105, %110
  %112 = sub i64 0, %111
  %113 = sub i64 %112, 1
  %114 = call i64 @llvm.smax.i64(i64 %113, i64 0)
  br label %115

115:                                              ; preds = %126, %97
  %116 = phi i64 [ 0, %97 ], [ %123, %126 ]
  %117 = phi <4 x float> [ zeroinitializer, %97 ], [ %159, %126 ]
  %118 = phi <4 x float> [ zeroinitializer, %97 ], [ %178, %126 ]
  %119 = phi <4 x float> [ zeroinitializer, %97 ], [ %197, %126 ]
  %120 = phi <4 x float> [ zeroinitializer, %97 ], [ %216, %126 ]
  call void @llvm.lifetime.end.p0(ptr %29)
  %121 = icmp eq i64 %116, %114
  %122 = add i64 %116, 1
  %123 = select i1 %121, i64 %116, i64 %122
  br i1 %121, label %124, label %126

124:                                              ; preds = %115
  %125 = icmp sgt i64 %112, 0
  br i1 %125, label %217, label %320

126:                                              ; preds = %115
  call void @llvm.lifetime.start.p0(ptr %29)
  store i64 %116, ptr %29, align 8
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 0, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  %127 = insertvalue [2 x ptr] undef, ptr %28, 0
  %128 = insertvalue [2 x ptr] %127, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %27)
  store [2 x ptr] %128, ptr %27, align 8
  %129 = getelementptr inbounds [2 x ptr], ptr %27, i32 0, i32 0
  %130 = load ptr, ptr %129, align 8
  %131 = load i64, ptr %130, align 8
  %132 = getelementptr inbounds ptr, ptr %129, i32 1
  %133 = load ptr, ptr %132, align 8
  %134 = load i64, ptr %133, align 8
  %135 = mul i64 %131, 64
  %136 = mul i64 %134, 128
  %137 = add i64 %135, %136
  %138 = getelementptr inbounds float, ptr %36, i64 %137
  %139 = getelementptr inbounds float, ptr %138, i64 %69
  %140 = load <4 x float>, ptr %139, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.start.p0(ptr %26)
  store i64 %80, ptr %26, align 8
  call void @llvm.lifetime.end.p0(ptr %25)
  %141 = insertvalue [2 x ptr] undef, ptr %26, 0
  %142 = insertvalue [2 x ptr] %141, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %25)
  store [2 x ptr] %142, ptr %25, align 8
  %143 = getelementptr inbounds [2 x ptr], ptr %25, i32 0, i32 0
  %144 = load ptr, ptr %143, align 8
  %145 = load i64, ptr %144, align 8
  %146 = trunc i64 %145 to i32
  %147 = getelementptr inbounds ptr, ptr %143, i32 1
  %148 = load ptr, ptr %147, align 8
  %149 = load i64, ptr %148, align 8
  %150 = trunc i64 %149 to i32
  %151 = mul i32 %146, 64
  %152 = mul i32 %150, 128
  %153 = add i32 %151, %152
  %154 = sext i32 %153 to i64
  %155 = getelementptr inbounds float, ptr %35, i64 %154
  %156 = getelementptr inbounds float, ptr %155, i64 %69
  %157 = load <4 x float>, ptr %156, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.end.p0(ptr %26)
  %158 = fmul contract <4 x float> %157, %140
  %159 = fadd contract <4 x float> %117, %158
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %79, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  %160 = insertvalue [2 x ptr] undef, ptr %24, 0
  %161 = insertvalue [2 x ptr] %160, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %23)
  store [2 x ptr] %161, ptr %23, align 8
  %162 = getelementptr inbounds [2 x ptr], ptr %23, i32 0, i32 0
  %163 = load ptr, ptr %162, align 8
  %164 = load i64, ptr %163, align 8
  %165 = trunc i64 %164 to i32
  %166 = getelementptr inbounds ptr, ptr %162, i32 1
  %167 = load ptr, ptr %166, align 8
  %168 = load i64, ptr %167, align 8
  %169 = trunc i64 %168 to i32
  %170 = mul i32 %165, 64
  %171 = mul i32 %169, 128
  %172 = add i32 %170, %171
  %173 = sext i32 %172 to i64
  %174 = getelementptr inbounds float, ptr %35, i64 %173
  %175 = getelementptr inbounds float, ptr %174, i64 %69
  %176 = load <4 x float>, ptr %175, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  %177 = fmul contract <4 x float> %176, %140
  %178 = fadd contract <4 x float> %118, %177
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.start.p0(ptr %22)
  store i64 %77, ptr %22, align 8
  call void @llvm.lifetime.end.p0(ptr %21)
  %179 = insertvalue [2 x ptr] undef, ptr %22, 0
  %180 = insertvalue [2 x ptr] %179, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %21)
  store [2 x ptr] %180, ptr %21, align 8
  %181 = getelementptr inbounds [2 x ptr], ptr %21, i32 0, i32 0
  %182 = load ptr, ptr %181, align 8
  %183 = load i64, ptr %182, align 8
  %184 = trunc i64 %183 to i32
  %185 = getelementptr inbounds ptr, ptr %181, i32 1
  %186 = load ptr, ptr %185, align 8
  %187 = load i64, ptr %186, align 8
  %188 = trunc i64 %187 to i32
  %189 = mul i32 %184, 64
  %190 = mul i32 %188, 128
  %191 = add i32 %189, %190
  %192 = sext i32 %191 to i64
  %193 = getelementptr inbounds float, ptr %35, i64 %192
  %194 = getelementptr inbounds float, ptr %193, i64 %69
  %195 = load <4 x float>, ptr %194, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %22)
  %196 = fmul contract <4 x float> %195, %140
  %197 = fadd contract <4 x float> %119, %196
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 %75, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %198 = insertvalue [2 x ptr] undef, ptr %20, 0
  %199 = insertvalue [2 x ptr] %198, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %199, ptr %19, align 8
  %200 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %201 = load ptr, ptr %200, align 8
  %202 = load i64, ptr %201, align 8
  %203 = trunc i64 %202 to i32
  %204 = getelementptr inbounds ptr, ptr %200, i32 1
  %205 = load ptr, ptr %204, align 8
  %206 = load i64, ptr %205, align 8
  %207 = trunc i64 %206 to i32
  %208 = mul i32 %203, 64
  %209 = mul i32 %207, 128
  %210 = add i32 %208, %209
  %211 = sext i32 %210 to i64
  %212 = getelementptr inbounds float, ptr %35, i64 %211
  %213 = getelementptr inbounds float, ptr %212, i64 %69
  %214 = load <4 x float>, ptr %213, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  %215 = fmul contract <4 x float> %214, %140
  %216 = fadd contract <4 x float> %120, %215
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.end.p0(ptr %29)
  br label %115

217:                                              ; preds = %124
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %113, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %218 = insertvalue [2 x ptr] undef, ptr %17, 0
  %219 = insertvalue [2 x ptr] %218, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %219, ptr %16, align 8
  %220 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %221 = load ptr, ptr %220, align 8
  %222 = load i64, ptr %221, align 8
  %223 = getelementptr inbounds ptr, ptr %220, i32 1
  %224 = load ptr, ptr %223, align 8
  %225 = load i64, ptr %224, align 8
  %226 = mul i64 %222, 64
  %227 = mul i64 %225, 128
  %228 = add i64 %226, %227
  %229 = getelementptr inbounds float, ptr %36, i64 %228
  %230 = getelementptr inbounds float, ptr %229, i64 %69
  %231 = load i64, ptr %18, align 8
  %232 = mul i64 %231, 32
  %233 = add i64 %66, %232
  %234 = mul i64 %233, 4
  %235 = icmp slt i64 %234, %39
  br i1 %235, label %236, label %314

236:                                              ; preds = %217
  %237 = load <4 x float>, ptr %230, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %80, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %238 = insertvalue [2 x ptr] undef, ptr %15, 0
  %239 = insertvalue [2 x ptr] %238, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %239, ptr %14, align 8
  %240 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %241 = load ptr, ptr %240, align 8
  %242 = load i64, ptr %241, align 8
  %243 = trunc i64 %242 to i32
  %244 = getelementptr inbounds ptr, ptr %240, i32 1
  %245 = load ptr, ptr %244, align 8
  %246 = load i64, ptr %245, align 8
  %247 = trunc i64 %246 to i32
  %248 = mul i32 %243, 64
  %249 = mul i32 %247, 128
  %250 = add i32 %248, %249
  %251 = sext i32 %250 to i64
  %252 = getelementptr inbounds float, ptr %35, i64 %251
  %253 = getelementptr inbounds float, ptr %252, i64 %69
  %254 = load <4 x float>, ptr %253, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %255 = fmul contract <4 x float> %254, %237
  %256 = fadd contract <4 x float> %117, %255
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %79, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %257 = insertvalue [2 x ptr] undef, ptr %13, 0
  %258 = insertvalue [2 x ptr] %257, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %258, ptr %12, align 8
  %259 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %260 = load ptr, ptr %259, align 8
  %261 = load i64, ptr %260, align 8
  %262 = trunc i64 %261 to i32
  %263 = getelementptr inbounds ptr, ptr %259, i32 1
  %264 = load ptr, ptr %263, align 8
  %265 = load i64, ptr %264, align 8
  %266 = trunc i64 %265 to i32
  %267 = mul i32 %262, 64
  %268 = mul i32 %266, 128
  %269 = add i32 %267, %268
  %270 = sext i32 %269 to i64
  %271 = getelementptr inbounds float, ptr %35, i64 %270
  %272 = getelementptr inbounds float, ptr %271, i64 %69
  %273 = load <4 x float>, ptr %272, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  %274 = fmul contract <4 x float> %273, %237
  %275 = fadd contract <4 x float> %118, %274
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %77, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %276 = insertvalue [2 x ptr] undef, ptr %11, 0
  %277 = insertvalue [2 x ptr] %276, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %277, ptr %10, align 8
  %278 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %279 = load ptr, ptr %278, align 8
  %280 = load i64, ptr %279, align 8
  %281 = trunc i64 %280 to i32
  %282 = getelementptr inbounds ptr, ptr %278, i32 1
  %283 = load ptr, ptr %282, align 8
  %284 = load i64, ptr %283, align 8
  %285 = trunc i64 %284 to i32
  %286 = mul i32 %281, 64
  %287 = mul i32 %285, 128
  %288 = add i32 %286, %287
  %289 = sext i32 %288 to i64
  %290 = getelementptr inbounds float, ptr %35, i64 %289
  %291 = getelementptr inbounds float, ptr %290, i64 %69
  %292 = load <4 x float>, ptr %291, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %293 = fmul contract <4 x float> %292, %237
  %294 = fadd contract <4 x float> %119, %293
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %75, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %295 = insertvalue [2 x ptr] undef, ptr %9, 0
  %296 = insertvalue [2 x ptr] %295, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %296, ptr %8, align 8
  %297 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %298 = load ptr, ptr %297, align 8
  %299 = load i64, ptr %298, align 8
  %300 = trunc i64 %299 to i32
  %301 = getelementptr inbounds ptr, ptr %297, i32 1
  %302 = load ptr, ptr %301, align 8
  %303 = load i64, ptr %302, align 8
  %304 = trunc i64 %303 to i32
  %305 = mul i32 %300, 64
  %306 = mul i32 %304, 128
  %307 = add i32 %305, %306
  %308 = sext i32 %307 to i64
  %309 = getelementptr inbounds float, ptr %35, i64 %308
  %310 = getelementptr inbounds float, ptr %309, i64 %69
  %311 = load <4 x float>, ptr %310, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %312 = fmul contract <4 x float> %311, %237
  %313 = fadd contract <4 x float> %120, %312
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %315

314:                                              ; preds = %217
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %315

315:                                              ; preds = %314, %236
  %316 = phi <4 x float> [ %117, %314 ], [ %256, %236 ]
  %317 = phi <4 x float> [ %118, %314 ], [ %275, %236 ]
  %318 = phi <4 x float> [ %119, %314 ], [ %294, %236 ]
  %319 = phi <4 x float> [ %120, %314 ], [ %313, %236 ]
  br label %321

320:                                              ; preds = %124
  br label %321

321:                                              ; preds = %320, %315
  %322 = phi <4 x float> [ %117, %320 ], [ %316, %315 ]
  %323 = phi <4 x float> [ %118, %320 ], [ %317, %315 ]
  %324 = phi <4 x float> [ %119, %320 ], [ %318, %315 ]
  %325 = phi <4 x float> [ %120, %320 ], [ %319, %315 ]
  %326 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %322, i64 0)
  %327 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %322, i64 2)
  %328 = fadd contract <2 x float> %326, %327
  %329 = extractelement <2 x float> %328, i64 0
  %330 = extractelement <2 x float> %328, i64 1
  %331 = fadd contract float %329, %330
  %332 = bitcast float %331 to i32
  %333 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %332, i32 16, i32 31)
  %334 = bitcast i32 %333 to float
  %335 = fadd contract float %331, %334
  %336 = bitcast float %335 to i32
  %337 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %336, i32 8, i32 31)
  %338 = bitcast i32 %337 to float
  %339 = fadd contract float %335, %338
  %340 = bitcast float %339 to i32
  %341 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %340, i32 4, i32 31)
  %342 = bitcast i32 %341 to float
  %343 = fadd contract float %339, %342
  %344 = bitcast float %343 to i32
  %345 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %344, i32 2, i32 31)
  %346 = bitcast i32 %345 to float
  %347 = fadd contract float %343, %346
  %348 = bitcast float %347 to i32
  %349 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %348, i32 1, i32 31)
  %350 = bitcast i32 %349 to float
  %351 = fadd contract float %347, %350
  br i1 %94, label %352, label %356

352:                                              ; preds = %321
  %353 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %354 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %353, 0
  %355 = getelementptr inbounds float, ptr %354, i64 %73
  store float %351, ptr %355, align 4
  br label %357

356:                                              ; preds = %321
  br label %357

357:                                              ; preds = %356, %352
  %358 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %323, i64 0)
  %359 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %323, i64 2)
  %360 = fadd contract <2 x float> %358, %359
  %361 = extractelement <2 x float> %360, i64 0
  %362 = extractelement <2 x float> %360, i64 1
  %363 = fadd contract float %361, %362
  %364 = bitcast float %363 to i32
  %365 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %364, i32 16, i32 31)
  %366 = bitcast i32 %365 to float
  %367 = fadd contract float %363, %366
  %368 = bitcast float %367 to i32
  %369 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %368, i32 8, i32 31)
  %370 = bitcast i32 %369 to float
  %371 = fadd contract float %367, %370
  %372 = bitcast float %371 to i32
  %373 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %372, i32 4, i32 31)
  %374 = bitcast i32 %373 to float
  %375 = fadd contract float %371, %374
  %376 = bitcast float %375 to i32
  %377 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %376, i32 2, i32 31)
  %378 = bitcast i32 %377 to float
  %379 = fadd contract float %375, %378
  %380 = bitcast float %379 to i32
  %381 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %380, i32 1, i32 31)
  %382 = bitcast i32 %381 to float
  %383 = fadd contract float %379, %382
  br i1 %92, label %384, label %388

384:                                              ; preds = %357
  %385 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %386 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %385, 0
  %387 = getelementptr inbounds float, ptr %386, i64 %90
  store float %383, ptr %387, align 4
  br label %389

388:                                              ; preds = %357
  br label %389

389:                                              ; preds = %388, %384
  %390 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %324, i64 0)
  %391 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %324, i64 2)
  %392 = fadd contract <2 x float> %390, %391
  %393 = extractelement <2 x float> %392, i64 0
  %394 = extractelement <2 x float> %392, i64 1
  %395 = fadd contract float %393, %394
  %396 = bitcast float %395 to i32
  %397 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %396, i32 16, i32 31)
  %398 = bitcast i32 %397 to float
  %399 = fadd contract float %395, %398
  %400 = bitcast float %399 to i32
  %401 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %400, i32 8, i32 31)
  %402 = bitcast i32 %401 to float
  %403 = fadd contract float %399, %402
  %404 = bitcast float %403 to i32
  %405 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %404, i32 4, i32 31)
  %406 = bitcast i32 %405 to float
  %407 = fadd contract float %403, %406
  %408 = bitcast float %407 to i32
  %409 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %408, i32 2, i32 31)
  %410 = bitcast i32 %409 to float
  %411 = fadd contract float %407, %410
  %412 = bitcast float %411 to i32
  %413 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %412, i32 1, i32 31)
  %414 = bitcast i32 %413 to float
  %415 = fadd contract float %411, %414
  br i1 %88, label %416, label %420

416:                                              ; preds = %389
  %417 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %418 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %417, 0
  %419 = getelementptr inbounds float, ptr %418, i64 %86
  store float %415, ptr %419, align 4
  br label %421

420:                                              ; preds = %389
  br label %421

421:                                              ; preds = %420, %416
  %422 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %325, i64 0)
  %423 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %325, i64 2)
  %424 = fadd contract <2 x float> %422, %423
  %425 = extractelement <2 x float> %424, i64 0
  %426 = extractelement <2 x float> %424, i64 1
  %427 = fadd contract float %425, %426
  %428 = bitcast float %427 to i32
  %429 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %428, i32 16, i32 31)
  %430 = bitcast i32 %429 to float
  %431 = fadd contract float %427, %430
  %432 = bitcast float %431 to i32
  %433 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %432, i32 8, i32 31)
  %434 = bitcast i32 %433 to float
  %435 = fadd contract float %431, %434
  %436 = bitcast float %435 to i32
  %437 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %436, i32 4, i32 31)
  %438 = bitcast i32 %437 to float
  %439 = fadd contract float %435, %438
  %440 = bitcast float %439 to i32
  %441 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %440, i32 2, i32 31)
  %442 = bitcast i32 %441 to float
  %443 = fadd contract float %439, %442
  %444 = bitcast float %443 to i32
  %445 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %444, i32 1, i32 31)
  %446 = bitcast i32 %445 to float
  %447 = fadd contract float %443, %446
  br i1 %84, label %448, label %452

448:                                              ; preds = %421
  %449 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %450 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %449, 0
  %451 = getelementptr inbounds float, ptr %450, i64 %82
  store float %447, ptr %451, align 4
  br label %453

452:                                              ; preds = %421
  br label %453

453:                                              ; preds = %452, %448
  br label %454

454:                                              ; preds = %453, %96
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.idx.i32(i32, i32, i32, i32) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 32) i32 @llvm.nvvm.read.ptx.sreg.laneid() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #4

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float>, i64 immarg) #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #2

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
