> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：POSTGRESQL____.md
> **优先级**：高。
> **覆盖范围**：PostgreSQL查询规范·C#实体->SQL类型映射·JOIN·枚举·分页·避坑

---

# PostgreSQL 查询规范（基于实体映射）

## 一、C# 实体与 PostgreSQL 表结构映射关系

### 1.1 DataEntity 基类继承体系

所有业务实体继承自 `DataEntity`，对应 SQL 查询中每个表的公共字段集。

```csharp
// C# 基类（框架提供）
public class DataEntity
{
    public long Id { get; set; }              // → ID BIGINT NOT NULL PK
    public long SyncId { get; set; }          // → SYNC_ID BIGINT NOT NULL
    public long? CreateBy { get; set; }       // → CREATE_BY BIGINT NULL
    public DateTime? CreateDate { get; set; } // → CREATE_DATE TIMESTAMP NULL
    public long? UpdateBy { get; set; }       // → UPDATE_BY BIGINT NULL
    public DateTime? UpdateDate { get; set; } // → UPDATE_DATE TIMESTAMP NULL
    public int? InvOrgId { get; set; }        // → INV_ORG_ID INT NULL
    public bool IsPhantom { get; set; }       // → IS_PHANTOM BOOLEAN NOT NULL DEFAULT FALSE
}
```

```sql
-- 查询时必须理解的默认字段映射
SELECT B.ID,              -- long → BIGINT
       B.SYNC_ID,          -- long → BIGINT
       B.CREATE_BY,        -- long? → BIGINT NULL
       B.CREATE_DATE,      -- DateTime? → TIMESTAMP NULL
       B.UPDATE_BY,        -- long? → BIGINT NULL
       B.UPDATE_DATE,      -- DateTime? → TIMESTAMP NULL
       B.INV_ORG_ID,       -- int? → INT NULL
       B.IS_PHANTOM        -- bool → BOOLEAN DEFAULT FALSE
FROM example_bill B;
```

> **⚠️ 未加引号标识符折叠为小写**：PostgreSQL 默认将未加双引号的标识符（表名/列名）折叠为**小写**。若建表时按 SMOM 惯例使用大写列名（如 `CREATE TABLE "EXAMPLE_BILL"`），则查询时必须**始终用双引号**包裹；若建表时用未加引号的小写形式，则查询一律写小写。**两种风格必须与建表脚本完全一致**（见 `references/17-postgresql-table.md`）。

### 1.2 属性类型 → PostgreSQL 数据类型映射

| C# 类型 | PostgreSQL 类型 | 查询注意事项 |
|---------|-----------------|-------------|
| `long` / `long?` | `BIGINT` | 精确整数，直接等值匹配 |
| `int` / `int?` / `enum` | `INT`（`INTEGER`） | 枚举值查询直接用数字 |
| `float` / `double` | `DOUBLE PRECISION` | 近似浮点，避免等值比较 |
| `decimal` | `NUMERIC(18,6)` | **保留6位小数**，精确数值 |
| `bool` | `BOOLEAN` | 值为 `TRUE` / `FALSE` |
| `DateTime` / `DateTime?` | `TIMESTAMP` | 精确到微秒，查询用字符串字面量 |
| `string` | `VARCHAR` | 字符串匹配注意引号与 `ILIKE` |
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
FROM example_bill B;
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
SELECT ID, NO FROM example_bill WHERE ID = 100001;

-- ✅ UPDATE_BY 可空，用 IS NULL 判断
SELECT ID, NO FROM example_bill WHERE UPDATE_BY IS NULL;

-- ✅ 批量查询（注意：IN 列表不得超过 1000 项，超过应改用分批查询或 ANY 数组）
SELECT ID, NO FROM example_bill WHERE ID IN (100001, 100002, 100003);

-- ✅ 大集合可用数组 ANY 代替超长 IN
SELECT ID, NO FROM example_bill WHERE ID = ANY (ARRAY[100001, 100002, 100003]);
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
SELECT ID, NO, STATUS FROM example_bill WHERE STATUS = 0;       -- Draft
SELECT ID, NO, STATUS FROM example_bill WHERE STATUS = 1;       -- Approved
SELECT ID, NO, STATUS FROM example_bill WHERE STATUS IN (1, 2); -- Approved + Paid

