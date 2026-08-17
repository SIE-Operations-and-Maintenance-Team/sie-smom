> **类型**：问题库（蒸馏自 SMOM 开发手册 /Problems/，14/15 页——"BS固定列悬停显示文本"页为站点死链未收录，2026-08-17 版本）
> **来源**：http://10.10.51.213:30687/Problems/
> **优先级**：高。排查/解决问题时先按本文件索引定位；工作流开发按第三节完整模式实施。
> **覆盖范围**：查询效率·框架数据操作开关·工作流全流程·节点高度/基类·配置缓存·通用查询·字符串数值排序·BS弹窗子页签·Web界面/命令/样式·JS跨模块undefined

---

# 常见问题与解决方案

## 问题索引

| # | 问题/主题 | 节 |
|---|---|---|
| 1 | 查询效率提升（Select 两种模式） | 一 |
| 2 | 常见框架数据操作（忽略幽灵/组织/权限/验证等 using 开关） | 二 |
| 3 | 工作流实战（Elsa 节点全流程） | 三 |
| 4 | 工作流节点高度设置 | 四 |
| 5 | 节点基类说明 | 五 |
| 6 | 配置不走缓存（ConfigExController） | 六 |
| 7 | 通用查询使用（UseDataSource + CommonQueryCriteria） | 七 |
| 8 | 字符串类型数值字段排序 | 八 |
| 9 | BS 弹窗只显示主视图、子页签不显示 | 九 |
| 10 | Web 界面/命令/样式小技巧 | 十 |
| 11 | JS 跨模块 undefined | 十一 |

---

## 一、查询效率提升：Select 两种模式

- **模式一 Select To Entity**：投影到实体类型——映射数据库的字段**按数据库字段名**接收，不映射数据库的字段（视图属性等）**按属性名**接收。
- **模式二 Select To Object**：投影到匿名/普通对象——**按对象属性名**接收；`Select` 内不能指定对象类型，用 `.ToList<指定对象类型>()` 收。

（配合 22 号文件 CommonEntityController 的 SplitContains 批量查询与 08-17 号查询规范。）

## 二、常见框架数据操作（using 开关）

```csharp
using (PhantomQueryContext.DontFilterPhantoms()) { /* 查询暂时忽略 IS_PHANTOM 条件 */ }
using (InvOrgs.WithAll()) { /* 查询暂时忽略库存组织条件 */ }
using (InvOrgs.With(new List<double> { 1, 2, 3 })) { /* 查询指定库存组织 */ }
using (SIE.DataAuth.DataAuths.LoadAll()) { /* 查询暂时忽略权限条件 */ }
using (Validator.DisableValidation()) { RF.Save(entityList); /* 保存时忽略实体验证规则 */ }
using (DB.ConnectionScope(ReportEntityDataProvider.ConnectionStringName)) { /* 指定数据库连接 */ }
```

## 三、工作流实战（Elsa 工作流，锁定解锁流程全流程）

> **红线：流程任务流转使用异步任务，谨慎使用事务，否则容易死锁。**

### 3.1 概念与文件布局

- 节点文件路径：`SIE.QMS.WorkFlow/Activities/QmsLockers/`（流程工程/流程节点文件夹/业务节点集合）。
- 节点特性 `[SieWorkFlowActivity]`：`Category`（流程定义中分组）、`DisplayName`、`Description`、`Outcomes`（流出分支，如 `new[] { "通过", "不通过" }`）。
- 节点参数：`VariableBase` 派生（[Serializable]，如 `QmsLockerVariable { BillId, StartFlowTaskId }`）；**第一个流程节点必须设置节点参数**（`SetVariable`）。
- 节点属性：`[ActivityInput(Label, UIHint, Order, DefaultValue, OptionsProvider, Hint)]`，`Order = -1` 表示界面不显示。
- 节点上下文 `ActivityExecutionContext`：`Input` 输入值判触发来源（TriggerModel 挂起 / `TrunInput` 转办 / `RejectInput` 驳回 / `AuditInput` 审核 / `RejectArriveInput` 驳回到达）；`GetSieVariable<T>()` 取流程变量。

