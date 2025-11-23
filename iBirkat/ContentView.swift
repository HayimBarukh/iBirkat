import SwiftUI
import UIKit
import CoreLocation

private let israelTimeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current

// ---------------------------------------------------------
// LOCATION + АСТРОНОМИЯ
// ---------------------------------------------------------

/// Провайдер геолокации: запрашивает доступ и публикует координаты + таймзону.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var lastLocation: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var resolvedTimeZone: TimeZone?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.status = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location

        // Асинхронно уточняем таймзону по геокодеру
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let tz = placemarks?.first?.timeZone else { return }
            DispatchQueue.main.async {
                self.resolvedTimeZone = tz
            }
        }
    }
}

/// Астрономический калькулятор восхода/заката по формуле NOAA.
struct AstronomyCalculator {
    struct SunTimes {
        let sunrise: Date
        let sunset: Date
    }

    /// Возвращает точные времена восхода и заката на дату и координаты.
    func sunTimes(for date: Date, coordinate: CLLocationCoordinate2D, timeZone: TimeZone) -> SunTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let baseDay = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date)),
              let dayOfYear = calendar.ordinality(of: .day, in: .year, for: baseDay) else {
            return nil
        }

        let zenith = 90.833 // гражданский восход/закат
        let tzOffsetHours = Double(timeZone.secondsFromGMT(for: baseDay)) / 3600

        guard let sunrise = calculateSunEvent(isSunrise: true,
                                               baseDate: baseDay,
                                               dayOfYear: Double(dayOfYear),
                                               latitude: coordinate.latitude,
                                               longitude: coordinate.longitude,
                                               zenith: zenith,
                                               tzOffsetHours: tzOffsetHours,
                                               calendar: calendar),
              let sunset = calculateSunEvent(isSunrise: false,
                                             baseDate: baseDay,
                                             dayOfYear: Double(dayOfYear),
                                             latitude: coordinate.latitude,
                                             longitude: coordinate.longitude,
                                             zenith: zenith,
                                             tzOffsetHours: tzOffsetHours,
                                             calendar: calendar) else {
            return nil
        }

        return SunTimes(sunrise: sunrise, sunset: sunset)
    }

    private func calculateSunEvent(isSunrise: Bool,
                                   baseDate: Date,
                                   dayOfYear: Double,
                                   latitude: Double,
                                   longitude: Double,
                                   zenith: Double,
                                   tzOffsetHours: Double,
                                   calendar: Calendar) -> Date? {
        let lngHour = longitude / 15.0
        let approxTime = dayOfYear + ((isSunrise ? 6.0 : 18.0) - lngHour) / 24.0

        let meanAnomaly = (0.9856 * approxTime) - 3.289

        var trueLongitude = meanAnomaly
            + (1.916 * sin(deg2rad(meanAnomaly)))
            + (0.020 * sin(deg2rad(2 * meanAnomaly)))
            + 282.634
        trueLongitude = normalizeDegrees(trueLongitude)

        var rightAscension = rad2deg(atan(0.91764 * tan(deg2rad(trueLongitude))))
        rightAscension = normalizeDegrees(rightAscension)

        let lQuadrant = floor(trueLongitude / 90.0) * 90.0
        let raQuadrant = floor(rightAscension / 90.0) * 90.0
        rightAscension = rightAscension + (lQuadrant - raQuadrant)
        rightAscension /= 15.0

        let sinDec = 0.39782 * sin(deg2rad(trueLongitude))
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(deg2rad(zenith)) - (sinDec * sin(deg2rad(latitude)))) / (cosDec * cos(deg2rad(latitude)))

        guard abs(cosH) <= 1 else { return nil }

        var hourAngle = rad2deg(acos(cosH))
        hourAngle = isSunrise ? 360 - hourAngle : hourAngle
        hourAngle /= 15.0

        let localMeanTime = hourAngle + rightAscension - (0.06571 * approxTime) - 6.622
        let utcTime = localMeanTime - lngHour
        let localTime = utcTime + tzOffsetHours

        let hour = Int(localTime)
        let minute = Int((localTime - Double(hour)) * 60.0)
        let second = Int((((localTime - Double(hour)) * 60.0) - Double(minute)) * 60.0)

        var components = DateComponents()
        components.year = calendar.component(.year, from: baseDate)
        components.month = calendar.component(.month, from: baseDate)
        components.day = calendar.component(.day, from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = calendar.timeZone

        return calendar.date(from: components)
    }

    private func deg2rad(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    private func rad2deg(_ radians: Double) -> Double { radians * 180.0 / .pi }
    private func normalizeDegrees(_ deg: Double) -> Double {
        var value = deg.truncatingRemainder(dividingBy: 360.0)
        if value < 0 { value += 360.0 }
        return value
    }
}

