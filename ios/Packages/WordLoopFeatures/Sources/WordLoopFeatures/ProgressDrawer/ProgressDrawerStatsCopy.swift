import Foundation

struct ProgressDrawerStatsCopy: Sendable {
    let progress: String
    let studied: String
    let mastered: String
    let learning: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(progress: "課程學習進度", studied: "已學習", mastered: "已掌握", learning: "學習中") }
        if id.hasPrefix("zh") { return Self(progress: "课程学习进度", studied: "已学习", mastered: "已掌握", learning: "学习中") }
        if id.hasPrefix("ja") { return Self(progress: "コースの学習進捗", studied: "学習済み", mastered: "習得済み", learning: "学習中") }
        if id.hasPrefix("ko") { return Self(progress: "코스 학습 진도", studied: "학습", mastered: "숙달", learning: "학습 중") }
        if id.hasPrefix("es") { return Self(progress: "Progreso del curso", studied: "Estudiado", mastered: "Dominado", learning: "En curso") }
        if id.hasPrefix("pt") { return Self(progress: "Progresso do curso", studied: "Estudado", mastered: "Dominado", learning: "Em estudo") }
        if id.hasPrefix("fr") { return Self(progress: "Progression du cours", studied: "Étudié", mastered: "Maîtrisé", learning: "En cours") }
        if id.hasPrefix("de") { return Self(progress: "Kursfortschritt", studied: "Gelernt", mastered: "Beherrscht", learning: "In Bearbeitung") }
        if id.hasPrefix("it") { return Self(progress: "Progressi del corso", studied: "Studiato", mastered: "Consolidato", learning: "In corso") }
        if id.hasPrefix("ru") { return Self(progress: "Прогресс курса", studied: "Изучено", mastered: "Освоено", learning: "В процессе") }
        if id.hasPrefix("ar") { return Self(progress: "تقدم الدورة", studied: "تمت دراسته", mastered: "متقن", learning: "قيد التعلم") }
        if id.hasPrefix("id") { return Self(progress: "Kemajuan kursus", studied: "Dipelajari", mastered: "Dikuasai", learning: "Sedang dipelajari") }
        if id.hasPrefix("th") { return Self(progress: "ความคืบหน้าของบทเรียน", studied: "เรียนแล้ว", mastered: "เชี่ยวชาญแล้ว", learning: "กำลังเรียน") }
        if id.hasPrefix("vi") { return Self(progress: "Tiến độ khóa học", studied: "Đã học", mastered: "Đã thành thạo", learning: "Đang học") }
        if id.hasPrefix("tr") { return Self(progress: "Kurs ilerlemesi", studied: "Çalışıldı", mastered: "Öğrenildi", learning: "Çalışılıyor") }
        return Self(progress: "Course progress", studied: "Studied", mastered: "Mastered", learning: "Learning")
    }
}
