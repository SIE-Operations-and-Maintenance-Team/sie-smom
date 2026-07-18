# 半客制·全客制界面·排序·权限排查·JS按需加载

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch34-38
> **提取范围**：docx 正文行 7129-8329
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

34. 半客制化界面的实现示例
34.1. 开发初衷
开发人员可通过此 自定义布局方案 根据需求实现灵活多变的布局方式 。
34.2. 使用场景
当框架提供的布局或配置方式满足不了现有需求，需要客制化界面或自定义布局，又想兼容框架的各种事件关联、权限等，可使用此方案实现多样化的布局方式。
34.3. 实现说明
34.3.1. 自定义布局文件 
添加自定义布局文件 
在对应的模块项目里添加 对应的自定义 JS文件 (注意文件需嵌入为资源 )，如下图所示 ； 
文件命名规范 ： [Name]UIGenerator , 如 OQCUIGenerator 、 MenuUIGenerator.
 

 
34.3.2. Module指定 JS类名
在模块对应的 Module里指定自义布局 JS的类名 ，属性名为 UIGenerator ，如下图：
 

 
34.3.3. JS的写法
/**定义自定义布局的类*/   
Ext.define('SIE.autoUI.[Name]UIGenerator',   
{   
//必须继承   
extend: 'SIE.autoUI.UIGenerator',   
/**  
* 必须实现的方法  
* @param {any} aggtMeta 模块元数据  
*/   
generateControl: function (aggtMeta) {   
  
/////coding   
  
// 必须返回 SIE.autoUI.ControlResult(view,control)   
// view - 通过SIE.autoUI.ViewFactory生成的view   
// control - 通过Ext生成的control   
return new SIE.autoUI.ControlResult(this._mainView, control);   
}   
  
}); 
 
34.3.4. 实现示例
• 主从在上，孙在下

 
• 主在上，从孙在下

 
• Module.cs :
private void App_ModuleOperations(object sender, EventArgs e)  
{  
    CommonModel.Modules.AddModules(  
        new WebModuleMeta()  
        {  
            EntityType = typeof(ModuleConfig),  
            Label = "模块定义",  
            UIGenerator = "SIE.autoUI.ModuleUIGenerator"  
        },  
        );  
}  
 
• ModuleUIGenerator.js:
/**模块定义的UI生成器 */  
Ext.define('SIE.autoUI.ModuleUIGenerator',  
    {  
        extend: 'SIE.autoUI.UIGenerator',  
        _mainView: null,  
        _childView: null,  
        _grandsonView: null,  
        _conditionView: null,  
  
        /**必须实现的方法 */  
        generateControl: function (aggtMeta, entity) {  
            this._mainView = this._generateMainView(aggtMeta);  
            var control = this._layout();  
            if (this._mainView.hasListeners['isready']) {  
                this._mainView.fireEvent('isReady', true);  
            }  
            return new SIE.autoUI.ControlResult(this._mainView, control);  
        },  
  
        /**生成主视图 */  
        _generateMainView: function (aggtMeta, mainView) {  
            var mk = aggtMeta.mainBlock;  
            mainView = this._vf.createListView(mk);  
            if (aggtMeta.children) {  
                this._generateChild(aggtMeta.children[0], mainView);  
            }  
            if (aggtMeta.surrounders) {  
                this._generateConditionView(aggtMeta.surrounders[0], mainView);  
            }  
            return mainView;  
        },  
  
        /**生成查询视图 */  
        _generateConditionView: function (surrounderMeta, mainView) {  
            var cr = SIE.view.RelationView;  
            var conditionView = this._vf.createConditionView(surrounderMeta.mainBlock);  
            var reverseRelation = new SIE.view.RelationView(cr.result, mainView);  
            var relation = new SIE.view.RelationView(surrounderMeta.surrounderType, conditionView);  
            mainView._setRelation(relation);  
            conditionView._setRelation(reverseRelation);  
            this._conditionView = conditionView;  
        },  
  
        /**生成子视图 */  
        _generateChild: function (childMeta, mainView) {  
            var childView = this._vf.createListView(childMeta.mainBlock);  
            childView._childProperty = childMeta.childProperty;  
            childView._associatedProperty = childMeta.associatedProperty;  
            childView._setParent(mainView);  
            if (childMeta.children) {  
                this._generateGrandson(childMeta.children[0], childView);  
            }  
            this._childView = childView;  
        },  
  
        /**生成孙视图 */  
        _generateGrandson: function (grandSonMeta, childView) {  
            var grandSonView = this._vf.createListView(grandSonMeta.mainBlock);  
            grandSonView._childProperty = grandSonMeta.childProperty;  
            grandSonView._associatedProperty = grandSonMeta.associatedProperty;  
            grandSonView._setParent(childView);  
            this._grandsonView = grandSonView;  
        },  
  
        /** 
         * 主在上，从孙在下 
         */  
        _layout: function () {  
            var me = this;  
            //考虑权限增加留空处理  
            var childItems = this._childView ? {  
                region: 'center',  
                xtype: 'panel',  
                width: '50%',  
                defaults: {  
                    layout: 'fit'  
                },  
                title: me._childView.getMeta().label,  
                items: me._childView.getControl()  
            } : [];  
            //考虑权限增加留空处理  
            var grandSonItems = this._grandsonView ? {  
                region: 'east',  
                width: '50%',  
                xtype: 'panel',  
                title: this._grandsonView.getMeta().label,  
                items: this._grandsonView.getControl()  
            } : [];  
            //  
            var mainItems = {  
                xtype: 'container',  
                layout: 'border',  
                scrollable: false,  
                border: 0,  
                defaults: {  
                    collapsible: false,  
                    split: true,  
                    layout: 'fit',  
                    border: 0  
                },  
                items: [{  
                    region: 'center',  
                    height: '50%',  
                    title: me._mainView.getMeta().label,  
                    items: me._mainView.getControl(),  
                }, {  
                    region:'south',  
                    xtype: 'container',  
                    height: '50%',  
                    layout: 'border',  
                    scrollable: false,  
                    border: 0,  
                    defaults: {  
                        collapsible: false,  
                        split: true,  
                        layout: 'fit',  
                        border: 0  
                    },  
                    items: [childItems, grandSonItems]  
                }]  
            };  
  
            return Ext.widget('container', {  
                border: 0,  
                layout: 'border',  
                scrollable: false,  
  
                defaults: {  
                    collapsible: false,  
                    split: true,  
                    layout: 'fit',  
                    border: 0  
                },  
                items: [  
                    {  
                        region: 'west',  
                        width: 256,  
                        items: this._conditionView.getControl()  
                    }, {  
                        region: 'center',  
                        items: mainItems  
                    }]  
            });  
        },  
    });  
 
