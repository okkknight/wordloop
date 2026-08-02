import XCTest
@testable import WordLoopFeatures

final class WordLoopFeaturesTests: XCTestCase {
    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopFeaturesModule.name, "WordLoopFeatures")
    }

    func testCoreCopyHasAValueForEverySupportedLocale() {
        let locales = [
            "zh-Hans", "zh-Hant", "ja", "ko", "es", "pt-BR", "fr", "de",
            "it", "ru", "ar", "id", "th", "vi", "tr", "en-US"
        ]

        for locale in locales {
            let copy = WordLoopCopy(localeIdentifier: locale)
            XCTAssertFalse(copy.course.isEmpty, locale)
            XCTAssertFalse(copy.progress.isEmpty, locale)
            XCTAssertFalse(copy.retry.isEmpty, locale)
            XCTAssertFalse(copy.loadingCourse.isEmpty, locale)
            XCTAssertFalse(copy.liveStudyPage.isEmpty, locale)
            XCTAssertFalse(copy.selectCourse.isEmpty, locale)
            XCTAssertFalse(copy.viewProgress.isEmpty, locale)
            XCTAssertFalse(copy.coursePackages.isEmpty, locale)
            XCTAssertFalse(copy.closeCourseSelector.isEmpty, locale)
            XCTAssertFalse(copy.noMatchingCourse.isEmpty, locale)
            XCTAssertFalse(copy.searchCourse.isEmpty, locale)
        }
    }

    @MainActor
    func testDesignSystemGalleryIsConstructibleWithoutServices() {
        _ = DesignSystemGalleryView()
    }
}
