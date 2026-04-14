import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let singleInstanceLock = SingleInstanceLock()
    private let pulseState = PulseState()
    private let logger = PulseLogger.shared
    private let submissionService = SubmissionService()
    private let fileManager = FileManager.default

    private let overlayController = PulseOverlayWindowController()
    private var showingUI = false
    private let arguments = ProcessInfo.processInfo.arguments

    private lazy var baseDirectory: URL = {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("homey-pulse", isDirectory: true)
    }()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            detectTranslocation()
            pulseState.cleanupFlags()

            if !isTestingBypassEnabled(), pulseState.hasSubmittedToday() {
                terminateSilently()
                return
            }

            let lockAcquired = singleInstanceLock.acquire()
            guard isTestingBypassEnabled() || pulseState.shouldShow(lockIsAvailable: lockAcquired) else {
                terminateSilently()
                return
            }

            subscribeToSystemNotifications()
            submissionService.retryPendingSubmissions { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.showPulseCard()
                }
            }
        } catch {
            terminateSilently()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        singleInstanceLock.release()
    }

    @objc private func handleWakeFromSleep() {
        guard !isTestingBypassEnabled() else { return }
        guard !pulseState.hasSubmittedToday() else { return }
        guard pulseState.shouldShow(lockIsAvailable: singleInstanceLock.lockAcquired) else { return }
        guard !showingUI else { return }
        showPulseCard()
    }

    private func showPulseCard() {
        showingUI = true
        let view = PulseCardView { [weak self] score, feedback, done in
            self?.submit(score: score, feedback: feedback, done: done)
        }
        overlayController.present(content: AnyView(view))
    }

    private func showConfirmationAndExit() {
        let message = motivationalMessages.randomElement() ?? "You're a star!"
        let view = ConfirmationView(message: message)
        overlayController.transition(content: AnyView(view))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.overlayController.dismiss {
                self?.terminateSilently()
            }
        }
    }

    private func submit(score: Int, feedback: String, done: @escaping () -> Void) {
        do {
            try pulseState.writeFlag()
            logger.info("Flag written for today's pulse submission")
        } catch {
            logger.error("Failed to write submission flag")
        }

        done()
        showConfirmationAndExit()

        submissionService.submitPulse(score: score, feedback: feedback) { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("Webhook submission completed")
            case let .failure(error):
                self?.logger.error("Webhook submission failed: \(error.localizedDescription)")
            }
        }
    }

    private func subscribeToWakeNotification() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func subscribeToSystemNotifications() {
        subscribeToWakeNotification()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleScreenParametersChanged() {
        overlayController.handleScreenConfigurationChange()
    }

    private func detectTranslocation() {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.contains("/AppTranslocation/") {
            logger.info("App appears translocated. Install script should remove quarantine attributes.")
        }
    }

    private func isTestingBypassEnabled() -> Bool {
        arguments.contains("--test")
    }

    private func terminateSilently() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        singleInstanceLock.release()
        NSApp.terminate(nil)
    }

    private let motivationalMessages = [
        "You're a star!",
        "That made our day!",
        "Homey loves you!",
        "High five!",
        "You legend!",
        "Brilliant energy today!",
        "You're making magic happen.",
        "Thanks for sharing your vibe.",
        "You're awesome.",
        "Keep shining!",
        "Today looks better already.",
        "Your voice matters.",
        "Smashing it!",
        "What a champion!",
        "You just boosted team morale."
    ]
}
