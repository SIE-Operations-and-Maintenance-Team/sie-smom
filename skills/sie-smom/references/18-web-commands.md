> **类型**：配方库（蒸馏自 SMOM 开发手册 /WebDev/Web命令/，23 页，2026-08-17 版本）
> **来源**：http://10.10.51.213:30687/WebDev/Web命令/
> **优先级**：高。写 Web 命令（保存/提交/导入/导出/打印/选择/添加/查看）时先读本文件照搬模式。
> **覆盖范围**：表单保存·表单提交(局部/全页刷新)·查看附件·打印·多表聚合导出·通用/自定义模板/子表/增强导入·列表保存/查找/导出/界面导入·添加(表单/行内+自动单号)·标签/单据打印基类·弹窗查看·选择命令(基础/工具栏/主表过滤/资源加载)

---

# Web 命令配方库

## 配方索引

| # | 任务 | 节 |
|---|---|---|
| 1 | 表单保存命令（自定义逻辑 + 及时刷新） | 一 |
| 2 | 表单提交命令-继承表单保存（局部刷新） | 二 |
| 3 | 表单提交命令-全页面刷新（切 ViewGroup） | 三 |
| 4 | 查看附件命令（图片预览） | 四 |
| 5 | 打印命令（8.0/8.3/9.0 版本差异） | 五 |
| 6 | 导出命令-多表聚合（主从 JOIN 展开） | 六 |
| 7 | 导入命令（简单/复杂 IBusinessImport） | 七 |
| 8 | 导入命令-使用自定义模板文件 | 八 |
| 9 | 导入命令-子表导入-继承内置导入 | 九 |
| 10 | 框架通用导入命令增强（UseImportExtCommands） | 十 |
| 11 | 列表保存命令-自定义保存逻辑 | 十一 |
| 12 | 列表数据查找命令（前端内存查找） | 十二 |
| 13 | 列表数据导出命令（ExporterSlim） | 十三 |
| 14 | 列表数据导入命令（填界面不落库） | 十四 |
| 15 | 添加命令-表单编辑+自动生成单号 | 十五 |
| 16 | 添加命令-行内编辑+自动生成单号 | 十六 |
| 17 | 通用标签打印命令基类 | 十七 |
| 18 | 通用单据打印命令基类 | 十八 |
| 19 | 通用弹窗查看命令 | 十九 |
| 20 | 选择命令（LookupCommandBase 全家） | 二十 |

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

## 四、Web查看附件命令

**场景**：附件列表中点击"查看附件"预览图片（PDF 新开页签）。参考案例 `ViewAttachmentCommand`。

**后端**：

```csharp
public class ViewAttachmentCommand : ViewCommand
{
    protected override object Excute(ViewArgs args, string scope)
    {
        var attachment = JsonConvert.DeserializeObject<CommonAttachmentDto>(args.Data);
        bool isPic = FileHelper.IsPicture(attachment.FileExtesion);
        if (isPic == false)
            throw new ValidationException("文件类型 {0} 不支持预览，请下载查看".L10nFormat(attachment.FileExtesion));
        var fileBase64String = FileHelper.GetAttachmentFileBase64String(attachment.FilePath, attachment.FileName);
        return fileBase64String;
    }
}
```

**关键工具 API**（`SIE.Core.Utils.FileHelper`）：
- `ByteArrayFileToBase64String(byte[], fileType)` — 字节数组转 base64（自动拼 `data:{mime};base64,` 前缀）
- `GetFileType(fileName)` / `GetBase64DescString(fileExtType)` — 后缀→MIME（覆盖图片/文本/视频/office/压缩包）
- `GetAttachmentFileBase64String(filePath, fileName)` — 经 `AttachmentController.FileDownload` 下载后转 base64
- `IsPicture(fileExtension)` — 图片判定（png/jpg/pdf/svg 等）

**DTO**：`SIE.Web.Core.Common.Dtos.CommonAttachmentDto { FilePath, FileName, FileExtesion }`。

**前端**（base64 → blob → objectURL，带缓存）：

```javascript
execute: function (view, source) {
    var me = this;
    if (!view._imgHrefDic) view._imgHrefDic = {};
    var entity = view.getCurrent();
    var imgHref = view._imgHrefDic[entity.data.Id];
    if (imgHref) { me.showImage(imgHref, entity.data.FileName); return; }   // 命中缓存直接显示
    SIE.Msg.wait("正在处理，请稍候...".t());
    view.execute({
        async: true,
        data: entity.data,
        success: function (res) {
            var blob = base64ToBlob(res.Result);
            var href = window.URL.createObjectURL(blob);
            view._imgHrefDic[entity.data.Id] = href;
            me.showImage(href, entity.data.FileName);
            SIE.Msg.hide();
        }
    });
},
showImage: function (url, title) {
    SIE.Common.Utils.ImgHelper.showImgDialog({ title: title, url: url, width: '60%', height: "90%" });
}
```

`SIE.Common.Utils.ImgHelper.showImgDialog(opt)`：标题匹配 `/pdf$/i` 时自动 `CRT.Workbench.addPage` 新页签；否则弹窗内 Ext.Img + 缩放/复原/关闭按钮。

**视图注册**：`CommonAttachmentViewConfig : WebViewConfig<Attachment>` 中 `View.UseCommand(typeof(ViewAttachmentCommand).FullName)`。

---

## 五、Web打印命令

**场景**：后端生成打印数据（见 `22-host-tools-cases.md` 打印节），前端按版本打开预览/打印。

**版本差异**（前端打开方式）：

```javascript
// 8.0：portal.addTab，url /Reports/DevPrintViewer(预览)、/Reports/DevPrint(打印)
portal.addTab({ id: 'Label_rpt', text: 'xxx打印'.t(), url: '/Reports/DevPrintViewer', params: param, method: 'POST' });

// 8.3：CRT.Workbench.showPageDialog，url /Modules/PrintTemplate/DevPrintViewer、/Modules/PrintTemplate/DevPrint
CRT.Workbench.showPageDialog({ id: 'Label_rpt', text: "xxx打印".t(), url: '/Modules/PrintTemplate/DevPrint', params: param, method: 'POST' });

// 9.0+：WebReportComponents 组件
SIE.Msg.wait("正在处理，请稍候...".t());
view.execute({
    withIds: true,
    selectIds: view.getSelectionIds(),
    success: (res) => {
        var rstPrint = res.Result;
        var printCmpt = new SIE.Web.Common.Prints.Report.WebReportComponents({
            ReportType: rstPrint.Type,
            ReportData: { path: rstPrint.Url, content: rstPrint.Url }
        });
        var cfg = printCmpt.getExtTarget();
        SIE.Msg.hide();
        if (cfg && cfg.printCallback) {
            cfg.printCallback(printCmpt);           // 有回调走回调（如静默打印）
        } else {
            var param = printCmpt.getPrintParams();
            var printUrl = printCmpt.getPrintUrl();
            if (!printCmpt.hasError()) {
                CRT.Workbench.showPageDialog({ id: 'Xxx_rpt', text: "xxx打印".t(), method: 'POST', url: printUrl, params: param });
            }
        }
        view.reloadData();
    }
});
```

