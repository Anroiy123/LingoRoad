# Folder Structure — LingoRoad ML Service (`lingoroad_ml`)

## The footgun to know before anything else
**There is no `pyproject.toml`, `setup.py`, `setup.cfg`, `README`,
`pytest.ini`, or `conftest.py` anywhere under `ml/`.** The `lingoroad_ml`
package is never `pip install`-ed; it only imports successfully because
the process's working directory is `ml/`, which Python puts on `sys.path`
for module (`-m`) invocations. Concretely:
- ✅ `cd src/backend/ml && .venv/Scripts/python -m pytest tests/ -v`
- ✅ `cd src/backend/ml && .venv/Scripts/python -m research.dqn_poc`
- ❌ `python src/backend/ml/research/dqn_poc.py` from the repo root — puts
  `research/` (not `ml/`) on `sys.path[0]`, so `from lingoroad_ml...`
  fails.
- The one exception: `research/build_item_bank.py` manually inserts `ml/`
  onto `sys.path` at the top of the file, so it happens to work either way.

When adding a new script under `research/` or a new test, follow the
existing convention (module invocation from `ml/`) rather than relying on
a script's own path tricks.

## Package layout (`lingoroad_ml/`)
```
lingoroad_ml/
├── irt.py           # 3PL IRT: prob_3pl, information, eap_estimate (161-pt grid EAP)
├── cat.py           # select_next: max-Fisher-information item selection
├── cefr.py          # cefr_from_theta — must mirror LingoRoad/Domain/CefrMap.cs
├── itemgen.py        # seed_irt_params — heuristic (a,b,c) seeding per CEFR level
├── simulation.py     # make_synthetic_bank, simulate_examinee, fixed_test — used by cat_simulation.py + tests
├── kt/                # knowledge tracing
│   ├── saint_plus.py  # SAINTPlus nn.Module — the model actually served at /kt/predict
│   ├── dkt.py          # DKTLstm nn.Module — baseline, not served
│   ├── dkvmn.py         # DKVMN nn.Module — baseline, not served
│   ├── data.py          # build_interactions (EdNet KT1 csv → DataFrame), split_users (80/10/10), KTSequenceDataset
│   └── train.py         # CLI trainer: python -m lingoroad_ml.kt.train --model {saint_plus,dkt,dkvmn}
├── rl/                 # task-15 DQN PoC — research-only, no HTTP route
│   ├── env.py           # ToyLearnerEnv
│   ├── dqn.py            # DQNAgent
│   └── dp.py              # value-iteration exact-optimum baseline
├── llm/                 # RAG advisor + generation features
│   ├── rag.py             # build_index, retrieve, gemini_embed
│   ├── advisor.py          # study-advisor prompt + answer()
│   ├── exercises.py         # MCQ/cloze/rewrite generation
│   ├── awe.py                 # IELTS-rubric automated writing evaluation
│   └── distractors.py         # WordNet distractors (nltk) — standalone, not wired into exercises.py
├── speech/scoring.py    # word_scores, fluency_from_wpm — pure functions, no Whisper dependency
└── serving/              # the FastAPI app
    ├── app.py              # FastAPI() instance; /health + /cat/select inline; includes the 3 routers below
    ├── kt_routes.py         # /kt/predict — lazy-loads + caches the SAINT+ checkpoint
    ├── llm_routes.py         # /llm/advisor, /llm/exercises, /llm/awe — shared Gemini client
    └── speech_routes.py       # /speech/score — faster-whisper + scoring + LLM feedback
```

