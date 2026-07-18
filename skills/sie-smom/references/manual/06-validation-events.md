# 验证规则·提交事件·前后端请求·Behavior·属性变更·附加子视图

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch15-19
> **提取范围**：docx 正文行 4149-4968
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

15. 验证规则和提交事件
15.1. 后端验证规则

作用对象：实体，用于实体保存时的逻辑验证，
有三种验证规则：标准规则、运行时规则、预编译规则
15.1.1. 标准规则
标准规则是在实体配置(EntityConfig<T>)中重写AddValidations()方法实现规则验证，标准规则不可在实体元数据功能中配置，而是代码编写完成运行程序立马生效。

标准规则可以实现的验证：
• 非空验证，使用：rules.AddRule(属性名, new RequiredRule())
• 非重复验证，单个和多个属性的非重复验证；
单个属性非重复验证：rules.AddRule(属性名, new NotDuplicateRule());
多个属性非重复验证：
		rules.AddRule(new NotDuplicateRule()
            {
                Properties =
                {
                    属性名1,
                    属性名2
                },
                MessageBuilder = (e) =>
                {
                    return “验证不通过的提示信息".L10N();
                }
            });
• 长度验证，包括最小和最大长度的设置
rules.AddRule(属性名, new StringLengthRangeRule() { Min = 2, Max = 40 });
• 最大最小值验证；rules.AddRule(属性名, new NumberRangeRule() { Min = 1, Max = 100 });
• 正则表达式验证；
rules.AddRule(属性名, new RegexMatchRule()
{
Regex = new Regex(@"^((\d{3}-\d{8}|\d{4}-\d{7,8})|(0?(13|14|15|17|18|19)[0-9]{9}))$"),
MessageBuilder = (o) =>
{
	return "电话号码不正确";
}
});
• 实体验证
rules.AddRule(new HandlerRule()
{
Handler = (o, e) =>
{    //这里可以进行查数据库进行操作，当前实体的数据不能满足验证判断要求时可查数据库判断
var reader = o.CastTo<实体类>();
if (判断的条件)
	e.BrokenDescription = “具体的验证提示信息".L10nFormat(reader.Name);
}
});


实现：在实体配置中重写验证方法AddValidations，如下所示：


15.1.2. 运行时规则
• 通过在实体元数据模块进行运行时配置的规则，如字段长度、非空等验证。运行时规则完全通过配置实现。
如在“实体元数据(数据字典)”菜单的“实体规则”页签中，维护规则，做基础的验证：

注意：发布到生产环境中，如果通过该功能添加基础验证配置，添加完成后要重启服务才会生效。
• 运行时规则还可以通过在实体属性中标记特性来实现的，完成后要进行实体元数据的初始化，在实体元数据菜单的实体规则可以配置启用和禁用，默认初始化完成后都是启用状态
常用的规则特性有：
  • 非空：[Required]
  • 非重复：[NotDuplicate]
  • 最大长度：[MaxLength(10)]
  • 最小长度：[MinLength(3)]
  • 最大值：[MaxValue(100)]
  • 最小值：[MinValue(0)]

示例：

• 在实体属性中标记验证特性的注意事项：
1.验证要生效，必须进行实体元数据的更新，且规则状态是启用状态才会生效；
2.实体属性配置的规则删除，元数据生成的规则不会自动删除，需要手动删除或者禁用，否则规则还会生效；
3.引用属性的非空验证是通过属性的类型进行验证的，不要在引用属性中标记非空特性[Required]，否则非空验证的提示会提示两次。

 
15.1.3. 预编译规则
通过C#代码的方式实现验证规则，然后在实体元数据功能进行更新并配置启用。
包含的规则子类：实体规则(继承EntityRule<T>)、非重复规则(继承NotDuplicateRule<T>)、删除被引用规则(继承NoReferencedRule<T>)。
该规则也需要在实体元数据中进行更新才会生效。
使用场景：常用来实现特定的验证提示与稍复杂的业务验证规则。
15.1.3.1. 实体规则
继承EntityRule<T>,在这个规则中可以实现所有规则。
示例模板：
    [System.ComponentModel.DisplayName("规则名称信息")]
    [System.ComponentModel.Description("规则描述信息")]
    public class XXXRule : EntityRule<T>
    {
        public XXXRule()  //构造函数
        {
            Scope = EntityStatusScopes.Add | EntityStatusScopes.Update; //规则作用域默认为新增和修改，如果是只在添加操作生效，可以对该属性进行规则设置
            ConnectToDataSource = false; //是否连接数据仓库，默认为false，如果在验证方法中有对数据库进行操作，该属性要设置为true
        }
        protected override void Validate(IEntity entity, RuleArgs e) //验证方法
        {
	    //这里可以调用控制器方法对数据库进行操作
            var t = entity as T;//entity为当前验证的实体
            if (验证的条件)
                e.BrokenDescription = “验证不通过的提示信息{0}".L10nFormat(t.A);
        }
    }

