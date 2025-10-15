import SwiftUI

/// A centered, wrapping cloud of format chips plus an "OBSLT" chip.
struct FormatsCloud: View {
    @Binding var selectedFormats: Set<PluginFormat>

    private enum ChipItem: Identifiable {
        case format(PluginFormat)
        case obsolete
        var id: String {
            switch self {
            case .format(let f): return "fmt-\(f.rawValue)"
            case .obsolete:      return "obsl"
            }
        }
    }

    var body: some View {
        // Exclude OBSLT from format list since it has special handling below
        let formatItems: [ChipItem] = PluginFormat.allCases.filter { $0 != .OBSLT }.map { .format($0) }
        let left  = formatItems.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
        let right = formatItems.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }

        return VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(left) { item in
                        chip(for: item)
                    }
                }
                .fixedSize()

                Spacer().frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(right) { item in
                        chip(for: item)
                    }
                }
                .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Centered OBSLT chip on its own row
            HStack(spacing: 0) {
                chip(for: .obsolete)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder private func chip(for item: ChipItem) -> some View {
        switch item {
        case .format(let format):
            ChipView(title: format.rawValue, selected: selectedFormats.contains(format)) {
                if selectedFormats.contains(format) { selectedFormats.remove(format) }
                else { selectedFormats.insert(format) }
            }
        case .obsolete:
            ChipView(title: "OBSOLETE", selected: selectedFormats.contains(.OBSLT), accent: .red) {
                if selectedFormats.contains(.OBSLT) {
                    selectedFormats.remove(.OBSLT)
                } else {
                    selectedFormats.insert(.OBSLT)
                }
            }
        }
    }
}

/// Local chip view (capsule-style) used by FormatsCloud.
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

/// A flow layout that wraps items in a centered cloud
struct FlowLayout<Data: RandomAccessCollection, Content: View, ID: Hashable>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    @State private var totalHeight
        = CGFloat.zero       // << variant for ScrollView/List

    init(items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry.size)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in size: CGSize) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .top) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
                    .padding(4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if item == items.last {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geo.size.height
            }
            return Color.clear
        }
    }
}

private extension PluginFormat {
    static let obsoletedChip = PluginFormat(rawValue: "OBSLT")

    var isObsoleteChip: Bool {
        rawValue == "OBSLT"
    }
}

#Preview {
    struct Demo: View {
        @State private var formats: Set<PluginFormat> = Set(PluginFormat.allCases)
        var body: some View {
            VStack(alignment: .center) {
                Text("Formats").font(.headline)
                FormatsCloud(selectedFormats: $formats)
            }
            .padding()
            .frame(width: 280)
            .background(Color(red: 30/255, green: 30/255, blue: 30/255))
        }
    }
    return Demo()
}