// ---------------------------------------------------------
// JEWISH DATE HELPER (без сторонних библиотек)
// ---------------------------------------------------------

struct JewishDayInfo {
    let hebrewDate: String      // למשל: י״ד אדר
    let special: String?        // למשל: "פורים"
}

// ---------------------------------------------------------
// ZMANIM MODELS (простая витрина с мнениями)
// ---------------------------------------------------------

struct ZmanOpinion: Identifiable, Hashable {
    let id: String
    let label: String   // Имя автора/практики
    let detail: String  // Точное правило в минутах/градусах
    let time: String

    init(id: String? = nil, label: String, detail: String, time: String) {
        self.id = id ?? label
        self.label = label
        self.detail = detail
        self.time = time
    }
}

struct ZmanItem: Identifiable, Hashable {
    let id: String
    let title: String
    let opinions: [ZmanOpinion]
    let subtitle: String?

    var defaultOpinion: ZmanOpinion { opinions.first! }

    init(id: String? = nil, title: String, opinions: [ZmanOpinion], subtitle: String? = nil) {
        self.id = id ?? title
        self.title = title
        self.opinions = opinions
        self.subtitle = subtitle
    }
}

/// Мини-провайдер времён, использующий астрономический расчёт восхода/заката
/// (NOAA) и текущие координаты. При отсутствии сигнала — резерв в Иерусалиме.
final class ZmanimProvider {
    private let astronomy = AstronomyCalculator()
    private let fallbackCoordinate = CLLocationCoordinate2D(latitude: 31.778, longitude: 35.235)

