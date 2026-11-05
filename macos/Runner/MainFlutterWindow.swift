/// Creates the macOS window that hosts the Flutter view and its plugins.
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Installs the Flutter view controller and registers generated plugins.
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
