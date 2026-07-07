import Foundation
import Observation

/// Loads `~/.config/nexus/config.lua`, watches it for edits, and republishes
/// the decoded `Config`. Also the write-back target for the settings window.
///
/// The Lua file is the source of truth: the settings UI mutates `config` and
/// calls `save()`, which regenerates the file; external editor changes are
/// picked up by the file-system watcher and re-evaluated live.
@MainActor
@Observable
public final class ConfigStore {
    /// The current, live configuration.
    public private(set) var config: Config = Config()

    /// Non-nil when the last load failed to parse; surfaced as a banner.
    public private(set) var loadError: String?

    public let fileURL: URL

    @ObservationIgnored private var source: DispatchSourceFileSystemObject?
    @ObservationIgnored private var fileDescriptor: Int32 = -1
    /// Set while `save()` is writing so the watcher ignores our own edit.
    @ObservationIgnored private var isSavingSelf = false

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        bootstrap()
        load()
        startWatching()
    }

    deinit {
        source?.cancel()
        if fileDescriptor >= 0 { close(fileDescriptor) }
    }

    public static func defaultURL() -> URL {
        configDirectory().appendingPathComponent("config.lua")
    }

    private static func configDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("nexus", isDirectory: true)
    }

    /// Ensure the directory and a default file exist on first run. Migrates a
    /// pre-existing `config.json` (from the old format) into `config.lua`.
    private func bootstrap() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let legacyJSON = dir.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: legacyJSON),
           let migrated = try? JSONDecoder().decode(Config.self, from: data) {
            writeToDisk(migrated)
        } else {
            writeToDisk(Config())
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Missing file → fall back to defaults, no error banner.
            config = Config()
            loadError = nil
            return
        }
        do {
            config = try LuaConfig.load(path: fileURL.path)
            loadError = nil
        } catch {
            // Keep the last good config; surface why the new one was rejected.
            let message = (error as? LuaConfig.LoadError)?.message ?? "\(error)"
            loadError = "config.lua: \(message)"
        }
    }

    /// Persist the given config (or the current one) to disk.
    public func save(_ newConfig: Config? = nil) {
        if let newConfig { config = newConfig }
        isSavingSelf = true
        writeToDisk(config)
        loadError = nil
        // Reset the guard shortly after; the fs event arrives asynchronously.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isSavingSelf = false
        }
    }

    /// Toggle transparency mode. When enabling, drop to a translucent opacity
    /// (restoring full opacity when disabling).
    public func setTransparency(enabled: Bool) {
        var updated = config
        updated.window.opacity = enabled ? 0.82 : 1.0
        save(updated)
    }

    public func setBlur(_ blur: Bool) {
        var updated = config
        updated.window.blur = blur
        save(updated)
    }

    /// Persist the git sidebar width (called once when a resize drag ends).
    public func setSidebarWidth(_ width: Double) {
        var updated = config
        updated.sidebarWidth = min(max(width, 240), 680)
        save(updated)
    }

    /// Nudge the window opacity, clamped to a usable range.
    public func adjustOpacity(by delta: Double) {
        var updated = config
        updated.window.opacity = min(max(config.window.opacity + delta, 0.1), 1.0)
        save(updated)
    }

    private func writeToDisk(_ config: Config) {
        let text = LuaConfig.serialize(config)
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - File watching

    private func startWatching() {
        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.source?.data ?? []
            // Editors often replace the file (rename/delete); re-open to keep watching.
            if flags.contains(.rename) || flags.contains(.delete) {
                self.restartWatching()
            }
            if self.isSavingSelf { return }
            self.load()
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }
            self?.fileDescriptor = -1
        }
        source = src
        src.resume()
    }

    private func restartWatching() {
        source?.cancel()
        source = nil
        // The old fd is closed by the cancel handler; re-arm on the next tick.
        DispatchQueue.main.async { [weak self] in
            self?.startWatching()
        }
    }
}
