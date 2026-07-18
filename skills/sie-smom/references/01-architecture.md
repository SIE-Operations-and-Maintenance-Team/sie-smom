> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：01-____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：项目分层(Module/Web/Wpf/xUnit/Job/Statistics)·Module注册·DataProvider·IoC(RT.Service·RF·DB)

---

# 赛意SMOM项目架构总览

> **适用范围**:本规范适用于项目中所有 `*.cs` 文件,始终生效。
> **内容概要**:项目分层(Module/Web/Wpf/xUnit/Job/Statistics)、Module 注册、DataProvider 定义、IoC 服务注册(RT.Service / RF / DB)。

本项目基于 .NET 6.0 的工业制造执行系统(MES)，使用 SIE 自研框架。

---

## 一、项目分层架构

| 项目后缀 | 用途 | 示例 |
|----------|------|------|
| SIE.{Module} | 领域逻辑层(实体/Controller/Service/Dao) | SIE.MES |
| SIE.Web.{Module} | ASP.NET Core Web端(ViewConfig/Command/DataQueryer/Behavior/Script) | SIE.Web.MES |
| SIE.Wpf.{Module} | WPF桌面端(ViewConfig/Command/Behavior/Editor/Layout) | SIE.Wpf.MES |
| SIE.xUnit.{Module} | xUnit单元测试 | SIE.xUnit.Core |
| SIE.{Module}.Job | Hangfire后台定时任务 | SIE.MES.Job |
| SIE.{Module}.Statistics | 统计汇总逻辑 | SIE.MES.Statistics |

**规则:**
- 控制器(Controller)禁止放在 SIE.Web.* 项目中，必须放在 SIE.{Module} 领域层
- SIE.Web.* 项目只放 ViewConfig、Command、DataQueryer、Behavior、Scripts
- SIE.Wpf.* 项目只放 ViewConfig、Command、Behavior、Editor、Layout、Converter

---

## 二、DataProvider 与模块注册

### 2.1 DataProvider 定义
```csharp
[assembly: Repository(typeof(CoreEntityRepository<>))]
namespace SIE.Core
{
    [DataProvider(typeof(CoreEntityDataProvider))]
    public class CoreEntityRepository<T> : EntityRepository<T> where T : Entity { }

    public class CoreEntityDataProvider : RdbDataProvider
    {
        public const string ConnectionStringName = "master";
        protected override string ConnectionStringSettingName => ConnectionStringName;
    }
}
```

### 2.2 模块注册
每个项目必须有 Module.cs，使用 `[assembly: Module(typeof(Module))]` 注册:

**领域层模块:**
```csharp
[assembly: Module(typeof(Module))]
namespace SIE.Core
{
    class Module : DomainModule
    {
        public override void Initialize(IApp app)
        {
            RT.Service.Register(typeof(ISysConfigService), typeof(SysConfigService), Services.ServiceLifeStyle.Singleton);
        }
    }
}
```

**Web层模块:**
```csharp
[assembly: Module(typeof(Module))]
namespace SIE.Web.Core
{
    public class Module : UIModule
    {
        public override void Initialize(IApp app)
        {
            if (app != null)
                app.ModuleOperations += App_ModuleOperations;
        }

        private void App_ModuleOperations(object sender, EventArgs e)
        {
            CommonModel.Modules.AddModules(
                new WebModuleMeta()
                {
                    Label = "用户协议管理".L10N(),
                    EntityType = typeof(UserAgreement),
                    BlocksTemplate = typeof(UserAgreementTemplate),
                }
            );
        }
    }
}
```

**Job模块:**
```csharp
[assembly: Module(typeof(Module))]
namespace SIE.AbnormalInfo.Job
{
    public class Module : DomainModule
    {
        public override void Initialize(IApp app) { }
    }
}
```

---

## 三、IoC 与服务注册

```csharp
// 服务注册(在 Module.Initialize 中)
RT.Service.Register(typeof(ISysConfigService), typeof(SysConfigService), Services.ServiceLifeStyle.Singleton);

// 服务调用
RT.Service.Resolve<CustomerController>().GetCustomer(keyword, pagingInfo);

// Repository 工厂调用
RF.Save(entity);                    // 保存
RF.GetById<T>(id);                   // 按ID获取
RF.GetAll<T>();                      // 获取全部
RF.BatchInsert(entityList);          // 批量插入

// 数据库查询
DB.Query<T>();                       // 查询
DB.Update<T>();                      // 更新
DB.Delete<T>();                       // 删除
DB.TransactionScope(connectionString) // 事务
```

**事务使用规则**（manual/11-ajax-deploy-db.md 41.4）：

- `CommonEntityDataProvider.ConnectionStringName` 为对应工程的数据库提供者。
- `tran.Complete()` 是事务完成标记。
- 事务内只放保存数据的业务逻辑，查询和验证移到事务外。
- **单表数据保存不要用事务**。
- **事务只能在服务端执行**（前端禁止，见红线1）。

---

## 四、SMOM 类命名规范速查

> 见 manual/01-dev-standards.md 1.2.5。命名空间统一为"对应工程名.文件夹名"；所有名称用英文不用拼音；Pascal 命名。