### 3.2 节点基类模式（业务基类继承 PanelBlockingActivity）

基类骨架（QmsLockerActivityBase 实战模式，可复制）：

```csharp
public abstract class QmsLockerActivityBase : PanelBlockingActivity
{
    protected abstract BillState UpdateBillState { get; }        // 流转到本节点后更新原单据状态
    public QmsLockerActivityBase()
    {
        entityTypeName = typeof(QmsLockerBillViewModel).FullName;  // 节点展示数据类型
        passType = ActivityPassType.Any;                            // All 全部通过 / Any 任一通过
    }
    [ActivityInput(Label = "处理人", UIHint = "org-tree", Order = -1)]
    public override string handler { get; set; }                   // 流程定义时选处理人（实战无用则 Order=-1）
    protected abstract EntityList<Employee> GetHandleEmployees(ActivityExecutionContext context);   // 指定处理人生成任务

    // 异常处理：捕异常 → WorkflowInstance.Fault + Logger + 流转记录 → Suspend()（挂起节点，流程不崩）
    protected virtual IActivityExecutionResult ErrorHandle(ActivityExecutionContext context, Func<IActivityExecutionResult> func);

    // 模板方法：OnExecute/OnResume/ReturnResult 全部 sealed 包 ErrorHandle，子类重写 XxxOverridable
    protected sealed override IActivityExecutionResult OnExecute(ctx) => ErrorHandle(ctx, () => OnExecuteOverridable(ctx));
    protected virtual IActivityExecutionResult OnResumeOverridable(ActivityExecutionContext context)
    {
        ResetCurrentIngOrg(context);
        if (context.Input is TrunInput trunInput) { handler = trunInput.TrunToPeople; return CustomizedTrun(...); }
        if (context.Input is RejectInput input) { return Reject(context, input, ...); }
        return OnExecuteInternal(context);
    }

    // 生成流程任务：转办则只给转办人；否则 GetHandleEmployees + GenerateFlowTasks + 通知 + 更新单据状态
    protected override void GenerateFlowTask(ActivityExecutionContext context);

    // 流转记录：发起记录 / 审核意见（AuditModel.Opinion）/ 默认
    protected override void SaveFlowProcessRecord(ActivityExecutionContext context);

    // 通知（Input 是 Variable 时跳过——发起场景不通知）
    protected virtual async Task SendNotifyMessageAsync(context, empIds);  // GetPendingFlowTask + NotifyHandlerAsync
}
```

### 3.3 四类节点写法

| 节点类型 | 基类 | 要点 |
|---|---|---|
| 起始节点 | 业务基类 | `UpdateBillState => BillState.Initiated`；`OnExecuteOverridable` 中 `Input is Variable` 时 `SetVariable(context, variable)` 后 `OnExecuteInternal` **自动跳过本节点**；驳回/转办后停留需手动提交 |
| 一般处理节点 | 业务基类 | 只需 `UpdateBillState` + 构造器设 `readonlyViewGroup/editViewGroup` + `GetHandleEmployees` |
| 分支控制节点 | 业务基类 | 特性加 `Outcomes = new[] { "返工", "不返工" }`；重写 `ReturnResultOverridable` 按单据数据 `return Outcome("分支名")` |
| 双角色流转控制节点 | 业务基类 | `passType = All`；重写 `ReturnResultOverridable`：两角色都处理完 `_workflowController.FinishToDoOrDoingFlowTaskInActivitiId(context)` + `Done()`，否则 `Suspend()`；可重写 `CustomizedTrunOverridable` 做转办业务后 `Suspend()` |
| 结束节点 | `BackgroundActivity` | `OnFinishExecute` 中更新单据最终状态；`SaveFlowProcessRecordWithMessage(context, "流程结束", null, null)` |

### 3.4 流程任务开发要点

- Web 前台 **TaskView**：流程任务视图渲染完成后 `view.TaskView` 可取流程任务数据（`_activityViews` 节点视图列表）。
- 流程定义配置：配置流程定义功能添加流程定义 → 发起（起始节点 SetVariable）→ 提交 → 通知 → 终止。

## 四、工作流节点高度设置

