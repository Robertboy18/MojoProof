; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_compute_fn_bfloat16_bfloat16_bfloat16_True_8_4_5752317d(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, { i64, i64, i64, {} } noundef %6) #0 {
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
  %33 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %34 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %35 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %36 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %35, 0
  %37 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %34, 0
  %38 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %34, 1, 1, 0
  %39 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %33, 0
  %40 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %33, 1, 1, 0
  %41 = sext i32 %3 to i64
  %42 = sub i64 %41, 1
  %43 = sext i32 %5 to i64
  %44 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %45 = zext i32 %44 to i64
  %46 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %47 = zext i32 %46 to i64
  %48 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %49 = sext i32 %48 to i64
  %50 = mul i64 %47, %49
  %51 = add i64 %50, %45
  %52 = udiv i64 %51, 32
  %53 = bitcast i64 %52 to <2 x i32>
  %54 = extractelement <2 x i32> %53, i64 0
  %55 = extractelement <2 x i32> %53, i64 1
  %56 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %54, i32 0, i32 31)
  %57 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %55, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %32)
  call void @llvm.lifetime.start.p0(ptr %32)
  store i32 %56, ptr %32, align 4
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i32 %57, ptr %31, align 4
  call void @llvm.lifetime.end.p0(ptr %30)
  %58 = insertvalue [2 x ptr] undef, ptr %32, 0
  %59 = insertvalue [2 x ptr] %58, ptr %31, 1
  call void @llvm.lifetime.start.p0(ptr %30)
  store [2 x ptr] %59, ptr %30, align 8
  %60 = getelementptr inbounds [2 x ptr], ptr %30, i32 0, i32 0
  %61 = load ptr, ptr %60, align 8
  %62 = load i32, ptr %61, align 4
  %63 = insertelement <2 x i32> undef, i32 %62, i64 0
  %64 = getelementptr inbounds ptr, ptr %60, i32 1
  %65 = load ptr, ptr %64, align 8
  %66 = load i32, ptr %65, align 4
  %67 = insertelement <2 x i32> %63, i32 %66, i64 1
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.end.p0(ptr %32)
  %68 = bitcast <2 x i32> %67 to i64
  %69 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %70 = sext i32 %69 to i64
  %71 = mul i64 %70, 8
  %72 = icmp eq i64 %70, 0
  %73 = mul i64 %68, 4
  %74 = getelementptr inbounds bfloat, ptr %36, i64 %73
  %75 = icmp slt i64 %73, %41
  %76 = select i1 %72, i1 %75, i1 false
  %77 = add i64 %73, 3
  %78 = getelementptr inbounds bfloat, ptr %36, i64 %77
  %79 = icmp slt i64 %77, %41
  %80 = select i1 %72, i1 %79, i1 false
  %81 = call i64 @llvm.smin.i64(i64 %77, i64 %42)
  %82 = add i64 %73, 2
  %83 = getelementptr inbounds bfloat, ptr %36, i64 %82
  %84 = icmp slt i64 %82, %41
  %85 = select i1 %72, i1 %84, i1 false
  %86 = call i64 @llvm.smin.i64(i64 %82, i64 %42)
  %87 = add i64 %73, 1
  %88 = getelementptr inbounds bfloat, ptr %36, i64 %87
  %89 = icmp slt i64 %87, %41
  %90 = select i1 %72, i1 %89, i1 false
  %91 = call i64 @llvm.smin.i64(i64 %87, i64 %42)
  %92 = call i64 @llvm.smin.i64(i64 %73, i64 %42)
  %93 = icmp sge i64 %73, %41
  br i1 %93, label %94, label %95

94:                                               ; preds = %7
  br label %454

