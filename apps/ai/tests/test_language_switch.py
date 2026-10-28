"""Switching a chat between English and German mid-chat, without network.

The backend asks POST /language/check before every turn; on a switch it updates
the chat's language and sends `language_switched=True` with that turn, which
adds a note to the stage prompt. A cheap word check keeps most messages away
from the model, and any failure keeps the language.
"""

from __future__ import annotations

import asyncio

import pytest
from fastapi.testclient import TestClient

from redream_ai.core import irt_app
from redream_ai.core.models import ChatInput, Conversation
from redream_ai.core.models import ChatResponse as PortedResponse
from redream_ai.core.prompts import (
    LANGUAGE_CHECK_PROMPT,
    LANGUAGE_SWITCH_NOTE_DE,
    LANGUAGE_SWITCH_NOTE_EN,
    REWRITING_NOTHING_YET_NOTE_DE,
    ROUTING_PROMPTS,
    SCOPE_BOUNDARY_DE,
    SCOPE_BOUNDARY_EN,
    SYSTEM_PROMPT_TEMPLATES_DE,
    SYSTEM_PROMPT_TEMPLATES_EN,
    TALK_GATE_PROMPT,
)
from redream_ai.main import app


class _Check:
    """Stands in for the routing agent on the language check."""

    def __init__(self, answer: str = "OTHER", fail: Exception | None = None, delay: float = 0):
        self.answer = answer
        self.fail = fail
        self.delay = delay
        self.calls: list[str] = []

    async def generate(self, prompt, system_prompt=None, **kwargs):
        assert system_prompt == LANGUAGE_CHECK_PROMPT
        self.calls.append(prompt)
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.fail:
            raise self.fail
        return self.answer, {}, None


@pytest.fixture
def check(monkeypatch):
    agent = _Check()
    monkeypatch.setattr(irt_app, "routing_agent", agent)
    monkeypatch.setattr(irt_app, "_language_verdicts", {})
    return agent


# --- the word check before the model ---------------------------------------------


@pytest.mark.parametrize(
    ("current", "message"),
    [
        ("en", "kannst du deutsch reden"),
        ("en", "nicht im traum, generell"),
        ("en", "Auf Deutsch bitte"),
        ("en", "Können wir auf Deutschen weitermachen?"),
        ("de", "can we speak english please"),
        ("de", "I had a dream about my brother"),
        ("de", "Lieber auf Englisch"),
        # Contractions are one word, with either apostrophe; "German" in a
        # German chat is an English word.
        ("de", "I don't speak German"),
        ("de", "Sorry I don\u2019t speak German"),
        ("de", "I don't understand"),
        ("de", "No German please"),
        ("en", "Kein Englisch"),
        ("en", "Can you speak Hochdeutsch"),
        # Short plain sentences, distress included.
        ("de", "I feel hopeless"),
        ("de", "I need help"),
        ("de", "I woke up screaming"),
        ("en", "Es hat keinen Sinn mehr"),
        ("en", "Mir geht es heute schlecht"),
        ("en", "Niemand versteht mich"),
        ("en", "Es war dunkel und kalt"),
        ("en", "Bitte antworte in meiner Sprache"),
        # One word of the other language and none of the current one.
        ("en", "Ich will sterben"),
        ("en", "Der Traum war schlimm"),
        ("de", "Life is pointless"),
        ("de", "I'm not okay"),
    ],
)
def test_these_messages_reach_the_model(current, message):
    assert irt_app._may_switch_language(message, current) is True


