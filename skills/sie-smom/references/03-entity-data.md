# 实体(Entity)与数据层规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。

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

### 1.0 `[Label]` 需要 `using SIE.ObjectModel`

缺少 `using SIE.ObjectModel;` 时，所有 `[Label("中文名")]` 会报 CS0246（`LabelAttribute` 定义在该命名空间）。实体文件必备 using：`SIE`（[DisplayMember]/[NotDuplicate]/RT）、`SIE.Domain`（DataEntity/P<T>/DomainController）、`SIE.MetaModel`（[RootEntity]/Meta）、`SIE.ObjectModel`（[Label]/Criteria）、`System`。详见红线 11（using 完整性）。

### 1.1 属性 setter 禁止加业务逻辑（用 OnPropertyChanged）

属性 setter 只能调用 `SetProperty`，**禁止在其中写副作用逻辑**（框架在 setter 中只做属性赋值，副作用会被绕过）：

```csharp
// 错误：setter 中写副作用
public string Code
{
    get { return GetProperty(CodeProperty); }
    set { SetProperty(CodeProperty, value); Name = value + "_suffix"; } // 禁止！
}

// 正确：用 OnPropertyChanged 响应变更
protected override void OnPropertyChanged(string propertyName)
{
    base.OnPropertyChanged(propertyName);
    if (propertyName == nameof(Code))
        Name = Code + "_suffix";
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

### 2.1 枚举属性必须用枚举类作为类型

实体中枚举类型的属性，必须使用对应的枚举类作为 `Property<T>` 的类型参数：

```csharp
// 正确：使用枚举类
public static readonly Property<AccountState> AccountStateProperty = P<Entity>.Register(e => e.AccountState);

// 错误：使用 int
public static readonly Property<int> AccountStateProperty = P<Entity>.Register(e => e.AccountState); // 禁止！
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

### 3.1 Criteria 属性禁止用自动属性

Criteria 属性必须用 `P<T>.Register` + `GetProperty/SetProperty` 注册。自动属性 `{ get; set; }` **编译可通过但运行时查询条件会丢失**（值未被 SIE 属性系统追踪）：

```csharp
// 错误：编译通过，但运行时查询条件丢失
public string Xxx { get; set; }

// 正确：经 SIE 属性系统注册
public static readonly Property<string> XxxProperty = P<T>.Register(e => e.Xxx);
public string Xxx
{
    get { return GetProperty(XxxProperty); }
    set { SetProperty(XxxProperty, value); }
}
```

### 3.2 FirstOrDefault 正确用法

`FirstOrDefault` 方法只有 **1 个参数重载**，如需加载视图属性：

```csharp
// 正确：单参数，传入 EagerLoadOptions
var entity = Query<Item>()
    .Where(e => e.Code == code)
    .FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty());

// 错误：框架没有双参数重载
var entity = Query<Item>()
    .Where(e => e.Code == code)
    .FirstOrDefault(null, new EagerLoadOptions().LoadWithViewProperty()); // 编译错误！
```

同理，`ToList` 也支持 `EagerLoadOptions`：

```csharp
query.ToList(criteria.PagingInfo, new EagerLoadOptions().LoadWithViewProperty());
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

### 4.1 DateRange 用 BeginValue/EndValue（不是 From/To）

`DateRange` **没有** `From` / `To` 属性（常见 AI 臆造，编译报 CS1061），范围值用 `BeginValue` / `EndValue`（均为 `DateTime?`）：

```csharp
// 错误：criteria.DeliveryDate.From / .To  → 编译错误

// 正确：BeginValue / EndValue
if (criteria.DeliveryDate.BeginValue.HasValue)
    query.Where(p => p.Date >= criteria.DeliveryDate.BeginValue.Value);
if (criteria.DeliveryDate.EndValue.HasValue)
    query.Where(p => p.Date <= criteria.DeliveryDate.EndValue.Value);
