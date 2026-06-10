"""Crisis-detection flow on POST /chats/{id}/message (ADR 0005)."""

from __future__ import annotations

from sqlalchemy import select

from redream_api.db.models.chat_message import ChatMessage
from redream_api.db.models.safety_event import SafetyEvent

from .conftest import FakeAiClient, start_chat


async def test_high_risk_input_skips_chat_and_logs_safety_event(
    client, fake_ai: FakeAiClient, db_session_maker
) -> None:
    chat_id = await start_chat(client)

    fake_ai.queue_safety(
        {
            "risk": "high",
            "categories": ["suicidal_ideation"],
            "confidence": 0.92,
            "prompt_version": "safety-v0.1.0",
        }
    )

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message",
        json={"content": "I don't want to be here anymore."},
    )
    assert r.status_code == 200, r.text

    body = r.json()
    assert body["ai_message"] is None, "AI should NOT be called on high-risk input"
    assert body["safety_event"] is not None
    assert body["safety_event"]["risk"] == "high"
    assert body["safety_event"]["categories"] == ["suicidal_ideation"]
    assert body["stage"] == "recording", "stage must NOT advance on high-risk"

    # Verify the AI service's /chat was not called.
    chat_calls = [c for c in fake_ai.calls if c["method"] == "chat"]
    assert chat_calls == []

    # Verify a safety_events row was written.
    async with db_session_maker() as session:
        events = (await session.scalars(select(SafetyEvent))).all()
    assert len(events) == 1
    assert events[0].risk == "high"
    assert events[0].confidence == 0.92
    assert events[0].action_taken == "helpline_shown"

    # The user message should be persisted with safety_flagged=True.
    async with db_session_maker() as session:
        msgs = (
            await session.scalars(
                select(ChatMessage).where(ChatMessage.chat_id == chat_id)
            )
        ).all()
    assert len(msgs) == 1
    assert msgs[0].safety_flagged is True


async def test_low_risk_input_proceeds_to_chat(
    client, fake_ai: FakeAiClient
) -> None:
    chat_id = await start_chat(client)
    # Default safety queue is empty → returns risk=none, so this should pass through.
    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Tell me more about that dream.",
            "structured": None,
            "usage": {"input_tokens": 8, "output_tokens": 12},
            "prompt_version": "chat-v0.0.0-test",
        }
    )

    r = await client.post(
        f"/api/v1/chats/{chat_id}/message",
        json={"content": "I had a strange dream last night."},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["safety_event"] is None
    assert body["ai_message"]["content"] == "Tell me more about that dream."
    assert body["ai_message"]["role"] == "assistant"
    assert body["stage"] == "recording"
