import Foundation

enum ArtworkCycleOption: String, CaseIterable, Identifiable, Sendable {
    case oneMonth
    case threeMonths
    case oneYear
    case tenKilometers
    case halfMarathon
    case marathon

    var id: Self { self }

    var cycle: ArtworkCycle {
        switch self {
        case .oneMonth: .time(.oneMonth)
        case .threeMonths: .time(.threeMonths)
        case .oneYear: .time(.oneYear)
        case .tenKilometers: .milestone(.tenKilometers)
        case .halfMarathon: .milestone(.halfMarathon)
        case .marathon: .milestone(.marathon)
        }
    }

    func title(distanceUnit: DistanceUnit) -> String {
        switch self {
        case .oneMonth: AppText.oneMonth
        case .threeMonths: AppText.threeMonths
        case .oneYear: AppText.oneYear
        case .tenKilometers: distanceUnit.format(meters: 10_000)
        case .halfMarathon: distanceUnit.format(meters: 21_097.5)
        case .marathon: distanceUnit.format(meters: 42_195)
        }
    }

    var isTimeCycle: Bool {
        switch self {
        case .oneMonth, .threeMonths, .oneYear: true
        case .tenKilometers, .halfMarathon, .marathon: false
        }
    }
}
