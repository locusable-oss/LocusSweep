import Foundation

/// Human-readable byte sizes for residue rows and summaries.
public enum ByteFormat {
    public static func string(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = -1
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex < 0 { return "\(bytes) B" }
        let formatted: String
        if value >= 100 || unitIndex == 0 {
            formatted = String(format: "%.0f", value)
        } else if value >= 10 {
            formatted = String(format: "%.1f", value)
        } else {
            formatted = String(format: "%.2f", value)
        }
        return "\(formatted) \(units[unitIndex])"
    }
}
