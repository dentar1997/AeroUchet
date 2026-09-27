import SwiftUI
import UIKit

struct FullEditorTest3View: View {
    let isEditing: Bool

    @State private var assignmentNumber = "5686217"
    @State private var flightNumber = "1512"
    @State private var aircraftType = "A-320A"
    @State private var registrationDigits = "73754"
    @State private var flightKind: FullTest3FlightKind = .planned
    @State private var calculatedMinutes: Int?
    @State private var departureCode = "SVO/B"
    @State private var arrivalCode = "SGC"

    @State private var workStart = fullTest3Date(2026, 9, 7, 0, 35)
    @State private var engineStart = fullTest3Date(2026, 9, 7, 1, 35)
    @State private var takeoff = fullTest3Date(2026, 9, 7, 1, 45)
    @State private var landing = fullTest3Date(2026, 9, 7, 1, 45)
    @State private var engineStop = fullTest3Date(2026, 9, 7, 1, 45)
    @State private var workEnd = fullTest3Date(2026, 9, 7, 2, 15)

    @State private var activeControl: FullTest3ActiveControl?
    @State private var showStartCalendar = false

    private let originalAssignmentNumber = "5686217"
    private let originalFlightNumber = "1512"
    private let originalAircraftType = "A-320A"
    private let originalRegistrationDigits = "73754"
    private let originalDepartureCode = "SVO/B"
    private let originalArrivalCode = "SGC"
    private let originalWorkStart = fullTest3Date(2026, 9, 7, 0, 35)
    private let isLastLeg = true

