from pathlib import Path

path = Path('AppViews.swift')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    '''            content()\n                .font(.subheadline.weight(.semibold))\n                .foregroundStyle(.primary)\n                .lineLimit(1)\n                .minimumScaleFactor(0.7)\n                .frame(height: 22, alignment: .center)\n''',
    '''            content()\n                .font(.system(size: 15, weight: .semibold))\n                .foregroundStyle(.primary)\n                .lineLimit(1)\n                .minimumScaleFactor(0.7)\n                .frame(height: 18, alignment: .center)\n''',
    'identity value size',
)

old_inline = '                .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)'
if text.count(old_inline) != 2:
    raise SystemExit(f'inline field size: expected 2 matches, found {text.count(old_inline)}')
text = text.replace(
    old_inline,
    '                .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)',
)

replace_once(
    '                    .frame(width: 58, height: 22)\n',
    '                    .frame(width: 58, height: 18)\n',
    'registration field height',
)

replace_once(
    '''            Text(value)\n                .font(.subheadline.weight(.semibold))\n                .foregroundStyle(.primary)\n                .minimumScaleFactor(0.85)\n''',
    '''            Text(value)\n                .font(.system(size: 15, weight: .semibold))\n                .foregroundStyle(.primary)\n                .minimumScaleFactor(0.85)\n                .frame(height: 18, alignment: .leading)\n''',
    'time card value size',
)

replace_once(
    '''        field.font = font\n        field.adjustsFontForContentSizeCategory = true\n''',
    '''        field.font = font\n        field.adjustsFontForContentSizeCategory = false\n''',
    'disable dynamic inline font resize',
)

replace_once(
    '''        context.coordinator.maxLength = maxLength\n\n        if field.text != text && !field.isFirstResponder {\n''',
    '''        context.coordinator.maxLength = maxLength\n        field.font = font\n\n        if field.text != text && !field.isFirstResponder {\n''',
    'keep inline font stable',
)

replace_once(
    '''        .overlay(\n            RoundedRectangle(cornerRadius: 20)\n                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)\n        )\n        .clipShape(RoundedRectangle(cornerRadius: 20))\n''',
    '''        .overlay(\n            RoundedRectangle(cornerRadius: 20)\n                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)\n        )\n        .overlay(alignment: .top) {\n            activeTimeEditor\n                .zIndex(10_000)\n        }\n        .clipShape(RoundedRectangle(cornerRadius: 20))\n''',
    'root time editor overlay',
)

replace_once(
    '''    private func timeEditorVerticalOffset(for point: DutyEditPoint) -> CGFloat {\n        switch point {\n        case .workStart, .engineOn, .takeoff:\n            return -205\n        case .workEnd, .engineOff, .landing:\n            return -226\n        }\n    }\n\n''',
    '',
    'remove cell-relative time offset',
)

replace_once(
    '''    private func timeEditorZIndex(_ index: Int, _ point: DutyEditPoint) -> Double {\n        focusedField == .time(index, point) ? 4000 : 0\n    }\n\n''',
    '',
    'remove time cell z index helper',
)

for point in ['workStart', 'engineOn', 'takeoff', 'workEnd', 'engineOff', 'landing']:
    line = f'                .zIndex(timeEditorZIndex(index, .{point}))\n'
    if text.count(line) != 1:
        raise SystemExit(f'z-index line expected once: {point}')
    text = text.replace(line, '', 1)

start = text.index('    private func timeCell(\n')
end = text.index('    private func legValueCard(\n', start)
new_block = '''    private func timeCell(\n        title: String,\n        value: String,\n        index: Int,\n        point: DutyEditPoint?\n    ) -> some View {\n        Group {\n            if isEditing, let point {\n                Button {\n                    focusedField = .time(index, point)\n                } label: {\n                    legValueCard(title: title, value: formatDateTime(\n                        point.date(in: times(for: draft[index]))\n                    ))\n                    .overlay(\n                        RoundedRectangle(cornerRadius: 10)\n                            .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)\n                    )\n                }\n                .buttonStyle(.plain)\n            } else {\n                legValueCard(title: title, value: value)\n            }\n        }\n    }\n\n    @ViewBuilder\n    private var activeTimeEditor: some View {\n        if case let .time(index, point) = focusedField,\n           draft.indices.contains(index) {\n            floatingEditor(width: 380, height: 282) {\n                VStack(alignment: .leading, spacing: 6) {\n                    editPopoverHeader(point.title, extraHorizontalInset: 0)\n\n                    HStack(alignment: .top, spacing: 12) {\n                        ZStack(alignment: .topLeading) {\n                            DatePicker(\n                                "",\n                                selection: timeBinding(index, point),\n                                displayedComponents: [.date]\n                            )\n                            .labelsHidden()\n                            .datePickerStyle(.graphical)\n                            .frame(width: 302, height: 330, alignment: .topLeading)\n                            .transaction { transaction in\n                                transaction.animation = nil\n                            }\n                            .animation(\n                                nil,\n                                value: point.date(in: times(for: draft[index]))\n                            )\n                            .scaleEffect(0.68, anchor: .topLeading)\n                        }\n                        .frame(width: 206, height: 225, alignment: .topLeading)\n                        .clipped()\n                        .contentShape(Rectangle())\n\n                        DatePicker(\n                            "",\n                            selection: timeBinding(index, point),\n                            displayedComponents: [.hourAndMinute]\n                        )\n                        .labelsHidden()\n                        .datePickerStyle(.wheel)\n                        .frame(width: 130, height: 288)\n                        .scaleEffect(0.78, anchor: .topLeading)\n                        .frame(width: 102, height: 225, alignment: .topLeading)\n                        .clipped()\n                        .contentShape(Rectangle())\n                    }\n                    .frame(maxWidth: .infinity, alignment: .center)\n                }\n            }\n            .frame(maxWidth: .infinity, alignment: timeEditorAlignment(for: point))\n            .padding(.horizontal, 18)\n            .padding(.top, 52)\n        }\n    }\n\n'''
text = text[:start] + new_block + text[end:]

path.write_text(text)
