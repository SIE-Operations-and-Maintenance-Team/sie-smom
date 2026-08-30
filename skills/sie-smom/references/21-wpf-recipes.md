# WPF 端配方库

## 配方索引

| # | 任务 | 节 |
|---|---|---|
| 1 | 弹窗命令-录入数据（四文件模式） | 一 |
| 2 | WPF 行为（ViewBehavior 全家） | 二 |
| 3 | WPF 客制化编辑器（三件套模式 + 7 例） | 三 |
| 4 | 经验案例（点位选择/按钮换位/PDF 打印/进度框） | 四 |
| 5 | 控件案例（卡片/多选/员工卡/圆角按钮） | 五 |
| 6 | 通用工具（动画/打印/等待框/消息框） | 六 |

---

## 一、WPF 弹窗命令-录入数据

**场景**：列表选中多条记录 → 弹对话框填写业务数据 → 调 Controller 批量处理（审核、异常处理、批量赋值等）。参考案例 `AbnormalLeaveCommand`（异常离岗）。

**四文件结构**：

| 文件 | 职责 | 所在工程 |
|---|---|---|
| Command.cs | 命令入口：CanExecute → 弹窗 → 调 Controller | SIE.Wpf.xxx |
| ViewModel.cs | 弹窗表单数据模型（含 ValidateData()） | SIE.xxx（共享层） |
| ViewModelViewConfig.cs | 弹窗表单 UI 布局 | SIE.Wpf.xxx |
| Controller.cs | 业务逻辑：校验 + 事务 + 批量更新 | SIE.xxx（共享层） |

**① ViewModel**（共享层，必须 `[RootEntity] + [Serializable]`，`P<T>.Register` 属性模式）：

```csharp
[Label("异常离岗")]
[RootEntity, Serializable]
public class AbnormalLeaveViewModel : ViewModel
{
    [Label("离岗原因")]
    public static readonly Property<string> LeaveReasonProperty = P<AbnormalLeaveViewModel>.Register(e => e.LeaveReason);
    public string LeaveReason { get { return GetProperty(LeaveReasonProperty); } set { SetProperty(LeaveReasonProperty, value); } }
    // LeaveDuration(decimal?)、Remark(string) 同模式...
    public void ValidateData()
    {
        DataChecker.CheckNotEmpty(LeaveReason, "离岗原因", true);
        DataChecker.CheckNotEmpty(Remark, "备注说明", true);
    }
}
```

**② ViewModelViewConfig**（弹窗 UI）：

```csharp
public class AbnormalLeaveViewModelViewConfig : WPFViewConfig<AbnormalLeaveViewModel>
{
    protected override void ConfigDetailsView()
    {
        View.AssignAuthorize(typeof(EmpAttendRecord));
        View.ClearCommands();   // 弹窗不带命令按钮，框架自动加"确认/取消"
        using (View.OrderProperties())
        {
            View.Property(p => p.LeaveReason)
                .UseSelectionViewMeta(new SelectionViewMeta
                {
                    SelectionEntityType = typeof(LeavePositionReason),
                    SelectedValuePath = LeavePositionReason.ReasonProperty,
                    DisplayMemberPath = LeavePositionReason.ReasonProperty,
                    DataSourceProvider = (e, c, r) => RT.Service.Resolve<LeavePositionReasonController>().SearchNotNormalReason(r, c)
                })
                .UseEditor(WPFEditorNames.EntityDropDown)
                .Show();
            View.Property(p => p.LeaveDuration).UseSpinEditor(p => { p.MinValue = 0; p.Decimals = 2; }).Show();
            View.Property(p => p.Remark).ShowInDetail(rowSpan: 5).UseMemoEditor().Show();
        }
    }
}
```

**③ 命令**（继承 `ListViewCommand`）：

