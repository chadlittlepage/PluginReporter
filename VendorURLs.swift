//
//  VendorURLs.swift
//  PluginReporter
//
//  Lightweight vendor website URL database
//

import Foundation

/// Simple vendor URL lookup - no dependencies, no bloat
struct VendorURLs {
    /// Vendor detection patterns mapped to their websites
    /// Format: ["vendor pattern": "website URL"]
    private static let vendorMap: [String: String] = [
        // Major Vendors (A-Z)
        "antares": "https://www.antarestech.com",
        "apple": "https://www.apple.com",
        "arturia": "https://www.arturia.com",
        "audiothing": "https://www.audiothing.net",
        "audio thing": "https://www.audiothing.net",
        "celemony": "https://www.celemony.com",
        "melodyne": "https://www.celemony.com",
        "eventide": "https://www.eventideaudio.com",
        "fabfilter": "https://www.fabfilter.com",
        "ik multimedia": "https://www.ikmultimedia.com",
        "izotope": "https://www.izotope.com",
        "liquidsonics": "https://www.liquidsonics.com",
        "liquid sonics": "https://www.liquidsonics.com",
        "melda": "https://www.meldaproduction.com",
        "meldaproduction": "https://www.meldaproduction.com",
        "native instruments": "https://www.native-instruments.com",
        "plugin alliance": "https://www.plugin-alliance.com",
        "plugin-alliance": "https://www.plugin-alliance.com",
        "brainworx": "https://www.plugin-alliance.com",
        "slate digital": "https://www.slatedigital.com",
        "steven slate": "https://www.slatedigital.com",
        "sonible": "https://www.sonible.com",
        "soundtoys": "https://www.soundtoys.com",
        "surge": "https://surge-synthesizer.github.io",
        "surge-synthesizer": "https://surge-synthesizer.github.io",
        "tal": "https://tal-software.com",
        "tal-": "https://tal-software.com",
        "togu audio line": "https://tal-software.com",
        "tc electronic": "https://www.tcelectronic.com",
        "tc-electronic": "https://www.tcelectronic.com",
        "clarity m": "https://www.tcelectronic.com",
        "tokyo dawn": "https://www.tokyodawn.net",
        "tdr": "https://www.tokyodawn.net",
        "u-he": "https://u-he.com",
        "urs": "https://u-he.com",
        "universal audio": "https://www.uaudio.com",
        "uad": "https://www.uaudio.com",
        "valhalla": "https://valhalladsp.com",
        "vital": "https://vital.audio",
        "matt tytel": "https://vital.audio",
        "voxengo": "https://www.voxengo.com",
        "waves": "https://www.waves.com",
        "xfer": "https://xferrecords.com",
        "serum": "https://xferrecords.com",

        // Additional vendors
        "dexed": "https://asb2m10.github.io/dexed",
        "digital suburban": "https://asb2m10.github.io/dexed",
        "auto-tune": "https://www.antarestech.com"
    ]

    /// Get website URL for a publisher name
    static func getWebsiteURL(for publisher: String) -> String? {
        let publisherLower = publisher.lowercased()

        // Try exact match first
        if let url = vendorMap[publisherLower] {
            return url
        }

        // Try pattern matching (contains)
        for (pattern, url) in vendorMap {
            if publisherLower.contains(pattern) || pattern.contains(publisherLower) {
                return url
            }
        }

        return nil
    }

    /// Generate fallback URL if no vendor match found
    static func generateFallbackURL(for publisher: String) -> String {
        let clean = publisher.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "inc", with: "")
            .replacingOccurrences(of: "llc", with: "")
            .replacingOccurrences(of: "gmbh", with: "")

        return "https://\(clean).com"
    }
}
