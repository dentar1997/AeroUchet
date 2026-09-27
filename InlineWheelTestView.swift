import SwiftUI
import UIKit

struct InlineWheelTestView: View {
    @State private var isEditing = false
    @State private var activeTakeoffID: Int?
    @State private var firstTakeoffMinutes = 1 * 60 + 50
    @State private var secondTakeoffMinutes = 15 * 60 + 12

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Тест inline-крутилки")
                                .font(.title2.bold())

                            Text("Изолированный прототип. Вкладка «Полёты» и реальные данные не используются.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            isEditing.toggle()
                            if !isEditing {
                                activeTakeoffID = nil
                            }
                        } label: {
                            Image(systemName: isEditing ? "xmark" : "wrench.and.screwdriver")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(isEditing ? "Выйти из режима редактирования" : "Редактировать")
                    }
                    .frame(maxWidth: 556)

                    TestAssignmentCard(
                        assignmentNumber: "5686217",
                        flightNumber: "1512",
                        aircraftType: "A-320A",
                        registration: "RA-73754",
                        route: "Москва (SVO/B) → Сургут (SGC)",
                        dateText: "07.09.2026",
                        workStart: "00:35",
                        engineStart: "01:36",
                        landing: "05:58",
                        engineStop: "06:10",
                        workEnd: "06:32",
                        takeoffMinutes: $firstTakeoffMinutes,
                        isEditing: isEditing,
                        isWheelActive: activeBinding(for: 1)
                    )

                    TestAssignmentCard(
                        assignmentNumber: "5727246",
                        flightNumber: "7108",
                        aircraftType: "A-320A",
                        registration: "RA-73754",
                        route: "Санкт-Петербург (LED) → Москва (SVO/B)",
                        dateText: "20.09.2026",
                        workStart: "14:40",
                        engineStart: "15:03",
                        landing: "17:37",
                        engineStop: "17:42",
                        workEnd: "18:05",
                        takeoffMinutes: $secondTakeoffMinutes,
                        isEditing: isEditing,
                        isWheelActive: activeBinding(for: 2)
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Тест")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func activeBinding(for id: Int) -> Binding<Bool> {
        Binding(
            get: { activeTakeoffID == id },
            set: { isActive in
                activeTakeoffID = isActive ? id : nil
            }
        )
    }
}

private struct TestAssignmentCard: View {
    let assignmentNumber: String
    let flightNumber: String
    let aircraftType: String
    let registration: String
    let route: String
    let dateText: String
    let workStart: String
    let engineStart: String
    let landing: String
    let engineStop: String
    let workEnd: String
    @Binding var takeoffMinutes: Int
    let isEditing: Bool
    @Binding var isWheelActive: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("Задание на полёт № \(assignmentNumber)")
                .font(.headline.bold())

            HStack(spacing: 8) {
                testValueCell(title: "Рейс", value: flightNumber)
                testValueCell(title: "Тип ВС", value: aircraftType)
                testValueCell(title: "Бортовой номер", value: registration)
                testValueCell(title: "Вид полёта", value: "Плановый")
                testValueCell(title: "Расчётное время", value: "Нет данных")
            }

            VStack(spacing: 2) {
                Text("Маршрут")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(route)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(testCellBackground)

            HStack(spacing: 8) {
                staticTimeCell(title: "Начало работы", value: "\(dateText) \(workStart)")
                staticTimeCell(title: "Включение двигателей", value: "\(dateText) \(engineStart)")

                InlineTakeoffTestCell(
                    dateText: dateText,
                    minutesOfDay: $takeoffMinutes,
                    isEditing: isEditing,
                    isActive: $isWheelActive
                )
                .zIndex(isWheelActive ? 100 : 0)
            }

            HStack(spacing: 8) {
                staticTimeCell(title: "Завершение работы", value: "\(dateText) \(workEnd)")
                staticTimeCell(title: "Выключение двигателей", value: "\(dateText) \(engineStop)")
                staticTimeCell(title: "Посадка", value: "\(dateText) \(landing)")
            }

            HStack(spacing: 8) {
                staticTimeCell(title: "Рабочее время", value: "5:57 · ночь 0:35")
                staticTimeCell(title: "Полётное время", value: "4:51 · ночь 0:05")
                staticTimeCell(title: "Лётное время", value: "4:07 · ночь 0:00")
            }
        }
        .padding(12)
        .frame(width: 556)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.32), lineWidth: 1)
        )
    }

    private func testValueCell(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(testCellBackground)
    }

    private func staticTimeCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(testCellBackground)
    }

    private var testCellBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}

