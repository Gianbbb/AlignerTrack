import Foundation
import SwiftUI

// MARK: - App Group Constant
public enum AppGroupConstants {
    public static let groupIdentifier = "group.com.alignertrack.app"
    public static let stateKey = "aligner_current_state"
    public static let removalStartTimeKey = "aligner_removal_start_time"
    public static let sessionsKey = "aligner_sessions"
    public static let cyclesKey = "aligner_cycles"
    public static let currentCycleIdKey = "aligner_current_cycle_id"
}

// MARK: - Models

public struct RemovalSession: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var startDate: Date
    public var endDate: Date
    public var note: String = ""

    public init(id: UUID = UUID(), startDate: Date, endDate: Date, note: String = "") {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
    }

    public var durationSeconds: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    public var durationFormatted: String {
        let totalSec = max(0, Int(durationSeconds))
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let seconds = totalSec % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m" + (seconds > 0 ? " \(seconds)s" : "")
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

public struct AlignerCycle: Identifiable, Codable, Equatable {
    public var id: UUID
    public var cycleNumber: Int
    public var startDate: Date
    public var nominalDays: Int = 14
    public var recoveryDays: Int = 0
    public var colorHex: String
    public var isCompleted: Bool = false
    public var note: String = ""

    public init(
        id: UUID = UUID(),
        cycleNumber: Int,
        startDate: Date = Date(),
        nominalDays: Int = 14,
        recoveryDays: Int = 0,
        colorHex: String = "#00B4D8",
        isCompleted: Bool = false,
        note: String = ""
    ) {
        self.id = id
        self.cycleNumber = cycleNumber
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.nominalDays = nominalDays
        self.recoveryDays = recoveryDays
        self.colorHex = colorHex
        self.isCompleted = isCompleted
        self.note = note
    }

    /// Total days of the cycle including manual recovery days
    public var totalDays: Int {
        nominalDays + recoveryDays
    }

    /// Nominal end date (day 14)
    public var nominalEndDate: Date {
        Calendar.current.date(byAdding: .day, value: nominalDays, to: startDate) ?? startDate
    }

    /// Actual end date after adding recovery days
    public var calculatedEndDate: Date {
        Calendar.current.date(byAdding: .day, value: totalDays, to: startDate) ?? startDate
    }

    /// Next cycle expected start date (same as calculatedEndDate)
    public var nextCycleStartDate: Date {
        calculatedEndDate
    }

    /// Color as SwiftUI Color
    public var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Color Hex Helper
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 180, 216)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    public func toHex() -> String {
        // Fallback default
        return "#00B4D8"
    }

    public static let emeraldMint = Color(red: 0.0, green: 0.72, blue: 0.58)
}

// MARK: - Predefined Cycle Colors
public struct CycleColorPalette {
    public static let colors: [String] = [
        "#00A896", // Smeraldo Menta
        "#4361EE", // Blu Elettrico
        "#7209B7", // Viola Orchidea
        "#F72585", // Rosa Magenta
        "#F77F00", // Arancione Corallo
        "#06D6A0", // Verde Turchese
        "#3A0CA3", // Indaco Notte
        "#4CC9F0"  // Celeste Cielo
    ]

    public static func color(forCycleNumber number: Int) -> String {
        let index = (number - 1) % colors.count
        return colors[max(0, index)]
    }
}
