# DQN PoC Checkpoint Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add validation-based checkpoint selection to the DQN PoC training loop,
retry the 4000-episode run, and replace the published result iff the selected
network's test-eval mean return ≥ 0.581.

**Architecture:** All changes live in the research script
(`src/backend/ml/research/dqn_poc.py`) — `DQNAgent` stays untouched. `train_dqn()`
gains a periodic greedy validation eval (seed 42, never the test seed 123) and
returns the best-validation network; `report_lines()` documents the selection in
the generated report. The decision gate and doc propagation mirror the 2026-07-18
extended-training plan.

**Tech Stack:** Python 3.13 venv at `src/backend/ml/.venv`, PyTorch, matplotlib (Agg), pytest.

**Spec:** `docs/superpowers/specs/2026-07-19-dqn-checkpoint-selection-design.md`

**Conventions:** All ml commands run from `src/backend/ml/`. Research scripts run
as modules (`.venv/Scripts/python -m research.dqn_poc`). Commit with explicit
paths, never `git add -A`. Never commit `ml/data/`, `ml/checkpoints/`, `.claude/`.
Reports ARE committed. Historical documents under `docs/superpowers/` and old
ledger entries keep old numbers — do NOT "fix" them. Git commands run from the
repo root `C:\Projects\LingoRoad`.

**Current baseline (context for the executor):** published DQN result is 0.581
(800 episodes, no selection). Yesterday's 4000-episode runs WITHOUT selection
scored 0.559 (schedule unchanged) and 0.449 (slow decay) — both failed the gate;
commits 9261fb2/e16900f added and reverted EPISODES=4000. The script currently
has `EPISODES = 800`, `EPS_DECAY_EPISODES = 400`, a pure `report_lines(results)`,
and `train_dqn()` returning `(agent, curve)`.

---

### Task 1: Checkpoint selection + report text (TDD)

**Files:**
- Modify: `src/backend/ml/research/dqn_poc.py`
- Modify: `src/backend/ml/tests/test_dqn_poc_report.py` (report_lines gains a `best_ep` parameter)
- Create: `src/backend/ml/tests/test_dqn_checkpoint.py`

- [ ] **Step 1: Write the failing checkpoint test**

Create `src/backend/ml/tests/test_dqn_checkpoint.py`:

```python
"""Checkpoint selection must return the best-validation network, deterministically."""
from research.dqn_poc import VAL_EPISODES, VAL_SEED, evaluate, train_dqn


def test_returned_agent_reproduces_best_validation_score():
    agent, curve, best_ep, best_val = train_dqn(episodes=25, checkpoint_every=10)
    assert len(curve) == 25
    # Periodic evals fire after episodes 10 and 20; 25 % 10 != 0 adds a final eval at 25.
    assert best_ep in (10, 20, 25)
    # Deterministic env + greedy policy: re-evaluating the returned agent on the
    # validation seed must reproduce the best checkpoint's score exactly —
    # proving the loaded weights ARE the best snapshot.
    val = evaluate(lambda s: agent.act(s, eps=0.0),
                   episodes=VAL_EPISODES, seed=VAL_SEED)["return"]
    assert abs(val - best_val) < 1e-9
```

- [ ] **Step 2: Run it to verify it fails**

Run (from `src/backend/ml/`): `.venv/Scripts/python -m pytest tests/test_dqn_checkpoint.py -v`
Expected: FAIL — `ImportError: cannot import name 'VAL_EPISODES'`

- [ ] **Step 3: Update the report tests for the new `best_ep` parameter**

Replace the full contents of `src/backend/ml/tests/test_dqn_poc_report.py` with:

```python
"""report_lines() must compute every measured number it prints."""
from research.dqn_poc import report_lines


def _results():
    def m(ret, latency):
        return {"return": ret, "length": 60.0, "goal_rate": 0.0, "latency_ms": latency}
    # (metrics, offline_cost) per policy — the task-15 published numbers.
    return {
        "DP (value iteration)": (m(0.636, 0.149), 50.2),
        "DQN": (m(0.581, 0.071), 82.3),
        "Greedy (fixed order)": (m(0.533, 0.002), 0.0),
        "Random": (m(0.197, 0.002), 0.0),
    }


def test_table_rows_come_from_results():
    text = "\n".join(report_lines(_results(), best_ep=3210))
    assert "| DQN | 0.581 | 60.0 | 0.00 | 82.3 | 0.071 |" in text
    assert "| Random | 0.197 | 60.0 | 0.00 | 0.0 | 0.002 |" in text
    assert "selected at episode 3210" in text


def test_gap_sentence_computed_not_hardcoded():
    text = "\n".join(report_lines(_results(), best_ep=3210))
    # 0.581-0.533=+0.048 (+9% of greedy); 0.636-0.533=+0.103 (+19%)
    assert "+0.048 (+9%)" in text
    assert "+0.103 (+19%)" in text
    # And with a different DQN return the sentence must follow.
    r = _results()
    r["DQN"][0]["return"] = 0.611
    text = "\n".join(report_lines(r, best_ep=3210))
    assert "+0.078 (+15%)" in text
```

