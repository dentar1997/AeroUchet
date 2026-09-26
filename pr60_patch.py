from pathlib import Path
import re

path = Path('AppViews.swift')
text = path.read_text()

def once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    text = text.replace(old, new, 1)

once(
'''        .overlay(alignment: .top) {
            activeTimeEditor
                .zIndex(10_000)
        }
''',
'',
'remove global time editor overlay'
)

once(
'''    private func assignmentContents(_ duty: FlightDuty) -> some View {
        dutyCard(isEditing && isValid
                 ? FlightDuty(id: duty.id, legs: updatedLegs)
                 : duty)
            .padding(16)
            .frame(maxWidth: .infinity)
    }
''',
'''    private func assignmentContents(_ duty: FlightDuty) -> some View {
        dutyCard(isEditing && isValid
                 ? FlightDuty(id: duty.id, legs: updatedLegs)
                 : duty)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if case .time = focusedField {
                            focusedField = nil
                        }
                    }
            }
    }
''',
'dismiss time editor on free area'
)

once(
'''        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func headerEditorZIndex''',
'''        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            activeTimeEditor(for: index)
                .zIndex(10_000)
        }
    }

    private func headerEditorZIndex''',
'anchor time editor to leg card'
)

pattern = re.compile(r'''    @ViewBuilder\n    private var activeTimeEditor: some View \{.*?\n    \}\n\n    private func legValueCard\(''', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('active time editor block not found')
new_editor = '''    @ViewBuilder
    private func activeTimeEditor(for legIndex: Int) -> some View {
        if case let .time(index, point) = focusedField,
           index == legIndex,
           draft.indices.contains(index) {
            floatingEditor(width: 380, height: 282) {
                VStack(alignment: .leading, spacing: 6) {
                    editPopoverHeader(point.title, extraHorizontalInset: 0)

                    HStack(alignment: .top, spacing: 12) {
                        ZStack(alignment: .topLeading) {
                            DatePicker(
                                "",
                                selection: timeBinding(index, point),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                            .frame(width: 302, height: 330, alignment: .topLeading)
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                            .animation(
                                nil,
                                value: point.date(in: times(for: draft[index]))
                            )
                            .scaleEffect(0.68, anchor: .topLeading)
                        }
                        .frame(width: 206, height: 225, alignment: .topLeading)
                        .clipped()
                        .contentShape(Rectangle())

                        DatePicker(
                            "",
                            selection: timeBinding(index, point),
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(width: 130, height: 288)
                        .scaleEffect(0.78, anchor: .topLeading)
                        .frame(width: 102, height: 225, alignment: .topLeading)
                        .clipped()
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: timeEditorAlignment(for: point))
            .padding(.horizontal, 18)
            .offset(y: legIndex == 0 ? 58 : -290)
        }
    }

    private func legValueCard('''
text = text[:match.start()] + new_editor + text[match.end():]

once(
'''                        font: .boldSystemFont(ofSize: 22)
                    )
                    .frame(width: 112, height: 30)
                }
                .frame(height: 30, alignment: .center)''',
'''                        font: .boldSystemFont(ofSize: 20)
                    )
                    .frame(width: 104, height: 28)
                }
                .frame(height: 28, alignment: .center)''',
'shrink assignment edit title'
)

once(
'''        .font(.title2.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
    }

    private func legCountText''',
'''        .font(.title3.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
    }

    private func legCountText''',
'shrink assignment title'
)

once(
'''        field.adjustsFontForContentSizeCategory = false
        field.delegate = context.coordinator
''',
'''        field.adjustsFontForContentSizeCategory = false
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 10.5
        field.delegate = context.coordinator
''',
'match inline field scaling'
)

path.write_text(text)

version = Path('AppVersion.swift')
v = version.read_text().replace('static let number = 59', 'static let number = 60').replace('static let label = "Версия 59"', 'static let label = "Версия 60"')
version.write_text(v)

package = Path('Package.swift')
p = package.read_text().replace('displayVersion: "59"', 'displayVersion: "60"').replace('bundleVersion: "59"', 'bundleVersion: "60"')
package.write_text(p)
