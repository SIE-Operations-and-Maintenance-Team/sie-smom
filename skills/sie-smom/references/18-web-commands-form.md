> **拆分说明**：原 `18-web-commands.md` 按任务域拆为 4 份；节号保留原手册序号（一~二十二），跨文件不连续属正常。

---

# Web 命令配方库 · 表单/列表保存与提交

## 配方索引（本文件）

| # | 任务 | 节 |
|---|---|---|
| 1 | 表单保存命令（自定义逻辑 + 及时刷新） | 一 |
| 2 | 表单提交命令-继承表单保存（局部刷新） | 二 |
| 3 | 表单提交命令-全页面刷新（切 ViewGroup） | 三 |
| 11 | 列表保存命令-自定义保存逻辑 | 十一 |

---

## 一、Web表单保存命令-自定义逻辑与及时刷新

**场景**：表单保存需要额外业务校验/状态联动，且保存后立即刷新界面数据、同步命令可执行状态。参考案例 `QualityAuditExamineSaveCommand`。

| 端 | 基类 |
|---|---|
| 前端 | `SIE.cmd.FormSave` |
| 后端 | `SIE.Web.Command.FormSaveCommand` |

执行链：`doSave() → view.execute() → FormSaveCommand.Excute()（反序列化 → OnSaving → DoSave → OnSaved）→ Controller.Save() → onSuccess() 刷新`。

**后端**（不重写 Excute，只重写 DoSave 转交 Controller）：

```csharp
public class QualityAuditExamineSaveCommand : FormSaveCommand
{
    protected override void DoSave(Entity data)
    {
        RT.Service.Resolve<QualityAuditExamineController>().Save(data as QualityAuditExamine);
    }

    protected override void OnSaving(Entity entity) { }
}
```

**Controller**（事务 + 锁 + 状态校验 + 状态联动）：

```csharp
public virtual void Save(QualityAuditExamine exam)
{
    using (var trans = DB.TransactionScope(SmomEntityDataProvider.ConnectionStringName))
    {
        RT.Service.Resolve<CommonEntityController>().Lock(exam);
        if (exam.PersistenceStatus != PersistenceStatus.New)
        {
            var latest = DataChecker.CheckExists<QualityAuditExamine>(exam.Id, "质量审核管理", null, true);
            if (latest.State == QualityAuditExamineState.Completed)
                throw new ValidationException("质量审核单【{0}】状态为【{1}】，不能修改".L10nFormat(latest.Code, latest.State.ToLabel()));
            if (latest.State != exam.State)
                throw new ValidationException("质量审核单【{0}】状态已变更为【{1}】，请检查".L10nFormat(latest.Code, latest.State.ToLabel()));
        }
        var details = exam.GetProperty(QualityAuditExamine.DetailListProperty);
        if (details?.Any() == true && exam.State == QualityAuditExamineState.Auditing)
            exam.State = QualityAuditExamineState.Improving;  // 状态联动在 RF.Save 前改实体
        RF.Save(exam);
        trans.Complete();
    }
}
```

**前端**：

```javascript
SIE.defineCommand('SIE.Web.XXX.Commands.XxxSaveCommand', {
    extend: 'SIE.cmd.FormSave',
    meta: { text: "保存", group: "edit" },

    canExecute: function (view) {
        var current = view.getCurrent();
        return current.data.State != 4 && this.callParent(arguments);  // 叠加而非覆盖框架判断
    },
    canVisible: function (view) {
        return view.getCurrent().data.State != 4;
    },

    doSave: function (view) {
        var me = this;
        SIE.Msg.wait("正在处理，请稍候...".t());
        var children = view.getChildren();
        var withChildren = children.length > 0;
        view.execute({
            withChildren: withChildren,   // 连同子表保存
            callback: function (res) { if (res.Success) me.onSuccess(view, res); }
        });
    },

    onSuccess: function (view, res) {
        var entity = view.getCurrent();
        entity.markSaved();
        var oldOnReloadData = view.onReloadData;
        view.onReloadData = function (data) {          // 临时替换钩子，数据加载完更新界面后立即恢复
            view.updateControl();
            view.onReloadData = oldOnReloadData;
            entity.markSaved();
            view.syncCmdState();                       // 同步命令可执行状态
            SIE.Msg.showInstantMessage("保存成功".t(), "提示".t(), 1);
        };
        CRT.Event.fire(view.model + '_refresh', entity.getId());                          // 刷新列表
        CRT.Event.fire(view.model + '_' + entity.getId() + '_refresh', entity.getId());
    },
});
```

