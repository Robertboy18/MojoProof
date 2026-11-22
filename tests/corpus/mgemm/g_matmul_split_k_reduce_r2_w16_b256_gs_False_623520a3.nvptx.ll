; ModuleID = 'test_multistage_gemm_kernel.mojo'
source_filename = "test_multistage_gemm_kernel.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: noinline
define internal void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc() #0 {
  call void @llvm.nvvm.griddepcontrol.wait()
  ret void
}

; Function Attrs: norecurse
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
  %2 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 0
  %3 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 4
  %4 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 1
  %5 = getelementptr { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, ptr %2, i32 0, i32 0
  %6 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 1
  %7 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 4
  %8 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %9 = zext i32 %8 to i64
  %10 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %11 = zext i32 %10 to i64
  %12 = mul i64 %11, 256
  %13 = add i64 %9, %12
  %14 = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %15 = sext i32 %14 to i64
  %16 = mul i64 %15, 256
  %17 = mul i64 %16, 3
  %18 = mul i64 %16, 2
  call void @max_gpu_primitives_grid_contr6A6A6A6A6A6A_2376f9a6514f34bc()
  %19 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 2
  %20 = mul i64 %16, 4
  %21 = load i64, ptr %19, align 8
  %22 = icmp eq i64 %20, 0
  %23 = select i1 %22, i64 0, i64 %13
  %24 = select i1 %22, i64 0, i64 %21
  %25 = select i1 %22, i64 1, i64 %20
  %26 = icmp slt i64 %25, 0
  %27 = icmp sgt i64 %25, 0
  br label %28

28:                                               ; preds = %644, %1
  %29 = phi i64 [ %23, %1 ], [ %53, %644 ]
  %30 = phi i64 [ 0, %1 ], [ %54, %644 ]
  %31 = icmp sge i64 %24, %29
  %32 = icmp sge i64 %29, %24
  %33 = add i64 %29, %25
  %34 = icmp slt i64 %33, %29
  %35 = xor i1 %34, %26
  %36 = select i1 %35, i64 1, i64 0
  %37 = icmp eq i64 %30, 0
  %38 = xor i1 %37, true
  %39 = or i1 %38, %31
  %40 = or i1 %38, %32
  br label %41

41:                                               ; preds = %28
  br i1 %27, label %42, label %47

42:                                               ; preds = %41
  br i1 %40, label %43, label %44

43:                                               ; preds = %42
  br label %50

44:                                               ; preds = %42
  br label %45

45:                                               ; preds = %44
  br label %49

46:                                               ; preds = %47
  br label %49

47:                                               ; preds = %41
  br i1 %39, label %48, label %46

48:                                               ; preds = %47
  br label %50

49:                                               ; preds = %46, %45
  br label %50

50:                                               ; preds = %49, %48, %43
  %51 = phi i1 [ true, %43 ], [ true, %48 ], [ false, %49 ]
  %52 = phi i64 [ undef, %43 ], [ undef, %48 ], [ %29, %49 ]
  %53 = phi i64 [ %29, %43 ], [ %29, %48 ], [ %33, %49 ]
  %54 = phi i64 [ %30, %43 ], [ %30, %48 ], [ %36, %49 ]
  %55 = mul i64 %52, 16
  %56 = icmp slt i64 %55, 0
  br i1 %51, label %57, label %58

57:                                               ; preds = %50
  br label %645

58:                                               ; preds = %50
  br label %59

59:                                               ; preds = %58
  %60 = load i64, ptr %19, align 8
  %61 = icmp slt i64 %52, %60
  br i1 %61, label %62, label %202

62:                                               ; preds = %59
  %63 = load { i64, i64 }, ptr %6, align 8
  %64 = extractvalue { i64, i64 } %63, 1
  %65 = icmp eq i64 %64, 0
  %66 = select i1 %65, i64 1, i64 %64
  %67 = sdiv i64 %55, %66
  %68 = mul i64 %67, %64
  %69 = sub i64 %55, %68
  %70 = icmp slt i64 %64, 0
  %71 = xor i1 %70, %56
  %72 = icmp ne i64 %69, 0
  %73 = and i1 %71, %72
  %74 = select i1 %73, i64 1, i64 0
  %75 = sub i64 %67, %74
  %76 = select i1 %65, i64 0, i64 %75
  %77 = select i1 %73, i64 %64, i64 0
  %78 = add i64 %69, %77
  %79 = select i1 %65, i64 0, i64 %78
  %80 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %81 = load i64, ptr %4, align 8
  %82 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %83 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %80, 0
  %84 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %80, 1, 1, 0
  %85 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %80, 1, 1, 1
  %86 = mul i64 %76, %85
  %87 = add i64 %86, %79
  %88 = getelementptr inbounds i8, ptr %83, i64 %87
  %89 = load <16 x i8>, ptr %88, align 16, !invariant.load !1
  %90 = call i64 @llvm.smax.i64(i64 %81, i64 1)
  br label %91

91:                                               ; preds = %97, %62
  %92 = phi i64 [ 1, %62 ], [ %100, %97 ]
  %93 = phi <16 x i8> [ %89, %62 ], [ %192, %97 ]
  %94 = icmp slt i64 %92, %90
  br i1 %94, label %95, label %96

95:                                               ; preds = %91
  br label %97

96:                                               ; preds = %91
  br label %193

97:                                               ; preds = %95
  %98 = icmp eq i64 %92, %90
  %99 = add i64 %92, 1
  %100 = select i1 %98, i64 %92, i64 %99
  %101 = mul i64 %92, %84
  %102 = add i64 %101, %86
  %103 = add i64 %102, %79
  %104 = getelementptr inbounds i8, ptr %83, i64 %103
  %105 = load <16 x i8>, ptr %104, align 16, !invariant.load !1
  %106 = bitcast <16 x i8> %93 to <8 x i16>
  %107 = extractelement <8 x i16> %106, i32 0
  %108 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %107)
  %109 = insertelement <8 x i32> undef, i32 %108, i32 0
  %110 = extractelement <8 x i16> %106, i32 1
  %111 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %110)
  %112 = insertelement <8 x i32> %109, i32 %111, i32 1
  %113 = extractelement <8 x i16> %106, i32 2
  %114 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %113)
  %115 = insertelement <8 x i32> %112, i32 %114, i32 2
  %116 = extractelement <8 x i16> %106, i32 3
  %117 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %116)
  %118 = insertelement <8 x i32> %115, i32 %117, i32 3
  %119 = extractelement <8 x i16> %106, i32 4
  %120 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %119)
  %121 = insertelement <8 x i32> %118, i32 %120, i32 4
  %122 = extractelement <8 x i16> %106, i32 5
  %123 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %122)
  %124 = insertelement <8 x i32> %121, i32 %123, i32 5
  %125 = extractelement <8 x i16> %106, i32 6
  %126 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %125)
  %127 = insertelement <8 x i32> %124, i32 %126, i32 6
  %128 = extractelement <8 x i16> %106, i32 7
  %129 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %128)
  %130 = insertelement <8 x i32> %127, i32 %129, i32 7
  %131 = bitcast <8 x i32> %130 to <16 x half>
  %132 = bitcast <16 x i8> %105 to <8 x i16>
  %133 = extractelement <8 x i16> %132, i32 0
  %134 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %133)
  %135 = insertelement <8 x i32> undef, i32 %134, i32 0
  %136 = extractelement <8 x i16> %132, i32 1
  %137 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %136)
  %138 = insertelement <8 x i32> %135, i32 %137, i32 1
  %139 = extractelement <8 x i16> %132, i32 2
  %140 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %139)
  %141 = insertelement <8 x i32> %138, i32 %140, i32 2
  %142 = extractelement <8 x i16> %132, i32 3
  %143 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %142)
  %144 = insertelement <8 x i32> %141, i32 %143, i32 3
  %145 = extractelement <8 x i16> %132, i32 4
  %146 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %145)
  %147 = insertelement <8 x i32> %144, i32 %146, i32 4
  %148 = extractelement <8 x i16> %132, i32 5
  %149 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %148)
  %150 = insertelement <8 x i32> %147, i32 %149, i32 5
  %151 = extractelement <8 x i16> %132, i32 6
  %152 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %151)
  %153 = insertelement <8 x i32> %150, i32 %152, i32 6
  %154 = extractelement <8 x i16> %132, i32 7
  %155 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %154)
  %156 = insertelement <8 x i32> %153, i32 %155, i32 7
  %157 = bitcast <8 x i32> %156 to <16 x half>
  %158 = fadd contract <16 x half> %131, %157
  %159 = fpext <16 x half> %158 to <16 x float>
  %160 = extractelement <16 x float> %159, i32 1
  %161 = extractelement <16 x float> %159, i32 0
  %162 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %160, float %161)
  %163 = insertelement <8 x i16> undef, i16 %162, i32 0
  %164 = extractelement <16 x float> %159, i32 3
  %165 = extractelement <16 x float> %159, i32 2
  %166 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %164, float %165)
  %167 = insertelement <8 x i16> %163, i16 %166, i32 1
  %168 = extractelement <16 x float> %159, i32 5
  %169 = extractelement <16 x float> %159, i32 4
  %170 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %168, float %169)
  %171 = insertelement <8 x i16> %167, i16 %170, i32 2
  %172 = extractelement <16 x float> %159, i32 7
  %173 = extractelement <16 x float> %159, i32 6
  %174 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %172, float %173)
  %175 = insertelement <8 x i16> %171, i16 %174, i32 3
  %176 = extractelement <16 x float> %159, i32 9
  %177 = extractelement <16 x float> %159, i32 8
  %178 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %176, float %177)
  %179 = insertelement <8 x i16> %175, i16 %178, i32 4
  %180 = extractelement <16 x float> %159, i32 11
  %181 = extractelement <16 x float> %159, i32 10
  %182 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %180, float %181)
  %183 = insertelement <8 x i16> %179, i16 %182, i32 5
  %184 = extractelement <16 x float> %159, i32 13
  %185 = extractelement <16 x float> %159, i32 12
  %186 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %184, float %185)
  %187 = insertelement <8 x i16> %183, i16 %186, i32 6
  %188 = extractelement <16 x float> %159, i32 15
  %189 = extractelement <16 x float> %159, i32 14
  %190 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %188, float %189)
  %191 = insertelement <8 x i16> %187, i16 %190, i32 7
  %192 = bitcast <8 x i16> %191 to <16 x i8>
  br label %91

