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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DutyAssignmentOverlay: View {
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    let onClose: () -> Void

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
                        } else if !editModeIsActive {
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
                        externalEditorDismissSignal: dismissEditorSignal
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
                            && !editModeIsActive
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
    let onEditModeChange: ((Bool) -> Void)?
    let externalEditorDismissSignal: Int

    init(
        duty: FlightDuty,
        onClose: (() -> Void)? = nil,
        scrollsAsPage: Bool = false,
        onEditorFocusChange: ((Bool) -> Void)? = nil,
        onEditModeChange: ((Bool) -> Void)? = nil,
        externalEditorDismissSignal: Int = 0
    ) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
        self.onEditorFocusChange = onEditorFocusChange
        self.onEditModeChange = onEditModeChange
        self.externalEditorDismissSignal = externalEditorDismissSignal
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
        store.duties.first { candidate in
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
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                if isEditing {
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

                    Button {
                        focusedField = nil
                        showReview = true
                    } label: {
                        Image(systemName: "checkmark")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(!isValid || differences.isEmpty)
                    .accessibilityLabel("Применить изменения")
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
                isEditing && isValid
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
        dutyCard(isEditing && isValid
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
        let restMinutes = minutesBetween(start, end)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Разделённая полётная смена")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("\(formatDateTime(start)) → \(formatDateTime(end))")
                    .font(.caption.bold())
                Image(systemName: "moon.zzz")
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
        let hoursAndMinutes = String(format: "%d:%02d", hours, remainingMinutes)
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
                keyboardType: .numberPad,
                capitalization: .none,
                maxLength: 9,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.first?.assignmentNumber
                    ?? duty.firstLeg.assignmentNumber
                    ?? "",
                numbersOnly: true,
                reserveText: "888888888",
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
        textFont: Font = .subheadline.weight(.semibold),
        inputFont: UIFont = .systemFont(ofSize: 15, weight: .semibold),
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
            return Color.accentColor.opacity(0.58)
        }

        if let field, fieldHasChanges(field) {
            return Color.indigo
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
            return Color.accentColor.opacity(0.58)
        }
        return routeSideHasChanges(index: index, side: side)
            ? Color.indigo
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

        return identityField("Расчётное время", field: .calculatedTime(index)) {
            Text(leg.calculatedMinutes.map(timeText) ?? "Нет данных")
        }
        .overlay(alignment: .topTrailing) {
            if isEditing, focusedField == .calculatedTime(index) {
                floatingEditor(
                    width: 188,
                    height: 132,
                    backgroundOpacity: 0.82
                ) {
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            if !isUnscheduled {
                                Button {
                                    toggleCalculatedTimeSource(index)
                                } label: {
                                    HStack(spacing: 5) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .stroke(Color.secondary, lineWidth: 1)
                                                .frame(width: 16, height: 16)

                                            if usesTable {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .fill(Color.accentColor)
                                                    .frame(width: 16, height: 16)

                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }

                                        Text("Из таблицы")
                                            .font(.caption2)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            if isUnscheduled || !usesTable {
                                compactTimeWheel(selection: calculatedTimeBinding(index))
                            } else {
                                Text(
                                    draft[index].calculatedMinutes.map(timeText)
                                    ?? "Нет данных"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 122, height: 76, alignment: .center)
                            }
                        }
                        .frame(width: 126, alignment: .topLeading)

                        VStack(spacing: 8) {
                            Button {
                                restoreOriginalCalculatedTime(index)
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .controlSize(.small)
                            .disabled(!calculatedEditorHasChanges(index))
                            .accessibilityLabel("Вернуть исходное расчётное время")

                            Button {
                                focusedField = nil
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.circle)
                            .controlSize(.small)
                            .accessibilityLabel("Готово")
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .offset(y: 42)
                .zIndex(5000)
            }
        }
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

    private func compactTimeWheel(selection: Binding<Date>) -> some View {
        DatePicker(
            "",
            selection: selection,
            displayedComponents: [.hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.wheel)
        .frame(width: 160, height: 108)
        .scaleEffect(0.78, anchor: .topLeading)
        .frame(width: 126, height: 86, alignment: .topLeading)
        .clipped()
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
                .font(.subheadline.weight(.semibold))
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
