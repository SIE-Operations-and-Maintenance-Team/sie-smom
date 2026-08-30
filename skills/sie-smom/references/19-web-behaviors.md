# Web Behavior 与扩展编辑器配方库

## 配方索引

| # | 任务 | 节 |
|---|---|---|
| 1 | 可模糊搜索枚举编辑器 | 一 |
| 2 | 枚举多选扩展编辑器 | 二 |
| 3 | 动态列-透视表处理行为 | 三 |
| 4 | 动态切换枚举值可选范围 | 四 |
| 5 | 控制命令可执行时机（canExecute 包装） | 五 |
| 6 | 列表单元格变色 / 行变色 | 六 |
| 7 | 列表底部状态栏 | 七 |
| 8 | 列表默认分页大小 | 八 |
| 9 | 列表内存排序 | 九 |
| 10 | 列表属性变更事件（2 方案） | 十 |
| 11 | 新增自动填充当前员工信息 | 十一 |
| 12 | 列表统计行 | 十二 |
| 13 | 视图通用扩展方法与通用行为 | 十三 |

## Behavior 机制速记（全文件通用）

- **注册**：`View.AddBehavior(typeof(XxxBehavior).FullName)` —— C# Behavior 通常是**空壳类**（纯标记），框架按命名约定加载同名 JS，实际逻辑全在 JS。
- **JS 生命周期钩子**：`beforeCreate(meta, curEntity)`（view 生成前，可改 meta.gridConfig）→ `onCreated(view)`（view 生成后，可加 DOM/控件）→ `onViewReady(view)`（view 聚合后，绑事件）→ `onDataLoaded(view)`（数据加载后）。
- **绑定事件**：一律先 `mun` 解绑再 `mon` 绑定，防 onViewReady 多次调用导致重复监听。
- **视图扩展方法模式**（十三节）：cs 静态扩展方法 `RemoveBehavior(name) + AddBehavior(name)` + `SetExtendedSetting(key, value)` 传参，JS 行为从 `view.config.gridConfig[key]` 读参。

---

## 一、可模糊搜索枚举编辑器

**用法**：`View.Property(p => p.JobType).UseEnumFilterEditor();`

**实现**（cs 扩展方法基于 UseEnumEditor 改 XType）：

```csharp
public static WebEntityPropertyViewMeta<T> UseEnumFilterEditor<T>(this WebEntityPropertyViewMeta<T> meta,
    Action<EnumBoxConfig> action = null)
{
    meta.UseEnumEditor(p =>
    {
        p.IsEnumNull = true;
        action?.Invoke(p);
        p.Editable = true;
        p.XType = "enumfilter";
        p.ColumnXType = "enumfiltercolumn";
    });
    return meta;
}
```

**js**（编辑器 + 列控件两个类，逻辑相同）：

```javascript
Ext.define('SIE.Web.Core.Editors.EnumFilter', {
    extend: 'SIE.control.XComboBox',
    alias: 'widget.enumfilter',
    anyMatch: true,   // 模糊匹配
    listeners: {
        // 手输枚举名不在集合内时，失焦清空
        blur: function (combo) {
            var store = combo.getStore();
            var rawValue = combo.getRawValue();
            var isEnum = false;
            store.each(function (record) { if (rawValue == record.get('text')) isEnum = true; });
            if (!isEnum) { combo.setRawValue(null); combo.setValue(null); }
        },
    },
});
// EnumFilterColumn 同理：extend 'SIE.grid.column.ComboBox', alias 'widget.enumfiltercolumn'
```

---

## 二、枚举多选扩展编辑器

**用法**：

```csharp
View.Property(p => p.Color).UseEnumExEditor();                       // 与普通枚举编辑器一致
View.Property(p => p.Color).UseEnumExEditor(p => {                   // 筛选可选枚举
    return new Dictionary<string, string> {
        { ((int)Color.Red).ToString(), Color.Red.ToLabel() },
        { ((int)Color.Blue).ToString(), Color.Blue.ToLabel() },
    };
});
View.Property(p => p.Color).UseEnumExEditor(p => { p.MultiSelect = true; });  // 多选（字段类型须为 string）
```

