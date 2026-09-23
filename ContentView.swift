import SwiftUI


struct ContentView: View {
    
    @StateObject
    private var store =
    AppStore()
    
    
    @StateObject
    private var absenceStore =
    AbsenceStore()
    
    
    @StateObject
    private var calendarSync =
    ProductionCalendarSyncModel()
    
    
    var body: some View {
        
        TabView {
            
            HomeView(
                store:
                    store
            )
            .tabItem {
                
                Label(
                    "Главная",
                    systemImage:
                        "house.fill"
                )
            }
            
            
            CalendarView(
                store:
                    store,
                absenceStore:
                    absenceStore,
                calendarSync:
                    calendarSync
            )
            .tabItem {
                
                Label(
                    "Календарь",
                    systemImage:
                        "calendar"
                )
            }
            
            
            FlightsView(
                store:
                    store
            )
            .tabItem {
                
                Label(
                    "Полёты",
                    systemImage:
                        "airplane"
                )
            }
            
            
            AccountingView(
                store:
                    store,
                absenceStore:
                    absenceStore,
                calendarSync:
                    calendarSync
            )
            .tabItem {
                
                Label(
                    "Учёт",
                    systemImage:
                        "list.clipboard"
                )
            }
            
            
            SimplePage(
                title:
                    "Зарплата",
                icon:
                    "rublesign.circle"
            )
            .tabItem {
                
                Label(
                    "Зарплата",
                    systemImage:
                        "rublesign.circle"
                )
            }
            
            
            SettingsRootView(
                store:
                    store,
                absenceStore:
                    absenceStore,
                calendarSync:
                    calendarSync
            )
            .tabItem {
                
                Label(
                    "Ещё",
                    systemImage:
                        "ellipsis.circle"
                )
            }
        }
        .environmentObject(
            store
        )
    }
}
