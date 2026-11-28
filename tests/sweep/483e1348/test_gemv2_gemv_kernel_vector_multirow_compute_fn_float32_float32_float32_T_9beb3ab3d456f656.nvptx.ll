; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_multirow_compute_fn_float32_float32_float32_True_4_4_1ca1688c(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %32 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %33 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %34 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %35 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %34, 0
  %36 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %33, 0
  %37 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %32, 0
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
  %69 = mul i32 %68, 4
  %70 = sext i32 %69 to i64
  %71 = icmp eq i64 %67, 0
  %72 = mul i64 %65, 4
  %73 = getelementptr inbounds float, ptr %35, i64 %72
  %74 = sitofp i64 %72 to float
  %75 = icmp slt i64 %72, %38
  %76 = select i1 %71, i1 %75, i1 false
  %77 = add i64 %72, 3
  %78 = getelementptr inbounds float, ptr %35, i64 %77
  %79 = sitofp i64 %77 to float
  %80 = icmp slt i64 %77, %38
  %81 = select i1 %71, i1 %80, i1 false
  %82 = call i64 @llvm.smin.i64(i64 %77, i64 %39)
  %83 = add i64 %72, 2
  %84 = getelementptr inbounds float, ptr %35, i64 %83
  %85 = sitofp i64 %83 to float
  %86 = icmp slt i64 %83, %38
  %87 = select i1 %71, i1 %86, i1 false
  %88 = call i64 @llvm.smin.i64(i64 %83, i64 %39)
  %89 = add i64 %72, 1
  %90 = getelementptr inbounds float, ptr %35, i64 %89
  %91 = sitofp i64 %89 to float
  %92 = icmp slt i64 %89, %38
  %93 = select i1 %71, i1 %92, i1 false
  %94 = call i64 @llvm.smin.i64(i64 %89, i64 %39)
  %95 = call i64 @llvm.smin.i64(i64 %72, i64 %39)
  %96 = icmp sge i64 %72, %38
  br i1 %96, label %97, label %98

97:                                               ; preds = %6
  br label %447

98:                                               ; preds = %6
  %99 = sdiv i64 %40, 4
  %100 = mul i64 %99, 4
  %101 = icmp eq i64 %100, %40
  %102 = xor i64 %40, 4
  %103 = ashr i64 %102, 63
  %104 = select i1 %101, i64 0, i64 %103
  %105 = add i64 %99, %104
  %106 = sdiv i64 %105, -32
  %107 = mul i64 %106, -32
  %108 = icmp eq i64 %107, %105
  %109 = xor i64 %105, -32
  %110 = ashr i64 %109, 63
  %111 = select i1 %108, i64 0, i64 %110
  %112 = add i64 %106, %111
  %113 = sub i64 0, %112
  %114 = sub i64 %113, 1
  %115 = call i64 @llvm.smax.i64(i64 %114, i64 0)
  br label %116

116:                                              ; preds = %127, %98
  %117 = phi i64 [ 0, %98 ], [ %124, %127 ]
  %118 = phi <4 x float> [ zeroinitializer, %98 ], [ %160, %127 ]
  %119 = phi <4 x float> [ zeroinitializer, %98 ], [ %179, %127 ]
  %120 = phi <4 x float> [ zeroinitializer, %98 ], [ %198, %127 ]
  %121 = phi <4 x float> [ zeroinitializer, %98 ], [ %217, %127 ]
  call void @llvm.lifetime.end.p0(ptr %28)
  %122 = icmp eq i64 %117, %115
  %123 = add i64 %117, 1
  %124 = select i1 %122, i64 %117, i64 %123
  br i1 %122, label %125, label %127

125:                                              ; preds = %116
  %126 = icmp sgt i64 %113, 0
  br i1 %126, label %218, label %321

127:                                              ; preds = %116
  call void @llvm.lifetime.start.p0(ptr %28)
  store i64 %117, ptr %28, align 8
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.start.p0(ptr %27)
  store i64 0, ptr %27, align 8
  call void @llvm.lifetime.end.p0(ptr %26)
  %128 = insertvalue [2 x ptr] undef, ptr %27, 0
  %129 = insertvalue [2 x ptr] %128, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %26)
  store [2 x ptr] %129, ptr %26, align 8
  %130 = getelementptr inbounds [2 x ptr], ptr %26, i32 0, i32 0
  %131 = load ptr, ptr %130, align 8
  %132 = load i64, ptr %131, align 8
  %133 = getelementptr inbounds ptr, ptr %130, i32 1
  %134 = load ptr, ptr %133, align 8
  %135 = load i64, ptr %134, align 8
  %136 = mul i64 %132, 32
  %137 = mul i64 %135, 128
  %138 = add i64 %136, %137
  %139 = getelementptr inbounds float, ptr %37, i64 %138
  %140 = getelementptr inbounds float, ptr %139, i64 %70
  %141 = load <4 x float>, ptr %140, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %25)
  call void @llvm.lifetime.start.p0(ptr %25)
  store i64 %95, ptr %25, align 8
  call void @llvm.lifetime.end.p0(ptr %24)
  %142 = insertvalue [2 x ptr] undef, ptr %25, 0
  %143 = insertvalue [2 x ptr] %142, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %24)
  store [2 x ptr] %143, ptr %24, align 8
  %144 = getelementptr inbounds [2 x ptr], ptr %24, i32 0, i32 0
  %145 = load ptr, ptr %144, align 8
  %146 = load i64, ptr %145, align 8
  %147 = trunc i64 %146 to i32
  %148 = getelementptr inbounds ptr, ptr %144, i32 1
  %149 = load ptr, ptr %148, align 8
  %150 = load i64, ptr %149, align 8
  %151 = trunc i64 %150 to i32
  %152 = mul i32 %147, 32
  %153 = mul i32 %151, 128
  %154 = add i32 %152, %153
  %155 = sext i32 %154 to i64
  %156 = getelementptr inbounds float, ptr %36, i64 %155
  %157 = getelementptr inbounds float, ptr %156, i64 %70
  %158 = load <4 x float>, ptr %157, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %24)
  call void @llvm.lifetime.end.p0(ptr %25)
  %159 = fmul contract <4 x float> %158, %141
  %160 = fadd contract <4 x float> %118, %159
  call void @llvm.lifetime.end.p0(ptr %23)
  call void @llvm.lifetime.start.p0(ptr %23)
  store i64 %94, ptr %23, align 8
  call void @llvm.lifetime.end.p0(ptr %22)
  %161 = insertvalue [2 x ptr] undef, ptr %23, 0
  %162 = insertvalue [2 x ptr] %161, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %22)
  store [2 x ptr] %162, ptr %22, align 8
  %163 = getelementptr inbounds [2 x ptr], ptr %22, i32 0, i32 0
  %164 = load ptr, ptr %163, align 8
  %165 = load i64, ptr %164, align 8
  %166 = trunc i64 %165 to i32
  %167 = getelementptr inbounds ptr, ptr %163, i32 1
  %168 = load ptr, ptr %167, align 8
  %169 = load i64, ptr %168, align 8
  %170 = trunc i64 %169 to i32
  %171 = mul i32 %166, 32
  %172 = mul i32 %170, 128
  %173 = add i32 %171, %172
  %174 = sext i32 %173 to i64
  %175 = getelementptr inbounds float, ptr %36, i64 %174
  %176 = getelementptr inbounds float, ptr %175, i64 %70
  %177 = load <4 x float>, ptr %176, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %22)
  call void @llvm.lifetime.end.p0(ptr %23)
  %178 = fmul contract <4 x float> %177, %141
  %179 = fadd contract <4 x float> %119, %178
  call void @llvm.lifetime.end.p0(ptr %21)
  call void @llvm.lifetime.start.p0(ptr %21)
  store i64 %88, ptr %21, align 8
  call void @llvm.lifetime.end.p0(ptr %20)
  %180 = insertvalue [2 x ptr] undef, ptr %21, 0
  %181 = insertvalue [2 x ptr] %180, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %20)
  store [2 x ptr] %181, ptr %20, align 8
  %182 = getelementptr inbounds [2 x ptr], ptr %20, i32 0, i32 0
  %183 = load ptr, ptr %182, align 8
  %184 = load i64, ptr %183, align 8
  %185 = trunc i64 %184 to i32
  %186 = getelementptr inbounds ptr, ptr %182, i32 1
  %187 = load ptr, ptr %186, align 8
  %188 = load i64, ptr %187, align 8
  %189 = trunc i64 %188 to i32
  %190 = mul i32 %185, 32
  %191 = mul i32 %189, 128
  %192 = add i32 %190, %191
  %193 = sext i32 %192 to i64
  %194 = getelementptr inbounds float, ptr %36, i64 %193
  %195 = getelementptr inbounds float, ptr %194, i64 %70
  %196 = load <4 x float>, ptr %195, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %20)
  call void @llvm.lifetime.end.p0(ptr %21)
  %197 = fmul contract <4 x float> %196, %141
  %198 = fadd contract <4 x float> %120, %197
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i64 %82, ptr %19, align 8
  call void @llvm.lifetime.end.p0(ptr %18)
  %199 = insertvalue [2 x ptr] undef, ptr %19, 0
  %200 = insertvalue [2 x ptr] %199, ptr %28, 1
  call void @llvm.lifetime.start.p0(ptr %18)
  store [2 x ptr] %200, ptr %18, align 8
  %201 = getelementptr inbounds [2 x ptr], ptr %18, i32 0, i32 0
  %202 = load ptr, ptr %201, align 8
  %203 = load i64, ptr %202, align 8
  %204 = trunc i64 %203 to i32
  %205 = getelementptr inbounds ptr, ptr %201, i32 1
  %206 = load ptr, ptr %205, align 8
  %207 = load i64, ptr %206, align 8
  %208 = trunc i64 %207 to i32
  %209 = mul i32 %204, 32
  %210 = mul i32 %208, 128
  %211 = add i32 %209, %210
  %212 = sext i32 %211 to i64
  %213 = getelementptr inbounds float, ptr %36, i64 %212
  %214 = getelementptr inbounds float, ptr %213, i64 %70
  %215 = load <4 x float>, ptr %214, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %216 = fmul contract <4 x float> %215, %141
  %217 = fadd contract <4 x float> %121, %216
  call void @llvm.lifetime.end.p0(ptr %26)
  call void @llvm.lifetime.end.p0(ptr %27)
  call void @llvm.lifetime.end.p0(ptr %28)
  br label %116

