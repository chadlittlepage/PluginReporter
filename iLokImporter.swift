//
//  iLokImporter.swift
//  Plugin Reporter
//
//  iLok License Manager CSV import functionality
//

import Foundation

struct iLokLicense {
    let productName: String
    let publisher: String
    let serialNumber: String?
    let location: String? // "Local Computer", "iLok", "iLok Cloud"
    let licenseType: String?
    let quantity: Int?
    let version: String?
    let expirationDate: Date?

    // Additional CSV fields
    let validLocations: String?
    let activations: String? // e.g., "0 of 3 activations used"
    let licenseStatus: String? // e.g., "Active", "Expired"
    let activationLocation: String?
    let subtype: String?
    let depositDate: String?
    let licensePeriod: String?
    let launchCount: String?
    let owner: String?
    let activateByDate: String?
    let groupName: String?
    let allocatedSeats: String?
    let totalSeats: String?
    let activationStatus: String?
    let publisherLicenseID: String?

    var pluginID: String {
        // Generate plugin ID locally to avoid main actor issues
        "\(publisher.lowercased())_\(productName.lowercased())"
            .replacingOccurrences(of: " ", with: "_")
    }
}

struct iLokImportResult {
    let totalLicenses: Int
    let matchedPlugins: Int
    let unmatchedLicenses: [iLokLicense]
    let importedLicenses: [iLokLicense]
    let errors: [String]
}

@MainActor
class iLokImporter {

    // Common column name variations in iLok CSV exports
    private enum ColumnName {
        static let productName = ["Product Name", "Product", "Name", "License Name", "License", "Asset Name", "Asset"]
        static let publisher = ["Publisher", "Manufacturer", "Vendor", "Company", "Developer", "Publisher Name"]
        static let serialNumber = ["Serial Number", "Serial", "License Key", "Key", "Activation Code", "Code", "Publisher License ID"]
        static let location = ["Location", "Where", "Activation", "Deposited To"]
        static let licenseType = ["License Type", "Type", "Asset Type"]
        static let quantity = ["Quantity", "Count", "Qty", "Licenses"]
        static let version = ["Version", "Ver", "Software Version"]
        static let expiration = ["Expiration", "Expiration Date", "Expires", "Valid Until"]

        // Additional iLok CSV columns
        static let validLocations = ["Valid Locations"]
        static let activations = ["Activations"]
        static let licenseStatus = ["License Status", "Status"]
        static let activationLocation = ["Activation Location"]
        static let subtype = ["Subtype"]
        static let depositDate = ["Deposit Date"]
        static let licensePeriod = ["License Period"]
        static let launchCount = ["Launch Count"]
        static let owner = ["Owner"]
        static let activateByDate = ["Activate By Date"]
        static let groupName = ["Group Name"]
        static let allocatedSeats = ["Allocated Seats"]
        static let totalSeats = ["Total Seats"]
        static let activationStatus = ["Activation Status"]
        static let publisherLicenseID = ["Publisher License ID"]
    }

