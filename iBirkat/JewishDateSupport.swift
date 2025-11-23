import Foundation

// Общая тайм-зона для Э״י
let israelTimeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current

// Простая модель для отображения даты
struct JewishDayInfo {
    let hebrewDate: String      // например: י״ד אדר
    let special: String?        // например: "פורים"
}

/// Помощник по еврейской дате на базе системного календаря .hebrew.
/// Учитываем, что еврейский день начинается вечером: делаем сдвиг +6 часов.
final class HebrewDateHelper {
    static let shared = HebrewDateHelper()

    private let monthFormatter: DateFormatter
    private let hebrewCalendar: Calendar
    private let eveningShiftHours: Double = 6

    private init() {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = Locale(identifier: "he_IL")
        cal.timeZone = israelTimeZone
        self.hebrewCalendar = cal

        let mf = DateFormatter()
        mf.calendar = cal
        mf.locale = Locale(identifier: "he_IL")
        mf.timeZone = israelTimeZone
        mf.dateFormat = "MMMM"      // только название месяца
        self.monthFormatter = mf
    }

    /// Текущая дата + сдвиг на вечер (новый еврейский день после выхода звёзд)
    func currentInfo() -> JewishDayInfo {
        let now = Date()
        let shifted = now.addingTimeInterval(eveningShiftHours * 3600)
        return info(for: shifted)
    }

    /// Информация по произвольной дате с учётом вечернего сдвига.
    func info(for date: Date) -> JewishDayInfo {
        let shiftedDate = date.addingTimeInterval(eveningShiftHours * 3600)

        let comps = hebrewCalendar.dateComponents([.year, .month, .day],
                                                  from: shiftedDate)
        let monthName = monthFormatter.string(from: shiftedDate)

        guard let month = comps.month, let day = comps.day else {
            return JewishDayInfo(hebrewDate: monthName, special: nil)
        }

        let monthsInYear = hebrewCalendar.range(of: .month, in: .year, for: shiftedDate)?.count ?? 12
        let isLeapYear = monthsInYear == 13

        let dayString = hebrewDayString(day)
        let hebrewDateString = "\(dayString) \(monthName)"

        var tags: [String] = []

        // ראש חודש — 1 или 30
        if day == 1 || day == 30 {
            tags.append("ראש חודש")
        }

        // תשרי (1) – חול המועד סוכות: 16–21 תשרי
        if month == 1 && (16...21).contains(day) {
            tags.append("חול המועד סוכות")
        }

        // ניסן (8) – חול המועד פסח: 16–20 ניסן
        if month == 8 && (16...20).contains(day) {
            tags.append("חול המועד פסח")
        }

        // חנוכה: 25 כסלו (3) – 2 טבת (4) (упрощённо)
        if (month == 3 && day >= 25) || (month == 4 && day <= 2) {
            tags.append("חנוכה")
        }

        // Адар: обычный/високосный год
        let isAdarForPurim = (!isLeapYear && month == 6) || (isLeapYear && month == 7)
        let isAdarForPurimKatan = isLeapYear && month == 6

        // פורים — 14 адар
        if isAdarForPurim && day == 14 {
            tags.append("פורים")
        }

        // שושן פורים — 15 адар
        if isAdarForPurim && day == 15 {
            tags.append("שושן פורים")
        }

        // פורים קטן — 14 ад״א (только в високосный год)
        if isAdarForPurimKatan && day == 14 {
            tags.append("פורים קטן")
        }

        // שושן פורים קטן — 15 ад״א
        if isAdarForPurimKatan && day == 15 {
            tags.append("שושן פורים קטן")
        }

        let specialText = tags.isEmpty ? nil : tags.joined(separator: " · ")
        return JewishDayInfo(hebrewDate: hebrewDateString, special: specialText)
    }

    /// Преобразование числа дня (1–30) в запись на иврите с גרש/גרשיים: י״ד, כ״א, ט׳ וכו׳
    private func hebrewDayString(_ n: Int) -> String {
        // особые случаи: 15 и 16 — не пишут יה / יו
        if n == 15 { return "ט״ו" }
        if n == 16 { return "ט״ז" }

        let unitsLetters = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        let tensLetters  = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]

        var components: [String] = []

        let tens = n / 10
        let units = n % 10

        if tens > 0 {
            components.append(tensLetters[tens])
        }
        if units > 0 {
            components.append(unitsLetters[units])
        }

        guard !components.isEmpty else { return "" }

        // Один символ: גרש справа (ז׳)
        if components.count == 1 {
            return components[0] + "׳"
        }

        // Несколько символов: גרשיים перед последней буквой (י״ד, כ״א)
        let last = components.removeLast()
        let joined = components.joined()
        return joined + "״" + last
    }
}
