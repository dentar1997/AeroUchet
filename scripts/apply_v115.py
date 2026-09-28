from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text(encoding="utf-8")

def replace_between(source: str, start_marker: str, end_marker: str, replacement: str) -> str:
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[:start] + replacement + source[end:]

enums = r'''private enum DutyFlightCountFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case one = "1 рейс"
    case two = "2 рейса"
    case three = "3 рейса"
    case fourPlus = "4+ рейса"
    var id: String { rawValue }
}

private enum DutySortOrder: String, CaseIterable, Identifiable {
    case date = "Дата"
    case dutyDuration = "Полётная смена"
    case flightCount = "Количество рейсов"
    case assignment = "Задание"
    case route = "Маршрут"
    var id: String { rawValue }
}


'''

flights = r'''struct FlightsView: View {
    @ObservedObject var store: AppStore

    @State private var newDuty: FlightDuty?
    @State private var showSearchTools = false
    @State private var showDatePicker = false
    @State private var searchText = ""
    @State private var selectedDate: Date?
    @State private var flightCountFilter: DutyFlightCountFilter = .all
    @State private var sortOrder: DutySortOrder = .date
    @State private var sortDescending = true
    @State private var scrollTargetDutyID: UUID?

    @State private var showImport = false
    @State private var showImportConfirmation = false
    @State private var showImportResult = false
    @State private var importMessage = ""
    @State private var pendingFlights: [FlightLeg] = []
    @State private var verificationStatus = ""

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate ?? Date() },
            set: { selectedDate = $0 }
        )
    }

    private var hasActiveLookup: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedDate != nil
            || flightCountFilter != .all
    }

    private var visibleDuties: [FlightDuty] {
        var values = store.duties.filter { duty in
            matchesCount(duty) && matchesSelectedDate(duty) && matchesSearch(duty)
        }

        func localizedBefore(_ lhs: String, _ rhs: String) -> Bool {
            let comparison = lhs.localizedStandardCompare(rhs)
            return sortDescending
                ? comparison == .orderedDescending
                : comparison == .orderedAscending
        }

        switch sortOrder {
        case .date:
            values.sort { sortDescending ? $0.start > $1.start : $0.start < $1.start }
        case .dutyDuration:
            values.sort {
                if $0.workMinutes == $1.workMinutes {
                    return sortDescending ? $0.start > $1.start : $0.start < $1.start
                }
                return sortDescending
                    ? $0.workMinutes > $1.workMinutes
                    : $0.workMinutes < $1.workMinutes
            }
        case .flightCount:
            values.sort {
                if $0.legs.count == $1.legs.count {
                    return sortDescending ? $0.start > $1.start : $0.start < $1.start
                }
                return sortDescending
                    ? $0.legs.count > $1.legs.count
                    : $0.legs.count < $1.legs.count
            }
        case .assignment:
            values.sort {
                localizedBefore(
                    $0.firstLeg.assignmentNumber ?? "",
                    $1.firstLeg.assignmentNumber ?? ""
                )
            }
        case .route:
            values.sort {
                localizedBefore(
                    AirportDatabase.routeDisplayName(
                        [$0.firstLeg.departure] + $0.legs.map(\.arrival)
                    ),
                    AirportDatabase.routeDisplayName(
                        [$1.firstLeg.departure] + $1.legs.map(\.arrival)
                    )
                )
            }
        }
        return values
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DutiesListView(
                    store: store,
                    duties: visibleDuties,
                    scrollTarget: $scrollTargetDutyID,
                    showsRevealButton: hasActiveLookup,
                    onReveal: revealInFullList
                )

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

                        HStack(spacing: 8) {
                            TextField(
                                "Аэропорт, дата, рейс, борт, тип ВС",
                                text: $searchText
                            )
                            .textFieldStyle(.roundedBorder)

                            Button {
                                showDatePicker.toggle()
                            } label: {
                                Image(systemName: selectedDate == nil
                                      ? "calendar"
                                      : "calendar.badge.checkmark")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Выбрать дату")
                        }

                        if showDatePicker {
                            DatePicker(
                                "Дата",
                                selection: selectedDateBinding,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .environment(\.timeZone, moscowTimeZone)
                        }

                        if let selectedDate {
                            HStack(spacing: 8) {
                                Label(
                                    formatDate(selectedDate),
                                    systemImage: "calendar"
                                )
                                .font(.subheadline.weight(.semibold))

                                Spacer()

                                Button {
                                    self.selectedDate = nil
                                    showDatePicker = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Сбросить дату")
                            }
                        }

                        Divider()

                        Picker("Количество рейсов", selection: $flightCountFilter) {
                            ForEach(DutyFlightCountFilter.allCases) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack(spacing: 8) {
                            Picker("Сортировка", selection: $sortOrder) {
                                ForEach(DutySortOrder.allCases) { value in
                                    Text(value.rawValue).tag(value)
                                }
                            }
                            .pickerStyle(.menu)

                            Button {
                                sortDescending.toggle()
                            } label: {
                                Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                sortDescending ? "По убыванию" : "По возрастанию"
                            )
                        }

                        HStack {
                            Button("Сбросить") {
                                searchText = ""
                                selectedDate = nil
                                showDatePicker = false
                                flightCountFilter = .all
                                sortOrder = .date
                                sortDescending = true
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("Готово") {
                                showSearchTools = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(16)
                    .frame(width: 360)
                    .presentationCompactAdaptation(.popover)
                }

                Menu {
                    Button {
                        showImport = true
                    } label: {
                        Label(
                            "Импорт истории рейсов из файла",
                            systemImage: "square.and.arrow.down"
                        )
                    }

                    Button {
                        newDuty = makeManualDuty()
                    } label: {
                        Label(
                            "Создать задание на полёт самостоятельно",
                            systemImage: "airplane.badge.plus"
                        )
                    }

                    Button {
                    } label: {
                        Label(
                            "Добавить перспективный план · в разработке",
                            systemImage: "calendar.badge.plus"
                        )
                    }
                    .disabled(true)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить")
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
        case .fourPlus: return duty.legs.count >= 4
        }
    }

    private func matchesSelectedDate(_ duty: FlightDuty) -> Bool {
        guard let selectedDate else { return true }
        return moscowCalendar.isDate(duty.start, inSameDayAs: selectedDate)
    }

    private func matchesSearch(_ duty: FlightDuty) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let needle = query.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        func contains(_ value: String) -> Bool {
            value.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            .contains(needle)
        }

        if contains(formatDate(duty.start)) {
            return true
        }

        return duty.legs.contains { leg in
            contains(leg.departure)
                || contains(AirportDatabase.displayName(for: leg.departure))
                || contains(leg.flightNumber)
                || contains(leg.legNumber ?? "")
                || contains(formattedRegistration(leg.registration))
                || contains(leg.aircraft)
        }
    }

    private func revealInFullList(_ duty: FlightDuty) {
        showSearchTools = false
        searchText = ""
        selectedDate = nil
        showDatePicker = false
        flightCountFilter = .all

        DispatchQueue.main.async {
            scrollTargetDutyID = duty.id
        }
    }

    private func nextManualAssignmentNumber() -> String {
        let values = store.flights.compactMap(\.assignmentNumber)

        func number(for value: String, prefix: String) -> Int? {
            let compact = value.replacingOccurrences(of: " ", with: "")
            guard compact.hasPrefix(prefix) else { return nil }
            return Int(compact.dropFirst(prefix.count))
        }

        let manualNumbers = values.compactMap { number(for: $0, prefix: "Manual") }
        let next = (manualNumbers.max() ?? 0) + 1
        if next <= 999 {
            return String(format: "Manual%03d", next)
        }

        let overflowNumbers = values.compactMap { number(for: $0, prefix: "ManuA") }
        return String(format: "ManuA%03d", (overflowNumbers.max() ?? 0) + 1)
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
            flightNumber: "11-10",
            departure: "SVO",
            arrival: "AER",
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
            legNumber: "11-10",
            scheduleType: .planned,
            calculatedMinutesOverride: nil
        )
        return FlightDuty(id: UUID(), legs: [leg])
    }
}


'''

