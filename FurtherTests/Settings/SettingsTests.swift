import Foundation
import XCTest
@testable import Further

@MainActor
final class SettingsTests: XCTestCase {
    func testUserDefaultsStorePersistsAcrossInstances() throws {
        let suiteName = "Further.SettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = UserDefaultsDistanceUnitStore(defaults: defaults)
        first.distanceUnit = .miles
        let restored = UserDefaultsDistanceUnitStore(defaults: defaults)

        XCTAssertEqual(restored.distanceUnit, .miles)
    }

    func testDistanceUnitPersistsAndOnlyChangesConversion() async throws {
        let unitStore = InMemoryDistanceUnitStore()
        let model = AppRootModel(
            bootstrap: AppBootstrap(
                containerSource: ModelContainerSource {
                    try FurtherModelContainer.inMemory()
                },
                timeSource: SystemTimeSource()
            ),
            timeSource: SystemTimeSource(),
            distanceUnitStore: unitStore
        )
        await model.start()
        await model.createArtwork(cycle: .milestone(.tenKilometers))
        await model.showSettings()

        model.selectDistanceUnit(.miles)

        guard case let .settings(settings) = model.state else {
            return XCTFail("Expected settings")
        }
        XCTAssertEqual(settings.distanceUnit, .miles)
        XCTAssertEqual(unitStore.distanceUnit, .miles)
        XCTAssertEqual(DistanceUnit.miles.format(meters: 1_609.344), "1.00 mi")
        XCTAssertEqual(
            try XCTUnwrap(ManualDistanceParser.meters(from: "1", unit: .miles)),
            1_609.344,
            accuracy: 0.001
        )

        model.backFromSettings()
        guard case let .currentArtwork(artwork) = model.state,
              case .blank = artwork.artwork.state else {
            return XCTFail("Changing units must not alter artwork facts")
        }
    }
}
