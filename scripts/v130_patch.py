from pathlib import Path
import re


def replace(path: str, old: str, new: str, count: int = 1):
    p = Path(path)
    text = p.read_text()
    actual = text.count(old)
    if actual < count:
        raise RuntimeError(f"{path}: expected at least {count} occurrences, found {actual}: {old[:120]!r}")
    text = text.replace(old, new, count)
    p.write_text(text)


def regex_replace(path: str, pattern: str, replacement: str, count: int = 1, flags=0):
    p = Path(path)
    text = p.read_text()
    text, n = re.subn(pattern, replacement, text, count=count, flags=flags)
    if n != count:
        raise RuntimeError(f"{path}: regex expected {count}, got {n}: {pattern[:120]!r}")
    p.write_text(text)


# ---------------------------------------------------------------------------
# ReferenceDataV129.swift
# ---------------------------------------------------------------------------
replace(
    "ReferenceDataV129.swift",
    '''    private init() {\n        aircraft = Self.seed.sorted { $0.registration < $1.registration }\n    }''',
    '''    private init() {\n        aircraft = Self.seed.sorted { left, right in\n            if left.registration == "RA-73772" { return true }\n            if right.registration == "RA-73772" { return false }\n            return left.registration < right.registration\n        }\n    }'''
)

replace(
    "ReferenceDataV129.swift",
    '''    private static func code(_ code: String, terminal: String?) -> String {\n        guard let terminal,\n              !terminal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {\n            return code\n        }\n        return "\\(code)/\\(terminal)"\n    }''',
    '''    private static func code(_ code: String, terminal: String?) -> String {\n        let base = code.uppercased()\n        let terminalValue = terminal?\n            .trimmingCharacters(in: .whitespacesAndNewlines)\n            .uppercased()\n        guard base == "SVO",\n              let terminalValue,\n              ["D", "E", "F"].contains(terminalValue) else {\n            return base\n        }\n        return "\\(base)/\\(terminalValue)"\n    }'''
)

replace(
    "ReferenceDataV129.swift",
    '''    @Published private(set) var entries: [FlightScheduleEntryV129] = []\n    @Published private(set) var imports: [FlightScheduleImportRecordV129] = []\n\n    private init() {\n        load()\n    }''',
    '''    @Published private(set) var entries: [FlightScheduleEntryV129] = []\n    @Published private(set) var imports: [FlightScheduleImportRecordV129] = []\n    private var entriesByFlightNumber: [String: [FlightScheduleEntryV129]] = [:]\n\n    private init() {\n        load()\n        rebuildIndex()\n    }'''
)

replace(
    "ReferenceDataV129.swift",
    '''        save()\n        return (added, updated, entries.count)\n    }\n\n    func deleteAll() {\n        entries = []\n        imports = []\n        save()\n    }''',
    '''        rebuildIndex()\n        save()\n        return (added, updated, entries.count)\n    }\n\n    func deleteAll() {\n        entries = []\n        imports = []\n        rebuildIndex()\n        save()\n    }'''
)

replace(
    "ReferenceDataV129.swift",
    '''        let candidates = entries.filter { $0.flightNumber == number }''',
    '''        let candidates = entriesByFlightNumber[number] ?? []'''
)

replace(
    "ReferenceDataV129.swift",
    '''    static func normalizedFlightNumber(_ raw: String) -> String {\n        raw.uppercased()\n            .replacingOccurrences(of: "SU", with: "")\n            .filter(\\.isNumber)\n    }''',
    '''    static func normalizedFlightNumber(_ raw: String) -> String {\n        let digits = raw.uppercased()\n            .replacingOccurrences(of: "SU", with: "")\n            .filter(\\.isNumber)\n        guard let value = Int(digits) else { return "" }\n        return String(value)\n    }'''
)

