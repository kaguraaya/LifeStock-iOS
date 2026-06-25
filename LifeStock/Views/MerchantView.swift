import SwiftUI
import SwiftData

/// 商家管理：维护购买来源/渠道。
///
/// 每个商家记录类型、物流提前期、是否常用、可选外链。
/// LifeItem 在购买时引用某个 Merchant 作为默认来源。
struct MerchantView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Merchant.isFavorite, order: .reverse),
                  SortDescriptor(\Merchant.name)]) private var merchants: [Merchant]

    @State private var showAdd = false
    @State private var editing: Merchant?

    var body: some View {
        List {
            if merchants.isEmpty {
                EmptyStateView(
                    symbol: "storefront",
                    title: "还没有商家",
                    message: "添加学校超市、淘宝、京东等常用购买来源，补货时可以一键选择，并自动计算物流提前期。",
                    actionTitle: "添加商家",
                    action: { showAdd = true }
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(merchants) { m in
                    Button {
                        editing = m
                    } label: {
                        merchantRow(m)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(m)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .navigationTitle("商家管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(AppTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            MerchantEditSheet(merchant: nil)
        }
        .sheet(item: $editing) { m in
            MerchantEditSheet(merchant: m)
        }
    }

    private func merchantRow(_ m: Merchant) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(m.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: m.type.symbol)
                    .foregroundStyle(m.type.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(m.name).font(.subheadline.weight(.medium))
                    if m.isFavorite {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    }
                }
                Text("\(m.type.displayName) · 物流 \(m.leadDays) 天")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func delete(_ m: Merchant) {
        context.delete(m)
        try? context.save()
    }
}

// MARK: - 编辑/新增
struct MerchantEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var merchant: Merchant?

    @State private var name = ""
    @State private var type: MerchantType = .offline
    @State private var leadDays: Int = 0
    @State private var deeplink = ""
    @State private var isFavorite = false

    private var isEditing: Bool { merchant != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("名称（如：学校超市、京东）", text: $name)
                    Picker("类型", selection: $type) {
                        ForEach(MerchantType.allCases) { t in
                            Label(t.displayName, systemImage: t.symbol).tag(t)
                        }
                    }
                }
                Section("物流") {
                    Stepper("提前期 \(leadDays) 天（电商通常 2-3）", value: $leadDays, in: 0...14)
                } header: {
                    Text("物流")
                } footer: {
                    Text("从决定购买到拿到手所需的天数，会影响提醒时间。")
                }
                Section("其他") {
                    Toggle("设为常用", isOn: $isFavorite)
                    TextField("外链（可选）", text: $deeplink)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(isEditing ? "编辑商家" : "新增商家")
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
        }
    }

    private func load() {
        guard let m = merchant else { return }
        name = m.name
        type = m.type
        leadDays = m.leadDays
        deeplink = m.deeplinkURL ?? ""
        isFavorite = m.isFavorite
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target: Merchant
        if let m = merchant {
            m.name = trimmedName
            m.type = type
            m.leadDays = leadDays
            m.deeplinkURL = deeplink.isEmpty ? nil : deeplink
            m.isFavorite = isFavorite
            target = m
        } else {
            let m = Merchant(name: trimmedName, type: type, leadDays: leadDays,
                             deeplinkURL: deeplink.isEmpty ? nil : deeplink, isFavorite: isFavorite)
            context.insert(m)
            target = m
        }

        // 把该商家的 leadDays 同步到所有以其为默认来源的物品的 shippingLeadDays，
        // 让商家提前期真正参与提醒计算。
        let merchantID = target.id
        let items = (try? context.fetch(FetchDescriptor<LifeItem>(
            predicate: #Predicate { $0.purchaseChannelID == merchantID }
        ))) ?? []
        for item in items {
            item.shippingLeadDays = leadDays
            item.updatedAt = .now
            NotificationService.shared.schedule(for: item)
        }
        SummaryRefresh.refresh(context: context)
        try? context.save()
        dismiss()
    }
}

// MARK: - MerchantType 颜色扩展
extension MerchantType {
    var color: Color {
        switch self {
        case .campus:      return .blue
        case .offline:     return .teal
        case .online:      return .purple
        case .subscription: return .indigo
        }
    }
}
