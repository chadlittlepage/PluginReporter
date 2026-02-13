//
//  PaginationManager.swift
//  Plugin Reporter
//
//  Manages pagination for large plugin lists (10,000+ items)
//  Provides efficient memory usage and smooth scrolling
//

import Foundation
import Combine

/// Manages pagination state and logic for large datasets
@MainActor
class PaginationManager<Item: Identifiable>: ObservableObject {
    // MARK: - Published Properties

    /// Current page number (0-indexed)
    @Published var currentPage: Int = 0

    /// Number of items per page (Int.max = infinity/show all)
    @Published var pageSize: Int = Int.max

    /// Total number of items across all pages
    @Published var totalItems: Int = 0

    /// Whether pagination is enabled (auto-disabled for small datasets)
    @Published var isEnabled: Bool = false

    // MARK: - Configuration

    /// Threshold for enabling pagination (items count)
    let paginationThreshold: Int

    /// Available page size options (Int.max represents infinity/show all)
    let pageSizeOptions: [Int] = [100, 250, 500, 1000, 2500, 5000, Int.max]

    // MARK: - Private Storage

    /// Full dataset (not displayed directly)
    private var allItems: [Item] = []

    /// Cache of computed pages to avoid re-slicing
    private var pageCache: [Int: [Item]] = [:]

    // MARK: - Initialization

    init(threshold: Int = 1000, defaultPageSize: Int = Int.max) {
        self.paginationThreshold = threshold

        // Load saved page size from UserDefaults, or use default
        let savedPageSize = UserDefaults.standard.integer(forKey: "paginationPageSize")
        if savedPageSize > 0 {
            self.pageSize = savedPageSize
        } else if UserDefaults.standard.object(forKey: "paginationPageSizeIsMax") as? Bool == true {
            self.pageSize = Int.max
        } else {
            self.pageSize = defaultPageSize
        }

        // Save page size whenever it changes
        setupPersistence()
    }

    private func setupPersistence() {
        // Save pageSize to UserDefaults whenever it changes
        // Note: We can't use Combine here because this is a generic class,
        // so we'll save in setPageSize() instead
    }

    // MARK: - Computed Properties

    /// Total number of pages
    var totalPages: Int {
        guard totalItems > 0, pageSize > 0 else { return 0 }
        return Int(ceil(Double(totalItems) / Double(pageSize)))
    }

    /// Range of items on current page (for display)
    var currentPageRange: String {
        guard totalItems > 0 else { return "0 of 0" }
        let start = currentPage * pageSize + 1
        let end = min((currentPage + 1) * pageSize, totalItems)
        return "\(start)-\(end) of \(totalItems)"
    }

    /// Can navigate to previous page
    var canGoPrevious: Bool {
        currentPage > 0
    }

