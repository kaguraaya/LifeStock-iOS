import SwiftUI
import SwiftData
import UIKit
import Charts

/// 物品详情页：统一查看物品全貌。
///
/// 结构：头图/状态 -> 价值 -> 历史购买 -> 图表 -> 备注
struct ItemDetailView: View {

    @Environment(\.modelContext) private var context
    @Bindable var item: LifeItem

    @State private var snap: ItemSnapshot?
    @State private var showEdit = false
    @State private var showRestock = false
    @State private var showPurchaseEdit: PurchaseRecord?
    @State private var showAddPurchase = false
    @State private var showSnoozeFeedback = false
    @State private var previewReceiptPath: ReceiptPath?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroImage
                headerCard
                valueCard
                actionRow
                purchaseHistorySection
                if item.trackingMode == .consumable {
                    forecastSection
                }
                if item.trackingMode == .durable {
                    depreciationCard
                }
                noteCard
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.bg)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button {
                        item.status = (item.status == .archived ? .active : .archived)
                        try? context.save()
                    } label: {
                        Label(item.status == .archived ? "恢复追踪" : "归档",
                              systemImage: "archivebox")
                    }
                    Button {
                        NotificationService.shared.snooze(item: item)
                        showSnoozeFeedback = true
                    } label: {
                        Label("稍后提醒", systemImage: "clock")
                    }
                    .tint(.orange)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            refreshSnapshot()
            // 消耗类：进入详情页时计算一次预测（写回 item 字段），
            // 之后 forecastSection 只读这些字段，避免在 view body 内修改模型。
            if item.trackingMode == .consumable {
                ForecastEngine.predictRepurchaseDate(for: item)
            }
        }
        .sheet(isPresented: $showEdit) {
            ItemEditView(item: item) { refreshSnapshot() }
        }
        .sheet(isPresented: $showRestock) {
            RestockSheet(item: item) { refreshSnapshot() }
        }
        .sheet(isPresented: $showAddPurchase) {
            PurchaseEditSheet(item: item, record: nil) { refreshSnapshot() }
        }
        .sheet(item: $showPurchaseEdit) { record in
            PurchaseEditSheet(item: item, record: record) { refreshSnapshot() }
        }
        .sheet(item: $previewReceiptPath) { path in
            ReceiptPreviewSheet(path: path)
        }
        .alert("已设置稍后提醒", isPresented: $showSnoozeFeedback) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("将在 \(item.reminderPolicy?.snoozeHours ?? 8) 小时后再次提醒你。")
        }
    }

    private func refreshSnapshot() {
        snap = ItemSnapshotBuilder.snapshot(for: item)
    }

    // MARK: 头图（如果有缩略图则展示横幅）
    @ViewBuilder
    private var heroImage: some View {
        if let data = item.thumbnailData, let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.35), .clear],
                                   startPoint: .bottom, endPoint: .center)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
                .padding(.horizontal, AppTheme.pad)
        }
    }

    // MARK: 头部状态卡
    private var headerCard: some View {
        let s = snap ?? ItemSnapshotBuilder.snapshot(for: item)
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: item.trackingMode.symbol)
                    .font(.system(size: 36))
                    .foregroundStyle(s.urgencyColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.title3.bold())
                    HStack {
                        ModeBadge(mode: item.trackingMode)
                        Text(item.category.displayName)
                            .font(.caption)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.gray.opacity(0.15), in: Capsule())
                        if let brand = item.brand {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("状态").font(.caption).foregroundStyle(.secondary)
                    Text(s.statusText)
                        .font(.headline)
                        .foregroundStyle(s.urgencyColor)
                }
                Spacer()
                if let target = s.targetDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("目标日期").font(.caption).foregroundStyle(.secondary)
                        Text(RelativeDateText.short(target))
                            .font(.headline)
                    }
                }
            }
        }
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(.horizontal, AppTheme.pad)
    }

    // MARK: 价值卡
    private var valueCard: some View {
        let daily = ForecastEngine.dailyCost(for: item)
        let last = item.purchasePrice
        return VStack(alignment: .leading, spacing: 12) {
            Text("价值").font(.headline)
            HStack {
                metricCell(title: "日均成本", value: daily.map { String(format: "%.2f 元", $0) } ?? "—")
                Divider().frame(height: 36)
                metricCell(title: "最近总价", value: last.map { String(format: "%.2f 元", $0) } ?? "—")
                if let unitP = item.unitPrice, unitP > 0, let u = item.unitName {
                    Divider().frame(height: 36)
                    metricCell(title: "单价",
                               value: String(format: "%.3f 元/%@", unitP, u))
                }
            }
        }
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(.horizontal, AppTheme.pad)
    }

    private func metricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 动作行
    private var actionRow: some View {
        HStack(spacing: 12) {
            primaryAction("我已补货", system: "cart.fill") {
                showRestock = true
            }
            secondaryAction("新增记录", system: "doc.badge.plus") {
                showAddPurchase = true
            }
        }
        .padding(.horizontal, AppTheme.pad)
    }

    private func primaryAction(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
    }

    private func secondaryAction(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }

    // MARK: 历史购买
    private var purchaseHistorySection: some View {
        let sorted = item.purchases.sorted { $0.purchasedAt > $1.purchasedAt }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("历史购买").font(.headline)
                Spacer()
                if !sorted.isEmpty {
                    Text("共 \(sorted.count) 次").font(.caption).foregroundStyle(.secondary)
                }
            }
            if sorted.isEmpty {
                Text("还没有购买记录，补货或新增记录后会出现在这里。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(sorted) { record in
                    Button {
                        showPurchaseEdit = record
                    } label: {
                        purchaseRow(record)
                    }
                    .buttonStyle(.plain)
                    if record.id != sorted.last?.id { Divider() }
                }
            }
        }
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(.horizontal, AppTheme.pad)
    }

    private func purchaseRow(_ r: PurchaseRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(RelativeDateText.short(r.purchasedAt)).font(.subheadline.weight(.medium))
                if let life = r.lifeDaysObserved {
                    Text("实际用了 \(life) 天").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f 元", r.effectiveCost ?? r.totalPrice))
                    .font(.subheadline.weight(.semibold))
                if let unitP = r.unitPrice, unitP > 0, let u = item.unitName {
                    Text(String(format: "%.3f 元/%@", unitP, u))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            // 小票图入口
            if r.receiptImagePath != nil {
                Button {
                    previewReceiptPath = ReceiptPath(path: r.receiptImagePath)
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: 预测信息
    private var forecastSection: some View {
        // 只读构建展示结果，不在 view body 内修改模型（预测写回在 onAppear 完成）
        let result = ForecastEngine.displayResult(for: item)
        let level = ConfidenceLevel.from(score: result.confidence)
        let backtest = ForecastEngine.backtest(for: item)
        let summary = ForecastEngine.backtestSummary(for: item)
        return VStack(alignment: .leading, spacing: 8) {
            Text("复购预测").font(.headline)
            HStack {
                Image(systemName: "waveform.path.ecg").foregroundStyle(AppTheme.accent)
                if let interval = result.predictedIntervalDays {
                    Text(String(format: "预测周期 %.1f 天", interval))
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("数据不足").font(.subheadline)
                }
                Spacer()
                ConfidenceTag(level: level)
            }
            Text(result.note).font(.caption).foregroundStyle(.secondary)

            // 预测 vs 实际双线图
            if backtest.count >= 2 {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("预测 vs 实际").font(.subheadline.weight(.semibold))
                    Chart(backtest) { pt in
                        LineMark(x: .value("日期", pt.date),
                                 y: .value("天数", pt.predicted))
                            .foregroundStyle(AppTheme.accent)
                            .symbol(.square)
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("日期", pt.date),
                                 y: .value("天数", pt.actual))
                            .foregroundStyle(.green)
                            .symbol(.circle)
                            .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 160)
                    .chartLegend(position: .bottom) {
                        HStack(spacing: 16) {
                            Label("预测", systemImage: "square.fill").foregroundStyle(AppTheme.accent).font(.caption)
                            Label("实际", systemImage: "circle.fill").foregroundStyle(.green).font(.caption)
                        }
                    }

                    if let s = summary {
                        HStack(spacing: 12) {
                            metricCell(title: "样本", value: "\(s.sampleCount)")
                            Divider().frame(height: 28)
                            metricCell(title: "平均误差", value: String(format: "%.1f 天", s.maeDays))
                            if let mape = s.mape {
                                Divider().frame(height: 28)
                                metricCell(title: "MAPE", value: String(format: "%.0f%%", mape))
                            }
                        }
                        .padding(.top, 4)
                        Text("平均误差越小、预测越准。MAPE 为平均绝对百分比误差。")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("至少 3 次购买记录后，这里会显示预测 vs 实际对比图。")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(.horizontal, AppTheme.pad)
    }

    // MARK: 折旧（耐用品）
    private var depreciationCard: some View {
        guard let price = item.devicePurchasePrice,
              let life = item.usefulLifeDays,
              let purchase = item.purchaseDate else {
            return AnyView(EmptyView())
        }
        let residual = item.residualValue ?? 0
        let daysUsed = max(0, ForecastEngine.daysLeft(from: purchase, to: .now)) // purchase 在过去 -> 已用天数为正
        let dep = ForecastEngine.straightLineDepreciation(
            purchasePrice: price, residualValue: residual,
            usefulLifeDays: life, daysUsed: daysUsed
        )
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("折旧与当前价值").font(.headline)
                HStack {
                    metricCell(title: "购入价", value: String(format: "%.0f 元", price))
                    Divider().frame(height: 36)
                    metricCell(title: "已用", value: "\(daysUsed) 天")
                    Divider().frame(height: 36)
                    metricCell(title: "累计折旧", value: String(format: "%.0f 元", dep.accumulatedDepreciation))
                    Divider().frame(height: 36)
                    metricCell(title: "账面价值", value: String(format: "%.0f 元", dep.bookValue))
                }
                Text(String(format: "日均折旧 %.2f 元", dep.dailyDepreciation))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .padding(.horizontal, AppTheme.pad)
        )
    }

    // MARK: 备注
    private var noteCard: some View {
        Group {
            if !item.note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("备注").font(.headline)
                    Text(item.note).font(.subheadline).foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.pad)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
                .padding(.horizontal, AppTheme.pad)
            }
        }
    }
}

// MARK: - 小票图预览
struct ReceiptPath: Identifiable {
    let id = UUID()
    let path: String
}

struct ReceiptPreviewSheet: View {
    let path: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let img = ImageStore.load(relativePath: path) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .padding()
                } else {
                    EmptyStateView(
                        symbol: "photo.badge.exclamationmark",
                        title: "小票图已丢失",
                        message: "原图可能已被清理。新建/补货时重新扫描可恢复。"
                    )
                    .padding(.top, 60)
                }
            }
            .background(AppTheme.bg)
            .navigationTitle("小票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
