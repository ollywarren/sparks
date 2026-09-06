# Sparks

An [Omarchy](https://omarchy.org/) shell plugin for quick-capturing ideas. A
bar icon lists everything you've logged, filterable by tag; a keybinding pops
a small floating window anywhere, any time, to type or dictate a new one.

Ideas are saved as plain Markdown files — nothing proprietary, no database —
so the folder is trivial to point a script, a sync tool, or an AI agent at.

## How it works

- **Bar icon** — click to see your ideas, newest first. Click a tag chip to
  filter, click an idea to open its file, click 󰆴 to delete one.
- **Capture window** — trigger it with a keybinding (see [Install](#install)).
  Type or dictate, drop `#tags` anywhere in the text, then either press
  `Ctrl+Enter`, press `Esc`, or click outside the window. All three save the
  idea if you typed anything; closing an empty window just closes it.

## Ideas as files

Each idea is one file in `~/Notes/ideas/` (configurable), named
`YYYY-MM-DD-HHMMSS-<slug-of-first-line>.md`:

```markdown
---
created: 2026-09-06T14:32:00+01:00
tags: sparks, ideas
---

Add a plugin marketplace page. #sparks #ideas
```

Hashtags in the text are lifted into the `tags:` line on save and left in the
body too, so the file still reads naturally on its own — open it directly,
`grep` the folder, or hand the whole directory to an agent.

## Requirements

- **Omarchy 4.x**, which ships the Quickshell-based `omarchy-shell`.
- **`jq`** — used by the backing script to build/parse JSON. Already a base
  Omarchy dependency (the same script pattern `omarchy-reminder` uses).
- **`xdg-open`** — opens an idea file or the ideas folder from the bar list.

No network access, no elevated privileges. Dictation, if you use it, is
Omarchy's own built-in dictation toggle (`omarchy-voxtype`) — it types into
whatever has focus, so the capture window needs no special integration.

## Install

```bash
omarchy plugin add https://github.com/ollywarren/sparks.git --enable --yes
omarchy restart shell
```

Or by hand:

```bash
git clone https://github.com/ollywarren/sparks.git \
  ~/.config/omarchy/plugins/ollywarren.sparks
omarchy-shell shell rescanPlugins
omarchy plugin enable ollywarren.sparks right
```

Then bind a key to pop the capture window, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + N", "New idea", "omarchy-shell shell toggle ollywarren.sparks")
```

If you change the `ideasDir` setting (below) from its default, pass the same
folder in the keybinding's payload so the capture window writes to the same
place the bar widget reads from:

```lua
o.bind("SUPER + ALT + N", "New idea",
  [[omarchy-shell shell toggle ollywarren.sparks '{"ideasDir":"~/Documents/ideas"}']])
```

## Removal

```bash
omarchy plugin remove ollywarren.sparks
```

This asks for confirmation, takes the widget out of your bar, and deletes the
plugin directory. Your idea files in `~/Notes/ideas/` are deliberately left
behind — they're your notes, not plugin state. Delete them yourself if you
don't want them:

```bash
rm -rf ~/Notes/ideas
```

## IPC

```bash
omarchy-shell ollywarren.sparks toggle              # open / close the bar list
omarchy-shell shell toggle ollywarren.sparks '{}'   # open / close the capture window
```

The bar list and the capture window are two independent entry points of the
same plugin (`bar-widget` and `overlay` kinds), so each is toggled separately.

## What it writes

- `.md` files under your configured ideas folder (default `~/Notes/ideas/`),
  one per idea, only when you save one from the capture window.
- Nothing else. No shell.json edits beyond what `omarchy plugin enable` /
  `disable` already does for the bar entry, no state file, no network calls.
  The only processes it runs are `bash` (its own backing script,
  `bin/sparks`), `xdg-open`, and `omarchy-notification-send` to confirm a
  save — all of which ship with Omarchy or your desktop.

## Settings

Settings live inline on the bar layout entry in `~/.config/omarchy/shell.json`,
which hot-reloads on save:

```json
{ "id": "ollywarren.sparks", "ideasDir": "~/Documents/ideas", "maxListItems": 60 }
```

| Key | Default | What |
|---|---|---|
| `icon` | `✨` | Bar glyph |
| `ideasDir` | `~/Notes/ideas` | Folder ideas are saved to and listed from |
| `panelWidth` | `380` | Popup width in px |
| `maxListItems` | `40` | Most ideas shown in the popup at once |

Or from the shell: `omarchy bar set ollywarren.sparks maxListItems 60`.

The capture window (an `overlay`, not a bar widget) doesn't read this
settings block — it takes `ideasDir` from its own IPC payload instead. See
[Install](#install) for wiring a custom folder into the keybinding.

## Development

`bin/sparks` is a small, dependency-light bash script that owns all file I/O
(`list`, `new`, `remove`) so the QML stays UI-only. Test it directly:

```bash
./bin/sparks list ~/Notes/ideas
./bin/sparks new ~/Notes/ideas "A test idea #testing"
```

Saving a file under `~/.config/omarchy/plugins/` normally hot-reloads it. If a
change to `Panel.qml` or `Capture.qml` doesn't appear, `omarchy restart
shell`. Check the manifest with `omarchy plugin validate <dir>`, and watch for
QML errors with `journalctl --user -f | grep omarchy-shell`.

| File | What |
|---|---|
| `manifest.json` | Plugin declaration and settings schema |
| `Panel.qml` | Bar icon + idea list popup |
| `Capture.qml` | Floating quick-capture window |
| `bin/sparks` | File I/O: list / new / remove |

## Licence

MIT — see [LICENSE](LICENSE).
