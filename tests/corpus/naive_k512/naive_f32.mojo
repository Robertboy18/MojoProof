# ===----------------------------------------------------------------------=== #
# Copyright (c) 2026, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #

# Modified for this repository, not upstream: MojoProof's reduction of
# modular/modular@bbc13a71:max/kernels/test/gpu/linalg/test_multistage_gemm_kernel.mojo (sha256
# 11934dcbe36565ba52eab774fd682924837326bc1b378e9fd74c6589ec5b43b7) to the launch of
# `matmul_kernel_naive` of max/kernels/src/linalg/matmul/gpu/__init__.mojo in its
# `multistage_gemm_run[M, N, K]` at float32, transposed `B` and `BLOCK_DIM = 16`, with the same
# parameters, layouts, arguments, grid and block, at M = 20, N = 256, K = 512 (row strides 512 of
# `A` and `B` and 256 of `C`; the upstream test launches it at K = 768). The buffers are created
# but not filled, and the multistage kernel and the host code that fills, checks and prints are
# removed. `mojo build --emit llvm --target-accelerator sm_90a -o naive_f32.ll naive_f32.mojo`
# compiles it to the IR of tests/corpus/naive_k512/. The kernel has never been run.

from max.gpu.host import DeviceContext
from std.math import ceildiv

from layout import Idx, TileTensor, row_major
from linalg.matmul.gpu import matmul_kernel_naive


def naive_run[
    M: Int,
    N: Int,
    K: Int,
    in_type: DType = .float32,
    out_type: DType = .float32,
](ctx: DeviceContext) raises:
    comptime transpose_b = True

    var a_shape = row_major(Idx[M], Idx[K])
    var b_shape = row_major(Idx[N], Idx[K])
    var c_shape = row_major(Idx[M], Idx[N])

    var a_device = ctx.enqueue_create_buffer[in_type](M * K)
    var b_device = ctx.enqueue_create_buffer[in_type](N * K)
    var c_device_ref = ctx.enqueue_create_buffer[out_type](M * N)

    var a_tensor = TileTensor(a_device, a_shape)
    var b_tensor = TileTensor(b_device, b_shape)
    var c_ref_tensor = TileTensor(c_device_ref, c_shape)

    comptime BLOCK_DIM = 16
    comptime naive_kernel = matmul_kernel_naive[
        out_type,
        in_type,
        in_type,
        type_of(c_ref_tensor).LayoutType,
        type_of(a_tensor).LayoutType,
        type_of(b_tensor).LayoutType,
        BLOCK_DIM,
        transpose_b,
        c_engine=type_of(c_ref_tensor).Engine,
        a_engine=type_of(a_tensor).Engine,
        b_engine=type_of(b_tensor).Engine,
    ]
    ctx.enqueue_function[naive_kernel](
        c_ref_tensor,
        a_tensor,
        b_tensor,
        Int32(M),
        Int32(N),
        Int32(K),
        grid_dim=(ceildiv(M, BLOCK_DIM), ceildiv(N, BLOCK_DIM)),
        block_dim=(BLOCK_DIM, BLOCK_DIM),
    )
    ctx.synchronize()


def main() raises:
    with DeviceContext() as ctx:
        naive_run[M=20, N=256, K=512](ctx)
