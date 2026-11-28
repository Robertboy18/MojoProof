; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @conv3d_gpu_naive_ndhwc_qrscf_float32_float32_float32_5f5d7b54(ptr noundef nonnull readonly byval({ ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } }) %2, { i64, i64, i64 } noundef %3, { i64, i64, i64 } noundef %4, { i64, i64, i64 } noundef %5, i32 noundef %6) #0 {
  %8 = load { ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } }, ptr %2, align 8
  %9 = load { ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } }, ptr %1, align 8
  %10 = load { ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } }, ptr %0, align 8
  %11 = extractvalue { ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } } %10, 0
  %12 = extractvalue { ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } } %9, 0
  %13 = extractvalue { ptr, { { {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {} } } } %8, 0
  %14 = sext i32 %6 to i64
  %15 = icmp eq i64 %14, 0
  %16 = select i1 %15, i64 1, i64 %14
  %17 = sdiv i64 32, %16
  %18 = mul i64 %17, %16
  %19 = icmp eq i64 %18, 32
  %20 = xor i64 32, %16
  %21 = ashr i64 %20, 63
  %22 = select i1 %19, i64 0, i64 %21
  %23 = add i64 %17, %22
  %24 = select i1 %15, i64 0, i64 %23
  %25 = icmp eq i64 %24, 0
  %26 = select i1 %25, i64 1, i64 %24
  %27 = extractvalue { i64, i64, i64 } %5, 0
  %28 = extractvalue { i64, i64, i64 } %5, 1
  %29 = extractvalue { i64, i64, i64 } %5, 2
  %30 = extractvalue { i64, i64, i64 } %3, 0
  %31 = extractvalue { i64, i64, i64 } %3, 1
  %32 = extractvalue { i64, i64, i64 } %3, 2
  %33 = extractvalue { i64, i64, i64 } %4, 0
  %34 = extractvalue { i64, i64, i64 } %4, 1
  %35 = extractvalue { i64, i64, i64 } %4, 2
  %36 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %37 = zext i32 %36 to i64
  %38 = trunc i64 %37 to i32
  %39 = mul i32 %38, 1536
  %40 = mul i32 %38, 360
  %41 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %42 = zext i32 %41 to i64
  %43 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %44 = sext i32 %43 to i64
  %45 = mul i64 %42, %44
  %46 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %47 = zext i32 %46 to i64
  %48 = add i64 %45, %47
  %49 = udiv i64 %48, 2
  %50 = urem i64 %48, 2
  %51 = trunc i64 %49 to i32
  %52 = mul i32 %51, 64
  %53 = mul i64 %49, %31
  %54 = trunc i64 %50 to i32
  %55 = mul i32 %54, 32
  %56 = mul i64 %50, %32
  %57 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %58 = zext i32 %57 to i64
  %59 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %60 = sext i32 %59 to i64
  %61 = mul i64 %58, %60
  %62 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %63 = zext i32 %62 to i64
  %64 = add i64 %61, %63
  %65 = trunc i64 %64 to i32
  %66 = mul i32 %65, 192
  %67 = add i32 %39, %66
  %68 = add i32 %67, %52
  %69 = add i32 %68, %55
  %70 = mul i64 %64, %30
  %71 = icmp sge i64 %37, 1
  %72 = icmp sge i64 %64, 8
  %73 = select i1 %71, i1 true, i1 %72
  %74 = icmp sge i64 %49, 3
  %75 = select i1 %73, i1 true, i1 %74
  %76 = icmp sge i64 %50, 2
  %77 = select i1 %75, i1 true, i1 %76
  br i1 %77, label %78, label %79

78:                                               ; preds = %7
  br label %250

79:                                               ; preds = %7
  br label %80

80:                                               ; preds = %117, %79
  %81 = phi i64 [ 0, %79 ], [ %87, %117 ]
  %82 = icmp slt i64 %81, 32
  br i1 %82, label %83, label %96

83:                                               ; preds = %80
  %84 = trunc i64 %81 to i32
  %85 = icmp eq i64 %81, 32
  %86 = add i64 %81, 1
  %87 = select i1 %85, i64 %81, i64 %86
  %88 = sdiv i64 %81, %26
  %89 = mul i64 %88, %26
  %90 = icmp eq i64 %89, %81
  %91 = xor i64 %81, %26
  %92 = ashr i64 %91, 63
  %93 = select i1 %90, i64 0, i64 %92
  %94 = add i64 %88, %93
  %95 = select i1 %25, i64 0, i64 %94
  br label %97

96:                                               ; preds = %80
  br label %250

97:                                               ; preds = %150, %83
  %98 = phi i64 [ 0, %83 ], [ %116, %150 ]
  %99 = phi <4 x float> [ zeroinitializer, %83 ], [ %130, %150 ]
  %100 = phi float [ 0.000000e+00, %83 ], [ %131, %150 ]
  %101 = icmp slt i64 %98, 2
  br i1 %101, label %102, label %117

102:                                              ; preds = %97
  %103 = trunc i64 %98 to i32
  %104 = mul i32 %103, 192
  %105 = mul i64 %98, %33
  %106 = add i64 %70, %105
  %107 = sub i64 %106, %27
  %108 = trunc i64 %107 to i32
  %109 = mul i32 %108, 40
  %110 = add i32 %40, %109
  %111 = icmp slt i64 %107, 9
  %112 = icmp sle i64 0, %107
  %113 = select i1 %112, i1 %111, i1 false
  %114 = icmp eq i64 %98, 2
  %115 = add i64 %98, 1
  %116 = select i1 %114, i64 %98, i64 %115
  br label %128

117:                                              ; preds = %97
  %118 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %99, i64 0)
  %119 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %99, i64 2)
  %120 = fadd contract <2 x float> %118, %119
  %121 = extractelement <2 x float> %120, i64 0
  %122 = extractelement <2 x float> %120, i64 1
  %123 = fadd contract float %121, %122
  %124 = fadd contract float %123, %100
  %125 = add i32 %69, %84
  %126 = sext i32 %125 to i64
  %127 = getelementptr inbounds float, ptr %13, i64 %126
  store float %124, ptr %127, align 4
  br label %80

