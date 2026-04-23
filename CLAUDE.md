这是一个 macOS 本地看图 app，SwiftUI 开发。
核心功能是本地文件夹浏览和图片查看。
需要遵守 App Sandbox 限制，使用 Security Scoped Bookmark 处理文件权限。

---

## 项目文件结构

```
ISeeImageViewer/
├── CLAUDE.md                        ← 本文件（开发规范 + 上下文）
├── Makefile                         ← make build / make run / make clean
├── ISeeImageViewer.xcodeproj/
├── specs/                           ← 所有模块规范文档
│   ├── UI.md                        ← UI 设计规范（唯一来源），含颜色自适应方案
│   ├── Roadmap.md                   ← 总体进度与 TODO
│   ├── AppState.md                  ← ✅ 全屏 + 外观模式（AppState / WindowAccessor）
│   ├── BookmarkManager.md           ← ✅ 已完成
│   ├── FolderStore.md               ← ✅ 已完成
│   ├── FolderBrowserView.md         ← ✅ 已完成
│   ├── QuickViewer.md               ← ✅ 已完成
│   ├── SortFilter.md                ← ✅ 已完成
│   ├── KeyboardShortcuts.md         ← ✅ 已完成
│   ├── Inspector.md                 ← ✅ 已完成
│   ├── TrafficLightHide.md          ← ✅ 已完成
│   ├── ThumbnailSizeSlider.md       ← ✅ 已完成
│   └── Prefetch.md                  ← 待开发
├── docs/
│   └── archive/                     ← 已归档的历史规范文档
│       ├── UIRefresh.md             ← 已归档
│       ├── FullScreen.md            ← 已归档（内容合并入 AppState.md）
│       ├── ImageViewerView.md       ← 已归档（已被 QuickViewer 替代）
│       ├── 2026-03-24-appearance-mode-design.md  ← 已归档（合并入 AppState.md + UI.md）
│       └── 2026-03-24-appearance-mode-plan.md    ← 已归档（实施记录）
└── ISeeImageViewer/                 ← Swift 源码（PBXFileSystemSynchronizedRootGroup，新文件自动加入编译）
    ├── ISeeImageViewerApp.swift      ← App 入口，注入 BookmarkManager / FolderStore / AppState
    ├── ContentView.swift            ← NavigationSplitView + 内嵌预览/QuickViewer 覆盖层
    ├── DesignSystem.swift           ← DS.Spacing / DS.Color / DS.Anim 等所有 UI 常量
    ├── BookmarkManager.swift
    ├── FolderBrowser/
    │   ├── FolderStore.swift        ← 状态管理（FolderNode 树形结构、图片列表、排序）
    │   ├── FolderSidebarView.swift  ← 侧边栏（树形展开/折叠、badge、右键菜单）
    │   └── ImageGridView.swift      ← 缩略图网格 + ThumbnailCell + loadThumbnail()
    ├── ImageViewer/
    │   └── ImagePreviewView.swift   ← 单击后内嵌预览（简单展示，双击触发 QuickViewer）
    ├── QuickViewer/
    │   ├── QuickViewerViewModel.swift  ← ZoomMode + 缩放/导航逻辑
    │   ├── ZoomScrollView.swift        ← NSViewRepresentable（滚轮/双击/拖拽）
    │   └── QuickViewerOverlay.swift    ← 全窗口覆盖层（TopBar + NavButtons + BottomToolbar + Filmstrip）
    ├── Inspector/
    │   ├── ImageInspectorViewModel.swift  ← ImageInfo struct + EXIF 读取
    │   └── ImageInspectorView.swift       ← Form + Section 布局
    └── FullScreen/
        ├── AppState.swift           ← isFullScreen + appearanceMode 状态 + toggleFullScreen()
        └── WindowAccessor.swift     ← NSViewRepresentable，获取 NSWindow + NSWindowDelegate
```

---

## 开发规范

- 所有模块开发前必须有对应的 specs/ 文件。
- **新开 session 第一步**：读取 CLAUDE.md + specs/Roadmap.md 恢复上下文。
- 开发环境为远程 Mac，无法使用 Xcode GUI。所有编译和验证使用命令行。
- 构建命令：`make build`（在 ISeeImageViewer/ 目录下）
- 运行命令：`make run`
- 清理命令：`make clean`

## UI 规范

- **所有 UI 常量必须引用 DesignSystem.swift（DS.*）**，禁止硬编码颜色、间距、动画。
- 详细规范见 specs/UI.md。
- 核心原则：内容优先、克制、原生、深色优先。
- `QuickViewerOverlay`（全窗口看图）强制深色（`.preferredColorScheme(.dark)`）；`ImagePreviewView`（内嵌预览）跟随全局外观，前景色使用 `Color.primary`。
- 禁止在看图界面使用 `.spring` 动画，用 `DS.Anim.normal / fast`。

## 持久化规范