@pytest.mark.parametrize(
    ("current", "message"),
    [
        ("en", "ja"),
        ("en", "ok"),
        ("en", "I was in Berlin"),
        ("en", "Danke"),
        ("en", "I dreamt my Oma said ich liebe dich to me"),  # a quote in an English sentence
        ("de", "ok"),
        ("de", "nein"),
        ("de", "Ich war in London"),
        ("de", "Ich hatte einen Traum über meinen Bruder"),
        ("en", "I was at the Oktoberfest with my friends"),
        ("en", "The wolf was chasing me in the forest"),
        ("de", "Mein Hund heißt Buddy"),
        ("de", "Ich habe Angst vor dem Wolf"),
        ("de", "I\u2019m scared"),  # two words
        ("de", "Ich habe The Walking Dead gesehen"),  # a title in a German sentence
        ("de", "Ich habe Harry Potter gelesen"),
    ],
)
def test_these_messages_do_not(current, message):
    assert irt_app._may_switch_language(message, current) is False


@pytest.mark.parametrize("message", ["ja", "ok", "I was in Berlin", "Danke"])
async def test_a_message_that_fails_the_word_check_costs_no_call(check, message):
    assert await irt_app.resolve_language_switch(message, "en") is None
    assert check.calls == []


async def test_an_empty_message_or_an_unknown_language_is_kept(check):
    assert await irt_app.resolve_language_switch("   ", "en") is None
    assert await irt_app.resolve_language_switch("kannst du deutsch reden", "fr") is None
    assert check.calls == []


# --- the model's answer ----------------------------------------------------------


@pytest.mark.parametrize(
    ("current", "message", "answer", "expected"),
    [
        ("en", "kannst du deutsch reden", "DE", "de"),
        ("en", "kannst du deutsch reden", " de.\n", "de"),
        ("de", "I had a dream about my brother", "EN", "en"),
        ("en", "nicht im traum, generell", "OTHER", None),
        ("de", "ich renne and all the bells are ringing", "MIXED", None),
        ("en", "nicht im traum, generell", "KEEP", None),  # not one of the words
        ("en", "nicht im traum, generell", "EN", None),  # the current language: keep
        ("de", "can we speak english please", "DE", None),
        ("en", "kannst du deutsch reden", "Deutsch, please", None),  # not one of the words
        ("en", "kannst du deutsch reden", "DE/EN", None),
        ("en", "kannst du deutsch reden", "EN or DE", None),
        ("en", "kannst du deutsch reden", "DE!", "de"),
        ("en", "kannst du deutsch reden", "", None),
    ],
)
async def test_the_answer_decides(check, current, message, answer, expected):
    check.answer = answer
    assert await irt_app.resolve_language_switch(message, current) == expected
    assert len(check.calls) == 1


async def test_the_model_gets_only_the_message(check):
    """It names the message's language; the code compares with the chat's."""
    check.answer = "DE"
    await irt_app.resolve_language_switch(" kannst du deutsch reden ", "en")
    assert check.calls == ["kannst du deutsch reden"]
    await irt_app.resolve_language_switch("can we speak english please", "de")
    assert check.calls[-1] == "can we speak english please"


async def test_an_error_keeps_the_language_and_is_not_remembered(monkeypatch):
    monkeypatch.setattr(irt_app, "routing_agent", _Check(fail=RuntimeError("provider down")))
    monkeypatch.setattr(irt_app, "_language_verdicts", {})
    assert await irt_app.resolve_language_switch("kannst du deutsch reden", "en") is None
    assert irt_app._language_verdicts == {}


async def test_a_timeout_keeps_the_language(monkeypatch):
    monkeypatch.setattr(irt_app, "routing_agent", _Check(answer="DE", delay=1))
    monkeypatch.setattr(irt_app, "_language_verdicts", {})
    monkeypatch.setattr(irt_app, "_LANGUAGE_CHECK_TIMEOUT_S", 0.01)
    assert await irt_app.resolve_language_switch("kannst du deutsch reden", "en") is None
    assert irt_app._language_verdicts == {}


async def test_without_agents_the_language_stays(monkeypatch):
    monkeypatch.setattr(irt_app, "routing_agent", None)
    monkeypatch.setattr(irt_app, "_language_verdicts", {})
    assert await irt_app.resolve_language_switch("kannst du deutsch reden", "en") is None


