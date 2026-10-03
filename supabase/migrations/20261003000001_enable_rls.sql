-- Row Level Security on every app table, with no policies.
--
-- Supabase's default grants let the `anon` and `authenticated` roles read and
-- write every table in `public` through PostgREST, GraphQL and Realtime, and
-- the anon key ships inside the mobile app. With RLS on and no policy, those
-- roles see nothing.
--
-- apps/api is unaffected: it connects as the tables' owner, and owners bypass
-- RLS. If a table ever has to be read by a client directly, add an explicit
-- policy for it.

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dreams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_moods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.help_center_concerns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safety_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_daily_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_consents ENABLE ROW LEVEL SECURITY;
