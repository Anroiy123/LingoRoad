# Task 9: Knowledge Tracing Models — SAINT+, DKT-LSTM, DKVMN + AUC table

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-8. Sprint 2. **This is the report's headline experiment.**

**Files:**
- Create: `ml/questgraph_ml/kt/saint_plus.py`, `ml/questgraph_ml/kt/dkt.py`, `ml/questgraph_ml/kt/dkvmn.py`, `ml/questgraph_ml/kt/train.py`, `ml/tests/test_kt_models.py`
- Modify: none

**Interfaces:**
- Consumes: `KTSequenceDataset`, `split_users`, `interactions.parquet`, `meta.json` (task-8).
- Produces:
  - Models, each `forward(batch: dict) -> logits [B, L]` where `batch` is the task-8 dataset dict (on device): `SAINTPlus(n_questions, n_parts=8, d=128, heads=8, layers=2, seq_len=100)`, `DKTLstm(n_questions, d=128)`, `DKVMN(n_questions, d=128, n_mem=32)`.
  - Checkpoints `ml/checkpoints/{saint_plus|dkt|dkvmn}.pt` saved as `{"state_dict":…, "config":{…}}` — task-10 loads `saint_plus.pt`.
  - `ml/reports/kt_results.md` AUC comparison table.
- Leakage rule all models obey: the prediction for position *t* may use questions ≤ *t* and responses < *t* (lag time of *t* is allowed — it is known before answering).

- [x] **Step 1: Write failing model tests**

`ml/tests/test_kt_models.py`:

```python
import torch
from questgraph_ml.kt.saint_plus import SAINTPlus
from questgraph_ml.kt.dkt import DKTLstm
from questgraph_ml.kt.dkvmn import DKVMN

def fake_batch(B=4, L=16, n_q=50):
    g = torch.Generator().manual_seed(0)
    return {
        "q": torch.randint(1, n_q, (B, L), generator=g),
        "part": torch.randint(1, 8, (B, L), generator=g),
        "correct": torch.randint(0, 2, (B, L), generator=g),
        "elapsed": torch.rand(B, L, generator=g),
        "lag": torch.rand(B, L, generator=g),
        "mask": torch.ones(B, L),
    }

MODELS = [
    lambda: SAINTPlus(n_questions=50, seq_len=16, d=32, heads=4, layers=1),
    lambda: DKTLstm(n_questions=50, d=32),
    lambda: DKVMN(n_questions=50, d=32, n_mem=8),
]

def test_forward_shapes():
    b = fake_batch()
    for make in MODELS:
        logits = make()(b)
        assert logits.shape == (4, 16)

def test_no_response_leakage_at_current_position():
    """Flipping correct[t] must not change the logit at t (only at >t)."""
    b1, b2 = fake_batch(), fake_batch()
    b2["correct"] = b1["correct"].clone()
    b2["correct"][:, -1] = 1 - b2["correct"][:, -1]   # flip only the last response
    for make in MODELS:
        m = make().eval()
        with torch.no_grad():
            l1, l2 = m(b1), m(b2)
        assert torch.allclose(l1[:, -1], l2[:, -1], atol=1e-5), type(m).__name__

def test_saint_plus_overfits_tiny_batch():
    torch.manual_seed(0)
    b = fake_batch(B=8, L=16)
    m = SAINTPlus(n_questions=50, seq_len=16, d=32, heads=4, layers=1)
    opt = torch.optim.Adam(m.parameters(), lr=1e-3)
    for _ in range(300):
        loss = torch.nn.functional.binary_cross_entropy_with_logits(
            m(b), b["correct"].float())
        opt.zero_grad(); loss.backward(); opt.step()
    acc = ((m(b) > 0) == b["correct"].bool()).float().mean()
    assert acc > 0.9
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_kt_models.py -v` → FAIL.

- [x] **Step 2: Implement SAINT+**

`ml/questgraph_ml/kt/saint_plus.py`:

