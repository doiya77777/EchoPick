import Foundation

extension Date {
    /// 相对时间显示（如"3分钟前"、"昨天"）
    var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 格式化为日期字符串
    var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// 仅日期
    var dayDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }
    
    /// 仅时间
    var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    /// 是否是今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// 是否是昨天
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// 智能日期显示
    var smartDisplay: String {
        if isToday {
            return "今天 \(timeDisplay)"
        } else if isYesterday {
            return "昨天 \(timeDisplay)"
        } else {
            return dateDisplay
        }
    }
}
