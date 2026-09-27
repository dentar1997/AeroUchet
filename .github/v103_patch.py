from pathlib import Path
import re

path = Path("InlineWheelTestView.swift")
text = path.read_text()

new_section = r'''// MARK: - Test 3: fixed geometry, pure overlay

private struct FixedGeometryAssignmentCard: View {
    let isEditing: Bool

    @State private var engineStartMinutes = 1 * 60 + 36
    @State private var takeoffMinutes = 1 * 60 + 50
    @State private var engineStopMinutes = 6 * 60 + 10
    @State private var engineStartDayOffset = 0
    @State private var takeoffDayOffset = 0
    @State private var engineStopDayOffset = 0
    @State private var activeCell: FixedCellID?
    @State private var activePart: FixedInlinePart?

    var body: some View {
        PrototypeAssignmentShell(
            assignmentNumber: "5686217",
            flightNumber: "1512",
            route: "Москва (SVO/B) → Сургут (SGC)",
            dateText: "07.09.2026"
        ) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Начало работы", value: "07.09.2026 00:35")

                FixedGeometryDateTimeCell(
                    id: .engineStart,
                    title: "Включение двигателей",
                    minutesOfDay: $engineStartMinutes,
                    dayOffset: $engineStartDayOffset,
                    originalMinutes: 1 * 60 + 36,
                    isEditing: isEditing,
                    isActive: activeCell == .engineStart,
                    activePart: activeCell == .engineStart ? activePart : nil,
                    onActivate: { part in
                        activeCell = .engineStart
                        activePart = part
                    }
                )
                .zIndex(activeCell == .engineStart ? 200 : 0)

                FixedGeometryDateTimeCell(
                    id: .takeoff,
                    title: "Взлёт",
                    minutesOfDay: $takeoffMinutes,
                    dayOffset: $takeoffDayOffset,
                    originalMinutes: 1 * 60 + 50,
                    isEditing: isEditing,
                    isActive: activeCell == .takeoff,
                    activePart: activeCell == .takeoff ? activePart : nil,
                    onActivate: { part in
                        activeCell = .takeoff
                        activePart = part
                    }
                )
                .zIndex(activeCell == .takeoff ? 200 : 0)
            }

            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Завершение работы", value: "07.09.2026 06:32")

                FixedGeometryDateTimeCell(
                    id: .engineStop,
                    title: "Выключение двигателей",
                    minutesOfDay: $engineStopMinutes,
                    dayOffset: $engineStopDayOffset,
                    originalMinutes: 6 * 60 + 10,
                    isEditing: isEditing,
                    isActive: activeCell == .engineStop,
                    activePart: activeCell == .engineStop ? activePart : nil,
                    onActivate: { part in
                        activeCell = .engineStop
                        activePart = part
                    }
                )
                .zIndex(activeCell == .engineStop ? 200 : 0)

                PrototypeStaticTimeCell(title: "Посадка", value: "07.09.2026 05:58")
            }

            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Рабочее время", value: "5:57 · ночь 0:35")
                PrototypeStaticTimeCell(title: "Полётное время", value: "4:51 · ночь 0:05")
                PrototypeStaticTimeCell(title: "Лётное время", value: "4:07 · ночь 0:00")
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                activeCell = nil
                activePart = nil
            }
        }
    }
}

private enum FixedCellID: Hashable {
    case engineStart
    case takeoff
    case engineStop
}

private enum FixedInlinePart {
    case date
    case hour
    case minute
}

private struct FixedGeometryDateTimeCell: View {
    let id: FixedCellID
    let title: String
    @Binding var minutesOfDay: Int
    @Binding var dayOffset: Int
    let originalMinutes: Int
    let isEditing: Bool
    let isActive: Bool
    let activePart: FixedInlinePart?
    let onActivate: (FixedInlinePart) -> Void

    @State private var showCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(spacing: 3) {
                FixedDateSegment(
                    dayOffset: $dayOffset,
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
            .frame(height: 18, alignment: .leading)
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
                    .opacity(0.82)
                    .accessibilityLabel("Открыть календарь")
                    .popover(isPresented: $showCalendar, arrowEdge: .top) {
                        CompactJumpCalendar(selection: calendarDateBinding)
                            .presentationCompactAdaptation(.popover)
                    }

                    Button {
                        minutesOfDay = originalMinutes
                        dayOffset = 0
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 8.5, weight: .semibold))
                            .frame(width: 17, height: 17)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor.opacity(0.82))
                    .opacity(hasChanges ? 0.82 : 0.28)
                    .disabled(!hasChanges)
                    .accessibilityLabel("Вернуть исходные дату и время")
                }
                .padding(.trailing, 5)
                .padding(.bottom, 5)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isActive)
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                showCalendar = false
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                showCalendar = false
            }
        }
    }

    private var hasChanges: Bool {
        dayOffset != 0 || minutesOfDay != originalMinutes
    }

    private var calendarDateBinding: Binding<Date> {
        Binding(
            get: { fixedTestDate(offset: dayOffset) },
            set: { date in
                dayOffset = fixedTestDayOffset(for: date)
                showCalendar = false
                onActivate(.date)
            }
        )
    }
}

private struct CompactJumpCalendar: View {
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
                        .foregroundStyle(
                            relative == 0
                                ? Color.accentColor
                                : Color.secondary.opacity(0.52)
                        )
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
                        .foregroundStyle(
                            relative == 0
                                ? Color.accentColor
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
                    let newValue = wrappedTestValue(startValue + steps, count: count)

                    if newValue != value {
                        value = newValue
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
text, count = re.subn(pattern, new_section, text, flags=re.S)
if count != 1:
    raise SystemExit(f"Test 3 replacement count: {count}")

path.write_text(text)

version = Path("AppVersion.swift")
version.write_text(version.read_text().replace("101", "103"))

package = Path("Package.swift")
package.write_text(package.read_text().replace('displayVersion: "102"', 'displayVersion: "103"').replace('bundleVersion: "102"', 'bundleVersion: "103"'))
