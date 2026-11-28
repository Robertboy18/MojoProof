; ModuleID = 'test_gemv2.mojo'
source_filename = "test_gemv2.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: convergent norecurse
define dso_local ptx_kernel void @gemv_kernel_vector_epilogue_fn_float32_float32_float32_True_4_3253ee90(ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {} }, { {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { i64, {} }, { {}, {} } } }) %2, i32 noundef %3, i32 noundef %4, i32 noundef %5, ptr noundef nonnull readonly byval({ { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }) %6) #0 {
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
  %24 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 2
  %25 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 1
  %26 = getelementptr { { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } }, { ptr, { { i64, {} }, { {}, {} } } } }, ptr %6, i32 0, i32 0
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
  call void @llvm.lifetime.end.p0(ptr %19)
  call void @llvm.lifetime.start.p0(ptr %19)
  store i32 %41, ptr %19, align 4
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.start.p0(ptr %18)
  store i32 %42, ptr %18, align 4
  call void @llvm.lifetime.end.p0(ptr %17)
  %43 = insertvalue [2 x ptr] undef, ptr %19, 0
  %44 = insertvalue [2 x ptr] %43, ptr %18, 1
  call void @llvm.lifetime.start.p0(ptr %17)
  store [2 x ptr] %44, ptr %17, align 8
  %45 = getelementptr inbounds [2 x ptr], ptr %17, i32 0, i32 0
  %46 = load ptr, ptr %45, align 8
  %47 = load i32, ptr %46, align 4
  %48 = insertelement <2 x i32> undef, i32 %47, i64 0
  %49 = getelementptr inbounds ptr, ptr %45, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = load i32, ptr %50, align 4
  %52 = insertelement <2 x i32> %48, i32 %51, i64 1
  call void @llvm.lifetime.end.p0(ptr %17)
  call void @llvm.lifetime.end.p0(ptr %18)
  call void @llvm.lifetime.end.p0(ptr %19)
  %53 = bitcast <2 x i32> %52 to i64
  call void @llvm.lifetime.end.p0(ptr %16)
  call void @llvm.lifetime.start.p0(ptr %16)
  store i64 %53, ptr %16, align 8
  %54 = call i32 @llvm.nvvm.read.ptx.sreg.laneid()
  %55 = sext i32 %54 to i64
  %56 = trunc i64 %55 to i32
  %57 = mul i32 %56, 4
  %58 = sext i32 %57 to i64
  %59 = icmp eq i64 %55, 0
  %60 = load i64, ptr %16, align 8
  %61 = icmp sge i64 %60, %27
  br i1 %61, label %62, label %63

62:                                               ; preds = %7
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %209

63:                                               ; preds = %7
  %64 = sdiv i64 %28, 4
  %65 = mul i64 %64, 4
  %66 = icmp eq i64 %65, %28
  %67 = xor i64 %28, 4
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
  %82 = phi <4 x float> [ zeroinitializer, %63 ], [ %122, %89 ]
  %83 = phi i64 [ 0, %63 ], [ %86, %89 ]
  call void @llvm.lifetime.end.p0(ptr %15)
  %84 = icmp eq i64 %83, %80
  %85 = add i64 %83, 1
  %86 = select i1 %84, i64 %83, i64 %85
  br i1 %84, label %87, label %89

87:                                               ; preds = %81
  %88 = icmp sgt i64 %78, 0
  br i1 %88, label %123, label %166

89:                                               ; preds = %81
  call void @llvm.lifetime.start.p0(ptr %15)
  store i64 %83, ptr %15, align 8
  call void @llvm.lifetime.end.p0(ptr %14)
  %90 = insertvalue [2 x ptr] undef, ptr %16, 0
  %91 = insertvalue [2 x ptr] %90, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %14)
  store [2 x ptr] %91, ptr %14, align 8
  %92 = getelementptr inbounds [2 x ptr], ptr %14, i32 0, i32 0
  %93 = load ptr, ptr %92, align 8
  %94 = load i64, ptr %93, align 8
  %95 = trunc i64 %94 to i32
  %96 = getelementptr inbounds ptr, ptr %92, i32 1
  %97 = load ptr, ptr %96, align 8
  %98 = load i64, ptr %97, align 8
  %99 = trunc i64 %98 to i32
  %100 = mul i32 %95, 32
  %101 = mul i32 %99, 128
  %102 = add i32 %100, %101
  %103 = sext i32 %102 to i64
  %104 = getelementptr inbounds float, ptr %22, i64 %103
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.start.p0(ptr %13)
  store i64 0, ptr %13, align 8
  call void @llvm.lifetime.end.p0(ptr %12)
  %105 = insertvalue [2 x ptr] undef, ptr %13, 0
  %106 = insertvalue [2 x ptr] %105, ptr %15, 1
  call void @llvm.lifetime.start.p0(ptr %12)
  store [2 x ptr] %106, ptr %12, align 8
  %107 = getelementptr inbounds [2 x ptr], ptr %12, i32 0, i32 0
  %108 = load ptr, ptr %107, align 8
  %109 = load i64, ptr %108, align 8
  %110 = getelementptr inbounds ptr, ptr %107, i32 1
  %111 = load ptr, ptr %110, align 8
  %112 = load i64, ptr %111, align 8
  %113 = mul i64 %109, 32
  %114 = mul i64 %112, 128
  %115 = add i64 %113, %114
  %116 = getelementptr inbounds float, ptr %23, i64 %115
  %117 = getelementptr inbounds float, ptr %104, i64 %58
  %118 = load <4 x float>, ptr %117, align 16, !invariant.load !1
  %119 = getelementptr inbounds float, ptr %116, i64 %58
  %120 = load <4 x float>, ptr %119, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %12)
  call void @llvm.lifetime.end.p0(ptr %13)
  call void @llvm.lifetime.end.p0(ptr %14)
  call void @llvm.lifetime.end.p0(ptr %15)
  %121 = fmul contract <4 x float> %118, %120
  %122 = fadd contract <4 x float> %82, %121
  br label %81

