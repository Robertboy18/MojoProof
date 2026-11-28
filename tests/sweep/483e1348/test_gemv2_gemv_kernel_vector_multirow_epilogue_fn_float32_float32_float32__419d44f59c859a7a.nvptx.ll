; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_epilogue_fn_float32_float32_float32_True_4_4_7053e1de(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }) %6) #0 {
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
  %37 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 2
  %38 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 1
  %39 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 0
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
  call void @llvm.lifetime.end.p0(ptr %32)
  call void @llvm.lifetime.start.p0(ptr %32)
  store i32 %55, ptr %32, align 4
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i32 %56, ptr %31, align 4
  call void @llvm.lifetime.end.p0(ptr %30)
  %57 = insertvalue [2 x ptr] undef, ptr %32, 0
  %58 = insertvalue [2 x ptr] %57, ptr %31, 1
  call void @llvm.lifetime.start.p0(ptr %30)
  store [2 x ptr] %58, ptr %30, align 8
  %59 = getelementptr inbounds [2 x ptr], ptr %30, i32 0, i32 0
  %60 = load ptr, ptr %59, align 8
  %61 = load i32, ptr %60, align 4
  %62 = insertelement <2 x i32> undef, i32 %61, i64 0
  %63 = getelementptr inbounds ptr, ptr %59, i32 1
  %64 = load ptr, ptr %63, align 8
  %65 = load i32, ptr %64, align 4
  %66 = insertelement <2 x i32> %62, i32 %65, i64 1
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.end.p0(ptr %32)
  %67 = bitcast <2 x i32> %66 to i64
  %68 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %69 = sext i32 %68 to i64
  %70 = trunc i64 %69 to i32
  %71 = mul i32 %70, 4
  %72 = sext i32 %71 to i64
  %73 = icmp eq i64 %69, 0
  %74 = mul i64 %67, 4
  %75 = trunc i64 %74 to i32
  %76 = add i64 %74, 3
  %77 = call i64 @llvm.smin.i64(i64 %76, i64 %41)
  %78 = add i64 %74, 2
  %79 = call i64 @llvm.smin.i64(i64 %78, i64 %41)
  %80 = add i64 %74, 1
  %81 = call i64 @llvm.smin.i64(i64 %80, i64 %41)
  %82 = call i64 @llvm.smin.i64(i64 %74, i64 %41)
  %83 = trunc i64 %76 to i32
  %84 = icmp slt i64 %76, %40
  %85 = select i1 %73, i1 %84, i1 false
  %86 = trunc i64 %78 to i32
  %87 = icmp slt i64 %78, %40
  %88 = select i1 %73, i1 %87, i1 false
  %89 = trunc i64 %80 to i32
  %90 = icmp slt i64 %80, %40
  %91 = select i1 %73, i1 %90, i1 false
  %92 = icmp slt i64 %74, %40
  %93 = select i1 %73, i1 %92, i1 false
  %94 = icmp sge i64 %74, %40
  br i1 %94, label %95, label %96

95:                                               ; preds = %7
  br label %477

96:                                               ; preds = %7
  %97 = sdiv i64 %42, 4
  %98 = mul i64 %97, 4
  %99 = icmp eq i64 %98, %42
  %100 = xor i64 %42, 4
  %101 = ashr i64 %100, 63
  %102 = select i1 %99, i64 0, i64 %101
  %103 = add i64 %97, %102
  %104 = sdiv i64 %103, -32
  %105 = mul i64 %104, -32
  %106 = icmp eq i64 %105, %103
  %107 = xor i64 %103, -32
  %108 = ashr i64 %107, 63
  %109 = select i1 %106, i64 0, i64 %108
  %110 = add i64 %104, %109
  %111 = sub i64 0, %110
  %112 = sub i64 %111, 1
  %113 = call i64 @llvm.smax.i64(i64 %112, i64 0)
  br label %114