218:                                              ; preds = %125
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i64 %114, ptr %17, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 0, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %15)
  %219 = insertvalue [2 x ptr] undef, ptr %16, 0
  %220 = insertvalue [2 x ptr] %219, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %15)
  store [2 x ptr] %220, ptr %15, align 8
  %221 = getelementptr inbounds [2 x ptr], ptr %15, i32 0, i32 0
  %222 = load ptr, ptr %221, align 8
  %223 = load i64, ptr %222, align 8
  %224 = getelementptr inbounds ptr, ptr %221, i32 1
  %225 = load ptr, ptr %224, align 8
  %226 = load i64, ptr %225, align 8
  %227 = mul i64 %223, 32
  %228 = mul i64 %226, 128
  %229 = add i64 %227, %228
  %230 = getelementptr inbounds float, ptr %37, i64 %229
  %231 = getelementptr inbounds float, ptr %230, i64 %70
  %232 = load i64, ptr %17, align 8
  %233 = mul i64 %232, 32
  %234 = add i64 %67, %233
  %235 = mul i64 %234, 4
  %236 = icmp slt i64 %235, %40
  br i1 %236, label %237, label %315

237:                                              ; preds = %218
  %238 = load <4 x float>, ptr %231, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %95, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %239 = insertvalue [2 x ptr] undef, ptr %14, 0
  %240 = insertvalue [2 x ptr] %239, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %240, ptr %13, align 8
  %241 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %242 = load ptr, ptr %241, align 8
  %243 = load i64, ptr %242, align 8
  %244 = trunc i64 %243 to i32
  %245 = getelementptr inbounds ptr, ptr %241, i32 1
  %246 = load ptr, ptr %245, align 8
  %247 = load i64, ptr %246, align 8
  %248 = trunc i64 %247 to i32
  %249 = mul i32 %244, 32
  %250 = mul i32 %248, 128
  %251 = add i32 %249, %250
  %252 = sext i32 %251 to i64
  %253 = getelementptr inbounds float, ptr %36, i64 %252
  %254 = getelementptr inbounds float, ptr %253, i64 %70
  %255 = load <4 x float>, ptr %254, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %256 = fmul contract <4 x float> %255, %238
  %257 = fadd contract <4 x float> %118, %256
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 %94, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %258 = insertvalue [2 x ptr] undef, ptr %12, 0
  %259 = insertvalue [2 x ptr] %258, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %259, ptr %11, align 8
  %260 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %261 = load ptr, ptr %260, align 8
  %262 = load i64, ptr %261, align 8
  %263 = trunc i64 %262 to i32
  %264 = getelementptr inbounds ptr, ptr %260, i32 1
  %265 = load ptr, ptr %264, align 8
  %266 = load i64, ptr %265, align 8
  %267 = trunc i64 %266 to i32
  %268 = mul i32 %263, 32
  %269 = mul i32 %267, 128
  %270 = add i32 %268, %269
  %271 = sext i32 %270 to i64
  %272 = getelementptr inbounds float, ptr %36, i64 %271
  %273 = getelementptr inbounds float, ptr %272, i64 %70
  %274 = load <4 x float>, ptr %273, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  %275 = fmul contract <4 x float> %274, %238
  %276 = fadd contract <4 x float> %119, %275
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %88, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %277 = insertvalue [2 x ptr] undef, ptr %10, 0
  %278 = insertvalue [2 x ptr] %277, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %278, ptr %9, align 8
  %279 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %280 = load ptr, ptr %279, align 8
  %281 = load i64, ptr %280, align 8
  %282 = trunc i64 %281 to i32
  %283 = getelementptr inbounds ptr, ptr %279, i32 1
  %284 = load ptr, ptr %283, align 8
  %285 = load i64, ptr %284, align 8
  %286 = trunc i64 %285 to i32
  %287 = mul i32 %282, 32
  %288 = mul i32 %286, 128
  %289 = add i32 %287, %288
  %290 = sext i32 %289 to i64
  %291 = getelementptr inbounds float, ptr %36, i64 %290
  %292 = getelementptr inbounds float, ptr %291, i64 %70
  %293 = load <4 x float>, ptr %292, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %294 = fmul contract <4 x float> %293, %238
  %295 = fadd contract <4 x float> %120, %294
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 %82, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %296 = insertvalue [2 x ptr] undef, ptr %8, 0
  %297 = insertvalue [2 x ptr] %296, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %297, ptr %7, align 8
  %298 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %299 = load ptr, ptr %298, align 8
  %300 = load i64, ptr %299, align 8
  %301 = trunc i64 %300 to i32
  %302 = getelementptr inbounds ptr, ptr %298, i32 1
  %303 = load ptr, ptr %302, align 8
  %304 = load i64, ptr %303, align 8
  %305 = trunc i64 %304 to i32
  %306 = mul i32 %301, 32
  %307 = mul i32 %305, 128
  %308 = add i32 %306, %307
  %309 = sext i32 %308 to i64
  %310 = getelementptr inbounds float, ptr %36, i64 %309
  %311 = getelementptr inbounds float, ptr %310, i64 %70
  %312 = load <4 x float>, ptr %311, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  %313 = fmul contract <4 x float> %312, %238
  %314 = fadd contract <4 x float> %121, %313
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %316

