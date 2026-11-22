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
define dso_local ptx_kernel void @matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b(ptr noundef nonnull readonly byval({ { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }) %0) #1 {
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

28:                                               ; preds = %636, %1
  %29 = phi i64 [ %23, %1 ], [ %53, %636 ]
  %30 = phi i64 [ 0, %1 ], [ %54, %636 ]
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
  %56 = trunc i64 %55 to i32
  br i1 %51, label %57, label %58

57:                                               ; preds = %50
  br label %637

58:                                               ; preds = %50
  br label %59

59:                                               ; preds = %58
  %60 = load i64, ptr %19, align 8
  %61 = icmp slt i64 %52, %60
  br i1 %61, label %62, label %200

62:                                               ; preds = %59
  %63 = load { i64, i64 }, ptr %6, align 8
  %64 = extractvalue { i64, i64 } %63, 1
  %65 = trunc i64 %64 to i32
  %66 = icmp eq i32 %65, 0
  %67 = select i1 %66, i32 1, i32 %65
  %68 = icmp eq i32 %67, 0
  %69 = select i1 %68, i32 1, i32 %67
  %70 = udiv i32 %56, %69
  %71 = select i1 %68, i32 0, i32 %70
  %72 = urem i32 %56, %69
  %73 = select i1 %68, i32 0, i32 %72
  %74 = select i1 %66, i32 0, i32 %71
  %75 = select i1 %66, i32 0, i32 %73
  %76 = zext i32 %74 to i64
  %77 = zext i32 %75 to i64
  %78 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %79 = load i64, ptr %4, align 8
  %80 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %81 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %78, 0
  %82 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %78, 1, 1, 0
  %83 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %78, 1, 1, 1
  %84 = mul i64 %76, %83
  %85 = add i64 %84, %77
  %86 = getelementptr inbounds i8, ptr %81, i64 %85
  %87 = load <16 x i8>, ptr %86, align 16, !invariant.load !1
  %88 = call i64 @llvm.smax.i64(i64 %79, i64 1)
  br label %89

89:                                               ; preds = %95, %62
  %90 = phi i64 [ 1, %62 ], [ %98, %95 ]
  %91 = phi <16 x i8> [ %87, %62 ], [ %190, %95 ]
  %92 = icmp slt i64 %90, %88
  br i1 %92, label %93, label %94

93:                                               ; preds = %89
  br label %95

94:                                               ; preds = %89
  br label %191

95:                                               ; preds = %93
  %96 = icmp eq i64 %90, %88
  %97 = add i64 %90, 1
  %98 = select i1 %96, i64 %90, i64 %97
  %99 = mul i64 %90, %82
  %100 = add i64 %99, %84
  %101 = add i64 %100, %77
  %102 = getelementptr inbounds i8, ptr %81, i64 %101
  %103 = load <16 x i8>, ptr %102, align 16, !invariant.load !1
  %104 = bitcast <16 x i8> %91 to <8 x i16>
  %105 = extractelement <8 x i16> %104, i32 0
  %106 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %105)
  %107 = insertelement <8 x i32> undef, i32 %106, i32 0
  %108 = extractelement <8 x i16> %104, i32 1
  %109 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %108)
  %110 = insertelement <8 x i32> %107, i32 %109, i32 1
  %111 = extractelement <8 x i16> %104, i32 2
  %112 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %111)
  %113 = insertelement <8 x i32> %110, i32 %112, i32 2
  %114 = extractelement <8 x i16> %104, i32 3
  %115 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %114)
  %116 = insertelement <8 x i32> %113, i32 %115, i32 3
  %117 = extractelement <8 x i16> %104, i32 4
  %118 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %117)
  %119 = insertelement <8 x i32> %116, i32 %118, i32 4
  %120 = extractelement <8 x i16> %104, i32 5
  %121 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %120)
  %122 = insertelement <8 x i32> %119, i32 %121, i32 5
  %123 = extractelement <8 x i16> %104, i32 6
  %124 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %123)
  %125 = insertelement <8 x i32> %122, i32 %124, i32 6
  %126 = extractelement <8 x i16> %104, i32 7
  %127 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %126)
  %128 = insertelement <8 x i32> %125, i32 %127, i32 7
  %129 = bitcast <8 x i32> %128 to <16 x half>
  %130 = bitcast <16 x i8> %103 to <8 x i16>
  %131 = extractelement <8 x i16> %130, i32 0
  %132 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %131)
  %133 = insertelement <8 x i32> undef, i32 %132, i32 0
  %134 = extractelement <8 x i16> %130, i32 1
  %135 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %134)
  %136 = insertelement <8 x i32> %133, i32 %135, i32 1
  %137 = extractelement <8 x i16> %130, i32 2
  %138 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %137)
  %139 = insertelement <8 x i32> %136, i32 %138, i32 2
  %140 = extractelement <8 x i16> %130, i32 3
  %141 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %140)
  %142 = insertelement <8 x i32> %139, i32 %141, i32 3
  %143 = extractelement <8 x i16> %130, i32 4
  %144 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %143)
  %145 = insertelement <8 x i32> %142, i32 %144, i32 4
  %146 = extractelement <8 x i16> %130, i32 5
  %147 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %146)
  %148 = insertelement <8 x i32> %145, i32 %147, i32 5
  %149 = extractelement <8 x i16> %130, i32 6
  %150 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %149)
  %151 = insertelement <8 x i32> %148, i32 %150, i32 6
  %152 = extractelement <8 x i16> %130, i32 7
  %153 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %152)
  %154 = insertelement <8 x i32> %151, i32 %153, i32 7
  %155 = bitcast <8 x i32> %154 to <16 x half>
  %156 = fadd contract <16 x half> %129, %155
  %157 = fpext <16 x half> %156 to <16 x float>
  %158 = extractelement <16 x float> %157, i32 1
  %159 = extractelement <16 x float> %157, i32 0
  %160 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %158, float %159)
  %161 = insertelement <8 x i16> undef, i16 %160, i32 0
  %162 = extractelement <16 x float> %157, i32 3
  %163 = extractelement <16 x float> %157, i32 2
  %164 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %162, float %163)
  %165 = insertelement <8 x i16> %161, i16 %164, i32 1
  %166 = extractelement <16 x float> %157, i32 5
  %167 = extractelement <16 x float> %157, i32 4
  %168 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %166, float %167)
  %169 = insertelement <8 x i16> %165, i16 %168, i32 2
  %170 = extractelement <16 x float> %157, i32 7
  %171 = extractelement <16 x float> %157, i32 6
  %172 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %170, float %171)
  %173 = insertelement <8 x i16> %169, i16 %172, i32 3
  %174 = extractelement <16 x float> %157, i32 9
  %175 = extractelement <16 x float> %157, i32 8
  %176 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %174, float %175)
  %177 = insertelement <8 x i16> %173, i16 %176, i32 4
  %178 = extractelement <16 x float> %157, i32 11
  %179 = extractelement <16 x float> %157, i32 10
  %180 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %178, float %179)
  %181 = insertelement <8 x i16> %177, i16 %180, i32 5
  %182 = extractelement <16 x float> %157, i32 13
  %183 = extractelement <16 x float> %157, i32 12
  %184 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %182, float %183)
  %185 = insertelement <8 x i16> %181, i16 %184, i32 6
  %186 = extractelement <16 x float> %157, i32 15
  %187 = extractelement <16 x float> %157, i32 14
  %188 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %186, float %187)
  %189 = insertelement <8 x i16> %185, i16 %188, i32 7
  %190 = bitcast <8 x i16> %189 to <16 x i8>
  br label %89

