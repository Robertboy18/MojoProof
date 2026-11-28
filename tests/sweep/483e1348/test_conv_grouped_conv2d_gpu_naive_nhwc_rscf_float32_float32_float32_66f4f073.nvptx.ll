; ModuleID = 'test_conv_grouped.mojo'
source_filename = "test_conv_grouped.mojo"
target datalayout = "e-p3:32:32-p4:32:32-p5:32:32-p6:32:32-p7:32:32-p101:32:32-i64:64-i128:128-i256:256-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

; Function Attrs: norecurse
define dso_local ptx_kernel void @conv2d_gpu_naive_nhwc_rscf_float32_float32_float32_66f4f073(ptr noundef nonnull readonly byval({ ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } }) %0, ptr noundef nonnull readonly byval({ ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } }) %1, ptr noundef nonnull readonly byval({ ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } }) %2, { i64, i64 } noundef %3, { i64, i64 } noundef %4, { i64, i64 } noundef %5, i32 noundef %6) #0 {
  %8 = load { ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } }, ptr %2, align 8
  %9 = load { ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } }, ptr %1, align 8
  %10 = load { ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } }, ptr %0, align 8
  %11 = extractvalue { ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } } %10, 0
  %12 = extractvalue { ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } } %9, 0
  %13 = extractvalue { ptr, { { {}, {}, {}, {} }, { {}, {}, {}, {} } } } %8, 0
  %14 = sext i32 %6 to i64
  %15 = icmp eq i64 %14, 0
  %16 = select i1 %15, i64 1, i64 %14
  %17 = sdiv i64 16, %16
  %18 = mul i64 %17, %16
  %19 = icmp eq i64 %18, 16
  %20 = xor i64 16, %16
  %21 = ashr i64 %20, 63
  %22 = select i1 %19, i64 0, i64 %21
  %23 = add i64 %17, %22
  %24 = select i1 %15, i64 0, i64 %23
  %25 = icmp eq i64 %24, 0
  %26 = select i1 %25, i64 1, i64 %24
  %27 = extractvalue { i64, i64 } %5, 0
  %28 = extractvalue { i64, i64 } %5, 1
  %29 = extractvalue { i64, i64 } %3, 0
  %30 = extractvalue { i64, i64 } %3, 1
  %31 = extractvalue { i64, i64 } %4, 0
  %32 = extractvalue { i64, i64 } %4, 1
  %33 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.z()
  %34 = mul i32 %33, 1024
  %35 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.y()
  %36 = zext i32 %35 to i64
  %37 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.y()
  %38 = sext i32 %37 to i64
  %39 = mul i64 %36, %38
  %40 = call i32 @llvm.nvvm.read.ptx.sreg.tid.y()
  %41 = zext i32 %40 to i64
  %42 = add i64 %39, %41
  %43 = trunc i64 %42 to i32
  %44 = mul i32 %43, 128
  %45 = add i32 %34, %44
  %46 = mul i64 %42, %29
  %47 = sub i64 %46, %27
  %48 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %49 = zext i32 %48 to i64
  %50 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %51 = sext i32 %50 to i64
  %52 = mul i64 %49, %51
  %53 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %54 = zext i32 %53 to i64
  %55 = add i64 %52, %54
  %56 = trunc i64 %55 to i32
  %57 = mul i32 %56, 16
  %58 = add i32 %45, %57
  %59 = mul i64 %55, %30
  %60 = sub i64 %59, %28
  %61 = icmp sge i64 %42, 8
  %62 = icmp sge i64 %55, 8
  %63 = select i1 %61, i1 true, i1 %62
  br i1 %63, label %64, label %65

64:                                               ; preds = %7
  br label %154

65:                                               ; preds = %7
  br label %66

66:                                               ; preds = %101, %65
  %67 = phi i64 [ 0, %65 ], [ %73, %101 ]
  %68 = icmp slt i64 %67, 16
  br i1 %68, label %69, label %82

69:                                               ; preds = %66
  %70 = trunc i64 %67 to i32
  %71 = icmp eq i64 %67, 16
  %72 = add i64 %67, 1
  %73 = select i1 %71, i64 %67, i64 %72
  %74 = sdiv i64 %67, %26
  %75 = mul i64 %74, %26
  %76 = icmp eq i64 %75, %67
  %77 = xor i64 %67, %26
  %78 = ashr i64 %77, 63
  %79 = select i1 %76, i64 0, i64 %78
  %80 = add i64 %74, %79
  %81 = select i1 %25, i64 0, i64 %80
  br label %83