-- ✅ 枚举范围判断
SELECT ID, NO, STATUS FROM example_bill WHERE STATUS >= 1;
```

### 2.3 BOOLEAN 对应 bool —— TRUE / FALSE 判断

```csharp
// C# 实体
public bool IsPhantom { get; set; }  // → IS_PHANTOM BOOLEAN DEFAULT FALSE
```

```sql
-- ✅ 查询有效数据（IsPhantom = false → FALSE）
SELECT ID, NO FROM example_bill WHERE IS_PHANTOM = FALSE;

-- ✅ 查询已删除数据（IsPhantom = true → TRUE）
SELECT ID, NO FROM example_bill WHERE IS_PHANTOM = TRUE;
```

### 2.4 NUMERIC(18,6) 对应 decimal —— 注意精度

```csharp
// C# 实体
public decimal Amount { get; set; }       // → AMOUNT NUMERIC(18,6)
public decimal? Qty { get; set; }         // → QTY NUMERIC(18,6) NULL
```

```sql
-- ✅ 查询时保持小数精度
SELECT ID, NO, AMOUNT FROM example_bill WHERE AMOUNT > 0;

-- ✅ 求和时使用 ROUND 控制小数位
SELECT ROUND(SUM(AMOUNT), 2) AS TOTAL_AMOUNT FROM example_bill;

-- ✅ 格式化输出（TO_CHAR 需要数字格式串）
SELECT ID, NO, TO_CHAR(AMOUNT, 'FM999999999999.00') AS AMOUNT_STR
FROM example_bill;
```

### 2.5 TIMESTAMP 对应 DateTime —— 日期范围查询

```csharp
// C# 实体
public DateTime CreateDate { get; set; }       // → CREATE_DATE TIMESTAMP NOT NULL
public DateTime? UpdateDate { get; set; }      // → UPDATE_DATE TIMESTAMP NULL
public DateTime BillDate { get; set; }         // → BILL_DATE TIMESTAMP
```

```sql
-- ✅ DateTime 范围查询（PostgreSQL 接受 'YYYY-MM-DD HH:MM:SS' 字符串字面量）
SELECT ID, NO, CREATE_DATE
FROM example_bill
WHERE CREATE_DATE >= '2024-06-01 00:00:00'
  AND CREATE_DATE < '2024-07-01 00:00:00';

-- ✅ 可空的 UpdateDate
SELECT ID, NO, UPDATE_DATE
FROM example_bill
WHERE UPDATE_DATE IS NOT NULL;

-- ✅ 精确到日的查询（半开区间）
SELECT ID, NO, BILL_DATE
FROM example_bill
WHERE BILL_DATE >= '2024-06-17 00:00:00'
  AND BILL_DATE < '2024-06-18 00:00:00';

-- ✅ 使用 TO_CHAR 格式化日期输出
SELECT ID, NO,
       TO_CHAR(BILL_DATE, 'YYYY-MM-DD') AS BILL_DATE_STR
FROM example_bill;
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
    public decimal Amount { get; set; }         // → AMOUNT NUMERIC(18,6)
    public DateTime BillDate { get; set; }      // → BILL_DATE TIMESTAMP
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
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE    -- 默认过滤逻辑删除数据
ORDER BY B.ID DESC;

-- 列表查询时只需返回需要的字段，无需每次都查全 12 列
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE
ORDER BY B.ID DESC;
```

### 3.2 列表查询（过滤逻辑删除 + 状态）

```sql
-- 所有列表查询统一格式
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE      -- 必有：过滤逻辑删除
  AND B.STATUS = 1              -- 按状态过滤
ORDER BY B.ID DESC;
```

### 3.3 详情查询

```sql
-- 单条记录查询
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT, B.BILL_DATE,
       B.CREATE_BY, B.CREATE_DATE,
       B.UPDATE_BY, B.UPDATE_DATE
