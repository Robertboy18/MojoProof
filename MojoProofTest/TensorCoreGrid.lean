import MojoProof.Sem.TensorCoreWarp
import MojoProofTest.Eval
import MojoProofTest.Pending

/-!
# The grid's step at a warp's `mma`, at two shapes

Tests of `Grid.fire_mma` (MojoProof/Sem/TensorCoreWarp.lean) and of `Grid.fire`'s `mma` arm.
* `f16Grid`, `bf16k8Grid`: `Grid.fire_mma` at `m16n8k16` with f16 inputs and at `m16n8k8` with
  bf16 inputs, both with an f32 accumulator, for every launch (so every accumulation policy),
  grid, warp, callees without a `range`, `nonnull` or `align` return attribute and all tiles of
  finite words: the step succeeds, and the lanes run on with the D tile of the launch's policy.
* `#guard`s, one program (`mmaKernel`, one block of 32 threads): each lane passes the same A, B
  and C registers, so rows 0-7 of A are 1, rows 8-15 are 2, B is 1 and C is 0.5; the lanes
  0-7 store their D registers 0 and 2 (rows `l / 4` and `l / 4 + 8`) at words `2l` and `2l + 1`
  of the buffer. At `m16n8k16` with f16 inputs the words are 16.5 and 32.5 (`0x41840000`,
  `0x42020000`), at `m16n8k8` with bf16 inputs 8.5 and 16.5 (`0x41080000`, `0x41840000`); the
  same program with one lane at another `mma` stops as unsupported, and with the intrinsic
  declared with a `nonnull` return it faults.
* `#guard`s, one cell at `m16n8k8` with f16 inputs (`cellCall`) whose products are `1`,
  `-2^24`, `0`, … from C = `2^24`, run at the two policies: `gridAcc` writes 1 in every word,
  `seqAcc` writes `+0`.
* `#guard`s on the grid directly (`warpAt`): a warp at `m16n8k8 .bf16` steps, one at
  `m16n8k24 .bf16`, a shape `Mma.table` does not list, is unsupported; with f16 inputs, a warp
  at `m16n8k16` steps and one at `m16n8k32`, another shape the table does not list, is
  unsupported, each with registers of its own counts and forms (`f16Regs`).
-/

namespace MojoProofTest.TensorCoreGrid

open MojoProof.Sem MojoProof.LLVM FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.Pending (thread kernel)

/-- `mma.m16n8k16` with f16 inputs and an f32 accumulator, as the importer reads it. -/
def mmaF16 : Mma := ⟨16, 8, 16, .f16, .float⟩

/-- `mma.m16n8k8` with bf16 inputs and an f32 accumulator, as the importer reads it. -/
def mmaBf16k8 : Mma := ⟨16, 8, 8, .bf16, .float⟩

