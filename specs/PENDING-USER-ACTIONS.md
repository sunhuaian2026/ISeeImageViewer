# PENDING User Actions

真机/GUI 验证清单。**不能自动化**的项累积在此，`/go` Step 3 追加，人工验证后从 Pending 移到 Done 并保留做历史记录。

## 格式

```
- [ ] (YYYY-MM-DD / <短 hash>) **类别**: 具体怎么测，要看到什么现象
```

类别：启动 / 排序 / QuickViewer / 全屏外观 / Inspector / 缩略图 / 侧边栏 / 其他

## 使用规则

- CC 在 `/go` Step 3 追加本次 `.swift` 改动可能影响的运行时项
- 不每次复制全清单 —— 只追加与本次改动**真正相关**的
- commit hash 先占位 `<pending>`，commit 完成后回填
- 人工测完在 Pending 前面打 `x`，把整行剪切到 Done 段
- Done 段保留所有历史（可追溯某次回归何时被验证过）

---

## Pending

（本段 CC 维护，追加新项。测完移到 Done。）

- [ ] (2026-04-27 / `<pending>` / followup) **架构**：把双 `.onTapGesture(count:1+2)` 替换为 `Button + .buttonStyle(.plain)` + 单一 action 互斥（codex 建议；macOS lazy 容器双 tap recognizer 有已知 edge case，独立改动避免 scope 失控）
- [ ] (2026-05-06 / `ab1fe89` / bugfix · v1.0.1) **dark 模式贴 macOS 系统配色 + 失焦响应**（partial — 待 v1.0.1 重新审）：原 commit ab1fe89 删 4 处 hardcoded background 想让系统 sidebar material 接管，实测 sidebar 上半 row 区域有 vibrancy + 漏壁纸色，但 row 之下空白区是深黑色 windowBackground（条纹感）。codex:rescue 给的 NSVisualEffectView 桥方案落地后引发**关于窗口居中回归**（具体因果链未定），同时颜色仍不一致，已 revert 回 ab1fe89 状态。**期望视觉**：app 切到 dark → 侧边栏整片跟 Finder/Mail/Notes 一致（vibrancy + 漏出桌面壁纸色 + 失焦自动褪色） + 内容区中性灰；侧边栏选中 / 未选中行视觉一致（无条纹）。**当前 ab1fe89 状态可接受作 v1.0**（条纹但不影响核心功能），下次审计走 SwiftUI ZStack vs NavigationSplitView column 行为 + 验证 codex 方案为何引发居中回归
- [ ] (2026-05-05 / `<pending>` / dist) **README 加下载入口**（依赖 v1.0.0 release 已创建，可立即回填 latest 链接）：项目 README 顶部加下载按钮（指 latest release）+ macOS 14+ 系统要求说明；首页带产品截图（grid / preview / QuickViewer / Inspector 各 1 张）
- [ ] (2026-05-05 / `<pending>` / dist · 可选 v1.0.1) **GitHub 仓库改名 ISeeImageViewer → Glance**：与 V1 发布解耦，发完 v1.0.0 后再做。改名后 GitHub 自动留旧路径 redirect，不影响已发链接

---

## Done

（本段追加完成条目，附完成日期。）

