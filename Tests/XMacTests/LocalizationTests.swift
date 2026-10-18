import XCTest
import XMacCore

/// The app follows the Mac language. These checks keep the seven catalogs in lockstep
/// and prove Bundle resolves each string from its `.lproj`.
final class LocalizationTests: XCTestCase {
    private let locales = ["en", "de", "fr", "es", "ja", "ko", "zh-Hans"]
    private let cjkLocales: Set<String> = ["ja", "ko", "zh-Hans"]
    private let properNames: Set<String> = ["Grok", "Ledger", "Graphite", "Phosphor"]
    private let infoKeys = [
        "CFBundleDisplayName",
        "CFBundleName",
        "NSCameraUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSHumanReadableCopyright"
    ]

    /// Cognates and product names that legitimately match the English source.
    private let mayMatchEnglish: [String: Set<String>] = [
        "de": ["Grok", "Ledger", "Graphite", "Phosphor", "OK", "Standard", "System", "Zoom", "Download", "Navigation"],
        "fr": [
            "Grok", "Ledger", "Graphite", "Phosphor", "OK", "Standard", "Navigation", "Zoom",
            "Session", "Monochrome", "Notifications", "Messages",
            "1 minute", "5 minutes", "15 minutes", "30 minutes"
        ],
        "es": ["Grok", "Ledger", "Graphite", "Phosphor", "OK", "Zoom", "Manual"],
        "ja": ["Grok", "Ledger", "Graphite", "Phosphor", "OK"],
        "ko": ["Grok", "Ledger", "Graphite", "Phosphor"],
        "zh-Hans": ["Grok", "Ledger", "Graphite", "Phosphor"]
    ]

    func testRouteTitlesStayOnCatalogKeys() {
        XCTAssertEqual(AppRoute.home.title, "Home")
        XCTAssertEqual(AppRoute.explore.title, "Explore")
        XCTAssertEqual(AppRoute.notifications.title, "Notifications")
        XCTAssertEqual(AppRoute.messages.title, "Messages")
        XCTAssertEqual(AppRoute.bookmarks.title, "Bookmarks")
        XCTAssertEqual(AppRoute.lists.title, "Lists")
        XCTAssertEqual(AppRoute.grok.title, "Grok")
        XCTAssertEqual(AppRoute.profile.title, "Profile")
        XCTAssertEqual(AppRoute.compose.title, "Post")
    }

    func testCatalogsMatchTheInterface() throws {
        let repo = repoRoot()
        let english = try load(repo.appendingPathComponent("Resources/en.lproj/Localizable.strings"))
        for (key, value) in english {
            XCTAssertEqual(value, key, "English catalog must keep the source string as the key")
            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        let used = try interfaceKeys(in: repo.appendingPathComponent("Sources"))
        XCTAssertEqual(used, Set(english.keys), "UI strings and the English catalog drifted")

        for locale in locales {
            let url = repo.appendingPathComponent("Resources/\(locale).lproj/Localizable.strings")
            let table = try load(url)
            XCTAssertEqual(Set(table.keys), Set(english.keys), "\(locale) is missing or extra keys")
            try assertNoDuplicateKeys(in: url)
            let bundle = try XCTUnwrap(Bundle(url: url.deletingLastPathComponent()))
            for (key, value) in table {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(locale) \(key)")
                XCTAssertEqual(
                    percentCount(value),
                    percentCount(english[key] ?? ""),
                    "\(locale) format tokens drifted for \(key)"
                )
                let resolved = bundle.localizedString(forKey: key, value: "MISSING", table: "Localizable")
                XCTAssertEqual(resolved, value, "\(locale) bundle lookup for \(key)")
                guard locale != "en" else { continue }
                if value == english[key] {
                    XCTAssertTrue(
                        mayMatchEnglish[locale, default: []].contains(key),
                        "\(locale) left \(key) in English"
                    )
                }
                if cjkLocales.contains(locale), !properNames.contains(key), key != "OK" {
                    XCTAssertTrue(hasTranslatedScript(value), "\(locale) \(key) has no translated script")
                }
                for snippet in ["Sign-in lives", "Don't autoplay", "Not affiliated", "Page didn't"] {
                    XCTAssertFalse(value.contains(snippet), "\(locale) still has English in \(key)")
                }
            }
        }
    }

    func testInfoPlistCatalogs() throws {
        let repo = repoRoot()
        let build = try String(contentsOf: repo.appendingPathComponent("build.sh"), encoding: .utf8)
        let english = try load(repo.appendingPathComponent("Resources/en.lproj/InfoPlist.strings"))
        XCTAssertEqual(Set(english.keys), Set(infoKeys))
        for key in infoKeys {
            XCTAssertTrue(build.contains(english[key] ?? "missing"), "build.sh drifted from en InfoPlist \(key)")
        }
        for locale in locales where locale != "en" {
            XCTAssertTrue(build.contains("<string>\(locale)</string>"), "build.sh omits \(locale)")
        }

        for locale in locales {
            let url = repo.appendingPathComponent("Resources/\(locale).lproj/InfoPlist.strings")
            let table = try load(url)
            XCTAssertEqual(Set(table.keys), Set(infoKeys), locale)
            try assertNoDuplicateKeys(in: url)
            let bundle = try XCTUnwrap(Bundle(url: url.deletingLastPathComponent()))
            for key in infoKeys {
                let value = try XCTUnwrap(table[key])
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                let resolved = bundle.localizedString(forKey: key, value: "MISSING", table: "InfoPlist")
                XCTAssertEqual(resolved, value, "\(locale) \(key)")
                if locale != "en", key != "CFBundleDisplayName", key != "CFBundleName" {
                    XCTAssertNotEqual(value, english[key], "\(locale) left \(key) untranslated")
                    if cjkLocales.contains(locale) {
                        XCTAssertTrue(hasTranslatedScript(value), "\(locale) \(key)")
                    }
                } else if key == "CFBundleDisplayName" || key == "CFBundleName" {
                    XCTAssertEqual(value, "X")
                }
            }
        }
    }

    func testPackagedAppMatchesTheCatalogs() throws {
        let repo = repoRoot()
        let resources = repo.appendingPathComponent("X.app/Contents/Resources")
        let marker = resources.appendingPathComponent("de.lproj/Localizable.strings")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: marker.path), "X.app has not been packaged yet")

