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

---

## 七、实体属性 5 种类型与注册（manual/03-entity-modeling.md 6.6）

| 类型 | 注册方法 | 说明 |
|---|---|---|
| 普通属性 | `P<T>.Register(e => e.Xxx)` | 直接属性，映射数据库基类字段（见第一节） |
| 列表属性 | `P<T>.RegisterList(e => e.XxxList)` | 一对多子表；取值用 `GetLazyList` |
| 引用属性 | `RegisterRefId` + `RegisterRef`（成对） | 一对一；ID 引用映射 DB 字段，实体引用默认懒加载 |
| 视图属性 | `P<T>.RegisterView(e => e.Xxx, p => p.Ref.Code)` | 显示引用实体字段；JOIN 加载避 N+1；不可编辑；需 `EagerLoadOptions.LoadWithViewProperty()` |
| 只读属性 | `P<T>.RegisterReadOnly(e => e.Xxx, e => e.Compute(), 依赖属性)` | 内存计算；**禁止访问数据库（会 N+1）** |

## 八、引用属性与主从关系

引用属性 ID 与实体**成对注册**（`ReferenceType.Normal` 普通引用 / `ReferenceType.Parent` 主从的子端）：

```csharp
public static readonly IRefIdProperty RoleIdProperty = P<User>.RegisterRefId(e => e.RoleId, ReferenceType.Normal);
public static readonly RefEntityProperty<Role> RoleProperty = P<User>.RegisterRef(e => e.Role, RoleIdProperty);
public int RoleId { get => (int)GetRefId(RoleIdProperty); set => SetRefId(RoleIdProperty, value); }
public Role Role { get => GetRefEntity(RoleProperty); set => SetRefEntity(RoleProperty, value); }
```

主从关系（一对多）：主实体 `RegisterList` + `GetLazyList`，子实体 `RegisterRefId(ReferenceType.Parent)` + `RegisterRef`：

```csharp
[RootEntity, Serializable]
public class ItemGroup : Entity<double>
{
    public static readonly ListProperty<EntityList<Item>> ItemListProperty = P<ItemGroup>.RegisterList(e => e.ItemList);
    public EntityList<Item> ItemList => this.GetLazyList(ItemListProperty);
}
[ChildEntity, Serializable]
public class Item : Entity<double>
{
    public static readonly IRefIdProperty ItemGroupIdProperty = P<Item>.RegisterRefId(e => e.GroupId, ReferenceType.Parent);
    public static readonly RefEntityProperty<ItemGroup> ItemGroupProperty = P<Item>.RegisterRef(e => e.Group, ItemGroupIdProperty);
}
```

## 九、实体配置 EntityConfig（manual/03-entity-modeling.md 6.8）

重写 `ConfigMeta()` 配置映射/插件，重写 `AddValidations()` 配置验证规则：

```csharp
protected override void ConfigMeta()
{
    Meta.MapTable("RES_EMP_GROUP");                        // 映射表
    Meta.MapView("V_RES_EMP_GROUP");                       // 映射数据库视图
    Meta.MapView("(SELECT * FROM RES_EMP_GROUP)");         // 映射 SQL 视图（必须括号；不能出现当前实体，否则死循环）
    Meta.MapAllProperties();                                // 映射所有字段
    Meta.Property(Employee.CodeProperty).MapColumn().HasLength(50); // 指定列长度
    // 实体插件
    Meta.EnablePhantoms();      // 假删除（IS_PHANTOM）
    Meta.EnableInvOrg();        // 库存组织（INV_ORG_ID）
    Meta.EnableDataSync();      // 数据同步（SYNC_ID）
    Meta.EnableEntityLog();     // 编辑日志
    Meta.EnableSort(); Meta.EnableTimeStamp(); Meta.EnableVersion();
}
```

> **注意**：业务实体通常继承 `DataEntity`（DataEntity 含 IS_PHANTOM/INV_ORG_ID/SYNC_ID 等默认列，见 SKILL.md 第6节）；直接继承 `Entity` 时需在 `ConfigMeta()` 手动 `EnablePhantoms/EnableInvOrg/EnableDataSync` 启用对应插件。**DataEntity 具体默认启用了哪些插件，拿不准时查 manual/03 6.8 或框架源码，勿臆测。**

## 十、实体仓库查找 RF.Find（manual/03-entity-modeling.md 6.4）

```csharp
var repo  = RF.Find<User>();        // 找实体仓库单例
var user  = repo.GetById(id, eagerLoad);
var users = repo.GetAll(pagingInfo, eagerLoad);
RF.Save(user);
```

> 仓库定位：同程序集同命名空间下"实体名+Repository"后缀视为其仓库，或 `[RepositoryFor]` / `[EntityMatrix]` 标记；找不到则用默认 `EntityRepository<T>`。**建议用默认仓库，特殊查询逻辑放 Controller。**

## 十一、标签式验证规则与缓存（manual/03-entity-modeling.md 6.7.8）

除第五节的代码式规则，还有**标签式**规则（声明后需实体元数据初始化才生效）：

- `[Required]` 不能为空
- `[NotDuplicate]` 不能重复
- `[MaxLength(n)]` / `[MinLength(n)]` 字符串长度
- `[MaxValue(v)]` / `[MinValue(v)]` 数值范围

> **缓存注意**：验证规则（标签式与代码式）修改后**必须重启服务才生效**——规则缓存在集群服务上，不重启无法保证所有节点刷新。