节点视图高度太小 → 节点视图 Behavior 中调整容器高度：

```javascript
Ext.define('...QmsLockerBillViewModelFormBehavior', {
    onViewReady: function (view) {
        Ext.defer(() => { this._setWorkFlowTaskNodeHeight(view); }, 500);   // 延时等渲染
    },
    _setWorkFlowTaskNodeHeight: function (view) {
        var taskView = view.TaskView;
        if (!taskView) return;
        var expandNodes = ['锁定解锁发起'];      // 需要调高的节点标题
        var height = 500;
        for (var i = 0; i < expandNodes.length; i++) {
            var panel = view.getControl().up(Ext.String.format("[title='{0}']", expandNodes[i]));
            panel && panel.setHeight(height);
        }
    }
});
```

## 五、节点基类说明（方法清单）

| 基类 | 方法 |
|---|---|
| `PanelBlockingActivity` | `OnExecute`（执行回调）、`SaveFlowProcessRecord`（处理记录）、`GenerateFlowTask`（生成任务）、`OnResume`（恢复挂起）、`ReturnResult`（返回结果） |
| `PanelActivity` | `OnExecuteInternal`（节点业务）、`ReturnResult`、`OnTrun`（转办回调）、`OnReject`（驳回回调）、`OnRejectArrive`（驳回到达回调） |
| `SieActivityBase` | `SaveFlowProcessRecord`（任务处理记录，需子类重写） |

## 六、配置不走缓存（ConfigExController）

**问题**：ConfigService 每次读库；改配置后缓存不失效。

**方案**：8.3+ 用 `ConfigExController : ConfigController` 替换实现（Redis 分布式缓存，键 `cfgs:{EntityType}:{ConfigType}:{InvOrgId}`，默认缓存 1 天；静态构造挂 `RepositoryDataProvider.Submitted`，保存 ConfigDetail 后主动删对应缓存键），服务端 Module 中注册：

```csharp
RT.Service.Register(typeof(ConfigController), typeof(ConfigExController));
```

**手工清缓存**（改配置立即生效）：

```bash
docker exec -it 容器名 /bin/bash
redis-cli -p 6380 -a '密码' --scan --pattern 'cfgs:*' | xargs -r -I{} redis-cli -p 6380 -a '密码' del "{}"
```

## 七、通用查询使用（自定义数据源 + CommonQueryCriteria）

```csharp
View.Property(p => p.Item).ShowInList(140).HasOrderNo(1)
    .UsePagingLookUpEditor(p =>
    {
        p.WindowWidth = 800; p.WindowHeight = 400;
        p.DicLinkField = new Dictionary<string, string>()          // 选中后联动回填：编辑器字段 → 本实体字段
        {
            { nameof(IAsnCoaAttachment.V_ItemName), Item.NameProperty.Name },
            { nameof(IAsnCoaAttachment.V_ItemSpecification), Item.SpecificationModelProperty.Name }
        };
        p.SearchFieldList = new List<string>() { Item.SpecificationModelProperty.Name };
    })
    .UseDataSource((entity, paging, keyword) =>
    {
        var repository = RF.Find<ItemForSupplier>();
        var criteria = new CommonQueryCriteria();
        if (keyword.IsNotEmpty())
        {
            keyword = $"%{keyword}%";
            criteria.Add(new PropertyMatchGroup          // OR 分组：编码或型号任一包含
            {
                new PropertyMatch(ItemForSupplier.CodeProperty, BinaryOp.Contains, keyword),
                new PropertyMatch(ItemForSupplier.SpecificationModelProperty, BinaryOp.Contains, keyword),
            });
        }
        criteria.PagingInfo = paging;
        return repository.GetBy(criteria);
    });
```

## 八、字符串类型数值字段排序

**问题**：数值存成字符串（如 AsnDetail.LineNo），字符排序 1,12,2 ≠ 数值排序 1,2,12。

**方案**：视图实体中把字符字段转数值（SQL 层 TO_NUMBER），查询 JOIN 该视图排序：

