import Foundation

/// User-facing copy shared by the live iPhone study surfaces.
///
/// Values are kept in code for now because the course package and the App UI
/// must resolve the same locale without relying on a second generated bundle.
public struct WordLoopCopy: Sendable {
    public let course: String
    public let progress: String
    public let retry: String
    public let loadingCourse: String
    public let liveStudyPage: String
    public let selectCourse: String
    public let viewProgress: String
    public let coursePackages: String
    public let closeCourseSelector: String
    public let noMatchingCourse: String
    public let searchCourse: String

    public static var current: Self {
        Self(localeIdentifier: Locale.preferredLanguages.first ?? Locale.current.identifier)
    }

    public init(localeIdentifier: String) {
        let language = localeIdentifier.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init) ?? "en"

        switch language {
        case "zh":
            if localeIdentifier.lowercased().contains("hant") || localeIdentifier.lowercased().contains("tw") || localeIdentifier.lowercased().contains("hk") {
                self.init(course: "課程", progress: "進度", retry: "重試", loadingCourse: "正在載入課程", liveStudyPage: "學習頁面", selectCourse: "選擇課程", viewProgress: "查看學習進度", coursePackages: "課程包", closeCourseSelector: "關閉課程選擇器", noMatchingCourse: "沒有符合的課程", searchCourse: "搜尋課程")
            } else {
                self.init(course: "课程", progress: "进度", retry: "重试", loadingCourse: "正在加载课程", liveStudyPage: "学习页面", selectCourse: "选择课程", viewProgress: "查看学习进度", coursePackages: "课程包", closeCourseSelector: "关闭课程选择器", noMatchingCourse: "没有匹配的课程", searchCourse: "搜索课程")
            }
        case "ja": self.init(course: "コース", progress: "進捗", retry: "再試行", loadingCourse: "コースを読み込み中", liveStudyPage: "学習ページ", selectCourse: "コースを選択", viewProgress: "学習の進捗を見る", coursePackages: "コースパッケージ", closeCourseSelector: "コース選択を閉じる", noMatchingCourse: "一致するコースがありません", searchCourse: "コースを検索")
        case "ko": self.init(course: "코스", progress: "진도", retry: "다시 시도", loadingCourse: "코스를 불러오는 중", liveStudyPage: "학습 페이지", selectCourse: "코스 선택", viewProgress: "학습 진도 보기", coursePackages: "코스 패키지", closeCourseSelector: "코스 선택 닫기", noMatchingCourse: "일치하는 코스가 없습니다", searchCourse: "코스 검색")
        case "es": self.init(course: "CURSOS", progress: "PROGRESO", retry: "Reintentar", loadingCourse: "Cargando curso", liveStudyPage: "Página de estudio", selectCourse: "Seleccionar curso", viewProgress: "Ver el progreso", coursePackages: "PAQUETES DE CURSOS", closeCourseSelector: "Cerrar selector de cursos", noMatchingCourse: "No hay cursos coincidentes", searchCourse: "Buscar cursos")
        case "pt": self.init(course: "CURSOS", progress: "PROGRESSO", retry: "Tentar novamente", loadingCourse: "Carregando curso", liveStudyPage: "Página de estudo", selectCourse: "Selecionar curso", viewProgress: "Ver progresso", coursePackages: "PACOTES DE CURSOS", closeCourseSelector: "Fechar seletor de cursos", noMatchingCourse: "Nenhum curso correspondente", searchCourse: "Buscar cursos")
        case "fr": self.init(course: "COURS", progress: "PROGRÈS", retry: "Réessayer", loadingCourse: "Chargement du cours", liveStudyPage: "Page d’étude", selectCourse: "Choisir un cours", viewProgress: "Voir la progression", coursePackages: "PACKS DE COURS", closeCourseSelector: "Fermer le sélecteur de cours", noMatchingCourse: "Aucun cours correspondant", searchCourse: "Rechercher un cours")
        case "de": self.init(course: "KURSE", progress: "FORTSCHRITT", retry: "Erneut versuchen", loadingCourse: "Kurs wird geladen", liveStudyPage: "Lernseite", selectCourse: "Kurs auswählen", viewProgress: "Fortschritt anzeigen", coursePackages: "KURSPAKETE", closeCourseSelector: "Kursauswahl schließen", noMatchingCourse: "Keine passenden Kurse", searchCourse: "Kurse suchen")
        case "it": self.init(course: "CORSI", progress: "PROGRESSI", retry: "Riprova", loadingCourse: "Caricamento del corso", liveStudyPage: "Pagina di studio", selectCourse: "Scegli corso", viewProgress: "Vedi i progressi", coursePackages: "PACCHETTI CORSI", closeCourseSelector: "Chiudi selettore corsi", noMatchingCourse: "Nessun corso corrispondente", searchCourse: "Cerca corsi")
        case "ru": self.init(course: "КУРСЫ", progress: "ПРОГРЕСС", retry: "Повторить", loadingCourse: "Загрузка курса", liveStudyPage: "Страница обучения", selectCourse: "Выбрать курс", viewProgress: "Посмотреть прогресс", coursePackages: "ПАКЕТЫ КУРСОВ", closeCourseSelector: "Закрыть выбор курса", noMatchingCourse: "Подходящих курсов нет", searchCourse: "Поиск курсов")
        case "ar": self.init(course: "الدورات", progress: "التقدم", retry: "إعادة المحاولة", loadingCourse: "جارٍ تحميل الدورة", liveStudyPage: "صفحة التعلّم", selectCourse: "اختيار دورة", viewProgress: "عرض التقدم", coursePackages: "حزم الدورات", closeCourseSelector: "إغلاق اختيار الدورة", noMatchingCourse: "لا توجد دورات مطابقة", searchCourse: "البحث عن دورة")
        case "id": self.init(course: "KURSUS", progress: "KEMAJUAN", retry: "Coba lagi", loadingCourse: "Memuat kursus", liveStudyPage: "Halaman belajar", selectCourse: "Pilih kursus", viewProgress: "Lihat kemajuan", coursePackages: "PAKET KURSUS", closeCourseSelector: "Tutup pemilih kursus", noMatchingCourse: "Tidak ada kursus yang cocok", searchCourse: "Cari kursus")
        case "th": self.init(course: "บทเรียน", progress: "ความคืบหน้า", retry: "ลองอีกครั้ง", loadingCourse: "กำลังโหลดบทเรียน", liveStudyPage: "หน้าฝึกเรียน", selectCourse: "เลือกบทเรียน", viewProgress: "ดูความคืบหน้า", coursePackages: "แพ็กเกจบทเรียน", closeCourseSelector: "ปิดตัวเลือกบทเรียน", noMatchingCourse: "ไม่พบบทเรียนที่ตรงกัน", searchCourse: "ค้นหาบทเรียน")
        case "vi": self.init(course: "KHÓA HỌC", progress: "TIẾN ĐỘ", retry: "Thử lại", loadingCourse: "Đang tải khóa học", liveStudyPage: "Trang học", selectCourse: "Chọn khóa học", viewProgress: "Xem tiến độ", coursePackages: "GÓI KHÓA HỌC", closeCourseSelector: "Đóng bộ chọn khóa học", noMatchingCourse: "Không có khóa học phù hợp", searchCourse: "Tìm khóa học")
        case "tr": self.init(course: "KURSLAR", progress: "İLERLEME", retry: "Tekrar dene", loadingCourse: "Kurs yükleniyor", liveStudyPage: "Çalışma sayfası", selectCourse: "Kurs seç", viewProgress: "İlerlemeyi gör", coursePackages: "KURS PAKETLERİ", closeCourseSelector: "Kurs seçiciyi kapat", noMatchingCourse: "Eşleşen kurs yok", searchCourse: "Kurs ara")
        default: self.init(course: "COURSE", progress: "PROGRESS", retry: "Try again", loadingCourse: "Loading course", liveStudyPage: "Study page", selectCourse: "Select course", viewProgress: "View learning progress", coursePackages: "COURSE PACKAGES", closeCourseSelector: "Close course selector", noMatchingCourse: "No matching courses", searchCourse: "Search courses")
        }
    }

    private init(course: String, progress: String, retry: String, loadingCourse: String, liveStudyPage: String, selectCourse: String, viewProgress: String, coursePackages: String, closeCourseSelector: String, noMatchingCourse: String, searchCourse: String) {
        self.course = course
        self.progress = progress
        self.retry = retry
        self.loadingCourse = loadingCourse
        self.liveStudyPage = liveStudyPage
        self.selectCourse = selectCourse
        self.viewProgress = viewProgress
        self.coursePackages = coursePackages
        self.closeCourseSelector = closeCourseSelector
        self.noMatchingCourse = noMatchingCourse
        self.searchCourse = searchCourse
    }
}
