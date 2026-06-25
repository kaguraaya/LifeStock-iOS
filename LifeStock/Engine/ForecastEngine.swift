import Foundation

/// 预测结果。承载"预测日期 + 间隔 + 置信度 + 误差说明"。
struct ForecastResult {
    var predictedDate: Date?
    var predictedIntervalDays: Double?
    var confidence: Double         // 0...1
    var maeDays: Double?
    var note: String
}

/// 回测点：某次补货的预测间隔 vs 实际间隔
struct BacktestPoint: Identifiable {
    let id = UUID()
    let date: Date
    let predicted: Double
    let actual: Double
}

/// 回测摘要：MAE / MAPE / 均值
struct BacktestSummary {
    let sampleCount: Int
    let maeDays: Double      // 平均绝对误差（天）
    let meanDays: Double     // 实际间隔均值
    let mape: Double?        // 平均绝对百分比误差（%），可能为 nil
}

/// 核心计算引擎。所有日期/价值/预测算法集中在这里，便于单测与替换。
///
/// 算法分四层（对应设计报告）：
/// 1. 日期层：剩余天数、预计用完日、续费日、折旧进度
/// 2. 价值层：单价、总价、日均成本、累计花费、设备折旧
/// 3. 预测层：复购时间预测、动态提醒时间、置信度
/// 4. 体验层：通知节流、购买来源提前期、用户手动修正反馈
enum ForecastEngine {

    // MARK: - 日期层

    /// 计算从 now 到 targetDate 的"剩余整天数"（按日历日起算）。
    static func daysLeft(from now: Date = .now, to targetDate: Date, calendar: Calendar = .current) -> Int {
        let startNow = calendar.startOfDay(for: now)
        let startTarget = calendar.startOfDay(for: targetDate)
        return calendar.dateComponents([.day], from: startNow, to: startTarget).day ?? 0
    }

    /// 物品的"目标日期"——即它将被处理/用完/扣费/折旧结束的日期。
    /// 口径由 trackingMode 决定：
    /// - expiry:       expiryDate
    /// - consumable:   purchaseDate + predictedCycleDays
    /// - subscription: nextBillingDate
    /// - durable:      purchaseDate + usefulLifeDays
    static func targetDate(for item: LifeItem) -> Date? {
        switch item.trackingMode {
        case .expiry:
            return item.expiryDate
        case .consumable:
            if let predicted = item.predictedDepletionDate { return predicted }
            if let last = item.purchaseDate, let cycle = item.predictedCycleDays {
                return Calendar.current.date(byAdding: .day, value: Int(cycle.rounded()), to: last)
            }
            if let last = item.purchaseDate, let expected = item.expectedUseDays {
                return Calendar.current.date(byAdding: .day, value: expected, to: last)
            }
            return nil
        case .subscription:
            return item.nextBillingDate
        case .durable:
            if let last = item.purchaseDate, let life = item.usefulLifeDays {
                return Calendar.current.date(byAdding: .day, value: life, to: last)
            }
            return nil
        }
    }

    /// 剩余天数（包装 targetDate + daysLeft）
    static func daysLeft(for item: LifeItem, now: Date = .now) -> Int? {
        guard let target = targetDate(for: item) else { return nil }
        return daysLeft(from: now, to: target)
    }

    // MARK: - 消耗类预计用完日期

    /// 估算日均消耗。
    /// 优先级：显式平均 > 包装量/观测天数 > 模板默认周期反推。
    static func estimatedDailyConsumption(
        packageQuantity: Double?,
        observedLifeDays: Int?,
        fallbackDailyConsumption: Double?
    ) -> Double? {
        if let fallback = fallbackDailyConsumption, fallback > 0 { return fallback }
        if let pkg = packageQuantity, let days = observedLifeDays, days > 0 {
            return pkg / Double(days)
        }
        return nil
    }

    // MARK: - 价值层

    /// 实际成本：总价 - 优惠 + 运费（保护下界）
    static func effectiveCost(total: Double, coupon: Double?, shipping: Double?) -> Double {
        let c = coupon ?? 0
        let s = shipping ?? 0
        return max(0, total - c + s)
    }

