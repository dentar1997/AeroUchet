from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

count = s.count('?? "Ожидает норму"')
assert count == 3, f"expected 3 calculated-time placeholders, found {count}"
s = s.replace('?? "Ожидает норму"', '?? "Отсутствует"')

old = '''            HStack(alignment: .top, spacing: 8) {
                flightNumber(leg, index: index)
                aircraftField(leg, index: index)
                registrationField(leg, index: index)
                flightKindField(leg, index: index)
                calculatedTime(leg, index: index)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            routeField(leg, index: index)
                .frame(maxWidth: .infinity)'''
new = '''            HStack(alignment: .top, spacing: 8) {
                flightNumber(leg, index: index)
                aircraftField(leg, index: index)
                registrationField(leg, index: index)
                flightKindField(leg, index: index)
                calculatedTime(leg, index: index)
            }
            .frame(width: 496, alignment: .center)

            routeField(leg, index: index)
                .frame(width: 496)'''
assert old in s, "legHeader layout block not found"
s = s.replace(old, new, 1)

old = '''        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)'''
new = '''        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)'''
assert old in s, "identityField padding block not found"
s = s.replace(old, new, 1)

old = '''        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .fixedSize(horizontal: compact, vertical: false)'''
new = '''        .padding(.horizontal, compact ? 12 : 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .fixedSize(horizontal: compact, vertical: false)'''
assert old in s, "compact legValueCard padding block not found"
s = s.replace(old, new, 1)

old = '''        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(valueTileColor)
        )
        .accessibilityElement(children: .combine)
    }

    private func timeAndNight(total: Int, night: Int) -> some View {'''
new = '''        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func timeAndNight(total: Int, night: Int) -> some View {'''
assert old in s, "dutyTotalCell background block not found"
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 89" in s
assert 'static let label = "Версия 89"' in s
s = s.replace("static let number = 89", "static let number = 90")
s = s.replace('static let label = "Версия 89"', 'static let label = "Версия 90"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "89"' in s
assert 'bundleVersion: "89"' in s
s = s.replace('displayVersion: "89"', 'displayVersion: "90"')
s = s.replace('bundleVersion: "89"', 'bundleVersion: "90"')
p.write_text(s)
