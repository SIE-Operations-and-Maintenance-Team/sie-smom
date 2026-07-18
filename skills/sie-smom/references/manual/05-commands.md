# 命令(增删改查·保存·选择·启停·复制新增·导入导出·合并拆分·上传)

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch14
> **提取范围**：docx 正文行 1780-4148
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

14. 命令
  14.1. 通用说明
• 自定义命令必须要放在Commands文件夹下才会执行；

注意： 与命令无关的js文件不能放到Commands文件夹下，否则会出现界面空白的情况。
• 重写的命令必须要写meta，且meta不能换行；

说明：
text：命令的名称设置；
group：为命令的分类，值包括edit和business；
iconCls：命令图标和图标颜色的设置；
hierarchy：命令的分组设置；
tooltip：命令的详细信息展示。
异常说明：

重写的命令添加的meta不能换行，meta必须在一行上完成

 

 
如果不写meta或者是meta换行，会导致角色编辑权限中命令名称为空

原因是：不好确定会换多少行，不好在正则表达式中做处理

• 如果只需要处理前端的业务，只需要添加js文件即可，且js文件要嵌入到资源；

说明：虽然在处理前端命令时，我们可以不用添加后端CS命令文件，但是在开发过程中通常会加一个空的CS命令文件，目的是方便查找代码及程序编码的规范。
注意： 保存命令和表单的删除命令，不管有没有处理后台逻辑，都必须有后台CS的命令文件。
• 前端js命令的使用：View.UseCommands("SIE.Web.Demo.Items.Commands.ItemCategoryCommand");其中SIE.Web.Demo.Items.Commands.ItemCategoryCommand为js命令文件的全命名空间；


• 如果命令有后台业务逻辑处理，则需要与JS文件名称相同的CS文件；

注意：这里的相同，是指命令的js和cs文件的命名空间和名称都必须一致，如下：


• BS有后端cs的命令文件，使用命令后面要加FullName，使用实例：View.UseCommands(typeof(CS命令文件的类名).FullName)

• 命令的图标可以在图标库中查找；


• 图标名前面要加icon-对应的图标名称；图标名用的是矢量图库，按钮不指定图标的颜色就是默认黑白色的颜色，指定了颜色会根据指定的颜色加上皮肤的颜色去叠加；
• 命令的多语言可以不加，框架统一处理了，其它的多语言需要自己手动加，前端的多语言使用.t()；
• 读取命令的名称


• 定义命令的名称空间，不能包含空格

• 命令的分组：通过meta中的hierarchy属性进行分组

• 命令启用防抖模式：executeIntervalMode: SIE.cmd.IntervalMode.Debounce.value；
• 在前端js命令使用时，会使用this.callParent(arguments)，继承该方法对应的父类的所有逻辑。


  14.2. 命令基类
    14.2.1. 添加/修改命令基类源码
[OLE: Package]
    14.2.2. 导入命令基类
      14.2.2.1. JS的基类
