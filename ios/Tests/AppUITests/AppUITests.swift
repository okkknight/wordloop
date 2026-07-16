import XCTest

@MainActor
final class AppUITests: XCTestCase {
    func testAppLaunchesIntoStartupPage() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["startup.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["startup.username"].exists)
        XCTAssertTrue(app.buttons["startup.submit"].exists)
        XCTAssertEqual(app.buttons["startup.submit"].label, "START")
        XCTAssertFalse(app.descendants(matching: .any)["design-system.gallery"].exists)
    }

    func testStartupAcceptsAnonymousAndNormalizedNamedSubmissions() {
        let anonymousApp = XCUIApplication()
        anonymousApp.launch()
        anonymousApp.buttons["startup.submit"].tap()
        XCTAssertEqual(anonymousApp.buttons["startup.submit"].value as? String, "已提交匿名用户")

        anonymousApp.terminate()

        let namedApp = XCUIApplication()
        namedApp.launch()
        let username = namedApp.textFields["startup.username"]
        username.tap()
        username.typeText(" Alice ")
        namedApp.keyboards.buttons["Go"].tap()
        XCTAssertEqual(namedApp.buttons["startup.submit"].value as? String, "已提交用户 alice")
    }

    func testStartupValidationClearsWhenEditing() {
        let app = XCUIApplication()
        app.launch()

        let username = app.textFields["startup.username"]
        username.tap()
        username.typeText("Word1")
        app.buttons["startup.submit"].tap()
        XCTAssertTrue(app.staticTexts["startup.error"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["startup.error"].label, "用户名只能使用英文字母")

        username.tap()
        username.typeText("a")
        XCTAssertFalse(app.staticTexts["startup.error"].exists)
        XCTAssertTrue(app.buttons["startup.submit"].isHittable)
    }

    func testStartupBusyFixturesExposeExactCopyAndDisabledButton() {
        for fixture in [
            (state: "preparing", button: "PREPARING…", helper: "正在恢复上次课程"),
            (state: "syncing", button: "SYNCING…", helper: "正在同步学习进度"),
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-wordloop-startup-state", fixture.state]
            app.launch()

            XCTAssertTrue(app.buttons["startup.submit"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["startup.submit"].label, fixture.button)
            XCTAssertFalse(app.buttons["startup.submit"].isEnabled)
            XCTAssertEqual(app.staticTexts["startup.helper"].label, fixture.helper)
            app.terminate()
        }
    }

    func testDesignSystemGalleryRemainsAvailableByLaunchArgument() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-design-system-gallery"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "design-system.palette.paper").count, 1)
        XCTAssertTrue(app.buttons["Show fixture dialog"].exists)
    }

    func testFixtureDialogAndDrawerAreAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-design-system-gallery"]
        app.launch()

        app.buttons["Show fixture dialog"].tap()
        XCTAssertTrue(app.buttons["CANCEL"].waitForExistence(timeout: 2))
        app.buttons["CANCEL"].tap()

        app.buttons["Show fixture drawer"].tap()
        XCTAssertTrue(app.buttons["Close fixture drawer"].waitForExistence(timeout: 2))
        app.buttons["Close fixture drawer"].tap()
    }

