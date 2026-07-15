import SwiftUI

public struct WordLoopSRGB: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: UInt32) {
        red = Double((hex >> 16) & 0xff) / 255
        green = Double((hex >> 8) & 0xff) / 255
        blue = Double(hex & 0xff) / 255
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    public var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    public func contrastRatio(with other: WordLoopSRGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Returns the final sRGB value produced by drawing this color over an
    /// opaque background. Tests use the same layer order as SwiftUI views so
    /// translucent roles cannot be checked against the wrong underlay.
    public func composited(over background: WordLoopSRGB, opacity: Double) -> WordLoopSRGB {
        let alpha = min(max(opacity, 0), 1)
        return .init(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha)
        )
    }
}

public enum WordLoopLayerOpacity {
    public static let posterAccent = 0.58
    public static let modeTrack = 0.10
    public static let modeUnselectedText = 1.0
    public static let courseCardSecondaryText = 0.75
    public static let courseCardBoundary = 0.56
}

public struct PosterPalette: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let order: Int
    public let background: WordLoopSRGB
    public let ink: WordLoopSRGB
    public let accent: WordLoopSRGB

    public static let all: [PosterPalette] = [
        .init(id: "paper", order: 0, background: .init(hex: 0xf3f0e8), ink: .init(hex: 0x1e3a34), accent: .init(hex: 0xd4562b)),
        .init(id: "sun", order: 1, background: .init(hex: 0xf5d547), ink: .init(hex: 0x282044), accent: .init(hex: 0xe85b44)),
        .init(id: "sky", order: 2, background: .init(hex: 0xdfecff), ink: .init(hex: 0x183565), accent: .init(hex: 0xf06449)),
        .init(id: "rose", order: 3, background: .init(hex: 0xf8d9df), ink: .init(hex: 0x4b1934), accent: .init(hex: 0x157d6a)),
        .init(id: "mint", order: 4, background: .init(hex: 0xd8eee3), ink: .init(hex: 0x173b33), accent: .init(hex: 0xc84e34)),
        .init(id: "night", order: 5, background: .init(hex: 0x26233e), ink: .init(hex: 0xf4ead7), accent: .init(hex: 0xf3bd4f)),
    ]

    public static let defaultPalette = all[0]

    /// Accent remains the machine-truth decorative color. Small text falls
    /// back to ink when that accent cannot reach WCAG AA against the poster.
    public var accessibleAccentText: WordLoopSRGB {
        accent.contrastRatio(with: background) >= 4.5 ? accent : ink
    }

    /// Deterministically advances through the canonical order without repeating
    /// the current palette. Unknown IDs restart at the first palette.
    public static func next(after currentID: String?) -> PosterPalette {
        guard let currentID,
              let index = all.firstIndex(where: { $0.id == currentID }) else {
            return defaultPalette
        }
        return all[(index + 1) % all.count]
    }
}

public enum WordLoopSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let safe: CGFloat = 20
    public static let safeWide: CGFloat = 24
    public static let lg: CGFloat = 32
    public static let minimumHit: CGFloat = 44
}

public enum WordLoopRadius {
    public static let control: CGFloat = 8
    public static let card: CGFloat = 13
    public static let dialog: CGFloat = 16
    public static let capsule: CGFloat = 999
}

public enum WordLoopBorder {
    public static let hairline: CGFloat = 1
    public static let emphasized: CGFloat = 2
}

public struct WordLoopShadowStyle: Equatable, Sendable {
    public let colorOpacity: Double
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(colorOpacity: Double, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.colorOpacity = colorOpacity
        self.radius = radius
        self.x = x
        self.y = y
    }
}

public enum WordLoopShadow {
    public static let card = WordLoopShadowStyle(colorOpacity: 0.12, radius: 30, y: 10)
    public static let drawer = WordLoopShadowStyle(colorOpacity: 0.16, radius: 60, y: 0)
    public static let dialog = WordLoopShadowStyle(colorOpacity: 0.22, radius: 60, y: 22)
}

public struct WordLoopMotionStyle: Equatable, Sendable {
    public let duration: TimeInterval
    public let displacement: CGFloat
    public let repeats: Bool

    public init(duration: TimeInterval, displacement: CGFloat, repeats: Bool = false) {
        self.duration = duration
        self.displacement = displacement
        self.repeats = repeats
    }
}

public enum WordLoopMotion {
    public static let paletteDuration: TimeInterval = 0.420
    public static let contentEnterDuration: TimeInterval = 0.520
    public static let drawerDuration: TimeInterval = 0.260
    public static let exitDuration: TimeInterval = 0.240
    public static let waveformDuration: TimeInterval = 0.880

    public static func palette(reduceMotion: Bool) -> WordLoopMotionStyle {
        .init(duration: reduceMotion ? 0 : paletteDuration, displacement: 0)
    }

    public static func contentEnter(reduceMotion: Bool) -> WordLoopMotionStyle {
        .init(duration: reduceMotion ? 0.16 : contentEnterDuration, displacement: reduceMotion ? 0 : 18)
    }

    public static func drawer(reduceMotion: Bool) -> WordLoopMotionStyle {
        .init(duration: reduceMotion ? 0.16 : drawerDuration, displacement: reduceMotion ? 0 : 344)
    }

    public static func exit(reduceMotion: Bool) -> WordLoopMotionStyle {
        .init(duration: reduceMotion ? 0 : exitDuration, displacement: reduceMotion ? 0 : 18)
    }

    public static func waveform(reduceMotion: Bool) -> WordLoopMotionStyle {
        .init(duration: reduceMotion ? 0 : waveformDuration, displacement: 0, repeats: !reduceMotion)
    }
}