114:                                              ; preds = %125, %96
  %115 = phi i64 [ 0, %96 ], [ %122, %125 ]
  %116 = phi <4 x float> [ zeroinitializer, %96 ], [ %158, %125 ]
  %117 = phi <4 x float> [ zeroinitializer, %96 ], [ %177, %125 ]
  %118 = phi <4 x float> [ zeroinitializer, %96 ], [ %196, %125 ]
  %119 = phi <4 x float> [ zeroinitializer, %96 ], [ %215, %125 ]
  call void @llvm.lifetime.end.p0(ptr %29)
  %120 = icmp eq i64 %115, %113
  %121 = add i64 %115, 1
  %122 = select i1 %120, i64 %115, i64 %121
  br i1 %120, label %123, label %125

123:                                              ; preds = %114
  %124 = icmp sgt i64 %111, 0
  br i1 %124, label %216, label %319

125:                                              ; preds = %114
  call void @llvm.lifetime.start.p0(ptr %29)
  store i64 %115, ptr %29, align 8
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 0, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  %126 = insertvalue [2 x ptr] undef, ptr %28, 0
  %127 = insertvalue [2 x ptr] %126, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %27)
  store [2 x ptr] %127, ptr %27, align 8
  %128 = getelementptr inbounds [2 x ptr], ptr %27, i32 0, i32 0
  %129 = load ptr, ptr %128, align 8
  %130 = load i64, ptr %129, align 8
  %131 = getelementptr inbounds ptr, ptr %128, i32 1
  %132 = load ptr, ptr %131, align 8
  %133 = load i64, ptr %132, align 8
  %134 = mul i64 %130, 32
  %135 = mul i64 %133, 128
  %136 = add i64 %134, %135
  %137 = getelementptr inbounds float, ptr %36, i64 %136
  %138 = getelementptr inbounds float, ptr %137, i64 %72
  %139 = load <4 x float>, ptr %138, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.start.p0(ptr %26)
  store i64 %82, ptr %26, align 8
  call void @llvm.lifetime.end.p0(ptr %25)
  %140 = insertvalue [2 x ptr] undef, ptr %26, 0
  %141 = insertvalue [2 x ptr] %140, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %25)
  store [2 x ptr] %141, ptr %25, align 8
  %142 = getelementptr inbounds [2 x ptr], ptr %25, i32 0, i32 0
  %143 = load ptr, ptr %142, align 8
  %144 = load i64, ptr %143, align 8
  %145 = trunc i64 %144 to i32
  %146 = getelementptr inbounds ptr, ptr %142, i32 1
  %147 = load ptr, ptr %146, align 8
  %148 = load i64, ptr %147, align 8
  %149 = trunc i64 %148 to i32
  %150 = mul i32 %145, 32
  %151 = mul i32 %149, 128
  %152 = add i32 %150, %151
  %153 = sext i32 %152 to i64
  %154 = getelementptr inbounds float, ptr %35, i64 %153
  %155 = getelementptr inbounds float, ptr %154, i64 %72
  %156 = load <4 x float>, ptr %155, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.end.p0(ptr %26)
  %157 = fmul contract <4 x float> %156, %139
  %158 = fadd contract <4 x float> %116, %157
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.start.p0(ptr %24)
  store i64 %81, ptr %24, align 8
  call void @llvm.lifetime.end.p0(ptr %23)
  %159 = insertvalue [2 x ptr] undef, ptr %24, 0
  %160 = insertvalue [2 x ptr] %159, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %23)
  store [2 x ptr] %160, ptr %23, align 8
  %161 = getelementptr inbounds [2 x ptr], ptr %23, i32 0, i32 0
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = trunc i64 %163 to i32
  %165 = getelementptr inbounds ptr, ptr %161, i32 1
  %166 = load ptr, ptr %165, align 8
  %167 = load i64, ptr %166, align 8
  %168 = trunc i64 %167 to i32
  %169 = mul i32 %164, 32
  %170 = mul i32 %168, 128
  %171 = add i32 %169, %170
  %172 = sext i32 %171 to i64
  %173 = getelementptr inbounds float, ptr %35, i64 %172
  %174 = getelementptr inbounds float, ptr %173, i64 %72
  %175 = load <4 x float>, ptr %174, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.end.p0(ptr %24)
  %176 = fmul contract <4 x float> %175, %139
  %177 = fadd contract <4 x float> %117, %176
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.start.p0(ptr %22)
  store i64 %79, ptr %22, align 8
  call void @llvm.lifetime.end.p0(ptr %21)
  %178 = insertvalue [2 x ptr] undef, ptr %22, 0
  %179 = insertvalue [2 x ptr] %178, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %21)
  store [2 x ptr] %179, ptr %21, align 8
  %180 = getelementptr inbounds [2 x ptr], ptr %21, i32 0, i32 0
  %181 = load ptr, ptr %180, align 8
  %182 = load i64, ptr %181, align 8
  %183 = trunc i64 %182 to i32
  %184 = getelementptr inbounds ptr, ptr %180, i32 1
  %185 = load ptr, ptr %184, align 8
  %186 = load i64, ptr %185, align 8
  %187 = trunc i64 %186 to i32
  %188 = mul i32 %183, 32
  %189 = mul i32 %187, 128
  %190 = add i32 %188, %189
  %191 = sext i32 %190 to i64
  %192 = getelementptr inbounds float, ptr %35, i64 %191
  %193 = getelementptr inbounds float, ptr %192, i64 %72
  %194 = load <4 x float>, ptr %193, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.end.p0(ptr %22)
  %195 = fmul contract <4 x float> %194, %139
  %196 = fadd contract <4 x float> %118, %195
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.start.p0(ptr %20)
  store i64 %77, ptr %20, align 8
  call void @llvm.lifetime.end.p0(ptr %19)
  %197 = insertvalue [2 x ptr] undef, ptr %20, 0
  %198 = insertvalue [2 x ptr] %197, ptr %29, 1
  call void @llvm.lifetime.start.p0(ptr %19)
  store [2 x ptr] %198, ptr %19, align 8
  %199 = getelementptr inbounds [2 x ptr], ptr %19, i32 0, i32 0
  %200 = load ptr, ptr %199, align 8
  %201 = load i64, ptr %200, align 8
  %202 = trunc i64 %201 to i32
  %203 = getelementptr inbounds ptr, ptr %199, i32 1
  %204 = load ptr, ptr %203, align 8
  %205 = load i64, ptr %204, align 8
  %206 = trunc i64 %205 to i32
  %207 = mul i32 %202, 32
  %208 = mul i32 %206, 128
  %209 = add i32 %207, %208
  %210 = sext i32 %209 to i64
  %211 = getelementptr inbounds float, ptr %35, i64 %210
  %212 = getelementptr inbounds float, ptr %211, i64 %72
  %213 = load <4 x float>, ptr %212, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.end.p0(ptr %20)
  %214 = fmul contract <4 x float> %213, %139
  %215 = fadd contract <4 x float> %119, %214
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  call void @llvm.lifetime.end.p0(ptr %29)
  br label %114

