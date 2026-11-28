# Bugs we found in Mojo and MAX

Writing down what Mojo's kernels and libraries do, precisely enough for Lean, turns up places where the code
doesn't do what it says. Every bug here was reproduced on the newest nightly before it was filed, and each
issue has a small reproducer. The list grows as we file more : )

Each issue's GitHub page shows its current status.

| Issue | Filed | Area | What goes wrong |
|---|---|---|---|
| [#7735](https://github.com/modular/modular/issues/7735) | 2026-11-22 | GPU matmul (`layout.tile_io`) | Rows of C come back as zeros for large M (M = 70000, K = 32768), because the masked tile copy's bound wraps in int32. |
| [#7736](https://github.com/modular/modular/issues/7736) | 2026-11-22 | `TileTensor.copy_from` (GPU) | Row views that start 8 bytes past a 16-byte boundary crash with `CUDA_ERROR_MISALIGNED_ADDRESS`. |
| [#7737](https://github.com/modular/modular/issues/7737) | 2026-11-22 | CPU matmul | With K = 0, C is left unwritten instead of becoming the zero matrix. |
| [#7738](https://github.com/modular/modular/issues/7738) | 2026-11-22 | Layout algebra | `composition` gives a wrong layout when B's stride doesn't divide A's first mode. |
| [#7739](https://github.com/modular/modular/issues/7739) | 2026-11-22 | `std.math` | `gcd(Int.MIN, n)` never returns for most n, e.g. `gcd(Int.MIN, 6)`. |
| [#7740](https://github.com/modular/modular/issues/7740) | 2026-11-23 | CPU flash attention | A row comes out all NaN when an additive `-inf` mask covers its first 128 keys. |
| [#7741](https://github.com/modular/modular/issues/7741) | 2026-11-23 | GPU log-softmax | `softmax_inline[logsoftmax=True]` returns `-inf` on GPU where the CPU path is finite. |
| [#7742](https://github.com/modular/modular/issues/7742) | 2026-11-23 | `std.math` | `acos` returns 0 or pi instead of NaN outside [-1, 1] for Float32, Float16 and BFloat16. |
| [#7743](https://github.com/modular/modular/issues/7743) | 2026-11-23 | `std.math` | `tanh` on Float16 and BFloat16 is far off on CPU (`tanh(Float16(9))` is 0.866). |
| [#7753](https://github.com/modular/modular/issues/7753) | 2026-11-23 | CPU `arg_nonzero` | On a sliced view such as `x[:, 0:2]` it reports wrong coordinates, for example (1, 1) for a nonzero at (1, 0), because `idx2crd` undoes a layout only when its modes nest. |
| [#7754](https://github.com/modular/modular/issues/7754) | 2026-11-23 | CPU RMS norm | `rms_norm_cpu` ignores `multiply_before_cast`, so its bf16 results can be an ulp or two off from the GPU kernels'. |
| [#7755](https://github.com/modular/modular/issues/7755) | 2026-11-23 | `std.math` | Integer `sqrt` is wrong for every value above `Int.MAX`, e.g. `sqrt(UInt64(10**19))` returns 0. |
| [#7756](https://github.com/modular/modular/issues/7756) | 2026-11-23 | `std.math` | `ceildiv(5, Int.MIN)` returns 1, and `ceildiv(Int.MIN, 1)` crashes with SIGFPE. |
| [#7757](https://github.com/modular/modular/issues/7757) | 2026-11-24 | `TileTensor` `stack_allocation` | A padded layout such as `(2, 4):(6, 1)` gets 8 floats where it spans 10, so its last element is written past the buffer. |
| [#7758](https://github.com/modular/modular/issues/7758) | 2026-11-24 | GPU matmul (B tile offset) | With a large non-transposed B (N = 65536, K = 32800), every element of C is wrong, and K = 65536 crashes, because the B tile offset wraps in int32. |
| [#7761](https://github.com/modular/modular/issues/7761) | 2026-11-24 | Float literals | Literals just below the smallest subnormal become 0.0 instead of rounding up, e.g. `Float32(1e-45)` and `Float64(4.9e-324)`. |
| [#7762](https://github.com/modular/modular/issues/7762) | 2026-11-24 | Layout `idx2crd` | `idx2crd` divides by zero on extent-1, stride-0 modes, so it fails on every BitTensorLayout at compile time and returns garbage after `make_dynamic`. |
| [#7763](https://github.com/modular/modular/issues/7763) | 2026-11-24 | `TileTensor` `as_span` and `reshape` | A runtime column slice such as `m[:, 0:n]` passes the row-major check, so both read it as if it were dense. |
| [#7764](https://github.com/modular/modular/issues/7764) | 2026-11-24 | Float `**` | `x ** -n` returns 0.0 instead of a subnormal whenever `x ** n` overflows, e.g. `Float64(2) ** -1074.0`. |
| [#7765](https://github.com/modular/modular/issues/7765) | 2026-11-24 | `group_norm` | `num_groups = 0` raises nothing and never writes the output, and two error messages print `{C}` and `{num_groups}` as text. |
| [#7771](https://github.com/modular/modular/issues/7771) | 2026-11-24 | `std.utils.coord` | `==` and `!=` on nested `Coord`s fail to compile, because `__eq__` re-wraps each inner `Coord` into the same type. |
| [#7772](https://github.com/modular/modular/issues/7772) | 2026-11-24 | `std.math` | `tanh(NaN)` returns 1.0 instead of NaN on CPU for Float64, Float32, BFloat16 and Float16. |
| [#7773](https://github.com/modular/modular/issues/7773) | 2026-11-24 | Layout `Swizzle` | A negative shift gives wrong results on unsigned offsets, and the compile-time form fails to evaluate. |
| [#7774](https://github.com/modular/modular/issues/7774) | 2026-11-24 | `TileTensor.fill` | On a vectorized view, `fill` writes only the first scalar of each element. |
| [#7775](https://github.com/modular/modular/issues/7775) | 2026-11-24 | `TileTensor` views of a `TwoLevelLayout` | Slices, `vectorize`, `distribute`, `split` and `make_dynamic` of a swizzled layout read the wrong elements, and `tile` doesn't compile. |
| [#7790](https://github.com/modular/modular/issues/7790) | 2026-11-26 | Layout `blocked_product` | With a runtime block extent the outer strides come out as -6 and -2 instead of 12 and 4, and a runtime tiler stride doesn't compile. |
| [#7791](https://github.com/modular/modular/issues/7791) | 2026-11-26 | Layout `upcast` | `upcast` gives a stride-0 (broadcast) mode extent 0, and `UpcastLayout` turns a nested mode into `0:0`. |
| [#7792](https://github.com/modular/modular/issues/7792) | 2026-11-26 | `TileTensor` slicing | A literal `-1` slice end is read as an open end, so `t[:-1, :]` keeps every row. |
| [#7793](https://github.com/modular/modular/issues/7793) | 2026-11-26 | `tensor_core_mma` example (AMD) | The AMD output store goes through `vectorize[4, 1]` on a row-major C, so each MFMA tile's stores start only on every fourth row. |
| [#7794](https://github.com/modular/modular/issues/7794) | 2026-11-26 | `std.utils.coord` | `crd2idx` doesn't compile for a one-element nested coordinate like `((0, 2))`, so `l(l.idx2crd(i))` fails on rank-1 nested layouts. |
| [#7795](https://github.com/modular/modular/issues/7795) | 2026-11-26 | `idx2crd` | It fails to compile when a nested mode contains a static 1, and `Layout.idx2crd` fails on layouts nested two deep. |
| [#7796](https://github.com/modular/modular/issues/7796) | 2026-11-26 | `std.math` | The zero-alignment assert in `align_up`/`align_down` fires only when every lane is zero, and their docstrings are wrong for negative alignments. |
| [#7815](https://github.com/modular/modular/issues/7815) | 2026-11-27 | Float literals | Literals just above the largest finite value become NaN instead of inf, e.g. `Float16(70000.0)` and `Float32(4e38)`; formats without an infinity get a wrong finite value. |
| [#7831](https://github.com/modular/modular/issues/7831) | 2026-11-28 | Float literals | In Float8_e4m3fnuz and Float8_e5m2fnuz, negative literals too small to represent become NaN instead of 0.0, e.g. `Float8_e4m3fnuz(-1e-10)`, because 0x80, the sign bit alone, is their NaN. |
