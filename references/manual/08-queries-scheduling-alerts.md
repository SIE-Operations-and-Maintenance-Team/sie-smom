# 三种查询实现·调度·预警

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch27-29
> **提取范围**：docx 正文行 6310-6755
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

27. 框架查询的三种实现方式
框架实体查询三种实现方式有使用查询实体类、使用标准查询实体、使用标准查询实体+标准查询数据提供者
27.1. 使用查询实体类
使用查询实体实现查询，可以设置查询条件默认值以及实现复杂的查询逻辑，但代码量较多且无法使用快捷查询功能

例子：
1、查询实体
/// <summary>
/// 资源查询实体
/// </summary>
[QueryEntity]
public class ResourCriteria : Criteria
{
        #region 原文 Key
        /// <summary>
        /// 原文
        /// </summary>
        [Label("原文")]
        public static readonly Property<string> KeyProperty = P<ResourCriteria>.Register(e => e.Key);
                  /// <summary>
        /// 原文
        /// </summary>
        public string Key
        {
            get { return this.GetProperty(KeyProperty); }
            set { this.SetProperty(KeyProperty, value); }
        }
        #endregion
                 #region 译文 Value
        /// <summary>
        /// 译文
        /// </summary>
        [Label("译文")]
        public static readonly Property<string> ValueProperty = P<ResourCriteria>.Register(e => e.Value);
                  /// <summary>
        /// 译文
        /// </summary>
        public string Value
        {
            get { return this.GetProperty(ValueProperty); }
            set { this.SetProperty(ValueProperty, value); }
        }
        #endregion
                 #region 文化 Culture
        /// <summary>
        /// 文化Id
        /// </summary>
        [Label("文化")]
        public static readonly IRefIdProperty CultureIdProperty =
            P<ResourCriteria>.RegisterRefId(e => e.CultureId, ReferenceType.Normal);
                  /// <summary>
        /// 文化Id
        /// </summary>
        public double? CultureId
        {
            get { return (double?)this.GetRefNullableId(CultureIdProperty); }
            set { this.SetRefNullableId(CultureIdProperty, value); }
        }
                   /// <summary>
        /// 文化
        /// </summary>
        public static readonly RefEntityProperty<Culture> CultureProperty =
            P<ResourCriteria>.RegisterRef(e => e.Culture, CultureIdProperty);
                   /// <summary>
        /// 文化
        /// </summary>
        public Culture Culture
        {
            get { return this.GetRefEntity(CultureProperty); }
            set { this.SetRefEntity(CultureProperty, value); }
        }
        #endregion 
          /// <summary>
    /// 获取资源
    /// </summary>
    /// <returns>资源列表</returns>
    protected override EntityList Fetch()
    {
        return RT.Service.Resolve<CultureController>().GetResources(this);
    }
}
2、查询视图（需要的查询条件必须写在ConfigView()方法中，且设置ShowInWhere.Detail或ShowInWhere.All）
/// <summary>
/// 资源查询实体视图配置
/// </summary>
public class ResourCriteriaViewCongfig : WPFViewConfig<ResourCriteria>
{
    /// <summary>
    /// 配置视图
    /// </summary>
    protected override void ConfigView()
    {
        View.Property(p => p.CultureId).HasLabel("文化").Show(ShowInWhere.Detail);
        View.Property(p => p.Key).Show(ShowInWhere.Detail);
        View.Property(p => p.Value).Show(ShowInWhere.Detail);
    } 
}
3、查询方法
/// <summary>
/// 获取资源列表
/// </summary>
/// <param name="criteria">资源查询实体</param>
/// <returns>资源列表</returns>
public virtual EntityList<Resource> GetResources(ResourCriteria criteria)
{
    var query = Query<Resource>();
    if (criteria.Culture != null)
    {
        query.Where(p => p.CultureId == criteria.CultureId);
    }
    return query.Where(p => p.Key.Contains(criteria.Key) && p.Value.Contains(criteria.Value)).ToList(criteria.PagingInfo);
}
4、在实体上标特性指定查询实体类型
[RootEntity, Serializable]
[ConditionQueryType(typeof(ResourCriteria))] 
[Label("资源")]
public partial class Resource : DataEntity
{
}

