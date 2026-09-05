# Maze pellet target balance

## Goal

Make the normal maze stage require the player to collect at least 75% of its
129 pellets before progressing. Keep the shorter demo profile unchanged.

## Design

Set the normal maze target to 97 pellets. This rounds 75% of 129 up from 96.75,
so completing the objective always represents at least 75% of the board. Keep
the target as an explicit value in `Pacing.TARGETS`, consistent with the other
stage balance settings and independent of later maze-layout edits.

The maze continues to award 5 points per pellet. A normal completion therefore
awards 485 pellet points. Ghost bonuses remain score-only and do not advance the
objective. The demo target remains 10 pellets.

## Verification

Update player-facing documentation that lists profile targets. Run the focused
roadmap tests that verify normal and demo profile targets, pellet scoring, and
maze objective completion.