        let infoURL = repo.appendingPathComponent("X.app/Contents/Info.plist")
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as? [String: Any]
        let declared = Set(info?["CFBundleLocalizations"] as? [String] ?? [])
        XCTAssertEqual(declared, Set(locales))
        XCTAssertEqual(info?["CFBundleDevelopmentRegion"] as? String, "en")

        for locale in locales {
            for name in ["Localizable", "InfoPlist"] {
                let source = repo.appendingPathComponent("Resources/\(locale).lproj/\(name).strings")
                let packaged = resources.appendingPathComponent("\(locale).lproj/\(name).strings")
                XCTAssertEqual(try load(packaged), try load(source), "\(locale) \(name) was not copied into X.app")
            }
        }
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func load(_ url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: String], "\(url.lastPathComponent) is not a string table")
    }

    private func assertNoDuplicateKeys(in url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        var seen: [String] = []
        let pattern = #"(?m)^"((?:\\.|[^"\\])*)"\s*="#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
            seen.append(String(text[keyRange]))
        }
        XCTAssertEqual(seen.count, Set(seen).count, "Duplicate key in \(url.path)")
        XCTAssertGreaterThan(seen.count, 0)
    }

    private func interfaceKeys(in sources: URL) throws -> Set<String> {
        var keys: Set<String> = []
        let patterns = [
            #"String\(localized:\s*"((?:\\.|[^"\\])*)""#,
            #"(?<![A-Za-z])(?:Button|Text|Toggle|Picker|Section|Label|TextField|LabeledContent|confirmationDialog)\(\s*"((?:\\.|[^"\\])*)""#,
            #"\.help\(\s*"((?:\\.|[^"\\])*)""#,
            #"help:\s*"((?:\\.|[^"\\])*)""#
        ]
        let regexes = try patterns.map { try NSRegularExpression(pattern: $0) }
        let files = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
        for relative in files where relative.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(relative), encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for regex in regexes {
                for match in regex.matches(in: text, range: range) {
                    guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
                    let key = String(text[keyRange])
                    if key.contains("\\(") { continue }
                    keys.insert(key)
                }
            }
        }
        return keys
    }

    private func percentCount(_ value: String) -> Int {
        value.filter { $0 == "%" }.count
    }

    private func hasTranslatedScript(_ value: String) -> Bool {
        value.unicodeScalars.contains { $0.value > 0x24F }
    }
}
