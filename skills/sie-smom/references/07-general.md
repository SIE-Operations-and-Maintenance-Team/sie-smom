> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：05-____.md
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
