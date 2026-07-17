> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **原文文件**：ORACLE____.md
> **优先级**：高。与 manual/ 权威手册重合之处，以本文件规则为准（更尖锐、更可执行）。
> **覆盖范围**：ORACLE建表规范·DataEntity默认列·序列·类型映射·命名·COMMENT

---

# Oracle 建表规范

## 一、表结构通用模板

所有业务表均继承自 `DataEntity`，必须包含以下**默认列**：

```sql
CREATE TABLE TABLE_NAME (
    -- ========== 基础字段（DataEntity 继承） ==========
    ID                    NUMBER(18,0)    NOT NULL,  -- 主键ID（对应 C# float/double）
    SYNC_ID               NUMBER(18,0)    NOT NULL,  -- 同步ID
    CREATE_BY             NUMBER(18,0),               -- 创建人ID
    CREATE_DATE           DATE            NOT NULL,   -- 创建时间
    UPDATE_BY             NUMBER(18,0),               -- 更新人ID
    UPDATE_DATE           DATE            NOT NULL,   -- 更新时间
    INV_ORG_ID            NUMBER(10,0),               -- 所属机构ID
    IS_PHANTOM            NUMBER(1,0)     DEFAULT 0 NOT NULL,  -- 假删标记（0=否, 1=是）
  
    -- ========== 业务字段（视需求添加） ==========
    NO                    VARCHAR2(80),               -- 单据号（若需要）
    STATUS                NUMBER(10,0),               -- 状态枚举（若有）
    -- ... 其他业务字段 ...
  
    -- ========== 约束 ==========
    CONSTRAINT PK_TABLE_NAME PRIMARY KEY (ID)
);
```

## 二、必须创建的序列

每个表**必须创建2个序列**：

### 1. 主键 ID 序列

```sql
CREATE SEQUENCE SEQ_TABLE_NAME_ID
    START WITH 100000      -- 从10万开始，避免与历史数据冲突
    INCREMENT BY 1
    NOMAXVALUE
    NOCYCLE
    CACHE 20;
```

### 2. 同步 ID 序列（SYNC_ID）

```sql
CREATE SEQUENCE SEQ_TABLE_NAME_SYNC_ID
    START WITH 1
    INCREMENT BY 1
    NOMAXVALUE
    NOCYCLE
    CACHE 20;
```

## 三、字段类型映射规则

| C# 类型 | Oracle 类型 | 说明 |
|---------|-------------|------|
| `float` / `double` | `NUMBER(18,0)` | 主键、外键ID |
| `int` / `enum` | `NUMBER(10,0)` | 枚举值、状态码 |
| `string`（单据号/用户名） | `VARCHAR2(80)` | 短文本，按需调整长度 |
| `string`（URL/长文本） | `VARCHAR2(4000)` | 长文本 |
| `decimal` | `NUMBER(18,6)` | 金额、数量等精确值 |
| `DateTime` | `DATE` | 日期时间 |
| `bool` | `NUMBER(1,0)` | 布尔值（0/1） |

## 四、命名规范

### 表名
- 全大写，下划线分隔
- 示例：`OQC_SHIP_INSP_CONFIRM_BILL`
- 表名应体现业务含义及所属模块

### 列名
- 全大写，下划线分隔
- 避免使用Oracle保留字（如 `NO` 可以使用，但需注意）
- 外键字段建议包含 `_ID` 后缀
- 枚举字段建议包含状态含义的后缀或前缀

### 序列名
- 格式：`SEQ_表名_ID` / `SEQ_表名_SYNC_ID`

### 主键约束
- 格式：`PK_表名`

### 索引
- 格式：`IX_表名_字段名`

## 五、必加的操作

### 1. 添加表备注
```sql
COMMENT ON TABLE TABLE_NAME IS '表中文注释';
```

### 2. 添加字段备注
```sql
COMMENT ON COLUMN TABLE_NAME.COLUMN_NAME IS '字段中文注释';
```

### 3. （推荐）添加CHECK约束（枚举字段）
```sql
ALTER TABLE TABLE_NAME
ADD CONSTRAINT CHK_TABLE_NAME_STATUS
CHECK (STATUS IN (0, 1, 2, ...));  -- 对应枚举所有合法值
```

### 4. （推荐）添加索引
```sql
-- 单据号索引（高频查询）
CREATE INDEX IX_TABLE_NAME_NO
ON TABLE_NAME (NO);

-- 外键索引（关联查询）
CREATE INDEX IX_TABLE_NAME_REF_ID
ON TABLE_NAME (REF_ID_FIELD);
```

## 六、完整建表示例（模板）

