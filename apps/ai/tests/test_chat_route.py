"""POST /chat route: routing + response wiring (agent.py + irt + api/chat.py).

Uses FakeLlmClient (no live Mistral). Each turn makes two LLM calls — routing
then response — so each test enqueues responses in that order.
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
    yield TestClient(app), fake_llm
    app.dependency_overrides.pop(get_llm_client, None)


def _route(stage: str) -> str:
    return json.dumps({"stage": stage, "confidence": 0.9})


def test_recording_turn_returns_text(client):
    tc, fake = client
    fake.enqueue(_route("recording"))  # routing agent
    fake.enqueue("Tell me what happened in the dream.")  # response agent

    r = tc.post(
        "/chat",
        json={
            "messages": [{"role": "user", "content": "I had a nightmare", "stage": "recording"}],
            "language": "en",
        },
    )

    assert r.status_code == 200
    body = r.json()
    assert body["stage"] == "recording"
    assert body["response"] == "Tell me what happened in the dream."
    assert body["structured"] is None
    assert body["prompt_version"] == "prompts-en-v1.1.0"


def test_illegal_jump_is_enforced_back(client):
    tc, fake = client
    # Routing hallucinates a jump straight to rewriting without intensity ever
    # visited; irt.enforce_transition must redirect to intensity.
    fake.enqueue(_route("rewriting"))
    fake.enqueue("On a scale from 0 to 10, how intense was it?")

    r = tc.post(
        "/chat",
        json={
            "messages": [{"role": "user", "content": "a dark forest", "stage": "recording"}],
            "language": "en",
        },
    )

    assert r.status_code == 200
    assert r.json()["stage"] == "intensity"


def test_summary_emits_structured(client):
    tc, fake = client
    fake.enqueue(_route("summary"))
    fake.enqueue(
        json.dumps(
            {
                "title": "Calm Forest",
                "rewritten_summary": "You walk through a sunlit clearing, feeling calm.",
                "original_summary": "You are chased through a dark forest.",
            }
        )
    )

    r = tc.post(
        "/chat",
        json={
            "messages": [
                {"role": "user", "content": "dream", "stage": "recording"},
                {"role": "assistant", "content": "rate it", "stage": "intensity"},
                {"role": "user", "content": "7", "stage": "intensity"},
                {"role": "assistant", "content": "let's rewrite", "stage": "rewriting"},
                {"role": "user", "content": "yes summarize", "stage": "rewriting"},
            ],
            "language": "en",
        },
    )

    assert r.status_code == 200
    body = r.json()
    assert body["stage"] == "summary"
    assert body["structured"]["title"] == "Calm Forest"
    assert body["structured"]["rewritten_summary"].startswith("You walk")
    # Backend reads dream_summary first for the original_dream column.
    assert body["structured"]["dream_summary"] == body["structured"]["original_summary"]
    assert "Calm Forest" in body["response"]


def test_empty_messages_rejected(client):
    tc, _ = client
    r = tc.post("/chat", json={"messages": [], "language": "en"})
    assert r.status_code == 400
