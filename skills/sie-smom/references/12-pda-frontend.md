> **类型**：精炼规则（个人经验整理，含明确的【禁止项 / 错误示例 / 正确示例】）
> **优先级**：高。
> **覆盖范围**：Vue2 语法限制·API 接口模板·调用处模板·Storage 工具·Prettier 风格

# PDA 前端（Vue2）编码规范

> **适用范围**:本规范适用于所有基于 Vue 2.5.x + Vux + axios 的 PDA 项目,始终生效。
> **内容概要**:Vue2 语法限制（禁止可选链）、API 接口实现模板、调用处模板、Prettier 代码风格。

## 一、Vue2 语法限制

### 1.1 禁止使用可选链 `?.`

Vue 2 项目的默认 Babel 配置（babel-preset-stage-2）不支持 `?.` 可选链操作符，编译时会报错。

```javascript
// 错误：Vue2 编译失败
const name = data?.Result?.Name;
const list = data?.Items ?? [];

// 正确：使用 && 短路判断
const name = data && data.Result && data.Result.Name;
const list = data && data.Items || [];
```

### 1.2 其他 Vue2 注意事项

- 不支持 `??` 空值合并运算符，用 `||` 替代
- 不支持 `Array.prototype.flat()`，用 `lodash` 的 `_.flatten` 替代
- 不支持 `String.prototype.trimEnd()` / `trimStart()`

## 二、API 接口实现模板

### 2.1 文件结构

所有 API 接口文件放在 `src/assets/plugins/axios-api/api/<ControllerName>/` 目录下，框架自动注册到 `this.$axiosApi`。

### 2.2 单参数接口模板

```javascript
import Vue from 'vue';
import Storage from '@/assets/js/storage.js'
export default function (code) {
    return Vue.axios.post(Storage.url(), {
        "ApiType": "TaskManagerPDAController",
        "Parameters": [
            {
                "Value": code
            }
        ],
        "Method": "GetRecommendLocation",
        "Context": {
            "Ticket": Storage.ticket(),
            "InvOrgId": Storage.orgid()
        }
    }).then(res => {
        const data = res.data;
        if (data.Success) {
            if (data.Context.Ticket) {
                Storage.refreshTicket(data.Context.Ticket);
            }
            return data.Result;
        } else {
            // 抛出一个特殊的错误对象，用于区分业务错误和网络错误
            const businessError = new Error(data.Message);
            businessError.isBusinessError = true;
            throw businessError;
        }
    }).catch(err => {
        // 区分业务逻辑错误和网络连接错误
        if (err.isBusinessError) {
            // 业务逻辑错误已经在上面处理过了，这里只需要重新抛出
            return Promise.reject(err);
        } else {
            // 真正的网络错误或HTTP状态码错误
            return Promise.reject(new Error("连接服务器失败"));
        }
    });
}
```

### 2.3 多参数接口模板

当接口需要多个参数时，统一使用对象传参：

```javascript
import Vue from 'vue';
import Storage from '@/assets/js/storage.js'
export default function (data) {
    return Vue.axios.post(Storage.url(), {
        "ApiType": "CallAgvNewController",
        "Parameters": [
            {
                "Value": data
            }
        ],
        "Method": "SubmitCallAgv",
        "Context": {
            "Ticket": Storage.ticket(),
            "InvOrgId": Storage.orgid()
        }
    }).then(res => {
        const data = res.data;
        if (data.Success) {
            if (data.Context.Ticket) {
                Storage.refreshTicket(data.Context.Ticket);
            }
            return data.Result;
        } else {
            const businessError = new Error(data.Message);
            businessError.isBusinessError = true;
            throw businessError;
        }
    }).catch(err => {
        if (err.isBusinessError) {
            return Promise.reject(err);
        } else {
            return Promise.reject(new Error("连接服务器失败"));
        }
    });
}
```

### 2.4 模板参数说明

| 字段 | 说明 | 值来源 |
|------|------|--------|
| `ApiType` | 后端 Controller 类名（不含命名空间） | 根据实际 Controller 填写 |
| `Method` | 后端方法名 | 根据实际方法填写 |
| `Parameters[0].Value` | 参数值 | 单参数直接传值，多参数传对象 |
| `Context.Ticket` | 登录票据 | `Storage.ticket()` |
| `Context.InvOrgId` | 库存组织 ID | `Storage.orgid()` |

## 三、调用处模板

### 3.1 标准调用模式

```javascript
this.$vux.loading.show({ text: 'Loading' });
try {
    const res = await this.$axiosApi.scanStation(this.inputStationCode);
    this.$vux.loading.hide();
    if (res) {
        // 处理成功结果
    } else {
        // 处理空结果
    }
} catch (err) {
    this.$vux.loading.hide();
    this.$MConfirm.Alert(err.message, function () {
    })
}
```

### 3.2 调用模板说明

- **loading 显示**：请求前调用 `this.$vux.loading.show({ text: 'Loading' })` 显示加载中
- **loading 隐藏**：无论成功或失败，在 `try` 和 `catch` 中都要 `this.$vux.loading.hide()`
- **成功处理**：`res` 为后端返回的 `Result` 数据，判断 `if (res)` 再处理
- **错误处理**：使用 `this.$MConfirm.Alert(err.message, callback)` 弹出错误提示
- **方法名**：`this.$axiosApi.<方法名>` 由框架自动注册，方法名取自 API 文件名的驼峰转换（如 `scan-station.js` → `scanStation`）

## 四、代码风格

所有 Vue 前端代码必须遵循 **Prettier 默认风格**：

- 缩进使用 2 空格
- 字符串使用单引号
- 对象字面量尾逗号保留
- 行宽 80 字符
- 禁止手动换行破坏 Prettier 格式
- 禁止每写一个属性就换行

```javascript
// 正确：Prettier 风格
const res = await this.$axiosApi.scanStation(this.inputStationCode);

// 错误：过度换行
const res = await this
    .$axiosApi
    .scanStation(this
        .inputStationCode);
```

## 五、Storage 工具方法

```javascript
import Storage from '@/assets/js/storage.js'

Storage.url()           // 获取 API 请求地址
Storage.ticket()        // 获取登录票据
Storage.refreshTicket(newticket) // 刷新票据
Storage.orgid()         // 获取库存组织 ID
Storage.userid()        // 获取用户 ID
Storage.warehouseid()   // 获取仓库 ID
```

## 六、MConfirm 弹窗方法

```javascript
import MConfirm from '@/assets/js/MConfirm.js'

this.$MConfirm.Toast(text, callback)     // 提示框（自动消失）
this.$MConfirm.Alert(text, callback)     // 警告框（需点击确认）
this.$MConfirm.Asktion(text, callback)   // 询问框（确认/取消）
```

> **注意**：所有 API 接口文件和调用代码必须遵循本文档的模板，禁止自行发明请求格式或错误处理方式。
