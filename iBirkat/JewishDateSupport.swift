import Foundation
import KosherSwift

// Общая тайм-зона для Э״י
let israelTimeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current

struct JewishDayInfo {
    let hebrewDate: String
    let special: String?
}

final class HebrewDateHelper {
    static let shared = HebrewDateHelper()

    private let monthFormatter: DateFormatter
    private let hebrewCalendar: Calendar

    private init() {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = Locale(identifier: "he_IL")
        cal.timeZone = TimeZone.current
        self.hebrewCalendar = cal

        let mf = DateFormatter()
        mf.calendar = cal
        mf.locale = Locale(identifier: "he_IL")
        mf.timeZone = TimeZone.current
        mf.dateFormat = "MMMM"
        self.monthFormatter = mf
    }

    /// Определяет текущую еврейскую дату с учетом заката (Шкия).
    func currentInfo(for location: GeoLocation? = nil) -> JewishDayInfo {
        let now = Date()
        var dateToUse = now

        // Логика определения вечера (следующий еврейский день)
        var isNextDay = false

        if let loc = location {
            // ИСПРАВЛЕНО: Используем существующий метод candleLighting с отступом 0,
            // так как это соответствует закату (Шкие), или фолбэк, если метод вернет nil
            let provider = ZmanimProvider(geoLocation: loc)
            
            // Пытаемся получить время заката (зажигание свечей за 0 минут до заката)
            if let sunset = provider.candleLighting(for: now, minutesBeforeSunset: 0) {
                if now > sunset {
                    isNextDay = true
                }
            } else {
                // Если API не вернуло время (например, в будни), используем упрощенную проверку по часам
                let hour = Calendar.current.component(.hour, from: now)
                if hour >= 19 { // Летом безопасно считать, что после 19:00 может быть вечер
                     isNextDay = true
                }
            }
        } else {
            // Фолбэк без GPS: считаем, что после 18:00 (усредненно) наступает вечер
            let hour = Calendar.current.component(.hour, from: now)
            if hour >= 18 {
                isNextDay = true
            }
        }

        if isNextDay {
            dateToUse = now.addingTimeInterval(86400) // +24 часа
        }

        return info(for: dateToUse)
    }

    func info(for date: Date) -> JewishDayInfo {
        let comps = hebrewCalendar.dateComponents([.year, .month, .day], from: date)
        let monthName = monthFormatter.string(from: date)

        guard let month = comps.month, let day = comps.day else {
            return JewishDayInfo(hebrewDate: monthName, special: nil)
        }

        let monthsInYear = hebrewCalendar.range(of: .month, in: .year, for: date)?.count ?? 12
        let isLeapYear = monthsInYear == 13

        let dayString = hebrewDayString(day)
        let hebrewDateString = "\(dayString) \(monthName)"

        var tags: [String] = []

        if day == 1 || day == 30 { tags.append("ראש חודש") }
        if month == 1 && (16...21).contains(day) { tags.append("חול המועד סוכות") }
        if month == 8 && (16...20).contains(day) { tags.append("חול המועד פסח") }
        if (month == 3 && day >= 25) || (month == 4 && day <= 2) { tags.append("חנוכה") }

        let isAdarForPurim = (!isLeapYear && month == 6) || (isLeapYear && month == 7)
        let isAdarForPurimKatan = isLeapYear && month == 6

        if isAdarForPurim && day == 14 { tags.append("פורים") }
        if isAdarForPurim && day == 15 { tags.append("שושן פורים") }
        if isAdarForPurimKatan && day == 14 { tags.append("פורים קטן") }
        if isAdarForPurimKatan && day == 15 { tags.append("שושן פורים קטן") }

        let specialText = tags.isEmpty ? nil : tags.joined(separator: " · ")
        return JewishDayInfo(hebrewDate: hebrewDateString, special: specialText)
    }

    private func hebrewDayString(_ n: Int) -> String {
        if n == 15 { return "ט״ו" }
        if n == 16 { return "ט״ז" }

        let unitsLetters = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        let tensLetters  = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]

        var components: [String] = []
        let tens = n / 10
        let units = n % 10

        if tens > 0 { components.append(tensLetters[tens]) }
        if units > 0 { components.append(unitsLetters[units]) }

        guard !components.isEmpty else { return "" }
        if components.count == 1 { return components[0] + "׳" }
        let last = components.removeLast()
        return components.joined() + "״" + last
    }
}
