import CryptoKit
import Foundation
import SwiftUI
import XCTest
@testable import WordLoopDesignSystem

final class WordLoopDesignSystemTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopDesignSystemModule.name, "WordLoopDesignSystem")
    }

    func testCanonicalPalettesKeepStableOrderAndExactSRGBValues() {
        XCTAssertEqual(PosterPalette.all.map(\.id), ["paper", "sun", "sky", "rose", "mint", "night"])
        XCTAssertEqual(PosterPalette.all.map(\.order), Array(0...5))
        XCTAssertEqual(PosterPalette.all[0].background, WordLoopSRGB(hex: 0xf3f0e8))
        XCTAssertEqual(PosterPalette.all[0].ink, WordLoopSRGB(hex: 0x1e3a34))
        XCTAssertEqual(PosterPalette.all[0].accent, WordLoopSRGB(hex: 0xd4562b))
        XCTAssertEqual(PosterPalette.all[5].background, WordLoopSRGB(hex: 0x26233e))
        XCTAssertEqual(PosterPalette.all[5].ink, WordLoopSRGB(hex: 0xf4ead7))
        XCTAssertEqual(PosterPalette.all[5].accent, WordLoopSRGB(hex: 0xf3bd4f))
    }

    func testNextPaletteNeverRepeatsAndWrapsDeterministically() {
        for palette in PosterPalette.all {
            XCTAssertNotEqual(PosterPalette.next(after: palette.id), palette)
        }
        XCTAssertEqual(PosterPalette.next(after: "night"), PosterPalette.all[0])
        XCTAssertEqual(PosterPalette.next(after: nil), PosterPalette.defaultPalette)
        XCTAssertEqual(PosterPalette.next(after: "unknown"), PosterPalette.defaultPalette)
    }

    func testSmallTextRolesMeetContrastWithoutChangingCanonicalAccents() {
        for palette in PosterPalette.all {
            XCTAssertGreaterThanOrEqual(palette.ink.contrastRatio(with: palette.background), 4.5)
            XCTAssertGreaterThanOrEqual(palette.accessibleAccentText.contrastRatio(with: palette.background), 4.5)
            XCTAssertGreaterThanOrEqual(palette.background.contrastRatio(with: palette.accessibleAccentText), 4.5)
        }
        XCTAssertEqual(PosterPalette.all[0].accessibleAccentText, PosterPalette.all[0].ink)
        XCTAssertEqual(PosterPalette.all[5].accessibleAccentText, PosterPalette.all[5].accent)
    }

    func testSpacingRadiusBorderAndShadowConstants() {
        XCTAssertEqual(
            [WordLoopSpacing.xxs, WordLoopSpacing.xs, WordLoopSpacing.sm, WordLoopSpacing.md, WordLoopSpacing.safe, WordLoopSpacing.safeWide, WordLoopSpacing.lg, WordLoopSpacing.minimumHit],
            [CGFloat(4), 8, 12, 16, 20, 24, 32, 44]
        )
        XCTAssertEqual(WordLoopRadius.control, 8)
        XCTAssertEqual(WordLoopRadius.card, 13)
        XCTAssertEqual(WordLoopRadius.dialog, 16)
        XCTAssertEqual(WordLoopBorder.hairline, 1)
        XCTAssertEqual(WordLoopShadow.dialog, .init(colorOpacity: 0.22, radius: 60, y: 22))
    }

    func testMotionKeepsWebTimingAndReduceMotionRemovesLargeMovement() {
        XCTAssertEqual(WordLoopMotion.paletteDuration, 0.420)
        XCTAssertEqual(WordLoopMotion.contentEnterDuration, 0.520)
        XCTAssertEqual(WordLoopMotion.drawerDuration, 0.260)
        XCTAssertEqual(WordLoopMotion.exitDuration, 0.240)
        XCTAssertEqual(WordLoopMotion.waveformDuration, 0.880)

        XCTAssertEqual(WordLoopMotion.contentEnter(reduceMotion: false).displacement, 18)
        XCTAssertEqual(WordLoopMotion.drawer(reduceMotion: false).displacement, 344)
        XCTAssertEqual(WordLoopMotion.contentEnter(reduceMotion: true).displacement, 0)
        XCTAssertEqual(WordLoopMotion.drawer(reduceMotion: true).displacement, 0)
        XCTAssertFalse(WordLoopMotion.waveform(reduceMotion: true).repeats)
        XCTAssertTrue(WordLoopMotion.waveform(reduceMotion: false).repeats)
    }

    func testFontResourcesExistHavePinnedDigestsAndResolvableNames() throws {
        let expectedHashes: [WordLoopFontFamily: String] = [
            .sans: "8f700c5c9f8e5af507132f1b50baf02fc12ca4c04a1100473bf44babbe8528fe",
            .mono: "506fbaf05ffde249c7c400b5591d1999577ebe82372b0e35266dd5d9ee385771",
        ]

        for family in WordLoopFontFamily.allCases {
            let url = try XCTUnwrap(WordLoopFontRegistry.resourceURL(for: family))
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 100_000)
            XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), expectedHashes[family])
            XCTAssertFalse(try XCTUnwrap(WordLoopFontRegistry.postScriptName(for: family)).isEmpty)
        }

        let licenseData = try Data(contentsOf: XCTUnwrap(WordLoopFontRegistry.licenseURL()))
        let license = try XCTUnwrap(String(data: licenseData, encoding: .utf8))
        XCTAssertTrue(license.contains("SIL OPEN FONT LICENSE"))
    }

    func testBundledFontRegistrationIsObservableAndIdempotent() {
        let first = WordLoopFontRegistry.registerBundledFonts()
        let second = WordLoopFontRegistry.registerBundledFonts()
        XCTAssertTrue(first.succeeded, first.failures.joined(separator: "\n"))
        XCTAssertTrue(second.succeeded, second.failures.joined(separator: "\n"))
        XCTAssertEqual(Set(first.registeredPostScriptNames), Set(second.registeredPostScriptNames))
    }

    func testHapticsCanBeNoOpOrRecordedWithoutUIKit() {
        NoOpWordLoopHaptics().perform(.success)
        let recorder = RecordingWordLoopHaptics()
        recorder.perform(.selection)
        recorder.perform(.failure)
        XCTAssertEqual(recorder.events, [.selection, .failure])
    }

    func testComponentModelsRemainPresentationOnly() {
        let card = CourseCardModel(title: "Title", metadata: "12 ITEMS", detail: "Detail", badge: "NEW", isSelected: true)
        XCTAssertEqual(card.title, "Title")
        XCTAssertTrue(card.isSelected)

        let dialog = ConfirmDialogModel(kicker: "NOTICE", title: "Continue?", message: "Message", cancelTitle: "Cancel", confirmTitle: "OK")
        XCTAssertEqual(dialog.confirmTitle, "OK")
        XCTAssertEqual(Set(WaveformState.allCases.map(\.rawValue)), ["idle", "active", "success", "failure"])
    }

    @MainActor
    func testVisualComponentsAreConstructibleOnHost() {
        let palette = PosterPalette.defaultPalette
        _ = PosterBackground(palette: palette) { Text("Fixture") }
        _ = MonoLabel("Label")
        _ = ModeSwitch(options: ["A", "B"], selection: .constant("A"), accessibilityLabel: "Mode")
        _ = PosterButton(.iconAndText(systemName: "play", text: "Play"), accessibilityLabel: "Play") {}
        _ = CourseCard(model: .init(title: "Course", metadata: "10 ITEMS"), palette: palette, accessibilityLabel: "Course") {}
        _ = SideDrawer(edge: .leading, palette: palette, title: "Courses", closeAccessibilityLabel: "Close", onClose: {}) { Text("Contents") }
        _ = ProgressTrack(progress: 0.5, palette: palette, accessibilityLabel: "Progress")
        _ = ConfirmDialog(model: .init(kicker: "NOTICE", title: "Title", message: "Message", cancelTitle: "Cancel", confirmTitle: "OK"), palette: palette, onCancel: {}, onConfirm: {})
        _ = Waveform(state: .active, palette: palette, accessibilityLabel: "Recording")
    }
}
