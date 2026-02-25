import SwiftUI

struct LogView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showCopiedBanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            logHeader
            logContent
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            if showCopiedBanner {
                copiedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCopiedBanner)
    }

    // MARK: - Subviews

    private var logHeader: some View {
        HStack {
            Text("Debug Log")
                .font(.headline)
            Spacer()
            Text("\(viewModel.logLines.count) lines")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var logContent: some View {
        if viewModel.logLines.isEmpty {
            Text("No events logged yet.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(viewModel.logLines.enumerated()), id: \.offset) { index, line in
                            logLineView(line: line, index: index)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: viewModel.logLines.count) { _ in
                    guard let last = viewModel.logLines.indices.last else { return }
                    withAnimation(.none) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                        UIPasteboard.general.string = viewModel.logText
                        flashCopiedBanner()
                    }
                )
            }
            .frame(minHeight: 180)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }

    private func logLineView(line: String, index: Int) -> some View {
        let isDetection = !line.hasPrefix("DEBUG:")
        return Text(line)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(isDetection ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                UIPasteboard.general.string = line
                flashCopiedBanner()
            }
    }

    private var copiedBanner: some View {
        Text("Copied to clipboard")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray2))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func flashCopiedBanner() {
        showCopiedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedBanner = false
        }
    }
}
