---
name: smom-quickstart
description: SMOM 平台快速入门。当用户要从零新建一个 SMOM 业务功能（建实体到配界面）时使用，给出端到端开发步骤清单，引导按正确顺序建实体->EntityConfig->建表->Controller->ViewConfig->菜单。详细 API/规则查 sie-smom skill 的 references/。
---

# SMOM 平台快速入门

## 0. 何时启用本 skill

当用户要"从零新建一个 SMOM 业务功能"（如缺陷管理、物料管理、工单管理）时启用。

典型信号：
- 用户说"新建一个 XX 功能"、"做一个 XX 单据"、"从零开发 SMOM XX 模块"
- 需要从实体到界面端到端搭建

不涉及从零开发时不要启用（查具体 API / 规则用 `sie-smom` skill）。

---

## 1. 端到端开发步骤

| 步骤 | 产出 | 关键规则（详见 `sie-smom` references） |
|------|------|------|
| 1. 实体建模 | 实体类（继承 `DataEntity`） | `Property<T>` 注册属性；`[RootEntity, Serializable]`；引用属性成对 `RegisterRefId`+`RegisterRef`；主从用 `RegisterList`+`ReferenceType.Parent` |
| 2. EntityConfig | `XxxConfig : EntityConfig<T>` | `ConfigMeta()` 里 `MapTable` + `EnablePhantoms`/`EnableInvOrg`/`EnableDataSync` |
| 3. 建表脚本 | MSSQL + Oracle 各一套 | 8 个 DataEntity 默认列 + 双序列 `SEQ_<表>_ID`/`SEQ_<表>_SYNC_ID` + `PK_`/`IX_`/`CHK_` 约束 + 列注释 |
| 4. Controller | `XxxController : DomainController` | 查询带 `Where` + `IS_PHANTOM=0` + `ORDER BY`；大集合 `SplitContains`；跨模块用 `CommonController` |
| 5. ViewConfig | `XxxViewConfig : WebViewConfig<T>` | `ConfigView`/`ConfigListView`；`ConfigDetailsView` 必须先 `View.FormEdit()` 再 `UseDefaultCommands()` |
| 6. 上线 | 升级数据库 + 模块初始化 + 菜单 | 先模块初始化，再配菜单权限 |

---

## 2. 防幻写

每一步动手前，先查 `sie-smom` skill 的 `references/` 对应文件（路由见 `sie-smom` 的 SKILL.md 第 4 节），**不臆造框架 API**。找不到就明说"参考库未覆盖，需查证"。

---

## 3. 参考底库

详细规则、API 签名、错误/正确示例见 `sie-smom` skill 的 `references/`（`01-architecture.md` ~ `11-oracle-table.md` + `manual/`）。
