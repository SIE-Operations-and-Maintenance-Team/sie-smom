# ViewConfig 视图配置规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。

## 一、Web ViewConfig
继承 WebViewConfig<T>:

```csharp
public class AbnormalInforViewConfig : WebViewConfig<AbnormalInfor>
{
    public const string ConfirmView = "ConfirmView";
    public const string ReadOnlyView = "ReadOnlyView";

    protected override void ConfigView()
    {
        View.FormEdit();
        View.DeclareExtendViewGroup(ConfirmView, ReadOnlyView);
        if (View.EntityViewMeta.ViewGroup == ConfirmView)
            ConfigConfirmView();
        else
            ConfigReadOnlyView();
    }

    protected override void ConfigListView()
    {
        View.UseCommands(AbnormalInfoCommands.ConfirmAbnormalInfoCommand, WebCommandNames.ExportXls);
        using (View.OrderProperties())
        {
            View.Property(p => p.No);
            View.Property(p => p.AbnormalInfoDefinitionDesc).HasLabel("异常信息");
        }
    }

    protected void ConfigConfirmView()
    {
        View.AddBehavior("SIE.Web.AbnormalInfo.AbnormalInfos.Behaviors.AbnormalInfoDetailBehavior");
        View.HasDetailColumnsCount(5);
        View.UseCommands(typeof(SaveAbnormalInfoCommand).FullName, typeof(SubmitAbnormalInfoCommand).FullName);
        using (View.OrderProperties())
        {
            View.Property(p => p.No).Readonly().ShowInDetail();
            View.Property(p => p.ReasonAnalysis).UseMemoEditor().HasLabel("原因分析(必填)").ShowInDetail(columnSpan: 5);
        }
    }
}
```

## 二、常用 ViewConfig 方法

| 方法 | 用途 |
|------|------|
| View.FormEdit() | 弹窗表单编辑模式，用于需要点击编辑按钮打开弹窗的场景 |
| View.InlineEdit() | 行内编辑模式，用于表格内直接编辑的场景 |
| View.UseDefaultCommands() | 使用默认命令 |
| View.UseCommands(...) | 指定命令 |
| View.UseDetail() | 使用详情弹窗 |
| View.AddBehavior(...) | 添加行为 |
| View.Property(p => p.XXX).Readonly() | 只读属性 |
| View.Property(p => p.XXX).HasLabel("xxx") | 自定义标签 |
| View.Property(p => p.XXX).ShowInDetail() | 在详情中显示 |
| View.Property(p => p.XXX).UseMemoEditor() | 多行文本编辑器 |
| View.Property(p => p.XXX).UseCatalogEditor(e => {...}) | 目录编辑器 |
| View.Property(p => p.XXX).UseDefectLookupEditor(p => {...}) | 缺陷查找编辑器 |
| View.Property(p => p.XXX).UsePagingLookUpEditor(...) | 分页查找编辑器 |
| View.Property(p => p.XXX).UseCheckEditor(p => {...}) | 布尔复选框（真实用法：`UseCheckEditor(p => p.AllowBlank = false)`） |
| View.Property(p => p.XXX).UseSpinEditor(p => {...}) | 数值编辑器（真实用法：`UseSpinEditor(p => p.AllowDecimals = false)`） |
| View.Property(p => p.XXX).UseDateRangeEditor(p => {...}) | 日期范围（真实用法：`p.DateFormat = "Y/m/d"; p.DateRangeType = ...`） |
| View.Property(p => p.XXX).UseDateTimeEditor() | 日期时间（可链 `.ShowInList(160).Readonly(IsReadonlyExp)`） |
| View.Property(p => p.XXX).UseEnumEditor(c => {...}) | 枚举下拉（真实用法：`c.AllowBlank = true`） |
| View.Property(p => p.XXX).UseImageComponentEditor(p => {...}) | 图片（真实用法：`p.Width = 300; p.Height = 400; p.Border = ...`） |
| View.Property(p => p.XXX).UsePagingLookUpPopupEditor(p => {...}) | 分页查找弹框（真实用法：`p.Editable = true; p.MultiOrSelect = ...`） |
| View.Property(p => p.XXX).UseTextButtonFieldEditor(p => {...}) | 文本按钮（真实用法：`p.ExtendJsObj = "SIE.Web.Xxx.Editors.XxxEditor"`） |
| ~~UseTextRangeEditor / UseSpinRangeEditor~~ | 文本范围/数值范围编辑器：平台实际项目未见调用，**需查证后再用** |
| View.ChildrenProperty(p => p.XXXList) | 子表属性 |
| View.AttachChildrenProperty(...) | 附加外部实体列表 |
| View.HasDetailColumnsCount(5) | 详情列数 |
| View.DeclareExtendViewGroup(...) | 声明扩展视图组 |
| View.SetPagingInfo(defaultSize, pageSizes) | 设置分页信息 |
| View.UseTotalColumn(displayProp, calcProps...) | 使用合计列 |
| View.UseMemorySelect() | 使用内存选中 |