34.3.5. 半客制化界面注意事项
• 使用UIGenerator自定义布局，只能布局成listview，如果要显示为detailView，不能使用生成出来的getmeta，必须自己去重写getmeta

 
getmeta的实现
getMeta: function () {  
    var meta = null;  
    SIE.AutoUI.getMeta({  
        async: false,  
        isDetail: true,  
        ignoreQuery: true,  
        model: "SIE.Web.Collection.OutputCollections.OutputCollectViewModel",  
        viewGroup: "OutputCollectView",  
        callback: function (res) {  
            meta = res;  
        }  
    });  
    return meta;  
}, 
• 使用了View.HasDetailColumnsCount(3); 自定义多个分组界面会变成左右结构（不使用View.HasDetailColumnsCount(3)是上下结构的）


 
• 定义一个实体A，继承另外一个实体B（B继承的这个实体包含子），用实体A去配置界面和菜单，来加载实体B的子，会报找不到子的异常，错误如下：

用实体B挂菜单配置界面就正常了
• 自定义布局，扩展SIE.autoUI.UIGenerator，重写generateControl方法，generateControl的参数entity为空，如下图：

在生成表单时，这个entity为空，如果生成的表单有引用关系（下拉列表），就会报脚本异常，异常如下：

在框架还没有处理的情况下，可以自己去创建个entity处理，如下图，可以解决上图的异常

 
 
