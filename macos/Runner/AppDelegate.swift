/// Configures macOS application lifecycle behavior for the Flutter runner.
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Requests app termination when the user closes its only window.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  /// Allows the app to participate in macOS secure state restoration.
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
