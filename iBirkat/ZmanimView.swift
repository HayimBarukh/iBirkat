import SwiftUI
import KosherSwift

/// Экран «Змани היום»
struct ZmanimView: View {

    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @State private var date: Date = Date()
    @State private var selectedOpinions: [String: ZmanOpinion] = [:]
    @State private var activeZmanItem: ZmanItem?
    @State private var showingCandleOffsetDialog = false

    // Settings
    @AppStorage("halachicProfile")
    private var halachicProfileRaw: String = HalachicProfile.sephardi.rawValue

    @AppStorage("candleLightingOffset")
    private var candleLightingOffset: Int = 18

    @AppStorage("customOpinionMap")
    private var customOpinionMapRaw: String = ""
    
    @AppStorage("showZmanimProfiles")
    private var showZmanimProfiles: Bool = true

    // MARK: - Computed Properties
    private var halachicProfile: HalachicProfile {
        HalachicProfile(rawValue: halachicProfileRaw) ?? .sephardi
    }

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
            ZStack(alignment: .topLeading) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerArea
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Блок спец. времени
                            if let special = specialTimesInfo {
                                specialTimesArea(special)
                                    .padding(.vertical, 8)
                                Divider()
                            }

                            // Список зманим (Компактный)
                            LazyVStack(spacing: 0) {
                                ForEach(currentZmanim) { item in
                                    rowView(for: item)
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                            
                            Color.clear.frame(height: 20)
                        }
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
                // Нижняя панель
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                        bottomNavigationRow
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                    }
                    .background(.ultraThinMaterial)
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
                    Circle().fill(Color(.systemBackground).opacity(0.8))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: 2) {
            Text("זמני היום · \(cityName)")
                .font(.headline)
                .padding(.top, 8)

            Text(hebrewInfo.hebrewDate)
                .font(.subheadline)

            Text(gregorianText)
                .font(.caption)
                .foregroundColor(.secondary)

            if showZmanimProfiles {
                HStack(spacing: 6) {
                    profileChip(.custom)
                    profileChip(.sephardi)
                    profileChip(.ashkenazi)
                    profileChip(.chabad)
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 12)
            }
            
            Divider()
        }
        .background(Color(.systemBackground))
    }

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

        let label = HStack(spacing: 3) {
            Text(isSelected ? fullLabel : shortLabel)
                .font(.caption.weight(isSelected ? .semibold : .regular))
            if showStar {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
            }
        }
        .lineLimit(1)
        .padding(.horizontal, isSelected ? 10 : 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isSelected ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
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

    // MARK: - Rows (Compact)

    @ViewBuilder
    private func rowView(for item: ZmanItem) -> some View {
        if item.opinions.count <= 1 {
            let opinion = item.opinions.first!
            compactRow(title: item.title, subtitle: item.subtitle, time: opinion.time, isInteractive: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        } else {
            let isSheetShown = Binding<Bool>(
                get: { activeZmanItem?.id == item.id },
                set: { if !$0 { activeZmanItem = nil } }
            )
            
            Button {
                activeZmanItem = item
            } label: {
                let selected = selectedOpinions[item.id] ?? item.defaultOpinion
                compactRow(title: item.title, subtitle: selected.title, time: selected.time, isInteractive: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zmanSheet(isPresented: isSheetShown) {
                opinionPicker(for: item)
            }
        }
    }

    private func compactRow(title: String, subtitle: String?, time: String, isInteractive: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.regular))
                    .foregroundColor(.primary)

                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(time)
                .font(.body.weight(.medium))
                .monospacedDigit()
            
            // Стрелочка удалена, чтобы время стояло ровно
        }
    }

    // MARK: - Special Times

    private struct SpecialTimesInfo {
        let title: String
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

        let title = (kind == .shabbat) ? "זמני שבת" : "זמני החג"
        
        return SpecialTimesInfo(
            title: title,
            candleLighting: timeString(lighting),
            endTime: timeString(motzaei)
        )
    }
    
    private enum DayKind { case shabbat, yomTov }
    private var specialDayKind: DayKind? {
        var gregorian = Calendar.current
        gregorian.timeZone = geoLocation.timeZone
        let weekday = gregorian.component(.weekday, from: date)
        if weekday == 6 { return .shabbat }

        var hebCal = Calendar(identifier: .hebrew)
        hebCal.timeZone = geoLocation.timeZone
        guard let tomorrow = hebCal.date(byAdding: .day, value: 1, to: date) else { return nil }
        let comps = hebCal.dateComponents([.month, .day], from: tomorrow)
        guard let month = comps.month, let day = comps.day else { return nil }
        
        let leap = (hebCal.range(of: .month, in: .year, for: tomorrow)?.count ?? 12) == 13
        if isYomTov(month: month, day: day, isLeapYear: leap) { return .yomTov }
        return nil
    }
    
    private func isYomTov(month: Int, day: Int, isLeapYear: Bool) -> Bool {
        switch (month, day) {
        case (1, 1), (1, 2), (1, 10), (1, 15), (1, 22), (8, 15), (8, 21), (10, 6): return true
        default: return false
        }
    }

    private func specialTimesArea(_ info: SpecialTimesInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.blue)
                
                Button {
                    lightHaptic()
                    activeZmanItem = nil
                    showingCandleOffsetDialog = true
                } label: {
                    Text("הדלקה: \(candleLightingOffset) דק׳")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .underline()
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
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("כניסה")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(info.candleLighting)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
                
                Divider().frame(height: 24)
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text("יציאה")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(info.endTime)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    // MARK: - Opinion Picker (Styled)

    private func opinionPicker(for item: ZmanItem) -> some View {
        let selectedOpinion = selectedOpinions[item.id] ?? item.defaultOpinion

        return ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
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

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(opinion.title)
                                            .font(.body.weight(isSelected ? .semibold : .regular))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()

                                    Text(opinion.time)
                                        .font(.title3.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
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

    // MARK: - Bottom navigation

    private var bottomNavigationRow: some View {
        HStack(spacing: 20) {
            Button {
                shiftDate(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .medium))
                    .padding(10)
                    .contentShape(Circle())
            }

            Button("היום") {
                date = Date()
                lightHaptic()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
            .buttonStyle(.plain)

            Button {
                shiftDate(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 18, weight: .medium))
                    .padding(10)
                    .contentShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic & Helpers

    private func timeString(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        return timeFormatter.string(from: d)
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
            if let opID = map[item.id],
               let op = item.opinions.first(where: { $0.id == opID }) {
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

// MARK: - Extensions

private extension View {
    @ViewBuilder
    func zmanSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
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
