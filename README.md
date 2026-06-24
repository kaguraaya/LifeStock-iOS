# LifeStock · 生活余量管家

> 它不是记录事情，而是管理"物品与服务的生命周期、使用价值和下一次购买决策"。

LifeStock 是一款 iOS 原生应用，围绕**生活消耗、期限风险、价值管理与复购决策**，把日常物品/服务当作"小型资产"来运营。它会过期、会用完、值不值、何时买——由你的一手数据说话。

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-orange">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-purple">
  <img alt="Storage" src="https://img.shields.io/badge/Storage-SwiftData-green">
</p>

---

## ✨ 核心能力

LifeStock 把物品分为**四种追踪模式**，每种模式对应不同的"目标日期"与"价值"计算口径：

| 模式 | 典型物品 | 回答的问题 |
|---|---|---|
| 到期类 | 牛奶、药品、证件、会员 | 什么时候会过期 |
| 消耗类 | 纸巾、沐浴露、牙膏 | 什么时候大概率会用完 |
| 订阅类 | B站会员、云盘 | 周期成本、何时扣费 |
| 耐用品类 | 耳机、鼠标、笔记本 | 折旧与当前价值 |

### 功能清单

- **四模式统一建模**：到期 / 消耗 / 订阅 / 耐用品，统一在一套数据模型中
- **物品全生命周期管理**：新增 / 编辑 / 删除 / 归档 / 暂停
- **购买记录表**：每次补货形成历史，支持补录优惠、运费、实际使用天数
- **价值管理**：单价、总价、日均成本、累计花费、月度花费、设备折旧（直线法）
- **复购预测**：基于历史间隔的加权移动平均（WMA），最近一期权重最大
- **置信度显示**：高 / 中 / 低，综合样本量、误差、变异程度启发式打分
- **购买来源提前期**：电商需预留物流天数，提醒时间动态前移
- **首页运营面板**：今日总览、最该处理、未来 7 天建议下单、价值概览
- **洞察图表**（Swift Charts）：分类支出占比、月度花费、价格变化、订阅成本分布
- **本地通知**：动态提醒时间 + 可操作通知（我已补货 / 稍后提醒 / 标记已处理）
- **小组件**（WidgetKit）：小尺寸摘要 + 中尺寸待处理列表
- **App Shortcuts**：Siri / 快捷指令"快速补货""快速新增""标记已处理"
- **模板中心**：7 个内置模板，一键带出默认值
- **数据导出**：JSON 完整备份 + CSV 购买记录（含 BOM，Excel 友好）
- **演示数据**：三套场景（宿舍常用品 / 期限风险 / 价值管理）一键载入
- **商家管理**：维护购买来源、物流提前期、常用渠道、可选外链
- **节省统计**：以历史中位单价为基准，估算每次购买的相对节省
- **成就与等级**：轻量 gamification，连续无断货、补货达人、省钱小能手等徽章
- **物品图片**：PhotosPicker 选图，原图落盘 + 缩略图缓存（演示数据自带占位图）
- **首次引导**：3 张卡片介绍核心价值，可跳过，首启即有内容不空荡
- **隐私优先**：默认不联网，所有数据与预测在设备端完成

---

## 🚀 快速开始

### 环境要求

- **Xcode 16.0+**（项目使用文件系统同步组 `PBXFileSystemSynchronizedRootGroup`，旧版 Xcode 不支持）
- **iOS 17.0+** 部署目标（SwiftData、Swift Charts、可操作通知等需要）
- macOS 14+（运行 Xcode 16）

### 运行步骤

1. 用 **Xcode 16** 打开 `LifeStock.xcodeproj`
2. 选择目标模拟器或真机（iPhone）
3. `Cmd + R` 运行
4. 首次启动会**自动播种演示数据**，可直接体验完整功能

> 真机运行时，通知与小组件权限会在合适的时机申请（保存带提醒的物品、添加小组件时）。

### 开发者签名

项目默认使用 `CODE_SIGN_STYLE = Automatic` 与 `-` 本地签名。若要在真机上运行：

1. 在 Xcode → Signing & Capabilities 中选择你的开发者团队
2. Bundle Identifier 改为你自己的命名空间（如 `com.<你的名字>.lifestock`）

---

## 🏗️ 项目结构

