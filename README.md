# Key Hints

Hold **Super** and, after a moment, a translucent frosted card appears in the
top-right corner, under the bar. It's an Omarchy shell plugin.

- **Left column: Omarchy shortcuts** for the modifiers you're holding, read live
  from `omarchy-menu-keybindings --print` so custom bindings show up.
  - Families are collapsed, e.g. `1–0 Go to workspace` or `←→↑↓ Focus window`.
  - Labels follow the window's state: *Float window* versus *Tile window*,
    *Exit full screen*, *Ungroup windows*.
  - The Super view also pins the next layer's answers to "how do I move this?":
    `Shift 1–0` Send window to workspace, `Shift ←→↑↓` Swap, and `Alt S` Hide
    window (Omarchy's minimize).
- **Footer: the next layer.** It shows what one more modifier unlocks, e.g.
  `+ Shift  apps · window  25`. Add that modifier and the card filters in place.
- **Right column (Super only): the focused app stack**, innermost first. For
  example, Ghostty › herdr › Claude Code.
  - Ghostty hints come from `ghostty +list-keybinds`.
  - herdr hints come from `~/.config/herdr/config.toml`.
  - The agent in the focused herdr pane comes from `herdr api snapshot`.
  - Other apps use the JSON packs in `packs/`.

Pressing an actual shortcut hides the card until Super is released, so quick
chords never flash it. Steam games (`steam_app_*`) never show it.

## How it works

| Piece | Role |
|---|---|
| `hypr/keyhints.lua` | Hyprland observer. Watches `input.keyboard.key` and reads modifier state; never binds or consumes keys. Sends `show`/`update`/`hide` to the shell over IPC, along with the window's class, title and state. Adds a blur layer rule. |
| `KeyHints.qml` | The overlay: a click-through, focus-free layer-shell surface on the active monitor, styled from Omarchy's theme tokens. |
| `HintModel.js` | Parses, groups and condenses bindings, rewords them by window state, and summarizes the next layers. |
| `bin/keyhints-context` | Detects the app stack in the focused window and prints its hints as JSON (Python, `-I`). |
| `packs/*.json` | Static hint packs. Add your own in `~/.config/keyhints/packs/`. |

The observer is loaded from `~/.config/hypr/hyprland.lua` by a guarded block:
it checks that the file exists and runs it under `pcall`.

The one-tick key-event deferral comes from
[NextKey](https://github.com/russellmorton/next-key) (MIT).

## Tuning

These settings are at the top of `KeyHints.qml`: `holdDelay` (300 ms),
`maxRows` (14) and `glassAlpha` (0.86). The shell hot-reloads the plugin on save.

## Adding an app pack

```json
{ "id": "obsidian", "name": "Obsidian",
  "match": { "class": "^obsidian$" },
  "hints": [ { "keys": "Ctrl P", "desc": "Command palette" } ] }
```

## Debug

```bash
omarchy-shell keyhints show SUPER eDP-1 com.mitchellh.ghostty "Orthrus: orthrus-manager" ""
omarchy-shell keyhints state
omarchy-shell keyhints hide
bin/keyhints-context com.mitchellh.ghostty "Orthrus: orthrus-manager" | jq .
```

## Remove

Delete the Key Hints block at the bottom of `~/.config/hypr/hyprland.lua`, then
run `omarchy plugin disable keyhints`.
