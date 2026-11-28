; ModuleID = 'test_matmul_custom.mojo'
source_filename = "test_matmul_custom.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_compute_fn_float32_float32_float32_False_4_4_c09dd656(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %36 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %34, 1, 1, 0
  %37 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %33, 0
  %38 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %33, 1, 1, 0
  %39 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %32, 0
  %40 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %32, 1, 1, 0
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
  call void @llvm.lifetime.end.p0(ptr %31)
  call void @llvm.lifetime.start.p0(ptr %31)
  store i32 %56, ptr %31, align 4
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.start.p0(ptr %30)
  store i32 %57, ptr %30, align 4
  call void @llvm.lifetime.end.p0(ptr %29)
  %58 = insertvalue [2 x ptr] undef, ptr %31, 0
  %59 = insertvalue [2 x ptr] %58, ptr %30, 1
  call void @llvm.lifetime.start.p0(ptr %29)
  store [2 x ptr] %59, ptr %29, align 8
  %60 = getelementptr inbounds [2 x ptr], ptr %29, i32 0, i32 0
  %61 = load ptr, ptr %60, align 8
  %62 = load i32, ptr %61, align 4
  %63 = insertelement <2 x i32> undef, i32 %62, i64 0
  %64 = getelementptr inbounds ptr, ptr %60, i32 1
  %65 = load ptr, ptr %64, align 8
  %66 = load i32, ptr %65, align 4
  %67 = insertelement <2 x i32> %63, i32 %66, i64 1
  call void @llvm.lifetime.end.p0(ptr %29)
  call void @llvm.lifetime.end.p0(ptr %30)
  call void @llvm.lifetime.end.p0(ptr %31)
  %68 = bitcast <2 x i32> %67 to i64
  %69 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %70 = sext i32 %69 to i64
  %71 = mul i64 %70, 4
  %72 = icmp eq i64 %70, 0
  %73 = mul i64 %68, 4
  %74 = mul i64 %73, %36
  %75 = getelementptr inbounds float, ptr %35, i64 %74
  %76 = icmp slt i64 %73, %41
  %77 = select i1 %72, i1 %76, i1 false
  %78 = add i64 %73, 3
  %79 = mul i64 %78, %36
  %80 = getelementptr inbounds float, ptr %35, i64 %79
  %81 = icmp slt i64 %78, %41
  %82 = select i1 %72, i1 %81, i1 false
  %83 = call i64 @llvm.smin.i64(i64 %78, i64 %42)
  %84 = add i64 %73, 2
  %85 = mul i64 %84, %36
  %86 = getelementptr inbounds float, ptr %35, i64 %85
  %87 = icmp slt i64 %84, %41
  %88 = select i1 %72, i1 %87, i1 false
  %89 = call i64 @llvm.smin.i64(i64 %84, i64 %42)
  %90 = add i64 %73, 1
  %91 = mul i64 %90, %36
  %92 = getelementptr inbounds float, ptr %35, i64 %91
  %93 = icmp slt i64 %90, %41
  %94 = select i1 %72, i1 %93, i1 false
  %95 = call i64 @llvm.smin.i64(i64 %90, i64 %42)
  %96 = call i64 @llvm.smin.i64(i64 %73, i64 %42)
  %97 = icmp sge i64 %73, %41
  br i1 %97, label %98, label %99

98:                                               ; preds = %6
  br label %424

99:                                               ; preds = %6
  %100 = sdiv i64 %43, 4
  %101 = mul i64 %100, 4
  %102 = icmp eq i64 %101, %43
  %103 = xor i64 %43, 4
  %104 = ashr i64 %103, 63
  %105 = select i1 %102, i64 0, i64 %104
  %106 = add i64 %100, %105
  %107 = sdiv i64 %106, -32
  %108 = mul i64 %107, -32
  %109 = icmp eq i64 %108, %106
  %110 = xor i64 %106, -32
  %111 = ashr i64 %110, 63
  %112 = select i1 %109, i64 0, i64 %111
  %113 = add i64 %107, %112
  %114 = sub i64 0, %113
  %115 = sub i64 %114, 1
  %116 = call i64 @llvm.smax.i64(i64 %115, i64 0)
  br label %117