FROM example_bill B
WHERE B.ID = 100001
  AND B.IS_PHANTOM = FALSE;
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
UPDATE example_bill
SET IS_PHANTOM = TRUE,           -- bool → BOOLEAN = TRUE
    UPDATE_BY = 1001,            -- long? → BIGINT
    UPDATE_DATE = NOW()          -- DateTime? → TIMESTAMP
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
FROM example_bill B
LEFT JOIN work_order W ON W.ID = B.WORK_ORDER_ID    -- IRefId: WorkOrder
LEFT JOIN material M   ON M.ID = B.MATERIAL_ID      -- IRefId: Material
LEFT JOIN sys_user U   ON U.ID = B.CREATE_BY        -- IRefId: CreateByUser
WHERE B.IS_PHANTOM = FALSE
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
FROM example_bill B
WHERE B.WORK_ORDER_ID IS NULL;      -- WorkOrder 未引用

SELECT B.ID, B.NO
FROM example_bill B
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
FROM example_bill
WHERE IS_PHANTOM = FALSE
  AND STATUS = 0;          -- BillStatus.Draft → 0

SELECT ID, NO, STATUS
FROM example_bill
WHERE IS_PHANTOM = FALSE
  AND STATUS IN (1, 2);    -- BillStatus.Approved + BillStatus.Paid
```

### 5.2 CHECK 约束与查询一致性

```sql
-- 建表时定义的 CHECK 约束（PostgreSQL 原生强制校验）
ALTER TABLE example_bill
ADD CONSTRAINT chk_example_bill_status
CHECK (STATUS IN (0, 1, 2, 9));

-- 查询时必须使用 CHECK 约束范围内的值
SELECT ID, NO FROM example_bill WHERE STATUS = 0;   -- ✅ 草稿
SELECT ID, NO FROM example_bill WHERE STATUS = 1;   -- ✅ 已审核
SELECT ID, NO FROM example_bill WHERE STATUS = 2;   -- ✅ 已付款
SELECT ID, NO FROM example_bill WHERE STATUS = 9;   -- ✅ 已作废
```

> **CHECK 约束**：PostgreSQL 的 CHECK 约束原生强制生效（MySQL 需 8.0.16+），是数据库层枚举合法性的可靠保证；SMOM 代码中仍以 C# 枚举 + 实体验证规则为准。

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

-- 单据号查询（走 ix_example_bill_no）
SELECT ID, NO, STATUS FROM example_bill
WHERE IS_PHANTOM = FALSE AND NO = 'BILL20240001';

-- 状态批量查询（走 ix_example_bill_status）
SELECT ID, NO, STATUS FROM example_bill
WHERE IS_PHANTOM = FALSE AND STATUS = 1;

-- 外键关联查询（走 ix_example_bill_work_order）
SELECT ID, NO, WORK_ORDER_ID FROM example_bill
WHERE IS_PHANTOM = FALSE AND WORK_ORDER_ID = 100001;

-- ⚠️ 注意：所有 IRefIdProperty 外键字段（如 WORK_ORDER_ID、MATERIAL_ID）
-- 必须在关联表上创建对应索引，否则 JOIN 查询时驱动表会走全表扫描
```

### 6.2 复合索引查询顺序

如果实体配置了复合索引，查询条件顺序应与索引列顺序一致（最左前缀原则）。

```csharp
// 假设 HasIndex(x => new { x.Status, x.BillDate })
// → IX_TABLE_NAME_STATUS_BILL_DATE
```

```sql
-- ✅ 复合索引：条件顺序与索引列顺序一致
SELECT ID, NO, STATUS, BILL_DATE
FROM example_bill
WHERE STATUS = 1                -- 索引前置列
  AND BILL_DATE >= '2024-01-01 00:00:00';

-- ❌ 错误：跳过前置列 STATUS 直接查 BILL_DATE，复合索引失效
SELECT ID, NO, STATUS, BILL_DATE
FROM example_bill
WHERE BILL_DATE >= '2024-01-01 00:00:00';
```

> **⚠️ 最左前缀原则**：复合索引 `(STATUS, BILL_DATE)` 只有在条件包含前置列 `STATUS` 时才能生效。可通过 `EXPLAIN` 查看 `Seq Scan`（全表扫描）确认是否走索引。

