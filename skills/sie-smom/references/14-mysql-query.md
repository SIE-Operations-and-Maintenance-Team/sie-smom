> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：MYSQL____.md
> **优先级**：高。
> **覆盖范围**：MySQL查询规范·C#实体->SQL类型映射·JOIN·枚举·分页·避坑

---

# MySQL 查询规范（基于实体映射）

## 一、C# 实体与 MySQL 表结构映射关系

### 1.1 DataEntity 基类继承体系

所有业务实体继承自 `DataEntity`，对应 SQL 查询中每个表的公共字段集。

```csharp
// C# 基类（框架提供）
public class DataEntity
{
    public long Id { get; set; }              // → ID BIGINT NOT NULL PK
    public long SyncId { get; set; }          // → SYNC_ID BIGINT NOT NULL
    public long? CreateBy { get; set; }       // → CREATE_BY BIGINT NULL
    public DateTime? CreateDate { get; set; } // → CREATE_DATE DATETIME NULL
    public long? UpdateBy { get; set; }       // → UPDATE_BY BIGINT NULL
    public DateTime? UpdateDate { get; set; } // → UPDATE_DATE DATETIME NULL
    public int? InvOrgId { get; set; }        // → INV_ORG_ID INT NULL
    public bool IsPhantom { get; set; }       // → IS_PHANTOM TINYINT(1) NOT NULL DEFAULT 0
}
```

```sql
-- 查询时必须理解的默认字段映射
SELECT B.ID,              -- long → BIGINT
       B.SYNC_ID,          -- long → BIGINT
       B.CREATE_BY,        -- long? → BIGINT NULL
       B.CREATE_DATE,      -- DateTime? → DATETIME NULL
       B.UPDATE_BY,        -- long? → BIGINT NULL
       B.UPDATE_DATE,      -- DateTime? → DATETIME NULL
       B.INV_ORG_ID,       -- int? → INT NULL
       B.IS_PHANTOM        -- bool → TINYINT(1) DEFAULT 0
FROM EXAMPLE_BILL B;
```

### 1.2 属性类型 → MySQL 数据类型映射

| C# 类型 | MySQL 类型 | 查询注意事项 |
|---------|-------------|-------------|
| `long` / `long?` | `BIGINT` | 精确整数，直接等值匹配 |
| `int` / `int?` / `enum` | `INT` | 枚举值查询直接用数字 |
| `float` / `double` | `DOUBLE` | 近似浮点，避免等值比较 |
| `decimal` | `DECIMAL(18,6)` | **保留6位小数**，精确数值 |
| `bool` | `TINYINT(1)` | 值为 0 或 1 |
| `DateTime` / `DateTime?` | `DATETIME` | 精确到秒，查询用字符串字面量 |
| `string` | `VARCHAR` | 字符串匹配注意引号 |
| `IRefIdProperty` | `BIGINT` | 外键字段，JOIN 关联使用 |

### 1.3 IRefIdProperty 引用类型映射

```csharp
// C# 实体中的引用属性
public class ExampleBill : DataEntity
{
    // IRefIdProperty 引用类型
    public WorkOrder WorkOrder { get; set; }    // → WORK_ORDER_ID BIGINT
    public Material Material { get; set; }      // → MATERIAL_ID BIGINT
}
```

```sql
-- 对应的 SQL 外键字段
SELECT B.WORK_ORDER_ID,    -- BIGINT → C# WorkOrder (IRefIdProperty)
       B.MATERIAL_ID       -- BIGINT → C# Material (IRefIdProperty)
FROM EXAMPLE_BILL B;
```

---

## 二、查询中的类型匹配规范

### 2.1 BIGINT 对应 long / long? —— 精确匹配

```csharp
// C# 实体
public long Id { get; set; }           // → ID BIGINT NOT NULL
public long? UpdateBy { get; set; }    // → UPDATE_BY BIGINT NULL
```

```sql
-- ✅ ID 是非空 BIGINT，直接等值匹配
SELECT ID, NO FROM EXAMPLE_BILL WHERE ID = 100001;

-- ✅ UPDATE_BY 可空，用 IS NULL 判断
SELECT ID, NO FROM EXAMPLE_BILL WHERE UPDATE_BY IS NULL;

-- ✅ 批量查询（注意：IN 列表不得超过 1000 项，超过应改用分批查询或临时表 JOIN）
SELECT ID, NO FROM EXAMPLE_BILL WHERE ID IN (100001, 100002, 100003);
```