```csharp
[Command(ImageName = "TableEdit", Label = "异常离岗", ToolTip = "异常离岗", GroupType = CommandGroupType.Business)]
public class AbnormalLeaveCommand : ListViewCommand
{
    public override bool CanExecute(ListLogicalView view)
    {
        var selected = view.SelectedEntities.OfType<EmpAttendRecord>().ToList();
        if (!selected.Any()) return false;
        foreach (var item in selected)
            if (item.PositionState != PositionState.OnPosition) return false;   // 业务状态校验
        return true;
    }

    public override void Execute(ListLogicalView view)
    {
        var viewModel = new AbnormalLeaveViewModel();
        if (PopSelectionView(viewModel) == 0)   // 0 = 确认
        {
            viewModel.ValidateData();           // 二次校验
            var idList = view.SelectedEntities.OfType<EmpAttendRecord>().Select(p => p.Id).ToList();
            WaitUtil.ShowWait((dialog) =>        // 等待框包裹后端调用
            {
                RT.Service.Resolve<EmpAttendRecordController>().AbnormalLeave(idList, viewModel);
            });
            CRT.MessageService.ShowInstantMessage("异常离岗处理完毕".L10N(), "提示".L10N(), 3);
            view.QueryView.TryExecuteQuery();    // 刷新列表
        }
    }

    private int PopSelectionView(AbnormalLeaveViewModel viewModel)
    {
        var template = new DetailsUITemplate<AbnormalLeaveViewModel>();   // 自动匹配 WPFViewConfig<T>
        template.ViewGroup = ViewConfig.DetailsView;
        var ui = template.CreateUI();
        ui.MainView.Data = viewModel;
        return CRT.Workbench.ShowDialog(ui, (v) => { v.Title = "异常离岗".L10N(); v.Width = 400; v.Height = 300; });
    }
}
```

**④ Controller**（防御性二次校验 + 事务）：

```csharp
public virtual void AbnormalLeave(IEnumerable<double> ids, AbnormalLeaveViewModel model)
{
    DataChecker.CheckNotNull(model, nameof(model));
    model.ValidateData();                                     // Controller 内再校验一次
    var now = RF.Find<EmpAttendRecord>().GetDbTime();
    using (var trans = DB.TransactionScope(TechEntityDataProvider.ConnectionStringName))
    {
        var list = RT.Service.Resolve<CommonEntityController>().GetEntityListById<EmpAttendRecord>(ids, null);
        foreach (var entity in list)
        {
            entity.LeaveTime = now; entity.PositionState = PositionState.OffPosition;
            entity.LeaveReason = model.LeaveReason; /* ...其余字段赋值... */
            RF.Save(entity);
        }
        trans.Complete();
    }
}
```

**⑤ 注册**：列表 ViewConfig 中 `View.AddBehavior(new EnableSelectBoxBehavior());`（多选需要勾选框）+ `View.UseCommands(typeof(AbnormalLeaveCommand), WPFCommandNames.Export);`

---

## 二、WPF 行为（ViewBehavior）

**基类**：`SIE.Wpf.ViewBehavior`，核心重写 `OnAttach()`；注册 `View.AddBehavior(new XxxBehavior());`（或 `AddBehavior(typeof(XxxBehavior))`）。

### 2.1 常用行为速查

```csharp
// 行变色（DevExpress FormatCondition）/行高/字体：
var listView = (ListLogicalView)View;
var grid = listView.Control;
var tableView = grid.View as TableView;
grid.FontSize = 14;
tableView.RowMinHeight = 40;
tableView.FormatConditions.Add(new FormatCondition
{
    ApplyToRow = true,
    FieldName = Xxx.DM_PreviewedProperty.Name,
    Value1 = true,
    ValueRule = ConditionRule.Equal,
    Format = new Format { Background = System.Windows.Media.Brushes.LightGreen }
});

// 列表勾选框 + 多选：
var grid = View.Control as GridControl;
(grid.View as TableView).ShowCheckBoxSelectorColumn = true;
grid.SelectionMode = MultiSelectMode.MultipleRow;

// 列表双击编辑：
((ListLogicalView)View).Control.View.AllowEditing = true;

// 序号列宽度：
tableView.IndicatorWidth = 80;
```

### 2.2 放大界面行为（现成 `EnlargeUIBehavior`）

```csharp
View.AddBehavior(new EnlargeUIBehavior());          // 默认 16/40
View.AddBehavior(new EnlargeUIBehavior(20, 60));    // (字体, 行高)
```

实现：ListLogicalView 设 `grid.FontSize` + `tableView.RowMinHeight`；DetailLogicalView 遍历 `PropertyEditors` 放大 LabelControl 与编辑控件字体。

### 2.3 动态显示子页签

模式：`DetailLogicalView` + `Control.Loaded` 事件（`view.Closed` 时解绑防泄漏）→ `view.LayoutControl.GetLogicalChild<DXTabControl>().Items` 按业务规则移除/保留 DXTabItem：