[OLE: Package]
[OLE: Package]
SIE.defineCommand('SIE.Web.Common.Import.Commands.ImportCommand', {  
    meta: { text: "导入Excel", group: "business", iconCls: "icon-ImportData icon-blue" },  
    myview: {}, // 当前视图对象  
    BehaviorName:"Download",  
    /** 
     * 是否可以执行 
     * @param {*} view 
     * @returns 总是可以执行， 
     * 子类可以根据具体情况覆写 
     */  
    canExecute: function (view) {  
        return true;  
    },  
  
    _progressBar: null,  
    _pageSize:25,  
  
    /** 
     *执行方法 
     * 
     * @param {*} listView 
     * @param {*} source 
     */  
    execute: function (listView, source) {  
        myview = listView; //保存当前视图对象  
        var me = this;  
        //初始化下载模板类型  
        me._downloadTemplateType();  
        var _importWindow = me.creatImportWindow(myview);  
        _importWindow.show();   
    },  
     /** 
     * 创建导入面板--打开窗体 
         * @param {*} myview 
    * @returns ， 
     */  
    creatImportWindow: function (myview) {  
        var me = this;  
        //创建一个表单面板  
        var form = me.creatImportFormPanel(myview);  
         //创建一个网格列表面板  
        var grid = me.creatImportGridPanel();  
  
        me._progressBar = new Ext.ProgressBar({  
            renderTo: Ext.getBody(),  
            width: 585,  
        });  
  
        //点击弹出框  
        var win = Ext.create("Ext.window.Window", {  
            title: "导入Excel", //标题  
            draggable: false,  
            height: 565, //高度  
            width: 700, //宽度  
            modal: true, //是否模态窗口，默认为false  
            resizable: false,  
            items: [form, grid, me._progressBar],  
            autoScroll: true,  
        });  
        me._progressBar.hide();  
        return win;  
    },  
     /** 
     * 创建导入面板--表单 
     * @param {*} myview 
     * @returns ，form 
     * 子类可以根据具体情况覆写，创建不同的面板 
     */  
    creatImportFormPanel: function (myview)  
    {  
        var me = this;  
        var form = new Ext.form.FormPanel({  
            bodyStyle: 'padding:5px 5px 0',  
            frame: true,  
            border: true,   
            items: [{  
                xtype: 'button',  
                id: 'templatebutton',  
                iconCls: 'iconfont icon-Download',  
                text: '下载模板',  
                handler: function () {  
                    myview.execute({  
                        data: {  
                            BehaviorName: me.BehaviorName,  
                            Type: myview.model  
                        },  
                        success: function (res) {  
                            var fileName = res.Result.FileName;  
                            var dataURI = res.Result.FileContent;  
  
                            //获取blob文件数据  
                            var blob = base64ToBlob(dataURI);  
                            if (window.navigator.msSaveOrOpenBlob) {  
                                navigator.msSaveBlob(blob, fileName);  
                            } else {  
                                var link = document.createElement('a');  
                                link.href = window.URL.createObjectURL(blob);  
                                link.download = fileName;  
                                link.click();  
                                window.URL.revokeObjectURL(link.href);  
                            }  
                        }  
                    })  
                }  
            }, {  
                xtype: 'filefield',  
                id: 'filefield',  
                name: 'fileUpload',  
                fieldLabel: '请选择导入文件',  
                reference: 'basicFile',  
                anchor: '100%',  
                buttonText: '...',  
                listeners: {  
                    change: function (field, newValue) {  
                        var fileExt = newValue.substring(newValue.lastIndexOf(".")).toLowerCase();  
                        if (fileExt != '.xlsx' && fileExt != '.xls') {  
                            Ext.Msg.alert('提示', '非xls,xlsx格式文件不支持导入');  
                            return;  
                        }  
                        //获取文件对象  
                        var file = field.fileInputEl.dom.files.item(0);  
                        var fileReader = new FileReader('file://' + newValue);  
                        fileReader.readAsDataURL(file);  
                        fileReader.onload = function (e) {  
                            //SIE.Msg.wait('数据正在导入中，请稍候...');  
                            me._progressBar.show();  
                            me._progressBar.wait({  
                                        interval: 100,  
                                        duration: 36000000,  
                                        text: '数据正在导入中，请稍候...',  
                                        increment: 10,  
                                        scope: this,  
                                        fn: function () {  
                                             
                                        }  
                                    });  
                            var parent = myview.getParent() != null && myview.getParent().getCurrent() != null ? myview.getParent().getCurrent().data : null;  
                            myview.execute({  
                                data: {  
                                    BehaviorName: 'ImportData',  
                                    Type: myview.model,  
                                    SelectedParent: parent != null ? Ext.encode(parent) : null,  
                                    SelectedParentId: parent != null ? parent.Id : 0,  
                                    Data: e.target.result,  
                                    ViewGroup: myview.viewGroup  
                                },  
                                success: function (res) {  
                                    //导入模板成功后处理数据  
                                    me._importExcelCallback(res,myview);  
                                    //SIE.Msg.hide();  
                                    me._progressBar.hide();  
                                    SIE.Msg.showMessage(res.Result.ImportMsg);  
                                }  
                            });  
                         }  
                    },  
                    render: function () {  
                        Ext.fly(this.el).on('click', function (e, t) {  
                            //重置防止选择同一个文件  
                            t.value = '';  
                        });  
                    }     
                }  
            }, {  
                xtype: 'textfield',  
                id: 'msgtextfield',  
                fieldLabel: '导入处理的消息',  
                readOnly: true,  
                anchor: '100%'  
            }]  
        });  
        return form;  
    },  
     /** 
     * 创建导入面板--Grid 
     * @returns  grid 
     */  
    creatImportGridPanel: function ()  
    {  
        var me=this;  
        //动态Jsonstore格式  
        var jsonText = '{\"total\":\"0\",\"data\":[{\"index\":\"\"}],\"columnModle\":[{\"text\":\"No\",\"dataIndex\":\"index\"}],\"fieldsNames\":[{\"name\":\"index\"}]}';  
        var json = Ext.util.JSON.decode(jsonText);  
        //创建strore对象  
        var store = new Ext.data.Store({  
            proxy: new Ext.data.MemoryProxy(null),  
            fields: json.fieldsNames,  
            data: json.data,  
            totalProperty: json.total,  
            pageSize: 25  
        });  
  
        //创建动态JsonStore表格  
        var importColumns = json.columnModle;  
        var bbar = new Ext.PagingToolbar({  
            id: 'failedtoolbar',  
            xtype: 'pagingtoolbar',  
            store: store,//数据  
            displayInfo: true,//是否显示数据信息  
            displayMsg: '显示{0}-{1}条记录,共{2}条',//只有displayInfo:true时才有效，用来显示有数据的提示信息。  
            emptyMsg: "没有记录",//没有数据显示的信息,  
            items:[  
                {  
                    xtype: 'combobox',  
                    itemId: 'pageSizeItem',  
                    store: Ext.create('Ext.data.Store', {  
                        fields: ['value'],  
                        data: [  
                            { "value": 25 },  
                            { "value": 50 },  
                            { "value": 100 },  
                            { "value": 1000 },  
                            { "value": 5000 },  
                        ]  
                    }),  
                    listeners: {  
                        change:function (clt, newValue, oldValue, eOpts) {  
                             var arrtydata = [];  
                             var toolbar= Ext.getCmp('failedtoolbar');  
                            toolbar.store.setPageSize(newValue);  
                             var pageData=toolbar.getPageData();  
                            for (var i = pageData.fromRecord-1; i < pageData.toRecord-1; i++) {  
                                arrtydata.push(toolbar.store.data.items[i]);  
                            }  
                            Ext.getCmp('failedGrid').store.setData(arrtydata);  
                        }  
                    },  
                    value:me._pageSize,  
                    width: 72,  
                    minValue:0,  
                    maxValue:5000,  
                    queryMode: 'local',  
                    displayField: 'value',  
                    valueField: 'value',  
                }  
            ],  
            listeners: {  
                change: {  
                    fn: function (clt, newValue, oldValue, eOpts) {  
                        var arrtydata = [];  
                        for (var i = this.getPageData().fromRecord-1; i < this.getPageData().toRecord-1; i++) {  
                            arrtydata.push(this.store.data.items[i]);  
                        }  
                        Ext.getCmp('failedGrid').store.setData(arrtydata);  
                    }  
                }  
            }  
        });  
          
        var grid = Ext.create("Ext.grid.Panel", {  
            id: 'failedGrid',  
            name: 'failedGrid',  
            title: '导入失败数据',  
            xtype: 'grid-filtering', //类型为锁定表格  
            height: 400, //高度   
            columns: importColumns,  
            bodyStyle: 'overflow-x:hidden; overflow-y:hidden',  
            store: store,  
            tbar:[{  
                    xtype: 'button',  
                    id: 'Importbutton',  
                    text: '导出Excel',  
                    handler:  
                    function(){  
                        var grid = Ext.getCmp('failedGrid');  
                        if(grid.store.config.totalProperty==='0')  
                        {  
                            SIE.Msg.showMessage('没有出错数据！');  
                            return;  
                        }  
                            //var me =this;  
                            var fieldNames = [];  
                            grid.getStore().config.fields.forEach(  
                                 function(item){  
                                    var fieldName = {};  
                                    fieldName.key=item.name;  
                                    fieldName.header=item.name==='_Index'?'失败行号':item.name;  
                                    fieldNames.push(fieldName);  
                            });  
                            var recordData = [];  
                                  
                                Ext.each(grid.getStore().getRange(), function (record) {  
                                    recordData.push(record.data);  
                                });  
                                 var exportJsonData = [];  
                                recordData.forEach(function (row) {  
                                var fieldData = '';  
                                fieldNames.forEach(function (fieldName) {  
                                    var exportValue = row[fieldName.key];  
                                    fieldData += '\"' + fieldName.key + '\":\"' + ( exportValue===null?'':exportValue) + '\",';  
                                });  
                                var fieldDataStr='{' + fieldData.substr(0, fieldData.length - 1) + '}';  
                                exportJsonData.push(JSON.parse(fieldDataStr.replace(/\n/g,"\\n").replace(/\r/g,"\\r")));  
                                });  
                                  
                                var exportJsonHeaders = [];  
                                fieldNames.forEach(function (value) {  
                                    exportJsonHeaders.push(value.header==='_MessageTip'?'失败原因':value.header)  
                                });  
                                me.jSONToExcelConvertor(exportJsonData, myview.label + Ext.util.Format.date(new Date(), 'Ymdhis'), exportJsonHeaders);  
                    },  
                }],  
            bbar: bbar,  
        });  
        return grid;  
    },  
      
      /** 
     * 初始化下载模板类型 
     * BehaviorName=‘Download’：下载默认类型模板，BehaviorName=“DownloadCustom”下载自定义列模板 
     * @returns  grid 
     */  
    _downloadTemplateType: function () {  
          
    },  
     /** 
     * 导入模板后回调函数--importExcelCallback 
     * @returns  grid 
     * 默认设置导入结果，如果导入数据成功，刷新视图，否则展示未导入成功数据 
     * 子类可以根据具体情况覆写，自行处理导入后的结果处理 
     */  
    _importExcelCallback: function (res,view) {  
        var me = this;  
        //设置导入结果  
        Ext.getCmp('msgtextfield').setValue(res.Result.ImportMsg);  
        if (res.Result.FailedJson.length > 0) {  
            var failedJson = Ext.util.JSON.decode(res.Result.FailedJson);  
            var arrtydata = [];  
            var num = failedJson.data.length > 10 ? 10 : failedJson.data.length;  
            for (var i = 0; i < num; i++) {  
                arrtydata.push(failedJson.data[i]);  
            }  
            var failedStore = new Ext.data.Store({  
                proxy: new Ext.data.MemoryProxy(failedJson.data),  
                fields: failedJson.fieldsNames,  
                totalProperty: "total",  
                data: failedJson.data,  
                pageSize: me._pageSize  
            });  
            var store = new Ext.data.Store({  
                proxy: new Ext.data.MemoryProxy(arrtydata),  
                fields: failedJson.fieldsNames,  
                totalProperty: "total",  
                data: arrtydata  
            });  
            Ext.getCmp('failedtoolbar').setStore(failedStore);  
            Ext.getCmp('failedGrid').reconfigure(store, failedJson.columnModle);  
        }  
        else {  
            var jsonText = '{\"total\":\"0\",\"data\":[{\"index\":\"\"}],\"columnModle\":[{\"text\":\"No\",\"dataIndex\":\"index\"}],\"fieldsNames\":[{\"name\":\"index\"}]}';  
            var json = Ext.util.JSON.decode(jsonText);  
            //创建strore对象  
            var store = new Ext.data.Store({  
                proxy: new Ext.data.MemoryProxy(null),  
                fields: json.fieldsNames,  
                data: json.data,  
                totalProperty: json.total,  
                pageSize: me._pageSize  
            });  
            Ext.getCmp('failedtoolbar').setStore(store);  
            Ext.getCmp('failedGrid').reconfigure(store, json.columnModle);  
        }  
        if (res.Result.ImportSuccessNum && res.Result.ImportSuccessNum > 0) {  
            me._importSuccess(view);  
        }  
    } ,  
     /** 
     * 导入数据成功--刷新窗体 
     * @param   {*} view 列表视图 
     * @returns  *  grid 
     * 默认执行成功后，刷新当前视图 
     * 子类可以根据具体情况覆写1.自行处理指定刷新子列表，2.父列表或者所有tab子视图列表 3.调用自定义命令 
     * 如果是视图使用了客制化查询命令，必须重写此方法，然后重新执行客制化命令中的方法 
     * 示例：view._relations[0]._target.getCommands().items[0].方法名; 
     */  
    _importSuccess: function (view) {  
        view.reloadData();  
    },  
      
    /** 
    * Json转Excel 
    * @param {*} JSONData Json数据 
         * @param {*} FileName 导出的文件名称 
         * @param {*} worksheet 表头名 
         */  
         jSONToExcelConvertor:function(JSONData, FileName, ShowLabel, worksheetName) {  
            //先转化json  
            var arrData = typeof JSONData != 'object' ? JSON.parse(JSONData) : JSONData;  
            //组装表格内容  
            var tableContent = '';  
            //设置表头  
            var row = "<tr>";  
            for (var i = 0, l = ShowLabel.length; i < l; i++)  
                row += "<td bgcolor='#00868B'><font size='3' color='white'><b>" + ShowLabel[i] + '</b></font></td>';  
            //换行  
            tableContent += row + "</tr>";  
            //设置数据  
            for (var i = 0; i < arrData.length; i++) {  
                var row = "<tr>";  
                for (var key in arrData[i]) {  
                    var value = arrData[i][key] == null ? "" : arrData[i][key];  
  
                    row += '<td style=\'mso-number-format:\"\@\"\'>' + value + '</td>';  
                }  
                tableContent += row + "</tr>";  
            }  
  
            //转换网页内容为data协议  
            var dataType = 'application/vnd.ms-excel';  
            var uri = 'data:' + dataType + ';base64, ',  
              template = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">'  
              + '<head><meta charset=\'UTF-8\'><!--[if gte mso 9]>'  
              + '<xml>'  
              + '<x:ExcelWorkbook>'  
              + '<x:ExcelWorksheets><x:ExcelWorksheet>'  
              + '<x:Name>{worksheet}'  
              + '</x:Name>'  
              + '<x:WorksheetOptions>'  
              + '<x:DisplayGridlines/>'  
              + '</x:WorksheetOptions>'  
              + '</x:ExcelWorksheet>'  
              + '</x:ExcelWorksheets>'  
              + '</x:ExcelWorkbook>'  
              + '</xml><![endif]-->'  
              + '</head>'  
              + '<body><table>{table}</table></body></html>',  
                base64 = function (s) { return window.btoa(unescape(encodeURIComponent(s))) },  
                format = function (s, c) {  
                    return s.replace(/{(\w+)}/g,  
                    function (m, p) {  
                        return c[p];  
                    })  
                }  
            //模板的占位替换  
            var ctx = {  
                worksheet: worksheetName || 'Worksheet', table: tableContent  
            };  
            FileName = FileName ? FileName + '.xls' : 'excel_data.xls';  
            //兼容IE,Edge  
            if (navigator.msSaveOrOpenBlob) {  
                uri = 'data:' + dataType + ';charset=utf-8, ';  
                var data = uri + format(template, ctx);  
                var blob = new Blob(['\ufeff', data], {  
                    type: dataType  
                });  
                navigator.msSaveOrOpenBlob(blob, FileName);  
            } else {  
                var data = uri + base64(format(template, ctx));  
                var link = document.createElement("a");  
                link.style = "visibility:hidden";  
                link.href = data;  
                link.download = FileName;  
                document.body.appendChild(link);  
                link.click();  
                document.body.removeChild(link);  
            }  
    },  
});   
 
      14.2.2.2. CS的基类
[OLE: Package]
/// <summary>  
/// 导入命令  
/// </summary>  
[JsCommand("SIE.Web.Common.Import.Commands.ImportCommandBase")]  
public abstract class ImportCommandBase : ViewCommand<ImportViewArgs>  
{  
    /// <summary>  
    /// 导入数据  
    /// </summary>  
    /// <param name="importViewArgs">导入视图参数</param>  
    /// <param name="scope">使用范围</param>  
    /// <returns>执行结果</returns>  
    protected override object Excute(ImportViewArgs importViewArgs, string scope)  
    {  
        //获取实体数据  
        var meta = ClientEntities.Find(importViewArgs.Type);  
        if (scope != meta.EntityType.GetQualifiedName())  
            throw new System.Security.SecurityException("参数type[{0}]与令牌不一致".FormatArgs(importViewArgs.Type));  
  
        ImportHandle importHandle = new ImportHandle();  
        switch (importViewArgs.BehaviorName)  
        {  
            case "Download":  
                return importHandle.DownloadTemplate(meta, GetImportTempleData());  
            case "DownloadCustom":  
                return importHandle.DownloadCustomTemplate(meta, GetImportHandleType(), GetImportTempleData());  
            default:  
                return ImportData(importViewArgs);  
        }  
    }  
  
