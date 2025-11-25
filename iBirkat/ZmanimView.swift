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
    @State private var showingSettingsDialog = false
    @State private var showCopyAlert = false

    // Settings
    @AppStorage("candleLightingOffset")
    private var candleLightingOffset: Int = 18
    
    @AppStorage("manualElevation")
    private var manualElevation: Double = 0.0
    
    @AppStorage("useManualElevation")
    private var useManualElevation: Bool = false

    @AppStorage("customOpinionMap")
    private var customOpinionMapRaw: String = ""
    
    // MARK: - Computed Properties

    private var geoLocation: GeoLocation {
        if useManualElevation {
            let baseLoc = locationManager.geoLocation ?? GeoLocation(
                locationName: "ירושלים", latitude: 31.778, longitude: 35.235, elevation: 0, timeZone: TimeZone(identifier: "Asia/Jerusalem")!
            )
            return GeoLocation(
                locationName: baseLoc.locationName,
                latitude: baseLoc.latitude,
                longitude: baseLoc.longitude,
                elevation: manualElevation,
                timeZone: baseLoc.timeZone
            )
        }
        
        if let g = locationManager.geoLocation {
            return g
        }
        
        let tz = TimeZone(identifier: "Asia/Jerusalem") ?? .current
        return GeoLocation(
            locationName: "ירושלים",
            latitude: 31.778,
            longitude: 35.235,
            elevation: 800,
            timeZone: tz
        )
    }

    private var provider: ZmanimProvider {
        ZmanimProvider(geoLocation: geoLocation)
    }

    private var currentZmanim: [ZmanItem] {
        provider.zmanim(for: date)
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
                                    .padding(.vertical, 6)
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
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .environment(\.layoutDirection, .rightToLeft)
                .onAppear {
                    applyCustomMap()
                }
                .onChange(of: date) { _ in
                    applyCustomMap()
                }
                // Нижняя панель
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                        bottomNavigationRow
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 0)
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
        .overlay(alignment: .topTrailing) {
            copyDebugButton
                .padding(.horizontal, 12)
                .padding(.top, 4)
        }
        .alert("הועתק ללוח", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("כל הנתונים הועתקו לבדיקה")
        }
    }

    // MARK: - Buttons

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
    
    private var copyDebugButton: some View {
        Button {
            copyDebugData()
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 15, weight: .medium))
                .padding(8)
                .background(
                    Circle().fill(Color(.systemBackground).opacity(0.8))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
                )
                .foregroundColor(.blue)
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
            
            // Чипсы профилей удалены, добавляем небольшой отступ
            Spacer().frame(height: 8)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Rows (Compact List)

    @ViewBuilder
    private func rowView(for item: ZmanItem) -> some View {
        if item.opinions.count <= 1 {
            let opinion = item.opinions.first!
            compactRow(title: item.title, subtitle: item.subtitle, time: opinion.time, isInteractive: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
                    .padding(.vertical, 8)
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
        }
    }

    // MARK: - Special Times Area

    private struct SpecialTimesInfo {
        let title: String
        let candleLighting: String
        let endTime: String
    }

    private var specialTimesInfo: SpecialTimesInfo? {
        guard let kind = specialDayKind else { return nil }
        let lighting = provider.getCandleLightingTime(for: date, minutesBeforeSunset: candleLightingOffset)
        
        var motzaeiCalendar = Calendar.current
        motzaeiCalendar.timeZone = geoLocation.timeZone
        let motzaeiDate = motzaeiCalendar.date(byAdding: .day, value: 1, to: date)
        
        // Берем ID мнения из карты выбора пользователя
        let map = loadCustomOpinionIDs()
        let havdalahOpinionID = map["havdalah"]
        
        let motzaeiStr = provider.getHavdalahTime(
            for: motzaeiDate ?? date,
            opinionID: havdalahOpinionID
        )

        let title = (kind == .shabbat) ? "זמני שבת" : "זמני החג"
        
        return SpecialTimesInfo(
            title: title,
            candleLighting: lighting,
            endTime: motzaeiStr
        )
    }
    
    private enum DayKind { case shabbat, yomTov }
    private var specialDayKind: DayKind? {
        var gregorian = Calendar.current
        gregorian.timeZone = geoLocation.timeZone
        let weekday = gregorian.component(.weekday, from: date)
        if weekday == 6 { return .shabbat } // Friday

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
        case (7, 1), (7, 2), (7, 10), (7, 15), (7, 22): return true
        case (1, 15), (1, 21): return true
        case (3, 6): return true
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
                    showingSettingsDialog = true
                } label: {
                    Text("הגדרות: \(candleLightingOffset) דק׳ / גובה \(Int(geoLocation.elevation))מ׳")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingSettingsDialog) {
                    SettingsSheet(
                        candleOffset: $candleLightingOffset,
                        useManualElev: $useManualElevation,
                        manualElev: $manualElevation,
                        customOpinionMapRaw: $customOpinionMapRaw,
                        selectedOpinions: $selectedOpinions,
                        currentAutoElev: locationManager.geoLocation?.elevation ?? 0
                    )
                    .presentationDetents([.medium])
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

    // MARK: - Opinion Picker

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
                                    // Радио-кнопка
                                    Circle()
                                        .strokeBorder(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                        .background(Circle().fill(isSelected ? Color.blue : Color.clear))
                                        .frame(width: 22, height: 22)
                                        .overlay(Circle().fill(Color.white).frame(width: 8, height: 8).opacity(isSelected ? 1 : 0))

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

    // MARK: - Bottom Navigation

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

    // MARK: - Helpers

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
        // Всегда сохраняем выбор пользователя, так как профиль один (общий)
        var map = loadCustomOpinionIDs()
        map[item.id] = opinion.id
        saveCustomOpinionIDs(map)
        lightHaptic()
        activeZmanItem = nil
    }

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func copyDebugData() {
        var output = "DEBUG ZMANIM REPORT\n"
        output += "Date: \(gregorianText)\n"
        output += "Location: \(cityName) (Elv: \(geoLocation.elevation)m)\n\n"
        
        for item in currentZmanim {
            output += "[\(item.title)]\n"
            for opinion in item.opinions {
                output += "- \(opinion.title): \(opinion.time)\n"
            }
            output += "\n"
        }
        
        UIPasteboard.general.string = output
        showCopyAlert = true
        lightHaptic()
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Binding var candleOffset: Int
    @Binding var useManualElev: Bool
    @Binding var manualElev: Double
    @Binding var customOpinionMapRaw: String
    @Binding var selectedOpinions: [String: ZmanOpinion]
    let currentAutoElev: Double
    
    @Environment(\.dismiss) var dismiss
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("הדלקת נרות")) {
                    Picker("זמן לפני השקיעה", selection: $candleOffset) {
                        Text("18 דקות").tag(18)
                        Text("24 דקות").tag(24)
                        Text("30 דקות").tag(30)
                        Text("40 דקות").tag(40)
                    }
                }
                
                Section(header: Text("גובה טופוגרפי (מטרים)")) {
                    Toggle("הגדרת גובה ידנית", isOn: $useManualElev)
                    
                    if useManualElev {
                        HStack {
                            Text("גובה במטרים:")
                            Spacer()
                            TextField("0", value: $manualElev, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    } else {
                        HStack {
                            Text("גובה אוטומטי (GPS):")
                            Spacer()
                            Text("\(Int(currentAutoElev)) מ׳")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(footer: Text("שינוי הגובה משפיע על זמני הזריחה והשקיעה הנראים.")) {
                    EmptyView()
                }
                
                // Кнопка сброса настроек
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("אפס להגדרות ברירת מחדל")
                            Spacer()
                        }
                    }
                    .alert("איפוס הגדרות", isPresented: $showResetConfirmation) {
                        Button("ביטול", role: .cancel) { }
                        Button("אפס", role: .destructive) {
                            resetDefaults()
                        }
                    } message: {
                        Text("האם אתה בטוח שברצונך לאפס את כל בחירות הזמנים לברירת המחדל?")
                    }
                }
            }
            .navigationTitle("הגדרות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סיום") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private func resetDefaults() {
        // Сброс выборов мнений
        customOpinionMapRaw = ""
        selectedOpinions = [:]
        
        // Сброс свечей на 18 (стандарт)
        candleOffset = 18
        
        // Сбрасываем ручную высоту? Можно, но не обязательно. Оставим на усмотрение пользователя.
        // useManualElev = false
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
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