```csharp
protected override void OnAttach()
{
    var view = View as DetailLogicalView;
    if (view != null)
    {
        view.Control.Loaded += Control_Loaded;
        view.Closed += (s, e) => { view.Control.Loaded -= Control_Loaded; };
    }
}
// Control_Loaded 中：按 current.WorkCenter.Resource.Name 决定保留哪些 tab，把不匹配的 DXTabItem 从 items 移除
```

### 2.4 列表自动列宽（现成 `UseAutoColumnSize`）

```csharp
View.UseAutoColumnSize();                                            // 全部列
View.UseAutoColumnSize(Item.NameProperty.Name);                      // 指定列
View.UseAutoColumnSizeExcept(Item.NameProperty.Name);                // 例外列
```

实现：`ListAutoColumnWidthBehavior` 监听 `listView.DataChanged` + `Data.CollectionChanged`，对目标列 `tableView.BestFitColumn(column)` 并手动加宽 8（列头显示不全问题）；配置经 `WPFEntityViewMeta.SetExtendedProperty(name, Dictionary<string,bool>)` 传递。

### 2.5 输入框屏蔽中文输入法

`TypeWritingBehavior(List<IManagedProperty>)`：DetailView 的目标编辑器 `GotKeyboardFocus` 切英文输入法、`LostKeyboardFocus` 切回中文。底层 `BanInputMethod` 用 Win32 API：

```csharp
[DllImport("user32.dll")] static extern bool PostMessage(IntPtr hhwnd, uint msg, IntPtr wparam, IntPtr lparam);
[DllImport("user32.dll")] static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);
// ChangeUSLanguage: PostMessage(0xffff, 0x0050, IntPtr.Zero, LoadKeyboardLayout("00000409", 1)) 屏蔽中文（Ctrl+Shift 也切不回，Win+空格可切）
// ChangeZHLanguage: 同上但 "00000804"
```

用法：`View.AddBehavior(new TypeWritingBehavior(new List<IManagedProperty> { Xxx.ScanCodeProperty }));`

---

## 三、WPF 客制化编辑器（三件套模式）

**通用模式**（7 个编辑器全部遵循）：

1. **编辑器类**：继承 `PropertyEditor<TConfig>`（自绘控件 + 手动绑定）或 `BaseEditor<TConfig>`（走 DevExpress EditSettings）或直接继承现成编辑器（如 `SpinEditor`/`ErrorEditor`）。
2. **注册**（UIModule 派生类）：`app.AllModulesIntialized += (o,e) => { AutoUI.BlockUIFactory.PropertyEditorFactory.Set(EditorName, typeof(XxxEditor)); };`
3. **扩展方法**：`meta.ViewMeta.EditorName = EditorName; meta.ViewMeta.Config = config;`

### 3.1 PropertyEditor 模式（LCD 显示编辑器）

```csharp
internal class LCDEditor : PropertyEditor<EditorConfig>
{
    protected override DependencyProperty BindingProperty() { return TextEdit.TextProperty; }
    protected override FrameworkElement CreateEditingElement()
    {
        var control = new TextEdit() {   // 黑底红字大字体只读
            Foreground = Brushes.Red, Background = Brushes.Black, FontSize = 32, IsReadOnly = true
        };
        var styles = new Style(typeof(TextEdit));
        styles.Setters.Add(new Setter(TextEdit.FontFamilyProperty, new FontFamily(
            new Uri("pack://application:,,,/", UriKind.Absolute), "./Resources;component/Fonts/#Quartz Regular")));
        control.Style = styles;
        control.SetBinding(GetBindingProperty(), CreateBinding());   // 手动绑定
        SetAutomationElement(control);
        return control;
    }
}
// 绑定 OneWay：binding.Mode = BindingMode.OneWay
// 用法：View.Property(p => p.Xxx).UseLCDEditor();
```

### 3.2 BaseEditor + ListBoxEdit 单选组模式（布尔/枚举单选编辑器）

`BoolRadioEditor` / `EnumRadioEditor` 都基于 `BaseEditor<TConfig>` + DevExpress `ListBoxEdit` + `RadioListBoxEditStyleSettings`：