95:                                               ; preds = %7
  %96 = sdiv i64 %43, 8
  %97 = mul i64 %96, 8
  %98 = icmp eq i64 %97, %43
  %99 = xor i64 %43, 8
  %100 = ashr i64 %99, 63
  %101 = select i1 %98, i64 0, i64 %100
  %102 = add i64 %96, %101
  %103 = sdiv i64 %102, -32
  %104 = mul i64 %103, -32
  %105 = icmp eq i64 %104, %102
  %106 = xor i64 %102, -32
  %107 = ashr i64 %106, 63
  %108 = select i1 %105, i64 0, i64 %107
  %109 = add i64 %103, %108
  %110 = sub i64 0, %109
  %111 = sub i64 %110, 1
  %112 = call i64 @llvm.smax.i64(i64 %111, i64 0)
  br label %113

113:                                              ; preds = %124, %95
  %114 = phi i64 [ 0, %95 ], [ %121, %124 ]
  %115 = phi <8 x float> [ zeroinitializer, %95 ], [ %156, %124 ]
  %116 = phi <8 x float> [ zeroinitializer, %95 ], [ %173, %124 ]
  %117 = phi <8 x float> [ zeroinitializer, %95 ], [ %190, %124 ]
  %118 = phi <8 x float> [ zeroinitializer, %95 ], [ %207, %124 ]
  call void @llvm.lifetime.end.p0(ptr %29)
  %119 = icmp eq i64 %114, %112
  %120 = add i64 %114, 1
  %121 = select i1 %119, i64 %114, i64 %120
  br i1 %119, label %122, label %124

122:                                              ; preds = %113
  %123 = icmp sgt i64 %110, 0
  br i1 %123, label %208, label %304