**9.0+ 前端命令 requires 注意**：`requires: ['SIE.Web.Common.Prints.Report.WebReportComponents']`。

**配套后端命令**（返回 `{ Data, Type }` 匿名对象）：

```csharp
public class MaterialReturnApplyPrintCommand : ViewCommand<MaterialReturnApply[]>
{
    protected override object Excute(MaterialReturnApply[] args, string scope)
    {
        DataChecker.CheckListNotEmpty(args, nameof(args));
        var sample = args[0];
        PrintTemplate template = RT.Service.Resolve<MaterialReturnApplyController>().GetPrintTemplate(sample.WmsReType);
        IReport reportByExtension = ReportFactory.Current.GetReportByExtension(template.Type);
        Type type = Type.GetType(template.EntityType);
        if (type == null) throw new ValidationException("不存在实体类型[{0}]".L10N().FormatArgs(template.EntityType));
        if (!(Activator.CreateInstance(type) is IPrintable printable))
            throw new ValidationException("创建实体类型[{0}]失败！".L10N().FormatArgs(template.EntityType));
        var ids = args.Select(p => p.Id).ToList();
        var datas = RT.Service.Resolve<CommonEntityController>().GetEntityListById<MaterialReturnApply>(ids, null);
        var printData = reportByExtension.PrintProcess(printable, template.Id, template.Content, () => {
            RT.Service.Resolve<MaterialReturnApplyController>().UpdatePrintQty(ids.ToList());
            return datas;
        }, 1);
        return new { Data = printData, Type = template.Type };
    }
}
```

前端 canExecute 典型校验：选中行且选中行的 `WmsReType` 一致才可打印（不同类型模板不同）。

---

## 六、Web导出命令-多表聚合

**场景**：主从（1:N）实体导出 Excel，主表字段在子表行展开（类 SQL JOIN）。基类 `BaseExportCommand<T1, T2, T3, T4>`（自研，位于 `SIE.Web.Core.Common.Commands`）。

**泛型**：T1 主表、T2 子表、T3/T4 预留（不用传 `object`）。需重写 3 个成员：`Name`（文件名）、`InitColumnDefs()`、`CreateExcelData(double[] ids)`。

**命令 cs**：

```csharp
public class ExportSampleTaskCommand : BaseExportCommand<SampleTask, SampleTaskDetail, object, object>
{
    protected override string Name => "取样任务";

    protected override List<ColumnDef> InitColumnDefs()
    {
        return new List<ColumnDef>
        {
            // 主表字段：取 task
            ColumnDef.New("取样任务号".L10N(), (task, dtl, _, _) => ShowValue(task.No)),
            ColumnDef.New("物料编码".L10N(), (task, dtl, _, _) => ShowValue(task.V_ItemCode)),
            // 子表字段：取 dtl
            ColumnDef.New("样本码".L10N(), (task, dtl, _, _) => ShowValue(dtl.SampleCode)),
        };
    }

    protected override void CreateExcelData(double[] ids)
    {
        var tasks = RT.Service.Resolve<SampleTaskController>().GetExportData(ids);
        foreach (var task in tasks)
        {
            var detailList = task.DetailList;
            if (detailList == null || detailList.Count == 0) continue;
            foreach (var detail in detailList)
            {
                IRow dataRow = CreateRow();                       // 基类方法，自动递增行号
                for (int i = 0; i < _columnDefs.Count; i++)
                {
                    var data = _columnDefs[i].ValueSelector(task, detail, null, null);
                    CreateDataCell(dataRow, i, data);             // 基类方法
                }
            }
        }
    }
}
```

**命令 js**（一行继承）：

```javascript
SIE.defineCommand('SIE.Web.XXX.Commands.ExportXxxCommand', {
    meta: { text: "导出", group: "business", iconCls: "icon-ExportData icon-blue" },
    extend: 'SIE.Web.Core.Common.Commands.BaseExportCommand'
});
```

**Controller 取数模式**（`EagerLoadOptions().LoadWithViewProperty()` 保证 V_xxx 视图属性可用）：

```csharp
public virtual EntityList<SampleTask> GetExportData(double[] ids)
{
    if (ids == null || ids.Length == 0) throw new ValidationException("请选择要导出的数据".L10N());
    var tasks = RT.Service.Resolve<CommonEntityController>()
        .GetEntityListById<SampleTask>(ids, new EagerLoadOptions().LoadWithViewProperty());
    var detailLookup = RT.Service.Resolve<CommonEntityController>()
        .GetEntityList<SampleTaskDetail, double>(
            SampleTaskDetail.SampleTaskIdProperty.Name,
            tasks.Select(p => p.Id).ToList(),
            new EagerLoadOptions().LoadWithViewProperty())
        .ToLookup(p => p.SampleTaskId);          // 按外键分组
    foreach (var task in tasks)
    {
        var details = detailLookup[task.Id].AsEntityList();
        task.LoadProperty(SampleTask.DetailListProperty, details);   // LoadProperty 填充导航属性
    }
    return tasks;
}
```

**基类内置能力**（勿重复实现）：`ShowValue(obj)` 自动处理 null/bool(是/否)/DateTime(yyyy-MM-dd HH:mm:ss)/decimal(G29)/枚举；表头/数据单元格样式；`NameWithDate` 文件名日期后缀；返回 `{ FileName, FileContent(base64) }`，前端基类自动触发浏览器下载。

**ViewConfig**：`View.UseCommands(typeof(ExportXxxCommand).FullName);`（ConfigListView）。

---

## 七、Web导入命令（通用）

**简单导入**（单表）：`View.UseImportCommands();` + 配置 `ConfigImportView` 视图分组即可。

**复杂导入**（自定义校验/业务逻辑）三层：

| 层 | 类 |
|---|---|
| 前端命令 | `SIE.Web.Common.Import.Commands.ImportCommandBase` |
| 后端命令 | `SIE.Web.Common.Import.Commands.ImportCommandBase`（cs） |
| 导入处理 | `IBusinessImport` 接口 |

