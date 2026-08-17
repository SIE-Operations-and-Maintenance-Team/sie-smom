# sie-smom

赛意 SMOM 平台（.NET 6.0 MES + SIE 自研框架）的 **Claude Code Skill**，参考 [Superpower](https://github.com/obra/superpowers) 设计。

让 AI 精通 SMOM 平台特性，**防幻写**——编写或审查 SMOM 的 C#/JS/SQL 代码时，AI 先查参考底库再写，不臆造框架 API。

## How it works

SMOM 是赛意自研框架，API 面广且无公开文档，AI 凭记忆写必然臆造（错误的编辑器名、缺失 `IS_PHANTOM`、前端直访 DB、主键用 IDENTITY 等）。本 skill 把平台特性抽成 **25 份参考底库**（编号 01-23，13 号历史删除；18 号 Web 命令配方按任务域拆为 4 份）：

- **01-07 精炼规则**：架构、实体、Controller、ViewConfig 等核心开发规范
- **08-17 数据库规范**：MSSQL/Oracle/MySQL/PostgreSQL 四库建表与查询
- **18-23 配方库**：蒸馏自 SMOM 开发手册 2026-08 版（Web 命令/Web 行为与编辑器/Web 前端/WPF/服务端工具/问题库，共 123 篇配方）

并借鉴平台外部规范精华（实战陷阱、防臆造 API、前端进阶等），强制 AI「先查再写、找不到就明说」：

1. **先查再写**：动手写实体 / Controller / ViewConfig / 命令 / SQL 前，先查 `references/` 找真实 API 签名与示例
2. **照搬模式**：复用参考库的命名、基类、属性、参数顺序
3. **找不到就明说**：参考库未覆盖的 API，明确告知「需查证」，不编造

详见 `skills/sie-smom/SKILL.md` 第 2 节（防幻写协议）和第 3 节（13 条红线）。

## Installation

### Claude Code 插件市场（推荐）

```bash
/plugin marketplace add SIE-Operations-and-Maintenance-Team/sie-smom
/plugin install sie-smom@sie-smom
```

后续仓库更新时，执行 `/plugin marketplace update` 刷新即可，无需重新添加。

### cc-switch

在 `cc-switch` 中添加仓库 `https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom`，它会自动扫描 `skills/` 目录。

### 手动克隆

```bash
cd ~/.claude/skills
git clone https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom.git
```

## 可用 Skill：sie-smom ⭐

**SIE SMOM 平台开发专家** - 让 AI 精通 SMOM 平台特性，防幻写。

| 领域 | 内容 |
|------|------|
| 架构 | 分层架构、Module 注册、DataProvider、IoC（RT.Service/RF/DB）、类命名规范、环境搭建、事务规则 |
| 实体层 | 实体属性 5 类型、引用/主从关系、EntityConfig、实体插件、验证规则、DAO |
| 后端 | Controller、查询规范、SplitContains、禁止全表查询、命令基类与可重写方法 |
| Web 端 | ViewConfig、编辑器、命令、Behavior、DataQueryer、ExtJS、提交事件、属性变更事件 |
| Web 命令配方 | 保存/提交/导入导出/打印/添加/选择/弹窗查看全配方（23 篇，按任务域拆为 `18-web-commands-form` / `import-export` / `add-lookup` / `print-attach` 4 份） |
| Web 行为与编辑器 | 单元格/行变色、状态栏、分页、排序、统计行、模糊枚举/枚举多选编辑器、透视表动态列（14 篇，`19-web-behaviors.md`） |
| Web 前端进阶 | invokeCommand、mon/fireEvent/mun、SIE.Msg、三档客制化（LayoutClass/UIGenerator/ModuleRuntime）、DM_ 跨层传参（24 篇，`20-web-frontend-misc.md`） |
| WPF 端 | ViewConfig、ViewBehavior、ListViewCommand、PagingLookUpEditor、Layout；弹窗命令/行为/编辑器/控件/工具配方（28 篇，`21-wpf-recipes.md`） |
| 数据库 | MSSQL 建表/查询、Oracle 建表/查询、MySQL 建表/查询、PostgreSQL 建表/查询、类型映射、序列、索引 |
| 服务端工具 | ObjectUtil/EntityUtil/DataChecker/SqlCreator/DbBulkProvider、调度防并发、预警三件套、钉钉/邮件/企微推送、客制化 WebApi（20 篇，`22-host-tools-cases.md`） |
| 工作流与问题排查 | Elsa 工作流全流程（节点/转办驳回/通知）、查询效率、框架开关、配置缓存、BS 弹窗子页签（14 篇，`23-problems.md`） |
| 高级功能 | 附件、打印、编码规则、调度、预警、API、客制化界面、权限 |
| 通用 | Algorithm、L10N 国际化、JS 事件 API（mon/fireEvent/mun）、常见坑、防臆造 API 速查 |

## 查证顺序（防幻写）

`skills/sie-smom/references/`（精炼规则，优先）→ 项目实际代码。references 未覆盖的 API 按防幻写协议明确「需查证」，不臆造。

## 目录结构

```
sie-smom/
├── .claude-plugin/
│   ├── plugin.json         ← plugin 元数据
│   └── marketplace.json    ← marketplace 声明（plugins 列表）
├── skills/
│   └── sie-smom/           ← 实际 skill（SKILL.md + references/ 01-23）
│       ├── SKILL.md        ← Skill 入口（平台本质、防幻写协议、13 条红线、路由表）
│       └── references/     ← 参考底库（25 份：01-07 精炼规则 / 08-17 数据库规范 / 18-23 配方库）
├── README.md
├── CLAUDE.md
├── LICENSE
└── update.ps1 / update.sh
```

## 如何贡献

1. 修改 `skills/sie-smom/` 下的文件
2. 更新 `README.md` 与 `CLAUDE.md` 中的相关说明
3. 提交 PR

## License

MIT © 2026 SIE Operations & Maintenance Team