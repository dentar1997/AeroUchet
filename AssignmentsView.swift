import SwiftUI
import UniformTypeIdentifiers


private enum AssignmentsSection: String, CaseIterable, Identifiable {
    case flights = "Полёты"
    case currentPlan = "Текущий план"
    case importedPlan = "Импортированный план"
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
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            switch section {
            case .flights:
                FlightHistoryAssignmentsView(store: store)
            case .currentPlan:
                CurrentPlanAssignmentsView(
                    store: store,
                    planStore: planStore
                )
            case .importedPlan:
                ImportedPlanAssignmentsView(
                    store: store,
                    planStore: planStore
                )
            case .workPlan:
                AccordWorkPlanView(store: store)
            }
        }
    }
}


private struct FlightHistoryAssignmentsView: View {
    @ObservedObject var store: AppStore
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label(
                    "История полётов · \(store.flights.count) легов",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.subheadline.weight(.semibold))

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Удалить историю", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(store.flights.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            FlightsView(store: store)
        }
        .alert("Удалить всю историю полётов?", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                store.deleteAllFlightHistory()
            }
        } message: {
            Text(
                "Будут удалены все \(store.flights.count) импортированных и вручную сохранённых легов. Текущий план, импортированный план и план работ останутся на месте."
            )
        }
    }
}


private struct CurrentPlanAssignmentsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    @State private var isRefreshing = false
    @State private var showDeleteConfirmation = false
    @State private var message = ""
    @State private var showMessage = false

    private var items: [AssignmentPlanItem] {
        planStore.sourceItems(
            .subscribedCalendar,
            actualFlights: store.flights,
            hideSuperseded: false
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(statusTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(statusSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                } header: {
                    Text("Подписной календарь")
                }

                Section("Назначения · \(items.count)") {
                    if items.isEmpty {
                        Text(
                            "Текущий план пока пуст. Нажми «Обновить», чтобы получить назначения из подписного календаря."
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            PlanAssignmentRow(
                                item: item,
                                status: planStore.historySupersedes(
                                    item,
                                    actualFlights: store.flights
                                ) ? "Есть в истории полётов · факт имеет приоритет" : nil,
                                statusColor: .green
                            )
                        }
                    }
                }
            }
            .navigationTitle("Текущий план")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        refreshCalendar()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Label("Обновить", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(items.isEmpty)
                    .accessibilityLabel("Удалить текущий план")
                }
            }
            .alert("Текущий план", isPresented: $showMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(message)
            }
            .alert("Удалить текущий план?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    planStore.deleteCurrentPlan()
                }
            } message: {
                Text(
                    "Удалятся только назначения, полученные из подписного календаря. История полётов, импортированный перспективный план и план работ не изменятся."
                )
            }
        }
    }

    private var statusIcon: String {
        switch planStore.calendarHealth {
        case .working: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .notChecked: return planStore.hasCalendarURL ? "questionmark.circle.fill" : "link.badge.plus"
        }
    }

    private var statusColor: Color {
        switch planStore.calendarHealth {
        case .working: return .green
        case .failed: return .red
        case .notChecked: return .orange
        }
    }

    private var statusTitle: String {
        if !planStore.hasCalendarURL {
            return "Ссылка не настроена"
        }
        switch planStore.calendarHealth {
        case .working: return "Подписной календарь работает"
        case .failed: return "Календарь недоступен"
        case .notChecked: return "Ссылка сохранена, но ещё не проверена"
        }
    }

    private var statusSubtitle: String {
        if let date = planStore.lastCalendarRefresh {
            return "Последнее обновление: \(formatDateTime(date))"
        }
        return "Ссылку можно настроить в «Ещё» → «План полётов»."
    }

    private func refreshCalendar() {
        guard planStore.hasCalendarURL else {
            message = "Сначала открой «Ещё» → «План полётов» и сохрани ссылку подписного календаря."
            showMessage = true
            return
        }

        isRefreshing = true
        Task {
            do {
                let count = try await planStore.refreshSubscribedCalendar(
                    actualFlights: store.flights
                )
                message = "Текущий план обновлён. Получено назначений: \(count)."
            } catch {
                message = error.localizedDescription
            }
            isRefreshing = false
            showMessage = true
        }
    }
}


private struct ImportedPlanAssignmentsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    @State private var showImporter = false
    @State private var showDeleteConfirmation = false
    @State private var message = ""
    @State private var showMessage = false

    private var items: [AssignmentPlanItem] {
        planStore.sourceItems(
            .importedFile,
            actualFlights: store.flights,
            hideSuperseded: false
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "Сюда импортируется файл текущего или перспективного плана. Он хранится отдельно от подписного календаря, чтобы можно было проверить оба источника независимо."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Импортированный план · \(items.count)") {
                    if items.isEmpty {
                        Text("План из файла пока не импортирован.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            PlanAssignmentRow(
                                item: item,
                                status: status(for: item),
                                statusColor: statusColor(for: item)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Импортированный план")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Импорт", systemImage: "doc.badge.plus")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(items.isEmpty)
                    .accessibilityLabel("Удалить импортированный план")
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [
                    .pdf,
                    UTType(filenameExtension: "ics") ?? .data
                ],
                allowsMultipleSelection: true
            ) { result in
                importFiles(result)
            }
            .alert("Импортированный план", isPresented: $showMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(message)
            }
            .alert("Удалить импортированный план?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    planStore.deleteImportedPlan()
                }
            } message: {
                Text(
                    "Удалятся только файлы текущего/перспективного плана. Подписной календарь и история полётов останутся без изменений."
                )
            }
        }
    }

    private func status(for item: AssignmentPlanItem) -> String? {
        if planStore.historySupersedes(item, actualFlights: store.flights) {
            return "Есть в истории полётов · используется факт"
        }
        if planStore.calendarOverlap(for: item) {
            return "Совпадает с текущим планом · используется календарь"
        }
        return nil
    }

    private func statusColor(for item: AssignmentPlanItem) -> Color {
        if planStore.historySupersedes(item, actualFlights: store.flights) {
            return .green
        }
        if planStore.calendarOverlap(for: item) {
            return .blue
        }
        return .secondary
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            var total = 0
            var succeeded = 0
            var failures: [String] = []

            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    total += try planStore.importPlanFile(
                        url: url,
                        actualFlights: store.flights
                    )
                    succeeded += 1
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            if failures.isEmpty {
                message = "Импортировано файлов: \(succeeded). Назначений: \(total)."
            } else {
                message = "Импортировано файлов: \(succeeded) из \(urls.count). Назначений: \(total). \(failures.joined(separator: " "))"
            }
            showMessage = true
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }
}


private struct AccordWorkPlanView: View {
    @ObservedObject var store: AppStore

    @State private var showAdd = false
    @State private var showImageImporter = false
    @State private var showVideoImporter = false
    @State private var showDeleteConfirmation = false
    @State private var isImporting = false
    @State private var message = ""
    @State private var showMessage = false

    private var storedEvents: [WorkEvent] {
        store.workEvents.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "План работ из «Аккорда» хранится отдельно от текущего и перспективного плана. Пока источники не объединяем — сначала проверяем импорт и чтение каждого независимо."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Аккорд · \(storedEvents.count)") {
                    if storedEvents.isEmpty {
                        Text("Назначений пока нет. Их можно добавить вручную, из фото или из видео.")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(storedEvents.isEmpty)
                    .accessibilityLabel("Удалить план работ")
                }
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
            .alert("Удалить весь план работ?", isPresented: $showDeleteConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    store.deleteAllWorkPlanEvents()
                }
            } message: {
                Text(
                    "Будут удалены только назначения плана работ из «Аккорда» и добавленные вручную наземные события. История полётов и оба плана полётов не изменятся."
                )
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


private struct PlanAssignmentRow: View {
    let item: AssignmentPlanItem
    var status: String?
    var statusColor: Color = .secondary

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

                if let status {
                    Label(status, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                }
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
        if let group = item.assignmentGroup, !group.isEmpty {
            let aircraft = item.aircraft.map { " · \($0)" } ?? ""
            return group + aircraft
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
