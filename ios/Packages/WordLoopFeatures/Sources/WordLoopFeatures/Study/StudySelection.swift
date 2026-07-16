import WordLoopCore
import WordLoopDesignSystem

enum StudySelection {
    static let masteryThreshold = 3

    static func eligibleEntries(
        in entries: [CourseEntry],
        studyCounts: [EntryID: Int]
    ) -> [CourseEntry] {
        entries.filter { studyCounts[$0.id, default: 0] < masteryThreshold }
    }

    /// Selects the entry that starts the next learning round.
    ///
    /// `randomIndex` is supplied by the caller so random courses remain fully
    /// deterministic in tests. Sequential courses preserve manifest order.
    static func entry(
        in entries: [CourseEntry],
        order: CoursePracticeOrder,
        studyCounts: [EntryID: Int],
        excluding currentEntryID: EntryID?,
        randomIndex: Int
    ) -> CourseEntry? {
        let eligible = eligibleEntries(in: entries, studyCounts: studyCounts)
        guard !eligible.isEmpty else { return nil }

        let alternatives = eligible.filter { $0.id != currentEntryID }
        let candidates = alternatives.isEmpty ? eligible : alternatives

        switch order {
        case .random:
            return candidates[normalized(randomIndex, count: candidates.count)]
        case .sequential:
            guard let currentEntryID,
                  let currentIndex = entries.firstIndex(where: { $0.id == currentEntryID }) else {
                return candidates.first
            }

            for offset in 1...entries.count {
                let candidate = entries[(currentIndex + offset) % entries.count]
                if candidates.contains(where: { $0.id == candidate.id }) {
                    return candidate
                }
            }
            return candidates.first
        }
    }

    static func palette(
        from palettes: [PosterPalette],
        excluding currentPaletteID: String?,
        randomIndex: Int
    ) -> PosterPalette? {
        guard !palettes.isEmpty else { return nil }
        let alternatives = palettes.filter { $0.id != currentPaletteID }
        let candidates = alternatives.isEmpty ? palettes : alternatives
        return candidates[normalized(randomIndex, count: candidates.count)]
    }

    private static func normalized(_ index: Int, count: Int) -> Int {
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
