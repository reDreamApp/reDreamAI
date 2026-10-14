"""Regression tests for security boundaries (no network or live services)."""

import asyncio
import time
from urllib.parse import parse_qs, urlsplit
from uuid import UUID, uuid4

import httpx
import pytest
from sqlalchemy import func, select

from redream_api.core import request_limits
from redream_api.core.config import settings
from redream_api.db.models.chat_message import ChatMessage
from redream_api.db.models.content_report import ContentReport
from redream_api.db.models.report_action import ReportAction
from redream_api.db.repositories.usage_repo import UsageRepo
from redream_api.services import email_notification, storage_service
from redream_api.services.token_budget import reserve_usage, settle_usage

from .conftest import start_chat


async def test_chunked_json_is_bounded_before_parsing(client, monkeypatch):
    monkeypatch.setattr(request_limits, "MAX_JSON_BODY_BYTES", 16)

    async def chunks():
        yield b'{"content":"'
        yield b"x" * 32
        yield b'"}'

    response = await client.post(
        "/api/v1/chats/1/message", content=chunks(), headers={"Content-Type": "application/json"}
    )
    assert response.status_code == 413


async def test_chunked_multipart_is_bounded_before_spooling(client, monkeypatch):
    monkeypatch.setattr(request_limits, "MAX_AUDIO_BODY_BYTES", 128)

    async def chunks():
        yield b'--test\r\nContent-Disposition: form-data; name="file"; filename="voice.mp3"\r\n\r\n'
        yield b"x" * 129
        yield b"\r\n--test--\r\n"

    response = await client.post(
        "/api/v1/audio/transcribe",
        content=chunks(),
        headers={"Content-Type": "multipart/form-data; boundary=test"},
    )
    assert response.status_code == 413


async def test_content_length_cannot_bypass_or_crash_limit(client):
    for value in ["-1", "not-a-number", "9" * 21]:
        r = await client.post(
            "/api/v1/audio/transcribe", content=b"x", headers={"Content-Length": value}
        )
        assert r.status_code == 400
    r = await client.post(
        "/api/v1/audio/transcribe", content=b"x", headers={"Content-Length": str(30 * 1024 * 1024)}
    )
    assert r.status_code == 413


async def _report(client, fake_ai):
    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Continue",
            "usage": {"input_tokens": 10, "output_tokens": 10},
        }
    )
    chat_id = await start_chat(client)
    msg = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "Dream text"})
    message_id = UUID(msg.json()["user_message"]["id"])
    report = await client.post(
        "/api/v1/reports/ai-content",
        json={
            "chat_id": chat_id,
            "message_id": str(message_id),
            "target_role": "user",
            "reason": "other",
        },
    )
    assert report.status_code == 201, report.text
    return UUID(report.json()["id"]), message_id


def _link(action, report_id, message_id=None):
    url = urlsplit(email_notification._signed_action_url(action, report_id, message_id))
    return url.path, {key: values[0] for key, values in parse_qs(url.query).items()}


async def test_moderation_get_confirms_post_consumes_once(client, db_session_maker, fake_ai):
    report_id, _ = await _report(client, fake_ai)
    path, fields = _link("resolve", report_id)
    page = await client.get(path, params=fields)
    assert page.status_code == 200 and 'method="post"' in page.text
    assert page.headers["referrer-policy"] == "no-referrer"
    async with db_session_maker() as db:
        assert (await db.get(ContentReport, report_id)).status == "new"
        assert await db.scalar(select(func.count()).select_from(ReportAction)) == 0
    assert (await client.post(path, data=fields)).status_code == 200
    assert (await client.post(path, data=fields)).status_code == 409
    async with db_session_maker() as db:
        assert (await db.get(ContentReport, report_id)).status == "resolved"
        assert await db.scalar(select(func.count()).select_from(ReportAction)) == 1