    /// 单价 = 实际成本 / 包装量
    static func unitPrice(effectiveCost: Double, packageQuantity: Double?) -> Double? {
        guard let pkg = packageQuantity, pkg > 0 else { return nil }
        return effectiveCost / pkg
    }

    /// 单件物品的日均成本，口径随模式不同：
    /// - consumable:   effectiveCost / 实际或预测周期
    /// - subscription: 计费金额 / 周期天数
    /// - durable:      折旧口径（见 straightLineDepreciation 的 daily）
    /// - expiry:       不摊销，返回 nil
    static func dailyCost(for item: LifeItem, asOf date: Date = .now) -> Double? {
        switch item.trackingMode {
        case .expiry:
            return nil
        case .consumable:
            let cost = item.purchasePrice ?? 0
            let days: Double
            if let observed = lastObservedLifeDays(for: item) {
                days = Double(observed)
            } else if let pred = item.predictedCycleDays, pred > 0 {
                days = pred
            } else if let exp = item.expectedUseDays, exp > 0 {
                days = Double(exp)
            } else {
                return nil
            }
            return days > 0 ? cost / days : nil
        case .subscription:
            let amount = item.purchasePrice ?? 0
            let cycle = item.billingCycleDays ?? 30
            return cycle > 0 ? amount / Double(cycle) : nil
        case .durable:
            guard let price = item.devicePurchasePrice,
                  let life = item.usefulLifeDays, life > 0 else { return nil }
            let residual = item.residualValue ?? 0
            return (price - residual) / Double(life)
        }
    }

    /// 累计花费 = Σ effectiveCost（缺省回退到 totalPrice）
    static func cumulativeSpend(records: [PurchaseRecord]) -> Double {
        records.reduce(0) { sum, r in
            if let eff = r.effectiveCost { return sum + eff }
            return sum + r.totalPrice
        }
    }

