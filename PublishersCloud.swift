import SwiftUI

/// A centered two-column cloud of publisher chips with 4pt spacing.
struct PublishersCloud: View {
    let publishers: [String]
    @Binding var selection: Set<String>

    private enum ChipItem: Identifiable { case publisher(String)
        var id: String { switch self { case .publisher(let s): return s } }
    }

    var body: some View {
        let items: [ChipItem] = publishers.map { .publisher($0) }
        let left  = items.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
        let right = items.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }

        return HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(left) { item in chip(for: item) }
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(right) { item in chip(for: item) }
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder private func chip(for item: ChipItem) -> some View {
        switch item {
        case .publisher(let name):
            ChipView(title: name, selected: selection.contains(name)) {
                if selection.contains(name) { selection.remove(name) }
                else { selection.insert(name) }
            }
        }
    }
}

// Capsule-styled chip used by PublishersCloud.
private struct ChipView: View {
    let title: String
    let selected: Bool
    var accent: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selected ? accent.opacity(0.25) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(selected ? accent : Color.white.opacity(0.25), lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    struct Demo: View {
        @State private var sel: Set<String> = []
        let pubs = ["Apple", "Eventide", "UVI", "Waves", "Softube", "Native Instruments", "Acme"]
        var body: some View {
            VStack {
                Text("Publisher").font(.headline)
                PublishersCloud(publishers: pubs, selection: $sel)
            }
            .padding()
            .frame(width: 280)
            .background(Color(red: 30/255, green: 30/255, blue: 30/255))
        }
    }
    return Demo()
}