    var body: some View {
        VStack(spacing: 10) {
            assignmentHeader
            identityRow
            routeRow
            firstTimeRow
            secondTimeRow
            summaryRow
        }
        .padding(12)
        .frame(width: 556)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.32), lineWidth: 1)
        )
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                activeControl = nil
                showStartCalendar = false
            }
        }
    }

    private var assignmentHeader: some View {
        HStack(spacing: 4) {
            Text("Задание на полёт №")
                .font(.headline.bold())

            if isEditing {
                TextField(
                    "",
                    text: filteredTextBinding(
                        value: $assignmentNumber,
                        maxLength: 9,
                        transform: { String($0.filter(\.isNumber)) }
                    )
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.headline.bold())
                .foregroundStyle(editColor(changed: assignmentNumber != originalAssignmentNumber))
                .frame(width: 92)
                .simultaneousGesture(TapGesture().onEnded { clearActiveTimeCell() })
            } else {
                Text(assignmentNumber)
                    .font(.headline.bold())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var identityRow: some View {
        HStack(spacing: 8) {
            FullTest3TextCell(
                title: "Рейс",
                text: filteredTextBinding(
                    value: $flightNumber,
                    maxLength: 7,
                    transform: fullTest3FlightNumber
                ),
                displayText: flightNumber,
                isEditing: isEditing,
                changed: flightNumber != originalFlightNumber,
                keyboardType: .numbersAndPunctuation,
                onActivate: clearActiveTimeCell
            )

            FullTest3TextCell(
                title: "Тип ВС",
                text: filteredTextBinding(
                    value: $aircraftType,
                    maxLength: 10,
                    transform: fullTest3UppercaseToken
                ),
                displayText: aircraftType,
                isEditing: isEditing,
                changed: aircraftType != originalAircraftType,
                keyboardType: .asciiCapable,
                onActivate: clearActiveTimeCell
            )

            FullTest3RegistrationCell(
                digits: filteredTextBinding(
                    value: $registrationDigits,
                    maxLength: 5,
                    transform: { String($0.filter(\.isNumber)) }
                ),
                isEditing: isEditing,
                changed: registrationDigits != originalRegistrationDigits,
                onActivate: clearActiveTimeCell
            )

            FullTest3FlightKindCell(
                kind: flightKind,
                isEditing: isEditing,
                onTap: toggleFlightKind
            )

            FullTest3CalculatedTimeCell(
                minutes: $calculatedMinutes,
                isEditing: isEditing,
                flightKind: flightKind,
                fallbackMinutes: flightMinutes,
                activePart: calculatedActivePart,
                onActivate: { part in
                    if calculatedMinutes == nil {
                        calculatedMinutes = max(flightMinutes, 0)
                    }
                    activeControl = .calculated(part)
                },
                onReset: resetCalculatedTime
            )
            .zIndex(isCalculatedActive ? 250 : 0)
        }
    }

    private var routeRow: some View {
        VStack(spacing: 2) {
            Text("Маршрут")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Москва (")
                    .font(.subheadline.bold())

                if isEditing {
                    TextField(
                        "",
                        text: filteredTextBinding(
                            value: $departureCode,
                            maxLength: 5,
                            transform: fullTest3AirportCode
                        )
                    )
                    .multilineTextAlignment(.center)
                    .font(.subheadline.bold())
                    .foregroundStyle(editColor(changed: departureCode != originalDepartureCode))
                    .frame(width: 48)
                    .simultaneousGesture(TapGesture().onEnded { clearActiveTimeCell() })
                } else {
                    Text(departureCode)
                        .font(.subheadline.bold())
                }

                Text(") → Сургут (")
                    .font(.subheadline.bold())

                if isEditing {
                    TextField(
                        "",
                        text: filteredTextBinding(
                            value: $arrivalCode,
                            maxLength: 5,
                            transform: fullTest3AirportCode
                        )
                    )
                    .multilineTextAlignment(.center)
                    .font(.subheadline.bold())
                    .foregroundStyle(editColor(changed: arrivalCode != originalArrivalCode))
                    .frame(width: 48)
                    .simultaneousGesture(TapGesture().onEnded { clearActiveTimeCell() })
                } else {
                    Text(arrivalCode)
                        .font(.subheadline.bold())
                }

                Text(")")
                    .font(.subheadline.bold())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
    }

    private var firstTimeRow: some View {
        HStack(spacing: 8) {
            eventCell(.workStart, title: "Начало работы")
            eventCell(.engineStart, title: "Включение двигателей")
            eventCell(.takeoff, title: "Взлёт")
        }
    }

    private var secondTimeRow: some View {
        HStack(spacing: 8) {
            eventCell(.workEnd, title: "Завершение работы")
            eventCell(.engineStop, title: "Выключение двигателей")
            eventCell(.landing, title: "Посадка")
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 8) {
            FullTest3SummaryCell(
                title: "Рабочее время",
                minutes: fullTest3Minutes(from: workStart, to: workEnd),
                nightMinutes: fullTest3NightMinutes(from: workStart, to: workEnd)
            )

            FullTest3SummaryCell(
                title: "Полётное время",
                minutes: fullTest3Minutes(from: engineStart, to: engineStop),
                nightMinutes: fullTest3NightMinutes(from: engineStart, to: engineStop)
            )

            FullTest3SummaryCell(
                title: "Лётное время",
                minutes: fullTest3Minutes(from: takeoff, to: landing),
                nightMinutes: fullTest3NightMinutes(from: takeoff, to: landing)
            )
        }
    }

    @ViewBuilder
    private func eventCell(_ id: FullTest3EventID, title: String) -> some View {
        let activePart = activePart(for: id)
        let isActive = activePart != nil

        FullTest3DateTimeCell(
            title: title,
            date: eventDate(id),
            isEditing: isEditing,
            isActive: isActive,
            activePart: activePart,
            dateEditable: dateIsEditable(id),
            showsCalendarButton: id == .workStart,
            showsDateWheel: id == .workStart,
            hasChanges: eventHasChanges(id),
            onActivate: { part in
                activateEvent(id, part: part)
            },
            onToggleDate: {
                toggleEventDate(id)
            },
            onSetDate: { date in
                setEventDateFromWheel(id, date: date)
            },
            onSetHour: { hour in
                setEventHour(id, hour: hour)
            },
            onSetMinute: { minute in
                setEventMinute(id, minute: minute)
            },
            onCalendar: {
                activeControl = .event(.workStart, .date)
                showStartCalendar = true
            },
            onReset: {
                resetEvent(id)
            }
        )
        .zIndex(isActive ? 200 : 0)
        .popover(
            isPresented: id == .workStart ? $showStartCalendar : .constant(false),
            arrowEdge: .top
        ) {
            if id == .workStart {
                FullTest3JumpCalendar(selection: workStartCalendarBinding)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func activateEvent(_ id: FullTest3EventID, part: FullTest3InlinePart) {
        if part == .date, id != .workStart {
            guard dateIsEditable(id) else {
                activeControl = .event(id, .hour)
                return
            }
            activeControl = .event(id, .date)
            toggleEventDate(id)
            return
        }

        activeControl = .event(id, part)
    }

    private func activePart(for id: FullTest3EventID) -> FullTest3InlinePart? {
        guard case .event(let activeID, let part) = activeControl, activeID == id else {
            return nil
        }
        return part
    }

    private var calculatedActivePart: FullTest3InlinePart? {
        guard case .calculated(let part) = activeControl else { return nil }
        return part
    }

    private var isCalculatedActive: Bool {
        calculatedActivePart != nil
    }

    private func clearActiveTimeCell() {
        activeControl = nil
        showStartCalendar = false
    }

    private func toggleFlightKind() {
        guard isEditing else { return }
        clearActiveTimeCell()

        switch flightKind {
        case .planned:
            flightKind = .nonPlanned
            calculatedMinutes = max(flightMinutes, 0)
        case .nonPlanned:
            flightKind = .planned
        }
    }

    private func resetCalculatedTime() {
        switch flightKind {
        case .planned:
            calculatedMinutes = nil
        case .nonPlanned:
            calculatedMinutes = max(flightMinutes, 0)
        }
    }

    private var flightMinutes: Int {
        fullTest3Minutes(from: engineStart, to: engineStop)
    }

    private func eventDate(_ id: FullTest3EventID) -> Date {
        switch id {
        case .workStart:
            return workStart
        case .engineStart:
            return engineStart
        case .takeoff:
            return takeoff
        case .landing:
            return landing
        case .engineStop:
            return engineStop
        case .workEnd:
            return workEnd
        }
    }

    private func setEventDate(_ id: FullTest3EventID, _ date: Date) {
        switch id {
        case .workStart:
            workStart = date
        case .engineStart:
            engineStart = date
        case .takeoff:
            takeoff = date
        case .landing:
            landing = date
        case .engineStop:
            engineStop = date
        case .workEnd:
            workEnd = date
        }
    }

    private func previousEventDate(_ id: FullTest3EventID) -> Date? {
        guard let previous = id.previous else { return nil }
        return eventDate(previous)
    }

    private func setEventHour(_ id: FullTest3EventID, hour: Int) {
        var components = fullTest3Calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: eventDate(id)
        )
        components.hour = fullTest3Wrapped(hour, count: 24)

        guard let candidate = fullTest3Calendar.date(from: components) else { return }
        applyEventCandidate(candidate, for: id)
    }

    private func setEventMinute(_ id: FullTest3EventID, minute: Int) {
        var components = fullTest3Calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: eventDate(id)
        )
        components.minute = fullTest3Wrapped(minute, count: 60)

        guard let candidate = fullTest3Calendar.date(from: components) else { return }
        applyEventCandidate(candidate, for: id)
    }

    private func setEventDateFromWheel(_ id: FullTest3EventID, date: Date) {
        guard id == .workStart else { return }
        applyWorkStart(date)
    }

    private func applyEventCandidate(_ candidate: Date, for id: FullTest3EventID) {
        if id == .workStart {
            applyWorkStart(candidate)
            return
        }

        let minimum = previousEventDate(id) ?? workStart
        let maximum = maximumAllowedEventDate
        let clamped = min(max(candidate, minimum), maximum)
        setEventDate(id, clamped)
        normalizeFollowingEvents(after: id)
    }

    private func applyWorkStart(_ candidate: Date) {
        let delta = candidate.timeIntervalSince(workStart)
        workStart = candidate
        engineStart = engineStart.addingTimeInterval(delta)
        takeoff = takeoff.addingTimeInterval(delta)
        landing = landing.addingTimeInterval(delta)
        engineStop = engineStop.addingTimeInterval(delta)
        workEnd = workEnd.addingTimeInterval(delta)
        normalizeFollowingEvents(after: .workStart)
    }

    private func normalizeFollowingEvents(after id: FullTest3EventID) {
        var previous = eventDate(id)

        for next in id.following {
            var candidate = eventDate(next)
            candidate = min(candidate, maximumAllowedEventDate)
            if candidate < previous {
                candidate = previous
            }
            setEventDate(next, candidate)
            previous = candidate
        }
    }

    private var maximumAllowedEventDate: Date {
        let startOfDay = fullTest3Calendar.startOfDay(for: workStart)
        let dayAfterNext = fullTest3Calendar.date(byAdding: .day, value: 2, to: startOfDay) ?? workStart
        return dayAfterNext.addingTimeInterval(-60)
    }

    private func dateIsEditable(_ id: FullTest3EventID) -> Bool {
        guard isEditing else { return false }
        if id == .workStart { return true }
        guard let previous = id.previous else { return true }
        return fullTest3DayOffset(eventDate(previous), from: workStart) == 0
    }

    private func toggleEventDate(_ id: FullTest3EventID) {
        guard id != .workStart, dateIsEditable(id) else { return }

        let current = eventDate(id)
        let currentOffset = fullTest3DayOffset(current, from: workStart)
        let targetOffset = currentOffset == 0 ? 1 : 0
        let targetDay = fullTest3Calendar.date(
            byAdding: .day,
            value: targetOffset,
            to: fullTest3Calendar.startOfDay(for: workStart)
        ) ?? current

        let time = fullTest3Calendar.dateComponents([.hour, .minute], from: current)
        var targetComponents = fullTest3Calendar.dateComponents([.year, .month, .day], from: targetDay)
        targetComponents.hour = time.hour
        targetComponents.minute = time.minute

        guard let candidate = fullTest3Calendar.date(from: targetComponents) else { return }

        if let previous = previousEventDate(id), candidate < previous {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        setEventDate(id, min(candidate, maximumAllowedEventDate))

        if targetOffset == 1 {
            forceFollowingEventsToNextDay(after: id)
        } else {
            normalizeFollowingEvents(after: id)
        }

        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func forceFollowingEventsToNextDay(after id: FullTest3EventID) {
        let nextDay = fullTest3Calendar.date(
            byAdding: .day,
            value: 1,
            to: fullTest3Calendar.startOfDay(for: workStart)
        ) ?? workStart
        var previous = eventDate(id)

        for next in id.following {
            let source = eventDate(next)
            let time = fullTest3Calendar.dateComponents([.hour, .minute], from: source)
            var components = fullTest3Calendar.dateComponents([.year, .month, .day], from: nextDay)
            components.hour = time.hour
            components.minute = time.minute

            var candidate = fullTest3Calendar.date(from: components) ?? previous
            candidate = min(candidate, maximumAllowedEventDate)
            if candidate < previous {
                candidate = previous
            }
            setEventDate(next, candidate)
            previous = candidate
        }
    }

    private func resetEvent(_ id: FullTest3EventID) {
        switch id {
        case .workStart:
            applyWorkStart(originalWorkStart)
        case .engineStart:
            applyEventCandidate(
                fullTest3Calendar.date(byAdding: .minute, value: 60, to: workStart) ?? workStart,
                for: .engineStart
            )
        case .takeoff:
            applyEventCandidate(
                fullTest3Calendar.date(byAdding: .minute, value: 10, to: engineStart) ?? engineStart,
                for: .takeoff
            )
        case .landing:
            applyEventCandidate(takeoff, for: .landing)
        case .engineStop:
            applyEventCandidate(landing, for: .engineStop)
        case .workEnd:
            let offset = isLastLeg ? 30 : 0
            applyEventCandidate(
                fullTest3Calendar.date(byAdding: .minute, value: offset, to: engineStop) ?? engineStop,
                for: .workEnd
            )
        }
    }

    private func eventHasChanges(_ id: FullTest3EventID) -> Bool {
        let baseline: Date

        switch id {
        case .workStart:
            baseline = originalWorkStart
        case .engineStart:
            baseline = fullTest3Calendar.date(byAdding: .minute, value: 60, to: workStart) ?? workStart
        case .takeoff:
            baseline = fullTest3Calendar.date(byAdding: .minute, value: 10, to: engineStart) ?? engineStart
        case .landing:
            baseline = takeoff
        case .engineStop:
            baseline = landing
        case .workEnd:
            let offset = isLastLeg ? 30 : 0
            baseline = fullTest3Calendar.date(byAdding: .minute, value: offset, to: engineStop) ?? engineStop
        }

        return !fullTest3SameMinute(eventDate(id), baseline)
    }

    private var workStartCalendarBinding: Binding<Date> {
        Binding(
            get: { workStart },
            set: { newValue in
                let time = fullTest3Calendar.dateComponents([.hour, .minute], from: workStart)
                var components = fullTest3Calendar.dateComponents([.year, .month, .day], from: newValue)
                components.hour = time.hour
                components.minute = time.minute

                if let candidate = fullTest3Calendar.date(from: components) {
                    applyWorkStart(candidate)
                }
                showStartCalendar = false
            }
        )
    }

    private func filteredTextBinding(
        value: Binding<String>,
        maxLength: Int,
        transform: @escaping (String) -> String
    ) -> Binding<String> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = String(transform(newValue).prefix(maxLength))
            }
        )
    }

    private func editColor(changed: Bool) -> Color {
        guard isEditing else { return .primary }
        return changed ? Color.indigo : Color.accentColor
    }
}

private enum FullTest3EventID: Int, CaseIterable, Hashable {
    case workStart
    case engineStart
    case takeoff
    case landing
    case engineStop
    case workEnd

    var previous: FullTest3EventID? {
        guard rawValue > 0 else { return nil }
        return FullTest3EventID(rawValue: rawValue - 1)
    }

    var following: [FullTest3EventID] {
        Self.allCases.filter { $0.rawValue > rawValue }
    }
}

private enum FullTest3InlinePart: Hashable {
    case date
    case hour
    case minute
}

private enum FullTest3ActiveControl: Hashable {
    case event(FullTest3EventID, FullTest3InlinePart)
    case calculated(FullTest3InlinePart)
}

private enum FullTest3FlightKind {
    case planned
    case nonPlanned

    var title: String {
        switch self {
        case .planned:
            return "Плановый"
        case .nonPlanned:
            return "Внеплановый"
        }
    }
}

private struct FullTest3TextCell: View {
    let title: String
    @Binding var text: String
    let displayText: String
    let isEditing: Bool
    let changed: Bool
    let keyboardType: UIKeyboardType
    let onActivate: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if isEditing {
                TextField("", text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.subheadline.bold())
                    .foregroundStyle(changed ? Color.indigo : Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .simultaneousGesture(TapGesture().onEnded(onActivate))
            } else {
                Text(displayText)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
    }
}

private struct FullTest3RegistrationCell: View {
    @Binding var digits: String
    let isEditing: Bool
    let changed: Bool
    let onActivate: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text("Бортовой номер")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if isEditing {
                HStack(spacing: 0) {
                    Text("RA-")
                    TextField("", text: $digits)
                        .keyboardType(.numberPad)
                        .frame(width: 42)
                }
                .font(.subheadline.bold())
                .foregroundStyle(changed ? Color.indigo : Color.accentColor)
                .frame(maxWidth: .infinity)
                .simultaneousGesture(TapGesture().onEnded(onActivate))
            } else {
                Text("RA-\(digits)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
    }
}

private struct FullTest3FlightKindCell: View {
    let kind: FullTest3FlightKind
    let isEditing: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text("Вид полёта")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(kind.title)
                .font(.subheadline.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onTap()
        }
    }
}

private struct FullTest3CalculatedTimeCell: View {
    @Binding var minutes: Int?
    let isEditing: Bool
    let flightKind: FullTest3FlightKind
    let fallbackMinutes: Int
    let activePart: FullTest3InlinePart?
    let onActivate: (FullTest3InlinePart) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text("Расчётное время")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let minutes {
                HStack(spacing: 0) {
                    FullTest3NumberWheel(
                        value: minutes / 60,
                        count: 24,
                        isEditing: isEditing,
                        isActive: activePart == .hour,
                        editableColor: .accentColor,
                        onActivate: { onActivate(.hour) },
                        onChange: { hour in
                            self.minutes = hour * 60 + minutes % 60
                        }
                    )

                    Text(":")
                        .font(.subheadline.bold())
                        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                        .frame(width: 6)

                    FullTest3NumberWheel(
                        value: minutes % 60,
                        count: 60,
                        isEditing: isEditing,
                        isActive: activePart == .minute,
                        editableColor: .accentColor,
                        onActivate: { onActivate(.minute) },
                        onChange: { minute in
                            self.minutes = minutes / 60 * 60 + minute
                        }
                    )
                }
                .frame(height: 20)
            } else {
                Text("Нет данных")
                    .font(.subheadline.bold())
                    .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isEditing else { return }
                        self.minutes = max(fallbackMinutes, 0)
                        onActivate(.hour)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
        .overlay(alignment: .bottomTrailing) {
            if isEditing, activePart != nil {
                Button(action: onReset) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8.5, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor.opacity(0.82))
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            }
        }
        .onTapGesture {
            guard isEditing else { return }
            if minutes == nil {
                minutes = max(fallbackMinutes, 0)
            }
            onActivate(.hour)
        }
    }
}

private struct FullTest3DateTimeCell: View {
    let title: String
    let date: Date
    let isEditing: Bool
    let isActive: Bool
    let activePart: FullTest3InlinePart?
    let dateEditable: Bool
    let showsCalendarButton: Bool
    let showsDateWheel: Bool
    let hasChanges: Bool
    let onActivate: (FullTest3InlinePart) -> Void
    let onToggleDate: () -> Void
    let onSetDate: (Date) -> Void
    let onSetHour: (Int) -> Void
    let onSetMinute: (Int) -> Void
    let onCalendar: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(spacing: 3) {
                if showsDateWheel {
                    FullTest3DateWheel(
                        date: date,
                        isEditing: isEditing,
                        isActive: activePart == .date,
                        editableColor: .accentColor,
                        onActivate: { onActivate(.date) },
                        onChange: onSetDate
                    )
                } else {
                    Text(fullTest3DateText(date))
                        .font(.caption.bold())
                        .foregroundStyle(
                            isEditing && dateEditable
                                ? Color.accentColor
                                : Color.primary
                        )
                        .frame(width: 70, height: 18, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEditing, dateEditable else { return }
                            onToggleDate()
                        }
                }

                FullTest3NumberWheel(
                    value: fullTest3Hour(date),
                    count: 24,
                    isEditing: isEditing,
                    isActive: activePart == .hour,
                    editableColor: .accentColor,
                    onActivate: { onActivate(.hour) },
                    onChange: onSetHour
                )

                Text(":")
                    .font(.caption.bold())
                    .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                    .frame(width: 5)

                FullTest3NumberWheel(
                    value: fullTest3Minute(date),
                    count: 60,
                    isEditing: isEditing,
                    isActive: activePart == .minute,
                    editableColor: .accentColor,
                    onActivate: { onActivate(.minute) },
                    onChange: onSetMinute
                )
            }
            .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
        .overlay(alignment: .bottomTrailing) {
            if isEditing, isActive {
                HStack(spacing: 3) {
                    if showsCalendarButton {
                        Button(action: onCalendar) {
                            Image(systemName: "calendar")
                                .font(.system(size: 8.5, weight: .semibold))
                                .frame(width: 17, height: 17)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor.opacity(0.82))
                        .opacity(0.82)
                    }

                    Button(action: onReset) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 8.5, weight: .semibold))
                            .frame(width: 17, height: 17)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor.opacity(0.82))
                    .opacity(hasChanges ? 0.82 : 0.28)
                    .disabled(!hasChanges)
                }
                .padding(.trailing, 5)
                .padding(.bottom, 5)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

private struct FullTest3NumberWheel: View {
    let value: Int
    let count: Int
    let isEditing: Bool
    let isActive: Bool
    let editableColor: Color
    let onActivate: () -> Void
    let onChange: (Int) -> Void

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack {
            Text(String(format: "%02d", value))
                .font(.caption.bold())
                .foregroundStyle(isEditing ? editableColor : Color.primary)
                .opacity(isActive ? 0 : 1)

            if isActive {
                ForEach(-1...1, id: \.self) { relative in
                    Text(String(format: "%02d", fullTest3Wrapped(value + relative, count: count)))
                        .font(.caption.bold())
                        .foregroundStyle(
                            relative == 0
                                ? editableColor
                                : Color.secondary.opacity(0.52)
                        )
                        .offset(y: CGFloat(relative) * rowHeight + residualOffset)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 17, height: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard isEditing, isActive else { return }
                    if !isDragging {
                        startValue = value
                        isDragging = true
                    }

                    dragTranslation = gesture.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    let newValue = fullTest3Wrapped(startValue + steps, count: count)

                    if newValue != value {
                        onChange(newValue)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.12)) {
                        dragTranslation = 0
                    }
                }
        )
    }

    private var residualOffset: CGFloat {
        guard isDragging else { return 0 }
        let steps = Int((-dragTranslation / rowHeight).rounded())
        return dragTranslation + CGFloat(steps) * rowHeight
    }
}

private struct FullTest3DateWheel: View {
    let date: Date
    let isEditing: Bool
    let isActive: Bool
    let editableColor: Color
    let onActivate: () -> Void
    let onChange: (Date) -> Void

    @State private var startDate = Date()
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack(alignment: .leading) {
            Text(fullTest3DateText(date))
                .font(.caption.bold())
                .foregroundStyle(isEditing ? editableColor : Color.primary)
                .opacity(isActive ? 0 : 1)

            if isActive {
                ForEach(-1...1, id: \.self) { relative in
                    let itemDate = fullTest3Calendar.date(byAdding: .day, value: relative, to: date) ?? date
                    Text(fullTest3DateText(itemDate))
                        .font(.caption.bold())
                        .foregroundStyle(
                            relative == 0
                                ? editableColor
                                : Color.secondary.opacity(0.52)
                        )
                        .offset(y: CGFloat(relative) * rowHeight + residualOffset)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 70, height: 18, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard isEditing, isActive else { return }
                    if !isDragging {
                        startDate = date
                        isDragging = true
                    }

                    dragTranslation = gesture.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    if let newDate = fullTest3Calendar.date(byAdding: .day, value: steps, to: startDate),
                       !fullTest3SameMinute(newDate, date) {
                        onChange(newDate)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.12)) {
                        dragTranslation = 0
                    }
                }
        )
    }

    private var residualOffset: CGFloat {
        guard isDragging else { return 0 }
        let steps = Int((-dragTranslation / rowHeight).rounded())
        return dragTranslation + CGFloat(steps) * rowHeight
    }
}

private struct FullTest3SummaryCell: View {
    let title: String
    let minutes: Int
    let nightMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(fullTest3DurationText(minutes)) · ночь \(fullTest3DurationText(nightMinutes))")
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(FullTest3Style.cellBackground)
    }
}

private struct FullTest3JumpCalendar: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker(
            "Дата",
            selection: $selection,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        .frame(width: 278, height: 292)
        .padding(8)
    }
}

