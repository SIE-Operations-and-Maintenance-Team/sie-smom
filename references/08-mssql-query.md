> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：MSSQL____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：MSSQL查询规范·C#实体->SQL类型映射·JOIN·枚举·分页·避坑

---

# MSSQL 查询规范（基于实体映射）

## 一、C# 实体与 SQL Server 表结构映射关系

### 1.1 DataEntity 基类继承体系

所有业务实体继承自 `DataEntity`，对应 SQL Server 查询中每个表的公共字段集。

```csharp
// C# 基类（框架提供）
public class DataEntity
{
    public long Id { get; set; }                     // → [ID] FLOAT NOT NULL
    public long SyncId { get; set; }                 // → [SYNC_ID] FLOAT NOT NULL
    public long? CreateBy { get; set; }              // → [CREATE_BY] FLOAT NULL
    public DateTime? CreateDate { get; set; }        // → [CREATE_DATE] DATETIME NULL
    public long? UpdateBy { get; set; }              // → [UPDATE_BY] FLOAT NULL
    public DateTime? UpdateDate { get; set; }        // → [UPDATE_DATE] DATETIME NULL
    public int? InvOrgId { get; set; }               // → [INV_ORG_ID] INT NULL
    public bool IsPhantom { get; set; }              // → [IS_PHANTOM] BIT NOT NULL DEFAULT 0
}
```

```sql
-- 查询时必须理解的默认字段映射
SELECT B.[ID],              -- long → FLOAT NOT NULL
       B.[SYNC_ID],          -- long → FLOAT NOT NULL
       B.[CREATE_BY],        -- long? → FLOAT NULL
       B.[CREATE_DATE],      -- DateTime? → DATETIME NULL
       B.[UPDATE_BY],        -- long? → FLOAT NULL
       B.[UPDATE_DATE],      -- DateTime? → DATETIME NULL
       B.[INV_ORG_ID],       -- int? → INT NULL
       B.[IS_PHANTOM]        -- bool → BIT NOT NULL DEFAULT 0
FROM [dbo].[EXAMPLE_BILL] B;
```

> **⚠️ FLOAT 类型说明**：SQL Server 中 `FLOAT` 是**近似浮点类型**（与 Oracle `NUMBER(18,0)` 精确值不同）。主键 ID 和外键作为序列生成的标识值使用时，实际值在精度范围内是精确的，但涉及 `FLOAT` 字段的计算和比较需注意浮点误差。

### 1.2 属性类型 → SQL Server 数据类型映射

| C# 类型 | SQL Server 类型 | 查询注意事项 |
|---------|-----------------|-------------|
| `long` / `long?` | `FLOAT` | 近似浮点，等值比较谨慎；主键用序列生成 |
| `int` / `int?` / `enum` | `INT` | 精确整数，直接等值匹配 |
| `float` / `double` | `FLOAT` | 同为近似浮点，避免等值比较 |
| `decimal` | `DECIMAL(18,6)` | 精确数值，保留 6 位小数 |
| `bool` | `BIT` | 值为 0 或 1 |
| `DateTime` / `DateTime?` | `DATETIME` | 精度约 3.33 毫秒 |
| `string` | `NVARCHAR` | Unicode 字符串，注意 `N` 前缀匹配 |
| `IRefIdProperty` | `FLOAT` | 外键字段，JOIN 关联使用 |

### 1.3 IRefIdProperty 引用类型映射

```csharp
// C# 实体中的引用属性
public class ExampleBill : DataEntity
{
    // IRefIdProperty 引用类型
    public WorkOrder WorkOrder { get; set; }    // → [WORK_ORDER_ID] FLOAT
    public Material Material { get; set; }      // → [MATERIAL_ID] FLOAT
}
```

```sql
-- 对应的 SQL 外键字段
SELECT B.[WORK_ORDER_ID],    -- FLOAT → C# WorkOrder (IRefIdProperty)
       B.[MATERIAL_ID]       -- FLOAT → C# Material (IRefIdProperty)
FROM [dbo].[EXAMPLE_BILL] B;
```

---

## 二、查询中的类型匹配规范

### 2.1 FLOAT 对应 long / long? —— 注意浮点

```csharp
// C# 实体
public long Id { get; set; }           // → [ID] FLOAT NOT NULL
public long? UpdateBy { get; set; }    // → [UPDATE_BY] FLOAT NULL
```

