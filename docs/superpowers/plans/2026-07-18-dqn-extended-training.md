# DQN PoC Extended Training Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Train the DQN PoC 5× longer (800 → 4000 episodes) and, if the greedy-eval
mean return is ≥ the published 0.581, make it the headline result in every published
location (report, EN doc, VN doc, EVIDENCE.md).

**Architecture:** One research script (`src/backend/ml/research/dqn_poc.py`) is the
single source of truth: it trains, evaluates, and *generates* the markdown report.
This plan first makes the report generation pure and fully computed (no hardcoded
measured numbers), then bumps the episode count, runs the experiment behind a
decision gate, and propagates measured numbers to the three publication documents.

**Tech Stack:** Python 3.13 venv at `src/backend/ml/.venv`, PyTorch, matplotlib (Agg), pytest.

**Spec:** `docs/superpowers/specs/2026-07-18-dqn-extended-training-design.md`

**Conventions:** All ml commands run from `src/backend/ml/`. Research scripts run as
modules (`.venv/Scripts/python -m research.dqn_poc`) — plain path invocation cannot
import `lingoroad_ml`. Commit with explicit paths, never `git add -A`. Never commit
`ml/data/`, `ml/checkpoints/`, `.claude/`. Reports ARE committed (task-7/15 precedent).
Historical documents (`docs/superpowers/specs+plans/2026-07-1{5,7}-*`, ledger entries)
keep the old numbers — they are records; do NOT "fix" them.

---

### Task 1: Pure, fully-computed report generation (TDD)

The generated `dqn_poc.md` currently hardcodes the measured gaps
("+0.048 (+9%)…") and the epsilon-decay length ("over 400"). Extract report
generation into a pure `report_lines(results)` function that computes both, so a
re-run can never leave stale numbers.

**Files:**
- Modify: `src/backend/ml/research/dqn_poc.py`
- Create: `src/backend/ml/tests/test_dqn_poc_report.py`

- [ ] **Step 1: Write the failing test**

Create `src/backend/ml/tests/test_dqn_poc_report.py`:

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
    text = "\n".join(report_lines(_results()))
    assert "| DQN | 0.581 | 60.0 | 0.00 | 82.3 | 0.071 |" in text
    assert "| Random | 0.197 | 60.0 | 0.00 | 0.0 | 0.002 |" in text


def test_gap_sentence_computed_not_hardcoded():
    text = "\n".join(report_lines(_results()))
    # 0.581-0.533=+0.048 (+9% of greedy); 0.636-0.533=+0.103 (+19%)
    assert "+0.048 (+9%)" in text
    assert "+0.103 (+19%)" in text
    # And with a different DQN return the sentence must follow.
    r = _results()
    r["DQN"][0]["return"] = 0.611
    text = "\n".join(report_lines(r))
    assert "+0.078 (+15%)" in text
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `src/backend/ml/`): `.venv/Scripts/python -m pytest tests/test_dqn_poc_report.py -v`
Expected: FAIL — `ImportError: cannot import name 'report_lines'`

- [ ] **Step 3: Implement `report_lines` in `research/dqn_poc.py`**

Add a module constant right below `EPISODES` (keep `EPISODES = 800` for now —
Task 2 bumps it):

```python
EPISODES = 800
EPS_DECAY_EPISODES = 400
N_SKILLS = 5
```

In `train_dqn()`, replace the epsilon line:

```python
        eps = max(0.05, 1.0 - ep / EPS_DECAY_EPISODES)
```

Add `report_lines()` above `main()` — this is the whole markdown body that
`main()` currently builds inline (the `lines = [...]`, the table `for` loop, and
the `lines += [...]` notes block), moved verbatim EXCEPT: the protocol line
interpolates `EPS_DECAY_EPISODES`, and the final bullet's gap numbers are
computed:

```python
def report_lines(results):
    """Markdown report body. Every measured number comes from `results`."""
    lines = [
        "# DQN PoC — four-policy comparison on ToyLearnerEnv",
        "",
        "Protocol: `docs/learning-path-optimization.md` §7 — 100 eval episodes, seed 123,",
        f"identical dynamics for all policies. DQN: {EPISODES} training episodes,",
        f"eps 1.0 -> 0.05 over {EPS_DECAY_EPISODES}. DP: k=11 grid (11^5 = 161,051 states),",
        "multilinear-interpolated successors (Kushner-Dupuis), goal bonus on arrival",
        "in the goal set, gamma = 0.98, tol 1e-6 (offline cost includes building the",
        "transition table).",
        "",
        "| Policy | Mean return | Mean episode length | Goal-reach rate | Offline cost (s) | Latency (ms/decision) |",
        "|---|---|---|---|---|---|",
    ]
    for name, (m, cost) in results.items():
        lines.append(f"| {name} | {m['return']:.3f} | {m['length']:.1f} | "
                     f"{m['goal_rate']:.2f} | {cost:.1f} | {m['latency_ms']:.3f} |")
    greedy = results["Greedy (fixed order)"][0]["return"]
    dqn_gap = results["DQN"][0]["return"] - greedy
    dp_gap = results["DP (value iteration)"][0]["return"] - greedy
    lines += [
        "",
        "Notes:",
        "- Episode length is censored at the 60-step cap; goal-reach rate is the share",
        "  of episodes ending with all skills >= 0.8 within the cap.",
        "- **The goal is unreachable within the cap at n=5 for any policy** (all",
        "  goal-reach rates 0.00, all lengths 60): total decay is 5 x 0.005 = 0.025/step",
        "  while practice gains shrink as mastery rises (0.15 x (1-m)), so raising all",
        "  five skills to >= 0.8 *simultaneously* needs ~80-90 steps. The +1 bonus never",
        "  fires; the comparison is decided by mastery-growth efficiency. (At n=3 the",
        "  goal is comfortably reachable — see tests/test_rl.py.) This also explains why",
        "  greedy's front-to-back rule is not near-optimal here: it keeps re-practicing",
        "  early skills at diminishing returns instead of maximising marginal gain.",
        "- DP is exact for the *discretized* (k=11, interpolated) model, not the",
        "  continuous env: discretization plus the ignored 60-step horizon make it an",
        "  upper-bound approximation. Nearest-grid rounding (the original protocol",
        "  wording) is degenerate at k=11 — the goal is unreachable in the rounded",
        "  chain — hence the interpolated model; see lingoroad_ml/rl/dp.py.",
        "- The a-priori expectation (task file) that a fixed-order heuristic is",
        "  near-optimal on a 5-skill chain did not survive measurement under forgetting:",
        f"  DQN beats greedy by {dqn_gap:+.3f} ({dqn_gap / greedy:+.0%}) and DP by",
        f"  {dp_gap:+.3f} ({dp_gap / greedy:+.0%}) mean return. The gaps quantify what",
        "  optimising marginal gain buys over a fixed order — the 'do chinh xac'",
        "  (accuracy) column of doc §6, measured.",
    ]
    return lines
```

In `main()`, delete the inline `lines = [...]` block, the table `for` loop, and
the `lines += [...]` block, and replace the write with:

```python
    (out / "dqn_poc.md").write_text("\n".join(report_lines(results)) + "\n",
                                    encoding="utf-8")
```

(The plotting code and the final `print` loop stay exactly as they are.)

- [ ] **Step 4: Run test to verify it passes**

Run: `.venv/Scripts/python -m pytest tests/test_dqn_poc_report.py -v`
Expected: 2 PASS

- [ ] **Step 5: Run the full ml suite**

Run: `.venv/Scripts/python -m pytest`
Expected: 46 passed (44 existing + 2 new), no failures.

- [ ] **Step 6: Commit**

```bash
git add src/backend/ml/research/dqn_poc.py src/backend/ml/tests/test_dqn_poc_report.py
git commit -m "refactor(ml): dqn_poc report generation pure + computed gap sentence"
```

---

### Task 2: Extend training to 4000 episodes

**Files:**
- Modify: `src/backend/ml/research/dqn_poc.py` (one line)

- [ ] **Step 1: Bump the constant**

```python
EPISODES = 4000
```

(`EPS_DECAY_EPISODES` stays 400 — the user-approved schedule: first 800 episodes
exactly replicate the published run.)

- [ ] **Step 2: Quick suite check** (tests must not depend on `EPISODES`)

Run: `.venv/Scripts/python -m pytest`
Expected: 46 passed.

- [ ] **Step 3: Commit**

```bash
git add src/backend/ml/research/dqn_poc.py
git commit -m "feat(ml): extend DQN PoC training to 4000 episodes"
```

---

### Task 3: Run the experiment — DECISION GATE

