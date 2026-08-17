> **类型**：配方库 + 工具 API 速查（蒸馏自 SMOM 开发手册 /HostDev/工具方法/ + /HostDev/经验案例/，20 页，2026-08-17 版本；末节含底层支持/实体/控制器主题相对 01/03/05 的增量补充）
> **来源**：http://10.10.51.213:30687/HostDev/
> **优先级**：高。写服务端工具类调用、批量数据库操作、外部系统交互、打印/推送扩展时先读本文件。
> **覆盖范围**：ObjectUtil·EntityUtil·DataChecker·数据容器·CommonEntityController·FileUtil·ThreadCacheUtil·HttpUtil·RedisUtil·SqlCreator·DbBulkProvider·打印增强·钉钉/邮件/企微推送·客制化WebApi·默认排序·树形递归·视图扩展实体·调度/快码/配置项/预警补充

---

# 服务端工具方法与经验案例

## 配方索引

| # | 任务 | 节 |
|---|---|---|
| 1 | 对象工具 ObjectUtil | 一 |
| 2 | 实体工具 EntityUtil | 二 |
| 3 | 数据检查器 DataChecker | 三 |
| 4 | 数据容器（批量上下文） | 四 |
| 5 | 通用实体控制器 CommonEntityController | 五 |
| 6 | 文件 / 线程缓存工具 | 六 |
| 7 | HTTP 工具 HttpUtil | 七 |
| 8 | Redis 工具 RedisUtil | 八 |
| 9 | SQL 语句构建器 SqlCreator | 九 |
| 10 | 数据库批量操作 DbBulkProvider | 十 |
| 11 | 经验案例（打印增强/推送/客制化Api/排序/递归/视图扩展/交互日志/自定义查询） | 十一 |
| 12 | 基础主题补充（调度防并发/快码/配置项/预警） | 十二 |

---

## 一、对象工具 ObjectUtil（`SIE.Core.Common`）

```csharp
from.ShallowCopy<TTo>();                    // 浅拷贝（同名属性第 1 层，引用类型赋引用）
from.ShallowCopy<TFrom, TTo>(to);           // 浅拷贝到已有对象
from.DeepCopy<TTo>();                       // 深拷贝（Json 序列化+反序列化）
strs.JoinString(seperator = ",");           // 连接字符串集合
str.Nvl(emptyReplace);                      // 空串替换
str.SubMaxString(maxLength);                // 按最大长度截取
str.SplitToDouble(separator = ",");         // "1,2,3" → List<double>（TryParse，失败为 0）
str.SplitToInt(separator = ",");
list.SortByStringNumber(p => p.No);         // 字符串数值排序（decimal.TryParse 排，就地重排 IList）
```

---

## 二、实体工具 EntityUtil（`SIE.Core.Utils`）

```csharp
EntityUtil.Label<TEntity>();                                   // 实体 Label（经 RepositoryFactory.Find）
EntityUtil.PropertyLabel<TEntity>(p => p.Code);                // 属性 Label（Reflect<T>.GetProperty）

// 批量填充快码显示值（catalogLookup 可传入复用）
EntityUtil.SetCatalogDisplay<T>(catalogType, list, t => t.Code, (t, name) => t.CodeDisplay = name,
    catalogLookup: RT.Service.Resolve<CatalogController>().GetCatalogList(catalogType).ToLookup(p => p.Code));

// 安全设置字符串属性：双方都为空不赋值（null 落库变 "" 导致误判脏数据）
entity.SetStringPropperty(Xxx.RemarkProperty, value);

// 验证字段唯一（验证规则内使用，写 ruleArgs.BrokenDescription）
EntityUtil.ValidateNotDuplicate(entity, ruleArgs,
    e => "编码【{0}】已存在".L10nFormat((e as Item).Code),
    Item.CodeProperty);
// 内部：CommonQueryCriteria 组合等值条件 + HasId 时排除自身 Id + DataAuths.LoadAll() 全数据域 CountBy
```

---

## 三、数据检查器 DataChecker（`SIE.Core.Common`，静态）

全部方法失败抛 `ValidationException`，`l10nName/l10nMsg` 参数控制名称是否本地化：