async def test_an_answer_is_remembered_without_the_text(check):
    check.answer = "DE"
    assert await irt_app.resolve_language_switch("Kannst du Deutsch reden", "en") == "de"
    assert await irt_app.resolve_language_switch("kannst du deutsch reden ", "en") == "de"
    assert len(check.calls) == 1  # the second answer came from memory
    assert all("deutsch" not in key for key in irt_app._language_verdicts)
    # The same text in the other chat language is a different question.
    check.answer = "OTHER"
    assert await irt_app.resolve_language_switch("kannst du deutsch reden", "de") is None
    assert len(check.calls) == 1  # names no other language: the word check stops it


# --- POST /language/check --------------------------------------------------------


@pytest.fixture
def client(check):
    with TestClient(app) as c:
        yield c


def test_the_route_reports_a_switch(client, check):
    check.answer = "DE"
    body = {"message": "kannst du deutsch reden", "language": "en"}
    r = client.post("/language/check", json=body)
    assert r.status_code == 200
    assert r.json() == {"language": "de", "switched": True}


def test_the_route_reports_no_switch(client, check):
    r = client.post("/language/check", json={"message": "ok", "language": "de"})
    assert r.status_code == 200
    assert r.json() == {"language": "de", "switched": False}
    assert check.calls == []


@pytest.mark.parametrize(
    "body",
    [
        {"language": "en"},
        {"message": "hello there friend"},
        {"message": "bonjour", "language": "fr"},
        {"message": "hi", "language": "en", "session_id": "s"},  # extra fields are refused
    ],
)
def test_the_route_validates_its_body(client, check, body):
    assert client.post("/language/check", json=body).status_code == 422
    assert check.calls == []


# --- the turn after a switch -----------------------------------------------------


def _conversation(language: str) -> Conversation:
    c = Conversation(session_id="s", language=language)
    c.add_message("A wolf stood at my door.", "user")
    c.stages = []
    return c


async def test_the_switch_note_is_added_only_on_the_switch():
    c = _conversation("de")
    assert await irt_app._stage_note("summary", None, c, "de") is None
    assert await irt_app._stage_note("summary", None, c, "de", False, True) == (
        LANGUAGE_SWITCH_NOTE_DE
    )
    assert await irt_app._stage_note("final", None, c, "en", False, True) == (
        LANGUAGE_SWITCH_NOTE_EN
    )
    # With another note, the switch note comes last.
    assert await irt_app._stage_note("rewriting", None, c, "de", True, True) == (
        REWRITING_NOTHING_YET_NOTE_DE + "\n\n" + LANGUAGE_SWITCH_NOTE_DE
    )


class _Turn:
    """Routing and response agent in one: moves on to the summary, records the reply prompt."""

    def __init__(self):
        self.system_prompts: list[str] = []

    async def generate(self, prompt, system_prompt=None, **kwargs):
        if system_prompt in ROUTING_PROMPTS.values():
            return "YES", {}, None  # the step check
        self.system_prompts.append(system_prompt)
        return "Antwort", {"input": 1, "output": 1, "total": 2}, None

    async def generate_stream(self, prompt, system_prompt=None):
        self.system_prompts.append(system_prompt)
        yield "Antwort", None, None
        yield "", {"input": 1, "output": 1, "total": 2}, None


def _summary_ready() -> Conversation:
    c = Conversation(session_id="s", language="de")
    c.add_message("A wolf stood at my door.", "user")
    c.add_message("Shall we rewrite it?", "assistant", "recording")
    c.add_message("The wolf becomes my dog.", "user")
    c.add_message("Lovely. Shall I write the summary?", "assistant", "rewriting")
    c.stages = ["recording", "rewriting"]
    return c


