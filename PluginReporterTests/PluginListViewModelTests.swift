//
//  PluginListViewModelTests.swift
//  PluginReporterTests
//
//  Comprehensive unit tests for PluginListViewModel
//

import XCTest
@testable import PluginReporter

@MainActor
final class PluginListViewModelTests: XCTestCase {

    // MARK: - Test Data Helpers

    private func createSamplePlugins() -> [PluginItem] {
        return [
            PluginItem(
                name: "EQ Eight",
                publisher: "Ableton",
                version: "11.0",
                type: "VST3",
                style: "EQ",
                sizeBytes: 5242880
            ),
            PluginItem(
                name: "Reverb One",
                publisher: "Audio Company",
                version: "2.0",
                type: "AU",
                style: "Reverb",
                sizeBytes: 10485760
            ),
            PluginItem(
                name: "Compressor Pro",
                publisher: "Audio Company",
                version: "1.5",
                type: "VST",
                style: "Compressor",
                sizeBytes: 3145728
            ),
            PluginItem(
                name: "Synth Master",
                publisher: "Synth Corp",
                version: "3.0",
                type: "VST3",
                style: "Synthesizer",
                sizeBytes: 20971520
            ),
            PluginItem(
                name: "Old Plugin",
                publisher: "Legacy Audio",
                version: "1.0",
                type: "AU",
                style: "Effect",
                sizeBytes: 1048576,
                obsolete: true
            )
        ]
    }

    // MARK: - Initialization Tests

    func test_initialization_withEmptyPlugins_createsViewModel() {
        let viewModel = PluginListViewModel(plugins: [])

        XCTAssertEqual(viewModel.plugins.count, 0)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertNil(viewModel.selectedFormat)
        XCTAssertNil(viewModel.selectedStyle)
        XCTAssertNil(viewModel.selectedPublisher)
        XCTAssertEqual(viewModel.sortOrder, .name)
    }

    func test_initialization_withSamplePlugins_createsViewModel() {
        let plugins = createSamplePlugins()
        let viewModel = PluginListViewModel(plugins: plugins)

        XCTAssertEqual(viewModel.plugins.count, 5)
        XCTAssertEqual(viewModel.totalPluginCount, 5)
    }

    func test_updatePlugins_replacesPluginList() {
        let viewModel = PluginListViewModel(plugins: [])
        XCTAssertEqual(viewModel.totalPluginCount, 0)

        viewModel.updatePlugins(createSamplePlugins())
        XCTAssertEqual(viewModel.totalPluginCount, 5)
    }

    // MARK: - Search Text Filtering Tests