| 方法 | 说明 |
|---|---|
| `CheckNotNull<T>(value, message, l10n)` | 值非空 |
| `CheckNotEmpty(value, message, l10n)` | 字符串非空 |
| `CheckListNotEmpty<T>(value, message, l10n)` | 列表非空 |
| `CheckExists<TEntity>(double/string id, message, elo, l10n)` | 实体存在（RF.GetById，返回实体） |
| `CheckEnum<TEnum>(value, name, l10n)` | 枚举值合法（Enum.IsDefined） |
| `CheckAboveZero(value, name, l10n)` / `CheckAboveZeroNullable` | 数值 > 0 |
| `CheckDate(value, name, l10n)` / `CheckDateNullable` | 日期 ≥ 1900-01-01 |
| `CheckConfigExist<T>(value, message, l10n)` | 配置非 null（"未配置:{0}"） |
| `CheckDic(key, dic, dicName, l10n)` / `CheckDicNullable` | 字典键存在（Nullable 版 key 空直接返回 default） |
| `CheckRequiedProperty<T>(data, dataDesc)` | 反射检查 [Required] 属性全部非空 |
| `ThrowConcurrentException(Func<bool>)` | 条件为真抛"操作产生并发" |
| `ToDictionaryExTips<TKey,T>(dicName, func, l10n)` | ToDictionary 包装，重复键异常转友好提示 |

---

## 四、数据容器（数据传递与通用数据获取）

**BaseDataContainer**（`SIE.Core.DataContainers`，[Serializable]）：

```csharp
// Now：一次取 DB 时间 + Stopwatch 推算（避免循环内反复查库）
public DateTime Now {
    get {
        if (_dbStartDateTime == null) { _dbStartDateTime = RF.Find<Employee>().GetDbTime(); _stopwatch = Stopwatch.StartNew(); }
        return _dbStartDateTime.Value.Add(_stopwatch.Elapsed);
    }
}
public virtual string GetUnionKey(params object[] keys);   // string.Join("_", keys)
```

**BaseDownloadContainer 模式**（批量接口/下载场景）：按业务域组织"字典属性 + InitXxxDic 方法"，Init 内统一 `DataChecker.ToDictionaryExTips` 转字典。典型字典：`ItemDic`(编码→物料)、`ItemIdDic`、`ProductBomDic`、`WorkOrderDic`(单号/SapId/生产订单)、`CustomerDic`、`SupplierDic`、`EnterpriseDic`、`WipResourceDic`、`AsnDic`、`ShippingOrderDic`、`LotDic`、`PurchaseOrderDic`、`WarehouseDic`、`WarehouseStageDic`(仓库id→STAGE库位)、`WarehousePickToDic`、`Transaction/TransactionDic`(单据小类)、`InventoryAllocateDic`(调拨单)、`AssignRule/TurnOverRule`。未维护的单据小类/规则直接抛 ValidationException。

---

## 五、通用实体控制器 CommonEntityController（`SIE.Core.Common.Controllers`）

```csharp
var ctrl = RT.Service.Resolve<CommonEntityController>();

// 单实体
ctrl.GetEntity<TEntity, TType>(property, value, elo, dic);        // == 匹配，dic 缓存
ctrl.GetEntityWithDic<TEntity, TType>(property, value, dic, elo); // 缓存优先，未命中查库回填 [IgnoreProxy]
ctrl.GetEntityContains<TEntity, TType>(property, value, elo);     // %Contains% 模糊匹配

// 批量（内部 SplitContains 自动分批，防超长 IN）
ctrl.GetEntityListByNo<TEntity>(nos, elo);          // 按 No
ctrl.GetEntityListByCode<TEntity>(codes, elo);      // 按 Code
ctrl.GetEntityListById<TEntity>(ids, elo);          // 按 Id（double/string 两版）
ctrl.GetEntityList<TEntity, TProperty>(propertyName, values, elo);   // 按任意属性

// 锁定（须在事务内；实现 = DB.Update Set UpdateBy = RT.IdentityId 行级锁）
ctrl.Lock<TEntity>(bill); ctrl.Lock<TEntity>(bills);
ctrl.Lock<TEntity>(billId); ctrl.Lock<TEntity>(billIds);
```

---

## 六、文件 / 线程缓存工具

