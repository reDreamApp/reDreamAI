"""SAFETY_DEBUG: every text model call on Mistral Small 3.2, no fallback (config.py)."""

from __future__ import annotations

import pytest

from redream_ai.config import settings
from redream_ai.core.agent import MODELS, Agent


@pytest.fixture
def keys(monkeypatch):
    monkeypatch.setenv("SCALEWAY_API_KEY", "test")
    monkeypatch.setenv("MISTRAL_API_KEY", "test")


def _agent() -> Agent:
    return Agent(
        MODELS["MISTRAL_MEDIUM"], "", fallback_model_config=MODELS["MISTRAL_MEDIUM_DIRECT"]
    )


def test_debug_mode_uses_mistral_small_without_fallback(keys, monkeypatch):
    monkeypatch.setattr(settings, "safety_debug", True)
    monkeypatch.setattr(settings, "environment", "development")
    agent = _agent()
    assert (agent.model, agent.provider) == ("mistral-small-3.2-24b-instruct-2506", "scaleway")
    assert agent.fallback_model is None


def test_production_ignores_debug_mode(keys, monkeypatch):
    monkeypatch.setattr(settings, "safety_debug", True)
    monkeypatch.setattr(settings, "environment", "production")
    agent = _agent()
    assert agent.model == MODELS["MISTRAL_MEDIUM"].name
    assert agent.fallback_model == MODELS["MISTRAL_MEDIUM_DIRECT"].name
