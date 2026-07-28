# sie-smom 参考底库缺陷修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 sie-smom Skill 参考底库中 AI 生成代码的 11 个 C# 后端缺陷 + 2 个 PDA 前端缺陷

**Architecture:** 在现有 sie-smom skill 的参考底库中修改 5 个精炼规则文件 + SKILL.md，新增 1 个 PDA 前端规范文件。所有修改均基于 spec 中确定的模板和示例，不新增无关内容。

**Tech Stack:** SIE SMOM 平台（.NET 6.0 MES + SIE 自研框架）、Vue 2.5.2 + Vux + axios

## Global Constraints

- 所有 C# 示例代码必须使用 Allman 风格（大括号独占一行）
- 所有 Vue 前端代码必须使用 Prettier 默认风格
- 禁止无意义换行：同一逻辑行的属性、参数、调用链放在同一行
- 所有示例必须语法正确，确保编译通过（C#）或 Babel 编译通过（Vue2）
- 所有结论标注来源文件（如 `见 references/03-entity-data.md`）
- 不修改 manual/ 目录下的权威手册原文

---

### Task 1: SKILL.md — 新增红线 11/12/13

**Files:**
- Modify: `skills/sie-smom/SKILL.md` — 第 3 节「强制规则」末尾

**Interfaces:**
- Consumes: spec 中红线 11/12/13 的文本内容
- Produces: 3 条新增红线，接在现有红线 10 之后

- [ ] **Step 1: 在红线 10 之后插入红线 11/12/13**

在 `SKILL.md` 第 3 节末尾，红线 10 的 `> 详见各 curated 文件中的【禁止 / 错误示例 / 正确示例】小节。` 之后，插入三条新红线：

```markdown
11. **using 指令完整性**：每个 `.cs` 文件必须在文件顶部包含所有必需的 `using` 指令（`SIE.*`、`System.*`、`RT.Service`、`RF`、`DB` 等）。禁止遗漏导致编译错误，代码生成后必须确认编译通过。
12. **FirstOrDefault 单参数重载**：`FirstOrDefault` 只有 1 个参数重载，如需加载视图属性使用 `FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty())`。禁止 `FirstOrDefault(null, ...)` 双参数形式。
13. **Criteria 类独立文件**：Criteria 查询实体必须定义在独立 `.cs` 文件中，继承 `Criteria`，标注 `[QueryEntity]` 和 `[Serializable]`。禁止写在 Controller 或 ViewConfig 类内部。
```

- [ ] **Step 2: 确认格式正确**

查看 SKILL.md 第 3 节，确认 3 条新红线编号连续、格式与前面 10 条一致（序号 + 粗体 + 描述）。

- [ ] **Step 3: 提交**

```bash
git add skills/sie-smom/SKILL.md
git commit -m "fix(skills): add red lines 11/12/13 for using/FirstOrDefault/Criteria"
```

---

### Task 2: SKILL.md — 扩展红线 4/5/9/10 + 新增第 8 节 PDA 前端

**Files:**
- Modify: `skills/sie-smom/SKILL.md` — 第 3 节红线 4/5/9/10，新增第 8 节

**Interfaces:**
- Consumes: spec 中红线扩展内容和 PDA 前端规范模板
- Produces: 4 条红线的扩展内容 + 完整第 8 节

- [ ] **Step 1: 扩展红线 4 — 补充枚举类型要求**

将红线 4 原文：
```
4. **每个查询必须带 `IS_PHANTOM = 0`**（除非明确查逻辑删除数据）；分页必须带 `ORDER BY`。
```
改为：
```
4. **每个查询必须带 `IS_PHANTOM = 0`**（除非明确查逻辑删除数据）；分页必须带 `ORDER BY`。**枚举类型属性必须用对应枚举类而非 `int`**：`Property<AccountState>` 而非 `Property<int>`。
```

- [ ] **Step 2: 扩展红线 5 — 补充 .csproj 同步要求**

将红线 5 原文：
```
5. **JS 文件必须设为嵌入资源**（`<EmbeddedResource Include="..."/>` + `<None Remove="..."/>`），否则运行时报 `No such Entity / No such class`。
```
改为：
```
5. **新增文件必须同步更新 `.csproj`**：所有新增文件（`.cs`、`.js`、`.aspx` 等）必须同步更新对应项目的 `.csproj`。JS 文件需同时配置 `<EmbeddedResource Include="..."/>` + `<None Remove="..."/>`，否则运行时报 `No such Entity / No such class`。
```

