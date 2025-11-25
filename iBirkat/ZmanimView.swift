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

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

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

    private var provider: ZmanimProvider {
        ZmanimProvider(geoLocation: geoLocation)
    }

    private var currentZmanim: [ZmanItem] {
        provider.zmanim(for: date, profile: halachicProfile)
    }

    private var hebrewInfo: JewishDayInfo {
        HebrewDateHelper.shared.info(for: date)
    }

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.timeZone = geoLocation.timeZone
        df.dateFormat = "HH:mm"
        return df
    }

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
                Color(.systemGroupedBackground) // Чуть серый фон для контраста карточек
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerArea
                        .background(Color(.systemBackground))
                        .padding(.bottom, 10)

                    ScrollView {
                        VStack(spacing: 0) {
                            if let special = specialTimesInfo {
                                specialTimesArea(special)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                            }

                            zmanimList
                                .padding(.horizontal, 16)
                                .padding(.bottom, 100) // Отступ под нижнюю панель
                        }
                        .padding(.top, 4)
                    }
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
                
                // Нижняя панель навигации
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Divider()
                        bottomNavigationRow
                            .padding(.top, 8)
                            .padding(.bottom, bottomInset > 0 ? bottomInset : 12)
                    }
                    .background(Material.bar) // Полупрозрачный фон
                }
                .ignoresSafeArea(.container, edges: .bottom)
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
                .font(.system(size: 16, weight: .semibold))
                .padding(10)
                .background(
                    Circle().fill(Color(.systemBackground).opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: 6) {
            Text("זמני היום · \(cityName)")
                .font(isPhone ? .headline : .title3)
                .padding(.top, 10)

            VStack(spacing: 2) {
                Text(hebrewInfo.hebrewDate)
                    .font(isPhone ? .subheadline.weight(.medium) : .headline)
                
                Text(gregorianText)
                    .font(isPhone ? .footnote : .subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                profileChip(.custom)
                profileChip(.sephardi)
                profileChip(.ashkenazi)
                profileChip(.chabad)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 3)
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
            fullLabel  = "עדות המזרח"
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
                    .font(.system(size: 10))
            }
        }
        .lineLimit(1)
        .padding(.horizontal, isSelected ? 14 : 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemFill))
        )
        .foregroundColor(isSelected ? .blue : .primary)

        return Button {
            halachicProfileRaw = profile.rawValue
            lightHaptic()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.7).onEnded { _ in
                guard profile == .custom else { return }
                resetCustomProfileToSephardiDefaults()
            }
        )
    }

    // MARK: - List

    private var zmanimList: some View {
        LazyVStack(spacing: 8) {
            ForEach(currentZmanim) { item in
                if item.opinions.count <= 1 {
                    nonInteractiveCard(for: item)
                } else {
                    interactiveZmanButton(for: item)
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
        let lighting = provider.candleLighting(for: date, minutesBeforeSunset: candleLightingOffset)
        
        var motzaeiCalendar = Calendar.current
        motzaeiCalendar.timeZone = geoLocation.timeZone
        let motzaeiDate = motzaeiCalendar.date(byAdding: .day, value: 1, to: date)
        let motzaei = provider.motzaeiShabbatOrYomTov(for: motzaeiDate ?? date, offsetMinutes: 40)

        return SpecialTimesInfo(
            kind: kind,
            candleLighting: timeString(lighting),
            endTime: timeString(motzaei)
        )
    }

    private var specialDayKind: SpecialTimesInfo.Kind? {
        var gregorian = Calendar.current
        gregorian.timeZone = geoLocation.timeZone
        let weekday = gregorian.component(.weekday, from: date)
        if weekday == 6 { return .shabbat } // Пятница

        // Проверка на Йом Тов (упрощенная)
        var hebCal = Calendar(identifier: .hebrew)
        hebCal.timeZone = geoLocation.timeZone
        guard let tomorrow = hebCal.date(byAdding: .day, value: 1, to: date) else { return nil }
        let comps = hebCal.dateComponents([.month, .day], from: tomorrow)
        guard let month = comps.month, let day = comps.day else { return nil }
        
        // Рош ѓаШана, Йом Кипур, Суккот, Песах, Шавуот
        let isLeap = (hebCal.range(of: .month, in: .year, for: tomorrow)?.count ?? 12) == 13
        if isYomTov(month: month, day: day, isLeapYear: isLeap) { return .yomTov }

        return nil
    }
    
    private func isYomTov(month: Int, day: Int, isLeapYear: Bool) -> Bool {
        switch (month, day) {
        case (1, 1), (1, 2), (1, 10), (1, 15), (1, 22), (8, 15), (8, 21), (10, 6): return true
        default: return false
        }
    }

    private func specialTimesArea(_ info: SpecialTimesInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(info.kind.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.blue)

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
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .confirmationDialog("בחרי זמן הדלקה", isPresented: $showingCandleOffsetDialog, titleVisibility: .visible) {
                    ForEach([18, 24, 30, 40], id: \.self) { value in
                        Button("\(value) דקות") {
                            candleLightingOffset = value
                            lightHaptic()
                        }
                    }
                }
            }

            VStack(spacing: 6) {
                specialRow(title: "הדלקת נרות", time: info.candleLighting)
                Divider().opacity(0.5)
                specialRow(title: "צאת שבת / חג", time: info.endTime)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    private func specialRow(title: String, time: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(time)
                .font(.title3.weight(.medium))
                .monospacedDigit()
        }
    }

    private func timeString(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        return timeFormatter.string(from: d)
    }

    // MARK: - Cards

    private func interactiveZmanButton(for item: ZmanItem) -> some View {
        let isSheetShown = Binding<Bool>(
            get: { activeZmanItem?.id == item.id },
            set: { if !$0 { activeZmanItem = nil } }
        )

        return Button {
            activeZmanItem = item
        } label: {
            interactiveCard(for: item)
        }
        .buttonStyle(.plain)
        .zmanSheet(isPresented: isSheetShown) {
            opinionPicker(for: item)
        }
    }

    private func opinionPicker(for item: ZmanItem) -> some View {
        let selectedOpinion = selectedOpinions[item.id] ?? item.defaultOpinion

        return ZStack {
            // Фон шторки — серый, как основной экран
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Хедер
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)

                    Text("בחר דעה עבור \(item.title)")
                        .font(.headline)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(item.opinions) { opinion in
                            let isSelected = (selectedOpinion.id == opinion.id)
                            
                            Button {
                                pickOpinion(item, opinion)
                            } label: {
                                HStack(alignment: .center, spacing: 14) {
                                    // Радио-кнопка
                                    Circle()
                                        .strokeBorder(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                        .background(Circle().fill(isSelected ? Color.blue : Color.clear))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 8, height: 8)
                                                .opacity(isSelected ? 1 : 0)
                                        )

                                    // Текст мнения
                                    Text(opinion.title)
                                        .font(.body.weight(isSelected ? .semibold : .regular))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()

                                    // Время
                                    Text(opinion.time)
                                        .font(.title3.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground)) // Белая карточка
                                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.blue, lineWidth: isSelected ? 1.5 : 0)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func nonInteractiveCard(for item: ZmanItem) -> some View {
        let opinion = item.opinions.first!
        return cardContent(title: item.title, subtitle: item.subtitle, time: opinion.time, isInteractive: false)
    }

    private func interactiveCard(for item: ZmanItem) -> some View {
        let selected = selectedOpinions[item.id] ?? item.defaultOpinion
        // ИСПРАВЛЕНИЕ: Используем selected.title вместо item.subtitle
        return cardContent(title: item.title, subtitle: selected.title, time: selected.time, isInteractive: true)
    }

    private func cardContent(title: String, subtitle: String?, time: String, isInteractive: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(time)
                .font(.title3.weight(.regular))
                .monospacedDigit()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Bottom navigation

    private var bottomNavigationRow: some View {
        HStack(spacing: 24) {
            Button {
                shiftDate(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .padding(12)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }

            Button("היום") {
                date = Date()
                lightHaptic()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.gray.opacity(0.1)))
            .buttonStyle(.plain)

            Button {
                shiftDate(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .padding(12)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
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
            if let opID = map[item.id], let op = item.opinions.first(where: { $0.id == opID }) {
                dict[item.id] = op
            }
        }
        selectedOpinions = dict
    }
    
    private func resetCustomProfileToSephardiDefaults() {
        guard halachicProfile == .custom else { return }
        customOpinionMapRaw = ""
        selectedOpinions = [:]
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

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - ZmanSheet Extension
private extension View {
    @ViewBuilder
    func zmanSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        if #available(iOS 16.0, *) {
            self.sheet(isPresented: isPresented) {
                content()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        } else {
            self.sheet(isPresented: isPresented, content: content)
        }
    }
}
