; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_bfloat16_bfloat16_bfloat16_True_8_4_7da0489b(ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %32 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %2, align 8
  %33 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %34 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %0, align 8
  %35 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %34, 0
  %36 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %33, 0
  %37 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %32, 0
  %38 = sext i32 %3 to i64
  %39 = sub i64 %38, 1
  %40 = sext i32 %5 to i64
  %41 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %42 = zext i32 %41 to i64
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %44 = zext i32 %43 to i64
  %45 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %46 = sext i32 %45 to i64
  %47 = mul i64 %44, %46
  %48 = add i64 %47, %42
  %49 = udiv i64 %48, 32
  %50 = bitcast i64 %49 to <2 x i32>
  %51 = extractelement <2 x i32> %50, i64 0
  %52 = extractelement <2 x i32> %50, i64 1
  %53 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %51, i32 0, i32 31)
  %54 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %52, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i32 %53, ptr %31, align 4
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.start.p0(ptr %30)
  store i32 %54, ptr %30, align 4
  call void @llvm.lifetime.end.p0(ptr %29)
  %55 = insertvalue [2 x ptr] undef, ptr %31, 0
  %56 = insertvalue [2 x ptr] %55, ptr %30, 1
  call void @llvm.lifetime.start.p0(ptr %29)
  store [2 x ptr] %56, ptr %29, align 8
  %57 = getelementptr inbounds [2 x ptr], ptr %29, i32 0, i32 0
  %58 = load ptr, ptr %57, align 8
  %59 = load i32, ptr %58, align 4
  %60 = insertelement <2 x i32> undef, i32 %59, i64 0
  %61 = getelementptr inbounds ptr, ptr %57, i32 1
  %62 = load ptr, ptr %61, align 8
  %63 = load i32, ptr %62, align 4
  %64 = insertelement <2 x i32> %60, i32 %63, i64 1
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  %65 = bitcast <2 x i32> %64 to i64
  %66 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %67 = sext i32 %66 to i64
  %68 = trunc i64 %67 to i32
  %69 = mul i32 %68, 8
  %70 = sext i32 %69 to i64
  %71 = icmp eq i64 %67, 0
  %72 = mul i64 %65, 4
  %73 = trunc i64 %72 to i32
  %74 = sext i32 %73 to i64
  %75 = getelementptr inbounds bfloat, ptr %35, i64 %74
  %76 = icmp slt i64 %72, %38
  %77 = select i1 %71, i1 %76, i1 false
  %78 = add i64 %72, 3
  %79 = trunc i64 %78 to i32
  %80 = sext i32 %79 to i64
  %81 = getelementptr inbounds bfloat, ptr %35, i64 %80
  %82 = icmp slt i64 %78, %38
  %83 = select i1 %71, i1 %82, i1 false
  %84 = call i64 @llvm.smin.i64(i64 %78, i64 %39)
  %85 = add i64 %72, 2
  %86 = trunc i64 %85 to i32
  %87 = sext i32 %86 to i64
  %88 = getelementptr inbounds bfloat, ptr %35, i64 %87
  %89 = icmp slt i64 %85, %38
  %90 = select i1 %71, i1 %89, i1 false
  %91 = call i64 @llvm.smin.i64(i64 %85, i64 %39)
  %92 = add i64 %72, 1
  %93 = trunc i64 %92 to i32
  %94 = sext i32 %93 to i64
  %95 = getelementptr inbounds bfloat, ptr %35, i64 %94
  %96 = icmp slt i64 %92, %38
  %97 = select i1 %71, i1 %96, i1 false
  %98 = call i64 @llvm.smin.i64(i64 %92, i64 %39)
  %99 = call i64 @llvm.smin.i64(i64 %72, i64 %39)
  %100 = icmp sge i64 %72, %38
  br i1 %100, label %101, label %102

101:                                              ; preds = %6
  br label %479

