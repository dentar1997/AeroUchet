from pathlib import Path

path = Path("AppViews.swift")
s = path.read_text()


def rep(old: str, new: str, label: str) -> None:
    global s
    if old not in s:
        raise SystemExit(f"missing target: {label}")
    s = s.replace(old, new, 1)


rep(
    "    @State private var dragOffset: CGFloat = 0\n",
    "    @State private var dragOffset: CGFloat = 0\n    @State private var editorIsActive = false\n",
    "overlay editor state",
)

rep(
    """                    DutyDetailView(
                        duty: duty,
                        onClose: onClose,
                        scrollsAsPage: true
                    )""",
    """                    DutyDetailView(
                        duty: duty,
                        onClose: onClose,
                        scrollsAsPage: true,
                        onEditorFocusChange: { editorIsActive = $0 }
                    )""",
    "overlay callback",
)

rep(
    "                .simultaneousGesture(dismissDrag(in: geometry.size.height))",
    """                .simultaneousGesture(
                    dismissDrag(
                        in: geometry.size.height,
                        enabled: !editorIsActive
                    )
                )""",
    "dismiss gesture call",
)

rep(
    "    private func dismissDrag(in height: CGFloat) -> some Gesture {\n",
    "    private func dismissDrag(in height: CGFloat, enabled: Bool) -> some Gesture {\n",
    "dismiss signature",
)

rep(
    "            .onChanged { value in\n                // Вниз карточка следует за пальцем полностью.",
    """            .onChanged { value in
                guard enabled else {
                    dragOffset = 0
                    return
                }

                // Вниз карточка следует за пальцем полностью.""",
    "dismiss onChanged guard",
)

rep(
    "            .onEnded { value in\n                let predicted = max(",
    """            .onEnded { value in
                guard enabled else {
                    dragOffset = 0
                    return
                }

                let predicted = max(""",
    "dismiss onEnded guard",
)

rep(
    """    let duty: FlightDuty
    let onClose: (() -> Void)?
    let scrollsAsPage: Bool

    init(duty: FlightDuty, onClose: (() -> Void)? = nil, scrollsAsPage: Bool = false) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
    }""",
    """    let duty: FlightDuty
    let onClose: (() -> Void)?
    let scrollsAsPage: Bool
    let onEditorFocusChange: ((Bool) -> Void)?

    init(
        duty: FlightDuty,
        onClose: (() -> Void)? = nil,
        scrollsAsPage: Bool = false,
        onEditorFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.duty = duty
        self.onClose = onClose
        self.scrollsAsPage = scrollsAsPage
        self.onEditorFocusChange = onEditorFocusChange
    }""",
    "DutyDetailView init",
)

rep(
    """        .onChange(of: draft) { _ in recordEdit() }
        .onChange(of: assignmentNumber) { _ in recordEdit() }
        .environment(\.timeZone, moscowTimeZone)""",
    """        .onChange(of: draft) { _ in recordEdit() }
        .onChange(of: assignmentNumber) { _ in recordEdit() }
        .onChange(of: focusedField) { value in
            onEditorFocusChange?(value != nil)
        }
        .onDisappear {
            onEditorFocusChange?(false)
        }
        .environment(\.timeZone, moscowTimeZone)""",
    "focus callback",
)

rep(
    """                legCard(
                    duty.legs[index],
                    index: index,
                    workEnd: duty.workIntervals[index].end
                )""",
    """                legCard(
                    duty.legs[index],
                    index: index,
                    workEnd: duty.workIntervals[index].end
                )
                .zIndex(legEditorZIndex(index))""",
    "leg zindex",
)

marker = """    private func headerEditorZIndex(_ index: Int) -> Double {
        switch focusedField {
        case .legNumber(let value),
             .route(let value),
             .flightKind(let value),
             .aircraft(let value),
             .registration(let value),
             .calculatedTime(let value):
            return value == index ? 1000 : 0
        default:
            return 0
        }
    }
"""
if marker not in s:
    raise SystemExit("missing target: headerEditorZIndex")
s = s.replace(
    marker,
    marker
    + """
    private func legEditorZIndex(_ index: Int) -> Double {
        switch focusedField {
        case .legNumber(let value),
             .route(let value),
             .flightKind(let value),
             .aircraft(let value),
             .registration(let value),
             .calculatedTime(let value),
             .time(let value, _):
            return value == index ? 2000 : 0
        default:
            return 0
        }
    }
""",
    1,
)

rep(
    """        case .workStart, .engineOn, .takeoff:
            return 46""",
    """        case .workStart, .engineOn, .takeoff:
            return -205""",
    "top time editor offset",
)

rep(
    """        case .calculatedTime:
            return 190""",
    """        case .calculatedTime:
            return 230""",
    "calculated width helper",
)

rep(
    "                        floatingEditor(width: 190) {",
    "                        floatingEditor(width: 230) {",
    "calculated editor width",
)

old_checkbox = """                                Button {
                                    toggleCalculatedTimeSource(index)
                                } label: {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .stroke(Color.secondary, lineWidth: 1.2)
                                                .frame(width: 20, height: 20)

                                            if draft[index].calculatedMinutesOverride == nil {
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(Color.accentColor)
                                                    .frame(width: 20, height: 20)

                                                Image(systemName: \"checkmark\")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }

                                        Text(\"Из таблицы\")
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)"""
new_checkbox = """                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.secondary, lineWidth: 1.2)
                                            .frame(width: 20, height: 20)

                                        if draft[index].calculatedMinutesOverride == nil {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(Color.accentColor)
                                                .frame(width: 20, height: 20)

                                            Image(systemName: \"checkmark\")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text(\"Из таблицы\")
                                }
                                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                                .zIndex(50)
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        toggleCalculatedTimeSource(index)
                                    }
                                )"""
rep(old_checkbox, new_checkbox, "calculated checkbox")

rep(
    """                                    .frame(width: 150, height: 108)
                                    .clipped()
                                    .frame(maxWidth: .infinity, alignment: .leading)""",
    """                                    .frame(width: 172, height: 118)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .zIndex(0)""",
    "calculated wheel hit area",
)

rep(
    """                                editPopoverHeader(
                                    \"Расчётное время\",
                                    extraHorizontalInset: 0
                                )""",
    """                                editPopoverHeader(
                                    \"Расчётное время\",
                                    extraHorizontalInset: 0
                                )
                                .zIndex(60)""",
    "calculated header zindex",
)

rep(
    """                                    .frame(
                                        width: 212,
                                        height: 172,
                                        alignment: .topLeading
                                    )
                                    .clipped()""",
    """                                    .frame(
                                        width: 212,
                                        height: 172,
                                        alignment: .topLeading
                                    )
                                    .clipped()
                                    .contentShape(Rectangle())""",
    "calendar hit area",
)

rep(
    """                                    .frame(width: 102, height: 172, alignment: .topLeading)
                                    .clipped()""",
    """                                    .frame(width: 102, height: 172, alignment: .topLeading)
                                    .clipped()
                                    .contentShape(Rectangle())""",
    "time wheel hit area",
)

path.write_text(s)
