# 后端控制器(Controller)规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。

## 1. 基类继承
所有业务控制器必须继承 DomainController:

```csharp
public class ItemController : DomainController
{
    // 业务方法
}
```

## 2. 查询方法标准写法
使用 Query<T>() 构建 LINQ 查询:

```csharp
public virtual EntityList<Item> GetItems(ItemCriteria criteria)
{
    if (criteria == null)
        throw new ArgumentNullException(nameof(criteria));
    var query = Query<Item>();
    if (criteria.Code.IsNotEmpty())
        query.Where(e => e.Code.Contains(criteria.Code));
    if (criteria.Name.IsNotEmpty())
        query.Where(e => e.Name.Contains(criteria.Name));
    return query
        .ToList(criteria.PagingInfo,new EagerLoadOptions().LoadWithViewProperty());
}
```

**重要规则：禁止无条件查询全表数据**

使用 `Query<T>()` 时，**必须至少添加一个 Where 条件**，严禁直接执行 `query.ToList()` 查询全表数据，避免大数据量下的性能问题。

**错误示例：**
```csharp
// 错误：无条件查询，可能返回全表数据
public virtual EntityList<Item> GetAllItems()
{
    var query = Query<Item>();
    return query.ToList(); // 严禁！
}
```

**正确示例：**
```csharp
// 正确：必须有查询条件
public virtual EntityList<Item> GetItems(ItemCriteria criteria)
{
    var query = Query<Item>();
    if (criteria.Code.IsNotEmpty())
        query.Where(e => e.Code.Contains(criteria.Code));
    if (criteria.State != null)
        query.Where(e => e.State == criteria.State);
    
    // 至少有一个条件才执行查询
    if (!criteria.Code.IsNotEmpty() && criteria.State == null)
        throw new ValidationException("请至少输入一个查询条件".L10N());
    
    return query.ToList(criteria.PagingInfo);
}
```

**重要规则：List 包含查询必须使用 SplitContains 或 SplitDataExecute**

当查询条件涉及 `List.Contains()` 时，**必须使用 `SplitContains` 或 `SplitDataExecute` 方法**，避免 SQL IN 子句过长导致性能问题或数据库错误。

**错误示例：**
```csharp
// 错误：直接使用 List.Contains，当 list 很大时会产生超长 SQL IN 子句
public virtual EntityList<Item> GetItemsByCodes(List<string> codes)
{
    var query = Query<Item>();
    query.Where(e => codes.Contains(e.Code)); // 严禁！
    return query.ToList();
}
```

**正确示例：**
```csharp
// 正确：使用 SplitContains 分批查询
public virtual EntityList<Item> GetItemsByCodes(List<string> codes)
{
    return codes.SplitContains(tempCodes=>
    {
        return Query<Item>()
            .Where(e => tempCodes.Contains(e.Code))
            .ToList();
    });
}

// 正确：使用 SplitDataExecute 分批执行
public virtual EntityList<Item> GetItemsByCodes(List<string> codes)
{
    return SplitDataExecute(codes, batch =>
    {
        return Query<Item>()
            .Where(e => batch.Contains(e.Code))
            .ToList();
    });
}
```

**说明：**
- `SplitContains`：自动将大集合分批，每批生成独立的 SQL IN 子句，合并结果
- `SplitDataExecute`：将大集合分批执行，每批独立查询，适合需要更细粒度控制的场景
- 当 List 元素数量超过 1000 时，必须使用上述方法，避免数据库 IN 子句限制

## 3. 服务调用写法
后端控制器之间互相调用使用 RT.Service.Resolve<T>():

```csharp
RT.Service.Resolve<AlgorithmController>().GetDateSequence(Context.DetailId, date, startValue);
```

## 4. 前端调用后端控制器唯一合法写法:

```csharp
RT.Service.Resolve<XXX控制器类>().对应方法();
```

## 5. 通用查询控制器
跨模块通用查询使用 CommonController:

```csharp
var emp = RT.Service.Resolve<CommonController>().GetData<Employee>(p => p.Name == config.EmployeeName);
var items = RT.Service.Resolve<CommonController>().GetDatas<Item>(p => p.State == State.Enable);
```

---

## 6. 命令基类与可重写方法

命令跨前后端：JS 端控制交互/创建实体，CS 端执行业务。