102:                                              ; preds = %6
  %103 = sdiv i64 %40, 8
  %104 = mul i64 %103, 8
  %105 = icmp eq i64 %104, %40
  %106 = xor i64 %40, 8
  %107 = ashr i64 %106, 63
  %108 = select i1 %105, i64 0, i64 %107
  %109 = add i64 %103, %108
  %110 = sdiv i64 %109, -32
  %111 = mul i64 %110, -32
  %112 = icmp eq i64 %111, %109
  %113 = xor i64 %109, -32
  %114 = ashr i64 %113, 63
  %115 = select i1 %112, i64 0, i64 %114
  %116 = add i64 %110, %115
  %117 = sub i64 0, %116
  %118 = sub i64 %117, 1
  %119 = call i64 @llvm.smax.i64(i64 %118, i64 0)
  br label %120

120:                                              ; preds = %131, %102
  %121 = phi i64 [ 0, %102 ], [ %128, %131 ]
  %122 = phi <8 x float> [ zeroinitializer, %102 ], [ %169, %131 ]
  %123 = phi <8 x float> [ zeroinitializer, %102 ], [ %189, %131 ]
  %124 = phi <8 x float> [ zeroinitializer, %102 ], [ %209, %131 ]
  %125 = phi <8 x float> [ zeroinitializer, %102 ], [ %229, %131 ]
  call void @llvm.lifetime.end.p0(ptr %28)
  %126 = icmp eq i64 %121, %119
  %127 = add i64 %121, 1
  %128 = select i1 %126, i64 %121, i64 %127
  br i1 %126, label %129, label %131

129:                                              ; preds = %120
  %130 = icmp sgt i64 %117, 0
  br i1 %130, label %230, label %341