```csharp
protected override BaseEditSettings CreateEditSettingsCore()
{
    var settings = new XxxEditorSettings();   // ListBoxEditSettings 派生 + IEditorSettings，AssignToEditAction 注入事件
    settings.StyleSettings = new RadioListBoxEditStyleSettings();
    settings.ValueMember = "Value"; settings.DisplayMember = "Display";
    settings.Items.AddRange(BoolItems);       // 布尔：[{Value:true,Display:"是"},{Value:false,Display:"否"}]
    // 枚举：Enum.GetValues((Config.EnumType ?? Meta.PropertyType).IgnoreNullable()) 反射生成，Display = item.ToLabel()

    var textBlockFactory = new FrameworkElementFactory(typeof(TextBlock));
    textBlockFactory.SetBinding(TextBlock.TextProperty, new Binding("Display"));
    textBlockFactory.SetBinding(TextBlock.ForegroundProperty, new Binding("Value")
    {
        Converter = new XxxForegroundConverter()   // 布尔：true绿/false红；枚举：按值索引映射 Colors 列表（越界取最后）
    });
    settings.ItemTemplate = new DataTemplate { VisualTree = textBlockFactory };

    var panelFactory = new FrameworkElementFactory(typeof(StackPanel));
    panelFactory.SetValue(StackPanel.OrientationProperty, Orientation.Horizontal);   // 横排
    settings.ItemsPanel = new ItemsPanelTemplate(panelFactory);
    return settings;
}
// 用法：
// View.Property(p => p.Qualified).UseBoolRadioEditor();
// View.Property(p => p.Status).UseEnumRadioButtonEditor(p => { p.FontSize = 20; p.Colors = new Brush[] { Brushes.Green, Brushes.Red }; p.EnumType = typeof(StatusEnum); });
```

表格编辑场景：`AssignToEdit` 里挂 `Control.DataContextChanged`，从 `EditGridCellData.RowData.Row` 取实体引用。

### 3.3 错误提示编辑器（带闪烁）— 继承现成 ErrorEditor

```csharp
public class ErrorEditorEx : ErrorEditor
{
    public new const string EditorName = "Customized_ErrorEditorEx";
    protected override FrameworkElement CreateEditingElement()
    {
        var textEdit = base.CreateEditingElement() as TextEdit;
        var anim = new DoubleAnimation { From = 1.0, To = 0.1, Duration = TimeSpan.FromMilliseconds(500), AutoReverse = true, RepeatBehavior = new RepeatBehavior(5.0) };
        var sb = new Storyboard();
        Storyboard.SetTarget(anim, textEdit);
        Storyboard.SetTargetProperty(anim, new PropertyPath(UIElement.OpacityProperty));
        sb.Children.Add(anim);
        sb.Completed += (s, e) => { textEdit.Opacity = 1.0; };
        textEdit.EditValueChanged += (s, e) =>           // 文本空→非空时重新闪烁
        {
            if (!string.IsNullOrEmpty(e.NewValue as string)) { sb.Stop(textEdit); textEdit.Opacity = 1.0; sb.Begin(textEdit, true); }
        };
        sb.Begin(textEdit, true);
        return textEdit;
    }
}
// 用法：View.Property(p => p.Error).UseEditor(ErrorEditorEx.EditorName).ShowInDetail(columnSpan: 4, height: 0, hideLabel: true);
```

### 3.4 计算器编辑器（触屏场景）

`CalculatorEditor : PropertyEditor<CalculatorEditorConfig>`（`CalculatorEditorConfig : SpinEditorConfig` 增 Width/Height/ShowPropertyValue）：`CreateEditingElement` 返回显示 Button，点击 `ShowEditor()` 弹 `CRT.Workbench.ShowDialog` 内置 `Calculator` 控件；关闭时 `ConfigLimit`（Decimals 四舍五入 + Min/Max 钳制）后 `Convert.ChangeType(result, Meta.PropertyType)` 回写。用法：`View.Property(p => p.Type).UseCalculatorEditor();`

### 3.5 可缩放数值编辑器（触屏场景）— 继承现成 SpinEditor

