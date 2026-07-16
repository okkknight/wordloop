import CryptoKit
import Darwin
import Foundation
import XCTest
import WordLoopCore
@testable import WordLoopContent

final class WordLoopContentTests: XCTestCase {
    private var temporaryRoots: [URL] = []

    override func tearDownWithError() throws {
        for root in temporaryRoots {
            try? FileManager.default.removeItem(at: root)
        }
        temporaryRoots = []
    }

    func testModuleIsAvailable() {
        XCTAssertEqual(WordLoopContentModule.name, "WordLoopContent")
    }

    func testLiveCatalogMatchesExporterInventoryAndLightweightCourseURLs() throws {
        let source = try BundledCourseSource.live()
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertEqual(catalog.collections.count, 3)
        XCTAssertEqual(catalog.courses.count, 30)
        XCTAssertEqual(catalog.defaultCourseID.rawValue, "modern-family-s01e01")
        XCTAssertEqual(catalog.courses.filter { $0.kind == .word }.count, 1)
        XCTAssertEqual(catalog.courses.filter { $0.kind == .sentence }.count, 29)
        XCTAssertEqual(catalog.courses.filter { $0.practiceOrder == .random }.count, 1)
        XCTAssertEqual(catalog.courses.filter { $0.practiceOrder == .sequential }.count, 29)

        let descriptor = try XCTUnwrap(catalog.courses.first { $0.id.rawValue == "modern-family-s01e01" })
        let course = try source.loadCourse(descriptor: descriptor)
        XCTAssertEqual(course.entries.count, 91)
        XCTAssertTrue(course.entries.allSatisfy { $0.audioURL.isFileURL && FileManager.default.fileExists(atPath: $0.audioURL.path) })
    }

    func testFullValidationLoadsAllCoursesAudioDigestsAndPinnedSamples() throws {
        let source = try BundledCourseSource.live(validationMode: .full)
        let catalog = try source.loadCatalog()
        var wordEntries = 0
        var sentenceEntries = 0
        var audioBytes = 0
        var courses: [CourseID: Course] = [:]

        for descriptor in catalog.courses {
            let course = try source.loadCourse(descriptor: descriptor)
            courses[descriptor.id] = course
            if descriptor.kind == .word { wordEntries += course.entries.count }
            else { sentenceEntries += course.entries.count }
            for entry in course.entries {
                let values = try entry.audioURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                XCTAssertEqual(values.isRegularFile, true)
                XCTAssertNotEqual(values.isSymbolicLink, true)
                audioBytes += try XCTUnwrap(values.fileSize)
            }
        }

        XCTAssertEqual(wordEntries, 570)
        XCTAssertEqual(sentenceEntries, 836)
        XCTAssertEqual(wordEntries + sentenceEntries, 1_406)
        XCTAssertEqual(audioBytes, 32_700_838)

        let ielts = try XCTUnwrap(courses[id("ielts-high-frequency")])
        let abandon = try XCTUnwrap(ielts.entries.first { $0.id.rawValue == "abandon" })
        XCTAssertEqual(ielts.descriptor.practiceOrder, .random)
        XCTAssertEqual(abandon.text, "abandon")
        XCTAssertEqual(abandon.translation, "vt. 放弃, 抛弃, 遗弃, 使屈从, 沉溺, 放纵；n. 放任, 无拘束, 狂热")
        XCTAssertEqual(abandon.phonetic, "ə'bændən")
        XCTAssertEqual(abandon.highlights, [])
        XCTAssertEqual(abandon.audioURL.lastPathComponent, "abandon.m4a")

        let modern = try XCTUnwrap(courses[id("modern-family-s01e01")])
        XCTAssertEqual(modern.descriptor.practiceOrder, .sequential)
        XCTAssertEqual(modern.entries.first?.id.rawValue, "s01e01-0003")
        XCTAssertEqual(modern.entries.first?.text, "Phil, would you get them?")
        XCTAssertEqual(modern.entries.first?.translation, "菲尔 把他们叫下来好吗")
        XCTAssertNil(modern.entries.first?.phonetic)
        XCTAssertEqual(modern.entries.first?.highlights, ["get them"])
        XCTAssertEqual(modern.entries.first?.audioURL.lastPathComponent, "s01e01-0003.m4a")

        let voa = try XCTUnwrap(courses[id("voa-workplace-conversations-b1")])
        XCTAssertEqual(voa.descriptor.practiceOrder, .sequential)
        XCTAssertEqual(voa.entries.first?.id.rawValue, "voa-work-b1-001")
        XCTAssertEqual(voa.entries.first?.text, "What do you think today's meeting is about? The email sounded important.")
        XCTAssertEqual(voa.entries.first?.translation, "你觉得今天的会议是关于什么的？那封邮件看起来很重要。")
        XCTAssertNil(voa.entries.first?.phonetic)
        XCTAssertEqual(voa.entries.first?.highlights, ["What do you think", "is about"])
        XCTAssertEqual(voa.entries.first?.audioURL.lastPathComponent, "voa-work-b1-001.m4a")
    }