## 三、AttachChildrenProperty 附加外部实体列表规范

**严禁在 lambda 中直接使用 `RT.Query<T>()`、`DB.Query<T>()`、`RF.Find<T>()` 等直接访问数据库。**

**默认要使用分页，必须通过 `ChildPagingDataArgs` 或 `ChildPagingDataWithParentEntityArgs` 传递分页参数。**

标准写法:

```csharp
// 写法一：ChildPagingDataArgs
View.AttachChildrenProperty(typeof(SampleTestProject), o =>
{
    var args = o as ChildPagingDataArgs;
    return RT.Service.Resolve<SampleTestProjectController>().GetSampleTestProjects(args?.PagingInfo);
}).HasLabel("送样检验标准").OrderNo = 2;

// 写法二：ChildPagingDataWithParentEntityArgs + 视图组
View.AttachChildrenProperty(typeof(SampleTestProject), o =>
{
    var args = o as ChildPagingDataWithParentEntityArgs;
    SampleInspBill parent = JsonConvert.DeserializeObject<SampleInspBill>(args.ParentEntity);
    return RT.Service.Resolve<SampleTestProjectController>().GetSampleTestProjects(args.PagingInfo);
}, SampleTestProjectViewConfig.ListView).HasLabel("送样检验标准").Show(ChildShowInWhere.Detail).OrderNo = 2;

// 控制器方法
public virtual EntityList<SampleTestProject> GetSampleTestProjects(PagingInfo pagingInfo = null)
{
    return Query<SampleTestProject>().ToList(pagingInfo);
}

// 错误：直接访问数据库（禁止）
View.AttachChildrenProperty(typeof(SampleTestProject), o =>
{
    return RT.Query<SampleTestProject>().ToList().AsEntityList(); // 禁止！
});
```

> **附加列表的元素也可以是 ViewModel（非实体）**：如 Asn 页"送货明细"页签挂 `AsnDeliveryDetailViewModel`（内存构建、不持久化）。VM 属性用 `P<VM>.Register` 注册（含 `[Label]`），数据由 Controller 查询后逐行组装（外部信息如仓库 Id 在方法入口取一次，循环内纯内存赋值，避免 N+1）。VM 上**不要**用 `RegisterReadOnly` 计算属性（VM 无实体配置）；列表页签取数仍走 `AttachChildrenProperty(typeof(VM), ...)` + Controller。

## 四、非重写视图方法属性显示规范

**在自定义的非重写视图方法中（如 `ConfigXxxView()`），属性必须显式使用 `.Readonly().Show(ShowInWhere.All)` 才能在前端显示。**

框架只自动处理 `ConfigListView()` 和 `ConfigDetailsView()` 两个重写方法中的属性显示。

```csharp
// 正确：自定义视图方法中使用 Readonly + Show
void ConfigWritingReportView()
{
    using (View.OrderProperties())
    {
        View.Property(p => p.No).Readonly().Show(ShowInWhere.All);
        View.Property(p => p.InspType).Readonly().Show(ShowInWhere.All);
    }
}

// 错误：自定义视图方法中忘记 Show（不会显示）
void ConfigWritingReportView()
{
    View.Property(p => p.No).Readonly();        // 不会显示！
}
```

---

## 五、视图配置方法与规则

| 方法 | 用途 | 关键规则 |
|---|---|---|
| `ConfigView()` | 界面入口 | 不在此配置列和命令 |
| `ConfigListView()` | 列表视图 | |
| `ConfigDetailsView()` | 表单视图 | **必须先 `View.FormEdit()` 再 `UseDefaultCommands()`，否则异常** |
| `ConfigQueryView()` | 查询视图 | **不用默认命令集**（会多出 view 权限） |
| `ConfigSelectionView()` | 下拉视图 | 不配操作命令 |
| `ConfigImportView()` | 导入视图 | 不配命令 |
| 自定义 `ConfigXxxView()` | 自定义视图 | `UseDefaultCommands()` 不生效；需 `DeclareExtendViewGroup` + `.Show()`（见第四节） |

### 5.1 查询条件配置（两种模式）

| 模式 | 做法 | 适用 |
|---|---|---|
| A. 实体自查询 | 主实体标 `[CriteriaQuery]`，ViewConfig 重写 `ConfigQueryView()` | 纯文本条件（StockingLevel、AbnormalInfoCategory） |
| B. 独立 Criteria 实体 | 主实体标 `[ConditionQueryType(typeof(XxxCriteria))]` + 独立查询实体 | **查询条件含引用属性（仓库/物料/人员等下拉数据源）时必须用 B** |