193:                                              ; preds = %96
  %194 = phi <16 x i8> [ %93, %96 ]
  %195 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %82, 0
  %196 = trunc i64 %76 to i32
  %197 = mul i32 %196, 512
  %198 = trunc i64 %79 to i32
  %199 = add i32 %197, %198
  %200 = sext i32 %199 to i64
  %201 = getelementptr inbounds i8, ptr %195, i64 %200
  store <16 x i8> %194, ptr %201, align 16
  br label %203

202:                                              ; preds = %59
  br label %203

203:                                              ; preds = %202, %193
  %204 = add i64 %52, %16
  %205 = mul i64 %204, 16
  %206 = icmp slt i64 %205, 0
  %207 = load i64, ptr %19, align 8
  %208 = icmp slt i64 %204, %207
  br i1 %208, label %209, label %349

209:                                              ; preds = %203
  %210 = load { i64, i64 }, ptr %6, align 8
  %211 = extractvalue { i64, i64 } %210, 1
  %212 = icmp eq i64 %211, 0
  %213 = select i1 %212, i64 1, i64 %211
  %214 = sdiv i64 %205, %213
  %215 = mul i64 %214, %211
  %216 = sub i64 %205, %215
  %217 = icmp slt i64 %211, 0
  %218 = xor i1 %217, %206
  %219 = icmp ne i64 %216, 0
  %220 = and i1 %218, %219
  %221 = select i1 %220, i64 1, i64 0
  %222 = sub i64 %214, %221
  %223 = select i1 %212, i64 0, i64 %222
  %224 = select i1 %220, i64 %211, i64 0
  %225 = add i64 %216, %224
  %226 = select i1 %212, i64 0, i64 %225
  %227 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %228 = load i64, ptr %4, align 8
  %229 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %230 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %227, 0
  %231 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %227, 1, 1, 0
  %232 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %227, 1, 1, 1
  %233 = mul i64 %223, %232
  %234 = add i64 %233, %226
  %235 = getelementptr inbounds i8, ptr %230, i64 %234
  %236 = load <16 x i8>, ptr %235, align 16, !invariant.load !1
  %237 = call i64 @llvm.smax.i64(i64 %228, i64 1)
  br label %238

