public enum CourseDrawerFixtures {
    public static let collections: [CourseDrawerCollection] = [
        .init(
            id: "ielts",
            label: "WORD COURSE",
            title: "IELTS 高频词",
            subtitle: "Academic Word List · 570 words",
            courses: [
                .init(
                    id: "ielts-high-frequency",
                    title: "IELTS 高频词",
                    subtitle: "Academic Word List · 570 words"
                ),
            ]
        ),
        .init(
            id: "modern-family-s01",
            label: "DIALOGUE COURSE",
            title: "摩登家庭 · 第一季",
            subtitle: "5 集对白课程",
            courses: [
                .init(
                    id: "modern-family-s01e01",
                    title: "Modern Family · S01E01",
                    subtitle: "Pilot · 91 learning sentences",
                    completionCount: 2,
                    isSelected: true
                ),
                .init(
                    id: "modern-family-s01e02",
                    title: "Modern Family · S01E02",
                    subtitle: "The Bicycle Thief · 53 learning sentences",
                    completionCount: 1
                ),
                .init(
                    id: "modern-family-s01e03",
                    title: "Modern Family · S01E03",
                    subtitle: "Come Fly with Me · 79 learning sentences"
                ),
                .init(
                    id: "modern-family-s01e04",
                    title: "Modern Family · S01E04",
                    subtitle: "The Incident · 55 learning sentences"
                ),
                .init(
                    id: "modern-family-s01e05",
                    title: "Modern Family · S01E05",
                    subtitle: "Coal Digger · 88 learning sentences"
                ),
            ]
        ),
        .init(
            id: "voa-level-2",
            label: "DIALOGUE COURSE",
            title: "VOA · Level 2",
            subtitle: "24 节实用口语课程 · B1",
            courses: [
                .init(
                    id: "voa-workplace-conversations-b1",
                    title: "Workplace Conversations · B1",
                    subtitle: "VOA Learning English · practical conversations"
                ),
            ]
        ),
    ]
}
