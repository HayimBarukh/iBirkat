import Foundation
import KosherSwift

// MARK: - Мнения и элементы списка

struct ZmanOpinion: Identifiable, Hashable {
    let id: String
    let title: String
    let time: String

    init(id: String? = nil, title: String, time: String) {
        self.id = id ?? title
        self.title = title
        self.time = time
    }
}

struct ZmanItem: Identifiable, Hashable {
    let id: String
    let title: String
    let opinions: [ZmanOpinion]
    let subtitle: String?

    var defaultOpinion: ZmanOpinion { opinions.first! }

    init(id: String? = nil,
         title: String,
         opinions: [ZmanOpinion],
         subtitle: String? = nil)
    {
        self.id = id ?? title
        self.title = title
        self.opinions = opinions
        self.subtitle = subtitle
    }
}

// MARK: - Провайдер зманим

final class ZmanimProvider {

    private let geoLocation: GeoLocation
    private let cal: ComplexZmanimCalendar      // С учетом высоты (Elevation) - для Нец/Шкия/Свечей
    private let calMishor: ComplexZmanimCalendar // Без высоты (Sea Level) - для Алот/Цет/РТ

    private lazy var timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.dateFormat = "HH:mm"
        df.timeZone = geoLocation.timeZone
        return df
    }()

    init(geoLocation: GeoLocation) {
        self.geoLocation = geoLocation
        
        // 1. Основной календарь (VISIBLE / ELEVATION)
        self.cal = ComplexZmanimCalendar(location: geoLocation)
        self.cal.useElevation = true
        
        // 2. Календарь Мишор (SEA LEVEL)
        let mishorLoc = GeoLocation(
            locationName: geoLocation.locationName,
            latitude: geoLocation.latitude,
            longitude: geoLocation.longitude,
            elevation: 0,
            timeZone: geoLocation.timeZone
        )
        self.calMishor = ComplexZmanimCalendar(location: mishorLoc)
        self.calMishor.useElevation = true // Для корректной работы мат. модели при высоте 0
    }

    private func getSunsetVisible(for date: Date) -> Date? {
        cal.workingDate = date
        return cal.getSunset()
    }

    func candleLighting(for date: Date, minutesBeforeSunset: Int) -> Date? {
        guard let sunset = getSunsetVisible(for: date) else { return nil }
        return sunset.addingTimeInterval(-Double(minutesBeforeSunset) * 60)
    }
    
    func getCandleLightingTime(for date: Date, minutesBeforeSunset: Int) -> String {
        guard let time = candleLighting(for: date, minutesBeforeSunset: minutesBeforeSunset) else { return "—" }
        return timeFormatter.string(from: time)
    }

    /// Расчет выхода Шаббата (Havdalah)
    /// - Parameters:
    ///   - opinionID: ID конкретного мнения. Если nil - берется дефолт из списка.
    func getHavdalahTime(for date: Date, opinionID: String?) -> String {
        // Генерируем список зманим для этого дня
        let items = zmanim(for: date)
        
        // Находим пункт "havdalah" (צאת השבת / חג)
        guard let havdalahItem = items.first(where: { $0.id == "havdalah" }) else {
            // Если в этот день нет хавдалы (например, обычный будний день), возвращаем прочерк
            return "—"
        }
        
        // 1. Если передан конкретный ID (выбрано пользователем), ищем его
        if let id = opinionID,
           let selectedOpinion = havdalahItem.opinions.first(where: { $0.id == id }) {
            return selectedOpinion.time
        }
        
        // 2. Иначе берем мнение по умолчанию (первое в списке - Рав Овадья/Сефардское)
        return havdalahItem.defaultOpinion.time
    }

    func motzaeiShabbatOrYomTov(for date: Date, offsetMinutes: Int = 40) -> Date? {
        guard let sunset = getSunsetVisible(for: date) else { return nil }
        return sunset.addingTimeInterval(Double(offsetMinutes) * 60)
    }

    func zmanim(for date: Date) -> [ZmanItem] {
        cal.workingDate = date
        calMishor.workingDate = date
        
        // 1. VISIBLE (Нец, Шкия)
        guard
            let sunriseVisible = cal.getSunrise(),
            let sunsetVisible  = cal.getSunset()
        else { return [] }

        // 2. MISHOR (Sea Level)
        let sunriseSeaLevel = calMishor.getSunrise() ?? sunriseVisible
        let sunsetSeaLevel  = calMishor.getSunset() ?? sunsetVisible
        
        // Градусы от Мишора (для строгих расчетов)
        let alos19_75 = calMishor.getSunriseOffsetByDegrees(offsetZenith: 19.75) ?? sunriseSeaLevel.addingTimeInterval(-90 * 60)
        let alos16_9  = calMishor.getSunriseOffsetByDegrees(offsetZenith: 16.9)  ?? sunriseSeaLevel.addingTimeInterval(-74 * 60)
        
        // Цет/РТ от Мишора
        let tzeit16_1_Mishor = calMishor.getSunsetOffsetByDegrees(offsetZenith: 16.1) ?? sunsetSeaLevel.addingTimeInterval(72 * 60)
        let tzeit19_75_Mishor = calMishor.getSunsetOffsetByDegrees(offsetZenith: 19.75) ?? sunsetSeaLevel.addingTimeInterval(90 * 60)

        // 8.5° от ВИДИМОГО (Visible)
        let tzeit8_5_Visible = cal.getSunsetOffsetByDegrees(offsetZenith: 8.5) ?? sunsetVisible.addingTimeInterval(36 * 60)
        
        // --- GRA Day (Visible) ---
        let dayLenVisible = sunsetVisible.timeIntervalSince(sunriseVisible)
        let shaahZmanitVisible = dayLenVisible / 12.0
        let chatzotVisible = sunriseVisible.addingTimeInterval(dayLenVisible / 2.0)

        // --- 1. ALOT HASHACHAR ---
        let alos72FixedMishor = sunriseSeaLevel.addingTimeInterval(-72.0 * 60.0)

        let opAlos72Fixed = ZmanOpinion(id: "alos-72-fixed", title: "72 דקות שוות (ילקוט יוסף)", time: timeString(alos72FixedMishor))
        let opAlos19_75 = ZmanOpinion(id: "alos-19.75", title: "19.75° (90 במעלות / חזון איש)", time: timeString(alos19_75))
        let opAlos16_9 = ZmanOpinion(id: "alos-16.9", title: "16.9° (חב״ד)", time: timeString(alos16_9))
        
        // По умолчанию для сефардов (Рав Овадья): сначала 72 минуты, потом градусы
        let alosOpinions = [opAlos72Fixed, opAlos19_75, opAlos16_9]

        // --- 2. MISHEYAKIR ---
        let mish11_5 = calMishor.getSunriseOffsetByDegrees(offsetZenith: 11.5) ?? sunriseSeaLevel.addingTimeInterval(-52 * 60)
        let mish11_0 = calMishor.getSunriseOffsetByDegrees(offsetZenith: 11.0) ?? sunriseSeaLevel.addingTimeInterval(-50 * 60)
        let mish10_5 = calMishor.getSunriseOffsetByDegrees(offsetZenith: 10.5) ?? sunriseSeaLevel.addingTimeInterval(-47 * 60)
        
        let mish52Mishor = sunriseSeaLevel.addingTimeInterval(-52 * 60)
        
        // Мишеякир 66 временных минут до восхода (Visible)
        let mish66Zmaniyot = sunriseVisible.addingTimeInterval(-1.1 * shaahZmanitVisible)

        let op11_5 = ZmanOpinion(id: "tz-11.5", title: "11.5° (ילקוט יוסף)", time: timeString(mish11_5))
        let op11   = ZmanOpinion(id: "tz-11", title: "11° (הרב פוזן / חב״ד)", time: timeString(mish11_0))
        let op10_5 = ZmanOpinion(id: "tz-10.5", title: "10.5° (אשכנז)", time: timeString(mish10_5))
        let op66_zmaniyot = ZmanOpinion(id: "tz-6-zmaniyot", title: "66 דק׳ זמניות לפני הנץ (ילקוט יוסף)", time: timeString(mish66Zmaniyot))
        let op52 = ZmanOpinion(id: "tz-52", title: "52 דקות (מנהג ישן)", time: timeString(mish52Mishor))

        // По умолчанию для сефардов (Рав Овадья): сначала 66 зманийот
        let tzitzitOpinions = [op66_zmaniyot, op11_5, op52, op11, op10_5]

        // --- 3. SOF ZMAN ---
        func calcZman(start: Date, end: Date, ratio: Double) -> Date {
            let length = end.timeIntervalSince(start)
            return start.addingTimeInterval(length * ratio)
        }

        // GRA (Visible)
        let sofShmaGRA = calcZman(start: sunriseVisible, end: sunsetVisible, ratio: 0.25)
        let sofTfilaGRA = calcZman(start: sunriseVisible, end: sunsetVisible, ratio: 1.0/3.0)

        // MGA 90 (19.75 Mishor)
        let sofShmaMGA_90 = calcZman(start: alos19_75, end: tzeit19_75_Mishor, ratio: 0.25)
        
        // MGA Sefard (72 fixed from Mishor)
        let mgaSefStart = sunriseSeaLevel.addingTimeInterval(-72 * 60)
        let mgaSefEnd   = sunsetSeaLevel.addingTimeInterval(72 * 60)
        let sofShmaMGA_Sef = calcZman(start: mgaSefStart, end: mgaSefEnd, ratio: 0.25)
        let sofTfilaMGA_Sef = calcZman(start: mgaSefStart, end: mgaSefEnd, ratio: 1.0/3.0)

        let opShmaGRA = ZmanOpinion(id: "shma-gra", title: "גר״א (זריחה עד שקיעה)", time: timeString(sofShmaGRA))
        let opShmaMGA_90 = ZmanOpinion(id: "shma-mga-90", title: "מג״א 90 (19.75°)", time: timeString(sofShmaMGA_90))
        let opShmaMGA_Sef = ZmanOpinion(id: "shma-mga-sef", title: "מג״א 72 (שוות)", time: timeString(sofShmaMGA_Sef))

        let opTfilaGRA = ZmanOpinion(id: "tfila-gra", title: "גר״א (זריחה עד שקיעה)", time: timeString(sofTfilaGRA))
        let opTfilaMGA_Sef = ZmanOpinion(id: "tfila-mga-sef", title: "מג״א 72 (שוות)", time: timeString(sofTfilaMGA_Sef))

        // По умолчанию для сефардов: МГА 72
        let shmaMGA_Ops = [opShmaMGA_Sef, opShmaMGA_90]

        // MINCHA / PLAG
        let minchaGdolaGRA = chatzotVisible.addingTimeInterval(shaahZmanitVisible * 0.5)
        let minchaGdolaFixed = chatzotVisible.addingTimeInterval(30 * 60)

        let opMinchaG_GRA = ZmanOpinion(id: "mg-gra", title: "0.5 שעה זמנית (גר״א)", time: timeString(minchaGdolaGRA))
        let opMinchaG_YY = ZmanOpinion(id: "mg-yy", title: "30 דקות (ילקוט יוסף)", time: timeString(minchaGdolaFixed))
        
        // По умолчанию для сефардов (Ялкут Йосеф): 30 минут фикс
        let minchaOps = [opMinchaG_YY, opMinchaG_GRA]

        let minchaKetanaGRA = calcZman(start: sunriseVisible, end: sunsetVisible, ratio: 9.5/12.0)
        let opMinchaK_GRA = ZmanOpinion(id: "mk-gra", title: "9.5 שעות (גר״א)", time: timeString(minchaKetanaGRA))

        let plagGRA = sunsetVisible.addingTimeInterval(-1.25 * shaahZmanitVisible)
        
        // Plag YY: 13.5 Zmaniyot from VISIBLE Sunset
        let secIn13_5 = 13.5 * (shaahZmanitVisible / 60.0)
        let tzeitYY = sunsetVisible.addingTimeInterval(secIn13_5)
        let plagYY = tzeitYY.addingTimeInterval(-1.25 * shaahZmanitVisible)

        let opPlagGRA = ZmanOpinion(id: "plag-gra", title: "גר״א (מזריחה עד שקיעה)", time: timeString(plagGRA))
        let opPlagYY = ZmanOpinion(id: "plag-yy", title: "ילקוט יוסף (מזריחה עד צאת)", time: timeString(plagYY))

        // По умолчанию для сефардов: Ялкут Йосеф
        let plagOps = [opPlagYY, opPlagGRA]

        // TZEIT / HAVDALAH (BOTTOM LIST - All Opinions)
        
        let tzeit13_5 = sunsetVisible.addingTimeInterval(secIn13_5)
        let opTzeit13_5 = ZmanOpinion(id: "tzeit-13.5", title: "13.5 דק׳ זמניות (ימי חול / ילקוט יוסף)", time: timeString(tzeit13_5))
        
        // 8.5 Degrees (Visible)
        let opTzeit8_5 = ZmanOpinion(id: "tzeit-8.5", title: "8.5° מעלות (שבת / חב״ד / ליטאים)", time: timeString(tzeit8_5_Visible))
        
        // 72 Fixed (Mishor) - Rabbeinu Tam Sefardi
        let rt72Mishor = sunsetSeaLevel.addingTimeInterval(72 * 60)
        let opRT72Fix = ZmanOpinion(id: "rt-72", title: "רבינו תם (72 דק׳ מהמישור)", time: timeString(rt72Mishor))
        
        // 16.1 Degrees (Mishor) - Rabbeinu Tam Ashkenaz
        let opRT16_1 = ZmanOpinion(id: "rt-16.1", title: "רבינו תם (16.1° מעלות)", time: timeString(tzeit16_1_Mishor))

        // Earliest (30 min Mishor)
        let opTzeit30 = ZmanOpinion(id: "tzeit-30", title: "30 דקות מהמישור (המוקדם ביותר)", time: timeString(sunsetSeaLevel.addingTimeInterval(30*60)))
        
        // 40 min from Visible (Sefardi Standard)
        let opTzeit40 = ZmanOpinion(id: "tzeit-40", title: "40 דקות מהשקיעה (מנהג הספרדים)", time: timeString(sunsetVisible.addingTimeInterval(40*60)))
        
        // 50 min from Visible (Stringent)
        let opTzeit50 = ZmanOpinion(id: "tzeit-50", title: "50 דקות מהשקיעה (חזון איש)", time: timeString(sunsetVisible.addingTimeInterval(50*60)))

        // По умолчанию для сефардов (для будней): 13.5 минут
        let tzeitList = [opTzeit13_5, opRT72Fix, opTzeit8_5, opRT16_1]
        
        // Havdalah (Выход Шаббата)
        // По умолчанию ставим 8.5°, так как это наиболее частый стандарт для всех,
        // но добавим остальные для выбора.
        // Вы просили "по умолчанию как у Рава Овадьи", для Шаббата он часто приводит и RT, и 8.5 как минимум.
        // Оставим 8.5 первым, как в предыдущей итерации, чтобы соответствовало вашему запросу "по умолчанию 8.5".
        let havdalahOpinions = [opTzeit8_5, opTzeit40, opTzeit30, opTzeit50, opRT72Fix, opRT16_1]

        // CHATZOT LAYLA
        cal.workingDate = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        let sunriseNext = cal.getSunrise() ?? sunriseVisible.addingTimeInterval(24*3600)
        cal.workingDate = date
        let nightLen = sunriseNext.timeIntervalSince(sunsetVisible)
        let chatzotLayla = sunsetVisible.addingTimeInterval(nightLen / 2.0)

        // --- ARRAY ---
        var items: [ZmanItem] = []

        items.append(ZmanItem(id: "alos", title: "עלות השחר", opinions: alosOpinions))
        items.append(ZmanItem(id: "tzitzitTefillin", title: "זמן ציצית ותפילין (משיכיר)", opinions: tzitzitOpinions))
        
        items.append(ZmanItem(
            id: "netz",
            title: "הנץ החמה",
            opinions: [ZmanOpinion(id: "netz", title: "הנץ הנראה (Topocentric)", time: timeString(sunriseVisible))],
            subtitle: "כולל גובה טופוגרפי (\(Int(geoLocation.elevation)) מ׳)"
        ))

        items.append(ZmanItem(id: "sofShmaGRA", title: "סו״ז קריאת שמע (גר״א)", opinions: [opShmaGRA], subtitle: "סוף ג׳ שעות"))
        items.append(ZmanItem(id: "sofShmaMGA", title: "סו״ז קריאת שמע (מגן אברהם)", opinions: shmaMGA_Ops, subtitle: "לחומרא"))

        items.append(ZmanItem(id: "sofTfilaGRA", title: "סו״ז תפילה (גר״א)", opinions: [opTfilaGRA], subtitle: "סוף ד׳ שעות"))
        items.append(ZmanItem(id: "sofTfilaMGA", title: "סו״ז תפילה (מגן אברהם)", opinions: [opTfilaMGA_Sef], subtitle: "לחומרא"))

        items.append(ZmanItem(id: "chatzot", title: "חצות היום", opinions: [ZmanOpinion(id: "chatzot", title: "חצות", time: timeString(chatzotVisible))]))
        items.append(ZmanItem(id: "minchaGedola", title: "מנחה גדולה", opinions: minchaOps))
        items.append(ZmanItem(id: "minchaKetana", title: "מנחה קטנה", opinions: [opMinchaK_GRA], subtitle: "9.5 שעות"))
        items.append(ZmanItem(id: "plagHamincha", title: "פלג המנחה", opinions: plagOps))

        items.append(ZmanItem(
            id: "shekiya",
            title: "שקיעת החמה",
            opinions: [
                ZmanOpinion(id: "shekiya-visible", title: "שקיעה נראית (Topocentric)", time: timeString(sunsetVisible)),
                ZmanOpinion(id: "shekiya-mishorit", title: "שקיעה מישורית (Sea Level)", time: timeString(sunsetSeaLevel))
            ],
            subtitle: "כולל גובה טופוגרפי (\(Int(geoLocation.elevation)) מ׳)"
        ))

        items.append(ZmanItem(id: "tzeit", title: "צאת הכוכבים", opinions: tzeitList))
        
        // Показывать Havdalah только в Шаббат или Йом Тов
        if isShabbatOrYomTov(date: date) {
            items.append(ZmanItem(id: "havdalah", title: "צאת השבת / חג", opinions: havdalahOpinions))
        }
        
        items.append(ZmanItem(id: "chatzotLayla", title: "חצות הלילה", opinions: [ZmanOpinion(id: "chatzot-layla", title: "אמצע הלילה", time: timeString(chatzotLayla))]))

        return items
    }
    
    // MARK: - Private Helpers
    
    private func isShabbatOrYomTov(date: Date) -> Bool {
        // Проверка на Шаббат (Суббота)
        var calGreg = Calendar.current
        calGreg.timeZone = geoLocation.timeZone
        let weekday = calGreg.component(.weekday, from: date)
        if weekday == 7 { return true } // 7 = Saturday
        
        // Проверка на Йом Тов (праздники)
        var hebCal = Calendar(identifier: .hebrew)
        hebCal.timeZone = geoLocation.timeZone
        let comps = hebCal.dateComponents([.month, .day], from: date)
        guard let month = comps.month, let day = comps.day else { return false }
        
        let leap = (hebCal.range(of: .month, in: .year, for: date)?.count ?? 12) == 13
        
        // Список дат праздников (Йом Тов, где есть Havdalah)
        switch (month, day) {
        // 1 = Nissan, 3 = Sivan, 7 = Tishrei
        // Rosh Hashana (Tishrei 1, 2)
        case (7, 1), (7, 2): return true
        // Yom Kippur (Tishrei 10)
        case (7, 10): return true
        // Sukkot (Tishrei 15)
        case (7, 15): return true
        // Shemini Atzeret / Simchat Torah (Tishrei 22)
        case (7, 22): return true
        // Pesach (Nissan 15, 21 - in Israel only 21 is last day)
        case (1, 15), (1, 21): return true
        // Shavuot (Sivan 6)
        case (3, 6): return true
        default: return false
        }
    }

    private func timeString(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        return timeFormatter.string(from: d)
    }
    
    private func timeString(_ val: Double, from start: Date, to end: Date, ratio: Double) -> String {
        let len = end.timeIntervalSince(start)
        let d = start.addingTimeInterval(len * ratio)
        return timeFormatter.string(from: d)
    }
}
