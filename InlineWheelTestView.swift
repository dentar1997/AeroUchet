import SwiftUI
import UIKit

struct InlineWheelTestView: View {
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    TestVariantSection(
                        number: 1,
                        title: "Текущий вариант",
                        subtitle: "Небольшой overlay над ячейкой. Сохраняем без изменений."
                    ) {
                        PopupWheelAssignmentCard(isEditing: isEditing)
                    }

                    TestVariantSection(
                        number: 2,
                        title: "Раздельные часы и минуты",
                        subtitle: "Часы и минуты становятся отдельными зонами прокрутки."
                    ) {
                        SeparatedWheelAssignmentCard(isEditing: isEditing)
                    }

                    TestVariantSection(
                        number: 3,
                        title: "Без изменения геометрии",
                        subtitle: "Центральные дата и время остаются точно на месте; соседние значения только дорисовываются сверху и снизу."
                    ) {
                        FixedGeometryAssignmentCard(isEditing: isEditing)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Тест")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Тестовые крутилки")
                    .font(.title2.bold())

                Text("Изолированные прототипы. Вкладка «Полёты» и реальные данные не используются.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "xmark" : "wrench.and.screwdriver")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isEditing ? "Выйти из режима редактирования" : "Редактировать")
        }
        .frame(maxWidth: 556)
    }
}

private struct TestVariantSection<Content: View>: View {
    let number: Int
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(
        number: Int,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.accentColor))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Тест \(number) · \(title)")
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .frame(maxWidth: 556, alignment: .leading)
    }
}

// MARK: - Test 1: existing popup overlay

private struct PopupWheelAssignmentCard: View {
    let isEditing: Bool

    @State private var takeoffMinutes = 1 * 60 + 50
    @State private var isWheelActive = false

    var body: some View {
        PrototypeAssignmentShell(
            assignmentNumber: "5686217",
            flightNumber: "1512",
            route: "Москва (SVO/B) → Сургут (SGC)",
            dateText: "07.09.2026"
        ) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Начало работы", value: "07.09.2026 00:35")
                PrototypeStaticTimeCell(title: "Включение двигателей", value: "07.09.2026 01:36")

                PopupTakeoffCell(
                    dateText: "07.09.2026",
                    minutesOfDay: $takeoffMinutes,
                    isEditing: isEditing,
                    isActive: $isWheelActive
                )
                .zIndex(isWheelActive ? 100 : 0)
            }

            PrototypeBottomRows(dateText: "07.09.2026")
        }
    }
}

private struct PopupTakeoffCell: View {
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
        .background(PrototypeStyle.cellBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            isActive = true
        }
        .overlay {
            if isEditing, isActive {
                PopupTimeWheelEditor(
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
        formatTestTime(minutesOfDay)
    }
}

private struct PopupTimeWheelEditor: View {
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
                    PrototypeWheelColumn(value: hourBinding, valueCount: 24, width: 48)

                    Text(":")
                        .font(.headline.bold())
                        .foregroundStyle(Color.accentColor)

                    PrototypeWheelColumn(value: minuteBinding, valueCount: 60, width: 48)
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
                minutesOfDay = wrappedTestValue(hour, count: 24) * 60 + minutesOfDay % 60
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay % 60 },
            set: { minute in
                minutesOfDay = minutesOfDay / 60 * 60 + wrappedTestValue(minute, count: 60)
            }
        )
    }
}

// MARK: - Test 2: separated inline columns

private struct SeparatedWheelAssignmentCard: View {
    let isEditing: Bool

    @State private var takeoffMinutes = 1 * 60 + 50
    @State private var activePart: TimeWheelPart?

    var body: some View {
        PrototypeAssignmentShell(
            assignmentNumber: "5727246",
            flightNumber: "7108",
            route: "Санкт-Петербург (LED) → Москва (SVO/B)",
            dateText: "20.09.2026"
        ) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Начало работы", value: "20.09.2026 14:40")
                PrototypeStaticTimeCell(title: "Включение двигателей", value: "20.09.2026 15:03")

                SeparatedInlineTimeCell(
                    dateText: "20.09.2026",
                    minutesOfDay: $takeoffMinutes,
                    isEditing: isEditing,
                    activePart: $activePart
                )
                .zIndex(activePart == nil ? 0 : 100)
            }

            PrototypeBottomRows(dateText: "20.09.2026")
        }
    }
}

private enum TimeWheelPart {
    case hour
    case minute
}

private struct SeparatedInlineTimeCell: View {
    let dateText: String
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    @Binding var activePart: TimeWheelPart?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Взлёт")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                Text(dateText)
                    .font(.caption2.bold())
                    .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

