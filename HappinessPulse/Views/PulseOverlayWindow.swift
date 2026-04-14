import AppKit
import SwiftUI

final class PulseOverlayWindowController {
    private let model = OverlayPresentationModel()
    private var window: NSWindow?
    private var focusTimer: Timer?

    func present(content: AnyView) {
        ensureWindow()
        model.setInitial(content: content)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startFocusAssertionTimer()
    }

    func transition(content: AnyView) {
        model.transition(content: content)
    }

    func dismiss(completion: @escaping () -> Void) {
        model.dismiss {
            self.focusTimer?.invalidate()
            self.focusTimer = nil
            self.window?.orderOut(nil)
            completion()
        }
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let window = PulseBlockingWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovable = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: OverlayRootView(model: model))
        self.window = window
    }

    func handleScreenConfigurationChange() {
        guard let window else { return }
        let frame = NSScreen.main?.frame ?? window.frame
        window.setFrame(frame, display: true)
        window.center()
    }

    private func startFocusAssertionTimer() {
        focusTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, let window = self.window else { return }
            if !window.isKeyWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        focusTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

final class PulseBlockingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        // Intentionally ignore Escape and cancel operations.
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 { return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class OverlayPresentationModel: ObservableObject {
    @Published var content: AnyView = AnyView(EmptyView())
    @Published var contentID = UUID()
    @Published var overlayVisible = false
    @Published var cardVisible = false

    func setInitial(content: AnyView) {
        self.content = content
        contentID = UUID()
        overlayVisible = false
        cardVisible = false

        withAnimation(.easeOut(duration: 0.4)) {
            overlayVisible = true
        }
        withAnimation(.interpolatingSpring(stiffness: 170, damping: 16).delay(0.1)) {
            cardVisible = true
        }
    }

    func transition(content: AnyView) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.content = content
            self.contentID = UUID()
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cardVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.overlayVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }
}

struct OverlayRootView: View {
    @ObservedObject var model: OverlayPresentationModel

    var body: some View {
        ZStack {
            VisualEffectBackdropView()
                .opacity(model.overlayVisible ? 1 : 0)
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .opacity(model.overlayVisible ? 1 : 0)

            model.content
                .id(model.contentID)
                .opacity(model.cardVisible ? 1 : 0)
                .scaleEffect(model.cardVisible ? 1 : 0.9)
                .offset(y: model.cardVisible ? 0 : 30)
                .transition(.opacity)
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectBackdropView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: .zero)
        view.blendingMode = .behindWindow
        view.state = .active
        updateMaterial(for: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        updateMaterial(for: nsView)
    }

    private func updateMaterial(for view: NSVisualEffectView) {
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        if reduceTransparency {
            view.material = .windowBackground
            view.state = .inactive
            return
        }

        view.state = .active
        if #available(macOS 12.0, *) {
            view.material = .fullScreenUI
        } else {
            view.material = .hudWindow
        }
    }
}
