import SwiftUI
import UIKit

struct InlineWheelTestView: View {
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    TestVariantSection(
                        number: 1,
                        title: "Текущий вариант",
                        subtitle: "Небольшой overlay над ячейкой. Сохраняем без изменений."
                    ) {
                        PopupWheelAssignmentCard(isEditing: isEditing)
                    }

                    TestVariantSection(
                        number: 2,
                        title: "Раздельные часы и минуты",
                        subtitle: "Часы и минуты становятся отдельными зонами прокрутки."
                    ) {
                        SeparatedWheelAssignmentCard(isEditing: isEditing)
                    }

                    TestVariantSection(
                        number: 3,
                        title: "Без изменения геометрии",
                        subtitle: "Центральные дата и время остаются точно на месте; соседние значения только дорисовываются сверху и снизу."
                    ) {
                        FullEditorTest3View(isEditing: isEditing)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Тест")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Тестовые крутилки")
                    .font(.title2.bold())

                Text("Изолированные прототипы. Вкладка «Полёты» и реальные данные не используются.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "xmark" : "wrench.and.screwdriver")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isEditing ? "Выйти из режима редактирования" : "Редактировать")
        }
        .frame(maxWidth: 556)
    }
}

private struct TestVariantSection<Content: View>: View {
    let number: Int
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(
        number: Int,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.accentColor))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Тест \(number) · \(title)")
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .frame(maxWidth: 556, alignment: .leading)
    }
}

// MARK: - Test 1: existing popup overlay

private struct PopupWheelAssignmentCard: View {
    let isEditing: Bool

    @State private var takeoffMinutes = 1 * 60 + 50
    @State private var isWheelActive = false

    var body: some View {
        PrototypeAssignmentShell(
            assignmentNumber: "5686217",
            flightNumber: "1512",
            route: "Москва (SVO/B) → Сургут (SGC)",
            dateText: "07.09.2026"
        ) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Начало работы", value: "07.09.2026 00:35")
                PrototypeStaticTimeCell(title: "Включение двигателей", value: "07.09.2026 01:36")

                PopupTakeoffCell(
                    dateText: "07.09.2026",
                    minutesOfDay: $takeoffMinutes,
                    isEditing: isEditing,
                    isActive: $isWheelActive
                )
                .zIndex(isWheelActive ? 100 : 0)
            }

            PrototypeBottomRows(dateText: "07.09.2026")
        }
    }
}

private struct PopupTakeoffCell: View {
    let dateText: String
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    @Binding var isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Взлёт")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(dateText) \(timeText)")
                .font(.caption.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            isActive = true
        }
        .overlay {
            if isEditing, isActive {
                PopupTimeWheelEditor(
                    dateText: dateText,
                    minutesOfDay: $minutesOfDay,
                    onClose: { isActive = false }
                )
                .offset(y: -4)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: isActive)
    }

    private var timeText: String {
        formatTestTime(minutesOfDay)
    }
}

private struct PopupTimeWheelEditor: View {
    let dateText: String
    @Binding var minutesOfDay: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text("Взлёт")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(dateText)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()

                Button(action: onClose) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            ZStack {
                HStack(spacing: 2) {
                    PrototypeWheelColumn(value: hourBinding, valueCount: 24, width: 48)

                    Text(":")
                        .font(.headline.bold())
                        .foregroundStyle(Color.accentColor)

                    PrototypeWheelColumn(value: minuteBinding, valueCount: 60, width: 48)
                }

                VStack(spacing: 27) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.72))
                        .frame(height: 1)

                    Rectangle()
                        .fill(Color.accentColor.opacity(0.72))
                        .frame(height: 1)
                }
                .frame(width: 110)
                .allowsHitTesting(false)
            }
            .frame(height: 84)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 164, height: 118)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.97))
        )
        .shadow(radius: 6, y: 2)
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

// MARK: - Test 2: separated inline columns

private struct SeparatedWheelAssignmentCard: View {
    let isEditing: Bool

    @State private var takeoffMinutes = 1 * 60 + 50
    @State private var activePart: TimeWheelPart?

    var body: some View {
        PrototypeAssignmentShell(
            assignmentNumber: "5727246",
            flightNumber: "7108",
            route: "Санкт-Петербург (LED) → Москва (SVO/B)",
            dateText: "20.09.2026"
        ) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Начало работы", value: "20.09.2026 14:40")
                PrototypeStaticTimeCell(title: "Включение двигателей", value: "20.09.2026 15:03")

                SeparatedInlineTimeCell(
                    dateText: "20.09.2026",
                    minutesOfDay: $takeoffMinutes,
                    isEditing: isEditing,
                    activePart: $activePart
                )
                .zIndex(activePart == nil ? 0 : 100)
            }

            PrototypeBottomRows(dateText: "20.09.2026")
        }
    }
}

private enum TimeWheelPart {
    case hour
    case minute
}

private struct SeparatedInlineTimeCell: View {
    let dateText: String
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    @Binding var activePart: TimeWheelPart?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Взлёт")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                Text(dateText)
                    .font(.caption2.bold())
                    .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

