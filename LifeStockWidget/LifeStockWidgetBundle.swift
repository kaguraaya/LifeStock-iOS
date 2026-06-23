import WidgetKit
import SwiftUI

/// LifeStock 小组件入口 Bundle。
///
/// 对应报告建议："小尺寸摘要 + 中尺寸待处理列表"，
/// 遵守 WidgetKit 的时间线与刷新预算，不做高频无意义更新。
@main
struct LifeStockWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeStockWidget()
    }
}
