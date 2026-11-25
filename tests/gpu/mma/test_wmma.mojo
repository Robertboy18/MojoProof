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

# Modified for this repository, not upstream: a test driver for a GPU run of one
# `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32`, from
# modular/modular@bbc13a71:max/kernels/test/gpu/basics/test_wmma.mojo (sha256
# 5d69c6b27ebe81f1b08653fb780e83fb42caf37bb7ebeba2c182cc4fe40102bc), with that
# file's imports kept, the imports of `argv`, `bitcast` and `thread_idx` and the
# functions `next_word`, `bf16_half`, `probe_half`, `bf16_pair`, `f32_word`,
# `thr_half`, `mma_lanes` and `run_case` added, and its kernels, runners and `main` replaced. `mma_lanes`
# runs on one warp: lane `l` takes its A registers (4 words of two bfloat16 each), B
# registers (2 words) and C registers (4 float32 words) from the input buffers at
# `4 l`, `2 l` and `4 l`, calls the library's `mma` (which emits
# `llvm.nvvm.mma.m16n8k16.row.col.bf16`) and stores its 4 D registers at `4 l`.
# `main` runs it on random registers of several kinds and on one fixed probe and
# on a fixed overflow-threshold probe, and writes, for each case, the 32 lanes'
# A, B, C and D registers to the file its
# second argument names (its first is the seed, its third the number of random
# cases of each kind). A conformance test, not a proof.

from std.math import ceildiv
from std.memory.alloc import unsafe_alloc
from std.random import random_si64

from max.gpu import block_idx
from max.gpu.host import DeviceContext
from max.gpu.compute.mma import mma
from max.gpu.compute.mma_util import (
    load_matrix_a,
    load_matrix_b,
    store_matrix_d,
)
from layout import TileTensor, row_major
from linalg.matmul.gpu import matmul_kernel_naive
from std.testing import assert_false

from std.utils.numerics import isnan

from std.sys import argv
from std.memory import bitcast
from max.gpu import thread_idx

comptime SENTINEL = UInt32(0x7FBADBAD)


def next_word(mut s: UInt64) -> UInt32:
    """One step of xorshift64*: the high 32 bits of the scrambled state."""
    s ^= s >> 12
    s ^= s << 25
    s ^= s >> 27
    return ((s * 2685821657736338717) >> 32).cast[DType.uint32]()


def bf16_half(kind: Int, op: Int, w: UInt32) -> UInt32:
    """A bfloat16 word (16 bits) of operand `op` (0 for A, 1 for B) from the
    random word `w`, by kind: 0, an integer in [-8, 8]; 1, a normal number of
    exponent -16 to 15 (sign and fraction random, as below); 2, any finite word
    (exponent 255 made 254); 3, for A a subnormal word (exponent field 0) and
    for B a normal number of exponent 90 to 121; 4, a normal number of
    exponent -75 to -60; 6, as kind 1 (`bf16_pair` makes the pairs cancel);
    7, a normal number of exponent -63 to 63; 8, by two more random bits a
    subnormal word, a normal number of exponent -126 to -111, of exponent -8
    to 7 or of exponent 50 to 65; 9, a normal number of exponent 60 to 63."""
    var sign = (w >> 15) & 0x8000
    var frac = (w >> 5) & 0x7F
    if kind == 6:
        return bf16_half(1, op, w)
    if kind == 7:
        return sign | ((64 + (w & 127)) << 7) | frac
    if kind == 8:
        var pick = (w >> 13) & 3
        if pick == 0:
            return sign | frac
        if pick == 1:
            return sign | ((1 + (w & 15)) << 7) | frac
        if pick == 2:
            return sign | ((119 + (w & 15)) << 7) | frac
        return sign | ((177 + (w & 15)) << 7) | frac
    if kind == 9:
        return sign | ((187 + (w & 3)) << 7) | frac
    if kind == 0:
        var v = Int(w % 17) - 8
        return bitcast[DType.uint32](Float32(v)) >> 16
    if kind == 1:
        return sign | ((111 + (w & 31)) << 7) | frac
    if kind == 3 and op == 0:
        return sign | frac
    if kind == 3:
        return sign | ((217 + (w & 31)) << 7) | frac
    if kind == 4:
        return sign | ((52 + (w & 15)) << 7) | frac
    var h = w & 0xFFFF
    if ((h >> 7) & 0xFF) == 0xFF:
        return h ^ 0x0080
    return h


