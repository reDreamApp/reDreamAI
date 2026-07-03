"""Langfuse observability helpers (redream_ai.observability).

Tracing is optional: with no LANGFUSE_* env configured, every helper must be a
safe no-op so tests and offline dev never depend on a Langfuse server. These
tests exercise that disabled path — the production path is covered implicitly by
the /chat and /safety route tests (which run with tracing disabled).
"""

from __future__ import annotations

import os
import subprocess
import sys
from typing import Any

from redream_ai import observability as obs


def _set_langfuse_settings(
    monkeypatch,
    *,
    host: str = "",
    public_key: str = "",
    secret_key: str = "",
    enabled: bool = True,
) -> None:
    monkeypatch.setattr(obs.settings, "langfuse_host", host)
    monkeypatch.setattr(obs.settings, "langfuse_public_key", public_key)
    monkeypatch.setattr(obs.settings, "langfuse_secret_key", secret_key)
    monkeypatch.setattr(obs.settings, "langfuse_enabled", enabled)


def _capture_configure(monkeypatch) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    monkeypatch.setattr(
        obs.langfuse_context, "configure", lambda **kwargs: calls.append(kwargs)
    )
    return calls


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


def test_client_disabled_by_langfuse_enabled_false(monkeypatch):
    # LANGFUSE_ENABLED=false is an explicit off-switch even with host/keys set.
    _set_langfuse_settings(
        monkeypatch, host="http://lf:3000", public_key="pk", secret_key="sk", enabled=False
    )
    monkeypatch.setattr(obs, "_client", None)
    monkeypatch.setattr(obs, "_initialized", False)

    assert obs._get_client() is None


def test_configure_decorators_disabled_when_unconfigured(monkeypatch):
    # No host/keys → the decorator context must be configured with enabled=False
    # and NOTHING else (no credentials, no host → no network ever).
    _set_langfuse_settings(monkeypatch)
    monkeypatch.setattr(obs, "_decorators_configured", False)
    calls = _capture_configure(monkeypatch)

    obs.configure_decorators()

    assert calls == [{"enabled": False}]
    assert obs._decorators_configured is True


def test_configure_decorators_off_switch_wins_over_keys(monkeypatch):
    _set_langfuse_settings(
        monkeypatch, host="http://lf:3000", public_key="pk", secret_key="sk", enabled=False
    )
    monkeypatch.setattr(obs, "_decorators_configured", False)
    calls = _capture_configure(monkeypatch)

    obs.configure_decorators()

    assert calls == [{"enabled": False}]


def test_configure_decorators_enabled_passes_settings_credentials(monkeypatch):
    _set_langfuse_settings(
        monkeypatch, host="http://lf:3000", public_key="pk-x", secret_key="sk-y"
    )
    monkeypatch.setattr(obs, "_decorators_configured", False)
    calls = _capture_configure(monkeypatch)

    obs.configure_decorators()

    assert calls == [
        {
            "host": "http://lf:3000",
            "public_key": "pk-x",
            "secret_key": "sk-y",
            "enabled": True,
        }
    ]


def test_configure_decorators_is_idempotent(monkeypatch):
    # Repeat calls (every lifespan entry) must early-return: the SDK's
    # configure() resets its singleton with a ~2s consumer-thread join, which
    # multiplied across TestClient-based tests dominated the suite's runtime.
    _set_langfuse_settings(monkeypatch)
    monkeypatch.setattr(obs, "_decorators_configured", False)
    calls = _capture_configure(monkeypatch)

    obs.configure_decorators()
    obs.configure_decorators()

    assert calls == [{"enabled": False}]  # second call never reached the SDK


def test_configure_decorators_real_sdk_disabled_state(monkeypatch):
    # End-to-end against the pinned v2 SDK (no monkeypatched configure). The
    # env carries plausible credentials — without them the SDK auto-disables
    # and the assertion would pass vacuously — so this genuinely pins that the
    # settings gate's enabled=False is what disables the client.
    monkeypatch.setenv("LANGFUSE_HOST", "http://localhost:9")
    monkeypatch.setenv("LANGFUSE_PUBLIC_KEY", "pk-env")
    monkeypatch.setenv("LANGFUSE_SECRET_KEY", "sk-env")
    _set_langfuse_settings(monkeypatch)  # settings gate: unconfigured → disable
    monkeypatch.setattr(obs, "_decorators_configured", False)

    obs.configure_decorators()

    assert obs.langfuse_context.client_instance.enabled is False


def test_observe_gating_binds_without_lifespan():
    # Regression: the gate must NOT depend on main.lifespan running. Importing
    # the core (as any script or targeted pytest run does) must already leave
    # the decorator context configured-disabled, even with live-looking
    # LANGFUSE_* creds in the env and LANGFUSE_ENABLED=false — previously the
    # decorators lazily built an ENABLED client from raw env in this scenario.
    code = (
        "from redream_ai.core import irt_app\n"
        "from redream_ai import observability as obs\n"
        "assert obs._decorators_configured is True\n"
        "assert obs.langfuse_context.client_instance.enabled is False\n"
    )
    env = {
        **os.environ,
        "LANGFUSE_HOST": "http://localhost:9",
        "LANGFUSE_PUBLIC_KEY": "pk-env",
        "LANGFUSE_SECRET_KEY": "sk-env",
        "LANGFUSE_ENABLED": "false",
        "SCALEWAY_API_KEY": "test-dummy",
        "MISTRAL_API_KEY": "test-dummy",
    }
    subprocess.run([sys.executable, "-c", code], check=True, env=env, timeout=120)


def test_flush_never_raises_when_decorator_flush_fails(monkeypatch):
    monkeypatch.setattr(obs, "_decorators_configured", True)

    def boom() -> None:
        raise RuntimeError("boom")

    monkeypatch.setattr(obs.langfuse_context, "flush", boom)
    obs.flush()  # must not raise
