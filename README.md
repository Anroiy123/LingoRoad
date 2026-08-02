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
| Personalized learning path | Prerequisite-DAG rules; DQN PoC planned | Done (DQN PoC measured) |
| Vietnamese study advisor | RAG + Gemini | Done |
| Exercise generation, AWE, speaking | LLM + Whisper ASR | Done |

Details and evidence: [docs/ai-theory-and-algorithms.md](docs/ai-theory-and-algorithms.md).
Privacy, retention, export and deletion operations:
[docs/privacy-retention.md](docs/privacy-retention.md).

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

End-to-end smoke (both services running): `cd src/backend && ml/.venv/Scripts/python ml/research/e2e_smoke.py`.

Architecture, schema, and data flows: [docs/system-architecture.md](docs/system-architecture.md).

## Flutter mobile

Ứng dụng Flutter LingoRoad nằm tại `src/mobile`, gồm 5 tab chính: Học, Lộ trình,
Ôn tập, Tiến độ và Hồ sơ. Theme được xây dựng theo `DESIGN.md`; Auth, onboarding,
Profile, Home, Path, Lesson/Exercise, Review, Progress, Advisor, Writing và
Speaking đều dùng API thật. Không còn `MockRepository` trong mã production.

```powershell
cd src/mobile
flutter pub get
flutter analyze
flutter test

# Android Emulator (API mặc định: http://10.0.2.2:5000)
flutter run

# Web hoặc Windows
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Xem thêm hướng dẫn và cấu hình môi trường tại
[`src/mobile/README.md`](src/mobile/README.md).