- [ ] **Step 3: 扩展红线 9 — 补充 Controller 继承 + 子表选择规则**

将红线 9 原文：
```
9. **Controller 继承 `DomainController`**；跨模块通用查询用 `CommonController`；控制器间互调用用 `RT.Service.Resolve<T>()`。
```
改为：
```
9. **Controller 继承 `DomainController`**；跨模块通用查询用 `CommonController`；控制器间互调用用 `RT.Service.Resolve<T>()`。**强关联子表用 `View.ChildrenProperty()`，弱关联/附加子表用 `View.AttachChildrenProperty()`**，禁止强关联子表使用 `AttachChildrenProperty`。
```

- [ ] **Step 4: 扩展红线 10 — 补充 FormEdit vs InlineEdit**

将红线 10 原文：
```
10. **自定义非重写视图方法**（如 `ConfigXxxView()`）中，属性必须显式 `.Readonly().Show(ShowInWhere.All)` 才会显示（框架只自动处理 `ConfigListView` / `ConfigDetailsView`）。
```
改为：
```
10. **自定义非重写视图方法**（如 `ConfigXxxView()`）中，属性必须显式 `.Readonly().Show(ShowInWhere.All)` 才会显示（框架只自动处理 `ConfigListView` / `ConfigDetailsView`）。**`View.FormEdit()` 用于弹窗编辑，`View.InlineEdit()` 用于行内编辑**，根据交互需求选择，禁止无脑全用 `View.FormEdit()`。
```

- [ ] **Step 5: 新增第 8 节「PDA 前端（Vue2）编码规范」**

在 SKILL.md 末尾，第 7 节「参考底库清单」之后，新增第 8 节：

```markdown
---

## 8. PDA 前端（Vue2）编码规范

> 适用项目：Vue 2.5.x + Vux + axios 的 PDA 项目。所有代码必须遵循 Prettier 默认风格。

### 8.1 禁止使用可选链 `?.`

Vue 2 项目默认 Babel 配置不支持 `?.` 可选链操作符，必须使用 `&&` 短路判断：

```javascript
// 错误（Vue2 编译失败）
const name = data?.Result?.Name;

// 正确
const name = data && data.Result && data.Result.Name;
```

### 8.2 API 接口实现模板

所有 API 接口文件放在 `src/assets/plugins/axios-api/api/<ControllerName>/` 目录下，严格按以下模板：

```javascript
import Vue from 'vue';
import Storage from '@/assets/js/storage.js'
export default function (code) {
    return Vue.axios.post(Storage.url(), {
        "ApiType": "TaskManagerPDAController",
        "Parameters": [
            {
                "Value": code
            }
        ],
        "Method": "GetRecommendLocation",
        "Context": {
            "Ticket": Storage.ticket(),
            "InvOrgId": Storage.orgid()
        }
    }).then(res => {
        const data = res.data;
        if (data.Success) {
            if (data.Context.Ticket) {
                Storage.refreshTicket(data.Context.Ticket);
            }
            return data.Result;
        } else {
            // 抛出一个特殊的错误对象，用于区分业务错误和网络错误
            const businessError = new Error(data.Message);
            businessError.isBusinessError = true;
            throw businessError;
        }
    }).catch(err => {
        // 区分业务逻辑错误和网络连接错误
        if (err.isBusinessError) {
            // 业务逻辑错误已经在上面处理过了，这里只需要重新抛出
            return Promise.reject(err);
        } else {
            // 真正的网络错误或HTTP状态码错误
            return Promise.reject(new Error("连接服务器失败"));
        }
    });
}
```

> **参数说明**：单参数时 `export default function (param)` 直接传值；多参数时使用对象 `export default function (data)` 传 `{ key1: val1, key2: val2 }`，`Parameters: [{ Value: data }]` 统一传整个对象。

### 8.3 调用处模板

```javascript
this.$vux.loading.show({ text: 'Loading' });
try {
    const res = await this.$axiosApi.scanStation(this.inputStationCode);
    this.$vux.loading.hide();
    if (res) {
        // 处理成功结果
    } else {
        // 处理空结果
    }
} catch (err) {
    this.$vux.loading.hide();
    this.$MConfirm.Alert(err.message, function () {
    })
}
```

> **注意**：`this.$axiosApi.<方法名>` 由框架自动注册，方法名取自 API 文件名的驼峰转换（如 `scan-station.js` → `this.$axiosApi.scanStation`）。
```