15.1.1. 实体规则实现示例一


• 在服务端新建一个规则类，命名以Rule结尾
• 实体规则继承EntityRule<对应操作的实体>，完成后对该规则进行特性的标记
• 重写验证规则的方法，在验证规则方法中实现具体的业务逻辑
• 初始化元数据，完成后在界面中进行验证
 
15.1.2. 实体规则实现示例二

• Scope如果不指定，默认值是AddOrUpdate
• 调用控制器的方法实现：RT.Service.Resolve<具体的控制器>().方法名(参数)
• 说明：控制必须建在服务端，且是部分类，继承自DomainController，控制器的方法必须是虚方法

 
15.1.3.2. 非重复验证使用示例
非重复验证，平台根据提供的实体字段值，对该实体进行数据的重复验证。如果存在一样字段值的数据，则系统在保存时会进行验证错误提示，提示的信息自己提供。当设置一个字段时，则只对实体的一个字段值在数据库中进行验证，如果设置多个字段值时，则将实体多个字段值在数据库中验证。

• 在构造函数中，通过Properties.Add方法同，添加判断重复的字段，可以添加一个或者多个字段，例如编码字段Code不能重复，则只需要添加Code字段。如多个字段时，则是将多个字段的值合起来一起判断。

15.1.3.3. 删除验证使用示例
• 在服务端新建一个规则类，命名以Rule结尾

• 删除验证继承NoReferencedRule<具体操作的实体>
如下图所示：

• 删除规则类建完之后，在类上面标记特性，对该规则类进行说明

• 完成后对该删除规则做业务逻辑的验证，验证在删除规则的构造函数中实现，如：

完成后运行代码，在初始化元数据中进行初始化元数据操作（该操作比较重要，如果没有做该动作，该验证不会生效）
15.1.3.4. 非空验证使用示例
非空验证，在保存实体时，平台对设置的实体字段进行判空验证。如果字段值为空，则系统在保存时会报验证错误提示。

15.1.4. 后端验证通用说明
1.标准验证AddValidations和预编译验证(在服务端编写验证规则类)是两种不一样的实现方式，同一逻辑用两种方式验证的效果是一样的，只是其中一种是代码所见即所得，一种是可配置；
2.在项目上对应的验证逻辑，能用标准规则验证就不要使用其他的验证，主要原因是实体元数据更新执行效率比较低；
3.非重复验证尽量使用框架非重复的子类进行验证，不要在实体规则中进行验证，原因是写的逻辑比较多，还有可能写漏，用框架的非重复验证会简单很多，也避免一些不必要的bug出现；
4.被引用不允许删除尽量使用框架的，原因与非重复验证一致；
5.String类型的长度验证，框架默认配置的长度是20，如果有些字段需要设置为其他的长度限制，需要自己手动设置，如果框架string类型的长度限制都需要调整，可以在配置文件中配置DefaultFieldMaximumLength。

15.2. 前端验证规则
15.2.1. 前端规则 
说明：1. 前端表单控件的规则控制是根据实体元数据对应的规则生成的，且验证只能实现常规验证。
2. 前端验证使用框架默认命令可以实现相关验证，如果重写了命令以下点需要注意。
 
• 表单编辑，如果自己重写了新增，修改和保存命令，前端验证失效，就要检查重写的新增、修改和保存命令有没有去调用验证的方法
• 新增、修改命令调用前端验证方法是在showView方法中调用this.validateData(view)，其中view为当前操作视图（8.1之前版本）

