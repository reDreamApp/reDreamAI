"""/rehearsal/generate and /audio/transcribe with fake audio providers."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from redream_ai.api.deps import get_audio_storage, get_synthesizer, get_transcriber
from redream_ai.audio.supabase_storage import publicize
from redream_ai.audio.tts import estimate_duration
from redream_ai.main import app


class FakeSynth:
    def __init__(self) -> None:
        self.calls: list[dict[str, object]] = []

    async def synthesize(self, *, text: str, model: str, voice_id: str | None) -> bytes:
        self.calls.append({"text": text, "model": model, "voice_id": voice_id})
        return b"ID3mp3bytes"


class FakeStorage:
    def __init__(self) -> None:
        self.objects: dict[str, bytes] = {}

    async def exists(self, path: str) -> bool:
        return path in self.objects

    async def upload(self, path: str, data: bytes, *, content_type: str) -> None:
        assert content_type == "audio/mpeg"
        self.objects[path] = data

    async def signed_url(self, path: str, *, expires_in: int) -> str:
        return f"https://storage.test/{path}?ttl={expires_in}"


class FakeTranscriber:
    async def transcribe(
        self, *, audio: bytes, file_name: str, model: str
    ) -> tuple[str, str | None, dict[str, int]]:
        assert audio == b"wavbytes" and file_name == "dream.wav"
        return "  Ich war im Wald. ", "de", {"input_tokens": 30, "output_tokens": 8}


@pytest.fixture
def synth() -> FakeSynth:
    return FakeSynth()


@pytest.fixture
def storage() -> FakeStorage:
    return FakeStorage()


@pytest.fixture
def client(synth: FakeSynth, storage: FakeStorage) -> TestClient:
    app.dependency_overrides[get_synthesizer] = lambda: synth
    app.dependency_overrides[get_audio_storage] = lambda: storage
    app.dependency_overrides[get_transcriber] = lambda: FakeTranscriber()
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


def test_rehearsal_synthesizes_uploads_and_caches(
    client: TestClient, synth: FakeSynth, storage: FakeStorage
) -> None:
    body = {"dream_id": "42", "rewritten_dream": "You walk home with a lantern.", "language": "en"}

    first = client.post("/rehearsal/generate", json=body).json()
    assert first["cache_hit"] is False
    assert first["script"] == "You walk home with a lantern."
    assert first["duration_estimate"] == "00:03"
    assert first["audio_url"].startswith("https://storage.test/dreams/42/en-")
    assert len(storage.objects) == 1
    assert synth.calls[0]["text"] == "You walk home with a lantern."

    second = client.post("/rehearsal/generate", json=body).json()
    assert second["cache_hit"] is True
    assert second["audio_url"] == first["audio_url"]
    assert len(synth.calls) == 1


def test_rehearsal_rejects_empty_text(client: TestClient) -> None:
    res = client.post(
        "/rehearsal/generate", json={"dream_id": "1", "rewritten_dream": "  ", "language": "de"}
    )
    assert res.status_code == 400


def test_transcribe_returns_text_language_and_usage(client: TestClient) -> None:
    res = client.post("/audio/transcribe", files={"file": ("dream.wav", b"wavbytes", "audio/wav")})
    assert res.status_code == 200
    assert res.json() == {
        "text": "Ich war im Wald.",
        "language_detected": "de",
        "input_tokens": 30,
        "output_tokens": 8,
    }


def test_duration_estimate_rounds_to_mm_ss() -> None:
    assert estimate_duration(" ".join(["word"] * 300)) == "02:05"


def test_publicize_rewrites_internal_host_only() -> None:
    signed = "http://kong:8000/storage/v1/object/sign/rehearsal-audio/dreams/1/en-x.mp3?token=t"
    assert publicize(signed, internal="http://kong:8000", public="https://sb.example.com") == (
        "https://sb.example.com/storage/v1/object/sign/rehearsal-audio/dreams/1/en-x.mp3?token=t"
    )
    assert publicize(signed, internal="http://kong:8000", public="") == signed
    assert publicize("https://other/x", internal="http://kong:8000", public="https://p") == (
        "https://other/x"
    )
