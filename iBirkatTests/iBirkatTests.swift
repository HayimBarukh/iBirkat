//
//  iBirkatTests.swift
//  iBirkatTests
//
//  Created by חיים ברוך ליברמן on 15/11/2025.
//

import Foundation
import Testing
@testable import iBirkat

struct iBirkatTests {

    private let hebrewCalendar: Calendar = {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return calendar
    }()

    private let zmanimProvider = ZmanimProvider()

    @Test("Особые дни по еврейскому календарю", arguments: [
        (year: 5784, month: 1, day: 1, expected: "ראש חודש"),
        (year: 5784, month: 7, day: 14, expected: "פורים"),
        (year: 5784, month: 8, day: 18, expected: "חול המועד פסח")
    ])
    func jewishCalendarTags(_ sample: (year: Int, month: Int, day: Int, expected: String)) throws {
        let date = hebrewDate(year: sample.year, month: sample.month, day: sample.day)
        let info = HebrewDateHelper.shared.info(for: date)

        #expect(info.special?.contains(sample.expected) == true)
    }

    @Test func candleLightingShownOnlyWhenExpected() throws {
        let friday = gregorianDate(year: 2024, month: 6, day: 7)
        let monday = gregorianDate(year: 2024, month: 6, day: 10)

        let fridayTitles = zmanimProvider.zmanim(for: friday).map { $0.title }
        let mondayTitles = zmanimProvider.zmanim(for: monday).map { $0.title }

        #expect(fridayTitles.first == "הדלקת נרות")
        #expect(mondayTitles.contains("הדלקת נרות") == false)
    }

    // MARK: - Helpers

    private func hebrewDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.calendar = hebrewCalendar
        components.timeZone = hebrewCalendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour

        return hebrewCalendar.date(from: components)!
    }

    private func gregorianDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour

        return calendar.date(from: components)!
    }
}
