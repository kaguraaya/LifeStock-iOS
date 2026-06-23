import Foundation
import SwiftData

/// 演示数据与内置模板的播种器。
///
/// 设计原则：演示数据必须"一键生效"，覆盖三套场景：
/// 1. 宿舍常用品（纸巾、牙膏、沐浴露、洗衣液）
/// 2. 期限风险（牛奶、药品、学生证、会员续费）
/// 3. 价值管理（耳机、鼠标、云盘订阅）
enum SeedData {

    /// 是否已经播种过演示数据（用 UserDefaults 标记，避免重复）
    static let demoSeededKey = "lifestock.demoSeeded.v1"

    static func hasSeeded() -> Bool {
        UserDefaults.standard.bool(forKey: demoSeededKey)
    }

    static func markSeeded() {
        UserDefaults.standard.set(true, forKey: demoSeededKey)
    }

    static func markUnseeded() {
        UserDefaults.standard.set(false, forKey: demoSeededKey)
    }

    // MARK: 内置模板
    static func seedBuiltInTemplates(context: ModelContext) {
        let descriptor = FetchDescriptor<ItemTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for t in builtInTemplates() {
            context.insert(t)
        }
        try? context.save()
    }

    /// 7 个内置模板（对应报告 UX 流程的模板网格）
    static func builtInTemplates() -> [ItemTemplate] {
        [
            ItemTemplate(name: "纸巾", defaultCategory: .daily, defaultTrackingMode: .consumable,
                         defaultUseDays: 27, defaultPackageQuantity: 500, defaultUnitName: "抽",
                         defaultPriceLow: 15, defaultPriceHigh: 25, defaultUnitPrice: 0.04,
                         defaultMerchantName: "学校超市", symbol: "shippingbox", isBuiltIn: true),

            ItemTemplate(name: "牙膏", defaultCategory: .daily, defaultTrackingMode: .consumable,
                         defaultUseDays: 90, defaultPackageQuantity: 1, defaultUnitName: "支",
                         defaultPriceLow: 12, defaultPriceHigh: 30,
                         defaultMerchantName: "学校超市", symbol: "drop.fill", isBuiltIn: true),

            ItemTemplate(name: "沐浴露", defaultCategory: .daily, defaultTrackingMode: .consumable,
                         defaultUseDays: 45, defaultPackageQuantity: 500, defaultUnitName: "ml",
                         defaultPriceLow: 25, defaultPriceHigh: 45, defaultUnitPrice: 0.07,
                         defaultMerchantName: "学校超市", symbol: "drop.degreesign", isBuiltIn: true),

            ItemTemplate(name: "洗衣液", defaultCategory: .daily, defaultTrackingMode: .consumable,
                         defaultUseDays: 60, defaultPackageQuantity: 2, defaultUnitName: "kg",
                         defaultPriceLow: 20, defaultPriceHigh: 40,
                         defaultMerchantName: "淘宝", symbol: "washer", isBuiltIn: true),

            ItemTemplate(name: "牛奶", defaultCategory: .food, defaultTrackingMode: .expiry,
                         defaultUseDays: nil, defaultPackageQuantity: 1, defaultUnitName: "盒",
                         defaultPriceLow: 5, defaultPriceHigh: 12,
                         defaultMerchantName: "学校超市", symbol: "cup.and.saucer.fill", isBuiltIn: true),

            ItemTemplate(name: "药品", defaultCategory: .medicine, defaultTrackingMode: .expiry,
                         defaultUseDays: nil, defaultPackageQuantity: 1, defaultUnitName: "盒",
                         defaultPriceLow: 10, defaultPriceHigh: 60,
                         defaultMerchantName: "校医院", symbol: "cross.case.fill", isBuiltIn: true),

            ItemTemplate(name: "云盘/会员订阅", defaultCategory: .subscription, defaultTrackingMode: .subscription,
                         defaultUseDays: nil, defaultPackageQuantity: nil, defaultUnitName: nil,
                         defaultPriceLow: 98, defaultPriceHigh: 298,
                         defaultMerchantName: "官方", symbol: "icloud.fill", isBuiltIn: true),
        ]
    }