### 2.2 INT 对应 int / enum —— 枚举用数字查询

```csharp
// C# 枚举
public enum BillStatus { Draft = 0, Approved = 1, Paid = 2, Cancelled = 9 }

public class ExampleBill : DataEntity
{
    public BillStatus Status { get; set; }  // → STATUS INT
    public int? InvOrgId { get; set; }      // → INV_ORG_ID INT NULL
}
```

```sql
-- ✅ 枚举字段用数字查询（与 C# 枚举值一致）
SELECT ID, NO, STATUS FROM EXAMPLE_BILL WHERE STATUS = 0;      -- Draft
SELECT ID, NO, STATUS FROM EXAMPLE_BILL WHERE STATUS = 1;      -- Approved
SELECT ID, NO, STATUS FROM EXAMPLE_BILL WHERE STATUS IN (1, 2); -- Approved + Paid

-- ✅ 枚举范围判断
SELECT ID, NO, STATUS FROM EXAMPLE_BILL WHERE STATUS >= 1;
```

### 2.3 TINYINT(1) 对应 bool —— 0 / 1 判断

```csharp
// C# 实体
public bool IsPhantom { get; set; }  // → IS_PHANTOM TINYINT(1) DEFAULT 0
```

```sql
-- ✅ 查询有效数据（IsPhantom = false → TINYINT(1) = 0）
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 0;

-- ✅ 查询已删除数据（IsPhantom = true → TINYINT(1) = 1）
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 1;
```

### 2.4 DECIMAL(18,6) 对应 decimal —— 注意精度

```csharp
// C# 实体
public decimal Amount { get; set; }       // → AMOUNT DECIMAL(18,6)
public decimal? Qty { get; set; }         // → QTY DECIMAL(18,6) NULL
```

```sql
-- ✅ 查询时保持小数精度
SELECT ID, NO, AMOUNT FROM EXAMPLE_BILL WHERE AMOUNT > 0;

-- ✅ 求和时使用 ROUND 控制小数位
SELECT ROUND(SUM(AMOUNT), 2) AS TOTAL_AMOUNT FROM EXAMPLE_BILL;

-- ✅ 格式化输出
SELECT ID, NO, FORMAT(AMOUNT, 2) AS AMOUNT_STR
FROM EXAMPLE_BILL;
```

### 2.5 DATETIME 对应 DateTime —— 日期范围查询

```csharp
// C# 实体
public DateTime CreateDate { get; set; }       // → CREATE_DATE DATETIME NOT NULL
public DateTime? UpdateDate { get; set; }      // → UPDATE_DATE DATETIME NULL
public DateTime BillDate { get; set; }         // → BILL_DATE DATETIME
```

```sql
-- ✅ DateTime 范围查询（MySQL 接受 'YYYY-MM-DD HH:MM:SS' 字符串字面量）
SELECT ID, NO, CREATE_DATE
FROM EXAMPLE_BILL
WHERE CREATE_DATE >= '2024-06-01 00:00:00'
  AND CREATE_DATE < '2024-07-01 00:00:00';

-- ✅ 可空的 UpdateDate
SELECT ID, NO, UPDATE_DATE
FROM EXAMPLE_BILL
WHERE UPDATE_DATE IS NOT NULL;

-- ✅ 精确到日的查询（半开区间）
SELECT ID, NO, BILL_DATE
FROM EXAMPLE_BILL
WHERE BILL_DATE >= '2024-06-17 00:00:00'
  AND BILL_DATE < '2024-06-18 00:00:00';

-- ✅ 使用 DATE_FORMAT 格式化日期输出
SELECT ID, NO,
       DATE_FORMAT(BILL_DATE, '%Y-%m-%d') AS BILL_DATE_STR
FROM EXAMPLE_BILL;
```

---

## 三、基于 DataEntity 基类的通用查询模式

### 3.1 默认查询模板