duties_list = r'''struct DutiesListView: View {
    @ObservedObject var store: AppStore
    let duties: [FlightDuty]
    @Binding var scrollTarget: UUID?
    let showsRevealButton: Bool
    let onReveal: (FlightDuty) -> Void

    @State private var selectedDuty: FlightDuty?

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List(duties) { duty in
                    HStack(spacing: 8) {
                        Button {
                            selectedDuty = duty
                        } label: {
                            DutyRow(duty: duty)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if showsRevealButton {
                            Button {
                                onReveal(duty)
                            } label: {
                                Image(systemName: "list.bullet.rectangle")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Показать в общем списке")
                        }
                    }
                    .id(duty.id)
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(target, anchor: .center)
                        }
                        scrollTarget = nil
                    }
                }
            }
            .scrollDisabled(selectedDuty != nil)
            .allowsHitTesting(selectedDuty == nil)
            .accessibilityHidden(selectedDuty != nil)

            if let duty = selectedDuty {
                DutyAssignmentOverlay(duty: duty, store: store) {
                    selectedDuty = nil
                }
                .zIndex(1)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}


'''

duty_card = r'''    // Уровень 1: одна общая карточка полётного задания.
    private func dutyCard(_ duty: FlightDuty) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if duty.legs.count > 1 {
                dutyTotals(duty)
            }

            ForEach(duty.legs.indices, id: \.self) { index in
                SwipeDeleteFlightCard(
                    isEnabled: isCreating
                        && draft.count > 3
                        && index > 0
                        && focusedField == nil,
                    onDelete: {
                        removeManualLeg(at: index)
                    }
                ) {
                    legCard(
                        duty.legs[index],
                        index: index,
                        workEnd: duty.workIntervals[index].end
                    )
                    .zIndex(legEditorZIndex(index))
                }

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
                        Text("Добавить рейс \(draft.count + 1)")
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
        }
    }

'''

count_func = r'''    private func deletionFlightCountText(_ count: Int) -> String {
        count == 1 ? "1 рейсом" : "\(count) рейсами"
    }

'''

