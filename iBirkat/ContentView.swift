import SwiftUI
import UIKit

struct ContentView: View {

    // MARK: - Состояния

    @State private var currentPageIndex: Int = 0
    @State private var selectedPrayer: Prayer = birkatHamazon
    @State private var showSettings: Bool = false
    @State private var showResetAlert: Bool = false
    
    // Управление переходом на экран зманим
    @State private var navigateToZmanim: Bool = false
    @State private var hasPerformedStartupNavigation: Bool = false

    @AppStorage("selectedNusach") private var selectedNusach: Nusach = .edotHaMizrach
    @AppStorage("startWithZimun") private var startWithZimun: Bool = false
    @AppStorage("keepScreenOn")   private var keepScreenOn: Bool = false
    @AppStorage("startOnZmanim")  private var startOnZmanim: Bool = false
    
    // Настройки Зманим (доступ для сброса)
    @AppStorage("candleLightingOffset") private var candleLightingOffset: Int = 18
    @AppStorage("customOpinionMap") private var customOpinionMapRaw: String = ""
    @AppStorage("manualElevation") private var manualElevation: Double = 0.0
    @AppStorage("useManualElevation") private var useManualElevation: Bool = false
    
    // Устаревшие настройки (для очистки при сбросе)
    @AppStorage("havdalahOpinion") private var havdalahOpinion: String = "default"
    @AppStorage("halachicProfile") private var halachicProfileRaw: String = "sephardi"

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass
    @Environment(\.scenePhase)          private var scenePhase

    @EnvironmentObject var locationManager: LocationManager

    private var isCompactPhone: Bool {
        hSizeClass == .compact && vSizeClass == .regular
    }

    private var isPhone: Bool {
        let idiom = UIDevice.current.userInterfaceIdiom
        if idiom == .pad || idiom == .mac { return false }
        if idiom == .phone { return true }
        let maxSide = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return maxSide < 900
    }

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
        HebrewDateHelper.shared.currentInfo(for: locationManager.geoLocation)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    prayerHeaderAndPickers

                    PDFKitView(
                        pdfName: selectedPrayer.pdfName(for: selectedNusach, isPhone: isPhone),
                        currentPageIndex: $currentPageIndex
                    )
                    .padding(.horizontal, isCompactPhone ? -2 : -12)
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
                        locationManager.requestLocationUpdate()
                    } else {
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                }
                .onAppear {
                    ensureValidSelection()
                    updatePageIndexForCurrentSelection()
                    handleShortcutIfNeeded()
                    updateIdleTimer()
                    locationManager.requestLocationUpdate()
                    checkStartupNavigation()
                }
            }
            .overlay {
                if showSettings {
                    settingsOverlay
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Логика старта

    private func checkStartupNavigation() {
        if startOnZmanim && !hasPerformedStartupNavigation {
            hasPerformedStartupNavigation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToZmanim = true
            }
        }
    }

    // MARK: - Шорткаты

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

    // MARK: - Помощники выбора брохи

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

    // MARK: - Кнопки в шапке

    private var gearButton: some View {
        Button {
            lightHaptic()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                showSettings = true
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: isPhone ? 15 : 18, weight: .regular))
                .padding(8)
                .background(
                    Capsule().fill(Color.gray.opacity(0.12))
                )
                .foregroundColor(.gray.opacity(0.85))
        }
    }

    private var zmanimButton: some View {
        NavigationLink(isActive: $navigateToZmanim) {
            ZmanimView()
                .environmentObject(locationManager)
        } label: {
            Image(systemName: "sun.max")
                .font(.system(size: isPhone ? 15 : 18, weight: .regular))
                .padding(8)
                .background(
                    Capsule().fill(Color.gray.opacity(0.12))
                )
                .foregroundColor(.gray.opacity(0.85))
        }
    }

    // MARK: - Оверлей настроек

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
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
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
                
                Toggle(isOn: $startOnZmanim) {
                    Text("פתיחה במסך זמנים")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Text("אפס הגדרות זמנים (ע״מ)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .alert("איפוס הגדרות", isPresented: $showResetAlert) {
                    Button("ביטול", role: .cancel) { }
                    Button("אפס", role: .destructive) {
                        resetZmanimSettings()
                    }
                } message: {
                    Text("האם אתה בטוח? כל ההגדרות בזמנים יאופסו למנהג עדות המזרח (ר׳ עובדיה).")
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
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18),
                            radius: 18, x: 0, y: 8)
            )
        }
    }
    
    private func resetZmanimSettings() {
        candleLightingOffset = 18
        customOpinionMapRaw = ""
        manualElevation = 0.0
        useManualElevation = false
        havdalahOpinion = "default"
        halachicProfileRaw = "sephardi" // На всякий случай сбрасываем профиль на дефолтный
        
        lightHaptic()
    }

    // MARK: - Шапка с датой и пикером брохи

    private var prayerHeaderAndPickers: some View {
        let info = jewishInfo

        let dateFont: Font = isPhone ? .footnote.weight(.medium) : .body.weight(.medium)
        let nusachFont: Font = isPhone ? .footnote.weight(.semibold) : .body.weight(.semibold)
        let spacing: CGFloat = isPhone ? 4 : 8

        return VStack(spacing: spacing) {

            HStack(spacing: 6) {
                Spacer()

                Text(info.hebrewDate)
                    .font(dateFont)

                Text("·")
                    .font(dateFont)
                    .foregroundColor(.secondary)

                Text(selectedNusach.title)
                    .font(nusachFont)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.bottom, 2)

            if !visibleAfterFoodPrayers.isEmpty {
                ZStack {
                    HStack {
                        zmanimButton
                        Spacer()
                        gearButton
                    }
                    .padding(.horizontal, isPhone ? 12 : 24)

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

            if let special = info.special, !special.isEmpty {
                Text("היום: \(special)")
                    .font(isPhone ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 14)
                    .background(Color.yellow.opacity(0.16))
                    .cornerRadius(999)
                    .padding(.top, 2)
            }
        }
        .padding(.top, isPhone ? 6 : 10)
        .padding(.horizontal, 12)
        .padding(.bottom, isPhone ? 6 : 10)
    }
}
