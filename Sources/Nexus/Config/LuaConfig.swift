import Foundation
import CLua

/// Reads and writes the Lua configuration file.
///
/// The config is a Lua script that builds and returns a config object,
/// WezTerm-style:
/// ```lua
/// local config = nexus.config()
/// config.font_family = "SF Mono"
/// config.font_size = 13
/// config.opacity = 0.82
/// return config
/// ```
/// `nexus.config()` (a global injected before the script runs) just returns a
/// fresh table; fields are flat, snake_case keys. Decoding executes the script
/// and reads the returned table; encoding regenerates the file from a `Config`.
enum LuaConfig {
    struct LoadError: Error {
        let message: String
    }

    /// Injected before the user's config runs: provides the `nexus` global and
    /// makes `require 'nexus'` work too.
    private static let preamble = """
    local M = {}
    function M.config() return {} end
    nexus = M
    package.preload['nexus'] = function() return M end
    """

    // MARK: - Decode

    /// Execute `path` and map the returned table onto a `Config`. Every field
    /// falls back to its default, so a partial config is valid.
    static func load(path: String) throws -> Config {
        guard let L = luaL_newstate() else {
            throw LoadError(message: "could not create Lua state")
        }
        defer { lua_close(L) }
        luaL_openlibs(L)

        if nx_dostring(L, preamble) != LUA_OK {
            throw LoadError(message: errorMessage(L))
        }
        if nx_loadfile(L, path) != LUA_OK {
            throw LoadError(message: errorMessage(L))
        }
        if nx_pcall(L, 0, 1) != LUA_OK {
            throw LoadError(message: errorMessage(L))
        }
        guard lua_type(L, -1) == LUA_TTABLE else {
            throw LoadError(message: "config must return the config object")
        }

        // Flat, snake_case keys (current format). Nested sub-tables are accepted
        // as a fallback so older `return { font = {...} }` files still load.
        var config = Config()

        // Colors: `theme = "Tokyo Night"` selects a built-in palette; explicit
        // color keys (or a nested `theme = {...}` table) override on top.
        if let name = themeName(L), let preset = BuiltInThemes.named(name) {
            config.theme = preset.theme
        }
        config.theme.foreground = string(L, "foreground") ?? sub(L, "theme") { string(L, "foreground") } ?? config.theme.foreground
        config.theme.background = string(L, "background") ?? sub(L, "theme") { string(L, "background") } ?? config.theme.background
        config.theme.cursor = string(L, "cursor") ?? sub(L, "theme") { string(L, "cursor") } ?? config.theme.cursor
        if let ansi = stringArray(L, "ansi") ?? sub(L, "theme", { stringArray(L, "ansi") }), ansi.count == 16 {
            config.theme.ansi = ansi
        }

        config.font.family = string(L, "font_family") ?? sub(L, "font") { string(L, "family") } ?? config.font.family
        config.font.size = number(L, "font_size") ?? sub(L, "font") { number(L, "size") } ?? config.font.size
        config.font.weight = string(L, "font_weight") ?? sub(L, "font") { string(L, "weight") } ?? config.font.weight
        let lh = number(L, "line_height") ?? sub(L, "font") { number(L, "lineHeight") }
        config.font.lineHeight = clamp(lh, 0.8, 2.0) ?? config.font.lineHeight

        let opacity = number(L, "opacity") ?? sub(L, "window") { number(L, "opacity") }
        config.window.opacity = clamp(opacity, 0.1, 1.0) ?? config.window.opacity
        config.window.blur = bool(L, "blur") ?? sub(L, "window") { bool(L, "blur") } ?? config.window.blur
        config.window.transparentTerminal = bool(L, "transparent_terminal")
            ?? sub(L, "window") { bool(L, "transparentTerminal") } ?? config.window.transparentTerminal

        config.sidebarWidth = clamp(number(L, "sidebar_width"), 240, 680) ?? config.sidebarWidth
        config.padding = clamp(number(L, "padding"), 0, 40) ?? config.padding

        // Keybindings merge onto the defaults: only specified actions override.
        if let bindings = stringMap(L, "keybindings") {
            for (action, shortcut) in bindings { config.keybindings[action] = shortcut }
        }

        return config
    }

    /// The value of `theme` only when it's a string (a preset name).
    private static func themeName(_ L: OpaquePointer) -> String? {
        lua_getfield(L, -1, "theme")
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TSTRING, let c = nx_tostring(L, -1) else { return nil }
        return String(cString: c)
    }

    /// Push `table[name]`; if it's a table run `read` (which reads from the now
    /// top-of-stack sub-table), then pop. Used for nested-format fallback.
    private static func sub<T>(_ L: OpaquePointer, _ name: String, _ read: () -> T?) -> T? {
        lua_getfield(L, -1, name)
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TTABLE else { return nil }
        return read()
    }

    private static func errorMessage(_ L: OpaquePointer) -> String {
        guard let c = nx_tostring(L, -1) else { return "unknown Lua error" }
        return String(cString: c)
    }

