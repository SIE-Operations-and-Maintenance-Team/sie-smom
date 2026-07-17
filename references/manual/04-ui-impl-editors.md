# 菜单·DB连接·单表主从表·编辑器·框架常用API

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch8-13
> **提取范围**：docx 正文行 1019-1779
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

8. BS菜单配置
  8.1. 标准内置菜单


新增加的功能菜单，或者是功能菜单配置好后更改了菜单对应的实体类，必须先进行模块初始化，才能在菜单左边的列表中看到对应的菜单，如果是普通账号还需要进行权限设置。
  8.2. 自定义菜单的配置（可外链客户第三方系统集成）
• 在模块菜单中添加模块菜单
注意：自定义菜单一定要加上Url，并且Url必须带http://或者https://，方能展示分配的菜单权限

• 在菜单中将左边的模块菜单拖动到右边菜单中，点击保存

• 在角色编辑权限中分配对应的角色，点击确定

• 对应的自定义菜单就显示出来了


  8.3. 报表平台新添加后如何配置为菜单
• 先在bs”文档定义”添加并保存，

• 在BS的模块定义中点击“模块初始化”按钮，初始化成功后会把CS中添加的报表在表格中生成对应的模块菜单数据

或者在菜单界面中点击模块初始化或者是指定模块初始化

• 将模块左边初始化成功的菜单拖到右边对应的菜单中，点击保存，然后在角色中分配对应的菜单权限，退出重新登录，报表就可以在BS上展示了

• 如果要打开为浏览器的新页签，可以在菜单中打开方式改为窗体

效果如下：

9. 框架数据库的连接
1. Oracle连接
    "master": {
      "Name": "master",
      "ConnectionString": "Data Source=(DESCRIPTION =(ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.175.70)(PORT = 1521))(CONNECT_DATA =(SERVER = DEDICATED)(SERVICE_NAME = MESDEV)));User Id=PROD82;Password=PROD82;Metadata Pooling=false;",
      "ProviderName": "Oracle.ManagedDataAccess.Client"
    },
2. SQL Server数据库连接
"master": {
      "Name": "master",
      "ConnectionString": "Data Source=192.168.175.68\MSSQLSERVER2017;Initial Catalog=Deerma;User ID=sa;Password=sie@2019;Integrated Security=True;",
      "ProviderName": "System.Data.SqlClient"
    }
3. VS自带数据库连接
"master": {
      "Name": "master",
      "ConnectionString": "Data Source=(LocalDB)\\MSSQLLocalDB;AttachDbFilename=XXX\\DbFile\\Demo-DB.mdf;Integrated Security=True;",
      "ProviderName": "System.Data.SqlClient"
    }

4. MySql数据库连接
  "master": {
      "Name": "master",
      "ConnectionString":"server=127.0.0.1;User Id=code_prod;password=123456;Database=test1;ConnectionTimeout=300;DefaultCommandTimeout=300",
      "ProviderName": "PolarDB"
    },

10. 单表的实现
以缺陷信息和缺陷信息分类为例，以表格（行内编辑）的形式添加界面，效果如下图：

 
单表的实现步骤如下 ：
• 建模
• 生成代码
• 配置默认菜单
• 升级数据库
• 菜单的配置
• 查询面板设置
• 下拉选择框配置
  10.1. 建模
• 根据业务要求进行UML建模

说明：
• 在做实体建模时，类、属性、类与类之间的关系的备注信息一定要加上，如果备注没有加上，通过类图生成的实体（类）和属性就没有描述，而我们界面显示的名称以及映射的数据库表和字段的备注信息，都是通过实体建模的备注信息生成的（没加会导致界面显示的名称和数据库表和属性的说明都为空）
• 定义类的编码不要使用Id,因为我们的实体去映射数据库表的主键是Id,如果再定义属性为Id,升级数据库时会升级失败，而且错误信息提示不明显，比较难排查问题
• 定义属性时不要两个或者两个以上的大写字母写在一块，如果两个大写的字母合在一起，如CODE映射到数据库的属性名是C_O_D_E,可读性差；Code映射到数据库的属性名是CODE
• 属性的常规验证如非空，非重复，可在类图上体现（比较直观，通过类图就能知道界面的常用操作）

 
  10.2.  生成代码
• UML建模完成后，就可以根据建模生成实体和界面，选中要生成实体和界面的类》右键》生成代码

• 在生成代码的界面，选择2018文件夹下的实体（Entity）和界面（WebViewConfig）的模板到右边，点击生成代码（Generate），等待生成成功

• 生成完成后，在下方的已生成文件列表选择文件右键打开文件所在位置，将生成的实体对应的文件夹拷贝到服务端，生成的界面拷贝到客户端

 

  10.3. 配置默认菜单 
• 生成代码，解决报错的代码，然后在客户端（SIE.Web.Test）的Module中给刚刚新建的两个实体配置默认菜单


  10.4. 升级数据库
