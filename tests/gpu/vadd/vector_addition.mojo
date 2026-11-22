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

# Modified for this repository, not upstream: a test driver for a GPU run of the kernel of
# modular/modular@bbc13a71:max/examples/gpu-functions/vector_addition.mojo (sha256
# f27b930957d981d74a83aa49cf0945cd7743c34e0662164d04b47a33210279f7)
# with that file's imports, declarations and kernel kept, the imports of `argv` and `bitcast`
# and the functions `next_word`, `finite` and `run_case` added, and its `main` replaced. `main`
# runs the kernel on random inputs at several launch sizes and writes, for each launch, the
# inputs and the whole output buffer to the file its second argument names (its first is the
# seed). tests/gpu/Compare.lean runs the evaluator on the same inputs. A conformance test, not
# a proof.

from std.math import ceildiv
from std.sys import argv, has_accelerator
from std.memory import bitcast

from max.gpu import global_idx
from max.gpu.host import DeviceContext
from layout import TileTensor, row_major

comptime float_dtype = DType.float32
comptime VECTOR_WIDTH = 10
comptime BLOCK_SIZE = 5
comptime layout = row_major[VECTOR_WIDTH]()


comptime PAD = 64
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


def run_case(
    ctx: DeviceContext,
    mut s: UInt64,
    n: Int,
    grid: Int,
    block: Int,
    mut text: String,
) raises:
    """One launch of `grid` blocks of `block` threads on size `n`: buffers of
    `n + PAD` floats, the inputs random finite floats, the output all SENTINEL.
    """
    var total = n + PAD
    var lhs_buffer = ctx.enqueue_create_buffer[float_dtype](total)
    var rhs_buffer = ctx.enqueue_create_buffer[float_dtype](total)
    var out_buffer = ctx.enqueue_create_buffer[float_dtype](total)
    text.write("case ", n, " ", grid, " ", block, " ", total, "\nlhs")
    with lhs_buffer.map_to_host() as h:
        for i in range(total):
            var w = finite(next_word(s))
            h[i] = bitcast[DType.float32](w)
            text.write(" ", w)
    text.write("\nrhs")
    with rhs_buffer.map_to_host() as h:
        for i in range(total):
            var w = finite(next_word(s))
            h[i] = bitcast[DType.float32](w)
            text.write(" ", w)
    text.write("\ninit ", SENTINEL, "\nout")
    with out_buffer.map_to_host() as h:
        for i in range(total):
            h[i] = bitcast[DType.float32](SENTINEL)

    var lhs_tensor = TileTensor(lhs_buffer, layout)
    var rhs_tensor = TileTensor(rhs_buffer, layout)
    var out_tensor = TileTensor(out_buffer, layout)
    ctx.enqueue_function[vector_addition](
        lhs_tensor,
        rhs_tensor,
        out_tensor,
        Int32(n),
        grid_dim=grid,
        block_dim=block,
    )
    with out_buffer.map_to_host() as h:
        for i in range(total):
            text.write(" ", bitcast[DType.uint32](h[i]))
    text.write("\n")


def main() raises:
    comptime assert has_accelerator(), "This example requires a supported GPU"
    var args = argv()
    var seed = atol(args[1])
    var s = UInt64(seed)
    var ctx = DeviceContext()
    var text = String()
    text.write("seed ", seed, "\ngpu ", ctx.device().get_name(), "\n")
    # (n, grid, block): one thread; n not a multiple of the block (37, 100,
    # 700, 1100); n above the thread count (1000 > 4 * 128); blocks of 1024.
    run_case(ctx, s, 1, 1, 1, text)
    run_case(ctx, s, 37, 3, 16, text)
    run_case(ctx, s, 100, 4, 32, text)
    run_case(ctx, s, 700, 3, 256, text)
    run_case(ctx, s, 1000, 4, 128, text)
    run_case(ctx, s, 1100, 2, 1024, text)
    ctx.synchronize()
    with open(String(args[2]), "w") as f:
        f.write(text)


def vector_addition(
    lhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    rhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    out_tensor: TileTensor[float_dtype, type_of(layout), MutAnyOrigin],
    size_dev: Int32,
):
    """The calculation to perform across the vector on the GPU."""
    var size = Int(size_dev)
    var global_tid = global_idx.x
    if global_tid < size:
        out_tensor[global_tid] = lhs_tensor[global_tid] + rhs_tensor[global_tid]
