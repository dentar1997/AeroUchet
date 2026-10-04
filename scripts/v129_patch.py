from pathlib import Path


def replace(path, old, new, expected=1):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(
            f"{path}: expected {expected} matches, found {count}\n--- OLD ---\n{old[:700]}"
        )
    p.write_text(text.replace(old, new, expected))


# Settings: expose both reference databases.
replace(
    "AssignmentsSettings.swift",
    '''                    LabeledContent("Легов истории", value: String(store.flights.count))''',
    '''                    NavigationLink {
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

                    LabeledContent("Легов истории", value: String(store.flights.count))'''
)


# Perspective row: compact right column, short dates, no visible calculated duty interval,
# numeric flight numbers, schedule-based IATA/terminal display and corrected linked text.
replace(
    "PlanAssignmentRowV119.swift",
    '''    @ObservedObject private var appearanceStore = AssignmentAppearanceStore.shared''',
    '''    @ObservedObject private var appearanceStore = AssignmentAppearanceStore.shared
    @ObservedObject private var scheduleStore = FlightScheduleStoreV129.shared'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''                Text(dateLabel)
                    .font(perspectiveStyle ? .subheadline.weight(.semibold) : .caption)
                    .foregroundStyle(
                        conflictText == nil
                            ? (perspectiveStyle ? Color.primary : Color.secondary)
                            : Color.red
                    )''',
    '''                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(
                        conflictText == nil
                            ? Color.secondary
                            : Color.red
                    )'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''                if let timeRange {
                    Text(timeRange)
                        .font(
                            perspectiveStyle
                                ? .subheadline.weight(.semibold).monospacedDigit()
                                : .caption.monospacedDigit()
                        )
                        .multilineTextAlignment(.trailing)
                }''',
    '''                if let timeRange {
                    Text(timeRange)
                        .font(.caption.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''                    "Полётная смена + перемещ. в кач. пассаж. = \\(timeText(total)) ≤ макс. продолж. полётной смены + 02:00"''',
    '''                    "Полётная смена + Перемещ. в кач. пассаж. = \\(timeText(total)) ≤ Макс. продолж. полётной смены + 02:00"'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''    private func legText(_ leg: DisplayLeg) -> String {
        var parts = [leg.flightNumber]
        if let departure = leg.departure,
           let arrival = leg.arrival {
            parts.append("\\(departure) → \\(arrival)")
        }
        if let aircraft = leg.aircraft, !aircraft.isEmpty {
            parts.append(aircraft)
        }
        return parts.joined(separator: " · ")
    }''',
    '''    private func legText(_ leg: DisplayLeg) -> String {
        var parts = [leg.flightNumber]
        if perspectiveStyle,
           !scheduleStore.entries.isEmpty,
           let match = PerspectiveDutyBuilderV129.scheduleDisplay(
                flightNumber: leg.flightNumber,
                date: metadata?.sourceStart ?? item.start,
                departureHint: leg.departure,
                arrivalHint: leg.arrival
           ) {
            let departure = DutyAutofillV129.displayAirport(
                code: match.entry.departure,
                terminal: match.entry.departureTerminal
            )
            let arrival = DutyAutofillV129.displayAirport(
                code: match.entry.arrival,
                terminal: match.entry.arrivalTerminal
            )
            parts.append("\\(departure) → \\(arrival)")
        } else if let departure = leg.departure,
                  let arrival = leg.arrival {
            parts.append("\\(departure) → \\(arrival)")
        }
        if let aircraft = leg.aircraft, !aircraft.isEmpty {
            parts.append(AircraftFamilyV129.display(aircraft))
        }
        return parts.joined(separator: " · ")
    }'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''        let value = lines.joined(separator: perspectiveStyle ? " " : "\\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)''',
    '''        let displayedLines = lines.enumerated().map { index, line in
            guard perspectiveStyle, index < lines.count - 1 else { return line }
            return line.replacingOccurrences(
                of: #"\\.\\s*$"#,
                with: "",
                options: .regularExpression
            )
        }
        let value = displayedLines.joined(separator: perspectiveStyle ? " " : "\\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''                return fullDate(item.start)
            }
            return "\\(fullDate(item.start)) — \\(fullDate(includedEnd))"''',
    '''                return displayDate(item.start)
            }
            return "\\(displayDate(item.start)) — \\(displayDate(includedEnd))"'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''            return fullDate(interval.start)
        }
        return "\\(fullDate(interval.start)) — \\(fullDate(interval.end))"''',
    '''            return displayDate(interval.start)
        }
        return "\\(displayDate(interval.start)) — \\(displayDate(interval.end))"'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''    private var secondaryTimeRange: String? {
        guard perspectiveStyle,
              !item.isAllDay,
              item.kind == .flight,
              metadata?.sourceStart != nil,
              metadata?.sourceEnd != nil else {
            return nil
        }
        return "\\(clock(item.start)) — \\(clock(item.end))"
    }

    private func fullDate(_ date: Date) -> String {''',
    '''    private var secondaryTimeRange: String? {
        nil
    }

    private func displayDate(_ date: Date) -> String {
        if !perspectiveStyle { return fullDate(date) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }

    private func fullDate(_ date: Date) -> String {'''
)
replace(
    "PlanAssignmentRowV119.swift",
    '''        return digits.isEmpty ? value : "SU \\(digits)"''',
    '''        return digits.isEmpty ? value : digits'''
)


