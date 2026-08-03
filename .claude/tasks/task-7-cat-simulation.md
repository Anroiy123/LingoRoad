# Task 7: CAT Simulation Experiment — report evidence for Placement Test

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-5 (irt/cat modules), task-4 (itemgen; real bank optional).

**Files:**
- Create: `ml/questgraph_ml/cefr.py`, `ml/questgraph_ml/simulation.py`, `ml/tests/test_simulation.py`, `ml/research/cat_simulation.py`
- Modify: `ml/requirements.txt` (add `matplotlib>=3.8`, `pandas>=2.2`)

**Interfaces:**
- Consumes: `prob_3pl`, `information`, `eap_estimate`, `select_next`, `seed_irt_params` (tasks 4–5).
- Produces: `cefr_from_theta(theta) -> str` (same bins as C# `CefrMap`); `simulate_examinee(theta_true, bank, rng, min_items=8, max_items=30, se_stop=0.35) -> SimResult(theta_hat, se, n_items)`; report artifacts `ml/reports/cat_simulation.png` + `ml/reports/cat_simulation.md`.

**Experiment design (goes in the practicum report):** N=1000 simulated examinees with θ_true ~ N(0,1). Each takes (a) the adaptive CAT and (b) a fixed random 30-item test, both scored with EAP. Ground truth CEFR = bin(θ_true). Metrics: exact CEFR classification accuracy, adjacent (±1 level) accuracy, RMSE(θ̂), mean/median items used by CAT. Deliverables: metrics table + two plots (items-used histogram; accuracy vs. fixed-test length curve for lengths 5,10,15,20,30,50).

- [x] **Step 1: Write failing tests**

`ml/tests/test_simulation.py`:

```python
import numpy as np
from questgraph_ml.cefr import cefr_from_theta
from questgraph_ml.simulation import make_synthetic_bank, simulate_examinee

def test_cefr_bins_match_dotnet():
    assert cefr_from_theta(-2.5) == "A1"
    assert cefr_from_theta(-1.0) == "A2"
    assert cefr_from_theta(0.0) == "B1"
    assert cefr_from_theta(1.0) == "B2"
    assert cefr_from_theta(2.0) == "C1"
    assert cefr_from_theta(3.0) == "C2"

def test_simulation_respects_stop_rule():
    rng = np.random.default_rng(1)
    bank = make_synthetic_bank(500, rng)
    r = simulate_examinee(theta_true=0.3, bank=bank, rng=rng)
    assert 8 <= r.n_items <= 30
    assert np.isfinite(r.theta_hat) and 0 < r.se < 1.0

def test_estimates_track_true_theta_on_average():
    rng = np.random.default_rng(2)
    bank = make_synthetic_bank(500, rng)
    errs = [simulate_examinee(t, bank, rng).theta_hat - t
            for t in np.linspace(-2, 2, 21)]
    assert abs(float(np.mean(errs))) < 0.25  # near-unbiased
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_simulation.py -v` → FAIL.

- [x] **Step 2: Implement, verify pass**

`ml/questgraph_ml/cefr.py`:

```python
"""Theta -> CEFR. MUST stay in sync with QuestGraph/Domain/CefrMap.cs."""
def cefr_from_theta(theta: float) -> str:
    if theta < -1.5: return "A1"
    if theta < -0.5: return "A2"
    if theta < 0.5:  return "B1"
    if theta < 1.5:  return "B2"
    if theta < 2.25: return "C1"
    return "C2"
```

`ml/questgraph_ml/simulation.py`:

```python
from dataclasses import dataclass
import numpy as np
from questgraph_ml.irt import prob_3pl, eap_estimate
from questgraph_ml.cat import select_next
from questgraph_ml.itemgen import seed_irt_params

LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]

@dataclass
class SimResult:
    theta_hat: float
    se: float
    n_items: int

def make_synthetic_bank(n: int, rng: np.random.Generator) -> list[tuple]:
    """Returns [(item_id, a, b, c)] spread evenly across CEFR levels."""
    return [(i, *seed_irt_params(LEVELS[i % 6], 4, rng)) for i in range(n)]

def simulate_examinee(theta_true: float, bank: list[tuple], rng: np.random.Generator,
                      min_items: int = 8, max_items: int = 30,
                      se_stop: float = 0.35) -> SimResult:
    remaining = dict((it[0], it) for it in bank)
    history: list[tuple] = []
    theta, se = 0.0, 1.0
    while True:
        next_id = select_next(theta, list(remaining.values()))
        if next_id is None:
            break
        _, a, b, c = remaining.pop(next_id)
        correct = bool(rng.random() < prob_3pl(theta_true, a, b, c))
        history.append((a, b, c, correct))
        theta, se = eap_estimate(history)
        n = len(history)
        if n >= max_items or (n >= min_items and se < se_stop):
            break
    return SimResult(theta, se, len(history))

def fixed_test(theta_true: float, bank: list[tuple], length: int,
               rng: np.random.Generator) -> float:
    idx = rng.choice(len(bank), size=min(length, len(bank)), replace=False)
    history = []
    for i in idx:
        _, a, b, c = bank[i]
        history.append((a, b, c, bool(rng.random() < prob_3pl(theta_true, a, b, c))))
    theta, _ = eap_estimate(history)
    return theta
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [x] **Step 3: Write the experiment script**

`ml/research/cat_simulation.py`:

```python
"""CAT vs fixed-test simulation study. Outputs ml/reports/cat_simulation.{png,md}.
Usage: python ml/research/cat_simulation.py [--n 1000] [--items ml/data/items.json]
"""
import argparse, json
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from questgraph_ml.cefr import cefr_from_theta
from questgraph_ml.simulation import make_synthetic_bank, simulate_examinee, fixed_test

ROOT = Path(__file__).parents[2]

def load_bank(path: str | None, rng) -> list[tuple]:
    if path and Path(path).exists():
        items = json.loads(Path(path).read_text(encoding="utf-8"))
        return [(i, it["a"], it["b"], it["c"]) for i, it in enumerate(items)]
    print("items.json not found - using synthetic 500-item bank")
    return make_synthetic_bank(500, rng)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=1000)
    ap.add_argument("--items", default=str(ROOT / "ml/data/items.json"))
    args = ap.parse_args()

    rng = np.random.default_rng(0)
    bank = load_bank(args.items, rng)
    thetas = rng.standard_normal(args.n)

    cat = [simulate_examinee(t, bank, rng) for t in thetas]
    true_cefr = [cefr_from_theta(t) for t in thetas]
    cat_cefr = [cefr_from_theta(r.theta_hat) for r in cat]

    lengths = [5, 10, 15, 20, 30, 50]
    fixed_acc = {}
    for L in lengths:
        est = [fixed_test(t, bank, L, rng) for t in thetas]
        fixed_acc[L] = float(np.mean([cefr_from_theta(e) == c
                                      for e, c in zip(est, true_cefr)]))

    levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
    idx = {l: i for i, l in enumerate(levels)}
    exact = float(np.mean([p == t for p, t in zip(cat_cefr, true_cefr)]))
    adjacent = float(np.mean([abs(idx[p] - idx[t]) <= 1
                              for p, t in zip(cat_cefr, true_cefr)]))
    rmse = float(np.sqrt(np.mean([(r.theta_hat - t) ** 2 for r, t in zip(cat, thetas)])))
    n_items = np.array([r.n_items for r in cat])

    out = ROOT / "ml/reports"; out.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    axes[0].hist(n_items, bins=range(8, 32))
    axes[0].set(title="CAT items used", xlabel="items", ylabel="examinees")
    axes[1].plot(lengths, [fixed_acc[L] for L in lengths], "o-", label="fixed test")
    axes[1].axhline(exact, color="tab:red", ls="--",
                    label=f"CAT (mean {n_items.mean():.1f} items)")
    axes[1].set(title="Exact CEFR accuracy vs test length", xlabel="test length",
                ylabel="accuracy"); axes[1].legend()
    fig.tight_layout(); fig.savefig(out / "cat_simulation.png", dpi=150)

    md = out / "cat_simulation.md"
    md.write_text(f"""# CAT Simulation Results (N={args.n}, bank={len(bank)} items)

| Metric | CAT | Fixed-30 |
|---|---|---|
| Exact CEFR accuracy | {exact:.3f} | {fixed_acc[30]:.3f} |
| Adjacent (±1) accuracy | {adjacent:.3f} | — |
| RMSE(θ) | {rmse:.3f} | — |
| Mean items | {n_items.mean():.1f} | 30 |
| Median items | {np.median(n_items):.0f} | 30 |
""", encoding="utf-8")
    print(md.read_text(encoding="utf-8"))

if __name__ == "__main__":
    main()
```

- [x] **Step 4: Run the experiment**

```powershell
$env:PYTHONPATH = "ml"
ml/.venv/Scripts/pip install -r ml/requirements.txt
ml/.venv/Scripts/python ml/research/cat_simulation.py --n 1000
```

Expected: table printed; CAT exact accuracy comparable to Fixed-30 while using ~12–20 items on average (this is the report's headline claim — record whatever the actual numbers are; do not overstate). Note in the report: the >88%-vs-Cambridge figure from the original requirement is replaced by this simulation study (requirement.md note V-3).

- [x] **Step 5: Commit**

```powershell
git add ml/
git commit -m "feat: CAT vs fixed-test simulation study with report artifacts"
```
