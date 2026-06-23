import Foundation
import SwiftData

/// 当前追踪对象主表。一个 LifeItem 代表"一件正在被管理的物品/服务"。
///
/// 设计原则：当前状态归 LifeItem，历史事实归 PurchaseRecord，
/// 把"估算"与"事实"分离，便于复购预测、价格趋势、日均成本计算。
@Model
final class LifeItem {

    // MARK: 标识与基本字段
    @Attribute(.unique) var id: UUID
    var name: String
    var trackingModeRaw: String
    var categoryRaw: String
    var statusRaw: String
    var brand: String?
    var note: String

    // MARK: 量与单位
    var unitName: String?              // 包、瓶、ml、卷
    var packageQuantity: Double?       // 包装总量（如 500 抽）
    var singleUseAmount: Double?       // 单次典型用量
    var averageDailyConsumption: Double? // 平滑后的日均消耗

    // MARK: 价格与币种
    var purchasePrice: Double?         // 最近一次总价
    var unitPrice: Double?             // 最近一次单价
    var currencyCode: String           // CNY

    // MARK: 日期
    var purchaseDate: Date?            // 最近一次购买/补货日期
    var expiryDate: Date?              // 到期日（到期类）
    var billingCycleDays: Int?         // 订阅周期天数
    var nextBillingDate: Date?         // 下次扣费日（订阅类）
    var expectedUseDays: Int?          // 模板或用户设定的预计周期
    var predictedCycleDays: Double?    // 基于历史修正后的预测周期
    var predictedDepletionDate: Date?  // 预计用完日期

    // MARK: 购买来源与提前期
    var purchaseChannelID: UUID?       // 默认购买来源
    var shippingLeadDays: Int          // 购买提前期（电商 2-3 天）

    // MARK: 耐用品折旧
    var devicePurchasePrice: Double?   // 耐用品购入价
    var residualValue: Double?         // 残值
    var usefulLifeDays: Int?           // 使用寿命

    // MARK: 多媒体
    var imageLocalPath: String?        // 原图相对路径（Application Support 下）
    var thumbnailData: Data?           // 缩略图缓存

    // MARK: 时间戳
    var createdAt: Date
    var updatedAt: Date

    // MARK: 关系
    /// 与购买历史是一对多
    @Relationship(deleteRule: .cascade, inverse: \PurchaseRecord.item)
    var purchases: [PurchaseRecord] = []

    /// 与手动修正日志是一对多
    @Relationship(deleteRule: .cascade, inverse: \UsageLog.item)
    var usageLogs: [UsageLog] = []

    /// 提醒策略一对一（可选；为 nil 时使用全局默认）
    @Relationship(deleteRule: .cascade, inverse: \ReminderPolicy.item)
    var reminderPolicy: ReminderPolicy?

    /// 模板来源（可选）
    var templateID: UUID?

    // MARK: 便捷访问（raw <-> enum）
    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .consumable }
        set { trackingModeRaw = newValue.rawValue }
    }
    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: 初始化
    init(
        id: UUID = UUID(),
        name: String,
        trackingMode: TrackingMode,
        category: ItemCategory,
        status: ItemStatus = .active,
        brand: String? = nil,
        note: String = "",
        unitName: String? = nil,
        packageQuantity: Double? = nil,
        singleUseAmount: Double? = nil,
        averageDailyConsumption: Double? = nil,
        purchasePrice: Double? = nil,
        unitPrice: Double? = nil,
        currencyCode: String = "CNY",
        purchaseDate: Date? = nil,
        expiryDate: Date? = nil,
        billingCycleDays: Int? = nil,
        nextBillingDate: Date? = nil,
        expectedUseDays: Int? = nil,
        predictedCycleDays: Double? = nil,
        predictedDepletionDate: Date? = nil,
        purchaseChannelID: UUID? = nil,
        shippingLeadDays: Int = 0,
        devicePurchasePrice: Double? = nil,
        residualValue: Double? = nil,
        usefulLifeDays: Int? = nil,
        imageLocalPath: String? = nil,
        thumbnailData: Data? = nil,
        templateID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.trackingModeRaw = trackingMode.rawValue
        self.categoryRaw = category.rawValue
        self.statusRaw = status.rawValue
        self.brand = brand
        self.note = note
        self.unitName = unitName
        self.packageQuantity = packageQuantity
        self.singleUseAmount = singleUseAmount
        self.averageDailyConsumption = averageDailyConsumption
        self.purchasePrice = purchasePrice
        self.unitPrice = unitPrice
        self.currencyCode = currencyCode
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.billingCycleDays = billingCycleDays
        self.nextBillingDate = nextBillingDate
        self.expectedUseDays = expectedUseDays
        self.predictedCycleDays = predictedCycleDays
        self.predictedDepletionDate = predictedDepletionDate
        self.purchaseChannelID = purchaseChannelID
        self.shippingLeadDays = shippingLeadDays
        self.devicePurchasePrice = devicePurchasePrice
        self.residualValue = residualValue
        self.usefulLifeDays = usefulLifeDays
        self.imageLocalPath = imageLocalPath
        self.thumbnailData = thumbnailData
        self.templateID = templateID
        self.createdAt = .now
        self.updatedAt = .now
    }
}