```sql
-- ✅ ID 由序列生成，等值匹配可靠
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [ID] = 100001;

-- ✅ UPDATE_BY 可空，用 IS NULL 判断
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [UPDATE_BY] IS NULL;

-- ✅ 批量查询（注意：IN 列表不得超过 1000 项）
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [ID] IN (100001, 100002, 100003);
```

### 2.2 INT 对应 int / enum —— 枚举用数字查询

```csharp
// C# 枚举
public enum BillStatus { Draft = 0, Approved = 1, Paid = 2, Cancelled = 9 }

public class ExampleBill : DataEntity
{
    public BillStatus Status { get; set; }  // → [STATUS] INT
    public int? InvOrgId { get; set; }      // → [INV_ORG_ID] INT NULL
}
```

```sql
-- ✅ 枚举字段用数字查询（与 C# 枚举值一致）
SELECT [ID], [NO], [STATUS] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 0;     -- Draft
SELECT [ID], [NO], [STATUS] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 1;     -- Approved
SELECT [ID], [NO], [STATUS] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] IN (1, 2); -- Approved + Paid

-- ✅ 枚举范围判断
SELECT [ID], [NO], [STATUS] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] >= 1;
```

### 2.3 BIT 对应 bool —— 0 / 1 判断

```csharp
// C# 实体
public bool IsPhantom { get; set; }  // → [IS_PHANTOM] BIT DEFAULT 0
```

```sql
-- ✅ 查询有效数据（IsPhantom = false → BIT = 0）
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [IS_PHANTOM] = 0;

-- ✅ 查询已删除数据（IsPhantom = true → BIT = 1）
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [IS_PHANTOM] = 1;
```

### 2.4 DECIMAL(18,6) 对应 decimal

```csharp
// C# 实体
public decimal Amount { get; set; }       // → [AMOUNT] DECIMAL(18,6)
public decimal? Qty { get; set; }         // → [QTY] DECIMAL(18,6) NULL
```

```sql
-- ✅ 查询时保持小数精度
SELECT [ID], [NO], [AMOUNT] FROM [dbo].[EXAMPLE_BILL] WHERE [AMOUNT] > 0;

-- ✅ 求和时使用 ROUND 控制小数位
SELECT ROUND(SUM([AMOUNT]), 2) AS TOTAL_AMOUNT FROM [dbo].[EXAMPLE_BILL];

-- ✅ 格式化输出
SELECT [ID], [NO], FORMAT([AMOUNT], 'N2') AS AMOUNT_STR
FROM [dbo].[EXAMPLE_BILL];
```

### 2.5 DATETIME 对应 DateTime —— 日期范围查询

```csharp
// C# 实体
public DateTime CreateDate { get; set; }       // → [CREATE_DATE] DATETIME NOT NULL
public DateTime? UpdateDate { get; set; }      // → [UPDATE_DATE] DATETIME NULL
public DateTime? BillDate { get; set; }         // → [BILL_DATE] DATETIME NULL
```

```sql
-- ✅ DateTime 范围查询
SELECT [ID], [NO], [CREATE_DATE]
FROM [dbo].[EXAMPLE_BILL]
WHERE [CREATE_DATE] >= '2024-06-01 00:00:00'
  AND [CREATE_DATE] < '2024-07-01 00:00:00';

-- ✅ 可空的 UpdateDate
SELECT [ID], [NO], [UPDATE_DATE]
FROM [dbo].[EXAMPLE_BILL]
WHERE [UPDATE_DATE] IS NOT NULL;

-- ✅ 精确到日的查询（半开区间）
SELECT [ID], [NO], [BILL_DATE]
FROM [dbo].[EXAMPLE_BILL]
WHERE [BILL_DATE] >= '2024-06-17 00:00:00'
  AND [BILL_DATE] < '2024-06-18 00:00:00';

-- ✅ 使用 CONVERT 格式化日期输出
SELECT [ID], [NO],
       CONVERT(VARCHAR(10), [BILL_DATE], 23) AS BILL_DATE_STR  -- 23 = yyyy-MM-dd
FROM [dbo].[EXAMPLE_BILL];
```

---

## 三、基于 DataEntity 基类的通用查询模式

### 3.1 默认查询模板

```csharp
// C# 实体：继承 DataEntity 后只需关注业务字段
public class ExampleBill : DataEntity
{
    public string No { get; set; }              // → [NO] NVARCHAR(80)
    public BillStatus Status { get; set; }      // → [STATUS] INT
    public decimal Amount { get; set; }         // → [AMOUNT] DECIMAL(18,6)
    public DateTime? BillDate { get; set; }      // → [BILL_DATE] DATETIME NULL
    public WorkOrder WorkOrder { get; set; }    // → [WORK_ORDER_ID] FLOAT
    public Material Material { get; set; }      // → [MATERIAL_ID] FLOAT
}
```