    /// Import iLok licenses from CSV file and match to existing plugins
    static func importFromCSV(
        url: URL, plugins: [ScannerPluginItem], autoMatch: Bool = true
    ) async throws -> iLokImportResult {

        // Read CSV file
        let csvContent = try String(contentsOf: url, encoding: .utf8)

        // Parse CSV
        let iLokLicenses = try parseCSV(csvContent)

        guard !iLokLicenses.isEmpty else {
            return iLokImportResult(
                totalLicenses: 0, matchedPlugins: 0, unmatchedLicenses: [], importedLicenses: [], errors: ["No licenses found in CSV file"]
            )
        }

        var importedLicenses: [iLokLicense] = []
        var unmatchedLicenses: [iLokLicense] = []
        var matchedCount = 0
        let errors: [String] = []

        if autoMatch {
            // Try to match iLok licenses to existing plugins
            for iLokLicense in iLokLicenses {
                if let matchedPlugin = findMatchingPlugin(
                    iLokLicense: iLokLicense, plugins: plugins
                ) {
                    // Convert iLok license to PluginLicense and save
                    let pluginLicense = convertToPluginLicense(
                        iLokLicense: iLokLicense, plugin: matchedPlugin
                    )

                    // Merge with existing license data if present
                    let existingLicense = LicenseManager.shared.getLicense(
                        for: pluginLicense.pluginID
                    )
                    let mergedLicense = mergeLicenses(
                        existing: existingLicense, imported: pluginLicense
                    )

                    LicenseManager.shared.setLicense(mergedLicense)
                    importedLicenses.append(iLokLicense)
                    matchedCount += 1
                } else {
                    unmatchedLicenses.append(iLokLicense)
                }
            }
        } else {
            unmatchedLicenses = iLokLicenses
        }

        return iLokImportResult(
            totalLicenses: iLokLicenses.count, matchedPlugins: matchedCount, unmatchedLicenses: unmatchedLicenses, importedLicenses: importedLicenses, errors: errors
        )
    }

    /// Parse CSV content into iLok licenses
    private static func parseCSV(_ content: String) throws -> [iLokLicense] {
        var licenses: [iLokLicense] = []

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            throw ImportError.invalidCSVFormat("CSV file is empty or has no header row")
        }

        // Detect delimiter (comma, tab, or semicolon)
        let delimiter = detectDelimiter(in: lines)
        print("📊 Detected delimiter: \(delimiter == "," ? "comma" : delimiter == "\t" ? "tab" : "semicolon")")

        // Find the actual header row (skip title/metadata rows)
        var headerLineIndex = 0
        var headers: [String] = []

        for (index, line) in lines.enumerated() {
            let potentialHeaders = parseCSVLine(line, delimiter: delimiter)

            // Skip lines with very few columns (likely title rows)
            guard potentialHeaders.count > 3 else { continue }

            // Check if this line looks like column headers by looking for known column names
            let looksLikeHeader = potentialHeaders.contains { header in
                let normalized = header.lowercased().trimmingCharacters(in: .whitespaces)
                return ColumnName.productName.contains { $0.lowercased() == normalized } ||
                       ColumnName.publisher.contains { $0.lowercased() == normalized } ||
                       normalized.contains("product") ||
                       normalized.contains("license") ||
                       normalized.contains("publisher") ||
                       normalized.contains("manufacturer")
            }

            if looksLikeHeader {
                headerLineIndex = index
                headers = potentialHeaders
                print("📋 Found headers at line \(index + 1): \(headers.prefix(5).joined(separator: ", "))...")
                break
            }
        }

        guard !headers.isEmpty else {
            throw ImportError.invalidCSVFormat("Could not find column headers in CSV file")
        }

        // Find column indices for known fields
        let productNameIndex = findColumnIndex(in: headers, matching: ColumnName.productName)
        let publisherIndex = findColumnIndex(in: headers, matching: ColumnName.publisher)
        let serialNumberIndex = findColumnIndex(in: headers, matching: ColumnName.serialNumber)
        let locationIndex = findColumnIndex(in: headers, matching: ColumnName.location)
        let licenseTypeIndex = findColumnIndex(in: headers, matching: ColumnName.licenseType)
        let quantityIndex = findColumnIndex(in: headers, matching: ColumnName.quantity)
        let versionIndex = findColumnIndex(in: headers, matching: ColumnName.version)
        let expirationIndex = findColumnIndex(in: headers, matching: ColumnName.expiration)

