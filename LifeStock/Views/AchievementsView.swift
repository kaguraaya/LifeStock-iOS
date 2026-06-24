import SwiftUI
import SwiftData

/// 成就与节省统计：轻度 gamification。
///
/// 展示：当前等级 + 总节省额 + 成就徽章网格（已解锁/进行中）。
struct AchievementsView: View {

    @Query private var items: [LifeItem]

    private var achievements: [InsightEngine.Achievement] {
        InsightEngine.achievements(items: items)
    }

    private var level: (level: Int, title: String, symbol: String) {
        InsightEngine.level(items: items)
    }

    private var totalSaved: Double {
        InsightEngine.totalSavings(items: items)
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                levelHeader
                savingsCard
                achievementGrid
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.bg)
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 等级头部
    private var levelHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.accent, .orange],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 10, y: 6)
                Image(systemName: level.symbol)
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 4) {
                Text("Lv.\(level.level)").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accent)
                Text(level.title).font(.title3.bold())
                Text("\(items.count) 件物品 · \(items.flatMap { $0.purchases }.count) 次记录")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: 节省卡
    private var savingsCard: some View {
        CardSection(title: "节省统计", subtitle: "以历史中位单价为基准的估算") {
            HStack(spacing: 12) {
                SummaryCard(title: "累计节省", value: MoneyFormatter.string(totalSaved),
                            subtitle: "元", symbol: "yensign.circle.fill", tint: .green)
                SummaryCard(title: "解锁成就",
                            value: "\(achievements.filter { $0.isUnlocked }.count)",
                            subtitle: "/ \(achievements.count) 项",
                            symbol: "rosette", tint: AppTheme.accent)
            }
        }
    }

    // MARK: 成就网格
    private var achievementGrid: some View {
        CardSection(title: "成就徽章", subtitle: "持续记录，解锁更多") {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(achievements) { a in
                    badgeCard(a)
                }
            }
        }
    }

    private func badgeCard(_ a: InsightEngine.Achievement) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(a.isUnlocked
                          ? AnyShapeStyle(LinearGradient(colors: [AppTheme.accent, .orange],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.gray.opacity(0.15)))
                    .frame(width: 56, height: 56)
                Image(systemName: a.symbol)
                    .font(.title3)
                    .foregroundStyle(a.isUnlocked ? .white : .gray)
            }
            VStack(spacing: 2) {
                Text(a.title).font(.subheadline.weight(.medium))
                Text(a.subtitle).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if !a.isUnlocked {
                VStack(spacing: 4) {
                    ProgressView(value: a.progress)
                        .tint(AppTheme.accent)
                    Text(a.progressText ?? "")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else {
                Text("已解锁")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
    }
}