191:                                              ; preds = %94
  %192 = phi <16 x i8> [ %91, %94 ]
  %193 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %80, 0
  %194 = trunc i64 %76 to i32
  %195 = mul i32 %194, 512
  %196 = trunc i64 %77 to i32
  %197 = add i32 %195, %196
  %198 = sext i32 %197 to i64
  %199 = getelementptr inbounds i8, ptr %193, i64 %198
  store <16 x i8> %192, ptr %199, align 16
  br label %201

200:                                              ; preds = %59
  br label %201

201:                                              ; preds = %200, %191
  %202 = add i64 %52, %16
  %203 = mul i64 %202, 16
  %204 = trunc i64 %203 to i32
  %205 = load i64, ptr %19, align 8
  %206 = icmp slt i64 %202, %205
  br i1 %206, label %207, label %345

207:                                              ; preds = %201
  %208 = load { i64, i64 }, ptr %6, align 8
  %209 = extractvalue { i64, i64 } %208, 1
  %210 = trunc i64 %209 to i32
  %211 = icmp eq i32 %210, 0
  %212 = select i1 %211, i32 1, i32 %210
  %213 = icmp eq i32 %212, 0
  %214 = select i1 %213, i32 1, i32 %212
  %215 = udiv i32 %204, %214
  %216 = select i1 %213, i32 0, i32 %215
  %217 = urem i32 %204, %214
  %218 = select i1 %213, i32 0, i32 %217
  %219 = select i1 %211, i32 0, i32 %216
  %220 = select i1 %211, i32 0, i32 %218
  %221 = zext i32 %219 to i64
  %222 = zext i32 %220 to i64
  %223 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %224 = load i64, ptr %4, align 8
  %225 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %226 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %223, 0
  %227 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %223, 1, 1, 0
  %228 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %223, 1, 1, 1
  %229 = mul i64 %221, %228
  %230 = add i64 %229, %222
  %231 = getelementptr inbounds i8, ptr %226, i64 %230
  %232 = load <16 x i8>, ptr %231, align 16, !invariant.load !1
  %233 = call i64 @llvm.smax.i64(i64 %224, i64 1)
  br label %234

