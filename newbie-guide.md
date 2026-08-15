# 新人开发上手指南 — sie-smom

> 适用人群：第一次接触本 skill 仓库的 SMOM 平台开发者。预计阅读 5 分钟，读完即可开始使用。

---

## 这个仓库是什么（30 秒版）

这是一个 Claude Code Skill，给 AI 装上后，它能帮你写赛意 SMOM 平台（.NET 6.0 MES + SIE 自研框架）的代码。

**核心思想**：AI 写 SMOM 代码前先查参考底库（16 份精炼规则），**不臆造框架 API**——找不到就明说「需查证」，绝不编造。

## 一、安装（5 分钟，一次性）

### 方式 1：Claude Code 插件市场（推荐）

```bash
/plugin marketplace add SIE-Operations-and-Maintenance-Team/sie-smom
/plugin install sie-smom@sie-smom
```

### 方式 2：cc-switch / 手动克隆

在 cc-switch 中添加仓库 `https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom`；或手动 `git clone` 到 `~/.claude/skills/`。

### 验证安装

输入 `/plugin` 看到 `sie-smom` 已安装即成功。也可以随便说一句 SMOM 相关需求（如"帮我写个 Controller"），看 AI 是否引用 skill 内容。

## 二、日常使用

AI 检测到 SMOM 信号（`SIE.*` 命名空间、`Property<T>`、`IS_PHANTOM`、`DomainController`、`WebViewConfig` 等）后自动启用本 skill。直接说需求即可：

```
帮我给工单实体加一个"优先级"字段，列表页要能按它筛选
帮我审查这段 Controller 代码有没有问题
帮我写一个按编码规则生成单号的 Controller 方法
```

AI 会先查 `references/` 参考底库，找到真实 API 签名与示例后再写，并在结论中标注来源（如"见 references/05-controller.md"）。

## 三、三条铁律（防幻写协议，违反 = 废代码）

1. **AI 说"参考库未覆盖，需查证"时，让它去查或你自己查**。禁止说"那你自己编一个吧"——SMOM 框架 API 面广且自研，凭记忆写必错。
2. **代码必须编译通过才算完**。手写场景，结尾提醒 AI "编译验证一下"。
3. **AI 结论应标注来源**（如"见 references/05-controller.md"）。没标注来源的框架 API 用法要警惕。

## 四、常见误区

| ❌ 误区 | ✅ 正确做法 |
|---|---|
| 让 AI"凭经验直接写，不用查" | 保持防幻写协议：先查底库再写 |
| 怀疑 AI 写的 API 不对但懒得验证 | 让 AI 编译验证 + 对照 references 查证 |
| AI 说"需查证"就让它编 | 让它查源码/文档，查不到就如实告知 |

## 五、FAQ

**Q1：skill 装在哪？会不会污染我的项目？**
插件方式安装在 Claude Code 插件目录（`~/.claude/plugins/`），不进入项目仓库。

**Q2：为什么我提需求时 AI 没触发 skill？**
确认：① 已安装且 marketplace 已刷新；② 需求里包含 SMOM 信号词（`SIE.*`、`Property<T>`、`IS_PHANTOM` 等），或直接点名"用 sie-smom 规则"。

**Q3：参考底库有哪些？**
16 份精炼规则（编号 01-17，13 号历史删除）：架构 / WPF / 实体数据 / Web ViewConfig / Controller / Web 前端 / 通用 / 四库（MSSQL/Oracle/MySQL/PostgreSQL）建表与查询 / PDA 前端。见 SKILL.md 第 4 节路由表。

---

*维护者注意：修改本文档后同步更新 README.md 中的链接。*