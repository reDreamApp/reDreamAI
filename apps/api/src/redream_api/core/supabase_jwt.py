"""Supabase JWT verification — fetch JWKS, verify signature + claims."""

from __future__ import annotations

from typing import Any, cast

import httpx
from cachetools import TTLCache
from jose import jwt
from jose.exceptions import JWTError

from .config import settings

# Supabase rotates keys infrequently, so an hour of caching is plenty.
_jwks_cache: TTLCache[str, dict[str, Any]] = TTLCache(maxsize=4, ttl=3600)


class JwtVerificationError(Exception):
    """The bearer token failed verification."""


async def _fetch_jwks() -> dict[str, Any]:
    cached = _jwks_cache.get(settings.supabase_jwks_url)
    if cached is not None:
        return cached

    if not settings.supabase_jwks_url:
        raise JwtVerificationError("SUPABASE_JWKS_URL is not configured")

    async with httpx.AsyncClient(timeout=10.0) as client:
        r = await client.get(settings.supabase_jwks_url)
        r.raise_for_status()
        jwks = cast(dict[str, Any], r.json())
    _jwks_cache[settings.supabase_jwks_url] = jwks
    return jwks


def _key_for_kid(jwks: dict[str, Any], kid: str | None) -> dict[str, Any] | None:
    if kid is None:
        return None
    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return cast(dict[str, Any], key)
    return None


async def verify_supabase_jwt(token: str) -> dict[str, Any]:
    """Verify `token` against the configured JWKS. Returns the decoded claims."""
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise JwtVerificationError(f"malformed token: {exc}") from exc

    alg = header.get("alg")
    if alg not in settings.jwt_algorithms_list:
        raise JwtVerificationError(f"unexpected algorithm: {alg}")

    kid = header.get("kid")
    key = _key_for_kid(await _fetch_jwks(), kid)
    if key is None:
        raise JwtVerificationError(f"no JWKS key for kid={kid}")

    try:
        claims = jwt.decode(
            token,
            key,
            algorithms=settings.jwt_algorithms_list,
            audience=settings.supabase_jwt_aud,
            issuer=settings.supabase_jwt_iss or None,
        )
    except JWTError as exc:
        raise JwtVerificationError(f"verification failed: {exc}") from exc

    return cast(dict[str, Any], claims)
