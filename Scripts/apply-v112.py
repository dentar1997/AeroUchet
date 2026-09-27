from pathlib import Path

app_path = Path("AppViews.swift")
version_path = Path("AppVersion.swift")

text = app_path.read_text(encoding="utf-8")


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected 1 match, found {count}")
    return source.replace(old, new, 1)


# Все числовые значения верхней строки лега используют тот же размер/вес,
# что и часы в крутилках. Заголовок «Задание на полёт №…» передаёт свой
# title3-шрифт явно и поэтому остаётся без изменений.
text = replace_once(
    text,
    """        textFont: Font = .subheadline.weight(.semibold),
        inputFont: UIFont = .systemFont(ofSize: 15, weight: .semibold),
""",
    """        textFont: Font = .caption.bold(),
        inputFont: UIFont = .systemFont(ofSize: 12, weight: .bold),
""",
    "stableInlineEditor typography",
)

# Переключение источника расчётного времени — это переключатель, а не выбор
# активной ячейки. После нажатия квадрат не остаётся в состоянии фокуса.
text = replace_once(
    text,
    """            onActivate: { focusedField = .calculatedTime(index) },
            onToggleSource: { toggleCalculatedTimeSource(index) },
            onRestore: { restoreOriginalCalculatedTime(index) }
""",
    """            onActivate: { focusedField = .calculatedTime(index) },
            onToggleSource: {
                focusedField = nil
                toggleCalculatedTimeSource(index)
            },
            onRestore: { restoreOriginalCalculatedTime(index) }
""",
    "calculated source focus",
)

# Итоговые длительности в карточке задания приводим к той же цифровой
# типографике, что часы/минуты крутилок.
time_start = text.index("    private func timeAndNight(total: Int, night: Int) -> some View {")
time_end = text.index("\n    // Уровень 2: отдельная карточка каждого лега.", time_start)
time_segment = text[time_start:time_end]
old_font = "                .font(.subheadline.weight(.semibold))\n                .foregroundStyle(.primary)"
new_font = "                .font(.caption.bold())\n                .monospacedDigit()\n                .foregroundStyle(.primary)"
if time_segment.count(old_font) != 2:
    raise RuntimeError(
        f"timeAndNight typography: expected 2 matches, found {time_segment.count(old_font)}"
    )
time_segment = time_segment.replace(old_font, new_font)
text = text[:time_start] + time_segment + text[time_end:]

# Значение в карточке разделённой смены — та же цифровая типографика.
value_start = text.index(
    "    private func legValueCard(\n        title: String,\n        value: String,"
)
value_end = text.index(
    "\n    private func legValueCard(\n        title: String,\n        total: Int,",
    value_start,
)
value_segment = text[value_start:value_end]
value_segment = replace_once(
    value_segment,
    """            Text(value)
                .font(.subheadline.weight(.semibold))
""",
    """            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
""",
    "legValueCard typography",
)
text = text[:value_start] + value_segment + text[value_end:]

# Полностью заменяем компактный блок расчётного времени. Квадрат и надпись
# «Из таблицы» имеют только два обычных цвета — бирюзовый или жёлтый — без
# приглушённого active-состояния. В ручном режиме квадрат закреплён слева,
# а часы всегда занимают один и тот же центр 130-точечной области.
calc_start = text.index("private struct InlineCalculatedTimeValue: View {")
calc_end = text.index("\nprivate struct DutyEditSnapshot: Equatable {", calc_start)
new_calc = r'''private struct InlineCalculatedTimeValue: View {
    let displayed: String
    let originalMinutes: Int
    @Binding var minutes: Int
    let isEditing: Bool
    let isActive: Bool
    let isUnscheduled: Bool
    let usesTable: Bool
    let hasChanges: Bool
    let onActivate: () -> Void
    let onToggleSource: () -> Void
    let onRestore: () -> Void

    @State private var activePart: Part?
    private enum Part { case hour, minute }

    private var hour: Int { minutes / 60 }
    private var minute: Int { minutes % 60 }

    private var sourceColor: Color {
        hasChanges ? DutyEditPalette.changed : Color.accentColor
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("Расчётное время")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if !isEditing {
                Text(displayed)
                    .font(
                        displayed == "Нет данных"
                            ? .subheadline.weight(.semibold)
                            : .caption.bold()
                    )
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(height: 18)
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
            if isEditing && isActive {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 17, height: 17)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(!hasChanges)
                .padding(.bottom, 6)
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
                width: 19, hitWidth: 33, hitOffset: 0, hitHeight: 48,
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
        .frame(width: 41, height: 18)
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
'''
text = text[:calc_start] + new_calc + text[calc_end:]

app_path.write_text(text, encoding="utf-8")

version = version_path.read_text(encoding="utf-8")
version = replace_once(
    version,
    """    static let number = 111
    static let label = "Версия 111"
""",
    """    static let number = 112
    static let label = "Версия 112"
""",
    "AppVersion",
)
version_path.write_text(version, encoding="utf-8")

print("Version 112 patch applied successfully")
