import SwiftUI

// MARK: - 置信度标签
/// 高/中/低胶囊标签，附解释气泡
struct ConfidenceTag: View {
    let level: ConfidenceLevel?

    var body: some View {
        if let level = level {
            HStack(spacing: 4) {
                Image(systemName: symbol(for: level))
                    .font(.caption2)
                Text("置信度 \(level.displayName)")
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color(for: level).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: level))
            .help(level.explanation)  // macOS/iPad 辅助；iPhone 不影响
            .accessibilityLabel("预测置信度：\(level.displayName)")
        }
    }

    private func symbol(for l: ConfidenceLevel) -> String {
        switch l {
        case .high:   return "checkmark.seal.fill"
        case .medium: return "circle.lefthalf.filled"
        case .low:    return "questionmark.circle"
        }
    }
    private func color(for l: ConfidenceLevel) -> Color {
        switch l {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .gray
        }
    }
}

// MARK: - 状态色条（卡片左侧）
struct UrgencyBar: View {
    let urgency: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(UrgencyPalette.color(urgency: urgency))
            .frame(width: 4)
    }
}

// MARK: - 模式胶囊
struct ModeBadge: View {
    let mode: TrackingMode
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: mode.symbol).font(.caption2)
            Text(mode.displayName).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(AppTheme.accent.opacity(0.12), in: Capsule())
        .foregroundStyle(AppTheme.accent)
    }
}

// MARK: - 摘要卡片（首页 / 洞察通用）
struct SummaryCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var tint: Color = AppTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let s = symbol {
                    Image(systemName: s).foregroundStyle(tint)
                }
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(value).font(.title2.bold())
            if let sub = subtitle {
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.pad)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .cardShadow()
    }
}

// MARK: - 章节标题
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let s = subtitle {
                Text(s).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            }
        }
    }
}

// MARK: - 章节容器
struct CardSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.gap) {
            SectionHeader(title: title, subtitle: subtitle)
            content
        }
        .padding(.horizontal, AppTheme.pad)
    }
}
