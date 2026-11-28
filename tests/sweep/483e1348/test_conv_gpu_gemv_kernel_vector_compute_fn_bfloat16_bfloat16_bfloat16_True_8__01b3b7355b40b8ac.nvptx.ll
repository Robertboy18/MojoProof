; ModuleID = 'test_conv_gpu.mojo'
source_filename = "test_conv_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_compute_fn_bfloat16_bfloat16_bfloat16_True_8_16782529(ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, { i64, i64, i64, {} } noundef %6) #0 {
  %8 = alloca [2 x ptr], i64 1, align 8
  %9 = alloca i64, i64 1, align 8
  %10 = alloca [2 x ptr], i64 1, align 8
  %11 = alloca i64, i64 1, align 8
  %12 = alloca [2 x ptr], i64 1, align 8
  %13 = alloca i64, i64 1, align 8
  %14 = alloca [2 x ptr], i64 1, align 8
  %15 = alloca i64, i64 1, align 8
  %16 = alloca i64, i64 1, align 8
  %17 = alloca [2 x ptr], i64 1, align 8
  %18 = alloca i32, i64 1, align 4
  %19 = alloca i32, i64 1, align 4
  %20 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %2, align 8
  %21 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %1, align 8
  %22 = load { ptr, { { i64, i64 }, { i64, {} } } }, ptr %0, align 8
  %23 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %22, 0
  %24 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %21, 0
  %25 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %21, 1, 1, 0
  %26 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %20, 0
  %27 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %20, 1, 1, 0
  %28 = sext i32 %3 to i64
  %29 = sext i32 %5 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %31 = zext i32 %30 to i64
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %33 = zext i32 %32 to i64
  %34 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %35 = sext i32 %34 to i64
  %36 = mul i64 %33, %35
  %37 = add i64 %36, %31
  %38 = udiv i64 %37, 32
  %39 = bitcast i64 %38 to <2 x i32>
  %40 = extractelement <2 x i32> %39, i64 0
  %41 = extractelement <2 x i32> %39, i64 1
  %42 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %40, i32 0, i32 31)
  %43 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %41, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i32 %42, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %43, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  %44 = insertvalue [2 x ptr] undef, ptr %19, 0
  %45 = insertvalue [2 x ptr] %44, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %17)
  store [2 x ptr] %45, ptr %17, align 8
  %46 = getelementptr inbounds [2 x ptr], ptr %17, i32 0, i32 0
  %47 = load ptr, ptr %46, align 8
  %48 = load i32, ptr %47, align 4
  %49 = insertelement <2 x i32> undef, i32 %48, i64 0
  %50 = getelementptr inbounds ptr, ptr %46, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = load i32, ptr %51, align 4
  %53 = insertelement <2 x i32> %49, i32 %52, i64 1
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %54 = bitcast <2 x i32> %53 to i64
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 %54, ptr %16, align 8
  %55 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %56 = sext i32 %55 to i64
  %57 = mul i64 %56, 8
  %58 = icmp eq i64 %56, 0
  %59 = load i64, ptr %16, align 8
  %60 = icmp sge i64 %59, %28
  br i1 %60, label %61, label %62

61:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %204

62:                                               ; preds = %7
  %63 = sdiv i64 %29, 8
  %64 = mul i64 %63, 8
  %65 = icmp eq i64 %64, %29
  %66 = xor i64 %29, 8
  %67 = ashr i64 %66, 63
  %68 = select i1 %65, i64 0, i64 %67
  %69 = add i64 %63, %68
  %70 = sdiv i64 %69, -32
  %71 = mul i64 %70, -32
  %72 = icmp eq i64 %71, %69
  %73 = xor i64 %69, -32
  %74 = ashr i64 %73, 63
  %75 = select i1 %72, i64 0, i64 %74
  %76 = add i64 %70, %75
  %77 = sub i64 0, %76
  %78 = sub i64 %77, 1
  %79 = call i64 @llvm.smax.i64(i64 %78, i64 0)
  br label %80

80:                                               ; preds = %88, %62
  %81 = phi <8 x float> [ zeroinitializer, %62 ], [ %120, %88 ]
  %82 = phi i64 [ 0, %62 ], [ %85, %88 ]
  call void @llvm.lifetime.end.p0(ptr %15)
  %83 = icmp eq i64 %82, %79
  %84 = add i64 %82, 1
  %85 = select i1 %83, i64 %82, i64 %84
  br i1 %83, label %86, label %88

86:                                               ; preds = %80
  %87 = icmp sgt i64 %77, 0
  br i1 %87, label %121, label %163

