# 实体建模·属性·标签·配置·UML-ModelFirst

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch6-7
> **提取范围**：docx 正文行 711-1018
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

6. 实体建模
SMOM实体建模是以模型为中心，先通过UML建模，模型生成代码，代码生成数据库的方式实现快速开发。
  6.1. 实体定义
实体是指通过面向对象的方式描述有唯一主键的数据结构。实体都继承自Entity或其子类。实体主要包含以下特点：
• 面向对象：支持继承、多重性关联（一对一、一对多、多对多）等面向对象的描述方式。
• 支持数据影射：支持针对关系型数据库的影射和持久化。
• 数据传输：支持二进制、JSON、XML格式的序列化和反序列化。
• 数据双向绑定：支持WPF前端的数据双向绑定。
实体结构类图：

  6.2. 实体分类
• 实体按关联关系分为根实体、子实体。
• 根实体：表示一对多聚合关系的根，使用RootEntityAttribute特性标记。实体元数据初始化时会从所有的根实体开始解析。
• 子实体：表示一对多聚合关系的子，使用ChildEntityAttribute特性标记。子实体必须有唯一个引用属性指向其父实体。

  6.3. 实体按功能划分为业务实体、查询实体、视图模型。
• 业务实体：描述业务数据结构的实体，通常影射数据库。
• 查询实体：表示实体对应的查询条件，使用QueryEntityAttribute特性标记。注意：6.1+版本的查询条件可以不使用查询实体，直接通过配置查询视图，使用CriteriaQuery标准查询实现数据查询。
• 视图模型：ViewModel通过用于生成界面，不影射数据库。
  6.4. 实体仓库
实体仓库用于实现实体的存取（持久化），每个类型的实体都有一个单例的仓库，实体仓库都继承自EntityRepository或其子类。仓库的方法支持分布式远程调用。实体与仓库类型的关系契约如下：
• 命名规则：在相同程序集，相同命名空间下，命名为实体名称+Repository后缀的类被视为相应实体的仓库。例如 RBAC.UserRepository为RBAC.User的仓库。
• 特性标记：在仓库上使用RepositoryForAttribute标记对应的实体类型。或在实体上使用EntityMatrixAttribute标记实体对应的仓库类型。
• 默认仓库：按上述1、2两种方式都找不到实体对应的仓库时，使用默认的仓库类型，如果实体User使用EntityRepository作为其仓库。
【注意】建议使用默认的实体仓库，特殊的查询逻辑在控制器实现
public void RepoDemo()
{
    //仓库是单例的，需要通过静态方法找对类型对应的仓库
    var repo = RF.Find<User>();
    //通过ID获取实体, eagerLoad用于指定贪婪加载
    var user = repo.GetById(id, eagerLoad);
    //获取实体列表, pagingInfo用于指定分页信息， eagerLoad用于指定贪婪加载
    var users = repo.GetAll(pagingInfo, eagerLoad);
    //实体的保存直接使用Save即可
    RF.Save(user);
}
  6.5. 实体列表
实体列表是实体的集合类型。实体列表都继承自EntityList或其子类。实体与列表类型的关系契约如下：
• 命名规则：在相同程序集，相同命名空间下，命名为实体名称+List后缀的类被视为相应实体的列表。例如 RBAC.UserList为RBAC.User的列表类型。
• 特性标记：在实体上使用EntityMatrixAttribute标记实体对应的列表类型。
• 默认仓库：按上述1、2两种方式都找不到实体对应的列表时，使用默认的列表类型，例如实体User使用EntityList<User>作为其列表。
  6.6. 实体属性
实体通过实现ICustomTypeDescriptor接口重新定义了实体的属性系统。通过注册的方式把属性注册到实体属性仓库中，所有属性注册完成后，通过编译，生成实体类型对应的属性容器。
    6.6.1. 普通属性
实体的直接属性，通常是能映射数据库的基类数据类型。通过P.Register()方法注册。
    6.6.2. 列表属性
实体的子属性，表示一对多关联关系。通过P.RegisterList()方法注册。
    6.6.3. 引用属性
实体的引用属性，表示一对一关联关系，引用ID与引用实体必须成对出现。通过P.RegisterRefId()方法注册引用ID，通过P.RegisterRef()方法注册引用实体。
    6.6.4. 视图属性
