import Foundation

struct StudyRepeatCopy: Sendable {
    let preparingMicrophone: String
    let microphoneDenied: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(preparingMicrophone: "正在準備麥克風", microphoneDenied: "需要麥克風權限才能進行跟讀練習") }
        if id.hasPrefix("zh") { return Self(preparingMicrophone: "正在准备麦克风", microphoneDenied: "需要麦克风权限才能进行跟读练习") }
        if id.hasPrefix("ja") { return Self(preparingMicrophone: "マイクを準備しています", microphoneDenied: "音読練習にはマイクの許可が必要です") }
        if id.hasPrefix("ko") { return Self(preparingMicrophone: "마이크 준비 중", microphoneDenied: "따라 말하기 연습에는 마이크 권한이 필요합니다") }
        if id.hasPrefix("es") { return Self(preparingMicrophone: "Preparando el micrófono", microphoneDenied: "Necesitas dar permiso al micrófono para practicar") }
        if id.hasPrefix("pt") { return Self(preparingMicrophone: "Preparando o microfone", microphoneDenied: "Você precisa permitir o microfone para praticar") }
        if id.hasPrefix("fr") { return Self(preparingMicrophone: "Préparation du microphone", microphoneDenied: "L’autorisation du microphone est nécessaire pour pratiquer") }
        if id.hasPrefix("de") { return Self(preparingMicrophone: "Mikrofon wird vorbereitet", microphoneDenied: "Für die Sprechübung ist der Mikrofonzugriff erforderlich") }
        if id.hasPrefix("it") { return Self(preparingMicrophone: "Preparazione del microfono", microphoneDenied: "Per esercitarti devi consentire l’accesso al microfono") }
        if id.hasPrefix("ru") { return Self(preparingMicrophone: "Подготовка микрофона", microphoneDenied: "Для практики нужна доступность микрофона") }
        if id.hasPrefix("ar") { return Self(preparingMicrophone: "جارٍ تجهيز الميكروفون", microphoneDenied: "يلزم السماح بالوصول إلى الميكروفون للتدرب على النطق") }
        if id.hasPrefix("id") { return Self(preparingMicrophone: "Menyiapkan mikrofon", microphoneDenied: "Izin mikrofon diperlukan untuk berlatih berbicara") }
        if id.hasPrefix("th") { return Self(preparingMicrophone: "กำลังเตรียมไมโครโฟน", microphoneDenied: "ต้องอนุญาตให้ใช้ไมโครโฟนเพื่อฝึกพูดตาม") }
        if id.hasPrefix("vi") { return Self(preparingMicrophone: "Đang chuẩn bị micrô", microphoneDenied: "Cần cấp quyền dùng micrô để luyện nói") }
        if id.hasPrefix("tr") { return Self(preparingMicrophone: "Mikrofon hazırlanıyor", microphoneDenied: "Konuşma pratiği için mikrofon izni gerekir") }
        return Self(preparingMicrophone: "Preparing microphone", microphoneDenied: "Microphone permission is required to practice speaking")
    }
}
