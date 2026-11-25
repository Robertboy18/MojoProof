import MojoProof.Tile.Basic
import MojoProof.Sem.Matmul

/-!
# The tile dot loop and TorchLean's matrix product

This module defines a tile program of a matrix product whose thread computes one cell by a dot
loop, and proves what its cells hold against TorchLean's `Tensor.matmul`. It defines:

* `dotOracle q t cell`: the oracle numbers that thread `t`'s dot loop for `cell` asks for at the
  tile oracle `q`, the pair of the `fmul` and the `fadd` site of each term;
* `dotFrom c t r col n j acc` and `dot c K rc`: thread `t`'s loop over terms `j` to `j + n - 1`
  of cell `(r, col)` (load cell `(r, j)` of buffer 0 and cell `(col, j)` of buffer 1, ask for the
  two choices, one `dotStep`), then the store of the result in cell `(r, col)` of buffer 2, and
  the program in which thread `t` runs the loop over `K` terms for the cell `rc t` (nothing if
  `rc t` is `none`); cells of two coordinates are numbered by `Nat.pair`;
* `mats A B`: the state whose buffers 0 and 1 hold the matrices `A` and `B`;
* `Meets`: a word meets the product at a cell: the `NaNEq` of TorchLean's product when the
  contraction is off, `dotBound` of the real product when the format is IEEE and the word is
  finite, and, when the format is IEEE, `GPUProof.Approx` at `GPUProof.dotGrade` of every exact
  entries and grades at which the cell's inputs are `GPUProof.Approx`;
* `byRows m p`: the placement of thread `t < m p` at row `t / p` and column `t % p`;
* `pairOracle o`: the tile oracle of a kernel whose thread `t` asks for `o t j` at term `j`.

It proves, for every float format, contraction flag, sizes, matrices, tile oracle, number of
threads and placement with no two threads at one cell:

* `dotFrom_run`: the loop stores `dotLoop` of the loaded pairs;
* `dot_run`: the run of `dot c K rc` from `mats A B` ends without a fault, leaves buffers 0 and 1
  as they were, and holds at cell `rc t` of buffer 2 the `dotLoop` from `+0` over the first `K`
  pairs of row `r` of `A` and row `col` of `B`;
* `meets_dotLoop`, `dot_meets`: that loop meets the product, so every placed cell of the run
  meets the product of the first `K` columns of `A` and the transpose of those of `B`.

Nothing here is in the trusted base.
-/

namespace MojoProof.Tile

open MojoProof.Sem FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- The oracle numbers of thread `t`'s dot loop for cell `cell` at the tile oracle `q`: at term
`j`, the numbers of the sites (`t`, `cell`, `fmul`, `j`) and (`t`, `cell`, `fadd`, `j`). -/
def dotOracle (q : Site → Nat) (t cell : Nat) (j : Nat) : Nat × Nat :=
  (q ⟨t, cell, .fmul, j⟩, q ⟨t, cell, .fadd, j⟩)

/-- **Thread `t`'s dot loop for cell `(r, col)`** over terms `j` to `j + n - 1` from the word
`acc`: at each term `j`, load cell `Nat.pair r j` of buffer 0 (`a`) and `Nat.pair col j` of
buffer 1 (`b`), ask for the choices `u` at (`t`, `Nat.pair r col`, `fmul`, `j`) and `v` at
(`t`, `Nat.pair r col`, `fadd`, `j`), and continue from `dotStep c acc (a, b) (u, v)`; at the end,
store the word in cell `Nat.pair r col` of buffer 2. -/
def dotFrom {fmt : FloatFormat} (c : Bool) (t r col : Nat) :
    Nat → Nat → Model fmt → Prog (TileE (Model fmt)) Unit
  | 0, _, acc => .vis (.store 2 (Nat.pair r col) acc) fun _ => .ret ()
  | n + 1, j, acc =>
    .vis (.load 0 (Nat.pair r j)) fun a => .vis (.load 1 (Nat.pair col j)) fun b =>
      .vis (.choose ⟨t, Nat.pair r col, .fmul, j⟩) fun u =>
        .vis (.choose ⟨t, Nat.pair r col, .fadd, j⟩) fun v =>
          dotFrom c t r col n (j + 1) (dotStep c acc (a, b) (u, v))