```sql
-- 完整查询（业务字段在前，DataEntity 基类字段在后）
SELECT B.[ID],                  -- DataEntity.Id（主键）
       B.[NO],                  -- 业务字段
       B.[STATUS],              -- 业务字段
       B.[AMOUNT],              -- 业务字段
       B.[BILL_DATE],           -- 业务字段
       B.[CREATE_BY],           -- DataEntity.CreateBy
       B.[CREATE_DATE],         -- DataEntity.CreateDate
       B.[UPDATE_BY],           -- DataEntity.UpdateBy
       B.[UPDATE_DATE],         -- DataEntity.UpdateDate
       B.[INV_ORG_ID],          -- DataEntity.InvOrgId
       B.[SYNC_ID],             -- DataEntity.SyncId
       B.[IS_PHANTOM]           -- DataEntity.IsPhantom
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0       -- 默认过滤逻辑删除数据
ORDER BY B.[ID] DESC;

-- 列表查询时只需返回需要的字段，无需每次都查全 12 列
SELECT B.[ID], B.[NO], B.[STATUS], B.[AMOUNT], B.[BILL_DATE],
       B.[CREATE_BY], B.[CREATE_DATE]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0
ORDER BY B.[ID] DESC;
```

### 3.2 列表查询（过滤逻辑删除 + 状态）

```sql
-- 所有列表查询统一格式
SELECT B.[ID], B.[NO], B.[STATUS], B.[AMOUNT], B.[BILL_DATE],
       B.[CREATE_BY], B.[CREATE_DATE]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0           -- 必有：过滤逻辑删除
  AND B.[STATUS] = 1               -- 按状态过滤
ORDER BY B.[ID] DESC;
```

### 3.3 详情查询

```sql
-- 单条记录查询
SELECT B.[ID], B.[NO], B.[STATUS], B.[AMOUNT], B.[BILL_DATE],
       B.[CREATE_BY], B.[CREATE_DATE],
       B.[UPDATE_BY], B.[UPDATE_DATE]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[ID] = 100001
  AND B.[IS_PHANTOM] = 0;
```

### 3.4 逻辑删除

```csharp
// C# 实体操作：设置 IsPhantom = true
bill.IsPhantom = true;
bill.UpdateBy = currentUserId;
bill.UpdateDate = DateTime.Now;
```

```sql
-- 对应的 SQL
UPDATE [dbo].[EXAMPLE_BILL]
SET [IS_PHANTOM] = 1,              -- bool → BIT = 1
    [UPDATE_BY] = 1001,            -- long? → FLOAT
    [UPDATE_DATE] = GETDATE()      -- DateTime? → DATETIME
WHERE [ID] = 100001;
```

---

## 四、基于 IRefIdProperty 的 JOIN 查询

### 4.1 引用类型 JOIN 模式

```csharp
// C# 实体中的引用关系
public class ExampleBill : DataEntity
{
    public WorkOrder WorkOrder { get; set; }      // IRefId → [WORK_ORDER_ID] FLOAT
    public Material Material { get; set; }        // IRefId → [MATERIAL_ID] FLOAT
    public User CreateByUser { get; set; }        // IRefId → [CREATE_BY] FLOAT
}
```

```sql
-- IRefIdProperty 关联查询
SELECT B.[ID], B.[NO], B.[AMOUNT],
       W.[NO]     AS WORK_ORDER_NO,    -- 关联 WorkOrder.No
       M.[NAME]   AS MATERIAL_NAME,    -- 关联 Material.Name
       U.[NAME]   AS CREATOR_NAME      -- 关联 User.Name
FROM [dbo].[EXAMPLE_BILL] B
LEFT JOIN [dbo].[WORK_ORDER] W ON W.[ID] = B.[WORK_ORDER_ID]    -- IRefId: WorkOrder
LEFT JOIN [dbo].[MATERIAL] M   ON M.[ID] = B.[MATERIAL_ID]      -- IRefId: Material
LEFT JOIN [dbo].[SYS_USER] U   ON U.[ID] = B.[CREATE_BY]        -- IRefId: CreateByUser
WHERE B.[IS_PHANTOM] = 0
ORDER BY B.[ID] DESC;
```

### 4.2 引用字段是否为空判断

```csharp
// C# 中判断 WorkOrder 是否为 null
if (bill.WorkOrder != null) { /* WorkOrder 被引用 */ }
```

