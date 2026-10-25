import SwiftUI

/// The palette for one appearance + accent scheme. Values come from the approved
/// "orange on black" direction; light mode uses darker accents so text stays readable.
struct Palette: Equatable {
    var bg: Color
    var card: Color
    var elevated: Color
    var text: Color
    var secondary: Color
    var muted: Color
    var line: Color
    var border: Color
    var accent: Color
    var onAccent: Color
    var danger: Color
    var isDark: Bool

    var accentSoft: Color { accent.opacity(isDark ? 0.16 : 0.18) }
    var dangerSoft: Color { danger.opacity(0.16) }

    static func make(scheme: AccentScheme, dark: Bool) -> Palette {
        let accent: Color
        let onAccent: Color
        switch (scheme, dark) {
        case (.orange, true): accent = Color(hex: 0xFFB84D); onAccent = Color(hex: 0x0A0A0D)
        case (.orange, false): accent = Color(hex: 0xC77A00); onAccent = .white
        case (.mint, true): accent = Color(hex: 0x5DD68C); onAccent = Color(hex: 0x0A0A0D)
        case (.mint, false): accent = Color(hex: 0x1F9B5A); onAccent = .white
        case (.ice, true): accent = Color(hex: 0x5EB5FF); onAccent = Color(hex: 0x0A0A0D)
        case (.ice, false): accent = Color(hex: 0x1F6FD0); onAccent = .white
        case (.red, true): accent = Color(hex: 0xFF5F6D); onAccent = Color(hex: 0x0A0A0D)
        case (.red, false): accent = Color(hex: 0xC8313F); onAccent = .white
        }
        if dark {
            return Palette(bg: Color(hex: 0x0A0A0D), card: Color(hex: 0x141518), elevated: Color(hex: 0x1F2024),
                           text: Color(hex: 0xF3F4F6), secondary: Color(hex: 0xA1A3AB), muted: Color(hex: 0x8B8E97),
                           line: Color(hex: 0x26272C), border: Color(hex: 0x3A3C44), accent: accent, onAccent: onAccent,
                           danger: Color(hex: 0xFF8A94), isDark: true)
        }
        return Palette(bg: Color(hex: 0xF6F7FB), card: .white, elevated: Color(hex: 0xE6E8EF),
                       text: Color(hex: 0x10131C), secondary: Color(hex: 0x4B4F5B), muted: Color(hex: 0x6B7280),
                       line: Color(hex: 0xE3E5EC), border: Color(hex: 0xC9CCD6), accent: accent, onAccent: onAccent,
                       danger: Color(hex: 0xC8313F), isDark: false)
    }

    static func swatch(_ scheme: AccentScheme) -> Color { make(scheme: scheme, dark: true).accent }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.make(scheme: .orange, dark: true) }

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

enum Radius {
    static let card: CGFloat = 22
    static let row: CGFloat = 18
    static let field: CGFloat = 12
    static let chip: CGFloat = 10
    static let button: CGFloat = 14
}
