# 通用附件·编码规则·配置项·标签单据打印·实体扩展属性

> **来源**：SMOM v8.0+ BS 学习手册（SMOM交付部-技术部 v3.0，原始 .docx）
> **章节**：Ch20-26
> **提取范围**：docx 正文行 4969-6309
> **用途**：权威参考底库。编写 SMOM 代码前按主题查阅本文件，禁止凭记忆臆造框架 API；拿不准的方法/编辑器/命令先在此核对。

---

20. 通用附件
• 当某个功能的数据需要上传附件时，我们需要对该功能添加附件功能，附件功能作为该功能的子列表功能。因此，附件是功能数据的子数据，我们开发附件功能时，也是针对主数据进行的。

• 功能的附件提供上传、删除、下载功能

20.1. 基础开发步骤
• 进行附件实体定义、附件仓库配置、附件实体配置；
• 在主数据的实体中增加附件列表属性；
• 在对应用的视图配置中，增加附件功能显示配置。

20.1.1. 附件实体定义
• 功能附件实体，继承自Attachment<TOwner>，指定附件的拥有者类型（TOwner），
• 比如班级附件如下，拥有者为SchoolClass(班级)；
• 附件是针对功能的附件，所以功能数据是主实体，而附件是子实体，因此附件实体需使用标签ChildEntity，同时需使用序列化标签Serializable。

