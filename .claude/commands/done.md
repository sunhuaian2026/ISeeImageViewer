---
description: 会话收尾 4 步 — 沉淀闭环 audit / /go 闭环 audit / 状态汇报 / 心智 handoff
---

会话结束时跑。4 步依次执行，每步 gate 行为明确。**本命令不 commit / 不 push** —— 如果 Step 1/2 audit 出有补救动作，要先 user 同意才执行。

整体哲学：本项目沉淀机制（Roadmap / PENDING / CLAUDE.md / `/go`）已嵌入 daily workflow，本命令做**闭环 audit + 心智 handoff**，不是从零写沉淀。

---

## Step 1: 沉淀闭环 audit（Claude 自动判断 + 报告，user 校准）

确定本会话 commit 范围：从对话状态推断（对话开始时的 git log vs 当前），不靠 `@{u}..HEAD`（本 session 已 push 时该范围会是空）。

```bash
# 收集本会话 commit
git log --oneline <session-start-hash>..HEAD
git diff --stat <session-start-hash>..HEAD
```

按 4 类触发逐项判断（每项 **✅ 已落 / ⚠️ 未落 / ❓ 不确定**）：

| # | 触发 | 判依据 | 应落文件 |
|---|---|---|---|
| (a) | 新术语 | git diff 引入新概念词 / 对话提及"以后这个叫 X" | `CONTEXT.md` 术语段 |
| (b) | 不可逆决策 | 拍板 trade-off / 架构选择 / 范围 freeze | `specs/Roadmap.md` 关键架构决策段 / V2 决策段 |
| (c) | 文件结构变 | git diff `Glance/` 新增/删除/移动 `.swift` | `CLAUDE.md` 文件结构段 |
| (d) | bug fix | commit message 含"修 / fix" / 修复 bug | `specs/Roadmap.md` Bug Fix 记录段 |

输出格式：

```
## Step 1: 沉淀闭环 audit

本会话 commit 范围: <start-hash>..<HEAD>（共 N 个 commit）

(a) 新术语 X 项:
  - <术语>: 在 CONTEXT.md 的 ✅ / ⚠️ 缺失 / ❓ 不确定
(b) 不可逆决策 X 项:
  - <决策>: 在 Roadmap 的 ✅ / ⚠️ / ❓
(c) 文件结构变 X 项:
  - <文件>: CLAUDE.md 文件结构段 ✅ / ⚠️ / ❓
(d) bug fix X 项:
  - <commit-hash> <commit-title>: Bug Fix 段 ✅ / ⚠️ / ❓

总评: 全闭环 ✅ / 有 N 项 ⚠️ 待补 / 有 N 项 ❓ 待校准
```

**Gate**：
- 全 ✅ → auto 进 Step 2
- 有 ⚠️ / ❓ → **wait user**：等用户回 "补 / 跳过 / 你判错了" 决定每项

---

## Step 2: /go 闭环 audit（严标准）

```bash
# 本会话最近 .swift 改动
git log --oneline <session-start-hash>..HEAD -- '*.swift'

# 最近 verify.sh 跑过的状态
ls -lt .verify-logs/ 2>/dev/null | head -3
```

判断（**每条都打勾才算走完**）：

| 维度 | 判依据 |
|---|---|
| 1. 本会话有 `.swift` 改动？ | 上面 git log 是否非空 |
| 2. 最后一次 `.swift` commit 后有 verify.sh ✅？ | `.verify-logs/` 时间戳 > 最后 .swift commit time，且 result 是 pass |
| 3. 文档同步过？ | CLAUDE.md / Roadmap.md 在范围内有 commit |
| 4. PENDING 加项？ | specs/PENDING-USER-ACTIONS.md 在范围内有 commit（如适用） |
| 5. push 走过 hook？ | git log 显示已 push（`@{u}..HEAD` 为空）+ 推断 hook 状态 |

输出：

```
## Step 2: /go 闭环 audit

本会话 .swift 改动: 是 (N 个 commit) / 否 (纯 docs)

[如有 .swift 改动]
1. .swift 改动 ✓
2. verify.sh 在 commit <last-swift-hash> 之后 跑过 ✅ / ⚠️ 没跑 / ❓ 不确定
3. 文档同步 commit 在范围内 ✅ / ⚠️
4. PENDING 加项 commit 在范围内 ✅ / ⚠️ / 不适用
5. push 已发 ✅ / ⚠️ 本地领先

总评: 走完 ✅ / 待补 ⚠️（缺 X / Y）/ 不适用（纯 docs）
```

**Gate**：
- ✅ / 不适用 → auto 进 Step 3
- ⚠️ → **wait user**：等用户回 "现在补 / 推迟到下次"

---

## Step 3: 同步状态汇报（auto-proceed）

```bash
git status -sb
git log --oneline -5
git rev-parse --short HEAD
git rev-parse --short @{u}
ls -lt .verify-logs/ 2>/dev/null | head -2
```

固定信息块输出：

```
## Step 3: 同步状态汇报

=== 项目: Glance / branch: <branch> / <date> ===

HEAD       <short>
origin     <short>（同步 ✓ / 领先 N / 落后 N）
工作树     干净 ✓ / 修改 N 个文件
verify.sh  最近一次 <X passed / Y failed>（<相对时间>）
pre-push   skipped ([wip] in range) / reviewed (P1 N / P2 N) / 未触发

最近 5 个 commit:
- <hash> <title>
- ...

待用户拍板（来源 1: PENDING 当前段 unchecked / 来源 2: 本对话尾部悬未决）:
- (具体项 1)
- (具体项 2)
```

**待用户拍板** 来源说明：
- **来源 1**：扫 `specs/PENDING-USER-ACTIONS.md` Pending 段，列**最近添加** + 用户没明确测过的 unchecked 项（不是全部 unchecked）
- **来源 2**：扫**最近 20 条对话**，找用户问了但 Claude 没答 / Claude 提了选项但用户没拍板的具体问题

---

## Step 4: next-session 心智 handoff（auto-proceed）

**核心**：聚焦 git log + 静态 docs **不会记录** 的"心智状态"。固定 4 段：

```
## Step 4: next-session prompt

=== Glance / branch <branch> / <date> ===

[当前 slice / issue]
（具体进度 + ship-able 状态。如 "V2 M1 Slice A 完成 (V2.0-beta1 ship-able)，Slice B plan 已输出待执行"）

[上次结束位置]
（最后做了什么具体动作，stop 在哪里。如 "Slice B plan 5 task + 5 决策点输出完，等用户拍板 + go"）

[下一步]
（下次开机第一步具体动作。如 "你回决策点 1-5 → 我说 go → 进 Slice B B.1 实施"）

[待你拍板]（来自 Step 3 来源 2 + 本会话明确开放的决策点）
- 具体决策项 1（含选项 + 我推荐）
- 具体决策项 2
- ...

[我心里想但没说]（最多 1-3 条高 priority）
- 隐性 trade-off / 备选方案 / 我犹豫的关键点（**简，不是 down-rank PENDING followup 项**）
```

"我心里想但没说" **简标准**：只列 1-3 条**最重要**的、下次开机必须重读的 trade-off / 隐性想法。次要的 down-rank 进 PENDING followup，**不在这里展开**。

---

## 整体规则

- 任一步出错 / user 说停 → 立即停下
- 不 commit / 不 push（Step 1/2 如有补救动作，先 user 同意才执行）
- Step 1 / Step 2 用 ⚠️ ❓ gate；Step 3 / Step 4 直接 auto 输出
- 输出尽量简洁，模板填具体内容，不重复模板说明
