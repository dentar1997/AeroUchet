import SwiftUI
import Foundation


// MARK: - Вид отсутствия

enum AbsenceType:
    String,
    Codable,
    CaseIterable,
    Identifiable {
    
    case vacation =
            "Отпуск"
    
    case studyLeave =
            "Учебный отпуск"
    
    case vlek =
            "ВЛЭК"
    
    case waterLand =
            "Суша-вода"
    
    case occupationalSafety =
            "Охрана труда / учёба"
    
    
    var id: String {
        rawValue
    }
    
    
    var icon: String {
        
        switch self {
            
        case .vacation:
            return "sun.max.fill"
            
        case .studyLeave:
            return "book.fill"
            
        case .vlek:
            return "cross.case.fill"
            
        case .waterLand:
            return "figure.pool.swim"
            
        case .occupationalSafety:
            return "shield.fill"
        }
    }
    
    
    var color: Color {
        
        switch self {
            
        case .vacation:
            return .orange
            
        case .studyLeave:
            return .indigo
            
        case .vlek:
            return .red
            
        case .waterLand:
            return .cyan
            
        case .occupationalSafety:
            return .brown
        }
    }
    
    
    var paymentBasis: String {
        
        switch self {
            
        case .vacation,
                .studyLeave:
            
            return
            "Средний дневной"
            
            
        case .vlek,
                .waterLand,
                .occupationalSafety:
            
            return
            "Средний часовой"
        }
    }
}


// MARK: - Отсутствие

struct AbsenceEvent:
    Identifiable,
    Codable {
    
    var id: UUID
    
    var type:
    AbsenceType
    
    var startDate:
    Date
    
    var endDate:
    Date
    
    var wholeDay:
    Bool
    
    var note:
    String
    
    
    init(
        id: UUID = UUID(),
        type: AbsenceType,
        startDate: Date,
        endDate: Date,
        wholeDay: Bool,
        note: String = ""
    ) {
        
        self.id =
        id
        
        self.type =
        type
        
        self.startDate =
        startDate
        
        self.endDate =
        endDate
        
        self.wholeDay =
        wholeDay
        
        self.note =
        note
    }
    
    
    var normalizedStart:
    Date {
        
        if wholeDay {
            
            return moscowCalendar
                .startOfDay(
                    for:
                        startDate
                )
        }
        
        
        return startDate
    }
    
    
    var normalizedEnd:
    Date {
        
        if wholeDay {
            
            let endDay =
            moscowCalendar
                .startOfDay(
                    for:
                        max(
                            startDate,
                            endDate
                        )
                )
            
            
            return moscowCalendar.date(
                byAdding:
                        .day,
                value:
                    1,
                to:
                    endDay
            )!
        }
        
        
        return max(
            startDate,
            endDate
        )
    }
}


// MARK: - Хранилище

final class AbsenceStore:
    ObservableObject {
    
    @Published
    var absences:
    [AbsenceEvent] = [] {
        
        didSet {
            save()
        }
    }
    
    
    private let storageKey =
    "savedAbsenceEvents"
    
    
    init() {
        
        load()
    }
    
    
    func add(
        _ absence:
        AbsenceEvent
    ) {
        
        absences.append(
            absence
        )
        
        
        absences.sort {
            
            $0.normalizedStart
            >
            $1.normalizedStart
        }
    }
    
    
    func update(
        _ absence:
        AbsenceEvent
    ) {
        
        guard let index =
                absences.firstIndex(
                    where: {
                        $0.id == absence.id
                    }
                )
        else {
            return
        }
        
        
        var updatedAbsences =
        absences
        
        
        updatedAbsences[index] =
        absence
        
        
        updatedAbsences.sort {
            
            $0.normalizedStart
            >
            $1.normalizedStart
        }
        
        
        absences =
        updatedAbsences
    }
    
    
    func delete(
        id: UUID
    ) {
        
        absences.removeAll {
            
            $0.id
            ==
            id
        }
    }
    
    
    private func save() {
        
        do {
            
            let data =
            try JSONEncoder()
                .encode(
                    absences
                )
            
            
            UserDefaults.standard
                .set(
                    data,
                    forKey:
                        storageKey
                )
            
        } catch {
            
            print(
                "Ошибка сохранения отсутствий:",
                error
            )
        }
    }
    
    
    private func load() {
        
        guard
            let data =
                UserDefaults.standard
                .data(
                    forKey:
                        storageKey
                )
                
        else {
            return
        }
        
        
        do {
            
            absences =
            try JSONDecoder()
                .decode(
                    [AbsenceEvent].self,
                    from:
                        data
                )
            
        } catch {
            
            print(
                "Ошибка загрузки отсутствий:",
                error
            )
        }
    }
}


