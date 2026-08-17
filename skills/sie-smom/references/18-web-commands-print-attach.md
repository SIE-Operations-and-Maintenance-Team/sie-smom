> **类型**：配方库（蒸馏自 SMOM 开发手册 /WebDev/Web命令/，2026-08-17 版本）
> **来源**：http://10.10.51.213:30687/WebDev/Web命令/
> **优先级**：高。写打印/附件/查找命令时先读本文件照搬模式。
> **覆盖范围**：查看附件（图片预览）·打印命令（8.0/8.3/9.0 版本差异）·列表数据查找（前端内存查找）·通用标签打印命令基类·通用单据打印命令基类
> **拆分说明**：原 `18-web-commands.md`（61K，23 篇配方）按任务域拆为 4 份：表单/列表保存提交 → `18-web-commands-form.md`；导入导出 → `18-web-commands-import-export.md`；添加/选择/弹窗查看 → `18-web-commands-add-lookup.md`；打印/附件/查找 → `18-web-commands-print-attach.md`。节号保留原手册序号（一~二十），便于溯源。

---

# Web 命令配方库 · 打印/附件/查找

## 配方索引（本文件）

| # | 任务 | 节 |
|---|---|---|
| 4 | 查看附件命令（图片预览） | 四 |
| 5 | 打印命令（8.0/8.3/9.0 版本差异） | 五 |
| 12 | 列表数据查找命令（前端内存查找） | 十二 |
| 17 | 通用标签打印命令基类 | 十七 |
| 18 | 通用单据打印命令基类 | 十八 |

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