34.3.6. 通过UIGenerator实现采集布局前端示例
如下是半客制化界面实现采集界面的布局示例：
Ext.define('SIE.Web.Collection.OutputCollectUIGenerator',  
    {  
        extend: 'SIE.autoUI.UIGenerator',  
        _mainView: null,  
        _collectView: null,  
        _workstationView: null,  
        _conditionView: null,  
        generateControl: function (aggtMeta, entity) {  
            this._mainView = this._generateMainView(aggtMeta);  
            var control = this._layout();  
            return new SIE.autoUI.ControlResult(this._mainView, control);  
        },  
        /**生成主视图 */  
        _generateMainView: function (aggtMeta, mainView) {  
            var meta = this.getMeta();  
            var mk = meta.mainBlock;  
            mk.formConfig.items[0].border = 0;  
            mk.formConfig.items[0].items[0].fieldStyle = {  
                background: 'gray',  
                border: 0,  
                color: 'red',  
                fontSize: '20px',  
                fontWeight: 'bold'  
            }  
            mk.formConfig.items[0].items[1].fieldStyle = {  
                background: 'gray',  
                border: 0,  
                color: 'red',  
                fontSize: '20px',  
                fontWeight: 'bold'  
            }  
            var entity = Ext.create(aggtMeta.mainBlock.model);  
            entity.setTips("资源不能为空 工序不能为空 工位不能为空");  
            entity.setSelectType(0);  
            entity.setHasInputQty(0);  
            entity.setHasPrintedQty(0);  
            entity.setRemainQty(0);  
            entity.setBatchQty(0);  
            entity.setSingleQty(10);  
            entity.setPackageStatus(2);  
            mainView = this._vf.createDetailView(mk, entity);  
            if (meta.children) {  
                this._generateCollectChild(meta.children[0], mainView);  
                this._generateWorkstationChild(meta.children[1], mainView);  
            }  
            return mainView;  
        },  
        /**生成采集结果子视图 */  
        _generateCollectChild: function (collectChildMeta, mainView) {  
            var collectView = this._vf.createListView(collectChildMeta.mainBlock);  
            collectView._childProperty = collectChildMeta.childProperty;  
            collectView._setParent(mainView);  
            this._collectView = collectView;  
        },  
  
        /**生成工作站信息子视图 */  
        _generateWorkstationChild: function (workstationMeta, mainView) {  
            var user = Ext.decode(workstationMeta.mainBlock.formConfig.items[0].value);  
            var childEntity = Ext.create(workstationMeta.mainBlock.model);  
            var workstationView = this._vf.createDetailView(workstationMeta.mainBlock, childEntity);  
            childEntity.setUserId(user.Id);  
            childEntity.setUserId_Display(user.DisPlay);  
            workstationView._associatedProperty = workstationMeta.associatedProperty;  
            workstationView._setParent(mainView);  
            this._workstationView = workstationView;  
        },  
        getMeta: function () {  
            var meta = null;  
            SIE.AutoUI.getMeta({  
                async: false,  
                isDetail: true,  
                ignoreQuery: true,  
                model: "SIE.Web.Collection.OutputCollections.OutputCollectViewModel",  
                viewGroup: "OutputCollectView",  
                callback: function (res) {  
                    meta = res;  
                }  
            });  
            return meta;  
        },  
        /** 
         * 主在上，一个从显示在中间，一个从显示在下方 
         */  
        _layout: function () {  
            var me = this;  
            //考虑权限增加留空处理  
            var collectItems = this._collectView ? {  
                region: 'center',  
                xtype: 'panel',  
                height: '87%',  
                defaults: {  
                    layout: 'fit'  
                },  
                title: me._collectView.getMeta().label,  
                items: me._collectView.getControl()  
            } : [];  
            //考虑权限增加留空处理  
            var workstationItems = this._workstationView ? {  
                region: 'south',  
                height: '13%',  
                xtype: 'panel',  
                title: this._workstationView.getMeta().label,  
                items: this._workstationView.getControl()  
            } : [];  
            //  
            var mainItems = {  
                xtype: 'container',  
                layout: 'border',  
                scrollable: false,  
                border: 0,  
                defaults: {  
                    collapsible: false,  
                    split: true,  
                    layout: 'fit',  
                    border: 0  
                },  
                items: [{  
                    region: 'center',  
                    height: '40%',  
                    title: me._mainView.getMeta().label,  
                    items: me._mainView.getControl(),  
                }, {  
                    region: 'south',  
                    xtype: 'container',  
                    height: '60%',  
                    layout: 'border',  
                    scrollable: false,  
                    border: 0,  
                    defaults: {  
                        collapsible: false,  
                        split: true,  
                        layout: 'fit',  
                        border: 0  
                    },  
                    items: [collectItems, workstationItems]  
                }]  
            };  
  
            return Ext.widget('container', {  
                border: 0,  
                layout: 'border',  
                scrollable: false,  
  
                defaults: {  
                    collapsible: false,  
                    split: true,  
                    layout: 'fit',  
                    border: 0  
                },  
                items: [  
                    {  
                        region: 'center',  
                        items: mainItems  
                    }]  
            });  
        },  
  
  });  

34.3.7. 通过行为实现采集布局的前端示例
Ext.define("SIE.Web.LibMan.Behaviors.BorrowBooksBehavior", {
    /**
    * view生命周期函数--view生成前
    * @param {*} meta 实体实体元数据
    * @param {*} curEntity 当前操作实体(可空)
    */
    detailView: null,
    beforeCreate: function (meta, curEntity) {
        var me = this;
        meta.formConfig.items[0].items[0].fieldStyle = {
            background: 'lightgray',
            border: 0,
            color: 'green',
            fontSize: '20px',
            fontWeight: 'bold'
        };
        meta.formConfig.items[0].items[1].fieldStyle = {
            background: 'lightgray',
            border: 0,
            color: 'red',
            fontSize: '20px',
            fontWeight: 'bold'
        };
        meta.formConfig.items[1].items[0].fieldStyle = {
            background: 'lightgray',
            border: 0,
            color: 'green',
            fontSize: '20px',
            fontWeight: 'bold'
        }
        meta.formConfig.items[1].items[1].fieldStyle = {
            background: 'lightgreen',
            border: 0,
            fontSize: '20px',
            fontWeight: 'bold'
        }
        meta.formConfig.items[1].items[1].enableKeyEvents = true;
        meta.formConfig.items[1].items[1].listeners = {
            keyup: function (self, e, eOpt) {
                if (e.keyCode == 13) {
                    var entity = me.detailView.getCurrent();
                    if (entity.getReaderNo() == "") {
                        entity.setTips("请先输入读者编号！".t());
                        return false;
                    }
                    if (entity.getBookNo() == "") {
                        entity.setTips("请扫描图书编号！".t());
                        return false;
                    }
                    saveBorrowBooksData(me, entity);
                }
            }
        }
    },
    onViewReady(view) {
        this.detailView = view;
        var entity = Ext.create(view.model);
        entity.setTips("请先输入读者编号，再扫描图书编号");
        entity.setErrors("错误信息");
        view.setCurrent(entity);
    },
});

