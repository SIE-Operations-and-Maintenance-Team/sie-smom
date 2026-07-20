# sie-smom

SIE SMOM 平台（.NET 6.0 MES + SIE 自研框架）的 Claude Code Skill 集合，参考 [Superpower](https://github.com/obra/superpowers) 设计。

让 AI 精通 SMOM 平台特性，**防幻写**--编写或审查 SMOM 的 C#/JS/SQL 代码时，AI 先查参考底库再写，不臆造框架 API。

## Installation

### Claude Code 插件市场（推荐）

注册 marketplace（**一次性**，后续新增 skill 不用换地址）：

```bash
/plugin marketplace add SIE-Operations-and-Maintenance-Team/sie-smom
```

安装 plugin：

```bash
/plugin install sie-smom@sie-smom
```

后续仓库新增 skill 时，客户端执行 `/plugin marketplace update` 刷新即可安装新 skill，**无需重新 `marketplace add`**。

### cc-switch

在 `cc-switch` 中添加仓库：

```
https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom
```

`cc-switch` 会自动扫描 `skills/` 目录，刷新即可看到。

### 手动克隆

```bash
cd ~/.claude/skills
git clone https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom.git
```

## 可用 Skills

### sie-smom ⭐

**SIE SMOM 平台开发专家** - 让 AI 精通 SMOM 平台特性，防幻写。

| 领域 | 内容 |
|------|------|
| 架构 | 分层架构、Module 注册、DataProvider、IoC（RT.Service/RF/DB）、类命名规范、环境搭建、事务规则 |
| 实体层 | 实体属性 5 类型、引用/主从关系、EntityConfig、实体插件、验证规则、DAO |
| 后端 | Controller、查询规范、SplitContains、禁止全表查询、命令基类与可重写方法 |
| Web 端 | ViewConfig、编辑器、命令、Behavior、DataQueryer、ExtJS、提交事件、属性变更事件 |
| WPF 端 | ViewConfig、ViewBehavior、ListViewCommand、PagingLookUpEditor、Layout |
| 数据库 | MSSQL 建表/查询、Oracle 建表/查询、类型映射、序列、索引 |
| 高级功能 | 附件、打印、编码规则、调度、预警、API、客制化界面、权限 |
| 通用 | Algorithm、L10N 国际化、JS 事件 API（mon/fireEvent/mun）、常见坑 |

## 目录结构

```
sie-smom/
├── .claude-plugin/
│   ├── plugin.json         ← plugin 元数据
│   └── marketplace.json    ← marketplace 声明（plugins 列表）
├── skills/
│   └── sie-smom/           ← 实际 skill（SKILL.md + references/）
│       ├── SKILL.md
│       └── references/
├── README.md
├── CLAUDE.md
├── LICENSE
└── update.ps1 / update.sh
```

> **新增 skill**：在 `skills/` 下建新目录（含 `SKILL.md`），并在 `.claude-plugin/marketplace.json` 的 `plugins` 数组追加条目。客户端刷新 marketplace 即可安装，无需换仓库地址。

## 如何贡献

1. 在 `skills/` 下创建新目录，如 `skills/xxx-skill/`
2. 目录根须包含 `SKILL.md` 作为入口
3. 在 `.claude-plugin/marketplace.json` 的 `plugins` 数组追加条目
4. 在 `README.md` 中添加介绍
5. 提交 PR

## License

MIT © 2026 SIE Operations & Maintenance Team
