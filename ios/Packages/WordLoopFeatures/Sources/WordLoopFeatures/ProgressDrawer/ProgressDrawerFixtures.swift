public enum ProgressDrawerFixtures {
    public static let sentenceEntries: [ProgressDrawerEntry] = [
        .init(id: "s01e01-0003", kind: .sentence, primaryText: "Phil, would you get them?", secondaryText: "菲尔 把他们叫下来好吗", studyCount: 0),
        .init(id: "s01e01-0007", kind: .sentence, primaryText: "Kids? Get down here!", secondaryText: "孩子们 快下来", studyCount: 0),
        .init(id: "s01e01-0008", kind: .sentence, primaryText: "Why are you guys yelling at us when we're way upstairs?", secondaryText: "我们远在楼上 你们喊也没用", studyCount: 0),
        .init(id: "s01e01-0010", kind: .sentence, primaryText: "And, wow! You're not wearing that outfit.", secondaryText: "你不能穿这套衣服出门", studyCount: 0),
        .init(id: "s01e01-0011", kind: .sentence, primaryText: "What's wrong with it?", secondaryText: "这衣服怎么了", studyCount: 0),
        .init(id: "s01e01-0015", kind: .sentence, primaryText: "No. It's way too short.", secondaryText: "不行 这裙子太短了", studyCount: 0),
        .init(id: "s01e01-0017", kind: .sentence, primaryText: "You don't need to prove it to them.", secondaryText: "没必要穿这么少给他们看", studyCount: 0),
        .init(id: "s01e01-0019", kind: .sentence, primaryText: "I got it. Where's the baby oil?", secondaryText: "我去吧 婴儿油在哪儿", studyCount: 0),
        .init(id: "s01e01-0022", kind: .sentence, primaryText: "I was out of control growing up.", secondaryText: "我在成长期间简直无法无天", studyCount: 0),
        .init(id: "s01e01-0036", kind: .sentence, primaryText: "Let's take it down a notch.", secondaryText: "你小点声叫喊", studyCount: 0),
    ]

    public static let sentenceBaseline = ProgressDrawerViewState(
        summary: .init(
            courseTitle: "Modern Family · S01E01",
            totalItemCount: 91,
            totalStudies: 0,
            masteredCount: 0
        ),
        entries: sentenceEntries
    )

    public static let word = ProgressDrawerViewState(
        summary: .init(
            courseTitle: "IELTS 高频词",
            totalItemCount: 570,
            totalStudies: 4,
            masteredCount: 1
        ),
        entries: [
            .init(id: "comfortable", kind: .word, primaryText: "comfortable", secondaryText: "/ˈkʌmftəbl/ · 舒服的；自在的", studyCount: 3),
            .init(id: "academic", kind: .word, primaryText: "academic", secondaryText: "/ˌækəˈdemɪk/ · 学术的", studyCount: 1),
            .init(id: "approach", kind: .word, primaryText: "approach", secondaryText: "/əˈproʊtʃ/ · 方法；接近", studyCount: 0),
        ]
    )

    public static var mixed: ProgressDrawerViewState {
        var entries = sentenceEntries
        entries[0].studyCount = 0
        entries[1].studyCount = 1
        entries[2].studyCount = 2
        entries[3].studyCount = 3
        return .init(
            summary: .init(
                courseTitle: "Modern Family · S01E01",
                totalItemCount: 91,
                totalStudies: 6,
                masteredCount: 1
            ),
            entries: entries
        )
    }

    public static var complete: ProgressDrawerViewState {
        .init(
            summary: .init(
                courseTitle: "Modern Family · S01E01",
                totalItemCount: 91,
                totalStudies: 273,
                masteredCount: 91
            ),
            entries: sentenceEntries.map {
                .init(
                    id: $0.id,
                    kind: $0.kind,
                    primaryText: $0.primaryText,
                    secondaryText: $0.secondaryText,
                    studyCount: 3
                )
            }
        )
    }
}
