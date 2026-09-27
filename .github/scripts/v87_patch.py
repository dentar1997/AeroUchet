from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = '''            let widthRatio = geometry.size.width >= 800 ? 0.74 : 0.92
            let width = min(geometry.size.width * widthRatio, 940)'''
new = '''            // Компактная ширина задания рассчитана от трёх временных
            // колонок по 192 pt плюс внутренние отступы карточек.
            let width = min(geometry.size.width * 0.92, 648)'''
assert old in s, "overlay width block not found"
s = s.replace(old, new, 1)

old = '''    private let timeColumns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 8),
        count: 3
    )'''
new = '''    private let timeColumns = Array(
        repeating: GridItem(.fixed(192), spacing: 8),
        count: 3
    )'''
assert old in s, "timeColumns block not found"
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 86" in s
assert 'static let label = "Версия 86"' in s
s = s.replace("static let number = 86", "static let number = 87")
s = s.replace('static let label = "Версия 86"', 'static let label = "Версия 87"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "86"' in s
assert 'bundleVersion: "86"' in s
s = s.replace('displayVersion: "86"', 'displayVersion: "87"')
s = s.replace('bundleVersion: "86"', 'bundleVersion: "87"')
p.write_text(s)
