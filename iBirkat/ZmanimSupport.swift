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
        let resolvedID = id ?? title
        let safeOpinions = opinions.isEmpty
            ? [ZmanOpinion(id: "\(resolvedID)-placeholder", title: "—", time: "—")]
            : opinions

        self.id = resolvedID
        self.title = title
        self.opinions = safeOpinions
        self.subtitle = subtitle
    }
}

// MARK: - Профили общин

enum HalachicProfile: String, CaseIterable, Identifiable {
    case sephardi     // עדות המזרח / ר׳ עובדיה
    case ashkenazi    // אשכנז (ישיבתי)
    case chabad       // חב״ד
    case custom       // מותאם אישית

    var id: Self { self }

    /// Базовые профили без кастомного режима
    static var basicCases: [HalachicProfile] {
        [.sephardi, .ashkenazi, .chabad]
    }

    var shortSymbol: String {
        switch self {
        case .sephardi:  return "ע״מ"
        case .ashkenazi: return "א"
        case .chabad:    return "ח"
        case .custom:    return "מותאם"
        }
    }

    var title: String {
        switch self {
        case .sephardi:  return "עדות המזרח / ר׳ עובדיה"
        case .ashkenazi: return "אשכנז (ישיבתי)"
        case .chabad:    return "חב״ד"
        case .custom:    return "פרופיל מותאם אישית"
        }
    }

    var iconName: String {
        switch self {
        case .sephardi:  return "menorah"
        case .ashkenazi: return "books.vertical"
        case .chabad:    return "staroflife"
        case .custom:    return "slider.horizontal.3"
        }
    }
}

// MARK: - Провайдер зманим

final class ZmanimProvider {

    private let geoLocation: GeoLocation
    private let cal: ComplexZmanimCalendar