**前端**（只需声明）：

```javascript
SIE.defineCommand('SIE.Web.XXX.Commands.ImportXxxCommand', {
    extend: 'SIE.Web.Common.Import.Commands.ImportCommandBase',
    meta: { text: "导入XXX", group: "business" },
});
```

**后端命令**：

```csharp
public class ImportTechDefectCommand : ImportCommandBase
{
    protected override ImportCompleted GetImportCompleted()
    {
        return (DataRow[] drSuccess, DataRow[] drFailed) => { };
    }

    protected override Type GetImportHandleType()
    {
        return typeof(ImportProcessTechDefectHandle);   // 声明导入处理类型
    }

    protected override List<string> GetImportTempleData()   // 可选：模板样例行
    {
        return new List<string> { "1", "2", "3" };
    }
}
```

**导入处理 IBusinessImport**（核心）：

```csharp
public class ImportXxxHandle : IDisposable, IBusinessImport
{
    // 1. 列名列表（与 Excel 模板列头一致）
    public List<string> ColumnNameList { get; set; } = new List<string> { "制程工艺编码", "工厂编码", "缺陷编码" };
    // 2. 列验证配置
    public Dictionary<string, ValidColumn> ColumnValidList { get; set; }
    // 3. 缓存字典（导入内去数据库查询的结果，防重复查询）
    private Dictionary<string, ProcessTech> processTechDic = new Dictionary<string, ProcessTech>();

    public IBusinessImport CreaetColumnValid()
    {
        this.ColumnValidList = new Dictionary<string, ValidColumn>
        {
            // ImportDataType._String/_Custom/_PositiveDouble/_PositiveInt/_Enum + 必填 + 自定义验证方法
            { "制程工艺编码", new ValidColumn(ImportDataType._Custom, true, VaildProcessTech) },
            { "缺陷编码", new ValidColumn(ImportDataType._Custom, true, VaildDefect) },
        };
        return this;
    }

    // 自定义列验证：签名固定 (object obj, out string MessageTip, DataRow dr)
    private bool VaildProcessTech(object obj, out string MessageTip, DataRow dr)
    {
        MessageTip = string.Empty;
        string code = obj.ToString().Trim();
        if (!processTechDic.ContainsKey(code))
        {
            var entity = RT.Service.Resolve<ProcessTechBaseController>().GetProcessTechByproCode(code);
            if (entity == null) { MessageTip = "【{0}】不存在".L10nFormat(code); return false; }
            processTechDic.Add(code, entity);       // 校验通过即入缓存
        }
        return true;
    }

    private int ColIndex(string columnName) { return ColumnNameList.IndexOf(columnName); }

    // 4. 业务数据处理（只处理无错误行；错误信息写 row[ImportDataHandle.MessageColumnName]）
    public void ProcessBusinessDataHandle(DataRow[] drs)
    {
        if (drs.Length == 0) return;
        if (drs.Any(p => !string.IsNullOrEmpty(p[ImportDataHandle.MessageColumnName].ToString()))) return;
        foreach (DataRow row in drs)
        {
            try
            {
                // 读取列：row.Field<string>(ColIndex("列名"))?.Trim()
                RF.Save(newEntity);
            }
            catch (Exception ex)
            {
                row[ImportDataHandle.MessageColumnName] += ex.GetBaseException().Message;
            }
        }
    }

    public void Dispose() { processTechDic.Clear(); /* 释放各缓存字典 */ }
}
```

**可用的辅助 API**：
- `ImportExtension.GetEnumLabel(typeof(枚举), string.Empty)` — 枚举名→枚举字典（验证枚举列）
- `CommonEntityController.GetEntityWithDic(属性, 值, 缓存字典, EagerLoadOptions)` — 按属性查找实体并缓存
- `ImportDataHandle.MessageColumnName` — 行错误信息列，写它即在前端错误列表展示

**坑点**：验证方法签名固定三参（obj, out MessageTip, DataRow dr）；跨行查重靠私有字典；Dispose 必须清缓存。

---

## 八、Web导入命令-使用自定义模板文件

**场景**：模板需合并单元格/多行表头/下拉选项/说明文字，框架自动模板不满足。

| 步骤 | 代码 |
|---|---|
| 1. 放文件 | 模板 .xlsx 放 Web 项目 `Templates/` 目录 |
| 2. 后端拦截 | 重写 `Excute(ImportViewArgs, string)`，`BehaviorName == "Download"` 时返回 `{ FileName, FilePath }` |
| 3. 前端打开 | 重写 `downloadTemplateSuccess(res)` 用 `window.open(origin + "/" + FilePath)` |

```csharp
// 后端命令（在 ImportCommandBase 派生类中）
protected override object Excute(ImportViewArgs importViewArgs, string scope)
{
    string behaviorName = importViewArgs.BehaviorName;
    if (behaviorName == "Download")   // 用户点了"下载模板"
    {
        var fileName = "员工技能导入模板.xlsx";
        return new { FileName = fileName, FilePath = "Templates/" + fileName };
    }
    return base.Excute(importViewArgs, scope);   // 其余行为（校验/导入）仍走基类
}
```

```javascript
// 前端命令
downloadTemplateSuccess: function (res) {
    var filePath = res.Result.FilePath;
    var url = window.location.origin + "/" + filePath;
    window.open(url);
}
```

**坑点**：模板列头必须与 Handle 的 `ColumnNameList` 完全一致，否则框架无法映射列；`FilePath` 相对 Web 站点根目录。

---

## 九、Web导入命令-子表导入-继承内置导入

**场景**：主从表中子表数据导入，每条记录需关联当前选中的父记录（自动写外键）。基类用**内置** `ImportExcelCommand`（不是 ImportCommandBase），封装了模板下载/解析/列验证/错误展示全流程。

**后端**（重写两个方法）：

```csharp
internal class ImportPhysAndChemStandardApplicableItemCommand : ImportExcelCommand
{
    private double parentId = 0;

    protected override object Excute(ImportViewArgs importViewArgs, string scope)
    {
        parentId = importViewArgs.SelectedParentId;   // 前端传入的父记录 ID
        return base.Excute(importViewArgs, scope);
    }

    protected override void OnRowDataRead(RowData data, CacheData cache)
    {
        if (data.Entity is PhysAndChemStandardApplicableItem entity)
        {
            entity.StandardId = parentId;             // 每行写外键
        }
        base.OnRowDataRead(data, cache);
    }
}
```