117:                                              ; preds = %128, %99
  %118 = phi i64 [ 0, %99 ], [ %125, %128 ]
  %119 = phi <4 x float> [ zeroinitializer, %99 ], [ %158, %128 ]
  %120 = phi <4 x float> [ zeroinitializer, %99 ], [ %174, %128 ]
  %121 = phi <4 x float> [ zeroinitializer, %99 ], [ %190, %128 ]
  %122 = phi <4 x float> [ zeroinitializer, %99 ], [ %206, %128 ]
  call void @llvm.lifetime.end.p0(ptr %28)
  %123 = icmp eq i64 %118, %116
  %124 = add i64 %118, 1
  %125 = select i1 %123, i64 %118, i64 %124
  br i1 %123, label %126, label %128

126:                                              ; preds = %117
  %127 = icmp sgt i64 %114, 0
  br i1 %127, label %207, label %298

128:                                              ; preds = %117
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 %118, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 0, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  %129 = insertvalue [2 x ptr] undef, ptr %27, 0
  %130 = insertvalue [2 x ptr] %129, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %26)
  store [2 x ptr] %130, ptr %26, align 8
  %131 = getelementptr inbounds [2 x ptr], ptr %26, i32 0, i32 0
  %132 = load ptr, ptr %131, align 8
  %133 = load i64, ptr %132, align 8
  %134 = getelementptr inbounds ptr, ptr %131, i32 1
  %135 = load ptr, ptr %134, align 8
  %136 = load i64, ptr %135, align 8
  %137 = mul i64 %133, %40
  %138 = mul i64 %136, 128
  %139 = add i64 %137, %138
  %140 = getelementptr inbounds float, ptr %39, i64 %139
  %141 = getelementptr inbounds float, ptr %140, i64 %71
  %142 = load <4 x float>, ptr %141, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.start.p0(ptr %25)
  store i64 %96, ptr %25, align 8
  call void @llvm.lifetime.end.p0(ptr %24)
  %143 = insertvalue [2 x ptr] undef, ptr %25, 0
  %144 = insertvalue [2 x ptr] %143, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %24)
  store [2 x ptr] %144, ptr %24, align 8
  %145 = getelementptr inbounds [2 x ptr], ptr %24, i32 0, i32 0
  %146 = load ptr, ptr %145, align 8
  %147 = load i64, ptr %146, align 8
  %148 = getelementptr inbounds ptr, ptr %145, i32 1
  %149 = load ptr, ptr %148, align 8
  %150 = load i64, ptr %149, align 8
  %151 = mul i64 %147, %38
  %152 = mul i64 %150, 128
  %153 = add i64 %151, %152
  %154 = getelementptr inbounds float, ptr %37, i64 %153
  %155 = getelementptr inbounds float, ptr %154, i64 %71
  %156 = load <4 x float>, ptr %155, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %25)
  %157 = fmul contract <4 x float> %156, %142
  %158 = fadd contract <4 x float> %119, %157
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %95, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %159 = insertvalue [2 x ptr] undef, ptr %23, 0
  %160 = insertvalue [2 x ptr] %159, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %160, ptr %22, align 8
  %161 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %162 = load ptr, ptr %161, align 8
  %163 = load i64, ptr %162, align 8
  %164 = getelementptr inbounds ptr, ptr %161, i32 1
  %165 = load ptr, ptr %164, align 8
  %166 = load i64, ptr %165, align 8
  %167 = mul i64 %163, %38
  %168 = mul i64 %166, 128
  %169 = add i64 %167, %168
  %170 = getelementptr inbounds float, ptr %37, i64 %169
  %171 = getelementptr inbounds float, ptr %170, i64 %71
  %172 = load <4 x float>, ptr %171, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  %173 = fmul contract <4 x float> %172, %142
  %174 = fadd contract <4 x float> %120, %173
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %89, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  %175 = insertvalue [2 x ptr] undef, ptr %21, 0
  %176 = insertvalue [2 x ptr] %175, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %20)
  store [2 x ptr] %176, ptr %20, align 8
  %177 = getelementptr inbounds [2 x ptr], ptr %20, i32 0, i32 0
  %178 = load ptr, ptr %177, align 8
  %179 = load i64, ptr %178, align 8
  %180 = getelementptr inbounds ptr, ptr %177, i32 1
  %181 = load ptr, ptr %180, align 8
  %182 = load i64, ptr %181, align 8
  %183 = mul i64 %179, %38
  %184 = mul i64 %182, 128
  %185 = add i64 %183, %184
  %186 = getelementptr inbounds float, ptr %37, i64 %185
  %187 = getelementptr inbounds float, ptr %186, i64 %71
  %188 = load <4 x float>, ptr %187, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %189 = fmul contract <4 x float> %188, %142
  %190 = fadd contract <4 x float> %121, %189
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %83, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  %191 = insertvalue [2 x ptr] undef, ptr %19, 0
  %192 = insertvalue [2 x ptr] %191, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %18)
  store [2 x ptr] %192, ptr %18, align 8
  %193 = getelementptr inbounds [2 x ptr], ptr %18, i32 0, i32 0
  %194 = load ptr, ptr %193, align 8
  %195 = load i64, ptr %194, align 8
  %196 = getelementptr inbounds ptr, ptr %193, i32 1
  %197 = load ptr, ptr %196, align 8
  %198 = load i64, ptr %197, align 8
  %199 = mul i64 %195, %38
  %200 = mul i64 %198, 128
  %201 = add i64 %199, %200
  %202 = getelementptr inbounds float, ptr %37, i64 %201
  %203 = getelementptr inbounds float, ptr %202, i64 %71
  %204 = load <4 x float>, ptr %203, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %205 = fmul contract <4 x float> %204, %142
  %206 = fadd contract <4 x float> %122, %205
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  br label %117

