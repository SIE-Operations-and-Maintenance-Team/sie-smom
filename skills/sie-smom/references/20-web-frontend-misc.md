# Web 前端基础与界面配方库

## 配方索引

| # | 任务 | 节 |
|---|---|---|
| 1 | 前端调用后台（命令/DataQueryer） | 一 |
| 2 | Web 事件 mon/fireEvent/mun | 二 |
| 3 | Web 消息提示 SIE.Msg | 三 |
| 4 | Web 插件（页面初始化） | 四 |
| 5 | Web 业务模块工程（UIModule） | 五 |
| 6 | 界面处理（控件/Workbench/AutoUI/弹框/日期） | 六 |
| 7 | 客制化界面三档 | 七 |
| 8 | Web 扩展视图 | 八 |
| 9 | 前端 Entity / View 类 API | 九 |
| 10 | Web 视图配置方法 | 十 |
| 11 | Web 数据处理（用户/组织/刷新） | 十一 |
| 12 | 经验案例（DM_ 机制/只读视图等） | 十二 |

---

## 一、前端调用后台

### 1.1 SIE.invokeCommand（调后端命令）

```javascript
SIE.invokeCommand({
    async: true,                                  // 是否异步
    cmd: 'SIE.Web.QMS.TestCommand',               // 必选：命令名
    module: 'SIE.QMS',                            // 命令所在模块
    data: entity.data,                            // 数据
    scope: '',                                    // 命令所在模块的子范围
    token: '',                                    // 令牌（一般传 view.token）
    timeout: 7200000,                             // 可选：超时
    callback: (res) => {},                        // 回调
});
```

### 1.2 SIE.invokeDataQuery（调后端 DataQueryer 方法）

```javascript
SIE.invokeDataQuery({
    async: true,
    type: 'SIE.Web.MES.ProductRoutings.RoutingRules.RoutingRuleQueryer',  // 必选：查询器名
    method: 'GetVersion',                          // 必选：方法名
    params: [data.StockFlowId],                    // 参数数组
    token: view.token,
    hideErrorMsg: false,
    callback: (res) => {}, success: (res) => {}, error: (res) => {},
});
```

后端 DataQueryer 定义（继承 `Data.DataQueryer`，方法内 RT.Service.Resolve 调 Controller）：

```csharp
public class RoutingRuleQueryer : Data.DataQueryer
{
    public string GetVersion(double stockFlowId)
    {
        return RT.Service.Resolve<RoutingRuleController>().GetVersion(stockFlowId);
    }
}
```

### 1.3 view.execute（命令执行·数据传输形态）

本质是调用 `SIE.invokeCommand`（`withIds/selectIds/withChildren/data/success/error/callback` 参数见 18 号文件各命令节）。

**前端 `data` 的形态决定后端 `ViewCommand<T>` 的泛型选型**，三种形态必须一一对应：

| 形态 | 前端 data | 后端基类 | 后端取数方式 |
|---|---|---|---|
| ① 单个实体 | `data: entity.data`（表单实体） | `ViewCommand`（不带泛型） | `Excute(ViewArgs args, string scope)` 内 `args.Data.ToJsonObject<Item>()` |
| ② 数组 / 集合 | `data: view.getSelectionIds()` 等基本类型数组 | `ViewCommand<double[]>`（泛型 = 数组类型） | `Excute(double[] args, string scope)`，直接使用 `args` |
| ③ 自定义拼装 | `data: indata`（`indata.Data = Ext.encode({...})`） | `ViewCommand<ViewArgs>`（**必须带 `<ViewArgs>` 泛型**） | `Excute(ViewArgs args, string scope)` 内 `args.Data.ToJsonObject<TestViewArgs>()` |

**③ 自定义拼装是易错点**：前端把自定义结构 `Ext.encode` 后塞进 `indata.Data` 传给命令，后端**必须声明 `ViewCommand<ViewArgs>`（带 `<ViewArgs>` 泛型）**，漏写泛型（直接 `ViewCommand`）会导致反序列化形态不符。拼装结构内用 `EntityList<Item>` 承接实体列表。

**示例 ③ 自定义拼装**：

