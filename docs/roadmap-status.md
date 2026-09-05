# Roadmap implementation status

Reference: `game-v0.2.1.md` in the ai-game-console-hackathon workspace. See
`v0.2.1-integration-contract.md` for the decisions made before parallel work.

## Implemented in this checkout

| Area | Implementation and acceptance route |
| --- | --- |
| Continuous run | Snake, Maze, Frogger, Asteroids in fixed order; three visible three-second transitions; full rendered input-driven runs |
| Snake | Wrapping, first-input stretch, no reversal, growth, capped speed increase, configured target; stage unit tests |
| Maze | Buffered turns, connected layout, at least eight tail segments, pellets, fatal head contact, tail attacks, safe warned ghost respawns; stage tests and live handoff |
| Frogger | Safe waiting rows, seeded moving traffic, repeated crossings, collisions, input gating; deterministic stage tests and complete runs |
| Asteroids | Acceleration, inertia, wrapping, shooting, safe warned spawns, particles, collision and victory; deterministic stage tests and complete runs |
| Configuration | Normal/Demo objectives outside stages; independent stage and companion RNG streams; fresh or explicitly reproducible seeds |
| Failure and replay | One-life failure, paused gameplay/transitions, victory/payoff, replay and title return; input-driven acceptance |
| Presentation | Stable 400x192 play area and 48-pixel companion panel; increasing stage palettes/activity; procedural sprites/audio; rendered frames |
| Development | Four stages times three checkpoint presets times two profiles; objective mechanics rather than direct progress assignment; release isolation |
| Journal | Current-run append-only semantic events, validated tags, bounded summary, retained final run until conversation ends |
| Companion | Five emotions, checkpoint priority, event-driven cooldown, nonblocking local inference, deterministic authored fallback and stale-response rejection |
| Conversation | Exactly three distinct choices per selection turn, maximum three selections, farewell, immediate skip, frozen final scene, no persistent memory |
| Bundled model | Existing Gemma/llama-server runtime reused and tested; constrained JSON and local-only requests; compatibility smoke test |
| Hardware interface | Optional semantic pulse and 13x8 blue matrix requests, rate limiting and desktop mock; not a working Uno Q output transport |

## Deliberate deviations and unresolved product decisions

- The document contains contradictory one-life and five-life rules. The full-run
  release follows the top-level one-life rule. Previous advanced Snake hazards
  remain available behind options, disabled in Normal and Demo profiles.
- The newer Pixel introduction supersedes the older instruction to boot directly
  into gameplay. The title does not preview future stages or transformations.
- Gemma selects from context-grounded authored replies rather than inventing
  unrestricted dialogue. Shape validation alone cannot enforce the roadmap's
  semantic promises. This choice makes spoilers, fake mechanical advice, and
  fabricated long-term memory rejectable at the adapter boundary.
- Model/fallback choices are identical within each turn. A late validated model
  reply cannot silently change the meaning of the player's selected option.
- A farewell has no response choices. The exactly-three-choices rule applies to
  selection turns, not the terminal farewell or replay screen.
- Automated Normal and Demo runs prove winnability, not human difficulty or
  60 to 90 seconds of play per stage. Those targets still need human tuning.

## Not complete on hardware

The supplied `/Users/j/summer-uno-q/board/` bridge has an internal `vibrate` RPC.
Its matrix displays a firmware startup frame. Its public game-accessible APIs do
not expose either semantic game feedback or dynamic matrix drawing. The game
therefore provides a tested transport contract and desktop mock, not fabricated
hardware output. The shared kit has not been modified.

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