124:                                              ; preds = %113
  call void @llvm.lifetime.start.p0(ptr %29)
  store i64 %114, ptr %29, align 8
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 0, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  %125 = insertvalue [2 x ptr] undef, ptr %28, 0
  %126 = insertvalue [2 x ptr] %125, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %27)
  store [2 x ptr] %126, ptr %27, align 8
  %127 = getelementptr inbounds [2 x ptr], ptr %27, i32 0, i32 0
  %128 = load ptr, ptr %127, align 8
  %129 = load i64, ptr %128, align 8
  %130 = getelementptr inbounds ptr, ptr %127, i32 1
  %131 = load ptr, ptr %130, align 8
  %132 = load i64, ptr %131, align 8
  %133 = mul i64 %129, %40
  %134 = mul i64 %132, 256
  %135 = add i64 %133, %134
  %136 = getelementptr inbounds bfloat, ptr %39, i64 %135
  %137 = getelementptr inbounds bfloat, ptr %136, i64 %71
  %138 = load <8 x bfloat>, ptr %137, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.start.p0(ptr %26)
  store i64 %92, ptr %26, align 8
  call void @llvm.lifetime.end.p0(ptr %25)
  %139 = insertvalue [2 x ptr] undef, ptr %26, 0
  %140 = insertvalue [2 x ptr] %139, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %25)
  store [2 x ptr] %140, ptr %25, align 8
  %141 = getelementptr inbounds [2 x ptr], ptr %25, i32 0, i32 0
  %142 = load ptr, ptr %141, align 8
  %143 = load i64, ptr %142, align 8
  %144 = getelementptr inbounds ptr, ptr %141, i32 1
  %145 = load ptr, ptr %144, align 8
  %146 = load i64, ptr %145, align 8
  %147 = mul i64 %143, %38
  %148 = mul i64 %146, 256
  %149 = add i64 %147, %148
  %150 = getelementptr inbounds bfloat, ptr %37, i64 %149
  %151 = getelementptr inbounds bfloat, ptr %150, i64 %71
  %152 = load <8 x bfloat>, ptr %151, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.end.p0(ptr %26)
  %153 = fpext <8 x bfloat> %152 to <8 x float>
  %154 = fpext <8 x bfloat> %138 to <8 x float>
  %155 = fmul contract <8 x float> %153, %154
  %156 = fadd contract <8 x float> %115, %155
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %91, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  %157 = insertvalue [2 x ptr] undef, ptr %24, 0
  %158 = insertvalue [2 x ptr] %157, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %23)
  store [2 x ptr] %158, ptr %23, align 8
  %159 = getelementptr inbounds [2 x ptr], ptr %23, i32 0, i32 0
  %160 = load ptr, ptr %159, align 8
  %161 = load i64, ptr %160, align 8
  %162 = getelementptr inbounds ptr, ptr %159, i32 1
  %163 = load ptr, ptr %162, align 8
  %164 = load i64, ptr %163, align 8
  %165 = mul i64 %161, %38
  %166 = mul i64 %164, 256
  %167 = add i64 %165, %166
  %168 = getelementptr inbounds bfloat, ptr %37, i64 %167
  %169 = getelementptr inbounds bfloat, ptr %168, i64 %71
  %170 = load <8 x bfloat>, ptr %169, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  %171 = fpext <8 x bfloat> %170 to <8 x float>
  %172 = fmul contract <8 x float> %171, %154
  %173 = fadd contract <8 x float> %116, %172
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.start.p0(ptr %22)
  store i64 %86, ptr %22, align 8
  call void @llvm.lifetime.end.p0(ptr %21)
  %174 = insertvalue [2 x ptr] undef, ptr %22, 0
  %175 = insertvalue [2 x ptr] %174, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %21)
  store [2 x ptr] %175, ptr %21, align 8
  %176 = getelementptr inbounds [2 x ptr], ptr %21, i32 0, i32 0
  %177 = load ptr, ptr %176, align 8
  %178 = load i64, ptr %177, align 8
  %179 = getelementptr inbounds ptr, ptr %176, i32 1
  %180 = load ptr, ptr %179, align 8
  %181 = load i64, ptr %180, align 8
  %182 = mul i64 %178, %38
  %183 = mul i64 %181, 256
  %184 = add i64 %182, %183
  %185 = getelementptr inbounds bfloat, ptr %37, i64 %184
  %186 = getelementptr inbounds bfloat, ptr %185, i64 %71
  %187 = load <8 x bfloat>, ptr %186, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %22)
  %188 = fpext <8 x bfloat> %187 to <8 x float>
  %189 = fmul contract <8 x float> %188, %154
  %190 = fadd contract <8 x float> %117, %189
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 %81, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %191 = insertvalue [2 x ptr] undef, ptr %20, 0
  %192 = insertvalue [2 x ptr] %191, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %192, ptr %19, align 8
  %193 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %194 = load ptr, ptr %193, align 8
  %195 = load i64, ptr %194, align 8
  %196 = getelementptr inbounds ptr, ptr %193, i32 1
  %197 = load ptr, ptr %196, align 8
  %198 = load i64, ptr %197, align 8
  %199 = mul i64 %195, %38
  %200 = mul i64 %198, 256
  %201 = add i64 %199, %200
  %202 = getelementptr inbounds bfloat, ptr %37, i64 %201
  %203 = getelementptr inbounds bfloat, ptr %202, i64 %71
  %204 = load <8 x bfloat>, ptr %203, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  %205 = fpext <8 x bfloat> %204 to <8 x float>
  %206 = fmul contract <8 x float> %205, %154
  %207 = fadd contract <8 x float> %118, %206
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.end.p0(ptr %29)
  br label %113

208:                                              ; preds = %122
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %111, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %209 = insertvalue [2 x ptr] undef, ptr %17, 0
  %210 = insertvalue [2 x ptr] %209, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %210, ptr %16, align 8
  %211 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %212 = load ptr, ptr %211, align 8
  %213 = load i64, ptr %212, align 8
  %214 = getelementptr inbounds ptr, ptr %211, i32 1
  %215 = load ptr, ptr %214, align 8
  %216 = load i64, ptr %215, align 8
  %217 = mul i64 %213, %40
  %218 = mul i64 %216, 256
  %219 = add i64 %217, %218
  %220 = getelementptr inbounds bfloat, ptr %39, i64 %219
  %221 = getelementptr inbounds bfloat, ptr %220, i64 %71
  %222 = load i64, ptr %18, align 8
  %223 = mul i64 %222, 32
  %224 = add i64 %70, %223
  %225 = mul i64 %224, 8
  %226 = icmp slt i64 %225, %43
  br i1 %226, label %227, label %298