- [ ] **Step 4: Implement in `research/dqn_poc.py`**

(a) Add `import copy` as the first import (above `import time`).

(b) Constants block becomes (EPISODES stays 800 — Task 2 bumps it):

```python
EPISODES = 800
EPS_DECAY_EPISODES = 400
CHECKPOINT_EVERY = 100
VAL_SEED = 42       # validation env for selection — NEVER the test seed 123
VAL_EPISODES = 20
N_SKILLS = 5
```

(c) Replace the whole `train_dqn()` with (note `evaluate()` is already defined
above it in the file):

```python
def train_dqn(episodes=EPISODES, checkpoint_every=CHECKPOINT_EVERY):
    env = ToyLearnerEnv(n_skills=N_SKILLS, seed=0)
    agent = DQNAgent(state_dim=N_SKILLS, n_actions=N_SKILLS, seed=0)
    curve = []
    best_val, best_ep, best_state = float("-inf"), 0, None

    def validate(after_ep):
        nonlocal best_val, best_ep, best_state
        val = evaluate(lambda s: agent.act(s, eps=0.0),
                       episodes=VAL_EPISODES, seed=VAL_SEED)["return"]
        if val > best_val:
            best_val, best_ep = val, after_ep
            best_state = copy.deepcopy(agent.q.state_dict())

    for ep in range(episodes):
        eps = max(0.05, 1.0 - ep / EPS_DECAY_EPISODES)
        s, total, done = env.reset(), 0.0, False
        while not done:
            a = agent.act(s, eps)
            s2, r, done = env.step(a)
            agent.remember(s, a, r, s2, done)
            agent.train_step()
            s, total = s2, total + r
        curve.append(total)
        if ep % 100 == 0:
            print(f"ep {ep}: mean return (last 100) {np.mean(curve[-100:]):.3f}", flush=True)
        if (ep + 1) % checkpoint_every == 0:
            validate(ep + 1)
    if episodes % checkpoint_every:
        validate(episodes)
    agent.q.load_state_dict(best_state)
    agent.target.load_state_dict(best_state)
    return agent, curve, best_ep, best_val
```

(d) `report_lines` signature becomes `report_lines(results, best_ep)` and its
protocol block (the first list, before the table header) becomes:

```python
    lines = [
        "# DQN PoC — four-policy comparison on ToyLearnerEnv",
        "",
        "Protocol: `docs/learning-path-optimization.md` §7 — 100 eval episodes, seed 123,",
        f"identical dynamics for all policies. DQN: {EPISODES} training episodes,",
        f"eps 1.0 -> 0.05 over {EPS_DECAY_EPISODES}; checkpoint selection — greedy eval",
        f"({VAL_EPISODES} episodes, validation seed {VAL_SEED}, never the test seed) every",
        f"{CHECKPOINT_EVERY} episodes, best network kept (selected at episode {best_ep}).",
        "DP: k=11 grid (11^5 = 161,051 states),",
        "multilinear-interpolated successors (Kushner-Dupuis), goal bonus on arrival",
        "in the goal set, gamma = 0.98, tol 1e-6 (offline cost includes building the",
        "transition table).",
        "",
        "| Policy | Mean return | Mean episode length | Goal-reach rate | Offline cost (s) | Latency (ms/decision) |",
        "|---|---|---|---|---|---|",
    ]
```

(everything after the table header — the row loop, gap computation, and notes —
is unchanged).

(e) In `main()`:

```python
    agent, curve, best_ep, best_val = train_dqn()
    dqn_cost = time.perf_counter() - t0
    print(f"DQN trained in {dqn_cost:.1f}s (best checkpoint: ep {best_ep}, "
          f"val return {best_val:.3f})", flush=True)
```

and mark the selected episode on the plot — right after the
`plt.plot(smooth, label="DQN (smoothed)")` line add:

```python
    plt.axvline(best_ep, color="tab:red", ls=":", lw=1, label=f"selected ep {best_ep}")
```

and the report write becomes:

```python
    (out / "dqn_poc.md").write_text("\n".join(report_lines(results, best_ep)) + "\n",
                                    encoding="utf-8")
```

