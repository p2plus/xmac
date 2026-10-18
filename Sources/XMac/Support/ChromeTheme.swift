import AppKit
import SwiftUI

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Empty string lets the page keep its own scheme.
    var cssScheme: String {
        switch self {
        case .system: ""
        case .light: "light"
        case .dark: "dark"
        }
    }

    static func resolve(_ raw: String?) -> AppearanceChoice {
        raw.flatMap(AppearanceChoice.init(rawValue:)) ?? .system
    }
}

enum ChromeTheme: String, CaseIterable, Identifiable {
    case standard
    case ledger
    case graphite
    case phosphor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .ledger: "Ledger"
        case .graphite: "Graphite"
        case .phosphor: "Phosphor"
        }
    }

    var blurb: String {
        switch self {
        case .standard: "System materials"
        case .ledger: "Warm gray, one accent"
        case .graphite: "Monochrome"
        case .phosphor: "Amber on near-black"
        }
    }

    static func resolve(_ raw: String?) -> ChromeTheme {
        raw.flatMap(ChromeTheme.init(rawValue:)) ?? .standard
    }

    func canvas(dark: Bool) -> NSColor {
        switch self {
        case .standard:
            return .windowBackgroundColor
        case .ledger:
            return Self.hex(dark ? 0x201F1C : 0xEFEEE9)
        case .graphite:
            return Self.hex(dark ? 0x1C1C1C : 0xF2F2F2)
        case .phosphor:
            return Self.hex(0x0C1208)
        }
    }

    func bar(dark: Bool) -> NSColor {
        switch self {
        case .standard:
            return .windowBackgroundColor
        case .ledger:
            return Self.hex(dark ? 0x282722 : 0xF8F7F3)
        case .graphite:
            return Self.hex(dark ? 0x242424 : 0xE8E8E8)
        case .phosphor:
            return Self.hex(0x10180C)
        }
    }

    func accent(dark: Bool) -> NSColor {
        switch self {
        case .standard:
            return .controlAccentColor
        case .ledger:
            return Self.hex(dark ? 0x7E9EC7 : 0x33507A)
        case .graphite:
            return Self.hex(dark ? 0xD0D0D0 : 0x3A3A3A)
        case .phosphor:
            return Self.hex(0xC6A15A)
        }
    }

    func ink(dark: Bool) -> NSColor {
        switch self {
        case .standard:
            return .labelColor
        case .ledger:
            return Self.hex(dark ? 0xECEBE6 : 0x21211E)
        case .graphite:
            return Self.hex(dark ? 0xF0F0F0 : 0x1A1A1A)
        case .phosphor:
            return Self.hex(0xD7C48A)
        }
    }

    func underPageColor(matching appearance: NSAppearance) -> NSColor {
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return canvas(dark: dark)
    }

    private static func hex(_ value: UInt32) -> NSColor {
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

enum NavEdge: String, CaseIterable, Identifiable {
    case leading
    case trailing
    case top
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: "Left"
        case .trailing: "Right"
        case .top: "Top"
        case .bottom: "Bottom"
        }
    }

    var isVertical: Bool { self == .leading || self == .trailing }

    static func resolve(_ raw: String?) -> NavEdge {
        raw.flatMap(NavEdge.init(rawValue:)) ?? .leading
    }
}

enum RefreshChoice: Int, CaseIterable, Identifiable {
    case manual = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "1 minute"
        case .fiveMinutes: "5 minutes"
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        }
    }

    static func resolve(_ raw: Int) -> RefreshChoice {
        RefreshChoice(rawValue: raw) ?? .manual
    }
}
