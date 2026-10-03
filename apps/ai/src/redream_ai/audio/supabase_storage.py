"""Rehearsal audio in a Supabase Storage bucket (service-role key, AI side)."""

from __future__ import annotations

import asyncio
from typing import Any

from supabase import Client, create_client


class SupabaseAudioStorage:
    """Implements `AudioStorage`. The sync client runs on a worker thread."""

    def __init__(
        self, *, url: str, service_role_key: str, bucket: str, public_url: str = ""
    ) -> None:
        if not url or not service_role_key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")
        self._client: Client = create_client(url, service_role_key)
        self._bucket = bucket
        self._internal_url = url.rstrip("/")
        self._public_url = public_url.rstrip("/")

    async def exists(self, path: str) -> bool:
        return bool(await asyncio.to_thread(self._files().exists, path))

    async def upload(self, path: str, data: bytes, *, content_type: str) -> None:
        await asyncio.to_thread(
            self._files().upload, path, data, {"content-type": content_type, "upsert": "true"}
        )

    async def signed_url(self, path: str, *, expires_in: int) -> str:
        res: Any = await asyncio.to_thread(self._files().create_signed_url, path, expires_in)
        if isinstance(res, dict):
            url = str(res.get("signedURL") or res.get("signedUrl") or res.get("signed_url"))
        else:
            url = str(getattr(res, "signedURL", None) or getattr(res, "signed_url", res))
        return publicize(url, internal=self._internal_url, public=self._public_url)

    def _files(self) -> Any:
        return self._client.storage.from_(self._bucket)


def publicize(url: str, *, internal: str, public: str) -> str:
    """Swap an internal base URL (e.g. `http://kong:8000`) for the public one."""
    if public and internal and url.startswith(internal):
        return public + url[len(internal) :]
    return url
