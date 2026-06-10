"""pytest fixtures for the AI service."""

from __future__ import annotations

import pytest

from redream_ai.llm.fake_client import FakeLlmClient


@pytest.fixture
def fake_llm() -> FakeLlmClient:
    """A fresh FakeLlmClient. Enqueue responses in the test body."""
    return FakeLlmClient()