```

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

### 5.2.1 EntityRule 必须设置 Scope 和 ConnectToDataSource

`EntityRule` 构造函数中**必须**指定作用范围和数据源连接（漏配则规则不生效或查询失败）：

```csharp
public class WorkOrderDeleteRule : EntityRule<WorkOrder>
{
    public WorkOrderDeleteRule()
    {
        Scope = EntityStatusScopes.Delete;   // 必须指定作用范围（Delete/Add/Update）
        ConnectToDataSource = true;          // 需要 DB 查询时必须开启
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

### 5.3.1 内联 NotDuplicateRule 写法（推荐）

在 `AddValidations()` 中直接使用 `rules.AddRule` 内联注册：

```csharp
protected override void AddValidations(ValidationRules rules)
{
    rules.AddRule(new NotDuplicateRule()
    {
        Properties =
        {
            FloorAgvStationRelation.FloorProperty,
            FloorAgvStationRelation.RobotTypeProperty
        },
        MessageBuilder = (e) =>
        {
            return "（所在楼层+机器人类型）不允许重复".L10N();
        }
    });
}
```

> **注意**：`NotDuplicateRule` 的 `Properties` 是集合属性，用 `{ ... }` 初始化器添加字段；`MessageBuilder` 是委托，返回国际化字符串。禁止使用 `rules.AddNotDuplicateRule<...>()` 等臆造方法。

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

## 七、实体属性 5 种类型与注册

| 类型 | 注册方法 | 说明 |
|---|---|---|
| 普通属性 | `P<T>.Register(e => e.Xxx)` | 直接属性，映射数据库基类字段（见第一节） |
| 列表属性 | `P<T>.RegisterList(e => e.XxxList)` | 一对多子表；取值用 `GetLazyList` |
| 引用属性 | `RegisterRefId` + `RegisterRef`（成对） | 一对一；ID 引用映射 DB 字段，实体引用默认懒加载 |
| 视图属性 | `P<T>.RegisterView(e => e.Xxx, p => p.Ref.Code)` | 显示引用实体字段；JOIN 加载避 N+1；不可编辑；需 `EagerLoadOptions.LoadWithViewProperty()`；**拉平路径必须全为引用属性+物理列终点，禁止嵌套另一视图属性**（如 `p => p.Assign.ShippingWarehouseId` 中后者是 Assign 的视图属性非物理列）——编译通过但 SQL 生成时被当作物理列，运行期报 `列名'XX'无效`（2026-09-04 发运订单特殊物料标识实测）；应改走自身引用链直达物理列 |
| 只读属性 | `P<T>.RegisterReadOnly(e => e.Xxx, e => e.Compute(), 依赖属性)` | 内存计算；**禁止访问数据库（会 N+1）**；**依赖参数禁止传 `RefEntityProperty`（如 `ItemProperty`），必须传对应 `IRefIdProperty`（如 `ItemIdProperty`），否则框架运行时报错**（编译不拦截；2026-09-04 用户实测反馈）；**视图属性（如 `ItemName` 拉平自 `Item`）不必单独声明为依赖——其失效由源 `IRefIdProperty` 级联，只绑源 Id 即可**（用户确认：`ItemNameProperty` 也是 view 字段、数据来源 `ItemIdProperty`）；**`XxxProperty` 声明必须在全部同类依赖字段之后**（C# 静态字段按文本序初始化，读到未初始化的同类字段为 null → 空引用异常；基类字段访问会先触发基类初始化，不受顺序影响。稳妥做法：只读属性 region 放类尾，参照 `AsnDetail.cs:241`） |

## 八、引用属性与主从关系

引用属性 ID 与实体**成对注册**（`ReferenceType.Normal` 普通引用 / `ReferenceType.Parent` 主从的子端）：

```csharp
public static readonly IRefIdProperty RoleIdProperty = P<User>.RegisterRefId(e => e.RoleId, ReferenceType.Normal);
public static readonly RefEntityProperty<Role> RoleProperty = P<User>.RegisterRef(e => e.Role, RoleIdProperty);
public double RoleId { get => GetRefId(RoleIdProperty); set => SetRefId(RoleIdProperty, value); }
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

### 8.1 引用属性 setter 语义区分（Criteria vs Entity）

**按业务语义选择 setter**：引用值**必有值**用 `GetRefId/SetRefId`；**可空语义**（业务实体可能未关联，或 Criteria 的可选过滤条件）用 `GetRefNullableId/SetRefNullableId`（Criteria 可空引用的实证写法见 `04-web-viewconfig.md` 第五节模式 B）：

```csharp
// 必有值语义（实体必填引用或 Criteria 必选条件）
set { SetRefId(ShopIdProperty, value); }

// 可空语义（实体可能未关联，或 Criteria 可选过滤条件）
set { SetRefNullableId(ResourceIdProperty, value); }
```

> 属性注册与访问方法必须严格对应：`P<T>.Register` → `GetProperty/SetProperty`；`RegisterRefId` → `GetRefId/SetRefId`（Entity 可空用 `GetRefNullableId/SetRefNullableId`）；`RegisterRef` → `GetRefEntity/SetRefEntity`；`RegisterView` → **只有 getter，没有 setter**。

## 九、实体配置 EntityConfig

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

> **注意**：业务实体通常继承 `DataEntity`（DataEntity 含 IS_PHANTOM/INV_ORG_ID/SYNC_ID 等默认列，见 SKILL.md 第6节）；直接继承 `Entity` 时需在 `ConfigMeta()` 手动 `EnablePhantoms/EnableInvOrg/EnableDataSync` 启用对应插件。**DataEntity 具体默认启用了哪些插件，拿不准时查框架源码，勿臆测。**

> **INV_ORG_ID 默认注入机制**：DataEntity 子表的 INV_ORG_ID 列由框架**默认自动注入**（列映射 + 保存时自动填充组织值），实体代码**不要**手动注册 `InvOrgIdProperty`——手动注册与默认注入重复映射同列，运行时报 `ORMException: cannot add column INV_ORG_ID to table X, it already existed, maybe managed property mapping duplicated!`；显式 `Meta.EnableInvOrg()` 属冗余调用（默认已启用）。查询过滤同样**不要手写**组织 Where 条件——默认注入的实体在 `Query<T>()` 时框架**强制注入**组织过滤（`p.GetInvOrgId() == ...` / `p.InvOrgId == ...` 的组织条件一律多余）；只有 `DisableInvOrg()`+手动注册的实体（Enterprise 模式）才需要手写 `p.InvOrgId == RT.InvOrg || p.InvOrgId == 0`（EnterpriseController.cs:134 先例）。实体上读组织值用 `this.GetInvOrgId()`（扩展方法，需 `using SIE.Common.InvOrg;`，先例 ItemController.cs:125 / EnterpriseBehavior.cs:48）。确需 CLR 属性（如 `p.InvOrgId` 强类型引用）时的正确姿势是 **`Meta.DisableInvOrg()` 与手动注册 `InvOrgIdProperty` 成对出现**（Enterprise.cs:193+32、CatalogEx.cs:144+81、ApiLog、Employee 同款）——只注册不 Disable 必炸。

## 十、实体仓库查找 RF.Find

```csharp
var repo  = RF.Find<User>();        // 找实体仓库单例
var user  = repo.GetById(id, eagerLoad);
var users = repo.GetAll(pagingInfo, eagerLoad);
RF.Save(user);
```

> 仓库定位：同程序集同命名空间下"实体名+Repository"后缀视为其仓库，或 `[RepositoryFor]` / `[EntityMatrix]` 标记；找不到则用默认 `EntityRepository<T>`。**建议用默认仓库，特殊查询逻辑放 Controller。**

### 10.1 RF.Delete() 不存在 —— 删除用 PersistenceStatus.Deleted + RF.Save()

框架**没有** `RF.Delete(entity)` 方法（常见 AI 臆造）。删除实体：

```csharp
// 正确：标记逻辑删除后保存（配合 IS_PHANTOM 假删除）
entity.PersistenceStatus = PersistenceStatus.Deleted;
RF.Save(entity);

// 或用 DAO 的 DeleteBy（条件删除，见第六节）
DB.Delete<T>().Where(e => e.Code == code).Execute();
```

### 10.2 EntityList<T> 没有 ForEach() 方法

`EntityList<T>` **没有** `ForEach()` 扩展（常见 AI 臆造，编译报错）。遍历用 `foreach`：

```csharp
// 错误：list.ForEach(x => ...);   // EntityList<T> 无此方法，编译错误

// 正确：foreach 遍历
foreach (var item in list)
{
    // ...
}
```

## 十一、标签式验证规则与缓存

除第五节的代码式规则，还有**标签式**规则（声明后需实体元数据初始化才生效）：

- `[Required]` 不能为空
- `[NotDuplicate]` 不能重复
- `[MaxLength(n)]` / `[MinLength(n)]` 字符串长度
- `[MaxValue(v)]` / `[MinValue(v)]` 数值范围

> **缓存注意**：验证规则（标签式与代码式）修改后**必须重启服务才生效**——规则缓存在集群服务上，不重启无法保证所有节点刷新。