    func test_searchText_filtersByName_caseInsensitive() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = "reverb"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Reverb One")
    }

    func test_searchText_filtersByPublisher_caseInsensitive() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = "audio company"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.publisher == "Audio Company" })
    }

    func test_searchText_filtersByStyle() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = "synthesizer"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].style, "Synthesizer")
    }

    func test_searchText_partialMatch_returnsResults() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = "comp"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertTrue(filtered.contains { $0.name.contains("Comp") })
    }

    func test_searchText_noMatch_returnsEmpty() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = "NonexistentPlugin"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 0)
    }

    func test_searchText_emptyString_returnsAllPlugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = ""

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 5)
    }

    // MARK: - Format Filtering Tests

    func test_formatFilter_VST_returnsOnlyVSTPlugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "VST"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.allSatisfy { $0.type.uppercased() == "VST" })
    }

    func test_formatFilter_AU_returnsOnlyAUPlugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "AU"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.type.uppercased() == "AU" })
    }

    func test_formatFilter_VST3_returnsOnlyVST3Plugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "VST3"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.type.uppercased() == "VST3" })
    }

    func test_formatFilter_OBSLT_returnsOnlyObsoletePlugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "OBSLT"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.allSatisfy { $0.obsolete })
    }

    func test_formatFilter_caseInsensitive_worksCorrectly() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "vst3"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 2)
    }

    // MARK: - Style Filtering Tests

    func test_styleFilter_filtersCorrectly() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedStyle = "Reverb"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].style, "Reverb")
    }

    func test_styleFilter_multiplePluginsWithSameStyle() {
        let plugins = createSamplePlugins() + [
            PluginItem(name: "Reverb Two", publisher: "Test", type: "VST", style: "Reverb")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)
        viewModel.selectedStyle = "Reverb"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.style == "Reverb" })
    }

    // MARK: - Publisher Filtering Tests

    func test_publisherFilter_filtersCorrectly() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedPublisher = "Audio Company"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.publisher == "Audio Company" })
    }

    func test_publisherFilter_singlePublisher() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedPublisher = "Synth Corp"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].publisher, "Synth Corp")
    }

    // MARK: - Combined Filters Tests

    func test_combinedFilters_searchAndFormat() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.searchText = "audio"
        viewModel.selectedFormat = "AU"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Reverb One")
    }

    func test_combinedFilters_formatAndStyle() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "VST3"
        viewModel.selectedStyle = "Synthesizer"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Synth Master")
    }

    func test_combinedFilters_allFilters() {
        let plugins = createSamplePlugins() + [
            PluginItem(name: "Special EQ", publisher: "Audio Company", type: "VST3", style: "EQ")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)
        viewModel.searchText = "eq"
        viewModel.selectedFormat = "VST3"
        viewModel.selectedPublisher = "Audio Company"

        let filtered = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Special EQ")
    }

    // MARK: - Sorting Tests

    func test_sorting_byName_ascending() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.sortOrder = .name

        let sorted = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(sorted[0].name, "Compressor Pro")
        XCTAssertEqual(sorted[1].name, "EQ Eight")
        XCTAssertEqual(sorted[2].name, "Old Plugin")
        XCTAssertEqual(sorted[3].name, "Reverb One")
        XCTAssertEqual(sorted[4].name, "Synth Master")
    }

    func test_sorting_byPublisher_ascending() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.sortOrder = .publisher

        let sorted = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(sorted[0].publisher, "Ableton")
        XCTAssertEqual(sorted[1].publisher, "Audio Company")
        XCTAssertEqual(sorted[2].publisher, "Audio Company")
    }

    func test_sorting_byType_ascending() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.sortOrder = .type

        let sorted = viewModel.filteredAndSortedPlugins
        let types = sorted.map { $0.type }
        XCTAssertEqual(types[0], "AU")
        XCTAssertEqual(types[1], "AU")
        XCTAssertEqual(types[2], "VST")
        XCTAssertEqual(types[3], "VST3")
        XCTAssertEqual(types[4], "VST3")
    }

    func test_sorting_byStyle_ascending() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.sortOrder = .style

        let sorted = viewModel.filteredAndSortedPlugins
        XCTAssertEqual(sorted[0].style, "Compressor")
        XCTAssertEqual(sorted[1].style, "Effect")
        XCTAssertEqual(sorted[2].style, "EQ")
        XCTAssertEqual(sorted[3].style, "Reverb")
        XCTAssertEqual(sorted[4].style, "Synthesizer")
    }

    // MARK: - Consolidated Plugins Tests

    func test_consolidatedPlugins_groupsByNameAndPublisher() {
        let plugins = [
            PluginItem(name: "Plugin A", publisher: "Publisher X", type: "VST"),
            PluginItem(name: "Plugin A", publisher: "Publisher X", type: "VST3"),
            PluginItem(name: "Plugin A", publisher: "Publisher X", type: "AU")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        let consolidated = viewModel.consolidatedPlugins
        XCTAssertEqual(consolidated.count, 1)
        XCTAssertEqual(consolidated[0].name, "Plugin A")
        XCTAssertEqual(consolidated[0].types.count, 3)
        XCTAssertTrue(consolidated[0].types.contains("VST"))
        XCTAssertTrue(consolidated[0].types.contains("VST3"))
        XCTAssertTrue(consolidated[0].types.contains("AU"))
    }

    func test_consolidatedPlugins_differentPublishers_notGrouped() {
        let plugins = [
            PluginItem(name: "Plugin A", publisher: "Publisher X", type: "VST"),
            PluginItem(name: "Plugin A", publisher: "Publisher Y", type: "VST")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        let consolidated = viewModel.consolidatedPlugins
        XCTAssertEqual(consolidated.count, 2)
    }

    func test_consolidatedPlugins_marksObsolete_ifAnyVersionIsObsolete() {
        let plugins = [
            PluginItem(name: "Plugin A", publisher: "Test", type: "VST", obsolete: false),
            PluginItem(name: "Plugin A", publisher: "Test", type: "AU", obsolete: true)
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        let consolidated = viewModel.consolidatedPlugins
        XCTAssertEqual(consolidated.count, 1)
        XCTAssertTrue(consolidated[0].isObsolete)
    }

    func test_consolidatedPlugins_sortsTypes_correctly() {
        let plugins = [
            PluginItem(name: "Plugin A", publisher: "Test", type: "VST3"),
            PluginItem(name: "Plugin A", publisher: "Test", type: "AU"),
            PluginItem(name: "Plugin A", publisher: "Test", type: "VST")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        let consolidated = viewModel.consolidatedPlugins
        let types = consolidated[0].types
        // Types should be sorted according to formatSortOrder
        XCTAssertEqual(types[0], "AU") // order 1
        XCTAssertEqual(types[1], "VST") // order 2
        XCTAssertEqual(types[2], "VST3") // order 3
    }

    // MARK: - Unique Values Tests

    func test_uniquePublishers_returnsUniqueAndSorted() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        let publishers = viewModel.uniquePublishers
        XCTAssertEqual(publishers.count, 4)
        XCTAssertEqual(publishers, ["Ableton", "Audio Company", "Legacy Audio", "Synth Corp"])
    }

    func test_uniqueFormats_returnsUniqueAndSorted() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        let formats = viewModel.uniqueFormats
        XCTAssertEqual(formats.count, 3)
        XCTAssertTrue(formats.contains("AU"))
        XCTAssertTrue(formats.contains("VST"))
        XCTAssertTrue(formats.contains("VST3"))
    }

    func test_uniqueStyles_returnsUniqueAndSorted_excludesEmpty() {
        let plugins = createSamplePlugins() + [
            PluginItem(name: "No Style", publisher: "Test", type: "VST", style: "")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        let styles = viewModel.uniqueStyles
        XCTAssertFalse(styles.contains(""))
        XCTAssertEqual(styles.count, 5)
    }

    // MARK: - Format Counts Tests

    func test_formatCounts_countsCorrectly() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        let counts = viewModel.formatCounts
        XCTAssertEqual(counts["AU"], 2)
        XCTAssertEqual(counts["VST"], 1)
        XCTAssertEqual(counts["VST3"], 2)
        XCTAssertEqual(counts["OBSLT"], 1)
    }

    func test_formatCounts_emptyPlugins_returnsEmpty() {
        let viewModel = PluginListViewModel(plugins: [])

        let counts = viewModel.formatCounts
        XCTAssertTrue(counts.isEmpty)
    }

    // MARK: - Style Counts Tests

    func test_styleCounts_countsCorrectly() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        let counts = viewModel.styleCounts
        XCTAssertEqual(counts["EQ"], 1)
        XCTAssertEqual(counts["Reverb"], 1)
        XCTAssertEqual(counts["Compressor"], 1)
        XCTAssertEqual(counts["Synthesizer"], 1)
        XCTAssertEqual(counts["Effect"], 1)
    }

    func test_styleCounts_ignoresEmptyStyles() {
        let plugins = createSamplePlugins() + [
            PluginItem(name: "No Style", publisher: "Test", type: "VST", style: "")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        let counts = viewModel.styleCounts
        XCTAssertNil(counts[""])
    }

    // MARK: - Dynamic Format Counts Tests

    func test_dynamicFormatCounts_withNoFilters_countsAllPlugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        let dynamicCounts = viewModel.dynamicFormatCounts
        let countDict = Dictionary(uniqueKeysWithValues: dynamicCounts.map { ($0.format, $0.count) })

        XCTAssertEqual(countDict["AU"], 2)
        XCTAssertEqual(countDict["VST"], 1)
        XCTAssertEqual(countDict["VST3"], 2)
        XCTAssertEqual(countDict["OBSLT"], 1)
    }

    func test_dynamicFormatCounts_withFilters_countsFilteredPlugins() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedPublisher = "Audio Company"

        let dynamicCounts = viewModel.dynamicFormatCounts
        let countDict = Dictionary(uniqueKeysWithValues: dynamicCounts.map { ($0.format, $0.count) })

        XCTAssertEqual(countDict["AU"], 1)
        XCTAssertEqual(countDict["VST"], 1)
        XCTAssertEqual(countDict["VST3"], 0)
    }

    // MARK: - Clear Filters Tests

    func test_clearAllFilters_resetsAllFilters() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.searchText = "test"
        viewModel.selectedFormat = "VST"
        viewModel.selectedStyle = "Reverb"
        viewModel.selectedPublisher = "Test Publisher"
        viewModel.sortOrder = .publisher

        viewModel.clearAllFilters()

        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertNil(viewModel.selectedFormat)
        XCTAssertNil(viewModel.selectedStyle)
        XCTAssertNil(viewModel.selectedPublisher)
        XCTAssertEqual(viewModel.sortOrder, .name)
    }

    // MARK: - Toggle Methods Tests

    func test_toggleFormatFilter_setsFilter() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.toggleFormatFilter("VST")
        XCTAssertEqual(viewModel.selectedFormat, "VST")
    }

    func test_toggleFormatFilter_clearsFilter_whenAlreadySet() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.toggleFormatFilter("VST")
        XCTAssertEqual(viewModel.selectedFormat, "VST")

        viewModel.toggleFormatFilter("VST")
        XCTAssertNil(viewModel.selectedFormat)
    }

    func test_toggleStyleFilter_setsFilter() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.toggleStyleFilter("Reverb")
        XCTAssertEqual(viewModel.selectedStyle, "Reverb")
    }

    func test_toggleStyleFilter_clearsFilter_whenAlreadySet() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.toggleStyleFilter("Reverb")
        viewModel.toggleStyleFilter("Reverb")
        XCTAssertNil(viewModel.selectedStyle)
    }

    func test_togglePublisherFilter_setsFilter() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.togglePublisherFilter("Audio Company")
        XCTAssertEqual(viewModel.selectedPublisher, "Audio Company")
    }

    func test_togglePublisherFilter_clearsFilter_whenAlreadySet() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.togglePublisherFilter("Audio Company")
        viewModel.togglePublisherFilter("Audio Company")
        XCTAssertNil(viewModel.selectedPublisher)
    }

    func test_resetSortOrder_resetsToName() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.sortOrder = .publisher
        viewModel.resetSortOrder()
        XCTAssertEqual(viewModel.sortOrder, .name)
    }

    // MARK: - Computed Properties Tests

    func test_hasActiveFilters_withNoFilters_returnsFalse() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        XCTAssertFalse(viewModel.hasActiveFilters)
    }

    func test_hasActiveFilters_withFormatFilter_returnsTrue() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "VST"
        XCTAssertTrue(viewModel.hasActiveFilters)
    }

    func test_hasActiveFilters_withStyleFilter_returnsTrue() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedStyle = "Reverb"
        XCTAssertTrue(viewModel.hasActiveFilters)
    }

    func test_hasActiveFilters_withPublisherFilter_returnsTrue() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedPublisher = "Test"
        XCTAssertTrue(viewModel.hasActiveFilters)
    }

    func test_hasActiveFilters_withSortOrder_returnsTrue() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.sortOrder = .publisher
        XCTAssertTrue(viewModel.hasActiveFilters)
    }

    func test_filteredPluginCount_returnsCorrectCount() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        viewModel.selectedFormat = "VST3"

        XCTAssertEqual(viewModel.filteredPluginCount, 2)
    }

    func test_totalPluginCount_returnsCorrectCount() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())
        XCTAssertEqual(viewModel.totalPluginCount, 5)
    }

    func test_sortOrderBadge_returnsRawValue() {
        let viewModel = PluginListViewModel(plugins: createSamplePlugins())

        viewModel.sortOrder = .name
        XCTAssertEqual(viewModel.sortOrderBadge, "Name")

        viewModel.sortOrder = .publisher
        XCTAssertEqual(viewModel.sortOrderBadge, "Publisher")

        viewModel.sortOrder = .type
        XCTAssertEqual(viewModel.sortOrderBadge, "Type")

        viewModel.sortOrder = .style
        XCTAssertEqual(viewModel.sortOrderBadge, "Style")
    }

    // MARK: - Edge Cases Tests

    func test_emptyPluginList_handlesGracefully() {
        let viewModel = PluginListViewModel(plugins: [])

        XCTAssertEqual(viewModel.filteredAndSortedPlugins.count, 0)
        XCTAssertEqual(viewModel.consolidatedPlugins.count, 0)
        XCTAssertEqual(viewModel.uniquePublishers.count, 0)
        XCTAssertEqual(viewModel.uniqueFormats.count, 0)
        XCTAssertEqual(viewModel.uniqueStyles.count, 0)
    }

    func test_largePluginList_handlesCorrectly() {
        let plugins = (0..<1000).map { i in
            PluginItem(
                name: "Plugin \(i)",
                publisher: "Publisher \(i % 10)",
                type: ["VST", "AU", "VST3"][i % 3],
                style: "Style \(i % 5)"
            )
        }
        let viewModel = PluginListViewModel(plugins: plugins)

        XCTAssertEqual(viewModel.totalPluginCount, 1000)
        XCTAssertEqual(viewModel.filteredPluginCount, 1000)
    }

    func test_specialCharacters_inSearchText_handlesCorrectly() {
        let plugins = [
            PluginItem(name: "Test & Company's Plugin", publisher: "Test", type: "VST")
        ]
        let viewModel = PluginListViewModel(plugins: plugins)

        viewModel.searchText = "&"
        XCTAssertEqual(viewModel.filteredAndSortedPlugins.count, 1)

        viewModel.searchText = "'"
        XCTAssertEqual(viewModel.filteredAndSortedPlugins.count, 1)
    }
}
