import SwiftUI
import SwiftData

/// 物品库：全量查看与筛选。
///
/// - 顶部搜索（searchable）
/// - 模式筛选条（全部 / 到期 / 消耗 / 订阅 / 耐用品）
/// - 紧迫度分组列表
/// - 右滑补货 / 左滑归档
struct LibraryView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\LifeItem.updatedAt, order: .reverse)])
    private var allItems: [LifeItem]

    @Binding var showQuickAdd: Bool
    @State private var searchText: String = ""
    @State private var selectedMode: TrackingMode? = nil
    @State private var selectedItem: LifeItem?
    @State private var restockItem: LifeItem?

    private var filteredItems: [LifeItem] {
        allItems
            .filter { item in
                // 模式筛选
                if let mode = selectedMode, item.trackingMode != mode { return false }
                // 搜索（名称 / 品牌 / 分类）
                if searchText.isEmpty { return true }
                let q = searchText.lowercased()
                return item.name.lowercased().contains(q)
                    || (item.brand?.lowercased().contains(q) ?? false)
                    || item.category.displayName.contains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modeFilterBar
                    .padding(.vertical, 10)

                if filteredItems.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            symbol: "shippingbox",
                            title: searchText.isEmpty ? "还没有物品" : "没有匹配的物品",
                            message: searchText.isEmpty
                                ? "点击右上角 + 添加第一件物品"
                                : "尝试更换关键词或筛选条件",
                            actionTitle: searchText.isEmpty ? "快速新增" : nil,
                            action: searchText.isEmpty ? { showQuickAdd = true } : nil
                        )
                        .padding(.top, 60)
                    }
                    .background(AppTheme.bg)
                } else {
                    itemListView
                }
            }
            .background(AppTheme.bg)
            .navigationTitle("物品库")
            .searchable(text: $searchText, prompt: "搜索名称、品牌或分类")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("快速新增")
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
            .sheet(item: $restockItem) { item in
                RestockSheet(item: item)
            }
        }
    }

    private var modeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "全部", isSelected: selectedMode == nil) {
                    selectedMode = nil
                }
                ForEach(TrackingMode.allCases) { mode in
                    chip(title: mode.displayName, isSelected: selectedMode == mode) {
                        selectedMode = (selectedMode == mode ? nil : mode)
                    }
                }
            }
            .padding(.horizontal, AppTheme.pad)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    isSelected ? AppTheme.accent : AppTheme.card,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var itemListView: some View {
        List {
            ForEach(filteredItems) { item in
                let snap = ItemSnapshotBuilder.snapshot(for: item)
                ItemCard(snapshot: snap) {
                    selectedItem = item
                }
                .contextMenu {
                    Button {
                        restockItem = item
                    } label: {
                        Label("我已补货", systemImage: "cart.fill")
                    }
                    Button {
                        toggleArchive(item)
                    } label: {
                        Label(item.status == .archived ? "恢复追踪" : "归档",
                              systemImage: item.status == .archived ? "arrow.uturn.backward.circle" : "archivebox")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        restockItem = item
                    } label: {
                        Label("补货", systemImage: "cart.fill")
                    }
                    .tint(AppTheme.accent)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        toggleArchive(item)
                    } label: {
                        Label("归档", systemImage: "archivebox")
                    }
                    .tint(.gray)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: AppTheme.pad, bottom: 4, trailing: AppTheme.pad))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
    }

    private func toggleArchive(_ item: LifeItem) {
        item.status = (item.status == .archived ? .active : .archived)
        item.updatedAt = .now
        try? context.save()
        SummaryRefresh.refresh(context: context)
    }
}