def probe_half(op: Int, l: Int, r: Int, h: Int) -> UInt32:
    """Element `h` of register `r` of lane `l` of operand `op` (0 for A, 1 for
    B) in the alignment probe: A[i][0] = 1 and A[i][k] = (2 - 2^-7) 2^-(21 + i)
    for k > 0; B[0][n] = 1 and B[k][n] = 2^-n for k > 0. So D[i][n] = C[i][n]
    + 1 + 15 (2 - 2^-7) 2^-(21 + i + n), one product of 1 and 15 equal smaller
    ones, at 128 distances. The element's row and column follow the ISA's
    fragment layouts of m16n8k16 (lane l = 4 g + t)."""
    var g = l // 4
    var t = l % 4
    if op == 0:
        var i = g + 8 * (r % 2)
        var k = h + 2 * (t + 4 * (r // 2))
        if k == 0:
            return 0x3F80
        return UInt32(((106 - i) << 7) | 0x7F)
    var k = h + 2 * (t + 4 * r)
    if k == 0:
        return 0x3F80
    return UInt32((127 - g) << 7)


def thr_half(op: Int, l: Int, r: Int, h: Int) -> UInt32:
    """Element `h` of register `r` of lane `l` of operand `op` (0 for A, 1 for
    B) in the overflow-threshold probe: A[i][0] = 2^52, B[0][n] = (-1)^n
    2^51 (1 + n / 8) and every other element 0, with C the largest finite
    float32 (`run_case`). So D[i][n] = (2 - 2^-23) 2^127 + (-1)^n (1 + n / 8)
    2^103, above the largest finite magnitude for even n. Layouts as in
    `probe_half`."""
    var g = l // 4
    var t = l % 4
    if op == 0:
        var k = h + 2 * (t + 4 * (r // 2))
        if k == 0:
            return UInt32(179 << 7)
        return 0
    var k = h + 2 * (t + 4 * r)
    if k == 0:
        return UInt32(((g & 1) << 15) | (178 << 7) | (g << 4))
    return 0


def bf16_pair(kind: Int, op: Int, mut s: UInt64) -> UInt32:
    """A register of operand `op` of two bfloat16 words of `kind`, element 0
    in the low bits. For kind 6 the two elements of an A register are equal
    but for the low fraction bits of the second (flipped by random bits, none
    one time in four) and those of a B register are negatives of each other,
    so the two products of each pair of `k` nearly cancel (`k` pairs `2 m`,
    `2 m + 1` in both layouts)."""
    var lo = bf16_half(kind, op, next_word(s))
    var w = next_word(s)
    if kind == 6:
        if op == 1:
            return lo | ((lo ^ 0x8000) << 16)
        var flip = w & 0x7F
        if ((w >> 8) & 3) == 0:
            flip = 0
        return lo | ((lo ^ flip) << 16)
    var hi = bf16_half(kind, op, w)
    return lo | (hi << 16)


def f32_word(kind: Int, mut s: UInt64) -> UInt32:
    """A float32 word by kind: 0, an integer in [-1024, 1024]; 1, a normal
    number of exponent -16 to 15; 2, any finite word (exponent 255 made 254);
    3, a normal number of exponent -30 to -15; 4, a subnormal word; 6, as 3;
    7, a normal number of exponent -100 to 100; 8, by two more random bits a
    subnormal word, a normal number of exponent -126 to -111 or of exponent
    -8 to 7; 9, a normal number of exponent 120 to 127."""
    var w = next_word(s)
    if kind == 6:
        return f32_word(3, s)
    if kind == 7:
        var e = 27 + (next_word(s) % 201)
        return (w & 0x807FFFFF) | (e << 23)
    if kind == 8:
        var pick = next_word(s) & 3
        if pick == 0:
            return w & 0x807FFFFF
        if pick == 1:
            return (w & 0x807FFFFF) | ((1 + (next_word(s) & 15)) << 23)
        return (w & 0x807FFFFF) | ((119 + (next_word(s) & 15)) << 23)
    if kind == 9:
        var e = 247 + (next_word(s) & 7)
        return (w & 0x807FFFFF) | (e << 23)
    if kind == 0:
        var v = Int(w % 2049) - 1024
        return bitcast[DType.uint32](Float32(v))
    if kind == 1:
        var e = 111 + (next_word(s) & 31)
        return (w & 0x807FFFFF) | (e << 23)
    if kind == 3:
        var e = 97 + (next_word(s) & 15)
        return (w & 0x807FFFFF) | (e << 23)
    if kind == 4:
        return w & 0x807FFFFF
    if ((w >> 23) & 0xFF) == 0xFF:
        return w ^ 0x00800000
    return w


def mma_lanes[
    d_origin: MutOrigin,
    a_origin: MutOrigin,
    b_origin: MutOrigin,
    c_origin: MutOrigin,
](
    d_ptr: MutPointer[UInt32, d_origin],
    a_ptr: MutPointer[UInt32, a_origin],
    b_ptr: MutPointer[UInt32, b_origin],
    c_ptr: MutPointer[UInt32, c_origin],
):
    """One m16n8k16 bf16 mma of the warp on the lanes' registers."""
    var l = Int(thread_idx.x)
    var ra = SIMD[DType.uint32, 4](0)
    var rb = SIMD[DType.uint32, 2](0)
    var rc = SIMD[DType.uint32, 4](0)
    for r in range(4):
        ra[r] = a_ptr[unsafe_offset=4 * l + r]
        rc[r] = c_ptr[unsafe_offset=4 * l + r]
    for r in range(2):
        rb[r] = b_ptr[unsafe_offset=2 * l + r]
    var rd = SIMD[DType.float32, 4](0)
    mma(
        rd,
        bitcast[DType.bfloat16, 8](ra),
        bitcast[DType.bfloat16, 4](rb),
        bitcast[DType.float32, 4](rc),
    )
    var wd = bitcast[DType.uint32, 4](rd)
    for r in range(4):
        d_ptr[unsafe_offset=4 * l + r] = wd[r]


def run_case(
    ctx: DeviceContext, mut s: UInt64, kind: Int, mut text: String
) raises:
    """One launch of one warp on random registers of `kind` (`bf16_half`,
    `f32_word`), or on the alignment probe (kind 5, `probe_half`, C zero) or
    the overflow-threshold probe (kind 10, `thr_half`), which draw no random
    word."""
    var a_buf = ctx.enqueue_create_buffer[DType.uint32](128)
    var b_buf = ctx.enqueue_create_buffer[DType.uint32](64)
    var c_buf = ctx.enqueue_create_buffer[DType.uint32](128)
    var d_buf = ctx.enqueue_create_buffer[DType.uint32](128)
    text.write("case ", kind, "\na")
    with a_buf.map_to_host() as h:
        for i in range(128):
            var w: UInt32
            if kind == 5:
                w = probe_half(0, i // 4, i % 4, 0) | (
                    probe_half(0, i // 4, i % 4, 1) << 16
                )
            elif kind == 10:
                w = thr_half(0, i // 4, i % 4, 0) | (
                    thr_half(0, i // 4, i % 4, 1) << 16
                )
            else:
                w = bf16_pair(kind, 0, s)
            h[i] = w
            text.write(" ", w)
    text.write("\nb")
    with b_buf.map_to_host() as h:
        for i in range(64):
            var w: UInt32
            if kind == 5:
                w = probe_half(1, i // 2, i % 2, 0) | (
                    probe_half(1, i // 2, i % 2, 1) << 16
                )
            elif kind == 10:
                w = thr_half(1, i // 2, i % 2, 0) | (
                    thr_half(1, i // 2, i % 2, 1) << 16
                )
            else:
                w = bf16_pair(kind, 1, s)
            h[i] = w
            text.write(" ", w)
    text.write("\nc")
    with c_buf.map_to_host() as h:
        for i in range(128):
            var w = UInt32(0)
            if kind == 10:
                w = UInt32(0x7F7FFFFF)
            elif kind != 5:
                w = f32_word(kind, s)
            h[i] = w
            text.write(" ", w)
    text.write("\ninit ", SENTINEL, "\nd")
    with d_buf.map_to_host() as h:
        for i in range(128):
            h[i] = SENTINEL

    var d_ptr = d_buf.unsafe_ptr()
    var a_ptr = a_buf.unsafe_ptr()
    var b_ptr = b_buf.unsafe_ptr()
    var c_ptr = c_buf.unsafe_ptr()
    comptime kernel = mma_lanes[
        type_of(d_ptr).origin,
        type_of(a_ptr).origin,
        type_of(b_ptr).origin,
        type_of(c_ptr).origin,
    ]
    ctx.enqueue_function[kernel](
        d_ptr, a_ptr, b_ptr, c_ptr, grid_dim=1, block_dim=32
    )
    with d_buf.map_to_host() as h:
        for i in range(128):
            text.write(" ", h[i])
    text.write("\n")


def main() raises:
    var args = argv()
    var seed = atol(args[1])
    var count = atol(args[3])
    var s = UInt64(seed)
    var ctx = DeviceContext()
    var text = String()
    text.write("seed ", seed, "\ngpu ", ctx.device().get_name(), "\n")
    # Kinds (`bf16_half`, `f32_word`): 0, small integers (every partial sum
    # exact); 1, normal numbers of moderate exponent; 2, any finite words; 3,
    # subnormal A elements; 4, products and C in the subnormal range; each
    # `count` times (the third argument). Then once kind 5, the alignment
    # probe (`probe_half`, C zero), which draws no random word. Then kinds 6,
    # near cancellation; 7, a wide spread of exponents; 8, subnormal and
    # normal elements mixed; 9, sums near the largest finite magnitude; each
    # `count` times; and once kind 10, the overflow-threshold probe
    # (`thr_half`). The first launches, to kind 5, are those of a run of the
    # driver without kinds 6 to 10 on the same seed.
    for kind in range(5):
        for _ in range(count):
            run_case(ctx, s, kind, text)
    run_case(ctx, s, 5, text)
    for kind in range(6, 10):
        for _ in range(count):
            run_case(ctx, s, kind, text)
    run_case(ctx, s, 10, text)
    ctx.synchronize()
    with open(String(args[2]), "w") as f:
        f.write(text)