131:                                              ; preds = %120
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 %121, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 0, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  %132 = insertvalue [2 x ptr] undef, ptr %27, 0
  %133 = insertvalue [2 x ptr] %132, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %26)
  store [2 x ptr] %133, ptr %26, align 8
  %134 = getelementptr inbounds [2 x ptr], ptr %26, i32 0, i32 0
  %135 = load ptr, ptr %134, align 8
  %136 = load i64, ptr %135, align 8
  %137 = trunc i64 %136 to i32
  %138 = getelementptr inbounds ptr, ptr %134, i32 1
  %139 = load ptr, ptr %138, align 8
  %140 = load i64, ptr %139, align 8
  %141 = trunc i64 %140 to i32
  %142 = mul i32 %137, 200
  %143 = mul i32 %141, 256
  %144 = add i32 %142, %143
  %145 = sext i32 %144 to i64
  %146 = getelementptr inbounds bfloat, ptr %37, i64 %145
  %147 = getelementptr inbounds bfloat, ptr %146, i64 %70
  %148 = load <8 x bfloat>, ptr %147, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.start.p0(ptr %25)
  store i64 %99, ptr %25, align 8
  call void @llvm.lifetime.end.p0(ptr %24)
  %149 = insertvalue [2 x ptr] undef, ptr %25, 0
  %150 = insertvalue [2 x ptr] %149, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %24)
  store [2 x ptr] %150, ptr %24, align 8
  %151 = getelementptr inbounds [2 x ptr], ptr %24, i32 0, i32 0
  %152 = load ptr, ptr %151, align 8
  %153 = load i64, ptr %152, align 8
  %154 = trunc i64 %153 to i32
  %155 = getelementptr inbounds ptr, ptr %151, i32 1
  %156 = load ptr, ptr %155, align 8
  %157 = load i64, ptr %156, align 8
  %158 = trunc i64 %157 to i32
  %159 = mul i32 %154, 200
  %160 = mul i32 %158, 256
  %161 = add i32 %159, %160
  %162 = sext i32 %161 to i64
  %163 = getelementptr inbounds bfloat, ptr %36, i64 %162
  %164 = getelementptr inbounds bfloat, ptr %163, i64 %70
  %165 = load <8 x bfloat>, ptr %164, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %25)
  %166 = fpext <8 x bfloat> %165 to <8 x float>
  %167 = fpext <8 x bfloat> %148 to <8 x float>
  %168 = fmul contract <8 x float> %166, %167
  %169 = fadd contract <8 x float> %122, %168
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %98, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %170 = insertvalue [2 x ptr] undef, ptr %23, 0
  %171 = insertvalue [2 x ptr] %170, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %171, ptr %22, align 8
  %172 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %173 = load ptr, ptr %172, align 8
  %174 = load i64, ptr %173, align 8
  %175 = trunc i64 %174 to i32
  %176 = getelementptr inbounds ptr, ptr %172, i32 1
  %177 = load ptr, ptr %176, align 8
  %178 = load i64, ptr %177, align 8
  %179 = trunc i64 %178 to i32
  %180 = mul i32 %175, 200
  %181 = mul i32 %179, 256
  %182 = add i32 %180, %181
  %183 = sext i32 %182 to i64
  %184 = getelementptr inbounds bfloat, ptr %36, i64 %183
  %185 = getelementptr inbounds bfloat, ptr %184, i64 %70
  %186 = load <8 x bfloat>, ptr %185, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  %187 = fpext <8 x bfloat> %186 to <8 x float>
  %188 = fmul contract <8 x float> %187, %167
  %189 = fadd contract <8 x float> %123, %188
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %91, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  %190 = insertvalue [2 x ptr] undef, ptr %21, 0
  %191 = insertvalue [2 x ptr] %190, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %20)
  store [2 x ptr] %191, ptr %20, align 8
  %192 = getelementptr inbounds [2 x ptr], ptr %20, i32 0, i32 0
  %193 = load ptr, ptr %192, align 8
  %194 = load i64, ptr %193, align 8
  %195 = trunc i64 %194 to i32
  %196 = getelementptr inbounds ptr, ptr %192, i32 1
  %197 = load ptr, ptr %196, align 8
  %198 = load i64, ptr %197, align 8
  %199 = trunc i64 %198 to i32
  %200 = mul i32 %195, 200
  %201 = mul i32 %199, 256
  %202 = add i32 %200, %201
  %203 = sext i32 %202 to i64
  %204 = getelementptr inbounds bfloat, ptr %36, i64 %203
  %205 = getelementptr inbounds bfloat, ptr %204, i64 %70
  %206 = load <8 x bfloat>, ptr %205, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %207 = fpext <8 x bfloat> %206 to <8 x float>
  %208 = fmul contract <8 x float> %207, %167
  %209 = fadd contract <8 x float> %124, %208
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %84, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  %210 = insertvalue [2 x ptr] undef, ptr %19, 0
  %211 = insertvalue [2 x ptr] %210, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %18)
  store [2 x ptr] %211, ptr %18, align 8
  %212 = getelementptr inbounds [2 x ptr], ptr %18, i32 0, i32 0
  %213 = load ptr, ptr %212, align 8
  %214 = load i64, ptr %213, align 8
  %215 = trunc i64 %214 to i32
  %216 = getelementptr inbounds ptr, ptr %212, i32 1
  %217 = load ptr, ptr %216, align 8
  %218 = load i64, ptr %217, align 8
  %219 = trunc i64 %218 to i32
  %220 = mul i32 %215, 200
  %221 = mul i32 %219, 256
  %222 = add i32 %220, %221
  %223 = sext i32 %222 to i64
  %224 = getelementptr inbounds bfloat, ptr %36, i64 %223
  %225 = getelementptr inbounds bfloat, ptr %224, i64 %70
  %226 = load <8 x bfloat>, ptr %225, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %227 = fpext <8 x bfloat> %226 to <8 x float>
  %228 = fmul contract <8 x float> %227, %167
  %229 = fadd contract <8 x float> %125, %228
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  br label %120

230:                                              ; preds = %129
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %118, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 0, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  %231 = insertvalue [2 x ptr] undef, ptr %16, 0
  %232 = insertvalue [2 x ptr] %231, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %15)
  store [2 x ptr] %232, ptr %15, align 8
  %233 = getelementptr inbounds [2 x ptr], ptr %15, i32 0, i32 0
  %234 = load ptr, ptr %233, align 8
  %235 = load i64, ptr %234, align 8
  %236 = trunc i64 %235 to i32
  %237 = getelementptr inbounds ptr, ptr %233, i32 1
  %238 = load ptr, ptr %237, align 8
  %239 = load i64, ptr %238, align 8
  %240 = trunc i64 %239 to i32
  %241 = mul i32 %236, 200
  %242 = mul i32 %240, 256
  %243 = add i32 %241, %242
  %244 = sext i32 %243 to i64
  %245 = getelementptr inbounds bfloat, ptr %37, i64 %244
  %246 = getelementptr inbounds bfloat, ptr %245, i64 %70
  %247 = load i64, ptr %17, align 8
  %248 = mul i64 %247, 32
  %249 = add i64 %67, %248
  %250 = mul i64 %249, 8
  %251 = icmp slt i64 %250, %40
  br i1 %251, label %252, label %335