### 6.3 模糊查询用 ILIKE（不区分大小写）

```sql
-- ❌ 错误：NO 是 VARCHAR(80)，NO LIKE 区分大小写，且 '%' 开头会导致索引失效
SELECT ID, NO FROM example_bill WHERE NO LIKE '%bill%';

-- ✅ 正确：不区分大小写模糊匹配用 ILIKE（注意 '%' 开头仍不走常规 B-tree 索引）
SELECT ID, NO FROM example_bill WHERE NO ILIKE '%bill%';

-- ✅ 需要高效模糊搜索时，对字段建 pg_trgm GIN 索引：
--   CREATE EXTENSION IF NOT EXISTS pg_trgm;
--   CREATE INDEX ix_example_bill_no_trgm ON example_bill USING gin (NO gin_trgm_ops);
```

---

## 七、INSERT 查询规范（基于映射）

### 7.1 完整 INSERT（含 DataEntity 默认字段）

```sql
INSERT INTO example_bill (
    -- DataEntity 默认字段（必填）
    ID, SYNC_ID, CREATE_BY, CREATE_DATE, UPDATE_BY, UPDATE_DATE,
    INV_ORG_ID, IS_PHANTOM,
    -- 业务字段
    NO, STATUS, AMOUNT, BILL_DATE,
    -- IRefIdProperty 外键字段
    WORK_ORDER_ID, MATERIAL_ID
) VALUES (
    100001, 1,                                   -- Id → BIGINT, SyncId → BIGINT
    1001, NOW(),                                 -- CreateBy → BIGINT, CreateDate → TIMESTAMP
    1001, NOW(),                                 -- UpdateBy → BIGINT, UpdateDate → TIMESTAMP
    101, FALSE,                                  -- InvOrgId → INT, IsPhantom → BOOLEAN
    'BILL20240001', 0, 1000,                    -- No → VARCHAR(80), Status → INT, Amount → NUMERIC(18,6)
    NOW(),                                       -- BillDate → TIMESTAMP
    200001, 300001                               -- WorkOrderId → BIGINT, MaterialId → BIGINT
);
```

> **⚠️ ID 取值说明**：PostgreSQL 若采用 `GENERATED BY DEFAULT AS IDENTITY` 或 `SERIAL` 自增主键，INSERT 时**不写入 ID 列**，由数据库自动生成；若沿用框架"显式序列"习惯（与 MSSQL/Oracle 规范一致），则使用 `nextval('seq_example_bill_id')` 或 `nextval('example_bill_id_seq')` 显式取值。PostgreSQL 序列默认命名 `表名_列名_seq`，也可自定义。

### 7.2 显式序列取值方式（与 MSSQL/Oracle 规范一致时）

```sql
-- 方式一：GENERATED BY DEFAULT AS IDENTITY（推荐，10+）
--   插入时省略 ID 列，数据库自动生成；需要显式值时也可写入（不报错）

-- 方式二：自定义序列 + nextval
CREATE SEQUENCE seq_example_bill_id START WITH 100000;
CREATE SEQUENCE seq_example_bill_sync_id START WITH 1;

INSERT INTO example_bill (ID, SYNC_ID, ...)
VALUES (nextval('seq_example_bill_id'), nextval('seq_example_bill_sync_id'), ...);

-- 方式三：SERIAL 伪类型（旧写法，默认序列名 表名_列名_seq）
INSERT INTO example_bill (SYNC_ID, ...)   -- 省略 ID，自动生成
VALUES (1, ...);
```

---

## 八、从 C# 到 SQL 的快速查询映射表

### 8.1 条件查询映射

