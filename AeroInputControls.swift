import SwiftUI
import UIKit

// MARK: - Универсальные элементы ввода для Swift Playgrounds
//
// Обычные SwiftUI Picker/DatePicker на iPad в Swift Playgrounds
// могут сбивать работу физической клавиатуры и не всегда реагируют
// на нажатие трекпадом. Эти элементы используют обычную строку-кнопку
// и UIKit-крутилку во всплывающем окне.

struct AeroYearPickerRow: View {
    let title: String
    @Binding var selection: Int
    let range: ClosedRange<Int>

    @State private var isPresented = false

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
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(title)

                Spacer()

                Text(String(selection))
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

                UIKitYearWheel(
                    selection: $selection,
                    range: range
                )
                .frame(height: 180)
            }
            .frame(width: 280, height: 235)
            .presentationCompactAdaptation(.sheet)
        }
    }
}

private struct UIKitYearWheel: UIViewRepresentable {
    @Binding var selection: Int
    let range: ClosedRange<Int>

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selection: $selection,
            range: range
        )
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        let row = max(
            0,
            min(
                selection - range.lowerBound,
                range.count - 1
            )
        )

        picker.selectRow(
            row,
            inComponent: 0,
            animated: false
        )

        return picker
    }

    func updateUIView(
        _ picker: UIPickerView,
        context: Context
    ) {
        let row = max(
            0,
            min(
                selection - range.lowerBound,
                range.count - 1
            )
        )

        if picker.selectedRow(inComponent: 0) != row {
            picker.selectRow(
                row,
                inComponent: 0,
                animated: false
            )
        }
    }

    final class Coordinator:
        NSObject,
        UIPickerViewDataSource,
        UIPickerViewDelegate {

        private var selection: Binding<Int>
        private let range: ClosedRange<Int>

        init(
            selection: Binding<Int>,
            range: ClosedRange<Int>
        ) {
            self.selection = selection
            self.range = range
        }

        func numberOfComponents(
            in pickerView: UIPickerView
        ) -> Int {
            1
        }

        func pickerView(
            _ pickerView: UIPickerView,
            numberOfRowsInComponent component: Int
        ) -> Int {
            range.count
        }

        func pickerView(
            _ pickerView: UIPickerView,
            titleForRow row: Int,
            forComponent component: Int
        ) -> String? {
            String(range.lowerBound + row)
        }

        func pickerView(
            _ pickerView: UIPickerView,
            didSelectRow row: Int,
            inComponent component: Int
        ) {
            selection.wrappedValue =
            range.lowerBound + row
        }
    }
}


struct AeroTimePickerRow: View {
    let title: String
    @Binding var selection: Date

    @State private var isPresented = false

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

                UIKitTimeWheel(
                    selection: $selection
                )
                .frame(height: 200)
            }
            .frame(width: 320, height: 255)
            .presentationCompactAdaptation(.sheet)
        }
    }
}

private struct UIKitTimeWheel: UIViewRepresentable {
    @Binding var selection: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 1
        picker.locale = Locale(identifier: "ru_RU")
        picker.timeZone = moscowTimeZone
        picker.date = selection

        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        return picker
    }

    func updateUIView(
        _ picker: UIDatePicker,
        context: Context
    ) {
        if abs(
            picker.date.timeIntervalSince(selection)
        ) > 0.5 {
            picker.setDate(
                selection,
                animated: false
            )
        }
    }

    final class Coordinator: NSObject {
        private var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func valueChanged(
            _ picker: UIDatePicker
        ) {
            selection.wrappedValue = picker.date
        }
    }
}
