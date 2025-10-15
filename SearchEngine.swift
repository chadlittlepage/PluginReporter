import Foundation

/// High-performance search and filter engine for plugin collections
///
/// Provides optimized filtering with support for:
/// - Free-text search across name, publisher, and style
/// - Field-specific search (type:VST, pub:Waves, etc.)
/// - Format filtering with intelligent type detection
/// - Negation support (!keyword)
/// - Concurrent filtering for large datasets (>1000 items)
enum SearchEngine {
    /// Filters plugin items based on search query and active filters
    ///
    /// - Parameters:
    ///   - items: Array of plugins to filter
    ///   - queryRaw: Search query string (supports field prefixes and negation)
    ///   - selectedFormats: Set of plugin formats to include
    ///   - selectedPublishers: Set of publishers to include
    ///   - selectedStyles: Set of styles to include
    /// - Returns: Filtered array of plugins matching all criteria
    static func filter(items: [PluginItem], queryRaw: String, selectedFormats: Set<PluginFormat>, selectedPublishers: Set<String>, selectedStyles: Set<String>) -> [PluginItem] {

        // Fast pre-filter by format and publisher using lazy evaluation
        let formatFiltered = selectedFormats.isEmpty ? items :
            items.lazy.compactMap { item -> PluginItem? in
                // Special handling for OBSLT - filter by obsolete flag
                if selectedFormats.contains(.OBSLT) {
                    // If OBSLT is the only selection, return only obsolete plugins
                    if selectedFormats.count == 1 {
                        return item.obsolete ? item : nil
                    }
                    // If OBSLT is combined with other formats, include obsolete OR matching format
                    let otherFormats = selectedFormats.filter { $0 != .OBSLT }
                    if item.obsolete {
                        return item
                    }
                    guard let format = PluginFormat(rawValue: item.type) else { return nil }
                    return otherFormats.contains(format) ? item : nil
                } else {
                    // Standard format filtering
                    guard let format = PluginFormat(rawValue: item.type) else { return nil }
                    return selectedFormats.contains(format) ? item : nil
                }
            }

        let publisherFiltered = selectedPublishers.isEmpty ? Array(formatFiltered) :
            formatFiltered.compactMap { item in
                selectedPublishers.contains(item.publisher) ? item : nil
            }

        let styleFiltered = selectedStyles.isEmpty ? publisherFiltered :
            publisherFiltered.compactMap { item in
                selectedStyles.contains(item.style) ? item : nil
            }

        let query = queryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return styleFiltered }

        // Pre-compile query tokens for better performance
        let tokens = parseQueryTokens(query)
        guard !tokens.isEmpty else { return styleFiltered }

        // Use parallel filtering for large datasets
        if styleFiltered.count > 1000 {
            return styleFiltered.concurrentFilter { item in
                tokens.allSatisfy { token in
                    matchesToken(item: item, token: token)
                }
            }
        } else {
            return styleFiltered.filter { item in
                tokens.allSatisfy { token in
                    matchesToken(item: item, token: token)
                }
            }
        }
    }

    /// Represents a parsed search token with field specifier and negation support
    private struct QueryToken {
        let isNegated: Bool
        let field: String?
        let value: String
        let lowercasedValue: String
        
        init(raw: String) {
            self.isNegated = raw.hasPrefix("!")
            let cleanRaw = isNegated ? String(raw.dropFirst()) : raw
            
            if let colonIndex = cleanRaw.firstIndex(of: ":") {
                self.field = String(cleanRaw[..<colonIndex])
                self.value = String(cleanRaw[cleanRaw.index(after: colonIndex)...])
            } else {
                self.field = nil
                self.value = cleanRaw
            }
            
            self.lowercasedValue = value.lowercased()
        }
    }
    
    private static func parseQueryTokens(_ query: String) -> [QueryToken] {
        return query.split(separator: " ").map { QueryToken(raw: String($0)) }
    }
    
    private static func matchesToken(item: PluginItem, token: QueryToken) -> Bool {
        let matched: Bool

        if let field = token.field {
            switch field {
            case "type":
                matched = item.type.lowercased().contains(token.lowercasedValue)
            case "pub":
                matched = item.publisher.lowercased().contains(token.lowercasedValue)
            case "arch":
                matched = item.architectures.lowercased().contains(token.lowercasedValue)
            case "req":
                matched = item.runtimeRequirement.lowercased().contains(token.lowercasedValue)
            case "path":
                matched = item.path.lowercased().contains(token.lowercasedValue)
            case "obsolete":
                let boolValue = ["true", "yes", "1"].contains(token.lowercasedValue)
                matched = item.obsolete == boolValue
            default:
                matched = false
            }
        } else {
            // INTELLIGENT FORMAT DETECTION - recognizes plugin type keywords
            let uppercasedQuery = token.value.uppercased()

            // Check if query is an exact format type match (AU, VST, VST3, AAX, CLAP, LV2)
            if isPluginFormat(uppercasedQuery) {
                // EXACT format match - only return plugins of this exact type
                matched = item.type.uppercased() == uppercasedQuery
            } else {
                // Free-text search - search in name, publisher, and style
                let lowercasedQuery = token.lowercasedValue
                matched = item.name.lowercased().contains(lowercasedQuery) ||
                         item.publisher.lowercased().contains(lowercasedQuery) ||
                         item.style.lowercased().contains(lowercasedQuery)
            }
        }

        return token.isNegated ? !matched : matched
    }

    /// Checks if a string matches a known plugin format type
    ///
    /// - Parameter str: String to check
    /// - Returns: true if the string is a recognized plugin format (AU, VST, VST3, AAX, CLAP, LV2, OBSLT)
    private static func isPluginFormat(_ str: String) -> Bool {
        let knownFormats = ["AU", "VST", "VST3", "AAX", "CLAP", "LV2", "OBSLT"]
        return knownFormats.contains(str.uppercased())
    }
}

// MARK: - Performance Extensions

extension Array {
    func concurrentFilter(_ isIncluded: @escaping (Element) -> Bool) -> [Element] {
        let result = ThreadSafeArray<Element>()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "concurrent.filter", qos: .userInitiated, attributes: .concurrent)
        
        let chunkSize = Swift.max(1, count / ProcessInfo.processInfo.activeProcessorCount)
        
        for chunk in chunked(into: chunkSize) {
            group.enter()
            queue.async {
                let filtered = chunk.filter(isIncluded)
                result.append(contentsOf: filtered)
                group.leave()
            }
        }
        
        group.wait()
        return result.elements
    }
    
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private class ThreadSafeArray<Element> {
    private var _elements: [Element] = []
    private let queue = DispatchQueue(label: "threadsafe.array", attributes: .concurrent)
    
    func append(contentsOf elements: [Element]) {
        queue.async(flags: .barrier) {
            self._elements.append(contentsOf: elements)
        }
    }
    
    var elements: [Element] {
        return queue.sync {
            return _elements
        }
    }
}