128:                                              ; preds = %172, %102
  %129 = phi i64 [ 0, %102 ], [ %149, %172 ]
  %130 = phi <4 x float> [ %99, %102 ], [ %153, %172 ]
  %131 = phi float [ %100, %102 ], [ %154, %172 ]
  %132 = icmp slt i64 %129, 2
  br i1 %132, label %133, label %150

133:                                              ; preds = %128
  %134 = trunc i64 %129 to i32
  %135 = mul i32 %134, 96
  %136 = add i32 %104, %135
  %137 = mul i64 %129, %34
  %138 = add i64 %53, %137
  %139 = sub i64 %138, %28
  %140 = trunc i64 %139 to i32
  %141 = mul i32 %140, 5
  %142 = add i32 %110, %141
  %143 = icmp slt i64 %139, 8
  %144 = icmp sle i64 0, %139
  %145 = select i1 %144, i1 %143, i1 false
  %146 = select i1 %113, i1 %145, i1 false
  %147 = icmp eq i64 %129, 2
  %148 = add i64 %129, 1
  %149 = select i1 %147, i64 %129, i64 %148
  br label %151

150:                                              ; preds = %128
  br label %97

151:                                              ; preds = %247, %133
  %152 = phi i64 [ 0, %133 ], [ %162, %247 ]
  %153 = phi <4 x float> [ %130, %133 ], [ %248, %247 ]
  %154 = phi float [ %131, %133 ], [ %249, %247 ]
  %155 = icmp slt i64 %152, 3
  br i1 %155, label %156, label %172

156:                                              ; preds = %151
  %157 = trunc i64 %152 to i32
  %158 = mul i32 %157, 32
  %159 = add i32 %136, %158
  %160 = icmp eq i64 %152, 3
  %161 = add i64 %152, 1
  %162 = select i1 %160, i64 %152, i64 %161
  %163 = mul i64 %152, %35
  %164 = add i64 %56, %163
  %165 = sub i64 %164, %29
  %166 = trunc i64 %165 to i32
  %167 = add i32 %142, %166
  %168 = icmp slt i64 %165, 5
  %169 = icmp sle i64 0, %165
  %170 = select i1 %169, i1 %168, i1 false
  %171 = select i1 %146, i1 %170, i1 false
  br i1 %171, label %173, label %246