234:                                              ; preds = %240, %207
  %235 = phi i64 [ 1, %207 ], [ %243, %240 ]
  %236 = phi <16 x i8> [ %232, %207 ], [ %335, %240 ]
  %237 = icmp slt i64 %235, %233
  br i1 %237, label %238, label %239

238:                                              ; preds = %234
  br label %240

239:                                              ; preds = %234
  br label %336

240:                                              ; preds = %238
  %241 = icmp eq i64 %235, %233
  %242 = add i64 %235, 1
  %243 = select i1 %241, i64 %235, i64 %242
  %244 = mul i64 %235, %227
  %245 = add i64 %244, %229
  %246 = add i64 %245, %222
  %247 = getelementptr inbounds i8, ptr %226, i64 %246
  %248 = load <16 x i8>, ptr %247, align 16, !invariant.load !1
  %249 = bitcast <16 x i8> %236 to <8 x i16>
  %250 = extractelement <8 x i16> %249, i32 0
  %251 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %250)
  %252 = insertelement <8 x i32> undef, i32 %251, i32 0
  %253 = extractelement <8 x i16> %249, i32 1
  %254 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %253)
  %255 = insertelement <8 x i32> %252, i32 %254, i32 1
  %256 = extractelement <8 x i16> %249, i32 2
  %257 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %256)
  %258 = insertelement <8 x i32> %255, i32 %257, i32 2
  %259 = extractelement <8 x i16> %249, i32 3
  %260 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %259)
  %261 = insertelement <8 x i32> %258, i32 %260, i32 3
  %262 = extractelement <8 x i16> %249, i32 4
  %263 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %262)
  %264 = insertelement <8 x i32> %261, i32 %263, i32 4
  %265 = extractelement <8 x i16> %249, i32 5
  %266 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %265)
  %267 = insertelement <8 x i32> %264, i32 %266, i32 5
  %268 = extractelement <8 x i16> %249, i32 6
  %269 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %268)
  %270 = insertelement <8 x i32> %267, i32 %269, i32 6
  %271 = extractelement <8 x i16> %249, i32 7
  %272 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %271)
  %273 = insertelement <8 x i32> %270, i32 %272, i32 7
  %274 = bitcast <8 x i32> %273 to <16 x half>
  %275 = bitcast <16 x i8> %248 to <8 x i16>
  %276 = extractelement <8 x i16> %275, i32 0
  %277 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %276)
  %278 = insertelement <8 x i32> undef, i32 %277, i32 0
  %279 = extractelement <8 x i16> %275, i32 1
  %280 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %279)
  %281 = insertelement <8 x i32> %278, i32 %280, i32 1
  %282 = extractelement <8 x i16> %275, i32 2
  %283 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %282)
  %284 = insertelement <8 x i32> %281, i32 %283, i32 2
  %285 = extractelement <8 x i16> %275, i32 3
  %286 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %285)
  %287 = insertelement <8 x i32> %284, i32 %286, i32 3
  %288 = extractelement <8 x i16> %275, i32 4
  %289 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %288)
  %290 = insertelement <8 x i32> %287, i32 %289, i32 4
  %291 = extractelement <8 x i16> %275, i32 5
  %292 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %291)
  %293 = insertelement <8 x i32> %290, i32 %292, i32 5
  %294 = extractelement <8 x i16> %275, i32 6
  %295 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %294)
  %296 = insertelement <8 x i32> %293, i32 %295, i32 6
  %297 = extractelement <8 x i16> %275, i32 7
  %298 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %297)
  %299 = insertelement <8 x i32> %296, i32 %298, i32 7
  %300 = bitcast <8 x i32> %299 to <16 x half>
  %301 = fadd contract <16 x half> %274, %300
  %302 = fpext <16 x half> %301 to <16 x float>
  %303 = extractelement <16 x float> %302, i32 1
  %304 = extractelement <16 x float> %302, i32 0
  %305 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %303, float %304)
  %306 = insertelement <8 x i16> undef, i16 %305, i32 0
  %307 = extractelement <16 x float> %302, i32 3
  %308 = extractelement <16 x float> %302, i32 2
  %309 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %307, float %308)
  %310 = insertelement <8 x i16> %306, i16 %309, i32 1
  %311 = extractelement <16 x float> %302, i32 5
  %312 = extractelement <16 x float> %302, i32 4
  %313 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %311, float %312)
  %314 = insertelement <8 x i16> %310, i16 %313, i32 2
  %315 = extractelement <16 x float> %302, i32 7
  %316 = extractelement <16 x float> %302, i32 6
  %317 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %315, float %316)
  %318 = insertelement <8 x i16> %314, i16 %317, i32 3
  %319 = extractelement <16 x float> %302, i32 9
  %320 = extractelement <16 x float> %302, i32 8
  %321 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %319, float %320)
  %322 = insertelement <8 x i16> %318, i16 %321, i32 4
  %323 = extractelement <16 x float> %302, i32 11
  %324 = extractelement <16 x float> %302, i32 10
  %325 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %323, float %324)
  %326 = insertelement <8 x i16> %322, i16 %325, i32 5
  %327 = extractelement <16 x float> %302, i32 13
  %328 = extractelement <16 x float> %302, i32 12
  %329 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %327, float %328)
  %330 = insertelement <8 x i16> %326, i16 %329, i32 6
  %331 = extractelement <16 x float> %302, i32 15
  %332 = extractelement <16 x float> %302, i32 14
  %333 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %331, float %332)
  %334 = insertelement <8 x i16> %330, i16 %333, i32 7
  %335 = bitcast <8 x i16> %334 to <16 x i8>
  br label %234