227:                                              ; preds = %208
  %228 = load <8 x bfloat>, ptr %221, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %92, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %229 = insertvalue [2 x ptr] undef, ptr %15, 0
  %230 = insertvalue [2 x ptr] %229, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %230, ptr %14, align 8
  %231 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %232 = load ptr, ptr %231, align 8
  %233 = load i64, ptr %232, align 8
  %234 = getelementptr inbounds ptr, ptr %231, i32 1
  %235 = load ptr, ptr %234, align 8
  %236 = load i64, ptr %235, align 8
  %237 = mul i64 %233, %38
  %238 = mul i64 %236, 256
  %239 = add i64 %237, %238
  %240 = getelementptr inbounds bfloat, ptr %37, i64 %239
  %241 = getelementptr inbounds bfloat, ptr %240, i64 %71
  %242 = load <8 x bfloat>, ptr %241, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %243 = fpext <8 x bfloat> %242 to <8 x float>
  %244 = fpext <8 x bfloat> %228 to <8 x float>
  %245 = fmul contract <8 x float> %243, %244
  %246 = fadd contract <8 x float> %115, %245
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %91, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %247 = insertvalue [2 x ptr] undef, ptr %13, 0
  %248 = insertvalue [2 x ptr] %247, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %248, ptr %12, align 8
  %249 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %250 = load ptr, ptr %249, align 8
  %251 = load i64, ptr %250, align 8
  %252 = getelementptr inbounds ptr, ptr %249, i32 1
  %253 = load ptr, ptr %252, align 8
  %254 = load i64, ptr %253, align 8
  %255 = mul i64 %251, %38
  %256 = mul i64 %254, 256
  %257 = add i64 %255, %256
  %258 = getelementptr inbounds bfloat, ptr %37, i64 %257
  %259 = getelementptr inbounds bfloat, ptr %258, i64 %71
  %260 = load <8 x bfloat>, ptr %259, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  %261 = fpext <8 x bfloat> %260 to <8 x float>
  %262 = fmul contract <8 x float> %261, %244
  %263 = fadd contract <8 x float> %116, %262
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %86, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %264 = insertvalue [2 x ptr] undef, ptr %11, 0
  %265 = insertvalue [2 x ptr] %264, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %265, ptr %10, align 8
  %266 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %267 = load ptr, ptr %266, align 8
  %268 = load i64, ptr %267, align 8
  %269 = getelementptr inbounds ptr, ptr %266, i32 1
  %270 = load ptr, ptr %269, align 8
  %271 = load i64, ptr %270, align 8
  %272 = mul i64 %268, %38
  %273 = mul i64 %271, 256
  %274 = add i64 %272, %273
  %275 = getelementptr inbounds bfloat, ptr %37, i64 %274
  %276 = getelementptr inbounds bfloat, ptr %275, i64 %71
  %277 = load <8 x bfloat>, ptr %276, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %278 = fpext <8 x bfloat> %277 to <8 x float>
  %279 = fmul contract <8 x float> %278, %244
  %280 = fadd contract <8 x float> %117, %279
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %81, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %281 = insertvalue [2 x ptr] undef, ptr %9, 0
  %282 = insertvalue [2 x ptr] %281, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %282, ptr %8, align 8
  %283 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %284 = load ptr, ptr %283, align 8
  %285 = load i64, ptr %284, align 8
  %286 = getelementptr inbounds ptr, ptr %283, i32 1
  %287 = load ptr, ptr %286, align 8
  %288 = load i64, ptr %287, align 8
  %289 = mul i64 %285, %38
  %290 = mul i64 %288, 256
  %291 = add i64 %289, %290
  %292 = getelementptr inbounds bfloat, ptr %37, i64 %291
  %293 = getelementptr inbounds bfloat, ptr %292, i64 %71
  %294 = load <8 x bfloat>, ptr %293, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %295 = fpext <8 x bfloat> %294 to <8 x float>
  %296 = fmul contract <8 x float> %295, %244
  %297 = fadd contract <8 x float> %118, %296
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %299

