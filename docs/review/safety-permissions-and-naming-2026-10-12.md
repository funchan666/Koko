# Koko：内容安全、权限与命名复核

2026-10-12，当前工作区源码复核。后续结论以本文为准，前一份 `app-review-risk-2026-10-12.md` 保留为上轮记录。

## 结论与证据范围

已落实可由客户端完成的权限修复、业务语义重构和有限的文本拦截。**不能确认当前版本满足 1.2，也不能承诺没有 1.1.4 或 4.3 风险。** 举报运营接收端、真实认证/关系服务、远端直播与审核处理仍未接通。独立账号仅提交 Koko 是用户提供的提交计划，不是已核验的 App Store Connect 状态；它不能替代产品差异化或 UGC 安全要求。

本轮覆盖源码/配置/本地化目录索引与检索，并审阅账号、举报、拉黑、发布、聊天、音视频权限、钱包和政策阅读等关键调用链。当前为 61 个 Swift 文件、8,834 行，54 份用户媒体、96 份资产目录图片。逐文件清单见 `safety-source-inventory-2026-10-12.json`。**不代表对每个媒体画面、视频全长或每条翻译进行人工内容鉴定。** 未编译、运行测试、分析器、模拟器或设备；未检查最终 IPA/Assets.car，也没有其他应用二进制作比较。

## 对照的 Apple 官方资料

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)：1.1.4 涉及露骨色情及相关剥削；1.2 要求内容过滤、举报及及时处理、拉黑与公开联系方式；4.3 同时涉及重复提交和缺少实质区别的产品。
- [Privacy — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/privacy)：结合用户正在使用的功能请求权限，说明具体用途，尊重访问选择。
- [Settings — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/settings)：设置应让用户自主控制体验。

“首次拒绝后安静结束、之后主动重试才给设置入口”是本次用户要求采用的具体交互约定，不将其冒称为 Apple 官方逐字规定。

## 已修改的权限流程

统一决策位于 `Koko/AccountAccess/KokoCapturePermission.swift`，区分允许、本次系统弹窗被拒绝、系统早已拒绝和设备限制。

| 入口 | 首次拒绝 | 后续主动重试 | 生命周期 |
| --- | --- | --- | --- |
| 头像拍摄 | 结束操作，留在资料编辑页，不弹解释/设置框 | 中性说明；可选设置、选择照片或暂不操作 | 前台恢复不自动启动相机；后台/离页使待处理结果失效 |
| 私人通话麦克风检查 | 结束准备，不继续申请相机 | 可选设置入口，仍可浏览/返回 | 静音、离页、后台、中断停止输入 |
| 私人通话相机检查 | 结束准备并停止已开启的麦克风 | 可选设置，允许不启用视频 | 不自动重试；异步回调校验页面与请求状态 |
| 房间上麦/相机 | 首次拒绝结束，不占用新座位或显示设置入口 | 仅在再次点按依赖权限的按钮后提供设置 | 后台/离页停止采集，过期任务不重新开启 |
| 头像选图 | 使用真实 PhotosPicker；取消不提示 | 用户自己再次打开选择器 | 不请求整库访问，不跳照片设置 |

全局唯一 `openSettingsURLString` 位于 `KokoDeviceSettingsAction` 的显式按钮回调。相机和麦克风系统授权请求集中在权限决策文件。不存在相册授权申请。头像相机页面只在预检允许后出现，页面自身不再次请求系统权限。受家长/设备策略限制时不提供无效的设置引导。

相机、麦克风用途描述提供英语、简体中文、西班牙语、法语、日语版本，明确头像拍摄、设备检查、未录制/未传送的真实范围。应用切换语言不等同于控制 iOS 系统弹窗语言；系统用途文本遵循 iOS 资源语言选择。

## 业务命名与持久化

没有 Flutter/Dart 的 `lib`。不引入随机前缀或为了增加字符串差异的机械改名。

| 原名称 | 当前职责名称 |
| --- | --- |
| `LocalJournal/` | `AccountStorage/` |
| `KokoLocalization/` | `Localization/` |
| `ListeningCommunity.swift` | 按账号、成员、房间、消息、金币、举报等概念拆分；静态内容归 `CommunityContentCatalog.swift` |
| `PersonalJournal` | `MemberAccountArchive` |
| `ListeningRoom` | `HostedConversationRoom` |
| `TokenMovement` | `CoinLedgerEntry` |
| `SafetyRecord` | `ContentReportReceipt` |
| `ConversationPlan` | `ConversationRunSheet` |
| `detailLine` / `tokenChange` | `entryDescription` / `coinDelta` |
| `subjectKey` / `selectedReason` | `reportedContentID` / `reportReason` |
| `tokenCost` / `targetAudience` | `coinPrice` / `audienceGoal`（目标，不代表在线人数） |
| 计划 `title/questions/notes/currentStep` | `sessionTitle/orderedPrompts/listeningNotes/activePromptIndex` |
| 计划 `roomID/startedAt/finishedAt` | `linkedRoomID/hostingStartedAt/hostingFinishedAt` |
| 计划 `reflection/nextConversation/updatedAt` | `personalReflection/followUpPrompt/lastEditedAt` |