• 生成不报错，运行项目，升级数据库（新添加的表需要升级数据库）
说明：
• BS通过”实体元数据界面”的”升级数据库按钮”进行数据库表升级操作生成新添加的功能表，如果是首次拿到项目，框架表都还没生成的情况下，BS下的升级数据库是行不通的，空库的情况需要通过CS端先进行升级数据库
• Cs端升级数据库只能直连形式去升级
8.0及以下版本：在该工程下App.config中配置数据库连接字符串，然后启用直连：<platform currentCulture="zh-CN" collectDevLanguages="IsDebugging">

8.0以上版本：在appsettings.json上配置

 
• CS版的升级数据库：
在升级数据库的对话框中（8.0以前的版本有个删除数据库的复选框选者，这个不要去勾选，勾选之后会把数据库中所有的表都删除，然后在生成选中连接的数据库）

• BS版的升级数据库：

 

更新备注：更新数据库表和属性的说明
初始化实体元数据：生成实体的验证规则（如非空非重复等）

  10.5. 菜单的配置
• 升级完成后登录系统，新配置的菜单第一次使用时，要在”模块定义”或者”菜单界面”进行模块初始化，初始化完成后关闭界面重新打开（8.2的版本左边模块增加了一个刷新按钮，点击刷新可直接进行菜单配置），进行菜单的配置

 

 
• 保存成功后，刷新浏览器，就可看到刚刚配置的菜单

• 点击缺陷信息和缺陷信息分类，我们的界面就出来



  10.6. 查询面板设置
• 从上面的步骤中可以看出，我们的界面是出来了，还缺少左边的查询条件，现在把界面的查询块配置上去，把实体类上面的[CriteriaQuery]取消注释，这个特性是配置“自动生成查询面板界面”
 
 
• 在viewconfig中配置查询视图

 
• 配置完成后运行项目，界面就出来了

这样一个基础的界面就开发完成了，并且可以进行增删改操作
  10.7. 下拉选择框配置
下拉列表的处理，如下图，缺陷责任关联缺陷分类下拉列表的选择框列显示不出来

需要在缺陷信息分类中ConfigSelectionView中配置下拉选择的列，如图


配置选择后回填的信息，在实体中配置显示名称DisplayMember。

  10.8. 说明
1．实体必须标记为根实体（RootEntity）/子实体（ChildEntity），序列化（Serializable）
2．所有的实体都是部分类，实体继承DataEntity。如：public partial class DefectCategory : DataEntity
3．配置查询面板，框架自带的查询标记特性：[CriteriaQuery]；自定义的查询标记特性：[ConditionQueryType(typeof(NameDemoCriteria))]

 
4．配置下拉列表选择后的显示内容：在实体上标记特性DisplayMember

如果没有配置，下图标记出来的地方带不出来值 

 
5.  实体配置说明

 
6. 界面说明：继承WebViewConfig
 

 


11. 主从表的实现
以供应商为例，实现一个主从结构的功能，供应商以表单的形式添加
  11.1. 类图关系
类图关系如下：

  11.2. 界面效果

供应商与地址关系的新增修改为行内编辑
供应商的新增，修改为表单编辑，表单编辑的界面效果如下：

  11.3. 步骤
• 根据类图生成代码实体和界面，将生成的代码拷贝到对应的工程下，实体拷贝到服务端(SIE.Test),生成的界面拷贝到(客户端)
• 处理完报错的代码，生成不报错，在客户端配置默认菜单
• 运行程序，升级数据库，并配置菜单
• 说明：1.升级数据库时如果未勾选实体元数据复选框，要让界面控件的验证生效，必须在实体元数据中进行初始化
• 配置菜单前要先进行模块初始化
• 设置为表单编辑：View.FormEdit();
• 设置固定列：View.Property(p => p.Code).FixColumn();
• 使用快码编辑器：UseCatalogEditor(e => { e.CatalogType = Supplier.SupperType; e.CatalogReloadData = true; })
CatalogType ：快码的类型，与快码界面主表的编码对应；
CatalogReloadData ：是否实时加载数据，True为实时加载；
快码的实现参考：快码的使用
• 子列表的显示：View.ChildrenProperty

• 设置表单编辑占几列：View.HasDetailColumnsCount(对应的列数);默认为1列显示
• 使用图片编辑器：UseImageComponentEditor(p=> { p.Width = 400;p.Height = 300; })，width和height为图片显示的宽和高
• 设置属性跨行跨列：ShowInDetail(rowSpan: 对应的行数，columnSpan：对应的列数)


• 明细启用/禁用按钮的设置：参考   命令》启用禁用命令的使用

  11.4. 子列表设置为立即保存
View.DefineFormChildSaveMode(MetaModel.View.FormChildSaveMode.Save);

 
 



12. 编辑器
  12.1. 布尔编辑器
