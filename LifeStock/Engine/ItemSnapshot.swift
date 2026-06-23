import Foundation
import SwiftUI

/// 为 UI 计算的"物品快照"——把散落在算法各处的结果集中成一个轻量值类型，
/// 避免 View 反复重新计算。
struct ItemSnapshot: Identifiable {
    let id: UUID              // 等同 LifeItem.id
    let name: String
    let trackingMode: TrackingMode
    let category: ItemCategory
    let status: ItemStatus

    let targetDate: Date?
    let daysLeft: Int?        // 负数表示已过期/已超期
    let statusText: String    // "预计 3 天后用完" / "今天到期" / "已过期 2 天"
    let valueText: String?    // "0.87 元/天" / "最近一次 19.9 元"
    let confidence: Double?
    let confidenceLevel: ConfidenceLevel?
    let dailyCost: Double?
    let currencyCode: String

    /// 优先级 0...4，用于首页排序与配色
    /// 0 = 已过期/已超期（红，最高优先）
    /// 1 = 3 天内（橙）
    /// 2 = 7 天内（黄）
    /// 3 = 正常追踪（蓝）
    /// 4 = 数据不足（灰）
    let urgency: Int

    let urgencyColor: Color
    let symbol: String
}

enum ItemSnapshotBuilder {

    /// 给定一个 LifeItem，计算它的展示快照
    static func snapshot(for item: LifeItem, now: Date = .now) -> ItemSnapshot {
        let target = ForecastEngine.targetDate(for: item)
        let days = target.map { ForecastEngine.daysLeft(from: now, to: $0) }

        let confidence: Double?
        if item.trackingMode == .consumable {
            let r = ForecastEngine.predictRepurchaseDate(for: item, today: now)
            confidence = r.confidence
        } else {
            confidence = nil
        }
        let level = confidence.map { ConfidenceLevel.from(score: $0) }

        let daily = ForecastEngine.dailyCost(for: item, asOf: now)

        let (statusText, urgency, color) = composeStatus(
            mode: item.trackingMode, days: days, status: item.status
        )

        let valueText = composeValue(mode: item.trackingMode,
                                     dailyCost: daily,
                                     lastPrice: item.purchasePrice,
                                     unitName: item.unitName)

        return ItemSnapshot(
            id: item.id,
            name: item.name,
            trackingMode: item.trackingMode,
            category: item.category,
            status: item.status,
            targetDate: target,
            daysLeft: days,
            statusText: statusText,
            valueText: valueText,
            confidence: confidence,
            confidenceLevel: level,
            dailyCost: daily,
            currencyCode: item.currencyCode,
            urgency: urgency,
            urgencyColor: color,
            symbol: item.trackingMode.symbol
        )
    }

    private static func composeStatus(mode: TrackingMode, days: Int?, status: ItemStatus)
    -> (String, Int, Color) {
        // 已归档/暂停：灰
        if status != .active {
            return (status.displayName, 4, Color.secondary.opacity(0.6))
        }
        guard let d = days else {
            return ("暂无目标日期", 4, Color.secondary.opacity(0.6))
        }

        let prefix: String
        switch mode {
        case .expiry:       prefix = d < 0 ? "已过期 " : "距到期 "
        case .consumable:   prefix = d < 0 ? "已用完 " : "预计 "
        case .subscription: prefix = d < 0 ? "已超期扣费 " : "距续费 "
        case .durable:      prefix = d < 0 ? "已超寿命 " : "距寿命终点 "
        }

        let suffix: String
        switch mode {
        case .consumable, .expiry, .subscription, .durable:
            suffix = (d < 0 ? "\(-d) 天" : (d == 0 ? "今天" : "\(d) 天后"))
        }

        let text = prefix + suffix
        // 紧迫度配色
        if d < 0 {
            return (text, 0, Color.red)
        } else if d <= 3 {
            return (text, 1, Color.orange)
        } else if d <= 7 {
            return (text, 2, Color.yellow)
        } else {
            return (text, 3, Color.blue)
        }
    }

    private static func composeValue(mode: TrackingMode,
                                     dailyCost: Double?,
                                     lastPrice: Double?,
                                     unitName: String?) -> String? {
        if let daily = dailyCost, daily > 0 {
            return String(format: "%.2f 元/天", daily)
        }
        if let price = lastPrice, price > 0 {
            if let u = unitName, !u.isEmpty {
                return String(format: "最近一次 %.2f 元 · %@", price, u)
            }
            return String(format: "最近一次 %.2f 元", price)
        }
        return nil
    }
}

// MARK: - 货币格式化
enum MoneyFormatter {
    /// 把 Double 格式化为带货币符号的字符串
    static func string(_ value: Double?, currencyCode: String = "CNY", digits: Int = 2) -> String {
        guard let v = value else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    /// 紧凑数字：1234 -> "1.2k"，12000 -> "1.2万"
    static func compact(_ value: Double) -> String {
        if abs(value) >= 10000 {
            return String(format: "%.1f万", value / 10000)
        }
        if abs(value) >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - 相对日期文案
enum RelativeDateText {
    /// "今天" / "明天" / "3 天后" / "已过期 2 天"
    static func days(_ days: Int?) -> String {
        guard let d = days else { return "—" }
        if d == 0 { return "今天" }
        if d == 1 { return "明天" }
        if d == -1 { return "昨天" }
        if d > 0 { return "\(d) 天后" }
        return "已过期 \(-d) 天"
    }

    /// 完整日期 "6月25日"
    static func short(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: d)
    }
}
