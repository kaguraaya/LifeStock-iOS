import Foundation

/// 物品的四种追踪模式，决定了"目标日期"与"价值"的计算口径。
enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case expiry       // 到期类：食品 / 药品 / 证件 / 会员
    case consumable   // 消耗类：纸巾 / 沐浴露 / 牙膏
    case subscription // 订阅类：B站会员 / 云盘
    case durable      // 耐用品类：耳机 / 笔记本

    var id: String { rawValue }

    /// 用户可见的中文标签
    var displayName: String {
        switch self {
        case .expiry:       return "到期类"
        case .consumable:   return "消耗类"
        case .subscription: return "订阅类"
        case .durable:      return "耐用品类"
        }
    }

    /// 一句话说明，用于 onboarding 与表单提示
    var hint: String {
        switch self {
        case .expiry:       return "会过期：食品、药品、证件、会员续费"
        case .consumable:   return "会用完：纸巾、沐浴露、牙膏"
        case .subscription: return "周期扣费：云盘、会员、订阅服务"
        case .durable:      return "耐用品：耳机、鼠标、笔记本，按折旧算价值"
        }
    }

    var symbol: String {
        switch self {
        case .expiry:       return "calendar.badge.exclamationmark"
        case .consumable:   return "shippingbox"
        case .subscription: return "creditcard"
        case .durable:      return "headphones"
        }
    }
}

/// 物品分类，用于洞察图表分组与筛选
enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case food, medicine, daily, document
    case subscription, warranty, study
    case device, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food:         return "食品"
        case .medicine:     return "药品"
        case .daily:        return "日用品"
        case .document:     return "证件"
        case .subscription: return "订阅"
        case .warranty:     return "保修"
        case .study:        return "学习"
        case .device:       return "设备"
        case .other:        return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .food:         return "fork.knife"
        case .medicine:     return "cross.case"
        case .daily:        return "house"
        case .document:     return "doc.text"
        case .subscription: return "creditcard"
        case .warranty:     return "checkmark.shield"
        case .study:        return "graduationcap"
        case .device:       return "laptopcomputer"
        case .other:        return "square.dashed"
        }
    }
}

/// 物品状态：活跃 / 归档 / 暂停
enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case active, archived, paused
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .active:   return "追踪中"
        case .archived: return "已归档"
        case .paused:   return "已暂停"
        }
    }
}

/// 商家/购买渠道类型
enum MerchantType: String, Codable, CaseIterable, Identifiable {
    case campus, offline, online, subscription
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .campus:      return "校内"
        case .offline:     return "线下"
        case .online:      return "电商"
        case .subscription: return "订阅"
        }
    }
    var symbol: String {
        switch self {
        case .campus:      return "building.columns"
        case .offline:     return "storefront"
        case .online:      return "shippingbox"
        case .subscription: return "autorenew"
        }
    }
}

/// 购买来源类型（冗余于 MerchantType，保留用于记录层面）
enum PurchaseSourceType: String, Codable {
    case online, offline, campus, subscription
}

/// 置信度等级，由算法分值映射而来
enum ConfidenceLevel: String {
    case high, medium, low

    var displayName: String {
        switch self {
        case .high:   return "高"
        case .medium: return "中"
        case .low:    return "低"
        }
    }

    var explanation: String {
        switch self {
        case .high:   return "历史样本充足，预测较可靠"
        case .medium: return "样本中等，预测仅供参考"
        case .low:    return "数据不足，建议先多记录几次"
        }
    }

    static func from(score: Double) -> ConfidenceLevel {
        if score >= 0.75 { return .high }
        if score >= 0.45 { return .medium }
        return .low
    }
}
