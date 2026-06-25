import SwiftUI
import SwiftData
import UserNotifications

/// 提醒中心：统一查看所有物品的提醒策略与即将到来的提醒。
///
/// 按"紧迫度"分组，展示每个物品的目标日期、提醒日期、策略状态，
/// 并支持快速操作：稍后提醒 / 标记已处理（取消通知）/ 跳转详情。
struct ReminderCenterView: View {

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<LifeItem> { $0.statusRaw == "active" })
    private var items: [LifeItem]

    @State private var selectedItem: LifeItem?
    @State private var groupedItems: [(urgency: String, color: Color, items: [LifeItem])] = []
    @State private var notificationAuthorized = true

    var body: some View {
        List {
            if groupedItems.isEmpty && notificationAuthorized {
                EmptyStateView(
                    symbol: "bell.slash",
                    title: "暂无待提醒",
                    message: "所有物品都在掌控之中。新增物品并启用提醒后，这里会显示即将到来的提醒。"
                )
                .listRowBackground(Color.clear)
            } else {
                if !notificationAuthorized {
                    permissionHint
                }
                ForEach(Array(groupedItems.enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(group.items) { item in
                            reminderRow(item, color: group.color)
                        }
                    } header: {
                        HStack {
                            Circle().fill(group.color).frame(width: 8, height: 8)
                            Text(group.urgency).font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .navigationTitle("提醒中心")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rebuildGroups()
            checkPermission()
        }
        .navigationDestination(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
    }

    // MARK: 权限提示
    private var permissionHint: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("通知权限未开启").font(.subheadline.weight(.medium))
                        Text("前往设置开启通知，才能收到提醒").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 提醒行
    private func reminderRow(_ item: LifeItem, color: Color) -> some View {
        let snap = ItemSnapshotBuilder.snapshot(for: item)
        let reminderDate = ForecastEngine.reminderDate(for: item)
        let policy = item.reminderPolicy
        let enabled = policy?.isEnabled ?? true

        return Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name).font(.subheadline.weight(.semibold))
                    if !enabled {
                        Text("已暂停")
                            .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(snap.statusText).font(.caption).foregroundStyle(color)
                }
                HStack(spacing: 12) {
                    if let rd = reminderDate {
                        Label(RelativeDateText.short(rd), systemImage: "bell")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let p = policy, p.isEnabled {
                        Text("提前 \(p.remindBeforeDays) 天 · 缓冲 \(p.bufferDays) 天")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                NotificationService.shared.snooze(item: item)
            } label: {
                Label("稍后", systemImage: "clock")
            }
            .tint(.orange)
            Button {
                NotificationService.shared.cancel(for: item)
                item.reminderPolicy?.isEnabled = false
                try? context.save()
                rebuildGroups()
            } label: {
                Label("已处理", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }

    // MARK: 权限检查
    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: 分组
    private func rebuildGroups() {
        let groups: [(String, Color, Int)] = [
            ("今天 / 已逾期", .red, 0),
            ("3 天内", .orange, 1),
            ("7 天内", .yellow, 2),
            ("更远", .blue, 3),
            ("暂无目标日期 / 已暂停", .gray, 4)
        ]
        var built: [(urgency: String, color: Color, items: [LifeItem])] = []
        for (name, color, urgency) in groups {
            let inGroup = items.filter {
                let snap = ItemSnapshotBuilder.snapshot(for: $0)
                if !($0.reminderPolicy?.isEnabled ?? true) && urgency != 4 { return false }
                if urgency == 4 {
                    return snap.urgency == 4 || !($0.reminderPolicy?.isEnabled ?? true)
                }
                return snap.urgency == urgency
            }
            if !inGroup.isEmpty {
                built.append((name, color, inGroup))
            }
        }
        groupedItems = built
    }
}
