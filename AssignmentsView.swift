import SwiftUI
import UniformTypeIdentifiers


private enum AssignmentsSection: String, CaseIterable, Identifiable {
    case flights = "Полёты"
    case currentPlan = "Текущий"
    case importedPlan = "Перспективный"
    case workPlan = "План работ"
    case test = "Test"

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
                case .test:
                    PerspectivePlanTestView()
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
                        PerspectivePlanMonthCardsView(
                            items: items,
                            status: status(for:),
                            statusColor: statusColor(for:)
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .listRowBackground(Color.clear)
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


private struct PerspectivePlanMonthCardsView: View {
    let items: [AssignmentPlanItem]
    let status: (AssignmentPlanItem) -> String?
    let statusColor: (AssignmentPlanItem) -> Color

    private struct MonthSection: Identifiable {
        let key: Int
        let primary: [AssignmentPlanItem]
        let carryovers: [AssignmentPlanItem]

        var id: Int { key }
    }

    private struct AssignmentGroup: Identifiable {
        let id: String
        let items: [AssignmentPlanItem]
        let start: Date
    }

    var body: some View {
        VStack(spacing: 16) {
            ForEach(monthSections) { month in
                monthCard(month)
            }
        }
        .padding(.vertical, 2)
    }

    private var monthSections: [MonthSection] {
        var keys = Set(items.map { sourceMonthKey($0) })

        for item in items where item.isAllDay {
            let includedEnd = moscowCalendar.date(byAdding: .day, value: -1, to: item.end) ?? item.end
            var cursor = monthStart(for: item.start)
            let last = monthStart(for: includedEnd)
            var guardCount = 0
            while cursor <= last, guardCount < 24 {
                keys.insert(monthKey(cursor))
                guard let next = moscowCalendar.date(byAdding: .month, value: 1, to: cursor) else {
                    break
                }
                cursor = next
                guardCount += 1
            }
        }

        return keys.sorted().map { key in
            let start = dateForMonthKey(key)
            let end = start.flatMap { moscowCalendar.date(byAdding: .month, value: 1, to: $0) }

            let primary = items
                .filter { sourceMonthKey($0) == key }
                .sorted { sourceStart($0) < sourceStart($1) }

            let carryovers: [AssignmentPlanItem]
            if let start, let end {
                carryovers = items
                    .filter { item in
                        item.isAllDay
                            && sourceMonthKey(item) < key
                            && item.start < end
                            && item.end > start
                    }
                    .sorted { $0.start < $1.start }
            } else {
                carryovers = []
            }

            return MonthSection(key: key, primary: primary, carryovers: carryovers)
        }
    }

    @ViewBuilder
    private func monthCard(_ month: MonthSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthTitle(month.key))
                    .font(.headline)
                Spacer()
                Text("\(month.primary.count) назначений")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !month.carryovers.isEmpty {
                VStack(spacing: 5) {
                    ForEach(month.carryovers) { item in
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.turn.down.right")
                            Text(carryoverText(item))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
            }

            ForEach(assignmentGroups(month.primary)) { group in
                VStack(spacing: 0) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        PlanAssignmentRowV119(
                            item: item,
                            status: status(item),
                            statusColor: statusColor(item),
                            conflictText: nil,
                            perspectiveStyle: true
                        )
                        .padding(.horizontal, 10)

                        if index < group.items.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.45), lineWidth: 0.7)
        }
    }

    private func assignmentGroups(_ source: [AssignmentPlanItem]) -> [AssignmentGroup] {
        var buckets: [String: [AssignmentPlanItem]] = [:]
        var order: [String] = []

        for item in source.sorted(by: { sourceStart($0) < sourceStart($1) }) {
            let linkedID = AssignmentV119MetadataCodec.metadata(from: item.detail)?.linkedGroupID
            let key = linkedID ?? "item|\(item.id)"
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key, default: []].append(item)
        }

        return order.compactMap { key in
            guard let values = buckets[key], !values.isEmpty else { return nil }
            let sorted = values.sorted { sourceStart($0) < sourceStart($1) }
            return AssignmentGroup(
                id: key,
                items: sorted,
                start: sourceStart(sorted[0])
            )
        }
        .sorted { $0.start < $1.start }
    }

    private func sourceStart(_ item: AssignmentPlanItem) -> Date {
        AssignmentV119MetadataCodec.metadata(from: item.detail)?.sourceStart ?? item.start
    }

    private func sourceMonthKey(_ item: AssignmentPlanItem) -> Int {
        monthKey(sourceStart(item))
    }

    private func monthKey(_ date: Date) -> Int {
        let parts = moscowCalendar.dateComponents([.year, .month], from: date)
        return (parts.year ?? 0) * 100 + (parts.month ?? 0)
    }

    private func monthStart(for date: Date) -> Date {
        let parts = moscowCalendar.dateComponents([.year, .month], from: date)
        return moscowCalendar.date(
            from: DateComponents(
                timeZone: moscowTimeZone,
                year: parts.year,
                month: parts.month,
                day: 1
            )
        ) ?? date
    }

    private func dateForMonthKey(_ key: Int) -> Date? {
        let year = key / 100
        let month = key % 100
        return moscowCalendar.date(
            from: DateComponents(
                timeZone: moscowTimeZone,
                year: year,
                month: month,
                day: 1
            )
        )
    }