function saveBorrowBooksData(me,entity) {
    myAjax({
        method: 'SaveBorrowBooksData',
        params: [entity.getReaderNo(), entity.getBookNo()],
        action: 'queryer',
        async: true,
        type: 'SIE.Web.LibMan.DataQuerys.BorrowReturnBooksDataQuery',
        token: me.detailView.getToken(),
        success: function (result) {
            entity.setTips("图书编号：" + entity.getBookNo() + "借书成功！");
            entity.setErrors("错误信息");
            entity.setBookNo(null);
            me.detailView.getChildren().forEach(function (v) {
                loadData(v);
            })
        },
        error: function (errorMessage) {
            entity.setErrors(errorMessage);
            entity.setTips("请扫描图书编号");
        }
    });
}

function myAjax(op) {
    var me, action, filter;
    op = Ext.apply({
        "async": !0
    }, op);
    me = this;
    action = "queryer";
    op.action && (action = op.action);
    filter = {
        Method: op.method,
        Parameters: op.params || []
    };
    SIE.Ajax({
        url: "/api/DataPortal/Query",
        timeout: op.timeout,
        "async": op.async,
        method: "POST",
        params: {
            action: action,
            type: op.type,
            filter: SIE.data.Utils.seriaizeRequest(filter),
            token: op.token
        },
        success: function (response) {
            var res = response.responseJson;
            !res && response.responseText && (res = Ext.decode(response.responseText));
            SIE.data.Utils.deserializeResponse(res);
            res.Success
                ? (op.success && op.success(res.Result))
                : (op.error ? op.error(res.Message) : SIE.Msg.showError(res.Message))
        },
        failure: function (response) {
            if ("communication failure" === response.statusText)
                SIE.Msg.showWarning("请求时间超时".t());
            else if (response.statusText !== "") {
                var res = response.responseJson;
                !res && response.responseText && (res = Ext.decode(response.responseText),
                    SIE.Msg.showError(res.Message))
            }
        }
    })
}

function loadData(view) {
    var args = {};
    var me = view, parent, pName, root;
    args = args || me._lastDataArgs || {};
    Ext.isFunction(args) && (args = {
        callback: args
    });
    this._lastDataArgs = args;
    var entity = me.getCurrent()
        , store = me.getData()
        , proxy = store.proxy;
    args.clearSort && (store.sorters = null);
    proxy.setExtraParams({});
    proxy.setExtraParam("token", args.token || me.getToken());
    proxy.extraParams && proxy.extraParams.action || proxy.setExtraParam("action", args.action || proxy.action || "entity");
    args.action && proxy.setExtraParam("action", args.action);
    proxy.extraParams && proxy.extraParams.type || proxy.setExtraParam("type", args.type || me.model);
    proxy.setExtraParam("viewGroup", me.viewGroup);
    proxy.setExtraParam("url", args.url || proxy.url);
    proxy.setExtraParam("parentEntity", Ext.encode(me._parent.getData().data));
    typeof args.async == "undefined" || (proxy.isSynchronous = !args.async);
    proxy.setExtraParam("searchKeyWord", args.searchKeyWord || proxy.searchKeyWord);
    (args.filter || proxy.filter) && proxy.setExtraParam("filter", args.filter || proxy.filter);
    args.sort && proxy.setExtraParam("sort", args.sort);
    args.page && proxy.setExtraParam("page", args.page);
    args.method ? SIE.data.Utils.filterByMethod(store, args.method, args.params) : args.criteria && SIE.data.Utils.filterByCriteria(store, args.criteria);
    parent = me._parent;

    parent && parent._current && (pName = me._childProperty,
        pName || (proxy.setExtraParam("action", "delegate"),
            proxy.setExtraParam("parent", parent.model),
            proxy.setExtraParam("filter", Ext.encode([{
                property: SIE._KeyPropertyName,
                value: parent._current.data[SIE._KeyPropertyName],
                exactMatch: !0
            }]))));
    proxy.timeout = args.timeout || !1;
    store._ondataloaded || (store.mon(store, "load", function () {
        me.fireEvent("ondataloaded")
    }),
        store._ondataloaded = !0);
    me._isTree ? (Ext.apply(proxy, {
        extractResponseData: function (response) {
            var responseObj = response.responseJson, entities;
            return (!responseObj && response.responseText && (responseObj = Ext.decode(response.responseText)),
                responseObj.Success) ? (entities = responseObj.Result.entities,
                    Ext.each(entities, function (o) {
                        o.leaf = !0;
                        o.parentId = o.TreePId;
                        Ext.each(entities, function (x) {
                            if (o.Id == x.TreePId)
                                return o.leaf = !1,
                                    !1
                        })
                    }),
                    responseObj.Result) : (SIE.Msg.showError(responseObj.Message),
                        response)
        }
    }),
        me._treeStoreInited || (me._treeStoreInited = !0,
            root = store.getRootNode(),
            root.set("loaded", !1)),
        store.load(function (records, operation, success) {
            me.setCurrent(null, !0);
            store._loaded = success;
            args.callback && args.callback(arguments);
            delete proxy.getExtraParams().page
        })) : (store.rejectChanges(),
            store.autoLoad = !0,
            store.load({
                url: args.url || proxy.url,
                callback: function (records, operation, success) {
                    me.getCurrent() != null ? me.setCurrent(null, !0) : me.syncCmdState();
                    store._loaded = success;
                    me.fireReloadData(me, entity);
                    args.callback && args.callback(arguments);
                    delete proxy.getExtraParams().page
                }
            }))
}
35. 全客制化界面实现示例
35.1. 说明
一般情况下，尽量不要使用全客制化去处理业务功能，如果使用全客制化，命令，命令的权限，相关事件，编辑器都要自己去实现；我们尽量使用半客制化去处理框架满足不了的功能（前端布局使用客制化的，其它能用框架的尽量使用框架）
 
