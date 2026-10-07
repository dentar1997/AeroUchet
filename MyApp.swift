import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Весь интерфейс на русском, в том числе системные календари (Денис 07.10).
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
