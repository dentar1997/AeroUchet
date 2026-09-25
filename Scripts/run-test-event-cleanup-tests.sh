#!/bin/bash
set -euo pipefail

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation

let suiteName = "AeroUchetCleanupRegression"
guard let defaults = UserDefaults(suiteName: suiteName) else {
    fatalError("Cannot create isolated test defaults")
}
defaults.removePersistentDomain(forName: suiteName)

for key in ["savedFlightLegs", "savedWorkEvents", "savedAbsenceEvents"] {
    defaults.set(Data([1, 2, 3]), forKey: key)
}
defaults.set("keep", forKey: "flightNormVersions")
defaults.set("keep", forKey: "productionCalendarData")

TestEventCleanup.perform(defaults: defaults)
for key in ["savedFlightLegs", "savedWorkEvents", "savedAbsenceEvents"] {
    precondition(defaults.object(forKey: key) == nil, "Test event was not removed")
}
precondition(defaults.string(forKey: "flightNormVersions") == "keep")
precondition(defaults.string(forKey: "productionCalendarData") == "keep")

defaults.set(Data([4]), forKey: "savedFlightLegs")
TestEventCleanup.perform(defaults: defaults)
precondition(defaults.data(forKey: "savedFlightLegs") == Data([4]),
             "A second launch removed newly imported data")

defaults.removePersistentDomain(forName: suiteName)
print("One-time test-event cleanup checks passed.")
SWIFT

swiftc TestEventCleanup.swift "$test_dir/main.swift" -o "$test_dir/check"
"$test_dir/check"
