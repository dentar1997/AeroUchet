from pathlib import Path
import re

app_path = Path('AppViews.swift')
text = app_path.read_text()
original_text = text

# floatingEditor: allow translucent editor surfaces while preserving existing callers.
text = text.replace(
'''    private func floatingEditor<Content: View>(
        width: CGFloat,
        height: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
''',
'''    private func floatingEditor<Content: View>(
        width: CGFloat,
        height: CGFloat? = nil,
        backgroundOpacity: Double = 1,
        @ViewBuilder content: () -> Content
    ) -> some View {
''',
1,
)
text = text.replace(
'''                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
''',
'''                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        Color(uiColor: .secondarySystemGroupedBackground)
                            .opacity(backgroundOpacity)
                    )
''',
1,
)

# Switching Planned -> Unscheduled always starts from the leg's current flight time.
old_toggle = '''    private func toggleScheduleType(_ index: Int) {
        let current = draft[index].scheduleType ?? .planned
        draft[index].scheduleType = current == .planned ? .unscheduled : .planned
        focusedField = nil
    }
'''
new_toggle = '''    private func toggleScheduleType(_ index: Int) {
        let current = draft[index].scheduleType ?? .planned

        if current == .planned {
            draft[index].scheduleType = .unscheduled
            draft[index].calculatedMinutesOverride = draft[index].flightMinutes
        } else {
            draft[index].scheduleType = .planned
        }

        focusedField = nil
    }
'''
if old_toggle not in text:
    raise SystemExit('toggleScheduleType block not found')
text = text.replace(old_toggle, new_toggle, 1)

# Compact calculated-time editor with reset + confirm column on the right.
calc_pattern = re.compile(
    r'''    private func calculatedTime\(_ leg: FlightLeg, index: Int\) -> some View \{.*?\n    \}\n\n    private func toggleCalculatedTimeSource''',
    re.S,
)
match = calc_pattern.search(text)
if not match:
    raise SystemExit('calculatedTime block not found')
new_calc = '''    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {
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

    private func toggleCalculatedTimeSource'''
text = text[:match.start()] + new_calc + text[match.end():]

# Replace date/time editor with a smaller translucent layout.
time_pattern = re.compile(
    r'''    private func timeEditor\(index: Int, point: DutyEditPoint\) -> some View \{.*?\n    \}\n\n    private func restoreOriginalTime''',
    re.S,
)
match = time_pattern.search(text)
if not match:
    raise SystemExit('timeEditor block not found')
new_time_editor = '''    private func timeEditor(index: Int, point: DutyEditPoint) -> some View {
        let editorHeight: CGFloat = showsCompactCalendar ? 236 : 132
        let selectedDate = point.date(in: times(for: draft[index]))

        return floatingEditor(
            width: 230,
            height: editorHeight,
            backgroundOpacity: 0.82
        ) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatDate(selectedDate))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: 174, alignment: .leading)

                    if showsCompactCalendar {
                        compactDateCalendar(index: index, point: point)
                            .frame(width: 174, alignment: .leading)
                    } else {
                        compactTimeWheel(selection: timeBinding(index, point))
                    }
                }
                .frame(width: 174, alignment: .topLeading)

                VStack(spacing: 8) {
                    Button {
                        if !showsCompactCalendar {
                            compactCalendarMonth = compactMonthStart(selectedDate)
                        }
                        showsCompactCalendar.toggle()
                    } label: {
                        Image(systemName: showsCompactCalendar ? "clock" : "calendar")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .accessibilityLabel(
                        showsCompactCalendar ? "Показать время" : "Показать календарь"
                    )

                    Button {
                        restoreOriginalTime(index: index, point: point)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
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
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .accessibilityLabel("Готово")
                }
            }
        }
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

    private func restoreOriginalTime'''
text = text[:match.start()] + new_time_editor + text[match.end():]

# Remove helper functions no longer used by the compact editor.
text = re.sub(
    r'''\n    private func shiftTimeEditorDay\(index: Int, point: DutyEditPoint, by days: Int\) \{.*?\n    \}\n''',
    '\n',
    text,
    count=1,
    flags=re.S,
)
text = re.sub(
    r'''\n    private func timeComponentBinding\(\n        index: Int,\n        point: DutyEditPoint,\n        component: Calendar.Component\n    \) -> Binding<Int> \{.*?\n    \}\n''',
    '\n',
    text,
    count=1,
    flags=re.S,
)

# Make the custom month calendar smaller while retaining all six weeks.
calendar_pattern = re.compile(
    r'''    private func compactDateCalendar\(index: Int, point: DutyEditPoint\) -> some View \{.*?\n    \}\n\n    private func compactMonthStart''',
    re.S,
)
match = calendar_pattern.search(text)
if not match:
    raise SystemExit('compactDateCalendar block not found')
new_calendar = '''    private func compactDateCalendar(index: Int, point: DutyEditPoint) -> some View {
        let selectedDate = point.date(in: times(for: draft[index]))
        let days = compactCalendarDays(for: compactCalendarMonth)
        let columns = Array(repeating: GridItem(.fixed(22), spacing: 3), count: 7)
        let weekdays = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

        return VStack(spacing: 4) {
            HStack(spacing: 5) {
                Button {
                    shiftCompactCalendarMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(compactMonthTitle(compactCalendarMonth))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    shiftCompactCalendarMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdays, id: \\.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 14)
                }

                ForEach(Array(days.enumerated()), id: \\.offset) { _, day in
                    if let day {
                        Button {
                            setTimeEditorDate(index: index, point: point, day: day)
                            showsCompactCalendar = false
                        } label: {
                            Text("\\(moscowCalendar.component(.day, from: day))")
                                .font(.system(
                                    size: 10,
                                    weight: moscowCalendar.isDate(day, inSameDayAs: selectedDate)
                                        ? .bold
                                        : .regular
                                ))
                                .frame(width: 22, height: 20)
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
                            .frame(width: 22, height: 20)
                    }
                }
            }
        }
        .frame(width: 172)
    }

    private func compactMonthStart'''
text = text[:match.start()] + new_calendar + text[match.end():]

# New editor geometry.
text = text.replace(
'''    private func timeEditorCenterX(
        width: CGFloat,
        point: DutyEditPoint
    ) -> CGFloat {
        let halfWidth: CGFloat = 143
''',
'''    private func timeEditorCenterX(
        width: CGFloat,
        point: DutyEditPoint
    ) -> CGFloat {
        let halfWidth: CGFloat = 115
''',
1,
)
text = text.replace(
'''        let editorHeight: CGFloat = showsCompactCalendar ? 292 : 188
''',
'''        let editorHeight: CGFloat = showsCompactCalendar ? 236 : 132
''',
1,
)

if text == original_text:
    raise SystemExit('AppViews.swift was not changed')
app_path.write_text(text)

# Version bump.
Path('AppVersion.swift').write_text('''enum AppVersion {\n    static let number = 100\n    static let label = "Версия 100"\n}\n''')

package_path = Path('Package.swift')
package = package_path.read_text()
package = package.replace('displayVersion: "99"', 'displayVersion: "100"')
package = package.replace('bundleVersion: "99"', 'bundleVersion: "100"')
package_path.write_text(package)