实体属性类型为bool类型。
12.1.1. 复选框编辑器 UseCheckEditor()
常用参数：AllowBlank（是否允许为空）、ColumnXType（列的类型）、XType。
View.Property(p => p.Check).UseCheckEditor(p => p.ColumnXType = "customCheckColumn");
12.1.2. 布尔下拉属性编辑器 UseCheckDropDownEditor()
常用参数：AllowBlank（是否允许为空）、Editable（是否可编辑）、ColumnXType（表格列类型）。
  12.2. 文本编辑器
实体属性类型为String类型。
    12.2.1. 字符串属性编辑器 UseTextEditor()
常用参数：AllowBlank（是否允许为空）、Grow(设置字段是否根据内容伸缩)、MaxLength(最大长度)、MasLengthText(最大长度验证失败提示信息)、MinLenght（最小长度）、MinLenghtText(最小长度验证失败提示信息)。
    12.2.2. 文本范围编辑器 UseTextRangeEditor()
常用参数：FirstText：开始值；LastText ：结束值，该编辑器用的比较少。
 
      12.2.2.1. textrange查询范围的使用
该使用在8.3及以上版本不支持。
• 框架自带查询实体类，直接在ConfigQueryView方法中配置UseTextRangeEditor()
配置具体的值：.UseTextRangeEditor(p => { p.FirstText = "1231"; p.LastText = "2342"; })
FirstText：开始值；LastText ：结束值
• 自定义的查询实体类的文本范围使用
  • 自定义一个查询实体类，不实现查询方法
 

  • 定义一个工厂，在工厂中实现查询方法
 


  • 在查询实体界面配置UseTextRangeEditor

  • 效果




    12.2.3. 密码属性编辑器 UsePasswordEditor()
常用参数：AllowBlank（是否允许为空）、Grow(设置字段是否根据内容伸缩)、MaxLength(最大长度)、MasLengthText(最大长度验证失败提示信息)、MinLenght（最小长度）、MinLenghtText(最小长度验证失败提示信息)。
    12.2.4. 备注属性编辑器(大文本编辑器) UseMemoEditor()
常用参数：AllowBlank（是否允许为空），GrowMin和GrowMax为设置大文本框的最小和最大宽高。
。
12.3. 数值编辑器
实体属性类型为数值类型，如int、int？、double、double？、decimal、decimal？。
    12.3.1. 带上下箭头的浮点型数字编辑器 UseSpinEditor()
常用参数：AllowBlank（是否允许为空）、MaxValue(最大值)、MinValue(最小值)、AllowDecimals(是否允许为小数)、DecimalPrecision（小数位数）、AllowNegative（是否允许为负数）、Step（增量设置）。
    12.3.2. 数值范围属性编辑器(支持整型、浮点型) UseSpinRangeEditor()
常用参数：BeginValue（开始值）、EndValue（结束值）、MaxValue(最大值)、MinValue(最小值)、Step(增量)。
  12.4. 日期编辑器
实体属性类型为DateTime。
    12.4.1. 日期属性编辑器 UseDateEditor()
常用参数：AllowBlank（是否允许为空）、MaxValue(最大值)、MinValue(最小值)。
日期格式化：
View.Property(p => p.Property7).UseDateEditor(p => p.Format = "Y/m/d H:i:s");
View.Property(p => p.Property3).UseDateEditor(p => p.Format = "Y-m-d");
    12.4.2. 日期范围编辑器 UseDateRangeEditor():
常用参数：DateFormat（格式化）、AllowBlank（是否允许为空）、MaxValue(最大值)、MinValue(最小值)、DateRangeType(日期范围类型)、StartDate（开始日期）、EndDate（结束日期）。
    12.4.3. 日期时间属性编辑器 UseDateTimeEditor()
常用参数：AllowBlank（是否允许为空）、MaxValue(最大值)、MinValue(最小值)。
    12.4.4. 时间编辑器 UseTimeEditor()
常用参数：AllowBlank（是否允许为空）、MaxValue(最大值)、MinValue(最小值)。
  12.5. 枚举编辑器 UseEnumEditor()
实体属性类型为枚举。
常用参数：AllowBlank（是否允许为空）。
支持带条件查询：UseEnumEditor("CriteriaEntity")

  12.6. 图片编辑器 UseImageComponentEditor()
实体属性类型为byte[]。
常用参数：Width（宽）、 Height（高）; Border（边框）
View.Property(p => p.Photo).UseImageComponentEditor(p => { p.Width = 300; p.Height = 400; p.Border = 1; }).ShowInDetail(rowSpan: 10)
  12.7. 快码编辑器 UseCatalogEditor()
实体类型类型为string。
常用参数：AllowBlank（是否允许为空）、CatalogReloadData（是否实时加载数据）、CatalogType（快码类型）
使用示例：

在实体中定义快码的类型

使用快码的属性为一般属性

 
    12.7.1. 快码的使用
