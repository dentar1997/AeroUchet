from pathlib import Path
import re


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'block not found: {label}')
    return text.replace(old, new, 1)

p = Path('AppViews.swift')
s = p.read_text()

# 1. Полёты: единый поиск/фильтр/сортировка и создание задания вместо старого sheet.
start = s.index('struct FlightsView: View {')
end = s.index('// MARK: - Список смен', start)
new_flights = r'''private enum DutySearchField: String, CaseIterable, Identifiable {
    case airport = "Аэропорт / IATA"
    case assignment = "Задание на полёт"
    case date = "Дата"
    case scheduleType = "Вид полёта"
    case flightNumber = "Рейс"
    case registration = "Бортовой номер"
    var id: String { rawValue }
}

private enum DutyFlightCountFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case one = "1 рейс"
    case two = "2 рейса"
    case three = "3 рейса"
    case four = "4 рейса"
    case fourPlus = "4+ рейса"
    var id: String { rawValue }
}

private enum DutySortOrder: String, CaseIterable, Identifiable {
    case newest = "Сначала новые"
    case oldest = "Сначала старые"
    case assignment = "По заданию"
    case route = "По маршруту"
    case flightCount = "По количеству рейсов"
    var id: String { rawValue }
}

struct FlightsView: View {
    @ObservedObject var store: AppStore

    @State private var newDuty: FlightDuty?
    @State private var showSearchTools = false
    @State private var searchField: DutySearchField = .airport
    @State private var searchText = ""
    @State private var flightCountFilter: DutyFlightCountFilter = .all
    @State private var sortOrder: DutySortOrder = .newest

    @State private var showImport = false
    @State private var showImportConfirmation = false
    @State private var showImportResult = false
    @State private var importMessage = ""
    @State private var pendingFlights: [FlightLeg] = []
    @State private var verificationStatus = ""

    private var visibleDuties: [FlightDuty] {
        var values = store.duties.filter { duty in
            matchesCount(duty) && matchesSearch(duty)
        }

        switch sortOrder {
        case .newest:
            values.sort { $0.start > $1.start }
        case .oldest:
            values.sort { $0.start < $1.start }
        case .assignment:
            values.sort {
                ($0.firstLeg.assignmentNumber ?? "")
                    .localizedStandardCompare($1.firstLeg.assignmentNumber ?? "") == .orderedAscending
            }
        case .route:
            values.sort {
                AirportDatabase.routeDisplayName([$0.firstLeg.departure] + $0.legs.map(\.arrival))
                    .localizedStandardCompare(
                        AirportDatabase.routeDisplayName([$1.firstLeg.departure] + $1.legs.map(\.arrival))
                    ) == .orderedAscending
            }
        case .flightCount:
            values.sort {
                if $0.legs.count == $1.legs.count { return $0.start > $1.start }
                return $0.legs.count < $1.legs.count
            }
        }
        return values
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DutiesListView(store: store, duties: visibleDuties)

                if let duty = newDuty {
                    DutyAssignmentOverlay(
                        duty: duty,
                        store: store,
                        isCreating: true,
                        onCreate: { legs in
                            store.addDutyLegs(legs)
                            newDuty = nil
                        },
                        onClose: { newDuty = nil }
                    )
                    .zIndex(10)
                }
            }
            .toolbar {
                Button {
                    showSearchTools = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Поиск, фильтр и сортировка")
                .popover(isPresented: $showSearchTools, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Поиск, фильтр и сортировка")
                            .font(.headline)

                        Picker("Искать по", selection: $searchField) {
                            ForEach(DutySearchField.allCases) { field in
                                Text(field.rawValue).tag(field)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Введите значение", text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        Divider()

                        Picker("Количество рейсов", selection: $flightCountFilter) {
                            ForEach(DutyFlightCountFilter.allCases) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Сортировка", selection: $sortOrder) {
                            ForEach(DutySortOrder.allCases) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Button("Сбросить") {
                                searchText = ""
                                searchField = .airport
                                flightCountFilter = .all
                                sortOrder = .newest
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button("Готово") { showSearchTools = false }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(16)
                    .frame(width: 330)
                    .presentationCompactAdaptation(.popover)
                }

                Button("Импорт истории", systemImage: "square.and.arrow.down") {
                    showImport = true
                }

                Button {
                    newDuty = makeManualDuty()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Новое задание на полёт")
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [UTType(filenameExtension: "xls") ?? .data]
            ) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let checked = try PortalFlightHistory.parse(Data(contentsOf: url))
                    pendingFlights = checked.flights
                    verificationStatus = checked.status
                    showImportConfirmation = true
                } catch {
                    importMessage = error.localizedDescription
                    showImportResult = true
                }
            }
            .alert("Импорт истории рейсов", isPresented: $showImportConfirmation) {
                Button("Отмена", role: .cancel) { pendingFlights = [] }
                Button("Импортировать") {
                    let result = store.importFlights(pendingFlights)
                    importMessage = "Добавлено: \(result.added). Обновлены поля ранее импортированных: \(result.updated). Уже были в приложении: \(pendingFlights.count - result.added)."
                    pendingFlights = []
                    showImportResult = true
                }
            } message: {
                let known = Set(store.flights.map { $0.historyKey })
                let unique = Set(pendingFlights.map { $0.historyKey })
                Text("\(verificationStatus) В файле \(pendingFlights.count) рейсов, новых: \(unique.subtracting(known).count).")
            }
            .alert("История рейсов", isPresented: $showImportResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importMessage)
            }
        }
    }

    private func matchesCount(_ duty: FlightDuty) -> Bool {
        switch flightCountFilter {
        case .all: return true
        case .one: return duty.legs.count == 1
        case .two: return duty.legs.count == 2
        case .three: return duty.legs.count == 3
        case .four: return duty.legs.count == 4
        case .fourPlus: return duty.legs.count >= 4
        }
    }

    private func matchesSearch(_ duty: FlightDuty) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        func contains(_ value: String) -> Bool {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }

        switch searchField {
        case .airport:
            return duty.legs.contains { leg in
                contains(leg.departure)
                    || contains(leg.arrival)
                    || contains(AirportDatabase.displayName(for: leg.departure))
                    || contains(AirportDatabase.displayName(for: leg.arrival))
            }
        case .assignment:
            return contains(duty.firstLeg.assignmentNumber ?? "")
        case .date:
            return contains(formatDate(duty.start))
        case .scheduleType:
            return duty.legs.contains { contains(($0.scheduleType ?? .planned).rawValue) }
        case .flightNumber:
            return duty.legs.contains {
                contains($0.flightNumber) || contains($0.legNumber ?? "")
            }
        case .registration:
            return duty.legs.contains { contains(formattedRegistration($0.registration)) }
        }
    }

    private func nextManualAssignmentNumber() -> String {
        let values = store.flights.compactMap(\.assignmentNumber)
        let manualNumbers = values.compactMap { value -> Int? in
            guard value.hasPrefix("Manual ") else { return nil }
            return Int(value.dropFirst("Manual ".count))
        }
        let next = (manualNumbers.max() ?? 0) + 1
        if next <= 999 {
            return String(format: "Manual %03d", next)
        }

        let overflowNumbers = values.compactMap { value -> Int? in
            guard value.hasPrefix("ManuA ") else { return nil }
            return Int(value.dropFirst("ManuA ".count))
        }
        return String(format: "ManuA %03d", (overflowNumbers.max() ?? 0) + 1)
    }

    private func makeManualDuty() -> FlightDuty {
        let start = Date()
        let engineOn = moscowCalendar.date(byAdding: .minute, value: 60, to: start) ?? start
        let takeoff = moscowCalendar.date(byAdding: .minute, value: 10, to: engineOn) ?? engineOn
        let landing = takeoff
        let engineOff = moscowCalendar.date(byAdding: .minute, value: 10, to: landing) ?? landing
        let workEnd = moscowCalendar.date(byAdding: .minute, value: 30, to: engineOff) ?? engineOff
        let assignment = nextManualAssignmentNumber()
        let times = PortalFlightTimes(
            workStart: start,
            engineOn: engineOn,
            takeoff: takeoff,
            landing: landing,
            engineOff: engineOff,
            workEnd: workEnd
        )
        let leg = FlightLeg(
            date: formatDate(engineOn),
            flightNumber: "1111",
            departure: "SVO",
            arrival: "",
            aircraft: "A321B",
            registration: "73-709",
            plannedDeparture: formatClock(engineOn),
            workStart: formatClock(start),
            engineOn: formatClock(engineOn),
            takeoff: formatClock(takeoff),
            landing: formatClock(landing),
            engineOff: formatClock(engineOff),
            portalTimes: times,
            assignmentNumber: assignment,
            legNumber: "1111",
            scheduleType: .planned,
            calculatedMinutesOverride: nil
        )
        return FlightDuty(id: UUID(), legs: [leg])
    }
}


'''
s = s[:start] + new_flights + s[end:]

