"""Rehearsal-audio purge over the Supabase Storage REST API."""

from __future__ import annotations

import pytest
from pytest_httpx import HTTPXMock

from redream_api.core.config import settings
from redream_api.services.storage_service import delete_rehearsal_audio


@pytest.fixture
def configured(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "supabase_url", "https://sb.test")
    monkeypatch.setattr(settings, "supabase_service_role_key", "service-key")
    monkeypatch.setattr(settings, "supabase_storage_bucket", "rehearsal-audio")


async def test_skips_when_not_configured(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "supabase_url", "")
    assert await delete_rehearsal_audio([1, 2]) == 0


@pytest.mark.usefixtures("configured")
async def test_lists_and_deletes_each_dream_folder(httpx_mock: HTTPXMock) -> None:
    httpx_mock.add_response(
        method="POST",
        url="https://sb.test/storage/v1/object/list/rehearsal-audio",
        match_json={"prefix": "dreams/7", "limit": 1000},
        json=[{"name": "en-abc.mp3"}, {"name": "de-def.mp3"}],
    )
    httpx_mock.add_response(
        method="DELETE",
        url="https://sb.test/storage/v1/object/rehearsal-audio",
        match_json={"prefixes": ["dreams/7/en-abc.mp3", "dreams/7/de-def.mp3"]},
        json=[],
    )
    httpx_mock.add_response(
        method="POST",
        url="https://sb.test/storage/v1/object/list/rehearsal-audio",
        match_json={"prefix": "dreams/8", "limit": 1000},
        json=[],
    )

    assert await delete_rehearsal_audio([7, 8]) == 2
    assert httpx_mock.get_requests()[0].headers["Authorization"] == "Bearer service-key"


@pytest.mark.usefixtures("configured")
async def test_storage_errors_do_not_raise(httpx_mock: HTTPXMock) -> None:
    httpx_mock.add_response(method="POST", status_code=500)
    assert await delete_rehearsal_audio([1]) == 0