**前端**（重写 canExecute + buttonChange）：

```javascript
SIE.defineCommand('SIE.Web.XXX.Commands.ImportXxxCommand', {
    extend: 'SIE.Web.Common.Import.Commands.ImportExcelCommand',
    meta: { text: "导入", group: "edit" },

    canExecute: function (view) {
        var parentView = view.getParent();
        var parent = parentView && parentView.getCurrent();
        return parent && !parent.isDirty() && parent.data.State != 1;   // 父记录已保存且状态可编辑
    },

    buttonChange: function (field, newValue, oldValue) {
        var me = this;
        var view = me.view;
        var parentView = view.getParent();
        var parent = parentView && parentView.getCurrent();
        var file = field.fileInputEl.dom.files.item(0);
        if (file.size / 1024 > me.limitFileSize * 1000) {
            Ext.MessageBox.alert("提示", "文件不能大于".t() + me.limitFileSize + "M".t());
            return false;
        }
        var fileReader = new FileReader('file://' + newValue);
        fileReader.readAsDataURL(file);
        fileReader.onload = function (e) {
            Ext.MessageBox.show({ msg: '导入数据中, 请稍等...'.t(), progressText: '导入中...'.t(), width: 300, closable: false });
            me.view.execute({
                data: {
                    BehaviorName: 'ImportData',
                    Type: me.view.model,
                    Data: e.target.result,
                    ViewGroup: me.view.viewGroup,
                    SelectedParentId: parent.data.Id      // 关键：传递父记录 ID，字段名不可改
                },
                success: function (res) { me.onSuccessImported(me, res); },
                error: function (res) { Ext.MessageBox.close(); }
            });
        }
    },
});
```

**坑点**：`SelectedParentId` 是前后端约定字段名；`OnRowDataRead` 在列验证**之前**调用，设置的字段值会参与后续验证；`OnRowDataRead` 用 `is` 类型判断保类型安全。

---

## 十、Web框架通用导入命令增强

**用法**：`View.UseImportExtCommands();`（扩展方法，注册 `ImportExcelExtCommand` + `DownloadTemplateCommand`）。

**增强点**：优化引用数据查找效率 —— 先收集表格中实际出现的引用值，用 `SplitDataExecute` 分批 IN 查询一次性建缓存字典（`InitCacheData`），而非逐行查库；找不到的值预填 null 防无效查询；重复值直接抛 `ValidationException("查找[{0}]属性[{1}]发现重复的值[{2}]")`。

**底层 Importer 关键 API**（一般不直接用，了解机制）：
- `Importer.Import(importResult, ImportType, ImportView, stream, OnRowDataRead, OnSave, OnComplete)` — 主入口
- `Importer.SaveTemplate(entityType, viewGroup, stream)` — 按视图组定义生成模板（表头红色=ImportIndexer 唯一索引列；枚举/布尔/快码列自动加批注和下拉验证）
- 保存：50 线程并发、100 行一批（`AsyncHelper.CreateParallelActions` + `WithCurrentThreadContext`）
- 引用列配置：`View.PropertyRef(p => p.DefectCategory.Code).HasLabel("分类编码")`（Web 用 `PropertyRef`，WPF 用 `Property`）；**不支持主从导入**

**ImportExcelExtCommand.cs**（重写 ImportData 换 Importer）：

```csharp
public class ImportExcelExtCommand : SIE.Web.Common.Import.Commands.ImportExcelCommand
{
    protected override object ImportData(ImportViewArgs importViewArgs)
    {
        Tuple<FileType, byte[]> tuple = FileStreamHelper.Base64ToExcel(importViewArgs.Data);
        MemoryStream memoryStream = new MemoryStream();
        memoryStream.Write(tuple.Item2);
        memoryStream.Seek(0L, SeekOrigin.Begin);
        SIE.Web.Core.Imports.Importer.Import(importResult, ImportType, ImportView, memoryStream, OnRowDataRead, OnSave, delegate (string errors) { OnComplete(errors); });
        return importResult;
    }
}
```

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

## 十二、Web列表数据查找命令

**场景**：列表页"查找"按钮，弹关键字窗口，前端内存中循环匹配并逐个跳转选中（非数据库查询）。参考案例 `SearchRowCommand`（`SIE.Web.Core.Common.Commands`）。

**配套 ViewModel + ViewConfig**：

```csharp
[Label("列表数据查找")]
[RootEntity, Serializable]
public class SearchFrameViewModel : ViewModel
{
    [Label("关键字")]
    public static readonly Property<string> KeywordProperty = P<SearchFrameViewModel>.Register(e => e.Keyword);
    public string Keyword { get { return this.GetProperty(KeywordProperty); } set { this.SetProperty(KeywordProperty, value); } }
}

public class SerachFrameViewModelViewConfig : WebViewConfig<SearchFrameViewModel>
{
    protected override void ConfigDetailsView()
    {
        View.HasDetailColumnsCount(4);
        View.Property(p => p.Keyword).ShowInDetail(columnSpan: 4);
    }
}
```

**命令核心**（后端 cs 为空壳 ViewCommand；逻辑全在前端）：

```javascript
SIE.defineCommand('SIE.Web.Core.Common.Commands.SearchRowCommand', {
    meta: { text: "查找", group: "edit", iconCls: "icon-Search icon-blue" },
    winWidth: 0, winHeight: 0,
    keyPropertyList: [],                 // 需匹配的属性名数组（派生命令指定）
    noMatchTips: "没有找到匹配结果".t(),
    _lastSearchKeyword: null, _lastMatchResultIndex: -1,
    _foundIndexList: [], _foundEntityList: [],

    execute: function (view) {
        if (!view.isListView) return;
        var _this = this;
        // 弹窗：SIE.AutoUI.getMeta({ model: 'SIE.Core.Common.ViewModels.SearchFrameViewModel', ignoreCommands: true, isDetail: true,
        //   callback: 创建 detailView → SIE.Window.show({ buttons: [查找, 关闭] }) })
    },

    _searchBtnFunction: function (view, entity) {
        if (!view.isListView || !this.keyPropertyList || !this.keyPropertyList.length) return;
        var keyword = entity.data.Keyword;
        if (keyword == null || keyword == "") { SIE.Msg.showWarning("请录入关键字".t()); return; }
        var selModel = view.getSelectionModel();
        if (!this._lastSearchKeyword || this._lastSearchKeyword != keyword) {
            // 新关键字：全量扫描
            this._search(view, keyword, this.keyPropertyList, selModel);
        } else {
            // 同关键字：循环下一个匹配 (index + 1) % length
            var next = (this._lastMatchResultIndex + 1) % this._foundIndexList.length;
            this._lastMatchResultIndex = next;
            selModel.select(this._foundIndexList[next]);
            view.startEdit(this._foundEntityList[next]);
        }
    },

    _search: function (view, keyword, keyPropertyList, selModel) {
        var dataList = view.getData().data.items;      // 当前内存数据
        var regExp = new RegExp(keyword, "i");         // 忽略大小写
        for (var di = 0; di < dataList.length; di++) {
            for (var pi = 0; pi < keyPropertyList.length; pi++) {
                var v = dataList[di].data[keyPropertyList[pi]];
                if (v && regExp.test(v)) {
                    this._foundIndexList.push(di);
                    this._foundEntityList.push(dataList[di]);
                }
            }
        }
        if (this._foundIndexList.length > 0) {
            this._lastMatchResultIndex = 0;
            selModel.select(this._foundIndexList[0]);
            view.startEdit(this._foundEntityList[0]);
        } else if (this.noMatchTips) { SIE.Msg.showWarning(this.noMatchTips); }
    },
});
```

