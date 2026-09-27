from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()

# 1. Replace the system delete alert with a popover attached to the trash button.
alert_start = text.index('        .alert("Удалить задание на полёт?", isPresented: $showDeleteConfirmation)')
body_end = text.index('\n    }\n\n    private func assignmentHeader', alert_start)
text = text[:alert_start] + text[body_end:]

trash_old = '''                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityLabel("Удалить задание на полёт")
'''
trash_new = '''                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityLabel("Удалить задание на полёт")
                    .popover(isPresented: $showDeleteConfirmation, arrowEdge: .top) {
                        VStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                            Text("Удалить задание на полёт?")
                                .font(.headline)
                            Text("Задание и \\(legCountText(duty.legs.count)) будут удалены.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 10) {
                                Button("Отмена") {
                                    showDeleteConfirmation = false
                                }
                                .buttonStyle(.bordered)

                                Button("Удалить") {
                                    showDeleteConfirmation = false
                                    store.deleteDutyLegs(ids: Set(duty.legs.map(\\.id)))
                                    close()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }
                        }
                        .padding(16)
                        .frame(width: 260)
                        .font(.subheadline)
                        .presentationCompactAdaptation(.popover)
                    }
'''
assert trash_old in text
text = text.replace(trash_old, trash_new, 1)

# 2. Separate source-change coloring from manual time edits.
call_old = '''            hasChanges: calculatedEditorHasChanges(index),
            onActivate: { focusedField = .calculatedTime(index) },
'''
call_new = '''            hasChanges: calculatedEditorHasChanges(index),
            sourceHasChanges: calculatedSourceHasChanges(index),
            onActivate: { focusedField = .calculatedTime(index) },
'''
assert call_old in text
text = text.replace(call_old, call_new, 1)

insert_at = text.index('    private func restoreOriginalCalculatedTime')
source_helper = '''    private func calculatedSourceHasChanges(_ index: Int) -> Bool {
        guard draft.indices.contains(index), original.indices.contains(index) else {
            return false
        }

        let originalUsesTable = original[index].calculatedMinutesOverride == nil
        let currentUsesTable = draft[index].calculatedMinutesOverride == nil
        return originalUsesTable != currentUsesTable
    }

'''
text = text[:insert_at] + source_helper + text[insert_at:]

struct_start = text.index('private struct InlineCalculatedTimeValue: View {')
struct_end = text.index('\nprivate struct DutyEditSnapshot', struct_start)
segment = text[struct_start:struct_end]

segment = segment.replace(
    '    let hasChanges: Bool\n    let onActivate: () -> Void\n',
    '    let hasChanges: Bool\n    let sourceHasChanges: Bool\n    let onActivate: () -> Void\n',
    1,
)
segment = segment.replace(
    '    private var sourceColor: Color {\n        hasChanges ? DutyEditPalette.changed : Color.accentColor\n    }\n',
    '    private var sourceColor: Color {\n        sourceHasChanges ? DutyEditPalette.changed : Color.accentColor\n    }\n\n'
    '    private var displayedClockParts: (hour: String, minute: String)? {\n'
    '        let parts = displayed.split(separator: ":", omittingEmptySubsequences: false)\n'
    '        guard parts.count == 2 else { return nil }\n'
    '        return (String(parts[0]), String(parts[1]))\n'
    '    }\n',
    1,
)

# 3. Make the static calculated time and the editing wheel geometrically identical
# to the clock in the Takeoff cell: 17 + colon 5 + 17, spacing -1 => width 37.
static_start = segment.index('            if !isEditing {')
static_end = segment.index('            } else if usesTable {', static_start)
static_new = '''            if !isEditing {
                if let parts = displayedClockParts {
                    HStack(spacing: -1) {
                        Text(parts.hour)
                            .frame(width: 17, height: 18)
                        Text(":")
                            .font(.caption.bold())
                            .frame(width: 5)
                        Text(parts.minute)
                            .frame(width: 17, height: 18)
                    }
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: 37, height: 18)
'''
static_new += '''                } else {
                    Text(displayed)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(height: 18)
                }
'''
segment = segment[:static_start] + static_new + segment[static_end:]
segment = segment.replace(
    '                width: 19, hitWidth: 33, hitOffset: 0, hitHeight: 48,',
    '                width: 17, hitWidth: 33, hitOffset: 0, hitHeight: 48,',
    1,
)
segment = segment.replace(
    '        .frame(width: 41, height: 18)',
    '        .frame(width: 37, height: 18)',
    1,
)

text = text[:struct_start] + segment + text[struct_end:]
path.write_text(text)

Path("AppVersion.swift").write_text(
    'enum AppVersion {\n'
    '    static let number = 113\n'
    '    static let label = "Версия 113"\n'
    '}\n'
)

# Fail early if any requested invariant is missing.
result = path.read_text()
assert '.alert("Удалить задание на полёт?"' not in result
assert 'sourceHasChanges: calculatedSourceHasChanges(index)' in result
assert 'private func calculatedSourceHasChanges' in result
assert 'sourceHasChanges ? DutyEditPalette.changed : Color.accentColor' in result
assert 'width: 17, hitWidth: 33' in result
assert '.frame(width: 37, height: 18)' in result
assert '.popover(isPresented: $showDeleteConfirmation' in result
