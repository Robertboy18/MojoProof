; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_compute_fn_float32_float32_float32_True_4_a857d73e(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
  %7 = alloca [2 x ptr], i64 1, align 8
  %8 = alloca i64, i64 1, align 8
  %9 = alloca [2 x ptr], i64 1, align 8
  %10 = alloca i64, i64 1, align 8
  %11 = alloca [2 x ptr], i64 1, align 8
  %12 = alloca i64, i64 1, align 8
  %13 = alloca [2 x ptr], i64 1, align 8
  %14 = alloca i64, i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca [2 x ptr], i64 1, align 8
  %17 = alloca i32, i64 1, align 4
  %18 = alloca i32, i64 1, align 4
  %19 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %20 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %21 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %22 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %21, 0
  %23 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %20, 0
  %24 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %19, 0
  %25 = sext i32 %3 to i64
  %26 = sext i32 %5 to i64
  %27 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %28 = zext i32 %27 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %32 = sext i32 %31 to i64
  %33 = mul i64 %30, %32
  %34 = add i64 %33, %28
  %35 = udiv i64 %34, 32
  %36 = bitcast i64 %35 to <2 x i32>
  %37 = extractelement <2 x i32> %36, i64 0
  %38 = extractelement <2 x i32> %36, i64 1
  %39 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %37, i32 0, i32 31)
  %40 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %38, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %39, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i32 %40, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %41 = insertvalue [2 x ptr] undef, ptr %18, 0
  %42 = insertvalue [2 x ptr] %41, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %42, ptr %16, align 8
  %43 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %44 = load ptr, ptr %43, align 8
  %45 = load i32, ptr %44, align 4
  %46 = insertelement <2 x i32> undef, i32 %45, i64 0
  %47 = getelementptr inbounds ptr, ptr %43, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = load i32, ptr %48, align 4
  %50 = insertelement <2 x i32> %46, i32 %49, i64 1
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  %51 = bitcast <2 x i32> %50 to i64
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %51, ptr %15, align 8
  %52 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %53 = sext i32 %52 to i64
  %54 = trunc i64 %53 to i32
  %55 = mul i32 %54, 4
  %56 = sext i32 %55 to i64
  %57 = icmp eq i64 %53, 0
  %58 = load i64, ptr %15, align 8
  %59 = icmp sge i64 %58, %25
  br i1 %59, label %60, label %61

60:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %200

61:                                               ; preds = %6
  %62 = sdiv i64 %26, 4
  %63 = mul i64 %62, 4
  %64 = icmp eq i64 %63, %26
  %65 = xor i64 %26, 4
  %66 = ashr i64 %65, 63
  %67 = select i1 %64, i64 0, i64 %66
  %68 = add i64 %62, %67
  %69 = sdiv i64 %68, -32
  %70 = mul i64 %69, -32
  %71 = icmp eq i64 %70, %68
  %72 = xor i64 %68, -32
  %73 = ashr i64 %72, 63
  %74 = select i1 %71, i64 0, i64 %73
  %75 = add i64 %69, %74
  %76 = sub i64 0, %75
  %77 = sub i64 %76, 1
  %78 = call i64 @llvm.smax.i64(i64 %77, i64 0)
  br label %79

79:                                               ; preds = %87, %61
  %80 = phi <4 x float> [ zeroinitializer, %61 ], [ %120, %87 ]
  %81 = phi i64 [ 0, %61 ], [ %84, %87 ]
  call void @llvm.lifetime.end.p0(ptr %14)
  %82 = icmp eq i64 %81, %78
  %83 = add i64 %81, 1
  %84 = select i1 %82, i64 %81, i64 %83
  br i1 %82, label %85, label %87

85:                                               ; preds = %79
  %86 = icmp sgt i64 %76, 0
  br i1 %86, label %121, label %164

87:                                               ; preds = %79
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %81, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %88 = insertvalue [2 x ptr] undef, ptr %15, 0
  %89 = insertvalue [2 x ptr] %88, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %89, ptr %13, align 8
  %90 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %91 = load ptr, ptr %90, align 8
  %92 = load i64, ptr %91, align 8
  %93 = trunc i64 %92 to i32
  %94 = getelementptr inbounds ptr, ptr %90, i32 1
  %95 = load ptr, ptr %94, align 8
  %96 = load i64, ptr %95, align 8
  %97 = trunc i64 %96 to i32
  %98 = mul i32 %93, 32
  %99 = mul i32 %97, 128
  %100 = add i32 %98, %99
  %101 = sext i32 %100 to i64
  %102 = getelementptr inbounds float, ptr %23, i64 %101
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 0, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %103 = insertvalue [2 x ptr] undef, ptr %12, 0
  %104 = insertvalue [2 x ptr] %103, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %104, ptr %11, align 8
  %105 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %106 = load ptr, ptr %105, align 8
  %107 = load i64, ptr %106, align 8
  %108 = getelementptr inbounds ptr, ptr %105, i32 1
  %109 = load ptr, ptr %108, align 8
  %110 = load i64, ptr %109, align 8
  %111 = mul i64 %107, 32
  %112 = mul i64 %110, 128
  %113 = add i64 %111, %112
  %114 = getelementptr inbounds float, ptr %24, i64 %113
  %115 = getelementptr inbounds float, ptr %102, i64 %56
  %116 = load <4 x float>, ptr %115, align 16, !invariant.load !1
  %117 = getelementptr inbounds float, ptr %114, i64 %56
  %118 = load <4 x float>, ptr %117, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %119 = fmul contract <4 x float> %116, %118
  %120 = fadd contract <4 x float> %80, %119
  br label %79