# Parser: don't preserve a period that is only the separator of two physical PDF lines.
replace(
    "PerspectivePlanV119.swift",
    '''        let detail = lines.dropFirst()
            .filter { normalizedText($0) != normalizedText(title) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)''',
    '''        let detailLines = lines.dropFirst()
            .filter { normalizedText($0) != normalizedText(title) }
        let detail = detailLines.enumerated().map { index, line in
            guard index < detailLines.count - 1 else { return line }
            return line.replacingOccurrences(
                of: #"\\.\\s*$"#,
                with: "",
                options: .regularExpression
            )
        }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)'''
)


# Test: working flight must have flight time.
replace(
    "AssignmentsView.swift",
    '''            plannedFlightMinutes: nil,
            isAllDayRange: false,
            originMonthKey: 202610
        )

        let passenger = AssignmentPlanItem(''',
    '''            plannedFlightMinutes: 200,
            isAllDayRange: false,
            originMonthKey: 202610
        )

        let passenger = AssignmentPlanItem('''
)


# Perspective working rows become interactive and open the production duty card.
replace(
    "AssignmentsView.swift",
    '''    @State private var showMessage = false
    @State private var pendingDraft: AssignmentImportDraft?''',
    '''    @State private var showMessage = false
    @State private var pendingDraft: AssignmentImportDraft?
    @State private var selectedPerspectiveDuty: FlightDuty?'''
)
replace(
    "AssignmentsView.swift",
    '''                        PerspectivePlanMonthCardsView(
                            items: items,
                            status: status(for:),
                            statusColor: statusColor(for:)
                        )''',
    '''                        PerspectivePlanMonthCardsView(
                            items: items,
                            status: status(for:),
                            statusColor: statusColor(for:),
                            onFlightTap: openPerspectiveDuty
                        )'''
)
replace(
    "AssignmentsView.swift",
    '''        }
    }

    private func status(for item: AssignmentPlanItem) -> String? {''',
    '''        }
        .overlay {
            if let duty = selectedPerspectiveDuty {
                PerspectiveDutyOverlayV129(
                    duty: duty,
                    store: store,
                    onClose: { selectedPerspectiveDuty = nil }
                )
                .zIndex(50)
            }
        }
    }

    private func openPerspectiveDuty(_ item: AssignmentPlanItem) {
        guard item.kind == .flight else { return }
        switch PerspectiveDutyBuilderV129.build(item: item) {
        case .ready(let duty):
            selectedPerspectiveDuty = duty
        case .missing(let reason):
            message = reason + " Сначала импортируй подходящее расписание в «Ещё» → «Расписание рейсов»."
            showMessage = true
        case .mismatch(let duty, let expected, let actual):
            selectedPerspectiveDuty = duty
            message = "Расписание построило полётное время \\(timeText(actual)), а в перспективном плане указано \\(timeText(expected)). Карточка открыта для проверки."
            showMessage = true
        }
    }

    private func status(for item: AssignmentPlanItem) -> String? {''',
    expected=1
)
replace(
    "AssignmentsView.swift",
    '''private struct PerspectivePlanMonthCardsView: View {
    let items: [AssignmentPlanItem]
    let status: (AssignmentPlanItem) -> String?
    let statusColor: (AssignmentPlanItem) -> Color''',
    '''private struct PerspectivePlanMonthCardsView: View {
    let items: [AssignmentPlanItem]
    let status: (AssignmentPlanItem) -> String?
    let statusColor: (AssignmentPlanItem) -> Color
    var onFlightTap: ((AssignmentPlanItem) -> Void)? = nil'''
)
replace(
    "AssignmentsView.swift",
    '''                    ForEach(Array(group.items.enumerated()), id: \\.element.id) { index, item in
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
                    }''',
    '''                    ForEach(Array(group.items.enumerated()), id: \\.element.id) { index, item in
                        if item.kind == .flight, let onFlightTap {
                            Button {
                                onFlightTap(item)
                            } label: {
                                PlanAssignmentRowV119(
                                    item: item,
                                    status: status(item),
                                    statusColor: statusColor(item),
                                    conflictText: nil,
                                    perspectiveStyle: true
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                        } else {
                            PlanAssignmentRowV119(
                                item: item,
                                status: status(item),
                                statusColor: statusColor(item),
                                conflictText: nil,
                                perspectiveStyle: true
                            )
                            .padding(.horizontal, 10)
                        }

                        if index < group.items.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }'''
)