/-- **The grid's step at a warp's `mma.m16n8k16` with f16 inputs**, the instance of
`Grid.fire_mma`: for every launch (so every accumulation policy `L.acc`), grid and warp whose 32
lanes wait at the `mma` with their `<2 x half>` A and B registers and `float` C registers
encoding tiles of finite words, from callees with no `range`, `nonnull` or `align` return
attribute, the step succeeds with a grid on the same memory whose threads outside the warp are
unchanged and whose lanes run on with results whose D tile is `L.acc.bits .binary16` of the
tiles at every cell. -/
theorem f16Grid {L : Launch} {c : Nat → Ctx} {g : Grid} {n : Nat}
    (hb : n % volume L.block - n % volume L.block % 32 + 32 ≤ volume L.block)
    (TA TB TC : Nat → Nat → Nat)
    (hTA : ∀ i j, TA i j < 2 ^ 16 ∧ wordFinite .binary16 (TA i j) = true)
    (hTB : ∀ i j, TB i j < 2 ^ 16 ∧ wordFinite .binary16 (TB i j) = true)
    (hTC : ∀ i j, TC i j < 2 ^ 32 ∧ wordFinite .binary32 (TC i j) = true)
    {u : Nat → Thread} {d : Nat → Func}
    (hl : ∀ j < 32, g.threads[n - n % volume L.block % 32 + j]? =
      some (.wait (u j) (.mma mmaF16) (encode .vec2 (fragA 2 2 2) TA j ++
        encode .vec2 (fragB 2 2) TB j ++ encode (.word 32) (fragC 2 1) TC j) (d j)) ∧
        (u j).at = (u (n % volume L.block % 32)).at)
    (hd : ∀ j < 32, ∀ a ∈ (d j).retAttrs, (∀ t lo hi, a ≠ .range t lo hi) ∧
      a ≠ .flag "nonnull" ∧ ∀ k, a ≠ .int "align" k) :
    ∃ y g', g.fire L c n = .ok (some g') ∧ g'.mem = g.mem ∧
      (∀ k, k < n - n % volume L.block % 32 ∨ n - n % volume L.block % 32 + 32 ≤ k →
        g'.threads[k]? = g.threads[k]?) ∧
      (∀ j < 32, g'.threads[n - n % volume L.block % 32 + j]? =
        some (.run ((u j).resume (some (y j))))) ∧
      ∀ i < 16, ∀ j < 8, (fragC 2 1).gather (resElem (.word 32) y) i j =
        L.acc.bits .binary16 (fun k : Fin 16 => TA i k) (fun k : Fin 16 => TB k j) (TC i j) :=
  Grid.fire_mma (v := mmaF16) (FA := fragA 2 2 2) (FB := fragB 2 2) (FC := fragC 2 1) rfl rfl
    rfl hb TA TB TC hTA hTB hTC hl hd

/-- **The grid's step at a warp's `mma.m16n8k8` with bf16 inputs**, the instance of
`Grid.fire_mma` at a second shape and input format: for every launch (so every policy
`L.acc`), grid and warp whose 32 lanes wait at the `mma` with their `i32` A and B registers (two
bf16 each) and `float` C registers encoding tiles of finite words, from callees with no
`range`, `nonnull` or `align` return attribute, the step succeeds with a grid on the same
memory whose threads outside the warp are unchanged and whose lanes run on with results whose D
tile is `L.acc.bits .bfloat16` of the tiles at every cell. -/
theorem bf16k8Grid {L : Launch} {c : Nat → Ctx} {g : Grid} {n : Nat}
    (hb : n % volume L.block - n % volume L.block % 32 + 32 ≤ volume L.block)
    (TA TB TC : Nat → Nat → Nat)
    (hTA : ∀ i j, TA i j < 2 ^ 16 ∧ wordFinite .bfloat16 (TA i j) = true)
    (hTB : ∀ i j, TB i j < 2 ^ 16 ∧ wordFinite .bfloat16 (TB i j) = true)
    (hTC : ∀ i j, TC i j < 2 ^ 32 ∧ wordFinite .binary32 (TC i j) = true)
    {u : Nat → Thread} {d : Nat → Func}
    (hl : ∀ j < 32, g.threads[n - n % volume L.block % 32 + j]? =
      some (.wait (u j) (.mma mmaBf16k8) (encode .pair (fragA 2 2 1) TA j ++
        encode .pair (fragB 2 1) TB j ++ encode (.word 32) (fragC 2 1) TC j) (d j)) ∧
        (u j).at = (u (n % volume L.block % 32)).at)
    (hd : ∀ j < 32, ∀ a ∈ (d j).retAttrs, (∀ t lo hi, a ≠ .range t lo hi) ∧
      a ≠ .flag "nonnull" ∧ ∀ k, a ≠ .int "align" k) :
    ∃ y g', g.fire L c n = .ok (some g') ∧ g'.mem = g.mem ∧
      (∀ k, k < n - n % volume L.block % 32 ∨ n - n % volume L.block % 32 + 32 ≤ k →
        g'.threads[k]? = g.threads[k]?) ∧
      (∀ j < 32, g'.threads[n - n % volume L.block % 32 + j]? =
        some (.run ((u j).resume (some (y j))))) ∧
      ∀ i < 16, ∀ j < 8, (fragC 2 1).gather (resElem (.word 32) y) i j =
        L.acc.bits .bfloat16 (fun k : Fin 8 => TA i k) (fun k : Fin 8 => TB k j) (TC i j) :=
  Grid.fire_mma (v := mmaBf16k8) (FA := fragA 2 2 1) (FB := fragB 2 1) (FC := fragC 2 1) rfl
    rfl rfl hb TA TB TC hTA hTB hTC hl hd

/-- One program: each of the block's threads runs the instructions `pre` after reading its
thread number `%2`, calls the `mma` intrinsic `name` with the arguments `ops` (its A, B and C
registers, typed as `decl` declares them, the declaration with the return attributes `ret`),
and the threads `l < 8` store their D registers 0 and 2 at words `2l` and `2l + 1` of the
buffer. With `odd`, thread 1 calls the intrinsic `odd` instead. -/
def mmaKernel (name decl ops : String) (odd : Option (String × String × String) := none)
    (pre ret : String := "") : String :=
  let call (n o : String) := "call { float, float, float, float } @" ++ n ++ "(" ++ o ++ ")"
  let first := match odd with
    | none => "  %3 = " ++ call name ops ++ "\n  br label %4\n"
    | some (n', _, o') => "  %a = icmp eq i32 %2, 1\n  br i1 %a, label %b, label %c\n\
      b:\n  %d = " ++ call n' o' ++ "\n  br label %e\nc:\n  %f = " ++ call name ops ++
      "\n  br label %e\ne:\n  %3 = phi { float, float, float, float } [ %d, %b ], [ %f, %c ]\n\
      br label %4\n"
  let declOdd := match odd with
    | none => ""
    | some (n', d', _) => "declare { float, float, float, float } @" ++ n' ++ "(" ++ d' ++
      ") #0\n"
  "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
    %2 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n" ++ pre ++ first ++ "4:\n\
    %5 = extractvalue { float, float, float, float } %3, 0\n\
    %6 = extractvalue { float, float, float, float } %3, 2\n\
    %7 = icmp ult i32 %2, 8\n\
    br i1 %7, label %8, label %12\n\
  8:\n\
    %9 = shl i32 %2, 1\n\
    %10 = getelementptr inbounds float, ptr addrspace(1) %0, i32 %9\n\
    store float %5, ptr addrspace(1) %10, align 4\n\
    %11 = getelementptr inbounds float, ptr addrspace(1) %10, i32 1\n\
    store float %6, ptr addrspace(1) %11, align 4\n\
    br label %12\n\
  12:\n\
    ret void\n\
  }\n\
  declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
  declare " ++ ret ++ "{ float, float, float, float } @" ++ name ++ "(" ++ decl ++ ") #0\n" ++
  declOdd ++
  "attributes #0 = { nocallback nounwind memory(none) }\n"

