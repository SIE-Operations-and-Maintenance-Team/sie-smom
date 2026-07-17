> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：ORACLE____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：ORACLE查询规范·C#实体->SQL类型映射·JOIN·枚举·分页·避坑

---

# Oracle SQL 查询规范（基于实体映射）

## 一、C# 实体与 Oracle 表结构映射关系

### 1.1 DataEntity 基类继承体系

所有业务实体继承自 `DataEntity`，对应 SQL 查询中每个表的公共字段集。

```csharp
// C# 基类（框架提供）
public class DataEntity
{
    public long Id { get; set; }              // → ID NUMBER(18,0) NOT NULL PK
    public long SyncId { get; set; }          // → SYNC_ID NUMBER(18,0) NOT NULL
    public long? CreateBy { get; set; }       // → CREATE_BY NUMBER(18,0)
    public DateTime? CreateDate { get; set; } // → CREATE_DATE DATE
    public long? UpdateBy { get; set; }       // → UPDATE_BY NUMBER(18,0)
    public DateTime? UpdateDate { get; set; } // → UPDATE_DATE DATE
    public int? InvOrgId { get; set; }        // → INV_ORG_ID NUMBER(10,0)
    public bool IsPhantom { get; set; }       // → IS_PHANTOM NUMBER(1,0) DEFAULT 0
}
```

```sql
-- 查询时必须理解的默认字段映射
SELECT B.ID,              -- long → NUMBER(18,0)
       B.SYNC_ID,          -- long → NUMBER(18,0)
       B.CREATE_BY,        -- long? → NUMBER(18,0) NULLABLE
       B.CREATE_DATE,      -- DateTime? → DATE NULLABLE
       B.UPDATE_BY,        -- long? → NUMBER(18,0) NULLABLE
       B.UPDATE_DATE,      -- DateTime? → DATE NULLABLE
       B.INV_ORG_ID,       -- int? → NUMBER(10,0) NULLABLE
       B.IS_PHANTOM        -- bool → NUMBER(1,0) DEFAULT 0
FROM EXAMPLE_BILL B;
```

### 1.2 属性类型 → Oracle 数据类型映射

| C# 类型 | Oracle 类型 | 查询注意事项 |
|---------|-------------|-------------|
| `long` / `long?` | `NUMBER(18,0)` | 精确整数，无需小数处理 |
| `int` / `int?` / `enum` | `NUMBER(10,0)` | 枚举值查询直接用数字 |
| `float` / `double` | `NUMBER(18,0)` | 不含小数位 |
| `decimal` | `NUMBER(18,6)` | **保留6位小数**，查询注意精度 |
| `bool` | `NUMBER(1,0)` | 值为 0 或 1 |
| `DateTime` / `DateTime?` | `DATE` | 精确到秒，查询用 `TO_DATE` / `DATE` |
| `string` | `VARCHAR2` | 字符串匹配注意引号 |
| `IRefIdProperty` | `NUMBER(18,0)` | 外键字段，JOIN 关联使用 |

### 1.3 IRefIdProperty 引用类型映射

```csharp
// C# 实体中的引用属性
public class ExampleBill : DataEntity
{
    // IRefIdProperty 引用类型
    public WorkOrder WorkOrder { get; set; }    // → WORK_ORDER_ID NUMBER(18,0)
    public Material Material { get; set; }      // → MATERIAL_ID NUMBER(18,0)
}
```

```sql
-- 对应的 SQL 外键字段
SELECT B.WORK_ORDER_ID,    -- NUMBER(18,0) → C# WorkOrder (IRefIdProperty)
       B.MATERIAL_ID       -- NUMBER(18,0) → C# Material (IRefIdProperty)
FROM EXAMPLE_BILL B;
```

---

## 二、查询中的类型匹配规范

### 2.1 NUMBER(18,0) 对应 long / long? —— 精确匹配