```javascript
execute: function (view, source) {
    var indata = {};
    var productModel = "";
    var productModelLineCapacity = [];
    indata.Data = Ext.encode({ A: productModel, B: productModelLineCapacity });
    view.execute({
        data: indata,
        success: function (res) {
        }
    });
}
```

```csharp
public class TestCommand : ViewCommand<ViewArgs>   // 必须带 <ViewArgs> 泛型
{
    protected override object Excute(ViewArgs args, string scope)
    {
        var data = args.Data.ToJsonObject<TestViewArgs>();
        return true;
    }
}

/// <summary>
/// 参数
/// </summary>
[Serializable]
public class TestViewArgs
{
    public string A { get; set; }
    public EntityList<Item> B { get; set; }
}
```

---

## 二、Web 事件 mon / fireEvent / mun

```javascript
// 订阅：监听组件.mon(被监听组件, 事件名, 处理函数, 作用域, 额外参数)
view.mon(view, "eventName", () => {}, view, { single: true });   // single 只订阅一次
// 触发：触发主体.fireEvent("事件名", 参数)
view.fireEvent("eventName", data);
// 注销：监听组件.mun(被监听组件, 事件名)
view.mun(view, "eventName");
```

---

## 三、Web 消息提示 SIE.Msg

```javascript
SIE.Msg.wait("正在处理，请稍候...".t());                          // 等待框
SIE.Msg.showInstantMessage("操作完毕".t(), "提示".t(), 1);         // 瞬时消息(msg,title,超时ms)
SIE.Msg.showMessage("提示".t(), ok_fn);                            // 消息框
SIE.Msg.showError("错误".t());                                     // 错误框
SIE.Msg.showWarning("警告".t());                                   // 警告框
SIE.Msg.askQuestion("询问？".t(), ok_fn, cancle_fn);               // 询问框(带取消回调)
SIE.Msg.confirm(msg, fn);                                          // 确认框
SIE.Msg.showToast('操作完毕', '提示');                             // Toast（分辨率缩放后宽度有问题，建议用 Ext.toast 并设 width）
SIE.Msg.progress('标题', '消息', '100%');                          // 进度条
SIE.Msg.hide();                                               // 关闭等待/进度框
SIE.Msg.close();
```

---

## 四、Web 插件（页面初始化加载）

JS 文件属性设为"嵌入的资源"，页面初始化时自动加载：

```javascript
SIE.definePlugin('SIE.MenuRemovePlugin', {
    init: function (app) {
        app.mon(app, "startupCompleted", function () {
            let portalSysMenu = Ext.getCmp("portal-sysMenu");
            let userInfo = CRT.Context.GlobalContext.getContext("userInfo");
            if (portalSysMenu && userInfo && userInfo.Code != "SysAdmin") {
                // 非管理员移除指定系统菜单
                let menuList = portalSysMenu.items;
                let removingMenu = ["修改密码".t(), "日志管理".t(), "下载打印插件".t()];
                for (let i = menuList.length - 1; i >= 0; i--) {
                    if (removingMenu.indexOf(menuList.getAt(i).text) != -1) menuList.removeAt(i);
                }
                portalSysMenu.update();
            }
        });
    }
});
```

---

## 五、Web 业务模块工程

- 命名：`SIE.Web.业务简称`（SIE.Web.Items、SIE.Web.QMS）
- 结构：`Module.cs`（UI 模块初始化）
- 引用：SIE.dll、SIE.Common.dll、SIE.Web.dll、SIE.Web.Common.dll

```csharp
[assembly: Module(typeof(SIE.Web.Items.Module))]
namespace SIE.Web.Items
{
    public class Module : UIModule
    {
        public override void Initialize(IApp app)
        {
            app.ModuleOperations += (s, e) =>
            {
                CommonModel.Modules.AddModules(
                    new WebModuleMeta { Label = "物料", EntityType = typeof(Item) });   // 挂载菜单
            };
        }
    }
}
```

> **菜单可见性红线**：Web 端功能页（有独立 ViewConfig 的实体）要出现在「菜单管理」的可引用清单里，**必须先在 Module.cs 的 `AddModules` 注册 `WebModuleMeta`**。运行时「菜单管理」只负责把**已注册**的功能节点挂到菜单组并授权，**不能引用未注册的实体**。漏注册的症状：页面代码齐全、编译通过，但菜单管理里找不到该功能、前端无入口——"走运行时配置所以不改代码"的假设不成立。仅"无菜单配置实体"（按钮入口 + `AssignAuthorize` 模式，见 04 §无菜单配置实体）反向适用：**不要**注册 `WebModuleMeta`，否则菜单+按钮双入口。

