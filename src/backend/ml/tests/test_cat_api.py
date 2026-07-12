from fastapi.testclient import TestClient
from lingoroad_ml.serving.app import app

client = TestClient(app)

def test_cat_select_returns_theta_and_next_item():
    body = {
        "history": [{"a": 1.0, "b": 0.0, "c": 0.25, "correct": True}],
        "candidates": [
            {"item_id": "11111111-1111-1111-1111-111111111111", "a": 1.2, "b": 0.3, "c": 0.25},
            {"item_id": "22222222-2222-2222-2222-222222222222", "a": 1.2, "b": -2.5, "c": 0.25},
        ],
    }
    r = client.post("/cat/select", json=body)
    assert r.status_code == 200
    data = r.json()
    assert {"theta", "se", "next_item_id"} <= data.keys()
    assert data["next_item_id"] == "11111111-1111-1111-1111-111111111111"

def test_cat_select_empty_candidates_returns_null_item():
    r = client.post("/cat/select", json={"history": [], "candidates": []})
    assert r.status_code == 200
    assert r.json()["next_item_id"] is None
