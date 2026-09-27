from pathlib import Path
import re

path = Path('InlineWheelTestView.swift')
text = path.read_text()

section = r'''// MARK: - Test 3: full editor prototype

private struct FixedGeometryAssignmentCard: View {
    let isEditing: Bool

    @State private var assignmentNumber = "5686217"
    @State private var flightNumber = "1512"
    @State private var aircraftType = "A-320A"
    @State private var registrationDigits = "73754"
    @State private var isPlanned = true
    @State private var calculatedMinutes: Int?
    @State private var departureCode = "SVO/B"
    @State private var arrivalCode = "SGC"

    @State private var baseDayOffset = 0
    @State private var startMinutes = 35
    @State private var engineStartMinutes = 95
    @State private var takeoffMinutes = 105
    @State private var landingMinutes = 105
    @State private var engineStopMinutes = 105
    @State private var workEndMinutes = 135

    @State private var engineStartDay = 0
    @State private var takeoffDay = 0
    @State private var landingDay = 0
    @State private var engineStopDay = 0
    @State private var workEndDay = 0

    @State private var activeField: Test3Field?
    @State private var activePart: FixedInlinePart?

    var body: some View {
        VStack(spacing: 10) {
            assignmentHeader
            identityRow
            routeRow
            firstTimeRow
            secondTimeRow
            totalsRow
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
                activeField = nil
                activePart = nil
            }
        }
    }

    private var assignmentHeader: some View {
        HStack(spacing: 4) {
            Text("Задание на полёт №")
                .font(.headline.bold())

            PrototypeInlineTextField(
                text: $assignmentNumber,
                maxLength: 9,
                allowed: .decimalDigits,
                isEditing: isEditing,
                alignment: .leading,
                font: .headline.bold(),
                onActivate: { activate(.assignment) }
            )
            .frame(width: 92)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var identityRow: some View {
        HStack(spacing: 8) {
            PrototypeEditableValueCell(title: "Рейс", isEditing: isEditing) {
                PrototypeInlineTextField(
                    text: $flightNumber,
                    maxLength: 7,
                    allowed: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")),
                    isEditing: isEditing,
                    alignment: .center,
                    onActivate: { activate(.flight) }
                )
            }

            PrototypeEditableValueCell(title: "Тип ВС", isEditing: isEditing) {
                PrototypeInlineTextField(
                    text: $aircraftType,
                    maxLength: 10,
                    allowed: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")),
                    isEditing: isEditing,
                    alignment: .center,
                    onActivate: { activate(.aircraft) }
                )
            }

            PrototypeEditableValueCell(title: "Бортовой номер", isEditing: isEditing) {
                HStack(spacing: 0) {
                    Text("RA-")
                    PrototypeInlineTextField(
                        text: $registrationDigits,
                        maxLength: 5,
                        allowed: .decimalDigits,
                        isEditing: isEditing,
                        alignment: .leading,
                        onActivate: { activate(.registration) }
                    )
                }
                .font(.subheadline.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
            }

            PrototypeEditableValueCell(title: "Вид полёта", isEditing: isEditing) {
                Button {
                    guard isEditing else { return }
                    isPlanned.toggle()
                    activate(.kind)
                    if !isPlanned {
                        calculatedMinutes = currentFlightMinutes
                    }
                } label: {
                    Text(isPlanned ? "Плановый" : "Внеплановый")
                        .font(.subheadline.bold())
                        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .buttonStyle(.plain)
                .disabled(!isEditing)
            }

            Test3CalculatedTimeCell(
                minutes: $calculatedMinutes,
                isEditing: isEditing,
                isActive: activeField == .calculated,
                activePart: activeField == .calculated ? activePart : nil,
                fallbackMinutes: currentFlightMinutes,
                onActivate: { part in
                    if calculatedMinutes == nil {
                        calculatedMinutes = currentFlightMinutes
                    }
                    activate(.calculated, part: part)
                },
                onReset: {
                    calculatedMinutes = isPlanned ? nil : currentFlightMinutes
                }
            )
            .zIndex(activeField == .calculated ? 200 : 0)
        }
    }

    private var routeRow: some View {
        VStack(spacing: 2) {
            Text("Маршрут")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                Text("Москва (")
                    .font(.subheadline.bold())

                PrototypeInlineTextField(
                    text: $departureCode,
                    maxLength: 5,
                    allowed: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/")),
                    isEditing: isEditing,
                    alignment: .center,
                    font: .subheadline.bold(),
                    onActivate: { activate(.routeDeparture) }
                )
                .frame(width: 48)

                Text(") → Сургут (")
                    .font(.subheadline.bold())

                PrototypeInlineTextField(
                    text: $arrivalCode,
                    maxLength: 5,
                    allowed: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/")),
                    isEditing: isEditing,
                    alignment: .center,
                    font: .subheadline.bold(),
                    onActivate: { activate(.routeArrival) }
                )
                .frame(width: 48)

                Text(")")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
    }

    private var firstTimeRow: some View {
        HStack(spacing: 8) {
            Test3StartTimeCell(
                baseDayOffset: $baseDayOffset,
                minutesOfDay: startMinutesBinding,
                isEditing: isEditing,
                isActive: activeField == .workStart,
                activePart: activeField == .workStart ? activePart : nil,
                onActivate: { part in activate(.workStart, part: part) },
                onReset: resetStart
            )
            .zIndex(activeField == .workStart ? 220 : 0)

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

    private var totalsRow: some View {
        HStack(spacing: 8) {
            PrototypeStaticTimeCell(title: "Рабочее время", value: durationText(from: startAbsolute, to: workEndAbsolute))
            PrototypeStaticTimeCell(title: "Полётное время", value: durationText(from: engineStartAbsolute, to: engineStopAbsolute))
            PrototypeStaticTimeCell(title: "Лётное время", value: durationText(from: takeoffAbsolute, to: landingAbsolute))
        }
    }

    @ViewBuilder
    private func eventCell(_ event: Test3Event, title: String) -> some View {
        Test3EventTimeCell(
            title: title,
            dayOffset: dayBinding(for: event),
            minutesOfDay: minutesBinding(for: event),
            baseDayOffset: baseDayOffset,
            isEditing: isEditing,
            isActive: activeField == event.field,
            activePart: activeField == event.field ? activePart : nil,
            dateLocked: isDateLocked(for: event),
            canUseNextDay: canToggleDate(for: event),
            onActivate: { part in activate(event.field, part: part) },
            onToggleDate: { toggleDate(for: event) },
            onReset: { reset(event) }
        )
        .zIndex(activeField == event.field ? 210 : 0)
    }

    private func activate(_ field: Test3Field, part: FixedInlinePart? = nil) {
        activeField = field
        activePart = part
    }

    private var currentFlightMinutes: Int {
        max(0, engineStopAbsolute - engineStartAbsolute)
    }

    private var startAbsolute: Int { startMinutes }
    private var engineStartAbsolute: Int { engineStartDay * 1440 + engineStartMinutes }
    private var takeoffAbsolute: Int { takeoffDay * 1440 + takeoffMinutes }
    private var landingAbsolute: Int { landingDay * 1440 + landingMinutes }
    private var engineStopAbsolute: Int { engineStopDay * 1440 + engineStopMinutes }
    private var workEndAbsolute: Int { workEndDay * 1440 + workEndMinutes }

    private var startMinutesBinding: Binding<Int> {
        Binding(
            get: { startMinutes },
            set: { newValue in
                startMinutes = wrappedTestValue(newValue, count: 1440)
                applyDefaultsFromStart()
            }
        )
    }

    private func dayBinding(for event: Test3Event) -> Binding<Int> {
        Binding(
            get: { day(for: event) },
            set: { setDay($0, for: event) }
        )
    }

    private func minutesBinding(for event: Test3Event) -> Binding<Int> {
        Binding(
            get: { minutes(for: event) },
            set: { setMinutes($0, for: event) }
        )
    }

    private func day(for event: Test3Event) -> Int {
        switch event {
        case .engineStart: engineStartDay
        case .takeoff: takeoffDay
        case .landing: landingDay
        case .engineStop: engineStopDay
        case .workEnd: workEndDay
        }
    }

    private func minutes(for event: Test3Event) -> Int {
        switch event {
        case .engineStart: engineStartMinutes
        case .takeoff: takeoffMinutes
        case .landing: landingMinutes
        case .engineStop: engineStopMinutes
        case .workEnd: workEndMinutes
        }
    }

    private func absolute(for event: Test3Event) -> Int {
        day(for: event) * 1440 + minutes(for: event)
    }

    private func previousAbsolute(for event: Test3Event) -> Int {
        switch event {
        case .engineStart: startAbsolute
        case .takeoff: engineStartAbsolute
        case .landing: takeoffAbsolute
        case .engineStop: landingAbsolute
        case .workEnd: engineStopAbsolute
        }
    }

    private func setDay(_ value: Int, for event: Test3Event) {
        let clamped = min(max(value, 0), 1)
        switch event {
        case .engineStart: engineStartDay = clamped
        case .takeoff: takeoffDay = clamped
        case .landing: landingDay = clamped
        case .engineStop: engineStopDay = clamped
        case .workEnd: workEndDay = clamped
        }
        normalize(from: event)
    }

    private func setMinutes(_ rawValue: Int, for event: Test3Event) {
        let minute = wrappedTestValue(rawValue, count: 1440)
        let dayValue = day(for: event)
        let minimum = previousAbsolute(for: event)
        let candidate = dayValue * 1440 + minute
        let accepted = max(candidate, minimum)
        let normalizedDay = min(accepted / 1440, 1)
        let normalizedMinute = accepted % 1440

        switch event {
        case .engineStart:
            engineStartDay = normalizedDay
            engineStartMinutes = normalizedMinute
            takeoffDay = normalizedDay
            takeoffMinutes = normalizedMinute
            advance(.takeoff, by: 10)
            landingDay = takeoffDay
            landingMinutes = takeoffMinutes
            clampFollowing(from: .landing)
        case .takeoff:
            takeoffDay = normalizedDay
            takeoffMinutes = normalizedMinute
            landingDay = takeoffDay
            landingMinutes = takeoffMinutes
            clampFollowing(from: .landing)
        case .landing:
            landingDay = normalizedDay
            landingMinutes = normalizedMinute
            clampFollowing(from: .landing)
        case .engineStop:
            engineStopDay = normalizedDay
            engineStopMinutes = normalizedMinute
            setWorkEndDefault()
        case .workEnd:
            workEndDay = normalizedDay
            workEndMinutes = normalizedMinute
        }
        normalize(from: event)
        refreshCalculatedIfNeeded()
    }

    private func toggleDate(for event: Test3Event) {
        guard !isDateLocked(for: event) else { return }
        let next = day(for: event) == 0 ? 1 : 0
        if next == 0 {
            let candidate = minutes(for: event)
            guard candidate >= previousAbsolute(for: event) else { return }
        }
        setDay(next, for: event)
        if next == 1 {
            forceFollowingToNextDay(after: event)
        }
    }

    private func isDateLocked(for event: Test3Event) -> Bool {
        Test3Event.allCases
            .filter { $0.rawValue < event.rawValue }
            .contains { day(for: $0) == 1 }
    }

    private func canToggleDate(for event: Test3Event) -> Bool {
        !isDateLocked(for: event)
    }

    private func forceFollowingToNextDay(after event: Test3Event) {
        for next in Test3Event.allCases where next.rawValue > event.rawValue {
            setDayDirect(1, for: next)
        }
        clampFollowing(from: event)
    }

    private func setDayDirect(_ value: Int, for event: Test3Event) {
        switch event {
        case .engineStart: engineStartDay = value
        case .takeoff: takeoffDay = value
        case .landing: landingDay = value
        case .engineStop: engineStopDay = value
        case .workEnd: workEndDay = value
        }
    }

    private func setAbsolute(_ value: Int, for event: Test3Event) {
        let clamped = min(max(value, 0), 2879)
        setDayDirect(clamped / 1440, for: event)
        let minute = clamped % 1440
        switch event {
        case .engineStart: engineStartMinutes = minute
        case .takeoff: takeoffMinutes = minute
        case .landing: landingMinutes = minute
        case .engineStop: engineStopMinutes = minute
        case .workEnd: workEndMinutes = minute
        }
    }

    private func normalize(from event: Test3Event) {
        var previous = previousAbsolute(for: event)
        for current in Test3Event.allCases where current.rawValue >= event.rawValue {
            let currentAbsolute = absolute(for: current)
            if currentAbsolute < previous {
                setAbsolute(previous, for: current)
            }
            previous = absolute(for: current)
        }
        if let firstNextDay = Test3Event.allCases.first(where: { day(for: $0) == 1 }) {
            for current in Test3Event.allCases where current.rawValue > firstNextDay.rawValue {
                setDayDirect(1, for: current)
                if absolute(for: current) < previousAbsolute(for: current) {
                    setAbsolute(previousAbsolute(for: current), for: current)
                }
            }
        }
    }

    private func clampFollowing(from event: Test3Event) {
        normalize(from: event)
    }

    private func advance(_ event: Test3Event, by minutes: Int) {
        let value = min(previousAbsolute(for: event) + minutes, 2879)
        setAbsolute(value, for: event)
    }

    private func setWorkEndDefault() {
        setAbsolute(min(engineStopAbsolute + 30, 2879), for: .workEnd)
    }

    private func applyDefaultsFromStart() {
        setAbsolute(min(startAbsolute + 60, 2879), for: .engineStart)
        setAbsolute(min(engineStartAbsolute + 10, 2879), for: .takeoff)
        setAbsolute(takeoffAbsolute, for: .landing)
        setAbsolute(landingAbsolute, for: .engineStop)
        setAbsolute(min(engineStopAbsolute + 30, 2879), for: .workEnd)
        refreshCalculatedIfNeeded()
    }

    private func refreshCalculatedIfNeeded() {
        if !isPlanned {
            calculatedMinutes = currentFlightMinutes
        }
    }

    private func resetStart() {
        baseDayOffset = 0
        startMinutes = 35
        applyDefaultsFromStart()
    }

    private func reset(_ event: Test3Event) {
        switch event {
        case .engineStart:
            setAbsolute(min(startAbsolute + 60, 2879), for: .engineStart)
            setAbsolute(min(engineStartAbsolute + 10, 2879), for: .takeoff)
            setAbsolute(takeoffAbsolute, for: .landing)
            setAbsolute(landingAbsolute, for: .engineStop)
            setWorkEndDefault()
        case .takeoff:
            setAbsolute(min(engineStartAbsolute + 10, 2879), for: .takeoff)
            setAbsolute(takeoffAbsolute, for: .landing)
            clampFollowing(from: .landing)
        case .landing:
            setAbsolute(takeoffAbsolute, for: .landing)
            clampFollowing(from: .landing)
        case .engineStop:
            setAbsolute(landingAbsolute, for: .engineStop)
            setWorkEndDefault()
        case .workEnd:
            setWorkEndDefault()
        }
        normalize(from: event)
        refreshCalculatedIfNeeded()
    }

    private func durationText(from start: Int, to end: Int) -> String {
        let duration = max(0, end - start)
        return String(format: "%d:%02d", duration / 60, duration % 60)
    }
}

private enum Test3Field: Hashable {
    case assignment
    case flight
    case aircraft
    case registration
    case kind
    case calculated
    case routeDeparture
    case routeArrival
    case workStart
    case engineStart
    case takeoff
    case landing
    case engineStop
    case workEnd
}

private enum Test3Event: Int, CaseIterable {
    case engineStart
    case takeoff
    case landing
    case engineStop
    case workEnd

    var field: Test3Field {
        switch self {
        case .engineStart: .engineStart
        case .takeoff: .takeoff
        case .landing: .landing
        case .engineStop: .engineStop
        case .workEnd: .workEnd
        }
    }
}

private enum FixedInlinePart {
    case date
    case hour
    case minute
}

private struct PrototypeEditableValueCell<Content: View>: View {
    let title: String
    let isEditing: Bool
    @ViewBuilder let content: Content

    init(title: String, isEditing: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isEditing = isEditing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            content
                .frame(minHeight: 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 3)
        .background(PrototypeStyle.cellBackground)
    }
}

private struct PrototypeInlineTextField: View {
    @Binding var text: String
    let maxLength: Int
    let allowed: CharacterSet
    let isEditing: Bool
    var alignment: TextAlignment = .center
    var font: Font = .subheadline.bold()
    let onActivate: () -> Void

    var body: some View {
        TextField("", text: filteredBinding)
            .font(font)
            .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
            .multilineTextAlignment(alignment)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .disabled(!isEditing)
            .onTapGesture { onActivate() }
    }

    private var filteredBinding: Binding<String> {
        Binding(
            get: { text },
            set: { raw in
                let filtered = raw.uppercased().unicodeScalars.filter { allowed.contains($0) }
                text = String(String.UnicodeScalarView(filtered)).prefix(maxLength).description
            }
        )
    }
}

private struct Test3CalculatedTimeCell: View {
    @Binding var minutes: Int?
    let isEditing: Bool
    let isActive: Bool
    let activePart: FixedInlinePart?
    let fallbackMinutes: Int
    let onActivate: (FixedInlinePart) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text("Расчётное время")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let minutes {
                HStack(spacing: 0) {
                    FixedNumberSegment(
                        value: hourBinding(minutes),
                        count: 24,
                        isEditing: isEditing,
                        isActive: isActive && activePart == .hour,
                        onActivate: { onActivate(.hour) }
                    )
                    Text(":")
                        .font(.subheadline.bold())
                        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                        .frame(width: 5)
                    FixedNumberSegment(
                        value: minuteBinding(minutes),
                        count: 60,
                        isEditing: isEditing,
                        isActive: isActive && activePart == .minute,
                        onActivate: { onActivate(.minute) }
                    )
                }
                .frame(height: 18)
            } else {
                Text("Нет данных")
                    .font(.subheadline.bold())
                    .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isEditing else { return }
                        self.minutes = fallbackMinutes
                        onActivate(.minute)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 3)
        .background(PrototypeStyle.cellBackground)
        .overlay(alignment: .bottomTrailing) {
            if isEditing, isActive {
                Button(action: onReset) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8.5, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor.opacity(0.82))
                .padding(4)
            }
        }
    }

    private func hourBinding(_ current: Int) -> Binding<Int> {
        Binding(
            get: { current / 60 },
            set: { hour in
                let minute = (self.minutes ?? current) % 60
                self.minutes = wrappedTestValue(hour, count: 24) * 60 + minute
            }
        )
    }

    private func minuteBinding(_ current: Int) -> Binding<Int> {
        Binding(
            get: { current % 60 },
            set: { minute in
                let hour = (self.minutes ?? current) / 60
                self.minutes = hour * 60 + wrappedTestValue(minute, count: 60)
            }
        )
    }
}

private struct Test3StartTimeCell: View {
    @Binding var baseDayOffset: Int
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    let isActive: Bool
    let activePart: FixedInlinePart?
    let onActivate: (FixedInlinePart) -> Void
    let onReset: () -> Void

    @State private var showCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Начало работы")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                FixedDateSegment(
                    dayOffset: $baseDayOffset,
                    isEditing: isEditing,
                    isActive: isActive && activePart == .date,
                    onActivate: { onActivate(.date) }
                )
                FixedTimeReadout(
                    minutesOfDay: $minutesOfDay,
                    isEditing: isEditing,
                    activePart: isActive ? activePart : nil,
                    onActivate: onActivate
                )
            }
            .frame(height: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
        .overlay(alignment: .bottomTrailing) {
            if isEditing, isActive {
                HStack(spacing: 3) {
                    Button {
                        onActivate(.date)
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 8.5, weight: .semibold))
                            .frame(width: 17, height: 17)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor.opacity(0.82))
                    .popover(isPresented: $showCalendar, arrowEdge: .top) {
                        CompactJumpCalendar(selection: calendarBinding)
                            .presentationCompactAdaptation(.popover)
                    }

                    Button(action: onReset) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 8.5, weight: .semibold))
                            .frame(width: 17, height: 17)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor.opacity(0.82))
                }
                .padding(5)
            }
        }
        .onChange(of: isActive) { _, active in
            if !active { showCalendar = false }
        }
    }

    private var calendarBinding: Binding<Date> {
        Binding(
            get: { fixedTestDate(offset: baseDayOffset) },
            set: { date in
                baseDayOffset = fixedTestDayOffset(for: date)
                showCalendar = false
                onActivate(.date)
            }
        )
    }
}

private struct Test3EventTimeCell: View {
    let title: String
    @Binding var dayOffset: Int
    @Binding var minutesOfDay: Int
    let baseDayOffset: Int
    let isEditing: Bool
    let isActive: Bool
    let activePart: FixedInlinePart?
    let dateLocked: Bool
    let canUseNextDay: Bool
    let onActivate: (FixedInlinePart) -> Void
    let onToggleDate: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(spacing: 3) {
                Text(fixedTestDateText(offset: baseDayOffset + dayOffset))
                    .font(.caption.bold())
                    .foregroundStyle(dateColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isEditing, !dateLocked, canUseNextDay else { return }
                        onToggleDate()
                        onActivate(.date)
                    }
                    .frame(width: 67, alignment: .leading)

                FixedTimeReadout(
                    minutesOfDay: $minutesOfDay,
                    isEditing: isEditing,
                    activePart: isActive ? activePart : nil,
                    onActivate: onActivate
                )
            }
            .frame(height: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
        .overlay(alignment: .bottomTrailing) {
            if isEditing, isActive {
                Button(action: onReset) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8.5, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor.opacity(0.82))
                .padding(5)
            }
        }
    }

    private var dateColor: Color {
        guard isEditing else { return Color.primary }
        return dateLocked ? Color.primary : Color.accentColor
    }
}

private struct CompactJumpCalendar: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker("Дата", selection: $selection, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 278, height: 292)
            .padding(8)
    }
}

private struct FixedDateSegment: View {
    @Binding var dayOffset: Int
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack(alignment: .leading) {
            Text(fixedTestDateText(offset: dayOffset))
                .font(.caption.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .opacity(isActive ? 0 : 1)

            if isActive {
                ForEach(-1...1, id: \.self) { relative in
                    Text(fixedTestDateText(offset: dayOffset + relative))
                        .font(.caption.bold())
                        .foregroundStyle(relative == 0 ? Color.accentColor : Color.secondary.opacity(0.52))
                        .offset(y: CGFloat(relative) * rowHeight + residualOffset)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 67, height: 18, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard isEditing, isActive else { return }
                    if !isDragging {
                        startValue = dayOffset
                        isDragging = true
                    }
                    dragTranslation = value.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    let newValue = startValue + steps
                    if newValue != dayOffset {
                        dayOffset = newValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.12)) { dragTranslation = 0 }
                }
        )
    }

    private var residualOffset: CGFloat {
        guard isDragging else { return 0 }
        let steps = Int((-dragTranslation / rowHeight).rounded())
        return dragTranslation + CGFloat(steps) * rowHeight
    }
}

private struct FixedTimeReadout: View {
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    let activePart: FixedInlinePart?
    let onActivate: (FixedInlinePart) -> Void

    var body: some View {
        HStack(spacing: 0) {
            FixedNumberSegment(
                value: hourBinding,
                count: 24,
                isEditing: isEditing,
                isActive: activePart == .hour,
                onActivate: { onActivate(.hour) }
            )
            Text(":")
                .font(.caption.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .frame(width: 5)
            FixedNumberSegment(
                value: minuteBinding,
                count: 60,
                isEditing: isEditing,
                isActive: activePart == .minute,
                onActivate: { onActivate(.minute) }
            )
        }
        .frame(width: 39, height: 18, alignment: .leading)
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay / 60 },
            set: { hour in
                minutesOfDay = wrappedTestValue(hour, count: 24) * 60 + minutesOfDay % 60
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay % 60 },
            set: { minute in
                minutesOfDay = minutesOfDay / 60 * 60 + wrappedTestValue(minute, count: 60)
            }
        )
    }
}

private struct FixedNumberSegment: View {
    @Binding var value: Int
    let count: Int
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack {
            Text(String(format: "%02d", value))
                .font(.caption.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .opacity(isActive ? 0 : 1)

            if isActive {
                ForEach(-1...1, id: \.self) { relative in
                    Text(String(format: "%02d", wrappedTestValue(value + relative, count: count)))
                        .font(.caption.bold())
                        .foregroundStyle(relative == 0 ? Color.accentColor : Color.secondary.opacity(0.52))
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
                    let newValue = wrappedTestValue(startValue + steps, count: count)
                    if newValue != value {
                        value = newValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.12)) { dragTranslation = 0 }
                }
        )
    }

    private var residualOffset: CGFloat {
        guard isDragging else { return 0 }
        let steps = Int((-dragTranslation / rowHeight).rounded())
        return dragTranslation + CGFloat(steps) * rowHeight
    }
}

private func fixedTestDate(offset: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
    let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)) ?? Date()
    return calendar.date(byAdding: .day, value: offset, to: base) ?? base
}

private func fixedTestDayOffset(for date: Date) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
    let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)) ?? Date()
    return calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: base),
        to: calendar.startOfDay(for: date)
    ).day ?? 0
}

// MARK: - Shared prototype shell'''

pattern = r'// MARK: - Test 3: fixed geometry, pure overlay\n.*?\n// MARK: - Shared prototype shell'
text, count = re.subn(pattern, section, text, flags=re.S)
if count != 1:
    raise SystemExit(f'replacement count={count}')
path.write_text(text)
