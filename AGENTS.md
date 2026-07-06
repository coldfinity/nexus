# AGENTS.md

Guidance for AI coding agents working in this repository. Read this before making changes.

## What Nexus is

Nexus is a native **macOS terminal emulator** built in SwiftUI, aimed at developers running AI coding agents. It wraps a real shell (via SwiftTerm) and adds a tiling pane layout, a Git sidebar, Lua-based configuration, and a theme-driven UI.

- **Platform:** macOS 14+ only.
- **Language:** Swift 5 language mode (see `Package.swift`) — chosen so AppKit delegate bridging with SwiftTerm doesn't fight strict Swift 6 concurrency.

## Build, test, run

```bash
swift build                 # compile
swift test                  # run the test suite (42 tests)
./scripts/build-app.sh      # build + package Nexus.app (release by default)
open Nexus.app              # launch
```

**Run via the app bundle, not `swift run`.** A bare SwiftPM executable has no `Info.plist`; in that mode SF Symbols fail to render and the Dock/window behavior is wrong. Always `./scripts/build-app.sh && open Nexus.app`.

Do **not** launch the GUI to "verify" unless asked — prefer `swift test`. To sanity-check UI rendering without a window, render a view off-screen with SwiftUI's `ImageRenderer` to a PNG and inspect it.

## Layout

```
Sources/Nexus/
  App/        NexusApp (scene + menus), AppDelegate, Workspace (tabs/panes), AppUIState
  Config/     Config model, ConfigStore (load/watch/save), LuaConfig (codec), Themes
  Git/        GitProcess (subprocess), GitStore (observable), GitGraph (lane algorithm),
              models, WorkingDirectory (libproc cwd resolver)
  Layout/     LayoutNode (split tree), TileLayout (pure frame calculator)
  Terminal/   Pane, TerminalController (owns the SwiftTerm view), TerminalPaneView
              (SwiftUI host), SessionLauncher, ThemeColors
  UI/         RootView, TabBarView, LayoutTreeView, PaneContainerView, GitSidebarView,
              CommitGraphView, CommitDetailView, SettingsView, DesignSystem, WindowConfigurator
Tests/NexusTests/
Vendor/SwiftTerm/   patched fork (see below)
Vendor/Lua/         Lua 5.4.7 C runtime, built as the CLua target
scripts/build-app.sh
```

## Conventions & gotchas

- **Vendored SwiftTerm fork** (`Vendor/SwiftTerm`, from v1.13.0). Patched to add a public `lineHeightMultiplier`. Find edits with `grep -rn "[Nexus patch]" Vendor/SwiftTerm`. Bumping SwiftTerm means re-cloning and re-applying the patch.
- **Vendored Lua** (`Vendor/Lua`, 5.4.7) is built as the `CLua` SPM target. Its C-API macros aren't importable into Swift, so `Vendor/Lua/include/lua_shims.h` wraps the ones we use (`nx_pcall`, `nx_loadfile`, `nx_tostring`, `nx_tonumber`, `nx_pop`, `nx_dostring`). The module map is in `Vendor/Lua/include/`.
- **Icons:** use the `Icon` view (in `UI/DesignSystem.swift`), which resolves symbols through AppKit and rasterizes them. Do **not** use `Image(systemName:)` directly — it renders as "?" placeholders in this app, and multi-layer symbols fail without flattening.
- **Chrome colors come from the theme.** All chrome color values live on `Palette` (derived from the active terminal theme in `UI/DesignSystem.swift`) and are passed via the `\.palette` SwiftUI environment. `NX` holds only geometry/fonts. Never hardcode chrome colors — read them from `palette`.
- **Layout is flat, not nested.** Panes are positioned by `computeTileLayout` (pure, tested) and rendered as flat siblings keyed by pane UUID. This deliberately avoids a nested SwiftUI split hierarchy, which caused terminal views (and shells) to be torn down/duplicated on split/close.
- **Terminal transparency** works by writing the background alpha to the SwiftTerm layer's `backgroundColor` in `TerminalController.apply` — SwiftTerm only sets it at init, so changing `nativeBackgroundColor` alone isn't enough.
- **Shell cwd** is read from the shell process via `libproc` (`Git/WorkingDirectory.swift`), not OSC 7, since a custom terminal can't rely on the shell emitting it.

## Configuration

User config is **Lua** at `~/.config/nexus/config.lua` (WezTerm-style builder: `local config = nexus.config()` then flat `config.font_size = 13`, `return config`). It is the source of truth and is hot-reloaded, but the Settings window regenerates it on save. The codec is `Config/LuaConfig.swift`; it accepts both the current flat keys and an older nested `return { font = {...} }` format. `ConfigStore` migrates a legacy `config.json` on first run.

## When you change things

- Add or update tests in `Tests/NexusTests/` for pure logic (layout, graph, config codec). Prefer testing pure functions over UI.
- Keep comments matching the surrounding density and style.
- Run `swift test` and `./scripts/build-app.sh` before claiming completion.
