import SwiftUI
import AppKit

@main
struct NexusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var configStore = ConfigStore()
    @State private var workspace = Workspace()
    @State private var gitStore = GitStore()
    @State private var agentStore = AgentStore()
    @State private var claudeStore = ClaudeCodeStore()
    @State private var uiState = AppUIState()

    var body: some Scene {
        WindowGroup("Nexus") {
            RootView(workspace: workspace, configStore: configStore, gitStore: gitStore, agentStore: agentStore, claudeStore: claudeStore, uiState: uiState)
                .onAppear {
                    // Closing the last pane closes the whole terminal.
                    workspace.onEmpty = {
                        NSApp.windows.forEach { $0.close() }
                        NSApp.terminate(nil)
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { workspace.newTab() }
                    .keyboardShortcut(shortcut("newTab", default: KeyboardShortcut("t", modifiers: .command)))
            }

            CommandMenu("Pane") {
                Button("Split Right") { workspace.splitFocused(.horizontal) }
                    .keyboardShortcut(shortcut("splitHorizontal", default: KeyboardShortcut("d", modifiers: .command)))
                Button("Split Down") { workspace.splitFocused(.vertical) }
                    .keyboardShortcut(shortcut("splitVertical", default: KeyboardShortcut("d", modifiers: [.command, .shift])))
                Divider()
                Button("Close Pane") { workspace.closeFocused() }
                    .keyboardShortcut(shortcut("closePane", default: KeyboardShortcut("w", modifiers: .command)))
                Divider()
                tabSwitchButtons
            }

            CommandMenu("View") {
                Button(uiState.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    uiState.toggleSidebar()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button(configStore.config.window.opacity < 1 ? "Disable Transparency" : "Enable Transparency") {
                    configStore.setTransparency(enabled: configStore.config.window.opacity >= 1)
                }
                .keyboardShortcut("t", modifiers: [.command, .option])

                Button(configStore.config.window.blur ? "Disable Blur" : "Enable Blur") {
                    configStore.setBlur(!configStore.config.window.blur)
                }
                .keyboardShortcut("b", modifiers: [.command, .option])

                Button("Increase Opacity") { configStore.adjustOpacity(by: 0.05) }
                    .keyboardShortcut("=", modifiers: [.command, .option])
                Button("Decrease Opacity") { configStore.adjustOpacity(by: -0.05) }
                    .keyboardShortcut("-", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView(configStore: configStore)
        }
    }

    private var tabSwitchButtons: some View {
        ForEach(1...9, id: \.self) { n in
            Button("Select Tab \(n)") { workspace.selectTab(index: n - 1) }
                .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
        }
    }

    /// Resolve a keybinding from config, falling back to a built-in default.
    private func shortcut(_ action: String, default fallback: KeyboardShortcut) -> KeyboardShortcut {
        if let raw = configStore.config.keybindings[action], let parsed = ShortcutParser.parse(raw) {
            return parsed
        }
        return fallback
    }
}

/// Ensures the app launches as a regular foreground app (important when run via
/// `swift run`, which otherwise starts as a background/accessory process).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Let our own ⌘W ("Close Pane") own the shortcut: strip ⌘W from the
        // built-in "Close Window" item so the two don't compete. Deferred until
        // after SwiftUI installs its menus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Self.disableSystemCloseShortcut()
        }
    }

    private static func disableSystemCloseShortcut() {
        let performClose = #selector(NSWindow.performClose(_:))
        guard let mainMenu = NSApp.mainMenu else { return }
        for topItem in mainMenu.items {
            guard let submenu = topItem.submenu else { continue }
            for item in submenu.items where item.action == performClose {
                item.keyEquivalent = ""
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