/-- `m16n8k16` with f16 inputs: the intrinsic, its parameter types and the arguments, A
registers `<1, 1>`, `<2, 2>`, `<1, 1>`, `<2, 2>`, B registers `<1, 1>`, C registers 0.5. -/
def f16Call : String × String × String :=
  let h (x : String) := "<2 x half> <half " ++ x ++ ", half " ++ x ++ ">"
  let f := "float 5.000000e-01"
  ("llvm.nvvm.mma.m16n8k16.row.col.f32.f32",
   "<2 x half>, <2 x half>, <2 x half>, <2 x half>, <2 x half>, <2 x half>, float, float, \
    float, float",
   ", ".intercalate [h "0xH3C00", h "0xH4000", h "0xH3C00", h "0xH4000", h "0xH3C00",
     h "0xH3C00", f, f, f, f])

/-- `m16n8k8` with bf16 inputs: the intrinsic, its parameter types and the arguments, A
registers `(1, 1)` and `(2, 2)` (`0x3f803f80`, `0x40004000`), B register `(1, 1)`, C registers
0.5. -/
def bf16k8Call : String × String × String :=
  let f := "float 5.000000e-01"
  ("llvm.nvvm.mma.m16n8k8.row.col.bf16", "i32, i32, i32, float, float, float, float",
   ", ".intercalate ["i32 1065369472", "i32 1073758208", "i32 1065369472", f, f, f, f])

/-- One cell whose two policies differ, at `m16n8k8` with f16 inputs: the lanes `l` with
`l % 4 = 0` pass the A registers `<1, -4096>` (`0xH3C00`, `0xHEC00`) and the B register
`<1, 4096>` (`0xH6C00`), the others zeros, so row `i` of A is `1, -4096, 0, …` and column `j`
of B is `1, 4096, 0, …` (`fragA 2 2 1`, `fragB 2 1`); C is `2^24`. Every cell's products are
`1`, `-2^24`, `0`, …: the instructions before the call, the intrinsic, its parameter types and
the arguments. -/
def cellCall : String × String × String × String :=
  let f := "float 1.677721600e+07"
  ("  %sp = and i32 %2, 3\n  %sq = icmp eq i32 %sp, 0\n\
    %sa = select i1 %sq, <2 x half> <half 0xH3C00, half 0xHEC00>, <2 x half> zeroinitializer\n\
    %sb = select i1 %sq, <2 x half> <half 0xH3C00, half 0xH6C00>, <2 x half> zeroinitializer\n",
   "llvm.nvvm.mma.m16n8k8.row.col.f32.f32", "<2 x half>, <2 x half>, <2 x half>, float, float, \
    float, float",
   ", ".intercalate ["<2 x half> %sa", "<2 x half> %sa", "<2 x half> %sb", f, f, f, f])

