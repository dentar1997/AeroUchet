from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

# Номер задания: убрать бирюзовый фон и рамку режима редактирования.
old = '''        .padding(.horizontal, 12)
        .padding(.vertical, 4)
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
        .frame(maxWidth: .infinity)'''
new = '''        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)'''
assert old in s, "dutyTitle decoration not found"
s = s.replace(old, new, 1)

# Рейс / тип ВС / борт / номер задания: значение акцентное сразу после входа в edit mode.
needle = "isActive.wrappedValue ? Color.accentColor : Color.primary"
assert needle in s, "stableInlineEditor accent expression not found"
s = s.replace(needle, "isEditing ? Color.accentColor : Color.primary")

# Верхние поля leg: убрать фон и рамку, красить само значение.
old = '''            content()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 18, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
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
        .contentShape(Rectangle())'''
new = '''            content()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 18, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())'''
assert old in s, "identityField decoration not found"
s = s.replace(old, new, 1)

# Маршрут: убрать фон/рамку; окрашивать только коды аэропортов.
old = '''        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
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

    private func routeIdentity'''
new = '''        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }

    private func routeIdentity'''
assert old in s, "routeField decoration not found"
s = s.replace(old, new, 1)

old = '''            + Text(cleanCode)
                .foregroundColor(isActive.wrappedValue ? .accentColor : .primary)
            + Text(")")'''
new = '''            + Text(cleanCode)
                .foregroundColor(isEditing ? .accentColor : .primary)
            + Text(")")'''
assert old in s, "route code color not found"
s = s.replace(old, new, 1)

# Карточка значения: возможность окрасить только значение, не заголовок и не фон.
old = '''    private func legValueCard(
        title: String,
        value: String,
        centered: Bool = false,
        compact: Bool = false
    ) -> some View {'''
new = '''    private func legValueCard(
        title: String,
        value: String,
        centered: Bool = false,
        compact: Bool = false,
        valueColor: Color = .primary
    ) -> some View {'''
assert old in s, "legValueCard signature not found"
s = s.replace(old, new, 1)

old = '''            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)'''
new = '''            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)'''
assert old in s, "legValueCard value color not found"
s = s.replace(old, new, 1)

# Расчётное время: без бирюзовой рамки, акцентное только значение.
old = '''                        legValueCard(
                            title: "Расчётное время",
                            value: leg.calculatedMinutes.map(timeText) ?? "Отсутствует",
                            centered: true,
                            compact: true
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                        )'''
new = '''                        legValueCard(
                            title: "Расчётное время",
                            value: leg.calculatedMinutes.map(timeText) ?? "Отсутствует",
                            centered: true,
                            compact: true,
                            valueColor: .accentColor
                        )'''
assert old in s, "calculatedTime edit card not found"
s = s.replace(old, new, 1)

# Редактируемые даты/время: без бирюзовой рамки, акцентное только значение.
old = '''                    legValueCard(title: title, value: formatDateTime(
                        point.date(in: times(for: draft[index]))
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                    )'''
new = '''                    legValueCard(
                        title: title,
                        value: formatDateTime(point.date(in: times(for: draft[index]))),
                        valueColor: .accentColor
                    )'''
assert old in s, "timeCell edit card not found"
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 92" in s
assert 'static let label = "Версия 92"' in s
s = s.replace("static let number = 92", "static let number = 93")
s = s.replace('static let label = "Версия 92"', 'static let label = "Версия 93"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "92"' in s
assert 'bundleVersion: "92"' in s
s = s.replace('displayVersion: "92"', 'displayVersion: "93"')
s = s.replace('bundleVersion: "92"', 'bundleVersion: "93"')
p.write_text(s)
