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
    private var mode =
    0
    
    
    @State
    private var showAddFlight =
    false

    @State private var showImport = false
    @State private var showImportConfirmation = false
    @State private var showImportResult = false
    @State private var importMessage = ""
    @State private var pendingFlights: [FlightLeg] = []

    var body: some View {
        
        NavigationStack {
            
            VStack(
                spacing: 0
            ) {
                
                Picker(
                    "Вид",
                    selection:
                        $mode
                ) {
                    
                    Text("Смены")
                        .tag(0)
                    
                    
                    Text("Леги")
                        .tag(1)
                }
                .pickerStyle(
                    .segmented
                )
                .padding()
                
                
                if mode == 0 {
                    
                    DutiesListView(
                        store:
                            store
                    )
                    
                } else {
                    
                    LegsListView(
                        store:
                            store
                    )
                }
            }
            
            
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
                    pendingFlights = try PortalFlightHistory.parse(Data(contentsOf: url))
                    showImportConfirmation = true
                } catch {
                    importMessage = error.localizedDescription
                    showImportResult = true
                }
            }
            .alert("Импорт истории рейсов", isPresented: $showImportConfirmation) {
                Button("Отмена", role: .cancel) { pendingFlights = [] }
                Button("Импортировать") {
                    let added = store.importFlights(pendingFlights)
                    importMessage = "Добавлено: \(added). Уже были в приложении: \(pendingFlights.count - added)."
                    pendingFlights = []
                    showImportResult = true
                }
            } message: {
                let known = Set(store.flights.map { $0.historyKey })
                let unique = Set(pendingFlights.map { $0.historyKey })
                Text("В файле \(pendingFlights.count) рейсов. Новых: \(unique.subtracting(known).count). Повторная загрузка не создаст копии.")
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
                    "\(duty.legs.count) лег. • \(formatDate(duty.start))"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    "\(formatClock(duty.start)) – \(formatClock(duty.end))"
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
    
    let duty:
    FlightDuty
    
    
    var body: some View {
        
        List {
            
            Section(
                "Полётная смена"
            ) {
                
                FlightInfoRow(
                    name:
                        "Маршрут",
                    value:
                        duty.routeText
                )
                
                
                FlightInfoRow(
                    name:
                        "Начало",
                    value:
                        formatDateTime(
                            duty.start
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Окончание",
                    value:
                        formatDateTime(
                            duty.end
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Рабочее время",
                    value:
                        timeText(
                            duty.workMinutes
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Рабочая ночь",
                    value:
                        timeText(
                            duty.workNightMinutes
                        )
                )
            }
            
            
            Section(
                "Итоги"
            ) {
                
                FlightInfoRow(
                    name:
                        "Полётное",
                    value:
                        timeText(
                            duty.flightMinutes
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Лётное",
                    value:
                        timeText(
                            duty.airMinutes
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Полётная ночь",
                    value:
                        timeText(
                            duty.flightNightMinutes
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Лётная ночь",
                    value:
                        timeText(
                            duty.airNightMinutes
                        )
                )
            }
            
            
            Section(
                "Леги"
            ) {
                
                ForEach(
                    duty.legs
                ) { flight in
                    
                    NavigationLink {
                        
                        FlightDetailView(
                            flight:
                                flight
                        )
                        
                    } label: {
                        
                        FlightRow(
                            flight:
                                flight
                        )
                    }
                }
            }
        }
        
        
        .navigationTitle(
            "Полётная смена"
        )
        
        
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
}


// MARK: - Леги

struct LegsListView: View {
    
    @ObservedObject
    var store: AppStore
    
    
    var flights:
    [FlightLeg] {
        
        store.flights
            .sorted {
                
                $0.timeline.workStart
                >
                $1.timeline.workStart
            }
    }
    
    
    var body: some View {
        
        List {
            
            ForEach(
                flights
            ) { flight in
                
                NavigationLink {
                    
                    FlightDetailView(
                        flight:
                            flight
                    )
                    
                } label: {
                    
                    FlightRow(
                        flight:
                            flight
                    )
                }
            }
        }
    }
}


// MARK: - Строка лега

struct FlightRow: View {
    
    let flight:
    FlightLeg
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    "airplane"
            )
            .foregroundStyle(
                .blue
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 3
            ) {
                
                Text(
                    "\(flight.departure) → \(flight.arrival)"
                )
                .bold()
                
                
                Text(
                    "\(flight.flightNumber) • \(flight.aircraft)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    flight.date
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                
                
                if !flight.hasValidStoredDates {
                    
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
            
            
            Text(flight.portalTimes == nil ? flight.plannedDeparture : flight.engineOn)
            .bold()
        }
    }
}


// MARK: - Детали лега

struct FlightDetailView: View {
    
    @Environment(
        \.dismiss
    )
    private var dismiss
    
    
    @EnvironmentObject
    private var store:
    AppStore
    
    
    let flight:
    FlightLeg
    
    
    @State
    private var showEdit =
    false
    
    
    @State
    private var showDeleteConfirmation =
    false
    
    
    var currentFlight:
    FlightLeg {
        
        store.flights
            .first {
                $0.id == flight.id
            }
        ?? flight
    }
    
    
    var body: some View {
        
        let current =
        currentFlight
        
        
        List {
            
            Section("Рейс") {
                
                FlightInfoRow(
                    name:
                        "Маршрут",
                    value:
                        "\(current.departure) → \(current.arrival)"
                )
                
                
                FlightInfoRow(
                    name:
                        "Номер",
                    value:
                        current.flightNumber
                )
                
                
                FlightInfoRow(
                    name:
                        "Тип ВС",
                    value:
                        current.aircraft
                )
                
                
                FlightInfoRow(
                    name:
                        "Борт",
                    value:
                        current.registration
                )
            }
            
            
            if current.hasValidStoredDates {
                
                Section("Время") {
                    
                    FlightInfoRow(
                        name:
                            "Начало работы",
                        value:
                            formatDateTime(
                                current.timeline.workStart
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name: "Плановое отправление",
                        value: current.portalTimes == nil
                            ? formatDateTime(current.timeline.plannedDeparture)
                            : "Нет в выгрузке"
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Включение двигателей",
                        value:
                            formatDateTime(
                                current.timeline.engineOn
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Взлёт",
                        value:
                            formatDateTime(
                                current.timeline.takeoff
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Посадка",
                        value:
                            formatDateTime(
                                current.timeline.landing
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Выключение двигателей",
                        value:
                            formatDateTime(
                                current.timeline.engineOff
                            )
                    )
                    if let actualEnd = current.portalTimes?.workEnd {
                        FlightInfoRow(name: "Завершение работы", value: formatDateTime(actualEnd))
                    }
                }
                
                
                Section("Расчёт") {
                    
                    FlightInfoRow(
                        name:
                            "Полётное",
                        value:
                            timeText(
                                current.flightMinutes
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Лётное",
                        value:
                            timeText(
                                current.airMinutes
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Полётная ночь",
                        value:
                            timeText(
                                current.flightNightMinutes
                            )
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Лётная ночь",
                        value:
                            timeText(
                                current.airNightMinutes
                            )
                    )
                }
                
            } else {
                
                Section {
                    
                    Label(
                        "Дата или время сохранены в неверном формате. Рейс не участвует в расчётах, пока запись не будет исправлена.",
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
                            "Начало работы",
                        value:
                            current.workStart
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Плановое отправление",
                        value:
                            current.plannedDeparture
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Включение двигателей",
                        value:
                            current.engineOn
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Взлёт",
                        value:
                            current.takeoff
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Посадка",
                        value:
                            current.landing
                    )
                    
                    
                    FlightInfoRow(
                        name:
                            "Выключение двигателей",
                        value:
                            current.engineOff
                    )
                }
            }
            
            
            Section("Действия") {
                
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
                        "Удалить рейс",
                        systemImage:
                            "trash"
                    )
                }
            }
        }
        
        
        .navigationTitle(
            "\(current.departure) → \(current.arrival)"
        )
        
        
        .navigationBarTitleDisplayMode(
            .inline
        )
        
        
        .sheet(
            isPresented:
                $showEdit
        ) {
            
            AddFlightView(
                flight:
                    current
            ) { updatedFlight in
                
                store.updateFlight(
                    updatedFlight
                )
            }
        }
        
        
        .alert(
            "Удалить рейс?",
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
                
                store.deleteFlight(
                    id:
                        current.id
                )
                
                
                dismiss()
            }
            
        } message: {
            
            Text(
                "\(current.flightNumber)  \(current.departure) → \(current.arrival)\nЭто действие нельзя отменить."
            )
        }
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
    
    
    @State
    private var plannedDeparture:
    Date
    
    
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
            
            
            _plannedDeparture =
            State(
                initialValue:
                    flight.timeline.plannedDeparture
            )
            
            
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
            
            
            _plannedDeparture =
            State(
                initialValue:
                    now
            )
            
            
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
                }
                
                
                Section(
                    "Рабочее время"
                ) {
                    
                    if flightToEdit?.portalTimes == nil {
                        AeroTimePickerRow(
                            title: "Плановое отправление",
                            selection: $plannedDeparture
                        )
                    } else {
                        Text("Плановое время отсутствует в истории портала")
                            .foregroundStyle(.secondary)
                    }
                    
                    
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
                flightToEdit?.portalTimes == nil ? formatClock(plannedDeparture) : "",
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
            portalTimes: flightToEdit?.portalTimes
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
