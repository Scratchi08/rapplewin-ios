import SwiftUI
import UIKit

/// Invisible first responder that receives both the on-screen keyboard (UIKeyInput) and a hardware keyboard
/// (arrows, Esc, Tab and Ctrl+letter arrive as key presses; printable keys arrive as text).
final class KeyCaptureUIView: UIView, UIKeyInput {
    var model: EmulatorModel?
    var softKeyboard = false {
        didSet { if softKeyboard != oldValue && isFirstResponder { reloadInputViews() } }
    }
    private let emptyInput = UIView(frame: .zero)   // zero-height input view = no on-screen keyboard

    // UITextInputTraits: plain, uncorrected typing
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no

    override init(frame: CGRect) {
        super.init(frame: frame)
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override var canBecomeFirstResponder: Bool { true }
    override var inputView: UIView? { softKeyboard ? nil : emptyInput }

    var hasText: Bool { true }                       // so Backspace always reaches deleteBackward()
    func insertText(_ text: String) {
        for u in text.unicodeScalars { model?.key(u.value == 10 ? 13 : u.value) }   // Return -> 13
    }
    func deleteBackward() { model?.key(8, code: 8) } // Apple II ← (^H) deletes in input lines

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key else { unhandled.insert(press); continue }
            switch key.keyCode {
            case .keyboardLeftArrow:  model?.key(8, code: 276)
            case .keyboardRightArrow: model?.key(21, code: 275)
            case .keyboardUpArrow:    model?.key(11, code: 273)
            case .keyboardDownArrow:  model?.key(10, code: 274)
            case .keyboardEscape:     model?.key(27, code: 27)
            case .keyboardTab:        model?.key(9, code: 9)
            default:
                if key.modifierFlags.contains(.control),
                   let u = key.charactersIgnoringModifiers.unicodeScalars.first {
                    model?.ctrlLatched = true
                    model?.key(u.value)
                } else {
                    unhandled.insert(press)          // printable: let UIKit deliver it through insertText
                }
            }
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }
}

struct KeyCapture: UIViewRepresentable {
    let model: EmulatorModel
    let active: Bool          // false while a sheet is open
    let softKeyboard: Bool

    func makeUIView(context: Context) -> KeyCaptureUIView {
        let v = KeyCaptureUIView()
        v.model = model
        return v
    }

    func updateUIView(_ v: KeyCaptureUIView, context: Context) {
        v.model = model
        v.softKeyboard = softKeyboard
        let wantActive = active
        DispatchQueue.main.async {
            if wantActive { if !v.isFirstResponder { v.becomeFirstResponder() } }
            else if v.isFirstResponder { v.resignFirstResponder() }
        }
    }
}
