# SDD progress ledger — LingoRoad plan

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