**坑点**：只搜当前页内存数据（`view.getData().data.items`），不查库；同一关键字重复点"查找"循环跳转。

---

## 十三、Web列表数据导出命令（ExporterSlim 轻量导出）

**场景**：选中/当前列表数据传后台，NPOI 生成 Excel 回传。核心工具：`ExporterSlimBuilder<T>` + `ExportColumnModelContainer<T>`（`SIE.Web.Core.Exports`）。

**命令 cs**：

```csharp
internal class ExportMoldChangeTaskCommand : ViewCommand<List<MoldChangeTask>>
{
    protected override object Excute(List<MoldChangeTask> args, string scope)
    {
        if (args.Count == 0) throw new ValidationException("没有可导出的数据");

        var exporterBuilder = new ExporterSlimBuilder<MoldChangeTaskExportViewModel>();
        var name = "转模单".L10N();
        exporterBuilder.FileName = name;               // 输出：{name}.xlsx
        exporterBuilder.ExcelContentTitle = name;      // Excel 内合并单元格大标题（可选）

        var ids = args.Select(x => x.Id).ToList();
        var list = RT.Service.Resolve<MoldChangeTaskController>().ExportMoldChangeTasks(ids);

        var container = new ExportColumnModelContainer<MoldChangeTask>();
        container.Add(p => p.Code);                                        // 自动取 Label 做列名
        container.Add(p => p.Name, "自定义列标题");                        // 自定义列名
        container.Add(p => p.Id, "自定义列标题", p => "自定义取值");        // 自定义取值 Func
        exporterBuilder.ExportColumns = container.Columns;

        var exporter = exporterBuilder.Build();
        var fileData = exporter.CreateExcelFile(list);   // { FileName, FileContent(base64) }
        return fileData;
    }
}
```

**列模型自动转换**（`ExportColumnModel<T>`）：不传 func 时按属性类型自动选值转换——bool → 是/否、DateTime → yyyy-MM-dd HH:mm:ss、枚举 → ToLabel()、其他 → ToString()。

**Builder 可配置项**：`ExcelContentTitle`、`FileName`、`ExportColumns`、`ConfigTitleStyle/ConfigHeaderStyle/ConfigCellStyle`（统一样式）、`SpecificHeadStyle(列名, exporter) => style` / `SpecificCellStyle(entity, 列名, exporter) => style`（按列/按单元格定制样式）。

**命令 js**：

```javascript
execute: function (view, source) {
    SIE.Msg.wait("处理中，请稍候...".t());
    var datas = view.getData().getData().items.map(p => p.data);   // 当前列表内存数据
    if (datas.length == 0) { SIE.Msg.showMessage("没有可导出的数据".t()); return; }
    view.execute({
        data: datas,
        success: function (res) {
            var fileData = res.Result;
            var blob = base64ToBlob(fileData.FileContent);
            var url = URL.createObjectURL(blob);
            var aDiv = document.createElement("a");
            aDiv.href = url; aDiv.download = fileData.FileName; aDiv.click();
            SIE.Msg.showInstantMessage(Ext.String.format("导出文件：【{0}】".t(), fileData.FileName));
        }
    })
}
```

---

## 十四、Web列表数据导入命令（填界面不落库）

**场景**：Excel 数据直接填到界面（用户确认后再手动保存），不写数据库。核心：`PageImportCommand`（`SIE.Web.Core.Common.Commands`）。

**前提**：
1. 配置 `PageImportCommand.ViewGroup`（值 `"ImportExcelDataView"`）视图分组，并设置键值列（`IsImportIndexer`）
2. 属性 `.Show(ShowInWhere.Import)`
3. 仅支持简单类型：布尔、枚举、数值、字符串、日期

**视图扩展方法**（一条注册两个命令）：

```csharp
public static void UsePageImportCommand<T>(this WebEntityViewMeta<T> meta)
{
    meta.UseCommand(typeof(PageImportCommand).FullName);
    meta.UseCommand(typeof(DownloadPageImportExcelCommand).FullName);   // 下载模板命令
}
```

**后端机制**（PageImportCommand 内置，一般不重写）：读 Excel → 按视图分组收集键值列+导入列 → `TransferData` 组装 `{ KeySplitor:'_', KeyPropertyList, ImportPropertyList, DataRowDictionary }` 返回前端；可重写 `SetExtendProperties(...)` 增加扩展列（服务于 JS 动态加的列）。

**前端填充核心**（loadSuccess）：按实体键值（`entity.get(keyProp)` join '_'）匹配 `DataRowDictionary`，对匹配行逐列 `view.startEdit(entity, rowIndex, colIndex)` + `entity.set(key, value)`，最后 `editPlug.completeEdit()`。

**下载模板命令**（`DownloadPageImportExcelCommand`）：继承 ImportExcelCommand，`protected override string ImportView => PageImportCommand.ViewGroup;`；前端通过隐藏 form `standardSubmit` POST 到 `api/Command/Excute` 触发文件下载。

---

## 十五、Web添加命令-表单编辑+自动生成单号

**场景**：`View.FormEdit()` 表单编辑模式下，点"添加"自动生成单号并预填，打开独立编辑页（Workbench Tab）。**五层协作**：

**① Controller（编号生成 + 实体预填）**：

