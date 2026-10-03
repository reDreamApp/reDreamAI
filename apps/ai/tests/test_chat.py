"""POST /chat through the routing + response pipeline with a fake LLM."""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

from redream_ai.api.deps import get_llm_client
from redream_ai.llm.fake_client import FakeLlmClient
from redream_ai.main import app


@pytest.fixture
def client(fake_llm: FakeLlmClient) -> TestClient:
    app.dependency_overrides[get_llm_client] = lambda: fake_llm
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


def _msg(role: str, content: str, stage: str | None = None) -> dict[str, str | None]:
    return {"role": role, "content": content, "stage": stage}


def _post(client: TestClient, messages: list[dict[str, str | None]], language: str = "en"):
    return client.post("/chat", json={"messages": messages, "language": language})


def test_rejects_empty_history(client: TestClient) -> None:
    assert _post(client, []).status_code == 400


def test_first_turn_routes_and_answers_in_recording(
    client: TestClient, fake_llm: FakeLlmClient
) -> None:
    fake_llm.enqueue('{"stage": "recording", "confidence": 0.9}', input_tokens=5, output_tokens=2)
    fake_llm.enqueue(
        "That sounds frightening. What happened next?", input_tokens=50, output_tokens=9
    )

    res = _post(client, [_msg("user", "I dreamt I was lost in a forest.")])

    assert res.status_code == 200
    body = res.json()
    assert body["stage"] == "recording"
    assert body["response"] == "That sounds frightening. What happened next?"
    assert body["structured"] is None
    assert body["usage"] == {"input_tokens": 55, "output_tokens": 11}
    assert body["prompt_version"].startswith("prompts-en-v")

    routing_call, response_call = fake_llm.calls
    assert routing_call["response_format"] == {"type": "json_object"}
    assert "Current stage: recording" in routing_call["messages"][1]["content"]
    assert response_call["messages"][0]["role"] == "system"
    assert response_call["messages"][-1] == {
        "role": "user",
        "content": "I dreamt I was lost in a forest.",
    }
    assert "self-help" in response_call["messages"][0]["content"]
    assert "no markdown" in response_call["messages"][0]["content"]


def test_guardrail_blocks_skipping_intensity(client: TestClient, fake_llm: FakeLlmClient) -> None:
    fake_llm.enqueue('{"stage": "rewriting", "confidence": 0.8}')
    fake_llm.enqueue("On a scale from 0 to 10, how intense was it?")

    res = _post(
        client,
        [
            _msg("user", "A nightmare about falling."),
            _msg("assistant", "Would you like to continue?", "recording"),
            _msg("user", "yes"),
        ],
    )

    assert res.json()["stage"] == "intensity"
    assert "0 to 10" in fake_llm.calls[1]["messages"][0]["content"]


def test_unparseable_routing_keeps_current_stage(
    client: TestClient, fake_llm: FakeLlmClient
) -> None:
    fake_llm.enqueue("rewriting")
    fake_llm.enqueue("Tell me more.")

    res = _post(
        client,
        [
            _msg("user", "hi"),
            _msg("assistant", "Tell me about your dream.", "recording"),
            _msg("user", "ok"),
        ],
    )

    assert res.json()["stage"] == "recording"