# 2. Список принимает уже найденные/отсортированные задания.
s = replace_once(
    s,
    'struct DutiesListView: View {\n    @ObservedObject var store: AppStore\n    @State private var selectedDuty: FlightDuty?\n',
    'struct DutiesListView: View {\n    @ObservedObject var store: AppStore\n    let duties: [FlightDuty]\n    @State private var selectedDuty: FlightDuty?\n',
    'DutiesListView declaration'
)
s = replace_once(s, '            List(store.duties) { duty in', '            List(duties) { duty in', 'DutiesListView list')

# 3. Overlay умеет работать в режиме создания.
s = replace_once(
    s,
    '''private struct DutyAssignmentOverlay: View {
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    let onClose: () -> Void
''',
    '''private struct DutyAssignmentOverlay: View {
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    let isCreating: Bool
    let onCreate: (([FlightLeg]) -> Void)?
    let onClose: () -> Void

    init(
        duty: FlightDuty,
        store: AppStore,
        isCreating: Bool = false,
        onCreate: (([FlightLeg]) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.duty = duty
        self.store = store
        self.isCreating = isCreating
        self.onCreate = onCreate
        self.onClose = onClose
    }
''',
    'DutyAssignmentOverlay declaration'
)
s = replace_once(
    s,
    '''                        externalEditorDismissSignal: dismissEditorSignal
                    )
''',
    '''                        externalEditorDismissSignal: dismissEditorSignal,
                        isCreating: isCreating,
                        onCreate: onCreate
                    )
''',
    'DutyDetailView overlay call'
)
s = s.replace('                        } else if !editModeIsActive {\n                            onClose()\n', '                        } else if isCreating || !editModeIsActive {\n                            onClose()\n', 2)
s = replace_once(
    s,
    '''                        canStart: !editorIsActive
                            && !editModeIsActive
                            && scrollIsAtTop,
''',
    '''                        canStart: !editorIsActive
                            && (isCreating || !editModeIsActive)
                            && scrollIsAtTop,
''',
    'creation drag'
)

