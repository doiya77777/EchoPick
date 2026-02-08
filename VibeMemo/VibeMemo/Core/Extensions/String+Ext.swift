import Foundation

extension String {
    /// 截取前 N 个字符
    func prefix(_ maxLength: Int) -> String {
        String(self.prefix(maxLength))
    }
    
    /// 移除多余空白行
    var trimmedLines: String {
        self.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
    
    /// 提取第一行作为标题
    var firstLine: String {
        self.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    /// 字符数统计（中文友好）
    var characterCount: Int {
        self.count
    }
    
    /// 估算阅读时间（中文约 400 字/分钟）
    var estimatedReadingTime: String {
        let count = self.count
        let minutes = max(1, count / 400)
        return "\(minutes) 分钟阅读"
    }
    
    /// 隐藏敏感信息（如 API Key）
    var masked: String {
        guard self.count > 8 else { return String(repeating: "•", count: self.count) }
        let prefix = String(self.prefix(4))
        let suffix = String(self.suffix(4))
        let masked = String(repeating: "•", count: min(self.count - 8, 20))
        return "\(prefix)\(masked)\(suffix)"
    }
}
