import SwiftUI

/// 全局视觉常量。集中管理配色、间距、圆角，便于整体调优。
enum AppTheme {
    /// 主色（暖橙，呼应"生活温度"）
    static let accent = Color(red: 0.96, green: 0.52, blue: 0.27)

    static let bg = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)

    static let red    = Color.red
    static let orange = Color.orange
    static let yellow = Color.yellow
    static let blue   = Color.blue
    static let gray   = Color.secondary

    static let corner: CGFloat = 16
    static let pad: CGFloat = 16
    static let gap: CGFloat = 12

    /// 主品牌渐变（橙→金），用于强调卡片、徽章、引导页
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, Color(red: 1.0, green: 0.66, blue: 0.30)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// 卡片阴影修饰符，统一阴影观感
struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

extension View {
    /// 给卡片加柔和阴影
    func cardShadow() -> some View { modifier(CardShadow()) }
}

/// 紧迫度到颜色的映射（与 ItemSnapshot 保持一致，便于复用）
enum UrgencyPalette {
    static func color(urgency: Int) -> Color {
        switch urgency {
        case 0: return AppTheme.red
        case 1: return AppTheme.orange
        case 2: return AppTheme.yellow
        case 3: return AppTheme.blue
        default: return AppTheme.gray.opacity(0.7)
        }
    }
}
