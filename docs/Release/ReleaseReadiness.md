# Koko 发布资源与内购核对

日期：2026-10-12。仅源码、工程配置、资源引用、图片像素和文档静态核对；执行了 XcodeGen 工程生成。没有编译、分析器、测试、归档、模拟器、设备运行、支付或上传。

## 资源处理

- 清除 27 组未引用旧 imageset，共 54 个文件；保留当前使用的原创界面和品牌资源。
- 优化 188 张 PNG/JPEG，逐张验证解码像素及尺寸相同，保留颜色配置；没有缩放、降色或有损重编码。
- 保留全部 44 张内容照片、10 段原视频和对应缩略图；未改视频编码。
- 删除资源内 .DS_Store。字体出处文档移到 design/fonts，字体与必需许可文本仍保留在包内。
- 去除图片的非显示元数据；PNG 的生成出处另保存在 design 原创素材记录和源图中，不声称图片为人工摄影或改变作者归属。

| 随包资源源文件合计 | 字节 | MiB |
| --- | ---: | ---: |
| 处理前 | 263759412 | 251.54 |
| 处理后 | 187335042 | 178.66 |
| 减少 | 76424370 | 72.88 |

减少 29.0%。这不是正式 IPA、App Store 下载大小或 Assets.car 实测值。Asset Catalog 还会在归档时编译，不能用 PNG 的磁盘节省推导最终包体节省。

视频合计 59,790,311 字节，已超过 50 MB。保留全部原视频和原像素质量时，当前资源不可能压到 50 MB 以下。没有为达数字删除可达内容、偷换远端下载或接受画质损失。更大的下降需要另行评估视频编码/按需内容分发，并做实际画质与离线行为验收。

详细文件记录：resource-audit.json。sourceSHA256 等历史素材记录表示导入原件，优化分发副本的编码字节可不同，像素未变。

## 本机信息

- 移除设计出处记录中的本机用户名、生成目录和会话目录；保留文件名、原始素材来源和许可。
- 后台文档的命令改为环境变量路径，不含特定电脑的绝对路径。
- Release 设置关闭 Swift 调试选项序列化并开启复制阶段 strip，dSYM 独立保留；已同步 project.yml 和生成工程。
- .git、开发文档、assets 源图、design、后台导入模板和 CommerceSetup 不在应用资源构建阶段。
- 不改签名、Entitlements、合法版权、SDK 标识或 Apple 构建元数据。上述属于隐私和包体卫生，不保证 App Review 结果，也不能消除 Apple 的开发者账号关联。
- 未归档，因此没有声称最终 Mach-O 或 dSYM 内完全没有编译路径。

## 真实内购

源码使用 StoreKit 2 的 Product.products 和 product.purchase；没有 .storekit 文件或 Scheme 模拟商品配置。原生钱包只对 verified 交易按账号原子入账，成功保存后 finish；托管订单先持久化并等待后台确认，再 finish。没有把取消、待批准、失败或静态模板当作到账成功。

App Review 使用 Apple Sandbox，但读取 App Store Connect 中真实商品并执行 Apple 的沙盒交易，不产生真实扣款。不能把审核沙盒误认为应用本地模拟。依据：[Apple 内购审核说明](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases/)。

仍未确认的发布条件：

1. App Store Connect 中 9 档商品实际创建、名称描述、地区与价格配置、付费协议、税务收款状态以及送审状态。本轮没有访问该账号。
2. 当前 Bundle ID 已按用户选择设置为 `com.auroracove.kokoconversation`，尚未配置正式开发者 Team，开发者后台注册状态未核实。
3. docs/BackendAPI/responses/purchase-response.json 的静态验单模板仍刻意返回 code 503。生产处理器必须验证 Apple 凭据、订单归属和幂等到账，不能把模板改成成功响应冒充验单。
4. 实际 Sandbox/TestFlight 购买、取消、延迟批准、未完成订单重试与重复发币回归均未执行。不能保证现在直接提交即可买到商品。
5. 原生金币账本仍是设备本地存储；网关订单具有后台确认流程，不等于原生钱包已经具备跨设备可信账本。

商品名称、描述、ID、币数、USD 参考价见 CommerceSetup/KokoCoinProducts.csv。已将原来 4 档超出 55 字符的商品描述缩短，9 档名称和描述均在限制内，币数和价格与后台 arrangement 模板逐项一致。保持原商品 ID，不因为本轮资源清理重命名或改价。