```
LifeStock.xcodeproj
├── LifeStock/                      # 主 App target
│   ├── App/
│   │   ├── LifeStockApp.swift          # @main 入口 + ModelContainer
│   │   ├── RootView.swift              # 四 Tab 框架
│   │   └── AppTheme.swift              # 配色 / 间距 / 圆角常量
│   ├── Models/                         # SwiftData 模型
│   │   ├── Enums.swift                 # 四模式 / 分类 / 状态 / 置信度
│   │   ├── LifeItem.swift              # 追踪对象主表
│   │   ├── PurchaseRecord.swift        # 购买历史（事实层）
│   │   └── SupportingModels.swift      # UsageLog / Merchant / Template / ReminderPolicy
│   ├── Engine/                         # 核心算法
│   │   ├── ForecastEngine.swift        # 预测 / 折旧 / 日均成本 / 置信度 / 提醒
│   │   ├── InsightEngine.swift         # 节省统计 + 成就/等级计算
│   │   └── ItemSnapshot.swift          # UI 快照 + 格式化工具
│   ├── Services/
│   │   ├── NotificationService.swift   # 本地通知 + 可操作通知
│   │   ├── SeedData.swift              # 内置模板 + 演示数据
│   │   ├── ExportService.swift         # JSON / CSV 导出 + 清理
│   │   ├── ImageStore.swift            # 图片落盘 + 缩略图 + 演示占位图
│   │   ├── SummaryStore.swift          # App↔Widget 共享摘要
│   │   └── SummaryRefresh.swift        # 写摘要 + 触发小组件刷新
│   ├── Views/
│   │   ├── HomeView.swift              # 首页运营面板
│   │   ├── LibraryView.swift           # 物品库（搜索/筛选/滑动操作）
│   │   ├── ItemDetailView.swift        # 详情：头图/价值/历史/预测/折旧
│   │   ├── ItemEditView.swift          # 完整新增/编辑（含 PhotosPicker）
│   │   ├── QuickAddSheet.swift         # 模板快速新增
│   │   ├── RestockSheet.swift          # 一键补货
│   │   ├── PurchaseEditSheet.swift     # 购买记录编辑
│   │   ├── InsightsView.swift          # 洞察图表 + 节省统计
│   │   ├── MerchantView.swift          # 商家管理
│   │   ├── AchievementsView.swift      # 成就与节省
│   │   ├── OnboardingView.swift        # 首次引导
│   │   └── ProfileView.swift           # 设置/模板/管理/导出/权限/清理
│   ├── Components/
│   │   ├── ItemCard.swift              # 业务卡片
│   │   └── SharedComponents.swift      # ConfidenceTag / SummaryCard / EmptyState 等
│   ├── AppIntents/
│   │   └── ItemIntents.swift           # App Shortcuts
│   └── Assets.xcassets/
└── LifeStockWidget/                # 小组件扩展 target
    ├── LifeStockWidgetBundle.swift
    ├── LifeStockWidget.swift           # 小/中尺寸
    └── SummaryStore.swift              # 镜像（扩展独立）
```

---

## 🧮 核心算法

### 复购预测（消耗类）

采用**历史间隔 + 加权移动平均（WMA）**，简单、可解释、易实现：

- 1 条历史 → 权重 `[1.0]`
- 2 条 → `[0.6, 0.4]`
- 3 条及以上 → `[0.5, 0.3, 0.2]`（最近一期权重最大）

当存在可量化库存时，优先用"包装量 / 日均消耗"反推；历史不足 2 条时回退到模板默认周期。

**示例**：纸巾三次间隔 30 / 28 / 26 天 → `0.5×26 + 0.3×28 + 0.2×30 = 27.4` 天。

### 置信度

产品启发式分数（非严格统计结论），综合：

```
score = 0.2 + 0.35·样本量 + 0.25·(1−误差惩罚) + 0.20·(1−变异惩罚)
```

映射为 `≥0.75 高` / `0.45–0.74 中` / `<0.45 低`。

### 设备折旧（耐用品）

直线法：`日均折旧 = (购入价 − 残值) / 使用寿命`。

### 动态提醒

```
提醒日 = 目标日 − 提前天数 − 物流提前期 − 缓冲天数
```

例如纸巾预测 6 月 30 日用完，提前 1 天、电商物流 2 天、缓冲 1 天 → 6 月 26 日提醒下单。

---

## 🔒 隐私

- **默认不联网**，所有数据保存在本机（SwiftData）
- 通知与预测均在本地完成，不上传任何信息
- 图片与小票只在本地保存
- 权限按需申请：通知在保存带提醒的物品时、照片在添加图片时
- 提供"清空全部数据"与"仅清理图片缓存"两级清理

---

## 📦 技术栈

| 能力 | 技术 |
|---|---|
| UI | SwiftUI |
| 本地存储 | SwiftData |
| 图表 | Swift Charts |
| 通知 | UserNotifications（可操作通知） |
| 小组件 | WidgetKit |
| 快捷指令 | App Intents / App Shortcuts |
| 架构 | 声明式 + 单 ModelContainer 环境注入 |

---

## 🛣️ 后续可扩展

已实现 ✅ 的功能：商家管理、节省统计、成就/等级、物品图片（PhotosPicker）、首次引导。

项目在架构上仍为以下方向预留了空间（作为课程演示的"下一步"）：

- **iCloud 同步**：SwiftData + CloudKit 兼容 schema（需付费 Apple Developer 账号配置 CloudKit 容器）
- **小票 OCR**：识别购物小票自动填入金额与商品
- **跨物品价格对比**：同类物品的单价横向比较
- **数据可视化增强**：复购间隔趋势、预测 vs 实际双线图

---

## 📄 许可

本项目用于学习与课程展示目的。