207:                                              ; preds = %126
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %115, ptr %17, align 8
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
  %216 = mul i64 %212, %40
  %217 = mul i64 %215, 128
  %218 = add i64 %216, %217
  %219 = getelementptr inbounds float, ptr %39, i64 %218
  %220 = getelementptr inbounds float, ptr %219, i64 %71
  %221 = load i64, ptr %17, align 8
  %222 = mul i64 %221, 32
  %223 = add i64 %70, %222
  %224 = mul i64 %223, 4
  %225 = icmp slt i64 %224, %43
  br i1 %225, label %226, label %292

226:                                              ; preds = %207
  %227 = load <4 x float>, ptr %220, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %96, ptr %14, align 8
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
  %236 = mul i64 %232, %38
  %237 = mul i64 %235, 128
  %238 = add i64 %236, %237
  %239 = getelementptr inbounds float, ptr %37, i64 %238
  %240 = getelementptr inbounds float, ptr %239, i64 %71
  %241 = load <4 x float>, ptr %240, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %242 = fmul contract <4 x float> %241, %227
  %243 = fadd contract <4 x float> %119, %242
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %95, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %244 = insertvalue [2 x ptr] undef, ptr %12, 0
  %245 = insertvalue [2 x ptr] %244, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %245, ptr %11, align 8
  %246 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %247 = load ptr, ptr %246, align 8
  %248 = load i64, ptr %247, align 8
  %249 = getelementptr inbounds ptr, ptr %246, i32 1
  %250 = load ptr, ptr %249, align 8
  %251 = load i64, ptr %250, align 8
  %252 = mul i64 %248, %38
  %253 = mul i64 %251, 128
  %254 = add i64 %252, %253
  %255 = getelementptr inbounds float, ptr %37, i64 %254
  %256 = getelementptr inbounds float, ptr %255, i64 %71
  %257 = load <4 x float>, ptr %256, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  %258 = fmul contract <4 x float> %257, %227
  %259 = fadd contract <4 x float> %120, %258
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %89, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %260 = insertvalue [2 x ptr] undef, ptr %10, 0
  %261 = insertvalue [2 x ptr] %260, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %261, ptr %9, align 8
  %262 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %263 = load ptr, ptr %262, align 8
  %264 = load i64, ptr %263, align 8
  %265 = getelementptr inbounds ptr, ptr %262, i32 1
  %266 = load ptr, ptr %265, align 8
  %267 = load i64, ptr %266, align 8
  %268 = mul i64 %264, %38
  %269 = mul i64 %267, 128
  %270 = add i64 %268, %269
  %271 = getelementptr inbounds float, ptr %37, i64 %270
  %272 = getelementptr inbounds float, ptr %271, i64 %71
  %273 = load <4 x float>, ptr %272, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %274 = fmul contract <4 x float> %273, %227
  %275 = fadd contract <4 x float> %121, %274
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %83, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %276 = insertvalue [2 x ptr] undef, ptr %8, 0
  %277 = insertvalue [2 x ptr] %276, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %277, ptr %7, align 8
  %278 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %279 = load ptr, ptr %278, align 8
  %280 = load i64, ptr %279, align 8
  %281 = getelementptr inbounds ptr, ptr %278, i32 1
  %282 = load ptr, ptr %281, align 8
  %283 = load i64, ptr %282, align 8
  %284 = mul i64 %280, %38
  %285 = mul i64 %283, 128
  %286 = add i64 %284, %285
  %287 = getelementptr inbounds float, ptr %37, i64 %286
  %288 = getelementptr inbounds float, ptr %287, i64 %71
  %289 = load <4 x float>, ptr %288, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %290 = fmul contract <4 x float> %289, %227
  %291 = fadd contract <4 x float> %122, %290
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %293