**ViewConfig**：`View.UseCommand(typeof(XxxSaveCommand).FullName);`（ConfigDetailsView 中追加，不替换默认命令）。

**坑点**：FormSaveCommand 内置链路自动调用 OnSaving → DoSave → OnSaved，不要重写 Excute；新实体（PersistenceStatus.New）跳过数据库状态比对（库里无记录，CheckExists 无意义）。

---

## 二、Web表单提交命令-继承表单保存（局部刷新）

**场景**："提交"= 保存 + 推进状态（如 创建 → 审核中），但提交后**视图分组不变**，仅局部刷新。与第三节按"是否需要切 ViewGroup"二选一。

| 端 | 基类 |
|---|---|
| 前端 | `SIE.cmd.FormSave` |
| 后端 | `SIE.Web.Command.FormSaveCommand` |

**后端**（同第一节结构，DoSave 转交 Submit）：

```csharp
public class QualityAuditExamineSubmitCommand : FormSaveCommand
{
    protected override void DoSave(Entity data)
    {
        RT.Service.Resolve<QualityAuditExamineController>().Submit(data as QualityAuditExamine);
    }

    protected override void OnSaving(Entity entity) { }
}
```

**Controller**（提交 = 复用 Save + 状态校验 + DB.Update 流转）：

```csharp
public virtual void Submit(QualityAuditExamine exam)
{
    DataChecker.CheckNotNull(exam, nameof(exam));
    DataChecker.CheckNotNull(exam.AssessStartDate, "审核日期起", true);
    using (var trans = DB.TransactionScope(SmomEntityDataProvider.ConnectionStringName))
    {
        Save(exam);                                 // 先按保存流程落库
        if (exam.State != QualityAuditExamineState.Created)
            throw new ValidationException("质量审核单【{0}】状态已变更为【{1}】，不可提交，请检查".L10nFormat(exam.Code, exam.State.ToLabel()));
        DB.Update<QualityAuditExamine>()
            .Where(p => p.Id == exam.Id)
            .Set(p => p.State, QualityAuditExamineState.Auditing)   // 状态流转用 DB.Update，避免 RF.Save 重落库
            .Execute();
        trans.Complete();
    }
}
```

**前端关键差异**（相对保存命令）：

```javascript
canExecute: function (view) {
    return view.getCurrent().data.State == 1;   // 仅 创建(1) 可提交
},
canVisible: function (view) { return this.canExecute(view); },

doSave: function (view) {
    var me = this;
    SIE.Msg.wait("正在处理，请稍候...".t());
    SIE.Msg.askQuestion("确定提交？", () => {
        var entity = view.getCurrent();
        var oldDirty = entity.dirty;
        entity.dirty = true;                     // 强制脏标记：无修改时框架不会提交，需置 true
        view.execute({
            withChildren: true,
            success: function (res) { me.onSuccess(view, res); },
            error: function (res) {
                entity.dirty = oldDirty;         // 失败恢复原 dirty
                SIE.Msg.hide();
            }
        });
    });
},
// onSuccess 与第一节相同（临时替换 onReloadData + CRT.Event.fire）
```

**坑点**：`entity.dirty = true` + 失败恢复是提交命令的固定套路；提交命令与保存命令在 ViewConfig 中并列 UseCommand，互不替换。

---

## 三、Web表单提交命令-全页面刷新

**场景**：视图按状态分组（ViewGroup）渲染，提交后状态变化必须切换视图分组重新加载整页。参考案例 `EdImproveFormSubmitCommand`（8D改善管理）。

| 端 | 基类 |
|---|---|
| 前端 | `SIE.cmd.FormSave` |
| 后端 | `SIE.Web.Command.FormSaveCommand`（重写 Excute 返回 OpenViewModel） |

**后端**（与第一/二节不同：重写 Excute，返回值作为前端 res.Result）：

```csharp
public class EdImproveFormSubmitCommand : FormSaveCommand
{
    protected override object Excute(ViewArgs args, string scope)
    {
        EntityList deserializeData = GetDeserializeData(args, scope);
        var entity = ((deserializeData.Count > 0) ? deserializeData[0] : null) as EdImprove;
        return RT.Service.Resolve<EdImproveController>().SubmitFromCommand(entity);
    }
}
```

