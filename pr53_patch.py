from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()


def replace_between(start_marker: str, end_marker: str, replacement: str) -> None:
    global text
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f"Start marker not found: {start_marker}")
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"End marker not found: {end_marker}")
    text = text[:start] + replacement.rstrip() + "\n\n" + text[end:]


replace_between(
    "    private func dutyTitle(_ duty: FlightDuty) -> some View {",
    "    private func legCountText(_ count: Int) -> String {",
    r'''    private func dutyTitle(_ duty: FlightDuty) -> some View {
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
'''
)

replace_between(
    "    private func editableValue<Editor: View>(",
    "    private func editPopoverHeader(",
    r'''    private func editableValue<Editor: View>(
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
'''
)

replace_between(
    "    private func editPopoverHeader(",
    "    private func editPopoverWidth(for field: DutyFocusedField) -> CGFloat {",
    r'''    private func editPopoverHeader(
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
            return 46
        case .workEnd, .engineOff, .landing:
            return -226
        }
    }
'''
)

replace_between(
    "    private func editPopoverWidth(for field: DutyFocusedField) -> CGFloat {",
    "    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {",
    r'''    private func editPopoverWidth(for field: DutyFocusedField) -> CGFloat {
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
            return 190
        default:
            return 260
        }
    }
'''
)

replace_between(
    "    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {",
    "    private func toggleCalculatedTimeSource(_ index: Int) {",
    r'''    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {
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
                        floatingEditor(width: 190) {
                            VStack(alignment: .leading, spacing: 6) {
                                editPopoverHeader(
                                    "Расчётное время",
                                    extraHorizontalInset: 0
                                )

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
                                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if draft[index].calculatedMinutesOverride != nil {
                                    DatePicker(
                                        "",
                                        selection: calculatedTimeBinding(index),
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                                    .frame(width: 150, height: 108)
                                    .clipped()
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
'''
)

replace_between(
    "    private func timeCell(\n",
    "    private func legValueCard(\n        title: String,\n        value: String\n    ) -> some View {",
    r'''    private func timeCell(
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
'''
)

path.write_text(text)
