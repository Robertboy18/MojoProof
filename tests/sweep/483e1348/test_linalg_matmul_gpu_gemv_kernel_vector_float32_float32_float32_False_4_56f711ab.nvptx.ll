; ModuleID = 'test_linalg_matmul_gpu.mojo'
source_filename = "test_linalg_matmul_gpu.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_float32_float32_float32_False_4_56f711ab(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, i64 }, { i64, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5) #0 {
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
  %20 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %1, align 8
  %21 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %0, align 8
  %22 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %21, 0
  %23 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %20, 0
  %24 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %19, 0
  %25 = extractvalue { ptr, { { i64, i64 }, { i64, {} } } } %19, 1, 1, 0
  %26 = sext i32 %3 to i64
  %27 = sext i32 %5 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %29 = zext i32 %28 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %31 = zext i32 %30 to i64
  %32 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %33 = sext i32 %32 to i64
  %34 = mul i64 %31, %33
  %35 = add i64 %34, %29
  %36 = udiv i64 %35, 32
  %37 = bitcast i64 %36 to <2 x i32>
  %38 = extractelement <2 x i32> %37, i64 0
  %39 = extractelement <2 x i32> %37, i64 1
  %40 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %38, i32 0, i32 31)
  %41 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %39, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %40, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.start.p0(ptr %17)
  store i32 %41, ptr %17, align 4
  call void @llvm.lifetime.end.p0(ptr %16)
  %42 = insertvalue [2 x ptr] undef, ptr %18, 0
  %43 = insertvalue [2 x ptr] %42, ptr %17, 1
  call void @llvm.lifetime.start.p0(ptr %16)
  store [2 x ptr] %43, ptr %16, align 8
  %44 = getelementptr inbounds [2 x ptr], ptr %16, i32 0, i32 0
  %45 = load ptr, ptr %44, align 8
  %46 = load i32, ptr %45, align 4
  %47 = insertelement <2 x i32> undef, i32 %46, i64 0
  %48 = getelementptr inbounds ptr, ptr %44, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = load i32, ptr %49, align 4
  %51 = insertelement <2 x i32> %47, i32 %50, i64 1
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  %52 = bitcast <2 x i32> %51 to i64
  call void @llvm.lifetime.end.p0(ptr %15)
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %52, ptr %15, align 8
  %53 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %54 = sext i32 %53 to i64
  %55 = mul i64 %54, 4
  %56 = trunc i64 %54 to i32
  %57 = mul i32 %56, 4
  %58 = sext i32 %57 to i64
  %59 = icmp eq i64 %54, 0
  %60 = load i64, ptr %15, align 8
  %61 = icmp sge i64 %60, %26
  br i1 %61, label %62, label %63

62:                                               ; preds = %6
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %195

63:                                               ; preds = %6
  %64 = sdiv i64 %27, 4
  %65 = mul i64 %64, 4
  %66 = icmp eq i64 %65, %27
  %67 = xor i64 %27, 4
  %68 = ashr i64 %67, 63
  %69 = select i1 %66, i64 0, i64 %68
  %70 = add i64 %64, %69
  %71 = sdiv i64 %70, -32
  %72 = mul i64 %71, -32
  %73 = icmp eq i64 %72, %70
  %74 = xor i64 %70, -32
  %75 = ashr i64 %74, 63
  %76 = select i1 %73, i64 0, i64 %75
  %77 = add i64 %71, %76
  %78 = sub i64 0, %77
  %79 = sub i64 %78, 1
  %80 = call i64 @llvm.smax.i64(i64 %79, i64 0)
  br label %81

81:                                               ; preds = %89, %63
  %82 = phi <4 x float> [ zeroinitializer, %63 ], [ %119, %89 ]
  %83 = phi i64 [ 0, %63 ], [ %86, %89 ]
  call void @llvm.lifetime.end.p0(ptr %14)
  %84 = icmp eq i64 %83, %80
  %85 = add i64 %83, 1
  %86 = select i1 %84, i64 %83, i64 %85
  br i1 %84, label %87, label %89

87:                                               ; preds = %81
  %88 = icmp sgt i64 %78, 0
  br i1 %88, label %120, label %160

