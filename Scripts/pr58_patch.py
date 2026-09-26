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
    '''                ) {
                    
                    Text(
                        monthTitle(
''',
    '''                ) {
                    
                    HStack {
                        Text(AppVersion.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    
                    Text(
                        monthTitle(
''',
    "home version label",
)

replace_once(
    '''                    if focusedField == .assignment {
                        InlineSelectAllTextField(
                            text: $assignmentNumber,
                            isActive: focusBinding(.assignment),
                            keyboardType: .numberPad,
                            capitalization: .none,
                            textAlignment: .center,
                            font: .boldSystemFont(ofSize: 22)
                        )
                        .frame(width: 112, height: 30)
                    } else {
                        Text(assignmentNumber.isEmpty ? "—" : assignmentNumber)
                    }
''',
    '''                    InlineSelectAllTextField(
                        text: $assignmentNumber,
                        isActive: focusBinding(.assignment),
                        keyboardType: .numberPad,
                        capitalization: .none,
                        textAlignment: .center,
                        font: .boldSystemFont(ofSize: 22)
                    )
                    .frame(width: 112, height: 30)
''',
    "stable assignment number field",
)

path.write_text(text)