315:                                              ; preds = %218
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  br label %316

316:                                              ; preds = %315, %237
  %317 = phi <4 x float> [ %118, %315 ], [ %257, %237 ]
  %318 = phi <4 x float> [ %119, %315 ], [ %276, %237 ]
  %319 = phi <4 x float> [ %120, %315 ], [ %295, %237 ]
  %320 = phi <4 x float> [ %121, %315 ], [ %314, %237 ]
  br label %322

321:                                              ; preds = %125
  br label %322

322:                                              ; preds = %321, %316
  %323 = phi <4 x float> [ %118, %321 ], [ %317, %316 ]
  %324 = phi <4 x float> [ %119, %321 ], [ %318, %316 ]
  %325 = phi <4 x float> [ %120, %321 ], [ %319, %316 ]
  %326 = phi <4 x float> [ %121, %321 ], [ %320, %316 ]
  %327 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %323, i64 0)
  %328 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %323, i64 2)
  %329 = fadd contract <2 x float> %327, %328
  %330 = extractelement <2 x float> %329, i64 0
  %331 = extractelement <2 x float> %329, i64 1
  %332 = fadd contract float %330, %331
  %333 = bitcast float %332 to i32
  %334 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %333, i32 16, i32 31)
  %335 = bitcast i32 %334 to float
  %336 = fadd contract float %332, %335
  %337 = bitcast float %336 to i32
  %338 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %337, i32 8, i32 31)
  %339 = bitcast i32 %338 to float
  %340 = fadd contract float %336, %339
  %341 = bitcast float %340 to i32
  %342 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %341, i32 4, i32 31)
  %343 = bitcast i32 %342 to float
  %344 = fadd contract float %340, %343
  %345 = bitcast float %344 to i32
  %346 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %345, i32 2, i32 31)
  %347 = bitcast i32 %346 to float
  %348 = fadd contract float %344, %347
  %349 = bitcast float %348 to i32
  %350 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %349, i32 1, i32 31)
  %351 = bitcast i32 %350 to float
  %352 = fadd contract float %348, %351
  %353 = fadd contract float %352, %74
  br i1 %76, label %354, label %355

