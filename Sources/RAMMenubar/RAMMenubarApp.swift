import AppKit
import SwiftUI

/// Menu bar app that shows live RAM usage as a percentage or in GB.
@main
struct RAMMenubarApp: App {
    @StateObject private var monitor = MemoryMonitor()

    init() {
        // Menu bar only: no Dock icon, no main window.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MemoryMenu(monitor: monitor)
        } label: {
            Text(monitor.menuBarTitle)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Which value the menu bar item shows.
enum DisplayMode {
    case percent
    case gigabytes
}

/// Polls `MemoryReader` and `ProcessMemoryReader` on a fixed interval and publishes the results.
@MainActor
final class MemoryMonitor: ObservableObject {
    static let refreshInterval: TimeInterval = 2
    static let topProcessCount = 10

    @Published private(set) var stats: MemoryStats?
    @Published private(set) var topProcesses: [ProcessMemory] = []
    @Published var displayMode: DisplayMode = .percent

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        stats = MemoryReader.read()
        topProcesses = ProcessMemoryReader.topProcesses(count: Self.topProcessCount)
    }

    var menuBarTitle: String {
        guard let stats else { return "RAM --" }
        switch displayMode {
        case .percent:
            return "RAM \(percentText(stats))"
        case .gigabytes:
            return "RAM \(MemoryFormat.gigabytes(stats.usedBytes))"
        }
    }
}

/// Contents of the dropdown shown when the menu bar item is clicked.
struct MemoryMenu: View {
    @ObservedObject var monitor: MemoryMonitor

    var body: some View {
        if let stats = monitor.stats {
            Toggle(isOn: gigabytesBinding) {
                Text("Used: \(MemoryFormat.gigabytes(stats.usedBytes))")
            }
            Toggle(isOn: percentBinding) {
                Text("Usage: \(percentText(stats))")
            }
        } else {
            Text("Memory data unavailable")
        }

        Divider()

        if monitor.topProcesses.isEmpty {
            Text("No process data")
        } else {
            // Buttons render in the normal font; plain Text in a menu is greyed out.
            ForEach(monitor.topProcesses) { process in
                Button {
                } label: {
                    Text("\(process.name) — \(MemoryFormat.processSize(process.bytes))")
                }
            }
        }

        Divider()

        Button("Quit RAM Monitor") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// Checked while the menu bar shows GB. Selecting "Used" switches to GB.
    private var gigabytesBinding: Binding<Bool> {
        Binding(
            get: { monitor.displayMode == .gigabytes },
            set: { if $0 { monitor.displayMode = .gigabytes } }
        )
    }

    /// Checked while the menu bar shows percent. Selecting "Usage" switches to percent.
    private var percentBinding: Binding<Bool> {
        Binding(
            get: { monitor.displayMode == .percent },
            set: { if $0 { monitor.displayMode = .percent } }
        )
    }
}

private func percentText(_ stats: MemoryStats) -> String {
    "\(Int((stats.usedFraction * 100).rounded()))%"
}

/// Formatting helpers for memory values.
enum MemoryFormat {
    private static let bytesPerGigabyte = 1_073_741_824.0

    /// Used memory in GB, e.g. "6.5 GB".
    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / bytesPerGigabyte)
    }

    /// Per-process size in MB or GB, e.g. "340 MB" or "1.2 GB".
    static func processSize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