def test_summary_stage_returns_structured_fields_and_rendered_text(
    client: TestClient, fake_llm: FakeLlmClient
) -> None:
    fake_llm.enqueue('{"stage": "summary", "confidence": 0.95}')
    fake_llm.enqueue(
        json.dumps(
            {
                "title": "Lantern in the Forest",
                "rewritten_dream": "You walk through the forest holding a warm lantern.",
                "original_dream": "You are lost in a dark forest and feel afraid.",
            }
        )
    )
    history = [
        _msg("user", "Lost in a dark forest, afraid."),
        _msg("assistant", "Shall we rate it?", "recording"),
        _msg("user", "yes"),
        _msg("assistant", "From 0 to 10?", "intensity"),
        _msg("user", "8"),
        _msg("assistant", "Thanks. Ready to rewrite?", "intensity"),
        _msg("user", "yes"),
        _msg("assistant", "What would you change?", "rewriting"),
        _msg("user", "I carry a lantern."),
        _msg("assistant", "You carry a lantern. Are you satisfied?", "rewriting"),
        _msg("user", "Yes, let's summarize."),
    ]

    body = _post(client, history).json()

    assert body["stage"] == "summary"
    assert body["structured"] == {
        "title": "Lantern in the Forest",
        "original_summary": "You are lost in a dark forest and feel afraid.",
        "rewritten_summary": "You walk through the forest holding a warm lantern.",
        "dream_summary": "You are lost in a dark forest and feel afraid.",
        "intensity": 8,
    }
    assert body["response"].startswith("Title: Lantern in the Forest")
    assert body["response"].endswith("Are you satisfied with the generated summary?")
    assert fake_llm.calls[1]["response_format"] == {"type": "json_object"}
    assert "JSON" in fake_llm.calls[1]["messages"][0]["content"]


def test_summary_flattens_nested_fields(client: TestClient, fake_llm: FakeLlmClient) -> None:
    """Seen live with ministral: fields came back as {"scene": "..."}."""
    fake_llm.enqueue('{"stage": "summary", "confidence": 0.95}')
    fake_llm.enqueue(
        json.dumps(
            {
                "title": "Guided Home",
                "rewritten_dream": {"scene": "An owl guides you home."},
                "original_dream": {"scene": "You are lost.", "feeling": "Afraid."},
            }
        )
    )
    history = [
        _msg("user", "dream"),
        _msg("assistant", "rate?", "intensity"),
        _msg("user", "5"),
        _msg("assistant", "change?", "rewriting"),
        _msg("user", "an owl guides me"),
        _msg("assistant", "satisfied?", "rewriting"),
        _msg("user", "done, summarize"),
    ]

    body = _post(client, history).json()

    assert body["structured"]["rewritten_summary"] == "An owl guides you home."
    assert body["structured"]["original_summary"] == "You are lost.\n\nAfraid."
    assert "{" not in body["response"]


def test_summary_without_json_passes_text_through(
    client: TestClient, fake_llm: FakeLlmClient
) -> None:
    fake_llm.enqueue('{"stage": "summary", "confidence": 0.95}')
    fake_llm.enqueue("Title: X\n\nRewritten Dream: ...")
    history = [
        _msg("user", "dream"),
        _msg("assistant", "rate?", "intensity"),
        _msg("user", "5"),
        _msg("assistant", "change?", "rewriting"),
        _msg("user", "an owl guides me"),
        _msg("assistant", "satisfied?", "rewriting"),
        _msg("user", "done, summarize"),
    ]

    body = _post(client, history).json()

    assert body["stage"] == "summary"
    assert body["structured"] is None
    assert body["response"].startswith("Title: X")


def test_final_requires_fresh_summary(client: TestClient, fake_llm: FakeLlmClient) -> None:
    fake_llm.enqueue('{"stage": "final", "confidence": 0.9}')
    fake_llm.enqueue('{"title": "T", "rewritten_dream": "R", "original_dream": "O"}')
    history = [
        _msg("user", "dream"),
        _msg("assistant", "rate?", "intensity"),
        _msg("user", "5"),
        _msg("assistant", "change?", "rewriting"),
        _msg("user", "an owl guides me"),
        _msg("assistant", "satisfied?", "rewriting"),
        _msg("user", "done"),
    ]

    body = _post(client, history).json()

    assert body["stage"] == "summary"
    assert body["structured"]["intensity"] == 5


def test_german_uses_german_prompts(client: TestClient, fake_llm: FakeLlmClient) -> None:
    fake_llm.enqueue('{"stage": "recording", "confidence": 0.9}')
    fake_llm.enqueue("Erzähl mir mehr.")

    body = _post(client, [_msg("user", "Ich hatte einen Albtraum.")], language="de").json()

    assert body["response"] == "Erzähl mir mehr."
    assert body["prompt_version"].startswith("prompts-de-v")
    assert "Selbsthilfe" in fake_llm.calls[1]["messages"][0]["content"]