    /// <summary>  
    /// 导入处理逻辑  
    /// </summary>  
    /// <param name="args">视图参数</param>  
    /// <param name="sheetName">excel工作薄sheet的名称</param>  
    /// <param name="isFirstRowColumn">第一行是否是DataTable的列名</param>  
    /// <returns>导入结果信息</returns>  
    protected virtual object ImportData(ImportViewArgs args, string sheetName = "", bool isFirstRowColumn = true)  
    {  
        //base64字节转换成Datatable  
        SpreadsheetHelper spreadsheet = new SpreadsheetHelper();  
        var dataTable = spreadsheet.Base64ToDataTable(args.Data, sheetName, isFirstRowColumn);  
        //处理导入逻辑  
        ImportDataHandleExt importDataHandle = new ImportDataHandleExt(args.SelectedParentId);  
        //导入数据  
        var resultMsg = importDataHandle.ImportProcess(dataTable, GetImportHandleType(), GetImportCompleted());  
        return new  
        {  
            ImportSuccessNum = importDataHandle.DrSuccess?.Length,  
            ImportMsg = importDataHandle.DrSuccess == null && importDataHandle.DrFailed == null ? resultMsg :  
                    ("导入成功数据【{0}】条，失败数据【{1}】条。".FormatArgs(importDataHandle.DrSuccess.Length, importDataHandle.DrFailed.Length)),  
            FailedJson = GetFailedJsonStore(args.SelectedParentId, importDataHandle.DrFailed)  
        };  
    }  
  
    /// <summary>  
    /// 获取失败信息Json  
    /// </summary>  
    /// <param name="selectedParentId">选择父Id</param>  
    /// <param name="dataRows">失败数据行</param>  
    /// <returns>Jsonstrore</returns>  
    protected virtual string GetFailedJsonStore(double selectedParentId, System.Data.DataRow[] dataRows)  
    {  
        if (dataRows == null || dataRows.Length == 0) return string.Empty;  
  
        //调整行号  
        dataRows.ForEach(p => p[ImportDataHandle.RowIndex] = int.Parse(p[ImportDataHandle.RowIndex].ToString()) + 2);//从1开始，第一行为标题，因此+2  
        //获取表对象  
        var dataTable = dataRows[0].Table.Clone();  
        //获取行内容  
        dataRows.ForEach(p => dataTable.Rows.Add(p.ItemArray));  
        //移除父Id  
        if (selectedParentId > 0)  
            dataTable.Columns.Remove(ImportDataHandle.ParentId);  
        //调整列名顺序  
        dataTable.Columns[ImportDataHandle.MessageColumnName].SetOrdinal(0);  
        dataTable.Columns[ImportDataHandle.RowIndex].SetOrdinal(0);  
        var dataJson = JsonConvert.SerializeObject(dataTable);  
        //获取列名称  
        var columns = dataTable.Columns.Cast<DataColumn>();  
        var columnModleJsonCombine = "{{\"text\":\"{0}\",\"dataIndex\":\"{1}\"}}";  
        var columnModleJson = string.Join(",", columns.Select(p =>  
        {  
            if (p.ColumnName == ImportDataHandle.MessageColumnName)  
                return columnModleJsonCombine.FormatArgs("失败原因".L10N(), ImportDataHandle.MessageColumnName);  
            if (p.ColumnName == ImportDataHandle.RowIndex)  
                return columnModleJsonCombine.FormatArgs("失败行号".L10N(), ImportDataHandle.RowIndex);  
            return columnModleJsonCombine.FormatArgs(p.ColumnName.L10N(), p.ColumnName);  
        }).ToArray());  
  
        //获取字段名称Json  
        var fieldsNamesJson = string.Join(",", columns.Select(p => "{{\"name\":\"{0}\"}}".FormatArgs(p.ColumnName)).ToArray());  
  
        //Json表格  
        string storeJson = "{{\"data\":{0},\"columnModle\":[{1}],\"fieldsNames\":[{2}]}}".FormatArgs(dataJson, columnModleJson, fieldsNamesJson);  
        return storeJson;  
    }  
  
    /// <summary>  
    /// 获取导入类型  
    /// </summary>  
    /// <returns></returns>  
    protected abstract Type GetImportHandleType();  
  
    /// <summary>  
    /// 获取导入完成处理逻辑  
    /// </summary>  
    /// <returns></returns>  
    protected abstract ImportCompleted GetImportCompleted();  
  
    /// <summary>  
    /// 获取示例数据  
    /// </summary>  
    /// <returns></returns>  
    protected virtual List<string> GetImportTempleData() { return new List<string>(); }  
  
}  
 
 

  14.3. 添加命令
    14.3.1. 框架源码
注意：框架命令源码仅供参考

[OLE: Package]
    14.3.2. 提供可重写的方法
      14.3.2.1. canExecute(view)
重写此方法可以自定义命令可执行的条件。
      14.3.2.2. createNewItem()
创建新实体，提供扩展。
      14.3.2.3. onItemCreated(entity)
新实体创建后，提供扩展。
      14.3.2.4. getEditEntity()
获取实体（创建新实体，创建完毕后返回该实体）。
    14.3.3. 自定义行内添加命令示例（前后端有数据交互）
添加命令继承SIE.cmd.Add
前端代码：
SIE.defineCommand('SIE.Web.Items.ProductBoms.Commands.ProductBomAddCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加", group: "edit" },
    onItemCreated: function (entity) {
        var model = entity.data;
        var me = this;
        this.view.execute({
            data: model,
            success: function (res) {
                var version = res.Result;
                entity.setVersion(version);
            }
        }, me.view);
    }
});

后台代码：
namespace SIE.Web.Items.ProductBoms.Commands
{
    /// <summary>
    /// 添加
    /// </summary>
    public class ProductBomAddCommand : ViewCommand
    {
        /// <summary>
        /// 执行
        /// </summary>
        /// <param name="args">args</param>
        /// <param name="scope">scope</param>
        /// <returns>执行结果</returns>
        protected override object Excute(ViewArgs args, string scope)
        {
            ProductBom bom = args.Data.ToJsonObject<ProductBom>();
            var config = ConfigService.GetConfig(new ProductBomVersionConfig(), typeof(ProductBom));
            if (config.Version != null)
            {
                bom.Version = RT.Service.Resolve<NumberRuleController>().GenerateSegment(config.Version, 1).FirstOrDefault();
            }
            return bom.Version;
        }
    }
}

    14.3.4. 自定义表单添加命令示例（前后端有数据交互）
前端代码：
SIE.defineCommand('SIE.Web.Demo.Items.Commands.AddUnitCommand', {
    extend: 'SIE.cmd.Add',
    meta: { text: "添加", group: "edit" },
    showView: function (entity) {
        if (entity) {
            var model = entity.data;
            var me = this;
            this.view.execute({
                data: model,
                success: function (res) {
                    var code = res.Result;
                    CRT.Workbench.addPage({
                        entityType: me.view.model,
                        recordId: entity.getId(),
                        title: me.getEditViewTitle(entity),
                        params: {
                            Code: code
                        },
                        isDetail: true,
                    });
                }
            }, me.view);
        }
    },
});
后台代码：
namespace SIE.Web.Demo.Items.Commands
{
    public class AddUnitCommand : ViewCommand
    {
        protected override object Excute(ViewArgs args, string scope)
        {
            var unitData = args.Data.ToJsonObject<Unit>();
            unitData.Code = RT.Service.Resolve<ItemController>().GetUintCode();
            return unitData.Code;
        }
    }
}

 

  14.4. 修改命令
    14.4.1. 框架源码
注意：框架命令源码仅供参考
[OLE: Package]
 
 
    14.4.2. 自定义弹框命令示例
SIE.defineCommand('SIE.Web.PO.PurchaseOrders.Commands.EditPurchaseOrderDetailCommand', {
    extend: 'SIE.cmd.Edit',
    meta: { text: "修改", group: "edit", iconCls: "icon-EditEntity icon-blue" },
    canExecute: function (view) {
        if (view.getSelection() == null || view.getSelection().length != 1) {
            return false;
        }
        var entity = view.getCurrent();
        var po = view.getParent().getCurrent();
        if (po != null && po.data.State !== SIE.PO.PurchaseOrders.State.Saved.value) return false;
        return entity != null;
    },
    showView: function (entity) {
        var me = this;
        var meta = null;
        SIE.AutoUI.getMeta({
            model: me.view.model,
            viewGroup: "AddPurchaseOrderViewGroup",
            isDetail: true,
            ignoreQuery: true,
            callback: function (res) {
                meta = res;
                var cfg = {
                    associateCmd: me,
                    viewMeta: meta,
                    entity: entity,
                    editMode: me.view.editMode,
                    title: me.getEditViewTitle(entity),
                };
            }
        });
    },
});


public class EditPurchaseOrderDetailCommand : ViewCommand
    {
        /// <summary>
        /// 修改命令
        /// </summary>
        /// <param name="args">args</param>
        /// <param name="scope">scope</param>
        /// <returns>true</returns>
        protected override object Excute(ViewArgs args, string scope)
        {
            return true;
        }
}

    14.4.3. 自定义tab页签命令示例
SIE.defineCommand('SIE.Web.PO.PurchaseOrders.Commands.EditPurchaseOrdersCommand', {
    extend: 'SIE.cmd.Edit',
    meta: { text: "修改", group: "edit", iconCls: "icon-EditEntity icon-blue" },
    canExecute: function (view) {
        if (view.getSelection() == null || view.getSelection().length != 1) {
            return false;
        }
        var entity = view.getCurrent();
        if (entity != null && entity.data.State !== SIE.PO.PurchaseOrders.State.Saved.value) return false;
        return entity != null;
    },
    showView: function (entity) {
        var me = this;
        var meta = null;
        CRT.Workbench.addPage({
            entityType: this.view.model,
            recordId: entity.getId(),
            title: this.getEditViewTitle(entity),
            viewGroup: "AddPurchaseOrderViewGroup",
            isDetail: true
        });
    },
});

    public class EditPurchaseOrdersCommand : ViewCommand
    {
        /// <summary>
        /// 修改命令
        /// </summary>
        /// <param name="args">args</param>
        /// <param name="scope">scope</param>
        /// <returns>true</returns>
        protected override object Excute(ViewArgs args, string scope)
        {
            return true;
        }
    }

  

  14.5. 删除命令
    14.5.1. 框架源码
