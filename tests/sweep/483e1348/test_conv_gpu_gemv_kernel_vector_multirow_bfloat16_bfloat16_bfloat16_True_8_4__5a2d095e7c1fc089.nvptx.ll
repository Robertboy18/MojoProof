; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_bfloat16_bfloat16_bfloat16_True_8_4_1c1953d9(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca [2 x ptr], i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i64, i64 1, align 8
  %15 = alloca [2 x ptr], i64 1, align 8
  %16 = alloca i64, i64 1, align 8
  %17 = alloca i64, i64 1, align 8
  %18 = alloca [2 x ptr], i64 1, align 8
  %19 = alloca i64, i64 1, align 8
  %20 = alloca [2 x ptr], i64 1, align 8
  %21 = alloca i64, i64 1, align 8
  %22 = alloca [2 x ptr], i64 1, align 8
  %23 = alloca i64, i64 1, align 8
  %24 = alloca [2 x ptr], i64 1, align 8
  %25 = alloca i64, i64 1, align 8
  %26 = alloca [2 x ptr], i64 1, align 8
  %27 = alloca i64, i64 1, align 8
  %28 = alloca i64, i64 1, align 8
  %29 = alloca [2 x ptr], i64 1, align 8
  %30 = alloca i32, i64 1, align 4
  %31 = alloca i32, i64 1, align 4
  %32 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %33 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %34 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %35 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %34, 0
  %36 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %33, 0
  %37 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %33, 1, 1, 0
  %38 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %32, 0
  %39 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %32, 1, 1, 0
  %40 = sext i32 %3 to i64
  %41 = sub i64 %40, 1
  %42 = sext i32 %5 to i64
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %44 = zext i32 %43 to i64
  %45 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %46 = zext i32 %45 to i64
  %47 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %48 = sext i32 %47 to i64
  %49 = mul i64 %46, %48
  %50 = add i64 %49, %44
  %51 = udiv i64 %50, 32
  %52 = bitcast i64 %51 to <2 x i32>
  %53 = extractelement <2 x i32> %52, i64 0
  %54 = extractelement <2 x i32> %52, i64 1
  %55 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %53, i32 0, i32 31)
  %56 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %54, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i32 %55, ptr %31, align 4
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.start.p0(ptr %30)
  store i32 %56, ptr %30, align 4
  call void @llvm.lifetime.end.p0(ptr %29)
  %57 = insertvalue [2 x ptr] undef, ptr %31, 0
  %58 = insertvalue [2 x ptr] %57, ptr %30, 1
  call void @llvm.lifetime.start.p0(ptr %29)
  store [2 x ptr] %58, ptr %29, align 8
  %59 = getelementptr inbounds [2 x ptr], ptr %29, i32 0, i32 0
  %60 = load ptr, ptr %59, align 8
  %61 = load i32, ptr %60, align 4
  %62 = insertelement <2 x i32> undef, i32 %61, i64 0
  %63 = getelementptr inbounds ptr, ptr %59, i32 1
  %64 = load ptr, ptr %63, align 8
  %65 = load i32, ptr %64, align 4
  %66 = insertelement <2 x i32> %62, i32 %65, i64 1
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  %67 = bitcast <2 x i32> %66 to i64
  %68 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %69 = sext i32 %68 to i64
  %70 = mul i64 %69, 8
  %71 = icmp eq i64 %69, 0
  %72 = mul i64 %67, 4
  %73 = getelementptr inbounds bfloat, ptr %35, i64 %72
  %74 = icmp slt i64 %72, %40
  %75 = select i1 %71, i1 %74, i1 false
  %76 = add i64 %72, 3
  %77 = getelementptr inbounds bfloat, ptr %35, i64 %76
  %78 = icmp slt i64 %76, %40
  %79 = select i1 %71, i1 %78, i1 false
  %80 = call i64 @llvm.smin.i64(i64 %76, i64 %41)
  %81 = add i64 %72, 2
  %82 = getelementptr inbounds bfloat, ptr %35, i64 %81
  %83 = icmp slt i64 %81, %40
  %84 = select i1 %71, i1 %83, i1 false
  %85 = call i64 @llvm.smin.i64(i64 %81, i64 %41)
  %86 = add i64 %72, 1
  %87 = getelementptr inbounds bfloat, ptr %35, i64 %86
  %88 = icmp slt i64 %86, %40
  %89 = select i1 %71, i1 %88, i1 false
  %90 = call i64 @llvm.smin.i64(i64 %86, i64 %41)
  %91 = call i64 @llvm.smin.i64(i64 %72, i64 %41)
  %92 = icmp sge i64 %72, %40
  br i1 %92, label %93, label %94

