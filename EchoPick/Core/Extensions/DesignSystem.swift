import SwiftUI

// MARK: - Design System
// 柚子鲸风格 · Light / Dark 自适应 · 细边框 · 大留白

enum DS {
    enum Colors {
        static let bg = Color("DSBackground")
        static let bgCard = Color("DSCard")
        static let text = Color("DSText")
        static let textSecondary = Color("DSTextSecondary")
        static let textMuted = Color("DSTextMuted")
        static let border = Color("DSBorder")
        static let accentSoft = Color("DSAccentSoft")

        // Category colors
        static let topicColor = Color(hex: "#5B6ABF")
        static let actionColor = Color(hex: "#D9534F")
        static let factColor = Color(hex: "#E5A100")
        static let green = Color(hex: "#34A853")
        static let red = Color(hex: "#D9534F")
        static let yellow = Color(hex: "#E5A100")
        static let blue = Color(hex: "#5B6ABF")
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 9999
    }

    // MARK: - Typography
    // 中文用默认系统字体（PingFang SC），英文/数字用 Rounded
    // 避免 .design(.rounded) 和中文混用的违和感

    enum Font {
        /// 大标题 — 用于页面标题
        static func title(_ size: CGFloat = 24) -> SwiftUI.Font {
            .system(size: size, weight: .bold)
        }

        /// 副标题
        static func headline(_ size: CGFloat = 18) -> SwiftUI.Font {
            .system(size: size, weight: .bold)
        }

        /// Section 标题
        static func section(_ size: CGFloat = 15) -> SwiftUI.Font {
            .system(size: size, weight: .bold)
        }

        /// 正文
        static func body(_ size: CGFloat = 14) -> SwiftUI.Font {
            .system(size: size)
        }

        /// 正文加粗
        static func bodyBold(_ size: CGFloat = 14) -> SwiftUI.Font {
            .system(size: size, weight: .semibold)
        }

        /// 辅助文字
        static func caption(_ size: CGFloat = 12) -> SwiftUI.Font {
            .system(size: size)
        }

        /// 小标签
        static func tag(_ size: CGFloat = 11) -> SwiftUI.Font {
            .system(size: size, weight: .medium)
        }

        /// 数字 — 用 Rounded + monospaced 让数字好看
        static func number(_ size: CGFloat = 18) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        /// 超大数字（计时器等）
        static func timer(_ size: CGFloat = 48) -> SwiftUI.Font {
            .system(size: size, weight: .ultraLight, design: .rounded)
        }

        /// 代码/Key — monospaced
        static func mono(_ size: CGFloat = 11) -> SwiftUI.Font {
            .system(size: size, design: .monospaced)
        }
    }
}

// MARK: - View Modifiers

extension View {
    func cardStyle(radius: CGFloat = DS.Radius.lg) -> some View {
        self
            .background(DS.Colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
    }

    func pillTag(color: Color = DS.Colors.text) -> some View {
        self
            .font(DS.Font.tag())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
