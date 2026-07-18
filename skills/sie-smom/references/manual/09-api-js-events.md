# Api接口·JS事件·关闭前事件·GridPanel动态列

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch30-33
> **提取范围**：docx 正文行 6756-7128
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

30. Api接口说明
30.1 数据推送接口的定义
[表格 10 行]

30.2 框架Api的使用

说明：
api方法与普通方法的区别，api方法多了api标记的特性
ApiService：api开放接口标记
ApiReturn：api开放接口返回值
ApiParameter：api开放接口参数说明

方法标记了ApiService，在运行host或者是部署成服务后，可以在api中查到对应的方法、请求格式和返回值，其他系统也可访问调用对应服务的api方法。






查看写好的api接口：查看api，以本地调试为例，在SIE.WebApiHost中将写api方法的工程引用进来。

将配置文件配置好，启用SIE.WebApiHost

启动成功后，在浏览器输入：http://localhost:5102/api/dataportal，其中localhost:5102为启动服务的IP和端口。





30.3 API接口方法调试
1. 将ApiRequest的内容拷贝到“Api使用说明”的“请求”中，如下：

2. 输入用户名和密码获取票据，更改参数，如下：

3. 点击POST请求

4. 可以进到后台api方法中，进行api方法的调试

30.4 接口的调用

30.3.1  C#调用接口

30.3.2  PDA使用vue调用框架api

31. JS事件Events的使用（自定义事件的使用）
31.1. 说明
事件在使用前要先订阅，使用的时候再激活，使用完成后再注销
31.2. 事件的订阅：mon
this.view.mon(this.view, this.view.entityCopyAfterEventName, function() { this.executeCopy();} , { single: true });
 
其中：
This    作用域不同，this的取值也会不一样
this.view.mon   在视图view中订阅了一个事件
this.view.entityCopyAfterEventName   事件的名称
function() { this.executeCopy();}  事件执行的方法
single: true   表示该事件只订阅一次
31.3. 激活事件：fireEvent
this.fireEvent(this.entityCopyAfterEventName, this);
其中：
This在这里是view
this.entityCopyAfterEventName   事件的名称
这里激活事件之后，就会去执行订阅事件的方法
31.4. 注销事件：mun
this.mun(this, this.entityCopyAfterEventName);
其中：
This在这里是view
this.entityCopyAfterEventName   事件的名称
事件注销后，整个事件的生命周期就结束了，如果还要再次使用事件还需再次订阅
 
注意：事件使用完后一定要记得把事件注销掉，不然事件会一直挂着，影响性能，如果重复订阅事件又没有注销掉，事件就会越来越多，会存在重复执行一个事件的情况

32. 关闭前事件处理
32.1. 框架实现逻辑
32.1.1. 关闭前事件的处理
由原来绑定在控件的方式改成了绑定在view
框架关闭事件的处理：
Ext.define('SIE.control.TabPanel', {  
    extend: 'Ext.tab.Panel',  
    xtype: 'sietabpanel',  
    alias: ['widget.sietabpanel'],  
    remove: function(component, autoDestroy) {  
        var me = this,  
            args = arguments,  
            view = null,  
            c = me.getComponent(component);  
  
        // After destroying, items is nulled so we can't proceed   
        if (me.destroyed || me.destroying) {  
            return;  
        }  
  
        c = me.getComponent(component);  
        me.setActiveItem(component);  
  
        //<debug>   
        if (!arguments.length) {  
            Ext.log.warn(  
                "Ext.container.Container: remove takes an argument of the component to remove. cmp.remove() is incorrect usage.");  
        }  
        //</debug>   
  
        if (component.down() && component.down().down() && component.down().down().view) {  
            view = component.down().down().view;  
        } else if (component.view) {  
            view = component.view;  
        } else {  
            me.doRemove(component, true);  
            return;  
        }  
  
        var returnObj = view.closeView();  
        if (returnObj.hasData) {  
            Ext.MessageBox.confirm("提示",  
                "数据还未保存，是否继续退出？",  
                function(btn) {  
                    if (btn == "yes") {  
                        if (returnObj.data && returnObj.data.reject) //用于数据不保存时，撤销在表单的修改  
                            returnObj.data.reject();  
                        me.closeTab(me, c, autoDestroy, view, view.getControl(), returnObj.data);  
                    }  
                });  
            return;  
        }  
        me.closeTab(me, c, autoDestroy, view, view.getControl(), returnObj.data);  
    },  
  
    closeTab: function(me, c, autoDestroy, view, control, data) {  
        if (view && view.mun) {  
            view.mun(view, 'beforeclosewin');  
            if (data) {  
                view.mun(data, 'propertyChanged');  
            }  
        }  
  
        me.doRemove(c, autoDestroy);  
  
        if (me.hasListeners.remove) {  
            me.fireEvent('remove', me, c);  
        }  
  
        if (!me.destroying && !me.destroyAfterRemoving && !c.floating) {  
            me.updateLayout();  
        }  
  
        if (me.destroyAfterRemoving) {  
            me.destroy();  
        }  
    }  
});  
 
 
调用View的方法
/** 
     * 关闭页签前的数据处理 
     * 客制化页面关闭需要自己重写事件，data为具体的操作数据（如listview的data为this.getControl().getStore()，detailView的data为this.getCurrent()，this为当前操作的view）；hasData为是否为脏数据(为脏设置为true) 
     * 关闭的验证data可以不处理，只处理hasData（是否为脏数据） 
     */  
    closeView:function() {  
        var returnObj = {  
            data: null,  
            hasData: null  
        };  
        if (!this.hasListeners['beforeclosewin']) {  
            this.mon(this, 'beforeClosewin', this.beforeClosewin);  
        }  
        this.fireEvent('beforeClosewin', returnObj);  
        return returnObj;  
    },  
    /** 
     * 关闭tab前要实现的数据验证 
     * @param {} returnObj  
     * @returns {}  
     */  
    beforeClosewin:function(returnObj) {  
        return null;  
    },  
 