实体的视图属性，用于显示引用属性实体中字段，通过P.RegisterView()方法注册。在实体加载时，通过贪婪加载参数[EagerLoadOptions.LoadWithViewProerty()]指定加载视图属性。视图属性的加载通过JOIN的SQL语句加载，避免N+1查询，可有效果提高数据加载的性能。视图属性不能编辑。
    6.6.5. 只读属性
实体的只读属性，用于在内存中计算属性的值，通过P.RegisterReadOnly()方法注册。例如对实体中的普通属性进行计算与格式化显示。【特别注意】不要在只读属性中访问数据库，会引用N+1的属性问题。
属性结构类图：

 
• 属性容器
var user = new User();
//通过实体实例中的属性容器获取所有托管属性
var propertiesFromInstance = user.PropertyContainer.GetProperties();
//通过实体元数据中的属性容器获取所有托管属性
var propertiesFromEntityMeta = CommonModel.Entities.Find(typeof(User)).ManagedProperties.GetProperties();
• 普通属性注册
//托管属性的注册
public static readonly Property<string> NameProperty = P<User>.Register(e => e.Name);
//托管属性的包装器，通过CLR属性访问托管属性
public string Name
{
  get { return this.GetProperty(NameProperty); }
  set { this.SetProperty(NameProperty, value); }
}
• 视图属性注册
public static readonly IRefIdProperty UserIdProperty = P<UserInUserGroup>.RegisterRefId(e => e.UserId, ReferenceType.Normal);
public double UserId
{
  get { return (double)GetRefId(UserIdProperty); }
  set { SetRefId(UserIdProperty, value); }
}
public static readonly RefEntityProperty<User> UserProperty = P<UserInUserGroup>.RegisterRef(e => e.User, UserIdProperty);
public User User
{
  get { return GetRefEntity(UserProperty); }
  set { SetRefEntity(UserProperty, value); }
}
// 视图属性的注册，把引用实体User的Code属性加载到当前实体
public static readonly Property<string> UserCodeProperty = P<UserInUserGroup>.RegisterView(e => e.UserCode, p => p.User.Code);
public string UserCode
{
  get { return this.GetProperty(UserCodeProperty); }
}
• 普通引用属性注册。引用属性包含ID引用和实体引用，ID引用影射数据库字段，实体引用默认使用懒加载，除非指定贪婪加载。
//引用属性需要增加一个ID引用
public static readonly IRefIdProperty RoleIdProperty = P<User>.RegisterRefId(e => e.RoleId, ReferenceType.Normal);
public int RoleId
{
  get { return (int)this.GetRefId(RoleIdProperty); }
  set { this.SetRefId(RoleIdProperty, value); }
}
//引用属性的注册
public static readonly RefEntityProperty<Role> RoleProperty = P<User>.RegisterRef(e => e.Role, RoleIdProperty);
public Role Role
{
  get { return this.GetRefEntity(RoleProperty); }
  set { this.SetRefEntity(RoleProperty, value); }
}
• 主从关系(一对多)的属性注册。主从关联使用双向关联，主实体会包含从实体列表，从实体包含主实体引用，且引用类型为Parent
/// <summary>
/// 物料分组
/// </summary>
[RootEntity,Serializable]
public class ItemGroup : Entity<double>
{
  #region Item列表 ItemList
  /// <summary>
  /// 物料列表
  /// </summary>
  public static readonly ListProperty<EntityList<Item>> ItemListProperty = P<ItemGroup>.RegisterList(e => e.ItemList);
  /// <summary>
  /// 物料列表
  /// </summary>
  public EntityList<Item> ItemList
  {
      get { return this.GetLazyList(ItemListProperty); }
  }
  #endregion
}
/// <summary>
/// 物料
/// </summary>
[ChildEntity,Serializable]
public class Item : Entity<double>
{
  #region ItemGroup ItemGroup
  /// <summary>
  /// 分组ID
  /// </summary>
  public static readonly IRefIdProperty ItemGroupIdProperty = P<Item>.RegisterRefId(e => e.GroupId, ReferenceType.Parent);
  /// <summary>
  /// 分组ID
  /// </summary>
  public double GroupId
  {
      get { return (double)this.GetRefId(ItemGroupIdProperty); }
      set { this.SetRefId(ItemGroupIdProperty, value); }
  }
  /// <summary>
  /// 分组
  /// </summary>
  public static readonly RefEntityProperty<ItemGroup> ItemGroupProperty = P<Item>.RegisterRef(e => e.Group, ItemGroupIdProperty);
  /// <summary>
  /// 分组
  /// </summary>
  public ItemGroup Group
  {
      get { return this.GetRefEntity(ItemGroupProperty); }
      set { this.SetRefEntity(ItemGroupProperty, value); }
  }
  #endregion
}
• 只读属性。只读属性应该只限于内存计算的结果，避免访问数据库，否则会影射加载的性能。
/// <summary>
/// 描述
/// </summary>
public static readonly Property<string> DescriptionProperty = P<Item>.RegisterReadOnly(
  e => e.Description, e => e.GetDescription(), NameProperty, CodeProperty, QtyProperty);