| C# 表达式 | SQL 条件 | 说明 |
|-----------|----------|------|
| `x.Id == 100001` | `ID = 100001` | `long` → `BIGINT` |
| `x.Status == BillStatus.Approved` | `STATUS = 1` | `enum` → `INT` |
| `x.Status >= BillStatus.Approved` | `STATUS >= 1` | 枚举比较 → 数字比较 |
| `x.Amount > 0` | `AMOUNT > 0` | `decimal` → `NUMERIC(18,6)` |
| `x.IsPhantom == false` | `IS_PHANTOM = FALSE` | `bool` → `BOOLEAN` |
| `x.IsPhantom == true` | `IS_PHANTOM = TRUE` | `bool` → `BOOLEAN` |
| `x.CreateDate >= startDate` | `CREATE_DATE >= '2024-01-01 00:00:00'` | `DateTime` → `TIMESTAMP` |
| `x.WorkOrder == null` | `WORK_ORDER_ID IS NULL` | `IRefIdProperty` 是否引用 |
| `x.No.Contains("2024")` | `NO LIKE '%2024%'` | `string` → `VARCHAR` |
| `x.No.Contains("2024")`（不区分大小写） | `NO ILIKE '%2024%'` | 模糊匹配忽略大小写 |
| `x.No.StartsWith("BILL")` | `NO LIKE 'BILL%'` | `string` → `VARCHAR` |
| `ids.Contains(x.Id)` | `ID IN (...)` / `ID = ANY (ARRAY[...])` | `long` 集合 → `BIGINT` 列表 |

### 8.2 排序映射

| C# 表达式 | SQL | 说明 |
|-----------|-----|------|
| `OrderByDescending(x => x.Id)` | `ORDER BY ID DESC` | 主键降序（最常用） |
| `ThenBy(x => x.Status)` | `ORDER BY ID DESC, STATUS ASC` | 多字段排序 |
| `OrderBy(x => x.CreateDate)` | `ORDER BY CREATE_DATE ASC` | 日期升序 |
| 可空字段排序控制 | `ORDER BY UPDATE_DATE NULLS LAST` | PostgreSQL 原生支持 `NULLS FIRST / LAST` |

### 8.3 SELECT 字段映射

| C# 实体字段 | SQL 列 | 类型映射 |
|------------|--------|---------|
| `Id` | `ID` | `long` → `BIGINT` |
| `SyncId` | `SYNC_ID` | `long` → `BIGINT` |
| `No` | `NO` | `string` → `VARCHAR(80)` |
| `Status` | `STATUS` | `enum` → `INT` |
| `Amount` | `AMOUNT` | `decimal` → `NUMERIC(18,6)` |
| `BillDate` | `BILL_DATE` | `DateTime` → `TIMESTAMP` |
| `IsPhantom` | `IS_PHANTOM` | `bool` → `BOOLEAN` |
| `WorkOrder` | `WORK_ORDER_ID` | `IRefIdProperty` → `BIGINT` |
| `CreateDate` | `CREATE_DATE` | `DateTime?` → `TIMESTAMP NULL` |
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
FROM example_bill B
WHERE B.NO = 'BILL20240001'
  AND B.IS_PHANTOM = FALSE
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
       ROUND(SUM(B.AMOUNT), 2) AS TOTAL       -- decimal → NUMERIC(18,6)
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE                    -- bool → BOOLEAN = FALSE
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
FROM example_bill B
JOIN work_order W ON W.ID = B.WORK_ORDER_ID         -- IRefId: WorkOrder
LEFT JOIN material M ON M.ID = B.MATERIAL_ID         -- IRefId: Material
WHERE B.IS_PHANTOM = FALSE                           -- bool → BOOLEAN
  AND B.STATUS = 1                                    -- BillStatus.Approved → 1
ORDER BY B.ID DESC;
```

### 9.4 限制行数

```sql
-- 限制返回行数（无需分页时使用 LIMIT）
SELECT B.ID, B.NO, B.STATUS, B.AMOUNT
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE
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
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE
  AND B.STATUS = 1
ORDER BY B.ID DESC
LIMIT #{size} OFFSET (#{page} - 1) * #{size};

-- 大数据量时使用游标分页（避免 OFFSET 深翻页性能问题）
SELECT B.ID, B.NO, B.AMOUNT, B.STATUS, B.BILL_DATE
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE
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
UPDATE example_bill
SET STATUS = 1,                    -- enum → INT
    AMOUNT = 1000,                 -- decimal → NUMERIC(18,6)
    UPDATE_BY = 1001,              -- long? → BIGINT
    UPDATE_DATE = NOW()            -- DateTime? → TIMESTAMP
