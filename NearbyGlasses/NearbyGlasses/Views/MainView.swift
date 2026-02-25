import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showSettings = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    warningBanner
                    scanSection
                    if viewModel.settings.loggingEnabled {
                        Divider()
                            .padding(.horizontal)
                        LogView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Nearby Glasses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: viewModel.settings)
            }
            .alert("Clear Log", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) { viewModel.clearLog() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to clear the debug log?")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gear")
                }
                Button { showClearConfirmation = true } label: {
                    Label("Clear Log", systemImage: "trash")
                }
                Button { LogExporter.export(logText: viewModel.logText) } label: {
                    Label("Export Log", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "gear")
                    .accessibilityLabel("Menu")
            }
        }
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Text("⚠️ WARNING! ⚠️")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.orange)
                Spacer()
            }
            Text(
                "HARASSING someone because you think they are wearing a covert surveillance device " +
                "can be a criminal offence. Always consider alternative explanations — false positives " +
                "are possible as many devices share these Bluetooth Company IDs."
            )
            .font(.caption)
            .foregroundColor(.primary)
            HStack {
                Spacer()
                Text("⚠️ DO NOT HARASS ANYONE AT ALL. ⚠️")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Scan Section

    private var scanSection: some View {
        VStack(spacing: 14) {
            // BLE unavailability warning
            if let reason = viewModel.bluetoothUnavailableReason {
                HStack(spacing: 6) {
                    Image(systemName: "bluetooth.slash")
                        .foregroundColor(.red)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Start / Stop button
            Button(action: { viewModel.toggleScanning() }) {
                HStack {
                    Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "play.circle.fill")
                    Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.isScanning ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Status text
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(viewModel.isScanning ? .green : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .animation(.easeInOut, value: viewModel.isScanning)

            // Descriptive text when not scanning
            if !viewModel.isScanning {
                Text(
                    "This app notifies you when smart glasses (Ray-Ban Meta, Snap Spectacles) " +
                    "might be nearby by scanning Bluetooth Low Energy advertisements. " +
                    "Keep Bluetooth enabled and optionally allow background scanning in Settings."
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private var statusText: String {
        if viewModel.isScanning {
            return "Scanning active — You will be notified if smart glasses are detected nearby."
        } else {
            return "Not scanning"
        }
    }
}

#Preview {
    MainView()
}