```csharp
public class EnlargeSpinEditor : SpinEditor
{
    public EnlargeSpinEditor() { this.ControlCreated += (s, e) => (this.Control as SpinEdit).Loaded += (obj, args) =>
    {
        var editor = obj as SpinEdit;
        editor.FontSize = Math.Max(editor.ActualHeight / 2, 14);
        editor.GetVisualChild<ButtonContainer>().Width = Math.Max(editor.Width / 3, 20);
    }; }
}
// 用法：View.Property(p => p.PackageNum).ShowInDetail(height: 0).UseEnlargeSpinEditor(p => { p.MinValue = 1; });
```

### 3.6 显示编辑器（只读富样式文本）

`DisplayEditor : BaseEditor<DiaplayEditorConfig>`（`DiaplayEditorConfig : TextEditorConfig`，继承 Mask/DisplayFormat/NullText/MaxLength）：重写 `CreateLabelElement()`（WrapPanel + 可选 PackIcon 图标 + LabelForeground/LabelFontWeight 文本）与 `CreateEditingElement()`（复用平台文本编辑器设只读/无边框/ValueForeground）。用法：

```csharp
View.Property(p => p.BatchRule).UseDisplayEditor(p => p.XType = "BatchRuleAndQtyEditor");
View.Property(p => p.WoNo).UseDisplayEditor(p => { p.FontSize = 20; p.LabelForeground = Brushes.Green; p.ValueForeground = Brushes.Blue; p.LabelFontWeight = FontWeights.SemiBold; });
```

---

## 四、经验案例

### 4.1 点位选择控件（图形化弹框录入）

纯代码构建 `DataGrid`（`SelectionUnit = Cell`、只读、`AddHandler(DataGridCell.MouseLeftButtonUpEvent)` 点选/反选变色）：坐标 `A1,B3,C8` 字符串 ↔ `Dictionary<"A00001","A1">`（key 用 `row + col.PadLeft(5,'0')` 排序稳定）双向转换；点击沿 `VisualTreeHelper.GetParent` 上溯找 `DataGridCell` 取行列索引；`Loaded` 时按 recordDic 初始化底色；外层 `DockPanel`（底部 TextBlock 实时显示已选）→ `CRT.Workbench.ShowDialog`。

### 4.2 调整按钮位置（按钮栏 → 表单内）

场景：UITemplate（`CollectionUITemplate` 派生）`OnUIGenerated` 中把命令按钮从按钮栏挪到表单内：

```csharp
void ResetPackButton(DetailLogicalView packingView)
{
    ItemsControl buttonCtn = packingView.CommandsContainer;
    ClientCommand packCmd = packingView.Commands.FirstOrDefault(p => p.GetType() == typeof(HrdPackingCommand));
    if (buttonCtn == null || packCmd == null)
        throw new ValidationException("当前账号无打包按钮权限，请联系管理员处理".L10N());
    SimpleButton packCmdBtn = null;
    foreach (var item in buttonCtn.Items)
        if (item is SimpleButton button && button.Command == packCmd.UICommand) packCmdBtn = button;
    buttonCtn.Items.Remove(packCmdBtn);
    foreach (var editor in packingView.PropertyEditors)
    {
        if (editor is BarcodeEditor barcodeEditor)
        {
            var parent = barcodeEditor.Control.GetLogicalParent<FormPanel>();
            if (parent != null)
            {
                int index = parent.Children.IndexOf(barcodeEditor.Control);
                var dockPanel = new DockPanel();
                dockPanel.Children.Add(packCmdBtn);
                FormPanel.SetColumnSpan(dockPanel, 1);
                parent.Children.Insert(index + 1, dockPanel);   // 插到条码框下一行
            }
        }
    }
}
```

UITemplate 要点：构造函数 `base(typeof(XxxUITemplate))` + `ViewGroup`；`DefineBlocks()` 中 `block.Layout = new LayoutMeta(typeof(XxxLayout))`；`OnUIGenerated(ControlResult ui)` 中 `ui.MainView as DetailLogicalView`、`CreateDetailListControl(view, data, ViewConfig.ListView)` 建子列表 Tab。

### 4.3 PDF 文件打印（PdfiumViewer）

NuGet：`PdfiumViewer` + `PdfiumViewer.Native.x86.v8-xfa` + `PdfiumViewer.Native.x86_64.v8-xfa`。WpfClient 生成后事件（pdfium.dll 必须移到 Lib 子目录）：

