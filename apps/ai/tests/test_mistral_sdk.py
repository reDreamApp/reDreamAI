"""The Mistral adapters must construct against the pinned SDK (no network)."""

from __future__ import annotations

from redream_ai.audio.mistral_audio import MistralAudioClient
from redream_ai.llm.mistral_client import MistralLlmClient, _text


def test_adapters_construct_with_installed_sdk() -> None:
    assert MistralLlmClient(api_key="test-key") is not None
    assert MistralAudioClient(api_key="test-key") is not None


def test_text_normalizes_string_and_chunk_lists() -> None:
    assert _text(None) == ""
    assert _text("hi") == "hi"
    assert _text([{"type": "text", "text": "a"}, {"type": "image_url"}, {"text": "b"}]) == "ab"
