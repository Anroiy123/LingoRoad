# Design: Theory Section 3 documentation (Learning Path Optimization + System Architecture)

Date: 2026-07-15
Status: approved (brainstorming session, user-validated)

## Context

The practicum theory work is split into three areas (mảng). The file
`src/backend/.claude/theory-reqquirement.md` is **Mảng 3** in its entirety — the area the
user owns. Its required output ("Đầu ra") is a document with three parts:

1. A description of the learning-path scheduling problem as combinatorial optimization
   *(bài toán tối ưu tổ hợp)* — input / output / constraints.
2. A comparison of three solution methods — Greedy vs Dynamic Programming vs
   Reinforcement Learning (DQN/PPO) — on accuracy and computational cost.
3. A system-architecture proposal (Python + React + PostgreSQL) integrating with the
   other two theory areas.

What the repo already provides: `docs/ai-theory-and-algorithms.md` covers the
implemented rule-based path builder (§5) and the planned DQN PoC (§8);
`.claude/tasks/task-15-dqn-poc.md` contains a complete toy-scale MDP formulation.
Missing: the formal optimization problem statement, all Dynamic Programming and PPO
material, the three-way comparison, and any architecture document.

## Decisions (from clarifying questions)

| Question | Decision |
|---|---|
| Audience / language | English repo docs with Vietnamese key terms annotated at first use; the user translates to Vietnamese for the practicum report later. |
| Mảng 1 & 2 boundaries | Not finalized. Write integration material against the 5 AI modules in `src/backend/.claude/requirement.md`; mark area ownership TBD. |
| Evidence for the comparison | Theory now (complexity analysis + literature). Define the exact toy-scale experiment for task 15 to produce measured numbers later. No new code in this effort. |
| Architecture stance | Document the actual hybrid as the proposal: ASP.NET Core application API + Python FastAPI ML serving + PostgreSQL (+ React planned), justified as an engineering choice. |
| Structure | Approach A: two focused docs plus navigation updates (chosen over one consolidated doc or extending the existing theory doc). |

## Deliverables

### 1. `docs/learning-path-optimization.md` (new — Đầu ra parts 1 & 2)

1. **Informal problem description** — sequencing study activities over the 156-skill
   prerequisite DAG for a learner with a mastery vector, goal CEFR level, and forgetting;
   grounded in `PathBuilder.cs`, `MasteryCalc.cs`, `Fsrs.cs`.
2. **Formal problem statement** with two formulations:
   - Static combinatorial view: precedence-constrained scheduling. Input = skill graph
     G=(S,E), mastery vector m ∈ [0,1]^156, goal CEFR, per-skill time costs. Output = an
     ordering of study activities. Constraints = prerequisite edges (hard), session
     budget, leaf-skills-only, skills above goal excluded. Note NP-hardness of
     precedence-constrained scheduling in general.
   - Stochastic MDP view (canonical): state = mastery vector; action = skill to study;
     transition = stochastic learning gain + forgetting decay (the MasteryCalc/task-15
     dynamics); reward = mastery gain; objective = minimize expected time-to-goal. Show
     the static view is the deterministic special case.
3. **Greedy** — the implemented rule pipeline (Kahn topological sort + filters) and the
   max-gain-per-unit-time greedy variant; O(V+E); explainable, constraint-safe by
   construction, myopic.
4. **Dynamic Programming** — value iteration / backward induction; exact optimality;
   curse of dimensionality (k-level discretization → k^156 states); tractable variants
   (subset-state DP for ≤ ~20 skills; full DP on the 5-skill toy env).
5. **Reinforcement Learning** — DQN (replay buffer, target network; mirrors task 15) and
   PPO (clipped surrogate; when preferable); action masking for hard constraints;
   simulator requirement and sim-to-real gap.
6. **Comparison table** — optimality, training cost, inference cost, data requirements,
   constraint guarantees, explainability, scalability.