**Controller**（提交后重载实体取最新状态）：

```csharp
public virtual OpenViewModel SubmitFromCommand(EdImprove bill)
{
    Submit(bill);
    bill = RF.GetById<EdImprove>(bill.Id);      // 必须重载：前端传入的是提交前状态
    return new OpenViewModel { ViewGroup = bill.State?.ToString() };
}
```

**前端核心 onSaved**：

```javascript
onSaved: function (view, res) {
    var me = this;
    var current = view.getCurrent();
    current.markSaved();
    CRT.Event.remove(view.model + '_' + current.getId() + "_refresh");   // 先移除旧监听防重复
    CRT.Event.fire(view.model + '_refresh', current.getId());
    CRT.Event.fire(view.model + '_' + current.getId() + '_refresh', current.getId());

    var tab = me.tab;                     // doSave 中保存：CRT.Workbench.getTabPanel().getActiveTab()
    tab.setLoading("提交成功，正在刷新数据".t());
    var openModel = res.Result;
    var pageOpt = {
        entityType: view.model,
        recordId: current.data.Id,
        viewGroup: openModel.ViewGroup,   // 后端返回的最新分组
        title: me.getEditViewTitle(current),
        isDetail: true,
        isNew: false
    };
    var relativePath = SIE.Util.Url.getPageUriSuffix(pageOpt);
    var newTabUrl = window.top.location.origin + '/#' + relativePath;
    var newUrl = window.top.location.origin + '/page?' + relativePath;
    tab.url = newTabUrl;
    window.frameElement && (window.frameElement.src = newUrl);   // iframe 内刷新
    window.top.location.href = tab.url;                           // 顶层窗口跳转
},
```

**坑点**：tab.url 带 `#`（hash 路由），直接赋值 href 不会触发浏览器刷新，必须显式设置 `window.frameElement.src` + `window.top.location.href`；刷新前必须 `CRT.Event.remove` 防止重复绑定。

---

## 十一、Web列表保存命令-自定义保存逻辑

**场景**：列表（Grid）保存需要业务校验/级联处理。参考案例 `WorkGroupSaveCommand`。

| 端 | 基类 |
|---|---|
| 前端 | `SIE.cmd.Save` |
| 后端 | `SIE.Web.Command.SaveCommand` |

**后端**（DoSave 收 `EntityList`）：

```csharp
internal class WorkGroupSaveCommand : SaveCommand
{
    protected override void DoSave(EntityList data)
    {
        RT.Service.Resolve<WorkGroupController>().Save(data as EntityList<WorkGroup>);
    }
}
```

**前端**（前置交互 + callParent）：

```javascript
SIE.defineCommand('SIE.Web.XXX.Commands.XxxSaveCommand', {
    extend: "SIE.cmd.Save",
    meta: { text: "保存", group: "edit" },
    doSave: function (view) {
        SIE.Msg.wait("正在保存，请稍候...".t());
        this.callParent(arguments);   // 交回父类触发后端 DoSave
    }
});
```

**Controller**（批量保存 + 逐条校验）：

```csharp
public virtual void Save(EntityList<WorkGroup> workGroups)
{
    using (var trans = DB.TransactionScope(ResourcesEntityDataProvider.ConnectionStringName))
    {
        foreach (var item in workGroups)
        {
            RF.Save(item);
            if (item.HandoverRule == HandoverRule.DesignatedPerson)
            {
                if (!WorkGroupAnyHandoverEmployee(item.Id))
                    throw new ValidationException("班组【{0}】指定人员交班，交接人员不能为空".L10nFormat(item.Name));
            }
        }
        trans.Complete();
    }
}
```

**ViewConfig**（注意与表单命令不同——这里是**替换**默认命令）：

```csharp
protected override void ConfigListView()
{
    View.UseDefaultCommands();
    View.ReplaceCommands(WebCommandNames.Save, typeof(WorkGroupSaveCommand).FullName);
}
```

**坑点**：`SaveCommand.DoSave` 参数是 `EntityList`（多条），`FormSaveCommand.DoSave` 参数是 `Entity`（单条），勿混淆。

---