20.1.2. 附件仓库配置
• 附加仓库的命名规范必须是：附件的实体名(如ClassAttachment)+Repository
• 在定义附件实体后，要为其配置附件仓库，定义一个附件的仓库类，继承为AttachmentRepository<附件实体>；
• 需为附件仓库配置[DataProvider(typeof(实体功能的仓库EntityDataProvider)),框架才能自动识别；
• 附件的仓库类只需进行简单配置，类中不需要添加任何属性字段；
• 没有配置附件仓库，上传附件时只有数据，并没有真正上传成功，下载附件也会报错。

20.1.3. 附件实体配置
• 和普通实体一样，附件实体需要实体配置；
• 附件实体中需要配置鉴别器Meta.EnableDiscriminator("附件实体类名")。因为无论什么功能的附件，只要集成了Attachment<TOwner>，它们数据都保存在相同的一个数据表中。通过数据表的鉴别字段进行区分（为什么需要区分因为主数据的ID有可能存在一样，需要通过鉴别器区分出相同主数据ID的附件到底属于哪个功能）。


20.1.4. 主数据增加附件列表属性
• 需在主数据实体中增加附件列表属性，将附件数据作为主数据的子数据属性。
[OLE: Package]

20.1.5. 主数据视图配置
在主数据实体中对应的相关视图（ConfigListView或ConfigDetailsView）中通过View.ChildrenProperty(p => p.附件列表属性)方法，把附件界面添加到主数据界面中。

20.2. 客制化附件开发（进阶）
• 通过上面的基础开发步骤就已经满足一般的功能附件，如有需对功能的附件进行特殊的处理，则需要对附件功能进行客制化；
• 一般附件客制化是对附件功能的按钮功能进行特殊处理，或者UI增删字段的显示。例如记录哪些用户下载过附件，禁止哪些用户下载指定附件，则需要进行附件的“下载”按钮进行客制化处理；
• 因为按钮是在视图中进行配置的，所以需要对附件功能的按钮进行客制化，则需要配置功能附件的视图。上面的介绍中并没有进行附件视图的配置，是因为框架中已经对Attachment<TOwner>进行过ViewConfig的配置，如对功能附件客制化，则需对功能附件进行ViewConfig配置。
20.2.1. 视图配置
配置web视图，定义按钮和视图，基类AttachmentViewConfig已经实现，
如果有特殊需求，请继承 WebViewConfig<TEntity> ，下面是基类实现。
命令： 使用了上传，删除，下载按钮，如果是只读，则只有下载按钮
列表：包括文件名，路径，扩展名，文件大小列
下拉列表：包括文件名，路径，扩展名，文件大小列
// <summary>  
/// 附件web视图配置  
/// </summary>  
public class AttachmentViewConfig : WebViewConfig<Attachment>  
{  
/// <summary>  
/// 附件视图配置  
/// </summary>  
protected override void ConfigView()  
{  
if (ViewGroup == "Readonly")  
{  
       this.UseReadOnlyCommand();  
}  
else  
{  
View.InlineEdit();  
this.UseCommand();  
}  
  
using (View.OrderProperties())  
{  
View.Property(p => p.FileName).Show(ShowInWhere.All);  
View.Property(p => p.FilePath).Show(ShowInWhere.All);  
View.Property(p => p.FileExtesion).Show(ShowInWhere.All);  
View.Property(p => p.FileSize).Show(ShowInWhere.All);  
}  
}  
  
/// <summary>  
/// readonlyCommand  
/// </summary>  
protected virtual void UseReadOnlyCommand()  
{  
View.UseCommands(typeof(DownloadCommand).FullName);  
}  
  
/// <summary>  
/// 正常命令  
/// </summary>  
protected virtual void UseCommand()  
{  
View.UseCommands(  
typeof(UploadAttachmentCommand).FullName,  
typeof(DeleteAttachmentCommand).FullName,  
typeof(DownloadCommand).FullName);  
}  
  
/// <summary>  
/// 下拉视图配置  
/// </summary>  
protected override void ConfigSelectionView()  
{  
View.Property(p => p.FileName);  
View.Property(p => p.FilePath);  
View.Property(p => p.FileExtesion);  
View.Property(p => p.FileSize);  
}  
}  
 
UploadAttachmentCommand 附件上传命令
DownloadCommand 附件下载命令
DeleteAttachmentCommand 删除命令

子类可以自定义命令，并覆写命令，覆写前调用清除命令，因为继承链上的每个配置类都会运行，命令会叠加
1 View.ClearCommands();
例如：App菜单附件使用了自定义的命令 AddAttachmentCommand和标准的下载DownloadCommand，删除 AppDeleteAttachmentCommand 命令，
这里先清除命令再添加自定义命令

class AppAttachmentViewConfig : AttachmentViewConfig
{
/// <summary>
/// 使用子类上传附件
/// </summary>
protected override void UseCommand()
{
View.ClearCommands();
View.UseCommands(
typeof(AppUploadAttachmentCommand).FullName,
typeof(AppDeleteAttachmentCommand).FullName,
typeof(DownloadCommand).FullName);
}
}
 
20.2.2. 上传命令使用
上传附件前端js 基类：SIE.Web.Common.Attachments.Commands.UploadAttachmentCommand，
提供了基本文件验证，保存逻辑， 可以根据需要继承前端基类，覆写验证或者保存后逻辑
 SIE.defineCommand('SIE.Web.Common.Attachments.Commands.UploadAttachmentCommand', {  
 meta: { text: "上传", group: "edit", iconCls: "icon‐Upload icon‐blue" },  
 myview: {},  
 /** 
 * 是否可以执行 
 * @param {*} view 
 * @returns 总是可以执行， 
 * 子类可以根据具体情况覆写 
 */  
 canExecute: function (view) {  
   return true;  
 },  
 /** 
 *执行方法 
 * 
 * @param {*} listView 
 * @param {*} source 
 */  
 execute: function (listView, source) {  
 myview = listView;  
 var btnFile = Ext.create('Ext.form.field.FileButton', { renderTo: Ext.getBody(), hidden: true });  
 btnFile.on("change", this.buttonChange, this);  
 btnFile.fileInputEl.dom.click();  
 },  
 /** 
 * 文件验证，子类可以覆盖， 
 * 编写自己的验证逻辑 
 * 一般是先调用基类的方法，在编写自己的逻辑 
 * 调用基类的方法：this.callParent(arguments); 
 * 
 * @param {string} fileSize 文件大小，字节 
 * @param {string } fileName 文件名称 
 * @param {*} file 文件对象 
 * @param {*} entity 附件对应的实体对象 
 * @returns 
 */  
 validateFile: function (fileSize, fileName, file, entity) {  
 if (Ext.isEmpty(fileName)) {  
 Ext.MessageBox.alert("提示", "上传的文件名不能为空。");  
 return false;  
 }  
  
 var size = fileSize / 1024;  
 if (size > 20000) {  
 Ext.MessageBox.alert("提示", "附件不能大于20M。");  
 return false;  
 }  
  
 return true;  
 },  
 /** 
 *获取文件，验证，并保存 
 * 
 * @param {*} field 输入控件 
 * @param {*} newValue 文件内容 
 * @returns 
 */  
 buttonChange: function (field, newValue) {  
 var file = field.fileInputEl.dom.files.item(0);  
 var fileSize = file.size;  
 var entity = myview.getParent().getCurrent().data;  
 var fileName = file.name;  
 var validateResult = this.validateFile(fileSize, fileName, file, entity);  
 if (!validateResult) {  
   return;  
 }  
  
 var fileExt =  
fileName.substring(fileName.lastIndexOf(".")).toLowerCase();  
 var fileReader = new FileReader('file://' + newValue);  
 fileReader.readAsDataURL(file);  
 fileReader.onload = function (e) {  
 if (myview) {  
 if (entity) {  
 myview.execute({  
 data: {  
 Attachment: {  
 OwnerId: entity.Id,  
 Content: e.target.result,  
 FileSize: fileSize,  
 FileExtesion: fileExt,  
 FileName: fileName  
 },  
    Entity: entity  
 },  
 success: function (res) {  
 myview.reloadData();  
 myview.getParent().getChildren()[1].reloadData();  
 Ext.Msg.alert('提示', res.Result);  
 }  
 });  
 }  
 }  
 }  
 }  
 });  
 
文件验证：validateFile 函数，只验证了文件名和大小， 子类覆写前可以先调用基类逻辑，
例如：app菜单附件 的command 继承后，先调用基类逻辑，然后编写了自己的验证。
SIE.defineCommand('SIE.Web.Rbac.APPMenus.Commands.AddAttachmentCommand',  
{  
 extend: 'SIE.Web.Common.Attachments.Commands.UploadAttachmentCommand',  
 validateFile: function (fileSize, fileName, file, entity) {  
 var result = this.callParent(arguments);  
 if (!result) {  
    return false;  
 } else {  
 var appHisId = entity.AppHisId;  
 if (appHisId == 0) {  
 Ext.MessageBox.alert("提示", "请先保存后再上传附件。");  
 return false;  
 }  
  
 var zipName = appHisId.toString() + ".zip";  
 if (zipName != fileName) {  
 Ext.MessageBox.alert("提示", "上传的文件名必须是 " + zipName);  
 return false;  
 }  
  
    return true;  
 }  
 }  
 }); 
 
文件上传服务端基类，SIE.Web.Common.Attachments.Commands，
提供了基本的保存附件逻辑，并提供了附件保存前验证事件， 保存前事件和附件保存后事件 ，
便于子类扩展。 如有特殊需求，可以继承: ViewCommand，自定义实现。
 /// <summary>  
 /// 上传附件  
 /// </summary>  
[JsCommand("SIE.Web.Common.Attachments.Commands.UploadAttachmentCommand")]  
 public class UploadAttachmentCommand : ViewCommand  
 {  
 /// <summary>  
 /// 附件保存前验证事件，子类可以根据需要扩展，比如验证附件中的内容  
 /// </summary>  
 public event Func<Stream, string> ValidatingFileStream;  
  
 /// <summary>  
 /// 附件保存前事件，子类可以根据需要扩展  
 /// </summary>  
 public event Func<UploadAttachmentViewArgs, string> SavingAttachement;  
  
 /// <summary>  
 /// 附件保存后事件，子类可以根据需要扩展，比如保存实体相关的内容  
 /// </summary>  
 public event Func<UploadAttachmentViewArgs, string> SavedAttachement;  
  
 /// <summary>  
 /// 服务端命令  
 /// </summary>  
 /// <param name="args"></param>  
 /// <param name="scope"></param>  
 /// <returns></returns>  
 protected override object Excute(ViewArgs args, string scope)  
 {  
 var meta = ClientEntities.Find(args.Type);  
 if (scope != meta.EntityType.GetQualifiedName())  
 throw new System.Security.SecurityException("参数type[{0}]与令牌不一致".F  
ormatArgs(args.Type));  
  
 var viewArgs = this.DeserializeData(args.Data);  
 var entityType = meta.EntityType;  
 viewArgs.Attachment.OwnerType = entityType;  
 var sm = this.GetAttachement(viewArgs);  
  
 // 验证事件，保存附件前的验证  
 var validateMsg = this.OnValidateFileStream(sm);  
 if (!string.IsNullOrEmpty(validateMsg))  
 {  
 return validateMsg;  
 }  
  
 // 保存前事件  
 this.OnSavingAttachement(viewArgs);  
  
 // 保存  
 this.SaveAttachement(viewArgs, entityType);  
  
 // 保存附件后的事件  
 this.OnSavedAttachement(viewArgs);  
 return "上传成功。".L10N();  
 }  
  
 /// <summary>  
 /// 从前端json数据反序列化  
 /// </summary>  
 /// <param name="data">前端传递的数据 json格式 ，包含附件和实体对象</param>  
 /// <returns>AttachmentViewArgs 对象</returns>  
 private UploadAttachmentViewArgs DeserializeData(string data)  
 {  
 UploadAttachmentViewArgs viewArgs = null;  
 if (!string.IsNullOrEmpty(data))
 {  
 JObject jo = JObject.Parse(data);  
 viewArgs = new UploadAttachmentViewArgs();  
  
 // 附件对象AttachmentViewArgs  
 viewArgs.Attachment = new UpLoadAttachment();  
 viewArgs.Attachment.FileExtesion = jo["Attachment"]["FileExtesion"].ToS  
tring();  
 viewArgs.Attachment.FileSize = jo["Attachment"]["FileSize"].ToString();  
 viewArgs.Attachment.FileName = jo["Attachment"]["FileName"].ToString();  
 viewArgs.Attachment.OwnerId = jo["Attachment"]["OwnerId"].ToString();  
  
 // 解析出base64的字符，格式形如：data:application/zip;base64,UEsDBBQAAAAIAKJUU02Zjai********  
 var raw = jo["Attachment"]["Content"].ToString();  
 var base64Discriminator = "base64,";  
 var base64Index = raw.IndexOf(base64Discriminator) + base64Discriminator.Length;  
 var base64Str = raw.Substring(base64Index);  
  
 // 转换为byte[]  
 viewArgs.Attachment.Content = Convert.FromBase64String(base64Str);  
  
 // 实体对象  
 viewArgs.ParentEntity = jo["Entity"].ToString();  
 }  
  
 return viewArgs;  
 }  
 private string OnSavingAttachement(AttachmentViewArgs viewArgs){......}  
 private string OnSavedAttachement(AttachmentViewArgs viewArgs){......}  
 private string OnValidateFileStream(Stream stream){.....}  
 private void SaveAttachement(AttachmentViewArgs viewArgs, Type type)  
{......}  
 }  
 
UploadAttachmentViewArgs 上传附件参数包含了上传对象和附件父对象的json串
/// <summary>  
/// 从前台传递过来的附件参数  
/// 包含附件和实体对象  
/// </summary>  
public class UploadAttachmentViewArgs  
{  
/// <summary>  
/// 上传附件对象  
/// </summary>  
public UpLoadAttachment Attachment { get; set; }  
  
/// <summary>  
/// 父实体对象  
/// </summary>  
public string ParentEntity { get; set; }  
}  
 
子类可以继承 UploadAttachmentCommand ，订阅事件实现自己的逻辑。
例如 app菜单附件，要验证附件内容，并根据附件内容填充子菜单表，重写了验证和保存逻辑。
 /// <summary>  
 /// 附件上传命令  
 /// </summary>  
 [JsCommand("SIE.Web.Rbac.APPMenus.Commands.AppUploadAttachmentCommand")]  
 public class AppUploadAttachmentCommand : UploadAttachmentCommand  
 {  
 /// <summary>  
 /// 附件中的子菜单内容  
 /// </summary>  
 private string menuContext;  
  
 /// <summary>  
 /// 注册验证和保存后事件  
 /// </summary>  
 public AppUploadAttachmentCommand()  
 {  
 this.ValidatingFileStream += AddAttachmentCommand_ValidatingFileStream;  
 this.SavedAttachement += AddAttachmentCommand_SavedAttachement;  
 }  
  
 /// <summary>  
 /// 保存事件  
 /// 保存menu.config中的子菜单  
 /// </summary>  
 /// <param name="arg"></param>  
 /// <returns></returns>  
 private string AddAttachmentCommand_SavedAttachement(UploadAttachmentViewArgs arg)  
 {  
 // 根据json字符转换为强类型对象  
 AppMenu appMenu = arg.ParentEntity.ToJsonObject<AppMenu>();  
 if (!string.IsNullOrEmpty(menuContext))  
 {  
 JObject jo = JObject.Parse(menuContext);  
 string code = jo["code"].ToString();  
 appMenu.Code = code;  
 string ops = string.Empty;  
 if (jo.ContainsKey("ops"))  
 {  
 JArray opsArray = jo["ops"] as JArray;  
 ops = this.GetOps(opsArray);  
 }  
  
 EntityList<AppSubMenu> list = new EntityList<AppSubMenu>();  
  
 // 添加根节点，就是appMenu 自己  
 AppSubMenu root = new AppSubMenu  
 {  
 Code = code,  
 Name = appMenu.Label,  
 Operations = ops,  
 AppMenu = appMenu  
 };  
  
 root.GenerateId();  
 list.Add(root);  
  
 // 根据配置文件内容填充子菜单集合到 实体对象属性AppSubMenuList  
 JArray childs = jo["childs"] as JArray;  
 var subMenus = this.RecursiveSubMenu(childs, root.Id, appMenu);  
  
 if (subMenus != null && subMenus.Count > 0)  
 {  
   list.AddRange(subMenus);  
 }  
  
 if (list != null && list.Count > 0)  
 {  
   RF.Save(list);  
 }  
 }  
  
 return string.Empty;  
 }  
  
 /// <summary>  
 /// 验证事件  
 /// 验证menu.config中的节点信息  
 /// </summary>  
 /// <param name="arg"></param>  
 /// <returns></returns>  
 private string AddAttachmentCommand_ValidatingFileStream(Stream arg)  
 {  
 this.menuContext = this.ExtractZipFile(arg, string.Empty, "menus.confi  
g");  
 if (!string.IsNullOrEmpty(menuContext))  
 {  
   JObject jo = JObject.Parse(menuContext);  
 if (!jo.ContainsKey("code"))  
 {  
   return "必须包含根节点code.".L10N();  
 }  
  
 string code = jo["code"].ToString();  
 if (string.IsNullOrEmpty(code))  
 {  
   return "根节点code不能为空.".L10N();  
 }  
 }  
  
 return string.Empty;  
 }  
 /// <summary>  
 /// 递归获取子菜单内容，子菜单里面有下级，下级里面也有下级  
 /// </summary>  
 /// <param name="ja">JArray 子菜单数组</param>  
 /// <param name="treePId">父级id</param>  
 /// <returns>子菜单列表</returns>  
 private List<AppSubMenu> RecursiveSubMenu(JArray ja, double treePId, AppMenu appMenu)  
 {  
   .....  
 }  
  
 /// <summary>  
 /// 从压缩文件中读取某个文件的内容  
 /// 文本文件  
 /// </summary>  
 /// <param name="archiveFilenameIn">压缩包文件</param>  
 /// <param name="password">密码</param>  
 /// <param name="fileName">需要读取的文件名</param>  
 /// <returns>文件的内容</returns>  
 private string ExtractZipFile(Stream fs, string password, string fileName)  
 {  
 ZipFile zf = null;  
 try  
 {  
 zf = new ZipFile(fs);  
 if (!String.IsNullOrEmpty(password))  
 {  
 // AES encrypted entries are handled automatically  
 zf.Password = password;  
 }  
  
 foreach (ZipEntry zipEntry in zf)  
 {  
 if (!zipEntry.IsFile)  
 {  
 // Ignore directories  
 continue;  
 }  
  
 if (String.Compare(zipEntry.Name, fileName, true) != 0)  
 {  
   continue;  
 }  
  
 Stream zipStream = zf.GetInputStream(zipEntry);  
 StreamReader sr = new StreamReader(zipStream);  
 string fileContext = sr.ReadToEnd();  
 return fileContext;  
 }  
 }  
 finally  
 {  
 if (zf != null)  
 {  
 zf.IsStreamOwner = true; // Makes close also shut the underlying stream  
 zf.Close(); // Ensure we release resources  
 }  
    }  
  
 return string.Empty;  
 }  
 
20.2.3. 下载命令使用
前端下载命令：SIE.Web.Common.Attachments.Commands.DownloadCommand，
直接使用，如有特殊需求，请自行实现。
SIE.defineCommand('SIE.Web.Common.Attachments.Commands.DownloadCommand',  
meta: { text: "下载", group: "edit", iconCls: "icon‐Delete icon‐blue" },  
execute: function (listView, source) {  
var selections = listView.getSelection();  
if (!selections || selections.length <= 0) {  
SIE.Msg.showWarning('请选择一行。');  
return;  
}  
  
listView.execute({  
data: {},  
success: function (res) {  
if (res.Result) {  
  
// 选择行中获取文件路径  
var filePath = selections[0].data.FilePath;  
  
// 服务端返回基地址  
var rootUrl = res.Result;  
var url = rootUrl + filePath;  
window.open(url);  
}  
}  
});  
}  
}); 
 
服务端下载命令：SIE.Web.Common.Attachments.Commands.DownloadCommand，
返回基地址，直接使用，如果特殊需求，请自行实现。
using SIE.Web.Command;  
namespace SIE.Web.Common.Attachments.Commands  
{  
/// <summary>  
/// 附件下载  
/// </summary>  
[JsCommand("SIE.Web.Common.Attachments.Commands.DownloadCommand")]  
public class DownloadCommand : ViewCommand  
{  
/// <summary>  
/// 附件配置地址，从web.config中的节点client.attachmentDownloadUrl 获取  
/// </summary>  
/// <param name="args"></param>  
/// <param name="scope"></param>  
/// <returns></returns>  
protected override object Excute(ViewArgs args, string scope)  
{  
var rootUrl = RT.Configuration.GetSetting("client.attachmentDownloadUrl");  
return rootUrl;  
}  
}  
} 
 
20.2.4. 删除命令
删除命令前端js类：SIE.Web.Common.Attachments.Commands.DeleteAttachmentCommand，
提供了删除附件的功能和删除后事件 afterDelete 供子类扩展。
SIE.defineCommand('SIE.Web.Common.Attachments.Commands.DeleteAttachmentCommand', {  
 extend: 'SIE.cmd.Delete',  
 isImmediate: true,  
 afterDelete: function (view) { },  
 execute: function (view) {  
 var me = this;  
 if (view.isListView) {  
 var isImmediate = me.isImmediate;  
 var msg = Ext.String.format('你确定删除选择的{0}条数据吗？'.L10N(), this.selectedItems.length);  
 if (isImmediate)  
   msg += "确定后将直接删除！".L10N();  
 else  
   msg += "删除后，需要再次点击保存！".L10N();  
  
 SIE.Msg.askQuestion(msg, function () {  
 if (isImmediate) {  
 view.removeSelection();  
 var children = view.getChildren();  
 var withChildren = children.length > 0;  
 var store = view.getData();  
 var entity = view.getCurrent().data;  
 var parentEntity = view.getParent().getCurrent().data;  
 view.execute({  
 withChildren: withChildren,  
 data: {  
 AttachmentId: entity.Id,  
 Attachment: entity,  
 ParentEntity: parentEntity,  
 },  
 success: function (res) {  
 store.commitChanges();  
 me._viewReload(view);  
 me.afterDelete(view);  
 },  
 error: function (res) {  
   store.rejectChanges();  
 }  
 });  
 view.setCurrent(null);  
 }  
 else {  
 view.removeSelection();  
 view.setCurrent(null);  
 }  
 });  
 }  
 else {  
    //form view  
 }  
 }  
 });  
 
例如：APP菜单，重写了afterDelete ，重新加载了子菜单列表
SIE.defineCommand('SIE.Web.Rbac.APPMenus.Commands.AppDeleteAttachmentCommand', {  
extend: 'SIE.Web.Common.Attachments.Commands.DeleteAttachmentCommand',  
afterDelete: function (view) {  
        view.getParent().getChildren()[1].reloadData();  
},  
  
});  
 
服务端类：SIE.Web.Common.Attachments.Commands.DeleteAttachmentCommand
提供了删除附件，删除附件前事件，删除后事件给子类扩展。
/// <summary>  
/// 附件删除  
/// </summary>  
JsCommand("SIE.Web.Common.Attachments.Commands.DeleteAttachmentCommand")]  
public class DeleteAttachmentCommand : DeleteCommand  
{  
/// <summary>  
/// 附件删除前事件，子类可以根据需要扩展  
/// </summary>  
public event Func<DeleteAttachmentViewArgs, string>  DeletingAttachement;  
  
/// <summary>  
/// 附件删除后事件，子类可以根据需要扩展，  
/// </summary>  
public event Func<DeleteAttachmentViewArgs, string> DeletedAttachement;  
  
/// <summary>  
/// 执行命令  
/// </summary>  
/// <param name="args"></param>  
/// <param name="scope"></param>  
/// <returns></returns>  
protected override object Excute(ViewArgs args, string scope)  
{  
.......  
}  
}  
 
删除附件参数提供了 附件Id，附件json对象，附件对应的父实体json对象
public class DeleteAttachmentViewArgs  
{  
/// <summary>  
/// 附件id  
/// </summary>  
public string AttachmentId { get; set; }  
  
/// <summary>  
/// 附件对象对应的json串  
/// </summary>  
public object Attachment { get; set; }  
  
/// <summary>  
/// 父实体对象对应的json串  
/// </summary>  
public object ParentEntity { get; set; }  
} 
 
子类继承DeleteAttachmentCommand，可以扩展自己业务逻辑，
例如 app 菜单附件扩展了删除后事件，把子菜单删除了。
[JsCommand("SIE.Web.Rbac.APPMenus.Commands.AppDeleteAttachmentCommand")]  
public class AppDeleteAttachmentCommand : DeleteAttachmentCommand  
{  
/// <summary>  
/// 附件删除，同步删除子菜单  
/// </summary>  
public AppDeleteAttachmentCommand()  
{  
// 订阅删除后事件  
this.DeletedAttachement += AppDeleteAttachmentCommand_DeletedAttachement;  
}  
  
/// <summary>  
/// 删除后事件，删除对应的子菜单  
/// </summary>  
/// <param name="arg"></param>  
/// <returns></returns>  
private string AppDeleteAttachmentCommand_DeletedAttachement(DeleteAttachmentViewArgs arg)  
{  
var entity = arg.ParentEntity.ToString();  
if (!string.IsNullOrEmpty(entity))  
{  
var appMenu = entity.ToJsonObject<AppMenu>();  
var appSubMenuList = RT.Service.Resolve<AppsMenuController>().GetAppMenusByParentId(appMenu.Id);  
appSubMenuList?.ForEach(p => p.PersistenceStatus = PersistenceStatus.Deleted);  
RF.Save(appSubMenuList);  
}  
  
return string.Empty;  
}  
} 
 
 
总结：通用组件实现了基本的上传，下载， 删除，如无特殊需求，
可以直接使用，在视图配置中使用通用命令即可
同时也提供了扩展点，给子类自定义实现。
如有还要不满足的需求，请自行实现。
 

 

 
20.3. 框架通用附件使用示例
1.新建一个附件实体类
/// <summary>  
/// 出货检验附件  
/// </summary>  
[ChildEntity, Serializable]  
   [Label("出货检验附件")]  
public partial class OobInspBillAttachment : Attachment<OobInspBill>  
   {  
}  
  
   /// <summary>  
   ///  仓库  
   /// </summary>  
   [DataProvider(typeof(OqcEntityDataProvider))]  
   public partial class OobInspBillAttachmentRepository : AttachmentRepository<OobInspBillAttachment>  
   {  
   }  
  
   /// <summary>  
   /// 出货检验附件 实体配置  
   /// </summary>  
   internal class OobInspBillAttachmentConfig : AttachmentEntityConfig<OobInspBillAttachment>  
{  
       /// <summary>  
       /// 配置  
       /// </summary>  
    protected override void ConfigMeta()  
    {   
           base.ConfigMeta();  
           Meta.EnableDiscriminator("OobInspBill");  
       }  
} 
 
2.在使用附件的主实体中添加一个列表属性，关联附件
#region 附件 AttachmentList  
/// <summary>  
/// 附件  
/// </summary>  
[Label("附件清单")]  
public static readonly ListProperty<EntityList<OobInspBillAttachment>> AttachmentListProperty = P<OobInspBill>.RegisterList(e => e.AttachmentList);  
  
/// <summary>  
/// 附件  
/// </summary>     
public EntityList<OobInspBillAttachment> AttachmentList  
{  
    get { return this.GetLazyList(AttachmentListProperty); }  
}  
#endregion 
 
3.视图配置
View.ChildrenProperty(p => p.AttachmentList).Show(ChildShowInWhere.All)
如果要附件子列表只有下载附件的权限，可配置
View.ChildrenProperty(p => p.AttachmentList).HasLabel("附件清单").Show(ChildShowInWhere.All).ViewGroup = "Readonly";
4.本地调试的话在webclient的配置文件中配置附件方式

5. 如果本地调试配置的是ftp形式，需要在本地安装部署ftp
本地windows系统ftp的安装和配置步骤：
• 控制面板-程序和功能-启用或关闭Windows功能-Internet Information Services-FTP服务器，点击确定，等待安装完成

• 安装完成后，在IIS管理器的网站中右键“添加FTP站点…”


注：如果需要添加多个FTP站点，记得修改端口号



• 添加FTP账号


• 用户授权
删除上传至FTP文件，需要对User用户授予完全控制权限



21. 编码生成规则
21.1. 界面及通用配置说明
编码生成规则，用于根据指定规则生成各种单据流水编号


在《编码规则》中的《编码段》中初始化算法，并启用相关编码段算法


创建新的编码规则，并添加指定的算法


界面配置项配置：


配置项界面配置值维护：


框架通用配置项的配置：


框架通用配置项获取编码规则的实现：


22. 配置项的使用
配置项，是指定功能中的一些使用规则，定义一些配置。
22.1. 继承ConfigValue
在服务端添加一个配置项的类，继承ConfigValue
***此类名称必须以XXXXXValue命名，最后必须带“Value”

 

22.2. 添加规则类界面
在客户端添加配置规则类对应的界面

22.3. 添加规则生成说明类
**规则生成说明类的命名，必须是配置项的类类名“Value”之前的部分，如配置项的类类名为“XXXXXValue”时规则生成说明类必须命名为“XXXXX”。这里要注意不要与实体配置类的命名冲突了。

22.4. 在对应实体中使用配置项

22.5. 获取功能配置项的值
ConfigService.GetConfig<XXConfigValue>(new XXConfig(), typeof(Student));
注意：XXConfig()为规则生成说明类，typeof(Student)为对应使用该规则生成说明类的实体；这里的规则生成说明类与实体要与对应实体及实体配置的规则生成说明类要完全一致，否则设置的值和获取的值会不一致。

23. 配置项列表编码自动生成
说明：配置项的使用参考上面22.配置项的使用，这里主要说明调用编码规则编号自动生成的实现。

编码自动生成的示例，这里以添加命令为例进行说明。
1. 添加JS文件，需要嵌套到资源

2. 添加与JS相同的名称的CS文件

3. 在客户端使用命令

4. 运行程序在界面维护规则，点击添加即可看到效果。
24. 配置项表单编码自动生成
说明：配置项的使用参考上面22.配置项的使用，这里主要说明调用编码规则编号自动生成的实现。

1. 重写添加命令，重写showView方法，在执行的回调方法中通过CRT.Workbench.addPage的params参数把获取到的编码传到界面中，params可以传一个或者多个参数，示例代码如下:

2. 在命令的后端获取配置的编码规则



 
3. 在打开界面的视图配置方法中添加行为进行赋值，如：

4. 用重写的添加命令替换框架默认的命令（即步骤1，2的命令名称），在详细视图配置方法中使用步骤上的行为。
25. 标签和单据打印
标签打印与单据打印的区别：报表的数据源不一样，标签打印获取的数据源是当前实体对应表，单据打印获取的数据源是当前实体与当前实体关联的子列表对应的表。
25.1 标签打印
定义标签打印的命令文件，包括js和cs文件。

25.1.1. 创建标签打印的基类
在服务端创建一个标签打印类，继承LabelPrintable
    /// <summary>
    /// 物料标签打印
    /// </summary>
    [DisplayName("物料标签打印")]
    public class ItemLabelPrintable: LabelPrintable<Item>
    {
        public override IEnumerable<string> GetPropertys(Type type = null)
        {
            return base.GetPropertys(type);
        }

        public override string ConverterData(object data)
        {
            return base.ConverterData(data);
        }
    }
说明：
1. 如果关联的实体对应的数据源满足要求，则不需要重写GetPropertys和ConverterData方法；
2. 如果重写了GetPropertys和ConverterData方法，则GetPropertys的属性和ConverterData的数据处理是一对一的
3. 这部分代码完成后即可在“模板设置—添加标签模板—名称”的下拉列表中显示出来


如需要把数据源字段改成中文并赋值，需要重写标签模板的GetPropertys和ConverterData方法，实现代码示例参考如下：
    /// <summary>
    /// 单位标签打印
    /// </summary>
    [DisplayName("单位标签打印")]
    public class UnitLabelPrintable:LabelPrintable<Unit>
    {
        public override IEnumerable<string> GetPropertys(Type type = null)
        {
            var propertys = new List<string>();
            if (type == typeof(Unit))
            {
                propertys.Add("编码");
                propertys.Add("名称");
                propertys.Add("类型");
                propertys.Add("单位精度");
                propertys.Add("修改人");
                propertys.Add("修改时间");
                //必须的字段，没有的话会报错
                propertys.Add("Id");
            }
            return propertys;
        }

        public override string ConverterData(object data)
        {
            var content = string.Empty;
            if (data is Unit)
            {
                var bill = data as Unit;
                if (bill != null)
                {
                    content += bill.Code + Separator
                        + bill.Name + Separator
                        + bill.Type + Separator
                        + bill.Precision + Separator
                        + bill.UpdateByName + Separator
                        + bill.UpdateDate.ToString("yyyy年MM月dd日") + Separator
                        + bill.Id + Separator;
                }
            }
            return content;
        }
    }


25.1.2. 定义标签打印的命令文件
25.1.2.1. 直接使用模板设置中设置好的模板示例
15.1.2.1.1. js命令文件
SIE.defineCommand('SIE.Web.Demo.Items.Commands.UnitLabelPrintCommand', {
    meta: { text: "单位标签打印", group: "edit", iconCls: "icon-PrintData icon-blue" },
    canExecute: function (view) {
        return view.hasSelectedEntities();
    },
    execute: function (view, source) {
        var me = this;
        view.execute({
            data: view.getSelectionIds(),
            success: function (res) {
                var param = { content: res.Result };
                CRT.Workbench.showPageDialog({
                    id: 'Label_rpt',
                    text: "标签打印".t(),
                    url: '/Modules/PrintTemplate/DevPrint',
                    params: param,
                    method: 'POST'
                });
            }
        });
    }
});

说明：
1. 添加的标签打印命令不需要去继承父类；
2. 调用标签打印通过CRT.Workbench.showPageDialog打开标签打印页签，打印的方法为/Modules/PrintTemplate/DevPrint，参数为params，请求方式为POST
15.1.2.1.2. CS命令文件
    public class UnitLabelPrintCommand : ViewCommand
    {
        protected override object Excute(ViewArgs args, string scope)
        {
            List<double> ids = args.Data.ToJsonObject<List<double>>();
            // 1.获取打印模板
            var template = RT.Service.Resolve<ItemController>().GetPrintTemplate();
            //2.根据类型获取报表处理对像
            var report = ReportFactory.Current.GetReportByExtension(template.Type);
            //3.获取打印实体对像
            var printableType = Type.GetType(template.EntityType);
            //4.获取打印数据
            var printData = RT.Service.Resolve<ItemController>().GetUnitPrintData(ids);
            //5.创建实体打印对像 如果清楚实体打印对像自己NEW 一个出来也行
            var printable = new UnitLabelPrintable();
            //6.调用打印处理函数返回打印模板BASE64字符串到前台，用于传输到打印预览页面
            return report.PrintProcess(printable, template.Content, () =>
            {
                return printData;
            });
        }
} 

说明：
1. 获取打印模板，方法需要自己去实现，如下为参考代码： 
        public virtual PrintTemplate GetPrintTemplate()
        {
            var temp = RT.Service.Resolve<PrintsController>().GetPrintTemplates("SIE.Demo.Items.UnitLabelPrintable,SIE.Demo", true).FirstOrDefault();
            return temp;
        }
其中PrintTemplate在SIE.Common.Prints命令空间下，获取打印模板GetPrintTemplates的第一个参数实体类型需要带名称空间(这里会根据命令空间去获取2.1步骤中定义的标签类设置的模板)，第二个参数为模板的启用状态（我们获取的是启用的模板）
2. 根据类型获取报表处理对像：该代码为通用
3. 获取打印实体对象：该代码为通过
4. 获取打印数据，需自己去实现，参考代码如下：
        public virtual EntityList<Unit> GetUnitPrintData(List<double> ids)
        {
            var units = Query<Unit>().Where(p => ids.Contains(p.Id)).ToList();
            return units;
        }
5. 创建实体打印对象：这里的对象为2.1步骤中定义的标签类
6. 调用打印机处理数据：该部分代码通用

15.1.2.1.3. 在界面使用命令及效果
View.UseCommands(typeof(UnitLabelPrintCommand).FullName);

 
25.1.2.2. 使用自定义模板

25.1.2.2.1. Js命令文件
与15.1.2.1的js命令文件一致。
SIE.defineCommand('SIE.Web.Demo.Items.Commands.ItemLabelPrintCommand', {
    meta: { text: "标签打印", group: "edit", iconCls: "icon-PrintData icon-blue" },
    canExecute: function (view) {
        if (!view.hasSelectedEntities()) {
            return false;
        }
        else {
            for (i = 0; i < view.getSelectedEntities().length; i++) {
                var label = view.getSelectedEntities()[i].data;
                return !label.IsScrapped;
            }
        }
    },
    execute: function (view, source) {
        var me = this;
        view.execute({
            data: view.getSelectionIds(),
            success: function (res) {
                var param = { content: res.Result };
                CRT.Workbench.showPageDialog({
                    id: 'Label_rpt',
                    text: "标签打印".t(),
                    url: '/Modules/PrintTemplate/DevPrint',
                    params: param,
                    method: 'POST'
                });
                view.loadData();
            }
        });
    }
}); 
25.1.2.2.2. cs命令文件
说明：与15.1.2.1的cs命令文件差异部分为说明中的1和4项
    public class ItemLabelPrintCommand : ViewCommand<double[]>
    {
        protected override object Excute(double[] args, string scope)
        {
            var ctl = RT.Service.Resolve<ItemController>();
            var labels = RT.Service.Resolve<ItemController>().GetItemLabelData(args.ToList());
            var items = labels.FirstOrDefault();
            if (items == null)
                throw new ValidationException("物料打印模板数据为维护".L10N());
            RT.Service.Resolve<ItemController>().LabelPrint(args.ToList());
            // 1.获取打印模板
            var template = RT.Service.Resolve<ItemController>().GetPrintTemplate(items);
            //2.根据类型获取报表处理对像
            var report = ReportFactory.Current.GetReportByExtension(template.Type);
            //3.获取打印实体对像
            var printableType = Type.GetType(template.EntityType);
            //4.获取打印数据
            List<Item> printData = new List<Item>();
            printData.AddRange(labels);
            //5.创建实体打印对像 如果清楚实体打印对像自己NEW 一个出来也行
            var printable = new ItemLabelPrintable();
            //6.调用打印处理函数返回打印模板BASE64字符串到前台，用于传输到打印预览页面
            return report.PrintProcess(printable, template.Content, () =>
            {
                return printData;
            });
        }
    }
说明：
1. 获取打印模板，方法需要自己去实现，如下为参考代码： 
        public virtual PrintTemplate GetPrintTemplate(Item item)
        {
            PrintTemplate template = new PrintTemplate();
            if (item != null && item.Template != null && item.Template.LabelTemplateId.HasValue)
            {
                var printTemplate = RF.GetById<PrintTemplate>(item.Template.LabelTemplateId.Value);
                if (printTemplate.State == State.Disable)
                    throw new ValidationException("打印模板禁用不能进行打印操作!".L10N());
                else
                    template = item.Template.LabelTemplate;
            }
            else
                throw new ValidationException("物料未维护标签模板,请维护后再进行打印操作!".L10N());
            return template;
        }
其中PrintTemplate在SIE.Common.Prints命令空间下，这里的打印模板为自己维护的模板
        public virtual EntityList<Item> GetItemLabelData(List<double> idList)
        {
            EntityList<Item> labels = new EntityList<Item>();
            EagerLoadOptions elo = new EagerLoadOptions();
            elo.LoadWith(Item.UnitProperty);
            for (int i = 0; i < Math.Ceiling((double)idList.Count() / 1000); i++)
            {
                var list = Query<Item>().Where(p => idList.Skip(i * 1000).Take(1000).Contains(p.Id)).ToList(null, elo);
                labels.AddRange(list);
            }
            return labels;
        } 

var labels = RT.Service.Resolve<ItemController>().GetItemLabelData(args.ToList());
var items = labels.FirstOrDefault();
2. 根据类型获取报表处理对像：该代码为通用
3. 获取打印实体对象：该代码为通过
4. 获取打印数据，需自己去实现，参考代码如下：
List<Item> printData = new List<Item>();
printData.AddRange(labels);
5. 创建实体打印对象：这里的对象为2.1步骤中定义的标签类
6. 调用打印机处理数据：该部分代码通用
25.1.2.2.3. 在界面使用命令及效果
View.UseCommands(typeof(ItemLabelPrintCommand).FullName);


 

25.2. 单据打印
25.2.1. 创建打印实体类
新建一个单据打印的实体类，继承单据打印的类BillPrintable
/// <summary>  
/// 来料检验单打印  
/// </summary>  
[DisplayName("来料检验单")]  
class IqcBillPrintable : BillPrintable<IqcBill>  
{  
    /// <summary>  
    /// 根据实体类型获取属性  
    /// </summary>  
    /// <param name="type">实体类型</param>  
    /// <returns>对应type的属性</returns>  
    public override IEnumerable<string> GetPropertys(Type type = null)  
    {  
        var propertys = base.GetPropertys(type).ToList();  
        if (type == typeof(IqcBill))  
        {  
            propertys.Add("SupplierName");  
            propertys.Add("ItemCode");  
            propertys.Add("ItemName");  
            propertys.Add("ItemDescription");  
            propertys.Add("Inspector");  
            propertys.Add("SupplierCode");  
            propertys.Remove("InspectionResult");  
            propertys.Add("InspectionResultDisplay");  
        }  
  
        if (type == typeof(IqcBillDetail))  
        {  
            propertys.Remove("InspectionResult");  
            propertys.Add("InspectionResultDisplay");  
            propertys.Add("SamplingPlan");  
            propertys.Add("Value1");  
            propertys.Add("Value2");  
            propertys.Add("Value3");  
            propertys.Add("Value4");  
            propertys.Add("Value5");  
            propertys.Add("Valuen");  
        }  
  
        return propertys;  
    }  
  
    /// <summary>  
    /// 转换数据  
    /// </summary>  
    /// <param name="data">实体对象</param>  
    /// <returns>转换后的数据</returns>  
    public override string ConverterData(object data)  
    {  
        var content = base.ConverterData(data);  
        if (data is IqcBill)  
        {  
            var bill = data as IqcBill;  
            if (bill != null)  
            {  
                content += bill.Supplier?.Name + Separator  
                    + bill.Item?.Code + Separator  
                    + bill.Item?.Name + Separator  
                    + bill.Item?.Description + Separator  
                    + bill.Inspector?.Name + Separator  
                    + bill.Supplier?.Code + Separator  
                    + (!bill.InspectionResult.HasValue ? null : (bill.InspectionResult == InspectionResult.Pass ? "合格" : "不合格")) + Separator;  
            }  
        }  
  
        if (data is IqcBillDetail)  
        {  
            var detail = data as IqcBillDetail;  
            if (detail != null)  
            {  
                content += (!detail.InspectionResult.HasValue ? null : (detail.InspectionResult == InspectionResult.Pass ? "合格" : "不合格")) + Separator;    //InspectionResultDisplay  
                if (detail.CheckTag == Defects.InspectionItems.CheckTag.Quantitative)  
                    content += detail.SamplingStep?.SamplingPlan?.Code + Separator;  
                else  
                    content += detail.SamplingStep?.SamplingPlan?.Code;  
                string temp = string.Empty;  
                for (int i = 0; i < detail.ValueList?.Count; i++)  
                {  
                    if (i < 5)  
                    {  
                        content += detail.ValueList[i].CheckValue.ToString() + Separator;  
                    }  
                    else  
                    {  
                        if (detail.ValueList[i].CheckValue.HasValue)  
                        {  
                            temp += detail.ValueList[i].CheckValue + ";";  
                        }  
                        else  
                        {  
                            temp += detail.ValueList[i].CheckValue;  
                        }  
                    }  
  
                    if (i == detail.ValueList.Count - 1)  
                    {  
                        content += temp;  
                    }  
                }  
            }  
        }  
  
        if (data is IqcValue)  
        {  
            var iqcVal = data as IqcValue;  
            if (iqcVal == null)  
            {  
                return null;  
            }  
        }  
  
        return content;  
    }  
}  

说明：
1. 如果关联的实体对应的数据源满足要求，则不需要重写GetPropertys和ConverterData方法；
2. 如果重写了GetPropertys和ConverterData方法，则GetPropertys的属性和ConverterData的数据处理是一对一的
3. 这部分代码完成后即可在“模板设置—添加单据模板—名称”的下拉列表中显示出来

25.2.2. 打印的特性
在实体中标记单据打印的特性，这里的实体名跟打印实体类中继承单据打印基类关联的实体为同一个
[BillPrintable(typeof(IqcBillPrintable))]  
public partial class IqcBill : SIE.QMS.Common.BillBase  

说明：
1. 标记特性通过BillPrintable来标记，typeof(IqcBillPrintable)为1.1中我们建的单据打印的实体类
2. 特性标记好后，在IqcBill功能操作中就会显示一个“打印”操作按钮

25.2.3. 效果

这里的模板是在模板设置中配置的单据，配置了多个，就会显示多个，如果只有一个，点击打印直接就预览了

25.3. 注意事项
1. 模板设置依赖于dev的控件、报表设计器和打印，缺少对应的dll，模板设计器会出现异常。

2. 模板设置的模板是保存到对应服务器的，需要配置附件方式

3. 关联的实体对应的数据源满足要求，则不需要重写GetPropertys和ConverterData方法；
4. 如果重写了GetPropertys和ConverterData方法，则GetPropertys的属性和ConverterData的数据处理是一对一的；
5. 打印模板的DisplayName特性是唯一的，可根据具体功能区分；
6. 模板中的数据源是读取缓存的，如果模板已经设置好后，再更改数据源和数据，需要重新构建，或者是删除再新建模板；
7. 报表设计器的属性如果是显示为英文，是缺少语言包；
8. 不管是标签还是单据打印，一定要判空处理；否则切换数据库在数据为空的情况下打印会报错；
9. 在数据转换方法ConverterData中，尽量少去查数据库进行操作；
10. 如何选择是用标签打印还是单据打印，取决于数据源，如果不需要子表的数据源则使用标签打印，否则使用单据打印；
11. 如果标签打印模板，不同的数据使用的模板不一样，只需要重写标签打印命令的获取模板数据部分的逻辑；
26. 实体扩展属性的实现
26.1. 应用场景
框架的dll是封装好的，在项目上根据项目的不同需求，封装好的一些基础功能可能满足不了项目的要求，需要在项目上扩展一些属性，当然这种场景也可以通过继承的方式进行实现，实体扩展只是其中的一种方式，后续项目中遇到对应的场景，可以选择自己熟悉的方式进行实现。
 
26.2. 实现示例
26.2.1. 服务端工程
      26.2.1.1. 新建服务端工程
新建一个服务端扩展工程，具体参考环境的搭建

 
      26.2.1.2. 添加扩展类

      26.2.1.3. 扩展一般属性

 

 
      26.2.1.4. 扩展引用属性

 

26.2.2. 添加一个UI扩展工程

 
26.2.2.1. 配置扩展界面
这里只需要把要添加的属性加上即可，界面展示是取两个方法的并集进行展示的。

 
26.2.2.2. 效果

 