```bat
if not exist "$(TargetDir)Lib\x64" md "$(TargetDir)Lib\x64"
if not exist "$(TargetDir)Lib\x86" md "$(TargetDir)Lib\x86"
move /Y "$(TargetDir)x64\pdfium.dll" "$(TargetDir)Lib\x64\"
move /Y "$(TargetDir)x86\pdfium.dll" "$(TargetDir)Lib\x86\"
```

```csharp
using (var document = PdfDocument.Load(filePath))
using (var printDocument = document.CreatePrintDocument())
{
    printDocument.PrinterSettings.PrinterName = printerName;
    printDocument.DocumentName = fileName;
    printDocument.PrintController = new StandardPrintController();
    // 进度：printDocument.PrintPage += (s, args) => 更新 WaitDialog 进度（pageNum/totalPage）
    printDocument.Print();
}
```

**坑点**：报"无法加载 DLL pdfium.dll" = 生成后事件未配置。

### 4.4 进度提示框（WaitDialog）

```csharp
WaitDialog _waitDialog = new WaitDialog() { Text = "提示文字".L10N() };
_waitDialog.ShowDialog();
// 线程中更新进度（0-100）：
_waitDialog.Dispatcher.Invoke(() => _waitDialog.ProgressValue = new ProgressValue { Percent = percent });
```

---

## 五、控件案例

### 5.1 卡片布局控件 CardLayoutControl

UserControl + 两个依赖属性（`TitleText` string 默认"标题"、`CardContent` object），XAML 中 `dxlc:LayoutControl/LayoutGroup`（标题 Border+TextBlock + 主体 Border+`ContentPresenter Content="{Binding CardContent,...}"`）：

```xml
<components:CardLayoutControl TitleText="基础信息">
    <components:CardLayoutControl.CardContent>
        <StackPanel><TextBlock Text="工单号：WO..."/></StackPanel>
    </components:CardLayoutControl.CardContent>
</components:CardLayoutControl>
```

### 5.2 通用多选控件 GeneralSelectControl

候选区（按钮网格）+ 已选区（标签网格）双区域。**依赖属性**：`Title`、`SourceItems`(ObservableCollection<ISelectableItem>)、`IsSingleSelect`(默认 false)、`BottomAreaVisibility`、`ColumnsPerRow`(默认 4)。**只读**：`SelectedSourceView`（ICollectionView 实时过滤 IsSelected=true）、`CandidateSourceView`（过滤 IsHide!=true）、`SelectedCountText`（"X个"）。**事件**：`ItemBeforeSelected`（e.Cancel=true 阻止）/`ItemSelected`/`ItemUnselected`。

**数据项接口 ISelectableItem**：`DisplayText / SecondDisplayText / IsSelected / IsSelectedFixed（固定选中不可取消）/ IsDisabled / IsHide（候选区隐藏，已选不受影响）`。基类：`SelectableItem`（基础）、`SelectableItem<T>`（带 double Id + 泛型实体）、`SelectableItemString<T>`（string Id），均继承 `ObservableObject`。

**关键机制**：双 `ListCollectionView` + `LiveFilteringProperties` 实时过滤；`OnSourceItemsChanged` 手动管理 CollectionChanged 订阅/解绑防内存泄漏；单选模式点击时先清其他已选（跳过 Fixed/Disabled）；自定义 `ColumnWrapPanel : Panel`（固定列数换行，每行高度独立，区别于 UniformGrid）。

**视觉状态**：选项按钮——选中蓝边框 #02A7F0、禁用/固定灰底 #C8C8C8；已选标签——蓝底白字 + 右上红 X（禁用/固定时 X 隐藏、灰底）。

### 5.3 员工信息卡片 EmployeeInfoCard

纯 DataContext 绑定（Photo/Name/Code/V_WorkshopName 等），照片 byte[] → Image.Source 用 `ByteToImageConverter`：

```csharp
public class ByteToImageConverter : MarkupExtension, IValueConverter
{
    public override object ProvideValue(IServiceProvider sp) => this;
    public object Convert(object value, ...)
    {
        if (value is not byte[] byteArray || byteArray.Length == 0) return null;
        try
        {
            var base64 = System.Text.Encoding.UTF8.GetString(byteArray).Split(',', 2).Last();   // 兼容 data:image;base64, 前缀
            var bytes = System.Convert.FromBase64String(base64);
            var bitmap = new BitmapImage();
            using (var ms = new MemoryStream(bytes))
            {
                bitmap.BeginInit(); bitmap.CacheOption = BitmapCacheOption.OnLoad; bitmap.StreamSource = ms;
                bitmap.EndInit(); bitmap.Freeze();   // Freeze 保证跨线程渲染安全
            }
            return bitmap;
        }
        catch { return null; }
    }
}
// XAML 可直接 {converter:ByteToImageConverter}，无需 Resources 声明
```