**Files:**
- Regenerates: `src/backend/ml/reports/dqn_poc.md`, `src/backend/ml/reports/dqn_poc.png` (working tree only; committing is Task 4's call)

- [ ] **Step 1: Run the experiment**

Run (from `src/backend/ml/`): `.venv/Scripts/python -m research.dqn_poc`
Expected duration ~7–8 min (DQN ~6.5 min at ~77s/800 eps, DP ~55s, eval seconds).
Use a 10-minute timeout or a background run — do NOT let a 2-minute default
timeout kill it. Expected output: `ep N: ...` progress lines every 100 episodes,
then `DQN trained in ...s`, `DP solved in ...s (156 sweeps)`, then four summary
lines. DP/greedy/random returns must come out 0.636 / 0.533 / 0.197 exactly
(same seeds); only the DQN row is news.

- [ ] **Step 2: Record the four summary lines verbatim** — Task 4 and 5 substitute
these measured numbers into the docs. Also note the new DQN and DP offline-cost
seconds.

- [ ] **Step 3: Gate on the DQN mean return**

- **DQN return ≥ 0.581** → proceed to Task 4. (Marginal improvement still
  replaces, per user decision.)
- **DQN return < 0.581** → do the fallback, once (git paths below are from the
  repo root):
  1. `git restore src/backend/ml/reports/dqn_poc.md src/backend/ml/reports/dqn_poc.png` (drop the losing artifacts)
  2. In `research/dqn_poc.py` set `EPS_DECAY_EPISODES = EPISODES // 2` (= 2000)
  3. Re-run Step 1–2.
  4. Fallback ≥ 0.581 → commit the schedule change
     (`git add src/backend/ml/research/dqn_poc.py && git commit -m "feat(ml): slower eps decay for 4000-episode run"`),
     proceed to Task 4 — and in Task 4/5 doc edits write the schedule as
     "ε 1.0 → 0.05 over 2000" instead of "over 400".
  5. Fallback also < 0.581 → NEGATIVE RESULT path: restore artifacts and the
     script (`git restore src/backend/ml/reports/dqn_poc.md src/backend/ml/reports/dqn_poc.png src/backend/ml/research/dqn_poc.py`),
     then revert Task 2's commit (`git revert --no-edit <task-2 sha>`) so the
     committed script still reproduces the committed report. Skip Task 4
     entirely. In Task 5, write the ledger entry documenting both measured
     returns as the finding. Done.

---

### Task 4: Commit artifacts + propagate measured numbers to the three publication docs

Only reached if the gate passed. Every `⟨…⟩` below is a measured value copied
from Task 3's output / the regenerated `ml/reports/dqn_poc.md` — copy, never
retype from memory, and take the gap sentence numbers from the generated report
(it computes them now).

**Files:**
- Commit: `src/backend/ml/reports/dqn_poc.md`, `src/backend/ml/reports/dqn_poc.png`
- Modify: `docs/learning-path-optimization.md`
- Modify: `docs/bao-cao-mang-3-vn.md`
- Modify: `src/backend/ml/reports/EVIDENCE.md`

- [ ] **Step 1: Sanity-read the regenerated report**

Read `ml/reports/dqn_poc.md`: header says "4000 training episodes"; table ordering
DP > DQN > greedy > random; gap sentence numbers consistent with the table.
View `ml/reports/dqn_poc.png`: curve extends to ~4000, first ~800 episodes match
the old curve's shape.

- [ ] **Step 2: Commit the artifacts**

```bash
git add src/backend/ml/reports/dqn_poc.md src/backend/ml/reports/dqn_poc.png
git commit -m "feat(ml): 4000-episode DQN PoC results"
```

- [ ] **Step 3: Update `docs/learning-path-optimization.md`** (four edits)

(a) §6.1 table (lines ~199–204): replace all four data rows with the new run's
values (DP/greedy/random returns unchanged; their cost/latency columns take the
new measured values):

```markdown
| DP (value iteration) | 0.636 | 60.0 | 0.00 | ⟨DP cost⟩ | ⟨DP latency⟩ |
| DQN | ⟨DQN return⟩ | 60.0 | 0.00 | ⟨DQN cost⟩ | ⟨DQN latency⟩ |
| Greedy (fixed order) | 0.533 | 60.0 | 0.00 | 0.0 | ⟨greedy latency⟩ |
| Random | 0.197 | 60.0 | 0.00 | 0.0 | ⟨random latency⟩ |
```

(b) §6.1 finding 2 (line ~216): replace "DQN beats it by +9% and DP by +19% mean
return" with the new percentages from the generated report's gap sentence.

(c) §7 intro (line ~225): "Executed by task 15 (2026-07-17); results in §6.1 and"
→ "Executed by task 15 (2026-07-17), DQN training extended to 4000 episodes
(2026-07-18); results in §6.1 and".

(d) §7 policy 4 (line ~253): "4. **DQN** — as trained by task 15 (800 episodes,
ε 1.0 → 0.05)." → "4. **DQN** — as trained by task 15, extended 2026-07-18
(4000 episodes, ε 1.0 → 0.05 over 400)." — and §7 outcome (line ~263):
"(§6.1: 0.636 > 0.581 > 0.533 > 0.197)" → "(§6.1: 0.636 > ⟨DQN return⟩ > 0.533 > 0.197)".
If ⟨DQN return⟩ ≥ 0.636 the "expected ordering DP ≥ DQN" claim changes character —
if that happens, flag it in the session notes and adjust the sentence to say the
ordering became DP ≈/≤ DQN with a one-line explanation, don't silently keep "held exactly".

