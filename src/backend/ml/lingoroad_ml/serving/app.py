from fastapi import FastAPI
from pydantic import BaseModel
from lingoroad_ml.cat import select_next
from lingoroad_ml.irt import eap_estimate
from lingoroad_ml.serving.kt_routes import router as kt_router
from lingoroad_ml.serving.llm_routes import router as llm_router
from lingoroad_ml.serving.speech_routes import router as speech_router

app = FastAPI(title="LingoRoad ML Service")
app.include_router(kt_router)
app.include_router(llm_router)
app.include_router(speech_router)

class HistoryEntry(BaseModel):
    a: float; b: float; c: float; correct: bool

class Candidate(BaseModel):
    item_id: str; a: float; b: float; c: float

class CatSelectRequest(BaseModel):
    history: list[HistoryEntry]
    candidates: list[Candidate]

class CatSelectResponse(BaseModel):
    theta: float; se: float; next_item_id: str | None

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/cat/select", response_model=CatSelectResponse)
def cat_select(req: CatSelectRequest):
    theta, se = eap_estimate([(h.a, h.b, h.c, h.correct) for h in req.history])
    next_id = select_next(theta, [(c.item_id, c.a, c.b, c.c) for c in req.candidates])
    return CatSelectResponse(theta=theta, se=se, next_item_id=next_id)
