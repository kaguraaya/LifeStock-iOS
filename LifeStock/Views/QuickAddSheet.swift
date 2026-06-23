import SwiftUI
import SwiftData

/// 快速新增：先选模板，再补最少字段。
///
/// 流程（对应报告）：
/// 1. 模板网格（含"从零开始"）
/// 2. 选模板 -> 带出默认值 -> 进入 ItemEditView
struct QuickAddSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\ItemTemplate.name)])
    private var templates: [ItemTemplate]

    @State private var showFullEdit = false
    @State private var editingFromTemplate: ItemTemplate?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("选择模板快速开始")
                            .font(.title3.bold())
                        Text("模板会带出默认模式、周期、单位和价格区间，你只需补名称与价格。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppTheme.pad)

                    LazyVGrid(columns: columns, spacing: 12) {
                        Button {
                            showFullEdit = true
                        } label: {
                            templateTile(symbol: "plus",
                                         title: "从零开始",
                                         subtitle: "自定义全部字段",
                                         tint: AppTheme.accent)
                        }

                        ForEach(templates) { t in
                            Button {
                                editingFromTemplate = t
                            } label: {
                                templateTile(symbol: t.symbol,
                                             title: t.name,
                                             subtitle: t.priceRangeText ?? "无价格区间",
                                             tint: .blue)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.pad)
                }
                .padding(.vertical, 16)
            }
            .background(AppTheme.bg)
            .navigationTitle("快速新增")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showFullEdit) {
                ItemEditView(item: nil)
            }
            .sheet(item: $editingFromTemplate) { t in
                ItemEditView(item: makeItem(from: t)) {
                    dismiss()
                }
            }
        }
    }

    private func templateTile(symbol: String, title: String, subtitle: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            Text(title).font(.subheadline.weight(.medium))
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .padding(8)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    /// 从模板构造一个尚未插入 context 的 LifeItem（编辑保存时才插入）
    private func makeItem(from template: ItemTemplate) -> LifeItem {
        let item = LifeItem(
            name: template.name,
            trackingMode: template.defaultTrackingMode,
            category: template.defaultCategory,
            unitName: template.defaultUnitName,
            packageQuantity: template.defaultPackageQuantity,
            expectedUseDays: template.defaultUseDays,
            templateID: template.id
        )
        return item
    }
}