216:                                              ; preds = %123
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i64 %112, ptr %18, align 8
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 0, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %217 = insertvalue [2 x ptr] undef, ptr %17, 0
  %218 = insertvalue [2 x ptr] %217, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %218, ptr %16, align 8
  %219 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %220 = load ptr, ptr %219, align 8
  %221 = load i64, ptr %220, align 8
  %222 = getelementptr inbounds ptr, ptr %219, i32 1
  %223 = load ptr, ptr %222, align 8
  %224 = load i64, ptr %223, align 8
  %225 = mul i64 %221, 32
  %226 = mul i64 %224, 128
  %227 = add i64 %225, %226
  %228 = getelementptr inbounds float, ptr %36, i64 %227
  %229 = getelementptr inbounds float, ptr %228, i64 %72
  %230 = load i64, ptr %18, align 8
  %231 = mul i64 %230, 32
  %232 = add i64 %69, %231
  %233 = mul i64 %232, 4
  %234 = icmp slt i64 %233, %42
  br i1 %234, label %235, label %313

235:                                              ; preds = %216
  %236 = load <4 x float>, ptr %229, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %82, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %237 = insertvalue [2 x ptr] undef, ptr %15, 0
  %238 = insertvalue [2 x ptr] %237, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %238, ptr %14, align 8
  %239 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %240 = load ptr, ptr %239, align 8
  %241 = load i64, ptr %240, align 8
  %242 = trunc i64 %241 to i32
  %243 = getelementptr inbounds ptr, ptr %239, i32 1
  %244 = load ptr, ptr %243, align 8
  %245 = load i64, ptr %244, align 8
  %246 = trunc i64 %245 to i32
  %247 = mul i32 %242, 32
  %248 = mul i32 %246, 128
  %249 = add i32 %247, %248
  %250 = sext i32 %249 to i64
  %251 = getelementptr inbounds float, ptr %35, i64 %250
  %252 = getelementptr inbounds float, ptr %251, i64 %72
  %253 = load <4 x float>, ptr %252, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %254 = fmul contract <4 x float> %253, %236
  %255 = fadd contract <4 x float> %116, %254
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 %81, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %256 = insertvalue [2 x ptr] undef, ptr %13, 0
  %257 = insertvalue [2 x ptr] %256, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %257, ptr %12, align 8
  %258 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %259 = load ptr, ptr %258, align 8
  %260 = load i64, ptr %259, align 8
  %261 = trunc i64 %260 to i32
  %262 = getelementptr inbounds ptr, ptr %258, i32 1
  %263 = load ptr, ptr %262, align 8
  %264 = load i64, ptr %263, align 8
  %265 = trunc i64 %264 to i32
  %266 = mul i32 %261, 32
  %267 = mul i32 %265, 128
  %268 = add i32 %266, %267
  %269 = sext i32 %268 to i64
  %270 = getelementptr inbounds float, ptr %35, i64 %269
  %271 = getelementptr inbounds float, ptr %270, i64 %72
  %272 = load <4 x float>, ptr %271, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  %273 = fmul contract <4 x float> %272, %236
  %274 = fadd contract <4 x float> %117, %273
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %79, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %275 = insertvalue [2 x ptr] undef, ptr %11, 0
  %276 = insertvalue [2 x ptr] %275, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %276, ptr %10, align 8
  %277 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %278 = load ptr, ptr %277, align 8
  %279 = load i64, ptr %278, align 8
  %280 = trunc i64 %279 to i32
  %281 = getelementptr inbounds ptr, ptr %277, i32 1
  %282 = load ptr, ptr %281, align 8
  %283 = load i64, ptr %282, align 8
  %284 = trunc i64 %283 to i32
  %285 = mul i32 %280, 32
  %286 = mul i32 %284, 128
  %287 = add i32 %285, %286
  %288 = sext i32 %287 to i64
  %289 = getelementptr inbounds float, ptr %35, i64 %288
  %290 = getelementptr inbounds float, ptr %289, i64 %72
  %291 = load <4 x float>, ptr %290, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %292 = fmul contract <4 x float> %291, %236
  %293 = fadd contract <4 x float> %118, %292
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 %77, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %294 = insertvalue [2 x ptr] undef, ptr %9, 0
  %295 = insertvalue [2 x ptr] %294, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %295, ptr %8, align 8
  %296 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %297 = load ptr, ptr %296, align 8
  %298 = load i64, ptr %297, align 8
  %299 = trunc i64 %298 to i32
  %300 = getelementptr inbounds ptr, ptr %296, i32 1
  %301 = load ptr, ptr %300, align 8
  %302 = load i64, ptr %301, align 8
  %303 = trunc i64 %302 to i32
  %304 = mul i32 %299, 32
  %305 = mul i32 %303, 128
  %306 = add i32 %304, %305
  %307 = sext i32 %306 to i64
  %308 = getelementptr inbounds float, ptr %35, i64 %307
  %309 = getelementptr inbounds float, ptr %308, i64 %72
  %310 = load <4 x float>, ptr %309, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  %311 = fmul contract <4 x float> %310, %236
  %312 = fadd contract <4 x float> %119, %311
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %314

