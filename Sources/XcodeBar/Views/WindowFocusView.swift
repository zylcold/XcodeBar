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
        var attempts = 0
        func tryFocus() {
            attempts += 1
            guard let window = self.window else {
                if attempts < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: tryFocus)
                }
                return
            }
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: tryFocus)
    }
}