**WebClient 工程**（启动入口）关键配置（appsettings.json）：`DataPortal.Url`（apihost 地址，`DataPortal.Mode=Remote` 必须配）、`DataPortal.Mode`（Local 直连数据库 / Remote 走服务中间件）、`Apollo`（配置中心，优先级 Apollo > 文件 > 默认值）、`JsClient_date_Format`（默认 "Y-m-d H:i:s"）、`RedisConnectionStrings`（配 SentinelInfo 后 Host 失效）、`DB.DataLimit`、`dev.isDebuggingEnabled`（true 返回错误堆栈）、`LoginCheckCodeEnabled`、`CookieAuthentication.Name/Interval`、`isEnableXssFilter`、MQueue 消息队列。

---

## 六、界面处理

### 6.1 获取控件

```javascript
view.getControl().getForm().getFields();   // 表单全部控件
view.findEditor("属性名");                 // 指定属性控件
```

### 6.2 CRT.Workbench

- `addTab(tab)` / `addPage(opt)`：opt 含 title/tabId/url/pageClass（指定即全客制化页面）/model/entityType/module/recordId/isNew/isDetail/viewGroup/params/ignoreQuery
- `showPageDialog(opt)`：弹窗访问 html 页面（带 POST 请求）
- `getTabById(tabId)` / `activeTab` / `closeCurrentTab`

### 6.3 SIE.AutoUI（JS 界面处理类）

- `getMeta({ model/module/viewGroup/isAggt/ignoreCommands/isDetail/ignoreQuery/isReadonly, callback(meta) })`
- `createListView()` / `createDetailView()` / `createConditionView()` / `generateAggtControl()`（主从结构）

### 6.4 打开弹框（标准模板）

```javascript
SIE.AutoUI.getMeta({
    model: model, ignoreCommands: true, isDetail: true, ignoreQuery: false,
    callback: function (res) {
        var mainBlock = res.mainBlock || res;
        var modelEntity = Ext.create(model);
        modelEntity.setBillId(entity.data.Id);      // 预填
        var modelView = SIE.AutoUI.createDetailView(mainBlock, modelEntity);
        var ui = modelView.getControl();
        modelView._sourceListView = view;
        var win = SIE.Window.show({
            title: "审核确认".t(), width: 400, height: 250,
            items: ui, buttons: [confirmBtn, closeBtn],
            callback: function (btn) { /* switch 处理；return false 保持窗口不关 */ }
        });
    },
});
```

### 6.5 打开指定单据（tabId 去重）

```javascript
var tabId = ('tab_' + [entityModel, cancel.Id].join('_')).replace(/[.|,]/g, '_');
CRT.Workbench.addPage({ tabId: tabId, entityType: entityModel, recordId: cancel.Id,
                        title: title, isDetail: true, isNew: false });
```

### 6.6 设置日期范围编辑器

```javascript
// 8.0：fields[0/1/2].setValue(日期类型, 开始, 结束) + 实体数据手工设置 view.setXxxDate(dateRange)
// 8.0+：
editor.setDataRangValue(begin, end);          // 一次性
editor.setBeginValue(begin); editor.setEndValue(end); editor.setDateType(0);   // 单独
```

---

## 七、客制化界面三档（按客制化程度递增）

| 档次 | 基类 | 核心方法 | 菜单挂载 |
|---|---|---|---|
| ① LayoutClass 布局 | `SIE.autoUI.Layout`（一般继承 `SIE.autoUI.layouts.Common`） | `layout(regions)` 返回组件 | `LayoutClass = typeof(XxxLayoutClass).FullName` |
| ② UIGenerator 界面创建 | `SIE.autoUI.UIGenerator`（一般继承 `AggtUIGeneratorDefault`） | `generateControl(aggtMeta)` 必须返回 `SIE.autoUI.ControlResult(view, control)` | `UIGenerator = typeof(XxxUIGenerator).FullName` |
| ③ ModuleRuntime 全客制化 | `SIE.ModuleRuntime` | `createUI(module)` 返回 UI | `ModuleRuntime = typeof(XxxModuleRuntime).FullName` |

