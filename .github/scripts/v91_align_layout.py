from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = '''        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)'''
new = '''        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)'''
assert old in s, "identityField padding block not found"
s = s.replace(old, new, 1)

old = '''        .padding(.horizontal, compact ? 12 : 10)
        .padding(.vertical, 6)'''
new = '''        .padding(.horizontal, 10)
        .padding(.vertical, 6)'''
assert old in s, "compact legValueCard padding block not found"
s = s.replace(old, new, 1)

old = '''        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
    }

    private func dutyTotalCell('''
new = '''        }
        .frame(width: 496, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    private func dutyTotalCell('''
assert old in s, "dutyTotals layout block not found"
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 90" in s
assert 'static let label = "Версия 90"' in s
s = s.replace("static let number = 90", "static let number = 91")
s = s.replace('static let label = "Версия 90"', 'static let label = "Версия 91"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "90"' in s
assert 'bundleVersion: "90"' in s
s = s.replace('displayVersion: "90"', 'displayVersion: "91"')
s = s.replace('bundleVersion: "90"', 'bundleVersion: "91"')
p.write_text(s)