```csharp
public virtual string GenerateNo()
{
    var config = ConfigService.GetConfig<NoConfigValue>(new NoConfig(), typeof(XxxEntity));
    if (config == null || config.BacodeRule == null)
        throw new ValidationException("未找到单号生成规则，请检查配置项".L10N());
    return RT.Service.Resolve<NumberRuleController>().GenerateSegment(config.BacodeRule.Id, 1).FirstOrDefault();
}

public virtual XxxEntity GenerateEntity()
{
    return new XxxEntity { No = GenerateNo(), State = XxxState.Created };   // 可预填任意多字段
}
```

`NoConfig : ModuleConfig<NoConfigValue>` 是平台内置配置类（SIE.Common.Configs.CommonConfigs），也可在实体上标 `[EntityWithConfig(typeof(NoConfig), "单号配置项", "单号配置规则")]` 自动注册。

**② AddCommand.cs**：

```csharp
public class XxxAddCommand : ViewCommand
{
    protected override object Excute(ViewArgs args, string scope)
    {
        return RT.Service.Resolve<XxxController>().GenerateEntity();   // 返回值序列化给前端
    }
}
```

**③ AddCommand.js**（Workbench.addPage 打开独立页）：

```javascript
SIE.defineCommand('XxxAddCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加".t(), group: "edit" },
    execute: function (view, source) {
        var me = this;
        SIE.Msg.wait("处理中...".t());
        view.execute({
            data: {},
            success: function (res) {
                SIE.Msg.hide();
                var entity = me.getEditEntity();
                var data = res.Result;
                CRT.Workbench.addPage({
                    entityType: me.view.model,
                    recordId: entity.data.Id,
                    title: me.getEditViewTitle(entity),
                    isDetail: true,
                    isNew: true,
                    params: { IsNew: true, Entity: data }   // 完整预填实体放 params
                });
            }
        });
    }
});
```

**④ DetailsViewBehavior.cs**（空壳占位）+ **⑤ DetailsViewBehavior.js**（接收预填）：

```javascript
Ext.define('XxxDetailsViewBehavior', {
    view: null,
    onViewReady: function (view) {          // view 聚合完成、表单就绪后的生命周期钩子
        this.view = view;
        var entity = view.getCurrent();
        var params = CRT.Context.PageContext.getParams();
        if (entity && entity.isNew() && params && params.IsNew && params.Entity) {
            entity.setNo(params.Entity.No);       // 逐字段写入预填值
        }
    }
});
```

**ViewConfig**：

```csharp
protected override void ConfigView() { View.FormEdit(); }

protected override void ConfigListView()
{
    View.UseCommands(typeof(XxxAddCommand).FullName, WebCommandNames.Edit, WebCommandNames.Delete);
}

protected override void ConfigDetailsView()
{
    View.AddBehavior(typeof(XxxDetailsViewBehavior).FullName);
    View.UseCommands(WebCommandNames.FormSave);
    View.Property(p => p.No).Readonly();   // 单号只读
}
```

**与行内添加对比**：

| 维度 | 行内添加（十六节） | 表单编辑（本节） |
|---|---|---|
| 视图模式 | `View.GridEdit()` | `View.FormEdit()` |
| JS 核心 | `view.createNewItem()` + `me.edit()` | `CRT.Workbench.addPage()` |
| 预填传递 | `editEntity.setNo()` 直接设值 | `params.Entity` → Behavior.onViewReady |
| 是否需 Behavior | 不需要 | **必须**（接收预填数据的唯一入口） |
| 适用 | 简单主表 | 复杂表单（子表/分组/多 Tab） |

---

## 十六、Web添加命令-行内编辑+自动生成单号

**场景**：Grid 行内编辑模式，三层协作：

```csharp
// ① Controller：GetNo + GetNewEntity（同十五节①，用 config.NumberRuleId）
public virtual string GetNo()
{
    var config = ConfigService.GetConfig(new NoConfig(), typeof(Entity));
    if (config == null || config.NumberRuleId == null)
        throw new ValidationException("未找到编号生成规则，请检查配置项".L10N());
    return RT.Service.Resolve<NumberRuleController>().GenerateSegment(config.NumberRuleId.Value, 1).First();
}
public virtual Entity GetNewEntity() { return new Entity { No = GetNo() }; }

// ② AddCommand.cs（同十五节②）
```

```javascript
// ③ AddCommand.js
SIE.defineCommand('...EntityAddCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加", group: "edit" },
    execute: function (view, source) {
        var me = this;
        SIE.Msg.wait("处理中...".t());
        view.execute({
            data: {},
            success: function (res) {
                SIE.Msg.hide();
                var data = res.Result;
                var editEntity = view.createNewItem();
                editEntity.setNo(data.No);       // 填入后端生成的编码
                me.onEditting(editEntity);
                me.edit(editEntity);             // 行内进入编辑
                me.onEdited(editEntity);
            }
        });
    }
});
```

---

## 十七、Web通用标签打印命令基类

**场景**：标签打印通用基类。一个启用模板直接打印；多个模板弹框选择。前后端继承基类，后端指定标签打印类型。

**后端基类**（`SIE.Web.Core.Common.Commands`）：

```csharp
[Serializable]
public class BaseLabelPrintCommandViewArgs : ViewArgs
{
    public bool IsPrint { get; set; }   // false=取模板列表，true=执行打印
}

public abstract class BaseLabelPrintCommand<TLabelPrintable> : ViewCommand<BaseLabelPrintCommandViewArgs>
    where TLabelPrintable : ILabelPrintable
{
    // 打印实体的数据类型与界面实体类型不一致时重写指定
    protected virtual Type PrintEntityType { get; }

    protected override object Excute(BaseLabelPrintCommandViewArgs args, string scope)
    {
        if (!args.IsPrint) return GetTemplates(args, scope);
        return GetPrintData(args, scope);
    }

    protected virtual object GetTemplates(BaseLabelPrintCommandViewArgs args, string scope)
    {
        var printableType = typeof(TLabelPrintable).GetQualifiedName();
        return AppRuntime.Service.Resolve<PrintsController>().GetPrintTemplates(printableType, isEnable: true);
    }

    protected virtual EntityList GetEntityList(BaseLabelPrintCommandViewArgs args, string scope)
    {
        var entityType = PrintEntityType ?? ClientEntities.Find(args.Type).EntityType;
        return RF.Find(entityType).GetByIdList(args.SelectedIds.Cast<object>().ToArray());
    }

    protected virtual object GetPrintData(BaseLabelPrintCommandViewArgs args, string scope)
    {
        PrintTemplate printTemplate = args.Data.ToJsonObject<PrintTemplate>();
        printTemplate = RT.Service.Resolve<PrintsController>().GetPrintTemplate(printTemplate.Id) as PrintTemplate;
        IReport report = ReportFactory.Current.GetReportByExtension(printTemplate.Type);
        Type type = Type.GetType(printTemplate.EntityType);
        if (!(Activator.CreateInstance(type) is IPrintable printable))
            throw new ValidationException("创建实体类型[{0}]失败！".L10N().FormatArgs(printTemplate.EntityType));
        EntityList datas = GetEntityList(args, scope);
        return report.PrintProcess(printable, printTemplate.Id, printTemplate.Content, () => datas.OfType<Entity>(), 1);
    }
}
```

