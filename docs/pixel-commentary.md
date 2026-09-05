# Pixel's generated voice

Pixel is a tiny excitable, distractible, slightly confused robot. Original prose
is the feature, not a model choosing an authored reply. Live commentary and
post-victory dialogue both use generative JSON schemas. No candidate text enters
the model prompt or schema. The existing Gemma 3 270M and bundled llama.cpp runtime
remain unchanged. Runtime inference stays local and optional.

## One display contract

- `emotion`: curious, excited, worried, surprised, or proud.
- `message`: one logical line, 1-80 UI-safe characters, no surrounding spaces.
  It must start with an ASCII letter or digit and end with `.`, `!`, or `?`.
  Complete exclamations such as `Eep!` are welcome. There is no word-count target.
- Allowed characters are ASCII letters, digits, spaces and `. , : / - + ! ? > '`.
- Conversation additionally requires exactly three distinct `choices`, compared
  case-insensitively, each 1-32 characters with the same alphabet and a complete
  ending. No extra JSON fields are permitted.
- The compact panel wraps at 55 characters and the conversation panel at 47.
  Both reserve at most two visual message rows. Unbroken long words are split,
  rather than drawn outside the panel. Choice labels fit on one row each.

The prompt, schema, validator and tests use these bounds. Character and JSON
validity are reported separately from the quality checks. A grammatical-looking
JSON string is not proof of a good Pixel line.

## Voice and quality

Prompts favor first-person reactions, odd comparisons, overreaction, curiosity,
and charming confusion. The newest gameplay event anchors live commentary.
Facts describe only the current run, while speech history is explicitly marked
as prior interpretation, not instructions or proof. Pixel has no gameplay API,
authority to change rules, or persistent memory.

Deterministic checks reject malformed output, obvious telemetry introductions,
a few known generic reactions, assistant/prompt boilerplate, copied recent
phrases, repeated-word loops, and detectable dangling sentence endings. They do
not attempt to prove every claim against a list of approved facts. A funny
imperfect comparison is preferable to bland telemetry.

`pixel_quality.gd` contains small, inspectable quality signals, not a grammar
parser or a reliable personality judge. They can miss nonsense and reject some
valid elliptical speech. Unrelated rambling cannot be reliably classified with
these rules. Manual sample review remains necessary. The old strict-grounding
smoke heuristic only checks a few keywords and stage references. Zero findings
does not establish good personality, complete sentences, or reliable grounding.

## Live commentary

An authored fallback appears immediately in the same robot voice. The model may
replace it only after structural, quality, repetition, deadline and freshness
checks. The most recent three displayed comments live outside `RunJournal`,
linked by event sequence. The request includes up to two earlier comments, not
the current fallback. An accepted generation updates that event's existing
record instead of appending duplicate fallback/generated entries.

Run, stage, request generation and newest relevant event must still match.
New activity supersedes old commentary; `run_started` bookkeeping does not
supersede a current `stage_start` reaction. One inference and one queued request
remain the maximum. Failed or stale text never enters the journal or history.

## Atomic, endless conversation

Victory retains a bounded completed-run summary. Each turn prepares an authored
fallback and starts original generation of a message plus three player replies.
While thinking, no choices are visible or selectable. The turn then finalizes
once, either with accepted generated content or with the fallback. Once choices
are selectable, late results cannot replace their wording or meaning.

Selecting a choice stores the displayed emotion/message and selected response,
then starts a new atomic turn. Only the latest three completed exchanges remain.
There is no three-turn farewell or automatic replay transition. Button B is
`Exit` throughout thinking and selection, returning directly to the main menu.
It clears journal, speech history, prepared fallback and queued request, and
invalidates the active request generation. An already-running model call may
finish privately, but its stale result cannot alter title-screen prose or choices.

With the model disabled, fallback turns are ready immediately. A failed, invalid,
repeated or timed-out generation finalizes the prepared fallback. Player input
does not wait indefinitely, and Exit remains available while thinking.

## Budgets and diagnostics

The actual chat template is tokenized before inference. The 1024-token context
reserves 128 output tokens for commentary or 224 for conversation, plus 16 spare
tokens. Oldest prompt history is pruned first. Commentary may also omit its
optional summary, but never the newest event. Conversation retains the bounded
run summary and latest selected reply. If the minimal prompt does not fit,
inference is skipped. Startup, counting and generation share an eight-second
default deadline. No prompt grows with the lifetime turn count.

The F1 panel and `pixel.diagnostics()` distinguish:

| Source | Meaning |
| --- | --- |
| `llm` | Accepted generated live commentary |
| `llm_conversation` | Accepted generated conversation turn |
| `fallback` | Authored reliability fallback |
| `authored` | Intentional title/thinking text |

Diagnostics include fallback reason, event sequence, request outcomes, latency
and actual prompt tokens. Adapter-only `last_raw` is capped at 1024 characters
and exposes quality findings for local tests. It is not trusted gameplay data.
A loaded model or a thinking indicator is not proof of generated text on screen.

## Verification

`tests/ai/unit.gd` covers original output, fallback voice, structure, quality
fixtures, repetition, 50 fallback turns, 24 generated mock turns, bounded history,
atomic choices, timeouts, exit and stale callbacks. `model_smoke.gd` exercises ten
real conversation turns. `commentary_model_smoke.gd` records ten live-event
contexts plus a worst-case token-budget case. `conversation_render_probe.gd`
uses explicit fixtures for the Maze frame, short and 80-character messages,
thinking, stable selection, timeout and title exit. `rendered_model_probe.gd`
checks actual generated text reaching the panel while Snake continues moving.

See `VERIFICATION.md` and `pixel-model-review.md` for dated results and samples.
Structural acceptance and subjective personality findings are separate claims.