```csharp
// C# 实体：继承 DataEntity 后只需关注业务字段
public class ExampleBill : DataEntity
{
    public string No { get; set; }              // → NO VARCHAR(80)
    public BillStatus Status { get; set; }      // → STATUS INT
    public decimal Amount { get; set; }         // → AMOUNT DECIMAL(18,6)
    public DateTime BillDate { get; set; }      // → BILL_DATE DATETIME
    public WorkOrder WorkOrder { get; set; }    // → WORK_ORDER_ID BIGINT
    public Material Material { get; set; }      // → MATERIAL_ID BIGINT
}
```

```sql
-- 完整查询（业务字段在前，DataEntity 基类字段在后）
SELECT B.ID,                  -- DataEntity.Id（主键）
       B.NO,                  -- 业务字段
       B.STATUS,              -- 业务字段
       B.AMOUNT,              -- 业务字段
       B.BILL_DATE,           -- 业务字段
       B.CREATE_BY,           -- DataEntity.CreateBy
       B.CREATE_DATE,         -- DataEntity.CreateDate
       B.UPDATE_BY,           -- DataEntity.UpdateBy
       B.UPDATE_DATE,         -- DataEntity.UpdateDate
       B.INV_ORG_ID,          -- DataEntity.InvOrgId
       B.SYNC_ID,             -- DataEntity.SyncId
       B.IS_PHANTOM           -- DataEntity.IsPhantom
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0       -- 默认过滤逻辑删除数据
ORDER BY B.ID DESC;

-- 列表查询时只需返回需要的字段，无需每次都查全 12 列
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
ORDER BY B.ID DESC;
```

### 3.2 列表查询（过滤逻辑删除 + 状态）

```sql
-- 所有列表查询统一格式
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0           -- 必有：过滤逻辑删除
  AND B.STATUS = 1               -- 按状态过滤
ORDER BY B.ID DESC;
```

### 3.3 详情查询

```sql
-- 单条记录查询
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE,
       B.UPDATE_BY, B.UPDATE_DATE
FROM EXAMPLE_BILL B
WHERE B.ID = 100001
  AND B.IS_PHANTOM = 0;
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
UPDATE EXAMPLE_BILL
SET IS_PHANTOM = 1,              -- bool → TINYINT(1) = 1
    UPDATE_BY = 1001,            -- long? → BIGINT
    UPDATE_DATE = NOW()          -- DateTime? → DATETIME
WHERE ID = 100001;
```

---

## 四、基于 IRefIdProperty 的 JOIN 查询

### 4.1 引用类型 JOIN 模式

```csharp
// C# 实体中的引用关系
public class ExampleBill : DataEntity
{
    public WorkOrder WorkOrder { get; set; }      // IRefId → WORK_ORDER_ID BIGINT
    public Material Material { get; set; }        // IRefId → MATERIAL_ID BIGINT
    public User CreateByUser { get; set; }        // IRefId → CREATE_BY  BIGINT
}
```

```sql
-- IRefIdProperty 关联查询
SELECT B.ID, B.NO, B.AMOUNT,
       W.NO     AS WORK_ORDER_NO,    -- 关联 WorkOrder.No
       M.NAME   AS MATERIAL_NAME,    -- 关联 Material.Name
       U.NAME   AS CREATOR_NAME      -- 关联 User.Name
FROM EXAMPLE_BILL B
LEFT JOIN WORK_ORDER W ON W.ID = B.WORK_ORDER_ID    -- IRefId: WorkOrder
LEFT JOIN MATERIAL M   ON M.ID = B.MATERIAL_ID      -- IRefId: Material
LEFT JOIN SYS_USER U   ON U.ID = B.CREATE_BY        -- IRefId: CreateByUser
WHERE B.IS_PHANTOM = 0
ORDER BY B.ID DESC;
```

### 4.2 引用字段是否为空判断

```csharp
// C# 中判断 WorkOrder 是否为 null
if (bill.WorkOrder != null)
{
    // WorkOrder 被引用
}
```

```sql
-- 判断引用是否为空
SELECT B.ID, B.NO
FROM EXAMPLE_BILL B
WHERE B.WORK_ORDER_ID IS NULL;      -- WorkOrder 未引用

SELECT B.ID, B.NO
FROM EXAMPLE_BILL B
WHERE B.WORK_ORDER_ID IS NOT NULL;  -- WorkOrder 已引用
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

// C# 属性
public BillStatus Status { get; set; }  // → STATUS INT
```

