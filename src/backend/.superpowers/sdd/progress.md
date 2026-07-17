# SDD progress ledger — LingoRoad plan

## Session 2026-07-18 (task 12 fully complete — Gemini blocker cleared)
- User topped up Gemini credits ("continue with gemini"). Verified with a 1-string
  gemini-embedding-001 call (OK, 3072-dim) before spending on the full build.
- Task-12 step 5 remainder DONE: (a) RAG index built — `python -m research.build_rag_index`
  over the 12 corpus guides → ml/data/corpus_index.npz + .chunks.json (gitignored);
  (b) live e2e advisor check — fresh user advisor-demo@lingoroad.test, GET /path sane
  (A1-first, not_started), POST /path/advisor returned a grounded Vietnamese answer
  citing the present_simple.md corpus content; sample committed 330acf1
  (ml/reports/samples/advisor.md). Task 12 is now COMPLETE end to end.
- Gotchas hit: (1) `dotnet run --no-launch-profile` breaks the API — JWT secret +
  connection string live in appsettings.Development.json, so run with
  `dotnet run --launch-profile http` (sets ASPNETCORE_ENVIRONMENT=Development);
  (2) Vietnamese JSON bodies get mangled as inline curl -d args on Windows —
  write the body to a UTF-8 file and use `--data-binary @file`.
- 2026-07-13 Gemini blocker CLEARED for all tasks. Next per task order: task-13
  (exercise generation & AWE, superpowers flow per user preference), then 14, 16.

## Session 2026-07-17 (task 15 completed)
- Superpowers flow per user request: brainstorm → spec 107cbb4 → plan c549342
  (docs/superpowers/{specs,plans}/2026-07-17-task15-dqn-poc*) → inline execution.
  NOTE: superpowers plugin skills exist in the plugin cache but are NOT registered with
  the session's Skill tool — read SKILL.md from
  ~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.6/skills/ and follow manually.
- Task 15: COMPLETE, well inside the 4-day box — 4d37487 (env), 59ec908 (dqn),
  0c895bf (dp), 13c394f (experiment + reports), 826456b (doc §6.1/§7).
  Measured (100 eps, seed 123): DP 0.636 > DQN 0.581 > greedy 0.533 > random 0.197 —
  expected ordering held. Artifacts: ml/reports/dqn_poc.{png,md};
  docs/learning-path-optimization.md §6.1 measured table.
- Findings (all documented in dp.py docstring + spec/plan amendments b2eb61f):
  (a) task-file DQN sketch has a SyntaxError (walrus on attribute) — fixed;
  (b) §7's nearest-grid rounding is degenerate at k=11 (goal unreachable in rounded
  chain, +1 bonus invisible; DP measured BELOW greedy) — replaced with multilinear
  interpolation (Kushner–Dupuis) + goal bonus on arrival in the goal set;
  (c) goal unreachable at n=5 within the 60-step cap for ANY policy (decay 0.025/step
  outpaces late gains; needs ~80–90 steps) — comparison decided by mastery-growth
  efficiency; fixed-order greedy is NOT near-optimal under forgetting (DQN +9%, DP +19%).
- Tests: ml 31 passed (24 existing + 7 new in tests/test_rl.py). .NET untouched.
- Next per task order: task-16 (demo e2e). Tasks 12-step-5 / 13 / 14 still BLOCKED on
  Gemini credits (2026-07-13 blocker unchanged).

## Session 2026-07-15 (theory Mảng-3 docs)
- User owns theory Mảng 3 = the whole of src/backend/.claude/theory-reqquirement.md
  (optimization + infrastructure). Brainstormed via superpowers; spec committed 10e74a2
  (docs/superpowers/specs/2026-07-15-theory-section3-docs-design.md).
- Written: docs/learning-path-optimization.md (problem spec, Greedy vs DP vs RL,
  task-15 experiment protocol), docs/system-architecture.md (hybrid .NET+FastAPI+Postgres
  documented as-is per user choice), docs/README.md index, root README.md rewrite,
  cross-links in docs/ai-theory-and-algorithms.md.
- Decisions: EN docs with VN key terms (user translates for report); Mảng 1/2 split TBD
  (integration written against the 5 modules); theory now, measured numbers when task 15
  runs.
- Task 15 gains a comparison duty: DP value-iteration (k=11 grid) + greedy + random vs
  DQN on ToyLearnerEnv; protocol in learning-path-optimization.md §7; code goes under
  ml/lingoroad_ml/rl/ (task file predates rename).
- Task-1 doc revised after quality review (table pipe escape, src/backend/ path
  prefixes, greedy-equivalence correction, discretized-DP hedging, goal-reach-rate
  metric); plan updated in lockstep.
- Task-2 doc corrected post-review (Skills table = 174 nodes: 156 leaves + 18
  containers); later reviews done inline after a session-limit hit killed a reviewer
  subagent.
- Gemini credit blocker from 2026-07-13 still stands (unrelated to this docs work).

