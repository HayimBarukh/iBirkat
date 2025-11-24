import SwiftUI
import KosherSwift

/// Экран «Змани היום»
struct ZmanimView: View {

    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    // Дата, для которой считаем зманим
    @State private var date: Date = Date()

    // Выбор мнений для конкретных зманим (в памяти экрана)
    @State private var selectedOpinions: [String: ZmanOpinion] = [:]
    @State private var activeZmanItem: ZmanItem?
    @State private var showingCandleOffsetDialog = false

    // Профиль по общине
    @AppStorage("halachicProfile")
    private var halachicProfileRaw: String = HalachicProfile.sephardi.rawValue

    // Смещение зажигания свечей до заката (в минутах)
    @AppStorage("candleLightingOffset")
    private var candleLightingOffset: Int = 18

    // Карта кастомных мнений: itemID -> opinionID (в JSON)
    @AppStorage("customOpinionMap")
    private var customOpinionMapRaw: String = ""

    // Текущий профиль как enum
    private var halachicProfile: HalachicProfile {
        HalachicProfile(rawValue: halachicProfileRaw) ?? .sephardi
    }

    // GEO: либо из CoreLocation, либо запасной — ירושלים
    private var geoLocation: GeoLocation {
        if let g = locationManager.geoLocation {
            return g
        }
        let tz = TimeZone(identifier: "Asia/Jerusalem") ?? .current
        return GeoLocation(
            locationName: "ירושלים",
            latitude: 31.778,
            longitude: 35.235,
            timeZone: tz
        )
    }

    // Провайдер зманим
    private var provider: ZmanimProvider {
        ZmanimProvider(geoLocation: geoLocation)
    }

    // Список зманим для текущей даты и профиля
    private var currentZmanim: [ZmanItem] {
        provider.zmanim(for: date, profile: halachicProfile)
    }

    // Еврейская дата (с учётом смены дня вечером)
    private var hebrewInfo: JewishDayInfo {
        HebrewDateHelper.shared.info(for: date)
    }