• 添加快码组
需要建一个初始化数据的类，放在服务端

命名规范：前面部分必须为“_年月日_时分秒”的格式，这里的时间必须是整个解决方法最新的时间，可以设置大些的时间
• 初始化快码组数据的代码实现
using SIE.Common.Catalogs;  
using SIE.CSM.Suppliers;  
using SIE.Data.DbMigration;  
using SIE.Domain;  
using System.Linq;  
  
namespace SIE.CSM.DbMigrations  
{  
    /// <summary>  
    /// 初始化  
    /// </summary>  
    public class _20180401_200001_InitCatalogType : ManualDbMigration  
    {  
        /// <summary>  
        /// 数据库设置  
        /// </summary>  
        public override string DbSetting  
        {  
            get { return CSMEntityDataProvider.ConnectionStringName; }  
        }  
  
        /// <summary>  
        /// 描述  
        /// </summary>  
        public override string Description  
        {  
            get { return "添加快码"; }  
        }  
  
        /// <summary>  
        /// 手动升级的类型：数据  
        /// </summary>  
        public override ManualMigrationType Type  
        {  
            get { return ManualMigrationType.Data; }  
        }  
  
        /// <summary>  
        /// 不支持 Down  
        /// </summary>  
        protected override void Down() { }  
  
        /// <summary>  
        /// 注入  
        /// </summary>  
        protected override void Up()  
        {  
            this.RunCode(db =>  
            {  
                ////由于本类没有支持 Down 操作，所以这里面的 Up 需要防止重入。  
                AppRuntime.InvOrg = 1;   
                ////获取快码组列表  
                if (RT.Service.Resolve<CatalogController>().GetCatalogTypeList().FirstOrDefault(p => p.Code == Supplier.SupperType) == null)  
                {  
                    RF.Save(new CatalogType()  
                    {  
                        Code = Supplier.SupperType,  
                        Name = "供应商类型",  
                        Description = "供应商类型"  
                    });  
                }  
            });  
        }  
    }  
}  
 
 
• 运行升级数据库。
注意事项
1）初始化快码组的数据类时间必须为整个解决方案最新
2）使用了初始化数据的服务端工程，必须要有单独的数据提供者
3）升级数据库的时候必须勾选全部数据库
4）项目上如何没有硬性要求，可直接往数据库快码组表的插入数据，快码组数据的编码与在实体中建的常量的默认值保持一致
• 在实体中定义一个快码类型的常量
public const string SupperType = "SUPPLIER_TYPE";

• 在界面中使用快码
View.Property(p => p.Type).UseCatalogEditor(e => e.CatalogType = Supplier.SupperType);

快码组表名：BD_CATALOG_TYPE
快码明细表名：BD_CATALOG
快码表插入语句（执行sql插入时，CODE的编码要与实体中定义快码的类型保持一致）
insert into BD_CATALOG_TYPE (ID, CODE, CREATE_BY, CREATE_DATE, DESCRIPTION, INV_ORG_ID, IS_PHANTOM, NAME, SYNC_ID, UPDATE_BY, UPDATE_DATE)
values (34, 'Abnormal_Type', 0, to_date('11-07-2019 10:34:15', 'dd-mm-yyyy hh24:mi:ss'), '影响类型', 1, '0', '影响类型', 33, 0,
 to_date('11-07-2019 10:34:15', 'dd-mm-yyyy hh24:mi:ss'));
  12.8. 下拉编辑器 UsePagingLookUpEditor()
使用该编辑器实体属性必须为引用属性。
引用关系框架默认使用该编辑器。
常用参数：AllowBlank（是否允许为空）、Editable （是否可编辑）、XType（控件的类型），DicLinkField（联动字段），DisplayField（显示名称），BindDisplayField（绑定显示名称）。

控件常用配置：
1. 下拉表格配置，在对应引用关系关联的实体对应的ViewConfig中配置选择视图；
界面呈现：

代码实现：

2. 配置选择后回填内容，即：

通过在关联实体上标记特性显示成员DisplayMember进行配置。

效果：

3. 配置下拉列表查询条件


在关联实体上配置QueryMembers。

4. 个性化显示配置
通过在界面中配置编辑器的显示名称DisplayField和绑定显示名称BindDisplayField进行设置

说明：列表个性化显示需要同时配置显示名称DisplayField和绑定显示名称BindDisplayField才会生效；表单配置显示名称DisplayField即会生效；9.1的列表配置个性化显示不生效。


  12.9. 放大镜弹框编辑器 UsePagingLookUpPopupEditor()
