from pathlib import Path
import re

path = Path('AppViews.swift')
text = path.read_text()
original = text

def replace_once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    text = text.replace(old, new, 1)

replace_once(
'''    @State private var scrollOffset: CGFloat = 0
    @State private var scrollContentIsScrollable = false
    @State private var dismissEditorSignal = 0
''',
'''    @State private var scrollIsAtTop = true
    @State private var scrollContentIsScrollable = false
    @State private var dragSessionActive = false
    @State private var dragSessionEligible = false
    @State private var dismissEditorSignal = 0
''',
'scroll state'
)

replace_once(
'''                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, newValue in
                    scrollOffset = newValue
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height + 1
                } action: { _, newValue in
                    scrollContentIsScrollable = newValue
                }
''',
'''                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top <= 0.5
                } action: { _, newValue in
                    scrollIsAtTop = newValue
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height + 1
                } action: { _, newValue in
                    scrollContentIsScrollable = newValue
                }
''',
'scroll geometry'
)

replace_once(
'''                    dismissDrag(
                        in: geometry.size.height,
                        enabled: !editorIsActive
                            && !editModeIsActive
                            && scrollOffset <= 0.5,
                        allowUpwardRubberBand: !scrollContentIsScrollable
                    )
''',
'''                    dismissDrag(
                        in: geometry.size.height,
                        canStart: !editorIsActive
                            && !editModeIsActive
                            && scrollIsAtTop,
                        allowUpwardRubberBand: !scrollContentIsScrollable
                    )
''',
'dismiss call'
)