7. **Experiment definition for task 15** — on the same ToyLearnerEnv, run DQN + a DP
   value-iteration solver (discretized) + the greedy policy + random; metrics: mean
   return, time-to-goal (episode length), wall-clock cost. Numbers land when task 15
   executes.
8. **Recommendation** — greedy in production, DP as toy-scale gold standard, RL as the
   research direction; justifies the repo's existing choices.
9. **References** — Bellman; Sutton & Barto; Mnih et al. 2015 (DQN); Schulman et al.
   2017 (PPO); Lenstra & Rinnooy Kan (precedence-constrained scheduling complexity).

Depth: moderate math (state the Bellman optimality equation and the key update rules;
no convergence proofs or sample-complexity derivations).

### 2. `docs/system-architecture.md` (new — Đầu ra part 3)

1. **Stack overview & rationale** — React SPA (planned) → application backend →
   PostgreSQL, plus a separate Python ML serving tier. Justification: models from
   Mảng 1 & 2 are Python-ecosystem (PyTorch, Gemini SDK, Whisper), so FastAPI is the AI
   backend (the Python role the requirement names), while ASP.NET Core handles the
   application layer. Include a requirement-mapping table (Python ML libs / FastAPI /
   React / PostgreSQL → how each is fulfilled).
2. **Component diagram** (mermaid) — includes the fail-soft rule: ML service down →
   503 for AI features, core features keep working.
3. **PostgreSQL schema** — actual entities verified against the EF Core model at writing
   time; then "tối ưu cho truy vấn phục vụ mô hình": indexes and query patterns feeding
   each model (interaction sequences for KT, mastery lookups for path building, due-card
   queries for FSRS).
4. **Data flows** — placement (CAT loop), practice → mastery update, path generation,
   review scheduling, RAG advisor; step-by-step with exact endpoints.
5. **Integration map** — 5 AI modules ↔ components ↔ endpoints; Mảng 1/2/3 ownership
   column marked TBD.
6. **Frontend architecture (proposal)** — SPA structure, TanStack Query for server
   state + light client state, API client layer, key screens from `MVP_architecture.md`.
7. **Deployment & dev environment** — docker-compose PostgreSQL, local GPU,
   env vars (`QG_KT_CHECKPOINT`, `QG_RAG_INDEX`, `GEMINI_API_KEY`), ports 5000/8001.

### 3. Navigation / project-docs updates

- **Root `README.md`** (currently one line): project overview paragraph, repo layout,
  AI feature table, links into `docs/`, run pointers (docker-compose + dotnet + uvicorn).
- **New `docs/README.md`**: index of the three theory docs with one-line descriptions,
  plus a table mapping docs → theory-requirement areas (Mảng 3 → the two new docs;
  Mảng 1 & 2 material → `ai-theory-and-algorithms.md`).
- **`docs/ai-theory-and-algorithms.md`**: surgical edits only — cross-links from §5 and
  §8 to the optimization doc; a note in the header table. No content rewrites.
- **SDD progress ledger** (`src/backend/.superpowers/sdd/progress.md`): append a session
  entry for this docs work.

## Writing conventions

- English prose; Vietnamese key terms in italics at first use, e.g. "combinatorial
  optimization *(tối ưu tổ hợp)*".
- Only measured numbers, cited from `ml/reports/`; planned work explicitly labeled
  "planned"; no invented benchmark figures.
- References section at the end of each doc; file paths relative to repo root.

## Out of scope

- No new code (the DP solver / greedy-on-toy-env comparison runs as part of task 15).
- No React implementation — frontend section is a proposal only.
- No changes to `.claude/` task files or to the Vietnamese requirement files.
- No translation to Vietnamese (user handles this for the report).

## Success criteria

- Each of the three "Đầu ra" parts maps to a specific doc section the user can point to.
- A reader new to the project can go README → docs/README → theory docs without dead ends.
- The comparison section answers "độ chính xác vs chi phí tính toán" for all three
  methods with complexity classes and literature, and names the exact experiment that
  will produce numbers.
- Nothing in the new docs contradicts `ai-theory-and-algorithms.md` or the code.