    // MARK: - Stack readers (config table assumed at index -1)

    private static func string(_ L: OpaquePointer, _ key: String) -> String? {
        lua_getfield(L, -1, key)
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TSTRING, let c = nx_tostring(L, -1) else { return nil }
        return String(cString: c)
    }

    private static func number(_ L: OpaquePointer, _ key: String) -> Double? {
        lua_getfield(L, -1, key)
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TNUMBER else { return nil }
        return nx_tonumber(L, -1)
    }

    private static func bool(_ L: OpaquePointer, _ key: String) -> Bool? {
        lua_getfield(L, -1, key)
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TBOOLEAN else { return nil }
        return lua_toboolean(L, -1) != 0
    }

    private static func stringArray(_ L: OpaquePointer, _ key: String) -> [String]? {
        lua_getfield(L, -1, key)
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TTABLE else { return nil }
        var result: [String] = []
        let count = luaL_len(L, -1)
        guard count > 0 else { return [] }
        for i in 1...count {
            lua_geti(L, -1, i)
            if lua_type(L, -1) == LUA_TSTRING, let c = nx_tostring(L, -1) {
                result.append(String(cString: c))
            }
            nx_pop(L, 1)
        }
        return result
    }

    private static func stringMap(_ L: OpaquePointer, _ key: String) -> [String: String]? {
        lua_getfield(L, -1, key)
        defer { nx_pop(L, 1) }
        guard lua_type(L, -1) == LUA_TTABLE else { return nil }
        var result: [String: String] = [:]
        lua_pushnil(L)
        while lua_next(L, -2) != 0 {
            // key at -2, value at -1. Only read string keys/values (reading a
            // non-string key with tostring would corrupt lua_next).
            if lua_type(L, -2) == LUA_TSTRING, lua_type(L, -1) == LUA_TSTRING,
               let k = nx_tostring(L, -2), let v = nx_tostring(L, -1) {
                result[String(cString: k)] = String(cString: v)
            }
            nx_pop(L, 1)
        }
        return result
    }

    private static func clamp(_ value: Double?, _ lo: Double, _ hi: Double) -> Double? {
        value.map { min(max($0, lo), hi) }
    }

    // MARK: - Encode

    /// Regenerate the Lua config file text from a `Config`, WezTerm-style.
    static func serialize(_ config: Config) -> String {
        var lines: [String] = []
        lines.append("-- Nexus configuration")
        lines.append("-- Managed by Nexus: edits from the Settings window overwrite this file.")
        lines.append("-- You can hand-edit it too — it's real Lua (comments, variables, logic).")
        lines.append("")
        lines.append("local config = nexus.config()")
        lines.append("")

        lines.append("-- Font")
        lines.append("config.font_family = \(quote(config.font.family))")
        lines.append("config.font_size = \(num(config.font.size))")
        lines.append("config.font_weight = \(quote(config.font.weight))")
        lines.append("config.line_height = \(num(config.font.lineHeight))")
        lines.append("")

        lines.append("-- Window")
        lines.append("config.opacity = \(num(config.window.opacity))")
        lines.append("config.blur = \(config.window.blur)")
        lines.append("config.transparent_terminal = \(config.window.transparentTerminal)")
        lines.append("config.sidebar_width = \(num(config.sidebarWidth))")
        lines.append("config.padding = \(num(config.padding))")
        lines.append("")

        // A built-in theme is referenced by name; a custom palette is written out.
        if let named = BuiltInThemes.match(config.theme) {
            lines.append("-- Colors — available themes: \(BuiltInThemes.all.map { $0.name }.joined(separator: ", "))")
            lines.append("config.theme = \(quote(named.name))")
        } else {
            lines.append("-- Colors (custom palette)")
            lines.append("config.foreground = \(quote(config.theme.foreground))")
            lines.append("config.background = \(quote(config.theme.background))")
            lines.append("config.cursor = \(quote(config.theme.cursor))")
            lines.append("config.ansi = {")
            for row in stride(from: 0, to: config.theme.ansi.count, by: 4) {
                let chunk = config.theme.ansi[row..<min(row + 4, config.theme.ansi.count)]
                lines.append("  " + chunk.map(quote).joined(separator: ", ") + ",")
            }
            lines.append("}")
        }
        lines.append("")

        // Only overrides are written; unspecified actions keep their defaults.
        let overrides = config.keybindings
            .filter { $0.value != Config.defaultKeybindings[$0.key] }
            .sorted { $0.key < $1.key }
        if overrides.isEmpty {
            lines.append("-- Keybindings: using defaults. Override individual actions, e.g.")
            lines.append("-- config.keybindings = { newTab = \"cmd+shift+t\" }")
        } else {
            lines.append("-- Keybindings (overrides only; others use defaults)")
            lines.append("config.keybindings = {")
            for (action, shortcut) in overrides {
                lines.append("  \(action) = \(quote(shortcut)),")
            }
            lines.append("}")
        }
        lines.append("")

        lines.append("return config")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func quote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func num(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
