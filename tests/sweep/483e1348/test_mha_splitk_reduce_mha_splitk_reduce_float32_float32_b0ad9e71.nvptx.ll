; ModuleID = 'test_mha_splitk_reduce.mojo'
source_filename = "test_mha_splitk_reduce.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

@mha_splitk_reduce_float32_float32_b0ad9e71.exp_sums_storage_0._gpu_shared_mem = internal addrspace(3) global [1 x { [32 x float] }] undef, align 4

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @mha_splitk_reduce_float32_float32_b0ad9e71(ptr noundef %0, ptr noundef %1, ptr noundef %2, ptr noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = sext i32 %4 to i64
  %8 = sext i32 %5 to i64
  %9 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %10 = zext i32 %9 to i64
  %11 = mul i64 %10, 96
  %12 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %13 = zext i32 %12 to i64
  %14 = mul i64 %13, 32
  %15 = add i64 %11, %14
  %16 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %17 = zext i32 %16 to i64
  %18 = add i64 %15, %17
  %19 = getelementptr inbounds float, ptr %1, i64 %18
  %20 = trunc i64 %17 to i32
  %21 = sext i32 %20 to i64
  %22 = mul i64 %10, 3
  %23 = mul i64 %7, 3
  %24 = mul i64 %23, %17
  %25 = add i64 %22, %24
  %26 = add i64 %25, %13
  %27 = getelementptr inbounds float, ptr %2, i64 %26
  %28 = getelementptr inbounds float, ptr %3, i64 %26
  %29 = icmp slt i64 %17, %8
  br i1 %29, label %30, label %32

30:                                               ; preds = %6
  %31 = load float, ptr %28, align 4
  br label %33

32:                                               ; preds = %6
  br label %33

33:                                               ; preds = %32, %30
  %34 = phi float [ -inf, %32 ], [ %31, %30 ]
  %35 = bitcast float %34 to i32
  %36 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %35, i32 16, i32 31)
  %37 = bitcast i32 %36 to float
  %38 = call float @llvm.maxnum.f32(float %34, float %37)
  %39 = bitcast float %38 to i32
  %40 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %39, i32 8, i32 31)
  %41 = bitcast i32 %40 to float
  %42 = call float @llvm.maxnum.f32(float %38, float %41)
  %43 = bitcast float %42 to i32
  %44 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %43, i32 4, i32 31)
  %45 = bitcast i32 %44 to float
  %46 = call float @llvm.maxnum.f32(float %42, float %45)
  %47 = bitcast float %46 to i32
  %48 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %47, i32 2, i32 31)
  %49 = bitcast i32 %48 to float
  %50 = call float @llvm.maxnum.f32(float %46, float %49)
  %51 = bitcast float %50 to i32
  %52 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %51, i32 1, i32 31)
  %53 = bitcast i32 %52 to float
  %54 = call float @llvm.maxnum.f32(float %50, float %53)
  %55 = fsub contract float %34, %54
  %56 = trunc i64 %21 to i32
  %57 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_float32_float32_b0ad9e71.exp_sums_storage_0._gpu_shared_mem, i32 %56
  %58 = mul i64 %7, 96
  br i1 %29, label %59, label %63

59:                                               ; preds = %33
  %60 = call float asm "ex2.approx.ftz.f32 $0, $1;", "=f,f"(float %55)
  %61 = load float, ptr %27, align 4
  %62 = fmul contract float %61, %60
  store float %62, ptr addrspace(3) %57, align 4
  br label %64

63:                                               ; preds = %33
  br label %64

64:                                               ; preds = %63, %59
  %65 = phi float [ 0.000000e+00, %63 ], [ %62, %59 ]
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %66 = bitcast float %65 to i32
  %67 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %66, i32 16, i32 31)
  %68 = bitcast i32 %67 to float
  %69 = fadd contract float %65, %68
  %70 = bitcast float %69 to i32
  %71 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %70, i32 8, i32 31)
  %72 = bitcast i32 %71 to float
  %73 = fadd contract float %69, %72
  %74 = bitcast float %73 to i32
  %75 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %74, i32 4, i32 31)
  %76 = bitcast i32 %75 to float
  %77 = fadd contract float %73, %76
  %78 = bitcast float %77 to i32
  %79 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %78, i32 2, i32 31)
  %80 = bitcast i32 %79 to float
  %81 = fadd contract float %77, %80
  %82 = bitcast float %81 to i32
  %83 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %82, i32 1, i32 31)
  %84 = bitcast i32 %83 to float
  %85 = fadd contract float %81, %84
  %86 = fdiv float 1.000000e+00, %85
  %87 = icmp slt i64 %17, 32
  br i1 %87, label %88, label %276

88:                                               ; preds = %64
  %89 = udiv i64 %8, 8
  %90 = mul i64 %89, 8
  br label %91

