import Foundation

struct StudyActionCopy: Sendable {
    let page: String
    let youSaid: String
    let tooEasy: String
    let next: String
    let playCurrent: String
    let mastery: String
    let mode: String
    let hiddenContent: String
    let focusPrefix: String
    let autoplay: String
    let autoplayOn: String
    let resume: String
    let pause: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(page: "主要學習頁", youSaid: "你說的是", tooEasy: "太簡單", next: "下一個", playCurrent: "播放目前學習內容", mastery: "熟練度", mode: "學習模式", hiddenContent: "學習內容已隱藏", focusPrefix: "重點表達：", autoplay: "自動播放", autoplayOn: "自動播放中", resume: "繼續", pause: "暫停") }
        if id.hasPrefix("zh") { return Self(page: "主学习页", youSaid: "你说的是", tooEasy: "太简单", next: "下一条", playCurrent: "播放当前学习内容", mastery: "熟练度", mode: "学习模式", hiddenContent: "学习内容已隐藏", focusPrefix: "重点表达：", autoplay: "自动播放", autoplayOn: "自动播放中", resume: "继续", pause: "暂停") }
        if id.hasPrefix("ja") { return Self(page: "メイン学習ページ", youSaid: "あなたの発音", tooEasy: "簡単すぎる", next: "次へ", playCurrent: "現在の学習内容を再生", mastery: "習熟度", mode: "学習モード", hiddenContent: "学習内容を非表示", focusPrefix: "重要表現：", autoplay: "自動再生", autoplayOn: "自動再生中", resume: "再開", pause: "一時停止") }
        if id.hasPrefix("ko") { return Self(page: "학습 페이지", youSaid: "말한 내용", tooEasy: "너무 쉬워요", next: "다음", playCurrent: "현재 학습 내용 재생", mastery: "숙련도", mode: "학습 모드", hiddenContent: "학습 내용 숨김", focusPrefix: "핵심 표현: ", autoplay: "자동 재생", autoplayOn: "자동 재생 중", resume: "재개", pause: "일시 정지") }
        if id.hasPrefix("es") { return Self(page: "Página principal de estudio", youSaid: "Has dicho", tooEasy: "Demasiado fácil", next: "Siguiente", playCurrent: "Reproducir el contenido actual", mastery: "Dominio", mode: "Modo de estudio", hiddenContent: "Contenido oculto", focusPrefix: "Expresiones clave: ", autoplay: "REPRODUCCIÓN AUTO", autoplayOn: "REPRODUCCIÓN AUTO ACTIVA", resume: "REANUDAR", pause: "PAUSAR") }
        if id.hasPrefix("pt") { return Self(page: "Página principal de estudo", youSaid: "Você disse", tooEasy: "Muito fácil", next: "Próximo", playCurrent: "Reproduzir conteúdo atual", mastery: "Domínio", mode: "Modo de estudo", hiddenContent: "Conteúdo oculto", focusPrefix: "Expressões-chave: ", autoplay: "REPRODUÇÃO AUTO", autoplayOn: "REPRODUÇÃO AUTO ATIVA", resume: "RETOMAR", pause: "PAUSAR") }
        if id.hasPrefix("fr") { return Self(page: "Page d’étude principale", youSaid: "Vous avez dit", tooEasy: "Trop facile", next: "Suivant", playCurrent: "Lire le contenu actuel", mastery: "Maîtrise", mode: "Mode d’étude", hiddenContent: "Contenu masqué", focusPrefix: "Expressions clés : ", autoplay: "LECTURE AUTO", autoplayOn: "LECTURE AUTO ACTIVE", resume: "REPRENDRE", pause: "PAUSE") }
        if id.hasPrefix("de") { return Self(page: "Hauptlernseite", youSaid: "Du hast gesagt", tooEasy: "Zu einfach", next: "Weiter", playCurrent: "Aktuellen Lerninhalt abspielen", mastery: "Beherrschung", mode: "Lernmodus", hiddenContent: "Lerninhalt ausgeblendet", focusPrefix: "Wichtige Ausdrücke: ", autoplay: "AUTO-WIEDERGABE", autoplayOn: "AUTO-WIEDERGABE AKTIV", resume: "FORTSETZEN", pause: "PAUSIEREN") }
        if id.hasPrefix("it") { return Self(page: "Pagina di studio principale", youSaid: "Hai detto", tooEasy: "Troppo facile", next: "Avanti", playCurrent: "Riproduci il contenuto attuale", mastery: "Padronanza", mode: "Modalità di studio", hiddenContent: "Contenuto nascosto", focusPrefix: "Espressioni chiave: ", autoplay: "RIPRODUZIONE AUTO", autoplayOn: "RIPRODUZIONE AUTO ATTIVA", resume: "RIPRENDI", pause: "PAUSA") }
        if id.hasPrefix("ru") { return Self(page: "Главная страница обучения", youSaid: "Вы сказали", tooEasy: "Слишком легко", next: "Далее", playCurrent: "Воспроизвести текущий материал", mastery: "Освоение", mode: "Режим обучения", hiddenContent: "Содержимое скрыто", focusPrefix: "Ключевые выражения: ", autoplay: "АВТОВОСПРОИЗВЕДЕНИЕ", autoplayOn: "АВТОВОСПРОИЗВЕДЕНИЕ ВКЛ.", resume: "ПРОДОЛЖИТЬ", pause: "ПАУЗА") }
        if id.hasPrefix("ar") { return Self(page: "صفحة التعلّم الرئيسية", youSaid: "قلتَ", tooEasy: "سهل جدًا", next: "التالي", playCurrent: "تشغيل مادة التعلّم الحالية", mastery: "الإتقان", mode: "وضع التعلّم", hiddenContent: "المحتوى مخفي", focusPrefix: "التعبيرات المهمة: ", autoplay: "تشغيل تلقائي", autoplayOn: "التشغيل التلقائي مفعّل", resume: "استئناف", pause: "إيقاف مؤقت") }
        if id.hasPrefix("id") { return Self(page: "Halaman belajar utama", youSaid: "Anda berkata", tooEasy: "Terlalu mudah", next: "Berikutnya", playCurrent: "Putar materi belajar saat ini", mastery: "Penguasaan", mode: "Mode belajar", hiddenContent: "Konten belajar disembunyikan", focusPrefix: "Ungkapan penting: ", autoplay: "PUTAR OTOMATIS", autoplayOn: "PUTAR OTOMATIS AKTIF", resume: "LANJUTKAN", pause: "JEDA") }
        if id.hasPrefix("th") { return Self(page: "หน้าฝึกเรียนหลัก", youSaid: "คุณพูดว่า", tooEasy: "ง่ายเกินไป", next: "ถัดไป", playCurrent: "เล่นเนื้อหาที่กำลังเรียน", mastery: "ความชำนาญ", mode: "โหมดการเรียน", hiddenContent: "ซ่อนเนื้อหาการเรียน", focusPrefix: "สำนวนสำคัญ: ", autoplay: "เล่นอัตโนมัติ", autoplayOn: "กำลังเล่นอัตโนมัติ", resume: "เล่นต่อ", pause: "หยุดชั่วคราว") }
        if id.hasPrefix("vi") { return Self(page: "Trang học chính", youSaid: "Bạn đã nói", tooEasy: "Quá dễ", next: "Tiếp theo", playCurrent: "Phát nội dung đang học", mastery: "Mức độ thành thạo", mode: "Chế độ học", hiddenContent: "Đã ẩn nội dung học", focusPrefix: "Cụm từ chính: ", autoplay: "TỰ ĐỘNG PHÁT", autoplayOn: "ĐANG TỰ ĐỘNG PHÁT", resume: "TIẾP TỤC", pause: "TẠM DỪNG") }
        if id.hasPrefix("tr") { return Self(page: "Ana çalışma sayfası", youSaid: "Söylediğiniz", tooEasy: "Çok kolay", next: "Sonraki", playCurrent: "Mevcut içeriği oynat", mastery: "Ustalık", mode: "Çalışma modu", hiddenContent: "Öğrenme içeriği gizli", focusPrefix: "Önemli ifadeler: ", autoplay: "OTOMATİK OYNAT", autoplayOn: "OTOMATİK OYNATMA AÇIK", resume: "DEVAM ET", pause: "DURAKLAT") }
        return Self(page: "Main study page", youSaid: "You said", tooEasy: "Too easy", next: "NEXT", playCurrent: "Play current study content", mastery: "Mastery", mode: "Study mode", hiddenContent: "Learning content hidden", focusPrefix: "Key expressions: ", autoplay: "AUTOPLAY", autoplayOn: "AUTOPLAY ON", resume: "RESUME", pause: "PAUSE")
    }
}
