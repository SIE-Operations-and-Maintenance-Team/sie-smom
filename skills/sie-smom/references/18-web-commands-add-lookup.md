> **类型**：配方库（蒸馏自 SMOM 开发手册 /WebDev/Web命令/，2026-08-17 版本）
> **来源**：http://10.10.51.213:30687/WebDev/Web命令/
> **优先级**：高。写添加/选择/弹窗查看命令时先读本文件照搬模式。
> **覆盖范围**：添加命令（表单编辑/行内编辑+自动生成单号）·通用弹窗查看命令·选择命令 LookupCommandBase（基础用法/选项面板工具栏/主表数据过滤/资源加载滞后）
> **拆分说明**：原 `18-web-commands.md`（61K，23 篇配方）按任务域拆为 4 份：表单/列表保存提交 → `18-web-commands-form.md`；导入导出 → `18-web-commands-import-export.md`；添加/选择/弹窗查看 → `18-web-commands-add-lookup.md`；打印/附件/查找 → `18-web-commands-print-attach.md`。节号保留原手册序号（一~二十），便于溯源。

---

# Web 命令配方库 · 添加/选择/弹窗查看

## 配方索引（本文件）

| # | 任务 | 节 |
|---|---|---|
| 15 | 添加命令-表单编辑+自动生成单号 | 十五 |
| 16 | 添加命令-行内编辑+自动生成单号 | 十六 |
| 19 | 通用弹窗查看命令 | 十九 |
| 20 | 选择命令（LookupCommandBase 全家，含 20.1-20.4） | 二十 |
| 21 | 子表行内添加/删除命令（内嵌明细行增删） | 二十一 |
| 22 | 列表工具栏打开聚合页命令（页面跳转，纯 JS） | 二十二 |

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

---

## 二十一、Web子表行内添加/删除命令（内嵌明细行增删）

适用：主表 `ChildrenProperty` 内嵌子表需要"添加行 / 删除行"按钮——只 `View.InlineEdit()` 不配命令时子表**没有任何操作按钮**，无法维护行。

三件套（PackingLabelAdjustDetail / SpecialItemMarkConfigDetail 实证）：

**1. cs 命令**（一个文件可放多个命令类）：

```csharp
[JsCommand("SIE.Web.WMS.Common.Commands.AddXxxDtlCommand")]
public class AddXxxDtlCommand : ViewCommand
{
    /// <summary>
    /// 添加
    /// </summary>
    protected override object Excute(ViewArgs args, string scope)
    {
        return true;   // 前端 extend SIE.cmd.Add 负责新增行；需要默认值时在此构造实体并返回
    }
}

[JsCommand("SIE.Web.WMS.Common.Commands.DeleteXxxDtlCommand")]
public class DeleteXxxDtlCommand : DeleteCommand { }   // 空类即可
```

**2. js 命令**（csproj 必须 `None Remove` + `EmbeddedResource Include`，缺一运行时报 No such class）：

```javascript
SIE.defineCommand('SIE.Web.WMS.Common.Commands.AddXxxDtlCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加", group: "edit", iconCls: "iconfont icon-AddEntity icon-green" },
});
SIE.defineCommand('SIE.Web.WMS.Common.Commands.DeleteXxxDtlCommand', {
    extend: 'SIE.cmd.Delete',
    meta: { text: "删除", group: "edit", iconCls: "icon-DeleteEntity icon-red" },
    canExecute: function (view) {
        return view.getSelection() != null && view.getSelection().length > 0;   // 无选中禁用
    },
});
```

**3. 子表 ViewConfig 挂载**：

```csharp
protected override void ConfigListView()
{
    View.ClearCommands();
    View.InlineEdit();
    View.UseCommands(
        typeof(AddXxxDtlCommand).FullName,
        typeof(DeleteXxxDtlCommand).FullName);
    using (View.OrderProperties()) { /* 列配置 */ }
}
```

> 有单据状态的子表可参照 `AddPackLabelAdjustDtlCommand.js` 在 `canExecute` 里判 `view.getParent().getCurrent().getBillState()`；纯配置子表无需。

## 二十二、Web列表工具栏打开聚合页命令（页面跳转，纯 JS）

适用：从一个列表页打开另一个实体的维护页（如物料列表 → 备货等级管理 / 特殊物料标识配置）。**纯 JS 命令即可，无 cs**：

```javascript
SIE.defineCommand('SIE.Web.WMS.Common.Commands.SpecialItemMarkConfigCommand', {
    meta: { text: "特殊物料标识配置", group: "config", iconCls: "icon-DistributeObjectsHorizontal icon-blue" },
    execute: function (listView, source) {
        CRT.Workbench.addPage({
            title: '特殊物料标识配置'.t(),
            entityType: 'SIE.WMS.Common.SpecialItemMarkConfig',   // 目标实体全名
            module: listView.module,
            ignoreQuery: false,
            isAggt: true
        });
    }
});
```

挂载与配套：主档 ViewConfig `View.UseCommand("全名")`（字符串引用，跨模块无编译依赖）；目标实体无独立菜单时用 `AssignAuthorize<T>(typeof(宿主实体))` 挂权限——完整三件套见 04-web-viewconfig §十一。