    func testCatalogRejectsMalformedUnknownSchemaAndUnknownFields() throws {
        try assertCatalogMutation { root in
            try Data("{".utf8).write(to: root.appendingPathComponent("catalog.json"))
        } matches: { if case .malformedJSON("catalog.json") = $0 { true } else { false } }

        try assertCatalogJSONMutation { $0["schemaVersion"] = 2 } matches: {
            if case .unsupportedSchema(document: "catalog.json", found: 2) = $0 { true } else { false }
        }

        try assertCatalogJSONMutation { $0["unexpected"] = true } matches: {
            if case .unknownField(document: "catalog.json", field: "unexpected") = $0 { true } else { false }
        }
    }

    func testCatalogRejectsDuplicateMissingReferencesAndInvalidDescriptorScalars() throws {
        try assertCatalogJSONMutation { object in
            var courses = object["courses"] as! [[String: Any]]
            courses.append(courses[0])
            object["courses"] = courses
        } matches: { if case .duplicateID(kind: "course", value: _) = $0 { true } else { false } }

        try assertCatalogJSONMutation { $0["defaultCourseId"] = "missing-course" } matches: {
            if case .defaultCourseMissing("missing-course") = $0 { true } else { false }
        }

        try assertCatalogJSONMutation { object in
            var courses = object["courses"] as! [[String: Any]]
            courses[0]["collectionId"] = "missing-collection"
            object["courses"] = courses
        } matches: { if case .unknownCollection(courseID: _, collectionID: "missing-collection") = $0 { true } else { false } }

        for fieldAndValue in [("minimumAppVersion", "1"), ("manifestSHA256", "BAD"), ("downloadSize", 0)] as [(String, Any)] {
            try assertCatalogJSONMutation { object in
                var courses = object["courses"] as! [[String: Any]]
                courses[0][fieldAndValue.0] = fieldAndValue.1
                object["courses"] = courses
            } matches: { if case .invalidValue = $0 { true } else { false } }
        }
    }

    func testCatalogRejectsUnsafeManifestLocationsAndUnknownEnums() throws {
        for location in ["../course.json", "/course.json", "https://example.com/course.json", "courses/%2e%2e/course.json", "courses\\course.json"] {
            try assertCatalogJSONMutation { object in
                var courses = object["courses"] as! [[String: Any]]
                courses[0]["manifestURL"] = location
                object["courses"] = courses
            } matches: { if case .unsafePath = $0 { true } else { false } }
        }

        try assertCatalogJSONMutation { object in
            var courses = object["courses"] as! [[String: Any]]
            courses[0]["kind"] = "video"
            object["courses"] = courses
        } matches: { if case .invalidValue(document: _, field: "kind") = $0 { true } else { false } }
    }

    func testCourseRejectsUnknownFieldAndDescriptorManifestIntegrityMismatches() throws {
        let context = try makeCourseContext()
        var courseJSON = try json(at: context.courseURL)
        courseJSON["unexpected"] = true
        try writeJSON(courseJSON, to: context.courseURL)
        XCTAssertThrowsError(try context.source.loadCourse(descriptor: context.descriptor)) {
            XCTAssertEqual($0 as? CourseContentError, .unknownField(document: context.descriptor.manifestLocation, field: "unexpected"))
        }

        for field in ["id", "collectionId", "contentVersion", "title", "kind", "practiceOrder"] {
            let next = try makeCourseContext()
            var json = try json(at: next.courseURL)
            switch field {
            case "contentVersion": json[field] = 2
            case "kind": json[field] = "word"
            case "practiceOrder": json[field] = "random"
            default: json[field] = "mismatch"
            }
            try writeJSON(json, to: next.courseURL)
            XCTAssertThrowsError(try next.source.loadCourse(descriptor: next.descriptor)) {
                guard case .metadataMismatch(courseID: _, field: field) = $0 as? CourseContentError else {
                    return XCTFail("Expected metadata mismatch for \(field), got \($0)")
                }
            }
        }
    }

