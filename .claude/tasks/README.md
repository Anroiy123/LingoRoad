# QuestGraph Implementation Plan (Index)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Execute task files in order; each file is self-contained.

**Goal:** Build the QuestGraph English-learning platform: ASP.NET Core API + Python ML service implementing adaptive placement testing (IRT/CAT), knowledge tracing (SAINT+), spaced repetition (FSRS), rule-based learning paths with an LLM advisor, LLM exercise generation/AWE, Whisper speaking assessment, and a DQN proof-of-concept — per `.claude/requirement.md` and `.claude/requirement-brainstorm.md`.

**Architecture:** Two services in one repo. `QuestGraph/` (.NET 10 minimal API) owns auth, domain, PostgreSQL persistence, and orchestration; `ml/` (Python FastAPI + PyTorch) serves stateless AI inference (CAT math, SAINT+, LLM calls, Whisper) and contains all research/training code so experiments and production share one implementation.

**Tech Stack:** .NET 10, EF Core + Npgsql, xUnit; Python 3.11, FastAPI, PyTorch, scipy, pytest; PostgreSQL 16 (docker-compose); Gemini API via OpenAI-compatible endpoint (gemini-2.5-flash, gemini-embedding-001); local Whisper via faster-whisper (ASR); edge-tts (listening audio).

## Global Constraints

Every task's requirements implicitly include these:

- .NET 10, minimal APIs, single `QuestGraph` project + `QuestGraph.Tests` (xUnit + WebApplicationFactory + SQLite in-memory for tests).
- Python 3.11+ in `ml/` with venv at `ml/.venv`; `pip install -r ml/requirements.txt`; tests via `pytest` from `ml/`.
- PostgreSQL 16 via `docker-compose.yml` service `db`: database `questgraph`, user `questgraph`, password `questgraph`, port 5432.
- ML service runs at `http://localhost:8001`; .NET reads base URL from config key `MlService:BaseUrl`.
- Degradation rule: if the ML service is unreachable, AI endpoints return **503** with body `{"error":"ml_service_unavailable"}`; non-AI endpoints keep working.
- `GEMINI_API_KEY` env var — see local `.claude/settings.local.json` / user secrets, **not committed to git** (billed tier, verified 2026-07-10 — no free-tier daily caps; `gemini-2.5-pro` available if a task needs it). LLM/embedding calls use the OpenAI SDK with base URL `https://generativelanguage.googleapis.com/v1beta/openai/`. Models: `gemini-2.5-flash` (LLM), local `faster-whisper` (ASR, runs on the GPU), `edge-tts` (listening audio), `gemini-embedding-001` (RAG).
- All learner-facing LLM output (advisor, AWE feedback, speaking feedback) is **Vietnamese**; exercise content itself is English.
- GPU budget RTX 4060 8 GB: KT models use sequence length 100, batch size ≤ 128, AMP allowed.
- θ→CEFR mapping (used everywhere): A1 < −1.5 ≤ A2 < −0.5 ≤ B1 < 0.5 ≤ B2 < 1.5 ≤ C1 < 2.25 ≤ C2.
- CAT stop rule: minimum 8 items, stop when SE(θ) < 0.35, hard cap 30 items.
- Never commit: `.claude/settings.local.json` (may hold machine-local secrets), `ml/data/`, `ml/checkpoints/`, `ml/.venv/`, learner audio uploads (`QuestGraph/wwwroot/uploads/`).
- TDD: every task follows write-test → see-fail → implement → see-pass → commit.

## Task Order & Dependencies

| # | File | Feature | Depends on | Sprint |
|---|------|---------|-----------|--------|
| 1 | task-1-foundations.md | Repo scaffold, docker Postgres, EF Core, health, test infra | — | 1 |
| 2 | task-2-auth-users.md | JWT auth, users | 1 | 1 |
| 3 | task-3-skills-graph.md | Micro-skill knowledge graph + seed | 1 | 1 |
| 4 | task-4-question-bank.md | Item bank schema + generation pipeline + import | 3 | 1 |
| 5 | task-5-cat-engine-service.md | IRT 3PL/EAP/max-info in Python + FastAPI `/cat/select` + .NET client | 1 | 1 |
| 6 | task-6-placement-sessions.md | Placement test endpoints end-to-end | 2,4,5 | 1 |
| 7 | task-7-cat-simulation.md | CAT simulation experiment (report evidence) | 5 | 1 |
| 8 | task-8-ednet-pipeline.md | EdNet KT1 download/sample/features/splits | 5 (ml env) | 2 |
| 9 | task-9-kt-models.md | SAINT+, DKT-LSTM, DKVMN training + AUC table | 8 | 2 |
| 10 | task-10-kt-serving-mastery.md | `/kt/mastery` serving + mastery updates in .NET | 6,9 | 2 |
| 11 | task-11-fsrs-review-queue.md | FSRS scheduler (C#) + review endpoints | 2,3 | 3 |
| 12 | task-12-learning-path-advisor.md | Rule-based path + LLM advisor with RAG | 3,10 | 3 |
| 13 | task-13-exercises-awe.md | Exercise generation, distractors, AWE | 3,5 (ml svc) | 3 |
| 14 | task-14-speaking.md | Audio upload → Whisper → scoring + feedback | 2,5 (ml svc) | 3 |
| 15 | task-15-dqn-poc.md | Toy-simulator DQN + learning-curve plot (time-boxed 4 days) | 3 | 3 |
| 16 | task-16-demo-e2e.md | Demo seed data, e2e smoke script, report evidence collection | all | 3 |

## Repository Layout (target)

```
QuestGraph.sln
docker-compose.yml
QuestGraph/                      # ASP.NET Core API
  Program.cs
  Data/AppDbContext.cs
  Domain/                        # entities + pure domain logic (Fsrs.cs, CefrMap.cs, ...)
  Endpoints/                     # one static class per feature (AuthEndpoints.cs, ...)
  Services/                      # MlClient.cs, TokenService.cs, ...
QuestGraph.Tests/                # xUnit
ml/
  requirements.txt
  questgraph_ml/
    irt.py  cat.py               # shared math (serving + research)
    serving/app.py               # FastAPI
    kt/     llm/    speech/  rl/
  research/                      # scripts: build_item_bank.py, cat_simulation.py, ...
  tests/
```