```sql
-- 判断引用是否为空
SELECT B.[ID], B.[NO]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[WORK_ORDER_ID] IS NULL;      -- WorkOrder 未引用

SELECT B.[ID], B.[NO]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[WORK_ORDER_ID] IS NOT NULL;  -- WorkOrder 已引用
```

---

## 五、枚举字段查询规范

### 5.1 状态字段（Status）

```csharp
// C# 枚举定义
public enum BillStatus
{
    Draft = 0,       // 草稿
    Approved = 1,    // 已审核
    Paid = 2,        // 已付款
    Cancelled = 9    // 已作废
}

public BillStatus Status { get; set; }  // → [STATUS] INT
```

```sql
-- 枚举值用数字查询，与 C# 枚举值保持一致
SELECT [ID], [NO], [STATUS]
FROM [dbo].[EXAMPLE_BILL]
WHERE [IS_PHANTOM] = 0
  AND [STATUS] = 0;          -- BillStatus.Draft → 0

SELECT [ID], [NO], [STATUS]
FROM [dbo].[EXAMPLE_BILL]
WHERE [IS_PHANTOM] = 0
  AND [STATUS] IN (1, 2);    -- BillStatus.Approved + BillStatus.Paid
```

### 5.2 CHECK 约束与查询一致性

```sql
-- 建表时定义的 CHECK 约束
ALTER TABLE [dbo].[EXAMPLE_BILL]
ADD CONSTRAINT [CHK_EXAMPLE_BILL_STATUS]
CHECK ([STATUS] IN (0, 1, 2, 9));

-- 查询时必须使用 CHECK 约束范围内的值
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 0;   -- ✅ 草稿
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 1;   -- ✅ 已审核
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 2;   -- ✅ 已付款
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 9;   -- ✅ 已作废
```

---

## 六、索引映射与查询优化

### 6.1 常用索引模式

```csharp
// C# 实体中的索引配置
// HasIndex(x => x.No)        → IX_TABLE_NAME_NO
// HasIndex(x => x.Status)    → IX_TABLE_NAME_STATUS
// HasIndex(x => x.WorkOrder) → IX_TABLE_NAME_WORK_ORDER_ID
```

```sql
-- 查询时优先使用有索引的字段作为过滤条件

-- 单据号查询（走 IX_EXAMPLE_BILL_NO）
SELECT [ID], [NO], [STATUS] FROM [dbo].[EXAMPLE_BILL]
WHERE [IS_PHANTOM] = 0 AND [NO] = N'BILL20240001';

-- 状态批量查询（走 IX_EXAMPLE_BILL_STATUS）
SELECT [ID], [NO], [STATUS] FROM [dbo].[EXAMPLE_BILL]
WHERE [IS_PHANTOM] = 0 AND [STATUS] = 1;

-- 外键关联查询（走 IX_EXAMPLE_BILL_WORK_ORDER）
SELECT [ID], [NO], [WORK_ORDER_ID] FROM [dbo].[EXAMPLE_BILL]
WHERE [IS_PHANTOM] = 0 AND [WORK_ORDER_ID] = 100001;

-- ⚠️ 注意：所有 IRefIdProperty 外键字段必须在关联表上创建对应索引
```

### 6.2 复合索引查询顺序

如果实体配置了复合索引，查询条件顺序应与索引列顺序一致。

```csharp
// 假设 HasIndex(x => new { x.Status, x.BillDate })
// → IX_EXAMPLE_BILL_STATUS_BILL_DATE
```

```sql
-- 假设复合索引 IX_EXAMPLE_BILL_STATUS_BILL_DATE（Status + BillDate）

-- ✅ 条件顺序与索引列顺序一致
SELECT [ID], [NO], [STATUS], [BILL_DATE]
FROM [dbo].[EXAMPLE_BILL]
WHERE [STATUS] = 1                       -- 索引前置列
  AND [BILL_DATE] >= '2024-01-01 00:00:00';
```

---

## 七、INSERT 查询规范（基于映射）

### 7.1 完整 INSERT（含 DataEntity 默认字段）