    func testAccessibilityTextAndReduceMotionFixtureLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-design-system-gallery", "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Native fixture gallery"].exists)
    }

    func testStartupAccessibilityTextAndReduceMotionFixtureLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-startup-invalid", "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["startup.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["startup.error"].exists)
        XCTAssertTrue(app.buttons["startup.submit"].isHittable)
    }

    func testStudyShellRequiresExplicitLaunchArgumentAndKeepsFixturePriority() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["study.page"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["startup.page"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["design-system.gallery"].exists)
        app.terminate()

        let galleryApp = XCUIApplication()
        galleryApp.launchArguments = ["-wordloop-study-shell", "-wordloop-design-system-gallery"]
        galleryApp.launch()
        XCTAssertTrue(galleryApp.descendants(matching: .any)["design-system.gallery"].waitForExistence(timeout: 5))
        XCTAssertFalse(galleryApp.descendants(matching: .any)["study.page"].exists)
    }

    func testStudyShellBaselineContentAndSafeAreaControlsAreAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell"]
        app.launch()

        XCTAssertTrue(app.buttons["study.course"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["study.progress"].isHittable)
        XCTAssertEqual(app.staticTexts["study.course-context"].label, "MODERN FAMILY · S01E01")
        XCTAssertEqual(app.staticTexts["study.progress-count"].label, "第 75 条，共 91 条")
        XCTAssertEqual(app.staticTexts["study.english"].label, "Uh, my dad still isn't completely comfortable with this.")
        XCTAssertEqual(app.staticTexts["study.translation"].label, "我爸对这事还是不太习惯")
        XCTAssertTrue(app.buttons["study.mastery"].isHittable)
        XCTAssertTrue(app.buttons["study.too-easy"].isHittable)
        XCTAssertTrue(app.buttons["study.primary-control"].isHittable)
        XCTAssertTrue(app.buttons["study.next"].isHittable)

        for identifier in ["study.course", "study.progress", "study.mastery", "study.too-easy", "study.primary-control", "study.next"] {
            let frame = app.descendants(matching: .any)[identifier].frame
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX)
        }
    }

    func testStudyShellModeVisibilityAndWordFixturesStayDeterministic() {
        let listenApp = XCUIApplication()
        listenApp.launchArguments = ["-wordloop-study-shell", "-wordloop-study-mode", "listen"]
        listenApp.launch()
        XCTAssertEqual(listenApp.buttons["study.mode.listen"].value as? String, "Selected")
        XCTAssertEqual(listenApp.buttons["study.primary-control"].label, "AUTOPLAY")
        listenApp.buttons["study.primary-control"].tap()
        XCTAssertEqual(listenApp.buttons["study.primary-control"].label, "AUTOPLAY ON")
        listenApp.terminate()

        let repeatApp = XCUIApplication()
        repeatApp.launchArguments = ["-wordloop-study-shell", "-wordloop-study-mode", "repeat"]
        repeatApp.launch()
        XCTAssertEqual(repeatApp.buttons["study.mode.repeat"].value as? String, "Selected")
        XCTAssertEqual(repeatApp.buttons["study.primary-control"].label, "PAUSE")
        XCTAssertTrue(repeatApp.descendants(matching: .any)["study.repeat-card"].exists)
        repeatApp.buttons["study.primary-control"].tap()
        XCTAssertEqual(repeatApp.buttons["study.primary-control"].label, "RESUME")
        repeatApp.terminate()

        let wordApp = XCUIApplication()
        wordApp.launchArguments = ["-wordloop-study-shell", "-wordloop-study-item", "word"]
        wordApp.launch()
        XCTAssertTrue(wordApp.staticTexts["study.phonetic"].waitForExistence(timeout: 5))
        wordApp.buttons["study.visibility"].tap()
        XCTAssertFalse(wordApp.staticTexts["study.english"].exists)
        XCTAssertTrue(wordApp.staticTexts["study.hidden-copy"].exists)
        wordApp.buttons["study.visibility"].tap()
        XCTAssertTrue(wordApp.staticTexts["study.english"].exists)
    }

    func testStudyShellAccessibilityFixtureKeepsWorstCaseContentReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-wordloop-study-shell",
            "-wordloop-study-item", "long-word",
            "-wordloop-fixture-accessibility-text",
            "-wordloop-fixture-reduce-motion",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["study.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["study.english"].exists)
        let playButton = app.buttons["study.play"]
        let visibilityButton = app.buttons["study.visibility"]
        XCTAssertTrue(playButton.isHittable)
        XCTAssertTrue(visibilityButton.isHittable)
        XCTAssertGreaterThanOrEqual(playButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(playButton.frame.height, 44)
        XCTAssertLessThanOrEqual(playButton.frame.maxX, visibilityButton.frame.minX)
        let nextButton = app.buttons["study.next"]
        XCTAssertTrue(nextButton.exists)
        if !nextButton.isHittable { app.swipeUp() }
        if !nextButton.isHittable { app.swipeUp() }
        XCTAssertTrue(nextButton.isHittable)
    }

    func testCourseDrawerOpensFromStudyShellAndAllCloseEntrypointsWork() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell"]
        app.launch()

        XCTAssertTrue(app.buttons["study.course"].waitForExistence(timeout: 5))
        app.buttons["study.course"].tap()
        var drawer = app.descendants(matching: .any)["course-drawer.page"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["study.next"].isHittable)
        app.buttons["course-drawer.close"].tap()
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 2))
        usleep(400_000)

        app.buttons["study.course"].tap()
        drawer = app.descendants(matching: .any)["course-drawer.page"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 2))
        let backdrop = app.buttons["course-drawer.backdrop"]
        XCTAssertTrue(backdrop.waitForExistence(timeout: 2))
        backdrop.tap()
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 2))
        usleep(400_000)

        app.buttons["study.course"].tap()
        drawer = app.descendants(matching: .any)["course-drawer.page"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 2))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.52))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["study.course"].isHittable)
    }

    func testCourseDrawerFixtureExposesCollectionsSelectionAndCompletion() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell", "-wordloop-course-drawer"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["course-drawer.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["course-drawer.search"].exists)
        for collectionID in ["ielts", "modern-family-s01", "voa-level-2"] {
            XCTAssertTrue(app.buttons["course-drawer.collection.\(collectionID)"].exists)
        }

        let current = app.buttons["course-drawer.course.modern-family-s01e01"]
        XCTAssertTrue(current.exists)
        XCTAssertTrue(current.label.contains("当前课程"))
        XCTAssertTrue(current.label.contains("已完成 2 次"))

        let episode2 = app.buttons["course-drawer.course.modern-family-s01e02"]
        XCTAssertTrue(episode2.exists)
        episode2.tap()
        XCTAssertFalse(app.descendants(matching: .any)["course-drawer.page"].exists)
        XCTAssertEqual(app.staticTexts["study.course-context"].label, "MODERN FAMILY · S01E01")
        XCTAssertEqual(app.staticTexts["study.progress-count"].label, "第 75 条，共 91 条")
    }

    func testCourseDrawerSearchEmptyClearAndVerticalScrollStayModal() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell", "-wordloop-course-drawer"]
        app.launch()

        let search = app.textFields["course-drawer.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("definitely absent")
        XCTAssertTrue(app.staticTexts["course-drawer.empty"].waitForExistence(timeout: 2))
        app.buttons["course-drawer.search-clear"].tap()
        XCTAssertFalse(app.staticTexts["course-drawer.empty"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["course-drawer.page"].waitForExistence(timeout: 5))
        let list = app.scrollViews["course-drawer.list"]
        XCTAssertTrue(list.exists)
        list.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["course-drawer.page"].exists)
        XCTAssertFalse(app.buttons["study.next"].isHittable)
    }

    func testCourseDrawerAccessibilityFixtureKeepsHeaderSearchAndListReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-wordloop-study-shell", "-wordloop-course-drawer",
            "-wordloop-course-collapsed", "-wordloop-course-completion", "12",
            "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion",
        ]
        app.launch()

        let close = app.buttons["course-drawer.close"]
        let search = app.textFields["course-drawer.search"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThanOrEqual(close.frame.width, 44)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(app.buttons["course-drawer.collection.modern-family-s01"].exists)
        XCTAssertFalse(app.buttons["study.next"].isHittable)
    }

    func testProgressDrawerOpensAndAllCloseEntrypointsWork() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell"]
        app.launch()

        XCTAssertTrue(app.buttons["study.progress"].waitForExistence(timeout: 5))
        app.buttons["study.progress"].tap()
        var drawer = app.descendants(matching: .any)["progress-drawer.page"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["study.next"].isHittable)
        app.buttons["progress-drawer.close"].tap()
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 2))
        usleep(400_000)

        app.buttons["study.progress"].tap()
        drawer = app.descendants(matching: .any)["progress-drawer.page"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 2))
        app.buttons["progress-drawer.backdrop"].tap()
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 2))
        usleep(400_000)

        app.buttons["study.progress"].tap()
        drawer = app.descendants(matching: .any)["progress-drawer.page"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 2))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.52))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["study.progress"].isHittable)
    }

    func testProgressDrawerFixturesExposeLockedSummaryRowsAndCompletionSemantics() {
        let baseline = XCUIApplication()
        baseline.launchArguments = ["-wordloop-study-shell", "-wordloop-progress-drawer"]
        baseline.launch()

        XCTAssertTrue(baseline.descendants(matching: .any)["progress-drawer.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(baseline.staticTexts["YOUR PROGRESS"].exists)
        XCTAssertTrue(baseline.staticTexts["0 / 273"].exists)
        XCTAssertEqual(baseline.staticTexts["progress-drawer.course"].label, "Modern Family · S01E01")
        XCTAssertEqual(baseline.staticTexts["progress-drawer.stats.mastered"].label, "已掌握 0 条")
        XCTAssertEqual(baseline.staticTexts["progress-drawer.stats.learning"].label, "学习中 91 条")
        let first = baseline.descendants(matching: .any)["progress-drawer.entry.s01e01-0003"]
        XCTAssertTrue(first.exists)
        XCTAssertTrue(first.label.contains("Phil, would you get them?"))
        XCTAssertTrue(first.label.contains("已学习 0 次，共 3 次"))
        baseline.terminate()

        let mixed = XCUIApplication()
        mixed.launchArguments = ["-wordloop-study-shell", "-wordloop-progress-drawer", "-wordloop-progress-mixed"]
        mixed.launch()
        let completed = mixed.descendants(matching: .any)["progress-drawer.entry.s01e01-0010"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        XCTAssertTrue(completed.label.contains("已学习 3 次，共 3 次"))
        XCTAssertTrue(completed.label.contains("已掌握"))
        XCTAssertEqual(mixed.staticTexts["progress-drawer.stats.mastered"].label, "已掌握 1 条")
        XCTAssertEqual(mixed.staticTexts["study.progress-count"].label, "第 75 条，共 91 条")
    }

    func testProgressDrawerSearchEmptyClearWordAndVerticalScrollStayModal() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell", "-wordloop-progress-drawer"]
        app.launch()

        let search = app.textFields["progress-drawer.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("definitely absent")
        XCTAssertTrue(app.staticTexts["progress-drawer.empty"].waitForExistence(timeout: 2))
        app.buttons["progress-drawer.search-clear"].tap()
        XCTAssertFalse(app.staticTexts["progress-drawer.empty"].exists)
        app.scrollViews["progress-drawer.list"].swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["progress-drawer.page"].exists)
        app.terminate()

        let word = XCUIApplication()
        word.launchArguments = ["-wordloop-study-shell", "-wordloop-progress-drawer", "-wordloop-progress-word", "-wordloop-progress-query", "kʌmf"]
        word.launch()
        let result = word.descendants(matching: .any)["progress-drawer.entry.comfortable"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("/ˈkʌmftəbl/"))
        XCTAssertFalse(word.descendants(matching: .any)["progress-drawer.entry.academic"].exists)
    }

    func testProgressDrawerAccessibilityAndCourseFixturePriority() {
        let accessible = XCUIApplication()
        accessible.launchArguments = [
            "-wordloop-study-shell", "-wordloop-progress-drawer", "-wordloop-progress-mixed",
            "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion",
        ]
        accessible.launch()

        let close = accessible.buttons["progress-drawer.close"]
        let search = accessible.textFields["progress-drawer.search"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThanOrEqual(close.frame.width, 44)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(accessible.staticTexts["progress-drawer.stats.mastered"].exists)
        XCTAssertFalse(accessible.buttons["study.next"].isHittable)
        accessible.terminate()

        let conflict = XCUIApplication()
        conflict.launchArguments = ["-wordloop-study-shell", "-wordloop-course-drawer", "-wordloop-progress-drawer"]
        conflict.launch()
        XCTAssertTrue(conflict.descendants(matching: .any)["course-drawer.page"].waitForExistence(timeout: 5))
        XCTAssertFalse(conflict.descendants(matching: .any)["progress-drawer.page"].exists)
    }

    func testRestartCompletionDialogCopyCancelAndRestartIntentStayPresentationOnly() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell", "-wordloop-completion-dialog", "restart"]
        app.launch()

        var dialog = app.descendants(matching: .any)["completion-dialog.page"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["completion-dialog.title"].label, "这门课程已经完成")
        XCTAssertEqual(app.staticTexts["completion-dialog.message"].label, "要重新开始练习吗？现有练习进度将被清零。")
        XCTAssertEqual(app.buttons["completion-dialog.cancel"].label, "取消")
        XCTAssertEqual(app.buttons["completion-dialog.confirm"].label, "重新开始")
        XCTAssertFalse(app.buttons["study.next"].isHittable)

        app.buttons["completion-dialog.cancel"].tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["study.next"].isHittable)

        app.terminate()
        app.launch()
        dialog = app.descendants(matching: .any)["completion-dialog.page"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        app.buttons["completion-dialog.confirm"].tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["study.course-context"].label, "MODERN FAMILY · S01E01")
        XCTAssertEqual(app.staticTexts["study.progress-count"].label, "第 75 条，共 91 条")
        XCTAssertEqual(app.buttons["study.mastery"].label, "熟练度 1 / 3")
    }

    func testNaturalCompletionDialogCanOpenCourseDrawerOrDismissRetrainIntent() {
        let app = XCUIApplication()
        app.launchArguments = ["-wordloop-study-shell", "-wordloop-completion-dialog", "complete"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["completion-dialog.page"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["completion-dialog.title"].label, "这门课程学完了")
        XCTAssertEqual(app.buttons["completion-dialog.cancel"].label, "选择课程")
        XCTAssertEqual(app.buttons["completion-dialog.confirm"].label, "再练一次")
        app.buttons["completion-dialog.cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["course-drawer.page"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["completion-dialog.page"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["completion-dialog.page"].waitForExistence(timeout: 5))
        app.buttons["completion-dialog.confirm"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["completion-dialog.page"].waitForNonExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["study.progress-count"].label, "第 75 条，共 91 条")
    }

    func testCompletionErrorBackdropAndModalPriorityStayDeterministic() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-wordloop-study-shell", "-wordloop-completion-dialog", "complete", "-wordloop-completion-error",
            "-wordloop-course-drawer", "-wordloop-progress-drawer",
        ]
        app.launch()

        let dialog = app.descendants(matching: .any)["completion-dialog.page"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["completion-dialog.error"].label, "暂时无法重置进度，请稍后重试。")
        XCTAssertFalse(app.descendants(matching: .any)["course-drawer.page"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["progress-drawer.page"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap()
        XCTAssertTrue(dialog.exists)
    }

    func testAllRepeatPresentationFixturesExposeExactStaticState() {
        let fixtures = [
            ("idle", "STANDBY", "跟读模式已准备好"),
            ("connecting", "CONNECTING", "正在准备麦克风"),
            ("ready", "READY", "听完示范后开始跟读"),
            ("playing", "LISTENING", "先听一遍标准发音"),
            ("speak", "SPEAKING", "请清晰地跟读"),
            ("speaking", "SPEAKING", "正在听你发音"),
            ("scoring", "CHECKING", "正在分析这次发音"),
            ("passed", "GREAT", "这次发音通过了"),
            ("paused", "PAUSED", "准备好后继续练习"),
            ("retry", "TRY AGAIN", "请再读一次"),
            ("error", "TRY AGAIN", "请再读一次"),
        ]

        for fixture in fixtures {
            let app = XCUIApplication()
            app.launchArguments = [
                "-wordloop-study-shell", "-wordloop-study-repeat",
                "-wordloop-repeat-state", fixture.0,
                "-wordloop-repeat-transcript", "I said this",
                "-wordloop-fixture-reduce-motion",
            ]
            app.launch()

            let state = app.descendants(matching: .any)["study.repeat-state.\(fixture.0)"]
            XCTAssertTrue(state.waitForExistence(timeout: 5), fixture.0)
            XCTAssertTrue(state.label.contains(fixture.1), fixture.0)
            XCTAssertTrue(state.label.contains(fixture.2), fixture.0)
            XCTAssertEqual(app.buttons["study.primary-control"].label, fixture.0 == "paused" ? "RESUME" : "PAUSE")
            XCTAssertEqual(app.descendants(matching: .any)["study.repeat-result"].exists, fixture.0 == "passed")
            XCTAssertEqual(app.descendants(matching: .any)["study.repeat-transcript"].exists, fixture.0 == "retry" || fixture.0 == "error")
            app.terminate()
        }
    }

    func testCompletionAndRetryAccessibilityFixtureRemainReachable() {
        let dialogApp = XCUIApplication()
        dialogApp.launchArguments = [
            "-wordloop-study-shell", "-wordloop-completion-dialog", "complete", "-wordloop-completion-error",
            "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion",
        ]
        dialogApp.launch()

        for identifier in ["completion-dialog.cancel", "completion-dialog.confirm"] {
            let button = dialogApp.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, dialogApp.frame.maxX)
        }
        dialogApp.terminate()

        let retryApp = XCUIApplication()
        retryApp.launchArguments = [
            "-wordloop-study-shell", "-wordloop-study-repeat", "-wordloop-repeat-state", "retry",
            "-wordloop-repeat-transcript", "A deliberately long fixture transcript that wraps safely",
            "-wordloop-fixture-accessibility-text", "-wordloop-fixture-reduce-motion",
        ]
        retryApp.launch()
        XCTAssertTrue(retryApp.descendants(matching: .any)["study.repeat-state.retry"].waitForExistence(timeout: 5))
        XCTAssertTrue(retryApp.descendants(matching: .any)["study.repeat-transcript"].exists)
        let next = retryApp.buttons["study.next"]
        if !next.isHittable { retryApp.swipeUp() }
        if !next.isHittable { retryApp.swipeUp() }
        XCTAssertTrue(next.isHittable)
        let evidence = XCTAttachment(screenshot: retryApp.screenshot())
        evidence.name = "retry-accessibility3-after-scroll"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
}
