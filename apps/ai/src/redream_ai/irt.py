"""IRT 5-stage state machine + guardrails.

Canonical flow: recording -> intensity -> rewriting -> summary -> final.

Guardrails:
- Cannot reach REWRITING without having visited INTENSITY.
- Cannot reach FINAL without a SUMMARY in history, AND no REWRITING after the
  most recent SUMMARY (a fresh summary must be the latest synthesis).
- Stages are forward-only — no regression once advanced.
- Recording, intensity and rewriting each need two user messages before the
  flow moves on: the answer itself, then the confirmation the assistant asks
  for. Models tend to jump ahead as soon as an answer looks complete.

The routing agent (an LLM) suggests a next stage from intent; this module
enforces the rules. If the routing agent proposes a forbidden transition,
the nearest legal stage is returned instead.
"""

from __future__ import annotations

from .models import Message, Role, Stage

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


CONFIRMED_STAGES = (Stage.RECORDING, Stage.INTENSITY, Stage.REWRITING)


def user_turns_in_current_stage(history: list[Message]) -> int:
    """User messages sent since the assistant entered the current stage."""
    stage, count = Stage.RECORDING, 0
    for m in history:
        if m.role == Role.ASSISTANT and m.stage is not None:
            if m.stage != stage:
                stage, count = m.stage, 0
        elif m.role == Role.USER:
            count += 1
    return count


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
    if cur in CONFIRMED_STAGES and user_turns_in_current_stage(history) < 2:
        return cur

    if proposed == Stage.REWRITING and Stage.INTENSITY not in visited:
        return Stage.INTENSITY

    if proposed == Stage.FINAL and not has_fresh_summary(history):
        return Stage.SUMMARY

    return proposed
