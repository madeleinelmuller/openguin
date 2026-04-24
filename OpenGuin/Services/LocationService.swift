import Foundation
import CoreLocation

actor LocationService {
    static let shared = LocationService()
    private var _delegate: Delegate?

    private init() {}

    private func delegate() async -> Delegate {
        if let d = _delegate { return d }
        let d = await Delegate()
        _delegate = d
        return d
    }

    func currentLocation() async -> (location: CLLocation?, placemark: CLPlacemark?, error: String?) {
        let status = await delegate().authorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await delegate().requestAuthorization()
            guard granted else {
                return (nil, nil, "Location access not granted. Enable it in Settings > Privacy > Location Services.")
            }
        case .denied, .restricted:
            return (nil, nil, "Location access denied. Enable it in Settings > Privacy > Location Services.")
        default:
            break
        }

        guard let location = await delegate().requestLocation() else {
            return (nil, nil, "Could not determine current location.")
        }

        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return (location, placemark, nil)
    }

    func describeCurrent() async -> String {
        let result = await currentLocation()
        if let err = result.error { return "Error: \(err)" }
        guard let loc = result.location else { return "Error: No location available." }

        var lines: [String] = []
        if let p = result.placemark {
            let locality = [p.locality, p.administrativeArea, p.country].compactMap { $0 }.joined(separator: ", ")
            if !locality.isEmpty { lines.append(locality) }
            if let name = p.name, name != p.locality { lines.append(name) }
        }
        lines.append(String(format: "Coordinates: %.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
        lines.append(String(format: "Accuracy: ±%.0fm", loc.horizontalAccuracy))
        return lines.joined(separator: "\n")
    }
}

@MainActor
private final class Delegate: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authContinuations: [CheckedContinuation<Bool, Never>] = []
    private var locationContinuations: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            authContinuations.append(cont)
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { cont in
            locationContinuations.append(cont)
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let granted = status == .authorizedWhenInUse || status == .authorizedAlways
        guard status != .notDetermined else { return }
        Task { @MainActor in
            let pending = self.authContinuations
            self.authContinuations.removeAll()
            for c in pending { c.resume(returning: granted) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            let pending = self.locationContinuations
            self.locationContinuations.removeAll()
            for c in pending { c.resume(returning: last) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let pending = self.locationContinuations
            self.locationContinuations.removeAll()
            for c in pending { c.resume(returning: nil) }
        }
    }
}
