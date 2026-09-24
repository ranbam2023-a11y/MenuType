import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