```sql
-- 枚举值用数字查询，与 C# 枚举值保持一致
SELECT ID, NO, STATUS
FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0
  AND STATUS = 0;          -- BillStatus.Draft → 0

SELECT ID, NO, STATUS
FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0
  AND STATUS IN (1, 2);    -- BillStatus.Approved + BillStatus.Paid
```

### 5.2 CHECK 约束与查询一致性

```sql
-- 建表时定义的 CHECK 约束（MySQL 8.0.16+ 才真正强制，旧版本不生效）
ALTER TABLE EXAMPLE_BILL
ADD CONSTRAINT CHK_EXAMPLE_BILL_STATUS
CHECK (STATUS IN (0, 1, 2, 9));

-- 查询时必须使用 CHECK 约束范围内的值
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 0;   -- ✅ 草稿
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 1;   -- ✅ 已审核
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 2;   -- ✅ 已付款
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 9;   -- ✅ 已作废
```

> **⚠️ CHECK 约束注意**：MySQL 5.7 及以下版本会**解析但忽略** CHECK 约束（不报错也不校验），必须依赖 8.0.16+ 版本或应用层枚举校验；SMOM 代码中枚举字段合法性由 C# 枚举 + 实体验证规则保证。

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
SELECT ID, NO, STATUS FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0 AND NO = 'BILL20240001';

-- 状态批量查询（走 IX_EXAMPLE_BILL_STATUS）
SELECT ID, NO, STATUS FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0 AND STATUS = 1;

-- 外键关联查询（走 IX_EXAMPLE_BILL_WORK_ORDER）
SELECT ID, NO, WORK_ORDER_ID FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0 AND WORK_ORDER_ID = 100001;

-- ⚠️ 注意：所有 IRefIdProperty 外键字段（如 WORK_ORDER_ID、MATERIAL_ID）
-- 必须在关联表上创建对应索引，否则 JOIN 查询时驱动表会走全表扫描
```

### 6.2 复合索引查询顺序

如果实体配置了复合索引，查询条件顺序应与索引列顺序一致（最左前缀原则）。

```csharp
// 假设 HasIndex(x => new { x.Status, x.BillDate })
// → IX_EXAMPLE_BILL_STATUS_BILL_DATE
```

```sql
-- ✅ 复合索引：条件顺序与索引列顺序一致
SELECT ID, NO, STATUS, BILL_DATE
FROM EXAMPLE_BILL
WHERE STATUS = 1                -- 索引前置列
  AND BILL_DATE >= '2024-01-01 00:00:00';

