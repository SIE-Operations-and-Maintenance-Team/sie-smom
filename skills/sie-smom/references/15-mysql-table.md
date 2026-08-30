# MySQL 建表规范

## 一、表结构通用模板

所有业务表均继承自 `DataEntity`，必须包含以下**默认列**：

```sql
CREATE TABLE `TABLE_NAME` (
    -- ========== 基础字段（DataEntity 继承） ==========
    `ID`                BIGINT          NOT NULL AUTO_INCREMENT,  -- 主键ID（对应 C# double）
    `SYNC_ID`           BIGINT          NOT NULL,                 -- 同步ID
    `CREATE_BY`         BIGINT          NULL,                     -- 创建人ID
    `CREATE_DATE`       DATETIME        NOT NULL,                 -- 创建时间
    `UPDATE_BY`         BIGINT          NULL,                     -- 更新人ID
    `UPDATE_DATE`       DATETIME        NOT NULL,                 -- 更新时间
    `INV_ORG_ID`        INT             NULL,                     -- 所属机构ID
    `IS_PHANTOM`        TINYINT(1)      NOT NULL DEFAULT 0,       -- 假删标记（0=否, 1=是）

    -- ========== 业务字段（视需求添加） ==========
    `NO`                VARCHAR(80)     NULL,                     -- 单据号（若需要）
    `STATUS`            INT             NULL,                     -- 状态枚举（若有）
    -- ... 其他业务字段 ...

    -- ========== 约束 ==========
    PRIMARY KEY (`ID`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '表中文注释';
```

> **⚠️ 引擎与字符集**：所有业务表**必须**使用 `InnoDB` 引擎（支持事务与行级锁，配合框架 `TransactionScope`），字符集使用 `utf8mb4`（完整 Unicode，兼容中文与 emoji），排序规则 `utf8mb4_general_ci`（或项目统一采用的 collation）。

## 二、ID 生成策略

### 1. 推荐：AUTO_INCREMENT 自增主键

```sql
`ID` BIGINT NOT NULL AUTO_INCREMENT,
PRIMARY KEY (`ID`)
```

- 插入时**不写入 ID 列**，由数据库自动生成，无需显式取序列值。
- 与 MSSQL/Oracle 规范"序列生成"的差异：MSSQL 用 `CREATE SEQUENCE` + `NEXT VALUE FOR`，Oracle 用 `CREATE SEQUENCE` + `.NEXTVAL`，MySQL 用 `AUTO_INCREMENT` 即可，**无需额外序列对象**。

### 2. 若沿用"显式序列"习惯（与 MSSQL/Oracle 规范一致）

MySQL 没有独立序列对象，可通过以下方式模拟：

```sql
-- 自增起始值设置（模拟 START WITH 100000）
ALTER TABLE `EXAMPLE_BILL` AUTO_INCREMENT = 100000;

-- 插入时先取当前最大 ID + 1 作为下一个值（不推荐并发下有竞争，仅作参考）
SELECT COALESCE(MAX(`ID`), 0) + 1 AS NEXT_ID FROM `EXAMPLE_BILL`;
```

> **建议**：新建 MySQL 表优先采用 `AUTO_INCREMENT`（第 1 种方式）；若项目要求与 MSSQL/Oracle 保持一致的"显式序列"行为，需在应用层自实现取号逻辑，并注意并发安全。

## 三、字段类型映射规则

| C# 类型 | MySQL 类型 | 说明 |
|---------|------------|------|
| `double` / `double?` | `BIGINT` | 主键、外键ID（对应 MSSQL `FLOAT` / Oracle `NUMBER(18,0)`，MySQL 为精确整数） |
| `int` / `enum` | `INT` | 枚举值、状态码（对应 Oracle `NUMBER(10,0)`） |
| `string`（单据号/用户名） | `VARCHAR(80)` | 短文本，按需调整长度 |
| `string`（URL/长文本） | `VARCHAR(4000)` | 长文本（或 `TEXT` 根据场景） |
| `decimal` | `DECIMAL(18,6)` | 金额、数量等精确值 |
| `DateTime` | `DATETIME` | 日期时间（精确到秒，对应 Oracle `DATE` / MSSQL `DATETIME`） |
| `bool` | `TINYINT(1)` | 布尔值（0/1，对应 MSSQL `BIT` / Oracle `NUMBER(1,0)`） |
| `float` | `DOUBLE` | 业务浮点，尽量避免用于金额等精确场景 |

## 四、命名规范

### 表名
- 全大写，下划线分隔
- 示例：`OQC_SHIP_INSP_CONFIRM_BILL`
- 表名应体现业务含义及所属模块

### 列名
- 全大写，下划线分隔
- 避免使用 MySQL 保留字（如 `RANK`（8.0+）、`GROUP` 等），必要时用反引号包裹
- 外键字段建议包含 `_ID` 后缀
- 枚举字段建议包含状态含义的后缀或前缀

### 主键
- 主键列统一命名为 `ID`，类型 `BIGINT`，`PRIMARY KEY (ID)`

### 索引
- 格式：`IX_表名_字段名`

### CHECK约束
- 格式：`CHK_表名_字段名`

> **注意**：MySQL 5.7 及以下会**解析但忽略** CHECK 约束（不报错也不校验）；MySQL 8.0.16+ 才真正强制。**枚举字段合法性的最终保证依赖应用层**（C# 枚举 + 实体验证规则）。

## 五、必加的操作

### 1. 添加表备注（建表时内联或 ALTER）

```sql
-- 建表时内联（推荐）
CREATE TABLE `TABLE_NAME` (
    ...
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '表中文注释';

-- 已存在表追加备注
ALTER TABLE `TABLE_NAME` COMMENT = '表中文注释';
```

