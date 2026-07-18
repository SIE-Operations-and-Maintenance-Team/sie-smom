# Ajax·SMOM8.2部署·数据库操作·示例·经验总结

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch39-43
> **提取范围**：docx 正文行 8330-8677
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

39. 通过ajax请求后台方法
这种方式作为了解就可以了，有向后端请求数据的，可以参考前面的“16.前后端数据请求”的实现。
39.1. SIE.Ajax(参数)
39.1.1. 参数
• async:true/flase-是否异步执行
• url:'/api/DataPortal/Query?type=xxxx&token=menudataqueryer&filter=xx'-后台方法及参数
• success:-调用成功回调函数
39.2. 示例
onRefresh: function() {  
    var view = this.getView();  
    var filter = {  
        Method: 'GetAllModuleConfig',  
        Parameters: []  
    };  
    filter = Ext.encode(filter);  
    SIE.Ajax({  
        async: true,//异步
        url: '/api/DataPortal/Query?type=SIE.Web.Rbac.Menus.DataQueryer.MenuDataQueryer&token=menudataqueryer&filter=' + filter,//URL
        success: function (res) {//成功回调参数
            var jsonRes = JSON.parse(res.responseText);  
            view.store.setData(jsonRes.Result);  
        }
    });  
},


40. SMOM8.2部署
40.1. 说明
请参考《SMOM部署文档-8.2.docx》文档。
[OLE: Word.Document.12]
41. 数据库操作
41.1. DB操作数据库
41.1.1. 更新数据操作

41.1.2.  删除数据操作

41.1.3.  查询数据操作

41.2. 框架执行SQL操作
自定义一个sql字符串

[OLE: Word.OpenDocumentText.12]
[OLE: Package]
说明：自定义SQL查询所有数据，在内存中做分组汇总，可以查看WMS的报表实现，逻辑在StatisticsController中实现。
41.3. 框架执行存储过程

41.4. 事务的使用
using (var tran = DB.TransactionScope(CommonEntityDataProvider.ConnectionStringName))
{
	//具体操作数据库的逻辑
	tran.Complete();
}
using (var tran = DB.AutonomousTransactionScope(CommonEntityDataProvider.ConnectionStringName))
{//自治事务，不受嵌套影响
	//具体操作数据库的逻辑
	tran.Complete();
}
说明：
1. CommonEntityDataProvider.ConnectionStringName为对应工程的数据库提供者；
2. tran.Complete为事务执行完成的标记；
3. 事务内只放保存数据业务操作逻辑，一些查询和验证的操作移到事务外进行操作；
4. 操作单表的数据保存逻辑不要使用事务；
5. 事务只能在服务端进行操作。

41.5. 实体配置映射视图

1. 通过linq查询的方式映射视图

2. 通过SQL映射视图
实体继承Entity<Double>

列的处理：

视图的映射：

41.6. ViewModel分页失效问题
界面查询方法自己做数据转换的分页生效，返回对象需要设置SetTotalCount。

41.7. Exists的用法

42. 示例参考
42.1. 隐藏登录界面的“1天内自动登录”
如下图，隐藏右下角的“1天内自动登录”

实现步骤：
1.在webclient的wwwroot中增加自定义样式，如下account.css

2.设置.remembeiPwd的样式为隐藏

3. 将样式CSS文件设置为始终复制

42.2. 嵌入Echart报表示例
几个重要的js如下：

1、将echart的js直接嵌入web项目以供使用；
 
2、自定义通用布局，实现如下左查询、上表下图的布局

通用布局代码如下：
Ext.define('SIE.Web.Report.Common.Scripts.CommonReportLayout', {
    extend: 'SIE.autoUI.layouts.Common',
    mainView: null,//主视图（表）
    criteriaView: null,//查询视图
    chartControl: null,//echart图控件
    chartOption: { //通用echart图表配置，子类创建图时使用以保持相同风格减少重复配置
        backgroundColor: '#ffffff',
        legend: {},
        tooltip: {
            trigger: 'axis',
        },
        dataZoom: [
            {   // 这个dataZoom组件，默认控制x轴。
                type: 'slider', // 这个 dataZoom 组件是 slider 型 dataZoom 组件
                start: 0,      // 左边在 0% 的位置。
                end: 100         // 右边在 100% 的位置。
            }
        ],
        toolbox: {//工具栏配置
            show: true,
            feature: {
                dataZoom: {
                    yAxisIndex: 'none'
                },
                dataView: { readOnly: false },
                magicType: { type: ['line', 'bar'] },
                restore: {},
                saveAsImage: {}
            }
        },
        dataset: {//数据源
            source: [],
        },
    },
    /**
     * 布局
     * @method layout
     * @for SIE.Web.MES.WipReworks.WipReworkLayout
     * @param {regions} regions 聚合块
     * @return {container} 结果控件
     */
    layout: function (regions) {
        var me = this;
        me.mainView = regions.main._view;
        me.mainView.reportLayout = me;
        var mainControl = regions.main.getControl();
        var condition = regions.getCondition();
        me.criteriaView = condition.getView();
        me.criteriaView.reportLayout = me;
        me.registerEvent();
        //定义一个form布局来容纳一个图控件
        var formCtl = {
            xtype: 'form',
            layout: 'fit',
            plain: true,
            items: [{
                id: 'reportChart',
                xtype: 'container',
                width: '100%',
                height: '100%',
            }]
        };
        //把form作为子项与主控件结合
        var childrenUI = this.layoutChildrenCore(mainControl, formCtl);
        var res = this._layoutNaviCondition(regions, childrenUI);
        return res;
    },
    /**
    * 获取图表domElement
    * @method getChartElement
    */
    getChartElement: function () {
        return document.getElementById("reportChart");
    },
    /**
    * 注册事件
    * @method registerEvent
    */
    registerEvent: function () {
    },
});
 