注意：框架命令源码仅供参考
[OLE: Package]
    14.5.2.  自定义删除命令

 
SIE.defineCommand('SIE.Web.Resources.CalendarSchemes.Commands.CalendarSchemeDeleteCommand', {
    extend: 'SIE.cmd.Delete',
    meta: { text: "删除", group: "edit" },

    canExecute: function (view) {
        var result = this.callParent(arguments);
        if (result === false) {
            return false;
        }
        if (view.getSelection().length > 0) {
            var flag = true;
            Ext.each(view.getSelection(), function (item) {
                if (item.getIsDefault() === 1) {
                    flag = false;
                }
            });
            return flag;
        }
        return false;
    }
});
  14.6. 查询命令
    14.6.1. 框架源码
注意：框架命令源码仅供参考
[OLE: Package]
    14.6.2. 自定义查询命令
/** 
 * 排班表查询命令 
 */  
SIE.defineCommand('SIE.Web.MES.TeamManagement.ShiftSchedules.ScheduleQuery', {  
    meta: { text: "查询", iconCls: "icon-Search icon-blue" },  
  
    /** 
     * @property ListLogicView 
     * 查询逻辑视图 
     */  
    view: null,  
  
    /** 
     * @property {Boolean} 
     * 是否允许查询，反正恶意查询  
     */  
    allow: true,  
  
    /** 
     * 判断查询方法能否执行 
     * @param view 查询逻辑视图 
     * @returns 能执行返回true，否则返回false 
     */  
    canExecute: function (view) {  
        var current = view.getCurrent();  
        return this.allow && current != null;  
    },  
  
    /** 
     * 执行查询方法  
     * @param view 查询逻辑视图 
     */  
    execute: function (view) {  
        var me = this;  
        try {  
            me.allow = false;  
            me.view = view;  
            var record = view.getCurrent();  
            delete record.data['CriteriaModuleKey'];  
            delete record.data['CriteriaType'];  
            delete record.data["CriteriaString"];  
            var istrue = true;  
            me.view.getControl().items.items.forEach(function (item) {  
                if (!item.validate()) {  
                    istrue = false;  
                }  
            });  
            var criteria = record.data;  
            if (!me.validateCriteria(criteria)) {  
                me.allow = true;  
                return;  
            }  
            criteria.ScheduleDate.startDate = criteria.ScheduleDate.BeginValue;  
            criteria.ScheduleDate.endDate = criteria.ScheduleDate.EndValue;  
            SIE.invokeDataQuery({  
                method: 'GetShiftScheduleTables',  
                params: [criteria],  
                action: 'queryer',  
                type: 'SIE.Web.MES.TeamManagement.ShiftSchedules.ShiftScheduleDataQueryer',  
                token: me.view.getToken(),  
                success: function (res) {  
                    var layout = me.view.mainLayout;  
                    if (!layout)  
                        return;  
                    var scheduleDate = me.view.getCurrent().data.ScheduleDate;  
                    layout.setGridPanelData(res.Result, scheduleDate.BeginValue, scheduleDate.EndValue);  
                    me.allow = true;  
                }  
            });  
        } catch (e) {  
            me.allow = true;  
            throw e;  
        }  
    },  
  
    /** 
     * 验证查询条件  
     * @param criteria 查询实体ShiftScheduleTableCriteria 
     * @returns 通过返回true，否则返回false 
     */  
    validateCriteria: function (criteria) {  
        if (criteria == null)  
            return false;  
        if (criteria.ScheduleDate.BeginValue == null || criteria.ScheduleDate.EndValue == null) {  
            SIE.Msg.showMessage('开始日期不能为空');  
            return false;  
        }  
        if (criteria.ScheduleDate.BeginValue > criteria.ScheduleDate.EndValue)  
            return false;  
        return true;  
    }  
});  
 
 
    14.6.3. 后台查询方法
/// <summary>  
/// 排班数据查询器  
/// </summary>    
[AllowAnonymous]  
public class ShiftScheduleDataQueryer : DataQueryer  
{  
    /// <summary>  
    /// 获取排班表信息  
    /// SIE.Web.MES.TeamManagement.ShiftSchedules.ScheduleQuery.js 调用  
    /// </summary>  
    /// <param name="criteria">班组排班表查询实体</param>   
    /// <returns>排班表信息列表</returns>   
    public List<ShiftScheduleInfo> GetShiftScheduleTables(ShiftScheduleTableCriteria criteria)  
    {  
        return RT.Service.Resolve<ShiftScheduleController>().GetShiftScheduleTables(criteria);  
} 
 
• 前端使用命令：
View.ReplaceCommands(WebCommandNames.ExecuteQuery,"SIE.Web.MES.TeamManagement.ShiftSchedules.ScheduleQuery");
 
• 说明：使用了后台查询方法的，查询实体类的查询方法就不要去实现，如上在查询按钮的执行方法中去调用了后台的查询方法，查询实体类的查询方法就返回了一个空的集合

 
 
• 如下查询命令走的是查询实体的查询方法
SIE.defineCommand('SIE.Web.WMS.Statistics.Common.Commands.WmsStatisticsQueryCommand', {  
    meta: { text: "查询", iconCls: "icon-Search icon-blue" },  
    /** 
     * @property {Boolean} 
     * 是否允许查询，反正恶意查询  
     */  
    allow: true,  
  
    /** 
     * @property {Boolean} 
     * 是否已经注册数据加载完成事件 
     */  
    register: false,  
    canExecute: function (view, source) {  
        var current = view.getCurrent();  
        return this.allow && current != null;  
    },  
  
    /** 
     * 判断查询方法能否执行 
     * @param view 查询逻辑视图 
     * @returns 能执行返回true，否则返回false 
     */  
    execute: function (view) {  
        var me = this;  
        try {  
            me.allow = false;  
            var record = view.getCurrent();  
            delete record.data['CriteriaModuleKey'];  
            delete record.data['CriteriaType'];  
            delete record.data["CriteriaString"];  
            var istrue = true;  
            view.getControl().items.items.forEach(function (item) {  
                if (!item.validate()) {  
                    istrue = false;  
                }  
            });  
            var mainView = view.getResultView();  
            if (mainView) {  
                var layout = me.view.mainLayout;  
                if (layout) {  
                    layout.loadReportData(record.data, mainView.token);  
                    me.allow = true;  
                }  
            }  
        } catch (e) {  
            me.allow = true;  
            throw e;  
        }  
    }  
});  
 

 

  14.7. 保存命令
    14.7.1. 框架源码
注意：框架命令源码仅供参考
[OLE: Package]
[OLE: Package]
    14.7.2. 自定义表格保存命令
14.7.2.1. 后台有数据处理，前端未传数据
步骤：
1.定义js文件（js文件嵌入到资源），继承SIE.cmd.Save，添加meta属性，没有特殊业务处理，不需要重写方法，如下所示：
SIE.defineCommand('SIE.Web.Resources.ProcessTechs.Commands.ProcessTechSaveCommand', {
    extend: 'SIE.cmd.Save',
    meta: { text: "保存", group: "edit", iconCls: "icon-SaveEntity icon-blue" },
});

2.定义后台cs文件，名字和命名空间和js声明的一致，继承SaveCommand,然后根据具体的业务需求重写对应的方法，如下示例重写了DoSave方法（可重写的方法有：Excute、DoSave、OnSaving、OnSaved）：
namespace SIE.Web.Resources.ProcessTechs.Commands
{
    /// <summary>
    /// 制程工艺保存命令
    /// </summary>
    public class ProcessTechSaveCommand : SaveCommand
    {
        protected override void DoSave(EntityList data)
        {
            foreach (ProcessTech item in data)
            {
                if (item.IsScheduling)
                {
                    item.OffsetTime = null;
                }
                else
                {
                    item.TransferTime = null;
                }
            }
            base.DoSave(data);
        }
    }
}

3.在界面使用命令
View.ReplaceCommands(WebCommandNames.Save, typeof(ProcessTechSaveCommand).FullName);
14.7.2.2. 前后端有交互
前后端有数据交互，前端通过view.execute传递数据到后端

后端继承ViewCommand<ViewArgs>或者ViewCommand

    14.7.3. 自定义表单保存命令
      14.7.3.1. 后台有业务逻辑处理，前端未传参数
新建命令的JS文件，嵌入到资源，继承SIE.cmd.FormSave
SIE.defineCommand('SIE.Web.Resources.Employees.Commands.EmployeeSaveCommand', {
    extend: 'SIE.cmd.FormSave',
    meta: { text: "保存", group: "edit", iconCls: "icon-SaveEntity icon-blue" },
    onSaved: function (view, res) {
        this.callParent(arguments);
        var me = this;
        var control = me.view.getControl().query('[name=Code]')[0];
        control["setReadOnly"](true);
    }
});

新建命令的cs文件 ，继承FormSaveCommand
namespace SIE.Web.Resources.Employees.Commands
{
    public class EmployeeSaveCommand : FormSaveCommand
    {
        protected override void DoSave(Entity entity)
        {
            Employee data = entity as Employee;
            RT.Service.Resolve<EmployeeController>().SaveEditedEmployee(data);
        }
    }
}
表单后台可重写的方法：Excute、DoSave、OnSaving、OnSaved、OnValidation

      14.7.3.2. 前后端有数据交互
前后端有数据交互，前端通过view.execute传递数据到后端

后端继承ViewCommand<ViewArgs>或者ViewCommand，重写Excute方法

 


    14.7.4. 保存命令连续点击报错的问题
• 版本保存按钮连续点击会报错问题，增加了点完一次保存后按钮变灰
• 继承了框架的保存命令，就会有连续保存变灰的效果
• 没有继承框架的保存命令，需要自己手动加如下代码

 

  14.8. 选择命令
14.8.1. 选择命令继承基类
[OLE: Package]

14.8.2. 自定义选择命令的实现
• 新建JS文件，右键属性，生成操作选择嵌套为资源

