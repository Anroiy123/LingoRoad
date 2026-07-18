from lingoroad_ml.speech.scoring import word_scores, fluency_from_wpm

def test_perfect_match_scores_one():
    s = word_scores("I have lived here for two years", "I have lived here for two years")
    assert s["accuracy"] == 1.0 and s["completeness"] == 1.0 and s["missing_words"] == []

def test_missing_words_lower_accuracy_and_are_listed():
    s = word_scores("I have lived here for two years", "I lived here two years")
    assert 0 < s["accuracy"] < 1
    assert "have" in s["missing_words"] and "for" in s["missing_words"]

def test_case_and_punctuation_ignored():
    s = word_scores("Hello, world!", "hello world")
    assert s["accuracy"] == 1.0

def test_fluency_peaks_in_natural_range_and_clamps():
    assert fluency_from_wpm(130) == 1.0
    assert 0 <= fluency_from_wpm(30) < 1.0
    assert 0 <= fluency_from_wpm(300) < 1.0
    assert fluency_from_wpm(0) == 0.0
