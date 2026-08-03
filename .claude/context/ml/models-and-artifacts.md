# Models & Artifacts — LingoRoad ML Service

## Environment variables
| Var | Read in | Purpose | Default |
|---|---|---|---|
| `QG_KT_CHECKPOINT` | `serving/kt_routes.py` | Path to the SAINT+ `.pt` checkpoint served at `/kt/predict` | `"checkpoints/saint_plus.pt"` (relative to cwd) |
| `QG_RAG_INDEX` | `serving/llm_routes.py` | Path to the RAG `.npz` vector index used by `/llm/advisor` | `"data/corpus_index.npz"` |
| `GEMINI_API_KEY` | `serving/llm_routes.py`, `llm/rag.py` (`gemini_embed`), `research/build_item_bank.py`, `research/expand_skills.py` | Gemini OpenAI-compatible endpoint key (chat + embeddings) | **none — required**, read via `os.environ[...]` (raises `KeyError` if unset, not `.get()`) |
| `GEN_MODEL` | `research/build_item_bank.py` | Chat model for item-bank generation | `"gemini-2.5-flash"` |
| `TTS_PROVIDER` | `research/build_item_bank.py` | `"edge"` (edge-tts, free) or `"openai"` (tts-1) for listening-item audio | `"edge"` |
| `EDGE_VOICE` | `research/build_item_bank.py` | edge-tts voice name | `"en-US-AriaNeural"` |
| `OPENAI_BASE_URL` | `research/build_item_bank.py`, `research/expand_skills.py` | If set, switches to a generic OpenAI-compatible provider (with `OPENAI_API_KEY`) instead of Gemini | unset → Gemini |
| `EXPAND_MODEL` | `research/expand_skills.py` | Chat model for skill expansion | `"gemini-2.5-flash"` |

No GPU-selection env var exists — `speech_routes.py` does a hardcoded
`try: device="cuda" except: device="cpu"`; `kt/train.py` auto-detects via
`torch.cuda.is_available()`.

## Checkpoints (`checkpoints/`, gitignored)
```
checkpoints/dkt.pt          (~7.4 MB)
checkpoints/dkvmn.pt        (~7.0 MB)
checkpoints/saint_plus.pt   (~10.5 MB)   ← the one actually served
checkpoints/backup_20260718/{dkt,dkvmn,saint_plus}.pt   # dated backup
```
Format: `torch.save({"state_dict": ..., "config": {"model", "n_questions",
"d", "seq_len", ...}}, path)` — written by `kt/train.py`. Loaded by
`serving/kt_routes.py:_load()` via `torch.load(path, map_location="cpu",
weights_only=False)`, cached in a module-global, resettable via
`reset_model()` (used in tests with `monkeypatch.setenv`).

## Knowledge tracing
| Model | File | Served? |
|---|---|---|
| SAINT+ | `kt/saint_plus.py` (`SAINTPlus`) | Yes — `/kt/predict`, hardcoded to this class |
| DKT | `kt/dkt.py` (`DKTLstm`) | No — comparison-only |
| DKVMN | `kt/dkvmn.py` (`DKVMN`) | No — comparison-only |

- **Data**: `kt/data.py` — `build_interactions()` (EdNet KT1 csv →
  DataFrame: `q_idx/part/correct/elapsed_ms/lag_ms`), `split_users()`
  (80/10/10, seeded, split by user), `KTSequenceDataset` (windowed,
  left-padded, `seq_len` sequences).
- **Training**: `python -m lingoroad_ml.kt.train --model
  {saint_plus,dkt,dkvmn} [--epochs 5] [--batch 128] [--d 128] [--seq-len
  100] [--lr 1e-3] [--data ml/data/ednet]` — AMP autocast/GradScaler,
  early stop (patience 2 on val AUC), writes best checkpoint + appends a
  row to `reports/kt_results.md`.
