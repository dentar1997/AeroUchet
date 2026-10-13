import SwiftUI
import Combine
import Foundation
import UIKit
import UniformTypeIdentifiers

// Элементы карточки задания на полёт (свайп-удаление, расчётное время, поле ввода).
// Вынесены из AppViews.swift 13.10 без изменений; доступ сделан внутренним для соседнего файла.


struct SwipeDeleteFlightCard<Content: View>: View {
    let isEnabled: Bool
    let onDelete: () -> Void
    let content: () -> Content

    @State private var horizontalOffset: CGFloat = 0

    init(
        isEnabled: Bool,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEnabled = isEnabled
        self.onDelete = onDelete
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if isEnabled {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalOffset = 0
                    }
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .accessibilityLabel("Удалить рейс")
            }

            content()
                .offset(x: horizontalOffset)
        }
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    guard isEnabled else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        return
                    }
                    guard value.translation.width < 0 else {
                        horizontalOffset = 0
                        return
                    }
                    horizontalOffset = max(-66, value.translation.width)
                }
                .onEnded { value in
                    guard isEnabled else {
                        horizontalOffset = 0
                        return
                    }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        withAnimation(.easeOut(duration: 0.16)) {
                            horizontalOffset = 0
                        }
                        return
                    }

                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalOffset = value.translation.width < -30 ? -62 : 0
                    }
                }
        )
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                horizontalOffset = 0
            }
        }
    }
}


struct InlineCalculatedTimeValue: View {
    let displayed: String
    let originalMinutes: Int
    @Binding var minutes: Int
    let isEditing: Bool
    let isActive: Bool
    let isUnscheduled: Bool
    let usesTable: Bool
    let hasChanges: Bool
    let sourceHasChanges: Bool
    let onActivate: () -> Void
    let onToggleSource: () -> Void
    let onRestore: () -> Void

    @State private var activePart: Part?
    private enum Part { case hour, minute }

    private var hour: Int { minutes / 60 }
    private var minute: Int { minutes % 60 }

    private var sourceColor: Color {
        sourceHasChanges ? DutyEditPalette.changed : Color.accentColor
    }

