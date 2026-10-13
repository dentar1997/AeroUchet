import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Таблица «Воздушные суда». Вынесена из ReferenceDataV129.swift 13.10 ради скорости сборки, код без изменений.


struct AircraftReferenceSettingsV129View: View {
    @ObservedObject private var store = AircraftReferenceStoreV129.shared

    // CI can start the real aircraft table with a search already filled in.
    // Normal app navigation keeps the standard empty search field.
    init(initialSearch: String = "") {
        _search = State(initialValue: initialSearch)
    }

    @State private var search = ""
    @State private var selectedTypes = Set(AircraftFamilyV129.allCases)
    @State private var typeMenuOpen = false
    @State private var typeButtonFrame: CGRect = .zero
    @State private var typePanelFrame: CGRect = .zero
    @State private var tapCatcher = ScheduleTapCatcher()

    /// OFF — диапазон по RA-бортовому номеру, ON — по MSN.
    @State private var rangeUsesMSN = false
    @State private var rangeFrom = ""
    @State private var rangeTo = ""

    private enum SortColumn {
        case registration, oldRegistration, msn, type, configuration, surname
    }

    /// nil = стартовый порядок: Тарасов первым, затем RA по возрастанию.
    /// После первого тапа по заголовку Тарасов сортируется как обычная строка.
    @State private var sortColumn: SortColumn?
    @State private var sortAscending = true
    @State private var selectedAircraftID: String?

    private struct ColumnWidths {
        let registration: CGFloat
        let oldRegistration: CGFloat
        let msn: CGFloat
        let type: CGFloat
        let configuration: CGFloat
        let surname: CGFloat
    }

    private var values: [AircraftReferenceV129] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = store.aircraft.filter { aircraft in
            selectedTypes.contains(aircraft.type)
                && matchesRange(aircraft)
                && (query.isEmpty
                    || aircraft.registration.localizedCaseInsensitiveContains(query)
                    || aircraft.surname.localizedCaseInsensitiveContains(query)
                    || aircraft.type.rawValue.localizedCaseInsensitiveContains(query)
                    || (aircraft.configuration?.localizedCaseInsensitiveContains(query) ?? false)
                    || (aircraft.oldRegistration?.localizedCaseInsensitiveContains(query) ?? false)
                    || (aircraft.msn?.localizedCaseInsensitiveContains(query) ?? false))
        }