replace(
    "ReferenceDataV129.swift",
    '''    static func airportCode(_ raw: String?) -> String? {\n        guard let raw else { return nil }\n        let upper = raw.uppercased()\n        if let slash = upper.firstIndex(of: "/") {\n            let value = String(upper[..<slash]).filter(\\.isLetter)\n            return value.count == 3 ? value : nil\n        }\n        let value = upper.filter(\\.isLetter)\n        return value.count == 3 ? value : nil\n    }''',
    '''    static func airportCode(_ raw: String?) -> String? {\n        guard let raw else { return nil }\n        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)\n        guard !trimmed.isEmpty else { return nil }\n        let upper = trimmed.uppercased()\n\n        if upper.contains("ШЕРЕМЕТЬЕВО") || upper == "Ш" { return "SVO" }\n\n        if let slash = upper.firstIndex(of: "/") {\n            let value = String(upper[..<slash]).filter(\\.isLetter)\n            if value.count == 3 { return value }\n        }\n\n        if let regex = try? NSRegularExpression(pattern: #"\\(([A-Z]{3})(?:/[A-Z0-9]+)?\\)"#),\n           let match = regex.firstMatch(\n                in: upper,\n                range: NSRange(location: 0, length: (upper as NSString).length)\n           ),\n           match.numberOfRanges >= 2 {\n            return (upper as NSString).substring(with: match.range(at: 1))\n        }\n\n        let letters = upper.filter(\\.isLetter)\n        if letters.count == 3 { return letters }\n\n        let byName = AirportDatabase.airports.filter { airport in\n            airport.name.caseInsensitiveCompare(trimmed) == .orderedSame\n        }\n        if byName.count == 1 { return byName[0].iata }\n        return nil\n    }'''
)

replace(
    "ReferenceDataV129.swift",
    '''    private func save() {\n        if let data = try? JSONEncoder().encode(entries) {''',
    '''    private func rebuildIndex() {\n        entriesByFlightNumber = Dictionary(grouping: entries) { entry in\n            Self.normalizedFlightNumber(entry.flightNumber)\n        }\n    }\n\n    private func save() {\n        if let data = try? JSONEncoder().encode(entries) {'''
)

replace(
    "ReferenceDataV129.swift",
    '''    private static func normalizedFlight(_ value: String) -> String {\n        let digits = value.filter(\\.isNumber)\n        if !digits.isEmpty { return digits }\n        if let number = Double(value), number.isFinite {\n            return String(Int(number.rounded()))\n        }\n        return ""\n    }''',
    '''    private static func normalizedFlight(_ value: String) -> String {\n        let digits = value.filter(\\.isNumber)\n        if !digits.isEmpty {\n            return FlightScheduleStoreV129.normalizedFlightNumber(digits)\n        }\n        if let number = Double(value), number.isFinite {\n            return FlightScheduleStoreV129.normalizedFlightNumber(String(Int(number.rounded())))\n        }\n        return ""\n    }'''
)

