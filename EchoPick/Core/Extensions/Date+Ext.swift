import Foundation

extension Date {
    var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var dateDisplay: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: self)
    }

    var timeDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    var dayDisplay: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: self)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    var smartDisplay: String {
        if isToday { return "今天 \(timeDisplay)" }
        if isYesterday { return "昨天 \(timeDisplay)" }
        return dateDisplay
    }
}

extension TimeInterval {
    /// 格式化时长：如 "5:32" 或 "1:05:32"
    var durationDisplay: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