-- ❌ 错误：跳过前置列 STATUS 直接查 BILL_DATE，复合索引失效
SELECT ID, NO, STATUS, BILL_DATE
FROM EXAMPLE_BILL
WHERE BILL_DATE >= '2024-01-01 00:00:00';
```

> **⚠️ 最左前缀原则**：复合索引 `(STATUS, BILL_DATE)` 只有在条件包含前置列 `STATUS` 时才能生效。可通过 `EXPLAIN` 查看 `key` 字段确认是否走索引。

---

## 七、INSERT 查询规范（基于映射）

### 7.1 完整 INSERT（含 DataEntity 默认字段）

```sql
INSERT INTO EXAMPLE_BILL (
    -- DataEntity 默认字段（必填）
    ID, SYNC_ID, CREATE_BY, CREATE_DATE, UPDATE_BY, UPDATE_DATE,
    INV_ORG_ID, IS_PHANTOM,
    -- 业务字段
    NO, STATUS, AMOUNT, BILL_DATE,
    -- IRefIdProperty 外键字段
    WORK_ORDER_ID, MATERIAL_ID
) VALUES (
    100001, 1,                                   -- Id → BIGINT, SyncId → BIGINT
    1001, NOW(),                                 -- CreateBy → BIGINT, CreateDate → DATETIME
    1001, NOW(),                                 -- UpdateBy → BIGINT, UpdateDate → DATETIME
    101, 0,                                      -- InvOrgId → INT, IsPhantom → TINYINT(1)
    'BILL20240001', 0, 1000,                    -- No → VARCHAR(80), Status → INT, Amount → DECIMAL(18,6)
    NOW(),                                       -- BillDate → DATETIME
    200001, 300001                               -- WorkOrderId → BIGINT, MaterialId → BIGINT
);
```

> **⚠️ ID 取值说明**：MySQL 若采用 `AUTO_INCREMENT` 自增主键，INSERT 时**不写入 ID 列**，由数据库自动生成；若沿用框架"显式序列"习惯（与 MSSQL/Oracle 规范一致），则需先 `SELECT 序列值` 再写入。MySQL 8.0 用 `AUTO_INCREMENT` 即可，无需额外序列对象。

### 7.2 DECIMAL 类型 INSERT

```sql
-- MySQL 自动补齐小数位
INSERT INTO EXAMPLE_BILL (ID, SYNC_ID, ... AMOUNT ...)
VALUES (100002, 2, ... 1000 ...);
```

---

## 八、从 C# 到 SQL 的快速查询映射表

### 8.1 条件查询映射

| C# 表达式 | SQL 条件 | 说明 |
|-----------|----------|------|
| `x.Id == 100001` | `ID = 100001` | `long` → `BIGINT` |
| `x.Status == BillStatus.Approved` | `STATUS = 1` | `enum` → `INT` |
| `x.Status >= BillStatus.Approved` | `STATUS >= 1` | 枚举比较 → 数字比较 |
| `x.Amount > 0` | `AMOUNT > 0` | `decimal` → `DECIMAL(18,6)` |
| `x.IsPhantom == false` | `IS_PHANTOM = 0` | `bool` → `TINYINT(1)` |
| `x.IsPhantom == true` | `IS_PHANTOM = 1` | `bool` → `TINYINT(1)` |
| `x.CreateDate >= startDate` | `CREATE_DATE >= '2024-01-01 00:00:00'` | `DateTime` → `DATETIME` |
| `x.WorkOrder == null` | `WORK_ORDER_ID IS NULL` | `IRefIdProperty` 是否引用 |
| `x.No.Contains("2024")` | `NO LIKE '%2024%'` | `string` → `VARCHAR` |
| `x.No.StartsWith("BILL")` | `NO LIKE 'BILL%'` | `string` → `VARCHAR` |
| `ids.Contains(x.Id)` | `ID IN (...)` | `long` 集合 → `BIGINT` 列表 |

### 8.2 排序映射

| C# 表达式 | SQL | 说明 |
|-----------|-----|------|
| `OrderByDescending(x => x.Id)` | `ORDER BY ID DESC` | 主键降序（最常用） |
| `ThenBy(x => x.Status)` | `ORDER BY ID DESC, STATUS ASC` | 多字段排序 |
| `OrderBy(x => x.CreateDate)` | `ORDER BY CREATE_DATE ASC` | 日期升序 |

### 8.3 SELECT 字段映射

| C# 实体字段 | SQL 列 | 类型映射 |
|------------|--------|---------|
| `Id` | `ID` | `long` → `BIGINT` |
| `SyncId` | `SYNC_ID` | `long` → `BIGINT` |
| `No` | `NO` | `string` → `VARCHAR(80)` |
| `Status` | `STATUS` | `enum` → `INT` |
| `Amount` | `AMOUNT` | `decimal` → `DECIMAL(18,6)` |
| `BillDate` | `BILL_DATE` | `DateTime` → `DATETIME` |
| `IsPhantom` | `IS_PHANTOM` | `bool` → `TINYINT(1)` |
| `WorkOrder` | `WORK_ORDER_ID` | `IRefIdProperty` → `BIGINT` |
| `CreateDate` | `CREATE_DATE` | `DateTime?` → `DATETIME NULL` |
| `UpdateBy` | `UPDATE_BY` | `long?` → `BIGINT NULL` |

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
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE
FROM EXAMPLE_BILL B
WHERE B.NO = 'BILL20240001'
  AND B.IS_PHANTOM = 0
ORDER BY B.ID DESC;
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
SELECT B.STATUS,                              -- enum → INT
       COUNT(1) AS CNT,
       ROUND(SUM(B.AMOUNT), 2) AS TOTAL       -- decimal → DECIMAL(18,6)
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0                        -- bool → TINYINT(1) = 0
GROUP BY B.STATUS
ORDER BY B.STATUS;
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
SELECT B.NO, B.AMOUNT,
       W.NO AS ORDER_NO,
       M.NAME AS MATERIAL_NAME
FROM EXAMPLE_BILL B
JOIN WORK_ORDER W ON W.ID = B.WORK_ORDER_ID         -- IRefId: WorkOrder
LEFT JOIN MATERIAL M ON M.ID = B.MATERIAL_ID         -- IRefId: Material
WHERE B.IS_PHANTOM = 0                               -- bool → TINYINT(1)
  AND B.STATUS = 1                                    -- BillStatus.Approved → 1
ORDER BY B.ID DESC;
```