121:                                              ; preds = %85
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %77, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %122 = insertvalue [2 x ptr] undef, ptr %15, 0
  %123 = insertvalue [2 x ptr] %122, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %123, ptr %9, align 8
  %124 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %125 = load ptr, ptr %124, align 8
  %126 = load i64, ptr %125, align 8
  %127 = trunc i64 %126 to i32
  %128 = getelementptr inbounds ptr, ptr %124, i32 1
  %129 = load ptr, ptr %128, align 8
  %130 = load i64, ptr %129, align 8
  %131 = trunc i64 %130 to i32
  %132 = mul i32 %127, 32
  %133 = mul i32 %131, 128
  %134 = add i32 %132, %133
  %135 = sext i32 %134 to i64
  %136 = getelementptr inbounds float, ptr %23, i64 %135
  %137 = getelementptr inbounds float, ptr %136, i64 %56
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 0, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %138 = insertvalue [2 x ptr] undef, ptr %8, 0
  %139 = insertvalue [2 x ptr] %138, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %139, ptr %7, align 8
  %140 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %141 = load ptr, ptr %140, align 8
  %142 = load i64, ptr %141, align 8
  %143 = getelementptr inbounds ptr, ptr %140, i32 1
  %144 = load ptr, ptr %143, align 8
  %145 = load i64, ptr %144, align 8
  %146 = mul i64 %142, 32
  %147 = mul i64 %145, 128
  %148 = add i64 %146, %147
  %149 = getelementptr inbounds float, ptr %24, i64 %148
  %150 = getelementptr inbounds float, ptr %149, i64 %56
  %151 = load i64, ptr %10, align 8
  %152 = mul i64 %151, 32
  %153 = add i64 %53, %152
  %154 = mul i64 %153, 4
  %155 = icmp slt i64 %154, %26
  br i1 %155, label %156, label %161

156:                                              ; preds = %121
  %157 = load <4 x float>, ptr %137, align 16, !invariant.load !1
  %158 = load <4 x float>, ptr %150, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %159 = fmul contract <4 x float> %157, %158
  %160 = fadd contract <4 x float> %80, %159
  br label %162

161:                                              ; preds = %121
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  br label %162

162:                                              ; preds = %161, %156
  %163 = phi <4 x float> [ %80, %161 ], [ %160, %156 ]
  br label %165

164:                                              ; preds = %85
  br label %165

165:                                              ; preds = %164, %162
  %166 = phi <4 x float> [ %80, %164 ], [ %163, %162 ]
  %167 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %166, i64 0)
  %168 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %166, i64 2)
  %169 = fadd contract <2 x float> %167, %168
  %170 = extractelement <2 x float> %169, i64 0
  %171 = extractelement <2 x float> %169, i64 1
  %172 = fadd contract float %170, %171
  %173 = bitcast float %172 to i32
  %174 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %173, i32 16, i32 31)
  %175 = bitcast i32 %174 to float
  %176 = fadd contract float %172, %175
  %177 = bitcast float %176 to i32
  %178 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %177, i32 8, i32 31)
  %179 = bitcast i32 %178 to float
  %180 = fadd contract float %176, %179
  %181 = bitcast float %180 to i32
  %182 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %181, i32 4, i32 31)
  %183 = bitcast i32 %182 to float
  %184 = fadd contract float %180, %183
  %185 = bitcast float %184 to i32
  %186 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %185, i32 2, i32 31)
  %187 = bitcast i32 %186 to float
  %188 = fadd contract float %184, %187
  %189 = bitcast float %188 to i32
  %190 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %189, i32 1, i32 31)
  %191 = bitcast i32 %190 to float
  %192 = fadd contract float %188, %191
  br i1 %57, label %193, label %198

193:                                              ; preds = %165
  %194 = load i64, ptr %15, align 8
  %195 = sitofp i64 %194 to float
  %196 = fadd contract float %192, %195
  %197 = getelementptr inbounds float, ptr %22, i64 %194
  store float %196, ptr %197, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %199

198:                                              ; preds = %165
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %199

199:                                              ; preds = %198, %193
  br label %200

200:                                              ; preds = %199, %60
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
