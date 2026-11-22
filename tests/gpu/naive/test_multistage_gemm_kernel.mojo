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

# Modified for this repository, not upstream: a test driver for a GPU run of one kernel that
# modular/modular@bbc13a71:max/kernels/test/gpu/linalg/test_multistage_gemm_kernel.mojo (sha256
# 11934dcbe36565ba52eab774fd682924837326bc1b378e9fd74c6589ec5b43b7) launches: the float32 naive
# matmul kernel `matmul_kernel_naive` with BLOCK_DIM 16 and transpose_b, on the static shapes of
# `multistage_gemm_run[M=20, N=50257, K=768]` (A of 20 x 768, B of 50257 x 768, C of
# 20 x 50257, row-major) and the default engines, instantiated as that function instantiates it.
# That file's imports are kept, the imports of `argv` and `bitcast` and the functions
# `next_word`, `finite`, `moderate`, `write_words` and `run_case` are added, and everything else
# is replaced by a `main` that runs the kernel at several launch sizes on random inputs and
# writes, for each launch, the inputs and the whole output buffer to the file its second argument
# names (its first is the seed). tests/gpu/Compare.lean runs the evaluator on the same inputs. A
# conformance test, not a proof.

from max.gpu.host import DeviceContext, FuncAttribute
from std.math import ceildiv
from std.random import rand
from std.sys import argv
from std.memory import bitcast

from internal_utils import assert_almost_equal
from layout import (
    ComptimeInt,
    Coord,
    Idx,
    RowMajorLayout,
    TensorEngine,
    TileTensor,
    row_major,
)
from layout.tensor_engine import DefaultEngine, DevicePointerEngine
from linalg.matmul.gpu import matmul_kernel_naive, multistage_gemm
from linalg.matmul.gpu._multistage_gemm_gpu import multistage_gemm_kernel
from linalg.utils_gpu import MatmulConfig, MatmulKernels

comptime M = 20
comptime N = 50257
comptime K = 768
comptime BLOCK_DIM = 16
comptime SENTINEL = UInt32(0x7FBADBAD)


def next_word(mut s: UInt64) -> UInt32:
    """One step of xorshift64*: the high 32 bits of the scrambled state."""
    s ^= s >> 12
    s ^= s << 25
    s ^= s >> 27
    return ((s * 2685821657736338717) >> 32).cast[DType.uint32]()


def finite(w: UInt32) -> UInt32:
    """`w`, or for exponent 255 (an infinity or NaN) exponent 254: a finite float."""
    if ((w >> 23) & 0xFF) == 0xFF:
        return w ^ 0x00800000
    return w


def moderate(w: UInt32) -> UInt32:
    """`w` with its exponent field replaced by 124 plus its low 3 bits: a normal float of
    magnitude in [2^-3, 2^5), with `w`'s sign and mantissa."""
    return (w & 0x807FFFFF) | ((124 + ((w >> 23) & 7)) << 23)


def write_words(ws: List[UInt32], mut text: String):
    """The words `ws`, each run of k > 1 equal words w written `w*k`."""
    var i = 0
    while i < len(ws):
        var j = i + 1
        while j < len(ws) and ws[j] == ws[i]:
            j += 1
        if j - i > 1:
            text.write(" ", ws[i], "*", j - i)
        else:
            text.write(" ", ws[i])
        i = j


