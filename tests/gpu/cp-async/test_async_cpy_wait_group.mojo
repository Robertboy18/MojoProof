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
# `cp.async.cg.shared.global` with and without its `src-size` operand,
# `cp.async.commit_group` and `cp.async.wait_group`, from
# modular/modular@bbc13a71:max/kernels/test/gpu/memory/test_async_cpy_wait_group.mojo
# (sha256 7b58f6cfd9bd06211e40729be8da1b6474f8877433b3d9c6402a7fa21ffb6c7c), with
# that file's imports kept, the imports of `argv` and `barrier` and the
# functions `next_word`, `copy_lanes` and `run_case` added, and its kernels,
# runners and `main` replaced. `copy_lanes` runs on one warp: the lanes store
# the 512 initial words into shared memory and meet at a barrier; then lane `l`
# issues 4 copies of 16 bytes into its own 64 bytes of shared memory, at
# `64 l + 16 j`, from the global addresses and with the source sizes of its plan:
# copies 0 and 1, then a commit; copy 2, then a commit; copy 3, without
# `src-size`, then a commit. After `wait_group 1` it stores its first 48 bytes
# (those of the two older groups) at word `12 l` of the first output, and after
# `wait_group 0` all 64 at word `16 l` of the second. `main` runs it on random
# words and plans and writes, for each case, the inputs and both outputs to the
# file its second argument names (its first is the seed). A conformance test,
# not a proof.

from std.sys import size_of

from max.gpu import thread_idx
from max.gpu.host import DeviceContext
from max.gpu.memory import (
    async_copy,
    async_copy_commit_group,
    async_copy_wait_all,
    async_copy_wait_group,
)
from std.memory import unsafe_stack_allocation
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal

from std.sys import argv
from max.gpu.sync import barrier

comptime SENTINEL = UInt32(0x7FBADBAD)


def next_word(mut s: UInt64) -> UInt32:
    """One step of xorshift64*: the high 32 bits of the scrambled state."""
    s ^= s >> 12
    s ^= s << 25
    s ^= s >> 27
    return ((s * 2685821657736338717) >> 32).cast[DType.uint32]()