238:                                              ; preds = %244, %209
  %239 = phi i64 [ 1, %209 ], [ %247, %244 ]
  %240 = phi <16 x i8> [ %236, %209 ], [ %339, %244 ]
  %241 = icmp slt i64 %239, %237
  br i1 %241, label %242, label %243

242:                                              ; preds = %238
  br label %244

243:                                              ; preds = %238
  br label %340

244:                                              ; preds = %242
  %245 = icmp eq i64 %239, %237
  %246 = add i64 %239, 1
  %247 = select i1 %245, i64 %239, i64 %246
  %248 = mul i64 %239, %231
  %249 = add i64 %248, %233
  %250 = add i64 %249, %226
  %251 = getelementptr inbounds i8, ptr %230, i64 %250
  %252 = load <16 x i8>, ptr %251, align 16, !invariant.load !1
  %253 = bitcast <16 x i8> %240 to <8 x i16>
  %254 = extractelement <8 x i16> %253, i32 0
  %255 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %254)
  %256 = insertelement <8 x i32> undef, i32 %255, i32 0
  %257 = extractelement <8 x i16> %253, i32 1
  %258 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %257)
  %259 = insertelement <8 x i32> %256, i32 %258, i32 1
  %260 = extractelement <8 x i16> %253, i32 2
  %261 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %260)
  %262 = insertelement <8 x i32> %259, i32 %261, i32 2
  %263 = extractelement <8 x i16> %253, i32 3
  %264 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %263)
  %265 = insertelement <8 x i32> %262, i32 %264, i32 3
  %266 = extractelement <8 x i16> %253, i32 4
  %267 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %266)
  %268 = insertelement <8 x i32> %265, i32 %267, i32 4
  %269 = extractelement <8 x i16> %253, i32 5
  %270 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %269)
  %271 = insertelement <8 x i32> %268, i32 %270, i32 5
  %272 = extractelement <8 x i16> %253, i32 6
  %273 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %272)
  %274 = insertelement <8 x i32> %271, i32 %273, i32 6
  %275 = extractelement <8 x i16> %253, i32 7
  %276 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %275)
  %277 = insertelement <8 x i32> %274, i32 %276, i32 7
  %278 = bitcast <8 x i32> %277 to <16 x half>
  %279 = bitcast <16 x i8> %252 to <8 x i16>
  %280 = extractelement <8 x i16> %279, i32 0
  %281 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %280)
  %282 = insertelement <8 x i32> undef, i32 %281, i32 0
  %283 = extractelement <8 x i16> %279, i32 1
  %284 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %283)
  %285 = insertelement <8 x i32> %282, i32 %284, i32 1
  %286 = extractelement <8 x i16> %279, i32 2
  %287 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %286)
  %288 = insertelement <8 x i32> %285, i32 %287, i32 2
  %289 = extractelement <8 x i16> %279, i32 3
  %290 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %289)
  %291 = insertelement <8 x i32> %288, i32 %290, i32 3
  %292 = extractelement <8 x i16> %279, i32 4
  %293 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %292)
  %294 = insertelement <8 x i32> %291, i32 %293, i32 4
  %295 = extractelement <8 x i16> %279, i32 5
  %296 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %295)
  %297 = insertelement <8 x i32> %294, i32 %296, i32 5
  %298 = extractelement <8 x i16> %279, i32 6
  %299 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %298)
  %300 = insertelement <8 x i32> %297, i32 %299, i32 6
  %301 = extractelement <8 x i16> %279, i32 7
  %302 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %301)
  %303 = insertelement <8 x i32> %300, i32 %302, i32 7
  %304 = bitcast <8 x i32> %303 to <16 x half>
  %305 = fadd contract <16 x half> %278, %304
  %306 = fpext <16 x half> %305 to <16 x float>
  %307 = extractelement <16 x float> %306, i32 1
  %308 = extractelement <16 x float> %306, i32 0
  %309 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %307, float %308)
  %310 = insertelement <8 x i16> undef, i16 %309, i32 0
  %311 = extractelement <16 x float> %306, i32 3
  %312 = extractelement <16 x float> %306, i32 2
  %313 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %311, float %312)
  %314 = insertelement <8 x i16> %310, i16 %313, i32 1
  %315 = extractelement <16 x float> %306, i32 5
  %316 = extractelement <16 x float> %306, i32 4
  %317 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %315, float %316)
  %318 = insertelement <8 x i16> %314, i16 %317, i32 2
  %319 = extractelement <16 x float> %306, i32 7
  %320 = extractelement <16 x float> %306, i32 6
  %321 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %319, float %320)
  %322 = insertelement <8 x i16> %318, i16 %321, i32 3
  %323 = extractelement <16 x float> %306, i32 9
  %324 = extractelement <16 x float> %306, i32 8
  %325 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %323, float %324)
  %326 = insertelement <8 x i16> %322, i16 %325, i32 4
  %327 = extractelement <16 x float> %306, i32 11
  %328 = extractelement <16 x float> %306, i32 10
  %329 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %327, float %328)
  %330 = insertelement <8 x i16> %326, i16 %329, i32 5
  %331 = extractelement <16 x float> %306, i32 13
  %332 = extractelement <16 x float> %306, i32 12
  %333 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %331, float %332)
  %334 = insertelement <8 x i16> %330, i16 %333, i32 6
  %335 = extractelement <16 x float> %306, i32 15
  %336 = extractelement <16 x float> %306, i32 14
  %337 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %335, float %336)
  %338 = insertelement <8 x i16> %334, i16 %337, i32 7
  %339 = bitcast <8 x i16> %338 to <16 x i8>
  br label %238

