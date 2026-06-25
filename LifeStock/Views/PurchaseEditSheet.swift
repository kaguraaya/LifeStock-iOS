import SwiftUI
import SwiftData

/// 购买记录的新增/编辑表单。
///
/// 支持补录：价格、渠道、优惠、运费、实际撑了几天。
/// 这些历史修正会直接影响未来预测、日均成本、价格趋势。
struct PurchaseEditSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: LifeItem
    var record: PurchaseRecord?
    var onDone: (() -> Void)? = nil

    @State private var totalPrice: String = ""
    @State private var quantity: String = "1"
    @State private var purchasedAt: Date = .now
    @State private var coupon: String = ""
    @State private var shipping: String = ""
    @State private var lifeDaysObserved: String = ""
    @State private var note: String = ""
    @State private var showScanner = false
    @State private var scannedReceiptPath: String?

    private var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("购买") {
                    TextField("总价（元）", text: $totalPrice).keyboardType(.decimalPad)
                    Button {
                        showScanner = true
                    } label: {
                        Label("扫描小票自动填入", systemImage: "doc.text.viewfinder")
                            .foregroundStyle(AppTheme.accent)
                    }
                    TextField("数量", text: $quantity).keyboardType(.decimalPad)
                    DatePicker("购买日期", selection: $purchasedAt, displayedComponents: .date)
                }
                Section("可选") {
                    TextField("优惠（元）", text: $coupon).keyboardType(.decimalPad)
                    TextField("运费（元）", text: $shipping).keyboardType(.decimalPad)
                    TextField("实际撑了几天", text: $lifeDaysObserved).keyboardType(.numberPad)
                    TextField("备注", text: $note, axis: .vertical).lineLimit(1...3)
                }
                Section {
                    Text(previewText()).font(.subheadline).foregroundStyle(.secondary)
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle(isEditing ? "编辑记录" : "新增记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(totalPrice.isEmpty)
                        .fontWeight(.semibold)
                }
                if isEditing {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                        Button("删除", role: .destructive) {
                            delete()
                        }
                    }
                }
            }
            .onAppear { load() }
            .fullScreenCover(isPresented: $showScanner) {
                ReceiptScannerView { amount, path in
                    totalPrice = String(format: "%.2f", amount)
                    scannedReceiptPath = path
                }
            }
        }
    }

    private func load() {
        guard let r = record else { return }
        totalPrice = String(r.totalPrice)
        quantity = String(r.quantity)
        purchasedAt = r.purchasedAt
        coupon = r.couponAmount.map { String($0) } ?? ""
        shipping = r.shippingFee.map { String($0) } ?? ""
        lifeDaysObserved = r.lifeDaysObserved.map { String($0) } ?? ""
        note = r.note ?? ""
        scannedReceiptPath = r.receiptImagePath   // 回填：编辑时保留已绑定的小票
    }

    private func previewText() -> String {
        guard let total = Double(totalPrice) else { return "请输入总价" }
        let eff = ForecastEngine.effectiveCost(total: total,
                                               coupon: Double(coupon),
                                               shipping: Double(shipping))
        var parts = ["实际成本 \(String(format: "%.2f", eff)) 元"]
        if let pkg = item.packageQuantity, pkg > 0 {
            let unit = item.unitName ?? "单位"
            parts.append("单价 \(String(format: "%.3f", eff / pkg)) 元/\(unit)")
        }
        return parts.joined(separator: " · ")
    }

    private func save() {
        guard let total = Double(totalPrice) else { return }
        let q = Double(quantity) ?? 1
        let eff = ForecastEngine.effectiveCost(total: total,
                                               coupon: Double(coupon),
                                               shipping: Double(shipping))
        let unitP = ForecastEngine.unitPrice(effectiveCost: eff, packageQuantity: item.packageQuantity)

        if let r = record {
            r.totalPrice = total
            r.quantity = q
            r.purchasedAt = purchasedAt
            r.couponAmount = Double(coupon)
            r.shippingFee = Double(shipping)
            r.effectiveCost = eff
            r.unitPrice = unitP
            r.lifeDaysObserved = Int(lifeDaysObserved)
            r.note = note.isEmpty ? nil : note
            if let scanned = scannedReceiptPath { r.receiptImagePath = scanned }
        } else {
            let r = PurchaseRecord(
                purchasedAt: purchasedAt,
                quantity: q,
                packageQuantity: item.packageQuantity,
                totalPrice: total,
                unitPrice: unitP,
                couponAmount: Double(coupon),
                shippingFee: Double(shipping),
                effectiveCost: eff,
                lifeDaysObserved: Int(lifeDaysObserved),
                sourceType: .offline,
                note: note.isEmpty ? nil : note,
                receiptImagePath: scannedReceiptPath
            )
            r.item = item
            item.purchases.append(r)
            context.insert(r)
        }
        item.updatedAt = .now
        if item.trackingMode == .consumable {
            ForecastEngine.predictRepurchaseDate(for: item)
        }
        try? context.save()
        SummaryRefresh.refresh(context: context)
        onDone?()
        dismiss()
    }

    private func delete() {
        guard let r = record else { return }
        if let idx = item.purchases.firstIndex(where: { $0.id == r.id }) {
            item.purchases.remove(at: idx)
        }
        context.delete(r)
        if let path = r.receiptImagePath { ImageStore.remove(relativePath: path) }
        item.updatedAt = .now
        if item.trackingMode == .consumable {
            ForecastEngine.predictRepurchaseDate(for: item)
        }
        try? context.save()
        SummaryRefresh.refresh(context: context)
        onDone?()
        dismiss()
    }
}
