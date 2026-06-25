import Foundation
import SwiftData
import SwiftUI

/// 数据导出与清理服务。
///
/// - JSON：完整备份（模型 + 关系快照）
/// - CSV：购买记录 / 支出统计，便于课上展示与 Excel 验证
/// - 一键清理：删除全部数据 / 仅清理图片缓存
enum ExportService {

    // MARK: - JSON 备份
    /// 导出为 JSON Data
    static func exportJSON(context: ModelContext) throws -> Data {
        let items = try context.fetch(FetchDescriptor<LifeItem>())
        let snapshots = items.map { ItemExport.from($0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(ExportPayload(items: snapshots,
                                                exportedAt: .now,
                                                appVersion: appVersion()))
    }

    /// 写入临时文件，返回 URL（用于 ShareLink / fileExporter）
    static func writeJSONFile(context: ModelContext) throws -> URL {
        let data = try exportJSON(context: context)
        return try writeTemp(data: data, filename: "LifeStock-backup-\(timestamp()).json")
    }

    // MARK: - CSV（购买记录）
    static func exportPurchaseCSV(context: ModelContext) throws -> URL {
        let items = try context.fetch(FetchDescriptor<LifeItem>())
        var rows: [String] = []
        rows.append("日期,物品名称,模式,分类,数量,包装量,总价,优惠,运费,实际成本,单价,实际天数,来源,备注")
        for item in items {
            for r in item.purchases.sorted(by: { $0.purchasedAt < $1.purchasedAt }) {
                let cols = [
                    csv(RelativeDateText.short(r.purchasedAt)),
                    csv(item.name),
                    item.trackingMode.displayName,
                    item.category.displayName,
                    String(r.quantity),
                    r.packageQuantity.map { String($0) } ?? "",
                    String(r.totalPrice),
                    r.couponAmount.map { String($0) } ?? "",
                    r.shippingFee.map { String($0) } ?? "",
                    String(r.effectiveCost ?? r.totalPrice),
                    r.unitPrice.map { String(format: "%.4f", $0) } ?? "",
                    r.lifeDaysObserved.map { String($0) } ?? "",
                    r.sourceType.rawValue,
                    csv(r.note ?? "")
                ]
                rows.append(cols.joined(separator: ","))
            }
        }
        let csvText = "\u{FEFF}" + rows.joined(separator: "\n")  // BOM 兼容 Excel 中文
        let data = Data(csvText.utf8)
        return try writeTemp(data: data, filename: "LifeStock-purchases-\(timestamp()).csv")
    }

    // MARK: - 清理
    /// 删除所有数据（物品、记录、模板、商家、日志、策略）+ 所有小票图与物品图
    @MainActor
    static func clearAllData(context: ModelContext) throws {
        // 先批量删小票图，避免模型删除后丢失路径引用
        let purchases = try context.fetch(FetchDescriptor<PurchaseRecord>())
        for r in purchases { ImageStore.remove(relativePath: r.receiptImagePath) }
        let items = try context.fetch(FetchDescriptor<LifeItem>())
        for item in items { ImageStore.remove(relativePath: item.imageLocalPath) }

        try context.delete(model: PurchaseRecord.self)
        try context.delete(model: UsageLog.self)
        try context.delete(model: ReminderPolicy.self)
        try context.delete(model: LifeItem.self)
        // 保留内置模板
        let builtIn = try context.fetch(FetchDescriptor<ItemTemplate>(
            predicate: #Predicate { $0.isBuiltIn == false }
        ))
        for t in builtIn { context.delete(t) }
        let merchants = try context.fetch(FetchDescriptor<Merchant.self>())
        for m in merchants { context.delete(m) }
        try context.save()
        SeedData.markUnseeded()
    }

    /// 仅清理图片缓存（原图 + 缩略图），保留所有结构化数据
    @MainActor
    static func clearImageCache(context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<LifeItem>())
        for item in items {
            if let path = item.imageLocalPath {
                let url = imageDirectory().appendingPathComponent(path)
                try? FileManager.default.removeItem(at: url)
            }
            item.imageLocalPath = nil
            item.thumbnailData = nil
        }
        try context.save()
    }

    // MARK: - 辅助
    private static func csv(_ s: String) -> String {
        // 含逗号/换行/引号的字段需要加引号转义
        if s.contains(",") || s.contains("\n") || s.contains("\"") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func writeTemp(data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: .now)
    }

    static func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "LifeStock \(v)"
    }

    static func imageDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("LifeStockImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

// MARK: - 导出数据结构
private struct ExportPayload: Codable {
    let items: [ItemExport]
    let exportedAt: Date
    let appVersion: String
}

struct ItemExport: Codable {
    let id: UUID
    let name: String
    let brand: String?
    let trackingMode: String
    let category: String
    let status: String
    let unitName: String?
    let packageQuantity: Double?
    let purchasePrice: Double?
    let unitPrice: Double?
    let currencyCode: String
    let purchaseDate: Date?
    let expiryDate: Date?
    let nextBillingDate: Date?
    let billingCycleDays: Int?
    let predictedCycleDays: Double?
    let predictedDepletionDate: Date?
    let shippingLeadDays: Int
    let devicePurchasePrice: Double?
    let residualValue: Double?
    let usefulLifeDays: Int?
    let note: String
    let purchases: [PurchaseExport]

    static func from(_ item: LifeItem) -> ItemExport {
        ItemExport(
            id: item.id,
            name: item.name,
            brand: item.brand,
            trackingMode: item.trackingModeRaw,
            category: item.categoryRaw,
            status: item.statusRaw,
            unitName: item.unitName,
            packageQuantity: item.packageQuantity,
            purchasePrice: item.purchasePrice,
            unitPrice: item.unitPrice,
            currencyCode: item.currencyCode,
            purchaseDate: item.purchaseDate,
            expiryDate: item.expiryDate,
            nextBillingDate: item.nextBillingDate,
            billingCycleDays: item.billingCycleDays,
            predictedCycleDays: item.predictedCycleDays,
            predictedDepletionDate: item.predictedDepletionDate,
            shippingLeadDays: item.shippingLeadDays,
            devicePurchasePrice: item.devicePurchasePrice,
            residualValue: item.residualValue,
            usefulLifeDays: item.usefulLifeDays,
            note: item.note,
            purchases: item.purchases.map(PurchaseExport.from)
        )
    }
}

struct PurchaseExport: Codable {
    let id: UUID
    let purchasedAt: Date
    let quantity: Double
    let packageQuantity: Double?
    let totalPrice: Double
    let unitPrice: Double?
    let couponAmount: Double?
    let shippingFee: Double?
    let effectiveCost: Double?
    let lifeDaysObserved: Int?
    let sourceType: String
    let note: String?

    static func from(_ r: PurchaseRecord) -> PurchaseExport {
        PurchaseExport(
            id: r.id,
            purchasedAt: r.purchasedAt,
            quantity: r.quantity,
            packageQuantity: r.packageQuantity,
            totalPrice: r.totalPrice,
            unitPrice: r.unitPrice,
            couponAmount: r.couponAmount,
            shippingFee: r.shippingFee,
            effectiveCost: r.effectiveCost,
            lifeDaysObserved: r.lifeDaysObserved,
            sourceType: r.sourceTypeRaw,
            note: r.note
        )
    }
}