```sql
INSERT INTO [dbo].[EXAMPLE_BILL] (
    -- DataEntity 默认字段（必填）
    [ID], [SYNC_ID], [CREATE_BY], [CREATE_DATE], [UPDATE_BY], [UPDATE_DATE],
    [INV_ORG_ID], [IS_PHANTOM],
    -- 业务字段
    [NO], [STATUS], [AMOUNT], [BILL_DATE],
    -- IRefIdProperty 外键字段
    [WORK_ORDER_ID], [MATERIAL_ID]
) VALUES (
    NEXT VALUE FOR [dbo].[SEQ_EXAMPLE_BILL_ID],          -- Id → FLOAT
    NEXT VALUE FOR [dbo].[SEQ_EXAMPLE_BILL_SYNC_ID],     -- SyncId → FLOAT
    1001, GETDATE(),                                     -- CreateBy, CreateDate
    1001, GETDATE(),                                     -- UpdateBy, UpdateDate
    101, 0,                                              -- InvOrgId → INT, IsPhantom → BIT
    N'BILL20240001', 0, 1000,                            -- No, Status, Amount
    '2024-06-17 00:00:00',                               -- BillDate → DATETIME
    200001, 300001                                       -- WorkOrderId, MaterialId → FLOAT
);
```

> **序列语法**：SQL Server 使用 `NEXT VALUE FOR [schema].[sequence_name]`，与 Oracle 的 `SEQ_NAME.NEXTVAL` 不同。

### 7.2 DECIMAL 类型 INSERT

```sql
-- SQL Server 自动补齐小数位
INSERT INTO [dbo].[EXAMPLE_BILL] ([ID], [SYNC_ID], ... [AMOUNT] ...)
VALUES (NEXT VALUE FOR [dbo].[SEQ_EXAMPLE_BILL_ID],
        NEXT VALUE FOR [dbo].[SEQ_EXAMPLE_BILL_SYNC_ID],
        ... 1000 ...);
```

---

## 八、从 C# 到 SQL 的快速查询映射表

### 8.1 条件查询映射

| C# 表达式 | SQL 条件 | 说明 |
|-----------|----------|------|
| `x.Id == 100001` | `[ID] = 100001` | `long` → `FLOAT` |
| `x.Status == BillStatus.Approved` | `[STATUS] = 1` | `enum` → `INT` |
| `x.Status >= BillStatus.Approved` | `[STATUS] >= 1` | 枚举比较 → 数字比较 |
| `x.Amount > 0` | `[AMOUNT] > 0` | `decimal` → `DECIMAL(18,6)` |
| `x.IsPhantom == false` | `[IS_PHANTOM] = 0` | `bool` → `BIT` |
| `x.IsPhantom == true` | `[IS_PHANTOM] = 1` | `bool` → `BIT` |
| `x.CreateDate >= startDate` | `[CREATE_DATE] >= '2024-01-01 00:00:00'` | `DateTime?` → `DATETIME` |
| `x.WorkOrder == null` | `[WORK_ORDER_ID] IS NULL` | `IRefIdProperty` 是否引用 |
| `x.No.Contains("2024")` | `[NO] LIKE N'%2024%'` | `string` → `NVARCHAR`，注意 `N` 前缀 |
| `x.No.StartsWith("BILL")` | `[NO] LIKE N'BILL%'` | `string` → `NVARCHAR` |
| `ids.Contains(x.Id)` | `[ID] IN (...)` | `long` 集合 → `FLOAT` 列表 |

### 8.2 排序映射

| C# 表达式 | SQL | 说明 |
|-----------|-----|------|
| `OrderByDescending(x => x.Id)` | `ORDER BY [ID] DESC` | 主键降序（最常用） |
| `ThenBy(x => x.Status)` | `ORDER BY [ID] DESC, [STATUS] ASC` | 多字段排序 |
| `OrderBy(x => x.CreateDate)` | `ORDER BY [CREATE_DATE] ASC` | 日期升序 |

### 8.3 SELECT 字段映射

| C# 实体字段 | SQL 列 | 类型映射 |
|------------|--------|---------|
| `Id` | `[ID]` | `long` → `FLOAT` |
| `SyncId` | `[SYNC_ID]` | `long` → `FLOAT` |
| `No` | `[NO]` | `string` → `NVARCHAR(80)` |
| `Status` | `[STATUS]` | `enum` → `INT` |
| `Amount` | `[AMOUNT]` | `decimal` → `DECIMAL(18,6)` |
| `BillDate` | `[BILL_DATE]` | `DateTime?` → `DATETIME NULL` |
| `IsPhantom` | `[IS_PHANTOM]` | `bool` → `BIT` |
| `WorkOrder` | `[WORK_ORDER_ID]` | `IRefIdProperty` → `FLOAT` |
| `CreateDate` | `[CREATE_DATE]` | `DateTime?` → `DATETIME NULL` |
| `UpdateBy` | `[UPDATE_BY]` | `long?` → `FLOAT NULL` |

---

## 九、常见查询场景（实体到 SQL 完整示例）