**FileUtil**（`SIE.Core.Utils`）：`FileUtil.IsImage(fileTypeOrName)`（jpg/jpeg/png/gif/bmp）。

**ThreadCacheUtil**（`SIE.Core.Caches`，循环处理中的数据缓存）：

```csharp
var dic = ThreadCacheUtil.Get("ComplaintTracking_EmployeeCodeDic", () => new Dictionary<string, Employee>());   // 默认 3 分钟过期
ThreadCacheUtil.Get(key, TimeSpan.FromMinutes(10), defaultValue);
// 实现：存 AppContext.Items（线程级），带 _ExpireTimestamp 过期判断，过期重算回填
```

---

## 七、HTTP 工具 HttpUtil（`SIE.Core.Utils`，单例 `HttpUtil.Instance`）

```csharp
HttpUtil.Instance.Get<TResponse>(url, urlParams, header, timeoutSeconds);           // timeout 默认 180s
HttpUtil.Instance.PostJson<TJsonObj, TResponse>(url, jsonObj, header, encoding, timeout);
HttpUtil.Instance.PostJson(url, json, header, encoding, timeout);                   // 返回 string
HttpUtil.Instance.PostForm<TResponse>(url, formData, header, encoding, timeout);
HttpUtil.Instance.Request(url, HttpMethod, requestHandle, headers, timeout);        // 底层通用
HttpUtil.Instance.CreateGetUrl(baseUrl, getParams); HttpUtil.Instance.CreateJson(obj); HttpUtil.Instance.CreateObject<T>(str);
HttpUtil.Instance.ResponseConvert<TResponse>(responseStr);                          // string 直返/JSON 反序列化（失败报原始报文）

// 带日志版本（ApiLogModel 记录 Target/RequestContent/ResponseContent；响应实现 IResponseDecode 自动 DecodeResponse）
HttpUtil.Instance.PostJsonWithLog<TRequest, TResponse>(url, request, logModel);
HttpUtil.Instance.PostFormWithLog<TResponse>(url, requestForm, logModel);
```

**机制**：HttpClient 单例（忽略 HTTPS 证书校验、全局上限 1 小时）；单请求超时用 CancellationTokenSource 实现，TaskCanceledException 转友好"网络请求超时"；非 200 抛"网络请求失败，错误代码..."。

---

## 八、Redis 工具 RedisUtil（`SIE.Core.Common`）

```csharp
// 缓存：键 = "proj_cache_{id}_{md5(json(key))}"
RedisUtil.GetCache<TValue>(id, key);
RedisUtil.SetCache(id, key, value, expireMinutes = 1);

// 防并发锁：键 = "proj_lock_{id}_{md5(json(key))}"
RedisUtil.LockToDo(id, key, "行为描述", () => { /* 需防并发逻辑 */ }, lockSeconds = 300);
RedisUtil.LockBatchToDo<T>(id, keys, "行为描述", action, lockSeconds = 600);   // 批量多键锁（全部锁定成功才执行）
// 未抢到锁 → ValidationException("XX产生并发，请稍后重试") + Logger.Error
```

**坑点**：未配置 `RedisConnectionStrings` 时 `RT.Redis.Lock` 不报错，故先 `CheckRedisConfig()` 主动校验；获取锁异常时只取消息第一行（密码错误报文含密码，防泄漏）。

---

## 九、SQL 语句构建器 SqlCreator（`SIE.HwatsingReport.Utils`，可复制的自研模式）

**用法**（配合 `DbAccesserFactory.Create` + `reader.ToList<T>()`）：

```csharp
using (var dba = DbAccesserFactory.Create(HwatsingReportEntityDataProvider.ConnectionStringName))
{
    var parameters = new Dictionary<string, IDbDataParameter>();
    var bill = new SqlCreator("bill", dba, parameters);
    var wo = new SqlCreator("wo", dba, parameters);
    var sql = $@"
SELECT
    {bill.As("MonthDate", $"CONVERT(VARCHAR(7), {bill}.CREATE_DATE, 120)")},
    {bill.As("InspQty", $"COUNT(1)")}
FROM PQC_FINAL_INSP_BILL {bill}
    LEFT JOIN WO {wo} ON {wo}.ID = {bill}.WORK_ORDER_ID
WHERE {bill}.INSPECTION_STATUS = 2 {bill.AndInvOrgPhantom()}
    {bill.AndIf(() => itemId > 0,         "ITEM_ID", "p_itemId", itemId)}
    {bill.AndIf(() => beginDate.HasValue, "CREATE_DATE", "p_beginDate", beginDate, ">=")}
    {wo.AndIf(() => orderNo.IsNotEmpty(), "NO", "p_orderNo", orderNo)}
GROUP BY CONVERT(VARCHAR(7), {bill}.CREATE_DATE, 120)";
    var cmd = dba.CreateCommand(sql, CommandType.Text, parameters.Values.ToArray());
    var list = cmd.ExecuteReader().ToList<ResultModel>();
}
```

