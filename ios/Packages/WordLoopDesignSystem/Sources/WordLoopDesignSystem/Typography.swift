import CoreText
import Foundation
import SwiftUI

public enum WordLoopFontFamily: String, CaseIterable, Sendable {
    case sans
    case mono

    public var resourceName: String {
        switch self {
        case .sans: "Geist[wght]"
        case .mono: "GeistMono[wght]"
        }
    }

    public var fallbackDesign: Font.Design {
        switch self {
        case .sans: .default
        case .mono: .monospaced
        }
    }
}

public struct WordLoopFontRegistrationResult: Equatable, Sendable {
    public let registeredPostScriptNames: [String]
    public let failures: [String]

    public var succeeded: Bool { failures.isEmpty && registeredPostScriptNames.count == WordLoopFontFamily.allCases.count }
}

public enum WordLoopFontRegistry {
    public static func resourceURL(for family: WordLoopFontFamily) -> URL? {
        Bundle.module.url(forResource: family.resourceName, withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.module.url(forResource: family.resourceName, withExtension: "ttf")
    }

    public static func licenseURL() -> URL? {
        Bundle.module.url(forResource: "LICENSE", withExtension: "txt", subdirectory: "Fonts")
            ?? Bundle.module.url(forResource: "LICENSE", withExtension: "txt")
    }

    /// Registration is safe to call more than once. Failures are returned to the
    /// caller so UI can retain the explicit system-font fallback.
    public static func registerBundledFonts() -> WordLoopFontRegistrationResult {
        var names: [String] = []
        var failures: [String] = []

        for family in WordLoopFontFamily.allCases {
            guard let url = resourceURL(for: family),
                  let provider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(provider),
                  let name = font.postScriptName as String? else {
                failures.append("Missing or unreadable \(family.resourceName).ttf")
                continue
            }

            var error: Unmanaged<CFError>?
            let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if didRegister || fontIsAvailable(postScriptName: name) {
                names.append(name)
            } else {
                let detail = error?.takeRetainedValue().localizedDescription ?? "unknown registration error"
                failures.append("\(family.resourceName).ttf: \(detail)")
            }
        }

        return .init(registeredPostScriptNames: names, failures: failures)
    }

    public static func postScriptName(for family: WordLoopFontFamily) -> String? {
        guard let url = resourceURL(for: family),
              let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider) else { return nil }
        return font.postScriptName as String?
    }

    private static func fontIsAvailable(postScriptName: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithNameAndSize(postScriptName as CFString, 12)
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        return CTFontCopyPostScriptName(font) as String == postScriptName
    }
}

public enum WordLoopTypography {
    public static func body(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        font(.sans, size: size, weight: weight, relativeTo: .body)
    }

    public static func label(size: CGFloat = 10, weight: Font.Weight = .semibold) -> Font {
        font(.mono, size: size, weight: weight, relativeTo: .caption)
    }

    public static func title(size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
        font(.sans, size: size, weight: weight, relativeTo: .title)
    }

    public static func posterTitle(size: CGFloat = 92, weight: Font.Weight = .bold) -> Font {
        font(.sans, size: size, weight: weight, relativeTo: .largeTitle)
    }

    public static func font(
        _ family: WordLoopFontFamily,
        size: CGFloat,
        weight: Font.Weight,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        if let name = WordLoopFontRegistry.postScriptName(for: family) {
            return .custom(name, size: size, relativeTo: textStyle).weight(weight)
        }
        return .system(size: size, weight: weight, design: family.fallbackDesign)
    }
}

public extension View {
    /// Keeps oversized poster copy readable at accessibility sizes instead of
    /// clipping it horizontally.
    func wordLoopPosterTitleLayout() -> some View {
        self
            .lineLimit(3)
            .minimumScaleFactor(0.46)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}