**实现要点**（`UseEnumExEditor` → `UseDropDownExEditor`）：
- `MultiDropDownConfig : ComboBoxConfig` 增加 `MultiSelect` 属性（ToJson 写 `multiSelect`）
- 多选时 `config.XType = "tagfield"`；可空单选时数据源补一条空键值
- 列名固定 `config.ColumnXType = "EnumExEditorColumnXType"`
- 枚举数据经 `EnumViewModel.GetByEnumType(type)` 生成（可按 `category` 参数筛选 `[Category]` 分组）
- 列表显示用自定义 column renderer：按编辑器 store 建键值字典，把 `值1,值2` 翻译为 `显示1,显示2`（delimiter 连接）

---

## 三、动态列-透视表处理行为

**场景**：行=固定维度（如指标），列=动态周期，且不达标值标红。参考案例 `QualityTargetPlanAchievementPivot`。

**架构**：`ViewConfig(AddBehavior) → C# Behavior(空壳) → JS Behavior(桥接+父视图联动) → JS Controller(动态列核心)`。

**后端**：
1. ViewModel 加 `string PeriodList` 属性，Controller `pivot.PeriodList = JsonConvert.SerializeObject(periodList);`（周期子对象 ViewModel 含 `StartDate/EndDate/PeriodLabel/DisplayValue/SortOrder/IsUnqualified`）。
2. ViewConfig：`View.UseClientOrder(); View.WithoutPaging(); View.AddBehavior(typeof(XxxPivotBehavior).FullName);`（透视表不分页、客户端排序）。
3. 主表挂载：`View.AttachChildrenProperty(typeof(XxxPivot), (o) => { ... return controller.GetPivot(entity.Id); }, allowPaging: false).HasLabel("...").Show(ChildShowInWhere.All);`

**JS Controller 核心流程**：`onDataLoaded → removeAllDynamicColumns → collectPeriodLabels(跨行去重按日期排序) → getInsertPosition → 循环 addColumn → 遍历 store 映射值 → store.commitChanges()`

```javascript
// 动态加列：dataIndex 用固定前缀+序号（不用标签文本，避免特殊字符问题）
var dataIndex = 'PeriodVal_' + i;
var column = {
    text: periodLabels[i], dataIndex: dataIndex, width: "250", isDynamic: true,   // isDynamic 标记便于移除
    renderer: function (value, metaData, record, rowIndex, colIndex, store, view) {
        var column = view.getHeaderAtIndex(colIndex);   // 用 colIndex 取 dataIndex，避开闭包陷阱
        if (record.data[column.dataIndex + '_Unqual']) metaData.style = 'color: #FF0000;';
        return value || '';
    }
};
view.getControl().addColumn(
    { name: dataIndex, type: 'string', defaultValue: null },   // Store 字段定义
    column,
    insertPosition + i
);

// 映射值：record.set(dataIndex, period.DisplayValue); record.set(dataIndex + '_Unqual', period.IsUnqualified);

// 移除旧动态列（倒序删防索引偏移）：
var columns = view.getControl().columnManager.columns;
for (var i = columns.length - 1; i >= 0; i--) { if (columns[i].isDynamic) view.getControl().removeColumn(i); }
```

**JS Behavior**（桥接 + 父视图联动）：

```javascript
onViewReady: function (view) {
    var controller = new XxxPivotController();
    controller.setView(view);
    view.setController(controller);
    var parentView = view.getParent();          // 子表响应主表选择变化
    parentView.mun(parentView, "selectionChanged", this.onParentSelectionChanged);
    parentView.mon(parentView, "selectionChanged", this.onParentSelectionChanged, this);
},
```

**导出配合**：exportXls 中按 `colIdx + '_Unqual'` 判断，设 `cellConfig.style = { font: { Color: '#FF0000' } }`。

**坑点**：renderer 不能直接引用循环变量 i（闭包陷阱）；`addColumn` 前两个参数必填（Store 字段定义 + 列配置），第三参为插入位置（可选）；父表切行必须先清理旧动态列。

---

## 四、动态切换枚举值可选范围行为

**场景**：某属性值变化后联动限制另一枚举编辑器的可选值（如仅"库区盘点+全盘"可选盲盘）。

