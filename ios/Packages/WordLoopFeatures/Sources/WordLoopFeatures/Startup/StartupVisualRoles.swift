import WordLoopDesignSystem

struct StartupVisualRole: Equatable, Sendable {
    let foreground: WordLoopSRGB
    let background: WordLoopSRGB

    var contrastRatio: Double {
        foreground.contrastRatio(with: background)
    }
}

enum StartupVisualRoles {
    static let palette = PosterPalette.all.first(where: { $0.id == "rose" }) ?? .defaultPalette

    // Precomposite the final sRGB roles so the rendered colors and the tested
    // colors are identical. Canonical palette values remain unchanged.
    static let placeholder = StartupVisualRole(
        foreground: blended(palette.ink, over: palette.background, opacity: 0.72),
        background: palette.background
    )

    static let inputBoundary = StartupVisualRole(
        foreground: blended(palette.accent, over: palette.background, opacity: 0.86),
        background: palette.background
    )

    private static func blended(
        _ foreground: WordLoopSRGB,
        over background: WordLoopSRGB,
        opacity: Double
    ) -> WordLoopSRGB {
        let alpha = min(max(opacity, 0), 1)
        return WordLoopSRGB(
            red: foreground.red * alpha + background.red * (1 - alpha),
            green: foreground.green * alpha + background.green * (1 - alpha),
            blue: foreground.blue * alpha + background.blue * (1 - alpha)
        )
    }
}
