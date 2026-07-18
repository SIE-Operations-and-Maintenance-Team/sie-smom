# sie-smom — SIE SMOM 平台 Claude Code Skill 集合

> 赛意 SMOM 平台（.NET 6.0 MES + SIE 自研框架）的 Claude Code Skill，参考 [Superpower](https://github.com/obra/superpowers) 设计。
>
> 所有 skill 放在 `skills/` 目录下，`cc-switch` 直接添加本仓库即可识别。

---

## 📦 安装

### cc-switch（推荐）

在 `cc-switch` 中添加仓库：

```
https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom
```

`cc-switch` 会自动扫描 `skills/` 目录，刷新即可看到。

### Claude Code 插件市场

```bash
/plugin marketplace add SIE-Operations-and-Maintenance-Team/sie-smom
/plugin install sie-smom@sie-smom
```

### 手动克隆

```bash
cd ~/.claude/skills
git clone https://github.com/SIE-Operations-and-Maintenance-Team/sie-smom.git
```

---

## 可用 Skills

### sie-smom ⭐

**SIE SMOM 平台开发专家** — 让 AI 精通 SMOM 平台特性，防幻写。

| 领域 | 内容 |
|------|------|
| 架构 | 分层架构、Module 注册、DataProvider、IoC（RT.Service/RF/DB） |
| 实体层 | 实体建模、属性注册、标签、验证规则、DAO |
| 后端 | Controller、查询规范、SplitContains、禁止全表查询 |
| Web 端 | ViewConfig、编辑器、命令、Behavior、DataQueryer、ExtJS |
| WPF 端 | ViewConfig、ViewBehavior、Command、Editor、Layout |
| 数据库 | MSSQL 建表/查询、Oracle 建表/查询、类型映射、序列、索引 |
| 高级功能 | 附件、打印、编码规则、调度、预警、API、客制化界面、权限 |

---

## 目录结构

```
sie-smom/
├── skills/
│   └── sie-smom/          ← 实际 skill，cc-switch 从这里识别
│       ├── SKILL.md
│       ├── plugin.json
│       ├── manifest.json
│       ├── references/
│       └── ...
├── plugins.json            ← Claude Code 插件市场索引
├── update.ps1              ← 一键更新脚本（Windows）
├── update.sh               ← 一键更新脚本（Unix）
├── README.md
├── LICENSE
└── .gitignore
```

---

## 如何贡献

1. 在 `skills/` 下创建新目录，如 `skills/xxx-skill/`
2. 目录根须包含 `SKILL.md` 作为入口
3. 在根目录 `plugins.json` 中添加插件条目
4. 在 `README.md` 中添加介绍
5. 提交 PR

---

## 许可证

[MIT](LICENSE) © 2026 SIE Operations & Maintenance Team