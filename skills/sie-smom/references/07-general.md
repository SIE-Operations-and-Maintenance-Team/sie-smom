> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **来源**：个人实战经验整理（精炼自 SIE 平台实践）
> **优先级**：高。
> **覆盖范围**：Algorithm注册·L10N国际化(.L10N·.L10nFormat·.t)·XML注释·框架API速查表

---

# 通用规范

> **适用范围**:本规范适用于项目中所有 `*.cs`、`*.js`、`*.ts` 文件,始终生效。
> **内容概要**:[Algorithm] 算法注册、L10N 国际化(.L10N()/.L10nFormat()/.t())、XML 文档注释、框架 API 速查表。

## 一、Algorithm 算法规范
使用 [Algorithm] 特性注册:

```csharp
[Algorithm("批次编码段算法", typeof(CodeAlgorithmConfig), AlgorithmType.Entity)]
[RootEntity, Serializable]
public class EnterpriseCodeSegmentAlgorithm : EntityCodeAlgorithm
{
    public override string GetCode()
    {
        var data = Context.Data;
        if (data == null) return "";
        if (data is IBatchCodeSegment)
            return ((IBatchCodeSegment)(data as object)).GetBatchCodeSegment();
        else
            throw new ValidationException("{0}编码段无法生成编码。".L10nFormat(data.GetType().FullName));
    }
}
```

## 二、国际化(L10N)规范

```csharp
// 静态文本翻译
throw new ValidationException("条码工单为空！".L10N());

// 格式化翻译
e.BrokenDescription = "包装[{0}]主单位必须是第一个".L10nFormat(d.Code);
```

```javascript
// JS前端翻译
title: '异常信息报表'.t()
```

## 三、XML 文档注释规范（强制）

**所有公开的类、方法、属性、字段必须使用 XML 文档注释，禁止遗漏。** 行内重要逻辑也必须添加注释说明意图。

```csharp
/// <summary>
/// 物料基类控制器
/// </summary>
public class ItemController : DomainController
{
    /// <summary>
    /// 查询物料
    /// </summary>
    /// <param name="criteria">物料查询实体</param>
    /// <returns>物料列表</returns>
    public virtual EntityList<Item> GetItems(ItemCriteria criteria)
    {
        // 校验查询条件
        if (criteria == null)
            throw new ArgumentNullException(nameof(criteria));
        // ...业务逻辑
    }
}
```

> **注意**：缺少 XML 注释的代码将被视为不合格。行内注释帮助接手者快速理解代码意图，但不应注释显而易见的内容（如 `i++` // 加一）。

## 四、关键框架约定速查

| 代码 | 含义 |
|------|------|
| RT.Service.Resolve<T>() | IoC 服务解析 |
| RT.IdentityId | 当前用户ID |
| RT.InvOrg | 当前库存组织 |
| RT.Config.Get<T>(key) | 获取配置 |
| RF.Save(entity) | 保存实体 |
| RF.GetById<T>(id) | 按ID获取 |
| RF.BatchInsert(list) | 批量插入 |
| DB.Query<T>() | 创建查询 |
| DB.Delete<T>() | 创建删除 |
| .L10N() | 国际化翻译 |
| .L10nFormat(args...) | 格式化国际化 |
| .IsNotEmpty() | 字符串非空判断 |
| .IsNullOrEmpty() | 字符串为空判断 |
| `FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty())` | 查询单条并加载视图属性（仅1参数重载） |
| .t() | JS前端翻译 |

> **FirstOrDefault 注意**：框架的 `FirstOrDefault` 只有 **1 个参数重载**，传入 `EagerLoadOptions` 即可。禁止使用 `FirstOrDefault(null, options)` 双参数形式。

---

## 五、常见坑