                HStack(spacing: 1) {
                    SeparatedSegment(
                        value: hourBinding,
                        count: 24,
                        isEditing: isEditing,
                        isActive: activePart == .hour,
                        onActivate: { activePart = .hour }
                    )

                    Text(":")
                        .font(.caption.bold())
                        .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

                    SeparatedSegment(
                        value: minuteBinding,
                        count: 60,
                        isEditing: isEditing,
                        isActive: activePart == .minute,
                        onActivate: { activePart = .minute }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                activePart = nil
            }
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay / 60 },
            set: { hour in
                minutesOfDay = wrappedTestValue(hour, count: 24) * 60 + minutesOfDay % 60
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay % 60 },
            set: { minute in
                minutesOfDay = minutesOfDay / 60 * 60 + wrappedTestValue(minute, count: 60)
            }
        )
    }
}

private struct SeparatedSegment: View {
    @Binding var value: Int
    let count: Int
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void

    var body: some View {
        ZStack {
            Text(String(format: "%02d", value))
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

            if isActive {
                PrototypeWheelColumn(
                    value: $value,
                    valueCount: count,
                    width: 32,
                    rowHeight: 22,
                    centerSize: 14,
                    neighborSize: 10
                )
                .frame(height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.92))
                )
                .shadow(radius: 3, y: 1)
            }
        }
        .frame(width: 30, height: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
    }
}

// MARK: - Test 3: fixed geometry, pure overlay

private struct FixedGeometryAssignmentCard: View {
    let isEditing: Bool

    @State private var takeoffMinutes = 1 * 60 + 50
    @State private var dayOffset = 0
    @State private var activePart: FixedInlinePart?

    private let originalMinutes = 1 * 60 + 50

    var body: some View {
        PrototypeAssignmentShell(
            assignmentNumber: "5686217",
            flightNumber: "1512",
            route: "Москва (SVO/B) → Сургут (SGC)",
            dateText: fixedTestDateText(offset: dayOffset)
        ) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Начало работы", value: "07.09.2026 00:35")
                PrototypeStaticTimeCell(title: "Включение двигателей", value: "07.09.2026 01:36")

                FixedGeometryDateTimeCell(
                    minutesOfDay: $takeoffMinutes,
                    dayOffset: $dayOffset,
                    isEditing: isEditing,
                    activePart: $activePart,
                    onReset: {
                        takeoffMinutes = originalMinutes
                        dayOffset = 0
                    }
                )
                .zIndex(activePart == nil ? 0 : 200)
            }

            PrototypeBottomRows(dateText: "07.09.2026")
        }
    }
}

private enum FixedInlinePart {
    case date
    case hour
    case minute
}

private struct FixedGeometryDateTimeCell: View {
    @Binding var minutesOfDay: Int
    @Binding var dayOffset: Int
    let isEditing: Bool
    @Binding var activePart: FixedInlinePart?
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Взлёт")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                FixedDateSegment(
                    dayOffset: $dayOffset,
                    isEditing: isEditing,
                    isActive: activePart == .date,
                    onActivate: { activePart = .date }
                )
                .zIndex(activePart == .date ? 10 : 0)

                FixedTimeReadout(
                    minutesOfDay: $minutesOfDay,
                    isEditing: isEditing,
                    activePart: $activePart
                )
                .zIndex(activePart == .hour || activePart == .minute ? 10 : 0)

                if isEditing {
                    Button {
                        activePart = .date
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel("Выбрать дату")

                    Button {
                        onReset()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 18, height: 18)
                    .disabled(dayOffset == 0 && minutesOfDay == 1 * 60 + 50)
                    .accessibilityLabel("Вернуть исходные дату и время")
                }
            }
            .frame(height: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                activePart = nil
            }
        }
    }
}