```javascript
Ext.define('...AddMoldInventoryCheckBehavior', {
    view: null,
    onViewReady: function (view) {
        var entity = view.getCurrent();
        this.view = view;
        view.mon(entity, 'propertyChanged', this._onEntityPropertyChanged, this);   // 单实体属性监听
    },
    _onEntityPropertyChanged(e) {
        var entity = e.entity; var property = e.property;   // e.value 可取新值
        switch (property) {
            case "CheckType": this.changeExecuteMode(this.view, entity); break;
            case "CheckMode": this.changeExecuteMode(this.view, entity); break;
        }
    },
    setEnumEditorValues(view, fieldName, values) {
        var editor = view.getControl().down(`[name=${fieldName}]`);
        editor.setValue(null);                                // 先清当前值
        var editorStore = editor.getStore();
        var originalDatas = editorStore.config.data;          // 原始枚举数据
        values.push(null);                                    // 加空选项
        var datas = originalDatas.filter(p => values.indexOf(p.value) != -1);
        editorStore.loadData(datas, false);
    },
});
```

---

## 五、控制命令可执行时机行为（canExecute 包装）

**场景**：单据启用后（State==1）批量禁用编辑类命令，白名单命令（导出/启禁用）不受影响，顶层"添加/导入"不受限。**不重写任何命令**，纯装饰器模式。参考案例 `PhysAndChemStandardCommandBehavior`。

```javascript
Ext.define('...PhysAndChemStandardCommandBehavior', {
    onViewReady: function (view) { this.changeCanExecute(view); },

    changeCanExecute: function (view) {
        var cmdNames = ['导出', '导出选中', '导出全部', '启用', '禁用'];   // 完全跳过的命令（按 meta.text 匹配）
        var topNames = ['添加', '导入'];                                  // 顶层视图跳过的命令

        var commands = view.getCommands();
        if (!commands || !commands.items || !commands.items.length) return;

        var getTopView = function (v) {
            var p = v;
            while (true) { var t = p.getParent(); if (!t) break; p = t; }
            return p;
        };

        Ext.Array.each(commands.items, function (command) {
            if (cmdNames.indexOf(command.meta.text) != -1) return;
            var originalCanExecute = command.canExecute;
            command.canExecute = function (cmdView) {
                var topView = getTopView(cmdView);
                if (topView == cmdView && topNames.indexOf(command.meta.text) != -1)
                    return originalCanExecute.call(command, cmdView);     // 顶层白名单直接放行
                var current = topView.getCurrent();
                if (current && current.data.State == 1) return false;     // 禁用条件
                return originalCanExecute.call(command, cmdView);         // 原逻辑
            };
        });
    }
});
```

**要点**：
- 保存 `originalCanExecute`，新函数用 `.call(command, cmdView)` 调原函数保证 this/参数正确
- 新增命令自动受控（无需逐个配置）；同一 Behavior 可注册到多个 ViewConfig
- 禁用条件可按需替换（Status/多条件/当前用户），也可加 `command.setHidden(true)` 或 setTooltip 提示
- C# Behavior 空壳 + `View.AddBehavior(typeof(XxxCommandBehavior).FullName)` 注册

---

## 六、列表单元格变色 / 行变色

**单元格变色**（beforeCreate 给所有列挂 renderer）：

```javascript
beforeCreate: function (meta, curEntity) {
    var gridConfig = meta.gridConfig;
    gridConfig.columns.forEach(columnConfig => {
        Ext.merge(columnConfig, { renderer: this.colorRenderer });
    });
},
colorRenderer: function (value, meta, record, rowndex, colindex, store, view) {
    switch (record.data.ProduceAlertValue) {
        case 1: meta.style = 'color:#ffffff;background:#e68e06;'; break;   // 预警：橙
        case 2: meta.style = 'color:#ffffff;background:#a71720;'; break;   // 延迟：红
    }
    // 保留列原有渲染（下拉翻译等）
    var column = meta.column;
    var controller = column.getController();
    if (controller && controller.renderComboData) return controller.renderComboData.apply(controller, arguments);
    var defaultRenderer = column.defaultRenderer;
    if (defaultRenderer) return defaultRenderer.call(column, value, meta, record, rowndex, colindex, store, view);
    return value;
}
```

**行变色**（getRowClass，对一行所有单元格生效）：

```javascript
beforeCreate: function (meta, curEntity) {
    meta.gridConfig.viewConfig = {
        getRowClass: function (record, index, rowParams, store) {
            if (record.data.ItemType == 1) return 'bg-warning';
        }
    };
}
```

---

## 七、列表底部状态栏行为

**场景**：列表底部加统计信息条（生产池/今日完成/预警/超期计数）。

