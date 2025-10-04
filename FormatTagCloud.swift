import SwiftUI

// A chip-style button used in the tag cloud
private struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(selected ? Color.accentColor : Color.white.opacity(0.25), lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// A wrapping grid of chips for selecting/deselecting PluginFormat values.
struct FormatTagCloud: View {
    let formats: [PluginFormat]
    @Binding var selection: Set<PluginFormat>

    // Adaptive columns so chips wrap within the sidebar width
    private var grid: [GridItem] {
        [GridItem(.adaptive(minimum: 70, maximum: 120), spacing: 8, alignment: .leading)]
    }

    var body: some View {
        LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
            ForEach(formats, id: \.self) { format in
                Chip(title: format.rawValue, selected: selection.contains(format)) {
                    if selection.contains(format) {
                        selection.remove(format)
                    } else {
                        selection.insert(format)
                    }
                }
                .contextMenu {
                    if selection.contains(format) {
                        Button("Deselect \(format.rawValue)") { selection.remove(format) }
                    } else {
                        Button("Select \(format.rawValue)") { selection.insert(format) }
                    }
                }
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var sel: Set<PluginFormat> = [.AU, .VST]
        var body: some View {
            VStack(alignment: .leading) {
                Text("Formats").font(.headline)
                FormatTagCloud(formats: PluginFormat.allCases, selection: $sel)
            }
            .padding()
            .frame(width: 280)
            .background(Color(red: 30/255, green: 30/255, blue: 30/255))
        }
    }
    return Demo()
}