WHERE ID = 100001
  AND IS_PHANTOM = FALSE;

-- 关联更新：根据子表汇总更新主表（PostgreSQL 使用 UPDATE ... FROM）
UPDATE example_bill B
SET AMOUNT = T.TOTAL_AMOUNT,
    UPDATE_BY = 1001,
    UPDATE_DATE = NOW()
FROM (
    SELECT BILL_ID, ROUND(SUM(LINE_AMOUNT), 6) AS TOTAL_AMOUNT
    FROM example_bill_line
    GROUP BY BILL_ID
) T
WHERE T.BILL_ID = B.ID
  AND B.ID = 100001
  AND B.IS_PHANTOM = FALSE;
```

> **⚠️ 关联更新语法差异**：PostgreSQL **不支持** MSSQL 的 `UPDATE ... FROM 子查询` 中的子查询直接跟随 FROM 的写法，必须将子查询放入 `FROM` 子句并加别名（`UPDATE 表 SET ... FROM (子查询) T WHERE T.关联列 = 表.列`）；也不同于 MySQL 的 `UPDATE ... JOIN` 语法。

---

## 十、常见错误与避坑

### 10.1 类型不匹配

```sql
-- ❌ 错误：NO 是 VARCHAR(80)，传入数字导致隐式类型转换，索引失效
SELECT ID, NO FROM example_bill WHERE NO = 1001;

-- ✅ 正确：字符串匹配
SELECT ID, NO FROM example_bill WHERE NO = '1001';
```

### 10.2 布尔值用 TRUE / FALSE 而非 0 / 1

```sql
-- ❌ 错误：IS_PHANTOM 是 BOOLEAN，不能传数字 0/1（PostgreSQL 不隐式转换）
SELECT ID, NO FROM example_bill WHERE IS_PHANTOM = 0;

-- ✅ 正确：C# bool → SQL BOOLEAN，值为 TRUE / FALSE
SELECT ID, NO FROM example_bill WHERE IS_PHANTOM = FALSE;
```

### 10.3 枚举用数字而非名称

```sql
-- ❌ 错误：STATUS 是 INT，不能传枚举名称
SELECT ID, NO FROM example_bill WHERE STATUS = 'Approved';

-- ✅ 正确：使用 C# 枚举对应的数字值
SELECT ID, NO FROM example_bill WHERE STATUS = 1;
```

### 10.4 DateTime 可空字段判断

```sql
-- ❌ 错误：UpdateDate 是 DateTime?，不能直接用等值判断
SELECT ID, NO FROM example_bill WHERE UPDATE_DATE = NULL;

-- ✅ 正确：NULL 判断使用 IS NULL
SELECT ID, NO FROM example_bill WHERE UPDATE_DATE IS NULL;

-- ✅ 正确：判断是否有过更新（C#: x.UpdateDate != null）
SELECT ID, NO FROM example_bill WHERE UPDATE_DATE IS NOT NULL;
```

### 10.5 字符串转义

```sql
-- ❌ 错误：字符串内含单引号时未转义，语法错误
SELECT ID, NO FROM example_bill WHERE NO = 'BILL'2024';

-- ✅ 正确：单引号双写转义（PostgreSQL 标准），E'' 前缀用反斜杠转义
SELECT ID, NO FROM example_bill WHERE NO = 'BILL''2024';
```

### 10.6 标识符大小写折叠

```sql
-- ❌ 错误：未加引号的标识符折叠为小写，若建表时用了双引号大写列名则报"列不存在"
SELECT ID, "STATUS" FROM example_bill;   -- 与建表风格不一致时报错

-- ✅ 正确：与建表风格完全一致
--   建表用未加引号（小写）：SELECT ID, STATUS FROM example_bill;
--   建表用双引号（大写）：  SELECT ID, "STATUS" FROM "EXAMPLE_BILL";
```

### 10.7 NULL 处理使用 COALESCE / NULLIF

```sql
-- ❌ 错误：可空字段直接参与运算可能产生 NULL
SELECT ID, NO, AMOUNT * QTY AS LINE_TOTAL
FROM example_bill_line;

