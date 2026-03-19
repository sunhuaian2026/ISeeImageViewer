这是一个 macOS 本地看图 app，SwiftUI 开发，目标上架 App Store。
核心功能是本地文件夹浏览和图片查看。
需要遵守 App Sandbox 限制，使用 Security Scoped Bookmark 处理文件权限。

开发规范：
- 所有模块开发前必须有对应的 specs/ 文件。
- 开发环境为远程 Mac，无法使用 Xcode GUI。所有编译和验证必须使用命令行（xcodebuild），不依赖 Xcode 界面操作。
- 编译命令示例：xcodebuild -project ISeeImageViewer.xcodeproj -scheme ISeeImageViewer -configuration Debug build
- 测试命令示例：xcodebuild test -project ISeeImageViewer.xcodeproj -scheme ISeeImageViewer -destination 'platform=macOS'

持久化规范：
- 每次 /plan 生成计划后，立刻将计划追加到对应的 specs/[模块名].md 的「实现步骤」章节。
- 每个模块完成后立刻 git commit，commit message 格式：「完成 [模块名]」。
- 每次 session 结束前，更新 specs/[模块名].md 里的「当前进度：第 X 步已完成」。
- 每次新开 session，第一步读取 CLAUDE.md 和对应的 specs/[模块名].md 恢复上下文。

验证与 Review 规范：
- 每个模块实现完成后，必须先执行编译验证，确认零错误零警告再提交。
- 编译通过后，对照 specs/[模块名].md 逐条检查接口和边界条件是否都已实现。
- 发现与 spec 不符的地方，先修复再 commit，不允许带问题提交。
- 每次 commit 前做一次自我 review：检查有没有硬编码、未处理的错误、遗漏的边界条件。