### 9.4 限制行数

```sql
-- 限制返回行数（无需分页时使用 LIMIT）
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
ORDER BY B.ID DESC
LIMIT 100;
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
-- 对应的 SQL（LIMIT OFFSET 分页）
SELECT B.ID, B.NO, B.AMOUNT, B.STATUS, B.BILL_DATE
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1
ORDER BY B.ID DESC
LIMIT #{size} OFFSET (#{page} - 1) * #{size};

-- 大数据量时使用游标分页（避免 OFFSET 深翻页性能问题）
SELECT B.ID, B.NO, B.AMOUNT, B.STATUS, B.BILL_DATE
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1
  AND B.ID < #{lastCursorId}     -- 上一页最后一条的 ID
ORDER BY B.ID DESC
LIMIT 20;
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
UPDATE EXAMPLE_BILL
SET STATUS = 1,                    -- enum → INT
    AMOUNT = 1000,                 -- decimal → DECIMAL(18,6)
    UPDATE_BY = 1001,              -- long? → BIGINT
    UPDATE_DATE = NOW()            -- DateTime? → DATETIME
WHERE ID = 100001
  AND IS_PHANTOM = 0;

-- 关联更新：根据子表汇总更新主表（MySQL 使用 UPDATE ... JOIN）
UPDATE EXAMPLE_BILL B
JOIN (
    SELECT BILL_ID, ROUND(SUM(LINE_AMOUNT), 6) AS TOTAL_AMOUNT
    FROM EXAMPLE_BILL_LINE
    GROUP BY BILL_ID
) T ON T.BILL_ID = B.ID
SET B.AMOUNT = T.TOTAL_AMOUNT,
    B.UPDATE_BY = 1001,
    B.UPDATE_DATE = NOW()
WHERE B.ID = 100001
  AND B.IS_PHANTOM = 0;
```

> **⚠️ 关联更新语法差异**：MySQL **不支持** `UPDATE ... FROM 子查询` 语法（MSSQL 支持），必须使用 `UPDATE ... JOIN` 语法（即 `UPDATE 表 JOIN 子查询 ON ... SET ...`）。

---

## 十、常见错误与避坑

### 10.1 类型不匹配

```sql
-- ❌ 错误：NO 是 VARCHAR(80)，传入数字导致隐式类型转换，索引失效
SELECT ID, NO FROM EXAMPLE_BILL WHERE NO = 1001;

-- ✅ 正确：字符串匹配
SELECT ID, NO FROM EXAMPLE_BILL WHERE NO = '1001';
```

### 10.2 布尔值用数字而非字符串

```sql
-- ❌ 错误：IS_PHANTOM 是 TINYINT(1)，不能传字符串
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 'false';

-- ✅ 正确：C# bool → SQL TINYINT(1)，值为 0 或 1
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 0;
```

### 10.3 枚举用数字而非名称

```sql
-- ❌ 错误：STATUS 是 INT，不能传枚举名称
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 'Approved';

-- ✅ 正确：使用 C# 枚举对应的数字值
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 1;
```

### 10.4 DateTime 可空字段判断