313:                                              ; preds = %216
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  br label %314

314:                                              ; preds = %313, %235
  %315 = phi <4 x float> [ %116, %313 ], [ %255, %235 ]
  %316 = phi <4 x float> [ %117, %313 ], [ %274, %235 ]
  %317 = phi <4 x float> [ %118, %313 ], [ %293, %235 ]
  %318 = phi <4 x float> [ %119, %313 ], [ %312, %235 ]
  br label %320

319:                                              ; preds = %123
  br label %320

320:                                              ; preds = %319, %314
  %321 = phi <4 x float> [ %116, %319 ], [ %315, %314 ]
  %322 = phi <4 x float> [ %117, %319 ], [ %316, %314 ]
  %323 = phi <4 x float> [ %118, %319 ], [ %317, %314 ]
  %324 = phi <4 x float> [ %119, %319 ], [ %318, %314 ]
  %325 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %321, i64 0)
  %326 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %321, i64 2)
  %327 = fadd contract <2 x float> %325, %326
  %328 = extractelement <2 x float> %327, i64 0
  %329 = extractelement <2 x float> %327, i64 1
  %330 = fadd contract float %328, %329
  %331 = bitcast float %330 to i32
  %332 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %331, i32 16, i32 31)
  %333 = bitcast i32 %332 to float
  %334 = fadd contract float %330, %333
  %335 = bitcast float %334 to i32
  %336 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %335, i32 8, i32 31)
  %337 = bitcast i32 %336 to float
  %338 = fadd contract float %334, %337
  %339 = bitcast float %338 to i32
  %340 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %339, i32 4, i32 31)
  %341 = bitcast i32 %340 to float
  %342 = fadd contract float %338, %341
  %343 = bitcast float %342 to i32
  %344 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %343, i32 2, i32 31)
  %345 = bitcast i32 %344 to float
  %346 = fadd contract float %342, %345
  %347 = bitcast float %346 to i32
  %348 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %347, i32 1, i32 31)
  %349 = bitcast i32 %348 to float
  %350 = fadd contract float %346, %349
  br i1 %93, label %351, label %361

