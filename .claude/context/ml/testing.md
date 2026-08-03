# Testing — LingoRoad ML Service

No `pytest.ini`, `conftest.py`, or markers exist anywhere under `ml/`.
Tests **must** run with `ml/` as the working directory (see the footgun
note in `folder-structure.md`):
```powershell
cd src/backend/ml
.venv/Scripts/python -m pytest tests/ -v
```

No test requires an actual GPU or live network/API call:
- `test_kt_api.py` / `test_kt_models.py` build small CPU-sized models on
  the fly.
- `test_speech.py` only exercises pure-Python scoring functions
  (`speech/scoring.py`) — never touches faster-whisper.
- `test_dqn_checkpoint.py` trains a real but tiny (25-episode) DQN on CPU.
- `test_rag.py`, `test_llm_api.py`, `test_exercises.py` use **fakes** or
  test prompt-construction shape only — no live Gemini calls.

## Test file map
| File | Covers |
|---|---|
| `test_irt.py` | `irt.py`, `cat.py` — 3PL probability, information peak, EAP prior/posterior, item selection |
| `test_itemgen.py` | `itemgen.py` — param bounds, CEFR ordering, seeded determinism |
| `test_simulation.py` | `cefr.py`, `simulation.py` — CEFR bins, CAT stop rule, unbiasedness |
| `test_cat_api.py` | `/cat/select` via FastAPI `TestClient` |
| `test_kt_models.py` | SAINT+/DKT/DKVMN — forward shapes, no-leakage-at-t (flips `correct[-1]`, asserts logit unchanged), tiny-batch overfit sanity |
| `test_kt_data.py` | `kt/data.py` — `build_interactions` correctness/lag, `split_users` disjointness/determinism, dataset padding/dtypes |
| `test_kt_api.py` | `/kt/predict` — builds a real tiny checkpoint via `monkeypatch.setenv("QG_KT_CHECKPOINT", ...)` + `kt_routes.reset_model()`; also the 503-without-checkpoint path |
| `test_rl.py` | `rl/env.py`, `rl/dqn.py`, `rl/dp.py` — env shapes/gating/termination, DQN trains without error, DP model matches env dynamics exactly, DP converges to goal, DP ≥ greedy |
| `test_dqn_checkpoint.py` | `research/dqn_poc.py` checkpoint-selection reproducibility — imports `research.dqn_poc` directly, must run with `ml/` as rootdir |
| `test_dqn_poc_report.py` | `research/dqn_poc.py:report_lines()` — markdown values are computed, not hardcoded |
| `test_rag.py` | `llm/rag.py` — build/retrieve roundtrip with a fake deterministic embedder |
| `test_llm_api.py` | `llm/advisor.py:build_messages` — prompt shape only |
| `test_exercises.py` | `llm/exercises.py`, `llm/awe.py`, `llm/distractors.py` — prompt shape, JSON parsing/validation, WordNet distractors (needs `nltk.download('wordnet')` per the module docstring) |
| `test_speech.py` | `speech/scoring.py` — `word_scores`/`fluency_from_wpm` (numbers, contractions, case) |

## Conventions
- **Pure-logic modules** (`irt.py`, `cat.py`, `cefr.py`, `MasteryCalc`-style
  math) get a matching `tests/test_<module>.py` with no FastAPI/`TestClient`
  involvement.
- **Served routes** get a `tests/test_<feature>_api.py` using
  `TestClient(app)` from `lingoroad_ml.serving.app`.
- **LLM-backed modules** are tested for prompt construction and response
  parsing with fakes/fixtures — never assert on live Gemini output.
- **Model-backed routes with a checkpoint dependency** (`/kt/predict`)
  follow the `monkeypatch.setenv` + `reset_model()` pattern to inject a
  tiny test checkpoint rather than requiring the real trained one.
- No coverage threshold is enforced; no CI runs this suite (no
  `.github/workflows/`) — developer-run only.