93:                                               ; preds = %6
  br label %441

94:                                               ; preds = %6
  %95 = sdiv i64 %42, 8
  %96 = mul i64 %95, 8
  %97 = icmp eq i64 %96, %42
  %98 = xor i64 %42, 8
  %99 = ashr i64 %98, 63
  %100 = select i1 %97, i64 0, i64 %99
  %101 = add i64 %95, %100
  %102 = sdiv i64 %101, -32
  %103 = mul i64 %102, -32
  %104 = icmp eq i64 %103, %101
  %105 = xor i64 %101, -32
  %106 = ashr i64 %105, 63
  %107 = select i1 %104, i64 0, i64 %106
  %108 = add i64 %102, %107
  %109 = sub i64 0, %108
  %110 = sub i64 %109, 1
  %111 = call i64 @llvm.smax.i64(i64 %110, i64 0)
  br label %112

112:                                              ; preds = %123, %94
  %113 = phi i64 [ 0, %94 ], [ %120, %123 ]
  %114 = phi <8 x float> [ zeroinitializer, %94 ], [ %155, %123 ]
  %115 = phi <8 x float> [ zeroinitializer, %94 ], [ %172, %123 ]
  %116 = phi <8 x float> [ zeroinitializer, %94 ], [ %189, %123 ]
  %117 = phi <8 x float> [ zeroinitializer, %94 ], [ %206, %123 ]
  call void @llvm.lifetime.end.p0(ptr %28)
  %118 = icmp eq i64 %113, %111
  %119 = add i64 %113, 1
  %120 = select i1 %118, i64 %113, i64 %119
  br i1 %118, label %121, label %123

121:                                              ; preds = %112
  %122 = icmp sgt i64 %109, 0
  br i1 %122, label %207, label %303

