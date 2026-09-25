import Foundation

// One-time removal of the test events stored on the iPad before real history import.
enum TestEventCleanup {
    private static let completionKey =
        "testEventCleanup_20260925_v1"

    private static let eventKeys = [
        "savedFlightLegs",
        "savedWorkEvents",
        "savedAbsenceEvents"
    ]

    static func perform(
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: completionKey) else {
            return
        }

        for key in eventKeys {
            defaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: completionKey)
    }
}