    func zmanim(for date: Date, coordinate: CLLocationCoordinate2D?, timeZone: TimeZone) -> [ZmanItem] {
        let coord = coordinate ?? fallbackCoordinate
        let tz = timeZone

        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = tz

        var hebrewCalendar = Calendar(identifier: .hebrew)
        hebrewCalendar.locale = Locale(identifier: "he_IL")
        hebrewCalendar.timeZone = tz

        let sunTimes = astronomy.sunTimes(for: date, coordinate: coord, timeZone: tz)

        // Если нет данных (крайний север/юг), используем приближение 6/18 часов.
        let sunriseMinutes: Int
        let sunsetMinutes: Int
        if let sunTimes = sunTimes {
            sunriseMinutes = minutesSinceMidnight(sunTimes.sunrise, calendar: gregorianCalendar)
            sunsetMinutes = minutesSinceMidnight(sunTimes.sunset, calendar: gregorianCalendar)
        } else {
            sunriseMinutes = 6 * 60
            sunsetMinutes = 18 * 60
        }

        let chatzot = (sunriseMinutes + sunsetMinutes) / 2

        var list: [ZmanItem] = []

        // עלות השחר — разные подходы в минутах до נץ
        list.append(
            buildItem(
                title: "עלות השחר",
                subtitle: "לפני נץ החמה",
                opinions: [
                    ("הגר״ח נאה", "72 דקות לפני נץ", sunriseMinutes - 72),
                    ("מגן אברהם", "90 דקות לפני נץ", sunriseMinutes - 90),
                    ("אדה״ז", "96 דקות לפני נץ", sunriseMinutes - 96),
                    ("ישועות יעקב", "120 דקות לפני נץ", sunriseMinutes - 120)
                ],
                calendar: gregorianCalendar
            )
        )

        // משיכיר — расстояние до נץ
        list.append(
            buildItem(
                title: "משיכיר",
                subtitle: "לפני נץ החמה",
                opinions: [
                    ("הגר״א", "50 דקות לפני נץ", sunriseMinutes - 50),
                    ("רש״ש", "45 דקות לפני נץ", sunriseMinutes - 45),
                    ("רב משה פיינשטיין", "42 דקות לפני נץ", sunriseMinutes - 42)
                ],
                calendar: gregorianCalendar
            )
        )

        // נץ החמה
        list.append(
            buildItem(
                title: "נץ החמה",
                opinions: [
                    ("נץ מדויק", "תחילת זריחת החמה", sunriseMinutes)
                ],
                calendar: gregorianCalendar
            )
        )

        // סוף זמן ק״ש
        list.append(
            buildItem(
                title: "סוף זמן ק״ש",
                subtitle: "בהתאם לאורך היום",
                opinions: [
                    ("מגן אברהם", "3 שעות זמניות מתחילת היום", sunriseMinutes + 180),
                    ("הגר״א", "עד 3 שעות זמניות", sunriseMinutes + 198),
                    ("חזון איש", "3 שעות זמניות + נטייה", sunriseMinutes + 204)
                ],
                calendar: gregorianCalendar
            )
        )

        // סוף זמן תפילה
        list.append(
            buildItem(
                title: "סוף זמן תפילה",
                opinions: [
                    ("מגן אברהם", "4 שעות זמניות מתחילת היום", sunriseMinutes + 264),
                    ("הגר״א", "עד 4 שעות זמניות", sunriseMinutes + 264),
                    ("חזון איש", "4 שעות זמניות + נטייה", sunriseMinutes + 276)
                ],
                calendar: gregorianCalendar
            )
        )

        // חצות היום + מנחה
        list.append(
            buildItem(
                title: "חצות היום",
                opinions: [("חצות", "אמצע בין נץ לשקיעה", chatzot)],
                calendar: gregorianCalendar
            )
        )

        list.append(
            buildItem(
                title: "מנחה גדולה",
                opinions: [
                    ("חצי שעה אחרי חצות", "30 דקות אחרי חצות", chatzot + 30)
                ],
                calendar: gregorianCalendar
            )
        )

        list.append(
            buildItem(
                title: "מנחה קטנה",
                opinions: [
                    ("שעה ורבע לפני שקיעה", "75 דקות לפני שקיעה", sunsetMinutes - 75),
                    ("גר״א", "9.5 שעות זמניות מהזריחה", sunsetMinutes - 150)
                ],
                calendar: gregorianCalendar
            )
        )

        list.append(
            buildItem(
                title: "פלג המנחה",
                opinions: [
                    ("1.25 שעות זמניות לפני לילה", "75 דקות לפני לילה", sunsetMinutes - 75),
                    ("18 דקות לפני שקיעה", "מינימום לחומרה", sunsetMinutes - 18)
                ],
                calendar: gregorianCalendar
            )
        )

        list.append(
            buildItem(
                title: "שקיעה",
                opinions: [("שקיעה אסטרונומית", "סיום שקיעה הנראית", sunsetMinutes)],
                calendar: gregorianCalendar
            )
        )

        // צאת הכוכבים — разные подходы после שקיעה
        list.append(
            buildItem(
                title: "צאת הכוכבים",
                subtitle: "לאחר שקיעה",
                opinions: [
                    ("רבינו תם", "72 דקות אחרי שקיעה", sunsetMinutes + 72),
                    ("גר״א", "18 דקות אחרי שקיעה", sunsetMinutes + 18),
                    ("חזו״א", "30 דקות אחרי שקיעה", sunsetMinutes + 30),
                    ("מנהג חב״ד", "36 דקות אחרי שקיעה", sunsetMinutes + 36)
                ],
                calendar: gregorianCalendar
            )
        )

        if shouldShowCandleLighting(for: date, calendar: hebrewCalendar, gregorian: gregorianCalendar) {
            let subtitle = isFriday(date, calendar: gregorianCalendar) ? "הדלקת נרות ערב שבת" : "הדלקת נרות ערב חג"
            list.insert(
                buildItem(
                    title: "הדלקת נרות",
                    subtitle: subtitle,
                    opinions: [
                        ("מנהג ירושלים", "40 דקות לפני שקיעה", sunsetMinutes - 40),
                        ("מנהג בני ברק", "30 דקות לפני שקיעה", sunsetMinutes - 30),
                        ("מנהג רוב הקהילות", "18 דקות לפני שקיעה", sunsetMinutes - 18),
                        ("תל אביב", "20 דקות לפני שקיעה", sunsetMinutes - 20)
                    ],
                    calendar: gregorianCalendar
                ),
                at: 0
            )
        }

        return list
    }

