import SwiftUI
import UIKit

// The date and clock stay in the assignment cell while their adjacent values
// appear above and below the selected part, as in the third wheel prototype.
struct InlineFlightDateTimeCell: View {
    let title: String
    @Binding var selection: Date
    let original: Date
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void
    let showsCalendarButton: Bool
    let dateCanToggle: Bool
    let onToggleDate: () -> Void
    let onDismiss: () -> Void
    let backgroundColor: Color

    @State private var activePart: Part?
    @State private var showsCalendar = false

    private enum Part { case date, hour, minute }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing { onDismiss() }
                }

            HStack(spacing: 3) {
                InlineFlightDateSegment(
                    value: dateText(selection),
                    previous: dateText(neighborDate(-1)),
                    next: dateText(neighborDate(1)),
                    valueColor: color(for: .date),
                    isEditing: isEditing,
                    isActive: isActive && activePart == .date && !showsCalendar,
                    canSpin: false,
                    onTap: {
                        guard isEditing else { return }
                        if showsCalendarButton {
                            openCalendar()
                        } else if dateCanToggle {
                            activate(.date)
                            onToggleDate()
                        }
                    },
                    onStep: { delta in
                        if let updated = calendar.date(byAdding: .day, value: delta, to: selection) {
                            selection = updated
                        }
                    }
                )

                HStack(spacing: -1) {
                    InlineFlightWheelSegment(
                        value: twoDigits(hour),
                        previous: twoDigits(wrap(hour - 1, count: 24)),
                        next: twoDigits(wrap(hour + 1, count: 24)),
                        width: 17,
                        hitWidth: 22,
                        hitOffset: 1,
                        isEditing: isEditing,
                        isActive: isActive && activePart == .hour,
                        valueColor: color(for: .hour),
                        onActivate: { activate(.hour) },
                        onStep: { delta in
                            setClock(
                                hour: wrap(hour + delta, count: 24),
                                minute: minute
                            )
                        }
                    )

                    Text(":")
                        .font(.caption.bold())
                        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                        .frame(width: 5)

                    InlineFlightWheelSegment(
                        value: twoDigits(minute),
                        previous: twoDigits(wrap(minute - 1, count: 60)),
                        next: twoDigits(wrap(minute + 1, count: 60)),
                        width: 17,
                        hitWidth: 30,
                        hitOffset: 7,
                        isEditing: isEditing,
                        isActive: isActive && activePart == .minute,
                        valueColor: color(for: .minute),
                        onActivate: { activate(.minute) },
                        onStep: { delta in
                            setClock(
                                hour: hour,
                                minute: wrap(minute + delta, count: 60)
                            )
                        }
                    )
                }
                .frame(width: 37, height: 18, alignment: .leading)
            }
            .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    if isEditing { onDismiss() }
                }
        )
        .overlay(alignment: .bottomTrailing) {
            if isEditing && isActive {
                VStack(spacing: 3) {
                    if showsCalendarButton {
                        Button {
                            openCalendar()
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 17, height: 17)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showsCalendar, arrowEdge: .top) {
                            DatePicker("Дата", selection: calendarSelection, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .frame(width: 278, height: 292)
                                .padding(8)
                                .presentationCompactAdaptation(.popover)
                        }
                        .accessibilityLabel("Открыть календарь")
                    }

                    Button {
                        selection = original
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 17, height: 17)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(selection == original)
                    .accessibilityLabel("Вернуть исходные дату и время")
                }
                .foregroundStyle(Color.accentColor)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            }
        }
        .onChange(of: isActive) { _, active in
            if !active {
                activePart = nil
                showsCalendar = false
            }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing {
                activePart = nil
                showsCalendar = false
            }
        }
    }

    private var hour: Int { calendar.component(.hour, from: selection) }
    private var minute: Int { calendar.component(.minute, from: selection) }

    private func color(for part: Part) -> Color {
        guard isEditing else { return .primary }
        if part == .date && showsCalendar {
            return Color(red: 0.0, green: 0.36, blue: 0.39)
        }
        if isActive && activePart == part {
            return Color.accentColor.opacity(0.58)
        }
        if hasChanged(part) {
            return .indigo
        }
        return .accentColor
    }

    private func hasChanged(_ part: Part) -> Bool {
        switch part {
        case .date:
            return !calendar.isDate(selection, inSameDayAs: original)
        case .hour:
            return hour != calendar.component(.hour, from: original)
        case .minute:
            return minute != calendar.component(.minute, from: original)
        }
    }

    private func neighborDate(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: selection) ?? selection
    }

    private func activate(_ part: Part) {
        guard isEditing else { return }
        if part != .date { showsCalendar = false }
        onActivate()
        activePart = part
    }

    private func openCalendar() {
        guard isEditing else { return }
        onActivate()
        activePart = .date
        showsCalendar = true
    }

    private func setClock(hour: Int, minute: Int) {
        var parts = calendar.dateComponents([.year, .month, .day], from: selection)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        if let date = calendar.date(from: parts) { selection = date }
    }

    private var calendarSelection: Binding<Date> {
        Binding(
            get: { selection },
            set: { date in
                var parts = calendar.dateComponents([.year, .month, .day], from: date)
                parts.hour = hour
                parts.minute = minute
                parts.second = 0
                if let updated = calendar.date(from: parts) { selection = updated }
                showsCalendar = false
                activePart = nil
            }
        )
    }

    private func dateText(_ date: Date) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        return String(format: "%02d.%02d.%04d", parts.day ?? 1, parts.month ?? 1, parts.year ?? 2000)
    }

    private func twoDigits(_ number: Int) -> String { String(format: "%02d", number) }

    private func wrap(_ value: Int, count: Int) -> Int {
        (value % count + count) % count
    }
}