# Duty detail supports a read-only synthetic perspective card.
replace(
    "AppViews.swift",
    '''    let externalEditorDismissSignal: Int
    let isCreating: Bool
    let onCreate: (([FlightLeg]) -> Void)?''',
    '''    let externalEditorDismissSignal: Int
    let isCreating: Bool
    let isReadOnly: Bool
    let onCreate: (([FlightLeg]) -> Void)?'''
)
replace(
    "AppViews.swift",
    '''        externalEditorDismissSignal: Int = 0,
        isCreating: Bool = false,
        onCreate: (([FlightLeg]) -> Void)? = nil''',
    '''        externalEditorDismissSignal: Int = 0,
        isCreating: Bool = false,
        isReadOnly: Bool = false,
        onCreate: (([FlightLeg]) -> Void)? = nil'''
)
replace(
    "AppViews.swift",
    '''        self.externalEditorDismissSignal = externalEditorDismissSignal
        self.isCreating = isCreating
        self.onCreate = onCreate''',
    '''        self.externalEditorDismissSignal = externalEditorDismissSignal
        self.isCreating = isCreating
        self.isReadOnly = isReadOnly
        self.onCreate = onCreate'''
)
replace(
    "AppViews.swift",
    '''        .onChange(of: focusedField) { value in
            onEditorFocusChange?(value != nil)
        }''',
    '''        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != newValue {
                handleEditorBlur(oldValue)
            }
            onEditorFocusChange?(newValue != nil)
        }'''
)
replace(
    "AppViews.swift",
    '''                } else {
                    Button {
                        original = duty.legs''',
    '''                } else if !isReadOnly {
                    Button {
                        original = duty.legs'''
)
replace(
    "AppViews.swift",
    '''                } else {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true''',
    '''                } else if !isReadOnly {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true'''
)


