# Task 16: Demo Seed, E2E Smoke, Report Evidence

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: all previous tasks. Sprint 3 close-out.

**Files:**
- Create: `ml/research/e2e_smoke.py`, `ml/reports/EVIDENCE.md`
- Modify: `README.md` (repo root — create it; currently missing)

**Interfaces:**
- Consumes: every endpoint from tasks 2–14, both services running, seeded item bank.
- Produces: a one-command smoke script proving the whole system works; a checklist of all practicum-report artifacts.

- [ ] **Step 1: Write the e2e smoke script**

`ml/research/e2e_smoke.py` — drives a full learner journey against live services. Uses `GET /items` (dev-only diagnostics data) to answer placement items correctly, simulating a strong learner.

```python
"""End-to-end smoke test. Prereqs: docker db up, API on :5000, ML service on :8001,
item bank imported, GEMINI_API_KEY set. Usage:
  python ml/research/e2e_smoke.py --api http://localhost:5000 [--skip-llm]
"""
import argparse, sys, uuid
import httpx

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", default="http://localhost:5000")
    ap.add_argument("--skip-llm", action="store_true",
                    help="skip advisor/exercises/AWE (no GEMINI_API_KEY)")
    args = ap.parse_args()
    c = httpx.Client(base_url=args.api, timeout=60)
    ok = lambda r: (r.raise_for_status(), r.json())[1]

    # 1. register + login
    email = f"smoke-{uuid.uuid4().hex[:8]}@test.com"
    tok = ok(c.post("/auth/register", json={"email": email, "password": "secret123",
                                            "name": "Smoke"}))["token"]
    c.headers["Authorization"] = f"Bearer {tok}"
    print("[1] auth ok")

    # 2. answer key from the diagnostics item listing
    answers = {i["id"]: i["correctAnswer"] for i in ok(c.get("/items"))}
    assert len(answers) >= 100, f"item bank too small: {len(answers)}"
    print(f"[2] item bank: {len(answers)} items")

    # 3. adaptive placement, always correct
    state = ok(c.post("/placement/start"))
    session, item_id = state["sessionId"], state["item"]["id"]
    n = 0
    while True:
        step = ok(c.post(f"/placement/{session}/answer",
                         json={"itemId": item_id, "answer": answers[item_id]}))
        n += 1
        assert n <= 30, "stop rule violated"
        if step["done"]:
            break
        item_id = step["item"]["id"]
    result = ok(c.get(f"/placement/{session}/result"))
    assert 8 <= result["itemsAnswered"] <= 30
    print(f"[3] placement: {result['itemsAnswered']} items -> {result['cefr']} "
          f"(theta {result['theta']:.2f})")

    # 4. mastery + path
    print(f"[4] mastery rows: {len(ok(c.get('/mastery')))}")
    path = ok(c.get("/path"))
    assert path, "empty learning path"
    print(f"[5] path: next = {path[0]['code']}")

    # 5. reviews (FSRS)
    ok(c.post("/reviews/cards", json={"skillCode": path[0]["code"],
                                      "front": "hello", "back": "xin chào"}))
    due = ok(c.get("/reviews/due"))
    graded = ok(c.post(f"/reviews/{due[0]['id']}/grade", json={"rating": 3}))
    assert not ok(c.get("/reviews/due")), "card still due after Good"
    print(f"[6] FSRS: next due {graded['due']}")

    if not args.skip_llm:
        # 6. advisor, exercises, AWE (live LLM calls)
        adv = ok(c.post("/path/advisor",
                        json={"question": "Tôi nên học gì tiếp theo và tại sao?"}))
        assert len(adv["answer"]) > 20
        print(f"[7] advisor: {adv['answer'][:60]}...")

        exs = ok(c.post("/exercises/generate", json={"skillCode": path[0]["code"]}))
        sub = ok(c.post(f"/exercises/{exs[0]['id']}/submit", json={"answer": "wrong-on-purpose"}))
        assert sub["correct"] is False and sub["correctAnswer"]
        print(f"[8] exercises: generated {len(exs)}, submit scored")

        awe = ok(c.post("/writing/evaluate", json={
            "taskPrompt": "Describe your hometown.",
            "essay": "My hometown is Da Nang. It have many beautiful beach."}))
        assert "scores" in awe and awe["overallVi"]
        print(f"[9] AWE: TA={awe['scores']['taskAchievement']}")

    print("SMOKE OK")

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it**

```powershell
docker compose up -d db
Start-Process ml/.venv/Scripts/uvicorn -ArgumentList "questgraph_ml.serving.app:app --port 8001 --app-dir ml"
dotnet run --project QuestGraph   # in a second terminal
$env:PYTHONPATH = "ml"
ml/.venv/Scripts/python ml/research/e2e_smoke.py --api http://localhost:5000
```

Expected: all numbered checks print, ends with `SMOKE OK`. (Speaking is exercised manually in task-14 Step 5 — multipart upload needs a real audio file.) Fix anything that fails before proceeding; this script is the demo-day dry run.

- [ ] **Step 3: Assemble the evidence checklist**

`ml/reports/EVIDENCE.md`:

```markdown
# Practicum Report Evidence Checklist

| # | Artifact | Source | Requirement section |
|---|----------|--------|---------------------|
| 1 | Question bank: N items, 6 CEFR levels, 5 skills, seeded IRT params | `GET /items`, `ml/data/items.json` | 1.1 |
| 2 | CAT simulation: accuracy table + plots | `ml/reports/cat_simulation.{md,png}` | 1.1 |
| 3 | KT AUC table: SAINT+ vs DKT vs DKVMN | `ml/reports/kt_results.md` | 1.2 |
| 4 | Knowledge graph: 150 micro-skills + prerequisites | `GET /skills/graph`, `skills.json` | 1.2 |
| 5 | Live SAINT+ inference | `POST /kt/predict` demo | 1.2 |
| 6 | Rule-based path + FSRS schedule | `GET /path`, `/reviews/*` demo | 1.3 |
| 7 | DQN PoC learning curve | `ml/reports/dqn_poc.{md,png}` | 1.3 |
| 8 | Advisor sample (Vietnamese, RAG) | `ml/reports/samples/advisor.md` | 1.3 |
| 9 | Generated exercises + distractors sample | `ml/reports/samples/exercises.md` | 1.4 |
| 10 | AWE sample (IELTS rubric, Vietnamese feedback) | `ml/reports/samples/awe.md` | 1.4 |
| 11 | Speaking assessment sample | `ml/reports/samples/speaking.md` | 1.5 |
| 12 | E2E smoke run transcript | `e2e_smoke.py` output | system |

Honest-limitations paragraph for the report: IRT params heuristically seeded (V-2);
KT vocabulary gap bridged by EMA mastery (task-10 note); AWE is LLM-as-judge, not a
fine-tuned model (V-6); speaking has no phoneme-level GOP (V-7); DQN is a toy-scale PoC.
```

Verify every referenced artifact exists; run any missing sample-collection steps from tasks 12–14.

- [ ] **Step 4: Write the root README**

`README.md` — quick start (docker db, venv, both run commands, test commands), architecture diagram (copy from `.claude/tasks/README.md` layout block), and a link-out table of the five modules. Keep under 80 lines.

- [ ] **Step 5: Final commit**

```powershell
git add -A
git commit -m "chore: e2e smoke script, evidence checklist, README"
```