> **模式 A 的坑（YXC 实证）**：`[CriteriaQuery]` 主实体自查询下，`ConfigQueryView()` 里给引用属性配编辑器（如 `UseWarehouseEditor()`）**加载仓库数据源会报错**（框架原因）。涉及引用属性的条件走模式 B。

**模式 B 五件套（PackingLabelAdjustCriteria / SpecialItemMarkConfigCriteria 实证）**：

**① 主实体挂特性**（替换 `[CriteriaQuery]`，两者不可并存）：

```csharp
[RootEntity, Serializable]
[ConditionQueryType(typeof(SpecialItemMarkConfigCriteria))]   // 关联查询实体
public class SpecialItemMarkConfig : DataEntity { }
```

**② 查询实体**（领域层，与主实体同目录；`[Label]` 需 `using SIE.ObjectModel;`）：

```csharp
[QueryEntity, Serializable]
[Label("特殊物料标识配置查询实体")]
public class SpecialItemMarkConfigCriteria : Criteria          // 基类是 Criteria（非 DataEntity）
{
    // 引用属性：RefId + RefEntity 成对注册（nullable）
    [Label("仓库")]
    public static readonly IRefIdProperty WarehouseIdProperty =
        P<SpecialItemMarkConfigCriteria>.RegisterRefId(e => e.WarehouseId, ReferenceType.Normal);
    public double? WarehouseId
    {
        get { return (double?)GetRefNullableId(WarehouseIdProperty); }
        set { SetRefNullableId(WarehouseIdProperty, value); }
    }
    public static readonly RefEntityProperty<Warehouse> WarehouseProperty =
        P<SpecialItemMarkConfigCriteria>.RegisterRef(e => e.Warehouse, WarehouseIdProperty);

    /// <summary>重写此方法实现查询</summary>
    protected override EntityList Fetch()
    {
        return RT.Service.Resolve<SpecialItemMarkController>().GetSpecialItemMarkConfigQueryDatas(this);
    }
}
```

**③ Controller 查询**（Criteria → Where 逐条件映射）：

```csharp
public virtual EntityList<SpecialItemMarkConfig> GetSpecialItemMarkConfigQueryDatas(SpecialItemMarkConfigCriteria criteria)
{
    var query = Query<SpecialItemMarkConfig>();
    if (criteria.WarehouseId.HasValue)
        query.Where(p => p.WarehouseId == criteria.WarehouseId.Value);
    query.OrderBy(criteria.OrderInfoList);
    return query.ToList(criteria.PagingInfo, new EagerLoadOptions().LoadWithViewProperty());
}
```

**④ CriteriaViewConfig**（Web 层）：

```csharp
internal class SpecialItemMarkConfigCriteriaViewConfig : WebViewConfig<SpecialItemMarkConfigCriteria>
{
    protected override void ConfigView()
    {
        using (View.OrderProperties())
        {
            // ConfigView() 不在框架自动显示清单内（仅 ConfigListView/ConfigDetailsView 自动），
            // 属性必须显式 .Show()，否则查询区不出现该条件
            View.Property(p => p.WarehouseId).UseWarehouseEditor().Show();
        }
    }
}
```

**⑤ csproj**：新增文件必须同步更新项目 `.csproj`（红线 5）；`.js` 还须同时配置 `EmbeddedResource` + `None Remove`（见 07 §五）。

## 六、ChildrenProperty 强关联子表规范

### 6.1 ChildrenProperty 与 AttachChildrenProperty 的选择依据

| 方法 | 适用场景 | 说明 |
|------|---------|------|
| `View.ChildrenProperty(p => p.ChildList)` | 强关联子表 | 子表是当前实体的直接子实体，通过 `RegisterList` + `GetLazyList` 定义 |
| `View.AttachChildrenProperty(typeof(OtherEntity), ...)` | 弱关联/附加子表 | 关联外部实体，非直接子实体，适合松耦合的附加信息展示 |

**禁止强关联子表使用 `AttachChildrenProperty`。**

### 6.2 强关联子表完整示例

**实体定义**（主实体中）：

```csharp
#region 可停泊站点 FloorAgvStationDetailList
/// <summary>
/// 可停泊站点
/// </summary>
[Label("可停泊站点")]
public static readonly ListProperty<EntityList<FloorAgvStationDetail>> FloorAgvStationDetailListProperty = P<FloorAgvStationRelation>.RegisterList(e => e.FloorAgvStationDetailList);

/// <summary>
/// 可停泊站点
/// </summary>
public EntityList<FloorAgvStationDetail> FloorAgvStationDetailList
{
    get { return this.GetLazyList(FloorAgvStationDetailListProperty); }
}
#endregion
```

**视图配置**：

