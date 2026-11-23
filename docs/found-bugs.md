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