```sql
-- ❌ 错误：UpdateDate 是 DateTime?，不能直接用等值判断
SELECT ID, NO FROM EXAMPLE_BILL WHERE UPDATE_DATE = NULL;

-- ✅ 正确：NULL 判断使用 IS NULL
SELECT ID, NO FROM EXAMPLE_BILL WHERE UPDATE_DATE IS NULL;

-- ✅ 正确：判断是否有过更新（C#: x.UpdateDate != null）
SELECT ID, NO FROM EXAMPLE_BILL WHERE UPDATE_DATE IS NOT NULL;
```

### 10.5 字符串转义

```sql
-- ❌ 错误：字符串内含单引号时未转义，语法错误
SELECT ID, NO FROM EXAMPLE_BILL WHERE NO = 'BILL'2024';

-- ✅ 正确：单引号用反斜杠转义或双写
SELECT ID, NO FROM EXAMPLE_BILL WHERE NO = 'BILL''2024';
```

### 10.6 保留字与标识符

```sql
-- ❌ 错误：NO 在 SQL Server / Oracle 中是保留字习惯，MySQL 中 NO 不是保留字，
--     但 STATUS、RANK、GROUP 等是 MySQL 保留字，不加反引号会报语法错误
SELECT ID, STATUS FROM EXAMPLE_BILL;

-- ✅ 正确：使用反引号包裹可能冲突的标识符
SELECT ID, `STATUS` FROM `EXAMPLE_BILL`;
```

### 10.7 NULL 处理使用 IFNULL / COALESCE

```sql
-- ❌ 错误：可空字段直接参与运算可能产生 NULL
SELECT ID, NO, AMOUNT * QTY AS LINE_TOTAL
FROM EXAMPLE_BILL_LINE;

-- ✅ 正确：使用 IFNULL 将 NULL 转为默认值
SELECT ID, NO,
       IFNULL(AMOUNT, 0) * IFNULL(QTY, 0) AS LINE_TOTAL
FROM EXAMPLE_BILL_LINE;

-- ✅ COALESCE 支持多个备选值
SELECT ID,
       COALESCE(REMARK, NO, '无备注') AS DISPLAY_TEXT
FROM EXAMPLE_BILL;
```

### 10.8 FLOAT/DOUBLE 等值比较

```sql
-- ❌ 错误：DOUBLE 是近似浮点，等值比较不可靠
SELECT ID, NO FROM EXAMPLE_BILL WHERE QTY_DOUBLE = 0.3;

-- ✅ 正确：使用 ABS 范围比较（注意 MySQL 中 ABS 不是函数式语法，用 ABS(col - 0.3) < 1e-9）
SELECT ID, NO FROM EXAMPLE_BILL WHERE ABS(QTY_DOUBLE - 0.3) < 1e-9;
```

---

## 十一、查询语句格式约定

### 11.1 关键字大小写

```sql
-- 关键字统一大写，字段名/表名与建表一致（大写）
SELECT B.ID,
       B.NO,
       B.STATUS,
       B.AMOUNT
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1
ORDER BY B.ID DESC;
```

### 11.2 注释标注实体类型

```sql
-- 查询 EXAMPLE_BILL 表（对应 ExampleBill 实体）
SELECT B.ID,                     -- DataEntity.Id
       B.NO,                     -- 业务字段
       B.STATUS,                 -- 业务字段（BillStatus 枚举 → INT）
       B.AMOUNT,                 -- 业务字段（decimal → DECIMAL(18,6)）
       B.BILL_DATE               -- 业务字段（DateTime → DATETIME）
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1;
```

### 11.3 参数命名规范

```csharp
// C# 中参数化查询的命名规范
// 属性名 → ?PropertyName 格式（MySqlConnector）
// 或 @PropertyName 格式（ADO.NET MySqlClient 旧版）
```

```sql
-- 使用命名参数，与 C# 属性名对应（MySqlConnector 使用 ? 前缀）
SELECT ID, NO, STATUS
FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0
  AND NO = ?No                -- 对应 string No
  AND STATUS = ?Status        -- 对应 enum Status
  AND BILL_DATE >= ?StartDate -- 对应 DateTime StartDate
  AND BILL_DATE < ?EndDate;   -- 对应 DateTime EndDate
```

---

## 十二、MySQL 与 MSSQL / Oracle 查询差异速查