实体属性类型为引用属性。
使用：UsePagingLookUpPopupEditor(p => { p.Editable = true; p.EnableDoubleClick = false; p.SelectOnClose = false; })
常用参数：AllowBlank（是否允许为空）、Editable （是否可编辑）、EnableDoubleClick （是否允许双击关闭弹出窗体，默认值true）、SelectOnClose （关闭窗体是否带回选择的值，默认为false，不带回值）、MultiOrSelect（多选或单选设置）
注意：在查询界面使用放大镜多选数据时，需要自定义查询实体，查询实体中的属性ID需要设置为string类型，如下面事例中的ProductId为string类型。
在查询界面使用放大镜多选示例：
1.查询实体引用属性的类型为string类型

2.查询界面的视图配置方法

3.查询实体中调用的查询方法的实现：

4.效果：

 
  12.10. 下拉联动编辑器 
1.UsePagingLookUpLinkEditor()（8.2之前版本）
使用：使用下拉列表联动必须要有关联关系才能使用
View.Property(p => p.Supplier).HasLabel("供应商").UsePagingLookUpLinkEditor((m, e) =>
{
     var keyValues = new Dictionary<string, string>();
     keyValues.Add(nameof(e.SupplierName), nameof(e.Supplier.Name));
     keyValues.Add(nameof(e.SupplierDesc), nameof(e.Supplier.Desc));
     m.LinkField = keyValues;
});
选择供应商带出供应商名称

供应商名称是配置的视图属性（视图属性不映射数据库），代码段使用pfv

与CS如下写法的效果是一样的（BS不支持该写法）

2. UsePagingLookUpEditor()（8.2版本及以上）
	8.2及以上版本的联动实现和下拉列表编辑器合并一起了，使用示例如下：

	CriticalEventFlowName为视图属性，CriticalEventFlow为引用属性



  12.11. 自定义编辑器（下拉列表）
说明：BS正常情况下，自定义编辑器只需要重写数据源部分即可，特殊需求才会重写JS部分
• 自定义编辑器重写数据源的使用示例
新建一个静态的扩展类，在扩展类中实现编辑器

• 在viewconfig中使用编辑器
View.Property(p => p.ProductCategory).HasLabel("产品分类").UseProCatEditor();
  12.12. 使用编辑器控件类型使用示例
说明：有时候重写数据源获取不到数据或者是获取数据和查询异常，可以使用这种方式实现
• 定义一个js文件，继承SIE.control.ComboList，定义一个别名
Ext.define('SIE.Web.Collection.OutputCollections.Control.WorkOrderComboList', {  
    extend: 'SIE.control.ComboList',  
    alias: 'widget.workOrdercombolist',  
    triggerCls: "x-form-arrow-trigger",  
    _onSearchBoxTriggerClick: function (pageNum) {  
        pageNum = pageNum || 1;  
        var me = this;  
  
        if (me.queryMode == 'remote') {  
            me._searchByDSP(pageNum);  
        }  
        else {  
            me.doLocalQuery();  
        }  
    },  
    _searchByDSP: function (pageNum) {  
        //继承时发现_isQuerySelectItems偶尔会未定义，而基类又会直接使用_isQuerySelectItems，使得报错。所以这里再定义一次。  
        if (typeof (_isQuerySelectItems) === "undefined")  
            _isQuerySelectItems = this._isQuerySelectItems;  
        var me = this,  
            dsp = this.dataSourceProperty;  
  
        var sieView = me._getSIEView();  
        if (!sieView) {  
            me._searchByRawValue();  
            return;  
        }  
        var filter = {};  
          
        var workstation = sieView._children[1].getData();  
        var searchValue = me.cbSearch.getRawValue();  
        me._view.loadData({  
            action: 'queryer',  
            type: 'SIE.Web.Collection.OutputCollections.DataQueryer.WorkOrderStandardDataQueryer',  
            filter: Ext.encode({ Method: 'GetWorkorder', Parameters: [workstation.data.ResourceId, pageNum, me.pageSize, (searchValue ? '%' + searchValue + '%' : '')] })  
        });  
        me._lastSearchValue = searchValue;  
    },  
});  
• WorkOrderStandardDataQueryer的实现
using SIE.Collection;  
using SIE.Domain;  
using SIE.MES.WorkOrders;  
using SIE.Resources.Employees;  
using System;  
using System.Collections.Generic;  
using System.Linq;  
using System.Text;  
using System.Threading.Tasks;  
  
namespace SIE.Web.Collection.OutputCollections.DataQueryer  
{  
    public class WorkOrderStandardDataQueryer : Data.DataQueryer  
    {  
        public EntityList GetWorkorder(double resourceId, int pageIndex, int pageSize, string keyword)  
        {  
            SIE.Resources.Employee emp = RT.Service.Resolve<EmployeeController>().GetLoginUserEmployee();  
            if (resourceId != 0)  
            {  
                var pagingInfo = new PagingInfo(pageIndex, pageSize, true);  
  
                return RT.Service.Resolve<ManufactureCollectionController>().FilterWorkorders(resourceId, emp, pagingInfo, keyword);  
            }  
            else  
            {  
                return new EntityList<WorkOrder>();  
            }  
        }  
    }  
}  
 
