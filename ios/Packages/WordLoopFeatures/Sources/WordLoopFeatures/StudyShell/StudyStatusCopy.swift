import Foundation

struct StudyStatusCopy: Sendable {
    let idle: String
    let connecting: String
    let ready: String
    let playing: String
    let speaking: String
    let scoring: String
    let passed: String
    let paused: String
    let retry: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(idle: "待機", connecting: "連線中", ready: "準備好了", playing: "聆聽中", speaking: "跟讀中", scoring: "檢查中", passed: "太棒了", paused: "已暫停", retry: "再試一次") }
        if id.hasPrefix("zh") { return Self(idle: "待机", connecting: "连接中", ready: "准备好了", playing: "播放中", speaking: "跟读中", scoring: "检查中", passed: "太棒了", paused: "已暂停", retry: "再试一次") }
        if id.hasPrefix("ja") { return Self(idle: "待機中", connecting: "接続中", ready: "準備完了", playing: "再生中", speaking: "音読中", scoring: "確認中", passed: "すばらしい", paused: "一時停止中", retry: "もう一度") }
        if id.hasPrefix("ko") { return Self(idle: "대기 중", connecting: "연결 중", ready: "준비 완료", playing: "듣는 중", speaking: "따라 말하는 중", scoring: "확인 중", passed: "잘했어요", paused: "일시 정지", retry: "다시 시도") }
        if id.hasPrefix("es") { return Self(idle: "EN ESPERA", connecting: "CONECTANDO", ready: "LISTO", playing: "ESCUCHANDO", speaking: "REPITIENDO", scoring: "COMPROBANDO", passed: "GENIAL", paused: "EN PAUSA", retry: "INTÉNTALO DE NUEVO") }
        if id.hasPrefix("pt") { return Self(idle: "AGUARDANDO", connecting: "CONECTANDO", ready: "PRONTO", playing: "OUVINDO", speaking: "REPETINDO", scoring: "VERIFICANDO", passed: "MUITO BEM", paused: "PAUSADO", retry: "TENTE NOVAMENTE") }
        if id.hasPrefix("fr") { return Self(idle: "EN ATTENTE", connecting: "CONNEXION", ready: "PRÊT", playing: "ÉCOUTE", speaking: "RÉPÉTITION", scoring: "VÉRIFICATION", passed: "BRAVO", paused: "EN PAUSE", retry: "RÉESSAYEZ") }
        if id.hasPrefix("de") { return Self(idle: "BEREIT", connecting: "VERBINDUNG", ready: "BEREIT", playing: "HÖREN", speaking: "NACHPRECHEN", scoring: "PRÜFUNG", passed: "SUPER", paused: "PAUSIERT", retry: "NOCH EINMAL") }
        if id.hasPrefix("it") { return Self(idle: "IN ATTESA", connecting: "CONNESSIONE", ready: "PRONTO", playing: "ASCOLTO", speaking: "RIPETIZIONE", scoring: "CONTROLLO", passed: "BRAVO", paused: "IN PAUSA", retry: "RIPROVA") }
        if id.hasPrefix("ru") { return Self(idle: "ОЖИДАНИЕ", connecting: "ПОДКЛЮЧЕНИЕ", ready: "ГОТОВО", playing: "СЛУШАЕМ", speaking: "ПОВТОРЯЙТЕ", scoring: "ПРОВЕРКА", passed: "ОТЛИЧНО", paused: "ПАУЗА", retry: "ПОВТОРИТЕ") }
        if id.hasPrefix("ar") { return Self(idle: "في الانتظار", connecting: "جارٍ الاتصال", ready: "جاهز", playing: "جارٍ الاستماع", speaking: "جارٍ التكرار", scoring: "جارٍ التحقق", passed: "رائع", paused: "متوقف مؤقتًا", retry: "حاول مرة أخرى") }
        if id.hasPrefix("id") { return Self(idle: "MENUNGGU", connecting: "MENGHUBUNGKAN", ready: "SIAP", playing: "MENDENGARKAN", speaking: "MENIRUKAN", scoring: "MEMERIKSA", passed: "HEBAT", paused: "DIJEDA", retry: "COBA LAGI") }
        if id.hasPrefix("th") { return Self(idle: "พร้อมรอ", connecting: "กำลังเชื่อมต่อ", ready: "พร้อมแล้ว", playing: "กำลังฟัง", speaking: "กำลังพูดตาม", scoring: "กำลังตรวจสอบ", passed: "ยอดเยี่ยม", paused: "หยุดชั่วคราว", retry: "ลองอีกครั้ง") }
        if id.hasPrefix("vi") { return Self(idle: "ĐANG CHỜ", connecting: "ĐANG KẾT NỐI", ready: "SẴN SÀNG", playing: "ĐANG NGHE", speaking: "ĐANG NÓI THEO", scoring: "ĐANG KIỂM TRA", passed: "TUYỆT VỜI", paused: "ĐÃ TẠM DỪNG", retry: "THỬ LẠI") }
        if id.hasPrefix("tr") { return Self(idle: "BEKLEMEDE", connecting: "BAĞLANIYOR", ready: "HAZIR", playing: "DİNLENİYOR", speaking: "TEKRARLANIYOR", scoring: "KONTROL EDİLİYOR", passed: "HARİKA", paused: "DURAKLATILDI", retry: "TEKRAR DENE") }
        return Self(idle: "STANDBY", connecting: "CONNECTING", ready: "READY", playing: "LISTENING", speaking: "SPEAKING", scoring: "CHECKING", passed: "GREAT", paused: "PAUSED", retry: "TRY AGAIN")
    }
}
