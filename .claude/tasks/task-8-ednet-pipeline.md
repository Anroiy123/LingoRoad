# Task 8: EdNet KT1 Pipeline — download, sample, features, splits

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-4 (ml env). Sprint 2.

**Files:**
- Create: `ml/questgraph_ml/kt/__init__.py`, `ml/questgraph_ml/kt/data.py`, `ml/tests/test_kt_data.py`, `ml/research/ednet_prepare.py`
- Modify: `ml/requirements.txt` (add `pandas>=2.2`, `pyarrow>=15`, `torch` — see Step 1)

**Interfaces:**
- Consumes: `ml/.venv`.
- Produces (used verbatim by task-9):
  - `build_interactions(kt1_dir, questions_csv, max_users) -> pd.DataFrame` with columns `user_id:int, q_idx:int, part:int, correct:int8, elapsed_ms:int64, lag_ms:int64` sorted by (user, timestamp); question vocabulary saved as `q_map` (dict question_id→q_idx).
  - `split_users(user_ids, seed=0) -> (train, val, test)` 80/10/10 by **user** (no leakage).
  - `KTSequenceDataset(df, seq_len=100)` — torch `Dataset` yielding dict of int64/float32 tensors: `q, part, correct, elapsed, lag, mask` each `[seq_len]`; elapsed = `clip(ms/1000, 0, 300)/300`, lag = `log1p(min(ms,86_400_000)/60_000)/log1p(1440)`; sequences windowed per user, left-padded, `mask=1` on real positions.
  - Artifact: `ml/data/ednet/interactions.parquet` + `ml/data/ednet/meta.json` (`{"n_questions":…, "n_parts":8, "q_map_file":…}`).

- [x] **Step 1: Install torch (CUDA) + deps**

```powershell
ml/.venv/Scripts/pip install torch --index-url https://download.pytorch.org/whl/cu121
ml/.venv/Scripts/pip install pandas pyarrow scikit-learn
```

Append to `ml/requirements.txt`: `pandas>=2.2`, `pyarrow>=15`, `scikit-learn>=1.4`, and a comment line `# torch: pip install torch --index-url https://download.pytorch.org/whl/cu121`.

Verify GPU: `ml/.venv/Scripts/python -c "import torch; print(torch.cuda.get_device_name(0))"` → `NVIDIA GeForce RTX 4060 ...`.

- [x] **Step 2: Download EdNet KT1 (manual, ~1.2 GB compressed)**

From https://github.com/riiid/ednet download **KT1** and **contents** archives; extract so that:

```
ml/data/ednet/KT1/u1.csv, u2.csv, ...       # per-user logs: timestamp,solving_id,question_id,user_answer,elapsed_time
ml/data/ednet/contents/questions.csv        # question_id,bundle_id,...,correct_answer,part,tags
```

(`ml/data/` is gitignored.)

- [x] **Step 3: Write failing pipeline tests (synthetic fixtures, no real data needed)**

`ml/tests/test_kt_data.py`:

```python
import pandas as pd
import numpy as np
from pathlib import Path
from questgraph_ml.kt.data import build_interactions, split_users, KTSequenceDataset

def make_fixture(tmp_path: Path):
    kt1 = tmp_path / "KT1"; kt1.mkdir()
    # user 1: two answers, second one wrong; timestamps 10s apart, 4s elapsed
    pd.DataFrame({
        "timestamp": [1_000_000, 1_010_000],
        "solving_id": [1, 2],
        "question_id": ["q1", "q2"],
        "user_answer": ["a", "c"],
        "elapsed_time": [4000, 3000],
    }).to_csv(kt1 / "u1.csv", index=False)
    pd.DataFrame({
        "question_id": ["q1", "q2"],
        "correct_answer": ["a", "b"],
        "part": [1, 5],
        "tags": ["1;2", "3"],
    }).to_csv(tmp_path / "questions.csv", index=False)
    return kt1, tmp_path / "questions.csv"

def test_build_interactions_correctness_and_lag(tmp_path):
    kt1, qcsv = make_fixture(tmp_path)
    df, q_map = build_interactions(kt1, qcsv, max_users=10)
    assert list(df["correct"]) == [1, 0]           # a==a, c!=b
    assert list(df["lag_ms"]) == [0, 6000]         # 10000 - 4000
    assert set(df["q_idx"]) == {q_map["q1"], q_map["q2"]}

def test_split_users_disjoint_and_deterministic():
    users = list(range(100))
    tr1, va1, te1 = split_users(users, seed=0)
    tr2, va2, te2 = split_users(users, seed=0)
    assert (tr1, va1, te1) == (tr2, va2, te2)
    assert set(tr1) | set(va1) | set(te1) == set(users)
    assert not (set(tr1) & set(va1)) and not (set(va1) & set(te1))
    assert len(tr1) == 80

def test_dataset_shapes_and_padding(tmp_path):
    kt1, qcsv = make_fixture(tmp_path)
    df, _ = build_interactions(kt1, qcsv, max_users=10)
    ds = KTSequenceDataset(df, seq_len=8)
    sample = ds[0]
    for key in ["q", "part", "correct", "elapsed", "lag", "mask"]:
        assert sample[key].shape == (8,)
    assert sample["mask"].sum() == 2               # two real interactions, rest padding
    assert 0.0 <= float(sample["elapsed"].max()) <= 1.0
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_kt_data.py -v` → FAIL.

