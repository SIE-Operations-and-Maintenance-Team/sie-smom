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