## Session 2026-07-13 later (task 12 code complete, step 5 BLOCKED; resume here)
- Task 12: CODE COMPLETE — 6244887 (PathBuilder + CefrMap.Rank, GET /path, POST /path/advisor
  w/ 503 degradation, MlClient.AdvisorAsync; Python lingoroad_ml/llm/{rag,advisor}.py +
  /llm/advisor route; env var QG_RAG_INDEX). Tests: .NET 37 passed, ml 24 passed.
  Live-checked GET /path against docker Postgres (sensible A1-first path) and advisor
  503 degradation with uvicorn down. 12 corpus guides written in ml/data/corpus/ (gitignored).
- **BLOCKER: GEMINI_API_KEY prepayment credits depleted (429 RESOURCE_EXHAUSTED).**
  Task-12 step 5 remainder needs credits: (a) cd ml && python -m research.build_rag_index
  (note: run research scripts as modules from ml/, plain path invocation can't import
  lingoroad_ml); (b) start uvicorn + API, POST /path/advisor, save a good Vietnamese answer
  to ml/reports/samples/advisor.md. Tasks 13/14 advisor-side LLM calls also blocked until topped up.
- Docs: user asked for AI theory/algorithms documentation → written to docs/ at repo root
  (C:\Projects\LingoRoad\docs\).

## Session 2026-07-13 (task 11 completed)
- Re-ran both suites before starting: ml 22 passed, .NET 25 passed (post-rename state healthy).
- Task 11: COMPLETE — d49e814 (FSRS-4.5 scheduler in C# Domain/Fsrs.cs + ReviewCard entity,
  /reviews/cards, /reviews/due, /reviews/{cardId}/grade; migration AddReviewCards applied).
  TDD followed: 5 property tests red→green, endpoint flow test red→green. Note: task files still
  say QuestGraph — paths/namespaces are LingoRoad since the f26847c rename; adapt on the fly.
- Test counts: ml 22 passed; .NET 31 passed.
- Next per task order: task-12 (learning path advisor, needs 3+10 — both done) —
  .claude/tasks/task-12-learning-path-advisor.md. Then 13, 14, 15, 16.
- Environment: docker db lingoroad-db-1 running (was stopped, restarted this session);
  DB schema current through AddReviewCards. NuGet NU1903 warnings: Microsoft.OpenApi 2.0.0 and
  SQLitePCLRaw.lib.e_sqlite3 2.1.11 have known vulns — bump when convenient.

## Session end 2026-07-10 (tasks 5-10 completed)
- Tasks 1-4: COMPLETE (see git history; 617 items / 156 skills in DB, audio 0b278a6).
- Task 5: COMPLETE — b49d767 (IRT 3PL + EAP + max-info, FastAPI /cat/select, .NET MlClient).
- Task 6: COMPLETE — 52029d8 (placement sessions e2e; migration AddTestSessions applied).
- Task 7: COMPLETE — c70e604 (CAT sim: exact CEFR acc 0.750 @ mean 18.5 items vs Fixed-30 0.672;
  evidence ml/reports/cat_simulation.{png,md}).
- Task 8: COMPLETE — 6838ab1 (EdNet KT1 pipeline). Local data: ml/data/ednet/ has KT1.zip + contents.zip
  downloaded (bit.ly/ednet_kt1 → Google Drive, via gdown), 60k user CSVs extracted, interactions.parquet
  = 7,504,848 rows / 60,000 users / 13,169 questions / mean_correct 0.654. NOTE: torch installed from
  cu128 index (cu121 in task file has no Python 3.13 wheels) — torch 2.11.0+cu128, RTX 4060 verified.
  Fixed real bug: lag feature promoted to float64 by np.log1p(1440.0) scalar division → broke AMP;
  dtype regression test added in test_kt_data.py.
- Task 9: COMPLETE — 6c03eaf. AUC table (ml/reports/kt_results.md, 5 epochs each, equal budget):
  saint_plus 0.7586 test > dkt 0.7565 > dkvmn 0.7558 (target ≥0.75 met; leakage test green).
  Checkpoints in ml/checkpoints/{dkt,dkvmn,saint_plus}.pt (gitignored). Training was FAST on this rig:
  SAINT+ ~21s/epoch, DKT ~7s, DKVMN ~145s — full 3-model suite ≈ 15 min, not overnight.
- Task 10: COMPLETE — 824c4da (MasteryCalc EMA+decay, MasteryService, /mastery endpoint, placement hook,
  migration AddMastery applied; Python /kt/predict serving SAINT+ checkpoint via QG_KT_CHECKPOINT env).
  Live-checked /kt/predict with trained checkpoint: sensible probabilities (0.92 after corrects, 0.55 after wrong).
- Test counts: ml 22 passed; .NET 25 passed.
- Next per task order: task-11 (FSRS review queue, sprint 3) — .claude/tasks/task-11-fsrs-review-queue.md.
  Then task-12 (needs 3,10 — both done), 13, 14, 15, 16.
- Conventions: TDD per task file, commits with EXPLICIT paths (never `git add -A`),
  never commit .claude/ ml/data/ ml/checkpoints/ ml/.venv/.
- Environment: docker db lingoroad-db-1 running; .NET API and uvicorn NOT running; ports 5000/8001 free.
  DB schema current through AddMastery. To serve KT: set QG_KT_CHECKPOINT=ml/checkpoints/saint_plus.pt
  before starting uvicorn from repo root (default relative path resolves wrong from there).