354:                                              ; preds = %322
  store float %353, ptr %73, align 4
  br label %356

355:                                              ; preds = %322
  br label %356

356:                                              ; preds = %355, %354
  %357 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %324, i64 0)
  %358 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %324, i64 2)
  %359 = fadd contract <2 x float> %357, %358
  %360 = extractelement <2 x float> %359, i64 0
  %361 = extractelement <2 x float> %359, i64 1
  %362 = fadd contract float %360, %361
  %363 = bitcast float %362 to i32
  %364 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %363, i32 16, i32 31)
  %365 = bitcast i32 %364 to float
  %366 = fadd contract float %362, %365
  %367 = bitcast float %366 to i32
  %368 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %367, i32 8, i32 31)
  %369 = bitcast i32 %368 to float
  %370 = fadd contract float %366, %369
  %371 = bitcast float %370 to i32
  %372 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %371, i32 4, i32 31)
  %373 = bitcast i32 %372 to float
  %374 = fadd contract float %370, %373
  %375 = bitcast float %374 to i32
  %376 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %375, i32 2, i32 31)
  %377 = bitcast i32 %376 to float
  %378 = fadd contract float %374, %377
  %379 = bitcast float %378 to i32
  %380 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %379, i32 1, i32 31)
  %381 = bitcast i32 %380 to float
  %382 = fadd contract float %378, %381
  %383 = fadd contract float %382, %91
  br i1 %93, label %384, label %385

