# Appearance Mode Implementation Plan

> **状态：✅ 已全部完成（含后续 Bug Fix）**

**Goal:** 为 ISeeImageViewer 加入浅色 / 深色 / 跟随系统三档外观切换，设置持久化，QuickViewer 保持强制深色。

**Architecture（实际实现）：**
`AppearanceMode` 枚举和持久化逻辑扩展到现有 `AppState`；`DS.Color.*` 背景/交互色使用 `AdaptiveColor` 类型（实现 `ShapeStyle.resolve(in:)` + `View`），从 `EnvironmentValues.colorScheme` 读取外观，正确响应 SwiftUI per-view `preferredColorScheme` 覆盖；根视图 `ISeeImageViewerApp` 用 `@Published appearanceMode` 驱动 `preferredColorScheme`；Toolbar 新增三档 Menu 入口；QuickViewer 材质改为明确深色半透明色（不依赖 NSAppearance）。

> ⚠️ 原计划使用 `NSColor(dynamicProvider:)` 实现自适应色，上线后发现该方案响应 NSWindow 级别的 NSAppearance 而非 SwiftUI per-view colorScheme，导致 QuickViewer 浅色模式下颜色错误。已全面替换为 `AdaptiveColor(ShapeStyle)` 方案。

**Tech Stack:** SwiftUI, UserDefaults

**Spec:** `specs/2026-03-24-appearance-mode-design.md`

---

## 文件改动总览

| 文件 | 动作 | 说明 |
|------|------|------|
| `ISeeImageViewer/FullScreen/AppState.swift` | 修改 | 新增 `AppearanceMode` 枚举 + `appearanceMode` 属性 + `init()` |
| `ISeeImageViewer/DesignSystem.swift` | 修改 | 新增 `AdaptiveColor(ShapeStyle, View)`，更新四个 `DS.Color.*` 色票 |
| `ISeeImageViewer/ISeeImageViewerApp.swift` | 修改 | 动态 `preferredColorScheme` 绑定 + `.defaultSize(1280, 800)` |
| `ISeeImageViewer/ImageViewer/ImagePreviewView.swift` | 修改 | 移除 `.preferredColorScheme(.dark)`；硬编码白色改为 `Color.primary` |
| `ISeeImageViewer/ContentView.swift` | 修改 | 新增外观切换 Toolbar Menu |
| `ISeeImageViewer/QuickViewer/QuickViewerOverlay.swift` | 修改 | 材质替换为明确深色半透明（`Color(white:0,opacity:)`） |
| `ISeeImageViewer/FolderBrowser/FolderSidebarView.swift` | 修改 | 移除强制深色环境；`listRowBackground` 自适应；选中高亮用 `accentColor` |

---

## Task 1：AppState — 新增 AppearanceMode

- [x] **Step 1：用完整内容替换 AppState.swift**
- [x] **Step 2：构建验证** → `** BUILD SUCCEEDED **`
- [x] **Step 3：提交** → `f78438a 完成 AppearanceMode 数据模型`

---

## Task 2：DesignSystem — AdaptiveColor + 色票更新

- [x] **Step 1：新增 `AdaptiveColor(ShapeStyle, View)` 结构体**（替代原计划的 `NSColor` 方案）
- [x] **Step 2：将 `DS.Color` 块替换为 `AdaptiveColor` 版本**
- [x] **Step 3：构建验证** → `** BUILD SUCCEEDED **`
- [x] **Step 4：提交** → `2e32207 修复 DesignSystem：改用 AdaptiveColor(ShapeStyle) 响应 SwiftUI per-view colorScheme`

---

## Task 3：ISeeImageViewerApp — 动态 colorScheme 绑定

- [x] **Step 1：将 `.preferredColorScheme(.dark)` 替换为动态绑定**
- [x] **Step 2：构建验证** → `** BUILD SUCCEEDED **`
- [x] **Step 3：提交** → `59d08d3 完成 AppearanceMode 根视图绑定`

---

## Task 4：ImagePreviewView — 移除强制深色 + 自适应颜色

- [x] **Step 1：删除 `.preferredColorScheme(.dark)`**
- [x] **Step 2：所有硬编码 `.white` 改为 `Color.primary`**（原计划未含，Bug Fix 补充）
- [x] **Step 3：构建验证** → `** BUILD SUCCEEDED **`
- [x] **Step 4：提交** → `62614b8` + `ce79d8b`

---

## Task 5：ContentView — 外观切换 Toolbar Menu

- [x] **Step 1：新增外观切换 ToolbarItem**
- [x] **Step 2：构建验证** → `** BUILD SUCCEEDED **`
- [x] **Step 3：提交** → `b4363e7 完成 AppearanceMode Toolbar 入口`

---

## Task 6：文档同步 + 最终验证

- [x] **Step 1：Roadmap.md 已完成模块表格新增 AppearanceMode**
- [x] **Step 2：Roadmap.md 关键架构决策新增第 11 条**
- [x] **Step 3：CLAUDE.md 文件结构补充 spec 条目**
- [x] **Step 4：clean build 最终验证** → `** BUILD SUCCEEDED **`
- [x] **Step 5：提交 + 推送** → `e48f6d7 完成 AppearanceMode 文档同步`

---

## Bug Fix 记录（实现后发现）

| Commit | 文件 | 问题 | 修复 |
|--------|------|------|------|
| `2e32207` | DesignSystem.swift | `NSColor(dynamicProvider:)` 不响应 per-view colorScheme，QuickViewer 颜色全错 | 改用 `AdaptiveColor(ShapeStyle)` |
| `a8cc21f` | FolderSidebarView.swift | 浅色模式侧边栏灰色与内容区不协调 | 移除 `.environment(.dark)`，改用 `DS.Color.appBackground` |
| `ce79d8b` | ImagePreviewView.swift | 浅色模式导航箭头/按钮不可见 | 硬编码 `.white` 改为 `Color.primary` |
| `e8e7c54` | FolderSidebarView.swift | 浅色模式侧边栏行背景仍偏白 | `listRowBackground(DS.Color.appBackground)` |
| `39b87f8` | QuickViewerOverlay.swift | 浅色模式 QuickViewer 材质渲染为浅色，图标不可见 | 材质替换为 `Color(white:0,opacity:)` |
| `c6da6b5` | QuickViewerOverlay.swift | 工具栏双层深色叠加视觉割裂 | 减淡工具栏背景，移除按钮独立背景 |
| `9d185fb` | FolderSidebarView.swift | 侧边栏选中高亮被 `listRowBackground` 覆盖，无高亮 | 选中行改用 `accentColor.opacity(0.2)` |
| `aeca565` | ISeeImageViewerApp.swift | 默认窗口尺寸偏小 | `.defaultSize(width: 1280, height: 800)` |

---

## 手动验收检查

| 场景 | 期望结果 | 状态 |
|------|---------|------|
| 首次启动 | Toolbar 显示 `circle.lefthalf.filled` 图标；外观跟随系统 | ✅ |
| 选择「浅色」 | 主界面切换为浅色，QuickViewer 仍为深色 | ✅ |
| 选择「深色」 | 主界面切换为深色 | ✅ |
| 选择「跟随系统」 | 跟随 macOS 系统设置 | ✅ |
| 退出重启 | 上次选择的外观模式被恢复 | ✅ |
| 打开 QuickViewer | 无论全局外观，QuickViewer 始终深色，图标清晰可见 | ✅ |
| 当前选中项 | Menu 中对应项显示 ✓ | ✅ |
| 侧边栏选中 | 选中文件夹高亮（accentColor），深浅模式均正确 | ✅ |