## Other top-level dirs
| Path | Purpose | Git status |
|---|---|---|
| `research/` | Standalone scripts, run as `python -m research.<name>` from `ml/` — see `models-and-artifacts.md` for what each does | tracked |
| `tests/` | pytest suite, run from `ml/` | tracked |
| `checkpoints/` | Trained `.pt` model files | **gitignored** (`src/backend/.gitignore: ml/checkpoints/`) |
| `data/` | Item bank, RAG corpus + index, EdNet raw/prepared data | **entirely gitignored** (`ml/data/`) — even the hand-authored `data/corpus/*.md` guides are not in version control; a fresh clone has none of this and must regenerate it (see `models-and-artifacts.md`) |
| `reports/` | Generated evidence: `EVIDENCE.md`, `cat_simulation.{md,png}`, `dqn_poc.{md,png}`, `kt_results.md`, `samples/{advisor,awe,exercises,speaking}.md` | tracked |
| `requirements.txt` | Canonical, loosely-pinned deps for new installs | tracked |
| `requirements.freeze-2026-07-12.txt` | `pip freeze` snapshot from before a venv rebuild — historical/known-good reference, not the file to edit | tracked |

## Dependency / runtime setup
- Python **3.13** (the `.venv` interpreter and the freeze-file's cu121-vs-3.13
  comment both corroborate this).
- `requirements.txt` deliberately does **not** list `torch` as a plain
  requirement — it needs a special index. Install order:
  ```powershell
  cd src/backend/ml
  pip install -r requirements.txt
  pip install torch --index-url https://download.pytorch.org/whl/cu128
  ```
  (cu121 has no Python 3.13 wheels, per the comment in `requirements.txt`.)
  Verified working combo: `torch==2.11.0+cu128` on an RTX 4060.
- No `pip install -e .` step exists or is needed — see the footgun above.
- Run the service: `.venv/Scripts/uvicorn lingoroad_ml.serving.app:app
  --port 8001` from `ml/`.

## Adding a new module/endpoint — the pattern
Reference implementations: `/cat/select` (simplest, defined inline in
`app.py`) and `/kt/predict` (full pattern: separate router + logic module
+ lazy-loaded checkpoint).

1. **Logic module** — framework-agnostic, no FastAPI/pydantic imports:
   `lingoroad_ml/foo.py` or `lingoroad_ml/foo/model.py` (mirrors
   `irt.py`/`cat.py`, or `kt/saint_plus.py` vs `serving/kt_routes.py`).
2. **Route module** — `lingoroad_ml/serving/foo_routes.py`:
   ```python
   from fastapi import APIRouter
   from pydantic import BaseModel
   from lingoroad_ml.foo import do_thing

   router = APIRouter()

   class FooRequest(BaseModel): ...
   class FooResponse(BaseModel): ...

   @router.post("/foo/bar", response_model=FooResponse)
   def foo_bar(req: FooRequest):
       return FooResponse(...)
   ```
   If it needs a checkpoint, follow `kt_routes.py`'s lazy-singleton
   pattern: module-global `_model = None`, a private `_load()` reading a
   `QG_<THING>_CHECKPOINT` env var (`os.environ.get(name,
   "checkpoints/default.pt")`), returning `None`/503
   (`JSONResponse(..., status_code=503)`) if missing, plus a public
   `reset_model()` that tests use to force a reload via
   `monkeypatch.setenv`.
3. **Wire into the app** — in `serving/app.py`:
   ```python
   from lingoroad_ml.serving.foo_routes import router as foo_router
   app.include_router(foo_router)
   ```
   (Only skip the router file and define directly on `app` for something
   as simple as `/cat/select`.)
4. **Tests** — `tests/test_foo_api.py` using `TestClient(app)` from
   `lingoroad_ml.serving.app` (pattern: `test_cat_api.py`,
   `test_kt_api.py`), plus a pure-logic `tests/test_foo.py` for the
   framework-agnostic module (pattern: `test_irt.py`).
5. **Env var naming** — new checkpoint/index paths should follow
   `QG_<THING>_CHECKPOINT` / `QG_<THING>_INDEX` (matches `QG_KT_CHECKPOINT`,
   `QG_RAG_INDEX`), read via `os.environ.get(name, default_relative_path)`.