@pytest.mark.parametrize("switched", [True, False])
@pytest.mark.parametrize("streaming", [True, False])
async def test_both_paths_add_the_note_only_on_the_switch(monkeypatch, switched, streaming):
    agent = _Turn()
    monkeypatch.setattr(irt_app, "routing_agent", agent)
    monkeypatch.setattr(irt_app, "response_agent", agent)

    async def tells_the_dream(text, any_length=False):
        return False

    monkeypatch.setattr(irt_app, "_is_plain_talk", tells_the_dream)
    chat_input = ChatInput(
        session_id="s",
        message="Der Wolf wird mein Hund. Ja, bitte die Zusammenfassung.",
        language_override="de",
        language_switched=switched,
    )

    if streaming:
        frames = [
            f async for f in irt_app.process_chat_message_stream(chat_input, _summary_ready())
        ]
        assert frames[-1] == "data: [DONE]\n\n"
    else:
        await irt_app.process_chat_message(chat_input, _summary_ready())

    (system_prompt,) = agent.system_prompts
    assert system_prompt.startswith(SCOPE_BOUNDARY_DE)
    assert SYSTEM_PROMPT_TEMPLATES_DE["summary"] in system_prompt
    assert system_prompt.endswith(LANGUAGE_SWITCH_NOTE_DE) is switched
    assert LANGUAGE_SWITCH_NOTE_EN not in system_prompt
    assert SYSTEM_PROMPT_TEMPLATES_EN["summary"] not in system_prompt


def test_the_chat_route_passes_the_flag_on(monkeypatch):
    seen = []

    async def fake(chat_input, conversation, safety_enabled=True):
        seen.append(chat_input.language_switched)
        conversation.stages.append("recording")
        return PortedResponse(
            session_id="s", stage="recording", response="ok", stages=conversation.stages
        )

    monkeypatch.setattr(irt_app, "routing_agent", object())
    monkeypatch.setattr(irt_app, "response_agent", object())
    monkeypatch.setattr(irt_app, "process_chat_message", fake)
    with TestClient(app) as c:
        for body in ({"language_switched": True}, {}):
            r = c.post(
                "/chat",
                json={"messages": [{"role": "user", "content": "hi"}], "language": "en", **body},
            )
            assert r.status_code == 200
    assert seen == [True, False]


# --- the prompts -----------------------------------------------------------------


def test_the_language_paragraphs_point_to_writing_in_the_other_language():
    # The guide only talks about language when asked, or for a third language:
    # in the 2026-10-25 screenshot it told a user who wrote "Thank you." that
    # they could simply write in English.
    assert (
        "\n- Language: the chat is held in English or German and switches by itself when "
        "the user writes in the other one. If the user asks for German, say they can simply "
        "write in German. If they write in or ask for another language, say in English that "
        "this chat can be held in English or German, and respond to the rest of their "
        "message. Otherwise say nothing about language.\n"
    ) in SCOPE_BOUNDARY_EN
    assert (
        "\n- Sprache: Der Chat läuft auf Deutsch oder Englisch und wechselt von selbst, wenn "
        "der Nutzer in der anderen Sprache schreibt. Bittet er um Englisch, sag, dass er "
        "einfach auf Englisch schreiben kann. Schreibt er in einer anderen Sprache oder "
        "bittet er um eine, sag auf Deutsch, dass dieser Chat auf Deutsch oder Englisch "
        "geführt werden kann, und geh auf den Rest seiner Nachricht ein. Sonst sag nichts "
        "zur Sprache.\n"
    ) in SCOPE_BOUNDARY_DE
    for boundary in (SCOPE_BOUNDARY_EN, SCOPE_BOUNDARY_DE):
        assert "settings" not in boundary and "Einstellungen" not in boundary


def test_the_language_check_answers_in_one_word():
    assert LANGUAGE_CHECK_PROMPT.endswith("Answer only EN, DE, MIXED or OTHER.")
    assert LANGUAGE_CHECK_PROMPT != TALK_GATE_PROMPT