```javascript
onCreated: function (view) {
    var mainCtl = view.getControl();
    var bottomBar = Ext.create({
        xtype: 'container', dock: 'bottom', padding: 8, viewModel: { data: {} },
        items: [
            { xtype: 'label', margin: '5 15', bind: '生产池：{producingCount}' },
            { xtype: 'label', margin: '5 15', bind: '预警：{alertCount}', style: { color: '#e68e06' } },
            // ...
        ]
    });
    mainCtl.dockedItems.add(bottomBar);
    // 暴露到 view 上供外部调用
    view.getBottomBar = () => bottomBar;
    view.setBottomBarData = (data) => {
        data = data || {};
        var vm = bottomBar.getViewModel();
        vm.set('producingCount', data.OrderProducingCount || 0);
        vm.set('alertCount', data.OrderAlertCount || 0);
        // ...
    };
    view.setBottomBarData(null);
},
```

---

## 八、列表默认分页大小

**用法**（视图配置）：`View.UseDefaultPageSize(100);`

**实现**：cs 扩展方法 `meta.EntityViewMeta.PageSize = pageSize;` + RemoveBehavior/AddBehavior(`SIE.Web.Core.UseDefaultPageSizeBehavior`)；JS 行为在 `onViewReady` 中设置 `view._pagingBar.store.setPageSize(pageSize)` 和 `view._pagingBar.items.map["pageSizeItem"].setValue(pageSize)`。

---

## 九、列表内存排序行为

**场景**：框架配置不能满足时，前端排序代替远程排序。**用法**：`View.UseLocalSort();`

**实现要点**（JS `SIE.Web.Core.UseLocalSortBehavior`，onDataLoaded 中）：
- `store.setRemoteSort(false)` + 重写 `store.sort(field, direction, mode)`
- 数据未保存（isDirty）时弹确认框 `Ext.MessageBox.confirm("数据还未保存，是否排序？")`
- **引用属性排序用显示值**：`if (objFiled[field + "_Display"]) field += "_Display";` 再 `getSorters().addSort(...)`
- 空参调用（`arguments.length === 0`）时 `me.forceLocalSort()`

---

## 十、列表属性变更事件处理（2 方案）

**背景**：列表数据变更渠道多（添加/复制新增/代码插入/刷新），绑事件要覆盖所有场景。

**方案 1：选择事件中绑实体属性变更**（理论上编辑中的数据必选中）：

```javascript
onViewReady: function (view) {
    this._view = view;
    view.mon(view, "selectionChanged", this.onSelectionChanged, this);
},
onSelectionChanged: function (e) {
    this._view.mun(e.newValue[0], "propertyChanged");                                   // 先解绑
    this._view.mon(e.newValue[0], "propertyChanged", this.onPropertyChanged, this);      // 再绑定
},
onPropertyChanged: function (e) {
    var entity = e.entity; var property = e.property;   // 可拿到变更前的值
},
```

**方案 2：监听 Grid edit 事件**（任何渠道加入表格的数据都可监听，但**拿不到变更前的值**，且值未变也触发）：

```javascript
onViewReady: function (view) {
    var control = view.getControl();
    view.mon(control, 'edit', this._propertyChanged, this, { view: view });
},
_propertyChanged: function (editor, context, eOpts) {
    var entity = context.record;
    var property = context.field;
    if (property == "SparePartId") { /* 联动逻辑 */ }
},
```

**选型**：需要旧值 → 方案 1；只需"某字段被编辑过"且要覆盖非选中编辑 → 方案 2。

---

## 十一、新增自动填充当前员工信息行为

**场景**：Grid 新增行自动填 CreateById/UpdateById 等为当前登录人。基类 `SIE.Web.Core.Behaviors.AutoFillEmployeeBehavior`（纯 JS 无 C#，与下方 extend 一致），**派生只需覆盖 employeeFields**：

```javascript
Ext.define('SIE.Web.XXX.Behaviors.MyBehavior', {
    extend: 'SIE.Web.Core.Behaviors.AutoFillEmployeeBehavior',
    employeeFields: ['CreateById', 'UpdateById']
});
// ViewConfig: View.AddBehavior(typeof(MyBehavior).FullName);
```

**基类机制**：onViewReady 中 `store.un('add') → store.on('add')`（防重复绑）→ 新记录对每个 field 设置两个字段：`record.set(field, userInfo.EmployeeId)` + `record.set(field + '_Display', userInfo.Name)`（引用属性 = ID 字段 + _Display 显示字段）。

