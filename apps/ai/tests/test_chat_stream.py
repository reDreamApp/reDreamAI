"""POST /chat/stream — SSE adapter over the ported streaming orchestrator (ADR 0009).

Most tests MOCK the ported `process_chat_message_stream` (and the structured-summary
pass) with fake async generators so nothing hits an LLM; one drives the REAL generator
with mocked internals to pin its wire frames against the route's parser. Frames are
collected through the TestClient streaming API and checked against the contract
documented in the `redream_ai.api.chat` module docstring:

    content* -> usage? -> safety? -> final -> [DONE]   (from the core; the route
        swallows `usage`, folding it into `final.usage`, and swallows the core's
        own [DONE] — consumers see: content* -> safety? -> final -> [DONE])
    content* -> error -> [DONE]                        (failure; no final frame)
"""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

import redream_ai.api.chat as chatmod
from redream_ai.core import irt_app
from redream_ai.main import app
from redream_ai.models import SummaryStructured

REQ = {"messages": [{"role": "user", "content": "I turn and face it"}], "language": "en"}


@pytest.fixture
def client(monkeypatch):
    """TestClient with the ported agents stubbed non-None (so /chat/stream doesn't 503)."""
    monkeypatch.setattr(irt_app, "routing_agent", object(), raising=False)
    monkeypatch.setattr(irt_app, "response_agent", object(), raising=False)
    with TestClient(app) as c:
        yield c


def _collect_frames(client, payload):
    """POST the request and return the SSE frames (without the '\\n\\n' separators)."""
    with client.stream("POST", "/chat/stream", json=payload) as r:
        assert r.status_code == 200
        assert r.headers["content-type"].startswith("text/event-stream")
        text = "".join(r.iter_text())
    assert text.endswith("\n\n")
    return [f for f in text.split("\n\n") if f]


def _payload(frame):
    return json.loads(frame.removeprefix("data: "))


def test_passthrough_order_and_final_frame(client, monkeypatch):
    """Content + safety pass through verbatim; usage is swallowed into final + [DONE]."""
    chunk1 = 'data: {"content": "You turn ", "stages": ["rewriting"], "language": "en"}'
    chunk2 = 'data: {"content": "and face it.", "stages": ["rewriting"], "language": "en"}'
    usage = 'data: {"usage": {"input": 17, "output": 43, "total": 60}}'
    safety = 'data: {"safety": {"is_safe": true, "node_id": "BEHAVIORAL_MASTERY"}}'

    async def fake(chat_input, conversation, safety_enabled=True):
        conversation.stages.append("rewriting")
        yield chunk1 + "\n\n"
        yield chunk2 + "\n\n"
        yield usage + "\n\n"  # the core's internal usage frame — swallowed into final
        yield safety + "\n\n"
        yield "data: [DONE]\n\n"  # the ported terminal — must be swallowed by the route

    monkeypatch.setattr(irt_app, "process_chat_message_stream", fake)
    frames = _collect_frames(client, REQ)

    assert frames[:3] == [chunk1, chunk2, safety]  # verbatim pass-through; no usage frame
    assert _payload(frames[3])["final"] == {
        "stage": "rewriting",
        "response": "You turn and face it.",  # accumulated content chunks
        "structured": None,
        "usage": {"input_tokens": 17, "output_tokens": 43},  # folded from the usage frame
        "prompt_version": chatmod.PROMPT_VERSION,
        "safety": {"is_safe": True, "node_id": "BEHAVIORAL_MASTERY"},
        "nightmare_summary": None,
    }
    assert frames[4] == "data: [DONE]"
    assert len(frames) == 5  # usage + ported [DONE] swallowed; ours terminal


def test_summary_stage_triggers_structured_extraction(client, monkeypatch):
    async def fake(chat_input, conversation, safety_enabled=True):
        conversation.stages.append("summary")
        conversation.nightmare_summary = "I was chased through a forest."
        yield 'data: {"content": "Title: Forest", "stages": ["summary"], "language": "en"}\n\n'
        chunk2 = {"content": "\n\nRewritten Dream: ...", "stages": ["summary"], "language": "en"}
        yield f"data: {json.dumps(chunk2)}\n\n"
        yield "data: [DONE]\n\n"

    captured = {}

    async def fake_extract(prose, language):
        captured["prose"] = prose
        captured["language"] = language
        return SummaryStructured(title="Forest", rewritten_summary="R",
                                 original_summary="O", dream_summary="O", intensity=None)

    monkeypatch.setattr(irt_app, "process_chat_message_stream", fake)
    monkeypatch.setattr(chatmod, "extract_summary_structured", fake_extract)
    frames = _collect_frames(client, REQ)

    final = _payload(frames[2])["final"]
    assert captured["prose"] == "Title: Forest\n\nRewritten Dream: ..."  # full accumulated text
    assert captured["language"] == "en"
    assert final["stage"] == "summary"
    assert final["structured"]["title"] == "Forest"
    assert final["structured"]["dream_summary"] == final["structured"]["original_summary"]
    # once-generated nightmare summary is echoed back for the backend to persist
    assert final["nightmare_summary"] == "I was chased through a forest."
    assert frames[3] == "data: [DONE]"