    func testCourseRejectsEmptyDuplicateInvalidEntriesAndTraversal() throws {
        try assertRehashedCourseMutation { $0["entries"] = [] }

        try assertRehashedCourseMutation { object in
            var entries = object["entries"] as! [[String: Any]]
            entries.append(entries[0])
            object["entries"] = entries
        }

        try assertRehashedCourseMutation { object in
            var entries = object["entries"] as! [[String: Any]]
            entries[0]["durationMilliseconds"] = 0
            object["entries"] = entries
        }

        for path in ["audio/../escape.m4a", "../escape.m4a", "audio/%2e%2e/escape.m4a", "https://x/a.m4a"] {
            try assertRehashedCourseMutation { object in
                var entries = object["entries"] as! [[String: Any]]
                entries[0]["audio"] = path
                object["entries"] = entries
            }
        }
    }

    func testIntegrityRejectsDuplicateUndeclaredAndInvalidRecords() throws {
        let duplicate = try makeCourseContext()
        var duplicateIntegrity = try json(at: duplicate.integrityURL)
        var files = duplicateIntegrity["files"] as! [[String: Any]]
        files.append(files[0])
        duplicateIntegrity["files"] = files
        try writeJSON(duplicateIntegrity, to: duplicate.integrityURL)
        XCTAssertThrowsError(try duplicate.source.loadCourse(descriptor: duplicate.descriptor))

        let missing = try makeCourseContext()
        var missingIntegrity = try json(at: missing.integrityURL)
        var missingFiles = missingIntegrity["files"] as! [[String: Any]]
        missingFiles.remove(at: 1)
        missingIntegrity["files"] = missingFiles
        try writeJSON(missingIntegrity, to: missing.integrityURL)
        XCTAssertThrowsError(try missing.source.loadCourse(descriptor: missing.descriptor))

        let invalid = try makeCourseContext()
        var invalidIntegrity = try json(at: invalid.integrityURL)
        var invalidFiles = invalidIntegrity["files"] as! [[String: Any]]
        invalidFiles[1]["sha256"] = "BAD"
        invalidIntegrity["files"] = invalidFiles
        try writeJSON(invalidIntegrity, to: invalid.integrityURL)
        XCTAssertThrowsError(try invalid.source.loadCourse(descriptor: invalid.descriptor))
    }

    func testFilesystemRejectsMissingExtraSymlinkAndFIFOAudio() throws {
        let missing = try makeCourseContext()
        try FileManager.default.removeItem(at: missing.firstAudioURL)
        XCTAssertThrowsError(try missing.source.loadCourse(descriptor: missing.descriptor))

        let extra = try makeCourseContext()
        try Data("extra".utf8).write(to: extra.courseRoot.appendingPathComponent("extra.m4a"))
        XCTAssertThrowsError(try extra.source.loadCourse(descriptor: extra.descriptor))

        let symlink = try makeCourseContext()
        let target = symlink.courseRoot.appendingPathComponent("course.json")
        try FileManager.default.removeItem(at: symlink.firstAudioURL)
        try FileManager.default.createSymbolicLink(at: symlink.firstAudioURL, withDestinationURL: target)
        XCTAssertThrowsError(try symlink.source.loadCourse(descriptor: symlink.descriptor))

        let fifo = try makeCourseContext()
        try FileManager.default.removeItem(at: fifo.firstAudioURL)
        XCTAssertEqual(mkfifo(fifo.firstAudioURL.path, 0o600), 0)
        XCTAssertThrowsError(try fifo.source.loadCourse(descriptor: fifo.descriptor))
    }