实现下图所示布局：

35.2. 实现说明
35.2.1. 菜单绑定
[assembly: Module(typeof(SIE.Web.UIDEMO.Module))]  
namespace SIE.Web.UIDEMO  
{  
    public class Module : UIModule  
    {  
        public override void Initialize(IApp app)  
        {  
            app.ModuleOperations += (s, e) =>  
            {  
                CommonModel.Modules.AddModules(new WebModuleMeta()  
                {  
                    Label = "采集界面示例",  
                    EntityType = typeof(CustomUI),  
                    ModuleRuntime = "SIE.Web.UIDEMO.CustomUIModuleRuntime"  
                });  
            };  
        }  
    }  
}  
35.2.2. CustomUI及其界面配置，子实体和子实体的界面配置
[RootEntity, Serializable]  
[Label("客制化测试")]  
public class CustomUI : ViewModel  
{  
    #region ChildrenA ChildrenA  
    /// <summary>  
    /// ChildrenA  
    /// </summary>  
    [Label("ChildrenA")]  
    public static readonly ListProperty<EntityList<TESTA>> ChildrenAProperty = P<CustomUI>.RegisterList(e => e.ChildrenA);  
  
    /// <summary>  
    /// ChildrenA  
    /// </summary>  
    public EntityList<TESTA> ChildrenA  
    {  
        get { return this.GetLazyList(ChildrenAProperty); }  
    }  
    #endregion  
 
    #region ChildrenB ChildrenB  
    /// <summary>  
    /// ChildrenB  
    /// </summary>  
    [Label("ChildrenB")]  
    public static readonly ListProperty<EntityList<TESTB>> ChildrenBProperty = P<CustomUI>.RegisterList(e => e.ChildrenB);  
  
    /// <summary>  
    /// ChildrenB  
    /// </summary>  
    public EntityList<TESTB> ChildrenB  
    {  
        get { return this.GetLazyList(ChildrenBProperty); }  
    }  
    #endregion  
}  
 
 
namespace SIE.Web.UIDEMO  
{  
    public class CustomUIViewConfig:WebViewConfig<CustomUI>  
    {  
        protected override void ConfigView()  
        {  
            View.ChildrenProperty(p => p.ChildrenA);  
            View.ChildrenProperty(P => P.ChildrenB);  
        }  
    }  
}  
 
35.2.3. 子实体和子实体的界面
[Serializable]  
[RootEntity]  
[Label("测试子页签A")]  
public class TESTA: ViewModel  
{  
    #region A属性名 Name  
    /// <summary>  
    /// A属性名  
    /// </summary>  
    [Label("A属性名")]  
    public static readonly Property<string> NameProperty = P<TESTA>.Register(e => e.Name);  
  
    /// <summary>  
    /// A属性名  
    /// </summary>  
    public string Name  
    {  
        get { return this.GetProperty(NameProperty); }  
        set { this.SetProperty(NameProperty, value); }  
    }  
    #endregion  
  
} 
 
[Serializable]  
[RootEntity]  
[Label("测试子页签B")]  
public class TESTB: ViewModel  
{  
    #region B属性名 Name  
    /// <summary>  
    /// B属性名  
    /// </summary>  
    [Label("B属性名")]  
    public static readonly Property<string> NameProperty = P<TESTB>.Register(e => e.Name);  
  
    /// <summary>  
    /// B属性名  
    /// </summary>  
    public string Name  
    {  
        get { return this.GetProperty(NameProperty); }  
        set { this.SetProperty(NameProperty, value); }  
    }  
    #endregion  
  
} 
 
public class TestAViewConfig:WebViewConfig<TESTA>  
{  
    protected override void ConfigView()  
    {  
        View.UseDefaultCommands();  
        View.Property(p => p.Name).Show();  
    }  
} 
 
public class TestBViewConfig:WebViewConfig<TESTB>  
{  
    protected override void ConfigView()  
    {  
        View.Property(p => p.Name).Show();  
    }  
} 
 