/-- The buffer's 16 words after one program at the call `call`, on one block of 32 threads, with
the instructions `pre`, the return attributes `ret` and the accumulation policy `acc`. -/
def mmaRun (call : String × String × String) (odd : Option (String × String × String) := none)
    (pre ret : String := "") (acc : MmaAcc := gridAcc) : Except String (List Val) :=
  runText (mmaKernel call.1 call.2.1 call.2.2 odd pre ret) 32 (fun b => [b]) 16
    (ty := .fp .float) (acc := acc)

-- one program at `m16n8k16` with f16 inputs: words 16.5 and 32.5
#guard checkWords "f16" ((List.range 8).flatMap fun _ => [0x41840000, 0x42020000])
  (mmaRun f16Call) == #[]

-- the same program at `m16n8k8` with bf16 inputs: words 8.5 and 16.5
#guard checkWords "bf16" ((List.range 8).flatMap fun _ => [0x41080000, 0x41840000])
  (mmaRun bf16k8Call) == #[]

-- the same program with thread 1 at the other `mma`: unsupported
#guard checkFault "odd" "lanes of a warp at different collectives"
  (mmaRun f16Call (some bf16k8Call)) == #[]

-- the mutant: the intrinsic declared with a `nonnull` return, which no aggregate meets
#guard checkFault "nonnull" "nonnull or align on a non-pointer"
  (mmaRun f16Call (ret := "nonnull ")) == #[]

-- one cell, two policies: the measured one gives 1 (`0x3F800000`) in every word, the
-- sequential one `+0`, as `2^24 + 1` rounds to even, `2^24`
#guard checkWords "cell gridAcc" (List.replicate 16 0x3F800000)
  (mmaRun cellCall.2 (pre := cellCall.1)) == #[]
#guard checkWords "cell seqAcc" (List.replicate 16 0)
  (mmaRun cellCall.2 (pre := cellCall.1) (acc := seqAcc)) == #[]

/-- A warp of 32 threads, each at the start of a kernel waiting at the `mma` `v` with the
arguments `args`, on the empty memory. -/
def warpAt (v : Mma) (args : List Val) : Grid :=
  { threads := Array.replicate 32 (.wait (thread #[]) (.mma v) args (kernel #[])), mem := {} }

/-- Nine registers of two bfloat16 ones (`0x3f803f80`), then four of binary32 zero: the A, B and
C registers of `m16n8k24 .bf16` (6, 3 and 4, `Mma.regs`), and enough for `m16n8k8 .bf16`. -/
def onesK24 : List Val := List.replicate 9 (.bits 32 0x3f803f80) ++ List.replicate 4 (.bits 32 0)

-- the grid steps at `m16n8k8 .bf16`, a listed shape, and refuses `m16n8k24 .bf16`, which
-- `Mma.table` does not list, with registers of `Mma.regs`' counts
#guard match (warpAt mmaBf16k8 ((onesK24.take 3) ++ onesK24.drop 9)).fire (launch2 1 1 32 1)
    (fun _ => Pending.ctx0) 0 with
  | .ok (some _) => true
  | _ => false
#guard match (warpAt ⟨16, 8, 24, .bf16, .float⟩ onesK24).fire (launch2 1 1 32 1)
    (fun _ => Pending.ctx0) 0 with
  | .error (.unsupported "mma operands the grid does not model") => true
  | _ => false

/-- `n` registers of two binary16 ones (`<2 x half>`, `0xH3C00`), then four of binary32 zero:
the A and B registers, then the C registers, of an `mma` with f16 inputs and an f32 accumulator
whose A and B take `n` registers together (`Mma.regs`: 6 at `m16n8k16`, 12 at `m16n8k32`). -/
def f16Regs (n : Nat) : List Val :=
  List.replicate n (.vec [.bits 16 0x3c00, .bits 16 0x3c00]) ++ List.replicate 4 (.bits 32 0)

-- with f16 inputs, the grid steps at `m16n8k16`, a listed shape, and refuses `m16n8k32`, which
-- `Mma.table` does not list, each with registers of its counts and forms
#guard match (warpAt mmaF16 (f16Regs 6)).fire (launch2 1 1 32 1) (fun _ => Pending.ctx0) 0 with
  | .ok (some _) => true
  | _ => false
#guard match (warpAt ⟨16, 8, 32, .f16, .float⟩ (f16Regs 12)).fire (launch2 1 1 32 1)
    (fun _ => Pending.ctx0) 0 with
  | .error (.unsupported "mma operands the grid does not model") => true
  | _ => false

end MojoProofTest.TensorCoreGrid
