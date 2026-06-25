import SwiftUI
import SwiftData
import Charts

/// 洞察页：价值管理与消费预测。
///
/// 图表"少而准"，每个图回答一个问题：
/// - 分类支出占比（钱花在哪些类目）
/// - 月度花费（柱状，月环比）
/// - 单个物品价格变化（折线）
/// - 订阅成本分布（条形）
struct InsightsView: View {

    @Query(filter: #Predicate<LifeItem> { $0.statusRaw == "active" })
    private var items: [LifeItem]

    @State private var timeWindow: TimeWindow = .month90
    @State private var priceSelectedItem: UUID?

    enum TimeWindow: String, CaseIterable, Identifiable {
        case month30, month90, month180
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .month30:  return 30
            case .month90:  return 90
            case .month180: return 180
            }
        }
        var displayName: String {
            switch self {
            case .month30:  return "近 30 天"
            case .month90:  return "近 90 天"
            case .month180: return "近半年"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if allRecords().isEmpty {
                        EmptyStateView(
                            symbol: "chart.bar.xaxis",
                            title: "先记录几次购买",
                            message: "LifeStock 才能学会你的复购节奏与消费结构。"
                        )
                        .padding(.top, 60)
                    } else {
                        windowPicker
                        summaryCards
                        savingsSection
                        categoryChart
                        monthlyChart
                        priceTrendChart
                        unitPriceCompareChart
                        subscriptionChart
                    }
                }
                .padding(.vertical, 16)
            }
            .background(AppTheme.bg)
            .navigationTitle("洞察")
        }
    }

    private var windowPicker: some View {
        Picker("时间窗", selection: $timeWindow) {
            ForEach(TimeWindow.allCases) { w in
                Text(w.displayName).tag(w)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppTheme.pad)
    }

    private var summaryCards: some View {
        let records = filteredRecords()
        let total = ForecastEngine.cumulativeSpend(records: records)
        let count = records.count
        let avg = count > 0 ? total / Double(count) : 0
        let dailyAvg = Double(timeWindow.days) > 0 ? total / Double(timeWindow.days) : 0
        return CardSection(title: "支出总览", subtitle: timeWindow.displayName) {
            HStack(spacing: 12) {
                SummaryCard(title: "累计花费", value: MoneyFormatter.compact(total),
                            subtitle: "元", symbol: "yensign.circle.fill", tint: .green)
                SummaryCard(title: "购买次数", value: "\(count)",
                            subtitle: "次", symbol: "cart.fill")
                SummaryCard(title: "日均花费", value: String(format: "%.1f", dailyAvg),
                            subtitle: "元/天", symbol: "calendar", tint: AppTheme.accent)
            }
        }
    }

    // MARK: 节省统计
    private var savingsSection: some View {
        let totalSaved = InsightEngine.totalSavings(items: items)
        // 找出"省得最多"的一次购买
        let bestSave: (name: String, amount: Double)? = {
            var best: (name: String, amount: Double)? = nil
            for item in items {
                for r in item.purchases {
                    if let s = InsightEngine.savings(for: r, in: item), s > 0 {
                        if best == nil || s > best!.amount {
                            best = (item.name, s)
                        }
                    }
                }
            }
            return best
        }()
        return CardSection(title: "节省统计", subtitle: "以历史中位单价为基准的估算") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    SummaryCard(title: "累计节省", value: MoneyFormatter.string(totalSaved),
                                subtitle: "元", symbol: "yensign.circle.fill", tint: .green)
                    SummaryCard(title: "最省一笔",
                                value: bestSave == nil ? "—" : String(format: "%.1f", bestSave!.amount),
                                subtitle: bestSave == nil ? "暂无" : bestSave!.name,
                                symbol: "tag.fill", tint: AppTheme.accent)
                }
                Text("口径：对同一物品的历史单价取中位数，估算每次购买相对中位的节省额。仅作趣味参考。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 分类支出占比
    private var categoryChart: some View {
        let data = categoryBreakdown()
        return CardSection(title: "分类支出占比", subtitle: "钱主要花在哪些类目") {
            VStack(alignment: .leading, spacing: 8) {
                if data.isEmpty {
                    Text("所选时间窗内暂无购买记录")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Chart(data) { d in
                        SectorMark(angle: .value("金额", d.amount),
                                   innerRadius: .ratio(0.55),
                                   angularInset: 1.5)
                            .foregroundStyle(by: .value("分类", d.category))
                    }
                    .frame(height: 200)

                    ForEach(data) { d in
                        HStack {
                            Circle().fill(.gray.opacity(0.3)).frame(width: 8, height: 8)
                            Text(d.category).font(.caption)
                            Spacer()
                            Text(MoneyFormatter.string(d.amount))
                                .font(.caption.weight(.medium))
                        }
                    }
                }
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 月度花费柱状
    private var monthlyChart: some View {
        let data = monthlyBreakdown()
        return CardSection(title: "月度花费", subtitle: "这个月比上个月花得多还是少") {
            VStack(alignment: .leading, spacing: 8) {
                Chart(data) { d in
                    BarMark(x: .value("月份", d.label),
                            y: .value("金额", d.amount))
                        .foregroundStyle(AppTheme.accent.gradient)
                        .cornerRadius(4)
                }
                .frame(height: 200)
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 单个物品价格变化
    private var priceTrendChart: some View {
        let consumables = items.filter { !$0.purchases.isEmpty }
        let selected = consumables.first(where: { $0.id == priceSelectedItem }) ?? consumables.first
        let priceData: [PricePoint] = {
            guard let s = selected else { return [] }
            return s.purchases.sorted { $0.purchasedAt < $1.purchasedAt }.map {
                PricePoint(date: $0.purchasedAt,
                           price: $0.effectiveCost ?? $0.totalPrice)
            }
        }()
        return CardSection(title: "价格变化", subtitle: "纸巾最近买贵了还是便宜了") {
            VStack(alignment: .leading, spacing: 8) {
                if consumables.isEmpty {
                    Text("还没有带购买记录的物品").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Picker("选择物品", selection: Binding(
                        get: { selected?.id ?? UUID() },
                        set: { priceSelectedItem = $0 }
                    )) {
                        ForEach(consumables) { c in
                            Text(c.name).tag(c.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if priceData.count >= 2 {
                        Chart(priceData) { p in
                            LineMark(x: .value("日期", p.date),
                                     y: .value("金额", p.price))
                                .foregroundStyle(AppTheme.accent)
                                .symbol(.circle)
                            AreaMark(x: .value("日期", p.date),
                                     y: .value("金额", p.price))
                                .foregroundStyle(AppTheme.accent.opacity(0.15))
                        }
                        .frame(height: 200)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    } else {
                        Text("\(selected?.name ?? "")至少需要 2 条记录才能绘制价格趋势")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 跨物品单价对比
    private var unitPriceCompareChart: some View {
        // 取所有消耗类物品的最近单价，按"单位"分组横向比较
        let data: [UnitPriceRow] = {
            var rows: [UnitPriceRow] = []
            for item in items where item.trackingMode == .consumable {
                guard let unitP = item.unitPrice, unitP > 0 else { continue }
                let unit = item.unitName ?? "单位"
                rows.append(UnitPriceRow(name: item.name, unitPrice: unitP, unit: unit))
            }
            return rows.sorted { $0.unitPrice < $1.unitPrice }  // 便宜在上
        }()
        let minP = data.first?.unitPrice
        let maxP = data.last?.unitPrice

        return CardSection(title: "单价对比", subtitle: "同类消耗品谁更划算（按最近单价）") {
            VStack(alignment: .leading, spacing: 8) {
                if data.isEmpty {
                    Text("还没有带单价的消耗类物品").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.name).font(.subheadline.weight(.medium))
                                if idx == 0 {
                                    Text("最划算")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                                Text(String(format: "%.3f 元/%@", row.unitPrice, row.unit))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            // 横条：相对最贵项的比例
                            GeometryReader { geo in
                                let ratio = maxP.map { CGFloat(row.unitPrice / $0) } ?? 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(idx == 0
                                          ? AnyShapeStyle(Color.green.opacity(0.6))
                                          : AnyShapeStyle(AppTheme.accent.opacity(0.5)))
                                    .frame(width: max(8, geo.size.width * ratio), height: 8)
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                    Text("绿色为最便宜的一档。单价越低越划算，但也要结合实际用量与质量。")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 订阅成本分布
    private var subscriptionChart: some View {
        let subs = items.filter { $0.trackingMode == .subscription }
        let data: [SubCost] = subs.compactMap {
            guard let daily = ForecastEngine.dailyCost(for: $0) else { return nil }
            return SubCost(name: $0.name, daily: daily,
                           monthly: daily * 30, yearly: daily * 365)
        }
        return CardSection(title: "订阅成本分布", subtitle: "哪个服务最贵") {
            VStack(alignment: .leading, spacing: 8) {
                if data.isEmpty {
                    Text("还没有订阅类物品").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Chart(data) { d in
                        BarMark(x: .value("日均成本", d.daily),
                                y: .value("订阅", d.name))
                            .foregroundStyle(AppTheme.accent.gradient)
                            .annotation(position: .trailing) {
                                Text(String(format: "%.2f 元/天", d.daily))
                                    .font(.caption2)
                            }
                    }
                    .frame(height: CGFloat(max(120, data.count * 44)))
                    .chartXAxis {
                        AxisMarks()
                    }
                }
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 数据聚合
    private func allRecords() -> [PurchaseRecord] {
        items.flatMap { $0.purchases }
    }

    private func filteredRecords() -> [PurchaseRecord] {
        let cutoff = Calendar.current.date(byAdding: .day,
                                           value: -timeWindow.days, to: .now) ?? .now
        return allRecords().filter { $0.purchasedAt >= cutoff }
    }

    private func categoryBreakdown() -> [CategoryAmount] {
        let recs = filteredRecords()
        var dict: [String: Double] = [:]
        for r in recs {
            let cat = (items.first(where: { $0.id == r.item?.id })?.category.displayName) ?? "其他"
            let cost = r.effectiveCost ?? r.totalPrice
            dict[cat, default: 0] += cost
        }
        return dict.map { CategoryAmount(category: $0.key, amount: $0.value) }
                   .sorted { $0.amount > $1.amount }
    }

    private func monthlyBreakdown() -> [MonthlyAmount] {
        let recs = allRecords()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy-MM"
        var dict: [String: Double] = [:]
        for r in recs {
            let key = fmt.string(from: r.purchasedAt)
            dict[key, default: 0] += r.effectiveCost ?? r.totalPrice
        }
        // 取最近 6 个月
        let now = Date()
        var months: [MonthlyAmount] = []
        for i in stride(from: 5, through: 0, by: -1) {
            if let d = cal.date(byAdding: .month, value: -i, to: now) {
                let key = fmt.string(from: d)
                let label = String(key.suffix(2)) + "月"
                months.append(MonthlyAmount(label: label, amount: dict[key] ?? 0))
            }
        }
        return months
    }
}

// MARK: - Chart 数据模型
private struct CategoryAmount: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
}
private struct MonthlyAmount: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
}
private struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}
private struct UnitPriceRow: Identifiable {
    let id = UUID()
    let name: String
    let unitPrice: Double
    let unit: String
}
private struct SubCost: Identifiable {
    let id = UUID()
    let name: String
    let daily: Double
    let monthly: Double
    let yearly: Double
}
