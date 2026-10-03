"""IRT state machine + guardrails (`redream_ai.irt`)."""

from __future__ import annotations

from redream_ai.irt import (
    STAGE_ORDER,
    current_stage,
    enforce_transition,
    has_fresh_summary,
    stages_visited,
    user_turns_in_current_stage,
)
from redream_ai.models import Message, Role, Stage


def _assistant(text: str, stage: Stage) -> Message:
    return Message(role=Role.ASSISTANT, content=text, stage=stage)


def _user(text: str) -> Message:
    return Message(role=Role.USER, content=text)


def _answer_and_confirm() -> list[Message]:
    return [_user("answer"), _user("yes")]


class TestCurrentStage:
    def test_empty_history_is_recording(self) -> None:
        assert current_stage([]) == Stage.RECORDING

    def test_returns_latest_staged_assistant_message(self) -> None:
        history = [
            _user("hi"),
            _assistant("tell me about your dream", Stage.RECORDING),
            _user("scary one"),
            _assistant("on a 0-10 scale?", Stage.INTENSITY),
        ]
        assert current_stage(history) == Stage.INTENSITY

    def test_ignores_user_messages_without_stage(self) -> None:
        history = [
            _assistant("...", Stage.REWRITING),
            _user("ok"),
        ]
        assert current_stage(history) == Stage.REWRITING


class TestGuardrails:
    def test_cannot_skip_to_rewriting_without_intensity(self) -> None:
        history = [
            _user("nightmare description"),
            _assistant("...", Stage.RECORDING),
            _user("yes"),
        ]
        assert enforce_transition(history, Stage.REWRITING) == Stage.INTENSITY

    def test_cannot_skip_to_final_without_summary(self) -> None:
        history = [
            _assistant("...", Stage.RECORDING),
            _assistant("rate it 0-10", Stage.INTENSITY),
            _assistant("let's rewrite", Stage.REWRITING),
            *_answer_and_confirm(),
        ]
        assert enforce_transition(history, Stage.FINAL) == Stage.SUMMARY

    def test_final_allowed_after_fresh_summary(self) -> None:
        history = [
            _assistant("...", Stage.RECORDING),
            _assistant("...", Stage.INTENSITY),
            _assistant("...", Stage.REWRITING),
            _assistant("here is the summary", Stage.SUMMARY),
        ]
        assert enforce_transition(history, Stage.FINAL) == Stage.FINAL

    def test_final_blocked_if_rewriting_after_summary(self) -> None:
        history = [
            _assistant("...", Stage.RECORDING),
            _assistant("...", Stage.INTENSITY),
            _assistant("...", Stage.REWRITING),
            _assistant("summary v1", Stage.SUMMARY),
            _assistant("more rewriting", Stage.REWRITING),
            *_answer_and_confirm(),
        ]
        assert enforce_transition(history, Stage.FINAL) == Stage.SUMMARY

    def test_cannot_regress(self) -> None:
        history = [
            _assistant("...", Stage.RECORDING),
            _assistant("...", Stage.INTENSITY),
        ]
        assert enforce_transition(history, Stage.RECORDING) == Stage.INTENSITY

    def test_can_stay(self) -> None:
        history = [_assistant("...", Stage.REWRITING)]
        assert enforce_transition(history, Stage.REWRITING) == Stage.REWRITING

    def test_can_advance_one_step(self) -> None:
        history = [_user("dream"), _assistant("continue?", Stage.RECORDING), _user("yes")]
        assert enforce_transition(history, Stage.INTENSITY) == Stage.INTENSITY

    def test_first_message_in_stage_cannot_advance(self) -> None:
        assert enforce_transition([_user("a complete dream")], Stage.INTENSITY) == Stage.RECORDING
        history = [
            _user("dream"),
            _assistant("continue?", Stage.RECORDING),
            _user("yes"),
            _assistant("0-10?", Stage.INTENSITY),
            _user("7"),
        ]
        assert enforce_transition(history, Stage.REWRITING) == Stage.INTENSITY

    def test_rewrite_needs_confirmation_before_summary(self) -> None:
        history = [
            _assistant("...", Stage.INTENSITY),
            _assistant("what would you change?", Stage.REWRITING),
            _user("an owl guides me home"),
        ]
        assert enforce_transition(history, Stage.SUMMARY) == Stage.REWRITING
        history += [_assistant("satisfied?", Stage.REWRITING), _user("yes")]
        assert enforce_transition(history, Stage.SUMMARY) == Stage.SUMMARY

    def test_user_turns_reset_when_stage_changes(self) -> None:
        history = [
            _user("dream"),
            _user("more"),
            _assistant("0-10?", Stage.INTENSITY),
            _user("7"),
        ]
        assert user_turns_in_current_stage(history) == 1


class TestHasFreshSummary:
    def test_no_summary_yet(self) -> None:
        assert not has_fresh_summary([_assistant("...", Stage.REWRITING)])

    def test_summary_present_no_rewriting_after(self) -> None:
        history = [
            _assistant("...", Stage.REWRITING),
            _assistant("...", Stage.SUMMARY),
        ]
        assert has_fresh_summary(history)

    def test_rewriting_invalidates_summary(self) -> None:
        history = [
            _assistant("...", Stage.SUMMARY),
            _assistant("...", Stage.REWRITING),
        ]
        assert not has_fresh_summary(history)


def test_stages_visited_collects_distinct_stages() -> None:
    history = [
        _assistant("a", Stage.RECORDING),
        _assistant("b", Stage.RECORDING),
        _assistant("c", Stage.INTENSITY),
    ]
    assert stages_visited(history) == {Stage.RECORDING, Stage.INTENSITY}


def test_stage_order_is_canonical() -> None:
    assert STAGE_ORDER == (
        Stage.RECORDING,
        Stage.INTENSITY,
        Stage.REWRITING,
        Stage.SUMMARY,
        Stage.FINAL,
    )
