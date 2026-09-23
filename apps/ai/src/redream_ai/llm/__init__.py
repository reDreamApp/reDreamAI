"""LLM client abstraction.

Routes accept an `LlmClient` and never import the Mistral SDK directly. Tests
inject `FakeLlmClient`; production uses `MistralLlmClient`.
"""

from .base import LlmClient, StreamChunk
from .fake_client import FakeLlmClient

__all__ = ["FakeLlmClient", "LlmClient", "StreamChunk"]
