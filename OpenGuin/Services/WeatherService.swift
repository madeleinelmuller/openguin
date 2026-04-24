import Foundation
import CoreLocation
import WeatherKit

actor WeatherService {
    static let shared = WeatherService()
    private let service = WeatherKit.WeatherService.shared

    private init() {}

    func weatherSummary(latitude: Double?, longitude: Double?) async -> String {
        let location: CLLocation
        var placeName: String?

        if let lat = latitude, let lon = longitude {
            location = CLLocation(latitude: lat, longitude: lon)
            if let p = try? await CLGeocoder().reverseGeocodeLocation(location).first {
                placeName = [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            }
        } else {
            let result = await LocationService.shared.currentLocation()
            if let err = result.error { return "Error: \(err)" }
            guard let loc = result.location else { return "Error: Could not determine location." }
            location = loc
            if let p = result.placemark {
                placeName = [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            }
        }

        do {
            let weather = try await service.weather(for: location)
            return format(weather: weather, placeName: placeName, location: location)
        } catch {
            return "Error fetching weather: \(error.localizedDescription)"
        }
    }

    private func format(weather: Weather, placeName: String?, location: CLLocation) -> String {
        let current = weather.currentWeather
        let f = MeasurementFormatter()
        f.unitOptions = .naturalScale
        f.numberFormatter.maximumFractionDigits = 0

        var lines: [String] = []
        if let place = placeName, !place.isEmpty {
            lines.append("Weather for \(place):")
        } else {
            lines.append(String(format: "Weather for %.3f, %.3f:", location.coordinate.latitude, location.coordinate.longitude))
        }
        lines.append("Now: \(current.condition.description), \(f.string(from: current.temperature)) (feels like \(f.string(from: current.apparentTemperature)))")
        lines.append("Humidity: \(Int(current.humidity * 100))%, Wind: \(f.string(from: current.wind.speed)) \(current.wind.compassDirection.abbreviation)")
        lines.append("UV Index: \(current.uvIndex.value) (\(current.uvIndex.category.description))")

        let today = weather.dailyForecast.forecast.first
        if let day = today {
            lines.append("Today: High \(f.string(from: day.highTemperature)), Low \(f.string(from: day.lowTemperature)), \(day.condition.description)")
            if day.precipitationChance > 0 {
                lines.append("Precipitation chance: \(Int(day.precipitationChance * 100))%")
            }
        }

        let hourly = weather.hourlyForecast.forecast.prefix(6)
        if !hourly.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "ha"
            let next = hourly.map { "\(df.string(from: $0.date).lowercased()) \(f.string(from: $0.temperature))" }.joined(separator: ", ")
            lines.append("Next hours: \(next)")
        }

        return lines.joined(separator: "\n")
    }
}
