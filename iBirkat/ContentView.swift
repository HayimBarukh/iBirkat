// Полная актуальная версия ContentView.swift (готовый файл для замены целиком)
import SwiftUI
import UIKit

// ---------------------------------------------------------
// JEWISH DATE HELPER (без сторонних библиотек)
// ---------------------------------------------------------

struct JewishDayInfo {
    let hebrewDate: String      // למשל: י״ד אדר
    let special: String?        // למשל: «פורים»
}

// ---------------------------------------------------------
// ZMANIM MODELS (простая витрина с мнениями)
// ---------------------------------------------------------

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

    init(id: String? = nil, title: String, opinions: [ZmanOpinion], subtitle: String? = nil) {
        self.id = id ?? title
        self.title = title
        self.opinions = opinions
        self.subtitle = subtitle
    }
}

/// Мини-провайдер времён. В реальном приложении эти времена нужно брать из
/// астрономического модуля и точной геолокации. Здесь мы просто строим
/// наглядный список с лёгким смещением по датам, чтобы показать поведение
/// интерфейса и выбор «по какому мнению».
final class ZmanimProvider {
    private let gregorianCalendar = Calendar(identifier: .gregorian)
    private let hebrewCalendar: Calendar = {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = Locale(identifier: "he_IL")
        return cal
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "he_IL")
        return formatter
    }()

    func zmanim(for date: Date) -> [ZmanItem] {
        let offset = minuteOffset(for: date)
        let sunrise = 6 * 60 + offset
        let sunset  = 18 * 60 + offset

        // Базовые времена — просто относительные точки, чтобы интерфейс был живым
        let chatzot = (sunrise + sunset) / 2

        var list: [ZmanItem] = [
            buildItem(title: "עלות השחר", base: sunrise - 90),
            buildItem(title: "משיכיר", base: sunrise - 50),
            buildItem(title: "נץ החמה", base: sunrise),
            buildItem(title: "סוף זמן ק״ש (מגן אברהם)", base: sunrise + 180),
            buildItem(title: "סוף זמן ק״ש (הגר״א)", base: sunrise + 198),
            buildItem(title: "סוף זמן תפילה", base: sunrise + 264),
            buildItem(title: "חצות היום", base: chatzot),
            buildItem(title: "מנחה גדולה", base: chatzot + 30),
            buildItem(title: "מנחה קטנה", base: sunset - 150),
            buildItem(title: "פלג המנחה", base: sunset - 75),
            buildItem(title: "שקיעה", base: sunset),
            buildItem(title: "צאת הכוכבים", base: sunset + 25)
        ]

        if shouldShowCandleLighting(for: date) {
            let candleTime = sunset - 18
            let subtitle = isFriday(date) ? "הדלקת נרות ערב שבת" : "הדלקת נרות ערב חג"
            list.insert(buildItem(title: "הדלקת נרות", base: candleTime, subtitle: subtitle), at: 0)
        }

        return list
    }

    private func buildItem(title: String, base: Int, subtitle: String? = nil) -> ZmanItem {
        let baseId = title
        let opinions = [
            ZmanOpinion(id: "\(baseId)-ovadia", title: "לפי הרב עובדיה", time: timeString(from: base)),
            ZmanOpinion(id: "\(baseId)-hazon", title: "לפי החזון איש", time: timeString(from: base + 3)),
            ZmanOpinion(id: "\(baseId)-gra", title: "לפי הגר״א", time: timeString(from: base - 2))
        ]

        return ZmanItem(id: baseId, title: title, opinions: opinions, subtitle: subtitle)
    }

    private func shouldShowCandleLighting(for date: Date) -> Bool {
        if isFriday(date) { return true }

        let comps = hebrewCalendar.dateComponents([.month, .day], from: date)
        guard let month = comps.month, let day = comps.day else { return false }

        // Условно считаем: ערב חג для Песаха и Суккота
        let erevPesach = (month == 8 && day == 14)
        let erevSukkot = (month == 1 && day == 14)
        return erevPesach || erevSukkot
    }

    private func isFriday(_ date: Date) -> Bool {
        let weekday = gregorianCalendar.component(.weekday, from: date)
        return weekday == 6 // 1-вс, 6-пт
    }

    private func minuteOffset(for date: Date) -> Int {
        let ord = gregorianCalendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return (ord % 8) - 4
    }

    private func timeString(from minutes: Int) -> String {
        let total = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        let h = total / 60
        let m = total % 60
        let components = DateComponents(calendar: gregorianCalendar, hour: h, minute: m)

        guard let date = components.date else { return "--:--" }
        return timeFormatter.string(from: date)
    }
}

/// Помощник по еврейской дате на базе системного календаря .hebrew.
/// Учитываем, что еврейский день начинается вечером: делаем сдвиг +6 часов.
final class HebrewDateHelper {
    static let shared = HebrewDateHelper()

    private let monthFormatter: DateFormatter
    private let hebrewCalendar: Calendar
    private let eveningShiftHours: Double = 6

    private init() {
        var cal = Calendar(identifier: .hebrew)
        cal.locale = Locale(identifier: "he_IL")
        self.hebrewCalendar = cal

        let mf = DateFormatter()
        mf.calendar = cal
        mf.locale = Locale(identifier: "he_IL")
        mf.dateFormat = "MMMM"      // только название месяца
        self.monthFormatter = mf
    }

    /// Текущая дата + сдвиг на вечер (новый еврейский день после выхода звёзд)
    func currentInfo() -> JewishDayInfo {
        let now = Date()
        let shifted = now.addingTimeInterval(eveningShiftHours * 3600)
        return info(for: shifted)
    }

    /// Информация по ПРОИЗВОЛЬНОЙ дате (Date) с учётом вечернего сдвига.
    func info(for date: Date) -> JewishDayInfo {
        let shiftedDate = date.addingTimeInterval(eveningShiftHours * 3600)

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
    private let gregorianFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .full
        return df
    }()

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
        HebrewDateHelper.shared.currentInfo()
    }

    private var currentZmanim: [ZmanItem] {
        zmanimProvider.zmanim(for: zmanimDate)
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
                    HebrewDateHelper.shared.info(for: date)
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
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)

                                if let subtitle = item.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(selectedOpinions[item.id]?.title ?? "בחר דעה")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(selectedOpinions[item.id]?.time ?? item.defaultOpinion.time)
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
                    Button(opinion.title) {
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
