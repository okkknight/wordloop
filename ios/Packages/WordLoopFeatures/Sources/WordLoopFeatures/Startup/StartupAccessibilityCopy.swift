import Foundation

struct StartupAccessibilityCopy: Sendable {
    let processing: String
    let available: String
    let anonymous: String
    let named: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(processing: "處理中", available: "可以提交", anonymous: "已提交匿名使用者", named: "已提交使用者") }
        if id.hasPrefix("zh") { return Self(processing: "处理中", available: "可提交", anonymous: "已提交匿名用户", named: "已提交用户") }
        if id.hasPrefix("ja") { return Self(processing: "処理中", available: "送信可能", anonymous: "匿名ユーザーとして送信済み", named: "ユーザーとして送信済み") }
        if id.hasPrefix("ko") { return Self(processing: "처리 중", available: "제출 가능", anonymous: "익명 사용자로 제출됨", named: "사용자로 제출됨") }
        if id.hasPrefix("es") { return Self(processing: "Procesando", available: "Listo para enviar", anonymous: "Enviado como usuario anónimo", named: "Enviado como usuario") }
        if id.hasPrefix("pt") { return Self(processing: "Processando", available: "Pronto para enviar", anonymous: "Enviado como usuário anônimo", named: "Enviado como usuário") }
        if id.hasPrefix("fr") { return Self(processing: "Traitement en cours", available: "Prêt à envoyer", anonymous: "Envoyé anonymement", named: "Envoyé comme utilisateur") }
        if id.hasPrefix("de") { return Self(processing: "Wird verarbeitet", available: "Bereit zum Senden", anonymous: "Anonym gesendet", named: "Als Benutzer gesendet") }
        if id.hasPrefix("it") { return Self(processing: "Elaborazione", available: "Pronto per l’invio", anonymous: "Inviato come utente anonimo", named: "Inviato come utente") }
        if id.hasPrefix("ru") { return Self(processing: "Обработка", available: "Готово к отправке", anonymous: "Отправлено анонимно", named: "Отправлено как пользователь") }
        if id.hasPrefix("ar") { return Self(processing: "جارٍ المعالجة", available: "جاهز للإرسال", anonymous: "تم الإرسال كمستخدم مجهول", named: "تم الإرسال كمستخدم") }
        if id.hasPrefix("id") { return Self(processing: "Memproses", available: "Siap dikirim", anonymous: "Dikirim sebagai pengguna anonim", named: "Dikirim sebagai pengguna") }
        if id.hasPrefix("th") { return Self(processing: "กำลังประมวลผล", available: "พร้อมส่ง", anonymous: "ส่งในฐานะผู้ใช้ไม่ระบุชื่อแล้ว", named: "ส่งในฐานะผู้ใช้แล้ว") }
        if id.hasPrefix("vi") { return Self(processing: "Đang xử lý", available: "Sẵn sàng gửi", anonymous: "Đã gửi với tư cách người dùng ẩn danh", named: "Đã gửi với tư cách người dùng") }
        if id.hasPrefix("tr") { return Self(processing: "İşleniyor", available: "Gönderilmeye hazır", anonymous: "Anonim kullanıcı olarak gönderildi", named: "Kullanıcı olarak gönderildi") }
        return Self(processing: "Processing", available: "Ready to submit", anonymous: "Submitted anonymously", named: "Submitted as user")
    }
}
