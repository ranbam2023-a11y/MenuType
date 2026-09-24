import AppKit
import ApplicationServices
import Combine
import SwiftUI

/// Owns the menu bar item, the popover, and the key monitors.
final class StatusController: NSObject, NSPopoverDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let engine = TypingEngine()

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var idleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// How long global capture stays on with no keystrokes before it switches itself off.
    private let autoDisarmAfter: TimeInterval = 60

    override init() {
        super.init()
        configureStatusItem()
        configurePopover()
        engine.requestArm = { [weak self] armed in self?.setArmed(armed) }
        observeEngine()
        updateTitle()
    }

    deinit {
        removeLocalMonitor()
        removeGlobalMonitor()
        idleTimer?.invalidate()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
        button.imagePosition = .noImage
        button.toolTip = "MenuType — click to see your speed and accuracy"
    }

    /// `preferredColorScheme` handles SwiftUI, but dynamic `NSColor`s resolve
    /// against the *view's* effective appearance, so set that too — otherwise
    /// the panel can render dark while claiming to be light.
    private func applyAppearance() {
        let name: NSAppearance.Name?
        switch engine.appearance {
        case .system: name = nil
        case .light: name = .aqua
        case .dark: name = .darkAqua
        }
        popover.contentViewController?.view.appearance = name.flatMap(NSAppearance.init(named:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = PopoverView(engine: engine, stats: engine.stats)
        popover.contentViewController = NSHostingController(rootView: root)
        applyAppearance()
    }

    private func observeEngine() {
        // Any of these change what the menu bar shows.
        let publishers: [AnyPublisher<Void, Never>] = [
            engine.$tape.map { _ in () }.eraseToAnyPublisher(),
            engine.$typed.map { _ in () }.eraseToAnyPublisher(),
            engine.$isComplete.map { _ in () }.eraseToAnyPublisher(),
            engine.$isArmed.map { _ in () }.eraseToAnyPublisher(),
            engine.$isEngaged.map { _ in () }.eraseToAnyPublisher(),
            engine.$isPanelOpen.map { _ in () }.eraseToAnyPublisher(),
            engine.$appearance.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(publishers)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTitle()
                self?.applyAppearance()
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu bar rendering

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        button.attributedTitle = statusTitle()
        button.needsDisplay = true
    }

    private func statusTitle() -> NSAttributedString {
        let output = NSMutableAttributedString()
        let chars = engine.targetChars

        if engine.isArmed {
            let dot: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.systemGreen,
                .baselineOffset: 1.5,
            ]
            output.append(NSAttributedString(string: "● ", attributes: dot))
        }

        let regular = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let strong = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

        for (index, char) in chars.enumerated() {
            var attributes: [NSAttributedString.Key: Any]

            if engine.isComplete {
                // Finished word: full green with a check.
                attributes = [.font: strong, .foregroundColor: NSColor.systemGreen]
            } else if index < engine.typed.count {
                if engine.typed[index] == char {
                    attributes = [.font: strong, .foregroundColor: NSColor.labelColor]
                } else {
                    attributes = [.font: strong, .foregroundColor: NSColor.systemRed]
                }
            } else if index == engine.typed.count && engine.isLive {
                // Cursor sits on the character you're about to type.
                attributes = [
                    .font: strong,
                    .foregroundColor: NSColor.labelColor,
                    .backgroundColor: NSColor.selectedContentBackgroundColor.withAlphaComponent(0.5),
                ]
            } else {
                attributes = [.font: regular, .foregroundColor: NSColor.secondaryLabelColor]
            }

            output.append(NSAttributedString(string: String(char), attributes: attributes))
        }

        if engine.isComplete {
            let check: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.systemGreen,
            ]
            output.append(NSAttributedString(string: "  ✓", attributes: check))
        }

        return output
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        engine.panelDidOpen()
        applyAppearance()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        installLocalMonitor()
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        removeLocalMonitor()
        engine.panelDidClose()
        updateTitle()
    }

    // MARK: - Key capture

    /// Popover typing: no permissions needed, only fires for our own windows.
    private func installLocalMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.engine.handle(event: event) ? nil : event
        }
    }

    private func removeLocalMonitor() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    /// "Type anywhere": requires Accessibility permission.
    private func installGlobalMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            // The local monitor already handled it if the popover is open.
            guard !self.popover.isShown else { return }
            self.engine.handle(event: event, global: true)
        }
    }

    private func removeGlobalMonitor() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    // MARK: - Arming

    private func setArmed(_ armed: Bool) {
        guard armed else {
            engine.setArmed(false)
            removeGlobalMonitor()
            stopIdleTimer()
            updateTitle()
            return
        }

        guard ensureAccessibilityPermission() else {
            engine.armWarning = "Grant Accessibility access to type without opening the menu. Typing in the popover still works."
            return
        }

        engine.armWarning = nil
        engine.setArmed(true)
        installGlobalMonitor()
        startIdleTimer()
        updateTitle()
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        return trusted
    }

    private func startIdleTimer() {
        stopIdleTimer()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.engine.isArmed else { return }
            let last = self.engine.lastInputAt ?? Date()
            if Date().timeIntervalSince(last) > self.autoDisarmAfter {
                // Don't keep listening to the whole system if you wandered off.
                self.setArmed(false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
}
