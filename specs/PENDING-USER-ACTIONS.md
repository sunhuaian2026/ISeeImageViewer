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

*空 — 等待 `/go` Step 3 或人工追加*

---

## Done

（本段追加完成条目，附完成日期。）

*空*