123:                                              ; preds = %112
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 %113, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 0, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  %124 = insertvalue [2 x ptr] undef, ptr %27, 0
  %125 = insertvalue [2 x ptr] %124, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %26)
  store [2 x ptr] %125, ptr %26, align 8
  %126 = getelementptr inbounds [2 x ptr], ptr %26, i32 0, i32 0
  %127 = load ptr, ptr %126, align 8
  %128 = load i64, ptr %127, align 8
  %129 = getelementptr inbounds ptr, ptr %126, i32 1
  %130 = load ptr, ptr %129, align 8
  %131 = load i64, ptr %130, align 8
  %132 = mul i64 %128, %39
  %133 = mul i64 %131, 256
  %134 = add i64 %132, %133
  %135 = getelementptr inbounds bfloat, ptr %38, i64 %134
  %136 = getelementptr inbounds bfloat, ptr %135, i64 %70
  %137 = load <8 x bfloat>, ptr %136, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.start.p0(ptr %25)
  store i64 %91, ptr %25, align 8
  call void @llvm.lifetime.end.p0(ptr %24)
  %138 = insertvalue [2 x ptr] undef, ptr %25, 0
  %139 = insertvalue [2 x ptr] %138, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %24)
  store [2 x ptr] %139, ptr %24, align 8
  %140 = getelementptr inbounds [2 x ptr], ptr %24, i32 0, i32 0
  %141 = load ptr, ptr %140, align 8
  %142 = load i64, ptr %141, align 8
  %143 = getelementptr inbounds ptr, ptr %140, i32 1
  %144 = load ptr, ptr %143, align 8
  %145 = load i64, ptr %144, align 8
  %146 = mul i64 %142, %37
  %147 = mul i64 %145, 256
  %148 = add i64 %146, %147
  %149 = getelementptr inbounds bfloat, ptr %36, i64 %148
  %150 = getelementptr inbounds bfloat, ptr %149, i64 %70
  %151 = load <8 x bfloat>, ptr %150, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %25)
  %152 = fpext <8 x bfloat> %151 to <8 x float>
  %153 = fpext <8 x bfloat> %137 to <8 x float>
  %154 = fmul contract <8 x float> %152, %153
  %155 = fadd contract <8 x float> %114, %154
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %90, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %156 = insertvalue [2 x ptr] undef, ptr %23, 0
  %157 = insertvalue [2 x ptr] %156, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %157, ptr %22, align 8
  %158 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %159 = load ptr, ptr %158, align 8
  %160 = load i64, ptr %159, align 8
  %161 = getelementptr inbounds ptr, ptr %158, i32 1
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = mul i64 %160, %37
  %165 = mul i64 %163, 256
  %166 = add i64 %164, %165
  %167 = getelementptr inbounds bfloat, ptr %36, i64 %166
  %168 = getelementptr inbounds bfloat, ptr %167, i64 %70
  %169 = load <8 x bfloat>, ptr %168, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  %170 = fpext <8 x bfloat> %169 to <8 x float>
  %171 = fmul contract <8 x float> %170, %153
  %172 = fadd contract <8 x float> %115, %171
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %85, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  %173 = insertvalue [2 x ptr] undef, ptr %21, 0
  %174 = insertvalue [2 x ptr] %173, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %20)
  store [2 x ptr] %174, ptr %20, align 8
  %175 = getelementptr inbounds [2 x ptr], ptr %20, i32 0, i32 0
  %176 = load ptr, ptr %175, align 8
  %177 = load i64, ptr %176, align 8
  %178 = getelementptr inbounds ptr, ptr %175, i32 1
  %179 = load ptr, ptr %178, align 8
  %180 = load i64, ptr %179, align 8
  %181 = mul i64 %177, %37
  %182 = mul i64 %180, 256
  %183 = add i64 %181, %182
  %184 = getelementptr inbounds bfloat, ptr %36, i64 %183
  %185 = getelementptr inbounds bfloat, ptr %184, i64 %70
  %186 = load <8 x bfloat>, ptr %185, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %187 = fpext <8 x bfloat> %186 to <8 x float>
  %188 = fmul contract <8 x float> %187, %153
  %189 = fadd contract <8 x float> %116, %188
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %80, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  %190 = insertvalue [2 x ptr] undef, ptr %19, 0
  %191 = insertvalue [2 x ptr] %190, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %18)
  store [2 x ptr] %191, ptr %18, align 8
  %192 = getelementptr inbounds [2 x ptr], ptr %18, i32 0, i32 0
  %193 = load ptr, ptr %192, align 8
  %194 = load i64, ptr %193, align 8
  %195 = getelementptr inbounds ptr, ptr %192, i32 1
  %196 = load ptr, ptr %195, align 8
  %197 = load i64, ptr %196, align 8
  %198 = mul i64 %194, %37
  %199 = mul i64 %197, 256
  %200 = add i64 %198, %199
  %201 = getelementptr inbounds bfloat, ptr %36, i64 %200
  %202 = getelementptr inbounds bfloat, ptr %201, i64 %70
  %203 = load <8 x bfloat>, ptr %202, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %204 = fpext <8 x bfloat> %203 to <8 x float>
  %205 = fmul contract <8 x float> %204, %153
  %206 = fadd contract <8 x float> %117, %205
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  br label %112