292:                                              ; preds = %207
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %293

293:                                              ; preds = %292, %226
  %294 = phi <4 x float> [ %119, %292 ], [ %243, %226 ]
  %295 = phi <4 x float> [ %120, %292 ], [ %259, %226 ]
  %296 = phi <4 x float> [ %121, %292 ], [ %275, %226 ]
  %297 = phi <4 x float> [ %122, %292 ], [ %291, %226 ]
  br label %299

298:                                              ; preds = %126
  br label %299

299:                                              ; preds = %298, %293
  %300 = phi <4 x float> [ %119, %298 ], [ %294, %293 ]
  %301 = phi <4 x float> [ %120, %298 ], [ %295, %293 ]
  %302 = phi <4 x float> [ %121, %298 ], [ %296, %293 ]
  %303 = phi <4 x float> [ %122, %298 ], [ %297, %293 ]
  %304 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %300, i64 0)
  %305 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %300, i64 2)
  %306 = fadd contract <2 x float> %304, %305
  %307 = extractelement <2 x float> %306, i64 0
  %308 = extractelement <2 x float> %306, i64 1
  %309 = fadd contract float %307, %308
  %310 = bitcast float %309 to i32
  %311 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %310, i32 16, i32 31)
  %312 = bitcast i32 %311 to float
  %313 = fadd contract float %309, %312
  %314 = bitcast float %313 to i32
  %315 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %314, i32 8, i32 31)
  %316 = bitcast i32 %315 to float
  %317 = fadd contract float %313, %316
  %318 = bitcast float %317 to i32
  %319 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %318, i32 4, i32 31)
  %320 = bitcast i32 %319 to float
  %321 = fadd contract float %317, %320
  %322 = bitcast float %321 to i32
  %323 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %322, i32 2, i32 31)
  %324 = bitcast i32 %323 to float
  %325 = fadd contract float %321, %324
  %326 = bitcast float %325 to i32
  %327 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %326, i32 1, i32 31)
  %328 = bitcast i32 %327 to float
  %329 = fadd contract float %325, %328
  %330 = fadd contract float %329, 2.000000e+00
  br i1 %77, label %331, label %332

331:                                              ; preds = %299
  store float %330, ptr %75, align 4
  br label %333

332:                                              ; preds = %299
  br label %333