**API**：`As(alias, sql)`（列别名）、`Columns(params)`、`ColumnAs`、`And(col, param, value, op="=")`（自动 AddParameter）、`AndIf(Func<bool>, ...)`（条件拼接）、`AndInvOrg()`/`AndPhantom()`/`AndInvOrgPhantom()`（INV_ORG_ID + IS_PHANTOM 常用组合）、`ToString()` 返回表别名（插值直接写 `{bill}` 得 "bill"）。参数经 `DbAccesser.SqlDialect.GetParameterName` 适配方言；重复参数名不同值抛异常。

---

## 十、数据库批量操作 DbBulkProvider（`SIE.Core.DbBulks`）

**前提**：RF.Save 逐条操作，大数据量用批量；SqlServer 连接串建议 `"ProviderName": "SqlServer"`。

**红线**：
- **不触发验证规则 / 提交事件，单层级插入/更新/删除（不处理任何子列表）**
- SqlServer 实现要求**数据库字段名全大写**（ListToDataTable 用大写列名匹配）
- 无特殊要求尽量用 RF.Save

```csharp
DbBulkProvider.GetEntityId<TEntity>(qty, batchSize = 1000);   // 批量取 ID：每块取一个序列 ID 再切小数（1000, 1000.001...1000.999）
DbBulkProvider.SetEntityId(entityList);                        // 给无 Id 实体批量赋 Id
DbBulkProvider.Insert(entityList);                             // 仅 PersistenceStatus.New
DbBulkProvider.Update(entityList, params 指定属性);            // 仅 Modified，可只更新指定属性
DbBulkProvider.InsertOrUpdate(entityList);
DbBulkProvider.Delete<TEntity, TKey>(entityList);              // 置 Deleted 状态后 DB.Delete（不删子表）
DbBulkProvider.Save<TEntity, TKey>(entityList);                // 删+增+改（单层级！删子表场景慎用）
// 全部自动：SetEntityId、填 CreateBy/UpdateBy/CreateDate/UpdateDate/InvOrgId、事务包裹、完成后置 Unchanged
```

**实现**：SqlServer 用 SqlBulkCopy（BatchSize=10000）+ 临时表 + MERGE 更新（受影响数与预期不符抛异常）；Oracle 用 ODP ArrayBindCount 数组绑定（分块 10000，**未验证**）。更新默认排除 ID/IS_LOCKED/IS_PHANTOM/CREATE_BY/CREATE_DATE 列。

---

## 十一、经验案例

### 11.1 打印增强（LocalContext 模式，解 N+1）

框架打印模板逐笔处理数据 → 扩展字段易 N+1。**优化**：取数提前到取打印数据之后、调打印方法之前，一次批量查出扩展信息，放实体 `LocalContext`。

四件套：
1. **扩展信息模型** `[Serializable]`（Id + 各扩展字段）
2. **Controller 批量取数**：`Query<T>().LeftJoin<...>...Select(...投影).ToList<ExtModel>()`（SplitDataExecute 分批）+ 通用加工（周别/备注切行等），返回 `Dictionary<id, ExtModel>`
3. **打印辅助类**：`InitBarcodePrintContainer(list)` → 逐实体 `printData.LocalContext[CommonConst.PrintDataContainer] = extModel`
4. **打印类** `ConverterData` 内 `packingRelation.LocalContext[CommonConst.PrintDataContainer] as ExtModel` 取值拼接

```csharp
// 使用：
report.Print(printable, filePath, printer, () => {
    var list = new PackingRelation[] { relation };
    new PackingNoPrintableHelper().InitBarcodePrintContainer(list);   // 取数回调内先初始化容器
    return list;
}, () => { }, copy);
```