207:                                              ; preds = %121
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %110, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 0, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  %208 = insertvalue [2 x ptr] undef, ptr %16, 0
  %209 = insertvalue [2 x ptr] %208, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %15)
  store [2 x ptr] %209, ptr %15, align 8
  %210 = getelementptr inbounds [2 x ptr], ptr %15, i32 0, i32 0
  %211 = load ptr, ptr %210, align 8
  %212 = load i64, ptr %211, align 8
  %213 = getelementptr inbounds ptr, ptr %210, i32 1
  %214 = load ptr, ptr %213, align 8
  %215 = load i64, ptr %214, align 8
  %216 = mul i64 %212, %39
  %217 = mul i64 %215, 256
  %218 = add i64 %216, %217
  %219 = getelementptr inbounds bfloat, ptr %38, i64 %218
  %220 = getelementptr inbounds bfloat, ptr %219, i64 %70
  %221 = load i64, ptr %17, align 8
  %222 = mul i64 %221, 32
  %223 = add i64 %69, %222
  %224 = mul i64 %223, 8
  %225 = icmp slt i64 %224, %42
  br i1 %225, label %226, label %297

226:                                              ; preds = %207
  %227 = load <8 x bfloat>, ptr %220, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %91, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %228 = insertvalue [2 x ptr] undef, ptr %14, 0
  %229 = insertvalue [2 x ptr] %228, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %229, ptr %13, align 8
  %230 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %231 = load ptr, ptr %230, align 8
  %232 = load i64, ptr %231, align 8
  %233 = getelementptr inbounds ptr, ptr %230, i32 1
  %234 = load ptr, ptr %233, align 8
  %235 = load i64, ptr %234, align 8
  %236 = mul i64 %232, %37
  %237 = mul i64 %235, 256
  %238 = add i64 %236, %237
  %239 = getelementptr inbounds bfloat, ptr %36, i64 %238
  %240 = getelementptr inbounds bfloat, ptr %239, i64 %70
  %241 = load <8 x bfloat>, ptr %240, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %242 = fpext <8 x bfloat> %241 to <8 x float>
  %243 = fpext <8 x bfloat> %227 to <8 x float>
  %244 = fmul contract <8 x float> %242, %243
  %245 = fadd contract <8 x float> %114, %244
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %90, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %246 = insertvalue [2 x ptr] undef, ptr %12, 0
  %247 = insertvalue [2 x ptr] %246, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %247, ptr %11, align 8
  %248 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %249 = load ptr, ptr %248, align 8
  %250 = load i64, ptr %249, align 8
  %251 = getelementptr inbounds ptr, ptr %248, i32 1
  %252 = load ptr, ptr %251, align 8
  %253 = load i64, ptr %252, align 8
  %254 = mul i64 %250, %37
  %255 = mul i64 %253, 256
  %256 = add i64 %254, %255
  %257 = getelementptr inbounds bfloat, ptr %36, i64 %256
  %258 = getelementptr inbounds bfloat, ptr %257, i64 %70
  %259 = load <8 x bfloat>, ptr %258, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  %260 = fpext <8 x bfloat> %259 to <8 x float>
  %261 = fmul contract <8 x float> %260, %243
  %262 = fadd contract <8 x float> %115, %261
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %85, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %263 = insertvalue [2 x ptr] undef, ptr %10, 0
  %264 = insertvalue [2 x ptr] %263, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %264, ptr %9, align 8
  %265 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %266 = load ptr, ptr %265, align 8
  %267 = load i64, ptr %266, align 8
  %268 = getelementptr inbounds ptr, ptr %265, i32 1
  %269 = load ptr, ptr %268, align 8
  %270 = load i64, ptr %269, align 8
  %271 = mul i64 %267, %37
  %272 = mul i64 %270, 256
  %273 = add i64 %271, %272
  %274 = getelementptr inbounds bfloat, ptr %36, i64 %273
  %275 = getelementptr inbounds bfloat, ptr %274, i64 %70
  %276 = load <8 x bfloat>, ptr %275, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %277 = fpext <8 x bfloat> %276 to <8 x float>
  %278 = fmul contract <8 x float> %277, %243
  %279 = fadd contract <8 x float> %116, %278
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %80, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %280 = insertvalue [2 x ptr] undef, ptr %8, 0
  %281 = insertvalue [2 x ptr] %280, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %281, ptr %7, align 8
  %282 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %283 = load ptr, ptr %282, align 8
  %284 = load i64, ptr %283, align 8
  %285 = getelementptr inbounds ptr, ptr %282, i32 1
  %286 = load ptr, ptr %285, align 8
  %287 = load i64, ptr %286, align 8
  %288 = mul i64 %284, %37
  %289 = mul i64 %287, 256
  %290 = add i64 %288, %289
  %291 = getelementptr inbounds bfloat, ptr %36, i64 %290
  %292 = getelementptr inbounds bfloat, ptr %291, i64 %70
  %293 = load <8 x bfloat>, ptr %292, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %294 = fpext <8 x bfloat> %293 to <8 x float>
  %295 = fmul contract <8 x float> %294, %243
  %296 = fadd contract <8 x float> %117, %295
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %298