- 每次计划生成后，立刻将计划追加到对应的 specs/[模块名].md 的「实现步骤」章节。
- 每个模块完成后立刻 git commit，commit message 格式：「完成 [模块名]」，然后执行 `git push` 同步到 GitHub（remote: git@github.com:sunhuaian2026/ISeeImageViewer.git）。
- **模块完成后必须同步更新文档**：
  1. 更新 specs/[模块名].md 里的「当前进度：第 X 步已完成」
  2. 更新 specs/Roadmap.md：将该模块移入「已完成」表格，标注 commit hash
  3. 如涉及新文件或目录，同步更新 CLAUDE.md 的文件结构
- xcodeproj 使用 PBXFileSystemSynchronizedRootGroup，在 ISeeImageViewer/ 目录下新建 .swift 文件会自动被编译，无需手改 xcodeproj。

## ⚠️ 文档同步强制规则（每次必须执行，不得跳过）

### 禁止单独提交代码

**代码变更和文档更新必须在同一个 commit 里。不允许先提交代码、事后补文档。**

git commit 前的强制 checklist，逐条检查，全部通过才能提交：

| 变更类型 | 必须更新的文档 |
|---------|-------------|
| Bug fix | `specs/Roadmap.md` Bug Fix 记录（含 commit hash、文件、问题、修复方式） |
| 新增/删除/移动文件 | `CLAUDE.md` 文件结构 |
| 完成模块或子功能 | 对应 `specs/[模块名].md` 的「当前进度」 |
| 模块进入已完成 | `specs/Roadmap.md` 已完成表格（含 commit hash） |
| 架构或交互逻辑变化 | `specs/Roadmap.md` 关键架构决策 |

**判断标准：任何让"下一个 session 读文档会产生误解"的变更，都必须同步更新文档。**

## 验证与 Review 规范

- 每个模块实现完成后，必须先执行 `make build`，确认零错误零警告再提交。
- 编译通过后，对照 specs/[模块名].md 逐条检查接口和边界条件是否都已实现。
- 发现与 spec 不符的地方，先修复再 commit，不允许带问题提交。
- 每次 commit 前做一次自我 review：检查有没有硬编码、未处理的错误、遗漏的边界条件。

### 任务收尾：`/go` 五步

任务涉及 `.swift` 改动时，收尾前必须跑 `/go`（定义在 `.claude/commands/go.md`）。纯文档 / scripts / specs 改动 → 跳 Step 1，commit message 末尾加 `[docs-only]`。

`/go` 五步：

1. **三段式 verify**（`./scripts/verify.sh`，成本递增、遇红即停）：
   - Stage 1 静态规则（ms）：grep/awk + 文档同步 + git hygiene
   - Stage 2 编译（30-60s）：`xcodebuild build -quiet`，0 error 才过；warning 非阻塞但必须修
   - Stage 3 单测（暂 skip，项目无 XCTest target）
   - 红 → 修 → 重跑，**最多 5 轮**。5 轮仍红就停下来问用户
2. **文档同步**：对照 `.swift` diff 按「⚠️ 文档同步强制规则」补 Roadmap / CLAUDE.md / specs/<module>.md
3. **PENDING 人工清单**：追加到 `specs/PENDING-USER-ACTIONS.md`（durable 文件，入库累积），只加本次改动相关项
4. **commit + push**：`git add` 逐文件明确；push 触发 pre-push hook 做第二道 codex 评审
5. **一段话汇报**：**第一行必须独立显示编译结果**（`BUILD SUCCEEDED — 0 errors, 0 code warnings`），不得仅用 verify 的汇总数字替代；其后 self-fix 几轮 / 文档动了啥 / PENDING 加几项 / commit hash / hook 结果

可选 `./scripts/verify.sh --with-codex` 在 verify 后追加 codex 全项目审查（跨 3+ 模块或架构重构时才跑）。

`make verify` / `make verify-codex` 便捷入口。完整 log 留 `.verify-logs/`（gitignored）。

## Pre-Push Codex Review Hook

`.githooks/pre-push` 在 `git push` 时调用 codex（read-only sandbox + high reasoning）审查待推 diff（`.swift` + `*.md`），发现 `[P1]` 阻塞 push，`[P2]` 仅告警。

**安装一次**：`make hooks-install`（设 `core.hooksPath=.githooks`）

**绕过方式**：
- 单次紧急：`git push --no-verify`
- 本次 session：`SKIP_CODEX_REVIEW=1 git push`
- 按 commit 跳过：commit message 含 `[skip-codex]` 或 `[wip]`

**规则覆盖**（见 `.githooks/pre-push` 的 PROMPT）：通用代码规则 + UI 硬编码/DS.* / `.spring` 禁用 / QuickViewerOverlay 深色 / 文档同步硬规则。

**缓存**：通过的 `local_sha` 写入 `.git/codex-reviewed-<sha>`，retry 不重复审。