• 在下拉列表编辑器中使用该类型
View.Property(p => p.WorkOrder).UsePagingLookUpEditor(p => p.XType = "workOrdercombolist");
 
  12.13. 树形列表下拉列表
• 说明：树形列表（如企业模型）不能重写数据源使用过滤条件进行过滤，如果过滤了，会因为找不到父id而抛异常
• 在BS中如下实现查询会异常（CS中使用的是dev的控件，如果加了过滤条件会自动变成普通下拉列表；BS的不会，还会去找父id，找不到就异常）：


 

 

 
如果要实现树形列表按条件过滤，要转换为普通列表。
实现方式：以企业模型为例。
    12.13.1. 实现方式一
/// <summary>  
/// 资源车间下拉编辑器  
/// </summary>  
/// <typeparam name="T">实体类型</typeparam>  
/// <param name="meta">属性视图元数据</param>  
/// <param name="action">委托</param>  
/// <returns>泛型属性视图元数据</returns>  
public static WebEntityPropertyViewMeta<T> UseShopLookUpEditor<T>(this WebEntityPropertyViewMeta<T> meta, Action<ComboListConfig> action = null)  
{  
    meta.UseDataSource((source, pagingInfo, keyword) =>  
    {  
        var enterpriseList = RT.Service.Resolve<EnterpriseController>().GetEnterprises(EnterpriseType.Shop, pagingInfo, keyword);  
        if (enterpriseList == null || enterpriseList.Count <= 0)  
            return new EntityList<Enterprise>();  
        for (var i = 0; i < enterpriseList.Count; i++)  
        {  
            enterpriseList[i].TreePId = null;  
        }  
  
        return enterpriseList;  
    }).UsePagingLookUpEditor(action);  
    return meta;  
}
    12.13.2. 实现方式二
• 1）重新定义一个实体类，继承Enterprise
• 2）实体配置中不要支持树
如企业模型中是支持树的，新建的实体类就不要去支持树了

• 为该实体配置界面
• 在使用界面中的属性关联企业模型改成关联新建的这个实体类
• 新建一个静态的扩展类，在扩展类中实现编辑器，在编辑器中处理数据源部分
• 使用编辑器
12.14. 自定义文本按钮编辑器UseTextButtonFieldEditor
在Viewconfig对应属性中使用UseTextButtonFieldEditor，指定编辑器的ExtendJsObj属性；

ExtendJsObj属性指定文件的前端js实现：

13. 框架常用Api
13.1. 实体常用设置
1. 创建实体的属性，我们只建业务相关的属性，业务属性不要和框架属性命名冲突，框架定义的属性包括：Id，CreateBy，CreateDate，InvOrgId，IsPhantom，SyncId，UpdateBy，UpdateDate。

2. 映射数据库表：Meta.MapTable(“RES_EMP_GROUP”)；
3. 映射视图：
直接读取数据库的视图：Meta.MapView(“V_RES_EMP_GROUP”)；
通过sql查询出来的视图：Meta.MapView(“(SELECT * FROM RES_EMP_GROUP)”)；
通过DB.Query查询出来的视图：
	Func<IQuery> view = () => DB.Query<Enterprise>()
              .Where(p => p.Level.IsResource == true && p.InvOrgId == RT.InvOrgId)
              .ToQuery();
          Meta.MapView(view);// 影射一条IQuery查询的视图，注意查询中不能出现当前实体，否则会出现死循环。
4. 映射实体中的所有字段：Meta.MapAllProperties();
5. 设置属性映射数据库的长度：Meta.Property(Employee.CodeProperty).MapColumn().HasLength(50);
6. 指定某个属性不映射数据库字段：Meta.Property(Employee.ExpectQtyExtProperty).DontMapColumn();
7. 创建唯一索引：Meta.IndexUniqueGroupOnProperties(DispatchTask.UpdateDateProperty);

8. 创建组合索引：Meta.IndexGroupOnProperties(DefectsInIqcBillDetails.YearProperty, DefectsInIqcBillDetails.MonthProperty,  DefectsInIqcBillDetails.DayProperty)