297:                                              ; preds = %207
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %298

298:                                              ; preds = %297, %226
  %299 = phi <8 x float> [ %114, %297 ], [ %245, %226 ]
  %300 = phi <8 x float> [ %115, %297 ], [ %262, %226 ]
  %301 = phi <8 x float> [ %116, %297 ], [ %279, %226 ]
  %302 = phi <8 x float> [ %117, %297 ], [ %296, %226 ]
  br label %304

303:                                              ; preds = %121
  br label %304

304:                                              ; preds = %303, %298
  %305 = phi <8 x float> [ %114, %303 ], [ %299, %298 ]
  %306 = phi <8 x float> [ %115, %303 ], [ %300, %298 ]
  %307 = phi <8 x float> [ %116, %303 ], [ %301, %298 ]
  %308 = phi <8 x float> [ %117, %303 ], [ %302, %298 ]
  %309 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %305, i64 0)
  %310 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %305, i64 4)
  %311 = fadd contract <4 x float> %309, %310
  %312 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %311, i64 0)
  %313 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %311, i64 2)
  %314 = fadd contract <2 x float> %312, %313
  %315 = extractelement <2 x float> %314, i64 0
  %316 = extractelement <2 x float> %314, i64 1
  %317 = fadd contract float %315, %316
  %318 = bitcast float %317 to i32
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 16, i32 31)
  %320 = bitcast i32 %319 to float
  %321 = fadd contract float %317, %320
  %322 = bitcast float %321 to i32
  %323 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %322, i32 8, i32 31)
  %324 = bitcast i32 %323 to float
  %325 = fadd contract float %321, %324
  %326 = bitcast float %325 to i32
  %327 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %326, i32 4, i32 31)
  %328 = bitcast i32 %327 to float
  %329 = fadd contract float %325, %328
  %330 = bitcast float %329 to i32
  %331 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %330, i32 2, i32 31)
  %332 = bitcast i32 %331 to float
  %333 = fadd contract float %329, %332
  %334 = bitcast float %333 to i32
  %335 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %334, i32 1, i32 31)
  %336 = bitcast i32 %335 to float
  %337 = fadd contract float %333, %336
  %338 = fptrunc float %337 to bfloat
  br i1 %75, label %339, label %340

339:                                              ; preds = %304
  store bfloat %338, ptr %73, align 2
  br label %341

340:                                              ; preds = %304
  br label %341

341:                                              ; preds = %340, %339
  %342 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %306, i64 0)
  %343 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %306, i64 4)
  %344 = fadd contract <4 x float> %342, %343
  %345 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %344, i64 0)
  %346 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %344, i64 2)
  %347 = fadd contract <2 x float> %345, %346
  %348 = extractelement <2 x float> %347, i64 0
  %349 = extractelement <2 x float> %347, i64 1
  %350 = fadd contract float %348, %349
  %351 = bitcast float %350 to i32
  %352 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %351, i32 16, i32 31)
  %353 = bitcast i32 %352 to float
  %354 = fadd contract float %350, %353
  %355 = bitcast float %354 to i32
  %356 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %355, i32 8, i32 31)
  %357 = bitcast i32 %356 to float
  %358 = fadd contract float %354, %357
  %359 = bitcast float %358 to i32
  %360 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %359, i32 4, i32 31)
  %361 = bitcast i32 %360 to float
  %362 = fadd contract float %358, %361
  %363 = bitcast float %362 to i32
  %364 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %363, i32 2, i32 31)
  %365 = bitcast i32 %364 to float
  %366 = fadd contract float %362, %365
  %367 = bitcast float %366 to i32
  %368 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %367, i32 1, i32 31)
  %369 = bitcast i32 %368 to float
  %370 = fadd contract float %366, %369
  %371 = fptrunc float %370 to bfloat
  br i1 %89, label %372, label %373

