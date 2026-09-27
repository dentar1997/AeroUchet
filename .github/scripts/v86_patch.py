from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = """            HStack(alignment: .top, spacing: 8) {
                flightNumber(leg, index: index)
                    .frame(maxWidth: .infinity)
                aircraftField(leg, index: index)
                    .frame(maxWidth: .infinity)
                registrationField(leg, index: index)
                    .frame(maxWidth: .infinity)
                flightKindField(leg, index: index)
                    .frame(maxWidth: .infinity)
                calculatedTime(leg, index: index)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)"""
new = """            HStack(alignment: .top, spacing: 8) {
                flightNumber(leg, index: index)
                aircraftField(leg, index: index)
                registrationField(leg, index: index)
                flightKindField(leg, index: index)
                calculatedTime(leg, index: index)
            }
            .frame(maxWidth: .infinity, alignment: .center)"""
assert old in s
s = s.replace(old, new, 1)

old = """        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)"""
new = """        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)"""
assert old in s
s = s.replace(old, new, 1)

old = """                            centered: true,
                            compact: false"""
new = """                            centered: true,
                            compact: true"""
assert old in s
s = s.replace(old, new, 1)

old = """                    centered: true,
                    compact: false"""
new = """                    centered: true,
                    compact: true"""
assert old in s
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 85" in s
assert 'static let label = "Версия 85"' in s
s = s.replace("static let number = 85", "static let number = 86")
s = s.replace('static let label = "Версия 85"', 'static let label = "Версия 86"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "85"' in s
assert 'bundleVersion: "85"' in s
s = s.replace('displayVersion: "85"', 'displayVersion: "86"')
s = s.replace('bundleVersion: "85"', 'bundleVersion: "86"')
p.write_text(s)
