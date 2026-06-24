import SwiftUI
import SwiftData

/// 首页：运营面板而非"全部列表"。
///
/// 从上到下排列（对应报告首页布局）：
/// [导航栏]  生活余量管家        [+]
/// [摘要区]  总物品数 | 本周待处理 | 本月花费
/// [高优先]  今天最该处理的 3 项
/// [建议购买] 未来 7 天建议下单
/// [价值概览] 日均成本最高 / 最近涨价 / 订阅即将扣费
struct HomeView: View {

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<LifeItem> { $0.statusRaw == "active" },
           sort: [SortDescriptor(\LifeItem.updatedAt, order: .reverse)])
    private var items: [LifeItem]

    @Binding var showQuickAdd: Bool
    @State private var selectedItem: LifeItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if items.isEmpty {
                        heroEmptyState
                    } else {
                        summaryRow
                        highPrioritySection
                        suggestBuySection
                        valueOverviewSection
                    }
                }
                .padding(.vertical, 16)
            }
            .background(AppTheme.bg)
            .navigationTitle("生活余量管家")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("快速新增物品")
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
        }
    }

    // MARK: 摘要区
    private var summaryRow: some View {
        let snapshots = items.map { ItemSnapshotBuilder.snapshot(for: $0) }
        let pendingThisWeek = snapshots.filter {
            ($0.daysLeft ?? 999) <= 7
        }.count
        let monthSpend = ForecastEngine.spend(
            inLast: 30,
            records: items.flatMap { $0.purchases }
        )
        let saved = InsightEngine.totalSavings(items: items)
        return VStack(spacing: 12) {
            // 强调头部：本周待处理 + 一句文案，渐变背景
            VStack(alignment: .leading, spacing: 6) {
                Text("本周待处理")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(pendingThisWeek)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text("项需关注")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(AppTheme.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .cardShadow()

            HStack(spacing: 12) {
                SummaryCard(title: "追踪中", value: "\(snapshots.count)",
                            subtitle: "件物品", symbol: "shippingbox.fill")
                SummaryCard(title: "本月花费", value: MoneyFormatter.compact(monthSpend),
                            subtitle: "近 30 天", symbol: "yensign.circle.fill",
                            tint: .green)
                SummaryCard(title: "累计节省", value: MoneyFormatter.compact(saved),
                            subtitle: "元", symbol: "tag.fill", tint: AppTheme.accent)
            }
        }
        .padding(.horizontal, AppTheme.pad)
    }

    // MARK: 高优先卡片
    private var highPrioritySection: some View {
        let snapshots = items
            .map { ItemSnapshotBuilder.snapshot(for: $0) }
            .sorted { $0.urgency < $1.urgency }   // urgency 0 = 最高优先
        let top = Array(snapshots.prefix(3))

        return CardSection(title: "今天最该处理",
                           subtitle: "按紧迫度排序，最多展示 3 项") {
            VStack(spacing: 10) {
                ForEach(top) { snap in
                    if let item = item(for: snap.id) {
                        ItemCard(snapshot: snap) {
                            selectedItem = item
                        }
                    }
                }
            }
        }
    }

    // MARK: 建议购买
    private var suggestBuySection: some View {
        // 未来 7 天内需要处理、且尚未购买的物品
        let snapshots = items
            .map { ItemSnapshotBuilder.snapshot(for: $0) }
            .filter { snap in
                guard let d = snap.daysLeft else { return false }
                return d >= 0 && d <= 7
            }
            .sorted { ($0.daysLeft ?? 0) < ($1.daysLeft ?? 0) }

        return CardSection(title: "未来 7 天建议下单",
                           subtitle: "结合购买来源的物流提前期") {
            if snapshots.isEmpty {
                Text("暂无即将到期的物品，节奏不错。")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(snapshots) { snap in
                        if let item = item(for: snap.id) {
                            CompactItemRow(snapshot: snap) {
                                selectedItem = item
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: 价值概览
    private var valueOverviewSection: some View {
        let topDaily = items
            .compactMap { item -> (LifeItem, Double)? in
                guard let cost = ForecastEngine.dailyCost(for: item), cost > 0 else { return nil }
                return (item, cost)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)

        let upcomingSub = items.filter {
            $0.trackingMode == .subscription &&
            (ForecastEngine.daysLeft(for: $0) ?? 999) <= 14
        }

        return CardSection(title: "价值概览",
                           subtitle: "钱主要在消耗什么，以及即将扣费的订阅") {
            VStack(alignment: .leading, spacing: 12) {
                // 日均成本最高 Top3
                VStack(alignment: .leading, spacing: 6) {
                    Text("日均成本最高").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if topDaily.isEmpty {
                        Text("暂无可计算日均成本的物品")
                            .font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(topDaily), id: \.0.id) { (item, cost) in
                            HStack {
                                Text(item.name).font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f 元/天", cost))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
                        }
                    }
                }

                Divider()

                // 即将扣费订阅
                VStack(alignment: .leading, spacing: 6) {
                    Text("订阅即将扣费").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if upcomingSub.isEmpty {
                        Text("近两周没有订阅扣费")
                            .font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(upcomingSub) { item in
                            HStack {
                                Image(systemName: "creditcard")
                                    .foregroundStyle(.secondary)
                                Text(item.name).font(.subheadline)
                                Spacer()
                                if let days = ForecastEngine.daysLeft(for: item) {
                                    Text(RelativeDateText.days(days))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
                        }
                    }
                }
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        }
    }

    // MARK: 空状态
    private var heroEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent)
            Text("欢迎来到 LifeStock")
                .font(.title2.bold())
            Text("它会过期、会用完、值不值、何时买——\n由你的一手数据说话。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showQuickAdd = true
            } label: {
                Label("添加第一件物品", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    // MARK: 辅助
    private func item(for id: UUID) -> LifeItem? {
        items.first { $0.id == id }
    }
}
