# cc-arcade agents

Notes for anyone adding or reviewing arcade apps.

## Controls
- Five buttons: left/right/top/front/bottom map to logical buttons 1–5; keyboard fallback A/S/D/F/G.
- Keep on-screen labels aligned with the mapping so players don’t need paper instructions.

## Startup flow
- `startup.lua` launches `menu.lua`, which lists installed apps (Blackjack, Button Debug).
- Button 5 in the menu exits to the shell; any app should return control cleanly so the menu can be re-run.

## Design requirements
- **Must always be able to quit an app:** each app needs a reliable, discoverable exit path that works with the five-button panel (no keyboard-only escape). If a button is reused for “quit,” show it in the footer UI so players know how to leave.
- Avoid blocking loops without handling redstone/key events; keep UI responsive to exit input.
- Keep text within the screen width; truncate with ellipses when needed.

## Monitor considerations

- This project will be run on a large monitor. unless otherwise specified by the prompt, always try to match the scale to the size of the monitor.

## Testing
- Desktop: run `lua test_harness.lua` to simulate menu navigation/launch without CraftOS.
- On hardware/CC:T: reboot to land in the menu; navigate with buttons or A/S/D/F/G.
