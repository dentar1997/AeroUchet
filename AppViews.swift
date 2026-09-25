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

struct FlightsView: View {
    
    @ObservedObject
    var store: AppStore
    
    
      @State
    private var showAddFlight =
    false

    @State private var showImport = false
    @State private var showImportConfirmation = false
    @State private var showImportResult = false
    @State private var importMessage = ""
    @State private var pendingFlights: [FlightLeg] = []
    @State private var verificationStatus = ""

    var body: some View {
        
        NavigationStack {
            
            DutiesListView(store: store)
            
                        .navigationTitle(
                "Полёты"
            )
            
            
            .toolbar {
                Button("Импорт истории", systemImage: "square.and.arrow.down") { showImport = true }
                Button {
                    
                    showAddFlight =
                    true
                    
                } label: {
                    
                    Image(
                        systemName:
                            "plus"
                    )
                }
            }
            
            
            .fileImporter(isPresented: $showImport, allowedContentTypes: [UTType(filenameExtension: "xls") ?? .data]) { result in
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
                Text("\(verificationStatus) В файле \(pendingFlights.count) легов, новых: \(unique.subtracting(known).count).")
            }
            .alert("История рейсов", isPresented: $showImportResult) {
                Button("OK", role: .cancel) { }
            } message: { Text(importMessage) }
            .sheet(
                isPresented:
                    $showAddFlight
            ) {
                
                AddFlightView {
                    
                    flight in
                    
                    store.addFlight(
                        flight
                    )
                }
            }
        }
    }
}


// MARK: - Список смен

struct DutiesListView: View {
    
    @ObservedObject
    var store: AppStore
    
    
    var body: some View {
        
        List(
            store.duties
        ) { duty in
            
            NavigationLink {
                
                DutyDetailView(
                    duty:
                        duty
                )
                
            } label: {
                
                DutyRow(
                    duty:
                        duty
                )
            }
        }
    }
}


// MARK: - Строка смены

struct DutyRow: View {
    
