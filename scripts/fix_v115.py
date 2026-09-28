from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text(encoding="utf-8")

replacements = {
    "// MARK: - Список смен\n\n// MARK: - Список смен": "// MARK: - Список смен",
    "private struct DutyAssignmentOverlay: View {private struct DutyAssignmentOverlay: View {": "private struct DutyAssignmentOverlay: View {",
    "    private func restCard    private func restCard(start: Date, end: Date) -> some View {": "    private func restCard(start: Date, end: Date) -> some View {",
    'reserveText: "Manual 888"': 'reserveText: "Manual888"',
}

for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f"Expected fragment not found: {old[:80]}")
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
