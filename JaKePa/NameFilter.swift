import Foundation

struct NameValidationError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

struct NameFilter {
    private static let blocklist: [String] = [
        // Japanese
        "うんこ", "うんち", "くそ", "ちんこ", "まんこ", "ちくび", "おっぱい",
        "しね", "死ね", "ころす", "殺す", "きちがい", "きもい", "きもい",
        "バカ", "ばか", "アホ", "あほ", "ブス", "ぶす", "デブ", "でぶ",
        "うざい", "うざ", "消えろ", "きえろ", "障害", "池沼",
        // English
        "fuck", "shit", "ass", "bitch", "dick", "pussy", "cunt",
        "nigger", "nigga", "faggot", "whore", "slut",
    ]

    static func validate(_ name: String) -> Result<String, NameValidationError> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .failure(NameValidationError("名前を入力してください"))
        }
        if trimmed.count > 12 {
            return .failure(NameValidationError("12文字以内で入力してください"))
        }

        let lowered = trimmed.lowercased()
        for word in blocklist where lowered.contains(word.lowercased()) {
            return .failure(NameValidationError("その名前は使用できません🙅"))
        }

        return .success(trimmed)
    }
}