def copy_lanes[
    o1_origin: MutOrigin,
    o2_origin: MutOrigin,
    g_origin: MutOrigin,
    i_origin: MutOrigin,
    p_origin: MutOrigin,
](
    o1_ptr: MutPointer[UInt32, o1_origin],
    o2_ptr: MutPointer[UInt32, o2_origin],
    g_ptr: MutPointer[UInt32, g_origin],
    i_ptr: MutPointer[UInt32, i_origin],
    p_ptr: MutPointer[UInt32, p_origin],
):
    """Lane `l`'s 4 copies into shared bytes `64 l` to `64 l + 63`, in 3
    groups, read after `wait_group 1` and after `wait_group 0`. Word `8 l + 2 j`
    of the plan is copy `j`'s global byte offset (a multiple of 16) and word
    `8 l + 2 j + 1` its source size (copy 3 has none)."""
    var l = Int(thread_idx.x)
    var shared = unsafe_stack_allocation[
        512, DType.uint32, alignment=16, address_space=.SHARED
    ]()
    for i in range(16):
        shared[unsafe_offset=16 * l + i] = i_ptr[unsafe_offset=16 * l + i]
    barrier()
    var g = g_ptr.unsafe_address_space_cast[.GLOBAL]()
    var p = 8 * l
    async_copy[16, fill=UInt32(0)](
        g.unsafe_offset(Int(p_ptr[unsafe_offset=p]) // 4),
        shared.unsafe_offset(16 * l),
        Int32(p_ptr[unsafe_offset=p + 1]),
    )
    async_copy[16, fill=UInt32(0)](
        g.unsafe_offset(Int(p_ptr[unsafe_offset=p + 2]) // 4),
        shared.unsafe_offset(16 * l + 4),
        Int32(p_ptr[unsafe_offset=p + 3]),
    )
    async_copy_commit_group()
    async_copy[16, fill=UInt32(0)](
        g.unsafe_offset(Int(p_ptr[unsafe_offset=p + 4]) // 4),
        shared.unsafe_offset(16 * l + 8),
        Int32(p_ptr[unsafe_offset=p + 5]),
    )
    async_copy_commit_group()
    async_copy[16](
        g.unsafe_offset(Int(p_ptr[unsafe_offset=p + 6]) // 4),
        shared.unsafe_offset(16 * l + 12),
    )
    async_copy_commit_group()
    async_copy_wait_group(1)
    for i in range(12):
        o1_ptr[unsafe_offset=12 * l + i] = shared[unsafe_offset=16 * l + i]
    async_copy_wait_group(0)
    for i in range(16):
        o2_ptr[unsafe_offset=16 * l + i] = shared[unsafe_offset=16 * l + i]


def run_case(
    ctx: DeviceContext, mut s: UInt64, n: Int, mut text: String
) raises:
    """One launch of one warp on 1,024 random global words and 512 random
    initial shared words; the plan's offsets are `16 (4 l + j)` and its
    source sizes 16 in case 0, and random (offsets below 4,096, sizes 0 to
    16) otherwise."""
    var g_buf = ctx.enqueue_create_buffer[DType.uint32](1024)
    var i_buf = ctx.enqueue_create_buffer[DType.uint32](512)
    var p_buf = ctx.enqueue_create_buffer[DType.uint32](256)
    var o1_buf = ctx.enqueue_create_buffer[DType.uint32](384)
    var o2_buf = ctx.enqueue_create_buffer[DType.uint32](512)
    text.write("case ", n, "\ngm")
    with g_buf.map_to_host() as h:
        for i in range(1024):
            var w = next_word(s)
            h[i] = w
            text.write(" ", w)
    text.write("\ninit")
    with i_buf.map_to_host() as h:
        for i in range(512):
            var w = next_word(s)
            h[i] = w
            text.write(" ", w)
    text.write("\nplan")
    with p_buf.map_to_host() as h:
        for i in range(256):
            var w: UInt32
            if i % 8 == 7:
                w = 16
            elif n == 0 and i % 2 == 0:
                w = UInt32(16 * (4 * (i // 8) + (i % 8) // 2))
            elif n == 0:
                w = 16
            elif i % 2 == 0:
                w = 16 * (next_word(s) % 256)
            else:
                w = next_word(s) % 17
            h[i] = w
            text.write(" ", w)
    text.write("\nfill ", SENTINEL, "\nwait1")
    with o1_buf.map_to_host() as h:
        for i in range(384):
            h[i] = SENTINEL
    with o2_buf.map_to_host() as h:
        for i in range(512):
            h[i] = SENTINEL

    var o1_ptr = o1_buf.unsafe_ptr()
    var o2_ptr = o2_buf.unsafe_ptr()
    var g_ptr = g_buf.unsafe_ptr()
    var i_ptr = i_buf.unsafe_ptr()
    var p_ptr = p_buf.unsafe_ptr()
    comptime kernel = copy_lanes[
        type_of(o1_ptr).origin,
        type_of(o2_ptr).origin,
        type_of(g_ptr).origin,
        type_of(i_ptr).origin,
        type_of(p_ptr).origin,
    ]
    ctx.enqueue_function[kernel](
        o1_ptr, o2_ptr, g_ptr, i_ptr, p_ptr, grid_dim=1, block_dim=32
    )
    with o1_buf.map_to_host() as h:
        for i in range(384):
            text.write(" ", h[i])
    text.write("\nwait0")
    with o2_buf.map_to_host() as h:
        for i in range(512):
            text.write(" ", h[i])
    text.write("\n")


def main() raises:
    var args = argv()
    var seed = atol(args[1])
    var s = UInt64(seed)
    var ctx = DeviceContext()
    var text = String()
    text.write("seed ", seed, "\ngpu ", ctx.device().get_name(), "\n")
    for n in range(6):
        run_case(ctx, s, n, text)
    ctx.synchronize()
    with open(String(args[2]), "w") as f:
        f.write(text)
