import SwiftUI

// MARK: - Элементы выбора без Picker/DatePicker
//
// В Swift Playgrounds на iPad системные Picker/DatePicker могут
// ломать работу физической клавиатуры. Поэтому здесь используются
// обычные кнопки и ScrollView: они не становятся текстовым
// first responder и нормально работают с пальцем и трекпадом.

struct AeroYearPickerRow: View {
    let title: String
    @Binding var selection: Int
    let range: ClosedRange<Int>

    init(
        _ title: String,
        selection: Binding<Int>,
        range: ClosedRange<Int> = 2000...2100
    ) {
        self.title = title
        self._selection = selection
        self.range = range
    }

    var body: some View {
        Stepper(
            value: $selection,
            in: range
        ) {
            HStack {
                Text(title)

                Spacer()

                Text(String(selection))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}


struct AeroTimePickerRow: View {
    let title: String
    @Binding var selection: Date

    @State private var isPresented = false

    private var selectedHour: Int {
        moscowCalendar.component(
            .hour,
            from: selection
        )
    }

    private var selectedMinute: Int {
        moscowCalendar.component(
            .minute,
            from: selection
        )
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(title)

                Spacer()

                Text(formatClock(selection))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Button("Готово") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
                .padding()

                Divider()

                HStack(spacing: 0) {
                    AeroNumberColumn(
                        values: Array(0...23),
                        selection: selectedHour
                    ) { hour in
                        setTime(
                            hour: hour,
                            minute: selectedMinute
                        )
                    }

                    Text(":")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 4)

                    AeroNumberColumn(
                        values: Array(0...59),
                        selection: selectedMinute
                    ) { minute in
                        setTime(
                            hour: selectedHour,
                            minute: minute
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(width: 300, height: 270)
            .presentationCompactAdaptation(.sheet)
        }
    }

    private func setTime(
        hour: Int,
        minute: Int
    ) {
        var components =
        moscowCalendar.dateComponents(
            [
                .year,
                .month,
                .day,
                .second
            ],
            from: selection
        )

        components.hour = hour
        components.minute = minute
        components.timeZone = moscowTimeZone

        if let updated =
            moscowCalendar.date(
                from: components
            ) {
            selection = updated
        }
    }
}


struct AeroMinutesPickerButton: View {
    @Binding var minutes: Int
    var foregroundStyle: Color = .primary

    @State private var isPresented = false

    private var selectedHour: Int {
        max(0, minutes / 60)
    }

    private var selectedMinute: Int {
        max(0, minutes % 60)
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text(
                String(
                    format: "%d:%02d",
                    selectedHour,
                    selectedMinute
                )
            )
            .fontWeight(.medium)
            .monospacedDigit()
            .foregroundStyle(foregroundStyle)
            .frame(
                maxWidth: .infinity
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            VStack(spacing: 0) {
                HStack {
                    Text("Расчётное время")
                        .font(.headline)

                    Spacer()

                    Button("Готово") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
                .padding()

                Divider()

                HStack(spacing: 0) {
                    AeroNumberColumn(
                        values: Array(0...23),
                        selection: selectedHour
                    ) { hour in
                        minutes =
                        hour * 60
                        + selectedMinute
                    }

                    Text(":")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 4)

                    AeroNumberColumn(
                        values: Array(0...59),
                        selection: selectedMinute
                    ) { minute in
                        minutes =
                        selectedHour * 60
                        + minute
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(
                width: 300,
                height: 270
            )
            .presentationCompactAdaptation(.sheet)
        }
    }
}


private struct AeroNumberColumn: View {
    let values: [Int]
    let selection: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(
                        values,
                        id: \.self
                    ) { value in
                        Button {
                            onSelect(value)
                        } label: {
                            Text(
                                String(
                                    format: "%02d",
                                    value
                                )
                            )
                            .font(
                                value == selection
                                ? .title2.weight(.semibold)
                                : .body
                            )
                            .monospacedDigit()
                            .foregroundStyle(
                                value == selection
                                ? .primary
                                : .secondary
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 38
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(value)
                    }
                }
                .padding(.vertical, 72)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(
                        selection,
                        anchor: .center
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