35.2.4. CustomUIModuleRuntime.JS的实现
Ext.define('SIE.Web.UIDEMO.CustomUIModuleRuntime', {  
    extend: 'SIE.ModuleRuntime',  
  
    constructor: function (meta) {  
        this.callParent(arguments);  
    },  
  
    /** 
     * 创建UI 
     * @param {string} module 模块信息 
     */  
    createUI: function (module) {  
        var ui = this.buildUI(module);  
        return ui;  
    },  
  
    /** 
     * 组建UI 
     * @param {*} module  
     */  
    buildUI: function (module) {  
        //获取元素据  
        var meta = this.getMeta(module);  
        //创建控件  
        var tabControl = this.createAggtControl(meta);  
        var panel = Ext.create('Ext.panel.Panel', {  
            layout: {  
                type: 'vbox',  
                pack: 'start',  
                align: 'stretch'  
            },  
            border: false,  
            defaults: {  
                border: false  
            },  
            items: [{  
                    xtype: 'toolbar',  
                    items: [{  
                            xtype: 'button',  
                            text: '作业指导书'  
                        },  
                        {  
                            xtype: 'button',  
                            text: '重新开始'  
                        }, '-', {  
                            xtype: 'button',  
                            text: '配置项'  
                        }  
                    ]  
                },  
                {  
                    xtype: 'form',  
                    items: [{  
                            xtype: 'component',  
                            flex: 1,  
                            margin: '10 10 0 10',  
                            html: '<input type="text" id="input-scan" style="width:100%;height:32px;border:0;color: green;\  
                                                font-size: 24px;\  
                                                font-weight: 500;" value="请扫描条码">'  
                        },  
                        {  
                            xtype: 'component',  
                            flex: 1,  
                            margin: '10 10 0 10',  
                            html: '<input type="text" id="input-scan" style="width:100%;height:32px;border:0;color: red;\  
                                                font-size: 24px;\  
                                                font-weight: 500;" value="工序不能为空。工位不能为空。资源不能为空。">'  
                        },  
                        {  
                            xtype: 'fieldset',  
                            margin: '10 10 0 10',  
                            title: '扫描信息',  
                            collapsible: true,  
                            defaults: {  
                                labelWidth: 90,  
                                anchor: '100%',  
                                layout: 'hbox'  
                            },  
                            items: [{  
                                xtype: 'fieldcontainer',  
                                items: [{  
                                        xtype: 'component',  
                                        flex: 1,  
                                        margin: '0 20 0 0',  
                                        //contentEl:'input-scan',  
                                        html: '<input type="text" id="input-scan" style="width:100%;background:#90ee90;height:32px;border:0">'  
                                        //fieldCls:'input-scan'  
                                    },  
                                    {  
                                        xtype: 'button',  
                                        width: 260,  
                                        text: '上料',  
                                        margin: '0 10 0 0'  
                                    },  
                                    {  
                                        xtype: 'button',  
                                        width: 260,  
                                        text: '装配采集'  
                                    }  
                                ]  
                            }]  
                        },  
                        {  
                            xtype: 'fieldset',  
                            margin: '10 10 0 10',  
                            title: '工单信息',  
                            collapsible: true,  
                            defaultType: 'textfield',  
                            defaults: {  
                                anchor: '100%',  
                            },  
  
                            items: [{  
                                    xtype: 'container',  
                                    layout: 'hbox',  
                                    defaultType: 'textfield',  
                                    margin: '0 10 5 0',  
                                    defaults: {  
                                        margin: '0 10'  
                                    },  
                                    items: [{  
                                        fieldLabel: '工单号',  
                                        name: 'email',  
                                        labelWidth: 100,  
                                        vtype: 'email',  
                                        flex: 1,  
                                        allowBlank: false  
                                    }, {  
                                        fieldLabel: '产品名称',  
                                        name: 'phone',  
                                        flex: 1,  
                                        labelWidth: 100,  
  
                                    }, {  
                                        fieldLabel: '当班采集数',  
                                        name: 'phone',  
                                        flex: 1,  
                                        labelWidth: 100,  
  
                                    }]  
                                },  
                                {  
                                    xtype: 'container',  
                                    layout: 'hbox',  
                                    defaultType: 'textfield',  
                                    margin: '0 10 5 0',  
                                    defaults: {  
                                        margin: '0 10'  
                                    },  
                                    items: [{  
                                            fieldLabel: '产品编码',  
                                            name: 'email',  
                                            labelWidth: 100,  
                                            vtype: 'email',  
                                            flex: 1,  
                                            allowBlank: false  
                                        }, {  
                                            fieldLabel: '产品型号',  
                                            name: 'phone',  
                                            flex: 1,  
                                            labelWidth: 100,  
  
                                        },  
                                        {  
                                            xtype: 'component',  
                                            flex: 1  
                                        }  
                                    ]  
                                }  
                            ]  
                        }  
  
                    ]  
                },  
                tabControl  
            ]  
        });  
  
        return new SIE.autoUI.ControlResult(null, panel);  
    },  
  
    /** 
     * 调用SIE.AutoUI.getMeta获取元素据 
     * @param {string} module 模块信息 
     */  
    getMeta: function (module) {  
        var meta = null;  
        SIE.AutoUI.getMeta({  
            async: false,  
            module: module.keyLabel,  
            model: module.model,  
            callback: function (res) {  
                meta = res;  
            }  
        });  
        return meta;  
    },  
  
    /** 
     * 利用SIE.AutoUI创建控件 
     * @param {object} meta  
     */  
    createAggtControl: function (meta) {  
        var me = this;  
        var tabPanel = {  
            xtype: 'tabpanel',  
            margin: '10 10 0 10',  
            flex: 1,  
            defaults:{  
                layout:'fit'  
            },  
            items: []  
        };  
        Ext.Array.forEach(meta.children, function (item) {  
            var tabItem = SIE.AutoUI.createListView(item.mainBlock);  
            tabPanel.items.push({  
                title: tabItem.label,  
                items: tabItem.getControl()  
            });  
        });  
        return tabPanel;  
    }  
  
});  
 
 


