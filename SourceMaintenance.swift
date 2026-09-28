import Foundation


extension AppStore {
    var importedFlightHistoryCount: Int {
        flights.filter { !isManualFlight($0) }.count
    }

    func deleteImportedFlightHistory() {
        flights.removeAll { !isManualFlight($0) }
    }

    func deleteAllFlightHistory() {
        deleteImportedFlightHistory()
    }

    func deleteAllWorkPlanEvents() {
        workEvents.removeAll()
    }

    private func isManualFlight(_ flight: FlightLeg) -> Bool {
        let assignment = (flight.assignmentNumber ?? "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        return assignment.hasPrefix("manual") || assignment.hasPrefix("manua")
    }
}