9. 忽略映射外键：IgnoreFK；
Meta.Property(SupplierShipBill.MasterBillIdProperty).ColumnMeta.IgnoreFK();
10. 启用假删除：Meta.EnablePhantoms();
11. 禁用假删除：Meta.DisablePhantoms()；
12. 启用库存组织：Meta.EnableInvOrg();
13. 禁用库存组织：Meta.DisableInvOrg()；
14. 启用实体排序：Meta.EnableSort();
15. 禁用实体排序：Meta.DisableSort();
16. 启用树形插件：Meta.SupportTree();
17. 启用实体编辑日志记录插件：Meta.EnableEntityLog();
18. 启用数据同步插件：Meta.EnableDataSync();
19. 启用实体鉴别器：Meta.EnableDiscriminator("PersonAttachment");
13.2. ViewConfig的视图说明
1. 界面视图继承：WebViewConfig<T>；
2. 视图配置的方法
1）配置视图：ConfigView，界面的入口，具体视图的列和命令操作配置不要在该方法中进行配置；
2）列表视图配置：ConfigListView；
3）表单视图配置：ConfigDetailsView，需要配置编辑模式为表单编辑（View.FormEdit()）才会进入，需要注意的是一定要先使用编辑模式，再使用默认命令集，否则会出异常；
4）查询视图配置：ConfigQueryView；查询命令中不要使用默认命令集，否则权限会多出一个view的权限配置；
5）下拉视图配置：ConfigSelectionView，下拉视图中不用配置操作命令；
6）导入视图配置：ConfigImportView()，导入命令中不用配置命令；
7）自定义视图配置：使用默认命令集(View.UseDefaultCommands())不生效，要把自定义分组添加到额外的分组（DeclareExtendViewGroup）里面，配置具体的列要加Show。
13.3. ViewConfig界面常用设置
1. 授权可信的实体：View.AssignAuthorize(typeof(实体名))；
2. 定义额外的视图，用于加载权限信息，生成授权界面：View.DeclareExtendViewGroup()；
3. 表格设置不使用分页：View.WithoutPaging();
4. 使用行为： View.AddBehavior("行为js的全名称空间");
5. 使用默认命令集： View.UseDefaultCommands();
6. 移除命令： View.RemoveCommands(WebCommandNames.Copy);
7. 使用命令： View.UseCommands(WebCommandNames.Save);
8. 替换命令： View.ReplaceCommands(WebCommandNames.Delete, typeof(DeleteGoodCommand).FullName);
9. 清除所有命令： View.ClearCommands()；
10. 设置列表为内存排序：View.UseClientOrder();
11. 设置父子的分布比列：View.UseLayoutSize(0.4, 0.6); 默认按1：1展示；
12. 设置表单显示列数：View.HasDetailColumnsCount(2);
13. 设置子列表水平布局：View.UseChildrenAsHorizontal();
14. 禁止树节点拖动：View.DraggableForTree();
15. 设置不允许编辑：View.DisableEditing();
16. 设置属性视图元数据： View.Property， View.ChildrenProperty和附加子属性视图元数据；
17. 表格列分组的使用：using (View.DeclareBand(“test”))；


18. 表单设置分组的使用：using (View.DeclareGroup("提示信息"))；
19. 设置列表的行选择模式：View.UseGridSelectionModel();
20. 设置当前界面需要额外引用的实体：View.RequierModels(typeof(FirstInspVal), typeof(PqcStandardDocumentAttachment));

13.4. ViewConfig属性常用设置

1. 设置列宽：ShowInList(width: 300)；
2. 设置列显示位置：View.Property(p => p.Describe).HasOrderNo(4);
3. 冻结列设置：FixColumn()；
4. 是否只读和是否可见：BS只支持表达式，CS中通过扩展只读属性控制是否只读和可见在BS中不能使用，是否可见在表格中只支持true和false
.Readonly(p => p.PropertyType != ItemPropertyType.Catalog)
.Visibility(p => p.PersistenceStatus != Domain.PersistenceStatus.New)

PersistenceStatus 为当前操作的状态，包括Unchanged、Modified、New、Deleted四种状态
5. 行内联动

6. 引用属性使用自定义数据源:View.Property(p => p.Supplier).UseDataSource()


7. 表单设置换行
BS表单设置换行需要在要设置换行的列的前一列设置对应的列宽和列所占的宽度；
如下图希望工单另起一行，需要设置工单上面的一列占满整行和这一列显示的宽度

需要注意的是：这里的width最好设置为百分比（因为电脑的分辨率不一致），width的百分比的比例是显示的宽度占设置列的多少。
效果：

8. 查询条件必填配置，在查询界面对应的属性中使用对应的编辑器，在编辑器中设置不允许为空的属性View.Property(p => p.Code).UseTextEditor(p => p.AllowBlank = false);
9. 后端获取实体的操作状态：p. PersistenceStatus=PersistenceStatus.New;PersistenceStatus 为当前实体的操作状态，包括Unchanged、Modified、New、Deleted四种状态。

13.5. JS常用设置
1. 设置保存：entity.markSaved()；
2. 添加提示进度条
SIE.Msg.wait('正在执行实体元数据初始化操作，请稍候...');

