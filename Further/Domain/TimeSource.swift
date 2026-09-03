import Foundation

protocol TimeSource: Sendable {
    func now() async -> Date
}

struct SystemTimeSource: TimeSource {
    func now() -> Date {
        Date()
    }
}

actor ControlledTimeSource: TimeSource {
    private var currentDate: Date

    init(now: Date) {
        currentDate = now
    }

    func now() -> Date {
        currentDate
    }

    func advance(by duration: TimeInterval) throws {
        guard duration.isFinite, duration >= 0 else {
            throw DomainValidationError.invalidDuration
        }

        currentDate = currentDate.addingTimeInterval(duration)
    }
}
