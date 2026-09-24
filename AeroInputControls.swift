import SwiftUI
import UIKit

// MARK: - Swift Playgrounds: восстановление физической клавиатуры

@MainActor
func restoreHardwareKeyboardAfterFilePicker() {
    DispatchQueue.main.asyncAfter(
        deadline: .now() + 0.25
    ) {
        guard
            let windowScene =
                UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: {
                    $0.activationState == .foregroundActive
                }),
            let window =
                windowScene.windows
                .first(where: { $0.isKeyWindow })
                ?? windowScene.windows.first
        else {
            return
        }

        let primer =
        UITextField(
            frame: CGRect(
                x: -1000,
                y: -1000,
                width: 1,
                height: 1
            )
        )

        primer.alpha = 0.01
        primer.autocorrectionType = .no
        window.addSubview(primer)

        primer.becomeFirstResponder()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.20
        ) {
            primer.resignFirstResponder()
            primer.removeFromSuperview()
        }
    }
}


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
