import Foundation


extension AppStore {
    /// Удаление истории полётов целиком — вместе с ручными заданиями Manual (D39).
    /// Текущий план, перспективный план и план работ не затрагиваются.
    var flightHistoryCount: Int {
        flights.count
    }

    func deleteAllFlightHistory() {
        flights.removeAll()
    }

    func deleteAllWorkPlanEvents() {
        workEvents.removeAll()
    }
}
