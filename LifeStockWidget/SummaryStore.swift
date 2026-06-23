import Foundation

/// 小组件侧的 SummaryStore 镜像（扩展不能直接依赖 App target）。
/// 字段与 LifeStock/Services/SummaryStore.swift 保持一致。
///
/// 数据流：App 写入 -> UserDefaults（可选 App Group） -> Widget 读取。
enum SummaryStore {

    static let suiteName: String? = nil
    static let storageKey = "lifestock.widget.summary.v1"

    struct Item: Codable, Identifiable {
        let id: String
        let name: String
        let statusText: String
        let urgency: Int
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

    static func read() -> Summary? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Summary.self, from: data)
    }

    static let placeholder = Summary(
        totalItems: 0,
        pendingThisWeek: 0,
        monthSpend: 0,
        topItems: [],
        updatedAt: .now
    )
}