| 基类 | 端 | 可重写方法 |
|---|---|---|
| `ViewCommand`（添加/修改/删除/查询等） | JS | `canExecute(view)` / `createNewItem()` / `onItemCreated(entity)` / `getEditEntity()` |
| `ViewCommand` | CS | `Excute(ViewArgs args, string scope)` |
| `SaveCommand`（表格保存） | CS | `Excute` / `DoSave(EntityList)` / `OnSaving` / `OnSaved` |
| `FormSaveCommand`（表单保存） | CS | `Excute` / `DoSave(Entity)` / `OnSaving` / `OnSaved` / `OnValidation` |
| `ImportCommandBase`（导入） | CS | `GetImportCompleted()` / `GetImportHandleType()` |

> 方法名 `Excute` 为框架实际拼写（非 `Execute`），重写时需一致。命令重写**必须加 meta 且不能换行**；前后端有交互时 JS/CS 全命名空间完全一致（见 `01-architecture.md` 命令类规范）。
>
> **`ViewCommand<T>` 泛型选型**（与前端 `view.execute({data})` 的数据形态一一对应，详见 `20-web-frontend-misc.md` 1.3 节）：
> - 传单个实体 → `ViewCommand`（不带泛型），`Excute(ViewArgs args, ...)` 内 `args.Data.ToJsonObject<T>()` 反序列化；
> - 传数组 / 集合（如 `getSelectionIds()`）→ `ViewCommand<double[]>`（泛型 = 数组类型），`Excute(double[] args, ...)` 直接使用 `args`；
> - **传自定义拼装数据（前端 `indata.Data = Ext.encode({...})`）→ 必须 `ViewCommand<ViewArgs>`（带 `<ViewArgs>` 泛型）**，`Excute(ViewArgs args, ...)` 内 `args.Data.ToJsonObject<Xxx>()` 反序列化。漏写 `<ViewArgs>` 泛型会导致反序列化形态不符。

## 7. Criteria 类必须定义在独立文件中

Criteria 查询实体必须定义在独立的 `.cs` 文件中，禁止写在 Controller 或 ViewConfig 类内部。

```csharp
// 正确：独立文件
// File: ApiLogCriteria.cs
[QueryEntity, Serializable]
[Label("API日志查询实体")]
public class ApiLogCriteria : Criteria
{
    #region 接口名 ApiName
    [Label("接口名")]
    public static readonly Property<string> ApiNameProperty = P<ApiLogCriteria>.Register(e => e.ApiName);
    public string ApiName
    {
        get { return this.GetProperty(ApiNameProperty); }
        set { this.SetProperty(ApiNameProperty, value); }
    }
    #endregion

    protected override EntityList Fetch()
    {
        return RT.Service.Resolve<ApiLogController>().GetApiLogs(this);
    }
}

// 错误：写在 Controller 类内部
public class ApiLogController : DomainController
{
    // 禁止：Criteria 不能定义在 Controller 内部
    public class ApiLogCriteria : Criteria { }
}
```

> **原因**：`[QueryEntity]` 扫描可能无法正确识别嵌套类。

---

## 8. 查询排序（Criteria.OrderInfoList）

BS 端排序由前端网格列头触发，后端通过 Criteria 基类内置的 `OrderInfoList` 属性应用排序（ViewConfig 无需配置排序）：

```csharp
// Controller 查询时应用排序
if (criteria.OrderInfoList != null && criteria.OrderInfoList.Count > 0)
    q = q.OrderBy(criteria.OrderInfoList);

// 或使用 Common 扩展判空
else if (criteria.OrderInfoList.AnyExt())
    entityQueryer = entityQueryer.OrderBy(criteria.OrderInfoList);
```

要点：
- `OrderInfoList` 由前端列头点击自动填充（字段名/方向），后端直接 `OrderBy(criteria.OrderInfoList)` 应用
- 分页查询必须带 `ORDER BY`（红线 4）：`OrderInfoList` 为空时给默认排序（如主键/创建时间）
- 集合判空优先用 Common 扩展 `.AnyExt()`（等价 `Count > 0` 的简写，来源：平台 Common 实际代码）

---

## 9. 禁止冗余的"标准 CRUD"方法

简单 CRUD 实体**不要手写**框架已提供的标准方法（`DeleteXxx` / `UpdateXxx` 等）——框架默认命令已覆盖，手写反而引入双份逻辑与维护负担（来源：平台实战反模式）：

```csharp
// 错误：框架默认删除命令已覆盖，无需手写
public virtual void DeleteXxx(double id) { ... }   // 冗余！

// 正确：仅实现框架没有的业务逻辑；标准 CRUD 交给默认命令
```

> 需要引用保护/重复校验等增强时，用验证规则（`NoReferencedRule` / `NotDuplicateRule`，见 `03-entity-data.md` 第五节），而不是重写删除方法。