### 5.4 圆角按钮 RoundButton（代码建模板）

`RoundButton : Button`：`CornerRadius` 依赖属性（默认 8）；`LoadTemplate()` 用 `FrameworkElementFactory` 构建 Border+ContentPresenter 视觉树（**避免 XamlReader 解析 XML 命名空间异常**）；Triggers 设悬浮 Opacity=0.8 / 按下 0.5 / 禁用 0.3。颜色变体零 XAML：`RoundButtonBlue`(白字 #02A7F0)、`RoundButtonGreen`(#02BF16)、`RoundButtonGrey`(#969696)、`RoundButtonRed`(#E02A2A)。

---

## 六、通用工具

### 6.1 动画工具 StoryboardUtil.FlashControl

```csharp
// 校验失败：输入框闪烁 3 秒并聚焦
txtBarcode.FlashControl(3.0);
```

扩展方法：`control.Focus()` + 保存原样式（Opacity/BorderBrush）→ DoubleAnimation(1.0→0.1, 500ms, AutoReverse) 按 `RepeatBehavior(TimeSpan.FromSeconds(duration))` 闪烁 → `Completed` 恢复原样式。

### 6.2 通用打印工具 PrintUtil（WPF 版）

```csharp
new PrintUtil().PrintEntityList(
    templateId: 1001, printer: @"\\PRINT-SERVER\HP_Laser",
    getDataFuncDic: new Dictionary<Type, Func<IEnumerable<object>>>
    {
        { typeof(BarcodePrintEntity), () => barcodeList.Cast<object>() },
    },
    copy: 2,
    beforePrint: () => { /* 开始前 */ },
    afterPrint: () => { /* 成功后回写状态 */ });
```

流程：DataChecker 校验打印机/模板 → `Type.GetType(template.EntityType)` 反射 IPrintable → 字典匹配取数方法 → `PrintsController.DownloadPrintTemplate(template.Id)` 下载 → `ReportFactory.Current.GetReportByExtension(template.Type).Print(printable, filePath, printer, getDataFunc, afterPrint回调, copy)`。

### 6.3 异步等待框 WaitUtil.ShowWait

```csharp
Exception ex = WaitUtil.ShowWait((dialog) =>
{
    var result = BarcodeService.Query(barcode);                       // 耗时操作
    dialog.Dispatcher.Invoke(() => dialog.Text = "正在保存数据".L10N());  // 可更新提示文字
    SaveResult(result);
}, tips: "正在查询条码信息".L10N());     // 默认 throwException=true 直接抛异常；false 则返回 ex
```

实现要点：Owner 取 `ClientRuntime.Workbench.DialogContents.LastOrDefault() as Window`（未加载则回退 `Application.Current.MainWindow`）；`BrushesThemeKeyExtension` 绑定主题色跟随系统主题；任务经 `WithCurrentThreadContext()` + `Task.Run` 执行，`Dispatcher.BeginInvoke(() => win.DialogResult = true)` 关窗。

### 6.4 自定义消息对话框 MsgUtil

```csharp
MsgUtil.ShowMessage("操作成功！");                                  // 基础（默认"确定"）
var result = MsgUtil.ShowMessage("确定删除吗？", title: "确认删除",
    setButtons: (win) => new Button[] { btnNo(DialogResult=false), btnYes(DialogResult=true) });   // 自定义按钮
MsgUtil.ShowCenterMessage("扫码成功！", title: "扫码提示", messageFontSize: 36);   // 居中大字
MsgUtil.ShowMessage(longMsg, configureWindow: win => { win.Width = 600; win.Height = 400; win.ResizeMode = ResizeMode.CanResize; });
```

基于 DevExpress `ThemedWindow`（`ShowTitle = title.IsNotEmpty()`）：DockPanel = 顶部 ScrollViewer（TextBlock 自动换行，长消息出滚动条）+ 底部 WrapPanel 按钮栏；返回 `bool?`。