    private lazy var timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.dateFormat = "HH:mm"
        df.timeZone = geoLocation.timeZone
        return df
    }()

    init(geoLocation: GeoLocation) {
        self.geoLocation = geoLocation
        self.cal = ComplexZmanimCalendar(location: geoLocation)
    }

    /// Вспомогательный метод: выставляем дату и возвращаем закат
    private func sunset(for date: Date) -> Date? {
        cal.workingDate = date
        return cal.getSunset()
    }

    /// Время зажигания свечей (минут до заката)
    func candleLighting(for date: Date, minutesBeforeSunset: Int) -> Date? {
        guard let sunset = sunset(for: date) else { return nil }
        return sunset.addingTimeInterval(-Double(minutesBeforeSunset) * 60)
    }

    /// Время выхода субботы/праздника (смещение в минутах после заката)
    func motzaeiShabbatOrYomTov(for date: Date, offsetMinutes: Int = 40) -> Date? {
        guard let sunset = sunset(for: date) else { return nil }
        return sunset.addingTimeInterval(Double(offsetMinutes) * 60)
    }

    /// Главный метод: список зманим на день
    func zmanim(
        for date: Date,
        profile: HalachicProfile
    ) -> [ZmanItem] {
        cal.workingDate = date

        guard
            let sunrise = cal.getSunrise(),
            let sunset  = cal.getSunset()
        else {
            return []
        }

        // День от נץ до שקיעה — שעה זמנית (גר״א / בעל התניא)
        let dayNetzToShkia = sunset.timeIntervalSince(sunrise)
        let shaahZmanitGRA = dayNetzToShkia / 12.0
        let chatzot        = sunrise.addingTimeInterval(dayNetzToShkia / 2.0)

        // ---------------------------------------------------------
        // ALOT HASHACHAR
        // ---------------------------------------------------------
        //
        // 🟠 ס״פ: 72 דקות שוות קודם הנץ
        // 🔵 א״ש / 🟣 חב״ד: 72 דקות זמניות (≈16.1°)
        // кастом — как ס״פ по умолчанию.
        //

        // 90 минут זמניות (1.5 שעה זמנית)
        let alos90Zmaniyot = sunrise.addingTimeInterval(-1.5 * shaahZmanitGRA)

        // 72 минуты швот
        let alos72Fixed    = sunrise.addingTimeInterval(-72.0 * 60.0)

        // 72 минуты זמניות (1.2 שעה זמנית) — ≈16.1°
        let alos72Zmaniyot = sunrise.addingTimeInterval(-1.2 * shaahZmanitGRA)

        let alos90Opinion = ZmanOpinion(
            id: "alos-90-zmaniyot",
            title: "90 דקות בזמניות קודם הנץ",
            time: timeString(alos90Zmaniyot)
        )

        let alos72FixedOpinion = ZmanOpinion(
            id: "alos-72-fixed",
            title: "72 דקות שוות קודם הנץ",
            time: timeString(alos72Fixed)
        )

        let alos72ZmaniyotOpinion = ZmanOpinion(
            id: "alos-72-zmaniyot",
            title: "72 דקות בזמניות (≈16.1°) קודם הנץ",
            time: timeString(alos72Zmaniyot)
        )

        let alosOpinions: [ZmanOpinion]
        switch profile {
        case .sephardi, .custom:
            // базовая — 72 швот
            alosOpinions = [
                alos72FixedOpinion,
                alos72ZmaniyotOpinion,
                alos90Opinion
            ]
        case .ashkenazi, .chabad:
            // базовая — 72 זמניות
            alosOpinions = [
                alos72ZmaniyotOpinion,
                alos72FixedOpinion,
                alos90Opinion
            ]
        }

        // ---------------------------------------------------------
        // זמן ציצית ותפילין (משיכיר)
        // ---------------------------------------------------------
        //
        // ס״פ – ≈11° (≈48 мин)
        // א״ש / חב״ד – ≈11.5° (≈52 мин)
        // לחומרא – ≈10.2° (≈46 мин)
        //

        let tzitzit11   = sunrise.addingTimeInterval(-48 * 60) // ≈11°
        let tzitzit11_5 = sunrise.addingTimeInterval(-52 * 60) // ≈11.5°
        let tzitzit10_2 = sunrise.addingTimeInterval(-46 * 60) // ≈10.2°

        let tz11 = ZmanOpinion(
            id: "tzitzit-11",
            title: "≈11° מתחת לאופק (≈48 דקות קודם הנץ)",
            time: timeString(tzitzit11)
        )

        let tz11_5 = ZmanOpinion(
            id: "tzitzit-11.5",
            title: "≈11.5° מתחת לאופק (≈52 דקות קודם הנץ)",
            time: timeString(tzitzit11_5)
        )

        let tz10_2 = ZmanOpinion(
            id: "tzitzit-10.2",
            title: "≈10.2° מתחת לאופק (≈46 דקות קודם הנץ, לחומרא)",
            time: timeString(tzitzit10_2)
        )

        let tzitzitOpinions: [ZmanOpinion]
        switch profile {
        case .sephardi, .custom:
            tzitzitOpinions = [tz11, tz11_5, tz10_2]
        case .ashkenazi, .chabad:
            tzitzitOpinions = [tz11_5, tz11, tz10_2]
        }

        // ---------------------------------------------------------
        // СОФ ЗМАН К״ש / ТФИЛА (Мג״א / גר״א)
        // ---------------------------------------------------------

        enum MADayVariant {
            case ma90Zmaniyot
            case ma72Fixed
            case ma72Zmaniyot
        }

        func maBounds(_ variant: MADayVariant) -> (start: Date, end: Date) {
            switch variant {
            case .ma90Zmaniyot:
                let delta = 1.5 * shaahZmanitGRA
                return (sunrise.addingTimeInterval(-delta),
                        sunset.addingTimeInterval(delta))

            case .ma72Fixed:
                let delta = 72.0 * 60.0
                return (sunrise.addingTimeInterval(-delta),
                        sunset.addingTimeInterval(delta))

            case .ma72Zmaniyot:
                let delta = (72.0 / 60.0) * shaahZmanitGRA
                return (sunrise.addingTimeInterval(-delta),
                        sunset.addingTimeInterval(delta))
            }
        }

        func maSofZmanShma(_ variant: MADayVariant) -> Date {
            let (start, end) = maBounds(variant)
            let dayLen = end.timeIntervalSince(start)
            return start.addingTimeInterval(dayLen * 3.0 / 12.0)
        }

        func maSofZmanTfila(_ variant: MADayVariant) -> Date {
            let (start, end) = maBounds(variant)
            let dayLen = end.timeIntervalSince(start)
            return start.addingTimeInterval(dayLen * 4.0 / 12.0)
        }

        // גר״א / בעל התניא: день от נץ до שקיעה
        let sofShmaGRA  = sunrise.addingTimeInterval(3.0 * shaahZmanitGRA)
        let sofTfilaGRA = sunrise.addingTimeInterval(4.0 * shaahZmanitGRA)

        // ---------------------------------------------------------
        // Минха, плаг
        // ---------------------------------------------------------

        let minchaGdolaGRA  = chatzot.addingTimeInterval(shaahZmanitGRA / 2.0)
        let minchaGdolaMA72 = chatzot.addingTimeInterval(30.0 * 60.0)

        let minchaKetanaGRA  = sunrise.addingTimeInterval(9.5 * shaahZmanitGRA)
        let minchaKetanaMA72 = minchaKetanaGRA

        let plagGRA  = sunrise.addingTimeInterval(10.75 * shaahZmanitGRA)
        let plagMA72 = plagGRA

        // ---------------------------------------------------------
        // Ночь / выход звёзд
        // ---------------------------------------------------------

        let nightGRA13_5 = sunset.addingTimeInterval(13.5 * 60.0)
        let nightGRA18   = sunset.addingTimeInterval(18.0 * 60.0)
        let nightGRA22_5 = sunset.addingTimeInterval(22.5 * 60.0)
        let nightGRA24   = sunset.addingTimeInterval(24.0 * 60.0)

        let taanitTokchinski = sunset.addingTimeInterval(27.0 * 60.0)

        let tzeit34 = sunset.addingTimeInterval(34.0 * 60.0)
        let tzeit36 = sunset.addingTimeInterval(36.0 * 60.0)
        let tzeit40 = sunset.addingTimeInterval(40.0 * 60.0)

        let nightRabbeinuTam72 = sunset.addingTimeInterval(72.0 * 60.0)

        let chatzotLayla = chatzot.addingTimeInterval(12.0 * 60.0 * 60.0)

        // ---------------------------------------------------------
        // Формирование списка
        // ---------------------------------------------------------

        var items: [ZmanItem] = []

        items.append(
            ZmanItem(
                id: "alos",
                title: "עלות השחר",
                opinions: alosOpinions,
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "tzitzitTefillin",
                title: "זמן ציצית ותפילין",
                opinions: tzitzitOpinions,
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "netz",
                title: "הנץ החמה",
                opinions: [
                    ZmanOpinion(
                        id: "netz-sea",
                        title: "מישור בגובה פני הים",
                        time: timeString(sunrise)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "sofShma-MA",
                title: "סוף זמן קריאת שמע (מגן אברהם)",
                opinions: [
                    ZmanOpinion(
                        id: "sofShma-MA-90-zmaniyot",
                        title: "לפי 90 דקות בזמניות",
                        time: timeString(maSofZmanShma(.ma90Zmaniyot))
                    ),
                    ZmanOpinion(
                        id: "sofShma-MA-72-fixed",
                        title: "לפי 72 דקות שוות",
                        time: timeString(maSofZmanShma(.ma72Fixed))
                    ),
                    ZmanOpinion(
                        id: "sofShma-MA-72-zmaniyot",
                        title: "לפי 72 דקות בזמניות",
                        time: timeString(maSofZmanShma(.ma72Zmaniyot))
                    )
                ],
                subtitle: "סוף ג׳ שעות זמניות"
            )
        )

        items.append(
            ZmanItem(
                id: "sofShma-GRA",
                title: "סוף זמן קריאת שמע (גר״א ובעל התניא)",
                opinions: [
                    ZmanOpinion(
                        id: "sofShma-GRA-main",
                        title: "ג׳ שעות זמניות מן הנץ",
                        time: timeString(sofShmaGRA)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "sofTfila-MA",
                title: "סוף זמן תפילה (מגן אברהם)",
                opinions: [
                    ZmanOpinion(
                        id: "sofTfila-MA-90-zmaniyot",
                        title: "לפי 90 דקות בזמניות",
                        time: timeString(maSofZmanTfila(.ma90Zmaniyot))
                    ),
                    ZmanOpinion(
                        id: "sofTfila-MA-72-fixed",
                        title: "לפי 72 דקות שוות",
                        time: timeString(maSofZmanTfila(.ma72Fixed))
                    ),
                    ZmanOpinion(
                        id: "sofTfila-MA-72-zmaniyot",
                        title: "לפי 72 דקות בזמניות",
                        time: timeString(maSofZmanTfila(.ma72Zmaniyot))
                    )
                ],
                subtitle: "סוף ד׳ שעות זמניות"
            )
        )

        items.append(
            ZmanItem(
                id: "sofTfila-GRA",
                title: "סוף זמן תפילה (גר״א ובעל התניא)",
                opinions: [
                    ZmanOpinion(
                        id: "sofTfila-GRA-main",
                        title: "ד׳ שעות זמניות מן הנץ",
                        time: timeString(sofTfilaGRA)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "chatzot",
                title: "חצות היום",
                opinions: [
                    ZmanOpinion(
                        id: "chatzot-main",
                        title: "אמצע היום ההלכתי",
                        time: timeString(chatzot)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "minchaGedola",
                title: "מנחה גדולה",
                opinions: [
                    ZmanOpinion(
                        id: "minchaG-GRA",
                        title: "גר\"א ובעל התניא",
                        time: timeString(minchaGdolaGRA)
                    ),
                    ZmanOpinion(
                        id: "minchaG-MA-72-fixed",
                        title: "לחומרא (מגן אברהם, 30 דקות שוות אחר חצות)",
                        time: timeString(minchaGdolaMA72)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "minchaKetana",
                title: "מנחה קטנה",
                opinions: [
                    ZmanOpinion(
                        id: "minchaK-GRA",
                        title: "גר\"א ובעל התניא",
                        time: timeString(minchaKetanaGRA)
                    ),
                    ZmanOpinion(
                        id: "minchaK-MA-72-fixed",
                        title: "מגן אברהם (72 דקות שוות)",
                        time: timeString(minchaKetanaMA72)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "plagHamincha",
                title: "פלג המנחה",
                opinions: [
                    ZmanOpinion(
                        id: "plag-GRA",
                        title: "גר\"א ובעל התניא",
                        time: timeString(plagGRA)
                    ),
                    ZmanOpinion(
                        id: "plag-MA-72-fixed",
                        title: "מגן אברהם (72 דקות שוות)",
                        time: timeString(plagMA72)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "shekiya",
                title: "שקיעת החמה",
                opinions: [
                    ZmanOpinion(
                        id: "shekiya-sea",
                        title: "מישור בגובה פני הים",
                        time: timeString(sunset)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "night-GRA-3-4-mil",
                title: "לילה לגר״א - ג׳ רבעי מיל",
                opinions: [
                    ZmanOpinion(
                        id: "night-GRA-13.5",
                        title: "13½ דקות אחרי השקיעה",
                        time: timeString(nightGRA13_5)
                    ),
                    ZmanOpinion(
                        id: "night-GRA-18",
                        title: "18 דקות אחרי השקיעה",
                        time: timeString(nightGRA18)
                    ),
                    ZmanOpinion(
                        id: "night-GRA-22.5",
                        title: "22½ דקות אחרי השקיעה",
                        time: timeString(nightGRA22_5)
                    ),
                    ZmanOpinion(
                        id: "night-GRA-24",
                        title: "24 דקות אחרי השקיעה (סידור אדה\"ז)",
                        time: timeString(nightGRA24)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "taaniyot-end",
                title: "לילה - גמר תעניות דרבנן",
                opinions: [
                    ZmanOpinion(
                        id: "taanit-tokchinski",
                        title: "ר׳ טוקצ׳ינסקי – 27 דקות אחרי השקיעה",
                        time: timeString(taanitTokchinski)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "tzeit-3-stars",
                title: "צאת ג׳ כוכבים",
                opinions: [
                    ZmanOpinion(
                        id: "tzeit-34",
                        title: "34 דקות אחרי השקיעה",
                        time: timeString(tzeit34)
                    ),
                    ZmanOpinion(
                        id: "tzeit-36",
                        title: "36 דקות אחרי השקיעה",
                        time: timeString(tzeit36)
                    ),
                    ZmanOpinion(
                        id: "tzeit-40",
                        title: "40 דקות אחרי השקיעה (מוצאי שבת ויו\"ט / חזון איש)",
                        time: timeString(tzeit40)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "night-RabbeinuTam",
                title: "לילה לרבינו תם - ד׳ מילין",
                opinions: [
                    ZmanOpinion(
                        id: "rt-72-fixed",
                        title: "72 דקות שוות אחר השקיעה",
                        time: timeString(nightRabbeinuTam72)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "chatzotLayla",
                title: "חצות הלילה",
                opinions: [
                    ZmanOpinion(
                        id: "chatzot-layla",
                        title: "אמצע הלילה ההלכתי",
                        time: timeString(chatzotLayla)
                    )
                ],
                subtitle: nil
            )
        )

        return items
    }

    // MARK: - Helpers

    private func timeString(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        return timeFormatter.string(from: d)
    }
}
