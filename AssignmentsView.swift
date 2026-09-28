import SwiftUI
import UniformTypeIdentifiers


private enum AssignmentsSection: String, CaseIterable, Identifiable {
    case flights = "Полёты"
    case workPlan = "План работ"

    var id: String { rawValue }
}


struct AssignmentsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    @State private var section: AssignmentsSection = .flights

    var body: some View {
        VStack(spacing: 0) {
            Picker("Назначения", selection: $section) {
                ForEach(AssignmentsSection.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            switch section {
            case .flights:
                AssignmentFlightsView(
                    store: store,
                    planStore: planStore
                )
            case .workPlan:
                AssignmentWorkPlanView(
                    store: store,
                    planStore: planStore
                )
            }
        }
        .onChange(of: store.flights) { _, flights in
            planStore.removeFlightsSuperseded(by: flights)
        }
    }
}


private struct AssignmentFlightsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    @State private var showPlanImporter = false
    @State private var showPlanList = false
    @State private var isRefreshing = false
    @State private var message = ""
    @State private var showMessage = false

    private var visiblePlan: [AssignmentPlanItem] {
        planStore.visibleItems(actualFlights: store.flights)
    }

    private var visiblePlanFlights: [AssignmentPlanItem] {
        visiblePlan.filter(\.isFlightLike)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    showPlanList = true
                } label: {
                    Label(
                        "План: \(visiblePlanFlights.count)",
                        systemImage: "calendar"
                    )
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 8)

                Button {
                    refreshCalendar()
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Label("Обновить план", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshing)

                Menu {
                    Button {
                        showPlanImporter = true
                    } label: {
                        Label(
                            "Импорт плана (текущий / перспективный)",
                            systemImage: "doc.badge.plus"
                        )
                    }

                    Button {
                        showPlanList = true
                    } label: {
                        Label(
                            "Открыть импортированный план",
                            systemImage: "list.bullet"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("Действия с планом")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            FlightsView(store: store)
        }
        .fileImporter(
            isPresented: $showPlanImporter,
            allowedContentTypes: [
                .pdf,
                UTType(filenameExtension: "ics") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }

                let count = try planStore.importPlanFile(
                    url: url,
                    actualFlights: store.flights
                )
                message = "Импортировано назначений: \(count). План из файла сохранён как текущий/перспективный и будет вытесняться более актуальным подписным календарём или фактической историей полётов."
                showMessage = true
            } catch {
                message = error.localizedDescription
                showMessage = true
            }
        }
        .sheet(isPresented: $showPlanList) {
            PlanAssignmentsListView(
                store: store,
                planStore: planStore
            )
        }
        .alert("План полётов", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
    }

    private func refreshCalendar() {
        guard planStore.hasCalendarURL else {
            message = "Сначала открой «Ещё» → «План полётов» и вставь ссылку подписного календаря."
            showMessage = true
            return
        }

        isRefreshing = true
        Task {
            do {
                let count = try await planStore.refreshSubscribedCalendar(
                    actualFlights: store.flights
                )
                message = "План обновлён. Получено назначений: \(count). Фактические рейсы из истории имеют приоритет и в план повторно не добавляются."
            } catch {
                message = error.localizedDescription
            }
            isRefreshing = false
            showMessage = true
        }
    }
}


private struct PlanAssignmentsListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    private var items: [AssignmentPlanItem] {
        planStore.visibleItems(actualFlights: store.flights)
    }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        "План пока не импортирован",
                        systemImage: "calendar.badge.plus",
                        description: Text(
                            "Обнови подписной календарь или импортируй текущий/перспективный план из файла."
                        )
                    )
                } else {
                    ForEach(items) { item in
                        PlanAssignmentRow(item: item)
                    }
                }
            }
            .navigationTitle("Импортированный план")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}


private struct PlanAssignmentRow: View {
    let item: AssignmentPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(item.kind == .passenger ? .orange : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.source.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDate(item.start))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(timeRange)
                    .font(.caption.monospacedDigit())
                if item.durationMinutes > 0, item.kind != .dayOff {
                    Text(timeText(item.durationMinutes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch item.kind {
        case .flight: return "airplane"
        case .passenger: return "person.crop.circle.badge.checkmark"
        case .ground: return "briefcase"
        case .dayOff: return "moon.zzz"
        }
    }

    private var title: String {
        if let number = item.flightNumber {
            return item.kind == .passenger ? "\(number) · пассажир" : number
        }
        return item.title
    }

    private var subtitle: String {
        if let departure = item.departure,
           let arrival = item.arrival {
            let aircraft = item.aircraft.map { " · \($0)" } ?? ""
            return "\(departure) → \(arrival)\(aircraft)"
        }
        return item.title
    }

    private var timeRange: String {
        if item.kind == .dayOff {
            return "Выходной"
        }
        return "\(formatClock(item.start)) – \(formatClock(item.end))"
    }
}


private struct AssignmentWorkPlanView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    @State private var showAdd = false
    @State private var showImageImporter = false
    @State private var showVideoImporter = false
    @State private var isImporting = false
    @State private var message = ""
    @State private var showMessage = false

    private var plannedGround: [AssignmentPlanItem] {
        planStore.visibleGroundItems(actualFlights: store.flights)
    }

    private var storedEvents: [WorkEvent] {
        store.workEvents.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            List {
                if !plannedGround.isEmpty {
                    Section("Текущий / перспективный план") {
                        ForEach(plannedGround) { item in
                            PlanAssignmentRow(item: item)
                        }
                    }
                }

                Section("Сохранённый план работ") {
                    if storedEvents.isEmpty {
                        Text("Старых назначений пока нет. Их можно добавить вручную, из фото или из видео.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(storedEvents) { event in
                            WorkEventRow(event: event)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        store.deleteWorkEvent(id: event.id)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("План работ")
            .toolbar {
                Menu {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Добавить вручную", systemImage: "plus")
                    }

                    Button {
                        showImageImporter = true
                    } label: {
                        Label("Импорт фото", systemImage: "photo")
                    }

                    Button {
                        showVideoImporter = true
                    } label: {
                        Label("Импорт видео", systemImage: "video")
                    }
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .disabled(isImporting)
            }
            .sheet(isPresented: $showAdd) {
                AddWorkEventView { event in
                    store.addWorkEvent(event)
                }
            }
            .fileImporter(
                isPresented: $showImageImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                handleMedia(result: result, isVideo: false)
            }
            .fileImporter(
                isPresented: $showVideoImporter,
                allowedContentTypes: [.movie],
                allowsMultipleSelection: false
            ) { result in
                handleMedia(result: result, isVideo: true)
            }
            .alert("Импорт плана работ", isPresented: $showMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(message)
            }
        }
    }

    private func handleMedia(
        result: Result<[URL], Error>,
        isVideo: Bool
    ) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource()
            isImporting = true

            Task {
                defer {
                    if access { url.stopAccessingSecurityScopedResource() }
                    isImporting = false
                }

                do {
                    let events = try isVideo
                        ? WorkPlanMediaImporter.parseVideo(url: url)
                        : WorkPlanMediaImporter.parseImage(url: url)
                    let imported = store.importWorkEvents(events)
                    message = "Распознано: \(events.count). Добавлено: \(imported.added). Уже были в приложении: \(imported.duplicates)."
                } catch {
                    message = error.localizedDescription
                }
                showMessage = true
            }
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }
}
