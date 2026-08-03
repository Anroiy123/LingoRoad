# API Catalog — LingoRoad ML Service

Base URL (dev): `http://localhost:8001`. App defined in
`lingoroad_ml/serving/app.py` (`FastAPI(title="LingoRoad ML Service")`),
which includes three routers (`kt_router`, `llm_router`, `speech_router`);
`/health` and `/cat/select` are defined directly on `app`.

This service is called **only** by the `.NET` API's `MlClient` (see
`../backend/auth-and-integrations.md`) — it has no auth of its own and is
not meant to be internet-facing.

| Verb | Path | Defined in | Request | Response |
|---|---|---|---|---|
| GET | `/health` | `serving/app.py` | — | `{"status": "ok"}` |
| POST | `/cat/select` | `serving/app.py` | `{history: [{a, b, c, correct}], candidates: [{item_id, a, b, c}]}` | `{theta, se, next_item_id}` — runs `irt.eap_estimate` then `cat.select_next` |
| POST | `/kt/predict` | `serving/kt_routes.py` | `{sequence: [{q_idx, part, correct, elapsed, lag}]}` | `{"p_next": [float, ...]}` (one prob per event, truncated to the checkpoint's `seq_len`, default 100) / **503** `{"error":"model_not_loaded"}` if no checkpoint |
| POST | `/llm/advisor` | `serving/llm_routes.py` | `{question, path: [{code, name, mastery, reason}], locale: "vi"}` | `{"answer": str}` — `rag.retrieve` (k=3) against `QG_RAG_INDEX`, then `llm.advisor.answer` (gemini-2.5-flash, temp 0.4). Missing index file → empty retrieval, not an error |
| POST | `/llm/exercises` | `serving/llm_routes.py` | `{skill_code, skill_name, cefr, type: "mcq", count: 3}` | `{"exercises": [{stem, options, correct_answer, explanation_vi}, ...]}` — `llm.exercises.generate` (gemini-2.5-flash, temp 0.7, forced JSON) |
| POST | `/llm/awe` | `serving/llm_routes.py` | `{task_prompt, essay}` | `{"scores": {task_achievement, coherence_cohesion, lexical_resource, grammatical_accuracy}, "feedback": [{sentence, issue, suggestion}], "overall_vi": str}` — `llm.awe.evaluate` (gemini-2.5-flash, temp 0.2, forced JSON) |
| POST | `/speech/score` | `serving/speech_routes.py` | multipart: `file` (audio) + `prompt_text` (form) | `{"transcript", "accuracy", "completeness", "fluency", "total", "feedback_vi"}` — faster-whisper "small" (CUDA fp16, falls back to CPU int8), `speech.scoring` scores it, gemini-2.5-flash writes Vietnamese feedback (falls back to a static string on any LLM exception — never errors on the feedback step) |

## Error-handling notes
- Only `/kt/predict` has an explicit in-route 503 (`model_not_loaded`).
  `/llm/*` routes have **no** explicit degrade-to-503 logic here — the
  `.NET`-side "`503 ml_service_unavailable`" behavior documented in
  `docs/system-architecture.md` happens when the **whole service** is
  unreachable/times out, handled entirely by `MlClient.cs` on the `.NET`
  side, not by anything in this file.
- No `/rl/*` or `/dqn/*` route exists — the RL module (`lingoroad_ml/rl/`)
  is research-only and is never served over HTTP.

## Shared Gemini client
`llm_routes._client()` (`@lru_cache`) is the one shared Gemini
OpenAI-compatible client, reused by `speech_routes.py` (imported directly:
`from lingoroad_ml.serving.llm_routes import _client`). `llm/rag.py`'s
`gemini_embed()` builds its **own** client independently — not the same
instance as `_client()`.
