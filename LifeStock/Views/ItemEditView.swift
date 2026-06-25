import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// 物品完整新增/编辑表单。
///
/// 涵盖：基础、模式相关字段、价格、提醒策略、备注。
/// 编辑模式下传入已存在 item；新增模式下由 sheet 接管保存。
struct ItemEditView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// 已存在物品（编辑模式）；新增时为 nil
    var item: LifeItem?
    var onSave: (() -> Void)? = nil

    // 表单状态
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var trackingMode: TrackingMode = .consumable
    @State private var category: ItemCategory = .daily
    @State private var status: ItemStatus = .active

    @State private var unitName: String = ""
    @State private var packageQuantity: String = ""
    @State private var expectedUseDays: String = ""

    @State private var purchasePrice: String = ""
    @State private var purchaseDate: Date = .now
    @State private var hasPurchaseDate: Bool = false

    @State private var expiryDate: Date = .now
    @State private var hasExpiryDate: Bool = false

    @State private var billingCycleDays: String = ""
    @State private var nextBillingDate: Date = .now
    @State private var hasNextBilling: Bool = false

    @State private var devicePrice: String = ""
    @State private var residualValue: String = ""
    @State private var usefulLifeDays: String = ""

    @State private var shippingLeadDays: Int = 0
    @State private var note: String = ""

    @State private var remindBeforeDays: Int = 1
    @State private var bufferDays: Int = 1
    @State private var reminderEnabled: Bool = true

    @State private var firstPurchaseTotal: String = ""   // 新建时同时记录首条购买

    // 图片
    @State private var photoItem: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var pendingThumbnail: Data?
    @State private var pendingPath: String?
    @State private var existingThumbnail: Data?

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                basicSection
                modeSpecificSection
                priceSection
                reminderSection
                noteSection
            }
            .navigationTitle(isEditing ? "编辑物品" : "新建物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
            .onChange(of: photoItem) { _, newItem in
                handlePickedPhoto(newItem)
            }
        }
    }

    // MARK: - 图片
    private var imageSection: some View {
        Section("图片（可选）") {
            HStack(spacing: 16) {
                // 预览：优先新选的图，其次已有缩略图
                if let preview = previewImage {
                    preview
                        .resizable().scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let data = existingThumbnail, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable().scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.tertiary)
                            .frame(width: 72, height: 72)
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(previewImage == nil && existingThumbnail == nil ? "添加图片" : "更换图片",
                              systemImage: "photo.badge.plus")
                    }
                    if previewImage != nil || existingThumbnail != nil {
                        Button(role: .destructive) {
                            removeImage()
                        } label: {
                            Label("移除图片", systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data?) = result, let uiImage = UIImage(data: data) {
                let saved = ImageStore.save(image: uiImage)
                DispatchQueue.main.async {
                    self.pendingPath = saved?.relativePath
                    self.pendingThumbnail = saved?.thumbnail
                    self.previewImage = Image(uiImage: uiImage)
                }
            }
        }
    }

    private func removeImage() {
        previewImage = nil
        pendingPath = nil
        pendingThumbnail = nil
        existingThumbnail = nil
        photoItem = nil
    }
    private var basicSection: some View {
        Section("基础") {
            TextField("名称（如：清风纸巾）", text: $name)
            TextField("品牌（可选）", text: $brand)

            Picker("追踪模式", selection: $trackingMode) {
                ForEach(TrackingMode.allCases) { m in
                    Label(m.displayName, systemImage: m.symbol).tag(m)
                }
            }

            Picker("分类", selection: $category) {
                ForEach(ItemCategory.allCases) { c in
                    Label(c.displayName, systemImage: c.symbol).tag(c)
                }
            }

            if isEditing {
                Picker("状态", selection: $status) {
                    ForEach(ItemStatus.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            }
        }
    }

    // MARK: - 模式相关
    private var modeSpecificSection: some View {
        Section("计量与周期") {
            TextField("单位（如：抽、ml、支）", text: $unitName)
            TextField("包装量（如：500）", text: $packageQuantity)
                .keyboardType(.decimalPad)

            if trackingMode == .consumable {
                TextField("预计使用周期（天）", text: $expectedUseDays)
                    .keyboardType(.numberPad)
            }

            if trackingMode == .expiry {
                Toggle("设置到期日", isOn: $hasExpiryDate)
                if hasExpiryDate {
                    DatePicker("到期日", selection: $expiryDate, displayedComponents: .date)
                }
            }

            if trackingMode == .subscription {
                TextField("订阅周期（天，如 30/365）", text: $billingCycleDays)
                    .keyboardType(.numberPad)
                Toggle("设置下次扣费日", isOn: $hasNextBilling)
                if hasNextBilling {
                    DatePicker("下次扣费日", selection: $nextBillingDate, displayedComponents: .date)
                }
            }

            if trackingMode == .durable {
                TextField("购入价（元）", text: $devicePrice)
                    .keyboardType(.decimalPad)
                TextField("残值（元）", text: $residualValue)
                    .keyboardType(.decimalPad)
                TextField("使用寿命（天）", text: $usefulLifeDays)
                    .keyboardType(.numberPad)
            }
        }
    }

    // MARK: - 价格
    private var priceSection: some View {
        Section("最近一次购买") {
            TextField("总价（元）", text: $purchasePrice)
                .keyboardType(.decimalPad)

            Toggle("设置最近购买日期", isOn: $hasPurchaseDate)
            if hasPurchaseDate {
                DatePicker("购买日期", selection: $purchaseDate, displayedComponents: .date)
            }

            if trackingMode == .consumable {
                Stepper("购买提前期：\(shippingLeadDays) 天（电商通常 2-3）",
                        value: $shippingLeadDays, in: 0...14)
            }

            // 新建模式：同时录入首条购买记录
            if !isEditing {
                TextField("首条记录金额（可选，默认同总价）", text: $firstPurchaseTotal)
                    .keyboardType(.decimalPad)
            }
        }
    }

    // MARK: - 提醒
    private var reminderSection: some View {
        Section("提醒策略") {
            Toggle("启用提醒", isOn: $reminderEnabled)
            if reminderEnabled {
                Stepper("提前 \(remindBeforeDays) 天提醒",
                        value: $remindBeforeDays, in: 0...30)
                Stepper("缓冲 \(bufferDays) 天",
                        value: $bufferDays, in: 0...14)
            }
        }
    }

    // MARK: - 备注
    private var noteSection: some View {
        Section("备注") {
            TextField("如：宿舍常备，新学期记得囤", text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    // MARK: - 加载
    private func load() {
        guard let item else { return }
        name = item.name
        brand = item.brand ?? ""
        trackingMode = item.trackingMode
        category = item.category
        status = item.status
        unitName = item.unitName ?? ""
        packageQuantity = item.packageQuantity.map { String($0) } ?? ""
        expectedUseDays = item.expectedUseDays.map { String($0) } ?? ""
        existingThumbnail = item.thumbnailData

        purchasePrice = item.purchasePrice.map { String($0) } ?? ""
        if let pd = item.purchaseDate {
            purchaseDate = pd
            hasPurchaseDate = true
        }

        if let ed = item.expiryDate {
            expiryDate = ed
            hasExpiryDate = true
        }
        billingCycleDays = item.billingCycleDays.map { String($0) } ?? ""
        if let nb = item.nextBillingDate {
            nextBillingDate = nb
            hasNextBilling = true
        }

        devicePrice = item.devicePurchasePrice.map { String($0) } ?? ""
        residualValue = item.residualValue.map { String($0) } ?? ""
        usefulLifeDays = item.usefulLifeDays.map { String($0) } ?? ""

        shippingLeadDays = item.shippingLeadDays
        note = item.note

        if let p = item.reminderPolicy {
            remindBeforeDays = p.remindBeforeDays
            bufferDays = p.bufferDays
            reminderEnabled = p.isEnabled
        }
    }

    // MARK: - 保存
    @MainActor
    private func save() {
        let target: LifeItem
        if let item {
            target = item
        } else {
            target = LifeItem(name: name.trimmingCharacters(in: .whitespaces),
                              trackingMode: trackingMode, category: category)
        }
        target.brand = brand.isEmpty ? nil : brand
        target.trackingMode = trackingMode
        target.category = category
        target.status = status
        target.unitName = unitName.isEmpty ? nil : unitName
        target.packageQuantity = Double(packageQuantity)
        target.expectedUseDays = Int(expectedUseDays)

        target.purchasePrice = Double(purchasePrice)
        target.purchaseDate = hasPurchaseDate ? purchaseDate : target.purchaseDate

        if trackingMode == .expiry {
            target.expiryDate = hasExpiryDate ? expiryDate : nil
        }
        if trackingMode == .subscription {
            target.billingCycleDays = Int(billingCycleDays)
            target.nextBillingDate = hasNextBilling ? nextBillingDate : nil
        }
        if trackingMode == .durable {
            target.devicePurchasePrice = Double(devicePrice)
            target.residualValue = Double(residualValue)
            target.usefulLifeDays = Int(usefulLifeDays)
        }

        target.shippingLeadDays = shippingLeadDays
        target.note = note
        target.updatedAt = .now

        // 图片：若本次选了新图则落盘并保存缩略图；若移除了则清空旧图
        if let path = pendingPath {
            // 编辑模式下若已有旧图，先删掉
            if isEditing { ImageStore.remove(relativePath: target.imageLocalPath) }
            target.imageLocalPath = path
            target.thumbnailData = pendingThumbnail
        } else if existingThumbnail == nil && previewImage == nil {
            // 用户点了"移除"
            if isEditing { ImageStore.remove(relativePath: target.imageLocalPath) }
            target.imageLocalPath = nil
            target.thumbnailData = nil
        }

        // 单价
        if let pkg = target.packageQuantity, pkg > 0,
           let cost = Double(purchasePrice) {
            target.unitPrice = cost / pkg
        }

        // 提醒策略
        if target.reminderPolicy == nil {
            let p = ReminderPolicy(remindBeforeDays: remindBeforeDays,
                                   bufferDays: bufferDays,
                                   isEnabled: reminderEnabled)
            p.item = target
            target.reminderPolicy = p
            context.insert(p)
        } else {
            target.reminderPolicy?.remindBeforeDays = remindBeforeDays
            target.reminderPolicy?.bufferDays = bufferDays
            target.reminderPolicy?.isEnabled = reminderEnabled
        }

        // 新建时同步生成首条购买记录
        if !isEditing {
            let totalStr = firstPurchaseTotal.isEmpty ? purchasePrice : firstPurchaseTotal
            if let total = Double(totalStr), total > 0 {
                let eff = ForecastEngine.effectiveCost(total: total, coupon: nil, shipping: nil)
                let record = PurchaseRecord(
                    purchasedAt: hasPurchaseDate ? purchaseDate : .now,
                    packageQuantity: target.packageQuantity,
                    totalPrice: total,
                    unitPrice: target.unitPrice,
                    effectiveCost: eff,
                    sourceType: .offline
                )
                record.item = target
                target.purchasePrice = total
                target.purchaseDate = hasPurchaseDate ? purchaseDate : .now
                context.insert(record)
            }
        }

        if target.trackingMode == .consumable {
            ForecastEngine.predictRepurchaseDate(for: target)
        }

        context.insert(target)
        try? context.save()

        // 重排通知
        NotificationService.shared.schedule(for: target)
        // 刷新小组件摘要
        SummaryRefresh.refresh(context: context)

        onSave?()
        dismiss()
    }
}
