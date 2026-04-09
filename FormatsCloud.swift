import SwiftUI

/// A centered, wrapping cloud of format chips plus an "OBSLT" chip.
struct FormatsCloud: View {
    @Binding var selectedFormats: Set<PluginFormat>
    var useFullObsoleteLabel: Bool = false

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
        // Exclude OBSLT and unknown from format list
        // OBSLT has special handling below, unknown is not user-selectable
        let formatItems: [ChipItem] = PluginFormat.allCases.filter { $0 != .OBSLT && $0 != .unknown }.map { .format($0) }
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
            let color = colorForPluginFormat(format)
            ChipView(title: format.rawValue, selected: selectedFormats.contains(format), accent: color) {
                if selectedFormats.contains(format) { selectedFormats.remove(format) } else { selectedFormats.insert(format) }
            }
        case .obsolete:
            let label = useFullObsoleteLabel ? "OBSOLETE" : "OBSLT"
            ChipView(title: label, selected: selectedFormats.contains(.OBSLT), accent: .red, accessibilityTitle: "OBSOLETE") {
                if selectedFormats.contains(.OBSLT) {
                    selectedFormats.remove(.OBSLT)
                } else {
                    selectedFormats.insert(.OBSLT)
                }
            }
        }
    }

    // Match colors from table badges
    private func colorForPluginFormat(_ format: PluginFormat) -> Color {
        switch format {
        case .AU:   return .blue
        case .VST:  return .green
        case .VST3: return .teal
        case .AAX:  return .purple
        case .CLAP: return .orange
        case .LV2:  return .gray
        case .OBSLT: return .red
        case .unknown: return .gray
        }
    }
}

/// Local chip view (badge-style matching table types) used by FormatsCloud.
private struct ChipView: View {
    let title: String
    let selected: Bool
    var accent: Color = .accentColor
    var accessibilityTitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accent)
                .padding(.horizontal, 6)
                .frame(height: 20)
                .frame(minWidth: 52)  // Min width 52, but can expand for longer text
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(accent.opacity(selected ? 0.3 : 0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(selected ? accent : Color.clear, lineWidth: selected ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel(accessibilityTitle ?? title)
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
                        if abs(width - d.width) > size.width {
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
            Task { @MainActor in
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
