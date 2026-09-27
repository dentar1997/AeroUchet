from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = '''                    .foregroundStyle(
                        isEditing ? Color.accentColor : Color.primary
                    )'''
new = '''                    .foregroundStyle(
                        isEditing
                            ? (isActive.wrappedValue
                                ? Color.accentColor.opacity(0.58)
                                : Color.accentColor)
                            : Color.primary
                    )'''
assert s.count(old) >= 2, s.count(old)
s = s.replace(old, new, 2)

old = '''                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)'''
new = '''                .foregroundStyle(
                    isEditing
                        ? (focusedField == field
                            ? Color.accentColor.opacity(0.58)
                            : Color.accentColor)
                        : Color.primary
                )'''
assert old in s
s = s.replace(old, new, 1)

old = '''            + Text(cleanCode)
                .foregroundColor(isEditing ? .accentColor : .primary)
            + Text(")")'''
new = '''            + Text(cleanCode)
                .foregroundColor(
                    isEditing
                        ? (isActive.wrappedValue
                            ? Color.accentColor.opacity(0.58)
                            : Color.accentColor)
                        : Color.primary
                )
            + Text(")")'''
assert old in s
s = s.replace(old, new, 1)

old = '''                            compact: true,
                            valueColor: .accentColor
                        )'''
new = '''                            compact: true,
                            valueColor: focusedField == .calculatedTime(index)
                                ? Color.accentColor.opacity(0.58)
                                : Color.accentColor
                        )'''
assert old in s
s = s.replace(old, new, 1)

old = '''                        value: formatDateTime(point.date(in: times(for: draft[index]))),
                        valueColor: .accentColor
                    )'''
new = '''                        value: formatDateTime(point.date(in: times(for: draft[index]))),
                        valueColor: focusedField == .time(index, point)
                            ? Color.accentColor.opacity(0.58)
                            : Color.accentColor
                    )'''
assert old in s
s = s.replace(old, new, 1)

old = '''        maxLength: Int? = nil,
        expands: Bool = true,
        allowsEditing: Bool = true,
        highlightHorizontalPadding: CGFloat = 2,'''
new = '''        maxLength: Int? = nil,
        expands: Bool = true,
        allowsEditing: Bool = true,
        restoreValue: String? = nil,
        highlightHorizontalPadding: CGFloat = 2,'''
assert old in s
s = s.replace(old, new, 1)

old = '''                    maxLength: maxLength,
                    isEnabled: true
                )'''
new = '''                    maxLength: maxLength,
                    isEnabled: true,
                    restoreValue: restoreValue
                )'''
assert old in s
s = s.replace(old, new, 1)

old = '''                expands: false,
                allowsEditing: isEditing,
                highlightHorizontalPadding: 0,
                textFont: .title3.bold(),'''
new = '''                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.first?.assignmentNumber
                    ?? duty.firstLeg.assignmentNumber
                    ?? "",
                highlightHorizontalPadding: 0,
                textFont: .title3.bold(),'''
assert old in s
s = s.replace(old, new, 1)

old = '''                maxLength: 10,
                expands: false,
                allowsEditing: isEditing
            )
        }
    }

    private func flightKindField'''
new = '''                maxLength: 10,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? (original[index].legNumber ?? original[index].flightNumber)
                    : leg.displayedLegNumber
            )
        }
    }

    private func flightKindField'''
assert old in s
s = s.replace(old, new, 1)

old = '''                maxLength: 10,
                expands: false,
                allowsEditing: isEditing
            )
        }
    }

    private func registrationField'''
new = '''                maxLength: 10,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? original[index].aircraft
                    : leg.aircraft
            )
        }
    }

    private func registrationField'''
assert old in s
s = s.replace(old, new, 1)

old = '''                maxLength: 5,
                expands: false,
                allowsEditing: isEditing,
                highlightHorizontalPadding: 0
            )'''
new = '''                maxLength: 5,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? formattedRegistration(original[index].registration)
                        .replacingOccurrences(of: "RA-", with: "")
                    : staticDigits,
                highlightHorizontalPadding: 0
            )'''
assert old in s
s = s.replace(old, new, 1)

old = '''                        maxLength: 5,
                        isEnabled: true
                    )'''
new = '''                        maxLength: 5,
                        isEnabled: true,
                        restoreValue: original.indices.contains(index)
                            ? (side == .departure
                                ? original[index].departure
                                : original[index].arrival)
                            : cleanCode
                    )'''
assert old in s
s = s.replace(old, new, 1)

old = '''    var maxLength: Int? = nil
    var isEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isActive: $isActive,
            maxLength: maxLength
        )'''
new = '''    var maxLength: Int? = nil
    var isEnabled: Bool = true
    var restoreValue: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isActive: $isActive,
            maxLength: maxLength,
            restoreValue: restoreValue
        )'''
assert old in s
s = s.replace(old, new, 1)

old = '''        context.coordinator.maxLength = maxLength
        field.font = font'''
new = '''        context.coordinator.maxLength = maxLength
        context.coordinator.restoreValue = restoreValue
        field.font = font'''
assert old in s
s = s.replace(old, new, 1)

old = '''        var maxLength: Int?
        private var replaceOnNextInput = false

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
        }'''
new = '''        var maxLength: Int?
        var restoreValue: String?
        private var replaceOnNextInput = false

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?,
            restoreValue: String?
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
            self.restoreValue = restoreValue
        }'''
assert old in s
s = s.replace(old, new, 1)

old = '''            var value = field.text ?? ""

            if replaceOnNextInput {
                value = ""
                replaceOnNextInput = false
            }

            if deleting {
                if !value.isEmpty {
                    value.removeLast()
                }
            } else if let characters {
                value.append(contentsOf: characters)
            }

            value = limited(value)'''
new = '''            var value = field.text ?? ""

            if deleting {
                // Backspace removes one symbol at a time. One extra Backspace
                // on an empty field restores the value from edit-mode entry.
                replaceOnNextInput = false
                if value.isEmpty,
                   let restoreValue,
                   !restoreValue.isEmpty {
                    value = limited(restoreValue)
                    replaceOnNextInput = true
                } else if !value.isEmpty {
                    value.removeLast()
                }
            } else if let characters {
                if replaceOnNextInput {
                    value = ""
                    replaceOnNextInput = false
                }
                value.append(contentsOf: characters)
            }

            value = limited(value)'''
assert old in s
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 93" in s
assert 'static let label = "Версия 93"' in s
s = s.replace("static let number = 93", "static let number = 94")
s = s.replace('static let label = "Версия 93"', 'static let label = "Версия 94"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "93"' in s
assert 'bundleVersion: "93"' in s
s = s.replace('displayVersion: "93"', 'displayVersion: "94"')
s = s.replace('bundleVersion: "93"', 'bundleVersion: "94"')
p.write_text(s)
