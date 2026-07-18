> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：MSSQL____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：MSSQL建表规范·DataEntity默认列·序列·类型映射·命名·sp_addextendedproperty

---

# SQL Server 建表规范

## 一、表结构通用模板

所有业务表均继承自 `DataEntity`，必须包含以下**默认列**：

```sql
CREATE TABLE [dbo].[TABLE_NAME] (
    -- ========== 基础字段（DataEntity 继承） ==========
    [ID]                FLOAT           NOT NULL,   -- 主键ID（使用序列获取，双精度浮点）
    [SYNC_ID]           FLOAT           NOT NULL,   -- 同步ID（使用序列获取）
    [CREATE_BY]         FLOAT           NULL,       -- 创建人ID
    [CREATE_DATE]       DATETIME        NOT NULL,   -- 创建时间
    [UPDATE_BY]         FLOAT           NULL,       -- 更新人ID
    [UPDATE_DATE]       DATETIME        NOT NULL,   -- 更新时间
    [INV_ORG_ID]        INT             NULL,       -- 所属机构ID
    [IS_PHANTOM]        BIT             NOT NULL DEFAULT 0,  -- 虚体标记（0=否,1=是）

    -- ========== 业务字段（视需求添加） ==========
    [NO]                NVARCHAR(80)    NULL,       -- 单据号（若需要）
    [STATUS]            INT             NULL,       -- 状态枚举（若有）
    -- ... 其他业务字段 ...

    -- ========== 约束 ==========
    CONSTRAINT [PK_TABLE_NAME] PRIMARY KEY ([ID])
);
```

## 二、必须创建的序列

每个表**必须创建2个序列**，用于显式获取 ID 和 SYNC_ID（与 Oracle 原规范保持一致，不使用 IDENTITY）。

### 1. 主键 ID 序列

```sql
CREATE SEQUENCE [dbo].[SEQ_TABLE_NAME_ID]
    START WITH 100000      -- 从10万开始，避免与历史数据冲突
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE
    CACHE 20;
```

### 2. 同步 ID 序列（SYNC_ID）

```sql
CREATE SEQUENCE [dbo].[SEQ_TABLE_NAME_SYNC_ID]
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE
    CACHE 20;
```

> **注意**：
> - SQL Server 序列属于架构，命名中使用 `[dbo]` 占位。
> - 序列的增量值以整数步进，但插入时赋值给 `FLOAT` 列会自动转换为浮点数，不影响使用。
> - 若实际开发中倾向使用 `IDENTITY` 自增，可省略序列，但为保持与 Oracle 规范一致，此处保留序列方式。

## 三、字段类型映射规则

| C# 类型 | SQL Server 类型 | 说明 |
|---------|-----------------|------|
| `float` / `double` | `FLOAT`（等价于 `FLOAT(53)`） | 主键、外键ID（对应 Oracle `NUMBER(18,0)`，但改为浮点） |
| `int` / `enum` | `INT` | 枚举值、状态码（对应 Oracle `NUMBER(10,0)`） |
| `string`（单据号/用户名） | `NVARCHAR(80)` | 短文本，按需调整长度（使用NVARCHAR支持Unicode） |
| `string`（URL/长文本） | `NVARCHAR(4000)` | 长文本（或 `NVARCHAR(MAX)` 根据场景） |
| `decimal` | `DECIMAL(18,6)` | 金额、数量等精确值 |
| `DateTime` | `DATETIME` | 日期时间（精度约3.33毫秒，保持与原规范兼容） |
| `bool` | `BIT` | 布尔值（0/1，对应 Oracle `NUMBER(1,0)`） |

## 四、命名规范

### 表名
- 全大写，下划线分隔
- 示例：`OQC_SHIP_INSP_CONFIRM_BILL`
- 表名应体现业务含义及所属模块

### 列名
- 全大写，下划线分隔
- 避免使用SQL Server保留字（如 `NO` 可以使用，但最好加方括号）
- 外键字段建议包含 `_ID` 后缀
- 枚举字段建议包含状态含义的后缀或前缀