336:                                              ; preds = %239
  %337 = phi <16 x i8> [ %236, %239 ]
  %338 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %225, 0
  %339 = trunc i64 %221 to i32
  %340 = mul i32 %339, 512
  %341 = trunc i64 %222 to i32
  %342 = add i32 %340, %341
  %343 = sext i32 %342 to i64
  %344 = getelementptr inbounds i8, ptr %338, i64 %343
  store <16 x i8> %337, ptr %344, align 16
  br label %346

345:                                              ; preds = %201
  br label %346

346:                                              ; preds = %345, %336
  %347 = add i64 %52, %18
  %348 = mul i64 %347, 16
  %349 = trunc i64 %348 to i32
  %350 = load i64, ptr %19, align 8
  %351 = icmp slt i64 %347, %350
  br i1 %351, label %352, label %490

352:                                              ; preds = %346
  %353 = load { i64, i64 }, ptr %6, align 8
  %354 = extractvalue { i64, i64 } %353, 1
  %355 = trunc i64 %354 to i32
  %356 = icmp eq i32 %355, 0
  %357 = select i1 %356, i32 1, i32 %355
  %358 = icmp eq i32 %357, 0
  %359 = select i1 %358, i32 1, i32 %357
  %360 = udiv i32 %349, %359
  %361 = select i1 %358, i32 0, i32 %360
  %362 = urem i32 %349, %359
  %363 = select i1 %358, i32 0, i32 %362
  %364 = select i1 %356, i32 0, i32 %361
  %365 = select i1 %356, i32 0, i32 %363
  %366 = zext i32 %364 to i64
  %367 = zext i32 %365 to i64
  %368 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %369 = load i64, ptr %4, align 8
  %370 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %371 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %368, 0
  %372 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %368, 1, 1, 0
  %373 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %368, 1, 1, 1
  %374 = mul i64 %366, %373
  %375 = add i64 %374, %367
  %376 = getelementptr inbounds i8, ptr %371, i64 %375
  %377 = load <16 x i8>, ptr %376, align 16, !invariant.load !1
  %378 = call i64 @llvm.smax.i64(i64 %369, i64 1)
  br label %379

379:                                              ; preds = %385, %352
  %380 = phi i64 [ 1, %352 ], [ %388, %385 ]
  %381 = phi <16 x i8> [ %377, %352 ], [ %480, %385 ]
  %382 = icmp slt i64 %380, %378
  br i1 %382, label %383, label %384

383:                                              ; preds = %379
  br label %385

384:                                              ; preds = %379
  br label %481

