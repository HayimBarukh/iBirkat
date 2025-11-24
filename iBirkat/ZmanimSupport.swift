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

    var tabletLabel: String {
        switch self {
        case .sephardi:  return "עדות המזרח"
        case .ashkenazi: return "אשכנז"
        case .chabad:    return "חב״ד"
        case .custom:    return "מותאם"
        }
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
        return Calendar.current.date(byAdding: .minute, value: -minutesBeforeSunset, to: sunset)
    }

    /// Все зманим для указанной даты и профиля
    func zmanim(for date: Date, profile: HalachicProfile) -> [ZmanItem] {
        cal.workingDate = date

        let candleOffsetMinutes = UserDefaults.standard.integer(forKey: "candleLightingOffset")
        let candleLighting = candleLighting(for: date, minutesBeforeSunset: candleOffsetMinutes)

        let dawn90    = cal.getAlosHashachar(90.0)
        let dawn72    = cal.getAlosHashachar(72.0, useElevation: false)
        let dawn161   = cal.getAlosHashachar(16.1, useElevation: false)

        let tallit115 = cal.getMisheyakir(11.5, useElevation: false)
        let tallit11  = cal.getMisheyakir(11.0, useElevation: false)
        let tallit102 = cal.getMisheyakir(10.2, useElevation: false)

        let hanetz    = cal.getSunrise()

        let sofZmanShmaMGA90   = cal.getSofZmanShmaMGA()
        let sofZmanShmaMGA72   = cal.getSofZmanShmaMGA72Minutes()
        let sofZmanShmaMGA72Deg = cal.getSofZmanShma(72.0)

        let sofZmanShmaGRA = cal.getSofZmanShmaGRA()

        let sofZmanTefilahMGA90 = cal.getSofZmanTfilaMGA()
        let sofZmanTefilahMGA72 = cal.getSofZmanTfilaMGA72Minutes()
        let sofZmanTefilahMGA72Deg = cal.getSofZmanTfila(72.0)

        let sofZmanTefilahGRA = cal.getSofZmanTfilaGRA()

        let chatzot = cal.getChatzos()

        let minchaGedolaMGA = cal.getMinchaGedolaMGA()
        let minchaGedolaGRA = cal.getMinchaGedolaGRA()

        let minchaKetanaGRA = cal.getMinchaKetanaGRA()

        let plagGRA = cal.getPlagHaminchaGRA()
        let plagMGA = cal.getPlagHaminchaMGA()

        let sunset = cal.getSunset()

        let tzeit13_5 = cal.getTzais(13.5)
        let tzeit16_875 = cal.getTzais(16.875)
        let tzeit18 = cal.getTzais(18.0)
        let tzeit24 = cal.getTzais(24.0)

        let nightGRA13_5 = cal.getTzaisGeonim3Stars18Minutes()
        let nightGRA18 = cal.getTzais(18.0)
        let nightGRA22_5 = cal.getTzais(22.5)
        let nightGRA24 = cal.getTzais(24.0)

        let taanitTokchinski = cal.getTzais(27.0)
        let tzeit34 = cal.getTzais(34.0)
        let tzeit36 = cal.getTzais(36.0)
        let tzeit40 = cal.getTzais(40.0)

        let nightRabbeinuTam72 = cal.getTzais72Zmanis()
        let chatzotLayla = cal.getChatzosLayla()

        var items: [ZmanItem] = []

        items.append(
            ZmanItem(
                id: "alos-hashachar",
                title: "עלות השחר",
                opinions: [
                    ZmanOpinion(
                        id: "dawn-90",
                        title: "90 דקות במעלות קודם הנץ",
                        time: timeString(dawn90)
                    ),
                    ZmanOpinion(
                        id: "dawn-72-fixed",
                        title: "72 דקות שוות קודם הנץ",
                        time: timeString(dawn72)
                    ),
                    ZmanOpinion(
                        id: "dawn-72-deg",
                        title: "72 דקות לפי 16.1 מעלות",
                        time: timeString(dawn161)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "tallit-tefillin",
                title: "זמן ציצית ותפילין",
                opinions: [
                    ZmanOpinion(
                        id: "tallit-11.5",
                        title: "11.5 מעלות תחת האופק",
                        time: timeString(tallit115)
                    ),
                    ZmanOpinion(
                        id: "tallit-11",
                        title: "11 מעלות תחת האופק",
                        time: timeString(tallit11)
                    ),
                    ZmanOpinion(
                        id: "tallit-10.2",
                        title: "10.2 מעלות תחת האופק",
                        time: timeString(tallit102)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "hanetz-hachama",
                title: "הנץ החמה",
                opinions: [
                    ZmanOpinion(
                        id: "sunrise-sea-level",
                        title: "מישור בגובה פני הים",
                        time: timeString(hanetz)
                    )
                ],
                subtitle: "תחילת היום המעשי"
            )
        )

        items.append(
            ZmanItem(
                id: "sof-zman-shma-MGA",
                title: "סו\"ז ק\"ש (מג\"א)",
                opinions: [
                    ZmanOpinion(
                        id: "shma-mga-90",
                        title: "לפי 90 דקות במעלות",
                        time: timeString(sofZmanShmaMGA90)
                    ),
                    ZmanOpinion(
                        id: "shma-mga-72-fixed",
                        title: "לפי 72 דקות שוות",
                        time: timeString(sofZmanShmaMGA72)
                    ),
                    ZmanOpinion(
                        id: "shma-mga-72-deg",
                        title: "לפי 72 דקות במעלות",
                        time: timeString(sofZmanShmaMGA72Deg)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "sof-zman-shma-GRA",
                title: "סו\"ז ק\"ש (גר\"א והבע\"ט)",
                opinions: [
                    ZmanOpinion(
                        id: "shma-gra",
                        title: "גר\"א ובעל התניא",
                        time: timeString(sofZmanShmaGRA)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "sof-zman-tefila-MGA",
                title: "סו\"ז תפילה (מג\"א)",
                opinions: [
                    ZmanOpinion(
                        id: "tefila-mga-90",
                        title: "לפי 90 דקות במעלות",
                        time: timeString(sofZmanTefilahMGA90)
                    ),
                    ZmanOpinion(
                        id: "tefila-mga-72-fixed",
                        title: "לפי 72 דקות שוות",
                        time: timeString(sofZmanTefilahMGA72)
                    ),
                    ZmanOpinion(
                        id: "tefila-mga-72-deg",
                        title: "לפי 72 דקות במעלות",
                        time: timeString(sofZmanTefilahMGA72Deg)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "sof-zman-tefila-GRA",
                title: "סו\"ז תפילה (גר\"א והבע\"ט)",
                opinions: [
                    ZmanOpinion(
                        id: "tefila-gra",
                        title: "גר\"א ובעל התניא",
                        time: timeString(sofZmanTefilahGRA)
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
                        id: "chatzot-hayom",
                        title: "שש שעות זמניות מהנץ",
                        time: timeString(chatzot)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "mincha-gedola",
                title: "מנחה גדולה",
                opinions: [
                    ZmanOpinion(
                        id: "mincha-gedola-gra",
                        title: "חצות + 30 דקות במעלות",
                        time: timeString(minchaGedolaGRA)
                    ),
                    ZmanOpinion(
                        id: "mincha-gedola-mga",
                        title: "חצות + ½ שעה זמנית",
                        time: timeString(minchaGedolaMGA)
                    )
                ],
                subtitle: "זמן לכתחילה למנחה"
            )
        )

        items.append(
            ZmanItem(
                id: "mincha-ktana",
                title: "מנחה קטנה",
                opinions: [
                    ZmanOpinion(
                        id: "mincha-ketana-gra",
                        title: "9.5 שעות זמניות מהנץ",
                        time: timeString(minchaKetanaGRA)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "plag-hamincha",
                title: "פלג המנחה",
                opinions: [
                    ZmanOpinion(
                        id: "plag-gra",
                        title: "10.75 שעות זמניות מהנץ",
                        time: timeString(plagGRA)
                    ),
                    ZmanOpinion(
                        id: "plag-mga",
                        title: "11 שעות זמניות מהנץ",
                        time: timeString(plagMGA)
                    )
                ],
                subtitle: nil
            )
        )

        items.append(
            ZmanItem(
                id: "candle-lighting",
                title: "תוספת שבת/יו\"ט",
                opinions: [
                    ZmanOpinion(
                        id: "candle-18",
                        title: "18 דקות לפני השקיעה",
                        time: timeString(candleLighting)
                    ),
                    ZmanOpinion(
                        id: "candle-40",
                        title: "40 דקות לפני השקיעה",
                        time: timeString(candleLighting(for: date, minutesBeforeSunset: 40))
                    )
                ],
                subtitle: "זמן הדלקת נרות (מותאם להעדפה)"
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