```python
"""SAINT+ (Shin et al. 2021): encoder attends to exercises, decoder to responses
+ temporal features. Response/elapsed are shifted right (start token); lag is not
(known before answering)."""
import torch
import torch.nn as nn

class SAINTPlus(nn.Module):
    START = 2  # response vocab: 0 wrong, 1 correct, 2 start-of-sequence

    def __init__(self, n_questions: int, n_parts: int = 8, d: int = 128,
                 heads: int = 8, layers: int = 2, seq_len: int = 100,
                 dropout: float = 0.1):
        super().__init__()
        self.q_emb = nn.Embedding(n_questions, d, padding_idx=0)
        self.part_emb = nn.Embedding(n_parts + 1, d, padding_idx=0)
        self.pos_emb = nn.Embedding(seq_len, d)
        self.resp_emb = nn.Embedding(3, d)
        self.elapsed_lin = nn.Linear(1, d)
        self.lag_lin = nn.Linear(1, d)
        self.transformer = nn.Transformer(
            d_model=d, nhead=heads, num_encoder_layers=layers,
            num_decoder_layers=layers, dim_feedforward=4 * d,
            dropout=dropout, batch_first=True)
        self.out = nn.Linear(d, 1)

    def forward(self, batch: dict) -> torch.Tensor:
        q, part = batch["q"], batch["part"]
        B, L = q.shape
        pos = self.pos_emb(torch.arange(L, device=q.device))[None]

        enc = self.q_emb(q) + self.part_emb(part) + pos

        resp_prev = torch.cat(
            [torch.full((B, 1), self.START, device=q.device, dtype=torch.long),
             batch["correct"][:, :-1]], dim=1)
        elapsed_prev = torch.cat(
            [torch.zeros(B, 1, device=q.device), batch["elapsed"][:, :-1]], dim=1)
        dec = (self.resp_emb(resp_prev)
               + self.elapsed_lin(elapsed_prev.unsqueeze(-1))
               + self.lag_lin(batch["lag"].unsqueeze(-1))
               + pos)

        causal = nn.Transformer.generate_square_subsequent_mask(L, device=q.device)
        h = self.transformer(enc, dec, src_mask=causal, tgt_mask=causal,
                             memory_mask=causal)
        return self.out(h).squeeze(-1)
```

- [x] **Step 3: Implement DKT-LSTM and DKVMN**

`ml/questgraph_ml/kt/dkt.py`:

```python
"""DKT baseline: LSTM over previous interactions, predict current question."""
import torch
import torch.nn as nn

class DKTLstm(nn.Module):
    START = 2

    def __init__(self, n_questions: int, d: int = 128):
        super().__init__()
        self.q_emb = nn.Embedding(n_questions, d, padding_idx=0)
        self.resp_emb = nn.Embedding(3, d)
        self.lstm = nn.LSTM(d, d, batch_first=True)
        self.out = nn.Sequential(nn.Linear(2 * d, d), nn.ReLU(), nn.Linear(d, 1))

    def forward(self, batch: dict) -> torch.Tensor:
        q = batch["q"]
        B, L = q.shape
        q_prev = torch.cat([torch.zeros(B, 1, dtype=torch.long, device=q.device),
                            q[:, :-1]], dim=1)
        r_prev = torch.cat([torch.full((B, 1), self.START, dtype=torch.long,
                                       device=q.device),
                            batch["correct"][:, :-1]], dim=1)
        h, _ = self.lstm(self.q_emb(q_prev) + self.resp_emb(r_prev))
        return self.out(torch.cat([h, self.q_emb(q)], dim=-1)).squeeze(-1)
```

`ml/questgraph_ml/kt/dkvmn.py`:

```python
"""DKVMN baseline (Zhang et al. 2017), compact: static key memory, dynamic value
memory with erase/add writes. Read for question t happens BEFORE writing response t."""
import torch
import torch.nn as nn

class DKVMN(nn.Module):
    def __init__(self, n_questions: int, d: int = 128, n_mem: int = 32):
        super().__init__()
        self.q_emb = nn.Embedding(n_questions, d, padding_idx=0)
        self.resp_emb = nn.Embedding(2, d)
        self.key = nn.Parameter(torch.randn(n_mem, d) * 0.1)
        self.v_init = nn.Parameter(torch.randn(n_mem, d) * 0.1)
        self.erase = nn.Linear(d, d)
        self.add = nn.Linear(d, d)
        self.f = nn.Linear(2 * d, d)
        self.out = nn.Linear(d, 1)

    def forward(self, batch: dict) -> torch.Tensor:
        q, correct = batch["q"], batch["correct"]
        B, L = q.shape
        mv = self.v_init.expand(B, -1, -1).contiguous()   # [B, n_mem, d]
        logits = []
        for t in range(L):
            k = self.q_emb(q[:, t])                        # [B, d]
            w = torch.softmax(k @ self.key.T, dim=-1)      # [B, n_mem]
            read = (w.unsqueeze(-1) * mv).sum(1)           # [B, d]
            summary = torch.tanh(self.f(torch.cat([read, k], dim=-1)))
            logits.append(self.out(summary).squeeze(-1))
            v = k + self.resp_emb(correct[:, t])           # write AFTER predicting
            e = torch.sigmoid(self.erase(v))
            a = torch.tanh(self.add(v))
            mv = mv * (1 - w.unsqueeze(-1) * e.unsqueeze(1)) \
                 + w.unsqueeze(-1) * a.unsqueeze(1)
        return torch.stack(logits, dim=1)
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_kt_models.py -v` → PASS (overfit test takes ~1 min on CPU).

- [x] **Step 4: Implement the shared training CLI**

`ml/questgraph_ml/kt/train.py`:

```python
"""Train a KT model on the EdNet parquet.
Usage: python -m questgraph_ml.kt.train --model saint_plus [--epochs 5] [--batch 128]
"""
import argparse, json, time
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import roc_auc_score
from torch.utils.data import DataLoader
from questgraph_ml.kt.data import KTSequenceDataset, split_users
from questgraph_ml.kt.saint_plus import SAINTPlus
from questgraph_ml.kt.dkt import DKTLstm
from questgraph_ml.kt.dkvmn import DKVMN

ROOT = Path(__file__).parents[2]

def make_model(name, n_q, seq_len, d):
    if name == "saint_plus": return SAINTPlus(n_q, d=d, seq_len=seq_len)
    if name == "dkt":        return DKTLstm(n_q, d=d)
    if name == "dkvmn":      return DKVMN(n_q, d=d)
    raise ValueError(name)

@torch.no_grad()
def evaluate(model, loader, device):
    model.eval()
    ys, ps = [], []
    for b in loader:
        b = {k: v.to(device) for k, v in b.items()}
        logits = model(b)
        m = b["mask"].bool()
        ys.append(b["correct"][m].cpu().numpy())
        ps.append(torch.sigmoid(logits[m]).cpu().numpy())
    return roc_auc_score(np.concatenate(ys), np.concatenate(ps))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, choices=["saint_plus", "dkt", "dkvmn"])
    ap.add_argument("--epochs", type=int, default=5)
    ap.add_argument("--batch", type=int, default=128)
    ap.add_argument("--d", type=int, default=128)
    ap.add_argument("--seq-len", type=int, default=100)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--data", default=str(ROOT / "data/ednet"))
    args = ap.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    data = Path(args.data)
    meta = json.loads((data / "meta.json").read_text())
    df = pd.read_parquet(data / "interactions.parquet")
    train_u, val_u, test_u = split_users(df["user_id"].unique().tolist())
    loaders = {}
    for name, users, shuffle in [("train", train_u, True), ("val", val_u, False),
                                 ("test", test_u, False)]:
        ds = KTSequenceDataset(df[df["user_id"].isin(users)], seq_len=args.seq_len)
        loaders[name] = DataLoader(ds, batch_size=args.batch, shuffle=shuffle)

    model = make_model(args.model, meta["n_questions"], args.seq_len, args.d).to(device)
    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    scaler = torch.amp.GradScaler(device)
    bce = torch.nn.functional.binary_cross_entropy_with_logits

    best_auc, patience = 0.0, 0
    ckpt = ROOT / "checkpoints" / f"{args.model}.pt"
    ckpt.parent.mkdir(exist_ok=True)
    for epoch in range(args.epochs):
        model.train(); t0 = time.time()
        for b in loaders["train"]:
            b = {k: v.to(device) for k, v in b.items()}
            with torch.amp.autocast(device):
                logits = model(b)
                loss = bce(logits, b["correct"].float(), weight=b["mask"])
            opt.zero_grad(); scaler.scale(loss).backward()
            scaler.step(opt); scaler.update()
        val_auc = evaluate(model, loaders["val"], device)
        print(f"epoch {epoch}: val AUC={val_auc:.4f} ({time.time()-t0:.0f}s)")
        if val_auc > best_auc:
            best_auc, patience = val_auc, 0
            torch.save({"state_dict": model.state_dict(),
                        "config": {"model": args.model, "n_questions": meta["n_questions"],
                                   "d": args.d, "seq_len": args.seq_len}}, ckpt)
        elif (patience := patience + 1) >= 2:
            print("early stop"); break

    model.load_state_dict(torch.load(ckpt, weights_only=False)["state_dict"])
    test_auc = evaluate(model, loaders["test"], device)
    report = ROOT / "reports/kt_results.md"
    report.parent.mkdir(exist_ok=True)
    if not report.exists():
        report.write_text("| Model | Val AUC | Test AUC |\n|---|---|---|\n")
    with report.open("a") as f:
        f.write(f"| {args.model} | {best_auc:.4f} | {test_auc:.4f} |\n")
    print(f"TEST AUC ({args.model}): {test_auc:.4f}")

if __name__ == "__main__":
    main()
```

- [x] **Step 5: Smoke-train, then full runs**

Smoke (verifies the loop end-to-end in minutes): temporarily prepare a small parquet with `--max-users 2000`, then

```powershell
$env:PYTHONPATH = "ml"
ml/.venv/Scripts/python -m questgraph_ml.kt.train --model saint_plus --epochs 1
```

Full runs (each on the 60k-user parquet; SAINT+ ≈ 20–60 min/epoch on the 4060 — run overnight if needed):

```powershell
ml/.venv/Scripts/python -m questgraph_ml.kt.train --model dkt --epochs 5
ml/.venv/Scripts/python -m questgraph_ml.kt.train --model dkvmn --epochs 5
ml/.venv/Scripts/python -m questgraph_ml.kt.train --model saint_plus --epochs 5
```

Expected: `ml/reports/kt_results.md` has three rows. Target: SAINT+ test AUC ≥ 0.75 on the subset and ≥ both baselines (published full-EdNet SAINT+ is ~0.79; a subset scores lower — report actual numbers honestly, per requirement.md V-4). If SAINT+ < DKT, debug before proceeding (check leakage test, lr, epochs) — do not report a broken comparison.

- [x] **Step 6: Commit**

```powershell
git add ml/
git commit -m "feat: SAINT+, DKT-LSTM, DKVMN training with AUC comparison"
```
