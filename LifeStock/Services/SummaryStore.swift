import Foundation

/// App 与 Widget 共享的摘要存储。
///
/// 设计说明（对应报告）：
/// - WidgetKit 有刷新预算（常看小组件每日约 40-70 次），
///   因此 LifeStock 的小组件只做"摘要 + 待处理列表"，
///   不做高频无意义更新。
/// - App 在数据变更时写入一份轻量摘要到 UserDefaults（App Group），
///   Widget 直接读取，避免在扩展进程内重建 SwiftData 查询。
///
/// App Group：
/// - 默认使用普通 UserDefaults（不强制要求 App Group 能力），
///   便于课程项目直接运行；
/// - 若后续配置了 App Group，只需把 suiteName 改为对应标识即可。
enum SummaryStore {

    /// 如果你配置了 App Group，把这里改为 App Group 标识即可启用跨进程共享。
    static let suiteName: String? = nil  // 例如 "group.com.lifestock.app"

    static let storageKey = "lifestock.widget.summary.v1"

    struct Item: Codable, Identifiable {
        let id: String
        let name: String
        let statusText: String
        let urgency: Int       // 0...4
        let daysLeft: Int?
    }

    struct Summary: Codable {
        let totalItems: Int
        let pendingThisWeek: Int
        let monthSpend: Double
        let topItems: [Item]
        let updatedAt: Date
    }

    private static var defaults: UserDefaults {
        if let suite = suiteName, let d = UserDefaults(suiteName: suite) {
            return d
        }
        return .standard
    }

    /// 由 App 在数据变更后调用，写入最新摘要
    static func write(_ summary: Summary) {
        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: storageKey)
        }
    }

    /// 由 Widget 读取
    static func read() -> Summary? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Summary.self, from: data)
    }

    /// 占位摘要（Widget 预览与首次安装时使用）
    static let placeholder = Summary(
        totalItems: 0,
        pendingThisWeek: 0,
        monthSpend: 0,
        topItems: [],
        updatedAt: .now
    )
}
