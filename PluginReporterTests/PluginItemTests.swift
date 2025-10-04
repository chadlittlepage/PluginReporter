//
//  PluginItemTests.swift
//  PluginReporterTests
//
//  Comprehensive unit tests for PluginItem model
//

import XCTest
@testable import PluginReporter

final class PluginItemTests: XCTestCase {

    // MARK: - Test Data Helpers

    private func createSamplePlugin() -> PluginItem {
        return PluginItem(
            id: UUID(),
            name: "Test Reverb",
            publisher: "Audio Company",
            version: "1.2.3",
            type: "VST3",
            style: "Reverb",
            architectures: "arm64, x86_64",
            date: Date(timeIntervalSince1970: 1704067200), // Jan 1, 2024
            sizeBytes: 5242880, // 5 MB
            path: "/Library/Audio/Plug-Ins/VST3/TestReverb.vst3",
            runtimeRequirement: "macOS 12.0",
            obsolete: false
        )
    }

    private func createObsoletePlugin() -> PluginItem {
        return PluginItem(
            id: UUID(),
            name: "Old Plugin",
            publisher: "Legacy Audio",
            version: "1.0.0",
            type: "AU",
            style: "Effect",
            architectures: "x86_64",
            date: Date(timeIntervalSince1970: 1577836800), // Jan 1, 2020
            sizeBytes: 1048576, // 1 MB
            path: "/Library/Audio/Plug-Ins/Components/OldPlugin.component",
            runtimeRequirement: "macOS 10.13",
            obsolete: true
        )
    }

    // MARK: - Initialization Tests

    func test_initialization_withAllParameters_createsPluginCorrectly() {
        let id = UUID()
        let plugin = PluginItem(
            id: id,
            name: "Test Plugin",
            publisher: "Test Publisher",
            version: "2.0.0",
            type: "VST",
            style: "Synthesizer",
            architectures: "arm64",
            date: Date(),
            sizeBytes: 10485760,
            path: "/test/path",
            runtimeRequirement: "macOS 13.0",
            obsolete: true
        )

        XCTAssertEqual(plugin.id, id)
        XCTAssertEqual(plugin.name, "Test Plugin")
        XCTAssertEqual(plugin.publisher, "Test Publisher")
        XCTAssertEqual(plugin.version, "2.0.0")
        XCTAssertEqual(plugin.type, "VST")
        XCTAssertEqual(plugin.style, "Synthesizer")
        XCTAssertEqual(plugin.architectures, "arm64")
        XCTAssertNotNil(plugin.date)
        XCTAssertEqual(plugin.sizeBytes, 10485760)
        XCTAssertEqual(plugin.path, "/test/path")
        XCTAssertEqual(plugin.runtimeRequirement, "macOS 13.0")
        XCTAssertTrue(plugin.obsolete)
    }

    func test_initialization_withDefaultParameters_usesDefaults() {
        let plugin = PluginItem(name: "Minimal", type: "AU")

        XCTAssertEqual(plugin.name, "Minimal")
        XCTAssertEqual(plugin.type, "AU")
        XCTAssertEqual(plugin.publisher, "")
        XCTAssertEqual(plugin.version, "")
        XCTAssertEqual(plugin.style, "")
        XCTAssertEqual(plugin.architectures, "")
        XCTAssertNil(plugin.date)
        XCTAssertEqual(plugin.sizeBytes, 0)
        XCTAssertEqual(plugin.path, "")
        XCTAssertEqual(plugin.runtimeRequirement, "")
        XCTAssertFalse(plugin.obsolete)
    }

    func test_initialization_generatesUniqueIDs() {
        let plugin1 = PluginItem(name: "Plugin 1", type: "VST")
        let plugin2 = PluginItem(name: "Plugin 2", type: "VST")

        XCTAssertNotEqual(plugin1.id, plugin2.id)
    }

    // MARK: - DisplaySize Tests

    func test_displaySize_withZeroBytes_returnsZeroKB() {
        let plugin = PluginItem(name: "Test", type: "VST", sizeBytes: 0)
        XCTAssertEqual(plugin.displaySize, "0 bytes")
    }

    func test_displaySize_withKilobytes_returnsFormattedKB() {
        let plugin = PluginItem(name: "Test", type: "VST", sizeBytes: 1024)
        XCTAssertEqual(plugin.displaySize, "1 KB")
    }

    func test_displaySize_withMegabytes_returnsFormattedMB() {
        let plugin = PluginItem(name: "Test", type: "VST", sizeBytes: 5242880) // 5 MB
        XCTAssertEqual(plugin.displaySize, "5 MB")
    }

    func test_displaySize_withGigabytes_returnsFormattedGB() {
        let plugin = PluginItem(name: "Test", type: "VST", sizeBytes: 1073741824) // 1 GB
        XCTAssertEqual(plugin.displaySize, "1.07 GB")
    }

    func test_displaySize_withDecimalValues_roundsCorrectly() {
        let plugin = PluginItem(name: "Test", type: "VST", sizeBytes: 1536000) // ~1.5 MB
        XCTAssertTrue(plugin.displaySize.contains("1.5"))
    }

    func test_displaySize_withLargeValues_handlesCorrectly() {
        let plugin = PluginItem(name: "Test", type: "VST", sizeBytes: Int64.max)
        XCTAssertFalse(plugin.displaySize.isEmpty)
    }

    // MARK: - DisplayDate Tests

    func test_displayDate_withNilDate_returnsUnknown() {
        let plugin = PluginItem(name: "Test", type: "VST", date: nil)
        XCTAssertEqual(plugin.displayDate, "Unknown")
    }