/-- **The tile program of a matrix product over `K` terms** with placement `rc`: thread `t` with
`rc t = some (r, col)` runs `dotFrom c t r col K 0` from `+0` (`Model.zero fmt false`); a
thread with `rc t = none` does nothing. -/
def dot {fmt : FloatFormat} {m p : Nat} (c : Bool) (K : Nat) (rc : Nat → Option (Fin m × Fin p))
    (t : Nat) : Prog (TileE (Model fmt)) Unit :=
  match rc t with
  | some (r, col) => dotFrom c t r col K 0 (Model.zero fmt false)
  | none => .ret ()

/-- The state whose buffer 0 holds the matrix `A` (`m × sA`) and buffer 1 the matrix `B`
(`p × sB`): cell `Nat.pair r j` of buffer 0 is entry `(r, j)` of `A` for `r < m`, `j < sA`, and of
buffer 1 entry `(r, j)` of `B` for `r < p`, `j < sB`; no other cell is set; the log is empty and
the phase 0. -/
def mats {fmt : FloatFormat} {m p sA sB : Nat} (A : Tensor (Model fmt) [m, sA])
    (B : Tensor (Model fmt) [p, sB]) : St (Model fmt) where
  cells b i :=
    if b = 0 then
      if h : i.unpair.1 < m ∧ i.unpair.2 < sA then some (Tensor.get2 A ⟨_, h.1⟩ ⟨_, h.2⟩)
      else none
    else if b = 1 then
      if h : i.unpair.1 < p ∧ i.unpair.2 < sB then some (Tensor.get2 B ⟨_, h.1⟩ ⟨_, h.2⟩)
      else none
    else none
  log := []
  phase := 0

/-- Cell `Nat.pair r j` of buffer 0 of `mats A B` is entry `(r, j)` of `A`, for every format,
sizes, matrices, row `r` and column `j < sA`. -/
theorem mats_A {fmt : FloatFormat} {m p sA sB : Nat} (A : Tensor (Model fmt) [m, sA])
    (B : Tensor (Model fmt) [p, sB]) (r : Fin m) (j : Fin sA) :
    (mats A B).cells 0 (Nat.pair r j) = some (Tensor.get2 A r j) := by
  simp [mats, Nat.unpair_pair]

/-- Cell `Nat.pair r j` of buffer 1 of `mats A B` is entry `(r, j)` of `B`, for every format,
sizes, matrices, row `r` and column `j < sB`. -/
theorem mats_B {fmt : FloatFormat} {m p sA sB : Nat} (A : Tensor (Model fmt) [m, sA])
    (B : Tensor (Model fmt) [p, sB]) (r : Fin p) (j : Fin sB) :
    (mats A B).cells 1 (Nat.pair r j) = some (Tensor.get2 B r j) := by
  simp [mats, Nat.unpair_pair]

