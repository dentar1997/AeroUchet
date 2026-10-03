import SwiftUI
import Foundation
import UIKit
import UniformTypeIdentifiers


// MARK: - Главная

struct HomeView: View {
    
    @ObservedObject
    var store: AppStore
    
    
    let columns = [
        
        GridItem(
            .adaptive(
                minimum: 150
            ),
            spacing: 12
        )
    ]
    
    
    var body: some View {
        
        let duties =
        store.duties
        
        
        let index =
        store.dailyIndex
        
        
        let activeMonth =
        startOfMonth(
            store.latestActivityDate
            ?? Date()
        )
        
        
        let totals =
        monthTotals(
            month:
                activeMonth,
            index:
                index
        )
        
        
        NavigationStack {
            
            ScrollView {
                
                VStack(
                    alignment:
                            .leading,
                    spacing: 20
                ) {
                    
                    HStack {
                        Text(AppVersion.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    
                    Text(
                        monthTitle(
                            activeMonth
                        )
                    )
                    .font(.title2)
                    .bold()
                    
                    
                    Text(
                        "Итоги месяца"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    
                    
                    LazyVGrid(
                        columns:
                            columns,
                        spacing: 12
                    ) {
                        
                        MetricCard(
                            title:
                                "Расчётные часы",
                            value:
                                "Пока —",
                            icon:
                                "clock"
                        )
                        
                        
                        MetricCard(
                            title:
                                "Полётное",
                            value:
                                timeText(
                                    totals.flightMinutes
                                ),
                            icon:
                                "airplane"
                        )
                        
                        
                        MetricCard(
                            title:
                                "Лётное",
                            value:
                                timeText(
                                    totals.airMinutes
                                ),
                            icon:
                                "airplane.circle"
                        )
                        
                        
                        MetricCard(
                            title:
                                "Рабочее всего",
                            value:
                                timeText(
                                    totals.workMinutes
                                ),
                            icon:
                                "briefcase.fill"
                        )
                        
                        
                        MetricCard(
                            title:
                                "Рабочее — рейсы",
                            value:
                                timeText(
                                    totals.flightWorkMinutes
                                ),
                            icon:
                                "airplane.departure"
                        )
                        
                        
                        MetricCard(
                            title:
                                "Рабочее — земля",
                            value:
                                timeText(
                                    totals.groundWorkMinutes
                                ),
                            icon:
                                "building.2"
                        )
                    }
                    
                    
                    Text(
                        "Последние смены"
                    )
                    .font(.title2)
                    .bold()
                    
                    
                    ForEach(
                        duties.prefix(4)
                    ) { duty in
                        
                        EventRow(
                            icon:
                                "airplane",
                            title:
                                duty.routeText,
                            subtitle:
                                "\(formatDate(duty.start)) • \(timeText(duty.workMinutes)) рабочего"
                        )
                    }
                }
                .padding()
            }
            
            
            .navigationTitle(
                "АэроУчёт"
            )
        }
    }
}


// MARK: - Полёты

private enum DutyFlightCountFilter: String, CaseIterable, Identifiable {
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


struct FlightsView: View {
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
        // Без собственного NavigationStack: FlightsView живёт внутри
        // общей панели вкладки «Назначения» (см. AssignmentsView).
        Group {
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


// MARK: - Список смен

struct DutiesListView: View {
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


private struct DutyAssignmentOverlay: View {
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

    @State private var settledDragOffset: CGFloat = 0
    @GestureState private var gestureDragOffset: CGFloat = 0
    @State private var editorIsActive = false
    @State private var editModeIsActive = false
    @State private var scrollIsAtTop = true
    @State private var scrollContentIsScrollable = false
    @State private var dragSessionActive = false
    @State private var dragSessionEligible = false
    @State private var dismissEditorSignal = 0

    private var dragOffset: CGFloat {
        settledDragOffset + gestureDragOffset
    }

    var body: some View {
        GeometryReader { geometry in
            // Ширина задания ориентирована на естественную ширину
            // верхней строки из пяти компактных полей leg.
            let width = min(geometry.size.width * 0.92, 556)

            ZStack {
                Color.black
                    .opacity(backgroundOpacity(for: geometry.size.height))
                    .ignoresSafeArea()
                    .onTapGesture {
                        if editorIsActive {
                            dismissEditorSignal += 1
                        } else if isCreating || !editModeIsActive {
                            onClose()
                        }
                    }

                ScrollView(.vertical) {
                    DutyDetailView(
                        duty: duty,
                        onClose: onClose,
                        scrollsAsPage: true,
                        onEditorFocusChange: { editorIsActive = $0 },
                        onEditModeChange: { editModeIsActive = $0 },
                        externalEditorDismissSignal: dismissEditorSignal,
                        isCreating: isCreating,
                        onCreate: onCreate
                    )
                    .environmentObject(store)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                    .background {
                        // This belongs to the scroll content, so blank margins
                        // receive taps instead of the ScrollView swallowing them.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if editorIsActive {
                                    dismissEditorSignal += 1
                                } else if !editModeIsActive {
                                    onClose()
                                }
                            }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top <= 0.5
                } action: { _, newValue in
                    scrollIsAtTop = newValue
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height + 1
                } action: { _, newValue in
                    scrollContentIsScrollable = newValue
                }
                .scrollDisabled(editorIsActive)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .offset(y: dragOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    dismissDrag(
                        in: geometry.size.height,
                        canStart: !editorIsActive
                            && (isCreating || !editModeIsActive)
                            && scrollIsAtTop,
                        allowUpwardRubberBand: !scrollContentIsScrollable
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func backgroundOpacity(for height: CGFloat) -> Double {
        guard height > 0 else { return 0.65 }
        let progress = min(max(dragOffset / height, 0), 1)
        return 0.65 * Double(1 - progress * 0.75)
    }

    private func dismissDrag(
        in height: CGFloat,
        canStart: Bool,
        allowUpwardRubberBand: Bool
    ) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($gestureDragOffset) { value, state, transaction in
                guard dragSessionEligible else {
                    state = 0
                    return
                }

                transaction.animation = nil
                state = interactiveOffset(
                    for: value.translation.height,
                    allowUpwardRubberBand: allowUpwardRubberBand
                )
            }
            .onChanged { value in
                guard !dragSessionActive else { return }
                dragSessionActive = true
                dragSessionEligible = canStart
                    && (allowUpwardRubberBand || value.translation.height > 0)
            }
            .onEnded { value in
                let eligible = dragSessionEligible
                dragSessionActive = false
                dragSessionEligible = false

                guard eligible else {
                    settledDragOffset = 0
                    return
                }

                let releasedOffset = interactiveOffset(
                    for: value.translation.height,
                    allowUpwardRubberBand: allowUpwardRubberBand
                )
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    settledDragOffset = releasedOffset
                }

                let predicted = max(
                    value.translation.height,
                    value.predictedEndTranslation.height
                )
                let shouldClose =
                    value.translation.height > 110
                    || predicted > 220

                if shouldClose {
                    withAnimation(
                        .spring(response: 0.34, dampingFraction: 0.92)
                    ) {
                        settledDragOffset = max(height + 80, 580)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                        onClose()
                    }
                } else {
                    withAnimation(
                        .spring(response: 0.42, dampingFraction: 0.88)
                    ) {
                        settledDragOffset = 0
                    }
                }
            }
    }

    private func interactiveOffset(
        for translation: CGFloat,
        allowUpwardRubberBand: Bool
    ) -> CGFloat {
        guard translation < 0 else { return translation }
        return allowUpwardRubberBand ? upwardRubberBand(translation) : 0
    }

    private func upwardRubberBand(_ translation: CGFloat) -> CGFloat {
        let distance = abs(min(translation, 0))
        let maxLift: CGFloat = 36
        let softness: CGFloat = 90
        return -maxLift * distance / (distance + softness)
    }
}


// MARK: - Строка смены

struct DutyRow: View {
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


// MARK: - Детали смены

struct DutyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let duty: FlightDuty
    let onClose: (() -> Void)?
    let scrollsAsPage: Bool
    let onEditorFocusChange: ((Bool) -> Void)?
    let onEditModeChange: ((Bool) -> Void)?
    let externalEditorDismissSignal: Int
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

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    @State private var isEditing = false
    @State private var draft: [FlightLeg] = []
    @State private var original: [FlightLeg] = []
    @State private var assignmentNumber = ""
    @State private var showReview = false
    @State private var showDeleteConfirmation = false
    @State private var focusedField: DutyFocusedField?
    @State private var editHistory: [DutyEditSnapshot] = []
    @State private var historyIndex = 0
    @State private var routeEditSide: RouteEditSide = .departure
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let timeColumns = Array(
        repeating: GridItem(.fixed(160), spacing: 8),
        count: 3
    )

    // Контраст плиток не зависит от уровня модального представления iPadOS.
    private var valueTileColor: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 0.36, alpha: 1)
            }
            return UIColor(white: 0.88, alpha: 1)
        })
    }

    private var current: FlightDuty {
        if isCreating, !draft.isEmpty {
            return FlightDuty(id: duty.id, legs: updatedLegs)
        }
        return store.duties.first { candidate in
            candidate.legs.contains { $0.id == duty.firstLeg.id }
        } ?? duty
    }

    private var editorCoversHeader: Bool {
        switch focusedField {
        case .time, .calculatedTime, .route:
            return true
        default:
            return false
        }
    }

    var body: some View {
        let current = current

        VStack(spacing: 0) {
            assignmentHeader(current)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(editorCoversHeader ? 0 : 1)

            if scrollsAsPage {
                assignmentContents(current)
                    .zIndex(editorCoversHeader ? 100 : 0)
            } else {
                ScrollView {
                    assignmentContents(current)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .zIndex(editorCoversHeader ? 100 : 0)
            }
        }
        .onAppear {
            if isCreating { onEditModeChange?(true) }
        }
        .onChange(of: draft) { _ in recordEdit() }
        .onChange(of: assignmentNumber) { _ in recordEdit() }
        .onChange(of: focusedField) { value in
            onEditorFocusChange?(value != nil)
        }
        .onChange(of: isEditing) { value in
            onEditModeChange?(value)
        }
        .onChange(of: externalEditorDismissSignal) { _ in
            focusedField = nil
        }
        .onDisappear {
            onEditorFocusChange?(false)
            onEditModeChange?(false)
        }
        .environment(\.timeZone, moscowTimeZone)
        .background {
            // Behind the controls: blank card/header space dismisses the
            // editor, while visible buttons and picker controls get the tap.
            Color.clear
                .contentShape(RoundedRectangle(cornerRadius: 20))
                .onTapGesture { focusedField = nil }
        }
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )

    }

    private func assignmentHeader(_ duty: FlightDuty) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                if isEditing {
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
                        focusedField = nil
                        showReview = true
                    } label: {
                        Image(systemName: "checkmark")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(!isValid || (!isCreating && differences.isEmpty))
                    .accessibilityLabel(isCreating ? "Сохранить задание на полёт" : "Применить изменения")
                    .popover(isPresented: $showReview, arrowEdge: .top) {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                            Text(isCreating ? "Сохранить задание на полёт?" : "Сохранить изменения?")
                                .font(.headline)
                            Text(isCreating
                                 ? "Новое задание на полёт будет добавлено."
                                 : "Данные задания на полёт будут обновлены.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 10) {
                                Button("Отмена") { showReview = false }
                                    .buttonStyle(.bordered)
                                Button("Сохранить") {
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
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(16)
                        .frame(width: 260)
                        .font(.subheadline)
                        .presentationCompactAdaptation(.popover)
                    }
                } else {
                    Button {
                        original = duty.legs
                        draft = duty.legs
                        assignmentNumber = duty.firstLeg.assignmentNumber ?? ""
                        editHistory = [
                            DutyEditSnapshot(
                                legs: draft,
                                assignment: assignmentNumber
                            )
                        ]
                        historyIndex = 0
                        isEditing = true
                    } label: {
                        Image(systemName: "wrench")
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityLabel("Редактировать задание на полёт")
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .labelStyle(.iconOnly)
            .frame(width: 104, alignment: .leading)

            dutyTitle(
                isEditing && !draft.isEmpty
                ? FlightDuty(id: duty.id, legs: updatedLegs)
                : duty
            )
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                if isEditing {
                    Button {
                        restoreEdit(at: historyIndex - 1)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(historyIndex == 0)
                    .accessibilityLabel("Отменить последнее изменение")

                    Button {
                        restoreEdit(at: historyIndex + 1)
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(historyIndex + 1 >= editHistory.count)
                    .accessibilityLabel("Повторить изменение")
                } else {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityLabel("Удалить задание на полёт")
                    .popover(isPresented: $showDeleteConfirmation, arrowEdge: .top) {
                        VStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                            Text("Удалить задание на полёт?")
                                .font(.headline)
                            Text("Задание с \(deletionFlightCountText(duty.legs.count)) будет удалено.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 10) {
                                Button("Отмена") {
                                    showDeleteConfirmation = false
                                }
                                .buttonStyle(.bordered)

                                Button("Удалить") {
                                    showDeleteConfirmation = false
                                    store.deleteDutyLegs(ids: Set(duty.legs.map(\.id)))
                                    close()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }
                        }
                        .padding(16)
                        .frame(width: 260)
                        .font(.subheadline)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .labelStyle(.iconOnly)
            .frame(width: 104, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }

    private func recordEdit() {
        guard isEditing else { return }
        let snapshot = DutyEditSnapshot(legs: draft, assignment: assignmentNumber)
        guard editHistory.indices.contains(historyIndex),
              editHistory[historyIndex] != snapshot else { return }
        editHistory = Array(editHistory.prefix(historyIndex + 1))
        editHistory.append(snapshot)
        historyIndex = editHistory.count - 1
    }

    private func restoreEdit(at index: Int) {
        guard editHistory.indices.contains(index) else { return }
        focusedField = nil
        historyIndex = index
        draft = editHistory[index].legs
        assignmentNumber = editHistory[index].assignment
    }

    private func assignmentContents(_ duty: FlightDuty) -> some View {
        dutyCard(isEditing && !draft.isEmpty
                 ? FlightDuty(id: duty.id, legs: updatedLegs)
                 : duty)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = nil }
            }
    }

    private var updatedLegs: [FlightLeg] {
        let number = assignmentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return draft.map { leg in
            var updated = leg
            updated.assignmentNumber = number.isEmpty ? nil : number
            updated.departure = leg.departure.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            updated.arrival = leg.arrival.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            updated.registration = leg.registration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return updated
        }
    }

    private var isValid: Bool {
        let legs = updatedLegs
        guard !legs.isEmpty, legs.allSatisfy({
            !$0.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.departure.isEmpty && !$0.arrival.isEmpty
            && $0.hasValidStoredDates
        }) else { return false }

        let dates = legs.flatMap { leg in
            let values = times(for: leg)
            return DutyEditPoint.allCases.map { $0.date(in: values) }
        }
        guard let first = dates.first, let last = dates.max() else { return false }
        let daySpan = moscowCalendar.dateComponents(
            [.day],
            from: moscowCalendar.startOfDay(for: first),
            to: moscowCalendar.startOfDay(for: last)
        ).day ?? 0
        guard (0...1).contains(daySpan) else { return false }

        let legsAreOrdered = zip(legs, legs.dropFirst()).allSatisfy {
            times(for: $0.0).workStart <= times(for: $0.1).workStart
        }
        let eachLegIsOrdered = legs.allSatisfy { leg in
            let values = times(for: leg)
            let dates = DutyEditPoint.allCases.map { $0.date(in: values) }
            return zip(dates, dates.dropFirst()).allSatisfy { $0 <= $1 }
        }
        return legsAreOrdered && eachLegIsOrdered
    }

    private var differences: [String] {
        zip(original, updatedLegs).flatMap { old, new -> [String] in
            var result: [String] = []
            let label = "Рейс № \(old.displayedLegNumber): "
            func add(_ title: String, _ before: String, _ after: String) {
                if before != after {
                    result.append(label + title + ": " + before + " → " + after)
                }
            }

            add("Номер задания", old.assignmentNumber ?? "—", new.assignmentNumber ?? "—")
            add("Номер рейса", old.flightNumber, new.flightNumber)
            add("Номер лега", editableLegNumber(old), editableLegNumber(new))
            add("Вылет", old.departure, new.departure)
            add("Прилёт", old.arrival, new.arrival)
            add("Тип ВС", old.aircraft, new.aircraft)
            add("Борт", old.registration, new.registration)
            add("Тип рейса", (old.scheduleType ?? .planned).rawValue,
                (new.scheduleType ?? .planned).rawValue)
            add(
                "Расчётное время",
                old.calculatedMinutesOverride.map(timeText) ?? "Из таблицы",
                new.calculatedMinutesOverride.map(timeText) ?? "Из таблицы"
            )

            let oldTimes = times(for: old)
            let newTimes = times(for: new)
            for point in DutyEditPoint.allCases {
                add(point.title,
                    formatDateTime(point.date(in: oldTimes)),
                    formatDateTime(point.date(in: newTimes)))
            }
            return result
        }
    }


    private func editableLegNumber(_ leg: FlightLeg, index: Int? = nil) -> String {
        if let legNumber = leg.legNumber {
            return legNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parts = leg.flightNumber
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let index, parts.indices.contains(index), !parts[index].isEmpty {
            return parts[index]
        }
        if parts.count == 1, let only = parts.first {
            return only
        }
        return leg.displayedLegNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { editableLegNumber(draft[index], index: index) },
            set: { draft[index].legNumber = String($0.prefix(7)) }
        )
    }

    private func registrationDigitsBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let compact = draft[index].registration
                    .uppercased()
                    .replacingOccurrences(of: "-", with: "")
                if compact.hasPrefix("RA") {
                    return String(compact.dropFirst(2).filter(\.isNumber).prefix(5))
                }
                return String(compact.filter(\.isNumber).prefix(5))
            },
            set: { newValue in
                let digits = String(newValue.filter(\.isNumber).prefix(5))
                draft[index].registration = "RA-" + digits
            }
        )
    }

    private func registrationTextBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { formattedRegistration(draft[index].registration) },
            set: { rawValue in
                let normalized = String(
                    rawValue
                        .uppercased()
                        .filter { character in
                            character.isASCII
                                && (character.isLetter || character.isNumber || character == "-")
                        }
                        .prefix(8)
                )
                draft[index].registration = normalized
            }
        )
    }

    private func registrationComparisonKey(_ rawValue: String) -> String {
        let formatted = formattedRegistration(rawValue)
        if formatted.hasPrefix("RA-") {
            return String(formatted.dropFirst(3))
        }
        return formatted
    }

    private func isNumericRegistration(_ rawValue: String) -> Bool {
        let formatted = formattedRegistration(rawValue)
        guard formatted.hasPrefix("RA-") else { return false }
        let suffix = formatted.dropFirst(3)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }

    private func toggleScheduleType(_ index: Int) {
        let current = draft[index].scheduleType ?? .planned

        if current == .planned {
            draft[index].scheduleType = .unscheduled
            draft[index].calculatedMinutesOverride = draft[index].flightMinutes
        } else {
            draft[index].scheduleType = .planned
        }

        focusedField = nil
    }

    private func scheduleBinding(_ index: Int) -> Binding<FlightScheduleType> {
        Binding(
            get: { draft[index].scheduleType ?? .planned },
            set: { draft[index].scheduleType = $0 }
        )
    }

    private func times(for leg: FlightLeg) -> PortalFlightTimes {
        if let portal = leg.portalTimes { return portal }
        let t = leg.timeline
        return PortalFlightTimes(
            workStart: t.workStart,
            engineOn: t.engineOn,
            takeoff: t.takeoff,
            landing: t.landing,
            engineOff: t.engineOff,
            workEnd: t.workEnd ?? moscowCalendar.date(
                byAdding: .minute, value: 30, to: t.engineOff
            )!
        )
    }

    private func timeBinding(_ index: Int, _ point: DutyEditPoint) -> Binding<Date> {
        Binding(
            get: { point.date(in: times(for: draft[index])) },
            set: { setDutyTime($0, index: index, point: point) }
        )
    }

    private var orderedDutyPoints: [(index: Int, point: DutyEditPoint)] {
        draft.indices.flatMap { index in
            DutyEditPoint.allCases.map { (index: index, point: $0) }
        }
    }

    private func dayOffset(_ date: Date) -> Int {
        guard let first = draft.first else { return 0 }
        return moscowCalendar.dateComponents(
            [.day],
            from: moscowCalendar.startOfDay(for: times(for: first).workStart),
            to: moscowCalendar.startOfDay(for: date)
        ).day ?? 0
    }

    private func canToggleDutyDate(index: Int, point: DutyEditPoint) -> Bool {
        let points = orderedDutyPoints
        guard let position = points.firstIndex(where: { $0.index == index && $0.point == point }),
              position > 0 else { return false }
        let previous = points[position - 1]
        let previousDate = previous.point.date(in: times(for: draft[previous.index]))
        let currentDate = point.date(in: times(for: draft[index]))
        return dayOffset(previousDate) == 0 && (0...1).contains(dayOffset(currentDate))
    }

    private func toggleDutyDate(index: Int, point: DutyEditPoint) {
        guard canToggleDutyDate(index: index, point: point) else { return }
        let points = orderedDutyPoints
        guard let position = points.firstIndex(where: { $0.index == index && $0.point == point })
        else { return }

        let current = point.date(in: times(for: draft[index]))
        let goingForward = dayOffset(current) == 0
        let delta = goingForward ? 1 : -1
        guard let changed = moscowCalendar.date(byAdding: .day, value: delta, to: current)
        else { return }
        writeDutyTime(changed, index: index, point: point)

        // A jump to tomorrow carries following events with it. Tapping again
        // brings them back; chronological normalization may retain tomorrow
        // for a later clock time that cannot fit on the first day.
        for item in points.dropFirst(position + 1) {
            let date = item.point.date(in: times(for: draft[item.index]))
            if dayOffset(date) == (goingForward ? 0 : 1),
               let shifted = moscowCalendar.date(byAdding: .day, value: delta, to: date) {
                writeDutyTime(shifted, index: item.index, point: item.point)
            }
        }
        normalizeDuty(after: position)
    }

    private func setDutyTime(_ date: Date, index: Int, point: DutyEditPoint) {
        let points = orderedDutyPoints
        guard let position = points.firstIndex(where: { $0.index == index && $0.point == point })
        else { return }
        let previousStart = draft.first.map { times(for: $0).workStart }
        writeDutyTime(date, index: index, point: point)

        if position == 0, let previousStart {
            let delta = moscowCalendar.dateComponents(
                [.day],
                from: moscowCalendar.startOfDay(for: previousStart),
                to: moscowCalendar.startOfDay(for: date)
            ).day ?? 0
            if delta != 0 {
                for item in points.dropFirst() {
                    let value = item.point.date(in: times(for: draft[item.index]))
                    if let shifted = moscowCalendar.date(byAdding: .day, value: delta, to: value) {
                        writeDutyTime(shifted, index: item.index, point: item.point)
                    }
                }
            }
        }
        normalizeDuty(after: position)
    }

    private func normalizeDuty(after position: Int) {
        let points = orderedDutyPoints
        guard !points.isEmpty else { return }
        let start = times(for: draft[points[0].index]).workStart
        let secondDay = moscowCalendar.date(
            byAdding: .day, value: 1, to: moscowCalendar.startOfDay(for: start)
        ) ?? start

        for offset in max(1, position)...max(1, points.count - 1) {
            guard offset < points.count else { break }
            let previous = points[offset - 1]
            let item = points[offset]
            let minimum: Date
            if item.index != previous.index && item.point == .workStart {
                minimum = times(for: draft[previous.index]).workStart
            } else {
                minimum = previous.point.date(in: times(for: draft[previous.index]))
            }
            let existing = item.point.date(in: times(for: draft[item.index]))
            var candidate = existing

            if candidate < minimum {
                let clock = moscowCalendar.dateComponents([.hour, .minute], from: existing)
                candidate = moscowCalendar.date(
                    bySettingHour: clock.hour ?? 0,
                    minute: clock.minute ?? 0,
                    second: 0,
                    of: minimum
                ) ?? minimum
                if candidate < minimum {
                    candidate = moscowCalendar.date(byAdding: .day, value: 1, to: candidate)
                        ?? minimum
                }
            }

            if moscowCalendar.startOfDay(for: candidate) > secondDay {
                candidate = max(minimum, moscowCalendar.date(
                    bySettingHour: moscowCalendar.component(.hour, from: existing),
                    minute: moscowCalendar.component(.minute, from: existing),
                    second: 0,
                    of: secondDay
                ) ?? minimum)
            }
            if candidate != existing {
                writeDutyTime(candidate, index: item.index, point: item.point)
            }
        }
    }

    private func writeDutyTime(_ newDate: Date, index: Int, point: DutyEditPoint) {
        guard draft.indices.contains(index) else { return }
        var leg = draft[index]
        let previous = times(for: leg)
        let updated = PortalFlightTimes(
            workStart: point == .workStart ? newDate : previous.workStart,
            engineOn: point == .engineOn ? newDate : previous.engineOn,
            takeoff: point == .takeoff ? newDate : previous.takeoff,
            landing: point == .landing ? newDate : previous.landing,
            engineOff: point == .engineOff ? newDate : previous.engineOff,
            workEnd: point == .workEnd ? newDate :
                (point == .engineOff && index == draft.count - 1
                 ? max(previous.workEnd, newDate) : previous.workEnd)
        )
        leg.portalTimes = updated
        leg.date = formatDate(updated.engineOn)
        leg.workStart = formatClock(updated.workStart)
        leg.engineOn = formatClock(updated.engineOn)
        leg.takeoff = formatClock(updated.takeoff)
        leg.landing = formatClock(updated.landing)
        leg.engineOff = formatClock(updated.engineOff)
        draft[index] = leg
    }
    // Уровень 1: одна общая карточка полётного задания.
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

    private func deletionFlightCountText(_ count: Int) -> String {
        count == 1 ? "1 рейсом" : "\(count) рейсами"
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

    private func restCard(start: Date, end: Date) -> some View {
        let restMinutes = minutesBetween(start, end)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Разделённая полётная смена")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: "moon.zzz")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 6) {
                legValueCard(
                    title: "Рабочее время",
                    value: "\(timeText(restMinutes)) → \(quarterRestText(restMinutes))"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { focusedField = nil }
        )
        .accessibilityElement(children: .combine)
    }

    private func quarterRestText(_ minutes: Int) -> String {
        let seconds = max(0, minutes) * 15
        let hours = seconds / 3_600
        let remainingMinutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        let hoursAndMinutes = String(format: "%02d:%02d", hours, remainingMinutes)
        return remainingSeconds == 0
            ? hoursAndMinutes
            : hoursAndMinutes + String(format: ":%02d", remainingSeconds)
    }

    private func dutyTitle(_ duty: FlightDuty) -> some View {
        HStack(spacing: 4) {
            Text("Задание на полёт №")
            stableInlineEditor(
                text: isEditing ? $assignmentNumber : .constant(duty.firstLeg.assignmentNumber ?? ""),
                isActive: isEditing ? focusBinding(.assignment) : .constant(false),
                field: .assignment,
                keyboardType: .asciiCapable,
                capitalization: .allCharacters,
                maxLength: 12,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.first?.assignmentNumber
                    ?? duty.firstLeg.assignmentNumber
                    ?? "",
                numbersOnly: false,
                reserveText: "Manual888",
                highlightHorizontalPadding: 0,
                textFont: .title3.bold(),
                inputFont: .systemFont(ofSize: 20, weight: .bold),
                lineHeight: 24
            )
        }
        .font(.title3.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(height: 24)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private func legCountText(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10

        if lastTwo >= 11 && lastTwo <= 14 {
            return "\(count) легов"
        }

        switch last {
        case 1:
            return "\(count) лег"
        case 2...4:
            return "\(count) лега"
        default:
            return "\(count) легов"
        }
    }

    // Итоги задания без отдельного заголовка.
    // Общее время и ночь снова находятся в одной ячейке.
    private func dutyTotals(_ duty: FlightDuty) -> some View {
        LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 6) {
            dutyTotalCell(
                title: "Полётная смена",
                total: duty.workMinutes,
                night: duty.workNightMinutes
            )

            dutyTotalCell(
                title: "Полётное время",
                total: duty.flightMinutes,
                night: duty.flightNightMinutes
            )

            dutyTotalCell(
                title: "Лётное время",
                total: duty.airMinutes,
                night: duty.airNightMinutes
            )
        }
        .frame(width: 496, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    private func dutyTotalCell(
        title: String,
        total: Int,
        night: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            timeAndNight(total: total, night: night)
                .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .onTapGesture { focusedField = nil }
    }

    private func timeAndNight(total: Int, night: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(timeText(total))
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text("· ночь")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(timeText(night))
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityLabel("\(timeText(total)), ночь \(timeText(night))")
    }

    // Уровень 2: отдельная карточка каждого лега.
    private func legCard(_ leg: FlightLeg, index: Int, workEnd: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            legHeader(leg, index: index)
                .zIndex(headerEditorZIndex(index))

            // Все исходные точки редактируются на месте. Итоги остаются вычисляемыми.
            LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 6) {
                timeCell(
                    title: "Начало работы",
                    date: leg.timeline.workStart,
                    index: index, point: .workStart
                )
                timeCell(
                    title: "Включение двигателей",
                    date: leg.timeline.engineOn,
                    index: index, point: .engineOn
                )
                timeCell(
                    title: "Взлёт",
                    date: leg.timeline.takeoff,
                    index: index, point: .takeoff
                )
                timeCell(
                    title: "Завершение работы",
                    date: times(for: leg).workEnd,
                    index: index,
                    point: .workEnd
                )
                timeCell(
                    title: "Выключение двигателей",
                    date: leg.timeline.engineOff,
                    index: index, point: .engineOff
                )
                timeCell(
                    title: "Посадка",
                    date: leg.timeline.landing,
                    index: index, point: .landing
                )
                legValueCard(
                    title: "Рабочее время",
                    total: minutesBetween(leg.timeline.workStart, workEnd),
                    night: nightMinutes(
                        from: leg.timeline.workStart,
                        to: workEnd
                    )
                )

                legValueCard(
                    title: "Полётное время",
                    total: leg.flightMinutes,
                    night: leg.flightNightMinutes
                )

                legValueCard(
                    title: "Лётное время",
                    total: leg.airMinutes,
                    night: leg.airNightMinutes
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { focusedField = nil }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func headerEditorZIndex(_ index: Int) -> Double {
        switch focusedField {
        case .legNumber(let value),
             .route(let value),
             .flightKind(let value),
             .aircraft(let value),
             .registration(let value),
             .calculatedTime(let value):
            return value == index ? 1000 : 0
        default:
            return 0
        }
    }

    private func legEditorZIndex(_ index: Int) -> Double {
        switch focusedField {
        case .legNumber(let value),
             .route(let value),
             .flightKind(let value),
             .aircraft(let value),
             .registration(let value),
             .calculatedTime(let value),
             .time(let value, _):
            return value == index ? 2000 : 0
        default:
            return 0
        }
    }

    private func legHeader(_ leg: FlightLeg, index: Int) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                flightNumber(leg, index: index)
                aircraftField(leg, index: index)
                registrationField(leg, index: index)
                flightKindField(leg, index: index)
                calculatedTime(leg, index: index)
            }
            .frame(width: 496, alignment: .center)
            .zIndex(focusedField == .calculatedTime(index) ? 100 : 0)

            routeField(leg, index: index)
                .frame(width: 496)
                .zIndex(0)
        }
    }

    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? legNumberBinding(index)
            : .constant(editableLegNumber(leg, index: index))
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.legNumber(index))
            : .constant(false)

        return identityField("Рейс", field: .legNumber(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                field: .legNumber(index),
                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                maxLength: 7,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? editableLegNumber(original[index], index: index)
                    : editableLegNumber(leg, index: index),
                clearOnFirstDelete: true
            )
        }
    }

    private func flightKindField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Вид полёта", field: .flightKind(index)) {
            ZStack {
                // Ширина всегда резервируется под самый длинный вариант,
                // чтобы «Плановый» не сжимал верхнюю строку.
                Text(FlightScheduleType.unscheduled.rawValue)
                    .hidden()
                Text((leg.scheduleType ?? .planned).rawValue)
            }
        }
    }

    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
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
    }

    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        let formatted = formattedRegistration(leg.registration)
        let numericRegistration = isNumericRegistration(formatted)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.registration(index))
            : .constant(false)

        return identityField("Бортовой номер", field: .registration(index)) {
            if numericRegistration {
                let staticDigits = formatted.replacingOccurrences(of: "RA-", with: "")
                stableInlineEditor(
                    text: isEditing
                        ? registrationDigitsBinding(index)
                        : .constant(staticDigits),
                    isActive: activeBinding,
                    field: .registration(index),
                    prefix: "RA-",
                    keyboardType: .numberPad,
                    capitalization: .none,
                    maxLength: 5,
                    expands: false,
                    allowsEditing: isEditing,
                    restoreValue: original.indices.contains(index)
                        ? registrationComparisonKey(original[index].registration)
                        : staticDigits,
                    highlightHorizontalPadding: 0
                )
            } else {
                stableInlineEditor(
                    text: isEditing
                        ? registrationTextBinding(index)
                        : .constant(formatted),
                    isActive: activeBinding,
                    field: .registration(index),
                    keyboardType: .asciiCapable,
                    capitalization: .allCharacters,
                    maxLength: 8,
                    expands: false,
                    allowsEditing: isEditing,
                    restoreValue: original.indices.contains(index)
                        ? formattedRegistration(original[index].registration)
                        : formatted,
                    highlightHorizontalPadding: 0
                )
            }
        }
    }

    private func stableInlineEditor(
        text: Binding<String>,
        isActive: Binding<Bool>,
        field: DutyFocusedField? = nil,
        prefix: String = "",
        keyboardType: UIKeyboardType,
        capitalization: UITextAutocapitalizationType,
        maxLength: Int? = nil,
        expands: Bool = true,
        allowsEditing: Bool = true,
        restoreValue: String? = nil,
        clearOnFirstDelete: Bool = false,
        numbersOnly: Bool = false,
        reserveText: String? = nil,
        highlightHorizontalPadding: CGFloat = 2,
        textFont: Font = .caption.bold(),
        inputFont: UIFont = .systemFont(ofSize: 12, weight: .bold),
        lineHeight: CGFloat = 18
    ) -> some View {
        let valueColor = isEditing
            ? editorValueColor(for: field, isActive: isActive.wrappedValue)
            : Color.primary

        return ZStack(alignment: .leading) {
            if let reserveText {
                Text(reserveText)
                    .font(textFont)
                    .hidden()
            }

            HStack(spacing: 0) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(textFont)
                        .foregroundStyle(valueColor)
                }

                Text(text.wrappedValue)
                    .font(textFont)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, highlightHorizontalPadding)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: expands ? .infinity : nil, minHeight: lineHeight, maxHeight: lineHeight)
        .overlay {
            if allowsEditing {
                InlineSelectAllTextField(
                    text: text,
                    isActive: isActive,
                    keyboardType: keyboardType,
                    capitalization: capitalization,
                    textAlignment: .center,
                    font: inputFont,
                    maxLength: maxLength,
                    isEnabled: true,
                    restoreValue: restoreValue,
                    clearOnFirstDelete: clearOnFirstDelete,
                    numbersOnly: numbersOnly
                )
                .frame(maxWidth: .infinity, minHeight: lineHeight, maxHeight: lineHeight)
            }
        }
        .frame(height: lineHeight)
    }

    private func editorValueColor(
        for field: DutyFocusedField?,
        isActive: Bool
    ) -> Color {
        if isActive {
            return field.map(fieldHasChanges) == true
                ? DutyEditPalette.selectedChanged
                : Color.accentColor.opacity(0.58)
        }

        if let field, fieldHasChanges(field) {
            return DutyEditPalette.changed
        }

        return Color.accentColor
    }

    private func fieldHasChanges(_ field: DutyFocusedField) -> Bool {
        guard isEditing else { return false }

        switch field {
        case .assignment:
            let before = (original.first?.assignmentNumber ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let after = assignmentNumber
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return before != after

        case .legNumber(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return editableLegNumber(original[index], index: index)
                != editableLegNumber(draft[index], index: index)

        case .aircraft(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return draft[index].aircraft != original[index].aircraft

        case .registration(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return registrationComparisonKey(draft[index].registration)
                != registrationComparisonKey(original[index].registration)

        case .route(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            let beforeDeparture = original[index].departure
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let afterDeparture = draft[index].departure
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let beforeArrival = original[index].arrival
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let afterArrival = draft[index].arrival
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return beforeDeparture != afterDeparture || beforeArrival != afterArrival

        case .flightKind(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return (draft[index].scheduleType ?? .planned)
                != (original[index].scheduleType ?? .planned)

        case .calculatedTime(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return draft[index].calculatedMinutesOverride
                != original[index].calculatedMinutesOverride

        case .time(let index, let point):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return point.date(in: times(for: draft[index]))
                != point.date(in: times(for: original[index]))

        default:
            return false
        }
    }

    private func identityField<Content: View>(
        _ title: String,
        field: DutyFocusedField,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            content()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    isEditing
                        ? editorValueColor(
                            for: field,
                            isActive: focusedField == field
                        )
                        : Color.primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 18, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            if case .flightKind(let index) = field {
                toggleScheduleType(index)
            } else {
                focusedField = field
            }
        }
    }

    private func routeField(_ leg: FlightLeg, index: Int) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text("Маршрут")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            routeIdentity(leg, index: index)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 18, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }

    private func routeIdentity(_ leg: FlightLeg, index: Int) -> some View {
        HStack(spacing: 0) {
            routeEndpoint(
                code: isEditing
                    ? routeCodeBinding(index: index, side: .departure)
                    : .constant(leg.departure.trimmingCharacters(in: .whitespacesAndNewlines)),
                index: index,
                side: .departure
            )

            Text("→")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)

            routeEndpoint(
                code: isEditing
                    ? routeCodeBinding(index: index, side: .arrival)
                    : .constant(leg.arrival.trimmingCharacters(in: .whitespacesAndNewlines)),
                index: index,
                side: .arrival
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func routeEndpoint(
        code: Binding<String>,
        index: Int,
        side: RouteEditSide
    ) -> some View {
        let cleanCode = code.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isActive = routeFocusBinding(index: index, side: side)
        let endpointText =
            Text("\(airportNameOnly(cleanCode)) (")
            + Text(cleanCode)
                .foregroundColor(
                    isEditing
                        ? routeValueColor(
                            index: index,
                            side: side,
                            isActive: isActive.wrappedValue
                        )
                        : Color.primary
                )
            + Text(")")

        return endpointText
            .overlay {
                if isEditing {
                    InlineSelectAllTextField(
                        text: code,
                        isActive: isActive,
                        keyboardType: .asciiCapable,
                        capitalization: .allCharacters,
                        textAlignment: .center,
                        font: .systemFont(ofSize: 15, weight: .semibold),
                        maxLength: 5,
                        isEnabled: true,
                        restoreValue: original.indices.contains(index)
                            ? (side == .departure
                                ? original[index].departure
                                : original[index].arrival)
                            : cleanCode
                    )
                    .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
                    .allowsHitTesting(false)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEditing else { return }
                routeEditSide = side
                focusedField = .route(index)
            }
    }
    private func routeValueColor(
        index: Int,
        side: RouteEditSide,
        isActive: Bool
    ) -> Color {
        if isActive {
            return routeSideHasChanges(index: index, side: side)
                ? DutyEditPalette.selectedChanged
                : Color.accentColor.opacity(0.58)
        }
        return routeSideHasChanges(index: index, side: side)
            ? DutyEditPalette.changed
            : Color.accentColor
    }

    private func routeSideHasChanges(index: Int, side: RouteEditSide) -> Bool {
        guard draft.indices.contains(index), original.indices.contains(index) else {
            return false
        }
        let before = side == .departure
            ? original[index].departure
            : original[index].arrival
        let after = side == .departure
            ? draft[index].departure
            : draft[index].arrival
        return before.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            != after.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func routeCodeBinding(index: Int, side: RouteEditSide) -> Binding<String> {
        Binding(
            get: {
                side == .departure
                    ? draft[index].departure
                    : draft[index].arrival
            },
            set: { rawValue in
                let normalized = String(
                    rawValue
                        .uppercased()
                        .filter { character in
                            character.isASCII
                                && (character.isLetter || character.isNumber || character == "/")
                        }
                        .prefix(5)
                )

                if side == .departure {
                    draft[index].departure = normalized
                } else {
                    draft[index].arrival = normalized
                }
            }
        )
    }

    private func routeFocusBinding(index: Int, side: RouteEditSide) -> Binding<Bool> {
        Binding(
            get: {
                isEditing
                    && focusedField == .route(index)
                    && routeEditSide == side
            },
            set: { active in
                guard isEditing else {
                    if focusedField == .route(index) {
                        focusedField = nil
                    }
                    return
                }

                if active {
                    routeEditSide = side
                    focusedField = .route(index)
                } else if focusedField == .route(index) && routeEditSide == side {
                    focusedField = nil
                }
            }
        )
    }

    private func airportNameOnly(_ rawCode: String) -> String {
        let display = airportDisplayName(rawCode)
        guard let range = display.range(of: " (", options: .backwards),
              display.hasSuffix(")") else {
            return display
        }
        return String(display[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func focusBinding(_ field: DutyFocusedField) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { active in
                if active {
                    focusedField = field
                } else if focusedField == field {
                    focusedField = nil
                }
            }
        )
    }

    private func editableValue<Editor: View>(
        _ value: String,
        title: String,
        field: DutyFocusedField,
        @ViewBuilder editor: @escaping () -> Editor
    ) -> some View {
        Group {
            if isEditing {
                ZStack {
                    Button { focusedField = field } label: {
                        Text(value)
                            .background {
                                if field == .assignment {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor.opacity(0.14))
                                }
                            }
                            .overlay {
                                if field == .assignment {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Нажмите, чтобы изменить")
                }
                .overlay(alignment: floatingEditorAlignment(for: field)) {
                    if focusedField == field {
                        floatingEditor(width: editPopoverWidth(for: field)) {
                            VStack(alignment: .leading, spacing: 6) {
                                editPopoverHeader(
                                    title,
                                    extraHorizontalInset: 0
                                )

                                editor()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .offset(y: 28)
                    }
                }
                .zIndex(focusedField == field ? 1000 : 0)
            } else {
                Text(value)
            }
        }
    }

    private func editPopoverHeader(
        _ title: String,
        extraHorizontalInset: CGFloat = 14
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.leading, extraHorizontalInset)

            Spacer(minLength: 6)

            Button {
                focusedField = nil
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .padding(.trailing, extraHorizontalInset)
            .accessibilityLabel("Готово")
        }
    }

    private func floatingEditor<Content: View>(
        width: CGFloat,
        height: CGFloat? = nil,
        backgroundOpacity: Double = 1,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        Color(uiColor: .secondarySystemGroupedBackground)
                            .opacity(backgroundOpacity)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .environment(\.timeZone, moscowTimeZone)
    }

    private func floatingEditorAlignment(for field: DutyFocusedField) -> Alignment {
        switch field {
        case .legNumber, .aircraft, .registration:
            return .topLeading
        case .route:
            return .top
        case .flightKind, .calculatedTime:
            return .topTrailing
        default:
            return .top
        }
    }

    private func editPopoverWidth(for field: DutyFocusedField) -> CGFloat {
        switch field {
        case .legNumber:
            return 220
        case .aircraft:
            return 225
        case .registration:
            return 245
        case .flightKind:
            return 245
        case .route:
            return 350
        case .calculatedTime:
            return 204
        default:
            return 260
        }
    }

    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {
        let editableLeg = isEditing && draft.indices.contains(index) ? draft[index] : leg
        let isUnscheduled = (editableLeg.scheduleType ?? .planned) == .unscheduled
        let usesTable = !isUnscheduled
            && draft.indices.contains(index)
            && draft[index].calculatedMinutesOverride == nil

        return InlineCalculatedTimeValue(
            displayed: leg.calculatedMinutes.map(timeText) ?? "Нет данных",
            originalMinutes: original.indices.contains(index)
                ? (original[index].calculatedMinutesOverride ?? original[index].flightMinutes)
                : (leg.calculatedMinutes ?? 0),
            minutes: Binding(
                get: { draft.indices.contains(index)
                    ? (draft[index].calculatedMinutesOverride ?? draft[index].flightMinutes)
                    : 0 },
                set: { draft[index].calculatedMinutesOverride = max(0, $0) }
            ),
            isEditing: isEditing,
            isActive: focusedField == .calculatedTime(index),
            isUnscheduled: isUnscheduled,
            usesTable: usesTable,
            hasChanges: calculatedEditorHasChanges(index),
            sourceHasChanges: calculatedSourceHasChanges(index),
            onActivate: { focusedField = .calculatedTime(index) },
            onToggleSource: {
                focusedField = nil
                toggleCalculatedTimeSource(index)
            },
            onRestore: { restoreOriginalCalculatedTime(index) }
        )
        .zIndex(focusedField == .calculatedTime(index) ? 5000 : 0)
    }

    private func calculatedEditorHasChanges(_ index: Int) -> Bool {
        guard draft.indices.contains(index), original.indices.contains(index) else {
            return false
        }

        if draft[index].calculatedMinutesOverride != original[index].calculatedMinutesOverride {
            return true
        }

        let originalType = original[index].scheduleType ?? .planned
        let currentType = draft[index].scheduleType ?? .planned
        return originalType == .planned && currentType != .planned
    }

    private func calculatedSourceHasChanges(_ index: Int) -> Bool {
        guard draft.indices.contains(index), original.indices.contains(index) else {
            return false
        }

        let originalUsesTable = original[index].calculatedMinutesOverride == nil
        let currentUsesTable = draft[index].calculatedMinutesOverride == nil
        return originalUsesTable != currentUsesTable
    }

    private func restoreOriginalCalculatedTime(_ index: Int) {
        guard draft.indices.contains(index), original.indices.contains(index) else { return }

        draft[index].calculatedMinutesOverride = original[index].calculatedMinutesOverride

        if (original[index].scheduleType ?? .planned) == .planned {
            draft[index].scheduleType = .planned
        }
    }

    private func toggleCalculatedTimeSource(_ index: Int) {
        if draft[index].calculatedMinutesOverride == nil {
            let seed = draft[index].calculatedMinutes ?? draft[index].flightMinutes
            draft[index].calculatedMinutesOverride = max(0, seed)
        } else {
            draft[index].calculatedMinutesOverride = nil
        }
    }

    private func timeCell(
        title: String,
        date: Date,
        index: Int,
        point: DutyEditPoint
    ) -> some View {
        InlineFlightDateTimeCell(
            title: title,
            selection: isEditing ? timeBinding(index, point) : .constant(date),
            original: isEditing && original.indices.contains(index)
                ? point.date(in: times(for: original[index])) : date,
            isEditing: isEditing,
            isActive: isEditing && focusedField == .time(index, point),
            onActivate: { focusedField = .time(index, point) },
            showsCalendarButton: index == 0 && point == .workStart,
            dateCanToggle: isEditing && canToggleDutyDate(index: index, point: point),
            onToggleDate: { toggleDutyDate(index: index, point: point) },
            onDismiss: { focusedField = nil },
            backgroundColor: valueTileColor
        )
        .zIndex(focusedField == .time(index, point) ? 100 : 0)
    }

    private func legValueCard(
        title: String,
        value: String,
        centered: Bool = false,
        compact: Bool = false,
        valueColor: Color = .primary
    ) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.85)
                .frame(
                    height: 18,
                    alignment: centered ? .center : .leading
                )
        }
        .frame(
            maxWidth: compact ? nil : .infinity,
            alignment: centered ? .center : .leading
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .fixedSize(horizontal: compact, vertical: false)
        .accessibilityElement(children: .combine)
        .onTapGesture { focusedField = nil }
    }

    private func legValueCard(
        title: String,
        total: Int,
        night: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            timeAndNight(total: total, night: night)
                .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .accessibilityElement(children: .combine)
        .onTapGesture { focusedField = nil }
    }

}


private struct SwipeDeleteFlightCard<Content: View>: View {
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


private struct InlineCalculatedTimeValue: View {
    let displayed: String
    let originalMinutes: Int
    @Binding var minutes: Int
    let isEditing: Bool
    let isActive: Bool
    let isUnscheduled: Bool
    let usesTable: Bool
    let hasChanges: Bool
    let sourceHasChanges: Bool
    let onActivate: () -> Void
    let onToggleSource: () -> Void
    let onRestore: () -> Void

    @State private var activePart: Part?
    private enum Part { case hour, minute }

    private var hour: Int { minutes / 60 }
    private var minute: Int { minutes % 60 }

    private var sourceColor: Color {
        sourceHasChanges ? DutyEditPalette.changed : Color.accentColor
    }

    private var displayedClockParts: (hour: String, minute: String)? {
        let parts = displayed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("Расчётное время")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if !isEditing {
                if let parts = displayedClockParts {
                    HStack(spacing: -1) {
                        Text(parts.hour)
                            .frame(width: 17, height: 18)
                        Text(":")
                            .font(.caption.bold())
                            .frame(width: 5)
                        Text(parts.minute)
                            .frame(width: 17, height: 18)
                    }
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: 37, height: 18)
                } else {
                    Text(displayed)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(height: 18)
                }
            } else if usesTable {
                Button {
                    activePart = nil
                    onToggleSource()
                } label: {
                    ZStack {
                        Text("Из таблицы")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack(spacing: 0) {
                            Image(systemName: "checkmark.square.fill")
                                .font(.system(size: 16))
                                .frame(width: 20)
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundStyle(sourceColor)
                    .frame(width: 130, height: 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Из таблицы")
                .accessibilityValue("Выбрано")
            } else if isUnscheduled {
                timeWheel.frame(height: 18)
            } else {
                ZStack {
                    timeWheel

                    HStack(spacing: 0) {
                        Button {
                            activePart = nil
                            onToggleSource()
                        } label: {
                            Image(systemName: "square")
                                .font(.system(size: 16))
                                .frame(width: 20, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(sourceColor)
                        .accessibilityLabel("Выбрать расчётное время из таблицы")

                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 130, height: 18)
            }
        }
        .frame(width: 130, alignment: .center)
        .padding(.vertical, 6)
        .overlay(alignment: .bottomTrailing) {
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
        .onChange(of: isActive) { _, active in
            if !active { activePart = nil }
        }
        .onChange(of: usesTable) { _, table in
            if table { activePart = nil }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { activePart = nil }
        }
    }

    private var timeWheel: some View {
        HStack(spacing: -1) {
            InlineFlightWheelSegment(
                value: String(format: "%02d", hour),
                previous: String(format: "%02d", max(0, hour - 1)),
                next: String(format: "%02d", hour + 1),
                width: 17, hitWidth: 33, hitOffset: 0, hitHeight: 48,
                isEditing: true,
                isActive: isActive && activePart == .hour,
                valueColor: color(for: .hour),
                onActivate: { onActivate(); activePart = .hour },
                onStep: { minutes = max(0, hour + $0) * 60 + minute },
                canStepPrevious: hour > 0
            )
            Text(":")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
                .frame(width: 5)
            InlineFlightWheelSegment(
                value: String(format: "%02d", minute),
                previous: String(format: "%02d", (minute + 59) % 60),
                next: String(format: "%02d", (minute + 1) % 60),
                width: 17, hitWidth: 38, hitOffset: 13, hitHeight: 48,
                isEditing: true,
                isActive: isActive && activePart == .minute,
                valueColor: color(for: .minute),
                onActivate: { onActivate(); activePart = .minute },
                onStep: { minutes = hour * 60 + (minute + $0 % 60 + 60) % 60 }
            )
        }
        .frame(width: 37, height: 18)
    }

    private func color(for part: Part) -> Color {
        let changed: Bool
        switch part {
        case .hour: changed = hour != originalMinutes / 60
        case .minute: changed = minute != originalMinutes % 60
        }
        if isActive && activePart == part {
            return changed
                ? DutyEditPalette.selectedChanged
                : Color.accentColor.opacity(0.58)
        }
        return changed ? DutyEditPalette.changed : .accentColor
    }
}

private struct DutyEditSnapshot: Equatable {
    let legs: [FlightLeg]
    let assignment: String
}

private enum RouteEditSide: Hashable {
    case departure
    case arrival
}

private enum DutyFocusedField: Hashable {
    case assignment
    case legNumber(Int)
    case route(Int)
    case flightKind(Int)
    case aircraft(Int)
    case registration(Int)
    case calculatedTime(Int)
    case time(Int, DutyEditPoint)
}

private enum DutyEditPoint: CaseIterable, Identifiable, Hashable {
    case workStart, engineOn, takeoff, landing, engineOff, workEnd

    var id: Self { self }

    var title: String {
        switch self {
        case .workStart: return "Начало работы"
        case .engineOn: return "Включение двигателей"
        case .takeoff: return "Взлёт"
        case .landing: return "Посадка"
        case .engineOff: return "Выключение двигателей"
        case .workEnd: return "Завершение работы"
        }
    }

    func date(in times: PortalFlightTimes) -> Date {
        switch self {
        case .workStart: return times.workStart
        case .engineOn: return times.engineOn
        case .takeoff: return times.takeoff
        case .landing: return times.landing
        case .engineOff: return times.engineOff
        case .workEnd: return times.workEnd
        }
    }
}

private func airportDisplayName(_ rawCode: String) -> String {
    AirportDatabase.displayName(for: rawCode)
}

private func formattedRegistration(_ rawValue: String) -> String {
    let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let compact = raw.replacingOccurrences(of: "-", with: "")

    if compact.hasPrefix("RA") {
        let number = String(compact.dropFirst(2))
        if !number.isEmpty && number.allSatisfy(\.isNumber) {
            return "RA-\(number)"
        }
    }

    if compact.count == 5 && compact.allSatisfy(\.isNumber) {
        return "RA-\(compact)"
    }

    return raw
}


private struct CompactFlightValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Добавление / редактирование рейса


// MARK: - Ввод с физической клавиатуры

// UITextField уже реализует UIKeyInput. Перехватываем именно текстовый канал
// insertText/deleteBackward: его использует система и для программной, и для
// физической клавиатуры, когда поле является first responder.
private final class AssignmentInputTextField: UITextField {
    var hardwareInputHandler: ((String?, Bool) -> Void)?

    override func insertText(_ text: String) {
        guard let hardwareInputHandler else {
            super.insertText(text)
            return
        }

        hardwareInputHandler(text, false)
    }

    override func deleteBackward() {
        guard let hardwareInputHandler else {
            super.deleteBackward()
            return
        }

        hardwareInputHandler(nil, true)
    }
}

private struct InlineSelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    let keyboardType: UIKeyboardType
    let capitalization: UITextAutocapitalizationType
    let textAlignment: NSTextAlignment
    let font: UIFont
    var maxLength: Int? = nil
    var isEnabled: Bool = true
    var restoreValue: String? = nil
    var clearOnFirstDelete = false
    var numbersOnly = false

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isActive: $isActive,
            maxLength: maxLength,
            restoreValue: restoreValue,
            clearOnFirstDelete: clearOnFirstDelete,
            numbersOnly: numbersOnly
        )
    }

    func makeUIView(context: Context) -> UITextField {
        let field = AssignmentInputTextField(frame: .zero)
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .clear
        field.tintColor = .clear
        field.keyboardType = keyboardType
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.autocapitalizationType = capitalization
        field.textAlignment = textAlignment
        field.font = font
        field.adjustsFontForContentSizeCategory = false
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 10.5
        field.isEnabled = isEnabled
        field.isUserInteractionEnabled = isEnabled
        field.delegate = context.coordinator
        field.hardwareInputHandler = { [weak field] characters, deleting in
            guard let field else { return }
            context.coordinator.handleHardwareInput(
                characters,
                deleting: deleting,
                in: field
            )
        }
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isActive = $isActive
        context.coordinator.maxLength = maxLength
        context.coordinator.restoreValue = restoreValue
        context.coordinator.clearOnFirstDelete = clearOnFirstDelete
        context.coordinator.numbersOnly = numbersOnly
        field.font = font
        field.keyboardType = keyboardType
        field.autocapitalizationType = capitalization
        field.isEnabled = isEnabled
        field.isUserInteractionEnabled = isEnabled

        if field.text != text {
            field.text = text
        }

        guard isEnabled else {
            if field.isFirstResponder {
                field.resignFirstResponder()
            }
            return
        }

        if isActive && !field.isFirstResponder {
            DispatchQueue.main.async {
                field.becomeFirstResponder()
                context.coordinator.prepareToReplaceCurrentValue(in: field)
            }
        } else if !isActive && field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isActive: Binding<Bool>
        var maxLength: Int?
        var restoreValue: String?
        var clearOnFirstDelete: Bool
        var numbersOnly: Bool
        private var replaceOnNextInput = false

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?,
            restoreValue: String?,
            clearOnFirstDelete: Bool,
            numbersOnly: Bool
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
            self.restoreValue = restoreValue
            self.clearOnFirstDelete = clearOnFirstDelete
            self.numbersOnly = numbersOnly
        }

        func prepareToReplaceCurrentValue(in textField: UITextField) {
            replaceOnNextInput = true
            moveCaretToEnd(in: textField)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isActive.wrappedValue = true
            prepareToReplaceCurrentValue(in: textField)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            replaceOnNextInput = false
            isActive.wrappedValue = false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if replaceOnNextInput {
                replaceOnNextInput = false
                let value = limited(string)
                textField.text = value
                text.wrappedValue = value
                moveCaretToEnd(in: textField)
                return false
            }

            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else {
                return true
            }

            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            let value = limited(candidate)
            if value != candidate {
                textField.text = value
                text.wrappedValue = value
                moveCaretToEnd(in: textField)
                return false
            }

            return true
        }

        @objc func textChanged(_ field: UITextField) {
            let value = limited(field.text ?? "")
            text.wrappedValue = value
            let normalized = text.wrappedValue
            if field.text != normalized {
                field.text = normalized
                moveCaretToEnd(in: field)
            }
        }

        func handleHardwareInput(
            _ characters: String?,
            deleting: Bool,
            in field: UITextField
        ) {
            var value = field.text ?? ""

            if deleting {
                if replaceOnNextInput, clearOnFirstDelete, !value.isEmpty {
                    value = ""
                    replaceOnNextInput = false
                } else {
                    replaceOnNextInput = false
                    if value.isEmpty,
                       let restoreValue,
                       !restoreValue.isEmpty {
                        value = limited(restoreValue)
                        replaceOnNextInput = true
                    } else if !value.isEmpty {
                        value.removeLast()
                    }
                }
            } else if let characters {
                if replaceOnNextInput {
                    value = ""
                    replaceOnNextInput = false
                }
                value.append(contentsOf: characters)
            }

            value = limited(value)
            text.wrappedValue = value
            field.text = text.wrappedValue
            moveCaretToEnd(in: field)
        }

        private func limited(_ value: String) -> String {
            let filtered = numbersOnly
                ? String(value.filter(\.isNumber))
                : value
            guard let maxLength else { return filtered }
            return String(filtered.prefix(maxLength))
        }

        private func moveCaretToEnd(in field: UITextField) {
            DispatchQueue.main.async {
                guard let end = field.endOfDocument as UITextPosition? else { return }
                field.selectedTextRange = field.textRange(from: end, to: end)
            }
        }
    }
}

private struct HardwareKeyboardTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.placeholder = placeholder
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
        field.clearButtonMode = .whileEditing
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }
    }
}

// MARK: - План работ

struct WorkEventsListView: View {
    
    @ObservedObject
    var store:
    AppStore
    
    
    @State
    private var showAdd =
    false
    
    
    var events:
    [WorkEvent] {
        
        store.workEvents
            .sorted {
                
                $0.startDate
                >
                $1.startDate
            }
    }
    
    
    var body: some View {
        
        List {
            
            if events.isEmpty {
                
                Text(
                    "План работ пока пуст."
                )
                .foregroundStyle(
                    .secondary
                )
                
            } else {
                
                ForEach(
                    events
                ) { event in
                    
                    NavigationLink {
                        
                        WorkEventDetailView(
                            event:
                                event
                        )
                        
                    } label: {
                        
                        WorkEventRow(
                            event:
                                event
                        )
                    }
                }
            }
        }
        
        
        .navigationTitle(
            "План работ"
        )
        
        
        .toolbar {
            
            Button {
                
                showAdd =
                true
                
            } label: {
                
                Image(
                    systemName:
                        "plus"
                )
            }
        }
        
        
        .sheet(
            isPresented:
                $showAdd
        ) {
            
            AddWorkEventView {
                
                event in
                
                store.addWorkEvent(
                    event
                )
            }
        }
    }
}


// MARK: - Строка наземной работы

struct WorkEventRow: View {
    
    let event:
    WorkEvent
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    event.type.icon
            )
            .font(.title2)
            .foregroundStyle(
                event.type.color
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    event.type.rawValue
                )
                .bold()
                
                
                if !event.note.isEmpty {
                    
                    Text(
                        event.note
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                
                
                Text(
                    "\(event.date) • \(event.startTime) – \(event.endTime)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                if !event.hasValidStoredDates {
                    
                    Label(
                        "Проверьте дату и время",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .orange
                    )
                }
            }
            
            
            Spacer()
            
            
            VStack(
                alignment:
                        .trailing,
                spacing: 3
            ) {
                
                if event.hasValidStoredDates {
                    
                    Text(
                        timeText(
                            event.creditedMinutes
                        )
                    )
                    .bold()
                    
                    
                    if event.type
                        == .homeReserve {
                        
                        Text(
                            "\(timeText(event.rawMinutes)) факт."
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    
                } else {
                    
                    Text(
                        "Не учтено"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .orange
                    )
                }
            }
        }
        .padding(
            .vertical,
            4
        )
    }
}


// MARK: - Детали наземного события

struct WorkEventDetailView: View {
    
    @Environment(
        \.dismiss
    )
    private var dismiss
    
    
    @EnvironmentObject
    private var store:
    AppStore
    
    
    let event:
    WorkEvent
    
    
    @State
    private var showEdit =
    false
    
    
    @State
    private var showDeleteConfirmation =
    false
    
    
    var currentEvent:
    WorkEvent {
        
        store.workEvents
            .first {
                $0.id == event.id
            }
        ?? event
    }
    
    
    var body: some View {
        
        let current =
        currentEvent
        
        
        List {
            
            Section(
                "Событие"
            ) {
                
                HStack {
                    
                    Label(
                        current.type.rawValue,
                        systemImage:
                            current.type.icon
                    )
                    .foregroundStyle(
                        current.type.color
                    )
                    
                    
                    Spacer()
                }
                
                
                FlightInfoRow(
                    name:
                        "Дата",
                    value:
                        current.date
                )
                
                
                if !current.note.isEmpty {
                    
                    FlightInfoRow(
                        name:
                            "Комментарий",
                        value:
                            current.note
                    )
                }
            }
            
            
            if current.hasValidStoredDates {
                
                Section(
                    "Время"
                ) {
                    
                    FlightInfoRow(
                        name:
                            "Начало",
                        value:
                            formatDateTime(
                                current.startDate
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Окончание",
                        value:
                            formatDateTime(
                                current.endDate
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Фактически",
                        value:
                            timeText(
                                current.rawMinutes
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "В зачёт",
                        value:
                            timeText(
                                current.creditedMinutes
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Ночное",
                        value:
                            timeText(
                                current.creditedNightMinutes
                            )
                    )
                }
                
                
                if current.type
                    == .homeReserve {
                    
                    Section(
                        "Расчёт"
                    ) {
                        
                        Text(
                            "Домашний резерв: четыре часа фактического времени дают один час рабочего времени."
                        )
                        .font(.footnote)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
                
            } else {
                
                Section {
                    
                    Label(
                        "Дата или время сохранены в неверном формате. Событие не участвует в расчётах, пока запись не будет исправлена.",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )
                    
                } header: {
                    
                    Text(
                        "Требуется проверка"
                    )
                }
                
                
                Section(
                    "Сохранённые значения"
                ) {
                    
                    FlightInfoRow(
                        name:
                            "Дата",
                        value:
                            current.date
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Начало",
                        value:
                            current.startTime
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Окончание",
                        value:
                            current.endTime
                    )
                }
            }
            
            
            Section(
                "Действия"
            ) {
                
                Button {
                    
                    showEdit =
                    true
                    
                } label: {
                    
                    Label(
                        "Редактировать",
                        systemImage:
                            "pencil"
                    )
                }
                
                
                Button(
                    role:
                            .destructive
                ) {
                    
                    showDeleteConfirmation =
                    true
                    
                } label: {
                    
                    Label(
                        "Удалить событие",
                        systemImage:
                            "trash"
                    )
                }
            }
        }
        
        
        .navigationTitle(
            current.type.rawValue
        )
        
        
        .navigationBarTitleDisplayMode(
            .inline
        )
        
        
        .sheet(
            isPresented:
                $showEdit
        ) {
            
            AddWorkEventView(
                event:
                    current
            ) { updatedEvent in
                
                store.updateWorkEvent(
                    updatedEvent
                )
            }
        }
        
        
        .alert(
            "Удалить событие?",
            isPresented:
                $showDeleteConfirmation
        ) {
            
            Button(
                "Отмена",
                role:
                        .cancel
            ) {
            }
            
            
            Button(
                "Удалить",
                role:
                        .destructive
            ) {
                
                store.deleteWorkEvent(
                    id:
                        current.id
                )
                
                
                dismiss()
            }
            
        } message: {
            
            Text(
                "\(current.type.rawValue)\n\(current.date) • \(current.startTime) – \(current.endTime)\nЭто действие нельзя отменить."
            )
        }
    }
}


// MARK: - Добавление / редактирование наземной работы

struct AddWorkEventView: View {
    
    @Environment(
        \.dismiss
    )
    private var dismiss
    
    
    let eventToEdit:
    WorkEvent?
    
    
    let onSave:
    (WorkEvent) -> Void
    
    
    @State
    private var date:
    Date
    
    
    @State
    private var type:
    WorkEventType
    
    
    @State
    private var start:
    Date
    
    
    @State
    private var end:
    Date
    
    
    @State
    private var note:
    String
    
    
    init(
        event: WorkEvent? = nil,
        onSave: @escaping (WorkEvent) -> Void
    ) {
        
        self.eventToEdit =
        event
        
        
        self.onSave =
        onSave
        
        
        let now =
        Date()
        
        
        if let event {
            
            _date =
            State(
                initialValue:
                    moscowCalendar
                    .startOfDay(
                        for:
                            event.startDate
                    )
            )
            
            
            _type =
            State(
                initialValue:
                    event.type
            )
            
            
            _start =
            State(
                initialValue:
                    event.startDate
            )
            
            
            _end =
            State(
                initialValue:
                    event.endDate
            )
            
            
            _note =
            State(
                initialValue:
                    event.note
            )
            
        } else {
            
            _date =
            State(
                initialValue:
                    now
            )
            
            
            _type =
            State(
                initialValue:
                        .appearance
            )
            
            
            _start =
            State(
                initialValue:
                    now
            )
            
            
            _end =
            State(
                initialValue:
                    now.addingTimeInterval(
                        2 * 3600
                    )
            )
            
            
            _note =
            State(
                initialValue:
                    ""
            )
        }
    }
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section(
                    "Назначение"
                ) {
                    
                    DatePicker(
                        "Дата",
                        selection:
                            $date,
                        displayedComponents:
                                .date
                    )
                    
                    
                    Picker(
                        "Тип",
                        selection:
                            $type
                    ) {
                        
                        ForEach(
                            WorkEventType.allCases
                        ) { item in
                            
                            Label(
                                item.rawValue,
                                systemImage:
                                    item.icon
                            )
                            .tag(
                                item
                            )
                        }
                    }
                    
                    
                    TextField(
                        "Комментарий",
                        text:
                            $note
                    )
                }
                
                
                Section(
                    "Время"
                ) {
                    
                    AeroTimePickerRow(
                        title: "Начало",
                        selection: $start
                    )
                    
                    
                    AeroTimePickerRow(
                        title: "Окончание",
                        selection: $end
                    )
                }
                
                
                if type
                    == .homeReserve {
                    
                    Section {
                        
                        Text(
                            "Домашний резерв: четыре часа дают один час рабочего времени."
                        )
                        .font(.footnote)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            }
            
            
            .environment(
                \.timeZone,
                 moscowTimeZone
            )
            
            
            .navigationTitle(
                eventToEdit == nil
                ? "Новое событие"
                : "Редактирование"
            )
            
            
            .navigationBarTitleDisplayMode(
                .inline
            )
            
            
            .toolbar {
                
                ToolbarItem(
                    placement:
                            .cancellationAction
                ) {
                    
                    Button(
                        "Отмена"
                    ) {
                        
                        dismiss()
                    }
                }
                
                
                ToolbarItem(
                    placement:
                            .confirmationAction
                ) {
                    
                    Button(
                        "Сохранить"
                    ) {
                        
                        saveEvent()
                    }
                }
            }
        }
    }
    
    
    func saveEvent() {
        
        let event =
        WorkEvent(
            id:
                eventToEdit?.id
            ?? UUID(),
            date:
                formatDate(
                    date
                ),
            type:
                type,
            startTime:
                formatClock(
                    start
                ),
            endTime:
                formatClock(
                    end
                ),
            note:
                note
                .trimmingCharacters(
                    in:
                            .whitespacesAndNewlines
                )
        )
        
        
        onSave(
            event
        )
        
        
        dismiss()
    }
}


// MARK: - Ещё

struct MoreView: View {
    
    @ObservedObject
    var store:
    AppStore
    
    
    @ObservedObject
    var absenceStore:
    AbsenceStore
    
    
    @StateObject
    private var flightNormStore =
    FlightNormStore()
    
    
    var body: some View {
        
        NavigationStack {
            
            List {
                
                Section(
                    "Работа"
                ) {
                    
                    NavigationLink {
                        
                        WorkEventsListView(
                            store:
                                store
                        )
                        
                    } label: {
                        
                        HStack {
                            
                            Label(
                                "План работ",
                                systemImage:
                                    "calendar.badge.clock"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                "\(store.workEvents.count)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    
                    
                    NavigationLink {
                        
                        AbsencesListView(
                            store:
                                absenceStore
                        )
                        
                    } label: {
                        
                        HStack {
                            
                            Label(
                                "Отсутствия",
                                systemImage:
                                    "calendar.badge.minus"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                "\(absenceStore.absences.count)"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
                
                
                Section(
                    "База"
                ) {
                    
                    NavigationLink {
                        
                        FlightNormsView(
                            store:
                                flightNormStore
                        )
                        
                    } label: {
                        
                        HStack {
                            
                            Label(
                                "Расчётное время",
                                systemImage:
                                    "tablecells"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                String(
                                    flightNormStore
                                        .versions
                                        .count
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    
                    
                    HStack {
                        
                        Text(
                            "Легов"
                        )
                        
                        
                        Spacer()
                        
                        
                        Text(
                            "\(store.flights.count)"
                        )
                    }
                    
                    
                    HStack {
                        
                        Text(
                            "Полётных смен"
                        )
                        
                        
                        Spacer()
                        
                        
                        Text(
                            "\(store.duties.count)"
                        )
                    }
                }
            }
            
            
            .navigationTitle(
                "Ещё"
            )
        }
    }
}


// MARK: - Общие маленькие элементы

struct FlightInfoRow: View {
    
    let name: String
    
    let value: String
    
    
    var body: some View {
        
        HStack {
            
            Text(
                name
            )
            
            
            Spacer()
            
            
            Text(
                value
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}


struct MetricCard: View {
    
    let title: String
    
    let value: String
    
    let icon: String
    
    
    var body: some View {
        
        VStack(
            alignment:
                    .leading,
            spacing: 10
        ) {
            
            Image(
                systemName:
                    icon
            )
            .font(.title2)
            .foregroundStyle(
                .blue
            )
            
            
            Text(
                title
            )
            .foregroundStyle(
                .secondary
            )
            
            
            Text(
                value
            )
            .font(.title2)
            .bold()
        }
        .frame(
            maxWidth:
                    .infinity,
            alignment:
                    .leading
        )
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                .ultraThinMaterial
            )
        }
    }
}


struct EventRow: View {
    
    let icon: String
    
    let title: String
    
    let subtitle: String
    
    
    var body: some View {
        
        HStack(
            spacing: 14
        ) {
            
            Image(
                systemName:
                    icon
            )
            .font(.title2)
            .foregroundStyle(
                .blue
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    title
                )
                .bold()
                
                
                Text(
                    subtitle
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                .ultraThinMaterial
            )
        }
    }
}


struct SimplePage: View {
    
    let title: String
    
    let icon: String
    
    
    var body: some View {
        
        NavigationStack {
            
            VStack(
                spacing: 20
            ) {
                
                Image(
                    systemName:
                        icon
                )
                .font(
                    .system(
                        size: 60
                    )
                )
                .foregroundStyle(
                    .blue
                )
                
                
                Text(
                    title
                )
                .font(.largeTitle)
                .bold()
                
                
                Text(
                    "Этот раздел сделаем следующим."
                )
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            .navigationTitle(
                title
            )
        }
    }
}
