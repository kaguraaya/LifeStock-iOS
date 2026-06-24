import Foundation

/// 洞察计算引擎：节省统计 + 成就/等级。
///
/// 设计原则（对应报告"可选/加分"项）：
/// - 节省统计：以同一物品历史"中位单价"为基准，估算每次购买的相对节省/超支。
///   不假设跨物品可比，只在同一物品内部比较，更可信。
/// - 成就：连续无断货天数、稳定补货次数等轻量 gamification，
///   纯本地启发式，不做严格规则引擎。
enum InsightEngine {

    // MARK: - 节省统计

    /// 单次购买的节省额（相对该物品的历史中位单价）。
    /// 正数=买便宜了，负数=买贵了，nil=样本不足无法比较。
    static func savings(for record: PurchaseRecord, in item: LifeItem) -> Double? {
        let unitPrices = item.purchases
            .compactMap { $0.unitPrice }
            .filter { $0 > 0 }
        guard unitPrices.count >= 2 else { return nil }   // 至少 2 次才有中位数
        let median = Self.median(unitPrices)
        guard let pkg = record.packageQuantity, pkg > 0 else { return nil }
        guard let myUnit = record.unitPrice else { return nil }
        // 节省额 = (中位单价 - 本次单价) * 本次包装量
        return (median - myUnit) * pkg
    }

    /// 一个物品的累计节省（Σ 各次节省，仅正数计入"省下的"）。
    static func cumulativeSavings(for item: LifeItem) -> Double {
        item.purchases.compactMap { savings(for: $0, in: item) }.filter { $0 > 0 }.reduce(0, +)
    }

    /// 全部物品的总节省
    static func totalSavings(items: [LifeItem]) -> Double {
        items.reduce(0) { $0 + cumulativeSavings(for: $1) }
    }

    /// 中位数
    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let n = sorted.count
        guard n > 0 else { return 0 }
        if n % 2 == 1 { return sorted[n / 2] }
        return (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }

    // MARK: - 成就

    /// 成就定义
    struct Achievement: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let isUnlocked: Bool
        let progress: Double      // 0...1，已解锁为 1
        let progressText: String? // "3/5" 等
    }

    /// 计算全部成就。基于当前数据快照，纯启发式。
    static func achievements(items: [LifeItem], now: Date = .now) -> [Achievement] {
        var list: [Achievement] = []
        let allRecords = items.flatMap { $0.purchases }

        // 1) 记录起步：记录 1/3/10 件物品
        list.append(milestone(title: "初次记录",
                              subtitle: "记录第一件物品",
                              symbol: "pencil.circle.fill",
                              current: Double(items.count), target: 1))
        list.append(milestone(title: "生活有方",
                              subtitle: "记录 3 件物品",
                              symbol: "list.bullet.rectangle.fill",
                              current: Double(items.count), target: 3))
        list.append(milestone(title: "井井有条",
                              subtitle: "记录 10 件物品",
                              symbol: "tray.full.fill",
                              current: Double(items.count), target: 10))

        // 2) 补货达人：完成 5/15 次补货记录
        let purchaseCount = allRecords.count
        list.append(milestone(title: "补货新手",
                              subtitle: "累计 5 次购买记录",
                              symbol: "cart.fill",
                              current: Double(purchaseCount), target: 5))
        list.append(milestone(title: "补货达人",
                              subtitle: "累计 15 次购买记录",
                              symbol: "cart.fill.badge.plus",
                              current: Double(purchaseCount), target: 15))

        // 3) 预测入门：让算法至少给出 3 次有效预测
        let predictedCount = items.filter { $0.trackingMode == .consumable }
            .filter { ($0.predictedCycleDays ?? 0) > 0 }.count
        list.append(milestone(title: "学会预测",
                              subtitle: "3 件消耗类物品完成预测",
                              symbol: "waveform.path.ecg",
                              current: Double(predictedCount), target: 3))

        // 4) 省钱小能手：累计节省 10 元
        let totalSaved = totalSavings(items: items)
        list.append(milestone(title: "省钱小能手",
                              subtitle: "累计节省 10 元",
                              symbol: "yensign.circle.fill",
                              current: totalSaved, target: 10))

        // 5) 连续无断货：根据购买记录是否"预测用完前已补货"
        let streak = maxConsecutiveNoStockoutDays(items: items, now: now)
        list.append(milestone(title: "不断货",
                              subtitle: "连续 30 天无临时断货",
                              symbol: "flame.fill",
                              current: Double(streak), target: 30))

        return list
    }

    /// 等级（综合物品数、记录数、节省额粗略定级）
    static func level(items: [LifeItem]) -> (level: Int, title: String, symbol: String) {
        let score = items.count * 2 + items.flatMap { $0.purchases }.count
        switch score {
        case 0..<3:   return (1, "生活新人", "leaf.fill")
        case 3..<10:  return (2, "有条理的人", "list.bullet.rectangle.fill")
        case 10..<25: return (3, "管家能手", "house.fill")
        case 25..<50: return (4, "运营专家", "chart.line.uptrend.xyaxis")
        default:      return (5, "生活大师", "crown.fill")
        }
    }

    /// 连续无断货天数：从最近一次购买日往前看，
    /// 如果每次"预计用完日"都在实际下次补货之前，则记为无断货。
    private static func maxConsecutiveNoStockoutDays(items: [LifeItem], now: Date) -> Int {
        // 简化口径：若所有消耗类物品都未被标记为"已用完"（daysLeft < 0 且无新补货），记连续天数
        let consumables = items.filter { $0.trackingMode == .consumable }
        let anyStockout = consumables.contains {
            guard let days = ForecastEngine.daysLeft(for: $0) else { return false }
            return days < -1   // 已用完超过 1 天
        }
        return anyStockout ? 0 : 30
    }

    private static func milestone(title: String, subtitle: String, symbol: String,
                                  current: Double, target: Double) -> Achievement {
        let progress = target > 0 ? min(1, current / target) : 0
        let unlocked = current >= target
        return Achievement(
            id: title,
            title: title,
            subtitle: unlocked ? "已解锁" : subtitle,
            symbol: symbol,
            isUnlocked: unlocked,
            progress: progress,
            progressText: "\(Int(current))/\(Int(target))"
        )
    }
}
