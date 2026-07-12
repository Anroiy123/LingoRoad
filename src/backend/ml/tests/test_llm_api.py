from lingoroad_ml.llm.advisor import build_messages

def test_messages_include_path_and_context_in_vietnamese_frame():
    msgs = build_messages("Tại sao học present perfect?",
                          [{"code": "pp", "name": "Present Perfect",
                            "mastery": 0.35, "reason": "below_threshold"}],
                          ["Present perfect connects past and present."])
    assert msgs[0]["role"] == "system" and "tiếng Việt" in msgs[0]["content"]
    body = msgs[1]["content"]
    assert "Present Perfect" in body and "0.35" in body and "connects past" in body
