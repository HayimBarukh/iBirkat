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

    // Профиль по общине
    @AppStorage("halachicProfile")
    private var halachicProfileRaw: String = HalachicProfile.sephardi.rawValue

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

                    separator
                        .padding(.horizontal, 16)

                    zmanimList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("בחר דעה עבור הזמן")
                .font(.headline)
                .padding(.bottom, 2)

            ForEach(item.opinions) { opinion in
                Button(opinion.title) {
                    pickOpinion(item, opinion)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Divider()

            Button("ביטול") {
                activeZmanItem = nil
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(14)
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
