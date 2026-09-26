from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


path = Path("AppViews.swift")
text = path.read_text()
old = '''    private func stableInlineEditor(\n        text: Binding<String>,\n        isActive: Binding<Bool>,\n        prefix: String = "",\n        keyboardType: UIKeyboardType,\n        capitalization: UITextAutocapitalizationType,\n        maxLength: Int? = nil\n    ) -> some View {\n        ZStack {\n            Text(prefix + text.wrappedValue)\n                .font(.subheadline.weight(.semibold))\n                .foregroundStyle(.primary)\n                .lineLimit(1)\n                .minimumScaleFactor(0.7)\n                .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)\n                .background {\n                    if isActive.wrappedValue {\n                        RoundedRectangle(cornerRadius: 3)\n                            .fill(Color.accentColor.opacity(0.22))\n                    }\n                }\n\n            InlineSelectAllTextField(\n                text: text,\n                isActive: isActive,\n                keyboardType: keyboardType,\n                capitalization: capitalization,\n                textAlignment: .center,\n                font: .systemFont(ofSize: 15, weight: .semibold),\n                maxLength: maxLength\n            )\n            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)\n            .opacity(0.01)\n            .allowsHitTesting(false)\n        }\n        .frame(height: 18)\n    }\n'''
new = '''    private func stableInlineEditor(\n        text: Binding<String>,\n        isActive: Binding<Bool>,\n        prefix: String = "",\n        keyboardType: UIKeyboardType,\n        capitalization: UITextAutocapitalizationType,\n        maxLength: Int? = nil\n    ) -> some View {\n        ZStack {\n            HStack(spacing: 0) {\n                if !prefix.isEmpty {\n                    Text(prefix)\n                        .font(.subheadline.weight(.semibold))\n                        .foregroundStyle(.primary)\n                }\n\n                Text(text.wrappedValue)\n                    .font(.subheadline.weight(.semibold))\n                    .foregroundStyle(.primary)\n                    .lineLimit(1)\n                    .minimumScaleFactor(0.7)\n                    .padding(.horizontal, 2)\n                    .background {\n                        if isActive.wrappedValue {\n                            RoundedRectangle(cornerRadius: 3)\n                                .fill(Color.accentColor.opacity(0.22))\n                        }\n                    }\n            }\n            .fixedSize(horizontal: true, vertical: false)\n            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)\n\n            InlineSelectAllTextField(\n                text: text,\n                isActive: isActive,\n                keyboardType: keyboardType,\n                capitalization: capitalization,\n                textAlignment: .center,\n                font: .systemFont(ofSize: 15, weight: .semibold),\n                maxLength: maxLength\n            )\n            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)\n            .opacity(0.01)\n            .allowsHitTesting(false)\n        }\n        .frame(height: 18)\n    }\n'''
text = replace_once(text, old, new, "stableInlineEditor")
path.write_text(text)

path = Path("AppVersion.swift")
text = path.read_text()
text = replace_once(text, "static let number = 62", "static let number = 63", "AppVersion number")
text = replace_once(text, 'static let label = "Версия 62"', 'static let label = "Версия 63"', "AppVersion label")
path.write_text(text)

path = Path("Package.swift")
text = path.read_text()
text = replace_once(text, 'displayVersion: "62"', 'displayVersion: "63"', "displayVersion")
text = replace_once(text, 'bundleVersion: "62"', 'bundleVersion: "63"', "bundleVersion")
path.write_text(text)