    private func buildItem(title: String, subtitle: String? = nil, opinions: [(String, String, Int)], calendar: Calendar) -> ZmanItem {
        let baseId = title
        let mapped = opinions.enumerated().map { idx, tuple -> ZmanOpinion in
            let (label, detail, minutes) = tuple
            return ZmanOpinion(
                id: "\(baseId)-\(idx)",
                label: label,
                detail: detail,
                time: timeString(from: minutes, calendar: calendar)
            )
        }

        return ZmanItem(id: baseId, title: title, opinions: mapped, subtitle: subtitle)
    }

    private func shouldShowCandleLighting(for date: Date, calendar: Calendar, gregorian: Calendar) -> Bool {
        if isFriday(date, calendar: gregorian) { return true }

        let comps = calendar.dateComponents([.month, .day], from: date)
        guard let month = comps.month, let day = comps.day else { return false }

        // Условно считаем: ערב חג для Песаха и Суккота
        let erevPesach = (month == 8 && day == 14)
        let erevSukkot = (month == 1 && day == 14)
        return erevPesach || erevSukkot
    }

    private func isFriday(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 6 // 1-вс, 6-пт
    }

    private func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return h * 60 + m
    }

    private func timeString(from minutes: Int, calendar: Calendar) -> String {
        let total = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        let h = total / 60
        let m = total % 60
        var components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: Date()))
        components.hour = h
        components.minute = m

        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
}

/// Помощник по еврейской дате на базе системного календаря .hebrew.
/// Учитываем, что еврейский день начинается вечером: делаем сдвиг +6 часов.
final class HebrewDateHelper {
    static let shared = HebrewDateHelper()

    private let eveningShiftHours: Double = 6

    private init() {}

    /// Текущая дата + сдвиг на вечер (новый еврейский день после выхода звёзд)
    func currentInfo(timeZone: TimeZone) -> JewishDayInfo {
        let now = Date()
        let shifted = now.addingTimeInterval(eveningShiftHours * 3600)
        return info(for: shifted, timeZone: timeZone)
    }

    /// Информация по ПРОИЗВОЛЬНОЙ дате (Date) с учётом вечернего сдвига и таймзоны.
    func info(for date: Date, timeZone: TimeZone) -> JewishDayInfo {
        let shiftedDate = date.addingTimeInterval(eveningShiftHours * 3600)

        var hebrewCalendar = Calendar(identifier: .hebrew)
        hebrewCalendar.locale = Locale(identifier: "he_IL")
        hebrewCalendar.timeZone = timeZone

        let monthFormatter = makeMonthFormatter(timeZone: timeZone)

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

        // Фиксируем, в каком адуаре мы находимся: в обычный год единственный адар — месяц 6,
        // в високосный — пурим празднуют только в адар ב׳ (месяц 7).
        let isAdarForPurim = (!isLeapYear && month == 6) || (isLeapYear && month == 7)
        let isAdarForPurimKatan = isLeapYear && month == 6

        // פורים — 14 адар (в високосном году: только адар ב׳)
        if isAdarForPurim && day == 14 {
            tags.append("פורים")
        }

        // שושן פורים — 15 адар (в високосном году: только адар ב׳)
        if isAdarForPurim && day == 15 {
            tags.append("שושן פורים")
        }

        // פורים קטן — 14 адר א׳ (только в високосный год)
        if isAdarForPurimKatan && day == 14 {
            tags.append("פורים קטן")
        }

        // שושן פורים קטן — 15 адר א׳ (только в високосный год)
        if isAdarForPurimKatan && day == 15 {
            tags.append("שושן פורים קטן")
        }

        let specialText = tags.isEmpty ? nil : tags.joined(separator: " · ")
        return JewishDayInfo(hebrewDate: hebrewDateString, special: specialText)
    }

