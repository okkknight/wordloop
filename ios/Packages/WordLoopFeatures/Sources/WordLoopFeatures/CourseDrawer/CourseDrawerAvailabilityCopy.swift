import Foundation

struct CourseDrawerAvailabilityCopy: Sendable {
    let download: String
    let update: String
    let tryAgain: String
    let offline: String
    let freeUpSpace: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(download: "下載", update: "更新", tryAgain: "重試", offline: "離線", freeUpSpace: "釋放空間") }
        if id.hasPrefix("zh") { return Self(download: "下载", update: "更新", tryAgain: "重试", offline: "离线", freeUpSpace: "释放空间") }
        if id.hasPrefix("ja") { return Self(download: "ダウンロード", update: "更新", tryAgain: "再試行", offline: "オフライン", freeUpSpace: "容量を空ける") }
        if id.hasPrefix("ko") { return Self(download: "다운로드", update: "업데이트", tryAgain: "다시 시도", offline: "오프라인", freeUpSpace: "공간 확보") }
        if id.hasPrefix("es") { return Self(download: "DESCARGAR", update: "ACTUALIZAR", tryAgain: "REINTENTAR", offline: "SIN CONEXIÓN", freeUpSpace: "LIBERAR ESPACIO") }
        if id.hasPrefix("pt") { return Self(download: "BAIXAR", update: "ATUALIZAR", tryAgain: "TENTAR NOVAMENTE", offline: "OFF-LINE", freeUpSpace: "LIBERAR ESPAÇO") }
        if id.hasPrefix("fr") { return Self(download: "TÉLÉCHARGER", update: "METTRE À JOUR", tryAgain: "RÉESSAYER", offline: "HORS LIGNE", freeUpSpace: "LIBÉRER DE L’ESPACE") }
        if id.hasPrefix("de") { return Self(download: "HERUNTERLADEN", update: "AKTUALISIEREN", tryAgain: "ERNEUT VERSUCHEN", offline: "OFFLINE", freeUpSpace: "SPEICHER FREIGEBEN") }
        if id.hasPrefix("it") { return Self(download: "SCARICA", update: "AGGIORNA", tryAgain: "RIPROVA", offline: "OFFLINE", freeUpSpace: "LIBERA SPAZIO") }
        if id.hasPrefix("ru") { return Self(download: "СКАЧАТЬ", update: "ОБНОВИТЬ", tryAgain: "ПОВТОРИТЬ", offline: "ОФЛАЙН", freeUpSpace: "ОСВОБОДИТЬ МЕСТО") }
        if id.hasPrefix("ar") { return Self(download: "تنزيل", update: "تحديث", tryAgain: "إعادة المحاولة", offline: "دون اتصال", freeUpSpace: "تحرير مساحة") }
        if id.hasPrefix("id") { return Self(download: "UNDUH", update: "PERBARUI", tryAgain: "COBA LAGI", offline: "OFFLINE", freeUpSpace: "KOSONGKAN RUANG") }
        if id.hasPrefix("th") { return Self(download: "ดาวน์โหลด", update: "อัปเดต", tryAgain: "ลองอีกครั้ง", offline: "ออฟไลน์", freeUpSpace: "เพิ่มพื้นที่ว่าง") }
        if id.hasPrefix("vi") { return Self(download: "TẢI XUỐNG", update: "CẬP NHẬT", tryAgain: "THỬ LẠI", offline: "NGOẠI TUYẾN", freeUpSpace: "GIẢI PHÓNG DUNG LƯỢNG") }
        if id.hasPrefix("tr") { return Self(download: "İNDİR", update: "GÜNCELLE", tryAgain: "TEKRAR DENE", offline: "ÇEVRİMDIŞI", freeUpSpace: "YER AÇ") }
        return Self(download: "DOWNLOAD", update: "UPDATE", tryAgain: "TRY AGAIN", offline: "OFFLINE", freeUpSpace: "FREE UP SPACE")
    }

    func title(for availability: CourseDrawerAvailability) -> String {
        switch availability {
        case .download: return download
        case .update: return update
        case .tryAgain: return tryAgain
        case .offline: return offline
        case .freeUpSpace: return freeUpSpace
        default: return availability.rawValue
        }
    }
}
