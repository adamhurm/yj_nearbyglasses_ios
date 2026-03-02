import SwiftUI

@main
struct NearbyGlassesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Owned at app scope so CBCentralManager is created at launch, not when
    // the view first appears. This is required for BLE state restoration to
    // work when iOS relaunches the app in the background.
    @StateObject private var viewModel = ScannerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active, viewModel.isScanning {
                // Re-issue scanForPeripherals with allowDuplicates:true.
                // iOS silently drops that option while suspended and coalesces
                // to ~30 s per device; this restores foreground frequency.
                viewModel.startScanning()
            }
        }
    }
}
