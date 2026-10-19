import SwiftUI
import UIKit
import DSHProtocol

/// Hidden terminal IME field. While `markedTextRange != nil` the ZWSP
/// sentinel is not restored, so CJK composition is not committed as raw
/// Latin letters.
struct TerminalImeField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var enabled: Bool
    var onCommitted: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.text = text
        field.keyboardType = .asciiCapable
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.returnKeyType = .default
        field.tintColor = .clear
        field.textColor = .clear
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.accessibilityLabel = L.terminalKeyboardInput()
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = enabled
        field.accessibilityLabel = L.terminalKeyboardInput()
        if ImeComposition.shouldRewriteText(isMarked: field.markedTextRange != nil), field.text != text {
            field.text = text
        }
        if focused {
            if !field.isFirstResponder { field.becomeFirstResponder() }
        } else if field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TerminalImeField

        init(_ parent: TerminalImeField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            commitIfUnmarked(field)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard ImeComposition.shouldRewriteText(isMarked: textField.markedTextRange != nil) else {
                return false
            }
            parent.onCommitted((textField.text ?? "") + "\n")
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.focused { parent.focused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focused { parent.focused = false }
        }

        private func commitIfUnmarked(_ field: UITextField) {
            guard ImeComposition.shouldRewriteText(isMarked: field.markedTextRange != nil) else { return }
            parent.onCommitted(field.text ?? "")
        }
    }
}