# Replace settings views tail in one controlled block.
regex_replace(
    "ReferenceDataV129.swift",
    r'''struct AircraftReferenceSettingsV129View: View \{.*\Z''',
    r'''struct AircraftReferenceSettingsV129View: View {
    @ObservedObject private var store = AircraftReferenceStoreV129.shared
    @State private var search = ""

    private var values: [AircraftReferenceV129] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.aircraft }
        return store.aircraft.filter {
            $0.registration.localizedCaseInsensitiveContains(query)
                || $0.surname.localizedCaseInsensitiveContains(query)
                || $0.type.rawValue.localizedCaseInsensitiveContains(query)
                || ($0.oldRegistration?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Борт, фамилия или тип ВС", text: $search)
            }

            Section("Воздушные суда · \(values.count)") {
                ForEach(values) { aircraft in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(aircraft.type.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Text(aircraft.registration)
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Text(aircraft.surname)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("Старый: \(aircraft.oldRegistration ?? "—")")
                            if let msn = aircraft.msn { Text("MSN: \(msn)") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Воздушные суда")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct FlightScheduleDatabaseV130View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared
    @State private var search = ""

    private var values: [FlightScheduleEntryV129] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.entries }
        let normalizedNumber = FlightScheduleStoreV129.normalizedFlightNumber(query)
        return store.entries.filter { entry in
            (!normalizedNumber.isEmpty
                && FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber) == normalizedNumber)
                || entry.departure.localizedCaseInsensitiveContains(query)
                || entry.arrival.localizedCaseInsensitiveContains(query)
                || (AirportDatabase.airport(for: entry.departure)?.name.localizedCaseInsensitiveContains(query) ?? false)
                || (AirportDatabase.airport(for: entry.arrival)?.name.localizedCaseInsensitiveContains(query) ?? false)
                || entry.rawAircraftCode.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Рейс, аэропорт или тип ВС", text: $search)
                    .textInputAutocapitalization(.characters)
            }

            Section("Строки · \(values.count)") {
                ForEach(values) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text("\(entry.departure) → \(entry.arrival)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(timeText(entry.flightMinutes))
                                .font(.caption.monospacedDigit())
                        }
                        Text("\(FlightScheduleStoreV129.shortDay(entry.validFrom))–\(FlightScheduleStoreV129.shortDay(entry.validTo)) · дни \(entry.operatingWeekdays.map(String.init).joined()) · UTC \(clock(entry.departureMinutesUTC))–\(clock(entry.arrivalMinutesUTC)) · \(entry.rawAircraftCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("База расписания")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}


struct FlightScheduleSettingsV129View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared
    @State private var showImporter = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var showDelete = false

    var body: some View {
        List {
            Section("Состояние") {
                LabeledContent("Строк в базе", value: String(store.entries.count))
                LabeledContent("Покрытие", value: store.coverageText)
                LabeledContent("Импортов", value: String(store.imports.count))

                NavigationLink {
                    FlightScheduleDatabaseV130View()
                } label: {
                    Label("Открыть базу расписания", systemImage: "list.bullet.rectangle")
                }
                .disabled(store.entries.isEmpty)
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Импортировать расписание", systemImage: "square.and.arrow.down")
                }

                Button("Удалить расписание", role: .destructive) {
                    showDelete = true
                }
                .disabled(store.entries.isEmpty)
            } footer: {
                Text("Загружается .xls с листом «UTC». Вид перевозки игнорируется; данные используются только как плановое расписание.")
            }

            if !store.imports.isEmpty {
                Section("Загруженные расписания") {
                    ForEach(store.imports) { value in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(FlightScheduleStoreV129.shortDay(value.validFrom))–\(FlightScheduleStoreV129.shortDay(value.validTo))")
                                .font(.subheadline.weight(.semibold))
                            Text("\(value.rowCount.formatted(.number.grouping(.automatic))) строк · импорт \(importDate(value.importedAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Расписание рейсов")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "xls") ?? .data]
        ) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let summary = try store.importXLS(data: data, sourceName: url.lastPathComponent)
                message = "Импорт завершён. Добавлено: \(summary.added), обновлено: \(summary.updated). В базе: \(summary.total) строк."
            } catch {
                message = error.localizedDescription
            }
            showMessage = true
        }
        .alert("Расписание рейсов", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
        .alert("Удалить всё расписание?", isPresented: $showDelete) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) { store.deleteAll() }
        } message: {
            Text("Будет очищена только локальная база расписания рейсов. История и планы не изменятся.")
        }
    }

    private func importDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
}
''',
    flags=re.S
)


# ---------------------------------------------------------------------------
# AssignmentPlan.swift
# ---------------------------------------------------------------------------
replace(
    "AssignmentPlan.swift",
    '''    func deleteImportedPlan() {\n        items.removeAll { $0.source == .importedFile }\n        lastFileImport = nil\n        saveItems()\n        saveMetadata()\n    }''',
    '''    func deleteImportedPlan() {\n        items.removeAll { $0.source == .importedFile }\n        lastFileImport = nil\n        saveItems()\n        saveMetadata()\n    }\n\n    func deleteItem(id: String) {\n        items.removeAll { $0.id == id }\n        saveItems()\n    }'''
)