123:                                              ; preds = %87
  call void @llvm.lifetime.end.p0(ptr %11)
  call void @llvm.lifetime.start.p0(ptr %11)
  store i64 %79, ptr %11, align 8
  call void @llvm.lifetime.end.p0(ptr %10)
  %124 = insertvalue [2 x ptr] undef, ptr %16, 0
  %125 = insertvalue [2 x ptr] %124, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %10)
  store [2 x ptr] %125, ptr %10, align 8
  %126 = getelementptr inbounds [2 x ptr], ptr %10, i32 0, i32 0
  %127 = load ptr, ptr %126, align 8
  %128 = load i64, ptr %127, align 8
  %129 = trunc i64 %128 to i32
  %130 = getelementptr inbounds ptr, ptr %126, i32 1
  %131 = load ptr, ptr %130, align 8
  %132 = load i64, ptr %131, align 8
  %133 = trunc i64 %132 to i32
  %134 = mul i32 %129, 32
  %135 = mul i32 %133, 128
  %136 = add i32 %134, %135
  %137 = sext i32 %136 to i64
  %138 = getelementptr inbounds float, ptr %22, i64 %137
  %139 = getelementptr inbounds float, ptr %138, i64 %58
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.start.p0(ptr %9)
  store i64 0, ptr %9, align 8
  call void @llvm.lifetime.end.p0(ptr %8)
  %140 = insertvalue [2 x ptr] undef, ptr %9, 0
  %141 = insertvalue [2 x ptr] %140, ptr %11, 1
  call void @llvm.lifetime.start.p0(ptr %8)
  store [2 x ptr] %141, ptr %8, align 8
  %142 = getelementptr inbounds [2 x ptr], ptr %8, i32 0, i32 0
  %143 = load ptr, ptr %142, align 8
  %144 = load i64, ptr %143, align 8
  %145 = getelementptr inbounds ptr, ptr %142, i32 1
  %146 = load ptr, ptr %145, align 8
  %147 = load i64, ptr %146, align 8
  %148 = mul i64 %144, 32
  %149 = mul i64 %147, 128
  %150 = add i64 %148, %149
  %151 = getelementptr inbounds float, ptr %23, i64 %150
  %152 = getelementptr inbounds float, ptr %151, i64 %58
  %153 = load i64, ptr %11, align 8
  %154 = mul i64 %153, 32
  %155 = add i64 %55, %154
  %156 = mul i64 %155, 4
  %157 = icmp slt i64 %156, %28
  br i1 %157, label %158, label %163

158:                                              ; preds = %123
  %159 = load <4 x float>, ptr %139, align 16, !invariant.load !1
  %160 = load <4 x float>, ptr %152, align 16, !invariant.load !1
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  %161 = fmul contract <4 x float> %159, %160
  %162 = fadd contract <4 x float> %82, %161
  br label %164

163:                                              ; preds = %123
  call void @llvm.lifetime.end.p0(ptr %8)
  call void @llvm.lifetime.end.p0(ptr %9)
  call void @llvm.lifetime.end.p0(ptr %10)
  call void @llvm.lifetime.end.p0(ptr %11)
  br label %164

164:                                              ; preds = %163, %158
  %165 = phi <4 x float> [ %82, %163 ], [ %162, %158 ]
  br label %167

166:                                              ; preds = %87
  br label %167

167:                                              ; preds = %166, %164
  %168 = phi <4 x float> [ %82, %166 ], [ %165, %164 ]
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
  br i1 %59, label %195, label %207

195:                                              ; preds = %167
  %196 = load i64, ptr %16, align 8
  call void @llvm.lifetime.end.p0(ptr %16)
  %197 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %26, align 8
  %198 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %25, align 8
  %199 = load { ptr, { { i64, {} }, { {}, {} } } }, ptr %24, align 8
  %200 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %197, 0
  %201 = getelementptr inbounds float, ptr %200, i64 %196
  store float %194, ptr %201, align 4
  %202 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %198, 0
  %203 = getelementptr inbounds i32, ptr %202, i64 %196
  store i32 0, ptr %203, align 4
  %204 = trunc i64 %196 to i32
  %205 = extractvalue { ptr, { { i64, {} }, { {}, {} } } } %199, 0
  %206 = getelementptr inbounds i32, ptr %205, i64 %196
  store i32 %204, ptr %206, align 4
  br label %208

207:                                              ; preds = %167
  call void @llvm.lifetime.end.p0(ptr %16)
  br label %208

208:                                              ; preds = %207, %195
  br label %209

209:                                              ; preds = %208, %62
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
