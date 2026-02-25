import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss

    // Local text-field state for numeric settings (with validation on commit)
    @State private var rssiText: String = ""
    @State private var cooldownText: String = ""
    @State private var maxLinesText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                scanningSection
                notificationSection
                loggingSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: syncTextFields)
        }
    }

    // MARK: - Sections

    private var scanningSection: some View {
        Section {
            Toggle("Enable Background Scanning", isOn: $settings.backgroundScanningEnabled)

            HStack {
                Text("RSSI Threshold (dBm)")
                Spacer()
                TextField("-75", text: $rssiText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .onSubmit { validateAndSaveRSSI() }
                    .onChange(of: rssiText) { _ in validateAndSaveRSSI() }
            }

            Picker("Language", selection: $settings.appLanguage) {
                Text("System Default").tag("system")
                Text("English").tag("en")
                Text("German (Deutsch)").tag("de")
                Text("Swiss German (Schweizerdeutsch)").tag("de-CH")
                Text("French (Français)").tag("fr")
            }
        } header: {
            Text("Scanning Settings")
        } footer: {
            Text("RSSI range: -120 to 0 dBm. Default -75 dBm ≈ 10–15m outdoors. Language changes take effect after restarting the app.")
                .font(.caption)
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)

            HStack {
                Text("Notification Cooldown (ms)")
                Spacer()
                TextField("10000", text: $cooldownText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onSubmit { validateAndSaveCooldown() }
                    .onChange(of: cooldownText) { _ in validateAndSaveCooldown() }
            }
        } header: {
            Text("Notification Settings")
        } footer: {
            Text("Cooldown prevents notification spam. Range: 0–600,000 ms (0–10 minutes). Default 10,000 ms (10 seconds).")
                .font(.caption)
        }
    }

    private var loggingSection: some View {
        Section {
            Toggle("Enable Log Display", isOn: $settings.loggingEnabled)
            Toggle("Debug Mode", isOn: $settings.debugEnabled)

            if settings.debugEnabled {
                HStack {
                    Text("Max Log Lines")
                    Spacer()
                    TextField("200", text: $maxLinesText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .onSubmit { validateAndSaveMaxLines() }
                        .onChange(of: maxLinesText) { _ in validateAndSaveMaxLines() }
                }

                Toggle("BLE ADV Only", isOn: $settings.advOnly)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Override Company IDs")
                        .font(.body)
                    TextField("e.g. 0x1234, 0xABCD", text: $settings.debugCompanyIds)
                        .font(.system(.caption, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Comma-separated hex values. Only active in debug mode.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Logging Settings")
        } footer: {
            if settings.debugEnabled {
                Text("Debug mode logs all BLE advertisements, not just detections. Max log lines: 50–5,000.")
                    .font(.caption)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("App")
                Spacer()
                Text("Nearby Glasses")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("License")
                Spacer()
                Text("PolyForm Noncommercial 1.0.0")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Detection Method")
                    .font(.subheadline)
                    .bold()
                Text(
                    "Scans Bluetooth Low Energy (BLE) advertisements and matches Manufacturer Specific Data " +
                    "Company IDs for known smart glasses manufacturers:\n" +
                    "• Meta Platforms, Inc. (0x01AB) — Ray-Ban Meta\n" +
                    "• Meta Platforms Technologies (0x058E)\n" +
                    "• EssilorLuxottica (0x0D53)\n" +
                    "• Snapchat, Inc. (0x03C2) — Snap Spectacles"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Disclaimer")
                    .font(.subheadline)
                    .bold()
                Text(
                    "This app provides probabilistic detection only. False positives are possible — " +
                    "many devices share Bluetooth Company IDs. No action should be taken based solely " +
                    "on this app's output. The developer is not liable for any misuse."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func syncTextFields() {
        rssiText = "\(settings.rssiThreshold)"
        cooldownText = "\(settings.cooldownMs)"
        maxLinesText = "\(settings.maxLogLines)"
    }

    private func validateAndSaveRSSI() {
        guard let val = Int(rssiText), (-120...0).contains(val) else { return }
        settings.rssiThreshold = val
    }

    private func validateAndSaveCooldown() {
        guard let val = Int(cooldownText), (0...600_000).contains(val) else { return }
        settings.cooldownMs = val
    }

    private func validateAndSaveMaxLines() {
        guard let val = Int(maxLinesText), (50...5_000).contains(val) else { return }
        settings.maxLogLines = val
    }
}

#Preview {
    SettingsView(settings: SettingsManager())
}