27.2. 使用标准查询实体
这种实现方式比较简单，适用于不需要设置条件默认值且没有特别复杂查询逻辑，支持快捷查询

例子：
1、设置查询视图
/// <summary>
/// 语言映射视图配置
/// </summary>
internal class ResourceViewConfig : WPFViewConfig<Resource>
{
    /// <summary>
    /// 查询配置视图
    /// </summary>
    protected override void ConfigQueryView()
    { 
        View.Property(p => p.CultureId).HasLabel("文化");
        View.Property(p => p.Key);
        View.Property(p => p.Value); 
    }
}
2、在实体上标特性使用
[RootEntity, Serializable] 
[CriteriaQuery]
[Label("资源")]
public partial class Resource : DataEntity
{
}

27.3. 使用标准查询实体+标准查询数据提供者
这种实现方式不可设置条件默认值，可以实现较复杂查询逻辑，支持快捷查询
例子：
1、设置查询视图
/// <summary>
/// 组织架构视图配置
/// </summary>
internal class EnterpriseViewConfig : WPFViewConfig<Enterprise>
{
    /// <summary>
    /// 查询配置视图
    /// </summary>
    protected override void ConfigQueryView()
    {  
        View.Property(p => p.Code);
        View.Property(p => p.Name); 
    }
}
2、新增标准查询数据提供者
/// <summary>
/// 资源标准查询数据提供者
/// </summary>
public class ResourceQueryProvider : ICriteriaQueryProvider
{
    /// <summary>
    /// 获取资源列表
    /// </summary>
    /// <param name="query">标准查询实体</param>
    /// <returns>资源列表</returns>
    public EntityList GetList(CriteriaQuery criteria)
    { 
           return RT.Service.Resolve<EnterpriseController>().GetEnterprises(criteria);
  }
}
3、注册标准查询数据提供者
public class Module : DomainModule
{
    public override void Initialize(IApp app)
    {
         RT.Service.Register<ResourceQueryProvider>(); 
    }
}
4、查询方法
/// <summary>
/// 获取企业模型集合
/// </summary>
/// <param name="query">标准查询实体</param>
/// <returns>企业模型集合</returns>
public virtual EntityList<Enterprise> GetEnterprises(CriteriaQuery query)
{
    return Query<Enterprise>().Where(p => p.InvOrgId == 0 || p.InvOrgId == RT.InvOrgId).Where(query.Criteria).ToList(query.PagingInfo);
}
5、在实体上指定标准查询数据提供者类型
[RootEntity, Serializable] 
[CriteriaQuery(typeof(ResourceQueryProvider ))]
[Label("资源")]
public partial class Enterprise: DataEntity
{
}

28. 调度
1. 调度任务是指系统按配置要求，定时执行相关的任务，这里分别有两个方面，一个是要执行的任务，需要开发人员使用代码实现相关的业务逻辑，另一个是实施人员在系统中配置执行任务的时间、周期、参数等。
2. 使用调度的功能，如果是直连数据库调试，需要在WebClient工程中引用Hangfire.Oracle.Core.dll，SIE.Schedule.dll和SIE.Web.Schedule.dll，依赖的第三方包：Hangfire1.7.8，Hangfire.Core1.7.8。
3. 调度的数据库连接名：hangfire。
4. 调度功能的开发，最好是与业务工程区分开，单独建调度工程进行调度功能的开发，工程名以Job结尾。
5. 命名规范：调度任务类命名以Job结尾；调度参数类命名以JobParameter结尾。
6. 做调度功能开发时，调度任务类是必须的，调度参数类非必须(根据具体的业务来决定是否需要参数类)。
7. 做调度功能开发时，日志必须记录详细。