showView: function (editEntity) {  
    /// <summary>  
    /// virtual 方法 弹出页面  
    /// </summary>  
    var me = this;  
    var key = '';  //todo workbench.createKey 还没有js工作台pugm  
    if (!this.viewMeta) {  
        SIE.AutoUI.getMeta({  
            async: false,  
            isDetail: true,  
            ignoreQuery: true,  
            model: this.view.model,  
            callback: function (meta) {  
                meta.token = me.view.token;  
                me.viewMeta = meta;  
            }  
        });  
    }  
    var cfg = {  
        associateCmd: me,  
        viewMeta: me.viewMeta,  
        entity: editEntity,  
        editMode: this.view.editMode,  
        title: this.getEditViewTitle(editEntity),  
        confirm: function (isNoSave) {  
            //弹窗的确认后回调  
            var isImmediate = me.view.isImmediate();   
            me.view.afterEdit(editEntity, isImmediate, me.isCopy);  
        }  
    };  
    var parent = this.view.getParent();  
    var view;  
    if (parent != null) {  
        //子视图弹框显示  
        me.setDialogAttribute  
       //设置弹窗属性  
       var dialogcfg={};  
       dialogcfg=me.setDialogAttribute(dialogcfg);  
        cfg.dialogcfg=dialogcfg;  
        //cfg.width=me.width;  
        //cfg.height=me.height;  
        view = SIE.App.showDialog(cfg);  
    }  
    else {  
        //页签显示  
        view = SIE.App.showView(cfg);  
    }  
    me._editingView = view;  
    this.validateData(view);  
},  
 
/** 
 * 验证数据 
 * 子类重写此方法实现特定的数据验证逻辑 
 * @returns {}  
 */  
validateData:function(view) {  
    return view.validateData();  
},  
 
 
• 保存方法调用前端验证是在onSaving方法中调用onValidation(view)，view为当前操作视图
SIE.defineCommand('SIE.cmd.FormSave', function () {  
    return {  
        extend: 'SIE.cmd.Save',  
        meta: { text: "保存", group: "edit", iconCls: "icon-SaveEntity icon-blue" },  
        /** 
         * @protected virtual void  
         * 验证实体 
         * @param {type} entity 
         */  
        onValidation: function (view) {  
            return view.validateData();  
        },  
        onSaving: function (view) {  
            var isValidator = this.onValidation(view);  
            return isValidator;  
        },  
        onSaved: function (view, res) {  
            var me = this;  
            var current = view.getCurrent();  
            current.markSaved();  
            var operationView = view;  
            if (view.associateCmd) {  
                operationView = view.associateCmd.view;  
                var store = operationView.getData();  
                if (store && store instanceof Ext.data.Store) {  
                    me.mon(store, 'load', me.onRefresh, this, { single: true });  
                }  
            }  
            operationView.reloadData();  
            me.onSavedMsg(view, res);  
        },  
        onRefresh: function (store, records, successful, operation, eOpts) {  
            var current = this.view.getCurrent();  
            var record = store.findRecord(SIE._KeyPropertyName, current.get(SIE._KeyPropertyName));  
            if (!record) {  
                record = current;  
            }  
            this.view.setCurrent(record, true);  
        },  
        canExecute: function (view) {  
            if (view.isDetailView) {  
                var result = false;  
                var current = view.getCurrent();  
                if (current) {  
                    result = current.isDirty();  
                }  
                return result;  
            }  
            return this.callParent(arguments);  
        },  
        execute: function (view, source) {  
            var isValidator = this.onSaving(view);  
            if (isValidator)  
                this.doSave(view);  
        }  
    };  
});  
 
说明：验证规则框架调用的地方，添加按钮ShowView时会调用，还有就是执行保存时会去调用。

15.2.2. 根据条件控制前端规则
• 只表单编辑时可用，需要重写命令
• 如果重写的命令中重写了showView方法，需要手动给_editingView赋值（是全局的，当前表单编辑的view，后面更改表单控件的属性会用的）,还需要手动去调用验证方法（如果没有调用要点击到对应的控件，控件提示验证才会生效）

• 在对应的方法中实现验证，下面例子是在属性变更事件中根据条件控制某个控件是必填还是非必填



15.3. 提交事件
1.提交事件建在服务端，而且在第一次使用或者修改了对应的事件，都必须初始化元数据才会生效。
2.提交事件使用场景：针对某个菜单功能的通用处理逻辑，可用在提交事件中进行处理。
3.提交事件分为提交前和提交后事件：
提交前事件，是在保存这个实体对象之前调用的；
提交后事件，是在保存这个实体对象之后调用的；

15.3.1. 提交前事件的使用
1.在服务端新建一个类，命名以OnSubmitting结尾，继承OnSubmitting，OnSubmitting后面跟对应的操作实体,如下图：

点击报错的地方，实现抽象类，如下图：

然后在生成的抽象方法中，写对应的业务操作，如下图是的场景是当员工信息添加信息时，保存前添加员工资源信息

然后在提交前事件类名前面加上事件名称和描述，也可以在建好该事件的时候就加上，如下图所示：

最后运行程序，初始化元数据，初始化元数据后，会在对应实体元数据的提交前事件生成一条数据


