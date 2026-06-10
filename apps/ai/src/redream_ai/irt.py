"""IRT 5-stage state machine + guardrails.

Canonical flow: recording -> intensity -> rewriting -> summary -> final.

Guardrails:
- Cannot reach REWRITING without having visited INTENSITY.
- Cannot reach FINAL without a SUMMARY in history, AND no REWRITING after the
  most recent SUMMARY (a fresh summary must be the latest synthesis).
- Stages are forward-only — no regression once advanced.

The routing agent (an LLM) suggests a next stage from intent; this module
enforces the rules. If the routing agent proposes a forbidden transition,
the nearest legal stage is returned instead.
"""

from __future__ import annotations

from .models import Message, Stage

STAGE_ORDER: tuple[Stage, ...] = (
    Stage.RECORDING,
    Stage.INTENSITY,
    Stage.REWRITING,
    Stage.SUMMARY,
    Stage.FINAL,
)


def stages_visited(history: list[Message]) -> set[Stage]:
    """Distinct stages that appear in the history."""
    return {m.stage for m in history if m.stage is not None}


def current_stage(history: list[Message]) -> Stage:
    """The stage of the most recent staged message, or RECORDING if none."""
    for msg in reversed(history):
        if msg.stage is not None:
            return msg.stage
    return Stage.RECORDING


def has_fresh_summary(history: list[Message]) -> bool:
    """True if a SUMMARY exists and no REWRITING has happened after it."""
    last_summary_idx: int | None = None
    for i, m in enumerate(history):
        if m.stage == Stage.SUMMARY:
            last_summary_idx = i
    if last_summary_idx is None:
        return False
    return not any(m.stage == Stage.REWRITING for m in history[last_summary_idx + 1 :])


def enforce_transition(history: list[Message], proposed: Stage) -> Stage:
    """Validate a proposed next stage; return the legal stage to use.

    Stays put on regression, redirects to the nearest required precursor on
    forbidden jumps, otherwise passes the proposal through.
    """

    cur = current_stage(history)
    visited = stages_visited(history)

    if proposed == cur:
        return proposed

    if STAGE_ORDER.index(proposed) < STAGE_ORDER.index(cur):
        return cur

    if proposed == Stage.REWRITING and Stage.INTENSITY not in visited:
        return Stage.INTENSITY

    if proposed == Stage.FINAL and not has_fresh_summary(history):
        return Stage.SUMMARY

    return proposed
