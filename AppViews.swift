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
                    "\(duty.firstLeg.assignmentNumber.map { "Полётное задание № \($0) • " } ?? "")\(duty.legs.count) лег. • \(formatDate(duty.start))"
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

    @State private var isEditing = false
    @State private var draft: [FlightLeg] = []
    @State private var original: [FlightLeg] = []
    @State private var assignmentNumber = ""
    @State private var showReview = false
    @State private var showDeleteConfirmation = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let timeColumns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 8),
        count: 3
    )

    private var current: FlightDuty {
        store.duties.first { candidate in
            candidate.legs.contains { $0.id == duty.firstLeg.id }
        } ?? duty
    }

    var body: some View {
        let current = current

        ScrollView {
            dutyCard(isEditing && isValid
                     ? FlightDuty(id: current.id, legs: updatedLegs)
                     : current)
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(16)
                .frame(maxWidth: .infinity)
        }
        .environment(\.timeZone, moscowTimeZone)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Полёты")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isEditing {
                    Button("Применить") { showReview = true }
                        .disabled(!isValid || differences.isEmpty)
                    Button("Отмена") {
                        isEditing = false
                        draft = []
                        original = []
                    }
                } else {
                    Button {
                        original = current.legs
                        draft = current.legs
                        assignmentNumber = current.firstLeg.assignmentNumber ?? ""
                        isEditing = true
                    } label: {
                        Image(systemName: "wrench")
                    }
                    .accessibilityLabel("Редактировать полётное задание")
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить полётное задание")
                }
            }
        }
        .sheet(isPresented: $showReview) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Заменить исходные данные на изменения?")
                            .font(.headline)

                        ForEach(differences, id: \.self) { item in
                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                        }
                    }
                    .padding()
                }
                .navigationTitle("Проверка изменений")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showReview = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Заменить") {
                            store.updateDutyLegs(updatedLegs)
                            isEditing = false
                            draft = []
                            original = []
                            showReview = false
                        }
                    }
                }
            }
        }
        .alert("Удалить полётное задание?", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить задание", role: .destructive) {
                store.deleteDutyLegs(ids: Set(current.legs.map(\.id)))
                dismiss()
            }
        } message: {
            Text("Задание и \(legCountText(current.legs.count)) будут удалены.")
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

        return zip(legs, legs.dropFirst()).allSatisfy {
            $0.0.timeline.workStart <= $0.1.timeline.workStart
        }
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
            add("Номер лега", old.legNumber ?? "—", new.legNumber ?? "—")
            add("Вылет", old.departure, new.departure)
            add("Прилёт", old.arrival, new.arrival)
            add("Тип ВС", old.aircraft, new.aircraft)
            add("Борт", old.registration, new.registration)
            add("Тип рейса", (old.scheduleType ?? .planned).rawValue,
                (new.scheduleType ?? .planned).rawValue)

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


    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { draft[index].legNumber ?? "" },
            set: { draft[index].legNumber = $0.isEmpty ? nil : $0 }
        )
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
            set: { newDate in
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
                         ? max(previous.workEnd, newDate)
                         : previous.workEnd)
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
        )
    }
    // Уровень 1: одна общая карточка полётного задания.
    private func dutyCard(_ duty: FlightDuty) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            dutyTitle(duty)
            dutyTotals(duty)


            ForEach(duty.legs.indices, id: \.self) { index in
                legCard(
                    duty.legs[index],
                    index: index,
                    workEnd: duty.workIntervals[index].end
                )

                if index + 1 < duty.legs.count {
                    let restStart = duty.workIntervals[index].end
                    let restEnd = duty.workIntervals[index + 1].start

                    if restEnd > restStart {
                        restCard(start: restStart, end: restEnd)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private func restCard(start: Date, end: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
                Text("Перерыв без работы")
                    .font(.subheadline.weight(.semibold))
                Text(timeText(minutesBetween(start, end)))
                    .font(.subheadline.weight(.semibold))
            }

            Text("\(formatDateTime(start)) → \(formatDateTime(end))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func dutyTitle(_ duty: FlightDuty) -> some View {
        ZStack {
            Group {
                if isEditing {
                    HStack {
                        Text("Полётное задание №")
                        TextField("Номер", text: $assignmentNumber)
                            .textInputAutocapitalization(.characters)
                            .frame(width: 145)
                    }
                } else {
                    Text(
                        duty.firstLeg.assignmentNumber.map {
                            "Полётное задание № \($0)"
                        } ?? "Полётное задание"
                    )
                }
            }
            .font(.title2.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                Text(legCountText(duty.legs.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
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
        HStack(spacing: 8) {
            dutyTotalCell(
                title: "Рабочее время",
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
        .padding(.horizontal, 12)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemGray4))
        )
        .accessibilityElement(children: .combine)
    }

    private func timeAndNight(total: Int, night: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(timeText(total))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("· ночь")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(timeText(night))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityLabel("\(timeText(total)), ночь \(timeText(night))")
    }

    // Уровень 2: отдельная карточка каждого лега.
    private func legCard(_ leg: FlightLeg, index: Int, workEnd: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            legHeader(leg, index: index)

            // Все исходные точки редактируются на месте. Итоги остаются вычисляемыми.
            LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 8) {
                timeCell(
                    title: "Начало работы",
                    value: formatDateTime(leg.timeline.workStart),
                    index: index, point: .workStart
                )
                timeCell(
                    title: "Включение двигателей",
                    value: formatDateTime(leg.timeline.engineOn),
                    index: index, point: .engineOn
                )
                timeCell(
                    title: "Взлёт",
                    value: formatDateTime(leg.timeline.takeoff),
                    index: index, point: .takeoff
                )
                timeCell(
                    title: "Завершение работы",
                    value: formatDateTime(workEnd),
                    index: index,
                    point: index == draft.count - 1 ? nil : .workEnd
                )
                timeCell(
                    title: "Выключение двигателей",
                    value: formatDateTime(leg.timeline.engineOff),
                    index: index, point: .engineOff
                )
                timeCell(
                    title: "Посадка",
                    value: formatDateTime(leg.timeline.landing),
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func legHeader(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if sizeClass == .compact {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        flightNumber(leg, index: index)
                        Spacer(minLength: 8)
                        calculatedTime(leg)
                            .frame(width: 155)
                    }
                    flightIdentity(leg, index: index)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    flightNumber(leg, index: index)
                        .frame(width: 155, alignment: .leading)
                    flightIdentity(leg, index: index)
                        .frame(maxWidth: .infinity)
                    calculatedTime(leg)
                        .frame(width: 155)
                }
            }
        }
    }

    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if isEditing {
                VStack(alignment: .leading, spacing: 3) {
                    TextField("Номер рейса", text: $draft[index].flightNumber)
                    TextField("Номер лега", text: legNumberBinding(index))
                        .font(.caption)
                }
            } else {
                Text("Рейс № \(leg.displayedLegNumber)")
            }
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.leading, 10)
    }

    private func flightIdentity(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if sizeClass == .compact {
                VStack(alignment: .leading, spacing: 8) {
                    identityField("Маршрут") {
                        routeIdentity(leg, index: index)
                    }
                    HStack(alignment: .top, spacing: 18) {
                        identityField("Тип ВС") {
                            aircraftIdentity(leg, index: index)
                        }
                        identityField("Вид полёта") {
                            flightKindIdentity(leg, index: index)
                        }
                        identityField("Бортовой номер") {
                            registrationIdentity(leg, index: index)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    identityField("Тип ВС") {
                        aircraftIdentity(leg, index: index)
                    }
                    .frame(width: 68, alignment: .leading)

                    identityField("Маршрут") {
                        routeIdentity(leg, index: index)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    identityField("Вид полёта") {
                        flightKindIdentity(leg, index: index)
                    }
                    .frame(width: 86, alignment: .leading)

                    identityField("Бортовой номер") {
                        registrationIdentity(leg, index: index)
                    }
                    .frame(width: 100, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identityField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            content()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func routeIdentity(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if isEditing {
                HStack(spacing: 4) {
                    TextField("Вылет", text: $draft[index].departure)
                        .frame(minWidth: 52)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    TextField("Прилёт", text: $draft[index].arrival)
                        .frame(minWidth: 52)
                }
            } else {
                Text(
                    "\(airportDisplayName(leg.departure)) → "
                    + "\(airportDisplayName(leg.arrival))"
                )
            }
        }
    }

    private func flightKindIdentity(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if isEditing {
                Picker("Вид полёта", selection: scheduleBinding(index)) {
                    ForEach(FlightScheduleType.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
            } else {
                Text((leg.scheduleType ?? .planned).rawValue)
            }
        }
    }

    private func aircraftIdentity(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if isEditing {
                TextField("Тип ВС", text: $draft[index].aircraft)
            } else {
                Text(leg.aircraft)
            }
        }
    }

    private func registrationIdentity(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if isEditing {
                TextField("Борт", text: $draft[index].registration)
            } else {
                Text(formattedRegistration(leg.registration))
            }
        }
    }

    private func calculatedTime(_ leg: FlightLeg) -> some View {
        legValueCard(
            title: "Расчётное время",
            value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму"
        )
    }

    private func timeCell(
        title: String,
        value: String,
        index: Int,
        point: DutyEditPoint?
    ) -> some View {
        Group {
            if isEditing, let point {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        title,
                        selection: timeBinding(index, point),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .systemGray4))
                )
            } else {
                legValueCard(title: title, value: value)
            }
        }
    }

    private func legValueCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemGray4))
        )
        .accessibilityElement(children: .combine)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemGray4))
        )
        .accessibilityElement(children: .combine)
    }

}


private enum DutyEditPoint: CaseIterable, Identifiable {
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
    let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let baseCode = code.split(separator: "/", maxSplits: 1).first.map(String.init) ?? code

    let names: [String: String] = [
        "SVO": "Шереметьево",
        "GYD": "Баку",
        "MQF": "Магнитогорск",
        "BAX": "Барнаул",
        "OVB": "Новосибирск",
        "AER": "Сочи",
        "KGD": "Калининград",
        "LED": "Санкт-Петербург",
        "KZN": "Казань",
        "SVX": "Екатеринбург",
        "UFA": "Уфа",
        "CEK": "Челябинск",
        "OMS": "Омск",
        "KUF": "Самара",
        "GOJ": "Нижний Новгород",
        "MRV": "Минеральные Воды",
        "MCX": "Махачкала",
        "VVO": "Владивосток",
        "KHV": "Хабаровск",
        "IKT": "Иркутск",
        "UUS": "Южно-Сахалинск",
        "PKC": "Петропавловск-Камчатский"
    ]

    guard let name = names[baseCode] else { return code }
    return "\(name) (\(code))"
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
