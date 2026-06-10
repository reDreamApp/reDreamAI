"""Prompts.

Each prompt module exports a `PROMPT_VERSION` constant — bump on every edit.
The version flows into Langfuse trace metadata and into `ChatResponse.prompt_version`
so we can correlate responses with the exact prompt revision that produced them.
"""