-- ✅ 正确：使用 COALESCE 将 NULL 转为默认值（PostgreSQL 无 IFNULL，用 COALESCE）
SELECT ID, NO,
       COALESCE(AMOUNT, 0) * COALESCE(QTY, 0) AS LINE_TOTAL
FROM example_bill_line;

-- ✅ COALESCE 支持多个备选值
SELECT ID,
       COALESCE(REMARK, NO, '无备注') AS DISPLAY_TEXT
FROM example_bill;
```

### 10.8 函数包裹索引列

```sql
-- ❌ 错误：DATE() 包裹索引列导致索引失效
SELECT ID, NO, BILL_DATE FROM example_bill WHERE DATE(BILL_DATE) = '2024-06-17';

-- ✅ 正确：半开区间，走 BILL_DATE 索引
SELECT ID, NO, BILL_DATE
FROM example_bill
WHERE BILL_DATE >= '2024-06-17 00:00:00'
  AND BILL_DATE < '2024-06-18 00:00:00';
```

---

## 十一、查询语句格式约定

### 11.1 关键字大小写

```sql
-- 关键字统一大写，标识符与建表风格一致（以下示例为未加引号小写风格）
SELECT B.ID,
       B.NO,
       B.STATUS,
       B.AMOUNT
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE
  AND B.STATUS = 1
ORDER BY B.ID DESC;
```

### 11.2 注释标注实体类型

```sql
-- 查询 example_bill 表（对应 ExampleBill 实体）
SELECT B.ID,                     -- DataEntity.Id
       B.NO,                     -- 业务字段
       B.STATUS,                 -- 业务字段（BillStatus 枚举 → INT）
       B.AMOUNT,                 -- 业务字段（decimal → NUMERIC(18,6)）
       B.BILL_DATE               -- 业务字段（DateTime → TIMESTAMP）
FROM example_bill B
WHERE B.IS_PHANTOM = FALSE
  AND B.STATUS = 1;
```

### 11.3 参数命名规范

```csharp
// C# 中参数化查询的命名规范
// 属性名 → @PropertyName 格式（Npgsql，与 ADO.NET 一致的 @ 前缀）
```

```sql
-- 使用命名参数，与 C# 属性名对应（Npgsql 使用 @ 前缀）
SELECT ID, NO, STATUS
FROM example_bill
WHERE IS_PHANTOM = FALSE
  AND NO = @No                -- 对应 string No
  AND STATUS = @Status        -- 对应 enum Status
  AND BILL_DATE >= @StartDate -- 对应 DateTime StartDate
  AND BILL_DATE < @EndDate;   -- 对应 DateTime EndDate
