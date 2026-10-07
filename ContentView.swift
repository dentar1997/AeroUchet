import SwiftUI
import UIKit


struct ContentView: View {
    @StateObject private var store = AppStore()
    @StateObject private var absenceStore = AbsenceStore()
    @StateObject private var calendarSync = ProductionCalendarSyncModel()
    @StateObject private var planStore = AssignmentPlanStore()
    @State private var storageNotices: [String] = []
    @State private var saveFailures: [String] = []

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }

            CalendarView(
                store: store,
                absenceStore: absenceStore,
                calendarSync: calendarSync
            )
            .tabItem {
                Label("Календарь", systemImage: "calendar")
            }

            AssignmentsView(
                store: store,
                planStore: planStore
            )
            .tabItem {
                Label("Назначения", systemImage: "square.grid.2x2")
            }

            AccountingView(
                store: store,
                absenceStore: absenceStore,
                calendarSync: calendarSync
            )
            .tabItem {
                Label("Учёт", systemImage: "list.clipboard")
            }

            SimplePage(
                title: "Зарплата",
                icon: "rublesign.circle"
            )
            .tabItem {
                Label("Зарплата", systemImage: "rublesign.circle")
            }

            SettingsRootV116View(
                store: store,
                absenceStore: absenceStore,
                calendarSync: calendarSync,
                planStore: planStore
            )
            .tabItem {
                Label("Ещё", systemImage: "ellipsis.circle")
            }

            // Вкладка «Тест» (07.10): база расписания в стиле перспективного плана — для сравнения.
            NavigationStack {
                FlightScheduleDatabaseV130View(largeText: true)
                    // У «Теста» нет заголовка: пустая navigation bar на iOS 26
                    // меняла safe area при каждом свайпе и визуально дёргала весь экран.
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("Тест", systemImage: "testtube.2")
            }
        }
        .environmentObject(store)
        .environmentObject(planStore)
        // Фон как в Stage Manager и во весь экран (Денис 07.10 04:39–04:50).
        .onAppear { ElevatedAppearance.apply() }
        .onAppear {
            storageNotices = StorageSafety.pendingNotices()
        }
        .alert(
            "Данные не прочитались",
            isPresented: Binding(
                get: { !storageNotices.isEmpty },
                set: { shown in
                    if !shown {
                        StorageSafety.clearPendingNotices()
                        storageNotices = []
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Не удалось прочитать: \(storageNotices.joined(separator: ", ")). Копия сохранена в резерв, ничего не удалено. Сообщи Claude до новых изменений.")
        }
        .onReceive(NotificationCenter.default.publisher(for: StorageSafety.saveFailedNotification)) { note in
            guard let title = note.userInfo?["title"] as? String,
                  !saveFailures.contains(title) else { return }
            saveFailures.append(title)
        }
        .alert(
            "Данные не сохранились",
            isPresented: Binding(
                get: { !saveFailures.isEmpty && storageNotices.isEmpty },
                set: { shown in if !shown { saveFailures = [] } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Не удалось сохранить: \(saveFailures.joined(separator: ", ")). Прежние сохранённые данные не тронуты. Сообщи Claude до новых изменений.")
        }
    }
}


/// «Приподнятый» вид окна: в тёмной теме фон мягкий тёмно-серый, как в Stage Manager,
/// а не чисто чёрный. Системные цвета (фон, таблицы, плашки) берут свои «приподнятые» оттенки.
enum ElevatedAppearance {
    static func apply() {
        let update = {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                windowScene.traitOverrides.userInterfaceLevel = .elevated
                for window in windowScene.windows {
                    window.traitOverrides.userInterfaceLevel = .elevated
                }
            }
        }
        update()
        // Окно может появиться чуть позже первого кадра.
        DispatchQueue.main.async(execute: update)
    }
}