def test_non_summary_stage_skips_extraction_and_echoes_request_nightmare_summary(
    client, monkeypatch
):
    async def fake(chat_input, conversation, safety_enabled=True):
        conversation.stages.append("recording")
        yield 'data: {"content": "Tell me more.", "stages": ["recording"], "language": "en"}\n\n'
        yield "data: [DONE]\n\n"

    async def boom(prose, language):
        raise AssertionError("extract_summary_structured must not run for non-summary stages")

    monkeypatch.setattr(irt_app, "process_chat_message_stream", fake)
    monkeypatch.setattr(chatmod, "extract_summary_structured", boom)
    frames = _collect_frames(client, {**REQ, "nightmare_summary": "already generated"})

    final = _payload(frames[1])["final"]
    assert final["stage"] == "recording"
    assert final["structured"] is None
    # no usage frame from the core -> zeros fallback, never a missing field
    assert final["usage"] == {"input_tokens": 0, "output_tokens": 0}
    # nightmare_summary from the request survives the rebuilt conversation untouched
    assert final["nightmare_summary"] == "already generated"


def test_real_generator_emits_usage_frame_folded_into_final(client, monkeypatch):
    """Drive the REAL process_chat_message_stream (mocked internals): its usage frame
    must reach final.usage through the route — pins the core↔route wire contract."""

    async def fake_determine_stage(user_input, conversation):
        conversation.stages.append("recording")  # the real router appends before generating
        return "recording"

    async def fake_response_stream(stage, full_prompt, conversation, language,
                                   safety_constraint=None):
        yield "Tell me ", None
        yield "more.", None
        yield "", {"input": 5, "output": 7, "total": 12}  # usage arrives on the last tuple

    monkeypatch.setattr(irt_app, "determine_stage_async", fake_determine_stage)
    monkeypatch.setattr(irt_app, "get_response_stream_async", fake_response_stream)
    frames = _collect_frames(client, REQ)

    payloads = [_payload(f) for f in frames[:-1]]
    assert "usage" not in {k for p in payloads for k in p}  # never forwarded raw
    assert [p["content"] for p in payloads[:2]] == ["Tell me ", "more."]
    final = _payload(frames[-2])["final"]
    assert final["response"] == "Tell me more."
    assert final["usage"] == {"input_tokens": 5, "output_tokens": 7}
    assert frames[-1] == "data: [DONE]"


def test_error_frame_passes_through_then_done_without_final(client, monkeypatch):
    error = 'data: {"error": "upstream exploded"}'

    async def fake(chat_input, conversation, safety_enabled=True):
        yield 'data: {"content": "part", "stages": ["rewriting"], "language": "en"}\n\n'
        yield error + "\n\n"  # the ported generator ends after its error frame (no [DONE])

    monkeypatch.setattr(irt_app, "process_chat_message_stream", fake)
    frames = _collect_frames(client, REQ)

    assert frames == [
        'data: {"content": "part", "stages": ["rewriting"], "language": "en"}',
        error,
        "data: [DONE]",  # terminal frame still emitted; no final frame on failure
    ]


def test_generator_exception_becomes_error_frame_plus_done(client, monkeypatch):
    async def fake(chat_input, conversation, safety_enabled=True):
        yield 'data: {"content": "part", "stages": ["rewriting"], "language": "en"}\n\n'
        raise RuntimeError("boom mid-stream")

    monkeypatch.setattr(irt_app, "process_chat_message_stream", fake)
    frames = _collect_frames(client, REQ)

    assert _payload(frames[1]) == {"error": "boom mid-stream"}
    assert frames[2] == "data: [DONE]"
    assert len(frames) == 3  # never a half-open stream: error + terminal, no final


def test_empty_messages_rejected(client):
    r = client.post("/chat/stream", json={"messages": [], "language": "en"})
    assert r.status_code == 400


def test_last_message_must_be_user(client):
    r = client.post(
        "/chat/stream",
        json={"messages": [{"role": "assistant", "content": "hi"}], "language": "en"},
    )
    assert r.status_code == 400


def test_503_when_agents_unconfigured(monkeypatch):
    monkeypatch.setattr(irt_app, "routing_agent", None, raising=False)
    with TestClient(app) as c:
        r = c.post(
            "/chat/stream",
            json={"messages": [{"role": "user", "content": "x"}], "language": "en"},
        )
    assert r.status_code == 503