三档的 cs 类都是空壳（供 typeof 使用），实际逻辑在同名 JS。LayoutClass.js 中 `layout(regions)` 遍历 `regions.children[i]._view.model/_view.viewGroup` 匹配分组，`regions.main.getControl()` 取主控件；ModuleRuntime.js 常用 `getMainMeta(module)`（AutoUI.getMeta 后往 `formConfig.tbar` 塞 `{ command: '...' }`）+ `createCustomizedControl`（createListView + 手拼 border layout：west 放查询条件 `createConditionView`、center 放主控件）+ `addBehavior(view)` 绑 `celldblclick`。

---

## 八、Web 扩展视图

```csharp
// ① 附加子列表（1:N，Item 上附加 ItemLog）
View.AttachChildrenProperty(typeof(ItemLog), (e) =>
{
    var item = e.Parent as Item;
    if (item == null) return new EntityList<ItemLog>();
    return this.itemController.GetItemLogs(item.Id);
}).HasLabel("其他").OrderNo = 31;

// ② 附加子表单（1:1，Item 上附加 ItemDetail；参数是 ChildPagingDataArgs）
View.AttachDetailChildrenProperty(typeof(ItemDetail), (c) =>
{
    var item = c.Parent as Item;
    return RF.GetById<ItemDetail>(item.Id);
}, BaseDataViewGroup).HasLabel("基本资料").OrderNo = 10;

// ③ AssociateChildrenProperty：列表重写数据源（支持分页/排序透传）
View.AssociateChildrenProperty(Item.UnitListProperty, args =>
{
    var pagingArgs = args as ChildPagingDataArgs;
    var parent = pagingArgs.Parent as Item;
    return RT.Service.Resolve<UnitController>()
        .GetItemUnits(parent.Id, pagingArgs.PagingInfo, pagingArgs.SortInfo);
}).HasLabel("自定义子列表数据源");
```

---

## 九、前端 Entity / View 类 API 速查

**SIE.data.Entity**（基类，派生自 Ext.data.Model）：`generateId()`、`isDirty()`、`isNew()`、`markSaved()`（递归标记整个组合树）、`rejects()`（撤销修改）、`set(property, value)`（值与现值相等时不触发）、`addPropertyChanged(fn)`。事件 `propertyChanged`：参数 `e = { property, value, oldvalue, entity }`。

**SIE.view.View**（基类，Ext.util.Observable）：`getToken()/getMeta()/getModel()/getControl()/validateData()/getData()/getCurrent()/setCurrent(value, force)/loadChildData()/getParent()/getChildren()/findChild(model, recur)/findRelationView(name)/getCommands()/findCmd(cmdType)/syncCmdState(view, recursion)/execute(opt, scope)/refreshData(recordId)`。

**SIE.view.ListView**：`isListView/getConditionView()/getSelection()/getSelectionIds()/getSelectionModel()/selectEntities(entities, keepExisting)/reloadData()/setControlReadOnly(readonly)/refresh()/startEdit(entity, rowIdx, colIdx)`。

**SIE.view.DetailView**：`isDetailView/updateControl()/findEditor(property)/setControlReadOnly(readonly)`。

**SIE.view.QueryView**（派生自 DetailView）：`isQueryView/getResultView()/tryExecuteQuery(opts)/resetCondition()/clearCondition()`。

---

## 十、Web 视图配置方法

### 10.1 ViewConfig 结构与视图分组

五个重写入口：`ConfigView/ConfigListView/ConfigDetailsView/ConfigSelectionView/ConfigQueryView`。内置分组：`ViewConfig.ListView / DetailsView / SelectionView / QueryView / ImportView`。自定义分组：

```csharp
public const string BaseDataViewGroup = "BaseDataViewGroup";
protected override void ConfigView()
{
    View.DeclareExtendViewGroup(new string[] { BaseDataViewGroup });
    if (ViewGroup == BaseDataViewGroup) ConfigBaseDataView();
}
protected void ConfigBaseDataView()
{
    using (View.OrderProperties())
    {
        View.Property(p => p.Description).Show(ShowInWhere.All);
    }
}
```