- **C# 代码不是 Allman 风格**：大括号必须独占一行（Allman 风格），禁止 Java/C 风格（大括号跟在行尾）。禁止无意义换行，同一逻辑行放在同一行。
- **ViewModel 分页失效**：界面查询方法自己做数据转换时，返回对象需 `SetTotalCount` 设置总数，否则分页失效。
- **报表 / Echart 返回类型**：返回数据用 `List`，**不要返回 `EntityList`**（框架对 `EntityList` 返回做了特殊处理）。
- **新增文件未更新 .csproj**：所有新增文件（`.cs`、`.js`、`.aspx` 等）必须同步更新对应项目的 `.csproj` 文件。JS 文件需同时配置 `<None Remove>` 和 `<EmbeddedResource Include>`，否则运行时报 `No such Entity / No such class`。这是最常见的遗漏问题，代码生成后必须确认 VS 能索引到新增文件。
- **L10N 扩展方法在 `System` 命名空间**：`.L10N()` / `.L10nFormat()` 的扩展类声明在 `System` 命名空间。自定义文件（如校验规则）即使其余 using 与框架示例一致，只要缺平文的 `using System;`（`using System.ComponentModel;` 等替代不了）就报 CS1061，报错行看起来毫无关联。
- **`RuleArgs` 在 `SIE.MetaModel` 命名空间**：自写 `EntityRule<T>` / `NotDuplicateRule<T>` 的 `Validate(IEntity, RuleArgs)` 报 CS0246 / CS0534 时，先补 `using SIE.MetaModel;`（与同项目既有规则文件对照 using 最直观）。
- **`ToList` 带 EagerLoadOptions 是第 2 参数**：`.ToList(pagingInfo, new EagerLoadOptions().LoadWith(X.ChildListProperty))`；不要按 `FirstOrDefault` 的单参数形态套用。

---

## 六、JS 事件与动态列 API

**事件订阅 / 激活 / 注销**（mon / fireEvent / mun）：

```javascript
this.view.mon(this.view, eventName, function () { /* ... */ }, { single: true });  // 订阅
this.fireEvent(eventName, this);                                                    // 激活
this.mun(this, eventName);                                                         // 注销
```

**关闭前事件**：事件名 `beforeClosewin`，在 Behavior 的 `onViewReady` 注册 `view.mon(view, 'beforeClosewin', this.beforeClosewin)`。

**GridPanel 动态列**：

```javascript
var gridPanel = view.getControl();
gridPanel.addColumn({ name: 'alive', type: 'boolean', defaultValue: true }, { header: '动态列', dataIndex: 'alive' });
gridPanel.removeColumn(colIndex - 1);  // 框架含行号列，索引需减 1
```

**定义命令（JS 端）**：`SIE.defineCommand('全命名空间', { extend: '...', meta: {...}, execute: function(view) {...} })`

**Api 开放接口**：方法标记 `[ApiService]`，参数 `[ApiParameter]`，返回 `[ApiReturn]`；运行 host / 部署后可在 API 查到对应方法、请求格式和返回值。

---

## 七、原生 SQL 与存储过程（DbAccesser）

框架内直接操作数据库的原生方式：`DbAccesserFactory.Create(连接字符串名)` 获取 `IDbAccesser`（真实用法见平台 SPC / WMS 模块实际代码）：

```csharp
using (var db = DbAccesserFactory.Create("连接字符串名"))   // 连接字符串名见 appsettings.json
{
    // 参数工厂创建参数（可指定 DbType / ParameterDirection）
    var p = db.ParameterFactory.CreateParameter("@ViewName", viewName);
    var p2 = db.ParameterFactory.CreateParameter("P_LPN", lpn, DbType.String, ParameterDirection.Input);

    // 原生 SQL 查询 → DataTable
    var dt = db.ExecuteDataTable("select * from XXX where CODE=@Code", CommandType.Text, parameters);

    // 存储过程：Oracle 用 "包名.过程名"，MSSQL 直接过程名
    var dt2 = db.ExecuteDataTable("RCS_PKG.RCS_CALL_BACK_UPDATE", CommandType.StoredProcedure, parameters);

    // 非查询（增删改）
    int count = db.ExecuteNonQuery(sql, CommandType.Text, parameters);
}
```