- [ ] **Step 5: Run the new test and the full suite**

Run: `.venv/Scripts/python -m pytest tests/test_dqn_checkpoint.py -v`
Expected: 1 PASS (takes ~10–30s — it really trains 25 episodes on CPU).
Run: `.venv/Scripts/python -m pytest`
Expected: 47 passed (46 + 1 new), no failures.

- [ ] **Step 6: Commit**

```bash
git add src/backend/ml/research/dqn_poc.py src/backend/ml/tests/test_dqn_poc_report.py src/backend/ml/tests/test_dqn_checkpoint.py
git commit -m "feat(ml): checkpoint selection in DQN PoC training (validation seed 42)"
```

---

### Task 2: Bump EPISODES to 4000

**Files:**
- Modify: `src/backend/ml/research/dqn_poc.py` (one line)

- [ ] **Step 1: `EPISODES = 4000`** (constants block; `EPS_DECAY_EPISODES` stays 400)

- [ ] **Step 2: Quick suite check**

Run: `.venv/Scripts/python -m pytest -q`
Expected: 47 passed (tests pass explicit `episodes=`, so the constant doesn't affect them).

- [ ] **Step 3: Commit**

```bash
git add src/backend/ml/research/dqn_poc.py
git commit -m "feat(ml): retry 4000-episode DQN PoC with checkpoint selection"
```

---

### Task 3: Run the experiment — DECISION GATE

- [ ] **Step 1: Run** (from `src/backend/ml/`, background or ≥10-min timeout — expect ~8–9 min):

`.venv/Scripts/python -m research.dqn_poc`

Expected output: `ep N: ...` lines, then
`DQN trained in ...s (best checkpoint: ep ⟨best_ep⟩, val return ⟨best_val⟩)`,
`DP solved in ...s (156 sweeps)`, then the four summary lines.
DP/greedy/random returns must be exactly 0.636 / 0.533 / 0.197. Note: the DQN
training trajectory will NOT match yesterday's 4000-episode run even before the
first checkpoint — the validation evals consume the shared `random` stream —
that is expected, not a bug.

- [ ] **Step 2: Record the summary lines + best_ep/best_val verbatim.**

- [ ] **Step 3: Gate on the DQN test-eval mean return**

- **≥ 0.581** → proceed to Task 4. If it also ≥ 0.636 (beats DP), the §7/A.7
  "expected ordering held" sentences must be rewritten honestly (DP is only an
  upper bound for the discretized model) — flag it, don't silently keep them.
- **< 0.581** → NEGATIVE RESULT path, no further fallback (spec decision 3):
  1. `git restore src/backend/ml/reports/dqn_poc.md src/backend/ml/reports/dqn_poc.png`
  2. Revert both commits so the committed script reproduces the committed report:
     `git revert --no-edit <task-2 sha> <task-1 sha>`
  3. Skip Task 4. In Task 5 the ledger documents the measured numbers; suite
     expectation returns to 46 passed.

---

### Task 4: Commit artifacts + propagate to EN/VN/EVIDENCE docs (gate passed only)

Every `⟨…⟩` is a measured value from Task 3 — copy from the run output / the
regenerated `ml/reports/dqn_poc.md` (its gap sentence is computed; take the
percentages from there, never retype from memory).

**Files:**
- Commit: `src/backend/ml/reports/dqn_poc.md`, `src/backend/ml/reports/dqn_poc.png`
- Modify: `docs/learning-path-optimization.md`, `docs/bao-cao-mang-3-vn.md`, `src/backend/ml/reports/EVIDENCE.md`

- [ ] **Step 1: Sanity-read the regenerated report** — header says "4000 training
episodes" and "selected at episode ⟨best_ep⟩"; table ordering sane; PNG shows the
red dotted selection line.

- [ ] **Step 2: Commit artifacts**

```bash
git add src/backend/ml/reports/dqn_poc.md src/backend/ml/reports/dqn_poc.png
git commit -m "feat(ml): checkpoint-selected 4000-episode DQN PoC results"
```

- [ ] **Step 3: `docs/learning-path-optimization.md`** (five edits)

(a) §6.1 table (~lines 199–204) — replace the four data rows:

```markdown
| DP (value iteration) | 0.636 | 60.0 | 0.00 | ⟨DP cost⟩ | ⟨DP latency⟩ |
| DQN | ⟨DQN return⟩ | 60.0 | 0.00 | ⟨DQN cost⟩ | ⟨DQN latency⟩ |
| Greedy (fixed order) | 0.533 | 60.0 | 0.00 | 0.0 | ⟨greedy latency⟩ |
| Random | 0.197 | 60.0 | 0.00 | 0.0 | ⟨random latency⟩ |
```

(b) §6.1 finding 2 (~line 216): "DQN beats it by +9% and DP by +19% mean return"
→ the new percentages from the generated report.

(c) §7 intro (~line 225): "Executed by task 15 (2026-07-17); results in §6.1 and"
→ "Executed by task 15 (2026-07-17); DQN retrained with checkpoint selection
(2026-07-19); results in §6.1 and".

(d) §7 policy 4 (~line 253):
"4. **DQN** — as trained by task 15 (800 episodes, ε 1.0 → 0.05)."
→ "4. **DQN** — retrained 2026-07-19: 4000 episodes, ε 1.0 → 0.05 over 400,
checkpoint selection (greedy 20-episode validation eval on seed 42 every 100
episodes, best network kept — selected at episode ⟨best_ep⟩)."

(e) §7 outcome (~line 263): "(§6.1: 0.636 > 0.581 > 0.533 > 0.197)"
→ "(§6.1: 0.636 > ⟨DQN return⟩ > 0.533 > 0.197)" (with the ordering-sentence
rewrite if ⟨DQN return⟩ ≥ 0.636, per Task 3).

- [ ] **Step 4: `docs/bao-cao-mang-3-vn.md`** (mirror, Vietnamese)

(a) A.6.1 table (~lines 121–124): same rows, names stay "Greedy (thứ tự cố
định)" / "Ngẫu nhiên".