# ---------------------------------------------------------------------------
# PerspectivePlanV119.swift — remove legacy separator before joining PDF lines.
# ---------------------------------------------------------------------------
replace(
    "PerspectivePlanV119.swift",
    '''    private static func eventLabels(_ text: String) -> (title: String, detail: String?) {\n        let lines = text\n            .components(separatedBy: .newlines)''',
    '''    private static func eventLabels(_ text: String) -> (title: String, detail: String?) {\n        let normalizedSource = text.replacingOccurrences(\n            of: #"\\s*·\\s*"#,\n            with: " ",\n            options: .regularExpression\n        )\n        let lines = normalizedSource\n            .components(separatedBy: .newlines)'''
)


# ---------------------------------------------------------------------------
# PlanAssignmentRowV119.swift
# ---------------------------------------------------------------------------
replace(
    "PlanAssignmentRowV119.swift",
    '''    var conflictText: String?\n    var perspectiveStyle = false''',
    '''    var conflictText: String?\n    var perspectiveStyle = false\n\n    private var effectiveConflictText: String? {\n        if let conflictText { return conflictText }\n        guard perspectiveStyle, item.kind == .flight else { return nil }\n        return PerspectiveDutyBuilderV129.routeConflict(item: item)\n    }'''
)

# only body-related conflict references, not declaration/effective var
replace(
    "PlanAssignmentRowV119.swift",
    '''                if let conflictText {\n                    Label(conflictText, systemImage: "exclamationmark.triangle.fill")''',
    '''                if let conflictText = effectiveConflictText {\n                    Label(conflictText, systemImage: "exclamationmark.triangle.fill")'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''                        conflictText == nil\n                            ? Color.secondary''',
    '''                        effectiveConflictText == nil\n                            ? Color.secondary'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''        .padding(.horizontal, conflictText == nil ? 0 : 8)''',
    '''        .padding(.horizontal, effectiveConflictText == nil ? 0 : 8)'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''            if conflictText != nil {\n                RoundedRectangle''',
    '''            if effectiveConflictText != nil {\n                RoundedRectangle'''
)

replace(
    "PlanAssignmentRowV119.swift",
    '''        let lines = raw\n            .components(separatedBy: .newlines)''',
    '''        let cleanedRaw = perspectiveStyle\n            ? raw.replacingOccurrences(\n                of: #"\\s*·\\s*"#,\n                with: " ",\n                options: .regularExpression\n            )\n            : raw\n        let lines = cleanedRaw\n            .components(separatedBy: .newlines)'''
)


# ---------------------------------------------------------------------------
# AssignmentsView.swift
# ---------------------------------------------------------------------------
replace(
    "AssignmentsView.swift",
    '''    case workPlan = "План работ"\n    case test = "Test"''',
    '''    case workPlan = "План работ"'''
)
replace(
    "AssignmentsView.swift",
    '''                case .workPlan:\n                    AccordWorkPlanView(store: store)\n                case .test:\n                    PerspectivePlanTestView()''',
    '''                case .workPlan:\n                    AccordWorkPlanView(store: store)'''
)
replace(
    "AssignmentsView.swift",
    '''    @State private var pendingDraft: AssignmentImportDraft?\n    @State private var selectedPerspectiveDuty: FlightDuty?''',
    '''    @State private var pendingDraft: AssignmentImportDraft?\n    @State private var selectedPerspectiveDuty: FlightDuty?\n    @State private var selectedPerspectiveItem: AssignmentPlanItem?'''
)
replace(
    "AssignmentsView.swift",
    '''            if let duty = selectedPerspectiveDuty {\n                PerspectiveDutyOverlayV129(\n                    duty: duty,\n                    store: store,\n                    onClose: { selectedPerspectiveDuty = nil }\n                )\n                .zIndex(50)\n            }''',
    '''            if let duty = selectedPerspectiveDuty,\n               let item = selectedPerspectiveItem {\n                PerspectiveDutyOverlayV129(\n                    item: item,\n                    duty: duty,\n                    store: store,\n                    planStore: planStore,\n                    onClose: {\n                        selectedPerspectiveDuty = nil\n                        selectedPerspectiveItem = nil\n                    }\n                )\n                .zIndex(50)\n            }'''
)
replace(
    "AssignmentsView.swift",
    '''        switch PerspectiveDutyBuilderV129.build(item: item) {\n        case .ready(let duty):\n            selectedPerspectiveDuty = duty\n        case .missing(let reason):''',
    '''        switch PerspectiveDutyBuilderV129.build(item: item) {\n        case .ready(let duty):\n            selectedPerspectiveItem = item\n            selectedPerspectiveDuty = duty\n        case .missing(let reason):'''
)
replace(
    "AssignmentsView.swift",
    '''        case .mismatch(let duty, let expected, let actual):\n            selectedPerspectiveDuty = duty\n            message = "Расписание построило полётное время \\(timeText(actual)), а в перспективном плане указано \\(timeText(expected)). Карточка открыта для проверки."\n            showMessage = true''',
    '''        case .routeMismatch(let reason):\n            message = reason + ". Карточка не открыта, проверь маршрут исходного плана и расписания."\n            showMessage = true\n        case .mismatch(let duty, let expected, let actual):\n            selectedPerspectiveItem = item\n            selectedPerspectiveDuty = duty\n            message = "Расписание построило полётное время \\(timeText(actual)), а в перспективном плане указано \\(timeText(expected)). Карточка открыта для проверки."\n            showMessage = true'''
)
replace(
    "AssignmentsView.swift",
    '''        VStack(spacing: 16) {\n            ForEach(monthSections) { month in''',
    '''        LazyVStack(spacing: 16) {\n            ForEach(monthSections) { month in'''
)
regex_replace(
    "AssignmentsView.swift",
    r'''\nprivate struct PerspectivePlanTestView: View \{.*?\n\}\n\n\nprivate struct AccordWorkPlanView: View \{''',
    '''\nprivate struct AccordWorkPlanView: View {''',
    flags=re.S
)


