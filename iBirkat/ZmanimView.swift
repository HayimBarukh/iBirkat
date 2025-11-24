import SwiftUI
import KosherSwift

/// Экран «Змани היום»
struct ZmanimView: View {

    @EnvironmentObject var locationManager: LocationManager

    // Дата, для которой считаем зманим
    @State private var date: Date = Date()

    // Выбор мнений для конкретных зманим (в памяти экрана)
    @State private var selectedOpinions: [String: ZmanOpinion] = [:]
    @State private var activeZmanItem: ZmanItem?
    @State private var popoverArrowEdge: Edge = .top
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

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { _ in
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
                    syncSelectedOpinionsWithProfile()
                }
            }
            .overlay(alignment: .center) {
                phoneOpinionOverlay
            }
            .safeAreaInset(edge: .bottom) {
                if isPhone {
                    bottomDateSelector
                }
            }
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(cityName)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.trailing)

                    Text(gregorianText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)

                    Text(hebrewInfo.formattedDate)
                        .font(.headline)
                }

                Spacer(minLength: 10)

               VStack(alignment: .trailing, spacing: 10) {
                    profilePicker
                    if !isPhone {
                        dateSelector
                    }
                }
            }

            separator
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 1 / UIScreen.main.scale)
    }

    // MARK: - Profile picker

    private var profilePicker: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Picker("", selection: $halachicProfileRaw) {
                ForEach(HalachicProfile.basicCases, id: \.rawValue) { profile in
                    profileLabel(for: profile)
                        .tag(profile.rawValue)
                        .accessibilityLabel(Text(profile.title))
                }

                profileLabel(for: .custom)
                    .tag(HalachicProfile.custom.rawValue)
                    .accessibilityLabel(Text(HalachicProfile.custom.title))
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private func profileLabel(for profile: HalachicProfile) -> some View {
        let text = isPhone ? profile.shortSymbol : profile.tabletLabel

        if profile == .custom {
            Text(text)
                .onLongPressGesture(minimumDuration: 1.0) {
                    resetCustomProfileToSephardiDefaults()
                }
        } else {
            Text(text)
        }
    }

    // MARK: - Date selector

    private var dateSelector: some View {
        HStack(spacing: 12) {
            Button {
                shiftDate(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(spacing: 4) {
                Text(hebrewInfo.dayOfWeek)
                    .font(.headline)
                Text(hebrewInfo.hebrewDateText)
                    .font(.subheadline)
            }
            .frame(width: 160)
            .contentShape(Rectangle())
            .onTapGesture {
                resetDateToToday()
            }

            Button {
                shiftDate(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private var compactDateSelector: some View {
        HStack(spacing: 10) {
            Button {
                shiftDate(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(spacing: 2) {
                Text(hebrewInfo.dayOfWeek)
                    .font(.subheadline.weight(.semibold))
                Text(hebrewInfo.hebrewDateText)
                    .font(.caption)
            }
            .frame(width: 150)
            .contentShape(Rectangle())
            .onTapGesture {
                resetDateToToday()
            }

            Button {
                shiftDate(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private var bottomDateSelector: some View {
        compactDateSelector
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -2)
    }

    // MARK: - Zmanim list

    private var zmanimList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    Color.clear
                        .frame(height: 0.01)
                        .id("top")

                    specialBannerIfNeeded
                        .padding(.top, 6)

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

    @ViewBuilder
    private var phoneOpinionOverlay: some View {
        if isPhone, let item = activeZmanItem {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        activeZmanItem = nil
                    }

                opinionPicker(for: item)
                    .frame(maxWidth: 320)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 18, x: 0, y: 8)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: activeZmanItem?.id)
        }
    }

    @ViewBuilder
    private func interactiveZmanButton(for item: ZmanItem) -> some View {
        let isPopoverShown = Binding<Bool>(
            get: { activeZmanItem?.id == item.id },
            set: { newValue in
                if !newValue {
                    activeZmanItem = nil
                }
            }
        )

        let button = Button {
            activeZmanItem = item
        } label: {
            interactiveCard(for: item)
        }
        .buttonStyle(.plain)

        if isPhone {
            button
        } else {
            button
                .zmanPopover(isPresented: isPopoverShown, arrowEdge: popoverArrowEdge) {
                    opinionPicker(for: item)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: activeZmanItem?.id == item.id) { isActive in
                                guard isActive else { return }

                                let frame = geo.frame(in: .global)
                                let screenHeight = UIScreen.main.bounds.height
                                let spaceAbove = frame.minY
                                let spaceBelow = screenHeight - frame.maxY

                                popoverArrowEdge = spaceBelow < spaceAbove ? .bottom : .top
                            }
                    }
                )
        }
    }

    private func opinionPicker(for item: ZmanItem) -> some View {
        let selectedOpinion = selectedOpinions[item.id] ?? item.defaultOpinion
        let maxHeight = UIScreen.main.bounds.height * 0.45

        return ScrollView {
            VStack(alignment: .trailing, spacing: 12) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("בחר דעה עבור הזמן")
                        .font(.headline)
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
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
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(opinion.time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)

                            Image(systemName: selectedOpinion.id == opinion.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedOpinion.id == opinion.id ? Color.accentColor : Color.secondary)
                                .imageScale(.large)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(selectedOpinion.id == opinion.id ? 0.08 : 0.03))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .cancel) {
                    activeZmanItem = nil
                } label: {
                    Text("ביטול")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(maxHeight: maxHeight)
        .scrollIndicators(.hidden)
    }

    private func interactiveCard(for item: ZmanItem) -> some View {
        let selected = selectedOpinions[item.id] ?? item.defaultOpinion

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(selected.time)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()

                Text(selected.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func nonInteractiveCard(for item: ZmanItem) -> some View {
        let opinion = item.opinions.first ?? item.defaultOpinion

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(opinion.time)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()

                Text(opinion.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var specialBannerIfNeeded: some View {
        Group {
            if hebrewInfo.isErevShabbat {
                specialBanner(text: "שבת שלום!", icon: "sparkles")
            } else if hebrewInfo.isErevChag {
                specialBanner(text: "חג שמח!", icon: "sparkles")
            } else if hebrewInfo.isShabbat {
                specialBanner(text: "שבת היום", icon: "sun.max.fill")
            } else {
                EmptyView()
            }
        }
    }

    private func specialBanner(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
            Text(text)
                .font(.headline)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.15))
        )
    }

    // MARK: - Date helpers

    private func shiftDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: date) {
            date = newDate
            lightHaptic()
        }
    }

    private func resetDateToToday() {
        date = Date()
        lightHaptic()
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

private struct ZmanPopoverModifier<PopoverContent: View>: ViewModifier {
    let isPresented: Binding<Bool>
    let arrowEdge: Edge
    let popoverContent: () -> PopoverContent

    @ViewBuilder
    func body(content trigger: Content) -> some View {
        trigger.popover(
            isPresented: isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: arrowEdge,
            content: popoverContent
        )
        .modifier(PresentationPopoverFallback())
    }
}

private struct PresentationPopoverFallback: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func zmanPopover<Content: View>(
        isPresented: Binding<Bool>,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(ZmanPopoverModifier(isPresented: isPresented, arrowEdge: arrowEdge, popoverContent: content))
    }
}
