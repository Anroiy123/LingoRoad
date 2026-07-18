import io
from functools import lru_cache
from fastapi import APIRouter, UploadFile, Form
from lingoroad_ml.speech.scoring import word_scores, fluency_from_wpm

router = APIRouter()

FEEDBACK_PROMPT = """Học viên đọc câu: "{expected}"
Whisper nghe được: "{transcript}". Các từ bị thiếu/sai: {missing}.
Viết 2-3 câu phản hồi tiếng Việt: khen điểm tốt, chỉ ra từ cần luyện,
gợi ý cách phát âm (chú ý lỗi phổ biến của người Việt như /th/, âm cuối)."""

@lru_cache
def _whisper():
    """Local faster-whisper. "small" fits easily in the 4060's 8 GB; CPU fallback for dev boxes."""
    from faster_whisper import WhisperModel
    try:
        return WhisperModel("small", device="cuda", compute_type="float16")
    except Exception:
        return WhisperModel("small", device="cpu", compute_type="int8")

@router.post("/speech/score")
async def speech_score(file: UploadFile, prompt_text: str = Form(...)):
    from lingoroad_ml.serving.llm_routes import _client
    audio = io.BytesIO(await file.read())
    segments, info = _whisper().transcribe(audio, language="en")
    transcript = " ".join(seg.text.strip() for seg in segments)
    duration = max(info.duration or 0.0, 0.1)

    s = word_scores(prompt_text, transcript)
    wpm = len(transcript.split()) / (duration / 60.0)
    fluency = fluency_from_wpm(wpm)
    total = round(0.6 * s["accuracy"] + 0.2 * s["completeness"] + 0.2 * fluency, 3)

    fb = _client().chat.completions.create(model="gemini-2.5-flash", temperature=0.4, messages=[
        {"role": "user", "content": FEEDBACK_PROMPT.format(
            expected=prompt_text, transcript=transcript,
            missing=", ".join(s["missing_words"]) or "không có")}])
    return {"transcript": transcript, "accuracy": s["accuracy"],
            "completeness": s["completeness"], "fluency": fluency,
            "total": total, "feedback_vi": fb.choices[0].message.content}