- [ ] **Step 6: 更新第 7 节「参考底库清单」**

在 `SKILL.md` 第 7 节的 references 清单末尾追加一行：

```
├── 12-pda-frontend.md          # PDA 前端（Vue2）编码规范
```

- [ ] **Step 7: 提交**

```bash
git add skills/sie-smom/SKILL.md
git commit -m "fix(skills): extend red lines 4/5/9/10, add PDA frontend section 8"
```

---

### Task 3: references/03-entity-data.md — 补充验证规则、FirstOrDefault、枚举类型

**Files:**
- Modify: `skills/sie-smom/references/03-entity-data.md`

**Interfaces:**
- Consumes: spec 中内联 NotDuplicateRule 示例、FirstOrDefault 示例、枚举类型示例
- Produces: 更新后的实体与数据层规范

- [ ] **Step 1: 在 5.3 节补充内联 NotDuplicateRule 写法**

在 5.3 节现有类定义方式示例之后，新增「内联写法」子节：

```markdown
### 5.3.1 内联 NotDuplicateRule 写法（推荐）

在 `AddValidations()` 中直接使用 `rules.AddRule` 内联注册：

```csharp
protected override void AddValidations(ValidationRules rules)
{
    rules.AddRule(new NotDuplicateRule()
    {
        Properties =
        {
            FloorAgvStationRelation.FloorProperty,
            FloorAgvStationRelation.RobotTypeProperty
        },
        MessageBuilder = (e) =>
        {
            return "（所在楼层+机器人类型）不允许重复".L10N();
        }
    });
}
```

> **注意**：`NotDuplicateRule` 的 `Properties` 是集合属性，用 `{ ... }` 初始化器添加字段；`MessageBuilder` 是委托，返回国际化字符串。禁止使用 `rules.AddNotDuplicateRule<...>()` 等臆造方法。
```

- [ ] **Step 2: 补充 FirstOrDefault 正确用法**

在第三节「Criteria 查询实体」的 `Fetch()` 示例附近，或新增独立小节，补充：

```markdown
### 3.1 FirstOrDefault 正确用法

`FirstOrDefault` 方法只有 **1 个参数重载**，如需加载视图属性：

```csharp
// 正确：单参数，传入 EagerLoadOptions
var entity = Query<Item>()
    .Where(e => e.Code == code)
    .FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty());

// 错误：框架没有双参数重载
var entity = Query<Item>()
    .Where(e => e.Code == code)
    .FirstOrDefault(null, new EagerLoadOptions().LoadWithViewProperty()); // 编译错误！
```

同理，`ToList` 也支持 `EagerLoadOptions`：

```csharp
query.ToList(criteria.PagingInfo, new EagerLoadOptions().LoadWithViewProperty());
```
```

- [ ] **Step 3: 补充枚举类型成员使用对应实体类规范**

在第二节「枚举定义」末尾补充：

```markdown
### 2.1 枚举属性必须用枚举类作为类型

实体中枚举类型的属性，必须使用对应的枚举类作为 `Property<T>` 的类型参数：

```csharp
// 正确：使用枚举类
public static readonly Property<AccountState> AccountStateProperty = P<Entity>.Register(e => e.AccountState);

// 错误：使用 int
public static readonly Property<int> AccountStateProperty = P<Entity>.Register(e => e.AccountState); // 禁止！
```
```

- [ ] **Step 4: 确认示例代码风格正确**

检查所有新增示例代码：
- C# Allman 风格（大括号独占一行）
- 无多余换行
- using 指令完整

- [ ] **Step 5: 提交**

```bash
git add skills/sie-smom/references/03-entity-data.md
git commit -m "fix(skills): add inline NotDuplicateRule, FirstOrDefault, enum type rules in 03-entity-data"
```

---

### Task 4: references/04-web-viewconfig.md — 补充 FormEdit/InlineEdit、ChildrenProperty 规范

