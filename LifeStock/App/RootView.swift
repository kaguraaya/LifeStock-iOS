import SwiftUI
import SwiftData

/// 根视图：四个主 Tab（首页 / 物品库 / 洞察 / 我的）。
///
/// "添加"作为全局主操作放在首页导航栏与物品库导航栏右上角，
/// 不占用 Tab 位——符合 HIG"标签页栏用于顶层导航而非动作入口"。
struct RootView: View {

    @State private var selection: Tab = .home
    @State private var showQuickAdd: Bool = false

    enum Tab: Hashable {
        case home, library, insights, profile
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(showQuickAdd: $showQuickAdd)
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(Tab.home)

            LibraryView(showQuickAdd: $showQuickAdd)
                .tabItem {
                    Label("物品库", systemImage: "shippingbox.fill")
                }
                .tag(Tab.library)

            InsightsView()
                .tabItem {
                    Label("洞察", systemImage: "chart.bar.fill")
                }
                .tag(Tab.insights)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(AppTheme.accent)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
        }
    }
}