15.3.2. 提交后事件的使用
在服务端新建一个类，命名以OnSubmitted结尾，继承OnSubmitted，OnSubmitted后面跟对应的操作实体,如下图：

给提交后事件添加名称和描述

实现提交后事件的抽象方法，在方法中处理相应的业务逻辑

控制器方法的写法如下图所示：


15.3.3. 注意事项
1.提交前、提交后事件使用要生效，必须进行实体元数据更新，状态为可用；
2.每次修改了提交前或者提交后事件，也必须进行实体元数据的更新；
3.提交事件后台代码删除，在实体元数据对应提交事件子列表的数据不会删除，需要手动去提交事件子页签将对应数据禁用，或者是在后台数据库将数据删除。
提交事件的表为：MDA_ENTITY_SUBMIT_EVENT，通过DISCRIMINATOR区分为提交前后事件；
DISCRIMINATOR=‘A’，为提交前事件；
DISCRIMINATOR=‘B’，为提交后事件；
4.提交事件后台的类名修改了，修改之前通过“更新”生成的提交事件对应的数据程序不会删除，会重新再生成一笔数据；也就是提交事件在“更新”之后修改了类名，需要把修改类名之前的数据禁用或者从数据库中删除。
5.如果是通过DB操作的数据，或者是批量保存，不会执行对应的验证规则。

16. 前后端数据请求
16.1. 说明
前端向后端请求数据包含两种方式：一种是通过命令的形式请求；还有一种方式是通过调用SIE.invokeDataQuery方法请求后端数据，该方式除了查询数据请求，也可能进行其它的数据处理，如数据删除、修改等。
在任务可触发的地方均可以进行调用，如按钮、页面控件单击等。
16.2. 通过命令请求
前端命令通过view.execute向后台发起请求
        view.execute({
            data: view.getSelectionIds(),
            success: function (res) {
                var data=res.Result ;
                
            }
});
后台自定义命令，继承ViewCommand或者ViewCommand<ViewArgs>或者ViewCommand<double[]>，根据前端传递的参数类型决定；重写Excute执行方法

23.1. 前端传的data为实体数据，后台命令继承ViewCommand，对应的数据转换为args.Data.ToJsonObject<实体>()；
SIE.defineCommand('SIE.Web.Demo.Items.Commands.ItemAddCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加", group: "edit" },
    onItemCreated: function (entity) {
        var model = entity.data;
        var me = this;
        this.view.execute({
            data: model,
            success: function (res) {
                var data = res.Result;
                //添加时设置编码和状态
                entity.setCode(data.Code);
                entity.setState(1);
        }, me.view);
    },
});

    public class ItemAddCommand : ViewCommand
    {
        protected override object Excute(ViewArgs args, string scope)
        {
            var item = args.Data.ToJsonObject<Item>();
            item.Code = RT.Service.Resolve<ItemController>().GetItemCode();
            item.State = State.Enable;
            return item;
        }
}

23.2. 前端传的data数据为自己拼装的数据，后台继承ViewCommand<ViewArgs>,对应的数据转换为args.Data.ToJsonObject<自定义类>()
    execute: function (view, source) {
        var indata = {};
        var productModel = “”;
        var productModelLineCapacity = [];
        var productModelSkill = [];
        indata.Data = Ext.encode({ A: productModel, B: productModelLineCapacity, C: productModelSkill  });
        view.execute({
            data: indata,
            success: function (res) {
            }
        });
}

    public class TestCommand : ViewCommand<ViewArgs>
    {
        /// <summary>
        /// 执行
        /// </summary>
        /// <param name="args">args</param>
        /// <param name="scope">scope</param>
        /// <returns>执行结果</returns>
        protected override object Excute(ViewArgs args, string scope)
        {
            var data = args.Data.ToJsonObject<TestViewArgs>();
            return true;
        }
    }

	/// <summary>
    /// 参数
    /// </summary>
    public class TestViewArgs
    {
        public string A { get; set; }
        public EntityList<Item> B { get; set; }
        public EntityList<Unit> C { get; set; }
    }

23.3. 前端传的数据为对应实体的id，后端继承ViewCommand<double[]>，对应的数据转换为args.ToList()

    execute: function (listView, source) {
        SIE.Msg.askQuestion('确定禁用选中的资料?'.t(), function () {
            listView.execute({
                data: listView.getSelectionIds(),
                success: function (res) {
                    SIE.each(listView.getSelection(), function (model) {
                        model.data.State = 0;
                    });
                    listView.reloadData();
                }
            });
        });
 }

    public class ItemDisableCommand : ViewCommand<double[]>
    {
        protected override object Excute(double[] args, string scope)
        {
            var itemList = RT.Service.Resolve<ItemController>().GetItemList(args.ToList());
            foreach (var item in itemList)
            {
                RT.EventBus.Publish(new HasItemStockEvent() { IetmId = item.Id });
                item.State = State.Disable;
            }
            RF.Save(itemList);
            return "操作成功";
        }
    }