```csharp
// C# 实体
public long Id { get; set; }           // → ID NUMBER(18,0) NOT NULL
public long? UpdateBy { get; set; }    // → UPDATE_BY NUMBER(18,0) NULLABLE
```

```sql
-- ✅ ID 是非空 NUMBER(18,0)，直接等值匹配
SELECT ID, NO FROM EXAMPLE_BILL WHERE ID = 100001;

-- ✅ UPDATE_BY 可空，用 IS NULL 判断
SELECT ID, NO FROM EXAMPLE_BILL WHERE UPDATE_BY IS NULL;

-- ✅ 批量查询（注意：IN 列表不得超过 1000 项，超过应改用临时表 JOIN）
SELECT ID, NO FROM EXAMPLE_BILL WHERE ID IN (100001, 100002, 100003);
```

### 2.2 NUMBER(10,0) 对应 int / enum —— 枚举用数字查询

```csharp
// C# 枚举
public enum BillStatus { Draft = 0, Approved = 1, Paid = 2, Cancelled = 9 }

public class ExampleBill : DataEntity
{
    public BillStatus Status { get; set; }  // → STATUS NUMBER(10,0)
    public int? InvOrgId { get; set; }      // → INV_ORG_ID NUMBER(10,0)
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

### 2.3 NUMBER(1,0) 对应 bool —— 0 / 1 判断

```csharp
// C# 实体
public bool IsPhantom { get; set; }  // → IS_PHANTOM NUMBER(1,0) DEFAULT 0
```

```sql
-- ✅ 查询有效数据（IsPhantom = false → NUMBER(1,0) = 0）
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 0;

-- ✅ 查询已删除数据（IsPhantom = true → NUMBER(1,0) = 1）
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 1;
```

### 2.4 NUMBER(18,6) 对应 decimal —— 注意精度

```csharp
// C# 实体
public decimal Amount { get; set; }       // → AMOUNT NUMBER(18,6)
public decimal? TaxRate { get; set; }     // → TAX_RATE NUMBER(18,6) NULLABLE
```

```sql
-- ✅ 查询时保持小数精度
SELECT ID, NO, AMOUNT FROM EXAMPLE_BILL WHERE AMOUNT > 0;

-- ✅ 求和时使用 ROUND 控制小数位
SELECT ROUND(SUM(AMOUNT), 2) AS TOTAL_AMOUNT FROM EXAMPLE_BILL;

-- ✅ 格式化输出明确小数位
SELECT ID, NO, TO_CHAR(AMOUNT, 'FM999999999999.00') AS AMOUNT_STR
FROM EXAMPLE_BILL;
```

### 2.5 DATE 对应 DateTime —— 日期范围查询

```csharp
// C# 实体
public DateTime CreateDate { get; set; }       // → CREATE_DATE DATE NOT NULL
public DateTime? UpdateDate { get; set; }      // → UPDATE_DATE DATE NULLABLE
public DateTime BillDate { get; set; }         // → BILL_DATE DATE
```

```sql
-- ✅ DateTime 范围查询
SELECT ID, NO, CREATE_DATE
FROM EXAMPLE_BILL
WHERE CREATE_DATE >= DATE '2024-06-01'
  AND CREATE_DATE < DATE '2024-07-01';

-- ✅ 可空的 UpdateDate
SELECT ID, NO, UPDATE_DATE
FROM EXAMPLE_BILL
WHERE UPDATE_DATE IS NOT NULL;

-- ✅ 精确到日的查询（半开区间）
SELECT ID, NO, BILL_DATE
FROM EXAMPLE_BILL
WHERE BILL_DATE >= TO_DATE('2024-06-17', 'YYYY-MM-DD')
  AND BILL_DATE < TO_DATE('2024-06-18', 'YYYY-MM-DD');