- [x] (2026-05-07 / `79fcfdf`) **F 键全局 · grid**：grid 模式 → 按 F → 窗口全屏（traffic lights 隐藏）；再按 F → 退出全屏 ✓ 2026-05-07
- [x] (2026-05-07 / `79fcfdf`) **F 键全局 · preview**：单击 cell 进 preview → 按 F → 窗口全屏；再按 F → 退出全屏 ✓ 2026-05-07
- [x] (2026-05-07 / `79fcfdf`) **F 键全局 · QV 回归**：双击 cell 进 QV → 按 F → 全屏；再按 F → 退出全屏（行为不变，跟修前一致） ✓ 2026-05-07
- [x] (2026-05-07 / `79fcfdf`) **F 键全局 · 不冲突其他快捷键**：grid 方向键/Space 仍正常；preview ESC/Space/方向键仍正常 ✓ 2026-05-07
- [x] (2026-05-07 / `02a36dc`) **Bug 4 扩展 · 路径 1 核心**：grid 双击 cell A 进 QV → 方向键到 Z → ESC 退 QV → grid highlight 跟到 Z（修前停在 A）✓ 2026-05-07
- [x] (2026-05-07 / `02a36dc`) **Bug 4 扩展 · 路径 2 preview 跟到 Z**：grid 单击 A 进 preview → 双击进 QV → QV 方向键到 Z → ESC 退 QV → preview 显示 Z（修前显示 A）✓ 2026-05-07
- [x] (2026-05-07 / `02a36dc`) **Bug 4 扩展 · 路径 2 grid highlight 跟到 Z**：续上 → 再 ESC 退 preview → grid highlight 跟到 Z ✓ 2026-05-07
- [x] (2026-05-07 / `3cdb991`) **QV colorScheme env · Path A 核心**：浅色模式 → grid → 直接双击 cell → QV (深色) → ESC 退 → sidebar 保持浅色，不再变深灰（修前 g1.png 现象）✓ 2026-05-07
- [x] (2026-05-07 / `3cdb991`) **QV colorScheme env · Path B 核心**：浅色模式 → grid → 单击 cell 进 preview → 双击 → QV (深色) → ESC 退 → 整个 app 保持浅色（preview / sidebar / 文件名 toolbar 全浅色，修前 g2.png 现象）✓ 2026-05-07
- [x] (2026-05-06 / `2b858cf`) **跟随系统外观模式生效**：菜单依次切「跟随系统」/「强制深色」/「强制浅色」/「跟随系统」 → 每次都立即生效；切「跟随系统」后系统切深浅 → app 跟着切；重启 app 保留上次模式选择；进 QuickViewer 仍强制深色（局部覆盖不受影响）✓ 2026-05-06
- [x] (2026-05-06 / `dcabffc`) **light 模式 chrome / 内容区对比**：切到 light 模式 → 内容区为纯白 (#FFFFFF) / 侧边栏为浅灰 (#F2F2F7)，对比方向跟 dark 模式一致（内容区是焦点更亮）；dark 模式视觉不变 ✓ 2026-05-06
- [x] (2026-05-06 / `20fa509`) **关于窗口跟随主窗口居中**（方案 2 真解 NSWindow，方案 1 e2e0d21 SwiftUI Window onAppear 有 A→B 跳跃已弃）：挪动主窗口到屏幕任意角落 → 菜单栏 → 关于一眼 → 关于窗口出现在主窗口中心，零跳跃；多次开关后位置仍跟随 ✓ 2026-05-06
- [x] (2026-04-23 / `68042e0`) **拖拽**：从 Finder 拖一个文件夹到侧边栏 → 出现在列表、自动选中、badge 正常、重启 app 后 bookmark 仍有效 ✓ 2026-04-23
- [x] (2026-04-23 / `68042e0`) **拖拽**：多选 2+ 文件夹一次拖入 → 全部加入；当前选中不变（不跳到新拖入的）✓ 2026-04-23
- [x] (2026-04-23 / `68042e0`) **拖拽**：拖一个已加过的文件夹 → 跳到选中它；`rootFolders` 不重复 ✓ 2026-04-23
- [x] (2026-04-23 / `68042e0`) **拖拽**：拖单张图片 / 文档文件（非目录）到侧边栏 → 静默无反馈（不出错、不加任何条目）✓ 2026-04-23
- [x] (2026-04-23 / `68042e0`) **拖拽**：拖拽悬停侧边栏时 → 紫色描边框可见；移出 → 平滑消失（约 150ms）✓ 2026-04-23
- [x] (2026-04-23 / `68042e0`) **拖拽**：拖到内容区（ImageGridView / ImagePreviewView）→ 无效（Finder 显示拒绝动画）✓ 2026-04-23
- [x] (2026-04-23 / `4f9fb18`) **QuickViewer**：大图（如手机照片 / 4K 截图）双击进入 → 缩到窗口约 90% 占比，四周留呼吸边（不再呆中间 30-40%）✓ 2026-04-25
- [x] (2026-04-23 / `4f9fb18`) **QuickViewer**：Retina 截图（如 macOS 原生截图 2x 像素）进入 → 同样约 90% 窗口占比，不再 39% 小块 ✓ 2026-04-25
- [x] (2026-04-23 / `4f9fb18`) **QuickViewer**：中等图（原生略小于窗口，如 1200×800）进入 → **显示 1:1 原生**（zoomPercent 100%），居中，不强拉伸 ✓ 2026-04-25
- [x] (2026-04-23 / `4f9fb18`) **QuickViewer**：小图 / 图标（如 64×64 favicon）进入 → 原生 1:1 居中显示（小块在中间），**不被拉伸变糊**；用户可滚轮 / 捏合主动放大 ✓ 2026-04-25
- [x] (2026-04-23 / `4f9fb18`) **QuickViewer**：双击图片 toggle → fit（90% 或 1:1）↔ 1:1（scale=1.0）切换流畅；1:1 时像素清晰 ✓ 2026-04-25
- [x] (2026-04-23 / `4f9fb18`) **QuickViewer**：放大到超出窗口 → 拖拽平移 / 滚轮缩放正常，边界不漏白（`clampOffset` 与新渲染对齐）✓ 2026-04-25
- [x] (2026-04-25 / `98573e9`) **QuickViewer 拖拽**：1:1 mode 下大图（超出窗口）→ 鼠标拖动图跟随移动，自然不抖动，能看到原本被裁掉的部分 ✓ 2026-04-25
- [x] (2026-04-25 / `98573e9`) **QuickViewer 拖拽**：拖到图边界 → 不漏白（clampOffset 兜底，图边贴窗口边停）✓ 2026-04-25
- [x] (2026-04-25 / `98573e9`) **QuickViewer 拖拽**：fit mode 图 ≤ 窗口 → 拖动无响应（canPan = false 正确，不应有抖动副作用）✓ 2026-04-25
- [x] (2026-04-25 / `98573e9`) **QuickViewer 拖拽**：双击 toggle fit ↔ 1:1 仍流畅；toggle 后再拖动行为仍正确 ✓ 2026-04-25
- [x] (2026-04-25 / `0e3ec10`) **QuickViewer 拖拽 y 方向**：鼠标向上拖 → 图向上移动；鼠标向下拖 → 图向下移动（修复 98573e9 后 y 方向反了的 follow-up）✓ 2026-04-25
- [x] (2026-04-25 / `4855e40`) **预览页**：选中文件夹 → 单击缩略图进入内嵌预览 → 按方向键 ←→ 连续切换 → 切换瞬间不应再出现 loading 转圈（首张可能仍转一下，第二张起命中预加载缓存即时显示）。**之前 868271d / c7a1533 都没修对，4855e40 才是根因修复（vm 提到 ContentView 跨 .id 重建持续）** ✓ 2026-04-25
- [x] (2026-04-25 / `4855e40`) **预览页**：单击进预览 → 双击进 QuickViewer → Esc 退回预览 → 再用方向键切换 → 仍无转圈（focus 恢复 + 缓存正常工作）✓ 2026-04-25
- [x] (2026-04-25 / `4855e40`) **预览页**：在预览中切换文件夹（侧边栏点另一个） → 不应崩溃；旧缓存清空（ContentView 的 onChange(of: selectedFolder) 触发 previewVM.clearCache），新文件夹预览正常 ✓ 2026-04-25
- [x] (2026-04-25 / `4855e40`) **预览页（回归验证）**：单击/双击/Esc/Space/← →/关闭按钮 全部行为不变；n/m 进度、青绿光晕、底部"双击图片进入全屏查看"提示文案、左右导航气泡按钮 视觉无差 ✓ 2026-04-25
- [x] (2026-04-25 / `4855e40`) **预览页（排序回归）**：进预览 → 切换排序顺序（toolbar 排序菜单） → 当前预览图片应仍是同一张（按 URL 重映射 currentIndex），不应跳到错的位置（验证 commit 175e82a 的修复仍生效）✓ 2026-04-25
- [x] (2026-04-27 / `fb6231c`) **AppIcon · Dock**：启动 app → Dock 显示新图标（眼睛 Cool Violet 方向，紫底青绿瞳孔），不再是 Xcode 默认占位 ✓ 2026-04-27
- [x] (2026-04-27 / `fb6231c`) **AppIcon · Finder column 16px**：在 Finder 用 column 视图看 Glance.app → 16px 缩略图下眼睛形状仍可辨认（不糊成色块）✓ 2026-04-27
- [x] (2026-04-27 / `fb6231c`) **AppIcon · Get Info**：右键 .app → 显示简介 → 左上角图标显示完整图标 + 大尺寸预览清晰 ✓ 2026-04-27
- [x] (2026-04-27 / `fb6231c`) **AppIcon · 浅色 Dock**：系统切到浅色模式 → Dock 里图标过渡仍 OK（紫底在浅色 Dock 上不应过黑过硬）✓ 2026-04-27
- [x] (2026-04-27 / `fb6231c`) **AppIcon · 关于本机**：app 菜单栏 → 关于 Glance（中文系统：关于一眼）→ 弹窗左侧大图标显示新图标 ✓ 2026-04-27
- [x] (2026-04-27 / `8e6de41`) **重命名 · Dock 中文系统**：系统语言中文 → Dock hover Glance.app 显示「一眼」 ✓ 2026-04-27
- [x] (2026-04-27 / `8e6de41`) **重命名 · Dock 英文系统**：系统语言切到英文 → Dock hover 显示 "Glance" ✓ 2026-04-27
- [x] (2026-04-27 / `8e6de41`) **重命名 · 活动监视器**：打开 Glance.app → 活动监视器进程列表显示 "Glance"（不再是 ISeeImageViewer）✓ 2026-04-27
- [x] (2026-04-27 / `8e6de41`) **重命名 · 顶部菜单栏**：app 运行时屏幕顶部菜单栏第一项显示「一眼」/ "Glance" ✓ 2026-04-27
- [x] (2026-04-27 / `8e6de41`) **重命名 · Bookmark 重新授权**：旧 ISeeImageViewer 的 bookmark 已失效（Bundle ID 改了），重新拖文件夹进侧边栏可正常授权浏览 ✓ 2026-04-27
- [x] (2026-04-27 / `c112059`) **缩略图**：含同名不同后缀文件夹（如 4.jpg + 4.png）→ 点击各 cell（含相邻同基名两张）→ 视觉点的就是预览出的，多次切换不漂移 ✓ 2026-05-04
- [x] (2026-04-27 / `c112059`) **排序**：切换排序后再点缩略图 → 视觉与预览一致（之前 ScrollView `.id(sortKey-direction)` 强制重建已删，要确认 LazyVGrid 自身能正确响应数组重排）✓ 2026-05-04
- [x] (2026-05-04 / `44ba6ee`) **缩略图 · 双击 highlight 跟随**：先单击 cell A（highlight 在 A）→ 双击 cell B 进 QuickViewer → ESC 退 QuickViewer → highlight 应**已在 B** ✓ 2026-05-04
- [x] (2026-05-04 / `44ba6ee`) **缩略图 · 上下方向键步长**：刚启动选中文件夹后不碰任何 cell，按 ↓ 高亮第二行同列 cell；按 ↑ 反之；Inspector 开关后步长仍正确 ✓ 2026-05-04
- [x] (2026-05-04 / `44ba6ee`) **缩略图 · 上下方向键边界**：↑ 到第一行后再 ↑ 停在最左 cell；↓ 到最后一行后再 ↓ 停在最末 cell ✓ 2026-05-04
- [x] (2026-05-04 / `5b29600`) **缩略图 · ESC 后焦点恢复（Y-1）**：单击 cell A 进 preview → ESC → 按方向键 highlight 在 grid 内正常移动 ✓ 2026-05-04
- [x] (2026-05-04 / `5b29600`) **缩略图 · ESC 后焦点恢复（Y-2）**：同上链路反复测试不再"反而弹出下一张预览" ✓ 2026-05-04
- [x] (2026-05-04 / `5b29600`) **缩略图 · ESC 后 Space**：单击 cell A 进 preview → ESC → Space → 进 QuickViewer 显示 highlight 那张 ✓ 2026-05-04
- [x] (2026-05-04 / `5b29600`) **预览页 · ESC 退出回归**：preview 内 ←→ / Space / 双击 / 关闭按钮 全部正常 ✓ 2026-05-04
- [x] (2026-05-04 / `59a9d86`) **缩略图 · QV dismiss 后 grid 焦点（核心 case）**：单击 → preview → ESC → Space → QV → ESC → Space / 方向键正常 ✓ 2026-05-04
- [x] (2026-05-04 / `59a9d86`) **缩略图 · grid 直接双击进 QV 后 ESC**：直接双击 → QV → ESC → 方向键 / Space 正常 ✓ 2026-05-04
- [x] (2026-05-04 / `59a9d86`) **预览 → QV → preview 路径**：单击 → preview → 双击图片 → QV → ESC → 回 preview，方向键切预览图正常 ✓ 2026-05-04
- [x] (2026-05-04 / `59a9d86`) **切换文件夹强制关 QV**：QV 中点侧边栏另一文件夹 → QV 自动关，焦点不崩 ✓ 2026-05-04
- [x] (2026-05-04 / `59a9d86`) **ImagePreviewView 关闭按钮回归**：单击进 preview → 点左上 X → 退回 grid → 方向键 / Space 正常 ✓ 2026-05-04
- [x] (2026-05-05 / `09c418c`) **自定义关于面板 · 无 focus ring 残留**：点击 contact 行 → 复制 + toast → 该行无 accent color 细描边 / focus ring 残留 ✓ 2026-05-05
- [x] (2026-05-04 / `fb7f900`) **QuickViewer filmstrip · 点击命中**：点 cell A → 高亮 + 主图都跳到 A，不漂移；多位置反复测过 ✓ 2026-05-05
- [x] (2026-05-04 / `fb7f900`) **QuickViewer filmstrip · scrollTo 跟随**：方向键切图 filmstrip 自动滚到当前 cell 居中 ✓ 2026-05-05
- [x] (2026-05-04 / `fb7f900`) **QuickViewer filmstrip · 缩略图加载**：快切 ←→ 缩略图不错位（.task(id:) + cancel guard 工作）✓ 2026-05-05
- [x] (2026-05-04 / `38adfd4`) **关于面板版本号注入**：版本号显示 commit hash 格式，多次 build 递变 ✓ 2026-05-05
- [x] (2026-05-04 / `38adfd4`) **BuildInfo.txt sidecar 同步**：`cat ~/sync/Glance.app.BuildInfo.txt` 7 字段齐全 ✓ 2026-05-05
- [x] (2026-05-05 / `8f927d1`) **自定义关于面板 · 弹窗触发**：菜单触发自定义窗口（非系统 NSAboutPanel），AppIcon / 名称 / 版本号 / 两行 contact 完整 ✓ 2026-05-05
- [x] (2026-05-05 / `8f927d1`) **自定义关于面板 · 点击复制 + toast**：hover 手指 cursor / 点击复制 / toast / ⌘V 粘贴验证 ✓ 2026-05-05
- [x] (2026-05-05 / `8f927d1`) **自定义关于面板 · 版本号动态读取**：关于窗口版本号字符串与 BuildInfo.txt version 字段一致 ✓ 2026-05-05
- [x] (2026-05-05 / `bd25fd0`) **关于面板 Copyright 字段**（历史，已被 8f927d1 自定义 about panel 取代）：标准面板 wrap 点不雅观（"小红书"和"382336617"被自动拆两行），升级到自定义 panel ✓ 2026-05-05
- [x] (2026-05-07 / `086ade2`) **Inspector · dark 模式开关边线同步**：dark 模式下按 ⌘I 开/关 Inspector → 边线随 Inspector 同步滑入/滑出，无粉色闪现/不"提前到位"/不延迟/不残留 ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **Inspector · light 模式开关边线同步**：light 模式同上行为正常，边线为浅黑半透明 #000 0.08 ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **Inspector · 切文件夹/取消选图自动关 Inspector**：切文件夹 / Esc 退选图 → Inspector 自动关 + 边线同步消失，无残留 ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **Inspector · 内容回归**：文件名/尺寸/EXIF/相机参数/GPS 字段不变；isLoading spinner 行为不变；切图 Form 内容跟着更新；ContentUnavailableView 文案不变 ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **focus ring · 真根因修法核心验证**：系统强调色粉色 → 启动 app → 单击进 ImagePreviewView → 整个 app 无粉色框；⌘I 开 Inspector → preview 右缘 + Inspector 间无粉色长条；失焦再聚焦 → 无"刚回来粉色框闪一下" ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **focus ring · ImageGridView 同步禁用**：grid 模式无图片选中 → grid 区域无粉色 focus ring；紫色 highlightedURL 圆角矩形仍正常 ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **focus ring · QuickViewerOverlay 同步禁用**：QV overlay 无粉色 focus ring；强制深色 overlay 自定义 UI（顶栏 / nav / filmstrip）视觉不变 ✓ 2026-05-08
- [x] (2026-05-07 / `086ade2`) **focus ring · 键盘功能回归**：grid 方向键 / preview 方向键 / preview Esc / preview Space / QV 方向键 / QV Esc 全正常；切文件夹 / 切预览图 onAppear 焦点路由仍生效 ✓ 2026-05-08
- [x] (2026-05-07 / `c0c833a`) **toolbar background hidden · 核心**（真解 v2，e39fbbf v1 已废）：单击 cell 进 ImagePreviewView → 顶部无浅灰横条，文件名 + ⓘ + 外观切换按钮直接坐在 NSWindow title bar ✓ 2026-05-08
- [x] (2026-05-07 / `c0c833a`) **toolbar background hidden · 进出 QV 回归**：双击进 QV → ESC → 再单击进 preview → 仍无浅灰横条 ✓ 2026-05-08
- [x] (2026-05-07 / `c0c833a`) **toolbar background hidden · sidebar 列**：左上 `+` 按钮 + sidebar toggle 视觉位置/间距不变 ✓ 2026-05-08
- [x] (2026-05-07 / `c0c833a`) **toolbar background hidden · Traffic light 回归**：进 QV 隐藏 / 退 QV 恢复行为不变（a064033 / 45a61f1 / 6da903c 历史区域）✓ 2026-05-08
- [x] (2026-05-07 / `c0c833a`) **toolbar background hidden · 外观切换**：浅色 / 深色 / 跟随系统切换 → toolbar 视觉跟切，无残留 ✓ 2026-05-08
- [x] (2026-05-07 / `3cdb991`) **QV colorScheme env · QV 视觉回归**：QV 内顶栏 / nav / filmstrip / 关闭按钮 / 缩放比例 / n/m 仍深色，视觉跟修前一致 ✓ 2026-05-08
- [x] (2026-05-07 / `3cdb991`) **QV colorScheme env · AppearanceMode 切换回归**：浅 / 深 / 跟随系统切换立即生效；QV 进出后切换仍即时；进 QV 前后切换外观无干扰 ✓ 2026-05-08
- [x] (2026-05-07 / `3cdb991`) **QV colorScheme env · 深色模式回归**：深色模式 → 进出 QV → 主 app 保持深色（无误浅化）✓ 2026-05-08
- [x] (2026-05-07 / `b44a175`) **Bug 4 · 核心**：grid 单击 1.png → preview → 方向键到 5.png → ESC → grid 紫色高亮跟到 5.png（修前停在 1.png）✓ 2026-05-08
- [x] (2026-05-07 / `b44a175`) **Bug 4 · 双击 → QV 路径回归**（44ba6ee 区域）：grid 单击 A → highlight=A → 双击 B → QV → ESC → highlight=B（不变，跟修前一致）✓ 2026-05-08
- [x] (2026-05-07 / `b44a175`) **Bug 4 · 排序回归**：grid 切排序 → highlight 自动清空（onChange of: images）→ 再单击/方向键正常；preview 内切排序仍显示同图（175e82a 行为不变）✓ 2026-05-08
- [x] (2026-05-07 / `b44a175`) **Bug 4 · 焦点 race 回归**（5b29600 / 59a9d86 区域）：单击 → preview → ESC → grid 方向键正常；单击 → preview → 双击 → QV → ESC → grid 方向键正常 ✓ 2026-05-08
- [x] (2026-05-07 / `02a36dc`) **Bug 4 扩展 · 6da903c 回归**（最关键）：grid 双击 A 进 QV → 不动方向键 → ESC → 回 grid 不进 preview（保 6da903c 行为）✓ 2026-05-08
- [x] (2026-05-07 / `02a36dc`) **Bug 4 扩展 · QV 三渠道全覆盖**：QV 内方向键 / nav button / filmstrip tap 切到 Z → ESC → 三种方式都让 highlight/preview 同步 Z（codex 标盲点 1）✓ 2026-05-08
- [x] (2026-05-05 / `0c9f699`) **部署目标降级回归**：装 `~/sync/Glance.app` 跑 7 路径（启动 / 拖文件夹 / 单击进 preview + 方向键 / 双击进 QV 缩放拖拽 / 全屏 F 键 / 排序菜单 / 关于面板点击复制 + toast），macOS 部署目标 26.2 → 14.0 未破坏现有功能 ✓ 2026-05-08
- [x] (2026-05-05 / `0c9f699`) **notarytool keychain profile 配置**（一次性，5/5 配过 + 5/7 ACL 丢后重存）：App-specific password 生成 → `xcrun notarytool store-credentials "glance-notary"` → `xcrun notarytool history` 验证无报错 ✓ 2026-05-07
- [x] (2026-05-05 / `0c9f699`) **完整 release 流程跑通**：`make release` 真跑成功（archive + Developer ID 签 + create-dmg + notarize Accepted + stapler staple）；产物 `dist/Glance-1.0.0.dmg` 2.4 MB universal binary，公证 Submission ID `cb7db74c-afbb-4e12-98a5-912ca15eefff` Accepted ✓ 2026-05-07
- [x] (2026-05-05 / `0c9f699`) **DMG Gatekeeper 干净 Mac 实测**：DMG 拷到非签名机 Mac → 双击挂载 → 拖到 Applications → 双击启动 → 直接打开，无 Gatekeeper 警告 ✓ 2026-05-08
- [x] (2026-05-05 / `d2263d9`) **GitHub 仓库改 public**（不可逆）：`gh repo edit sunhuaian2026/ISeeImageViewer --visibility public --accept-visibility-change-consequences` 执行成功；`gh repo view` 返回 `visibility: PUBLIC, isPrivate: false`；匿名 HTTP 200 ✓ 2026-05-08
- [x] (2026-05-05 / `0c9f699`) **GitHub Release v1.0.0 创建**（不可逆）：`gh release create v1.0.0 dist/Glance-1.0.0.dmg dist/Glance-1.0.0.dmg.sha256 --target 0c9f6993... --title "Glance 1.0.0 · 一眼" --notes-file docs/release-notes/v1.0.0.md` 执行成功；release URL https://github.com/sunhuaian2026/ISeeImageViewer/releases/tag/v1.0.0；DMG 匿名下载 HTTP 200 + content-length 2516359 ✓ 2026-05-08
