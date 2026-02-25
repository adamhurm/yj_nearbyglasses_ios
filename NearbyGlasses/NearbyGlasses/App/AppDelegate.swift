import UIKit

/// Minimal AppDelegate required for BLE state restoration.
///
/// When iOS relaunches the app due to BLE background events, the launch options will contain
/// UIApplication.LaunchOptionsKey.bluetoothCentrals with the restoration identifier.
/// The CBCentralManager in BLEScanner handles restoration via willRestoreState(_:).
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
}
