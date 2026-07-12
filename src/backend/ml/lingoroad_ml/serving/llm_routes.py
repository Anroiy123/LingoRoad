import os
from functools import lru_cache
from pathlib import Path
from fastapi import APIRouter
from pydantic import BaseModel
from lingoroad_ml.llm import advisor, rag

router = APIRouter()
INDEX = Path(os.environ.get("QG_RAG_INDEX", "data/corpus_index.npz"))

@lru_cache
def _client():
    from openai import OpenAI
    return OpenAI(api_key=os.environ["GEMINI_API_KEY"],
                  base_url="https://generativelanguage.googleapis.com/v1beta/openai/")

class PathEntry(BaseModel):
    code: str; name: str; mastery: float; reason: str

class AdvisorReq(BaseModel):
    question: str
    path: list[PathEntry]
    locale: str = "vi"

@router.post("/llm/advisor")
def llm_advisor(req: AdvisorReq):
    def retrieve_fn(q):
        if not INDEX.exists():
            return []
        return rag.retrieve(q, INDEX, embed_fn=rag.gemini_embed, k=3)
    text = advisor.answer(req.question, [p.model_dump() for p in req.path],
                          retrieve_fn, _client())
    return {"answer": text}
