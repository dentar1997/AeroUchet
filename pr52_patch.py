from pathlib import Path
import re

path = Path('AppViews.swift')
text = path.read_text()

def require(condition, label):
    if not condition:
        raise SystemExit(f'Block not found: {label}')

# Whole assignment card scrolls; no nested scrolling inside the card.
marker = '            let maximumHeight = max(320, geometry.size.height - 40)\n'
require(marker in text, 'maximumHeight marker')
text = text.replace(marker, '', 1)

start = text.find('                ViewThatFits(in: .vertical) {')
end_marker = '                .simultaneousGesture(dismissDrag(in: geometry.size.height))'
require(start >= 0, 'ViewThatFits start')
end = text.find(end_marker, start)
require(end >= 0, 'ViewThatFits end')
end += len(end_marker)

whole_card_scroll = '''                ScrollView(.vertical) {
                    DutyDetailView(
                        duty: duty,
                        onClose: onClose,
                        scrollsAsPage: true
                    )
                    .environmentObject(store)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .offset(y: dragOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(dismissDrag(in: geometry.size.height))'''
text = text[:start] + whole_card_scroll + text[end:]

# Large reliable checkbox target for “Из таблицы”.
toggle_pos = text.find('toggleCalculatedTimeSource(index)')
require(toggle_pos >= 0, 'calculated toggle function call')
calc_start = text.rfind('                        Button {', 0, toggle_pos)
calc_end_marker = '                    }\n                    .padding(.horizontal, 18)'
calc_end = text.find(calc_end_marker, toggle_pos)
require(calc_start >= 0, 'calculated button start')
require(calc_end >= 0, 'calculated controls end')

calc_controls = '''                        Button {
                            toggleCalculatedTimeSource(index)
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color.secondary, lineWidth: 1.2)
                                        .frame(width: 20, height: 20)

                                    if draft[index].calculatedMinutesOverride == nil {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.accentColor)
                                            .frame(width: 20, height: 20)

                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text("Из таблицы")
                            }
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .zIndex(10)

                        if draft[index].calculatedMinutesOverride != nil {
                            DatePicker(
                                "",
                                selection: calculatedTimeBinding(index),
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(width: 160, height: 112)
                            .clipped()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .zIndex(0)
                        } else {
                            Text(
                                draft[index].calculatedMinutes.map(timeText)
                                ?? "Ожидает норму"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        }
'''
text = text[:calc_start] + calc_controls + text[calc_end:]

# Stable calendar geometry.
calendar_old = '''                                .datePickerStyle(.graphical)
                                .frame(width: 302, height: 246, alignment: .topLeading)
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                                .scaleEffect(0.72, anchor: .topLeading)'''
calendar_new = '''                                .datePickerStyle(.graphical)
                                .frame(width: 302, height: 246, alignment: .topLeading)
                                .clipped()
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                                .animation(
                                    nil,
                                    value: point.date(in: times(for: draft[index]))
                                )
                                .scaleEffect(0.72, anchor: .topLeading)'''
require(calendar_old in text, 'calendar geometry')
text = text.replace(calendar_old, calendar_new, 1)

# Fix whole time popover size so it does not shrink after selecting a day.
time_frame_old = '''                    .frame(width: 365)
                    .fixedSize(horizontal: false, vertical: true)'''
require(time_frame_old in text, 'time popover frame')
text = text.replace(time_frame_old, '                    .frame(width: 365, height: 230, alignment: .top)', 1)

# Make visible editor surfaces match the 10pt rounded time cards.
pattern = re.compile(r'(?m)^(\s*)\.presentationCornerRadius\(10\)$')
matches = list(pattern.finditer(text))
require(len(matches) >= 4, 'popover corner modifiers')

def card_surface(match):
    i = match.group(1)
    return (
        f'{i}.background(\n'
        f'{i}    RoundedRectangle(cornerRadius: 10, style: .continuous)\n'
        f'{i}        .fill(Color(uiColor: .secondarySystemGroupedBackground))\n'
        f'{i})\n'
        f'{i}.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))\n'
        f'{i}.presentationBackground(.clear)'
    )

text = pattern.sub(card_surface, text)
path.write_text(text)

# Remove accidental temporary files; not part of the app.
for filename in ['.github/ignore', 'foo', 'bar', 'baz', 'oops', 'x', 'y', 'z', 'w']:
    p = Path(filename)
    if p.exists():
        p.unlink()
