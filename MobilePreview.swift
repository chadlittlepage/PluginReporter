// MobilePreview.swift — iOS look of ContentView using mock data
import SwiftUI

#if DEBUG
struct MobilePreview: View {
    @StateObject private var scanner: PluginScanner
    @StateObject private var prefs = Preferences()

    init() {
        // Build a few mock items
        let mocks: [ScannerPluginItem] = [
            ScannerPluginItem(id: UUID(), name: "Stereo Room", publisher: "Eventide", version: "3.7.10", type: "AU", architectures: "Apple, Intel 64", date: Date(), sizeBytes: 14_000_000, path: "/Library/Audio/Plug-Ins/Components/StereoRoom.component", runtimeRequirement: "Universal", obsolete: false),
            ScannerPluginItem(id: UUID(), name: "MetricAB", publisher: "ADPTR", version: "1.4.1", type: "VST3", architectures: "Apple, Intel 64", date: Date(), sizeBytes: 24_000_000, path: "/Library/Audio/Plug-Ins/VST3/MetricAB.vst3", runtimeRequirement: "Universal", obsolete: false),
            ScannerPluginItem(id: UUID(), name: "Classic EQ", publisher: "Acme", version: "2.3", type: "AAX", architectures: "Universal", date: Date(), sizeBytes: 11_000_000, path: "/Library/Application Support/Avid/Audio/Plug-Ins/ClassicEQ.aaxplugin", runtimeRequirement: "Universal", obsolete: false)
        ]
        _scanner = StateObject(wrappedValue: PluginScanner.preview(with: mocks))
    }

    var body: some View {
        ContentView()
            .environmentObject(scanner)
            .environmentObject(prefs)
            .padding(.horizontal, 0) // let it use full width
    }
}

#Preview("iPhone 15 Pro") {
    MobilePreview()
        .previewDevice(.iPhone15Pro)
}

#Preview("iPad Pro 11\"") {
    MobilePreview()
        .previewDevice(.iPadPro11)
}
#endif
