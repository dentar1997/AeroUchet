from pathlib import Path
import re

path = Path('AppViews.swift')
text = path.read_text()
original_text = text


def replace_once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    text = text.replace(old, new, 1)

replace_once(
'''    @State private var routeEditSide: RouteEditSide = .departure
    @Environment(\\.horizontalSizeClass) private var sizeClass
''',
'''    @State private var routeEditSide: RouteEditSide = .departure
    @State private var showsCompactCalendar = false
    @State private var compactCalendarMonth = Date()
    @Environment(\\.horizontalSizeClass) private var sizeClass
''',
'compact calendar state'
)

replace_once(
'''        .onChange(of: focusedField) { value in
            onEditorFocusChange?(value != nil)
        }
''',
'''        .onChange(of: focusedField) { value in
            showsCompactCalendar = false
            onEditorFocusChange?(value != nil)
        }
''',
'focus change reset'
)

replace_once(
'''        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
''',
'''        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
''',
'outer border'
)

replace_once(
'''            HStack(alignment: .top, spacing: 8) {
                flightNumber(leg, index: index)
                aircraftField(leg, index: index)
                registrationField(leg, index: index)
                flightKindField(leg, index: index)
                calculatedTime(leg, index: index)
            }
            .frame(width: 496, alignment: .center)

            routeField(leg, index: index)
                .frame(width: 496)
''',
'''            HStack(alignment: .top, spacing: 8) {
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
''',
'calculated editor z order'
)

calc_pattern = re.compile(r'''    private func calculatedTime\(_ leg: FlightLeg, index: Int\) -> some View \{.*?\n    \}\n\n    private func toggleCalculatedTimeSource''', re.S)
match = calc_pattern.search(text)
if not match:
    raise SystemExit('calculatedTime block not found')
new_calc = '''    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {
        let editableLeg = isEditing && draft.indices.contains(index) ? draft[index] : leg
        let isUnscheduled = (editableLeg.scheduleType ?? .planned) == .unscheduled

        return identityField("Расчётное время", field: .calculatedTime(index)) {
            Text(leg.calculatedMinutes.map(timeText) ?? "Нет данных")
        }
        .overlay(alignment: .topTrailing) {
            if isEditing, focusedField == .calculatedTime(index) {
                floatingEditor(width: 204) {
                    VStack(alignment: .leading, spacing: 6) {
                        editPopoverHeader(
                            "Расчётное время",
                            extraHorizontalInset: 0
                        )
                        .zIndex(200)

                        if isUnscheduled {
                            DatePicker(
                                "",
                                selection: calculatedTimeBinding(index),
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(width: 166, height: 116)
                            .clipped()
                        } else {
                            ZStack(alignment: .topLeading) {
                                Group {
                                    if draft[index].calculatedMinutesOverride != nil {
                                        DatePicker(
                                            "",
                                            selection: calculatedTimeBinding(index),
                                            displayedComponents: [.hourAndMinute]
                                        )
                                        .labelsHidden()
                                        .datePickerStyle(.wheel)
                                        .frame(width: 166, height: 116)
                                        .clipped()
                                    } else {
                                        Text(
                                            draft[index].calculatedMinutes.map(timeText)
                                            ?? "Нет данных"
                                        )
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 166, height: 40, alignment: .leading)
                                    }
                                }
                                .padding(.top, 42)
                                .zIndex(0)

                                Button {
                                    toggleCalculatedTimeSource(index)
                                } label: {
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
                                    .frame(width: 166, height: 38, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .zIndex(100)
                            }
                        }
                    }
                }
                .offset(y: 42)
                .zIndex(5000)
            }
        }
        .zIndex(focusedField == .calculatedTime(index) ? 5000 : 0)
    }

    private func toggleCalculatedTimeSource'''
text = text[:match.start()] + new_calc + text[match.end():]

time_pattern = re.compile(r'''    private func timeEditor\(index: Int, point: DutyEditPoint\) -> some View \{.*?\n    \}\n\n    private func timeEditorCenterX''', re.S)
match = time_pattern.search(text)
if not match:
    raise SystemExit('timeEditor block not found')