**坑点**：`Clone` 不克隆 LocalContext，需克隆打印数据时手动 `newBarcode.LocalContext.CopyExtendedProperties(barcode.LocalContext);`。分隔符用极偏字符（示例 `CommonConst.PrintSeparator = '卐'`），普通字符易与数据冲突报错。

### 11.2 邮件 / 企业微信实时预警推送（PushPlug 标准模式）

```csharp
// ① 按 PushClass 查数据库 PushPlug 配置
var pushPlug = DB.Query<PushPlug>().Where(p => p.PushClass == "SIE.Senders.EmailSender").FirstOrDefault();
// pushClass：邮件 "SIE.Senders.EmailSender"；企微 "SIE.Senders.WxWorkSender.WxWorkAlerter"
// ② 平台获取发送器并初始化
var sender = RT.Service.Resolve<PushPlugController>().GetSender(pushPlug);
sender.Config.Initialize(pushPlug.Config);
// ③ 组消息模板 JSON（EmailMessageTemplate / WeChatMessageTemplate { Subject, Message }）
var template = JsonConvert.SerializeObject(new EmailMessageTemplate { Subject = "...", Message = htmlTable });
// ④ 发送
var receiveParam = new ReceiveParam { MessageTemplateJson = template };
receiveParam.Employees.AddRange(employees);
sender.Send(sender.CreateSendParam(new AlertResultBase(), receiveParam));
```

差异：邮件一次一条 HTML 表格消息；企微逐条明细循环发送。扩展新渠道 = 枚举 + GetPushPlug case + PushPlug 表配置 + ISender 实现。

### 11.3 钉钉群聊消息推送

前置：群设置 → 添加"自定义"机器人 → 拿 Webhook（设置了关键词则消息必含关键词）。开发四步：① 数据类（普通类 + [Label] 供界面配置）② 推送类继承 `DingTalkGroupAlertSender`（实现 `DataType` 数据类型 + `GetData(id)` 返回参数实例）③ `DingTalkMsgType` 枚举加值 + `DingTalkGroupAlertController.SenderDic` 绑定 ④ C# 调用推送。界面支持 Markdown 消息 + 可配置参数。

### 11.4 客制化 WebApi 接口报文格式

平台路由控制器在 `SIE.WebApiHost/Controllers`。自定义 `TransferController`（`[Route("transfer")]`，动态 GET/POST `{*url}`）+ `ApiTransfer` 静态映射：

```csharp
static Dictionary<string, ApiRequest> _routerMap = new()
{
    { "SomePath/Test", new ApiRequest {
        ApiType = nameof(TestController), Method = nameof(TestController.Test),
        Parameters = new ApiMethodParameter[1] } },   // 参数最多 1 个，body JSON 反序列化后填 Parameters[0].Value
};
// 流程：MapRouter(url)（小写匹配、重置 Context）→ MapParameters(body) → request.Context[ClientIPAddress] = GetClientIp → DataPortalManager.Server.Invoke(request, handler) → 失败 Problem(message)
```

### 11.5 默认排序（查询拦截）

DomainModule.Initialize 中 `XxxEntityDataProvider.Querying -= handler; += handler;`，handler 内判断实体类型 + `IsDefaultOrderBy`（无排序或框架默认 UPDATE_DATE,ID）时 `query.OrderBy.Clear()` + `QueryFactory.Instance.OrderBy(mainTable.FindColumn(Xxx.YyyProperty))`。

### 11.6 企业模型树形递归查找

数据量小 → 全量加载内存递归（优于 SQL 递归）：

```csharp
public virtual EntityList<Enterprise> GetEnterpriseLevelType(double? rootId, EnterpriseType levelType, string keyword)
{
    var all = RF.GetAll<Enterprise>(null, new EagerLoadOptions().LoadWithViewProperty());   // LoadWithViewProperty 保证 LevelType 可用
    var result = new List<Enterprise>();
    GetEnterpriseLevelTypeRecursive(rootId, levelType, keyword, all, result);
    return result.AsEntityList();
}
private void GetEnterpriseLevelTypeRecursive(double? parentId, EnterpriseType levelType, string keyword, EntityList<Enterprise> all, List<Enterprise> result)
{
    foreach (var child in all.Where(e => e.TreePId == parentId))   // 部门/车间可能不是工厂直接子节点，须递归
    {
        if (child.LevelType == levelType && (keyword == null || child.Name.Contains(keyword))) result.Add(child);
        GetEnterpriseLevelTypeRecursive(child.Id, levelType, keyword, all, result);
    }
}
```