    let duty:
    FlightDuty
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    "airplane.departure"
            )
            .foregroundStyle(
                .blue
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    duty.routeText
                )
                .bold()
                
                
                Text(
                    "\(duty.firstLeg.assignmentNumber.map { "№ \($0) • " } ?? "")\(duty.legs.count) лег. • \(formatDate(duty.start))"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    "\(formatClock(duty.start)) – \(formatClock(duty.end))\(duty.restMinutes > 0 ? " • разделена" : "")"
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
            
            
            VStack(
                alignment:
                        .trailing
            ) {
                
                Text(
                    timeText(
                        duty.workMinutes
                    )
                )
                .bold()
                
                
                Text(
                    "рабочее"
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }
}


// MARK: - Детали смены

struct DutyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let duty: FlightDuty

    @State private var editingFlight: FlightLeg?
    @State private var deletingFlight: FlightLeg?
    @State private var showDeleteConfirmation = false

    private let columns = [GridItem(.adaptive(minimum: 175, maximum: 280), spacing: 8)]

    private var current: FlightDuty {
        if let number = duty.firstLeg.assignmentNumber {
            return store.duties.first { $0.firstLeg.assignmentNumber == number } ?? duty
        }
        return store.duties.first { $0.id == duty.id } ?? duty
    }

    var body: some View {
        let current = current
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(current.firstLeg.assignmentNumber.map { "Задание № \($0)" } ?? "Полётная смена")
                    .font(.title2.bold())
                Text(current.routeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    CompactFlightValue(title: "Начало смены", value: formatDateTime(current.start))
                    CompactFlightValue(title: "Окончание (+30 мин)", value: formatDateTime(current.end))
                    CompactFlightValue(title: "Рабочее время", value: timeText(current.workMinutes))
                    if current.restMinutes > 0 {
                        CompactFlightValue(title: "Перерыв без работы", value: timeText(current.restMinutes))
                    }
                    CompactFlightValue(title: "Полётное", value: timeText(current.flightMinutes))
                    CompactFlightValue(title: "Лётное", value: timeText(current.airMinutes))
                    CompactFlightValue(title: "Рабочая ночь", value: timeText(current.workNightMinutes))
                    CompactFlightValue(title: "Полётная ночь", value: timeText(current.flightNightMinutes))
                    CompactFlightValue(title: "Лётная ночь", value: timeText(current.airNightMinutes))
                }

                if current.restMinutes > 0 {
                    Label("Разделённая смена: время отдыха между рабочими интервалами не входит в рабочее время.",
                          systemImage: "moon.zzz")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(current.legs) { leg in
                    let index = current.legs.firstIndex(where: { $0.id == leg.id })!
                    legCard(leg, workEnd: current.workIntervals[index].end)
                }
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(current.firstLeg.assignmentNumber.map { "Задание № \($0)" } ?? "Полётная смена")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingFlight) { flight in
            AddFlightView(flight: flight) { updated in
                store.updateFlight(updated)
            }
        }
        .alert("Удалить лег?", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) { deletingFlight = nil }
            Button("Удалить", role: .destructive) {
                if let flight = deletingFlight {
                    store.deleteFlight(id: flight.id)
                    if current.legs.count <= 1 { dismiss() }
                }
                deletingFlight = nil
            }
        } message: {
            Text(deletingFlight.map { "\($0.displayedLegNumber)  \($0.departure) → \($0.arrival)" } ?? "")
        }
    }

    private func legCard(_ leg: FlightLeg, workEnd: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Рейс № \(leg.displayedLegNumber)  \(leg.departure) → \(leg.arrival)")
                        .font(.headline)
                    Text("\((leg.scheduleType ?? .planned).rawValue) • \(leg.aircraft) • \(leg.registration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Редактировать", systemImage: "pencil") { editingFlight = leg }
                    Button(role: .destructive) {
                        deletingFlight = leg
                        showDeleteConfirmation = true
                    } label: {
                        Label("Удалить лег", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .padding(8)
                }
                .accessibilityLabel("Действия с рейсом \(leg.displayedLegNumber)")
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                CompactFlightValue(title: "Начало работы", value: formatDateTime(leg.timeline.workStart))
                CompactFlightValue(title: "Включение", value: formatDateTime(leg.timeline.engineOn))
                CompactFlightValue(title: "Взлёт", value: formatDateTime(leg.timeline.takeoff))
                CompactFlightValue(title: "Посадка", value: formatDateTime(leg.timeline.landing))
                CompactFlightValue(title: "Выключение", value: formatDateTime(leg.timeline.engineOff))
                CompactFlightValue(title: "Окончание работы", value: formatDateTime(workEnd))
                CompactFlightValue(title: "Полётное", value: timeText(leg.flightMinutes))
                CompactFlightValue(title: "Лётное", value: timeText(leg.airMinutes))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
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


// MARK: - Тест физической клавиатуры

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

struct AddFlightView: View {
    
    @Environment(
        \.dismiss
    )
    private var dismiss
    
    
    let flightToEdit:
    FlightLeg?
    
    
    let onSave:
    (FlightLeg) -> Void
    
    
    @State
    private var date:
    Date
    
    
    @State
    private var flightNumber:
    String

    @State private var chosenLegNumber: String

    private var numberParts: [String] {
        flightNumber.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    }

    
    @State
    private var departure:
    String
    
    
    @State
    private var arrival:
    String
    
    
    @State
    private var aircraft:
    String
    
    
    @State
    private var registration:
    String
    
    
    @State private var scheduleType: FlightScheduleType

    @State
    private var workStart:
    Date
    
    
    @State
    private var engineOn:
    Date
    
    
    @State
    private var takeoff:
    Date
    
    
    @State
    private var landing:
    Date
    
    
    @State
    private var engineOff:
    Date
    
    
    init(
        flight: FlightLeg? = nil,
        onSave: @escaping (FlightLeg) -> Void
    ) {
        
        self.flightToEdit =
        flight
        
        self.onSave =
        onSave
        
        
        let now =
        Date()
        
        
        if let flight {
            
            _date =
            State(
                initialValue:
                    moscowCalendar
                    .startOfDay(
                        for:
                            (flight.portalTimes == nil ? flight.timeline.plannedDeparture : flight.timeline.engineOn)
                    )
            )
            
            
            _flightNumber =
            State(
                initialValue:
                    flight.flightNumber
            )
            _chosenLegNumber = State(initialValue: flight.legNumber ?? flight.flightNumber.components(separatedBy: "/").first ?? "")

            _departure =
            State(
                initialValue:
                    flight.departure
            )
            
            
            _arrival =
            State(
                initialValue:
                    flight.arrival
            )
            
            
            _aircraft =
            State(
                initialValue:
                    flight.aircraft
            )
            
            
            _registration =
            State(
                initialValue:
                    flight.registration
            )
            
            
            _scheduleType = State(initialValue: flight.scheduleType ?? .planned)

            _workStart =
            State(
                initialValue:
                    flight.timeline.workStart
            )
            
            
            _engineOn =
            State(
                initialValue:
                    flight.timeline.engineOn
            )
            
            
            _takeoff =
            State(
                initialValue:
                    flight.timeline.takeoff
            )
            
            
            _landing =
            State(
                initialValue:
                    flight.timeline.landing
            )
            
            
            _engineOff =
            State(
                initialValue:
                    flight.timeline.engineOff
            )
            
        } else {
            
            _date =
            State(
                initialValue:
                    now
            )
            
            
            _flightNumber =
            State(
                initialValue:
                    ""
            )
            _chosenLegNumber = State(initialValue: "")

            _departure =
            State(
                initialValue:
                    "SVO"
            )
            
            
            _arrival =
            State(
                initialValue:
                    ""
            )
            
            
            _aircraft =
            State(
                initialValue:
                    "Airbus A320"
            )
            
            
            _registration =
            State(
                initialValue:
                    ""
            )
            
            
            _scheduleType = State(initialValue: .planned)

            _workStart =
            State(
                initialValue:
                    now
            )
            
            
            _engineOn =
            State(
                initialValue:
                    now
            )
            
            
            _takeoff =
            State(
                initialValue:
                    now
            )
            
            
            _landing =
            State(
                initialValue:
                    now
            )
            
            
            _engineOff =
            State(
                initialValue:
                    now
            )
        }
    }
    
    
    var canSave: Bool {
        
        !departure
            .trimmingCharacters(
                in: .whitespaces
            )
            .isEmpty
        
        &&
        !arrival
            .trimmingCharacters(
                in: .whitespaces
            )
            .isEmpty
        &&
        numberParts.allSatisfy({ part in
            part.count >= 1 && part.count <= 4 &&
            part.utf8.allSatisfy({ byte in byte >= 48 && byte <= 57 })
        })
    }
    
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                Section("Рейс") {
                    
                    DatePicker(
                        "Дата",
                        selection:
                            $date,
                        displayedComponents:
                                .date
                    )
                    .disabled(flightToEdit?.portalTimes != nil)
                    
                    
                    HardwareKeyboardTextField(
                        text: $flightNumber,
                        placeholder: "Номер рейса"
                    )
                    .frame(minHeight: 22)
                    if numberParts.count > 1 {
                        Picker("Номер этого лега", selection: $chosenLegNumber) {
                            ForEach(numberParts, id: \.self) { number in
                                Text(number).tag(number)
                            }
                        }
                    }
                    
                    TextField(
                        "Аэропорт вылета",
                        text:
                            $departure
                    )
                    
                    
                    TextField(
                        "Аэропорт прилёта",
                        text:
                            $arrival
                    )
                    
                    
                    TextField(
                        "Тип ВС",
                        text:
                            $aircraft
                    )
                    
                    
                    TextField(
                        "Борт",
                        text:
                            $registration
                    )
                    Picker("Тип рейса", selection: $scheduleType) {
                        ForEach(FlightScheduleType.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                }
                
                
                Section(
                    "Рабочее время"
                ) {
                    
                    AeroTimePickerRow(
                        title: "Начало работы",
                        selection: $workStart
                    )
                    .disabled(flightToEdit?.portalTimes != nil)
                }
                
                
                Section("Полёт") {
                    
                    AeroTimePickerRow(
                        title: "Включение двигателей",
                        selection: $engineOn
                    )
                    .disabled(flightToEdit?.portalTimes != nil)
                    
                    
                    AeroTimePickerRow(
                        title: "Взлёт",
                        selection: $takeoff
                    )
                    .disabled(flightToEdit?.portalTimes != nil)
                    
                    
                    AeroTimePickerRow(
                        title: "Посадка",
                        selection: $landing
                    )
                    .disabled(flightToEdit?.portalTimes != nil)
                    
                    
                    AeroTimePickerRow(
                        title: "Выключение двигателей",
                        selection: $engineOff
                    )
                    .disabled(flightToEdit?.portalTimes != nil)
                }
            }
            
            
            .environment(
                \.timeZone,
                 moscowTimeZone
            )
            
            
            .navigationTitle(
                flightToEdit == nil
                ? "Новый лег"
                : "Редактирование лега"
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
                        
                        saveFlight()
                    }
                    .disabled(
                        !canSave
                    )
                }
            }
        }
    }
    
    
    func saveFlight() {
        
        let flight =
        FlightLeg(
            id:
                flightToEdit?.id
            ?? UUID(),
            date:
                formatDate(
                    date
                ),
            flightNumber:
                flightNumber.isEmpty
            ? "Без номера"
            : flightNumber,
            departure:
                departure
                .uppercased(),
            arrival:
                arrival
                .uppercased(),
            aircraft:
                aircraft,
            registration:
                registration
                .uppercased(),
            plannedDeparture:
                flightToEdit?.plannedDeparture ?? "",
            workStart:
                formatClock(
                    workStart
                ),
            engineOn:
                formatClock(
                    engineOn
                ),
            takeoff:
                formatClock(
                    takeoff
                ),
            landing:
                formatClock(
                    landing
                ),
            engineOff:
                formatClock(
                    engineOff
                ),
            portalTimes: flightToEdit?.portalTimes,
            assignmentNumber: flightToEdit?.assignmentNumber,
            legNumber: numberParts.contains(chosenLegNumber) ? chosenLegNumber : numberParts.first,
            scheduleType: scheduleType
        )
        
        
        onSave(
            flight
        )
        
        
        dismiss()
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