pattern = re.compile(r'''    private func dismissDrag\(\n        in height: CGFloat,\n        enabled: Bool,\n        allowUpwardRubberBand: Bool\n    \) -> some Gesture \{.*?\n    \}\n\n    private func interactiveOffset\(''', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('dismissDrag function not found')
new_func = '''    private func dismissDrag(
        in height: CGFloat,
        canStart: Bool,
        allowUpwardRubberBand: Bool
    ) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($gestureDragOffset) { value, state, transaction in
                guard dragSessionEligible else {
                    state = 0
                    return
                }

                transaction.animation = nil
                state = interactiveOffset(
                    for: value.translation.height,
                    allowUpwardRubberBand: allowUpwardRubberBand
                )
            }
            .onChanged { value in
                guard !dragSessionActive else { return }
                dragSessionActive = true
                dragSessionEligible = canStart
                    && (allowUpwardRubberBand || value.translation.height > 0)
            }
            .onEnded { value in
                let eligible = dragSessionEligible
                dragSessionActive = false
                dragSessionEligible = false

                guard eligible else {
                    settledDragOffset = 0
                    return
                }

                let releasedOffset = interactiveOffset(
                    for: value.translation.height,
                    allowUpwardRubberBand: allowUpwardRubberBand
                )
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    settledDragOffset = releasedOffset
                }

                let predicted = max(
                    value.translation.height,
                    value.predictedEndTranslation.height
                )
                let shouldClose =
                    value.translation.height > 110
                    || predicted > 220

                if shouldClose {
                    withAnimation(
                        .spring(response: 0.34, dampingFraction: 0.92)
                    ) {
                        settledDragOffset = max(height + 80, 580)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                        onClose()
                    }
                } else {
                    withAnimation(
                        .spring(response: 0.42, dampingFraction: 0.88)
                    ) {
                        settledDragOffset = 0
                    }
                }
            }
    }

    private func interactiveOffset('''
text = text[:match.start()] + new_func + text[match.end():]

# Text shown when no norm/table value exists.
text = text.replace('"Отсутствует"', '"Нет данных"')

replace_once(
'''    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { draft[index].legNumber ?? draft[index].flightNumber },
            set: { draft[index].legNumber = $0.isEmpty ? nil : $0 }
        )
    }
''',
'''    private func legNumberValue(_ leg: FlightLeg, index: Int) -> String {
        if let legNumber = leg.legNumber {
            return legNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parts = leg.flightNumber
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.indices.contains(index), !parts[index].isEmpty {
            return parts[index]
        }
        return leg.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func legNumberBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { legNumberValue(draft[index], index: index) },
            set: { draft[index].legNumber = String($0.prefix(7)) }
        )
    }
''',
'leg number binding'
)

# Add generic registration binding for legacy alphabetic registrations.
anchor = '''    private func toggleScheduleType(_ index: Int) {
'''
if text.count(anchor) != 1:
    raise SystemExit('toggleScheduleType anchor mismatch')
registration_helpers = '''    private func registrationTextBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { formattedRegistration(draft[index].registration) },
            set: { rawValue in
                let normalized = String(
                    rawValue
                        .uppercased()
                        .filter { character in
                            character.isASCII
                                && (character.isLetter || character.isNumber || character == "-")
                        }
                        .prefix(8)
                )
                draft[index].registration = normalized
            }
        )
    }

    private func registrationComparisonKey(_ rawValue: String) -> String {
        let formatted = formattedRegistration(rawValue)
        if formatted.hasPrefix("RA-") {
            return String(formatted.dropFirst(3))
        }
        return formatted
    }

    private func isNumericRegistration(_ rawValue: String) -> Bool {
        let formatted = formattedRegistration(rawValue)
        guard formatted.hasPrefix("RA-") else { return false }
        let suffix = formatted.dropFirst(3)
        return !suffix.isEmpty && suffix.allSatisfy(\\.isNumber)
    }

'''
text = text.replace(anchor, registration_helpers + anchor, 1)

# Correct change-state comparison for registration.
replace_once(
'''            let before = String(original[index].registration.filter(\\.isNumber).prefix(5))
            let after = String(draft[index].registration.filter(\\.isNumber).prefix(5))
            return before != after
''',
'''            return registrationComparisonKey(draft[index].registration)
                != registrationComparisonKey(original[index].registration)
''',
'registration comparison'
)

# Compare the displayed leg value, not the whole slash-separated assignment string.
replace_once(
'''            let before = original[index].legNumber ?? original[index].flightNumber
            let after = draft[index].legNumber ?? draft[index].flightNumber
            return before != after
''',
'''            let before = legNumberValue(original[index], index: index)
            let after = legNumberValue(draft[index], index: index)
            return before != after
''',
'leg comparison'
)

# Flight editor: own leg only, max 7 symbols, correct restore value.
replace_once(
'''        let textBinding: Binding<String> = isEditing
            ? legNumberBinding(index)
            : .constant(leg.displayedLegNumber)
''',
'''        let textBinding: Binding<String> = isEditing
            ? legNumberBinding(index)
            : .constant(legNumberValue(leg, index: index))
''',
'flight static binding'
)
replace_once('''                maxLength: 10,
''', '''                maxLength: 7,
''', 'flight max length')
replace_once(
'''                restoreValue: original.indices.contains(index)
                    ? (original[index].legNumber ?? original[index].flightNumber)
                    : leg.displayedLegNumber,
''',
'''                restoreValue: original.indices.contains(index)
                    ? legNumberValue(original[index], index: index)
                    : legNumberValue(leg, index: index),
''',
'flight restore'
)

# Legacy alphabetic registrations do not receive an RA- prefix.
reg_pattern = re.compile(r'''    private func registrationField\(_ leg: FlightLeg, index: Int\) -> some View \{.*?\n    \}\n\n    private func stableInlineEditor\(''', re.S)
reg_match = reg_pattern.search(text)
if not reg_match:
    raise SystemExit('registrationField block not found')
reg_func = '''    private func registrationField(_ leg: FlightLeg, index: Int) -> some View {
        let formatted = formattedRegistration(leg.registration)
        let numericRegistration = isNumericRegistration(formatted)
        let activeBinding: Binding<Bool> = isEditing
            ? focusBinding(.registration(index))
            : .constant(false)

        return identityField("Бортовой номер", field: .registration(index)) {
            if numericRegistration {
                let staticDigits = formatted.replacingOccurrences(of: "RA-", with: "")
                stableInlineEditor(
                    text: isEditing
                        ? registrationDigitsBinding(index)
                        : .constant(staticDigits),
                    isActive: activeBinding,
                    field: .registration(index),
                    prefix: "RA-",
                    keyboardType: .numberPad,
                    capitalization: .none,
                    maxLength: 5,
                    expands: false,
                    allowsEditing: isEditing,
                    restoreValue: original.indices.contains(index)
                        ? registrationComparisonKey(original[index].registration)
                        : staticDigits,
                    highlightHorizontalPadding: 0
                )
            } else {
                stableInlineEditor(
                    text: isEditing
                        ? registrationTextBinding(index)
                        : .constant(formatted),
                    isActive: activeBinding,
                    field: .registration(index),
                    keyboardType: .asciiCapable,
                    capitalization: .allCharacters,
                    maxLength: 8,
                    expands: false,
                    allowsEditing: isEditing,
                    restoreValue: original.indices.contains(index)
                        ? formattedRegistration(original[index].registration)
                        : formatted,
                    highlightHorizontalPadding: 0
                )
            }
        }
    }

    private func stableInlineEditor('''
text = text[:reg_match.start()] + reg_func + text[reg_match.end():]

# Route endpoints track their own changed state, not the combined route state.
route_color_old = '''                    isEditing
                        ? editorValueColor(
                            for: .route(index),
                            isActive: isActive.wrappedValue
                        )
                        : Color.primary
'''
route_color_new = '''                    isEditing
                        ? routeValueColor(
                            index: index,
                            side: side,
                            isActive: isActive.wrappedValue
                        )
                        : Color.primary
'''
replace_once(route_color_old, route_color_new, 'route endpoint color')

route_anchor = '''    private func routeCodeBinding(index: Int, side: RouteEditSide) -> Binding<String> {
'''
if text.count(route_anchor) != 1:
    raise SystemExit('route binding anchor mismatch')
route_helpers = '''    private func routeValueColor(
        index: Int,
        side: RouteEditSide,
        isActive: Bool
    ) -> Color {
        if isActive {
            return Color.accentColor.opacity(0.58)
        }
        return routeSideHasChanges(index: index, side: side)
            ? Color.indigo
            : Color.accentColor
    }

    private func routeSideHasChanges(index: Int, side: RouteEditSide) -> Bool {
        guard draft.indices.contains(index), original.indices.contains(index) else {
            return false
        }
        let before = side == .departure
            ? original[index].departure
            : original[index].arrival
        let after = side == .departure
            ? draft[index].departure
            : draft[index].arrival
        return before.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            != after.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

'''
text = text.replace(route_anchor, route_helpers + route_anchor, 1)

if text == original:
    raise SystemExit('no changes made')
path.write_text(text)