/-- **The loop stores the dot loop of the loaded pairs.** For every format, flag `c`, thread `t`,
cell `(r, col)`, count `n`, first term `j`, word `acc`, tile oracle `q`, state `s` and words
`a i`, `b i` (`i < n`) at cells `Nat.pair r (j + i)` of buffer 0 and `Nat.pair col (j + i)` of
buffer 1 of `s`: the run of `dotFrom c t r col n j acc` ends without a fault in a state whose
cells are those of `s` except cell `Nat.pair r col` of buffer 2, which holds `dotLoop c` from
`acc` over the pairs `(a i, b i)` at the oracle numbers `dotOracle q t (Nat.pair r col) (j + i)`. -/
theorem dotFrom_run {fmt : FloatFormat} (c : Bool) (t r col : Nat) (q : Site → Nat) (n : Nat) :
    ∀ (j : Nat) (acc : Model fmt) (s : St (Model fmt)) (a b : Fin n → Model fmt),
      (∀ i : Fin n, s.cells 0 (Nat.pair r (j + i.val)) = some (a i)) →
      (∀ i : Fin n, s.cells 1 (Nat.pair col (j + i.val)) = some (b i)) →
      ∃ s', run1 q t (dotFrom c t r col n j acc) s = .ok ((), s') ∧ ∀ b' i',
        s'.cells b' i' = if b' = 2 ∧ i' = Nat.pair r col then
          some (dotLoop c (fun i => dotOracle q t (Nat.pair r col) (j + i)) acc
            (List.ofFn fun i => (a i, b i)))
        else s.cells b' i' := by
  induction n with
  | zero =>
    intro j acc s a b _ _
    exact ⟨_, rfl, fun _ _ => by simp only [List.ofFn_zero, dotLoop]⟩
  | succ n ih =>
    intro j acc s a b ha hb
    have ha0 := ha 0
    have hb0 := hb 0
    simp only [Fin.val_zero, Nat.add_zero] at ha0 hb0
    have e : ∀ i : Fin n, j + 1 + i.val = j + i.succ.val := fun i => by
      rw [Fin.val_succ]; omega
    obtain ⟨s', h1, hc⟩ := ih (j + 1)
      (dotStep c acc (a 0, b 0) (dotOracle q t (Nat.pair r col) j))
      { s with log := ⟨t, 1, Nat.pair col j, false, s.phase⟩ ::
        ⟨t, 0, Nat.pair r j, false, s.phase⟩ :: s.log }
      (fun i => a i.succ) (fun i => b i.succ)
      (fun i => by rw [e]; exact ha i.succ) (fun i => by rw [e]; exact hb i.succ)
    refine ⟨s', ?_, fun b' i' => ?_⟩
    · simp only [dotFrom, run1, ha0, hb0]
      exact h1
    · have e' : (fun i => dotOracle q t (Nat.pair r col) (j + 1 + i)) =
          fun i => dotOracle q t (Nat.pair r col) (j + (i + 1)) := funext fun i => by
        rw [Nat.add_assoc, Nat.add_comm 1 i]
      rw [hc, e', List.ofFn_succ]
      simp only [dotLoop, Nat.add_zero]

/-- **The run of the tile matrix product.** For every format, flag `c`, sizes with `K ≤ sA` and
`K ≤ sB`, matrices `A` (`m × sA`) and `B` (`p × sB`), placement `rc` with no two threads at one
cell, tile oracle `q` and number `T` of threads: the run of `dot c K rc` on threads `0` to
`T - 1` from `mats A B` ends without a fault in a state whose buffers other than 2 are those of
`mats A B`, and whose cell `Nat.pair r col` of buffer 2, for every thread `t < T` with
`rc t = some (r, col)`, is `dotLoop c` at `dotOracle q t (Nat.pair r col)` from `+0` over the
pairs `(get2 A r k, get2 B col k)`, `k < K`. -/
theorem dot_run {fmt : FloatFormat} (c : Bool) {m p sA sB K : Nat} (hA : K ≤ sA) (hB : K ≤ sB)
    (A : Tensor (Model fmt) [m, sA]) (B : Tensor (Model fmt) [p, sB])
    {rc : Nat → Option (Fin m × Fin p)} (hinj : ∀ t t' x, rc t = some x → rc t' = some x → t = t')
    (q : Site → Nat) (T : Nat) :
    ∃ st, runAll q (dot c K rc) T (mats A B) = .ok st ∧
      (∀ b i, b ≠ 2 → st.cells b i = (mats A B).cells b i) ∧
      ∀ t r col, t < T → rc t = some (r, col) → st.cells 2 (Nat.pair r col) =
        some (dotLoop c (dotOracle q t (Nat.pair r col)) (Model.zero fmt false)
          (List.ofFn fun k : Fin K =>
            (Tensor.get2 A r (Fin.castLE hA k), Tensor.get2 B col (Fin.castLE hB k)))) := by
  induction T with
  | zero => exact ⟨_, rfl, fun _ _ _ => rfl, fun _ _ _ h => absurd h (Nat.not_lt_zero _)⟩
  | succ T ih =>
    obtain ⟨st, hs, h01, h2⟩ := ih
    have old : ∀ t r col, t < T + 1 → rc t = some (r, col) → t ≠ T →
        st.cells 2 (Nat.pair r col) = some (dotLoop c (dotOracle q t (Nat.pair r col))
          (Model.zero fmt false) (List.ofFn fun k : Fin K =>
            (Tensor.get2 A r (Fin.castLE hA k), Tensor.get2 B col (Fin.castLE hB k)))) :=
      fun t r col ht hr hne => h2 t r col (by omega) hr
    cases hT : rc T with
    | none =>
      refine ⟨st, ?_, h01, fun t r col ht hr => old t r col ht hr fun e => ?_⟩
      · simp only [runAll, hs, dot, hT]
        rfl
      · subst e; rw [hT] at hr; cases hr
    | some x =>
      obtain ⟨r, col⟩ := x
      obtain ⟨s', h1, hc⟩ := dotFrom_run c T r col q K 0 (Model.zero fmt false) st
        (fun k => Tensor.get2 A r (Fin.castLE hA k)) (fun k => Tensor.get2 B col (Fin.castLE hB k))
        (fun k => by
          rw [h01 0 _ (by decide), Nat.zero_add]
          exact mats_A A B r (Fin.castLE hA k))
        (fun k => by
          rw [h01 1 _ (by decide), Nat.zero_add]
          exact mats_B A B col (Fin.castLE hB k))
      simp only [Nat.zero_add] at hc
      refine ⟨s', ?_, fun b i hb => ?_, fun t r' col' ht hr => ?_⟩
      · simp only [runAll, hs, dot, hT, h1]
        rfl
      · rw [hc, ite_eq_right fun h => hb h.1]
        exact h01 b i hb
      · rw [hc]
        by_cases htT : t = T
        · subst htT
          rw [hT] at hr
          cases hr
          rw [ite_eq_left ⟨rfl, rfl⟩]
        · have hne : ¬ (2 = 2 ∧ Nat.pair r' col' = Nat.pair r col) := fun h => htT (by
            obtain ⟨e1, e2⟩ := Nat.pair_eq_pair.1 h.2
            exact hinj t T (r, col) (by rw [hr, Fin.ext e1, Fin.ext e2]) hT)
          rw [ite_eq_right hne]
          exact old t r' col' ht hr htT

/-- **A word meets TorchLean's product at a cell.** For every format, sizes with `K ≤ sA` and
`K ≤ sB`, matrices `A` (`m × sA`) and `B` (`p × sB`), cell `(r, col)`, flag `c` and oracle
sequence `o`, the word `v` meets the product when:

* if the contraction is off (`c` false, or no `fadd` number `(o j).2` is `2` modulo `3`), `v` and
  entry `(r, col)` of TorchLean's `Tensor.matmul` of the first `K` columns of `A` (`cols`) and
  the transpose of the first `K` columns of `B` are the same word or both NaNs (`NaNEq`);
* if the format is IEEE and `v` is finite, `|v - (A Bᵀ)_(r, col)|` over the reals on those
  columns is at most `dotBound fmt K` of the sum of the `K` absolute products;
* if the format is IEEE, for every exact entries `a`, `x` and grades `ga`, `gx` of length `K`
  such that entry `k` of row `r` of `A` is `GPUProof.Approx` at `ga k` of `a k` and entry `k` of
  row `col` of `B` at `gx k` of `x k`, `v` is `GPUProof.Approx` at
  `GPUProof.dotGrade (.ieee fmt) K a x ga gx` of `Σₖ aₖ xₖ`. -/
def Meets {fmt : FloatFormat} {m p sA sB K : Nat} (A : Tensor (Model fmt) [m, sA])
    (B : Tensor (Model fmt) [p, sB]) (hA : K ≤ sA) (hB : K ≤ sB) (r : Fin m) (col : Fin p)
    (c : Bool) (o : Nat → Nat × Nat) (v : Model fmt) : Prop :=
  ((∀ j, c = true → (o j).2 % 3 ≠ 2) →
    NaNEq v (Tensor.get2 (Tensor.matmul (cols K hA A)
      (Tensor.permute (cols K hB B) (Shape.adjacentSwap [p, K] 0) [K, p])) r col)) ∧
  (fmt.isIEEE = true → v.isFinite = true →
    |v.toReal - Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal (cols K hA A))
      (Tensor.map Model.toReal
        (Tensor.permute (cols K hB B) (Shape.adjacentSwap [p, K] 0) [K, p]))) r col| ≤
      dotBound fmt K ((List.ofFn fun k : Fin K =>
        (Tensor.get2 A r (Fin.castLE hA k), Tensor.get2 B col (Fin.castLE hB k))).map
          fun ab => |ab.1.toReal * ab.2.toReal|).sum) ∧
  (fmt.isIEEE = true → ∀ (a x : Fin K → ℝ) (ga gx : Fin K → GPUProof.Grade),
    (∀ k, GPUProof.Approx .real (ga k) (.ieee fmt) (Tensor.get2 A r (Fin.castLE hA k)).toReal?
      (a k)) →
    (∀ k, GPUProof.Approx .real (gx k) (.ieee fmt) (Tensor.get2 B col (Fin.castLE hB k)).toReal?
      (x k)) →
    GPUProof.Approx .real (GPUProof.dotGrade (.ieee fmt) K a x ga gx) (.ieee fmt) v.toReal?
      (∑ k, a k * x k))