| 类 | 命名 | 关键规则 |
|---|---|---|
| 数据提供者 | `XXXDataProvider` | 工程间唯一；建议"工程名+DataProvider"；命名空间=工程名 |
| 模块初始化 | `XXXModule` | 命名空间=工程名 |
| 实体类 | 业务名（≤2 单词，≤30 字符） | 服务端工程；文件夹"实体名+s"；partial；`[RootEntity/ChildEntity, Serializable]`；父实体不含子列表属性；只含属性不写业务逻辑；配置类"类名+Config" |
| 查询实体 | `实体名+Criteria` | 服务端工程 |
| ViewModel | `XXXViewModel` | |
| 控制器 | `XXXController` | 服务端工程；非私有方法必须 `virtual`；一实体一控制器 |
| 规则类 | `XXXRule` | 服务端工程 |
| 附件类 | `XXXAttachment` | `[ChildEntity, Serializable]`；`Meta.EnableDiscriminator("XXX")` 启用鉴别器；仓库类"附件类+Repository" |
| 标签打印 | `XXXLabelPrintable` | `[DisplayName("打印名称")]` |
| 单据打印 | `XXXPrintable` | `[DisplayName("打印名称")]` |
| 配置项 | `XXXConfigValue` | `[EntityWithConfig(typeof(NoConfig))]`；规则生成说明类"XXXConfig" |
| 界面配置 | `XXXViewConfig` | 客户端工程；ConfigView 中**不要配置命令**（会污染所有视图）；先配置编辑模式再配置命令；分组名用常量不用字符串 |
| 命令类 | `XXXCommand` | 放 `Commands` 文件夹；JS 嵌入资源；重写命令**必须加 meta 且不能换行**；前后端有交互时 JS/CS 全命名空间完全一致 |
| 调度任务 | `XXXJob` | `[Job]` 标签；`ExecuteJob` 中**必须用 `AddLog` 记录日志**；参数类 `XXXJobParameter` |
| 预警 | `XXXAlert` / `XXXAlertConfig` / `XXXAlertResult` | |
| 推送 | `XXXSender` / `XXXSenderConfig` | |

---

## 五、属性与建表命名陷阱（高价值坑，多为静默失败）

> 见 manual/01-dev-standards.md 1.2.4 / 1.2.5.9。违反常无异常提示，务必遵守。

- **相邻两字母不能同时大写**：`WOType` 生成字段 `W_O_TYPE`，应写 `WoType` 生成 `WO_TYPE`。
- **属性名不能与框架属性冲突**：禁用 `Id / CreateBy / UpdateBy / CreateDate / UpdateDate / InvOrgId / IsPhantom / SyncId`，冲突会**静默映射失败且无异常提示**。
- **首字母不能小写**：小写映射不了数据库字段。
- **String 默认长度**：映射 DB 字段长度 80、验证输入长度 20，需更长要额外设置。
- **属性 `[Label]` 必须标记**。
- **新增属性用代码段，不要复制**：从其他实体复制属性时，关联实体必须改，否则抛异常。
- **通用词不加修饰**：`Code / Name / Description / Type` 不加修饰词；状态统一用 `State` 不用 `Status`。
- **BS 基类不能含列表属性**：否则生成界面解析异常。
- **数据库表名**：`模块_表释义名`；主表代表整个模块时全大写（`WO` / `WO_BOM` / `WO_PROC_BILL`）；Oracle 标识符 ≤30、表名尽量 ≤15 字符（序列+同步序列占用），过长用缩写（`DefectResponsibilityCategory` → `DEF_RESP_CATE`）；不含 `.` 和关键字。

---

## 六、环境搭建速查（SMOM8.2，manual/01-dev-standards.md 第2、4节）

- **首次拿到项目**：先确保编译通过、能运行登录、加载界面，再做功能。
- **版本要求**：VS2019.16.4+；安装 net core sdk 3.1 与 2.2（8.2+ 用 3.1，旧版用 2.2）。
- **工程类型**：服务端 `.NET Standard 2.0`；Web 端 `.NET Core 3.1`；WPF 端 `.NET Framework 4.7.2`。
- **引用 dll**：服务端 `SIE.dll` + `SIE.Common.dll`；客户端 `SIE.dll` + `SIE.Web.dll` + `SIE.Common.dll` + `SIE.Web.Common.dll`；有依赖关系时只加最后一层 dll。
- **AssemblyInfo 冲突**：编辑 .csproj，在 PropertyGroup 下加 `<GenerateAssemblyInfo>false</GenerateAssemblyInfo>`。
- **nuget 迁移**：服务端 / Web 端无 `packages.config` / `app.config`，迁移时不要带这两个文件。
- **数据访问模式**：直连数据库设 `Local`；起 host 设 `Remote`，`DataPortal.Url` 为 host 链接。
- **配置文件**：`launchSettings.json` 环境变量为 `Development` 时读 `appsettings.Development.json`。
- **框架支持数据库**：SQL Server / MySQL / Oracle（Oracle 用得多）。
- **新菜单**：需先模块初始化，再配置菜单权限。
