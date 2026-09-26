from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


path = Path("AppViews.swift")
text = path.read_text()

text = replace_once(
    text,
    '''                    stableInlineEditor(\n                        text: $assignmentNumber,\n                        isActive: focusBinding(.assignment),\n                        keyboardType: .numberPad,\n                        capitalization: .none,\n                        expands: false\n                    )''',
    '''                    stableInlineEditor(\n                        text: $assignmentNumber,\n                        isActive: focusBinding(.assignment),\n                        keyboardType: .numberPad,\n                        capitalization: .none,\n                        expands: false,\n                        allowsEditing: isEditing\n                    )''',
    "assignment editor",
)

text = replace_once(
    text,
    '''            stableInlineEditor(\n                text: textBinding,\n                isActive: activeBinding,\n                keyboardType: .numbersAndPunctuation,\n                capitalization: .allCharacters\n            )''',
    '''            stableInlineEditor(\n                text: textBinding,\n                isActive: activeBinding,\n                keyboardType: .numbersAndPunctuation,\n                capitalization: .allCharacters,\n                allowsEditing: isEditing\n            )''',
    "flight editor",
)

text = replace_once(
    text,
    '''            stableInlineEditor(\n                text: textBinding,\n                isActive: activeBinding,\n                keyboardType: .default,\n                capitalization: .allCharacters\n            )''',
    '''            stableInlineEditor(\n                text: textBinding,\n                isActive: activeBinding,\n                keyboardType: .default,\n                capitalization: .allCharacters,\n                allowsEditing: isEditing\n            )''',
    "aircraft editor",
)

text = replace_once(
    text,
    '''            stableInlineEditor(\n                text: textBinding,\n                isActive: activeBinding,\n                prefix: "RA-",\n                keyboardType: .numberPad,\n                capitalization: .none,\n                maxLength: 5\n            )''',
    '''            stableInlineEditor(\n                text: textBinding,\n                isActive: activeBinding,\n                prefix: "RA-",\n                keyboardType: .numberPad,\n                capitalization: .none,\n                maxLength: 5,\n                allowsEditing: isEditing\n            )''',
    "registration editor",
)

text = replace_once(
    text,
    '''        maxLength: Int? = nil,\n        expands: Bool = true\n    ) -> some View {''',
    '''        maxLength: Int? = nil,\n        expands: Bool = true,\n        allowsEditing: Bool = true,\n        highlightHorizontalPadding: CGFloat = 2\n    ) -> some View {''',
    "stable editor signature",
)

text = replace_once(
    text,
    '''                    .padding(.horizontal, 2)''',
    '''                    .padding(.horizontal, highlightHorizontalPadding)''',
    "highlight padding",
)

text = replace_once(
    text,
    '''                font: .systemFont(ofSize: 15, weight: .semibold),\n                maxLength: maxLength\n            )\n            .frame(maxWidth: expands ? .infinity : nil, minHeight: 18, maxHeight: 18)\n            .fixedSize(horizontal: !expands, vertical: false)''',
    '''                font: .systemFont(ofSize: 15, weight: .semibold),\n                maxLength: maxLength,\n                isEnabled: allowsEditing\n            )\n            .frame(maxWidth: expands ? .infinity : nil, minHeight: 18, maxHeight: 18)\n            .fixedSize(horizontal: !expands, vertical: false)\n            .allowsHitTesting(allowsEditing)''',
    "stable editor input",
)

text = replace_once(
    text,
    '''        HStack(spacing: 4) {\n            routeEndpoint(''',
    '''        HStack(spacing: 0) {\n            routeEndpoint(''',
    "route spacing",
)

text = replace_once(
    text,
    '''                    ? routeCodeBinding(index: index, side: .departure)\n                    : .constant(leg.departure),''',
    '''                    ? routeCodeBinding(index: index, side: .departure)\n                    : .constant(leg.departure.trimmingCharacters(in: .whitespacesAndNewlines)),''',
    "departure trim",
)

text = replace_once(
    text,
    '''                    ? routeCodeBinding(index: index, side: .arrival)\n                    : .constant(leg.arrival),''',
    '''                    ? routeCodeBinding(index: index, side: .arrival)\n                    : .constant(leg.arrival.trimmingCharacters(in: .whitespacesAndNewlines)),''',
    "arrival trim",
)

text = replace_once(
    text,
    '''                capitalization: .allCharacters,\n                maxLength: 4,\n                expands: false\n            )''',
    '''                capitalization: .allCharacters,\n                maxLength: 4,\n                expands: false,\n                allowsEditing: isEditing,\n                highlightHorizontalPadding: 0\n            )''',
    "route editor options",
)

text = replace_once(
    text,
    '''    private func routeFocusBinding(index: Int, side: RouteEditSide) -> Binding<Bool> {\n        Binding(\n            get: { focusedField == .route(index) && routeEditSide == side },\n            set: { active in\n                if active {\n                    routeEditSide = side\n                    focusedField = .route(index)\n                } else if focusedField == .route(index) && routeEditSide == side {\n                    focusedField = nil\n                }\n            }\n        )\n    }''',
    '''    private func routeFocusBinding(index: Int, side: RouteEditSide) -> Binding<Bool> {\n        Binding(\n            get: {\n                isEditing\n                    && focusedField == .route(index)\n                    && routeEditSide == side\n            },\n            set: { active in\n                guard isEditing else {\n                    if focusedField == .route(index) {\n                        focusedField = nil\n                    }\n                    return\n                }\n\n                if active {\n                    routeEditSide = side\n                    focusedField = .route(index)\n                } else if focusedField == .route(index) && routeEditSide == side {\n                    focusedField = nil\n                }\n            }\n        )\n    }''',
    "route focus guard",
)