172:                                              ; preds = %151
  br label %128

173:                                              ; preds = %156
  br label %174

174:                                              ; preds = %179, %173
  %175 = phi <4 x float> [ %153, %173 ], [ %222, %179 ]
  %176 = phi i64 [ 0, %173 ], [ %177, %179 ]
  %177 = add i64 %176, 4
  %178 = icmp sle i64 %177, 1
  br i1 %178, label %179, label %223

179:                                              ; preds = %174
  %180 = add i64 %95, %176
  %181 = trunc i64 %180 to i32
  %182 = add i32 %167, %181
  %183 = sext i32 %182 to i64
  %184 = getelementptr inbounds float, ptr %11, i64 %183
  %185 = load <4 x float>, ptr %184, align 4
  %186 = trunc i64 %176 to i32
  %187 = mul i32 %186, 32
  %188 = add i32 %159, %187
  %189 = add i32 %188, %84
  %190 = sext i32 %189 to i64
  %191 = getelementptr inbounds float, ptr %12, i64 %190
  %192 = load float, ptr %191, align 4
  %193 = insertelement <4 x float> zeroinitializer, float %192, i64 0
  %194 = add i64 %176, 1
  %195 = trunc i64 %194 to i32
  %196 = mul i32 %195, 32
  %197 = add i32 %159, %196
  %198 = add i32 %197, %84
  %199 = sext i32 %198 to i64
  %200 = getelementptr inbounds float, ptr %12, i64 %199
  %201 = load float, ptr %200, align 4
  %202 = insertelement <4 x float> %193, float %201, i64 1
  %203 = add i64 %176, 2
  %204 = trunc i64 %203 to i32
  %205 = mul i32 %204, 32
  %206 = add i32 %159, %205
  %207 = add i32 %206, %84
  %208 = sext i32 %207 to i64
  %209 = getelementptr inbounds float, ptr %12, i64 %208
  %210 = load float, ptr %209, align 4
  %211 = insertelement <4 x float> %202, float %210, i64 2
  %212 = add i64 %176, 3
  %213 = trunc i64 %212 to i32
  %214 = mul i32 %213, 32
  %215 = add i32 %159, %214
  %216 = add i32 %215, %84
  %217 = sext i32 %216 to i64
  %218 = getelementptr inbounds float, ptr %12, i64 %217
  %219 = load float, ptr %218, align 4
  %220 = insertelement <4 x float> %211, float %219, i64 3
  %221 = fmul contract <4 x float> %185, %220
  %222 = fadd contract <4 x float> %175, %221
  br label %174

223:                                              ; preds = %174
  br label %224

224:                                              ; preds = %228, %223
  %225 = phi i64 [ %176, %223 ], [ %244, %228 ]
  %226 = phi float [ %154, %223 ], [ %243, %228 ]
  %227 = icmp slt i64 %225, 1
  br i1 %227, label %228, label %245

228:                                              ; preds = %224
  %229 = add i64 %95, %225
  %230 = trunc i64 %229 to i32
  %231 = add i32 %167, %230
  %232 = sext i32 %231 to i64
  %233 = getelementptr inbounds float, ptr %11, i64 %232
  %234 = load float, ptr %233, align 4
  %235 = trunc i64 %225 to i32
  %236 = mul i32 %235, 32
  %237 = add i32 %159, %236
  %238 = add i32 %237, %84
  %239 = sext i32 %238 to i64
  %240 = getelementptr inbounds float, ptr %12, i64 %239
  %241 = load float, ptr %240, align 4
  %242 = fmul contract float %234, %241
  %243 = fadd contract float %226, %242
  %244 = add i64 %225, 1
  br label %224

245:                                              ; preds = %224
  br label %247

246:                                              ; preds = %156
  br label %247

247:                                              ; preds = %246, %245
  %248 = phi <4 x float> [ %153, %246 ], [ %175, %245 ]
  %249 = phi float [ %154, %246 ], [ %226, %245 ]
  br label %151

250:                                              ; preds = %96, %78
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.z() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float>, i64 immarg) #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