384:                                              ; preds = %356
  store float %383, ptr %90, align 4
  br label %386

385:                                              ; preds = %356
  br label %386

386:                                              ; preds = %385, %384
  %387 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %325, i64 0)
  %388 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %325, i64 2)
  %389 = fadd contract <2 x float> %387, %388
  %390 = extractelement <2 x float> %389, i64 0
  %391 = extractelement <2 x float> %389, i64 1
  %392 = fadd contract float %390, %391
  %393 = bitcast float %392 to i32
  %394 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %393, i32 16, i32 31)
  %395 = bitcast i32 %394 to float
  %396 = fadd contract float %392, %395
  %397 = bitcast float %396 to i32
  %398 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %397, i32 8, i32 31)
  %399 = bitcast i32 %398 to float
  %400 = fadd contract float %396, %399
  %401 = bitcast float %400 to i32
  %402 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %401, i32 4, i32 31)
  %403 = bitcast i32 %402 to float
  %404 = fadd contract float %400, %403
  %405 = bitcast float %404 to i32
  %406 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %405, i32 2, i32 31)
  %407 = bitcast i32 %406 to float
  %408 = fadd contract float %404, %407
  %409 = bitcast float %408 to i32
  %410 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %409, i32 1, i32 31)
  %411 = bitcast i32 %410 to float
  %412 = fadd contract float %408, %411
  %413 = fadd contract float %412, %85
  br i1 %87, label %414, label %415

414:                                              ; preds = %386
  store float %413, ptr %84, align 4
  br label %416

415:                                              ; preds = %386
  br label %416

416:                                              ; preds = %415, %414
  %417 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %326, i64 0)
  %418 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %326, i64 2)
  %419 = fadd contract <2 x float> %417, %418
  %420 = extractelement <2 x float> %419, i64 0
  %421 = extractelement <2 x float> %419, i64 1
  %422 = fadd contract float %420, %421
  %423 = bitcast float %422 to i32
  %424 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %423, i32 16, i32 31)
  %425 = bitcast i32 %424 to float
  %426 = fadd contract float %422, %425
  %427 = bitcast float %426 to i32
  %428 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %427, i32 8, i32 31)
  %429 = bitcast i32 %428 to float
  %430 = fadd contract float %426, %429
  %431 = bitcast float %430 to i32
  %432 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %431, i32 4, i32 31)
  %433 = bitcast i32 %432 to float
  %434 = fadd contract float %430, %433
  %435 = bitcast float %434 to i32
  %436 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %435, i32 2, i32 31)
  %437 = bitcast i32 %436 to float
  %438 = fadd contract float %434, %437
  %439 = bitcast float %438 to i32
  %440 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %439, i32 1, i32 31)
  %441 = bitcast i32 %440 to float
  %442 = fadd contract float %438, %441
  %443 = fadd contract float %442, %79
  br i1 %81, label %444, label %445

444:                                              ; preds = %416
  store float %443, ptr %78, align 4
  br label %446

445:                                              ; preds = %416
  br label %446

446:                                              ; preds = %445, %444
  br label %447

447:                                              ; preds = %446, %97
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
