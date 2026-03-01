import AppKit
import SwiftUI
import SwiftData

// MARK: - FloatingPanel (NSPanel subclass)

/// A Stickies-like floating panel that sits above all windows.
/// Content is SwiftUI via NSHostingView.
final class FloatingPanel: NSPanel {

    override var canBecomeKey: Bool { true }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .nonactivatingPanel,
                .hudWindow           // gives the frosted glass HUD look
            ],
            backing: .buffered,
            defer: false
        )

        title = "Tasks"
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Restore saved frame, otherwise centre on screen
        if let savedFrame = UserDefaults.standard.string(forKey: "floatingPanelFrame") {
            let frame = NSRectFromString(savedFrame)
            if frame != .zero {
                setFrame(frame, display: false)
            } else {
                center()
            }
        } else {
            center()
        }
    }

    override func close() {
        // Save frame before hiding
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "floatingPanelFrame")
        orderOut(nil)  // hide, don't destroy
    }
}

// MARK: - FloatingPanelController

/// Manages the floating panel lifecycle.
/// Owned by the macOS App and injected as an @EnvironmentObject.
@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    @Published var isVisible = false

    private var panel: FloatingPanel?
    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let ctx = modelContext else { return }

        if panel == nil {
            panel = FloatingPanel()
            let content = FloatingPanelView()
                .environment(\.modelContext, ctx)
                .environmentObject(AuthManager.shared)

            let hosting = NSHostingView(rootView: content)
            hosting.frame = panel!.contentView!.bounds
            hosting.autoresizingMask = [.width, .height]
            panel!.contentView?.addSubview(hosting)
        }

        panel?.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.close()
        isVisible = false
    }
}