# Manual duty starts with a digits-only flight number and 8-minute taxi times.
p = Path("AppViews.swift")
text = p.read_text()
fn_start = text.index('    private func makeManualDuty() -> FlightDuty {')
fn_end = text.index('\n    }\n}\n\n\n// MARK: - Список смен', fn_start) + len('\n    }')
new_manual = '''    private func makeManualDuty() -> FlightDuty {
        let reference = Date()
        let assignment = nextManualAssignmentNumber()
        let number = "1110"
        let fallbackEngineOn = moscowCalendar.date(byAdding: .minute, value: 60, to: reference) ?? reference
        let fallbackEngineOff = moscowCalendar.date(byAdding: .minute, value: 120, to: fallbackEngineOn) ?? fallbackEngineOn
        let fallbackTimes = PortalFlightTimes(
            workStart: fallbackEngineOn.addingTimeInterval(-60 * 60),
            engineOn: fallbackEngineOn,
            takeoff: fallbackEngineOn.addingTimeInterval(8 * 60),
            landing: fallbackEngineOff.addingTimeInterval(-8 * 60),
            engineOff: fallbackEngineOff,
            workEnd: fallbackEngineOff.addingTimeInterval(30 * 60)
        )
        var leg = FlightLeg(
            date: formatDate(fallbackEngineOn),
            flightNumber: number,
            departure: "SVO",
            arrival: "AER",
            aircraft: AircraftFamilyV129.a320.rawValue,
            registration: "",
            plannedDeparture: formatClock(fallbackEngineOn),
            workStart: formatClock(fallbackTimes.workStart),
            engineOn: formatClock(fallbackEngineOn),
            takeoff: formatClock(fallbackTimes.takeoff),
            landing: formatClock(fallbackTimes.landing),
            engineOff: formatClock(fallbackEngineOff),
            portalTimes: fallbackTimes,
            assignmentNumber: assignment,
            legNumber: number,
            scheduleType: .planned,
            calculatedMinutesOverride: nil
        )
        if let match = DutyAutofillV129.scheduleMatch(
            flightNumber: number,
            referenceDate: reference
        ) {
            leg = DutyAutofillV129.applyingSchedule(
                to: leg,
                match: match,
                index: 0,
                totalCount: 1,
                previousEngineOff: nil
            )
            leg.assignmentNumber = assignment
        }
        return FlightDuty(id: UUID(), legs: [leg])
    }'''
p.write_text(text[:fn_start] + new_manual + text[fn_end:])


# Flight number editor: digits only and updates the real flight number.
replace(
    "AppViews.swift",
    '''                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                maxLength: 7,''',
    '''                keyboardType: .numberPad,
                capitalization: .none,
                maxLength: 4,'''
)
replace(
    "AppViews.swift",
    '''    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { editableLegNumber(draft[index], index: index) },
            set: { draft[index].legNumber = String($0.prefix(7)) }
        )
    }''',
    '''    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { editableLegNumber(draft[index], index: index) },
            set: { raw in
                let digits = DutyAutofillV129.normalizedFlightNumber(raw)
                draft[index].legNumber = digits
                draft[index].flightNumber = digits
            }
        )
    }'''
)
replace(
    "AppViews.swift",
    '''        let numericRegistration = isNumericRegistration(formatted)''',
    '''        let numericRegistration = isCreating || isNumericRegistration(formatted)'''
)


# Aircraft type is a six-option menu.
replace(
    "AppViews.swift",
    '''    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? $draft[index].aircraft
            : .constant(leg.aircraft)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.aircraft(index))
            : .constant(false)

        return identityField("Тип ВС", field: .aircraft(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                field: .aircraft(index),
                keyboardType: .default,
                capitalization: .allCharacters,
                maxLength: 10,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? original[index].aircraft
                    : leg.aircraft
            )
        }
    }''',
    '''    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Тип ВС", field: .aircraft(index)) {
            if isEditing {
                Menu {
                    ForEach(AircraftFamilyV129.allCases) { type in
                        Button(type.rawValue) {
                            selectAircraftType(type, index: index)
                        }
                    }
                } label: {
                    Text(AircraftFamilyV129.display(leg.aircraft))
                        .font(.caption.bold())
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(AircraftFamilyV129.display(leg.aircraft))
                    .font(.caption.bold())
            }
        }
    }'''
)


