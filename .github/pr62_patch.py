from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()

def once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    text = text.replace(old, new, 1)

once(
'''    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? legNumberBinding(index)
            : .constant(leg.displayedLegNumber)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.legNumber(index))
            : .constant(false)

        return identityField("Рейс", field: .legNumber(index)) {
            InlineSelectAllTextField(
                text: textBinding,
                isActive: activeBinding,
                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                textAlignment: .center,
                font: .systemFont(ofSize: 15, weight: .semibold)
            )
            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
            .allowsHitTesting(isEditing)
        }
    }
''',
'''    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? legNumberBinding(index)
            : .constant(leg.displayedLegNumber)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.legNumber(index))
            : .constant(false)

        return identityField("Рейс", field: .legNumber(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters
            )
        }
    }
''',
"flight number stable visual text"
)

once(
'''    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? $draft[index].aircraft
            : .constant(leg.aircraft)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.aircraft(index))
            : .constant(false)

        return identityField("Тип ВС", field: .aircraft(index)) {
            InlineSelectAllTextField(
                text: textBinding,
                isActive: activeBinding,
                keyboardType: .default,
                capitalization: .allCharacters,
                textAlignment: .center,
                font: .systemFont(ofSize: 15, weight: .semibold)
            )
            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
            .allowsHitTesting(isEditing)
        }
    }
''',
'''    private func aircraftField(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? $draft[index].aircraft
            : .constant(leg.aircraft)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.aircraft(index))
            : .constant(false)

        return identityField("Тип ВС", field: .aircraft(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                keyboardType: .default,
                capitalization: .allCharacters
            )
        }
    }
''',
"aircraft stable visual text"
)

once(
'''    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        let staticDigits = formattedRegistration(leg.registration)
            .replacingOccurrences(of: "RA-", with: "")
        let textBinding: Binding<String> = isEditing
            ? registrationDigitsBinding(index)
            : .constant(staticDigits)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.registration(index))
            : .constant(false)

        return identityField("Бортовой номер", field: .registration(index)) {
            HStack(spacing: 0) {
                Text("RA-")

                InlineSelectAllTextField(
                    text: textBinding,
                    isActive: activeBinding,
                    keyboardType: .numberPad,
                    capitalization: .none,
                    textAlignment: .left,
                    font: .systemFont(ofSize: 15, weight: .semibold),
                    maxLength: 5
                )
                .frame(width: 58, height: 18)
                .allowsHitTesting(isEditing)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
''',
'''    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        let staticDigits = formattedRegistration(leg.registration)
            .replacingOccurrences(of: "RA-", with: "")
        let textBinding: Binding<String> = isEditing
            ? registrationDigitsBinding(index)
            : .constant(staticDigits)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.registration(index))
            : .constant(false)

        return identityField("Бортовой номер", field: .registration(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                prefix: "RA-",
                keyboardType: .numberPad,
                capitalization: .none,
                maxLength: 5
            )
        }
    }
''',
"registration stable visual text"
)

marker = '''    private func identityField<Content: View>(
'''
helper = '''    private func stableInlineEditor(
        text: Binding<String>,
        isActive: Binding<Bool>,
        prefix: String = "",
        keyboardType: UIKeyboardType,
        capitalization: UITextAutocapitalizationType,
        maxLength: Int? = nil
    ) -> some View {
        ZStack {
            Text(prefix + text.wrappedValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
                .background {
                    if isActive.wrappedValue {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(0.22))
                    }
                }

            InlineSelectAllTextField(
                text: text,
                isActive: isActive,
                keyboardType: keyboardType,
                capitalization: capitalization,
                textAlignment: .center,
                font: .systemFont(ofSize: 15, weight: .semibold),
                maxLength: maxLength
            )
            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
            .opacity(0.01)
            .allowsHitTesting(false)
        }
        .frame(height: 18)
    }

'''
if text.count(marker) != 1:
    raise SystemExit(f"identity marker: expected 1 match, found {text.count(marker)}")
text = text.replace(marker, helper + marker, 1)

path.write_text(text)
