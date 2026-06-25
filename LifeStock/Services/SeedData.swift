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

        // ---- 场景 1：宿舍常用品（消耗类）----
        // 纸巾：4 次历史购买，间隔 30/29/28 -> WMA(0.5,0.3,0.2)=28.7，最后购买 25 天前
        // 预测用完日 = now-25 + 28.7 ≈ now+3.7，真正进入"未来7天建议下单"。
        // 京东提前期 2 天 + 缓冲 1 天 -> 建议下单日 = now+3.7-3 ≈ now+0.7（今明天就该下单）。
        let tissue = makeItem(
            name: "清风纸巾", mode: .consumable, category: .daily,
            note: "宿舍常备，常从京东购买，需提前 2 天物流",
            purchasePrice: 18.0, unitName: "抽", packageQuantity: 500,
            expectedUseDays: 28, shippingLeadDays: 2, now: now
        )
        tissue.thumbnailData = ImageStore.demoThumbnail(symbol: "shippingbox.fill", background: .orange)
        context.insert(tissue)
        addPurchase(to: tissue, in: context, daysAgo: 112, price: 21.0, pkgQty: 500, observedLife: 30, now: now) // 单价0.042
        addPurchase(to: tissue, in: context, daysAgo: 82, price: 22.0, pkgQty: 500, observedLife: 30, now: now) // 0.044 偏贵
        addPurchase(to: tissue, in: context, daysAgo: 53, price: 20.0, pkgQty: 500, observedLife: 29, now: now) // 0.040 中位
        addPurchase(to: tissue, in: context, daysAgo: 25, price: 18.0, pkgQty: 500, observedLife: nil, now: now) // 0.036 便宜，省了

        // 沐浴露：2 次历史购买，间隔 46 天 -> WMA(0.6,0.4)=46，最后购买 40 天前
        // 预测用完日 = now-40 + 46 = now+6，进入"未来7天"。
        let showerGel = makeItem(
            name: "舒肤佳沐浴露", mode: .consumable, category: .daily,
            purchasePrice: 36, unitName: "ml", packageQuantity: 500,
            expectedUseDays: 46, now: now
        )
        showerGel.thumbnailData = ImageStore.demoThumbnail(symbol: "drop.fill", background: .teal)
        context.insert(showerGel)
        addPurchase(to: showerGel, in: context, daysAgo: 86, price: 45, pkgQty: 500, observedLife: nil, now: now) // 偏贵
        addPurchase(to: showerGel, in: context, daysAgo: 40, price: 36, pkgQty: 500, observedLife: nil, now: now) // 便宜

        // 牙膏：还远，不进7天（用于对比）。间隔≈90天，最后购买50天前 -> 还有40天
        let toothpaste = makeItem(
            name: "黑人牙膏", mode: .consumable, category: .daily,
            purchasePrice: 15, unitName: "支", packageQuantity: 1,
            expectedUseDays: 90, now: now
        )
        context.insert(toothpaste)
        addPurchase(to: toothpaste, in: context, daysAgo: 140, price: 15, pkgQty: 1, observedLife: 90, now: now)
        addPurchase(to: toothpaste, in: context, daysAgo: 50, price: 15, pkgQty: 1, observedLife: nil, now: now)

        // 洗衣液：消耗类，还远，补充场景多样性
        let detergent = makeItem(
            name: "蓝月亮洗衣液", mode: .consumable, category: .daily,
            purchasePrice: 29, unitName: "袋", packageQuantity: 1,
            expectedUseDays: 60, now: now
        )
        context.insert(detergent)
        addPurchase(to: detergent, in: context, daysAgo: 20, price: 29, pkgQty: 1, observedLife: nil, now: now)

        // ---- 场景 2：期限风险 ----
        // 牛奶：今天到期（到期类，进"今天最该处理"但不属于"建议下单"）
        let milk = makeItem(
            name: "特仑苏牛奶", mode: .expiry, category: .food,
            purchasePrice: 8, unitName: "盒", packageQuantity: 1,
            expiryDate: cal.date(byAdding: .day, value: 0, to: now),
            now: now
        )
        milk.thumbnailData = ImageStore.demoThumbnail(symbol: "cup.and.saucer.fill", background: .blue)
        context.insert(milk)
        addPurchase(to: milk, in: context, daysAgo: 5, price: 8, pkgQty: 1, observedLife: nil, now: now)

        // 药品：已过期 2 天
        let medicine = makeItem(
            name: "布洛芬", mode: .expiry, category: .medicine,
            note: "感冒备用，注意有效期",
            purchasePrice: 22, unitName: "盒", packageQuantity: 1,
            expiryDate: cal.date(byAdding: .day, value: -2, to: now),
            now: now
        )
        context.insert(medicine)
        addPurchase(to: medicine, in: context, daysAgo: 120, price: 22, pkgQty: 1, observedLife: nil, now: now)

        // 学生证：14 天后到期（需年审）
        let studentID = makeItem(
            name: "学生证（年审）", mode: .expiry, category: .document,
            note: "每学期注册章",
            purchasePrice: 0, unitName: nil, packageQuantity: nil,
            expiryDate: cal.date(byAdding: .day, value: 14, to: now),
            now: now
        )
        context.insert(studentID)

        // B站会员：5 天后续费（订阅类）
        let biliVIP = makeItem(
            name: "B站大会员", mode: .subscription, category: .subscription,
            note: "季度订阅",
            purchasePrice: 88, unitName: nil, packageQuantity: nil,
            billingCycleDays: 90,
            nextBillingDate: cal.date(byAdding: .day, value: 5, to: now),
            now: now
        )
        context.insert(biliVIP)
        addPurchase(to: biliVIP, in: context, daysAgo: 85, price: 88, pkgQty: nil, observedLife: nil, source: .subscription, now: now)

        // ---- 场景 3：价值管理 ----
        // 耳机：耐用品，折旧
        let earphone = makeItem(
            name: "AirPods Pro", mode: .durable, category: .device,
            note: "已用 180 天，按直线法折旧",
            purchasePrice: nil, unitName: nil, packageQuantity: nil,
            devicePrice: 1999, residualValue: 400, usefulLife: 730,
            purchaseDate: cal.date(byAdding: .day, value: -180, to: now),
            now: now
        )
        earphone.thumbnailData = ImageStore.demoThumbnail(symbol: "airpodspro", background: .gray)
        context.insert(earphone)

        // 鼠标：耐用品，折旧（补充价值管理场景）
        let mouse = makeItem(
            name: "罗技 M330 鼠标", mode: .durable, category: .device,
            note: "已用约 10 个月",
            purchasePrice: nil, unitName: nil, packageQuantity: nil,
            devicePrice: 129, residualValue: 20, usefulLife: 1095,
            purchaseDate: cal.date(byAdding: .day, value: -300, to: now),
            now: now
        )
        context.insert(mouse)

        // iCloud+：月度订阅（30 天周期，21 元/月）
        let cloud = makeItem(
            name: "iCloud+ 200GB", mode: .subscription, category: .subscription,
            note: "月度订阅，每月扣费",
            purchasePrice: 21, unitName: nil, packageQuantity: nil,
            billingCycleDays: 30,
            nextBillingDate: cal.date(byAdding: .day, value: 9, to: now),
            now: now
        )
        context.insert(cloud)
        addPurchase(to: cloud, in: context, daysAgo: 21, price: 21, pkgQty: nil, observedLife: nil, source: .subscription, now: now)

        // ---- 演示商家：让商家管理页有内容 ----
        let jdMerchant = Merchant(name: "京东", type: .online, leadDays: 2, deeplinkURL: "https://m.jd.com", isFavorite: true)
        let merchants = [
            Merchant(name: "学校超市", type: .campus, leadDays: 0, isFavorite: true),
            jdMerchant,
            Merchant(name: "淘宝", type: .online, leadDays: 3),
            Merchant(name: "校医院", type: .campus, leadDays: 0),
            Merchant(name: "苹果官网", type: .online, leadDays: 1, deeplinkURL: "https://www.apple.com.cn")
        ]
        for m in merchants { context.insert(m) }
        // 关联：纸巾默认从京东买（呼应提前期 2 天）
        if let jd = merchants.first(where: { $0.name == "京东" }) {
            tissue.purchaseChannelID = jd.id
        }
        try? context.save()

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
        note: String = "",
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
        now: Date
    ) -> LifeItem {
        LifeItem(
            name: name, trackingMode: mode, category: category,
            note: note,
            unitName: unitName, packageQuantity: packageQuantity,
            purchasePrice: purchasePrice,
            purchaseDate: purchaseDate ?? now,
            expiryDate: expiryDate,
            billingCycleDays: billingCycleDays,
            nextBillingDate: nextBillingDate,
            expectedUseDays: expectedUseDays,
            shippingLeadDays: shippingLeadDays,
            devicePurchasePrice: devicePrice,
            residualValue: residualValue,
            usefulLifeDays: usefulLife
        )
    }

    private static func addPurchase(
        to item: LifeItem, in context: ModelContext, daysAgo: Int, price: Double,
        pkgQty: Double?, observedLife: Int?,
        source: PurchaseSourceType = .offline,
        now: Date = .now
    ) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
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
        context.insert(record)
    }
}