**关键 API**：当前用户 `CRT.Context.GlobalContext.getContext('userInfo')`（含 EmployeeId、Name）；字段存在性校验 `record.fieldsMap && record.fieldsMap[field]`。

---

## 十二、列表统计行行为

**场景**：纯前端统计行（Ext summary feature），无后台处理。建议放通用模块，使用时继承重写列名。

```javascript
Ext.define('SIE.Web.Customized.AddSummaryRowBehavior', {
    summaryCountColumnNames: [],              // 计数列
    summarySumColumnNames: ["Qty"],           // 求和列
    summarySumDecimalColumnNames: ["DecimalQty"],  // 小数求和列（防浮点误差）

    beforeCreate: function (meta, curEntity) {
        if (meta && meta.gridConfig && meta.gridConfig.columns) {
            meta.gridConfig["features"] = [{ ftype: 'summary' }];
            var columns = meta.gridConfig.columns;
            for (var i = 0; i < columns.length; i++) {
                if (this.summarySumDecimalColumnNames.indexOf(columns[i]["dataIndex"]) != -1)
                    columns[i]["summaryType"] = this.summarySum;      // 自定义：按最大小数位整数化累加
                else if (this.summarySumColumnNames.indexOf(columns[i]["dataIndex"]) != -1)
                    columns[i]["summaryType"] = "sum";
                else if (this.summaryCountColumnNames.indexOf(columns[i]["dataIndex"]) != -1)
                    columns[i]["summaryType"] = "count";
            }
        }
    },
    // summarySum(records, values)：取各值最大小数位 maxPrecision → 逐值 Math.round(v*10^n) 累加 → 除回
});
```

---

## 十三、视图通用扩展方法与通用行为

### 13.1 通用视图扩展方法（`EntityViewMetaExtension.cs`，配合各行为使用）

```csharp
meta.AddSingleBehavior(behaviorName);   // 添加不重复行为（内部 RemoveBehavior + AddBehavior）
view.ClearBehaviors();                  // 清空行为
view.HideAllPropertys();                // 所有属性 ShowInWhere.Hide
view.HideAllChildPropertys();           // 所有子列表 ChildShowInWhere.Hide
view.SetExtendedSetting(name, value);   // 写扩展配置（去重后加入 ExtensionJsConfigs，JS 从 view.config.gridConfig[name] 读）
```

### 13.2 列表自动列宽

```csharp
View.UseAutoColumnWidth();                                   // 全部列
View.UseAutoColumnWidth(Item.NameProperty, Item.CodeProperty);        // 指定列
View.UseAutoColumnWidthExcept(Item.NameProperty, Item.CodeProperty);  // 例外列
```

实现：cs 设置（`AutoColumnWidthBehavior_SpecificColumns` / `_ExceptColumns`）+ JS（`SIE.Web.Core.AutoColumnWidthBehavior`）在 `onCreated` 绑 store load（并监听 view dataChanged 应对子列表换 store），数据加载后对目标列 `Ext.suspendLayouts() → 逐列 _autoSizeColumn → Ext.resumeLayouts(true)`；优先用 `tableView.getMaxContentWidth(col)` 自算宽度（分辨率缩放后 Ext 像素识别有问题），无该方法才 `col.autoSize()`。

### 13.3 列表字段必填样式（列头红星）

```csharp
View.UseRequiredMark();                                      // 全部列
View.UseRequiredMark(Item.NameProperty);                     // 指定列
View.UseRequiredMarkExcept(Item.NameProperty);               // 例外列
```

JS（`SIE.Web.Core.RequiredMarkBehavior`）onCreated 中对目标列 `col.setText(col.text + "<div style='display:inline-block;color:red;font-size:1.2rem;width:1rem;'>*</div>")`。

### 13.4 列表双击触发命令

```csharp
View.UseDoubleClickForCmd(typeof(ViewApiLogCommand).FullName);
```

JS（`SIE.Web.Core.Common.Behaviors.DoubleClickForCmdBehavior`）onViewReady 绑 `grid.rowdblclick`，从 `view.config.gridConfig["DoubleClickForCmdBehavior_SpecificCmd"]` 读命令名，`view.getCommands().map[commandType]` 取命令，`Ext.getCmp(command.config.meta.id)` 取按钮元素后 `command.tryExecute(commandEl)` 触发。
