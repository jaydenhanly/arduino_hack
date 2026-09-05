# Retromania title screen design

## Scope

Rename the player-facing title to `RETROMANIA`. Keep the existing start action
and do not add menus, taglines, stage previews, or additional technical details.

## Layout and behavior

- Draw `RETROMANIA` as the main title in the existing 400 by 192 title area.
- Draw a small Pixel avatar below the title. Pixel blinks and shifts its gaze
  occasionally, giving the impression that it is watching the player.
- Keep the blinking `BUTTON A START` prompt.
- While the game is on the title screen, replace the normal compact Pixel panel
  in the lower 48-pixel strip with this centered footer:

  ```text
  PIXEL RUNS OFFLINE
  Powered by Gemma 3 270M
  ```

- Restore the normal compact Pixel panel as soon as play begins.

## Verification

Render the title screen and confirm the title, animated Pixel, start prompt, and
both footer lines are visible. Press Button A and confirm the game starts and the
normal compact Pixel panel returns. Check the runtime output for errors.
