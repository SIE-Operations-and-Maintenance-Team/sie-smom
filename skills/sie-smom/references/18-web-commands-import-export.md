> **拆分说明**：原 `18-web-commands.md` 按任务域拆为 4 份；节号保留原手册序号（一~二十二），跨文件不连续属正常。

---

# Web 命令配方库 · 导入导出

## 配方索引（本文件）

| # | 任务 | 节 |
|---|---|---|
| 6 | 导出命令-多表聚合（主从 JOIN 展开） | 六 |
| 7 | 导入命令（简单/复杂 IBusinessImport） | 七 |
| 8 | 导入命令-使用自定义模板文件 | 八 |
| 9 | 导入命令-子表导入-继承内置导入 | 九 |
| 10 | 框架通用导入命令增强（UseImportExtCommands） | 十 |
| 13 | 列表数据导出命令（ExporterSlim 轻量导出） | 十三 |
| 14 | 列表数据导入命令（填界面不落库） | 十四 |

---

## 六、Web导出命令-多表聚合

**场景**：主从（1:N）实体导出 Excel，主表字段在子表行展开（类 SQL JOIN）。基类 `BaseExportCommand<T1, T2, T3, T4>`（自研，位于 `SIE.Web.Core.Common.Commands`）。

**泛型**：T1 主表、T2 子表、T3/T4 预留（传 `object` 即可）。需重写 3 个成员：`Name`（文件名）、`InitColumnDefs()`、`CreateExcelData(double[] ids)`。

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
                // newEntity 为按行解析构建的待保存实体（构建过程省略）
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
        var fileReader = new FileReader();
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
        // importResult / ImportType / ImportView 来自基类成员或外部初始化，此处省略
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

## 十三、Web列表数据导出命令（ExporterSlim 轻量导出）

**场景**：选中/当前列表数据传后台，NPOI 生成 Excel 回传。核心工具：`ExporterSlimBuilder<T>` + `ExportColumnModelContainer<T>`（`SIE.Web.Core.Exports`）。

**命令 cs**：

```csharp
internal class ExportMoldChangeTaskCommand : ViewCommand<List<MoldChangeTask>>
{
    protected override object Excute(List<MoldChangeTask> args, string scope)
    {
        if (args.Count == 0) throw new ValidationException("没有可导出的数据");

        var exporterBuilder = new ExporterSlimBuilder<MoldChangeTask>();
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

