# Live Pixel commentary

Implemented September 5, 2026. This changes commentary during gameplay, not the
three-selection post-victory conversation. The bundled Gemma 3 270M model and
llama.cpp b10819 runtime are unchanged. No hosted inference or runtime downloads
were added.

## Generation and trust

`gemma_adapter.gd` sends commentary facts and recent speech without candidate
replies. `commentary_prompt.gd` defines Pixel, emotions, UI constraints, field
meanings and the vocabulary actually present in the context. It gives the newest
event a plain-language description, not a proposed reply. Pixel may express its
own preferences and playful metaphors, but is instructed not to invent events,
player intentions/feelings, mechanics, prior-run memories or gameplay authority.

`pixel_reply.gd` accepts an original JSON object containing exactly `emotion`
and `message`. Emotions are curious, excited, worried, surprised and proud.
Messages contain 1-80 ASCII letters, digits, spaces or `. , : / - + ! ? > '`.
They cannot contain newlines or surrounding whitespace. The generation grammar
enforces the same character constraints. Candidate equality remains mandatory
for post-victory conversation only.

The schema's field descriptions are documentation, not a replacement for prompt
instructions. llama.cpp uses the schema to constrain tokens; it does not place
those descriptions in the chat prompt. Its pinned grammar compiler requires a
literal leading hyphen in the character class; an escaped hyphen is unsupported.

## Event-linked memory and freshness

- `RunJournal` stores only validated gameplay facts. Generated prose never enters it.
- The controller stores the latest three displayed comments separately, each
  carrying `event_sequence`, `stage`, `kind`, `emotion` and `message`.
- An immediate authored fallback creates the event's record. Its generation
  request includes up to two earlier records, not that fallback's wording.
- A validated, current response replaces the same event's record. Invalid,
  repeated, timed-out and stale responses cannot enter commentary history.
- New runs, reset and conversation exit clear the history. Returned histories
  and contexts are copies, not writable access to internal state.
- Requests must match run, stage, generation, both deadlines, and the latest
  commentary-relevant event sequence. New activity makes older commentary stale.
  The first-input `run_started` bookkeeping event does not invalidate an otherwise
  current `stage_start` reaction. Checkpoints, stage changes and terminal events
  retain priority. One inference and one queued request remain the maximum.

Commentary rejects case/punctuation-equivalent repetition and a copied span of
five words from recent displayed comments. This is a repetition heuristic, not a
semantic similarity model. Commentary sampling considers the entire 1024-token
window with a 1.15 repetition penalty. Conversation sampling is unchanged.

## Token and time budgets

Commentary reserves 128 output tokens and a 16-token margin. Before generation,
the service calls the local runtime's `/apply-template` and `/tokenize` endpoints
to count the actual formatted system and user prompt. Older history is removed
first if necessary, then the optional summary. The newest event is never removed.
If the prompt still cannot fit, or counting fails, generation is skipped and
the authored fallback stays visible. Counting, startup and generation all share
the existing request deadline, eight seconds by default.

## Diagnostics

`pixel.diagnostics()` returns copies of:

- `source`: `authored`, `fallback`, `llm` for generated commentary, or
  `llm_selected` for an authored conversation candidate chosen by the model.
- `event_sequence` and `fallback_reason` for the displayed message.
- `last_request`: run/event identity, conversation flag, outcome, latency and
  actual prompt token count. This may describe a stale request, not the screen.
- `totals`: controller-lifetime requested, accepted, stale and failed counts.

`request_finished(details)` publishes each completed dispatched request's
outcome. These diagnostics contain no rejected generated prose. The F1 developer
panel shows message source, event sequence and fallback reason; the normal HUD
does not expose debugging details. A loaded model or thinking indicator alone
does not prove that generated text reached the display.

## Verification and limits

`tests/ai/unit.gd` covers novel messages, UI/schema bounds, unchanged conversation
allowlists, history replacement/isolation, repetition, stale callbacks,
timeouts, disabled models, token counting failures and context pruning.
`tests/ai/rendered_model_probe.gd` requires an accepted `llm` message on screen
while real input moves Snake. Its route avoids collecting an apple during the
stage-start request, which would correctly supersede that request's event.

`tests/ai/commentary_model_smoke.gd` exercises ten real gameplay-event contexts
and an oversized worst-case context. It reports generated-message acceptance
separately from grounding findings. Repeated replies are expected to leave the
authored fallback intact, not count as successful model delivery.

Run it with `-- --strict-grounding` to fail on the grounding review heuristics.
Those checks flag prompt echo, selected unsupported claims, stage-start
contradictions and non-current-stage references. They can flag legitimate
metaphors or recollections and miss other hallucinations. Human review of the
logged event/reply pairs is still required. A passing sample is not a guarantee.

Observed limitation: the bundled 270M model can produce valid, original JSON but
refer to an earlier stage instead of the newest event. In the recorded strict
run, it said "The ghost escaped!" about a traffic-danger event. This is not fixed
by schema validation or repetition penalties. The change therefore proves real
generation and safe data/lifecycle handling, not production-quality grounding.
Model replacement or task-specific training needs a separate quality and target
hardware evaluation. See `VERIFICATION.md` for measured results.