16.3. 通过SIE.invokeDataQuery请求
前端调用SIE.invokeDataQuery方法，后端通过DataQueryer类的方法接收请求，后端处理完后SIE.invokeDataQuery的success回调方法会被触发，处理前端的事。
以下示例是通过在添加按钮触发期间，向后端获取自动生成的编号。

16.3.1. 前端代码
[OLE: Package]

• 向后端请求时，提供method、params、action、type、token这5个参数，区分大小写。
  • method：后端请求方法，对应的是后端处理类里面的方法名
  • params：后端方法接受的参数，数组形式，如不传参数，则此参数可以不提供
  • action：请求方式，此处写死“queryer”，此参数可不提供，平台默认“queryer”
  • type：后端请求方法所在类的命名空间及类名
  • token：页面的token，用于系统验证请求合法性，该参数不加后端没有设置匿名会跳转到登录界面。

• 向后端请求完后，如请求成功，则触发success(res)回调方法，也可通过error(res)方式获取后端报错信息，无论后端处理成功或者报错，都可通过callback(res)进行回调处理。


16.3.2. 后端代码
[OLE: Package]

• 后端接收调用的类，必须继承DataQueryer基类，该基类在SIE.Web.Data命名空间，修饰符可以为internal,而非public。请求的方法，必须使用public公开，否则请求不到，方法中的参数与前端提供的参数保持一致。

17. 行为Behavior使用说明
17.1. 使用场景
需要在框架默认生成的视图中添加额外的处理逻辑，如数据、界面样式、操作逻辑的处理等。
说明：在8.0版本中是叫生命周期以LifeCycle结尾，后面的版本都是叫行为以Behavior结尾。
17.2. View的生命周期简介
如下图：框架的行为提供beforeCreate、onCreated、onViewReady、onShow、onDataLoaded5个生命周期函数(钩子)，可满足大部分需求。

17.3. 使用说明
通过5个生命周期函数，我们可以在在页面生成前后、数据加载后，对页面进行处理或者对数据进行额外的处理，例如表格样式的额外设定（如数据行变红色字体），新建数据设置流水编码等
17.3.1. Behavior JS脚本模板
Ext.define('SIE.Web.Demo.Behaviors.AddBehavior',
    {
        //view创建之前
        beforeCreate: function (view) {
            console.log("beforeCreate");
        },
        //view创建之后
        onCreated: function (view) {
            console.log("onCreated");
        }, 
        //view就绪
        onViewReady: function (view) {
            console.log("onViewReady");
        },
        //view显示
        onShow: function (view) {
            console.log("onshow"); 
        },
        //view数据加载后
        onDataLoaded: function (view) {
            console.log("onDataLoaded"); 
        },
    });

从行为的模板脚本可以看出，行为中提供了5个方法，view创建前的方法beforeCreate，View创建后的方法onCreated，view就绪的方法onViewReady，view显示的方法onShow，view数据加载后的方法onDataLoaded，这5个方法可以根据具体的业务场景选择合适的方法进行业务处理。
17.3.2. Behavior使用步骤
• 创建Behavior JS脚本文件，并且JS文件需要设置“生成操作”为“嵌入式资源”；
• 编写Behavior JS代码，代码中可实现beforeCreate、onCreated、onViewReady、onShow、onDataLoaded5个生命周期函数；
• 在实体对应的ViewConfig中加入Behavior（8.0的版本是在ViewConfig中加入生命周期）。
 
17.3.3. 示例
17.3.3.1. 创建Behavior JS文件，并设置为嵌入式资源
• 根据规范，我们需要创建一个Behaviors文件夹，用于存放Behavior JS文件。
• JS文件必须设置为“嵌入式资源”，否则系统在VIewConfig添加后，运行时将会报错。

17.3.3.2. JS代码定义
• 代码中可实现beforeCreate、onCreated、onViewReady、onShow、onDataLoaded5个生命周期函数，平台在页面生成时会调用对应的函数。
• 需要注意的是JS文件要定义好命名空间，在ViewConfig配置中需要填写一致。
• 在onViewReady、onShow、onDataLoaded三个函数中，可以通过view.getCurrent()方法获取entity实体对象，entity对象可以通过entity.setXXX(属性名，如setCode)对相关属性进行重新赋值，页面控件的值也会发生变化。