91:                                               ; preds = %107, %88
  %92 = phi i64 [ 0, %88 ], [ %103, %107 ]
  %93 = phi i64 [ 0, %88 ], [ %104, %107 ]
  %94 = phi float [ 0.000000e+00, %88 ], [ %237, %107 ]
  %95 = phi float [ 0.000000e+00, %88 ], [ %239, %107 ]
  %96 = add i64 %92, 8
  %97 = icmp slt i64 %96, %92
  %98 = select i1 %97, i64 1, i64 0
  %99 = icmp sge i64 %92, %90
  %100 = icmp eq i64 %93, 0
  %101 = xor i1 %100, true
  %102 = or i1 %101, %99
  %103 = select i1 %102, i64 %92, i64 %96
  %104 = select i1 %102, i64 %93, i64 %98
  br i1 %102, label %105, label %107

105:                                              ; preds = %91
  %106 = call i64 @llvm.smax.i64(i64 %90, i64 %8)
  br label %240

107:                                              ; preds = %91
  %108 = sdiv i64 %92, 8
  %109 = mul i64 %108, 8
  %110 = icmp eq i64 %109, %92
  %111 = xor i64 %92, 8
  %112 = ashr i64 %111, 63
  %113 = select i1 %110, i64 0, i64 %112
  %114 = add i64 %108, %113
  %115 = trunc i64 %114 to i32
  %116 = mul i32 %115, 8
  %117 = sext i32 %116 to i64
  %118 = trunc i64 %117 to i32
  %119 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_float32_float32_b0ad9e71.exp_sums_storage_0._gpu_shared_mem, i32 %118
  %120 = load <8 x float>, ptr addrspace(3) %119, align 32
  %121 = mul i64 %92, %58
  %122 = add i64 %121, %11
  %123 = add i64 %122, %14
  %124 = add i64 %123, %17
  %125 = getelementptr inbounds float, ptr %0, i64 %124
  %126 = load float, ptr %125, align 4, !invariant.load !1
  %127 = extractelement <8 x float> %120, i64 0
  %128 = fcmp ogt float %127, 0.000000e+00
  %129 = select i1 %128, float %126, float 0.000000e+00
  %130 = fmul contract float %129, %127
  %131 = fsub contract float %130, %95
  %132 = fadd contract float %94, %131
  %133 = fsub contract float %132, %94
  %134 = fsub contract float %133, %131
  %135 = add i64 %92, 1
  %136 = mul i64 %135, %58
  %137 = add i64 %136, %11
  %138 = add i64 %137, %14
  %139 = add i64 %138, %17
  %140 = getelementptr inbounds float, ptr %0, i64 %139
  %141 = load float, ptr %140, align 4, !invariant.load !1
  %142 = extractelement <8 x float> %120, i64 1
  %143 = fcmp ogt float %142, 0.000000e+00
  %144 = select i1 %143, float %141, float 0.000000e+00
  %145 = fmul contract float %144, %142
  %146 = fsub contract float %145, %134
  %147 = fadd contract float %132, %146
  %148 = fsub contract float %147, %132
  %149 = fsub contract float %148, %146
  %150 = add i64 %92, 2
  %151 = mul i64 %150, %58
  %152 = add i64 %151, %11
  %153 = add i64 %152, %14
  %154 = add i64 %153, %17
  %155 = getelementptr inbounds float, ptr %0, i64 %154
  %156 = load float, ptr %155, align 4, !invariant.load !1
  %157 = extractelement <8 x float> %120, i64 2
  %158 = fcmp ogt float %157, 0.000000e+00
  %159 = select i1 %158, float %156, float 0.000000e+00
  %160 = fmul contract float %159, %157
  %161 = fsub contract float %160, %149
  %162 = fadd contract float %147, %161
  %163 = fsub contract float %162, %147
  %164 = fsub contract float %163, %161
  %165 = add i64 %92, 3
  %166 = mul i64 %165, %58
  %167 = add i64 %166, %11
  %168 = add i64 %167, %14
  %169 = add i64 %168, %17
  %170 = getelementptr inbounds float, ptr %0, i64 %169
  %171 = load float, ptr %170, align 4, !invariant.load !1
  %172 = extractelement <8 x float> %120, i64 3
  %173 = fcmp ogt float %172, 0.000000e+00
  %174 = select i1 %173, float %171, float 0.000000e+00
  %175 = fmul contract float %174, %172
  %176 = fsub contract float %175, %164
  %177 = fadd contract float %162, %176
  %178 = fsub contract float %177, %162
  %179 = fsub contract float %178, %176
  %180 = add i64 %92, 4
  %181 = mul i64 %180, %58
  %182 = add i64 %181, %11
  %183 = add i64 %182, %14
  %184 = add i64 %183, %17
  %185 = getelementptr inbounds float, ptr %0, i64 %184
  %186 = load float, ptr %185, align 4, !invariant.load !1
  %187 = extractelement <8 x float> %120, i64 4
  %188 = fcmp ogt float %187, 0.000000e+00
  %189 = select i1 %188, float %186, float 0.000000e+00
  %190 = fmul contract float %189, %187
  %191 = fsub contract float %190, %179
  %192 = fadd contract float %177, %191
  %193 = fsub contract float %192, %177
  %194 = fsub contract float %193, %191
  %195 = add i64 %92, 5
  %196 = mul i64 %195, %58
  %197 = add i64 %196, %11
  %198 = add i64 %197, %14
  %199 = add i64 %198, %17
  %200 = getelementptr inbounds float, ptr %0, i64 %199
  %201 = load float, ptr %200, align 4, !invariant.load !1
  %202 = extractelement <8 x float> %120, i64 5
  %203 = fcmp ogt float %202, 0.000000e+00
  %204 = select i1 %203, float %201, float 0.000000e+00
  %205 = fmul contract float %204, %202
  %206 = fsub contract float %205, %194
  %207 = fadd contract float %192, %206
  %208 = fsub contract float %207, %192
  %209 = fsub contract float %208, %206
  %210 = add i64 %92, 6
  %211 = mul i64 %210, %58
  %212 = add i64 %211, %11
  %213 = add i64 %212, %14
  %214 = add i64 %213, %17
  %215 = getelementptr inbounds float, ptr %0, i64 %214
  %216 = load float, ptr %215, align 4, !invariant.load !1
  %217 = extractelement <8 x float> %120, i64 6
  %218 = fcmp ogt float %217, 0.000000e+00
  %219 = select i1 %218, float %216, float 0.000000e+00
  %220 = fmul contract float %219, %217
  %221 = fsub contract float %220, %209
  %222 = fadd contract float %207, %221
  %223 = fsub contract float %222, %207
  %224 = fsub contract float %223, %221
  %225 = add i64 %92, 7
  %226 = mul i64 %225, %58
  %227 = add i64 %226, %11
  %228 = add i64 %227, %14
  %229 = add i64 %228, %17
  %230 = getelementptr inbounds float, ptr %0, i64 %229
  %231 = load float, ptr %230, align 4, !invariant.load !1
  %232 = extractelement <8 x float> %120, i64 7
  %233 = fcmp ogt float %232, 0.000000e+00
  %234 = select i1 %233, float %231, float 0.000000e+00
  %235 = fmul contract float %234, %232
  %236 = fsub contract float %235, %224
  %237 = fadd contract float %222, %236
  %238 = fsub contract float %237, %222
  %239 = fsub contract float %238, %236
  br label %91