# 4. Строка в списке полётов.
row_start = s.index('struct DutyRow: View {')
row_end = s.index('// MARK: - Детали смены', row_start)
new_row = r'''struct DutyRow: View {
    let duty: FlightDuty

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "airplane.departure")
                .foregroundStyle(.blue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(formatDate(duty.start))
                    .font(.subheadline.bold())

                Text(
                    AirportDatabase.routeDisplayName(
                        [duty.firstLeg.departure] + duty.legs.map(\.arrival)
                    )
                )
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                Text(summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if duty.legs.count > 1 {
                    ForEach(duty.legs.indices, id: \.self) { index in
                        HStack(spacing: 5) {
                            Text(duty.legs[index].displayedLegNumber)
                                .foregroundStyle(.secondary)
                            Text(timeText(duty.legs[index].flightMinutes))
                                .monospacedDigit()
                        }
                        .font(.caption2)
                    }
                    Divider()
                        .frame(width: 72)
                }

                Text(timeText(duty.workMinutes))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text("полётная смена")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var summaryLine: String {
        let assignment = duty.firstLeg.assignmentNumber.map { "Задание на полёт № \($0)" }
            ?? "Задание на полёт"
        let count = flightCountText(duty.legs.count)
        let interval = "\(formatClock(duty.start)) – \(formatClock(duty.end))"
        let divided = duty.restMinutes > 0 ? " • разделена" : ""
        return "\(assignment) • \(count) • \(interval)\(divided)"
    }

    private func flightCountText(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "\(count) рейсов" }
        switch last {
        case 1: return "\(count) рейс"
        case 2...4: return "\(count) рейса"
        default: return "\(count) рейсов"
        }
    }
}


'''
s = s[:row_start] + new_row + s[row_end:]

