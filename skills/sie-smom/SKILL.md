---
name: sie-smom
description: SIE SMOM 平台开发专家（.NET 6.0 MES + SIE 自研框架）。编写或审查 SMOM 的 C#/JS/SQL 代码时使用：实体建模、Controller、ViewConfig、命令、编辑器、验证规则、Behavior、附件、打印、调度、预警、API、客制化界面、MSSQL/ORACLE 建表与查询。所有结论必须来自 references/ 参考底库，禁止臆造框架 API。
---

# SIE SMOM 平台开发专家

## 0. 何时启用本 skill

当任务涉及**赛意 SMOM / SIE 框架**代码时启用，典型信号：
- 代码中出现 `SIE.*` 命名空间、`RT.Service` / `RF` / `DB` / `DomainController` / `WebViewConfig` / `WPFViewConfig` / `ViewBehavior` / `ListViewCommand` / `PagingLookUpEditor`
- 出现 `Property<T>` / `Criteria` / `IRefIdProperty` / `DataEntity` / `IS_PHANTOM` / `.L10N()` / `.t()` / `SIE.invokeDataQuery` / `Ext.define('SIE.Web...`
- 新建业务表（MSSQL `SEQ_*` / Oracle `NUMBER(18,0)`）、写跨实体 SQL、配菜单/编辑器/命令/调度/预警/打印

不涉及上述信号时不要启用。

---

## 1. 平台本质（始终牢记）

- **产品**：赛意 SMOM —— 工业 MES 制造执行系统；**框架**：SIE 自研框架；**运行时**：.NET 6.0。
- **分层**（命名空间即职责，禁止乱放）：

| 项目后缀 | 职责 | 只允许放 |
|---|---|---|
| `SIE.{Module}` | 领域层 | 实体 / Controller / Service / Dao / Rule |
| `SIE.Web.{Module}` | BS Web 端 | ViewConfig / Command / DataQueryer / Behavior / Scripts(.js) |
| `SIE.Wpf.{Module}` | CS 桌面端 | ViewConfig / Command / Behavior / Editor / Layout / Converter |
| `SIE.xUnit.{Module}` | 单元测试 | xUnit |
| `SIE.{Module}.Job` | 后台任务 | Hangfire 调度 |
| `SIE.{Module}.Statistics` | 统计汇总 | 统计逻辑 |

> **Controller 禁止放在 `SIE.Web.*`，必须在 `SIE.{Module}` 领域层。**

- **IoC 三件套**：`RT.Service`（服务解析/注册）、`RF`（Repository 工厂：Save/GetById/BatchInsert）、`DB`（Query/Update/Delete/TransactionScope）。
- **数据底座**：所有业务实体继承 `DataEntity`，逻辑删除用 `IS_PHANTOM`（bool→0/1），主键 ID 与外键均为 `FLOAT`(MSSQL) / `NUMBER(18,0)`(Oracle)，由**序列**生成（不用 IDENTITY）。

---

## 2. 防幻写协议（本 skill 的核心约束）

> 平台 API 面广且自研，**凭记忆写必出错**。遵守以下三步：

1. **先查再写**：动手写实体 / Controller / ViewConfig / 命令 / 编辑器 / 验证规则 / SQL 前，先按【第 4 节路由表】读对应 `references/` 文件，找到**真实可用的方法签名与示例**。
2. **照搬模式**：复用参考库里的命名、基类、属性、参数顺序；不引入第二种风格、不臆造未出现的框架方法。
3. **找不到就明说**：若某方法/编辑器/规则在参考库中查不到，**必须告知用户「参考库未覆盖，需查证」**，不得编造 API。给出结论时标注来源文件（如 `见 references/05-controller.md`）。

**绝对禁止**：自己脑补 `View.UseXxxEditor()`、`RT.Xxx`、`SIE.SomeApi`、某基类某重写方法等参考库中不存在的东西。

---

## 3. 强制规则（红线，始终生效）

以下规则在任何 SMOM 代码中**无条件遵守**，违反即缺陷：

