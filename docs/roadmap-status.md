# Roadmap implementation status

Reference: `game-v0.2.1.md` in the ai-game-console-hackathon workspace. See
`v0.2.1-integration-contract.md` for the decisions made before parallel work.

## Implemented in this checkout

| Area | Implementation and acceptance route |
| --- | --- |
| Continuous run | Snake, Maze, Frogger, Asteroids in fixed order; three visible three-second transitions; full rendered input-driven runs |
| Snake | Wrapping, first-input stretch, no reversal, growth, capped speed increase, configured target; stage unit tests |
| Maze | Authored 24x12 ASCII topology, shared neighbors, one tunnel, nine-cell entrance relocation, buffered turns, pellets, fatal head contact, tail attacks, safe warned central respawns |
| Frogger | Seeded traffic, repeated crossings, 0.25-second reset grace plus neutral rearm while traffic moves; deterministic and rendered tests |
| Asteroids | Acceleration, inertia, wrapping, shooting, safe warned spawns, particles, collision and victory; deterministic stage tests and complete runs |
| Configuration | Normal/Demo objectives outside stages; independent stage and companion RNG streams; fresh or explicitly reproducible seeds |
| Failure and replay | One-life failure, paused gameplay/transitions, victory/payoff, replay and title return; input-driven acceptance |
| Presentation | Stable 400x192 play area and 48-pixel companion panel; increasing stage palettes/activity; procedural sprites/audio; rendered frames |
| Development | Four stages times three checkpoint presets times two profiles; objective mechanics rather than direct progress assignment; release isolation |
| Journal | Current-run append-only semantic events, validated tags, bounded summary, retained final run until conversation ends |
| Companion | LLM-authored live commentary, five emotions, bounded event-linked history, source diagnostics, deterministic immediate fallback and stale-response rejection |
| Conversation | Original generated message and three distinct responses; atomic thinking-to-ready turns, endless bounded history, B exits to title and clears pending state |
| Bundled model | Existing Gemma/llama-server runtime reused and tested; constrained JSON and local-only requests; compatibility smoke test |
| Hardware interface | Optional semantic pulses and abstract 13x8 aura, bounded versioned local socket, priorities, rate limits and desktop mock; not physically verified |

## Deliberate deviations and unresolved product decisions

- The document contains contradictory one-life and five-life rules. The full-run
  release follows the top-level one-life rule. Previous advanced Snake hazards
  remain available behind options, disabled in Normal and Demo profiles.
- The newer Pixel introduction supersedes the older instruction to boot directly
  into gameplay. The title does not preview future stages or transformations.
- Live commentary and conversation preserve original LLM prose. Structural checks
  and a limited quality heuristic reject some broken, repetitive and bland output,
  but cannot establish personality quality or factual grounding.
- Conversation choices become selectable only after one atomic model/fallback
  result. No late result can replace a ready turn. There is no automatic farewell.
- The current staged balance adjustment sets Normal Maze to 97 pellets, rather
  than the earlier requested 30. That existing adjustment is preserved; Demo is 10.
- Automated Normal and Demo runs prove winnability, not human difficulty or
  60 to 90 seconds of play per stage. Those targets still need human tuning.

## Not complete on hardware

The supplied `/Users/j/summer-uno-q/board/` bridge has an internal `vibrate` RPC.
Its matrix displays a firmware startup frame. Its public game-accessible APIs do
not expose either semantic game feedback or dynamic matrix drawing. The game
therefore provides a tested transport contract and desktop mock, not fabricated
hardware output. Earlier edits to `board/install-game.sh` and the new
`board/bridge/summer_feedback/` are frozen, preserved, and inventoried in
`shared-kit-frozen.md`. No further shared-kit work or deployment is authorized.

Finishing this part requires an approved kit extension providing the output
transport, followed by physical installation through the supplied scripts. App
name and icon must be confirmed before deployment. Real joystick/button mapping,
matrix/haptics, Linux inference latency, frame time and human legibility must be
checked on the board. A host-exported ARM64 ZIP alone cannot prove those checks.

## Explicitly deferred by the reference

Sensors, side quests, mini-bosses, an AI gameplay director, another AI-driven
stage, hybrid rulesets and phone audio are later iterations, not v0.2.1 scope.
Pixel has no API to change rules, spawn objects, score points or modify a future
run. No paid generation, cloud model, persistence or multiplayer was introduced.