# 5. DutyDetailView получает режим создания.
s = replace_once(
    s,
    '''    let externalEditorDismissSignal: Int

    init(
        duty: FlightDuty,
        onClose: (() -> Void)? = nil,
        scrollsAsPage: Bool = false,
        onEditorFocusChange: ((Bool) -> Void)? = nil,
        onEditModeChange: ((Bool) -> Void)? = nil,
        externalEditorDismissSignal: Int = 0
    ) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
        self.onEditorFocusChange = onEditorFocusChange
        self.onEditModeChange = onEditModeChange
        self.externalEditorDismissSignal = externalEditorDismissSignal
    }
''',
    '''    let externalEditorDismissSignal: Int
    let isCreating: Bool
    let onCreate: (([FlightLeg]) -> Void)?

    init(
        duty: FlightDuty,
        onClose: (() -> Void)? = nil,
        scrollsAsPage: Bool = false,
        onEditorFocusChange: ((Bool) -> Void)? = nil,
        onEditModeChange: ((Bool) -> Void)? = nil,
        externalEditorDismissSignal: Int = 0,
        isCreating: Bool = false,
        onCreate: (([FlightLeg]) -> Void)? = nil
    ) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
        self.onEditorFocusChange = onEditorFocusChange
        self.onEditModeChange = onEditModeChange
        self.externalEditorDismissSignal = externalEditorDismissSignal
        self.isCreating = isCreating
        self.onCreate = onCreate
        _isEditing = State(initialValue: isCreating)
        _draft = State(initialValue: isCreating ? duty.legs : [])
        _original = State(initialValue: isCreating ? duty.legs : [])
        _assignmentNumber = State(initialValue: isCreating ? (duty.firstLeg.assignmentNumber ?? "") : "")
        _editHistory = State(initialValue: isCreating
            ? [DutyEditSnapshot(legs: duty.legs, assignment: duty.firstLeg.assignmentNumber ?? "")]
            : [])
    }
''',
    'DutyDetailView init'
)

s = replace_once(
    s,
    '''    private var current: FlightDuty {
        store.duties.first { candidate in
            candidate.legs.contains { $0.id == duty.firstLeg.id }
        } ?? duty
    }
''',
    '''    private var current: FlightDuty {
        if isCreating, !draft.isEmpty {
            return FlightDuty(id: duty.id, legs: updatedLegs)
        }
        return store.duties.first { candidate in
            candidate.legs.contains { $0.id == duty.firstLeg.id }
        } ?? duty
    }
''',
    'current duty'
)

s = replace_once(
    s,
    '''        .onChange(of: draft) { _ in recordEdit() }
''',
    '''        .onAppear {
            if isCreating { onEditModeChange?(true) }
        }
        .onChange(of: draft) { _ in recordEdit() }
''',
    'creation onAppear'
)

# В режиме создания крестика слева нет.
s = replace_once(
    s,
    '''                if isEditing {
                    Button {
                        focusedField = nil
                        isEditing = false
                        draft = []
                        original = []
                        editHistory = []
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityLabel("Отменить все изменения")

                    Button {
''',
    '''                if isEditing {
                    if !isCreating {
                        Button {
                            focusedField = nil
                            isEditing = false
                            draft = []
                            original = []
                            editHistory = []
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 18, height: 18)
                        }
                        .accessibilityLabel("Отменить все изменения")
                    }

                    Button {
''',
    'hide create x'
)

s = replace_once(
    s,
    '''                    .disabled(!isValid || differences.isEmpty)
                    .accessibilityLabel("Применить изменения")
''',
    '''                    .disabled(!isValid || (!isCreating && differences.isEmpty))
                    .accessibilityLabel(isCreating ? "Сохранить задание на полёт" : "Применить изменения")
''',
    'save enabled creation'
)

s = replace_once(
    s,
    '''                            Text("Сохранить изменения?")
                                .font(.headline)
                            Text("Данные задания на полёт будут обновлены.")
''',
    '''                            Text(isCreating ? "Сохранить задание на полёт?" : "Сохранить изменения?")
                                .font(.headline)
                            Text(isCreating
                                 ? "Новое задание на полёт будет добавлено."
                                 : "Данные задания на полёт будут обновлены.")
''',
    'save popover creation text'
)

s = replace_once(
    s,
    '''                                Button("Сохранить") {
                                    store.updateDutyLegs(updatedLegs)
                                    showReview = false
                                    focusedField = nil
                                    isEditing = false
                                    draft = []
                                    original = []
                                    editHistory = []
                                }
''',
    '''                                Button("Сохранить") {
                                    if isCreating {
                                        onCreate?(updatedLegs)
                                        showReview = false
                                        focusedField = nil
                                        close()
                                    } else {
                                        store.updateDutyLegs(updatedLegs)
                                        showReview = false
                                        focusedField = nil
                                        isEditing = false
                                        draft = []
                                        original = []
                                        editHistory = []
                                    }
                                }
''',
    'save creation action'
)