### 9.1 根据单号查询

```csharp
// C# LINQ 表达式
db.Query<ExampleBill>()
  .Where(x => x.No == billNo && !x.IsPhantom)
  .OrderByDescending(x => x.Id);
```

```sql
-- 生成的 SQL（列表查询只需返回需要的字段）
SELECT B.[ID], B.[NO], B.[STATUS], B.[AMOUNT], B.[BILL_DATE],
       B.[CREATE_BY], B.[CREATE_DATE]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[NO] = N'BILL20240001'
  AND B.[IS_PHANTOM] = 0
ORDER BY B.[ID] DESC;
```

### 9.2 按状态分组统计

```csharp
// C# LINQ
db.Query<ExampleBill>()
  .Where(x => !x.IsPhantom)
  .GroupBy(x => x.Status)
  .Select(g => new {
      Status = g.Key,
      Count = g.Count(),
      Total = g.Sum(x => x.Amount)
  });
```

```sql
-- 生成的 SQL
SELECT B.[STATUS],                            -- enum → INT
       COUNT(1) AS CNT,
       ROUND(SUM(B.[AMOUNT]), 2) AS TOTAL     -- decimal → DECIMAL(18,6)
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0                      -- bool → BIT = 0
GROUP BY B.[STATUS]
ORDER BY B.[STATUS];
```

### 9.3 外键关联查询（含引用实体字段）

```csharp
// C# LINQ 关联查询（注意：直接在 select 中访问引用属性会触发懒加载，
// 推荐通过 join 或 Include 显式加载）
from bill in db.Query<ExampleBill>()
join order in db.Query<WorkOrder>() on bill.WorkOrder.Id equals order.Id
join material in db.Query<Material>() on bill.Material.Id equals material.Id into mj
from material in mj.DefaultIfEmpty()
where !bill.IsPhantom && bill.Status == BillStatus.Approved
select new {
    bill.No, bill.Amount,
    OrderNo = order.No,
    MaterialName = material.Name
};
```

```sql
-- 对应的 SQL
SELECT B.[NO], B.[AMOUNT],
       W.[NO] AS ORDER_NO,
       M.[NAME] AS MATERIAL_NAME
FROM [dbo].[EXAMPLE_BILL] B
JOIN [dbo].[WORK_ORDER] W ON W.[ID] = B.[WORK_ORDER_ID]     -- IRefId: WorkOrder
LEFT JOIN [dbo].[MATERIAL] M ON M.[ID] = B.[MATERIAL_ID]     -- IRefId: Material
WHERE B.[IS_PHANTOM] = 0                                     -- bool → BIT
  AND B.[STATUS] = 1                                          -- BillStatus.Approved → 1
ORDER BY B.[ID] DESC;
```

### 9.4 TOP 限制行数

```sql
-- 限制返回行数（无需分页时使用 TOP）
SELECT TOP 100 B.[ID], B.[NO], B.[STATUS], B.[AMOUNT]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0
ORDER BY B.[ID] DESC;
```

### 9.5 分页查询

```csharp
// C# 分页
var page = db.Query<ExampleBill>()
    .Where(x => !x.IsPhantom && x.Status == BillStatus.Approved)
    .OrderByDescending(x => x.Id)
    .Skip((pageIndex - 1) * pageSize)
    .Take(pageSize)
    .ToList();
```

```sql
-- SQL Server 2012+ 分页（OFFSET FETCH）
SELECT B.[ID], B.[NO], B.[AMOUNT], B.[STATUS], B.[BILL_DATE]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0
  AND B.[STATUS] = 1
ORDER BY B.[ID] DESC
OFFSET (@page - 1) * @size ROWS
FETCH NEXT @size ROWS ONLY;

-- 大数据量时使用游标分页（避免 OFFSET 深翻页性能问题）
SELECT B.[ID], B.[NO], B.[AMOUNT], B.[STATUS], B.[BILL_DATE]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0
  AND B.[STATUS] = 1
  AND B.[ID] < @lastCursorId       -- 上一页最后一条的 ID
ORDER BY B.[ID] DESC
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;

-- SQL Server 2008 兼容分页（ROW_NUMBER）
SELECT * FROM (
    SELECT B.[ID], B.[NO], B.[AMOUNT], B.[STATUS], B.[BILL_DATE],
           ROW_NUMBER() OVER (ORDER BY B.[ID] DESC) AS RN
    FROM [dbo].[EXAMPLE_BILL] B
    WHERE B.[IS_PHANTOM] = 0
      AND B.[STATUS] = 1
) T
WHERE T.RN BETWEEN @startRow AND @endRow
ORDER BY T.[ID] DESC;
```