340:                                              ; preds = %243
  %341 = phi <16 x i8> [ %240, %243 ]
  %342 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %229, 0
  %343 = trunc i64 %223 to i32
  %344 = mul i32 %343, 512
  %345 = trunc i64 %226 to i32
  %346 = add i32 %344, %345
  %347 = sext i32 %346 to i64
  %348 = getelementptr inbounds i8, ptr %342, i64 %347
  store <16 x i8> %341, ptr %348, align 16
  br label %350

349:                                              ; preds = %203
  br label %350

350:                                              ; preds = %349, %340
  %351 = add i64 %52, %18
  %352 = mul i64 %351, 16
  %353 = icmp slt i64 %352, 0
  %354 = load i64, ptr %19, align 8
  %355 = icmp slt i64 %351, %354
  br i1 %355, label %356, label %496

356:                                              ; preds = %350
  %357 = load { i64, i64 }, ptr %6, align 8
  %358 = extractvalue { i64, i64 } %357, 1
  %359 = icmp eq i64 %358, 0
  %360 = select i1 %359, i64 1, i64 %358
  %361 = sdiv i64 %352, %360
  %362 = mul i64 %361, %358
  %363 = sub i64 %352, %362
  %364 = icmp slt i64 %358, 0
  %365 = xor i1 %364, %353
  %366 = icmp ne i64 %363, 0
  %367 = and i1 %365, %366
  %368 = select i1 %367, i64 1, i64 0
  %369 = sub i64 %361, %368
  %370 = select i1 %359, i64 0, i64 %369
  %371 = select i1 %367, i64 %358, i64 0
  %372 = add i64 %363, %371
  %373 = select i1 %359, i64 0, i64 %372
  %374 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %375 = load i64, ptr %4, align 8
  %376 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %377 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %374, 0
  %378 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %374, 1, 1, 0
  %379 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %374, 1, 1, 1
  %380 = mul i64 %370, %379
  %381 = add i64 %380, %373
  %382 = getelementptr inbounds i8, ptr %377, i64 %381
  %383 = load <16 x i8>, ptr %382, align 16, !invariant.load !1
  %384 = call i64 @llvm.smax.i64(i64 %375, i64 1)
  br label %385

