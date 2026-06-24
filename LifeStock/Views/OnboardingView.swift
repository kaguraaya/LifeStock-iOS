import SwiftUI

/// 首次启动引导：3 张卡片，简短可跳过。
///
/// 对应报告 onboarding 原则：
/// - 启动后展示，不上来先塞厚重表单
/// - 只讲 3 件事：会过期 / 会用完 / 值不值何时买
/// - 不在首启申请任何权限
struct OnboardingView: View {

    @State private var index = 0
    var onFinish: () -> Void

    private let pages: [OnboardPage] = [
        OnboardPage(symbol: "calendar.badge.exclamationmark",
                    title: "会过期",
                    subtitle: "牛奶、药品、证件、会员",
                    desc: "LifeStock 会盯着到期日，在合适的时候提醒你处理，而不是到日子才慌。",
                    tint: .red),
        OnboardPage(symbol: "shippingbox.fill",
                    title: "会用完",
                    subtitle: "纸巾、沐浴露、牙膏",
                    desc: "根据你的购买历史预测下次用完的时间，并结合购买来源提醒你提前下单。",
                    tint: AppTheme.accent),
        OnboardPage(symbol: "chart.bar.fill",
                    title: "值不值、何时买",
                    subtitle: "单价、日均成本、复购节奏",
                    desc: "不只是提醒，而是帮你管理物品的使用价值，回答这次买得贵不贵。",
                    tint: .green)
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            VStack(spacing: 12) {
                Button {
                    if index < pages.count - 1 {
                        withAnimation { index += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(index < pages.count - 1 ? "下一步" : "开始使用")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(pages[index].tint)

                Button("跳过") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.pad)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .background(AppTheme.bg)
    }

    private func pageView(_ p: OnboardPage) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(p.tint.opacity(0.12))
                    .frame(width: 160, height: 160)
                Image(systemName: p.symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(p.tint)
            }
            VStack(spacing: 8) {
                Text(p.title).font(.largeTitle.bold())
                Text(p.subtitle).font(.headline).foregroundStyle(.secondary)
            }
            Text(p.desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardPage {
    let symbol: String
    let title: String
    let subtitle: String
    let desc: String
    let tint: Color
}
