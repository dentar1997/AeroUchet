from pathlib import Path

p = Path("AppViews.swift")
s = p.read_text()

old = '''            // Три временные колонки по 176 pt + промежутки + внутренние
            // отступы leg и задания дают компактную ширину около 600 pt.
            let width = min(geometry.size.width * 0.92, 600)'''
new = '''            // Ширина задания ориентирована на естественную ширину
            // верхней строки из пяти компактных полей leg.
            let width = min(geometry.size.width * 0.92, 556)'''
assert old in s, "overlay width block not found"
s = s.replace(old, new, 1)

old = '''    private let timeColumns = Array(
        repeating: GridItem(.fixed(176), spacing: 8),
        count: 3
    )'''
new = '''    private let timeColumns = Array(
        repeating: GridItem(.fixed(160), spacing: 8),
        count: 3
    )'''
assert old in s, "timeColumns block not found"
s = s.replace(old, new, 1)

old = '''    private func assignmentHeader(_ duty: FlightDuty) -> some View {
        ZStack {
            dutyTitle(
                isEditing && isValid
                ? FlightDuty(id: duty.id, legs: updatedLegs)
                : duty
            )
            .padding(.horizontal, 180)

            HStack(spacing: 8) {
                Button(action: close) {
                    Image(systemName: "xmark.circle")
                }
                .accessibilityLabel("Закрыть задание")

                Spacer()

                if isEditing {
                    Button {
                        restoreEdit(at: historyIndex - 1)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(historyIndex == 0)
                    .accessibilityLabel("Отменить последнее изменение")

                    Button {
                        restoreEdit(at: historyIndex + 1)
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(historyIndex + 1 >= editHistory.count)
                    .accessibilityLabel("Повторить изменение")

                    Button {
                        focusedField = nil
                        showReview = true
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isValid || differences.isEmpty)
                    .accessibilityLabel("Применить изменения")

                    Button {
                        focusedField = nil
                        isEditing = false
                        draft = []
                        original = []
                        editHistory = []
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Отменить все изменения")
                } else {
                    Button {
                        original = duty.legs
                        draft = duty.legs
                        assignmentNumber = duty.firstLeg.assignmentNumber ?? ""
                        editHistory = [
                            DutyEditSnapshot(
                                legs: draft,
                                assignment: assignmentNumber
                            )
                        ]
                        historyIndex = 0
                        isEditing = true
                    } label: {
                        Image(systemName: "wrench")
                    }
                    .accessibilityLabel("Редактировать задание на полёт")

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить задание на полёт")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
    }'''
new = '''    private func assignmentHeader(_ duty: FlightDuty) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                if isEditing {
                    Button {
                        restoreEdit(at: historyIndex - 1)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(historyIndex == 0)
                    .accessibilityLabel("Отменить последнее изменение")

                    Button {
                        restoreEdit(at: historyIndex + 1)
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(historyIndex + 1 >= editHistory.count)
                    .accessibilityLabel("Повторить изменение")
                }
            }
            .frame(width: 104, alignment: .leading)

            dutyTitle(
                isEditing && isValid
                ? FlightDuty(id: duty.id, legs: updatedLegs)
                : duty
            )
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                if isEditing {
                    Button {
                        focusedField = nil
                        showReview = true
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isValid || differences.isEmpty)
                    .accessibilityLabel("Применить изменения")

                    Button {
                        focusedField = nil
                        isEditing = false
                        draft = []
                        original = []
                        editHistory = []
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Отменить все изменения")
                } else {
                    Button {
                        original = duty.legs
                        draft = duty.legs
                        assignmentNumber = duty.firstLeg.assignmentNumber ?? ""
                        editHistory = [
                            DutyEditSnapshot(
                                legs: draft,
                                assignment: assignmentNumber
                            )
                        ]
                        historyIndex = 0
                        isEditing = true
                    } label: {
                        Image(systemName: "wrench")
                    }
                    .accessibilityLabel("Редактировать задание на полёт")

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить задание на полёт")
                }
            }
            .frame(width: 104, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
    }'''
assert old in s, "assignmentHeader block not found"
s = s.replace(old, new, 1)

old = '''                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(value)'''
new = '''                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)'''
assert old in s, "time title scaling block not found"
s = s.replace(old, new, 1)

p.write_text(s)

p = Path("AppVersion.swift")
s = p.read_text()
assert "static let number = 88" in s
assert 'static let label = "Версия 88"' in s
s = s.replace("static let number = 88", "static let number = 89")
s = s.replace('static let label = "Версия 88"', 'static let label = "Версия 89"')
p.write_text(s)

p = Path("Package.swift")
s = p.read_text()
assert 'displayVersion: "88"' in s
assert 'bundleVersion: "88"' in s
s = s.replace('displayVersion: "88"', 'displayVersion: "89"')
s = s.replace('bundleVersion: "88"', 'bundleVersion: "89"')
p.write_text(s)