/// <summary>
/// 描述
/// </summary>
public string Description
{
  get { return this.GetProperty(DescriptionProperty); }
}
private string GetDescription()
{
  return "{0}[{1}]({2}PCS)".FormatArgs(Name, Code, Qty);
}
  6.7. 实体标签
6.7.1. 实体成员显示标签（DisplayMemberAttribute）
用于在实体上声明实体被引用时显示哪个属性的值，注意显示的成员必须是普通属性，不能把引用属性当显示成员。
6.7.2. 实体名称标签（LabelAttribute）
用于在实体上声明实体的显示名称。
6.7.3. 实体类型标签（RootEntityAttribute, ChildEntityAttribute, QueryEntityAttribute）
用于在实体上声明实体的类型。
6.7.4. 实体序列化标签（SerializableAttribute）
用于在实体上声明实体可序列化。
6.7.5. 实体通用查询标签（CriteriaQueryAttribute）
用于在实体上声明实体的查询使用通过查询条件。
6.7.6. 实体查询标签（ConditionQueryTypeAttribute）
用于在实体上声明实体使用的查询实体类型。
6.7.7. 实体属性名称标签（LabelAttribute）
用于在实体属性上声明属性的显示名称
6.7.8. 实体属性验证规则标签
验证规则标签声明后，规则并不会马上生效，需要在实体元数据模块进行初始化后才会生效。【注意】验证规则修改后，服务需要重启才能保证规则生效，因为规则会缓存在服务上，服务是集群的，不重启不能保证所有服务上的规则都刷新。验证规则标签包括：
• RequiredAttribute：声明实体属性不能为空。
• NotDuplicateAttribute：声明实体属性不能重复。
• MaxLengthAttribute：声明实体属性的最大长度，只对字符串类型的属性有效。
• MinLengthAttribute：声明实体属性的最小长度，只对字符串类型的属性有效。
• MaxValueAttribute：声明实体属性的最大值。
• MinValueAttribute：声明实体属性的最小值。
  6.8. 实体配置
在实体配置类EntityConfig可以对实体的验证规则、实体影射进行配置
• 实体映射配置：重写ConfigMeta()方法，可实现实体的影射表、字段、实体插件等的配置。
• 实体的验证规则：重写AddValidations()方法，可实现实体的验证规则配置。
• 影射表
protected override void ConfigMeta()
{
          Meta.MapTable("RES_EMP_GROUP");//映射数据库表
}
• 映射视图
protected override void ConfigMeta()
{
          Meta.MapView("V_RES_EMP_GROUP");//映射数据库中的视图
}
protected override void ConfigMeta()
{
          Meta.MapView("(SELECT * FROM RES_EMP_GROUP)");//映射一条查询语句的视图，注意语句需要使用括号括起来
}
protected override void ConfigMeta()
{
          Meta.MapView("(SELECT * FROM RES_EMP_GROUP)");//映射一条查询语句的视图，注意语句需要使用括号括起来
}
protected override void ConfigMeta()
{
          Func<IQuery> view = () => DB.Query<Enterprise>()
              .Where(p => p.Level.IsResource == true && p.InvOrgId == RT.InvOrgId)
              .ToQuery();
          Meta.MapView(view);// 映射一条IQuery查询的视图，注意查询中不能出现当前实体，否则会出现死循环
}
• 映射属性
protected override void ConfigMeta()
{
          Meta.MapAllProperties();//影射实体中的所有字段
          Meta.Property(Employee.CodeProperty).MapColumn().HasLength(50);//影射实体中的指定属性
}
• 实体插件
protected override void ConfigMeta()
{
          Meta.EnablePhantoms();//启用假删除插件
          Meta.EnableInvOrg();//启用库存组织插件
          Meta.EnableEntityLog();//启用实体编辑日志记录插件
          Meta.EnableDataSync();//启用数据同步插件
          Meta.EnableSort();//启用实体排序插件
          Meta.EnableTimeStamp();//启用实体时间戳插件
          Meta.EnableVersion();//启用实体版本插件
}
• 实体验证
protected override void AddValidations(IValidationDeclarer rules)
{
          rules.Add(new NotDuplicateRule
          {
              Properties = { ConfigDetail.ConfigIdProperty, ConfigDetail.CategoryProperty },
              MessageBuilder = (e) => "类型不能重复".L10N()
          });
}

