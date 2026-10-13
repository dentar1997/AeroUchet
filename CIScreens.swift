import Foundation

// Снимки экранов в CI (Денис 12.10, «Программируй» 13.10).
// Работает ТОЛЬКО в iOS Simulator на GitHub Actions: на iPad (Swift Playgrounds)
// эта часть не компилируется, и приложение ведёт себя как раньше.
//
// Аргументы запуска:
//   --aerouchet-ci-tab=home|calendar|assignments|accounting|salary|more — открыть вкладку
//   --aerouchet-ci-demo — вымышленные рейсы текущего месяца, если история пуста
// Личных данных здесь нет: номера заданий, рейсы и времена придуманы.

#if targetEnvironment(simulator)
enum CIScreens {
    private static let arguments = ProcessInfo.processInfo.arguments

    private static func value(_ name: String) -> String? {
        let prefix = "--aerouchet-ci-\(name)="
        return arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }

    /// Номер вкладки по порядку в `ContentView`.
    static var initialTab: Int {
        switch value("tab") {
        case "calendar": return 1
        case "assignments": return 2
        case "accounting": return 3
        case "salary": return 4
        case "more": return 5
        default: return 0
        }
    }

    /// Пишет вымышленную историю файлами (как обычное сохранение), до запуска `AppStore`.
    static func seedDemoDataIfRequested() {
        guard arguments.contains("--aerouchet-ci-demo"),
              StorageSafety.fileNames(inFolder: "history").isEmpty else { return }
        let legs = demoLegs(now: Date())
        let encoder = JSONEncoder()
        for (month, monthLegs) in Dictionary(grouping: legs, by: { historyMonthKey(for: $0.date) }) {
            guard let data = try? encoder.encode(monthLegs) else { continue }
            StorageSafety.storeData(data, name: "history/flights-\(month).json", title: "CI demo")
        }
        StorageSafety.storeFile(["version": "ci-demo"], name: "history/migrated.json", title: "CI demo")
    }

    /// Двухлеговые полётные смены «туда-обратно» каждые 4 дня текущего месяца.
    private static func demoLegs(now: Date) -> [FlightLeg] {
        let routes: [(String, String, String, String, Int, Int, String, String)] = [
            // откуда, куда, номер туда, обратно, полёт мин, час вылета, ВС, борт
            ("SVO", "LED", "0034", "0035", 80, 7, "A-320", "RA-73745"),
            ("SVO", "AER", "1120", "1121", 150, 9, "A-321", "RA-73772"),
            ("SVO", "KZN", "1190", "1191", 85, 13, "A-320N", "RA-73745"),
            ("SVO", "MRV", "1314", "1315", 125, 6, "A-321B", "RA-73772"),
            ("SVO", "IST", "2130", "2131", 205, 10, "A-320", "RA-73745"),
            ("SVO", "GOJ", "1200", "1201", 70, 22, "A-321", "RA-73772"),
        ]
        var components = moscowCalendar.dateComponents([.year, .month], from: now)
        components.timeZone = moscowTimeZone
        var legs: [FlightLeg] = []
        for (index, route) in routes.enumerated() {
            components.day = 2 + index * 4
            components.hour = route.5
            components.minute = 15
            guard let firstOn = moscowCalendar.date(from: components) else { continue }
            let assignment = String(900_001 + index)
            let firstOff = firstOn.addingTimeInterval(TimeInterval(route.4 * 60))
            let secondOn = firstOff.addingTimeInterval(55 * 60)
            let secondOff = secondOn.addingTimeInterval(TimeInterval((route.4 + 5) * 60))
            let first = PortalFlightTimes(
                workStart: firstOn.addingTimeInterval(-60 * 60), engineOn: firstOn,
                takeoff: firstOn.addingTimeInterval(8 * 60), landing: firstOff.addingTimeInterval(-8 * 60),
                engineOff: firstOff, workEnd: firstOff
            )
            let second = PortalFlightTimes(
                workStart: firstOff, engineOn: secondOn,
                takeoff: secondOn.addingTimeInterval(8 * 60), landing: secondOff.addingTimeInterval(-8 * 60),
                engineOff: secondOff, workEnd: secondOff.addingTimeInterval(30 * 60)
            )
            let pairs: [(PortalFlightTimes, String, String, String)] = [
                (first, route.0, route.1, route.2), (second, route.1, route.0, route.3),
            ]
            for (times, from, to, legNumber) in pairs {
                legs.append(FlightLeg(
                    date: formatDate(times.engineOn), flightNumber: "\(route.2)/\(route.3)",
                    departure: from, arrival: to, aircraft: route.6, registration: route.7,
                    plannedDeparture: "",
                    workStart: formatClock(times.workStart), engineOn: formatClock(times.engineOn),
                    takeoff: formatClock(times.takeoff), landing: formatClock(times.landing),
                    engineOff: formatClock(times.engineOff), portalTimes: times,
                    portalKey: FlightLeg.portalKey(for: times),
                    assignmentNumber: assignment, legNumber: legNumber, scheduleType: .planned
                ))
            }
        }
        return legs
    }
}
#else
enum CIScreens {
    static var initialTab: Int { 0 }
    static func seedDemoDataIfRequested() {}
}
#endif