/-- **The dot loop meets the product.** For every format, sizes with `K ≤ sA` and `K ≤ sB`,
matrices, cell `(r, col)`, flag `c` and oracle sequence `o`, `dotLoop c o` from `+0` over the
pairs `(get2 A r k, get2 B col k)`, `k < K`, meets the product at `(r, col)` (`Meets`; by
`matmul_cols_nanEq`, `matmul_cols_error` and `dotLoop_approx`). -/
theorem meets_dotLoop {fmt : FloatFormat} {m p sA sB K : Nat} (A : Tensor (Model fmt) [m, sA])
    (B : Tensor (Model fmt) [p, sB]) (hA : K ≤ sA) (hB : K ≤ sB) (r : Fin m) (col : Fin p)
    (c : Bool) (o : Nat → Nat × Nat) :
    Meets A B hA hB r col c o (dotLoop c o (Model.zero fmt false) (List.ofFn fun k : Fin K =>
      (Tensor.get2 A r (Fin.castLE hA k), Tensor.get2 B col (Fin.castLE hB k)))) :=
  ⟨matmul_cols_nanEq c o A B hA hB r col, fun hfmt => matmul_cols_error hfmt c o A B hA hB r col,
    fun hfmt a x ga gx ha hx => dotLoop_approx hfmt c o _ _ a x ga gx ha hx⟩