385:                                              ; preds = %383
  %386 = icmp eq i64 %380, %378
  %387 = add i64 %380, 1
  %388 = select i1 %386, i64 %380, i64 %387
  %389 = mul i64 %380, %372
  %390 = add i64 %389, %374
  %391 = add i64 %390, %367
  %392 = getelementptr inbounds i8, ptr %371, i64 %391
  %393 = load <16 x i8>, ptr %392, align 16, !invariant.load !1
  %394 = bitcast <16 x i8> %381 to <8 x i16>
  %395 = extractelement <8 x i16> %394, i32 0
  %396 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %395)
  %397 = insertelement <8 x i32> undef, i32 %396, i32 0
  %398 = extractelement <8 x i16> %394, i32 1
  %399 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %398)
  %400 = insertelement <8 x i32> %397, i32 %399, i32 1
  %401 = extractelement <8 x i16> %394, i32 2
  %402 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %401)
  %403 = insertelement <8 x i32> %400, i32 %402, i32 2
  %404 = extractelement <8 x i16> %394, i32 3
  %405 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %404)
  %406 = insertelement <8 x i32> %403, i32 %405, i32 3
  %407 = extractelement <8 x i16> %394, i32 4
  %408 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %407)
  %409 = insertelement <8 x i32> %406, i32 %408, i32 4
  %410 = extractelement <8 x i16> %394, i32 5
  %411 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %410)
  %412 = insertelement <8 x i32> %409, i32 %411, i32 5
  %413 = extractelement <8 x i16> %394, i32 6
  %414 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %413)
  %415 = insertelement <8 x i32> %412, i32 %414, i32 6
  %416 = extractelement <8 x i16> %394, i32 7
  %417 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %416)
  %418 = insertelement <8 x i32> %415, i32 %417, i32 7
  %419 = bitcast <8 x i32> %418 to <16 x half>
  %420 = bitcast <16 x i8> %393 to <8 x i16>
  %421 = extractelement <8 x i16> %420, i32 0
  %422 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %421)
  %423 = insertelement <8 x i32> undef, i32 %422, i32 0
  %424 = extractelement <8 x i16> %420, i32 1
  %425 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %424)
  %426 = insertelement <8 x i32> %423, i32 %425, i32 1
  %427 = extractelement <8 x i16> %420, i32 2
  %428 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %427)
  %429 = insertelement <8 x i32> %426, i32 %428, i32 2
  %430 = extractelement <8 x i16> %420, i32 3
  %431 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %430)
  %432 = insertelement <8 x i32> %429, i32 %431, i32 3
  %433 = extractelement <8 x i16> %420, i32 4
  %434 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %433)
  %435 = insertelement <8 x i32> %432, i32 %434, i32 4
  %436 = extractelement <8 x i16> %420, i32 5
  %437 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %436)
  %438 = insertelement <8 x i32> %435, i32 %437, i32 5
  %439 = extractelement <8 x i16> %420, i32 6
  %440 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %439)
  %441 = insertelement <8 x i32> %438, i32 %440, i32 6
  %442 = extractelement <8 x i16> %420, i32 7
  %443 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %442)
  %444 = insertelement <8 x i32> %441, i32 %443, i32 7
  %445 = bitcast <8 x i32> %444 to <16 x half>
  %446 = fadd contract <16 x half> %419, %445
  %447 = fpext <16 x half> %446 to <16 x float>
  %448 = extractelement <16 x float> %447, i32 1
  %449 = extractelement <16 x float> %447, i32 0
  %450 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %448, float %449)
  %451 = insertelement <8 x i16> undef, i16 %450, i32 0
  %452 = extractelement <16 x float> %447, i32 3
  %453 = extractelement <16 x float> %447, i32 2
  %454 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %452, float %453)
  %455 = insertelement <8 x i16> %451, i16 %454, i32 1
  %456 = extractelement <16 x float> %447, i32 5
  %457 = extractelement <16 x float> %447, i32 4
  %458 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %456, float %457)
  %459 = insertelement <8 x i16> %455, i16 %458, i32 2
  %460 = extractelement <16 x float> %447, i32 7
  %461 = extractelement <16 x float> %447, i32 6
  %462 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %460, float %461)
  %463 = insertelement <8 x i16> %459, i16 %462, i32 3
  %464 = extractelement <16 x float> %447, i32 9
  %465 = extractelement <16 x float> %447, i32 8
  %466 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %464, float %465)
  %467 = insertelement <8 x i16> %463, i16 %466, i32 4
  %468 = extractelement <16 x float> %447, i32 11
  %469 = extractelement <16 x float> %447, i32 10
  %470 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %468, float %469)
  %471 = insertelement <8 x i16> %467, i16 %470, i32 5
  %472 = extractelement <16 x float> %447, i32 13
  %473 = extractelement <16 x float> %447, i32 12
  %474 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %472, float %473)
  %475 = insertelement <8 x i16> %471, i16 %474, i32 6
  %476 = extractelement <16 x float> %447, i32 15
  %477 = extractelement <16 x float> %447, i32 14
  %478 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %476, float %477)
  %479 = insertelement <8 x i16> %475, i16 %478, i32 7
  %480 = bitcast <8 x i16> %479 to <16 x i8>
  br label %379

