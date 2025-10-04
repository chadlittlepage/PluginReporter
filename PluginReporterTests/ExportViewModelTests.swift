//
//  ExportViewModelTests.swift
//  PluginReporterTests
//
//  Comprehensive unit tests for ExportViewModel
//

import XCTest
@testable import PluginReporter

@MainActor
final class ExportViewModelTests: XCTestCase {

    // MARK: - Test Data Helpers

    private func createSamplePlugins() -> [PluginItem] {
        return [
            PluginItem(
                name: "Test Reverb",
                publisher: "Audio Company",
                version: "1.2.3",
                type: "VST3",
                style: "Reverb",
                architectures: "arm64, x86_64",
                date: Date(timeIntervalSince1970: 1704067200), // Jan 1, 2024
                sizeBytes: 5242880, // 5 MB
                obsolete: false
            ),
            PluginItem(
                name: "Compressor Pro",
                publisher: "Audio Company",
                version: "2.0.0",
                type: "AU",
                style: "Compressor",
                architectures: "arm64",
                date: Date(timeIntervalSince1970: 1704153600), // Jan 2, 2024
                sizeBytes: 3145728, // 3 MB
                obsolete: false
            ),
            PluginItem(
                name: "Old Plugin",
                publisher: "Legacy Audio",
                version: "1.0.0",
                type: "VST",
                style: "Effect",
                architectures: "x86_64",
                date: Date(timeIntervalSince1970: 1577836800), // Jan 1, 2020
                sizeBytes: 1048576, // 1 MB
                obsolete: true
            )
        ]
    }

    private func createPluginWithSpecialCharacters() -> [PluginItem] {
        return [
            PluginItem(
                name: "Test, Plugin",
                publisher: "Company, Inc.",
                version: "1.0",
                type: "VST",
                style: "EQ, Compressor",
                architectures: "arm64, x86_64"
            )
        ]
    }

    // MARK: - Initialization Tests

    func test_initialization_withEmptyPlugins_createsViewModel() {
        let viewModel = ExportViewModel(plugins: [])

        XCTAssertEqual(viewModel.plugins.count, 0)
        XCTAssertFalse(viewModel.showShareSheet)
        XCTAssertNil(viewModel.exportURL)
        XCTAssertFalse(viewModel.isExporting)
        XCTAssertNil(viewModel.lastError)
    }

    func test_initialization_withSamplePlugins_createsViewModel() {
        let plugins = createSamplePlugins()
        let viewModel = ExportViewModel(plugins: plugins)

        XCTAssertEqual(viewModel.plugins.count, 3)
        XCTAssertFalse(viewModel.showShareSheet)
        XCTAssertNil(viewModel.exportURL)
        XCTAssertFalse(viewModel.isExporting)
        XCTAssertNil(viewModel.lastError)
    }

    func test_updatePlugins_replacesPluginList() {
        let viewModel = ExportViewModel(plugins: [])
        XCTAssertEqual(viewModel.plugins.count, 0)

        viewModel.updatePlugins(createSamplePlugins())
        XCTAssertEqual(viewModel.plugins.count, 3)
    }

    // MARK: - CSV Export Tests

