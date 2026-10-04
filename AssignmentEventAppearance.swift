import SwiftUI
import UIKit


enum AssignmentEventType: String, CaseIterable, Codable, Identifiable {
    case flight
    case passenger
    case hotelReserve
    case homeReserve
    case dayOff
    case leave
    case simulatorLand
    case simulatorWater
    case training
    case medical
    case simulatorCTS
    case appearance
    case ground

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flight: return "Полёт рабочим экипажем"
        case .passenger: return "Перелёт пассажиром"
        case .hotelReserve: return "Резерв"
        case .homeReserve: return "Резерв в месте жительства"
        case .dayOff: return "Выходной"
        case .leave: return "Отпуск"
        case .simulatorLand: return "Тренажёр суша"
        case .simulatorWater: return "Тренажёр вода"
        case .training: return "Обучение"
        case .medical: return "Медкомиссия"
        case .simulatorCTS: return "Тренажёр КТС"
        case .appearance: return "Явка"
        case .ground: return "Прочее назначение"
        }
    }

    static func resolve(_ item: AssignmentPlanItem) -> AssignmentEventType {
        switch item.kind {
        case .flight:
            return .flight
        case .passenger:
            return .passenger
        case .hotelReserve:
            return .hotelReserve
        case .homeReserve:
            return .homeReserve
        case .dayOff:
            return .dayOff
        case .leave:
            return .leave
        case .medical:
            return .medical
        case .simulator:
            let value = (item.title + " " + (AssignmentV119MetadataCodec.humanDetail(item.detail) ?? ""))
                .lowercased()
            if value.contains("вод") {
                return .simulatorWater
            }
            if value.contains("суш") || value.contains("выжив") {
                return .simulatorLand
            }
            return .simulatorCTS
        case .training:
            let value = item.title.lowercased()
            return value.contains("явка") ? .appearance : .training
        case .ground:
            let value = item.title.lowercased()
            if value.contains("явка") { return .appearance }
            if value.contains("обуч") || value.contains("инструктаж") { return .training }
            return .ground
        }
    }
}


struct AssignmentIconColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            red = Double(r)
            green = Double(g)
            blue = Double(b)
            alpha = Double(a)
        } else {
            red = 0.25
            green = 0.48
            blue = 0.95
            alpha = 1
        }
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    static let blue = AssignmentIconColor(red: 0.10, green: 0.42, blue: 0.94)
    static let cyan = AssignmentIconColor(red: 0.05, green: 0.62, blue: 0.78)
    static let orange = AssignmentIconColor(red: 0.93, green: 0.48, blue: 0.08)
    static let purple = AssignmentIconColor(red: 0.58, green: 0.30, blue: 0.88)
    static let magenta = AssignmentIconColor(red: 0.78, green: 0.24, blue: 0.50)
    static let teal = AssignmentIconColor(red: 0.05, green: 0.58, blue: 0.56)
    static let gray = AssignmentIconColor(red: 0.46, green: 0.48, blue: 0.52)
}


enum AssignmentIconMode: String, Codable, CaseIterable {
    case preset
    case sfSymbol
    case composite

    var title: String {
        switch self {
        case .preset: return "Варианты"
        case .sfSymbol: return "SF Symbol"
        case .composite: return "Редактор"
        }
    }
}


struct AssignmentIconLayer: Identifiable, Codable, Equatable {
    var id = UUID()
    var symbolName: String
    var color: AssignmentIconColor
    var scale: Double = 1
    var xOffset: Double = 0
    var yOffset: Double = 0
    var rotation: Double = 0
}


struct AssignmentIconStyle: Codable, Equatable {
    var mode: AssignmentIconMode
    var presetIndex: Int
    var symbolName: String
    var color: AssignmentIconColor
    var layers: [AssignmentIconLayer]