async def test_moderation_rejects_expired_tampered_and_empty_secret(client, monkeypatch):
    report_id = uuid4()
    path, fields = _link("resolve", report_id)
    fields["expires"] = str(int(time.time()) - 1)
    assert (await client.get(path, params=fields)).status_code == 403
    path, fields = _link("resolve", report_id)
    fields["nonce"] = "x" * 32
    assert (await client.get(path, params=fields)).status_code == 403
    path, fields = _link("resolve", report_id)
    monkeypatch.setattr(settings, "report_notification_hmac_secret", "")
    assert (await client.get(path, params=fields)).status_code == 403


async def test_hide_is_atomic_and_owner_message_bound(client, db_session_maker, fake_ai):
    report_id, message_id = await _report(client, fake_ai)
    path, fields = _link("hide", report_id, uuid4())
    assert (await client.post(path, data=fields)).status_code == 403
    path, fields = _link("hide", report_id, message_id)
    responses = await asyncio.gather(client.post(path, data=fields), client.post(path, data=fields))
    assert sorted(r.status_code for r in responses) == [200, 409]
    async with db_session_maker() as db:
        assert (await db.get(ChatMessage, message_id)).visibility_status == "hidden"
        assert await db.scalar(select(func.count()).select_from(ReportAction)) == 1


async def test_concurrent_reservations_cannot_overbook_total(
    fake_user, db_session_maker, monkeypatch
):
    monkeypatch.setattr(settings, "daily_llm_token_budget_total", 8192)

    async def reserve():
        async with db_session_maker() as db:
            try:
                return await reserve_usage(db, user_id=fake_user.id)
            except Exception as error:
                from fastapi import HTTPException

                assert isinstance(error, HTTPException) and error.status_code == 429
                return None

    reservations = await asyncio.gather(*[reserve() for _ in range(6)])
    assert len([r for r in reservations if r]) == 1
    async with db_session_maker() as db:
        assert await UsageRepo(db).get_today_total() == 8192
        assert await UsageRepo(db).get_today_tokens(fake_user.id) == 8192
        reservation = next(r for r in reservations if r)
        await settle_usage(db, reservation, input_tokens=10, output_tokens=20)
        assert await UsageRepo(db).get_today_total() == 30
        assert await UsageRepo(db).get_today_tokens(fake_user.id) == 30


async def test_audio_refresh_moves_legacy_path_and_signs_shortly(monkeypatch):
    user = uuid4()
    old = f"users/{user}/7/en-old.mp3"
    calls = []
    monkeypatch.setattr(settings, "supabase_url", "http://kong")
    monkeypatch.setattr(settings, "supabase_public_url", "https://storage.example")
    monkeypatch.setattr(settings, "supabase_service_role_key", "test-key")

    def storage(req):
        import json

        calls.append((req.url.path, json.loads(req.content)))
        assert req.url.host == "kong"
        if req.url.path.endswith("/move"):
            return httpx.Response(200, json={})
        return httpx.Response(
            200,
            json={
                "signedURL": (
                    f"/object/sign/rehearsal-audio/users/{user}/7/v2-en-old.mp3?token=short"
                )
            },
        )

    monkeypatch.setattr(storage_service, "_transport", httpx.MockTransport(storage))
    url = await storage_service.refresh_rehearsal_url(
        f"https://untrusted.invalid/storage/v1/object/sign/rehearsal-audio/{old}?token=year",
        user,
        7,
    )
    assert url.startswith("https://storage.example/")
    assert calls[0][1]["sourceKey"] == old
    assert calls[0][1]["destinationKey"] == old.replace("/en-", "/v2-en-")
    assert calls[1][1]["expiresIn"] == 300
    with pytest.raises(ValueError):
        await storage_service.refresh_rehearsal_url(
            f"https://storage.example/storage/v1/object/sign/rehearsal-audio/users/{uuid4()}/7/v2-en-a.mp3",
            user,
            7,
        )


