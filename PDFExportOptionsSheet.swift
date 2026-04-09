// PDFExportOptionsSheet.swift — SwiftUI UI for PDF export options
import Combine
import SwiftUI

struct PDFExportOptionsSheet: View {
    @Binding var options: PDFExportOptions
    var onConfirm: (PDFExportOptions) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export PDF Options").font(.title3).bold()

            HStack {
                Text("Page Size")
                Picker("Page Size", selection: $options.page) {
                    ForEach(PDFExportOptions.Page.allCases) { page in
                        Text(page.rawValue).tag(page)
                    }
                }
                .labelsHidden()
            }

            Toggle("Landscape", isOn: $options.landscape)

            HStack {
                Text("Margins")
                Slider(value: Binding(get: { Double(options.margin) }, set: { options.margin = CGFloat($0) }), in: 12...72)
                Text("\(Int(options.margin)) pt").monospacedDigit()
            }

            HStack {
                Text("Font Size")
                Slider(value: Binding(get: { Double(options.fontSize) }, set: { options.fontSize = CGFloat($0) }), in: 7...14)
                Text("\(Int(options.fontSize)) pt").monospacedDigit()
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Export") { onConfirm(options) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

#Preview {
    PDFExportOptionsSheet(options: .constant(PDFExportOptions())) { _ in } onCancel: { }
}
