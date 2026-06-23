import Foundation
import SwiftData

/// 手动修正消耗/库存状态的日志。
/// 例："今天还剩半瓶""快没了"，用于在没有可量化库存时辅助修正预测。
@Model
final class UsageLog {

    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var remainingRatio: Double?   // 0...1，"还剩半瓶" = 0.5
    var note: String?

    /// 反向关系
    var item: LifeItem?

    init(
        id: UUID = UUID(),
        loggedAt: Date = .now,
        remainingRatio: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.remainingRatio = remainingRatio
        self.note = note
    }
}

/// 商家/购买来源。一个 Merchant 可对应多条购买记录。
@Model
final class Merchant {

    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var leadDays: Int               // 从决定购买到拿到手的天数
    var deeplinkURL: String?
    var isFavorite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: MerchantType = .offline,
        leadDays: Int = 0,
        deeplinkURL: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.leadDays = leadDays
        self.deeplinkURL = deeplinkURL
        self.isFavorite = isFavorite
        self.createdAt = .now
    }

    var type: MerchantType {
        get { MerchantType(rawValue: typeRaw) ?? .offline }
        set { typeRaw = newValue.rawValue }
    }
}

/// 常用品模板，用于快速新增时智能填充默认值。
@Model
final class ItemTemplate {

    @Attribute(.unique) var id: UUID
    var name: String
    var defaultCategoryRaw: String
    var defaultTrackingModeRaw: String
    var defaultUseDays: Int?
    var defaultPackageQuantity: Double?
    var defaultUnitName: String?
    var defaultPriceLow: Double?
    var defaultPriceHigh: Double?
    var defaultUnitPrice: Double?
    var defaultMerchantName: String?
    var symbol: String
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        defaultCategory: ItemCategory = .daily,
        defaultTrackingMode: TrackingMode = .consumable,
        defaultUseDays: Int? = nil,
        defaultPackageQuantity: Double? = nil,
        defaultUnitName: String? = nil,
        defaultPriceLow: Double? = nil,
        defaultPriceHigh: Double? = nil,
        defaultUnitPrice: Double? = nil,
        defaultMerchantName: String? = nil,
        symbol: String = "shippingbox",
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.defaultCategoryRaw = defaultCategory.rawValue
        self.defaultTrackingModeRaw = defaultTrackingMode.rawValue
        self.defaultUseDays = defaultUseDays
        self.defaultPackageQuantity = defaultPackageQuantity
        self.defaultUnitName = defaultUnitName
        self.defaultPriceLow = defaultPriceLow
        self.defaultPriceHigh = defaultPriceHigh
        self.defaultUnitPrice = defaultUnitPrice
        self.defaultMerchantName = defaultMerchantName
        self.symbol = symbol
        self.isBuiltIn = isBuiltIn
    }

    var defaultCategory: ItemCategory {
        get { ItemCategory(rawValue: defaultCategoryRaw) ?? .daily }
        set { defaultCategoryRaw = newValue.rawValue }
    }
    var defaultTrackingMode: TrackingMode {
        get { TrackingMode(rawValue: defaultTrackingModeRaw) ?? .consumable }
        set { defaultTrackingModeRaw = newValue.rawValue }
    }

    /// 模板的价格区间文案，如 "25–45 元"
    var priceRangeText: String? {
        guard let low = defaultPriceLow, let high = defaultPriceHigh else { return nil }
        return String(format: "%.0f–%.0f 元", low, high)
    }
}

/// 提醒规则。每个物品可有一份，为空时回退到全局默认。
@Model
final class ReminderPolicy {

    @Attribute(.unique) var id: UUID
    var remindBeforeDays: Int        // 提前提醒天数
    var bufferDays: Int              // 额外安全缓冲天数
    var snoozeHours: Int             // 稍后提醒时长
    var repeatSuppressionHours: Int  // 重复打扰抑制窗
    var isEnabled: Bool

    /// 反向关系：所属物品（一对一）
    var item: LifeItem?

    init(
        id: UUID = UUID(),
        remindBeforeDays: Int = 1,
        bufferDays: Int = 1,
        snoozeHours: Int = 8,
        repeatSuppressionHours: Int = 24,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.remindBeforeDays = remindBeforeDays
        self.bufferDays = bufferDays
        self.snoozeHours = snoozeHours
        self.repeatSuppressionHours = repeatSuppressionHours
        self.isEnabled = isEnabled
    }

    /// 全局默认策略，新建物品时复制一份
    static var defaultPolicy: ReminderPolicy {
        ReminderPolicy(remindBeforeDays: 1, bufferDays: 1, snoozeHours: 8)
    }
}