# Заголовок показывает draft даже до полной валидности маршрута.
s = replace_once(
    s,
    '''            dutyTitle(
                isEditing && isValid
                ? FlightDuty(id: duty.id, legs: updatedLegs)
                : duty
            )
''',
    '''            dutyTitle(
                isEditing && !draft.isEmpty
                ? FlightDuty(id: duty.id, legs: updatedLegs)
                : duty
            )
''',
    'header draft display'
)
s = replace_once(
    s,
    '''        dutyCard(isEditing && isValid
                 ? FlightDuty(id: duty.id, legs: updatedLegs)
                 : duty)
''',
    '''        dutyCard(isEditing && !draft.isEmpty
                 ? FlightDuty(id: duty.id, legs: updatedLegs)
                 : duty)
''',
    'content draft display'
)

# Текст удаления в терминах рейсов.
s = replace_once(
    s,
    '''                            Text("Задание и \\(legCountText(duty.legs.count)) будут удалены.")
''',
    '''                            Text("Задание с \\(deletionFlightCountText(duty.legs.count)) будет удалено.")
''',
    'delete message'
)

# Assignment Number допускает Manual 001.
s = replace_once(
    s,
    '''                keyboardType: .numberPad,
                capitalization: .none,
                maxLength: 9,
''',
    '''                keyboardType: .asciiCapable,
                capitalization: .allCharacters,
                maxLength: 12,
''',
    'assignment keyboard'
)
s = replace_once(s, '                numbersOnly: true,\n                reserveText: "888888888",', '                numbersOnly: false,\n                reserveText: "Manual 888",', 'assignment alpha')

# Карточка-плюс после последнего рейса при создании.
s = replace_once(
    s,
    '''            ForEach(duty.legs.indices, id: \\.self) { index in
                legCard(
                    duty.legs[index],
                    index: index,
                    workEnd: duty.workIntervals[index].end
                )
                .zIndex(legEditorZIndex(index))

                if index + 1 < duty.legs.count {
                    let restStart = duty.workIntervals[index].end
                    let restEnd = duty.workIntervals[index + 1].start

                    if restEnd > restStart {
                        restCard(start: restStart, end: restEnd)
                    }
                }
            }
''',
    '''            ForEach(duty.legs.indices, id: \\.self) { index in
                legCard(
                    duty.legs[index],
                    index: index,
                    workEnd: duty.workIntervals[index].end
                )
                .zIndex(legEditorZIndex(index))

                if index + 1 < duty.legs.count {
                    let restStart = duty.workIntervals[index].end
                    let restEnd = duty.workIntervals[index + 1].start

                    if restEnd > restStart {
                        restCard(start: restStart, end: restEnd)
                    }
                }
            }

            if isCreating && draft.count < 10 {
                Button {
                    appendManualLeg()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Добавить рейс \\(draft.count + 1)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
''',
    'add flight placeholder'
)

# Вставляем функции для удаления/добавления рейсов перед restCard.
marker = '    private func restCard(start: Date, end: Date) -> some View {'
insert = r'''    private func deletionFlightCountText(_ count: Int) -> String {
        switch count {
        case 1: return "одним рейсом"
        case 2: return "двумя рейсами"
        case 3: return "тремя рейсами"
        case 4: return "четырьмя рейсами"
        default: return "\(count) рейсами"
        }
    }

    private func appendManualLeg() {
        guard isCreating, draft.count < 10, let lastIndex = draft.indices.last else { return }

        var previousLeg = draft[lastIndex]
        let previousTimes = times(for: previousLeg)
        let previousUpdated = PortalFlightTimes(
            workStart: previousTimes.workStart,
            engineOn: previousTimes.engineOn,
            takeoff: previousTimes.takeoff,
            landing: previousTimes.landing,
            engineOff: previousTimes.engineOff,
            workEnd: previousTimes.engineOff
        )
        previousLeg.portalTimes = previousUpdated
        previousLeg.workStart = formatClock(previousUpdated.workStart)
        previousLeg.engineOn = formatClock(previousUpdated.engineOn)
        previousLeg.takeoff = formatClock(previousUpdated.takeoff)
        previousLeg.landing = formatClock(previousUpdated.landing)
        previousLeg.engineOff = formatClock(previousUpdated.engineOff)
        draft[lastIndex] = previousLeg

        let workStart = previousUpdated.engineOff
        let engineOn = moscowCalendar.date(byAdding: .minute, value: 60, to: workStart) ?? workStart
        let takeoff = moscowCalendar.date(byAdding: .minute, value: 10, to: engineOn) ?? engineOn
        let landing = takeoff
        let engineOff = moscowCalendar.date(byAdding: .minute, value: 10, to: landing) ?? landing
        let workEnd = moscowCalendar.date(byAdding: .minute, value: 30, to: engineOff) ?? engineOff
        let values = PortalFlightTimes(
            workStart: workStart,
            engineOn: engineOn,
            takeoff: takeoff,
            landing: landing,
            engineOff: engineOff,
            workEnd: workEnd
        )
        let newLeg = FlightLeg(
            date: formatDate(engineOn),
            flightNumber: "1111",
            departure: previousLeg.arrival,
            arrival: "",
            aircraft: "A321B",
            registration: "73-709",
            plannedDeparture: formatClock(engineOn),
            workStart: formatClock(workStart),
            engineOn: formatClock(engineOn),
            takeoff: formatClock(takeoff),
            landing: formatClock(landing),
            engineOff: formatClock(engineOff),
            portalTimes: values,
            assignmentNumber: assignmentNumber,
            legNumber: "1111",
            scheduleType: .planned,
            calculatedMinutesOverride: nil
        )
        draft.append(newLeg)
        focusedField = nil
    }

'''
if marker not in s:
    raise SystemExit('rest marker not found')