def run_case(
    ctx: DeviceContext,
    mut s: UInt64,
    m: Int,
    n: Int,
    k: Int,
    grid_x: Int,
    grid_y: Int,
    narrow: Bool,
    mut text: String,
) raises:
    """One launch of grid_x x grid_y blocks of 16 x 16 threads on m rows, n columns and inner
    dimension k: A of m * K words and B of n * K words (row-major, row stride K), the first k
    words of each row random finite floats (of magnitude in [2^-3, 2^5) if `narrow`) and the
    others SENTINEL; C of m * N words (row stride N), all SENTINEL.
    """
    var a_words = m * K
    var b_words = n * K
    var c_words = m * N
    var a_device = ctx.enqueue_create_buffer[DType.float32](a_words)
    var b_device = ctx.enqueue_create_buffer[DType.float32](b_words)
    var c_device_ref = ctx.enqueue_create_buffer[DType.float32](c_words)
    text.write("case ", m, " ", n, " ", k, " ", grid_x, " ", grid_y, " ", BLOCK_DIM, " ")
    text.write(BLOCK_DIM, " ", c_words, " ", a_words, " ", b_words, "\na")
    var ws = List[UInt32](capacity=a_words)
    with a_device.map_to_host() as h:
        for i in range(a_words):
            var w = finite(next_word(s)) if i % K < k else SENTINEL
            if narrow and i % K < k:
                w = moderate(w)
            h[i] = bitcast[DType.float32](w)
            ws.append(w)
    write_words(ws, text)
    text.write("\nb")
    ws = List[UInt32](capacity=b_words)
    with b_device.map_to_host() as h:
        for i in range(b_words):
            var w = finite(next_word(s)) if i % K < k else SENTINEL
            if narrow and i % K < k:
                w = moderate(w)
            h[i] = bitcast[DType.float32](w)
            ws.append(w)
    write_words(ws, text)
    text.write("\ninit ", SENTINEL, "\nc")
    with c_device_ref.map_to_host() as h:
        for i in range(c_words):
            h[i] = bitcast[DType.float32](SENTINEL)

    var a_shape = row_major(Idx[M], Idx[K])
    var b_shape = row_major(Idx[N], Idx[K])
    var c_shape = row_major(Idx[M], Idx[N])
    var a_tensor = TileTensor(a_device, a_shape)
    var b_tensor = TileTensor(b_device, b_shape)
    var c_ref_tensor = TileTensor(c_device_ref, c_shape)
    comptime naive_kernel = matmul_kernel_naive[
        DType.float32,
        DType.float32,
        DType.float32,
        type_of(c_ref_tensor).LayoutType,
        type_of(a_tensor).LayoutType,
        type_of(b_tensor).LayoutType,
        BLOCK_DIM,
        True,
        c_engine=type_of(c_ref_tensor).Engine,
        a_engine=type_of(a_tensor).Engine,
        b_engine=type_of(b_tensor).Engine,
    ]
    ctx.enqueue_function[naive_kernel](
        c_ref_tensor,
        a_tensor,
        b_tensor,
        Int32(m),
        Int32(n),
        Int32(k),
        grid_dim=(grid_x, grid_y),
        block_dim=(BLOCK_DIM, BLOCK_DIM),
    )
    var out = List[UInt32](capacity=c_words)
    with c_device_ref.map_to_host() as h:
        for i in range(c_words):
            out.append(bitcast[DType.uint32](h[i]))
    write_words(out, text)
    text.write("\n")
    _ = a_device^
    _ = b_device^
    _ = c_device_ref^


def main() raises:
    var args = argv()
    var seed = atol(args[1])
    var s = UInt64(seed)
    with DeviceContext() as ctx:
        var text = String()
        text.write("seed ", seed, "\ngpu ", ctx.device().get_name(), "\n")
        # (m, n, k, grid_x, grid_y, narrow), blocks of 16 x 16 threads: one cell; m and n not
        # multiples of 16, so threads out of bounds in x and in y; k = 768 (the static K), k = 0
        # (no round) and k below 768; grids larger than ceildiv(m, 16) x ceildiv(n, 16); m = 20
        # (the static M); inputs over the whole finite range, and of magnitude in [2^-3, 2^5),
        # whose sums stay finite and show the rounding.
        run_case(ctx, s, 1, 1, 1, 1, 1, False, text)
        run_case(ctx, s, 3, 5, 768, 1, 1, False, text)
        run_case(ctx, s, 17, 19, 7, 2, 2, False, text)
        run_case(ctx, s, 2, 21, 768, 1, 2, True, text)
        run_case(ctx, s, 5, 20, 0, 1, 2, False, text)
        run_case(ctx, s, 4, 6, 33, 2, 2, True, text)
        run_case(ctx, s, 20, 40, 2, 2, 3, False, text)
        run_case(ctx, s, 3, 17, 768, 1, 2, True, text)
        ctx.synchronize()
        with open(String(args[2]), "w") as f:
            f.write(text)
