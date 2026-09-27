from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()
old = """                                if editorIsActive {
                                    dismissEditorSignal += 1
                                } else {
                                    onClose()
                                }
"""
new = """                                if editorIsActive {
                                    dismissEditorSignal += 1
                                } else if !editModeIsActive {
                                    onClose()
                                }
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f"outside margin tap guard: expected 1 occurrence, found {count}")
path.write_text(text.replace(old, new, 1))