      14.8.2.1. JS文件的实现
SIE.defineCommand('SIE.Web.Rbac.Roles.Commands.AddUserCommand', {  
    extend: 'SIE.cmd.LookupCommandBase',  
    meta: { text: "添加用户", group: "edit", iconCls: "icon-PlaylistCheck icon-blue" },  
    userConfig: {  
        dataParams: { specKeyPrototyName: 'UserId', targetClassName: 'SIE.Rbac.Users.User' },  
    },  
    save: function (win) {  
        /// <summary>  
        /// 保存选择的操作列表。  
        /// </summary>  
        var me = this;  
        /* post数据结构*/  
        var indata = {};  
        /* post数据结构*/  
        var selections = this._targetSelectItems.items;  
        if (selections && selections.length > 0) {  
            var userInRoles = [];  
            SIE.each(selections, function (item) {  
                var userId = item.getId();  
                if (me._sourceViewSelectItems.indexOf(userId) === -1) {  
                    var userInRole = { RoleId: me._sourceId, UserId: userId };  
                    userInRoles.push(userInRole);  
                }  
            });  
            indata = userInRoles;  
            me._targetView.execute({  
                data: indata,  
                success: function (res) {  
                    win.close();  //关闭模态窗口  
                    me._ownerView.loadChildData(true); //重载视图数据  
                }  
            }, me._ownerView);  
        }  
        else {  
            SIE.Msg.showWarning('没有可提交的数据');  
        }  
    }  
  
});  

      14.8.2.2. CS文件的实现
 
/// <summary>  
/// 添加用户命令  
/// </summary>  
[JsCommand("SIE.Web.Rbac.Roles.Commands.AddUserCommand")]  
public class AddUserCommand : ViewCommand  
{  
    protected override object Excute(ViewArgs args, string scope)  
    {  
        var meta = ClientEntities.Find(args.Type);  
        var savedData = RF.Find(meta.EntityType).NewList();  
        var userInRoleList = args.Data.ToJsonObject<List<UserInRole>>();  
        Check.NotNullOrEmpty(userInRoleList, nameof(userInRoleList));  
        if (null == userInRoleList || userInRoleList.Count == 0)  
        {  
            throw new ArgumentNullException("{0}数据参数不能为空".FormatArgs(nameof(userInRoleList)));  
        }  
        foreach (var item in userInRoleList)  
        {  
            var userInRole = new UserInRole();  
            userInRole.UserId = item.UserId;  
            userInRole.RoleId = item.RoleId;  
            savedData.Add(userInRole);  
        }  
        RF.Save(savedData);  
        return true;  
    }  
}  
      14.8.2.3. 在ViewConfig中使用命令
View.UseCommands(typeof(AddUserCommand).FullName)
 


14.8.3. 选择命令注意事项
1.选择对话切换分页选中的问题

 
• 上图这种选择添加命令的实现需要注意的时，获取选择的数据不要使用this._targetView.getSelection();
 
• 使用这种写法，会造成在选择第一页的数据再切换到第二页选择数据，再回到第一页，点击确定会报“没有可提交数据的异常”
 

 

• 应该使用this._targetSelectItems.items;获取选择的数据

2. 弹框选择命令的实体如果不是按实体名+Criteria进行命名的，需要在userConfig中配置查询实体名，否则会报找不到查询实体名的js异常，配置如下：


  14.9. 启用禁用命令的使用
    14.9.1. 状态属性添加
实体中需要添加一个状态属性，名称必须时State
#region 状态 State  
/// <summary>  
/// 状态  
/// </summary>  
[Label("状态")]  
public static readonly Property<SIE.Domain.State> StateProperty = P<SupplierAddress>.Register(e => e.State);  
  
/// <summary>  
/// 状态  
/// </summary>  
public SIE.Domain.State State  
{  
    get { return GetProperty(StateProperty); }  
    set { SetProperty(StateProperty, value); }  
}  
#endregion  
 
    14.9.2. 实现接口:IStateEntity
在实体中实现接口:IStateEntity

 
    14.9.3. 效果


  14.10. 查询命令
    14.10.1. 框架源码
注意：框架命令源码仅供参考
[OLE: Package]
说明：查询命令只有一个execute方法，因为在重写查询命令时，可不需要去继承查询命令，如下自定义查询命令的使用。
    14.10.2. 自定义查询命令
14.10.2.1. 自定义前端js文件
/** 
 * 排班表查询命令 
 */  
SIE.defineCommand('SIE.Web.MES.TeamManagement.ShiftSchedules.ScheduleQuery', {  
    meta: { text: "查询", iconCls: "icon-Search icon-blue" },  
  
    /** 
     * @property ListLogicView 
     * 查询逻辑视图 
     */  
    view: null,  
  
    /** 
     * @property {Boolean} 
     * 是否允许查询，反正恶意查询  
     */  
    allow: true,  
  
    /** 
     * 判断查询方法能否执行 
     * @param view 查询逻辑视图 
     * @returns 能执行返回true，否则返回false 
     */  
    canExecute: function (view) {  
        var current = view.getCurrent();  
        return this.allow && current != null;  
    },  
  
    /** 
     * 执行查询方法  
     * @param view 查询逻辑视图 
     */  
    execute: function (view) {  
        var me = this;  
        try {  
            me.allow = false;  
            me.view = view;  
            var record = view.getCurrent();  
            delete record.data['CriteriaModuleKey'];  
            delete record.data['CriteriaType'];  
            delete record.data["CriteriaString"];  
            var istrue = true;  
            me.view.getControl().items.items.forEach(function (item) {  
                if (!item.validate()) {  
                    istrue = false;  
                }  
            });  
            var criteria = record.data;  
            if (!me.validateCriteria(criteria)) {  
                me.allow = true;  
                return;  
            }  
            criteria.ScheduleDate.startDate = criteria.ScheduleDate.BeginValue;  
            criteria.ScheduleDate.endDate = criteria.ScheduleDate.EndValue;  
            SIE.invokeDataQuery({  
                method: 'GetShiftScheduleTables',  
                params: [criteria],  
                action: 'queryer',  
                type: 'SIE.Web.MES.TeamManagement.ShiftSchedules.ShiftScheduleDataQueryer',  
                token: me.view.getToken(),  
                success: function (res) {  
                    var layout = me.view.mainLayout;  
                    if (!layout)  
                        return;  
                    var scheduleDate = me.view.getCurrent().data.ScheduleDate;  
                    layout.setGridPanelData(res.Result, scheduleDate.BeginValue, scheduleDate.EndValue);  
                    me.allow = true;  
                }  
            });  
        } catch (e) {  
            me.allow = true;  
            throw e;  
        }  
    },  
  
    /** 
     * 验证查询条件  
     * @param criteria 查询实体ShiftScheduleTableCriteria 
     * @returns 通过返回true，否则返回false 
     */  
    validateCriteria: function (criteria) {  
        if (criteria == null)  
            return false;  
        if (criteria.ScheduleDate.BeginValue == null || criteria.ScheduleDate.EndValue == null) {  
            SIE.Msg.showMessage('开始日期不能为空');  
            return false;  
        }  
        if (criteria.ScheduleDate.BeginValue > criteria.ScheduleDate.EndValue)  
            return false;  
        return true;  
    }  
});  
 
 
14.10.2.2. 后台查询方法
/// <summary>  
/// 排班数据查询器  
/// </summary>    
[AllowAnonymous]  
public class ShiftScheduleDataQueryer : DataQueryer  
{  
    /// <summary>  
    /// 获取排班表信息  
    /// SIE.Web.MES.TeamManagement.ShiftSchedules.ScheduleQuery.js 调用  
    /// </summary>  
    /// <param name="criteria">班组排班表查询实体</param>   
    /// <returns>排班表信息列表</returns>   
    public List<ShiftScheduleInfo> GetShiftScheduleTables(ShiftScheduleTableCriteria criteria)  
    {  
        return RT.Service.Resolve<ShiftScheduleController>().GetShiftScheduleTables(criteria);  
} 
 
14.10.2.3. 前端使用命令
View.ReplaceCommands(WebCommandNames.ExecuteQuery,"SIE.Web.MES.TeamManagement.ShiftSchedules.ScheduleQuery");
 
14.10.2.4. 说明
• 1.使用了后台查询方法的，查询实体类的查询方法就不要去实现，如上在查询按钮的执行方法中去调用了后台的查询方法，查询实体类的查询方法就返回了一个空的集合。

 
 
• 2.	如下查询命令走的是查询实体的查询方法
SIE.defineCommand('SIE.Web.WMS.Statistics.Common.Commands.WmsStatisticsQueryCommand', {  
    meta: { text: "查询", iconCls: "icon-Search icon-blue" },  
    /** 
     * @property {Boolean} 
     * 是否允许查询，反正恶意查询  
     */  
    allow: true,  
  
    /** 
     * @property {Boolean} 
     * 是否已经注册数据加载完成事件 
     */  
    register: false,  
    canExecute: function (view, source) {  
        var current = view.getCurrent();  
        return this.allow && current != null;  
    },  
  
    /** 
     * 判断查询方法能否执行 
     * @param view 查询逻辑视图 
     * @returns 能执行返回true，否则返回false 
     */  
    execute: function (view) {  
        var me = this;  
        try {  
            me.allow = false;  
            var record = view.getCurrent();  
            delete record.data['CriteriaModuleKey'];  
            delete record.data['CriteriaType'];  
            delete record.data["CriteriaString"];  
            var istrue = true;  
            view.getControl().items.items.forEach(function (item) {  
                if (!item.validate()) {  
                    istrue = false;  
                }  
            });  
            var mainView = view.getResultView();  
            if (mainView) {  
                var layout = me.view.mainLayout;  
                if (layout) {  
                    layout.loadReportData(record.data, mainView.token);  
                    me.allow = true;  
                }  
            }  
        } catch (e) {  
            me.allow = true;  
            throw e;  
        }  
    }  
});  
 


