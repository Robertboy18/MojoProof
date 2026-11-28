; ModuleID = 'test_ragged_matmul_native_views.mojo'
source_filename = "test_ragged_matmul_native_views.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_epilogue_fn_float32_float32_float32_True_4_cb875049(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %6) #0 {
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
  %20 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %2, align 8
  %21 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %1, align 8
  %22 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %21, 0
  %23 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %20, 0
  %24 = sext i32 %3 to i64
  %25 = sext i32 %5 to i64
  %26 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %27 = zext i32 %26 to i64
  %28 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %29 = zext i32 %28 to i64
  %30 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %31 = sext i32 %30 to i64
  %32 = mul i64 %29, %31
  %33 = add i64 %32, %27
  %34 = udiv i64 %33, 32
  %35 = bitcast i64 %34 to <2 x i32>
  %36 = extractelement <2 x i32> %35, i64 0
  %37 = extractelement <2 x i32> %35, i64 1
  %38 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %36, i32 0, i32 31)
  %39 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %37, i32 0, i32 31)
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i32 %38, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %39, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  %40 = insertvalue [2 x ptr] undef, ptr %19, 0
  %41 = insertvalue [2 x ptr] %40, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %17)
  store [2 x ptr] %41, ptr %17, align 8
  %42 = getelementptr inbounds [2 x ptr], ptr %17, i32 0, i32 0
  %43 = load ptr, ptr %42, align 8
  %44 = load i32, ptr %43, align 4
  %45 = insertelement <2 x i32> undef, i32 %44, i64 0
  %46 = getelementptr inbounds ptr, ptr %42, i32 1
  %47 = load ptr, ptr %46, align 8
  %48 = load i32, ptr %47, align 4
  %49 = insertelement <2 x i32> %45, i32 %48, i64 1
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %50 = bitcast <2 x i32> %49 to i64
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 %50, ptr %16, align 8
  %51 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %52 = sext i32 %51 to i64
  %53 = trunc i64 %52 to i32
  %54 = mul i32 %53, 4
  %55 = sext i32 %54 to i64
  %56 = icmp eq i64 %52, 0
  %57 = load i64, ptr %16, align 8
  %58 = icmp sge i64 %57, %24
  br i1 %58, label %59, label %60

59:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %201

60:                                               ; preds = %7
  %61 = sdiv i64 %25, 4
  %62 = mul i64 %61, 4
  %63 = icmp eq i64 %62, %25
  %64 = xor i64 %25, 4
  %65 = ashr i64 %64, 63
  %66 = select i1 %63, i64 0, i64 %65
  %67 = add i64 %61, %66
  %68 = sdiv i64 %67, -32
  %69 = mul i64 %68, -32
  %70 = icmp eq i64 %69, %67
  %71 = xor i64 %67, -32
  %72 = ashr i64 %71, 63
  %73 = select i1 %70, i64 0, i64 %72
  %74 = add i64 %68, %73
  %75 = sub i64 0, %74
  %76 = sub i64 %75, 1
  %77 = call i64 @llvm.smax.i64(i64 %76, i64 0)
  br label %78

78:                                               ; preds = %86, %60
  %79 = phi <4 x float> [ zeroinitializer, %60 ], [ %119, %86 ]
  %80 = phi i64 [ 0, %60 ], [ %83, %86 ]
  call void @llvm.lifetime.end.p0(ptr %15)
  %81 = icmp eq i64 %80, %77
  %82 = add i64 %80, 1
  %83 = select i1 %81, i64 %80, i64 %82
  br i1 %81, label %84, label %86

84:                                               ; preds = %78
  %85 = icmp sgt i64 %75, 0
  br i1 %85, label %120, label %163

86:                                               ; preds = %78
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %80, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %87 = insertvalue [2 x ptr] undef, ptr %16, 0
  %88 = insertvalue [2 x ptr] %87, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %88, ptr %14, align 8
  %89 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %90 = load ptr, ptr %89, align 8
  %91 = load i64, ptr %90, align 8
  %92 = trunc i64 %91 to i32
  %93 = getelementptr inbounds ptr, ptr %89, i32 1
  %94 = load ptr, ptr %93, align 8
  %95 = load i64, ptr %94, align 8
  %96 = trunc i64 %95 to i32
  %97 = mul i32 %92, 64
  %98 = mul i32 %96, 128
  %99 = add i32 %97, %98
  %100 = sext i32 %99 to i64
  %101 = getelementptr inbounds float, ptr %22, i64 %100
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 0, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %102 = insertvalue [2 x ptr] undef, ptr %13, 0
  %103 = insertvalue [2 x ptr] %102, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %103, ptr %12, align 8
  %104 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %105 = load ptr, ptr %104, align 8
  %106 = load i64, ptr %105, align 8
  %107 = getelementptr inbounds ptr, ptr %104, i32 1
  %108 = load ptr, ptr %107, align 8
  %109 = load i64, ptr %108, align 8
  %110 = mul i64 %106, 64
  %111 = mul i64 %109, 128
  %112 = add i64 %110, %111
  %113 = getelementptr inbounds float, ptr %23, i64 %112
  %114 = getelementptr inbounds float, ptr %101, i64 %55
  %115 = load <4 x float>, ptr %114, align 16, !invariant.load !1
  %116 = getelementptr inbounds float, ptr %113, i64 %55
  %117 = load <4 x float>, ptr %116, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %118 = fmul contract <4 x float> %115, %117
  %119 = fadd contract <4 x float> %79, %118
  br label %78