17.3.3.3. ViewConfig定义
• 在实体对应的VIewConfig中的对应页面配置中(如ConfigDetailsView)，
• 8.0之后的版本是通过View.AddBehavior(“Behavior JS命名空间”)添加配置Behavior JS，命名空间需要跟JS定义的一致，否则会报错。
• 8.0的版本是通过View.AddCycle(“Behavior JS命名空间”)添加配置Behavior JS，命名空间需要跟JS定义的一致，否则会报错。



17.3.3.4. 示例：表格行样式设置
可以根据数据的指定字段值（数据状态），设置整行数据的样式，引用的Class，以下代码为根据数据的状态字段state为0的时候，整行数据为红色字段（可以自己设置其它样式）。

[OLE: Package]
17.3.3.5. 示例：表格单元格样式设置
可以根据单元格的值，设置单元格的样式，如字体颜色、背景色、粗体等。

[OLE: Package]

17.4. 代码片段（适用于8.0的框架，8.0以上版本可复制上面脚本模板使用）
可通过代码片段快速插入脚本模板
17.4.1. 代码片段导入
• 工具-代码片段管理器

 
• 语言选择JavaScript,点击导入

 

 

17.4.2. 代码片段使用
• 输入vlc，并按两次tab键即可导入
• 在JS文件中输入vlc

• 按两次tab键，可快速生成



18. 属性变更事件的实现
18.1. 说明
1. 列表属性变更事件是在添加和修改命令中处理的，表单属性变更事件在行为中处理；
2. 使用属性变更事件时，我们只需要在使用时对属性变更事件进行注册就可以，激活和注销变更事件框架会处理；
3. 属性变更事件的注册：this.mon(entity, "propertyChanged", this._onEntityPropertyChanged, this);
其中：
this：为作用域；
entity：为对应选择行数据，在行为中可以通过view.getCurrent()来获取，命令方法中可直接获取该参数;
propertyChanged：属性变更事件的名称，该名称不能修改；
this._onEntityPropertyChanged：激活变更事件执行的方法，方法名和作用域可修改，调用具体实现的方法；
4. 属性变更事件是针对数据的，在编辑属性的数据变更时才会有效果，即作用域为新增修改数据，也就是属性数据变更。
18.2. 列表属性变更事件的使用
如果要使用列表属性变更事件，必须重写对应的命令（只有在新增和修改中会有属性变更事件）
18.2.1. 新增属性变更事件
添加命令属性变更事件是在onItemCreated中进行注册，使用示例如下：

SIE.defineCommand('SIE.Web.QMS.Standards.Commands.ItemInspStdDtIAddCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加", group: "edit", iconCls: "iconfont icon-AddEntity icon-blue" },
    onItemCreated: function (entity) {
        if (entity) {
            this.mon(entity, 'propertyChanged', this._onEntityPropertyChanged, this);
        }
    },
    _onEntityPropertyChanged: function (e) {
        if (e.property.length > 0) {
            if (e.property.indexOf('CheckTag') >= 0) {
                var data = e.entity;
                if (e.value == 1) {
                    data.setLimitLow(null);
                    data.setLimitMax(null);
                    data.setUnit(null);
                }
            }
        }
    }
});
18.2.2. 修改属性变更事件
修改命令属性变更事件是在onEditting方法中进行注册，使用示例如下：

18.3. 表单属性变更事件使用
表单变更事件的注册在行为的onViewReady方法中进行注册，如下：

Ext.define("SIE.Web.LibMan.ReaderMans.Behaviors.ReaderManDetailBehavior", {
    onViewReady(view) {
        var entity = view.getCurrent();
        if (entity) {
            view.mon(entity, "propertyChanged", this._onEntityPropertyChanged, this);
        }
    },
    _onEntityPropertyChanged: function (e) {
        var entity = e.entity;
        if (e.property.length > 0 && e.property === "BorrowQty") {
            entity.setSurplusQty(entity.getQty() - entity.getBorrowQty());
        }
    }
});
19. 附加子视图
19.1. 附加显示
19.1.1. AssociateChildrenProperty
场景理解：支持跨应用，实体横向扩展，使用.RegisterExtension方法注册到A对象上的，常用来对现有对象的扩展,支持1对N关系，根据返回类型
19.1.2. AttachChildrenProperty
场景理解：在 B对象上有A对象引用，常用来表示，1对N关系，显示为列表视图
19.1.3. AttachDetailChildrenProperty
场景理解: 在B对象上有A对象的引用，常用来表示，1对1关系，在A上附加B(也可能是自己)并显示为表单视图
 
