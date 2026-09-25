import SwiftUI

@main
struct MyApp: App {
    init() {
        TestEventCleanup.perform()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