    func test_displayDate_withValidDate_returnsFormattedDate() {
        let date = Date(timeIntervalSince1970: 1704067200) // Jan 1, 2024 00:00:00 UTC
        let plugin = PluginItem(name: "Test", type: "VST", date: date)
        XCTAssertFalse(plugin.displayDate.isEmpty)
        XCTAssertNotEqual(plugin.displayDate, "Unknown")
    }

    func test_displayDate_withDistantPast_handlesCorrectly() {
        let plugin = PluginItem(name: "Test", type: "VST", date: Date.distantPast)
        XCTAssertFalse(plugin.displayDate.isEmpty)
    }

    func test_displayDate_withDistantFuture_handlesCorrectly() {
        let plugin = PluginItem(name: "Test", type: "VST", date: Date.distantFuture)
        XCTAssertFalse(plugin.displayDate.isEmpty)
    }

    // MARK: - Codable Tests

    func test_codable_encodesAndDecodesCorrectly() throws {
        let original = createSamplePlugin()

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PluginItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.publisher, original.publisher)
        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.style, original.style)
        XCTAssertEqual(decoded.architectures, original.architectures)
        XCTAssertEqual(decoded.date?.timeIntervalSince1970, original.date?.timeIntervalSince1970)
        XCTAssertEqual(decoded.sizeBytes, original.sizeBytes)
        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.runtimeRequirement, original.runtimeRequirement)
        XCTAssertEqual(decoded.obsolete, original.obsolete)
    }

    func test_codable_encodesArrayCorrectly() throws {
        let plugins = [createSamplePlugin(), createObsoletePlugin()]

        let encoder = JSONEncoder()
        let data = try encoder.encode(plugins)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([PluginItem].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].name, plugins[0].name)
        XCTAssertEqual(decoded[1].name, plugins[1].name)
    }

    func test_codable_withNilDate_encodesAndDecodesCorrectly() throws {
        let original = PluginItem(name: "Test", type: "VST", date: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PluginItem.self, from: data)

        XCTAssertNil(decoded.date)
    }

    // MARK: - Hashable Tests

    func test_hashable_sameID_areEqual() {
        let id = UUID()
        let plugin1 = PluginItem(id: id, name: "Plugin 1", type: "VST")
        let plugin2 = PluginItem(id: id, name: "Plugin 2", type: "AU")

        XCTAssertEqual(plugin1, plugin2)
    }

    func test_hashable_differentID_areNotEqual() {
        let plugin1 = PluginItem(name: "Plugin", type: "VST")
        let plugin2 = PluginItem(name: "Plugin", type: "VST")

        XCTAssertNotEqual(plugin1, plugin2)
    }

    func test_hashable_canBeUsedInSet() {
        let plugin1 = createSamplePlugin()
        let plugin2 = createObsoletePlugin()

        var set = Set<PluginItem>()
        set.insert(plugin1)
        set.insert(plugin2)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(plugin1))
        XCTAssertTrue(set.contains(plugin2))
    }

    func test_hashable_removesCorrectItemFromSet() {
        var set = Set<PluginItem>()
        let plugin = createSamplePlugin()

        set.insert(plugin)
        XCTAssertEqual(set.count, 1)

        set.remove(plugin)
        XCTAssertEqual(set.count, 0)
    }

    // MARK: - Property Accessor Tests

    func test_properties_canBeAccessed() {
        let plugin = createSamplePlugin()

        XCTAssertFalse(plugin.name.isEmpty)
        XCTAssertFalse(plugin.publisher.isEmpty)
        XCTAssertFalse(plugin.version.isEmpty)
        XCTAssertFalse(plugin.type.isEmpty)
        XCTAssertFalse(plugin.style.isEmpty)
        XCTAssertFalse(plugin.architectures.isEmpty)
        XCTAssertNotNil(plugin.date)
        XCTAssertGreaterThan(plugin.sizeBytes, 0)
        XCTAssertFalse(plugin.path.isEmpty)
        XCTAssertFalse(plugin.runtimeRequirement.isEmpty)
    }

    func test_properties_canBeModified() {
        var plugin = createSamplePlugin()

        plugin.name = "Modified Name"
        plugin.publisher = "New Publisher"
        plugin.obsolete = true

        XCTAssertEqual(plugin.name, "Modified Name")
        XCTAssertEqual(plugin.publisher, "New Publisher")
        XCTAssertTrue(plugin.obsolete)
    }

    // MARK: - PluginFormat Enum Tests

    func test_pluginFormat_allCases_containsExpectedValues() {
        let formats = PluginFormat.allCases
        XCTAssertTrue(formats.contains(.AU))
        XCTAssertTrue(formats.contains(.VST))
        XCTAssertTrue(formats.contains(.VST3))
        XCTAssertTrue(formats.contains(.AAX))
        XCTAssertTrue(formats.contains(.CLAP))
        XCTAssertTrue(formats.contains(.LV2))
    }

    func test_pluginFormat_rawValue_matchesExpectedString() {
        XCTAssertEqual(PluginFormat.AU.rawValue, "AU")
        XCTAssertEqual(PluginFormat.VST.rawValue, "VST")
        XCTAssertEqual(PluginFormat.VST3.rawValue, "VST3")
        XCTAssertEqual(PluginFormat.AAX.rawValue, "AAX")
        XCTAssertEqual(PluginFormat.CLAP.rawValue, "CLAP")
        XCTAssertEqual(PluginFormat.LV2.rawValue, "LV2")
    }

    func test_pluginFormat_id_equalsRawValue() {
        for format in PluginFormat.allCases {
            XCTAssertEqual(format.id, format.rawValue)
        }
    }

    func test_pluginFormat_codable_encodesAndDecodesCorrectly() throws {
        let format = PluginFormat.VST3

        let encoder = JSONEncoder()
        let data = try encoder.encode(format)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PluginFormat.self, from: data)

        XCTAssertEqual(decoded, format)
    }
}