new_time = '''    private func timeEditor(index: Int, point: DutyEditPoint) -> some View {
        let editorHeight: CGFloat = showsCompactCalendar ? 292 : 188
        let selectedDate = point.date(in: times(for: draft[index]))

        return floatingEditor(width: 286, height: editorHeight) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(point.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    Button {
                        restoreOriginalTime(index: index, point: point)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .disabled(!fieldHasChanges(.time(index, point)))
                    .accessibilityLabel("Вернуть исходные дату и время")

                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .accessibilityLabel("Готово")
                }

                HStack(spacing: 6) {
                    Button {
                        shiftTimeEditorDay(index: index, point: point, by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Text(formatDate(selectedDate))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 96)

                    Button {
                        shiftTimeEditorDay(index: index, point: point, by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer(minLength: 2)

                    Button {
                        if !showsCompactCalendar {
                            compactCalendarMonth = compactMonthStart(selectedDate)
                        }
                        showsCompactCalendar.toggle()
                    } label: {
                        Image(systemName: showsCompactCalendar ? "clock" : "calendar")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(
                        showsCompactCalendar ? "Показать время" : "Показать календарь"
                    )
                }

                if showsCompactCalendar {
                    compactDateCalendar(index: index, point: point)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(spacing: 2) {
                        Picker(
                            "Часы",
                            selection: timeComponentBinding(
                                index: index,
                                point: point,
                                component: .hour
                            )
                        ) {
                            ForEach(0..<24, id: \\.self) { hour in
                                Text(String(format: "%02d", hour))
                                    .tag(hour)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 72, height: 94)
                        .clipped()

                        Text(":")
                            .font(.title3.weight(.semibold))

                        Picker(
                            "Минуты",
                            selection: timeComponentBinding(
                                index: index,
                                point: point,
                                component: .minute
                            )
                        ) {
                            ForEach(0..<60, id: \\.self) { minute in
                                Text(String(format: "%02d", minute))
                                    .tag(minute)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 72, height: 94)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func restoreOriginalTime(index: Int, point: DutyEditPoint) {
        guard original.indices.contains(index) else { return }
        let originalDate = point.date(in: times(for: original[index]))
        timeBinding(index, point).wrappedValue = originalDate
        compactCalendarMonth = compactMonthStart(originalDate)
    }

    private func shiftTimeEditorDay(index: Int, point: DutyEditPoint, by days: Int) {
        let current = point.date(in: times(for: draft[index]))
        guard let updated = moscowCalendar.date(byAdding: .day, value: days, to: current) else {
            return
        }
        timeBinding(index, point).wrappedValue = updated
        compactCalendarMonth = compactMonthStart(updated)
    }

    private func timeComponentBinding(
        index: Int,
        point: DutyEditPoint,
        component: Calendar.Component
    ) -> Binding<Int> {
        Binding(
            get: {
                let current = point.date(in: times(for: draft[index]))
                return moscowCalendar.component(component, from: current)
            },
            set: { value in
                let current = point.date(in: times(for: draft[index]))
                guard let updated = moscowCalendar.date(
                    bySetting: component,
                    value: value,
                    of: current
                ) else { return }
                timeBinding(index, point).wrappedValue = updated
            }
        )
    }

    private func compactDateCalendar(index: Int, point: DutyEditPoint) -> some View {
        let selectedDate = point.date(in: times(for: draft[index]))
        let days = compactCalendarDays(for: compactCalendarMonth)
        let columns = Array(repeating: GridItem(.fixed(28), spacing: 4), count: 7)
        let weekdays = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                Button {
                    shiftCompactCalendarMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(compactMonthTitle(compactCalendarMonth))
                    .font(.caption.weight(.semibold))

                Spacer()

                Button {
                    shiftCompactCalendarMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(weekdays, id: \\.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 18)
                }

                ForEach(Array(days.enumerated()), id: \\.offset) { _, day in
                    if let day {
                        Button {
                            setTimeEditorDate(index: index, point: point, day: day)
                            showsCompactCalendar = false
                        } label: {
                            Text("\\(moscowCalendar.component(.day, from: day))")
                                .font(.caption.weight(
                                    moscowCalendar.isDate(day, inSameDayAs: selectedDate)
                                        ? .bold
                                        : .regular
                                ))
                                .frame(width: 28, height: 24)
                                .background {
                                    if moscowCalendar.isDate(day, inSameDayAs: selectedDate) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.22))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 28, height: 24)
                    }
                }
            }
        }
        .frame(width: 220)
    }

    private func compactMonthStart(_ date: Date) -> Date {
        let components = moscowCalendar.dateComponents([.year, .month], from: date)
        return moscowCalendar.date(from: components) ?? date
    }

    private func compactCalendarDays(for month: Date) -> [Date?] {
        let start = compactMonthStart(month)
        guard let range = moscowCalendar.range(of: .day, in: .month, for: start) else {
            return Array(repeating: nil, count: 42)
        }

        let weekday = moscowCalendar.component(.weekday, from: start)
        let leading = (weekday + 5) % 7
        var result = Array<Date?>(repeating: nil, count: leading)

        for day in range {
            if let date = moscowCalendar.date(byAdding: .day, value: day - 1, to: start) {
                result.append(date)
            }
        }

        while result.count < 42 {
            result.append(nil)
        }
        return result
    }

    private func shiftCompactCalendarMonth(by months: Int) {
        if let updated = moscowCalendar.date(
            byAdding: .month,
            value: months,
            to: compactCalendarMonth
        ) {
            compactCalendarMonth = compactMonthStart(updated)
        }
    }

    private func compactMonthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }

    private func setTimeEditorDate(index: Int, point: DutyEditPoint, day: Date) {
        let current = point.date(in: times(for: draft[index]))
        var dateComponents = moscowCalendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = moscowCalendar.dateComponents([.hour, .minute], from: current)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        guard let updated = moscowCalendar.date(from: dateComponents) else { return }
        timeBinding(index, point).wrappedValue = updated
        compactCalendarMonth = compactMonthStart(updated)
    }

    private func timeEditorCenterX'''
text = text[:match.start()] + new_time + text[match.end():]

replace_once(
'''        let halfWidth: CGFloat = 190
        let edgeInset: CGFloat = 18
''',
'''        let halfWidth: CGFloat = 143
        let edgeInset: CGFloat = 18
''',
'time editor x geometry'
)

replace_once(
'''    private func timeEditorCenterY(
        legFrame: CGRect,
        legIndex: Int
    ) -> CGFloat {
        let editorHalfHeight: CGFloat = 141
        let gap: CGFloat = 12

        if legIndex == 0 {
            let headerHeight: CGFloat = 72
            return legFrame.minY + headerHeight + gap + editorHalfHeight
        }

        return legFrame.minY - gap - editorHalfHeight
    }
''',
'''    private func timeEditorCenterY(
        legFrame: CGRect,
        legIndex: Int
    ) -> CGFloat {
        let editorHeight: CGFloat = showsCompactCalendar ? 292 : 188
        let editorHalfHeight = editorHeight / 2
        let gap: CGFloat = 12

        if legIndex == 0 {
            let headerHeight: CGFloat = 72
            return legFrame.minY + headerHeight + gap + editorHalfHeight
        }

        return legFrame.minY - gap - editorHalfHeight
    }
''',
'time editor y geometry'
)

if text == original_text:
    raise SystemExit('no changes')
path.write_text(text)
