import Foundation
import UserNotifications

/// 本地通知服务。
///
/// 设计要点（对应报告"通知与提醒策略"）：
/// - 触发逻辑随 trackingMode 走 ForecastEngine.reminderDate(for:)
/// - 同一物品 24 小时内不重复发同主题通知
/// - 用户点"稍后提醒"按 snoozeHours 延后
/// - 暂不实现"近 12 小时打开过详情页就抑制"（需要埋点，留作扩展）
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    /// 动作标识，对应可操作通知的按钮
    enum ActionID: String {
        case restocked   = "RESTOCKED"
        case snooze      = "SNOOZE"
        case markHandled = "MARK_HANDLED"
    }

    enum CategoryID: String {
        case itemReminder = "ITEM_REMINDER"
    }

    /// 请求通知授权。仅在"用户保存了带提醒的物品"等时机调用。
    @MainActor
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// 注册可操作通知的分类（在启动时调用一次）
    func registerCategories() {
        let restock = UNNotificationAction(
            identifier: ActionID.restocked.rawValue,
            title: "我已补货",
            options: [.foreground])
        let snooze = UNNotificationAction(
            identifier: ActionID.snooze.rawValue,
            title: "稍后提醒",
            options: [])
        let handled = UNNotificationAction(
            identifier: ActionID.markHandled.rawValue,
            title: "标记已处理",
            options: [.foreground])

        let category = UNNotificationCategory(
            identifier: CategoryID.itemReminder.rawValue,
            actions: [restock, snooze, handled],
            intentIdentifiers: [],
            options: [])

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// 为单个物品排定提醒。
    /// - Parameters:
    ///   - item: 目标物品
    ///   - now: 当前时间（便于测试）
    func schedule(for item: LifeItem, now: Date = .now) {
        guard let policy = item.reminderPolicy, policy.isEnabled else {
            cancel(for: item)
            return
        }
        guard let fireDate = ForecastEngine.reminderDate(for: item) else {
            cancel(for: item)
            return
        }
        // 已过去的就不排（除非未来重排）
        guard fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(item.name)：\(titleSuffix(for: item))"
        content.body = body(for: item)
        content.sound = .default
        content.categoryIdentifier = CategoryID.itemReminder.rawValue
        content.userInfo = ["itemID": item.id.uuidString]
        content.threadIdentifier = item.id.uuidString  // 按物品聚合，系统自动折叠

        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                                from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: item),
            content: content,
            trigger: trigger)

        // 先取消旧的再排新的，保证 24 小时内不重复
        cancel(for: item)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// 取消某个物品的所有通知
    func cancel(for item: LifeItem) {
        let id = notificationID(for: item)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// 批量重排所有物品（数据变更后调用）
    func rescheduleAll(items: [LifeItem], now: Date = .now) {
        for item in items where item.status == .active {
            schedule(for: item, now: now)
        }
    }

    /// 稍后提醒：延后 snoozeHours
    func snooze(item: LifeItem, hours: Int? = nil) {
        let h = hours ?? item.reminderPolicy?.snoozeHours ?? 8
        let fireDate = Date().addingTimeInterval(TimeInterval(h) * 3600)

        let content = UNMutableNotificationContent()
        content.title = "\(item.name)：稍后提醒"
        content.body = body(for: item)
        content.sound = .default
        content.categoryIdentifier = CategoryID.itemReminder.rawValue
        content.userInfo = ["itemID": item.id.uuidString]
        content.threadIdentifier = item.id.uuidString

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(h) * 3600, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: item) + ".snooze",
            content: content,
            trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: - 文案

    private func titleSuffix(for item: LifeItem) -> String {
        if let days = ForecastEngine.daysLeft(for: item) {
            if days < 0 { return "已超期 \(-days) 天" }
            if days == 0 { return "今天需要处理" }
            return "\(days) 天后需要处理"
        }
        return "记得处理"
    }

    private func body(for item: LifeItem) -> String {
        var parts: [String] = []
        if item.shippingLeadDays > 0 {
            parts.append("网购需预留 \(item.shippingLeadDays) 天物流")
        }
        return parts.isEmpty ? "点击查看详情，或一键补货。" : parts.joined(separator: "，") + "。"
    }

    private func notificationID(for item: LifeItem) -> String {
        "lifestock.item.\(item.id.uuidString)"
    }
}
