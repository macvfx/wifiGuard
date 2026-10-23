import Foundation

/// The activity log on disk: one tab-separated line per event, rotated weekly or monthly and
/// compressed with gzip, with only the newest archives kept.
final class ActivityLog {
    private let directory: URL
    private let fileURL: URL
    private let archiveQueue = DispatchQueue(label: "wifiguard.log-archive")

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Wi-Fi Guard/Logs", isDirectory: true)
        fileURL = directory.appendingPathComponent("activity.log")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var folderURL: URL { directory }

    func append(date: Date, text: String) {
        let line = "\(Self.format(date))\t\(text)\n"
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// The newest entries, newest first.
    func recent(limit: Int) -> [LogEntry] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").suffix(limit).reversed().compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let date = Self.parse(String(parts[0])) else { return nil }
            return LogEntry(date: date, text: String(parts[1]))
        }
    }

    /// Compress the current log when it started in an earlier week or month than `now`.
    /// Returns true if it rotated.
    @discardableResult
    func rotateIfNeeded(rotation: String, keep: Int, now: Date = Date()) -> Bool {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8),
              let first = text.split(separator: "\n").first,
              let stamp = first.split(separator: "\t").first,
              let started = Self.parse(String(stamp)) else { return false }

        let calendar = Calendar.current
        let components: Set<Calendar.Component> = rotation == "weekly"
            ? [.yearForWeekOfYear, .weekOfYear] : [.year, .month]
        guard calendar.dateComponents(components, from: started) != calendar.dateComponents(components, from: now)
        else { return false }

        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.locale = Locale(identifier: "en_US_POSIX")
        var archive = directory.appendingPathComponent("activity-\(day.string(from: started)).log")
        var suffix = 1
        while FileManager.default.fileExists(atPath: archive.path)
                || FileManager.default.fileExists(atPath: archive.path + ".gz") {
            suffix += 1
            archive = directory.appendingPathComponent("activity-\(day.string(from: started))-\(suffix).log")
        }
        do { try FileManager.default.moveItem(at: fileURL, to: archive) } catch { return false }

        let directory = self.directory
        archiveQueue.async {
            let gzip = Process()
            gzip.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
            gzip.arguments = ["-f", archive.path]
            try? gzip.run()
            gzip.waitUntilExit()
            Self.prune(directory: directory, keep: keep)
        }
        return true
    }

    private static func prune(directory: URL, keep: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let archives = files.filter { $0.hasPrefix("activity-") && $0.hasSuffix(".log.gz") }.sorted()
        for name in archives.dropLast(max(1, keep)) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    private static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func parse(_ text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