28.1. 调度任务类
任务调度类，是指能被调度模块识别为“调度任务”的类，该类继承于JobBase类，拥有相关调度所需执行的方法、日志记录方法。调度器会按配置要求，定时实例化调度任务类，并执行调度方法。


28.1.1. 代码定义



28.1.2. 代码要点
• [Job("统计班级学生数量", typeof(StudentJobParameter))]    
• 所有的调度任务的类，都需要标记Job标签，用于告诉系统当前的类是一个调度任务类，“调度任务设置”中识别并添加到调度任务中。
• JobBase
所有的调度任务的类，都需要继承JobBase类，只有继承了JobBase，才提供相关调度任务的相关标准方法。
• ExecuteJob
继承了JobBase的类，需要实现ExecuteJob方法，调度器在执行调度任务时，会自动调用调度任务类的ExecuteJob方法，就是说系统在定时执行这个方法。在执行ExecuteJob方法时，会将“调度任务设置”中设置的参数传给ExecuteJob的param参数。
• AddLog
调度任务在执行过程中，可以将相关的日志信息写入到数据库中，同时会在“调度任务设置”功能中看到。需要注意的是，是在调度任务中执行一次任务，就算写多个日志信息，会合并成一个，并不会出现多条记录。
• StudentJobParameter（JobParameter）
StudentJobParameter是自己定义的参数实体，用于提供当前调度任务类可以要接收的自定义业务参数，如果调度任务类不需要设定任何业务参数，则默认为JobParameter即可，即typeof(JobParameter)



28.2. 调度任务参数
调度任务参数，是用于配置调度任务时，给该任务提供相关业务参数给调度任务，调度任务在执行时，获取到设置到的相关参数，以供调度任务的业务逻辑代码使用。
要使用调度任务参数，需进行3个步骤的开发或处理。
• 参数实体类
• 参数实体视图
• 调度任务类声明参数实体类型

28.2.1. 参数实体类


[RootEntity,Serializable]：调度参数实体是根实体，需要标记RootEntity和Serializable标签
JobParameter：调度参数实体需要继承为JobParameter
28.2.2. 参数实体视图

调度的参数实体视图定义，跟普通实体视图定义一样，需继承WebViewConfig<T>，调度参数设置中弹出的是表单页面，所以调用的是ConfigDetailsView视图，相关字段在ConfigDetailsView设置即可。
28.3. 调度任务设置
28.3.1. 添加调度任务



 
 
28.3.2. 配置调度参数（执行时间及周期）
点击调度任务的“cron表达式”，可配置调度任务的执行时间及周期，即告诉调度器什么时候执行，或者隔多久执行一次。

28.3.3. 调度任务参数（业务参数）
点击调度任务的“方法参数”，即可弹出该任务的业务参数配置页面，该页面就是由调度任务参数视图进行配置的。



28.3.4. 运行和触发
• 配置完成后，点击启动按钮，设置为启动，目前demo中的数据库是附加的，启动会报错

 
• 启动后点击触发按钮，进入调度任务排队等待，根据时间先后顺序执行
• 运行和触发的区别：
运行：表示立即执行，在本地环境运行调度，在开发时可通过这个按钮进行调试调度任务。
触发：进入排队等待，在调度服务运行，由调度器执行。


28.4. 调度常见异常问题说明
1. 本地触发调度任务，当服务器调度服务运行中，会增加任务队列，两个线程任务同时执行，导致调度执行两次。
解决思路：
1）本地调试触发调度连接服务器数据库时，将服务器对应的调度停止后，再进行本地触发调试（调试完成后要记得启动调度）；
2）后台调度任务增加关键字lock，锁定当前执行的任务，当第一线程执行到lock语句时，会申请一个互斥锁，当任务执行完毕后才会释放，期间有第二个线程进入lock，则会等待。