    private var displayedClockParts: (hour: String, minute: String)? {
        let parts = displayed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("Расчётное время")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if !isEditing {
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
                } else {
                    Text(displayed)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(height: 18)
                }
            } else if usesTable {
                Button {
                    activePart = nil
                    onToggleSource()
                } label: {
                    ZStack {
                        Text("Из таблицы")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack(spacing: 0) {
                            Image(systemName: "checkmark.square.fill")
                                .font(.system(size: 16))
                                .frame(width: 20)
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundStyle(sourceColor)
                    .frame(width: 130, height: 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Из таблицы")
                .accessibilityValue("Выбрано")
            } else if isUnscheduled {
                timeWheel.frame(height: 18)
            } else {
                ZStack {
                    timeWheel

                    HStack(spacing: 0) {
                        Button {
                            activePart = nil
                            onToggleSource()
                        } label: {
                            Image(systemName: "square")
                                .font(.system(size: 16))
                                .frame(width: 20, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(sourceColor)
                        .accessibilityLabel("Выбрать расчётное время из таблицы")

                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 130, height: 18)
            }
        }
        .frame(width: 130, alignment: .center)
        .padding(.vertical, 6)
        .overlay(alignment: .bottomTrailing) {
            if isEditing && hasChanges {
                Button {
                    activePart = nil
                    onRestore()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.trailing, -7)
                .padding(.bottom, -1)
                .zIndex(10000)
                .highPriorityGesture(
                    TapGesture().onEnded {
                        activePart = nil
                        onRestore()
                    }
                )
                .accessibilityLabel("Вернуть исходное расчётное время")
            }
        }
        .onChange(of: isActive) { _, active in
            if !active { activePart = nil }
        }
        .onChange(of: usesTable) { _, table in
            if table { activePart = nil }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { activePart = nil }
        }
    }

    private var timeWheel: some View {
        HStack(spacing: -1) {
            InlineFlightWheelSegment(
                value: String(format: "%02d", hour),
                previous: String(format: "%02d", max(0, hour - 1)),
                next: String(format: "%02d", hour + 1),
                width: 17, hitWidth: 33, hitOffset: 0, hitHeight: 48,
                isEditing: true,
                isActive: isActive && activePart == .hour,
                valueColor: color(for: .hour),
                onActivate: { onActivate(); activePart = .hour },
                onStep: { minutes = max(0, hour + $0) * 60 + minute },
                canStepPrevious: hour > 0
            )
            Text(":")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
                .frame(width: 5)
            InlineFlightWheelSegment(
                value: String(format: "%02d", minute),
                previous: String(format: "%02d", (minute + 59) % 60),
                next: String(format: "%02d", (minute + 1) % 60),
                width: 17, hitWidth: 38, hitOffset: 13, hitHeight: 48,
                isEditing: true,
                isActive: isActive && activePart == .minute,
                valueColor: color(for: .minute),
                onActivate: { onActivate(); activePart = .minute },
                onStep: { minutes = hour * 60 + (minute + $0 % 60 + 60) % 60 }
            )
        }
        .frame(width: 37, height: 18)
    }

    private func color(for part: Part) -> Color {
        let changed: Bool
        switch part {
        case .hour: changed = hour != originalMinutes / 60
        case .minute: changed = minute != originalMinutes % 60
        }
        if isActive && activePart == part {
            return changed
                ? DutyEditPalette.selectedChanged
                : Color.accentColor.opacity(0.58)
        }
        return changed ? DutyEditPalette.changed : .accentColor
    }
}

// MARK: - Добавление / редактирование рейса


// MARK: - Ввод с физической клавиатуры

// UITextField уже реализует UIKeyInput. Перехватываем именно текстовый канал
// insertText/deleteBackward: его использует система и для программной, и для
// физической клавиатуры, когда поле является first responder.
private final class AssignmentInputTextField: UITextField {
    var hardwareInputHandler: ((String?, Bool) -> Void)?

    override func insertText(_ text: String) {
        guard let hardwareInputHandler else {
            super.insertText(text)
            return
        }

        hardwareInputHandler(text, false)
    }

    override func deleteBackward() {
        guard let hardwareInputHandler else {
            super.deleteBackward()
            return
        }

        hardwareInputHandler(nil, true)
    }
}

struct InlineSelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    let keyboardType: UIKeyboardType
    let capitalization: UITextAutocapitalizationType
    let textAlignment: NSTextAlignment
    let font: UIFont
    var maxLength: Int? = nil
    var isEnabled: Bool = true
    var restoreValue: String? = nil
    var clearOnFirstDelete = false
    var numbersOnly = false

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isActive: $isActive,
            maxLength: maxLength,
            restoreValue: restoreValue,
            clearOnFirstDelete: clearOnFirstDelete,
            numbersOnly: numbersOnly
        )
    }

    func makeUIView(context: Context) -> UITextField {
        let field = AssignmentInputTextField(frame: .zero)
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .clear
        field.tintColor = .clear
        field.keyboardType = keyboardType
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.autocapitalizationType = capitalization
        field.textAlignment = textAlignment
        field.font = font
        field.adjustsFontForContentSizeCategory = false
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 10.5
        field.isEnabled = isEnabled
        field.isUserInteractionEnabled = isEnabled
        field.delegate = context.coordinator
        field.hardwareInputHandler = { [weak field] characters, deleting in
            guard let field else { return }
            context.coordinator.handleHardwareInput(
                characters,
                deleting: deleting,
                in: field
            )
        }
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isActive = $isActive
        context.coordinator.maxLength = maxLength
        context.coordinator.restoreValue = restoreValue
        context.coordinator.clearOnFirstDelete = clearOnFirstDelete
        context.coordinator.numbersOnly = numbersOnly
        field.font = font
        field.keyboardType = keyboardType
        field.autocapitalizationType = capitalization
        field.isEnabled = isEnabled
        field.isUserInteractionEnabled = isEnabled

        if field.text != text {
            field.text = text
        }

        guard isEnabled else {
            if field.isFirstResponder {
                field.resignFirstResponder()
            }
            return
        }

        if isActive && !field.isFirstResponder {
            DispatchQueue.main.async {
                field.becomeFirstResponder()
                context.coordinator.prepareToReplaceCurrentValue(in: field)
            }
        } else if !isActive && field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isActive: Binding<Bool>
        var maxLength: Int?
        var restoreValue: String?
        var clearOnFirstDelete: Bool
        var numbersOnly: Bool
        private var replaceOnNextInput = false

        init(
            text: Binding<String>,
            isActive: Binding<Bool>,
            maxLength: Int?,
            restoreValue: String?,
            clearOnFirstDelete: Bool,
            numbersOnly: Bool
        ) {
            self.text = text
            self.isActive = isActive
            self.maxLength = maxLength
            self.restoreValue = restoreValue
            self.clearOnFirstDelete = clearOnFirstDelete
            self.numbersOnly = numbersOnly
        }

        func prepareToReplaceCurrentValue(in textField: UITextField) {
            replaceOnNextInput = true
            moveCaretToEnd(in: textField)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isActive.wrappedValue = true
            prepareToReplaceCurrentValue(in: textField)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            replaceOnNextInput = false
            if Self.isCoveredByPresentation(textField) {
                // Системное окно (импорт файлов и т.п.) временно забрало фокус.
                // Сохраняем активность ячейки и возвращаем first responder
                // после закрытия окна, иначе физическая клавиатура «теряется».
                restoreFocusAfterPresentation(of: textField)
                return
            }
            isActive.wrappedValue = false
        }

        private static func isCoveredByPresentation(_ field: UITextField) -> Bool {
            guard let window = field.window else { return false }
            var top = window.rootViewController
            while let next = top?.presentedViewController { top = next }
            guard let topView = top?.viewIfLoaded,
                  top !== window.rootViewController else { return false }
            return !field.isDescendant(of: topView)
        }

        private func restoreFocusAfterPresentation(
            of field: UITextField,
            attempt: Int = 0
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak field] in
                guard let self, let field, self.isActive.wrappedValue,
                      field.window != nil else { return }
                if Self.isCoveredByPresentation(field) {
                    if attempt < 600 {
                        self.restoreFocusAfterPresentation(of: field, attempt: attempt + 1)
                    }
                    return
                }
                if !field.isFirstResponder {
                    field.becomeFirstResponder()
                    self.prepareToReplaceCurrentValue(in: field)
                }
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if replaceOnNextInput {
                replaceOnNextInput = false
                let value = limited(string)
                textField.text = value
                text.wrappedValue = value
                moveCaretToEnd(in: textField)
                return false
            }

            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else {
                return true
            }

            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            let value = limited(candidate)
            if value != candidate {
                textField.text = value
                text.wrappedValue = value
                moveCaretToEnd(in: textField)
                return false
            }

            return true
        }

        @objc func textChanged(_ field: UITextField) {
            let value = limited(field.text ?? "")
            text.wrappedValue = value
            let normalized = text.wrappedValue
            if field.text != normalized {
                field.text = normalized
                moveCaretToEnd(in: field)
            }
        }

        func handleHardwareInput(
            _ characters: String?,
            deleting: Bool,
            in field: UITextField
        ) {
            var value = field.text ?? ""

            if deleting {
                if replaceOnNextInput, clearOnFirstDelete, !value.isEmpty {
                    value = ""
                    replaceOnNextInput = false
                } else {
                    replaceOnNextInput = false
                    if value.isEmpty,
                       let restoreValue,
                       !restoreValue.isEmpty {
                        value = limited(restoreValue)
                        replaceOnNextInput = true
                    } else if !value.isEmpty {
                        value.removeLast()
                    }
                }
            } else if let characters {
                if replaceOnNextInput {
                    value = ""
                    replaceOnNextInput = false
                }
                value.append(contentsOf: characters)
            }

            value = limited(value)
            text.wrappedValue = value
            field.text = text.wrappedValue
            moveCaretToEnd(in: field)
        }

        private func limited(_ value: String) -> String {
            let filtered = numbersOnly
                ? String(value.filter(\.isNumber))
                : value
            guard let maxLength else { return filtered }
            return String(filtered.prefix(maxLength))
        }

        private func moveCaretToEnd(in field: UITextField) {
            DispatchQueue.main.async {
                guard let end = field.endOfDocument as UITextPosition? else { return }
                field.selectedTextRange = field.textRange(from: end, to: end)
            }
        }
    }
}
