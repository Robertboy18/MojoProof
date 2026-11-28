; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_bfloat16_bfloat16_bfloat16_True_8_d85dec43(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %19 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %20 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %21 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %22 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %21, 0
  %23 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %20, 0
  %24 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %20, 1, 1, 0
  %25 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %19, 0
  %26 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %19, 1, 1, 0
  %27 = sext i32 %3 to i64
  %28 = sext i32 %5 to i64
  %29 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %30 = zext i32 %29 to i64
  %31 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %32 = zext i32 %31 to i64
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %34 = sext i32 %33 to i64
  %35 = mul i64 %32, %34
  %36 = add i64 %35, %30
  %37 = udiv i64 %36, 32
  %38 = bitcast i64 %37 to <2 x i32>
  %39 = extractelement <2 x i32> %38, i64 0
  %40 = extractelement <2 x i32> %38, i64 1
  %41 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %39, i32 0, i32 31)
  %42 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %40, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %41, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i32 %42, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %43 = insertvalue [2 x ptr] undef, ptr %18, 0
  %44 = insertvalue [2 x ptr] %43, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %44, ptr %16, align 8
  %45 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %46 = load ptr, ptr %45, align 8
  %47 = load i32, ptr %46, align 4
  %48 = insertelement <2 x i32> undef, i32 %47, i64 0
  %49 = getelementptr inbounds ptr, ptr %45, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = load i32, ptr %50, align 4
  %52 = insertelement <2 x i32> %48, i32 %51, i64 1
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  %53 = bitcast <2 x i32> %52 to i64
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %53, ptr %15, align 8
  %54 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %55 = sext i32 %54 to i64
  %56 = mul i64 %55, 8
  %57 = icmp eq i64 %55, 0
  %58 = load i64, ptr %15, align 8
  %59 = icmp sge i64 %58, %27
  br i1 %59, label %60, label %61

60:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %200

61:                                               ; preds = %6
  %62 = sdiv i64 %28, 8
  %63 = mul i64 %62, 8
  %64 = icmp eq i64 %63, %28
  %65 = xor i64 %28, 8
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
  %80 = phi <8 x float> [ zeroinitializer, %61 ], [ %119, %87 ]
  %81 = phi i64 [ 0, %61 ], [ %84, %87 ]
  call void @llvm.lifetime.end.p0(ptr %14)
  %82 = icmp eq i64 %81, %78
  %83 = add i64 %81, 1
  %84 = select i1 %82, i64 %81, i64 %83
  br i1 %82, label %85, label %87

85:                                               ; preds = %79
  %86 = icmp sgt i64 %76, 0
  br i1 %86, label %120, label %162

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
  %93 = getelementptr inbounds ptr, ptr %90, i32 1
  %94 = load ptr, ptr %93, align 8
  %95 = load i64, ptr %94, align 8
  %96 = mul i64 %92, %24
  %97 = mul i64 %95, 256
  %98 = add i64 %96, %97
  %99 = getelementptr inbounds bfloat, ptr %23, i64 %98
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 0, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %100 = insertvalue [2 x ptr] undef, ptr %12, 0
  %101 = insertvalue [2 x ptr] %100, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %101, ptr %11, align 8
  %102 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %103 = load ptr, ptr %102, align 8
  %104 = load i64, ptr %103, align 8
  %105 = getelementptr inbounds ptr, ptr %102, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = load i64, ptr %106, align 8
  %108 = mul i64 %104, %26
  %109 = mul i64 %107, 256
  %110 = add i64 %108, %109
  %111 = getelementptr inbounds bfloat, ptr %25, i64 %110
  %112 = getelementptr inbounds bfloat, ptr %99, i64 %56
  %113 = load <8 x bfloat>, ptr %112, align 16, !invariant.load !1
  %114 = getelementptr inbounds bfloat, ptr %111, i64 %56
  %115 = load <8 x bfloat>, ptr %114, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %116 = fpext <8 x bfloat> %113 to <8 x float>
  %117 = fpext <8 x bfloat> %115 to <8 x float>
  %118 = fmul contract <8 x float> %116, %117
  %119 = fadd contract <8 x float> %80, %118
  br label %79