    // MARK: 演示数据
    /// 写入完整演示场景。调用前应清空现有数据。
    static func seedDemoData(context: ModelContext, now: Date = .now) {
        let cal = Calendar.current

        // ---- 场景 1：宿舍常用品 ----
        // 纸巾：3 次历史购买，间隔 30/28/26 -> WMA ≈ 27.4，预测 3 天后用完
        let tissue = makeItem(
            name: "清风纸巾", mode: .consumable, category: .daily,
            purchasePrice: 19.9, unitName: "抽", packageQuantity: 500,
            expectedUseDays: 27, shippingLeadDays: 2, now: now,
            note: "宿舍常备，网购需提前 2 天"
        )
        addPurchase(to: tissue, daysAgo: 60, price: 21.0, pkgQty: 500, observedLife: 30)
        addPurchase(to: tissue, daysAgo: 32, price: 19.5, pkgQty: 500, observedLife: 28)
        addPurchase(to: tissue, daysAgo: 4,  price: 19.9, pkgQty: 500, observedLife: nil) // 最新一次还没观测完
        context.insert(tissue)

        // 沐浴露：预计 6 天后用完
        let showerGel = makeItem(
            name: "舒肤佳沐浴露", mode: .consumable, category: .daily,
            purchasePrice: 39, unitName: "ml", packageQuantity: 500,
            expectedUseDays: 45, now: now
        )
        addPurchase(to: showerGel, daysAgo: 40, price: 39, pkgQty: 500, observedLife: nil)
        context.insert(showerGel)

        // 牙膏：还有 20 天
        let toothpaste = makeItem(
            name: "黑人牙膏", mode: .consumable, category: .daily,
            purchasePrice: 15, unitName: "支", packageQuantity: 1,
            expectedUseDays: 90, now: now
        )
        addPurchase(to: toothpaste, daysAgo: 70, price: 15, pkgQty: 1, observedLife: nil)
        context.insert(toothpaste)

        // ---- 场景 2：期限风险 ----
        // 牛奶：今天到期
        let milk = makeItem(
            name: "特仑苏牛奶", mode: .expiry, category: .food,
            purchasePrice: 8, unitName: "盒", packageQuantity: 1,
            expiryDate: cal.date(byAdding: .day, value: 0, to: now),
            now: now
        )
        addPurchase(to: milk, daysAgo: 5, price: 8, pkgQty: 1, observedLife: nil)
        context.insert(milk)

        // 药品：已过期 2 天
        let medicine = makeItem(
            name: "布洛芬", mode: .expiry, category: .medicine,
            purchasePrice: 22, unitName: "盒", packageQuantity: 1,
            expiryDate: cal.date(byAdding: .day, value: -2, to: now),
            now: now, note: "感冒备用，注意有效期"
        )
        addPurchase(to: medicine, daysAgo: 120, price: 22, pkgQty: 1, observedLife: nil)
        context.insert(medicine)

        // 学生证：14 天后到期（需年审）
        let studentID = makeItem(
            name: "学生证（年审）", mode: .expiry, category: .document,
            purchasePrice: 0, unitName: nil, packageQuantity: nil,
            expiryDate: cal.date(byAdding: .day, value: 14, to: now),
            now: now, note: "每学期注册章"
        )
        context.insert(studentID)

        // B站会员：5 天后续费
        let biliVIP = makeItem(
            name: "B站大会员", mode: .subscription, category: .subscription,
            purchasePrice: 88, unitName: nil, packageQuantity: nil,
            billingCycleDays: 90,
            nextBillingDate: cal.date(byAdding: .day, value: 5, to: now),
            now: now, note: "季度订阅"
        )
        addPurchase(to: biliVIP, daysAgo: 85, price: 88, pkgQty: nil, observedLife: nil, source: .subscription)
        context.insert(biliVIP)

        // ---- 场景 3：价值管理 ----
        // 耳机：耐用品，折旧
        let earphone = makeItem(
            name: "AirPods Pro", mode: .durable, category: .device,
            purchasePrice: nil, devicePrice: 1999, residualValue: 400, usefulLife: 730,
            purchaseDate: cal.date(byAdding: .day, value: -180, to: now),
            now: now, note: "已用 180 天，按直线法折旧"
        )
        context.insert(earphone)

        // 云盘订阅：年度
        let cloud = makeItem(
            name: "iCloud+ 200GB", mode: .subscription, category: .subscription,
            purchasePrice: 21, unitName: nil, packageQuantity: nil,
            billingCycleDays: 30,
            nextBillingDate: cal.date(byAdding: .day, value: 9, to: now),
            now: now, note: "每月扣费"
        )
        addPurchase(to: cloud, daysAgo: 21, price: 21, pkgQty: nil, observedLife: nil, source: .subscription)
        context.insert(cloud)

        // 给所有物品附加默认提醒策略
        let allItems = (try? context.fetch(FetchDescriptor<LifeItem>())) ?? []
        for item in allItems where item.reminderPolicy == nil {
            let policy = ReminderPolicy.defaultPolicy
            policy.item = item
            item.reminderPolicy = policy
            context.insert(policy)
        }

        // 重算消耗类预测
        for item in allItems where item.trackingMode == .consumable {
            ForecastEngine.predictRepurchaseDate(for: item, today: now)
        }

        try? context.save()
        markSeeded()
    }

    // MARK: 辅助
    private static func makeItem(
        name: String, mode: TrackingMode, category: ItemCategory,
        purchasePrice: Double?, unitName: String?, packageQuantity: Double?,
        expectedUseDays: Int? = nil,
        expiryDate: Date? = nil,
        billingCycleDays: Int? = nil,
        nextBillingDate: Date? = nil,
        devicePrice: Double? = nil,
        residualValue: Double? = nil,
        usefulLife: Int? = nil,
        purchaseDate: Date? = nil,
        shippingLeadDays: Int = 0,
        now: Date, note: String = ""
    ) -> LifeItem {
        LifeItem(
            name: name, trackingMode: mode, category: category,
            purchasePrice: purchasePrice,
            unitName: unitName, packageQuantity: packageQuantity,
            expectedUseDays: expectedUseDays,
            expiryDate: expiryDate,
            billingCycleDays: billingCycleDays,
            nextBillingDate: nextBillingDate,
            devicePurchasePrice: devicePrice,
            residualValue: residualValue,
            usefulLifeDays: usefulLife,
            purchaseDate: purchaseDate ?? now,
            shippingLeadDays: shippingLeadDays,
            note: note
        )
    }

    private static func addPurchase(
        to item: LifeItem, daysAgo: Int, price: Double,
        pkgQty: Double?, observedLife: Int?,
        source: PurchaseSourceType = .offline
    ) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let eff = ForecastEngine.effectiveCost(total: price, coupon: nil, shipping: nil)
        let unitP = ForecastEngine.unitPrice(effectiveCost: eff, packageQuantity: pkgQty)
        let record = PurchaseRecord(
            purchasedAt: date,
            quantity: 1,
            packageQuantity: pkgQty,
            totalPrice: price,
            unitPrice: unitP,
            effectiveCost: eff,
            lifeDaysObserved: observedLife,
            sourceType: source
        )
        record.item = item
        item.purchases.append(record)
    }
}
