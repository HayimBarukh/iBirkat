import Foundation

// MARK: - Модель брохи

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

// MARK: - Нусах

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

// MARK: - Константы брох

let birkatHamazon  = Prayer(title: "ברכת המזון",  basePdfName: "birkat hamazon")
let meenShalosh    = Prayer(title: "מעין שלש",     basePdfName: "meenshalosh")
let boreNefashot   = Prayer(title: "בורא נפשות",  basePdfName: "borenefashot")

let allAfterFoodPrayers: [Prayer] = [
    birkatHamazon,
    meenShalosh,
    boreNefashot
]