private struct FixedDateSegment: View {
    @Binding var dayOffset: Int
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack {
            Text(fixedTestDateText(offset: dayOffset))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

            if isActive {
                ForEach(-1...1, id: \.self) { relative in
                    let center = relative == 0

                    Text(fixedTestDateText(offset: dayOffset + relative))
                        .font(
                            .system(
                                size: center ? 10 : 9,
                                weight: center ? .bold : .medium,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(
                            center
                                ? Color.accentColor
                                : Color.secondary.opacity(0.58)
                        )
                        .offset(y: CGFloat(relative) * rowHeight + residualOffset)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 64, height: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard isEditing, isActive else { return }
                    if !isDragging {
                        startValue = dayOffset
                        isDragging = true
                    }

                    dragTranslation = value.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    let newValue = startValue + steps

                    if newValue != dayOffset {
                        dayOffset = newValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.12)) {
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
}

private struct FixedTimeReadout: View {
    @Binding var minutesOfDay: Int
    let isEditing: Bool
    @Binding var activePart: FixedInlinePart?

    var body: some View {
        HStack(spacing: 0) {
            FixedNumberSegment(
                value: hourBinding,
                count: 24,
                isEditing: isEditing,
                isActive: activePart == .hour,
                onActivate: { activePart = .hour }
            )

            Text(":")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
                .frame(width: 5)

            FixedNumberSegment(
                value: minuteBinding,
                count: 60,
                isEditing: isEditing,
                isActive: activePart == .minute,
                onActivate: { activePart = .minute }
            )
        }
        .frame(width: 39, height: 18)
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay / 60 },
            set: { hour in
                minutesOfDay = wrappedTestValue(hour, count: 24) * 60 + minutesOfDay % 60
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minutesOfDay % 60 },
            set: { minute in
                minutesOfDay = minutesOfDay / 60 * 60 + wrappedTestValue(minute, count: 60)
            }
        )
    }
}

private struct FixedNumberSegment: View {
    @Binding var value: Int
    let count: Int
    let isEditing: Bool
    let isActive: Bool
    let onActivate: () -> Void

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private let rowHeight: CGFloat = 20

    var body: some View {
        ZStack {
            Text(String(format: "%02d", value))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isEditing ? Color.accentColor : Color.primary)

            if isActive {
                ForEach(-1...1, id: \.self) { relative in
                    let center = relative == 0

                    Text(String(format: "%02d", wrappedTestValue(value + relative, count: count)))
                        .font(
                            .system(
                                size: center ? 10 : 9,
                                weight: center ? .bold : .medium,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(
                            center
                                ? Color.accentColor
                                : Color.secondary.opacity(0.58)
                        )
                        .offset(y: CGFloat(relative) * rowHeight + residualOffset)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 17, height: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onActivate()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard isEditing, isActive else { return }
                    if !isDragging {
                        startValue = value
                        isDragging = true
                    }

                    dragTranslation = gesture.translation.height
                    let steps = Int((-dragTranslation / rowHeight).rounded())
                    let newValue = wrappedTestValue(startValue + steps, count: count)

                    if newValue != value {
                        value = newValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.easeOut(duration: 0.12)) {
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
}

// MARK: - Shared prototype shell

private struct PrototypeAssignmentShell<Content: View>: View {
    let assignmentNumber: String
    let flightNumber: String
    let route: String
    let dateText: String
    @ViewBuilder let content: Content

    init(
        assignmentNumber: String,
        flightNumber: String,
        route: String,
        dateText: String,
        @ViewBuilder content: () -> Content
    ) {
        self.assignmentNumber = assignmentNumber
        self.flightNumber = flightNumber
        self.route = route
        self.dateText = dateText
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Задание на полёт № \(assignmentNumber)")
                .font(.headline.bold())

            HStack(spacing: 8) {
                PrototypeValueCell(title: "Рейс", value: flightNumber)
                PrototypeValueCell(title: "Тип ВС", value: "A-320A")
                PrototypeValueCell(title: "Бортовой номер", value: "RA-73754")
                PrototypeValueCell(title: "Вид полёта", value: "Плановый")
                PrototypeValueCell(title: "Расчётное время", value: "Нет данных")
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
            .background(PrototypeStyle.cellBackground)

            content
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
}

private struct PrototypeValueCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(PrototypeStyle.cellBackground)
    }
}

private struct PrototypeStaticTimeCell: View {
    let title: String
    let value: String

    var body: some View {
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
        .background(PrototypeStyle.cellBackground)
    }
}

private struct PrototypeBottomRows: View {
    let dateText: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Завершение работы", value: "\(dateText) 06:32")
                PrototypeStaticTimeCell(title: "Выключение двигателей", value: "\(dateText) 06:10")
                PrototypeStaticTimeCell(title: "Посадка", value: "\(dateText) 05:58")
            }

            HStack(spacing: 8) {
                PrototypeStaticTimeCell(title: "Рабочее время", value: "5:57 · ночь 0:35")
                PrototypeStaticTimeCell(title: "Полётное время", value: "4:51 · ночь 0:05")
                PrototypeStaticTimeCell(title: "Лётное время", value: "4:07 · ночь 0:00")
            }
        }
    }
}

private struct PrototypeWheelColumn: View {
    @Binding var value: Int
    let valueCount: Int
    var width: CGFloat = 48
    var rowHeight: CGFloat = 27
    var centerSize: CGFloat = 18
    var neighborSize: CGFloat = 13

    @State private var startValue = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            ForEach(-2...2, id: \.self) { relative in
                let isCenter = relative == 0

                Text(String(format: "%02d", wrappedTestValue(value + relative, count: valueCount)))
                    .font(
                        .system(
                            size: isCenter ? centerSize : neighborSize,
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
                    .offset(y: CGFloat(relative) * rowHeight + residualOffset)
            }
        }
        .frame(width: width, height: rowHeight * 3)
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
                    let newValue = wrappedTestValue(startValue + steps, count: valueCount)

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
}

private enum PrototypeStyle {
    static var cellBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}

private func wrappedTestValue(_ value: Int, count: Int) -> Int {
    let result = value % count
    return result >= 0 ? result : result + count
}

private func formatTestTime(_ minutesOfDay: Int) -> String {
    let normalized = wrappedTestValue(minutesOfDay, count: 24 * 60)
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}

private func fixedTestDateText(offset: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current

    guard
        let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)),
        let date = calendar.date(byAdding: .day, value: offset, to: base)
    else {
        return "07.09.2026"
    }

    let components = calendar.dateComponents([.day, .month, .year], from: date)
    return String(
        format: "%02d.%02d.%04d",
        components.day ?? 7,
        components.month ?? 9,
        components.year ?? 2026
    )
}