要点：
- 返回 `DataTable`，转实体需自行处理（平台常见 `DataTableToList<T>` 帮助方法）
- 参数名：MSSQL `@name`、Oracle `:name`（按 `ParameterFactory` 约定）
- **红线 1 延伸**：DbAccesser 仅用于后端 Controller / Service / Job，前端一律禁止

---

## 八、数据权限（EntityDataAuth + QueryFactory.Exists）

平台数据权限方案：实体打 `[EntityDataAuth]` 标记，框架 `DataAuthInterceptor` 在 `RepositoryDataProvider.Querying` 事件自动为查询注入 EXISTS 子查询过滤（真实用法见平台 Common/DataAuth 模块）：

```csharp
[EntityDataAuth(AuthIdProperty = "DeptId", AuthType = typeof(EmployeeAuth), Nullable = true)]
public class XxxEntity : DataEntity { ... }
```

- `AuthIdProperty`：实体上做权限过滤的属性（部门/员工等）
- `AuthType`：授权实体类（如 `EmployeeAuth`，可带 `[EmployeeAuth]\` 特性指定 `EmployeeIdProperty`）
- `Nullable = true`：字段为空时放行（生成 `OR 字段 IS NULL OR EXISTS(...)`），否则强制 EXISTS
- 启用：模块初始化调用 `DataAuthInterceptor.Intercept()`（订阅 `RepositoryDataProvider.Querying`）

**底层 EXISTS 构建（QueryFactory）**——框架查询对象工厂：

```csharp
var f = QueryFactory.Instance;
IQuery subQuery = /* 子查询 */;
e.Args.Query.Where = e.Args.Query.Where.And(f.Exists(subQuery));          // EXISTS 子查询
// f.Constraint(column, value) 列约束 / f.Value(null) 空值 / f.Or(...) 或组合
```

**排查提示**：界面查不到数据时，依次检查：① 实体是否有 `[EntityDataAuth]`；② 授权实体（EmployeeAuth）中是否有当前用户数据；③ `DataAuths.LoadALl` 配置（置 true 可临时全量放行，仅排查用）；④ 菜单/按钮权限用 ViewConfig 的 `View.AssignAuthorize(typeof(实体))` 授权（见 `04-web-viewconfig.md`）。

---

## 九、不存在的 API（防臆造速查）

> 以下 API 是 AI 写代码时最容易"凭空推测"出来的，**在 SIE 框架中均不存在**（来源：平台实战反模式整理）。遇到这些写法直接按右列替换：

| AI 推测（不存在） | 实际 API / 做法 |
|---|---|
| `[BusinessOperation]` Attribute | 无等效项，业务方法直接写在 Controller 中 |
| `BusinessException` | `ValidationException`（命名空间 `SIE.Domain.Validation`） |
| `DomainController.Update(entity)` | `RF.Save(entity)` |
| `UseAllOption()` | 此框架版本不存在此方法 |
| `ChildrenProperty(...).DisableEditing()` | `DisableEditing` 不适用于 `WebChildrenPropertyViewMeta` |
| `OrderBy(p => p.Xxx, true)` 双参数降序 | `OrderByDescending(p => p.Xxx)` |
| `SIE.cmd.Base` 作为 extend 基类 | 自定义命令**不需要 extend**（`SIE.defineCommand` 直接定义 meta/canExecute/execute） |
| 命名空间 `SIE.Domain.Attributes` | 不存在（`[Label]` 等特性在 `SIE.ObjectModel` 等真实命名空间） |
| 命名空间 `SIE.Web.Common.MetaModel.Extend` | 不存在 |
| `RdbDataProvider` 在 `SIE.Data` | 实际命名空间以模块 DataProvider 文件为准，查 `01-architecture.md` |

> **规则**：任何"直觉 API"在 `references/` 查不到时，先按上表对照，再查证源码——找不到就明说，禁止臆造。
