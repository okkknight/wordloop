import Foundation

struct StudyVisibilityCopy: Sendable {
    let fullValue: String
    let focusValue: String
    let hiddenValue: String
    let showFull: String
    let showFocus: String
    let hide: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(fullValue: "顯示全文", focusValue: "只顯示重點表達", hiddenValue: "學習內容已隱藏", showFull: "顯示全文", showFocus: "只顯示重點表達", hide: "隱藏學習內容") }
        if id.hasPrefix("zh") { return Self(fullValue: "全文可见", focusValue: "仅重点表达可见", hiddenValue: "学习内容已隐藏", showFull: "显示全文", showFocus: "只显示重点表达", hide: "隐藏学习内容") }
        if id.hasPrefix("ja") { return Self(fullValue: "全文を表示", focusValue: "重要表現のみ表示", hiddenValue: "学習内容を非表示", showFull: "全文を表示", showFocus: "重要表現だけを表示", hide: "学習内容を隠す") }
        if id.hasPrefix("ko") { return Self(fullValue: "전체 내용 표시", focusValue: "핵심 표현만 표시", hiddenValue: "학습 내용 숨김", showFull: "전체 내용 표시", showFocus: "핵심 표현만 표시", hide: "학습 내용 숨기기") }
        if id.hasPrefix("es") { return Self(fullValue: "Texto completo visible", focusValue: "Solo expresiones clave visibles", hiddenValue: "Contenido oculto", showFull: "Mostrar texto completo", showFocus: "Mostrar solo expresiones clave", hide: "Ocultar contenido") }
        if id.hasPrefix("pt") { return Self(fullValue: "Texto completo visível", focusValue: "Apenas expressões-chave visíveis", hiddenValue: "Conteúdo oculto", showFull: "Mostrar texto completo", showFocus: "Mostrar apenas expressões-chave", hide: "Ocultar conteúdo") }
        if id.hasPrefix("fr") { return Self(fullValue: "Texte complet visible", focusValue: "Expressions clés visibles uniquement", hiddenValue: "Contenu masqué", showFull: "Afficher le texte complet", showFocus: "Afficher uniquement les expressions clés", hide: "Masquer le contenu") }
        if id.hasPrefix("de") { return Self(fullValue: "Vollständiger Text sichtbar", focusValue: "Nur wichtige Ausdrücke sichtbar", hiddenValue: "Lerninhalt ausgeblendet", showFull: "Vollständigen Text anzeigen", showFocus: "Nur wichtige Ausdrücke anzeigen", hide: "Lerninhalt ausblenden") }
        if id.hasPrefix("it") { return Self(fullValue: "Testo completo visibile", focusValue: "Visibili solo le espressioni chiave", hiddenValue: "Contenuto nascosto", showFull: "Mostra testo completo", showFocus: "Mostra solo le espressioni chiave", hide: "Nascondi contenuto") }
        if id.hasPrefix("ru") { return Self(fullValue: "Весь текст виден", focusValue: "Видны только ключевые выражения", hiddenValue: "Содержимое скрыто", showFull: "Показать весь текст", showFocus: "Показать только ключевые выражения", hide: "Скрыть содержимое") }
        if id.hasPrefix("ar") { return Self(fullValue: "النص الكامل ظاهر", focusValue: "التعبيرات المهمة فقط ظاهرة", hiddenValue: "المحتوى مخفي", showFull: "إظهار النص الكامل", showFocus: "إظهار التعبيرات المهمة فقط", hide: "إخفاء المحتوى") }
        if id.hasPrefix("id") { return Self(fullValue: "Teks lengkap terlihat", focusValue: "Hanya ungkapan penting yang terlihat", hiddenValue: "Konten pembelajaran disembunyikan", showFull: "Tampilkan teks lengkap", showFocus: "Tampilkan hanya ungkapan penting", hide: "Sembunyikan konten") }
        if id.hasPrefix("th") { return Self(fullValue: "แสดงข้อความทั้งหมด", focusValue: "แสดงเฉพาะสำนวนสำคัญ", hiddenValue: "ซ่อนเนื้อหาการเรียน", showFull: "แสดงข้อความทั้งหมด", showFocus: "แสดงเฉพาะสำนวนสำคัญ", hide: "ซ่อนเนื้อหา") }
        if id.hasPrefix("vi") { return Self(fullValue: "Hiện toàn bộ văn bản", focusValue: "Chỉ hiện cụm từ chính", hiddenValue: "Đã ẩn nội dung học", showFull: "Hiện toàn bộ văn bản", showFocus: "Chỉ hiện cụm từ chính", hide: "Ẩn nội dung") }
        if id.hasPrefix("tr") { return Self(fullValue: "Tam metin görünür", focusValue: "Yalnızca önemli ifadeler görünür", hiddenValue: "Öğrenme içeriği gizli", showFull: "Tam metni göster", showFocus: "Yalnızca önemli ifadeleri göster", hide: "İçeriği gizle") }
        return Self(fullValue: "Full text visible", focusValue: "Key expressions only", hiddenValue: "Learning content hidden", showFull: "Show full text", showFocus: "Show key expressions only", hide: "Hide learning content")
    }
}