2. 调度任务需要先禁用再删除，否则删除后调度还会在hangfire运行（该问题在9.1的版本做了限制，已修复）。
如果删除后调度还在运行，可以在调度的控制台Recurring jobs页签进行删除。

3. V8.3的调度设置每天定点执行任务，会延时8小时执行。
说明：这个是框架的bug，如果要处理这种问题，时间设置提前8小时，如下图：我希望在每天上午11点定时执行任务，设置cron表达式时设置的是凌晨3点执行。

4. V8.3早期版本，调度模块生成调度表成功后，升级任何数据库都报错。


解决方案：
永久解决方案：平台Bug，升级最新SIE.dll；
临时解决方案：将调度相关的表和数据备份，然后删除调度表，再执行升级；或者是通过脚本在数据库层面操作。
5. 部署的调度任务不执行。
问题描述：部署后调度任务不执行，对应场景：调度测试环境（windows环境）执行成功，但正式环境（linux+docker）不执行。
解决方案：打开调度控制台检查linux环境是否时区正确，两个系统的环境的时区标识是不是样的。
下面第1个图是windows环境，第2个图是linux环境：


6. 某个调度任务执行失败。
问题描述：其他调度任务都正常，某个调度任务执行不了或者失败，失败如下图。
原因：调度服务没有发布，只发布了Host和BS
解决方案：调度服务、Host和BS同时发布。

7. 调度服务挂掉，原因可能是调度任务逻辑内部异常；如果是调度任务挂掉，可能的原因是任务不会入队，调度执行的时间被设置到了秒级。
29. 预警的使用
本地WebClient直连，要使用框架的预警平台，需要在WebClient中依赖的dll文件如下：
1. 需引用的DLL：SIE.Alert.dll、SIE.Alert.Job.dll、SIE.IScript.dll、 SIE.Script.dll、SIE.RazorEngine.dll、SIE.Senders.dll、SIE.Web.Alert.dll、SIE.Web.Senders.dll；
2. 依赖包：NetEscapades.AspNetCore.SecurityHeaders、MailKit、Microsoft.CodeAnalysis。

29.1. 预警界面的配置使用说明

1. 通用说明：预警平台的使用依赖于预警模块和推送模板，界面配置也会从这两个方面进行配置说明。框架涉及到的功能配置菜单：推送模块管理、预警配置、预警日志。

29.1.1. 推送模块配置
1. 推送管理模块的数据是程序编码实现的(开发实现完成，点击界面的“初始化”按钮，生成数据)，框架默认实现的推送如下：

2. 以下以邮件的配置为例：选择邮箱的数据行，点击配置信息，进行配置；

邮箱如果不启用SSL，端口为25；启动SSL，端口为465。
163邮箱配置：

腾讯企业邮箱的配置：

QQ邮箱服务器地址：smtp.qq.com

29.1.2. 预警配置
1. 预警日志功能：查看的是所有的预警日志。

2. 预警配置：预警配置功能包含操作命令：添加、修改、删除、复制新增、测试、预警日志、预警类型管理、预警模块管理、推送方式。

3. 预警配置-预警类型管理：基础数据

4. 预警配置-预警模块管理：预警具体的实现逻辑，点击添加按钮，弹出的“选择预警模块”中的数据是开发实现的。

5. 预警配置-推送方式：“推送名称”和“严重程度等级”按具体业务要求定义，无特别要求；“接收人”关联的信息为员工维护信息(推送方式为邮件，必须设置接收人的邮箱信息)。

推送方式的信息模板：可设置默认的模板，也可以根据对应的模板设置，根据模板设置依赖与具体的模板。

[OLE: Package]
推送方式配置完成后，点击“测试”按钮，提示“测试结束”，表示邮件的配置是OK的。

6. 预警配置-添加预警，数据维护好后，点击保存按钮，保存数据。

7. 预警配置-配置严重程度和严重程度对应的推送方式。
执行顺序：优先去匹配等级为通用的，满足条件就直接对应严重程度的推送方式，不满足条件就依次执行等级为轻、中、高的；严重程度的条件会跟预警的返回值Value进行比较。