    func testManifestAndAudioByteCountAndDigestMutationsFailClosed() throws {
        let manifest = try makeCourseContext()
        var bytes = try Data(contentsOf: manifest.courseURL)
        bytes.append(0x20)
        try bytes.write(to: manifest.courseURL)
        XCTAssertThrowsError(try manifest.source.loadCourse(descriptor: manifest.descriptor)) {
            guard case .manifestDigestMismatch = $0 as? CourseContentError else { return XCTFail("Unexpected \($0)") }
        }

        let size = try makeCourseContext()
        var audio = try Data(contentsOf: size.firstAudioURL)
        audio.append(0)
        try audio.write(to: size.firstAudioURL)
        XCTAssertThrowsError(try size.source.loadCourse(descriptor: size.descriptor)) {
            guard case .byteCountMismatch = $0 as? CourseContentError else { return XCTFail("Unexpected \($0)") }
        }

        let digest = try makeCourseContext(validationMode: .full)
        var sameSize = try Data(contentsOf: digest.firstAudioURL)
        sameSize[0] ^= 0xff
        try sameSize.write(to: digest.firstAudioURL)
        XCTAssertThrowsError(try digest.source.loadCourse(descriptor: digest.descriptor)) {
            guard case .audioDigestMismatch = $0 as? CourseContentError else { return XCTFail("Unexpected \($0)") }
        }
    }

    func testRepositoryCachesSuccessRejectsUnknownAndRetriesFailures() async throws {
        let fixture = repositoryFixture()
        let source = RecordingSource(catalog: fixture.catalog, course: fixture.course)
        let repository = CourseRepository(source: source)

        _ = try await repository.catalog()
        _ = try await repository.descriptors()
        _ = try await repository.course(id: fixture.course.id)
        _ = try await repository.course(id: fixture.course.id)
        XCTAssertEqual(source.counts(), .init(catalog: 1, course: 1))

        let unknown = id("unknown-course")
        await XCTAssertThrowsErrorAsync(try await repository.course(id: unknown)) {
            XCTAssertEqual($0 as? CourseContentError, .unknownCourse("unknown-course"))
        }
        XCTAssertEqual(source.counts(), .init(catalog: 1, course: 1))

        let retrying = RecordingSource(catalog: fixture.catalog, course: fixture.course, catalogFailures: 1)
        let retryRepository = CourseRepository(source: retrying)
        await XCTAssertThrowsErrorAsync(try await retryRepository.catalog())
        _ = try await retryRepository.catalog()
        XCTAssertEqual(retrying.counts().catalog, 2)
    }

    private func makeCourseContext(validationMode: CourseValidationMode = .lightweight) throws -> CourseContext {
        let live = try BundledCourseSource.live()
        let catalog = try live.loadCatalog()
        let descriptor = try XCTUnwrap(catalog.courses.first { $0.id.rawValue == "modern-family-s01e01" })
        let root = makeTemporaryRoot()
        try FileManager.default.copyItem(
            at: live.resourceRootURL.appendingPathComponent("catalog.json"),
            to: root.appendingPathComponent("catalog.json")
        )
        let sourceCourseRoot = live.resourceRootURL
            .appendingPathComponent("courses/modern-family-s01e01/1")
        let courseRoot = root.appendingPathComponent("courses/modern-family-s01e01/1")
        try FileManager.default.createDirectory(at: courseRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceCourseRoot, to: courseRoot)
        let source = BundledCourseSource(resourceRootURL: root, validationMode: validationMode)
        let firstAudio = try XCTUnwrap(try source.loadCourse(descriptor: descriptor).entries.first?.audioURL)
        return CourseContext(
            source: source,
            descriptor: descriptor,
            courseRoot: courseRoot,
            courseURL: courseRoot.appendingPathComponent("course.json"),
            integrityURL: courseRoot.appendingPathComponent("integrity.json"),
            firstAudioURL: firstAudio
        )
    }