36. BS排序说明
36.1. 启用前端（内存）排序
在ViewConfig中配置函数 View.UseClientOrder();
36.2. 自定义查询实体支持后台排序
需要在自定义查询方法中添加排序
query.OrderBy(criteria.OrderInfoList).ToList(criteria.PagingInfo, new EagerLoadOptions().LoadWithViewProperty())

36.3. 附加子支持后台排序
在附加子列表中把子对应的实体转换为ChildPagingDataArgs，并把排序参数传到后端做对应的排序处理。
View.AttachChildrenProperty(typeof(UserInUserGroup), (w =>  
{  
    var args = w as ChildPagingDataArgs;  
    var user = w.Parent as User;  
    var groupUser = RT.Service.Resolve<UserController>().GetGroupUserListByUserId(user.Id, args.SortInfo, args.PagingInfo);  
    return groupUser;  
}), "GroupUser"/*, childLayoutType: ChildLayoutType.Card*/);  
 
36.4. 引用属性支持实体配置的DisplayMember排序
默认以DisplayMember进行排序，若没有配置则以ID进行排序（在8.1之前的版本中可以不配置DisplayMember，之后的版本不配置，下拉列表会报错）。
 
 
36.5. 框架子表排序处理
/// <summary>  
/// 通过父对象 Id 分页查询子对象的集合(带排序)。  
/// </summary>  
/// <param name="parentId"></param>  
/// <param name="paging"></param>  
/// <param name="sortList"></param>  
/// <param name="eagerLoad">需要贪婪加载的属性。</param>  
/// <returns>实体列表</returns>  
public override EntityList GetSortByParentId(object parentId, PagingInfo paging = null,  
    IList<OrderInfo> sortList = null, EagerLoadOptions eagerLoad = null)  
{  
    var parentProperty = FindParentPropertyInfo(true);  
    var mp = (parentProperty.ManagedProperty as IRefProperty).RefIdProperty;  
  
    var table = Qf.Table(this);  
    var query = Qf.Query(  
        table,  
        where: Qf.Constraint(table.Column(mp), parentId)  
    );  
    foreach (var sortInfo in sortList)  
    {  
        var property = EntityMeta.ManagedProperties.FindProperty(sortInfo.Property, true);  
        if (property == null || property.IsReadOnly) continue; //只读属性可以只存在于View，服务器上没有  
        if (property != null)  
        {  
            var viewProperty = property as IViewProperty;  
            if (viewProperty != null)  
            {  
                var finder = new ViewPathFinder(query, this);  
                finder.Find(viewProperty.ViewPath);  
                query.OrderBy.Add(finder.PropertyOwnerTable.Column(finder.Property), sortInfo.SortOrder);  
            }  
            else if (property is IRefIdProperty)  
            {  
                var attributes =  
                    (SIE.ObjectModel.DisplayMemberAttribute[])((RefIdProperty<double>)property)  
                    .RefEntityType.GetCustomAttributes(typeof(SIE.ObjectModel.DisplayMemberAttribute),  
                        false);  
  
                if (attributes.Count() > 0)  
                {  
                    var refPropertyName = ((RefIdProperty<double>)property).RefEntityProperty.Name + "." +  
                                          attributes[0].Property;  
                    var finder = new ViewPathFinder(query, this);  
                    finder.Find(refPropertyName);  
                    query.OrderBy.Add(finder.PropertyOwnerTable.Column(finder.Property), sortInfo.SortOrder);  
                }  
                else  
                {  
                    query.OrderBy.Add(query.MainTable.Column(property), sortInfo.SortOrder);  
                }  
            }  
            else  
            {  
                query.OrderBy.Add(query.MainTable.Column(property), sortInfo.SortOrder);  
            }  
        }  
    }  
  
    query.MainTable.Alias = QueryGenerationContext.Get(query).NextTableAlias();  
  
    var args = new EntityQueryArgs(query);  
    args.SetFetchType(FetchType.List);  
    args.SetDataLoadOptions(paging, eagerLoad);  
    return QueryList(args);  
}  
#endregion  
 
 
框架主表和附加子排序处理
public static IQuery ToQuery(this IEntityQueryer queryer, out System.Linq.Expressions.NewExpression exp)  
{  
    var expression = queryer.Expression;  
    expression = Evaluator.PartialEval(expression);  
    var builder = new EntityQueryerBuilder(queryer.Repository);  
    exp = builder.NewExpression;  
    var query = builder.BuildQuery(expression, queryer.Alias);  
    if (!object.ReferenceEquals(queryer.WhereCriteria, null))  
        query.Where = QueryFactory.Instance.And(query.Where, new CriteriaBuilder(query).Build(queryer.WhereCriteria));  
    if (!object.ReferenceEquals(queryer.HavingCriteria, null))  
        query.Having = QueryFactory.Instance.And(query.Having, new CriteriaBuilder(query).Build(queryer.HavingCriteria));  
    if (!object.ReferenceEquals(queryer.OrderByCriteria, null))  
    {  
        foreach (var item in queryer.OrderByCriteria)  
        {  
            var property = queryer.Repository.EntityMeta.ManagedProperties.FindProperty(item.Property, true);  
            if (property == null || property.IsReadOnly) continue;//只读属性可以只存在于View，服务器上没有  
            if (property != null)  
            {  
                var viewProperty = property as IViewProperty;  
                if (viewProperty != null)  
                {  
                    var finder = new ViewPathFinder(query, queryer.Repository);  
                    finder.Find(viewProperty.ViewPath);  
                    query.OrderBy.Add(finder.PropertyOwnerTable.Column(finder.Property), item.SortOrder);  
                }  
                else if (property is IRefIdProperty)  
                {  
                    var attributes =  
                        (SIE.ObjectModel.DisplayMemberAttribute[]) ((RefIdProperty<double>) property)  
                        .RefEntityType.GetCustomAttributes(typeof(SIE.ObjectModel.DisplayMemberAttribute),  
                            false);  
  
                    if (attributes.Count() > 0)  
                    {  
                        var refPropertyName = ((RefIdProperty<double>) property).RefEntityProperty.Name + "." +  
                                              attributes[0].Property;  
                        var finder = new ViewPathFinder(query, queryer.Repository);  
                        finder.Find(refPropertyName);  
                        query.OrderBy.Add(finder.PropertyOwnerTable.Column(finder.Property), item.SortOrder);  
                    }  
                    else  
                    {  
                        query.OrderBy.Add(query.MainTable.Column(property), item.SortOrder);  
                    }  
                }  
                else  
                    query.OrderBy.Add(query.MainTable.Column(property), item.SortOrder);  
            }  
        }  
    }  
    return query;  
}  
 
 


