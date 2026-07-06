import SwiftUI
import AppKit

extension Color {
    init(hexString: String) {
        if let (r, g, b) = HexColor.rgb(hexString) {
            self = Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        } else {
            self = .black
        }
    }

    /// `#rrggbb` in the sRGB space.
    var hexString: String {
        let ns = (NSColor(self).usingColorSpace(.sRGB)) ?? .black
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

/// Native preferences window. Edits a working copy of `Config` and writes it
/// back to disk (the source of truth) on every change.
struct SettingsView: View {
    let configStore: ConfigStore

    @State private var draft: Config

    init(configStore: ConfigStore) {
        self.configStore = configStore
        _draft = State(initialValue: configStore.config)
    }

    var body: some View {
        Form {
            Section("Theme") {
                ThemePicker(selected: BuiltInThemes.match(draft.theme)) { named in
                    draft.theme = named.theme
                    configStore.save(draft)
                }
            }

            Section("Font") {
                TextField("Family", text: binding(\.font.family))
                sliderField("Size", value: binding(\.font.size), in: 8...28, step: 1, fractionDigits: 0)
                sliderField("Line height", value: binding(\.font.lineHeight), in: 0.8...2.0, step: 0.05, fractionDigits: 2)
            }

            Section("Window") {
                sliderField("Padding", value: binding(\.padding), in: 0...40, step: 1, fractionDigits: 0)
                sliderField("Opacity", value: binding(\.window.opacity), in: 0.3...1.0, step: 0.01, fractionDigits: 0, displayScale: 100, suffix: "%")
                Picker("Applies to", selection: binding(\.window.transparentTerminal)) {
                    Text("Sidebar only").tag(false)
                    Text("Sidebar & terminal").tag(true)
                }
                Toggle("Blur background", isOn: binding(\.window.blur))
            }

            Section("Colors") {
                ColorPicker("Foreground", selection: colorBinding(\.theme.foreground))
                ColorPicker("Background", selection: colorBinding(\.theme.background))
                ColorPicker("Cursor", selection: colorBinding(\.theme.cursor))
                Text("The 16 ANSI colors and keybindings can be edited in\n\(configStore.fileURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                HStack {
                    Button("Reveal config file") {
                        NSWorkspace.shared.activateFileViewerSelecting([configStore.fileURL])
                    }
                    Spacer()
                    Button("Reset to defaults") {
                        draft = Config()
                        configStore.save(draft)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .onChange(of: configStore.config) { _, newValue in
            // Pick up external edits while the window is open.
            draft = newValue
        }
    }

    /// A labeled row with a slider and an editable numeric field kept in sync.
    /// `displayScale` lets the field show scaled units (e.g. opacity 0.82 → 82).
    @ViewBuilder
    private func sliderField(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        fractionDigits: Int,
        displayScale: Double = 1,
        suffix: String = ""
    ) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range, step: step)
            TextField("", value: displayBinding(value, in: range, scale: displayScale),
                      format: .number.precision(.fractionLength(fractionDigits)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
            if !suffix.isEmpty {
                Text(suffix).foregroundStyle(.secondary)
            }
        }
    }

    /// A scaled, clamped view over a `Double` binding for the typed field.
    private func displayBinding(_ value: Binding<Double>, in range: ClosedRange<Double>, scale: Double) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue * scale },
            set: { value.wrappedValue = min(max($0 / scale, range.lowerBound), range.upperBound) }
        )
    }

    /// A binding into `draft` that persists on write.
    private func binding<T: Equatable>(_ keyPath: WritableKeyPath<Config, T>) -> Binding<T> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: {
                draft[keyPath: keyPath] = $0
                configStore.save(draft)
            }
        )
    }

    /// A `Color` binding backed by a hex-string field in `draft`.
    private func colorBinding(_ keyPath: WritableKeyPath<Config, String>) -> Binding<Color> {
        Binding(
            get: { Color(hexString: draft[keyPath: keyPath]) },
            set: {
                draft[keyPath: keyPath] = $0.hexString
                configStore.save(draft)
            }
        )
    }
}

/// A grid of preset theme swatches. Selecting one applies its palette.
private struct ThemePicker: View {
    let selected: NamedTheme?
    let onSelect: (NamedTheme) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(BuiltInThemes.all) { named in
                ThemeSwatch(named: named, isSelected: named == selected)
                    .onTapGesture { onSelect(named) }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeSwatch: View {
    let named: NamedTheme
    let isSelected: Bool

    /// ANSI indices to preview: red, green, yellow, blue, magenta, cyan.
    private let previewIndices = [1, 2, 3, 4, 5, 6]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(named.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hexString: named.theme.foreground))
                .lineLimit(1)
            HStack(spacing: 3) {
                ForEach(previewIndices, id: \.self) { i in
                    Circle()
                        .fill(Color(hexString: named.theme.ansi[i]))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hexString: named.theme.background))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Palette.from(theme: named.theme).accent : Color.primary.opacity(0.12),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