# ---------------------------------------------------------------------------
# AppViews.swift
# ---------------------------------------------------------------------------
replace(
    "AppViews.swift",
    '''    let isCreating: Bool\n    let isReadOnly: Bool\n    let onCreate: (([FlightLeg]) -> Void)?''',
    '''    let isCreating: Bool\n    let isReadOnly: Bool\n    let onCreate: (([FlightLeg]) -> Void)?\n    let onUpdate: (([FlightLeg]) -> Void)?\n    let onDelete: (() -> Void)?'''
)
replace(
    "AppViews.swift",
    '''        isCreating: Bool = false,\n        isReadOnly: Bool = false,\n        onCreate: (([FlightLeg]) -> Void)? = nil\n    ) {''',
    '''        isCreating: Bool = false,\n        isReadOnly: Bool = false,\n        onCreate: (([FlightLeg]) -> Void)? = nil,\n        onUpdate: (([FlightLeg]) -> Void)? = nil,\n        onDelete: (() -> Void)? = nil\n    ) {'''
)
replace(
    "AppViews.swift",
    '''        self.isReadOnly = isReadOnly\n        self.onCreate = onCreate''',
    '''        self.isReadOnly = isReadOnly\n        self.onCreate = onCreate\n        self.onUpdate = onUpdate\n        self.onDelete = onDelete'''
)
replace(
    "AppViews.swift",
    '''    @State private var routeEditSide: RouteEditSide = .departure\n    @Environment(\\.horizontalSizeClass) private var sizeClass''',
    '''    @State private var routeEditSide: RouteEditSide = .departure\n    @State private var externallySavedLegs: [FlightLeg]?\n    @Environment(\\.horizontalSizeClass) private var sizeClass'''
)
replace(
    "AppViews.swift",
    '''    private var current: FlightDuty {\n        if isCreating, !draft.isEmpty {\n            return FlightDuty(id: duty.id, legs: updatedLegs)\n        }\n        return store.duties.first { candidate in''',
    '''    private var current: FlightDuty {\n        if isCreating, !draft.isEmpty {\n            return FlightDuty(id: duty.id, legs: updatedLegs)\n        }\n        if let externallySavedLegs, !externallySavedLegs.isEmpty {\n            return FlightDuty(id: duty.id, legs: externallySavedLegs)\n        }\n        return store.duties.first { candidate in'''
)
replace(
    "AppViews.swift",
    '''                                    } else {\n                                        store.updateDutyLegs(updatedLegs)\n                                        showReview = false''',
    '''                                    } else {\n                                        if let onUpdate {\n                                            externallySavedLegs = updatedLegs\n                                            onUpdate(updatedLegs)\n                                        } else {\n                                            store.updateDutyLegs(updatedLegs)\n                                        }\n                                        showReview = false'''
)
replace(
    "AppViews.swift",
    '''                                Button("Удалить") {\n                                    showDeleteConfirmation = false\n                                    store.deleteDutyLegs(ids: Set(duty.legs.map(\\.id)))\n                                    close()\n                                }''',
    '''                                Button("Удалить") {\n                                    showDeleteConfirmation = false\n                                    if let onDelete {\n                                        onDelete()\n                                    } else {\n                                        store.deleteDutyLegs(ids: Set(duty.legs.map(\\.id)))\n                                    }\n                                    close()\n                                }'''
)