37. 界面权限问题及排查
37.1. 说明
在SMOM-BS开发中会涉及相关权限问题，可能导致界面出不来，或者权限配置出不来，请按以下场景进行排查。
37.2. 场景1
附加子界面，普通账户没有权限问题，管理员有权限
普通账户界面显示

 
管理员界面显示

 
原因是附加子需要在附加子的界面中指定父实体，指定完成后点击模块初始化即可显示出来View.AssignAuthorize(typeof(父实体名))

 
注意：如果是主从孙结构，主表和从表是附加的关系，从表和孙表也是附加的关系，则从表和孙表的授权都是授权到主表
37.3. 场景2 
BS中半客制化界面非管理员界面附加子加载不出来
1）在加载不出来的子中给界面授权：View.AssignAuthorize(typeof(挂菜单的父类))
2）前端JS，在对应的操作的getMeta方法中指定module（这里的module设置为父的实体），注意：主和子存在关系的不能设置module，否则页面刷新会存在问题。

37.4. 场景3 
自定义分组的操作按钮显示不出来
实现：需要在界面上声明对应的ViewGroup（8.0以前的版本默认是有操作权限的，8.0的版本改成了默认没有权限，如果自定义的分组没有声明，操作权限显示不出来）
View.DeclareExtendViewGroup(MainView, DetailView, UnQualifiedAuditView);

37.5. 场景4
配置权限时，子类中存在父类的视图及命令权限配置 

• 原因分析：子类和父类映射的是同一张表，而框架是用label生成的命令，如果同一个基类的话，基类的命令就会默认加载出来。
• 期望：根据实体对应的视图进行权限配置，子类里面不需要出现父类的视图
• 解决方式：
  • 父类的listview中不要去加命令，把命令加到子类中
如下图可以把这些命令申明成一个集合，在显示的子类UseCommands去使用
 

  • 如果上还不能解决问题，就再抽个基类出来，把命令定义到子类
 
37.6. 场景5
重写命令，继承的子类也是重写的，分配权限时，只分配了重写的命令，继承的子类没有分配命令权限，导致普通账号没有权限，异常如下：


解决方案：一种方式是给继承的子名字授权；还有就是从代码上调整，不要去继承业务命令的实现。
37.7. 场景6
通过Ext.create的方式去创建命令，执行命令，如果没有给创建的这个命令分配权限，普通账号会报“没有执行权限的权限，请分配”，代码示例如下：


37.8. 权限问题的排查
1. 先进行模块初始化
2. 然后在模块定义中有没有生成对应的视图配置和命令配置，如以单位为例

3. 然后查看角色的编辑权限，有没有对应的权限（一般步骤2模块定义的数据正常，权限这边的也会正常，因为界面的操作权限是根据模块定义的数据生成出来的）
4. 如果有问题的话，按1，2，3，4，5，6的场景排查代码
 
 


38. JS按需加载方法
38.1. View.RequierModels（加载类）
View.RequierModels(typeof(类)); 

38.2. View.RequirModuleResource（加载模块嵌入资源）
View.RequirModuleResource("资源名称");

38.3. View.RequireResource(加载第三方JS)
View.RequireResource("JS相对路径");


