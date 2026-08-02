import Foundation

struct StartupCopy: Sendable {
    let start: String
    let preparing: String
    let syncing: String
    let ready: String
    let retry: String
    let restoring: String
    let syncingProgress: String
    let offline: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(start: "開始", preparing: "準備中…", syncing: "同步中…", ready: "準備好了", retry: "重試", restoring: "正在恢復上次課程", syncingProgress: "正在同步學習進度", offline: "無法同步，仍可使用內建課程") }
        if id.hasPrefix("zh") { return Self(start: "开始", preparing: "准备中…", syncing: "同步中…", ready: "准备好了", retry: "重试", restoring: "正在恢复上次课程", syncingProgress: "正在同步学习进度", offline: "无法同步，仍可使用本地课程") }
        if id.hasPrefix("ja") { return Self(start: "開始", preparing: "準備中…", syncing: "同期中…", ready: "準備完了", retry: "再試行", restoring: "前回のコースを復元しています", syncingProgress: "学習の進捗を同期しています", offline: "同期できませんが、内蔵コースは利用できます") }
        if id.hasPrefix("ko") { return Self(start: "시작", preparing: "준비 중…", syncing: "동기화 중…", ready: "준비 완료", retry: "다시 시도", restoring: "지난 코스를 복원하는 중", syncingProgress: "학습 진도 동기화 중", offline: "동기화할 수 없지만 기본 코스를 사용할 수 있습니다") }
        if id.hasPrefix("es") { return Self(start: "Empezar", preparing: "Preparando…", syncing: "Sincronizando…", ready: "Listo", retry: "Reintentar", restoring: "Restaurando el último curso", syncingProgress: "Sincronizando el progreso", offline: "No se puede sincronizar, pero puedes usar los cursos incluidos") }
        if id.hasPrefix("pt") { return Self(start: "Começar", preparing: "Preparando…", syncing: "Sincronizando…", ready: "Pronto", retry: "Tentar novamente", restoring: "Restaurando o último curso", syncingProgress: "Sincronizando o progresso", offline: "Não foi possível sincronizar, mas você pode usar os cursos incluídos") }
        if id.hasPrefix("fr") { return Self(start: "Commencer", preparing: "Préparation…", syncing: "Synchronisation…", ready: "Prêt", retry: "Réessayer", restoring: "Restauration du dernier cours", syncingProgress: "Synchronisation de la progression", offline: "Synchronisation impossible, mais les cours inclus restent disponibles") }
        if id.hasPrefix("de") { return Self(start: "Starten", preparing: "Wird vorbereitet…", syncing: "Wird synchronisiert…", ready: "Bereit", retry: "Erneut versuchen", restoring: "Letzten Kurs wiederherstellen", syncingProgress: "Lernfortschritt synchronisieren", offline: "Synchronisierung nicht möglich, enthaltene Kurse bleiben verfügbar") }
        if id.hasPrefix("it") { return Self(start: "Inizia", preparing: "Preparazione…", syncing: "Sincronizzazione…", ready: "Pronto", retry: "Riprova", restoring: "Ripristino dell’ultimo corso", syncingProgress: "Sincronizzazione dei progressi", offline: "Impossibile sincronizzare, ma puoi usare i corsi inclusi") }
        if id.hasPrefix("ru") { return Self(start: "Начать", preparing: "Подготовка…", syncing: "Синхронизация…", ready: "Готово", retry: "Повторить", restoring: "Восстанавливаем последний курс", syncingProgress: "Синхронизируем прогресс", offline: "Синхронизация недоступна, но встроенные курсы можно использовать") }
        if id.hasPrefix("ar") { return Self(start: "ابدأ", preparing: "جارٍ التحضير…", syncing: "جارٍ المزامنة…", ready: "جاهز", retry: "إعادة المحاولة", restoring: "جارٍ استعادة آخر دورة", syncingProgress: "جارٍ مزامنة التقدم", offline: "تعذّرت المزامنة، لكن يمكنك استخدام الدورات المضمّنة") }
        if id.hasPrefix("id") { return Self(start: "Mulai", preparing: "Menyiapkan…", syncing: "Menyinkronkan…", ready: "Siap", retry: "Coba lagi", restoring: "Memulihkan kursus terakhir", syncingProgress: "Menyinkronkan kemajuan belajar", offline: "Tidak dapat menyinkronkan, tetapi kursus bawaan tetap dapat digunakan") }
        if id.hasPrefix("th") { return Self(start: "เริ่ม", preparing: "กำลังเตรียม…", syncing: "กำลังซิงค์…", ready: "พร้อม", retry: "ลองอีกครั้ง", restoring: "กำลังกู้คืนบทเรียนล่าสุด", syncingProgress: "กำลังซิงค์ความคืบหน้า", offline: "ซิงค์ไม่ได้ แต่ยังใช้บทเรียนที่มีในเครื่องได้") }
        if id.hasPrefix("vi") { return Self(start: "Bắt đầu", preparing: "Đang chuẩn bị…", syncing: "Đang đồng bộ…", ready: "Sẵn sàng", retry: "Thử lại", restoring: "Đang khôi phục khóa học gần đây", syncingProgress: "Đang đồng bộ tiến độ học", offline: "Không thể đồng bộ nhưng bạn vẫn dùng được các khóa học có sẵn") }
        if id.hasPrefix("tr") { return Self(start: "Başla", preparing: "Hazırlanıyor…", syncing: "Senkronize ediliyor…", ready: "Hazır", retry: "Tekrar dene", restoring: "Son kurs geri yükleniyor", syncingProgress: "İlerleme senkronize ediliyor", offline: "Senkronize edilemedi ancak yerleşik kursları kullanabilirsiniz") }
        return Self(start: "START", preparing: "PREPARING…", syncing: "SYNCING…", ready: "READY", retry: "RETRY", restoring: "Restoring your last course", syncingProgress: "Syncing learning progress", offline: "Unable to sync; included courses are still available")
    }
}