# Blur hooks: number -> schedule, registration -> aircraft database.
replace(
    "AppViews.swift",
    '''    private func toggleScheduleType(_ index: Int) {''',
    '''    private func handleEditorBlur(_ field: DutyFocusedField?) {
        guard isEditing, let field else { return }
        switch field {
        case .legNumber(let index):
            autofillSchedule(index: index)
        case .registration(let index):
            guard draft.indices.contains(index) else { return }
            draft[index] = DutyAutofillV129.applyingAircraftReference(to: draft[index])
        default:
            break
        }
    }

    private func autofillSchedule(index: Int) {
        guard draft.indices.contains(index) else { return }
        let number = DutyAutofillV129.normalizedFlightNumber(
            editableLegNumber(draft[index], index: index)
        )
        guard !number.isEmpty else { return }
        draft[index].legNumber = number
        draft[index].flightNumber = number

        let previousEnd = index > 0 ? times(for: draft[index - 1]).engineOff : nil
        let reference = previousEnd ?? times(for: draft[index]).engineOn
        var match = DutyAutofillV129.scheduleMatch(
            flightNumber: number,
            referenceDate: reference,
            notBefore: previousEnd,
            departureHint: draft[index].departure,
            arrivalHint: draft[index].arrival
        )
        if match == nil {
            match = DutyAutofillV129.scheduleMatch(
                flightNumber: number,
                referenceDate: reference,
                notBefore: previousEnd
            )
        }
        guard let match else { return }
        draft[index] = DutyAutofillV129.applyingSchedule(
            to: draft[index],
            match: match,
            index: index,
            totalCount: draft.count,
            previousEngineOff: previousEnd
        )
    }

    private func selectAircraftType(_ type: AircraftFamilyV129, index: Int) {
        guard draft.indices.contains(index) else { return }
        let current = AircraftFamilyV129.normalized(draft[index].aircraft)
        let hasRegistration = draft[index].registration.filter(\\.isNumber).count == 5
        if hasRegistration, current != type {
            draft[index].registration = ""
        }
        draft[index].aircraft = type.rawValue
        focusedField = nil
    }

    private func toggleScheduleType(_ index: Int) {'''
)


# Add leg: choose pair from the last actually selected number and load its schedule.
p = Path("AppViews.swift")
text = p.read_text()
fn_start = text.index('    private func appendManualLeg() {')
fn_end = text.index('\n    private func removeManualLeg(at index: Int)', fn_start)
new_append = '''    private func appendManualLeg() {
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

        let previousNumber = editableLegNumber(previousLeg, index: lastIndex)
        let flightNumber = DutyAutofillV129.pairedFlightNumber(after: previousNumber) ?? previousNumber
        let newIndex = draft.count
        let fallbackEngineOn = previousUpdated.engineOff.addingTimeInterval(60 * 60)
        let fallbackEngineOff = fallbackEngineOn.addingTimeInterval(120 * 60)
        let fallbackTimes = PortalFlightTimes(
            workStart: previousUpdated.engineOff,
            engineOn: fallbackEngineOn,
            takeoff: fallbackEngineOn.addingTimeInterval(8 * 60),
            landing: fallbackEngineOff.addingTimeInterval(-8 * 60),
            engineOff: fallbackEngineOff,
            workEnd: fallbackEngineOff.addingTimeInterval(30 * 60)
        )
        var newLeg = FlightLeg(
            date: formatDate(fallbackEngineOn),
            flightNumber: flightNumber,
            departure: previousLeg.arrival,
            arrival: previousLeg.departure,
            aircraft: AircraftFamilyV129.display(previousLeg.aircraft),
            registration: previousLeg.registration,
            plannedDeparture: formatClock(fallbackEngineOn),
            workStart: formatClock(fallbackTimes.workStart),
            engineOn: formatClock(fallbackEngineOn),
            takeoff: formatClock(fallbackTimes.takeoff),
            landing: formatClock(fallbackTimes.landing),
            engineOff: formatClock(fallbackEngineOff),
            portalTimes: fallbackTimes,
            assignmentNumber: assignmentNumber,
            legNumber: flightNumber,
            scheduleType: .planned,
            calculatedMinutesOverride: nil
        )

        var match = DutyAutofillV129.scheduleMatch(
            flightNumber: flightNumber,
            referenceDate: previousUpdated.engineOff,
            notBefore: previousUpdated.engineOff,
            departureHint: previousLeg.arrival,
            arrivalHint: previousLeg.departure
        )
        if match == nil {
            match = DutyAutofillV129.scheduleMatch(
                flightNumber: flightNumber,
                referenceDate: previousUpdated.engineOff,
                notBefore: previousUpdated.engineOff
            )
        }
        if let match {
            newLeg = DutyAutofillV129.applyingSchedule(
                to: newLeg,
                match: match,
                index: newIndex,
                totalCount: newIndex + 1,
                previousEngineOff: previousUpdated.engineOff
            )
            newLeg.assignmentNumber = assignmentNumber
        }
        draft.append(newLeg)
        focusedField = nil
    }
'''
p.write_text(text[:fn_start] + new_append + text[fn_end:])