7. 实体的UML设计(ModelFirst的使用)
意义
注意：使用modelfirst建模时，右边preject工程的层级最好跟项目的层级保持一致，这样生成的实体类拷贝到项目中就不用一个个去修改命名空间，也可以防止改漏的命名空间而引发的问题。
  7.1. 下载路径
[OLE: Package]
将文件解压保存到本地，通过《EAP.ModelFirst.exe》启动ModelFirst，可以将《EAP.ModelFirst.exe》发送到桌面快捷方式，方便使用。
  7.2. 创建实体
开发中的实体基本都是使用代码生成器自动生成的。
• 新建工程，双击创建类图

 
• 在左边菜单的工具箱中选中“类”，并把其拖到类图中，或选中项目右键新建“Class”

• 双击工程项目下的类进行相关信息编辑 

每增加一个属性可以在属性列表处点击“新属性”的图标进行新增。
• 编辑完成后，选中需要生成的实体点击项目总管栏上的生成图标，选择相应要生成的实体模版， 

说明：
• 使用modelfirst建模时，右边preject工程的层级最好跟项目的层级保持一致，这样生成的实体类拷贝到项目中就不用一个个去修改命名空间，也可以防止改漏的命名空间而引发的问题；
• 使用ModelFirst建立模型，我们只使用到了类和枚举，接口和控制器等不要在类图中体现；
• 属性名不能命名为Id,因为框架表的主键设置的为Id,这里的属性只建业务相关的属性，框架级别通用的属性框架有统一处理；
• 在实体建模中关系基本用到的为关联关系和组合关系；
• 常规的功能只需要生成实体和对应的界面就好，不需要生成查询实体类（Criteria）,如果框架的查询条件满足不了的情况下，可以通过查询实体类去处理；
• BS的常规功能开发使用modelfirst生成的话，只需要生成Entity和WebViewConfig。
 
  7.3. 实体规范
•  各个实体文件需放到各自的文件夹下，文件夹命名需加“s”结尾。
• 业务实体命名不带前后缀，建议命名不超过两个单词，长度不超过30字符。
• 查询实体以Criteria为结尾。


  7.4. ModelFirst特殊说明
• 创建可空的引用关系

 
• 在2018下的模板起作用（2017下的模板不起作用，生成的实体还是非空实体），使用2018生成引用关系如下图所示：

 
 
• 创建组合关系，需要手动将箭头去掉，不去掉是单向关系
 
  7.5. 常见的几中UML关系图
常见的类和类之间的关系有如下几种关系
泛化（Generalization）, 实现（Realization）,关联（Association)，聚合（Aggregation）,组合(Composition)，依赖(Dependency)泛化：带空心三角箭头的实线，箭头指向父类，表示是一种类继承的关系
实现：带空心三角箭头的虚线，箭头指向接口，表示类与接口的关系
组合:   带实心菱形的实线，菱形指向整体，表示整体与部分的关系，且部分不能离开整体而单独存在。如公司与部门的关系。
聚合：带空心菱形的实线，菱形指向整体，也是表示整体与部分的关系，但部分可以离开整体而单独存在。如部门与人员，人员可以独立存在
关联： 带普通箭头的实心线，指向被拥有者，是一种拥有的关系。
依赖：  带普通箭头的虚线，指向被使用者，是一种使用的关系。
这些关系在代码中的强弱顺序：
泛化 =实现>组合> 聚合> 关联> 依赖

