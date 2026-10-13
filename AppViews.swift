import SwiftUI
import Combine
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
                                durationText(
                                    totals.workSeconds
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
                                durationText(
                                    totals.groundWorkSeconds
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
    @ObservedObject private var cardPresence = DutyCardPresence.shared

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
                .disabled(cardPresence.isOpen)
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

                } label: {
                    Image(systemName: "plus")
                }
                .disabled(cardPresence.isOpen)
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
                Text("\(verificationStatus) В файле \(pendingFlights.count) рейсов, новых: \(store.countNewImported(pendingFlights)).")
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
                || contains(AirportDatabase.airport(for: leg.departure)?.city ?? "")
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
        // Время в заданиях — с точностью до минуты: секунды «сейчас» не берём (аудит 05.10, п. 6).
        let now = Date()
        let reference = moscowCalendar.dateInterval(of: .minute, for: now)?.start ?? now
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
            aircraft: AircraftFamilyV129.a320S.rawValue,
            registration: "RA-73772",
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
        leg.registration = "RA-73772"
        leg = DutyAutofillV129.applyingAircraftReference(to: leg)
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


/// Открыта ли сейчас карточка задания поверх списка. Пока открыта, переключатель
/// разделов, «лупа», «+» и удаление недоступны — черновик не теряется (аудит 05.10, п. 25б).
final class DutyCardPresence: ObservableObject {
    static let shared = DutyCardPresence()
    @Published private(set) var openCount = 0

    var isOpen: Bool { openCount > 0 }

    func opened() { openCount += 1 }
    func closed() { openCount = max(0, openCount - 1) }
}


struct DutyAssignmentOverlay: View {
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    let isCreating: Bool
    let isReadOnly: Bool
    let onCreate: (([FlightLeg]) -> Void)?
    let onUpdate: (([FlightLeg]) -> Void)?
    let onDelete: (() -> Void)?
    let onClose: () -> Void

    init(
        duty: FlightDuty,
        store: AppStore,
        isCreating: Bool = false,
        isReadOnly: Bool = false,
        onCreate: (([FlightLeg]) -> Void)? = nil,
        onUpdate: (([FlightLeg]) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.duty = duty
        self.store = store
        self.isCreating = isCreating
        self.isReadOnly = isReadOnly
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
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
        overlayBody
            .onAppear { DutyCardPresence.shared.opened() }
            .onDisappear { DutyCardPresence.shared.closed() }
    }

    private var overlayBody: some View {
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
                        isReadOnly: isReadOnly,
                        onCreate: onCreate,
                        onUpdate: onUpdate,
                        onDelete: onDelete
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
