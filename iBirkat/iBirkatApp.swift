import SwiftUI
import UIKit

// MARK: - Общий помощник для ярлыков

private let shortcutKey = "shortcutPrayerID"

private func saveShortcutPrayerID(from type: String) {
    let id: String
    switch type {
    case "birkat": id = "birkat"
    case "meen":   id = "meen"
    case "bore":   id = "bore"
    default:       id = ""
    }
    UserDefaults.standard.set(id, forKey: shortcutKey)
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        let itemBirkat = UIMutableApplicationShortcutItem(
            type: "birkat",
            localizedTitle: "ברכת המזון"
        )

        let itemMeen = UIMutableApplicationShortcutItem(
            type: "meen",
            localizedTitle: "מעין שלש"
        )

        let itemBore = UIMutableApplicationShortcutItem(
            type: "bore",
            localizedTitle: "בורא נפשות"
        )

        UIApplication.shared.shortcutItems = [itemBirkat, itemMeen, itemBore]

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        if let shortcutItem = options.shortcutItem {
            saveShortcutPrayerID(from: shortcutItem.type)
        }

        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )

        config.delegateClass = SceneDelegate.self
        return config
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

// MARK: - SceneDelegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        saveShortcutPrayerID(from: shortcutItem.type)
        completionHandler(true)
    }
}

// MARK: - Точка входа SwiftUI

@main
struct iBirkatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
