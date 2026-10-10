import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
                #if targetEnvironment(simulator)
                // Screenshot-only route. The normal iPad app and its navigation
                // remain unchanged; the capture uses the actual aircraft table.
                if ProcessInfo.processInfo.arguments.contains("--aerouchet-ci-aircraft-tamm") {
                    NavigationStack {
                        AircraftReferenceSettingsV129View(initialSearch: "Тамм")
                    }
                    .onAppear { ElevatedAppearance.apply() }
                } else {
                    ContentView()
                }
                #else
                ContentView()
                #endif
            }
            // Весь интерфейс на русском, в том числе системные календари (Денис 07.10).
            .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