```csharp
[RootEntity, Serializable]
public class AsnDetailOrder : Entity<double>
{
    [Label("LineNo")]
    public static readonly Property<int> LineNoProperty = P<AsnDetailOrder>.Register(e => e.LineNo);
    public int LineNo { get { return GetProperty(LineNoProperty); } set { SetProperty(LineNoProperty, value); } }
}

class AsnDetailOrderConfig : EntityConfig<AsnDetailOrder>
{
    protected override void ConfigMeta()
    {
        Func<IQuery> view = () => DB.Query<AsnDetail>().As("T")
            .Select(p => new { p.Id, Line_No = p.SQL<int>(new Data.FormattedSql("TO_NUMBER(T.LINE_NO) AS LINE_NO")) })
            .ToQuery();
        Meta.MapView(view).MapAllProperties();
    }
}

// 使用：
var query = Query<AsnDetail>().Join<AsnDetailOrder>((dtl, od) => dtl.Id == od.Id);
var data = query.OrderBy<AsnDetailOrder>((dtl, od) => od.LineNo).ToList(new PagingInfo(1, 10));
```

（前端内存排序场景用 `ObjectUtil.SortByStringNumber`，见 22 号文件第一节。）

## 九、BS 弹窗只显示主视图、子页签不显示（排查清单）

以命令弹窗显示工单（带子页签）为例，按序排查：

1. **JS getMeta 用法**：`isAggt: true`；`module` 必须赋值（如 `"SIE.MES.WorkOrders.WorkOrder,SIE.MES"`）；callback 生成界面**用 `res` 整体**（不是 `res.mainBlock`）；生成方法用 `SIE.AutoUI.generateAggtControl(res, entity)`。
2. **Web 视图配置**：没配 `View.AssignAuthorize(typeof(WorkOrder))`。
3. **角色权限**：菜单未更新功能模块（角色权限没有配置选项），或角色未配权限。

## 十、Web 界面/命令/样式小技巧

```javascript
// 隐藏界面内容
view.getControl().up().hide();
// 界面不可操作
view.getControl().setDisabled(!enable);
// 动态更新命令图标（this 为命令）
var commandEl = Ext.getCmp(this.config.meta.id);
commandEl.setIconCls("iconfont icon-Checkmark icon-red");
```

**增加不受权限管控的 Web 命令**（beforeCreate 中动态注入工具栏）：

```javascript
beforeCreate: function (meta, entity) {
    var config = meta.gridConfig;
    var view = config.store.associateView;
    var addCmds = [{ command: 'SIE.Web.XXX.Commands.XxxCommand' }];
    var cmdList = SIE.AutoUI.createCommands(addCmds, view);   // 动态创建命令按钮
    if (cmdList.length > 0) {
        config.dockedItems = config.dockedItems || [];
        var dockedItem = config.dockedItems[0];
        if (dockedItem) {
            for (var i = 0; i < cmdList.length; i++) dockedItem.items.splice(0, 0, cmdList[i]);   // 插到工具栏最前
        } else {
            var toolBarConfig = { items: cmdList };
            toolBarConfig = Ext.merge(toolBarConfig, GlobalConfig.defaultToolBarConfig);
            if (config.bodyCls && config.bodyCls === "conditionViewBodyCls") toolBarConfig.style = 'border-top-width:0';
            config.dockedItems.push(toolBarConfig);
        }
    }
}
```

**页面样式**：覆盖样式文件（登录 `wwwroot/css/account/account.css`、主界面 `wwwroot/css/site.css`）或用样式注入插件；滚动条宽度纯 CSS：

```css
::webkit-scrollbar { width: 30px; height: 30px; }
```

## 十一、JS 跨模块导致 undefined

**问题**：A 模块 JS 调 B 模块的 js 方法/变量，报 undefined。

**方案**：视图中声明加载目标模块资源：

```csharp
View.RequirModuleResource("SIE.Web.MES.WorkOrders.Scripts.WorkOrderBehavior.js");
```

（同族问题：LookupCommandBase 的 `Ext.require` 异步加载需计数器 + onReady 模式，见 18 号文件第二十节。）

---

> 未收录说明：手册 Problems 章节"BS固定列之后，无法使用鼠标悬停显示文本内容问题"一页为站点死链（侧边栏链接 404），待手册修复后补充。
