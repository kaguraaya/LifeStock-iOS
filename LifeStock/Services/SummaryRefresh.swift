import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 把当前数据快照写入 SummaryStore（供小组件读取）。
///
/// 调用时机：保存物品、补货、删除、清空、演示重载之后。
/// 单独抽出，避免在每个 View 里重复实现。
enum SummaryRefresh {

    @MainActor
    static func refresh(context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<LifeItem>(
            predicate: #Predicate { $0.statusRaw == "active" }
        ))) ?? []

        let snapshots = items.map { ItemSnapshotBuilder.snapshot(for: $0) }
        let pending = snapshots.filter { ($0.daysLeft ?? 999) <= 7 }.count
        let spend = ForecastEngine.spend(inLast: 30, records: items.flatMap { $0.purchases })

        let top = snapshots
            .sorted { $0.urgency < $1.urgency }
            .prefix(3)
            .map {
                SummaryStore.Item(
                    id: $0.id.uuidString,
                    name: $0.name,
                    statusText: $0.statusText,
                    urgency: $0.urgency,
                    daysLeft: $0.daysLeft
                )
            }

        SummaryStore.write(SummaryStore.Summary(
            totalItems: snapshots.count,
            pendingThisWeek: pending,
            monthSpend: spend,
            topItems: Array(top),
            updatedAt: .now
        ))

        // 同时刷新 Widget 时间线（受系统预算约束，不会频繁触发）
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
