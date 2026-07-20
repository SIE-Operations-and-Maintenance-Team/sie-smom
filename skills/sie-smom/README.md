# sie-smom — SIE SMOM 平台开发专家 (Claude Code Skill)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 一个 Claude Code Skill，让 AI 成为 **赛意 SMOM 平台**（.NET 6.0 MES + SIE 自研框架）的开发专家，所有内容有源可查、不产生幻觉。
>
> A Claude Code Skill that turns AI into an expert on the **SIE SMOM platform** (.NET 6.0 MES + SIE framework), with all content traceable to source — no hallucination.

---

## 📦 安装 / Installation

需要 [Claude Code](https://claude.ai/code)。

### 方式一：Claude Code 插件市场（推荐，自动更新）

```bash
# 第一步：注册市场（只需一次）
/plugin marketplace add SIE-Operations-and-Maintenance-Team/smom-skills

# 第二步：安装 skill（只需一次，后续版本自动更新）
/plugin install sie-smom@smom-skills
```

### 方式二：直接克隆

```bash
cd ~/.claude/skills
git clone https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom.git
```

### 方式三：一键更新脚本（传统方式适用）

```bash
# 安装 smom-skills 索引仓库后运行
.\update.ps1            # Windows
./update.sh             # macOS / Linux
```

---

## 🚀 使用说明 / Usage

安装后，当你在 Claude Code 中处理以下内容时，skill 会自动激活：

- 代码中出现 `SIE.*` 命名空间、`RT.Service` / `RF` / `DB` / `DomainController` / `WebViewConfig` / `WPFViewConfig`
- 涉及 `Property<T>` / `Criteria` / `IRefIdProperty` / `DataEntity` / `IS_PHANTOM` / `.L10N()` / `.t()`
- 新建业务表（MSSQL / Oracle 建表脚本）
- 配置编辑器、命令、验证规则、Behavior、附件、打印、调度、预警、API

也可手动调用：

```
/sie-smom
```

Skill 内置的**防幻写协议**保证 AI 在给出建议前先查阅参考底库，遇到不熟悉的 API 会明确告知"参考库未覆盖，需查证"，不会编造框架方法。

> 详细规则见 `SKILL.md` 第 2 节（防幻写协议）和第 3 节（10 条强制红线）。

---

## 📚 内容结构 / Structure

```
sie-smom/
├── SKILL.md                         # 入口文件：平台本质 + 防幻写协议 + 10 条红线 + 路由表
├── references/
│   ├── 01-architecture.md           # 架构总览（分层/Module/DataProvider/IoC）
│   ├── 02-wpf.md                    # WPF 组件规范
│   ├── 03-entity-data.md            # 实体与数据层（属性/验证/DAO）
│   ├── 04-web-viewconfig.md         # Web ViewConfig 规范
│   ├── 05-controller.md             # 后端 Controller 规范
│   ├── 06-web-frontend.md           # Web 前端规范（DataQueryer/ExtJS）
│   ├── 07-general.md                # 通用规范（Algorithm/L10N/API 速查）
│   ├── 08-mssql-query.md            # MSSQL 查询规范
│   ├── 09-mssql-table.md            # MSSQL 建表规范
│   ├── 10-oracle-query.md           # Oracle 查询规范
│   ├── 11-oracle-table.md           # Oracle 建表规范
│   └── manual/                      # SMOM v8.0+ BS 学习手册（docx 权威全文，按主题切分）
│       ├── 01-dev-standards.md      # 开发工具/C#语法/环境/代码片段/8.2注意
│       ├── 02-snest-platform.md     # SNest 技术平台/架构/部署
│       ├── 03-entity-modeling.md    # 实体建模/属性/标签/配置/UML-ModelFirst
│       ├── 04-ui-impl-editors.md    # 菜单/DB连接/单表主从表/编辑器/常用API
│       ├── 05-commands.md           # 命令全集（最大，约 112KB）
│       ├── 06-validation-events.md  # 验证/提交事件/Behavior/属性变更/附加子视图
│       ├── 07-attachments-printing.md # 附件/编码规则/配置项/打印/实体扩展
│       ├── 08-queries-scheduling-alerts.md # 三种查询/调度/预警
│       ├── 09-api-js-events.md      # Api/JS事件/关闭前/GridPanel动态列
│       ├── 10-custom-ui-permissions.md # 半全客制界面/排序/权限/JS按需加载
│       └── 11-ajax-deploy-db.md     # Ajax/部署/数据库操作/示例/经验总结
```

---

## 🧠 参考底库 / Reference Sources

本 skill 的参考底库由两部分组成：

| 类型 | 来源 | 特点 |
|------|------|------|
| **curated/** (references 根目录 11 篇) | 个人经验整理的**精炼规则** | 含明确的【禁止项 / 错误示例 / 正确示例】，与 manual 重合处以此为准 |
| **manual/** (11 篇) | SMOM v8.0+ BS 学习手册（docx） | 权威完整手册，按主题切分，提供 curated 未覆盖的广度细节 |

---

## 🤝 贡献指南 / Contributing

欢迎提交 Issue 和 PR！

### 如何贡献

1. Fork 本仓库
2. 添加或修改参考内容
3. 提交 PR，说明修改内容及来源依据

### 内容规范

- 所有新增内容必须**有来源依据**（SMOM 文档、框架源码、官方示例）
- 禁止添加臆造/猜测的框架 API
- 精炼规则风格：每个规则含 **禁止项 → 错误示例 → 正确示例**
- 如需补充新的 docx 参考源，请按 `manual/` 现有格式切分

---

## 📄 许可证 / License

[MIT](LICENSE) © 2026 SIE Operations & Maintenance Team