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
# modular/modular@bbc13a71:max/kernels/test/gpu/linalg/test_gemv.mojo (sha256
# 5c79501dee90b23abf26f5129121ea66827dbe39645c704350879b1442e125c6) to the two kernel launches of
# its `run_matvec[.float32, .float32, .float32]`: `gemv_kernel` (M = 4096, N = 1, K = 4096) and
# `gevm_kernel` (M = 1, N = 4096, K = 4096) of max/kernels/src/linalg/gemv.mojo, with the same
# parameters, arguments, grid and block. The buffers are created but not filled, and the host code
# that fills, times, checks and prints is removed. `mojo build --emit llvm --target-accelerator
# sm_80 -o gemv_f32.ll gemv_f32.mojo` compiles it to the IR of tests/corpus/gemv/. The kernels
# have never been run.

from std.math import ceildiv

from max.gpu.host import DeviceContext
from linalg.gemv import gemv_kernel, gevm_kernel


def run_matvec[
    a_type: DType,
    b_type: DType,
    c_type: DType,
](M: Int, N: Int, K: Int, *, ctx: DeviceContext[]) raises:
    var a_device = ctx.enqueue_create_buffer[a_type](M * K)
    var b_device = ctx.enqueue_create_buffer[b_type](K * N)
    var c_device = ctx.enqueue_create_buffer[c_type](M * N)

    comptime warp_size = ctx.default_device_info.warp_size
    comptime WARPS_PER_BLOCK = 1024 // warp_size

    if N == 1:
        comptime kernel = gemv_kernel[c_type, a_type, b_type]

        ctx.enqueue_function[kernel](
            c_device,
            a_device,
            b_device,
            Int32(M),
            Int32(N),
            Int32(K),
            grid_dim=ceildiv(M, WARPS_PER_BLOCK),
            block_dim=warp_size * WARPS_PER_BLOCK,
        )
    elif M == 1:
        comptime kernel = gevm_kernel[
            c_type,
            a_type,
            b_type,
            tile_size=warp_size * WARPS_PER_BLOCK,
        ]

        ctx.enqueue_function[kernel](
            c_device,
            a_device,
            b_device,
            Int32(M),
            Int32(N),
            Int32(K),
            grid_dim=ceildiv(N, warp_size),
            block_dim=warp_size * WARPS_PER_BLOCK,
        )
    ctx.synchronize()


def main() raises:
    with DeviceContext() as ctx:
        # gemv for matrix vector multiply - FP32
        run_matvec[.float32, .float32, .float32](4096, 1, 4096, ctx=ctx)
        # gevm for vector matrix multiply - FP32
        run_matvec[.float32, .float32, .float32](1, 4096, 4096, ctx=ctx)
