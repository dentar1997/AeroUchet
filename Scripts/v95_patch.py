from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()


def replace_once(label, old, new):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    text = text.replace(old, new, 1)


def replace_between(label, start, end, new_block):
    global text
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"{label}: start marker not found")
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f"{label}: end marker not found")
    text = text[:i] + new_block + text[j:]


replace_once(
    "assignment field",
    '''                isActive: isEditing ? focusBinding(.assignment) : .constant(false),
                keyboardType: .numberPad,''',
    '''                isActive: isEditing ? focusBinding(.assignment) : .constant(false),
                field: .assignment,
                keyboardType: .numberPad,'''
)

replace_once(
    "assignment reserve width",
    '''                restoreValue: original.first?.assignmentNumber
                    ?? duty.firstLeg.assignmentNumber
                    ?? "",
                highlightHorizontalPadding: 0,''',
    '''                restoreValue: original.first?.assignmentNumber
                    ?? duty.firstLeg.assignmentNumber
                    ?? "",
                reserveText: "8888888",
                highlightHorizontalPadding: 0,'''
)

replace_once(
    "flight field behavior",
    '''                isActive: activeBinding,
                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,''',
    '''                isActive: activeBinding,
                field: .legNumber(index),
                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                clearOnFirstDelete: true,'''
)

replace_once(
    "aircraft field state",
    '''                isActive: activeBinding,
                keyboardType: .default,
                capitalization: .allCharacters,''',
    '''                isActive: activeBinding,
                field: .aircraft(index),
                keyboardType: .default,
                capitalization: .allCharacters,'''
)

replace_once(
    "registration field state",
    '''                isActive: activeBinding,
                prefix: "RA-",
                keyboardType: .numberPad,''',
    '''                isActive: activeBinding,
                field: .registration(index),
                prefix: "RA-",
                keyboardType: .numberPad,'''
)

stable_block = '''    private func stableInlineEditor(
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
        reserveText: String? = nil,
        highlightHorizontalPadding: CGFloat = 2,
        textFont: Font = .subheadline.weight(.semibold),
        inputFont: UIFont = .systemFont(ofSize: 15, weight: .semibold),
        lineHeight: CGFloat = 18
    ) -> some View {
        let valueColor = isEditing
            ? editorValueColor(for: field, isActive: isActive.wrappedValue)
            : Color.primary

        ZStack(alignment: .leading) {
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
                    clearOnFirstDelete: clearOnFirstDelete
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
            return Color.accentColor.opacity(0.72)
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
            let before = original[index].legNumber ?? original[index].flightNumber
            let after = draft[index].legNumber ?? draft[index].flightNumber
            return before != after

        case .aircraft(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return draft[index].aircraft != original[index].aircraft

        case .registration(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            let before = original[index].registration
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let after = draft[index].registration
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return before != after

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

'''
replace_between(
    "stable editor + state colors",
    "    private func stableInlineEditor(\n",
    "    private func identityField<Content: View>(\n",
    stable_block
)

identity_block = '''    private func identityField<Content: View>(
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

'''
replace_between(
    "identity field colors",
    "    private func identityField<Content: View>(\n",
    "    private func routeField(_ leg: FlightLeg, index: Int) -> some View {\n",
    identity_block
)

route_endpoint_block = '''    private func routeEndpoint(
        code: Binding<String>,
        index: Int,
        side: RouteEditSide
    ) -> some View {
        let cleanCode = code.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isActive = routeFocusBinding(index: index, side: side)
        let endpointText =
            Text("\\(airportNameOnly(cleanCode)) (")
            + Text(cleanCode)
                .foregroundColor(
                    isEditing
                        ? editorValueColor(
                            for: .route(index),
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
'''
replace_between(
    "route changed color",
    "    private func routeEndpoint(\n",
    "    private func routeCodeBinding(index: Int, side: RouteEditSide) -> Binding<String> {\n",
    route_endpoint_block
)

calculated_block = '''    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Расчётное время", field: .calculatedTime(index)) {
            Text(leg.calculatedMinutes.map(timeText) ?? "Отсутствует")
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
                                        ?? "Отсутствует"
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
                .offset(y: 46)
            }
        }
        .zIndex(focusedField == .calculatedTime(index) ? 1000 : 0)
    }

'''
replace_between(
    "calculated time plain field",
    "    private func calculatedTime(_ leg: FlightLeg, index: Int) -> some View {\n",
    "    private func toggleCalculatedTimeSource(_ index: Int) {\n",
    calculated_block
)

replace_once(
    "time changed color",
    '''                        valueColor: focusedField == .time(index, point)
                            ? Color.accentColor.opacity(0.58)
                            : Color.accentColor''',
    '''                        valueColor: editorValueColor(
                            for: .time(index, point),
                            isActive: focusedField == .time(index, point)
                        )'''
)

inline_block = '''private struct InlineSelectAllTextField: UIViewRepresentable {
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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isActive: $isActive,
            maxLength: maxLength,
            restoreValue: restoreValue,
            clearOnFirstDelete: clearOnFirstDelete
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
        private var replaceOnNextInput = false

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?,
            restoreValue: String?,
            clearOnFirstDelete: Bool
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
            self.restoreValue = restoreValue
            self.clearOnFirstDelete = clearOnFirstDelete
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
            guard let maxLength else { return value }
            return String(value.prefix(maxLength))
        }

        private func moveCaretToEnd(in field: UITextField) {
            DispatchQueue.main.async {
                guard let end = field.endOfDocument as UITextPosition? else { return }
                field.selectedTextRange = field.textRange(from: end, to: end)
            }
        }
    }
}

'''
replace_between(
    "inline field delete behavior",
    "private struct InlineSelectAllTextField: UIViewRepresentable {\n",
    "private struct HardwareKeyboardTextField: UIViewRepresentable {\n",
    inline_block
)

path.write_text(text)

version = Path("AppVersion.swift")
version_text = version.read_text()
if 'static let number = 94' not in version_text or 'static let label = "Версия 94"' not in version_text:
    raise SystemExit("AppVersion.swift is not v94")
version_text = version_text.replace('static let number = 94', 'static let number = 95')
version_text = version_text.replace('static let label = "Версия 94"', 'static let label = "Версия 95"')
version.write_text(version_text)

package = Path("Package.swift")
package_text = package.read_text()
if 'displayVersion: "94"' not in package_text or 'bundleVersion: "94"' not in package_text:
    raise SystemExit("Package.swift is not v94")
package_text = package_text.replace('displayVersion: "94"', 'displayVersion: "95"', 1)
package_text = package_text.replace('bundleVersion: "94"', 'bundleVersion: "95"', 1)
package.write_text(package_text)