1. **禁止前端直访数据库**：ViewConfig / Command / Behavior / DataQueryer / 前端 JS 中禁止 `DB.Query<T>` / `RF.Save` / `RF.GetById` / `Query<T>` 等；必须 `RT.Service.Resolve<XxxController>().方法()`。
2. **禁止无条件全表查询**：`Query<T>().ToList()` 必须至少带一个 `Where`；无条件的 `GetAll` 要抛 `ValidationException("请至少输入一个查询条件".L10N())`。
3. **大集合 IN 查询必须分批**：`List.Contains` 用 `SplitContains` 或 `SplitDataExecute`；元素 >1000 时强制使用，避免超长 SQL IN。
4. **每个查询必须带 `IS_PHANTOM = 0`**（除非明确查逻辑删除数据）；分页必须带 `ORDER BY`。
5. **JS 文件必须设为嵌入资源**（`<EmbeddedResource Include="..."/>` + `<None Remove="..."/>`），否则运行时报 `No such Entity / No such class`。
6. **实体属性用 `Property<T>` 注册**，`#region` 包裹并加 `[Label("中文名")]`；枚举每个值加 `[Label]`。
7. **国际化**：C# 用 `.L10N()` / `.L10nFormat(args)`，JS 用 `.t()`；不裸写中文业务串到无翻译路径。
8. **新建实体须同步产出建表脚本**（MSSQL 和 Oracle 各一套）：含 8 个 `DataEntity` 默认列、2 个序列（`SEQ_<表>_ID` 从 100000 起、`SEQ_<表>_SYNC_ID` 从 1 起）、主键约束 `PK_<表>`、索引 `IX_<表>_<字段>`、表/列注释、枚举字段 `CHECK` 约束。
9. **Controller 继承 `DomainController`**；跨模块通用查询用 `CommonController`；控制器间互调用用 `RT.Service.Resolve<T>()`。
10. **自定义非重写视图方法**（如 `ConfigXxxView()`）中，属性必须显式 `.Readonly().Show(ShowInWhere.All)` 才会显示（框架只自动处理 `ConfigListView` / `ConfigDetailsView`）。

> 详见各 curated 文件中的【禁止 / 错误示例 / 正确示例】小节。

---

## 4. 主题路由表（按任务查参考文件）

> `curated/`（references 根目录 01-11）= 精炼规则，优先读；`manual/` = docx 权威手册，查细节/查 curated 未覆盖项时读。

| 任务 | 先读（curated） | 再查（manual） |
|---|---|---|
| 架构 / 分层 / Module 注册 / DataProvider / IoC | `01-architecture.md` | `01-dev-standards.md`、`02-snest-platform.md` |
| 实体建模 / 属性 / 标签 / 配置 / UML-ModelFirst | `03-entity-data.md` | `03-entity-modeling.md` |
| 实体验证规则 / DAO | `03-entity-data.md` | `06-validation-events.md` |
| 后端 Controller / 查询规范 | `05-controller.md` | `05-commands.md` |
| 命令（增删改查·保存·选择·启停·复制新增·导入导出·合并拆分·上传） | `05-controller.md` | `05-commands.md` |
| Web ViewConfig / 视图方法 / AttachChildrenProperty | `04-web-viewconfig.md` | `04-ui-impl-editors.md` |
| 编辑器 `UseXxxEditor()`（布尔/文本/数值/日期/枚举/图片/快码/分页查找/弹框/联动/树形/文本按钮） | — | `04-ui-impl-editors.md` |
| Web 前端（DataQueryer / ExtJS Layout·Controller / 通用工具 / Web Behavior） | `06-web-frontend.md` | `09-api-js-events.md` |
| Behavior 行为 / 属性变更事件 / 附加子视图 / 提交事件 | — | `06-validation-events.md` |
| 通用附件 / 编码生成规则 / 配置项 / 标签单据打印 / 实体扩展属性 | — | `07-attachments-printing.md` |
| 三种查询实现 / 调度 / 预警 | — | `08-queries-scheduling-alerts.md` |
| Api 接口 / JS 事件(mon·fireEvent·mun) / 关闭前事件 / GridPanel 动态列 | — | `09-api-js-events.md` |
| 半客制 / 全客制界面 / BS 排序 / 界面权限排查 / JS 按需加载 | — | `10-custom-ui-permissions.md` |
| Ajax(SIE.Ajax) / SMOM8.2 部署 / 框架内数据库操作(DB·原生SQL·存储过程·事务·Exists) | — | `11-ajax-deploy-db.md` |
| WPF（ViewConfig / Behavior / Command / Editor / Layout） | `02-wpf.md` | — |
| 通用（Algorithm / L10N / XML 注释 / 框架 API 速查） | `07-general.md` | — |
| MSSQL 建表 | `09-mssql-table.md` | — |
| MSSQL 查询（C#→SQL 类型映射 / JOIN / 枚举 / 分页 / 避坑 / MSSQL↔Oracle 差异） | `08-mssql-query.md` | — |
| Oracle 建表 | `11-oracle-table.md` | — |
| Oracle 查询 | `10-oracle-query.md` | — |