3、在上面布局上，存在两种情况，一是图表一致（图的展示完全依赖于表数据），二是不一致；
针对图表一致的，封装了TableChartFitReportLayout布局，在表数据加载后自动绘图；代码如下：
Ext.define('SIE.Web.Report.Common.Scripts.TableChartFitReportLayout', {
    extend: 'SIE.Web.Report.Common.Scripts.CommonReportLayout',//继承通用布局
    /**
    * 注册事件
    * @method registerEvent
    */
    registerEvent: function () {
        var me = this;
        //注册数据加载完毕事件，以在加载完数据后自动根据数据绘图
        me.mainView.mon(me.mainView, 'ondataloaded', me.onDataLoaded, me);
    },
    /**
    * 数据加载完毕处理方法
    * @method onDataLoaded
    */
    onDataLoaded: function () {
        var me = this;
       //将表格的数据整理到数组传给绘图方法
        var datas = [];
        me.mainView.getData().getData().items.forEach(item => {
            datas.push(item.data);
        });
        me.drawChart(datas);
    },
    /**
    * 绘制图表
    * @method drawChart
    */
    drawChart: function (datas) {
        var me = this;
        if (!me.chartControl) {
            //echart绘图前需要先初始化图表控件
            me.chartControl = echarts.init(me.getChartElement());
            //用数据绘图
            me.initChart(datas);
        } else {
            //如果已经初始化过，就不需要重复初始化，更新图的数据源即可
            me.setChartDataSource(datas);
        }
    },
    /**
    * 初始化图表（报表需要重写此方法，来进行图控件配置）
    * @method initChart
    */
    initChart: function (datas) {
 
    },
    /**
    * 设置图表数据源
    * @method setChartDataSource
    */
    setChartDataSource: function (datas) {
        var me = this;
        if (me.chartControl && datas) {
            me.chartControl.setOption({
                dataset: {
                    source: datas,
                }
            });
        }
    },
});
 
4、具体使用上述图表一致的示例
（1）使用模板，模板中指定布局

 

 
（2）布局中实现initChart方法，以配置echart图表

具体配置dataset参照官网如下部分。其它echart本身配置也直接看官网
Documentation - Apache ECharts

 
（3）表格部分正常和查询等部分，正常写即可。在表格数据加载完后，就会根据配置自行展示图。
 
5、图表不一致时，重写查询命令，在查询表数据时，同时查询图的数据来展示。通用命令代码如下：
SIE.defineCommand('SIE.Web.Report.Common.Commands.TableChartUnfitQueryCommand', {
    extend: 'SIE.cmd.ExecuteQuery',
    meta: { text: "查询", iconCls: "icon-Search icon-blue" },
    execute: function (view) {
        var me = this;
        this.callParent(arguments);//保留基类查询的动作，即查询表数据
        me.drawChart(view);//额外进行绘图
    },
    /**
    * 绘制图表
    * @method drawChart
    */
    drawChart: function (view) {
        var me = this;
        var reportLayout = view.reportLayout;
        if (!reportLayout.chartControl) {
            me.initChart(view);//未初始化过控件则初始化
        } else {
            me.reloadChartDataSource(view);//否则直接更新数据源
        }
    },
    /**
    * 初始化图表
    * @method initChart
    */
    initChart: function (view) {
        var me = this;
        var reportLayout = view.reportLayout;
        reportLayout.chartControl = echarts.init(reportLayout.getChartElement());
 
        //获取图表配置，并为其设置数据源
        var option = me.getInitChartOption(view);
        var option = Ext.merge(reportLayout.chartOption, option);
        var chartDatas = me.getChartDatas(view);
        var option = Ext.merge(option, {
            dataset: {
                source: chartDatas,
            }
        });
        reportLayout.chartControl.setOption(option, true);
    },
    /**
    * 获取初始化图表配置（继承后须重写）
    * @method initChart
    */
    getInitChartOption: function (view) {
 
    },
    /**
    * 设置图表数据源
    * @method setChartDataSource
    */
    reloadChartDataSource: function (view) {
        var me = this;
        var chartControl = view.reportLayout.chartControl;
        if (chartControl) {
            chartControl.setOption({
                dataset: {
                    source: me.getChartDatas(view),
                }
            });
        }
    },
    /**
    * 获取图表数据（继承后须重写）
    * @method getChartDatas
    */
    getChartDatas: function (view) {
    },
});
 
使用示例如下：
（1）继承自通用查询命令，重写初始化图表配置方法，和获取图数据源方法。
返回数据时，返回List即可，不要返回EntityList因为框架对它的返回做了特殊处理


 
6、布局中为表格注册点击事件，点击后弹出新页面展示明细数据。

 
 

 

43. 经验总结
