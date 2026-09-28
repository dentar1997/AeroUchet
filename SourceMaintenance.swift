import Foundation


extension AppStore {
    func deleteAllFlightHistory() {
        flights.removeAll()
    }

    func deleteAllWorkPlanEvents() {
        workEvents.removeAll()
    }
}
