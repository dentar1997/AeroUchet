from pathlib import Path

app = Path('AppViews.swift')
s = app.read_text()

replacements = []

replacements.append((
'''                    HStack(alignment: .top, spacing: 8) {
                        flightNumber(leg, index: index)
                        aircraftField(leg, index: index)
                        registrationField(leg, index: index)
                    }''',
'''                    HStack(alignment: .top, spacing: 4) {
                        flightNumber(leg, index: index)
                            .frame(width: 62)
                        aircraftField(leg, index: index)
                            .frame(width: 72)
                        registrationField(leg, index: index)
                            .frame(maxWidth: .infinity)
                    }'''
))

replacements.append((
'''                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                allowsEditing: isEditing''',
'''                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                maxLength: 10,
                allowsEditing: isEditing'''
))

replacements.append((
'''                keyboardType: .default,
                capitalization: .allCharacters,
                allowsEditing: isEditing''',
'''                keyboardType: .default,
                capitalization: .allCharacters,
                maxLength: 10,
                allowsEditing: isEditing'''
))

replacements.append((
'''            Text("→")
                .foregroundStyle(.secondary)''',
'''            Text(" → ")
                .foregroundStyle(.secondary)'''
))

replacements.append((
'''            Text("\\(airportNameOnly(code.wrappedValue))(")''',
'''            Text("\\(airportNameOnly(code.wrappedValue)) (")'''
))

replacements.append((
'''                maxLength: 4,
                expands: false,''',
'''                maxLength: 5,
                expands: false,'''
))

replacements.append((
'''                            character.isASCII && (character.isLetter || character.isNumber)
                        }
                        .prefix(4)''',
'''                            character.isASCII
                                && (character.isLetter || character.isNumber || character == "/")
                        }
                        .prefix(5)'''
))

replacements.append((
'''        let field = HardwareFriendlyTextField(frame: .zero)''',
'''        let field = UITextField(frame: .zero)'''
))

replacements.append((
'''        field.hardwareInputHandler = { [weak field] characters, deleting in
            guard let field else { return }
            context.coordinator.handleHardwareInput(
                characters,
                deleting: deleting,
                in: field
            )
        }
''',
''''''
))

for old, new in replacements:
    if old not in s:
        raise SystemExit(f'Expected block not found:\n{old[:180]}')
    s = s.replace(old, new, 1)

# Center all three calculated-time cards while preserving all other value cards.
s = s.replace(
'''                        legValueCard(
                            title: "Расчётное время",
                            value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму"
                        )''',
'''                        legValueCard(
                            title: "Расчётное время",
                            value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму",
                            centered: true
                        )''',
1)
s = s.replace(
'''                legValueCard(
                    title: "Расчётное время",
                    value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму"
                )''',
'''                legValueCard(
                    title: "Расчётное время",
                    value: leg.calculatedMinutes.map(timeText) ?? "Ожидает норму",
                    centered: true
                )''',
1)

old_card = '''    private func legValueCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.85)
                .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .accessibilityElement(children: .combine)
    }'''
new_card = '''    private func legValueCard(
        title: String,
        value: String,
        centered: Bool = false
    ) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.85)
                .frame(
                    height: 18,
                    alignment: centered ? .center : .leading
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: centered ? .center : .leading
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .accessibilityElement(children: .combine)
    }'''
if old_card not in s:
    raise SystemExit('legValueCard block not found')
s = s.replace(old_card, new_card, 1)

app.write_text(s)

v = Path('AppVersion.swift')
vs = v.read_text()
vs = vs.replace('static let number = 66', 'static let number = 67')
vs = vs.replace('static let label = "Версия 66"', 'static let label = "Версия 67"')
v.write_text(vs)

p = Path('Package.swift')
ps = p.read_text()
ps = ps.replace('displayVersion: "66"', 'displayVersion: "67"')
ps = ps.replace('bundleVersion: "66"', 'bundleVersion: "67"')
p.write_text(ps)