351:                                              ; preds = %320
  %352 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %39, align 8
  %353 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %38, align 8
  %354 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %37, align 8
  %355 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %352, 0
  %356 = getelementptr inbounds float, ptr %355, i64 %74
  store float %350, ptr %356, align 4
  %357 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %353, 0
  %358 = getelementptr inbounds i32, ptr %357, i64 %74
  store i32 0, ptr %358, align 4
  %359 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %354, 0
  %360 = getelementptr inbounds i32, ptr %359, i64 %74
  store i32 %75, ptr %360, align 4
  br label %362

361:                                              ; preds = %320
  br label %362

362:                                              ; preds = %361, %351
  %363 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %322, i64 0)
  %364 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %322, i64 2)
  %365 = fadd contract <2 x float> %363, %364
  %366 = extractelement <2 x float> %365, i64 0
  %367 = extractelement <2 x float> %365, i64 1
  %368 = fadd contract float %366, %367
  %369 = bitcast float %368 to i32
  %370 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %369, i32 16, i32 31)
  %371 = bitcast i32 %370 to float
  %372 = fadd contract float %368, %371
  %373 = bitcast float %372 to i32
  %374 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %373, i32 8, i32 31)
  %375 = bitcast i32 %374 to float
  %376 = fadd contract float %372, %375
  %377 = bitcast float %376 to i32
  %378 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %377, i32 4, i32 31)
  %379 = bitcast i32 %378 to float
  %380 = fadd contract float %376, %379
  %381 = bitcast float %380 to i32
  %382 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %381, i32 2, i32 31)
  %383 = bitcast i32 %382 to float
  %384 = fadd contract float %380, %383
  %385 = bitcast float %384 to i32
  %386 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %385, i32 1, i32 31)
  %387 = bitcast i32 %386 to float
  %388 = fadd contract float %384, %387
  br i1 %91, label %389, label %399

389:                                              ; preds = %362
  %390 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %39, align 8
  %391 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %38, align 8
  %392 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %37, align 8
  %393 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %390, 0
  %394 = getelementptr inbounds float, ptr %393, i64 %80
  store float %388, ptr %394, align 4
  %395 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %391, 0
  %396 = getelementptr inbounds i32, ptr %395, i64 %80
  store i32 0, ptr %396, align 4
  %397 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %392, 0
  %398 = getelementptr inbounds i32, ptr %397, i64 %80
  store i32 %89, ptr %398, align 4
  br label %400