385:                                              ; preds = %391, %356
  %386 = phi i64 [ 1, %356 ], [ %394, %391 ]
  %387 = phi <16 x i8> [ %383, %356 ], [ %486, %391 ]
  %388 = icmp slt i64 %386, %384
  br i1 %388, label %389, label %390

389:                                              ; preds = %385
  br label %391

390:                                              ; preds = %385
  br label %487

391:                                              ; preds = %389
  %392 = icmp eq i64 %386, %384
  %393 = add i64 %386, 1
  %394 = select i1 %392, i64 %386, i64 %393
  %395 = mul i64 %386, %378
  %396 = add i64 %395, %380
  %397 = add i64 %396, %373
  %398 = getelementptr inbounds i8, ptr %377, i64 %397
  %399 = load <16 x i8>, ptr %398, align 16, !invariant.load !1
  %400 = bitcast <16 x i8> %387 to <8 x i16>
  %401 = extractelement <8 x i16> %400, i32 0
  %402 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %401)
  %403 = insertelement <8 x i32> undef, i32 %402, i32 0
  %404 = extractelement <8 x i16> %400, i32 1
  %405 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %404)
  %406 = insertelement <8 x i32> %403, i32 %405, i32 1
  %407 = extractelement <8 x i16> %400, i32 2
  %408 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %407)
  %409 = insertelement <8 x i32> %406, i32 %408, i32 2
  %410 = extractelement <8 x i16> %400, i32 3
  %411 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %410)
  %412 = insertelement <8 x i32> %409, i32 %411, i32 3
  %413 = extractelement <8 x i16> %400, i32 4
  %414 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %413)
  %415 = insertelement <8 x i32> %412, i32 %414, i32 4
  %416 = extractelement <8 x i16> %400, i32 5
  %417 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %416)
  %418 = insertelement <8 x i32> %415, i32 %417, i32 5
  %419 = extractelement <8 x i16> %400, i32 6
  %420 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %419)
  %421 = insertelement <8 x i32> %418, i32 %420, i32 6
  %422 = extractelement <8 x i16> %400, i32 7
  %423 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %422)
  %424 = insertelement <8 x i32> %421, i32 %423, i32 7
  %425 = bitcast <8 x i32> %424 to <16 x half>
  %426 = bitcast <16 x i8> %399 to <8 x i16>
  %427 = extractelement <8 x i16> %426, i32 0
  %428 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %427)
  %429 = insertelement <8 x i32> undef, i32 %428, i32 0
  %430 = extractelement <8 x i16> %426, i32 1
  %431 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %430)
  %432 = insertelement <8 x i32> %429, i32 %431, i32 1
  %433 = extractelement <8 x i16> %426, i32 2
  %434 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %433)
  %435 = insertelement <8 x i32> %432, i32 %434, i32 2
  %436 = extractelement <8 x i16> %426, i32 3
  %437 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %436)
  %438 = insertelement <8 x i32> %435, i32 %437, i32 3
  %439 = extractelement <8 x i16> %426, i32 4
  %440 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %439)
  %441 = insertelement <8 x i32> %438, i32 %440, i32 4
  %442 = extractelement <8 x i16> %426, i32 5
  %443 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %442)
  %444 = insertelement <8 x i32> %441, i32 %443, i32 5
  %445 = extractelement <8 x i16> %426, i32 6
  %446 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %445)
  %447 = insertelement <8 x i32> %444, i32 %446, i32 6
  %448 = extractelement <8 x i16> %426, i32 7
  %449 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %448)
  %450 = insertelement <8 x i32> %447, i32 %449, i32 7
  %451 = bitcast <8 x i32> %450 to <16 x half>
  %452 = fadd contract <16 x half> %425, %451
  %453 = fpext <16 x half> %452 to <16 x float>
  %454 = extractelement <16 x float> %453, i32 1
  %455 = extractelement <16 x float> %453, i32 0
  %456 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %454, float %455)
  %457 = insertelement <8 x i16> undef, i16 %456, i32 0
  %458 = extractelement <16 x float> %453, i32 3
  %459 = extractelement <16 x float> %453, i32 2
  %460 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %458, float %459)
  %461 = insertelement <8 x i16> %457, i16 %460, i32 1
  %462 = extractelement <16 x float> %453, i32 5
  %463 = extractelement <16 x float> %453, i32 4
  %464 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %462, float %463)
  %465 = insertelement <8 x i16> %461, i16 %464, i32 2
  %466 = extractelement <16 x float> %453, i32 7
  %467 = extractelement <16 x float> %453, i32 6
  %468 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %466, float %467)
  %469 = insertelement <8 x i16> %465, i16 %468, i32 3
  %470 = extractelement <16 x float> %453, i32 9
  %471 = extractelement <16 x float> %453, i32 8
  %472 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %470, float %471)
  %473 = insertelement <8 x i16> %469, i16 %472, i32 4
  %474 = extractelement <16 x float> %453, i32 11
  %475 = extractelement <16 x float> %453, i32 10
  %476 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %474, float %475)
  %477 = insertelement <8 x i16> %473, i16 %476, i32 5
  %478 = extractelement <16 x float> %453, i32 13
  %479 = extractelement <16 x float> %453, i32 12
  %480 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %478, float %479)
  %481 = insertelement <8 x i16> %477, i16 %480, i32 6
  %482 = extractelement <16 x float> %453, i32 15
  %483 = extractelement <16 x float> %453, i32 14
  %484 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %482, float %483)
  %485 = insertelement <8 x i16> %481, i16 %484, i32 7
  %486 = bitcast <8 x i16> %485 to <16 x i8>
  br label %385