19.1.4. 子列表数据的加载

 
19.1.5. 注意点
附加子的拿到父的属性并要对之进行操作

 

19.2. 附加示例
19.2.1. 附加表单
      19.2.1.1. 实现方式
可通过AssociateChildrenProperty或者AttachDetailChildrenProperty实现。
      19.2.1.2. AttachDetailChildrenProperty
View.AttachDetailChildrenProperty(typeof(Item), (c) =>
                {
                    var pagingDataArgs = c as ChildPagingDataArgs;
                    var item = c.Parent as Item;
                    item = RF.GetById<Item>(item.Id, new EagerLoadOptions().LoadWithViewProperty());
                    return item;
                }, BaseDataViewGroup).HasLabel("基本资料").OrderNo = 1;

说明：typeof(Item)为附加子的实体类(可以跟主实体是同一个，也可以是单独的其他实体；如果是单独的其他实体的话，跟主的关系是一般外键关系)；不指定分组名时默认为DetailsView;
      19.2.1.3. AssociateChildrenProperty

1. 在服务端新建一个类，不需要继承父类，给类标记特性[CompiledPropertyDeclarer]
    [CompiledPropertyDeclarer]
    public class PersonExtentionDetailProperty
{

2. 用代码段添加扩展一般属性
        #region 扩展属性
        /// <summary>
        /// 扩展属性
        /// </summary>
        public static readonly Property<Phone> Extend1Property =
            P<Person>.RegisterExtension<Phone>("Extend1", typeof(PersonExtentionDetailProperty));

        /// <summary>
        /// 获取扩展属性
        /// </summary>
        /// <param name="me">me对象</param>
        /// <returns>返回扩展属性</returns>
        public static Phone GetExtend1(Person me)
        {
            return (Phone)me.GetProperty(Extend1Property);
        }

        /// <summary>
        /// 设置扩展属性
        /// </summary>
        /// <param name="me">me对象</param>
        /// <param name="value">设置扩展属性</param>
        public static void SetExtend1(Person me, Phone value)
        {
            me.SetProperty(Extend1Property, value);
        }
        #endregion
说明：Person为对应主表的实体，Phone为要附加的子，且附加的子Phone和Person的关系是引用关系，关系如下：


3. 在扩展属性对应的类中添加实体的配置类，配置扩展属性不映射数据库
        /// <summary>
        /// 扩展属性 实体配置
        /// </summary>
        internal class PersonExtentionDetailPropertyConfig : EntityConfig<Person>
        {
            protected override void ConfigMeta()
            {
Meta.Property(PersonExtentionDetailProperty.Extend1Property).DontMapColumn();
}
        }

4. 在界面附加子表单
View.AssociateChildrenProperty(PersonExtentionDetailProperty.Extend1Property, e =>
            {
                var entity = e.Parent as Person;
                var extend = RT.Service.Resolve<ComposeEntityConotroller>().QueryPhoneList(entity.Id);
                if (extend.Count == 0)
                {
                    var phone = new Phone();
                    phone.GenerateId();
                    return phone;
                }
                PersonExtentionDetailProperty.SetExtend1(entity, extend[0]);
                return extend[0];
            }, ViewConfig.DetailsView).HasLabel("预约信息").OrderNo = 1;
说明：默认分组为ListView，这里要显示正常，分组名必须指定且正确。

5. 数据的处理，可以通过提交事件或者重写命令实现，建议通过提交事件实现，参考代码如下：
public class SupAddressSubmitted : OnSubmitted<SupplierTest>
    {
        protected override void Invoke(SupplierTest entity, EntitySubmittedEventArgs e)
        {
            if (e.Action == SubmitAction.Insert || e.Action == SubmitAction.Update)
            {
                SupAddress supAddress = entity.GetProperty(SupAdressExtention.SupAddProperty);
                if (supAddress != null && supAddress.SupplierTestId ==0)
                {
                    supAddress.SupplierTestId = entity.Id;
                    RF.Save(supAddress);
                }
                else if(supAddress != null && supAddress.SupplierTestId > 0)
                {
                    RF.Save(supAddress);
                }
            }
            if(e.Action== SubmitAction.Delete)
            {
                var address = RT.Service.Resolve<OrderTestController>().SupAddress(entity.Id);
                if (address != null)
                {
                    address.PersistenceStatus = PersistenceStatus.Deleted;
                    RF.Save(address);
                }
            }
        }
    }

19.2.2. 附加列表
19.2.2.1. 实现方式
可通过AssociateChildrenProperty或者AttachChildrenProperty实现。
19.2.2.2. AttachChildrenProperty
1. 前端界面附加实现：
View.AttachChildrenProperty(typeof(BorrowBookMan), (c) =>
			{
				var args = c as ChildPagingDataArgs;
				var parent = args.Parent.CastTo<ReaderMan>();
				if (parent == null)
				{
					return new EntityList<BorrowBookMan>();
				}
				var borrowBooks = RT.Service.Resolve<BookManController>().GetBorrowBookMans(parent.Id, args?.SortInfo, args?.PagingInfo);
				return borrowBooks;
			}, BorrowBookManViewConfig.BorrowBooksReadonly).HasLabel("借书管理").Show(ChildShowInWhere.All);
2. 后台数据源查询方法实现：
        /// <summary>
        /// 获取读者对应的借书信息
        /// </summary>
        /// <param name="readerId">读者Id</param>
        /// <param name="orderInfos">排序信息</param>
        /// <param name="pagingInfo">分页信息</param>
        /// <returns></returns>
        public virtual EntityList<BorrowBookMan> GetBorrowBookMans(double readerId, IList<OrderInfo> orderInfos, PagingInfo pagingInfo)
        {
            var query = Query<BorrowBookMan>().Where(p => p.ReaderManId == readerId);
            query.Where(p => !p.IsReturn);
            var result = query.OrderBy(orderInfos).ToList(pagingInfo, new EagerLoadOptions().LoadWithViewProperty());
            return result;
        }

19.2.2.3. AssociateChildrenProperty 
1. 在服务端新建一个类，不需要继承父类，给类标记特性[CompiledPropertyDeclarer]
    [CompiledPropertyDeclarer]
    public class PersonExtentionDetailProperty
{

2. 用代码段添加扩展列表属性
        #region EntityList<PersonUint> PersonUintList (人员单位信息列表属性)
        /// <summary>
        /// 人员单位列表属性 扩展属性。
        /// </summary>
        public static readonly Property<EntityList<PersonUnit>> PersonUintListProperty =
            P<Person>.RegisterExtensionList<EntityList<PersonUnit>>("SupplierItemList", typeof(PersonExtentionDetailProperty));

