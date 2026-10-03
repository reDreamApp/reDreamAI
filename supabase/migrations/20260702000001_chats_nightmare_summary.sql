-- The AI generates the nightmare summary ONCE (at the recording→rewriting
-- transition). The backend persists it here and echoes it into every later
-- /chat and /chat/stream call, so the stateless AI service (ADR 0002) never
-- regenerates it mid-conversation.
ALTER TABLE public.chats ADD COLUMN nightmare_summary TEXT;
