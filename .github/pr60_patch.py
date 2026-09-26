from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    text = text.replace(old, new, 1)


replace_once(
    """        .overlay(alignment: .top) {
            activeTimeEditor
                .zIndex(10_000)
        }
""",
    """        .overlay {
            ZStack(alignment: .top) {
                if case .time = focusedField {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = nil
                        }
                        .zIndex(1)
                }

                activeTimeEditor
                    .zIndex(2)
            }
        }
""",
    "time editor overlay",
)

count = text.count(".systemFont(ofSize: 15, weight: .semibold)")
if count != 3:
    raise SystemExit(f"inline font match count: {count}")
text = text.replace(
    ".systemFont(ofSize: 15, weight: .semibold)",
    ".systemFont(ofSize: 14, weight: .semibold)",
)

replace_once(
    "                        font: .boldSystemFont(ofSize: 22)\n",
    "                        font: .boldSystemFont(ofSize: 20)\n",
    "assignment inline font",
)
replace_once(
    "        .font(.title2.bold())\n",
    "        .font(.title3.bold())\n",
    "assignment title font",
)

replace_once(
    """    private func timeEditorAlignment(for point: DutyEditPoint) -> Alignment {
        switch point {
        case .workStart, .workEnd:
            return .topLeading
        case .engineOn, .engineOff:
            return .top
        case .takeoff, .landing:
            return .topTrailing
        }
    }

    private func editPopoverWidth(for field: DutyFocusedField) -> CGFloat {
""",
    """    private func timeEditorAlignment(for point: DutyEditPoint) -> Alignment {
        switch point {
        case .workStart, .workEnd:
            return .topLeading
        case .engineOn, .engineOff:
            return .top
        case .takeoff, .landing:
            return .topTrailing
        }
    }

    private func timeEditorTopPadding(for index: Int) -> CGFloat {
        if index == 0 {
            return 142
        }

        return 76 + CGFloat(index - 1) * 230
    }

    private func editPopoverWidth(for field: DutyFocusedField) -> CGFloat {
""",
    "time editor vertical placement helper",
)

replace_once(
    "            .padding(.top, 52)\n",
    "            .padding(.top, timeEditorTopPadding(for: index))\n",
    "time editor top padding",
)

path.write_text(text)

Path("AppVersion.swift").write_text(
    'enum AppVersion {\n    static let number = 60\n    static let label = "Версия 60"\n}\n'
)

package = Path("Package.swift")
p = package.read_text()
if 'displayVersion: "59"' not in p or 'bundleVersion: "59"' not in p:
    raise SystemExit("version 59 markers not found in Package.swift")
p = p.replace('displayVersion: "59"', 'displayVersion: "60"')
p = p.replace('bundleVersion: "59"', 'bundleVersion: "60"')
package.write_text(p)
