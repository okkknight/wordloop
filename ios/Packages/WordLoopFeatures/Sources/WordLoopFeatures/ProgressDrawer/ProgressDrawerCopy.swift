import Foundation

struct ProgressDrawerCopy: Sendable {
    let page: String
    let close: String
    let kicker: String
    let empty: String
    let search: String
    let delete: String
    let deleteQuestion: String
    let cancel: String
    let acknowledge: String
    let deleteError: String
    let retryNetwork: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") {
            return Self(page: "學習進度", close: "關閉學習進度", kicker: "你的進度", empty: "沒有符合的學習記錄", search: "搜尋學習記錄", delete: "刪除我的學習資料", deleteQuestion: "刪除全部學習資料？", cancel: "取消", acknowledge: "知道了", deleteError: "暫時無法刪除資料", retryNetwork: "請檢查網路後重試。")
        }
        if id.hasPrefix("zh") {
            return Self(page: "学习进度", close: "关闭学习进度", kicker: "你的进度", empty: "没有匹配的学习记录", search: "搜索学习记录", delete: "删除我的学习数据", deleteQuestion: "删除全部学习数据？", cancel: "取消", acknowledge: "知道了", deleteError: "暂时无法删除数据", retryNetwork: "请检查网络后重试。")
        }
        if id.hasPrefix("ja") { return Self(page: "学習の進捗", close: "学習の進捗を閉じる", kicker: "あなたの進捗", empty: "一致する学習記録がありません", search: "学習記録を検索", delete: "学習データを削除", deleteQuestion: "学習データをすべて削除しますか？", cancel: "キャンセル", acknowledge: "了解", deleteError: "データを削除できません", retryNetwork: "ネットワークを確認して、もう一度お試しください。") }
        if id.hasPrefix("ko") { return Self(page: "학습 진도", close: "학습 진도 닫기", kicker: "내 진도", empty: "일치하는 학습 기록이 없습니다", search: "학습 기록 검색", delete: "내 학습 데이터 삭제", deleteQuestion: "학습 데이터를 모두 삭제할까요?", cancel: "취소", acknowledge: "확인", deleteError: "데이터를 삭제할 수 없습니다", retryNetwork: "네트워크를 확인하고 다시 시도해 주세요.") }
        if id.hasPrefix("es") { return Self(page: "Progreso", close: "Cerrar progreso", kicker: "TU PROGRESO", empty: "No hay registros coincidentes", search: "Buscar registros", delete: "ELIMINAR MIS DATOS", deleteQuestion: "¿Eliminar todos los datos de aprendizaje?", cancel: "Cancelar", acknowledge: "Entendido", deleteError: "No se pueden eliminar los datos", retryNetwork: "Comprueba la red e inténtalo de nuevo.") }
        if id.hasPrefix("pt") { return Self(page: "Progresso", close: "Fechar progresso", kicker: "SEU PROGRESSO", empty: "Nenhum registro correspondente", search: "Buscar registros", delete: "EXCLUIR MEUS DADOS", deleteQuestion: "Excluir todos os dados de aprendizagem?", cancel: "Cancelar", acknowledge: "Entendi", deleteError: "Não foi possível excluir os dados", retryNetwork: "Verifique a rede e tente novamente.") }
        if id.hasPrefix("fr") { return Self(page: "Progression", close: "Fermer la progression", kicker: "VOTRE PROGRESSION", empty: "Aucun résultat correspondant", search: "Rechercher dans les progrès", delete: "SUPPRIMER MES DONNÉES", deleteQuestion: "Supprimer toutes les données d’apprentissage ?", cancel: "Annuler", acknowledge: "Compris", deleteError: "Impossible de supprimer les données", retryNetwork: "Vérifiez le réseau et réessayez.") }
        if id.hasPrefix("de") { return Self(page: "Fortschritt", close: "Fortschritt schließen", kicker: "DEIN FORTSCHRITT", empty: "Keine passenden Lernaufzeichnungen", search: "Lernaufzeichnungen suchen", delete: "MEINE LERNDATEN LÖSCHEN", deleteQuestion: "Alle Lerndaten löschen?", cancel: "Abbrechen", acknowledge: "Verstanden", deleteError: "Daten konnten nicht gelöscht werden", retryNetwork: "Netzwerk prüfen und erneut versuchen.") }
        if id.hasPrefix("it") { return Self(page: "Progressi", close: "Chiudi progressi", kicker: "I TUOI PROGRESSI", empty: "Nessun record corrispondente", search: "Cerca nei progressi", delete: "ELIMINA I MIEI DATI", deleteQuestion: "Eliminare tutti i dati di apprendimento?", cancel: "Annulla", acknowledge: "Capito", deleteError: "Impossibile eliminare i dati", retryNetwork: "Controlla la rete e riprova.") }
        if id.hasPrefix("ru") { return Self(page: "Прогресс", close: "Закрыть прогресс", kicker: "ВАШ ПРОГРЕСС", empty: "Подходящих записей нет", search: "Поиск по прогрессу", delete: "УДАЛИТЬ МОИ ДАННЫЕ", deleteQuestion: "Удалить все учебные данные?", cancel: "Отмена", acknowledge: "Понятно", deleteError: "Не удалось удалить данные", retryNetwork: "Проверьте сеть и повторите попытку.") }
        if id.hasPrefix("ar") { return Self(page: "التقدم", close: "إغلاق التقدم", kicker: "تقدمك", empty: "لا توجد سجلات تعليمية مطابقة", search: "البحث في سجلات التعلم", delete: "حذف بيانات تعلّمي", deleteQuestion: "هل تريد حذف جميع بيانات التعلم؟", cancel: "إلغاء", acknowledge: "حسنًا", deleteError: "تعذّر حذف البيانات", retryNetwork: "تحقق من الشبكة وحاول مرة أخرى.") }
        if id.hasPrefix("id") { return Self(page: "Kemajuan", close: "Tutup kemajuan", kicker: "KEMAJUAN ANDA", empty: "Tidak ada catatan belajar yang cocok", search: "Cari catatan belajar", delete: "HAPUS DATA BELAJAR SAYA", deleteQuestion: "Hapus semua data belajar?", cancel: "Batal", acknowledge: "Mengerti", deleteError: "Data tidak dapat dihapus", retryNetwork: "Periksa jaringan lalu coba lagi.") }
        if id.hasPrefix("th") { return Self(page: "ความคืบหน้า", close: "ปิดความคืบหน้า", kicker: "ความคืบหน้าของคุณ", empty: "ไม่พบประวัติการเรียนที่ตรงกัน", search: "ค้นหาประวัติการเรียน", delete: "ลบข้อมูลการเรียนของฉัน", deleteQuestion: "ลบข้อมูลการเรียนทั้งหมดไหม", cancel: "ยกเลิก", acknowledge: "รับทราบ", deleteError: "ลบข้อมูลไม่ได้", retryNetwork: "ตรวจสอบเครือข่ายแล้วลองอีกครั้ง") }
        if id.hasPrefix("vi") { return Self(page: "Tiến độ", close: "Đóng tiến độ", kicker: "TIẾN ĐỘ CỦA BẠN", empty: "Không có bản ghi học tập phù hợp", search: "Tìm bản ghi học tập", delete: "XÓA DỮ LIỆU HỌC CỦA TÔI", deleteQuestion: "Xóa toàn bộ dữ liệu học tập?", cancel: "Hủy", acknowledge: "Đã hiểu", deleteError: "Không thể xóa dữ liệu", retryNetwork: "Kiểm tra mạng rồi thử lại.") }
        if id.hasPrefix("tr") { return Self(page: "İlerleme", close: "İlerlemeyi kapat", kicker: "İLERLEMEN", empty: "Eşleşen öğrenme kaydı yok", search: "Öğrenme kayıtlarında ara", delete: "ÖĞRENME VERİLERİMİ SİL", deleteQuestion: "Tüm öğrenme verileri silinsin mi?", cancel: "İptal", acknowledge: "Anladım", deleteError: "Veriler silinemedi", retryNetwork: "Ağı kontrol edip tekrar deneyin.") }
        return Self(page: "Learning progress", close: "Close learning progress", kicker: "YOUR PROGRESS", empty: "No matching learning records", search: "Search learning records", delete: "DELETE MY LEARNING DATA", deleteQuestion: "Delete all learning data?", cancel: "Cancel", acknowledge: "Got it", deleteError: "Unable to delete data", retryNetwork: "Check your network and try again.")
    }
}