    /// 最近 N 天的总花费
    static func spend(inLast days: Int, records: [PurchaseRecord], now: Date = .now) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let filtered = records.filter { $0.purchasedAt >= cutoff }
        return cumulativeSpend(records: filtered)
    }

    /// 直线法折旧：
    /// - dailyDepreciation = (price - residual) / life
    /// - accumulated = min(daysUsed, life) * daily
    /// - bookValue = max(residual, price - accumulated)
    static func straightLineDepreciation(
        purchasePrice: Double,
        residualValue: Double,
        usefulLifeDays: Int,
        daysUsed: Int
    ) -> (dailyDepreciation: Double, accumulatedDepreciation: Double, bookValue: Double) {
        guard usefulLifeDays > 0 else {
            return (0, 0, purchasePrice)
        }
        let daily = (purchasePrice - residualValue) / Double(usefulLifeDays)
        let used = min(max(0, daysUsed), usefulLifeDays)
        let accumulated = Double(used) * daily
        let book = max(residualValue, purchasePrice - accumulated)
        return (daily, accumulated, book)
    }

    // MARK: - 预测层

    /// 加权移动平均：最近一期权重最大。
    /// 1 条 -> [1.0]；2 条 -> [0.6, 0.4]；3 条及以上 -> [0.5, 0.3, 0.2]
    static func weightedMovingAverage(_ intervals: [Double]) -> Double? {
        let cleaned = intervals.filter { $0 > 0 }
        guard !cleaned.isEmpty else { return nil }
        let recent = Array(cleaned.suffix(3))
        let weightsMap: [[Double]] = [
            [1.0],
            [0.6, 0.4],
            [0.5, 0.3, 0.2]
        ]
        let weights = weightsMap[recent.count - 1]
        return zip(recent.reversed(), weights).map(*).reduce(0, +)
    }

    /// 从购买记录序列中提取"相邻购买间隔天数"。
    /// 要求记录已按时间排序。
    static func intervals(from records: [PurchaseRecord]) -> [Double] {
        let dates = records.sorted { $0.purchasedAt < $1.purchasedAt }.map { $0.purchasedAt }
        guard dates.count >= 2 else { return [] }
        var gaps: [Double] = []
        for i in 1..<dates.count {
            let g = Calendar.current.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? 0
            if g > 0 { gaps.append(Double(g)) }
        }
        return gaps
    }

    /// 平均绝对误差（天数），与原始数据同量纲，便于用户理解。
    static func maeDays(intervals: [Double], predicted: Double?) -> Double? {
        guard let pred = predicted, !intervals.isEmpty else { return nil }
        let sum = intervals.reduce(0.0) { $0 + abs($1 - pred) }
        return sum / Double(intervals.count)
    }

    /// 产品启发式置信度（不是严格的统计结论）：
    /// 综合"样本量、误差、变异程度"打分。
    static func confidenceScore(sampleCount n: Int, maeDays: Double?, meanDays: Double?, cv: Double?) -> Double {
        let sampleBoost = min(1.0, Double(n) / 5.0)
        let safeMean = max(7.0, meanDays ?? 7.0)
        let errorPenalty = min(1.0, (maeDays ?? 7) / safeMean)
        let variabilityPenalty = min(1.0, cv ?? 0.6)
        let score = 0.2 + 0.35 * sampleBoost
                   + 0.25 * (1 - errorPenalty)
                   + 0.20 * (1 - variabilityPenalty)
        return max(0.1, min(0.95, score))
    }

    /// 变异系数 = std / mean
    static func coefficientOfVariation(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return nil }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance) / mean
    }

    /// 最近一次"实际撑了几天"——用于反推日均消耗。
    static func lastObservedLifeDays(for item: LifeItem) -> Int? {
        let sorted = item.purchases
            .sorted { $0.purchasedAt < $1.purchasedAt }
        // 找到最近一条带 lifeDaysObserved 的记录
        return sorted.reversed().first(where: { ($0.lifeDaysObserved ?? 0) > 0 })?.lifeDaysObserved
    }

    /// 纯只读：基于 item 已存的预测字段构建展示用 ForecastResult，
    /// 不修改模型。供详情页 view body 反复调用而不会产生副作用。
    static func displayResult(for item: LifeItem, today: Date = .now) -> ForecastResult {
        guard item.trackingMode == .consumable else {
            return ForecastResult(predictedDate: nil, predictedIntervalDays: nil,
                                  confidence: 0, maeDays: nil, note: "仅消耗类支持复购预测")
        }
        if let interval = item.predictedCycleDays, interval > 0 {
            // 复用已存的置信度估算口径，但纯只读不写回 item
            let records = item.purchases.sorted { $0.purchasedAt < $1.purchasedAt }
            let gaps = intervals(from: records)
            let mae = maeDays(intervals: gaps, predicted: interval)
            let mean = gaps.isEmpty ? interval : gaps.reduce(0, +) / Double(max(gaps.count, 1))
            let cv = coefficientOfVariation(gaps)
            let conf = confidenceScore(sampleCount: gaps.count,
                                       maeDays: mae, meanDays: mean, cv: cv)
            return ForecastResult(predictedDate: item.predictedDepletionDate,
                                  predictedIntervalDays: interval,
                                  confidence: conf,
                                  maeDays: mae,
                                  note: gaps.count >= 2
                                         ? "基于历史 \(gaps.count) 次购买间隔"
                                         : (item.packageQuantity != nil
                                            ? "按包装量与日均消耗估算"
                                            : "暂用模板默认周期"))
        }
        return ForecastResult(predictedDate: item.predictedDepletionDate,
                              predictedIntervalDays: item.predictedCycleDays,
                              confidence: 0,
                              maeDays: nil,
                              note: "记录一次购买后即可开始预测")
    }

    /// 对消耗类物品做复购预测，并把结果写回 item 字段。
    /// 返回 ForecastResult 供 UI 使用。
    @discardableResult
    static func predictRepurchaseDate(for item: LifeItem, today: Date = .now) -> ForecastResult {
        guard item.trackingMode == .consumable else {
            return ForecastResult(predictedDate: nil, predictedIntervalDays: nil,
                                  confidence: 0, maeDays: nil, note: "仅消耗类支持复购预测")
        }

        let records = item.purchases.sorted { $0.purchasedAt < $1.purchasedAt }
        let gaps = intervals(from: records)

        // 1) 优先用可量化库存估算：包装量 / 日均消耗
        if let pkg = item.packageQuantity, pkg > 0,
           let daily = estimatedDailyConsumption(
               packageQuantity: pkg,
               observedLifeDays: lastObservedLifeDays(for: item),
               fallbackDailyConsumption: item.averageDailyConsumption),
           daily > 0,
           let lastDate = records.last?.purchasedAt ?? item.purchaseDate {
            let remainingDays = pkg / daily
            let predDate = Calendar.current.date(byAdding: .day,
                                                 value: Int(remainingDays.rounded()),
                                                 to: lastDate) ?? lastDate
            item.predictedCycleDays = remainingDays
            item.predictedDepletionDate = predDate
            let cv = coefficientOfVariation(gaps)
            let conf = confidenceScore(sampleCount: gaps.count,
                                       maeDays: maeDays(intervals: gaps, predicted: remainingDays),
                                       meanDays: remainingDays,
                                       cv: cv)
            return ForecastResult(predictedDate: predDate,
                                  predictedIntervalDays: remainingDays,
                                  confidence: conf,
                                  maeDays: maeDays(intervals: gaps, predicted: remainingDays),
                                  note: "按包装量与日均消耗估算")
        }

        // 2) 历史间隔加权移动平均
        if let wma = weightedMovingAverage(gaps) {
            item.predictedCycleDays = wma
            let lastDate = records.last?.purchasedAt ?? item.purchaseDate ?? today
            let predDate = Calendar.current.date(byAdding: .day,
                                                 value: Int(wma.rounded()),
                                                 to: lastDate) ?? lastDate
            item.predictedDepletionDate = predDate
            let mae = maeDays(intervals: gaps, predicted: wma)
            let mean = gaps.reduce(0, +) / Double(max(gaps.count, 1))
            let cv = coefficientOfVariation(gaps)
            let conf = confidenceScore(sampleCount: gaps.count,
                                       maeDays: mae,
                                       meanDays: mean,
                                       cv: cv)
            return ForecastResult(predictedDate: predDate,
                                  predictedIntervalDays: wma,
                                  confidence: conf,
                                  maeDays: mae,
                                  note: gaps.count >= 2 ? "基于 \(gaps.count) 次历史购买间隔" : "样本偏少，仅供参考")
        }

        // 3) 回退：模板/用户设定的 expectedUseDays
        if let expected = item.expectedUseDays, expected > 0,
           let lastDate = item.purchaseDate {
            let predDate = Calendar.current.date(byAdding: .day, value: expected, to: lastDate) ?? lastDate
            item.predictedCycleDays = Double(expected)
            item.predictedDepletionDate = predDate
            return ForecastResult(predictedDate: predDate,
                                  predictedIntervalDays: Double(expected),
                                  confidence: 0.2,
                                  maeDays: nil,
                                  note: "数据不足，暂用模板默认周期")
        }

        return ForecastResult(predictedDate: nil, predictedIntervalDays: nil,
                              confidence: 0, maeDays: nil,
                              note: "记录一次购买后即可开始预测")
    }

    // MARK: - 预测 vs 实际回测
    /// 回测：对每次补货，用"之前的历史间隔 WMA"预测这次的天数，
    /// 与"实际相邻购买间隔"对照。用于绘制预测 vs 实际双线图。
    ///
    /// 返回结果不含最后一个点（最后一次购买没有"实际间隔"）。
    static func backtest(for item: LifeItem) -> [BacktestPoint] {
        let records = item.purchases.sorted { $0.purchasedAt < $1.purchasedAt }
        guard records.count >= 3 else { return [] }  // 至少 3 条才能形成 1 个预测点 + 1 个实际点

        var points: [BacktestPoint] = []
        for i in 2..<records.count {
            // 用 0..<i 的间隔预测第 i 次的到达时间
            let prior = Array(records.prefix(i))
            let dates = prior.map { $0.purchasedAt }
            var gaps: [Double] = []
            for j in 1..<dates.count {
                let g = Calendar.current.dateComponents([.day], from: dates[j-1], to: dates[j]).day ?? 0
                if g > 0 { gaps.append(Double(g)) }
            }
            guard let predicted = weightedMovingAverage(gaps) else { continue }

            let actualDays = max(0, Calendar.current.dateComponents([.day],
                from: records[i-1].purchasedAt,
                to: records[i].purchasedAt).day ?? 0)

            points.append(BacktestPoint(
                date: records[i].purchasedAt,
                predicted: predicted,
                actual: Double(actualDays)
            ))
        }
        return points
    }

    /// 回测点的预测准确率摘要
    static func backtestSummary(for item: LifeItem) -> BacktestSummary? {
        let points = backtest(for: item)
        guard !points.isEmpty else { return nil }
        let errors = points.map { abs($0.predicted - $0.actual) }
        let mae = errors.reduce(0, +) / Double(errors.count)
        let mean = points.map { $0.actual }.reduce(0, +) / Double(points.count)
        let mape: Double? = {
            let sum = points.reduce(0.0) { $0 + ($1.actual > 0 ? abs($1.predicted - $1.actual) / $1.actual : 0) }
            return points.contains { $0.actual > 0 } ? (sum / Double(points.count) * 100) : nil
        }()
        return BacktestSummary(sampleCount: points.count, maeDays: mae, meanDays: mean, mape: mape)
    }

    // MARK: - 提醒层

    /// 计算提醒日期：在"预测需要日"基础上，扣除提前期、物流提前期与缓冲天数。
    static func reminderDate(
        predictedNeedDate: Date,
        remindBeforeDays: Int,
        merchantLeadDays: Int,
        bufferDays: Int
    ) -> Date {
        let offset = -(remindBeforeDays + merchantLeadDays + bufferDays)
        return Calendar.current.date(byAdding: .day, value: offset, to: predictedNeedDate) ?? predictedNeedDate
    }

    /// 综合物品的提醒日期（结合其 ReminderPolicy 与 shippingLeadDays）
    ///
    /// 口径说明：shippingLeadDays 表示"从决定购买到拿到手所需天数"。
    /// 该字段应在物品关联商家时由商家的 leadDays 同步写入（见
    /// MerchantStore 或编辑流程），从而让商家提前期真正参与提醒计算。
    static func reminderDate(for item: LifeItem) -> Date? {
        guard let target = targetDate(for: item) else { return nil }
        let policy = item.reminderPolicy ?? ReminderPolicy.defaultPolicy
        guard policy.isEnabled else { return nil }
        return reminderDate(
            predictedNeedDate: target,
            remindBeforeDays: policy.remindBeforeDays,
            merchantLeadDays: item.shippingLeadDays,
            bufferDays: policy.bufferDays
        )
    }

    /// 物品的"建议下单日期"= 目标日 - 物流提前期 - 缓冲天数。
    /// 专为首页"未来 N 天建议下单"使用：哪怕物品本身还有 10 天才用完，
    /// 如果物流要 2 天、缓冲 1 天，则建议下单日是 now+7，仍应纳入推荐。
    static func suggestedPurchaseDate(for item: LifeItem) -> Date? {
        guard let target = targetDate(for: item) else { return nil }
        let buffer = item.reminderPolicy?.bufferDays ?? 1
        let offset = -(item.shippingLeadDays + buffer)
        return Calendar.current.date(byAdding: .day, value: offset, to: target) ?? target
    }

    /// 距"建议下单日"还剩几天（负数=已过建议下单日，应尽快下单）
    static func daysUntilSuggestedPurchase(for item: LifeItem, now: Date = .now) -> Int? {
        guard let d = suggestedPurchaseDate(for: item) else { return nil }
        return daysLeft(from: now, to: d)
    }
}