### 9.6 更新操作

```csharp
// C# 实体更新
var bill = db.Get<ExampleBill>(100001);
bill.Status = BillStatus.Approved;
bill.UpdateBy = currentUserId;
bill.UpdateDate = DateTime.Now;
db.Update(bill);
```

```sql
-- 对应的 SQL
UPDATE [dbo].[EXAMPLE_BILL]
SET [STATUS] = 1,                    -- enum → INT
    [AMOUNT] = 1000,                 -- decimal → DECIMAL(18,6)
    [UPDATE_BY] = 1001,              -- long? → FLOAT
    [UPDATE_DATE] = GETDATE()        -- DateTime? → DATETIME
WHERE [ID] = 100001
  AND [IS_PHANTOM] = 0;

-- 关联更新：根据子表汇总更新主表
UPDATE B
SET B.[AMOUNT] = T.TOTAL_AMOUNT,
    B.[UPDATE_BY] = 1001,
    B.[UPDATE_DATE] = GETDATE()
FROM [dbo].[EXAMPLE_BILL] B
JOIN (
    SELECT [BILL_ID], ROUND(SUM([LINE_AMOUNT]), 6) AS TOTAL_AMOUNT
    FROM [dbo].[EXAMPLE_BILL_LINE]
    GROUP BY [BILL_ID]
) T ON T.[BILL_ID] = B.[ID]
WHERE B.[ID] = 100001
  AND B.[IS_PHANTOM] = 0;
```

---

## 十、常见错误与避坑

### 10.1 FLOAT 等值比较

```sql
-- ❌ 错误：FLOAT 是近似浮点，等值比较不可靠（此处 ID 由序列生成不受影响，
--     但如果涉及 FLOAT 运算结果，应避免等值判断）
DECLARE @val FLOAT = 0.1 + 0.2;
IF @val = 0.3  -- 可能为 false ！FLOAT 运算有精度误差
    PRINT 'equal';

-- ✅ 正确：使用 ABS 范围比较
IF ABS(@val - 0.3) < 1e-10
    PRINT 'equal';
```

### 10.2 布尔值用数字而非字符串

```sql
-- ❌ 错误：BIT 字段不能传字符串
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [IS_PHANTOM] = 'false';

-- ✅ 正确：C# bool → BIT，值为 0 或 1
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [IS_PHANTOM] = 0;
```

### 10.3 枚举用数字而非名称

```sql
-- ❌ 错误：STATUS 是 INT，不能传枚举名称
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 'Approved';

-- ✅ 正确：使用 C# 枚举对应的数字值
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [STATUS] = 1;
```

### 10.4 DateTime 可空字段判断

```sql
-- ❌ 错误：UpdateDate 是 DateTime?，不能直接用等值判断
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [UPDATE_DATE] = NULL;

-- ✅ 正确：NULL 判断使用 IS NULL
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [UPDATE_DATE] IS NULL;

-- ✅ 正确：判断是否有过更新（C#: x.UpdateDate != null）
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [UPDATE_DATE] IS NOT NULL;
```

### 10.5 NVARCHAR 缺少 N 前缀

```sql
-- ❌ 错误：NVARCHAR 字段匹配时建议带 N 前缀（避免隐式转换）
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [NO] = 'BILL20240001';

-- ✅ 正确：使用 N 前缀匹配 Unicode 字符串
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL] WHERE [NO] = N'BILL20240001';
```

### 10.6 标识符方括号

```sql
-- ❌ 错误：NO 是 SQL Server 保留字，不加方括号可能导致歧义
SELECT ID, NO FROM EXAMPLE_BILL;

-- ✅ 正确：始终使用方括号包裹标识符
SELECT [ID], [NO] FROM [dbo].[EXAMPLE_BILL];
```

### 10.7 NULL 处理使用 ISNULL / COALESCE

```sql
-- ❌ 错误：可空字段直接参与运算可能产生 NULL
SELECT [ID], [NO], [AMOUNT] * [QTY] AS LINE_TOTAL
FROM [dbo].[EXAMPLE_BILL_LINE];

-- ✅ 正确：使用 ISNULL 将 NULL 转为默认值
SELECT [ID], [NO],
       ISNULL([AMOUNT], 0) * ISNULL([QTY], 0) AS LINE_TOTAL
FROM [dbo].[EXAMPLE_BILL_LINE];

-- ✅ COALESCE 支持多个备选值
SELECT [ID],
       COALESCE([REMARK], [NO], '无备注') AS DISPLAY_TEXT
FROM [dbo].[EXAMPLE_BILL];
```