def test_legacy_host_config_migrates():
    from redream_api.core.config import Settings

    configured = Settings(
        _env_file=None, rehearsal_url_ttl_seconds=31536000, consent_version="2026-10-03"
    )
    assert configured.rehearsal_url_ttl_seconds == 300
    assert configured.consent_version == "2026-10-07"


async def test_revokes_orphaned_audio_and_recovers_move_retry(monkeypatch):
    from .test_rehearsal_audio import _Bucket

    user = uuid4()
    old = f"users/{user}/7/en-old.mp3"
    orphan = f"users/{user}/8/de-previous-rewrite.mp3"
    current = f"users/{user}/7/v2-en-current.mp3"
    bucket = _Bucket([old, orphan, current])
    moves = []
    monkeypatch.setattr(settings, "supabase_url", "http://kong")
    monkeypatch.setattr(settings, "supabase_service_role_key", "srk")

    def storage(req):
        import json

        if req.url.path.endswith("/move"):
            body = json.loads(req.content)
            source, destination = body["sourceKey"], body["destinationKey"]
            if source not in bucket.files:
                return httpx.Response(404)
            bucket.files.remove(source)
            bucket.files.add(destination)
            moves.append(source)
            # Simulate a crash after moving but before persisting the DB URL.
            return httpx.Response(500)
        if "/object/sign/" in req.url.path:
            return httpx.Response(
                200, json={"signedURL": req.url.path.removeprefix("/storage/v1") + "?token=new"}
            )
        return bucket(req)

    monkeypatch.setattr(storage_service, "_transport", httpx.MockTransport(storage))
    await storage_service.revoke_legacy_audio_objects()
    assert set(moves) == {old, orphan}
    assert old not in bucket.files and orphan not in bucket.files
    assert current in bucket.files
    # Re-running deployment is harmless; an old DB URL also refreshes safely.
    await storage_service.revoke_legacy_audio_objects()
    url = await storage_service.refresh_rehearsal_url(
        f"https://storage.example/storage/v1/object/sign/rehearsal-audio/{old}?token=old",
        user,
        7,
    )
    assert "v2-en-old.mp3?token=new" in url


async def test_audio_clean_up_skips_once_nothing_old_is_left(
    fake_user, db_session_maker, monkeypatch, capsys
):
    """The deploy runs it every time; only the first run may touch storage."""
    from redream_api import revoke_legacy_audio
    from redream_api.db.models.dream import Dream

    calls: list[str] = []

    async def sweep() -> None:
        calls.append("sweep")

    async def refresh(url: str, user_id, dream_id) -> str:
        calls.append(f"refresh {dream_id}")
        return url.replace("/en-", "/v2-en-")

    monkeypatch.setattr(revoke_legacy_audio, "async_session_maker", db_session_maker)
    monkeypatch.setattr(revoke_legacy_audio, "revoke_legacy_audio_objects", sweep)
    monkeypatch.setattr(revoke_legacy_audio, "refresh_rehearsal_url", refresh)
    base = f"https://s.example/storage/v1/object/sign/rehearsal-audio/users/{fake_user.id}"
    async with db_session_maker() as db:
        db.add(
            Dream(
                user_id=fake_user.id,
                title="old link",
                original_dream="o",
                rehearsal_audio_url=f"{base}/1/en-abc.mp3?token=t",
            )
        )
        db.add(
            Dream(
                user_id=fake_user.id,
                title="current link",
                original_dream="o",
                rehearsal_audio_url=f"{base}/2/v2-en-abc.mp3?token=t",
            )
        )
        db.add(Dream(user_id=fake_user.id, title="no audio", original_dream="o"))
        await db.commit()

    await revoke_legacy_audio.main()
    assert calls == ["sweep", "refresh 1"]
    assert "1 dream(s)" in capsys.readouterr().out

    calls.clear()
    await revoke_legacy_audio.main()
    assert calls == []
    assert "nothing to do" in capsys.readouterr().out