replace(
    "AppViews.swift",
    '''private struct DutyAssignmentOverlay: View {\n    let duty: FlightDuty\n    @ObservedObject var store: AppStore\n    let isCreating: Bool\n    let onCreate: (([FlightLeg]) -> Void)?\n    let onClose: () -> Void''',
    '''struct DutyAssignmentOverlay: View {\n    let duty: FlightDuty\n    @ObservedObject var store: AppStore\n    let isCreating: Bool\n    let onCreate: (([FlightLeg]) -> Void)?\n    let onUpdate: (([FlightLeg]) -> Void)?\n    let onDelete: (() -> Void)?\n    let onClose: () -> Void'''
)
replace(
    "AppViews.swift",
    '''        isCreating: Bool = false,\n        onCreate: (([FlightLeg]) -> Void)? = nil,\n        onClose: @escaping () -> Void\n    ) {\n        self.duty = duty\n        self.store = store\n        self.isCreating = isCreating\n        self.onCreate = onCreate\n        self.onClose = onClose''',
    '''        isCreating: Bool = false,\n        onCreate: (([FlightLeg]) -> Void)? = nil,\n        onUpdate: (([FlightLeg]) -> Void)? = nil,\n        onDelete: (() -> Void)? = nil,\n        onClose: @escaping () -> Void\n    ) {\n        self.duty = duty\n        self.store = store\n        self.isCreating = isCreating\n        self.onCreate = onCreate\n        self.onUpdate = onUpdate\n        self.onDelete = onDelete\n        self.onClose = onClose'''
)
replace(
    "AppViews.swift",
    '''                        isCreating: isCreating,\n                        onCreate: onCreate\n                    )''',
    '''                        isCreating: isCreating,\n                        onCreate: onCreate,\n                        onUpdate: onUpdate,\n                        onDelete: onDelete\n                    )'''
)

# Manual duty default aircraft and registration.
replace(
    "AppViews.swift",
    '''            aircraft: AircraftFamilyV129.a320.rawValue,\n            registration: "",''',
    '''            aircraft: AircraftFamilyV129.a320S.rawValue,\n            registration: "RA-73772",'''
)
replace(
    "AppViews.swift",
    '''            leg.assignmentNumber = assignment\n        }\n        return FlightDuty(id: UUID(), legs: [leg])''',
    '''            leg.assignmentNumber = assignment\n        }\n        leg.registration = "RA-73772"\n        leg = DutyAutofillV129.applyingAircraftReference(to: leg)\n        return FlightDuty(id: UUID(), legs: [leg])'''
)

# Live flight lookup: keep typed digits, then autofill if current value exists.
replace(
    "AppViews.swift",
    '''            set: { raw in\n                let digits = DutyAutofillV129.normalizedFlightNumber(raw)\n                draft[index].legNumber = digits\n                draft[index].flightNumber = digits\n            }''',
    '''            set: { raw in\n                let digits = String(raw.filter(\\.isNumber).prefix(4))\n                draft[index].legNumber = digits\n                draft[index].flightNumber = digits\n                autofillSchedule(index: index)\n            }'''
)