        /// <summary>
        /// 获取 人员单位列表属性 属性的值。
        /// </summary>
        /// <param name="me">要获取扩展属性值的对象。</param>
        public static EntityList<PersonUnit> GetPersonUintList(Person me)
        {
            return me.GetProperty(PersonUintListProperty);
        }

        /// <summary>
        /// 设置 人员单位列表属性 属性的值。
        /// </summary>
        /// <param name="me">要设置扩展属性值的对象。</param>
        /// <param name="value">设置的值。</param>
        public static void SetPersonUintList(Person me, EntityList<PersonUnit> value)
        {
            me.SetProperty(PersonUintListProperty, value);
        }
        #endregion
说明：Person为对应主表的实体，PersonUnit为要附加的子列表，且附加的子PersonUnit和Person的关系是一般外键的引用关系，关系如下：

3. 在扩展属性对应的类中添加实体的配置类，配置扩展列表属性不映射数据库
        /// <summary>
        /// 扩展属性 实体配置
        /// </summary>
        internal class PersonExtentionDetailPropertyConfig : EntityConfig<Person>
        {
            protected override void ConfigMeta()
            {
Meta.Property(PersonExtentionDetailProperty.PersonUintListProperty).DontMapColumn();
            }
        }

4. 在界面附加子列表
View.AssociateChildrenProperty(PersonExtentionDetailProperty.PersonUintListProperty, e =>
            {
                var data=e as  ChildPagingDataArgs;
                var person = data.Parent as Person;
                if (person == null) return new EntityList<PersonUnit>();
                return RT.Service.Resolve<ComposeEntityConotroller>().GetPersonUnit(person.Id, (e as ChildPagingDataArgs)?.PagingInfo, (e as ChildPagingDataArgs)?.SortInfo);
            }, PersonUnitViewConfig.CostomView).HasLabel("单位信息");
说明：GetPersonUnit为列表数据展示的处理;
PersonUnitViewConfig.CostomView为自定义分组，默认分组为ListView

附加子后端数据查询方法：
public virtual EntityList<PersonUnit> GetPersonUnit(double PersonId, PagingInfo pagingInfo, IList<OrderInfo> orderInfos)
        {
            return Query<PersonUnit>().Where(p => p.PersonId == PersonId).OrderBy(orderInfos)
                .ToList(pagingInfo, new EagerLoadOptions().LoadWithViewProperty());
        }
