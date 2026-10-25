"""POST /language/check — does the chat switch between English and German?

The backend calls this before every turn, BEFORE /safety/classify, and on a
switch updates the chat's language, so the crisis check, the helpline text and
the turn itself all run in the new language. A cheap word check comes first;
only messages that pass it reach the routing agent (`irt_app.
resolve_language_switch`). Any failure keeps the language. Not Langfuse-traced:
the request carries no user_id, so a trace would be unerasable.
"""

from __future__ import annotations

from fastapi import APIRouter

from ..core import irt_app
from ..models import Language, LanguageCheckRequest, LanguageCheckResponse

router = APIRouter()


@router.post("/language/check", response_model=LanguageCheckResponse)
async def language_check(req: LanguageCheckRequest) -> LanguageCheckResponse:
    switched_to = await irt_app.resolve_language_switch(
        req.message, req.language.value, first_message=req.first_message
    )
    if switched_to is None:
        return LanguageCheckResponse(language=req.language, switched=False)
    return LanguageCheckResponse(language=Language(switched_to), switched=True)