    static func defaultStyle(for type: AssignmentEventType) -> AssignmentIconStyle {
        let symbol: String
        let color: AssignmentIconColor

        switch type {
        case .flight:
            symbol = "airplane"
            color = .blue
        case .passenger:
            symbol = "suitcase.fill"
            color = .blue
        case .hotelReserve:
            symbol = "building.2.fill"
            color = .orange
        case .homeReserve:
            symbol = "house.fill"
            color = .orange
        case .dayOff:
            symbol = "bed.double.fill"
            color = .gray
        case .leave:
            symbol = "sun.max.fill"
            color = .magenta
        case .simulatorLand:
            symbol = "tent.fill"
            color = .purple
        case .simulatorWater:
            symbol = "water.waves"
            color = .purple
        case .training:
            symbol = "graduationcap.fill"
            color = .purple
        case .medical:
            symbol = "stethoscope"
            color = .purple
        case .simulatorCTS:
            symbol = "airplane.circle.fill"
            color = .teal
        case .appearance:
            symbol = "checklist"
            color = .teal
        case .ground:
            symbol = "briefcase.fill"
            color = .gray
        }

        return AssignmentIconStyle(
            mode: .preset,
            presetIndex: 0,
            symbolName: symbol,
            color: color,
            layers: [
                AssignmentIconLayer(
                    symbolName: symbol,
                    color: color
                )
            ]
        )
    }
}


struct AssignmentIconPreset: Identifiable {
    let id: Int
    let title: String
    let symbols: [String]
    let isMotionSimulator: Bool
}


