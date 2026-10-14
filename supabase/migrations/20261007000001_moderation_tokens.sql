CREATE TABLE public.moderation_tokens (
  digest varchar(64) PRIMARY KEY,
  expires_at timestamptz NOT NULL
);
ALTER TABLE public.moderation_tokens ENABLE ROW LEVEL SECURITY;
-- Only the trusted backend database role can consume capabilities.
