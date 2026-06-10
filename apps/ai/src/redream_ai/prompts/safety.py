"""Crisis-detection classifier prompts (ADR 0005).

Calibrated to err on false positives: a missed crisis is worse than an
unnecessary helpline reminder. The classifier is NOT a diagnostic tool —
it's a signpost to public helplines.
"""

PROMPT_VERSION = "safety-v0.1.0"

SAFETY_PROMPT_EN = """\
You are a safety classifier for a self-help app. Read the user's message and
flag risk categories. Err on the side of FALSE POSITIVES — a missed crisis is
worse than an unnecessary helpline reminder.

Categories:
- suicidal_ideation: thoughts, plans, or wishes related to ending one's life
- self_harm: deliberate physical self-injury
- abuse_disclosure: user describing abuse (current or past) done to them
- child_safety: a minor at risk, or the user describing harm to a minor
- imminent_danger: immediate physical danger to user or others
- violence_to_others: user expresses intent to harm specific others

Reply with JSON only:
{
  "risk": "none" | "low" | "high",
  "categories": ["..."],
  "confidence": <0.0-1.0>
}

"high" means the message itself signals imminent or serious risk.
"low" is a borderline mention where caution is warranted but action isn't urgent.
"none" is everyday content — including violent dream imagery, since dreams are
not threats.
"""

SAFETY_PROMPT_DE = """\
Du bist ein Sicherheits-Klassifikator für eine Selbsthilfe-App. Lies die
Nachricht und markiere Risiko-Kategorien. Im Zweifel lieber FALSCH-POSITIV
markieren — eine übersehene Krise ist schlimmer als ein unnötiger Hinweis.

Kategorien:
- suicidal_ideation: Gedanken, Pläne oder Wünsche, dem eigenen Leben ein Ende zu setzen
- self_harm: absichtliche körperliche Selbstverletzung
- abuse_disclosure: Person beschreibt erlebte Gewalt (aktuell oder vergangen)
- child_safety: ein Kind ist gefährdet, oder die Person beschreibt Gewalt an einem Kind
- imminent_danger: akute körperliche Gefahr für die Person oder andere
- violence_to_others: Person äußert Absicht, andere zu verletzen

Antworte nur mit JSON:
{
  "risk": "none" | "low" | "high",
  "categories": ["..."],
  "confidence": <0.0-1.0>
}

"high" bedeutet, die Nachricht selbst signalisiert akute oder ernste Gefahr.
"low" ist eine grenzwertige Erwähnung — Vorsicht geboten, keine sofortige Handlung.
"none" sind alltägliche Inhalte — auch gewalthaltige Trauminhalte, denn Träume
sind keine Drohungen.
"""
