from pathlib import Path

path = Path('AppViews.swift')
s = path.read_text()

old = '''            identityField("Маршрут", field: .route(index)) {
                routeIdentity(leg, index: index)
            }
            .frame(maxWidth: .infinity, alignment: .top)
'''
new = '''            routeField(leg, index: index)
                .frame(maxWidth: .infinity, alignment: .top)
'''
assert old in s
s = s.replace(old, new, 1)

old = '''    private func routeIdentity(_ leg: FlightLeg, index: Int) -> some View {
        HStack(spacing: 4) {
            routeEndpoint(
                code: isEditing ? $draft[index].departure : .constant(leg.departure),
                index: index,
                side: .departure
            )

            Text("→")
                .foregroundStyle(.secondary)

            routeEndpoint(
                code: isEditing ? $draft[index].arrival : .constant(leg.arrival),
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
        HStack(spacing: 0) {
            Text("\\(airportNameOnly(code.wrappedValue)) (")

            stableInlineEditor(
                text: code,
                isActive: routeFocusBinding(index: index, side: side),
                keyboardType: .asciiCapable,
                capitalization: .allCharacters,
                expands: false
            )

            Text(")")
        }
        .fixedSize(horizontal: true, vertical: false)
    }
'''
new = '''    private func routeField(_ leg: FlightLeg, index: Int) -> some View {
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
    }

    private func routeIdentity(_ leg: FlightLeg, index: Int) -> some View {
        HStack(spacing: 4) {
            routeEndpoint(
                code: isEditing
                    ? routeCodeBinding(index: index, side: .departure)
                    : .constant(leg.departure),
                index: index,
                side: .departure
            )

            Text("→")
                .foregroundStyle(.secondary)

            routeEndpoint(
                code: isEditing
                    ? routeCodeBinding(index: index, side: .arrival)
                    : .constant(leg.arrival),
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
        HStack(spacing: 0) {
            Text("\\(airportNameOnly(code.wrappedValue))(")

            stableInlineEditor(
                text: code,
                isActive: routeFocusBinding(index: index, side: side),
                keyboardType: .asciiCapable,
                capitalization: .allCharacters,
                maxLength: 4,
                expands: false
            )

            Text(")")
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(
            maxWidth: .infinity,
            alignment: side == .departure ? .trailing : .leading
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            routeEditSide = side
            focusedField = .route(index)
        }
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
                            character.isASCII && (character.isLetter || character.isNumber)
                        }
                        .prefix(4)
                )

                if side == .departure {
                    draft[index].departure = normalized
                } else {
                    draft[index].arrival = normalized
                }
            }
        )
    }
'''
assert old in s
s = s.replace(old, new, 1)

start = s.index('private struct InlineSelectAllTextField: UIViewRepresentable {')
end = s.index('\nprivate struct HardwareKeyboardTextField: UIViewRepresentable {', start)
old = s[start:end]
new = '''private struct InlineSelectAllTextField: UIViewRepresentable {
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
        field.isUserInteractionEnabled = true
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
        field.font = font
        field.keyboardType = keyboardType
        field.autocapitalizationType = capitalization

        if field.text != text && !field.isFirstResponder {
            field.text = text
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
        private var replaceOnNextInput = false

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
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
            if field.text != value {
                field.text = value
                moveCaretToEnd(in: field)
            }
            text.wrappedValue = value
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
s = s[:start] + new + s[end:]

path.write_text(s)

v = Path('AppVersion.swift')
vs = v.read_text().replace('static let number = 63', 'static let number = 64').replace('static let label = "Версия 63"', 'static let label = "Версия 64"')
v.write_text(vs)

p = Path('Package.swift')
ps = p.read_text().replace('displayVersion: "63"', 'displayVersion: "64"').replace('bundleVersion: "63"', 'bundleVersion: "64"')
p.write_text(ps)