    func test_exportCSV_withEmptyPlugins_createsFile() {
        let viewModel = ExportViewModel(plugins: [])

        viewModel.exportCSV()

        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.showShareSheet)
        XCTAssertFalse(viewModel.isExporting)
    }

    func test_exportCSV_withSamplePlugins_createsFile() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.showShareSheet)
        XCTAssertFalse(viewModel.isExporting)
    }

    func test_exportCSV_createsValidCSVContent() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)

        // Check header
        XCTAssertTrue(content.contains("Name,Publisher,Type,Style,Version,Architecture,Size,Obsolete"))

        // Check data rows
        XCTAssertTrue(content.contains("Test Reverb"))
        XCTAssertTrue(content.contains("Audio Company"))
        XCTAssertTrue(content.contains("VST3"))
        XCTAssertTrue(content.contains("Reverb"))
        XCTAssertTrue(content.contains("1.2.3"))

        XCTAssertTrue(content.contains("Compressor Pro"))
        XCTAssertTrue(content.contains("Old Plugin"))
        XCTAssertTrue(content.contains("Legacy Audio"))
    }

    func test_exportCSV_handlesObsoleteFlag() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")

        // Find the Old Plugin line (obsolete)
        let obsoleteLine = lines.first { $0.contains("Old Plugin") }
        XCTAssertNotNil(obsoleteLine)
        XCTAssertTrue(obsoleteLine?.contains("Yes") ?? false)

        // Find a non-obsolete plugin line
        let normalLine = lines.first { $0.contains("Test Reverb") }
        XCTAssertNotNil(normalLine)
        XCTAssertTrue(normalLine?.contains("No") ?? false)
    }

    func test_exportCSV_escapesCommas() throws {
        let viewModel = ExportViewModel(plugins: createPluginWithSpecialCharacters())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)

        // Commas should be replaced with semicolons
        XCTAssertTrue(content.contains("Test; Plugin"))
        XCTAssertTrue(content.contains("Company; Inc."))
        XCTAssertTrue(content.contains("EQ; Compressor"))
    }

    func test_exportCSV_includesAllColumns() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")
        let header = lines[0]

        XCTAssertTrue(header.contains("Name"))
        XCTAssertTrue(header.contains("Publisher"))
        XCTAssertTrue(header.contains("Type"))
        XCTAssertTrue(header.contains("Style"))
        XCTAssertTrue(header.contains("Version"))
        XCTAssertTrue(header.contains("Architecture"))
        XCTAssertTrue(header.contains("Size"))
        XCTAssertTrue(header.contains("Obsolete"))
    }

    func test_exportCSV_correctRowCount() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        // 1 header + 3 data rows
        XCTAssertEqual(lines.count, 4)
    }

    func test_exportCSV_usesDisplaySize() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)

        // Check that displaySize is used (should be formatted like "5 MB", "3 MB", etc.)
        XCTAssertTrue(content.contains("MB") || content.contains("KB"))
    }

    // MARK: - PDF Export Tests

    func test_exportPDF_withEmptyPlugins_createsFile() {
        let viewModel = ExportViewModel(plugins: [])

        viewModel.exportPDF()

        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.showShareSheet)
        XCTAssertFalse(viewModel.isExporting)
    }

    func test_exportPDF_withSamplePlugins_createsFile() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportPDF()

        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.showShareSheet)
        XCTAssertFalse(viewModel.isExporting)
    }

    func test_exportPDF_createsValidPDFFile() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportPDF()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        // Check file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // Check file has content
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)

        // Check PDF magic number (%PDF)
        let pdfHeader = String(data: data.prefix(4), encoding: .utf8)
        XCTAssertEqual(pdfHeader, "%PDF")
    }

    func test_exportPDF_includesPluginCount() throws {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportPDF()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let data = try Data(contentsOf: url)
        let pdfString = String(data: data, encoding: .utf8) ?? ""

        // PDF should contain plugin count in title
        XCTAssertTrue(pdfString.contains("3 plugins") || pdfString.contains("Plugin List"))
    }

    func test_exportPDF_handlesLargeDataset() {
        let plugins = (0..<100).map { i in
            PluginItem(
                name: "Plugin \(i)",
                publisher: "Publisher \(i)",
                type: "VST",
                style: "Effect"
            )
        }
        let viewModel = ExportViewModel(plugins: plugins)

        viewModel.exportPDF()

        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.showShareSheet)
        XCTAssertFalse(viewModel.isExporting)
    }

    // MARK: - Error Handling Tests

    func test_exportCSV_clearsLastError() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        // Simulate previous error
        viewModel.lastError = NSError(domain: "test", code: 1)

        viewModel.exportCSV()

        // Error should be cleared on new export attempt
        XCTAssertNil(viewModel.lastError)
    }

    func test_exportPDF_clearsLastError() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        // Simulate previous error
        viewModel.lastError = NSError(domain: "test", code: 1)

        viewModel.exportPDF()

        // Error should be cleared on new export attempt
        XCTAssertNil(viewModel.lastError)
    }

    // MARK: - State Management Tests

    func test_isExporting_setToFalse_afterCSVExport() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        XCTAssertFalse(viewModel.isExporting)
    }

    func test_isExporting_setToFalse_afterPDFExport() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportPDF()

        XCTAssertFalse(viewModel.isExporting)
    }

    func test_exportURL_updates_afterCSVExport() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        let previousURL = viewModel.exportURL

        viewModel.exportCSV()

        XCTAssertNotEqual(viewModel.exportURL, previousURL)
        XCTAssertNotNil(viewModel.exportURL)
    }

    func test_exportURL_updates_afterPDFExport() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        let previousURL = viewModel.exportURL

        viewModel.exportPDF()

        XCTAssertNotEqual(viewModel.exportURL, previousURL)
        XCTAssertNotNil(viewModel.exportURL)
    }

    func test_showShareSheet_setToTrue_afterCSVExport() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        XCTAssertFalse(viewModel.showShareSheet)

        viewModel.exportCSV()

        XCTAssertTrue(viewModel.showShareSheet)
    }

    func test_showShareSheet_setToTrue_afterPDFExport() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        XCTAssertFalse(viewModel.showShareSheet)

        viewModel.exportPDF()

        XCTAssertTrue(viewModel.showShareSheet)
    }

    // MARK: - File Location Tests

    func test_exportCSV_usesCorrectFileName() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        XCTAssertTrue(url.lastPathComponent.contains("plugins.csv"))
    }

    func test_exportPDF_usesCorrectFileName() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportPDF()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        XCTAssertTrue(url.lastPathComponent.contains("plugins.pdf"))
    }

    func test_exportCSV_usesTemporaryDirectory() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        XCTAssertTrue(url.path.hasPrefix(tempDir.path))
    }

    func test_exportPDF_usesTemporaryDirectory() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportPDF()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        XCTAssertTrue(url.path.hasPrefix(tempDir.path))
    }

    // MARK: - Edge Cases Tests

    func test_exportCSV_withEmptyStrings_handlesCorrectly() throws {
        let plugins = [
            PluginItem(
                name: "",
                publisher: "",
                version: "",
                type: "VST",
                style: "",
                architectures: ""
            )
        ]
        let viewModel = ExportViewModel(plugins: plugins)

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(content.isEmpty)
    }

    func test_exportPDF_withEmptyStrings_handlesCorrectly() {
        let plugins = [
            PluginItem(
                name: "",
                publisher: "",
                type: "VST",
                style: ""
            )
        ]
        let viewModel = ExportViewModel(plugins: plugins)

        viewModel.exportPDF()

        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertNil(viewModel.lastError)
    }

    func test_exportCSV_withLongStrings_handlesCorrectly() throws {
        let longString = String(repeating: "a", count: 1000)
        let plugins = [
            PluginItem(
                name: longString,
                publisher: longString,
                type: "VST",
                style: longString
            )
        ]
        let viewModel = ExportViewModel(plugins: plugins)

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains(longString))
    }

    func test_exportCSV_withUnicodeCharacters_handlesCorrectly() throws {
        let plugins = [
            PluginItem(
                name: "音楽プラグイン",
                publisher: "日本の会社",
                type: "VST",
                style: "リバーブ"
            )
        ]
        let viewModel = ExportViewModel(plugins: plugins)

        viewModel.exportCSV()

        guard let url = viewModel.exportURL else {
            XCTFail("Export URL should not be nil")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("音楽プラグイン"))
        XCTAssertTrue(content.contains("日本の会社"))
    }

    func test_multipleExports_overwritesPreviousFile() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()
        let firstURL = viewModel.exportURL

        viewModel.exportCSV()
        let secondURL = viewModel.exportURL

        // URLs should be the same (same file location)
        XCTAssertEqual(firstURL, secondURL)
    }

    func test_exportCSV_thenPDF_createsDifferentFiles() {
        let viewModel = ExportViewModel(plugins: createSamplePlugins())

        viewModel.exportCSV()
        let csvURL = viewModel.exportURL

        viewModel.exportPDF()
        let pdfURL = viewModel.exportURL

        XCTAssertNotEqual(csvURL, pdfURL)
        XCTAssertTrue(csvURL?.pathExtension == "csv")
        XCTAssertTrue(pdfURL?.pathExtension == "pdf")
    }

    // MARK: - Performance Tests

    func test_exportCSV_performance_with1000Plugins() {
        let plugins = (0..<1000).map { i in
            PluginItem(
                name: "Plugin \(i)",
                publisher: "Publisher \(i % 10)",
                version: "1.0.\(i)",
                type: ["VST", "AU", "VST3"][i % 3],
                style: "Style \(i % 5)",
                architectures: "arm64",
                sizeBytes: Int64(i * 1024)
            )
        }
        let viewModel = ExportViewModel(plugins: plugins)

        measure {
            viewModel.exportCSV()
        }
    }

    func test_exportPDF_performance_with100Plugins() {
        let plugins = (0..<100).map { i in
            PluginItem(
                name: "Plugin \(i)",
                publisher: "Publisher \(i % 10)",
                type: ["VST", "AU", "VST3"][i % 3],
                style: "Style \(i % 5)"
            )
        }
        let viewModel = ExportViewModel(plugins: plugins)

        measure {
            viewModel.exportPDF()
        }
    }
}
