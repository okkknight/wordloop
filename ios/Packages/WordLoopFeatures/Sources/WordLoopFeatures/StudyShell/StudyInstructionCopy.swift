import Foundation

struct StudyInstructionCopy: Sendable {
    let idle: String
    let ready: String
    let playing: String
    let speak: String
    let speaking: String
    let scoring: String
    let passed: String
    let paused: String
    let retry: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(idle: "跟讀模式已準備好", ready: "聽完示範後開始跟讀", playing: "先聽一遍標準發音", speak: "請清晰地跟讀", speaking: "正在聽你的發音", scoring: "正在分析這次發音", passed: "這次發音通過了", paused: "準備好後繼續練習", retry: "請再讀一次") }
        if id.hasPrefix("zh") { return Self(idle: "跟读模式已准备好", ready: "听完示范后开始跟读", playing: "先听一遍标准发音", speak: "请清晰地跟读", speaking: "正在听你发音", scoring: "正在分析这次发音", passed: "这次发音通过了", paused: "准备好后继续练习", retry: "请再读一次") }
        if id.hasPrefix("ja") { return Self(idle: "音読モードの準備ができました", ready: "お手本を聞いてから音読を始めてください", playing: "まず標準発音を聞いてください", speak: "はっきり音読してください", speaking: "発音を聞き取っています", scoring: "発音を分析しています", passed: "発音に合格しました", paused: "準備ができたら練習を続けてください", retry: "もう一度読んでください") }
        if id.hasPrefix("ko") { return Self(idle: "따라 말하기 모드를 사용할 준비가 됐어요", ready: "예시를 들은 후 따라 말해 보세요", playing: "먼저 표준 발음을 들어 보세요", speak: "또렷하게 따라 말해 보세요", speaking: "발음을 듣고 있어요", scoring: "발음을 분석하고 있어요", passed: "발음이 통과했어요", paused: "준비되면 연습을 계속하세요", retry: "다시 읽어 보세요") }
        if id.hasPrefix("es") { return Self(idle: "El modo de repetición está listo", ready: "Escucha el ejemplo y empieza a repetir", playing: "Escucha primero la pronunciación estándar", speak: "Repite con claridad", speaking: "Estamos escuchando tu pronunciación", scoring: "Estamos analizando tu pronunciación", passed: "Tu pronunciación ha sido aprobada", paused: "Continúa cuando estés listo", retry: "Lee otra vez") }
        if id.hasPrefix("pt") { return Self(idle: "O modo de repetição está pronto", ready: "Ouça o exemplo e comece a repetir", playing: "Ouça primeiro a pronúncia padrão", speak: "Repita com clareza", speaking: "Estamos ouvindo sua pronúncia", scoring: "Estamos analisando sua pronúncia", passed: "Sua pronúncia foi aprovada", paused: "Continue quando estiver pronto", retry: "Leia novamente") }
        if id.hasPrefix("fr") { return Self(idle: "Le mode de répétition est prêt", ready: "Écoutez l’exemple, puis commencez à répéter", playing: "Écoutez d’abord la prononciation standard", speak: "Répétez clairement", speaking: "Nous écoutons votre prononciation", scoring: "Nous analysons votre prononciation", passed: "Votre prononciation est validée", paused: "Reprenez quand vous êtes prêt", retry: "Lisez encore une fois") }
        if id.hasPrefix("de") { return Self(idle: "Der Nachsprechmodus ist bereit", ready: "Hör dir das Beispiel an und sprich es nach", playing: "Hör dir zuerst die Standardaussprache an", speak: "Sprich deutlich nach", speaking: "Wir hören deine Aussprache", scoring: "Wir analysieren deine Aussprache", passed: "Deine Aussprache wurde bestanden", paused: "Mach weiter, sobald du bereit bist", retry: "Lies es noch einmal") }
        if id.hasPrefix("it") { return Self(idle: "La modalità ripetizione è pronta", ready: "Ascolta l’esempio e inizia a ripetere", playing: "Ascolta prima la pronuncia standard", speak: "Ripeti chiaramente", speaking: "Stiamo ascoltando la tua pronuncia", scoring: "Stiamo analizzando la tua pronuncia", passed: "La tua pronuncia è stata approvata", paused: "Continua quando sei pronto", retry: "Leggi di nuovo") }
        if id.hasPrefix("ru") { return Self(idle: "Режим повторения готов", ready: "Послушайте пример и начните повторять", playing: "Сначала послушайте стандартное произношение", speak: "Повторяйте чётко", speaking: "Слушаем ваше произношение", scoring: "Анализируем ваше произношение", passed: "Произношение принято", paused: "Продолжите, когда будете готовы", retry: "Прочитайте ещё раз") }
        if id.hasPrefix("ar") { return Self(idle: "وضع التكرار جاهز", ready: "استمع إلى المثال ثم ابدأ بالتكرار", playing: "استمع أولًا إلى النطق القياسي", speak: "كرّر بوضوح", speaking: "نستمع إلى نطقك", scoring: "نحلّل نطقك", passed: "تم اجتياز النطق", paused: "تابع عندما تكون مستعدًا", retry: "اقرأ مرة أخرى") }
        if id.hasPrefix("id") { return Self(idle: "Mode menirukan siap digunakan", ready: "Dengarkan contoh lalu mulai menirukan", playing: "Dengarkan pelafalan standar terlebih dahulu", speak: "Tirukan dengan jelas", speaking: "Kami sedang mendengarkan pelafalan Anda", scoring: "Kami sedang menganalisis pelafalan Anda", passed: "Pelafalan Anda berhasil", paused: "Lanjutkan saat Anda siap", retry: "Baca sekali lagi") }
        if id.hasPrefix("th") { return Self(idle: "โหมดพูดตามพร้อมแล้ว", ready: "ฟังตัวอย่างแล้วเริ่มพูดตาม", playing: "ฟังการออกเสียงมาตรฐานก่อน", speak: "พูดตามให้ชัดเจน", speaking: "กำลังฟังการออกเสียงของคุณ", scoring: "กำลังวิเคราะห์การออกเสียงของคุณ", passed: "ผ่านการออกเสียงแล้ว", paused: "พร้อมแล้วจึงฝึกต่อได้", retry: "อ่านอีกครั้ง") }
        if id.hasPrefix("vi") { return Self(idle: "Chế độ nói theo đã sẵn sàng", ready: "Nghe mẫu rồi bắt đầu nói theo", playing: "Hãy nghe phát âm chuẩn trước", speak: "Nói theo thật rõ ràng", speaking: "Đang nghe cách phát âm của bạn", scoring: "Đang phân tích cách phát âm của bạn", passed: "Bạn đã phát âm đạt", paused: "Tiếp tục khi bạn sẵn sàng", retry: "Đọc lại một lần nữa") }
        if id.hasPrefix("tr") { return Self(idle: "Tekrarlama modu hazır", ready: "Örneği dinleyip tekrar etmeye başla", playing: "Önce standart telaffuzu dinle", speak: "Net bir şekilde tekrar et", speaking: "Telaffuzunu dinliyoruz", scoring: "Telaffuzunu analiz ediyoruz", passed: "Telaffuzun başarılı", paused: "Hazır olduğunda devam et", retry: "Bir kez daha oku") }
        return Self(idle: "Repeat mode is ready", ready: "Listen to the example, then start repeating", playing: "Listen to the standard pronunciation first", speak: "Repeat clearly", speaking: "Listening to your pronunciation", scoring: "Analyzing your pronunciation", passed: "Pronunciation passed", paused: "Continue when you are ready", retry: "Read it again")
    }
}