/-- **Every placed cell of the tile matrix product meets TorchLean's product.** For every
format, flag `c`, sizes with `K ≤ sA` and `K ≤ sB`, matrices `A` (`m × sA`) and `B` (`p × sB`),
placement `rc` with no two threads at one cell, tile oracle `q` and number `T`: the run of
`dot c K rc` on threads `0` to `T - 1` from `mats A B` ends without a fault, and for every thread
`t < T` with `rc t = some (r, col)` its cell `Nat.pair r col` of buffer 2 holds a word that meets
the product at `(r, col)` at the oracle numbers `dotOracle q t (Nat.pair r col)` (`Meets`). -/
theorem dot_meets {fmt : FloatFormat} (c : Bool) {m p sA sB K : Nat} (hA : K ≤ sA) (hB : K ≤ sB)
    (A : Tensor (Model fmt) [m, sA]) (B : Tensor (Model fmt) [p, sB])
    {rc : Nat → Option (Fin m × Fin p)} (hinj : ∀ t t' x, rc t = some x → rc t' = some x → t = t')
    (q : Site → Nat) (T : Nat) :
    ∃ st, runAll q (dot c K rc) T (mats A B) = .ok st ∧
      ∀ t r col, t < T → rc t = some (r, col) → ∃ v, st.cells 2 (Nat.pair r col) = some v ∧
        Meets A B hA hB r col c (dotOracle q t (Nat.pair r col)) v :=
  let ⟨st, hr, _, h2⟩ := dot_run c hA hB A B hinj q T
  ⟨st, hr, fun t r col ht h => ⟨_, h2 t r col ht h, meets_dotLoop A B hA hB r col c _⟩⟩

/-- The placement by rows of `m × p` cells: thread `t < m p` at row `t / p` and column `t % p`,
the other threads at none. -/
def byRows (m p : Nat) (t : Nat) : Option (Fin m × Fin p) :=
  if h : t < m * p then
    some (⟨t / p, Nat.div_lt_of_lt_mul (by rwa [Nat.mul_comm] at h)⟩,
      ⟨t % p, Nat.mod_lt _ (Nat.pos_of_ne_zero fun e => by simp [e] at h)⟩)
  else none

/-- No two threads of `byRows m p` are at one cell, for all `m` and `p`. -/
theorem byRows_inj (m p : Nat) (t t' : Nat) (x : Fin m × Fin p) (h : byRows m p t = some x)
    (h' : byRows m p t' = some x) : t = t' := by
  unfold byRows at h h'
  split at h <;> split at h' <;> simp only [Option.some.injEq, reduceCtorEq] at h h'
  rw [← h'] at h
  simp only [Prod.mk.injEq, Fin.mk.injEq] at h
  rw [← Nat.div_add_mod t p, ← Nat.div_add_mod t' p, h.1, h.2]

/-- The tile oracle of a kernel whose thread `t` takes at term `j` of its dot loop the oracle
numbers `o t j` (the `fmul`'s, the `fadd`'s): at a site of thread `t` and term `j`, `(o t j).1`
for `fmul`, `(o t j).2` for `fadd`, and 0 for another operation; the site's cell does not
enter. -/
def pairOracle (o : Nat → Nat → Nat × Nat) (s : Site) : Nat :=
  match s.op with
  | .fmul => (o s.thread s.idx).1
  | .fadd => (o s.thread s.idx).2
  | _ => 0

/-- At `pairOracle o`, the dot loop's oracle numbers of thread `t` are `o t`, at every cell, for
every `o` and `t`. -/
theorem dotOracle_pair (o : Nat → Nat → Nat × Nat) (t cell : Nat) :
    dotOracle (pairOracle o) t cell = o t :=
  funext fun _ => rfl

end MojoProof.Tile