  14.11. 复制新增命令的实现
14.11.1. 框架源码
注意：框架命令源码仅供参考
[OLE: Package]

说明：复制新增命令只支持主从表的复制
14.11.2. 框架实现逻辑
1.在view中定义事件，当所有子加载成功后去激活实体拷贝事件
         entityCopyAfterEventName: 'entityCopyAfter',  
    onEntityCopyReady: function() {  
        var isChildLoad = false;  
        if (this.hasListeners.entitycopyafter) {  
            isChildLoad = this.isLoadChildData();  
        }  
        if (isChildLoad) {  
            this.fireEvent(this.entityCopyAfterEventName, this);  
            this.mun(this, this.entityCopyAfterEventName);  
        }  
    },  
    isLoadChildData:function() {  
        var isChildLoad = true;  
        for (var i = 0; i < this._children.length; i++) {  
            var view = this._children[i];  
            if (view._children.length > 0)  
                view.isLoadChildData();  
            else {  
                if (view.getData() && !view.getData()._loaded)  
                    isChildLoad = false;  
                else if (view.getData() && view.getData().store && !view.getData().store.loaded)  
                    isChildLoad = false;  
            }  
            if (!isChildLoad)  
                break;  
        }  
        return isChildLoad;  
    },  
 
 
2.在加载子loadChildData方法中，子加载成功后通过父的view去调用onEntityCopyReady()方法

3.在copy命令的执行方法中去激活拷贝事件
//复制新增命令  
SIE.defineCommand('SIE.cmd.Copy', function() {  
    var _loadChildData = function(view) {  
        Ext.each(view._children,  
            function(childView) {  
                childView.loadChildData(true); //ajax load data  
                //目前只能复制主从，孙及下级的递归先注释掉  
                /*if (childView._children.length > 0) { 
                    _loadChildData(childView); 
                }*/  
            });  
    };  
  
    return {  
        extend: 'SIE.cmd.Add',  
        meta: { text: "复制新增", group: "edit", iconCls: "icon-AddEntity icon-green" },  
        isCopy: true,  
        canExecute: function(view) {  
            if (view.getSelection() == null || view.getSelection().length !== 1) {  
                return false;  
            }  
            return true;  
        },  
        execute: function (view, source) {  
            var me = this;  
            if (me.view._children.length > 1) {  
                me.view.mon(me.view, me.view.entityCopyAfterEventName, function() {  
                    me.executeCopy();  
                } , { single: true });  
                _loadChildData(me.view);  
            } else {  
                me.executeCopy();  
            }  
              
        },  
        getEditEntity: function() {  
            var view = this.view;  
            var c = view.getCurrent();  
            view.copyEntityData = view.copyEntity(c);  
            var copyEntity = view.copyEntityData;  
            this._setCopyEntity(copyEntity.data);  
            var editmode = view.editMode;  
            if (editmode === SIE.viewMeta.editMode.INLINE) {  
                view.getData().insert(0, copyEntity);  
            }  
            copyEntity.isCopy = true;  
            return view.copyEntityData;  
        },  
        executeCopy:function() {  
            var me = this;  
            var editEntity = me.getEditEntity();  
            me.onEditting(editEntity);  
            me.edit(editEntity);  
            me.onEdited(editEntity);  
        },  
        //复制新增不带出创建人创建时间更新人更新时间  
        _setCopyEntity: function(data) {  
            data.CreateBy = null;  
            data.CreateByName = null;  
            data.CreateBy_Display = null;  
            data.CreateDate = null;  
            data.UpdateBy = null;  
            data.UpdateByName = null;  
            data.UpdateBy_Display = null;  
            data.UpdateDate = null;  
        },  
    }  
});  
 
 
14.11.3. 复制新增的使用示例
SIE.defineCommand('SIE.Web.Portal.Receipt.Commands.AsnDetailCopyCommand', {
    extend: 'SIE.cmd.Copy',
    meta: { text: "复制新增", group: "edit", iconCls: "icon-ContentCopy icon-blue" },
    canExecute: function (view) {
        if (view.getSelection() == null || view.getSelection().length != 1) {
            return false;
        }
        var entity = view.getParent().getCurrent().data;
        if (entity != null) {
            if (entity.PrepareState == null || entity.PrepareState != 10 || entity.AsnSource != 1) return false;
        }
        return true;
    },
    _setCopyEntity: function (data) {
        this.callParent(arguments);
        data.LineNo = null;
        var ct = this.view.getParent().getChildren()[0].getData().data.length;
        data.LineNo = (ct + 1).toString();
        data.Lot = "Lot";
        data.LotAtt01 = null;
        data.LotAtt02 = null;
        data.LotAtt04 = null;
        data.LotAtt05 = null;
        data.LotAtt06 = null;
        data.LotAtt07 = null;
        data.LotAtt08 = null;
        data.LotAtt09 = null;
    }
});


  14.12. 导入命令的使用示例
14.12.1 实现一（使用框架导入命令）
1. 使用导入命令需要引用NPOI，否则下载模板会报错

2.  在ConfigListView中使用导入命令
View. UseImportCommands();
3. 配置下载模板


4. 实现效果

 
14.12.2 实现二（自定义命令方式实现）
1. 自定义一个js命令，嵌入到资源，继承自ImportCommandBase
SIE.defineCommand('SIE.Web.Demo.Items.Commands.UnitImportCommand', {
    extend: 'SIE.Web.Common.Import.Commands.ImportCommandBase',
    meta: { text: "导入Excel", group: "business", iconCls: "icon-Download icon-blue" },
}); 

2. 自定义一个CS命令文件，继承ImportCommandBase
namespace SIE.Web.Demo.Items.Commands
{
    public class UnitImportCommand : ImportCommandBase
    {
        protected override ImportCompleted GetImportCompleted()
        {
            return (DataRow[] drSuccess, DataRow[] drFailed) =>
            {
            };
        }
        protected override Type GetImportHandleType()
        {
            return typeof(UnitImportHandle);
        }
    }
}

UnitImportHandle的实现：
public class UnitImportHandle : IDisposable, IBusinessImport
    {
        /// <summary>
        /// 表头
        /// </summary>
        public List<string> ColumnNameList { get; set; } = new List<string>
        {
            "编码".L10N(),
            "名称".L10N(),
            "类型".L10N(),
            "单位精度".L10N(),
            "控件时间测试".L10N()
        };
        /// <summary>
        /// 列的标准验证 (列名 列对应验证 )
        /// </summary>
        public Dictionary<string, ValidColumn> ColumnValidList { get; set; }

        /// <summary>
        /// 创建表头并验证
        /// </summary>
        /// <returns>要导入的表头</returns>
        public IBusinessImport CreaetColumnValid()
        {
            this.ColumnValidList = new Dictionary<string, ValidColumn>
            {
                { "编码".L10N(), new ValidColumn(ImportDataType._String, true, CodeValidation, true) },
                { "名称".L10N(), new ValidColumn(ImportDataType._String, true, NameValidation, true) },
                { "类型".L10N(), new ValidColumn(ImportDataType._String, true,StateValidation ,true) },
                { "单位精度".L10N(), new ValidColumn(ImportDataType._String, false,true) },
                { "控件时间测试".L10N(), new ValidColumn(ImportDataType._String, false, 200) },
            };
            return this;
        }

        private bool StateValidation(object obj, out string MessageTip, DataRow dr)
        {
            MessageTip = string.Empty;
            var type = obj.ToString();
            if (type.IsNullOrEmpty())
            {
                MessageTip = "类型【{0}】不能为空".L10N().FormatArgs(type);
                return false;
            }
            return true;
        }

        /// <summary>
        /// 编码验证
        /// </summary>
        /// <param name="obj">验证列值</param>
        /// <param name="messageTip">验证消息提示</param>
        /// <param name="dr">验证行对象(DataRow)</param>
        /// <returns></returns>
        private bool CodeValidation(object obj, out string messageTip, DataRow dr)
        {
            messageTip = string.Empty;
            var code = obj.ToString();
            if (code.IsNullOrEmpty())
            {
                messageTip = "编码【{0}】不能为空".L10N().FormatArgs(code);
                return false;
            }
            return true;
        }

        private bool NameValidation(object obj, out string messageTip, DataRow dr)
        {
            var name = obj.ToString();
            if (name.IsNullOrEmpty())
            {
                messageTip = "名称【{0}】不能为空".L10N().FormatArgs(name);
                return false;
            }
            messageTip = string.Empty;
            return true;
        }

        public void Dispose()
        {
        }

        /// <summary>
        /// 导入业务数据处理
        /// </summary>
        /// <param name="drs"></param>
        public void ProcessBusinessDataHandle(DataRow[] drs)
        {
            drs.ForEach(p =>
            {
                try
                {
                    var unit = new Unit();
                    unit.Code = p["编码"].ToString();
                    unit.Name = p["名称"].ToString();
                    unit.Type = p["类型"].ToString();
                    unit.Precision = Convert.ToInt32(p["单位精度"].ToString());
                    unit.DateTimeTest = DateTime.Now;
                    RF.Save(unit);
                }
                catch (Exception ex)
                {
                    //设置失败信息到失败列，用于统计及显示
                    p[ImportDataHandle.MessageColumnName] = ex.Message;
                }
            });
        }
    }
3.  下载模板的配置

4. 在界面使用命令
View.UseCommands(typeof(UnitImportCommand).FullName);
5. 效果

14.13. 导出命令
    14.13.1. 说明
一般情况下，使用框架默认的导出命令即可
 
