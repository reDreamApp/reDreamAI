-- A message that switches a chat's language (en <-> de) and is a crisis
-- message gets the helpline, not an AI reply. The AI's note about the switch
-- then goes with the next AI turn instead: this flag holds it until that turn
-- is saved.
ALTER TABLE public.chats
    ADD COLUMN language_switch_pending BOOLEAN NOT NULL DEFAULT false;
