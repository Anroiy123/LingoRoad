# LingoRoad Documentation

| Document | What it answers |
|---|---|
| [ai-theory-and-algorithms.md](ai-theory-and-algorithms.md) | Theory, implementation, and evidence for every AI component: IRT/CAT placement, knowledge tracing (SAINT+), mastery, FSRS spaced repetition, rule-based path, RAG advisor |
| [learning-path-optimization.md](learning-path-optimization.md) | The path-scheduling optimization problem (input/output/constraints); Greedy vs Dynamic Programming vs RL (DQN/PPO) on accuracy and computational cost; the task-15 experiment protocol |
| [system-architecture.md](system-architecture.md) | Full-stack architecture (React + ASP.NET Core + FastAPI + PostgreSQL), schema design for model queries, data flows, integration map of the five AI modules |
| `superpowers/` | Design specs and implementation plans produced during development |

## Mapping to the theory requirement

The practicum theory work is split into three areas *(mảng)*; the split of areas 1–2
among the team is still TBD.

| Area | Focus | Covered by |
|---|---|---|
| Mảng 1 & 2 (TBD split) | Assessment models (IRT/CAT, knowledge tracing) and NLP/LLM (exercise generation, AWE, advisor, speaking) | [ai-theory-and-algorithms.md](ai-theory-and-algorithms.md) §1–4, §6–8 |
| **Mảng 3** (`src/backend/.claude/theory-reqquirement.md`) | Learning-path optimization + technical infrastructure | [learning-path-optimization.md](learning-path-optimization.md) + [system-architecture.md](system-architecture.md) |
