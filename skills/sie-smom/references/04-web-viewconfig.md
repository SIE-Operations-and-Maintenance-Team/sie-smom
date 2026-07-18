> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：06-____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：WebViewConfig·常用方法·AttachChildrenProperty分页·非重写视图属性显示

---

# ViewConfig 视图配置规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。
> **内容概要**:Web ViewConfig、常用 ViewConfig 方法速查、AttachChildrenProperty 分页规范、非重写视图方法属性显示规范。

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
| View.FormEdit() | 表单编辑模式 |
| View.InlineEdit() | 行内编辑模式 |
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