120:                                              ; preds = %85
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %77, ptr %10, align 8
  call void @llvm.lifetime.end.p0(ptr %9)
  %121 = insertvalue [2 x ptr] undef, ptr %15, 0
  %122 = insertvalue [2 x ptr] %121, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %9)
  store [2 x ptr] %122, ptr %9, align 8
  %123 = getelementptr inbounds [2 x ptr], ptr %9, i32 0, i32 0
  %124 = load ptr, ptr %123, align 8
  %125 = load i64, ptr %124, align 8
  %126 = getelementptr inbounds ptr, ptr %123, i32 1
  %127 = load ptr, ptr %126, align 8
  %128 = load i64, ptr %127, align 8
  %129 = mul i64 %125, %24
  %130 = mul i64 %128, 256
  %131 = add i64 %129, %130
  %132 = getelementptr inbounds bfloat, ptr %23, i64 %131
  %133 = getelementptr inbounds bfloat, ptr %132, i64 %56
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.start.p0(ptr %8)
  store i64 0, ptr %8, align 8
  call void @llvm.lifetime.end.p0(ptr %7)
  %134 = insertvalue [2 x ptr] undef, ptr %8, 0
  %135 = insertvalue [2 x ptr] %134, ptr %10, 1
  call void @llvm.lifetime.start.p0(ptr %7)
  store [2 x ptr] %135, ptr %7, align 8
  %136 = getelementptr inbounds [2 x ptr], ptr %7, i32 0, i32 0
  %137 = load ptr, ptr %136, align 8
  %138 = load i64, ptr %137, align 8
  %139 = getelementptr inbounds ptr, ptr %136, i32 1
  %140 = load ptr, ptr %139, align 8
  %141 = load i64, ptr %140, align 8
  %142 = mul i64 %138, %26
  %143 = mul i64 %141, 256
  %144 = add i64 %142, %143
  %145 = getelementptr inbounds bfloat, ptr %25, i64 %144
  %146 = getelementptr inbounds bfloat, ptr %145, i64 %56
  %147 = load i64, ptr %10, align 8
  %148 = mul i64 %147, 32
  %149 = add i64 %55, %148
  %150 = mul i64 %149, 8
  %151 = icmp slt i64 %150, %28
  br i1 %151, label %152, label %159

152:                                              ; preds = %120
  %153 = load <8 x bfloat>, ptr %133, align 16, !invariant.load !1
  %154 = load <8 x bfloat>, ptr %146, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %155 = fpext <8 x bfloat> %153 to <8 x float>
  %156 = fpext <8 x bfloat> %154 to <8 x float>
  %157 = fmul contract <8 x float> %155, %156
  %158 = fadd contract <8 x float> %80, %157
  br label %160

159:                                              ; preds = %120
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  br label %160

160:                                              ; preds = %159, %152
  %161 = phi <8 x float> [ %80, %159 ], [ %158, %152 ]
  br label %163

162:                                              ; preds = %85
  br label %163

163:                                              ; preds = %162, %160
  %164 = phi <8 x float> [ %80, %162 ], [ %161, %160 ]
  %165 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %164, i64 0)
  %166 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %164, i64 4)
  %167 = fadd contract <4 x float> %165, %166
  %168 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %167, i64 0)
  %169 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %167, i64 2)
  %170 = fadd contract <2 x float> %168, %169
  %171 = extractelement <2 x float> %170, i64 0
  %172 = extractelement <2 x float> %170, i64 1
  %173 = fadd contract float %171, %172
  %174 = bitcast float %173 to i32
  %175 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %174, i32 16, i32 31)
  %176 = bitcast i32 %175 to float
  %177 = fadd contract float %173, %176
  %178 = bitcast float %177 to i32
  %179 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %178, i32 8, i32 31)
  %180 = bitcast i32 %179 to float
  %181 = fadd contract float %177, %180
  %182 = bitcast float %181 to i32
  %183 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %182, i32 4, i32 31)
  %184 = bitcast i32 %183 to float
  %185 = fadd contract float %181, %184
  %186 = bitcast float %185 to i32
  %187 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %186, i32 2, i32 31)
  %188 = bitcast i32 %187 to float
  %189 = fadd contract float %185, %188
  %190 = bitcast float %189 to i32
  %191 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %190, i32 1, i32 31)
  %192 = bitcast i32 %191 to float
  %193 = fadd contract float %189, %192
  %194 = fptrunc float %193 to bfloat
  br i1 %57, label %195, label %198

195:                                              ; preds = %163
  %196 = load i64, ptr %15, align 8
  %197 = getelementptr inbounds bfloat, ptr %22, i64 %196
  store bfloat %194, ptr %197, align 2
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %199

198:                                              ; preds = %163
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %199

199:                                              ; preds = %198, %195
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
