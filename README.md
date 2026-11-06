# Key Hints

Hold **Super** and, after a moment, the screen dims and the shortcuts you can
use right now appear in the top-right corner. Add Shift, Ctrl or Alt and the
hints switch to that layer. Let go and they're gone.

Key Hints is an [Omarchy](https://omarchy.org) 4 shell plugin. It reads your
real bindings, so custom shortcuts show up, and it follows your theme.

## What it shows

- **Omarchy shortcuts** for the modifiers you're holding.
  - Families are condensed: `1–0` Go to workspace, `←→↑↓` Focus window.
  - Labels follow the focused window: *Float* or *Tile window*, *Exit full
    screen*, *Ungroup windows*.
  - Holding Super alone also pins the answers to "how do I move this window?",
    even though they live one layer deeper: `Shift 1–0` Send window to
    workspace, `Shift ←→↑↓` Swap, and `Alt S` Hide window (Omarchy's minimize).
- **The next layer.** The footer shows what one more modifier unlocks, for
  example `+ Shift  apps · window  25`.
- **Hints for the focused app**, innermost first. A terminal running Claude
  Code inside herdr shows *Ghostty › herdr › Claude Code*, with each one's keys.
  - Ghostty's keys come from `ghostty +list-keybinds`, herdr's from its
    `config.toml`, and the agent in the focused herdr pane from `herdr api`.
  - Other apps use the JSON packs in `packs/` (browsers, Files, Codex).
- **Apps that suit what you're doing.** *Handy with Claude Code* offers Files
  in this folder, the capture menu, the clipboard, Browser and Editor. A
  browser gets Passwords, Email and Calendar.
- **Every launchable app** when no window is focused, since window commands
  don't apply then.
- **What you're still learning** (optional). Shortcuts you already use fade and
  sink; the three most useful ones you've never tried are highlighted. See
  [Learning](#learning).

The hints get out of the way. Pressing a shortcut, dragging a window with
Super held, or switching workspace hides them until you release Super, so
quick chords never flash them. They never appear over Steam games, and by
default not over full-screen windows either.

## Install

```bash
omarchy plugin add https://github.com/Lucasmind/omarchy-keyhints.git
~/.config/omarchy/plugins/keyhints/bin/keyhints-install
```

The installer:

- enables the plugin;
- puts the keyboard icon in the bar after the tray;
- adds a marked, guarded block to `~/.config/hypr/hyprland.lua`. The block
  checks the plugin file exists and loads it under `pcall`, so a missing or
  broken plugin can't stop Hyprland from starting;
- restarts the shell.

Every file it edits gets a timestamped `.bak.<time>` copy, and symlinked
dotfiles are edited at their target. If Hyprland reports config errors after
the change, the installer rolls back. It's safe to run again.

Requires Omarchy 4 with Hyprland 0.55 or newer and its Lua config, plus
`python3` and `xkbcli`, which are both in the Omarchy base install.

### Update

```bash
omarchy plugin update keyhints
~/.config/omarchy/plugins/keyhints/bin/keyhints-install   # restarts the shell to load the new version
```

### Uninstall

```bash
~/.config/omarchy/plugins/keyhints/bin/keyhints-install --uninstall   # add --purge to delete settings and usage
omarchy plugin remove keyhints
```

## Settings

Click the **keyboard icon** in the bar for settings; right-click it to switch
Key Hints on or off. The icon dims while it's off.

| Setting | Default | |
|---|---|---|
| On/off | on | |
| App hints | on | Focused-app hints, app suggestions and the empty-desktop launcher. Off leaves Omarchy shortcuts only. |
| Show over full-screen windows | off | Full screen means Super F, not maximized (Super Alt F). |
| Learn from my usage | on | See below. |
| Hold Super for | Normal | Quick 150 ms, Normal 300 ms, Relaxed 600 ms. |

Settings are saved to `~/.config/keyhints/settings.json`.

## Learning

With learning on, Key Hints counts the Super shortcuts you press. It records
only presses that match one of your Omarchy bindings, as a count and the date
last used per shortcut, in `~/.local/state/keyhints/usage.json`. It never
records other keys, typing, apps or times, and the data never leaves your
machine.

After 30 presses it starts adapting:

- A shortcut used **8 or more times** in the last 45 days counts as known.
  It's shown faded and is the first to go when space runs out, which leaves
  room for ones you don't know yet.
- The **three most useful shortcuts you've never tried** in the current view
  are shown in the accent color.
- The settings panel shows how many shortcuts you use, are learning and
  haven't tried. **Reset** clears the counts.

Key presses arrive from Hyprland as raw keycodes. `bin/keyhints-keymap`
converts them to key names for your configured layout (`input:kb_layout`),
so non-US layouts count correctly.

## Theming

Key Hints follows the active Omarchy theme and updates live on
`omarchy theme set`. Colors come from the shell's `Color` tokens. Fonts,
sizes, corner radius and keycap borders come from `Style`. Everything is
resolved in `components/KeyTheme.qml`:

| Role | Default |
|---|---|
| Dim layer | theme `background` at 88%, so light themes dim to light |
| Text | `menu.text` |
| Headings, modifier keys, "try this" | theme `accent` |
| Keycaps | the theme's `[controls]` normal state |

A theme can tune any role by shipping `shell.keyhints.toml`. You can override
one for every theme under `[keyhints]` in `~/.config/omarchy/shell.toml`:

```toml
[keyhints]
scrim-alpha = 0.92      # darker dim
scrim = "#000000"       # always black instead of the theme background
heading = "urgent"      # any palette role or hex color
key-border-width = 0    # flat keycaps
```

Roles: `scrim`, `scrim-alpha`, `text`, `muted-alpha`, `heading`, `key`,
`key-fill-alpha`, `key-border`, `key-border-alpha`, `key-border-width`.

## Adding an app pack

Drop a JSON file in `~/.config/keyhints/packs/`:

```json
{ "id": "obsidian", "name": "Obsidian",
  "match": { "class": "^obsidian$" },
  "hints": [ { "keys": "Ctrl P", "desc": "Command palette" } ] }
```

`match.class` and the optional `match.title` are regular expressions tested
against the focused window. App suggestions are the `SUGGESTIONS` rules at the
top of `HintModel.js`.

## How it works

| Piece | Role |
|---|---|
| `hypr/keyhints.lua` | Hyprland observer, loaded from `hyprland.lua`. Watches `input.keyboard.key`, the pointer (only while Super is held) and workspace changes. Never binds or consumes input. Talks to the shell over IPC. |
| `hypr/KeyhintsState.lua` | The observer's state machine, kept free of Hyprland calls for testing. |
| `KeyHints.qml` | The overlay: a full-screen, click-through, focus-free dim layer on the active monitor. Also owns settings and usage. |
| `HintModel.js` | Parses, groups and condenses bindings, rewords by window state, suggests apps, applies usage, summarizes the next layers. |
| `SettingsWidget.qml` | Bar icon and settings panel, built from the shell's own panel components. Not named `BarWidget.qml`, which clashes with the shell's `BarWidget` type ("File name case mismatch"). |
| `components/` | `KeyTheme` (colors), `HintSection`, `Keycap`. |
| `bin/keyhints-context` | Works out the app stack in the focused window and prints its hints as JSON. |
| `bin/keyhints-keymap` | Keycode → key name for the configured XKB layout. |
| `bin/keyhints-install` | Install / uninstall. |

The dim layer has an empty input region, so clicks, drags and scrolling go
straight through to your windows.

The one-tick key-event deferral comes from
[NextKey](https://github.com/russellmorton/next-key) (MIT).

## Development

```bash
tests/run          # model (node), state machine (lua), context script (python), lint, manifest
```

The plugin is `keepLoaded`, so saving a file does **not** hot-reload it. Run
`omarchy restart shell` after QML or JS edits, and `hyprctl reload` after Lua
edits.

```bash
omarchy-shell keyhints show SUPER eDP-1 com.mitchellh.ghostty "Host: workspace" ""
omarchy-shell keyhints state
omarchy-shell keyhints hide
omarchy-shell keyhints stats
bin/keyhints-context com.mitchellh.ghostty "Orthrus: orthrus-manager" | jq .
```

## License

MIT