                HStack(spacing: 1) {
                    SeparatedSegment(
                        value: hourBinding,
                        count: 24,
                        isEditing: isEditing,
                        isActive: activePart == .hour,
                        onActivate: { activePart = .hour }
                    )

                    Text(":")
                        .font(.caption.bold())
                        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

                    SeparatedSegment(
                        value: minuteBinding,
                        count: 60,
                        isEditing: isEditing,
                        isActive: activePart == .minute,
                        onActivate: { activePart = .minute }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                activePart = nil
            }
        }
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

private struct SeparatedSegment: View {
    @Binding var value: Int
    let count: Int
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void

    var body: some View {
        ZStack {
            Text(String(format: "%02d", value))
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

            if isActive {
                PrototypeWheelColumn(
                    value: $value,
                    valueCount: count,
                    width: 32,
                    rowHeight: 22,
                    centerSize: 14,
                    neighborSize: 10
                )
                .frame(height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.92))
                )
                .shadow(radius: 3, y: 1)
            }
        }
        .frame(width: 30, height: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
    }
}

// MARK: - Test 3: full editor prototype

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

// MARK: - Shared prototype shell

private struct PrototypeAssignmentShell<Content: View>: View {
    let assignmentNumber: String
    let flightNumber: String
    let route: String
    let dateText: String
    @ViewBuilder let content: Content

    init(
        assignmentNumber: String,
        flightNumber: String,
        route: String,
        dateText: String,
        @ViewBuilder content: () -> Content
    ) {
        self.assignmentNumber = assignmentNumber
        self.flightNumber = flightNumber
        self.route = route
        self.dateText = dateText
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Задание на полёт № \(assignmentNumber)")
                .font(.headline.bold())

            HStack(spacing: 8) {
                PrototypeValueCell(title: "Рейс", value: flightNumber)
                PrototypeValueCell(title: "Тип ВС", value: "A-320A")
                PrototypeValueCell(title: "Бортовой номер", value: "RA-73754")
                PrototypeValueCell(title: "Вид полёта", value: "Плановый")
                PrototypeValueCell(title: "Расчётное время", value: "Нет данных")
            }

            VStack(spacing: 2) {
                Text("Маршрут")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(route)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(PrototypeStyle.cellBackground)

            content
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
    }
}

private struct PrototypeValueCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
    }
}

private struct PrototypeStaticTimeCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
    }
}

private struct PrototypeBottomRows: View {
    let dateText: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Завершение работы", value: "\(dateText) 06:32")
                PrototypeStaticTimeCell(title: "Выключение двигателей", value: "\(dateText) 06:10")
                PrototypeStaticTimeCell(title: "Посадка", value: "\(dateText) 05:58")
            }

            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Рабочее время", value: "5:57 · ночь 0:35")
                PrototypeStaticTimeCell(title: "Полётное время", value: "4:51 · ночь 0:05")
                PrototypeStaticTimeCell(title: "Лётное время", value: "4:07 · ночь 0:00")
            }
        }
    }
}

private struct PrototypeWheelColumn: View {
    @Binding var value: Int
    let valueCount: Int
    var width: CGFloat = 48
    var rowHeight: CGFloat = 27
    var centerSize: CGFloat = 18
    var neighborSize: CGFloat = 13

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            ForEach(-2...2, id: \.self) { relative in
                let isCenter = relative == 0

                Text(String(format: "%02d", wrappedTestValue(value + relative, count: valueCount)))
                    .font(
                        .system(
                            size: isCenter ? centerSize : neighborSize,
                            weight: isCenter ? .semibold : .regular,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        isCenter
                            ? Color.accentColor
                            : Color.secondary.opacity(abs(relative) == 1 ? 0.72 : 0.34)
                    )
                    .offset(y: CGFloat(relative) * rowHeight + residualOffset)
            }
        }
        .frame(width: width, height: rowHeight * 3)
        .contentShape(Rectangle())
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gestureValue in
                    if !isDragging {
                        startValue = value
                        isDragging = true
                    }

                    dragTranslation = gestureValue.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    let newValue = wrappedTestValue(startValue + steps, count: valueCount)

                    if newValue != value {
                        value = newValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.14)) {
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

private enum PrototypeStyle {
    static var cellBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}

private func wrappedTestValue(_ value: Int, count: Int) -> Int {
    let result = value % count
    return result >= 0 ? result : result + count
}

private func formatTestTime(_ minutesOfDay: Int) -> String {
    let normalized = wrappedTestValue(minutesOfDay, count: 24 * 60)
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}

private func fixedTestDateText(offset: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current

    guard
        let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)),
        let date = calendar.date(byAdding: .day, value: offset, to: base)
    else {
        return "07.09.2026"
    }

    let components = calendar.dateComponents([.day, .month, .year], from: date)
    return String(
        format: "%02d.%02d.%04d",
        components.day ?? 7,
        components.month ?? 9,
        components.year ?? 2026
    )
}