8. 预警配置-预警测试：预警配置完成后，点击“测试”按钮，对配置的预警进行测试，提示预警测试结束，表示配置OK。

选择对应的预警数据，点击”预警日志”，可以查询预警的详情，查看预警推送是否成功。


29.2. 预警插件示例
29.2.1. 创建代码文件
DemoAlertResult.cs
DemoAlertPlugConfig.cs
DemoAlertPlug.cs
DemoAlertPlugConfigViewConfig.cs
 
• DemoAlertResult.cs
预警返回结果配置，继承AlertResultBase，可以不实现，如果要实现该类的属性只能是简单属性。

 
• DemoAlertPlugConfig.cs
预警参数配置，继承AlertConfig，根据业务需要配置参数。


• DemoAlertPlugConfigViewConfig.cs 
预警参数界面配置，继承WebViewConfig<预警参数类>

• DemoAlertPlug.cs 
预警类，继承AlertBase，标记特性[Alert(“预警名称”),typeof(预警参数类)，typeof(预警返回结果类，如果没有实现，这里使用AlertResult),”预警描述”]；实现Run方法，run方法返回的value值会跟预警配置的严重程度值去对比，满足条件就会执行对应的推送方式。




29.2.2. 预警配置-预警模块管理
• 添加预警模块

• 配置参数

 
 
29.3. 邮件插件示例
    29.3.1. 邮件开发示例
• 添加项目引用
SIE.Senders.dll


• 创建代码文件
DemoSenderConfig.cs
DemoSender.cs

DemoSenderConfig.cs为邮件推送参数类，继承EmailSenderConfig(如果不用框架的父类，则继承SenderConfg)

说明：
1. 这里框架的邮件推送的属性就够了，就没有添加属性，如果需要添加属性，根据实际需求使用代码段添加。
2. 2.邮件推送参数界面配置类的开发：这里是使用框架邮件的配置类就能满足要求，如果是参数类添加了属性，或者是继承SenderConfg，属性自己实现；则需要实现参数界面配置类的实现。
3. 参数界面配置类，继承WebViewConfig<推送方式参数类>，重写ConfigDetailsView，添加界面要展示的属性。 


DemoSender.cs为邮件推送类的实现，继承EmailSender，标记特性Sender，重写发送参数的方法CreateSendParam。

 
 CreateEmailSendParam方法的实现：
public ISendParam CreateEmailSendParam(AlertResultBase result, ReceiveParam param)
        {
            var emailSendParam = new EmailSendParam();
            for (int i = 0; i < param.Employees.Count; i++)
            {
                if (!string.IsNullOrWhiteSpace(param.Employees[i].Email))
                    emailSendParam.SendTos.Add(new MailboxAddress(param.Employees[i].Email));
            }
            emailSendParam.Attachments = param.EmailAttachmentCollection;
            dynamic resultDynamic = result;
            if (!param.MessageTemplateJson.IsNullOrWhiteSpace())
            {
                var emailMessageTemplate = JsonConvert.DeserializeObject<EmailMessageTemplate>(param.MessageTemplateJson);
                if (emailMessageTemplate != null)
                {
                    emailSendParam.Subject = emailMessageTemplate.Subject;
                    emailSendParam.Body = emailMessageTemplate.Message;
                }
            }
            return emailSendParam;
        }


    29.3.2. 插件初始化
完成后运行项目，在“推送模块管理”点击初始化按钮，把数据初始化出来

然后在预警配置中点击推送方式按钮，在推送方式中即可添加配置


添加的推送方式，要配置推送方式、接收人、信息模板。
注意：这里的接收人要在员工维护中对应的人员，且对应人员的邮箱要维护正确才能收到邮件。
 
29.2.3. 邮件服务器配置
发件邮箱和邮箱服务器的配置：在推送模块管理中配置发送邮件的服务器和发件邮箱。