| 场景 | Oracle | SQL Server | MySQL |
|------|--------|------------|-------|
| 当前时间 | `SYSDATE` | `GETDATE()` | `NOW()` |
| 主键生成 | `SEQ_ID.NEXTVAL` | `NEXT VALUE FOR [dbo].[SEQ_ID]` | `AUTO_INCREMENT`（或先取序列值再 INSERT） |
| 字符串前缀 | `'string'` | `N'string'`（Unicode） | `'string'`（无前缀，库/列字符集决定） |
| 分页 | `OFFSET n ROWS FETCH NEXT m ROWS ONLY` | `OFFSET n ROWS FETCH NEXT m ROWS ONLY` | `LIMIT m OFFSET n` |
| 限制行数 | `FETCH FIRST n ROWS ONLY` | `TOP n` | `LIMIT n` |
| NVL / COALESCE | `NVL(col, 0)` | `ISNULL(col, 0)` / `COALESCE(col, 0)` | `IFNULL(col, 0)` / `COALESCE(col, 0)` |
| 标识符引用 | 大写字段名 | `[方括号]` | 反引号 `` ` ``（必要时） |
| 模式前缀 | 无（或用户名） | `[dbo]` | 库名（`库名.表名`） |
| 日期字面量 | `DATE '2024-01-01'` 或 `TO_DATE` | `'2024-01-01'` 字符串自动转换 | `'2024-01-01 00:00:00'` 字符串字面量 |
| 日期格式化 | `TO_CHAR(date, 'fmt')` | `CONVERT(varchar, date, style)` / `FORMAT()` | `DATE_FORMAT(date, '%Y-%m-%d')` |
| 类型转换 | `TO_NUMBER`、`TO_CHAR` | `CAST`、`CONVERT` | `CAST`、`CONVERT` |
| 可空字段排序 | `NULLS FIRST / LAST` | 默认 NULL 最小 | 默认 NULL 最小（可用 `ISNULL(col, ...)` 控制） |
| 列注释 | `COMMENT ON COLUMN` | `sp_addextendedproperty` | 建表时 `COMMENT '...'` 或 `ALTER TABLE ... MODIFY ... COMMENT '...'` |
| 关联更新 | `UPDATE ... SET (col) = (子查询)` | `UPDATE ... FROM 子查询` | `UPDATE ... JOIN 子查询` |
| 布尔类型 | `NUMBER(1,0)` | `BIT` | `TINYINT(1)` |
| 字符串类型 | `VARCHAR2(n)` | `NVARCHAR(n)` | `VARCHAR(n)` |
| 空字符串处理 | `''` 视为 `NULL` | `''` ≠ `NULL` | `''` ≠ `NULL`（但 `''` 可存入 VARCHAR） |

---

## 十三、附则

1. **SELECT 字段顺序**：业务字段在前，DataEntity 基类字段在后。例如 `NO, STATUS, AMOUNT, CREATE_DATE` 在前，`IS_PHANTOM, SYNC_ID` 在后。
2. **关键字大写**：`SELECT`、`FROM`、`WHERE`、`JOIN`、`AND`、`OR`、`ORDER BY` 等关键字统一大写。
3. **表名/字段名大写**：与建表规范一致，所有表名和字段名大写。
4. **参数占位符**：MySqlConnector 使用 `?paramName` 格式（ADO.NET MySqlClient 旧版用 `@paramName`），参数名与 C# 属性名对应。
5. **每次查询必须带 IS_PHANTOM = 0**（除非有明确需求查询逻辑删除数据）。
6. **外键字段按需选择 JOIN 类型**：非空外键用 `JOIN`，可空外键用 `LEFT JOIN`。
7. **分页必须带 ORDER BY**：确保结果顺序一致。
8. **字符串常量不加 N 前缀**：MySQL 无 Unicode 前缀语法（区别于 MSSQL 的 `N'...'`），字符集由库/列定义决定，乱码先检查库表字符集（`utf8mb4`）。
9. **字符串字面量转义**：内部单引号双写（`''`）或反斜杠转义，参数化查询优先。
10. **避免函数包裹索引列**：如 `WHERE DATE(BILL_DATE) = '2024-06-17'` 会使索引失效，应使用半开区间 `>= '2024-06-17 00:00:00' AND < '2024-06-18 00:00:00'`。