private struct InlineTakeoffTestCell: View {
    let dateText: String
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    @Binding var isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Взлёт")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(dateText) \(timeText)")
                .font(.caption.bold())
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            isActive = true
        }
        .overlay {
            if isEditing, isActive {
                InlineTimeWheelEditor(
                    dateText: dateText,
                    minutesOfDay: $minutesOfDay,
                    onClose: { isActive = false }
                )
                .offset(y: -4)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: isActive)
    }

    private var timeText: String {
        String(format: "%02d:%02d", minutesOfDay / 60, minutesOfDay % 60)
    }
}

private struct InlineTimeWheelEditor: View {
    let dateText: String
    @Binding var minutesOfDay: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text("Взлёт")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(dateText)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()

                Button(action: onClose) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            ZStack {
                HStack(spacing: 2) {
                    InlineWheelColumn(
                        value: hourBinding,
                        valueCount: 24
                    )

                    Text(":")
                        .font(.headline.bold())
                        .foregroundStyle(Color.accentColor)

                    InlineWheelColumn(
                        value: minuteBinding,
                        valueCount: 60
                    )
                }

                VStack(spacing: 27) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.72))
                        .frame(height: 1)

                    Rectangle()
                        .fill(Color.accentColor.opacity(0.72))
                        .frame(height: 1)
                }
                .frame(width: 110)
                .allowsHitTesting(false)
            }
            .frame(height: 84)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 164, height: 118)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.97))
        )
        .shadow(radius: 6, y: 2)
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay / 60 },
            set: { hour in
                minutesOfDay = wrapped(hour, count: 24) * 60 + minutesOfDay % 60
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay % 60 },
            set: { minute in
                minutesOfDay = minutesOfDay / 60 * 60 + wrapped(minute, count: 60)
            }
        )
    }

    private func wrapped(_ value: Int, count: Int) -> Int {
        let result = value % count
        return result >= 0 ? result : result + count
    }
}

private struct InlineWheelColumn: View {
    @Binding var value: Int
    let valueCount: Int

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private let rowHeight: CGFloat = 27

    var body: some View {
        ZStack {
            ForEach(-2...2, id: \.self) { relative in
                let isCenter = relative == 0

                Text(String(format: "%02d", wrapped(value + relative)))
                    .font(
                        .system(
                            size: isCenter ? 18 : 13,
                            weight: isCenter ? .semibold : .regular,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        isCenter
                            ? Color.accentColor
                            : Color.secondary.opacity(abs(relative) == 1 ? 0.72 : 0.34)
                    )
                    .scaleEffect(isCenter ? 1 : 0.92)
                    .offset(
                        y: CGFloat(relative) * rowHeight + residualOffset
                    )
            }
        }
        .frame(width: 48, height: 82)
        .contentShape(Rectangle())
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gestureValue in
                    if !isDragging {
                        startValue = value
                        isDragging = true
                    }

                    dragTranslation = gestureValue.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    let newValue = wrapped(startValue + steps)

                    if newValue != value {
                        value = newValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.14)) {
                        dragTranslation = 0
                    }
                }
        )
    }

    private var residualOffset: CGFloat {
        guard isDragging else { return 0 }
        let steps = Int((-dragTranslation / rowHeight).rounded())
        return dragTranslation + CGFloat(steps) * rowHeight
    }

    private func wrapped(_ rawValue: Int) -> Int {
        let result = rawValue % valueCount
        return result >= 0 ? result : result + valueCount
    }
}