**Files:**
- Modify: `skills/sie-smom/references/04-web-viewconfig.md`

**Interfaces:**
- Consumes: spec 中 FormEdit/InlineEdit 选择规则、ChildrenProperty 强关联子表示例
- Produces: 更新后的 ViewConfig 规范

- [ ] **Step 1: 在第二节「常用 ViewConfig 方法」表格中补充说明**

在 `View.FormEdit()` 和 `View.InlineEdit()` 行的「用途」列补充选择指导：

| 方法 | 用途 |
|------|------|
| `View.FormEdit()` | 弹窗表单编辑模式，用于需要点击编辑按钮打开弹窗的场景 |
| `View.InlineEdit()` | 行内编辑模式，用于表格内直接编辑的场景 |

- [ ] **Step 2: 新增「六、ChildrenProperty 强关联子表规范」**

在现有第五节之后，新增第六节：

```markdown
## 六、ChildrenProperty 强关联子表规范

### 6.1 ChildrenProperty 与 AttachChildrenProperty 的选择依据

| 方法 | 适用场景 | 说明 |
|------|---------|------|
| `View.ChildrenProperty(p => p.ChildList)` | 强关联子表 | 子表是当前实体的直接子实体，通过 `RegisterList` + `GetLazyList` 定义 |
| `View.AttachChildrenProperty(typeof(OtherEntity), ...)` | 弱关联/附加子表 | 关联外部实体，非直接子实体，适合松耦合的附加信息展示 |

**禁止强关联子表使用 `AttachChildrenProperty`。**

### 6.2 强关联子表完整示例

**实体定义**（主实体中）：

```csharp
#region 可停泊站点 FloorAgvStationDetailList
/// <summary>
/// 可停泊站点
/// </summary>
[Label("可停泊站点")]
public static readonly ListProperty<EntityList<FloorAgvStationDetail>> FloorAgvStationDetailListProperty = P<FloorAgvStationRelation>.RegisterList(e => e.FloorAgvStationDetailList);

/// <summary>
/// 可停泊站点
/// </summary>
public EntityList<FloorAgvStationDetail> FloorAgvStationDetailList
{
    get { return this.GetLazyList(FloorAgvStationDetailListProperty); }
}
#endregion
```

**视图配置**：

```csharp
// 强关联子表：直接使用 ChildrenProperty
View.ChildrenProperty(p => p.FloorAgvStationDetailList);

// 弱关联/附加子表：使用 AttachChildrenProperty
View.AttachChildrenProperty(typeof(AgvMaintenanceAbnormal), o =>
{
    var args = o as ChildPagingDataArgs;
    return null;
}).HasLabel("AGV异常情况");
```

> **注意**：`ChildrenProperty` 不需要 lambda 参数，直接传入实体属性表达式即可；`AttachChildrenProperty` 需要 lambda 接收 `ChildPagingDataArgs` 并返回数据源。
```

- [ ] **Step 3: 更新索引编号**

检查 ViewConfig 文件现有章节编号，将原第六节「ViewConfig 其他常用方法」改为第七节，原第七节「属性设置」改为第八节，原第八节「JS 常用 API」改为第九节，原第九节「默认值设置」改为第十节。

- [ ] **Step 4: 提交**

```bash
git add skills/sie-smom/references/04-web-viewconfig.md
git commit -m "fix(skills): add FormEdit/InlineEdit rules and ChildrenProperty spec in 04-web-viewconfig"
```

---

### Task 5: references/05-controller.md — 新增 Criteria 类独立文件规范

**Files:**
- Modify: `skills/sie-smom/references/05-controller.md`

**Interfaces:**
- Consumes: spec 中 Criteria 独立文件规范示例
- Produces: 更新后的 Controller 规范

- [ ] **Step 1: 在 Controller 规范末尾新增 Criteria 独立文件规范**

在现有第 6 节「命令基类与可重写方法」之后，新增第 7 节：

```markdown
## 7. Criteria 类必须定义在独立文件中

Criteria 查询实体必须定义在独立的 `.cs` 文件中，禁止写在 Controller 或 ViewConfig 类内部。

```csharp
// 正确：独立文件
// File: ApiLogCriteria.cs
[QueryEntity, Serializable]
[Label("API日志查询实体")]
public class ApiLogCriteria : Criteria
{
    #region 接口名 ApiName
    [Label("接口名")]
    public static readonly Property<string> ApiNameProperty = P<ApiLogCriteria>.Register(e => e.ApiName);
    public string ApiName
    {
        get { return this.GetProperty(ApiNameProperty); }
        set { this.SetProperty(ApiNameProperty, value); }
    }
    #endregion