```sql
-- =============================================
-- 创建表：EXAMPLE_BILL
-- 描述：示例业务单据表
-- =============================================

-- 1. 创建主键序列
CREATE SEQUENCE SEQ_EXAMPLE_BILL_ID
    START WITH 100000
    INCREMENT BY 1
    NOMAXVALUE
    NOCYCLE
    CACHE 20;

-- 2. 创建同步ID序列
CREATE SEQUENCE SEQ_EXAMPLE_BILL_SYNC_ID
    START WITH 1
    INCREMENT BY 1
    NOMAXVALUE
    NOCYCLE
    CACHE 20;

-- 3. 建表
CREATE TABLE EXAMPLE_BILL (
    -- 基础字段
    ID                NUMBER(18,0)    NOT NULL,
    SYNC_ID           NUMBER(18,0)    NOT NULL,
    CREATE_BY         NUMBER(18,0),
    CREATE_DATE       DATE            NOT NULL,
    UPDATE_BY         NUMBER(18,0),
    UPDATE_DATE       DATE            NOT NULL,
    INV_ORG_ID        NUMBER(10,0),
    IS_PHANTOM        NUMBER(1,0)     DEFAULT 0 NOT NULL,
  
    -- 业务字段
    NO                VARCHAR2(80),
    BILL_TYPE         VARCHAR2(40),
    STATUS            NUMBER(10,0),
    QTY               NUMBER(18,6),
    AMOUNT            NUMBER(18,6),
    REMARK            VARCHAR2(4000),
    BILL_DATE         DATE,
  
    -- 外键字段
    WORK_ORDER_ID     NUMBER(18,0),
    MATERIAL_ID       NUMBER(18,0),
  
    -- 约束
    CONSTRAINT PK_EXAMPLE_BILL PRIMARY KEY (ID)
);

-- 4. 表备注
COMMENT ON TABLE EXAMPLE_BILL IS '示例业务单据表';

-- 5. 字段备注
COMMENT ON COLUMN EXAMPLE_BILL.ID              IS '主键ID';
COMMENT ON COLUMN EXAMPLE_BILL.SYNC_ID         IS '同步ID';
COMMENT ON COLUMN EXAMPLE_BILL.CREATE_BY       IS '创建人ID';
COMMENT ON COLUMN EXAMPLE_BILL.CREATE_DATE     IS '创建时间';
COMMENT ON COLUMN EXAMPLE_BILL.UPDATE_BY       IS '更新人ID';
COMMENT ON COLUMN EXAMPLE_BILL.UPDATE_DATE     IS '更新时间';
COMMENT ON COLUMN EXAMPLE_BILL.INV_ORG_ID      IS '所属机构ID';
COMMENT ON COLUMN EXAMPLE_BILL.IS_PHANTOM      IS '虚体标记(0=否,1=是)';
COMMENT ON COLUMN EXAMPLE_BILL.NO              IS '单据号';
COMMENT ON COLUMN EXAMPLE_BILL.BILL_TYPE       IS '单据类型';
COMMENT ON COLUMN EXAMPLE_BILL.STATUS          IS '状态(0=草稿,1=已提交,2=已审核)';
COMMENT ON COLUMN EXAMPLE_BILL.QTY             IS '数量';
COMMENT ON COLUMN EXAMPLE_BILL.AMOUNT          IS '金额';
COMMENT ON COLUMN EXAMPLE_BILL.REMARK          IS '备注';
COMMENT ON COLUMN EXAMPLE_BILL.BILL_DATE       IS '单据日期';
COMMENT ON COLUMN EXAMPLE_BILL.WORK_ORDER_ID   IS '工单ID(引用WorkOrder)';
COMMENT ON COLUMN EXAMPLE_BILL.MATERIAL_ID     IS '物料ID(引用Material)';

-- 6. 创建索引
CREATE INDEX IX_EXAMPLE_BILL_NO ON EXAMPLE_BILL (NO);
CREATE INDEX IX_EXAMPLE_BILL_STATUS ON EXAMPLE_BILL (STATUS);
CREATE INDEX IX_EXAMPLE_BILL_WORK_ORDER ON EXAMPLE_BILL (WORK_ORDER_ID);

-- 7. （可选）枚举字段CHECK约束
ALTER TABLE EXAMPLE_BILL
ADD CONSTRAINT CHK_EXAMPLE_BILL_STATUS
CHECK (STATUS IN (0, 1, 2));
```

## 七、从C#实体到Oracle表的快速映射

当给出一个C#实体类时，按以下步骤转换：

1. **提取`DataEntity`默认字段** → 映射为基础列
2. **提取业务属性**（Property字段）：
   - `string` → `VARCHAR2`
   - `int`/`enum` → `NUMBER(10,0)`
   - `float`/`double` → `NUMBER(18,0)`
   - `decimal` → `NUMBER(18,6)`
   - `DateTime` → `DATE`
3. **提取引用类型**（IRefIdProperty）→ 映射为 `NUMBER(18,0)` 外键字段
4. **解析`[Label]`** → 生成COMMENT备注
5. **检查`MapTable`配置** → 确定表名
6. **检查`HasIndex`** → 生成索引

---

**当新建C#实体类时，请按照以上规范生成对应的Oracle建表脚本。**