所有改名的 Codable 字段通过显式 `CodingKeys` 保留原磁盘键；账号文件路径、身份标识、余额、关系、记录 ID 和权益 ID 不变。源码引用和工程引用已同步。旧数据实际加载仍需要后续运行验证，不能将静态字段映射核对描述为迁移测试通过。

`assets/images` 的五份原始出图按用途移入 `assets/original-ui/feedback` 和 `assets/original-ui/conversation-studio`，来源记录同步。与应用资产中的图片逐字节一致，无裁剪、重采样、加噪或指纹扰动。用户提供的 `photos/`、`videos/` 保留。

## 内容与 1.1.4 / 1.2

- 对源码和五种语言资源检索性招揽、匿名/随机聊天、威胁等相关文本，未发现面向用户的色情招揽宣传。命中主要是社区禁止事项、举报类型及新拦截规则；这些用于制止问题的词不应被机械删除。检索无命中不能证明媒体或未来 UGC 安全。
- Marlowe、Eli Santos、Ren、Imani Brooks、Noa Bennett、Jules Martin 为当前编辑内容姓名，没有流水号式命名。不随意重命名同一身份，也不把静态人物伪装为真实在线用户。
- 移除语音卡片不符合实际状态的 `LIVE CHAT` 字样。保留录制视频、设备检查、本地保存等关键能力边界，避免营销文案误导。政策阅读器用途仅为条款/隐私网页，未发现按审核状态切换内容或动态下载执行代码的入口。
- `CommunityTextPolicy` 在资料保存、动态提交、评论、私信发送、房间新增/修改文字和公开主持问题之前拒绝少量明确的色情索取、有偿性服务及威胁短语。覆盖五种界面语言的有限短语，做大小写/宽度/重音及空白归一化；**可被变体绕过，不是完整语义分类器**。举报说明不经此拦截，避免受害者无法描述问题。私密主持笔记不当作公开内容过滤。
- 举报类型从固定集合验证；举报/拉黑成功只在存储成功后反馈。内容与作者隐藏覆盖成员、动态、评论、房间与会话，解除拉黑不会自动恢复关系。
- 私信发送与通话准备校验互关；不新增自动互关/假接听/假消息。单向关注动作不会替他人确认。
- 新动态保持私有待审核，没有自动批准定时器。当前未上传运营后台，因此不能宣称“审核团队已收到”。

**仍需补齐的高优先级问题：**

1. 举报接收、人工处理、响应时限、处置反馈和服务端封禁；当前保存本机不等于及时处理举报。
2. 联系邮箱已按用户提供的地址更新为 `stapallalkthiag@hotmail.com`，启用 `KokoSafetySupportContactEnabled`，反馈页与社区规定共用 Info.plist 配置并支持复制。未发送验证邮件或核实邮箱收件情况；应用内举报与保存反馈仍按现有本地逻辑处理，不会自动发送到邮箱。
3. 图像、视频、音频审核和运营机制。44 张照片、10 段视频还需逐份核查内容与使用授权，尤其完整视频声音和后续画面；不能只检查首帧。
4. 邮箱入口按既有要求仅做格式校验，不是身份认证；可跳过资料的路径也不构成成人年龄验证。若作为 18+ 在线社区发布，需要与真实认证、年龄策略及商店分级保持一致。
5. 远端消息、关注确认、RTC 与账号删除服务没有因此次客户端修改而实现。应用内能力、协议和商店说明必须与实际一致。
6. 两个已配置政策网址本轮通过网页工具读取返回错误，不能确认当前远端全文、可达性和联系方式；登录和设置使用同一地址已静态确认。需上线前真实验证，不据工具错误断言网站宕机。

## 4.3、Framework 与 Assets.car

- 工程显式链接 StoreKit、AuthenticationServices、WebKit、PhotosUI、AVFoundation、Security；没有发现项目配置中的第三方二进制 framework/package 依赖。SwiftUI/UIKit 等系统 SDK 的合理使用不是本次要通过改名隐藏的内容。
- Apple 公布的指南没有给出可据此计算的 Framework/Assets.car 相似度阈值；本轮没有对最终二进制或外部应用做相似度评估，不给出虚构百分比。
- 源图片有五组字节相同文件：一组是用户要求的 AppIcon/品牌图同源；四组是旧集合目录中未被该目录 Contents.json 引用的分片副本与独立分片。它们是仓库内部复用，不是其他产品相似证据，也不能据此推断 Assets.car 内容。明细保存在本轮清单。
- 单应用账号不能排除 4.3(b)。差异化证据应来自已实现的谈话编排、可编辑主持顺序、逐题私密记录、回顾和下一次衔接；文件名、配色或多加金币入口不是充分证明。当前直播/语音社交的远端链路仍缺失，产品完整性风险比参数名称更重要。
- 没有添加混淆、无用 Framework、审核识别开关或隐瞒实际运行方式的文案。

## 静态交付检查

已完成：源码引用检索、重命名持久化键核对、资源清单/原图一致性、目录 Contents.json 引用检查（无缺失图片）、五语言文案资源生成、XcodeGen 重新生成、plist/strings 格式检查、`git diff --check`。资源生成和工程生成不是编译。

未执行：Swift 编译、测试、分析器、任何模拟器/设备运行、真实权限交互、双账号通信、App Store 支付和审核提交。后续若获运行授权，应分别验证首次拒绝、二次点击、限制状态、设置返回、后台取消和账号切换时的异步结果，并加载改名前的真实存档。
