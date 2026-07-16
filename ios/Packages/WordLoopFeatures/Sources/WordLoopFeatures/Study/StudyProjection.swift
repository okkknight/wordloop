import Foundation
import WordLoopCore
import WordLoopDesignSystem

enum StudyProjection {
    static func courseDrawerState(
        catalog: CourseCatalog,
        selectedCourseID: CourseID?,
        completionCounts: [CourseID: Int] = [:]
    ) -> CourseDrawerViewState {
        let availableCourses = catalog.courses.filter { $0.availability == .available }
        let collections: [CourseDrawerCollection] = catalog.collections.compactMap { collection -> CourseDrawerCollection? in
            let courses = availableCourses
                .filter { $0.collectionID == collection.id }
                .map { descriptor in
                    CourseDrawerCourse(
                        id: descriptor.id.rawValue,
                        title: descriptor.title,
                        subtitle: descriptor.subtitle,
                        completionCount: completionCounts[descriptor.id, default: 0],
                        isSelected: descriptor.id == selectedCourseID
                    )
                }
            guard !courses.isEmpty else { return nil }
            return CourseDrawerCollection(
                id: collection.id.rawValue,
                label: collection.label,
                title: collection.title,
                subtitle: collection.subtitle,
                courses: courses
            )
        }

        let expandedCollectionID = selectedCourseID.flatMap { selectedID in
            availableCourses.first(where: { $0.id == selectedID })?.collectionID.rawValue
        } ?? collections.first?.id

        return CourseDrawerViewState(
            collections: collections,
            expandedCollectionID: expandedCollectionID
        )
    }

    static func studyShellItem(
        entry: CourseEntry,
        kind: CourseKind
    ) -> StudyShellItem {
        StudyShellItem(
            id: entry.id.rawValue,
            kind: itemKind(kind),
            english: entry.text,
            phonetic: displayedPhonetic(entry.phonetic),
            translation: normalized(entry.translation) ?? "",
            highlightRanges: highlightRanges(tokens: entry.highlights, in: entry.text)
        )
    }

    static func studyShellState(
        course: Course,
        collection: CourseCollectionDescriptor,
        currentEntryID: EntryID,
        palette: PosterPalette,
        mode: StudyMode,
        visibility: StudyTextVisibility,
        masteryCount: Int,
        isAutoplayEnabled: Bool
    ) -> StudyShellViewState? {
        guard let entryIndex = course.entries.firstIndex(where: { $0.id == currentEntryID }) else {
            return nil
        }
        let entry = course.entries[entryIndex]
        let item = studyShellItem(entry: entry, kind: course.descriptor.kind)
        let safeVisibility: StudyTextVisibility = item.kind == .word && visibility == .focus
            ? .full
            : visibility

        return StudyShellViewState(
            palette: palette,
            courseLabel: course.descriptor.title.uppercased(),
            courseTitle: collection.title,
            currentIndex: entryIndex + 1,
            totalCount: course.entries.count,
            item: item,
            mode: shellMode(mode),
            visibility: safeVisibility,
            masteryCount: masteryCount,
            isAutoplayEnabled: isAutoplayEnabled,
            isRepeatPaused: false
        )
    }

    static func progressDrawerState(
        course: Course,
        studyCounts: [EntryID: Int]
    ) -> ProgressDrawerViewState {
        let entries = course.entries.map { entry in
            ProgressDrawerEntry(
                id: entry.id.rawValue,
                kind: progressKind(course.descriptor.kind),
                primaryText: entry.text,
                secondaryText: progressSecondaryText(entry: entry, kind: course.descriptor.kind),
                studyCount: studyCounts[entry.id, default: 0]
            )
        }
        return ProgressDrawerViewState(
            summary: ProgressDrawerSummary(
                courseTitle: course.descriptor.title,
                totalItemCount: entries.count,
                totalStudies: entries.reduce(0) { $0 + $1.studyCount },
                masteredCount: entries.filter(\.isMastered).count
            ),
            entries: entries
        )
    }

    static func displayedPhonetic(_ phonetic: String?) -> String? {
        guard let value = normalized(phonetic) else { return nil }
        let withoutLeadingSlash = value.hasPrefix("/") ? String(value.dropFirst()) : value
        let unwrapped = withoutLeadingSlash.hasSuffix("/")
            ? String(withoutLeadingSlash.dropLast())
            : withoutLeadingSlash
        guard !unwrapped.isEmpty else { return nil }
        return "/\(unwrapped)/"
    }

    static func highlightRanges(tokens: [String], in text: String) -> [StudyHighlightRange] {
        let sorted = Set(tokens.flatMap { token in
            StudyShellItem.highlightRanges(matching: token, in: text)
        }).sorted {
            $0.lowerBound == $1.lowerBound
                ? $0.upperBound < $1.upperBound
                : $0.lowerBound < $1.lowerBound
        }

        var result: [StudyHighlightRange] = []
        for range in sorted where result.last.map({ $0.upperBound <= range.lowerBound }) ?? true {
            result.append(range)
        }
        return result
    }

    private static func progressSecondaryText(entry: CourseEntry, kind: CourseKind) -> String {
        let translation = normalized(entry.translation)
        guard kind == .word else { return translation ?? "" }
        return [displayedPhonetic(entry.phonetic), translation]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func itemKind(_ kind: CourseKind) -> StudyShellItem.Kind {
        kind == .word ? .word : .sentence
    }

    private static func progressKind(_ kind: CourseKind) -> ProgressDrawerEntry.Kind {
        kind == .word ? .word : .sentence
    }

    private static func shellMode(_ mode: StudyMode) -> StudyShellMode {
        mode == .listen ? .listen : .repeat
    }
}
