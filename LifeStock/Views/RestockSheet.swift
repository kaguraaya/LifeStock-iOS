import SwiftUI
import SwiftData

/// 补货表单：One-Tap 主动作。
///
/// 默认值来自最近一次购买记录（"沿用上次参数"）。
/// 保存后：新建 PurchaseRecord + 更新 purchaseDate + 重算预测 + 重排通知。
struct RestockSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: LifeItem
    var onDone: (() -> Void)? = nil

    @State private var totalPrice: String = ""
    @State private var quantity: String = "1"
    @State private var purchaseDate: Date = .now
    @State private var coupon: String = ""
    @State private var shipping: String = ""
    @State private var useLastValues: Bool = true

    private var lastRecord: PurchaseRecord? {
        item.purchases.sorted { $0.purchasedAt > $1.purchasedAt }.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("补货信息") {
                    Toggle("沿用上次参数", isOn: $useLastValues)
                        .onChange(of: useLastValues) { _, newValue in
                            if newValue { applyLastValues() }
                        }
                    TextField("总价（元）", text: $totalPrice)
                        .keyboardType(.decimalPad)
                    TextField("数量", text: $quantity)
                        .keyboardType(.decimalPad)
                    DatePicker("购买日期", selection: $purchaseDate, displayedComponents: .date)
                }

                Section("可选") {
                    TextField("优惠（元）", text: $coupon).keyboardType(.decimalPad)
                    TextField("运费（元）", text: $shipping).keyboardType(.decimalPad)
                }

                Section {
                    Text(previewText())
                        .font(.subheadline).foregroundStyle(.secondary)
                } header: {
                    Text("实付与单价预览")
                }
            }
            .navigationTitle("我已补货 · \(item.name)")
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
            }
            .onAppear {
                if useLastValues { applyLastValues() }
            }
        }
    }

    private func applyLastValues() {
        if let last = lastRecord {
            totalPrice = String(last.totalPrice)
            quantity = String(last.quantity)
            coupon = last.couponAmount.map { String($0) } ?? ""
            shipping = last.shippingFee.map { String($0) } ?? ""
        }
    }

    private func previewText() -> String {
        guard let total = Double(totalPrice) else { return "请输入总价" }
        let couponV = Double(coupon) ?? 0
        let shippingV = Double(shipping) ?? 0
        let eff = ForecastEngine.effectiveCost(total: total, coupon: couponV, shipping: shippingV)
        var parts = ["实际成本 \(String(format: "%.2f", eff)) 元"]
        if let pkg = item.packageQuantity, pkg > 0 {
            let unit = item.unitName ?? "单位"
            let unitP = eff / pkg
            parts.append("单价 \(String(format: "%.3f", unitP)) 元/\(unit)")
        }
        return parts.joined(separator: " · ")
    }

    private func save() {
        guard let total = Double(totalPrice) else { return }
        let q = Double(quantity) ?? 1
        let couponV = Double(coupon)
        let shippingV = Double(shipping)
        let eff = ForecastEngine.effectiveCost(total: total, coupon: couponV, shipping: shippingV)
        let unitP = ForecastEngine.unitPrice(effectiveCost: eff, packageQuantity: item.packageQuantity)

        let record = PurchaseRecord(
            purchasedAt: purchaseDate,
            quantity: q,
            packageQuantity: item.packageQuantity,
            totalPrice: total,
            unitPrice: unitP,
            couponAmount: couponV,
            shippingFee: shippingV,
            effectiveCost: eff,
            sourceType: .offline
        )
        record.item = item
        item.purchases.append(record)
        item.purchasePrice = total
        item.unitPrice = unitP
        item.purchaseDate = purchaseDate
        item.updatedAt = .now

        if item.trackingMode == .consumable {
            ForecastEngine.predictRepurchaseDate(for: item)
        }

        context.insert(record)
        try? context.save()
        NotificationService.shared.schedule(for: item)
        SummaryRefresh.refresh(context: context)

        onDone?()
        dismiss()
    }
}