// MARK: - Сколько отсутствие уменьшает норму дня

func absenceMinutes(
    absence: AbsenceEvent,
    day: Date
) -> Int {
    
    let scheduled =
    productionScheduledMinutes(
        for:
            day
    )
    
    
    guard scheduled > 0
    else {
        return 0
    }
    
    
    let dayStart =
    moscowCalendar
        .startOfDay(
            for:
                day
        )
    
    
    let dayEnd =
    moscowCalendar.date(
        byAdding:
                .day,
        value:
            1,
        to:
            dayStart
    )!
    
    
    let overlap =
    overlapMinutes(
        start1:
            absence.normalizedStart,
        end1:
            absence.normalizedEnd,
        start2:
            dayStart,
        end2:
            dayEnd
    )
    
    
    guard overlap > 0
    else {
        return 0
    }
    
    
    // Целый день уменьшает норму
    // ровно на норму этого рабочего дня:
    // 7:12 либо 6:12.
    
    if absence.wholeDay {
        
        return scheduled
    }
    
    
    // Частичное отсутствие —
    // по его продолжительности,
    // но не больше нормы дня.
    
    return min(
        overlap,
        scheduled
    )
}


// MARK: - Все отсутствия месяца

func totalAbsenceMinutes(
    month: Date,
    absences:
    [AbsenceEvent]
) -> Int {
    
    var total = 0
    
    
    for day in daysInMonth(
        month
    ) {
        
        let scheduled =
        productionScheduledMinutes(
            for:
                day
        )
        
        
        guard scheduled > 0
        else {
            continue
        }
        
        
        var dayAbsence =
        0
        
        
        for absence in absences {
            
            dayAbsence +=
            absenceMinutes(
                absence:
                    absence,
                day:
                    day
            )
        }
        
        
        // Несколько пересекающихся
        // отсутствий не могут уменьшить
        // норму больше нормы самого дня.
        
        total += min(
            dayAbsence,
            scheduled
        )
    }
    
    
    return total
}


// MARK: - Один вид отсутствия за месяц

func absenceMinutesForType(
    type: AbsenceType,
    month: Date,
    absences:
    [AbsenceEvent]
) -> Int {
    
    var total =
    0
    
    
    let filtered =
    absences.filter {
        
        $0.type
        ==
        type
    }
    
    
    for day in daysInMonth(
        month
    ) {
        
        let scheduled =
        productionScheduledMinutes(
            for:
                day
        )
        
        
        guard scheduled > 0
        else {
            continue
        }
        
        
        var dayTotal =
        0
        
        
        for absence in filtered {
            
            dayTotal +=
            absenceMinutes(
                absence:
                    absence,
                day:
                    day
            )
        }
        
        
        total += min(
            dayTotal,
            scheduled
        )
    }
    
    
    return total
}


// MARK: - Отсутствия по дням календаря

func buildAbsencesByDay(
    absences:
    [AbsenceEvent]
) -> [Int: [AbsenceEvent]] {
    
    var result:
    [Int: [AbsenceEvent]] = [:]
    
    
    for absence in absences {
        
        for day in touchedDays(
            from:
                absence.normalizedStart,
            to:
                absence.normalizedEnd
        ) {
            
            result[
                dayKey(
                    day
                ),
                default: []
            ]
                .append(
                    absence
                )
        }
    }
    
    
    return result
}