    protected override EntityList Fetch()
    {
        return RT.Service.Resolve<ApiLogController>().GetApiLogs(this);
    }
}

// 错误：写在 Controller 类内部
public class ApiLogController : DomainController
{
    // 禁止：Criteria 不能定义在 Controller 内部
    public class ApiLogCriteria : Criteria { }
}
```

> **原因**：Criteria 是独立的查询实体，放在 Controller 内部会导致耦合、难以复用，且框架的某些机制（如 `[QueryEntity]` 扫描）可能无法正确识别嵌套类。
```

- [ ] **Step 2: 提交**

```bash
git add skills/sie-smom/references/05-controller.md
git commit -m "fix(skills): add Criteria independent file rule in 05-controller"
```

---

### Task 6: references/07-general.md — 强化注释、FirstOrDefault、csproj 规范

**Files:**
- Modify: `skills/sie-smom/references/07-general.md`

**Interfaces:**
- Consumes: spec 中 XML 注释强化要求、FirstOrDefault 示例、csproj 规范
- Produces: 更新后的通用规范

- [ ] **Step 1: 强化 XML 注释要求**

在第三节「XML 文档注释规范」中，将首句改为更强硬的表述，并补充行内注释要求：

```markdown
## 三、XML 文档注释规范（强制）

**所有公开的类、方法、属性、字段必须使用 XML 文档注释，禁止遗漏。** 行内重要逻辑也必须添加注释说明意图。

```csharp
/// <summary>
/// 物料基类控制器
/// </summary>
public class ItemController : DomainController
{
    /// <summary>
    /// 查询物料
    /// </summary>
    /// <param name="criteria">物料查询实体</param>
    /// <returns>物料列表</returns>
    public virtual EntityList<Item> GetItems(ItemCriteria criteria)
    {
        // 校验查询条件
        if (criteria == null)
            throw new ArgumentNullException(nameof(criteria));
        // ...业务逻辑
    }
}
```

> **注意**：缺少 XML 注释的代码将被视为不合格。行内注释帮助接手者快速理解代码意图，但不应注释显而易见的内容（如 `i++` // 加一）。
```

- [ ] **Step 2: 补充 FirstOrDefault 正确用法**

在第四节「关键框架约定速查」表格中，找到 `RF.GetById<T>(id, eagerLoad)` 行，下方新增一行：

```
| `FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty())` | 查询单条并加载视图属性（仅1参数重载） |
```

同时在该节新增说明：

```markdown
> **FirstOrDefault 注意**：框架的 `FirstOrDefault` 只有 **1 个参数重载**，传入 `EagerLoadOptions` 即可。禁止使用 `FirstOrDefault(null, options)` 双参数形式。
```

- [ ] **Step 3: 补充 .csproj 同步更新要求**

在第五节「常见坑」中，新增一条：

```markdown
- **新增文件未更新 .csproj**：所有新增文件（`.cs`、`.js`、`.aspx` 等）必须同步更新对应项目的 `.csproj` 文件。JS 文件需同时配置 `<None Remove>` 和 `<EmbeddedResource Include>`，否则运行时报 `No such Entity / No such class`。这是最常见的遗漏问题，代码生成后必须确认 VS 能索引到新增文件。
```

- [ ] **Step 4: 提交**

```bash
git add skills/sie-smom/references/07-general.md
git commit -m "fix(skills): strengthen XML comments, add FirstOrDefault and csproj rules in 07-general"
```

---

### Task 7: 新增 references/12-pda-frontend.md — PDA 前端编码规范

**Files:**
- Create: `skills/sie-smom/references/12-pda-frontend.md`

**Interfaces:**
- Consumes: spec 中 PDA 前端规范内容、实际 PDA 项目代码模式
- Produces: 完整的 PDA 前端（Vue2 + Vux）编码规范文件

- [ ] **Step 1: 创建 12-pda-frontend.md**