399:                                              ; preds = %362
  br label %400

400:                                              ; preds = %399, %389
  %401 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %323, i64 0)
  %402 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %323, i64 2)
  %403 = fadd contract <2 x float> %401, %402
  %404 = extractelement <2 x float> %403, i64 0
  %405 = extractelement <2 x float> %403, i64 1
  %406 = fadd contract float %404, %405
  %407 = bitcast float %406 to i32
  %408 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %407, i32 16, i32 31)
  %409 = bitcast i32 %408 to float
  %410 = fadd contract float %406, %409
  %411 = bitcast float %410 to i32
  %412 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %411, i32 8, i32 31)
  %413 = bitcast i32 %412 to float
  %414 = fadd contract float %410, %413
  %415 = bitcast float %414 to i32
  %416 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %415, i32 4, i32 31)
  %417 = bitcast i32 %416 to float
  %418 = fadd contract float %414, %417
  %419 = bitcast float %418 to i32
  %420 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %419, i32 2, i32 31)
  %421 = bitcast i32 %420 to float
  %422 = fadd contract float %418, %421
  %423 = bitcast float %422 to i32
  %424 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %423, i32 1, i32 31)
  %425 = bitcast i32 %424 to float
  %426 = fadd contract float %422, %425
  br i1 %88, label %427, label %437

427:                                              ; preds = %400
  %428 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %39, align 8
  %429 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %38, align 8
  %430 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %37, align 8
  %431 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %428, 0
  %432 = getelementptr inbounds float, ptr %431, i64 %78
  store float %426, ptr %432, align 4
  %433 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %429, 0
  %434 = getelementptr inbounds i32, ptr %433, i64 %78
  store i32 0, ptr %434, align 4
  %435 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %430, 0
  %436 = getelementptr inbounds i32, ptr %435, i64 %78
  store i32 %86, ptr %436, align 4
  br label %438

437:                                              ; preds = %400
  br label %438

438:                                              ; preds = %437, %427
  %439 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %324, i64 0)
  %440 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %324, i64 2)
  %441 = fadd contract <2 x float> %439, %440
  %442 = extractelement <2 x float> %441, i64 0
  %443 = extractelement <2 x float> %441, i64 1
  %444 = fadd contract float %442, %443
  %445 = bitcast float %444 to i32
  %446 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %445, i32 16, i32 31)
  %447 = bitcast i32 %446 to float
  %448 = fadd contract float %444, %447
  %449 = bitcast float %448 to i32
  %450 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %449, i32 8, i32 31)
  %451 = bitcast i32 %450 to float
  %452 = fadd contract float %448, %451
  %453 = bitcast float %452 to i32
  %454 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %453, i32 4, i32 31)
  %455 = bitcast i32 %454 to float
  %456 = fadd contract float %452, %455
  %457 = bitcast float %456 to i32
  %458 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %457, i32 2, i32 31)
  %459 = bitcast i32 %458 to float
  %460 = fadd contract float %456, %459
  %461 = bitcast float %460 to i32
  %462 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %461, i32 1, i32 31)
  %463 = bitcast i32 %462 to float
  %464 = fadd contract float %460, %463
  br i1 %85, label %465, label %475

465:                                              ; preds = %438
  %466 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %39, align 8
  %467 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %38, align 8
  %468 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %37, align 8
  %469 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %466, 0
  %470 = getelementptr inbounds float, ptr %469, i64 %76
  store float %464, ptr %470, align 4
  %471 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %467, 0
  %472 = getelementptr inbounds i32, ptr %471, i64 %76
  store i32 0, ptr %472, align 4
  %473 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %468, 0
  %474 = getelementptr inbounds i32, ptr %473, i64 %76
  store i32 %83, ptr %474, align 4
  br label %476

475:                                              ; preds = %438
  br label %476

476:                                              ; preds = %475, %465
  br label %477

477:                                              ; preds = %476, %95
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