// MARK: - Добавление / редактирование отсутствия

struct AddAbsenceView: View {
    
    @Environment(
        \.dismiss
    )
    private var dismiss
    
    
    let absenceToEdit:
    AbsenceEvent?
    
    
    let onSave:
    (AbsenceEvent) -> Void
    
    
    @State
    private var type:
    AbsenceType
    
    
    @State
    private var wholeDay:
    Bool
    
    
    @State
    private var startDate:
    Date
    
    
    @State
    private var endDate:
    Date
    
    
    @State
    private var note:
    String
    
    
    init(
        absence: AbsenceEvent? = nil,
        onSave: @escaping (AbsenceEvent) -> Void
    ) {
        
        self.absenceToEdit =
        absence
        
        
        self.onSave =
        onSave
        
        
        let now =
        Date()
        
        
        if let absence {
            
            _type =
            State(
                initialValue:
                    absence.type
            )
            
            
            _wholeDay =
            State(
                initialValue:
                    absence.wholeDay
            )
            
            
            _startDate =
            State(
                initialValue:
                    absence.startDate
            )
            
            
            _endDate =
            State(
                initialValue:
                    absence.endDate
            )
            
            
            _note =
            State(
                initialValue:
                    absence.note
            )
            
        } else {
            
            _type =
            State(
                initialValue:
                        .vacation
            )
            
            
            _wholeDay =
            State(
                initialValue:
                    true
            )
            
            
            _startDate =
            State(
                initialValue:
                    now
            )
            
            
            _endDate =
            State(
                initialValue:
                    now
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
                    "Отсутствие"
                ) {
                    
                    Picker(
                        "Тип",
                        selection:
                            $type
                    ) {
                        
                        ForEach(
                            AbsenceType
                                .allCases
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
                    
                    
                    Toggle(
                        "Целый день",
                        isOn:
                            $wholeDay
                    )
                    
                    
                    TextField(
                        "Комментарий",
                        text:
                            $note
                    )
                }
                
                
                Section(
                    "Период"
                ) {
                    
                    DatePicker(
                        "Начало",
                        selection:
                            $startDate,
                        displayedComponents:
                            wholeDay
                        ? .date
                        : [
                            .date,
                            .hourAndMinute
                        ]
                    )
                    
                    
                    DatePicker(
                        "Окончание",
                        selection:
                            $endDate,
                        in:
                            startDate...,
                        displayedComponents:
                            wholeDay
                        ? .date
                        : [
                            .date,
                            .hourAndMinute
                        ]
                    )
                }
                
                
                Section(
                    "Оплата"
                ) {
                    
                    HStack {
                        
                        Text(
                            "Основа"
                        )
                        
                        
                        Spacer()
                        
                        
                        Text(
                            type
                                .paymentBasis
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    
                    
                    Text(
                        "Сейчас отсутствие уменьшает норму рабочего времени. Расчёт денег по среднему заработку добавим в разделе «Зарплата»."
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            
            
            .environment(
                \.timeZone,
                 moscowTimeZone
            )
            
            
            .navigationTitle(
                absenceToEdit == nil
                ? "Новое отсутствие"
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
                        
                        saveAbsence()
                    }
                }
            }
        }
    }
    
    
    func saveAbsence() {
        
        let absence =
        AbsenceEvent(
            id:
                absenceToEdit?.id
            ?? UUID(),
            type:
                type,
            startDate:
                startDate,
            endDate:
                endDate,
            wholeDay:
                wholeDay,
            note:
                note
                .trimmingCharacters(
                    in:
                            .whitespacesAndNewlines
                )
        )
        
        
        onSave(
            absence
        )
        
        
        dismiss()
    }
}


// MARK: - Список отсутствий

struct AbsencesListView: View {
    
    @ObservedObject
    var store:
    AbsenceStore
    
    
    @State
    private var showAdd =
    false
    
    
    var body: some View {
        
        List {
            
            if store
                .absences
                .isEmpty {
                
                ContentUnavailableView(
                    "Отсутствий нет",
                    systemImage:
                        "calendar.badge.minus",
                    description:
                        Text(
                            "Добавь отпуск, ВЛЭК, учебный отпуск или другое отсутствие."
                        )
                )
                
            } else {
                
                ForEach(
                    store.absences
                ) { absence in
                    
                    NavigationLink {
                        
                        AbsenceDetailView(
                            absence:
                                absence,
                            store:
                                store
                        )
                        
                    } label: {
                        
                        AbsenceRow(
                            absence:
                                absence
                        )
                    }
                }
            }
        }
        
                .navigationTitle(
            "Отсутствия"
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
            
            AddAbsenceView {
                
                absence in
                
                store.add(
                    absence
                )
            }
        }
    }
}


// MARK: - Детали отсутствия

struct AbsenceDetailView: View {
    
    @Environment(
        \.dismiss
    )
    private var dismiss
    
    
    let absence:
    AbsenceEvent
    
    
    @ObservedObject
    var store:
    AbsenceStore
    
    
    @State
    private var showEdit =
    false
    
    
    @State
    private var showDeleteConfirmation =
    false
    
    
    var currentAbsence:
    AbsenceEvent {
        
        store.absences
            .first {
                $0.id == absence.id
            }
        ?? absence
    }
    
    
    var body: some View {
        
        let current =
        currentAbsence
        
        
        List {
            
            Section(
                "Отсутствие"
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
                        "Период",
                    value:
                        absencePeriodText(
                            current
                        )
                )
                
                
                FlightInfoRow(
                    name:
                        "Режим",
                    value:
                        current.wholeDay
                    ? "Целый день"
                    : "По времени"
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
            
            
            Section(
                "Оплата"
            ) {
                
                FlightInfoRow(
                    name:
                        "Основа",
                    value:
                        current.type
                        .paymentBasis
                )
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
                        "Удалить отсутствие",
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
            
            AddAbsenceView(
                absence:
                    current
            ) { updatedAbsence in
                
                store.update(
                    updatedAbsence
                )
            }
        }
        
        
        .alert(
            "Удалить отсутствие?",
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
                
                store.delete(
                    id:
                        current.id
                )
                
                
                dismiss()
            }
            
        } message: {
            
            Text(
                "\(current.type.rawValue)\n\(absencePeriodText(current))\nЭто действие нельзя отменить."
            )
        }
    }
}


// MARK: - Строка отсутствия

struct AbsenceRow: View {
    
    let absence:
    AbsenceEvent
    
    
    var body: some View {
        
        HStack(
            spacing: 14
        ) {
            
            Image(
                systemName:
                    absence.type.icon
            )
            .font(.title2)
            .foregroundStyle(
                absence.type.color
            )
            .frame(
                width: 34
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    absence
                        .type
                        .rawValue
                )
                .bold()
                
                
                Text(
                    absencePeriodText(
                        absence
                    )
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    absence
                        .type
                        .paymentBasis
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                
                
                if !absence
                    .note
                    .isEmpty {
                    
                    Text(
                        absence.note
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            
            
            Spacer()
        }
        .padding(
            .vertical,
            4
        )
    }
}


// MARK: - Текст периода

func absencePeriodText(
    _ absence:
    AbsenceEvent
) -> String {
    
    if absence.wholeDay {
        
        let start =
        formatDate(
            absence.startDate
        )
        
        
        let end =
        formatDate(
            absence.endDate
        )
        
        
        if start == end {
            
            return start
        }
        
        
        return
        "\(start) – \(end)"
    }
    
    
    return
    "\(formatDateTime(absence.startDate)) – \(formatDateTime(absence.endDate))"
}