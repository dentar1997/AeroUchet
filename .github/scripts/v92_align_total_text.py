from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = '''    private func dutyTotals(_ duty: FlightDuty) -> some View {
        HStack(spacing: 8) {
            dutyTotalCell(
                title: "Рабочее время",
                total: duty.workMinutes,
                night: duty.workNightMinutes
            )

            dutyTotalCell(
                title: "Полётное время",
                total: duty.flightMinutes,
                night: duty.flightNightMinutes
            )

            dutyTotalCell(
                title: "Лётное время",
                total: duty.airMinutes,
                night: duty.airNightMinutes
            )
        }
        .frame(width: 496, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }'''

new = '''    private func dutyTotals(_ duty: FlightDuty) -> some View {
        LazyVGrid(columns: timeColumns, alignment: .leading, spacing: 6) {
            dutyTotalCell(
                title: "Рабочее время",
                total: duty.workMinutes,
                night: duty.workNightMinutes
            )

            dutyTotalCell(
                title: "Полётное время",
                total: duty.flightMinutes,
                night: duty.flightNightMinutes
            )

            dutyTotalCell(
                title: "Лётное время",
                total: duty.airMinutes,
                night: duty.airNightMinutes
            )
        }
        .frame(width: 496, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }'''

assert old in s, "dutyTotals block not found"
s = s.replace(old, new, 1)
p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 91" in s
assert 'static let label = "Версия 91"' in s
s = s.replace("static let number = 91", "static let number = 92")
s = s.replace('static let label = "Версия 91"', 'static let label = "Версия 92"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "91"' in s
assert 'bundleVersion: "91"' in s
s = s.replace('displayVersion: "91"', 'displayVersion: "92"')
s = s.replace('bundleVersion: "91"', 'bundleVersion: "92"')
p.write_text(s)
