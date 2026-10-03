import SwiftUI
import UniformTypeIdentifiers


private enum AssignmentsSection: String, CaseIterable, Identifiable {
    case flights = "Полёты"
    case currentPlan = "Текущий"
    case importedPlan = "Перспективный"
    case workPlan = "План работ"

    var id: String { rawValue }
}


struct AssignmentsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore

    @State private var section: AssignmentsSection = .flights

    var body: some View {
        // Одна общая навигационная панель на всю вкладку: в iPadOS 26
        // вкладки приложения плавают сверху, и только NavigationStack
        // опускает содержимое (переключатель разделов) под них.
        // Разделы ниже своих NavigationStack не создают — их toolbar
        // попадает в эту общую панель.
        NavigationStack {
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
                    CurrentPlanAssignmentsView(store: store, planStore: planStore)
                case .importedPlan:
                    ImportedPlanAssignmentsView(store: store, planStore: planStore)
                case .workPlan:
                    AccordWorkPlanView(store: store)
                }
            }
            .toolbarTitleDisplayMode(.inline)
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
                    "История полётов · \(store.importedFlightHistoryCount) легов",
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
                .disabled(store.importedFlightHistoryCount == 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()
            FlightsView(store: store)
        }
        .alert(
            "Удалить импортированную историю полётов?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                store.deleteImportedFlightHistory()
            }
        } message: {
            Text(
                "Будут удалены только \(store.importedFlightHistoryCount) легов из импортированной истории. Ручные задания Manual, текущий план, импортированный план и план работ останутся на месте."
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
        Group {
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
                            PlanAssignmentRowV119(
                                item: item,
                                status: planStore.historySupersedes(
                                    item,
                                    actualFlights: store.flights
                                ) ? "Есть в истории полётов · факт имеет приоритет" : nil,
                                statusColor: .green,
                                conflictText: nil
                            )
                        }
                    }
                }
            }
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
        case .working:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .notChecked:
            return planStore.hasCalendarURL ? "questionmark.circle.fill" : "link.badge.plus"
        }
    }

    private var statusColor: Color {
        switch planStore.calendarHealth {
        case .working:
            return .green
        case .failed:
            return .red
        case .notChecked:
            return .orange
        }
    }

    private var statusTitle: String {
        if !planStore.hasCalendarURL {
            return "Ссылка не настроена"
        }
        switch planStore.calendarHealth {
        case .working:
            return "Подписной календарь работает"
        case .failed:
            return "Календарь недоступен"
        case .notChecked:
            return "Ссылка сохранена, но ещё не проверена"
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
    @ObservedObject private var archiveStore = AssignmentImportArchiveStore.shared

    @State private var showImporter = false
    @State private var showDeleteConfirmation = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var pendingDraft: AssignmentImportDraft?

    private var items: [AssignmentPlanItem] {
        planStore.sourceItems(
            .importedFile,
            actualFlights: store.flights,
            hideSuperseded: false
        )
    }

    var body: some View {
        Group {
            List {
                Section {
                    Text(
                        "Перспективный PDF сначала разбирается во временный план. Если назначения конфликтуют, приложение попросит разрешить конфликты до сохранения."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if archiveStore.hadConflicts,
                   archiveStore.latestArchive != nil {
                    Section("Импорт") {
                        Button {
                            reopenConflictResolution()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Были конфликты")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Открыть предыдущие решения и изменить их")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Импортированный план · \(items.count)") {
                    if items.isEmpty {
                        Text("План из файла пока не импортирован.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            PlanAssignmentRowV119(
                                item: item,
                                status: status(for: item),
                                statusColor: statusColor(for: item),
                                conflictText: nil
                            )
                        }
                    }
                }
            }
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
            .sheet(item: $pendingDraft) { draft in
                AssignmentConflictResolverView(
                    draft: draft,
                    onCancel: {
                        pendingDraft = nil
                    },
                    onSave: {
                        saveDraft(draft)
                    }
                )
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
                    archiveStore.clear()
                }
            } message: {
                Text(
                    "Удалятся только файлы текущего/перспективного плана и сохранённые решения его конфликтов. Подписной календарь и история полётов останутся без изменений."
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
            guard !urls.isEmpty else { return }

            var accesses: [(URL, Bool)] = []
            for url in urls {
                accesses.append((url, url.startAccessingSecurityScopedResource()))
            }
            defer {
                for (url, didAccess) in accesses where didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let draft = try AssignmentImportDraft.parse(urls: urls)
            if draft.unresolvedConflictCount > 0 {
                pendingDraft = draft
            } else {
                let count = try draft.commit(
                    to: planStore,
                    actualFlights: store.flights
                )
                message = "Импорт завершён. Сохранено назначений: \(count). Конфликтов не обнаружено."
                showMessage = true
            }
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }

    private func saveDraft(_ draft: AssignmentImportDraft) {
        do {
            let count = try draft.commit(
                to: planStore,
                actualFlights: store.flights
            )
            pendingDraft = nil
            message = "План сохранён. Назначений: \(count). Все конфликты разрешены."
            showMessage = true
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }

    private func reopenConflictResolution() {
        guard let archive = archiveStore.latestArchive else { return }
        pendingDraft = AssignmentImportDraft(archive: archive)
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
        Group {
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
                    if access {
                        url.stopAccessingSecurityScopedResource()
                    }
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