# Instant RA -> type.
replace(
    "AppViews.swift",
    '''            set: { newValue in\n                let digits = String(newValue.filter(\\.isNumber).prefix(5))\n                draft[index].registration = "RA-" + digits\n            }''',
    '''            set: { newValue in\n                let digits = String(newValue.filter(\\.isNumber).prefix(5))\n                draft[index].registration = "RA-" + digits\n                if digits.count == 5 {\n                    draft[index] = DutyAutofillV129.applyingAircraftReference(to: draft[index])\n                }\n            }'''
)

# Replace Menu with simple value. Tap behavior handled by identityField.
regex_replace(
    "AppViews.swift",
    r'''    private func aircraftField\(_ leg: FlightLeg, index: Int\) -> some View \{.*?\n    \}\n\n    private func registrationField''',
    '''    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {\n        identityField("Тип ВС", field: .aircraft(index)) {\n            Text(AircraftFamilyV129.display(leg.aircraft))\n                .font(.caption.bold())\n                .lineLimit(1)\n        }\n    }\n\n    private func registrationField''',
    flags=re.S
)

replace(
    "AppViews.swift",
    '''            if case .flightKind(let index) = field {\n                toggleScheduleType(index)\n            } else {\n                focusedField = field\n            }''',
    '''            if case .flightKind(let index) = field {\n                toggleScheduleType(index)\n            } else if case .aircraft(let index) = field {\n                cycleAircraftType(index)\n            } else {\n                focusedField = field\n            }'''
)

replace(
    "AppViews.swift",
    '''    private func selectAircraftType(_ type: AircraftFamilyV129, index: Int) {''',
    '''    private func cycleAircraftType(_ index: Int) {\n        guard draft.indices.contains(index) else { return }\n        let values = AircraftFamilyV129.allCases\n        let current = AircraftFamilyV129.normalized(draft[index].aircraft) ?? .a320\n        let currentIndex = values.firstIndex(of: current) ?? 0\n        let next = values[(currentIndex + 1) % values.count]\n        selectAircraftType(next, index: index)\n    }\n\n    private func selectAircraftType(_ type: AircraftFamilyV129, index: Int) {'''
)

# Allow deleting added legs from second leg onward as soon as there is >1.
replace(
    "AppViews.swift",
    '''                    isEnabled: isCreating\n                        && draft.count > 3\n                        && index > 0''',
    '''                    isEnabled: isCreating\n                        && draft.count > 1\n                        && index > 0'''
)

regex_replace(
    "AppViews.swift",
    r'''    private func removeManualLeg\(at index: Int\) \{.*?\n    \}\n\n    private func restCard''',
    '''    private func removeManualLeg(at index: Int) {\n        guard isCreating, draft.count > 1, index > 0, draft.indices.contains(index) else {\n            return\n        }\n\n        focusedField = nil\n        draft.remove(at: index)\n\n        var previousEngineOff: Date?\n        for currentIndex in draft.indices {\n            var leg = draft[currentIndex]\n            let values = times(for: leg)\n            let workStart = currentIndex == 0\n                ? values.engineOn.addingTimeInterval(-60 * 60)\n                : (previousEngineOff ?? values.engineOn.addingTimeInterval(-60 * 60))\n            let workEnd = currentIndex == draft.indices.last\n                ? values.engineOff.addingTimeInterval(30 * 60)\n                : values.engineOff\n\n            leg.portalTimes = PortalFlightTimes(\n                workStart: workStart,\n                engineOn: values.engineOn,\n                takeoff: values.takeoff,\n                landing: values.landing,\n                engineOff: values.engineOff,\n                workEnd: workEnd\n            )\n            leg.date = formatDate(values.engineOn)\n            leg.workStart = formatClock(workStart)\n            leg.engineOn = formatClock(values.engineOn)\n            leg.takeoff = formatClock(values.takeoff)\n            leg.landing = formatClock(values.landing)\n            leg.engineOff = formatClock(values.engineOff)\n            draft[currentIndex] = leg\n            previousEngineOff = values.engineOff\n        }\n    }\n\n    private func restCard''',
    flags=re.S
)

print("v130 source patch applied")