89:                                               ; preds = %81
  call void @llvm.lifetime.start.p0(ptr %14)
  store i64 %83, ptr %14, align 8
  call void @llvm.lifetime.end.p0(ptr %13)
  %90 = insertvalue [2 x ptr] undef, ptr %15, 0
  %91 = insertvalue [2 x ptr] %90, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %13)
  store [2 x ptr] %91, ptr %13, align 8
  %92 = getelementptr inbounds [2 x ptr], ptr %13, i32 0, i32 0
  %93 = load ptr, ptr %92, align 8
  %94 = load i64, ptr %93, align 8
  %95 = getelementptr inbounds ptr, ptr %92, i32 1
  %96 = load ptr, ptr %95, align 8
  %97 = load i64, ptr %96, align 8
  %98 = mul i64 %94, 4
  %99 = mul i64 %97, 128
  %100 = add i64 %98, %99
  %101 = getelementptr inbounds float, ptr %23, i64 %100
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.start.p0(ptr %12)
  store i64 0, ptr %12, align 8
  call void @llvm.lifetime.end.p0(ptr %11)
  %102 = insertvalue [2 x ptr] undef, ptr %12, 0
  %103 = insertvalue [2 x ptr] %102, ptr %14, 1
  call void @llvm.lifetime.start.p0(ptr %11)
  store [2 x ptr] %103, ptr %11, align 8
  %104 = getelementptr inbounds [2 x ptr], ptr %11, i32 0, i32 0
  %105 = load ptr, ptr %104, align 8
  %106 = load i64, ptr %105, align 8
  %107 = getelementptr inbounds ptr, ptr %104, i32 1
  %108 = load ptr, ptr %107, align 8
  %109 = load i64, ptr %108, align 8
  %110 = mul i64 %106, %25
  %111 = mul i64 %109, 128
  %112 = add i64 %110, %111
  %113 = getelementptr inbounds float, ptr %24, i64 %112
  %114 = getelementptr inbounds float, ptr %101, i64 %58
  %115 = load <4 x float>, ptr %114, align 16, !invariant.load !1
  %116 = getelementptr inbounds float, ptr %113, i64 %55
  %117 = load <4 x float>, ptr %116, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  %118 = fmul contract <4 x float> %115, %117
  %119 = fadd contract <4 x float> %82, %118
  br label %81

120:                                              ; preds = %87
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.start.p0(ptr %10)
  store i64 %79, ptr %10, align 8
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
  %129 = mul i64 %125, 4
  %130 = mul i64 %128, 128
  %131 = add i64 %129, %130
  %132 = getelementptr inbounds float, ptr %23, i64 %131
  %133 = getelementptr inbounds float, ptr %132, i64 %58
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
  %142 = mul i64 %138, %25
  %143 = mul i64 %141, 128
  %144 = add i64 %142, %143
  %145 = getelementptr inbounds float, ptr %24, i64 %144
  %146 = getelementptr inbounds float, ptr %145, i64 %55
  %147 = load i64, ptr %10, align 8
  %148 = mul i64 %147, 32
  %149 = add i64 %54, %148
  %150 = mul i64 %149, 4
  %151 = icmp slt i64 %150, %27
  br i1 %151, label %152, label %157

152:                                              ; preds = %120
  %153 = load <4 x float>, ptr %133, align 16, !invariant.load !1
  %154 = load <4 x float>, ptr %146, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  %155 = fmul contract <4 x float> %153, %154
  %156 = fadd contract <4 x float> %82, %155
  br label %158

157:                                              ; preds = %120
  call void @llvm.lifetime.end.p0(ptr %7)
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  br label %158

158:                                              ; preds = %157, %152
  %159 = phi <4 x float> [ %82, %157 ], [ %156, %152 ]
  br label %161

160:                                              ; preds = %87
  br label %161

161:                                              ; preds = %160, %158
  %162 = phi <4 x float> [ %82, %160 ], [ %159, %158 ]
  %163 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %162, i64 0)
  %164 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %162, i64 2)
  %165 = fadd contract <2 x float> %163, %164
  %166 = extractelement <2 x float> %165, i64 0
  %167 = extractelement <2 x float> %165, i64 1
  %168 = fadd contract float %166, %167
  %169 = bitcast float %168 to i32
  %170 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %169, i32 16, i32 31)
  %171 = bitcast i32 %170 to float
  %172 = fadd contract float %168, %171
  %173 = bitcast float %172 to i32
  %174 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %173, i32 8, i32 31)
  %175 = bitcast i32 %174 to float
  %176 = fadd contract float %172, %175
  %177 = bitcast float %176 to i32
  %178 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %177, i32 4, i32 31)
  %179 = bitcast i32 %178 to float
  %180 = fadd contract float %176, %179
  %181 = bitcast float %180 to i32
  %182 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %181, i32 2, i32 31)
  %183 = bitcast i32 %182 to float
  %184 = fadd contract float %180, %183
  %185 = bitcast float %184 to i32
  %186 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %185, i32 1, i32 31)
  %187 = bitcast i32 %186 to float
  %188 = fadd contract float %184, %187
  br i1 %59, label %189, label %193

189:                                              ; preds = %161
  %190 = load i64, ptr %15, align 8
  %191 = mul i64 %190, 8
  %192 = getelementptr inbounds float, ptr %22, i64 %191
  store float %188, ptr %192, align 4
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %194

193:                                              ; preds = %161
  call void @llvm.lifetime.end.p0(ptr %15)
  br label %194

194:                                              ; preds = %193, %189
  br label %195

195:                                              ; preds = %194, %62
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