    // Форматтер времени
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.timeZone = geoLocation.timeZone
        df.dateFormat = "HH:mm"
        return df
    }

    // Форматтер григорианской даты (на иврите)
    private var gregorianFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.timeZone = geoLocation.timeZone
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }

    private var gregorianText: String {
        gregorianFormatter.string(from: date)
    }

    private var cityName: String {
        geoLocation.locationName ?? "מקום נוכחי"
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerArea

                    if let special = specialTimesInfo {
                        specialTimesArea(special)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }

                    separator
                        .padding(.horizontal, 16)

                    zmanimList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .environment(\.layoutDirection, .rightToLeft)
                .onAppear {
                    syncSelectedOpinionsWithProfile()
                }
                .onChange(of: halachicProfileRaw) { _ in
                    syncSelectedOpinionsWithProfile()
                }
                .onChange(of: date) { _ in
                    if halachicProfile == .custom {
                        applyCustomMap()
                    } else {
                        selectedOpinions = [:]
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        separator
                            .padding(.horizontal, 16)

                        bottomNavigationRow
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            // Минимальный зазор без удвоения safe-area и без лишнего пустого места
                            .padding(.bottom, bottomInset > 0 ? max(bottomInset - 10, 8) : 6)
                    }
                    .background(
                        Color(.systemBackground)
                            .opacity(0.98)
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            backFloatingButton
                .padding(.horizontal, 12)
                .padding(.top, 4)
        }
    }

    // MARK: - Floating back button

    private var backFloatingButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 15, weight: .medium))
                .padding(8)
                .background(
                    Circle().fill(Color.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.15),
                                radius: 8, x: 0, y: 3)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: 4) {
            Text("זמני היום · \(cityName)")
                .font(.headline)

            Text(hebrewInfo.hebrewDate)
                .font(.subheadline)

            Text(gregorianText)
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                profileChip(.custom)
                profileChip(.sephardi)
                profileChip(.ashkenazi)
                profileChip(.chabad)
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }

    /// Кнопка профиля (ע״מ / א / ח / מותאם)
    private func profileChip(_ profile: HalachicProfile) -> some View {
        let isSelected = (profile == halachicProfile)

        let shortLabel: String
        let fullLabel: String
        let showStar: Bool

        switch profile {
        case .sephardi:
            shortLabel = "ע״מ"
            fullLabel  = "עדות המזרח / ר׳ עובדיה"
            showStar   = false
        case .ashkenazi:
            shortLabel = "א"
            fullLabel  = "אשכנז"
            showStar   = false
        case .chabad:
            shortLabel = "ח"
            fullLabel  = "חב״ד"
            showStar   = false
        case .custom:
            shortLabel = "מותאם"
            fullLabel  = "מותאם אישית"
            showStar   = true
        }

        let label = HStack(spacing: 4) {
            Text(isSelected ? fullLabel : shortLabel)
                .font(.footnote.weight(isSelected ? .semibold : .regular))
            if showStar {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
            }
        }
        .lineLimit(1)
        .padding(.horizontal, isSelected ? 14 : 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.blue.opacity(0.18)
                                 : Color.gray.opacity(0.12))
        )
        .foregroundColor(isSelected ? .blue : .primary)

        return Button {
            // обычный тап — просто выбрать профиль
            halachicProfileRaw = profile.rawValue
            lightHaptic()
        } label: {
            label
        }
        .buttonStyle(.plain)
        // ДЛИННОЕ НАЖАТИЕ НА КАСТОМ — СБРОС К СЕФАРАДИМ
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.7).onEnded { _ in
                guard profile == .custom else { return }
                resetCustomProfileToSephardiDefaults()
            }
        )
    }

    // MARK: - Separator

    private var separator: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.16))
            .frame(height: 1)
    }

    // MARK: - List

    private var zmanimList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(currentZmanim) { item in
                    if item.opinions.count <= 1 {
                        nonInteractiveCard(for: item)
                    } else {
                        interactiveZmanButton(for: item)
                    }
                }
            }
        }
    }

    // MARK: - Special times (candle lighting / motzaei)

    private struct SpecialTimesInfo {
        enum Kind {
            case shabbat
            case yomTov

            var title: String {
                switch self {
                case .shabbat: return "ערב שבת"
                case .yomTov:  return "ערב חג"
                }
            }
        }

        let kind: Kind
        let candleLighting: String
        let endTime: String
    }

    private var specialTimesInfo: SpecialTimesInfo? {
        guard let kind = specialDayKind else { return nil }

        let lighting = provider.candleLighting(
            for: date,
            minutesBeforeSunset: candleLightingOffset
        )

        // Выход праздника/Шаббата считаем по следующему календарному дню
        var motzaeiCalendar = Calendar.current
        motzaeiCalendar.timeZone = geoLocation.timeZone
        let motzaeiDate = motzaeiCalendar.date(byAdding: .day, value: 1, to: date)
        let motzaei = provider.motzaeiShabbatOrYomTov(
            for: motzaeiDate ?? date,
            offsetMinutes: 40
        )

        return SpecialTimesInfo(
            kind: kind,
            candleLighting: timeString(lighting),
            endTime: timeString(motzaei)
        )
    }

    /// Определение, является ли дата вечером Шаббата или праздника (Э״י)
    private var specialDayKind: SpecialTimesInfo.Kind? {
        // Пятница — всегда ערב שבת
        var gregorian = Calendar.current
        gregorian.timeZone = geoLocation.timeZone
        let weekday = gregorian.component(.weekday, from: date)
        if weekday == 6 { return .shabbat }

        // Проверяем, не вечер ли Йом Тов
        var hebCal = Calendar(identifier: .hebrew)
        hebCal.timeZone = geoLocation.timeZone

        guard
            let tomorrow = hebCal.date(byAdding: .day, value: 1, to: date)
        else { return nil }

        let comps = hebCal.dateComponents([.month, .day], from: tomorrow)
        guard let month = comps.month, let day = comps.day else {
            return nil
        }

        let leap = (hebCal.range(of: .month, in: .year, for: tomorrow)?.count ?? 12) == 13
        if isYomTov(month: month, day: day, isLeapYear: leap) {
            return .yomTov
        }

        return nil
    }

    /// Список праздничных дней в Э״י (для определения «эрев חג»)
    private func isYomTov(month: Int, day: Int, isLeapYear: Bool) -> Bool {
        _ = isLeapYear // параметр оставлен для будущего учёта диаспоры/לוח שנה

        // Нумерация месяцев календаря .hebrew: תשרי=1 … אלול=13
        switch (month, day) {
        case (1, 1), (1, 2): // Рош ѓаШана
            return true
        case (1, 10): // Йом Кипур
            return true
        case (1, 15), (1, 22): // Суккот, Шмини Ацерет/Симхат Тора
            return true
        case (8, 15), (8, 21): // 1-й и 7-й дни Песаха
            return true
        case (10, 6): // Шавуот
            return true
        default:
            // Високосный Адар: порядок месяцев отличается, но на йом-товы не влияет
            return false
        }
    }

    private func specialTimesArea(_ info: SpecialTimesInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(info.kind.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    lightHaptic()
                    activeZmanItem = nil
                    showingCandleOffsetDialog = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(candleLightingOffset) דק׳ לפני שקיעה")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .confirmationDialog("בחרי זמן הדלקה", isPresented: $showingCandleOffsetDialog, titleVisibility: .visible) {
                    ForEach(candleLightingOffsets, id: \.self) { value in
                        Button("\(value) דקות לפני שקיעה") {
                            candleLightingOffset = value
                            lightHaptic()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                specialRow(title: "הדלקת נרות", time: info.candleLighting)
                specialRow(title: "צאת שבת / חג", time: info.endTime)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    private var candleLightingOffsets: [Int] { [18, 24, 30, 40] }

    private func specialRow(title: String, time: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(time)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func timeString(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        return timeFormatter.string(from: d)
    }

    private func interactiveZmanButton(for item: ZmanItem) -> some View {
        let isPopoverShown = Binding<Bool>(
            get: { activeZmanItem?.id == item.id },
            set: { newValue in
                if !newValue {
                    activeZmanItem = nil
                }
            }
        )

        return Button {
            activeZmanItem = item
        } label: {
            interactiveCard(for: item)
        }
        .buttonStyle(.plain)
        .zmanPopover(isPresented: isPopoverShown) {
            opinionPicker(for: item)
        }
    }

    private func opinionPicker(for item: ZmanItem) -> some View {
        let selectedOpinion = selectedOpinions[item.id] ?? item.defaultOpinion

        return VStack(alignment: .trailing, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("בחר דעה עבור הזמן")
                    .font(.headline)
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            ForEach(item.opinions) { opinion in
                Button {
                    pickOpinion(item, opinion)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(opinion.title)
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.trailing)

                            Text(opinion.time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Image(systemName: selectedOpinion.id == opinion.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedOpinion.id == opinion.id ? Color.accentColor : Color.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedOpinion.id == opinion.id ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                activeZmanItem = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("ביטול")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .foregroundColor(.secondary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private func nonInteractiveCard(for item: ZmanItem) -> some View {
        let opinion = item.opinions.first!

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(opinion.time)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    private func interactiveCard(for item: ZmanItem) -> some View {
        let selected = selectedOpinions[item.id] ?? item.defaultOpinion

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(selected.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            Spacer()

            Text(selected.time)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    // MARK: - Bottom navigation

    private var bottomNavigationRow: some View {
        HStack(spacing: 16) {
            Button {
                shiftDate(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .padding(8)
                    .background(Circle().fill(Color.gray.opacity(0.12)))
            }

            Button("היום") {
                date = Date()
                lightHaptic()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.gray.opacity(0.12)))
            .buttonStyle(.plain)

            Button {
                shiftDate(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .padding(8)
                    .background(Circle().fill(Color.gray.opacity(0.12)))
            }
        }
        .buttonStyle(.plain)
    }

    private func shiftDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: date) {
            date = newDate
            lightHaptic()
        }
    }

    // MARK: - Кастомный профиль / сохранение мнений

    private func syncSelectedOpinionsWithProfile() {
        if halachicProfile == .custom {
            applyCustomMap()
        } else {
            selectedOpinions = [:]
        }
    }

    private func applyCustomMap() {
        let map = loadCustomOpinionIDs()
        var dict: [String: ZmanOpinion] = [:]

        for item in currentZmanim {
            if let opID = map[item.id],
               let op = item.opinions.first(where: { $0.id == opID }) {
                dict[item.id] = op
            }
        }
        selectedOpinions = dict
    }

    /// Сброс кастомного профиля к значениям по умолчанию (сефарадим)
    /// — удаляем карту мнений и локальный выбор; при профиле `.custom`
    /// это значит: брать `defaultOpinion`, который настроен как Сефарадим.
    private func resetCustomProfileToSephardiDefaults() {
        guard halachicProfile == .custom else { return }
        customOpinionMapRaw = ""      // стираем сохранённые выборы
        selectedOpinions = [:]        // локально тоже очищаем
        lightHaptic()
    }

    private func loadCustomOpinionIDs() -> [String: String] {
        guard !customOpinionMapRaw.isEmpty,
              let data = customOpinionMapRaw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveCustomOpinionIDs(_ dict: [String: String]) {
        if let data = try? JSONEncoder().encode(dict),
           let str = String(data: data, encoding: .utf8) {
            customOpinionMapRaw = str
        }
    }

    private func pickOpinion(_ item: ZmanItem, _ opinion: ZmanOpinion) {
        selectedOpinions[item.id] = opinion

        if halachicProfile == .custom {
            var map = loadCustomOpinionIDs()
            map[item.id] = opinion.id
            saveCustomOpinionIDs(map)
        }

        lightHaptic()
        activeZmanItem = nil
    }

    // MARK: - Haptics

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

private extension View {
    @ViewBuilder
    func zmanPopover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if #available(iOS 17.0, *) {
            popover(
                isPresented: isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top,
                content: content
            )
            .presentationCompactAdaptation(.popover)
        } else {
            popover(
                isPresented: isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top,
                content: content
            )
        }
    }
}
