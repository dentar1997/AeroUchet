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
                            Label("Отсутствия", systemImage: "calendar.badge.minus")
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
                            Label("План полётов", systemImage: "airplane.circle")
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(planStatusColor)
                                    .frame(width: 8, height: 8)
                                Text(planStatusText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        EventAppearanceSettingsView()
                    } label: {
                        Label(
                            "Настройка событий",
                            systemImage: "paintpalette.fill"
                        )
                    }

                    NavigationLink {
                        ProductionCalendarSettingsView(calendarSync: calendarSync)
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
                            Label("Расчётное время", systemImage: "tablecells")
                            Spacer()
                            Text(String(flightNormStore.versions.count))
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        AircraftReferenceSettingsV129View()
                    } label: {
                        HStack {
                            Label("Воздушные суда", systemImage: "airplane")
                            Spacer()
                            Text(String(AircraftReferenceStoreV129.shared.aircraft.count))
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        FlightScheduleSettingsV129View()
                    } label: {
                        HStack {
                            Label("Расписание рейсов", systemImage: "calendar.badge.clock")
                            Spacer()
                            Text(String(FlightScheduleStoreV129.shared.entries.count))
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Легов истории", value: String(store.flights.count))
                    LabeledContent("Полётных смен", value: String(store.duties.count))
                    LabeledContent(
                        "Текущий план",
                        value: String(planStore.calendarSourceItems.count)
                    )
                    LabeledContent(
                        "Импортированный план",
                        value: String(planStore.importedSourceItems.count)
                    )
                    LabeledContent("План работ", value: String(store.workEvents.count))
                }
            }
            .navigationTitle("Ещё")
        }
    }

    private var planStatusColor: Color {
        guard planStore.hasCalendarURL else { return .secondary }
        switch planStore.calendarHealth {
        case .working: return .green
        case .failed: return .red
        case .notChecked: return .orange
        }
    }

    private var planStatusText: String {
        guard planStore.hasCalendarURL else { return "Не настроен" }
        switch planStore.calendarHealth {
        case .working: return "Работает"
        case .failed: return "Ошибка"
        case .notChecked: return "Не проверен"
        }
    }
}


private struct PilotPlanSettingsView: View {
    @ObservedObject var planStore: AssignmentPlanStore

    @AppStorage(AssignmentPlanStore.calendarURLKey)
    private var calendarURL = ""

    @State private var draftURL = ""
    @State private var isChecking = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.14))
                            .frame(width: 38, height: 38)
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                            .font(.title3.weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(.headline)
                        Text(statusSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Состояние")
            }

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

                Button {
                    saveAndCheck()
                } label: {
                    HStack {
                        if isChecking {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text(isChecking ? "Проверяем…" : "Сохранить и проверить ссылку")
                    }
                }
                .disabled(
                    isChecking
                        || draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                if !calendarURL.isEmpty {
                    Button {
                        checkSavedURL()
                    } label: {
                        Label("Проверить сейчас", systemImage: "arrow.clockwise")
                    }
                    .disabled(isChecking)

                    Button("Удалить ссылку", role: .destructive) {
                        calendarURL = ""
                        draftURL = ""
                        planStore.resetCalendarValidation()
                        message = "Ссылка удалена. Уже загруженные планы сохранены отдельно."
                    }
                }
            } header: {
                Text("Подписной календарь")
            } footer: {
                Text(
                    "Проверка скачивает календарь и убеждается, что ссылка действительно возвращает читаемые назначения. Сам текущий план обновляется вручную во вкладке «Назначения» → «Текущий план»."
                )
            }

            Section("Данные") {
                LabeledContent(
                    "Назначений текущего плана",
                    value: String(planStore.calendarSourceItems.count)
                )
                LabeledContent(
                    "Назначений из файла",
                    value: String(planStore.importedSourceItems.count)
                )

                if let date = planStore.lastCalendarCheck {
                    LabeledContent("Последняя проверка", value: formatDateTime(date))
                }

                if let date = planStore.lastCalendarRefresh {
                    LabeledContent("Последнее обновление плана", value: formatDateTime(date))
                }

                if let date = planStore.lastFileImport {
                    LabeledContent("Последний импорт файла", value: formatDateTime(date))
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let checkMessage = planStore.calendarCheckMessage {
                    Text(checkMessage)
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

    private var statusColor: Color {
        guard planStore.hasCalendarURL else { return .secondary }
        switch planStore.calendarHealth {
        case .working: return .green
        case .failed: return .red
        case .notChecked: return .orange
        }
    }

    private var statusIcon: String {
        guard planStore.hasCalendarURL else { return "link.badge.plus" }
        switch planStore.calendarHealth {
        case .working: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .notChecked: return "questionmark.circle.fill"
        }
    }

    private var statusTitle: String {
        guard planStore.hasCalendarURL else {
            return "Подписной календарь не настроен"
        }
        switch planStore.calendarHealth {
        case .working: return "Подписной календарь работает"
        case .failed: return "Календарь не прошёл проверку"
        case .notChecked: return "Ссылка сохранена, но не проверена"
        }
    }

    private var statusSubtitle: String {
        if planStore.calendarHealth == .working {
            return "Ссылка отвечает и назначения читаются."
        }
        if planStore.calendarHealth == .failed {
            return planStore.calendarCheckMessage ?? "Не удалось получить назначения."
        }
        return planStore.hasCalendarURL
            ? "Нажми «Проверить сейчас»."
            : "Вставь ссылку подписного ICS-календаря."
    }

    private func saveAndCheck() {
        let trimmed = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            message = "Проверь ссылку: нужен полный адрес http/https."
            return
        }

        calendarURL = url.absoluteString
        draftURL = calendarURL
        planStore.resetCalendarValidation()
        checkSavedURL()
    }

    private func checkSavedURL() {
        guard !isChecking else { return }
        isChecking = true
        message = nil

        Task {
            do {
                let count = try await planStore.validateSubscribedCalendar()
                message = "Проверка пройдена. Ссылка работает, найдено назначений: \(count)."
            } catch {
                message = "Проверка не пройдена: \(error.localizedDescription)"
            }
            isChecking = false
        }
    }
}
