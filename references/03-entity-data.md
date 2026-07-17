> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：04-_____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：实体属性(Property<T>)·枚举Label·Criteria·验证规则(PropertyRule·EntityRule·NotDuplicateRule·NoReferencedRule)·DAO

---

# 实体(Entity)与数据层规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。
> **内容概要**:Entity 属性注册(Property<T>)、枚举 Label、Criteria 查询实体、DateRange、验证规则(PropertyRule/EntityRule/NotDuplicateRule/NoReferencedRule)、DAO 层 BaseDao<T>。

## 一、实体属性注册
属性使用 Property<T> 注册，必须用 #region 包裹并附带 [Label]:

```csharp
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
}
```

## 二、枚举定义
枚举必须使用 [Label] 特性标注中文名称:

```csharp
public enum AccountState
{
    [Label("运行")]
    Running = 0,
    [Label("停机")]
    Downtime = 1,
    [Label("故障")]
    Fault = 2,
}
```

## 三、Criteria 查询实体
查询实体继承 Criteria，必须重写 Fetch():

```csharp
[QueryEntity, Serializable]
[Label("API日志查询实体")]
public class ApiLogCriteria : Criteria
{
    protected override EntityList Fetch()
    {
        return RT.Service.Resolve<ApiLogController>().GetApiLogs(this);
    }
}
```

## 四、DateRange 日期范围

```csharp
[Label("开始时间")]
public static readonly Property<DateRange> StartTimeProperty = P<ApiLogCriteria>.Register(e => e.StartTime);

public DateRange StartTime
{
    get { return this.GetProperty(StartTimeProperty); }
    set { this.SetProperty(StartTimeProperty, value); }
}
```

---

## 五、验证规则(Validation Rules)

### 5.1 属性验证规则 - PropertyRule<T>
```csharp
[DisplayName("包装单位数量大于0验证规则")]
public class PackageUnitQtyRule : PropertyRule<PackageRuleDetail>
{
    protected override IManagedProperty Property => PackageRuleDetail.QtyProperty;

    protected override void Validate(IEntity entity, RuleArgs e)
    {
        var packageDtl = entity as PackageRuleDetail;
        if (packageDtl.Qty <= 0)
            e.BrokenDescription = "产品数必须大于0".L10N();
    }
}
```

### 5.2 实体验证规则 - EntityRule<T>
```csharp
[DisplayName("包装规则验证规则")]
public class MasterUnitInPackageRuleLevelRule : EntityRule<PackageRule>
{
    protected override void Validate(IEntity entity, RuleArgs e)
    {
        var d = entity as PackageRule;
        e.BrokenDescription = "包装[{0}]主单位必须是第一个".L10nFormat(d.Code);
    }
}
```

### 5.3 不重复验证规则 - NotDuplicateRule<T>
```csharp
public class NotDuplicateRule : NotDuplicateRule<PackageRuleDetail>
{
    public NotDuplicateRule()
    {
        Properties.Add(PackageRuleDetail.PackageRuleIdProperty);
        Properties.Add(PackageRuleDetail.PackageUnitIdProperty);
        MessageBuilder = (e) => "已经存在包装单位[{0}]".L10nFormat((e as PackageRuleDetail).PackageUnit.Code);
    }
}
```

### 5.4 不可删除引用规则 - NoReferencedRule<T>
```csharp
public class UndeleteRule : NoReferencedRule<NumberRule>
{
    public UndeleteRule()
    {
        Properties.Add(ItemPackageRuleDetail.NumberRuleIdProperty);
        MessageBuilder = (o, e) => "编码规则[{0}]已经被[{1}]引用，不能删除".L10nFormat((o as NumberRule).Code, "物料包装规则明细".L10N());
    }
}
```

---

## 六、DAO 层

DAO 继承 BaseDao<T>:

```csharp
public class BaseDao<T> : IDao where T : Entity
{
    protected BaseDao() { }

    public virtual T GetById(object id, EagerLoadOptions eagerLoad = null)
        => RF.GetById<T>(id, eagerLoad);

    protected virtual IEntityQueryer<T> Query()
        => DB.Query<T>();

    public virtual EntityList<T> FindMany(Expression<Func<T, bool>> filter, PagingInfo paging = null, EagerLoadOptions eagerLoad = null)
        => Query().Where(filter).ToList(paging, eagerLoad);

    public virtual void Save(T entity)
        => RF.Save(entity);

    public virtual void DeleteBy(Expression<Func<T, bool>> filter)
        => DB.Delete<T>().Where(filter).Execute();
}
```
