import Foundation

struct LookbackMonthKey: Hashable, Sendable {
    let year: Int
    let month: Int
}

struct LookbackRecordRow: Identifiable, Equatable, Sendable {
    let entry: ActivityRecordIndexEntry

    var id: ActivityID { entry.id }
}

struct LookbackMonthSection: Identifiable, Equatable, Sendable {
    let id: LookbackMonthKey
    let records: [LookbackRecordRow]
}

struct LookbackViewState: Equatable, Sendable {
    let sections: [LookbackMonthSection]

    init(entries: [ActivityRecordIndexEntry]) {
        let sorted = entries.sorted {
            if $0.summary.startedAt != $1.summary.startedAt {
                return $0.summary.startedAt > $1.summary.startedAt
            }
            return $0.id.rawValue.uuidString > $1.id.rawValue.uuidString
        }
        var grouped: [LookbackMonthKey: [LookbackRecordRow]] = [:]

        for entry in sorted {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(
                identifier: entry.summary.startTimeZoneIdentifier
            ) ?? .gmt
            let components = calendar.dateComponents(
                [.year, .month],
                from: entry.summary.startedAt
            )
            let key = LookbackMonthKey(
                year: components.year ?? 0,
                month: components.month ?? 0
            )
            grouped[key, default: []].append(LookbackRecordRow(entry: entry))
        }
        let keys = grouped.keys.sorted {
            ($0.year, $0.month) > ($1.year, $1.month)
        }
        sections = keys.map {
            LookbackMonthSection(id: $0, records: grouped[$0] ?? [])
        }
    }
}

enum LookbackFlowState: Equatable, Sendable {
    case list(LookbackViewState)
    case detail(SharedActivityRecordV1)
}
