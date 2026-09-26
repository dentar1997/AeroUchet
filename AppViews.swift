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
    @ObservedObject var store: AppStore
    @State private var selectedDuty: FlightDuty?

    var body: some View {
        ZStack {
            List(store.duties) { duty in
                Button {
                    selectedDuty = duty
                } label: {
                    DutyRow(duty: duty)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        .navigationTitle(selectedDuty == nil ? "Полёты" : "")
    }
}

private struct DutyAssignmentOverlay: View {
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var editorIsActive = false

    var body: some View {
        GeometryReader { geometry in
            let widthRatio = geometry.size.width >= 800 ? 0.74 : 0.92
            let width = min(geometry.size.width * widthRatio, 940)

            ZStack {
                Color.black
                    .opacity(backgroundOpacity(for: geometry.size.height))
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                ScrollView(.vertical) {
                    DutyDetailView(
                        duty: duty,
                        onClose: onClose,
                        scrollsAsPage: true,
                        onEditorFocusChange: { editorIsActive = $0 }
                    )
                    .environmentObject(store)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
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
                        enabled: !editorIsActive
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func backgroundOpacity(for height: CGFloat) -> Double {
        guard height > 0 else { return 0.65 }
        let progress = min(max(dragOffset / height, 0), 1)
        return 0.65 * Double(1 - progress * 0.75)
    }

    private func dismissDrag(in height: CGFloat, enabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard enabled else {
                    dragOffset = 0
                    return
                }

                // Вниз карточка следует за пальцем полностью.
                // Вверх даём небольшой упругий ход, как у обычного sheet.
                if value.translation.height >= 0 {
                    dragOffset = value.translation.height
                } else {
                    dragOffset = max(value.translation.height * 0.18, -32)
                }
            }
            .onEnded { value in
                guard enabled else {
                    dragOffset = 0
                    return
                }

                let predicted = max(
                    value.translation.height,
                    value.predictedEndTranslation.height
                )
                let shouldClose =
                    value.translation.height > 110
                    || predicted > 220

                if shouldClose {
                    withAnimation(.easeOut(duration: 0.18)) {
                        dragOffset = max(height, 500)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onClose()
                    }
                } else {
                    withAnimation(
                        .spring(response: 0.28, dampingFraction: 0.82)
                    ) {
                        dragOffset = 0
                    }
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
                    AirportDatabase.routeDisplayName(
                        [duty.firstLeg.departure] + duty.legs.map(\.arrival)
                    )
                )
                .bold()
                
                
                Text(
                    "\(duty.firstLeg.assignmentNumber.map { "Задание на полёт № \($0) • " } ?? "")\(duty.legs.count) лег. • \(formatDate(duty.start))"
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
    let onClose: (() -> Void)?
    let scrollsAsPage: Bool
    let onEditorFocusChange: ((Bool) -> Void)?

    init(
        duty: FlightDuty,
        onClose: (() -> Void)? = nil,
        scrollsAsPage: Bool = false,
        onEditorFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
        self.onEditorFocusChange = onEditorFocusChange
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
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let timeColumns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 8),
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
        store.duties.first { candidate in
            candidate.legs.contains { $0.id == duty.firstLeg.id }
        } ?? duty
    }

    var body: some View {
        let current = current

        VStack(spacing: 0) {
            assignmentHeader(current)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(focusedField == .assignment ? 1000 : 1)

            if scrollsAsPage {
                assignmentContents(current)
            } else {
                ScrollView {
                    assignmentContents(current)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onChange(of: draft) { _ in recordEdit() }
        .onChange(of: assignmentNumber) { _ in recordEdit() }
        .onChange(of: focusedField) { value in
            onEditorFocusChange?(value != nil)
        }
        .onDisappear {
            onEditorFocusChange?(false)
        }
        .environment(\.timeZone, moscowTimeZone)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
        .alert("Удалить задание на полёт?", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить задание", role: .destructive) {
                store.deleteDutyLegs(ids: Set(current.legs.map(\.id)))
                close()
            }
        } message: {
            Text("Задание и \(legCountText(current.legs.count)) будут удалены.")
        }
    }

    private func assignmentHeader(_ duty: FlightDuty) -> some View {
        ZStack {
            dutyTitle(
                isEditing && isValid
                ? FlightDuty(id: duty.id, legs: updatedLegs)
                : duty
            )
            .padding(.horizontal, 180)

            HStack(spacing: 8) {
                Button(action: close) {
                    Image(systemName: "xmark.circle")
                }
                .accessibilityLabel("Закрыть задание")

                Spacer()

                if isEditing {
                    Button {
                        restoreEdit(at: historyIndex - 1)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(historyIndex == 0)
                    .accessibilityLabel("Отменить последнее изменение")

                    Button {
                        restoreEdit(at: historyIndex + 1)
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(historyIndex + 1 >= editHistory.count)
                    .accessibilityLabel("Повторить изменение")

                    Button {
                        focusedField = nil
                        showReview = true
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isValid || differences.isEmpty)
                    .accessibilityLabel("Применить изменения")

                    Button {
                        focusedField = nil
                        isEditing = false
                        draft = []
                        original = []
                        editHistory = []
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Отменить все изменения")
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
                    }
                    .accessibilityLabel("Редактировать задание на полёт")

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить задание на полёт")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
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
        dutyCard(isEditing && isValid
                 ? FlightDuty(id: duty.id, legs: updatedLegs)
                 : duty)
            .padding(16)
            .frame(maxWidth: .infinity)
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
            dutyTotals(duty)


            ForEach(duty.legs.indices, id: \.self) { index in
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
        }
    }

    private func restCard(start: Date, end: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Перерыв без работы")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
                Text(timeText(minutesBetween(start, end)))
                    .font(.subheadline.weight(.semibold))
            }

            Text("\(formatDateTime(start)) → \(formatDateTime(end))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 22)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func dutyTitle(_ duty: FlightDuty) -> some View {
        let title = duty.firstLeg.assignmentNumber.map {
            "Задание на полёт № \($0)"
        } ?? "Задание на полёт"

        return ZStack {
            Group {
                if isEditing {
                    ZStack {
                        Button {
                            focusedField = .assignment
                        } label: {
                            Text(title)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.08))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .overlay(alignment: .top) {
                        if focusedField == .assignment {
                            floatingEditor(width: 230) {
                                VStack(alignment: .leading, spacing: 5) {
                                    editPopoverHeader(
                                        "Задание на полёт №",
                                        extraHorizontalInset: 0
                                    )

                                    TextField("Номер", text: $assignmentNumber)
                                        .textInputAutocapitalization(.characters)
                                        .textFieldStyle(.plain)
                                        .font(.headline)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .offset(y: 42)
                        }
                    }
                    .zIndex(focusedField == .assignment ? 1000 : 0)
                    .accessibilityHint("Нажмите, чтобы изменить номер задания")
                } else {
                    Text(title)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .font(.title2.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
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
                .fill(valueTileColor)
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
                .zIndex(headerEditorZIndex(index))

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
                    value: formatDateTime(times(for: leg).workEnd),
                    index: index,
                    point: .workEnd
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
        LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 8) {
            Group {
                if sizeClass == .compact {
                    VStack(spacing: 4) {
                        flightNumber(leg, index: index)
                        aircraftField(leg, index: index)
                        registrationField(leg, index: index)
                    }
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        flightNumber(leg, index: index)
                        aircraftField(leg, index: index)
                        registrationField(leg, index: index)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            identityField("Маршрут", field: .route(index)) {
                routeIdentity(leg, index: index)
            }
            .frame(maxWidth: .infinity, alignment: .top)

            Group {
                if sizeClass == .compact {
                    VStack(spacing: 4) {
                        flightKindField(leg, index: index)
                        calculatedTime(leg, index: index)
                    }
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        flightKindField(leg, index: index)
                        calculatedTime(leg, index: index)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
    }

    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Рейс", field: .legNumber(index)) {
            editableValue(
                leg.displayedLegNumber,
                title: "Рейс",
                field: .legNumber(index)
            ) {
                TextField("Номер лега", text: legNumberBinding(index))
                    .multilineTextAlignment(.leading)
                    .keyboardType(.numberPad)
            }
        }
    }

    private func flightKindField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Вид полёта", field: .flightKind(index)) {
            flightKindIdentity(leg, index: index)
        }
    }

    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Тип ВС", field: .aircraft(index)) {
            aircraftIdentity(leg, index: index)
        }
    }

    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Бортовой номер", field: .registration(index)) {
            registrationIdentity(leg, index: index)
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
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
        .background {
            if isEditing {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
        .overlay {
            if isEditing {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { focusedField = field }
        }
    }

    private func routeIdentity(_ leg: FlightLeg, index: Int) -> some View {
        editableValue(
            "\(airportDisplayName(leg.departure)) → \(airportDisplayName(leg.arrival))",
            title: "Маршрут",
            field: .route(index)
        ) {
            HStack(spacing: 8) {
                TextField("Вылет", text: $draft[index].departure)
                    .textInputAutocapitalization(.characters)
                Image(systemName: "arrow.right")
                TextField("Прилёт", text: $draft[index].arrival)
                    .textInputAutocapitalization(.characters)
            }
        }
    }

    private func flightKindIdentity(_ leg: FlightLeg, index: Int) -> some View {
        editableValue(
            (leg.scheduleType ?? .planned).rawValue,
            title: "Вид полёта",
            field: .flightKind(index)
        ) {
            Picker("Вид полёта", selection: scheduleBinding(index)) {
                ForEach(FlightScheduleType.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func aircraftIdentity(_ leg: FlightLeg, index: Int) -> some View {
        editableValue(
            leg.aircraft,
            title: "Тип ВС",
            field: .aircraft(index)
        ) {
            TextField("Тип ВС", text: $draft[index].aircraft)
                .multilineTextAlignment(.leading)
        }
    }

    private func registrationIdentity(_ leg: FlightLeg, index: Int) -> some View {
        editableValue(
            formattedRegistration(leg.registration),
            title: "Бортовой номер",
            field: .registration(index)
        ) {
            TextField("Бортовой номер", text: $draft[index].registration)
                .textInputAutocapitalization(.characters)
                .multilineTextAlignment(.leading)
        }
    }

    private func focusBinding(_ field: DutyFocusedField) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { if !$0 { focusedField = nil } }
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
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

    private func timeEditorAlignment(for point: DutyEditPoint) -> Alignment {
        switch point {
        case .workStart, .workEnd:
            return .topLeading
        case .engineOn, .engineOff:
            return .top
        case .takeoff, .landing:
            return .topTrailing
        }
    }

    private func timeEditorVerticalOffset(for point: DutyEditPoint) -> CGFloat {
        switch point {
        case .workStart, .engineOn, .takeoff:
            return -205
        case .workEnd, .engineOff, .landing:
            return -226
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
            return 230
        default:
            return 260
        }
    }

    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {
        Group {
            if isEditing {
                ZStack {
                    Button {
                        focusedField = .calculatedTime(index)
                    } label: {
                        legValueCard(
                            title: "Расчётное время",
                            value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму"
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .overlay(alignment: .topTrailing) {
                    if focusedField == .calculatedTime(index) {
                        floatingEditor(width: 230) {
                            VStack(alignment: .leading, spacing: 6) {
                                editPopoverHeader(
                                    "Расчётное время",
                                    extraHorizontalInset: 0
                                )
                                .zIndex(60)

                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.secondary, lineWidth: 1.2)
                                            .frame(width: 20, height: 20)

                                        if draft[index].calculatedMinutesOverride == nil {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(Color.accentColor)
                                                .frame(width: 20, height: 20)

                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text("Из таблицы")
                                }
                                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                                .zIndex(50)
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        toggleCalculatedTimeSource(index)
                                    }
                                )

                                if draft[index].calculatedMinutesOverride != nil {
                                    DatePicker(
                                        "",
                                        selection: calculatedTimeBinding(index),
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                                    .frame(width: 172, height: 118)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .zIndex(0)
                                } else {
                                    Text(
                                        draft[index].calculatedMinutes.map(timeText)
                                        ?? "Ожидает норму"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .offset(y: 46)
                    }
                }
                .zIndex(focusedField == .calculatedTime(index) ? 1000 : 0)
            } else {
                legValueCard(
                    title: "Расчётное время",
                    value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму"
                )
            }
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

    private func calculatedTimeBinding(_ index: Int) -> Binding<Date> {
        let base = moscowCalendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1)
        )!

        return Binding(
            get: {
                moscowCalendar.date(
                    byAdding: .minute,
                    value: draft[index].calculatedMinutesOverride
                        ?? draft[index].flightMinutes,
                    to: base
                )!
            },
            set: { newDate in
                let components = moscowCalendar.dateComponents(
                    [.hour, .minute],
                    from: newDate
                )
                let hours = components.hour ?? 0
                let minutes = components.minute ?? 0
                draft[index].calculatedMinutesOverride = hours * 60 + minutes
            }
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
                ZStack {
                    Button {
                        focusedField = .time(index, point)
                    } label: {
                        legValueCard(title: title, value: formatDateTime(
                            point.date(in: times(for: draft[index]))
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .overlay(alignment: timeEditorAlignment(for: point)) {
                    if focusedField == .time(index, point) {
                        floatingEditor(width: 380, height: 226) {
                            VStack(alignment: .leading, spacing: 6) {
                                editPopoverHeader(title, extraHorizontalInset: 0)

                                HStack(alignment: .top, spacing: 12) {
                                    ZStack(alignment: .topLeading) {
                                        DatePicker(
                                            "",
                                            selection: timeBinding(index, point),
                                            displayedComponents: [.date]
                                        )
                                        .labelsHidden()
                                        .datePickerStyle(.graphical)
                                        .frame(width: 302, height: 246, alignment: .topLeading)
                                        .transaction { transaction in
                                            transaction.animation = nil
                                        }
                                        .animation(
                                            nil,
                                            value: point.date(in: times(for: draft[index]))
                                        )
                                        .scaleEffect(0.70, anchor: .topLeading)
                                    }
                                    .frame(
                                        width: 212,
                                        height: 172,
                                        alignment: .topLeading
                                    )
                                    .clipped()
                                    .contentShape(Rectangle())

                                    DatePicker(
                                        "",
                                        selection: timeBinding(index, point),
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                                    .frame(width: 130, height: 220)
                                    .scaleEffect(0.78, anchor: .topLeading)
                                    .frame(width: 102, height: 172, alignment: .topLeading)
                                    .clipped()
                                    .contentShape(Rectangle())
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .offset(y: timeEditorVerticalOffset(for: point))
                    }
                }
                .zIndex(focusedField == .time(index, point) ? 1000 : 0)
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
                .fill(valueTileColor)
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
                .fill(valueTileColor)
        )
        .accessibilityElement(children: .combine)
    }

}


private struct DutyEditSnapshot: Equatable {
    let legs: [FlightLeg]
    let assignment: String
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
