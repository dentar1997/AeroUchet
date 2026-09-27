from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 occurrence, found {count}")
    text = text.replace(old, new, 1)


replace_once(
    '''    @State private var editorIsActive = false
    @State private var editModeIsActive = false
    @State private var dismissEditorSignal = 0
''',
    '''    @State private var editorIsActive = false
    @State private var editModeIsActive = false
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollContentIsScrollable = false
    @State private var dismissEditorSignal = 0
''',
    "scroll state"
)

replace_once(
    '''                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(editorIsActive)
''',
    '''                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, newValue in
                    scrollOffset = newValue
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height + 1
                } action: { _, newValue in
                    scrollContentIsScrollable = newValue
                }
                .scrollDisabled(editorIsActive)
''',
    "scroll geometry"
)

replace_once(
    '''                    dismissDrag(
                        in: geometry.size.height,
                        enabled: !editorIsActive && !editModeIsActive
                    )
''',
    '''                    dismissDrag(
                        in: geometry.size.height,
                        enabled: !editorIsActive
                            && !editModeIsActive
                            && scrollOffset <= 0.5,
                        allowUpwardRubberBand: !scrollContentIsScrollable
                    )
''',
    "dismiss gesture call"
)

replace_once(
    '''    private func dismissDrag(in height: CGFloat, enabled: Bool) -> some Gesture {
''',
    '''    private func dismissDrag(
        in height: CGFloat,
        enabled: Bool,
        allowUpwardRubberBand: Bool
    ) -> some Gesture {
''',
    "dismiss gesture signature"
)

replace_once(
    '''                state = interactiveOffset(for: value.translation.height)
''',
    '''                state = interactiveOffset(
                    for: value.translation.height,
                    allowUpwardRubberBand: allowUpwardRubberBand
                )
''',
    "drag updating offset"
)

replace_once(
    '''                let releasedOffset = interactiveOffset(for: value.translation.height)
''',
    '''                let releasedOffset = interactiveOffset(
                    for: value.translation.height,
                    allowUpwardRubberBand: allowUpwardRubberBand
                )
''',
    "drag released offset"
)

replace_once(
    '''    private func interactiveOffset(for translation: CGFloat) -> CGFloat {
        translation >= 0 ? translation : upwardRubberBand(translation)
    }
''',
    '''    private func interactiveOffset(
        for translation: CGFloat,
        allowUpwardRubberBand: Bool
    ) -> CGFloat {
        guard translation < 0 else { return translation }
        return allowUpwardRubberBand ? upwardRubberBand(translation) : 0
    }
''',
    "interactive offset"
)

replace_once(
    '''    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { draft[index].legNumber ?? draft[index].flightNumber },
            set: { draft[index].legNumber = $0.isEmpty ? nil : $0 }
        )
    }
''',
    '''    private func editableLegNumber(_ leg: FlightLeg) -> String {
        if let legNumber = leg.legNumber {
            return legNumber
        }
        return leg.displayedLegNumber
    }

    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { editableLegNumber(draft[index]) },
            set: { draft[index].legNumber = $0 }
        )
    }
''',
    "leg binding"
)

replace_once(
    '''        case .legNumber(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            let before = original[index].legNumber ?? original[index].flightNumber
            let after = draft[index].legNumber ?? draft[index].flightNumber
            return before != after
''',
    '''        case .legNumber(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            return editableLegNumber(original[index]) != editableLegNumber(draft[index])
''',
    "leg changed state"
)

replace_once(
    '''        case .registration(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            let before = original[index].registration
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let after = draft[index].registration
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return before != after
''',
    '''        case .registration(let index):
            guard draft.indices.contains(index), original.indices.contains(index) else {
                return false
            }
            let before = String(original[index].registration.filter(\\.isNumber).prefix(5))
            let after = String(draft[index].registration.filter(\\.isNumber).prefix(5))
            return before != after
''',
    "registration changed state"
)

replace_once(
    '''                restoreValue: original.indices.contains(index)
                    ? (original[index].legNumber ?? original[index].flightNumber)
                    : leg.displayedLegNumber,
''',
    '''                restoreValue: original.indices.contains(index)
                    ? editableLegNumber(original[index])
                    : leg.displayedLegNumber,
''',
    "leg restore value"
)

replace_once(
    '''            add("Номер лега", old.legNumber ?? "—", new.legNumber ?? "—")
''',
    '''            add("Номер лега", editableLegNumber(old), editableLegNumber(new))
''',
    "leg differences"
)

path.write_text(text)