**前端基类**（`SIE.Web.Core.Common.Commands.BaseLabelPrintCommand`）：canExecute=有选中行；execute → 取模板（1 个直接 print，多个 `showSelectView` 用 AutoUI 弹 PrintTemplate 列表选择）；print → `{ Data: JSON.stringify(template), Type, SelectedIds, IsPrint: true }` → 成功后 `CRT.Workbench.showPageDialog({ url: '/Modules/PrintTemplate/DevPrint', params: { content: res.Result } })`；派生命令可重写 `afterPrint(view)` 做打印后处理（如更新打印次数）。

**坑点**：打印实体的数据实体类型必须与界面数据类型一致（不一致时重写 `PrintEntityType`），否则预览报错无数据。

---

## 十八、Web通用单据打印命令基类

与十七节结构完全相同，差异点：

| 项 | 标签打印 | 单据打印 |
|---|---|---|
| 泛型约束 | `ILabelPrintable` | `IBillPrintable` |
| 前端打印呈现 | showPageDialog `/Modules/PrintTemplate/DevPrint` | `WebReportComponents` 组件（ReportType=template.Type, ReportData=打印结果），有 printCallback 走回调否则 getPrintParams/getPrintUrl + showPageDialog |

派生方式：cs 继承 `BaseBillPrintCommand<XxxBillPrintable>` 指定单据打印类型；js 继承 `SIE.Web.Core.Common.Commands.BaseBillPrintCommand`，按需重写 `afterPrint`。

---

## 十九、Web通用弹窗查看命令

**场景**：列表行"查看"按钮，弹只读详情窗。需配合视图扩展方法：

```csharp
public static WebEntityViewMeta<T> UseViewInDetailCommand<T>(this WebEntityViewMeta<T> view, string viewGroup = ViewConfig.DetailsView)
{
    view.SetExtendedSetting("ViewInDetailCommand_ViewGroup", viewGroup);
    view.UseCommand("SIE.Web.Core.Commands.ViewInDetailCommand");
    return view;
}
```

**命令核心**（`extend: 'SIE.cmd.ListEditableBase'`）：

```javascript
canExecute: function (view) {
    if (!view.isListView) return false;
    return view.getSelection().length == 1;
},
execute: function (view, source) {
    var me = this;
    var current = view.getCurrent();
    var viewGroup = view.config.gridConfig.ViewInDetailCommand_ViewGroup;   // 读扩展设置
    if (!this.viewMeta) {
        SIE.AutoUI.getMeta({
            async: false, isDetail: true, ignoreQuery: true,
            model: this.view.model, viewGroup: viewGroup,
            callback: function (meta) {
                meta = meta.mainBlock || meta;
                if (meta && meta.formConfig && meta.formConfig.items) {
                    Ext.Array.forEach(meta.formConfig.items, function (item) { item.readOnly = true; });   // 全字段只读
                }
                meta.token = me.view.token;
                me.viewMeta = meta;   // 缓存 meta，下次复用
            }
        });
    }
    var cfg = {
        associateCmd: me, viewMeta: me.viewMeta, entity: current,
        title: this.getEditViewTitle(current),
        dialogcfg: { buttons: ["关闭"] }
    };
    me._editingView = SIE.App.showDialog(cfg);
},
```

---

## 二十、Web选择命令（LookupCommandBase）

**场景**：子表工具栏"选择"按钮，弹选择界面勾选数据写入中间表（多对多关联：选设备/物料/检验项目等）。

| 端 | 基类 |
|---|---|
| 前端 | `SIE.cmd.LookupCommandBase` |
| 后端 | `ViewCommand` |

执行链：`execute() → _checkParameter(callback) → Ext.require 加载完成 → _loadSourceViewAllData() → _popupWin() 弹窗 → save() 提交`。

### 20.1 基础用法

```javascript
SIE.defineCommand('SIE.Web.Tech.ProcessPositions.Commands.SelectEquipCommand', {
    extend: 'SIE.cmd.LookupCommandBase',
    meta: { text: "选择", group: "edit", iconCls: "icon-PlaylistCheck icon-blue" },
    userConfig: {
        dataParams: {
            specKeyPrototyName: 'EquipAccountId',                            // 命令所属视图实体的字段（关联已选数据）
            targetClassName: 'SIE.Core.Equipments.EquipAccountCoreSelect',   // 选择实体类型
        },
        gridCfg: { multiSelect: true, pageSize: 25 },
    },

    execute: function (view, source) {
        var me = this;
        me._checkParameter(() => {
            SIE.Msg.wait("正在处理，请稍候...".t());
            me._loadSourceViewAllData(view, source);
        });
    },

    // 【标准实现，照抄】计数器 + onReady 确保 Ext.require 全部完成
    _checkParameter: function (callback) {
        var dataParams = this.dataParams;
        if (Ext.isEmpty(dataParams.specKeyPrototyName)) SIE.emptyArgument('specKeyPrototyName');
        if (Ext.isEmpty(dataParams.targetClassName)) SIE.emptyArgument('targetClassName');
        var resources = [
            dataParams.targetClassName,
            dataParams.targetCriteriaClassName || dataParams.targetClassName + 'Criteria'
        ];
        var count = 0;
        var onReady = () => { count++; if (count >= resources.length) callback(); };
        for (var i = 0; i < resources.length; i++) { Ext.require(resources[i], onReady); }
    },

    save: function (win) {
        var me = this;
        var selections = me._targetSelectItems.items;      // 弹窗选中项
        var srcViewSelectedIds = me._sourceViewSelectItems; // 已有 ID（防重复）
        if (selections && selections.length > 0) {
            var middleDataList = [];
            SIE.each(selections, function (item) {
                if (srcViewSelectedIds.indexOf(item.getId()) === -1) {
                    middleDataList.push({ ProcessPositionId: me._sourceId, EquipAccountId: item.getId() });  // 组装中间表
                }
            });
            me._ownerView.execute({
                data: middleDataList,
                success: function (res) {
                    me._ownerView.loadChildData(true);     // 刷新子表
                    SIE.Msg.showInstantMessage("操作成功".t());
                    win.close();
                }
            });
        } else { SIE.Msg.showWarning('没有可提交的数据'.t()); }
    },
});
```

