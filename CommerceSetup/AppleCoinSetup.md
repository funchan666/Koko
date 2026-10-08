# Koko 金币充值配置

客户端已接入真实 StoreKit 2。当前按用户要求保留临时 Bundle ID `com.koko.app`，未指定开发者团队；未在 App Store Connect 创建/修改任何商品，未发起购买，也未编译或测试。本说明不能视为真实支付已验收。

## 商品清单

全部为 **Consumable（消耗型）**，USD 为基准货币。原七个 ID 和价格保持不变；金币数量均已调整，新增 2.99 / 29.99 两档。CSV 是配置交接表，不代表 App Store Connect 已导入这些商品。

| USD | 金币 | Product ID | 来源 |
| ---: | ---: | --- | --- |
| 0.99 | 360 | hrsrzorpkreajmwb | 原 ID |
| 1.99 | 780 | nfqsfmisuvrnetzu | 原 ID |
| 2.99 | 1,240 | pmwqzntlcxvfrsda | 新增 |
| 4.99 | 2,280 | rkkuocvmcmaqhxlq | 原 ID |
| 9.99 | 4,920 | rvthzqpamnueclfd | 原 ID |
| 19.99 | 10,600 | ztyjvowtyrkjtspk | 原 ID |
| 29.99 | 16,800 | kdhvxqjpnrtwbsme | 新增 |
| 49.99 | 29,600 | tsvizuhgbkfzzhos | 原 ID |
| 99.99 | 64,800 | aiapsuakjxhtmttt | 原 ID |

代码的唯一档位来源是 `Koko/CoinCommerce/KokoCoinCatalog.swift`。已发售的 Product ID 不应改变对应金币权益；日后若调整数量，应使用新 Product ID，避免延迟到账的旧交易被按新数量入账。

## 连接正式应用

1. 在 `project.yml` 替换 `PRODUCT_BUNDLE_IDENTIFIER` 为 App Store Connect 中这款应用的正式 Bundle ID，并设置 `DEVELOPMENT_TEAM`。
2. 在对应应用中创建上表九个消耗型商品，逐项填写本地化名称、描述、审核资料和销售地区。七个指定 ID 与 USD 价格不得改动；美元金额必须与表格相同。
3. 完成 Paid Apps Agreement、税务和收款信息等 Apple 商业配置，使商品对目标商店可用。
4. 用 XcodeGen 更新工程。工程已声明 StoreKit.framework 和 In-App Purchase capability，没有 `.storekit` 本地配置文件，也没有自动模拟加币逻辑。
5. 真正可购买还取决于 Apple 的商品可用状态、签名、安装渠道与商店环境。Sandbox / TestFlight 会使用 Apple 测试支付环境；正式 App Store 环境才产生真实扣款。当前未做任何支付验证。

## 请求与到账边界

- 启动、登录和进入充值页均不请求 Product 列表。仅点击对应 Buy 时执行 `Product.products(for: [pack.id])`，检查 ID、consumable 类型及 USD 价格，再调用 `product.purchase`。Apple 原生面板展示并确认实际本地价格；不是应用绘制的支付仿制面板。
- 页面预先显示明确标注的 USD 参考价；取得商品后使用 Apple 的 `displayPrice`。不会把参考价冒充已获取的商店价格。
- `appAccountToken` 是与本地 Koko 身份绑定的稳定 UUID。购买过程暂时阻止切换/删除账号；延迟交易只对匹配的账号发币。
- 只有 StoreKit `.verified` 结果可入账。金币、交易 ID、流水一次原子写入，保存成功后才 `finish()`。取消、未批准、签名未通过、商品缺失、网络/保存异常不加币。
- `Transaction.updates` 全局监听；启动、切换账号、前台恢复以及用户点击“检查未到账订单”时处理 `Transaction.unfinished`。不会用“恢复购买”重复发放已完成消耗型订单。
- 收到已验证退款通知时进行一次冲正；已花费的退款金币作为待抵扣额，不造成可花费负余额。历史查询仅用于已记账订单的退款对账，不从历史重复发币。退款跨设备、离线及服务端通知的完整处理仍需要后端。

实现依据：[Apple Product 查询](https://developer.apple.com/documentation/storekit/product/products(for:))、[Apple purchase](https://developer.apple.com/documentation/storekit/product/purchase(options:))、[未完成交易](https://developer.apple.com/documentation/storekit/transaction/unfinished)、[交易完成](https://developer.apple.com/documentation/storekit/transaction/finish())。

## 欢迎礼与消费

新创建账号第一次完成资料进入首页即原子发放 **600 金币**；关闭欢迎页只标记已读，不再次发币。原创主视觉为薄荷金属唱片、深翡翠唱片套和浅金色金币；只做整张位图的入场倾斜、缩放和渐显，支持“减少动态效果”。没有代码绘制美术、SF Symbols 或默认系统弹窗。

| 消费用途 | 金币 | 规则 |
| --- | ---: | --- |
| A little bloom | 30 | 每份礼物 |
| Good listening | 75 | 每份礼物 |
| You made my day | 160 | 每份礼物 |
| Room to dance | 320 | 每份礼物 |
| Good company | 480 | 装饰，买断 |
| Out of office | 720 | 装饰，买断 |
| Pocket radio | 1,100 | 装饰，买断 |
| Room regular | 1,500 | 装饰，买断 |

赠送多份按数量计算；从背包赠送已购礼物仅消耗库存，不二次扣币。装饰佩戴、切换、卸下均免费，不能重复购买已拥有的装饰。消费前显示当前余额、花费和剩余余额；不足自动进入充值页展示差额。充值后不会自动续扣，用户必须回到原功能再次确认。

**聊天类全部免费**：文字/图片私聊、语音/视频聊天、进入/创建房间、发言、上麦，以及关注、点赞、评论、收藏均不收费。房间礼物是单独、可选的装饰性表达，不是聊天解锁条件；本地礼物不产生他人收益。

## 当前本地账户的限制

依照此前“先做本地交互”的工程范围，余额、交易去重记录和赠礼库存仍在每个账号的设备本地 JSON，采用原子写入和文件保护；它不是服务端可信账本。当前邮箱账号校验已改为本地 Keychain 密码校验，但没有邮箱验证或服务端账号认证。

正式运营前还需要真实认证和服务端校验/幂等记账、App Store Server Notifications、退款/消费对账、跨设备余额以及账号迁移。现有 code 不宣称防越狱篡改，也不保证卸载/换机后恢复已消费/未消费余额。删除本地资料页面会明确提示余额和已完成消耗型订单记录也会删除。欢迎礼同安装内重登、删除再创建相同身份不重复；跨安装防重复需服务端。

## 素材来源与核对

- 新图由 Garden / Image 2 Host-Native 的内置图像工具生成，已检查画面并保存至 `Koko/Resources/KokoArtwork.xcassets/KokoFirstRecord.imageset/KokoFirstRecord.png`。
- 提示词：`garden-gpt-image-2/prompt/koko-first-record-welcome.txt`。
- 本轮只做源码、SDK 声明、商品配置和资源引用核对；没有执行编译、测试、模拟器或支付交易。
