# 修复 sie-smom Skill 参考底库缺陷

## 背景

sie-smom 是赛意 SMOM 平台（.NET 6.0 MES + SIE 自研框架）的 Claude Code 开发辅助 Skill。在实际项目开发中，AI 生成的代码暴露出多个质量问题，包括 C# 后端语法错误、模式错误、注释缺失、PDA 前端 Vue2 兼容性问题等。本设计文档旨在系统性地修复参考底库，确保 AI 后续生成的代码符合项目实际要求。

## 代码风格总则（强制，贯穿所有修改）

所有代码生成必须遵守以下风格规范，违者视为缺陷：

1. **C# 代码**：Allman 风格（大括号独占一行）。禁止将不相关的逻辑挤在同一行，也禁止每写一个 token 就换行。合理利用垂直空间，相关逻辑放在同一逻辑块内。
2. **Vue 前端代码**：Prettier 默认风格。禁止手动换行破坏 Prettier 格式，禁止每写一个属性就换行。
3. **代码紧凑性**：不要写一个东西就换一行。同一逻辑行的属性、参数、调用链应放在同一行或合理分组，避免产生大量无意义的短行。

## 问题清单

### C# 后端

| # | 问题 | 严重程度 | 所属文件 |
|---|------|---------|---------|
| 1 | 缺少 `using` 头文件导致编译不通过 | 阻断 | SKILL.md |
| 2 | 实体验证规则（NotDuplicateRule）写法错误 | 阻断 | 03-entity-data.md |
| 3 | `FirstOrDefault` 用了 2 参数重载而框架只有 1 参数 | 阻断 | 03-entity-data.md, 07-general.md |
| 4 | 代码缺少 XML 注释和行内重要注释 | 质量 | 07-general.md |
| 5 | 新增文件未同步添加到 `.csproj` | 阻断 | SKILL.md, 06-web-frontend.md |
| 6 | 枚举类型成员用 `int` 而非实体类 | 正确性 | 03-entity-data.md, SKILL.md |
| 7 | Criteria 类写在 Controller 内部 | 架构 | 05-controller.md |
| 8 | 全用 `View.FormEdit()` 而非 `View.InlineEdit()` | 正确性 | 04-web-viewconfig.md |
| 9 | 关联子表全用 `AttachChildrenProperty` 而非 `ChildrenProperty` | 正确性 | 04-web-viewconfig.md |

### PDA 前端（Vue2）

| # | 问题 | 严重程度 | 所属文件 |
|---|------|---------|---------|
| 1 | 使用了 Vue2 不支持的 `?.` 可选链操作符 | 阻断 | 需新增 |
| 2 | 接口实现和调用处不符合项目模板 | 阻断 | 需新增 |

## 修改方案

### 一、SKILL.md

#### 第 3 节「强制规则」新增红线

**红线 11 — using 指令完整性**：每个 `.cs` 文件必须在文件顶部包含所有必需的 `using` 指令，包括 `SIE.*` 命名空间、`System.*`、`RT.Service`、`RF`、`DB` 等。禁止遗漏导致编译错误。代码生成后必须确认编译通过。

**红线 12 — FirstOrDefault 单参数重载**：`FirstOrDefault` 方法只有 1 个参数重载，如需加载视图属性使用 `FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty())`。禁止使用 `FirstOrDefault(null, ...)` 双参数形式。

**红线 13 — Criteria 类独立文件**：Criteria 查询实体必须定义在独立的 `.cs` 文件中，继承 `Criteria` 基类，标注 `[QueryEntity]` 和 `[Serializable]`。禁止写在 Controller 或 ViewConfig 等类内部。

#### 红线 4 扩展：补充枚举类型要求

枚举类型的实体属性必须使用对应的枚举类作为属性类型，禁止使用 `int`。例如：
```csharp
// 正确
public static readonly Property<AccountState> AccountStateProperty = P<Entity>.Register(e => e.AccountState);
public AccountState AccountState { get; set; }

// 错误
public static readonly Property<int> AccountStateProperty = P<Entity>.Register(e => e.AccountState);
```

#### 红线 5 扩展：补充 .csproj 同步要求

所有新增文件（`.cs`、`.js`、`.aspx` 等）必须同步更新对应项目的 `.csproj` 文件。JS 文件需同时配置 `<None Remove>` 和 `<EmbeddedResource Include>`。代码生成后必须确认 VS 能索引到新增文件。

#### 红线 10 扩展：补充 FormEdit vs InlineEdit 选择规则

