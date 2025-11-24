import Foundation

// Описание одного времени
struct ZmanDefinition: Identifiable {
    let id = UUID()
    let name: String          // например: "עלות השחר"
    let category: String      // группа: "תחילת היום", "צאת הכוכבים" и т.п.
    let opinions: [ZmanOpinionDefinition]
}

// Описание одной шиты для этого времени
struct ZmanOpinionDefinition: Identifiable {
    let id = UUID()
    let title: String         // текст шиты
    let note: String?         // пояснение / источник (опционально)
}

// Группа времен по категории для красивого вывода
struct ZmanSection: Identifiable {
    let id = UUID()
    let title: String
    let zmanim: [ZmanDefinition]
}

// ВСЕ ВРЕМЕНА И ШИТОТ — как ты дал
let halachicZmanDefinitions: [ZmanDefinition] = [

    // MARK: - תחילת היום

    ZmanDefinition(
        name: "עלות השחר",
        category: "תחילת היום",
        opinions: [
            ZmanOpinionDefinition(
                title: "90 דקות במעלות קודם הנץ",
                note: "תחילת היום לפי 90 דקות זמניות לפני הנץ"
            ),
            ZmanOpinionDefinition(
                title: "72 דקות שוות קודם הנץ",
                note: "72 דקות קבועות לפני הנץ"
            ),
            ZmanOpinionDefinition(
                title: "72 דקות לפי 16.1 מעלות",
                note: "עלות לפי 16.1° מתחת לאופק"
            )
        ]
    ),

    ZmanDefinition(
        name: "זמן ציצית ותפילין",
        category: "תחילת היום",
        opinions: [
            ZmanOpinionDefinition(
                title: "11.5 מעלות תחת האופק",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "11 מעלות תחת האופק",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "10.2 מעלות תחת האופק",
                note: nil
            )
        ]
    ),

    // MARK: - הנץ החמה

    ZmanDefinition(
        name: "הנץ החמה",
        category: "תחילת היום המעשי",
        opinions: [
            ZmanOpinionDefinition(
                title: "מישור בגובה פני הים",
                note: "זריחת השמש על קו האופק בגובה פני הים"
            )
        ]
    ),

    // MARK: - בוקר: קריאת שמע / תפילה

    ZmanDefinition(
        name: "סו\"ז ק\"ש (מג\"א)",
        category: "בוקר",
        opinions: [
            ZmanOpinionDefinition(
                title: "לפי 90 דקות במעלות",
                note: "תחילת היום 90 דקות זמניות קודם הנץ"
            ),
            ZmanOpinionDefinition(
                title: "לפי 72 דקות שוות",
                note: "תחילת היום 72 דקות קבועות קודם הנץ"
            ),
            ZmanOpinionDefinition(
                title: "לפי 72 דקות במעלות",
                note: "תחילת היום 72 דקות זמניות קודם הנץ"
            )
        ]
    ),

    ZmanDefinition(
        name: "סו\"ז ק\"ש (גר\"א והבע\"ט)",
        category: "בוקר",
        opinions: [
            ZmanOpinionDefinition(
                title: "גר\"א ובעל התניא",
                note: "סוף ג׳ שעות זמניות מהנץ עד השקיעה"
            )
        ]
    ),

    ZmanDefinition(
        name: "סו\"ז תפילה (מג\"א)",
        category: "בוקר",
        opinions: [
            ZmanOpinionDefinition(
                title: "לפי 90 דקות במעלות",
                note: "תחילת היום 90 דקות זמניות קודם הנץ"
            ),
            ZmanOpinionDefinition(
                title: "לפי 72 דקות שוות",
                note: "תחילת היום 72 דקות קבועות קודם הנץ"
            ),
            ZmanOpinionDefinition(
                title: "לפי 72 דקות במעלות",
                note: "תחילת היום 72 דקות זמניות קודם הנץ"
            )
        ]
    ),

    ZmanDefinition(
        name: "סו\"ז תפילה (גר\"א והבע\"ט)",
        category: "בוקר",
        opinions: [
            ZmanOpinionDefinition(
                title: "גר\"א ובעל התניא",
                note: "סוף ד׳ שעות זמניות מהנץ עד השקיעה"
            )
        ]
    ),

    // MARK: - צהריים

    ZmanDefinition(
        name: "חצות היום",
        category: "צהריים",
        opinions: [
            ZmanOpinionDefinition(
                title: "שש שעות זמניות מהנץ",
                note: "אמצע הזמן בין הנץ לשקיעה"
            )
        ]
    ),

    // MARK: - אחר הצהריים

    ZmanDefinition(
        name: "מנחה גדולה",
        category: "אחר הצהריים",
        opinions: [
            ZmanOpinionDefinition(
                title: "חצות + 30 דקות במעלות",
                note: "זמן לכתחילה למנחה"
            ),
            ZmanOpinionDefinition(
                title: "חצות + ½ שעה זמנית",
                note: "חצי שעה זמנית אחרי חצות"
            )
        ]
    ),

    ZmanDefinition(
        name: "מנחה קטנה",
        category: "אחר הצהריים",
        opinions: [
            ZmanOpinionDefinition(
                title: "9.5 שעות זמניות מהנץ",
                note: "תשע שעות ומחצה זמניות"
            )
        ]
    ),

    // MARK: - ערב

    ZmanDefinition(
        name: "פלג המנחה",
        category: "ערב",
        opinions: [
            ZmanOpinionDefinition(
                title: "10.75 שעות זמניות מהנץ",
                note: "פלג לפי הגר\"א"
            ),
            ZmanOpinionDefinition(
                title: "11 שעות זמניות מהנץ",
                note: "פלג לפי מג\"א"
            )
        ]
    ),

    ZmanDefinition(
        name: "תוספת שבת/יו\"ט",
        category: "ערב",
        opinions: [
            ZmanOpinionDefinition(
                title: "18 דקות לפני השקיעה",
                note: "מנהג ירושלים והפוסקים"
            ),
            ZmanOpinionDefinition(
                title: "40 דקות לפני השקיעה",
                note: "מנהג חלק מקהילות אשכנז"
            )
        ]
    ),

    // MARK: - שקיעה / בין השמשות

    ZmanDefinition(
        name: "שקיעת החמה",
        category: "שקיעה",
        opinions: [
            ZmanOpinionDefinition(
                title: "מישור בגובה פני הים",
                note: "שקיעה גיאומטרית (0°)"
            )
        ]
    ),

    ZmanDefinition(
        name: "בין השמשות דרבנו תם",
        category: "בין השמשות",
        opinions: [
            ZmanOpinionDefinition(
                title: "3/4 מיל אחרי השקיעה",
                note: "כ־13.5 דקות זמניות אחרי שקיעה"
            ),
            ZmanOpinionDefinition(
                title: "4/5 מיל אחרי השקיעה",
                note: "כ־18 דקות זמניות אחרי שקיעה"
            )
        ]
    ),

    // MARK: - צאת הכוכבים

    ZmanDefinition(
        name: "צאת הכוכבים (רגיל)",
        category: "צאת הכוכבים",
        opinions: [
            ZmanOpinionDefinition(
                title: "13½ דקות במעלות (הילוך מיל 18 דקות)",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "16⅞ דקות במעלות (הילוך מיל 22.5 דקות)",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "18 דקות במעלות (הילוך מיל 24 דקות)",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "24 דקות במעלות – סידורו של ר׳ שניאור זלמן",
                note: "מנהג חב\"ד"
            )
        ]
    ),

    // MARK: - תעניות

    ZmanDefinition(
        name: "לילה – גמר תעניות דרבנן",
        category: "תעניות",
        opinions: [
            ZmanOpinionDefinition(
                title: "ר׳ טוקצינסקי – 27 דקות במעלות",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "ר׳ משה פיינשטיין – למי שקשה לו להתענות",
                note: nil
            )
        ]
    ),

    // MARK: - צאת ג׳ כוכבים / מוצ"ש

    ZmanDefinition(
        name: "לילה – צאת ג׳ כוכבים",
        category: "צאת ג׳ כוכבים",
        opinions: [
            ZmanOpinionDefinition(
                title: "34 דקות במעלות – ספר מועד מועדים",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "36 דקות במעלות – מוצאי שבת ויום טוב",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "40 דקות במעלות – חזון איש",
                note: nil
            )
        ]
    ),

    // MARK: - רבנו תם

    ZmanDefinition(
        name: "לילה לרבינו תם – ד׳ מילין",
        category: "צאת הכוכבים (חומרא)",
        opinions: [
            ZmanOpinionDefinition(
                title: "72 דקות שוות אחר השקיעה",
                note: nil
            ),
            ZmanOpinionDefinition(
                title: "72 דקות במעלות",
                note: nil
            )
        ]
    ),

    // MARK: - לילה / יחידות זמן

    ZmanDefinition(
        name: "חצות הלילה",
        category: "לילה",
        opinions: [
            ZmanOpinionDefinition(
                title: "אמצע הלילה",
                note: "אמצע הזמן בין שקיעה לזריחה"
            )
        ]
    ),

    ZmanDefinition(
        name: "שעה זמנית",
        category: "יחידות זמן הלכתיות",
        opinions: [
            ZmanOpinionDefinition(
                title: "גר\"א ובעל התניא",
                note: "היום מחולק ל־12 שעות משקיעה לנץ (או להפך)"
            )
        ]
    )
]

// Секции по порядку категорий
let halachicZmanSections: [ZmanSection] = {
    let order: [String] = [
        "תחילת היום",
        "תחילת היום המעשי",
        "בוקר",
        "צהריים",
        "אחר הצהריים",
        "ערב",
        "צאת הכוכבים",
        "תעניות",
        "צאת ג׳ כוכבים",
        "צאת הכוכבים (חומרא)",
        "לילה",
        "יחידות זמן הלכתיות"
    ]

    var sections: [ZmanSection] = []
    for cat in order {
        let items = halachicZmanDefinitions.filter { $0.category == cat }
        if !items.isEmpty {
            sections.append(ZmanSection(title: cat, zmanim: items))
        }
    }
    return sections
}()