372:                                              ; preds = %341
  store bfloat %371, ptr %87, align 2
  br label %374

373:                                              ; preds = %341
  br label %374

374:                                              ; preds = %373, %372
  %375 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %307, i64 0)
  %376 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %307, i64 4)
  %377 = fadd contract <4 x float> %375, %376
  %378 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %377, i64 0)
  %379 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %377, i64 2)
  %380 = fadd contract <2 x float> %378, %379
  %381 = extractelement <2 x float> %380, i64 0
  %382 = extractelement <2 x float> %380, i64 1
  %383 = fadd contract float %381, %382
  %384 = bitcast float %383 to i32
  %385 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %384, i32 16, i32 31)
  %386 = bitcast i32 %385 to float
  %387 = fadd contract float %383, %386
  %388 = bitcast float %387 to i32
  %389 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %388, i32 8, i32 31)
  %390 = bitcast i32 %389 to float
  %391 = fadd contract float %387, %390
  %392 = bitcast float %391 to i32
  %393 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %392, i32 4, i32 31)
  %394 = bitcast i32 %393 to float
  %395 = fadd contract float %391, %394
  %396 = bitcast float %395 to i32
  %397 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %396, i32 2, i32 31)
  %398 = bitcast i32 %397 to float
  %399 = fadd contract float %395, %398
  %400 = bitcast float %399 to i32
  %401 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %400, i32 1, i32 31)
  %402 = bitcast i32 %401 to float
  %403 = fadd contract float %399, %402
  %404 = fptrunc float %403 to bfloat
  br i1 %84, label %405, label %406

405:                                              ; preds = %374
  store bfloat %404, ptr %82, align 2
  br label %407

406:                                              ; preds = %374
  br label %407

407:                                              ; preds = %406, %405
  %408 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %308, i64 0)
  %409 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %308, i64 4)
  %410 = fadd contract <4 x float> %408, %409
  %411 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %410, i64 0)
  %412 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %410, i64 2)
  %413 = fadd contract <2 x float> %411, %412
  %414 = extractelement <2 x float> %413, i64 0
  %415 = extractelement <2 x float> %413, i64 1
  %416 = fadd contract float %414, %415
  %417 = bitcast float %416 to i32
  %418 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %417, i32 16, i32 31)
  %419 = bitcast i32 %418 to float
  %420 = fadd contract float %416, %419
  %421 = bitcast float %420 to i32
  %422 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %421, i32 8, i32 31)
  %423 = bitcast i32 %422 to float
  %424 = fadd contract float %420, %423
  %425 = bitcast float %424 to i32
  %426 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %425, i32 4, i32 31)
  %427 = bitcast i32 %426 to float
  %428 = fadd contract float %424, %427
  %429 = bitcast float %428 to i32
  %430 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %429, i32 2, i32 31)
  %431 = bitcast i32 %430 to float
  %432 = fadd contract float %428, %431
  %433 = bitcast float %432 to i32
  %434 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %433, i32 1, i32 31)
  %435 = bitcast i32 %434 to float
  %436 = fadd contract float %432, %435
  %437 = fptrunc float %436 to bfloat
  br i1 %79, label %438, label %439

438:                                              ; preds = %407
  store bfloat %437, ptr %77, align 2
  br label %440

439:                                              ; preds = %407
  br label %440

440:                                              ; preds = %439, %438
  br label %441

441:                                              ; preds = %440, %93
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