487:                                              ; preds = %390
  %488 = phi <16 x i8> [ %387, %390 ]
  %489 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %376, 0
  %490 = trunc i64 %370 to i32
  %491 = mul i32 %490, 512
  %492 = trunc i64 %373 to i32
  %493 = add i32 %491, %492
  %494 = sext i32 %493 to i64
  %495 = getelementptr inbounds i8, ptr %489, i64 %494
  store <16 x i8> %488, ptr %495, align 16
  br label %497

496:                                              ; preds = %350
  br label %497

497:                                              ; preds = %496, %487
  %498 = add i64 %52, %17
  %499 = mul i64 %498, 16
  %500 = icmp slt i64 %499, 0
  %501 = load i64, ptr %19, align 8
  %502 = icmp slt i64 %498, %501
  br i1 %502, label %503, label %643

503:                                              ; preds = %497
  %504 = load { i64, i64 }, ptr %6, align 8
  %505 = extractvalue { i64, i64 } %504, 1
  %506 = icmp eq i64 %505, 0
  %507 = select i1 %506, i64 1, i64 %505
  %508 = sdiv i64 %499, %507
  %509 = mul i64 %508, %505
  %510 = sub i64 %499, %509
  %511 = icmp slt i64 %505, 0
  %512 = xor i1 %511, %500
  %513 = icmp ne i64 %510, 0
  %514 = and i1 %512, %513
  %515 = select i1 %514, i64 1, i64 0
  %516 = sub i64 %508, %515
  %517 = select i1 %506, i64 0, i64 %516
  %518 = select i1 %514, i64 %505, i64 0
  %519 = add i64 %510, %518
  %520 = select i1 %506, i64 0, i64 %519
  %521 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %522 = load i64, ptr %4, align 8
  %523 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %524 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %521, 0
  %525 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %521, 1, 1, 0
  %526 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %521, 1, 1, 1
  %527 = mul i64 %517, %526
  %528 = add i64 %527, %520
  %529 = getelementptr inbounds i8, ptr %524, i64 %528
  %530 = load <16 x i8>, ptr %529, align 16, !invariant.load !1
  %531 = call i64 @llvm.smax.i64(i64 %522, i64 1)
  br label %532

532:                                              ; preds = %538, %503
  %533 = phi i64 [ 1, %503 ], [ %541, %538 ]
  %534 = phi <16 x i8> [ %530, %503 ], [ %633, %538 ]
  %535 = icmp slt i64 %533, %531
  br i1 %535, label %536, label %537

536:                                              ; preds = %532
  br label %538

537:                                              ; preds = %532
  br label %634