```

---

## 三、基于 DataEntity 基类的通用查询模式

### 3.1 默认查询模版

```csharp
// C# 实体：继承 DataEntity 后只需关注业务字段
public class ExampleBill : DataEntity
{
    public string No { get; set; }              // → NO VARCHAR2(80)
    public BillStatus Status { get; set; }      // → STATUS NUMBER(10,0)
    public decimal Amount { get; set; }         // → AMOUNT NUMBER(18,6)
    public DateTime BillDate { get; set; }      // → BILL_DATE DATE
    public WorkOrder WorkOrder { get; set; }    // → WORK_ORDER_ID NUMBER(18,0)
    public Material Material { get; set; }      // → MATERIAL_ID NUMBER(18,0)
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
SET IS_PHANTOM = 1,              -- bool → NUMBER(1,0) = 1
    UPDATE_BY = 1001,             -- long? → NUMBER(18,0)
    UPDATE_DATE = SYSDATE         -- DateTime? → DATE
WHERE ID = 100001;
```

---

## 四、基于 IRefIdProperty 的 JOIN 查询

### 4.1 引用类型 JOIN 模式

```csharp
// C# 实体中的引用关系
public class ExampleBill : DataEntity
{
    public WorkOrder WorkOrder { get; set; }      // IRefId → WORK_ORDER_ID NUMBER(18,0)
    public Material Material { get; set; }        // IRefId → MATERIAL_ID NUMBER(18,0)
    public User CreateByUser { get; set; }        // IRefId → CREATE_BY  NUMBER(18,0)
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
public BillStatus Status { get; set; }  // → STATUS NUMBER(10,0)
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
-- 建表时定义的 CHECK 约束
ALTER TABLE EXAMPLE_BILL
ADD CONSTRAINT CHK_EXAMPLE_BILL_STATUS
CHECK (STATUS IN (0, 1, 2, 9));

-- 查询时必须使用 CHECK 约束范围内的值
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 0;   -- ✅ 草稿
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 1;   -- ✅ 已审核
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 2;   -- ✅ 已付款
SELECT ID, NO FROM EXAMPLE_BILL WHERE STATUS = 9;   -- ✅ 已作废
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

如果实体配置了复合索引，查询条件顺序应与索引列顺序一致。

```csharp
// 假设 HasIndex(x => new { x.Status, x.BillDate })
// → IX_EXAMPLE_BILL_STATUS_BILL_DATE
```

```sql
-- ✅ 复合索引：条件顺序与索引列顺序一致
SELECT ID, NO, STATUS, BILL_DATE
FROM EXAMPLE_BILL
WHERE STATUS = 1                -- 索引前置列
  AND BILL_DATE >= DATE '2024-01-01';
```

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
    SEQ_EXAMPLE_BILL_ID.NEXTVAL,            -- Id → NUMBER(18,0)
    SEQ_EXAMPLE_BILL_SYNC_ID.NEXTVAL,       -- SyncId → NUMBER(18,0)
    1001, SYSDATE,                          -- CreateBy → NUMBER(18,0), CreateDate → DATE
    1001, SYSDATE,                          -- UpdateBy → NUMBER(18,0), UpdateDate → DATE
    101, 0,                                 -- InvOrgId → NUMBER(10,0), IsPhantom → NUMBER(1,0)
    'BILL20240001', 0, 1000,                  -- No → VARCHAR2(80), Status → NUMBER(10,0), Amount → NUMBER(18,6)
    SYSDATE,                                -- BillDate → DATE
    200001, 300001                          -- WorkOrderId → NUMBER(18,0), MaterialId → NUMBER(18,0)
);
```

### 7.2 decimal 类型 INSERT

```csharp
// C# 属性
public decimal Amount { get; set; }   // → AMOUNT NUMBER(18,6)
```

```sql
-- ✅ Oracle 自动补齐小数位
INSERT INTO EXAMPLE_BILL (ID, SYNC_ID, ... AMOUNT ...)
VALUES (SEQ_EXAMPLE_BILL_ID.NEXTVAL, SEQ_EXAMPLE_BILL_SYNC_ID.NEXTVAL, ... 1000 ...);
```

---

## 八、从 C# 到 SQL 的快速查询映射表

### 8.1 条件查询映射

| C# 表达式 | SQL 条件 | 说明 |
|-----------|----------|------|
| `x.Id == 100001` | `ID = 100001` | `long` → `NUMBER(18,0)` |
| `x.Status == BillStatus.Approved` | `STATUS = 1` | `enum` → `NUMBER(10,0)` |
| `x.Status >= BillStatus.Approved` | `STATUS >= 1` | 枚举比较 → 数字比较 |
| `x.Amount > 0` | `AMOUNT > 0` | `decimal` → `NUMBER(18,6)` |
| `x.IsPhantom == false` | `IS_PHANTOM = 0` | `bool` → `NUMBER(1,0)` |
| `x.IsPhantom == true` | `IS_PHANTOM = 1` | `bool` → `NUMBER(1,0)` |
| `x.CreateDate >= startDate` | `CREATE_DATE >= TO_DATE(...)` | `DateTime` → `DATE` |
| `x.WorkOrder == null` | `WORK_ORDER_ID IS NULL` | `IRefIdProperty` 是否引用 |
| `x.No.Contains("2024")` | `NO LIKE '%2024%'` | `string` → `VARCHAR2` |
| `x.No.StartsWith("BILL")` | `NO LIKE 'BILL%'` | `string` → `VARCHAR2` |
| `ids.Contains(x.Id)` | `ID IN (...)` | `long` 集合 → `NUMBER(18,0)` 列表 |

### 8.2 排序映射

| C# 表达式 | SQL | 说明 |
|-----------|-----|------|
| `OrderByDescending(x => x.Id)` | `ORDER BY ID DESC` | 主键降序（最常用） |
| `ThenBy(x => x.Status)` | `ORDER BY ID DESC, STATUS ASC` | 多字段排序 |
| `OrderBy(x => x.CreateDate)` | `ORDER BY CREATE_DATE ASC` | 日期升序 |

### 8.3 SELECT 字段映射

| C# 实体字段 | SQL 列 | 类型映射 |
|------------|--------|---------|
| `Id` | `ID` | `long` → `NUMBER(18,0)` |
| `SyncId` | `SYNC_ID` | `long` → `NUMBER(18,0)` |
| `No` | `NO` | `string` → `VARCHAR2(80)` |
| `Status` | `STATUS` | `enum` → `NUMBER(10,0)` |
| `Amount` | `AMOUNT` | `decimal` → `NUMBER(18,6)` |
| `BillDate` | `BILL_DATE` | `DateTime` → `DATE` |
| `IsPhantom` | `IS_PHANTOM` | `bool` → `NUMBER(1,0)` |
| `WorkOrder` | `WORK_ORDER_ID` | `IRefIdProperty` → `NUMBER(18,0)` |
| `CreateDate` | `CREATE_DATE` | `DateTime?` → `DATE NULLABLE` |
| `UpdateBy` | `UPDATE_BY` | `long?` → `NUMBER(18,0) NULLABLE` |

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
SELECT B.STATUS,                              -- enum → NUMBER(10,0)
       COUNT(1) AS CNT,
       ROUND(SUM(B.AMOUNT), 2) AS TOTAL       -- decimal → NUMBER(18,6)
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0                        -- bool → NUMBER(1,0) = 0
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
WHERE B.IS_PHANTOM = 0                               -- bool → NUMBER(1,0)
  AND B.STATUS = 1                                    -- BillStatus.Approved → 1
ORDER BY B.ID DESC;
```

### 9.4 分页查询

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
-- Oracle 12c+ 对应的 SQL
SELECT B.ID, B.NO, B.AMOUNT, B.STATUS, B.BILL_DATE
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1
ORDER BY B.ID DESC
OFFSET (:page - 1) * :size ROWS FETCH NEXT :size ROWS ONLY;

-- 大数据量时使用游标分页（避免 OFFSET 深翻页性能问题）
SELECT B.ID, B.NO, B.AMOUNT, B.STATUS, B.BILL_DATE
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1
  AND B.ID < :lastCursorId     -- 上一页最后一条的 ID
ORDER BY B.ID DESC
FETCH NEXT 20 ROWS ONLY;
```

### 9.5 更新操作

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
SET STATUS = 1,                    -- enum → NUMBER(10,0)
    AMOUNT = 1000,                  -- decimal → NUMBER(18,6)
    UPDATE_BY = 1001,              -- long? → NUMBER(18,0)
    UPDATE_DATE = SYSDATE          -- DateTime? → DATE
WHERE ID = 100001
  AND IS_PHANTOM = 0;

-- 关联更新：根据子表汇总更新主表（同时更新 DataEntity 基础字段）
UPDATE EXAMPLE_BILL B
SET (B.AMOUNT, B.UPDATE_BY, B.UPDATE_DATE) = (
    SELECT ROUND(SUM(L.LINE_AMOUNT), 6), 1001, SYSDATE
    FROM EXAMPLE_BILL_LINE L
    WHERE L.BILL_ID = B.ID
)
WHERE B.ID = 100001
  AND B.IS_PHANTOM = 0;
```

---

## 十、常见错误与避坑

### 10.1 类型不匹配

```sql
-- ❌ 错误：NO 是 VARCHAR2(80)，传入数字导致隐式类型转换
SELECT ID, NO FROM EXAMPLE_BILL WHERE NO = 1001;

-- ✅ 正确：字符串匹配
SELECT ID, NO FROM EXAMPLE_BILL WHERE NO = '1001';
```

### 10.2 布尔值用数字而非字符串

```sql
-- ❌ 错误：IS_PHANTOM 是 NUMBER(1,0)，不能传字符串
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 'false';

-- ✅ 正确：C# bool → SQL NUMBER(1,0)，值为 0 或 1
SELECT ID, NO FROM EXAMPLE_BILL WHERE IS_PHANTOM = 0;
```

### 10.3 枚举用数字而非名称

```sql
-- ❌ 错误：STATUS 是 NUMBER(10,0)，不能传枚举名称
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
       B.STATUS,                 -- 业务字段（BillStatus 枚举 → NUMBER(10,0)）
       B.AMOUNT,                 -- 业务字段（decimal → NUMBER(18,6)）
       B.BILL_DATE               -- 业务字段（DateTime → DATE）
FROM EXAMPLE_BILL B
WHERE B.IS_PHANTOM = 0
  AND B.STATUS = 1;
```

### 11.3 参数命名规范

```csharp
// C# 中参数化查询的命名规范
// 属性名 → :PropertyName 格式
```

```sql
-- 使用命名参数，与 C# 属性名对应
SELECT ID, NO, STATUS
FROM EXAMPLE_BILL
WHERE IS_PHANTOM = 0
  AND NO = :No               -- 对应 string No
  AND STATUS = :Status        -- 对应 enum Status
  AND BILL_DATE >= :StartDate -- 对应 DateTime StartDate
  AND BILL_DATE < :EndDate;   -- 对应 DateTime EndDate
```

---

## 十二、附则

1. **SELECT 字段顺序**：业务字段在前，DataEntity 基类字段在后。例如 `NO, STATUS, AMOUNT, CREATE_DATE` 在前，`IS_PHANTOM, SYNC_ID` 在后。
2. **关键字大写**：`SELECT`、`FROM`、`WHERE`、`JOIN`、`AND`、`OR`、`ORDER BY` 等关键字统一大写。
3. **表名/字段名大写**：与建表规范一致，所有表名和字段名大写。
4. **参数占位符**：使用 `:paramName` 格式（ODP.NET / Oracle.ManagedDataAccess），参数名与 C# 属性名对应。
5. **每次查询必须带 IS_PHANTOM = 0**（除非有明确需求查询逻辑删除数据）。
6. **外键字段按需选择 JOIN 类型**：非空外键用 `JOIN`，可空外键用 `LEFT JOIN`。
7. **分页必须带 ORDER BY**：确保结果顺序一致。