252:                                              ; preds = %230
  %253 = load <8 x bfloat>, ptr %246, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %99, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %254 = insertvalue [2 x ptr] undef, ptr %14, 0
  %255 = insertvalue [2 x ptr] %254, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %255, ptr %13, align 8
  %256 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %257 = load ptr, ptr %256, align 8
  %258 = load i64, ptr %257, align 8
  %259 = trunc i64 %258 to i32
  %260 = getelementptr inbounds ptr, ptr %256, i32 1
  %261 = load ptr, ptr %260, align 8
  %262 = load i64, ptr %261, align 8
  %263 = trunc i64 %262 to i32
  %264 = mul i32 %259, 200
  %265 = mul i32 %263, 256
  %266 = add i32 %264, %265
  %267 = sext i32 %266 to i64
  %268 = getelementptr inbounds bfloat, ptr %36, i64 %267
  %269 = getelementptr inbounds bfloat, ptr %268, i64 %70
  %270 = load <8 x bfloat>, ptr %269, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %271 = fpext <8 x bfloat> %270 to <8 x float>
  %272 = fpext <8 x bfloat> %253 to <8 x float>
  %273 = fmul contract <8 x float> %271, %272
  %274 = fadd contract <8 x float> %122, %273
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %98, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %275 = insertvalue [2 x ptr] undef, ptr %12, 0
  %276 = insertvalue [2 x ptr] %275, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %276, ptr %11, align 8
  %277 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %278 = load ptr, ptr %277, align 8
  %279 = load i64, ptr %278, align 8
  %280 = trunc i64 %279 to i32
  %281 = getelementptr inbounds ptr, ptr %277, i32 1
  %282 = load ptr, ptr %281, align 8
  %283 = load i64, ptr %282, align 8
  %284 = trunc i64 %283 to i32
  %285 = mul i32 %280, 200
  %286 = mul i32 %284, 256
  %287 = add i32 %285, %286
  %288 = sext i32 %287 to i64
  %289 = getelementptr inbounds bfloat, ptr %36, i64 %288
  %290 = getelementptr inbounds bfloat, ptr %289, i64 %70
  %291 = load <8 x bfloat>, ptr %290, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  %292 = fpext <8 x bfloat> %291 to <8 x float>
  %293 = fmul contract <8 x float> %292, %272
  %294 = fadd contract <8 x float> %123, %293
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %91, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %295 = insertvalue [2 x ptr] undef, ptr %10, 0
  %296 = insertvalue [2 x ptr] %295, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %296, ptr %9, align 8
  %297 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %298 = load ptr, ptr %297, align 8
  %299 = load i64, ptr %298, align 8
  %300 = trunc i64 %299 to i32
  %301 = getelementptr inbounds ptr, ptr %297, i32 1
  %302 = load ptr, ptr %301, align 8
  %303 = load i64, ptr %302, align 8
  %304 = trunc i64 %303 to i32
  %305 = mul i32 %300, 200
  %306 = mul i32 %304, 256
  %307 = add i32 %305, %306
  %308 = sext i32 %307 to i64
  %309 = getelementptr inbounds bfloat, ptr %36, i64 %308
  %310 = getelementptr inbounds bfloat, ptr %309, i64 %70
  %311 = load <8 x bfloat>, ptr %310, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %312 = fpext <8 x bfloat> %311 to <8 x float>
  %313 = fmul contract <8 x float> %312, %272
  %314 = fadd contract <8 x float> %124, %313
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %84, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %315 = insertvalue [2 x ptr] undef, ptr %8, 0
  %316 = insertvalue [2 x ptr] %315, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %316, ptr %7, align 8
  %317 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %318 = load ptr, ptr %317, align 8
  %319 = load i64, ptr %318, align 8
  %320 = trunc i64 %319 to i32
  %321 = getelementptr inbounds ptr, ptr %317, i32 1
  %322 = load ptr, ptr %321, align 8
  %323 = load i64, ptr %322, align 8
  %324 = trunc i64 %323 to i32
  %325 = mul i32 %320, 200
  %326 = mul i32 %324, 256
  %327 = add i32 %325, %326
  %328 = sext i32 %327 to i64
  %329 = getelementptr inbounds bfloat, ptr %36, i64 %328
  %330 = getelementptr inbounds bfloat, ptr %329, i64 %70
  %331 = load <8 x bfloat>, ptr %330, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %332 = fpext <8 x bfloat> %331 to <8 x float>
  %333 = fmul contract <8 x float> %332, %272
  %334 = fadd contract <8 x float> %125, %333
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %336