481:                                              ; preds = %384
  %482 = phi <16 x i8> [ %381, %384 ]
  %483 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %370, 0
  %484 = trunc i64 %366 to i32
  %485 = mul i32 %484, 512
  %486 = trunc i64 %367 to i32
  %487 = add i32 %485, %486
  %488 = sext i32 %487 to i64
  %489 = getelementptr inbounds i8, ptr %483, i64 %488
  store <16 x i8> %482, ptr %489, align 16
  br label %491

490:                                              ; preds = %346
  br label %491

491:                                              ; preds = %490, %481
  %492 = add i64 %52, %17
  %493 = mul i64 %492, 16
  %494 = trunc i64 %493 to i32
  %495 = load i64, ptr %19, align 8
  %496 = icmp slt i64 %492, %495
  br i1 %496, label %497, label %635

497:                                              ; preds = %491
  %498 = load { i64, i64 }, ptr %6, align 8
  %499 = extractvalue { i64, i64 } %498, 1
  %500 = trunc i64 %499 to i32
  %501 = icmp eq i32 %500, 0
  %502 = select i1 %501, i32 1, i32 %500
  %503 = icmp eq i32 %502, 0
  %504 = select i1 %503, i32 1, i32 %502
  %505 = udiv i32 %494, %504
  %506 = select i1 %503, i32 0, i32 %505
  %507 = urem i32 %494, %504
  %508 = select i1 %503, i32 0, i32 %507
  %509 = select i1 %501, i32 0, i32 %506
  %510 = select i1 %501, i32 0, i32 %508
  %511 = zext i32 %509 to i64
  %512 = zext i32 %510 to i64
  %513 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %514 = load i64, ptr %4, align 8
  %515 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %516 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %513, 0
  %517 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %513, 1, 1, 0
  %518 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %513, 1, 1, 1
  %519 = mul i64 %511, %518
  %520 = add i64 %519, %512
  %521 = getelementptr inbounds i8, ptr %516, i64 %520
  %522 = load <16 x i8>, ptr %521, align 16, !invariant.load !1
  %523 = call i64 @llvm.smax.i64(i64 %514, i64 1)
  br label %524

524:                                              ; preds = %530, %497
  %525 = phi i64 [ 1, %497 ], [ %533, %530 ]
  %526 = phi <16 x i8> [ %522, %497 ], [ %625, %530 ]
  %527 = icmp slt i64 %525, %523
  br i1 %527, label %528, label %529

528:                                              ; preds = %524
  br label %530

529:                                              ; preds = %524
  br label %626