(b) A.6.1 phát hiện 2 (~line 129): "DQN vượt nó +9% và DP vượt +19%" → new
percentages.

(c) A.7 intro (~line 135): "Đã thực hiện ngày 17/07/2026;" → "Đã thực hiện ngày
17/07/2026; DQN huấn luyện lại với checkpoint selection ngày 19/07/2026;".

(d) A.7 chính sách 4 (~line 144): "4. **DQN** — như task 15 huấn luyện (800
episode, ε 1.0 → 0.05)." → "4. **DQN** — huấn luyện lại ngày 19/07/2026: 4000
episode, ε 1.0 → 0.05 trong 400 episode đầu, checkpoint selection (đánh giá
greedy 20 episode trên seed kiểm định 42 mỗi 100 episode, giữ mạng tốt nhất —
chọn tại episode ⟨best_ep⟩)."

(e) A.7 kết quả (~line 149): "(A.6.1: 0.636 > 0.581 > 0.533 > 0.197)" → new DQN
value, same ordering caveat.

- [ ] **Step 5: `src/backend/ml/reports/EVIDENCE.md`** row 7 (~line 11):
"DQN PoC (100 eps, seed 123): DP 0.636 > DQN 0.581 > greedy 0.533 > random 0.197"
→ "DQN PoC (100 eps, seed 123; DQN 4000 eps + checkpoint selection): DP 0.636 >
DQN ⟨DQN return⟩ > greedy 0.533 > random 0.197" (reorder if DQN beat DP).

- [ ] **Step 6: Commit**

```bash
git add docs/learning-path-optimization.md docs/bao-cao-mang-3-vn.md src/backend/ml/reports/EVIDENCE.md
git commit -m "docs: checkpoint-selected DQN result in §6.1/A.6.1 + EVIDENCE"
```

---

### Task 5: Final verification + ledger

**Files:**
- Modify: `src/backend/.superpowers/sdd/progress.md`

- [ ] **Step 1: Full ml suite**

Run: `.venv/Scripts/python -m pytest -q`
Expected: 47 passed (46 on the negative path after the reverts).

- [ ] **Step 2: Stale-number grep** (from repo root):

`grep -rn "0\.581\|+9%\|800 episodes\|800 training" docs/learning-path-optimization.md docs/bao-cao-mang-3-vn.md src/backend/ml/reports/`

Gate passed: expect ZERO hits (0.533/0.197 context rows don't match these
patterns). Negative path: expect the same consistent 0.581/800 hits as before
the session. Either way, `docs/superpowers/` and ledger history are exempt.

- [ ] **Step 3: Ledger entry** — append a new session section at the top of
`src/backend/.superpowers/sdd/progress.md`: method (checkpoint selection,
validation seed 42, cadence), measured best_ep/best_val, test-eval return, gate
verdict, what was replaced (or the negative finding), commit shas, test count.

- [ ] **Step 4: Commit**

```bash
git add src/backend/.superpowers/sdd/progress.md
git commit -m "docs(sdd): session ledger — DQN checkpoint selection run"
```
