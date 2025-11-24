import Foundation
import KosherSwift

/// Дополнение для расчёта получестного времени ночи (חצות לילה), отсутствующего в API KosherSwift.
extension ComplexZmanimCalendar {
    /// Полночь по дуге между закатом текущего дня и восходом следующего дня.
    func getChatzosLayla() -> Date? {
        guard let sunset = getSunset() else { return nil }

        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: workingDate)
            ?? workingDate.addingTimeInterval(86_400)

        let nextDayCalendar = ComplexZmanimCalendar(location: geoLocation)
        nextDayCalendar.workingDate = nextDate

        guard let nextSunrise = nextDayCalendar.getSunrise() else { return nil }

        let interval = nextSunrise.timeIntervalSince(sunset)
        return sunset.addingTimeInterval(interval / 2)
    }
}
