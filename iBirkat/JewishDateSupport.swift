import Foundation

// Общая тайм-зона для Э״י
let israelTimeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current

// Простая модель для отображения даты
struct JewishDayInfo {
    let hebrewDate: String      // например: י״ד אדר
    let special: String?        // например: "פורים"
    let formattedDate: String
    let dayOfWeek: String
    let hebrewDateText: String
    let isErevShabbat: Bool
    let isErevChag: Bool
    let isShabbat: Bool
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
            return JewishDayInfo(
                hebrewDate: monthName,
                special: nil,
                formattedDate: monthName,
                dayOfWeek: "",
                hebrewDateText: monthName,
                isErevShabbat: false,
                isErevChag: false,
                isShabbat: false
            )
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
        let weekday = weekdayName(for: shiftedDate)
        let formatted = [hebrewDateString, specialText].compactMap { $0 }.joined(separator: " · ")

        let erevShabbat = isErevShabbat(for: shiftedDate)
        let shabbat = isShabbat(shiftedDate)
        let erevChag = isErevChag(for: shiftedDate)

        return JewishDayInfo(
            hebrewDate: hebrewDateString,
            special: specialText,
            formattedDate: formatted,
            dayOfWeek: weekday,
            hebrewDateText: hebrewDateString,
            isErevShabbat: erevShabbat,
            isErevChag: erevChag,
            isShabbat: shabbat
        )
    }

    private func weekdayName(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.timeZone = israelTimeZone
        df.dateFormat = "EEEE"
        return df.string(from: date)
    }

    private func isShabbat(_ date: Date) -> Bool {
        let weekday = hebrewCalendar.component(.weekday, from: date)
        return weekday == 7
    }

    private func isErevShabbat(for date: Date) -> Bool {
        let weekday = hebrewCalendar.component(.weekday, from: date)
        return weekday == 6
    }

    private func isErevChag(for date: Date) -> Bool {
        guard let tomorrow = hebrewCalendar.date(byAdding: .day, value: 1, to: date) else {
            return false
        }

        let comps = hebrewCalendar.dateComponents([.month, .day], from: tomorrow)
        guard let month = comps.month, let day = comps.day else { return false }

        let monthsInYear = hebrewCalendar.range(of: .month, in: .year, for: tomorrow)?.count ?? 12
        let isLeapYear = monthsInYear == 13
        return isYomTov(month: month, day: day, isLeapYear: isLeapYear)
    }

    private func isYomTov(month: Int, day: Int, isLeapYear: Bool) -> Bool {
        _ = isLeapYear // зарезервировано для учёта диаспоры/адар ב׳

        switch (month, day) {
        case (1, 1), (1, 2): // Рош ѓаШана
            return true
        case (1, 10): // Йом Кипур
            return true
        case (1, 15), (1, 22): // Суккот, Шмини Ацерет/Симхат Тора
            return true
        case (8, 15), (8, 21): // 1-й и 7-й дни Песаха
            return true
        case (10, 6): // Шавуот
            return true
        default:
            return false
        }
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

// Дополнительные поля, которые использует ZmanimView
extension JewishDayInfo {
    /// Пока используем special как "событие / параша".
    var parashaOrEvent: String {
        special ?? ""
    }

    /// Временно возвращаем тот же текст, что и hebrewDateText.
    /// При желании можно расширить до "תשרי תשפ״ו" и т.п.
    var hebrewMonthAndYear: String {
        hebrewDateText
    }

    /// Алиас для dayOfWeek, чтобы имя было более читаемым.
    var weekdayName: String {
        dayOfWeek
    }
}
