import Foundation
import CoreLocation
import Combine
import KosherSwift

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var currentLocation: CLLocation?
    @Published var placeName: String = "מיקום נוכחי"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
    }

    // GeoLocation для KosherSwift
    var geoLocation: GeoLocation? {
        guard let loc = currentLocation else { return nil }
        return GeoLocation(
            locationName: placeName,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            timeZone: TimeZone.current
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        currentLocation = loc

        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self = self else { return }
            if let pm = placemarks?.first {
                let city = pm.locality ?? pm.subLocality ?? pm.name ?? "מיקום נוכחי"
                DispatchQueue.main.async {
                    self.placeName = city
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}