- The `.NET` side assembles the `sequence` payload from the `Responses`
  table ordered by `AnsweredAt` — this service never reads Postgres
  directly (it's stateless).

## RL module (`rl/`) — task-15 DQN PoC, research-only
| File | Contents |
|---|---|
| `rl/env.py` | `ToyLearnerEnv(n_skills=5, seed=0)` — 5 chained skills (skill *i* needs skill *i-1* ≥0.5), gain 0.15·(1−m) if unlocked / 0.01 if blocked, decay 0.005/step, `done` at all≥0.8 (+1 reward) or 60-step cap |
| `rl/dqn.py` | `DQNAgent` — MLP `state_dim→64→64→n_actions`, ε-greedy, replay buffer (`deque`, maxlen 10k), target network synced every 200 steps |
| `rl/dp.py` | `build_model()` + `solve()`/`DpPolicy` — value iteration over an 11-level-per-skill discretized grid with multilinear-interpolated successors; the exact-optimum baseline |

Greedy/random baselines are **not** separate files — inline lambdas in
`research/dqn_poc.py`. Driver: `python -m research.dqn_poc` (4000
episodes, checkpoint-selected via periodic validation), writes
`reports/dqn_poc.{md,png}`. Theory/results write-up:
`docs/learning-path-optimization.md`.

## LLM/RAG module (`llm/`)
| File | Role |
|---|---|
| `rag.py` | `build_index(corpus_dir, out_path, embed_fn)` — chunks `*.md` at 800 chars, embeds, `np.savez` + sibling `.chunks.json`. `retrieve(query, index_path, embed_fn, k=3)` — brute-force cosine similarity. `gemini_embed(texts)` — `gemini-embedding-001` |
| `advisor.py` | Vietnamese system prompt + `build_messages(question, path, context_chunks)` + `answer()` (gemini-2.5-flash, temp 0.4) |
| `exercises.py` | `build_exercise_messages`, `parse_exercises` (validates `correct_answer ∈ options`), `generate()` (temp 0.7, forced JSON) |
| `awe.py` | `build_awe_messages` (IELTS rubric), `evaluate()` (temp 0.2, forced JSON) |
| `distractors.py` | `wordnet_distractors(word, n)` (nltk WordNet) — standalone, **not currently wired into `exercises.py` or any route** |

Index build: `python -m research.build_rag_index` — one-liner driver
calling `build_index(data/corpus, data/corpus_index.npz,
embed_fn=gemini_embed)`.

## Data (`data/`, entirely gitignored)
```
data/corpus/*.md                    11 hand-authored grammar guides — RAG source (NOT in version control)
data/corpus_index.npz               RAG embeddings (research/build_rag_index.py)
data/corpus_index.npz.chunks.json   parallel chunk-text array
data/items.json                     617-item question bank (research/build_item_bank.py)
data/ednet/                         EdNet KT1 raw + prepared (KT1.zip, 60k per-user csvs, interactions.parquet, meta.json, q_map.json)
```
Because `ml/data/` is fully gitignored, **a fresh clone has none of this**
— including the hand-written `corpus/*.md` source files, which exist
nowhere else. Regenerating requires: item bank via `build_item_bank.py`,
RAG index via `build_rag_index.py` (needs `data/corpus/*.md` to already
exist — there's no separate script that recreates the guides themselves),
EdNet via external download + `ednet_prepare.py`.

## Research scripts (`research/`)
| Script | Purpose | Invocation |
|---|---|---|
| `build_item_bank.py` | Generates the 617-item bank (MCQ/cloze/listening) via LLM + TTS, seeds IRT params, optional `--post` import into the `.NET` API | `python ml/research/build_item_bank.py --per-skill 4 [--limit N] [--post URL] [--sleep S] [--resume]` (has its own `sys.path` shim — works from anywhere) |
| `build_rag_index.py` | Builds `data/corpus_index.npz` | `python -m research.build_rag_index` |
| `cat_simulation.py` | CAT-vs-fixed-test accuracy study → `reports/cat_simulation.{md,png}` | `python -m research.cat_simulation [--n 1000] [--items ml/data/items.json]` |
| `dqn_poc.py` | Trains DQN, solves DP, evaluates DP/DQN/Greedy/Random → `reports/dqn_poc.{md,png}` | `python -m research.dqn_poc` |
| `e2e_smoke.py` | Live smoke test against the **`.NET` API** (not this service directly) — auth, placement, mastery/path, reviews, advisor/exercises/AWE | `ml/.venv/Scripts/python ml/research/e2e_smoke.py --api http://localhost:5000 [--skip-llm]`; needs db + `.NET` API + this service all running, plus the item bank imported |
| `ednet_prepare.py` | Samples EdNet KT1 users → `data/ednet/interactions.parquet` + `meta.json` + `q_map.json` | `python ml/research/ednet_prepare.py --max-users 60000` (or `-m research.ednet_prepare`) |
| `expand_skills.py` | LLM-expands `LingoRoad/Data/Seed/skills.json` to ~150 micro-skills (in place — review the diff by hand) | `python -m research.expand_skills` |

## Docs-vs-code note
`docs/ai-theory-and-algorithms.md` marks exercise generation/AWE (task 13)
and speaking (task 14) as **Planned**. `llm/exercises.py`, `llm/awe.py`,
`speech/scoring.py`, and their routes are fully implemented and tested,
with sample output already in `reports/samples/{exercises,awe,speaking}.md`
— the doc label is stale, the code is ahead of it.
