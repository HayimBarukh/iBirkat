import SwiftUI
import UIKit

// ---------------------------------------------------------
// JEWISH DATE HELPER (без сторонних библиотек)
// ---------------------------------------------------------

struct JewishDayInfo {
    let hebrewDate: String      // למשל: י״ד אדר
    let special: String?        // למשל: "פורים"
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

        // Пурим — 14 адар (для простоты считаем месяц 7)
        if month == 7 && day == 14 {
            tags.append("פורים")
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

    // только «пустая» кнопка Зманим — показывает алерт
    @State private var showZmanimStubAlert: Bool = false

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
        .alert("זמני היום יהיו כאן",
               isPresented: $showZmanimStubAlert) {
            Button("סגור", role: .cancel) {}
        } message: {
            Text("המסך עדיין בפיתוח")
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
            showZmanimStubAlert = true
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

#Preview {
    ContentView()
        .environment(\.layoutDirection, .rightToLeft)
}