### 序列名
- 格式：`SEQ_表名_ID` / `SEQ_表名_SYNC_ID`

### 主键约束
- 格式：`PK_表名`

### 索引
- 格式：`IX_表名_字段名`

### CHECK约束
- 格式：`CHK_表名_字段名`

## 五、必加的操作

### 1. 添加表备注

```sql
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'表中文注释',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'TABLE_NAME';
```

### 2. 添加字段备注

```sql
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'字段中文注释',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'TABLE_NAME',
    @level2type = N'COLUMN', @level2name = N'COLUMN_NAME';
```

### 3. （推荐）添加CHECK约束（枚举字段）

```sql
ALTER TABLE [dbo].[TABLE_NAME]
ADD CONSTRAINT [CHK_TABLE_NAME_STATUS]
CHECK ([STATUS] IN (0, 1, 2, ...));  -- 对应枚举所有合法值
```

### 4. （推荐）添加索引

```sql
-- 单据号索引（高频查询）
CREATE INDEX [IX_TABLE_NAME_NO]
ON [dbo].[TABLE_NAME] ([NO]);

-- 外键索引（关联查询）
CREATE INDEX [IX_TABLE_NAME_REF_ID]
ON [dbo].[TABLE_NAME] ([REF_ID_FIELD]);
```

## 六、完整建表示例（模板）