298:                                              ; preds = %208
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %299

299:                                              ; preds = %298, %227
  %300 = phi <8 x float> [ %115, %298 ], [ %246, %227 ]
  %301 = phi <8 x float> [ %116, %298 ], [ %263, %227 ]
  %302 = phi <8 x float> [ %117, %298 ], [ %280, %227 ]
  %303 = phi <8 x float> [ %118, %298 ], [ %297, %227 ]
  br label %305

304:                                              ; preds = %122
  br label %305

305:                                              ; preds = %304, %299
  %306 = phi <8 x float> [ %115, %304 ], [ %300, %299 ]
  %307 = phi <8 x float> [ %116, %304 ], [ %301, %299 ]
  %308 = phi <8 x float> [ %117, %304 ], [ %302, %299 ]
  %309 = phi <8 x float> [ %118, %304 ], [ %303, %299 ]
  %310 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %306, i64 0)
  %311 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %306, i64 4)
  %312 = fadd contract <4 x float> %310, %311
  %313 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %312, i64 0)
  %314 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %312, i64 2)
  %315 = fadd contract <2 x float> %313, %314
  %316 = extractelement <2 x float> %315, i64 0
  %317 = extractelement <2 x float> %315, i64 1
  %318 = fadd contract float %316, %317
  %319 = bitcast float %318 to i32
  %320 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %319, i32 16, i32 31)
  %321 = bitcast i32 %320 to float
  %322 = fadd contract float %318, %321
  %323 = bitcast float %322 to i32
  %324 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %323, i32 8, i32 31)
  %325 = bitcast i32 %324 to float
  %326 = fadd contract float %322, %325
  %327 = bitcast float %326 to i32
  %328 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %327, i32 4, i32 31)
  %329 = bitcast i32 %328 to float
  %330 = fadd contract float %326, %329
  %331 = bitcast float %330 to i32
  %332 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %331, i32 2, i32 31)
  %333 = bitcast i32 %332 to float
  %334 = fadd contract float %330, %333
  %335 = bitcast float %334 to i32
  %336 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %335, i32 1, i32 31)
  %337 = bitcast i32 %336 to float
  %338 = fadd contract float %334, %337
  %339 = fptrunc float %338 to bfloat
  %340 = fpext bfloat %339 to float
  %341 = fmul contract float %340, 2.000000e+00
  %342 = fptrunc float %341 to bfloat
  br i1 %76, label %343, label %344

343:                                              ; preds = %305
  store bfloat %342, ptr %74, align 2
  br label %345

344:                                              ; preds = %305
  br label %345

345:                                              ; preds = %344, %343
  %346 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %307, i64 0)
  %347 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %307, i64 4)
  %348 = fadd contract <4 x float> %346, %347
  %349 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %348, i64 0)
  %350 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %348, i64 2)
  %351 = fadd contract <2 x float> %349, %350
  %352 = extractelement <2 x float> %351, i64 0
  %353 = extractelement <2 x float> %351, i64 1
  %354 = fadd contract float %352, %353
  %355 = bitcast float %354 to i32
  %356 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %355, i32 16, i32 31)
  %357 = bitcast i32 %356 to float
  %358 = fadd contract float %354, %357
  %359 = bitcast float %358 to i32
  %360 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %359, i32 8, i32 31)
  %361 = bitcast i32 %360 to float
  %362 = fadd contract float %358, %361
  %363 = bitcast float %362 to i32
  %364 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %363, i32 4, i32 31)
  %365 = bitcast i32 %364 to float
  %366 = fadd contract float %362, %365
  %367 = bitcast float %366 to i32
  %368 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %367, i32 2, i32 31)
  %369 = bitcast i32 %368 to float
  %370 = fadd contract float %366, %369
  %371 = bitcast float %370 to i32
  %372 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %371, i32 1, i32 31)
  %373 = bitcast i32 %372 to float
  %374 = fadd contract float %370, %373
  %375 = fptrunc float %374 to bfloat
  %376 = fpext bfloat %375 to float
  %377 = fmul contract float %376, 2.000000e+00
  %378 = fptrunc float %377 to bfloat
  br i1 %90, label %379, label %380