```csharp
// 强关联子表：直接使用 ChildrenProperty
View.ChildrenProperty(p => p.FloorAgvStationDetailList);

// 弱关联/附加子表：使用 AttachChildrenProperty
View.AttachChildrenProperty(typeof(AgvMaintenanceAbnormal), o =>
{
    var args = o as ChildPagingDataArgs;
    return null;
}).HasLabel("AGV异常情况");
```

> **注意**：`ChildrenProperty` 不需要 lambda 参数，直接传入实体属性表达式即可；`AttachChildrenProperty` 需要 lambda 接收 `ChildPagingDataArgs` 并返回数据源。

---

## 七、ViewConfig 其他常用方法

`AssignAuthorize(typeof(实体))` 授权可信实体 / `WithoutPaging()` 不分页 / `RemoveCommands(WebCommandNames.Copy)` 移除命令 / `ReplaceCommands(WebCommandNames.Delete, typeof(XxxCommand).FullName)` 替换命令 / `ClearCommands()` 清除命令 / `UseClientOrder()` 内存排序 / `UseLayoutSize(0.4, 0.6)` 父子比例（默认 1:1）/ `UseChildrenAsHorizontal()` 子列表水平布局 / `DisableEditing()` 禁止编辑 / `DraggableForTree()` 禁止树拖动 / `using (View.DeclareBand("test"))` 表格列分组 / `using (View.DeclareGroup("提示信息"))` 表单分组 / `UseGridSelectionModel()` 行选择模式 / `RequierModels(typeof(A), typeof(B))` 额外引用实体

## 八、属性设置

- `ShowInList(width: 300)` 列宽 / `HasOrderNo(4)` 列顺序 / `FixColumn()` 冻结列
- `.Readonly(表达式)` / `.Visibility(表达式)`（表格仅 true/false）；`PersistenceStatus` 状态：`Unchanged / Modified / New / Deleted`
- `.UseDataSource((source, pagingInfo, keyword) => ...)` 引用属性自定义数据源
- 查询必填：`.UseTextEditor(p => p.AllowBlank = false)`

## 九、JS 常用 API 速查

- **消息**：`SIE.Msg.showMessage / showError / showWarning / askQuestion / confirm / wait / hide / close / showToast`
- **视图方法**：`view.getParent() / getChildren() / getCurrent() / refreshData([id]) / loadChildData([true]) / syncCmdState([view, recursion]) / getControl() / getMeta() / getData() / setData() / getToken() / findCmd() / findChild("全命名空间")`
- **其他**：`entity.markSaved()` / `CRT.Workbench.closeCurrentTab()` / `CRT.Context.GlobalContext.getContext('userInfo')` 登录人 / `CRT.Context.PageContext.getParams()` addPage 参数

## 十、默认值设置

- 后端：`View.Property(p => p.Name).DefaultValue("Test")`；枚举 `.DefaultValue((int)ItemType.Product)`；日期 `.DefaultValue(DateTime.Today).UseDateEditor()`；引用属性 `.DefaultValue(RT.Service.Resolve<XxxController>().GetXxx())`
- 前端：`entity.set('属性名', value)`；**引用属性需同时设 id 和 `_Display` 显示名**

## 十一、无独立菜单的配置实体（主档列表按钮快捷入口）

适用：低频维护的配置/规则（如备货等级管理），不占功能菜单树。

三件套（StockingLevel / SpecialItemMarkConfig 实证）：

**1. 入口 JS 命令**（纯前端，无 cs）：

```javascript
SIE.defineCommand('SIE.Web.WMS.Common.Commands.SpecialItemMarkConfigCommand', {
    meta: { text: "特殊物料标识配置", group: "config", iconCls: "icon-DistributeObjectsHorizontal icon-blue" },
    execute: function (listView, source) {
        CRT.Workbench.addPage({
            title: '特殊物料标识配置'.t(),
            entityType: 'SIE.WMS.Common.SpecialItemMarkConfig',   // 实体全名（命名空间.类名）
            module: listView.module,
            ignoreQuery: false,
            isAggt: true   // 聚合页（列表+详情一体）
        });
    }
});
```

**2. 主档 ViewConfig 挂载**（字符串全名，跨模块无编译依赖；js 以 EmbeddedResource 随 DLL 分发，见 07 §五 csproj 红线）：

```csharp
// ItemViewConfig.ConfigListView
View.UseCommand("SIE.Web.Items.Items.Commands.StockingLevelCommand");          // 备货等级（同模式先例）
View.UseCommand("SIE.Web.WMS.Common.Commands.SpecialItemMarkConfigCommand");
```

**3. 权限挂载**（无菜单则无功能权限节点，挂到宿主实体）：

```csharp
// 配置实体 ViewConfig.ConfigView
this.View.AssignAuthorize<SpecialItemMarkConfig>(typeof(Item));   // 权限跟随物料功能
```

> 注意：该模式**不要**再在 Module.cs 注册 `WebModuleMeta`，否则菜单+按钮双入口。
