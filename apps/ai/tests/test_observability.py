"""Langfuse observability helpers (redream_ai.observability).

Tracing is optional: with no LANGFUSE_* env configured, every helper must be a
safe no-op so tests and offline dev never depend on a Langfuse server. These
tests exercise that disabled path — the production path is covered implicitly by
the /chat and /safety route tests (which run with tracing disabled).
"""

from __future__ import annotations

from redream_ai import observability as obs


def test_disabled_when_unconfigured(monkeypatch):
    # Force a clean, unconfigured state regardless of ambient env / prior import.
    monkeypatch.setattr(obs.settings, "langfuse_host", "", raising=False)
    monkeypatch.setattr(obs.settings, "langfuse_public_key", "", raising=False)
    monkeypatch.setattr(obs.settings, "langfuse_secret_key", "", raising=False)
    monkeypatch.setattr(obs, "_client", None, raising=False)
    monkeypatch.setattr(obs, "_initialized", False, raising=False)

    assert obs._get_client() is None
    assert obs.start_trace("chat-turn", session_id="s1", input=[]) is None


def test_helpers_are_noops_with_none_trace():
    # Must not raise when there is no trace (the disabled path passes None down).
    obs.record_generation(
        None,
        name="irt-route",
        model="m",
        input=[{"role": "user", "content": "hi"}],
        output="{}",
        usage={"input_tokens": 1, "output_tokens": 2},
    )
    obs.update_trace(None, output={"stage": "recording"})
    obs.flush()
