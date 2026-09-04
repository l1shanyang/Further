import Foundation
import XCTest
@testable import Further

final class LookbackStateTests: XCTestCase {
    func testRecordsGroupByTheirStartLocationLocalMonth() throws {
        let instant = ISO8601DateFormatter().date(from: "2026-01-31T16:30:00Z")!
        let shanghai = try record(startedAt: instant, timeZone: "Asia/Shanghai")
        let losAngeles = try record(startedAt: instant, timeZone: "America/Los_Angeles")

        let state = LookbackViewState(
            entries: [losAngeles, shanghai].map { ActivityRecordIndexEntry(record: $0) }
        )

        XCTAssertEqual(Set(state.sections.map(\.id)), [
            LookbackMonthKey(year: 2026, month: 1),
            LookbackMonthKey(year: 2026, month: 2),
        ])
    }

    func testSectionsAndRecordsAreNewestFirstWithStableTieBreak() throws {
        let january = try record(
            id: ActivityID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
            startedAt: Date(timeIntervalSince1970: 1_769_904_000),
            timeZone: "UTC"
        )
        let newerA = try record(
            id: ActivityID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
            startedAt: Date(timeIntervalSince1970: 1_772_582_400),
            timeZone: "UTC"
        )
        let newerB = try record(
            id: ActivityID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
            startedAt: newerA.summary.startedAt,
            timeZone: "UTC"
        )

        let state = LookbackViewState(
            entries: [january, newerA, newerB].map { ActivityRecordIndexEntry(record: $0) }
        )

        XCTAssertEqual(state.sections.map(\.id.month), [3, 2])
        XCTAssertEqual(state.sections[0].records.map(\.id), [newerB.id, newerA.id])
    }

    func testMissingFactsAndTechnicalInterruptionRemainFormalRecords() throws {
        let interrupted = try record(
            startedAt: Date(timeIntervalSince1970: 1_772_582_400),
            timeZone: "UTC",
            lifecycle: .technicalInterruption(.appTermination)
        )

        let state = LookbackViewState(entries: [ActivityRecordIndexEntry(record: interrupted)])
        let restored = try XCTUnwrap(state.sections.first?.records.first?.entry)

        XCTAssertEqual(restored.lifecycle, .technicalInterruption(.appTermination))
        XCTAssertNil(restored.summary.distance)
        XCTAssertNil(restored.expression.note)
    }

    func testSectionsOrderByLocalMonthAcrossTimeZones() throws {
        let newerFebruary = try record(
            startedAt: ISO8601DateFormatter().date(from: "2026-03-01T07:30:00Z")!,
            timeZone: "America/Los_Angeles"
        )
        let olderMarch = try record(
            startedAt: ISO8601DateFormatter().date(from: "2026-03-01T00:30:00Z")!,
            timeZone: "Asia/Tokyo"
        )

        let state = LookbackViewState(
            entries: [newerFebruary, olderMarch].map { ActivityRecordIndexEntry(record: $0) }
        )

        XCTAssertEqual(state.sections.map(\.id.month), [3, 2])
    }

    private func record(
        id: ActivityID = ActivityID(),
        startedAt: Date,
        timeZone: String,
        lifecycle: ActivityLifecycle = .endedNormally
    ) throws -> SharedActivityRecordV1 {
        let assignment = ActivityAssignment(
            activityID: id,
            artworkID: ArtworkID(),
            environment: .indoor,
            startedAt: startedAt,
            startTimeZoneIdentifier: timeZone
        )
        return try DomainTestSamples.record(
            assignment: assignment,
            endedAt: startedAt.addingTimeInterval(60),
            lifecycle: lifecycle
        )
    }
}