88:                                               ; preds = %80
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %82, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %89 = insertvalue [2 x ptr] undef, ptr %16, 0
  %90 = insertvalue [2 x ptr] %89, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %90, ptr %14, align 8
  %91 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %92 = load ptr, ptr %91, align 8
  %93 = load i64, ptr %92, align 8
  %94 = getelementptr inbounds ptr, ptr %91, i32 1
  %95 = load ptr, ptr %94, align 8
  %96 = load i64, ptr %95, align 8
  %97 = mul i64 %93, %25
  %98 = mul i64 %96, 256
  %99 = add i64 %97, %98
  %100 = getelementptr inbounds bfloat, ptr %24, i64 %99
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 0, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %101 = insertvalue [2 x ptr] undef, ptr %13, 0
  %102 = insertvalue [2 x ptr] %101, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %102, ptr %12, align 8
  %103 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %104 = load ptr, ptr %103, align 8
  %105 = load i64, ptr %104, align 8
  %106 = getelementptr inbounds ptr, ptr %103, i32 1
  %107 = load ptr, ptr %106, align 8
  %108 = load i64, ptr %107, align 8
  %109 = mul i64 %105, %27
  %110 = mul i64 %108, 256
  %111 = add i64 %109, %110
  %112 = getelementptr inbounds bfloat, ptr %26, i64 %111
  %113 = getelementptr inbounds bfloat, ptr %100, i64 %57
  %114 = load <8 x bfloat>, ptr %113, align 16, !invariant.load !1
  %115 = getelementptr inbounds bfloat, ptr %112, i64 %57
  %116 = load <8 x bfloat>, ptr %115, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %117 = fpext <8 x bfloat> %114 to <8 x float>
  %118 = fpext <8 x bfloat> %116 to <8 x float>
  %119 = fmul contract <8 x float> %117, %118
  %120 = fadd contract <8 x float> %81, %119
  br label %80

121:                                              ; preds = %86
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %78, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %122 = insertvalue [2 x ptr] undef, ptr %16, 0
  %123 = insertvalue [2 x ptr] %122, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %123, ptr %10, align 8
  %124 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %125 = load ptr, ptr %124, align 8
  %126 = load i64, ptr %125, align 8
  %127 = getelementptr inbounds ptr, ptr %124, i32 1
  %128 = load ptr, ptr %127, align 8
  %129 = load i64, ptr %128, align 8
  %130 = mul i64 %126, %25
  %131 = mul i64 %129, 256
  %132 = add i64 %130, %131
  %133 = getelementptr inbounds bfloat, ptr %24, i64 %132
  %134 = getelementptr inbounds bfloat, ptr %133, i64 %57
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 0, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %135 = insertvalue [2 x ptr] undef, ptr %9, 0
  %136 = insertvalue [2 x ptr] %135, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %136, ptr %8, align 8
  %137 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %138 = load ptr, ptr %137, align 8
  %139 = load i64, ptr %138, align 8
  %140 = getelementptr inbounds ptr, ptr %137, i32 1
  %141 = load ptr, ptr %140, align 8
  %142 = load i64, ptr %141, align 8
  %143 = mul i64 %139, %27
  %144 = mul i64 %142, 256
  %145 = add i64 %143, %144
  %146 = getelementptr inbounds bfloat, ptr %26, i64 %145
  %147 = getelementptr inbounds bfloat, ptr %146, i64 %57
  %148 = load i64, ptr %11, align 8
  %149 = mul i64 %148, 32
  %150 = add i64 %56, %149
  %151 = mul i64 %150, 8
  %152 = icmp slt i64 %151, %29
  br i1 %152, label %153, label %160

153:                                              ; preds = %121
  %154 = load <8 x bfloat>, ptr %134, align 16, !invariant.load !1
  %155 = load <8 x bfloat>, ptr %147, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %156 = fpext <8 x bfloat> %154 to <8 x float>
  %157 = fpext <8 x bfloat> %155 to <8 x float>
  %158 = fmul contract <8 x float> %156, %157
  %159 = fadd contract <8 x float> %81, %158
  br label %161

160:                                              ; preds = %121
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %161

161:                                              ; preds = %160, %153
  %162 = phi <8 x float> [ %81, %160 ], [ %159, %153 ]
  br label %164

163:                                              ; preds = %86
  br label %164

164:                                              ; preds = %163, %161
  %165 = phi <8 x float> [ %81, %163 ], [ %162, %161 ]
  %166 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %165, i64 0)
  %167 = call <4 x float> @llvm.vector.extract.v4f32.v8f32(<8 x float> %165, i64 4)
  %168 = fadd contract <4 x float> %166, %167
  %169 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %168, i64 0)
  %170 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %168, i64 2)
  %171 = fadd contract <2 x float> %169, %170
  %172 = extractelement <2 x float> %171, i64 0
  %173 = extractelement <2 x float> %171, i64 1
  %174 = fadd contract float %172, %173
  %175 = bitcast float %174 to i32
  %176 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %175, i32 16, i32 31)
  %177 = bitcast i32 %176 to float
  %178 = fadd contract float %174, %177
  %179 = bitcast float %178 to i32
  %180 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %179, i32 8, i32 31)
  %181 = bitcast i32 %180 to float
  %182 = fadd contract float %178, %181
  %183 = bitcast float %182 to i32
  %184 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %183, i32 4, i32 31)
  %185 = bitcast i32 %184 to float
  %186 = fadd contract float %182, %185
  %187 = bitcast float %186 to i32
  %188 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %187, i32 2, i32 31)
  %189 = bitcast i32 %188 to float
  %190 = fadd contract float %186, %189
  %191 = bitcast float %190 to i32
  %192 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %191, i32 1, i32 31)
  %193 = bitcast i32 %192 to float
  %194 = fadd contract float %190, %193
  %195 = fptrunc float %194 to bfloat
  %196 = fpext bfloat %195 to float
  %197 = fmul contract float %196, 2.000000e+00
  %198 = fptrunc float %197 to bfloat
  br i1 %58, label %199, label %202

199:                                              ; preds = %164
  %200 = load i64, ptr %16, align 8
  %201 = getelementptr inbounds bfloat, ptr %23, i64 %200
  store bfloat %198, ptr %201, align 2
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %203

202:                                              ; preds = %164
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %203

203:                                              ; preds = %202, %199
  br label %204

204:                                              ; preds = %203, %61
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