### 11.7 视图扩展实体（非 Id 关联外键字段的取数）

实体通过**非 Id**（如单号）关联外部实体时：① 实体定义 `DM_Xxx` 属性（[Label]）+ `Meta.Property(...).DontMapColumn()` ② 视图扩展类 `BoardRoutingDbView : BoardRouting`（空派生）③ 扩展配置类 `EntityConfig<BoardRoutingDbView>` 中 `Meta.TableMeta.TableName = null;`（清空表映射）+ `Meta.MapView(sql).MapAllProperties()`（LEFT JOIN SQL，别名列名与 DM 属性对应）④ 查询用 `Query<BoardRoutingDbView>()`，结果 `datas.AsEntityList<BoardRouting>()` + `SetTotalCount`。

### 11.8 外部系统交互日志

```csharp
RT.Service.Resolve<ExtSysApiLogController>().ApiLog(ApiType.ErpUpload_GetToken, ApiSysType.ERP, ApiDirection.Send,
    (logModel) => {
        logModel.Target = url;
        logModel.RequestContent = JsonConvert.SerializeObject(queryDic);
        var responseStr = /* 网络请求 */;
        logModel.ResponseContent = responseStr;
        /* 响应解析、后续处理 */
    });   // 交互行为委托内写全部逻辑，日志自动记录；showApiTypeWhenError 控制异常时是否显示接口名
```

### 11.9 无自定义查询实体的自定义查询（Provider 模式）

目标：只有个别属性（如枚举多选）需客制化，其余套框架。四步：
1. `class XxxCutomizedCriteriaProvider : ICriteriaQueryProvider`，`GetList(CriteriaQuery)` 内按 `query.EntityType` 分流到对应 Controller
2. Module 中 `RT.Service.Register<XxxCutomizedCriteriaProvider>();`
3. 实体标注 `[CriteriaQuery(typeof(XxxCutomizedCriteriaProvider))]`
4. Controller.GetList 中：`criteriaQuery[propName]` 取值 → **置 null 清空**（防框架重复处理）→ `Query<T>().Where(客制化条件).Where(criteriaQuery.Criteria).OrderBy(criteriaQuery.OrderInfoList).ToList(criteriaQuery.PagingInfo, new EagerLoadOptions().LoadWithViewProperty())` —— 其余属性框架自动处理

---

## 十二、基础主题补充（与 01/03/05 配合读）

### 12.1 调度 JobBase 进程内防并发模式

```csharp
[Job("COA报告解析", typeof(JobParameter))]
public class CoaDataDecodeJob : JobBase
{
    private static bool _running = false;
    private static readonly object _locker = new object();
    protected override void ExecuteJob(object param)
    {
        lock (_locker)
        {
            if (_running) throw new ValidationException("调度在进程内产生并发，放弃本次执行");
            _running = true;
        }
        try { ExecuteJobSafe(param); }
        finally { lock (_locker) { _running = false; } }
    }
    protected virtual void ExecuteJobSafe(object param) { throw new NotImplementedException(); }
}
```

调度参数类：`[RootEntity, Serializable] class XxxParameter : JobParameter`（Property<int> 定义可配置参数）。**运行**=本地立即执行（调试用）；**触发**=进调度队列由调度服务执行。发布后避免"运行"（并发敏感任务）。

### 12.2 快码初始化（ManualDbMigration + 建表知识）

```csharp
class _20250620_000000_InitDefectCategory : ManualDbMigration   // 命名必须 _yyyyMMdd_HHmmss（时间取方案最新时间）
{
    public override string DbSetting => BarcodeEntityDataProvider.ConnectionStringName;
    public override string Description => "添加不良类别快码";
    public override ManualMigrationType Type => ManualMigrationType.Data;
    protected override void Down() { }
    protected override void Up()
    {
        this.RunCode(db => {
            if (AppRuntime.InvOrg == null || AppRuntime.InvOrg <= 0) AppRuntime.InvOrg = 1;   // 防重入
            var catalogType = RT.Service.Resolve<CatalogController>().GetCatalogType(catalogTypeCode);
            if (catalogType == null) RF.Save(new CatalogType { Code = catalogTypeCode, Name = "不良类别", ... });
        });
    }
}
```

