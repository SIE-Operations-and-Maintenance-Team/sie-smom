> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：03-____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：DataQueryer分层·ExtJS Layout·Controller·通用工具·JS嵌入资源·禁止前端直访DB

---

# Web 前端规范

> **适用范围**:本规范适用于项目中所有 `*.cs`、`*.js` 文件,始终生效。
> **内容概要**:DataQueryer 分层封装、ExtJS Layout/Controller、通用工具方法、Web Command、JS 嵌入资源规范、Web Behavior、禁止前端直访数据库。

## 一、DataQueryer 数据查询规范

**严禁在页面 JS/TS 中直接裸写 SIE.invokeDataQuery 完整请求代码。**

必须按分层封装:
1. 前端新建固定文件夹 DataQueryer
2. 文件夹内创建 xxxDataQueryer 类，强制继承基类 DataQueryer
3. 接口请求全部写在 xxxDataQueryer 类的内部方法中

### 后端 DataQueryer
```csharp
public class DockMapDataQueryer : Data.DataQueryer
{
    public List<ZoneData> RefreshGetDocks(DockSearchParams searchParams)
    {
        // 业务逻辑
    }
}
```

### 前端 JS 调用
```javascript
SIE.invokeDataQuery({
    async: false,
    type: "SIE.Web.xxx.xxxx.DataQueryer.xxxxxxDataQueryer",
    method: 'xxxx',
    token: me.view.token,
    params: [],
    success: function (res) {
        var data = res.Result;
    }
});
```

## 二、ExtJS Layout 定义
```javascript
Ext.define('SIE.Web.Module.Scripts.XxxLayout', {
    extend: 'SIE.Web.Core.Reports.RateReportLayoutBase',
    xtype: 'XxxLayout',

    _layoutChildren: function (regions) {
        var me = this;
        return Ext.widget('container', {
            layout: 'border',
            items: [{ region: 'north', items: toolbar }, { region: 'center', items: [me.createGrid(me)] }]
        });
    },

    loadData: function (criteria, token) {
        SIE.invokeDataQuery({
            method: 'GetData', params: [criteria], action: 'queryer', async: false,
            type: 'SIE.Web.Module.DataQueryer.XxxDataQueryer', token: token,
            success: function (res) { if (res.Success) { var data = res.Result; } }
        });
    },
});
```

## 三、ExtJS Controller 定义
```javascript
Ext.define('SIE.Web.Module.Scripts.XxxController', {
    extend: 'SIE.Web.Core.Reports.PivotController',
    alias: 'controller.XxxController',
    exportTo: function (btn) {
        this.doExport(Ext.merge({ title: '报表'.t(), fileName: '报表'.t() + '.xlsx' }, btn.cfg));
    },
});
```

## 四、通用工具方法
```javascript
SIE.Web.Core.CommonFuns.round(3.14159, 2); // 四舍五入
SIE.Web.Core.CommonFuns.markSaved(entity);   // 标记已保存
SIE.Web.Core.CommonFuns.mainReloadData(view); // 重新加载
SIE.Web.Core.CommonFuns.showPopView(model, module, title); // 打开弹窗
```

## 五、Web Command 规范
表单保存命令继承 FormSaveCommand:

```csharp
public class SaveXxxCommand : FormSaveCommand
{
    protected override void DoSave(Entity entity)
    {
        if (entity == null)
            throw new ValidationException("没有数据可以提交。".L10N());
        var data = entity as XxxEntity;
        RT.Service.Resolve<XxxController>().SaveXxx(data);
    }
}
```

## 六、JS 文件嵌入资源规范

**所有 JS 文件的生成操作必须设置为"嵌入资源"(Embedded Resource)。**

在 `.csproj` 项目文件中，确保所有 `.js` 文件配置为嵌入资源：

```xml
<ItemGroup>
  <EmbeddedResource Include="Scripts\**\*.js" />
</ItemGroup>
```

或者通过通配符统一设置：

```xml
<PropertyGroup>
  <DefaultItemExcludes>$(DefaultItemExcludes);Scripts\**\*.js</DefaultItemExcludes>
</PropertyGroup>

<ItemGroup>
  <EmbeddedResource Include="Scripts\**\*.js" />
</ItemGroup>
```

**注意事项：**
- 禁止将 JS 文件设置为 `Content` 或 `None`
- 嵌入资源确保 JS 文件编译进程序集，部署时不会遗漏
- 新增 JS 文件时无需手动修改 csproj，通配符会自动包含

**⚠️ 强制规则：AI 助手每创建一个 JS 文件，必须同步在 .csproj 中完成以下两处配置，缺一不可：**

```xml
<!-- 1. None Remove 中添加（移除默认的 None 包含） -->
<None Remove="路径\文件名.js" />

<!-- 2. EmbeddedResource Include 中添加（注册为嵌入资源） -->
<EmbeddedResource Include="路径\文件名.js" />
```

**未配置会导致 JS 文件不会被编译进程序集，运行时报错：No such Entity / No such class。**

## 七、Web Behavior 规范
使用静态扩展方法注册:

```csharp
public static class GridPageInfoBehavior
{
    public static WebEntityViewMeta<TEntity> SetPagingInfo<TEntity>(this WebEntityViewMeta<TEntity> meta, int defaultPageSize, List<int> pageSizes = null)
    {
        meta.AddBehavior("SIE.Web.Core.Behaviors.GridPageInfoBehavior");
        meta.SetExtendSetting("Grid_PageInfo", JsonConvert.SerializeObject(new { defaultPageSize, pageSizes }));
        return meta;
    }
}
```

## 八、禁止前端直接访问数据库

**严禁在前端代码中直接访问数据库**，包括但不限于：

- 禁止调用 `DB.Query<T>()`
- 禁止调用 `DB.Update<T>()`
- 禁止调用 `DB.Delete<T>()`
- 禁止调用 `Query<T>()`
- 禁止使用 `RF.Save()`、`RF.GetById()` 等 Repository 方法
- 禁止直接操作任何数据访问层(DAO)方法

**错误示例：**
```csharp
// 错误：前端直接访问数据库
public class XxxViewConfig : WebViewConfig<XxxEntity>
{
    protected override void ConfigView()
    {
        var data = DB.Query<XxxEntity>().Where(e => e.State == State.Enable).ToList(); // 严禁！
        var entity = RF.GetById<XxxEntity>(id); // 严禁！
    }
}
```

**正确示例：**
```csharp
// 正确：通过 Controller 访问数据
public class XxxViewConfig : WebViewConfig<XxxEntity>
{
    protected override void ConfigView()
    {
        var data = RT.Service.Resolve<XxxController>().GetXxxByState(State.Enable);
        var entity = RT.Service.Resolve<XxxController>().GetXxxById(id);
    }
}
```

**说明：**
- 前端（ViewConfig、Command、Behavior、DataQueryer）必须通过 `RT.Service.Resolve<XxxController>()` 调用后端控制器获取数据
- 数据访问逻辑必须封装在领域层（SIE.{Module}）的 Controller 中
- 这样确保数据访问的统一性、安全性和可维护性