```sql
-- =============================================
-- 创建表：[dbo].[EXAMPLE_BILL]
-- 描述：示例业务单据表
-- =============================================

-- 1. 创建主键序列
CREATE SEQUENCE [dbo].[SEQ_EXAMPLE_BILL_ID]
    START WITH 100000
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE
    CACHE 20;

-- 2. 创建同步ID序列
CREATE SEQUENCE [dbo].[SEQ_EXAMPLE_BILL_SYNC_ID]
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE
    CACHE 20;

-- 3. 建表
CREATE TABLE [dbo].[EXAMPLE_BILL] (
    -- 基础字段
    [ID]                FLOAT           NOT NULL,
    [SYNC_ID]           FLOAT           NOT NULL,
    [CREATE_BY]         FLOAT           NULL,
    [CREATE_DATE]       DATETIME        NOT NULL,
    [UPDATE_BY]         FLOAT           NULL,
    [UPDATE_DATE]       DATETIME        NOT NULL,
    [INV_ORG_ID]        INT             NULL,
    [IS_PHANTOM]        BIT             NOT NULL DEFAULT 0,

    -- 业务字段
    [NO]                NVARCHAR(80)    NULL,
    [BILL_TYPE]         NVARCHAR(40)    NULL,
    [STATUS]            INT             NULL,
    [QTY]               DECIMAL(18,6)   NULL,
    [AMOUNT]            DECIMAL(18,6)   NULL,
    [REMARK]            NVARCHAR(4000)  NULL,
    [BILL_DATE]         DATETIME        NULL,

    -- 外键字段
    [WORK_ORDER_ID]     FLOAT           NULL,
    [MATERIAL_ID]       FLOAT           NULL,

    -- 约束
    CONSTRAINT [PK_EXAMPLE_BILL] PRIMARY KEY ([ID])
);

-- 4. 表备注
EXEC sp_addextendedproperty
    @name = N'MS_Description', @value = N'示例业务单据表',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'EXAMPLE_BILL';

-- 5. 字段备注（使用简化语法，一行一个）
EXEC sp_addextendedproperty N'MS_Description', N'主键ID',      N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'ID';
EXEC sp_addextendedproperty N'MS_Description', N'同步ID',      N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'SYNC_ID';
EXEC sp_addextendedproperty N'MS_Description', N'创建人ID',    N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'CREATE_BY';
EXEC sp_addextendedproperty N'MS_Description', N'创建时间',    N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'CREATE_DATE';
EXEC sp_addextendedproperty N'MS_Description', N'更新人ID',    N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'UPDATE_BY';
EXEC sp_addextendedproperty N'MS_Description', N'更新时间',    N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'UPDATE_DATE';
EXEC sp_addextendedproperty N'MS_Description', N'所属机构ID', 	N'SCHEMA',	N'dbo',
	N'TABLE',
	N'EXAMPLE_BILL',
	N'COLUMN',
	N'INV_ORG_ID';
EXEC sp_addextendedproperty N'MS_Description', N'虚体标记(0=否,1=是)', N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'IS_PHANTOM';
EXEC sp_addextendedproperty N'MS_Description', N'单据号',      N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'NO]';
EXEC sp_addextendedproperty N'MS_Description', N'单据类型',    N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'BILL_TYPE]';
EXEC sp_addextendedproperty N'MS_Description', N'状态(0=草稿,1=已提交,2=已审核)', N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'STATUS]';
EXEC sp_addextendedproperty N'MS_Description', N'数量',        N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'QTY]';
EXEC sp_addextendedproperty N'MS_Description', N'金额',        N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'AMOUNT]';
EXEC sp_addextendedproperty N'MS_Description', N'备注',        N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'REMARK]';
EXEC sp_addextendedproperty N'MS_Description', N'单据日期',    N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN', N'BILL_DATE]';
EXEC sp_addextendedproperty N'MS_Description', N'工单ID(引用WorkOrder)', N'SCHEMA', N'dbo', N'TABLE', N'EXAMPLE_BILL', N'COLUMN]',	N'WORK_ORDER_ID]';
EXEC sp_addextendedproperty N'MS_Description',	N'物料ID(引用Material)', 	N'SCHEMA',	N'dbo',
	N'TABLE',
	N'EXAMPLE_BILL',
	N'COLUMN',
	N'MATERIAL_ID';

-- 6. 创建索引
CREATE INDEX [IX_EXAMPLE_BILL_NO] ON [dbo].[EXAMPLE_BILL] ([NO]);
CREATE INDEX [IX_EXAMPLE_BILL_STATUS] ON [dbo].[EXAMPLE_BILL] ([STATUS]);
CREATE INDEX [IX_EXAMPLE_BILL_WORK_ORDER] ON [dbo].[EXAMPLE_BILL] ([WORK_ORDER_ID]);

-- 7. （可选）枚举字段CHECK约束
ALTER TABLE [dbo].[EXAMPLE_BILL]
ADD CONSTRAINT [CHK_EXAMPLE_BILL_STATUS]
CHECK ([STATUS] IN (0, 1, 2));
```

## 七、从C#实体到SQL Server表的快速映射

当给出一个C#实体类时，按以下步骤转换：

1. **提取`DataEntity`默认字段** → 映射为基础列
   - `ID` → `FLOAT NOT NULL`（使用序列）
   - `SYNC_ID` → `FLOAT NOT NULL`（使用序列）
   - `CREATE_BY` → `FLOAT NULL`
   - `CREATE_DATE` → `DATETIME NOT NULL`
   - `UPDATE_BY` → `FLOAT NULL`
   - `UPDATE_DATE` → `DATETIME NOT NULL`
   - `INV_ORG_ID` → `INT NULL`
   - `IS_PHANTOM` → `BIT NOT NULL DEFAULT 0`

2. **提取业务属性**（Property字段）：
   - `string` → `NVARCHAR(长度)`，默认80或4000
   - `int`/`enum` → `INT`
   - `float`/`double` → `FLOAT`
   - `decimal` → `DECIMAL(18,6)`
   - `DateTime` → `DATETIME`

3. **提取引用类型**（IRefIdProperty）→ 映射为 `FLOAT` 外键字段

4. **解析`[Label]`** → 生成 `sp_addextendedproperty` 注释

5. **检查`MapTable`配置** → 确定表名

6. **检查`HasIndex`** → 生成索引

---
**当新建C#实体类时，请按照以上规范生成对应的SQL SERVER建表脚本。**