### 2. 添加字段备注（建表时内联或 ALTER）

```sql
-- 建表时内联（推荐）
`NO` VARCHAR(80) NULL COMMENT '单据号',

-- 已存在表修改字段备注
ALTER TABLE `TABLE_NAME`
MODIFY COLUMN `NO` VARCHAR(80) NULL COMMENT '单据号';
```

### 3. （推荐）添加CHECK约束（枚举字段）

```sql
-- MySQL 8.0.16+ 强制，5.7 及以下忽略（应用层仍须校验）
ALTER TABLE `TABLE_NAME`
ADD CONSTRAINT `CHK_TABLE_NAME_STATUS`
CHECK (`STATUS` IN (0, 1, 2, ...));  -- 对应枚举所有合法值
```

### 4. （推荐）添加索引

```sql
-- 单据号索引（高频查询）
CREATE INDEX `IX_TABLE_NAME_NO`
ON `TABLE_NAME` (`NO`);

-- 外键索引（关联查询）
CREATE INDEX `IX_TABLE_NAME_REF_ID`
ON `TABLE_NAME` (`REF_ID_FIELD`);
```

## 六、完整建表示例（模板）

```sql
-- =============================================
-- 创建表：EXAMPLE_BILL
-- 描述：示例业务单据表
-- 数据库：MySQL 8.0+ / InnoDB / utf8mb4
-- =============================================

-- 1. 建表
CREATE TABLE `EXAMPLE_BILL` (
    -- 基础字段（DataEntity）
    `ID`                BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `SYNC_ID`           BIGINT          NOT NULL COMMENT '同步ID',
    `CREATE_BY`         BIGINT          NULL COMMENT '创建人ID',
    `CREATE_DATE`       DATETIME        NOT NULL COMMENT '创建时间',
    `UPDATE_BY`         BIGINT          NULL COMMENT '更新人ID',
    `UPDATE_DATE`       DATETIME        NOT NULL COMMENT '更新时间',
    `INV_ORG_ID`        INT             NULL COMMENT '所属机构ID',
    `IS_PHANTOM`        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '虚体标记(0=否,1=是)',

    -- 业务字段
    `NO`                VARCHAR(80)     NULL COMMENT '单据号',
    `BILL_TYPE`         VARCHAR(40)     NULL COMMENT '单据类型',
    `STATUS`            INT             NULL COMMENT '状态(0=草稿,1=已提交,2=已审核)',
    `QTY`               DECIMAL(18,6)   NULL COMMENT '数量',
    `AMOUNT`            DECIMAL(18,6)   NULL COMMENT '金额',
    `REMARK`            VARCHAR(4000)   NULL COMMENT '备注',
    `BILL_DATE`         DATETIME        NULL COMMENT '单据日期',

    -- 外键字段
    `WORK_ORDER_ID`     BIGINT          NULL COMMENT '工单ID(引用WorkOrder)',
    `MATERIAL_ID`       BIGINT          NULL COMMENT '物料ID(引用Material)',

    -- 约束
    PRIMARY KEY (`ID`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '示例业务单据表';

-- 2. （可选）AUTO_INCREMENT 起始值设为 100000，避免与历史数据冲突
ALTER TABLE `EXAMPLE_BILL` AUTO_INCREMENT = 100000;

-- 3. 创建索引
CREATE INDEX `IX_EXAMPLE_BILL_NO` ON `EXAMPLE_BILL` (`NO`);
CREATE INDEX `IX_EXAMPLE_BILL_STATUS` ON `EXAMPLE_BILL` (`STATUS`);
CREATE INDEX `IX_EXAMPLE_BILL_WORK_ORDER` ON `EXAMPLE_BILL` (`WORK_ORDER_ID`);

-- 4. （可选）枚举字段CHECK约束（MySQL 8.0.16+ 强制，5.7 及以下忽略）
ALTER TABLE `EXAMPLE_BILL`
ADD CONSTRAINT `CHK_EXAMPLE_BILL_STATUS`
CHECK (`STATUS` IN (0, 1, 2));
```

## 七、从C#实体到MySQL表的快速映射

当给出一个C#实体类时，按以下步骤转换：

1. **提取`DataEntity`默认字段** → 映射为基础列
   - `ID` → `BIGINT NOT NULL AUTO_INCREMENT`（主键）
   - `SYNC_ID` → `BIGINT NOT NULL`
   - `CREATE_BY` → `BIGINT NULL`
   - `CREATE_DATE` → `DATETIME NOT NULL`
   - `UPDATE_BY` → `BIGINT NULL`
   - `UPDATE_DATE` → `DATETIME NOT NULL`
   - `INV_ORG_ID` → `INT NULL`
   - `IS_PHANTOM` → `TINYINT(1) NOT NULL DEFAULT 0`

2. **提取业务属性**（Property字段）：
   - `string` → `VARCHAR(长度)`，默认80或4000
   - `int`/`enum` → `INT`
   - `float`/`double` → `DOUBLE`
   - `decimal` → `DECIMAL(18,6)`
   - `DateTime` → `DATETIME`

3. **提取引用类型**（IRefIdProperty）→ 映射为 `BIGINT` 外键字段

4. **解析`[Label]`** → 生成 `COMMENT` 备注（建表内联或 `ALTER TABLE ... MODIFY`）

5. **检查`MapTable`配置** → 确定表名

6. **检查`HasIndex`** → 生成索引

7. **引擎与字符集** → 一律 `ENGINE = InnoDB DEFAULT CHARSET = utf8mb4`
