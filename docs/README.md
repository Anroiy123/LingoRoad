# LingoRoad Documentation

| Document | What it answers |
|---|---|
| [ai-theory-and-algorithms.md](ai-theory-and-algorithms.md) | Theory, implementation, and evidence for every AI component: IRT/CAT placement, knowledge tracing (SAINT+), mastery, FSRS spaced repetition, rule-based path, RAG advisor |
| [learning-path-optimization.md](learning-path-optimization.md) | The path-scheduling optimization problem (input/output/constraints); Greedy vs Dynamic Programming vs RL (DQN/PPO) on accuracy and computational cost; the task-15 experiment protocol |
| [system-architecture.md](system-architecture.md) | Full-stack architecture (React + ASP.NET Core + FastAPI + PostgreSQL), schema design for model queries, data flows, integration map of the five AI modules |
| [bao-cao-mang-3-vn.md](bao-cao-mang-3-vn.md) | Vietnamese consolidation of the two Mảng 3 documents above (Part A optimization + Part B architecture) |
| [bao-cao-ly-thuyet-nhom.md](bao-cao-ly-thuyet-nhom.md) | Shared team theory doc (VN): the three-area assignment, each member's results in full (Mảng 1 & 2), Mảng 3 summary, and a theory↔implementation cross-link table |
| [bao-cao-tien-do.md](bao-cao-tien-do.md) | Progress report (VN): theory + implementation status per module with measured evidence, and the khó khăn log — blockers hit during implementation and how each was resolved |
| `superpowers/` | Design specs and implementation plans produced during development |

## Mapping to the theory requirement

The practicum theory work is split into three areas *(mảng)*, one per team member.
All three members' results are collected in [bao-cao-ly-thuyet-nhom.md](bao-cao-ly-thuyet-nhom.md).

| Area | Focus | Covered by |
|---|---|---|
| Mảng 1 | Learning theory (ZPD, mastery, SRL, SRS), knowledge tracing (DKT/DKVMN/SAINT+), gamification | [bao-cao-ly-thuyet-nhom.md](bao-cao-ly-thuyet-nhom.md) §Mảng 1; measured KT evidence in [ai-theory-and-algorithms.md](ai-theory-and-algorithms.md) |
| Mảng 2 | LLM & RAG, CEFR assessment (IRT/CAT), ASR & pronunciation (Whisper, MFA) | [bao-cao-ly-thuyet-nhom.md](bao-cao-ly-thuyet-nhom.md) §Mảng 2; measured placement/advisor/speaking evidence in [ai-theory-and-algorithms.md](ai-theory-and-algorithms.md) |
| **Mảng 3** (`src/backend/.claude/theory-reqquirement.md`) | Learning-path optimization + technical infrastructure | [learning-path-optimization.md](learning-path-optimization.md) + [system-architecture.md](system-architecture.md) (VN: [bao-cao-mang-3-vn.md](bao-cao-mang-3-vn.md)) |
