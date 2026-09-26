from pathlib import Path

path = Path('AppViews.swift')
s = path.read_text()


def rep(old: str, new: str, label: str) -> None:
    global s
    if old not in s:
        raise SystemExit(f'missing target: {label}')
    s = s.replace(old, new, 1)


# Editors that overlap the header must render above the assignment title and its controls.
rep(
'''            assignmentHeader(current)
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
            }''',
'''            assignmentHeader(current)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(editorCoversHeader ? 0 : 1)
                .allowsHitTesting(!editorCoversHeader)

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
            }''',
'header/content z-index'
)

marker = '''    private var current: FlightDuty {
        store.duties.first { candidate in
            candidate.legs.contains { $0.id == duty.firstLeg.id }
        } ?? duty
    }
'''
if marker not in s:
    raise SystemExit('missing target: current duty marker')
s = s.replace(marker, marker + '''
    private var editorCoversHeader: Bool {
        switch focusedField {
        case .time, .calculatedTime, .route:
            return true
        default:
            return false
        }
    }
''', 1)

# Assignment number edits inline: only the number itself becomes selected.
start = s.index('    private func dutyTitle(_ duty: FlightDuty) -> some View {')
end = s.index('    private func legCountText(_ count: Int) -> String {', start)
s = s[:start] + '''    private func dutyTitle(_ duty: FlightDuty) -> some View {
        let title = duty.firstLeg.assignmentNumber.map {
            "Задание на полёт № \\($0)"
        } ?? "Задание на полёт"

        return Group {
            if isEditing {
                HStack(spacing: 4) {
                    Text("Задание на полёт №")

                    if focusedField == .assignment {
                        InlineSelectAllTextField(
                            text: $assignmentNumber,
                            isActive: focusBinding(.assignment),
                            keyboardType: .numberPad,
                            capitalization: .none,
                            textAlignment: .center,
                            font: .boldSystemFont(ofSize: 22)
                        )
                        .frame(width: 112, height: 30)
                    } else {
                        Text(assignmentNumber.isEmpty ? "—" : assignmentNumber)
                    }
                }
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
                .onTapGesture {
                    focusedField = .assignment
                }
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

''' + s[end:]

# Existing leg number binding should start from the visible number when no explicit leg number exists.
rep(
'''    private func legNumberBinding(_ index: Int) -> Binding<String> {
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
''',
'''    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { draft[index].legNumber ?? draft[index].flightNumber },
            set: { draft[index].legNumber = $0.isEmpty ? nil : $0 }
        )
    }

    private func registrationDigitsBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let compact = draft[index].registration
                    .uppercased()
                    .replacingOccurrences(of: "-", with: "")
                if compact.hasPrefix("RA") {
                    return String(compact.dropFirst(2).filter(\\.isNumber).prefix(5))
                }
                return String(compact.filter(\\.isNumber).prefix(5))
            },
            set: { newValue in
                let digits = String(newValue.filter(\\.isNumber).prefix(5))
                draft[index].registration = "RA-" + digits
            }
        )
    }

    private func toggleScheduleType(_ index: Int) {
        let current = draft[index].scheduleType ?? .planned
        draft[index].scheduleType = current == .planned ? .unscheduled : .planned
        focusedField = nil
    }

    private func scheduleBinding(_ index: Int) -> Binding<FlightScheduleType> {
        Binding(
            get: { draft[index].scheduleType ?? .planned },
            set: { draft[index].scheduleType = $0 }
        )
    }
''',
'inline bindings'
)