- [ ] **Step 4: Update `docs/bao-cao-mang-3-vn.md`** (mirror edits, Vietnamese)

(a) §A.6.1 table (lines ~121–124): same four rows as Step 3(a) (policy names stay
Vietnamese: "Greedy (thứ tự cố định)", "Ngẫu nhiên").

(b) §A.6.1 phát hiện 2 (line ~129): "DQN vượt nó +9% và DP vượt +19% return
trung bình" → new percentages.

(c) §A.7 intro (line ~135): "Đã thực hiện ngày 17/07/2026;" → "Đã thực hiện ngày
17/07/2026, huấn luyện DQN kéo dài lên 4000 episode ngày 18/07/2026;".

(d) §A.7 chính sách 4 (line ~144): "4. **DQN** — như task 15 huấn luyện (800
episode, ε 1.0 → 0.05)." → "4. **DQN** — như task 15 huấn luyện, kéo dài ngày
18/07/2026 (4000 episode, ε 1.0 → 0.05 trong 400 episode đầu)." — and §A.7 kết
quả (line ~149): "(A.6.1: 0.636 > 0.581 > 0.533 > 0.197)" → new DQN value, same
ordering caveat as Step 3(d).

- [ ] **Step 5: Update `src/backend/ml/reports/EVIDENCE.md`** (row 7, line ~11)

"DQN PoC (100 eps, seed 123): DP 0.636 > DQN 0.581 > greedy 0.533 > random 0.197"
→ "DQN PoC (100 eps, seed 123; DQN trained 4000 eps): DP 0.636 > DQN ⟨DQN return⟩ >
greedy 0.533 > random 0.197" (adjust ordering if the DP ≥ DQN caveat fired).

- [ ] **Step 6: Commit the doc updates**

```bash
git add docs/learning-path-optimization.md docs/bao-cao-mang-3-vn.md src/backend/ml/reports/EVIDENCE.md
git commit -m "docs: 4000-episode DQN result in §6.1/A.6.1 tables + EVIDENCE"
```

---

### Task 5: Final verification + ledger

**Files:**
- Modify: `src/backend/.superpowers/sdd/progress.md`

- [ ] **Step 1: Full ml suite one last time**

Run (from `src/backend/ml/`): `.venv/Scripts/python -m pytest`
Expected: 46 passed. (.NET untouched by this work — no need to run it.)

- [ ] **Step 2: Stale-number grep**

Run (from repo root): `grep -rn "0\.581\|+9%\|800 episodes\|800 training" docs/ src/backend/ml/reports/ README.md`
Expected: hits ONLY in historical records — `docs/superpowers/specs/2026-07-17-*`,
`docs/superpowers/plans/2026-07-1{5,7}-*`, and the 2026-07-18 extended-training
spec/plan (which quote 0.581 as the old baseline). Any hit in
`docs/learning-path-optimization.md`, `docs/bao-cao-mang-3-vn.md`, or
`src/backend/ml/reports/` (other than EVIDENCE row context showing 0.533/0.197)
is a straggler — fix it before proceeding. On the NEGATIVE RESULT path this grep
must instead confirm the published docs still say 0.581 consistently.

- [ ] **Step 3: Ledger entry**

Append a session entry to `src/backend/.superpowers/sdd/progress.md` (new entry
above the previous ones, matching house style): what was run (4000 eps, schedule),
measured DQN return and gaps, decision taken (replaced / fallback used / negative
result kept 800), commit shas, test count (46), environment note.

- [ ] **Step 4: Commit**

```bash
git add src/backend/.superpowers/sdd/progress.md
git commit -m "docs(sdd): session ledger — DQN PoC extended training"
```