    14.13.2. 自定义导出按钮的实现
以生产通用报表的导出按钮为例：
14.13.2.1. JS文件实现
• 新增一个导出的JS文件，如下：
SIE.defineCommand('SIE.Web.MES.WIP.Products.ExportReportCommand', {  
    meta: { text: "导出", group: "edit", iconCls: "icon-ExportData icon-blue" },  
    _view: null,  
    selOption: null,  
    execute: function (view) {  
        _view = view;  
        var me = this;  
        var criter = view._relations[0]._target.getCurrent();  
        delete criter.data['CriteriaModuleKey'];  
        delete criter.data['CriteriaType'];  
        delete criter.data["CriteriaString"];  
        var token = view.getToken();  
        var store = me.initStore();  
        var win = Ext.create("Ext.window.Window", {  
            title: "导出选项", //标题              
            draggable: false,  
            bodyStyle: 'padding:10px 30px 10px 30px',  
            height: 200, //高度  
            width: 300, //宽度  
            modal: true, //是否模态窗口，默认为false  
            resizable: false,  
            labelWidth: 40,  
            closeAction: 'close',  
            autoDestroy: true,  
            items: [  
                {  
                    xtype: 'combobox',  
                    name: 'rangeCb',  
                    fieldLabel: '数据选项',  
                    labelStyle: 'width:80px;',  
                    valueField: "key",  
                    displayField: "value",  
                    store: store,  
                    listeners: {  
                        afterRender: function () {  
                            selOption = Ext.ComponentQuery.query('combobox[name=rangeCb]');  
                            selOption = selOption[selOption.length - 1];  
                            document.getElementById(selOption.id).children[0].children[0].style.width = 'auto';  
                        }  
                    }  
                }  
            ],  
            buttons: [{  
                text: '保存',  
                handler: function () {  
                    var rangeOption = selOption.getValue();  
                    var seleneity = _view.getSelection();  
                    var modellist = new Array();//导出选中行  
                    var pagesize = _view._pagingBar.store.pageSize;  
                    var currentpage = _view._pagingBar.store.currentPage;  
                    if (rangeOption == "1") {  
                        if (seleneity.length == 0) { SIE.Msg.showError("请选中至少一行再导出"); return; }  
                        for (var i = 0; i < seleneity.length; i++) {  
                            modellist.push(seleneity[i].data);  
                        }  
                    }  
  
                    SIE.invokeDataQuery({  
                        method: 'GetWipProductData',  
                        params: [rangeOption, modellist, pagesize, currentpage, criter.data],  
                        action: 'queryer',  
                        type: 'SIE.Web.MES.WIP.Products.WipProductDataQueryer',  
                        token: token,  
                        success: function (res) {  
                            var exportData = res.Result[0]['exportData'];  
                            var div = document.createElement("DIV");  
                            document.body.appendChild(div);  
                            div.innerHTML = exportData;  
                            div.style.display = "none";  
                            var l = div.children.length;  
                            var catearr = [];  
                            catearr.push("sheet1");  
                            var myDate = new Date();  
                            var datestr = (myDate.toLocaleDateString() + myDate.toLocaleTimeString('chinese', { hour12: false })).replace(/\//g, "").replace(/:/g, "");  
                            me.table2Excel(div, catearr, "生产通用报表" + datestr + ".xls", "Excel");  
                            document.body.removeChild(div);  
                            Ext.MessageBox.show({  
                                msg: '正在导出数据',  
                                progressText: '...',  
                                width: 300,  
                                wait: {  
                                    interval: 200  
                                }  
                            });  
                            me.timer = Ext.defer(function () {  
                                me.timer = null;  
                                Ext.MessageBox.hide();  
                                win.close();  
                                Ext.toast({  
                                    html: "导出成功",  
                                    closable: false,  
                                    align: 't',  
                                    slideInDuration: 400  
                                });  
                            }, 2000);  
                        }  
                    });  
                }  
            }, {  
                text: '取消',  
                handler: function () {  
                    win.close();  
                }  
            }],  
            autoScroll: true,  
            listeners: {  
                afterrender: function () {  
  
                },  
                beforeclose: function () {  
  
                }  
            }  
        });  
        win.show();  
    },  
    initStore: function () {  
        var optionDataStore = new Ext.data.SimpleStore({  
            fields: [  
                { name: 'key', mapping: 'key' },  
                { name: 'value', mapping: 'value' }  
            ],  
            data: [{ 'key': '0', 'value': '当前页' },  
            { 'key': '1', 'value': '选中行' },  
            { 'key': '2', 'value': '查询结果' }]  
        });  
        return optionDataStore;  
    },  
    table2Excel: function (tableid, wsnames, wbname, appname) {  
        var workbookXML = "";  
        var base64 = function (s) {  
            return window.btoa(unescape(encodeURIComponent(s)));  
        };  
        var excelFormat = function (s, c) {  
            return s.replace(/{(\w+)}/g,  
                function (m, p) {  
                    return c[p];  
                });  
        };  
        var uri = 'data:application/vnd.ms-excel;base64,';  
        var template = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel"' +  
            'xmlns="http://www.w3.org/TR/REC-html40"><head><!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>'  
            + '<x:Name>{worksheet}</x:Name><x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions></x:ExcelWorksheet></x:ExcelWorksheets>'  
            + '</x:ExcelWorkbook></xml><![endif]-->' +  
            ' <style type="text/css">' +  
            'table td {' +  
            'border: 1px solid #000000;' +  
            'width: 200px;' +  
            'height: 30px;' +  
            ' text-align: center;' +  
            ' }' +  
            '</style>' +  
            '</head><body ><table class="excelTable">{table}</table></body></html>';  
        if (!tableid.nodeType) tableid = document.getElementById(tableid);  
        var ctx = { worksheet: 'Worksheet', table: tableid.innerHTML };  
        workbookXML = excelFormat(template, ctx);  
        if (navigator.msSaveOrOpenBlob) {  
            uri = 'data:application/vnd.ms-excel;charset=utf-8,';  
            var data = uri + base64(workbookXML);  
            var blob = new Blob(['\ufeff', data], {  
                type: 'application/vnd.ms-excel'  
            });  
            navigator.msSaveOrOpenBlob(blob, wbname || 'Workbook.xls');  
        }  
        else {  
            var link = document.createElement("A");  
            link.href = uri + base64(workbookXML);  
            link.download = wbname || 'Workbook.xls';  
            link.target = '_blank';  
            document.body.appendChild(link);  
            link.click();  
            document.body.removeChild(link);  
        }  
    }  
});  
 
说明：如果导出命令中没有弹框对话框选择导出的数据，直接在执行方法中调用SIE.invokeDataQuery即可
 
14.13.2.2. 请求后台数据部分的处理
/// <summary>  
/// 获取导出的生产通用报表的数据  
/// </summary>  
/// <param name="rangeOption">查询选项</param>  
/// <param name="seleneity">选择行</param>  
/// <param name="pagesize">页面大小</param>  
/// <param name="currentpage">当前页</param>  
/// <param name="criteria">查询条件</param>  
/// <returns>生产通用报表的数据</returns>  
public List<EntityJson> GetWipProductData(int rangeOption, EntityList<WipProductVersion> seleneity, int pagesize, int currentpage, WipProductVersionCriteria criteria)  
{  
    List<EntityJson> res = new List<EntityJson>();  
    StringBuilder sb = new StringBuilder();  
    ////定义表头  
    string head = "<table>";  
    sb.Append(head);  
    if (rangeOption == (int)ExportOption.Current)  
    { //导出当前页  
        criteria.PagingInfo.PageSize = pagesize;  
        criteria.PagingInfo.PageNumber = currentpage;  
        EntityList<WipProductVersion> data = RT.Service.Resolve<WipProductVersionController>().GetWipProductVersions(criteria);  
        sb.Append(ExportAll(data));  
    }  
  
    if (rangeOption == (int)ExportOption.Selected && seleneity.Count > 0)  
    { //导出选中行  
        sb.Append(ExportAll(seleneity));  
    }  
  
    if (rangeOption == (int)ExportOption.All)  
    { //导出选中行  
        criteria.PagingInfo = null;  
        EntityList<WipProductVersion> data = RT.Service.Resolve<WipProductVersionController>().GetWipProductVersions(criteria);  
        sb.Append(ExportAll(data));  
    }  
  
    sb.Append("</table>");  
    EntityJson resNode = new EntityJson();  
    resNode.SetProperty("exportData", sb.ToString());  
    res.Add(resNode);  
    return res;  
}  
 
/// <summary>  
/// 生产通用报表导出选项  
/// </summary>  
public enum ExportOption  
{  
    /// <summary>  
    /// 当前页  
    /// </summary>  
    Current = 0,  
  
    /// <summary>  
    /// 选中行  
    /// </summary>  
    Selected = 1,  
  
    /// <summary>  
    /// 查询结果  
    /// </summary>  
    All = 2,  
}  
 
14.13.2.3. ExportAll方法的
/// <summary>  
/// 导出生产通用报表数据  
/// </summary>  
/// <param name="data">生产通用报表</param>  
/// <returns>生产通用报表数据</returns>  
public string ExportAll(EntityList<WipProductVersion> data)  
{  
    StringBuilder sb = new StringBuilder();  
    sb.Append("<tr style='background-color:#B3B3B3'><td>条码</td><td>是否hold</td><td>工单号</td><td>工单类型</td>"  
                  + "<td>工单数量</td><td>工艺流程名称</td><td>车间</td><td>产品型号</td><td>当前工序</td><td>当前工位资源</td>"  
                  + "<td>产品等级</td><td>是否已完工下线</td></tr>");  
    data.ForEach(p =>  
    {  
        sb.Append(string.Format("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td>"  
              + "<td>{4}</td><td>{5}</td><td>{6}</td><td>{7}</td><td>{8}</td><td>{9}</td>"  
              + "<td>{10}</td><td>{11}</td></tr>", p.Sn, p.IsHold, p.WorkOrderNo, p.WoType, p.WoPlanQty, p.VersionName, p.WorkShopName, p.Model, p.ProcessName, p.ResourceName, p.Grade, p.IsFinish));  
 
        #region 判断产品检验记录表是否有数据，有数据就导出  
        var testInfoList = p.InspectionItemList;  
        if (testInfoList.Any())  
        {  
            sb.Append(ExportTestData(testInfoList));  
        }  
        #endregion  
 
        #region 判断生产采集记录表是否有数据，有数据就导出  
        var processList = p.ProcessList;  
        if (processList.Any())  
        {  
            sb.Append(ExportProcessData(processList));  
        }  
        #endregion  
 
        #region 判断产品维修记录表是否有数据，有数据就导出  
        var repairList = p.RepaireList;  
        if (repairList.Any())  
        {  
            sb.Append(ExportRepairList(repairList));  
        }  
        #endregion  
 
        #region 判断产品缺陷记录表是否有数据，有数据就导出  
        var defectList = p.DefectList;  
        if (defectList.Any())  
        {  
            sb.Append(ExportDefectData(defectList));  
        }  
        #endregion  
    });  
    return sb.ToString();  
}
 
14.13.2.4. ExportTestData方法
/// <summary>  
/// 导出产品检验记录表  
/// </summary>  
/// <param name="data">产品检验记录表</param>  
/// <returns>产品检验记录</returns>  
public string ExportTestData(EntityList<WipProductInspectionItem> data)  
{  
    StringBuilder sb = new StringBuilder();  
    sb.Append("<tr style='background-color:#CE8CFB'><td>产品检验记录</td><td>项目编码</td><td>项目名称</td><td>规范上限</td>"  
                  + "<td>规范下限</td><td>测试值</td><td>检验结果</td><td>备注</td><td>检验人</td></tr>");  
    data.ForEach(p =>  
    {  
        sb.Append(string.Format("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td>"  
              + "<td>{4}</td><td>{5}</td><td>{6}</td><td>{7}</td><td>{8}</td></tr>", string.Empty, string.Empty, p.InspectionItem.Name, p.LimitMax == null ? string.Empty : p.LimitMax.ToString(), p.LimitLow == null ? string.Empty : p.LimitLow.ToString(),  
              p.InspectionValue == null ? string.Empty : p.InspectionValue.ToString(), p.Result, p.Remarks, p.InspectBy?.Name));  
    });  
    return sb.ToString();  
} 
 
• 在界面中使用命令
View.UseCommands("SIE.Web.MES.WIP.Products.ExportReportCommand");
• 界面效果
点击导出按钮，弹出导出选项界面

数据选项选择对应的项，点击保存，会导出对应的excel，excel的效果如下：

 


14.14. 合并行命令实现示例
在读者分类功能中做一个合并行的按钮，选择两条或以上未被合并过的数据，点击合并行，能够合并数据，效果如下：

实现步骤：
1. 在读者分类实体中增加“子单据列表”，关联自己；

2. 在读者分类实体中增加“主单据” 的引用属性，关联自己且设置为忽略外键；


3. 在读者分类实体中增加属性“是否合单”；

4. 在读者分类实体中增加属性“合单状态”

5. 在读者分类ViewConfig的配置列表视图中将“子单据列表”隐藏；

6. 添加行为，在行为的beforeCreate中创建一个子列表，将列头隐藏；

7. 添加行为，在行为的beforeCreate中创建一个子列表，将列头隐藏

8. 子列表选择事件对应方法的实现

9. 合并行行为的具体实现代码如下：
Ext.define('SIE.Web.LibMan.Behaviors.ReaderCatListBehavior',
    {
        /**
          * view生命周期函数--view生成前
          * @param {*} meta 实体视图元数据
          * @param {*} curEntity 当前操作实体(可空)
          */
        beforeCreate: function (meta, curEntity) {
            var configColumns = meta.gridConfig.columns;
            var childCols = Ext.clone(configColumns);
            var lastCol = configColumns[configColumns.length - 1];
            //调整主表格最后一列列宽，使得隐藏子视图的滚动条
            if (!lastCol.width)
                lastCol.width = 150;
            else
                lastCol.width += 20;
            meta.gridConfig.listeners = {
                columnresize: function (ct, column, width, eOpts) {
                    var childs = ct.ownerCt.query("gridpanel");
                    Ext.Array.forEach(childs, function (panel) {
                        for (var i in panel.columns) {
                            var c_column = panel.columns[i];
                            if (c_column.dataIndex == column.dataIndex) {
                                c_column.setWidth(width);
                                break;
                            }
                        }
                    });
                    Ext.Array.forEach(childCols, function (childCol) {
                        if (childCol.dataIndex == column.dataIndex) {
                            childCol.width = width;
                            return;
                        }
                    });
                }
            };
            meta.gridConfig.plugins = meta.gridConfig.plugins || [];//空值校验
            meta.gridConfig.plugins.push({
                ptype: "rowwidget",
                widget: {
                    xtype: 'gridpanel',
                    autoLoad: true,
                    bind: {
                        store: '{record.ReaderCatChildList}'
                    },
                    columns: childCols,
                    margin: "0 0 0 35",
                    //隐藏列表头
                    hideHeaders: true,
                    listeners: {
                        selectionchange: this.onChildSelectionChanged
                    }
                },
                getHeaderConfig: function () {
                    var defaultIconColumnCfg = this.superclass.getHeaderConfig.apply(this, arguments);
                    defaultIconColumnCfg.renderer = function (value, gridcell, record) {
                        //非合并单据不需要显示扩展图标
                        if (record.getMergeState() === 1) {
                            return '<div class="' + Ext.baseCSSPrefix + 'grid-row-expander" role="presentation" tabIndex="0"></div>';
                        }
                    };
                    return defaultIconColumnCfg;
                }
            });
        },
        /**
         * 选择嵌入的表格内数据
         */
        onChildSelectionChanged: function (row, selected, opts) {
            var mainView = this.up('grid').SIEView;
            mainView.selectedChildRecords = selected;
            if (selected && selected.length > 0)
                mainView.setCurrent(selected[0]._MasterBill);
            mainView.syncCmdState();
        },
    });
10. 合并行的前端命令实现

11. 合并行后端命令实现

12. 合并单据方法的实现

13. 框架的查询方法需要重写，这里要查询显示的数据为未合单的数据

14. 在界面使用命令和行为


14.15. 拆分行命令实现示例
拆分行是在合并行的基础上实现的，实体属性和行为的处理与合并行的一致，这里只说明拆分行的命令部分实现。
前端JS实现：
SIE.defineCommand('SIE.Web.LibMan.ReaderCats.Commands.CancelMergeReaderCatCommand', {
    meta: { text: "取消合并", group: "edit", iconCls: "icon-SaveEntity icon-blue" },
    canExecute: function (view) {
        var current = view.getCurrent();
        if (!current || (current.getMergeState() === 0))
            return false;
        else
            return true;
    },
    /**
    * @override 执行取消合并
    * */
    execute: function (view, source) {
        var me = this;
        var selections = view.selectedChildRecords || [];
        me.cancelMerge(view, selections);
    },
    /**
     * 取消合并方法*/
    cancelMerge: function (view, selections) {
        var entity = view.getCurrent();
        SIE.Msg.askQuestion('确定取消合并?'.t(),
            function () {
                var ids = [];
                var isChildBill = false;
                if (selections.length > 0 && selections.every(function (item) { return item.getMasterBillId() == entity.getId() })) {
                    //选择了子单
                    ids = selections.map(function (item) { return item.getId(); });
                    isChildBill = true;
                }
                else {
                    ids = [entity.getId()];      //选择主单
                    isChildBill = false;
                }
                view.execute({
                    data: {
                        ids: ids,
                        isChildBill: isChildBill
                    },
                    success: function (res) {
                        SIE.Msg.showInstantMessage("取消合并成功!".format(res.Result).t());
                        view.reloadData();
                    }
                });
            });
    }
});

后台CS实现：
using SIE.Domain;
using SIE.LibMan.ReaderCats;
using SIE.Web.Command;
using System;
using System.Collections.Generic;
using System.Text;

namespace SIE.Web.LibMan.ReaderCats.Commands
{
    public class CancelMergeReaderCatCommand : ViewCommand
    {
        protected override object Excute(ViewArgs args, string scope)
        {
            var arg = args.Data.ToJsonObject<CancelMergeArgInfo>();
            if (arg.ids.Count < 1)
                throw new InvalidOperationException("请选择需要取消合并的单据。");

            if (arg.isChildBill)
            {
                //取消合并子单据
                var childBill = RF.GetById<ReaderCat>(arg.ids[0]);
                if (childBill == null)
                    throw new ArgumentNullException();
                if (!childBill.IsMerge)
                    throw new InvalidOperationException("单据[{0}]不是已合并单据，不能取消合并。".L10nFormat(childBill.CatNo));
                RT.Service.Resolve<ReaderCatController>().CancelMergeMethod(childBill);
            }
            else
            {
                //取消合并主单据
                var current = RF.GetById<ReaderCat>(arg.ids[0]);
                if (current == null)
                    throw new ArgumentNullException();
                if (current.MergeState != MergeState.MergeBill)
                    throw new InvalidOperationException("单据[{0}]不是合并单据，不能取消合并。".L10nFormat(current.CatNo));
                RT.Service.Resolve<ReaderCatController>().CancelMergeMethod(new List<ReaderCat>() { current });
            }
            return true;
        }
    }

    /// <summary>
    /// 参数结构
    /// </summary>
    public struct CancelMergeArgInfo
    {
        /// <summary>
        /// id集合
        /// </summary>
        public List<double> ids { get; set; }
        /// <summary>
        /// 是否子单据
        /// </summary>
        public bool isChildBill { get; set; }
    }
}
拆单的实现逻辑：
/// <summary>
        /// 取消合并订单  针对选中的是子单据
        /// </summary>
        /// <param name="bill">读者分类</param>
        public virtual void CancelMergeMethod(ReaderCat bill)
        {
            using (var trans = DB.TransactionScope(LibManEntityDataProvider.ConnectionStringName))
            {
                var billId = bill.MasterBillId;
                var masterBill = RF.GetById<ReaderCat>(billId);
                bill.MergeState = MergeState.SplitBill;
                bill.IsMerge = false;
                bill.MasterBillId = null;
                RF.Save(bill);

                var childBills = GetChildBills(masterBill.Id);
                if (childBills.Count <= 1)
                {
                    childBills.ForEach(p => { p.MasterBillId = null; p.MergeState = MergeState.SplitBill; p.IsMerge = false; });
                    masterBill.PersistenceStatus = PersistenceStatus.Deleted;
                    RF.Save(childBills);
                }
                else
                {
                    //部分子单据取消合并后，刷新主单据的相关合计值
                    masterBill.CatName = string.Join(",", childBills.Where(p => p.CatName.IsNotEmpty()).Select(p => p.CatName).Distinct());
                    masterBill.Qty -= bill.Qty;
                    masterBill.Day -= bill.Day;
                }
                RF.Save(masterBill);

                trans.Complete();
            }
        }

        /// <summary>
        /// 取消合并订单 针对选中的是主单
        /// </summary>
        /// <param name="data">读者分离列表</param>
        public virtual void CancelMergeMethod(List<ReaderCat> data)
        {
            using (var trans = DB.TransactionScope(LibManEntityDataProvider.ConnectionStringName))
            {
                if (data.All(p => p.MasterBillId == null))
                {
                    foreach (var masterbill in data)
                    {
                        var childBills = GetChildBills(masterbill.Id);
                        childBills.ForEach(p => { p.MasterBillId = null; p.MergeState = MergeState.SplitBill; p.IsMerge = false; });
                        masterbill.PersistenceStatus = PersistenceStatus.Deleted;
                        RF.Save(childBills);
                        RF.Save(masterbill);
                    }
                }

                trans.Complete();
            }
        }

14.16. 上传命令
  14.16.1. 框架源码
注意：框架命令源码仅供参考
前端js文件：
[OLE: Package]

后台CS文件：
[OLE: Package]

14.17. 主界面命令弹出对话框实现示例


14.18. 添加修改保存数据后关闭当前tab
数据保存后，关闭当前tab：CRT.Workbench.closeCurrentTab(); 

