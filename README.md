# LingoRoad

AI-powered personalized English-learning platform for Vietnamese learners. LingoRoad
places a learner on the CEFR scale with an adaptive test, tracks what they know as they
practice, schedules reviews before they forget, and generates a personalized learning
path — with explanations in Vietnamese.

## AI features

| Feature | Technique | Status |
|---|---|---|
| Adaptive placement test | IRT 3PL + max-information CAT | Done |
| Knowledge tracing | SAINT+ Transformer (vs DKT/DKVMN baselines) | Done |
| Skill mastery | EMA with forgetting decay | Done |
| Spaced repetition | FSRS-4.5 | Done |
| Personalized learning path | Prerequisite-DAG rules; DQN PoC planned | Done / planned |
| Vietnamese study advisor | RAG + Gemini | Done (code) |
| Exercise generation, AWE, speaking | LLM + Whisper ASR | Planned |

Details and evidence: [docs/ai-theory-and-algorithms.md](docs/ai-theory-and-algorithms.md).

## Repository layout

```
docs/                       Project documentation (start at docs/README.md)
src/backend/LingoRoad/      ASP.NET Core application API (.NET 10)
src/backend/LingoRoad.Tests/  .NET test suite
src/backend/ml/             Python ML: training, research, FastAPI model serving
src/backend/docker-compose.yml  PostgreSQL 16
DESIGN.md, MVP_architecture.md, LingoRoad.md   Original (Vietnamese) design documents
```

## Quick start

```bash
# 1. Database
cd src/backend && docker compose up -d db

# 2. Application API  → http://localhost:5000
cd src/backend/LingoRoad && dotnet run

# 3. ML service       → http://localhost:8001
cd src/backend/ml && .venv/Scripts/uvicorn lingoroad_ml.serving.app:app --port 8001
```

Tests: `dotnet test src/backend` and `cd src/backend/ml && .venv/Scripts/python -m pytest tests/ -v`.

Architecture, schema, and data flows: [docs/system-architecture.md](docs/system-architecture.md).