```markdown
> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **优先级**：高。
> **覆盖范围**：Vue2 语法限制·API 接口模板·调用处模板·Storage 工具·Prettier 风格

# PDA 前端（Vue2）编码规范

> **适用范围**:本规范适用于所有基于 Vue 2.5.x + Vux + axios 的 PDA 项目,始终生效。
> **内容概要**:Vue2 语法限制（禁止可选链）、API 接口实现模板、调用处模板、Prettier 代码风格。

## 一、Vue2 语法限制

### 1.1 禁止使用可选链 `?.`

Vue 2 项目的默认 Babel 配置（babel-preset-stage-2）不支持 `?.` 可选链操作符，编译时会报错。

```javascript
// 错误：Vue2 编译失败
const name = data?.Result?.Name;
const list = data?.Items ?? [];

// 正确：使用 && 短路判断
const name = data && data.Result && data.Result.Name;
const list = data && data.Items || [];
```

### 1.2 其他 Vue2 注意事项

- 不支持 `??` 空值合并运算符，用 `||` 替代
- 不支持 `Array.prototype.flat()`，用 `lodash` 的 `_.flatten` 替代
- 不支持 `String.prototype.trimEnd()` / `trimStart()`

## 二、API 接口实现模板

### 2.1 文件结构

所有 API 接口文件放在 `src/assets/plugins/axios-api/api/<ControllerName>/` 目录下，框架自动注册到 `this.$axiosApi`。

### 2.2 单参数接口模板

```javascript
import Vue from 'vue';
import Storage from '@/assets/js/storage.js'
export default function (code) {
    return Vue.axios.post(Storage.url(), {
        "ApiType": "TaskManagerPDAController",
        "Parameters": [
            {
                "Value": code
            }
        ],
        "Method": "GetRecommendLocation",
        "Context": {
            "Ticket": Storage.ticket(),
            "InvOrgId": Storage.orgid()
        }
    }).then(res => {
        const data = res.data;
        if (data.Success) {
            if (data.Context.Ticket) {
                Storage.refreshTicket(data.Context.Ticket);
            }
            return data.Result;
        } else {
            // 抛出一个特殊的错误对象，用于区分业务错误和网络错误
            const businessError = new Error(data.Message);
            businessError.isBusinessError = true;
            throw businessError;
        }
    }).catch(err => {
        // 区分业务逻辑错误和网络连接错误
        if (err.isBusinessError) {
            // 业务逻辑错误已经在上面处理过了，这里只需要重新抛出
            return Promise.reject(err);
        } else {
            // 真正的网络错误或HTTP状态码错误
            return Promise.reject(new Error("连接服务器失败"));
        }
    });
}
```

### 2.3 多参数接口模板

当接口需要多个参数时，统一使用对象传参：

```javascript
import Vue from 'vue';
import Storage from '@/assets/js/storage.js'
export default function (data) {
    return Vue.axios.post(Storage.url(), {
        "ApiType": "CallAgvNewController",
        "Parameters": [
            {
                "Value": data
            }
        ],
        "Method": "SubmitCallAgv",
        "Context": {
            "Ticket": Storage.ticket(),
            "InvOrgId": Storage.orgid()
        }
    }).then(res => {
        const data = res.data;
        if (data.Success) {
            if (data.Context.Ticket) {
                Storage.refreshTicket(data.Context.Ticket);
            }
            return data.Result;
        } else {
            const businessError = new Error(data.Message);
            businessError.isBusinessError = true;
            throw businessError;
        }
    }).catch(err => {
        if (err.isBusinessError) {
            return Promise.reject(err);
        } else {
            return Promise.reject(new Error("连接服务器失败"));
        }
    });
}
```

### 2.4 模板参数说明

| 字段 | 说明 | 值来源 |
|------|------|--------|
| `ApiType` | 后端 Controller 类名（不含命名空间） | 根据实际 Controller 填写 |
| `Method` | 后端方法名 | 根据实际方法填写 |
| `Parameters[0].Value` | 参数值 | 单参数直接传值，多参数传对象 |
| `Context.Ticket` | 登录票据 | `Storage.ticket()` |
| `Context.InvOrgId` | 库存组织 ID | `Storage.orgid()` |

## 三、调用处模板

### 3.1 标准调用模式

```javascript
this.$vux.loading.show({ text: 'Loading' });
try {
    const res = await this.$axiosApi.scanStation(this.inputStationCode);
    this.$vux.loading.hide();
    if (res) {
        // 处理成功结果
    } else {
        // 处理空结果
    }
} catch (err) {
    this.$vux.loading.hide();
    this.$MConfirm.Alert(err.message, function () {
    })
}
```

### 3.2 调用模板说明

- **loading 显示**：请求前调用 `this.$vux.loading.show({ text: 'Loading' })` 显示加载中
- **loading 隐藏**：无论成功或失败，在 `try` 和 `catch` 中都要 `this.$vux.loading.hide()`
- **成功处理**：`res` 为后端返回的 `Result` 数据，判断 `if (res)` 再处理
- **错误处理**：使用 `this.$MConfirm.Alert(err.message, callback)` 弹出错误提示
- **方法名**：`this.$axiosApi.<方法名>` 由框架自动注册，方法名取自 API 文件名的驼峰转换（如 `scan-station.js` → `scanStation`）

## 四、代码风格

所有 Vue 前端代码必须遵循 **Prettier 默认风格**：

- 缩进使用 2 空格
- 字符串使用单引号
- 对象字面量尾逗号保留
- 行宽 80 字符
- 禁止手动换行破坏 Prettier 格式
- 禁止每写一个属性就换行

```javascript
// 正确：Prettier 风格
const res = await this.$axiosApi.scanStation(this.inputStationCode);

