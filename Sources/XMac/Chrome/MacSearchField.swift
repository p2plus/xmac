import AppKit
import SwiftUI

struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    var focusTick: Int
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = String(localized: "Search", comment: "Search field placeholder")
        field.delegate = context.coordinator
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        if field.stringValue != text {
            field.stringValue = text
        }
        let placeholder = String(localized: "Search", comment: "Search field placeholder")
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        guard focusTick > 0, focusTick != context.coordinator.lastTick else { return }
        context.coordinator.lastTick = focusTick
        // AppKit ignores makeFirstResponder during the current update pass.
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void
        var lastTick = 0

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            let value = field.stringValue
            guard text.wrappedValue != value else { return }
            text.wrappedValue = value
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            onSubmit()
            return true
        }
    }
}