**后端**（中间表写入标准写法）：

```csharp
public class SelectEquipCommand : ViewCommand
{
    protected override object Excute(ViewArgs args, string scope)
    {
        var equipList = args.Data.ToJsonObject<List<ProcessPositionEquip>>();
        if (equipList == null || equipList.Count == 0)
            throw new ValidationException("提交数据不可为空".L10N());
        var list = new EntityList<ProcessPositionEquip>();
        foreach (var item in equipList)
            list.Add(new ProcessPositionEquip { EquipAccountId = item.EquipAccountId, ProcessPositionId = item.ProcessPositionId });
        RF.Save(list);
        return true;
    }
}
```

### 20.2 弹出界面添加工具栏（选项面板）

**场景**：弹窗顶部加选项（如"推送方式"下拉），save 时读取选项一起提交。

**三段式**：

```javascript
// ① getMetacallback — 介入弹窗渲染流程（LookupCommandBase 唯一介入点）
getMetacallback: function (blocks, source) {
    var me = this;
    me._queryBlockProcess(blocks);
    me._gridBlockProcess(blocks);
    me.addToolbar(blocks, () => {
        var ui = SIE.AutoUI.generateAggtControl(blocks);
        me._popupWin(ui, source);
        me._reloadTargetViewData();
    });
},

// ② addToolbar — 动态加载选项实体渲染到工具栏
addToolbar: function (blocks, callback) {
    var me = this;
    var meta = blocks.mainBlock || blocks;
    var toolBar = meta.gridConfig.tbar = [];               // 工具栏数组
    var optionModel = "SIE.Grikin.Smom.QualityKPIs.QualityAlertOptionViewModel";  // 选项 ViewModel
    SIE.AutoUI.getMeta({
        async: true, ignoreCommands: true, isDetail: true, ignoreQuery: true,
        token: meta.token, model: optionModel,
        callback: function (res) {
            var mainBlock = res.mainBlock || res;
            var model = SIE.getModel(optionModel);
            var entity = new model();
            var view = SIE.AutoUI.createDetailView(mainBlock, entity);
            var ui = view.getControl();
            view.validateData();
            me.optionEntity = entity;      // 存引用，save 时读 me.optionEntity.data.Xxx
            toolBar.push(ui);
            ui.width = "100%";
            callback(meta);
        }
    });
},

// ③ save — 读取工具栏选项并传参
save: function (win) {
    var me = this;
    var alertType = me.optionEntity.data.AlertType;
    if (alertType == null) { SIE.Msg.showWarning('请选择推送方式'.t()); return; }
    // ... ownerView.execute({ data: { DetailIds, EmployeeIds, PushTypes: [alertType] }, callback: ... })
},
```

**坑点**：不要在 execute 里直接操作 UI（元数据未加载就渲染会报错）；选项 getMeta 四参数 `async:true, ignoreCommands:true, ignoreQuery:true, isDetail:true` 是选项面板的固定组合。

### 20.3 根据主表数据过滤

**场景**：弹窗查询条件按主表字段自动过滤并锁定（如工序下选岗位只显示该工序的岗位）。

**四步**：

```javascript
// ① 命令顶层声明主表参数容器
extParam: { ProcessId: null, ProcessName: null },

// ② execute 读父视图
execute: function (view, source) {
    var me = this;
    var parentView = view.getParent();
    var parent = parentView.getCurrent();
    this.extParam.ProcessId = parent.data.ProcessId;
    this.extParam.ProcessName = parent.data.ProcessId_Display;
    me._checkParameter(() => { me._loadSourceViewAllData(view, source); });
},

// ③ _popupWin 末尾重写查询视图 tryExecuteQuery（查询前后各注入一次）
var queryView = me._targetView._relations[0]._target;
var tryExecuteQuery = queryView.tryExecuteQuery;
queryView.tryExecuteQuery = (opt) => {
    var current = queryView.getCurrent();
    var setValues = function () {
        if (me.extParam) {
            current.data.ProcessId_Display = me.extParam.ProcessName;
            current.data.ProcessId = me.extParam.ProcessId;
            current.data.V_ProcessName = me.extParam.ProcessName;
        }
        queryView.updateControl();
    };
    setValues();                          // ① 查询前注入
    tryExecuteQuery.call(queryView, opt); // ② 原始查询
    setValues();                          // ③ 查询后再注入（防内部重置）
};

// ④ _queryBlockProcess 锁定注入字段
_queryBlockProcess: function (block) {
    if (block.surrounders) {
        var items = block.surrounders["0"].mainBlock.formConfig.items;
        if (items) {
            for (var i = 0; i < items.length; i++) {
                var item = items[i];
                if (item.name == "ProcessId") item.readOnly = true;
                else if (item.name == "V_ProcessName") item.readOnly = true;
                else item.readOnly = false;
            }
        }
    }
},
```

**坑点**：查询后必须再次 `setValues()`（tryExecuteQuery 内部可能重置字段）；extParam 字段名必须与弹窗查询视图字段名一致；后端与普通选择命令完全一致（过滤纯前端）。

### 20.4 资源加载滞后导致报错（必看）

**问题**：`Ext.require` 异步加载，若 `_checkParameter` 末尾直接调 `callback()`，资源未加载完，后续创建 Criteria 等依赖类定义的代码报 undefined。

**修复**：计数器 + onReady 模式（见 20.1 的 `_checkParameter` 标准实现）。要点：
- resources 必含 `targetClassName` 和对应 Criteria 类（默认命名 `{targetClassName}Criteria`）
- count 计数，全部就绪（`count >= resources.length`）才 callback
- 每个 `Ext.require(res, onReady)` 传同一个 onReady

**相关变体 save**（选择后不调后端、直接前端回填子表行）：

```javascript
save: function (win) {
    // ... 组装 detailList 后：
    var childView = me._ownerView;
    SIE.each(detailList, function (detail) {
        var newItem = childView.createNewItem();
        newItem.set('KpiStandardId', detail.KpiStandardId);
        newItem.set('KpiNo', detail.KpiNo);
        // ... 逐字段 set（引用属性同时 set Id 与 Id_Display）
    });
    win.close();
}
```

此变体适合"从选择目标抓多列数据直接填子表"场景；配合 `me._sourceViewSelectItems` 防重复添加。
