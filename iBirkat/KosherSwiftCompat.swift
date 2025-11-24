import Foundation
import KosherSwift

// Временная совместимость для новых версий KosherSwift, где часть методов была удалена.
// Реализуем наиболее используемые расчёты на основе восхода/заката и пропорциональных часов.
extension ComplexZmanimCalendar {
    /// Вспомогательный час זמני по мнению הגר"א.
    private var graShaahZmanis: TimeInterval? {
        guard let sunrise = getSunrise(), let sunset = getSunset() else { return nil }
        let dayLength = sunset.timeIntervalSince(sunrise)
        guard dayLength > 0 else { return nil }
        return dayLength / 12.0
    }

    /// Вспомогательный час זמני по мнению מג"א (отעלות до צאת עם смещениями).
    private func mgaShaahZmanis(dawnMinutes: Double, tzeitMinutes: Double) -> TimeInterval? {
        guard let dawn = getAlosHashachar(dawnMinutes),
              let sunset = getSunset(),
              let tzeit = getTzais(tzeitMinutes)
        else { return nil }

        let dayLength = tzeit.timeIntervalSince(dawn)
        guard dayLength > 0 else { return nil }
        return dayLength / 12.0
    }

    func getSunrise() -> Date? {
        sunrise()
    }

    func getSunset() -> Date? {
        sunset()
    }

    func getAlosHashachar(_ minutesBeforeSunrise: Double, useElevation: Bool = true) -> Date? {
        guard let sunrise = getSunrise() else { return nil }
        return Calendar.current.date(byAdding: .second,
                                     value: -Int(minutesBeforeSunrise * 60),
                                     to: sunrise)
    }

    func getMisheyakir(_ minutesBeforeSunrise: Double, useElevation: Bool = true) -> Date? {
        getAlosHashachar(minutesBeforeSunrise, useElevation: useElevation)
    }

    func getSofZmanShmaMGA() -> Date? {
        guard let dawn = getAlosHashachar(90.0),
              let shaah = mgaShaahZmanis(dawnMinutes: 90.0, tzeitMinutes: 90.0)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 3)
    }

    func getSofZmanShmaMGA72Minutes() -> Date? {
        guard let dawn = getAlosHashachar(72.0, useElevation: false),
              let shaah = mgaShaahZmanis(dawnMinutes: 72.0, tzeitMinutes: 72.0)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 3)
    }

    func getSofZmanShma(_ dawnMinutes: Double) -> Date? {
        guard let dawn = getAlosHashachar(dawnMinutes, useElevation: false),
              let shaah = mgaShaahZmanis(dawnMinutes: dawnMinutes, tzeitMinutes: dawnMinutes)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 3)
    }

    func getSofZmanShmaGRA() -> Date? {
        guard let sunrise = getSunrise(), let shaah = graShaahZmanis else { return nil }
        return sunrise.addingTimeInterval(shaah * 3)
    }

    func getSofZmanTfilaMGA() -> Date? {
        guard let dawn = getAlosHashachar(90.0),
              let shaah = mgaShaahZmanis(dawnMinutes: 90.0, tzeitMinutes: 90.0)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 4)
    }

    func getSofZmanTfilaMGA72Minutes() -> Date? {
        guard let dawn = getAlosHashachar(72.0, useElevation: false),
              let shaah = mgaShaahZmanis(dawnMinutes: 72.0, tzeitMinutes: 72.0)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 4)
    }

    func getSofZmanTfila(_ dawnMinutes: Double) -> Date? {
        guard let dawn = getAlosHashachar(dawnMinutes, useElevation: false),
              let shaah = mgaShaahZmanis(dawnMinutes: dawnMinutes, tzeitMinutes: dawnMinutes)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 4)
    }

    func getSofZmanTfilaGRA() -> Date? {
        guard let sunrise = getSunrise(), let shaah = graShaahZmanis else { return nil }
        return sunrise.addingTimeInterval(shaah * 4)
    }

    func getChatzos() -> Date? {
        guard let sunrise = getSunrise(), let shaah = graShaahZmanis else { return nil }
        return sunrise.addingTimeInterval(shaah * 6)
    }

    func getMinchaGedolaMGA() -> Date? {
        guard let dawn = getAlosHashachar(90.0),
              let shaah = mgaShaahZmanis(dawnMinutes: 90.0, tzeitMinutes: 90.0)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 6.5)
    }

    func getMinchaGedolaGRA() -> Date? {
        guard let sunrise = getSunrise(), let shaah = graShaahZmanis else { return nil }
        return sunrise.addingTimeInterval(shaah * 6.5)
    }

    func getMinchaKetanaGRA() -> Date? {
        guard let sunrise = getSunrise(), let shaah = graShaahZmanis else { return nil }
        return sunrise.addingTimeInterval(shaah * 9.5)
    }

    func getPlagHaminchaGRA() -> Date? {
        guard let sunrise = getSunrise(), let shaah = graShaahZmanis else { return nil }
        return sunrise.addingTimeInterval(shaah * 10.75)
    }

    func getPlagHaminchaMGA() -> Date? {
        guard let dawn = getAlosHashachar(90.0),
              let shaah = mgaShaahZmanis(dawnMinutes: 90.0, tzeitMinutes: 90.0)
        else { return nil }
        return dawn.addingTimeInterval(shaah * 10.75)
    }

    func getTzais(_ minutesAfterSunset: Double) -> Date? {
        guard let sunset = getSunset() else { return nil }
        return Calendar.current.date(byAdding: .second,
                                     value: Int(minutesAfterSunset * 60),
                                     to: sunset)
    }

    func getTzaisGeonim3Stars18Minutes() -> Date? {
        getTzais(18.0)
    }

    func getTzais72Zmanis() -> Date? {
        guard let shaah = graShaahZmanis, let sunset = getSunset() else { return nil }
        let zmanisMinutes = shaah / 60.0
        let offset = 72.0 * zmanisMinutes
        return sunset.addingTimeInterval(offset * 60)
    }

    func getBaleiTefila() -> Date? {
        getSofZmanTfilaMGA()
    }

    func getChatzosLayla() -> Date? {
        guard let sunset = getSunset() else { return nil }
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: workingDate)
            ?? workingDate.addingTimeInterval(86_400)
        let nextCal = ComplexZmanimCalendar(location: geoLocation)
        nextCal.workingDate = nextDate
        guard let nextSunrise = nextCal.getSunrise() else { return nil }
        let interval = nextSunrise.timeIntervalSince(sunset)
        return sunset.addingTimeInterval(interval / 2)
    }
}
