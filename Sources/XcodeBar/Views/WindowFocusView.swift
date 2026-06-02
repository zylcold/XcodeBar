import AppKit
import SwiftUI

struct WindowFocusView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        FocusHostingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? FocusHostingView)?.scheduleFocus()
    }
}

private final class FocusHostingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleFocus()
    }

    func scheduleFocus() {
        focus(after: 0.02)
        focus(after: 0.15)
        focus(after: 0.35)
    }

    private func focus(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let window = self?.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
