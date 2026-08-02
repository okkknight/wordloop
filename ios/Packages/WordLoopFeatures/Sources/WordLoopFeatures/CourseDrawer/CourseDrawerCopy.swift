import Foundation
import WordLoopCore

struct CourseDrawerCopy: Sendable {
    let label: String
    let title: String
    let subtitle: String

    static var current: Self {
        Self(localeIdentifier: Locale.preferredLanguages.first ?? Locale.current.identifier)
    }

    init(localeIdentifier: String) {
        let id = localeIdentifier.lowercased().replacingOccurrences(of: "_", with: "-")
        let language = id.split(separator: "-").first.map(String.init) ?? "en"
        switch language {
        case "zh" where id.contains("hant") || id.contains("tw") || id.contains("hk"):
            self.init(label: "口語課程", title: "日常英語會話", subtitle: "Everyday English · 實用場景口語")
        case "zh":
            self.init(label: "口语课程", title: "日常英语会话", subtitle: "Everyday English · 实用场景口语")
        case "ja":
            self.init(label: "会話コース", title: "日常英会話", subtitle: "Everyday English · 実用会話")
        case "ko":
            self.init(label: "회화 코스", title: "일상 영어 회화", subtitle: "Everyday English · 실용 회화")
        case "es":
            self.init(label: "CURSO DE CONVERSACIÓN", title: "Inglés cotidiano", subtitle: "Everyday English · conversaciones prácticas")
        case "pt":
            self.init(label: "CURSO DE CONVERSAÇÃO", title: "Inglês do dia a dia", subtitle: "Everyday English · conversas práticas")
        case "fr":
            self.init(label: "COURS DE CONVERSATION", title: "Anglais du quotidien", subtitle: "Everyday English · conversations pratiques")
        case "de":
            self.init(label: "KONVERSATIONSKURS", title: "Alltagsenglisch", subtitle: "Everyday English · praktische Gespräche")
        case "it":
            self.init(label: "CORSO DI CONVERSAZIONE", title: "Inglese quotidiano", subtitle: "Everyday English · conversazioni pratiche")
        case "ru":
            self.init(label: "РАЗГОВОРНЫЙ КУРС", title: "Повседневный английский", subtitle: "Everyday English · практические разговоры")
        case "ar":
            self.init(label: "دورة المحادثة", title: "الإنجليزية اليومية", subtitle: "Everyday English · محادثات عملية")
        case "id":
            self.init(label: "KURSUS PERCAKAPAN", title: "Bahasa Inggris sehari-hari", subtitle: "Everyday English · percakapan praktis")
        case "th":
            self.init(label: "บทสนทนา", title: "ภาษาอังกฤษในชีวิตประจำวัน", subtitle: "Everyday English · บทสนทนาในสถานการณ์จริง")
        case "vi":
            self.init(label: "KHÓA HỘI THOẠI", title: "Tiếng Anh giao tiếp hằng ngày", subtitle: "Everyday English · hội thoại thực tế")
        case "tr":
            self.init(label: "KONUŞMA KURSU", title: "Günlük İngilizce", subtitle: "Everyday English · pratik konuşmalar")
        default:
            self.init(label: "SPEAKING COURSE", title: "Everyday English", subtitle: "Everyday English · practical conversations")
        }
    }

    init(label: String, title: String, subtitle: String) {
        self.label = label
        self.title = title
        self.subtitle = subtitle
    }

    static func localized(
        collectionID: String,
        fallbackLabel: String,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) -> Self {
        guard collectionID == "ai-practice" else {
            return Self(label: fallbackLabel, title: fallbackTitle, subtitle: fallbackSubtitle)
        }
        return current
    }
}