335:                                              ; preds = %230
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %336

336:                                              ; preds = %335, %252
  %337 = phi <8 x float> [ %122, %335 ], [ %274, %252 ]
  %338 = phi <8 x float> [ %123, %335 ], [ %294, %252 ]
  %339 = phi <8 x float> [ %124, %335 ], [ %314, %252 ]
  %340 = phi <8 x float> [ %125, %335 ], [ %334, %252 ]
  br label %342

341:                                              ; preds = %129
  br label %342

342:                                              ; preds = %341, %336
  %343 = phi <8 x float> [ %122, %341 ], [ %337, %336 ]
  %344 = phi <8 x float> [ %123, %341 ], [ %338, %336 ]
  %345 = phi <8 x float> [ %124, %341 ], [ %339, %336 ]
  %346 = phi <8 x float> [ %125, %341 ], [ %340, %336 ]
  %347 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %343, i64 0)
  %348 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %343, i64 4)
  %349 = fadd contract <4 x float> %347, %348
  %350 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %349, i64 0)
  %351 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %349, i64 2)
  %352 = fadd contract <2 x float> %350, %351
  %353 = extractelement <2 x float> %352, i64 0
  %354 = extractelement <2 x float> %352, i64 1
  %355 = fadd contract float %353, %354
  %356 = bitcast float %355 to i32
  %357 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %356, i32 16, i32 31)
  %358 = bitcast i32 %357 to float
  %359 = fadd contract float %355, %358
  %360 = bitcast float %359 to i32
  %361 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %360, i32 8, i32 31)
  %362 = bitcast i32 %361 to float
  %363 = fadd contract float %359, %362
  %364 = bitcast float %363 to i32
  %365 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %364, i32 4, i32 31)
  %366 = bitcast i32 %365 to float
  %367 = fadd contract float %363, %366
  %368 = bitcast float %367 to i32
  %369 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %368, i32 2, i32 31)
  %370 = bitcast i32 %369 to float
  %371 = fadd contract float %367, %370
  %372 = bitcast float %371 to i32
  %373 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %372, i32 1, i32 31)
  %374 = bitcast i32 %373 to float
  %375 = fadd contract float %371, %374
  %376 = fptrunc float %375 to bfloat
  br i1 %77, label %377, label %378

377:                                              ; preds = %342
  store bfloat %376, ptr %75, align 2
  br label %379

378:                                              ; preds = %342
  br label %379