        // Additional CSV column indices
        let validLocationsIndex = findColumnIndex(in: headers, matching: ColumnName.validLocations)
        let activationsIndex = findColumnIndex(in: headers, matching: ColumnName.activations)
        let licenseStatusIndex = findColumnIndex(in: headers, matching: ColumnName.licenseStatus)
        let activationLocationIndex = findColumnIndex(in: headers, matching: ColumnName.activationLocation)
        let subtypeIndex = findColumnIndex(in: headers, matching: ColumnName.subtype)
        let depositDateIndex = findColumnIndex(in: headers, matching: ColumnName.depositDate)
        let licensePeriodIndex = findColumnIndex(in: headers, matching: ColumnName.licensePeriod)
        let launchCountIndex = findColumnIndex(in: headers, matching: ColumnName.launchCount)
        let ownerIndex = findColumnIndex(in: headers, matching: ColumnName.owner)
        let activateByDateIndex = findColumnIndex(in: headers, matching: ColumnName.activateByDate)
        let groupNameIndex = findColumnIndex(in: headers, matching: ColumnName.groupName)
        let allocatedSeatsIndex = findColumnIndex(in: headers, matching: ColumnName.allocatedSeats)
        let totalSeatsIndex = findColumnIndex(in: headers, matching: ColumnName.totalSeats)
        let activationStatusIndex = findColumnIndex(in: headers, matching: ColumnName.activationStatus)
        let publisherLicenseIDIndex = findColumnIndex(in: headers, matching: ColumnName.publisherLicenseID)

        guard let productNameIndex = productNameIndex else {
            let foundColumns = headers.joined(separator: ", ")
            throw ImportError.missingRequiredColumn("Product Name or similar column not found. Found columns: \(foundColumns)")
        }

        // Parse data rows (start from line after header)
        for lineIndex in (headerLineIndex + 1)..<lines.count {
            let line = lines[lineIndex]
            let columns = parseCSVLine(line, delimiter: delimiter)

            guard columns.count > productNameIndex else { continue }

            let productName = columns[productNameIndex].trimmingCharacters(in: .whitespaces)
            guard !productName.isEmpty else { continue }

            let publisher = publisherIndex.map { columns[safe: $0] ?? "" } ?? ""
            let serialNumber = serialNumberIndex.map { columns[safe: $0] } ?? nil
            let location = locationIndex.map { columns[safe: $0] } ?? nil
            let licenseType = licenseTypeIndex.map { columns[safe: $0] } ?? nil
            let quantity = quantityIndex.flatMap { Int(columns[safe: $0] ?? "") }
            let version = versionIndex.map { columns[safe: $0] } ?? nil
            let expirationDate = expirationIndex.flatMap { parseDate(columns[safe: $0] ?? "") }

            // Extract additional fields
            let validLocations = validLocationsIndex.map { columns[safe: $0] } ?? nil
            let activations = activationsIndex.map { columns[safe: $0] } ?? nil
            let licenseStatus = licenseStatusIndex.map { columns[safe: $0] } ?? nil
            let activationLocation = activationLocationIndex.map { columns[safe: $0] } ?? nil
            let subtype = subtypeIndex.map { columns[safe: $0] } ?? nil
            let depositDate = depositDateIndex.map { columns[safe: $0] } ?? nil
            let licensePeriod = licensePeriodIndex.map { columns[safe: $0] } ?? nil
            let launchCount = launchCountIndex.map { columns[safe: $0] } ?? nil
            let owner = ownerIndex.map { columns[safe: $0] } ?? nil
            let activateByDate = activateByDateIndex.map { columns[safe: $0] } ?? nil
            let groupName = groupNameIndex.map { columns[safe: $0] } ?? nil
            let allocatedSeats = allocatedSeatsIndex.map { columns[safe: $0] } ?? nil
            let totalSeats = totalSeatsIndex.map { columns[safe: $0] } ?? nil
            let activationStatus = activationStatusIndex.map { columns[safe: $0] } ?? nil
            let publisherLicenseID = publisherLicenseIDIndex.map { columns[safe: $0] } ?? nil

            let license = iLokLicense(
                productName: productName, publisher: publisher, serialNumber: serialNumber?.isEmpty == false ? serialNumber : nil, location: location?.isEmpty == false ? location : nil, licenseType: licenseType?.isEmpty == false ? licenseType : nil, quantity: quantity, version: version?.isEmpty == false ? version : nil, expirationDate: expirationDate, validLocations: validLocations?.isEmpty == false ? validLocations : nil, activations: activations?.isEmpty == false ? activations : nil, licenseStatus: licenseStatus?.isEmpty == false ? licenseStatus : nil, activationLocation: activationLocation?.isEmpty == false ? activationLocation : nil, subtype: subtype?.isEmpty == false ? subtype : nil, depositDate: depositDate?.isEmpty == false ? depositDate : nil, licensePeriod: licensePeriod?.isEmpty == false ? licensePeriod : nil, launchCount: launchCount?.isEmpty == false ? launchCount : nil, owner: owner?.isEmpty == false ? owner : nil, activateByDate: activateByDate?.isEmpty == false ? activateByDate : nil, groupName: groupName?.isEmpty == false ? groupName : nil, allocatedSeats: allocatedSeats?.isEmpty == false ? allocatedSeats : nil, totalSeats: totalSeats?.isEmpty == false ? totalSeats : nil, activationStatus: activationStatus?.isEmpty == false ? activationStatus : nil, publisherLicenseID: publisherLicenseID?.isEmpty == false ? publisherLicenseID : nil
            )

            licenses.append(license)
        }