530:                                              ; preds = %528
  %531 = icmp eq i64 %525, %523
  %532 = add i64 %525, 1
  %533 = select i1 %531, i64 %525, i64 %532
  %534 = mul i64 %525, %517
  %535 = add i64 %534, %519
  %536 = add i64 %535, %512
  %537 = getelementptr inbounds i8, ptr %516, i64 %536
  %538 = load <16 x i8>, ptr %537, align 16, !invariant.load !1
  %539 = bitcast <16 x i8> %526 to <8 x i16>
  %540 = extractelement <8 x i16> %539, i32 0
  %541 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %540)
  %542 = insertelement <8 x i32> undef, i32 %541, i32 0
  %543 = extractelement <8 x i16> %539, i32 1
  %544 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %543)
  %545 = insertelement <8 x i32> %542, i32 %544, i32 1
  %546 = extractelement <8 x i16> %539, i32 2
  %547 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %546)
  %548 = insertelement <8 x i32> %545, i32 %547, i32 2
  %549 = extractelement <8 x i16> %539, i32 3
  %550 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %549)
  %551 = insertelement <8 x i32> %548, i32 %550, i32 3
  %552 = extractelement <8 x i16> %539, i32 4
  %553 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %552)
  %554 = insertelement <8 x i32> %551, i32 %553, i32 4
  %555 = extractelement <8 x i16> %539, i32 5
  %556 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %555)
  %557 = insertelement <8 x i32> %554, i32 %556, i32 5
  %558 = extractelement <8 x i16> %539, i32 6
  %559 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %558)
  %560 = insertelement <8 x i32> %557, i32 %559, i32 6
  %561 = extractelement <8 x i16> %539, i32 7
  %562 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %561)
  %563 = insertelement <8 x i32> %560, i32 %562, i32 7
  %564 = bitcast <8 x i32> %563 to <16 x half>
  %565 = bitcast <16 x i8> %538 to <8 x i16>
  %566 = extractelement <8 x i16> %565, i32 0
  %567 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %566)
  %568 = insertelement <8 x i32> undef, i32 %567, i32 0
  %569 = extractelement <8 x i16> %565, i32 1
  %570 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %569)
  %571 = insertelement <8 x i32> %568, i32 %570, i32 1
  %572 = extractelement <8 x i16> %565, i32 2
  %573 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %572)
  %574 = insertelement <8 x i32> %571, i32 %573, i32 2
  %575 = extractelement <8 x i16> %565, i32 3
  %576 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %575)
  %577 = insertelement <8 x i32> %574, i32 %576, i32 3
  %578 = extractelement <8 x i16> %565, i32 4
  %579 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %578)
  %580 = insertelement <8 x i32> %577, i32 %579, i32 4
  %581 = extractelement <8 x i16> %565, i32 5
  %582 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %581)
  %583 = insertelement <8 x i32> %580, i32 %582, i32 5
  %584 = extractelement <8 x i16> %565, i32 6
  %585 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %584)
  %586 = insertelement <8 x i32> %583, i32 %585, i32 6
  %587 = extractelement <8 x i16> %565, i32 7
  %588 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %587)
  %589 = insertelement <8 x i32> %586, i32 %588, i32 7
  %590 = bitcast <8 x i32> %589 to <16 x half>
  %591 = fadd contract <16 x half> %564, %590
  %592 = fpext <16 x half> %591 to <16 x float>
  %593 = extractelement <16 x float> %592, i32 1
  %594 = extractelement <16 x float> %592, i32 0
  %595 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %593, float %594)
  %596 = insertelement <8 x i16> undef, i16 %595, i32 0
  %597 = extractelement <16 x float> %592, i32 3
  %598 = extractelement <16 x float> %592, i32 2
  %599 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %597, float %598)
  %600 = insertelement <8 x i16> %596, i16 %599, i32 1
  %601 = extractelement <16 x float> %592, i32 5
  %602 = extractelement <16 x float> %592, i32 4
  %603 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %601, float %602)
  %604 = insertelement <8 x i16> %600, i16 %603, i32 2
  %605 = extractelement <16 x float> %592, i32 7
  %606 = extractelement <16 x float> %592, i32 6
  %607 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %605, float %606)
  %608 = insertelement <8 x i16> %604, i16 %607, i32 3
  %609 = extractelement <16 x float> %592, i32 9
  %610 = extractelement <16 x float> %592, i32 8
  %611 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %609, float %610)
  %612 = insertelement <8 x i16> %608, i16 %611, i32 4
  %613 = extractelement <16 x float> %592, i32 11
  %614 = extractelement <16 x float> %592, i32 10
  %615 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %613, float %614)
  %616 = insertelement <8 x i16> %612, i16 %615, i32 5
  %617 = extractelement <16 x float> %592, i32 13
  %618 = extractelement <16 x float> %592, i32 12
  %619 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %617, float %618)
  %620 = insertelement <8 x i16> %616, i16 %619, i32 6
  %621 = extractelement <16 x float> %592, i32 15
  %622 = extractelement <16 x float> %592, i32 14
  %623 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float %621, float %622)
  %624 = insertelement <8 x i16> %620, i16 %623, i32 7
  %625 = bitcast <8 x i16> %624 to <16 x i8>
  br label %524

626:                                              ; preds = %529
  %627 = phi <16 x i8> [ %526, %529 ]
  %628 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %515, 0
  %629 = trunc i64 %511 to i32
  %630 = mul i32 %629, 512
  %631 = trunc i64 %512 to i32
  %632 = add i32 %630, %631
  %633 = sext i32 %632 to i64
  %634 = getelementptr inbounds i8, ptr %628, i64 %633
  store <16 x i8> %627, ptr %634, align 16
  br label %636

635:                                              ; preds = %491
  br label %636

636:                                              ; preds = %635, %626
  br label %28