    /// Can navigate to next page
    var canGoNext: Bool {
        currentPage < totalPages - 1
    }

    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(max(1, totalPages - 1))
    }

    // MARK: - Data Management

    /// Update the full dataset and reset to first page
    /// - Parameter items: Complete array of items to paginate
    func updateItems(_ items: [Item]) {
        self.allItems = items
        self.totalItems = items.count
        self.isEnabled = items.count > paginationThreshold

        // Clear cache when data changes
        pageCache.removeAll()

        // Reset to first page if current page is out of bounds
        if currentPage >= totalPages {
            currentPage = max(0, totalPages - 1)
        }

        AppLogger.debug("Pagination: Updated with \(items.count) items, enabled: \(isEnabled)")
    }

    /// Get items for the current page
    /// - Returns: Sliced array of items for current page
    func getCurrentPage() -> [Item] {
        guard isEnabled else { return allItems }

        // Check cache first
        if let cached = pageCache[currentPage] {
            return cached
        }

        // Compute page slice
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, allItems.count)

        guard startIndex < allItems.count else { return [] }

        let page = Array(allItems[startIndex..<endIndex])

        // Cache for future use
        pageCache[currentPage] = page

        return page
    }

    /// Get items for a specific page (without changing current page)
    /// - Parameter page: Page number to retrieve
    /// - Returns: Items for that page
    func getPage(_ page: Int) -> [Item] {
        guard page >= 0 && page < totalPages else { return [] }

        if let cached = pageCache[page] {
            return cached
        }

        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, allItems.count)

        guard startIndex < allItems.count else { return [] }

        let items = Array(allItems[startIndex..<endIndex])
        pageCache[page] = items

        return items
    }

    // MARK: - Navigation

    /// Go to next page
    func nextPage() {
        guard canGoNext else { return }
        currentPage += 1
        AppLogger.debug("Pagination: Next page -> \(currentPage + 1)/\(totalPages)")
    }

    /// Go to previous page
    func previousPage() {
        guard canGoPrevious else { return }
        currentPage -= 1
        AppLogger.debug("Pagination: Previous page -> \(currentPage + 1)/\(totalPages)")
    }

    /// Go to first page
    func firstPage() {
        currentPage = 0
        AppLogger.debug("Pagination: First page")
    }

    /// Go to last page
    func lastPage() {
        currentPage = max(0, totalPages - 1)
        AppLogger.debug("Pagination: Last page -> \(totalPages)")
    }

    /// Jump to specific page
    /// - Parameter page: Target page number (0-indexed)
    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        currentPage = page
        AppLogger.debug("Pagination: Jump to page \(page + 1)/\(totalPages)")
    }

    /// Change page size and adjust current page to maintain approximate position
    /// - Parameter newSize: New page size
    func setPageSize(_ newSize: Int) {
        guard newSize > 0 else { return }

        // Calculate approximate current position in dataset
        let currentPosition = currentPage * pageSize

        // Update page size
        pageSize = newSize

        // Save to UserDefaults
        if newSize == Int.max {
            UserDefaults.standard.set(true, forKey: "paginationPageSizeIsMax")
            UserDefaults.standard.removeObject(forKey: "paginationPageSize")
        } else {
            UserDefaults.standard.set(newSize, forKey: "paginationPageSize")
            UserDefaults.standard.removeObject(forKey: "paginationPageSizeIsMax")
        }

        // Clear cache since page boundaries changed
        pageCache.removeAll()

        // Adjust current page to maintain approximate position
        currentPage = currentPosition / pageSize
        currentPage = min(currentPage, max(0, totalPages - 1))

        AppLogger.debug("Pagination: Page size -> \(newSize), adjusted to page \(currentPage + 1)")
    }

    // MARK: - Search & Filter Support

    /// Find page containing a specific item
    /// - Parameter item: Item to locate
    /// - Returns: Page number containing the item, or nil if not found
    func findPage(containing item: Item) -> Int? {
        guard let index = allItems.firstIndex(where: { $0.id == item.id }) else {
            return nil
        }
        return index / pageSize
    }

    /// Navigate to page containing specific item
    /// - Parameter item: Item to locate and navigate to
    /// - Returns: True if item was found and navigation succeeded
    @discardableResult
    func navigateTo(item: Item) -> Bool {
        guard let page = findPage(containing: item) else {
            return false
        }
        goToPage(page)
        return true
    }

    // MARK: - Performance Metrics

    /// Get memory usage estimate
    var estimatedMemoryUsage: String {
        let itemSize = MemoryLayout<Item>.size
        let totalMemory = allItems.count * itemSize
        let pageMemory = pageCache.values.reduce(0) { $0 + $1.count * itemSize }

        return "Total: \(ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)), " +
               "Cached: \(ByteCountFormatter.string(fromByteCount: Int64(pageMemory), countStyle: .memory))"
    }

    /// Clear page cache to free memory
    func clearCache() {
        pageCache.removeAll()
        AppLogger.debug("Pagination: Cache cleared")
    }

    /// Preload adjacent pages for smoother navigation
    func preloadAdjacentPages() {
        guard isEnabled else { return }

        // Preload next page
        if canGoNext {
            _ = getPage(currentPage + 1)
        }

        // Preload previous page
        if canGoPrevious {
            _ = getPage(currentPage - 1)
        }
    }
}

// MARK: - Pagination Configuration

struct PaginationConfig {
    /// Enable pagination for datasets larger than this threshold
    static let defaultThreshold = 1000

    /// Default page size
    static let defaultPageSize = 500

    /// Maximum items to display without pagination
    static let maxUnpaginatedItems = 999

    /// Preload adjacent pages for smooth scrolling
    static let preloadAdjacentPages = true
}