text = replace_once(
    text,
    '''        return String(display[..<range.lowerBound])''',
    '''        return String(display[..<range.lowerBound])\n            .trimmingCharacters(in: .whitespacesAndNewlines)''',
    "airport name trim",
)

text = replace_once(
    text,
    '''// MARK: - Тест физической клавиатуры\n\nprivate struct InlineSelectAllTextField: UIViewRepresentable {''',
    '''// MARK: - Тест физической клавиатуры\n\nprivate final class HardwareFriendlyTextField: UITextField {\n    var hardwareInputHandler: ((String?, Bool) -> Void)?\n\n    override func pressesBegan(\n        _ presses: Set<UIPress>,\n        with event: UIPressesEvent?\n    ) {\n        var handled = false\n\n        for press in presses {\n            guard let key = press.key else { continue }\n\n            if key.keyCode == .keyboardDeleteOrBackspace {\n                hardwareInputHandler?(nil, true)\n                handled = true\n                continue\n            }\n\n            let commandModifiers: UIKeyModifierFlags = [\n                .command,\n                .control,\n                .alternate\n            ]\n            guard key.modifierFlags.intersection(commandModifiers).isEmpty else {\n                continue\n            }\n\n            let characters = key.characters\n            let printable = !characters.isEmpty\n                && characters.unicodeScalars.allSatisfy { scalar in\n                    scalar.value >= 0x20\n                        && !(0xE000...0xF8FF).contains(scalar.value)\n                }\n\n            if printable {\n                hardwareInputHandler?(characters, false)\n                handled = true\n            }\n        }\n\n        if !handled {\n            super.pressesBegan(presses, with: event)\n        }\n    }\n}\n\nprivate struct InlineSelectAllTextField: UIViewRepresentable {''',
    "hardware field subclass",
)

text = replace_once(
    text,
    '''    let font: UIFont\n    var maxLength: Int? = nil\n''',
    '''    let font: UIFont\n    var maxLength: Int? = nil\n    var isEnabled: Bool = true\n''',
    "input enabled property",
)

text = replace_once(
    text,
    '''    func makeUIView(context: Context) -> UITextField {\n        let field = UITextField(frame: .zero)''',
    '''    func makeUIView(context: Context) -> UITextField {\n        let field = HardwareFriendlyTextField(frame: .zero)''',
    "hardware field make",
)

text = replace_once(
    text,
    '''        field.isUserInteractionEnabled = true\n        field.delegate = context.coordinator\n        field.addTarget(''',
    '''        field.isEnabled = isEnabled\n        field.isUserInteractionEnabled = isEnabled\n        field.hardwareInputHandler = { [weak field] characters, deleting in\n            guard let field else { return }\n            context.coordinator.handleHardwareInput(\n                characters,\n                deleting: deleting,\n                in: field\n            )\n        }\n        field.delegate = context.coordinator\n        field.addTarget(''',
    "hardware handler setup",
)

text = replace_once(
    text,
    '''        field.font = font\n        field.keyboardType = keyboardType\n        field.autocapitalizationType = capitalization\n\n        if field.text != text && !field.isFirstResponder {\n            field.text = text\n        }\n\n        if isActive && !field.isFirstResponder {''',
    '''        field.font = font\n        field.keyboardType = keyboardType\n        field.autocapitalizationType = capitalization\n        field.isEnabled = isEnabled\n        field.isUserInteractionEnabled = isEnabled\n\n        if field.text != text {\n            field.text = text\n        }\n\n        guard isEnabled else {\n            if field.isFirstResponder {\n                field.resignFirstResponder()\n            }\n            return\n        }\n\n        if isActive && !field.isFirstResponder {''',
    "input update enabled",
)

text = replace_once(
    text,
    '''        @objc func textChanged(_ field: UITextField) {\n            let value = limited(field.text ?? "")\n            if field.text != value {\n                field.text = value\n                moveCaretToEnd(in: field)\n            }\n            text.wrappedValue = value\n        }\n\n        private func limited(_ value: String) -> String {''',
    '''        @objc func textChanged(_ field: UITextField) {\n            let value = limited(field.text ?? "")\n            text.wrappedValue = value\n            let normalized = text.wrappedValue\n            if field.text != normalized {\n                field.text = normalized\n                moveCaretToEnd(in: field)\n            }\n        }\n\n        func handleHardwareInput(\n            _ characters: String?,\n            deleting: Bool,\n            in field: UITextField\n        ) {\n            var value = field.text ?? ""\n\n            if replaceOnNextInput {\n                value = ""\n                replaceOnNextInput = false\n            }\n\n            if deleting {\n                if !value.isEmpty {\n                    value.removeLast()\n                }\n            } else if let characters {\n                value.append(contentsOf: characters)\n            }\n\n            value = limited(value)\n            text.wrappedValue = value\n            field.text = text.wrappedValue\n            moveCaretToEnd(in: field)\n        }\n\n        private func limited(_ value: String) -> String {''',
    "hardware input coordinator",
)

path.write_text(text)

version = Path("AppVersion.swift")
version_text = version.read_text()
version_text = version_text.replace("static let number = 65", "static let number = 66")
version_text = version_text.replace('static let label = "Версия 65"', 'static let label = "Версия 66"')
if "Версия 66" not in version_text:
    raise SystemExit("AppVersion update failed")
version.write_text(version_text)

package = Path("Package.swift")
package_text = package.read_text()
package_text = package_text.replace('displayVersion: "65"', 'displayVersion: "66"')
package_text = package_text.replace('bundleVersion: "65"', 'bundleVersion: "66"')
if 'displayVersion: "66"' not in package_text or 'bundleVersion: "66"' not in package_text:
    raise SystemExit("Package version update failed")
package.write_text(package_text)