240:                                              ; preds = %245, %105
  %241 = phi i64 [ %90, %105 ], [ %248, %245 ]
  %242 = phi float [ %94, %105 ], [ %271, %245 ]
  %243 = phi float [ %95, %105 ], [ %273, %245 ]
  %244 = icmp slt i64 %241, %106
  br i1 %244, label %245, label %274

245:                                              ; preds = %240
  %246 = icmp eq i64 %241, %106
  %247 = add i64 %241, 1
  %248 = select i1 %246, i64 %241, i64 %247
  %249 = sdiv i64 %241, 1
  %250 = mul i64 %249, 1
  %251 = icmp eq i64 %250, %241
  %252 = xor i64 %241, 1
  %253 = ashr i64 %252, 63
  %254 = select i1 %251, i64 0, i64 %253
  %255 = add i64 %249, %254
  %256 = trunc i64 %255 to i32
  %257 = sext i32 %256 to i64
  %258 = trunc i64 %257 to i32
  %259 = getelementptr inbounds float, ptr addrspace(3) @mha_splitk_reduce_float32_float32_b0ad9e71.exp_sums_storage_0._gpu_shared_mem, i32 %258
  %260 = load float, ptr addrspace(3) %259, align 4
  %261 = mul i64 %241, %58
  %262 = add i64 %261, %11
  %263 = add i64 %262, %14
  %264 = add i64 %263, %17
  %265 = getelementptr inbounds float, ptr %0, i64 %264
  %266 = load float, ptr %265, align 4, !invariant.load !1
  %267 = fcmp ogt float %260, 0.000000e+00
  %268 = select i1 %267, float %266, float 0.000000e+00
  %269 = fmul contract float %268, %260
  %270 = fsub contract float %269, %243
  %271 = fadd contract float %242, %270
  %272 = fsub contract float %271, %242
  %273 = fsub contract float %272, %270
  br label %240

274:                                              ; preds = %240
  %275 = fmul contract float %242, %86
  store float %275, ptr %19, align 4
  br label %277

276:                                              ; preds = %64
  br label %277

277:                                              ; preds = %276, %274
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.z() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

; Function Attrs: convergent nocallback nounwind memory(inaccessiblemem: readwrite)
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #2

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #3

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #4

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #3

attributes #0 = { convergent norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nounwind memory(inaccessiblemem: readwrite) }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { convergent nocallback nounwind }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{}