private struct InlineFlightDateSegment: View {
    let value: String
    let previous: String
    let next: String
    let valueColor: Color
    let isEditing: Bool
    let isActive: Bool
    let canSpin: Bool
    let onTap: () -> Void
    let onStep: (Int) -> Void

    @State private var translation: CGFloat = 0
    @State private var appliedSteps = 0
    @State private var dragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack(alignment: .leading) {
            Text(value)
                .foregroundStyle(valueColor)
                .opacity(isActive && canSpin ? 0 : 1)

            if isActive && canSpin {
                Text(previous)
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .offset(y: -rowHeight + residualOffset)
                    .allowsHitTesting(false)
                Text(value)
                    .foregroundStyle(valueColor)
                    .offset(y: residualOffset)
                    .allowsHitTesting(false)
                Text(next)
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .offset(y: rowHeight + residualOffset)
                    .allowsHitTesting(false)
            }
        }
        .font(.caption.bold())
        .monospacedDigit()
        .frame(width: 67, height: 18, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard isEditing && isActive && canSpin else { return }
                    if !dragging {
                        dragging = true
                        appliedSteps = 0
                    }
                    translation = gesture.translation.height
                    let steps = Int((-translation / rowHeight).rounded())
                    if steps != appliedSteps {
                        onStep(steps - appliedSteps)
                        appliedSteps = steps
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    dragging = false
                    appliedSteps = 0
                    withAnimation(.easeOut(duration: 0.12)) { translation = 0 }
                }
        )
    }

    private var residualOffset: CGFloat {
        guard dragging else { return 0 }
        let steps = Int((-translation / rowHeight).rounded())
        return translation + CGFloat(steps) * rowHeight
    }
}

struct InlineFlightWheelSegment: View {
    let value: String
    let previous: String
    let next: String
    let width: CGFloat
    let hitWidth: CGFloat
    let hitOffset: CGFloat
    let isEditing: Bool
    let isActive: Bool
    let valueColor: Color
    let onActivate: () -> Void
    let onStep: (Int) -> Void
    var canStepPrevious = true

    @State private var translation: CGFloat = 0
    @State private var appliedSteps = 0
    @State private var dragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack(alignment: .leading) {
            Text(value)
                .opacity(isActive ? 0 : 1)

            if isActive {
                if canStepPrevious {
                    Text(previous)
                        .foregroundStyle(Color.primary.opacity(0.76))
                        .offset(y: -rowHeight + residualOffset)
                        .allowsHitTesting(false)
                }
                Text(value)
                    .foregroundStyle(valueColor)
                    .offset(y: residualOffset)
                    .allowsHitTesting(false)
                Text(next)
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .offset(y: rowHeight + residualOffset)
                    .allowsHitTesting(false)
            }
        }
        .font(.caption.bold())
        .monospacedDigit()
        .foregroundStyle(valueColor)
        .frame(width: width, height: 18)
        .overlay {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: hitWidth, height: 38)
                .offset(x: hitOffset)
                .onTapGesture {
                    guard isEditing else { return }
                    onActivate()
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { gesture in
                            guard isEditing && isActive else { return }
                            if !dragging {
                                dragging = true
                                appliedSteps = 0
                            }
                            translation = gesture.translation.height
                            let steps = Int((-translation / rowHeight).rounded())
                            if !canStepPrevious && steps < appliedSteps {
                                translation = -CGFloat(appliedSteps) * rowHeight
                                return
                            }
                            if steps != appliedSteps {
                                onStep(steps - appliedSteps)
                                appliedSteps = steps
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                        .onEnded { _ in
                            dragging = false
                            appliedSteps = 0
                            withAnimation(.easeOut(duration: 0.12)) { translation = 0 }
                        }
                )
        }
    }

    private var residualOffset: CGFloat {
        guard dragging else { return 0 }
        let steps = Int((-translation / rowHeight).rounded())
        return translation + CGFloat(steps) * rowHeight
    }
}
