import Foundation

struct StartupUsernameCopy: Sendable {
    let invalid: String

    static var current: Self {
        let id = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if id.hasPrefix("zh-hant") || id.contains("zh-tw") || id.contains("zh-hk") { return Self(invalid: "使用者名稱只能包含英文字母") }
        if id.hasPrefix("zh") { return Self(invalid: "用户名只能使用英文字母") }
        if id.hasPrefix("ja") { return Self(invalid: "ユーザー名には英字のみ使用できます") }
        if id.hasPrefix("ko") { return Self(invalid: "사용자 이름에는 영문자만 사용할 수 있습니다") }
        if id.hasPrefix("es") { return Self(invalid: "El nombre de usuario solo puede contener letras inglesas") }
        if id.hasPrefix("pt") { return Self(invalid: "O nome de usuário só pode usar letras do alfabeto inglês") }
        if id.hasPrefix("fr") { return Self(invalid: "Le nom d’utilisateur ne peut contenir que des lettres anglaises") }
        if id.hasPrefix("de") { return Self(invalid: "Der Benutzername darf nur englische Buchstaben enthalten") }
        if id.hasPrefix("it") { return Self(invalid: "Il nome utente può contenere solo lettere inglesi") }
        if id.hasPrefix("ru") { return Self(invalid: "Имя пользователя может содержать только латинские буквы") }
        if id.hasPrefix("ar") { return Self(invalid: "لا يمكن أن يحتوي اسم المستخدم إلا على أحرف إنجليزية") }
        if id.hasPrefix("id") { return Self(invalid: "Nama pengguna hanya boleh menggunakan huruf Inggris") }
        if id.hasPrefix("th") { return Self(invalid: "ชื่อผู้ใช้ต้องใช้ตัวอักษรภาษาอังกฤษเท่านั้น") }
        if id.hasPrefix("vi") { return Self(invalid: "Tên người dùng chỉ được chứa chữ cái tiếng Anh") }
        if id.hasPrefix("tr") { return Self(invalid: "Kullanıcı adı yalnızca İngilizce harfler içerebilir") }
        return Self(invalid: "Username may contain English letters only")
    }
}