快码表：**BD_CATALOG_TYPE**（组）/ **BD_CATALOG**（明细）；直接插数据（INSERT 全 10 列，时间函数 MSSQL `GETDATE()` / Oracle `SYSDATE` / MySQL `SYSDATE()`）。视图用 `UseCatalogEditor(e => e.CatalogType = Xxx.CatalogXxxType)`。

### 12.3 配置项四件套（实体配置项 / 全局配置项）

```csharp
// ① ConfigValue 派生（[RootEntity, Serializable][Label]，Property/IRefIdProperty 定义配置字段，重写 Display()）
public class RepairNoConfigValue : ConfigValue { /* NumberRuleId : IRefIdProperty + RefEntityProperty<NumberRule> CodeRule */ }
// ② 配置视图
public class RepairNoConfigValueViewConfig : WebViewConfig<RepairNoConfigValue>
{ protected override void ConfigDetailsView() { View.Property(p => p.CodeRule); } }
// ③ ModuleConfig 派生（[DisplayName][Description]，override DefaultValue）
public class RepairNoConfig : ModuleConfig<RepairNoConfigValue> { ... }
// 全局配置项：GlobalConfig<TValue> 派生（不挂实体）
// ④ 实体标注
[EntityWithConfig(typeof(RepairNoConfig))] public partial class Repair : DataEntity { }
// 简单单号配置无需自定义：直接用平台 NoConfig + [EntityWithConfig(typeof(NoConfig), "单号配置项", "单号配置规则")]

// 读取
var config = ConfigService.GetConfig(new RepairNoConfig(), typeof(Repair));        // 实体配置
var config = ConfigService.GetConfig(new ErpGlobalConfig());                        // 全局配置
```

### 12.4 预警三件套（Alert 全流程）

```csharp
// ① 结果类 [Serializable] : AlertResultBase（Body 推送内容 + Value 预警级别判定依据）
// ② 配置类 [RootEntity, Serializable][Label] : AlertConfig（Property<int> AlertValue；重写 Initialize(string)/ToString() 用 JsonConvert 反序列化/序列化）
// ③ 预警类 [RootEntity, Serializable] + [Alert("名称", typeof(Config), typeof(Result), "描述")] : AlertBase
public override AlertResultBase Run()
{
    var config = this.Context.Config as XxxPlugConfig;
    var list = RT.Service.Resolve<XxxController>().GetYyyList();
    if (list.Any())
    {
        var result = new XxxResult();
        result.Body = /* StringBuilder 拼 <br/> 内容（.L10N()） */;
        result.Value = config.AlertValue;
        return result;
    }
    return null;
}
```

### 12.5 其他速记

- **打印基类 Printable**：`Separator` 可重写（默认 `|`，数据含分隔符会报错→重写）；`GetPropertys(Type)` 定义可打印字段（增列）；`ConverterData(object)` 填充（**赋值顺序必须按 GetPropertys 添加顺序**）。标注法：实体标 `[BillPrintable(typeof(XxxPrintable))]`（仅单据打印）；命令法见 18 号文件第五节。
- **附件实体**：`Attachment<T>` 派生（[ChildEntity, Serializable]）+ 仓库 `AttachmentRepository<TAttachment>` + 配置 `AttachmentEntityConfig<T>`（`Meta.EnableDiscriminator("主体名")`，附件同表鉴别器区分）；主实体挂 `ListProperty<EntityList<TAttachment>>`（GetLazyList）；附件视图可选命令 Download/FtpDownload/UploadAttachment/DeleteAttachment；控制器 `RT.Service.Resolve<AttachmentController>()`。
- **自定义实体仓库**：`[DataProvider(typeof(XxxEntityDataProvider))] class XxxRepository : CommonEntityRepository<T>`，重写 `Insert(Entity)/Update(Entity)`（如密码加密/部分字段更新）。