s = s.replace(marker, insert + marker, 1)

# 6. Старую форму «Новый лег» удаляем из AppViews.
old_add_start = s.find('struct AddFlightView: View {')
if old_add_start != -1:
    old_add_end = s.index('// MARK: - План работ', old_add_start)
    s = s[:old_add_start] + s[old_add_end:]

p.write_text(s)

# 7. AppStore: сохранение нового задания одним Published-изменением.
core = Path('AeroCore.swift')
c = core.read_text()
c = replace_once(
    c,
    '''    func addFlight(
        _ flight: FlightLeg
    ) {
        
        flights.insert(
            flight,
            at: 0
        )
    }
''',
    '''    func addFlight(
        _ flight: FlightLeg
    ) {
        
        flights.insert(
            flight,
            at: 0
        )
    }

    func addDutyLegs(_ legs: [FlightLeg]) {
        guard !legs.isEmpty else { return }
        flights = legs + flights
    }
''',
    'AppStore addDutyLegs'
)
core.write_text(c)

# 8. Кнопки возврата времени показываются только при реальном изменении.
cell = Path('InlineFlightDateTimeCell.swift')
t = cell.read_text()
t = replace_once(
    t,
    '''        .overlay(alignment: .bottomTrailing) {
            if isEditing && isActive {
                VStack(spacing: 3) {
                    if showsCalendarButton && activePart == .date {
''',
    '''        .overlay(alignment: .bottomTrailing) {
            if isEditing && (isActive || hasAnyChange) {
                VStack(spacing: 3) {
                    if isActive && showsCalendarButton && activePart == .date {
''',
    'time restore overlay'
)
t = replace_once(
    t,
    '''                    Button {
                        selection = original
                    } label: {
''',
    '''                    if hasAnyChange {
                    Button {
                        selection = original
                        activePart = nil
                        showsCalendar = false
                        onDismiss()
                    } label: {
''',
    'time restore button start'
)
t = replace_once(
    t,
    '''                    .buttonStyle(.plain)
                    .disabled(selection == original)
                    .accessibilityLabel("Вернуть исходные дату и время")
                }
''',
    '''                    .buttonStyle(.plain)
                    .accessibilityLabel("Вернуть исходные дату и время")
                    }
                }
''',
    'time restore button end'
)
marker = '    private var hour: Int { calendar.component(.hour, from: selection) }'
if marker not in t:
    raise SystemExit('inline clock marker not found')
t = t.replace(marker, '''    private var hasAnyChange: Bool {
        selection != original
    }

''' + marker, 1)
cell.write_text(t)

# 9. Расчётное время: возврат виден только при жёлтом изменении и всегда активен.
s = p.read_text()
s = replace_once(
    s,
    '''        .overlay(alignment: .bottomTrailing) {
            if isEditing && isActive {
                Button(action: onRestore) {
''',
    '''        .overlay(alignment: .bottomTrailing) {
            if isEditing && hasChanges {
                Button {
                    onRestore()
                    activePart = nil
                } label: {
''',
    'calculated restore visible'
)
s = replace_once(
    s,
    '''                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(!hasChanges)
                .padding(.bottom, 6)
''',
    '''                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 6)
''',
    'calculated restore enabled'
)
p.write_text(s)

Path('AppVersion.swift').write_text('''enum AppVersion {
    static let number = 114
    static let label = "Версия 114"
}
''')
