import SwiftUI
import SwiftData
import UserNotifications

/// 我的：设置、模板、导出、权限、清理、关于。
///
/// 涵盖：通知权限、模板中心、演示模式、导出 JSON/CSV、清理、版本。
struct ProfileView: View {

    @Environment(\.modelContext) private var context
    @Query private var allItems: [LifeItem]
    @Query private var templates: [ItemTemplate]

    @State private var notificationAuthorized = false
    @State private var showPermissionAlert = false
    @State private var shareItem: ShareFile?
    @State private var showClearConfirm = false
    @State private var showDemoConfirm = false
    @State private var showTemplateSheet = false
    @State private var busyMessage: String?

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            List {
                headerSection
                permissionSection
                dataSection
                demoSection
                templateSection
                manageSection
                exportSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            .navigationTitle("我的")
        }
        .sheet(item: $shareItem) { f in
            ActivityShareView(url: f.url)
        }
        .sheet(isPresented: $showTemplateSheet) {
            TemplateCenterView()
        }
        .alert("清空所有数据？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认清空", role: .destructive) {
                clearAll()
            }
        } message: {
            Text("将删除所有物品、购买记录与自定义模板，内置模板会保留。此操作不可恢复。")
        }
        .alert("重新载入演示数据？", isPresented: $showDemoConfirm) {
            Button("取消", role: .cancel) {}
            Button("载入", role: .destructive) {
                reloadDemo()
            }
        } message: {
            Text("将先清空当前数据，再写入三套演示场景。")
        }
        .onAppear { refreshPermission() }
    }

    // MARK: - 头部
    private var headerSection: some View {
        // 用 reduce 做轻量计数，避免 flatMap 全量复制数组导致 body 卡死
        let purchaseCount = allItems.reduce(0) { $0 + $1.purchases.count }
        return Section {
            VStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
                Text("LifeStock · 生活余量管家")
                    .font(.headline)
                Text("追踪 \(allItems.count) 件物品 · \(purchaseCount) 条记录")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - 权限
    private var permissionSection: some View {
        Section("权限") {
            HStack {
                Image(systemName: "bell.badge")
                VStack(alignment: .leading) {
                    Text("通知")
                    Text(notificationAuthorized ? "已授权" : "未授权")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { notificationAuthorized },
                    set: { newValue in
                        if newValue {
                            requestNotification()
                        } else {
                            openSettings()
                        }
                    }
                ))
                .labelsHidden()
            }

            NavigationLink {
                PrivacyExplanationView()
            } label: {
                Label("隐私说明", systemImage: "hand.raised.fill")
            }
        }
    }

    // MARK: - 数据管理
    private var dataSection: some View {
        Section("数据") {
            Button {
                clearImages()
            } label: {
                Label("清理图片缓存", systemImage: "photo.stack")
            }
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("清空所有数据", systemImage: "trash")
            }
        }
    }

    // MARK: - 演示
    private var demoSection: some View {
        Section("演示") {
            Button {
                showDemoConfirm = true
            } label: {
                Label("重新载入演示数据", systemImage: "sparkles")
            }
            Label("数据已" + (SeedData.hasSeeded() ? "包含演示场景" : "未播种"),
                  systemImage: SeedData.hasSeeded() ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 模板
    private var templateSection: some View {
        Section("模板") {
            Button {
                showTemplateSheet = true
            } label: {
                Label("模板中心（\(templates.count)）", systemImage: "square.grid.2x2")
            }
        }
    }

    // MARK: - 管理入口（商家 / 成就 / 提醒中心）
    private var manageSection: some View {
        Section {
            NavigationLink {
                ReminderCenterView()
            } label: {
                Label("提醒中心", systemImage: "bell.badge")
            }
            NavigationLink {
                MerchantView()
            } label: {
                Label("商家管理", systemImage: "storefront")
            }
            NavigationLink {
                AchievementsView()
            } label: {
                Label("成就与节省", systemImage: "rosette")
            }
        } header: {
            Text("管理")
        }
    }

    // MARK: - 导出
    private var exportSection: some View {
        Section("导出与备份") {
            Button {
                exportJSON()
            } label: {
                Label("导出 JSON 备份", systemImage: "doc.text")
            }
            Button {
                exportCSV()
            } label: {
                Label("导出 CSV（购买记录）", systemImage: "tablecells")
            }
        }
    }

    // MARK: - 关于
    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Label("版本", systemImage: "info.circle")
                Spacer()
                Text("v\(appVersion)").foregroundStyle(.secondary)
            }
            NavigationLink {
                AboutView()
            } label: {
                Label("关于 LifeStock", systemImage: "questionmark.circle")
            }
        }
    }

    // MARK: - 动作
    private func refreshPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    @MainActor
    private func requestNotification() {
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            notificationAuthorized = granted
            if !granted { openSettings() }
        }
    }

    @MainActor
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    private func exportJSON() {
        do {
            let url = try ExportService.writeJSONFile(context: context)
            shareItem = ShareFile(url: url)
        } catch {
            busyMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportCSV() {
        do {
            let url = try ExportService.exportPurchaseCSV(context: context)
            shareItem = ShareFile(url: url)
        } catch {
            busyMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func clearImages() {
        try? ExportService.clearImageCache(context: context)
        SummaryRefresh.refresh(context: context)
    }

    @MainActor
    private func clearAll() {
        try? ExportService.clearAllData(context: context)
        SummaryRefresh.refresh(context: context)
    }

    @MainActor
    private func reloadDemo() {
        try? ExportService.clearAllData(context: context)
        SeedData.seedDemoData(context: context)
        SummaryRefresh.refresh(context: context)
    }
}

// MARK: - 分享包装
struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityShareView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 隐私说明
private struct PrivacyExplanationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私优先 · 设备端处理")
                    .font(.title3.bold())
                VStack(alignment: .leading, spacing: 10) {
                    bullet("默认不联网，所有数据保存在本机。")
                    bullet("通知与预测均在本地完成，不上传任何信息。")
                    bullet("物品图片与小票只在本地保存，不会上传服务器。")
                    bullet("权限按需申请：通知在保存带提醒的物品时申请，照片在添加图片时申请。")
                    bullet("导出的 JSON / CSV 包含价格与渠道等敏感信息，请妥善保管。")
                    bullet("你可以随时在“数据”中清空全部数据或仅清理图片缓存。")
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("隐私说明")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(text)
        }
    }
}

// MARK: - 关于
private struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("LifeStock / 生活余量管家")
                    .font(.title3.bold())
                Text("它不是记录事情，而是管理“物品与服务的生命周期、使用价值和下一次购买决策”。")
                    .foregroundStyle(.secondary)
                Divider()
                Text("支持四种追踪模式：到期类、消耗类、订阅类、耐用品类。基于历史数据做复购预测、日均成本与设备折旧，帮你回答“什么时候该买”“这次买得贵不贵”。")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 模板中心
private struct TemplateCenterView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ItemTemplate.name)]) private var templates: [ItemTemplate]

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(templates) { t in
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: t.symbol)
                            .font(.title2).foregroundStyle(AppTheme.accent)
                        Text(t.name).font(.subheadline.weight(.medium))
                        if let range = t.priceRangeText {
                            Text(range).font(.caption).foregroundStyle(.secondary)
                        }
                        if let days = t.defaultUseDays {
                            Text("默认周期 \(days) 天").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(AppTheme.bg)
        .navigationTitle("模板中心")
        .navigationBarTitleDisplayMode(.inline)
    }
}