### 10.2 常用配置方法

```csharp
View.FormEdit();                          // 表单编辑（批量编辑禁用，单条保存）
View.InlineEdit();                        // 行内编辑（批量保存）
View.UseDefaultCommands(); View.ClearCommands();
View.UseCommand(typeof(Cmd).FullName); View.UseCommands(WebCommandNames.Save, WebCommandNames.Delete);
View.AssignAuthorize(typeof(Item));       // 视图授权给指定实体
View.DeclareExtendViewGroup("ExtViewGroup");
View.AddBehavior(typeof(ItemBehavior).FullName);
View.UseChildrenAsHorizontal(false);      // 子视图布局方向
View.UseLayoutSize(4, 6);                 // 父子分布比例
using (View.OrderProperties()) { }        // 按代码顺序排列属性
View.RequireResource("/Script/charts.js", MIMEType.Script);
// 列表：View.UseGridSelectionModel() / View.WithoutPaging() / View.UseClientOrder() / using (View.DeclareBand("列分组")) { }
// 表单：View.HasDetailColumnsCount(4) / using (View.DeclareGroup("表单分组", 4, true, true)) { }
```

### 10.3 属性配置

```csharp
View.Property(p => p.Name).HasLabel("名称").HasOrderNo(1)
    .DefaultValue("默认值").Show(ShowInWhere.All)
    .Cascade(p => p.Code, null)                       // 联动：Code 变更时清空 Name
    .Readonly(p => p.Code == "Sys");                  // 条件只读
View.Property(p => p.Unit).UseDataSource((entity, paging, keyword) => ...);   // 引用属性数据源
// 表单：.ShowInDetail(width, height, hideLabel, rowSpan, columnSpan) / .Visibility(p => p.Code == "Sys")
// 列表：.ShowInList(width) / .FixColumn()（冻结） / .DisSortable()
// 导入：.ImportIndexer()（导入新增/更新依据，不支持引用属性） / .ImportRemark("备注")
//       View.PropertyRef(p => p.Unit.Code).HasLabel("单位编码")   // 按引用字段导入
// 子表：View.ChildrenProperty(p => p.UnitList).HasLabel("单位").UseViewGroup(...).HasOrderNo(1)
//       .Show(ChildShowInWhere.All).Visible(false)
```

---

## 十一、Web 数据处理

```javascript
// 用户信息：8.0 SIE.App.userInfo；8.3+ CRT.Context.GlobalContext.getContext("userInfo")
// 库存组织：8.0 SIE.App.orgInfo；8.3+ CRT.Context.GlobalContext.getContext("orgInfo")
// 刷新列表：view.reloadData()；或事件 CRT.Event.fire(Ext.String.format('{0}_refresh', view.model))
// 刷新表单：view.refreshData(entity.data.Id)；或事件 CRT.Event.fire('{model}_{id}_refresh', id)

// 解决表单刷新不及时（临时替换 onReloadData 钩子）：
var entity = view.getCurrent();
var oldOnReloadData = view.onReloadData;
view.onReloadData = function (data) {
    view.updateControl();
    view.onReloadData = oldOnReloadData;   // 立即恢复
    entity.markSaved();
    view.syncCmdState();
    SIE.Msg.showInstantMessage("操作完毕".t(), "提示".t(), 1);
};
CRT.Event.fire(Ext.String.format('{0}_{1}_refresh', view.model, entity.data.Id), entity.data.Id);
CRT.Event.fire(Ext.String.format('{0}_refresh', view.model));
```

---

## 十二、经验案例

### 12.1 DM_ 跨层传参机制（重要约定）

**DM_ 前缀字段是平台在视图间传递动态参数的标准约定**：不映射数据库列（`Meta.Property(...).DontMapColumn()`），仅跨层传参。两种典型场景：

