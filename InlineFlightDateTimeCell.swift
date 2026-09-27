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

    @State private var activePart: Part?
    @State private var showsCalendar = false

    private enum Part { case hour, minute }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(spacing: 3) {
                Text(dateText(selection))
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(
                        isEditing && (showsCalendarButton || dateCanToggle)
                            ? Color.accentColor : Color.primary
                    )
                    .frame(width: 67, height: 18, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isEditing else { return }
                        if showsCalendarButton {
                            onActivate()
                            showsCalendar = true
                        } else if dateCanToggle {
                            onActivate()
                            onToggleDate()
                        }
                    }

                InlineFlightWheelSegment(
                    value: twoDigits(hour),
                    previous: twoDigits(wrap(hour - 1, count: 24)),
                    next: twoDigits(wrap(hour + 1, count: 24)),
                    width: 17,
                    isEditing: isEditing,
                    isActive: isActive && activePart == .hour,
                    onActivate: { activate(.hour) },
                    onStep: { delta in
                        setClock(
                            hour: wrap(calendar.component(.hour, from: selection) + delta, count: 24),
                            minute: calendar.component(.minute, from: selection)
                        )
                    }
                )

                Text(":")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                    .frame(width: 4)

                InlineFlightWheelSegment(
                    value: twoDigits(minute),
                    previous: twoDigits(wrap(minute - 1, count: 60)),
                    next: twoDigits(wrap(minute + 1, count: 60)),
                    width: 17,
                    isEditing: isEditing,
                    isActive: isActive && activePart == .minute,
                    onActivate: { activate(.minute) },
                    onStep: { delta in
                        setClock(
                            hour: calendar.component(.hour, from: selection),
                            minute: wrap(calendar.component(.minute, from: selection) + delta, count: 60)
                        )
                    }
                )
            }
            .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .overlay(alignment: .bottomTrailing) {
            if isEditing && isActive {
                HStack(spacing: 3) {
                    if showsCalendarButton {
                        Button {
                            onActivate()
                            showsCalendar = true
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

    private func activate(_ part: Part) {
        guard isEditing else { return }
        onActivate()
        activePart = part
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

private struct InlineFlightWheelSegment: View {
    let value: String
    let previous: String
    let next: String
    let width: CGFloat
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void
    let onStep: (Int) -> Void

    @State private var translation: CGFloat = 0
    @State private var appliedSteps = 0
    @State private var dragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack(alignment: .leading) {
            Text(value)
                .opacity(isActive ? 0 : 1)

            if isActive {
                Text(previous)
                    .foregroundStyle(Color.secondary.opacity(0.52))
                    .offset(y: -rowHeight + residualOffset)
                    .allowsHitTesting(false)
                Text(value)
                    .foregroundStyle(Color.accentColor)
                    .offset(y: residualOffset)
                    .allowsHitTesting(false)
                Text(next)
                    .foregroundStyle(Color.secondary.opacity(0.52))
                    .offset(y: rowHeight + residualOffset)
                    .allowsHitTesting(false)
            }
        }
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
        .frame(width: width, height: 18, alignment: .leading)
        .contentShape(Rectangle())
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