---

## 5. 框架 API 速查（高频，始终在上下文）

> 完整表见 `references/07-general.md`。以下为最常用，写代码时直接用，**其余请查证**。

```
RT.Service.Resolve<T>()              // IoC 解析服务/控制器
RT.Service.Register(iface, impl, ServiceLifeStyle.Singleton)  // 注册（在 Module.Initialize）
RT.IdentityId / RT.InvOrg / RT.Config.Get<T>(key)
RF.Save(entity) / RF.GetById<T>(id) / RF.GetAll<T>() / RF.BatchInsert(list)
DB.Query<T>() / DB.Update<T>() / DB.Delete<T>() / DB.TransactionScope(connStr)
Query<T>()                            // DomainController 内构建 LINQ 查询
SplitContains(fn) / SplitDataExecute(list, batch=>fn)  // 大集合分批 IN
.L10N() / .L10nFormat(args)           // C# 国际化
.t()                                  // JS 国际化
.IsNotEmpty() / .IsNullOrEmpty()      // 字符串判空
SIE.invokeDataQuery({type,method,params,token,success})  // 前端调后端 DataQueryer
SIE.Ajax({...})                       // 前端 ajax 请求后台方法
```

**编辑器（节选，完整见 `manual/04-ui-impl-editors.md`）**：
`UseCheckEditor` / `UseTextEditor` / `UseTextRangeEditor` / `UseMemoEditor` / `UseSpinEditor` / `UseSpinRangeEditor` / `UseDateEditor` / `UseDateRangeEditor` / `UseDateTimeEditor` / `UseEnumEditor` / `UseImageComponentEditor` / `UseCatalogEditor` / `UsePagingLookUpEditor` / `UsePagingLookUpPopupEditor` / `UseTextButtonFieldEditor`。

**命令基类（节选，完整见 `manual/05-commands.md`）**：
`ListViewCommand` / `FormSaveCommand` / 以及框架的 添加/修改/删除/查询/保存/选择/复制新增/导入/导出/合并行/拆分行/上传 命令基类——具体可重写方法(canExecute/onItemCreated/getEditEntity 等)查手册，勿臆造。

---

## 6. 数据库不变式（建表/查询共用）

**DataEntity 默认 8 列**（每张业务表必有）：

| 列 | C# | MSSQL | Oracle | 说明 |
|---|---|---|---|---|
| ID | long | FLOAT NOT NULL | NUMBER(18,0) NOT NULL | 主键，序列生成 |
| SYNC_ID | long | FLOAT NOT NULL | NUMBER(18,0) NOT NULL | 同步ID，序列生成 |
| CREATE_BY | long? | FLOAT NULL | NUMBER(18,0) | 创建人 |
| CREATE_DATE | DateTime | DATETIME NOT NULL | DATE NOT NULL | 创建时间 |
| UPDATE_BY | long? | FLOAT NULL | NUMBER(18,0) | 更新人 |
| UPDATE_DATE | DateTime | DATETIME NOT NULL | DATE NOT NULL | 更新时间 |
| INV_ORG_ID | int? | INT NULL | NUMBER(10,0) | 所属机构 |
| IS_PHANTOM | bool | BIT NOT NULL DEFAULT 0 | NUMBER(1,0) DEFAULT 0 NOT NULL | 逻辑删除标记 |