```

> **⚠️ 参数前缀注意**：Npgsql（PostgreSQL 的 .NET 驱动）使用 `@param` 前缀（与 MSSQL 一致），与 Oracle 的 `:param`、MySQL MySqlConnector 的 `?param` 不同。

---

## 十二、PostgreSQL 与 MSSQL / Oracle / MySQL 查询差异速查

| 场景 | Oracle | SQL Server | MySQL | PostgreSQL |
|------|--------|------------|-------|------------|
| 当前时间 | `SYSDATE` | `GETDATE()` | `NOW()` | `NOW()` / `CURRENT_TIMESTAMP` |
| 主键生成 | `SEQ_ID.NEXTVAL` | `NEXT VALUE FOR [dbo].[SEQ_ID]` | `AUTO_INCREMENT` | `IDENTITY`（10+）/ `SERIAL` / `nextval('序列')` |
| 字符串前缀 | `'string'` | `N'string'`（Unicode） | `'string'` | `'string'`（无前缀） |
| 分页 | `OFFSET n ROWS FETCH NEXT m ROWS ONLY` | `OFFSET n ROWS FETCH NEXT m ROWS ONLY` | `LIMIT m OFFSET n` | `LIMIT m OFFSET n` |
| 限制行数 | `FETCH FIRST n ROWS ONLY` | `TOP n` | `LIMIT n` | `LIMIT n` |
| NVL / COALESCE | `NVL(col, 0)` | `ISNULL(col, 0)` / `COALESCE(col, 0)` | `IFNULL(col, 0)` / `COALESCE(col, 0)` | `COALESCE(col, 0)`（无 IFNULL） |
| 标识符引用 | 大写字段名 | `[方括号]` | 反引号 `` ` `` | 双引号 `"`（大小写敏感） |
| 模式前缀 | 无（或用户名） | `[dbo]` | 库名（`库名.表名`） | `schema.表名`（默认 `public`） |
| 布尔类型 | `NUMBER(1,0)` | `BIT` | `TINYINT(1)` | `BOOLEAN`（TRUE / FALSE） |
| 字符串类型 | `VARCHAR2(n)` | `NVARCHAR(n)` | `VARCHAR(n)` | `VARCHAR(n)` |
| 日期字面量 | `DATE '2024-01-01'` 或 `TO_DATE` | `'2024-01-01'` 字符串自动转换 | `'2024-01-01 00:00:00'` 字符串字面量 | `'2024-01-01 00:00:00'` 字符串字面量 |
| 日期格式化 | `TO_CHAR(date, 'fmt')` | `CONVERT(varchar, date, style)` / `FORMAT()` | `DATE_FORMAT(date, '%Y-%m-%d')` | `TO_CHAR(date, 'YYYY-MM-DD')` |
| 类型转换 | `TO_NUMBER`、`TO_CHAR` | `CAST`、`CONVERT` | `CAST`、`CONVERT` | `CAST`、`::`（如 `col::BIGINT`） |
| 可空字段排序 | `NULLS FIRST / LAST` | 默认 NULL 最小 | 默认 NULL 最小 | `NULLS FIRST / LAST`（原生支持） |
| 列注释 | `COMMENT ON COLUMN` | `sp_addextendedproperty` | `COMMENT '...'` | `COMMENT ON COLUMN ... IS '...'` |
| 模糊匹配 | `LIKE`（区分大小写） | `LIKE`（区分大小写） | `LIKE`（由 collation 决定） | `LIKE` 区分 / `ILIKE` 不区分 |
| 关联更新 | `UPDATE ... SET (col) = (子查询)` | `UPDATE ... FROM 子查询` | `UPDATE ... JOIN 子查询` | `UPDATE ... FROM (子查询) T WHERE ...` |
| 空字符串处理 | `''` 视为 `NULL` | `''` ≠ `NULL` | `''` ≠ `NULL` | `''` ≠ `NULL` |

---

## 十三、附则

1. **SELECT 字段顺序**：业务字段在前，DataEntity 基类字段在后。例如 `NO, STATUS, AMOUNT, CREATE_DATE` 在前，`IS_PHANTOM, SYNC_ID` 在后。
2. **关键字大写**：`SELECT`、`FROM`、`WHERE`、`JOIN`、`AND`、`OR`、`ORDER BY` 等关键字统一大写。
3. **标识符大小写**：与建表脚本完全一致——建表用未加引号小写则查询写小写；建表用双引号大写则查询始终带双引号。混用会导致 `column does not exist`。
4. **参数占位符**：Npgsql 使用 `@paramName` 格式（与 MSSQL 相同，区别于 Oracle `:param`、MySQL `?param`），参数名与 C# 属性名对应。
5. **每次查询必须带 IS_PHANTOM = FALSE**（除非有明确需求查询逻辑删除数据）。
6. **外键字段按需选择 JOIN 类型**：非空外键用 `JOIN`，可空外键用 `LEFT JOIN`。
7. **分页必须带 ORDER BY**：确保结果顺序一致。
8. **字符串常量不加 N 前缀**：PostgreSQL 无 Unicode 前缀语法（区别于 MSSQL 的 `N'...'`），乱码先检查库字符集（UTF8）。
9. **布尔字段用 TRUE / FALSE**：PostgreSQL 布尔类型不接受 0/1 字面量（区别于 MSSQL `BIT`、MySQL `TINYINT(1)`）。
10. **避免函数包裹索引列**：如 `WHERE DATE(BILL_DATE) = ...` 会使索引失效，应使用半开区间；不区分大小写模糊查询用 `ILIKE` 并考虑 `pg_trgm` 索引。