    private func monthTitle(_ key: Int) -> String {
        guard let date = dateForMonthKey(key) else { return String(key) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "LLLL yyyy"
        let text = formatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func carryoverText(_ item: AssignmentPlanItem) -> String {
        let includedEnd = moscowCalendar.date(byAdding: .day, value: -1, to: item.end) ?? item.end
        return "\(item.title) · продолжение до \(fullDate(includedEnd))"
    }

    private func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}


private struct PerspectivePlanTestView: View {
    private let items: [AssignmentPlanItem] = Self.makeItems()

    var body: some View {
        List {
            Section {
                Text(
                    "Искусственный пример для проверки компоновки: сначала рабочий рейс, затем перемещение в качестве пассажира. Данные в основной план не сохраняются."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            PerspectivePlanMonthCardsView(
                items: items,
                status: { _ in nil },
                statusColor: { _ in .secondary }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .listRowBackground(Color.clear)
        }
    }

    private static func makeItems() -> [AssignmentPlanItem] {
        let sourceFlightStart = date(day: 3, hour: 10, minute: 0)
        let sourceFlightEnd = date(day: 3, hour: 13, minute: 20)
        let dutyStart = date(day: 3, hour: 9, minute: 0)
        let dutyEnd = date(day: 3, hour: 13, minute: 50)
        let passengerSourceStart = date(day: 3, hour: 15, minute: 10)
        let passengerEnd = date(day: 3, hour: 17, minute: 0)
        let passengerStart = date(day: 3, hour: 14, minute: 30)
        let groupID = "test-working-then-passenger"

        let flightMetadata = AssignmentV119Metadata(
            sourceStart: sourceFlightStart,
            sourceEnd: sourceFlightEnd,
            passengerBasis: nil,
            passengerMovementMinutes: nil,
            linkedGroupID: groupID,
            waitingMinutes: nil,
            subsequentDutyReductionMinutes: nil,
            linkedSequenceMinutes: nil,
            legs: [
                AssignmentV119LegMetadata(
                    flightNumber: "SU 1000",
                    departure: "Шереметьево (C)",
                    arrival: "Самара (KUF)",
                    aircraft: "A320"
                )
            ]
        )

        let passengerMinutes = max(
            0,
            Int(passengerEnd.timeIntervalSince(passengerStart) / 60)
        )
        let waiting = max(0, Int(passengerStart.timeIntervalSince(dutyEnd) / 60))
        let passengerMetadata = AssignmentV119Metadata(
            sourceStart: passengerSourceStart,
            sourceEnd: passengerEnd,
            passengerBasis: nil,
            passengerMovementMinutes: passengerMinutes,
            linkedGroupID: groupID,
            waitingMinutes: waiting,
            subsequentDutyReductionMinutes: nil,
            linkedSequenceMinutes: max(0, Int(dutyEnd.timeIntervalSince(dutyStart) / 60))
                + waiting
                + passengerMinutes,
            legs: [
                AssignmentV119LegMetadata(
                    flightNumber: "SU 1001",
                    departure: "Самара (KUF)",
                    arrival: "Шереметьево (B)",
                    aircraft: "A320"
                )
            ]
        )

        let flightLeg = AssignmentPlanLeg(
            id: "test-flight-leg",
            flightNumber: "SU 1000",
            role: .workingPilot,
            departure: "Шереметьево (C)",
            arrival: "Самара (KUF)"
        )
        let passengerLeg = AssignmentPlanLeg(
            id: "test-passenger-leg",
            flightNumber: "SU 1001",
            role: .passenger,
            departure: "Самара (KUF)",
            arrival: "Шереметьево (B)"
        )

        let flight = AssignmentPlanItem(
            id: "test-flight",
            source: .importedFile,
            externalUID: nil,
            kind: .flight,
            start: dutyStart,
            end: dutyEnd,
            title: "Полётная смена",
            flightNumber: "SU 1000",
            flightNumbers: ["SU 1000"],
            departure: "Шереметьево (C)",
            arrival: "Самара (KUF)",
            aircraft: "A320",
            assignmentGroup: "Шереметьево (C) - Самара (KUF)",
            importedAt: Date(),
            detail: AssignmentV119MetadataCodec.encode(
                humanDetail: nil,
                metadata: flightMetadata
            ),
            flightLegs: [flightLeg],
            plannedFlightMinutes: nil,
            isAllDayRange: false,
            originMonthKey: 202610
        )

        let passenger = AssignmentPlanItem(
            id: "test-passenger",
            source: .importedFile,
            externalUID: nil,
            kind: .passenger,
            start: passengerStart,
            end: passengerEnd,
            title: "Перелёт пассажиром",
            flightNumber: "SU 1001",
            flightNumbers: ["SU 1001"],
            departure: "Самара (KUF)",
            arrival: "Шереметьево (B)",
            aircraft: "A320",
            assignmentGroup: "Самара (KUF) - Шереметьево (B)",
            importedAt: Date(),
            detail: AssignmentV119MetadataCodec.encode(
                humanDetail: nil,
                metadata: passengerMetadata
            ),
            flightLegs: [passengerLeg],
            plannedFlightMinutes: nil,
            isAllDayRange: false,
            originMonthKey: 202610
        )

        return [flight, passenger]
    }

    private static func date(day: Int, hour: Int, minute: Int) -> Date {
        moscowCalendar.date(
            from: DateComponents(
                timeZone: moscowTimeZone,
                year: 2026,
                month: 10,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? Date()
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
