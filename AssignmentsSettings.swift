import SwiftUI


struct SettingsRootV116View: View {
    @ObservedObject var store: AppStore
    @ObservedObject var absenceStore: AbsenceStore
    @ObservedObject var calendarSync: ProductionCalendarSyncModel
    @ObservedObject var planStore: AssignmentPlanStore

    @StateObject private var flightNormStore = FlightNormStore()

    var body: some View {
        NavigationStack {
            List {
                Section("Работа") {
                    NavigationLink {
                        AbsencesListView(store: absenceStore)
                    } label: {
                        HStack {
                            Label(
                                "Отсутствия",
                                systemImage: "calendar.badge.minus"
                            )
                            Spacer()
                            Text(String(absenceStore.absences.count))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Настройки") {
                    NavigationLink {
                        PilotPlanSettingsView(planStore: planStore)
                    } label: {
                        HStack {
                            Label(
                                "План полётов",
                                systemImage: "airplane.circle"
                            )
                            Spacer()
                            Text(planStore.hasCalendarURL ? "Настроен" : "Не настроен")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        ProductionCalendarSettingsView(
                            calendarSync: calendarSync
                        )
                    } label: {
                        Label(
                            "Производственный календарь",
                            systemImage: "calendar.badge.checkmark"
                        )
                    }
                }

                Section("База") {
                    NavigationLink {
                        FlightNormsView(store: flightNormStore)
                    } label: {
                        HStack {
                            Label(
                                "Расчётное время",
                                systemImage: "tablecells"
                            )
                            Spacer()
                            Text(String(flightNormStore.versions.count))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Легов")
                        Spacer()
                        Text(String(store.flights.count))
                    }

                    HStack {
                        Text("Полётных смен")
                        Spacer()
                        Text(String(store.duties.count))
                    }

                    HStack {
                        Text("Назначений плана")
                        Spacer()
                        Text(
                            String(
                                planStore.visibleItems(
                                    actualFlights: store.flights
                                ).count
                            )
                        )
                    }
                }
            }
            .navigationTitle("Ещё")
        }
    }
}


private struct PilotPlanSettingsView: View {
    @ObservedObject var planStore: AssignmentPlanStore

    @AppStorage(AssignmentPlanStore.calendarURLKey)
    private var calendarURL = ""

    @State private var draftURL = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                TextField(
                    "https://…/calendar.ics",
                    text: $draftURL,
                    axis: .vertical
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .lineLimit(2...4)

                Button("Сохранить ссылку") {
                    saveURL()
                }
                .disabled(
                    draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                if !calendarURL.isEmpty {
                    Button("Удалить ссылку", role: .destructive) {
                        calendarURL = ""
                        draftURL = ""
                        message = "Ссылка удалена. Уже импортированный план сохранён."
                    }
                }
            } header: {
                Text("Подписной календарь")
            } footer: {
                Text(
                    "Ссылка сохраняется только в настройках приложения и не зашивается в исходный код. Обновление запускается вручную кнопкой «Обновить план» во вкладке «Назначения» → «Полёты»."
                )
            }

            Section("Состояние") {
                LabeledContent(
                    "Ссылка",
                    value: planStore.hasCalendarURL ? "Настроена" : "Не настроена"
                )

                if let date = planStore.lastCalendarRefresh {
                    LabeledContent(
                        "Последнее обновление",
                        value: formatDateTime(date)
                    )
                }

                if let date = planStore.lastFileImport {
                    LabeledContent(
                        "Последний импорт файла",
                        value: formatDateTime(date)
                    )
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("План полётов")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draftURL = calendarURL
        }
    }

    private func saveURL() {
        let trimmed = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            message = "Проверь ссылку: нужен полный адрес http/https."
            return
        }

        calendarURL = url.absoluteString
        draftURL = calendarURL
        message = "Ссылка сохранена."
    }
}
