# WPF 组件规范

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。

## 一、WPF ViewConfig
继承 WPFViewConfig<T>:

```csharp
[ManagedProperty.CompiledPropertyDeclarer]
public class CustomerViewConfig : WPFViewConfig<Customer>
{
    protected override void ConfigView()
    {
        View.InlineEdit();
        View.UseDefaultCommands();
        View.UseDetail(dialogHeight: 400);
    }

    protected override void ConfigListView()
    {
        View.AddBehavior(typeof(CustomerChangeBehavior));
        View.Property(p => p.Code);
        View.Property(p => p.Name);
        View.Property(p => p.State).Readonly();
        View.ChildrenProperty(p => p.CustomerAddressList);
    }
}
```

## 二、ViewBehavior
继承 ViewBehavior:

```csharp
public class CustomerChangeBehavior : ViewBehavior
{
    private bool isRun;
    private Entity Current;

    protected override void OnAttach()
    {
        var view = View as ListLogicalView;
        if (view != null)
            view.CurrentChanged += Customer_CurrentChanged;
    }
}
```

## 三、ListViewCommand
继承 ListViewCommand:

```csharp
[Command(ImageName = "Cancel", Label = "禁用", ToolTip = "禁用", GroupType = CommandGroupType.Business)]
public class CustomerDisableCommand : ListViewCommand
{
    public override bool CanExecute(ListLogicalView view)
        => (view?.Current as Customer)?.State != State.Disable;

    public override void Execute(ListLogicalView view)
    {
        if (CRT.MessageService.AskQuestion("确定禁用选中的资料?".L10N()))
        {
            // 数据操作经 Controller（红线 1：命令内禁止直访 RF/DB），Controller 内再保存
            RT.Service.Resolve<CustomerController>().Disable((view.Current as Customer));
        }
    }
}
```

## 四、PagingLookUpEditor
继承 PagingLookUpEditor:

```csharp
public class CustomerLookupEditor : PagingLookUpEditor
{
    public const string EditorName = "CustomerLookupEditor";

    protected override EntityList GetDataSourceCore(Entity source, PagingInfo pagingInfo, string keyword, IManagedProperty titleProperty)
        => RT.Service.Resolve<CustomerController>().GetCustomer(keyword, pagingInfo);
}
```

## 五、WPF Extension 方法
放在 (Extentions)/EntityPropertyViewMetaExtension.cs:

```csharp
public static class EntityPropertyViewMetaExtension
{
    public static WPFEntityPropertyViewMeta<T> UseCustomerEditor<T>(this WPFEntityPropertyViewMeta<T> meta, Action<CustomerLookUpEditorConfig> action = null)
    {
        meta.ViewMeta.EditorName = CustomerLookupEditor.EditorName;
        var config = new CustomerLookUpEditorConfig();
        meta.ViewMeta.Config = config;
        action?.Invoke(config);
        return meta;
    }
}
```

## 六、WPF Layout
实现 ILayoutControl 接口:

```csharp
public partial class PackingLayout : UserControl, ILayoutControl
{
    public virtual void Arrange(UIComponents components)
    {
        if (components.CommandsContainer != null)
            toolBar.Content = components.CommandsContainer.Control;
        mainView.Content = components.Main.Control;
    }
}
```
