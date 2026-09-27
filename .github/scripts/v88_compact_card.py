from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = '''            // Компактная ширина задания рассчитана от трёх временных
            // колонок по 192 pt плюс внутренние отступы карточек.
            let width = min(geometry.size.width * 0.92, 648)'''
new = '''            // Три временные колонки по 176 pt + промежутки + внутренние
            // отступы leg и задания дают компактную ширину около 600 pt.
            let width = min(geometry.size.width * 0.92, 600)'''
assert old in s, "overlay width block not found"
s = s.replace(old, new, 1)

old = '''    private let timeColumns = Array(
        repeating: GridItem(.fixed(192), spacing: 8),
        count: 3
    )'''
new = '''    private let timeColumns = Array(
        repeating: GridItem(.fixed(176), spacing: 8),
        count: 3
    )'''
assert old in s, "timeColumns block not found"
s = s.replace(old, new, 1)

old = '''    private func flightKindField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Вид полёта", field: .flightKind(index)) {
            Text((leg.scheduleType ?? .planned).rawValue)
        }
    }'''
new = '''    private func flightKindField(_ leg: FlightLeg, index: Int) -> some View {
        identityField("Вид полёта", field: .flightKind(index)) {
            ZStack {
                // Ширина всегда резервируется под самый длинный вариант,
                // чтобы «Плановый» не сжимал верхнюю строку.
                Text(FlightScheduleType.unscheduled.rawValue)
                    .hidden()
                Text((leg.scheduleType ?? .planned).rawValue)
            }
        }
    }'''
assert old in s, "flightKindField block not found"
s = s.replace(old, new, 1)

marker = '''    private func legValueCard(
        title: String,
        value: String,'''
idx = s.find(marker)
assert idx != -1, "legValueCard value overload not found"
head = s[:idx]
tail = s[idx:]
old = '''            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)'''
new = '''            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(value)'''
assert old in tail, "legValueCard title block not found"
tail = tail.replace(old, new, 1)
s = head + tail

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 87" in s
assert 'static let label = "Версия 87"' in s
s = s.replace("static let number = 87", "static let number = 88")
s = s.replace('static let label = "Версия 87"', 'static let label = "Версия 88"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "87"' in s
assert 'bundleVersion: "87"' in s
s = s.replace('displayVersion: "87"', 'displayVersion: "88"')
s = s.replace('bundleVersion: "87"', 'bundleVersion: "88"')
p.write_text(s)
