import SwiftUI
import SwiftData

@main
@MainActor
struct LifeStockApp: App {

    /// SwiftData 容器。所有模型注册于此，App 各处通过环境注入。
    /// 采用默认存储（本地 App Support 下 sqlite），符合"离线优先、设备端计算"原则。
    let container: ModelContainer

    /// 是否需要展示首次引导
    @AppStorage("lifestock.onboarding.done") private var onboardingDone: Bool = false

    init() {
        do {
            container = try ModelContainer(
                for: LifeItem.self, PurchaseRecord.self, UsageLog.self,
                     Merchant.self, ItemTemplate.self, ReminderPolicy.self,
                configurations: ModelConfiguration(
                    isStoredInMemoryOnly: false,
                    allowsSave: true
                )
            )
            // 注入给 App Intents 使用
            SharedContainer.container = container
        } catch {
            // 容器创建失败时回退到内存存储，保证 App 仍可启动
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(
                for: LifeItem.self, PurchaseRecord.self, UsageLog.self,
                     Merchant.self, ItemTemplate.self, ReminderPolicy.self,
                configurations: config
            )
            SharedContainer.container = container
        }

        // 启动时注册通知分类
        NotificationService.shared.registerCategories()

        // 启动时播种内置模板
        SeedData.seedBuiltInTemplates(context: container.mainContext)

        // 首次启动立即播种演示数据，确保首屏不空（无论是否过引导页）
        if !SeedData.hasSeeded() {
            SeedData.seedDemoData(context: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            if onboardingDone {
                RootView()
                    .modelContainer(container)
                    .onAppear {
                        SummaryRefresh.refresh(context: container.mainContext)
                    }
            } else {
                OnboardingView {
                    onboardingDone = true
                    SummaryRefresh.refresh(context: container.mainContext)
                }
            }
        }
    }
}