32.1.2. 框架表格关闭方法的实现
beforeClosewin: function(returnObj) {  
        var data = this.getData();  
        if (data) {  
            var changeData = SIE.data.Serializer.serialize(data, true);  
            if (changeData._data) {  
                var hasData = false;  
                for (var pro in changeData._data) {  
                    hasData = true;  
                    break;  
                }  
                returnObj.data = data;  
                returnObj.hasData = hasData;  
            }  
        }  
        return returnObj;  
    }  
 
32.1.3. 框架表单关闭方法的实现
beforeClosewin: function(returnObj) {  
        var data = this.getData();  
        if (data) {  
            var changeData = SIE.data.Serializer.serialize(data, true);  
            if (changeData._data) {  
                var hasData = false;  
                for (var pro in changeData._data) {  
                    if (pro == "_isEntityHost") continue;  
                    hasData = true;  
                    break;  
                }  
                returnObj.data = data;  
                returnObj.hasData = hasData;  
            }  
        }  
        return returnObj;  
    } 
 
32.1.4. 产品调用关闭前事件的处理
• 通过post方式自己添加的tab需要将view传过去，如下：

• 自己通过addtab添加的需要把view传到控件上

32.1.5. 在产品关闭前要重写关闭前方法实现
• 需要重写的地方挂事件
me._editingView.mon(me._editingView, 'beforeClosewin', this.beforeClosewin);
 
• 重写事件对应的方法处理自己的业务
beforeClosewin: function (returnObj) {  
        //关闭时解绑事件  
        var viewQuality = this.getChildren()[0];//定性  
        if (viewQuality.getData()) {  
            viewQuality.mun(viewQuality.getData(), 'load');  
        }  
        var viewQuantity = this.getChildren()[1];//定量  
        if (viewQuantity.getData()) {  
            viewQuantity.mun(viewQuantity.getData(), 'load');  
        }  
        var data = this.getCurrent();  
        returnObj.data = data;  
        returnObj.hasData = data.dirty;  
    }  

32.1.6. 关闭tab标签撤销数据的修改
• 在关闭tab时提示是不是未保存数据是否直接退出时回调数据处理（如果不保存，要把界面修改的内容撤销掉）

• 注册事件（这里的事件对应的方法可以在自己的功能重写）

32.1.7. 表格数据撤销的方法实现

32.1.8. 表单数据撤销的方法实现

 
/** 
* 数据不保存时，撤销在表单的修改方法重写，extjs的reject只能撤销主表的，从表不能撤销 
* @returns {}  
*/  
rejects:function() {  
    var data = this;  
    if (data) {  
        if (data.isModel) {  
           data.reject();  
           var loadedChildrens = data.getEntityChildren();  
           for (var i = 0, len = loadedChildrens.length; i < len; i++) {  
               var children = loadedChildrens.getAt(i);  
                if (children.isStore) {  
                   children.rejectChanges();  
                }  
               else if (children.isModel) {  
                   children.rejects();  
                }  
            }  
       }  
    }  
}  

32.2. 关闭前事件的使用示例