    private func makeMonthFormatter(timeZone: TimeZone) -> DateFormatter {
        let mf = DateFormatter()
        mf.calendar = Calendar(identifier: .hebrew)
        mf.locale = Locale(identifier: "he_IL")
        mf.timeZone = timeZone
        mf.dateFormat = "MMMM"      // только название месяца
        return mf
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

// ---------------------------------------------------------
// MODEL
// ---------------------------------------------------------

struct Prayer: Identifiable, Equatable, Hashable {
    let id = UUID()
    let title: String
    let basePdfName: String   // без суффиксов и расширения

    func pdfName(for nusach: Nusach, isPhone: Bool) -> String {
        if isPhone {
            switch nusach {
            case .edotHaMizrach:
                return basePdfName + "_iphone"
            case .ashkenaz:
                return basePdfName + "_iphone_a"
            case .chabad:
                return basePdfName + "_iphone_h"
            }
        }

        switch nusach {
        case .edotHaMizrach:
            return basePdfName
        case .ashkenaz:
            return basePdfName + "_a"
        case .chabad:
            return basePdfName + "_h"
        }
    }

    func hasPdf(for nusach: Nusach, isPhone: Bool) -> Bool {
        let name = pdfName(for: nusach, isPhone: isPhone)
        return Bundle.main.url(forResource: name, withExtension: "pdf") != nil
    }
}

// ---------------------------------------------------------
// PRAYERS
// ---------------------------------------------------------

let birkatHamazon  = Prayer(title: "ברכת המזון",  basePdfName: "birkat hamazon")
let meenShalosh    = Prayer(title: "מעין שלש",     basePdfName: "meenshalosh")
let boreNefashot   = Prayer(title: "בורא נפשות",  basePdfName: "borenefashot")

let allAfterFoodPrayers = [
    birkatHamazon,
    meenShalosh,
    boreNefashot
]

// ---------------------------------------------------------
// NUSACH
// ---------------------------------------------------------

enum Nusach: String, CaseIterable, Identifiable {
    case edotHaMizrach
    case ashkenaz
    case chabad

    var id: Self { self }

    var title: String {
        switch self {
        case .edotHaMizrach: return "עדות המזרח"
        case .ashkenaz:      return "אשכנז"
        case .chabad:        return "חב״ד"
        }
    }
}

// ---------------------------------------------------------
// CONTENT VIEW
// ---------------------------------------------------------

struct ContentView: View {

    @StateObject private var locationProvider = LocationProvider()
    @State private var currentPageIndex: Int = 0
    @State private var selectedPrayer: Prayer = birkatHamazon
    @State private var showSettings: Bool = false
    @State private var showZmanimSheet: Bool = false
    @State private var zmanimDate: Date = Date()
    @State private var zmanimSelections: [String: ZmanOpinion] = [:]
    @State private var activeZmanItem: ZmanItem?

    @AppStorage("selectedNusach") private var selectedNusach: Nusach = .edotHaMizrach
    @AppStorage("startWithZimun") private var startWithZimun: Bool = false
    @AppStorage("keepScreenOn")   private var keepScreenOn: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.scenePhase) private var scenePhase

    private var isCompactPhone: Bool {
        hSizeClass == .compact && vSizeClass == .regular
    }

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private let zmanimProvider = ZmanimProvider()
    private var gregorianFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.timeZone = currentTimeZone
        df.dateStyle = .full
        return df
    }