enum AssignmentIconPresetLibrary {
    static func presets(for type: AssignmentEventType) -> [AssignmentIconPreset] {
        switch type {
        case .flight:
            return [
                .init(id: 0, title: "Самолёт", symbols: ["airplane"], isMotionSimulator: false),
                .init(id: 1, title: "Самолёт в круге", symbols: ["airplane.circle.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Вылет", symbols: ["airplane.departure"], isMotionSimulator: false)
            ]
        case .passenger:
            return [
                .init(id: 0, title: "Чемодан", symbols: ["suitcase.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Чемодан на колёсах", symbols: ["suitcase.rolling.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Багаж", symbols: ["suitcase"], isMotionSimulator: false)
            ]
        case .hotelReserve:
            return [
                .init(id: 0, title: "Гостиница", symbols: ["building.2.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Здание", symbols: ["building.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Гостиница и кровать", symbols: ["building.2.fill", "bed.double.fill"], isMotionSimulator: false)
            ]
        case .homeReserve:
            return [
                .init(id: 0, title: "Дом", symbols: ["house.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Дом в круге", symbols: ["house.circle.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Контур дома", symbols: ["house"], isMotionSimulator: false)
            ]
        case .dayOff:
            return [
                .init(id: 0, title: "Кровать", symbols: ["bed.double.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Сон", symbols: ["moon.zzz.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Кровать и луна", symbols: ["bed.double.fill", "moon.fill"], isMotionSimulator: false)
            ]
        case .leave:
            return [
                .init(id: 0, title: "Солнце", symbols: ["sun.max.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Отпуск в календаре", symbols: ["calendar.badge.minus"], isMotionSimulator: false),
                .init(id: 2, title: "Путешествие", symbols: ["airplane", "sun.max.fill"], isMotionSimulator: false)
            ]
        case .simulatorLand:
            return [
                .init(id: 0, title: "Лес и палатка", symbols: ["tree.fill", "tent.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Палатка", symbols: ["tent.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Лес", symbols: ["tree.fill"], isMotionSimulator: false)
            ]
        case .simulatorWater:
            return [
                .init(id: 0, title: "Морские волны", symbols: ["water.waves"], isMotionSimulator: false),
                .init(id: 1, title: "Волны и капля", symbols: ["water.waves", "drop.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Вода", symbols: ["drop.fill"], isMotionSimulator: false)
            ]
        case .training:
            return [
                .init(id: 0, title: "Обучение", symbols: ["graduationcap.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Книга", symbols: ["book.closed.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Учебные материалы", symbols: ["books.vertical.fill"], isMotionSimulator: false)
            ]
        case .medical:
            return [
                .init(id: 0, title: "Стетоскоп", symbols: ["stethoscope"], isMotionSimulator: false),
                .init(id: 1, title: "Медицинский кейс", symbols: ["cross.case.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Медицина", symbols: ["heart.text.square.fill"], isMotionSimulator: false)
            ]
        case .simulatorCTS:
            return [
                .init(id: 0, title: "КТС — вид спереди", symbols: [], isMotionSimulator: true),
                .init(id: 1, title: "КТС — компактный", symbols: [], isMotionSimulator: true),
                .init(id: 2, title: "КТС — платформа", symbols: [], isMotionSimulator: true)
            ]
        case .appearance:
            return [
                .init(id: 0, title: "Планшет с галочкой", symbols: ["checklist"], isMotionSimulator: false),
                .init(id: 1, title: "Документ с галочкой", symbols: ["doc.text.fill", "checkmark.circle.fill"], isMotionSimulator: false),
                .init(id: 2, title: "Галочка", symbols: ["checkmark.square.fill"], isMotionSimulator: false)
            ]
        case .ground:
            return [
                .init(id: 0, title: "Портфель", symbols: ["briefcase.fill"], isMotionSimulator: false),
                .init(id: 1, title: "Календарь", symbols: ["calendar"], isMotionSimulator: false),
                .init(id: 2, title: "Список", symbols: ["list.clipboard.fill"], isMotionSimulator: false)
            ]
        }
    }
}


@MainActor
final class AssignmentAppearanceStore: ObservableObject {
    static let shared = AssignmentAppearanceStore()

    @Published private(set) var styles: [String: AssignmentIconStyle] = [:]

    private let defaultsKey = "assignmentEventAppearanceV119"

    private init() {
        load()
    }

    func style(for type: AssignmentEventType) -> AssignmentIconStyle {
        styles[type.rawValue] ?? .defaultStyle(for: type)
    }

    func setStyle(_ style: AssignmentIconStyle, for type: AssignmentEventType) {
        styles[type.rawValue] = style
        save()
    }

    func reset(_ type: AssignmentEventType) {
        styles.removeValue(forKey: type.rawValue)
        save()
    }

    private func load() {
        guard let decoded = StorageSafety.decode(
            [String: AssignmentIconStyle].self, key: defaultsKey, title: "Настройка событий"
        ) else {
            return
        }
        styles = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(styles) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}


struct AssignmentEventIconView: View {
    let eventType: AssignmentEventType
    let style: AssignmentIconStyle
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch style.mode {
            case .preset:
                presetBody
            case .sfSymbol:
                Image(systemName: validSymbol(style.symbolName))
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(style.color.color)
            case .composite:
                compositeBody
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var presetBody: some View {
        let presets = AssignmentIconPresetLibrary.presets(for: eventType)
        let index = min(max(style.presetIndex, 0), max(presets.count - 1, 0))
        let preset = presets[index]

        if preset.isMotionSimulator {
            MotionSimulatorGlyph(variant: index)
                .fill(style.color.color)
        } else {
            ZStack {
                ForEach(Array(preset.symbols.enumerated()), id: \.offset) { position, symbol in
                    Image(systemName: validSymbol(symbol))
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(style.color.color)
                        .scaleEffect(preset.symbols.count > 1 ? 0.72 : 1)
                        .offset(
                            x: preset.symbols.count > 1
                                ? CGFloat(position * 7) - 3.5
                                : 0,
                            y: preset.symbols.count > 1
                                ? CGFloat(position == 0 ? -2 : 3)
                                : 0
                        )
                }
            }
        }
    }

    private var compositeBody: some View {
        ZStack {
            ForEach(style.layers) { layer in
                Image(systemName: validSymbol(layer.symbolName))
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(layer.color.color)
                    .scaleEffect(layer.scale)
                    .rotationEffect(.degrees(layer.rotation))
                    .offset(x: layer.xOffset, y: layer.yOffset)
            }
        }
    }

    private func validSymbol(_ name: String) -> String {
        UIImage(systemName: name) == nil ? "questionmark.square.dashed" : name
    }
}


private struct MotionSimulatorGlyph: Shape {
    let variant: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let cabinWidth = variant == 1 ? w * 0.58 : w * 0.68
        let cabinHeight = variant == 2 ? h * 0.28 : h * 0.34
        let cabinX = (w - cabinWidth) / 2
        let cabinY = h * 0.10
        let cabin = CGRect(
            x: cabinX,
            y: cabinY,
            width: cabinWidth,
            height: cabinHeight
        )
        path.addRoundedRect(
            in: cabin,
            cornerSize: CGSize(width: cabinHeight * 0.45, height: cabinHeight * 0.45)
        )

        let platformY = cabin.maxY + h * 0.08
        path.addRoundedRect(
            in: CGRect(x: w * 0.18, y: platformY, width: w * 0.64, height: h * 0.08),
            cornerSize: CGSize(width: 2, height: 2)
        )

        let baseY = h * 0.88
        let leftTop = CGPoint(x: w * 0.34, y: platformY + h * 0.06)
        let rightTop = CGPoint(x: w * 0.66, y: platformY + h * 0.06)
        let legWidth = max(1.5, w * 0.07)

        func addLeg(from start: CGPoint, to end: CGPoint) {
            var leg = Path()
            leg.move(to: start)
            leg.addLine(to: end)
            path.addPath(leg.strokedPath(.init(lineWidth: legWidth, lineCap: .round)))
        }

        addLeg(from: leftTop, to: CGPoint(x: w * 0.18, y: baseY))
        addLeg(from: leftTop, to: CGPoint(x: w * 0.46, y: baseY))
        addLeg(from: rightTop, to: CGPoint(x: w * 0.54, y: baseY))
        addLeg(from: rightTop, to: CGPoint(x: w * 0.82, y: baseY))

        path.addRoundedRect(
            in: CGRect(x: w * 0.10, y: baseY, width: w * 0.80, height: h * 0.08),
            cornerSize: CGSize(width: 2, height: 2)
        )
        return path
    }
}


struct EventAppearanceSettingsView: View {
    @StateObject private var appearanceStore = AssignmentAppearanceStore.shared

    var body: some View {
        List {
            Section {
                Text(
                    "У каждого события своя иконка и свой цвет. Можно выбрать один из трёх готовых вариантов, любой SF Symbol по имени или собрать свою иконку из нескольких SF Symbols."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("События") {
                ForEach(AssignmentEventType.allCases) { type in
                    NavigationLink {
                        EventAppearanceEditorView(eventType: type)
                    } label: {
                        HStack(spacing: 12) {
                            AssignmentEventIconView(
                                eventType: type,
                                style: appearanceStore.style(for: type),
                                size: 25
                            )
                            .frame(width: 32)

                            Text(type.title)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Настройка событий")
        .navigationBarTitleDisplayMode(.inline)
    }
}


private struct EventAppearanceEditorView: View {
    let eventType: AssignmentEventType

    @ObservedObject private var appearanceStore = AssignmentAppearanceStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AssignmentIconStyle

    private let symbolSuggestions = [
        "airplane", "airplane.circle.fill", "airplane.departure", "airplane.arrival",
        "suitcase.fill", "suitcase.rolling.fill", "house.fill", "building.2.fill",
        "bed.double.fill", "moon.zzz.fill", "tent.fill", "tree.fill", "water.waves",
        "drop.fill", "graduationcap.fill", "book.closed.fill", "stethoscope",
        "cross.case.fill", "heart.text.square.fill", "checklist", "checkmark.square.fill",
        "doc.text.fill", "list.clipboard.fill", "briefcase.fill", "calendar",
        "calendar.badge.minus", "sun.max.fill", "person.fill", "person.crop.circle",
        "clock.fill", "location.fill", "link", "star.fill", "flag.fill", "bolt.fill"
    ]

    init(eventType: AssignmentEventType) {
        self.eventType = eventType
        _draft = State(initialValue: AssignmentAppearanceStore.shared.style(for: eventType))
    }

    var body: some View {
        Form {
            Section("Предпросмотр") {
                HStack(spacing: 18) {
                    AssignmentEventIconView(
                        eventType: eventType,
                        style: draft,
                        size: 32
                    )
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(eventType.title)
                            .font(.headline)
                        Text("Реальный размер в карточке")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    AssignmentEventIconView(
                        eventType: eventType,
                        style: draft,
                        size: 22
                    )
                }
            }

            Section("Источник иконки") {
                Picker("Источник", selection: $draft.mode) {
                    ForEach(AssignmentIconMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch draft.mode {
            case .preset:
                presetEditor
            case .sfSymbol:
                singleSymbolEditor
            case .composite:
                compositeEditor
            }

            Section {
                Button("Вернуть стандартную иконку", role: .destructive) {
                    draft = .defaultStyle(for: eventType)
                    appearanceStore.reset(eventType)
                }
            }
        }
        .navigationTitle(eventType.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Сохранить") {
                    appearanceStore.setStyle(draft, for: eventType)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var presetEditor: some View {
        Section("Три варианта") {
            let presets = AssignmentIconPresetLibrary.presets(for: eventType)
            ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                Button {
                    draft.presetIndex = index
                } label: {
                    HStack(spacing: 12) {
                        var preview = draft
                        AssignmentEventIconView(
                            eventType: eventType,
                            style: {
                                preview.mode = .preset
                                preview.presetIndex = index
                                return preview
                            }(),
                            size: 27
                        )
                        .frame(width: 36)

                        Text(preset.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if draft.presetIndex == index {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }
            }

            ColorPicker(
                "Цвет иконки",
                selection: Binding(
                    get: { draft.color.color },
                    set: { draft.color = AssignmentIconColor($0) }
                ),
                supportsOpacity: false
            )
        }
    }

    private var singleSymbolEditor: some View {
        Section("SF Symbol") {
            TextField("Например: airplane", text: $draft.symbolName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if UIImage(systemName: draft.symbolName) == nil {
                Label(
                    "Такого SF Symbol на этой версии iOS не найдено.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            ColorPicker(
                "Цвет символа",
                selection: Binding(
                    get: { draft.color.color },
                    set: { draft.color = AssignmentIconColor($0) }
                ),
                supportsOpacity: false
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(symbolSuggestions, id: \.self) { symbol in
                        Button {
                            draft.symbolName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var compositeEditor: some View {
        Group {
            Section {
                Text(
                    "До трёх слоёв. У каждого слоя можно отдельно изменить SF Symbol, цвет, размер, положение и поворот."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            ForEach(Array(draft.layers.indices), id: \.self) { index in
                Section("Слой \(index + 1)") {
                    TextField(
                        "Имя SF Symbol",
                        text: Binding(
                            get: { draft.layers[index].symbolName },
                            set: { draft.layers[index].symbolName = $0 }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    ColorPicker(
                        "Цвет",
                        selection: Binding(
                            get: { draft.layers[index].color.color },
                            set: { draft.layers[index].color = AssignmentIconColor($0) }
                        ),
                        supportsOpacity: false
                    )

                    LabeledContent("Размер") {
                        Slider(
                            value: Binding(
                                get: { draft.layers[index].scale },
                                set: { draft.layers[index].scale = $0 }
                            ),
                            in: 0.45...1.7
                        )
                        .frame(width: 180)
                    }

                    LabeledContent("По горизонтали") {
                        Slider(
                            value: Binding(
                                get: { draft.layers[index].xOffset },
                                set: { draft.layers[index].xOffset = $0 }
                            ),
                            in: -12...12
                        )
                        .frame(width: 180)
                    }

                    LabeledContent("По вертикали") {
                        Slider(
                            value: Binding(
                                get: { draft.layers[index].yOffset },
                                set: { draft.layers[index].yOffset = $0 }
                            ),
                            in: -12...12
                        )
                        .frame(width: 180)
                    }

                    LabeledContent("Поворот") {
                        Slider(
                            value: Binding(
                                get: { draft.layers[index].rotation },
                                set: { draft.layers[index].rotation = $0 }
                            ),
                            in: -45...45
                        )
                        .frame(width: 180)
                    }

                    if draft.layers.count > 1 {
                        Button("Удалить слой", role: .destructive) {
                            draft.layers.remove(at: index)
                        }
                    }
                }
            }

            if draft.layers.count < 3 {
                Section {
                    Button {
                        draft.layers.append(
                            AssignmentIconLayer(
                                symbolName: "star.fill",
                                color: draft.color
                            )
                        )
                    } label: {
                        Label("Добавить слой", systemImage: "square.stack.3d.up.badge.plus")
                    }
                }
            }
        }
    }
}