        return licenses
    }

    /// Detect the delimiter used in the CSV file
    private static func detectDelimiter(in lines: [String]) -> String {
        // Try to detect delimiter from first few lines
        let sampleLines = Array(lines.prefix(5))

        var delimiterScores: [String: Int] = [",": 0, "\t": 0, ";": 0]

        for line in sampleLines {
            let commaCount = line.filter { $0 == "," }.count
            let tabCount = line.filter { $0 == "\t" }.count
            let semicolonCount = line.filter { $0 == ";" }.count

            delimiterScores[",", default: 0] += commaCount
            delimiterScores["\t", default: 0] += tabCount
            delimiterScores[";", default: 0] += semicolonCount
        }

        // Return the delimiter with the highest count
        let bestDelimiter = delimiterScores.max(by: { $0.value < $1.value })?.key ?? ","
        return bestDelimiter
    }

    /// Parse a single CSV line, handling quoted fields
    private static func parseCSVLine(_ line: String, delimiter: String = ",") -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var index = line.startIndex

        let delimiterChar = delimiter.first ?? ","

        while index < line.endIndex {
            let char = line[index]

            if char == "\"" {
                insideQuotes.toggle()
            } else if char == delimiterChar && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }

            index = line.index(after: index)
        }

        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    /// Find column index by matching against known column name variations
    private static func findColumnIndex(in headers: [String], matching variations: [String]) -> Int? {
        for (index, header) in headers.enumerated() {
            let normalizedHeader = header.trimmingCharacters(in: .whitespaces)
                .lowercased()

            for variation in variations {
                if normalizedHeader == variation.lowercased() {
                    return index
                }
            }
        }
        return nil
    }

    /// Parse date string from various formats
    private static func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let formatters = [
            "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "M/d/yyyy", "d/M/yyyy"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    /// Find matching plugin for an iLok license
    private static func findMatchingPlugin(
        iLokLicense: iLokLicense, plugins: [ScannerPluginItem]
    ) -> ScannerPluginItem? {

        // Exact match by name and publisher
        if let match = plugins.first(where: {
            $0.name.lowercased() == iLokLicense.productName.lowercased() &&
            $0.publisher.lowercased() == iLokLicense.publisher.lowercased()
        }) {
            return match
        }

        // Match by name only (case-insensitive)
        if let match = plugins.first(where: {
            $0.name.lowercased() == iLokLicense.productName.lowercased()
        }) {
            return match
        }

        // Fuzzy match by name (contains)
        if let match = plugins.first(where: {
            $0.name.lowercased().contains(iLokLicense.productName.lowercased()) ||
            iLokLicense.productName.lowercased().contains($0.name.lowercased())
        }) {
            return match
        }

        return nil
    }

    /// Convert iLok license to PluginLicense
    private static func convertToPluginLicense(
        iLokLicense: iLokLicense, plugin: ScannerPluginItem
    ) -> PluginLicense {
        // Generate plugin ID locally to avoid main actor issues
        let pluginID = "\(plugin.publisher.lowercased())_\(plugin.name.lowercased())"
            .replacingOccurrences(of: " ", with: "_")

        // Build comprehensive notes from all iLok CSV fields
        var notes = ""

        if let validLocations = iLokLicense.validLocations {
            notes += "Valid Locations: \(validLocations)\n"
        }
        if let activations = iLokLicense.activations {
            notes += "Activations: \(activations)\n"
        }
        if let licenseStatus = iLokLicense.licenseStatus {
            notes += "License Status: \(licenseStatus)\n"
        }
        if let location = iLokLicense.location {
            notes += "Location: \(location)\n"
        }
        if let licenseType = iLokLicense.licenseType {
            notes += "Type: \(licenseType)\n"
        }
        if let activationLocation = iLokLicense.activationLocation {
            notes += "Activation Location: \(activationLocation)\n"
        }
        if let subtype = iLokLicense.subtype {
            notes += "Subtype: \(subtype)\n"
        }
        if let depositDate = iLokLicense.depositDate {
            notes += "Deposit Date: \(depositDate)\n"
        }
        if let licensePeriod = iLokLicense.licensePeriod {
            notes += "License Period: \(licensePeriod)\n"
        }
        if let launchCount = iLokLicense.launchCount {
            notes += "Launch Count: \(launchCount)\n"
        }
        if let owner = iLokLicense.owner {
            notes += "Owner: \(owner)\n"
        }
        if let activateByDate = iLokLicense.activateByDate {
            notes += "Activate By Date: \(activateByDate)\n"
        }
        if let groupName = iLokLicense.groupName {
            notes += "Group Name: \(groupName)\n"
        }
        if let allocatedSeats = iLokLicense.allocatedSeats {
            notes += "Allocated Seats: \(allocatedSeats)\n"
        }
        if let totalSeats = iLokLicense.totalSeats {
            notes += "Total Seats: \(totalSeats)\n"
        }
        if let activationStatus = iLokLicense.activationStatus {
            notes += "Activation Status: \(activationStatus)\n"
        }
        if let publisherLicenseID = iLokLicense.publisherLicenseID {
            notes += "Publisher License ID: \(publisherLicenseID)\n"
        }

        notes += "Imported from iLok License Manager"

        // Create base license with required fields
        var license = PluginLicense(
            pluginName: plugin.name, pluginID: pluginID
        )

        // Set optional fields
        license.serialNumber = iLokLicense.serialNumber
        license.notes = notes.isEmpty ? nil : notes
        license.activationsUsed = iLokLicense.quantity

        return license
    }

    /// Merge existing license with imported data (preserve existing data, add missing fields)
    private static func mergeLicenses(
        existing: PluginLicense?, imported: PluginLicense
    ) -> PluginLicense {
        guard let existing = existing else {
            return imported
        }

        var merged = existing

        // Only update if existing doesn't have the value
        if merged.serialNumber == nil {
            merged.serialNumber = imported.serialNumber
        }

        if merged.activationsUsed == nil {
            merged.activationsUsed = imported.activationsUsed
        }

        // Append notes
        if let importedNotes = imported.notes {
            if let existingNotes = merged.notes {
                merged.notes = existingNotes + "\n\n" + importedNotes
            } else {
                merged.notes = importedNotes
            }
        }

        merged.lastModified = Date()

        return merged
    }

    enum ImportError: LocalizedError {
        case invalidCSVFormat(String)
        case missingRequiredColumn(String)
        case fileReadError

        var errorDescription: String? {
            switch self {
            case .invalidCSVFormat(let message): 
                return "Invalid CSV format: \(message)"
            case .missingRequiredColumn(let column): 
                return "Missing required column: \(column)"
            case .fileReadError: 
                return "Failed to read CSV file"
            }
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}