append_remove = r'''    private func appendManualLeg() {
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

        let newIndex = draft.count
        let outbound = newIndex.isMultiple(of: 2)
        let flightNumber = outbound ? "11-10" : "11-11"
        let departure = outbound ? "SVO" : "AER"
        let arrival = outbound ? "AER" : "SVO"

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
            flightNumber: flightNumber,
            departure: departure,
            arrival: arrival,
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
            legNumber: flightNumber,
            scheduleType: .planned,
            calculatedMinutesOverride: nil
        )
        draft.append(newLeg)
        focusedField = nil
    }

    private func removeManualLeg(at index: Int) {
        guard isCreating, draft.count > 3, index > 0, draft.indices.contains(index) else {
            return
        }

        focusedField = nil
        draft.remove(at: index)

        for currentIndex in draft.indices {
            var leg = draft[currentIndex]
            let values = times(for: leg)
            let workEnd = currentIndex == draft.indices.last
                ? (moscowCalendar.date(
                    byAdding: .minute,
                    value: 30,
                    to: values.engineOff
                ) ?? values.engineOff)
                : values.engineOff

            leg.portalTimes = PortalFlightTimes(
                workStart: values.workStart,
                engineOn: values.engineOn,
                takeoff: values.takeoff,
                landing: values.landing,
                engineOff: values.engineOff,
                workEnd: workEnd
            )
            leg.workStart = formatClock(values.workStart)
            leg.engineOn = formatClock(values.engineOn)
            leg.takeoff = formatClock(values.takeoff)
            leg.landing = formatClock(values.landing)
            leg.engineOff = formatClock(values.engineOff)
            draft[currentIndex] = leg
        }
    }

'''

swipe_struct = r'''private struct SwipeDeleteFlightCard<Content: View>: View {
    let isEnabled: Bool
    let onDelete: () -> Void
    let content: () -> Content

    @State private var horizontalOffset: CGFloat = 0

    init(
        isEnabled: Bool,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEnabled = isEnabled
        self.onDelete = onDelete
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if isEnabled {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalOffset = 0
                    }
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .accessibilityLabel("Удалить рейс")
            }

            content()
                .offset(x: horizontalOffset)
        }
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    guard isEnabled else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        return
                    }
                    guard value.translation.width < 0 else {
                        horizontalOffset = 0
                        return
                    }
                    horizontalOffset = max(-66, value.translation.width)
                }
                .onEnded { value in
                    guard isEnabled else {
                        horizontalOffset = 0
                        return
                    }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        withAnimation(.easeOut(duration: 0.16)) {
                            horizontalOffset = 0
                        }
                        return
                    }

                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalOffset = value.translation.width < -30 ? -62 : 0
                    }
                }
        )
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                horizontalOffset = 0
            }
        }
    }
}


'''

old_restore = r'''        .overlay(alignment: .bottomTrailing) {
            if isEditing && hasChanges {
                Button {
                    onRestore()
                    activePart = nil
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 6)
                .accessibilityLabel("Вернуть исходное расчётное время")
            }
        }
'''

new_restore = r'''        .overlay(alignment: .bottomTrailing) {
            if isEditing && hasChanges {
                Button {
                    activePart = nil
                    onRestore()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.trailing, -7)
                .padding(.bottom, -1)
                .zIndex(10000)
                .highPriorityGesture(
                    TapGesture().onEnded {
                        activePart = nil
                        onRestore()
                    }
                )
                .accessibilityLabel("Вернуть исходное расчётное время")
            }
        }
'''

start = text.index("private enum DutySearchField:")
end = text.index("struct FlightsView: View {", start)
text = text[:start] + enums + text[end:]
text = replace_between(
    text,
    "struct FlightsView: View {",
    "// MARK: - Список смен",
    flights + "// MARK: - Список смен\n\n"
)
text = replace_between(
    text,
    "struct DutiesListView: View {",
    "private struct DutyAssignmentOverlay: View {",
    duties_list + "private struct DutyAssignmentOverlay: View {"
)
text = replace_between(
    text,
    "    // Уровень 1: одна общая карточка полётного задания.\n    private func dutyCard",
    "    private func deletionFlightCountText",
    duty_card + "    private func deletionFlightCountText"
)
text = replace_between(
    text,
    "    private func deletionFlightCountText",
    "    private func appendManualLeg",
    count_func + "    private func appendManualLeg"
)
text = replace_between(
    text,
    "    private func appendManualLeg",
    "    private func restCard",
    append_remove + "    private func restCard"
)

marker = "private struct InlineCalculatedTimeValue: View {"
text = text.replace(marker, swipe_struct + marker, 1)

if old_restore not in text:
    raise SystemExit("restore block not found")
text = text.replace(old_restore, new_restore, 1)

path.write_text(text, encoding="utf-8")

version = Path("AppVersion.swift")
version_text = version.read_text(encoding="utf-8")
version_text = version_text.replace("static let number = 114", "static let number = 115")
version_text = version_text.replace('static let label = "Версия 114"', 'static let label = "Версия 115"')
version.write_text(version_text, encoding="utf-8")
