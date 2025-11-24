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
            }
            .zmanPopover(
                isPresented: Binding(
                    get: { activeZmanItem != nil },
                    set: { newValue in if !newValue { activeZmanItem = nil } }
                ),
                arrowEdge: popoverArrowEdge
            ) {
                if let item = activeZmanItem {
                    ZStack {
                        popoverContent(for: item)
                    }
                    .frame(
                        maxWidth: isPhone ? 280 : 360,
                        maxHeight: isPhone ? 380 : 420
                    )
                    .padding(isPhone ? 14 : 18)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 8)
                }
            }
            .confirmationDialog(
                "הדלקת נרות - קיזוז דקות",
                isPresented: $showingCandleOffsetDialog,
                titleVisibility: .visible
            ) {
                Button("18 דקות לפני השקיעה") {
                    candleLightingOffset = 18
                }
                Button("40 דקות לפני השקיעה") {
                    candleLightingOffset = 40
                }
                Button("ביטול", role: .cancel) { }
            }
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: 14) {
            topControls
            dateInfoCard
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            profileSelector

            Spacer(minLength: 0)

            cityButton
        }
        .frame(maxWidth: .infinity)
    }

    private var profileSelector: some View {
        HStack(spacing: isPhone ? 6 : 10) {
            ForEach(isPhone ? HalachicProfile.basicCases : HalachicProfile.allCases) { profile in
                Button(action: {
                    halachicProfileRaw = profile.rawValue
                    syncSelectedOpinionsWithProfile()
                }) {
                    Group {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Text(profile.tabletLabel)
                                .font(.headline)
                                .frame(minWidth: 90)
                        } else {
                            Text(profile.shortSymbol)
                                .font(.subheadline)
                                .frame(width: 48)
                        }
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, isPhone ? 8 : 12)
                    .background(
                        Capsule()
                            .fill(halachicProfile == profile ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if profile == .custom {
                        Button(role: .destructive) {
                            resetCustomProfileToSephardiDefaults()
                        } label: {
                            Label("איפוס ברירת מחדל (לחיצה ארוכה)", systemImage: "arrow.uturn.left")
                        }
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            if profile == .custom {
                                resetCustomProfileToSephardiDefaults()
                            }
                        }
                )
                .opacity(profile == .custom && halachicProfile != .custom ? 0.65 : 1.0)
            }
        }
    }

    private var cityButton: some View {
        Button(action: {
            locationManager.requestLocation()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                Text(cityName)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date info card

    private var dateInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hebrewInfo.hebrewDate)
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(hebrewInfo.parashaOrEvent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(gregorianText)
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                    Text(hebrewInfo.hebrewMonthAndYear)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("יום בשבוע")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(hebrewInfo.weekdayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Spacer(minLength: 0)

                    Button(action: resetDateToToday) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("תאריך לועזי")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(gregorianText)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let candle = provider.candleLighting(for: date, minutesBeforeSunset: candleLightingOffset) {
                    Divider()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("הדלקת נרות")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(timeFormatter.string(from: candle))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer(minLength: 0)

                        Button(action: { showingCandleOffsetDialog = true }) {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Special times area

    private var specialTimesInfo: (title: String, values: [String])? {
        var values: [String] = []
        if let dawn = provider.zmanim(for: date, profile: halachicProfile).first?.opinions.first?.time {
            values.append("עלות: \(dawn)")
        }
        if let sunset = provider.zmanim(for: date, profile: halachicProfile).first(where: { $0.id == "shekiya" })?.opinions.first?.time {
            values.append("שקיעה: \(sunset)")
        }
        guard !values.isEmpty else { return nil }
        return (title: "זמנים מרכזיים", values: values)
    }

    private func specialTimesArea(_ info: (title: String, values: [String])) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(info.title)
                .font(.headline)
            ForEach(info.values, id: \.self) { value in
                Text(value)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - List of zmanim

    private var zmanimList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(halachicZmanSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(section.zmanim) { zman in
                                if let item = currentZmanim.first(where: { $0.title == zman.name }) {
                                    zmanRow(for: item)
                                } else {
                                    zmanRow(for: ZmanItem(title: zman.name, opinions: []))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Row

    private func zmanRow(for item: ZmanItem) -> some View {
        let opinion = selectedOpinions[item.id] ?? item.defaultOpinion

        return Button {
            activeZmanItem = item
            popoverArrowEdge = .trailing
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(opinion.title)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                        Text(opinion.time)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    // MARK: - Popover content

    private func popoverContent(for item: ZmanItem) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(item.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(item.opinions) { opinion in
                    Button {
                        pickOpinion(item, opinion)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(opinion.title)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                Text(opinion.time)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: { activeZmanItem = nil }) {
                Text("סגירה")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
        .padding(.top, 6)
    }

    // MARK: - Separators

    private var separator: some View {
        Rectangle()
            .fill(Color(.quaternaryLabel))
            .frame(height: 1)
    }

    // MARK: - Date controls

    private var dateControls: some View {
        HStack(spacing: 10) {
            Button(action: { shiftDate(by: -1) }) {
                Image(systemName: "chevron.right")
            }

            Spacer(minLength: 0)

            datePicker

            Spacer(minLength: 0)

            Button(action: { shiftDate(by: 1) }) {
                Image(systemName: "chevron.left")
            }
        }
        .padding(.vertical, isPhone ? 6 : 10)
        .padding(.horizontal, isPhone ? 6 : 12)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var datePicker: some View {
        DatePicker(
            "",
            selection: $date,
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .environment(\.layoutDirection, .rightToLeft)
        .scaleEffect(isPhone ? 0.9 : 1.0)
    }

    // MARK: - Special footer for phone

    private var phoneFooter: some View {
        VStack(spacing: 6) {
            separator
                .padding(.horizontal, 16)

            dateControls
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .padding(.bottom, 6)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Helpers для выделения секций

    private func sectionBackground(_ color: Color = Color(.secondarySystemBackground)) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color)
    }

    private func highlightBackground() -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.yellow.opacity(0.15))
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
