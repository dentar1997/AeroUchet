from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()

old = '''            assignmentHeader(current)\n                .padding(.horizontal, 16)\n                .padding(.top, 8)'''
new = '''            assignmentHeader(current)\n                .padding(.horizontal, 16)\n                .padding(.top, 8)\n                .zIndex(focusedField == .assignment ? 1000 : 1)'''
if old not in text:
    raise SystemExit("assignment header marker not found")
text = text.replace(old, new, 1)

old = '''            legHeader(leg, index: index)\n\n            // Все исходные точки редактируются на месте. Итоги остаются вычисляемыми.'''
new = '''            legHeader(leg, index: index)\n                .zIndex(headerEditorZIndex(index))\n\n            // Все исходные точки редактируются на месте. Итоги остаются вычисляемыми.'''
if old not in text:
    raise SystemExit("leg header marker not found")
text = text.replace(old, new, 1)

marker = '''    private func legHeader(_ leg: FlightLeg, index: Int) -> some View {'''
insert = '''    private func headerEditorZIndex(_ index: Int) -> Double {\n        switch focusedField {\n        case .legNumber(let value),\n             .route(let value),\n             .flightKind(let value),\n             .aircraft(let value),\n             .registration(let value),\n             .calculatedTime(let value):\n            return value == index ? 1000 : 0\n        default:\n            return 0\n        }\n    }\n\n'''
if marker not in text:
    raise SystemExit("legHeader function marker not found")
text = text.replace(marker, insert + marker, 1)

path.write_text(text)
