import Foundation

struct StudyAccessibilityCopy: Sendable {
    let waveform: String
    let progressTemplate: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(waveform: "跟讀狀態波形", progressTemplate: "%@，第 %d 項，共 %d 項") }
        if id.hasPrefix("zh") { return Self(waveform: "跟读状态波形", progressTemplate: "%@，第 %d 条，共 %d 条") }
        if id.hasPrefix("ja") { return Self(waveform: "音読状態の波形", progressTemplate: "%@、%d番目、全%d件") }
        if id.hasPrefix("ko") { return Self(waveform: "따라 말하기 상태 파형", progressTemplate: "%@, %d번째, 총 %d개") }
        if id.hasPrefix("es") { return Self(waveform: "Forma de onda del estado de repetición", progressTemplate: "%@, elemento %d de %d") }
        if id.hasPrefix("pt") { return Self(waveform: "Forma de onda do estado de repetição", progressTemplate: "%@, item %d de %d") }
        if id.hasPrefix("fr") { return Self(waveform: "Onde de l’état de répétition", progressTemplate: "%@, élément %d sur %d") }
        if id.hasPrefix("de") { return Self(waveform: "Wellenform des Nachsprechstatus", progressTemplate: "%@, %d. von %d") }
        if id.hasPrefix("it") { return Self(waveform: "Forma d’onda dello stato di ripetizione", progressTemplate: "%@, elemento %d di %d") }
        if id.hasPrefix("ru") { return Self(waveform: "Форма сигнала режима повторения", progressTemplate: "%@, элемент %d из %d") }
        if id.hasPrefix("ar") { return Self(waveform: "موجة حالة التكرار", progressTemplate: "%@، العنصر %d من %d") }
        if id.hasPrefix("id") { return Self(waveform: "Gelombang status menirukan", progressTemplate: "%@, item %d dari %d") }
        if id.hasPrefix("th") { return Self(waveform: "รูปคลื่นสถานะการพูดตาม", progressTemplate: "%@ รายการที่ %d จาก %d") }
        if id.hasPrefix("vi") { return Self(waveform: "Dạng sóng trạng thái nói theo", progressTemplate: "%@, mục %d trên %d") }
        if id.hasPrefix("tr") { return Self(waveform: "Tekrarlama durumu dalga biçimi", progressTemplate: "%@, %d / %d") }
        return Self(waveform: "Repeat status waveform", progressTemplate: "%@, item %d of %d")
    }

    func progress(course: String, current: Int, total: Int) -> String {
        String(format: progressTemplate, course, current, total)
    }
}