关闭前事件的事件名称：beforeClosewin，在行为的onViewReady方法中通过view.mon(view, ‘beforeClosewin’, this.beforeClosewin);进行注册，注册完成后实现beforeClosewin方法。
如：读者分类中，界面存在修改的数据，也不提示“数据还未保存，是否继续退出”，直接关闭界面的实现示例：

1. 添加行为js文件，在onViewReady中注册关闭前事件，实现关闭前方法beforeClosewin；
Ext.define('SIE.Web.XyTest.Scripts.ReaderCatListBehavior',
    {
        onViewReady: function (view) {
            view.mon(view, 'beforeClosewin', this.beforeClosewin);  //关闭页签前事件注册
        },
        /**
        * @override 重写关闭前方法
        * @param {} returnObj 输出参数，如果有事件需要解除绑定，例如propertyChanged，则赋值data;如果需要提示是否未保存，则赋值hasData
        * @returns {}
        */
        beforeClosewin: function (returnObj) {
            var view = this;
            var data = view.getCurrent();
            returnObj.data = data;
            returnObj.hasData = false;
        },
    });

2. 在界面使用行为，就可看到效果。

33. GridPanel动态列使用
33.1. 动态添加列
SIE.defineCommand('SIE.Web.Common.Prints.Commands.AddDynamicColumn', {  
    meta: { text: "添加列", group: "edit", iconCls: "iconfont icon-PrintData icon-blue" },  
    canExecute: function (view) {  
        return true;  
    },  
    execute: function (view, source) {  
        var me = this;  
        var gridPanel = view.getControl();//获取GridPanel对象  
        //调用gridPanel.addColumn（field,columnConfig)  
        gridPanel.addColumn({ name: 'alive', type: 'boolean', defaultValue: true, convert: null }, { header: '动态列', dataIndex: 'alive' });    
    },  
});  
 
• Field参数配置可以参考Ext.data.Model.fields属性的配置方式 
• columnConfg 参数可以考Ext.grid.Panel.config.column属性的配置


在实际开发过程中，动态列不会通过点击按钮进行添加，而是在行为中根据某些条件来创建动态列，使用行为添加动态列示例代码如下：
1. 在行为的onViewReady中进行实现，添加行为的js文件，嵌入到资源，重写onViewReady方法。

2. 动态列方法的实现，如addDynamicIsScrapColumn方法的实现
addDynamicIsScrapColumn: function (view, columnText, dataIndex) {
            var gridPanel = view.getControl();
            var columns = gridPanel.columns;
            // 查找是否在馆所在列的索引，每次添加的是否报废列插入是否在馆后面
            var position = columns.length - 5;
            var text = columnText.t(); //动态列列名
            var name = dataIndex; //字段名
            var field = {
                name: name, value: null, defaultValue: 1, convert: null
            };
            var column = {
                text: text, header: text, dataIndex: name, sortable: false, width: 100, xtype: "comboboxcolumn",
                editor: {
                    xtype: 'xcombobox', width: "80%", valueField: "value", queryMode: "local", ischeckbox: false, editable: false, allowBlank: true, readOnlyCls: "ux-form-readonly", revertInvalid: false,
                    store: {
                        fields: ['text', 'value'], pageSize: 0, remoteSort: false,
                        data: [{ text: "", value: null }, { text: "是", value: 0 }, { text: "否", value: 1 }]
                    }
                },
            };
            gridPanel.addColumn(field, column, position);
        },

3. 在对应界面的视图配置中使用行为。
33.2. 动态删除列
SIE.defineCommand('SIE.Web.Common.Prints.Commands.DeleteDynamicColumn', {  
    meta: { text: "删除列", group: "edit", iconCls: "iconfont icon-PrintData icon-blue" },  
    canExecute: function (view) {  
        return true;  
    },  
    execute: function (view, source) {  
        var me = this;  
        var gridPanel = view.getControl();  
        var colIndex = gridPanel.view.lastFocused.colIdx;  
        var colName = gridPanel.view.lastFocused.column.dataIndex;  
        gridPanel.removeColumn(colIndex-1);//用索引的方式删除  
        //gridPanel.removeColumn(colName);//用字段的方式删除  
  
    },  
});  
 
• 删除列可以使用单元格列索引的方式删除，也可以使用字段名称删除
• 删除列会把表格中数据行对应的列值也会删除。
• Data数据对应的字段也会删除。
• 由于GridPanel框架中增加了行号列，所以拿到列索引要减1
• 获取Header对象，header对象含用列的索引和绑定的字段信息，可以方便获取表格动态列的数据
• 根据索引获取
header = gridPanel.columnManager.getHeaderAtIndex(索引值);  
根据字段获取
Header = gridPanel.columnManager.getHeaderByDataIndex('字段名')   


