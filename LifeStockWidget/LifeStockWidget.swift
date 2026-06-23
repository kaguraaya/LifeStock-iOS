import WidgetKit
import SwiftUI

/// 主小组件：提供"摘要（小）"与"待处理列表（中）"两种尺寸。
///
/// 刷新策略：
/// - 系统按预算调用 getTimeline，间隔至少 30 分钟以上；
/// - App 端在数据变更后通过 WidgetCenter.reloadAllTimelines() 主动触发，
///   由系统决定真实刷新时机。
struct LifeStockWidget: Widget {
    let kind: String = "LifeStockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LifeStockWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.widgetBackground)
                }
        }
        .configurationDisplayName("生活余量管家")
        .description("一眼看清：本周待处理、本月花费与最该处理的物品。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now, summary: SummaryStore.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let summary = SummaryStore.read() ?? SummaryStore.placeholder
        completion(SimpleEntry(date: .now, summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let summary = SummaryStore.read() ?? SummaryStore.placeholder
        let entry = SimpleEntry(date: .now, summary: summary)
        // 下次由系统预算决定；这里给出 45 分钟后的占位刷新点
        let next = Calendar.current.date(byAdding: .minute, value: 45, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let summary: SummaryStore.Summary
}

// MARK: - View
struct LifeStockWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidget(summary: entry.summary)
        case .systemMedium: MediumWidget(summary: entry.summary)
        default:            SmallWidget(summary: entry.summary)
        }
    }
}

// MARK: - 小尺寸：摘要
struct SmallWidget: View {
    let summary: SummaryStore.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.orange)
                Text("生活余量").font(.caption.weight(.semibold))
                Spacer()
            }
            Text("\(summary.pendingThisWeek)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(summary.pendingThisWeek > 0 ? .orange : .primary)
            Text("本周待处理")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Image(systemName: "yensign.circle")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("本月 \(String(format: "%.0f", summary.monthSpend)) 元")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }
}

// MARK: - 中尺寸：待处理列表
struct MediumWidget: View {
    let summary: SummaryStore.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(.orange)
                Text("最该处理").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(summary.totalItems) 件 · 本月 \(String(format: "%.0f", summary.monthSpend)) 元")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if summary.topItems.isEmpty {
                Spacer()
                Text("暂无待处理，节奏不错。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(summary.topItems) { item in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(urgencyColor(item.urgency))
                            .frame(width: 3, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(item.statusText)
                                .font(.caption2)
                                .foregroundStyle(urgencyColor(item.urgency))
                        }
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }

    private func urgencyColor(_ u: Int) -> Color {
        switch u {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .blue
        default: return .gray.opacity(0.7)
        }
    }
}

// MARK: - 预览
#Preview(as: .systemSmall) {
    LifeStockWidget()
} timeline: {
    SimpleEntry(date: .now, summary: SummaryStore.placeholder)
    SimpleEntry(date: .now, summary: SummaryStore.Summary(
        totalItems: 12,
        pendingThisWeek: 3,
        monthSpend: 186.5,
        topItems: [
            .init(id: "1", name: "清风纸巾", statusText: "预计 3 天后用完", urgency: 1, daysLeft: 3),
            .init(id: "2", name: "特仑苏牛奶", statusText: "今天到期", urgency: 0, daysLeft: 0),
        ],
        updatedAt: .now
    ))
}