**场景一：弹窗选择按主表过滤（后端参与）**
1. 前端 LookupCommandBase 注入 `current.data.DM_FactoryId = extParam.FactoryId` 后 `updateControl()`，`_queryBlockProcess` 锁定只读
2. 空派生类 `[CriteriaQuery(typeof(EntityCommonCriteriaProvider))] public class XxxForTarget : Xxx { }` 做精准路由
3. Provider：`if (query.EntityType == typeof(XxxForTarget)) return Controller.GetList<T>(query); return RT.Service.Resolve<CriteriaController>().GetList(query);`
4. Controller：`var factoryId = criteriaQuery["DM_FactoryId"]; criteriaQuery["DM_FactoryId"] = null;` —— **后端必须清理，避免污染通用查询**

**场景二：子表 PagingLookUp 下拉按主表过滤（前端+DataSource）**
1. 实体定义 `DM_xxxProperty` + `DontMapColumn()`
2. JS PagingLookUpMethod（`extend: 'SIE.control.PagingLookUpMethod'`）重写 `_searchByDSPfilter`：`filter.Parameters.Entity.DM_FactoryId = parent.data.FactoryId`（parent 经 `view.getParent().getCurrent()` 取）
3. ViewConfig：`UsePagingLookUpEditor(p => p.MethodClassName = "...")` + `UseDataSource((source, pagingInfo, keyword) => { var entity = source as Xxx; return Controller.GetXxx(entity.DM_FactoryId, ...); })`

### 12.2 只读视图基类 WebViewConfigEx

- `WebViewConfigEx<TEntity>`：内置三个分组 `Readonly`（通用只读，默认复用 ReadonlyList）/`ReadonlyList`/`ReadonlyDetails`
- `ConfigView()` 自动按 ViewGroup 分支：`ConfigReadonlyList() = SetChildrenViewGroup(Readonly) + ConfigListView() + SetReadonly()`
- `SetReadonly() = View.ClearCommands() + 所有属性 Readonly(true)`（需保留导出等命令时子类重写）
- 内部 `ShowPropertyWrapper : IDisposable` 配合 using 自动订阅 `PropertyFound/ChildrenPropertyFound` 事件设置属性显示范围，退出自动解绑防内存泄漏
- 分组名一律用常量，禁止硬编码字符串

### 12.3 其他速查

- **JS 调用界面上的命令**：`view.getCommands().map[commandType]` → `Ext.getCmp(command.config.meta.id)` → `command.tryExecute(commandEl)`
- **打开指定功能菜单**：`CRT.Workbench.addPage({ entityType: 'SIE.WMS.Portal.Receipt.PtAsn,SIE.WMS.Portal', title: '...', module: 同 entityType, isAggt: true })`
- **热重载 JS 文件**：appsettings `dev.isDebuggingEnabled: true` → 找到 Web 工程 X 上级目录路径 Z → WebClient 的 `bin/Debug/net6.0/path.Web工程X.json` 的 RootPath 填 Z
- **客制化消息提示**：`SIE.Msg._showMsg({ title, msg, buttons: Ext.Msg.YESNO, defaultFocus: Ext.Msg.NO, icon: Ext.Msg.QUESTION, iconCls: "iconfont icon-Notice1", fn })`
- **列表回车换列 Tab 换行**：重写编辑器 `extend: 'Ext.form.field.Number'`，`specialKey` 监听 ENTER/TAB，按 dataIndex 数字后缀 +1 找下一列，找不到则下一行（`sieView.startEdit(nextEntity, nextRowIdx, nextColIdx)`，`Ext.defer 30ms`）；Tab 未消除表格原有 Tab 事件影响需自行处理
- **通用打印工具 PrintUtil**（`SIE.Web.Core.Utils`）：`PrintEntityList(templateId, Dictionary<Type, Func<IEnumerable<object>>> getDataFuncDic, copy=1)` —— 按模板 EntityType 匹配取数方法，内部 DataChecker.CheckExists + ReportFactory + PrintProcess
- **子页签操作**：`view.getChildren().filter(p => p.model == '...' && p.viewGroup == 'ListView' && p.label == '...' && p._childProperty == 'ItemList')[0]` → `childView.getControl().up('tabpanel')` → `tabpanel.setActive(0)` 或 `setActive(control)`
- **更换 LOGO**：文件在 WebClient 服务 `wwwroot/` 下；登录页 `/images/logo_white_login.png`（180×60）+ 背景 `/images/account/1920.jpg`；登录后 `/images/logo_white.svg`（176×58）。浏览器有缓存，换后 Ctrl+Shift+R 强刷