- `View.FormEdit()`：弹窗表单编辑模式，用于需要点击编辑按钮打开弹窗的场景
- `View.InlineEdit()`：行内直接编辑模式，用于表格内直接编辑的场景
- 根据实际交互需求选择，禁止无脑全用 `View.FormEdit()`

#### 红线 9 扩展：补充 ChildrenProperty vs AttachChildrenProperty 选择规则

- `View.ChildrenProperty(p => p.ChildList)`：强关联子表（子表是当前实体的直接子实体，通过 `RegisterList` + `GetLazyList` 定义）。适合主从强关联关系。
- `View.AttachChildrenProperty(typeof(OtherEntity), ...)`：弱关联/附加子表（关联外部实体，非直接子实体）。适合松耦合的附加信息展示。
- 禁止强关联子表也使用 `AttachChildrenProperty`。

#### 新增第 8 节「PDA 前端（Vue2）编码规范」

涵盖：
- Vue2 不支持 `?.` 可选链操作符，必须使用 `&&` 短路判断
- API 接口模板（严格按项目实际模板）
- 调用处模板（`this.$vux.loading` + `try/catch` + `this.$MConfirm.Alert`）
- Prettier 默认风格

### 二、references/03-entity-data.md 修改

#### 5.3 节补充内联 NotDuplicateRule 写法

当前只有类定义方式，补充内联方式：

```csharp
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
```

#### 补充 FirstOrDefault 正确用法

```csharp
// 正确：单参数重载，加载视图属性
.FirstOrDefault(new EagerLoadOptions().LoadWithViewProperty());

// 错误：框架没有双参数重载
.FirstOrDefault(null, new EagerLoadOptions().LoadWithViewProperty()); // 编译错误！
```

#### 补充枚举类型成员使用对应实体类

```csharp
// 正确
public static readonly Property<AccountState> AccountStateProperty = ...

// 错误
public static readonly Property<int> AccountStateProperty = ...
```

### 三、references/04-web-viewconfig.md 修改

#### 补充 FormEdit vs InlineEdit 选择规则

在第二节「常用 ViewConfig 方法」中补充说明：
- `View.FormEdit()` → 弹窗编辑模式，用于需要点击编辑按钮弹出表单的场景
- `View.InlineEdit()` → 行内编辑模式，用于表格内直接编辑的场景

#### 补充 ChildrenProperty 强关联子表规范

新增章节，包含：
- 实体定义（`RegisterList` + `GetLazyList`）
- 视图配置（`View.ChildrenProperty(p => p.ChildList)`）
- 对比 AttachChildrenProperty 的选择依据

```csharp
// 实体定义
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

// 视图配置
View.ChildrenProperty(p => p.FloorAgvStationDetailList);
```

### 四、references/05-controller.md 修改

#### 新增 Criteria 类独立文件规范

```csharp
// 正确：独立文件
// File: ApiLogCriteria.cs
[QueryEntity, Serializable]
[Label("API日志查询实体")]
public class ApiLogCriteria : Criteria
{
    // ...
}

// 错误：写在 Controller 类内部
public class ApiLogController : DomainController
{
    public class ApiLogCriteria : Criteria { } // 禁止！
}
```

### 五、references/07-general.md 修改

#### 强化 XML 注释要求

在第三节「XML 文档注释规范」中强调「所有公开的类、方法、属性、字段必须使用 XML 文档注释」，并增加行内重要注释的要求。

#### 补充 FirstOrDefault 正确用法

#### 补充 .csproj 同步更新要求

### 六、新增 references/12-pda-frontend.md

#### Vue2 编码规范

1. **禁止使用 `?.` 可选链**：Vue2 项目默认不支持，需改用 `&&` 短路判断
2. **API 接口模板**：严格按项目模板
3. **调用处模板**：`this.$vux.loading` + `try/catch` + `this.$MConfirm.Alert`
4. **Prettier 默认风格**

## 不修改的文件

- `references/01-architecture.md`：架构部分无问题
- `references/02-wpf.md`：WPF 部分无问题
- `references/08-mssql-query.md`：MSSQL 查询无问题
- `references/09-mssql-table.md`：MSSQL 建表无问题
- `references/10-oracle-query.md`：Oracle 查询无问题
- `references/11-oracle-table.md`：Oracle 建表无问题
- `references/manual/` 目录：权威手册原文，不修改

## 验证方式

1. 修改后 Review 每个文件的变更内容
2. 确认所有 11 个 C# 问题点 + 2 个 PDA 问题点均被覆盖
3. 确认示例代码语法正确、风格一致（C# Allman、Vue Prettier）