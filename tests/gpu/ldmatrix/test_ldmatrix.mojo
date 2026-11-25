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

# Modified for this repository, not upstream: a test driver for a GPU run of
# `ldmatrix.sync.aligned.m8n8.x4.shared.b16`, with and without `.trans`, from
# modular/modular@bbc13a71:max/kernels/test/gpu/layout/test_ldmatrix.mojo (sha256
# 6953615728b429799295750b6eed9a3d4da634e2ef803ed338cb50553471e5e0), with that
# file's imports kept, the imports of `argv` and `bitcast` and the functions
# `next_word`, `ldm_lanes` and `run_case` added, and its kernels, runners and
# `main` replaced. `ldm_lanes` runs on one warp: the lanes copy 512 16-bit words
# into shared memory, then lane `l` gives the shared address of row `l`, the byte
# offset `rows[l]` (a multiple of 16), to the library's `ld_matrix` (which emits
# `llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16` and its `.trans` form) and stores
# its 4 registers of each load at `8 l` and `8 l + 4`. `main` runs it on random
# words and row offsets and writes, for each case, the words, the offsets and the
# lanes' registers to the file its second argument names (its first is the
# seed). A conformance test, not a proof.

from std.math import ceildiv
from std.math.uutils import umod, ufloordiv
from std.random import random_si64

from max.gpu import WARP_SIZE, lane_id, thread_idx
from max.gpu.sync import barrier
from max.gpu.host import DeviceContext
from max.gpu.compute.mma import ld_matrix, mma
from max.gpu.compute.mma_util import store_matrix_d
from layout import TileTensor, row_major
from layout.tensor_core import get_fragment_size, get_mma_shape
from linalg.matmul.gpu import matmul_kernel_naive
from std.memory import unsafe_stack_allocation
from std.memory.alloc import unsafe_alloc
from std.testing import assert_almost_equal

from std.utils.numerics import get_accum_type

from std.sys import argv
from std.memory import bitcast

comptime SENTINEL = UInt32(0x7FBADBAD)


def next_word(mut s: UInt64) -> UInt32:
    """One step of xorshift64*: the high 32 bits of the scrambled state."""
    s ^= s >> 12
    s ^= s << 25
    s ^= s >> 27
    return ((s * 2685821657736338717) >> 32).cast[DType.uint32]()


def ldm_lanes[
    d_origin: MutOrigin,
    m_origin: MutOrigin,
    a_origin: MutOrigin,
](
    d_ptr: MutPointer[UInt32, d_origin],
    m_ptr: MutPointer[UInt16, m_origin],
    a_ptr: MutPointer[UInt32, a_origin],
):
    """One `ldmatrix.x4` and one `ldmatrix.x4.trans` of the warp from 512
    16-bit words in shared memory, lane `l` giving row `l` at byte `rows[l]`."""
    var l = Int(thread_idx.x)
    var shared = unsafe_stack_allocation[
        512, DType.float16, alignment=32, address_space=.SHARED
    ]()
    for i in range(l, 512, WARP_SIZE):
        shared[unsafe_offset=i] = bitcast[DType.float16](
            m_ptr[unsafe_offset=i]
        )
    barrier()
    var p = shared.unsafe_offset(Int(a_ptr[unsafe_offset=l]) // 2)
    var plain = bitcast[DType.uint32, 4](ld_matrix[8](p))
    var trans = bitcast[DType.uint32, 4](ld_matrix[8, transpose=True](p))
    for r in range(4):
        d_ptr[unsafe_offset=8 * l + r] = plain[r]
        d_ptr[unsafe_offset=8 * l + 4 + r] = trans[r]


def run_case(
    ctx: DeviceContext, mut s: UInt64, n: Int, mut text: String
) raises:
    """One launch of one warp on 512 random 16-bit words; the row offsets
    are `16 l` in case 0 (the rows in order) and random multiples of 16 below
    1024 otherwise."""
    var m_buf = ctx.enqueue_create_buffer[DType.uint16](512)
    var a_buf = ctx.enqueue_create_buffer[DType.uint32](32)
    var d_buf = ctx.enqueue_create_buffer[DType.uint32](256)
    text.write("case ", n, "\nmem")
    with m_buf.map_to_host() as h:
        for i in range(512):
            var w = (next_word(s) >> 16).cast[DType.uint16]()
            h[i] = w
            text.write(" ", w)
    text.write("\nrows")
    with a_buf.map_to_host() as h:
        for i in range(32):
            var w: UInt32
            if n > 0:
                w = 16 * (next_word(s) % 64)
            else:
                w = UInt32(16 * i)
            h[i] = w
            text.write(" ", w)
    text.write("\ninit ", SENTINEL, "\nd")
    with d_buf.map_to_host() as h:
        for i in range(256):
            h[i] = SENTINEL

    var d_ptr = d_buf.unsafe_ptr()
    var m_ptr = m_buf.unsafe_ptr()
    var a_ptr = a_buf.unsafe_ptr()
    comptime kernel = ldm_lanes[
        type_of(d_ptr).origin,
        type_of(m_ptr).origin,
        type_of(a_ptr).origin,
    ]
    ctx.enqueue_function[kernel](d_ptr, m_ptr, a_ptr, grid_dim=1, block_dim=32)
    with d_buf.map_to_host() as h:
        for i in range(256):
            text.write(" ", h[i])
    text.write("\n")


def main() raises:
    var args = argv()
    var seed = atol(args[1])
    var s = UInt64(seed)
    var ctx = DeviceContext()
    var text = String()
    text.write("seed ", seed, "\ngpu ", ctx.device().get_name(), "\n")
    for n in range(8):
        run_case(ctx, s, n, text)
    ctx.synchronize()
    with open(String(args[2]), "w") as f:
        f.write(text)
