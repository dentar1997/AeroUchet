import SwiftUI
import Combine
import Foundation
import UIKit
import UniformTypeIdentifiers

// Карточка задания на полёт. Вынесена из AppViews.swift 13.10 ради скорости сборки:
// правка карточки пересобирает только этот файл. Код перенесён без изменений.


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
    let isReadOnly: Bool
    let onCreate: (([FlightLeg]) -> Void)?
    let onUpdate: (([FlightLeg]) -> Void)?
    let onDelete: (() -> Void)?

    init(
        duty: FlightDuty,
        onClose: (() -> Void)? = nil,
        scrollsAsPage: Bool = false,
        onEditorFocusChange: ((Bool) -> Void)? = nil,
        onEditModeChange: ((Bool) -> Void)? = nil,
        externalEditorDismissSignal: Int = 0,
        isCreating: Bool = false,
        isReadOnly: Bool = false,
        onCreate: (([FlightLeg]) -> Void)? = nil,
        onUpdate: (([FlightLeg]) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
        self.onEditorFocusChange = onEditorFocusChange
        self.onEditModeChange = onEditModeChange
        self.externalEditorDismissSignal = externalEditorDismissSignal
        self.isCreating = isCreating
        self.isReadOnly = isReadOnly
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
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
    @State private var externallySavedLegs: [FlightLeg]?
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
        if let externallySavedLegs, !externallySavedLegs.isEmpty {
            return FlightDuty(id: duty.id, legs: externallySavedLegs)
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
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != newValue {
                handleEditorBlur(oldValue)
            }
            onEditorFocusChange?(newValue != nil)
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
        // Открыта из «Календаря» (экраном, а не поверх списка): пока идёт
        // редактирование, «назад» и свайп назад недоступны — черновик не теряется (п. 25б).
        .navigationBarBackButtonHidden(isEditing && !scrollsAsPage)
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
                                        if let onUpdate {
                                            externallySavedLegs = updatedLegs
                                            onUpdate(updatedLegs)
                                        } else {
                                            store.updateDutyLegs(updatedLegs)
                                        }
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
                } else if !isReadOnly {
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
                } else if !isReadOnly {
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
                                    if let onDelete {
                                        onDelete()
                                    } else {
                                        store.deleteDutyLegs(ids: Set(duty.legs.map(\.id)))
                                    }
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
            set: { raw in
                let digits = String(raw.filter(\.isNumber).prefix(4))
                guard digits != editableLegNumber(draft[index], index: index) else { return }
                draft[index].legNumber = digits
                // У лега с портала общий номер задания («1110/1111») — факт, его не переписываем.
                if !isPortalFact(index) {
                    draft[index].flightNumber = digits
                }
                autofillSchedule(index: index)
            }
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
                if digits.count == 5 {
                    draft[index] = DutyAutofillV129.applyingAircraftReference(to: draft[index])
                }
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
        return suffix.count <= 5 && suffix.allSatisfy(\.isNumber)
    }

    private func handleEditorBlur(_ field: DutyFocusedField?) {
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

    /// Лег истории, пришедший с портала: времена, маршрут, тип и борт — факт.
    /// Расписание их не переписывает (D34, аудит 05.10, п. 22).
    private func isPortalFact(_ index: Int) -> Bool {
        guard !isCreating, onUpdate == nil, draft.indices.contains(index) else { return false }
        let leg = draft[index]
        if leg.portalKey != nil { return true }
        let assignment = (leg.assignmentNumber ?? "").replacingOccurrences(of: " ", with: "")
        return !(assignment.hasPrefix("Manual") || assignment.hasPrefix("ManuA"))
    }

    private func autofillSchedule(index: Int) {
        guard draft.indices.contains(index) else { return }
        let number = DutyAutofillV129.normalizedFlightNumber(
            editableLegNumber(draft[index], index: index)
        )
        guard !number.isEmpty else { return }

        // История: факт с портала не трогаем; ручное задание — только если номер реально сменили.
        if !isCreating, onUpdate == nil {
            if isPortalFact(index) { return }
            if original.indices.contains(index),
               DutyAutofillV129.normalizedFlightNumber(
                   editableLegNumber(original[index], index: index)
               ) == number {
                return
            }
        }

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
        let enteredNumber = editableLegNumber(draft[index], index: index)
        var updated = DutyAutofillV129.applyingSchedule(
            to: draft[index],
            match: match,
            index: index,
            totalCount: draft.count,
            previousEngineOff: previousEnd
        )
        updated.legNumber = enteredNumber
        updated.flightNumber = enteredNumber
        draft[index] = updated
    }

    private func cycleAircraftType(_ index: Int) {
        guard draft.indices.contains(index) else { return }
        let values = AircraftFamilyV129.allCases
        let current = AircraftFamilyV129.normalized(draft[index].aircraft) ?? .a320
        let currentIndex = values.firstIndex(of: current) ?? 0
        let next = values[(currentIndex + 1) % values.count]
        selectAircraftType(next, index: index)
    }

    private func selectAircraftType(_ type: AircraftFamilyV129, index: Int) {
        guard draft.indices.contains(index) else { return }
        let current = AircraftFamilyV129.normalized(draft[index].aircraft)
        let hasRegistration = draft[index].registration.filter(\.isNumber).count == 5
        if hasRegistration, current != type {
            draft[index].registration = "RA-"
        }
        draft[index].aircraft = type.rawValue
        focusedField = nil
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
                        && draft.count > 1
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

    private func removeManualLeg(at index: Int) {
        guard isCreating, draft.count > 1, index > 0, draft.indices.contains(index) else {
            return
        }

        focusedField = nil
        draft.remove(at: index)

        var previousEngineOff: Date?
        for currentIndex in draft.indices {
            var leg = draft[currentIndex]
            let values = times(for: leg)
            let workStart = currentIndex == 0
                ? values.engineOn.addingTimeInterval(-60 * 60)
                : (previousEngineOff ?? values.engineOn.addingTimeInterval(-60 * 60))
            let workEnd = currentIndex == draft.indices.last
                ? values.engineOff.addingTimeInterval(30 * 60)
                : values.engineOff

            leg.portalTimes = PortalFlightTimes(
                workStart: workStart,
                engineOn: values.engineOn,
                takeoff: values.takeoff,
                landing: values.landing,
                engineOff: values.engineOff,
                workEnd: workEnd
            )
            leg.date = formatDate(values.engineOn)
            leg.workStart = formatClock(workStart)
            leg.engineOn = formatClock(values.engineOn)
            leg.takeoff = formatClock(values.takeoff)
            leg.landing = formatClock(values.landing)
            leg.engineOff = formatClock(values.engineOff)
            draft[currentIndex] = leg
            previousEngineOff = values.engineOff
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

    // Итоги задания без отдельного заголовка.
    // Общее время и ночь снова находятся в одной ячейке.
    private func dutyTotals(_ duty: FlightDuty) -> some View {
        LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 6) {
            dutyTotalCell(
                title: "Полётная смена",
                total: duty.workMinutes,
                night: nil
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
        night: Int?
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

    private func accessibilityTimeText(total: Int, night: Int?) -> String {
        guard let night else { return timeText(total) }
        return "\(timeText(total)), ночь \(timeText(night))"
    }

    /// Ночь показывается только у полётного и лётного времени (D36).
    private func timeAndNight(total: Int, night: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(timeText(total))
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)

            if let night {
                Text("· ночь")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(timeText(night))
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityLabel(accessibilityTimeText(total: total, night: night))
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
                    night: nil
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
                    // Одинаковая ширина в просмотре и редактировании (U01, п. 25а).
                    .frame(width: 130)
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
            : .constant(FlightScheduleStoreV129.displayFlightNumber(editableLegNumber(leg, index: index)))
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.legNumber(index))
            : .constant(false)

        return identityField("Рейс", field: .legNumber(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                field: .legNumber(index),
                keyboardType: .numberPad,
                capitalization: .none,
                maxLength: 4,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? editableLegNumber(original[index], index: index)
                    : editableLegNumber(leg, index: index),
                clearOnFirstDelete: true,
                // Ширина ячейки не зависит от числа введённых цифр (U01, п. 25а).
                reserveText: "0000"
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
        identityField("Тип ВС", field: .aircraft(index)) {
            ZStack {
                // Ширина — под самый длинный тип, чтобы строка не прыгала.
                Text("A321N")
                    .font(.caption.bold())
                    .hidden()
                Text(AircraftFamilyV129.display(leg.aircraft))
                    .font(.caption.bold())
                    .lineLimit(1)
            }
        }
    }

    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        let formatted = formattedRegistration(leg.registration)
        let numericRegistration = isCreating || isNumericRegistration(formatted)
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
                    clearOnFirstDelete: true,
                    reserveText: "RA-00000",
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
                    reserveText: "RA-00000",
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
            } else if case .aircraft(let index) = field {
                cycleAircraftType(index)
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
        night: Int?
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

    var title: String {
        switch self {
        case .assignment: return "Назначение"
        case .legNumber: return "Рейс"
        case .route: return "Маршрут"
        case .flightKind: return "Вид полёта"
        case .aircraft: return "Тип ВС"
        case .registration: return "Бортовой номер"
        case .calculatedTime: return "Расчётное время"
        case .time(_, let point): return point.title
        }
    }
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

func formattedRegistration(_ rawValue: String) -> String {
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