333:                                              ; preds = %332, %331
  %334 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %301, i64 0)
  %335 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %301, i64 2)
  %336 = fadd contract <2 x float> %334, %335
  %337 = extractelement <2 x float> %336, i64 0
  %338 = extractelement <2 x float> %336, i64 1
  %339 = fadd contract float %337, %338
  %340 = bitcast float %339 to i32
  %341 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %340, i32 16, i32 31)
  %342 = bitcast i32 %341 to float
  %343 = fadd contract float %339, %342
  %344 = bitcast float %343 to i32
  %345 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %344, i32 8, i32 31)
  %346 = bitcast i32 %345 to float
  %347 = fadd contract float %343, %346
  %348 = bitcast float %347 to i32
  %349 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %348, i32 4, i32 31)
  %350 = bitcast i32 %349 to float
  %351 = fadd contract float %347, %350
  %352 = bitcast float %351 to i32
  %353 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %352, i32 2, i32 31)
  %354 = bitcast i32 %353 to float
  %355 = fadd contract float %351, %354
  %356 = bitcast float %355 to i32
  %357 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %356, i32 1, i32 31)
  %358 = bitcast i32 %357 to float
  %359 = fadd contract float %355, %358
  %360 = fadd contract float %359, 2.000000e+00
  br i1 %94, label %361, label %362

361:                                              ; preds = %333
  store float %360, ptr %92, align 4
  br label %363

362:                                              ; preds = %333
  br label %363

363:                                              ; preds = %362, %361
  %364 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %302, i64 0)
  %365 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %302, i64 2)
  %366 = fadd contract <2 x float> %364, %365
  %367 = extractelement <2 x float> %366, i64 0
  %368 = extractelement <2 x float> %366, i64 1
  %369 = fadd contract float %367, %368
  %370 = bitcast float %369 to i32
  %371 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %370, i32 16, i32 31)
  %372 = bitcast i32 %371 to float
  %373 = fadd contract float %369, %372
  %374 = bitcast float %373 to i32
  %375 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %374, i32 8, i32 31)
  %376 = bitcast i32 %375 to float
  %377 = fadd contract float %373, %376
  %378 = bitcast float %377 to i32
  %379 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %378, i32 4, i32 31)
  %380 = bitcast i32 %379 to float
  %381 = fadd contract float %377, %380
  %382 = bitcast float %381 to i32
  %383 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %382, i32 2, i32 31)
  %384 = bitcast i32 %383 to float
  %385 = fadd contract float %381, %384
  %386 = bitcast float %385 to i32
  %387 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %386, i32 1, i32 31)
  %388 = bitcast i32 %387 to float
  %389 = fadd contract float %385, %388
  %390 = fadd contract float %389, 2.000000e+00
  br i1 %88, label %391, label %392

391:                                              ; preds = %363
  store float %390, ptr %86, align 4
  br label %393

392:                                              ; preds = %363
  br label %393

393:                                              ; preds = %392, %391
  %394 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %303, i64 0)
  %395 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %303, i64 2)
  %396 = fadd contract <2 x float> %394, %395
  %397 = extractelement <2 x float> %396, i64 0
  %398 = extractelement <2 x float> %396, i64 1
  %399 = fadd contract float %397, %398
  %400 = bitcast float %399 to i32
  %401 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %400, i32 16, i32 31)
  %402 = bitcast i32 %401 to float
  %403 = fadd contract float %399, %402
  %404 = bitcast float %403 to i32
  %405 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %404, i32 8, i32 31)
  %406 = bitcast i32 %405 to float
  %407 = fadd contract float %403, %406
  %408 = bitcast float %407 to i32
  %409 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %408, i32 4, i32 31)
  %410 = bitcast i32 %409 to float
  %411 = fadd contract float %407, %410
  %412 = bitcast float %411 to i32
  %413 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %412, i32 2, i32 31)
  %414 = bitcast i32 %413 to float
  %415 = fadd contract float %411, %414
  %416 = bitcast float %415 to i32
  %417 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %416, i32 1, i32 31)
  %418 = bitcast i32 %417 to float
  %419 = fadd contract float %415, %418
  %420 = fadd contract float %419, 2.000000e+00
  br i1 %82, label %421, label %422

421:                                              ; preds = %393
  store float %420, ptr %80, align 4
  br label %423

422:                                              ; preds = %393
  br label %423

423:                                              ; preds = %422, %421
  br label %424

424:                                              ; preds = %423, %98
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