379:                                              ; preds = %378, %377
  %380 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %344, i64 0)
  %381 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %344, i64 4)
  %382 = fadd contract <4 x float> %380, %381
  %383 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %382, i64 0)
  %384 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %382, i64 2)
  %385 = fadd contract <2 x float> %383, %384
  %386 = extractelement <2 x float> %385, i64 0
  %387 = extractelement <2 x float> %385, i64 1
  %388 = fadd contract float %386, %387
  %389 = bitcast float %388 to i32
  %390 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %389, i32 16, i32 31)
  %391 = bitcast i32 %390 to float
  %392 = fadd contract float %388, %391
  %393 = bitcast float %392 to i32
  %394 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %393, i32 8, i32 31)
  %395 = bitcast i32 %394 to float
  %396 = fadd contract float %392, %395
  %397 = bitcast float %396 to i32
  %398 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %397, i32 4, i32 31)
  %399 = bitcast i32 %398 to float
  %400 = fadd contract float %396, %399
  %401 = bitcast float %400 to i32
  %402 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %401, i32 2, i32 31)
  %403 = bitcast i32 %402 to float
  %404 = fadd contract float %400, %403
  %405 = bitcast float %404 to i32
  %406 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %405, i32 1, i32 31)
  %407 = bitcast i32 %406 to float
  %408 = fadd contract float %404, %407
  %409 = fptrunc float %408 to bfloat
  br i1 %97, label %410, label %411

410:                                              ; preds = %379
  store bfloat %409, ptr %95, align 2
  br label %412

411:                                              ; preds = %379
  br label %412

412:                                              ; preds = %411, %410
  %413 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %345, i64 0)
  %414 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %345, i64 4)
  %415 = fadd contract <4 x float> %413, %414
  %416 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %415, i64 0)
  %417 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %415, i64 2)
  %418 = fadd contract <2 x float> %416, %417
  %419 = extractelement <2 x float> %418, i64 0
  %420 = extractelement <2 x float> %418, i64 1
  %421 = fadd contract float %419, %420
  %422 = bitcast float %421 to i32
  %423 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %422, i32 16, i32 31)
  %424 = bitcast i32 %423 to float
  %425 = fadd contract float %421, %424
  %426 = bitcast float %425 to i32
  %427 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %426, i32 8, i32 31)
  %428 = bitcast i32 %427 to float
  %429 = fadd contract float %425, %428
  %430 = bitcast float %429 to i32
  %431 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %430, i32 4, i32 31)
  %432 = bitcast i32 %431 to float
  %433 = fadd contract float %429, %432
  %434 = bitcast float %433 to i32
  %435 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %434, i32 2, i32 31)
  %436 = bitcast i32 %435 to float
  %437 = fadd contract float %433, %436
  %438 = bitcast float %437 to i32
  %439 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %438, i32 1, i32 31)
  %440 = bitcast i32 %439 to float
  %441 = fadd contract float %437, %440
  %442 = fptrunc float %441 to bfloat
  br i1 %90, label %443, label %444

443:                                              ; preds = %412
  store bfloat %442, ptr %88, align 2
  br label %445

444:                                              ; preds = %412
  br label %445

445:                                              ; preds = %444, %443
  %446 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %346, i64 0)
  %447 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %346, i64 4)
  %448 = fadd contract <4 x float> %446, %447
  %449 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %448, i64 0)
  %450 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %448, i64 2)
  %451 = fadd contract <2 x float> %449, %450
  %452 = extractelement <2 x float> %451, i64 0
  %453 = extractelement <2 x float> %451, i64 1
  %454 = fadd contract float %452, %453
  %455 = bitcast float %454 to i32
  %456 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %455, i32 16, i32 31)
  %457 = bitcast i32 %456 to float
  %458 = fadd contract float %454, %457
  %459 = bitcast float %458 to i32
  %460 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %459, i32 8, i32 31)
  %461 = bitcast i32 %460 to float
  %462 = fadd contract float %458, %461
  %463 = bitcast float %462 to i32
  %464 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %463, i32 4, i32 31)
  %465 = bitcast i32 %464 to float
  %466 = fadd contract float %462, %465
  %467 = bitcast float %466 to i32
  %468 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %467, i32 2, i32 31)
  %469 = bitcast i32 %468 to float
  %470 = fadd contract float %466, %469
  %471 = bitcast float %470 to i32
  %472 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %471, i32 1, i32 31)
  %473 = bitcast i32 %472 to float
  %474 = fadd contract float %470, %473
  %475 = fptrunc float %474 to bfloat
  br i1 %83, label %476, label %477

476:                                              ; preds = %445
  store bfloat %475, ptr %81, align 2
  br label %478

477:                                              ; preds = %445
  br label %478

478:                                              ; preds = %477, %476
  br label %479

479:                                              ; preds = %478, %101
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
