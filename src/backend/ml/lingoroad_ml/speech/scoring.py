"""Word-level speaking scores from an expected prompt vs ASR transcript."""
import re
from difflib import SequenceMatcher

def _words(text: str) -> list[str]:
    return re.findall(r"[a-z']+", text.lower())

def word_scores(expected: str, transcript: str) -> dict:
    exp, got = _words(expected), _words(transcript)
    if not exp:
        return {"accuracy": 0.0, "completeness": 0.0, "missing_words": []}
    sm = SequenceMatcher(a=exp, b=got)
    matched_idx = set()
    for block in sm.get_matching_blocks():
        matched_idx.update(range(block.a, block.a + block.size))
    missing = [exp[i] for i in range(len(exp)) if i not in matched_idx]
    return {
        "accuracy": round(len(matched_idx) / len(exp), 3),
        "completeness": round(min(len(got) / len(exp), 1.0), 3),
        "missing_words": missing,
    }

def fluency_from_wpm(wpm: float) -> float:
    """1.0 in the natural 100-160 wpm band, tapering linearly outside."""
    if wpm <= 0:
        return 0.0
    if 100 <= wpm <= 160:
        return 1.0
    if wpm < 100:
        return round(wpm / 100.0, 3)
    return round(max(0.0, 1.0 - (wpm - 160) / 140.0), 3)