    private func assertCatalogMutation(
        _ mutation: (URL) throws -> Void,
        matches: (CourseContentError) -> Bool
    ) throws {
        let live = try BundledCourseSource.live()
        let root = makeTemporaryRoot()
        try FileManager.default.copyItem(
            at: live.resourceRootURL.appendingPathComponent("catalog.json"),
            to: root.appendingPathComponent("catalog.json")
        )
        try mutation(root)
        XCTAssertThrowsError(try BundledCourseSource(resourceRootURL: root).loadCatalog()) {
            guard let contentError = $0 as? CourseContentError, matches(contentError) else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    private func assertCatalogJSONMutation(
        _ mutation: (inout [String: Any]) -> Void,
        matches: (CourseContentError) -> Bool
    ) throws {
        try assertCatalogMutation({ root in
            let url = root.appendingPathComponent("catalog.json")
            var object = try json(at: url)
            mutation(&object)
            try writeJSON(object, to: url)
        }, matches: matches)
    }

    private func assertRehashedCourseMutation(_ mutation: (inout [String: Any]) -> Void) throws {
        let context = try makeCourseContext()
        var object = try json(at: context.courseURL)
        mutation(&object)
        try writeJSON(object, to: context.courseURL)
        let descriptor = try rehashCourse(context)
        XCTAssertThrowsError(try context.source.loadCourse(descriptor: descriptor))
    }

    private func rehashCourse(_ context: CourseContext) throws -> CourseDescriptor {
        let data = try Data(contentsOf: context.courseURL)
        let digest = sha256(data)
        var integrity = try json(at: context.integrityURL)
        var files = integrity["files"] as! [[String: Any]]
        let index = try XCTUnwrap(files.firstIndex { $0["path"] as? String == "course.json" })
        files[index]["bytes"] = data.count
        files[index]["sha256"] = digest
        integrity["files"] = files
        try writeJSON(integrity, to: context.integrityURL)
        let old = context.descriptor
        return CourseDescriptor(
            id: old.id,
            collectionID: old.collectionID,
            title: old.title,
            subtitle: old.subtitle,
            description: old.description,
            kind: old.kind,
            practiceOrder: old.practiceOrder,
            contentVersion: old.contentVersion,
            minimumAppVersion: old.minimumAppVersion,
            manifestLocation: old.manifestLocation,
            manifestSHA256: digest,
            downloadSize: old.downloadSize,
            availability: old.availability
        )
    }

    private func makeTemporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WordLoopContentTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        temporaryRoots.append(root)
        return root
    }

    private func json(at url: URL) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func id(_ rawValue: String) -> CourseID {
        CourseID(rawValue: rawValue)!
    }

    private func repositoryFixture() -> (catalog: CourseCatalog, course: Course) {
        let courseID = id("fixture-course")
        let collectionID = CourseCollectionID(rawValue: "fixture")!
        let descriptor = CourseDescriptor(
            id: courseID,
            collectionID: collectionID,
            title: "Fixture",
            subtitle: "",
            description: "",
            kind: .sentence,
            practiceOrder: .sequential,
            contentVersion: 1,
            minimumAppVersion: "1.0.0",
            manifestLocation: "courses/fixture-course/1/course.json",
            manifestSHA256: String(repeating: "0", count: 64),
            downloadSize: 1,
            availability: .available
        )
        let entry = CourseEntry(
            id: EntryID(rawValue: "entry-one")!,
            text: "Hello",
            translation: nil,
            phonetic: nil,
            highlights: [],
            audioURL: URL(fileURLWithPath: "/tmp/fixture.m4a"),
            durationMilliseconds: 1
        )
        let catalog = CourseCatalog(
            schemaVersion: 1,
            generatedAt: "2026-07-16T00:00:00Z",
            defaultCourseID: courseID,
            collections: [.init(id: collectionID, label: "COURSE", title: "Fixture", subtitle: "One")],
            courses: [descriptor]
        )
        return (catalog, Course(descriptor: descriptor, entries: [entry]))
    }
}

private struct CourseContext {
    let source: BundledCourseSource
    let descriptor: CourseDescriptor
    let courseRoot: URL
    let courseURL: URL
    let integrityURL: URL
    let firstAudioURL: URL
}

private struct SourceCounts: Equatable {
    let catalog: Int
    let course: Int
}

private final class RecordingSource: CourseSource, @unchecked Sendable {
    private let lock = NSLock()
    private let storedCatalog: CourseCatalog
    private let storedCourse: Course
    private var catalogCalls = 0
    private var courseCalls = 0
    private var catalogFailures: Int

    init(catalog: CourseCatalog, course: Course, catalogFailures: Int = 0) {
        storedCatalog = catalog
        storedCourse = course
        self.catalogFailures = catalogFailures
    }

    func loadCatalog() throws -> CourseCatalog {
        try lock.withLock {
            catalogCalls += 1
            if catalogFailures > 0 {
                catalogFailures -= 1
                throw CourseContentError.malformedJSON("fixture")
            }
            return storedCatalog
        }
    }

    func loadCourse(descriptor: CourseDescriptor) throws -> Course {
        lock.withLock {
            courseCalls += 1
            return storedCourse
        }
    }

    func counts() -> SourceCounts {
        lock.withLock { SourceCounts(catalog: catalogCalls, course: courseCalls) }
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (any Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