3. 关闭当前打开的tab页签：CRT.Workbench.closeCurrentTab();
4. Js或者当前操作数据是新增还是修改
[表格 3 行]
5. 视图view的方法
• 获取父视图：view. getParent();
• 获取子视图：view. getChildren()；
• 获取当前实体：view. getCurrent();
• 刷新数据，DetailView需要传实体id参数：view. refreshData();
• 加载子视图数据：view. loadChildData(),可以调用，查询当前打开子数据，view. loadChildData(true)不管子页签有没有打开，都加载子视图数据；
• 刷新视图命令状态：view. syncCmdState();
• 获取视图对应的界面元素：view. getControl();
• 获取视图对应的客户端元数据：view. getMeta();
• 获取界面对应数据：view. getData();
• 设置界面对应数据：view.setData();
• 获取票据：view. getToken();
• 查找命令：view.findCmd()；
• 根据实体类型查找子实体视图：view. findChild("实体的全命名空间");
• 刷新列表数据：view.refreshData();或CRT.Event.fire(Ext.String.format('{0}_refresh', view.model), entity.data.Id);
• 刷新表单数据：view.refreshData(entity.data.Id);或CRT.Event.fire(Ext.String.format('{0}_{1}_refresh', view.model, entity.data.Id), entity.data.Id);
6. 消息提示方法
• 显示消息：SIE.Msg. showMessage(msg, ok_fn);
• 显示错误消息：SIE.Msg. showError(msg);
• 显示警告消息：SIE.Msg. showWarning(msg);
• 询问消息：SIE.Msg. askQuestion(msg, ok_fn, cancle_fn);
• 倒计时提示信息：SIE.Msg. showInstantMessage(msg, title, timeout, ok_fn);
• 确认提示：SIE.Msg. confirm(msg, fn);
• 等待进度条提示信息：SIE.Msg. wait(message, title, config);无关闭按钮；
• 等待进度条提示信息：SIE.Msg. progress(title, message, progressText);有关闭按钮；
• 隐藏消息框：SIE.Msg. hide();
• 关闭消息框：SIE.Msg. close();
• SIE.Msg. showToast(html, title);
7. 获取视图元数据：SIE.AutoUI.getMeta；
8. 前端获取登录人：
var currentUser = CRT.Context.GlobalContext.getContext('userInfo');
var userName = currentUser.Name;
9. 获取addPage传过来的参数：CRT.Context.PageContext.getParams();
10. 获取表单控件：view.getControl().getForm().getFields();
13.6. 使用自定义分组
14.7.2.1. 在界面中定义一个分组的常量

14.7.2.2. 在具体的列表中使用分组

14.7.2.3. 在使用分组界面的配置视图中添加扩展分组，分组中调用方法实现具体的界面展示；
View.DeclareExtendViewGroup(new string[] { BaseDataViewGroup ，DesignDataViewGroup});
View.DeclareExtendViewGroup(nameof(SupplierUser));

自定义分组不加DeclareExtendViewGroup，界面的操作按钮显示不出来

13.7. 实体和界面的默认值设置
13.7.1. 后端默认值设置
实体和ViewConfig中设置默认值都是通过DefaultValue进行设置的，实体的默认值设置的作用域比ViewConfig中设置作用域要大。
13.7.1.1. 实体默认值设置
1. 普通属性默认值设置


2. 枚举默认值设置

13.7.1.2. ViewConfig默认值设置
1. String属性类型的默认值设置：View.Property(p => p.Name). DefaultValue(“Test”);
2. 枚举默认值的设置：View.Property(p => p.Name).DefaultValue((int)ItemType.Product);
3. 下拉列表默认值设置，请求后台数据库赋值：
View.Property(p => p.EmpId).DefaultValue(RT.Service.Resolve<EmployeeController>().GetLoginUserEmployee())
GetLoginUserEmployee方法在服务端控制器实现，如下：
public virtual SIE.Resources.Employee GetLoginUserEmployee()  
{  
    var employee = RF.GetById<SIE.Resources.Employee>(RT.IdentityId);  
    return employee;  
} 
4. 界面设置当前日期：View.Property(p => p.Date).DefaultValue(System.DateTime.Today).UseDateEditor();
5. 设置当前时间：View.Property(p => p.DateTime).DefaultValue(DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")).UseDateTimeEditor();
13.7.2. 前端js默认值设置
默认值前端js没有提供设置的方法，设置默认值和设置值我们都是通过设置数据行的属性，设置如下：
1. entity.set('属性名', value);
2. entity.set属性名(value);
说明：在前端设置引用属性的默认值，除了设置id的默认值，还要设置对应显示名称的默认值，如果id为UnitId，则显示名称的命名为UnitId_Display。

13.7.3. 在8.1之前版本前端默认值实现说明

前端默认值设置，表格和表单是分开的
框架的表格和表单编辑是会默认去调用默认值设置的
13.7.3.1. 表格编辑框架默认值设置

• 在addNew方法中会去调用默认值

 
如果重写了该方法，要实现默认值的设置，需要手动去调用该方法
13.7.3.2. 表单编辑框架默认值设置

• 在创建DetailView时会去调用默认值设置


13.7.3.3. 自定义界面默认值设置
如果是自定义的界面，重写了showView，需要手动去调用表单编辑的默认值设置