---

## 十一、查询语句格式约定

### 11.1 关键字大小写

```sql
-- 关键字统一大写，标识符使用方括号
SELECT B.[ID],
       B.[NO],
       B.[STATUS],
       B.[AMOUNT]
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0
  AND B.[STATUS] = 1
ORDER BY B.[ID] DESC;
```

### 11.2 注释标注实体类型

```sql
-- 查询 EXAMPLE_BILL 表（对应 ExampleBill 实体）
SELECT B.[ID],                     -- DataEntity.Id
       B.[NO],                     -- 业务字段
       B.[STATUS],                 -- 业务字段（BillStatus 枚举 → INT）
       B.[AMOUNT],                 -- 业务字段（decimal → DECIMAL(18,6)）
       B.[BILL_DATE]               -- 业务字段（DateTime? → DATETIME NULL）
FROM [dbo].[EXAMPLE_BILL] B
WHERE B.[IS_PHANTOM] = 0
  AND B.[STATUS] = 1;
```

### 11.3 参数命名规范

```csharp
// C# 中参数化查询的命名规范
// 属性名 → @PropertyName 格式
```

```sql
-- 使用命名参数（与 C# 属性名对应）
SELECT [ID], [NO], [STATUS]
FROM [dbo].[EXAMPLE_BILL]
WHERE [IS_PHANTOM] = 0
  AND [NO] = @No                 -- 对应 string No
  AND [STATUS] = @Status          -- 对应 enum Status
  AND [BILL_DATE] >= @StartDate   -- 对应 DateTime? StartDate
  AND [BILL_DATE] < @EndDate;     -- 对应 DateTime? EndDate
```

---

## 十二、MSSQL 与 Oracle 查询差异速查

| 场景 | Oracle | SQL Server |
|------|--------|------------|
| 当前时间 | `SYSDATE` | `GETDATE()` |
| 序列取值 | `SEQ_ID.NEXTVAL` | `NEXT VALUE FOR [dbo].[SEQ_ID]` |
| 字符串前缀 | `'string'` | `N'string'`（Unicode） |
| 分页（12c+/2012+） | `OFFSET n ROWS FETCH NEXT m ROWS ONLY` | `OFFSET n ROWS FETCH NEXT m ROWS ONLY` |
| 分页（旧版） | `ROWNUM` / `ROW_NUMBER()` | `ROW_NUMBER()` / `TOP` |
| NVL / COALESCE | `NVL(col, 0)` | `ISNULL(col, 0)` / `COALESCE(col, 0)` |
| 标识符引用 | 大写字段名 | `[方括号]` |
| 模式前缀 | 无（或用户名） | `[dbo]` |
| 日期字面量 | `DATE '2024-01-01'` 或 `TO_DATE` | `'2024-01-01'` 字符串自动转换 |
| 日期格式化 | `TO_CHAR(date, 'fmt')` | `CONVERT(varchar, date, style)` / `FORMAT()` |
| 类型转换 | `TO_NUMBER`、`TO_CHAR` | `CAST`、`CONVERT` |
| 可空字段排序 | `NULLS FIRST / LAST` | 默认 `NULLS` 在排序中比非空值小 |
| 列注释 | `COMMENT ON COLUMN` | `sp_addextendedproperty` |

---

## 十三、附则

1. **SELECT 字段顺序**：业务字段在前，DataEntity 基类字段在后。
2. **关键字大写**：`SELECT`、`FROM`、`WHERE`、`JOIN`、`AND`、`OR`、`ORDER BY` 等关键字统一大写。
3. **标识符使用方括号**：表名和字段名使用 `[方括号]` 包裹，避免保留字冲突。
4. **模式前缀**：表名前加 `[dbo]` 模式前缀。
5. **参数占位符**：使用 `@paramName` 格式（SqlClient / .NET），参数名与 C# 属性名对应。
6. **每次查询必须带 IS_PHANTOM = 0**（除非有明确需求查询逻辑删除数据）。
7. **外键字段按需选择 JOIN 类型**：非空外键用 `JOIN`，可空外键用 `LEFT JOIN`。
8. **NVARCHAR 字符串使用 N 前缀**：匹配 `NVARCHAR` 字段时使用 `N'字符串'`。
9. **分页必须带 ORDER BY**：确保结果顺序一致。
10. **避免 FLOAT 等值比较**：近似浮点类型不应使用 `=` 比较运算结果。
