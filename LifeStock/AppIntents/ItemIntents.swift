import Foundation
import AppIntents
import SwiftData

/// App Intents / App Shortcuts 入口。
///
/// 暴露三个高频动作给 Siri、Shortcuts、Spotlight：
/// - 快速补货（最近一次购买参数 + 默认今天）
/// - 快速新增（最少字段直接入库）
/// - 标记已处理（取消该物品的待发通知）
///
/// 注：AppIntents 在 App target 内即可工作，无需额外扩展。
/// 这里只做入口与骨架；复杂表单仍走 App 内 UI。

/// 共享的 ModelContainer 句柄（由 App 启动时注入）
enum SharedContainer {
    static var container: ModelContainer?
}

// MARK: - 物品选择实体
struct ItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "物品"
    static var defaultQuery = ItemEntityQuery()

    var id: UUID
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    var representation: IntentItem { IntentItem(id: id, displayName: displayName) }

    init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
    init(_ rep: IntentItem) {
        self.id = rep.id
        self.displayName = rep.displayName
    }
}

struct IntentItem: Identifiable {
    let id: UUID
    let displayName: String
}

struct ItemEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ItemEntity] {
        guard let container = SharedContainer.container else { return [] }
        let context = ModelContext(container)
        let items = try context.fetch(FetchDescriptor<LifeItem>())
        return items.filter { identifiers.contains($0.id) }
            .map { ItemEntity(id: $0.id, displayName: $0.name) }
    }

    func suggestedEntities() async throws -> [ItemEntity] {
        guard let container = SharedContainer.container else { return [] }
        let context = ModelContext(container)
        let items = try context.fetch(FetchDescriptor<LifeItem>(
            predicate: #Predicate { $0.statusRaw == "active" }
        ))
        return items.map { ItemEntity(id: $0.id, displayName: $0.name) }
    }
}

// MARK: - 快速补货
struct QuickRestockIntent: AppIntent {
    static var title: LocalizedStringResource = "快速补货"
    static var description: IntentDescription = "用最近一次购买参数，为指定物品补货，并重算预测与提醒。"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "物品")
    var item: ItemEntity

    @Parameter(title: "总价", default: 0.0)
    var totalPrice: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = SharedContainer.container else {
            return .result(dialog: "数据未就绪")
        }
        let context = ModelContext(container)
        let id = item.id
        let descriptor = FetchDescriptor<LifeItem>(
            predicate: #Predicate { $0.id == id }
        )
        guard let target = try context.fetch(descriptor).first else {
            return .result(dialog: "找不到该物品")
        }

        let total = totalPrice > 0 ? totalPrice : (target.purchasePrice ?? 0)
        let eff = ForecastEngine.effectiveCost(total: total, coupon: nil, shipping: nil)
        let unitP = ForecastEngine.unitPrice(effectiveCost: eff,
                                             packageQuantity: target.packageQuantity)
        let record = PurchaseRecord(
            purchasedAt: .now,
            quantity: 1,
            packageQuantity: target.packageQuantity,
            totalPrice: total,
            unitPrice: unitP,
            effectiveCost: eff,
            sourceType: .offline
        )
        record.item = target
        target.purchasePrice = total
        target.unitPrice = unitP
        target.purchaseDate = .now
        target.updatedAt = .now

        if target.trackingMode == .consumable {
            ForecastEngine.predictRepurchaseDate(for: target)
        }
        context.insert(record)
        try context.save()
        NotificationService.shared.schedule(for: target)

        return .result(dialog: "已为「\(target.name)」补货，总价 \(String(format: "%.2f", total)) 元。")
    }
}

// MARK: - 快速新增
struct QuickAddItemIntent: AppIntent {
    static var title: LocalizedStringResource = "快速新增物品"
    static var description: IntentDescription = "用最少字段直接新增一个消耗类物品。"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "名称")
    var name: String

    @Parameter(title: "总价", default: 0.0)
    var totalPrice: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = SharedContainer.container else {
            return .result(dialog: "数据未就绪")
        }
        let context = ModelContext(container)
        let item = LifeItem(name: name, trackingMode: .consumable, category: .daily,
                            purchasePrice: totalPrice, purchaseDate: .now)
        let policy = ReminderPolicy.defaultPolicy
        policy.item = item
        item.reminderPolicy = policy
        context.insert(item)
        context.insert(policy)

        if totalPrice > 0 {
            let eff = ForecastEngine.effectiveCost(total: totalPrice, coupon: nil, shipping: nil)
            let record = PurchaseRecord(purchasedAt: .now, totalPrice: totalPrice,
                                        effectiveCost: eff, sourceType: .offline)
            record.item = item
            context.insert(record)
        }
        try context.save()
        return .result(dialog: "已新增「\(name)」，可在 App 内补全详情。")
    }
}

// MARK: - 标记已处理
struct MarkHandledIntent: AppIntent {
    static var title: LocalizedStringResource = "标记已处理"
    static var description: IntentDescription = "取消该物品的待发提醒（如已自行处理）。"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "物品")
    var item: ItemEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = SharedContainer.container else {
            return .result(dialog: "数据未就绪")
        }
        let context = ModelContext(container)
        let id = item.id
        let descriptor = FetchDescriptor<LifeItem>(predicate: #Predicate { $0.id == id })
        guard let target = try context.fetch(descriptor).first else {
            return .result(dialog: "找不到该物品")
        }
        NotificationService.shared.cancel(for: target)
        return .result(dialog: "已取消「\(target.name)」的提醒。")
    }
}

// MARK: - App Shortcuts 汇总
struct LifeStockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddItemIntent(),
            phrases: [
                "在 \(.applicationName) 新增物品",
                "用 \(.applicationName) 记一件东西"
            ],
            shortTitle: "快速新增物品",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: QuickRestockIntent(),
            phrases: ["在 \(.applicationName) 补货"],
            shortTitle: "快速补货",
            systemImageName: "cart"
        )
        AppShortcut(
            intent: MarkHandledIntent(),
            phrases: ["用 \(.applicationName) 标记已处理"],
            shortTitle: "标记已处理",
            systemImageName: "checkmark.circle"
        )
    }
}