538:                                              ; preds = %536
  %539 = icmp eq i64 %533, %531
  %540 = add i64 %533, 1
  %541 = select i1 %539, i64 %533, i64 %540
  %542 = mul i64 %533, %525
  %543 = add i64 %542, %527
  %544 = add i64 %543, %520
  %545 = getelementptr inbounds i8, ptr %524, i64 %544
  %546 = load <16 x i8>, ptr %545, align 16, !invariant.load !1
  %547 = bitcast <16 x i8> %534 to <8 x i16>
  %548 = extractelement <8 x i16> %547, i32 0
  %549 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %548)
  %550 = insertelement <8 x i32> undef, i32 %549, i32 0
  %551 = extractelement <8 x i16> %547, i32 1
  %552 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %551)
  %553 = insertelement <8 x i32> %550, i32 %552, i32 1
  %554 = extractelement <8 x i16> %547, i32 2
  %555 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %554)
  %556 = insertelement <8 x i32> %553, i32 %555, i32 2
  %557 = extractelement <8 x i16> %547, i32 3
  %558 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %557)
  %559 = insertelement <8 x i32> %556, i32 %558, i32 3
  %560 = extractelement <8 x i16> %547, i32 4
  %561 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %560)
  %562 = insertelement <8 x i32> %559, i32 %561, i32 4
  %563 = extractelement <8 x i16> %547, i32 5
  %564 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %563)
  %565 = insertelement <8 x i32> %562, i32 %564, i32 5
  %566 = extractelement <8 x i16> %547, i32 6
  %567 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %566)
  %568 = insertelement <8 x i32> %565, i32 %567, i32 6
  %569 = extractelement <8 x i16> %547, i32 7
  %570 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %569)
  %571 = insertelement <8 x i32> %568, i32 %570, i32 7
  %572 = bitcast <8 x i32> %571 to <16 x half>
  %573 = bitcast <16 x i8> %546 to <8 x i16>
  %574 = extractelement <8 x i16> %573, i32 0
  %575 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %574)
  %576 = insertelement <8 x i32> undef, i32 %575, i32 0
  %577 = extractelement <8 x i16> %573, i32 1
  %578 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %577)
  %579 = insertelement <8 x i32> %576, i32 %578, i32 1
  %580 = extractelement <8 x i16> %573, i32 2
  %581 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %580)
  %582 = insertelement <8 x i32> %579, i32 %581, i32 2
  %583 = extractelement <8 x i16> %573, i32 3
  %584 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %583)
  %585 = insertelement <8 x i32> %582, i32 %584, i32 3
  %586 = extractelement <8 x i16> %573, i32 4
  %587 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %586)
  %588 = insertelement <8 x i32> %585, i32 %587, i32 4
  %589 = extractelement <8 x i16> %573, i32 5
  %590 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %589)
  %591 = insertelement <8 x i32> %588, i32 %590, i32 5
  %592 = extractelement <8 x i16> %573, i32 6
  %593 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %592)
  %594 = insertelement <8 x i32> %591, i32 %593, i32 6
  %595 = extractelement <8 x i16> %573, i32 7
  %596 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %595)
  %597 = insertelement <8 x i32> %594, i32 %596, i32 7
  %598 = bitcast <8 x i32> %597 to <16 x half>
  %599 = fadd contract <16 x half> %572, %598
  %600 = fpext <16 x half> %599 to <16 x float>
  %601 = extractelement <16 x float> %600, i32 1
  %602 = extractelement <16 x float> %600, i32 0
  %603 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %601, float %602)
  %604 = insertelement <8 x i16> undef, i16 %603, i32 0
  %605 = extractelement <16 x float> %600, i32 3
  %606 = extractelement <16 x float> %600, i32 2
  %607 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %605, float %606)
  %608 = insertelement <8 x i16> %604, i16 %607, i32 1
  %609 = extractelement <16 x float> %600, i32 5
  %610 = extractelement <16 x float> %600, i32 4
  %611 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %609, float %610)
  %612 = insertelement <8 x i16> %608, i16 %611, i32 2
  %613 = extractelement <16 x float> %600, i32 7
  %614 = extractelement <16 x float> %600, i32 6
  %615 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %613, float %614)
  %616 = insertelement <8 x i16> %612, i16 %615, i32 3
  %617 = extractelement <16 x float> %600, i32 9
  %618 = extractelement <16 x float> %600, i32 8
  %619 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %617, float %618)
  %620 = insertelement <8 x i16> %616, i16 %619, i32 4
  %621 = extractelement <16 x float> %600, i32 11
  %622 = extractelement <16 x float> %600, i32 10
  %623 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %621, float %622)
  %624 = insertelement <8 x i16> %620, i16 %623, i32 5
  %625 = extractelement <16 x float> %600, i32 13
  %626 = extractelement <16 x float> %600, i32 12
  %627 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %625, float %626)
  %628 = insertelement <8 x i16> %624, i16 %627, i32 6
  %629 = extractelement <16 x float> %600, i32 15
  %630 = extractelement <16 x float> %600, i32 14
  %631 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %629, float %630)
  %632 = insertelement <8 x i16> %628, i16 %631, i32 7
  %633 = bitcast <8 x i16> %632 to <16 x i8>
  br label %532

634:                                              ; preds = %537
  %635 = phi <16 x i8> [ %534, %537 ]
  %636 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %523, 0
  %637 = trunc i64 %517 to i32
  %638 = mul i32 %637, 512
  %639 = trunc i64 %520 to i32
  %640 = add i32 %638, %639
  %641 = sext i32 %640 to i64
  %642 = getelementptr inbounds i8, ptr %636, i64 %641
  store <16 x i8> %635, ptr %642, align 16
  br label %644

643:                                              ; preds = %497
  br label %644

644:                                              ; preds = %643, %634
  br label %28

645:                                              ; preds = %57
  %646 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %647 = load i64, ptr %646, align 8
  %648 = icmp slt i64 %13, %647
  br i1 %648, label %649, label %743

