> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：07-_____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：DomainController·Query<T>规范·禁止全表查询·SplitContains·SplitDataExecute·CommonController

---

# 后端控制器(Controller)规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。
> **内容概要**:DomainController 基类、Query<T>() 查询规范、禁止无条件全表查询、SplitContains/SplitDataExecute 分批查询、RT.Service.Resolve 服务调用、CommonController 通用查询。

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
