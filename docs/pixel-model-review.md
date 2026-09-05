# Pixel model review, September 5, 2026

This is desktop evidence from the bundled Gemma 3 270M, not Uno Q evidence.
Final headless logs are in `build/validation/final-pixel-model/`.

## Structure and delivery

- Live commentary: 10/10 samples had valid JSON/UI structure; 6/10 were accepted.
  Three repetitions and one quality rejection retained their authored fallback.
- Conversation: 10/10 turns had valid structure; 2/10 were accepted as
  `llm_conversation`. Seven quality rejections and one repetition used fallback.
  Ten atomic turns, bounded history, exit, legacy API and cleanup checks passed.
- The worst-case commentary prompt retained one prior record: 797 prompt tokens,
  128 output tokens and 16 margin tokens fit the 1024-token context. Its repeated
  `X!X!` output was rejected. No prompt-growth guarantee relies on character counts.
- The standalone model service smoke test passed. This proves inference works,
  not that its generic summary prose is suitable Pixel dialogue.

## What the samples actually sound like

| Outcome | Actual model sample | Human assessment |
| --- | --- | --- |
| Accepted live | `I can't believe it! This was supposed to be a fun day!` | A usable first-person overreaction, but not especially distinctive. |
| Accepted live | `Oh, wow! It's so amazing!` | Bland. The heuristic missed this generic enthusiasm. |
| Rejected repetition | `Wow! It's so amazing! This was really thrilling!` | Repeats a recent phrase. |
| Rejected quality | `OMG! IT WAS AMAZING! I KABORED THE FEELING OF... SURPRISINGLY FUNNY! I WENT TO,!` | Broken output, not charming confusion. |
| Rejected conversation | `A complete thought on one line, 1-80 characters, ending in . ! or ?` | Prompt echo. |
| Accepted conversation | `Is there any hope for something better?` | Original but generic and weakly connected to this run. |
| Accepted conversation | `The world needs a new way to play. A simple, satisfying experience.` | Bland product prose, not the intended robot personality. |

The first accepted conversation included `The world felt less like it had.` as
a choice. The second included `That's impossible! It's been so!`. Both passed
the limited completion heuristic despite reading as incomplete. Another accepted
live reply ended `erratically. ?`. These are known quality gaps, not successes.

Earlier exploratory runs are preserved in `build/validation/pixel-final-model/`
and `build/validation/pixel-reviewed-model/`. They produced truncated sentences
such as `A strange energy buzzes around my head. I can almost feel the faint hum
of some.` and assistant boilerplate such as `This feeling is contagious! How can
I help?`. Focused deterministic fixtures now reject these patterns.

The discovery thread supplied the stronger personality example `Another day at
the end of the world! But hey, who needs another Tuesday?`; it remains allowed
by a fixture. That is a supplied earlier sample, not a new final-run success.
Its telemetry and broken-sentence examples also have rejection fixtures.

## Limits and next decision

The automated grounding signal reported zero findings in the final live samples,
despite bland and malformed prose. It is not a personality score, grounding proof,
or comprehensive semantic validator. Rejection heuristics are an expedient quality
filter; the durable parts are original generation, strict structural validation,
bounded event-linked memory, atomic turns, freshness and fallback handling.

The model is genuinely authoring prose, but this checkpoint does not meet a claim
of consistently entertaining, grounded or complete dialogue. Further quality work
needs a separately budgeted prompt/model evaluation, not a hidden reply catalog or
an ever-growing list of forbidden sentences. The user requested closure, so these
limitations are recorded rather than starting another tuning loop.
