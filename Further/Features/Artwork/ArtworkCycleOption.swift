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

    var title: String {
        switch self {
        case .oneMonth: AppText.oneMonth
        case .threeMonths: AppText.threeMonths
        case .oneYear: AppText.oneYear
        case .tenKilometers: AppText.tenKilometers
        case .halfMarathon: AppText.halfMarathon
        case .marathon: AppText.marathon
        }
    }

    var isTimeCycle: Bool {
        switch self {
        case .oneMonth, .threeMonths, .oneYear: true
        case .tenKilometers, .halfMarathon, .marathon: false
        }
    }
}