    /// Максимальная ширина сегментов — учитываем кнопки по бокам
    private var segmentedMaxWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if isPhone {
            return min(screenWidth - 140, 420)
        } else {
            return 520
        }
    }

    private var visibleAfterFoodPrayers: [Prayer] {
        allAfterFoodPrayers.filter { $0.hasPdf(for: selectedNusach, isPhone: isPhone) }
    }

    private var jewishInfo: JewishDayInfo {
        HebrewDateHelper.shared.currentInfo(timeZone: currentTimeZone)
    }

    private var currentZmanim: [ZmanItem] {
        zmanimProvider.zmanim(for: zmanimDate, coordinate: currentCoordinate, timeZone: currentTimeZone)
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        locationProvider.lastLocation?.coordinate
    }

    private var currentTimeZone: TimeZone {
        locationProvider.resolvedTimeZone ?? israelTimeZone
    }

    // ---------------------------------------------------------

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                prayerHeaderAndPickers

                PDFKitView(
                    pdfName: selectedPrayer.pdfName(for: selectedNusach, isPhone: isPhone),
                    currentPageIndex: $currentPageIndex
                )
                .padding(.horizontal, isCompactPhone ? -2 : -4)
                .padding(.top, isCompactPhone ? 0 : -2)
            }
            .onChange(of: selectedPrayer) { _ in
                updatePageIndexForCurrentSelection()
                lightHaptic()
            }
            .onChange(of: selectedNusach) { _ in
                ensureValidSelection()
                lightHaptic()
            }
            .onChange(of: startWithZimun) { _ in
                if selectedPrayer == birkatHamazon {
                    updatePageIndexForCurrentSelection()
                }
            }
            .onChange(of: keepScreenOn) { _ in
                updateIdleTimer()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    handleShortcutIfNeeded()
                    updateIdleTimer()
                } else {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
            .onAppear {
                ensureValidSelection()
                updatePageIndexForCurrentSelection()
                handleShortcutIfNeeded()
                updateIdleTimer()
                locationProvider.request()
            }
        }
        .overlay {
            if showSettings {
                settingsOverlay
            }
        }
        .sheet(isPresented: $showZmanimSheet) {
            ZmanimSheet(
                isPresented: $showZmanimSheet,
                date: $zmanimDate,
                gregorianFormatter: gregorianFormatter,
                currentZmanim: currentZmanim,
                selectedOpinions: $zmanimSelections,
                activeZmanItem: $activeZmanItem,
                hebrewInfo: { date in
                    HebrewDateHelper.shared.info(for: date, timeZone: currentTimeZone)
                },
                pickOpinion: { item, opinion in
                    zmanimSelections[item.id] = opinion
                    lightHaptic()
                },
                haptic: lightHaptic
            )
            .environment(\.layoutDirection, .rightToLeft)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // ---------------------------------------------------------
    // SHORTCUT HANDLING
    // ---------------------------------------------------------

    private func handleShortcutIfNeeded() {
        let key = "shortcutPrayerID"
        guard let id = UserDefaults.standard.string(forKey: key),
              !id.isEmpty
        else { return }

        applyShortcut(id: id)
        UserDefaults.standard.set("", forKey: key)
    }

    private func applyShortcut(id: String) {
        switch id {
        case "birkat":
            selectedPrayer = birkatHamazon
        case "meen":
            selectedPrayer = meenShalosh
        case "bore":
            selectedPrayer = boreNefashot
        default:
            return
        }

        updatePageIndexForCurrentSelection()
        lightHaptic()
    }

    // ---------------------------------------------------------

    private func ensureValidSelection() {
        guard !visibleAfterFoodPrayers.isEmpty else { return }

        if !selectedPrayer.hasPdf(for: selectedNusach, isPhone: isPhone) {
            selectedPrayer = visibleAfterFoodPrayers.first!
        }

        updatePageIndexForCurrentSelection()
    }

    private func updatePageIndexForCurrentSelection() {
        if selectedPrayer == birkatHamazon {
            currentPageIndex = startWithZimun ? 0 : 1
        } else {
            currentPageIndex = 0
        }
    }

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn
    }

    // ---------------------------------------------------------
    // Кнопки в шапке
    // ---------------------------------------------------------

    private var gearButton: some View {
        Button {
            lightHaptic()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                showSettings = true
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: isPhone ? 14 : 16, weight: .regular))
                .padding(6)
                .background(
                    Capsule().fill(Color.gray.opacity(0.12))
                )
                .foregroundColor(.gray.opacity(0.85))
        }
    }

    private var zmanimButton: some View {
        Button {
            lightHaptic()
            showZmanimSheet = true
        } label: {
            Image(systemName: "sun.max")
                .font(.system(size: isPhone ? 14 : 16, weight: .regular))
                .padding(6)
                .background(
                    Capsule().fill(Color.gray.opacity(0.12))
                )
                .foregroundColor(.gray.opacity(0.85))
        }
    }

    // ---------------------------------------------------------
    // Настройки — без тестовых кнопок
    // ---------------------------------------------------------

    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showSettings = false
                    }
                }

            VStack(spacing: 16) {
                Text("הגדרות")
                    .font(.headline)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("נוסח תפילה")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(Nusach.allCases) { nusach in
                        Button {
                            selectedNusach = nusach
                            lightHaptic()
                        } label: {
                            HStack {
                                Text(nusach.title)
                                Spacer()
                                if nusach == selectedNusach {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Divider()

                Toggle(isOn: $startWithZimun) {
                    Text("להתחיל מזימון")
                }

                Toggle(isOn: $keepScreenOn) {
                    Text("לא לכבות מסך בזמן קריאה")
                }

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showSettings = false
                    }
                } label: {
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18),
                            radius: 18, x: 0, y: 8)
            )
        }
    }

    // ---------------------------------------------------------
    // Шапка: дата+нусах по центру, под кнопками — бейдж праздника
    // ---------------------------------------------------------

    private var prayerHeaderAndPickers: some View {
        let info = jewishInfo

        return VStack(spacing: 4) {

            // Дата и нусах по центру
            HStack(spacing: 6) {
                Spacer()

                Text(info.hebrewDate)
                    .font(.footnote.weight(.medium))

                Text("·")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text(selectedNusach.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.bottom, 2)

            // Кнопки + шестерёнка + «солнышко»
            if !visibleAfterFoodPrayers.isEmpty {
                ZStack {
                    HStack {
                        zmanimButton
                        Spacer()
                        gearButton
                    }
                    .padding(.horizontal, 12)

                    HStack {
                        Spacer()
                        Picker("", selection: $selectedPrayer) {
                            ForEach(visibleAfterFoodPrayers) { prayer in
                                Text(prayer.title).tag(prayer)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: segmentedMaxWidth)
                        Spacer()
                    }
                }
            }

            // Под кнопками — если сегодня особый день
            if let special = info.special, !special.isEmpty {
                Text("היום: \(special)")
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 12)
                    .background(Color.yellow.opacity(0.16))
                    .cornerRadius(999)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

// ---------------------------------------------------------
// ZMANIM SHEET
// ---------------------------------------------------------

struct ZmanimSheet: View {

    @Binding var isPresented: Bool
    @Binding var date: Date
    let gregorianFormatter: DateFormatter
    let currentZmanim: [ZmanItem]
    @Binding var selectedOpinions: [String: ZmanOpinion]
    @Binding var activeZmanItem: ZmanItem?

    let hebrewInfo: (Date) -> JewishDayInfo
    let pickOpinion: (ZmanItem, ZmanOpinion) -> Void
    let haptic: () -> Void

    private var hebrewDateText: String {
        hebrewInfo(date).hebrewDate
    }

    private var gregorianDateText: String {
        gregorianFormatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                header
                navigationRow
                divider
                list
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגור") { isPresented = false }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(hebrewDateText)
                .font(.headline)
            Text(gregorianDateText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var navigationRow: some View {
        HStack(spacing: 12) {
            Button {
                shiftDate(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .padding(10)
                    .background(Circle().fill(Color.gray.opacity(0.12)))
            }

            Button("היום") {
                date = Date()
                haptic()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.gray.opacity(0.12)))

            Button {
                shiftDate(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .padding(10)
                    .background(Circle().fill(Color.gray.opacity(0.12)))
            }
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.18))
            .frame(height: 1)
            .padding(.horizontal, -16)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(currentZmanim) { item in
                    Button {
                        activeZmanItem = item
                    } label: {
                        let activeOpinion = selectedOpinions[item.id] ?? item.defaultOpinion
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)

                                if let subtitle = item.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(activeOpinion.label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(activeOpinion.detail)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Text(activeOpinion.time)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.gray.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 20)
        }
        .confirmationDialog(
            "בחר דעה עבור הזמן",
            isPresented: Binding(
                get: { activeZmanItem != nil },
                set: { newValue in if !newValue { activeZmanItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = activeZmanItem {
                ForEach(item.opinions) { opinion in
                    Button("\(opinion.label) · \(opinion.detail)") {
                        pickOpinion(item, opinion)
                        activeZmanItem = nil
                    }
                }
                Button("ביטול", role: .cancel) {
                    activeZmanItem = nil
                }
            }
        }
    }

    private func shiftDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: date) {
            date = newDate
            haptic()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.layoutDirection, .rightToLeft)
}
