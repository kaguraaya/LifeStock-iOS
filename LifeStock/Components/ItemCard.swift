import SwiftUI

/// 最重要的业务卡片：同时显示四层信息（名称/状态/价值/颜色条）
///
/// 第一行：名称 + 分类 + 模式标签
/// 第二行：状态文案（预计 3 天后用完 / 今天到期 / 7 天后续费）
/// 第三行：价值文案（0.87 元/天 / 最近一次 19.9 元）
/// 右侧：颜色状态条 + 置信度
struct ItemCard: View {

    let snapshot: ItemSnapshot
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                UrgencyBar(urgency: snapshot.urgency)

                VStack(alignment: .leading, spacing: 8) {
                    // 第一行：名称 + 模式
                    HStack(spacing: 6) {
                        Text(snapshot.name)
                            .font(.headline)
                            .lineLimit(1)
                        ModeBadge(mode: snapshot.trackingMode)
                        Spacer()
                        ConfidenceTag(level: snapshot.confidenceLevel)
                    }

                    // 第二行：状态文案
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.symbol)
                            .font(.subheadline)
                            .foregroundStyle(snapshot.urgencyColor)
                        Text(snapshot.statusText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(snapshot.urgencyColor)
                    }

                    // 第三行：价值文案
                    if let value = snapshot.valueText {
                        Text(value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.pad)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .cardShadow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 紧凑版卡片（用于"建议购买"列表）
struct CompactItemRow: View {
    let snapshot: ItemSnapshot
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: snapshot.symbol)
                    .foregroundStyle(snapshot.urgencyColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(snapshot.statusText).font(.caption).foregroundStyle(snapshot.urgencyColor)
                }
                Spacer()
                if let value = snapshot.valueText {
                    Text(value).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
