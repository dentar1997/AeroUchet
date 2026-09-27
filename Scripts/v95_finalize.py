from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()
start = "    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {\n"
end = "    private func flightKindField(_ leg: FlightLeg, index: Int) -> some View {\n"
i = text.find(start)
j = text.find(end, i)
if i < 0 or j < 0:
    raise SystemExit("flightNumber markers not found")

block = '''    private func flightNumber(_ leg: FlightLeg, index: Int) -> some View {
        let textBinding: Binding<String> = isEditing
            ? legNumberBinding(index)
            : .constant(leg.displayedLegNumber)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.legNumber(index))
            : .constant(false)

        return identityField("Рейс", field: .legNumber(index)) {
            stableInlineEditor(
                text: textBinding,
                isActive: activeBinding,
                field: .legNumber(index),
                keyboardType: .numbersAndPunctuation,
                capitalization: .allCharacters,
                maxLength: 10,
                expands: false,
                allowsEditing: isEditing,
                restoreValue: original.indices.contains(index)
                    ? (original[index].legNumber ?? original[index].flightNumber)
                    : leg.displayedLegNumber,
                clearOnFirstDelete: true
            )
        }
    }

'''

path.write_text(text[:i] + block + text[j:])