- [x] **Step 4: Implement `kt/data.py`, verify pass**

```python
"""EdNet KT1 -> interaction frame + torch dataset (features per SAINT+ paper)."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import torch
from torch.utils.data import Dataset

def build_interactions(kt1_dir: Path, questions_csv: Path, max_users: int | None = None):
    q = pd.read_csv(questions_csv, usecols=["question_id", "correct_answer", "part"])
    q_map = {qid: i + 1 for i, qid in enumerate(q["question_id"])}  # 0 = padding
    q = q.set_index("question_id")

    frames = []
    files = sorted(Path(kt1_dir).glob("u*.csv"))[:max_users]
    for f in files:
        df = pd.read_csv(f).sort_values("timestamp")
        df["user_id"] = int(f.stem[1:])
        df = df.join(q, on="question_id", how="inner")
        df["correct"] = (df["user_answer"] == df["correct_answer"]).astype("int8")
        prev_end = (df["timestamp"] + df["elapsed_time"]).shift(1)
        df["lag_ms"] = (df["timestamp"] - prev_end).clip(lower=0).fillna(0).astype("int64")
        df["q_idx"] = df["question_id"].map(q_map)
        df["elapsed_ms"] = df["elapsed_time"].astype("int64")
        frames.append(df[["user_id", "q_idx", "part", "correct", "elapsed_ms", "lag_ms"]])
    out = pd.concat(frames, ignore_index=True)
    return out, q_map

def split_users(user_ids, seed: int = 0):
    rng = np.random.default_rng(seed)
    ids = np.array(sorted(user_ids))
    rng.shuffle(ids)
    n = len(ids)
    return (ids[: int(n * 0.8)].tolist(),
            ids[int(n * 0.8): int(n * 0.9)].tolist(),
            ids[int(n * 0.9):].tolist())

class KTSequenceDataset(Dataset):
    def __init__(self, df: pd.DataFrame, seq_len: int = 100):
        self.seq_len = seq_len
        self.windows = []
        for _, g in df.groupby("user_id", sort=False):
            arr = g[["q_idx", "part", "correct", "elapsed_ms", "lag_ms"]].to_numpy()
            for start in range(0, len(arr), seq_len):
                self.windows.append(arr[start: start + seq_len])

    def __len__(self):
        return len(self.windows)

    def __getitem__(self, i):
        w = self.windows[i]
        L, n = self.seq_len, len(w)
        pad = L - n
        def col(j, dtype):
            v = np.zeros(L, dtype=dtype); v[pad:] = w[:, j]; return v
        elapsed = np.clip(col(3, np.float32) / 1000.0, 0, 300) / 300.0
        lag = np.log1p(np.minimum(col(4, np.float32), 86_400_000) / 60_000.0) / np.log1p(1440.0)
        mask = np.zeros(L, dtype=np.float32); mask[pad:] = 1.0
        return {"q": torch.from_numpy(col(0, np.int64)),
                "part": torch.from_numpy(col(1, np.int64)),
                "correct": torch.from_numpy(col(2, np.int64)),
                "elapsed": torch.from_numpy(elapsed),
                "lag": torch.from_numpy(lag),
                "mask": torch.from_numpy(mask)}
```

Create empty `ml/questgraph_ml/kt/__init__.py`.
Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [x] **Step 5: Write and run the preparation script**

`ml/research/ednet_prepare.py`:

```python
"""Sample EdNet KT1 users and write interactions.parquet (~5-10M rows).
Usage: python ml/research/ednet_prepare.py --max-users 60000
"""
import argparse, json
from pathlib import Path
from questgraph_ml.kt.data import build_interactions

ROOT = Path(__file__).parents[2] / "ml/data/ednet"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-users", type=int, default=60000)
    args = ap.parse_args()

    df, q_map = build_interactions(ROOT / "KT1", ROOT / "contents/questions.csv",
                                   max_users=args.max_users)
    df.to_parquet(ROOT / "interactions.parquet")
    (ROOT / "q_map.json").write_text(json.dumps({k: v for k, v in q_map.items()}))
    (ROOT / "meta.json").write_text(json.dumps(
        {"n_questions": len(q_map) + 1, "n_parts": 8,
         "n_users": int(df["user_id"].nunique()), "n_rows": len(df)}))
    print(f"rows={len(df):,} users={df['user_id'].nunique():,} "
          f"questions={len(q_map):,} mean_correct={df['correct'].mean():.3f}")

if __name__ == "__main__":
    main()
```

Run: `$env:PYTHONPATH="ml"; ml/.venv/Scripts/python ml/research/ednet_prepare.py --max-users 60000`
Expected: ~5–10M rows, mean_correct ≈ 0.6–0.7 (EdNet norm). If rows < 5M, raise `--max-users`. Reading 60k csv files takes a while — run once, the parquet is the working artifact.

- [x] **Step 6: Commit**

```powershell
git add ml/
git commit -m "feat: EdNet KT1 preprocessing pipeline and sequence dataset"
```
