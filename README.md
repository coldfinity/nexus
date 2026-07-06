# Nexus

A native macOS terminal, built in SwiftUI, with a tiling layout, a Git sidebar, and a Lua config. It runs a real shell through [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) and themes the entire UI from whatever colors your terminal uses.

> Requires macOS 14+.

## Features

- **Tiling panes & tabs** — split any pane horizontally (⌘D) or vertically (⌘⇧D), nest arbitrarily, drag dividers to resize. Tabs with ⌘T; ⌘1–9 to switch.
- **Git sidebar** — a live commit graph, branch list (click to check out), and a worktree manager (add / remove / open in a new tab). Click a commit for its full message, changed files, and diff. Toggle with ⌘⇧G; drag its edge to resize.
- **Themes** — 10 built in (One Dark, Dracula, Solarized Dark/Light, Nord, Gruvbox Dark, Tokyo Night, Rosé Pine, Black Metal (Venom), Monokai) or bring your own. The tab bar, sidebar, and accents all recolor to match — light or dark.
- **Lua configuration** — a WezTerm-style `config.lua` with comments, variables, and logic. Hot-reloaded on save.
- **Transparency & blur** — per-window opacity with an optional vibrancy backdrop; choose whether it applies to just the sidebar or the terminal too.
- **Tunable type & spacing** — font family, size, line height, and terminal padding, all editable in Settings or the config file.

## Building

```bash
git clone <this-repo> nexus && cd nexus
./scripts/build-app.sh        # builds Nexus.app in the project root
open Nexus.app
```

The vendored SwiftTerm and Lua sources are included, so no extra dependencies are needed. For development, `swift build` and `swift test` work as usual — but run the app through `Nexus.app` (a bare `swift run` can't render SF Symbols correctly).

## Configuration

Settings live in `~/.config/nexus/config.lua`, created on first launch. It's the source of truth and reloads the moment you save:

```lua
local config = nexus.config()

-- Font
config.font_family = "SF Mono"
config.font_size = 13
config.line_height = 1.2

-- Window
config.opacity = 0.85
config.blur = true
config.transparent_terminal = true
config.sidebar_width = 340
config.padding = 8

-- Colors — a built-in theme by name...
config.theme = "Tokyo Night"
-- ...or a custom palette:
-- config.background = "#1a1b26"
-- config.foreground = "#c0caf5"
-- config.ansi = { "#15161e", "#f7768e", ... }  -- 16 colors

-- Keybindings: defaults apply unless overridden
-- config.keybindings = { newTab = "cmd+shift+t" }

return config
```

You can also edit everything from the **Settings** window (⌘,) — it writes back to the same file. Because it's real Lua, `local x = 12; config.font_size = x + 2` works.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New tab | ⌘T |
| Close pane (or window if last) | ⌘W |
| Split right | ⌘D |
| Split down | ⌘⇧D |
| Switch to tab N | ⌘1–9 |
| Toggle Git sidebar | ⌘⇧G |
| Toggle transparency | ⌥⌘T |
| Toggle blur | ⌥⌘B |
| Increase / decrease opacity | ⌥⌘= / ⌥⌘- |
| Settings | ⌘, |

Split, close, and new-tab bindings are configurable in `config.keybindings`.

## Development

See [AGENTS.md](AGENTS.md) for the architecture, conventions, and the vendored-dependency notes.