**类型映射（C# → DB）**：

| C# | MSSQL | Oracle |
|---|---|---|
| long / IRefIdProperty | FLOAT | NUMBER(18,0) |
| int / enum | INT | NUMBER(10,0) |
| decimal | DECIMAL(18,6) | NUMBER(18,6) |
| bool | BIT | NUMBER(1,0) |
| DateTime | DATETIME | DATE |
| string(短) | NVARCHAR(80) | VARCHAR2(80) |
| string(长) | NVARCHAR(4000) | VARCHAR2(4000) |

- **命名**：表/列全大写下划线；外键列加 `_ID` 后缀；约束 `PK_/IX_/CHK_/SEQ_` 前缀。
- **序列**：`SEQ_<表>_ID` START WITH 100000；`SEQ_<表>_SYNC_ID` START WITH 1；取值 MSSQL `NEXT VALUE FOR [dbo].[SEQ]`、Oracle `SEQ.NEXTVAL`。
- **差异速查**：当前时间 `GETDATE()` vs `SYSDATE`；NULL 兜底 `ISNULL` vs `NVL`；字符串前缀 `N'...'`(MSSQL Unicode) vs `'...'`；标识符 `[dbo].[表]` vs `表`；参数 `@name` vs `:name`；列注释 `sp_addextendedproperty` vs `COMMENT ON COLUMN`。完整对照见 `references/08-mssql-query.md` 第十二节。

---

## 7. 参考底库清单

```
references/
├── 01-architecture.md         # 架构总览（分层/Module/DataProvider/IoC）
├── 02-wpf.md                  # WPF 组件规范
├── 03-entity-data.md          # 实体与数据层（属性/验证/DAO）
├── 04-web-viewconfig.md       # Web ViewConfig 规范
├── 05-controller.md           # 后端 Controller 规范
├── 06-web-frontend.md         # Web 前端规范（DataQueryer/ExtJS）
├── 07-general.md              # 通用规范（Algorithm/L10N/API 速查）
├── 08-mssql-query.md          # MSSQL 查询规范
├── 09-mssql-table.md          # MSSQL 建表规范
├── 10-oracle-query.md         # Oracle 查询规范
├── 11-oracle-table.md         # Oracle 建表规范
└── manual/                    # SMOM v8.0+ BS 学习手册（docx 权威全文，按主题切分）
    ├── 01-dev-standards.md            # 开发工具/C#语法/环境/代码片段/8.2注意
    ├── 02-snest-platform.md           # SNest 技术平台/架构/部署
    ├── 03-entity-modeling.md          # 实体建模/属性/标签/配置/UML-ModelFirst
    ├── 04-ui-impl-editors.md          # 菜单/DB连接/单表主从表/编辑器/常用API
    ├── 05-commands.md                 # 命令全集（最大）
    ├── 06-validation-events.md        # 验证/提交事件/前后端请求/Behavior/属性变更/附加子视图
    ├── 07-attachments-printing.md     # 附件/编码规则/配置项/打印/实体扩展
    ├── 08-queries-scheduling-alerts.md # 三种查询/调度/预警
    ├── 09-api-js-events.md            # Api/JS事件/关闭前/GridPanel动态列
    ├── 10-custom-ui-permissions.md    # 半全客制界面/排序/权限/JS按需加载
    └── 11-ajax-deploy-db.md           # Ajax/部署/数据库操作/示例/经验总结
```

> 11 篇 curated 为精炼规则（含禁止/错误/正确示例），与 manual 重合处以 curated 为准；manual 提供 curated 未覆盖的广度细节。
