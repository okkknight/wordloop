import Foundation

struct ProgressDrawerEntryCopy: Sendable {
    let studied: String
    let total: String
    let mastered: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(studied: "已學習", total: "共", mastered: "已掌握") }
        if id.hasPrefix("zh") { return Self(studied: "已学习", total: "共", mastered: "已掌握") }
        if id.hasPrefix("ja") { return Self(studied: "学習済み", total: "全", mastered: "習得済み") }
        if id.hasPrefix("ko") { return Self(studied: "학습", total: "총", mastered: "숙달") }
        if id.hasPrefix("es") { return Self(studied: "Estudiado", total: "de", mastered: "Dominado") }
        if id.hasPrefix("pt") { return Self(studied: "Estudado", total: "de", mastered: "Dominado") }
        if id.hasPrefix("fr") { return Self(studied: "Étudié", total: "sur", mastered: "Maîtrisé") }
        if id.hasPrefix("de") { return Self(studied: "Gelernt", total: "von", mastered: "Beherrscht") }
        if id.hasPrefix("it") { return Self(studied: "Studiato", total: "su", mastered: "Consolidato") }
        if id.hasPrefix("ru") { return Self(studied: "Изучено", total: "из", mastered: "Освоено") }
        if id.hasPrefix("ar") { return Self(studied: "تمت دراسته", total: "من", mastered: "متقن") }
        if id.hasPrefix("id") { return Self(studied: "Dipelajari", total: "dari", mastered: "Dikuasai") }
        if id.hasPrefix("th") { return Self(studied: "เรียนแล้ว", total: "จาก", mastered: "เชี่ยวชาญแล้ว") }
        if id.hasPrefix("vi") { return Self(studied: "Đã học", total: "trên", mastered: "Đã thành thạo") }
        if id.hasPrefix("tr") { return Self(studied: "Çalışıldı", total: "/", mastered: "Öğrenildi") }
        return Self(studied: "Studied", total: "of", mastered: "Mastered")
    }
}