649:                                              ; preds = %645
  %650 = load i64, ptr %7, align 8
  %651 = add i64 %650, %13
  %652 = load { i64, i64 }, ptr %6, align 8
  %653 = extractvalue { i64, i64 } %652, 1
  %654 = icmp eq i64 %653, 0
  %655 = select i1 %654, i64 1, i64 %653
  %656 = sdiv i64 %651, %655
  %657 = mul i64 %656, %653
  %658 = sub i64 %651, %657
  %659 = icmp slt i64 %653, 0
  %660 = icmp slt i64 %651, 0
  %661 = xor i1 %659, %660
  %662 = icmp ne i64 %658, 0
  %663 = and i1 %661, %662
  %664 = select i1 %663, i64 1, i64 0
  %665 = sub i64 %656, %664
  %666 = select i1 %654, i64 0, i64 %665
  %667 = select i1 %663, i64 %653, i64 0
  %668 = add i64 %658, %667
  %669 = select i1 %654, i64 0, i64 %668
  %670 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %671 = load i64, ptr %4, align 8
  %672 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %673 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %670, 0
  %674 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %670, 1, 1, 0
  %675 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %670, 1, 1, 1
  %676 = mul i64 %666, %675
  %677 = add i64 %676, %669
  %678 = getelementptr inbounds i8, ptr %673, i64 %677
  br label %679

679:                                              ; preds = %685, %649
  %680 = phi i64 [ 0, %649 ], [ %688, %685 ]
  %681 = phi i8 [ 0, %649 ], [ %690, %685 ]
  %682 = icmp slt i64 %680, 1
  br i1 %682, label %683, label %684

683:                                              ; preds = %679
  br label %685

684:                                              ; preds = %679
  br label %691

685:                                              ; preds = %683
  %686 = icmp eq i64 %680, 1
  %687 = add i64 %680, 1
  %688 = select i1 %686, i64 %680, i64 %687
  %689 = getelementptr inbounds i8, ptr %678, i64 %680
  %690 = load i8, ptr %689, align 1, !invariant.load !1
  br label %679

691:                                              ; preds = %684
  %692 = phi i8 [ %681, %684 ]
  %693 = call i64 @llvm.smax.i64(i64 %671, i64 1)
  br label %694

694:                                              ; preds = %720, %691
  %695 = phi i64 [ 1, %691 ], [ %703, %720 ]
  %696 = phi i8 [ %692, %691 ], [ %733, %720 ]
  %697 = icmp slt i64 %695, %693
  br i1 %697, label %698, label %699

698:                                              ; preds = %694
  br label %700

699:                                              ; preds = %694
  br label %734

700:                                              ; preds = %698
  %701 = icmp eq i64 %695, %693
  %702 = add i64 %695, 1
  %703 = select i1 %701, i64 %695, i64 %702
  %704 = mul i64 %695, %674
  %705 = add i64 %704, %676
  %706 = add i64 %705, %669
  %707 = getelementptr inbounds i8, ptr %673, i64 %706
  br label %708

708:                                              ; preds = %714, %700
  %709 = phi i64 [ 0, %700 ], [ %717, %714 ]
  %710 = phi i8 [ 0, %700 ], [ %719, %714 ]
  %711 = icmp slt i64 %709, 1
  br i1 %711, label %712, label %713

712:                                              ; preds = %708
  br label %714

713:                                              ; preds = %708
  br label %720

714:                                              ; preds = %712
  %715 = icmp eq i64 %709, 1
  %716 = add i64 %709, 1
  %717 = select i1 %715, i64 %709, i64 %716
  %718 = getelementptr inbounds i8, ptr %707, i64 %709
  %719 = load i8, ptr %718, align 1, !invariant.load !1
  br label %708

720:                                              ; preds = %713
  %721 = phi i8 [ %710, %713 ]
  %722 = zext i8 %696 to i16
  %723 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %722)
  %724 = trunc i32 %723 to i16
  %725 = bitcast i16 %724 to half
  %726 = zext i8 %721 to i16
  %727 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %726)
  %728 = trunc i32 %727 to i16
  %729 = bitcast i16 %728 to half
  %730 = fadd contract half %725, %729
  %731 = fpext half %730 to float
  %732 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %731)
  %733 = trunc i16 %732 to i8
  br label %694

734:                                              ; preds = %699
  %735 = phi i8 [ %696, %699 ]
  %736 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %672, 0
  %737 = trunc i64 %666 to i32
  %738 = mul i32 %737, 512
  %739 = trunc i64 %669 to i32
  %740 = add i32 %738, %739
  %741 = sext i32 %740 to i64
  %742 = getelementptr inbounds i8, ptr %736, i64 %741
  store i8 %735, ptr %742, align 1
  br label %744

743:                                              ; preds = %645
  br label %744

744:                                              ; preds = %743, %734
  call void @llvm.nvvm.griddepcontrol.launch.dependents()
  ret void
}

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.wait() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, -2147483648) i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: nounwind
declare void @llvm.nvvm.griddepcontrol.launch.dependents() #2

attributes #0 = { noinline "target-cpu"="sm_90a" "target-features"="+ptx85,+sm_90a" "tune-cpu"="sm_90a" }
attributes #1 = { norecurse "nvvm.maxntid"="256" "target-cpu"="sm_90a" "target-features"="+ptx85,+sm_90a" "tune-cpu"="sm_90a" }
attributes #2 = { nounwind }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