private enum FullTest3Style {
    static var cellBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}

private var fullTest3Calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
    return calendar
}

private func fullTest3Date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int
) -> Date {
    fullTest3Calendar.date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    ) ?? Date()
}

private func fullTest3DateText(_ date: Date) -> String {
    let components = fullTest3Calendar.dateComponents([.day, .month, .year], from: date)
    return String(
        format: "%02d.%02d.%04d",
        components.day ?? 1,
        components.month ?? 1,
        components.year ?? 2026
    )
}

private func fullTest3Hour(_ date: Date) -> Int {
    fullTest3Calendar.component(.hour, from: date)
}

private func fullTest3Minute(_ date: Date) -> Int {
    fullTest3Calendar.component(.minute, from: date)
}

private func fullTest3DayOffset(_ date: Date, from start: Date) -> Int {
    fullTest3Calendar.dateComponents(
        [.day],
        from: fullTest3Calendar.startOfDay(for: start),
        to: fullTest3Calendar.startOfDay(for: date)
    ).day ?? 0
}

private func fullTest3Wrapped(_ value: Int, count: Int) -> Int {
    let result = value % count
    return result >= 0 ? result : result + count
}

private func fullTest3SameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
    abs(lhs.timeIntervalSince(rhs)) < 30
}

private func fullTest3Minutes(from start: Date, to end: Date) -> Int {
    max(0, Int(end.timeIntervalSince(start) / 60.0))
}