82:                                               ; preds = %66
  br label %154

83:                                               ; preds = %125, %69
  %84 = phi i64 [ 0, %69 ], [ %100, %125 ]
  %85 = phi float [ 0.000000e+00, %69 ], [ %107, %125 ]
  %86 = icmp slt i64 %84, 3
  br i1 %86, label %87, label %101

87:                                               ; preds = %83
  %88 = trunc i64 %84 to i32
  %89 = mul i32 %88, 48
  %90 = mul i64 %84, %31
  %91 = add i64 %47, %90
  %92 = trunc i64 %91 to i32
  %93 = mul i32 %92, 128
  %94 = add i32 %34, %93
  %95 = icmp slt i64 %91, 8
  %96 = icmp sle i64 0, %91
  %97 = select i1 %96, i1 %95, i1 false
  %98 = icmp eq i64 %84, 3
  %99 = add i64 %84, 1
  %100 = select i1 %98, i64 %84, i64 %99
  br label %105

101:                                              ; preds = %83
  %102 = add i32 %58, %70
  %103 = sext i32 %102 to i64
  %104 = getelementptr inbounds float, ptr %13, i64 %103
  store float %85, ptr %104, align 4
  br label %66

105:                                              ; preds = %152, %87
  %106 = phi i64 [ 0, %87 ], [ %115, %152 ]
  %107 = phi float [ %85, %87 ], [ %153, %152 ]
  %108 = icmp slt i64 %106, 3
  br i1 %108, label %109, label %125

109:                                              ; preds = %105
  %110 = trunc i64 %106 to i32
  %111 = mul i32 %110, 16
  %112 = add i32 %89, %111
  %113 = icmp eq i64 %106, 3
  %114 = add i64 %106, 1
  %115 = select i1 %113, i64 %106, i64 %114
  %116 = mul i64 %106, %32
  %117 = add i64 %60, %116
  %118 = trunc i64 %117 to i32
  %119 = mul i32 %118, 16
  %120 = add i32 %94, %119
  %121 = icmp slt i64 %117, 8
  %122 = icmp sle i64 0, %117
  %123 = select i1 %122, i1 %121, i1 false
  %124 = select i1 %97, i1 %123, i1 false
  br i1 %124, label %126, label %151

125:                                              ; preds = %105
  br label %83

126:                                              ; preds = %109
  br label %127

127:                                              ; preds = %131, %126
  %128 = phi i64 [ 0, %126 ], [ %134, %131 ]
  %129 = phi float [ %107, %126 ], [ %149, %131 ]
  %130 = icmp slt i64 %128, 1
  br i1 %130, label %131, label %150

131:                                              ; preds = %127
  %132 = icmp eq i64 %128, 1
  %133 = add i64 %128, 1
  %134 = select i1 %132, i64 %128, i64 %133
  %135 = add i64 %81, %128
  %136 = trunc i64 %135 to i32
  %137 = add i32 %120, %136
  %138 = sext i32 %137 to i64
  %139 = getelementptr inbounds float, ptr %11, i64 %138
  %140 = load float, ptr %139, align 4
  %141 = trunc i64 %128 to i32
  %142 = mul i32 %141, 16
  %143 = add i32 %112, %142
  %144 = add i32 %143, %70
  %145 = sext i32 %144 to i64
  %146 = getelementptr inbounds float, ptr %12, i64 %145
  %147 = load float, ptr %146, align 4
  %148 = fmul contract float %140, %147
  %149 = fadd contract float %129, %148
  br label %127

150:                                              ; preds = %127
  br label %152

151:                                              ; preds = %109
  br label %152

152:                                              ; preds = %151, %150
  %153 = phi float [ %107, %151 ], [ %129, %150 ]
  br label %105

154:                                              ; preds = %82, %64
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.z() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 65535) i32 @llvm.nvvm.read.ptx.sreg.ctaid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.y() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 2147483647) i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 1, 1025) i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.nvvm.read.ptx.sreg.tid.x() #1

attributes #0 = { norecurse "target-cpu"="sm_80" "target-features"="+ptx81,+sm_80" "tune-cpu"="sm_80" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
