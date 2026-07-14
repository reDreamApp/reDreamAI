"""GDPR purge: Langfuse trace deletion + the /users/me/data route.

`delete_user_traces` talks to the Langfuse public API over httpx; tests
install an `httpx.MockTransport` via the module's `_transport` seam — no
network, and the request shapes (list-by-userId, bulk-delete body) are
asserted against the real API contract.
"""

from __future__ import annotations

import json
from typing import Any
from uuid import uuid4

import httpx
import pytest

from redream_api.services import langfuse_service


@pytest.fixture
def langfuse_settings(monkeypatch):
    monkeypatch.setattr(langfuse_service.settings, "langfuse_host", "http://langfuse.test")
    monkeypatch.setattr(langfuse_service.settings, "langfuse_public_key", "pk-test")
    monkeypatch.setattr(langfuse_service.settings, "langfuse_secret_key", "sk-test")


def _install_transport(monkeypatch, handler) -> list[httpx.Request]:
    """Route the service's httpx client through `handler`; returns the request log."""
    requests: list[httpx.Request] = []

    def _logging_handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return handler(request)

    monkeypatch.setattr(langfuse_service, "_transport", httpx.MockTransport(_logging_handler))
    return requests


def _list_response(ids: list[str], *, page: int, total_pages: int) -> httpx.Response:
    return httpx.Response(
        200,
        json={
            "data": [{"id": i} for i in ids],
            "meta": {"page": page, "totalPages": total_pages, "limit": 100},
        },
    )


async def test_deletes_all_traces_across_pages(monkeypatch, langfuse_settings):
    """Two list pages → one paginated listing, then bulk deletes of every id."""
    user_id = uuid4()
    page_ids = {1: [f"tr-{i}" for i in range(100)], 2: ["tr-100", "tr-101"]}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "GET":
            page = int(request.url.params["page"])
            assert request.url.params["userId"] == str(user_id)
            return _list_response(page_ids[page], page=page, total_pages=2)
        assert request.method == "DELETE"
        return httpx.Response(200, json={"success": True})

    requests = _install_transport(monkeypatch, handler)

    assert await langfuse_service.delete_user_traces(user_id) is True

    deletes = [r for r in requests if r.method == "DELETE"]
    deleted_ids = [i for r in deletes for i in json.loads(r.content.decode())["traceIds"]]
    assert deleted_ids == page_ids[1] + page_ids[2]
    # Basic-auth with the project keys on every request.
    assert all(r.headers["Authorization"].startswith("Basic ") for r in requests)


async def test_no_traces_is_success_without_delete_call(monkeypatch, langfuse_settings):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "GET"
        return _list_response([], page=1, total_pages=1)

    requests = _install_transport(monkeypatch, handler)

    assert await langfuse_service.delete_user_traces(uuid4()) is True
    assert [r.method for r in requests] == ["GET"]


async def test_delete_failure_returns_false(monkeypatch, langfuse_settings):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "GET":
            return _list_response(["tr-1"], page=1, total_pages=1)
        return httpx.Response(500, text="boom")

    _install_transport(monkeypatch, handler)

    assert await langfuse_service.delete_user_traces(uuid4()) is False


async def test_unconfigured_langfuse_returns_false(monkeypatch):
    monkeypatch.setattr(langfuse_service.settings, "langfuse_host", "")

    assert await langfuse_service.delete_user_traces(uuid4()) is False


async def test_ai_calls_carry_user_and_session_ids(client, fake_ai, fake_user):
    """Both AI calls of a turn must send user_id/session_id — apps/ai stamps
    them on the Langfuse traces the purge later deletes by userId."""
    from .conftest import start_chat

    fake_ai.queue_chat(
        {
            "stage": "recording",
            "response": "Tell me more.",
            "structured": None,
            "usage": {"input_tokens": 1, "output_tokens": 1},
            "prompt_version": "test-v0",
        }
    )
    chat_id = await start_chat(client)
    r = await client.post(f"/api/v1/chats/{chat_id}/message", json={"content": "a nightmare"})
    assert r.status_code == 200

    by_method = {c["method"]: c["payload"] for c in fake_ai.calls}
    for method in ("safety_classify", "chat"):
        assert by_method[method]["user_id"] == str(fake_user.id)
        assert by_method[method]["session_id"] == str(chat_id)


async def test_purge_route_reaches_postgres_storage_and_langfuse(
    client, fake_user, db_session_maker, monkeypatch
):
    """DELETE /users/me/data must clear all three stores (apps/api invariant)."""
    from redream_api.api.v1.users import routes as user_routes

    calls: dict[str, Any] = {}

    async def fake_storage(user_id):
        calls["storage"] = user_id

    async def fake_langfuse(user_id):
        calls["langfuse"] = user_id
        return True

    monkeypatch.setattr(user_routes, "delete_rehearsal_audio_for_user", fake_storage)
    monkeypatch.setattr(user_routes, "delete_user_traces", fake_langfuse)

    r = await client.delete("/api/v1/users/me/data")
    assert r.status_code == 204

    assert calls == {"storage": fake_user.id, "langfuse": fake_user.id}
    from redream_api.db.repositories.user_repo import UserRepo

    async with db_session_maker() as session:
        assert await UserRepo(session).get(fake_user.id) is None