private func fullTest3DurationText(_ minutes: Int) -> String {
    let safe = max(0, minutes)
    return String(format: "%d:%02d", safe / 60, safe % 60)
}

private func fullTest3NightMinutes(from start: Date, to end: Date) -> Int {
    guard end > start else { return 0 }

    var total = 0.0
    var day = fullTest3Calendar.startOfDay(for: start)
    let finalDay = fullTest3Calendar.startOfDay(for: end)

    while day <= finalDay {
        let six = fullTest3Calendar.date(byAdding: .hour, value: 6, to: day) ?? day
        let twentyTwo = fullTest3Calendar.date(byAdding: .hour, value: 22, to: day) ?? day
        let nextDay = fullTest3Calendar.date(byAdding: .day, value: 1, to: day) ?? day

        total += fullTest3OverlapSeconds(start, end, day, six)
        total += fullTest3OverlapSeconds(start, end, twentyTwo, nextDay)

        guard let followingDay = fullTest3Calendar.date(byAdding: .day, value: 1, to: day) else {
            break
        }
        day = followingDay
    }

    return Int(total / 60.0)
}

private func fullTest3OverlapSeconds(
    _ intervalStart: Date,
    _ intervalEnd: Date,
    _ segmentStart: Date,
    _ segmentEnd: Date
) -> TimeInterval {
    let start = max(intervalStart, segmentStart)
    let end = min(intervalEnd, segmentEnd)
    return max(0, end.timeIntervalSince(start))
}

private func fullTest3FlightNumber(_ value: String) -> String {
    value
        .uppercased()
        .filter { $0.isLetter || $0.isNumber || $0 == "-" }
}

private func fullTest3UppercaseToken(_ value: String) -> String {
    value
        .uppercased()
        .filter { $0.isLetter || $0.isNumber || $0 == "-" }
}

private func fullTest3AirportCode(_ value: String) -> String {
    value
        .uppercased()
        .filter { $0.isLetter || $0.isNumber || $0 == "/" }
}
