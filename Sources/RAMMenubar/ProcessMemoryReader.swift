import Darwin
import Foundation

/// Memory used by one process, as Activity Monitor reports it (physical footprint).
struct ProcessMemory: Identifiable {
    let pid: pid_t
    let name: String
    let bytes: UInt64

    var id: pid_t { pid }
}

/// Lists the processes using the most memory.
enum ProcessMemoryReader {
    /// Returns the `count` processes with the largest physical footprint, largest first.
    /// Processes we are not allowed to inspect (for example root-owned ones) are skipped.
    static func topProcesses(count: Int) -> [ProcessMemory] {
        let ranked = allFootprints()
            .sorted { $0.bytes > $1.bytes }
            .prefix(count)

        return ranked.map { ProcessMemory(pid: $0.pid, name: name(for: $0.pid), bytes: $0.bytes) }
    }

    private static func allFootprints() -> [(pid: pid_t, bytes: UInt64)] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }

        let capacity = Int(byteCount) / MemoryLayout<pid_t>.size + 16
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = proc_listpids(
            UInt32(PROC_ALL_PIDS), 0, &pids, Int32(capacity * MemoryLayout<pid_t>.size)
        )
        guard filled > 0 else { return [] }

        return pids.prefix(Int(filled) / MemoryLayout<pid_t>.size).compactMap { pid in
            guard pid > 0, let bytes = footprint(of: pid), bytes > 0 else { return nil }
            return (pid, bytes)
        }
    }

    private static func footprint(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        return info.ri_phys_footprint
    }

    private static func name(for pid: pid_t) -> String {
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
            let path = String(cString: pathBuffer)
            return (path as NSString).lastPathComponent
        }

        var nameBuffer = [CChar](repeating: 0, count: 256)
        if proc_name(pid, &nameBuffer, UInt32(nameBuffer.count)) > 0 {
            return String(cString: nameBuffer)
        }

        return "pid \(pid)"
    }
}