// 错误：过度换行
const res = await this
    .$axiosApi
    .scanStation(this
        .inputStationCode);
```

## 五、Storage 工具方法

```javascript
import Storage from '@/assets/js/storage.js'

Storage.url()           // 获取 API 请求地址
Storage.ticket()        // 获取登录票据
Storage.refreshTicket() // 刷新票据
Storage.orgid()         // 获取库存组织 ID
Storage.userid()        // 获取用户 ID
Storage.warehouseid()   // 获取仓库 ID
```

## 六、MConfirm 弹窗方法

```javascript
import MConfirm from '@/assets/js/MConfirm.js'

this.$MConfirm.Toast(text, callback)     // 提示框（自动消失）
this.$MConfirm.Alert(text, callback)     // 警告框（需点击确认）
this.$MConfirm.Asktion(text, callback)   // 询问框（确认/取消）
```

> **注意**：所有 API 接口文件和调用代码必须遵循本文档的模板，禁止自行发明请求格式或错误处理方式。
```

- [ ] **Step 2: 验证文件格式**

确认 12-pda-frontend.md 的 Markdown 格式正确，代码块有语言标注，表格展示正常。

- [ ] **Step 3: 提交**

```bash
git add skills/sie-smom/references/12-pda-frontend.md
git commit -m "feat(skills): add PDA frontend (Vue2) coding standards reference"
```

---

### 验证清单

实施完成后，逐项确认：

- [ ] 红线 11（using 完整性）已添加
- [ ] 红线 12（FirstOrDefault 单参数）已添加
- [ ] 红线 13（Criteria 独立文件）已添加
- [ ] 红线 4 已扩展枚举类型要求
- [ ] 红线 5 已扩展 .csproj 同步要求
- [ ] 红线 9 已扩展子表选择规则
- [ ] 红线 10 已扩展 FormEdit/InlineEdit 规则
- [ ] 第 8 节 PDA 前端规范已添加
- [ ] 03-entity-data.md 已补充内联 NotDuplicateRule
- [ ] 03-entity-data.md 已补充 FirstOrDefault 正确用法
- [ ] 03-entity-data.md 已补充枚举类型规范
- [ ] 04-web-viewconfig.md 已补充 FormEdit/InlineEdit 选择规则
- [ ] 04-web-viewconfig.md 已补充 ChildrenProperty 强关联子表规范
- [ ] 05-controller.md 已补充 Criteria 独立文件规范
- [ ] 07-general.md 已强化 XML 注释要求
- [ ] 07-general.md 已补充 FirstOrDefault 和 csproj 规范
- [ ] 12-pda-frontend.md 已创建（含接口模板、调用模板、Vue2 限制）
- [ ] 所有示例代码语法正确、风格一致（C# Allman、Vue Prettier）
- [ ] 所有 11 个 C# 问题点 + 2 个 PDA 问题点均已覆盖