120:                                              ; preds = %84
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %76, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %121 = insertvalue [2 x ptr] undef, ptr %16, 0
  %122 = insertvalue [2 x ptr] %121, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %122, ptr %10, align 8
  %123 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %124 = load ptr, ptr %123, align 8
  %125 = load i64, ptr %124, align 8
  %126 = trunc i64 %125 to i32
  %127 = getelementptr inbounds ptr, ptr %123, i32 1
  %128 = load ptr, ptr %127, align 8
  %129 = load i64, ptr %128, align 8
  %130 = trunc i64 %129 to i32
  %131 = mul i32 %126, 64
  %132 = mul i32 %130, 128
  %133 = add i32 %131, %132
  %134 = sext i32 %133 to i64
  %135 = getelementptr inbounds float, ptr %22, i64 %134
  %136 = getelementptr inbounds float, ptr %135, i64 %55
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 0, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %137 = insertvalue [2 x ptr] undef, ptr %9, 0
  %138 = insertvalue [2 x ptr] %137, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %138, ptr %8, align 8
  %139 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %140 = load ptr, ptr %139, align 8
  %141 = load i64, ptr %140, align 8
  %142 = getelementptr inbounds ptr, ptr %139, i32 1
  %143 = load ptr, ptr %142, align 8
  %144 = load i64, ptr %143, align 8
  %145 = mul i64 %141, 64
  %146 = mul i64 %144, 128
  %147 = add i64 %145, %146
  %148 = getelementptr inbounds float, ptr %23, i64 %147
  %149 = getelementptr inbounds float, ptr %148, i64 %55
  %150 = load i64, ptr %11, align 8
  %151 = mul i64 %150, 32
  %152 = add i64 %52, %151
  %153 = mul i64 %152, 4
  %154 = icmp slt i64 %153, %25
  br i1 %154, label %155, label %160

155:                                              ; preds = %120
  %156 = load <4 x float>, ptr %136, align 16, !invariant.load !1
  %157 = load <4 x float>, ptr %149, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %158 = fmul contract <4 x float> %156, %157
  %159 = fadd contract <4 x float> %79, %158
  br label %161

160:                                              ; preds = %120
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %161

161:                                              ; preds = %160, %155
  %162 = phi <4 x float> [ %79, %160 ], [ %159, %155 ]
  br label %164

163:                                              ; preds = %84
  br label %164

164:                                              ; preds = %163, %161
  %165 = phi <4 x float> [ %79, %163 ], [ %162, %161 ]
  %166 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %165, i64 0)
  %167 = call <2 x float> @llvm.vector.extract.v2f32.v4f32(<4 x float> %165, i64 2)
  %168 = fadd contract <2 x float> %166, %167
  %169 = extractelement <2 x float> %168, i64 0
  %170 = extractelement <2 x float> %168, i64 1
  %171 = fadd contract float %169, %170
  %172 = bitcast float %171 to i32
  %173 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %172, i32 16, i32 31)
  %174 = bitcast i32 %173 to float
  %175 = fadd contract float %171, %174
  %176 = bitcast float %175 to i32
  %177 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %176, i32 8, i32 31)
  %178 = bitcast i32 %177 to float
  %179 = fadd contract float %175, %178
  %180 = bitcast float %179 to i32
  %181 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %180, i32 4, i32 31)
  %182 = bitcast i32 %181 to float
  %183 = fadd contract float %179, %182
  %184 = bitcast float %183 to i32
  %185 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %184, i32 2, i32 31)
  %186 = bitcast i32 %185 to float
  %187 = fadd contract float %183, %186
  %188 = bitcast float %187 to i32
  %189 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %188, i32 1, i32 31)
  %190 = bitcast i32 %189 to float
  %191 = fadd contract float %187, %190
  br i1 %56, label %192, label %199

192:                                              ; preds = %164
  %193 = load i64, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %194 = load { ptr, { { {}, {} }, { {}, {} } } }, ptr %6, align 8
  %195 = extractvalue { ptr, { { {}, {} }, { {}, {} } } } %194, 0
  %196 = trunc i64 %193 to i32
  %197 = sext i32 %196 to i64
  %198 = getelementptr inbounds float, ptr %195, i64 %197
  store float %191, ptr %198, align 4
  br label %200

199:                                              ; preds = %164
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %200

200:                                              ; preds = %199, %192
  br label %201

201:                                              ; preds = %200, %59
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
