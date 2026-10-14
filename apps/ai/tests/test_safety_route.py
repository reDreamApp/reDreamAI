"""POST /safety/classify — crisis pre-classifier (ADR 0005).

This path is independent of the ported IRT core and must keep working after the
core replacement. Uses FakeLlmClient via the DI override (no network).
"""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

from redream_ai.api.chat import get_llm_client
from redream_ai.main import app


@pytest.fixture
def client(fake_llm):
    app.dependency_overrides[get_llm_client] = lambda: fake_llm
    with TestClient(app) as c:
        yield c, fake_llm
    app.dependency_overrides.pop(get_llm_client, None)


def test_safety_classify_low_risk(client):
    tc, fake = client
    fake.enqueue(json.dumps({"risk": "none", "categories": [], "confidence": 0.95}))
    r = tc.post("/safety/classify", json={"text": "I dreamt of a calm forest.", "language": "en"})
    assert r.status_code == 200
    body = r.json()
    assert body["risk"] == "none"
    assert body["categories"] == []


def test_safety_classify_high_risk(client):
    tc, fake = client
    fake.enqueue(
        json.dumps({"risk": "high", "categories": ["suicidal_ideation"], "confidence": 0.9})
    )
    r = tc.post(
        "/safety/classify",
        json={"text": "I don't want to be here anymore.", "language": "en"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["risk"] == "high"
    assert "suicidal_ideation" in body["categories"]


def test_safety_empty_text_rejected(client):
    tc, _ = client
    r = tc.post("/safety/classify", json={"text": "   ", "language": "en"})
    assert r.status_code == 400


def test_safety_trace_tagged_with_session_and_user(client, monkeypatch):
    """session_id/user_id must reach the Langfuse trace — the GDPR purge
    deletes traces by userId, so an untagged trace is an unerasable one."""
    import redream_ai.observability as obs

    captured = {}

    def fake_start_trace(name, *, session_id=None, user_id=None, **kwargs):
        captured["session_id"] = session_id
        captured["user_id"] = user_id
        return None

    monkeypatch.setattr(obs, "start_trace", fake_start_trace)

    tc, fake = client
    fake.enqueue(json.dumps({"risk": "none", "categories": [], "confidence": 0.9}))
    r = tc.post(
        "/safety/classify",
        json={
            "text": "I dreamt of a calm forest.",
            "language": "en",
            "session_id": "42",
            "user_id": "user-abc",
        },
    )
    assert r.status_code == 200
    assert captured == {"session_id": "42", "user_id": "user-abc"}


@pytest.mark.parametrize("text", ["ja", "Yes.", "yes, exactly", "Nein!", "ja genau"])
def test_bare_answer_skips_the_model(client, text):
    """A plain yes / no is never a risk signal: "Hat er dich gewürgt?" → "ja"
    came back high and showed the helpline instead of a reply (2026-10-14)."""
    tc, fake = client
    r = tc.post(
        "/safety/classify",
        json={
            "text": text,
            "language": "de",
            "stage": "recording",
            "context": "Hat er dich gewürgt?",
        },
    )
    assert r.status_code == 200
    assert r.json()["risk"] == "none"
    assert fake.calls == []


@pytest.mark.parametrize("text", ["8", "yes he did", "yes yes yes yes", "ja, ich will sterben"])
def test_other_short_replies_reach_the_model(client, text):
    tc, fake = client
    fake.enqueue(json.dumps({"risk": "none", "categories": [], "confidence": 0.9}))
    r = tc.post("/safety/classify", json={"text": text, "language": "en"})
    assert r.status_code == 200
    assert len(fake.calls) == 1


@pytest.mark.parametrize(
    ("stage", "labelled"),
    [("recording", True), ("rewriting", True), ("summary", True), ("final", False)],
)
def test_context_marked_as_about_the_dream(client, stage, labelled):
    tc, fake = client
    fake.enqueue(json.dumps({"risk": "none", "categories": [], "confidence": 0.9}))
    tc.post(
        "/safety/classify",
        json={
            "text": "he did it again",
            "language": "en",
            "stage": stage,
            "context": "What happens next?",
        },
    )
    user_turn = fake.calls[0]["messages"][1]["content"]
    assert ("(about the user's dream)" in user_turn) is labelled
    assert "What happens next?" in user_turn
