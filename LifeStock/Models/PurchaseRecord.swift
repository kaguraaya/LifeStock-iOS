import Foundation
import SwiftData

/// 每次购买/续费/补货的历史记录。
///
/// 这是"事实层"——价格、渠道、实际撑了几天都落在这里，
/// 而非 LifeItem 本身。预测算法从这里取数。
@Model
final class PurchaseRecord {

    @Attribute(.unique) var id: UUID
    var purchasedAt: Date
    var quantity: Double              // 买了多少单位（如 1 包）
    var packageQuantity: Double?      // 每单位包装量（如 500 抽）
    var totalPrice: Double
    var unitPrice: Double?
    var couponAmount: Double?
    var shippingFee: Double?
    var effectiveCost: Double?        // 实际成本 = 总价 - 优惠 + 运费
    var lifeDaysObserved: Int?        // 这一批实际撑了几天（事后补录）
    var sourceTypeRaw: String
    var orderReference: String?
    var note: String?
    var receiptImagePath: String?
    var merchantID: UUID?
    var createdAt: Date

    /// 反向关系：所属物品
    var item: LifeItem?

    var sourceType: PurchaseSourceType {
        get { PurchaseSourceType(rawValue: sourceTypeRaw) ?? .offline }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        purchasedAt: Date,
        quantity: Double = 1,
        packageQuantity: Double? = nil,
        totalPrice: Double,
        unitPrice: Double? = nil,
        couponAmount: Double? = nil,
        shippingFee: Double? = nil,
        effectiveCost: Double? = nil,
        lifeDaysObserved: Int? = nil,
        sourceType: PurchaseSourceType = .offline,
        orderReference: String? = nil,
        note: String? = nil,
        receiptImagePath: String? = nil,
        merchantID: UUID? = nil
    ) {
        self.id = id
        self.purchasedAt = purchasedAt
        self.quantity = quantity
        self.packageQuantity = packageQuantity
        self.totalPrice = totalPrice
        self.unitPrice = unitPrice
        self.couponAmount = couponAmount
        self.shippingFee = shippingFee
        self.effectiveCost = effectiveCost
        self.lifeDaysObserved = lifeDaysObserved
        self.sourceTypeRaw = sourceType.rawValue
        self.orderReference = orderReference
        self.note = note
        self.receiptImagePath = receiptImagePath
        self.merchantID = merchantID
        self.createdAt = .now
    }
}