        guard let sortColumn else {
            return filtered.sorted(by: initialSortsBefore)
        }
        return filtered.sorted { sortsBefore($0, $1, column: sortColumn) }
    }

    var body: some View {
        GeometryReader { geometry in
            let widths = columnWidths(for: geometry.size.width - 24)

            VStack(spacing: 8) {
                HStack {
                    Text(aircraftCountTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                HStack(spacing: 10) {
                    TextField("Поиск", text: $search)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .scheduleFilterTile()
                        .frame(minWidth: 160, maxWidth: .infinity)

                    rangeField("от", text: $rangeFrom)
                    rangeField("до", text: $rangeTo)

                    Button {
                        rangeUsesMSN.toggle()
                        rangeFrom = ""
                        rangeTo = ""
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: rangeUsesMSN ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(rangeUsesMSN ? Color.teal : Color.secondary)
                            Text(rangeUsesMSN ? "MSN" : "Бортовой номер")
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        // Фиксируем именно содержимое ДО background плитки.
                        // Поэтому визуальная серая ячейка не меняет ширину.
                        .frame(width: 122, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .scheduleFilterTile()

                    AircraftFamilyFilterButton(
                        selection: $selectedTypes,
                        isOpen: $typeMenuOpen,
                        frame: $typeButtonFrame,
                        panelFrame: $typePanelFrame
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .zIndex(1)

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        sortHeader("Бортовой номер", .registration)
                            .frame(width: widths.registration, alignment: .center)
                        sortHeader("Старый бортовой номер", .oldRegistration)
                            .frame(width: widths.oldRegistration, alignment: .center)
                        sortHeader("MSN", .msn)
                            .frame(width: widths.msn, alignment: .center)
                        sortHeader("Тип ВС", .type)
                            .frame(width: widths.type, alignment: .center)
                        sortHeader("Компоновка", .configuration)
                            .frame(width: widths.configuration, alignment: .center)
                        sortHeader("Фамилия", .surname)
                            .frame(width: widths.surname, alignment: .center)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: ScheduleMonthsCalendarView.headerHeight)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(values) { aircraft in
                                aircraftRow(aircraft, widths: widths)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        // Тот же принцип, что в базе расписания: экран занимает нижнюю safe area,
        // а сама карточка оставляет физический зазор 12 pt от нижнего края.
        .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        .background {
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
        }
        .onAppear {
            tapCatcher.onTap = { point in
                if typeMenuOpen,
                   !typePanelFrame.contains(point),
                   !typeButtonFrame.contains(point) {
                    typeMenuOpen = false
                }
            }
            tapCatcher.install()
        }
        .onDisappear { tapCatcher.remove() }
        // Как в базе расписания: отдельный системный заголовок сверху не показываем.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .aeroStableNavigationBar()
        .onChange(of: rangeFrom) { _, value in
            let digits = sanitizedRange(value)
            if digits != value { rangeFrom = digits }
        }
        .onChange(of: rangeTo) { _, value in
            let digits = sanitizedRange(value)
            if digits != value { rangeTo = digits }
        }
    }

    private var aircraftCountTitle: String {
        let total = store.aircraft.count
        return values.count == total
            ? "Воздушные суда · \(total)"
            : "Воздушные суда · \(values.count) из \(total)"
    }

    private func rangeField(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .keyboardType(.numberPad)
                .font(.caption.monospacedDigit())
                .multilineTextAlignment(.center)
                // Одинаковая ширина в обоих режимах — без сдвига «от/до».
                .frame(width: 58)
        }
        .scheduleFilterTile()
    }

    private func sanitizedRange(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(rangeUsesMSN ? 6 : 5))
    }

    private func matchesRange(_ aircraft: AircraftReferenceV129) -> Bool {
        let lower = Int(rangeFrom)
        let upper = Int(rangeTo)
        guard lower != nil || upper != nil else { return true }

        let value: Int?
        if rangeUsesMSN {
            value = aircraft.msn.flatMap(Int.init)
        } else {
            value = Int(aircraft.digits)
        }
        guard let value else { return false }
        if let lower, value < lower { return false }
        if let upper, value > upper { return false }
        return true
    }

    private func columnWidths(for totalWidth: CGFloat) -> ColumnWidths {
        // Все шесть столбцов занимают одинаковые ячейки:
        // центры колонок идут с одинаковым шагом по всей ширине таблицы.
        // 24 = внутренние horizontal padding, 40 = пять spacing по 8.
        let usable = max(totalWidth - 24 - 40, 0)
        let equal = usable / 6
        return ColumnWidths(
            registration: equal,
            oldRegistration: equal,
            msn: equal,
            type: equal,
            configuration: equal,
            surname: equal
        )
    }

    private func aircraftRow(_ aircraft: AircraftReferenceV129, widths: ColumnWidths) -> some View {
        VStack(spacing: 0) {
            Button {
                selectedAircraftID = selectedAircraftID == aircraft.id ? nil : aircraft.id
            } label: {
                HStack(spacing: 8) {
                    Text(aircraft.registration)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(width: widths.registration, alignment: .center)
                    Text(aircraft.oldRegistration ?? "—")
                        .font(.caption.monospaced())
                        .frame(width: widths.oldRegistration, alignment: .center)
                    Text(aircraft.msn ?? "—")
                        .font(.caption.monospacedDigit())
                        .frame(width: widths.msn, alignment: .center)
                    Text(aircraft.type.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(width: widths.type, alignment: .center)
                    Text(aircraft.configuration ?? "—")
                        .font(.caption.monospacedDigit())
                        .frame(width: widths.configuration, alignment: .center)
                    Text(aircraft.surname)
                        .font(.caption)
                        .frame(width: widths.surname, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selectedAircraftID == aircraft.id ? Color.teal.opacity(0.10) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
        }
    }

    private func sortHeader(_ title: String, _ column: SortColumn) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        } label: {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .overlay(alignment: .trailing) {
                    if sortColumn == column {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .offset(x: 13)
                    }
                }
                .foregroundStyle(sortColumn == column ? Color.teal : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func initialSortsBefore(_ left: AircraftReferenceV129, _ right: AircraftReferenceV129) -> Bool {
        let leftIsTarasov = left.registration == "RA-73772"
        let rightIsTarasov = right.registration == "RA-73772"
        if leftIsTarasov != rightIsTarasov { return leftIsTarasov }
        return left.registration.localizedStandardCompare(right.registration) == .orderedAscending
    }

    private func sortsBefore(
        _ left: AircraftReferenceV129,
        _ right: AircraftReferenceV129,
        column: SortColumn
    ) -> Bool {
        let order: ComparisonResult
        switch column {
        case .registration:
            order = left.registration.localizedStandardCompare(right.registration)
        case .oldRegistration:
            if let fixed = missingValueOrder(left.oldRegistration, right.oldRegistration) { return fixed }
            order = (left.oldRegistration ?? "").localizedStandardCompare(right.oldRegistration ?? "")
        case .msn:
            if let fixed = missingValueOrder(left.msn, right.msn) { return fixed }
            if let lhs = Int(left.msn ?? ""), let rhs = Int(right.msn ?? ""), lhs != rhs {
                order = lhs < rhs ? .orderedAscending : .orderedDescending
            } else {
                order = (left.msn ?? "").localizedStandardCompare(right.msn ?? "")
            }
        case .type:
            order = left.type.rawValue.localizedStandardCompare(right.type.rawValue)
        case .configuration:
            if let fixed = missingValueOrder(left.configuration, right.configuration) { return fixed }
            order = (left.configuration ?? "").localizedStandardCompare(right.configuration ?? "")
        case .surname:
            order = left.surname.localizedStandardCompare(right.surname)
        }

        if order != .orderedSame {
            return sortAscending ? order == .orderedAscending : order == .orderedDescending
        }
        return left.registration.localizedStandardCompare(right.registration) == .orderedAscending
    }

    /// Пустые справочные значения всегда внизу, независимо от направления сортировки.
    private func missingValueOrder(_ left: String?, _ right: String?) -> Bool? {
        switch (left, right) {
        case (nil, nil):
            return nil
        case (nil, _):
            return false
        case (_, nil):
            return true
        default:
            return nil
        }
    }
}

// замер инкрементальной сборки (будет откачен)
