import Foundation

enum DistanceUnit: String, CaseIterable, Equatable, Sendable {
    case kilometers
    case miles

    var metersPerUnit: Double {
        switch self {
        case .kilometers: 1_000
        case .miles: 1_609.344
        }
    }

    var symbol: String {
        switch self {
        case .kilometers: AppText.kilometers
        case .miles: AppText.miles
        }
    }

    var title: String {
        switch self {
        case .kilometers: AppText.kilometersTitle
        case .miles: AppText.milesTitle
        }
    }

    func format(meters: Double?) -> String {
        guard let meters else { return AppText.notRecorded }
        return String(format: "%.2f %@", meters / metersPerUnit, symbol)
    }
}

@MainActor
protocol DistanceUnitStoring: AnyObject {
    var distanceUnit: DistanceUnit { get set }
}

@MainActor
final class UserDefaultsDistanceUnitStore: DistanceUnitStoring {
    private static let key = "distance-unit"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var distanceUnit: DistanceUnit {
        get {
            guard let rawValue = defaults.string(forKey: Self.key),
                  let unit = DistanceUnit(rawValue: rawValue) else {
                return .kilometers
            }
            return unit
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.key)
        }
    }
}

@MainActor
final class InMemoryDistanceUnitStore: DistanceUnitStoring {
    var distanceUnit: DistanceUnit

    init(distanceUnit: DistanceUnit = .kilometers) {
        self.distanceUnit = distanceUnit
    }
}
