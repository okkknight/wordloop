import Foundation

struct CourseDrawerStatusCopy: Sendable {
    let expanded: String
    let collapsed: String
    let current: String
    let notSelected: String
    let completed: String

    static var currentLocale: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(expanded: "已展開", collapsed: "已收合", current: "目前課程", notSelected: "未選擇", completed: "已完成") }
        if id.hasPrefix("zh") { return Self(expanded: "已展开", collapsed: "已收起", current: "当前课程", notSelected: "未选择", completed: "已完成") }
        if id.hasPrefix("ja") { return Self(expanded: "展開済み", collapsed: "折りたたみ済み", current: "現在のコース", notSelected: "未選択", completed: "完了") }
        if id.hasPrefix("ko") { return Self(expanded: "펼침", collapsed: "접힘", current: "현재 코스", notSelected: "선택 안 함", completed: "완료") }
        if id.hasPrefix("es") { return Self(expanded: "Expandido", collapsed: "Contraído", current: "Curso actual", notSelected: "No seleccionado", completed: "Completado") }
        if id.hasPrefix("pt") { return Self(expanded: "Expandido", collapsed: "Recolhido", current: "Curso atual", notSelected: "Não selecionado", completed: "Concluído") }
        if id.hasPrefix("fr") { return Self(expanded: "Développé", collapsed: "Réduit", current: "Cours actuel", notSelected: "Non sélectionné", completed: "Terminé") }
        if id.hasPrefix("de") { return Self(expanded: "Ausgeklappt", collapsed: "Eingeklappt", current: "Aktueller Kurs", notSelected: "Nicht ausgewählt", completed: "Abgeschlossen") }
        if id.hasPrefix("it") { return Self(expanded: "Espanso", collapsed: "Compresso", current: "Corso attuale", notSelected: "Non selezionato", completed: "Completato") }
        if id.hasPrefix("ru") { return Self(expanded: "Развёрнуто", collapsed: "Свёрнуто", current: "Текущий курс", notSelected: "Не выбран", completed: "Завершено") }
        if id.hasPrefix("ar") { return Self(expanded: "موسّع", collapsed: "مطوي", current: "الدورة الحالية", notSelected: "غير محددة", completed: "مكتملة") }
        if id.hasPrefix("id") { return Self(expanded: "Diperluas", collapsed: "Diciutkan", current: "Kursus saat ini", notSelected: "Tidak dipilih", completed: "Selesai") }
        if id.hasPrefix("th") { return Self(expanded: "ขยายแล้ว", collapsed: "ย่อแล้ว", current: "บทเรียนปัจจุบัน", notSelected: "ยังไม่ได้เลือก", completed: "เรียนจบแล้ว") }
        if id.hasPrefix("vi") { return Self(expanded: "Đã mở rộng", collapsed: "Đã thu gọn", current: "Khóa học hiện tại", notSelected: "Chưa chọn", completed: "Đã hoàn thành") }
        if id.hasPrefix("tr") { return Self(expanded: "Genişletildi", collapsed: "Daraltıldı", current: "Mevcut kurs", notSelected: "Seçilmedi", completed: "Tamamlandı") }
        return Self(expanded: "Expanded", collapsed: "Collapsed", current: "Current course", notSelected: "Not selected", completed: "Completed")
    }
}