# Inline editors for flight number, aircraft and registration; flight kind toggles on each tap.
start = s.index('    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {')
end = s.index('    private func focusBinding(_ field: DutyFocusedField) -> Binding<Bool> {', start)
replacement = '''    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Рейс", field: .legNumber(index)) {
            if focusedField == .legNumber(index) {
                InlineSelectAllTextField(
                    text: legNumberBinding(index),
                    isActive: focusBinding(.legNumber(index)),
                    keyboardType: .numbersAndPunctuation,
                    capitalization: .allCharacters,
                    textAlignment: .center,
                    font: .systemFont(ofSize: 15, weight: .semibold)
                )
                .frame(maxWidth: .infinity, minHeight: 22)
            } else {
                Text(leg.displayedLegNumber)
            }
        }
    }

    private func flightKindField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Вид полёта", field: .flightKind(index)) {
            Text((leg.scheduleType ?? .planned).rawValue)
        }
    }

    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Тип ВС", field: .aircraft(index)) {
            if focusedField == .aircraft(index) {
                InlineSelectAllTextField(
                    text: $draft[index].aircraft,
                    isActive: focusBinding(.aircraft(index)),
                    keyboardType: .default,
                    capitalization: .allCharacters,
                    textAlignment: .center,
                    font: .systemFont(ofSize: 15, weight: .semibold)
                )
                .frame(maxWidth: .infinity, minHeight: 22)
            } else {
                Text(leg.aircraft)
            }
        }
    }

    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Бортовой номер", field: .registration(index)) {
            if focusedField == .registration(index) {
                HStack(spacing: 0) {
                    Text("RA-")

                    InlineSelectAllTextField(
                        text: registrationDigitsBinding(index),
                        isActive: focusBinding(.registration(index)),
                        keyboardType: .numberPad,
                        capitalization: .none,
                        textAlignment: .left,
                        font: .systemFont(ofSize: 15, weight: .semibold),
                        maxLength: 5
                    )
                    .frame(width: 58, height: 22)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(formattedRegistration(leg.registration))
            }
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
            guard isEditing else { return }
            if case .flightKind(let index) = field {
                toggleScheduleType(index)
            } else {
                focusedField = field
            }
        }
    }

    private func routeIdentity(_ leg: FlightLeg, index: Int) -> some View {
        editableValue(
            "\\(airportDisplayName(leg.departure)) → \\(airportDisplayName(leg.arrival))",
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

'''
s = s[:start] + replacement + s[end:]

# Focus binding must work in both directions for UIKit inline fields.
rep(
'''    private func focusBinding(_ field: DutyFocusedField) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { if !$0 { focusedField = nil } }
        )
    }
''',
'''    private func focusBinding(_ field: DutyFocusedField) -> Binding<Bool> {
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
''',
'focus binding'
)

# Calculated time editor: restore compact width but keep the whole wheel visible and the table toggle above it.
rep('''        case .calculatedTime:
            return 230''', '''        case .calculatedTime:
            return 204''', 'calculated width helper')

old_calc = '''                        floatingEditor(width: 230) {
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
                        }'''
new_calc = '''                        floatingEditor(width: 204) {
                            VStack(alignment: .leading, spacing: 6) {
                                editPopoverHeader(
                                    "Расчётное время",
                                    extraHorizontalInset: 0
                                )
                                .zIndex(200)

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
                                                ?? "Ожидает норму"
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
                                        .frame(width: 166, minHeight: 38, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .zIndex(100)
                                }
                            }
                        }'''
rep(old_calc, new_calc, 'calculated editor')

# Inline UITextField that selects the whole editable fragment as soon as the card is activated.
insert_marker = '''// MARK: - Тест физической клавиатуры

private struct HardwareKeyboardTextField: UIViewRepresentable {'''
if insert_marker not in s:
    raise SystemExit('missing target: HardwareKeyboardTextField marker')
inline_field = '''// MARK: - Тест физической клавиатуры

private struct InlineSelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    let keyboardType: UIKeyboardType
    let capitalization: UITextAutocapitalizationType
    let textAlignment: NSTextAlignment
    let font: UIFont
    var maxLength: Int? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isActive: $isActive,
            maxLength: maxLength
        )
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .label
        field.tintColor = .systemBlue
        field.keyboardType = keyboardType
        field.autocorrectionType = .no
        field.autocapitalizationType = capitalization
        field.textAlignment = textAlignment
        field.font = font
        field.adjustsFontForContentSizeCategory = true
        field.delegate = context.coordinator
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

        if field.text != text && !field.isFirstResponder {
            field.text = text
        }

        if isActive && !field.isFirstResponder {
            DispatchQueue.main.async {
                field.becomeFirstResponder()
                field.selectAll(nil)
            }
        } else if !isActive && field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isActive: Binding<Bool>
        var maxLength: Int?

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isActive.wrappedValue = true
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isActive.wrappedValue = false
        }

        @objc func textChanged(_ field: UITextField) {
            var value = field.text ?? ""
            if let maxLength, value.count > maxLength {
                value = String(value.prefix(maxLength))
                field.text = value
            }
            text.wrappedValue = value
        }
    }
}

private struct HardwareKeyboardTextField: UIViewRepresentable {'''
s = s.replace(insert_marker, inline_field, 1)

path.write_text(s)
