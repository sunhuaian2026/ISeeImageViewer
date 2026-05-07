# Glance · 一眼

> 简洁、克制、专注内容的 macOS 本地看图 app

[![macOS 14+](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/sonoma/) [![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-green.svg)](https://www.apple.com/mac/) [![Notarized](https://img.shields.io/badge/Apple-Notarized-success.svg)](#)

**[⬇ 下载 v1.0.0](https://github.com/sunhuaian2026/ISeeImageViewer/releases/latest)** · 邮箱 `16414766@qq.com` · 小红书 `382336617`

<!-- TODO: 在这里放 4 张产品截图：grid / preview / QuickViewer / Inspector -->

---

## 主要功能

- **本地文件夹浏览** — 拖文件夹到侧边栏自动加入，构建子文件夹树 + 图片数 badge
- **沉浸式看图** — 双击进 QuickViewer 全窗口查看，缩放/拖拽/方向键零延迟切换
- **缩略图网格** — Toolbar 滑块调尺寸（80~280pt），6 种排序
- **EXIF Inspector** — 相机参数 / 拍摄时间 / GPS（⌘I 切换）
- **键盘快捷键** — Space / ESC / 方向键 / `F` 全屏
- **深浅外观自适应** — 跟随系统 / 强制深色 / 强制浅色，UserDefaults 持久化
- **中英双语** — 中文系统显示「一眼」，英文系统显示 "Glance"

## 系统要求

- macOS **14.0 (Sonoma)** 或更新
- Apple Silicon (M1 / M2 / M3 / M4) 或 Intel Mac (x86_64) — **universal binary**，同一个 DMG 自动适配

## 安装

下载 [latest release](https://github.com/sunhuaian2026/ISeeImageViewer/releases/latest) 的 DMG → 双击 → 拖 `Glance.app` 到 `Applications` → Launchpad / Spotlight 启动。

✅ 已通过 Apple 公证（Notarization），双击直接打开，不弹任何 Gatekeeper 警告。

## 数据安全 & 隐私

- App Sandbox 沙盒（用户主动授权才能读取文件夹）
- Apple Developer ID 签名 + 公证 + Hardened Runtime
- Security Scoped Bookmark 持久授权（重启 app 后自动恢复）
- **零网络请求 / 零数据上传 / 零遥测**

## 开发

```bash
make build          # Debug 编译
make run            # build + 启动
make verify         # 三段式验证（静态规则 + xcodebuild + 单测）
make release        # 公开分发包（Release + Developer ID 签 + Hardened Runtime + create-dmg + 公证 + staple）
make release-dry    # 同上但跳过公证（本地干跑验证签名 + DMG 流程）
```

详见 [`CLAUDE.md`](CLAUDE.md) 与 [`specs/Roadmap.md`](specs/Roadmap.md)。

## 反馈与贡献

- 🐛 Bug / 功能建议 → [GitHub Issues](https://github.com/sunhuaian2026/ISeeImageViewer/issues)
- 📧 邮箱：16414766@qq.com
- 📕 小红书：**382336617**

## License

[MIT](LICENSE) © 2026 Hongjun Sun (孙红军)

---

Built with SwiftUI · 2026 © 孙红军