637:                                              ; preds = %57
  %638 = getelementptr { { { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, i64, {}, {}, { ptr, { { {}, {} }, { {}, {} } } } }, { i64, i64 }, i64, i64, i64 }, ptr %0, i32 0, i32 3
  %639 = load i64, ptr %638, align 8
  %640 = icmp slt i64 %13, %639
  br i1 %640, label %641, label %733

641:                                              ; preds = %637
  %642 = load i64, ptr %7, align 8
  %643 = add i64 %642, %13
  %644 = load { i64, i64 }, ptr %6, align 8
  %645 = trunc i64 %643 to i32
  %646 = extractvalue { i64, i64 } %644, 1
  %647 = trunc i64 %646 to i32
  %648 = icmp eq i32 %647, 0
  %649 = select i1 %648, i32 1, i32 %647
  %650 = icmp eq i32 %649, 0
  %651 = select i1 %650, i32 1, i32 %649
  %652 = udiv i32 %645, %651
  %653 = select i1 %650, i32 0, i32 %652
  %654 = urem i32 %645, %651
  %655 = select i1 %650, i32 0, i32 %654
  %656 = select i1 %648, i32 0, i32 %653
  %657 = select i1 %648, i32 0, i32 %655
  %658 = zext i32 %656 to i64
  %659 = zext i32 %657 to i64
  %660 = load { ptr, { { i64, i64, i64 }, { i64, i64, {} } } }, ptr %5, align 8
  %661 = load i64, ptr %4, align 8
  %662 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %3, align 8
  %663 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %660, 0
  %664 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %660, 1, 1, 0
  %665 = extractvalue { ptr, { { i64, i64, i64 }, { i64, i64, {} } } } %660, 1, 1, 1
  %666 = mul i64 %658, %665
  %667 = add i64 %666, %659
  %668 = getelementptr inbounds i8, ptr %663, i64 %667
  br label %669

669:                                              ; preds = %675, %641
  %670 = phi i64 [ 0, %641 ], [ %678, %675 ]
  %671 = phi i8 [ 0, %641 ], [ %680, %675 ]
  %672 = icmp slt i64 %670, 1
  br i1 %672, label %673, label %674

673:                                              ; preds = %669
  br label %675

674:                                              ; preds = %669
  br label %681

675:                                              ; preds = %673
  %676 = icmp eq i64 %670, 1
  %677 = add i64 %670, 1
  %678 = select i1 %676, i64 %670, i64 %677
  %679 = getelementptr inbounds i8, ptr %668, i64 %670
  %680 = load i8, ptr %679, align 1, !invariant.load !1
  br label %669

681:                                              ; preds = %674
  %682 = phi i8 [ %671, %674 ]
  %683 = call i64 @llvm.smax.i64(i64 %661, i64 1)
  br label %684

684:                                              ; preds = %710, %681
  %685 = phi i64 [ 1, %681 ], [ %693, %710 ]
  %686 = phi i8 [ %682, %681 ], [ %723, %710 ]
  %687 = icmp slt i64 %685, %683
  br i1 %687, label %688, label %689

688:                                              ; preds = %684
  br label %690

689:                                              ; preds = %684
  br label %724

690:                                              ; preds = %688
  %691 = icmp eq i64 %685, %683
  %692 = add i64 %685, 1
  %693 = select i1 %691, i64 %685, i64 %692
  %694 = mul i64 %685, %664
  %695 = add i64 %694, %666
  %696 = add i64 %695, %659
  %697 = getelementptr inbounds i8, ptr %663, i64 %696
  br label %698

698:                                              ; preds = %704, %690
  %699 = phi i64 [ 0, %690 ], [ %707, %704 ]
  %700 = phi i8 [ 0, %690 ], [ %709, %704 ]
  %701 = icmp slt i64 %699, 1
  br i1 %701, label %702, label %703

702:                                              ; preds = %698
  br label %704

703:                                              ; preds = %698
  br label %710

704:                                              ; preds = %702
  %705 = icmp eq i64 %699, 1
  %706 = add i64 %699, 1
  %707 = select i1 %705, i64 %699, i64 %706
  %708 = getelementptr inbounds i8, ptr %697, i64 %699
  %709 = load i8, ptr %708, align 1, !invariant.load !1
  br label %698

710:                                              ; preds = %703
  %711 = phi i8 [ %700, %703 ]
  %712 = zext i8 %686 to i16
  %713 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %712)
  %714 = trunc i32 %713 to i16
  %715 = bitcast i16 %714 to half
  %716 = zext i8 %711 to i16
  %717 = call i32 asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"(i16 %716)
  %718 = trunc i32 %717 to i16
  %719 = bitcast i16 %718 to half
  %720 = fadd contract half %715, %719
  %721 = fpext half %720 to float
  %722 = call i16 asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"(float 0.000000e+00, float %721)
  %723 = trunc i16 %722 to i8
  br label %684

724:                                              ; preds = %689
  %725 = phi i8 [ %686, %689 ]
  %726 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %662, 0
  %727 = trunc i64 %658 to i32
  %728 = mul i32 %727, 512
  %729 = trunc i64 %659 to i32
  %730 = add i32 %728, %729
  %731 = sext i32 %730 to i64
  %732 = getelementptr inbounds i8, ptr %726, i64 %731
  store i8 %725, ptr %732, align 1
  br label %734

733:                                              ; preds = %637
  br label %734

734:                                              ; preds = %733, %724
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