379:                                              ; preds = %345
  store bfloat %378, ptr %88, align 2
  br label %381

380:                                              ; preds = %345
  br label %381

381:                                              ; preds = %380, %379
  %382 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %308, i64 0)
  %383 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %308, i64 4)
  %384 = fadd contract <4 x float> %382, %383
  %385 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %384, i64 0)
  %386 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %384, i64 2)
  %387 = fadd contract <2 x float> %385, %386
  %388 = extractelement <2 x float> %387, i64 0
  %389 = extractelement <2 x float> %387, i64 1
  %390 = fadd contract float %388, %389
  %391 = bitcast float %390 to i32
  %392 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %391, i32 16, i32 31)
  %393 = bitcast i32 %392 to float
  %394 = fadd contract float %390, %393
  %395 = bitcast float %394 to i32
  %396 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %395, i32 8, i32 31)
  %397 = bitcast i32 %396 to float
  %398 = fadd contract float %394, %397
  %399 = bitcast float %398 to i32
  %400 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %399, i32 4, i32 31)
  %401 = bitcast i32 %400 to float
  %402 = fadd contract float %398, %401
  %403 = bitcast float %402 to i32
  %404 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %403, i32 2, i32 31)
  %405 = bitcast i32 %404 to float
  %406 = fadd contract float %402, %405
  %407 = bitcast float %406 to i32
  %408 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %407, i32 1, i32 31)
  %409 = bitcast i32 %408 to float
  %410 = fadd contract float %406, %409
  %411 = fptrunc float %410 to bfloat
  %412 = fpext bfloat %411 to float
  %413 = fmul contract float %412, 2.000000e+00
  %414 = fptrunc float %413 to bfloat
  br i1 %85, label %415, label %416

415:                                              ; preds = %381
  store bfloat %414, ptr %83, align 2
  br label %417

416:                                              ; preds = %381
  br label %417

417:                                              ; preds = %416, %415
  %418 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %309, i64 0)
  %419 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %309, i64 4)
  %420 = fadd contract <4 x float> %418, %419
  %421 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %420, i64 0)
  %422 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %420, i64 2)
  %423 = fadd contract <2 x float> %421, %422
  %424 = extractelement <2 x float> %423, i64 0
  %425 = extractelement <2 x float> %423, i64 1
  %426 = fadd contract float %424, %425
  %427 = bitcast float %426 to i32
  %428 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %427, i32 16, i32 31)
  %429 = bitcast i32 %428 to float
  %430 = fadd contract float %426, %429
  %431 = bitcast float %430 to i32
  %432 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %431, i32 8, i32 31)
  %433 = bitcast i32 %432 to float
  %434 = fadd contract float %430, %433
  %435 = bitcast float %434 to i32
  %436 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %435, i32 4, i32 31)
  %437 = bitcast i32 %436 to float
  %438 = fadd contract float %434, %437
  %439 = bitcast float %438 to i32
  %440 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %439, i32 2, i32 31)
  %441 = bitcast i32 %440 to float
  %442 = fadd contract float %438, %441
  %443 = bitcast float %442 to i32
  %444 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %443, i32 1, i32 31)
  %445 = bitcast i32 %444 to float
  %446 = fadd contract float %442, %445
  %447 = fptrunc float %446 to bfloat
  %448 = fpext bfloat %447 to float
  %449 = fmul contract float %448, 2.000000e+00
  %450 = fptrunc float %449 to bfloat
  br i1 %80, label %451, label %452

451:                                              ; preds = %417
  store bfloat %450, ptr %78, align 2
  br label %453

452:                                              ; preds = %417
  br label %453

453:                                              ; preds = %452, %451
  br label %454

454:                                              ; preds = %453, %94
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
declare <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float>, i64 immarg) #1

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
