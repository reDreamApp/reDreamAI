-- A chat can switch between English and German mid-chat (the backend checks
-- every user message via the AI's /language/check). The journal entry keeps
-- the chat's language at the summary, so its rehearsal audio uses that
-- language instead of whatever the app is set to. Manual dreams get the app's
-- language from new app builds; older ones stay NULL (the rehearsal request's
-- language is used then).
ALTER TABLE public.dreams
    ADD COLUMN language TEXT CHECK (language IS NULL OR language IN ('en', 'de'));

-- Backfill chatbot dreams from their chat: one chat → one dream via
-- dreams.session_id = chats.id as text (see _upsert_dream_from_structured).
UPDATE public.dreams AS d
SET language = c.language
FROM public.chats AS c
WHERE d.source = 'chatbot'
  AND d.session_id = c.id::text
  AND d.user_id = c.user_id;
